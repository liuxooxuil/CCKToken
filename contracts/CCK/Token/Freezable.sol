// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Freezable {
    mapping(address => bool) public frozen;

    function freezeUser(address user) external {
        frozen[user] = true;
    }

    function unfreezeUser(address user) external {
        frozen[user] = false;
    }

    function isFrozen(address userAddress) external view returns (bool) {
        return frozen[userAddress];
    }
}