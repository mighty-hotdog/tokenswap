# What is Quickstart
A library of reference/sample/template smart contracts useful for quick prototyping of defi applications.  

# The Goal
A. A working ERC20/ERC1155/ERC6909-capable wallet.  
B. A working ERC20/ERC1155/ERC6909-capable tokenswap app:  
    a. with anti-slippage mechanism,  
    b. manages liquidity pools with compatible ERC4626 vaults,  
    c. connects multiple wallet types,  
    d. integrates multiple pricefeed oracles,  
    e. provides onboarding for new tokens.  
C. A Solidity/Foundry/Echidna/Chimera/Medusa devtest rig.  
D. A test sandbox Docker container running a reth node.  

# The Plan
~~Start:  28Oct2025  ~~  
~~End:    16Nov2025  ~~  
~~        30Nov2025  ~~  
Restart: 21Feb2026  
End:     40 days later  

1. ~~Create core ERC20 contracts, combine into a single custom token contract. 28Oct~~ DONE  
2. Create dev/test Docker sandboxes. 1D  
3. Recreate core ERC20 contracts, combine into single custom token contract. 1D  
4. Create Solidity/Foundry/Echidna/Chimera/Medusa testrig and test custom token contract. 1D  
5. Create ERC20 extension contracts (ERC2612, ERC677, ERC165), add to custom token contract and test. 2D  
6. Create an ERC20 wrapper and test. 1D  
7. Create a stablecoin and test + study common stablecoins in use + improve stablecoin implementation. 3D  
8. Create an ERC4626 vault and test + study ERC4626 implementations and vulnerabilities + improve ERC4626 implementation. 3D  
9.  Create an ERC1155 multi token and test. 1D  
10. Create an ERC6909 multi token and test. 1D  
11. Modify vaults to work with ERC1155 and ERC6909. Test. 2D  
12. Create a wallet app and test. 3D  
13. Create a tokenswap app for ERC20 tokens + create and run tests. 12D  
    a. create tokenswap app with anti-slippage mechanism  
    b. hookup vaults as liquidity pools  
    c. connect wallets  
    d. connect pricefeed oracles  
    e. create onboarding mechanism for new tokens  

   *note: this is a "broken app" with countless critical vulnerabilities. it merely stitches together previous pieces of work to get something up and running. purely for learning Solidity and to practice building a defi app.*  

   *past this point, I'm ready to study real defi apps like Uniswap, Compound, Aave, Balancer, etc.*  

14. Deep dive smart contract testing + use on tokenswap app.  
    1.  Solidity, Foundry, Echidna, Chimera, Medusa. 3D  
    2.  Formal verification. 2D  
    3.  on-chain testing. 2D  
15. Create test Docker sandbox running a reth node. Deploy tokenswap to node and test/run. 2D  