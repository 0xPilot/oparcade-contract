const { ethers, upgrades } = require("hardhat");

describe("GameRegistry", () => {
  before(async () => {
    [deployer] = await ethers.getSigners();

    // Initialize GameRegistry contract
    const GameRegistry = await ethers.getContractFactory("GameRegistry");
    const gameRegistry = await upgrades.deployProxy(GameRegistry);
  });
});
