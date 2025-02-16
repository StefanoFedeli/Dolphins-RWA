// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Loan.sol";
import "./Oracle.sol";

contract LoanFactory is Ownable {
    address public oracleAddress;
    address public platform;
    mapping (uint256 => address) public loans;
    uint256 public loanCount;

    event LoanCreated(address indexed loanAddress, address indexed lender, address indexed borrower, uint256 principal, uint256 interestRate);

    constructor(address _oracleAddress, address _platform) Ownable(_platform) {
        oracleAddress = _oracleAddress;
        platform = _platform;
    }

    function setOracleAddress(address _oracleAddress) external onlyOwner {
        oracleAddress = _oracleAddress;
    }

    function createLoan(
        address _lender,
        address _borrower,
        address _collateralToken,
        uint256 _principal,
        uint256 _principalTokenId,
        uint256 _interestRate,
        uint256 _risk
    ) external onlyOwner returns (address) {
        Loan newLoan = new Loan(
            _lender,
            _borrower,
            _collateralToken,
            platform,
            oracleAddress,
            _principal,
            _principalTokenId,
            _interestRate,
            _risk
        );

        emit LoanCreated(address(newLoan), _lender, _borrower, _principal, _interestRate);
        loans[loanCount] = address(newLoan);
        loanCount += 1;
        return address(newLoan);
    }
}
