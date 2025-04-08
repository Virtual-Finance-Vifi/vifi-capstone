# System Components

## VFE (Virtual Fiat Environment) Contract
### Core Structures

1. VARQ Structure (Virtual Access Reserved Quota)
   ```solidity
   struct VARQ {
       uint256 usdcSupplyDeployed;    // Total USDC deposited into system
       uint256 fiatTokensSupply;       // Total fiat tokens in circulation
       uint256 redemptionTokensSupply; // Total redemption tokens issued
       uint256 oracleRate;            // Current exchange rate from oracle
   }
   ```

### State Variables
```solidity
struct VARQ {
    uint256 usdcSupplyDeployed;    // Total USDC deposited into system
    uint256 fiatTokensSupply;       // Total fiat tokens in circulation
    uint256 redemptionTokensSupply; // Total redemption tokens issued
    uint256 oracleRate;            // Current exchange rate from oracle
}

struct AMM {
    uint256 redemptionPool;  // Amount of redemption tokens in pool
    uint256 fiatPool;        // Amount of fiat tokens in pool
}

uint256 public fiatExternal;  // Tracks all fiat tokens issued to users
uint256 public fiatExtra;     // Excess fiat tokens not in pool or external
IFiatToken public fiatToken;  // ERC20 fiat token contract

uint256 public feeRate;      // Fee rate in basis points (e.g., 30 = 0.3%)
uint256 public usdcFees;     // Accumulated USDC fees
uint256 private constant PRECISION = 10000;  // For basis point calculations
```

### VARQ Expansion Mechanism
```solidity
function varqExpansion(uint256 uDeltaPostFee) internal returns (uint256 rDelta, uint256 fDelta) {
    // For each USDC deposited (after fees):
    // 1. Create 1:1 redemption tokens
    rDelta = uDeltaPostFee;
    
    // 2. Create fiat tokens based on oracle rate
    fDelta = uDeltaPostFee * oracleRate;
    
    // 3. Update system totals
    varq.usdcSupplyDeployed += uDeltaPostFee;
    varq.redemptionTokensSupply += rDelta;
    varq.fiatTokensSupply += fDelta;
    
    return (rDelta, fDelta);
}
```

### VARQ Contraction Mechanism
```solidity
function varqContraction(
    uint256 rSwap,
    uint256 fRemainder
) internal returns (uint256 uPrefee, uint256 fUnutilized) {
    // Get price ratio P_R = fiatSupply / redemptionSupply
    uint256 pR = (varq.fiatTokensSupply * PRECISION) / varq.redemptionTokensSupply;
    
    // Calculate required fiat tokens to burn (rSwap * P_R)
    uint256 fBurn = (rSwap * pR) / PRECISION;
    
    // Check if enough fiat tokens available
    require(fRemainder >= fBurn, "Insufficient fiat tokens for burn");
    
    // Update system totals
    varq.usdcSupplyDeployed -= rSwap;
    varq.redemptionTokensSupply -= rSwap;
    varq.fiatTokensSupply -= fBurn;
    
    // Calculate unutilized fiat tokens
    fUnutilized = fRemainder - fBurn;
    uPrefee = rSwap;
    
    return (uPrefee, fUnutilized);
}
```

### Key Relationships
- VARQ tracks all system-wide token quantities and rates
- AMM tracks the pool balances for both token types
- System invariants:
  * usdcSupplyDeployed = fiatTokensSupply + redemptionTokensSupply
  * redemptionPool ≤ redemptionTokensSupply
  * fiatPool ≤ fiatTokensSupply
  * For deposit amount delta_u: fee = (delta_u * feeRate) / 10000
  * usdcFees accumulates all collected fees
- Total fiat token allocation:
  * fiatTokensSupply = fiatPool + fiatExternal + fiatExtra
  * fiatExtra holds excess tokens that couldn't be LP'd
  * fiatExtra can be used for future LP operations

## Token Contracts
1. USDC Integration
   - Standard ERC20 interface for USDC token interaction
   - Used for deposits/withdrawals only
   - Decimals: 6
   - Fees collected on deposits

