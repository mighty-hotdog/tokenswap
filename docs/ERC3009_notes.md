# ERC3009 - Direct Token Transfers With ERC20 Token Contracts via EIP712 Signatures

author:     mighty_hotdog  
created:    31Jul2026  
updated:    01Aug2026

Enables a non-owner address to skip the ERC20 approval step and directly perform token transfers on behalf of the owner using secp256k1 signatures signed with the owner's private key.

Introduces new functions `transferWithAuthorization()` and `receiveWithAuthorization()`, and optionally `cancelAuthorization()`, which together provide an alternative token transfer mechanism to ERC20's `approve()` and `transferFrom()`.