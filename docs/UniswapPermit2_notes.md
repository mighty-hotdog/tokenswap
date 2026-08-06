# Uniswap Permit2 - Enables Time-Bounded Signature-Protected ERC20 Token Transfers via a Public Non-Custodial Wrapper Contract

author:     mighty_hotdog  
created:    06Aug2026

Introduces the Uniswap Permit2 smart contract as a wrapper for ERC20 token contracts. To effect token transfers on behalf of users, DApps/protocols go through Permit2 where they are subject to signature checks. Upon verification, Permit2 then calls into the token contracts to perform the transfer.

Because Permit2 is non-custodial, unowned (ie: completely independent from control of any entity) and unupgradable, it serves all users/DApps/protocols on the blockchain it is deployed, as a public-good middle-man that performs signature verification and then calls into the token contracts to effect the actual token transfers upon signature verification. All this is done according to Permit2's immutable smart contract logic, of which the source code is publicly visible.

Permit2 is deployed at the same address `0x000000000022D473030F116dDEE9F6B43aC78BA3` on virtually all EVM-compatible L1s and L2s.  
https://etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3

Because it was deployed via EVM's `CREATE2` opcode, any network supported by the Uniswap Protocol or its deployment factory automatically hosts the identical unowned singleton.

## Mechanism
Before everything else, the user is required to call `approve()` on the token contract directly and grant the Permit2 contract an allowance.

If the granted allowance is infinite (eg: USDC.approve(Permit2_Address, type(uint256).max)) and hence does not run out, this approval only needs to be done once. All subsequent use of Permit2 by the user for this particular token, even via any other DApps/protocols, will ride on this 1-time approval.

Permit2 offers 2 primary mechanisms, each with a single-transfer as well as a batched version:  
1. `SignatureTransfer` enables one-time, signature-based token movement without long-lived ERC-20 allowances. Used for when explicit signer authorization per transfer is required.

2. `AllowanceTransfer` allows time-bounded token allowances to be granted and spent safely through Permit2. Used for when multiple transfers within relatively short periods of time are desired rather than a single signature-authorized spending.

### SignatureTransfer
2x entry points to the Permit2 contract:
1. `permitTransferFrom()`  
   STEP 1: User interacts with app offchain, signs the permit message the app presents to create a signature.  
   STEP 2: App calls `permitTransferFrom()` on Permit2 using the signature and providing transfer details.  
   STEP 3: Upon verification, Permit2 "grants" a temporary allowance to the app as per the permit message. If the allowance is sufficient and has not expired, Permit2 then calls `transferFrom()` on the token contract to spend this allowance and effect the actual token transfer, as per the transfer details provided.

2. `permitWitnessTransferFrom()`  
   Same as `permitTransferFrom()` except with 2x additional input params: `witness` and `witnessTypeString`.  
   `witness` contains arbitrary signed data that can optionally be used to validate additional transaction context.  
   `witnessTypeString` is the EIP712 type string for `witness` hashing. It must include the amount and token to transfer. It must also follow EIP712 struct ordering.

Notes:  
* Batched version `permitTransferFrom()` and `permitWitnessTransferFrom()` allow the app to perform multiple token transfers on behalf of a single owner - multiple receivers, multiple tokens, multiple amounts - in a single transaction.
* ___Very important to note that when hashing multiple typed structs, the ordering of the structs in the type string matter.___
* The nonces DO NOT FOLLOW the standard incrementing schema. Refer to below link for details.  
  https://developers.uniswap.org/docs/protocols/permit2/concepts/allowance-transfer#nonce-schema

### AllowanceTransfer
3x entry points to the Permit2 contract:  
1. `approve()`  
   The user calls `approve()` directly on Permit2 to grant an allowance to an app to spend tokens on his behalf. Note that this allowance is between the user and the app and is tracked by Permit2. It is NOT THE SAME as the allowance the user granted Permit2 directly on the token contract itself.  
   Note also that this allowance expires and becomes invalid beyond the expiration param included in this call.

2. `permit()`  
   STEP 1: User interacts with app offchain, signs the permit message the app presents to create a signature.
   STEP 2: App calls `permit()` on Permit2 using the signature.  
   STEP 3: Upon verification, Permit2 allocates an allowance to the app as per the message signed by the user.

   `permit()` has a single-transaction and a batched version (for multiple permit requests, each with its own signature).

3. `transferFrom()`  
   App calls `transferFrom()` on Permit2 to request for token transfer on user's behalf. As long as the allowance is sufficient, Permit2 calls `transferFrom()` on the token contract to effect the transfer.

Notes:  
* `uint160` is used instead of the usual `uint256` for the allowance and token amount. Integrating contracts (ie: the apps and/or relayers) must perform the necessary conversions.
* `approve()` allows a single owner to grant an allowance to a single spender (the app) per call.  
  Batched version `permit()` allows a single owner to grant a single spender (the app) allowances for multiple different tokens in a single transaction.  
  Batched version `transferFrom()` allows the app to perform multiple token transfers - different owners, different receivers, different tokens, different amounts - in a single transaction.
* The nonces follow a standard incrementing schema and are unique to each owner/token/spender combination.

## Usage/Integration
Token contracts have nothing to do with regards to integration - Permit2 does the heavy lifting.

Integrating apps however have to track and validate the context of each transaction. The burden is on them to ensure the intended actions for the owners with regards to allowances, transactions, receivers, tokens, and amounts, are correctly executed. And that all other non-intended actions are prevented.

## Security
Permit2 introduces several security features that improve upon ERC20. However, token owners are still responsible for making sure what they sign is what they intend. Malicious apps can still attempt to trick owners into signing fraudulent messages that can be used to effect owner-unintended transactions.

Permit2 architecture involves redirection/rerouting of requests/transactions. Lots of room for context mistakes/bugs and unchecked contexts. The burden falls heavy upon integrating contracts to carefully validate the context of each transaction - caller, receiver, transfer to/from who, allowance to/from who, who is msg.sender really, etc.

As a separate but related point, Uniswap also provides the `Universal Router` that mitigates some of these rerouting issues.  
https://developers.uniswap.org/docs/protocols/universal-router/overview