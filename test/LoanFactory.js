const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LoanFactory Contract", function () {
    let loanFactory;
    let oracle;
    let testToken;
    let platform;
    let lender;
    let borrower;

    const principalAmount = ethers.parseUnits("1000", 18);
    const principalTokenId = 1;
    const interestRate = ethers.parseUnits("5", 16); // 5%
    const risk = 140000; // 140%

    beforeEach(async function () {
        const Oracle = await ethers.getContractFactory("Oracle");
        const TestToken = await ethers.getContractFactory("MockERC20");
        const LoanFactoryContract = await ethers.getContractFactory("LoanFactory");
        const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");

        [platform, lender, borrower] = await ethers.getSigners();

        // Deploy Mock Chainlink Price Feed
        stablecoinPriceFeed = await MockPriceFeed.deploy(6, ethers.parseUnits("1", 6)); 
        await stablecoinPriceFeed.waitForDeployment();

        // Deploy Oracle contract
        oracle = await Oracle.deploy(platform.address);
        await oracle.waitForDeployment();

        // Deploy test token contract
        testToken = await TestToken.deploy("TestToken", "TST",5000);
        await testToken.waitForDeployment();

        // Deploy LoanFactory contract
        loanFactory = await LoanFactoryContract.deploy(oracle.target, platform.address);
        await loanFactory.waitForDeployment();

        // Set token price in oracle
        await oracle.connect(platform).updateTokenPrice(principalTokenId, ethers.parseUnits("1", 18));
        await oracle.connect(platform).setStablecoinOracle(testToken.target,stablecoinPriceFeed.target);
    });

    it("Should deploy the LoanFactory contract", async function () {
        expect(loanFactory.target).to.properAddress;
    });

    it("Should create a new Loan contract", async function () {
        const tx = await loanFactory.connect(platform).createLoan(
            lender.address,
            borrower.address,
            testToken.target,
            principalAmount,
            principalTokenId,
            interestRate,
            risk
        );


        const receipt = await tx.wait();
        const loanAddress = receipt.logs?.filter((x) => { return x.fragment?.name == "LoanCreated"; })[0].args?.loanAddress;

        const Loan = await ethers.getContractFactory("Loan");
        const loan = Loan.attach(loanAddress);

        expect(await loan.lender()).to.equal(lender.address);
        expect(await loan.borrower()).to.equal(borrower.address);
        expect(await loan.scaledPrincipalAmount()).to.equal(principalAmount);
        expect(await loan.interestRate()).to.equal(interestRate);
    });

    it("Should emit LoanCreated event", async function () {
        await expect(loanFactory.connect(platform).createLoan(
            lender.address,
            borrower.address,
            testToken.target,
            principalAmount,
            principalTokenId,
            interestRate,
            risk
        ))
        .to.emit(loanFactory, "LoanCreated");
    });

    it("Should revert if not called by the owner", async function () {
        await expect(
            loanFactory.connect(borrower).createLoan(
                lender.address,
                borrower.address,
                testToken.target,
                principalAmount,
                principalTokenId,
                interestRate,
                risk
            )
        ).to.be.reverted;
    });
});
