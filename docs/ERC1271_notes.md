# ERC1271 - A Way for Smart Contracts to Verify Signatures

author:     mighty_hotdog  
created:    27Jul2026  
updated:    01Aug2026

Only EOAs (externally owned accounts) may hold private keys, and hence create signatures. This means token owners which are  
themselves smart contracts, need a different method of signature creation and verification.

ERC1271 offers a way for smart contract accounts (which own tokens but do not hold private keys) to verify signatures that originated with them.

## Signature Creation and Verification for EOAs

STEP 1: EOA owner creates a signature off-chain.  
STEP 2: Relayer contract uses this signature to perform an action on-chain on behalf of the EOA owner.  
STEP 3: Verifying contract uses `ecrecover()`, or other similiar functions, to extract signer address (ie: the EOA address) from the message hash and the signature. Which it then compares vs the owner's address it has been given. If the addresses match, ie: signer == owner, the signature is valid.

Note: The relayer contract and the verifying contract may be the same entity, as in the case of a (traditional, non-multisig) smart contract wallet:
* wallet web UI requests a signature from the EOA owner.
* wallet relayer contract uses the signature to perform an action on-chain on behalf of the EOA owner, eg: a token transfer.
* wallet verifying contract uses `ecrecover()` to verify the signature.

## Signature Creation and Verification for Smart Contracts

STEP 1: Smart contract owner delegates (off-chain) 1 or more EOAs that are authorized to create signatures on its behalf.  
STEP 2: EOA creates a signature off-chain.  
STEP 3: Relayer contract uses this signature to perform an action on-chain on behalf of the smart contract owner.  
STEP 4: Verifying contract calls `isValidSignature()` function on the smart contract owner, passing in as parameters the message hash and the signature. If the return is `0x1626ba7e`, the signature is valid. Otherwise, the signature is not valid.

Note:
* From the verifying contract pov, `isValidSignature()` **must be strictly non-state-changing**. This is because the verifying contract may be calling this function on an unknown contract address - no clue as to what the code in that contract and function does. The non-state-changing quality is enforced, from the verifying contract's side, by specifying the function call as a `staticcall`. This guarantees that if the target contract attempts to write to the blockchain or do any other state changes, the call will fail. This guards against several types of potential attack vectors.
    ```(solidity)
    contract SecureProtocol {
        function verify(address signer, bytes32 hash, bytes calldata sig) external view {
            
            // SAFE: This syntax explicitly forces the compiler to emit a STATICCALL opcode
            (bool success, bytes memory data) = signer.staticcall(
                abi.encodeWithSelector(0x1626ba7e, hash, sig)
            );
            
            require(success, "Staticcall failed or state change attempted");
            bytes4 magicValue = abi.decode(data, (bytes4));
            require(magicValue == 0x1626ba7e, "Invalid signature");
        }
    }
    ```
* `isValidSignature()` may be implemented using whatever logic appropriate for the smart contract owner to verify the signature. Some example implementations:
  * In multisig smart contract accounts (eg: Safe), the function decodes the signature input parameter byte array into an array of individual EOA signatures. It then loops through them, checks them via `ecrecover()`, and verifies if the number of valid co-signers meets its required threshold (e.g., 2-of-3 signatures).
  * Where Account Abstraction (ERC-4337) is used, the function checks if the single private key linked to the account authorized the signature data, or evaluates dynamic access rules (like whether a temporary passkey authorized it).
  * The standard does not specify any particular signature scheme. Any scheme that creates/decodes signatures that fit into a `bytes` array may be used.
* `0x1626ba7e` is actually the function selector for `isValidSignature()`.
    ```
    IERC1271.isValidSignature.selector == 0x1626ba7e
    ```
* As with the previous case, relayer contract and verifying contract may well be the same entity. But now, in order to implement multisig or account abstraction, the DApp/protocol has to be the actual owner (ie: of the tokens or assets) instead of the original EOA owner.  
  * Multisig smart contract wallet example:
    * wallet web UI requests signatures from several of the multisig EOAs authorized to sign on behalf of a particular target account.
    * wallet relayer contract uses the signatures to perform an action on-chain on behalf of the target account, eg: a token transfer.  This may involve single or multiple function calls, to itself, or other wallet contracts.
    * wallet verifying contract calls `isValidSignature()` on itself or another wallet contract to verify the signatures.