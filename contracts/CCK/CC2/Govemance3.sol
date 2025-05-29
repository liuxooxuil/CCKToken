// SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;
/// ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x617F2E2fD72FD9D5503197092aC168c91465E7f2"]
    import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
    import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";
    import "contracts/CCK/ERC3643.sol";

    // CCKToken 合约，整合治理、自动分发、代币功能
    contract CCKToken is ERC20, Ownable, IERC3643 {
        // 总供应量，初始为 500,000 代币，精度为 18
        uint256 public TOTAL_SUPPLY = 500_000 * 10**18;
        // 白名单映射，记录允许接收代币的地址
        mapping(address => bool) public whitelist;
        // 白名单成员列表，方便遍历
        address[] public whitelistMembers;
        // 冻结状态映射
        mapping(address => bool) public frozen;
        // Uniswap V3 资金池地址
        address public uniswapPool;
        // 已铸造代币数量
        uint256 public mintedAmount;
        // 自定义代币名称
        string public tokenName;

        // 治理状态变量
        // 投票者列表
        address[] public voters;
        // 记录是否已投票
        mapping(address => bool) public hasVoted;
        // 当前投票数量
        uint256 public voteCount;
        // 五票治理（名称、总供应量、投票者）所需票数
        uint256 public constant TOTAL_VOTES_REQUIRED = 5;
        // 白名单和冻结投票所需票数
        uint256 public constant MIN_VOTES_FOR_USER_ACTIONS = 3;
        // 铸币所需票数
        uint256 public constant MIN_VOTES_FOR_MINT = 2;
        // 提案是否活跃
        bool public proposalActive;
        // 投票是否暂停
        bool public votingPaused;
        // 合约是否暂停
        bool public contractPaused;
        // 提案类型
        string public proposalType;
        // 提案发起人（五票治理）
        address public proposalInitiator;
        // 更改名称时间戳（2分钟延迟）
        uint256 public changeTimestamp;
        // 新提议名称
        string public newProposedName;
        // 总供应量调整量（正增负减）
        int64 public proposedAdjustmentAmount;
        // 总供应量调整时间戳
        uint256 public totalSupplyAdjustmentTimestamp;
        // 提议的旧投票者
        address[] public proposedOldVoters;
        // 提议的新投票者
        address[] public proposedNewVoters;
        // 投票者更改时间戳
        uint256 public votersChangeTimestamp;
        // 提议的白名单成员
        address public proposedWhitelistMember;
        // 白名单操作（add/remove）
        string public proposedWhitelistAction;
        // 提议的冻结用户
        address public proposedFreezeUser;
        // 冻结操作（freeze/unfreeze）
        string public proposedFreezeAction;
        // 提议的铸币接收者
        address public proposedMintRecipient;
        // 提议的铸币数量
        uint256 public proposedMintAmount;
        // 上次分发时间戳
        uint256 public lastDistributionTimestamp;
        // 分发间隔（5分钟）
        uint256 public constant DISTRIBUTION_INTERVAL = 300;
        // 每次分发数量（1代币）
        uint256 public constant DISTRIBUTION_AMOUNT = 1 * 10**18;

        // 事件
        event NameChanged(string newName);
        event NameProposalCreated(string newName, address initiator);
        event AdjustTotalSupplyProposalCreated(int64 amount, address initiator);
        event TotalSupplyAdjusted(uint256 newTotalSupply);
        event VotersChanged(address[] oldVoters, address[] newVoters);
        event VotersProposalCreated(address[] oldVoters, address[] newVoters, address initiator);
        event WhitelistProposalCreated(address member, string action);
        event WhitelistChanged(address member, string action);
        event FreezeProposalCreated(address user, string action);
        event FreezeChanged(address user, string action);
        event MintProposalCreated(address to, uint256 amount);
        event MintExecuted(address to, uint256 amount);
        event WhitelistDistribution(address[] recipients, uint256 amount);
        event ProposalCancelled(string proposalType, address initiator);
        event VotingPaused();
        event VotingResumed();
        event ContractPaused();
        event ContractResumed();

        // 修饰符
        modifier onlyVoter() {
            require(isVoter(msg.sender), "Not a voter");
            _;
        }

        modifier whenNotPaused() {
            require(!contractPaused, "Contract is paused");
            _;
        }

        // 构造函数
        constructor(
            string memory initialName,
            address[] memory _whitelist,
            address[] memory _voters,
            address _uniswapPool
        ) ERC20(initialName, "CCKToken") Ownable(msg.sender) {
            require(_whitelist.length > 0, "At least one whitelisted address required");
            require(_voters.length > 0, "At least one voter required");

            // 初始化白名单和成员列表
            for (uint256 i = 0; i < _whitelist.length; i++) {
                whitelist[_whitelist[i]] = true;
                whitelistMembers.push(_whitelist[i]);
            }

            voters = _voters;
            proposalActive = false;
            voteCount = 0;
            votingPaused = false;
            contractPaused = false;
            uniswapPool = _uniswapPool;
            tokenName = initialName;
            proposalType = "";
            lastDistributionTimestamp = block.timestamp;
        }

        // 重写 name()
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

        // 提出更改名称
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

        // 提出调整总供应量
        function proposeAdjustTotalSupply(int64 amount) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(amount != 0, "Adjustment amount must be non-zero");
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

        // 提出替换投票者
        function proposeNewVoters(address[] memory _oldVoters, address[] memory _newVoters) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(_oldVoters.length == _newVoters.length, "Old and new voters arrays must have same length");
            require(_oldVoters.length > 0, "At least one voter replacement required");

            for (uint256 i = 0; i < _oldVoters.length; i++) {
                require(isVoter(_oldVoters[i]), "Old voter not in voter list");
                require(_newVoters[i] != address(0), "New voter cannot be zero address");
                require(!isVoter(_newVoters[i]), "New voter already in voter list");
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

        // 提出添加白名单
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

        // 提出移除白名单
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

        // 提出冻结用户
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

        // 提出解冻用户
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

        // 提出铸币
        function proposeMint(address to, uint256 amount) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(whitelist[to], "Recipient not whitelisted");
            require(to != address(0), "Recipient cannot be zero address");
            require(amount > 0, "Amount must be greater than zero");
            require(mintedAmount + amount <= TOTAL_SUPPLY, "Total supply exceeded");

            resetVotes();
            voteCount = 0;
            proposedMintRecipient = to;
            proposedMintAmount = amount;
            proposalActive = true;
            proposalType = "mint";
            emit MintProposalCreated(to, amount);
        }

        // 重置投票
        function resetVotes() internal {
            for (uint256 i = 0; i < voters.length; i++) {
                hasVoted[voters[i]] = false;
            }
        }

        // 投票
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
            bool isMint = proposalTypeHash == keccak256(abi.encodePacked("mint"));
            uint256 requiredVotes = isMint ? MIN_VOTES_FOR_MINT : (isUserAction ? MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);

            if (voteCount >= requiredVotes) {
                if (proposalTypeHash == keccak256(abi.encodePacked("name"))) {
                    changeTimestamp = block.timestamp + 2 minutes;
                } else if (proposalTypeHash == keccak256(abi.encodePacked("adjustTotalSupply"))) {
                    totalSupplyAdjustmentTimestamp = block.timestamp + 2 minutes;
                } else if (proposalTypeHash == keccak256(abi.encodePacked("voters"))) {
                    votersChangeTimestamp = block.timestamp + 2 minutes;
                }
            }
        }

        // 取消提案（仅五票治理）
        function cancelProposal() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(msg.sender == proposalInitiator, "Only initiator can cancel");
            
            bytes32 proposalTypeHash = keccak256(abi.encodePacked(proposalType));
            require(proposalTypeHash == keccak256(abi.encodePacked("name")) ||
                    proposalTypeHash == keccak256(abi.encodePacked("adjustTotalSupply")) ||
                    proposalTypeHash == keccak256(abi.encodePacked("voters")), "Invalid proposal type for cancellation");

            require(voteCount >= TOTAL_VOTES_REQUIRED, "Proposal not yet approved");
            
            if (proposalTypeHash == keccak256(abi.encodePacked("name"))) {
                require(block.timestamp < changeTimestamp, "Cancellation window closed");
            } else if (proposalTypeHash == keccak256(abi.encodePacked("adjustTotalSupply"))) {
                require(block.timestamp < totalSupplyAdjustmentTimestamp, "Cancellation window closed");
            } else if (proposalTypeHash == keccak256(abi.encodePacked("voters"))) {
                require(block.timestamp < votersChangeTimestamp, "Cancellation window closed");
            }

            resetVotes();
            voteCount = 0;
            string memory cancelledType = proposalType;
            proposalActive = false;
            proposalType = "";
            proposalInitiator = address(0);

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

        // 更改名称
        function changeName() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("name")), "Invalid proposal type");
            require(block.timestamp >= changeTimestamp, "Change not allowed yet");
            require(voteCount >= TOTAL_VOTES_REQUIRED, "Not enough votes");

            _setName(newProposedName);
            proposalActive = false;
            proposalType = "";
            proposalInitiator = address(0);
            delete newProposedName;
            delete changeTimestamp;
            emit NameChanged(newProposedName);
        }

        // 调整总供应量
        function adjustTotalSupply() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("adjustTotalSupply")), "Invalid proposal type");
            require(block.timestamp >= totalSupplyAdjustmentTimestamp, "Change not allowed yet");
            require(voteCount >= TOTAL_VOTES_REQUIRED, "Not enough votes");

            TOTAL_SUPPLY = uint256(int256(TOTAL_SUPPLY) + proposedAdjustmentAmount);
            proposalActive = false;
            proposalType = "";
            proposalInitiator = address(0);
            delete proposedAdjustmentAmount;
            delete totalSupplyAdjustmentTimestamp;
            emit TotalSupplyAdjusted(TOTAL_SUPPLY);
        }

        // 替换投票者
        function changeVoters() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("voters")), "Invalid proposal type");
            require(block.timestamp >= votersChangeTimestamp, "Change not allowed yet");
            require(voteCount >= TOTAL_VOTES_REQUIRED, "Not enough votes");
            require(proposedOldVoters.length > 0, "No voter replacement proposed");

            for (uint256 i = 0; i < proposedOldVoters.length; i++) {
                require(isVoter(proposedOldVoters[i]), "Old voter not in voter list");
                require(proposedNewVoters[i] != address(0), "New voter cannot be zero address");
                require(!isVoter(proposedNewVoters[i]), "New voter already in voter list");
                for (uint256 j = i + 1; j < proposedNewVoters.length; j++) {
                    require(proposedNewVoters[i] != proposedNewVoters[j], "Duplicate new voters not allowed");
                }
            }

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

        // 添加白名单
        function changeWhitelistAdd() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("whitelist_add")), "Invalid proposal type");
            require(voteCount >= MIN_VOTES_FOR_USER_ACTIONS, "Not enough votes");
            require(proposedWhitelistMember != address(0), "Invalid member address");
            require(!whitelist[proposedWhitelistMember], "Member already whitelisted");

            whitelist[proposedWhitelistMember] = true;
            whitelistMembers.push(proposedWhitelistMember);
            proposalActive = false;
            proposalType = "";
            emit WhitelistChanged(proposedWhitelistMember, "add");
            delete proposedWhitelistMember;
            delete proposedWhitelistAction;
        }

        // 移除白名单
        function changeWhitelistRemove() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("whitelist_remove")), "Invalid proposal type");
            require(voteCount >= MIN_VOTES_FOR_USER_ACTIONS, "Not enough votes");
            require(proposedWhitelistMember != address(0), "Invalid member address");
            require(whitelist[proposedWhitelistMember], "Member not whitelisted");

            whitelist[proposedWhitelistMember] = false;
            for (uint256 i = 0; i < whitelistMembers.length; i++) {
                if (whitelistMembers[i] == proposedWhitelistMember) {
                    whitelistMembers[i] = whitelistMembers[whitelistMembers.length - 1];
                    whitelistMembers.pop();
                    break;
                }
            }

            proposalActive = false;
            proposalType = "";
            emit WhitelistChanged(proposedWhitelistMember, "remove");
            delete proposedWhitelistMember;
            delete proposedWhitelistAction;
        }

        // 冻结用户
        function changeFreezeUser() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("freeze")), "Invalid proposal type");
            require(voteCount >= MIN_VOTES_FOR_USER_ACTIONS, "Not enough votes");
            require(proposedFreezeUser != address(0), "Invalid user address");
            require(!frozen[proposedFreezeUser], "User already frozen");

            frozen[proposedFreezeUser] = true;
            proposalActive = false;
            proposalType = "";
            emit FreezeChanged(proposedFreezeUser, "freeze");
            delete proposedFreezeUser;
            delete proposedFreezeAction;
        }

        // 解冻用户
        function changeUnfreezeUser() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("unfreeze")), "Invalid proposal type");
            require(voteCount >= MIN_VOTES_FOR_USER_ACTIONS, "Not enough votes");
            require(proposedFreezeUser != address(0), "Invalid user address");
            require(frozen[proposedFreezeUser], "User not frozen");

            frozen[proposedFreezeUser] = false;
            proposalActive = false;
            proposalType = "";
            emit FreezeChanged(proposedFreezeUser, "unfreeze");
            delete proposedFreezeUser;
            delete proposedFreezeAction;
        }

        // 执行铸币
        function changeMint() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("mint")), "Invalid proposal type");
            require(voteCount >= MIN_VOTES_FOR_MINT, "Not enough votes");
            require(proposedMintRecipient != address(0), "Invalid recipient address");
            require(whitelist[proposedMintRecipient], "Recipient not whitelisted");

            _mint(proposedMintRecipient, proposedMintAmount);
            mintedAmount += proposedMintAmount;

            proposalActive = false;
            proposalType = "";
            emit MintExecuted(proposedMintRecipient, proposedMintAmount);
            delete proposedMintRecipient;
            delete proposedMintAmount;
        }

        // 白名单分发代币（由投票者直接触发或自动触发）
        function distributeToWhitelist() external onlyVoter whenNotPaused {
            require(block.timestamp >= lastDistributionTimestamp + DISTRIBUTION_INTERVAL, "Distribution interval not reached");
            require(whitelistMembers.length > 0, "No whitelist members");
            require(mintedAmount + (whitelistMembers.length * DISTRIBUTION_AMOUNT) <= TOTAL_SUPPLY, "Total supply exceeded");

            address[] memory recipients = new address[](whitelistMembers.length);
            for (uint256 i = 0; i < whitelistMembers.length; i++) {
                if (whitelist[whitelistMembers[i]]) {
                    _mint(whitelistMembers[i], DISTRIBUTION_AMOUNT);
                    mintedAmount += DISTRIBUTION_AMOUNT;
                    recipients[i] = whitelistMembers[i];
                }
            }

            lastDistributionTimestamp = block.timestamp;
            emit WhitelistDistribution(recipients, DISTRIBUTION_AMOUNT);
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
            require(voteCount < TOTAL_VOTES_REQUIRED, "Already enough votes to pause");
            resetVotes();
            voteCount = 0;
            contractPaused = true;
            emit ContractPaused();
        }

        // 恢复合约
        function resumeContract() external onlyVoter whenNotPaused {
            require(voteCount < TOTAL_VOTES_REQUIRED, "Already enough votes to resume");
            resetVotes();
            voteCount = 0;
            contractPaused = false;
            emit ContractResumed();
        }

        // 返回可铸造剩余代币
        function remainingSupply() external view returns (uint256) {
            return TOTAL_SUPPLY - mintedAmount;
        }

        // 重写转账
        function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
            require(!frozen[msg.sender], "Sender is frozen");
            require(amount == uint256(uint128(amount)), "Amount must be an integer");
            return super.transfer(to, amount);
        }

        // 重写授权转账
        function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
            require(!frozen[sender], "Sender is frozen");
            require(amount == uint256(uint128(amount)), "Amount must be an integer");
            return super.transferFrom(sender, recipient, amount);
        }

        // 获取Uniswap价格
        function getCurrentPrice() external view returns (uint256) {
            IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
            (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
            uint256 price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (2 ** 192);
            return price;
        }

        // 重写 decimals
        function decimals() public view virtual override returns (uint8) {
            return 0;
        }

        // 查看用户余额
        function balanceOfUser(address user) external view returns (uint256) {
            return balanceOf(user);
        }

        // ERC-3643 接口
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