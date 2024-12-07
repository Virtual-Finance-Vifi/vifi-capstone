# VARQ Protocol Example: TTD Implementation

This walkthrough demonstrates the VARQ protocol handling the Trinidad and Tobago Dollar (TTD), showing how the system manages currency state, minting, and rate changes.

## 1. Initial Currency Setup

First, we create a new currency state for TTD:
```
varq.addvCurrencyState("TTD", "rqtTTD", oracleUpdater);
//Creates:
// - vTTD (ID: 2)
// - vRQT_TTD (ID: 3)
```

Set the initial oracle rate (1 USD = 6.8 TTD):

varq.updateOracleRate(1, 6.8e18);


## 2. First User: 1M USD Deposit

User deposits 1M USDC and receives vUSD:
```
varq.depositUSD(1_000_000e18); // Receives 1M vUSD (ID: 1)
```
Mint TTD with 1M vUSD:
```
varq.mintvCurrency(1, 1_000_000e18);
```
### State After First Mint

   - S_u (USD Supply): 1,000,000
   - S_f (TTD Supply): 6,800,000 (1M 6.8)
   - S_r (Reserve Supply): 1,000,000
   - Protocol Rate: 6.8 (S_f/S_r)
   - User Receives:
   - 6.8M vTTD (ID: 2)
   - 1M vRQT_TTD (ID: 3)


## 3. Oracle Rate Update

Oracle rate changes from 6.8 to 6.9:
```
varq.updateOracleRate(1, 6.9e18);
```
### State After Rate Change


### State After Rate Change
Protocol Rate: 6.8 (unchanged)
Oracle Rate: 6.9 (new)


## 4. Second User: 500k USD Deposit

New user deposits 500k USDC:
```
varq.depositUSD(500_000e18); // Receives 500k vUSD (ID: 1)
```
Mint TTD with 500k vUSD:
```
varq.mintvCurrency(1, 500_000e18);
```

### Calculations Before Second Mint

   - Protocol Rate: 6.8
   - Oracle Rate: 6.9
   - Flux Ratio: 0.985 (6.8/6.9)
   - Flux Influence: 0.985 (reserve ratio = 1)

### State After Second Mint

   - S_u: 1,500,000 (1M + 500k)
   - S_f: 10,250,000 (6.8M + [500k 6.9])
   - S_r: 1,492,500 (1M + [500k 0.985])
   - Protocol Rate: 6.87 (10.25M/1.4925M)
   - Second User Receives:
   - 3.45M vTTD (500k 6.9)
   - 492.5k vRQT_TTD (500k 0.985)


## Key System Behaviors

1. **Initial Minting**
   - Sets baseline protocol rate
   - Establishes 1:1 reserve ratio

2. **Rate Change Response**
   - New mints use updated oracle rate (6.9)
   - Protocol rate adjusts gradually
   - Reserve token minting reduced by flux influence

3. **System Stability**
   - Protocol rate moves from 6.8 to 6.87
   - Reserve ratio maintains close to 1
   - Smooth handling of rate changes

This example demonstrates VARQ's ability to:
- Handle real-world currency scenarios
- Maintain stability during rate changes
- Provide predictable token outputs
- Balance flexibility with stability
