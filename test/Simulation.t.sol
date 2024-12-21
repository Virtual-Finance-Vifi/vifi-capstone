// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {FluxAdjFeesHook} from "../src/FluxAdjFeesHook.sol";
import {VARQ} from "../src/VARQ.sol";
import {IVARQ} from "../src/interfaces/IVARQ.sol";
import {vTokens} from "../src/vTokens.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {IvTokens} from "../src/interfaces/IvTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

contract Simulation is Test, Deployers {
    VARQ public varq;
    MockUSDC public usdc;
    FluxAdjFeesHook public hook;
    vTokens public vUSD;
    vTokens public vKES;
    vTokens public vRQT_KES;

    // Test variables
    uint256 public constant INITIAL_USDC_SUPPLY = 1000000000 * 1e18;
    uint256 public constant ONE_MILLION_USDC = 1000000 * 1e18;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public david = address(0x4);
    address public ender = address(0x5);

    // Q64.96 fixed-point number for sqrt price at 1:1
    uint160 constant SQRT_RATIO_1_1 = 79228162514264337593543950336;

    function setUp() public {
        // Only do basic setup here
        usdc = new MockUSDC();
        varq = new VARQ(address(this), address(usdc));
        vUSD = vTokens(varq.tokenProxies(1));

        deployFreshManagerAndRouters();

        // Deploy hook
        address hookAddress = address(
            uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG)
        );
        vm.txGasPrice(10 gwei);
        deployCodeTo(
            "FluxAdjFeesHook.sol",
            abi.encode(address(manager), address(varq)),
            hookAddress
        );
        hook = FluxAdjFeesHook(hookAddress);

        usdc.transfer(alice, ONE_MILLION_USDC * 2);
        usdc.transfer(bob, ONE_MILLION_USDC * 3);
        usdc.transfer(charlie, ONE_MILLION_USDC * 1);
        usdc.transfer(david, ONE_MILLION_USDC * 2);
        usdc.transfer(ender, ONE_MILLION_USDC * 2);

        depositUSD(alice, usdc.balanceOf(alice));
        depositUSD(bob, usdc.balanceOf(bob));
        depositUSD(charlie, usdc.balanceOf(charlie));
        depositUSD(david, usdc.balanceOf(david));
        depositUSD(ender, usdc.balanceOf(ender));

        // Setup KES
        varq.addvCurrencyState("KES", "KES_Reserve", address(this));
        varq.updateOracleRate(1, 128e18);
        vKES = vTokens(varq.tokenProxies(3));
        vRQT_KES = vTokens(varq.tokenProxies(2));
    }

    function test_VARQSetup() public {
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(1);
        assertEq(state.oracleRate, 128e18);
        assertEq(state.oracleUpdater, address(this));
    }

    function test_mintvRQT() public {
        // First ensure oracle rate is set
        varq.updateOracleRate(1, 128e18); // Set some rate

        // Add debug logs
        console.log("vKES address:", address(vKES));
        console.log("vRQT_KES address:", address(vRQT_KES));
        console.log("VARQ address:", address(varq));
        console.log("Alice address:", alice);

        uint256 aliceBalance = vUSD.balanceOf(alice);
        console.log("Alice vUSD balance:", aliceBalance);

        vm.prank(alice);
        vUSD.approve(address(varq), aliceBalance);
        vm.prank(alice);
        varq.mintvCurrency(1, aliceBalance);

        // Add more debug logs
        console.log(
            "Alice vRQT_KES balance after mint:",
            vRQT_KES.balanceOf(alice)
        );

        assertEq(vRQT_KES.balanceOf(alice), aliceBalance);
    }

    function test_PoolInitialization() public {
        // First setup tokens
        varq.addvCurrencyState("KES", "KES_Reserve", address(this));
        varq.updateOracleRate(1, 128e18);
        usdc.approve(address(varq), INITIAL_USDC_SUPPLY);
        varq.depositUSD(1000e18);
        varq.mintvCurrency(1, 1000e18);

        // Get token info
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(1);
        IVARQ.vTokenMetadata memory fiatToken = varq.tokenMetadatas(
            state.tokenIdFiat
        );
        IVARQ.vTokenMetadata memory reserveToken = varq.tokenMetadatas(
            state.tokenIdReserve
        );

        // Get vToken proxy addresses
        address vRQTProxy = varq
            .tokenMetadatas(state.tokenIdReserve)
            .proxyAddress;
        address vKESProxy = varq.tokenMetadatas(state.tokenIdFiat).proxyAddress;

        // Initialize pool with vRQT as token0
        (key, ) = initPool(
            Currency.wrap(vRQTProxy), // vRQT as currency0
            Currency.wrap(vKESProxy), // vKES as currency1
            IHooks(hook),
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            SQRT_RATIO_1_1
        );

        // Verify pool initialization
        assertTrue(Currency.unwrap(key.currency0) != address(0));
        assertTrue(Currency.unwrap(key.currency1) != address(0));
    }

    function test_SetupTokens() public {
        // Test the initial token setup
        test_PoolInitialization();

        // Get token info
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(1);

        // Verify initial balances
        uint256 fiatBalance = varq.balanceOf(address(this), state.tokenIdFiat);
        uint256 reserveBalance = varq.balanceOf(
            address(this),
            state.tokenIdReserve
        );

        assertEq(fiatBalance, 128000 ether); // 128,000 tokens
        assertEq(reserveBalance, 1000 ether); // 1,000 tokens
    }

    function test_ApproveTokens() public {
        // Run setup first
        test_SetupTokens();

        // Get token info
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(1);

        // Get vToken proxy addresses
        address vRQTProxy = varq
            .tokenMetadatas(state.tokenIdReserve)
            .proxyAddress;
        address vKESProxy = varq.tokenMetadatas(state.tokenIdFiat).proxyAddress;

        // Log balances and ownership info
        console.log("=== Before Approve ===");
        console.log("Test contract address:", address(this));
        console.log(
            "vKES balance:",
            varq.balanceOf(address(this), state.tokenIdFiat)
        );
        console.log(
            "vRQT balance:",
            varq.balanceOf(address(this), state.tokenIdReserve)
        );
        console.log("vKES proxy:", vKESProxy);
        console.log("vRQT proxy:", vRQTProxy);
        console.log("Router address:", address(modifyLiquidityRouter));

        // Test contract (owner of tokens) approves router through the IvTokens interface
        IvTokens(vKESProxy).approve(
            address(modifyLiquidityRouter),
            type(uint256).max
        );
        IvTokens(vRQTProxy).approve(
            address(modifyLiquidityRouter),
            type(uint256).max
        );

        // Verify approvals through the IvTokens interface
        assertEq(
            IvTokens(vKESProxy).allowance(
                address(this),
                address(modifyLiquidityRouter)
            ),
            type(uint256).max
        );
        assertEq(
            IvTokens(vRQTProxy).allowance(
                address(this),
                address(modifyLiquidityRouter)
            ),
            type(uint256).max
        );
    }

    // Helper function to handle USDC deposits
    function depositUSD(address user, uint256 amount) internal {
        vm.prank(user);
        usdc.approve(address(varq), amount);

        vm.expectEmit(true, true, false, false);
        emit IERC20.Transfer(user, address(varq), amount);

        vm.prank(user);
        varq.depositUSD(amount);
    }

    function test_AddLiquidity() public {
        // Run setup first
        test_PoolInitialization();

        // Get token info
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(1);

        // Get vToken proxy addresses
        address vKESProxy = varq.tokenMetadatas(state.tokenIdFiat).proxyAddress;
        address vRQTProxy = varq
            .tokenMetadatas(state.tokenIdReserve)
            .proxyAddress;

        // Call approve on VARQ directly for these specific token IDs
        varq.approve(vKESProxy, state.tokenIdFiat, type(uint256).max);
        varq.approve(vRQTProxy, state.tokenIdReserve, type(uint256).max);

        // Now approve the router through the proxies
        IvTokens(vKESProxy).approve(
            address(modifyLiquidityRouter),
            type(uint256).max
        );
        IvTokens(vRQTProxy).approve(
            address(modifyLiquidityRouter),
            type(uint256).max
        );

        // Verify approvals
        console.log(
            "vKES approval:",
            IvTokens(vKESProxy).allowance(
                address(this),
                address(modifyLiquidityRouter)
            )
        );
        console.log(
            "vRQT approval:",
            IvTokens(vRQTProxy).allowance(
                address(this),
                address(modifyLiquidityRouter)
            )
        );

        // Calculate tick range prices
        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

        // Calculate liquidity based on the amount of reserve token we want to add
        uint256 reserveTokenAmount = 100 ether; // Start with 100 tokens
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount1(
            sqrtPriceAtTickLower,
            sqrtPriceAtTickUpper,
            reserveTokenAmount
        );

        // Calculate how much fiat token this liquidity amount requires
        uint256 fiatTokenAmount = LiquidityAmounts.getAmount0ForLiquidity(
            sqrtPriceAtTickLower,
            sqrtPriceAtTickUpper,
            liquidityDelta
        );

        console.log("Liquidity delta:", liquidityDelta);
        console.log("Fiat token required:", fiatTokenAmount);
        console.log("Reserve token required:", reserveTokenAmount);

        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }),
            Constants.ZERO_BYTES
        );
    }

    function test_TransferExcessTokens() public {
        // Run setup first
        test_PoolInitialization();

        // Get token info
        IVARQ.vCurrencyState memory state = varq.vCurrencyStates(1);

        // Verify initial balance
        uint256 initialBalance = varq.balanceOf(
            address(this),
            state.tokenIdFiat
        );
        console.log("Initial fiat token balance:", initialBalance);

        // Transfer 127,000 tokens to a different address
        uint256 transferAmount = 127000 ether;
        address recipient = address(0xdead); // Or any other address you prefer

        varq.transferFrom(
            address(this),
            recipient,
            state.tokenIdFiat,
            transferAmount
        );

        // Verify new balance
        uint256 newBalance = varq.balanceOf(address(this), state.tokenIdFiat);
        console.log("New fiat token balance:", newBalance);

        // Should now have 1,000 tokens left
        assertEq(newBalance, 1000 ether);
    }
}
