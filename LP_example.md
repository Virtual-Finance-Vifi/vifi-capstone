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
- **Output:** ~200,000 vKES

### Pool Status After Swap:
- **1,100,000 vRQT**
- **1,800,000 vKES**

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
- **1,100,000 vRQT**
- **1,800,000 vKES**
- **960 vUSD (yield)**

### Alice's Total Holdings After Withdrawal:
- **1,100,000 vRQT**
- **127,800,000 vKES** (126M kept + 1.8M from pool)
- **960 vUSD (yield)**

---

## Conversion Back to vUSD at New Rate (129)

- **Protocol rate remains:** 128
- **vKES (127,800,000)** requires **998,437.5 vRQT**
- Conversion results:
  - **vUSD:** 998,437.5
  - **vRQT:** 101,562.5

---

## Final Position

- **998,960.5 vUSD** (998,437.5 + 960 yield)
- **101,562.5 vRQT**

### Note:
Alice would need another LP to fully exit her position.

---

## Assuming another LP came in

### Pool Ratio:
- **1 vRQT : 2 vKES**

Bob swaps the following:
- **Input:** 25,291.83 vRQT
- **Output:** ~50,583.66 vKES

### Remaining Token:
- **76,270.67 vRQT**
- **9,762,645.91 vKES**

which converted to:
- **76,270.67 vUSD**

Alice total earnings would be:

- **998,437.5 + 76,270.67 vUSD**
- Total vUSD
- **1,074,708.17 vUSD**
