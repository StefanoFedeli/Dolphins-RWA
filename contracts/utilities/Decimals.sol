// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DecimalUtility {

    /**
     * @dev Fetches the number of decimals from an ERC-20 token.
     * @param token The address of the ERC-20 token.
     * @return The number of decimals used by the token.
     */
    function getTokenDecimals(address token) internal view returns (uint8) {
        return IERC20Extented(token).decimals();
    }

    /**
     * @dev Converts an amount to 18 decimals for internal calculations.
     * @param token The address of the ERC-20 token.
     * @param amount The amount to convert.
     * @return The amount converted to 18 decimals.
     */
    function to18Decimals(address token, uint256 amount) internal view returns (uint256) {
        uint8 decimals = getTokenDecimals(token);
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount / (10**(decimals - 18));
        } else {
            return amount * (10**(18 - decimals));
        }
    }

    /**
     * @dev Converts an amount from 18 decimals back to the token's native decimal precision.
     * @param token The address of the ERC-20 token.
     * @param amount The amount to convert.
     * @return The amount converted from 18 decimals.
     */
    function from18Decimals(address token, uint256 amount) internal view returns (uint256) {
        uint8 decimals = getTokenDecimals(token);
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount * (10**(decimals - 18));
        } else {
            return amount / (10**(18 - decimals));
        }
    }
}

abstract contract IERC20Extented is IERC20 {
    function decimals() public view virtual returns (uint8);
}