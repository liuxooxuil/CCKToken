// SPDX-License-Identifier: MIT
    pragma solidity ^0.8.24;

    // 导入必要库
    import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol"; // Uniswap V3 池接口
    import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // ERC20 标准
    import "@openzeppelin/contracts/access/Ownable.sol"; // 所有权管理
    import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // 防止重入攻击
    import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // ERC20 接口
    import "contracts/CCK/ERC3643.sol"; // ERC3643 接口

    // CCKToken 合约：优化治理功能，复用方法，保留所有功能
    contract CCKToken is ERC20, Ownable, IERC3643, ReentrancyGuard {
        // 总供应量：500,000 代币，18 位小数
        uint256 public TOTAL_SUPPLY = 500_000 * 10**18;
        // 白名单映射：记录允许操作的地址
        mapping(address => bool) public whitelist;
        // 冻结状态：记录地址是否被冻结
        mapping(address => bool) public frozen;
        // Uniswap V3 池地址
        address public uniswapPool;
        // 已铸造数量：记录已发行代币
        uint256 public mintedAmount;
        // 代币名称：自定义名称
        string public tokenName;
        // 交换比率：1 输入 = 20 CCKToken
        uint256 public constant EXCHANGE_RATE = 20;

        // 治理相关
        mapping(address => bool) public voters; // 投票者映射
        mapping(address => bool) public hasVoted; // 是否已投票
        uint256 public constant TOTAL_VOTES_REQUIRED = 5; // 所需总票数
        uint256 public constant MIN_VOTES_FOR_USER_ACTIONS = 3; // 用户操作最小票数
        uint256 public constant MIN_VOTES_FOR_MINT = 2; // 铸造最小票数

        // 提案类型枚举
        enum ProposalType { Name, TotalSupply, Voters, WhitelistAdd, WhitelistRemove, Freeze, Unfreeze, Mint }
        // 提案结构体
        struct Proposal {
            ProposalType proposalType; // 提案类型
            address initiator; // 发起者
            uint256 voteCount; // 投票数
            uint256 timestamp; // 执行时间戳
            address target; // 目标地址
            uint256 value; // 数值（如铸造数量）
            string name; // 名称（名称变更）
            address[] oldVoters; // 旧投票者
            address[] newVoters; // 新投票者
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
        event ProposalCancelled(uint256 indexed proposalId, ProposalType proposalType);
        event NameChanged(string newName);
        event TotalSupplyAdjusted(uint256 newTotalSupply);
        event VotersChanged(address[] oldVoters, address[] newVoters);
        event WhitelistChanged(address member, bool added);
        event FreezeChanged(address user, bool frozen);
        event MintExecuted(address to, uint256 amount);
        event WhitelistDistribution(uint256 amount);
        event VotingPaused();
        event VotingResumed();
        event ContractPaused();
        event ContractResumed();
        event Exchange(address indexed user, uint256 inputAmount, uint256 cckAmount, address indexed targetAddress);

        // 修饰器：限制仅投票者
        modifier onlyVoter() {
            require(voters[msg.sender], ""); // 不是投票者
            _;
        }

        // 修饰器：限制合约未暂停
        modifier whenNotPaused() {
            require(!contractPaused, ""); // 合约已暂停
            _;
        }

        // 构造函数：初始化代币
        constructor(
            string memory initialName, // 初始名称
            address[] memory _whitelist, // 白名单
            address[] memory _voters // 投票者
        ) ERC20(initialName, "CC") Ownable(msg.sender) {
            require(_whitelist.length > 0, ""); // 至少需要一个白名单地址
            require(_voters.length > 0, "");// 至少需要一个投票者

            // 初始化白名单
            for (uint256 i = 0; i < _whitelist.length; i++) {
                require(_whitelist[i] != address(0), ""); // 无效白名单地址
                whitelist[_whitelist[i]] = true;
            }

            // 初始化投票者
            for (uint256 i = 0; i < _voters.length; i++) {
                require(_voters[i] != address(0), ""); // 无效投票者地址 
                voters[_voters[i]] = true;
            }

            tokenName = initialName;
            lastDistributionTimestamp = block.timestamp;
        }

        // 交换函数：为目标地址铸造 CCKToken
        function exchange(uint256 inputAmount, address targetAddress) external nonReentrant whenNotPaused {
            require(whitelist[targetAddress], ""); // 目标地址不在白名单
            require(inputAmount > 0, ""); // 输入数量需大于零

            uint256 cckAmount = inputAmount * EXCHANGE_RATE;
            require(cckAmount > 0, "CCK ");  // 数量过小
            require(mintedAmount + (cckAmount * 1e18) <= TOTAL_SUPPLY, ""); //超过总供应量

            _mint(targetAddress, cckAmount * 1e18);
            mintedAmount += cckAmount * 1e18;

            emit Exchange(msg.sender, inputAmount, cckAmount, targetAddress);
        }

        // 创建提案
        function propose(
            ProposalType proposalType, // 提案类型
            address target, // 目标地址
            uint256 value, // 数值
            string memory name, // 名称
            address[] memory oldVoters, // 旧投票者
            address[] memory newVoters // 新投票者
        ) external onlyVoter whenNotPaused {
            require(proposals[proposalCount].active == false, ""); // 已有活跃提案

            // 验证输入
            if (proposalType == ProposalType.Name) {
                require(bytes(name).length > 0, ""); // 名称不能为空
            } else if (proposalType == ProposalType.TotalSupply) {
                require(value != 0, ""); // 调整量不能为零
                require(int256(TOTAL_SUPPLY) + int256(value) >= int256(mintedAmount), ""); // 供应量不能低于已铸造量
                require(int256(TOTAL_SUPPLY) + int256(value) >= 0, ""); // 供应量不能为负
            } else if (proposalType == ProposalType.Voters) {
                require(oldVoters.length == newVoters.length && oldVoters.length > 0, ""); // 投票者数组无效
                for (uint256 i = 0; i < oldVoters.length; i++) {
                    require(voters[oldVoters[i]], ""); // 旧投票者无效
                    require(newVoters[i] != address(0) && !voters[newVoters[i]], ""); // 新投票者无效
                    for (uint256 j = i + 1; j < newVoters.length; j++) {
                        require(newVoters[i] != newVoters[j], ""); // 新投票者重复
                    }
                }
            } else if (proposalType == ProposalType.WhitelistAdd) {
                require(target != address(0) && !whitelist[target], ""); // 无效或已白名单
            } else if (proposalType == ProposalType.WhitelistRemove) {
                require(whitelist[target], ""); // 不在白名单
            } else if (proposalType == ProposalType.Freeze) {
                require(target != address(0) && !frozen[target], ""); // 无效或已冻结
            } else if (proposalType == ProposalType.Unfreeze) {
                require(frozen[target], ""); // 未冻结
            } else if (proposalType == ProposalType.Mint) {
                require(whitelist[target] && target != address(0), ""); // 无效接收者
                require(value > 0 && mintedAmount + value <= TOTAL_SUPPLY, ""); // 无效铸造数量
            }

            // 创建提案
            proposals[proposalCount] = Proposal({
                proposalType: proposalType,
                initiator: msg.sender,
                voteCount: 0,
                timestamp: proposalType <= ProposalType.Voters ? block.timestamp + 2 minutes : block.timestamp,
                target: target,
                value: value,
                name: name,
                oldVoters: oldVoters,
                newVoters: newVoters,
                active: true
            });

            resetVotes();
            emit ProposalCreated(proposalCount, proposalType, msg.sender);
            proposalCount++;
        }

        // 投票
        function vote(uint256 proposalId) external onlyVoter whenNotPaused {
            Proposal storage proposal = proposals[proposalId];
            require(proposal.active, ""); // 无活跃提案
            require(!hasVoted[msg.sender], ""); // 已投票
            require(!votingPaused, ""); // 投票已暂停

            hasVoted[msg.sender] = true;
            proposal.voteCount++;

            uint256 requiredVotes = proposal.proposalType == ProposalType.Mint ? MIN_VOTES_FOR_MINT :
                                   (proposal.proposalType >= ProposalType.WhitelistAdd && proposal.proposalType <= ProposalType.Unfreeze ?
                                    MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
            require(proposal.voteCount <= requiredVotes, ""); // 投票数超限
        }

        // 执行提案
        function executeProposal(uint256 proposalId) external whenNotPaused {
            Proposal storage proposal = proposals[proposalId];
            require(proposal.active, ""); // 无活跃提案
            require(block.timestamp >= proposal.timestamp, ""); // 无活跃提案

            uint256 requiredVotes = proposal.proposalType == ProposalType.Mint ? MIN_VOTES_FOR_MINT :
                                   (proposal.proposalType >= ProposalType.WhitelistAdd && proposal.proposalType <= ProposalType.Unfreeze ?
                                    MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
            require(proposal.voteCount >= requiredVotes, ""); // 票数不足

            if (proposal.proposalType == ProposalType.Name) {
                _setName(proposal.name);
                emit NameChanged(proposal.name);
            } else if (proposal.proposalType == ProposalType.TotalSupply) {
                TOTAL_SUPPLY = uint256(int256(TOTAL_SUPPLY) + int256(proposal.value));
                emit TotalSupplyAdjusted(TOTAL_SUPPLY);
            } else if (proposal.proposalType == ProposalType.Voters) {
                for (uint256 i = 0; i < proposal.oldVoters.length; i++) {
                    voters[proposal.oldVoters[i]] = false;
                    voters[proposal.newVoters[i]] = true;
                }
                emit VotersChanged(proposal.oldVoters, proposal.newVoters);
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

            resetVotes();
            delete proposals[proposalId];
            emit ProposalExecuted(proposalId, proposal.proposalType);
        }

        // 取消提案
        function cancelProposal(uint256 proposalId) external whenNotPaused {
            Proposal storage proposal = proposals[proposalId];
            require(proposal.active, ""); // 无活跃提案
            require(msg.sender == proposal.initiator, ""); // 仅发起者可取消
            require(proposal.proposalType <= ProposalType.Voters, ""); // 仅可取消名称、供应量或投票者提案
            require(proposal.voteCount >= TOTAL_VOTES_REQUIRED, ""); // 提案未获批
            require(block.timestamp < proposal.timestamp, ""); // 取消窗口已关闭

            resetVotes();
            ProposalType cancelledType = proposal.proposalType;
            delete proposals[proposalId];
            emit ProposalCancelled(proposalId, cancelledType);
        }

        // 重置投票
        function resetVotes() internal {
            for (uint256 i = 0; i < proposalCount; i++) {
                if (proposals[i].active) {
                    hasVoted[proposals[i].initiator] = false;
                }
            }
        }

        // 获取当前价格
        function getCurrentPrice() public view returns (uint256 price) {
            IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (2**192); // 计算价格
        }

        // 向白名单分发代币
        function distributeToWhitelist() external onlyVoter whenNotPaused {
            require(block.timestamp >= lastDistributionTimestamp + DISTRIBUTION_INTERVAL, ""); // 未到分发间隔
            require(mintedAmount + DISTRIBUTION_AMOUNT <= TOTAL_SUPPLY, ""); // 超过总供应量

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

        // 转账
        function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
            require(!frozen[msg.sender], ""); // 发送者被冻结
            require(amount == uint256(uint128(amount)), ""); // 数量必须为整数
            return super.transfer(to, amount);
        }

        // 从指定地址转账
        function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
            require(!frozen[sender], ""); // 发送者被冻结
            require(amount == uint256(uint128(amount)), ""); // 发送者被冻结
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

        // 设置名称
        function _setName(string memory newName) internal {
            tokenName = newName;
        }
    }