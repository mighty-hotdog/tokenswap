// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {IERC2612} from "./IERC2612.sol";
import {ERC20} from "./ERC20.sol";
import {SimpleSignatureChecker} from "./SimpleSignatureChecker.sol";

/*
 * @title   ERC2612
 * @notice  ERC2612 is an abstract contract that implements the ERC2612 standard in an extended ERC20 token contract.
 * @author  mighty_hotdog
 *          created 24Jul2026
            modified 25Jul2026
                updated notes in _createDomainSeparator() on significance of "name" and "version"
                added ERC20Meta as a parent contract
                updated constructor() with input parameters and added ERC20Meta constructor call
                updated _createDomainSeparator() to add "name" and "version" as input parameters and use them in the
                    creation of the domain separator
            modified 28Jul2026
                added "@dev" comments to further explain necessity of including ERC20 as parent contract, and rejection
                    of including ERC20Meta.
                modified `permit()` to delegate actual signature checks to the `SimpleSignatureChecker` library.
            modified 31Jul2026
                replaced hardcoded magic number in `s` value check with `S_BOUNDARY` constant from `SimpleSignatureChecker`.
            modified 01Aug2026
                removed ERC20Meta import.
                shifted all custom errors to IERC2612 interface, added IERC2612 as parent contract.
            modified 03Aug2026
                shifted _ADDRESS_AT_DEPLOYMENT initialization from contructor() to declaration.
                added _CHAINID_AT_DEPLOYMENT.
                fixed bugs in _createDomainSeparator():
                    1. `name` change to `keccak256(bytes(name))`
                    2. `version` change to `keccak256(bytes(version))`
                removed the `s` value safety check in `permit()` as it is more appropriate to do it in `SimpleSignatureChecker`
                    which already does this check anyway, together with the `v` value check.
                deprecated `_createDomainSeparator()`.
                modified `DOMAIN_SEPARATOR()` to return pre-calc domain separator, or recalc new if chainid different from deployment.
                removed `_ADDRESS_AT_DEPLOYMENT` becos not useful.
                added `_NAMEHASH_AT_DEPLOYMENT` and `_VERSIONHASH_AT_DEPLOYMENT` for gas optimization.
                moved `_CHAINID_AT_DEPLOYMENT` assignment from declaration to constructor() - why better? further study needed.
 *
 * @dev     ERC2612 extends ERC20, offering a new `permit()` function as an alternative to the ERC20 `approve()`.
 *          However, this `permit()` function needs to modify the `_allowances` state variable in the ERC20 contract,
 *          which requires ERC2612 to inherit from ERC20.
 * @dev     ERC2612 signature cryptography includes a `DOMAIN_SEPARATOR` value, which by design intent requires a
 *          human-readable string `name` as identifier for the app/protocol context for which the signature is intended,
 *          and a likewise human-readable string `version` of the app/protocol contract, also for which the signature is
 *          intended.
 *          For this discussion, the app/protocol obviously refers to the extended ERC20 token contract, whose state
 *          (allowances) is to be modified by the `permit()` function upon verification of a valid signature.
 * @dev     The design option was considered to include ERC20Meta as a parent contract, which would allow its `name`
 *          state variable to be used in ERC2612 code to create the `DOMAIN_SEPARATOR`, and thus avoid having 2 separate
 *          locations in the same token contract code where the name of the contract can possibly be inconsistently defined.
 *          However, this design choice was rejected in favor of a much simpler solution: in any custom ERC20 token where
 *          ERC20Meta and ERC2612 are both included, simply be sure to use the same `name` input parameter from the main
 *          token contract constructor for the constructor calls for both parent contracts.
 */
