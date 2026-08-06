// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/*
 * @title   Pausable
 * @author  mighty_hotdog
 *          created 17Jul2026
 * @notice  Pausable is an abstract contract that implements a pause mechanism for all derived contracts.
 * @dev     _paused is a global state that applies to all derived contracts.
 *          However, the _paused state variable itself is declared private to restrict access to it.
 *          Pausable mechanism is applied via the whenNotPaused() modifier, which marks functions as pausable.
 *          Pausable_Paused and Pausable_Unpaused events can be emitted (or not) on successful pause/unpause.
 *
 * @dev     Pause/Unpause are powerful functions that should be access-controlled to only authorized users.
 *          Option 1:
 *              Generic solution, may be used to introduce access-control in other contracts as well.
 *              Create new Authorized_Users contract and have Pausable inherit from it.
 *              Users/addresses may be added/removed to the authorized list.
 *              _setPaused() and _setUnpaused() functions restricted to be callable only by authorized users.
 *          Option 2:
 *              Fastest and simplest solution.
 *              Have Pausable inherit from Ownable contract.
 *              _setPaused() and _setUnpaused() functions restricted to be callable only by contract owner.
 */
abstract contract Pausable {
    ///////////////////////////////////////////////////
    // custom errors
    //////////////////////////////////////////////////
    error Pausable_PauseInEffect();

    ///////////////////////////////////////////////////
    // events
    //////////////////////////////////////////////////
    event Pausable_Paused(address indexed pauser);
    event Pausable_Unpaused(address indexed unpauser);

    ///////////////////////////////////////////////////
    // state variables
    //////////////////////////////////////////////////
    bool private _paused;

    ///////////////////////////////////////////////////
    // modifiers
    //////////////////////////////////////////////////
    modifier whenNotPaused() {
        _checkIfPaused();
        _;
    }

    ///////////////////////////////////////////////////
    // constructor
    //////////////////////////////////////////////////
    constructor() {
        _paused = false;
    }

    ///////////////////////////////////////////////////
    // external/public functions
    //////////////////////////////////////////////////
    function isPaused() public view returns (bool) {
        return _paused;
    }
    function pause() public virtual {
        _setPaused(true);
    }
    function unpause() public virtual {
        _setUnpaused(true);
    }

    ///////////////////////////////////////////////////
    // internal/private functions
    //////////////////////////////////////////////////
    function _checkIfPaused() internal virtual view {
        if (_paused) {revert Pausable_PauseInEffect();}
    }
    function _setPaused(bool emitEvent) internal virtual {
        _paused = true;
        if (emitEvent) {
            emit Pausable_Paused(msg.sender);
        }
    }
    function _setUnpaused(bool emitEvent) internal virtual {
        _paused = false;
        if (emitEvent) {
            emit Pausable_Unpaused(msg.sender);
        }
    }
}