2. Fiat Tokens
   - ERC20-compliant
   - Backed by portion of usdcSupplyDeployed (after fees)
   - 1:1 peg target with corresponding fiat currency
   - Amount in pool tracked by fiatPool

3. Redemption Tokens
   - None ERC20-compliant (Exist only within the Smart Contract)
   - Represents reserve pool allocation
   - Amount in pool tracked by redemptionPool

## Pool Mechanics
- Single trading pair between redemption and fiat tokens
- Pool balances tracked separately in AMM struct
- Enables monitoring of available liquidity for each token type

## AMM Swap Mechanics

### Core Functions
```solidity
function swapGivenInCalcOut(
    uint256 deltaIn,      // Amount of token X going in
    uint256 currentIn,    // Current balance of token X
    uint256 currentOut    // Current balance of token Y
) internal pure returns (uint256 deltaOut) {
    // Generic swap calculation that works for either direction:
    // X->Y or Y->X (redemption<->fiat)
    // Formula: deltaOut = currentOut - ((currentIn * currentOut) / (currentIn + deltaIn))
    
    uint256 numerator = currentIn * currentOut;
    uint256 denominator = currentIn + deltaIn;
    deltaOut = currentOut - (numerator / denominator);
    
    return deltaOut;
}

function swapGivenOutCalcIn(
    uint256 deltaOut,     // Desired amount of token Y out
    uint256 currentIn,    // Current balance of token X
    uint256 currentOut    // Current balance of token Y
) internal pure returns (
    uint256 deltaIn,      // Required amount of token X in
    uint256 newIn,        // New balance of token X
    uint256 newOut        // New balance of token Y
) {
    // Generic swap calculation that works for either direction:
    // X->Y or Y->X (redemption<->fiat)
    // Formula: deltaIn = currentIn - ((currentIn * currentOut) / (currentOut + deltaOut))
    
    uint256 numerator = currentIn * currentOut;
    uint256 denominator = currentOut + deltaOut;
    deltaIn = currentIn - (numerator / denominator);
    
    newIn = currentIn - deltaIn;
    newOut = currentOut + deltaOut;
    
    return (deltaIn, newIn, newOut);
}
```

### Key Relationships
- Functions are token-agnostic and work symmetrically for:
  * redemption -> fiat swaps
  * fiat -> redemption swaps
- Constant Product Formula: x * y = k
  * Works identically regardless of which token is X or Y
  * Maintains k constant after swap in either direction

### Usage Examples
1. Redemption -> Fiat swap:
   ```solidity
   deltaOut = swapGivenInCalcOut(
       redemptionIn,      // deltaIn
       redemptionPool,    // currentIn
       fiatPool          // currentOut
   );
   ```

2. Fiat -> Redemption swap:
   ```solidity
   deltaOut = swapGivenInCalcOut(
       fiatIn,           // deltaIn
       fiatPool,        // currentIn
       redemptionPool    // currentOut
   );
   ```

### Implementation Notes
- Functions are symmetric and token-agnostic
- Same formulas work for both swap directions
- All calculations maintain constant product invariant
- Division rounds down by default

### Combined Operations

