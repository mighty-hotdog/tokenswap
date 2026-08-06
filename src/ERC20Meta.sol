// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {IERC20Meta} from "./IERC20Meta.sol";
import {StringUtils} from "./StringUtils.sol";

/*
 * @title   ERC20Meta
 * @author  mighty_hotdog
 *          created 17Jul2026
 * @notice  ERC20Meta is an abstract contract that implements the optionals specified in the ERC20 standard.
 * @dev     NAME, SYMBOL, DECIMALS declared private so that compiler doesn't autogenerate accessor functions for them
 *          because the standard already specifies their accessor functions that are required for implementation.
 */
abstract contract ERC20Meta is IERC20Meta {
    using StringUtils for bytes32;
    using StringUtils for string;

    //////////////////////////////////////////////////
    // state variables
    //////////////////////////////////////////////////
    bytes32 private immutable NAME;
    bytes32 private immutable SYMBOL;
    uint8 private constant DECIMALS = 18;

    //////////////////////////////////////////////////
    // constructor
    //////////////////////////////////////////////////
    constructor(string memory name_, string memory symbol_) {
        bytes memory n = bytes(name_);
        bytes memory s = bytes(symbol_);
        if (n.length > 32) {revert ERC20Meta_NameLongerThan32Bytes();}
        if (s.length > 32) {revert ERC20Meta_SymbolLongerThan32Bytes();}
        if (n.length == 0) {NAME = bytes32(0);} else {NAME = name_.toBytes32();}
        if (s.length == 0) {SYMBOL = bytes32(0);} else {SYMBOL = symbol_.toBytes32();}
    }

    //////////////////////////////////////////////////
    // external/public functions
    //////////////////////////////////////////////////
    function name() public virtual view returns (string memory) {
        return NAME.toString();
    }

    function symbol() public virtual view returns (string memory) {
        return SYMBOL.toString();
    }

    function decimals() public virtual view returns (uint8) {
        return DECIMALS;
    }
}