abstract contract ERC2612 is IERC2612, ERC20 {
    bytes32 private constant PERMIT_TYPEHASH = 
        keccak256("Permit(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)");
    bytes32 private constant DOMAIN_TYPEHASH = 
        keccak256("EIP712Domain(string name, string version, uint256 chainId, address verifyingContract)");
    bytes32 internal immutable _NAMEHASH_AT_DEPLOYMENT;
    bytes32 internal immutable _VERSIONHASH_AT_DEPLOYMENT;
    uint256 internal immutable _CHAINID_AT_DEPLOYMENT;
    bytes32 internal immutable _DOMAIN_SEPARATOR;
    mapping(address=>uint256) private _nonces;

    constructor(
        string memory name,             // name of this token contract, part of the signing domain
        string memory version)          // version of this token contract, part of the signing domain
    {
        _NAMEHASH_AT_DEPLOYMENT = keccak256(bytes(name));
        _VERSIONHASH_AT_DEPLOYMENT = keccak256(bytes(version));
        _DOMAIN_SEPARATOR = DOMAIN_SEPARATOR();
        _CHAINID_AT_DEPLOYMENT = block.chainid; // placed after DOMAIN_SEPARATOR() to force calculation of domain separator at deployment
    }

    /*
     * @notice  `permit()` function
     *          Alternative to the ERC20 `approve()` function.
     *          Allows non-owner caller to change that owner's allowance via a secp256k1 signature.
     * @param   owner      owner of the token
     * @param   spender    spender of the token
     * @param   value      allowance to be granted to the spender
     * @param   deadline   signature expiry deadline
     * @param   v          signature `v` value
     * @param   r          signature `r` value
     * @param   s          signature `s` value
     *
     * @dev     This version delegates signature checking to the SimpleSignatureChecker library.
     */
    function permit(
        address owner, 
        address spender, 
        uint256 value, 
        uint256 deadline, 
        uint8 v, bytes32 r, bytes32 s
        ) external virtual {
        // safety checks and early exit
        if (owner == spender) {revert ERC2612_OwnerIsSpender();}
        if (owner == address(0)) {revert ERC2612_OwnerIsZeroAddress();}
        if (spender == address(0)) {revert ERC2612_SpenderIsZeroAddress();}
        if (block.timestamp > deadline) {revert ERC2612_ExpiredSignature();}
        /* delegating this check to SimpleSignatureChecker library (which already does it anyway) instead of doing it here
        // additional check to prevent signature malleability attacks:
        // s must be in lower half of elliptic curve
        // use S_BOUNDARY constant from SimpleSignatureChecker library instead of hardcoded magic number
        if (uint256(s) > SimpleSignatureChecker.S_BOUNDARY) {revert ERC2612_InvalidSValue();}
        */

        // create message hash
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        _nonces[owner],
                        deadline
                    )
                )
        ));

        // check signature and perform allowance update
        // SimpleSignatureChecker library function supports both EOA and contract owners
        // function reverts if signature is invalid for any reason, returns `true` only on valid signature
        if (SimpleSignatureChecker.isValidSignature(owner, msgHash, v, r, s)) {
            super._updateAllowance(owner, spender, value);
            _nonces[owner] += 1;
        }
        /*  original code, before using SimpleSignatureChecker library
            limited to only EOA owners
        // 2. extract signer from vrs and compare with owner from message
        // revert if:
        // - ecrecover returns address(0), ie: signature is invalid and ecrecover cannot extract original signer, OR
        // - signer is not owner
        address signer = ecrecover(msgHash, v, r, s);
        if (signer == address(0)) {revert ERC2612_MalformedSignature();}
        if (signer != owner) {revert ERC2612_SignerIsNotOwner();}

        // after all the checks passed, do the effects, ie: update state
        super._updateAllowance(owner, spender, value);
        _nonces[owner] += 1;
        */
    }

    function nonces(address owner) external view virtual returns (uint256) {
        if (owner == address(0)) {return 0;}
        return _nonces[owner];
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

    /* 03Aug2026 deprecating this whole function
    function _createDomainSeparator(string memory name, string memory version) internal view virtual returns (bytes32) {
        Notes:
        1. This implementation assumes "name" and "version" only need to be unique to this contract, their specific value is not
           important, hence the "cheapoHack" trick. Override if different assumptions are needed.
        
           UPDATE 25Jul2026:
           Above assumption is not true. Providing a meaningful and human-readable "name" and "version" for the DApp/protocol
           is very important:
                1. This info is what DApps like Metamask extracts and shows to users when asking for their signature. What the
                "cheapoHack" (or other similiar) trick does, is to present a string of gibberish to users who are then unable to
                understand what they are being asked to sign, or determine if this is malicious or legitimate. This defeats a
                major design intent of why EIP712 was introduced in the 1st place.

                2. Also, DApps, indexers, and SDKs often expect standard ERC20 name() string from the token contract to match
                the EIP712 domain name. Using address strings in the domain separator as "name" and/or "version", may cause
                standard front-end libraries (like ethers.js, viem, or Wagmi) trying to auto-derive the domain separator from
                the token's metadata to calculate an incorrect hash, causing all UI-generated signatures to fail on-chain.

        2. Explicit conversion of bytes to string is legal in Solidity. In fact, string is equal to bytes in memory representation.
           Differences between these 2 types:
                a. string is assumed to be UTF-8 encoded but bytes is not
                b. string does not allow length or index access but bytes allows

        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                _CHAINID_AT_DEPLOYMENT,
                _ADDRESS_AT_DEPLOYMENT
            )
        );
    }
    */
}