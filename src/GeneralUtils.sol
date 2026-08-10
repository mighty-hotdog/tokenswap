// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

library GeneralUtils {
    /*
     * @notice  deDupeList function for addresses
     *          De-duplicates an address[] list and returns a new address[] list with no duplicates and resized appropriately.
     * @dev     Optimization tricks used:
     *          1. comparing vs `deDuped` instead of `list` as it's shorter and hence cheaper to check.
     *          2. becos duplicate comparison is with `deDuped`, any candidate value that reaches `deDupedCount` (ie: end of `deDuped`)
     *             is obviously not a duplicate and hence safe to add to `deDuped`.
     *          3. rather than creating a new memory array for returning and copying the final deduped items to it, the existing array's
     *             length is manually overwritten instead, leaving out-of-scope items to be released at end of transaction.
     */
    function deDupeList(address[] memory list) internal pure returns (address[] memory deDuped) {
        // if list has < 2 items, return as is
        uint256 len = list.length;
        if (len < 2) {return list;}

        // create new temporary memory array deDuped with max possible length to hold de-duped items
        deDuped = new address[](len);
        uint256 deDupedCount = 0;

        // for each user in `list`, check if already exists in `deDuped`; `deDuped` is shorter to check than `list`
        // if not, increment deDupedCount and copy to deDuped
        for (uint256 i = 0; i < len;) {
            address user = list[i];

            // 2ndary loop to check if `user` exists in `deDuped`
            uint256 j = 0;
            for (; j < deDupedCount;) {
                if (deDuped[j] == user) {
                    break;
                }
                unchecked {j++;}
            }
            // if j arrived at `deDupedCount`, it means user not found in deDuped
            if (j == deDupedCount) {
                deDuped[deDupedCount] = user;
                unchecked {deDupedCount++;}
            }
            unchecked {i++;}
        }

        /*
        // create new memory array finalList with length deDupedCount, copy all deDuped items to it, then return finalList
        address[] memory finalList = new address[](deDupedCount);
        for (uint256 i = 0; i < deDupedCount;) {
            finalList[i] = deDuped[i];
            unchecked {i++;}
        }
        return finalList;
        */

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
    }

    /*
     * @notice  deDupeList function for bytes
     *          De-duplicates a bytes[] list and returns a new address[] list with no duplicates and resized appropriately.
     * @dev     Comparing `bytes` is a pain as "==" cannot be used directly - need to compare hashes instead.
     *          And becos hashing is expensive, comparing lengths 1st will eliminate `bytes` of different lengths straight away
     *          without having to hash them.
     * @dev     Optimization tricks used:
     *          1. comparing vs `deDuped` instead of `list` as it's shorter and hence cheaper to check.
     *          2. these 2 lines yield identical output:
     *                  bytes32 userHash = keccak256(user);                     // hashes `user` right where it is in-memory
     *                  bytes32 userHash = keccak256(abi.encodePacked(user));   // allocates new memory scratchpad, copies `user` data
     *                                                                          // to it (ie: w/o length slot and without padding),
     *                                                                          // then pass to keccak256 to be hashed
     *             hence using line (1) is way more efficient.
     *          3. becos duplicate comparison is with `deDuped`, any candidate value that reaches `deDupedCount` (ie: end of `deDuped`)
     *             is obviously not a duplicate and hence safe to add to `deDuped`.
     *          4. rather than creating a new memory array for returning and copying the final deduped items to it, the existing array's
     *             length is manually overwritten instead, leaving out-of-scope items to be released at end of transaction.
     */
    function deDupeList(bytes[] memory list) internal pure returns (bytes[] memory deDuped) {
        // if list has < 2 items, return as is
        uint256 len = list.length;
        if (len < 2) {return list;}

        // create new temporary memory array deDuped with max possible length to hold de-duped items
        deDuped = new bytes[](len);
        bytes32[] memory deDupedHashes = new bytes32[](len);    // contains the hashes of `deDuped` items
        uint256 deDupedCount = 0;

        // for each user in `list`, check if already exists in `deDuped`; `deDuped` is shorter & cheaper to check than `list`
        // if not, increment deDupedCount and copy to deDuped
        for (uint256 i = 0; i < len;) {
            bytes memory user = list[i];
            bytes32 userHash = keccak256(user);     // hash of `user`, precalc just once to compare with `deDuped` hashes
            uint256 userLen = user.length;          // length of `user`, again obtained just once for comparison loop

            // 2ndary loop to check if `user` exists in `deDuped`
            uint256 j = 0;
            for (; j < deDupedCount;) {
                if ((deDuped[j].length == userLen) && 
                    (deDupedHashes[j] == userHash)) {
                    break;
                }
                unchecked {j++;}
            }
            // if j arrived at `deDupedCount`, it means user not found in deDuped
            if (j == deDupedCount) {
                deDuped[deDupedCount] = user;
                deDupedHashes[deDupedCount] = userHash;
                unchecked {deDupedCount++;}
            }
            unchecked {i++;}
        }
        // overwrite `deDuped` array length with `deDupedCount`
        // out-of-scope items will be released at end of transaction
        // this saves having to create new array for return and copying to it
        assembly {mstore(deDuped, deDupedCount)}
    }
}