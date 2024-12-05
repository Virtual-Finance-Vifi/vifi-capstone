# VARQ Protocol

VARQ is a decentralized protocol for creating and managing virtual currency pairs with reserve quotas. It implements a system of tokenized fiat currencies and their corresponding reserve tokens.

## Core Components

### VARQ.sol
The main contract that handles:
- Creation and management of virtual currency pairs
- Minting and burning of currency tokens
- Oracle rate updates
- USD deposits and withdrawals
- Protocol rate calculations and flux influence

### vTokens.sol
A proxy contract that wraps each token type with ERC20-like functionality:
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
- **ERC20 Compatibility**: All tokens follow standard token interfaces

## Token Types

1. **vUSD**: Base virtual USD token (tokenId: 1)
2. **National Currencies**: Created per nation-state (tokenId: nationId * 2)
3. **Reserve Quota Tokens**: Paired with each national currency (tokenId: nationId * 2 + 1)

## State Management

The protocol maintains several key state variables:
- `S_u`: USD supply
- `S_f`: Fiat currency supply
- `S_r`: Reserve token supply
- Oracle rates
- Token metadata
- Balance and allowance mappings

## Testing

The test suite includes verification of:
- Initial balance checks
- USD deposit functionality
- Currency state management
- Proxy token operations