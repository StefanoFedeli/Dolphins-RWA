// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";  // ✅ Import Hardhat's console for debugging
import "./Oracle.sol";


contract Loan is ReentrancyGuard, Ownable {

    address public lender;
    address public borrower;
    
    uint256 public principalTokenAmount;
    uint256 public principalTokenId;
    uint256 public collateralTokenAmount;
    IERC20 public collateralToken;

    Oracle public oracle;

    uint256 public interestRate;
    uint256 public startTime;
    uint256 public liquidationTreashold; // in basis points (10000 = 100%)

    bool public isFrozen;

    event LoanCreated(address indexed lender, address indexed borrower, uint256 principal, uint256 interestRate);
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event PaymentMade(address indexed borrower, uint256 amount, uint256 timestamp);
    event LoanLiquidated(address indexed lender);
    event ContractFrozen();

    constructor(
        address _lender,
        address _borrower,
        address _collateralToken,
        address _platform,
        address _oracle,
        uint256 _principal,
        uint256 _principalTokenId,
        uint256 _interestRate,
        uint256 _risk // 14000 = 140% by default
    ) ReentrancyGuard() Ownable(_platform){
        lender = _lender;
        borrower = _borrower;
        oracle = Oracle(_oracle);

        principalTokenAmount = _principal;
        principalTokenId = _principalTokenId;
        collateralToken = IERC20(_collateralToken);
        collateralTokenAmount = (oracle.getTokenPrice(principalTokenId)*_principal) + ((oracle.getTokenPrice(principalTokenId)*_principal) * (_risk / 100));
        liquidationTreashold = _risk - 2000 ; // 12000 = 120% by default
        interestRate = _interestRate;
        startTime = 0;
        isFrozen = false;
    }

    function depositCollateral(uint256 _collateral) external nonReentrant {
        require(_collateral >= collateralTokenAmount, "Insufficient collateral");
        require(!isFrozen, "Contract is frozen");

        collateralToken.transferFrom(msg.sender, address(this), _collateral);
        collateralTokenAmount = _collateral;
        startTime = block.timestamp;
        emit CollateralDeposited(msg.sender, _collateral);
    }
    
    // Debt can be closed only if loan is in default or by platform providing proof of re-payment.
    function closeDebt() external nonReentrant onlyOwner {
        uint256 usdPriceCollateral = oracle.getStablecoinPrice(address(collateralToken));
        uint256 usdPricePrincipal = oracle.getTokenPrice(principalTokenId);
        require(usdPriceCollateral > 0 && usdPricePrincipal > 0, "Price not available");
        require(usdPriceCollateral * collateralTokenAmount < liquidationTreashold * usdPricePrincipal * principalTokenAmount / 10000, "Debt cannot be closed yet");

        isFrozen = true;
        emit ContractFrozen();
    }

    function repay(uint256 _amount) external nonReentrant {
        require(!isFrozen, "Contract is frozen");
        require(startTime > 0, "Collateral has not been deposited yet");

        collateralToken.transferFrom(borrower, address(this), _amount);
        collateralTokenAmount += _amount;
        emit PaymentMade(borrower, _amount, block.timestamp);
    }

    /**
     * @dev Calculates the interest for a loan.
     * @return The calculated interest amount (with 18 decimals precision).
     */
    function calculateInterest()
        public
        view
        returns (uint256) {
        uint256 usdPricePrincipal = oracle.getTokenPrice(principalTokenId);
        uint256 duration = block.timestamp - startTime;
        uint256 interest = (usdPricePrincipal * principalTokenAmount * interestRate  * duration / 365 days);
        return interest;
    }

    function liquidate() external nonReentrant {
        // Liquidation can be done if the contract is frozen or the collateral value is below the liquidation threshold
        uint256 usdPriceCollateral = oracle.getStablecoinPrice(address(collateralToken));
        uint256 usdPricePrincipal = oracle.getTokenPrice(principalTokenId);
        require(usdPriceCollateral > 0 && usdPricePrincipal > 0, "Price not available");
        require(isFrozen || (usdPriceCollateral * collateralTokenAmount < liquidationTreashold * usdPricePrincipal * principalTokenAmount / 10000), "Cannot liquidate yet");

        collateralToken.transfer(lender, collateralTokenAmount);
        collateralTokenAmount = 0;
        emit LoanLiquidated(lender);
    }
}
