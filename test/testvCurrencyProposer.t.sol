// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "../src/Governance/vCurrencyProposer.sol";
import "../src/Governance/ViFiGovernor.sol";
import "../src/VARQ.sol";
import "../src/MockUSDC.sol";
import "../src/vTokens.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "forge-std/console.sol";

contract testvCurrencyProposer is Test {
    vCurrencyProposer proposer;
    ViFiGovernor governor;
    VARQ varq;
    MockUSDC usdc;
    vTokens vusd;
    ProxyAdmin admin;
    uint256 constant TEN_MILLION = 1e6 * 10e18;
    uint256 constant vNGN_PROPOSAL_HASH =
        75914404841624833367818712717546805125547566659903663113614736328051148968570;

    event ProposalSubmitted(
        uint256 indexed proposalId,
        string name,
        string symbol
    );

    event Staked(
        uint256 indexed proposalId,
        address indexed staker,
        uint256 amount
    );
    event SentToGovernance(
        uint256 indexed proposalId,
        uint256 governanceProposalId
    );

    function setUp() public {
        usdc = new MockUSDC();
        varq = new VARQ(address(this), address(usdc));
        vusd = vTokens(varq.tokenProxies(1));
        varq.setOperator(address(vusd), true);

        // Deploy governor implementation
        ViFiGovernor governorImpl = new ViFiGovernor();
        // Deploy proxy admin
        admin = new ProxyAdmin(address(this));

        // Deploy governor proxy
        bytes memory initData = abi.encodeWithSelector(
            ViFiGovernor.initialize.selector,
            IVotes(address(vusd)),
            TimelockControllerUpgradeable(payable(address(this)))
        );

        TransparentUpgradeableProxy governorProxy = new TransparentUpgradeableProxy(
                address(governorImpl),
                address(admin),
                initData
            );
        // Use the proxied governor
        governor = ViFiGovernor(payable(address(governorProxy)));

        proposer = new vCurrencyProposer(
            address(vusd),
            address(governor),
            address(varq)
        );
    }

    function test_submitProposal() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        assertEq(proposalId, 0);
    }

    function test_submitProposalWithIncrementingProposalId() public {
        proposer.submitProposal("vKES", "vKES", address(0), 2000);
        uint256 proposalId = proposer.submitProposal(
            "vLAOS",
            "vLAOS",
            address(0),
            2000
        );
        assertEq(proposalId, 1);
    }

    function test_submitProposalWithCorrectProposalNameandSymbol() public {
        uint256 proposalId = proposer.submitProposal(
            "vKES",
            "vKES",
            address(0),
            2000
        );
        (string memory name, string memory symbol, , , , , , , ) = proposer
            .proposals(proposalId);
        assertEq(name, "vKES");
        assertEq(symbol, "vKES");
    }

    function test_submitProposalEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ProposalSubmitted(uint256(0), "vKES", "vKES");
        proposer.submitProposal("vKES", "vKES", address(0), 2000);
    }

    function test_approveProposal() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        proposer.approveProposal(proposalId, TEN_MILLION);
        assertEq(proposer.minStakeRequired(proposalId), TEN_MILLION);
    }

    // Test staking functionality
    function test_stakeSuccessfully() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        proposer.approveProposal(proposalId, TEN_MILLION);

        // Mint vUSD to test address and approve proposer
        usdc.approve(address(varq), TEN_MILLION);
        varq.depositUSD(TEN_MILLION);
        vusd.approve(address(proposer), TEN_MILLION);

        proposer.stake(proposalId, TEN_MILLION);

        assertEq(proposer.getProposalTotalStake(proposalId), TEN_MILLION);
    }

    function test_stakeEmitsEvent() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        proposer.approveProposal(proposalId, TEN_MILLION);

        usdc.approve(address(varq), TEN_MILLION);
        varq.depositUSD(TEN_MILLION);
        vusd.approve(address(proposer), TEN_MILLION);

        vm.expectEmit(true, true, false, true);
        emit Staked(proposalId, address(this), TEN_MILLION);
        proposer.stake(proposalId, TEN_MILLION);
    }

    function test_cannotStakeBeforeApproval() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );

        usdc.approve(address(varq), TEN_MILLION);
        varq.depositUSD(TEN_MILLION);
        vusd.approve(address(proposer), TEN_MILLION);

        vm.expectRevert("Proposal not approved");
        proposer.stake(proposalId, TEN_MILLION);
    }

    /* function test_cannotStakeAfterGovernanceSubmission() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        proposer.approveProposal(proposalId, TEN_MILLION);

        usdc.approve(address(varq), TEN_MILLION * 2);
        varq.depositUSD(TEN_MILLION * 2);
        vusd.approve(address(proposer), TEN_MILLION * 2);

        // First stake triggers governance submission
        proposer.stake(proposalId, TEN_MILLION);

        vm.expectRevert("Already sent to governance");
        proposer.stake(proposalId, TEN_MILLION);
    }

    // Test unstaking functionality
    function test_unstakeSuccessfully() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        proposer.approveProposal(proposalId, TEN_MILLION);

        usdc.approve(address(varq), TEN_MILLION);
        varq.depositUSD(TEN_MILLION);
        vusd.approve(address(proposer), TEN_MILLION);

        proposer.stake(proposalId, TEN_MILLION / 2);
        uint256 balanceBefore = vusd.balanceOf(address(this));
        proposer.unstake(proposalId, TEN_MILLION / 2);
        uint256 balanceAfter = vusd.balanceOf(address(this));

        assertEq(balanceAfter - balanceBefore, TEN_MILLION / 2);
        assertEq(proposer.getProposalTotalStake(proposalId), 0);
    } */

    function test_cannotUnstakeMoreThanStaked() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        proposer.approveProposal(proposalId, TEN_MILLION);

        usdc.approve(address(varq), TEN_MILLION);
        varq.depositUSD(TEN_MILLION);
        vusd.approve(address(proposer), TEN_MILLION);

        proposer.stake(proposalId, TEN_MILLION / 2);
        vm.expectRevert("Insufficient staked amount");
        proposer.unstake(proposalId, TEN_MILLION);
    }

    function test_cannotUnstakeAfterGovernanceSubmission() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        proposer.approveProposal(proposalId, TEN_MILLION);

        usdc.approve(address(varq), TEN_MILLION);
        varq.depositUSD(TEN_MILLION);
        vusd.approve(address(proposer), TEN_MILLION);

        proposer.stake(proposalId, TEN_MILLION); // This will trigger governance submission

        vm.expectRevert("Already sent to governance");
        proposer.unstake(proposalId, TEN_MILLION);
    }

    // Test governance submission
    function test_automaticGovernanceSubmissionOnThreshold() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        proposer.approveProposal(proposalId, TEN_MILLION);

        usdc.approve(address(varq), TEN_MILLION);
        varq.depositUSD(TEN_MILLION);
        vusd.approve(address(proposer), TEN_MILLION);

        proposer.stake(proposalId, TEN_MILLION);

        (, , , , , , bool isStakingOpen, bool sentToGovernance, ) = proposer
            .proposals(proposalId);
        assertFalse(isStakingOpen);
        assertTrue(sentToGovernance);
    }

    /* // Test owner-only functions
    function test_onlyOwnerCanApprove() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );

        vm.prank(address(1)); // Switch to non-owner address
        vm.expectRevert("Ownable: caller is not the owner");
        proposer.approveProposal(proposalId, TEN_MILLION);
    }
    */
    function test_cannotApproveProposalTwice() public {
        uint256 proposalId = proposer.submitProposal(
            "vNGN",
            "vNGN",
            address(0),
            2000
        );
        proposer.approveProposal(proposalId, TEN_MILLION);

        vm.expectRevert("Already approved");
        proposer.approveProposal(proposalId, TEN_MILLION);
    }
}
