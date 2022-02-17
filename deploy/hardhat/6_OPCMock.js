const deployOPCMock = async (hre) => {
  const { deploy } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();

  await deploy("ERC20Mock", {
    from: deployer,
    args: ["OPC Mock", "OPC Mock"],
    log: true,
  });
};
module.exports = deployOPCMock;
deployOPCMock.tags = ["OPCMock"];
