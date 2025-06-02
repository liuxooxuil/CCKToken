// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenTransfer {
    address public targetAddress; // 接收USDT的目标地址（移除immutable）
    IERC20 public immutable usdtToken; // USDT代币合约
    address public immutable owner; // 合约拥有者

    // 转账事件
    event TokensTransferred(address indexed sender, uint256 amount, address indexed target);
    // 目标地址更新事件
    event TargetAddressUpdated(address indexed oldAddress, address indexed newAddress);

    // 构造函数，初始化USDT合约地址和目标接收地址
    constructor(address _usdtTokenAddress, address _targetAddress) {
        require(_usdtTokenAddress != address(0), "Invalid token address");
        require(_targetAddress != address(0), "Invalid target address");
        usdtToken = IERC20(_usdtTokenAddress);
        targetAddress = _targetAddress;
        owner = msg.sender;
    }

    // 用户调用此函数发送ERC20到目标地址
    function transferTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        
        // 检查用户是否授权足够的USDT给合约
        uint256 allowance = usdtToken.allowance(msg.sender, address(this));
        require(allowance >= amount, "Insufficient allowance");

        // 从用户账户转移USDT到目标地址
        bool success = usdtToken.transferFrom(msg.sender, targetAddress, amount);
        require(success, "Transfer failed");

        // 触发转账事件
        emit TokensTransferred(msg.sender, amount, targetAddress);
    }

    // // 仅限拥有者：更新目标地址
    // function updateTargetAddress(address newTargetAddress) external {
    //     require(msg.sender == owner, "Only owner can update target address");
    //     require(newTargetAddress != address(0), "Invalid target address");
    //     require(newTargetAddress != targetAddress, "New address must be different");

    //     address oldAddress = targetAddress;
    //     targetAddress = newTargetAddress;

    //     // 触发目标地址更新事件
    //     emit TargetAddressUpdated(oldAddress, newTargetAddress);
    // }
}