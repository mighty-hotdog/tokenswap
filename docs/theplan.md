# Tokenswap
Tokenswap is a defi app that lets users connect wallets, create liquidity pools, and swap tokens.

# MoneyPouch
MoneyPouch is a wallet that lets users store and manage tokens, and connect to defi apps in order to swap, spend, stake, or otherwise use these tokens.

# The Plan
Started on 16Jul2026. Goal is to learn enough to build out non-trivial versions of these 2 projects by end Sep 2026.

# Roadmap
started:   16Jul2026  
today:     06Aug2026 (22 days)

* get to sufficiently complex custom token contracts that are unit/fuzz/invariant/onchain testable.
* create test rigs and write test suites for them.
* get to a MoneyPouch design that is buildable and begin building it.
  * compare with common designs + implementations.
  * learn, experiment, build the components that go into MoneyPouch.
  * 2-3 day sprints that produce testable features + associated tests, OR writeups.
* deploy MoneyPouch onchain and test.

## Custom Token Contracts
1. ERC20 token.
   ERC20 core + metadata, mintable, burnable, ownable, pausable, authorizable, capped, wrapped.
2. Approvals, permits and signatures.
   1. ERC2612, ERC3009, Uniswap Permit2.
   2. foundations - EIP712, ERC191, EIP155, ERC1271.
   3. sigs - vrs, standard 65 byte array, EIP2098, ERC6492.
   4. multisigs (incl. Safe Multisig).
   5. account abstraction (ERC4337) and sigs.
   6. EIP2537 as used in ZKRollups, liquid restaking, cross-chain light clients (ie: bridges).
3. Cross-chain-capable tokens and bridging.
   1. ERC7786, ERC7802.
4. ERC20 alternatives.
   1. ERC677, ERC777, ERC1363.
5. Multi-tokens and NFTs.
   1. ERC165, ERC1155, ERC6909.
   2. ERC721 + ERC721A.
6. Multisig wallets.
   1. ERC4337, ERC7579.
7. ~~RWA token standards.~~ KIV
   ~~1. ERC3643, ERC1400.~~
8. Common tokens and their design + implementation.
   1. eth, weth and other common flavors.
   2. stablecoins usdc, usdt, dai, etc.

## Offchain and Onchain Testing
1. Offchain testing.
   1. create test rigs and write test suites for:
      1. solidity/foundry/echidna/chimera/medusa/halmos.
      2. unit/fuzz/invariant tests.
2. Onchain testing.
   1. deploy contracts onchain.
   2. create test rigs and write test suites.
      1. what does onchain testing look like? what types of tests needed?
      2. what rigs/setup needed?

## Building MoneyPouch
1. Wallet technology.
   1. foundations, standards, components.
   2. common designs + implementations.
2. MoneyPouch design.

## Phase 2 - Tokenswap app ? days
7. Create MoneyPouch app + deploy on testnet.
8. Create test rig for MoneyPouch app.
   1. docker sandboxes for dev + test.
   2. Solidity/Foundry/Echidna/Chimera/Medusa test rigs.
   3. how to do onchain testing.
9. ERC20 vaults, wrappers and multi-asset extensions. 3D
   1. ERC4626 vaults.
   2. ERC7535, ERC7540, ERC7575.
10. Create a tokenswap app.
   1. liquidity pools + vaults.
   2. connect wallets.
   3. connect pricefeed oracles.
   4. onboarding mechanism for new tokens.
   5. token swap mechanism + anti-slippage.
   6. user interface.
11. Create test rig for Tokenswap app.
   1.  offchain testing
   2.  onchain testing