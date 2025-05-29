// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/CCK/ERC3643.sol";

contract CCKToken is ERC20, Ownable, IERC3643 {
    uint256 public constant TOTAL_SUPPLY = 500_000 * 10**18; // 总供应量
    mapping(address => bool) public whitelist; // 白名单
    mapping(address => bool) public frozen; // 冻结状态
    address public uniswapPool; // Uniswap V3 池地址
    uint256 public mintedAmount; // 已发行的代币数量
    string public tokenName; // 自定义代币名称状态变量

    // 治理相关状态变量
    address[] public voters; // 投票人员地址列表
    mapping(address => bool) public hasVoted; // 记录每个地址是否已投票
    uint256 public voteCount; // 当前投票数量
    uint256 public totalVotesRequired = 5; // 需要的总票数
    bool public proposalActive; // 当前提案是否有效
    bool public votingPaused; // 投票状态
    bool public contractPaused; // 合约暂停状态
    uint256 public changeTimestamp; // 更改名称的时间戳
    string public newProposedName; // 新提议名称

    // 事件
    event NameChanged(string newName); // 名称更改事件
    event ProposalCreated(string newName); // 提案创建事件
    event VotingPaused(); // 投票已暂停事件
    event VotingResumed(); // 投票已恢复事件
    event ContractPaused(); // 合约已暂停事件
    event ContractResumed(); // 合约已恢复事件

    // 修饰符
    modifier onlyVoter() {
        require(isVoter(msg.sender), "Not a voter");
        _;
    }

    modifier whenNotPaused() {
        require(!contractPaused, "Contract is paused");
        _;
    }

    constructor(
        string memory initialName,
        address[] memory _whitelist,
        address[] memory _voters,
        address _uniswapPool
    ) ERC20(initialName, "CCKToken") Ownable(msg.sender) {
        require(_whitelist.length > 0, "At least one whitelisted address required");
        require(_voters.length > 0, "At least one voter required");

        // 初始化白名单
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelist[_whitelist[i]] = true;
        }

        // 初始化投票者
        voters = _voters;
        proposalActive = false;
        voteCount = 0;
        votingPaused = false;
        contractPaused = false;
        uniswapPool = _uniswapPool;
        tokenName = initialName; // 初始化自定义代币名称
    }

    // 重写 name() 函数以返回自定义 tokenName
    function name() public view virtual override returns (string memory) {
        return tokenName;
    }

    // 检查是否为投票者
    function isVoter(address _voter) internal view returns (bool) {
        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i] == _voter) {
                return true;
            }
        }
        return false;
    }

    // 提出新代币名称提案
    function proposeNewName(string memory newName) public onlyVoter whenNotPaused {
        require(!proposalActive, "Proposal already active");
        resetVotes();
        voteCount = 0;
        newProposedName = newName;
        proposalActive = true;
        emit ProposalCreated(newName);
    }

    // 重置投票记录
    function resetVotes() internal {
        for (uint256 i = 0; i < voters.length; i++) {
            hasVoted[voters[i]] = false;
        }
    }

    // 投票
    function vote() public onlyVoter whenNotPaused {
        require(proposalActive, "No active proposal");
        require(!hasVoted[msg.sender], "Already voted");
        require(!votingPaused, "Voting is paused");

        hasVoted[msg.sender] = true;
        voteCount++;

        if (voteCount >= totalVotesRequired) {
            changeTimestamp = block.timestamp + 2 minutes;
        }
    }

    // 更改代币名称
    function changeName() public whenNotPaused {
        require(block.timestamp >= changeTimestamp, "Change not allowed yet");
        require(voteCount >= totalVotesRequired, "Not enough votes");

        _setName(newProposedName);
        proposalActive = false;
        emit NameChanged(newProposedName);
    }

    // 暂停投票
    function pauseVoting() public onlyOwner {
        votingPaused = true;
        emit VotingPaused();
    }

    // 恢复投票
    function resumeVoting() public onlyOwner {
        votingPaused = false;
        emit VotingResumed();
    }

    // 暂停合约
    function pauseContract() public onlyVoter whenNotPaused {
        require(voteCount < totalVotesRequired, "Already enough votes to pause");
        resetVotes();
        voteCount = 0;
        contractPaused = true;
        emit ContractPaused();
    }

    // 恢复合约
    function resumeContract() public onlyVoter whenNotPaused {
        require(voteCount < totalVotesRequired, "Already enough votes to resume");
        resetVotes();
        voteCount = 0;
        contractPaused = false;
        emit ContractResumed();
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

    // 发行代币
    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        require(whitelist[to], "Not whitelisted");
        require(mintedAmount + amount <= TOTAL_SUPPLY, "Total supply exceeded");
        _mint(to, amount);
        mintedAmount += amount;
    }

    // 重写转账函数
    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!frozen[msg.sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transfer(recipient, amount);
    }

    // 重写转账授权函数
    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!frozen[sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transferFrom(sender, recipient, amount);
    }

    // 获取当前价格
    function getCurrentPrice() external view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint256 price = uint256(sqrtPriceX96) ** 2 / (2 ** 192);
        return price;
    }

    // 重写 decimals 方法
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    // 查看用户余额
    function balanceOfUser(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    // ERC-3643 接口实现
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
        return contractPaused;
    }

    function isFrozen(address userAddress) external view override returns (bool) {
        return frozen[userAddress];
    }

    function getFrozenTokens(address userAddress) external view override returns (uint256) {
        return 0;
    }

    // 内部函数：设置代币名称
    function _setName(string memory newName) internal {
        tokenName = newName; // 更新自定义代币名称
    }
}