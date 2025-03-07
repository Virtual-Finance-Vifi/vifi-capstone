Virtual Fiat Environment (VFE): A Modular Decentralized Financial Protocol

Abstract
--------

The Virtual Fiat Environment (VFE) is a decentralized financial protocol managing perpetual instruments—Reserved Quota ($R$, a fiat currency call option) and Fiat non-USD ($F$, a perpetual fiat currency)—through a modular architecture comprising the Fiat Quota Supply (FQS), Virtual Perpetual Automated Market Maker (VP-AMM), and Implicit Derived State (IDS). The FQS tracks core supplies, the VP-AMM manages liquidity, and the IDS computes derived metrics. This paper details the mathematical framework, operational logic, and a numerical example across initialization, forward swaps, and a reverse swap.

1. Introduction
---------------

The VFE facilitates:
- **Forward Swap**: Deposits USD ($U_{i,n}$) to issue $R$ and $F$, minting ERC20 Fiat ($F_{e,n}$).
- **Reverse Swap**: Redeems ERC20 Fiat ($F_{e,n}$) to unmint $R$ and $F$, withdrawing USD.

It is split into:
- **Fiat Quota Supply (FQS)**: Manages $O_R$, $S_{u,n}$, $S_{r,n}$, $S_{f,n}$.
- **Virtual Perpetual Automated Market Maker (VP-AMM)**: Operates $X_{R,n}$, $Y_{F,n}$, $Z_{F,n}$.
- **Implicit Derived State (IDS)**: Computes $P_{R,n}$, $\phi_n$, $\omega_n$, $\lambda(\phi_n, \omega_n)$.

This modular design is validated through a numerical example.

2. Notation
-----------

| **Symbol**          | **Description**                                                                 | **Component** |
|---------------------|---------------------------------------------------------------------------------|----------------|
| $U_{i,n}$           | USD input at step $n$ (USDC deposited)                                          | FQS           |
| $S_{u,n}$           | Supply of USD reserve at step $n$                                               | FQS           |
| $S_{r,n}$           | Supply of Reserved Quota at step $n$                                            | FQS           |
| $S_{f,n}$           | Supply of Fiat non-USD in the system at step $n$                                | FQS           |
| $O_R$               | Oracle rate (external, fixed at 7 in example)                                   | FQS           |
| $P_{R,n}$           | Protocol rate, $P_{R,n} = \frac{S_{f,n}}{S_{r,n}}$                              | IDS           |
| $\phi_n$            | Flux, $\phi_n = \frac{P_{R,n}}{O_R}$                                            | IDS           |
| $\omega_n$          | Reserve ratio, $\omega_n = \frac{S_{u,n}}{S_{r,n}}$                             | IDS           |
| $\lambda(\phi_n, \omega_n)$ | Funding rate, adjusts issuance                                          | IDS           |
| $R_{i,n}$           | Reserved Quota issued at step $n$                                               | VP-AMM/FQS    |
| $F_{i,n}$           | Fiat non-USD issued at step $n$                                                 | VP-AMM/FQS    |
| $X_{R,n}$           | Reserved Quota in the VP-AMM at step $n$                                        | VP-AMM        |
| $Y_{F,n}$           | Fiat non-USD in the VP-AMM at step $n$                                          | VP-AMM        |
| $Z_{F,n}$           | Excess Fiat non-USD outside VP-AMM at step $n$                                  | VP-AMM        |
| $K$                 | VP-AMM constant product, $K = X_{R,n} \cdot Y_{F,n}$                            | VP-AMM        |
| $F_{s,n}$           | Fiat non-USD swapped (positive when removed in forward, added in reverse)       | VP-AMM        |
| $F_{e,n}$           | Fiat non-USD expressed (minted/burned as ERC20)                                 | VP-AMM        |
| $R_{s,n}$           | Reserved Quota swapped out in reverse swap                                      | VP-AMM        |
| $F_{r,n}$           | Fiat non-USD redeemed in reverse swap                                           | VP-AMM/FQS    |
| $F_{t,n}$           | Total ERC20 Fiat minted at step $n$                                             | VP-AMM        |
| $\text{initRatio}$ | Initial VP-AMM provisioning ratio (set to 2)                                    | VP-AMM        |

3. Model Description
--------------------

### 3.1 Fiat Quota Supply (FQS)

The FQS tracks the core supplies and oracle rate:

- **Initialization**:
  $S_{u,0} = U_{i,0}, \quad F_{i,0} = U_{i,0} \cdot O_R, \quad R_{i,0} = U_{i,0} \cdot \lambda(\phi_0, \omega_0)$
  $S_{r,0} = R_{i,0}, \quad S_{f,0} = F_{i,0}$

- **Forward Swap**:
  $S_{u,n+1} = S_{u,n} + U_{i,n}, \quad F_{i,n} = U_{i,n} \cdot O_R, \quad R_{i,n} = U_{i,n} \cdot \lambda(\phi_n, \omega_n)$
  $S_{r,n+1} = S_{r,n} + R_{i,n}, \quad S_{f,n+1} = S_{f,n} + F_{i,n}$

- **Reverse Swap**:
  $S_{u,n+1} = S_{u,n} - R_{s,n}, \quad S_{r,n+1} = S_{r,n} - R_{s,n}, \quad S_{f,n+1} = S_{f,n} - F_{r,n}$

### 3.2 Virtual Perpetual Automated Market Maker (VP-AMM)

The VP-AMM manages the liquidity pool and ERC20 minting:

