// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {ERC20} from "./ERC20.sol";

/*
 * @title   ERC20Mintable
 * @author  mighty_hotdog
 *          created 17Jul2026
 *          modified 31Jul2026
 *              added `super` keyword to calls to totalSupply() and _updateToken() , to specify that these
 *                  functions to be called are to be the version from the ERC20 parent contract inherited
 *                  by this ERC20Mintable contract.
 * @notice  ERC20Mintable is an abstract contract that implements a mintable extension to the ERC20 standard.
 * @dev     Inherits from ERC20, calls its _updateToken() internal function.
 *          Adds MAX_TOTAL_SUPPLY state variable, set in constructor and immutable.
 *          Adds mint() public function.
 *          Emits Mint event on successful mint.
 */
abstract contract ERC20Mintable is ERC20 {
    //////////////////////////////////////////////////
    // custom errors
    //////////////////////////////////////////////////
    error ERC20Mintable_MaxTotalSupplyZero();
    error ERC20Mintable_MintToZeroAddress();
    error ERC20Mintable_MaxTotalSupplyExceeded();

    //////////////////////////////////////////////////
    // events
    //////////////////////////////////////////////////
    event Mint(address indexed to, uint256 amount);

    //////////////////////////////////////////////////
    // state variables
    //////////////////////////////////////////////////
    uint256 public immutable MAX_TOTAL_SUPPLY;

    //////////////////////////////////////////////////
    // constructor
    //////////////////////////////////////////////////
    constructor(uint256 maxTotalSupply_) {
        if (maxTotalSupply_ == 0) {revert ERC20Mintable_MaxTotalSupplyZero();}
        MAX_TOTAL_SUPPLY = maxTotalSupply_;
    }

    //////////////////////////////////////////////////
    // external/public functions
    //////////////////////////////////////////////////
    function mint(address to, uint256 amount) public virtual returns (bool) {
        if (to == address(0)) {revert ERC20Mintable_MintToZeroAddress();}
        if (amount > MAX_TOTAL_SUPPLY - super.totalSupply()) {revert ERC20Mintable_MaxTotalSupplyExceeded();}
        bool result = super._updateToken(address(0), to, amount);
        emit Mint(to, amount);
        return result;
    }
}