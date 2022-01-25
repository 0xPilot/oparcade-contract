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
    mockUSDT = await ERC20Mock.deploy("mockUSDT", "mockUSDT");
    mockOPC = await ERC20Mock.deploy("mockOPC", "mockOPC");

    // register the contract addresses and maintainer to the AddressRegistery
    await addressRegistry.updateOparcade(oparcade.address);
    await addressRegistry.updateGameRegistry(gameRegistry.address);
    await addressRegistry.updateMaintainer(maintainer.address);

    // add games
    await gameRegistry.addGame(game1);
    await gameRegistry.addGame(game2);

    // Set deposit token amount and claimable tokens for games
    let gid = 0;
    await gameRegistry.updateDepositTokenAmount(gid, mockUSDT.address, MockUSDTDepositAmount);
    await gameRegistry.updateClaimableTokenAddress(gid, mockUSDT.address, true);

    gid = 1;
    await gameRegistry.updateDepositTokenAmount(gid, mockUSDT.address, MockUSDTDepositAmount);
    await gameRegistry.updateDepositTokenAmount(gid, mockOPC.address, mockOPCDepositAmount);
    await gameRegistry.updateClaimableTokenAddress(gid, mockOPC.address, true);
  });

  describe("deposit and claim", () => {
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
      // set gid
      let gid = 0;

      // deposit mockUSDT tokens
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.deposit(gid, mockUSDT.address);

      // check balances
      expect(await mockUSDT.balanceOf(oparcade.address)).to.equal(MockUSDTDepositAmount);

      // set new gid
      gid = 1;

      // deposit mockOPC tokens
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.deposit(gid, mockOPC.address);

      // check balances
      expect(await mockOPC.balanceOf(oparcade.address)).to.equal(mockOPCDepositAmount);
    });

    it("Should revert if users deposit the invalid token...", async () => {
      // set gid
      let gid = 0;

      // deposit mockUSDT tokens
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await expect(oparcade.deposit(gid, mockOPC.address)).to.be.revertedWith("Invalid deposit token");
    });

    it("Should be able to claim tokens...", async () => {
      // deposit tokens
      let gid = 0;
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.deposit(gid, mockUSDT.address);

      gid = 1;
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.deposit(gid, mockOPC.address);

      // set gid, claimable amount and nonce
      gid = 0;
      const claimableAmount = 5000;
      const nonce = 0;
      const feeAmount = (claimableAmount * platformFee) / 1000;

      // get signature
      let signature = await getSignature(maintainer, gid, alice.address, mockUSDT.address, claimableAmount, nonce);

      // claim tokens
      await oparcade.connect(alice).claim(gid, alice.address, mockUSDT.address, claimableAmount, nonce, signature);

      // check balace
      expect(await mockUSDT.balanceOf(feeRecipient.address)).to.equal(feeAmount);
      expect(await mockUSDT.balanceOf(alice.address)).to.equal(claimableAmount - feeAmount);
    });

    it("Should revert if the signature is used twice...", async () => {
      // deposit tokens
      let gid = 0;
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.deposit(gid, mockUSDT.address);

      gid = 1;
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.deposit(gid, mockOPC.address);

      // set gid, claimable amount and nonce
      gid = 0;
      const claimableAmount = 5000;
      const nonce = 0;
      const feeAmount = (claimableAmount * platformFee) / 1000;

      // get signature
      let signature = await getSignature(maintainer, gid, alice.address, mockUSDT.address, claimableAmount, nonce);

      // claim tokens
      await oparcade.connect(alice).claim(gid, alice.address, mockUSDT.address, claimableAmount, nonce, signature);

      // check balace
      expect(await mockUSDT.balanceOf(feeRecipient.address)).to.equal(feeAmount);
      expect(await mockUSDT.balanceOf(alice.address)).to.equal(claimableAmount - feeAmount);

      // claim twice with the same signature
      await expect(
        oparcade.connect(alice).claim(gid, alice.address, mockUSDT.address, claimableAmount, nonce, signature),
      ).to.be.revertedWith("Already used signature");
    });

    it("Should revert if msg.sender is not a winner...", async () => {
      // deposit tokens
      let gid = 0;
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.deposit(gid, mockUSDT.address);

      gid = 1;
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.deposit(gid, mockOPC.address);

      // set gid, claimable amount and nonce
      gid = 0;
      const claimableAmount = 5000;
      const nonce = 0;
      const feeAmount = (claimableAmount * platformFee) / 1000;

      // get signature
      let signature = await getSignature(maintainer, gid, alice.address, mockUSDT.address, claimableAmount, nonce);

      // claim tokens
      await expect(
        oparcade.connect(bob).claim(gid, alice.address, mockUSDT.address, claimableAmount, nonce, signature),
      ).to.be.revertedWith("Only winner can claim");
    });

    it("Should revert if the maintainer is not a message signer...", async () => {
      // deposit tokens
      let gid = 0;
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.deposit(gid, mockUSDT.address);

      gid = 1;
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.deposit(gid, mockOPC.address);

      // set gid, claimable amount and nonce
      gid = 0;
      const claimableAmount = 5000;
      const nonce = 0;
      const feeAmount = (claimableAmount * platformFee) / 1000;

      // get signature
      let signature = await getSignature(alice, gid, alice.address, mockUSDT.address, claimableAmount, nonce);

      // claim tokens
      await expect(
        oparcade.connect(alice).claim(gid, alice.address, mockUSDT.address, claimableAmount, nonce, signature),
      ).to.be.revertedWith("Wrong signer");
    });

    it("Should revert if the claim token is not allowed...", async () => {
      // deposit tokens
      let gid = 0;
      await mockUSDT.approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.deposit(gid, mockUSDT.address);

      gid = 1;
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.deposit(gid, mockOPC.address);

      // set gid, claimable amount and nonce
      gid = 1;
      const claimableAmount = 5000;
      const nonce = 0;
      const feeAmount = (claimableAmount * platformFee) / 1000;

      // get signature
      let signature = await getSignature(maintainer, gid, alice.address, mockUSDT.address, claimableAmount, nonce);

      // claim tokens
      await expect(
        oparcade.connect(alice).claim(gid, alice.address, mockUSDT.address, claimableAmount, nonce, signature),
      ).to.be.revertedWith("Disallowed claim token");
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
