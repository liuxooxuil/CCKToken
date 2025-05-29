// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/CCK/ERC3643.sol";

contract CCKToken is ERC20, Ownable, IERC3643 {
    uint256 public constant TOTAL_SUPPLY = 100_000_000_000; // 总供应量调整为100亿 // 总供应量
    mapping(address => bool) public whitelist; // 白名单
    mapping(address => bool) public frozen; // 冻结状态
    address public uniswapPool; // Uniswap V3 池地址
    uint256 public mintedAmount; // 已发行的代币数量
    address public immutable transferReceiver; // 固定接收地址
    address public immutable tokenAddress; // 固定的 ERC20 代币地址
    uint256 public constant MINT_RATIO = 20; // 1:20 铸币比例

    constructor(
        address[] memory _whitelist,
        address _transferReceiver,
        address _tokenAddress
    ) ERC20("CCK", "CCKToken") Ownable(msg.sender) {
        require(_whitelist.length > 0, "At least one whitelisted address required");
        require(_transferReceiver != address(0), "Invalid receiver address");
        require(_tokenAddress != address(0), "Invalid token address");

        // 批量添加白名单成员
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelist[_whitelist[i]] = true;
        }

        // 设置固定接收地址和代币地址
        transferReceiver = _transferReceiver;
        tokenAddress = _tokenAddress;
    }

    // 添加白名单成员
    function addToWhitelist(address member) external onlyOwner {
        whitelist[member] = true;
    }

    // 移除白名单成员
    function removeFromWhitelist(address member) external onlyOwner {
        whitelist[member] = false;
    }

    // 冻结用户
    function freezeUser(address user) external onlyOwner {
        frozen[user] = true;
    }

    // 解冻用户
    function unfreezeUser(address user) external onlyOwner {
        frozen[user] = false;
    }

    // 返回可铸造的剩余代币数量
    function remainingSupply() external view returns (uint256) {
        return TOTAL_SUPPLY - mintedAmount;
    }

    // ERC-3643协议方法实现
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
        return frozen[userAddress];
    }

    function getFrozenTokens(address userAddress) external view override returns (uint256) {
        return 0;
    }

    // 重写转账函数，确保转账金额为整数且不被冻结
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        // require(!frozen[msg.sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transfer(recipient, amount);
    }

    // 重写转账授权函数
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        // require(!frozen[sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transferFrom(sender, recipient, amount);
    }

    // 发行代币，需在白名单内
    function mint(address to, uint256 amount) external onlyOwner {
        // require(whitelist[to], "Not whitelisted");
        require(mintedAmount + amount <= TOTAL_SUPPLY, "Total supply exceeded");
        _mint(to, amount);
        mintedAmount += amount;
    }

    // 重写 ERC20 的 decimals 方法，设置为 0，表示没有小数点
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    // 查看用户持有的代币数量
    function balanceOfUser(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    // 获取当前价格
    function getCurrentPrice() external view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint256 price = uint256(sqrtPriceX96) ** 2 / (2 ** 192);
        return price;
    }

    // 转账并铸造 CCK 代币
    function transferAndMint(uint256 amount) external {
        // require(!frozen[msg.sender], "Sender is frozen");
        require(amount > 0, "Amount must be greater than 0");
        // require(whitelist[msg.sender], "Sender not whitelisted");
        // require(mintedAmount + (amount * MINT_RATIO) <= TOTAL_SUPPLY, "Total supply exceeded");

        // 创建 ERC20 代币合约实例
        IERC20 token = IERC20(tokenAddress);

        // 检查余额和授权
        // require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        require(token.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");

        // 执行转账到固定接收地址
        bool success = token.transferFrom(msg.sender, transferReceiver, amount);
        require(success, "Token transfer failed");

        // 按 1:20 比例铸造 CCK 代币
        uint256 cckAmount = amount * MINT_RATIO;
        _mint(msg.sender, cckAmount);
        mintedAmount += cckAmount;

        // 触发事件
        emit TransferExecuted(tokenAddress, transferReceiver, amount);
    }

    // 事件声明
    event TransferExecuted(address indexed token, address indexed to, uint256 amount);
}