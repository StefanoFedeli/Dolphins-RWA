const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Oracle Contract", function () {
    let Oracle, oracle, owner, addr1;
    let stablecoinPriceFeed, tokenizedBond;

    before(async function () {
        [owner, addr1] = await ethers.getSigners();

        // Mock Chainlink Price Feed
        const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
        stablecoinPriceFeed = await MockPriceFeed.deploy(8, ethers.parseUnits("1", 8)); // $1.00 (8 decimals)

        // Deploy Oracle contract
        Oracle = await ethers.getContractFactory("Oracle");
        oracle = await Oracle.deploy(owner.address);

        await stablecoinPriceFeed.waitForDeployment();
        await oracle.waitForDeployment();

        // Sample tokenized bond identifier
        tokenizedBond = "1021";
    });

    it("Should return correct stablecoin price from Chainlink", async function () {
        await oracle.connect(owner).setStablecoinOracle("0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6",stablecoinPriceFeed.target);
        const price = await oracle.getStablecoinPrice("0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6");

        expect(price).to.equal(ethers.parseUnits("1", 8)); // Expecting $1.00
    });

    it("Should allow owner to update tokenized bond price", async function () {
        await oracle.connect(owner).updateTokenPrice(tokenizedBond, ethers.parseUnits("100", 18)); // $100
        const bondPrice = await oracle.getTokenPrice(tokenizedBond);
        expect(bondPrice).to.equal(ethers.parseUnits("100", 18));
    });

    it("Should not allow non-owner to update bond price", async function () {
        await expect(
            oracle.connect(addr1).updateTokenPrice(tokenizedBond, ethers.parseUnits("50", 18))
        ).to.be.reverted;
    });

    it("Should return 0 for unregistered tokenized bonds", async function () {
        await expect( oracle.getTokenPrice("1")).to.be.reverted;
    });
});
