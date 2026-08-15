// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {ITokenCaps} from "./ITokenCaps.sol";
import {ERC20} from "./ERC20.sol";
import {ERC20Meta} from "./ERC20Meta.sol";
import {ERC20Burnable} from "./ERC20Burnable.sol";
import {ERC20Mintable} from "./ERC20Mintable.sol";
import {Ownable} from "./Ownable.sol";
import {Pausable} from "./Pausable.sol";
import {Authorizable} from "./Authorizable.sol";
import {Capped} from "./Capped.sol";
import {ERC2612} from "./ERC2612.sol";
import {ERC3009} from "./ERC3009.sol";

/*
 * @title   ERC20Token
 * @notice  Sample contract that implements a custom ERC20 token.
 * @author  mighty_hotdog
 *          created 24Jul2026
 *          modified 29Jul2026
 *              added ERC2612.
 *          modified 31Jul2026
 *              added notes on multiple inheritance.
 *          modified 04Aug2026
 *              added ERC3009 and Authorizable.
 *          modified 05Aug2026
 *              added Capped.
 *              replaced all ERC20CustomToken constants with constructor input params.
 *                  delegates these values to deployment, allowing greater flexibility without modifying this contract.
 *              added initial caps in constructor so that these immediately apply at contract deployment.
 *              introduced `InitialCaps` struct via `IERC20CustomToken` interface import in order to set initial caps.
 *              modified this contract name from `ERC20CustomToken` to `ERC20Token`.
 *              fixed misleading interface name `IERC20CustomToken` to `ITokenCaps`.
 *          modified 09Aug2026
 *              updated notes on multiple inheritance.
 *              updated "todos" list.
 *          modified 15Aug2026
 *              added dev notes on `this` warnings in constructor and Uniswap Permit2 support.
 *              updated todos.
 *          todos:
 *              1. refactor.
 *
 * @dev     Important notes on multiple inheritance:
 *              1. Inheritance impacts visibility of functions and variables, ie: who can see who.
 *                 And in the case of multiple inheritance, there is an order, ie: who can see who 1st, who 2nd, etc.
 *              2. C3 Linearization (the way Solidity handles multiple inheritance) ensures that for ERC20Token
 *                 (ie: this contract), there is only 1 instance of, for example, `_balances`, as defined in the ERC20
 *                 abstract contract, even though ERC20 is inherited by several of ERC20Token's parents, as well as
 *                 ERC20Token itself.
 *              3. Related to (2), state variable shadowing (ie: different variables same name) is not allowed, hence for
 *                 a contract that inherits from multiple contracts like ERC20Token, all state variable names must be unique.
 *              4. While state variables must be unique, functions may be overloaded (same name but different typed
 *                 parameters or different number of parameters) or overridden (explicitly via `virtual` and `override`).
 *              5. When a function that has multiple separate definitions in the inheritance graph is called in a child
 *                 contract (eg: ERC20Token), the compiler searches the parent contracts from right to left in the order
 *                 they are specified, ie: ERC2612 is searched 1st, then Pausable, then Ownable, ERC20Mintable, etc.
 * @dev     According to Gemini, these `this` warnings in constructor are merely a solidity parser legacy quirk and not a
 *          problem to be fixed.
 * @dev     This contract already works with Uniswap Permit2. No change needed, UniswapPermit2 just works with any ERC20 token.
 */
contract ERC20Token is 
    ITokenCaps, ERC20, ERC20Meta, ERC20Burnable, ERC20Mintable, Ownable, Pausable, Authorizable, Capped, ERC2612, ERC3009 {
    /* Replaced with constructor input params to allow more deployment flexibility while keeping this contract unchanged and simpler.
    // initialization constants to be set in constructor at contract deployment
    string private constant NAME = "Sample Custom ERC20 Token";
    string private constant SYMBOL = "SCTK";
    string private constant CONTRACT_VERSION = "1";
    uint256 private constant MAXIMUM_TOTAL_SUPPLY = 1e18;   // 1,000,000,000,000,000,000 tokens
    uint256 private constant INITIAL_SUPPLY = 1e9;          // 1,000,000,000 tokens
    */

    constructor(
        string memory name, 
        string memory symbol, 
        string memory version, 
        uint256 maxTotalSupply, 
        uint256 initialSupply, 
        address[] memory initialAuthorizedAddresses,
        TokenCaps memory initCaps
        ) 
        ERC20Meta(name, symbol) 
        ERC20Mintable(maxTotalSupply) 
        Ownable(msg.sender) 
        Authorizable(initialAuthorizedAddresses) 
        ERC2612(name, version) 
        ERC3009(name, version)
    {
        mint(msg.sender, initialSupply);
        setCap(this.setCap.selector, initCaps.capValueCap, initCaps.capTimeCap);
        setCap(this.burn.selector, initCaps.burnValueCap, initCaps.burnTimeCap);
        setCap(this.burnFrom.selector, initCaps.burnValueCap, initCaps.burnTimeCap);
        setCap(this.mint.selector, initCaps.mintValueCap, initCaps.mintTimeCap);
        setCap(this.transfer.selector, initCaps.transferValueCap, initCaps.transferTimeCap);
        setCap(this.transferFrom.selector, initCaps.transferValueCap, initCaps.transferTimeCap);
    }

    // admin functions
    function mint(address to, uint256 amount) public override 
        onlyAuthorized whenNotPaused capped(this.mint.selector, amount) returns (bool) 
    {
        return super.mint(to, amount);
    }
    function burn(uint256 amount) public override 
        onlyAuthorized whenNotPaused capped(this.burn.selector, amount) returns (bool) 
    {
        return super.burn(amount);
    }
    function burnFrom(address from, uint256 amount) public override 
        onlyAuthorized whenNotPaused capped(this.burnFrom.selector, amount) returns (bool) 
    {
        return super.burnFrom(from, amount);
    }
    function transferOwnership(address newOwner) public override onlyAuthorized whenNotPaused {
        super.transferOwnership(newOwner);
    }
    function pause() public override onlyAuthorized {
        super.pause();
    }
    function unpause() public override onlyAuthorized {
        super.unpause();
    }
    function setCap(bytes4 functionSel, uint256 valueCap, uint256 timeCap) public override 
        onlyAuthorized whenNotPaused capped(functionSel, valueCap) returns (bool) 
    {
        return super.setCap(functionSel, valueCap, timeCap);
    }
    function unsetCap(bytes4 functionSel) public override onlyAuthorized whenNotPaused returns (bool) {
        return super.unsetCap(functionSel);
    }

    // user functions
    function transfer(address to, uint256 amount) public override 
        whenNotPaused capped(this.transfer.selector, amount) returns (bool) 
    {
        return super.transfer(to, amount);
    }
    function transferFrom(address from, address to, uint256 amount) public override 
        whenNotPaused capped(this.transferFrom.selector, amount) returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }
    function approve(address spender, uint256 amount) public override whenNotPaused returns (bool) {
        return super.approve(spender, amount);
    }
    function DOMAIN_SEPARATOR() public view override(ERC2612, ERC3009) returns (bytes32) {
        return super.DOMAIN_SEPARATOR();
    }
}