```solidity
function ExpansionSwap(uint256 uDelta) external returns (uint256 fOut) {
    // 1. Apply fee to incoming USDC
    uint256 uDeltaPostFee = applyFee(uDelta);
    
    // 2. Expand VARQ system with USDC
    (uint256 rDelta, uint256 fDelta) = varqExpansion(uDeltaPostFee);
    
    // 3. Swap redemption tokens for additional fiat tokens
    uint256 fSwap = swapForward(rDelta);
    
    // 4. Combine fiat tokens from expansion and swap
    fOut = fDelta + fSwap;
    
    // 5. Update external fiat token tracking
    fiatExternal += fOut;
    
    // If not all fiat tokens can be LP'd or issued
    // store excess in fiatExtra for future use
    if (someTokensCantBeLPd) {
        fiatExtra += excessAmount;
    }
    
    return fOut;
}

function ContractionSwap(
    uint256 fToBurn,
    uint256 rExpected
) external returns (uint256 uDeltaPostFee) {
    // 1. Validate burn amount against external balance
    if (fToBurn > fiatExternal) {
        fToBurn = fiatExternal;
    }
    
    // 2. If rExpected not specified, use fToBurn as estimate
    if (rExpected == 0) {
        rExpected = fToBurn;
    }
    
    // 3. Swap fiat tokens for redemption tokens
    uint256 fSwap = swapReverse(rExpected);
    
    // 4. Calculate remaining fiat tokens for VARQ contraction
    uint256 fDelta = fToBurn - fSwap;
    
    // 5. Contract VARQ system
    (uint256 uPrefee, uint256 fUnutilized) = varqContraction(rExpected, fDelta);
    
    // 6. Apply fee to outgoing USDC
    uDeltaPostFee = applyFee(uPrefee);
    
    // Can use fiatExtra if needed for pool operations
    if (needExtraTokens) {
        uint256 amount = min(fiatExtra, neededAmount);
        fiatExtra -= amount;
        // Use tokens from fiatExtra
    }
    
    return uDeltaPostFee;
}
```

### Key Relationships
- ExpansionSwap combines:
  1. Fee application
  2. VARQ expansion
  3. AMM swap
  4. External balance tracking

- ContractionSwap combines:
  1. Balance validation
  2. AMM swap
  3. VARQ contraction
  4. Fee application

### Implementation Notes
- VARQ and AMM operations are encapsulated within VFE
- Operations must be performed in specific order
- External access only through these combined functions
- Maintains system invariants across both subsystems

### System Invariants
- Token accounting must always balance:
  * fiatTokensSupply = fiatPool + fiatExternal + fiatExtra
  * All fiat tokens exist in one of three places:
    1. In the AMM pool (fiatPool)
    2. Issued to users (fiatExternal)
    3. Held in reserve (fiatExtra)

### Fee Management

```solidity
// Admin function to update fee rate
function updateFee(uint256 newFeeRate) external onlyOwner {
    require(newFeeRate <= 1000, "Fee rate cannot exceed 10%");  // Max 10% fee
    feeRate = newFeeRate;
}

// Internal function to apply fee and update fee accumulator
function applyFee(uint256 uDelta) internal returns (uint256 uDeltaPostFee) {
    // Calculate fee amount: (uDelta * feeRate) / 10000
    uint256 feeAmount = (uDelta * feeRate) / PRECISION;
    
    // Update accumulated fees
    usdcFees += feeAmount;
    
    // Return amount after fee deduction
    return uDelta - feeAmount;
}
```

### Key Relationships
- Fee calculation:
  * Fee amount = (deposit amount * fee rate) / 10000
  * Example: 30 basis points = 0.3% = 30/10000
- System invariants:
  * usdcFees accumulates all collected fees
  * feeRate is expressed in basis points (1-10000)
  * Maximum fee rate is capped at 10% (1000 basis points)

### Usage in Operations
```solidity
function ExpansionSwap(uint256 uDelta) external returns (uint256 fOut) {
    // 1. Apply fee to incoming USDC
    uint256 uDeltaPostFee = applyFee(uDelta);
    
    // ... rest of expansion logic ...
}

function ContractionSwap(
    uint256 fToBurn,
    uint256 rExpected
) external returns (uint256 uDeltaPostFee) {
    // ... contraction logic ...
    
    // Apply fee before returning USDC
    uDeltaPostFee = applyFee(uPrefee);
    
    return uDeltaPostFee;
}
```

## VFE Factory Contract

### Initialization Parameters
```solidity
struct VFEInitParams {
    uint256 uDelta;              // Total USDC staked to create VFE
    uint256 uDeltaForFiat;       // Amount to convert for first user
    uint256 initOracleRate;      // Initial oracle rate
    uint256 initRatio;           // Initial pool ratio
    uint256 feeRate;            // Initial fee rate in basis points
    address initialLP;           // Address of initial liquidity provider
    address initialFP;           // Address of initial first participant
}
```

