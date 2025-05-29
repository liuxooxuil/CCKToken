// SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
    import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";
    import "contracts/CCK/ERC3643.sol";

    // CCKToken 合约，继承 ERC20、Ownable 和 IERC3643，整合治理功能
    contract CCKToken is ERC20, Ownable, IERC3643 {
        // 总供应量，初始为 500,000 代币，精度为 18，可通过治理调整
        uint256 public TOTAL_SUPPLY = 500_000 * 10**18;
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
        // 提案通过所需的总票数（名称、总供应量调整、投票者），默认为 5
        uint256 public totalVotesRequired = 5;
        // 白名单和冻结操作所需的最低票数，默认为 3
        uint256 public minVotesForUserActions = 3;
        // 铸币操作所需的最低票数，默认为 2
        uint256 public minVotesForMint = 2;
        // 当前是否有一个活跃的提案
        bool public proposalActive;
        // 投票是否暂停
        bool public votingPaused;
        // 合约是否暂停
        bool public contractPaused;
        // 当前提案类型：name、adjustTotalSupply、voters、whitelist_add、whitelist_remove、freeze、unfreeze、mint
        string public proposalType;
        // 提案发起人地址（仅用于名称、总供应量调整、投票者提案）
        address public proposalInitiator;
        // 更改名称的时间戳（需等待 2 分钟）
        uint256 public changeTimestamp;
        // 新提议的代币名称
        string public newProposedName;
        // 提议的总供应量调整量（正数增加，负数减少）
        int64 public proposedAdjustmentAmount;
        // 调整总供应量的时间戳
        uint256 public totalSupplyAdjustmentTimestamp;
        // 提议替换的旧投票者地址列表
        address[] public proposedOldVoters;
        // 提议替换的新投票者地址列表
        address[] public proposedNewVoters;
        // 更改投票者时间戳
        uint256 public votersChangeTimestamp;
        // 提议的白名单成员地址
        address public proposedWhitelistMember;
        // 提议的白名单操作（add 或 remove）
        string public proposedWhitelistAction;
        // 提议的冻结用户地址
        address public proposedFreezeUser;
        // 提议的冻结操作（freeze 或 unfreeze）
        string public proposedFreezeAction;
        // 提议的铸币接收者地址
        address public proposedMintRecipient;
        // 提议的铸币数量
        uint256 public proposedMintAmount;

        // 事件
        // 代币名称更改事件
        event NameChanged(string newName);
        // 提案创建事件（更改名称）
        event NameProposalCreated(string newName, address initiator);
        // 总供应量调整事件
        event TotalSupplyAdjusted(uint256 newTotalSupply);
        // 提案创建事件（调整总供应量）
        event AdjustTotalSupplyProposalCreated(int64 amount, address initiator);
        // 投票者替换事件
        event VotersChanged(address[] oldVoters, address[] newVoters);
        // 提案创建事件（替换投票者）
        event VotersProposalCreated(address[] oldVoters, address[] newVoters, address initiator);
        // 白名单操作提案创建事件
        event WhitelistProposalCreated(address member, string action);
        // 白名单操作更改事件
        event WhitelistChanged(address member, string action);
        // 冻结操作提案创建事件
        event FreezeProposalCreated(address user, string action);
        // 冻结操作更改事件
        event FreezeChanged(address user, string action);
        // 铸币提案创建事件
        event MintProposalCreated(address to, uint256 amount);
        // 铸币执行事件
        event MintExecuted(address to, uint256 amount);
        // 提案取消事件（仅限名称、总供应量调整、投票者）
        event ProposalCancelled(string proposalType, address initiator);
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
            proposalType = ""; // 初始化提案类型
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

        // 提出新的代币名称提案，仅限投票者
        function proposeNewName(string memory newName) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            resetVotes();
            voteCount = 0;
            newProposedName = newName;
            proposalActive = true;
            proposalType = "name";
            proposalInitiator = msg.sender;
            emit NameProposalCreated(newName, msg.sender);
        }

        // 提出调整总供应量的提案，仅限投票者
        function proposeAdjustTotalSupply(int64 amount) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(amount != 0, "Adjustment amount must be non-zero");
            // 验证调整后总供应量不低于已铸造量
            require(int256(TOTAL_SUPPLY) + amount >= int256(mintedAmount), "Total supply cannot be less than minted amount");
            require(int256(TOTAL_SUPPLY) + amount >= 0, "Total supply cannot be negative");

            resetVotes();
            voteCount = 0;
            proposedAdjustmentAmount = amount;
            proposalActive = true;
            proposalType = "adjustTotalSupply";
            proposalInitiator = msg.sender;
            emit AdjustTotalSupplyProposalCreated(amount, msg.sender);
        }

        // 提出替换投票者的提案，仅限投票者
        function proposeNewVoters(address[] memory _oldVoters, address[] memory _newVoters) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(_oldVoters.length == _newVoters.length, "Old and new voters arrays must have same length");
            require(_oldVoters.length > 0, "At least one voter replacement required");

            // 验证旧投票者存在，新投票者不重复且有效
            for (uint256 i = 0; i < _oldVoters.length; i++) {
                require(isVoter(_oldVoters[i]), "Old voter not in voter list");
                require(_newVoters[i] != address(0), "New voter cannot be zero address");
                require(!isVoter(_newVoters[i]), "New voter already in voter list");
                // 检查新投票者数组内部无重复
                for (uint256 j = i + 1; j < _newVoters.length; j++) {
                    require(_newVoters[i] != _newVoters[j], "Duplicate new voters not allowed");
                }
            }

            resetVotes();
            voteCount = 0;
            proposedOldVoters = _oldVoters;
            proposedNewVoters = _newVoters;
            proposalActive = true;
            proposalType = "voters";
            proposalInitiator = msg.sender;
            emit VotersProposalCreated(_oldVoters, _newVoters, msg.sender);
        }

        // 提出添加白名单成员的提案，仅限投票者
        function proposeAddToWhitelist(address member) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(member != address(0), "Member cannot be zero address");
            require(!whitelist[member], "Member already whitelisted");
            resetVotes();
            voteCount = 0;
            proposedWhitelistMember = member;
            proposedWhitelistAction = "add";
            proposalActive = true;
            proposalType = "whitelist_add";
            emit WhitelistProposalCreated(member, "add");
        }

        // 提出移除白名单成员的提案，仅限投票者
        function proposeRemoveFromWhitelist(address member) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(whitelist[member], "Member not whitelisted");
            resetVotes();
            voteCount = 0;
            proposedWhitelistMember = member;
            proposedWhitelistAction = "remove";
            proposalActive = true;
            proposalType = "whitelist_remove";
            emit WhitelistProposalCreated(member, "remove");
        }

        // 提出冻结用户的提案，仅限投票者
        function proposeFreezeUser(address user) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(user != address(0), "User cannot be zero address");
            require(!frozen[user], "User already frozen");
            resetVotes();
            voteCount = 0;
            proposedFreezeUser = user;
            proposedFreezeAction = "freeze";
            proposalActive = true;
            proposalType = "freeze";
            emit FreezeProposalCreated(user, "freeze");
        }

        // 提出解冻用户的提案，仅限投票者
        function proposeUnfreezeUser(address user) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(frozen[user], "User not frozen");
            resetVotes();
            voteCount = 0;
            proposedFreezeUser = user;
            proposedFreezeAction = "unfreeze";
            proposalActive = true;
            proposalType = "unfreeze";
            emit FreezeProposalCreated(user, "unfreeze");
        }

        // 提出铸造代币的提案，仅限投票者
        function proposeMint(address to, uint256 amount) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(whitelist[to], "Recipient not whitelisted");
            require(mintedAmount + amount <= TOTAL_SUPPLY, "Total supply exceeded");
            require(to != address(0), "Recipient cannot be zero address");
            require(amount > 0, "Amount must be greater than zero");

            resetVotes();
            voteCount = 0;
            proposedMintRecipient = to;
            proposedMintAmount = amount;
            proposalActive = true;
            proposalType = "mint";
            emit MintProposalCreated(to, amount);
        }

        // 内部函数：重置投票记录
        function resetVotes() internal {
            // 重置当前投票者列表的投票状态
            for (uint256 i = 0; i < voters.length; i++) {
                hasVoted[voters[i]] = false;
            }
        }

        // 投票函数，仅限投票者
        function vote() external onlyVoter whenNotPaused {
            require(proposalActive, "No active proposal");
            require(!hasVoted[msg.sender], "Already voted");
            require(!votingPaused, "Voting is paused");

            hasVoted[msg.sender] = true;
            voteCount++;

            bytes32 proposalTypeHash = keccak256(abi.encodePacked(proposalType));
            bool isUserAction = proposalTypeHash == keccak256(abi.encodePacked("whitelist_add")) ||
                               proposalTypeHash == keccak256(abi.encodePacked("whitelist_remove")) ||
                               proposalTypeHash == keccak256(abi.encodePacked("freeze")) ||
                               proposalTypeHash == keccak256(abi.encodePacked("unfreeze"));
            bool isMintAction = proposalTypeHash == keccak256(abi.encodePacked("mint"));
            uint256 requiredVotes = isMintAction ? minVotesForMint : (isUserAction ? minVotesForUserActions : totalVotesRequired);

            // 仅名称、总供应量调整、投票者替换需延迟
            if (voteCount >= requiredVotes) {
                if (proposalTypeHash == keccak256(abi.encodePacked("name"))) {
                    changeTimestamp = block.timestamp + 2 minutes;
                } else if (proposalTypeHash == keccak256(abi.encodePacked("adjustTotalSupply"))) {
                    totalSupplyAdjustmentTimestamp = block.timestamp + 2 minutes;
                } else if (proposalTypeHash == keccak256(abi.encodePacked("voters"))) {
                    votersChangeTimestamp = block.timestamp + 2 minutes;
                }
                // 白名单、冻结、铸币无需延迟，直接可执行
            }
        }

        // 取消提案，仅限提案发起人，仅限名称、总供应量调整、投票者提案
        function cancelProposal() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(msg.sender == proposalInitiator, "Only initiator can cancel");
            
            bytes32 proposalTypeHash = keccak256(abi.encodePacked(proposalType));
            require(proposalTypeHash == keccak256(abi.encodePacked("name")) ||
                    proposalTypeHash == keccak256(abi.encodePacked("adjustTotalSupply")) ||
                    proposalTypeHash == keccak256(abi.encodePacked("voters")), "Invalid proposal type for cancellation");

            require(voteCount >= totalVotesRequired, "Proposal not yet approved");
            
            // 检查是否在 2 分钟等待时间内
            if (proposalTypeHash == keccak256(abi.encodePacked("name"))) {
                require(block.timestamp < changeTimestamp, "Cancellation window closed");
            } else if (proposalTypeHash == keccak256(abi.encodePacked("adjustTotalSupply"))) {
                require(block.timestamp < totalSupplyAdjustmentTimestamp, "Cancellation window closed");
            } else if (proposalTypeHash == keccak256(abi.encodePacked("voters"))) {
                require(block.timestamp < votersChangeTimestamp, "Cancellation window closed");
            }

            // 重置提案状态
            resetVotes();
            voteCount = 0;
            string memory cancelledType = proposalType;
            proposalActive = false;
            proposalType = "";
            proposalInitiator = address(0);

            // 清空提案相关数据
            if (proposalTypeHash == keccak256(abi.encodePacked("name"))) {
                delete newProposedName;
                delete changeTimestamp;
            } else if (proposalTypeHash == keccak256(abi.encodePacked("adjustTotalSupply"))) {
                delete proposedAdjustmentAmount;
                delete totalSupplyAdjustmentTimestamp;
            } else if (proposalTypeHash == keccak256(abi.encodePacked("voters"))) {
                delete proposedOldVoters;
                delete proposedNewVoters;
                delete votersChangeTimestamp;
            }

            emit ProposalCancelled(cancelledType, msg.sender);
        }

        // 更改代币名称，需满足投票和时间要求
        function changeName() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("name")), "Invalid proposal type");
            require(block.timestamp >= changeTimestamp, "Change not allowed yet");
            require(voteCount >= totalVotesRequired, "Not enough votes");

            _setName(newProposedName);
            proposalActive = false;
            proposalType = "";
            proposalInitiator = address(0);
            delete newProposedName;
            delete changeTimestamp;
            emit NameChanged(newProposedName);
        }

        // 调整总供应量，需满足投票和时间要求
        function adjustTotalSupply() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("adjustTotalSupply")), "Invalid proposal type");
            require(block.timestamp >= totalSupplyAdjustmentTimestamp, "Change not allowed yet");
            require(voteCount >= totalVotesRequired, "Not enough votes");

            // 调整总供应量
            TOTAL_SUPPLY = uint256(int256(TOTAL_SUPPLY) + proposedAdjustmentAmount);

            proposalActive = false;
            proposalType = "";
            proposalInitiator = address(0);
            delete proposedAdjustmentAmount;
            delete totalSupplyAdjustmentTimestamp;
            emit TotalSupplyAdjusted(TOTAL_SUPPLY);
        }

        // 替换投票者，需满足投票和时间要求
        function changeVoters() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("voters")), "Invalid proposal type");
            require(block.timestamp >= votersChangeTimestamp, "Change not allowed yet");
            require(voteCount >= totalVotesRequired, "Not enough votes");
            require(proposedOldVoters.length > 0, "No voter replacement proposed");

            // 验证旧投票者存在，新投票者不重复且有效
            for (uint256 i = 0; i < proposedOldVoters.length; i++) {
                require(isVoter(proposedOldVoters[i]), "Old voter not in voter list");
                require(proposedNewVoters[i] != address(0), "New voter cannot be zero address");
                require(!isVoter(proposedNewVoters[i]), "New voter already in voter list");
                for (uint256 j = i + 1; j < proposedNewVoters.length; j++) {
                    require(proposedNewVoters[i] != proposedNewVoters[j], "Duplicate new voters not allowed");
                }
            }

            // 替换投票者
            for (uint256 i = 0; i < proposedOldVoters.length; i++) {
                for (uint256 j = 0; j < voters.length; j++) {
                    if (voters[j] == proposedOldVoters[i]) {
                        voters[j] = proposedNewVoters[i];
                        break;
                    }
                }
            }

            proposalActive = false;
            proposalType = "";
            proposalInitiator = address(0);
            emit VotersChanged(proposedOldVoters, proposedNewVoters);
            delete proposedOldVoters;
            delete proposedNewVoters;
            delete votersChangeTimestamp;
        }

        // 添加白名单成员，需满足投票要求，无需延迟
        function changeWhitelistAdd() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("whitelist_add")), "Invalid proposal type");
            require(voteCount >= minVotesForUserActions, "Not enough votes");
            require(proposedWhitelistMember != address(0), "Invalid member address");
            require(!whitelist[proposedWhitelistMember], "Member already whitelisted");

            whitelist[proposedWhitelistMember] = true;
            proposalActive = false;
            proposalType = "";
            emit WhitelistChanged(proposedWhitelistMember, "add");
            delete proposedWhitelistMember;
            delete proposedWhitelistAction;
        }

        // 移除白名单成员，需满足投票要求，无需延迟
        function changeWhitelistRemove() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("whitelist_remove")), "Invalid proposal type");
            require(voteCount >= minVotesForUserActions, "Not enough votes");
            require(proposedWhitelistMember != address(0), "Invalid member address");
            require(whitelist[proposedWhitelistMember], "Member not whitelisted");

            whitelist[proposedWhitelistMember] = false;
            proposalActive = false;
            proposalType = "";
            emit WhitelistChanged(proposedWhitelistMember, "remove");
            delete proposedWhitelistMember;
            delete proposedWhitelistAction;
        }

        // 冻结用户，需满足投票要求，无需延迟
        function changeFreezeUser() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("freeze")), "Invalid proposal type");
            require(voteCount >= minVotesForUserActions, "Not enough votes");
            require(proposedFreezeUser != address(0), "Invalid user address");
            require(!frozen[proposedFreezeUser], "User already frozen");

            frozen[proposedFreezeUser] = true;
            proposalActive = false;
            proposalType = "";
            emit FreezeChanged(proposedFreezeUser, "freeze");
            delete proposedFreezeUser;
            delete proposedFreezeAction;
        }

        // 解冻用户，需满足投票要求，无需延迟
        function changeUnfreezeUser() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("unfreeze")), "Invalid proposal type");
            require(voteCount >= minVotesForUserActions, "Not enough votes");
            require(proposedFreezeUser != address(0), "Invalid user address");
            require(frozen[proposedFreezeUser], "User not frozen");

            frozen[proposedFreezeUser] = false;
            proposalActive = false;
            proposalType = "";
            emit FreezeChanged(proposedFreezeUser, "unfreeze");
            delete proposedFreezeUser;
            delete proposedFreezeAction;
        }

        // 执行铸造代币，需满足投票要求，无需延迟
        function changeMint() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("mint")), "Invalid proposal type");
            require(voteCount >= minVotesForMint, "Not enough votes");
            require(proposedMintRecipient != address(0), "Invalid recipient address");
            require(whitelist[proposedMintRecipient], "Recipient not whitelisted");
            require(mintedAmount + proposedMintAmount <= TOTAL_SUPPLY, "Total supply exceeded");

            _mint(proposedMintRecipient, proposedMintAmount);
            mintedAmount += proposedMintAmount;

            proposalActive = false;
            proposalType = "";
            emit MintExecuted(proposedMintRecipient, proposedMintAmount);
            delete proposedMintRecipient;
            delete proposedMintAmount;
        }

        // 暂停投票，仅限合约管理员
        function pauseVoting() external onlyOwner {
            votingPaused = true;
            emit VotingPaused();
        }

        // 恢复投票，仅限合约管理员
        function resumeVoting() external onlyOwner {
            votingPaused = false;
            emit VotingResumed();
        }

        // 暂停合约，仅限投票者
        function pauseContract() external onlyVoter whenNotPaused {
            require(voteCount < totalVotesRequired, "Already enough votes to pause");
            resetVotes();
            voteCount = 0;
            contractPaused = true;
            emit ContractPaused();
        }

        // 恢复合约，仅限投票者
        function resumeContract() external onlyVoter whenNotPaused {
            require(voteCount < totalVotesRequired, "Already enough votes to resume");
            resetVotes();
            voteCount = 0;
            contractPaused = false;
            emit ContractResumed();
        }

        // 返回可铸造的剩余代币数量
        function remainingSupply() external view returns (uint256) {
            return TOTAL_SUPPLY - mintedAmount;
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

        // 返回身份注册合约地址（暂未实现）
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