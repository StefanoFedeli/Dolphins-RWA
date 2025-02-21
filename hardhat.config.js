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
      accounts: [vars.get("SEPOLIA_PRIVATE_KEY")],
    },
  },
};
