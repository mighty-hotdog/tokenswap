// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {GeneralUtils} from "./GeneralUtils.sol";

/*
 * @title   Authorizable
 * @author  mighty_hotdog
 *          created 17Jul2026
 *          modified 10Aug2026
 *              generalize `deDupeList()` to work with any list, and move to separate utility library "GeneralUtils"
 * @notice  Authorize implements a type of access control - authorized users - to all inheriting contracts.
 * @dev     _authorizedUsers is implemented as an address array to facilitate enumeration (ie: knowing how many
 *          users, who they are, adding/removing specific users).
 *          This contract deals alot with arrays, specifically of addresses - adding/removing users, checking for
 *          particular user(s), etc, hence optimization has huge impact here.
 *          General design:
 *              1. persist data as arrays in storage.
 *              2. copy to memory for processing, and keeping all processing in memory.
 *              3. write back to storage when processing completed.
 */
abstract contract Authorizable {
    //////////////////////////////////////////////////
    // custom errors
    //////////////////////////////////////////////////
    error Authorizable_UnauthorizedUser();

    //////////////////////////////////////////////////
    // events
    //////////////////////////////////////////////////
    event Authorizable_UsersAdded();
    event Authorizable_UsersRemoved();

    //////////////////////////////////////////////////
    // state variables
    //////////////////////////////////////////////////
    address[] private _authorizedUsers;

    //////////////////////////////////////////////////
    // modifiers
    //////////////////////////////////////////////////
    /*
     * @notice  onlyAuthorized modifier
     * @dev     if the msg.sender is not in _authorizedUsers, revert.
     * @dev     Key functionality of Authorizable.
     *          Modifiers cannot be virtual, hence actual logic is delegated to _isAuthorized() internal functon that can be overridden.
     */
    modifier onlyAuthorized() {
        if (!_isAuthorized(msg.sender)) {revert Authorizable_UnauthorizedUser();}
        _;
    }

    //////////////////////////////////////////////////
    // constructor
    //////////////////////////////////////////////////
    /*
     * @notice  constructor
     * @dev     Adds an initial list of authorized users.
     */
    constructor(address[] memory initialAuthorizedUsers) {
        addAuthorizedUsers(initialAuthorizedUsers);
    }

    //////////////////////////////////////////////////
    // external/public functions
    //////////////////////////////////////////////////
    function authorizedUsersCount() public virtual view returns (uint256) {
        return _authorizedUsers.length;
    }

    /*
     * @notice  addAuthorizedUsers function
     *          Adds users to _authorizedUsers.
     * @dev     Input param is memory, which is alot more expensive than calldata. Any way to optimize to calldata?
     *          Algorithm:
     *              1. early exit if empty newUsers
     *              2. de-duplicate newUsers into deDuped (memory)
     *              3. if _authorizedUsers (storage) is empty, just copy deDuped (memory) to it and return
     *              4. copy _authorizedUsers (storage) to cached (memory) for processing
     *              5. for each user in deDuped, check if exists in cached
     *                  if not, push directly to _authorizedUsers in storage
     *              6. emit Authorizable_UsersAdded event
     *          Notes:
     *              1. memory to storage write occurs every iteration in nest for loop, can this be optimized?
     *                 Is there batch processing in EVM where all the memory to storage writes can be done in 1 go?
     */
    function addAuthorizedUsers(address[] memory newUsers) public virtual onlyAuthorized {
        // early exit if newUsers is empty
        uint256 newLen = newUsers.length;
        if (newLen == 0) {return;}

        // de-duplicate usersToRemove into deDuped (memory)
        address[] memory deDuped = newLen > 1 ? GeneralUtils.deDupeList(newUsers) : newUsers;
        newLen = deDuped.length;

        // if _authorizedUsers (storage) is empty, just copy deDuped to it and return
        if (_authorizedUsers.length == 0) {
            _authorizedUsers = deDuped;
            return;
        }

        // copy _authorizedUsers (storage) to cached (memory)
        address[] memory cached = _authorizedUsers;
        uint256 cachedLen = cached.length;

        // for each user in deDuped, check if exists in cached
        // if not, push directly to _authorizedUsers in storage
        bool userExists = false;
        for (uint256 i = 0; i < newLen;) {
            address user = deDuped[i];
            for (uint256 j = 0; j < cachedLen;) {
                if (cached[j] == user) {
                    userExists = true;
                    break;
                }
                unchecked {j++;}
            }
            if (!userExists) {
                _authorizedUsers.push(user);
            }
            userExists = false;
            unchecked {i++;}
        }
        emit Authorizable_UsersAdded();
    }
    /*
     * @notice  removeAuthorizedUsers function
     *          Removes users from _authorizedUsers.
     * @dev     Input param is memory, which is alot more expensive than calldata. Any way to optimize to calldata?
     *          Algorithm:
     *              1. early exit if:
     *                  a. empty input array, or 
     *                  b. empty _authorizedUsers
     *              2. de-duplicate input array into deDuped (memory)
     *              3. copy _authorizedUsers (storage) to cached (memory)
     *              4. perform comparisons and removals in memory:
     *                  for each user in deDuped, if exists in cached:
     *                      a. remove user from cached by overwriting cached[j] with last item in cached
     *                      b. shrink cached accordingly by decrementing cachedLen by 1
     *                      c. reevaluate user vs the new cached[j] item
     *              5. perform storage updates in 1 go:
     *                  a. copy final authorized users list from cached (memory) back to _authorizedUsers (storage)
     *                  b. resize (ie: shrink) _authorizedUsers (storage) accordingly
     *              6. emit Authorizable_UsersRemoved event
     *
     * @dev     Gemini claims copy 1st shrink/resize 2nd is more gas efficient than the other way around due to EIP3529. To be verified.
     *          Gemini claims copy 1st shrink/resize 2nd is standard pattern across industry-grade codebases like OpenZeppelin. To be verified.
     */
    function removeAuthorizedUsers(address[] memory usersToRemove) public virtual onlyAuthorized {
        // early exit if (1) usersToRemove is empty, or (2) _authorizedUsers is empty
        uint256 removeLen = usersToRemove.length;
        if (removeLen == 0) {return;}
        uint256 len = _authorizedUsers.length;
        if (len == 0) {return;}

        // de-duplicate usersToRemove into deDuped (memory)
        address[] memory deDuped = removeLen > 1 ? GeneralUtils.deDupeList(usersToRemove) : usersToRemove;
        removeLen = deDuped.length;

        // copy _authorizedUsers (storage) to cached (memory)
        address[] memory cached = _authorizedUsers;
        uint256 cachedLen = cached.length;

        // perform all comparisons and removals in memory
        for (uint256 i = 0; i < removeLen;) {
            address user = deDuped[i];
            for (uint256 j = 0; j < cachedLen;) {
                if (cached[j] == user) {
                    /*
                    // Gemini claims these storage operations performed every iteration are extremely expensive and
                    // it's better to perform all in 1 go later. To be verified.
                    //
                    // remove user from _authorizedUsers in storage by swapping with last item and popping
                    _authorizedUsers[j] = _authorizedUsers[_authorizedUsers.length - 1];
                    _authorizedUsers.pop();
                    */
                    // remove user from cached by:
                    //  1. overwriting cached[j] with last item in array
                    //  2. decrementing cachedLen by 1 to shrink cached accordingly
                    cached[j] = cached[cachedLen - 1];
                    unchecked {cachedLen--;}

                    // continue loop but with same j index, ie: reevaluate user vs the new cached[j]
                    continue;
                }
                unchecked {j++;}
            }
            unchecked {i++;}
        }

        // perform storage updates all in 1 go:
        //  1. copy cached (memory) to _authorizedUsers (storage)
        for (uint256 i = 0; i < cachedLen;) {
            if (_authorizedUsers[i] != cached[i]) {     // saves gas if memory to storage copy not needed
                _authorizedUsers[i] = cached[i];
            }
            unchecked {i++;}
        }

        //  2. shrink _authorizedUsers (storage) accordingly
        len -= cachedLen;
        for (uint256 i = 0; i < len;) {
            _authorizedUsers.pop();
            unchecked {i++;}
        }
        emit Authorizable_UsersRemoved();
    }

    function _isAuthorized(address user) internal virtual view returns (bool) {
        // early exit with false if _authorizedUsers is empty and hence all users are not authorized
        if (_authorizedUsers.length == 0) {return false;}
        address[] memory cached = _authorizedUsers;
        uint256 len = cached.length;
        for (uint256 i = 0; i < len; i++) {
            if (cached[i] == user) {return true;}
        }
        return false;
    }

    /*
     * @notice  deDupeList function
     * @dev     De-duplicates an address[] list and returns a new address[] list with no duplicates and resized appropriately.
     *          A cool assembly optimization trick was used to avoid creating a new memory array and then copying to it.
     *          Trick involves manually overwriting existing memory array size, leaving out-of-scope items to be released at end
     *          of whole transaction.
     */
    /*
    function deDupeListTemp(address[] memory list) internal virtual pure returns (address[] memory) {
        // if list has < 2 items, return as is
        uint256 len = list.length;
        if (len < 2) {return list;}

        // create new temporary memory array deDuped with max possible length to hold de-duped items
        address[] memory deDuped = new address[](len);
        uint256 deDupedCount = 0;

        // for each user in list, check if exists in rest of list
        // if not, increment deDupedCount and copy to deDuped
        bool exists = false;
        for (uint256 i = 0; i < len;) {
            address user = list[i];
            for (uint256 j = i + 1; j < len;) {
                if (list[j] == user) {
                    exists = true;
                    break;
                }
                unchecked {j++;}
            }
            if (!exists) {
                deDuped[deDupedCount] = user;
                unchecked {deDupedCount++;}
            }
            exists = false;
            unchecked {i++;}
        }

        // create new memory array finalList with length deDupedCount, copy all deDuped items to it, then return finalList
        //address[] memory finalList = new address[](deDupedCount);
        //for (uint256 i = 0; i < deDupedCount;) {
        //    finalList[i] = deDuped[i];
        //    unchecked {i++;}
        //}
        //return finalList;

        // this 1 line assembly is more efficient than the above loop copy
        // it updates the length of the existing deDuped in-memory array
        // what this assembly does:
        //      1. mstore writes deDupedCount (ie: new array size) to pointer deDuped
        // notes:
        //      1. deDuped is a pointer to an array of addresses in memory
        //      2. array organization is as such: 1st 32 bytes store length, followed contiguously by each item in the array
        //      3. by shrinking the deDuped array using assembly in this manner, the additional items are still held in memory
        //         but can no longer be referenced by the deDuped pointer
        //         these will only be released at the end of the transaction
        assembly {mstore(deDuped, deDupedCount)}
        return deDuped;
    }
    */
}