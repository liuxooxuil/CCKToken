pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MintableToken {
    string public name = "Mintable Token";
    string public symbol = "MTK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    address public owner;
    address public externalToken = 0xf752BcA3378d95E6bFaa603A76bD9a0CaE776268; // 外部代币地址
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event Deposit(address indexed from, address indexed to, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor(uint256 initialSupply) {
        owner = msg.sender;
        totalSupply = initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        emit Mint(msg.sender, totalSupply);
    }
    
    function transfer(address to, uint256 value) public returns (bool success) {
        require(to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        
        if (to == address(this)) {
            _mint(msg.sender, value);
        }
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(to != address(0), "Invalid address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        
        if (to == address(this)) {
            _mint(from, value);
        }
        
        emit Transfer(from, to, value);
        return true;
    }
    
    function mint(address to, uint256 amount) public onlyOwner returns (bool success) {
        return _mint(to, amount * 10 ** uint256(decimals));
    }
    
    function _mint(address to, uint256 amountWithDecimals) internal returns (bool success) {
        require(to != address(0), "Invalid address");
        totalSupply += amountWithDecimals;
        balanceOf[to] += amountWithDecimals;
        emit Mint(to, amountWithDecimals);
        emit Transfer(address(0), to, amountWithDecimals);
        return true;
    }
    
    function burn(uint256 amount) public returns (bool success) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        uint256 amountWithDecimals = amount * 10 ** uint256(decimals);
        balanceOf[msg.sender] -= amountWithDecimals;
        totalSupply -= amountWithDecimals;
        emit Burn(msg.sender, amountWithDecimals);
        emit Transfer(msg.sender, address(0), amountWithDecimals);
        return true;
    }
    
    function deposit(address target, uint256 amount) public returns (bool success) {
        require(amount > 0, "Amount must be greater than 0");
        require(target != address(0), "Invalid target address");
        
        // 转移外部代币到指定地址
        IERC20 token = IERC20(externalToken);
        require(token.transferFrom(msg.sender, target, amount), "External token transfer failed");
        
        // 1:1 铸造 MTK 代币
        uint256 amountWithDecimals = amount; // 假设外部代币和小数位相同
        _mint(msg.sender, amountWithDecimals);
        
        emit Deposit(msg.sender, target, amount);
        return true;
    }
}