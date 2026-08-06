// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

library StringUtils {
    function toBytes32(string memory s) internal pure returns (bytes32 result) {
        // what the assembly does:
        //      1. adds 32 to pointer 's'
        //      2. loads 32 bytes from pointer to 'result'
        // explanation:
        //      's' points to start of string
        //      string is organized as such: 1st 32 bytes store length, followed by data
        //      adding 32 to 's' shifts pointer to start of data
        //      mload (by definition) loads 32 bytes from pointer position to 'result'
        //      since 'result' is the named bytes32 return variable, it is automatically returned
        // notes:
        //      1. 'mload' reads (aka loads) 32 bytes (ie: 1 EVM word) from memory
        //         costs 3 gas
        //         takes 1 input: pointer to memory location
        //         returns the 32-byte value at that memory location
        //         does NOT modify memory
        //      2. returns '0x0' if string == "" (ie: empty)
        //      3. truncates string if longer than 32 bytes
        //      4. right-fills with '0x0' if string is shorter than 32 bytes,
        //         this is the correct behavior for Solidity/EVM.
        //      5. assumes string storage and 'mload' command are implemented correctly and do not change across versions,
        //         these assumptions are reasonable
        assembly {
            result := mload(add(s,32))
        }
    }

    function toString(bytes32 b) internal pure returns (string memory) {
        // find length of data by scanning 'b' from right (ie: least significant byte) and stopping at 1st non-zero byte
        uint256 len = 32;
        while (len > 0 && b[len - 1] == 0) {
            len--;
        }
        // define new bytes array 'str' of length 'len' and copy data from 'b'
        // notes:
        //      1. 'bytes' is a dynamic byte array almost identical to 'string': both are stored in memory, also 1st 32 bytes store length
        //         only difference is 'string' is assumed to be utf8 encoded
        //      2. 'mstore' writes (aka stores) 32 bytes to memory
        //         costs 3 gas + additional 100+ if memory needs to be dynamically expanded
        //         takes 2 inputs: pointer to memory location, and 32-byte value to write
        //         overwrites whatever was at that memory location
        //         returns nothing
        bytes memory str = new bytes(len);
        assembly {
            // 1. add 32 to pointer 'str'
            // 2. copy data from 'b' to 'str'
            mstore(add(str, 32), b)
        }
        // cast bytes array to string and return
        return string(str);
    }
}