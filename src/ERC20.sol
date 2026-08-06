// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {IERC20} from "./IERC20.sol";

/*
 * @title   ERC20
 * @author  mighty_hotdog
 *          created 17Jul2026
 * @notice  ERC20 is an abstract contract that implements the core functionality specified in the ERC20 standard.
 * @dev     state variables _totalSupply, _balances, _allowances declared private to restrict access to them.
 *          only the internal functions _updateToken, _updateAllowance, and _spendAllowance can modify them.
 *          while these 3 functions are virtual, the overidding functions must still call these 3 functions via super
 *          to access the private state variables.
 */
abstract contract ERC20 is IERC20 {
    //////////////////////////////////////////////////
    // state variables
    //////////////////////////////////////////////////
    uint256 private _totalSupply;
    mapping(address=>uint256) private _balances;
    mapping(address=>mapping(address=>uint256)) private _allowances;

    //////////////////////////////////////////////////
    // external/public functions
    //////////////////////////////////////////////////
    function totalSupply() public virtual view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public virtual view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public virtual view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        if (to == address(0)) {revert ERC20_TransferToZeroAddress();}
        return _updateToken(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        if (from == address(0)) {revert ERC20_TransferFromZeroAddress();}
        if (to == address(0)) {revert ERC20_TransferToZeroAddress();}
        return _spendAllowance(from, msg.sender, amount) && _updateToken(from, to, amount);
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        return _updateAllowance(msg.sender, spender, amount);
    }

    //////////////////////////////////////////////////
    // internal/private functions
    //////////////////////////////////////////////////
    function _updateToken(address from, address to, uint256 amount) internal virtual returns (bool) {
        if (from == to) {revert ERC20_TransferToSelf();}    // generic check, applies to all cases
        // mint ////////////////////////////////
        if ((from == address(0)) && (amount > 0)) {             // mint effects
            _totalSupply += amount;
            unchecked {
                _balances[to] += amount;
            }
        }
        else {
            if (amount > _balances[from]) {revert ERC20_InsufficientBalance();}     // balance check, applies to burn and transfer
            unchecked {
                _balances[from] -= amount;                  // burn and transfer effect
            }
            // burn ///////////////////////////////
            if ((to == address(0)) && (amount > 0)) {       // burn effect
                unchecked {
                    _totalSupply -= amount;
                }
            }
            // transfer ///////////////////////////
            else {
                if (amount > 0) {                           // transfer effect
                    unchecked {
                        _balances[to] += amount;
                    }
                }
                emit Transfer(from, to, amount);            // transfer interaction
            }
        }
        return true;
    }

    function _updateAllowance(address owner, address spender, uint256 amount) internal virtual returns (bool) {
        if (owner == spender) {revert ERC20_OwnerIsSpender();}
        if (owner == address(0)) {revert ERC20_OwnerIsZeroAddress();}
        if (spender == address(0)) {revert ERC20_SpenderIsZeroAddress();}
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual returns (bool) {
        if (owner == spender) {revert ERC20_OwnerIsSpender();}
        if (owner == address(0)) {revert ERC20_OwnerIsZeroAddress();}
        if (spender == address(0)) {revert ERC20_SpenderIsZeroAddress();}
        if (amount > _allowances[owner][spender]) {revert ERC20_InsufficientAllowance();}
        if (amount > 0) {
            unchecked {
                _allowances[owner][spender] -= amount;
            }
        }
        return true;
    }
}