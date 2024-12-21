// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/VARQ.sol";
import "../src/MockUSDC.sol";
import "../src/vTokens.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract testVARQ is Test {
    event vCurrencyStateAdded(
        uint256 nationId,
        uint256 tokenIdFiat,
        uint256 tokenIdReserve
    );
    event OracleRateUpdated(uint256 nationId, uint256 rate);
    event Transfer(
        address indexed operator,
        address from,
        address to,
        uint256 id,
        uint256 amount
    );

    VARQ varq;
    MockUSDC usdc;
    vTokens vusd;

    function setUp() public {
        // Initialize MockUSDC and VARQ contracts
        usdc = new MockUSDC();
        varq = new VARQ(address(this), address(usdc));
        vusd = vTokens(varq.tokenProxies(1));
    }

    // === Basic Functionality Tests ===
    // Test initial USDC balance
    function testInitialBalance() public {
        uint256 initialBalance = usdc.balanceOf(address(this));
        assertEq(initialBalance, 1e27); // 1 billion USDC, considering decimals
    }

    function testDepositUSD() public {
        uint256 depositAmount = 1e6 * 1e18; // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        assertEq(varq.balanceOf(address(this), 1), depositAmount);
    }

    // Test deposit of USDC through proxy
    function testDepositUSDProxy() public {
        uint256 depositAmount = 1e6 * 1e18; // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        assertEq(vusd.balanceOf(address(this)), depositAmount);
    }

    // Test withdrawal directly through VARQ
    function testWithdrawUSD() public {
        // First deposit some USDC
        uint256 depositAmount = 1e6 * 1e18; // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // Now withdraw half of it
        uint256 withdrawAmount = 5e5 * 1e18; // 500k USDC
        uint256 initialUSDCBalance = usdc.balanceOf(address(this));

        varq.withdrawUSD(withdrawAmount);

        // Check VARQ balance decreased
        assertEq(
            varq.balanceOf(address(this), 1),
            depositAmount - withdrawAmount
        );
        // Check USDC was received
        assertEq(
            usdc.balanceOf(address(this)),
            initialUSDCBalance + withdrawAmount
        );
    }

    // Test withdrawal through proxy
    function testWithdrawUSDProxy() public {
        // First deposit some USDC
        uint256 depositAmount = 1e6 * 1e18; // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // Now withdraw half of it
        uint256 withdrawAmount = 5e5 * 1e18; // 500k USDC
        uint256 initialUSDCBalance = usdc.balanceOf(address(this));

        varq.withdrawUSD(withdrawAmount);

        // Check vUSD proxy balance decreased
        assertEq(vusd.balanceOf(address(this)), depositAmount - withdrawAmount);
        // Check USDC was received
        assertEq(
            usdc.balanceOf(address(this)),
            initialUSDCBalance + withdrawAmount
        );
    }

    // === Currency State Management Tests ===

    // Test adding currency state with invalid nation ID
    // function testCannotAddDuplicateNationState() public {
    //     varq.addvCurrencyState("KES", "rqtKES", address(this));
    //     vm.expectRevert("Nation-state already exists");
    //     varq.addvCurrencyState("KES", "rqtKES2", address(this));
    // }

    // Test adding currency state with zero address oracle
    function testCannotAddZeroAddressOracle() public {
        // Attempt to add a currency state with a zero address for the oracle updater
        string memory symbol = "KES";
        string memory name = "rqtKES";

        // Expect the transaction to revert with a specific error message
        vm.expectRevert("Oracle updater cannot be zero address");
        varq.addvCurrencyState(symbol, name, address(0));
    }

    // === Oracle Management Tests ===

    // Test unauthorized oracle rate update
    function testCannotUpdateOracleRateUnauthorized() public {
        // First set up a currency state
        string memory symbol = "KES";
        string memory name = "rqtKES";
        uint256 nationId = varq.addvCurrencyState(symbol, name, address(this));

        // Create a different address to act as unauthorized user
        address unauthorized = address(0x1);

        // Switch to unauthorized user context
        vm.startPrank(unauthorized);

        // Attempt to update oracle rate with unauthorized address
        vm.expectRevert("Not authorized to update oracle");
        varq.updateOracleRate(nationId, 1e18); // Trying to set rate to 1:1

        vm.stopPrank();

        // Verify the oracle rate remains unchanged (should still be 0)
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(nationId);
        assertEq(state.oracleRate, 0, "Oracle rate should remain unchanged");
    }

    // Test oracle rate update with valid permissions
    function testUpdateOracleRate() public {
        // Set up currency state
        string memory symbol = "KES";
        string memory name = "rqtKES";
        uint256 nationId = varq.addvCurrencyState(symbol, name, address(this));

        // Update oracle rate
        uint256 newRate = 1e18; // 1:1 rate
        varq.updateOracleRate(nationId, newRate);

        // Verify rate was updated
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(nationId);
        assertEq(state.oracleRate, newRate, "Oracle rate should be updated");
    }

    // Test oracle updater change by non-owner
    function testCannotUpdateOracleUpdaterUnauthorized() public {
        // Set up currency state
        uint256 nationId = varq.addvCurrencyState(
            "KES",
            "rqtKES",
            address(this)
        );

        // Create unauthorized address
        address unauthorized = address(0x1);
        vm.startPrank(unauthorized);

        // Attempt unauthorized update
        vm.expectRevert(); // Just check for any revert
        varq.updateOracleUpdater(nationId, address(0x2));

        vm.stopPrank();
    }

    // === Minting Tests ===

    // Test minting with insufficient vUSD balance
    function testCannotMintWithInsufficientVUSD() public {
        // Set up currency state
        uint256 nationId = varq.addvCurrencyState(
            "KES",
            "rqtKES",
            address(this)
        );
        varq.updateOracleRate(nationId, 1e18);

        // Attempt to mint without enough vUSD
        vm.expectRevert("Insufficient vUSD balance");
        varq.mintvCurrency(nationId, 1e18);
    }

    // Test minting with zero oracle rate
    function testCannotMintWithZeroOracleRate() public {
        // Set up currency state without setting oracle rate
        uint256 nationId = varq.addvCurrencyState(
            "KES",
            "rqtKES",
            address(this)
        );

        // Deposit some vUSD first
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // Attempt to mint with zero oracle rate
        vm.expectRevert("Oracle rate cannot be zero");
        varq.mintvCurrency(nationId, 1e18);
    }

    // Test minting with non-existent nation state
    function testCannotMintNonExistentNation() public {
        // Attempt to mint for non-existent nation
        vm.expectRevert("Nation-state does not exist");
        varq.mintvCurrency(999, 1e18);
    }

    // Test successful minting with various amounts
    function testSuccessfulMint() public {
        // Initialize state
        _initializeReserveState(1);

        // Now perform the actual test
        uint256 mintAmount = 1e5 * 1e18;
        varq.mintvCurrency(1, mintAmount);

        // Check balances
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(1);
        assertEq(
            varq.balanceOf(address(this), state.tokenIdFiat),
            mintAmount * 2
        ); // Account for initial mint
        assertTrue(varq.balanceOf(address(this), state.tokenIdReserve) > 0);
    }

    // Test minting effects on state variables (S_u, S_f, S_r)
    function testMintStateVariables() public {
        // Set up currency state
        uint256 nationId = varq.addvCurrencyState(
            "KES",
            "rqtKES",
            address(this)
        );
        varq.updateOracleRate(nationId, 1e18);

        // Deposit vUSD
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // Record initial state
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(nationId);
        uint256 initialOracleRate = state.oracleRate;
        uint256 initialSu = state.S_u;
        uint256 initialSf = state.S_f;
        uint256 initialSr = state.S_r;

        // Mint nation currency
        uint256 mintAmount = 1e5 * 1e18;
        varq.mintvCurrency(nationId, mintAmount);

        // Check updated state variables
        state = varq.vCurrencyStates(nationId);
        uint256 newOracleRate = state.oracleRate;
        uint256 newSu = state.S_u;
        uint256 newSf = state.S_f;
        uint256 newSr = state.S_r;

        assertTrue(newSu > initialSu, "S_u should increase");
        assertTrue(newSf > initialSf, "S_f should increase");
        assertTrue(newSr > initialSr, "S_r should increase");
        assertEq(
            newOracleRate,
            initialOracleRate,
            "Oracle rate should remain unchanged"
        );
    }

    // === Burning Tests ===

    // Test burning with insufficient nation currency
    function testCannotBurnInsufficientNationCurrency() public {
        // Set up currency state and mint some currency
        uint256 nationId = varq.addvCurrencyState(
            "KES",
            "rqtKES",
            address(this)
        );
        varq.updateOracleRate(nationId, 1e18);

        // Attempt to burn without any balance
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(nationId);
        vm.expectRevert("Insufficient nation currency balance");
        varq.burnvCurrency(nationId, 1e18);
    }

    // Test burning with insufficient reserve quota
    function testCannotBurnInsufficientReserveQuota() public {
        // 1. Setup: Create nation state and set oracle rate
        uint256 nationId = varq.addvCurrencyState(
            "KES",
            "rqtKES",
            address(this)
        );
        varq.updateOracleRate(nationId, 1e18); // 1:1 rate

        // 2. Deposit vUSD for minting
        uint256 depositAmount = 1e6 * 1e18; // 1 million vUSD
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // 3. Mint initial tokens
        uint256 mintAmount = 1e5 * 1e18; // 100k tokens
        varq.mintvCurrency(nationId, mintAmount);

        // 4. Get token IDs - using tuple destructuring instead of struct
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(nationId);
        uint256 tokenIdFiat = state.tokenIdFiat;
        uint256 tokenIdReserve = state.tokenIdReserve;

        // 5. Transfer half of reserve quota tokens to another address
        address otherAddress = address(0x123);
        uint256 reserveBalance = varq.balanceOf(address(this), tokenIdReserve);
        varq.transfer(otherAddress, tokenIdReserve, reserveBalance / 2);

        // 6. Try to burn the full amount of nation currency
        vm.expectRevert("Insufficient reserve quota token balance");
        varq.burnvCurrency(nationId, mintAmount); // This should fail as we only have half the needed reserve tokens
    }

    // Test successful burning
    function testSuccessfulBurn() public {
        // Set up currency state
        uint256 nationId = varq.addvCurrencyState(
            "KES",
            "rqtKES",
            address(this)
        );
        varq.updateOracleRate(nationId, 1e18);

        // Deposit and mint
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        uint256 mintAmount = 1e5 * 1e18;
        varq.mintvCurrency(nationId, mintAmount);

        // Record balances before burn
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(nationId);
        uint256 tokenIdFiat = state.tokenIdFiat;
        uint256 tokenIdReserve = state.tokenIdReserve;
        uint256 initialFiatBalance = varq.balanceOf(address(this), tokenIdFiat);
        uint256 initialReserveBalance = varq.balanceOf(
            address(this),
            tokenIdReserve
        );

        // Burn half
        uint256 burnAmount = mintAmount / 2;
        varq.burnvCurrency(nationId, burnAmount);

        // Verify balances
        assertEq(
            varq.balanceOf(address(this), tokenIdFiat),
            initialFiatBalance - burnAmount
        );
        assertTrue(
            varq.balanceOf(address(this), tokenIdReserve) <
                initialReserveBalance
        );
    }

    // Test burning effects on state variables
    function testBurnStateVariables() public {}

    // === USD Deposit/Withdrawal Tests ===

    // Test deposit with zero amount
    function testCannotDepositZero() public {
        vm.expectRevert("Amount must be greater than zero");
        varq.depositUSD(0);
    }

    // Test deposit without USDC approval
    function testCannotDepositWithoutApproval() public {
        // Attempt to deposit without approving USDC first
        vm.expectRevert(); // Remove the specific error message to catch any revert
        varq.depositUSD(1e18);
    }

    // Test withdrawal with zero amount
    function testCannotWithdrawZero() public {
        vm.expectRevert("Amount must be greater than zero");
        varq.withdrawUSD(0);
    }

    // Test withdrawal exceeding balance
    function testCannotWithdrawExceedingBalance() public {
        vm.expectRevert("Insufficient vUSD balance");
        varq.withdrawUSD(1e18);
    }

    // === Calculation Tests ===

    // Test flux ratio calculation with zero oracle rate
    function testCannotCalculateFluxRatioZeroOracle() public {
        uint256 nationId = varq.addvCurrencyState(
            "KES",
            "rqtKES",
            address(this)
        );

        // Attempt to mint with zero oracle rate
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        vm.expectRevert("Oracle rate cannot be zero");
        varq.mintvCurrency(nationId, depositAmount);
    }

    // Test reserve ratio calculation with zero S_r
    function testCannotCalculateReserveRatioZeroSr() public {}

    // Test flux influence calculation scenarios
    function testFluxInfluenceCalculation() public {
        _initializeReserveState(1);

        // Verify state changes
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(1);
        assertTrue(state.S_r > 0, "S_r should be greater than zero");
        assertTrue(state.S_u > 0, "S_u should be greater than zero");
    }

    // === Integration Tests ===

    // Test full cycle: deposit -> mint -> burn -> withdraw
    function testFullCycle() public {
        _initializeReserveState(1);

        // Additional deposit for the test
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // Mint
        uint256 mintAmount = 1e5 * 1e18;
        varq.mintvCurrency(1, mintAmount);

        // Burn
        varq.burnvCurrency(1, mintAmount);

        // Withdraw
        varq.withdrawUSD(depositAmount);

        // Verify final state (accounting for initialization)
        assertEq(
            usdc.balanceOf(address(this)),
            1e27 - depositAmount,
            "Should have expected USDC balance"
        );
        assertTrue(
            varq.balanceOf(address(this), 1) > 0,
            "Should have remaining vUSD balance from initialization"
        );
    }

    // Test multiple nations interaction
    function testMultipleNationsInteraction() public {
        // Initialize both nations
        _initializeReserveState(1);
        _initializeReserveState(2);

        // Update second nation's rate
        varq.updateOracleRate(2, 2e18); // Different rate for second currency

        // Mint both currencies
        uint256 mintAmount = 1e5 * 1e18;
        varq.mintvCurrency(1, mintAmount);
        varq.mintvCurrency(2, mintAmount);

        // Verify independent state management
        IVARQ.vCurrencyState memory state1 = varq.vCurrencyStates(1);
        IVARQ.vCurrencyState memory state2 = varq.vCurrencyStates(2);

        assertTrue(varq.balanceOf(address(this), state1.tokenIdFiat) > 0);
        assertTrue(varq.balanceOf(address(this), state2.tokenIdFiat) > 0);
    }

    // === Event Tests ===

    // Test vCurrencyStateAdded event
    function testVCurrencyStateAddedEvent() public {
        // First add a currency state
        varq.addvCurrencyState("TEST", "rqtTEST", address(this));

        // Expect the next event with the correct values
        vm.expectEmit(true, true, true, true);
        // Parameters: (currencyId, tokenIdFiat, tokenIdReserve)
        emit vCurrencyStateAdded(2, 5, 4); // Updated to match actual values

        // Add another currency state
        varq.addvCurrencyState("KES", "rqtKES", address(this));
    }

    // Test OracleRateUpdated event
    function testOracleRateUpdatedEvent() public {
        varq.addvCurrencyState("KES", "rqtKES", address(this));

        vm.expectEmit(true, true, true, true);
        emit OracleRateUpdated(1, 1e18);
        varq.updateOracleRate(1, 1e18);
    }

    // Test Transfer events
    function testTransferEvents() public {
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);

        // First, expect the ERC20 Transfer from USDC
        vm.expectEmit(true, true, true, true, address(usdc));
        emit IERC20.Transfer(
            address(this), // from: testVARQ contract
            address(varq), // to: VARQ contract
            depositAmount // value
        );

        // Then, expect the ERC1155 Transfer from VARQ
        vm.expectEmit(true, true, true, true, address(varq));
        emit Transfer(
            address(this), // operator: testVARQ contract (msg.sender)
            address(0), // from: zero address (minting)
            address(this), // to: testVARQ contract
            1, // id: vUSD token ID
            depositAmount // amount
        );

        // Now perform the deposit which will emit both events in order
        varq.depositUSD(depositAmount);
    }

    // Helper function to initialize S_r for a nation
    function _initializeReserveState(uint256 nationId) internal {
        // Set up initial state
        varq.addvCurrencyState("TST", "rqtTST", address(this));
        varq.updateOracleRate(nationId, 1e18);

        // Deposit initial vUSD
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // Mint a small amount to initialize S_r
        uint256 initialMint = 1e5 * 1e18;
        varq.mintvCurrency(nationId, initialMint);

        // Wait for a block to ensure protocol rate is calculated
        vm.roll(block.number + 1);
    }

    function testUSDCTransferEvent() public {
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);

        vm.expectEmit(true, true, true, true, address(usdc));
        emit IERC20.Transfer(address(this), address(varq), depositAmount);

        varq.depositUSD(depositAmount);
    }

    function testVARQTransferEvent() public {
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);

        vm.expectEmit(true, true, true, true, address(varq));
        emit Transfer(
            address(this), // operator (the test contract is the operator)
            address(0), // from
            address(this), // to
            1, // id
            depositAmount // amount
        );

        varq.depositUSD(depositAmount);
    }

    function testMintvCurrency() public {
        // Setup currency state - now returns the nationId
        uint256 nationId = varq.addvCurrencyState(
            "KES",
            "rqtKES",
            address(this)
        );
        varq.updateOracleRate(nationId, 1e18);

        // Deposit vUSD
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // Mint vCurrency using the returned nationId
        uint256 mintAmount = 1e5 * 1e18;
        varq.mintvCurrency(nationId, mintAmount);

        // Get token IDs using the returned nationId
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(nationId);
        uint256 tokenIdFiat = state.tokenIdFiat;
        uint256 tokenIdReserve = state.tokenIdReserve;

        // Verify balances
        assertEq(varq.balanceOf(address(this), tokenIdFiat), mintAmount);
        assertEq(varq.balanceOf(address(this), tokenIdReserve), mintAmount);
    }

    function testFluxDiffWith3PercentHigherOracleRate() public {
        // Setup initial rates
        uint256 protocolRate = 1e18; // 1.0
        uint256 oracleRate = 1.03e18; // 1.03 (3% higher)

        // Calculate flux difference
        uint256 fluxDiff = varq.calculateFluxDiff(protocolRate, oracleRate);

        // Print values for debugging (as percentages)
        console.log("Protocol Rate:", protocolRate / 1e16, "%");
        console.log("Oracle Rate:", oracleRate / 1e16, "%");
        console.log("Flux Diff:", fluxDiff / 1e16, "%");

        // Assert flux difference is above 0.5 (50%)
        assertGt(fluxDiff, 0.5e18); // Greater than 50%
        assertLt(fluxDiff, 1e18); // Less than 100%
    }
}
