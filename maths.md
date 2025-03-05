Virtual Fiat Environment (VFE): A Decentralized Financial Protocol

Abstract
--------

The Virtual Fiat Environment (VFE) is a decentralized financial protocol designed to manage perpetual instruments—Reserved Quota ($R$, resembling a fiat currency call option) and Fiat non-USD ($F$, a perpetual fiat currency)—via a Constant Product Automated Market Maker (CP AMM). It facilitates forward swaps (issuance of $R$ and $F$ against USD deposits) and reverse swaps (redemption of ERC20 Fiat tokens for USD), maintaining equilibrium through internal and external rate dynamics. This paper presents the mathematical framework, operational logic, and a numerical example spanning initialization and multiple swaps.

1. Introduction
---------------

The VFE operates as an intermediary between external USD inputs and internal liquidity provisioning, leveraging a CP AMM to balance $R$ and $F$. Key features include:
- **Forward Swap**: Deposits USD ($U_{i,n}$) to issue $R$ and $F$, minting ERC20 Fiat ($F_{e,n}$).
- **Reverse Swap**: Redeems ERC20 Fiat ($F_{e,n}$) to unmint $R$ and $F$, withdrawing USD.
- **Liquidity Pool**: Maintains a constant product $K = X_{R,n} \cdot Y_{F,n}$, with excess Fiat tracked separately.

This write-up formalizes the VFE’s mechanics, validated through a numerical example.

2. Notation
-----------

| **Symbol**          | **Description**                                                                 |
|---------------------|---------------------------------------------------------------------------------|
| $U_{i,n}$           | USD input at step $n$ (USDC deposited)                                          |
| $S_{u,n}$           | Supply of USD reserve at step $n$                                               |
| $S_{r,n}$           | Supply of Reserved Quota at step $n$                                            |
| $S_{f,n}$           | Supply of Fiat non-USD in the system at step $n$                                |
| $O_R$               | Oracle rate (external, fixed at 7 in example)                                   |
| $P_{R,n}$           | Protocol rate, $P_{R,n} = \frac{S_{f,n}}{S_{r,n}}$ (internal)                   |
| $\phi_n$            | Flux, $\phi_n = \frac{P_{R,n}}{O_R}$ (rate ratio)                               |
| $\omega_n$          | Reserve ratio, $\omega_n = \frac{S_{u,n}}{S_{r,n}}$                             |
| $\lambda(\phi_n, \omega_n)$ | Funding rate, adjusts issuance                                          |
| $R_{i,n}$           | Reserved Quota issued at step $n$                                               |
| $F_{i,n}$           | Fiat non-USD issued at step $n$                                                 |
| $X_{R,n}$           | Reserved Quota in the AMM at step $n$                                           |
| $Y_{F,n}$           | Fiat non-USD in the AMM at step $n$                                             |
| $Z_{F,n}$           | Excess Fiat non-USD outside AMM at step $n$                                     |
| $K$                 | AMM constant product, $K = X_{R,n} \cdot Y_{F,n}$                               |
| $F_{s,n}$           | Fiat non-USD swapped (positive when removed in forward, added in reverse)       |
| $F_{e,n}$           | Fiat non-USD expressed (minted/burned as ERC20)                                 |
| $R_{s,n}$           | Reserved Quota swapped out in reverse swap                                      |
| $F_{r,n}$           | Fiat non-USD redeemed in reverse swap                                           |
| $F_{t,n}$           | Total ERC20 Fiat minted at step $n$                                             |
| $\text{init_ratio}$ | Initial AMM provisioning ratio (set to 2)                                       |

3. Model Description
--------------------

### 3.1 Initialization

The VFE initializes with a USD deposit $U_{i,0}$, issuing $R$ and $F$ to establish supplies and the AMM:

$S_{u,0} = U_{i,0}, \quad F_{i,0} = U_{i,0} \cdot O_R, \quad R_{i,0} = U_{i,0} \cdot \lambda(\phi_0, \omega_0)$

