const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("GameRegistry", () => {
  let addressRegistry, gameRegistry, tournamentCreationFeeToken;

  let game1 = "Game1",
    game2 = "Game2";

  // const ONE_ETHER = ethers.utils.parseEther("1");
  const tournamentCreationFeeAmount = 100;
  const platformFee = 10; // 1%
  const baseGameCreatorFee = 100;  // 10%

  before(async () => {
    [deployer, alice, bob, feeRecipient, token1, token2, token3] = await ethers.getSigners();

    // deploy mock token
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    tournamentCreationFeeToken = await ERC20Mock.deploy("mockFeeToken", "mockFeeToken");

    // Initialize AddressRegistry contract
    const AddressRegistry = await ethers.getContractFactory("AddressRegistry");
    addressRegistry = await upgrades.deployProxy(AddressRegistry);

    // Initialize GameRegistry contract
    const GameRegistry = await ethers.getContractFactory("GameRegistry");
    gameRegistry = await upgrades.deployProxy(GameRegistry, [
      addressRegistry.address,
      feeRecipient.address,
      platformFee,
      tournamentCreationFeeToken.address,
      tournamentCreationFeeAmount,
    ]);
  });

  it("Should be able to add a new game...", async () => {
    /// add the first game
    await gameRegistry.addGame(game1, alice.address, baseGameCreatorFee);
    expect(await gameRegistry.games(0)).to.equal(game1);
    expect(await gameRegistry.isDeprecatedGame(0)).to.be.false;
    expect(await gameRegistry.gameCount()).to.equal(1);

    // add the second game
    await gameRegistry.addGame(game2, bob.address, baseGameCreatorFee);
    expect(await gameRegistry.games(1)).to.equal(game2);
    expect(await gameRegistry.isDeprecatedGame(1)).to.be.false;
    expect(await gameRegistry.gameCount()).to.equal(2);
  });

  it("Should revert if trying to remove a non-existing game...", async () => {
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
    const tid0 = 0;
    const tid1 = 1;
    let depositTokenList = [];
    const token1_amount = 100;
    const token2_amount = 200;

    // add token1
    await gameRegistry.updateDepositTokenAmount(gid, tid0, token1.address, token1_amount);

    expect(await gameRegistry.depositTokenAmount(gid, tid0, token1.address)).to.equal(token1_amount);
    expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token1.address);

    // update token1
    const new_token1_amount = 300;
    await gameRegistry.updateDepositTokenAmount(gid, tid0, token1.address, new_token1_amount);

    expect(await gameRegistry.depositTokenAmount(gid, tid0, token1.address)).to.equal(new_token1_amount);
    expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token1.address);

    // add token2
    await gameRegistry.updateDepositTokenAmount(gid, tid1, token2.address, token2_amount);

    expect(await gameRegistry.depositTokenAmount(gid, tid1, token2.address)).to.equal(token2_amount);
    expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(2);
    expect(await gameRegistry.depositTokenList(gid, 1)).to.equal(token2.address);

    // remove token1
    await gameRegistry.updateDepositTokenAmount(gid, tid1, token1.address, 0);

    expect(await gameRegistry.depositTokenAmount(gid, tid1, token1.address)).to.equal(0);
    expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token2.address);

    // remove token3 (unavailable token)
    await gameRegistry.updateDepositTokenAmount(gid, tid1, token3.address, 0);

    expect(await gameRegistry.depositTokenAmount(gid, tid1, token3.address)).to.equal(0);
    expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token2.address);
  });

  it("Should be able to update the distributable token...", async () => {
    const gid = 1;

    // add token1
    await gameRegistry.updateDistributableTokenAddress(gid, token1.address, true);

    expect((await gameRegistry.getDistributableTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.distributable(gid, token1.address)).to.be.true;

    // update token1
    await gameRegistry.updateDistributableTokenAddress(gid, token1.address, true);

    expect((await gameRegistry.getDistributableTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.distributable(gid, token1.address)).to.be.true;

    // add token2
    await gameRegistry.updateDistributableTokenAddress(gid, token2.address, true);

    expect((await gameRegistry.getDistributableTokenList(gid)).length).to.equal(2);
    expect(await gameRegistry.distributable(gid, token2.address)).to.be.true;

    // remove token2
    await gameRegistry.updateDistributableTokenAddress(gid, token2.address, false);

    expect((await gameRegistry.getDistributableTokenList(gid)).length).to.equal(1);
    expect(await gameRegistry.distributable(gid, token2.address)).to.be.false;
  });
});
