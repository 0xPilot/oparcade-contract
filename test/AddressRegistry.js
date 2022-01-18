const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("AddressRegistry", () => {
  let addressRegistry;

  const MINT_AMOUNT = 100;

  before(async () => {
    [deployer, oparcade, gameRegistry, maintainer] = await ethers.getSigners();

    // Initialize AddressRegistry contract
    const AddressRegistry = await ethers.getContractFactory("AddressRegistry");
    addressRegistry = await upgrades.deployProxy(AddressRegistry);
  });

  it("Should be able to update Oparcade...", async () => {
    await addressRegistry.updateOparcade(oparcade.address);
    expect(await addressRegistry.oparcade()).to.equal(oparcade.address);
  });

  it("Should be able to update GameRegistry...", async () => {
    await addressRegistry.updateGameRegistry(gameRegistry.address);
    expect(await addressRegistry.oparcade()).to.equal(gameRegistry.address);
  });

  it("Should be able to update Maintainer...", async () => {
    await addressRegistry.updateMaintainer(maintainer.address);
    expect(await addressRegistry.oparcade()).to.equal(maintainer.address);
  });
});
