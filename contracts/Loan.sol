// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";  // ✅ Import Hardhat's console for debugging
import "./Oracle.sol";
import "./utilities/Decimals.sol"; // Import DecimalUtility contract


contract Loan is ReentrancyGuard, Ownable, DecimalUtility {

    uint256 public constant MULTIPLIER = 10 ** 18;  // Expected decimal places

    address public lender;
    address public borrower;
    
    uint256 public scaledPrincipalAmount; // Amount of Shares with 18 decimals
    uint256 public principalTokenId; // Share ID in Oracle Contract
    uint256 public scaledCollateralAmount; // Amount of collateral in Stablecoin (with 18 decimals) 
    IERC20 public collateralToken; // Which Stablecoin is used as collateral

    Oracle public oracle;

    uint256 public interestRate; // in basis points (5500 = 5.5%)
    uint256 public startTime;
    uint256 public liquidationTreashold; // in basis points (100000 = 100%)

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
        uint256 _principal, // 1000000 = 1 share, 18 decimals
        uint256 _principalTokenId,
        uint256 _interestRate, // in basis points (5500 = 5.5%)
        uint256 _risk // 140000 = 140% by default
    ) ReentrancyGuard() Ownable(_platform){
        require(_principal > 0 && _principal % MULTIPLIER == 0, "Only full shares are accepted");
        require(_risk > 20000, "Risk must be at least 20%");

        lender = _lender;
        borrower = _borrower;
        oracle = Oracle(_oracle);

        scaledPrincipalAmount = _principal;
        principalTokenId = _principalTokenId;

        collateralToken = IERC20(_collateralToken);
        // Calculate collateral amount with 18 decimals
        uint256 intermediate = oracle.getTokenPrice(principalTokenId) * _principal / oracle.getStablecoinPrice(_collateralToken);
        scaledCollateralAmount = intermediate * _risk / 10**5;
        liquidationTreashold = _risk - 20000 ; // 20% buffer
        interestRate = _interestRate;

        startTime = 0;
        isFrozen = false;
    }

    /**
     * 
     * @param _collateral Amount of collateral expressed with 6 decimals
     */
    function depositCollateral(uint256 _collateral) external nonReentrant {
        uint256 usdPriceCollateral = oracle.getStablecoinPrice(address(collateralToken));
        uint256 depositWithDecimals = to18Decimals(address(collateralToken), _collateral);
        require((depositWithDecimals * usdPriceCollateral) / 10**18 >= (scaledCollateralAmount * usdPriceCollateral) / 10**18, "Insufficient collateral");
        require(!isFrozen, "Contract is frozen");

        collateralToken.transferFrom(msg.sender, address(this), from18Decimals(address(collateralToken), depositWithDecimals));
        
        startTime = block.timestamp;
        emit CollateralDeposited(msg.sender, scaledCollateralAmount);
    }
    
    // Debt can be closed only if loan is in default or by platform providing proof of re-payment.
    function closeDebt() external nonReentrant onlyOwner {
        uint256 usdPriceCollateral = oracle.getStablecoinPrice(address(collateralToken));
        uint256 usdPricePrincipal = oracle.getTokenPrice(principalTokenId);
        require(usdPriceCollateral > 0 && usdPricePrincipal > 0, "Price not available");
        require(usdPriceCollateral * scaledCollateralAmount < liquidationTreashold * usdPricePrincipal * scaledPrincipalAmount / 10000, "Debt cannot be closed yet");

        isFrozen = true;
        emit ContractFrozen();
    }

    function repay(uint256 _amount) external nonReentrant {
        require(!isFrozen, "Contract is frozen");
        require(startTime > 0, "Collateral has not been deposited yet");

        uint256 usdPriceCollateral = oracle.getStablecoinPrice(address(collateralToken));
        uint256 repayWithDecimals = to18Decimals(address(collateralToken), _amount);

        collateralToken.transferFrom(borrower, address(this), _amount);
        scaledCollateralAmount += repayWithDecimals * 10**18 / usdPriceCollateral ;
        emit PaymentMade(borrower, _amount, block.timestamp);
    }

    function liquidate() external nonReentrant {
        // Liquidation can be done if the contract is frozen or the collateral value is below the liquidation threshold
        uint256 usdPriceCollateral = oracle.getStablecoinPrice(address(collateralToken));
        uint256 usdPricePrincipal = oracle.getTokenPrice(principalTokenId);
        uint256 collateralFullAmount =  usdPriceCollateral * scaledCollateralAmount / 10**18;
        console.log("collateralTokenAmount: ", collateralFullAmount);
        require(usdPriceCollateral > 0 && usdPricePrincipal > 0, "Price not available");
        require(isFrozen || collateralFullAmount < liquidationTreashold * usdPricePrincipal * scaledPrincipalAmount, "Cannot liquidate yet");

        collateralToken.transfer(lender, from18Decimals(address(collateralToken),scaledCollateralAmount));
        scaledCollateralAmount = 0;
        emit LoanLiquidated(lender);
    }
}
