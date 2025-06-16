// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IERC3643
 * @dev Interface for on-chain identity management and compliance.
 */
interface IERC3643 {
    /**
     * @dev Returns the on-chain ID of the contract.
     * @return address The address of the contract.
     */
    function onchainID() external view returns (address);
    
    /**
     * @dev Returns the version of the contract.
     * @return string The version string.
     */
    function version() external view returns (string memory);
    
    /**
     * @dev Returns the identity registry address.
     * @return address The identity registry address.
     */
    function identityRegistry() external view returns (address);
    
    /**
     * @dev Returns the compliance address.
     * @return address The compliance address.
     */
    function compliance() external view returns (address);
    
    /**
     * @dev Checks if the contract is paused.
     * @return bool Indicates if the contract is paused.
     */
    function paused() external view returns (bool);
    
    /**
     * @dev Checks if a user is frozen.
     * @param userAddress Address of the user to check.
     * @return bool Indicates if the user is frozen.
     */
    function isFrozen(address userAddress) external view returns (bool);
    
    /**
     * @dev Returns the number of frozen tokens for a user.
     * @param userAddress Address of the user to check.
     * @return uint256 Amount of frozen tokens.
     */
    // function getFrozenTokens(address userAddress) external view returns (uint256);
}