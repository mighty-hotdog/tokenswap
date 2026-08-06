// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/**
 * @title   Capped
 * @author  mighty_hotdog
 *          created 05Aug2026
 * @notice  Enables users to set a value cap and/or a time limit on a transaction type.
 *          eg: a cap of 1000 tokens per 24 hours for transfers, or 10,000 tokens per week for mints.
 * @dev     The various time cap values are in Unix time, to be compared vs `block.timestamp`.
 *          This is obviously a SECURITY VULNERABILITY.
 *          TO BE FIXED.
 */
abstract contract Capped {
    error Capped_ValueCapped(bytes4 functionSel, uint256 value);
    error Capped_TimeCapped(bytes4 functionSel, uint256 time);
    event Capped_CapSet(bytes4 indexed functionSel, uint256 valueCap, uint256 timeCap);
    event Capped_CapUnset(bytes4 indexed functionSel);
    mapping(bytes4 => uint256 valueCap) private _valueCaps;
    mapping(bytes4 => uint256 timeCap) private _timeCaps;
    mapping(bytes4 => uint256 lastActionTime) private _lastActionTime;
    modifier capped(bytes4 functionSel, uint256 value) {
        if (_isValueCapped(functionSel, value)) revert Capped_ValueCapped(functionSel, value);
        if (_isTimeCapped(functionSel)) revert Capped_TimeCapped(functionSel, block.timestamp);
        _updateLastActionTime(functionSel);
        _;
    }
    function setCap(bytes4 functionSel, uint256 valueCap, uint256 timeCap) public virtual returns (bool) {
        _valueCaps[functionSel] = valueCap;
        _timeCaps[functionSel] = timeCap;
        emit Capped_CapSet(functionSel, valueCap, timeCap);
        return true;
    }
    function unsetCap(bytes4 functionSel) public virtual returns (bool) {
        delete _valueCaps[functionSel];
        delete _timeCaps[functionSel];
        emit Capped_CapUnset(functionSel);
        return true;
    }
    function getCap(bytes4 functionSel) external view virtual returns (uint256 valueCap, uint256 timeCap) {
        return (_valueCaps[functionSel], _timeCaps[functionSel]);
    }
    function getLastActionTime(bytes4 functionSel) external view virtual returns (uint256 lastActionTime) {
        return _lastActionTime[functionSel];
    }
    function _isValueCapped(bytes4 functionSel, uint256 value) internal view virtual returns (bool) {
        uint256 valueCap = _valueCaps[functionSel];
        return valueCap > 0 && value > valueCap;
    }
    function _isTimeCapped(bytes4 functionSel) internal view virtual returns (bool) {
        uint256 timeCap = _timeCaps[functionSel];
        if (timeCap == 0) return false;
        uint256 lastTime = _lastActionTime[functionSel];
        return block.timestamp < lastTime + timeCap;
    }
    function _updateLastActionTime(bytes4 functionSel) internal virtual {
        _lastActionTime[functionSel] = block.timestamp;
    }
}