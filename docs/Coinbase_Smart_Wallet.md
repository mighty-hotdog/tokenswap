# Coinbase Smart Wallet - Deep Dive Into a State-of-the-Art Smart Contract Wallet

author:     mighty_hotdog  
created:    18Aug2026
updated:    26Aug2026

Deep dive into the Coinbase Smart Wallet architecture, technology, and design.

## Architecture
Major pieces:  
* offchain key generation (Credential Management API and WebAuthn)
* onchain signature verification (ERC4337 EntryPoint, EIP7212)
* abstract account setup and deployment across multichains (ERC4337 and 1167)

Uses `secp256r1` (NIST P-256) elliptic cryptography, not the `secp256k1` used in Bitcoin, Ethereum/EVM and "standard crypto". Via WebAuthn and EIP7212 precompiles.  
Offchain-onchain interactions pass through the `ERC4337 EntryPoint` contract as gateway.  
Single address and unified user experience across multichains via ERC4337 and 1167.  
Prioritizes user experience and maximum gas optimization via non-modular, hardcoded logic, eschewing ERC7579.

## New User Signup Workflow

## 1st Transaction Workflow

## Subsequent Wallet Transactions Workflow

## Other Workflows