### Factory Creation Function
```solidity
function createVFE(VFEInitParams memory params) external returns (address) {
    // 1. Deploy new VFE instance
    VFE vfe = new VFE();
    
    // 2. Initialize core state variables
    vfe.initialize(
        usdcFees = 0,
        feeRate = params.feeRate,
        usdcSupply = 0,
        redemptionSupply = 0,
        fiatSupply = 0,
        redemptionPool = 0,
        fiatPool = 0,
        fiatExtra = 0,
        oracleRate = params.initOracleRate,
        fiatExternal = 0
    );
    
    // 3. Perform initial VARQ expansion
    (uint256 rDelta, uint256 fDelta) = vfe.varqExpansion(params.uDelta);
    
    // 4. Calculate initial token distributions
    uint256 externalFiat = params.uDeltaForFiat * (params.initOracleRate + params.initRatio);
    uint256 yToSet = rDelta * params.initRatio;
    uint256 extraFiat = fDelta - yToSet - externalFiat;
    
    // 5. Set initial pool and token states
    vfe.setInitialState({
        initialLP: params.initialLP,      // Address of initial LP
        redemptionPool: rDelta,           // All redemption tokens go to pool
        fiatPool: yToSet,                 // Initial fiat tokens in pool
        fiatExtra: extraFiat,             // Extra fiat tokens held in reserve
        fiatExternal: externalFiat        // Fiat tokens for first user
    });
    
    // 6. Create initial LP position
    vfe.initializeLPPosition(
        params.initialLP,
        rDelta,      // All redemption tokens
        yToSet,      // Initial fiat pool
        extraFiat    // Extra fiat tokens
    );
    
    // 7. Mint initial fiat tokens to first participant
    vfe.initializeFirstParticipant(
        params.initialFP,
        externalFiat    // Fiat tokens for first user based on uDeltaForFiat
    );
    
    return address(vfe);
}
```

### VFE Initialize Function
```solidity
function initialize(
    uint256 _feeRate,
    uint256 _oracleRate,
    // ... other params
) external initializer {
    require(msg.sender == factory, "Only factory can initialize");
    
    // Initialize all state variables
    feeRate = _feeRate;
    oracleRate = _oracleRate;
    // ... initialize other variables
}

function setInitialState(
    uint256 _redemptionPool,
    uint256 _fiatPool,
    uint256 _fiatExtra,
    uint256 _fiatExternal
) external {
    require(msg.sender == factory, "Only factory can set state");
    
    // Set initial pool states
    redemptionPool = _redemptionPool;
    fiatPool = _fiatPool;
    fiatExtra = _fiatExtra;
    fiatExternal = _fiatExternal;
}
```

### Key Relationships
- Factory creates new VFE instance with:
  * Initial USDC stake (uDelta)
  * First user allocation (uDeltaForFiat)
  * Initial oracle rate and pool ratio
  * Initial fee rate

- Initial token distribution:
  * redemptionPool = rDelta
  * fiatPool = rDelta * initRatio
  * fiatExternal = uDeltaForFiat * (oracleRate + initRatio)
  * fiatExtra = remaining fiat tokens

### Implementation Notes
- Factory is the only address that can initialize VFE
- All initial states are set atomically
- Uses proxy pattern for upgradeable contracts
- Ensures proper initialization of all components

### LP Tracking Structure

```solidity
// Structure to track individual LP positions
struct LPPosition {
    uint256 redemptionTokensAddedToPool;  // Redemption tokens provided to pool
    uint256 fiatTokensAddedToPool;        // Fiat tokens provided to pool
    uint256 fiatTokensAddedExtra;         // Extra fiat tokens held in reserve
}

// State variable to track all LP positions
mapping(address => LPPosition) public lpPositions;

// Events for LP tracking
event LPPositionUpdated(
    address indexed provider,
    uint256 redemptionTokensAdded,
    uint256 fiatTokensAdded,
    uint256 fiatTokensExtra
);
```

