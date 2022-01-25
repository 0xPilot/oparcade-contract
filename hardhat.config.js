const fs = require("fs");
const path = require("path");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require('hardhat-deploy');
require("hardhat-gas-reporter");
require("hardhat-abi-exporter");
require("solidity-coverage");
require('dotenv').config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// REQUIRED TO ENSURE METADATA IS SAVED IN DEPLOYMENTS (because solidity-coverage disable it otherwise)
const { TASK_COMPILE_GET_COMPILER_INPUT } = require("hardhat/builtin-tasks/task-names");
task(TASK_COMPILE_GET_COMPILER_INPUT).setAction(async (_, bre, runSuper) => {
  const input = await runSuper();
  input.settings.metadata.useLiteralContent = bre.network.name !== "coverage";
  return input;
});

const infuraKey = process.env.INFURA_KEY || "";

function nodeUrl(network) {
  return `https://${network}.infura.io/v3/${infuraKey}`;
}

let privateKey = process.env.PK || "";
const accounts = privateKey
  ? [
    privateKey,
    ]
  : undefined;

module.exports = {
  defaultNetwork: "hardhat",
  gasReporter: {
    showTimeSpent: true,
    currency: "USD",
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        }
      },
    },
    local: {
      url: 'http://localhost:8545',
    },
    polygon: {
      url: nodeUrl("polygon-mainnet"),
      gasPrice: 40000000000,
      timeout: 50000
    },
    mumbai: {
      url: nodeUrl("polygon-mumbai"),
      gasPrice: 40000000000,
      timeout: 50000
    },
    coverage: {
      url: "http://127.0.0.1:8555",
    },
  },
  solidity: {
    version: "0.8.11",
    settings: {
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    coverage: "./coverage",
    coverageJson: "./coverage.json",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 50000,
  },
  namedAccounts: {
    deployer: {
      default: 0,
      mumbai: "0x8f96BFc80BC3B7D881767253EDb7A76429B7EC6B",
    },
    feeRecipient: {
      default: 1,
      mumbai: "0x8f96BFc80BC3B7D881767253EDb7A76429B7EC6B",
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
