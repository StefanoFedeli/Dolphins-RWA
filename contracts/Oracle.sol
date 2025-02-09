// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Oracle is Ownable {
    // Mapping for tokenized bond prices (manual update)
    mapping(address => uint256) private bondPrices;

    // Mapping for stablecoin price feeds from Chainlink
    mapping(address => AggregatorV3Interface) private stablecoinOracles;

    event BondPriceUpdated(address indexed bond, uint256 price);
    event StablecoinOracleSet(address indexed stablecoin, address oracle);

    constructor(address _platformWallet) Ownable(_platformWallet) {}

    /**
     * @dev Updates the price of a tokenized bond (only callable by owner).
     * @param bond Address of the tokenized bond.
     * @param price New price in USD (with 18 decimals precision).
     */
    function updateBondPrice(address bond, uint256 price) external onlyOwner {
        require(price > 0, "Invalid price");
        bondPrices[bond] = price;
        emit BondPriceUpdated(bond, price);
    }

    /**
     * @dev Returns the latest price of a tokenized bond.
     * @param bond Address of the tokenized bond.
     * @return price in USD (18 decimals precision).
     */
    function getBondPrice(address bond) external view returns (uint256) {
        require(bondPrices[bond] > 0, "Price not available");
        return bondPrices[bond];
    }

    /**
     * @dev Sets the Chainlink oracle for a stablecoin.
     * @param stablecoin Address of the stablecoin.
     * @param oracle Address of the Chainlink price feed contract.
     */
    function setStablecoinOracle(address stablecoin, address oracle) external onlyOwner {
        require(oracle != address(0), "Invalid oracle address");
        stablecoinOracles[stablecoin] = AggregatorV3Interface(oracle);
        emit StablecoinOracleSet(stablecoin, oracle);
    }

    /**
     * @dev Returns the latest price of a stablecoin from Chainlink.
     * @param stablecoin Address of the stablecoin.
     * @return price in USD (with 18 decimals precision).
     */
    function getStablecoinPrice(address stablecoin) external view returns (uint256) {
        AggregatorV3Interface oracle = stablecoinOracles[stablecoin];
        require(address(oracle) != address(0), "Oracle not set for stablecoin");

        (, int256 price, , , ) = oracle.latestRoundData();
        require(price > 0, "Invalid price data");

        return uint256(price);
    }
}
