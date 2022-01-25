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
});
