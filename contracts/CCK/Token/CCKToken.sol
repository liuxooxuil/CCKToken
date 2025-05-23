// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Whitelist.sol";
import "./Freezable.sol";
import "./PriceOracle.sol";
import "contracts/CCK/ERC3643.sol";

/**
 * @title CCKToken
 * @dev ERC20 token implementation with additional features such as whitelisting,
 * freezing accounts, and price retrieval from Uniswap V3.
 */
contract CCKToken is ERC20, Ownable, IERC3643 {
    uint256 public constant TOTAL_SUPPLY = 500_000 * 10**18; // Total supply of tokens
    uint256 public mintedAmount; // Amount of tokens already minted
    
    Whitelist public whitelistContract; // Instance of the whitelist contract
    Freezable public freezableContract; // Instance of the freezable contract
    PriceOracle public priceOracle; // Instance of the price oracle contract

    /**
     * @dev Constructor to initialize the token and its associated contracts.
     * @param _whitelist Array of addresses to be added to the whitelist
     * @param _uniswapPool Address of the Uniswap V3 pool for price retrieval
     */
    constructor(address[] memory _whitelist, address _uniswapPool) 
        ERC20("CCK", "CCK") 
        Ownable(msg.sender) 
    {
        whitelistContract = new Whitelist();
        freezableContract = new Freezable();
        priceOracle = new PriceOracle(_uniswapPool);

        require(_whitelist.length > 0, "At least one whitelisted address required");
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelistContract.addToWhitelist(_whitelist[i]);
        }

        _mint(msg.sender, TOTAL_SUPPLY); // Mint total supply to the contract deployer
    }

    /**
     * @dev Mints new tokens to a specified address, if the address is whitelisted.
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(whitelistContract.isWhitelisted(to), "Not whitelisted");
        require(mintedAmount + amount <= TOTAL_SUPPLY, "Total supply exceeded");
        _mint(to, amount);
        mintedAmount += amount;
    }

    /**
     * @dev Transfers tokens to a specified address.
     * @param recipient Address to receive the tokens
     * @param amount Amount of tokens to transfer
     * @return success Indicates if the transfer was successful
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(!freezableContract.isFrozen(msg.sender), "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transfer(recipient, amount);
    }

    /**
     * @dev Transfers tokens from one address to another.
     * @param sender Address to send tokens from
     * @param recipient Address to receive the tokens
     * @param amount Amount of tokens to transfer
     * @return success Indicates if the transfer was successful
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(!freezableContract.isFrozen(sender), "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transferFrom(sender, recipient, amount);
    }

    /**
     * @dev Returns the balance of a specified user.
     * @param user Address of the user to check balance
     * @return balance Amount of tokens held by the user
     */
    function balanceOfUser(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    /**
     * @dev Returns the on-chain ID of the contract.
     * @return address The address of the contract
     */
    function onchainID() external view override returns (address) {
        return address(this);
    }

    /**
     * @dev Returns the version of the contract.
     * @return version The version string
     */
    function version() external view override returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev Returns the identity registry address.
     * @return address The identity registry address (currently returns zero)
     */
    function identityRegistry() external view override returns (address) {
        return address(0);
    }

    /**
     * @dev Returns the compliance address.
     * @return address The compliance address (currently returns zero)
     */
    function compliance() external view override returns (address) {
        return address(0);
    }

    /**
     * @dev Checks if the contract is paused.
     * @return paused Indicates if the contract is paused (always returns false)
     */
    function paused() external view override returns (bool) {
        return false; 
    }

    /**
     * @dev Checks if a user is frozen.
     * @param userAddress Address of the user to check
     * @return frozen Indicates if the user is frozen
     */
    function isFrozen(address userAddress) external view override returns (bool) {
        return freezableContract.isFrozen(userAddress);
    }

    /**
     * @dev Returns the number of frozen tokens for a user.
     * @param userAddress Address of the user to check
     * @return frozenTokens Amount of frozen tokens (currently returns zero)
     */
    function getFrozenTokens(address userAddress) external view override returns (uint256) {
        return 0;
    }

    /**
     * @dev Retrieves the current price from the price oracle.
     * @return price Current price of the token
     */
    function getCurrentPrice() external view returns (uint256) {
        return priceOracle.getCurrentPrice();
    }
}