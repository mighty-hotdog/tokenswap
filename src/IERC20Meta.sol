// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

interface IERC20Meta {
    error ERC20Meta_NameLongerThan32Bytes();
    error ERC20Meta_SymbolLongerThan32Bytes();

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}