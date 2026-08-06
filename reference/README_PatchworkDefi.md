# What is PatchworkDefi
A homebrew hodgepodge library of reference/sample/template smart contracts useful for quick prototyping of defi apps.  

# What is MoneyPouch
A wallet app that stitches together code from PatchworkDefi and other sources to create a barebones defi wallet.  

# What is MarketDay
A tokenswap app that stitches together code from PatchworkDefi and other sources to create a barebones defi app.  

# New Plan
Start:   05Jul2026  

1. Recreate core ERC20 contracts. 1D  
   a. ERC20 core + meta, mintable, burnable, ownable, pausable.  
   b. ERC20 sample token, ERC20 wrapper.  
2. Deep dive EVM + smart contracts. 2D  
3. Prepare for audit. 1D  

# The Goal
1. A working ERC20/ERC1155/ERC6909-capable wallet.  
2. A working ERC20/ERC1155/ERC6909-capable tokenswap app:  
   a. with anti-slippage mechanism,  
   b. manages liquidity pools with compatible ERC4626 vaults,  
   c. connects multiple wallet types,  
   d. integrates multiple pricefeed oracles,  
   e. provides onboarding for new tokens.  
3. A Solidity/Foundry/Echidna/Chimera/Medusa dev + test rig.  
4. A test sandbox Docker container running a reth node.  

# The Plan (deferred)
Restart: 21Jun2026  
End:     8Aug2026 (50 days later)  

1. Create dev/test Docker sandboxes. 1D  
2. Recreate core ERC20 contracts.  
   a. ERC20 core + meta, mintable, burnable, ownable, pausable. 1D  
   b. ERC20 sample token, ERC20 wrapper. 1D  
3. Create Solidity/Foundry/Echidna/Chimera/Medusa testrig and test core ERC20 contracts. 3D  
4. Recreate and test ERC20 extension contracts.  
   a. ERC165, ERC1155, ERC6909. 3D  
   b. ERC223, ERC2616 aka ERC20Permit, Uniswap Permit2. 3D  
   c. ERC677, ERC777, ERC1363. 3D  
   d. ERC721 + ERC721A. 3D  
5. Create a stablecoin and test + study common stablecoins in use + improve stablecoin implementation. 3D  (21 days by this point)  

6. Create an ERC4626 vault and test + study ERC4626 implementations and vulnerabilities + improve ERC4626 implementation. 3D  
7. Modify vaults to work with ERC1155 and ERC6909. Test. 2D  
8. Create a wallet app and test. 3D  (29 days by this point)  

9. Create a tokenswap app for ERC20 tokens + create and run tests. 12D  (41 days by this point)  
   a. create tokenswap app with anti-slippage mechanism  
   b. hookup vaults as liquidity pools  
   c. connect wallets  
   d. connect pricefeed oracles  
   e. create onboarding mechanism for new tokens  
   f. create WebUI for tokenswap app

   *note: these are toy apps with countless critical vulnerabilities. they merely stitch together previous pieces of work to get something up and running but is barebones basic. purely for learning Solidity, EVM, Web3 app dev, and defi.*  

   *past this point, I'm ready to study real defi apps like Uniswap, Compound, Aave, Balancer, etc.*  

10. Deep dive smart contract testing + apply on tokenswap app.  
    1.  Solidity, Foundry, Echidna, Chimera, Medusa. 3D  
    2.  Formal verification. 2D  
    3.  on-chain testing. 2D  
11. Deploy tokenswap app to testnet, connect to webUI, and test. 2D  (50 days by this point)  

12. Create test Docker sandbox running a reth node. Deploy tokenswap to node and test/run. 2D  