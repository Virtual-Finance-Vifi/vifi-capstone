# Virtual Finance Protocol (ViFi Protocol):  
## A Modular Decentralized Financial Framework for Virtual Fiat Currencies

### Abstract

The **Virtual Finance Protocol (ViFi Protocol)** is a decentralized framework designed to create and manage “virtual fiat” ecosystems. A central feature is the **Virtual Fiat Environment (VFE)**, which supports the minting and redemption of perpetual instruments representing real-world fiat currencies—such as the **Trinidad and Tobago Dollar (TTD)**—through a carefully orchestrated system of smart contracts. Specifically, the VFE maintains two key tokenized primitives:

- **Reserved Quota ($$R$$)**: A perpetual call option on the protocol’s USD collateral.  
- **Fiat non-USD ($$F$$)**: A tokenized representation of the local currency (e.g., TTD) that can be further wrapped as an ERC-20 token (TTDV).

ViFi organizes these primitives in a modular fashion:
1. **VARQ** (Virtual Access Reserved Quota), which encompasses the **Fiat Quota Supply (FQS)** and **Implicit Derived State (IDS)**.  
2. **VP-AMM** (Virtual Perpetual Automated Market Maker), which mints and burns TTDV.  
3. **Auxiliary Contracts**: A **Virtualizer** for converting USDC $$\leftrightarrow$$ USDV, a **Treasury** to hold collateral, a **Farm** to stake USDV and instantiate VFEs, and a **Stable Swap (CSAMM)** to exchange TTDV with the real-asset token TTDC.

By ensuring an **over-collateralized** structure ($$\omega \geq 1$$), the protocol preserves the stability and redeemability of the minted currency. We provide a comprehensive mathematical framework, outline the smart contracts, and demonstrate the system with a step-by-step numerical example for the TTD-based VFE. The result is a scalable approach for bridging real-world local fiat currencies onto decentralized financial rails.

---

## Table of Contents

1. **Introduction**  
2. **Background and Motivation**  
3. **ViFi Protocol Architecture**  
   3.1. Virtual Fiat Environment (VFE)  
   3.2. Auxiliary Modules: Virtualizer, Treasury, Farm, Stable Swap  
4. **Mathematical Notation and Core Functions**  
5. **Mechanics of Forward Swap and Reverse Swap**  
   5.1. Forward Swap  
   5.2. Reverse Swap Quadratic Derivation  
6. **Example: VFE for Trinidad and Tobago Dollar (TTD)**  
   6.1. Initial Conditions  
   6.2. Step-by-Step Swap Demonstrations  
7. **Discussion: Key Observations and Risks**  
   7.1. Over-Collateralization and $$\omega \ge 1$$  
   7.2. Oracle Rate and Governance  
   7.3. Stability under Market Stress  
   7.4. Potential Extensions (Multi-Fiat, Alternate AMM Curves, etc.)  
8. **Conclusion**  

---

## 1. Introduction

In the rapidly evolving realm of Decentralized Finance (DeFi), stablecoins and their related protocols form the backbone for on-chain liquidity and trading. While popular stablecoins generally peg their value to the U.S. dollar, relatively few address the nuanced needs of local fiat currencies in regions with smaller economies. Such local currencies remain essential for day-to-day commerce in their respective countries, yet are often underserved by mainstream stablecoin projects.

The **Virtual Finance Protocol (ViFi Protocol)** aims to extend the benefits of decentralized finance to local currencies by creating an **on-chain environment** that mirrors the behavior of a given fiat currency—**without** sacrificing the fundamental risk safeguards of over-collateralization and robust issuance/redemption logic. Specifically, ViFi proposes a **Virtual Fiat Environment (VFE)** that interacts with a USD-pegged stablecoin (USDV) and a local fiat token (TTDV for Trinidad and Tobago, or more generally any currency “X”) in a system that enforces:

1. **Over-Collateralization**: The protocol never allows the total “claims” (Reserved Quota, $$R$$) to exceed actual USD collateral staked in the system.  
2. **Modular Architecture**: Each VFE is composed of well-defined submodules, ensuring clarity of responsibilities and minimized attack surfaces.  
3. **Scalability**: Multiple VFEs can be instantiated from a single “Farm” contract, allowing parallel creation of different local fiat ecosystems.

