// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/CCK/ERC3643.sol";

contract CCKToken is ERC20, Ownable, IERC3643, ReentrancyGuard {
    uint256 public TOTAL_SUPPLY = 500_000 * 10**18;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public frozen;
    address public uniswapPool;
    uint256 public mintedAmount;
    string public tokenName;
    uint256 public constant EXCHANGE_RATE = 20;

    mapping(address => bool) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public constant TOTAL_VOTES_REQUIRED = 5;
    uint256 public constant MIN_VOTES_FOR_USER_ACTIONS = 3;
    uint256 public constant MIN_VOTES_FOR_MINT = 2;
    bool isFirstProposal = true;
    // 存储投票者列表
    address[] public votersList;

    enum ProposalType { Name, TotalSupply, Voters, WhitelistAdd, WhitelistRemove, Freeze, Unfreeze, Mint }
    struct Proposal {
        ProposalType proposalType;
        address initiator;
        uint256 voteCount;
        uint256 timestamp;
        address target;
        uint256 value;
        string name;
        address[] oldVoters;
        address[] newVoters;
        bool active;
        address[] votedVoters; // 记录已投票的投票者
    }
    mapping(uint256 => Proposal) public proposals;
    uint256 internal proposalCount;
    bool public votingPaused;
    bool public contractPaused;

    uint256 public lastDistributionTimestamp;
    uint256 public constant DISTRIBUTION_INTERVAL = 300;
    uint256 public constant DISTRIBUTION_AMOUNT = 1 * 10**18;

    uint256 public lastAutoBatchMintTimestamp;
    uint256 public constant AUTO_BATCH_MINT_INTERVAL = 15 minutes;
    uint256 public constant BATCH_MINT_AMOUNT = 100 * 10**18;

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
    event AutoBatchMintToWhitelist(address[] indexed recipients, uint256 amountPerAddress);
    event ManualBatchMintToWhitelist(address[] indexed recipients, uint256 amountPerAddress);
    event VoteCast(uint256 indexed proposalId, address indexed voter);

    modifier onlyVoter() {
        require(voters[msg.sender], "Not a voter");
        _;
    }

    modifier whenNotPaused() {
        require(!contractPaused, "Contract paused");
        _;
    }

    constructor(
        string memory initialName,
        address[] memory _whitelist,
        address[] memory _voters
    ) ERC20(initialName, "CC") Ownable(msg.sender) {
        require(_whitelist.length > 0, "Empty whitelist");
        require(_voters.length > 0, "Empty voters");

        for (uint256 i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), "Invalid whitelist address");
            whitelist[_whitelist[i]] = true;
        }

        for (uint256 i = 0; i < _voters.length; i++) {
            require(_voters[i] != address(0), "Invalid voter address");
            voters[_voters[i]] = true;
            votersList.push(_voters[i]);
        }

        tokenName = initialName;
        lastDistributionTimestamp = block.timestamp;
        lastAutoBatchMintTimestamp = block.timestamp;
    }

    function autoBatchMintToWhitelist(address[] memory whitelistAddresses) external whenNotPaused nonReentrant {
        require(block.timestamp >= lastAutoBatchMintTimestamp + AUTO_BATCH_MINT_INTERVAL, "Auto batch mint interval not reached");
        require(whitelistAddresses.length > 0, "Whitelist addresses array empty");
        uint256 totalMintAmount = whitelistAddresses.length * BATCH_MINT_AMOUNT;
        require(mintedAmount + totalMintAmount <= TOTAL_SUPPLY, "Exceeds total supply");

        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            address recipient = whitelistAddresses[i];
            require(recipient != address(0), "Invalid recipient address");
            require(whitelist[recipient], "Recipient not in whitelist");
            _mint(recipient, BATCH_MINT_AMOUNT);
        }

        mintedAmount += totalMintAmount;
        lastAutoBatchMintTimestamp = block.timestamp;

        emit AutoBatchMintToWhitelist(whitelistAddresses, BATCH_MINT_AMOUNT);
    }

    function manualBatchMintToWhitelist(address[] memory whitelistAddresses) external onlyVoter whenNotPaused nonReentrant {
        require(whitelistAddresses.length > 0, "Whitelist addresses array empty");
        uint256 totalMintAmount = whitelistAddresses.length * BATCH_MINT_AMOUNT;
        require(mintedAmount + totalMintAmount <= TOTAL_SUPPLY, "Exceeds total supply");

        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            address recipient = whitelistAddresses[i];
            require(recipient != address(0), "Invalid recipient address");
            require(whitelist[recipient], "Recipient not in whitelist");
            _mint(recipient, BATCH_MINT_AMOUNT);
        }

        mintedAmount += totalMintAmount;

        emit ManualBatchMintToWhitelist(whitelistAddresses, BATCH_MINT_AMOUNT);
    }

    function exchange(uint256 inputAmount, address targetAddress) external nonReentrant whenNotPaused {
        require(whitelist[targetAddress], "Target not whitelisted");
        require(inputAmount > 0, "Invalid input amount");

        uint256 cckAmount = inputAmount * EXCHANGE_RATE;
        require(cckAmount > 0, "Amount too small");
        require(mintedAmount + cckAmount <= TOTAL_SUPPLY, "Exceeds total supply");

        _mint(targetAddress, cckAmount);
        mintedAmount += cckAmount;

        emit Exchange(msg.sender, inputAmount, cckAmount, targetAddress);
    }

    function propose(
        ProposalType proposalType,
        address target,
        uint256 value,
        string memory name,
        address[] memory oldVoters,
        address[] memory newVoters
    ) external onlyVoter whenNotPaused {
        // 移除：require(proposals[proposalCount].active == false, "There are active proposals")
        if (proposalType == ProposalType.Name) {
            require(bytes(name).length > 0, "Empty name");
        } else if (proposalType == ProposalType.TotalSupply) {
            require(value != 0, "Invalid value");
            require(int256(TOTAL_SUPPLY) + int256(value) >= int256(mintedAmount), "Supply below minted");
            require(int256(TOTAL_SUPPLY) + int256(value) >= 0, "Negative supply");
        } else if (proposalType == ProposalType.Voters) {
            require(oldVoters.length == newVoters.length && oldVoters.length > 0, "Invalid voter arrays");
            for (uint256 i = 0; i < oldVoters.length; i++) {
                require(voters[oldVoters[i]], "Invalid old voter");
                require(newVoters[i] != address(0) && !voters[newVoters[i]], "Invalid new voter");
                for (uint256 j = i + 1; j < newVoters.length; j++) {
                    require(newVoters[i] != newVoters[j], "Duplicate new voter");
                }
            }
        } else if (proposalType == ProposalType.WhitelistAdd) {
            require(target != address(0) && !whitelist[target], "Invalid or whitelisted target");
        } else if (proposalType == ProposalType.WhitelistRemove) {
            require(whitelist[target], "Target not whitelisted");
        } else if (proposalType == ProposalType.Freeze) {
            require(target != address(0) && !frozen[target], "Invalid or frozen target");
        } else if (proposalType == ProposalType.Unfreeze) {
            require(frozen[target], "Target not frozen");
        } else if (proposalType == ProposalType.Mint) {
            require(whitelist[target] && target != address(0), "Invalid recipient");
            require(value > 0 && mintedAmount + value <= TOTAL_SUPPLY, "Invalid mint amount");
        }

        proposals[proposalCount] = Proposal({
            proposalType: proposalType,
            initiator: msg.sender,
            voteCount: 0,
            timestamp: proposalType <= ProposalType.Voters ? block.timestamp + 3 minutes : block.timestamp,
            target: target,
            value: value,
            name: name,
            oldVoters: oldVoters,
            newVoters: newVoters,
            active: true,
            votedVoters: new address[](0)
        });

        emit ProposalCreated(proposalCount, proposalType, msg.sender);
        // if (isFirstProposal){
        //     isFirstProposal = false;
        //     proposalCount;
        //     return;
        // }
        proposalCount++;
    }

    function vote(uint256 proposalId) external onlyVoter whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "No active proposal");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(!votingPaused, "Voting paused");

        hasVoted[proposalId][msg.sender] = true;
        proposal.voteCount++;
        proposal.votedVoters.push(msg.sender);

        uint256 requiredVotes = proposal.proposalType == ProposalType.Mint ? MIN_VOTES_FOR_MINT :
                               (proposal.proposalType >= ProposalType.WhitelistAdd && proposal.proposalType <= ProposalType.Unfreeze ?
                                MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
        require(proposal.voteCount <= requiredVotes, "Vote count exceeds limit");

        emit VoteCast(proposalId, msg.sender);
    }

    function executeProposal(uint256 proposalId) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "No active proposal");
        require(block.timestamp >= proposal.timestamp, "Proposal not ready");

        uint256 requiredVotes = proposal.proposalType == ProposalType.Mint ? MIN_VOTES_FOR_MINT :
                               (proposal.proposalType >= ProposalType.WhitelistAdd && proposal.proposalType <= ProposalType.Unfreeze ?
                                MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
        require(proposal.voteCount >= requiredVotes, "Insufficient votes");

        if (proposal.proposalType == ProposalType.Name) {
            _setName(proposal.name);
            emit NameChanged(proposal.name);
        } else if (proposal.proposalType == ProposalType.TotalSupply) {
            TOTAL_SUPPLY = uint256(int256(TOTAL_SUPPLY) + int256(proposal.value));
            emit TotalSupplyAdjusted(TOTAL_SUPPLY);
        } else if (proposal.proposalType == ProposalType.Voters) {
            for (uint256 i = 0; i < proposal.oldVoters.length; i++) {
                voters[proposal.oldVoters[i]] = false;
                // 更新 votersList
                for (uint256 j = 0; j < votersList.length; j++) {
                    if (votersList[j] == proposal.oldVoters[i]) {
                        votersList[j] = proposal.newVoters[i];
                        break;
                    }
                }
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

        resetVotes(proposalId);
        delete proposals[proposalId];
        emit ProposalExecuted(proposalId, proposal.proposalType);
    }

    function cancelProposal(uint256 proposalId) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "No active proposal");
        require(msg.sender == proposal.initiator, "Not initiator");
        require(proposal.proposalType <= ProposalType.Voters, "Invalid proposal type");
        require(proposal.voteCount >= TOTAL_VOTES_REQUIRED, "Proposal already approved");
        require(block.timestamp < proposal.timestamp, "Cancellation window closed");

        resetVotes(proposalId);
        ProposalType cancelledType = proposal.proposalType;
        delete proposals[proposalId];
        emit ProposalCancelled(proposalId, cancelledType);
    }

    function resetVotes(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        for (uint256 i = 0; i < proposal.votedVoters.length; i++) {
            hasVoted[proposalId][proposal.votedVoters[i]] = false;
        }
        delete proposal.votedVoters;
    }

    function getActiveProposals() external view returns (uint256[] memory ids, Proposal[] memory activeProposals) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active) {
                activeCount++;
            }
        }

        ids = new uint256[](activeCount);
        activeProposals = new Proposal[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active) {
                ids[index] = i;
                activeProposals[index] = proposals[i];
                index++;
            }
        }
    }

    function getCurrentPrice() public view returns (uint256 price) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (2**192);
    }

    function distributeToWhitelist() external onlyVoter whenNotPaused {
        require(block.timestamp >= lastDistributionTimestamp + DISTRIBUTION_INTERVAL, "Interval not reached");
        require(mintedAmount + DISTRIBUTION_AMOUNT <= TOTAL_SUPPLY, "Exceeds total supply");

        lastDistributionTimestamp = block.timestamp;
        emit WhitelistDistribution(DISTRIBUTION_AMOUNT);
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
        contractPaused = true;
        emit ContractPaused();
    }

    function resumeContract() external onlyVoter {
        contractPaused = false;
        emit ContractResumed();
    }

    function remainingSupply() external view returns (uint256) {
        return TOTAL_SUPPLY - mintedAmount;
    }

    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        require(!frozen[msg.sender], "Sender frozen");
        require(amount == uint256(uint128(amount)), "Invalid amount");
        return super.transfer(to, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!frozen[sender], "Sender frozen");
        require(amount == uint256(uint128(amount)), "Invalid amount");
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

    function getProposalCount() external view returns (uint256) {
        return proposalCount > 0 ? proposalCount - 1 : 0; // 查询时减 1
    }
}