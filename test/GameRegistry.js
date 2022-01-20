const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("GameRegistry", () => {
  let gameRegistry;

  let game1 = "Game1",
    game2 = "Game2";

  before(async () => {
    [deployer, token1, token2] = await ethers.getSigners();

    // Initialize GameRegistry contract
    const GameRegistry = await ethers.getContractFactory("GameRegistry");
    gameRegistry = await upgrades.deployProxy(GameRegistry);
  });

  it("Should be able to add a new game...", async () => {
    /// add the first game
    await gameRegistry.addGame(game1);
    expect(await gameRegistry.games(0)).to.equal(game1);
    expect(await gameRegistry.isDeprecatedGame(0)).to.be.false;
    expect(await gameRegistry.gameLength()).to.equal(1);

    // add the second game
    await gameRegistry.addGame(game2);
    expect(await gameRegistry.games(1)).to.equal(game2);
    expect(await gameRegistry.isDeprecatedGame(1)).to.be.false;
    expect(await gameRegistry.gameLength()).to.equal(2);
  });

  it("Should revert if trying to remve a non-existing game...", async () => {
    const gid = 2;

    // remove the game
    await expect(gameRegistry.removeGame(gid)).to.be.revertedWith("Invalid game index");
  });

  it("Should be able to remove a game...", async () => {
    const gid = 0;

    // remove the first game
    await gameRegistry.removeGame(gid);
    expect(await gameRegistry.games(0)).to.equal(game1);
    expect(await gameRegistry.isDeprecatedGame(gid)).to.be.true;
  });

  it("Should be able to update the deposit amount...", async () => {
    const gid = 1;
    const token1_amount = 100;

    // update the deposit token amount
    await gameRegistry.updateDepositTokenAmount(gid, token1.address, token1_amount);
    expect(await gameRegistry.depositTokenAmount(gid, token1.address)).to.equal(token1_amount);
  });

  it("Should be able to update the claimable amount...", async () => {
    const gid = 1;

    // update the claimable token address
    await gameRegistry.updateClaimableTokenAddress(gid, token1.address, true);
    expect(await gameRegistry.claimable(gid, token1.address)).to.be.true;
  });
});
