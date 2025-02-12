// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Oracle is Ownable {
    // Mapping for tokenized assets by IDs to prices (manual update)
    mapping(uint256 => uint256) private blueDolphinTokens;

    // Mapping for stablecoin price feeds from Chainlink
    mapping(address => AggregatorV3Interface) private stablecoinOracles;

    event TokenPriceUpdated(uint256 indexed tokenID, uint256 price);
    event StablecoinOracleSet(address indexed stablecoin, address oracle);

    constructor(address _platformWallet) Ownable(_platformWallet) {}

    /**
     * @dev Updates the price of a tokenized tokenized asset (only callable by owner).
     * @param tokenID ID of the BlueDolphin Token.
     * @param price New price in USD (with 18 decimals precision).
     */
    function updateTokenPrice(uint256 tokenID, uint256 price) external onlyOwner {
        require(price > 0, "Invalid price");
        blueDolphinTokens[tokenID] = price;
        emit TokenPriceUpdated(tokenID, price);
    }

    /**
     * @dev Returns the latest price of a tokenized asset.
     * @param tokenID ID of the tokenized asset.
     * @return price in USD (18 decimals precision).
     */
    function getTokenPrice(uint256 tokenID) external view returns (uint256) {
        require(blueDolphinTokens[tokenID] > 0, "Price not available");
        return blueDolphinTokens[tokenID];
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
