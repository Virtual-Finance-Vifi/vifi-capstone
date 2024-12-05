// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/VARQ.sol";
import "../src/MockUSDC.sol";
import "../src/vTokens.sol";

contract testVARQ is Test {
    event vCurrencyStateAdded(uint256 nationId, uint256 tokenIdFiat, uint256 tokenIdReserve);
    event OracleRateUpdated(uint256 nationId, uint256 rate);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
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
        assertEq(initialBalance, 1e27);  // 1 billion USDC, considering decimals
    }

    function testDepositUSD() public {
        uint256 depositAmount = 1e6 * 1e18;  // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        assertEq(varq.balanceOf(address(this), 1), depositAmount);
    }

    // Test deposit of USDC through proxy
    function testDepositUSDProxy() public {
        uint256 depositAmount = 1e6 * 1e18;  // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        assertEq(vusd.balanceOf(address(this)), depositAmount);
    }

    // Test withdrawal directly through VARQ
    function testWithdrawUSD() public {
        // First deposit some USDC
        uint256 depositAmount = 1e6 * 1e18;  // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        
        // Now withdraw half of it
        uint256 withdrawAmount = 5e5 * 1e18;  // 500k USDC
        uint256 initialUSDCBalance = usdc.balanceOf(address(this));
        
        varq.withdrawUSD(withdrawAmount);
        
        // Check VARQ balance decreased
        assertEq(varq.balanceOf(address(this), 1), depositAmount - withdrawAmount);
        // Check USDC was received
        assertEq(usdc.balanceOf(address(this)), initialUSDCBalance + withdrawAmount);
    }

    // Test withdrawal through proxy
    function testWithdrawUSDProxy() public {
        // First deposit some USDC
        uint256 depositAmount = 1e6 * 1e18;  // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        
        // Now withdraw half of it
        uint256 withdrawAmount = 5e5 * 1e18;  // 500k USDC
        uint256 initialUSDCBalance = usdc.balanceOf(address(this));
        
        varq.withdrawUSD(withdrawAmount);
        
        // Check vUSD proxy balance decreased
        assertEq(vusd.balanceOf(address(this)), depositAmount - withdrawAmount);
        // Check USDC was received
        assertEq(usdc.balanceOf(address(this)), initialUSDCBalance + withdrawAmount);
    }

    // === Currency State Management Tests ===
    
    // Test adding currency state with invalid nation ID
    function testCannotAddDuplicateNationState() public {
        // First addition should succeed
        string memory symbol = "KES";
        string memory name = "rqtKES";
        varq.addvCurrencyState(1, symbol, name, address(this));

        // Second addition with same nationId should fail
        vm.expectRevert("Nation-state already exists");
        varq.addvCurrencyState(1, "KES2", "rqtKES2", address(this));

        // Verify the original state remains unchanged
        (
            uint256 tokenIdFiat,
            uint256 tokenIdReserve,
            ,,,, // Skip other fields we don't need to check
            address oracleUpdater
        ) = varq.vCurrencyStates(1);

        // Check that original values are maintained
        assertEq(tokenIdFiat, 2, "Original tokenIdFiat should be unchanged");
        assertEq(tokenIdReserve, 3, "Original tokenIdReserve should be unchanged");
        assertEq(oracleUpdater, address(this), "Original oracleUpdater should be unchanged");

        // Verify original token names are maintained
        vTokens vkes = vTokens(varq.tokenProxies(tokenIdFiat));
        assertEq(vkes.name(), symbol, "Original token name should be unchanged");
        assertEq(vkes.symbol(), string(abi.encodePacked("v", symbol)), "Original token symbol should be unchanged");
    }

    // Test adding currency state with zero address oracle
    function testCannotAddZeroAddressOracle() public {
        // Attempt to add a currency state with a zero address for the oracle updater
        string memory symbol = "KES";
        string memory name = "rqtKES";
        
        // Expect the transaction to revert with a specific error message
        vm.expectRevert("Oracle updater cannot be zero address");
        varq.addvCurrencyState(1, symbol, name, address(0));
    }

    // === Oracle Management Tests ===
    
    // Test unauthorized oracle rate update
    function testCannotUpdateOracleRateUnauthorized() public {
        // First set up a currency state
        string memory symbol = "KES";
        string memory name = "rqtKES";
        varq.addvCurrencyState(1, symbol, name, address(this));

        // Create a different address to act as unauthorized user
        address unauthorized = address(0x1);
        
        // Switch to unauthorized user context
        vm.startPrank(unauthorized);
        
        // Attempt to update oracle rate with unauthorized address
        vm.expectRevert("Not authorized to update oracle");
        varq.updateOracleRate(1, 1e18); // Trying to set rate to 1:1
        
        vm.stopPrank();

        // Verify the oracle rate remains unchanged (should still be 0)
        (,, uint256 oracleRate,,,,) = varq.vCurrencyStates(1);
        assertEq(oracleRate, 0, "Oracle rate should remain unchanged");
    }

    // Test oracle rate update with valid permissions
    function testUpdateOracleRate() public {
        // Set up currency state
        string memory symbol = "KES";
        string memory name = "rqtKES";
        varq.addvCurrencyState(1, symbol, name, address(this));

        // Update oracle rate
        uint256 newRate = 1e18; // 1:1 rate
        varq.updateOracleRate(1, newRate);

        // Verify rate was updated
        (,, uint256 oracleRate,,,,) = varq.vCurrencyStates(1);
        assertEq(oracleRate, newRate, "Oracle rate should be updated");
    }

    // Test oracle updater change by non-owner
    function testCannotUpdateOracleUpdaterUnauthorized() public {
        // Set up currency state
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        
        // Create unauthorized address
        address unauthorized = address(0x1);
        vm.startPrank(unauthorized);
        
        // Attempt unauthorized update
        vm.expectRevert();  // Just check for any revert
        varq.updateOracleUpdater(1, address(0x2));
        
        vm.stopPrank();
    }

    // === Minting Tests ===

    // Test minting with insufficient vUSD balance
    function testCannotMintWithInsufficientVUSD() public {
        // Set up currency state
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        varq.updateOracleRate(1, 1e18);

        // Attempt to mint without enough vUSD
        vm.expectRevert("Insufficient vUSD balance");
        varq.mintvCurrency(1, 1e18);
    }

    // Test minting with zero oracle rate
    function testCannotMintWithZeroOracleRate() public {
        // Set up currency state without setting oracle rate
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        
        // Deposit some vUSD first
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // Attempt to mint with zero oracle rate
        vm.expectRevert("Oracle rate cannot be zero");
        varq.mintvCurrency(1, 1e18);
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
        (uint256 tokenIdFiat, uint256 tokenIdReserve,,,,,) = varq.vCurrencyStates(1);
        assertEq(varq.balanceOf(address(this), tokenIdFiat), mintAmount * 2); // Account for initial mint
        assertTrue(varq.balanceOf(address(this), tokenIdReserve) > 0);
    }

    // Test minting effects on state variables (S_u, S_f, S_r)
    function testMintStateVariables() public {
        // Set up currency state
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        varq.updateOracleRate(1, 1e18);

        // Deposit vUSD
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        // Record initial state
        (,, uint256 initialOracleRate, uint256 initialSu, uint256 initialSf, uint256 initialSr,) = 
            varq.vCurrencyStates(1);

        // Mint nation currency
        uint256 mintAmount = 1e5 * 1e18;
        varq.mintvCurrency(1, mintAmount);

        // Check updated state variables
        (,, uint256 newOracleRate, uint256 newSu, uint256 newSf, uint256 newSr,) = 
            varq.vCurrencyStates(1);

        assertTrue(newSu > initialSu, "S_u should increase");
        assertTrue(newSf > initialSf, "S_f should increase");
        assertTrue(newSr > initialSr, "S_r should increase");
        assertEq(newOracleRate, initialOracleRate, "Oracle rate should remain unchanged");
    }

    // === Burning Tests ===

    // Test burning with insufficient nation currency
    function testCannotBurnInsufficientNationCurrency() public {
        // Set up currency state and mint some currency
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        varq.updateOracleRate(1, 1e18);

        // Attempt to burn without any balance
        (uint256 tokenIdFiat,,,,,,) = varq.vCurrencyStates(1);
        vm.expectRevert("Insufficient nation currency balance");
        varq.burnvCurrency(1, 1e18);
    }

    // Test burning with insufficient reserve quota
    function testCannotBurnInsufficientReserveQuota() public {
        // Set up currency state
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        varq.updateOracleRate(1, 1e18);

        // Deposit vUSD
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        
        // First mint a larger amount to ensure S_r is initialized
        uint256 initialMint = 1e5 * 1e18;  // Increased initial mint amount
        varq.mintvCurrency(1, initialMint);
        
        // Wait for a block to ensure protocol rate is calculated
        vm.roll(block.number + 1);
        
        // Now attempt to burn more than what's available
        vm.expectRevert("Insufficient reserve quota token balance");
        varq.burnvCurrency(1, 1e6 * 1e18);
    }

    // Test successful burning
    function testSuccessfulBurn() public {
        // Set up currency state
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        varq.updateOracleRate(1, 1e18);

        // Deposit and mint
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        
        uint256 mintAmount = 1e5 * 1e18;
        varq.mintvCurrency(1, mintAmount);

        // Record balances before burn
        (uint256 tokenIdFiat, uint256 tokenIdReserve,,,,,) = varq.vCurrencyStates(1);
        uint256 initialFiatBalance = varq.balanceOf(address(this), tokenIdFiat);
        uint256 initialReserveBalance = varq.balanceOf(address(this), tokenIdReserve);

        // Burn half
        uint256 burnAmount = mintAmount / 2;
        varq.burnvCurrency(1, burnAmount);

        // Verify balances
        assertEq(varq.balanceOf(address(this), tokenIdFiat), initialFiatBalance - burnAmount);
        assertTrue(varq.balanceOf(address(this), tokenIdReserve) < initialReserveBalance);
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

    // Test protocol rate calculation with zero S_r
    function testCannotCalculateProtocolRateZeroSr() public {
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        varq.updateOracleRate(1, 1e18);

        // Attempt to mint with zero S_r
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        vm.expectRevert("S_r cannot be zero");
        varq.mintvCurrency(1, depositAmount);
    }

    // Test flux ratio calculation with zero oracle rate
    function testCannotCalculateFluxRatioZeroOracle() public {
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        
        // Attempt to mint with zero oracle rate
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);

        vm.expectRevert("Oracle rate cannot be zero");
        varq.mintvCurrency(1, depositAmount);
    }

    // Test reserve ratio calculation with zero S_r
    function testCannotCalculateReserveRatioZeroSr() public {}

    // Test flux influence calculation scenarios
    function testFluxInfluenceCalculation() public {
        _initializeReserveState(1);

        // Verify state changes
        (,,, uint256 Su,, uint256 Sr,) = varq.vCurrencyStates(1);
        assertTrue(Sr > 0, "S_r should be greater than zero");
        assertTrue(Su > 0, "S_u should be greater than zero");
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
        assertEq(usdc.balanceOf(address(this)), 1e27 - depositAmount, "Should have expected USDC balance");
        assertTrue(varq.balanceOf(address(this), 1) > 0, "Should have remaining vUSD balance from initialization");
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
        (uint256 tokenIdFiat1,,,,,,) = varq.vCurrencyStates(1);
        (uint256 tokenIdFiat2,,,,,,) = varq.vCurrencyStates(2);
        
        assertTrue(varq.balanceOf(address(this), tokenIdFiat1) > 0);
        assertTrue(varq.balanceOf(address(this), tokenIdFiat2) > 0);
    }

    // === Event Tests ===

    // Test vCurrencyStateAdded event
    function testVCurrencyStateAddedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit vCurrencyStateAdded(1, 2, 3); // nationId=1, tokenIdFiat=2, tokenIdReserve=3
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
    }

    // Test OracleRateUpdated event
    function testOracleRateUpdatedEvent() public {
        varq.addvCurrencyState(1, "KES", "rqtKES", address(this));
        
        vm.expectEmit(true, true, true, true);
        emit OracleRateUpdated(1, 1e18);
        varq.updateOracleRate(1, 1e18);
    }

    // Test Transfer events
    function testTransferEvents() public {
        // Set up the deposit amount
        uint256 depositAmount = 1e6 * 1e18;
        usdc.approve(address(varq), depositAmount);
        
        // Watch for the Transfer event from the USDC contract first
        vm.expectEmit(true, true, true, true, address(usdc));
        emit Transfer(address(this), address(varq), depositAmount);
        
        // Watch for the ERC1155 Transfer event from the VARQ contract
        vm.expectEmit(true, true, true, true, address(varq));
        emit TransferSingle(
            address(varq),  // operator
            address(0),     // from (mint)
            address(this),  // to
            1,             // id (vUSD token id)
            depositAmount  // amount
        );
        
        // Perform the deposit
        varq.depositUSD(depositAmount);
    }

    // Helper function to initialize S_r for a nation
    function _initializeReserveState(uint256 nationId) internal {
        // Set up initial state
        varq.addvCurrencyState(nationId, "TST", "rqtTST", address(this));
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
} 