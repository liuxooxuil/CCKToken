// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestUSDT is ERC20, Ownable {
    constructor(address[] memory recipients, uint256[] memory amounts) ERC20("Test USDT", "USDT")Ownable(msg.sender) {
        require(recipients.length == amounts.length, "Recipients and amounts length mismatch");
        
        // 发行总量为 200,000
        uint256 totalSupply = 200_000 * 10 ** decimals();
        _mint(address(this), totalSupply); // 将代币铸造到合约地址

        // 分发代币
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(address(this), recipients[i], amounts[i] * 10 ** decimals());
        }
    }

    // 查询持有的代币数量
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    // 提供分发功能
    function distributeTokens(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Recipients and amounts length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(address(this), recipients[i], amounts[i] * 10 ** decimals());
        }
    }
}