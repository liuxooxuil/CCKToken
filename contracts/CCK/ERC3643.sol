// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC3643 {
    function onchainID() external view returns (address);
    function version() external view returns (string memory);
    function identityRegistry() external view returns (address);
    function compliance() external view returns (address);
    function paused() external view returns (bool);
    function isFrozen(address userAddress) external view returns (bool);
    function getFrozenTokens(address userAddress) external view returns (uint256);
}