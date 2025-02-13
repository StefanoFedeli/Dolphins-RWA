const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Loan Contract", function () {
    let Loan;
    let loan;
    let oracle;
    let testToken;
    let platform;
    let lender;
    let borrower;
    let collateralTokenAddress;

    const principalAmount = ethers.parseUnits("1", 18);
    const principalTokenId = 1;
    const interestRate = ethers.parseUnits("500",0); // 5%
    const risk = 14000; // 140%

    beforeEach(async function () {
        const Oracle = await ethers.getContractFactory("Oracle");
        const TestToken = await ethers.getContractFactory("MockERC20");
        const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
        const LoanContract = await ethers.getContractFactory("Loan");

        [platform, lender, borrower, collateralTokenAddress] = await ethers.getSigners();

        stablecoinPriceFeed = await MockPriceFeed.deploy(8, ethers.parseUnits("1", 8)); 
        await stablecoinPriceFeed.waitForDeployment();


        oracle = await Oracle.deploy(platform.address);
        await oracle.waitForDeployment();

        testToken = await TestToken.deploy("TestToken", "TST",100000000000000);
        await testToken.waitForDeployment();

        // Set token price in oracle
        await oracle.connect(platform).updateTokenPrice(principalTokenId, ethers.parseUnits("2",0)); // $2
        await oracle.connect(platform).setStablecoinOracle(testToken.target,stablecoinPriceFeed.target);

        loan = await LoanContract.deploy(
            lender.address,
            borrower.address,
            testToken.target,
            platform.address,
            oracle.target,
            principalAmount,
            principalTokenId,
            interestRate,
            risk
        );
        await loan.waitForDeployment();

        // Mint test tokens to borrower
        await testToken.mint(borrower.address, ethers.parseUnits("5000", 18));

    });

    it("Should create a loan and deposit collateral", async function () {
        const collateralAmount = ethers.parseUnits("350", 18);
        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.target, collateralAmount);
        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        expect(await loan.collateralTokenAmount()).to.equal(collateralAmount);
    });

    it("Should calculate interest correctly", async function () {
        const collateralAmount = ethers.parseUnits("1400", 18);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.target, collateralAmount);

        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        // Fast forward time
        await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]); // 1 year
        await ethers.provider.send("evm_mine");

        const interest = await loan.calculateInterest();
        expect(interest).to.be.gt(0);
    });

    it("Should allow repayment", async function () {
        const collateralAmount = ethers.parseUnits("1400", 18);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.target, collateralAmount);

        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        const repaymentAmount = ethers.parseUnits("500", 18);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.target, repaymentAmount);

        // Repay loan
        await loan.connect(borrower).repay(repaymentAmount);

        expect(await loan.collateralTokenAmount()).to.equal(collateralAmount + repaymentAmount);
    });

    it("Should liquidate loan if collateral value is below threshold", async function () {
        const collateralAmount = ethers.parseUnits("1400", 18);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.target, collateralAmount);

        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        // Set collateral token price to a lower value
        await oracle.connect(platform).updateTokenPrice(principalTokenId, ethers.parseUnits("0.5", 18));

        // Liquidate loan
        await loan.connect(lender).liquidate();

        expect(await loan.collateralTokenAmount()).to.equal(0);
    });
});
