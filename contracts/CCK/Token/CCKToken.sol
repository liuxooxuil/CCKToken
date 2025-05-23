// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Whitelist.sol";
import "./Freezable.sol";
import "./PriceOracle.sol";
import "contracts/CCK/ERC3643.sol";

contract CCKToken is ERC20, Ownable, IERC3643 {
    uint256 public constant TOTAL_SUPPLY = 500_000 * 10**18;
    uint256 public mintedAmount;
    
    Whitelist public whitelistContract;
    Freezable public freezableContract;
    PriceOracle public priceOracle;

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

        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(whitelistContract.isWhitelisted(to), "Not whitelisted");
        require(mintedAmount + amount <= TOTAL_SUPPLY, "Total supply exceeded");
        _mint(to, amount);
        mintedAmount += amount;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(!freezableContract.isFrozen(msg.sender), "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(!freezableContract.isFrozen(sender), "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transferFrom(sender, recipient, amount);
    }

    function balanceOfUser(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    function onchainID() external view override returns (address) {
        return address(this);
    }

    function version() external view override returns (string memory) {
        return "1.0.0";
    }

    function identityRegistry() external view override returns (address) {
        return address(0);
    }

    function compliance() external view override returns (address) {
        return address(0);
    }

    function paused() external view override returns (bool) {
        return false; 
    }

    function isFrozen(address userAddress) external view override returns (bool) {
        return freezableContract.isFrozen(userAddress);
    }

    function getFrozenTokens(address userAddress) external view override returns (uint256) {
        return 0; // 目前没有冻结的代币逻辑
    }

    function getCurrentPrice() external view returns (uint256) {
        return priceOracle.getCurrentPrice();
    }
}