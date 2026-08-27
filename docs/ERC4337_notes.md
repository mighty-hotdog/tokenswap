# ERC4337 - Account Abstraction not via Protocol Changes but Application Code

author:     mighty_hotdog  
created:    26Aug2026  
updated:    28Aug2026

**Account Abstraction** allows blockchain users to use `smart contract accounts` containing arbitrary verification code as their primary accounts instead of `EOAs`.  
**Protocol** refers to the Ethereum blockchain, specifically the consensus layer.  
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
3. Atomic multi-operations (parallel to EIP7702).
4. Allow transaction fees payment with ERC20 tokens instead of ETH, and allow transactions sponsorship (parallel to EIP7702).
5. Abstracted validation, allowing use of different schemes, multisigs, custom recovery, etc.
6. Abstracted gas payments, allowing 3rd party payees to be onboarded, payment in different tokens, cross-chain gas payments, etc.
7. Abstracted execution, allowing bundled transactions.

## How it works
### At protocol level
Introduced:
1. `UserOperation` pseudo transaction.
2. `canonical UserOperation mempool` and `alternative UserOperation mempool`.
3. `bundler` node type.

`Bundler` nodes implement ERC7652 for their validation sims.

App frontends (offchain):  
* builds `UserOperation` structs from user intent + other relevant information,
* performs validation simulation on them,
* signs them with user's private key,
* then submits them, via specialized bundler-targeting RPCs, to `bundler` nodes.

`Bundler` nodes (still considered offchain since no blockchain state change is allowed here):  
* working in the `canonical UserOperation mempool`,
* performs more validation simulation (different objectives and different sim methods vs the frontends) on the structs,
* bundles several of them together,
* then submits them onchain to Ethereum (onchain, finally) by calling `handleOps()` on the singleton `EntryPoint contract`.

### At application level
Introduced:
1. `Factory contract` singleton
2. `EntryPoint contract` singleton

On receipt of `UserOperations` array from `bundler` nodes calling `handleOps()`, `EntryPoint contract`:  
* checks each `UserOperation` for if the `sender` account (ie: the user-associated `smart contract account`) needs to be deployed.
  * if yes, proceeds to deploy `sender` account using `initcode` field contents in the `UserOperation`.
  * if no, skips to verification loop.
* runs thru a verification loop in which it performs `signature validation` on each submitted `UserOperation`.  
  Note that an earlier round of `signature validation` had already been done offchain by the bundler nodes before submission onchain to `EntryPoint contract`.
* runs thru an execution loop in which it executes each `UserOperation` by calling the `sender` with the contents of the `calldata` field in the `UserOperation`.  
  Execution loop ends when:  
  * all `UserOperations` have been processed (either sent to `sender` address to be executed, or discarded due to signature validation failure).
  * all gas expenses have been settled, ie:
    * all expenses covered and sent to the appropriate specified receipients,
    * excess gas refunded to the appropriate receipients.

### UserOperation simulation/validation
There are 2 different types of `UserOperation` simulation/validation done in the ERC4337 cycle:
1. Asset/UX simulation.  
   When: right before user sees device OS prompt to sign transaction.  
   Performed by: app `frontend`.  
   Method: ***to be completed***  
   Goals:  
   * User protection.  
      By translating raw bytecode of the `UserOperation` into human-readable text and allowing user to confirm intention to proceed.
   * Gas estimation.  
      Assists the frontend in populating the `UserOperation` fields concerned with gas and fees.  
2. ERC7562 security/verification simulation.  
   When: after app `frontend` submits `UserOperation` to `bundler` nodes via bundler-targeting RPCs, before `bundler` submits `UserOperation` bundles onchain.  
   Performed by: `bundler` node.  
   Goals:  
   * ensures `UserOperations` are valid (ie: not flawed transactions that will revert).
   * ensures `sender` (ie: user-associated `smart contract account`) has enough balance to pay max gas fees.

#### The ERC7562 security simulation
This is the offchain `view call` or `trace call` performed by the `bundler` to the offchain local forked instance of the `EntryPoint contract` passing in the `UserOperation`, where `EntryPoint contract` doesn't actually execute but validates the `UserOperation` against a shared set of rules.

To validate a normal Ethereum transaction `tx`, the bundler performs some or all of the below as static checks:  
* `ecrecover(tx.v, tx.r, tx.s)` has to return a valid EOA,
* `tx.nonce` has to be the current nonce of the recovered EOA,
* `balance` of the recovered EOA has to be sufficient to pay for the transaction,
* `tx.gasLimit` has to be sufficient to cover the intrinsic gas cost of a transaction,
* `chainId` has to match the current chain

All these checks do not rely on EVM state and cannot be affected by transactions performed by other accounts.

`UserOperation` validation however:  
* relies on EVM state (ie: calls to `validateUserOp()` and `validatePaymasterUserOp()`),
* can be changed by other `UserOperations` or even normal Ethereum transactions.

Hence validation requires a new mechanism - simulation - which ensures the validation code is sandboxed and isolated from other `UserOperations` while the sim is in progress. This new simulation mechanism is performed entirely within the `bundler` node making use of a local fork of the target blockchain with the very latest state.

Simulaton specification:
* `bundler` node makes a view call to the `handleOps()` function of the `EntryPoint contract`, passing in the `UserOperation` to check.
* `bundler` code recognizes this as a simulation call, and proceeds to:
  * create the `sender` account if `initcode` is present in the `UserOperation`,
  * call `sender.validateUserOp()`,
  * if a paymaster is specified in the `UserOperation`, call `paymaster.validatePaymasterUserOp()`.
  * `bundler` code stops here without going into actual execution, which the live `handleOps()` of the onchain `EntryPoint contract` will continue with.
* `bundler` code does all the above while enforcing the rules specified in ERC7652.

