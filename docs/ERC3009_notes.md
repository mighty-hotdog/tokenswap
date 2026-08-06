# ERC3009 - Direct Token Transfers With ERC20 Token Contracts via EIP712 Signatures

author:     mighty_hotdog  
created:    31Jul2026  
updated:    06Aug2026

Enables a non-owner address to skip the ERC20 approval step and directly perform token transfers on behalf of the owner using signatures created by the owner.

Introduces new functions `transferWithAuthorization()` and `receiveWithAuthorization()`, and optionally `cancelAuthorization()`, which together provide an alternative token transfer mechanism to ERC20's `approve()` and `transferFrom()`.

ERC3009 extends ERC20 and brings the following benefits:  
1. token owners may delegate transaction call and hence gas costs to a relayer contract.
2. single transaction token transfers (no separate `approve()`)
3. additional security features (offchain signing + onchain signature-checking, signature validity period, nonce, chainid checks)

## Mechanism for Token Transfers
2 methods: `transferWithAuthorization()` and `receiveWithAuthorization()`.

### transferWithAuthorization()
STEP 1: owner interacts with app offchain, signs the message the app presents to create a signature.  
STEP 2: app's smart contract (functions as relayer contract) calls `transferWithAuthorization()` on the token contract with the transfer request details and the signature.  
STEP 3: token contract verifies signature is valid, then performs the actual token transfer as per the request.

Notes:  
* `transferWithAuthorization()` can be called by any address.
* the message signed offchain contains:
  * `transferWithAuthorization()` function name + associated params
  * `from` address
  * `to` address
  * `value` to transfer
  * `validAfter` and `validBefore`, valid time period for the signature
  * `nonce`, random unique 32-byte number included in signature to prevent reuse
  * `chainid`, the blockchain on which the signature is to be used
  * verifying contract, address of the contract which will verify the signature, ie: the token contract
* each `from` address has its own set of unique nonces, nonces can be repeated for different addresses but not within the same address.
* standard does not specify a signature scheme, hence even though `secp256k1` most common, any scheme that produces a signature that fits into `vrs` may be used.

### receiveWithAuthorization()
`receiveWithAuthorization()` must be called by the `to` address, otherwise it is identical to `transferWithAuthorization()`.

## Usage/Integration
* ERC3009 specifications to be implemented alongside ERC20 in the token contract.  
* ERC3009's `transferWithAuthorization()` and `receiveWithAuthorization()` are an alternative to ERC20's `approve()` and `transferFrom()` mechanism.

## Security
The standard does not specify or even mention ERC1271, but if support for this is implemented, this introduces an external call to an unknown/untrusted contract for signature verification. Mitigate this by making this external call a `staticcall` to guarantee that the unknown contract cannot change blockchain state.