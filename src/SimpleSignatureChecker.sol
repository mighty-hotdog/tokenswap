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
            modified 06Aug2026
                added support for 64-byte ERC2098 compact signatures
                refactoring
            todos:
                1. expand library to include more utilities useful for signature checking
                2. remove all custom errors and let reverts just bubble up errors to the calling function for error handling
 * @dev     This library is designed to revert on any signature check failures. The functions return `true` only if signature is valid.
 * @dev     Assumptions:
 *          - `signature` input param contains just 1 signature.
 *          - `vrs` values represent a secp256k1 signature.
 *          - input param `signature` is either a standard 65 byte or a compact 64 byte signature.
 *          - the IERC1271.isValidSignature() call to the `addrToCheck` contract can handle a standard 65 byte vrs signature.
 */
library SimpleSignatureChecker {
    error SimpleSignatureChecker_InvalidAddressToCheck();
    error SimpleSignatureChecker_InvalidVValue();
    error SimpleSignatureChecker_InvalidSValue();
    error SimpleSignatureChecker_MalformedSignature();
    error SimpleSignatureChecker_checkSignatureFailed();
    error SimpleSignatureChecker_InvalidReturnValue();
    error SimpleSignatureChecker_InvalidSignature();
    error SimpleSignatureChecker_InvalidSignatureLength(uint256 expected, uint256 actual);
    uint8 public constant V_PARITY_UNSET = 27;
    uint8 public constant V_PARITY_SET = 28;
    uint256 public constant S_BOUNDARY = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;
    bytes4 public constant MAGIC_VALUE = IERC1271.isValidSignature.selector;
    uint256 public constant STANDARD_SIGNATURE_LENGTH = 65;
    uint256 public constant COMPACT_SIGNATURE_LENGTH = 64;
    function isValidSignature(address addrToCheck, bytes32 dataHash, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        // safety checks + early exit
        if (addrToCheck == address(0)) {revert SimpleSignatureChecker_InvalidAddressToCheck();}
        uint8 validV = validateVRSValues(v, s);

        if (addrToCheck.code.length == 0) {
            address extractedSigner = ecrecover(dataHash, validV, r, s);
            if (extractedSigner == address(0)) {revert SimpleSignatureChecker_MalformedSignature();}
            if (extractedSigner != addrToCheck) {revert SimpleSignatureChecker_InvalidSignature();}
            return true;
        } else {
            // encode vrs values to standard 65 bytes signature
            bytes memory signature = vrsEncode(validV, r, s);
            // make staticcall to isValidSignature() on addrToCheck
            return isValidSignature_ERC1271_Staticcall(addrToCheck, dataHash, signature);
        }
    }
    function isValidSignature(address addrToCheck, bytes32 dataHash, bytes memory signature) internal view returns (bool) {
        // safety checks + early exit
        if (addrToCheck == address(0)) {revert SimpleSignatureChecker_InvalidAddressToCheck();}
        uint256 len = signature.length;
        if (len != COMPACT_SIGNATURE_LENGTH && len != STANDARD_SIGNATURE_LENGTH) {
            revert SimpleSignatureChecker_InvalidSignatureLength(STANDARD_SIGNATURE_LENGTH, len);
        }

        if (addrToCheck.code.length == 0) {
            // decode signature to produce the vrs values
            (uint8 v, bytes32 r, bytes32 s) = vrsDecode(signature);
            // pump back into the vrs version of isValidSignature() to reuse its code
            return isValidSignature(addrToCheck, dataHash, v, r, s);

            /* deprecated original code
            if (v < 2) {v += V_PARITY_UNSET;}    // v is in raw cryptographic form: convert to standard EVM
            if (v != V_PARITY_UNSET && v != V_PARITY_SET) {revert SimpleSignatureChecker_InvalidVValue();}
            if (uint256(s) > S_BOUNDARY) {revert SimpleSignatureChecker_InvalidSValue();}

            // recover actual signer using ecrecover()
            address extractedSigner = ecrecover(dataHash, v, r, s);
            if (extractedSigner == address(0)) {revert SimpleSignatureChecker_MalformedSignature();}
            // compare vs addrToCheck
            if (extractedSigner != addrToCheck) {revert SimpleSignatureChecker_InvalidSignature();}
            return true;
            */
        } else {
            // make staticcall to isValidSignature() on addrToCheck
            return isValidSignature_ERC1271_Staticcall(addrToCheck, dataHash, signature);
        }
    }

    /**
     * @notice  validateVRSValues()
     *          Normalize `v` to standard EVM format. Reverts on invalid `v` or `s` values.
     * @dev     In the EVM, `vrs` values ALWAYS represent a secp256k1 ECDSA signature.
     */
    function validateVRSValues(uint8 v, bytes32 s) internal pure returns (uint8 validV) {
        if (uint256(s) > S_BOUNDARY) {revert SimpleSignatureChecker_InvalidSValue();}
        validV = v < 2 ? v + V_PARITY_UNSET : v;   // if `v` is in raw cryptographic form, convert to standard EVM
        if (validV != V_PARITY_UNSET && validV != V_PARITY_SET) {revert SimpleSignatureChecker_InvalidVValue();}
    }

    /**
     * @notice  ERC1271Staticcall()
     *          Helper function to make IERC1271.isValidSignature() staticcall to unknown target address to verify signature.
     */
    function isValidSignature_ERC1271_Staticcall(address target, bytes32 dataHash, bytes memory signature) internal view returns (bool) {
            (bool success, bytes memory returnData) = 
                target.staticcall(
                    abi.encodeWithSelector(MAGIC_VALUE, dataHash, signature));
            // check return values
            if (!success) {revert SimpleSignatureChecker_checkSignatureFailed();}
            // returnData.length >= 32 means it is valid return data and not historical garbage left in local memory scratchpad
            if (returnData.length < 32) {revert SimpleSignatureChecker_InvalidReturnValue();}
            if (abi.decode(returnData, (bytes4)) != MAGIC_VALUE) {revert SimpleSignatureChecker_InvalidSignature();}
            return true;
    }

    /**
     * @notice  vrsEncode()
     *          Encodes vrs values into a standard 65 bytes signature.
     */
    function vrsEncode(uint8 v, bytes32 r, bytes32 s) internal pure returns (bytes memory sig){
        uint8 validV = validateVRSValues(v, s);
        sig = new bytes(65);
        assembly ("memory-safe") {
            mstore(add(sig, 32), r)     // writes `r` value into 2nd 32 bytes
            mstore(add(sig, 64), s)     // writes `s` value into 3rd 32 bytes
            mstore8(add(sig, 96), validV)    // writes `v` value into 65th byte
        }
    }

    /**
     * @notice  vrsEncodeCompact()
     *          Encodes vrs values into a compact 64 bytes ERC2098 signature.
     */
    function vrsEncodeCompact(uint8 v, bytes32 r, bytes32 s) internal pure returns (bytes memory sig){
        uint8 validV = validateVRSValues(v, s);
        sig = new bytes(64);
        assembly ("memory-safe") {
            mstore(add(sig, 32), r)     // write `r` value into 2nd 32 bytes
            if eq(validV, V_PARITY_SET) {
                // toggle `s` value left-most bit if v is V_PARITY_SET
                s := xor(s, 0x8000000000000000000000000000000000000000000000000000000000000000)
            }
            mstore(add(sig, 64), s)     // write `s` value into 3rd 32 bytes
        }

        /* deprecated original code
        assembly {
            mstore(add(sig, 32), r)    // writes `r` value into 2nd 32 bytes
            mstore(add(sig, 64), s)    // writes `s` value into 3rd 32 bytes
        }
        if (v == V_PARITY_SET) {
            assembly {
                // toggles `s` value left-most bit, then writes into 3rd 32 bytes
                mstore(add(sig, 64), xor(s, 0x8000000000000000000000000000000000000000000000000000000000000000))
            }
        } else if (v != V_PARITY_UNSET) {revert SimpleSignatureChecker_InvalidVValue();}    // if v is not 28 or 27, revert
        */
    }

    /**
     * @notice  vrsDecode()
     *          Decodes signature into vrs values. Accepts both standard 65-byte and compact 64-byte ERC2098 signatures.
     * @dev     Assumes `sig` is a secp256k1 signature.
     */
    function vrsDecode(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        uint256 len = sig.length;
        if (len == STANDARD_SIGNATURE_LENGTH) {
            (v,r,s) = vrsDecodeStandard(sig);
        } else if (len == COMPACT_SIGNATURE_LENGTH) {
            (v,r,s) = vrsDecodeCompact(sig);
        } else {revert SimpleSignatureChecker_InvalidSignatureLength(STANDARD_SIGNATURE_LENGTH, len);}
    }

    /**
     * @notice  vrsDecodeStandard()
     *          Decodes standard 65-byte signature into vrs values.
     * @dev     Assumes `sig` is a secp256k1 signature.
     */
    function vrsDecodeStandard(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (sig.length != STANDARD_SIGNATURE_LENGTH) {
            revert SimpleSignatureChecker_InvalidSignatureLength(STANDARD_SIGNATURE_LENGTH, sig.length);
        }
        assembly ("memory-safe") {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            // `mload(add(sig, 96))` loads 32 bytes from `sig`
            // but `v` only occupies the 1st byte (on the left), with the rest being garbage
            // so use `shr()` to shift that 1st byte contents 248 bits to the right, equivalent to shifting right 31 bytes
            // this is cleaner and safer than the original "byte slicing" code
            v := shr(248, mload(add(sig, 96)))
        }
    }

    /**
     * @notice  vrsDecodeCompact()
     *          Decodes compact 64-byte ERC2098 signature into vrs values.
     * @dev     Assumes `sig` is a secp256k1 signature.
     */
    function vrsDecodeCompact(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (sig.length != COMPACT_SIGNATURE_LENGTH) {
            revert SimpleSignatureChecker_InvalidSignatureLength(COMPACT_SIGNATURE_LENGTH, sig.length);
        }
        assembly ("memory-safe") {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := V_PARITY_UNSET
            if and(s, 0x8000000000000000000000000000000000000000000000000000000000000000) {v := V_PARITY_SET}
            s := and(s, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
        }
    }
}