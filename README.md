# VARQ Protocol

VARQ is a decentralized protocol for creating and managing virtual currency pairs with reserve quotas. It implements a system of tokenized fiat currencies and their corresponding reserve tokens, along with AMM functionality and yield generation.

## Core Components

### VARQ.sol
The main contract that handles:
- Creation and management of virtual currency pairs
- Minting and burning of currency tokens
- Oracle rate updates
- USD deposits and withdrawals
- Protocol rate calculations and flux influence
- AMM functionality with constant product formula
- Yield generation and distribution
- LP token management and locking
- vCurrency genesis and termination mechanisms

### vTokens.sol
A proxy contract that wraps each token type with ERC6909-like functionality:
- Standard token interface (name, symbol, decimals)
- Balance checking
- Transfer operations
- Approval mechanisms

### IVARQToken.sol
Interface defining core token functionality for balance checking and supply calculation.

## Key Features

- **Multi-Currency Support**: Each nation-state can have its own virtual currency pair
- **Oracle Integration**: External price feeds can update exchange rates
- **Reserve Mechanism**: Implements a reserve quota system with flux ratio calculations
- **USDC Integration**: Uses USDC as the base deposit currency
- **ERC6909 Compatibility**: All tokens follow standard token interfaces
- **Automated Market Maker**: Uniswap V2-style AMM for each currency pair
- **Yield Generation**: 10% APY on RQT in AMM pools
- **Liquidity Management**: 30-day lock period for LP tokens with yield accrual

## Token Types

1. **vUSD**: Base virtual USD token (tokenId: 1)
2. **National Currencies**: Created per nation-state (tokenId: nationId * 2)
3. **Reserve Quota Tokens**: Paired with each national currency (tokenId: nationId * 2 + 1)
4. **LP Tokens**: Represents locked liquidity positions in AMM pools

## vCurrency Lifecycle

### Genesis
- Proposal system requiring 10k vUSD minimum stake
- Community-driven initial ratio setting
- 10M vUSD threshold for activation
- Automatic AMM pool creation and initial liquidity

### Operation
- AMM-based price discovery
- Yield generation for LP providers
- Oracle-based rate updates
- Continuous liquidity provision with 30-day lock

### Termination
- Triggered when reserves fall below 10%
- Orderly unwinding of positions
- Direct vUSD claims based on final rates

## Yield Mechanism

- 10% APY on RQT in AMM pools
- Continuous accrual based on time and stake
- Claimed as vUSD during LP withdrawal
- Pro-rated based on lock duration

## State Management

The protocol maintains several key state variables:
- `S_u`: USD supply
- `S_f`: Fiat currency supply
- `S_r`: Reserve token supply
- Oracle rates
- Token metadata
- Balance and allowance mappings
- AMM pool states
- LP positions and locks
- Yield accumulation data

## Testing

The test suite includes verification of:
- Initial balance checks
- USD deposit functionality
- Currency state management
- Proxy token operations
- AMM functionality
- Yield calculations
- LP token locking and unlocking
- Genesis and termination processes

## Security Features

- Minimum liquidity requirements
- LP token transfer restrictions during lock period
- Oracle manipulation protection
- Termination safety mechanisms