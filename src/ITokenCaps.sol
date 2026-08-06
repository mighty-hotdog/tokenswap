// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/**
 * @title   ITokenCaps
 * @author  mighty_hotdog
 *          created 05Aug2026
 * @notice  Interface. Defines struct for token caps.
 * @dev     Intended for use in the sample ERC20Token contract. However use in other contracts is not restricted.
 * @dev     The various `TimeCap` values are in Unix time, to be compared vs block.timestamp.
 *          This is obviously a SECURITY VULNERABILITY.
 *          TO BE FIXED.
 */
interface ITokenCaps {
    struct TokenCaps {
        uint256 capValueCap;
        uint256 capTimeCap;
        uint256 burnValueCap;
        uint256 burnTimeCap;
        uint256 mintValueCap;
        uint256 mintTimeCap;
        uint256 transferValueCap;
        uint256 transferTimeCap;
    }
}