- **Initialization**:
  $X_{R,0} = R_{i,0}, \quad Y_{F,0} = R_{i,0} \cdot \text{initRatio}, \quad Z_{F,0} = F_{i,0} - Y_{F,0}$
  $F_{t,0} = 0$

- **Forward Swap**:
  $X_{R,n+1} = X_{R,n} + R_{i,n}, \quad Y_{F,n+1} = \frac{K}{X_{R,n+1}}$
  $F_{s,n} = Y_{F,n} - Y_{F,n+1}, \quad F_{e,n} = F_{s,n} + F_{i,n}$
  $F_{t,n+1} = F_{t,n} + F_{e,n}, \quad Z_{F,n+1} = Z_{F,n}$

- **Reverse Swap**:
  $F_{e,n} = F_{s,n} + F_{r,n}, \quad F_{r,n} = R_{s,n} \cdot P_{R,n}$
  $Y_{F,n+1} = Y_{F,n} + F_{s,n}, \quad X_{R,n+1} = \frac{K}{Y_{F,n+1}}$
  $R_{s,n} = X_{R,n} - X_{R,n+1}$
  $P_{R,n} R_{s,n}^2 - (Y_{F,n} + F_{e,n} + P_{R,n} X_{R,n}) R_{s,n} + (Y_{F,n} + F_{e,n}) X_{R,n} - K = 0$
  $F_{t,n+1} = F_{t,n} - F_{e,n}, \quad Z_{F,n+1} = Z_{F,n}$

### 3.3 Implicit Derived State (IDS)

The IDS computes derived metrics:

- **All Steps**:
  $P_{R,n} = \frac{S_{f,n}}{S_{r,n}}, \quad \phi_n = \frac{P_{R,n}}{O_R}, \quad \omega_n = \frac{S_{u,n}}{S_{r,n}}$
  $\lambda(\phi_n, \omega_n) = \begin{cases} 
  1 & \text{if } \phi_n > 1 \text{ and } \omega_n = 1 \\ 
  \phi_n & \text{otherwise} 
  \end{cases}$

4. Numerical Example
--------------------

### 4.1 Initialization ($n = 0$)

- **Inputs**: $U_{i,0} = 100$, $O_R = 7$, $\text{initRatio} = 2$.
- **FQS**: 
  - $S_{u,0} = 100$, $F_{i,0} = 700$, $R_{i,0} = 100$.
  - $S_{r,0} = 100$, $S_{f,0} = 700$.
- **VP-AMM**: 
  - $X_{R,0} = 100$, $Y_{F,0} = 200$, $Z_{F,0} = 500$, $K = 20,000$.
  - $F_{t,0} = 0$.
- **IDS**: $P_{R,0} = 7$, $\phi_0 = 1$, $\omega_0 = 1$, $\lambda_0 = 1$.

### 4.2 Forward Swap ($n = 0$ to $n = 1$), $U_{i,1} = 10$

- **FQS**: 
  - $S_{u,1} = 110$, $F_{i,1} = 70$, $R_{i,1} = 10$.
  - $S_{r,1} = 110$, $S_{f,1} = 770$.
- **VP-AMM**: 
  - $X_{R,1} = 110$, $Y_{F,1} = 181.8182$.
  - $F_{s,1} = 18.1818$, $F_{e,1} = 88.1818$.
  - $F_{t,1} = 88.1818$, $Z_{F,1} = 500$.
- **IDS**: $P_{R,1} = 7$, $\phi_1 = 1$, $\omega_1 = 1$, $\lambda_1 = 1$.

### 4.3 Forward Swap ($n = 1$ to $n = 2$), $U_{i,2} = 10$

- **FQS**: 
  - $S_{u,2} = 120$, $F_{i,2} = 70$, $R_{i,2} = 10$.
  - $S_{r,2} = 120$, $S_{f,2} = 840$.
- **VP-AMM**: 
  - $X_{R,2} = 120$, $Y_{F,2} = 166.6667$.
  - $F_{s,2} = 15.1515$, $F_{e,2} = 85.1515$.
  - $F_{t,2} = 173.3333$, $Z_{F,2} = 500$.
- **IDS**: $P_{R,2} = 7$, $\phi_2 = 1$, $\omega_2 = 1$, $\lambda_2 = 1$.

### 4.4 Reverse Swap ($n = 2$ to $n = 3$), $F_{e,3} = 85.1515$

- **FQS**: 
  - $S_{u,3} = 120 - 9.9725 = 110.0275$ (9.9725 USDC withdrawn).
  - $S_{r,3} = 120 - 9.9725 = 110.0275$.
  - $S_{f,3} = 840 - 69.8075 = 770.1925$.
- **VP-AMM**: 
  - $F_{s,3} = 15.01965$, $R_{s,3} = 9.9725$, $F_{r,3} = 69.8075$.
  - $X_{R,3} = 110.0275$, $Y_{F,3} = 181.68635$.
  - $F_{t,3} = 173.3333 - 85.1515 = 88.1818$, $Z_{F,3} = 500$.
- **IDS**: $P_{R,3} \approx 7$, $\phi_3 = 1$, $\omega_3 = 1$, $\lambda_3 = 1$.

5. Discussion
-------------

The modular VFE maintains equilibrium ($\phi_n = 1$), with IDS adjusting issuance via $\lambda$. The VP-AMM ensures liquidity stability, while FQS tracks supply dynamics. The reverse swap’s unminting returns 9.9725 USDC, demonstrating symmetry.

6. Conclusion
-------------

This modular framework robustly manages perpetual fiat instruments, validated numerically. Additional components (e.g., dynamic $O_R$) can enhance functionality.
