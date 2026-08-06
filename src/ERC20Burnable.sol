// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {ERC20} from "./ERC20.sol";

/*
 * @title   ERC20Burnable
 * @author  mighty_hotdog
 *          created 17Jul2026
 *          modified 31Jul2026
 *              added `super` keyword to calls to _updateToken() and _spendAllowance(), to specify that these
 *                  functions to be called are to be the version from the ERC20 parent contract inherited
 *                  by this ERC20Burnable contract.
 * @notice  ERC20Burnable is an abstract contract that implements a burnable extension to the ERC20 standard.
 * @dev     Inherits from ERC20, calls its _updateToken() and _spendAllowance() internal functions.
 *          Adds burn() and burnFrom() public functions.
 *          Emits Burn event on successful burn.
 */
abstract contract ERC20Burnable is ERC20 {
    //////////////////////////////////////////////////
    // custom errors
    //////////////////////////////////////////////////
    error ERC20Burnable_BurnFromZeroAddress();

    //////////////////////////////////////////////////
    // events
    //////////////////////////////////////////////////
    event Burn(address indexed account, uint256 amount);

    //////////////////////////////////////////////////
    // external/public functions
    //////////////////////////////////////////////////
    function burn(uint256 amount) public virtual returns (bool) {
        bool result = super._updateToken(msg.sender, address(0), amount);
        emit Burn(msg.sender, amount);
        return result;
    }

    function burnFrom(address account, uint256 amount) public virtual returns (bool) {
        if (account == address(0)) {revert ERC20Burnable_BurnFromZeroAddress();}
        bool result = super._spendAllowance(account, msg.sender, amount) && _updateToken(account, address(0), amount);
        emit Burn(account, amount);
        return result;
    }
}