const deployGameRegistry = async (hre) => {
  const { deploy } = hre.deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("GameRegistry", {
    from: deployer,
    args: [],
    log: true,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      viaAdminContract: "DefaultProxyAdmin",
      execute: {
        init: {
          methodName: "initialize",
          args: [],
        },
      },
    },
  });
};
module.exports = deployGameRegistry;
deployGameRegistry.tags = ["GameRegistry"];
