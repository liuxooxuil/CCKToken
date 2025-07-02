// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/CCK/ERC3643.sol";

contract CCKToken is ERC20, Ownable, IERC3643, ReentrancyGuard {
    uint256 public TOTAL_SUPPLY = 300_000_000 * 10**18; // Integer units (decimals = 0)
    mapping(address => bool) public whitelist;
    mapping(address => bool) public frozen;
    uint256 public mintedAmount;
    string public tokenName;
    uint256 public constant EXCHANGE_RATE = 20;
    mapping(address => bool) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public constant TOTAL_VOTES_REQUIRED = 5;
    uint256 public constant MIN_VOTES_FOR_USER_ACTIONS = 3;
    uint256 public constant MIN_VOTES_FOR_MINT = 2;
    address[] public votersList;

    enum ProposalType { Name, TotalSupply, Voters, WhitelistAdd, WhitelistRemove, Freeze, Unfreeze, Mint, ToggleWhitelistCheck }

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
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 internal proposalCount;
    bool public votingPaused;
    bool public contractPaused;
    uint256 public lastDistributionTimestamp;
    uint256 public constant DISTRIBUTION_INTERVAL = 300;
    uint256 public constant DISTRIBUTION_AMOUNT = 1; // Integer units
    uint256 public lastAutoBatchMintTimestamp;
    uint256 public constant AUTO_BATCH_MINT_INTERVAL = 15 minutes;
    uint256 public constant BATCH_MINT_AMOUNT = 100; // Integer units
    bool public whitelistCheckEnabled = false;

    event ProposalCreated(uint256 indexed proposalId, ProposalType proposalType, address initiator);
    event ProposalExecuted(uint256 indexed proposalId, ProposalType proposalType);
    event ProposalCancelled(uint256 indexed proposalId, ProposalType proposalType);
    event NameChanged(string newName);
    event TotalSupplyAdjusted(uint256 newTotalSupply);
    event VotersChanged(address[] oldVoters, address[] newVoters);
    event StatusChanged(address indexed target, string statusType, bool status);
    event MintExecuted(address to, uint256 amount);
    event WhitelistDistribution(uint256 amount);
    event VotingPaused();
    event VotingResumed();
    event ContractPaused();
    event ContractResumed();
    event Exchange(address indexed user, uint256 inputAmount, uint256 cckAmount, address indexed targetAddress);
    event BatchMint(address[] indexed recipients, uint256 amountPerAddress, bool isAuto);
    event VoteCast(uint256 indexed proposalId, address indexed voter);
    event WhitelistCheckToggled(bool enabled);
    event Deposit(address indexed from, address indexed token, address indexed to, uint256 amount);

    constructor(
        string memory initialName,
        address[] memory _whitelist,
        address[] memory _voters
    ) ERC20(initialName, "CC") Ownable(msg.sender) {
        require(_whitelist.length > 0, "Whitelist cannot be empty");
        require(_voters.length > 0, "Voters list cannot be empty");

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

    function _batchMintToWhitelist(address[] memory whitelistAddresses, uint256 amount) internal {
        require(whitelistAddresses.length > 0, "Whitelist addresses cannot be empty");
        uint256 totalMintAmount = whitelistAddresses.length * amount;
        require(mintedAmount + totalMintAmount <= TOTAL_SUPPLY, "Exceeds total supply");

        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            address recipient = whitelistAddresses[i];
            require(recipient != address(0), "Invalid recipient address");
            require(whitelist[recipient], "Recipient not whitelisted");
            _mint(recipient, amount);
        }
        mintedAmount += totalMintAmount;
    }

    function autoBatchMintToWhitelist(address[] memory whitelistAddresses) external nonReentrant {
        require(!contractPaused, "Contract paused");
        require(block.timestamp >= lastAutoBatchMintTimestamp + AUTO_BATCH_MINT_INTERVAL, "Too soon for auto mint");
        _batchMintToWhitelist(whitelistAddresses, BATCH_MINT_AMOUNT);
        lastAutoBatchMintTimestamp = block.timestamp;
        emit BatchMint(whitelistAddresses, BATCH_MINT_AMOUNT, true);
    }

    function manualBatchMintToWhitelist(address[] memory whitelistAddresses) external nonReentrant {
        require(!contractPaused, "Contract paused");
        require(voters[msg.sender], "Not a voter");
        _batchMintToWhitelist(whitelistAddresses, BATCH_MINT_AMOUNT);
        emit BatchMint(whitelistAddresses, BATCH_MINT_AMOUNT, false);
    }

    function exchange(uint256 inputAmount, address targetAddress) external nonReentrant {
        require(!contractPaused, "Contract paused");
        if (whitelistCheckEnabled) {
            require(whitelist[targetAddress], "Target not whitelisted");
        }
        require(inputAmount > 0, "Input amount must be greater than 0");

        uint256 cckAmount = inputAmount * EXCHANGE_RATE;
        require(cckAmount > 0, "CCK amount must be greater than 0");
        require(mintedAmount + cckAmount <= TOTAL_SUPPLY, "Exceeds total supply");

        _mint(targetAddress, cckAmount);
        mintedAmount += cckAmount;
        emit Exchange(msg.sender, inputAmount, cckAmount, targetAddress);
    }

    function deposit(address tokenAddress, address target, uint256 amount, uint8 tokenDecimals, uint256 exchangeRate) external nonReentrant returns (bool success) {
        require(!contractPaused, "Contract paused");
        require(amount > 0, "Amount must be greater than 0");
        require(target != address(0), "Invalid target address");
        require(tokenAddress != address(0), "Invalid token address");
        require(tokenDecimals <= 78, "Invalid token decimals"); // Prevent overflow
        require(exchangeRate > 0, "Exchange rate must be greater than 0");
        if (whitelistCheckEnabled) {
            require(whitelist[msg.sender], "Sender not whitelisted");
        }
        require(!frozen[msg.sender], "Sender account is frozen");

        // Transfer external token to target address
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, target, amount), "External token transfer failed");

        // Calculate CCK amount: base amount (adjusted for token decimals) * exchange rate
        uint256 baseAmount = amount / (10 ** tokenDecimals); // Convert to integer units of external token
        uint256 cckAmount = baseAmount * exchangeRate; // Apply exchange rate
        require(cckAmount > 0, "CCK amount must be greater than 0");
        require(mintedAmount + cckAmount <= TOTAL_SUPPLY, "Exceeds total supply");
        _mint(msg.sender, cckAmount);
        mintedAmount += cckAmount;

        emit Deposit(msg.sender, tokenAddress, target, cckAmount);
        return true;
    }

    function propose(
        ProposalType proposalType,
        address target,
        uint256 value,
        string memory name,
        address[] memory oldVoters,
        address[] memory newVoters
    ) external {
        require(!contractPaused, "Contract paused");
        require(voters[msg.sender], "Not a voter");

        if (proposalType == ProposalType.Name) {
            require(bytes(name).length > 0, "Name cannot be empty");
        } else if (proposalType == ProposalType.TotalSupply) {
            require(value != 0, "Value cannot be zero");
            require(int256(TOTAL_SUPPLY) + int256(value) >= int256(mintedAmount), "Invalid total supply");
            require(int256(TOTAL_SUPPLY) + int256(value) >= 0, "Total supply cannot be negative");
        } else if (proposalType == ProposalType.Voters) {
            require(oldVoters.length == newVoters.length && oldVoters.length > 0, "Invalid voters list");
            for (uint256 i = 0; i < oldVoters.length; i++) {
                require(voters[oldVoters[i]], "Old voter not found");
                require(newVoters[i] != address(0) && !voters[newVoters[i]], "Invalid new voter");
                for (uint256 j = i + 1; j < newVoters.length; j++) {
                    require(newVoters[i] != newVoters[j], "Duplicate new voters");
                }
            }
        } else if (proposalType == ProposalType.WhitelistAdd) {
            require(target != address(0) && !whitelist[target], "Invalid or already whitelisted");
        } else if (proposalType == ProposalType.WhitelistRemove) {
            require(whitelist[target], "Target not whitelisted");
        } else if (proposalType == ProposalType.Freeze) {
            require(target != address(0) && !frozen[target], "Invalid or already frozen");
        } else if (proposalType == ProposalType.Unfreeze) {
            require(frozen[target], "Target not frozen");
        } else if (proposalType == ProposalType.Mint) {
            require(whitelist[target] && target != address(0), "Invalid or not whitelisted");
            require(value > 0 && mintedAmount + value <= TOTAL_SUPPLY, "Invalid mint amount");
        } else if (proposalType == ProposalType.ToggleWhitelistCheck) {
            require(value <= 1, "Invalid value");
            require(target == address(0) && bytes(name).length == 0 && oldVoters.length == 0 && newVoters.length == 0, "Invalid parameters");
        }

        proposals[proposalCount] = Proposal({
            proposalType: proposalType,
            initiator: msg.sender,
            voteCount: 0,
            timestamp: proposalType <= ProposalType.Voters ? block.timestamp + 48 hours : block.timestamp,
            target: target,
            value: value,
            name: name,
            oldVoters: oldVoters,
            newVoters: newVoters,
            active: true
        });

        emit ProposalCreated(proposalCount, proposalType, msg.sender);
        proposalCount++;
    }

    function vote(uint256 proposalId) external {
        require(!contractPaused, "Contract paused");
        require(voters[msg.sender], "Not a voter");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "Proposal not active");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(!votingPaused, "Voting paused");

        hasVoted[proposalId][msg.sender] = true;
        proposal.voteCount++;

        uint256 requiredVotes = proposal.proposalType == ProposalType.Mint || proposal.proposalType == ProposalType.ToggleWhitelistCheck ?
                                MIN_VOTES_FOR_MINT : (proposal.proposalType >= ProposalType.WhitelistAdd && 
                                proposal.proposalType <= ProposalType.Unfreeze ? MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
        require(proposal.voteCount <= requiredVotes, "Too many votes");

        emit VoteCast(proposalId, msg.sender);
    }

    function _checkProposalVotes(Proposal storage proposal) internal view returns (uint256) {
        require(proposal.active, "Proposal not active");
        require(block.timestamp >= proposal.timestamp, "Proposal not ready");
        uint256 requiredVotes = proposal.proposalType == ProposalType.Mint || proposal.proposalType == ProposalType.ToggleWhitelistCheck ?
                                MIN_VOTES_FOR_MINT : (proposal.proposalType == ProposalType.WhitelistAdd || 
                                proposal.proposalType == ProposalType.WhitelistRemove || proposal.proposalType == ProposalType.Freeze || 
                                proposal.proposalType == ProposalType.Unfreeze ? MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
        require(proposal.voteCount >= requiredVotes, "Insufficient votes");
        return requiredVotes;
    }

    function executeProposal(uint256 proposalId) external {
        require(!contractPaused, "Contract paused");
        Proposal storage proposal = proposals[proposalId];
        _checkProposalVotes(proposal);

        if (proposal.proposalType == ProposalType.Name) {
            _setName(proposal.name);
            emit NameChanged(proposal.name);
        } else if (proposal.proposalType == ProposalType.TotalSupply) {
            TOTAL_SUPPLY = uint256(int256(TOTAL_SUPPLY) + int256(proposal.value));
            emit TotalSupplyAdjusted(TOTAL_SUPPLY);
        } else if (proposal.proposalType == ProposalType.Voters) {
            address[] memory tempVotersList = votersList;
            for (uint256 i = 0; i < proposal.oldVoters.length; i++) {
                voters[proposal.oldVoters[i]] = false;
                voters[proposal.newVoters[i]] = true;
                for (uint256 j = 0; j < tempVotersList.length; j++) {
                    if (tempVotersList[j] == proposal.oldVoters[i]) {
                        tempVotersList[j] = proposal.newVoters[i];
                        break;
                    }
                }
            }
            votersList = tempVotersList;
            emit VotersChanged(proposal.oldVoters, proposal.newVoters);
        } else if (proposal.proposalType == ProposalType.WhitelistAdd) {
            whitelist[proposal.target] = true;
            emit StatusChanged(proposal.target, "Whitelist", true);
        } else if (proposal.proposalType == ProposalType.WhitelistRemove) {
            whitelist[proposal.target] = false;
            emit StatusChanged(proposal.target, "Whitelist", false);
        } else if (proposal.proposalType == ProposalType.Freeze) {
            frozen[proposal.target] = true;
            emit StatusChanged(proposal.target, "Freeze", true);
        } else if (proposal.proposalType == ProposalType.Unfreeze) {
            frozen[proposal.target] = false;
            emit StatusChanged(proposal.target, "Freeze", false);
        } else if (proposal.proposalType == ProposalType.Mint) {
            _mint(proposal.target, proposal.value);
            mintedAmount += proposal.value;
            emit MintExecuted(proposal.target, proposal.value);
        } else if (proposal.proposalType == ProposalType.ToggleWhitelistCheck) {
            whitelistCheckEnabled = proposal.value == 1;
            emit WhitelistCheckToggled(proposal.value == 1);
        }

        resetVotes(proposalId);
        delete proposals[proposalId];
        emit ProposalExecuted(proposalId, proposal.proposalType);
    }

    function cancelProposal(uint256 proposalId) external {
        require(!contractPaused, "Contract paused");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "Proposal not active");
        require(msg.sender == proposal.initiator, "Not initiator");
        require(proposal.proposalType <= ProposalType.Voters, "Cannot cancel this proposal type");
        require(block.timestamp < proposal.timestamp, "Proposal time expired");

        resetVotes(proposalId);
        ProposalType cancelledType = proposal.proposalType;
        delete proposals[proposalId];
        emit ProposalCancelled(proposalId, cancelledType);
    }

    function resetVotes(uint256 proposalId) internal {
        for (uint256 i = 0; i < votersList.length; i++) {
            if (hasVoted[proposalId][votersList[i]]) {
                hasVoted[proposalId][votersList[i]] = false;
            }
        }
    }

    function getActiveProposals() external view returns (uint256[] memory ids) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active) {
                activeCount++;
            }
        }

        ids = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active) {
                ids[index] = i;
                index++;
            }
        }
    }

    function distributeToWhitelist() external {
        require(!contractPaused, "Contract paused");
        require(voters[msg.sender], "Not a voter");
        require(block.timestamp >= lastDistributionTimestamp + DISTRIBUTION_INTERVAL, "Too soon for distribution");
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

    function pauseContract() external {
        require(voters[msg.sender], "Not a voter");
        require(!contractPaused, "Contract already paused");
        contractPaused = true;
        emit ContractPaused();
    }

    function resumeContract() external {
        require(voters[msg.sender], "Not a voter");
        contractPaused = false;
        emit ContractResumed();
    }

    function remainingSupply() external view returns (uint256) {
        return TOTAL_SUPPLY - mintedAmount;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(!contractPaused, "Contract paused");
        require(!frozen[msg.sender], "Sender frozen");
        require(amount == uint256(uint128(amount)), "Amount too large");

        bool success = super.transfer(to, amount);
        if (success && to == address(this)) {
            _mint(msg.sender, amount);
        }
        return success;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(!contractPaused, "Contract paused");
        require(!frozen[sender], "Sender frozen");
        require(amount == uint256(uint128(amount)), "Amount too large");

        bool success = super.transferFrom(sender, recipient, amount);
        if (success && recipient == address(this)) {
            _mint(sender, amount);
        }
        return success;
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

    function version() external pure override returns (string memory) {
        return "1.0.0";
    }

    function identityRegistry() external pure override returns (address) {
        return address(0);
    }

    function compliance() external pure override returns (address) {
        return address(0);
    }

    function paused() external view override returns (bool) {
        return contractPaused;
    }

    function isFrozen(address userAddress) external view override returns (bool) {
        return frozen[userAddress];
    }

    function _setName(string memory newName) internal {
        tokenName = newName;
    }

    function getProposalCount() public view returns (uint256) {
        return proposalCount > 0 ? proposalCount - 1 : 0;
    }

    function getWhitelistCheckEnabled() public view returns (bool) {
        return whitelistCheckEnabled;
    }
}