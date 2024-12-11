# ViFi - Decentralized Stablecoin Protocol for Emerging Market Currencies

**Category:** Stablecoin, Foreign Exchange (FX), Emerging Markets, Blockchain

---

## Overview

ViFi is revolutionizing access to FX liquidity for institutional and retail users in Africa and LATAM, addressing the $540B annual market for stablecoins in these regions. By integrating **local stablecoins** with **deep DeFi liquidity**, ViFi ensures users access the **best FX rates at any volume**

For the programme, we undertook a complete redesign of our protocol including integration of **Uniswap Hooks** and **EigenLayer** via Reclaim Protocol. Our protocol dynamically balances FX rates, ensuring price discovery is transparent, decentralized, and highly efficient for frontier markets. The protocol uses the Central Bank rate via an Oracle or EigenLayer AVS as a starting rate and then reprices the FX rate in a free market with our dual token model. By pairing the local stablecoin with a speculative token that functions as a call option on USD, we create a buffer against volatilitty and open up FX arbitrage opportunities.

---

## Hackathon Submission Details

## Links

- **[Demo Video](https://youtu.be/_GI2W6YdQBQ)**
- **[Project Deck](https://docsend.com/view/5zcc88yd4hmnri2y)** (Comprehensive explanation of ViFi’s vision and technical implementation)
- **Key Repositories:**
  - **[ViFi Protocol](https://github.com/Virtual-Finance-Vifi/vifi-capstone)** (Core smart contracts and integrations)
  - **[Reclaim zkFetch dApp](https://github.com/Virtual-Finance-Vifi/cbk-reader)** (On-chain FX rate provisioning via zkProofs)

### **Key Features**

1. **Dynamic Rebalancing via Uniswap Hooks:**

   - Our **beforeSwap hook** dynamically adjusts fees based on protocol state.
   - Central bank FX rate changes trigger protocol rebalancing, ensuring all holders benefit from the most accurate market rates.
   - This approach ties rate adjustments directly to pool activity for optimal efficiency.

2. **Reclaim Protocol with EigenLayer:**

   - Implemented a **proving network** for on-chain FX rates using **zkProofs**.
   - A **zkFetch dApp** fetches daily FX rates from APIs (e.g., Central Bank of Kenya) and provisions this data as an on-chain proof.
   - While still in progress, we've successfully generated and submitted proofs. Verification of proofs is WIP.

3. **Protocol Redesign:**
   - We undertook a redesign of the protocol to now use ERC-6909 to manage the issuance of stablecoins for the local currencies.
   - We've extended the ERC-6909 to support multiple currencies and added a new `KESAttestor` contract to fetch the latest FX rates from the Central Bank of Kenya.

### **Technical Stack**

- **Uniswap Hooks:** BeforeSwap hook
- **Middleware:** EigenLayer, zkProof integrations

## Challenges and Next Steps

1. **Building on bleeding-edge tools:**

   - Integration with Uniswap Hooks, which are still evolving, requires innovative problem-solving to finalize protocol state management.

2. **Future Roadmap:**
   - Complete Reclaim Protocol's zkFetch implementation for production.
   - Launch the redesigned protocol on mainnet by **Q2 2025**.

## Team

- **Varoun Hanooman:** First engineering hire at Doodles, AI - ML PhD candidate
- **Tony Olendo:** DevRel Engineer at Polygon, Yearn vault integrations at Coordinape.
