# ERC4337 - Account Abstraction not via Protocol Changes but Application Code

author:     mighty_hotdog  
created:    26Aug2026  
updated:    27Aug2026

**Account Abstraction** allows blockchain users to use `smart contract accounts` containing arbitrary verification code as their primary accounts instead of `EOAs`.  
**Protocol** refers to Ethereum, specifically the consensus layer.  
**Application code** refers to `smart contracts`.  

## What it does
> ***excerpt from the ERC4337 specification https://eips.ethereum.org/EIPS/eip-4337*** :
> 
> Historically, users could interact with Ethereum only by sending transactions from special accounts controlled by private keys (ie: EOAs), with transaction validation entirely enforced by fixed protocol rules (ie: baked into the Ethereum blockchain itself). Account abstraction is an alternative model that allows each account to supply its own validation logic executed as smart contract code, while the protocol (ie: Ethereum) provides only minimal constraints.

ERC4337 goes further to totally remove any need for users to also have an EOA, and still be able to work with legacy smart contract accounts and EIP7702, which both still require EOAs.

Additional, ERC4337 introduces new features and use-cases:  
1. Decentralization.
   * Any node (that meets the requirements) may participate in ERC4337 account-abstracted block building process - there are no gatekeepers and no permissions needed from such. These nodes are known as `bundlers`.
   * There are no trust assumptions required to work with participating `bundler` nodes.
   * Users, and all other actors, do not need to know the direct communication addresses of any other actor(s) in order to work with them - all work/collaborations happen via public `mempools`.

      Caveat: The app frontend and the bundler nodes (2 actors in this scheme) do actually need to know the following:
      * factory contract address (singleton, pre-deployed)
      * EntryPoint contract address (singleton, pre-deployed)
      * any participating Paymaster contract addresses (pre-deployed)

      This decentralization aspect of ERC4337, while not perfect, is real nonetheless.
   * `Mempools` - here specifically referring to the `canonical UserOperation mempool` and the `alternative UserOperation mempool` - are decentralized P2P networks where `bundler` nodes work collaboratively on `UserOperations` submitted to the mempools.

      These are NOT THE SAME as Ethereum's original native L1 transaction mempool that deals with traditional ECDSA-signed Ethereum L1 transactions.

      All discussions in the ERC4337 specification deal with usage and interaction with the `canonical UserOperation mempool`. The ERC7562 specification goes into more detail about both mempools, as well as usage of the `alternative UserOperation mempool` that ERC4337 does not cover.
2. User privacy.
3. Atomic multi-operations (parallel to EIP7202).
4. Allow transaction fees payment with ERC20 tokens instead of ETH, and allow transactions sponsorship (parallel to EIP7202).
5. Abstracted validation, allowing use of different schemes, multisigs, custom recovery, etc.
6. Abstracted gas payments, allowing 3rd party payees to be onboarded, payment in different tokens, cross-chain gas payments, etc.
7. Abstracted execution, allowing bundled transactions.

## How it works
### At protocol level
Introduced:
   1. `UserOperation` pseudo transaction.
   2. `canonical UserOperation mempool` and `alternative UserOperation mempool`.
   3. `bundler` node type.

Apps (offchain) builds `UserOperation` structs from user intent + other relevant information, performs some validation simulation on them, signs them with user's private key, then submits them, via specialized bundler-targeting RPCs, to `bundler` nodes.

`Bundler` nodes, working in the `canonical UserOperation mempool`, after performing more validation simulation (different objectives and different sim methods vs the apps) on the structs, bundles several of them together and submits them to Ethereum blockchain by calling `handleOps()` on the singleton `EntryPoint contract`.

### At application level
`EntryPoint contract` goes through:  
* 1st a verification loop in which it performs `signature validation` on each submitted `UserOperation`.  
  Note that an earlier round of `signature validation` had already been done offchain by the bundler nodes before submission onchain to `EntryPoint contract`.
* 2nd an execution loop in which it executes each `UserOperation` via the proxy wallet address specified in each struct.  
  Execution loop ends when:  
  * all `UserOperations` have been processed (either executed or discarded).
  * all gas expenses have been settled, ie:
    * all expenses covered and sent to the appropriate specified receipients,
    * excess gas refunded to the appropriate receipients.