// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockV3Aggregator {
    uint8 private _decimals;
    int256 public latestAnswer;

    constructor(uint8 _decimal, int256 _initialAnswer) {
        _decimals = _decimal;
        latestAnswer = _initialAnswer;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }


    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, latestAnswer, 0, block.timestamp, 0);
    }

    function updatePrice(int256 _newPrice) external {
        latestAnswer = _newPrice;
    }
}
