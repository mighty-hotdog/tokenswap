// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

interface IERC3009 {
    error ERC3009_ZeroValue(address authorizer, address receiver);
    error ERC3009_AuthorizerIsReceiver();
    error ERC3009_AuthorizerIsZeroAddress();
    error ERC3009_ReceiverIsZeroAddress();
    error ERC3009_InvalidAuthorization();
    error ERC3009_NonceAlreadyUsed(bytes32 nonce);
    error ERC3009_InvalidReceiver(address receiver);
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);
    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);
    function authorizationState(address authorizer, bytes32 nonce) external view returns (bool);
    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v, bytes32 r, bytes32 s
    ) external;
    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v, bytes32 r, bytes32 s
    ) external;
}

interface IERC3009Cancel {
    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);
    function cancelAuthorization(
        address authorizer,
        bytes32 nonce,
        uint8 v, bytes32 r, bytes32 s
    ) external;
}