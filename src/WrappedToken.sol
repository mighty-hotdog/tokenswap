// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/**
 * @title   WrappedToken
 * @author  mighty_hotdog
 *          created 08Aug2026
 * @notice  Abstract contract implementing a basic wrapped token:
 *          1. receives collateral tokens and returns wrapped tokens.
 *          2. receives wrapped tokens and returns collateral tokens.
 *          3. fixed collateral/wrapped exchange rate 1:1.
 * @dev     External function names chosen to make most sense to users - may not reflect actual under-the-hood functionality.
 * @dev     Inherit from this contract to add extended functionality like access control, permissions (ERC2612, ERC3009, ERC1271), etc.
 * @dev     Design:
 *          - list of accepted collateral tokens.
 *          - mapping of user balances, including wrapped token balance and all collateral deposits.
 *          - receives deposit of collateral tokens from caller, returns commensurate amount of wrapped tokens.
 *          - receives burn request for wrapped tokens from caller, returns commensurate amount of collateral tokens.
 *
 * @dev     TBD if we want to mess around with payables in order to accept ETH as collateral.
 */
abstract contract WrappedToken {
    struct Collateral {
        address addr;
        string name;
    }
    Collateral[] private _acceptedCollaterals;  // stored as array to be enumerable, also short list expected ie: < 30 items
    mapping(address collateral => string collateralName) private _collateralNames;
    mapping(address user => mapping(address asset => uint256 balance)) private _balances;
    constructor(Collateral[] memory initialAcceptedCollaterals) {}
    function addAcceptedCollaterals(Collateral[] memory addList) external virtual returns (bool) {}
    function removeAcceptedCollaterals(Collateral[] memory removeList) external virtual returns (bool) {}
    function getAcceptedCollateralList() external view virtual returns (Collateral[] memory list) {}
    function isAccepted(address collateral) external view virtual returns (bool) {}
    function deposit(address collateral, uint256 amount) external virtual returns (uint256 wrappedAmount) {}
    function burn(address collateralToWithdraw, uint256 burnAmount) external virtual returns (uint256 withdrawAmount) {}

    /* not implementing batched transactions for now.
    struct TokenAmount {
        address addr;
        uint256 amount;
    }
    function isAccepted(address[] memory collaterals) external view returns (bool) {}   // batch check
    function deposit(TokenAmount[] memory deposits) external returns (uint256 wrappedAmount) {}    // batch deposit
    function burn(TokenAmount[] memory withdrawals, uint256 burnAmount) external returns (TokenAmount[] memory successfulWithdrawals) {}
    */
}