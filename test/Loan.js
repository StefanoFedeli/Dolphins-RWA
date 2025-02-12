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

    const principalAmount = ethers.utils.parseUnits("1000", 18);
    const principalTokenId = 1;
    const interestRate = ethers.utils.parseUnits("5", 16); // 5%
    const risk = 14000; // 140%

    beforeEach(async function () {
        const Oracle = await ethers.getContractFactory("Oracle");
        const TestToken = await ethers.getContractFactory("ERC20");
        const LoanContract = await ethers.getContractFactory("Loan");

        [platform, lender, borrower, collateralTokenAddress] = await ethers.getSigners();

        oracle = await Oracle.deploy(platform.address);
        await oracle.deployed();

        testToken = await TestToken.deploy("TestToken", "TST");
        await testToken.deployed();

        loan = await LoanContract.deploy(
            lender.address,
            borrower.address,
            testToken.address,
            platform.address,
            oracle.address,
            principalAmount,
            principalTokenId,
            interestRate,
            risk
        );
        await loan.deployed();

        // Mint test tokens to borrower
        await testToken.mint(borrower.address, ethers.utils.parseUnits("2000", 18));

        // Set token price in oracle
        await oracle.connect(platform).updateTokenPrice(principalTokenId, ethers.utils.parseUnits("1", 18));
    });

    it("Should create a loan and deposit collateral", async function () {
        const collateralAmount = ethers.utils.parseUnits("1400", 18);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.address, collateralAmount);

        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        expect(await loan.collateralTokenAmount()).to.equal(collateralAmount);
    });

    it("Should calculate interest correctly", async function () {
        const collateralAmount = ethers.utils.parseUnits("1400", 18);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.address, collateralAmount);

        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        // Fast forward time
        await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]); // 1 year
        await ethers.provider.send("evm_mine");

        const interest = await loan.calculateInterest();
        expect(interest).to.be.gt(0);
    });

    it("Should allow repayment", async function () {
        const collateralAmount = ethers.utils.parseUnits("1400", 18);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.address, collateralAmount);

        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        const repaymentAmount = ethers.utils.parseUnits("500", 18);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.address, repaymentAmount);

        // Repay loan
        await loan.connect(borrower).repay(repaymentAmount);

        expect(await loan.collateralTokenAmount()).to.equal(collateralAmount.add(repaymentAmount));
    });

    it("Should liquidate loan if collateral value is below threshold", async function () {
        const collateralAmount = ethers.utils.parseUnits("1400", 18);

        // Approve tokens for loan contract
        await testToken.connect(borrower).approve(loan.address, collateralAmount);

        // Deposit collateral
        await loan.connect(borrower).depositCollateral(collateralAmount);

        // Set collateral token price to a lower value
        await oracle.connect(platform).updateTokenPrice(principalTokenId, ethers.utils.parseUnits("0.5", 18));

        // Liquidate loan
        await loan.connect(lender).liquidate();

        expect(await loan.collateralTokenAmount()).to.equal(0);
    });
});
