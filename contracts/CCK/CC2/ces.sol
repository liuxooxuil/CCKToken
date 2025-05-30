// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ERC20 代币接收合约
contract ERC20Receiver is Ownable {
    // 支持的 ERC20 代币地址
    address public supportedToken;

    // 用户余额
    mapping(address => uint256) public userBalances;

    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed admin, uint256 amount);

    // 构造函数：初始化支持的 ERC20 代币地址
    constructor(address _supportedToken)Ownable(msg.sender)   {
        supportedToken = _supportedToken;
    }

    // 存款函数：用户将指定 ERC20 代币发送到本合约
    function deposit(uint256 _amount) public {
        require(_amount > 0, " 0");
        require(supportedToken != address(0), "1");

        // 转账 ERC20 代币到本合约
        require(IERC20(supportedToken).transferFrom(msg.sender, address(this), _amount), "1");

        // 更新用户余额
        userBalances[msg.sender] += _amount;

        emit Deposit(msg.sender, _amount);
    }

    // 管理员提取合约中的指定 ERC20 代币
    function withdraw(uint256 _amount) public onlyOwner {
        require(_amount > 0, "1 0");
        uint256 contractBalance = IERC20(supportedToken).balanceOf(address(this));
        require(_amount <= contractBalance, "1");

        // 转账 ERC20 代币到管理员
        require(IERC20(supportedToken).transfer(owner(), _amount), "1");

        emit Withdraw(owner(), _amount);
    }

    // 管理员更新支持的 ERC20 代币地址
    function setSupportedToken(address _newToken) public onlyOwner {
        supportedToken = _newToken;
    }

    // 查询用户的余额
    function balanceOf(address _user) public view returns (uint256) {
        return userBalances[_user];
    }
}
