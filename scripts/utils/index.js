const hre = require("hardhat");
const ethers = hre.ethers;
require("dotenv").config();

const resetFork = async (networkName, blockNumber=undefined) => {
  await hre.network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: process.env[networkName],
          blockNumber,
        },
      },
    ],
  });
};

const getExpContract = async (attackName) => {
  const factory = await ethers.getContractFactory(`contracts/${attackName}/Exp.sol:Exp`);
  return await (await factory.deploy()).deployed();
};

module.exports = {
  resetFork,
  getExpContract,
};
