// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {FluxAdjFeesHook} from "../src/FluxAdjFeesHook.sol";
import {VARQ} from "../src/VARQ.sol";
import {IVARQ} from "../src/interfaces/IVARQ.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

contract FluxAdjFeesTest is Test, Deployers {
    FluxAdjFeesHook public hook;
    VARQ public varq;
    MockERC20 public usdc;
    
    // Test variables
    uint256 public constant INITIAL_USDC_SUPPLY = 1000000 * 1e6;
    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20("USDC", "USDC", 6);
        usdc.mint(alice, INITIAL_USDC_SUPPLY);
        usdc.mint(bob, INITIAL_USDC_SUPPLY);

        // Deploy VARQ
        varq = new VARQ(address(this), address(usdc));

        // Deploy v4-core
        deployFreshManagerAndRouters();

        // Deploy our hook with the proper flags
        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG |
                    Hooks.BEFORE_SWAP_FLAG
            )
        );

        // Deploy FluxAdjFeesHook
        deployCodeTo(
            "FluxAdjFeesHook.sol", 
            abi.encode(address(manager), address(varq)), 
            hookAddress
        );
        hook = FluxAdjFeesHook(hookAddress);
    }

    function test_VARQInitialState() public {
        // Test initial vUSD token (ID 1)
        IVARQ.vTokenMetadata memory vUSDMetadata = varq.tokenMetadatas(1);
        assertEq(vUSDMetadata.name, "vUSD");
        assertEq(vUSDMetadata.symbol, "vUSD");
        assertEq(vUSDMetadata.decimals, 18);
    }

    function test_AddvCurrencyState() public {
        // Add a new vCurrency state
        uint256 currencyId = varq.addvCurrencyState(
            "EUR",
            "EUR_Reserve",
            address(this)
        );

        // Verify the vCurrency state
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(currencyId);
        assertEq(state.tokenIdFiat, 2);
        assertEq(state.tokenIdReserve, 3);
        assertEq(state.oracleUpdater, address(this));
    }

    function test_DepositAndMintFlow() public {
        // Setup
        vm.startPrank(alice);
        usdc.approve(address(varq), INITIAL_USDC_SUPPLY);
        
        // Deposit USDC
        uint256 depositAmount = 1000 * 1e6;
        varq.depositUSD(depositAmount);
        
        // Add vEUR
        vm.stopPrank();
        uint256 currencyId = varq.addvCurrencyState(
            "EUR",
            "EUR_Reserve",
            address(this)
        );
        
        // Set oracle rate (1 EUR = 1.1 USD)
        varq.updateOracleRate(currencyId, 1.1e18);
        
        // Mint vEUR
        vm.startPrank(alice);
        uint256 mintAmount = 100 * 1e18;
        varq.mintvCurrency(currencyId, mintAmount);
        
        // Verify balances
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(currencyId);
        assertEq(varq.balanceOf(alice, state.tokenIdFiat), 110 * 1e18); // 100 USD worth of EUR
        assertEq(varq.balanceOf(alice, state.tokenIdReserve), 100 * 1e18);
        vm.stopPrank();
    }

    function test_HookFeeAdjustment() public {
        // Add vEUR currency
        uint256 currencyId = varq.addvCurrencyState(
            "EUR",
            "EUR_Reserve",
            address(this)
        );
        
        // Set initial oracle rate
        varq.updateOracleRate(currencyId, 1.1e18);
        
        // Get vToken addresses
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(currencyId);
        IVARQ.vTokenMetadata memory fiatToken = varq.tokenMetadatas(state.tokenIdFiat);
        IVARQ.vTokenMetadata memory reserveToken = varq.tokenMetadatas(state.tokenIdReserve);
        
        // Create pool key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(fiatToken.proxyAddress),
            currency1: Currency.wrap(reserveToken.proxyAddress),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: hook
        });

        // Initialize pool
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        // Test that the hook returns the correct fee based on flux difference
        (,, uint24 fee) = hook.beforeSwap(
            address(0),
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 1e18,
                sqrtPriceLimitX96: 0
            }),
            ZERO_BYTES
        );

        // Verify fee is within expected range
        assertTrue(fee > 0);
        assertTrue(fee <= 6000); // Max fee should be BASE_FEE + DELTA_FEE
    }
}