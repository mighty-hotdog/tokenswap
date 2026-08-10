// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/**
 * @title   WrappedToken
 * @author  mighty_hotdog
 *          created 08Aug2026
 *          modified 10Aug2026
 *              added `deDupeCollateralList()` function that produces a new Collateral[] list with unique addresses and names.
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
    struct Collateral {
        address addr;
        string name;
    }

    /////////////////////////////////////////////////////////////////////////////////////////
    // state variables
    /////////////////////////////////////////////////////////////////////////////////////////
    /**
     * @notice  _acceptedCollateralsList
     *          state variable
     *          List of accepted collateral token addresses and their utf8 readable names.
     * @dev     Stored as array to be enumerable.
     * @dev     List is intended to be short (< 30 items) to maintain access efficiency and avoid out-of-gas reverts in function calls.
     *          Problems begin at ~400 items. Functions accessing this list break at ~1000 items due to out of gas.
     *          However as an abstract contract designed to be extended, the upper limit is left to the implementer to specify.
     *          The upper limit may be enforced by overriding the `_exceedSizeLimit()` function.
     */
    Collateral[] private _acceptedCollateralsList;
    mapping(address collateral => string Name) private _acceptedCollateralsMap;
    mapping(address user => mapping(address asset => uint256 balance)) private _balances;

    /////////////////////////////////////////////////////////////////////////////////////////
    // constructor
    /////////////////////////////////////////////////////////////////////////////////////////
    constructor(Collateral[] memory initialAcceptedCollaterals) {
        uint256 len = initialAcceptedCollaterals.length;
        if (len > 0 && !_exceedSizeLimit(len)) {
            for (uint256 i = 0; i < len; i++) {
                _addAcceptedCollateral(initialAcceptedCollaterals[i].addr, initialAcceptedCollaterals[i].name);
            }
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////
    // external/public functions
    /////////////////////////////////////////////////////////////////////////////////////////
    function addAcceptedCollaterals(Collateral[] calldata addList) external virtual returns (bool) {}
    function removeAcceptedCollaterals(Collateral[] calldata removeList) external virtual returns (bool) {}
    function getAcceptedCollateralList() external view virtual returns (Collateral[] memory list) {
        return _acceptedCollateralsList;
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
    function _addAcceptedCollateral(address token, string memory name) internal virtual returns (bool) {
        // safety checks
        if (bytes(name).length == 0) {return false;}
        if (_isAccepted(token)) {return false;}
        if (_exceedSizeLimit(_acceptedCollateralsList.length + 1)) {return false;}
        // add the collateral to accepted list and mapping
        _acceptedCollateralsList.push(Collateral({addr: token, name:name}));
        _acceptedCollateralsMap[token] = name;
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
        return bytes(_acceptedCollateralsMap[token]).length > 0;
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
        if (len > 30) revert("max size for _acceptedCollateralsList exceeded");
        return false;
    }

    /**
     * @notice  deDupeCollateralList function
     *          De-duplicates a Collateral[] list and returns a new Collateral[] list with no duplicates and resized appropriately.
     * @dev     Enforced de-duplication rules:
     *          - all tokens in the accepted collaterals list must have valid and unique addresses and names.
     *          - invalid addresses: zero address (0x0), this contract (address(this))
     *          - invalid names: empty-string names.
     */
    function deDupeCollateralList(Collateral[] memory list) internal pure returns (Collateral[] memory deDuped) {
        // if list has < 2 items, return as is
        uint256 len = list.length;
        if (len < 2) {return list;}

        deDuped = new Collateral[](len);
        bytes32[] memory deDupedHashes = new bytes32[](len);
        uint256 deDupedCount = 0;

        for (uint256 i = 0;i < len;) {
            address addr = list[i].addr;
            bytes memory name = bytes(list[i].name);
            bytes32 nameHash = keccak256(name);
            uint256 nameLen = name.length;
            if (nameLen > 0) {
                uint256 j = 0;
                for (; j < deDupedCount;) {
                    if ((addr == deDuped[j].addr) ||
                        ((nameLen == bytes(deDuped[j].name).length) && (nameHash == deDupedHashes[j]))) {break;}
                    unchecked {j++;}
                }
                if (j == deDupedCount) {
                    deDuped[deDupedCount] = list[i];
                    deDupedHashes[deDupedCount] = nameHash;
                    unchecked {deDupedCount++;}
                }
            }
            unchecked {i++;}
        }
        assembly {mstore(deDuped, deDupedCount)}
    }


    /* not implementing batched transactions for now.
    struct TokenAmount {
        address addr;
        uint256 amount;
    }
    function isAccepted(address[] memory collaterals) external view returns (bool) {}
    function deposit(TokenAmount[] memory deposits) external returns (uint256 wrappedAmount) {}
    function burn(TokenAmount[] memory withdrawals, uint256 burnAmount) external returns (TokenAmount[] memory successfulWithdrawals) {}
    */
}