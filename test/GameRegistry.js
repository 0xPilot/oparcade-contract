const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("GameRegistry", () => {
  let gameRegistry;

  let game1 = "Game1",
    game2 = "Game2";

  before(async () => {
    [deployer, token1, token2, token3] = await ethers.getSigners();

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

  it("Should be able to update the deposit token...", async () => {
    const gid = 1;
    let depositTokenList = [];
    const token1_amount = 100;
    const token2_amount = 200;

    // add token1
    await gameRegistry.updateDepositTokenAmount(gid, token1.address, token1_amount);

    expect(await gameRegistry.depositTokenAmount(gid, token1.address)).to.equal(token1_amount);
    expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token1.address);

    // add token2
    await gameRegistry.updateDepositTokenAmount(gid, token2.address, token2_amount);

    expect(await gameRegistry.depositTokenAmount(gid, token2.address)).to.equal(token2_amount);
    expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(2);
    expect(await gameRegistry.depositTokenList(gid, 1)).to.equal(token2.address);

    // remove token1
    await gameRegistry.updateDepositTokenAmount(gid, token1.address, 0);

    expect(await gameRegistry.depositTokenAmount(gid, token1.address)).to.equal(0);
    expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token2.address);

    // remove token3
    await gameRegistry.updateDepositTokenAmount(gid, token3.address, 0);

    expect(await gameRegistry.depositTokenAmount(gid, token3.address)).to.equal(0);
    expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token2.address);
  });

  it("Should be able to update the claimable token...", async () => {
    const gid = 1;

    // add token1
    await gameRegistry.updateClaimableTokenAddress(gid, token1.address, true);

    expect((await gameRegistry.getClaimableTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.claimable(gid, token1.address)).to.be.true;

    // add token2
    await gameRegistry.updateClaimableTokenAddress(gid, token2.address, true);

    expect((await gameRegistry.getClaimableTokenList(gid)).length).to.equal(2);
    expect(await gameRegistry.claimable(gid, token2.address)).to.be.true;

    // remove token2
    await gameRegistry.updateClaimableTokenAddress(gid, token2.address, false);

    expect((await gameRegistry.getClaimableTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.claimable(gid, token2.address)).to.be.false;
  });
});
