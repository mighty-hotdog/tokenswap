// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {IERC3009, IERC3009Cancel} from "./IERC3009.sol";
import {ERC20} from "./ERC20.sol";
import {SimpleSignatureChecker} from "./SimpleSignatureChecker.sol";

/**
 * @title   ERC3009
 * @notice  Implementation of ERC3009 standard for direct ERC20 token transfers (skipping approvals) via owner-originated signatures.
 * @author  mighty_hotdog
 *          created 03Aug2026
 *          modified 06Aug2026
 *              added comments to highlight ERC1271 support and that the `isValidSignature()` library function uses `staticcall`.
 * @dev     This implementation assumes the `vrs` signatures are secp256k1. The standard itself does not specify any particular scheme.
 * @dev     This contract Supports ERC1271 via the SimpleSignatureChecker library.
 *          To be noted that the `isValidSignature()` library function used in this contract performs a `staticcall` to do the signature
 *          checking. This guarantees that the unknown/untrusted contract being called cannot change blockchain state.
 */
abstract contract ERC3009 is IERC3009, ERC20 {
    // constants
    bytes32 internal constant DOMAIN_TYPEHASH = 
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = 
        keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");
    bytes32 internal constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH = 
        keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");
    bytes32 internal constant CANCEL_AUTHORIZATION_TYPEHASH = 
        keccak256("CancelAuthorization(address authorizer,bytes32 nonce)");
    
    // state variables
    uint256 private immutable _CHAINID_AT_DEPLOYMENT;
    bytes32 private immutable _NAMEHASH_AT_DEPLOYMENT;      // introduced for gas optimization
    bytes32 private immutable _VERSIONHASH_AT_DEPLOYMENT;   // introduced for gas optimization
    bytes32 private immutable _DOMAIN_SEPARATOR;
    mapping(address => mapping(bytes32 => bool)) private _usedNonces;

    // constructor
    constructor(
        string memory name,     // name of this token contract, part of the signing domain
        string memory version   // version of this token contract, part of the signing domain
        ) 
    {
        _NAMEHASH_AT_DEPLOYMENT = keccak256(bytes(name));
        _VERSIONHASH_AT_DEPLOYMENT = keccak256(bytes(version));
        _DOMAIN_SEPARATOR = DOMAIN_SEPARATOR();
        _CHAINID_AT_DEPLOYMENT = block.chainid; // placed after DOMAIN_SEPARATOR() to force calculation of domain separator at deployment
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        if (block.chainid == _CHAINID_AT_DEPLOYMENT) {
            return _DOMAIN_SEPARATOR;
        }
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                _NAMEHASH_AT_DEPLOYMENT,
                _VERSIONHASH_AT_DEPLOYMENT,
                block.chainid,
                address(this)
            )
        );
    }

    // public/external functions
    function authorizationState(address authorizer, bytes32 nonce) external view virtual returns (bool) {
        return _usedNonces[authorizer][nonce];
    }

    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v, bytes32 r, bytes32 s
    ) external virtual {
        // safety checks and early exits
        if (value == 0) {revert ERC3009_ZeroValue(from, to);}   // guard vs griefing calls, log addresses to help investigation
        if (from == to) {revert ERC3009_AuthorizerIsReceiver();}
        if (from == address(0)) {revert ERC3009_AuthorizerIsZeroAddress();}
        if (to == address(0)) {revert ERC3009_ReceiverIsZeroAddress();}
        if (!isValidAuthorization(validAfter, validBefore)) {revert ERC3009_InvalidAuthorization();}
        if (!consumeNonce(from, nonce)) {revert ERC3009_NonceAlreadyUsed(nonce);}
        // create the message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
                        from,
                        to,
                        value,
                        validAfter,
                        validBefore,
                        nonce
                    )
                )
            )
        );
        // check the signature and perform the transfer
        // function reverts if signature is invalid for any reason, rolling back the earlier nonce consumption and event emittance
        if (SimpleSignatureChecker.isValidSignature(from, messageHash, v, r, s)) {
            super._updateToken(from, to, value);
        }
    }

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v, bytes32 r, bytes32 s
    ) external virtual {
        // safety checks and early exits
        if (value == 0) {revert ERC3009_ZeroValue(from, to);}   // guard vs griefing calls, log addresses to help investigation
        if (to != msg.sender) {revert ERC3009_InvalidReceiver(to);}
        if (from == to) {revert ERC3009_AuthorizerIsReceiver();}
        if (from == address(0)) {revert ERC3009_AuthorizerIsZeroAddress();}
        if (!isValidAuthorization(validAfter, validBefore)) {revert ERC3009_InvalidAuthorization();}
        if (!consumeNonce(from, nonce)) {revert ERC3009_NonceAlreadyUsed(nonce);}
        // create the message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        RECEIVE_WITH_AUTHORIZATION_TYPEHASH,
                        from,
                        to,
                        value,
                        validAfter,
                        validBefore,
                        nonce
                    )
                )
            )
        );
        // check the signature and perform the transfer
        // function reverts if signature is invalid for any reason, rolling back the earlier nonce consumption and event emittance
        if (SimpleSignatureChecker.isValidSignature(from, messageHash, v, r, s)) {
            super._updateToken(from, to, value);
        }
    }

    function cancelAuthorization(
        address authorizer,
        bytes32 nonce,
        uint8 v, bytes32 r, bytes32 s
    ) external virtual {
        // safety checks and early exits
        if (authorizer == address(0)) {revert ERC3009_AuthorizerIsZeroAddress();}
        if (cancelNonce(authorizer, nonce)) {revert ERC3009_NonceAlreadyUsed(nonce);}
        // create the message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        CANCEL_AUTHORIZATION_TYPEHASH,
                        authorizer,
                        nonce
                    )
                )
            )
        );
        // check the signature and perform the cancellation
        // function reverts if signature is invalid for any reason, rolling back the earlier nonce cancellation and event emittance
        if (SimpleSignatureChecker.isValidSignature(authorizer, messageHash, v, r, s)) {
            // nothing to do, nonce cancellation and event emittance already done in cancelNonce()
        }
    }

    // private/internal functions
    function isValidAuthorization(uint256 validAfter, uint256 validBefore) internal view virtual returns (bool) {
        // this function checks vs block.timestamp, which is a SECURITY VULNERABILITY
        // TODO: study and implement something similiar to OpenZeppelin's `_checkValidity()`
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/draft-ERC3009.sol
        if (block.timestamp <= validAfter || block.timestamp >= validBefore) {return false;}
        return true;
    }

    function consumeNonce(address from, bytes32 nonce) internal virtual returns (bool) {
        if (_usedNonces[from][nonce]) {return false;}
        _usedNonces[from][nonce] = true;
        emit AuthorizationUsed(from, nonce);
        return true;
    }

    function cancelNonce(address from, bytes32 nonce) internal virtual returns (bool) {
        if (_usedNonces[from][nonce]) {return false;}
        _usedNonces[from][nonce] = true;
        emit AuthorizationCanceled(from, nonce);
        return true;
    }
}