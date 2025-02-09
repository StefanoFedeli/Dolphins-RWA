// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Loan is ReentrancyGuard, Ownable {

    address public lender;
    address public borrower;
    
    IERC20 public stablecoin;
    
    uint256 public principal;
    uint256 public collateral; 
    uint256 public interestRate; 
    uint256 public startTime; 
    uint256 public duration; 
    uint256 public lastPaymentTime; 
    uint256 public maximumInterestDue;
    uint256 public paidInterest; 
    uint256 public LIQUIDATION_THRESHOLD;
    bool public isFrozen;

    uint256 public constant GRACE_PERIOD = 2 days;

    event LoanCreated(address indexed lender, address indexed borrower, uint256 principal, uint256 interestRate);
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event PaymentMade(address indexed borrower, uint256 amount, uint256 timestamp);
    event LoanLiquidated(address indexed lender);
    event ContractFrozen();
    event ContractDestroyed();

    constructor(
        address _lender,
        address _borrower,
        address _stablecoin,
        address _platform,
        uint256 _principal,
        uint256 _interestRate,
        uint256 _duration,
        uint256 _risk
    ) ReentrancyGuard() Ownable(_platform){
        lender = _lender;
        borrower = _borrower;
        stablecoin = IERC20(_stablecoin);
        principal = _principal;
        duration = _duration;
        maximumInterestDue = principal * _interestRate * _duration / (365 days * 10000);
        paidInterest = 0;
        LIQUIDATION_THRESHOLD = _risk;
        isFrozen = false;
    }

    function depositCollateral(uint256 _collateral) external nonReentrant {
        require(msg.sender == borrower, "Only borrower can deposit collateral");
        require(_collateral >= (principal * LIQUIDATION_THRESHOLD) / 10000, "Insufficient collateral");
        require(!isFrozen, "Contract is frozen");

        stablecoin.transferFrom(msg.sender, address(this), _collateral);
        collateral = _collateral;
        emit CollateralDeposited(msg.sender, _collateral);
    }

    function closeDebt() external nonReentrant onlyOwner {
        // Debt can be closed only if all totalInterestDue has been paid or if all the interest accrued to date has been paid
        require(paidInterest >= maximumInterestDue || calculateInterest() < paidInterest, "Debt cannot be closed yet");

        isFrozen = true;
        emit ContractFrozen();
    }

    function repayInterest(uint256 _amount) external nonReentrant {
        require(block.timestamp <= startTime + duration + GRACE_PERIOD, "Loan is in default");
        require(!isFrozen, "Contract is frozen");

        stablecoin.transferFrom(borrower, lender, _amount);
        paidInterest += _amount;
        emit PaymentMade(borrower, _amount, block.timestamp);
    }

    function calculateInterest() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startTime;
        return (principal * interestRate * timeElapsed) / (365 days * 10000);
    }

    function liquidate() external nonReentrant {
        require(block.timestamp > startTime + duration + GRACE_PERIOD, "Loan is not yet liquidatable");
        require(!isFrozen, "Contract is frozen");

        stablecoin.transferFrom(borrower, lender, collateral);
        emit LoanLiquidated(lender);
    }
}
