# ERC2612 - ERC20 Approvals But Using secp256k1 Signatures Instead of Owner Calling approve() Directly

author:     mighty_hotdog  
created:    24Jul2026  
modified:   01Aug2026

Enables non-owner address to change the owner's allowances for spenders by using EIP712-compliant secp256k1 signatures signed with the owner's private key.

ERC2612 introduces new function `permit()` as alternative to ERC20's `approve()`.

## Allowance and Approvals for Original ERC20 Contracts (Base Case)

`owner` calls `approve(spender, amount)` to grant `spender` a spending allowance of owner's tokens.

Note:
* `owner` calls `approve()` on the ERc20 token contract of the specific token he is granting allowance for
* `spender` is a specific specified non-owner address
* only the `owner` may make this call
* `owner` has to own ETH and pay gas to make this call

## How Allowance and Approvals Work for ERC2612-extended ERC20 Contracts

STEP 1: `owner` (or any entity with access to owner's private key) creates a `secp256k1 signature` offchain, with expiry deadline and nonce.  
STEP 2: `relayer`, using the signature, makes the actual `permit()` call to the extended ERC20 contract, where if everything checks out:
* changes owner's `allowance` as requested
* increments `nonce` by 1
* emits `Approval` event as required by ERC20  

Note:
* ERC2612 offers `permi()` as an alternative to the ERC20 `approve()` function  
  ie: legacy ERC20 contracts must implement a new contract that includes the ERC2612 extensions with existing ERC20 requirements
* `relayer` can be any address, ie: `owner` requirement as caller is removed
* gas is paid by `relayer` rather than `owner`
* `signature` created by signing `message hash` using `owner`'s `private key`, ie: verifies that the message was approved by `owner`
* `message hash` (keccak256) contains:
    * an EIP712 `domain separator` that specifies the `signing domain`:
        * the **contract/protocol name** that the `signature` is intended for (eg: Uniswap, USDC, etc)
        * the **version of the contract/protocol** that the `signature` is intended for
        * the **chain ID** of the blockchain/network that the contract/protocol is deployed on
        * the deployed **address of the contract/protocol** that the signature is intended for
    * the actual `message` to be sent:
      * the `permit()` function name
      * `owner` and `spender` addresses
      * new `allowance` value
      * `nonce`  
        The `nonce` is an owner-specific counter that increments only on every successful `permit()` call executed in sequence.  
        Its intent is to prevent this `signature` to be resent/reused again.
      * `deadline`  
        Expires the `signature` if it is not used before the `deadline`.

## Terms and Concepts

### Public-Private Key Pairs
A cryptographical construct comprising a matching pair of public key and private key.  
The private key is a secret to be kept by the user and/or whatever entity he delegates his authority to. It is used to create signatures in a process known as "signing".  
The public key is used to verify that a signature was created by the user (and/or his delegate) in the 1st place.

There are many ways to generate public private key pairs. Here in blockchain world, Elliptic Curve Cryptography is used.  
How it works:
1. Private key is a randomly chosen 256-bit integer.
2. multiply this integer by a fixed standardized "generator point" (G) on the secp256k1 curve to produce a (x,y) coordinate point on the curve. This is the Public key.

### Signature
A cryptographical artifact created by signing a clump of data using a private key. The clump of data can be anything: a byte array, a struct, a message, etc.  
Signatures are used to verify that a particular user was the signer who created the signature in the 1st place. In this particular case, the data contains all pertinent parameters and information relating to a specific `permit()` call to be made to the extended ERC20 token contract.

How it works (super brief summary of ECDSA algorithm):  
1. The data to be signed is 1st hashed to produce a unique integer representation of the data.
2. The hash is put through a cryptographical algorithm with the signer's private key, producing a signature as the output. This process is known as "signing" the data.
1. this signature, at another time in another place by some other entity, is put through a matching cryptographical algorithm with a user's public key, to determine if this signature was created (aka signed) by this same user.

### Signing Domain
This refers to and includes all information required to uniquely specify/identify the context in which a signature is intended for. In EIP712, all this information is included in a single `keccak256` hash known as the `domain separator`, with suggested elements:
* string name: human-readable name of the app/protocol/contract which the signature is intended for, eg: Uniswap, USDC, etc
* string version: version of the app/protocol/contract, eg: 1, 2, etc
* uint256 chainId: chain ID of the blockchain/network that the app/protocol/contract is deployed on
* address verifyingContract: deployed address of the app/protocol/contract
* bytes32 salt: a disambiguating salt for the app/protocol/contract

In ERC2612 implementation, the signing domain refers to the ERC20 token contract that is the subject of the `permit()` call, in which the signature is intended to be used.

### ECDSA
ECDSA stands for Elliptic Curve Digital Signature Algorithm. It is a mathematical algorithm that uses a pair of public and private keys to create and verify digital signatures. Instead of multiplying massive prime numbers (like RSA cryptography), ECDSA relies on the difficulty of Elliptic Curve Cryptography.

### secp256k1
secp256k1 is the name of the specific mathematical curve (aka elliptic curves) used to generate the public-private key pairs that feed into the ECDSA algorithm. The name follows a strict naming standard set by SECG (Standards for Efficient Cryptography Group).

The exact algebraic equation that defines the secp256k1 curve geometry is:

                            y^2 = x^3 + 7 (mod p)

### secp256k1 Signatures
A pair of 32-byte integers, (r, s), generated by running the ECDSA algorithm specifically on the secp256k1 curve to validate a transaction or message.
  
ECDSA signatures comprise strictly of only (r, s). The `v` parameter is an EVM specific addition known as `recovery identifier` or `parity byte`. It is required because the mathematical geometry of the secp256k1 curve creates an ambiguity when attempting to back-calculate the signer's public key.
  
This ambiguity comes in 2 forms, which together produce 4 possible result for any given `r` value:
1. a single `r` value, which is the x-coordinate of a point on the curve, has 2 possible `s` values, which is the y-coordinate.
2. there is a 1 in 10^38 chance that the math will produce a `r` value beyond the curve's total order (n). this is known as `overflow`.

`v` was originally a 2-bit flag that tells the EVM exactly which of the 4 values is the correct one:
* bit 0: parity, indicates whether the y-coordinate is even (0) or odd (1).
* bit 1: overflow, indicates whether the x-coordinate has overflowed past the curve order (n). 0 no overflow, 1 overflow.
* so `v` has a raw value between 0 and 3.

To make signatures easier to handle and protect against network attacks, the raw 2-bit value of `v` is encoded differently depending on the transaction context:
1. Raw / Unsigned Messages (27 or 28)  
   For standard off-chain message signing (like eth_sign or EIP-712 payloads used in ERC-2612 and ERC-3009), Ethereum adds a constant of 27 to the raw parity bit.  
   v = 27: Y-coordinate is even, no overflow.  
   v = 28: Y-coordinate is odd, no overflow.  
2. On-Chain Transaction Replay Protection (EIP-155)  
   To prevent a transaction signed on Ethereum Mainnet from being intercepted and replayed on a fork or alternative network (like Polygon or Optimism), EIP-155 builds the network's Chain ID directly into the `v` value of on-chain transactions. The formula used by nodes to calculate an EIP-155 transaction v value is:

                            v = (Chain ID * 2) + 35 + parity

For example, on Ethereum Mainnet (Chain ID = 1), the v value for a transaction will be either 37 (even) or 38 (odd). When the EVM parses the transaction, it mathematically extracts the Chain ID directly from v to verify it matches the current network before executing.

### Relationship Between ECDSA, secp256k1 Curves, and secp256k1 Signatures

            ECDSA (the cryptographical algorithm for creating/signing and verifying signatures)
              |
              | applied to
              |
        secp256k1 curve (the elliptic curve from which public-private key pairs are generated)
              |
              | produces
              |
      secp256k1 signatures (the output created by signing a message with a secp256k1 private key)

## Security Considerations
* ERC2612 standard specifies `deadline` as time, to be compared vs `block.timestamp` which can be manipulated by miners.  
  Possible workaround uses `deadline` as a block number, and compare it vs `block.number`. But this breaks the ERC2612 standard.
* Front-running the `permit()` call does not benefit attacker as call details are included in the signature, ie: only thing the `front-runner` can do is run the same `permit()` transaction before the original call.  
  Result is `front-runner` executes the call successfully and pays the gas, `relayer` call gets reverted (due to invalidated nonce), and `owner` gets same outcome.
* `relayer` may choose to censor the call, ie: receive `owner`'s `signed message` but does not execute the call.  
  `owner` has no immediate way of knowing this, apart from any future expected token transfers failing.
* `DOMAIN_SEPARATOR()` is a view function, common implementation is to generate once at contract deployment, then store and reuse for subsequent `permit()` calls.  
  If a future chain fork or split occurs where `chainid` on both chains are temporarily the same, cross-chain replay attacks may be carried out by executing the `permit()` call on both chains in this window, ie: same `permit()` call (using the same `signature`) may be repeated on the other chain where it may not have been intended to be executed.

## Signer Address Recovery

`ecrecover` is a built-in Solidity function that retrieves the `signer address` from a `secp256k1 signature` (ie: v, r, s).

```(solidity)
address signer = ecrecover(digest, v, r, s);
```

`v, r, s` together form the `secp256k1 signature` for `EVM`.  
`digest` is a representation of the original `permit()` call intended to adjust the `owner`'s `allowance` for the `spender`.

A common sample reference implementation:

        ```(solidity)
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
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
            )
        );
        ```

        ```(solidity)
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                name,           // name of this token contract, which is also the signing contract
                version,        // version of this token contract
                block.chainid,
                thisContract    // address of this token contract
            )
        );
        ```

        ```(solidity)
        bytes32 DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name, string version, uint256 chainId, address verifyingContract)");
        ```

        ```(solidity)
        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)");
        ```

## A Note On ERC1271

Only `EOA`s (externally owned accounts) may hold `private keys` and hence create signatures. This means for `token owners` which are `smart contracts`, a different `signature` creation and verification scheme is needed - enter ERC1271.

OpenZeppelin provides the `ECDSA library` (contracts/utils/cryptography/ECDSA.sol) to handle `signer address recovery` from `secp256k1 signatures` (ie: v, r, s). As noted, this works only for `EOA signers`.

OpenZeppelin also provides the `SignatureChecker library` (contracts/utils/cryptography/SignatureChecker.sol) as an alternative to the `ECDSA library`. It inspects ```owner.code.length``` to differentiate between `EOA` and `smart contract` owner addresses. If a contract is detected, the `signature checking` function reroutes from `ecrecover` to an alternative ERC1271 `signature checking` method/function.

## EIP712, ERC191 and EIP155

**These 3 define standards for hashing and signing data that ERC2612 builds upon. To study and fully grasp them would be to enter into the world of Ethereum infrastructural foundations.**