$S_{r,0} = R_{i,0}, \quad S_{f,0} = F_{i,0}$

$X_{R,0} = R_{i,0}, \quad Y_{F,0} = R_{i,0} \cdot \text{init_ratio}, \quad Z_{F,0} = F_{i,0} - Y_{F,0}$

$F_{t,0} = 0$

$P_{R,0} = \frac{S_{f,0}}{S_{r,0}}, \quad \phi_0 = \frac{P_{R,0}}{O_R}, \quad \omega_0 = \frac{S_{u,0}}{S_{r,0}}$

$\lambda(\phi_0, \omega_0) = \begin{cases} 
1 & \text{if } \phi_0 > 1 \text{ and } \omega_0 = 1 \\ 
\phi_0 & \text{otherwise} 
\end{cases}$

### 3.2 Forward Swap

A forward swap deposits $U_{i,n}$, issuing $R$ and $F$, adjusting the AMM, and minting ERC20 Fiat:

$P_{R,n} = \frac{S_{f,n}}{S_{r,n}}, \quad \phi_n = \frac{P_{R,n}}{O_R}, \quad \omega_n = \frac{S_{u,n}}{S_{r,n}}$

$\lambda(\phi_n, \omega_n) = \begin{cases} 
1 & \text{if } \phi_n > 1 \text{ and } \omega_n = 1 \\ 
\phi_n & \text{otherwise} 
\end{cases}$

$S_{u,n+1} = S_{u,n} + U_{i,n}, \quad F_{i,n} = U_{i,n} \cdot O_R, \quad R_{i,n} = U_{i,n} \cdot \lambda(\phi_n, \omega_n)$

$S_{r,n+1} = S_{r,n} + R_{i,n}, \quad S_{f,n+1} = S_{f,n} + F_{i,n}$

$X_{R,n+1} = X_{R,n} + R_{i,n}, \quad Y_{F,n+1} = \frac{K}{X_{R,n+1}}$

$F_{s,n} = Y_{F,n} - Y_{F,n+1}, \quad F_{e,n} = F_{s,n} + F_{i,n}$

$F_{t,n+1} = F_{t,n} + F_{e,n}, \quad Z_{F,n+1} = Z_{F,n}$

### 3.3 Reverse Swap

A reverse swap redeems $F_{e,n}$ ERC20 Fiat, swapping $F_{s,n}$ into the AMM, unminting $R_{s,n}$ and $F_{r,n}$, and withdrawing USD:

$F_{e,n} = F_{s,n} + F_{r,n}, \quad F_{r,n} = R_{s,n} \cdot P_{R,n}$

