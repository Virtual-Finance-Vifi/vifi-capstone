// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./vTokens.sol";
import "./interfaces/IVARQ.sol";

contract VARQ is Ownable, IVARQ {

    IERC20 public usdcToken;

    mapping(uint256 => vTokenMetadata) private _tokenMetadatas;
    mapping(uint256 => vCurrencyState) private _vCurrencyStates;

    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance;
    mapping(address => mapping(address => bool)) public isOperator;
    mapping(uint256 => address) public tokenProxies;

    // Add counters for both token IDs and nation IDs
    uint256 private nextTokenId = 2;    // Start at 2 since vUSD is token ID 1
    uint256 private nextvCurrencyId = 1;   // Start nation IDs at 1

    // Add these to the VARQ contract

    struct vAMMPool {
        uint256 reserveFiat;    // Reserve of fiat token
        uint256 reserveReserve; // Reserve of reserve token
        uint256 kLast;          // Last K value (reserve0 * reserve1)
    }

    // Mapping to store pool data for each currency
    mapping(uint256 => vAMMPool) public vAMMPools;

    // Minimum liquidity locked forever
    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    // Track liquidity tokens for each provider
    mapping(uint256 => mapping(address => uint256)) public liquidityBalance;
    mapping(uint256 => uint256) public totalLiquidity;

    // Add new structs
    struct vCurrencyPool {
        address uniswapPair;
        uint256 lockEndTime;
        uint256 yieldAccrued;
        bool isTerminated;
        uint256 terminationRate;  // Final redemption rate for vRQT
        uint256 totalLockedVUSD;    // Track total vUSD locked
        mapping(address => LockedLP) userLocks;  // Track individual LP locks
        uint256 lastYieldUpdate;        // Last time yield was updated
        uint256 yieldPerTokenStored;    // Accumulated yield per token
        uint256 totalRQTStaked;         // Total RQT in AMM
        mapping(address => uint256) userYieldPerTokenPaid;  // User's last yield checkpoint
        mapping(address => uint256) yields;                 // Accumulated yields
    }

    // Add new state variables
    mapping(uint256 => vCurrencyPool) public pools;

    // Minimum reserves threshold (10%)
    uint256 public constant MIN_RESERVES_THRESHOLD = 1e17; // 0.1 in 1e18

    // Add new structs
    struct vCurrencyProposal {
        string name;
        string symbol;
        address oracleAddress;
        uint256 totalStaked;
        uint256 proposedRatio;  // weighted average of staker inputs
        uint256 minStakeRequired;  // 10M vUSD
        bool isActive;
        mapping(address => StakeInfo) stakers;
    }

    struct StakeInfo {
        uint256 amountStaked;
        uint256 proposedRatio;
        uint256 timestamp;
    }

    // Add new state variables
    mapping(uint256 => vCurrencyProposal) public proposals;
    uint256 public nextProposalId;
    uint256 public constant MINIMUM_PROPOSAL_STAKE = 10_000 * 1e18; // 10k vUSD
    uint256 public constant MINIMUM_TOTAL_STAKE = 10_000_000 * 1e18; // 10M vUSD

    // New struct for tracking locked LP positions
    struct LockedLP {
        uint256 vusdAmount;         // Original vUSD amount
        uint256 liquidityAmount;    // LP tokens received
        uint256 unlockTime;         // When LP can be withdrawn
        bool claimed;               // Whether LP has been claimed
    }

    // Add new state variable to track stakers per proposal
    mapping(uint256 => address[]) private proposalStakers;

    // Constants for yield calculation
    uint256 private constant APY = 1000;  // 10.00%
    uint256 private constant YIELD_DENOMINATOR = 10000;     // 100.00%
    uint256 private constant SECONDS_PER_YEAR = 31536000;   // 365 days

    constructor(address initialOwner, address _usdcToken) Ownable(initialOwner) {
        usdcToken = IERC20(_usdcToken);
        _createTokenProxy(1, "vUSD", "vUSD", 18, 0);
    }

    function addvCurrencyState(
    string memory _name,
    string memory _reserveName,
    address _oracleUpdater
) external onlyOwner returns (uint256) {
    require(_oracleUpdater != address(0), "Oracle updater cannot be zero address");

    // Deploy reserve token first (this will be currency0)
    bytes32 reserveSalt = keccak256(abi.encodePacked("RESERVE", nextvCurrencyId));
    vTokens reserveToken = new vTokens{salt: reserveSalt}(
        address(this),
        nextTokenId,
        _reserveName,
        string.concat("vRQT_", _name),
        18,
        nextvCurrencyId
    );

    // Store metadata for reserve token
    _tokenMetadatas[nextTokenId] = vTokenMetadata({
        name: _reserveName,
        symbol: string.concat("vRQT_", _name),
        decimals: 18,
        totalSupply: 0,
        proxyAddress: address(reserveToken),
        vCurrencyId: nextvCurrencyId
    });

    // Deploy fiat token second with salt to ensure higher address
    bytes32 fiatSalt = keccak256(abi.encodePacked("FIAT", nextvCurrencyId));
    vTokens fiatToken = new vTokens{salt: fiatSalt}(
        address(this),
        nextTokenId + 1,
        _name,
        string.concat("v", _name),
        18,
        nextvCurrencyId
    );

    // Store metadata for fiat token
    _tokenMetadatas[nextTokenId + 1] = vTokenMetadata({
        name: _name,
        symbol: string.concat("v", _name),
        decimals: 18,
        totalSupply: 0,
        proxyAddress: address(fiatToken),
        vCurrencyId: nextvCurrencyId
    });

    uint256 currencyId = nextvCurrencyId;
    nextvCurrencyId++;

    _vCurrencyStates[currencyId] = vCurrencyState({
        tokenIdFiat: nextTokenId + 1,
        tokenIdReserve: nextTokenId,
        oracleRate: 0,
        S_u: 0,
        S_f: 0,
        S_r: 0,
        oracleUpdater: _oracleUpdater
    });

    emit vCurrencyStateAdded(currencyId, nextTokenId + 1, nextTokenId);

    nextTokenId += 2;

    return currencyId;
}

    function updateOracleRate(uint256 currencyId, uint256 newRate) public {
        vCurrencyState storage nation = _vCurrencyStates[currencyId];
        require(msg.sender == nation.oracleUpdater, "Not authorized to update oracle");
        nation.oracleRate = newRate;
        emit OracleRateUpdated(currencyId, newRate);
    }

    function updateOracleUpdater(uint256 currencyId, address newUpdater) public onlyOwner {
        vCurrencyState storage nation = _vCurrencyStates[currencyId];
        nation.oracleUpdater = newUpdater;
        emit OracleUpdated(newUpdater);
    }

    function mintvCurrency(uint256 currencyId, uint256 amount) public {
        vCurrencyState storage nation = _vCurrencyStates[currencyId];
        require(nation.tokenIdFiat != 0, "Nation-state does not exist");
        require(nation.oracleRate > 0, "Oracle rate cannot be zero");
        require(balanceOf[msg.sender][1] >= amount, "Insufficient vUSD balance");

        _burn(msg.sender, 1, amount);
        uint256 nationAmount = (amount * nation.oracleRate) / 1e18; // Normalize to 18 decimals

        // Handle initial minting case
        if (nation.S_r == 0) {
            // For the first mint, we set initial ratios
            nation.S_u = amount;
            nation.S_f = nationAmount;
            nation.S_r = amount; // Initialize S_r with the full amount
            _mint(msg.sender, nation.tokenIdFiat, nationAmount);
            _mint(msg.sender, nation.tokenIdReserve, amount);
            return;
        }

        uint256 protocolRate = _calculateProtocolRate(nation.S_f, nation.S_r);
        uint256 fluxRatio = _calculateFluxRatio(protocolRate, nation.oracleRate);
        uint256 reserveRatio = _calculateReserveRatio(nation.S_u, nation.S_r);

        uint256 fluxInfluence = _calculateFluxInfluence(fluxRatio, reserveRatio);

        uint256 reserveAmount = (amount * fluxInfluence) / 1e18; // Normalize back to non-decimal amount

        _mint(msg.sender, nation.tokenIdFiat, nationAmount);
        _mint(msg.sender, nation.tokenIdReserve, reserveAmount);

        nation.S_u += amount;
        nation.S_f += nationAmount;
        nation.S_r += reserveAmount;
    }


    function burnvCurrency(uint256 currencyId, uint256 amount) public {
        vCurrencyState storage nation = _vCurrencyStates[currencyId];
        require(nation.tokenIdFiat != 0, "Nation-state does not exist");
        require(balanceOf[msg.sender][nation.tokenIdFiat] >= amount, "Insufficient nation currency balance");

        uint256 protocolRate = _calculateProtocolRate(nation.S_f, nation.S_r);
        uint256 usdAmount = (amount * 1e18) / protocolRate; // Normalize the result

        require(balanceOf[msg.sender][nation.tokenIdReserve] >= usdAmount, "Insufficient reserve quota token balance");
        require(nation.S_u >= usdAmount, "Insufficient S_u supply");

        _burn(msg.sender, nation.tokenIdFiat, amount);
        _burn(msg.sender, nation.tokenIdReserve, usdAmount);

        _mint(msg.sender, 1, usdAmount);

        nation.S_u -= usdAmount;
        nation.S_f -= amount;
        nation.S_r -= usdAmount;
    }

    function depositUSD(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        bool success = usdcToken.transferFrom(msg.sender, address(this), amount);
        require(success, "USDC transfer failed");

        _mint(msg.sender, 1, amount);
    }

    function withdrawUSD(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf[msg.sender][1] >= amount, "Insufficient vUSD balance");

        _burn(msg.sender, 1, amount);
        bool success = usdcToken.transfer(msg.sender, amount);
        require(success, "USDC transfer failed");
    }

    // Returns the protocol rate normalized to 18 decimal places
    function _calculateProtocolRate(uint256 S_f, uint256 S_r) public pure returns (uint256) {
        require(S_r > 0, "S_r cannot be zero");
        return (S_f * 1e18) / S_r;
    }

    // Returns the flux ratio normalized to 18 decimal places
    function _calculateFluxRatio(uint256 protocolRate, uint256 oracleRate) public pure returns (uint256) {
        require(oracleRate > 0, "oracleRate cannot be zero");
        return (protocolRate * 1e18) / oracleRate;
    }

    // Returns the reserve ratio normalized to 18 decimal places
    function _calculateReserveRatio(uint256 S_u, uint256 S_r) public pure returns (uint256) {
        require(S_r > 0, "S_r cannot be zero");
        return (S_u * 1e18) / S_r;
    }

    // Calculates flux influence, taking into account normalization where necessary
    function _calculateFluxInfluence(uint256 fluxRatio, uint256 reserveRatio) public pure returns (uint256) {
        if (fluxRatio > 1e18 && reserveRatio <= 1e18) {
            return 1e18; // normalize to 18 decimal places
        } else {
            return fluxRatio; // already normalized
        }
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

    function _mint(address receiver, uint256 id, uint256 amount) internal {
        _tokenMetadatas[id].totalSupply += amount;
        balanceOf[receiver][id] += amount;
        emit Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function _burn(address sender, uint256 id, uint256 amount) internal {
        require(balanceOf[sender][id] >= amount, "Insufficient balance to burn");
        _tokenMetadatas[id].totalSupply -= amount;
        balanceOf[sender][id] -= amount;
        emit Transfer(msg.sender, sender, address(0), id, amount);
    }

    function _createTokenProxy(uint256 id, string memory name_, string memory symbol_, uint8 decimals_, uint256 vCurrencyId_) internal {
        vTokens proxy = new vTokens(
            address(this), 
            id, 
            name_, 
            symbol_, 
            decimals_,
            vCurrencyId_  // Pass through to constructor
        );
        _tokenMetadatas[id] = vTokenMetadata(name_, symbol_, decimals_, 0, address(proxy), vCurrencyId_);
        tokenProxies[id] = address(proxy);
    }

    function calculateTotalSupply(uint256 tokenId) public view returns (uint256) {
        return _tokenMetadatas[tokenId].totalSupply;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC6909 LOGIC
    //////////////////////////////////////////////////////////////*/

    function transfer(address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender][id] -= amount;
        balanceOf[receiver][id] += amount;
        emit Transfer(msg.sender, msg.sender, receiver, id, amount);
        return true;
    }

    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        if (msg.sender != sender && !isOperator[sender][msg.sender]) {
            uint256 allowed = allowance[sender][msg.sender][id];
            if (allowed != type(uint256).max) allowance[sender][msg.sender][id] = allowed - amount;
        }

        balanceOf[sender][id] -= amount;
        balanceOf[receiver][id] += amount;
        emit Transfer(msg.sender, sender, receiver, id, amount);
        return true;
    }

    function approve(address spender, uint256 id, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender][id] = amount;
        emit Approval(msg.sender, spender, id, amount);
        return true;
    }

    function setOperator(address operator, bool approved) public virtual returns (bool) {
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    // Optional: Add a view function to check the next token ID
    function getNextTokenId() public view returns (uint256) {
        return nextTokenId;
    }

    // Optional: Add view functions to check the next available IDs
    function getNextvCurrencyId() public view returns (uint256) {
        return nextvCurrencyId;
    }

    function tokenMetadatas(uint256 id) external view returns (vTokenMetadata memory) {
        return _tokenMetadatas[id];
    }

    function vCurrencyStates(uint256 currencyId) external view returns (vCurrencyState memory) {
        return _vCurrencyStates[currencyId];
    }

    function getAllowance(address owner, address spender, uint256 id) public view returns (uint256) {
        return allowance[owner][spender][id];
    }

    function approveFor(address owner, address spender, uint256 id, uint256 amount) public returns (bool) {
        // Ensure that only the proxy contract can call this function
        require(msg.sender == _tokenMetadatas[id].proxyAddress, "Only proxy can approve");
        allowance[owner][spender][id] = amount;
        emit Approval(owner, spender, id, amount);
        return true;
    }

    // Add liquidity to the vAMM pool
    function addLiquidity(
        uint256 currencyId,
        uint256 amountFiatDesired,
        uint256 amountReserveDesired,
        uint256 amountFiatMin,
        uint256 amountReserveMin,
        address to
    ) external returns (uint256 amountFiat, uint256 amountReserve, uint256 liquidityMinted) {
        vCurrencyState storage nation = _vCurrencyStates[currencyId];
        vAMMPool storage pool = vAMMPools[currencyId];
        
        // Calculate amounts
        if (pool.reserveFiat == 0 && pool.reserveReserve == 0) {
            amountFiat = amountFiatDesired;
            amountReserve = amountReserveDesired;
            pool.kLast = amountFiat * amountReserve;
        } else {
            uint256 amountReserveOptimal = quote(amountFiatDesired, pool.reserveFiat, pool.reserveReserve);
            if (amountReserveOptimal <= amountReserveDesired) {
                require(amountReserveOptimal >= amountReserveMin, "INSUFFICIENT_RESERVE_AMOUNT");
                amountFiat = amountFiatDesired;
                amountReserve = amountReserveOptimal;
            } else {
                uint256 amountFiatOptimal = quote(amountReserveDesired, pool.reserveReserve, pool.reserveFiat);
                require(amountFiatOptimal <= amountFiatDesired);
                require(amountFiatOptimal >= amountFiatMin, "INSUFFICIENT_FIAT_AMOUNT");
                amountFiat = amountFiatOptimal;
                amountReserve = amountReserveDesired;
            }
        }

        // Calculate liquidity tokens to mint
        uint256 liquidity;
        if (totalLiquidity[currencyId] == 0) {
            liquidity = sqrt(amountFiat * amountReserve) - MINIMUM_LIQUIDITY;
            // Lock minimum liquidity forever
            liquidityBalance[currencyId][address(0)] = MINIMUM_LIQUIDITY;
        } else {
            liquidity = min(
                (amountFiat * totalLiquidity[currencyId]) / pool.reserveFiat,
                (amountReserve * totalLiquidity[currencyId]) / pool.reserveReserve
            );
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        // Update liquidity tracking
        liquidityBalance[currencyId][to] += liquidity;
        totalLiquidity[currencyId] += liquidity;

        // Transfer tokens to pool
        transferFrom(msg.sender, address(this), nation.tokenIdFiat, amountFiat);
        transferFrom(msg.sender, address(this), nation.tokenIdReserve, amountReserve);

        // Update pool reserves
        pool.reserveFiat += amountFiat;
        pool.reserveReserve += amountReserve;
        pool.kLast = pool.reserveFiat * pool.reserveReserve;

        emit LiquidityAdded(currencyId, amountFiat, amountReserve, to);

        return (amountFiat, amountReserve, liquidity);
    }

    // Swap tokens using vAMM
    function swap(
        uint256 currencyId,
        uint256 amountIn,
        uint256 minAmountOut,
        bool isFiatIn,
        address to
    ) external returns (uint256 amountOut) {
        vCurrencyState storage nation = _vCurrencyStates[currencyId];
        vAMMPool storage pool = vAMMPools[currencyId];
        
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(pool.reserveFiat > 0 && pool.reserveReserve > 0, "INSUFFICIENT_LIQUIDITY");

        uint256 reserveIn = isFiatIn ? pool.reserveFiat : pool.reserveReserve;
        uint256 reserveOut = isFiatIn ? pool.reserveReserve : pool.reserveFiat;

        // Calculate amount out using constant product formula
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "INSUFFICIENT_OUTPUT_AMOUNT");

        // Transfer tokens
        uint256 tokenIdIn = isFiatIn ? nation.tokenIdFiat : nation.tokenIdReserve;
        uint256 tokenIdOut = isFiatIn ? nation.tokenIdReserve : nation.tokenIdFiat;

        transferFrom(msg.sender, address(this), tokenIdIn, amountIn);
        transfer(to, tokenIdOut, amountOut);

        // Update reserves
        if (isFiatIn) {
            pool.reserveFiat += amountIn;
            pool.reserveReserve -= amountOut;
        } else {
            pool.reserveReserve += amountIn;
            pool.reserveFiat -= amountOut;
        }

        pool.kLast = pool.reserveFiat * pool.reserveReserve;
        
        emit Swap(currencyId, msg.sender, to, amountIn, amountOut, isFiatIn);
    }

    // Helper functions
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256) {
        require(amountA > 0, "INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "INSUFFICIENT_LIQUIDITY");
        return (amountA * reserveB) / reserveA;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        
        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    // Helper function to calculate square root
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // Helper function to get minimum value
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // Events
    event LiquidityAdded(uint256 indexed currencyId, uint256 amountFiat, uint256 amountReserve, address indexed to);
    event Swap(uint256 indexed currencyId, address indexed sender, address indexed to, uint256 amountIn, uint256 amountOut, bool isFiatIn);
    event LiquidityRemoved(
        uint256 indexed currencyId,
        address indexed provider,
        address indexed to,
        uint256 fiatAmount,
        uint256 reserveAmount,
        uint256 liquidityBurned
    );

    // Add view function to check liquidity
    function getLiquidityBalance(uint256 currencyId, address provider) external view returns (uint256) {
        return liquidityBalance[currencyId][provider];
    }

    // Add view function to check total liquidity
    function getTotalLiquidity(uint256 currencyId) external view returns (uint256) {
        return totalLiquidity[currencyId];
    }

    // Add termination functions
    function checkTerminationConditions(uint256 currencyId) public returns (bool) {
        vCurrencyState storage state = _vCurrencyStates[currencyId];
        vCurrencyPool storage pool = pools[currencyId];
        
        // Check if either vRQT or vFiat reserves are below threshold
        uint256 reserveRatio = _calculateReserveRatio(state.S_f, state.S_r);
        if (reserveRatio < MIN_RESERVES_THRESHOLD) {
            pool.isTerminated = true;
            pool.terminationRate = _calculateTerminationRate(currencyId);
            emit VCurrencyTerminated(currencyId, pool.terminationRate);
            return true;
        }
        return false;
    }

    function claimTerminatedVCurrency(
        uint256 currencyId,
        uint256 amount,
        bool isFiat
    ) external {
        vCurrencyPool storage pool = pools[currencyId];
        require(pool.isTerminated, "Not terminated");
        
        if (isFiat) {
            // Claim vFiat at protocol rate
            uint256 vusdAmount = _calculateVUSDClaim(currencyId, amount, true);
            _burn(msg.sender, _vCurrencyStates[currencyId].tokenIdFiat, amount);
            _mint(msg.sender, 1, vusdAmount);
        } else {
            // Claim vRQT at termination rate
            uint256 vusdAmount = _calculateVUSDClaim(currencyId, amount, false);
            _burn(msg.sender, _vCurrencyStates[currencyId].tokenIdReserve, amount);
            _mint(msg.sender, 1, vusdAmount);
        }
        
        emit VCurrencyClaimed(currencyId, msg.sender, amount, vusdAmount, isFiat);
    }

    // Helper function to calculate termination rate
    function _calculateTerminationRate(uint256 currencyId) internal view returns (uint256) {
        vCurrencyState storage state = _vCurrencyStates[currencyId];
        vAMMPool storage pool = vAMMPools[currencyId];
        
        // Use the last pool ratio as the termination rate
        if (pool.reserveReserve > 0) {
            return (pool.reserveFiat * 1e18) / pool.reserveReserve;
        }
        return 0;
    }

    // Helper function to calculate vUSD claim amount
    function _calculateVUSDClaim(
        uint256 currencyId,
        uint256 amount,
        bool isFiat
    ) internal view returns (uint256) {
        vCurrencyState storage state = _vCurrencyStates[currencyId];
        vCurrencyPool storage pool = pools[currencyId];
        
        if (isFiat) {
            // For vFiat, use protocol rate (S_f/S_r)
            return (amount * state.S_r) / state.S_f;
        } else {
            // For vRQT, use termination rate
            return (amount * pool.terminationRate) / 1e18;
        }
    }

    // Add events
    event VCurrencyTerminated(uint256 indexed currencyId, uint256 terminationRate);
    event VCurrencyClaimed(
        uint256 indexed currencyId,
        address indexed user,
        uint256 amount,
        uint256 vusdAmount,
        bool isFiat
    );

    // Genesis functions
    function proposeVCurrency(
        string memory _name,
        string memory _symbol,
        address _oracleAddress,
        uint256 _proposedRatio,
        uint256 _initialStake
    ) external returns (uint256 proposalId) {
        require(_initialStake >= MINIMUM_PROPOSAL_STAKE, "Insufficient initial stake");
        require(_oracleAddress != address(0), "Invalid oracle address");
        
        proposalId = nextProposalId++;
        vCurrencyProposal storage proposal = proposals[proposalId];
        proposal.name = _name;
        proposal.symbol = _symbol;
        proposal.oracleAddress = _oracleAddress;
        proposal.minStakeRequired = MINIMUM_TOTAL_STAKE;
        proposal.isActive = true;
        
        // Initial stake from proposer
        _stakeForProposal(proposalId, _initialStake, _proposedRatio);
        
        emit VCurrencyProposed(proposalId, _name, _symbol, _oracleAddress);
        return proposalId;
    }

    function _stakeForProposal(
        uint256 proposalId,
        uint256 amount,
        uint256 proposedRatio
    ) internal {
        vCurrencyProposal storage proposal = proposals[proposalId];
        
        // If this is the first time this address is staking in this proposal
        if (proposal.stakers[msg.sender].amountStaked == 0) {
            proposalStakers[proposalId].push(msg.sender);
        }
        
        // Transfer vUSD from staker
        require(balanceOf[msg.sender][1] >= amount, "Insufficient vUSD balance");
        _burn(msg.sender, 1, amount);
        
        // Update staker info
        StakeInfo storage staker = proposal.stakers[msg.sender];
        staker.amountStaked += amount;
        staker.proposedRatio = proposedRatio;
        staker.timestamp = block.timestamp;
        
        // Update total staked and weighted average ratio
        proposal.totalStaked += amount;
        proposal.proposedRatio = _calculateWeightedRatio(proposal);
        
        emit StakedForProposal(proposalId, msg.sender, amount, proposedRatio);
    }

    function stakeForProposal(
        uint256 proposalId,
        uint256 amount,
        uint256 proposedRatio
    ) external {
        require(proposals[proposalId].isActive, "Proposal not active");
        _stakeForProposal(proposalId, amount, proposedRatio);
    }

    function initiateGenesis(uint256 proposalId) external onlyOwner {
        vCurrencyProposal storage proposal = proposals[proposalId];
        require(proposal.isActive, "Proposal not active");
        require(proposal.totalStaked >= proposal.minStakeRequired, "Insufficient stake");
        
        // Create vCurrency pair
        uint256 currencyId = addvCurrencyState(
            proposal.name,
            string.concat("vRQT_", proposal.name),
            proposal.oracleAddress
        );
        
        // Convert staked vUSD to vCurrency pair at weighted average ratio
        uint256 fiatAmount = (proposal.totalStaked * proposal.proposedRatio) / 1e18;
        
        // Initialize AMM pool with converted tokens
        _initializeAMMPool(currencyId, proposal.totalStaked, fiatAmount);
        
        // Set lock period
        pools[currencyId].lockEndTime = block.timestamp + 30 days;
        
        // Deactivate proposal
        proposal.isActive = false;
        
        emit VCurrencyGenesis(currencyId, proposal.totalStaked, fiatAmount);
    }

    function _calculateWeightedRatio(vCurrencyProposal storage proposal) internal view returns (uint256) {
        uint256 weightedSum;
        address[] memory stakers = _getProposalStakers(proposal);
        
        for(uint i = 0; i < stakers.length; i++) {
            StakeInfo storage staker = proposal.stakers[stakers[i]];
            weightedSum += (staker.amountStaked * staker.proposedRatio);
        }
        
        return proposal.totalStaked > 0 ? weightedSum / proposal.totalStaked : 0;
    }

    function _initializeAMMPool(
        uint256 currencyId,
        uint256 reserveAmount,
        uint256 fiatAmount
    ) internal {
        vAMMPool storage pool = vAMMPools[currencyId];
        pool.reserveReserve = reserveAmount;
        pool.reserveFiat = fiatAmount;
        pool.kLast = reserveAmount * fiatAmount;
        
        // Mint initial LP tokens
        uint256 initialLiquidity = sqrt(reserveAmount * fiatAmount);
        liquidityBalance[currencyId][msg.sender] = initialLiquidity - MINIMUM_LIQUIDITY;
        liquidityBalance[currencyId][address(0)] = MINIMUM_LIQUIDITY; // Lock minimum liquidity
        totalLiquidity[currencyId] = initialLiquidity;
    }

    // Add events
    event VCurrencyProposed(
        uint256 indexed proposalId,
        string name,
        string symbol,
        address oracleAddress
    );
    event StakedForProposal(
        uint256 indexed proposalId,
        address indexed staker,
        uint256 amount,
        uint256 proposedRatio
    );
    event VCurrencyGenesis(
        uint256 indexed currencyId,
        uint256 totalStaked,
        uint256 initialFiatAmount
    );

    // Function to deposit vUSD and receive locked LP tokens
    function depositAndLockLP(
        uint256 currencyId,
        uint256 vusdAmount,
        uint256 minFiatOut,
        uint256 minReserveOut
    ) external returns (uint256 liquidityMinted) {
        vCurrencyState storage state = _vCurrencyStates[currencyId];
        vCurrencyPool storage pool = pools[currencyId];
        
        require(!pool.isTerminated, "Pool terminated");
        require(vusdAmount >= 1e18, "Min 1 vUSD required"); // Minimum deposit
        require(balanceOf[msg.sender][1] >= vusdAmount, "Insufficient vUSD");

        // Calculate amounts based on current pool ratio
        vAMMPool storage ammPool = vAMMPools[currencyId];
        uint256 fiatAmount = (vusdAmount * ammPool.reserveFiat) / ammPool.reserveReserve;
        
        // Verify minimum outputs
        require(fiatAmount >= minFiatOut, "Insufficient fiat output");
        require(vusdAmount >= minReserveOut, "Insufficient reserve output");

        // Burn vUSD from sender
        _burn(msg.sender, 1, vusdAmount);

        // Convert vUSD to vCurrency pair
        _mint(address(this), state.tokenIdFiat, fiatAmount);
        _mint(address(this), state.tokenIdReserve, vusdAmount);

        // Add liquidity to AMM
        liquidityMinted = _addLiquidityAndLock(
            currencyId,
            fiatAmount,
            vusdAmount,
            msg.sender
        );

        // Update user's locked position
        LockedLP storage userLock = pool.userLocks[msg.sender];
        userLock.vusdAmount += vusdAmount;
        userLock.liquidityAmount += liquidityMinted;
        userLock.unlockTime = block.timestamp + 30 days;
        
        pool.totalLockedVUSD += vusdAmount;

        emit LPLocked(currencyId, msg.sender, vusdAmount, liquidityMinted);
        return liquidityMinted;
    }

    // Internal function to add liquidity and lock
    function _addLiquidityAndLock(
        uint256 currencyId,
        uint256 fiatAmount,
        uint256 reserveAmount,
        address user
    ) internal returns (uint256 liquidityMinted) {
        vAMMPool storage ammPool = vAMMPools[currencyId];
        vCurrencyPool storage pool = pools[currencyId];
        
        // Update yield before changing stakes
        _updateYield(currencyId);
        
        // Calculate liquidity tokens
        if (ammPool.reserveFiat == 0 && ammPool.reserveReserve == 0) {
            liquidityMinted = sqrt(fiatAmount * reserveAmount) - MINIMUM_LIQUIDITY;
            liquidityBalance[currencyId][address(0)] = MINIMUM_LIQUIDITY;
        } else {
            liquidityMinted = min(
                (fiatAmount * totalLiquidity[currencyId]) / ammPool.reserveFiat,
                (reserveAmount * totalLiquidity[currencyId]) / ammPool.reserveReserve
            );
        }

        require(liquidityMinted > 0, "Insufficient liquidity minted");

        // Update pool reserves
        ammPool.reserveFiat += fiatAmount;
        ammPool.reserveReserve += reserveAmount;
        ammPool.kLast = ammPool.reserveFiat * ammPool.reserveReserve;

        // Update liquidity tracking
        liquidityBalance[currencyId][address(this)] += liquidityMinted;
        totalLiquidity[currencyId] += liquidityMinted;

        // Update RQT tracking for yield
        pool.totalRQTStaked += reserveAmount;
        
        // Initialize user's yield tracking
        pool.userYieldPerTokenPaid[user] = pool.yieldPerTokenStored;
        
        return liquidityMinted;
    }

    // Add yield update function
    function _updateYield(uint256 currencyId) internal {
        vCurrencyPool storage pool = pools[currencyId];
        
        if (block.timestamp > pool.lastYieldUpdate) {
            if (pool.totalRQTStaked > 0) {
                uint256 timeElapsed = block.timestamp - pool.lastYieldUpdate;
                
                // Calculate yield: (APY * timeElapsed * totalRQTStaked) / (SECONDS_PER_YEAR * YIELD_DENOMINATOR)
                uint256 yieldIncrement = (APY * timeElapsed * 1e18) / (SECONDS_PER_YEAR * YIELD_DENOMINATOR);
                pool.yieldPerTokenStored += yieldIncrement;
            }
            pool.lastYieldUpdate = block.timestamp;
        }
    }

    // Add function to calculate earned yield
    function earned(uint256 currencyId, address user) public view returns (uint256) {
        vCurrencyPool storage pool = pools[currencyId];
        LockedLP storage userLock = pool.userLocks[user];
        
        uint256 currentYieldPerToken = pool.yieldPerTokenStored;
        if (block.timestamp > pool.lastYieldUpdate && pool.totalRQTStaked > 0) {
            uint256 timeElapsed = block.timestamp - pool.lastYieldUpdate;
            uint256 yieldIncrement = (APY * timeElapsed * 1e18) / (SECONDS_PER_YEAR * YIELD_DENOMINATOR);
            currentYieldPerToken += yieldIncrement;
        }
        
        return (userLock.liquidityAmount * 
               (currentYieldPerToken - pool.userYieldPerTokenPaid[user]) / 1e18) 
               + pool.yields[user];
    }

    // Function to withdraw locked LP after lock period
    function withdrawLockedLP(uint256 currencyId) external {
        vCurrencyPool storage pool = pools[currencyId];
        LockedLP storage userLock = pool.userLocks[msg.sender];
        
        require(userLock.liquidityAmount > 0, "No locked LP");
        require(!userLock.claimed, "LP already claimed");
        require(block.timestamp >= userLock.unlockTime, "Still locked");

        // Update yield before withdrawal
        _updateYield(currencyId);
        
        // Calculate earned yield
        uint256 yieldEarned = earned(currencyId, msg.sender);
        
        uint256 liquidityAmount = userLock.liquidityAmount;
        userLock.claimed = true;

        // Calculate amounts to return
        vAMMPool storage ammPool = vAMMPools[currencyId];
        uint256 fiatAmount = (liquidityAmount * ammPool.reserveFiat) / totalLiquidity[currencyId];
        uint256 reserveAmount = (liquidityAmount * ammPool.reserveReserve) / totalLiquidity[currencyId];

        // Update pool state
        ammPool.reserveFiat -= fiatAmount;
        ammPool.reserveReserve -= reserveAmount;
        totalLiquidity[currencyId] -= liquidityAmount;
        liquidityBalance[currencyId][address(this)] -= liquidityAmount;

        // Convert back to vUSD and transfer to user
        uint256 vusdReturn = userLock.vusdAmount + yieldEarned;
        _mint(msg.sender, 1, vusdReturn);

        pool.totalLockedVUSD -= userLock.vusdAmount;

        // Mint yield as vUSD
        if (yieldEarned > 0) {
            _mint(msg.sender, 1, yieldEarned);
            pool.yields[msg.sender] = 0;
        }

        // Update user's yield checkpoint
        pool.userYieldPerTokenPaid[msg.sender] = pool.yieldPerTokenStored;
        
        emit LPUnlocked(currencyId, msg.sender, vusdReturn, liquidityAmount);
        emit YieldClaimed(currencyId, msg.sender, yieldEarned);
    }

    // Add events
    event LPLocked(
        uint256 indexed currencyId,
        address indexed user,
        uint256 vusdAmount,
        uint256 liquidityMinted
    );

    event LPUnlocked(
        uint256 indexed currencyId,
        address indexed user,
        uint256 vusdReturned,
        uint256 liquidityBurned
    );

    // Implement the missing helper function
    function _getProposalStakers(uint256 proposalId) internal view returns (address[] memory) {
        return proposalStakers[proposalId];
    }

    // Add new event
    event YieldClaimed(
        uint256 indexed currencyId,
        address indexed user,
        uint256 yieldAmount
    );

    // Add function to prevent LP token transfers during lock
    function transfer(address to, uint256 id, uint256 amount) external override returns (bool) {
        vCurrencyPool storage pool = pools[_tokenMetadatas[id].vCurrencyId];
        LockedLP storage userLock = pool.userLocks[msg.sender];
        
        // If this is an LP token and user has a lock, prevent transfer
        if (userLock.liquidityAmount > 0 && 
            block.timestamp < userLock.unlockTime && 
            !userLock.claimed) {
            revert("LP tokens locked");
        }
        
        return super.transfer(to, id, amount);
    }
}