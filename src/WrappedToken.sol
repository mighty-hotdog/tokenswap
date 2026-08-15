// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/**
 * @title   WrappedToken
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
 *              another major update on design.
 *              changed (reverted) contract and file name from `ERC20Wrapped` back to `WrappedToken`. Events and custom errors too.
 *              removed `_deposits` variable - any user bringing wrapped tokens in for burning gets equivalent amount of collateral
 *                  tokens in return.
 * @notice  Abstract contract designed to be inherited by a wrapped token contract.
 *          Scaffolds the basic framework of a wrapped token:
 *          1. user deposits collateral tokens and receives equivalent amount of wrapped tokens.
 *          2. user burns/returns wrapped tokens and receives back equivalent amount of collateral tokens.
 *          3. collateral/wrapped exchange rate fixed at 1:1.
 *
 * @dev     Developer howto:
 *          1. Create a wrapped token contract that inherits from this contract.
 *          2. Select a collateral token.
 *             Can be any valid token, not necessarily ERC20.
 *             This collateral is set in constructor during deployment and is immutable.
 *             The collateral contract interface is to be imported into the wrapped token contract.
 *          3. Select a wrapping token.
 *             Can be any valid token, not necessarily ERC20.
 *             This wrapping token is set at design.
 *             The wrapped token contract is to inherit from both the wrapping token contract and this contract.
 *          4. Implement all other features in the wrapped token contract.
 *             eg: access control, pausability, capping, signatures/permits/approvals, etc.
 *
 * @dev     TBD if we want to mess around with payables in order to accept ETH as collateral.
 */
abstract contract WrappedToken {
    /////////////////////////////////////////////////////////////////////////////////////////
    // custom errors
    /////////////////////////////////////////////////////////////////////////////////////////
    error WrappedToken_InvalidCollateral(address token);
    error WrappedToken_DepositFromZeroAddress();
    error WrappedToken_MintToZeroAddress();
    error WrappedToken_DepositZeroAmount();
    error WrappedToken_BurnFromZeroAddress();
    error WrappedToken_TransferToZeroAddress();
    error WrappedToken_BurnZeroAmount();

    /////////////////////////////////////////////////////////////////////////////////////////
    // events
    /////////////////////////////////////////////////////////////////////////////////////////
    event WrappedToken_Deposit(address indexed user, uint256 amount);
    event WrappedToken_Burn(address indexed user, uint256 amount);

    /////////////////////////////////////////////////////////////////////////////////////////
    // state variables
    /////////////////////////////////////////////////////////////////////////////////////////
    address private immutable _COLLATERAL;

    /////////////////////////////////////////////////////////////////////////////////////////
    // constructor
    /////////////////////////////////////////////////////////////////////////////////////////
    constructor(address collateral) {
        if (!_isValidCollateral(collateral)) {revert WrappedToken_InvalidCollateral(collateral);}
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
        return _deposit(msg.sender, msg.sender, amount, true);
    }
    function burn(uint256 amount) external virtual returns (bool) {
        return _burn(msg.sender, msg.sender, amount, true);
    }
    function depositFrom(address from, address to, uint256 amount) external virtual returns (bool) {
        return _deposit(from, to, amount, true);
    }
    function burnFrom(address from, address to, uint256 amount) external virtual returns (bool) {
        return _burn(from, to, amount, true);
    }

    /////////////////////////////////////////////////////////////////////////////////////////
    // internal/private functions
    /////////////////////////////////////////////////////////////////////////////////////////
    /**
     * @notice  _deposit function
     *          Internal function containing implementation details for depositing collateral tokens and minting wrapped tokens.
     * @dev     Checks:
     *              1. `from` and `to` are valid.
     *              2. `amount` > 0.
     *                 Users performing test-deposits should do so with small amounts but not 0.
     *          Effects:
     *              1. transfer collateral tokens from `from` to this contract.
     *                 Involves external call (inside `_transferCollateral()` function) to the collateral token contract.
     *              2. mint wrapped tokens to `to`.
     *          Interactions:
     *              1. emit WrappedToken_Deposit() event if `emitFlag` is true.
     */
    function _deposit(address from, address to, uint256 amount, bool emitFlag) internal virtual returns (bool) {
        if (from == address(0)) {revert WrappedToken_DepositFromZeroAddress();}
        if (to == address (0)) {revert WrappedToken_MintToZeroAddress();}
        if (amount == 0) {revert WrappedToken_DepositZeroAmount();}
        if (_transferCollateral(from, address(this), amount) && _mintWrapped(to, amount)) {
            if (emitFlag) {emit WrappedToken_Deposit(from, amount);}
            return true;
        }
        return false;
    }

    /**
     * @notice  _burn function
     *          Internal function containing implementation details for burning wrapped tokens and returning collateral tokens.
     * @dev     Checks:
     *              1. `from` and `to` are valid.
     *              2. `amount` > 0.
     *                 Users performing test-burns should do so with small amounts but not 0.
     *          Effects:
     *              1. burn wrapped tokens from `from`.
     *              2. transfer collateral tokens from this contract to `to`.
     *                 Involves external call (inside `_transferCollateral()` function) to the collateral token contract.
     *          Interactions:
     *              1. emit WrappedToken_Burn() event if `emitFlag` is true.
     */
    function _burn(address from, address to, uint256 amount, bool emitFlag) internal virtual returns (bool) {
        if (from == address(0)) {revert WrappedToken_BurnFromZeroAddress();}
        if (to == address (0)) {revert WrappedToken_TransferToZeroAddress();}
        if (amount == 0) {revert WrappedToken_BurnZeroAmount();}
        if (_burnWrapped(from, amount) && _transferCollateral(address(this), to, amount)) {
            if (emitFlag) {emit WrappedToken_Burn(from, amount);}
            return true;
        }
        return false;
    }

    /**
     * @notice  _mintWrapped function
     *          Internal function containing implementation details for minting wrapped tokens.
     * @dev     This is a function scaffold to be overridden in the inheriting wrapped token contract.
     *          The wrapped token contract is to inherit from both the wrapping token contract and this contract.
     *          Actual implementation details depend on the token mechanism of the wrapping token and its contract interface.
     */
    function _mintWrapped(address to, uint256 amount) internal virtual returns (bool) {}

    /**
     * @notice  _burnWrapped function
     *          Internal function containing implementation details for burning wrapped tokens.
     * @dev     This is a function scaffold to be overridden in the inheriting wrapped token contract.
     *          The wrapped token contract is to inherit from both the wrapping token contract and this contract.
     *          Actual implementation details depend on the token mechanism of the wrapping token and its contract interface.
     */
    function _burnWrapped(address from, uint256 amount) internal virtual returns (bool) {}

    /**
     * @notice  _transferCollateral function
     *          Internal function containing implementation details for transferring collateral tokens.
     * @dev     This is a function scaffold to be overridden in the inheriting wrapped token contract.
     *          The wrapped token contract is to import the collateral contract interface and to inherit from this contract.
     *          Actual implementation details depend on the token mechanism of the collateral token and its contract interface.
     */
    function _transferCollateral(address from, address to, uint256 amount) internal virtual returns (bool) {}

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
     *          Performs all necessary tasks (if any) associated with setting the collateral.
     */
    function _collateralTasks(address token) internal virtual {}
}