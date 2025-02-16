const { expect } = require("chai");
const { ethers } = require("hardhat");

const DECIMALS = (10 ** 18).toString().replaceAll('1','0').substring(0,18);

describe("Loan Contract", function () {
    let loan;
    let oracle;
    let testToken;
    let platform;
    let lender;
    let borrower;

    const principalAmount = ethers.parseUnits("30", 18); // 30 Apple stocks
    const principalTokenId = 1;
    const interestRate = ethers.parseUnits("5.56",3); // 5.56%
    const risk = 140000; // 140%

    beforeEach(async function () {
        const Oracle = await ethers.getContractFactory("Oracle");
        const TestToken = await ethers.getContractFactory("MockERC20");
        const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
        const LoanContract = await ethers.getContractFactory("Loan");

        [platform, lender, borrower, collateralTokenAddress] = await ethers.getSigners();

        stablecoinPriceFeed = await MockPriceFeed.deploy(6, ethers.parseUnits("1", 6));  // 1$ but with 6 decimals
        await stablecoinPriceFeed.waitForDeployment();


        oracle = await Oracle.deploy(platform.address);
        await oracle.waitForDeployment();

        testToken = await TestToken.deploy("TestToken", "TST",100000000000000);
        await testToken.waitForDeployment();

        // Set token price in oracle
        await oracle.connect(platform).updateTokenPrice(principalTokenId, ethers.parseUnits("244.6",18)); // 244.60$
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
        await testToken.mint(borrower.address, ethers.parseUnits("50000", 6)); // Mock 50_000 USDT

    });

    it("Should create a loan and deposit collateral", async function () {
        /**
         * Testing loaning a 30 Apple stocks (principalAmount) with 5.56% interest rate
         * and 140% risk at 120% liquidation treshold. Collateral is price $APPL 244.60$ * 30 * 140% = 10273.2$
         * Borrower should deposit 10273.2$ worth of stablecoin as collateral. 
         * Stablecoin USDT is used as collateral. Has 6 decimals.
         */
        const collateralAmount = ethers.parseUnits("10273.2", 6);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.target, collateralAmount);
        
        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        expect((await loan.scaledCollateralAmount()).toString()).to.equal("102732"+DECIMALS.substring(0,17));
    });

    it("Should allow repayment", async function () {
        const collateralAmount = ethers.parseUnits("10273.2", 6);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.target, collateralAmount);

        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        const repaymentAmount = ethers.parseUnits("500", 6); // 500 USDT

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.target, repaymentAmount);

        // Repay loan
        await loan.connect(borrower).repay(repaymentAmount);

        expect(await loan.scaledCollateralAmount()).to.equal("107732"+DECIMALS.substring(0,17));
    });

    it("Should liquidate loan if collateral value is below threshold", async function () {
        const collateralAmount = ethers.parseUnits("10273.2", 6);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.target, collateralAmount);

        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        // Set borrwed token price to a higher price
        await oracle.connect(platform).updateTokenPrice(principalTokenId, ethers.parseUnits("500",18)); // 500 USDT

        // Liquidate loan
        await loan.connect(lender).liquidate();

        expect(await loan.scaledCollateralAmount()).to.equal(0);
    });
});
