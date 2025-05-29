// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/CCK/ERC3643.sol";

// CCKToken 合约，继承 ERC20、Ownable 和 IERC3643，整合治理功能
contract CCKToken is ERC20, Ownable, IERC3643 {
    // 总供应量，固定为 500,000 代币，精度为 18
    uint256 public constant TOTAL_SUPPLY = 500_000 * 10**18;
    // 白名单映射，记录允许接收新铸造代币的地址
    mapping(address => bool) public whitelist;
    // 冻结状态映射，记录用户账户是否被冻结
    mapping(address => bool) public frozen;
    // Uniswap V3 资金池地址，用于查询价格
    address public uniswapPool;
    // 已铸造的代币数量
    uint256 public mintedAmount;
    // 自定义代币名称状态变量，用于治理更改名称
    string public tokenName;

    // 治理相关状态变量
    // 投票者地址列表
    address[] public voters;
    // 记录每个地址是否已投票
    mapping(address => bool) public hasVoted;
    // 当前投票数量
    uint256 public voteCount;
    // 提案通过所需的总票数，默认为 5
    uint256 public totalVotesRequired = 5;
    // 当前是否有一个活跃的提案
    bool public proposalActive;
    // 投票是否暂停
    bool public votingPaused;
    // 合约是否暂停
    bool public contractPaused;
    // 更改名称的时间戳（需等待 2 分钟）
    uint256 public changeTimestamp;
    // 新提议的代币名称
    string public newProposedName;

    // 事件
    // 代币名称更改事件
    event NameChanged(string newName);
    // 提案创建事件
    event ProposalCreated(string newName);
    // 投票暂停事件
    event VotingPaused();
    // 投票恢复事件
    event VotingResumed();
    // 合约暂停事件
    event ContractPaused();
    // 合约恢复事件
    event ContractResumed();

    // 修饰符
    // 限制只有投票者可以调用
    modifier onlyVoter() {
        require(isVoter(msg.sender), "Not a voter");
        _;
    }

    // 限制合约未暂停时调用
    modifier whenNotPaused() {
        require(!contractPaused, "Contract is paused");
        _;
    }

    // 构造函数，初始化代币名称、白名单、投票者和 Uniswap 池地址
    constructor(
        string memory initialName, // 初始代币名称
        address[] memory _whitelist, // 白名单地址列表
        address[] memory _voters, // 投票者地址列表
        address _uniswapPool // Uniswap V3 资金池地址
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

    // 重写 name() 函数，返回自定义代币名称
    function name() public view virtual override returns (string memory) {
        return tokenName;
    }

    // 内部函数：检查地址是否为投票者
    function isVoter(address _voter) internal view returns (bool) {
        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i] == _voter) {
                return true;
            }
        }
        return false;
    }

    // 提出新的代币名称提案，仅限合约管理员
    function proposeNewName(string memory newName) public onlyOwner whenNotPaused {
        require(!proposalActive, "Proposal already active");
        resetVotes();
        voteCount = 0;
        newProposedName = newName;
        proposalActive = true;
        emit ProposalCreated(newName);
    }

    // 内部函数：重置投票记录
    function resetVotes() internal {
        for (uint256 i = 0; i < voters.length; i++) {
            hasVoted[voters[i]] = false;
        }
    }

    // 投票函数，仅限投票者
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

    // 更改代币名称，需满足投票和时间要求
    function changeName() public whenNotPaused {
        require(block.timestamp >= changeTimestamp, "Change not allowed yet");
        require(voteCount >= totalVotesRequired, "Not enough votes");

        _setName(newProposedName);
        proposalActive = false;
        emit NameChanged(newProposedName);
    }

    // 暂停投票，仅限合约管理员
    function pauseVoting() public onlyOwner {
        votingPaused = true;
        emit VotingPaused();
    }

    // 恢复投票，仅限合约管理员
    function resumeVoting() public onlyOwner {
        votingPaused = false;
        emit VotingResumed();
    }

    // 暂停合约，仅限投票者
    function pauseContract() public onlyVoter whenNotPaused {
        require(voteCount < totalVotesRequired, "Already enough votes to pause");
        resetVotes();
        voteCount = 0;
        contractPaused = true;
        emit ContractPaused();
    }

    // 恢复合约，仅限投票者
    function resumeContract() public onlyVoter whenNotPaused {
        require(voteCount < totalVotesRequired, "Already enough votes to resume");
        resetVotes();
        voteCount = 0;
        contractPaused = false;
        emit ContractResumed();
    }

    // 添加白名单成员，仅限合约管理员
    function addToWhitelist(address member) external onlyOwner {
        whitelist[member] = true;
    }

    // 移除白名单成员，仅限合约管理员
    function removeFromWhitelist(address member) external onlyOwner {
        whitelist[member] = false;
    }

    // 冻结用户，仅限合约管理员
    function freezeUser(address user) external onlyOwner {
        frozen[user] = true;
    }

    // 解冻用户，仅限合约管理员
    function unfreezeUser(address user) external onlyOwner {
        frozen[user] = false;
    }

    // 返回可铸造的剩余代币数量
    function remainingSupply() external view returns (uint256) {
        return TOTAL_SUPPLY - mintedAmount;
    }

    // 铸造代币，仅限合约管理员，目标地址需在白名单内
    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        require(whitelist[to], "Not whitelisted");
        require(mintedAmount + amount <= TOTAL_SUPPLY, "Total supply exceeded");
        _mint(to, amount);
        mintedAmount += amount;
    }

    // 重写转账函数，确保未被冻结且合约未暂停
    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!frozen[msg.sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transfer(recipient, amount);
    }

    // 重写授权转账函数，确保未被冻结且合约未暂停
    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!frozen[sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transferFrom(sender, recipient, amount);
    }

    // 从 Uniswap V3 资金池获取当前价格
    function getCurrentPrice() external view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint256 price = uint256(sqrtPriceX96) ** 2 / (2 ** 192);
        return price;
    }

    // 重写 decimals 方法，设置为 0（无小数位）
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    // 查看用户代币余额
    function balanceOfUser(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    // ERC-3643 接口实现
    // 返回链上 ID
    function onchainID() external view override returns (address) {
        return address(this);
    }

    // 返回合约版本
    function version() external view override returns (string memory) {
        return "1.0.0";
    }

    // 返回身份注册合约地址
    function identityRegistry() external view override returns (address) {
        return address(0);
    }

    // 返回合规性合约地址（暂未实现）
    function compliance() external view override returns (address) {
        return address(0);
    }

    // 返回合约暂停状态
    function paused() external view override returns (bool) {
        return contractPaused;
    }

    // 返回用户是否被冻结
    function isFrozen(address userAddress) external view override returns (bool) {
        return frozen[userAddress];
    }

    // 返回冻结的代币数量（当前为 0，无具体逻辑）
    function getFrozenTokens(address userAddress) external view override returns (uint256) {
        return 0;
    }

    // 内部函数：设置代币名称
    function _setName(string memory newName) internal {
        tokenName = newName; // 更新自定义代币名称
    }
}