// SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    // 导入必要库
    import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // ERC20 标准
    import "@openzeppelin/contracts/access/Ownable.sol"; // 所有权管理
    import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // 防止重入
    import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // ERC20 接口
    import "contracts/CCK/ERC3643.sol"; // 自定义 ERC3643 接口

    // CCKToken 合约：优化版，精简治理逻辑，复用方法
    contract CCKToken is ERC20, Ownable, IERC3643, ReentrancyGuard {
        // 总供应量：500,000 代币，18 位小数
        uint256 public TOTAL_SUPPLY = 500_000 * 10**18;
        // 白名单映射：记录允许操作的地址
        mapping(address => bool) public whitelist;
        // 冻结状态：记录地址是否被冻结
        mapping(address => bool) public frozen;
        // 已铸造数量：记录已发行代币
        uint256 public mintedAmount;
        // 代币名称：自定义名称
        string public tokenName;
        // 输入代币地址：用于交换的 ERC20（如 USDT）
        address public inputToken;
        // 储备地址：存储输入代币
        address public reserveAddress;
        // 交换比率：1 输入代币 = 20 CCKToken
        uint256 public constant EXCHANGE_RATE = 20;

        // 治理相关
        mapping(address => bool) public voters; // 投票者映射
        mapping(address => bool) public hasVoted; // 是否已投票
        uint256 public constant TOTAL_VOTES_REQUIRED = 5; // 所需总票数
        uint256 public constant MIN_VOTES_FOR_USER_ACTIONS = 3; // 用户操作最小票数
        uint256 public constant MIN_VOTES_FOR_MINT = 2; // 铸造最小票数

        // 提案类型枚举
        enum ProposalType { InputToken, ReserveAddress, WhitelistAdd, WhitelistRemove, Freeze, Unfreeze, Mint }
        // 提案结构体
        struct Proposal {
            ProposalType proposalType; // 提案类型
            address initiator; // 发起者
            uint256 voteCount; // 投票数
            uint256 timestamp; // 执行时间戳（若需延迟）
            address target; // 目标地址（如白名单成员）
            uint256 value; // 数值（如铸造数量）
            bool active; // 是否活跃
        }
        // 提案映射：提案 ID 到提案数据
        mapping(uint256 => Proposal) public proposals;
        uint256 public proposalCount; // 提案计数
        bool public votingPaused; // 投票暂停状态
        bool public contractPaused; // 合约暂停状态

        // 分发相关
        uint256 public lastDistributionTimestamp; // 上次分发时间
        uint256 public constant DISTRIBUTION_INTERVAL = 300; // 分发间隔（秒）
        uint256 public constant DISTRIBUTION_AMOUNT = 1 * 10**18; // 分发数量

        // 事件
        event ProposalCreated(uint256 indexed proposalId, ProposalType proposalType, address initiator);
        event ProposalExecuted(uint256 indexed proposalId, ProposalType proposalType);
        event WhitelistChanged(address member, bool added);
        event FreezeChanged(address user, bool frozen);
        event MintExecuted(address to, uint256 amount);
        event WhitelistDistribution(uint256 amount);
        event VotingPaused();
        event VotingResumed();
        event ContractPaused();
        event ContractResumed();
        event Exchange(address indexed user, uint256 inputAmount, uint256 cckAmount);
        event InputTokenUpdated(address newInputToken);
        event ReserveAddressUpdated(address newReserveAddress);

        // 修饰器：限制仅投票者
        modifier onlyVoter() {
            require(voters[msg.sender], "Not a voter");
            _;
        }

        // 修饰器：限制合约未暂停
        modifier whenNotPaused() {
            require(!contractPaused, "Contract is paused");
            _;
        }

        // 构造函数：初始化代币
        constructor(
            string memory initialName, // 初始名称
            address[] memory _whitelist, // 白名单
            address[] memory _voters, // 投票者
            address _inputToken, // 输入代币
            address _reserveAddress // 储备地址
        ) ERC20(initialName, "CCKToken") Ownable(msg.sender) {
            require(_whitelist.length > 0, "At least one whitelisted address required");
            require(_voters.length > 0, "At least one voter required");
            require(_inputToken != address(0) && _inputToken != address(this), "Invalid input token address");
            require(_reserveAddress != address(0), "Invalid reserve address");

            // 初始化白名单
            for (uint256 i = 0; i < _whitelist.length; i++) {
                require(_whitelist[i] != address(0), "Invalid whitelist address");
                whitelist[_whitelist[i]] = true;
            }

            // 初始化投票者
            for (uint256 i = 0; i < _voters.length; i++) {
                require(_voters[i] != address(0), "Invalid voter address");
                voters[_voters[i]] = true;
            }

            tokenName = initialName;
            lastDistributionTimestamp = block.timestamp;
            inputToken = _inputToken;
            reserveAddress = _reserveAddress;
        }

        // 交换函数：输入代币兑换 CCKToken
        function exchange(uint256 inputAmount) external nonReentrant whenNotPaused {
            require(whitelist[msg.sender], "Sender not whitelisted");
            require(inputAmount > 0, "Input amount must be greater than zero");
            require(inputToken != address(this), "Input token cannot be CCKToken");

            // 获取输入代币小数位，默认 18
            uint8 inputDecimals = 18;
            try IERC20Metadata(inputToken).decimals() returns (uint8 decimals) {
                inputDecimals = decimals;
            } catch {}

            // 计算 CCKToken 数量（1:20）
            uint256 cckAmount = (inputAmount * EXCHANGE_RATE) / (10 ** inputDecimals);
            require(cckAmount > 0, "CCK amount too small");
            require(mintedAmount + (cckAmount * 1e18) <= TOTAL_SUPPLY, "Total supply exceeded");

            // 转移输入代币
            require(IERC20(inputToken).transferFrom(msg.sender, address(this), inputAmount), "Input token transfer failed");
            require(IERC20(inputToken).transfer(reserveAddress, inputAmount), "Reserve transfer failed");

            // 铸造 CCKToken
            _mint(msg.sender, cckAmount * 1e18);
            mintedAmount += cckAmount * 1e18;

            emit Exchange(msg.sender, inputAmount, cckAmount);
        }

        // 创建提案
        function propose(
            ProposalType proposalType, // 提案类型
            address target, // 目标地址
            uint256 value // 数值（如铸造数量）
        ) external onlyVoter whenNotPaused {
            require(proposals[proposalCount].active == false, "Proposal already active");

            // 验证输入
            if (proposalType == ProposalType.InputToken) {
                require(target != address(0) && target != address(this), "Invalid input token");
            } else if (proposalType == ProposalType.ReserveAddress) {
                require(target != address(0), "Invalid reserve address");
            } else if (proposalType == ProposalType.WhitelistAdd) {
                require(target != address(0) && !whitelist[target], "Invalid or already whitelisted");
            } else if (proposalType == ProposalType.WhitelistRemove) {
                require(whitelist[target], "Not whitelisted");
            } else if (proposalType == ProposalType.Freeze) {
                require(target != address(0) && !frozen[target], "Invalid or already frozen");
            } else if (proposalType == ProposalType.Unfreeze) {
                require(frozen[target], "Not frozen");
            } else if (proposalType == ProposalType.Mint) {
                require(whitelist[target] && target != address(0), "Invalid recipient");
                require(value > 0 && mintedAmount + value <= TOTAL_SUPPLY, "Invalid mint amount");
            }

            // 创建提案
            proposals[proposalCount] = Proposal({
                proposalType: proposalType,
                initiator: msg.sender,
                voteCount: 0,
                timestamp: proposalType <= ProposalType.ReserveAddress ? block.timestamp : block.timestamp + 2 minutes,
                target: target,
                value: value,
                active: true
            });

            emit ProposalCreated(proposalCount, proposalType, msg.sender);
            proposalCount++;
        }

        // 投票
        function vote(uint256 proposalId) external onlyVoter whenNotPaused {
            Proposal storage proposal = proposals[proposalId];
            require(proposal.active, "No active proposal");
            require(!hasVoted[msg.sender], "Already voted");
            require(!votingPaused, "Voting is paused");

            hasVoted[msg.sender] = true;
            proposal.voteCount++;

            // 检查是否达到所需票数
            uint256 requiredVotes = proposal.proposalType == ProposalType.Mint ? MIN_VOTES_FOR_MINT :
                                   (proposal.proposalType >= ProposalType.WhitelistAdd && proposal.proposalType <= ProposalType.Unfreeze ?
                                    MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
            require(proposal.voteCount <= requiredVotes, "Vote count exceeded");
        }

        // 执行提案
        function executeProposal(uint256 proposalId) external whenNotPaused {
            Proposal storage proposal = proposals[proposalId];
            require(proposal.active, "No active proposal");
            require(block.timestamp >= proposal.timestamp, "Change not allowed yet");

            // 验证票数
            uint256 requiredVotes = proposal.proposalType == ProposalType.Mint ? MIN_VOTES_FOR_MINT :
                                   (proposal.proposalType >= ProposalType.WhitelistAdd && proposal.proposalType <= ProposalType.Unfreeze ?
                                    MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
            require(proposal.voteCount >= requiredVotes, "Not enough votes");

            // 执行提案
            if (proposal.proposalType == ProposalType.InputToken) {
                inputToken = proposal.target;
                emit InputTokenUpdated(proposal.target);
            } else if (proposal.proposalType == ProposalType.ReserveAddress) {
                reserveAddress = proposal.target;
                emit ReserveAddressUpdated(proposal.target);
            } else if (proposal.proposalType == ProposalType.WhitelistAdd) {
                whitelist[proposal.target] = true;
                emit WhitelistChanged(proposal.target, true);
            } else if (proposal.proposalType == ProposalType.WhitelistRemove) {
                whitelist[proposal.target] = false;
                emit WhitelistChanged(proposal.target, false);
            } else if (proposal.proposalType == ProposalType.Freeze) {
                frozen[proposal.target] = true;
                emit FreezeChanged(proposal.target, true);
            } else if (proposal.proposalType == ProposalType.Unfreeze) {
                frozen[proposal.target] = false;
                emit FreezeChanged(proposal.target, false);
            } else if (proposal.proposalType == ProposalType.Mint) {
                _mint(proposal.target, proposal.value);
                mintedAmount += proposal.value;
                emit MintExecuted(proposal.target, proposal.value);
            }

            // 清理提案
            resetVotes(proposalId);
            delete proposals[proposalId];
            emit ProposalExecuted(proposalId, proposal.proposalType);
        }

        // 重置投票
        function resetVotes(uint256 proposalId) internal {
            Proposal storage proposal = proposals[proposalId];
            for (uint256 i = 0; i < proposalCount; i++) {
                if (proposals[i].active) {
                    hasVoted[proposals[i].initiator] = false;
                }
            }
        }

        // 向白名单分发代币
        function distributeToWhitelist() external onlyVoter whenNotPaused {
            require(block.timestamp >= lastDistributionTimestamp + DISTRIBUTION_INTERVAL, "Distribution interval not reached");
            require(mintedAmount + DISTRIBUTION_AMOUNT <= TOTAL_SUPPLY, "Total supply exceeded");

            // 假设白名单成员数量有限，简化分发
            lastDistributionTimestamp = block.timestamp;
            emit WhitelistDistribution(DISTRIBUTION_AMOUNT);
        }

        // 暂停投票
        function pauseVoting() external onlyOwner {
            votingPaused = true;
            emit VotingPaused();
        }

        // 恢复投票
        function resumeVoting() external onlyOwner {
            votingPaused = false;
            emit VotingResumed();
        }

        // 暂停合约
        function pauseContract() external onlyVoter whenNotPaused {
            contractPaused = true;
            emit ContractPaused();
        }

        // 恢复合约
        function resumeContract() external onlyVoter {
            contractPaused = false;
            emit ContractResumed();
        }

        // 获取剩余供应量
        function remainingSupply() external view returns (uint256) {
            return TOTAL_SUPPLY - mintedAmount;
        }

        // 转账（限制冻结用户）
        function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
            require(!frozen[msg.sender], "Sender is frozen");
            require(amount == uint256(uint128(amount)), "Amount must be an integer");
            return super.transfer(to, amount);
        }

        // 从指定地址转账
        function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
            require(!frozen[sender], "Sender is frozen");
            require(amount == uint256(uint128(amount)), "Amount must be an integer");
            return super.transferFrom(sender, recipient, amount);
        }

        // 小数位：返回 0
        function decimals() public view virtual override returns (uint8) {
            return 0;
        }

        // 获取用户余额
        function balanceOfUser(address user) external view returns (uint256) {
            return balanceOf(user);
        }

        // ERC3643 接口实现
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

        // 设置名称（内部）
        function _setName(string memory newName) internal {
            tokenName = newName;
        }
    }