The subsequent sections delve into how each component—VARQ, VP-AMM, Virtualizer, Treasury, Farm, and Stable Swap—collectively enables a robust bridging of USD collateral to local fiat tokens.

---

## 2. Background and Motivation

### 2.1 Existing Fiat-Backed or Synthetic Protocols

- **MakerDAO** introduced an over-collateralized approach to stablecoins (Dai), but predominantly tied to USD.  
- **Synthetix** and **UMA** focus on synthetic derivatives, providing exposure to a range of assets but often require complex collateral and oracle mechanisms to maintain pegs.  
- **Commercial Stablecoins** (like USDC, USDT) are centralized, offering simple redemption in USD but rarely extend trust frameworks to smaller fiat currencies.  

Against this backdrop, **ViFi** stands out by concentrating on local fiat currencies and providing a **call-option** style token ($$R$$) that ensures the system’s solvency even under market stress.

### 2.2 Why Trinidad and Tobago Dollar (TTD)?

Trinidad and Tobago’s economy, while not massive in global terms, is significant in its region. A TTD-pegged system exemplifies how local currencies can be integrated into DeFi. Lessons learned easily translate to other currencies with different USD exchange rates or volatility profiles.

### 2.3 Core Objectives

- **Maintain Redeemability**: Guarantee that the local fiat tokens (TTDV) can convert back to USDV (and ultimately USD) at a predictable rate.  
- **Ensure Over-Collateralization**: Protect the protocol from “runs” by disallowing issuance of $$R$$ beyond the available USDV collateral.  
- **Facilitate Local On/Off-Ramps**: A stable-swap mechanism (CSAMM) allows TTDV to exchange 1:1 with TTDC, which in turn can be tied to regulated custodial holdings of real TTD.

---

## 3. ViFi Protocol Architecture

The ViFi Protocol is composed of multiple smart contracts, each fulfilling a distinct role. Figure 1 (conceptual) would show how these contracts interconnect, with the VFE being the centerpiece.

### 3.1 Virtual Fiat Environment (VFE)

A **VFE** governs a single non-USD currency, in this case TTD. Within it, we have two primary submodules:

1. **VARQ (Virtual Access Reserved Quota)**: Manages the issuance and redemption logic of the perpetual instruments $$R$$ (Reserved Quota) and $$F$$ (Fiat non-USD). Internally, it splits into:
   - **Fiat Quota Supply (FQS)**: Tracks the total USDV collateral $$S_{u,n}$$, total $$R$$ supply $$S_{r,n}$$, total $$F$$ supply $$S_{f,n}$$, and the oracle rate $$O_R$$.  
   - **Implicit Derived State (IDS)**: Computes derived metrics such as $$\phi_n$$, $$\omega_n$$, and the funding rate $$\lambda(\phi_n,\omega_n)$$ used for new issuance.  

2. **VP-AMM (Virtual Perpetual Automated Market Maker)**: Maintains a constant-product pool of $$(R, F)$$. Deposits from VARQ (i.e., newly minted $$R_{i,n}, F_{i,n}$$) partially remain in the AMM, while **excess** $$F$$ is minted to the user in the form of TTDV (ERC-20). Conversely, TTDV redemptions burn $$F$$ (and a corresponding $$R$$) from the pool.

### 3.2 Auxiliary Modules: Virtualizer, Treasury, Farm, Stable Swap

1. **Virtualizer**: On-chain gateway for swapping USDC $$\leftrightarrow$$ USDV.  
2. **Treasury**: Custodian of USDV collateral, may deploy some assets to external yield sources, tracks non-staked vs. staked balances.  
3. **Farm** (sUSDV Vault): Allows users to stake USDV in exchange for sUSDV. The Farm also instantiates new VFEs with dedicated collateral.  
4. **Stable Swap (CSAMM)**: A constant-sum pool enabling near 1:1 exchange between TTDV and TTDC. This 1:1 ratio is crucial if TTDC is directly backed by actual TTD in a centralized or semi-centralized manner.

---

## 4. Mathematical Notation and Core Functions

Below is a **comprehensive table** of the primary symbols used in the ViFi Protocol, formatted in Markdown with LaTeX-style expressions:

