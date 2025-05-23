// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Whitelist
 * @dev A contract that manages a whitelist of addresses.
 */
contract Whitelist {
    // Mapping to track whitelisted addresses
    mapping(address => bool) public whitelist;

    /**
     * @dev Adds a member to the whitelist.
     * @param member Address of the user to be added to the whitelist.
     */
    function addToWhitelist(address member) external {
        whitelist[member] = true;
    }

    /**
     * @dev Removes a member from the whitelist.
     * @param member Address of the user to be removed from the whitelist.
     */
    function removeFromWhitelist(address member) external {
        whitelist[member] = false;
    }

    /**
     * @dev Checks if a member is in the whitelist.
     * @param member Address of the user to check.
     * @return bool Indicates if the user is whitelisted.
     */
    function isWhitelisted(address member) external view returns (bool) {
        return whitelist[member];
    }
}