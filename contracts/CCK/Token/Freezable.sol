// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Freezable
 * @dev Contract that allows freezing and unfreezing of user accounts.
 */
contract Freezable {
    // Mapping to track frozen status of user accounts
    mapping(address => bool) public frozen;

    /**
     * @dev Freezes a user account, preventing it from performing certain actions.
     * @param user Address of the user to be frozen.
     */
    function freezeUser(address user) external {
        frozen[user] = true;
    }

    /**
     * @dev Unfreezes a user account, allowing it to perform actions again.
     * @param user Address of the user to be unfrozen.
     */
    function unfreezeUser(address user) external {
        frozen[user] = false;
    }

    /**
     * @dev Checks if a user account is frozen.
     * @param userAddress Address of the user to check.
     * @return bool Indicates if the user account is frozen.
     */
    function isFrozen(address userAddress) external view returns (bool) {
        return frozen[userAddress];
    }
}