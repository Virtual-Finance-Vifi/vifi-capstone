// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ViFiGovernor.sol";
import "../VARQ.sol";
import "../interfaces/IvTokens.sol";

interface IViFiGovernor {
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);
}

contract vCurrencyProposer is Ownable {
    // Structs
    struct vCurrencyProposal {
        string name;
        string symbol;
        address oracleAddress;
        uint256 totalStaked;
        uint256 proposedRatio;
        bool approved; // Set by owner after review
        bool isStakingOpen; // True when approved and staking period starts
        bool sentToGovernance; // True when sent for governance vote
        uint256 governanceProposalId; // ID from ViFiGovernor
        mapping(address => StakeInfo) stakers;
    }

    struct StakeInfo {
        uint256 amountStaked;
        uint256 proposedRatio;
        uint256 timestamp;
    }

    // State variables
    IvTokens public immutable vUSD;
    IViFiGovernor public immutable governor;
    VARQ public immutable varq;

    mapping(uint256 => vCurrencyProposal) public proposals;
    uint256 public nextProposalId;
    mapping(uint256 => uint256) public minStakeRequired;

    // Events
    event ProposalSubmitted(
        uint256 indexed proposalId,
        string name,
        string symbol
    );

    event ProposalApproved(uint256 indexed proposalId);
    event StakingStarted(uint256 indexed proposalId);
    event Staked(
        uint256 indexed proposalId,
        address indexed staker,
        uint256 amount
    );
    event SentToGovernance(
        uint256 indexed proposalId,
        uint256 governanceProposalId
    );
    event Unstaked(
        uint256 indexed proposalId,
        address indexed staker,
        uint256 amount
    );

    constructor(
        address _vUSD,
        address _governor,
        address _varq
    ) Ownable(msg.sender) {
        vUSD = IvTokens(_vUSD);
        governor = IViFiGovernor(_governor);
        varq = VARQ(_varq);
    }

    function submitProposal(
        string memory _name,
        string memory _symbol,
        address _oracleAddress,
        uint256 _proposedRatio
    ) external returns (uint256 proposalId) {
        proposalId = nextProposalId++;
        vCurrencyProposal storage proposal = proposals[proposalId];

        proposal.name = _name;
        proposal.symbol = _symbol;
        proposal.oracleAddress = _oracleAddress;
        proposal.proposedRatio = _proposedRatio;
        proposal.approved = false;
        proposal.isStakingOpen = false;
        proposal.sentToGovernance = false;

        emit ProposalSubmitted(proposalId, _name, _symbol);
    }

    function approveProposal(
        uint256 proposalId,
        uint256 minStake
    ) external onlyOwner {
        vCurrencyProposal storage proposal = proposals[proposalId];
        require(!proposal.approved, "Already approved");

        proposal.approved = true;
        proposal.isStakingOpen = true;
        minStakeRequired[proposalId] = minStake;

        emit ProposalApproved(proposalId);
        emit StakingStarted(proposalId);
    }

    function stake(uint256 proposalId, uint256 amount) external {
        vCurrencyProposal storage proposal = proposals[proposalId];
        require(proposal.approved, "Proposal not approved");
        require(proposal.isStakingOpen, "Staking not open");
        require(!proposal.sentToGovernance, "Already sent to governance");

        vUSD.transferFrom(msg.sender, address(this), amount);

        proposal.stakers[msg.sender].amountStaked += amount;
        proposal.stakers[msg.sender].timestamp = block.timestamp;
        proposal.totalStaked += amount;

        emit Staked(proposalId, msg.sender, amount);

        if (proposal.totalStaked >= minStakeRequired[proposalId]) {
            _sendToGovernance(proposalId);
        }
    }

    function unstake(uint256 proposalId, uint256 amount) external {
        vCurrencyProposal storage proposal = proposals[proposalId];
        require(!proposal.sentToGovernance, "Already sent to governance");

        StakeInfo storage stakerInfo = proposal.stakers[msg.sender];
        require(
            stakerInfo.amountStaked >= amount,
            "Insufficient staked amount"
        );

        stakerInfo.amountStaked -= amount;
        proposal.totalStaked -= amount;

        require(vUSD.transfer(msg.sender, amount), "Transfer failed");

        emit Unstaked(proposalId, msg.sender, amount);
    }

    function _sendToGovernance(uint256 proposalId) internal {
        vCurrencyProposal storage proposal = proposals[proposalId];

        // Prepare the calldata for VARQ.addvCurrencyState
        bytes memory callData = abi.encodeWithSelector(
            VARQ.addvCurrencyState.selector,
            proposal.name,
            proposal.symbol,
            proposal.oracleAddress
        );

        address[] memory targets = new address[](1);
        targets[0] = address(varq);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        string memory description = string(
            abi.encodePacked("Add new vCurrency: ", proposal.name)
        );

        uint256 governanceProposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        proposal.governanceProposalId = governanceProposalId;
        proposal.sentToGovernance = true;
        proposal.isStakingOpen = false;

        emit SentToGovernance(proposalId, governanceProposalId);
    }

    // View functions
    function getProposalStake(
        uint256 proposalId,
        address staker
    ) external view returns (StakeInfo memory) {
        return proposals[proposalId].stakers[staker];
    }

    function getProposalTotalStake(
        uint256 proposalId
    ) external view returns (uint256) {
        return proposals[proposalId].totalStaked;
    }
}
