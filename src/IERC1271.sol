// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/**
 * @title   IERC1271
 * @notice  Interface for the ERC1271 standard, which defines a method for smart contracts accounts (which can own
 *          tokens but cannot hold private keys) to validate signatures that originate from them.
 * @author  mighty_hotdog
 *          created 24Jul2026
 *          modified 01Aug2026
                added interface natspec
            todos:
                1. add comments on how/where this interface is to be used/implemented.
 */
interface IERC1271 {
    function isValidSignature(bytes32 _hash, bytes memory signature) external view returns (bytes4 magicValue);
}