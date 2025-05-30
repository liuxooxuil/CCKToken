// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 货币兑换合约：用户传入指定 ERC20 代币，合约按 1:20 比例铸造 RWT 代币
contract CurrencyExchange is ReentrancyGuard {
    // 代币属性
    string public name = "RewardToken"; // 代币名称
    string public symbol = "RWT"; // 代币符号
    uint256 public decimals = 18; // 小数位数
    uint256 public totalSupply; // 总供应量

    // 合约属性
    address public admin; // 管理员地址
    address public supportedToken; // 支持的 ERC20 代币地址
    uint256 public constant EXCHANGE_RATE = 20; // 兑换比例：1 单位输入代币 = 20 RWT

    // 映射
    mapping(address => uint256) public balanceOf; // RWT 代币余额
    mapping(address => mapping(address => uint256)) public allowance; // RWT 代币授权金额

    // 事件
    event Transfer(address indexed from, address indexed to, uint256 value); // 转账事件
    event Approval(address indexed owner, address indexed spender, uint256 value); // 授权事件
    event DepositToken(address indexed user, address token, uint256 amount, uint256 tokenAmount, uint256 balance); // 存款事件
    event WithdrawToken(address indexed admin, address token, uint256 amount); // 取款事件

    // 构造函数：初始化管理员和支持的 ERC20 代币地址
    constructor(address _supportedToken) {
        admin = msg.sender;
        supportedToken = _supportedToken;
    }

    // 存款 ERC20 代币：用户传入指定代币，合约铸造 RWT 代币
    function depositToken(uint256 _amount) public nonReentrant {
        require(_amount > 0, "1 0");
        require(supportedToken != address(0), "1");
        require(IERC20(supportedToken).transferFrom(msg.sender, address(this), _amount), "1");

        uint256 tokenAmount = _amount * EXCHANGE_RATE;
        _mint(msg.sender, tokenAmount);

        emit DepositToken(msg.sender, supportedToken, _amount, tokenAmount, balanceOf[msg.sender]);
    }

    // 内部铸造函数：铸造 RWT 代币给指定地址
    function _mint(address _to, uint256 _amount) internal {
        require(_to != address(0), "1");
        totalSupply += _amount;
        balanceOf[_to] += _amount;
        emit Transfer(address(0), _to, _amount);
    }

    // 转账函数：转移 RWT 代币
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "1");
        require(balanceOf[msg.sender] >= _value, "1");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    // 授权函数：允许 spender 花费指定数量的 RWT 代币
    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "1");

        allowance[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);

        return true;
    }

    // 从授权账户转账：spender 从 from 转移 RWT 代币
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "1");
        require(_value <= balanceOf[_from], "1");
        require(_value <= allowance[_from][msg.sender], "1");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);

        return true;
    }

    // 查询 RWT 代币余额
    function balanceOfRWT(address _user) public view returns (uint256) {
        return balanceOf[_user];
    }

    // 管理员提取合约中的指定 ERC20 代币
    function withdrawToken(uint256 _amount) public {
        require(msg.sender == admin, "1");
        require(supportedToken != address(0), "1");
        require(_amount <= IERC20(supportedToken).balanceOf(address(this)), "1");

        require(IERC20(supportedToken).transfer(admin, _amount), "1");

        emit WithdrawToken(admin, supportedToken, _amount);
    }

    // 管理员更新支持的 ERC20 代币地址
    function setSupportedToken(address _newToken) public {
        require(msg.sender == admin, "1");
        supportedToken = _newToken;
    }
}
