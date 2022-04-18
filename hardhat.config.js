require("@nomiclabs/hardhat-ethers");
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  network: {
    hardhat: {
      timeout: 300000,
    },
  },
  solidity: "0.8.13",
};
