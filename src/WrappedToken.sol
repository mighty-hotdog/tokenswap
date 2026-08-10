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
 * @notice  Abstract contract implementing basic functionality of a wrapped token:
 *          1. receives collateral tokens and returns wrapped tokens.
 *          2. receives wrapped tokens and returns collateral tokens.
 *
 * @dev     For this implementation, collateral/wrapped exchange rate is fixed at 1:1. To modify, inherit this contract and override.
 * @dev     Inherit from this contract to add extended functionality like access control, permissions (ERC2612, ERC3009, ERC1271), etc.
 * @dev     Design intent:
 *          - users may deposit amounts for a list of accepted collateral tokens they hold, and receive equivalent amounts of wrapped
 *            tokens in return.
 *          - these deposits are associated with the depositor's address.
 *          - users may burn wrapped tokens and receive back equivalent amounts of their collateral token deposits. users may specify
 *            the types and amounts of collaterals they wish to redeem.
 * @dev     Assumptions:
 *          - Token addresses may not be repeated in the accepted collaterals list, nor token names.
 * @dev     TBD if we want to mess around with payables in order to accept ETH as collateral.
 *          Issue is not the payable infra but that ETH has a real world value that fluctuates:
 *          - does taking ETH as collateral mean the wrapped tokens and exchange rate must be subject to the fluctuations too?
 *          - must we mess around with price oracles too?
 */
abstract contract WrappedToken {
    /////////////////////////////////////////////////////////////////////////////////////////
    // state variables
    /////////////////////////////////////////////////////////////////////////////////////////
    /**
     * @notice  _acceptedCollaterals
     *          state variable
     *          List of accepted collateral token addresses.
     * @dev     Stored as array to be enumerable.
     * @dev     Ths addresses in this list are unique.
     * @dev     List is intended to be short (< 30 items) to maintain access efficiency and avoid out-of-gas reverts in function calls.
     *          Problems begin at ~400 items. Functions accessing this list break at ~1000 items due to out of gas.
     *          However as an abstract contract designed to be extended, the upper limit is left to the implementer to specify.
     *          The upper limit may be enforced by overriding the `_exceedSizeLimit()` function.
     */
    address[] private _acceptedCollaterals;
    mapping(address user => mapping(address asset => uint256 balance)) private _balances;

    /////////////////////////////////////////////////////////////////////////////////////////
    // constructor
    /////////////////////////////////////////////////////////////////////////////////////////
    constructor(address[] memory initialAcceptedCollaterals) {
        uint256 len = initialAcceptedCollaterals.length;
        if (len > 0 && !_exceedSizeLimit(len)) {
            for (uint256 i = 0; i < len; i++) {
                _addAcceptedCollateral(initialAcceptedCollaterals[i]);
            }
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////
    // external/public functions
    /////////////////////////////////////////////////////////////////////////////////////////
    function addAcceptedCollaterals(address[] calldata addList) external virtual returns (bool) {}
    function removeAcceptedCollaterals(address[] calldata removeList) external virtual returns (bool) {}
    function getAcceptedCollateralList() external view virtual returns (address[] memory) {
        return _acceptedCollaterals;
    }
    function isAccepted(address token) external view virtual returns (bool) {
        return _isAccepted(token);
    }
    function deposit(address collateral, uint256 amount) external virtual returns (uint256 wrappedAmount) {}
    function burn(address collateralToWithdraw, uint256 burnAmount) external virtual returns (uint256 withdrawAmount) {}

    /////////////////////////////////////////////////////////////////////////////////////////
    // internal/private functions
    /////////////////////////////////////////////////////////////////////////////////////////
    /**
     * @notice  _addAcceptedCollateral function
     *          Adds a token to the accepted collaterals list.
     */
    function _addAcceptedCollateral(address token) internal virtual returns (bool) {
        // safety checks
        if (_isAccepted(token)) {return false;}
        if (_exceedSizeLimit(_acceptedCollaterals.length + 1)) {return false;}
        // add the collateral to accepted list and mapping
        _acceptedCollaterals.push(token);
        return true;
    }

    /**
     * @notice  _isAccepted function
     *          Checks if a token is already in this contract's accepted collaterals list.
     */
    function _isAccepted(address token) internal view returns (bool) {
        // sanity checks
        if (token == address(0)) {return false;}
        if (token == address(this)) {return false;}
        uint256 len = _acceptedCollaterals.length;
        for (uint256 i = 0; i < len; i++) {if (_acceptedCollaterals[i] == token) {return true;}}
        return false;
    }

    /**
     * @notice  _exceedSizeLimit function
     *          Checks if size of accepted collaterals list is greater than max.
     * @dev     Reverts if max size exceeded. Returns false if not exceeded.
     * @dev     This function is intended to be overridden in derived contracts, which should define and set a proper
     *          UPPER_LIMIT or MAX_SIZE property to be checked against by the overriding function, as well as define
     *          appropriate custom errors to revert when exceeded.
     */
    function _exceedSizeLimit(uint256 len) internal pure returns (bool) {
        if (len > 30) revert("max size for _acceptedCollaterals exceeded");
        return false;
    }
}