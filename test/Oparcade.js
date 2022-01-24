const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Oparcade", () => {
  let addressRegistry, gameRegistry, oparcade, mockUSDT, mockOPC;

  let game1 = "Game1",
    game2 = "Game2";

  const MockUSDTDepositAmount = 100,
    mockOPCDepositAmount = 500;

  before(async () => {
    [deployer, alice, bob, maintainer, feeRecipient] = await ethers.getSigners();

    const platformFee = 10; // 1%

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
    // set gid
    const gid = 0;

    // set claimable amount and nonce
    const claimableAmount = 50;
    const nonce = 0;

    // deposit tokens
    await oparcade.claim(alice.address, gid, mockUSDT.address, claimableAmount, nonce);
  });
});
