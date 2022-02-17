const deployUSDCMock = async (hre) => {
  const { deploy } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();

  await deploy("ERC20Mock", {
    from: deployer,
    args: ["USDC Mock", "USDC Mock"],
    log: true,
  });
};
module.exports = deployUSDCMock;
deployUSDCMock.tags = ["USDCMock"];
