// SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    // 导入必要的外部合约接口和库
    import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol"; // Uniswap V3 池接口
    import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // ERC20 代币标准
    import "@openzeppelin/contracts/access/Ownable.sol"; // 所有权管理
    import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // 防止重入攻击
    import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // ERC20 接口
    import "contracts/CCK/ERC3643.sol"; // 自定义 ERC3643 接口

    // CCKToken 合约，继承 ERC20、Ownable、IERC3643 和 ReentrancyGuard
    contract CCKToken is ERC20, Ownable, IERC3643, ReentrancyGuard {
        // 总供应量：500,000 代币，内部使用 18 位小数
        uint256 public TOTAL_SUPPLY = 500_000 * 10**18;
        // 白名单映射：记录允许操作的地址
        mapping(address => bool) public whitelist;
        // 白名单成员数组：存储所有白名单地址
        address[] public whitelistMembers;
        // 冻结状态：记录地址是否被冻结
        mapping(address => bool) public frozen;
        // Uniswap V3 池地址（Sepolia 测试网）
        address public uniswapPool;
        // 已铸造数量：记录已发行的代币总量
        uint256 public mintedAmount;
        // 代币名称：自定义代币名称
        string public tokenName;
        // 输入代币地址：用于交换的测试网 ERC20 代币（如 USDT）
        address public inputToken;
        // 储备地址：存储输入代币的地址
        address public reserveAddress;
        // 交换比率：1 输入代币 = 20 CCKToken
        uint256 public constant EXCHANGE_RATE = 20;

        // 治理相关状态变量
        address[] public voters; // 投票者列表
        mapping(address => bool) public hasVoted; // 记录是否已投票
        uint256 public voteCount; // 当前投票数
        uint256 public constant TOTAL_VOTES_REQUIRED = 5; // 所需总票数
        uint256 public constant MIN_VOTES_FOR_USER_ACTIONS = 3; // 用户操作所需最小票数
        uint256 public constant MIN_VOTES_FOR_MINT = 2; // 铸造代币所需最小票数
        bool public proposalActive; // 是否有活跃提案
        bool public votingPaused; // 投票是否暂停
        bool public contractPaused; // 合约是否暂停
        string public proposalType; // 提案类型
        address public proposalInitiator; // 提案发起者
        uint256 public changeTimestamp; // 名称变更时间戳
        string public newProposedName; // 提议的新名称
        int64 public proposedAdjustmentAmount; // 提议的供应量调整
        uint256 public totalSupplyAdjustmentTimestamp; // 供应量调整时间戳
        address[] public proposedOldVoters; // 提议替换的旧投票者
        address[] public proposedNewVoters; // 提议的新投票者
        uint256 public votersChangeTimestamp; // 投票者变更时间戳
        address public proposedWhitelistMember; // 提议的白名单成员
        string public proposedWhitelistAction; // 白名单操作（添加/移除）
        address public proposedFreezeUser; // 提议冻结的用户
        string public proposedFreezeAction; // 冻结操作（冻结/解冻）
        address public proposedMintRecipient; // 提议铸造的接收者
        uint256 public proposedMintAmount; // 提议铸造的数量
        uint256 public lastDistributionTimestamp; // 上次分发时间戳
        uint256 public constant DISTRIBUTION_INTERVAL = 300; // 分发间隔（秒）
        uint256 public constant DISTRIBUTION_AMOUNT = 1 * 10**18; // 每次分发数量
        // 输入代币和储备地址的提案变量
        address public proposedInputToken; // 提议的新输入代币
        address public proposedReserveAddress; // 提议的新储备地址

        // 事件定义
        event NameChanged(string newName); // 名称变更
        event NameProposalCreated(string newName, address initiator); // 名称提案创建
        event AdjustTotalSupplyProposalCreated(int64 amount, address initiator); // 供应量调整提案
        event TotalSupplyAdjusted(uint256 newTotalSupply); // 供应量调整完成
        event VotersChanged(address[] oldVoters, address[] newVoters); // 投票者变更
        event VotersProposalCreated(address[] oldVoters, address[] newVoters, address initiator); // 投票者提案
        event WhitelistProposalCreated(address member, string action); // 白名单提案
        event WhitelistChanged(address member, string action); // 白名单变更
        event FreezeProposalCreated(address user, string action); // 冻结提案
        event FreezeChanged(address user, string action); // 冻结状态变更
        event MintProposalCreated(address to, uint256 amount); // 铸造提案
        event MintExecuted(address to, uint256 amount); // 铸造执行
        event WhitelistDistribution(address[] recipients, uint256 amount); // 白名单分发
        event ProposalCancelled(string proposalType, address initiator); // 提案取消
        event VotingPaused(); // 投票暂停
        event VotingResumed(); // 投票恢复
        event ContractPaused(); // 合约暂停
        event ContractResumed(); // 合约恢复
        event Exchange(address indexed user, uint256 inputAmount, uint256 cckAmount); // 代币交换
        event InputTokenUpdated(address newInputToken); // 输入代币更新
        event ReserveAddressUpdated(address newReserveAddress); // 储备地址更新
        event InputTokenProposalCreated(address newInputToken, address initiator); // 输入代币提案
        event ReserveAddressProposalCreated(address newReserveAddress, address initiator); // 储备地址提案
        event Debug(string message, uint256 value); // 调试事件

        // 修饰器：限制仅投票者可调用
        modifier onlyVoter() {
            require(isVoter(msg.sender), "Not a voter");
            _;
        }

        // 修饰器：限制合约未暂停时可调用
        modifier whenNotPaused() {
            require(!contractPaused, "Contract is paused");
            _;
        }

        // 构造函数：初始化代币参数
        constructor(
            string memory initialName, // 初始代币名称
            address[] memory _whitelist, // 初始白名单
            address[] memory _voters, // 初始投票者
            address _inputToken, // 输入代币地址
            address _reserveAddress // 储备地址
        ) ERC20(initialName, "CCKToken") Ownable(msg.sender) {
            require(_whitelist.length > 0, "At least one whitelisted address required");
            require(_voters.length > 0, "At least one voter required");
            require(_inputToken != address(0) && _inputToken != address(this), "Invalid input token address");
            require(_reserveAddress != address(0), "Invalid reserve address");

            emit Debug("Initializing whitelist", _whitelist.length);
            for (uint256 i = 0; i < _whitelist.length; i++) {
                require(_whitelist[i] != address(0), "Invalid whitelist address");
                whitelist[_whitelist[i]] = true;
                whitelistMembers.push(_whitelist[i]);
            }

            emit Debug("Initializing voters", _voters.length);
            for (uint256 i = 0; i < _voters.length; i++) {
                require(_voters[i] != address(0), "Invalid voter address");
            }
            voters = _voters;

            proposalActive = false;
            voteCount = 0;
            votingPaused = false;
            contractPaused = false;
            tokenName = initialName;
            proposalType = "";
            lastDistributionTimestamp = block.timestamp;
            inputToken = _inputToken;
            reserveAddress = _reserveAddress;
            emit Debug("Constructor completed", 0);
        }

        // 交换函数：将输入代币兑换为 CCKToken
        function exchange(uint256 inputAmount) external nonReentrant whenNotPaused {
            require(whitelist[msg.sender], "Sender not whitelisted");
            require(inputAmount > 0, "Input amount must be greater than zero");
            require(inputToken != address(this), "Input token cannot be CCKToken");

            // 获取输入代币小数位，失败则默认 18
            uint8 inputDecimals = 18;
            try IERC20Metadata(inputToken).decimals() returns (uint8 decimals) {
                inputDecimals = decimals;
            } catch {
                emit Debug("Failed to get decimals, using default", inputDecimals);
            }

            // 计算 CCKToken 数量（1:20 比率）
            uint256 cckAmount = (inputAmount * EXCHANGE_RATE) / (10 ** inputDecimals);
            require(cckAmount > 0, "CCK amount too small");
            require(mintedAmount + (cckAmount * 1e18) <= TOTAL_SUPPLY, "Total supply exceeded");

            // 转移输入代币到合约
            bool success = IERC20(inputToken).transferFrom(msg.sender, address(this), inputAmount);
            require(success, "Input token transfer failed");

            // 转移输入代币到储备地址
            success = IERC20(inputToken).transfer(reserveAddress, inputAmount);
            require(success, "Reserve transfer failed");

            // 直接铸造 CCKToken
            _mint(msg.sender, cckAmount * 1e18);
            mintedAmount += cckAmount * 1e18;

            emit Exchange(msg.sender, inputAmount, cckAmount);
        }

        // 提议新输入代币
        function proposeNewInputToken(address newInputToken) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(newInputToken != address(0) && newInputToken != address(this), "Invalid input token address");
            resetVotes();
            voteCount = 0;
            proposedInputToken = newInputToken;
            proposalActive = true;
            proposalType = "input_token";
            proposalInitiator = msg.sender;
            emit InputTokenProposalCreated(newInputToken, msg.sender);
        }

        // 提议新储备地址
        function proposeNewReserveAddress(address newReserveAddress) external onlyVoter whenNotPaused {
            require(!proposalActive, "Proposal already active");
            require(newReserveAddress != address(0), "Invalid reserve address");
            resetVotes();
            voteCount = 0;
            proposedReserveAddress = newReserveAddress;
            proposalActive = true;
            proposalType = "reserve_address";
            proposalInitiator = msg.sender;
            emit ReserveAddressProposalCreated(newReserveAddress, msg.sender);
        }

        // 执行输入代币变更
        function changeInputToken() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("input_token")), "Invalid proposal type");
            require(voteCount >= TOTAL_VOTES_REQUIRED, "Not enough votes");
            require(proposedInputToken != address(0), "Invalid input token address");

            inputToken = proposedInputToken;
            proposalActive = false;
            proposalType = "";
            proposalInitiator = address(0);
            emit InputTokenUpdated(proposedInputToken);
            delete proposedInputToken;
        }

        // 执行储备地址变更
        function changeReserveAddress() external whenNotPaused {
            require(proposalActive, "No active proposal");
            require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("reserve_address")), "Invalid proposal type");
            require(voteCount >= TOTAL_VOTES_REQUIRED, "Not enough votes");
            require(proposedReserveAddress != address(0), "Invalid reserve address");

            reserveAddress = proposedReserveAddress;
            proposalActive = false;
            proposalType = "";
            proposalInitiator = address(0);
            emit ReserveAddressUpdated(proposedReserveAddress);
            delete proposedReserveAddress;
        }

        // 投票函数
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
            bool isConfig = proposalTypeHash == keccak256(abi.encodePacked("input_token")) ||
                            proposalTypeHash == keccak256(abi.encodePacked("reserve_address"));
            uint256 requiredVotes = isMint ? MIN_VOTES_FOR_MINT : 
                                   (isUserAction ? MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);

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

        // 重置投票状态
        function resetVotes() internal {
            for (uint256 i = 0; i < voters.length; i++) {
                hasVoted[voters[i]] = false;
            }
        }

        // 获取当前价格（Uniswap V3 池）
        function getCurrentPrice() external view returns (uint256) {
            IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            // 价格计算：sqrtPriceX96 转换为价格
            uint256 price = uint256(sqrtPriceX96) ** 2 / (2 ** (192));
            return price;
        }

        // 获取代币名称
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

        // 提议新名称
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

        // 提议调整总供应量
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

        // 提议替换投票者
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

        // 提议添加白名单成员
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

        // 提议移除白名单成员
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

        // 提议冻结用户
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

        // 提议解冻用户
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

        // 提议铸造代币
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

        // 取消提案
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

        // 执行名称变更
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

        // 执行供应量调整
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

        // 执行投票者变更
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

        // 执行添加白名单
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

        // 执行移除白名单
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

        // 执行冻结用户
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

        // 执行解冻用户
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

        // 执行铸造代币
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

        // 向白名单成员分发代币
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

        // 从指定地址转账（限制冻结用户）
        function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
            require(!frozen[sender], "Sender is frozen");
            require(amount == uint256(uint128(amount)), "Amount must be an integer");
            return super.transferFrom(sender, recipient, amount);
        }

        // 小数位：返回 0（自定义逻辑）
        function decimals() public view virtual override returns (uint8) {
            return 0;
        }

        // 获取用户余额
        function balanceOfUser(address user) external view returns (uint256) {
            return balanceOf(user);
        }

        // 获取链上 ID
        function onchainID() external view override returns (address) {
            return address(this);
        }

        // 获取版本号
        function version() external view override returns (string memory) {
            return "1.0.0";
        }

        // 获取身份注册地址（默认 0）
        function identityRegistry() external view override returns (address) {
            return address(0);
        }

        // 获取合规性地址（默认 0）
        function compliance() external view override returns (address) {
            return address(0);
        }

        // 检查合约是否暂停
        function paused() external view override returns (bool) {
            return contractPaused;
        }

        // 检查用户是否冻结
        function isFrozen(address userAddress) external view override returns (bool) {
            return frozen[userAddress];
        }

        // 获取冻结代币数量（默认 0）
        function getFrozenTokens(address userAddress) external view override returns (uint256) {
            return 0;
        }

        // 设置新名称（内部函数）
        function _setName(string memory newName) internal {
            tokenName = newName;
        }
    }