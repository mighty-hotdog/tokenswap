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

## Features and Points of Note
* Uses `secp256r1` (NIST P-256) elliptic cryptography, not the `secp256k1` used in Bitcoin, Ethereum/EVM and "standard crypto". Via WebAuthn and EIP7212 precompiles.
* Offchain-onchain interactions pass through the `ERC4337 EntryPoint` contract as gateway.
* Single address and unified user experience across multichains via `ERC4337 factory` and `ERC1167 minimal proxy contract`.
* Prioritizes user experience and maximum gas optimization via non-modular, hardcoded logic, eschewing ERC7579.
* Multiple convenience and/or enabling functionalities via ERC4337 (eg: multisig, paymaster).

## New User Signup Workflow
### Phase 1 - Offchain key generation
1. **User action trigger**: User clicks "create wallet" or similiar actions on frontend.
2. **Server request for challenge**: Browser/app-frontend verifies it is an actual user action, then sends request to backend to receive a `challenge` (random string of bytes) and a unique user ID.
3. **WebAuthn call**: Frontend calls `navigator.credentials.create()`, passing in the challenge, app domain name, algorithmic flag "-7" (ie: secp256r1).
4. **Device biometric check**: Frontend freezes. Device OS takes over and prompts user for FaceID scan, fingerprint, or device PIN.
5. **Secure keypair generation**: Device authenticates user, then triggers special hardware chip (eg: IPhone's Secure Enclave, Android's TEE, or Macbook's TouchID) to generate unique key pair. Private key (tied to requesting app domain) is locked in chip and unaccessible to internet, app, or even the OS itself.
6. **Public key export**: Hardware chip signs challenge using newly-created private key, returns `Attestation Object` to frontend. Frontend parses object and extracts public key (raw uncompressed 64 byte string comprising 2x 32 byte variables: X and Y).

### Phase 2 - Counterfactual address calculation
Frontend:
1. imports public address of Wallet Factory contract and wallet proxy bytecode.
2. calculates user wallet address (via Viem or Ethers) using this formula:
        
        address = keccak256(0xff || FactoryAddress || Salt || keccak256(ProxyBytecode))

    ***`Salt` is often a hash of user's Passkey identifier.***
3. presents wallet address to user, who can now share it, and use it to receive funds or buy crypto.

***Note: The user wallet DOES NOT yet exist on the blockchain at this point. Just a deterministic pre-calculated address.***

### Phase 3 - Actual deployment and 1st transaction
Occurs when user performs 1st outgoing action, eg: send funds, swap token, mint NFT.
1. User performs action (ie: clicks something) on frontend.
2. Frontend verifies it is actual user action, then constructs a standard ERC4337 `UserOperation` struct with `initCode` field populated:
   
        initCode = Factory Contract Address || `createAccount()` Function Selector

   and makes authentication call to OS.
3. Frontend freezes. OS takes over and prompts user for FaceID scan, fingerprint, or device PIN, signs `UserOperation` with private key, and returns `signed payload` to frontend.
4. Frontend broadcasts signed payload to specialized `alt mempool` for P2P UserOp.
5. Special `bundler node` picks up UserOp, bundles with several other UserOps, wraps in a standard Ethereum transaction envelope, and broadcasts envelope to standard `validator nodes` on the target blockchains (eg: Base, Arbitrum).
6. Transaction hits the singleton `EntryPoint contract`. Contract sees non-empty `initCode` field, and calls `Wallet Factory contract`.
7. Factory contract reads embedded public key and executes `CREATE2 opcode` to deploy a `minimal proxy wallet contract` to same address as per the pre-calculated counterfactual wallet address.
8. Factory contract immediately fires the proxy contract's `initialize()` function, saving the user's `public key` (X and Y values) into the proxy contract's immutable storage.
   
   User's wallet is fully deployed at this point. As a proxy contract routing all execution to a singleton `Wallet Logic contract`.

9. `EntryPoint contract` now calls `validateUserOp()` on the newly deployed proxy contract.
10. Proxy makes a `DELEGATECALL` to route call to the `Wallet Logic contract`.
11. `Wallet Logic contract` passes signed payload to the EIP7212 precompiled contract (0x100) for verification.
12. On verification, `EntryPoint contract` triggers `executeUserOp()` on proxy contract, which, via `Wallet Logic contract`, performs the transaction as requested by the user.

## Subsequent Wallet Transactions Workflow

## Other Workflows