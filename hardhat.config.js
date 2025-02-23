require("@nomicfoundation/hardhat-toolbox");
const { vars } = require("hardhat/config");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks: {
    hardhat: {
    },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${vars.get("SEPOLIA_ALCHEMY_API_KEY")}`,
      accounts: [vars.get("SEPOLIA_DEPLOYER_KEY")],
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: vars.get("ETHERSCAN_API_KEY")
  },
  sourcify: {
    // Disabled by default
    // Doesn't need an API key
    enabled: true
  }
};
