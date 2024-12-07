// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "@uniswap/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "@uniswap/contracts/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/contracts/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/contracts/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/contracts/types/BalanceDelta.sol";
import {LPFeeLibrary} from "@uniswap/contracts/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/contracts/libraries/hooks/BeforeSwapDelta.sol";