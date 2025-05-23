// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Whitelist {
    mapping(address => bool) public whitelist;

    function addToWhitelist(address member) external {
        whitelist[member] = true;
    }

    function removeFromWhitelist(address member) external {
        whitelist[member] = false;
    }

    function isWhitelisted(address member) external view returns (bool) {
        return whitelist[member];
    }
}