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

    // Set deposit token amount and distributable tokens for games
    let gid = 0;
    await gameRegistry.updateDepositTokenAmount(gid, mockUSDT.address, MockUSDTDepositAmount);
    await gameRegistry.updateDistributableTokenAddress(gid, mockUSDT.address, true);

    gid = 1;
    await gameRegistry.updateDepositTokenAmount(gid, mockUSDT.address, MockUSDTDepositAmount);
    await gameRegistry.updateDepositTokenAmount(gid, mockOPC.address, mockOPCDepositAmount);
    await gameRegistry.updateDistributableTokenAddress(gid, mockOPC.address, true);

    // Initial mock token distribution
    const initAmount = 10000000;
    await mockUSDT.transfer(alice.address, initAmount);
    await mockUSDT.transfer(bob.address, initAmount);
    await mockOPC.transfer(alice.address, initAmount);
    await mockOPC.transfer(bob.address, initAmount);
  });

  describe("deposit and distribute", () => {
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

      // calculate fee amount
      let feeAmount = (MockUSDTDepositAmount * platformFee) / 1000;

      // check balances
      expect(await mockUSDT.balanceOf(feeRecipient.address)).to.equal(feeAmount);
      expect(await mockUSDT.balanceOf(oparcade.address)).to.equal(MockUSDTDepositAmount - feeAmount);

      // set new gid
      gid = 1;

      // deposit mockOPC tokens
      await mockOPC.approve(oparcade.address, mockOPCDepositAmount);
      await oparcade.deposit(gid, tid, mockOPC.address);

      // calculate fee amount
      feeAmount = (mockOPCDepositAmount * platformFee) / 1000;

      // check balances
      expect(await mockOPC.balanceOf(feeRecipient.address)).to.equal(feeAmount);
      expect(await mockOPC.balanceOf(oparcade.address)).to.equal(mockOPCDepositAmount - feeAmount);
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

      // calculate total fees
      let MockUSDTFeeAmount = (2 * (MockUSDTDepositAmount * platformFee)) / 1000;
      let MockOPCFeeAmount = (2 * (mockOPCDepositAmount * platformFee)) / 1000;

      // set distributable amount
      const totalMockUSDTDistributableAmount = 2 * MockUSDTDepositAmount - MockUSDTFeeAmount;
      const totalMockOPCDistributableAmount = 2 * mockOPCDepositAmount - MockOPCFeeAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.3;
      const aliceMockOPCAmount = totalMockOPCDistributableAmount * 0.6;
      const bobMockOPCAmount = totalMockOPCDistributableAmount * 0.4;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount];
      const mockOPCDistributableAmount = [aliceMockOPCAmount, bobMockOPCAmount];

      // check old balaces
      const beforeAliceMockUSDTAmount = await mockUSDT.balanceOf(alice.address);
      const beforeBobMockUSDTAmount = await mockUSDT.balanceOf(bob.address);
      const beforeAliceMockOPCAmount = await mockOPC.balanceOf(alice.address);
      const beforeBobMockOPCAmount = await mockOPC.balanceOf(bob.address);

      // distribute tokens
      gid = 0;
      await oparcade
        .connect(maintainer)
        .distribute(gid, tid, [alice.address, bob.address], mockUSDT.address, mockUSDTDistributableAmount);

      gid = 1;
      await oparcade
        .connect(maintainer)
        .distribute(gid, tid, [alice.address, bob.address], mockOPC.address, mockOPCDistributableAmount);

      // check new balaces
      expect(await mockUSDT.balanceOf(alice.address)).to.equal(beforeAliceMockUSDTAmount.add(aliceMockUSDTAmount));
      expect(await mockUSDT.balanceOf(bob.address)).to.equal(beforeBobMockUSDTAmount.add(bobMockUSDTAmount));
      expect(await mockOPC.balanceOf(alice.address)).to.equal(beforeAliceMockOPCAmount.add(aliceMockOPCAmount));
      expect(await mockOPC.balanceOf(bob.address)).to.equal(beforeBobMockOPCAmount.add(bobMockOPCAmount));
    });

    it("Should revert if the distributor is not a maintainer...", async () => {
      // deposit tokens
      let gid = 0;
      let tid = 2;

      await mockUSDT.connect(alice).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(alice).deposit(gid, tid, mockUSDT.address);

      await mockUSDT.connect(bob).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(bob).deposit(gid, tid, mockUSDT.address);

      // calculate total fees
      let MockUSDTFeeAmount = (2 * (MockUSDTDepositAmount * platformFee)) / 1000;

      // set distributable amount
      const totalMockUSDTDistributableAmount = 2 * MockUSDTDepositAmount - MockUSDTFeeAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.3;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount];

      // distribute tokens
      await expect(
        oparcade
          .connect(alice)
          .distribute(gid, tid, [alice.address, bob.address], mockUSDT.address, mockUSDTDistributableAmount),
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

      // calculate total fees
      let MockUSDTFeeAmount = (2 * (MockUSDTDepositAmount * platformFee)) / 1000;

      // set distributable amount
      const totalMockUSDTDistributableAmount = 2 * MockUSDTDepositAmount - MockUSDTFeeAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.5;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount];

      // distribute tokens
      await expect(
        oparcade
          .connect(maintainer)
          .distribute(gid, tid, [alice.address], mockUSDT.address, mockUSDTDistributableAmount),
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

      // calculate total fees
      let MockUSDTFeeAmount = (2 * (MockUSDTDepositAmount * platformFee)) / 1000;

      // set distributable amount
      const totalMockUSDTDistributableAmount = 2 * MockUSDTDepositAmount - MockUSDTFeeAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.3;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount];

      // distribute tokens
      await expect(
        oparcade
          .connect(maintainer)
          .distribute(gid, tid, [alice.address, bob.address], mockOPC.address, mockUSDTDistributableAmount),
      ).to.be.revertedWith("Disallowed distribution token");
    });

    it("Should revert if total payment amount is exceeded...", async () => {
      // lock more tokens
      await mockUSDT.transfer(oparcade.address, MockUSDTDepositAmount);

      // deposit tokens
      let gid = 0;
      let tid = 2;

      await mockUSDT.connect(alice).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(alice).deposit(gid, tid, mockUSDT.address);

      await mockUSDT.connect(bob).approve(oparcade.address, MockUSDTDepositAmount);
      await oparcade.connect(bob).deposit(gid, tid, mockUSDT.address);

      // calculate total fees
      let MockUSDTFeeAmount = (2 * (MockUSDTDepositAmount * platformFee)) / 1000;

      // set distributable amount
      const totalMockUSDTDistributableAmount = 2 * MockUSDTDepositAmount - MockUSDTFeeAmount;

      const aliceMockUSDTAmount = totalMockUSDTDistributableAmount * 0.7;
      const bobMockUSDTAmount = totalMockUSDTDistributableAmount * 0.5;

      const mockUSDTDistributableAmount = [aliceMockUSDTAmount, bobMockUSDTAmount];

      // distribute tokens
      await expect(
        oparcade
          .connect(maintainer)
          .distribute(gid, tid, [alice.address, bob.address], mockUSDT.address, mockUSDTDistributableAmount),
      ).to.be.revertedWith("Total payouts exceeded");
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