### LP Management Functions
```solidity
function addLiquidity(
    uint256 redemptionAmount,
    uint256 fiatAmount,
    uint256 fiatExtra
) external {
    // Update LP position
    LPPosition storage position = lpPositions[msg.sender];
    position.redemptionTokensAddedToPool += redemptionAmount;
    position.fiatTokensAddedToPool += fiatAmount;
    position.fiatTokensAddedExtra += fiatExtra;
    
    // Update pool totals
    redemptionPool += redemptionAmount;
    fiatPool += fiatAmount;
    fiatExtra += fiatExtra;
    
    emit LPPositionUpdated(
        msg.sender,
        position.redemptionTokensAddedToPool,
        position.fiatTokensAddedToPool,
        position.fiatTokensAddedExtra
    );
}

function removeLiquidity(
    uint256 redemptionAmount,
    uint256 fiatAmount,
    uint256 fiatExtra
) external {
    LPPosition storage position = lpPositions[msg.sender];
    
    // Verify sufficient position
    require(position.redemptionTokensAddedToPool >= redemptionAmount, "Insufficient redemption tokens");
    require(position.fiatTokensAddedToPool >= fiatAmount, "Insufficient fiat tokens");
    require(position.fiatTokensAddedExtra >= fiatExtra, "Insufficient extra fiat tokens");
    
    // Update LP position
    position.redemptionTokensAddedToPool -= redemptionAmount;
    position.fiatTokensAddedToPool -= fiatAmount;
    position.fiatTokensAddedExtra -= fiatExtra;
    
    // Update pool totals
    redemptionPool -= redemptionAmount;
    fiatPool -= fiatAmount;
    fiatExtra -= fiatExtra;
    
    emit LPPositionUpdated(
        msg.sender,
        position.redemptionTokensAddedToPool,
        position.fiatTokensAddedToPool,
        position.fiatTokensAddedExtra
    );
}

function getLPPosition(address provider) external view returns (
    uint256 redemptionTokens,
    uint256 fiatTokens,
    uint256 fiatExtra
) {
    LPPosition memory position = lpPositions[provider];
    return (
        position.redemptionTokensAddedToPool,
        position.fiatTokensAddedToPool,
        position.fiatTokensAddedExtra
    );
}
```

### Factory Integration
```solidity
function setInitialState(
    address initialLP,
    uint256 redemptionPool,
    uint256 fiatPool,
    uint256 fiatExtra
) external {
    require(msg.sender == factory, "Only factory can set state");
    
    // Set initial pool states
    redemptionPool = redemptionPool;
    fiatPool = fiatPool;
    fiatExtra = fiatExtra;
    
    // Set initial LP position
    LPPosition storage position = lpPositions[initialLP];
    position.redemptionTokensAddedToPool = redemptionPool;
    position.fiatTokensAddedToPool = fiatPool;
    position.fiatTokensAddedExtra = fiatExtra;
    
    emit LPPositionUpdated(
        initialLP,
        redemptionPool,
        fiatPool,
        fiatExtra
    );
}
```

### VFE LP Initialization
```solidity
function initializeLPPosition(
    address initialLP,
    uint256 redemptionAmount,
    uint256 fiatAmount,
    uint256 fiatExtra
) external {
    require(msg.sender == factory, "Only factory can initialize LP");
    
    // Create initial LP position
    LPPosition storage position = lpPositions[initialLP];
    position.redemptionTokensAddedToPool = redemptionAmount;
    position.fiatTokensAddedToPool = fiatAmount;
    position.fiatTokensAddedExtra = fiatExtra;
    
    emit LPPositionUpdated(
        initialLP,
        redemptionAmount,
        fiatAmount,
        fiatExtra
    );
}
```

### VFE First Participant Initialization
```solidity
function initializeFirstParticipant(
    address initialFP,
    uint256 fiatAmount
) external {
    require(msg.sender == factory, "Only factory can initialize FP");
    
    // Mint initial fiat tokens to first participant
    fiatToken.mint(initialFP, fiatAmount);
    fiatExternal = fiatAmount;
    
    emit FirstParticipantInitialized(
        initialFP,
        fiatAmount
    );
}
```