| **Symbol**                | **Description**                                                                          | **Component**                   |
|---------------------------|------------------------------------------------------------------------------------------|---------------------------------|
| $$U_{i,n}$$               | USDV input at step $$n$$ (deposited into VARQ / FQS)                                     | VARQ / FQS                      |
| $$S_{u,n}$$               | Supply of USDV reserve in the Farm or a specific VFE at step $$n$$                       | Farm / VARQ / FQS              |
| $$S_{r,n}$$               | Total supply of **Reserved Quota** ($$R$$) at step $$n$$                                 | VARQ / FQS                      |
| $$S_{f,n}$$               | Total supply of **Fiat non-USD** ($$F$$) in system at step $$n$$                         | VARQ / FQS                      |
| $$O_R$$                   | Oracle rate (TTD:USD, e.g. fixed at 7)                                                  | VARQ / FQS                      |
| $$P_{R,n}$$               | Protocol rate, $$P_{R,n} = \frac{S_{f,n}}{S_{r,n}}$$                                     | VARQ / IDS                      |
| $$\phi_n$$                | Flux ratio, $$\phi_n = \frac{P_{R,n}}{O_R}$$                                            | VARQ / IDS                      |
| $$\omega_n$$              | Reserve ratio, $$\omega_n = \frac{S_{u,n}}{S_{r,n}}$$                                   | VARQ / IDS                      |
| $$\lambda(\phi_n, \omega_n)$$ | Funding rate, scales new issuance of $$R$$                                          | VARQ / IDS                      |
| $$R_{i,n}$$               | **Reserved Quota** issued at step $$n$$                                                 | VFE / VP-AMM / VARQ            |
| $$F_{i,n}$$               | **Fiat non-USD** issued at step $$n$$                                                   | VFE / VP-AMM / VARQ            |
| $$X_{R,n}$$               | Reserved Quota ($$R$$) held in the VP-AMM at step $$n$$                                  | VP-AMM                          |
| $$Y_{F,n}$$               | Fiat non-USD ($$F$$) held in the VP-AMM at step $$n$$                                    | VP-AMM                          |
| $$Z_{F,n}$$               | Excess Fiat non-USD ($$F$$) outside VP-AMM (e.g. Farm-held TTDV) at step $$n$$           | VP-AMM                          |
| $$K$$                     | VP-AMM constant product, $$K = X_{R,n} \times Y_{F,n}$$                                  | VP-AMM                          |
| $$F_{s,n}$$               | Fiat non-USD swapped in the AMM (positive in forward swaps, negative in reverse swaps)   | VP-AMM                          |
| $$F_{e,n}$$               | ERC-20 TTDV tokens minted or burned at step $$n$$                                       | VP-AMM                          |
| $$R_{s,n}$$               | Reserved Quota swapped out in a reverse swap                                            | VP-AMM                          |
| $$F_{r,n}$$               | Fiat non-USD redeemed in a reverse swap                                                 | VP-AMM / VARQ                   |
| $$F_{t,n}$$               | Total ERC-20 TTDV tokens minted at step $$n$$                                           | VP-AMM                          |
| $$A_{R,0}$$               | Initial AMM-implied rate, e.g. $$A_{R,0} = \text{PSR} - O_R$$ (can be set to 2)          | VP-AMM                          |
| $$S_{v,n}(\text{id}, \text{addr})$$ | Balance of VToken $$\text{id}$$ for address $$\text{addr}$$ at step $$n$$              | All modules                     |
| $$S_{v,n}(\text{id})$$    | Total supply of VToken $$\text{id}$$ at step $$n$$                                      | All modules                     |
| $$U_{nr,n}$$              | Non-staked USDV reserve in the Treasury                                                 | Treasury                        |
| $$U_{ns,n}$$              | Staked USDV in the Treasury (Farm deposits)                                             |1 Treasury                        |
| $$U_{p,n}$$               | Deployed USDV for yield                                                                 | Treasury                        |
| $$U_{y,n}$$               | Accumulated yield in the Treasury                                                       | Treasury                        |
| $$U_{val,n}$$             | Total Farm value in USDV at step $$n$$                                                  | Farm                            |
| $$T_R$$                   | Total rate, $$T_R = P_{R,n} + A_{R,n}$$ (e.g. could be 9)                                | VP-AMM / Farm                   |
| $$A_{R,n}$$               | AMM-implied rate, $$A_{R,n} = \frac{Y_{F,n}}{X_{R,n}}$$                                 | VP-AMM                          |
| $$U_{fee}$$               | Swap fee in USDV (e.g. 1% of $$\Delta U$$)                                              | VP-AMM                          |
| $$X_{v,n}$$               | TTDV in the Stable Swap at step $$n$$                                                   | Stable Swap                     |
| $$Y_{c,n}$$               | TTDC in the Stable Swap at step $$n$$                                                   | Stable Swap                     |
| $$k_{ss}$$                | Stable Swap constant sum, $$k_{ss} = X_{v,n} + Y_{c,n}$$                                 | Stable Swap                     |
| $$\Delta X_v$$            | TTDV input to the Stable Swap (CSAMM)                                                   | Stable Swap                     |
| $$\Delta Y_c$$            | TTDC output from the Stable Swap                                                        | Stable Swap                     |

