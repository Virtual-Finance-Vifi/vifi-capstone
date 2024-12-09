# Liquidity Pool and Yield Farming Setup

## Initial Setup (Day 0)

Alice starts with the following assets:
- **1,000,000 vUSD**
- After minting (Oracle Rate: 128):
  - **128,000,000 vKES**
  - **1,000,000 vRQT**

---

## Step 1: Pool Creation with Time Lock

Alice provides liquidity (LOCKED FOR 1 WEEK):
- **1,000,000 vRQT**
- **2,000,000 vKES**

### Pool Ratio:
- **1 vRQT : 2 vKES**

### Alice's Remaining Holdings:
- **126,000,000 vKES**

---

## Step 2: Trading During Lock Period

Bob swaps the following:
- **Input:** 100,000 vRQT
- **Fee:** 3000 vRQT (assuming 0.3%)
- **Output:** 199,400 vKES

### Pool Status After Swap:
- **1,099,700 vRQT**
- **1,800,600 vKES**

---

## Step 3: Oracle Rate Change

- **Rate changes:** 128 → 129

---

## Step 4: Yield Accumulation (1 Week)

### USDM Yield:
- **5% APY** on $1,000,000
- **Weekly yield:** (5% / 52) = ~0.096%
- **Yield:** $1,000,000 × 0.096% = **960 vUSD**

---

## Step 5: Liquidity Withdrawal & Position Close

Alice withdraws from the pool and receives:
- **1,099,700 vRQT**
- **1,800,600 vKES**
- **960 vUSD (yield)**

### Alice's Total Holdings After Withdrawal:
- **1,100,000 vRQT** (1,099,700 vRQT + 3000 vRQT)
- **127,800,600 vKES** (126M kept + 1.8M from pool)
- **960 vUSD (yield)**

---

## Conversion Back to vUSD at New Rate (129)

- **Protocol rate remains:** 128
- **vKES (127,800,600)** requires **998,442.1875 vRQT**
- Conversion results:
  - **vUSD:** 998,442.1875
  - **vRQT:** 101,557.8125

---

## Final Position

- **999,402.1875 vUSD** (998,442.1875 + 960 yield)
- **101,557.8125 vRQT**

### Note:
Alice would need another LP to fully exit her position.

---

## Assuming another LP came in

### Pool Ratio:
- **1 vRQT : 1 vKES** (assuming the spread compressed/unlikely but assuming a unfavourable deal from the new LP)
Alice starting with:
- **vRQT:** 101,557.8125

Alice swaps the following:
- **Input:** 100,770.54 vRQT
- **Output:** ~100,770.54 vKES

### Remaining Token:
- **787.27 vRQT**
- **100,770.54 vKES**

which converted to:
- **787.27 vUSD**

Alice total earnings would be:

- **999,402.1875 + 787.27 vUSD**
- Total vUSD
- **1,000,189.4575 vUSD**
