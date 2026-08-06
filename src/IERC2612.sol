// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

interface IERC2612 {
    error ERC2612_OwnerIsSpender();
    error ERC2612_OwnerIsZeroAddress();
    error ERC2612_SpenderIsZeroAddress();
    error ERC2612_ExpiredSignature();
    error ERC2612_InvalidSValue();

    /*
    // the following 2 errors are not used in the current ERC2612 implementation.
    // retained as reference to original intent of the ERC2612 standard as written.
    error ERC2612_MalformedSignature();
    error ERC2612_SignerIsNotOwner();
    */

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}