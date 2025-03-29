// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VFE {
    // State variables (all in 18 decimals)
    uint256 public usdcFees;
    uint256 public feeRate;
    uint256 public usdcSupply;
    uint256 public redemptionSupply;
    uint256 public fiatSupply; // fiatPool + fiatExtra + fiatExternal
    uint256 public redemptionPool; // Internal redemption tokens
    uint256 public fiatPool; // Internal fiat tokens in AMM
    uint256 public fiatExtra; // Internal excess fiat
    uint256 public oracleRate;
    uint256 public fiatExternal; // External fiat tokens (ERC20)
    bool public terminated; // Termination flag

    IERC20 public immutable usdcToken;

    // Fiat token (ERC20-like, for fiatExternal)
    string public fiatName;
    string public fiatSymbol;
    uint8 public constant DECIMALS = 18;
    mapping(address => uint256) public fiatBalances;
    mapping(address => mapping(address => uint256)) public fiatAllowances;
    uint256 public totalFiatSupply; // Tracks fiatExternal

    // LP token state (internal, not ERC20)
    string public lpName = "VFELP";
    string public lpSymbol = "VFELP";
    mapping(address => uint256) public lpBalances;
    uint256 public totalLpSupply;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event LpMinted(address indexed to, uint256 amount);
    event LpBurned(address indexed from, uint256 amount);
    event FeesUpdated(uint256 newFeeRate);
    event ForwardVarqSwap(address indexed user, uint256 uDelta, uint256 fOut);
    event ReverseVarqSwap(address indexed user, uint256 fToBurn, uint256 uOut, uint256 fUnutilized);
    event PoolUpdated(uint256 redemptionPool, uint256 fiatPool);
    event Terminated();

    constructor(
        uint256 uDelta,
        uint256 initOracleRate,
        uint256 initRatio,
        uint256 fee,
        address usdcTokenAddr,
        string memory fiatName_,
        string memory fiatSymbol_
    ) {
        require(usdcTokenAddr != address(0), "Invalid USDC address");
        usdcFees = 0;
        feeRate = fee;
        usdcSupply = 0;
        redemptionSupply = 0;
        fiatSupply = 0;
        redemptionPool = 0;
        fiatPool = 0;
        fiatExtra = 0;
        oracleRate = initOracleRate;
        fiatExternal = 0;
        terminated = false;
        usdcToken = IERC20(usdcTokenAddr);
        fiatName = fiatName_;
        fiatSymbol = fiatSymbol_;
        totalFiatSupply = 0;

        // Initialize with varqForward
        require(usdcToken.transferFrom(msg.sender, address(this), uDelta), "Initial USDC transfer failed");
        uint256 uDeltaPostFee = applyFee(uDelta);
        (uint256 rDelta, uint256 fDelta) = varqForward(uDeltaPostFee);
        redemptionPool = rDelta;
        fiatPool = rDelta * initRatio / 1e18;
        fiatExtra = fDelta - fiatPool;
        fiatSupply = fiatPool + fiatExtra + fiatExternal;

        // Mint initial LP tokens
        uint256 pR = redemptionSupply > 0 ? fiatSupply * 1e18 / redemptionSupply : 0;
        uint256 spotPrice = redemptionPool > 0 ? fiatPool * 1e18 / redemptionPool : 0;
        uint256 denominator = pR + spotPrice;
        uint256 vFiat = denominator > 0 ? 1e18 * 1e18 / denominator : 0;
        uint256 vRedemption = denominator > 0 ? spotPrice * 1e18 / denominator : 0;
        uint256 excessUsdc = usdcSupply > redemptionSupply ? usdcSupply - redemptionSupply : 0;
        totalLpSupply = (redemptionPool * vRedemption / 1e18) + 
                        ((fiatPool + fiatExtra) * vFiat / 1e18) + 
                        usdcFees + excessUsdc;
        lpBalances[msg.sender] = totalLpSupply;
        emit LpMinted(msg.sender, totalLpSupply);

        emit PoolUpdated(redemptionPool, fiatPool);
    }

    modifier nonZero(uint256 value) {
        require(value > 0, "Division by zero");
        _;
    }

    modifier notTerminated() {
        require(!terminated, "VFE is terminated");
        _;
    }

    function applyFee(uint256 uDelta) internal returns (uint256) {
        uint256 uDeltaFee = uDelta * feeRate / 1e18;
        usdcFees += uDeltaFee;
        return uDelta - uDeltaFee;
    }

    function varqForward(uint256 uDeltaPostFee) internal returns (uint256 rDelta, uint256 fDelta) {
        uint256 lambda = _getLambda();
        rDelta = uDeltaPostFee * lambda / 1e18;
        fDelta = uDeltaPostFee * oracleRate / 1e18;
        usdcSupply += uDeltaPostFee;
        redemptionSupply += rDelta;
        fiatSupply += fDelta;
        return (rDelta, fDelta);
    }

    function swapForward(uint256 rDelta) internal returns (uint256 deltaOut) {
        deltaOut = _swapGivenInCalcOut(rDelta, redemptionPool, fiatPool);
        redemptionPool += rDelta;
        fiatPool -= deltaOut;
        emit PoolUpdated(redemptionPool, fiatPool);
        return deltaOut;
    }

    function forwardVarqSwap(uint256 uDelta) external notTerminated returns (uint256 fOut) {
        require(usdcToken.transferFrom(msg.sender, address(this), uDelta), "USDC transfer failed");
        uint256 uDeltaPostFee = applyFee(uDelta);
        (uint256 rDelta, uint256 fDelta) = varqForward(uDeltaPostFee);
        uint256 fSwap = swapForward(rDelta);
        fOut = fDelta + fSwap;
        fiatExternal += fOut;
        fiatSupply = fiatPool + fiatExtra + fiatExternal;
        _mint(msg.sender, fOut);
        emit ForwardVarqSwap(msg.sender, uDelta, fOut);
        return fOut;
    }

    function _swapGivenInCalcOut(uint256 deltaIn, uint256 currentIn, uint256 currentOut) 
        internal pure returns (uint256 deltaOut) 
    {
        require(currentIn > 0 && currentOut > 0, "Invalid pool state");
        deltaOut = currentOut - (currentIn * currentOut / (currentIn + deltaIn));
        return deltaOut;
    }

    function _swapGivenOutCalcIn(uint256 deltaOut, uint256 currentIn, uint256 currentOut) 
        internal pure returns (uint256 deltaIn, uint256 newIn, uint256 newOut) 
    {
        require(currentIn > 0 && currentOut > 0, "Invalid pool state");
        deltaIn = currentIn - (currentIn * currentOut / (currentOut + deltaOut));
        newIn = currentIn - deltaIn;
        newOut = currentOut + deltaOut;
        return (deltaIn, newIn, newOut);
    }

    function swapReverse(uint256 rDelta) internal returns (uint256 deltaIn) {
        (deltaIn,,) = _swapGivenOutCalcIn(rDelta, redemptionPool, fiatPool);
        redemptionPool -= rDelta;
        fiatPool += deltaIn;
        emit PoolUpdated(redemptionPool, fiatPool);
        return deltaIn;
    }

    function varqReverse(uint256 rSwap, uint256 fRemainder) 
        internal returns (uint256 uPrefee, uint256 fUnutilized) 
    {
        uint256 pR = _getProtocolRate();
        uint256 requiredFiat = rSwap * pR / 1e18;
        require(fRemainder >= requiredFiat, "Insufficient fiat to burn");
        fUnutilized = fRemainder - requiredFiat;
        usdcSupply -= rSwap;
        redemptionSupply -= rSwap;
        fiatSupply -= fRemainder;
        fiatExternal -= fRemainder;
        fiatSupply = fiatPool + fiatExtra + fiatExternal;
        uPrefee = rSwap;
        return (uPrefee, fUnutilized);
    }

    function reverseVarqSwap(uint256 fToBurn, uint256 rExpected) 
        external notTerminated returns (uint256 uDeltaPostFee, uint256 fUnutilized) 
    {
        require(fToBurn > 0, "Invalid fToBurn amount");
        require(rExpected > 0 && rExpected <= redemptionPool, "Invalid rExpected amount");
        _burn(msg.sender, fToBurn);
        uint256 fSwap = swapReverse(rExpected);
        uint256 fDelta = fToBurn - fSwap;
        (uint256 uPrefee, fUnutilized) = varqReverse(rExpected, fDelta);
        uDeltaPostFee = applyFee(uPrefee);
        require(usdcToken.transfer(msg.sender, uDeltaPostFee), "USDC transfer failed");
        emit ReverseVarqSwap(msg.sender, fToBurn, uDeltaPostFee, fUnutilized);
        return (uDeltaPostFee, fUnutilized);
    }

    function unwindLp(uint256 lpAmount) external notTerminated returns (uint256 usdcOut) {
        require(lpAmount > 0 && lpAmount <= lpBalances[msg.sender], "Invalid LP amount");
        uint256 fraction = lpAmount * 1e18 / totalLpSupply;

        // Withdraw redemption tokens from pool
        uint256 rWithdraw = fraction * redemptionPool / 1e18;
        redemptionPool -= rWithdraw;

        // Calculate fiat required for varqReverse
        uint256 pR = _getProtocolRate();
        uint256 fRequired = rWithdraw * pR / 1e18;

        // Source fiat from fiatPool and fiatExtra
        uint256 fWithdraw = fraction * fiatPool / 1e18;
        fiatPool -= fWithdraw;
        uint256 fTotal = fWithdraw;
        if (fWithdraw < fRequired && fiatExtra > 0) {
            uint256 fExtraNeeded = fRequired - fWithdraw;
            fExtraNeeded = (fExtraNeeded <= fiatExtra) ? fExtraNeeded : fiatExtra;
            fiatExtra -= fExtraNeeded;
            fTotal += fExtraNeeded;
        }

        if (fTotal < fRequired) {
            terminated = true;
            emit Terminated();
            revert("VFE terminated due to insufficient liquidity");
        }

        // Execute varqReverse
        (uint256 uPrefee, uint256 fUnutilized) = varqReverseInternal(rWithdraw, fTotal);

        // Add additional assets
        uint256 feeShare = fraction * usdcFees / 1e18;
        uint256 excessUsdc = usdcSupply > redemptionSupply ? usdcSupply - redemptionSupply : 0;
        uint256 excessShare = fraction * excessUsdc / 1e18;

        // Total USDC payout (post-fee on uPrefee)
        uint256 uDeltaPostFee = applyFee(uPrefee);
        usdcOut = uDeltaPostFee + feeShare + excessShare;
        usdcFees -= feeShare;
        if (usdcSupply > redemptionSupply) {
            usdcSupply -= excessShare;
        }

        // Burn LP tokens
        lpBalances[msg.sender] -= lpAmount;
        totalLpSupply -= lpAmount;
        emit LpBurned(msg.sender, lpAmount);

        require(usdcToken.transfer(msg.sender, usdcOut), "USDC transfer failed");
        return usdcOut;
    }

    function varqReverseInternal(uint256 rSwap, uint256 fRemainder) 
        internal returns (uint256 uPrefee, uint256 fUnutilized) 
    {
        uint256 pR = _getProtocolRate();
        uint256 requiredFiat = rSwap * pR / 1e18;
        require(fRemainder >= requiredFiat, "Insufficient fiat to burn");
        fUnutilized = fRemainder - requiredFiat;
        usdcSupply -= rSwap;
        redemptionSupply -= rSwap;
        fiatSupply -= fRemainder;
        fiatSupply = fiatPool + fiatExtra + fiatExternal;
        uPrefee = rSwap;
        return (uPrefee, fUnutilized);
    }

    function claimUsdcForLp(uint256 lpAmount) external returns (uint256 usdcOut) {
        require(terminated, "VFE not terminated");
        require(lpAmount > 0 && lpAmount <= lpBalances[msg.sender], "Invalid LP amount");
        uint256 fraction = lpAmount * 1e18 / totalLpSupply;

        uint256 rShare = fraction * redemptionPool / 1e18;
        uint256 fShare = fraction * (fiatPool + fiatExtra) / 1e18;

        uint256 totalUsdcForLp = usdcSupply + usdcFees;
        uint256 totalLpTokens = redemptionSupply + fiatPool + fiatExtra;
        uint256 usdcPerLpToken = totalLpTokens > 0 ? totalUsdcForLp * 1e18 / totalLpTokens : 0;

        usdcOut = (rShare + fShare) * usdcPerLpToken / 1e18;

        redemptionPool -= rShare;
        fiatPool -= (fShare <= fiatPool) ? fShare : fiatPool;
        fiatExtra -= (fShare > fiatPool) ? (fShare - fiatPool) : 0;
        fiatSupply = fiatPool + fiatExtra + fiatExternal;
        redemptionSupply -= rShare;
        if (usdcSupply >= usdcOut) {
            usdcSupply -= usdcOut;
        } else {
            uint256 fromSupply = usdcSupply;
            usdcSupply = 0;
            usdcFees -= (usdcOut - fromSupply);
        }

        lpBalances[msg.sender] -= lpAmount;
        totalLpSupply -= lpAmount;
        emit LpBurned(msg.sender, lpAmount);

        require(usdcToken.transfer(msg.sender, usdcOut), "USDC transfer failed");
        return usdcOut;
    }

    function claimUsdcForFiat(uint256 fiatAmount) external returns (uint256 usdcOut) {
        require(terminated, "VFE not terminated");
        require(fiatAmount > 0 && fiatAmount <= fiatBalances[msg.sender], "Invalid fiat amount");

        uint256 totalUsdcForFiat = usdcSupply;
        uint256 totalFiatTokens = fiatExternal;
        uint256 usdcPerFiatToken = totalFiatTokens > 0 ? totalUsdcForFiat * 1e18 / totalFiatTokens : 0;

        usdcOut = fiatAmount * usdcPerFiatToken / 1e18;

        fiatExternal -= fiatAmount;
        fiatSupply = fiatPool + fiatExtra + fiatExternal;
        _burn(msg.sender, fiatAmount);
        usdcSupply -= (usdcSupply >= usdcOut) ? usdcOut : usdcSupply;

        require(usdcToken.transfer(msg.sender, usdcOut), "USDC transfer failed");
        return usdcOut;
    }

    function _getProtocolRate() internal view returns (uint256) {
        return redemptionSupply > 0 ? fiatSupply * 1e18 / redemptionSupply : 0;
    }

    function _getFluxRatio() internal view returns (uint256) {
        return oracleRate > 0 ? _getProtocolRate() * 1e18 / oracleRate : 0;
    }

    function _getReserveRatio() internal view returns (uint256) {
        return usdcSupply > 0 ? fiatSupply * 1e18 / usdcSupply : 0;
    }

    function _getLambda() internal view returns (uint256) {
        if (usdcSupply == 0) return 1e18;
        uint256 fluxRatio = _getFluxRatio();
        uint256 reserveRatio = _getReserveRatio();
        if (fluxRatio > 1e18 && reserveRatio == 1e18) return 1e18;
        return fluxRatio;
    }

    function calcOptimalR(uint256 fExit) external view returns (uint256 rOptimal) {
        uint256 yF = fiatPool;
        uint256 xR = redemptionPool;
        uint256 pR = _getProtocolRate();
        uint256 a = pR;
        uint256 b = -(fExit + yF + pR * xR / 1e18);
        uint256 c = fExit * xR / 1e18;
        uint256 discriminant = b * b - 4 * a * c;
        if (discriminant == 0 || a == 0) return 0;
        uint256 sqrtDisc = sqrt(discriminant);
        rOptimal = (-b - sqrtDisc) / (2 * a);
        return rOptimal;
    }

    function _mint(address to, internal uint256 amount) {
        require(to != address(0), "Invalid recipient");
        fiatBalances[to] += amount;
        totalFiatSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(fiatBalances[from] >= amount, "Insufficient fiat balance");
        fiatBalances[from] -= amount;
        totalFiatSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ERC20 functions for fiat token
    function balanceOf(address account) external view returns (uint256) {
        return fiatBalances[account];
    }

    function totalSupply() external view returns (uint256) {
        return totalFiatSupply;
    }

    function transfer(address to, uint256 amount) external notTerminated returns (bool) {
        require(to != address(0), "Invalid recipient");
        require(fiatBalances[msg.sender] >= amount, "Insufficient balance");
        fiatBalances[msg.sender] -= amount;
        fiatBalances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external notTerminated returns (bool) {
        fiatAllowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external notTerminated returns (bool) {
        require(fiatBalances[from] >= amount, "Insufficient balance");
        require(fiatAllowances[from][msg.sender] >= amount, "Insufficient allowance");
        fiatBalances[from] -= amount;
        fiatBalances[to] += amount;
        fiatAllowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return fiatAllowances[owner][spender];
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
