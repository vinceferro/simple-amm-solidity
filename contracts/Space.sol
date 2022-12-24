// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Space
 * @author Uniswap emh TheV - credits to uniswap Math
 */

library Space {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 a) internal pure returns (uint256) {
        uint256 sr = 0;
        if (a > 3) {
            sr = a;
            uint256 b = a / 2 + 1;
            while (b < sr) {
                sr = b;
                b = (a / b + b) / 2;
            }
        } else if (a != 0) {
            sr = 1;
        }
        return sr;
    }
}