Each contract in the system (Virtualizer, Treasury, Farm, VARQ, VP-AMM, and Stable Swap) exposes specific functions for depositing, withdrawing, staking, swapping, or redeeming. These are spelled out in “State Variables, Input Variables, and Function Calls” (not shown here in full detail for brevity).

---

## 5. Mechanics of Forward Swap and Reverse Swap

### 5.1 Forward Swap

A **Forward Swap** begins with a user depositing $$U_{i,n}$$ USDV into the VFE. The process is:

1. **VARQ (FQS)**:
   1. Increases the local store of USDV: $$S_{u,n} \leftarrow S_{u,n-1} + U_{i,n}$$.  
   2. Mints new $$F_{i,n} = U_{i,n}\cdot O_R$$.  
   3. Mints new $$R_{i,n} = U_{i,n}\cdot \lambda(\phi_n,\omega_n)$$.  
2. **VP-AMM**:
   1. Adds $$R_{i,n}$$ to the AMM’s $$R$$-reserve.  
   2. Adjusts $$Y_{F,n}=\frac{K}{X_{R,n}}$$ to maintain the product $$K$$.  
   3. Whatever fraction of $$F$$ does not fit into the AMM pool becomes minted TTDV (i.e., “excess $$F$$” is given to the user as an ERC-20).

Hence, a user exchanging 1 USDV gets $$O_R$$ units of TTD in principle, adjusted by the AMM’s internal state. The system carefully updates $$\omega$$ to ensure $$\omega \ge 1$$.

#### Collateral Constraint

Before finalizing the forward swap, the protocol checks that issuing $$\Delta R$$ would not push $$\omega < 1$$. If it would, the swap is either partially filled or rejected.

### 5.2 Reverse Swap Quadratic Derivation

When a user has TTDV and wants to redeem USDV, the system must perform a **Reverse Swap**:

1. **Burn TTDV** in the VP-AMM, thus removing some $$(R_{s,n}, F_{r,n})$$ from the reserves.  
2. Use that combination of $$(R_{s,n}, F_{r,n})$$ to redeem the underlying USDV in VARQ.  

Because part of the TTDV might convert into $$R_s$$ via the AMM, and part might directly redeem as $$F_r$$ at the protocol rate $$P_{R,n}$$, we set up:

- $$F_{e,n}$$: The total TTDV to be “exited.”  
- $$F_{s,n}$$: The portion used in the AMM to obtain $$R_{s,n}$$.  
- $$F_{r,n} = R_{s,n}\times P_{R,n}$$: The fraction used for direct redemption.

**System of Equations**:

$$
\begin{cases}
F_{e,n} = F_{s,n} + \bigl(R_{s,n}\cdot P_{R,n}\bigr), \\
R_{s,n} = X_{R,n-1} - \dfrac{K}{\,Y_{F,n-1}+F_{s,n}\!}.
\end{cases}
$$

Solving for $$R_{s,n}$$ yields a standard quadratic form in $$R_{s,n}$$. The final formula:

$$
R_{s,n} 
= 
\frac{-b \;\pm\; \sqrt{\,b^2 - 4\,a\,c\,}}{2a},
$$
where $$a=P_{R,n}$$, and $$b,c$$ are derived from the pool’s prior state. One selects the physically valid root (i.e., $$0 \le R_{s,n} \le X_{R,n-1}$$), ensuring the user cannot redeem more $$R$$ than the AMM contains. 

This closed-form approach obviates iterative methods and clarifies how TTDV breaks down into an AMM component $$F_s$$ and a protocol redemption component $$F_r$$.

---

## 6. Example: VFE for Trinidad and Tobago Dollar (TTD)

