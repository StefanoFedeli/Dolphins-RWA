const { ethers } = require("hardhat");
const { vars } = require("hardhat/config");
const OracleModule = require("../ignition/modules/Oracle");
const LoanFactoryModule = require("../ignition/modules/LoanFactory")

async function main() {
    const signers = new ethers.Wallet(vars.get("PLATFORM_PRIVATE_KEY"));

    const { oracle } = await hre.ignition.deploy(OracleModule, {
      parameters: { OracleModule: { platformAddress: signers.address }},
    });

    const { factory } = await hre.ignition.deploy(LoanFactoryModule, {
      parameters: { LoanFactoryModule: {oracleAddress: oracle.target, platformAddress: signers.address}},
    });
  
    console.log(`Deployed to: ${oracle.target}, ${factory.target}`);
}

main().catch(console.error);