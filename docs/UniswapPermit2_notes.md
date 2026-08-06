# Uniswap Permit2 - Enables Time-Bounded Signature-Protected ERC20 Token Transfers via a Public Non-Custodial Wrapper Contract

author:     mighty_hotdog  
created:    06Aug2026

Introduces the Uniswap Permit2 smart contract as a wrapper for ERC20 token contracts. To effect token transfers on behalf of users, DApps/protocols go through Permit2 where they are subject to signature checks. Upon verification, Permit2 then calls into the token contracts to perform the transfer.

Because Permit2 is non-custodial and unowned (ie: completely independent from control of any entity), it serves all users/DApps/protocols on the blockchain it is deployed, as a public-good middle-man that performs signature verification and then calls into the token contracts to effect the actual token transfers upon signature verification. All this is done according to Permit2's immutable smart contract logic, of which the source code is publicly visible.

Permit2 is deployed at the same address `0x000000000022D473030F116dDEE9F6B43aC78BA3` on virtually all EVM-compatible L1s and L2s.  
https://etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3

Because it was deployed via EVM's `CREATE2` opcode, any network supported by the Uniswap Protocol or its deployment factory automatically hosts the identical unowned singleton.

## Mechanism

## Usage/Integration

## Security