### 6.1 Initial Conditions

- **Oracle Rate**: $$O_R=7$$ TTD per 1 USD.  
- **AMM-Implied Rate**: For initialization, we assume an initial rate offset $$A_{R,0}=2$$, so total rate $$T_R=9$$.  
- All expansions (Farm, Virtualizer, etc.) are set up with typical starting states: The user can convert USDC to USDV 1:1. The Farm has zero sUSDV initially.

### 6.2 Step-by-Step Swap Demonstrations

Below, we walk through a **seven-step** process involving three participants: Alice, Bob, and Charlie. Each interacts with the system differently—Alice stakes, Bob provides liquidity, and Charlie performs a smaller final conversion.  

1. **$$n=1$$**:  
   - **Alice Converts 300 USDC to 300 USDV** using the Virtualizer.  
   - Treasury’s non-reserve $$U_{nr}$$ grows by 300.  

2. **$$n=2$$**:  
   - **Alice Stakes 100 USDV into sUSDV** via Farm.  
   - The Farm’s internal USDV supply $$\bigl(S_{u,2}\bigr)=100$$, and Alice holds 200 USDV plus 100 sUSDV.  

3. **$$n=3$$**:  
   - **Bob Converts 10 USDC to 10 USDV**.  
   - The Treasury now reflects 310 total USDV in the ecosystem. Bob has 10 USDV.  

4. **$$n=4$$**:  
   - **Bob Stakes 10 USDV plus 90 TTDC** (off-chain or set aside) for potential usage in the soon-to-be-initialized VFE.  
   - Bob effectively signals a 9:1 ratio (TTD:USD), i.e., a Proposed System Rate (PSR) of 9.  

5. **$$n=5$$**:  
   - **Farm Initializes VFE-TTD** with 100 USDV in total (90 from the Farm’s own stash, 10 from Bob’s stake).  
   - **VARQ** (FQS) sees $$U_{i,n}=100$$. It updates $$S_{u}=100$$, mints $$\Delta F=700$$ since $$O_R=7$$, and issues $$\Delta R=100$$ given $$\lambda=1$$.  
   - **VP-AMM** sets up $$(X_R=100, Y_F=200)$$, deriving a constant product $$K=20{,}000$$. Excess $$F=500$$ is minted as TTDV.  
   - **Bob** then converts his 10 USDV at a total rate $$T_R=9$$, receiving 90 TTDV from that 500 minted token pool, leaving 410 TTDV in the Farm’s custody.  
   - **Stable Swap**: Bob pairs his 90 TTDV with 90 TTDC, establishing a 1:1 CSAMM with $$k_{ss}=180$$.  

6. **$$n=6$$**:  
   - **Charlie Converts 1 USDC to 1 USDV**, holding 1 USDV.  

7. **$$n=7$$**:  
   - **Charlie Executes a Forward Swap** of 1 USDV.  
   - **VARQ**: Mints 7 new $$F$$, 1 new $$R$$; updates $$(S_{f},S_{r})$$.  
   - **VP-AMM**: Adjusts $$(X_{R}=101, Y_{F}\approx198.02)$$, yielding about 1.98 TTDV from the AMM plus 7 from minted fiat, giving ~8.98 TTDV total to Charlie.  
   - **Stable Swap**: Charlie swaps 8.98 TTDV for ~8.98 TTDC in the CSAMM.

All final state variables align with the system’s invariants, demonstrating correct creation and redemption of TTDV. 

---

## 7. Discussion: Key Observations and Risks

### 7.1 Over-Collateralization and $$\omega \ge 1$$

A fundamental design constraint is that the system enforces:

$$
\omega = \frac{S_{u,n}}{S_{r,n}} \;\ge\; 1.
$$

This prevents the supply of $$R$$ (the call options on USD collateral) from ever surpassing actual USD stablecoins in that environment. As a result, a user holding $$R$$ can always rely on redeeming it for an equivalent slice of the underlying USDV. This mechanism is akin to a “no fractional reserve” principle.

### 7.2 Oracle Rate and Governance

Throughout the example, we assume a constant oracle rate $$O_R=7$$. In a live system, TTD:USD might fluctuate. The protocol needs:

1. **Timely Oracle Feeds**: Possibly from Chainlink or a decentralized aggregator.  
2. **Governance Mechanism**: A DAO or multi-signature approach that can update $$O_R$$ or tweak $$\lambda$$ if market conditions change drastically.  

