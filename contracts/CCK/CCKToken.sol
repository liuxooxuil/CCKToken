// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
/// 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol"; 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/CCK/ERC3643.sol";
 
contract CCKToken is ERC20, Ownable, IERC3643 {

    
    // uint256 public constant TOTAL_SUPPLY = 500_000 * 10**18; // 总供应量

    uint256 public constant TOTAL_SUPPLY = 500_000; // 总供应量
    mapping(address => bool) public whitelist; // 白名单
    mapping(address => bool) public frozen; // 冻结状态
    address public uniswapPool; // Uniswap V3 池地址
    uint256 public mintedAmount; // 已发行的代币数量

    constructor(address[] memory _whitelist) ERC20("CCK", "CCKToken") Ownable(msg.sender) {
        require(_whitelist.length > 0, "At least one whitelisted address required");
        
        // 批量添加白名单成员
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelist[_whitelist[i]] = true;
        }

        // _mint(msg.sender, TOTAL_SUPPLY); // 初始发行总量
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
        return TOTAL_SUPPLY - mintedAmount; // 计算剩余的可铸造数量
    }

    // ERC-3643协议方法实现
    function onchainID() external view override returns (address) {
        return address(this);
    }

    function version() external view override returns (string memory) {
        return "1.0.0";
    }

    function identityRegistry() external view override returns (address) {
        return address(0); // 返回身份注册合约地址
    }

    function compliance() external view override returns (address) {
        return address(0); // 返回合规性合约地址
    }

    function paused() external view override returns (bool) {
        return false; 
    }

    function isFrozen(address userAddress) external view override returns (bool) {
        return frozen[userAddress]; // 返回用户冻结状态
    }

    function getFrozenTokens(address userAddress) external view override returns (uint256) {
        return 0; // 目前没有冻结的代币逻辑
    }

    // 重写转账函数，确保转账金额为整数且不被冻结
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(!frozen[msg.sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transfer(recipient, amount);
    }

    // 重写转账授权函数
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(!frozen[sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transferFrom(sender, recipient, amount);
    }

    // 发行代币，需在白名单内
    function mint(address to, uint256 amount) external onlyOwner {
        require(whitelist[to], "Not whitelisted");
        require(mintedAmount + amount <= TOTAL_SUPPLY, "Total supply exceeded");
        _mint(to, amount);
        mintedAmount += amount;
    }

      // 重写 ERC20 的 decimals 方法，设置为 0，表示没有小数点
    function decimals() public view virtual override returns (uint8) {
        return 0; // 没有小数位
    }

    // 查看用户持有的代币数量
    function balanceOfUser(address user) external view returns (uint256) {
        return balanceOf(user); // 调用ERC20的balanceOf方法
    }

        // 获取当前价格
    function getCurrentPrice() external view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        // 价格计算：sqrtPriceX96 转换为价格
        uint256 price = uint256(sqrtPriceX96) ** 2 / (2 ** (192)); // 计算实际价格
        return price; // 返回当前价格
    }
}