$Y'_{F,n+1} = Y_{F,n} + F_{s,n}, \quad X'_{R,n+1} = \frac{K}{Y'_{F,n+1}}, \quad R_{s,n} = X_{R,n} - X'_{R,n+1}$

$P_{R,n} R_{s,n}^2 - (Y_{F,n} + F_{e,n} + P_{R,n} X_{R,n}) R_{s,n} + (Y_{F,n} + F_{e,n}) X_{R,n} - K = 0$

$S_{u,n+1} = S_{u,n} - R_{s,n}, \quad S_{r,n+1} = S_{r,n} - R_{s,n}, \quad S_{f,n+1} = S_{f,n} - F_{r,n}$

$X_{R,n+1} = X_{R,n} - R_{s,n}, \quad Y_{F,n+1} = Y_{F,n} + F_{s,n}$

$F_{t,n+1} = F_{t,n} - F_{e,n}, \quad Z_{F,n+1} = Z_{F,n}$

4. Numerical Example
--------------------

### 4.1 Initialization ($n = 0$)

- **Inputs**: $U_{i,0} = 100$, $O_R = 7$, $\text{init_ratio} = 2$.
- **Supplies**: 
  - $S_{u,0} = 100$, $F_{i,0} = 100 \cdot 7 = 700$, $R_{i,0} = 100 \cdot 1 = 100$.
  - $S_{r,0} = 100$, $S_{f,0} = 700$.
- **LP Position**: 
  - $X_{R,0} = 100$, $Y_{F,0} = 100 \cdot 2 = 200$, $Z_{F,0} = 700 - 200 = 500$, $K = 20,000$.
- **ERC20**: $F_{t,0} = 0$.
- **Rates**: $P_{R,0} = 7$, $\phi_0 = 1$, $\omega_0 = 1$, $\lambda_0 = 1$.

### 4.2 Forward Swap ($n = 0$ to $n = 1$), $U_{i,1} = 10$

- **Supplies**: 
  - $S_{u,1} = 110$, $F_{i,1} = 70$, $R_{i,1} = 10$.
  - $S_{r,1} = 110$, $S_{f,1} = 770$.
- **LP Position**: 
  - $X_{R,1} = 110$, $Y_{F,1} = \frac{20,000}{110} = 181.8182$.
  - $F_{s,1} = 200 - 181.8182 = 18.1818$, $F_{e,1} = 18.1818 + 70 = 88.1818$.
  - $Z_{F,1} = 500$.
- **ERC20**: $F_{t,1} = 0 + 88.1818 = 88.1818$.
- **Rates**: $P_{R,1} = 7$, $\phi_1 = 1$, $\omega_1 = 1$, $\lambda_1 = 1$.

### 4.3 Forward Swap ($n = 1$ to $n = 2$), $U_{i,2} = 10$

- **Supplies**: 
  - $S_{u,2} = 120$, $F_{i,2} = 70$, $R_{i,2} = 10$.
  - $S_{r,2} = 120$, $S_{f,2} = 840$.
- **LP Position**: 
  - $X_{R,2} = 120$, $Y_{F,2} = \frac{20,000}{120} = 166.6667$.
  - $F_{s,2} = 181.8182 - 166.6667 = 15.1515$, $F_{e,2} = 15.1515 + 70 = 85.1515$.
  - $Z_{F,2} = 500$.
- **ERC20**: $F_{t,2} = 88.1818 + 85.1515 = 173.3333$.
- **Rates**: $P_{R,2} = 7$, $\phi_2 = 1$, $\omega_2 = 1$, $\lambda_2 = 1$.

### 4.4 Reverse Swap ($n = 2$ to $n = 3$), $F_{e,3} = 85.1515$

- **Swap Results**: 
  - $F_{s,3} = 15.01965$, $R_{s,3} = 9.9725$, $F_{r,3} = 9.9725 \cdot 7 = 69.8075$.
  - $F_{e,3} = 15.01965 + 69.8075 = 85.1515$.
- **Supplies**: 
  - $S_{u,3} = 120 - 9.9725 = 110.0275$ (9.9725 USDC withdrawn).
  - $S_{r,3} = 120 - 9.9725 = 110.0275$.
  - $S_{f,3} = 840 - 69.8075 = 770.1925$.
- **LP Position**: 
  - $X_{R,3} = 120 - 9.9725 = 110.0275$.
  - $Y_{F,3} = 166.6667 + 15.01965 = 181.68635$.
  - $Z_{F,3} = 500$.
- **ERC20**: $F_{t,3} = 173.3333 - 85.1515 = 88.1818$.
- **Rates**: $P_{R,3} \approx 7$, $\phi_3 = 1$, $\omega_3 = 1$, $\lambda_3 = 1$.

5. Discussion
-------------

The VFE maintains equilibrium ($\phi_n = 1$) across swaps, with $\lambda$ adjusting issuance to protect USD reserves. The reverse swap demonstrates unminting, returning 9.9725 USDC, reflecting the system’s symmetry. Future enhancements could include additional components (e.g., LP adjustments, dynamic $O_R$).

6. Conclusion
-------------

This model provides a robust framework for managing perpetual fiat instruments in a DeFi context, validated through a consistent numerical example. Further components are anticipated to expand its functionality.
