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

    // 治理相关
    mapping(address => bool) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public constant TOTAL_VOTES_REQUIRED = 5;
    uint256 public constant MIN_VOTES_FOR_USER_ACTIONS = 3;
    uint256 public constant MIN_VOTES_FOR_MINT = 2;

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
    }
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    bool public votingPaused;
    bool public contractPaused;

    uint256 public lastDistributionTimestamp;
    uint256 public constant DISTRIBUTION_INTERVAL = 300;
    uint256 public constant DISTRIBUTION_AMOUNT = 1 * 10**18;

    // 新增：批量铸造相关
    uint256 public lastAutoBatchMintTimestamp;
    uint256 public constant AUTO_BATCH_MINT_INTERVAL = 15 minutes;
    uint256 public constant BATCH_MINT_AMOUNT = 100 * 10**18;

    // 事件（原有事件保持不变，新增批量铸造事件）
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

    modifier onlyVoter() {
        require(voters[msg.sender], "Not a voter");
        _;
    }

    modifier whenNotPaused() {
        require(!contractPaused, "The contract has been suspended");
        _;
    }

    constructor(
        string memory initialName,
        address[] memory _whitelist,
        address[] memory _voters
    ) ERC20(initialName, "CC") Ownable(msg.sender) {
        require(_whitelist.length > 0, "At least one whitelisted address is required");
        require(_voters.length > 0, "At least one voter is required");

        for (uint256 i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), "Invalid whitelist address");
            whitelist[_whitelist[i]] = true;
        }

        for (uint256 i = 0; i < _voters.length; i++) {
            require(_voters[i] != address(0), "Invalid voter address");
            voters[_voters[i]] = true;
        }

        tokenName = initialName;
        lastDistributionTimestamp = block.timestamp;
        lastAutoBatchMintTimestamp = block.timestamp; // 初始化自动批量铸造时间
    }

    // 新增：自动批量铸币（每15分钟可调用）
    function autoBatchMintToWhitelist(address[] memory whitelistAddresses) external whenNotPaused nonReentrant {
        require(block.timestamp >= lastAutoBatchMintTimestamp + AUTO_BATCH_MINT_INTERVAL, "Auto batch mint interval not reached");
        require(whitelistAddresses.length > 0, "Whitelist addresses array is empty");
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

    // 新增：手动批量铸币（由投票者调用）
    function manualBatchMintToWhitelist(address[] memory whitelistAddresses) external onlyVoter whenNotPaused nonReentrant {
        require(whitelistAddresses.length > 0, "Whitelist addresses array is empty");
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
        require(whitelist[targetAddress], "The destination address is not in the whitelist");
        require(inputAmount > 0, "The input quantity must be greater than zero");

        uint256 cckAmount = inputAmount * EXCHANGE_RATE;
        require(cckAmount > 0, "CC The quantity is too small");
        require(mintedAmount + cckAmount <= TOTAL_SUPPLY, "Exceeds the total supply");

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
        require(proposals[proposalCount].active == false, "There are active proposals");

        if (proposalType == ProposalType.Name) {
            require(bytes(name).length > 0, "The name cannot be empty");
        } else if (proposalType == ProposalType.TotalSupply) {
            require(value != 0, "The adjustment amount cannot be zero");
            require(int256(TOTAL_SUPPLY) + int256(value) >= int256(mintedAmount), "The supply cannot be less than the minted amount");
            require(int256(TOTAL_SUPPLY) + int256(value) >= 0, "The supply cannot be negative");
        } else if (proposalType == ProposalType.Voters) {
            require(oldVoters.length == newVoters.length && oldVoters.length > 0, "The voter array is invalid");
            for (uint256 i = 0; i < oldVoters.length; i++) {
                require(voters[oldVoters[i]], "Old voters are invalid");
                require(newVoters[i] != address(0) && !voters[newVoters[i]], "New voters are not valid");
                for (uint256 j = i + 1; j < newVoters.length; j++) {
                    require(newVoters[i] != newVoters[j], "New voters repeat");
                }
            }
        } else if (proposalType == ProposalType.WhitelistAdd) {
            require(target != address(0) && !whitelist[target], "Invalid or whitelisted");
        } else if (proposalType == ProposalType.WhitelistRemove) {
            require(whitelist[target], "Not on the whitelist");
        } else if (proposalType == ProposalType.Freeze) {
            require(target != address(0) && !frozen[target], "Invalid or frozen");
        } else if (proposalType == ProposalType.Unfreeze) {
            require(frozen[target], "Not frozen");
        } else if (proposalType == ProposalType.Mint) {
            require(whitelist[target] && target != address(0), "Invalid recipients");
            require(value > 0 && mintedAmount + value <= TOTAL_SUPPLY, "Number of invalid mints");
        }

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

        emit ProposalCreated(proposalCount, proposalType, msg.sender);
        proposalCount++;
    }

    function vote(uint256 proposalId) external onlyVoter whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "No active proposals");
        require(!hasVoted[proposalId][msg.sender], "Voted");
        require(!votingPaused, "Voting has been suspended");

        hasVoted[proposalId][msg.sender] = true;
        proposal.voteCount++;

        uint256 requiredVotes = proposal.proposalType == ProposalType.Mint ? MIN_VOTES_FOR_MINT :
                               (proposal.proposalType >= ProposalType.WhitelistAdd && proposal.proposalType <= ProposalType.Unfreeze ?
                                MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
        require(proposal.voteCount <= requiredVotes, "The number of votes is exceeded");
    }

    function executeProposal(uint256 proposalId) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "No active proposals");
        require(block.timestamp >= proposal.timestamp, "Proposal execution time not reached");

        uint256 requiredVotes = proposal.proposalType == ProposalType.Mint ? MIN_VOTES_FOR_MINT :
                               (proposal.proposalType >= ProposalType.WhitelistAdd && proposal.proposalType <= ProposalType.Unfreeze ?
                                MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
        require(proposal.voteCount >= requiredVotes, "There are not enough votes");

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

        resetVotes(proposalId);
        delete proposals[proposalId];
        emit ProposalExecuted(proposalId, proposal.proposalType);
    }

    function cancelProposal(uint256 proposalId) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "No active proposals");
        require(msg.sender == proposal.initiator, "Only the initiator can cancel");
        require(proposal.proposalType <= ProposalType.Voters, "Only name, supply, or voter proposals can be canceled");
        require(proposal.voteCount >= TOTAL_VOTES_REQUIRED, "The proposal was not approved");
        require(block.timestamp < proposal.timestamp, "The cancellation window is closed");

        resetVotes(proposalId);
        ProposalType cancelledType = proposal.proposalType;
        delete proposals[proposalId];
        emit ProposalCancelled(proposalId, cancelledType);
    }

    function resetVotes(uint256 proposalId) internal {
        // 重置指定提案的所有投票者状态
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active) {
                // 假设投票者数量有限，遍历 voters 映射不可行，需记录投票者
                // 这里简化处理，实际需维护投票者列表
                // 示例：重置所有已投票的投票者
                // 需在 vote 时记录投票者地址
            }
        }
        // 临时解决方案：手动重置已知的投票者
        // 需在部署时记录投票者列表
        // 示例：假设 voters 映射可迭代（实际需优化）
    }


    function getCurrentPrice() public view returns (uint256 price) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (2**192);
    }

    function distributeToWhitelist() external onlyVoter whenNotPaused {
        require(block.timestamp >= lastDistributionTimestamp + DISTRIBUTION_INTERVAL, "The distribution interval has not been reached");
        require(mintedAmount + DISTRIBUTION_AMOUNT <= TOTAL_SUPPLY, "Exceeds the total supply");

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
        require(!frozen[msg.sender], "The sender is frozen");
        require(amount == uint256(uint128(amount)), "The quantity must be an integer");
        return super.transfer(to, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!frozen[sender], "The sender is frozen");
        require(amount == uint256(uint128(amount)), "The quantity must be an integer");
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