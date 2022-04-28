const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const getSignature = async (signer, gid, winner, token, amount, nonce) => {
  let message = ethers.utils.solidityKeccak256(
    ["uint256", "address", "address", "uint256", "uint256"],
    [gid, winner, token, amount, nonce],
  );
  let signature = await signer.signMessage(ethers.utils.arrayify(message));
  return signature;
};

describe("Oparcade", () => {
  let addressRegistry, gameRegistry, oparcade, mockUSDT, mockOPC, platformFee;

  let game1 = "Game1",
    game2 = "Game2";

  const MockUSDTDepositAmount = 10000,
    mockOPCDepositAmount = 50000;

  beforeEach(async () => {
    [deployer, alice, bob, maintainer, feeRecipient] = await ethers.getSigners();

    platformFee = 10; // 1%

    // Initialize AddressRegistry contract
    const AddressRegistry = await ethers.getContractFactory("AddressRegistry");
    addressRegistry = await upgrades.deployProxy(AddressRegistry);

    // Initialize GameRegistry contract
    const GameRegistry = await ethers.getContractFactory("GameRegistry");
    gameRegistry = await upgrades.deployProxy(GameRegistry);

    // Initialize Oparcade contract
    const Oparcade = await ethers.getContractFactory("Oparcade");
    oparcade = await upgrades.deployProxy(Oparcade, [addressRegistry.address, feeRecipient.address, platformFee]);

    // deploy mock tokens
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    const MockERC721 = await ethers.getContractFactory("MockERC721");
    const MockERC1155 = await ethers.getContractFactory("MockERC1155");
    mockUSDT = await ERC20Mock.deploy("mockUSDT", "mockUSDT");
    mockOPC = await ERC20Mock.deploy("mockOPC", "mockOPC");
    mockERC721 = await MockERC721.deploy();
    mockERC1155 = await MockERC1155.deploy();

    // register the contract addresses and maintainer to the AddressRegistery
    await addressRegistry.updateOparcade(oparcade.address);
    await addressRegistry.updateGameRegistry(gameRegistry.address);
    await addressRegistry.updateMaintainer(maintainer.address);

    // add games
    await gameRegistry.addGame(game1);
    await gameRegistry.addGame(game2);

    // Set deposit token amount and distributable tokens for games
    let gid = 0;
    await gameRegistry.updateDepositTokenAmount(gid, mockUSDT.address, MockUSDTDepositAmount);
    await gameRegistry.updateDistributableTokenAddress(gid, mockUSDT.address, true);

    gid = 1;
    await gameRegistry.updateDepositTokenAmount(gid, mockUSDT.address, MockUSDTDepositAmount);
    await gameRegistry.updateDepositTokenAmount(gid, mockOPC.address, mockOPCDepositAmount);
    await gameRegistry.updateDistributableTokenAddress(gid, mockUSDT.address, true);
    await gameRegistry.updateDistributableTokenAddress(gid, mockOPC.address, true);

    // Initial mock token distribution
    const initAmount = 10000000;
    await mockUSDT.transfer(alice.address, initAmount);
    await mockUSDT.transfer(bob.address, initAmount);
    await mockOPC.transfer(alice.address, initAmount);
    await mockOPC.transfer(bob.address, initAmount);
    await mockERC721.mint(deployer.address, 1);
    await mockERC721.mint(deployer.address, 2);
    await mockERC721.mint(deployer.address, 3);
    await mockERC1155.mint(deployer.address, [1, 2, 3], [3, 3, 3]);
  });

  describe("deposit and distributePrize", () => {
    it("Fail to initialize, addressRegistry == address (0), should revert...", async () => {
      // Initialize Oparcade contract
      const Oparcade = await ethers.getContractFactory("Oparcade");
      await expect(
        upgrades.deployProxy(Oparcade, [ethers.constants.AddressZero, feeRecipient.address, platformFee]),
      ).to.be.revertedWith("Invalid AddressRegistry");
    });

    it("Fail to initialize, platformFee > 0 , feeRecipient == address (0), should revert...", async () => {
      // Initialize Oparcade contract
      const Oparcade = await ethers.getContractFactory("Oparcade");
      await expect(
        upgrades.deployProxy(Oparcade, [addressRegistry.address, ethers.constants.AddressZero, platformFee]),
      ).to.be.revertedWith("Fee recipient not set");
    });

    it("Fail to initialize, platformFee > 1000 (100%), should revert...", async () => {
      // new platform fee
      const newPlatformFee = 1001;

      // Initialize Oparcade contract
      const Oparcade = await ethers.getContractFactory("Oparcade");
      await expect(
        upgrades.deployProxy(Oparcade, [addressRegistry.address, feeRecipient.address, newPlatformFee]),
      ).to.be.revertedWith("Platform fee exceeded");
    });

    it("Should be able to deposit tokens...", async () => {
      // set gid and tid
      let gid = 0;
      let tid = 0;

      // deposit mockUSDT tokens
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.deposit(gid, tid, mockUSDT.address);

      // check balances
      expect(await mockUSDT.balanceOf(oparcade.address)).to.equal(MockUSDTDepositAmount);

      // set new gid
      gid = 1;

      // deposit mockOPC tokens
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.deposit(gid, tid, mockOPC.address);

      // check balances
      expect(await mockOPC.balanceOf(oparcade.address)).to.equal(mockOPCDepositAmount);
    });

    it("Should revert if users deposit the invalid token...", async () => {
      // set gid and tid
      let gid = 0;
      let tid = 0;

      // deposit mockUSDT tokens
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await expect(oparcade.deposit(gid, tid, mockOPC.address)).to.be.revertedWith("Invalid deposit token");
    });

    it("Should be able to distribute tokens...", async () => {
      // deposit tokens
      let gid = 0;
      let tid = 1;

      await mockUSDT.connect(alice).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(alice).deposit(gid, tid, mockUSDT.address);

      await mockUSDT.connect(bob).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(bob).deposit(gid, tid, mockUSDT.address);

      gid = 1;

      await mockOPC.connect(alice).approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.connect(alice).deposit(gid, tid, mockOPC.address);

      await mockOPC.connect(bob).approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.connect(bob).deposit(gid, tid, mockOPC.address);

      // deposit prize
      gid = 0;
      await mockUSDT.approve(oparcade.address, 2 * MockUSDTDepositAmount);
      await oparcade.depositPrize(gid, tid, mockUSDT.address, 2 * MockUSDTDepositAmount);

      gid = 1;
      await mockOPC.approve(oparcade.address, 2 * mockOPCDepositAmount);
      await oparcade.depositPrize(gid, tid, mockOPC.address, 2 * mockOPCDepositAmount);

      // set distributable amount
      const totalMockUSDTDistributableAmount = 4 * MockUSDTDepositAmount;
      const totalMockOPCDistributableAmount = 4 * mockOPCDepositAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.3;
      const aliceMockOPCAmount = totalMockOPCDistributableAmount * 0.6;
      const bobMockOPCAmount = totalMockOPCDistributableAmount * 0.4;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount];
      const mockOPCDistributableAmount = [aliceMockOPCAmount, bobMockOPCAmount];

      // check old balances
      const beforeAliceMockUSDTAmount = await mockUSDT.balanceOf(alice.address);
      const beforeBobMockUSDTAmount = await mockUSDT.balanceOf(bob.address);
      const beforeAliceMockOPCAmount = await mockOPC.balanceOf(alice.address);
      const beforeBobMockOPCAmount = await mockOPC.balanceOf(bob.address);

      // distribute tokens
      gid = 0;
      await oparcade
        .connect(maintainer)
        .distributePrize(gid, tid, [alice.address, bob.address], mockUSDT.address, mockUSDTDistributableAmount);

      gid = 1;
      await oparcade
        .connect(maintainer)
        .distributePrize(gid, tid, [alice.address, bob.address], mockOPC.address, mockOPCDistributableAmount);

      // calculate total fees
      let MockUSDTFeeAmount = (totalMockUSDTDistributableAmount * platformFee) / 1000;
      let MockOPCFeeAmount = (totalMockOPCDistributableAmount * platformFee) / 1000;

      // check new balances
      expect(await mockUSDT.balanceOf(alice.address)).to.equal(
        beforeAliceMockUSDTAmount.add((aliceMockUSDTAmount * (1000 - platformFee)) / 1000),
      );
      expect(await mockUSDT.balanceOf(bob.address)).to.equal(
        beforeBobMockUSDTAmount.add((bobMockUSDTAmount * (1000 - platformFee)) / 1000),
      );
      expect(await mockOPC.balanceOf(alice.address)).to.equal(
        beforeAliceMockOPCAmount.add((aliceMockOPCAmount * (1000 - platformFee)) / 1000),
      );
      expect(await mockOPC.balanceOf(bob.address)).to.equal(
        beforeBobMockOPCAmount.add((bobMockOPCAmount * (1000 - platformFee)) / 1000),
      );
    });

    it("Should revert if the distributor is not a maintainer...", async () => {
      // deposit tokens
      let gid = 0;
      let tid = 2;

      await mockUSDT.connect(alice).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(alice).deposit(gid, tid, mockUSDT.address);

      await mockUSDT.connect(bob).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(bob).deposit(gid, tid, mockUSDT.address);

      // set distributable amount
      const totalMockUSDTDistributableAmount = 2 * MockUSDTDepositAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.3;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount];

      // distribute tokens
      await expect(
        oparcade
          .connect(alice)
          .distributePrize(gid, tid, [alice.address, bob.address], mockUSDT.address, mockUSDTDistributableAmount),
      ).to.be.revertedWith("Only maintainer");
    });

    it("Should revert if winners are not matched with the payments...", async () => {
      // deposit tokens
      let gid = 0;
      let tid = 2;

      await mockUSDT.connect(alice).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(alice).deposit(gid, tid, mockUSDT.address);

      await mockUSDT.connect(bob).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(bob).deposit(gid, tid, mockUSDT.address);

      // set distributable amount
      const totalMockUSDTDistributableAmount = 2 * MockUSDTDepositAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.5;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount];

      // distribute tokens
      await expect(
        oparcade
          .connect(maintainer)
          .distributePrize(gid, tid, [alice.address], mockUSDT.address, mockUSDTDistributableAmount),
      ).to.be.revertedWith("Mismatched winners and amounts");
    });

    it("Should revert if the token is not allowed to distribute...", async () => {
      // deposit tokens
      let gid = 0;
      let tid = 2;

      await mockUSDT.connect(alice).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(alice).deposit(gid, tid, mockUSDT.address);

      await mockUSDT.connect(bob).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(bob).deposit(gid, tid, mockUSDT.address);

      // set distributable amount
      const totalMockUSDTDistributableAmount = 2 * MockUSDTDepositAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.3;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount];

      // distribute tokens
      await expect(
        oparcade
          .connect(maintainer)
          .distributePrize(gid, tid, [alice.address, bob.address], mockOPC.address, mockUSDTDistributableAmount),
      ).to.be.revertedWith("Disallowed distribution token");
    });

    it("Should revert if total payment amount is exceeded...", async () => {
      // lock more tokens
      await mockUSDT.transfer(oparcade.address, 10 * MockUSDTDepositAmount);

      // deposit tokens
      let gid = 0;
      let tid = 2;

      await mockUSDT.connect(alice).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(alice).deposit(gid, tid, mockUSDT.address);

      await mockUSDT.connect(bob).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(bob).deposit(gid, tid, mockUSDT.address);

      // deposit prize
      await mockUSDT.approve(oparcade.address, 2 * MockUSDTDepositAmount);
      await oparcade.depositPrize(gid, tid, mockUSDT.address, 2 * MockUSDTDepositAmount);

      // set exceeded distributable amount
      const totalMockUSDTDistributableAmount = 4 * MockUSDTDepositAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.3;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount + 1];

      // distribute tokens
      await expect(
        oparcade
          .connect(maintainer)
          .distributePrize(gid, tid, [alice.address, bob.address], mockUSDT.address, mockUSDTDistributableAmount),
      ).to.be.revertedWith("Prize amount exceeded");
    });
  });

  describe("depositPrize", () => {
    it("Should deposit the ERC20 token prize", async () => {
      // check old balance
      expect(await mockUSDT.balanceOf(oparcade.address)).to.equal(0);

      // set gid and tid
      let gid = 0;
      let tid = 0;

      // deposit the prize
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.depositPrize(gid, tid, mockUSDT.address, MockUSDTDepositAmount);

      expect(await mockUSDT.balanceOf(oparcade.address)).to.equal(MockUSDTDepositAmount);
    });

    it("Should revert if the token is not allowed to distribute...", async () => {
      // set gid and tid
      let gid = 0;
      let tid = 0;

      // deposit the prize
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await expect(oparcade.depositPrize(gid, tid, mockOPC.address, mockOPCDepositAmount)).to.be.revertedWith(
        "Disallowed distribution token",
      );
    });
  });

  describe("distributeNFTPrize", () => {
    beforeEach(async () => {
      let gid = 0;
      let tid = 0;
      let nftType = 721;
      let tokenIds = [1, 2, 3];
      let tokenAmounts = [1, 1, 1];

      // deposit mockERC721 NFTs
      await gameRegistry.updateDistributableTokenAddress(gid, mockERC721.address, true);
      await mockERC721.approve(oparcade.address, tokenIds[0]);
      await mockERC721.approve(oparcade.address, tokenIds[1]);
      await mockERC721.approve(oparcade.address, tokenIds[2]);
      await oparcade.depositNFTPrize(deployer.address, gid, tid, mockERC721.address, nftType, tokenIds, tokenAmounts);

      gid = 1;
      tid = 1;
      nftType = 1155;
      tokenIds = [1, 2, 3];
      tokenAmounts = [3, 3, 3];

      // deposit mockERC1155 NFTs
      await gameRegistry.updateDistributableTokenAddress(gid, mockERC1155.address, true);
      await mockERC1155.setApprovalForAll(oparcade.address, true);
      await oparcade.depositNFTPrize(deployer.address, gid, tid, mockERC1155.address, nftType, tokenIds, tokenAmounts);
    });

    it("Should distribute the ERC721 NFT prize", async () => {
      // check old balance
      expect(await mockERC721.balanceOf(alice.address)).to.equal(0);
      expect(await mockERC721.balanceOf(bob.address)).to.equal(0);

      let gid = 0;
      let tid = 0;
      let nftType = 721;
      let tokenIds = [1, 3];
      let tokenAmounts = [1, 1];

      // distribute ERC721 NFTs
      await oparcade
        .connect(maintainer)
        .distributeNFTPrize(
          gid,
          tid,
          [alice.address, bob.address],
          mockERC721.address,
          nftType,
          tokenIds,
          tokenAmounts,
        );

      // check new balance
      expect(await mockERC721.balanceOf(alice.address)).to.equal(1);
      expect(await mockERC721.balanceOf(bob.address)).to.equal(1);
      expect(await mockERC721.ownerOf(1)).to.equal(alice.address);
      expect(await mockERC721.ownerOf(3)).to.equal(bob.address);
    });

    it("Should distribute the ERC1155 NFT prize", async () => {
      // check old balance
      expect(await mockERC1155.balanceOf(alice.address, 1)).to.equal(0);
      expect(await mockERC1155.balanceOf(bob.address, 3)).to.equal(0);

      let gid = 1;
      let tid = 1;
      let nftType = 1155;
      let tokenIds = [1, 3];
      let tokenAmounts = [1, 2];

      // distribute ERC1155 NFTs
      await oparcade
        .connect(maintainer)
        .distributeNFTPrize(
          gid,
          tid,
          [alice.address, bob.address],
          mockERC1155.address,
          nftType,
          tokenIds,
          tokenAmounts,
        );

      // check new balance
      expect(await mockERC1155.balanceOf(alice.address, 1)).to.equal(1);
      expect(await mockERC1155.balanceOf(bob.address, 3)).to.equal(2);
    });
  });

  describe("withdrawPrize", () => {
    it("Should withdraw the ERC20 token prize", async () => {
      // set gid and tid
      let gid = 0;
      let tid = 0;

      // deposit the prize
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.depositPrize(gid, tid, mockUSDT.address, MockUSDTDepositAmount);

      // deposit the prize again
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.depositPrize(gid, tid, mockUSDT.address, MockUSDTDepositAmount);

      // check old balance
      const beforeOwnerMockUSDTAmount = await mockUSDT.balanceOf(deployer.address);

      // withdraw the prize
      await oparcade.withdrawPrize(gid, tid, mockUSDT.address, MockUSDTDepositAmount * 1.5);

      // check new balance
      expect(await mockUSDT.balanceOf(deployer.address)).to.equal(
        beforeOwnerMockUSDTAmount.add(MockUSDTDepositAmount * 1.5),
      );
    });

    it("Should revert if the prize token is not enough to withdraw...", async () => {
      // set gid and tid
      let gid = 0;
      let tid = 0;

      // deposit prize
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await expect(oparcade.depositPrize(gid, tid, mockOPC.address, mockOPCDepositAmount)).to.be.revertedWith(
        "Disallowed distribution token",
      );

      // withdraw the prize
      await expect(oparcade.withdrawPrize(gid, tid, mockUSDT.address, MockUSDTDepositAmount * 1.5)).to.be.revertedWith(
        "Insufficient prize",
      );
    });
  });

  describe("depositNFTPrize", () => {
    it("Should deposit the ERC721 NFT prize", async () => {
      // check old balance
      expect(await mockERC721.balanceOf(oparcade.address)).to.equal(0);

      let gid = 0;
      let tid = 0;
      let nftType = 721;
      let tokenIds = [1, 2, 3];
      let tokenAmounts = [1, 1, 1];

      // deposit mockERC721 NFTs
      await gameRegistry.updateDistributableTokenAddress(gid, mockERC721.address, true);
      await mockERC721.approve(oparcade.address, tokenIds[0]);
      await mockERC721.approve(oparcade.address, tokenIds[1]);
      await mockERC721.approve(oparcade.address, tokenIds[2]);
      await oparcade.depositNFTPrize(deployer.address, gid, tid, mockERC721.address, nftType, tokenIds, tokenAmounts);

      // check new balance
      expect(await mockERC721.balanceOf(oparcade.address)).to.equal(3);
      expect(await mockERC721.ownerOf(1)).to.equal(oparcade.address);
      expect(await mockERC721.ownerOf(2)).to.equal(oparcade.address);
      expect(await mockERC721.ownerOf(3)).to.equal(oparcade.address);
    });

    it("Should deposit the ERC1155 NFT prize", async () => {
      // check old balance
      expect(await mockERC1155.balanceOf(oparcade.address, 1)).to.equal(0);
      expect(await mockERC1155.balanceOf(oparcade.address, 2)).to.equal(0);
      expect(await mockERC1155.balanceOf(oparcade.address, 3)).to.equal(0);

      let gid = 1;
      let tid = 1;
      let nftType = 1155;
      let tokenIds = [1, 2, 3];
      let tokenAmounts = [3, 3, 3];

      // deposit mockERC1155 NFTs
      await gameRegistry.updateDistributableTokenAddress(gid, mockERC1155.address, true);
      await mockERC1155.setApprovalForAll(oparcade.address, true);
      await oparcade.depositNFTPrize(deployer.address, gid, tid, mockERC1155.address, nftType, tokenIds, tokenAmounts);

      // check new balance
      expect(await mockERC1155.balanceOf(oparcade.address, 1)).to.equal(3);
      expect(await mockERC1155.balanceOf(oparcade.address, 2)).to.equal(3);
      expect(await mockERC1155.balanceOf(oparcade.address, 3)).to.equal(3);
    });
  });

  describe("withdrawNFTPrize", () => {
    beforeEach(async () => {
      let gid = 0;
      let tid = 0;
      let nftType = 721;
      let tokenIds = [1, 2, 3];
      let tokenAmounts = [1, 1, 1];

      // deposit mockERC721 NFTs
      await gameRegistry.updateDistributableTokenAddress(gid, mockERC721.address, true);
      await mockERC721.approve(oparcade.address, tokenIds[0]);
      await mockERC721.approve(oparcade.address, tokenIds[1]);
      await mockERC721.approve(oparcade.address, tokenIds[2]);
      await oparcade.depositNFTPrize(deployer.address, gid, tid, mockERC721.address, nftType, tokenIds, tokenAmounts);

      gid = 1;
      tid = 1;
      nftType = 1155;
      tokenIds = [1, 2, 3];
      tokenAmounts = [3, 3, 3];

      // deposit mockERC1155 NFTs
      await gameRegistry.updateDistributableTokenAddress(gid, mockERC1155.address, true);
      await mockERC1155.setApprovalForAll(oparcade.address, true);
      await oparcade.depositNFTPrize(deployer.address, gid, tid, mockERC1155.address, nftType, tokenIds, tokenAmounts);
    });

    it("Should withdraw the ERC721 NFT prize", async () => {
      // check old balance
      expect(await mockERC721.balanceOf(alice.address)).to.equal(0);

      let gid = 0;
      let tid = 0;
      let nftType = 721;
      let tokenIds = [1, 2, 3];
      let tokenAmounts = [1, 1, 1];

      // withdraw mockERC721 NFTs
      await oparcade.withdrawNFTPrize(alice.address, gid, tid, mockERC721.address, nftType, tokenIds, tokenAmounts);

      // check new balance
      expect(await mockERC721.balanceOf(alice.address)).to.equal(3);
      expect(await mockERC721.ownerOf(1)).to.equal(alice.address);
      expect(await mockERC721.ownerOf(2)).to.equal(alice.address);
      expect(await mockERC721.ownerOf(3)).to.equal(alice.address);
    });

    it("Should withdraw the ERC1155 NFT prize", async () => {
      // check old balance
      expect(await mockERC1155.balanceOf(alice.address, 1)).to.equal(0);
      expect(await mockERC1155.balanceOf(alice.address, 2)).to.equal(0);
      expect(await mockERC1155.balanceOf(alice.address, 3)).to.equal(0);

      let gid = 1;
      let tid = 1;
      let nftType = 1155;
      let tokenIds = [1, 2, 3];
      let tokenAmounts = [3, 3, 3];

      // deposit mockERC1155 NFTs
      await oparcade.withdrawNFTPrize(alice.address, gid, tid, mockERC1155.address, nftType, tokenIds, tokenAmounts);

      // check new balance
      expect(await mockERC1155.balanceOf(alice.address, 1)).to.equal(3);
      expect(await mockERC1155.balanceOf(alice.address, 2)).to.equal(3);
      expect(await mockERC1155.balanceOf(alice.address, 3)).to.equal(3);
    });
  });

  describe("updatePlatformFee", () => {
    it("Should be able to update platform fee and recipient...", async () => {
      // new fee recipient
      const newFeeRecipient = bob.address;

      // new platform fee
      const newPlatformFee = 100;

      // change platform fee and recipient
      await oparcade.updatePlatformFee(newFeeRecipient, newPlatformFee);

      // check new platform fee
      expect(await oparcade.platformFee()).to.be.equal(newPlatformFee);

      // check new fee recipient
      expect(await oparcade.feeRecipient()).to.be.equal(newFeeRecipient);
    });

    it("Should revert if platformFee > 1000 (100%)...", async () => {
      // New platform fee
      const newPlatformFee = 1001;

      // Should revert with "platform fee exceeded"
      await expect(oparcade.updatePlatformFee(feeRecipient.address, newPlatformFee)).to.be.revertedWith(
        "Platform fee exceeded",
      );
    });

    it("Fail to initialize, platformFee > 0 , feeRecipient == address (0), should revert...", async () => {
      // change platform fee and recipient
      await expect(oparcade.updatePlatformFee(ethers.constants.AddressZero, platformFee)).to.be.revertedWith(
        "Fee recipient not set",
      );
    });

    it("Fail to initialize, platformFee > 1000 (100%), should revert...", async () => {
      // new platform fee
      const newPlatformFee = 1001;

      // change platform fee and recipient
      await expect(oparcade.updatePlatformFee(feeRecipient.address, newPlatformFee)).to.be.revertedWith(
        "Platform fee exceeded",
      );
    });
  });

  describe("pause/unpause", () => {
    it("Should pause Oparcade", async () => {
      // Pause Oparcade
      await oparcade.pause();

      // Expect Oparcade is paused
      expect(await oparcade.paused()).to.be.true;
    });
    it("Should unpause(resume) Oparcade", async () => {
      // Pause Oparcade
      await oparcade.pause();

      // Expect Oparcade is paused
      expect(await oparcade.paused()).to.be.true;

      // Unpause Oparcade
      await oparcade.unpause();

      // Expect Oparcade is resumed
      expect(await oparcade.paused()).to.be.false;
    });
  });
});
