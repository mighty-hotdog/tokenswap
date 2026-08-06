// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {IERC1271} from "./IERC1271.sol";

/*
 * @title   SimpleSignatureChecker
 * @notice  Library that implements a basic signature check function.
 * @author  mighty_hotdog
 *          created 28Jul2026
 *          completed 29Jul2026
 *          modified 01Aug2026
                added MalformedSignature() custom error to handle ecrecover() returning address(0)
                fixed bugs: modified functions from `external` to `internal`
            todos:
                1. expand library to include more utilities useful for signature checking
                2. remove all custom errors and let reverts just bubble up errors to the calling function for error handling
 * @dev     This library is designed to revert on any signature check failures. The functions return `true` only if signature is valid.
 * @dev     Assumptions:
 *          - `signature` input param contains just 1 signature.
 *          - `vrs` values represent a secp256k1 signature.
 *          - input param `signature` is a standard 65 byte vrs signature.
 *          - the IERC1271.isValidSignature() call to the `addrToCheck` contract expects a standard 65 byte vrs signature.
 */
library SimpleSignatureChecker {
    error SimpleSignatureChecker_InvalidAddressToCheck();
    error SimpleSignatureChecker_InvalidVValue();
    error SimpleSignatureChecker_InvalidSValue();
    error SimpleSignatureChecker_MalformedSignature();
    error SimpleSignatureChecker_checkSignatureFailed();
    error SimpleSignatureChecker_InvalidReturnValue();
    error SimpleSignatureChecker_InvalidSignature();
    bytes4 public constant MAGIC_VALUE = IERC1271.isValidSignature.selector;
    uint256 public constant S_BOUNDARY = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;
    function isValidSignature(address addrToCheck, bytes32 dataHash, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        // safety checks + early exit
        if (addrToCheck == address(0)) {revert SimpleSignatureChecker_InvalidAddressToCheck();}
        if (v == 0 || v == 1) {v += 27;}    // v is in raw cryptographic form: convert to standard EVM
        if (v != 27 && v != 28) {revert SimpleSignatureChecker_InvalidVValue();}
        if (uint256(s) > S_BOUNDARY) {revert SimpleSignatureChecker_InvalidSValue();}

        if (addrToCheck.code.length == 0) {
            address extractedSigner = ecrecover(dataHash, v, r, s);
            if (extractedSigner == address(0)) {revert SimpleSignatureChecker_MalformedSignature();}
            if (extractedSigner != addrToCheck) {revert SimpleSignatureChecker_InvalidSignature();}
            return true;
        } else {
            // encode vrs values to standard 65 bytes signature
            // make staticcall to isValidSignature() on addrToCheck
            // check return value
            bytes memory vrsSignature = new bytes(65);
            assembly {
                mstore(add(vrsSignature, 32), r)    // writes `r` value into 2nd 32 bytes
                mstore(add(vrsSignature, 64), s)    // writes `s` value into 3rd 32 bytes
                mstore(add(vrsSignature, 65), v)    // writes `v` value into 65th byte
            }
            (bool success, bytes memory returnData) = 
                addrToCheck.staticcall(
                    abi.encodeWithSelector(MAGIC_VALUE, dataHash, vrsSignature));
            if (!success) {revert SimpleSignatureChecker_checkSignatureFailed();}
            if (returnData.length < 32) {revert SimpleSignatureChecker_InvalidReturnValue();}
            if (abi.decode(returnData, (bytes4)) != MAGIC_VALUE) {revert SimpleSignatureChecker_InvalidSignature();}
            return true;
        }
    }
    function isValidSignature(address addrToCheck, bytes32 dataHash, bytes memory signature) internal view returns (bool) {
        // safety checks + early exit
        if (addrToCheck == address(0)) {revert SimpleSignatureChecker_InvalidAddressToCheck();}
        if (signature.length != 65) {revert SimpleSignatureChecker_InvalidSignature();}

        if (addrToCheck.code.length == 0) {
            // decode signature to produce the vrs values
            // recover actual signer using ecrecover()
            // compare vs addrToCheck
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 32))
                s := mload(add(signature, 64))
                v := byte(0, mload(add(signature, 65)))
            }
            // more safety checks + early exit
            if (v == 0 || v == 1) {v += 27;}    // v is in raw cryptographic form: convert to standard EVM
            if (v != 27 && v != 28) {revert SimpleSignatureChecker_InvalidVValue();}
            if (uint256(s) > S_BOUNDARY) {revert SimpleSignatureChecker_InvalidSValue();}

            address extractedSigner = ecrecover(dataHash, v, r, s);
            if (extractedSigner == address(0)) {revert SimpleSignatureChecker_MalformedSignature();}
            if (extractedSigner != addrToCheck) {revert SimpleSignatureChecker_InvalidSignature();}
            return true;
        } else {
            // make staticcall to isValidSignature() on addrToCheck
            // safety checks:
            //      1. return bool is true (ie: success)
            //      2. return data length >= 32 (ie: valid return data and not historical garbage left in local memory scratchpad)
            // check return value
            (bool success, bytes memory returnData) = 
                addrToCheck.staticcall(
                    abi.encodeWithSelector(MAGIC_VALUE, dataHash, signature));
            if (!success) {revert SimpleSignatureChecker_checkSignatureFailed();}
            if (returnData.length < 32) {revert SimpleSignatureChecker_InvalidReturnValue();}
            if (abi.decode(returnData, (bytes4)) != MAGIC_VALUE) {revert SimpleSignatureChecker_InvalidSignature();}
            return true;
        }
    }
}