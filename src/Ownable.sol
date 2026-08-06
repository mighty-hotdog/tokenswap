// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

/*
 * @title   Ownable
 * @author  mighty_hotdog
 *          created 17Jul2026
 * @notice  Ownable is an abstract contract that implements a type of access control - ownership - for all derived contracts.
 * @dev     _owner state variable declared private to restrict access to it.
 *          Only constructor and internal functions _transferOwnership() and _checkOwner() can modify/access it.
 *          While these 2 internal functions are virtual, overidding functions must still call them via super
 *          to access the private state variable.
 *          Ownable_OwnershipTransferred event can be emitted (or not) upon successful ownership transfer.
 *
 *          Both transferOwnership() and _transferOwnership() functions are onlyOwner access-controlled.
 *          Is this redundant? Should modifier be removed from the public function transferOwnership()?
 */
abstract contract Ownable {
    ///////////////////////////////////////////////////
    // custom errors
    //////////////////////////////////////////////////
    error Ownable_NotOwner();
    error Ownable_InvalidNewOwner();

    //////////////////////////////////////////////////
    // events
    //////////////////////////////////////////////////
    event Ownable_OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    //////////////////////////////////////////////////
    // state variables
    //////////////////////////////////////////////////
    address private _owner;

    //////////////////////////////////////////////////
    // modifiers
    //////////////////////////////////////////////////
    /*
     * @notice  onlyOwner modifier
     *          Restricts access to functions to be callable only by contract owner.
     * @dev     Reverts if msg.sender is not contract owner.
     *          As modifiers cannot be virtual, the logic here is delegated to the internal function _checkOwner()
     *          which is virtual and can be overridden in derived contracts.
     *          To maximize logic/code flexibility, msg.sender is (not assumed, but) explicitly passed to _checkOwner()
     *          to be processed accordingly.
     */
    modifier onlyOwner() {
        _checkOwner(msg.sender);
        _;
    }

    //////////////////////////////////////////////////
    // constructor
    //////////////////////////////////////////////////
    /*
     * @notice  constructor
     *          Sets initial contract owner.
     * @param   initialOwner    Address of initial owner.
     * @dev     As constructors cannot be virtual, the logic here is delegated to the internal function _transferOwnership()
     *          which is virtual and can be overridden in derived contracts.
     *          Because _transferOwnership() is also access-controlled and can only be called by the contract owner, _owner
     *          is first set to msg.sender (deployer of the contract) just this once to allow transferOwnership() function
     *          to be called.
     *          _transferOwnership() is set to not emit ownership transferevent.
     */
    constructor(address initialOwner) {
        _owner = msg.sender;
        _transferOwnership(initialOwner, false);
    }

    //////////////////////////////////////////////////
    // external/public functions
    //////////////////////////////////////////////////
    function owner() public virtual view returns (address) {
        return _owner;
    }

    /*
     * @notice  transferOwnership function
     *          Transfers ownership of this contract (and derived contracts) to new owner.
     * @param   newOwner    Address of new owner.
     * @dev     Public function, intended to be called by external users.
     *          Virtual function, can be overridden in derived contracts.
     *          Access restricted to contract owner, reverts if msg.sender is not contract owner.
     *          Delegates logic to internal function _transferOwnership().
     *          _transferOwnership() is set to emit onwership transfer event.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        _transferOwnership(newOwner, true);
    }

    //////////////////////////////////////////////////
    // internal/private functions
    //////////////////////////////////////////////////
    /*
     * @notice  _transferOwnership function
     *          Transfers ownership of this contract (and derived contracts) to new owner.
     * @param   newOwner    Address of new owner.
     * @param   emitEvent   Boolean flag to indicate whether to emit Ownable_OwnershipTransferred event.
     * @dev     Internal function, intended to be called by public function transferOwnership().
     *          Virtual function, can be overridden in derived contracts.
     *          Access restricted to contract owner, reverts if msg.sender is not contract owner.
     *          Reverts if newOwner is zero address.
     *          Emits Ownable_OwnershipTransferred event if emitEvent is true.
     */
    function _transferOwnership(address newOwner, bool emitEvent) internal virtual onlyOwner {
        if (newOwner == address(0)) {revert Ownable_InvalidNewOwner();}
        _owner = newOwner;
        if (emitEvent) {
            emit Ownable_OwnershipTransferred(msg.sender, newOwner);
        }
    }

    function _checkOwner(address account) internal virtual view {
        if (account != _owner) {revert Ownable_NotOwner();}
    }
}