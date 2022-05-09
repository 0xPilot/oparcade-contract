const settings = async (hre) => {
  // get contracts
  const addressRegistry = await ethers.getContract('AddressRegistry');
  const gameRegistry = await ethers.getContract('GameRegistry');
  const oparcade = await ethers.getContract('Oparcade');

  // register GameRegistry contract address
  await addressRegistry.updateGameRegistry(gameRegistry.address);

  // register Oparcade contract address
  await addressRegistry.updateOparcade(oparcade.address);
};
module.exports = settings;
settings.tags = ["Settings"];
settings.dependencies = ["AddressRegistry", "GameRegistry", "Oparcade"];
