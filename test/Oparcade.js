const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Oparcade", () => {
  let addressRegistry, gameRegistry, mockUSDT, mockOPC;

  let game1 = "Game1",
    game2 = "Game2";

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
    const Oparcade = await ethers.getContractFactory("GameRegistry");
    oparcade = await upgrades.deployProxy(Oparcade, [addressRegistry.address, feeRecipient.addGame, platformFee]);

    // deploy mock tokens
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockUSDT = await MockERC20.deploy("mockUSDT", "mockUSDT");
    mockOPC = await MockERC20.deploy("mockOPC", "mockOPC");

    // register the contract addresses and maintainer to the AddressRegistery
    await addressRegistry.updateOparcade(oparcade.address);
    await addressRegistry.updateGameRegistry(gameRegistry.address);
    await addressRegistry.updateMaintainer(maintainer.address);

    // add games
    gameRegistry.addGame(game1);
    gameRegistry.addGame(game2);

    // Set deposit token amount and claimable tokens for games
    let gid = 0;
    gameRegistry.updateDepositTokenAmount(gid, mockUSDT, 10 ** 18);
    gameRegistry.updateClaiimableTokenAddress(gid, mockUSDT, true);

    gid = 1;
    gameRegistry.updateDepositTokenAmount(gid, mockUSDT, 10 ** 18);
    gameRegistry.updateDepositTokenAmount(gid, mockOPC, 20 ** 18);
    gameRegistry.updateClaiimableTokenAddress(gid, mockOPC, true);
  });
});
