// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/**
 * @title   ERC20Wrapped
 * @author  mighty_hotdog
 *          created 08Aug2026
 *          modified 10Aug2026
 *              added `deDupeCollateralList()` function that produces a new Collateral[] list with unique addresses and names.
 *          modified 11Aug2026
 *              removed `name` field for tokens.
 *              removed `Collateral` struct and replaced all instances with `address`.
 *              removed `deDupeCollateralList()` function.
 *              updated `_acceptedCollateralsList` to `_acceptedCollaterals`.
 *          modified 15Aug2026
 *              updated and clarified on design intent for this contract.
 *              simplified contract to just 1 collateral to 1 wrapped token.
 *                  removed the multiple collateral design as it doesn't appear in any real-world use cases and doesn't make sense
 *                  for a wrapped token contract.
 *              changed contract and file name from `WrappedToken` to `ERC20Wrapped`. Updated events and custom errors accordingly.
 * @notice  Abstract contract. Implements basic functionality of a wrapped token:
 *          1. user deposits collateral tokens and receives equivalent amount of wrapped tokens.
 *          2. user burns/returns wrapped tokens and receives back equivalent amount of collateral tokens.
 *          3. collateral/wrapped exchange rate fixed at 1:1.
 *
 * @dev     TBD if we want to mess around with payables in order to accept ETH as collateral.
 */
abstract contract ERC20Wrapped {
    error ERC20Wrapped_InvalidCollateral(address token);
    event ERC20Wrapped_Deposit(address indexed user, uint256 amount);
    event ERC20Wrapped_Burn(address indexed user, uint256 amount);

    /////////////////////////////////////////////////////////////////////////////////////////
    // state variables
    /////////////////////////////////////////////////////////////////////////////////////////
    address private immutable _COLLATERAL;
    mapping(address user => uint256 balance) private _deposits;

    /////////////////////////////////////////////////////////////////////////////////////////
    // constructor
    /////////////////////////////////////////////////////////////////////////////////////////
    constructor(address collateral) {
        if (!_isValidCollateral(collateral)) {revert ERC20Wrapped_InvalidCollateral(collateral);}
        _COLLATERAL = collateral;
        _collateralTasks(collateral);
    }

    /////////////////////////////////////////////////////////////////////////////////////////
    // external/public functions
    /////////////////////////////////////////////////////////////////////////////////////////
    function COLLATERAL() external view virtual returns (address) {
        return _COLLATERAL;
    }
    function deposit(uint256 amount) external virtual returns (bool) {
        _deposits[msg.sender] += amount;
        // transfer collateral tokens to this contract
        // ERC20 example code (need to import IERC20.sol):
        //_COLLATERAL.transferFrom(msg.sender, address(this), amount);
        emit ERC20Wrapped_Deposit(msg.sender, amount);
        return true;
    }
    function burn(uint256 amount) external virtual returns (bool) {
        _deposits[msg.sender] -= amount;
        // transfer collateral tokens from this contract to user
        // ERC20 example code (need to import IERC20.sol):
        //_COLLATERAL.transferFrom(address(this), address(msg.sender), amount);
        emit ERC20Wrapped_Burn(msg.sender, amount);
        return true;
    }
    function depositFrom(address user, uint256 amount) external virtual returns (bool) {}
    function burnFrom(address user, uint256 amount) external virtual returns (bool) {}

    /////////////////////////////////////////////////////////////////////////////////////////
    // internal/private functions
    /////////////////////////////////////////////////////////////////////////////////////////
    /**
     * @notice  _isValidCollateral function
     *          Contains all checks for if a token is a valid collateral token.
     */
    function _isValidCollateral(address token) internal view virtual returns (bool) {
        if ((token == address(0)) || (token == address(this))) {return false;}
        return true;
    }

    /**
     * @notice  _collateralTasks function
     *          Performs all necessary tasks associated with setting the collateral.
     */
    function _collateralTasks(address token) internal virtual {}
}