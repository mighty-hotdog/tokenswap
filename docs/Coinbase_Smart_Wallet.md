# Coinbase Smart Wallet - Deep Dive Into a State-of-the-Art Smart Contract Wallet

author:     mighty_hotdog  
created:    18Aug2026  
updated:    26Aug2026

Deep dive into the Coinbase Smart Wallet architecture, technology, and design.

## Architecture
Major pieces:  
* offchain key generation (Credential Management API and WebAuthn)
* onchain signature verification (ERC4337 EntryPoint, EIP7212)
* abstract account setup and deployment across multichains (ERC4337 and ERC1167)
* onchain transaction execution
* multisig, paymaster, and other functionalities

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
1. User performs action (eg: clicks "send") on frontend.
2. Frontend verifies it is actual user action, then constructs a standard ERC4337 `UserOperation` struct with `initCode` field populated:
   
        initCode = Factory Contract Address || `createAccount()` Function Selector

   and makes authentication call to OS.
3. Frontend freezes. OS takes over and prompts user for FaceID scan, fingerprint, or device PIN, signs `UserOperation` with private key, and returns `signed payload` to frontend.
4. Frontend broadcasts signed payload to specialized `alt mempool` for P2P UserOp.
5. Special `bundler node` picks up UserOp, bundles with several other UserOps, wraps in a standard Ethereum transaction envelope, and broadcasts envelope to standard `validator nodes` on the target blockchains (eg: Base, Arbitrum).
6. Transaction hits the singleton `EntryPoint contract`. Contract sees non-empty `initCode` field, and calls `Wallet Factory contract`.
7. Factory contract reads embedded public key and executes `CREATE2 opcode` to deploy a `minimal proxy wallet contract` to same address as per the pre-calculated counterfactual wallet address.
8. Factory contract immediately fires the proxy contract's `initialize()` function, saving the user's `public key` (X and Y values) into the proxy contract's immutable storage.
   
    ***Note: user's wallet is fully deployed at this point. As a proxy contract routing all execution to a singleton `Wallet Logic contract`.***

9. `EntryPoint contract` now calls `validateUserOp()` on the newly deployed proxy contract.
10. Proxy makes a `DELEGATECALL` to route call to the `Wallet Logic contract`.
11. `Wallet Logic contract` passes signed payload to the EIP7212 precompiled contract (0x100) for verification.
12. On verification, `EntryPoint contract` triggers `executeUserOp()` on proxy contract, which, via `Wallet Logic contract`, performs the transaction as requested by the user.

## Subsequent Wallet Transactions Workflow
### Phase 1 - User intent and offchain simulation
1. User performs action (eg: click "swap") on frontend.
2. Frontend builds an ERC4337 `UserOperation` object and performs an `asset/UX` `state fork simulation` by sending it to an `Ethereum RPC node`, which does something akin to a dry run for the transaction in a local fork of the blockchain (it's actually much more complicated under the hood).  
   
   The purpose is 2-fold: (1) translate raw hex data into human-readable text and then displaying to the user the expected result of the transaction, and (2) to help the frontend with gas estimates that it needs to include in the final `UserOperation` object to be submitted.  

   To include signature validation in the simulation, the `UserOperation` object's signature field is populated with a dummy P-256 signature.
3. If the transaction is successfully simulated/validated, frontend makes a WebAuthn payload signature request call `navigator.credentials.get()`. Device OS takes over and prompts user for a FaceID or similiar check. Upon verification, special security hardware chip is triggered to sign the `UserOperation` payload and return the signed string to the frontend.

### Phase 2 - Alt mempool and bundler batching
4. Frontend broadcasts signed `UserOperation` payload to `alt mempool` to be picked up by a `bundler node`. Here, the bundler node performs 2x rounds of anti-DoS simulation of the `UserOperation` against a sandboxed local fork of the live blockchain with the absolute latest block state.  
   
   Purpose is to surface and discard DoS attempts thru submitting invalid transactions that waste gas. The 1st round involves each `UserOperation` on its own. The 2nd round involves the aggregated bundle of several `UserOperations` right before submission, so that each `UserOperation` is validated again vs the very latest blockchain state.  

   In this sandboxed simulation governed by ERC7562, wallet code is banned from:
   * reading the env vars: TIMESTAMP, BLOCKNUMBER, COINBASE, DIFFICULTY, BASEFEE, GASLIMIT, and BLOCKHASH, all of which can be manipulated on the live blockchain in order to cause the transaction to fail.
   * reading storage slots of external 3rd party contracts.  
  
    As part of this simulation/validation routine, the bundler node also performs reputation tracking and throttling on `UserOperation` originator addresses.
5. If sim check passes, bundler bundles several `UserOperation` into a single EVM transaction and calls `handleOps()` on the `EntryPoint contract` to send all transactions over.

### Phase 3 - Onchain EntryPoint verification loop
6. `EntryPoint contract` steps through the array of `UserOperations`, calling `validateUserOp()` via a `DELEGATECALL` through each minimal proxy contract address to the singleton `Wallet Logic contract`.
7. `Wallet Logic contract` parses the transaction hash and signature for the current `UserOperation`, then makes a `STATICCALL` to the EIP7212 precompiled contract at 0x100 to verify the signature vs the hash.
8. On signature verified, `Wallet Logic contract` calculates max gas requirements for the `UserOperation`, performs any required transfers to the temporary `EntryPoint contract` escrow to cover gas shortfalls, and does a final verification that the wallet account's balance in the `EntryPoint contract` is sufficient to meet all gas expenses.

### Phase 4 - Onchain EntryPoint execution loop
9. `EntryPoint contract` again steps through the array of `UserOperations`, executing each via `DELEGATECALL` through the proxy contract to the `Wallet Logic contract`.
10. Pay the combined gas fees for all `UserOperations` to the `beneficiary address` provided by the bundler.
11. Refund all excess gas from the `EntryPoint contract` escrow, back to either the wallet account or the paymaster contract.

### Phase 5 - Final display update
12. Frontend catches and parses the onchain events triggered by the `UserOperation`, and upon receipt of the final event(s), updates the user display to show the final status on the transaction.


## Other Workflows