# ERC4337 - Account Abstraction not via Protocol Changes but Application Code

**Account Abstraction** allows blockchain users to use `smart contract accounts` containing arbitrary verification code as their primary accounts instead of `EOAs`.  
**Protocol** refers to Ethereum, specifically the consensus layer.  
**Application code** refers to `smart contracts`.  

> Historically, users could interact with Ethereum only by sending transactions from special accounts controlled by private keys (ie: EOAs), with transaction validation entirely enforced by fixed protocol rules (ie: baked into the Ethereum blockchain itself). Account abstraction is an alternative model that allows each account to supply its own validation logic executed as smart contract code, while the protocol (ie: Ethereum) provides only minimal constraints.

ERC4337 goes further to totally remove any need for users to also have an EOA, and still be able to work with legacy smart contract accounts and EIP7702, which both still require EOAs.

Additional, ERC4337 introduces new features and use-cases:  
1. Decentralization.
   * Any node (that meets the requirements) may participate in ERC4337 account-abstracted block building process - there are no gatekeepers and no permissions needed from such. These nodes are known as `bundlers`.
   * There are no trust assumptions required to work with participating `bundler` nodes.
   * Users, and all other actors, do not need to know the direct communication addresses of any other actor(s) in order to work with them - all work/collaborations happen in public `mempools`.
   * `Mempools` - specifically referring to the `canonical mempool` and the `alternative mempool` - are decentralized P2P networks where `bundler` nodes work collaboratively on `UserOperations` submitted to the mempools.
2. User privacy.
3. Atomic multi-operations (parallel to EIP7202).
4. Allow transaction fees payment with ERC20 tokens instead of ETH, and allow transactions sponsorship (parallel to EIP7202).
5. Abstracted validation, allowing use of different schemes, multisigs, custom recovery, etc.
6. Abstracted gas payments, allowing 3rd party payees to be onboarded, payment in different tokens, cross-chain gas payments, etc.
7. Abstracted execution, allowing bundled transactions.

