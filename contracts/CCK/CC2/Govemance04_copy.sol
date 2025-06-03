// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/CCK/ERC3643.sol";

contract CCKToken is ERC20, Ownable, IERC3643, ReentrancyGuard {
    uint256 public TOTAL_SUPPLY = 500_000 * 10**18;
    mapping(address => bool) public whitelist;
    address[] public whitelistMembers;
    mapping(address => bool) public frozen;
    address public uniswapPool;
    uint256 public mintedAmount;
    string public tokenName;
    // address public inputToken; // 用于交换的代币，需通过治理设置
    // address public reserveAddress; // 储备地址，需通过治理设置
    uint256 public constant EXCHANGE_RATE = 20;

    address[] public voters;
    mapping(address => bool) public hasVoted;
    uint256 public voteCount;
    uint256 public constant TOTAL_VOTES_REQUIRED = 5;
    uint256 public constant MIN_VOTES_FOR_USER_ACTIONS = 3;
    uint256 public constant MIN_VOTES_FOR_MINT = 2;
    bool public proposalActive;
    bool public votingPaused;
    bool public contractPaused;
    string public proposalType;
    address public proposalInitiator;
    uint256 public changeTimestamp;
    string public newProposedName;
    int64 public proposedAdjustmentAmount;
    uint256 public totalSupplyAdjustmentTimestamp;
    address[] public proposedOldVoters;
    address[] public proposedNewVoters;
    uint256 public votersChangeTimestamp;
    address public proposedWhitelistMember;
    string public proposedWhitelistAction;
    address public proposedFreezeUser;
    string public proposedFreezeAction;
    address public proposedMintRecipient;
    uint256 public proposedMintAmount;
    uint256 public lastDistributionTimestamp;
    uint256 public constant DISTRIBUTION_INTERVAL = 300;
    uint256 public constant DISTRIBUTION_AMOUNT = 1 * 10**18;

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
    event Exchange(address indexed user, uint256 inputAmount, uint256 cckAmount, address indexed targetAddress);
    event Debug(string message, uint256 value);

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
        address[] memory _voters
    ) ERC20(initialName, "CCKToken") Ownable(msg.sender) {
        require(_whitelist.length > 0, "At least one whitelisted address required");
        require(_voters.length > 0, "At least one voter required");

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
        emit Debug("Constructor completed", 0);
    }

    function exchange(uint256 inputAmount, address targetAddress) external nonReentrant whenNotPaused {
        require(whitelist[targetAddress], "Target not whitelisted");
        require(inputAmount > 0, "Input amount must be greater than zero");

        uint256 cckAmount = (inputAmount * EXCHANGE_RATE);
        require(cckAmount > 0, "CCK amount too small");
        require(mintedAmount + (cckAmount * 1e18) <= TOTAL_SUPPLY, "Total supply exceeded");

        _mint(targetAddress, cckAmount * 1e18);
        mintedAmount += cckAmount * 1e18;

        emit Exchange(msg.sender, inputAmount, cckAmount, targetAddress);
    }

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

    function resetVotes() internal {
        for (uint256 i = 0; i < voters.length; i++) {
            hasVoted[voters[i]] = false;
        }
    }

    function getCurrentPrice() external view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint256 price = uint256(sqrtPriceX96) ** 2 / (2 ** 192);
        return price;
    }

    function name() public view virtual override returns (string memory) {
        return tokenName;
    }

    function isVoter(address _voter) internal view returns (bool) {
        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i] == _voter) {
                return true;
            }
        }
        return false;
    }

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

    function changeMint() external whenNotPaused {
        require(proposalActive, "No active proposal");
        require(keccak256(abi.encodePacked(proposalType)) == keccak256(abi.encodePacked("mint")), "Invalid proposal type");
        require(voteCount >= MIN_VOTES_FOR_MINT, "Not enough votes");
        require(proposedMintRecipient != address(0), "Invalid receiver address");
        require(whitelist[proposedMintRecipient], "Recipient not whitelisted");

        _mint(proposedMintRecipient, proposedMintAmount);
        mintedAmount += proposedMintAmount;

        proposalActive = false;
        proposalType = "";
        emit MintExecuted(proposedMintRecipient, proposedMintAmount);
        delete proposedMintRecipient;
        delete proposedMintAmount;
    }

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

    function pauseVoting() external onlyOwner {
        votingPaused = true;
        emit VotingPaused();
    }

    function resumeVoting() external onlyOwner {
        votingPaused = false;
        emit VotingResumed();
    }

    function pauseContract() external onlyVoter whenNotPaused {
        require(voteCount < TOTAL_VOTES_REQUIRED, "Already enough votes to pause");
        resetVotes();
        voteCount = 0;
        contractPaused = true;
        emit ContractPaused();
    }

    function resumeContract() external onlyVoter whenNotPaused {
        require(voteCount < TOTAL_VOTES_REQUIRED, "Already enough votes to resume");
        resetVotes();
        voteCount = 0;
        contractPaused = false;
        emit ContractResumed();
    }

    function remainingSupply() external view returns (uint256) {
        return TOTAL_SUPPLY - mintedAmount;
    }

    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        require(!frozen[msg.sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transfer(to, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!frozen[sender], "Sender is frozen");
        require(amount == uint256(uint128(amount)), "Amount must be an integer");
        return super.transferFrom(sender, recipient, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    function balanceOfUser(address user) external view returns (uint256) {
        return balanceOf(user);
    }

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

    function _setName(string memory newName) internal {
        tokenName = newName;
    }
}