### 7.3 Stability under Market Stress

- **VP-AMM Liquidity**: If TTDV is widely traded, the AMM can handle moderate volume. Large trades might cause high slippage, especially if the pool is shallow.  
- **CSAMM Vulnerability**: A constant-sum pool is efficient for small trades near 1:1 but can be quickly depleted by large imbalances if, say, TTD experiences external volatility.  
- **Potential for Black Swans**: If the value of USDC or USDV breaks its peg, or if TTD hyperinflates, the protocol still holds the nominal amounts. Over-collateralization mitigates some but not all systemic risks.

### 7.4 Potential Extensions (Multi-Fiat, Alternate AMM Curves, etc.)

- **Multiple VFEs**: The Farm can spawn separate VFEs for Jamaican Dollar, Barbadian Dollar, etc., each with its own oracle rate, liquidity pool, and stable-swap.  
- **More Advanced AMMs**: Instead of a simple $$x\cdot y=K$$ approach, stable-swap style invariants (like Curve’s) could provide deeper liquidity near the peg, improving user experience.  
- **Dynamic $$\lambda(\phi,\omega)$$**: The piecewise definition can be replaced by a smoother function or a more intricate mechanism that updates in real time based on liquidity and volatility.

---

## 8. Conclusion

The **Virtual Finance Protocol (ViFi Protocol)** provides a robust, modular solution for bringing local fiat currencies onto decentralized finance rails. By dividing tasks among clearly defined smart contracts—**VARQ (FQS + IDS)**, **VP-AMM**, **Virtualizer**, **Treasury**, **Farm**, and **Stable Swap**—the protocol ensures:

1. **Over-collateralized** issuance of fiat tokens ($$F$$ $$\rightarrow$$ TTDV).  
2. A **call-option** style design for $$R$$, guaranteeing no undercollateralization event can arise under normal conditions.  
3. An **automated market maker** that simplifies liquidity provisioning and TTDV minting.  
4. A **constant-sum** stable swap for near 1:1 conversions between TTDV and TTDC.  

The numerical example with Alice, Bob, and Charlie highlights the real flows of capital, demonstrating how multiple participants can stake, instantiate a new VFE, provide liquidity, or simply swap small amounts of TTDV. The final result is a blueprint for replicating stable, local-currency-pegged ecosystems across DeFi, scalable to numerous fiat currencies. 

Looking forward, further research might explore advanced governance models, on-chain insurance for black-swan events, or expansions to yield-bearing strategies in the Treasury that maintain robust pegging. Ultimately, ViFi underscores a path to bridging real-world local currencies with the decentralized, permissionless innovations that define the DeFi landscape.

---

### References

1. **MakerDAO**: “The Dai Stablecoin System,” *Whitepaper*, 2017.  
2. **Uniswap**: “A Constant-Product Market Maker Model,” *Whitepaper*, 2018.  
3. **Curve Finance**: “StableSwap Invariant,” 2020.  
4. **Synthetix**: “Synthetix: A Protocol for Synthetic Assets,” Technical Documentation, 2019.  

*(Additional references, footnotes, or appendices can be included as needed.)*

---

## Appendix: Extended Equations and Quadratic Details

For completeness, we restate the core **Reverse Swap** system:

$$
\begin{aligned}
F_{e} &= F_s + \bigl(R_s \cdot P_R\bigr), \\
R_s &= X_{R} - \frac{K}{\,Y_F + F_s\,}.
\end{aligned}
$$

Combining and rearranging yields a **quadratic** in $$R_s$$. By standard polynomial manipulation $$(a R_s^2 + b R_s + c = 0)$$, we obtain:

$$
R_s = \frac{-\,b \;\pm\; \sqrt{b^2 - 4 a c}}{2 a}.
$$

The choice of root ensures $$0 \le R_s \le X_R$$. Once $$R_s$$ is determined, $$F_s$$ follows from:

$$
\begin{aligned}
F_s &= (Y_F + F_s) - Y_F \\
    &= \frac{K}{X_R - R_s} \;-\; Y_F,
\end{aligned}
$$

and 
$$
F_r = R_s \cdot P_R.
$$

This approach elegantly handles partial splits between direct redemption and AMM swaps, guaranteeing self-consistent token accounting.

---
