// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "@uniswap/v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {IVARQ} from "./interfaces/IVARQ.sol";
import {IvTokens} from "./interfaces/IvTokens.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

contract FluxAdjFeesHook is BaseHook {

    error MustUseDynamicFee();
    error InvalidTokenPair();

    using LPFeeLibrary for uint24;

    uint24 public constant BASE_FEES = 3000;
    uint24 public constant DELTA_FEES = 3000;
    IVARQ public varq;

    constructor(IPoolManager _manager, address _varq) BaseHook(_manager) {
        varq = IVARQ(_varq);
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true, // safety check
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true, // swap fee adjustment
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    ) external pure override returns (bytes4) {
        
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return this.beforeInitialize.selector;
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        bytes calldata
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        bool isForward = swapParams.zeroForOne;
        
        // Convert Currency to address before checking
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        
        // Validate that we're dealing with vTokens
        if (!_isVToken(token0) || !_isVToken(token1)) {
            revert InvalidTokenPair();
        }

        // Get token metadata safely
        IvTokens vtoken = IvTokens(token0);
        uint256 vCurrencyId = vtoken.vCurrencyId();
        
        IVARQ.vCurrencyState memory vCurrencyState = varq.vCurrencyStates(vCurrencyId);

        uint256 protocolRate = _calculateProtocolRate(vCurrencyState.S_f, vCurrencyState.S_r);
        uint256 fluxDiff = calculateFluxDiff(protocolRate, vCurrencyState.oracleRate);
        
        // Calculate dynamic fee
        uint24 fee;
        if (fluxDiff == 0) {
            fee = BASE_FEES;
        } else {
            uint24 feeAdjustment = uint24((uint256(DELTA_FEES) * fluxDiff) / 1e18);
            if (isForward) {
                fee = BASE_FEES - feeAdjustment;  // Lower fee for forward direction
            } else {
                fee = BASE_FEES + feeAdjustment;  // Higher fee for reverse direction
            }
        }
        
        uint24 feeWithFlag = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        return (
            this.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            feeWithFlag
        );
    }

    function _isVToken(address token) internal view returns (bool) {
        try IvTokens(token).parentContract() returns (address parent) {
            return parent == address(varq);
        } catch {
            return false;
        }
    }

    function _calculateProtocolRate(uint256 S_f, uint256 S_r) public pure returns (uint256) {
        require(S_r > 0, "S_r cannot be zero");
        return (S_f * 1e18) / S_r;
    }

    function calculateFluxDiff(uint256 protocolRate, uint256 oracleRate) public pure returns (uint256) {
        uint256 difference;
        if (protocolRate > oracleRate) {
            difference = protocolRate - oracleRate;
        } else {
            difference = oracleRate - protocolRate;
        }

        // Calculate the relative difference as a proportion of oracleRate
        uint256 relativeDifference = (difference * 1e18) / oracleRate;  // This gives us 0.03e18 for 3%

        // k value for sensitivity - dramatically increased
        uint256 k = 241049 * 1e14;  // Increased by 100x again (about 231 billion)

        // Calculate exponent term with better scaling
        uint256 kx = (k * relativeDifference) / 1e18;  // Direct scaling
        
        // Calculate e^(-kx)
        uint256 expKx = approximateExp(kx);

        // Return 1 - e^(-kx)
        return 1e18 - expKx;
    }

    function approximateExp(uint256 x) internal pure returns (uint256) {
        // Start with 1.0
        uint256 result = 1e18;
        
        // Add x term
        result = result - ((x * 1e18) / 1e18);
        
        // Add x^2/2 term
        uint256 term = (x * x) / 1e18;  // x^2
        result = result + ((term * 1e18) / 2) / 1e18;
        
        // Add x^3/6 term
        term = (term * x) / 1e18;  // x^3
        result = result - ((term * 1e18) / 6) / 1e18;
        
        return result;
    }


}

