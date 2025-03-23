# Virtual Fiat Environment (VFE-TTD): A Modular Decentralized Financial Protocol

## Abstract

The Virtual Fiat Environment (VFE) for Trinidad and Tobago Dollar (TTD) is a decentralized financial protocol designed to manage perpetual instruments—Reserved Quota (\( R \), a fiat currency call option) and Fiat non-USD (\( F \), a perpetual TTD)—via a modular architecture. This comprises the Fiat Quota Supply (FQS), Virtual Perpetual Automated Market Maker (VP-AMM), and Implicit Derived State (IDS). The FQS tracks core supplies, the VP-AMM facilitates liquidity and ERC20 fiat minting/burning, and the IDS computes derived metrics to maintain system stability. This paper presents the complete mathematical framework, operational logic, and a detailed numerical example spanning initialization and user interactions.

The VFE enables:
- **Forward Swap**: Deposits USDV (\( U_{i,n} \)) to issue \( R \) and \( F \), minting ERC20 TTDV (\( F_{e,n} \)).
- **Reverse Swap**: Redeems ERC20 TTDV (\( F_{e,n} \)) to unmint \( R \) and \( F \), withdrawing USDV.

This specification integrates additional components (Virtualizer, Treasury, Farm) to contextualize VFE within a broader ecosystem, validated through a seven-step example.

---

## 1. Introduction

The VFE-TTD protocol bridges USDV (a virtual USD stablecoin) with TTDV (a virtual TTD token), leveraging:
- **Fiat Quota Supply (FQS)**: Tracks USDV reserves and total \( R \) and \( F \) supplies.
- **Virtual Perpetual Automated Market Maker (VP-AMM)**: Manages liquidity and ERC20 TTDV issuance.
- **Implicit Derived State (IDS)**: Computes protocol rate, flux, reserve ratio, and funding rate.

Additional components include:
- **Virtualizer**: Converts USDC to USDV.
- **Treasury**: Manages USDV collateral and yield.
- **Farm**: Vault for staking USDV into sUSDV, integrating VFE assets.

This paper details all mathematics and applies them to a numerical example with users Alice, Bob, and Charlie.

---

## 2. Notation

| **Symbol**          | **Description**                                                                 | **Component** |
|---------------------|---------------------------------------------------------------------------------|----------------|
| \( U_{i,n} \)       | USDV input at step \( n \) (deposited into FQS)                                 | FQS           |
| \( S_{u,n} \)       | Supply of USDV reserve in Farm at step \( n \)                                 | Farm/FQS      |
| \( S_{r,n} \)       | Total supply of Reserved Quota (\( R \)) at step \( n \)                       | FQS           |
| \( S_{f,n} \)       | Total supply of Fiat non-USD (\( F \)) in the system at step \( n \)           | FQS           |
| \( O_R \)           | Oracle rate (TTD:USD, fixed at 7)                                              | FQS           |
| \( P_{R,n} \)       | Protocol rate, \( P_{R,n} = \frac{S_{f,n}}{S_{r,n}} \)                         | IDS           |
| \( \phi_n \)        | Flux, \( \phi_n = \frac{P_{R,n}}{O_R} \)                                       | IDS           |
| \( \omega_n \)      | Reserve ratio, \( \omega_n = \frac{S_{u,n}}{S_{r,n}} \)                        | IDS           |
| \( \lambda(\phi_n, \omega_n) \) | Funding rate, adjusts issuance                                     | IDS           |
| \( R_{i,n} \)       | Reserved Quota issued at step \( n \)                                          | VP-AMM/FQS    |
| \( F_{i,n} \)       | Fiat non-USD issued at step \( n \)                                            | VP-AMM/FQS    |
| \( X_{R,n} \)       | Reserved Quota in VP-AMM at step \( n \)                                       | VP-AMM        |
| \( Y_{F,n} \)       | Fiat non-USD in VP-AMM at step \( n \)                                         | VP-AMM        |
| \( Z_{F,n} \)       | Excess Fiat non-USD outside VP-AMM (held by Farm) at step \( n \)              | VP-AMM        |
| \( K \)             | VP-AMM constant product, \( K = X_{R,n} \cdot Y_{F,n} \)                       | VP-AMM        |
| \( F_{s,n} \)       | Fiat non-USD swapped (positive in forward, negative in reverse)                | VP-AMM        |
| \( F_{e,n} \)       | ERC20 Fiat (TTDV) minted/burned at step \( n \)                                | VP-AMM        |
| \( R_{s,n} \)       | Reserved Quota swapped out in reverse swap                                     | VP-AMM        |
| \( F_{r,n} \)       | Fiat non-USD redeemed in reverse swap                                          | VP-AMM/FQS    |
| \( F_{t,n} \)       | Total ERC20 TTDV minted at step \( n \)                                        | VP-AMM        |
| \( \text{initRatio} \) | Initial VP-AMM provisioning ratio (set to 2)                                | VP-AMM        |
| \( S_{v,n}(id, addr) \) | Balance of VToken \( id \) for address \( addr \) at step \( n \)           | All           |
| \( S_{v,n}(id) \)   | Total supply of VToken \( id \) at step \( n \)                                | All           |
| \( U_{nr,n} \)      | Non-staked USDV reserve in Treasury                                            | Treasury      |
| \( U_{ns,n} \)      | Staked USDV in Treasury (in Farm)                                              | Treasury      |
| \( U_{val,n} \)     | Total Farm value in USDV at step \( n \)                                       | Farm          |
| \( T_R \)           | Total rate, \( T_R = O_R + \text{initRatio} = 9 \)                             | Farm          |
| \( A_R \)           | AMM-implied rate, \( A_R = \frac{Y_{F,n}}{X_{R,n}} \)                          | VP-AMM        |

---

## 3. Model Description

### 3.1 Virtualizer
- **Deposit**: \( S_{v,n}(1, addr) = S_{v,n-1}(1, addr) + U_d \), \( U_{nr,n} = U_{nr,n-1} + U_d \).
- **Withdraw**: \( S_{v,n}(1, addr) = S_{v,n-1}(1, addr) - U_w \), \( U_{nr,n} = U_{nr,n-1} - U_w \), \( U_{nr,n} \geq S_{v,n}(1) \).

### 3.2 Treasury
- **Total**: \( S_{u,n} (Treasury) = U_{nr,n} + U_{ns,n} + U_{p,n} + U_{y,n} \), \( U_{nr,n} \geq S_{v,n}(1) \).
- **Deposit**: \( U_{nr,n} = U_{nr,n-1} + U_d \).
- **Stake Burn**: \( U_{nr,n} = U_{nr,n-1} - U_{stake} \), \( U_{ns,n} = U_{ns,n-1} + U_{stake} \).

### 3.3 Farm (sUSDV Vault)
- **Stake**: 
  - \( S_{v,n}(1, addr) = S_{v,n-1}(1, addr) - U_{stake} \).
  - \( S_{v,n}(2, addr) = S_{v,n-1}(2, addr) + S_{stake} \).
  - \( S_{u,n} = S_{u,n-1} + U_{stake} \).
  - \( S_{stake} = U_{stake} \cdot \frac{S_{v,n-1}(2)}{U_{val,n-1}} \) (if \( S_{v,n-1}(2) > 0 \), else \( S_{stake} = U_{stake} \)).
- **Valuation**: 
  - \( U_{val,n} = S_{u,n} + \frac{Y_{F,n}}{T_R} + \frac{X_{R,n} \cdot A_R}{T_R} + \frac{S_{v,n}(3, Farm)}{T_R} \).
- **VFE Init**: 
  - \( S_{u,n} = S_{u,n-1} - U_{i,n} \), then OTC adjusts \( S_{u,n} += 10 \), \( S_{v,n}(3, Farm) -= 90 \).

### 3.4 Fiat Quota Supply (FQS)
- **Initialization**:
  - \( S_{u,n} = S_{u,n-1} + U_{i,n} \) (initially from Farm burn).
  - \( F_{i,n} = U_{i,n} \cdot O_R \).
  - \( R_{i,n} = U_{i,n} \cdot \lambda(\phi_n, \omega_n) \).
  - \( S_{r,n} = S_{r,n-1} + R_{i,n} \), \( S_{f,n} = S_{f,n-1} + F_{i,n} \).
- **Forward Swap**:
  - \( S_{u,n+1} = S_{u,n} + U_{i,n} \).
  - \( F_{i,n} = U_{i,n} \cdot O_R \).
  - \( R_{i,n} = U_{i,n} \cdot \lambda(\phi_n, \omega_n) \).
  - \( S_{r,n+1} = S_{r,n} + R_{i,n} \).
  - \( S_{f,n+1} = S_{f,n} + F_{i,n} \).
- **Reverse Swap**:
  - \( S_{u,n+1} = S_{u,n} - R_{s,n} \).
  - \( S_{r,n+1} = S_{r,n} - R_{s,n} \).
  - \( S_{f,n+1} = S_{f,n} - F_{r,n} \).

### 3.5 Virtual Perpetual Automated Market Maker (VP-AMM)
- **Initialization**:
  - \( X_{R,n} = R_{i,n} \).
  - \( Y_{F,n} = R_{i,n} \cdot \text{initRatio} \).
  - \( Z_{F,n} = F_{i,n} - Y_{F,n} \) (to Farm as \( S_{v,n}(3, Farm) \)).
  - \( K = X_{R,n} \cdot Y_{F,n} \).
  - \( F_{t,n} = 0 \).
- **Forward Swap**:
  - \( X_{R,n+1} = X_{R,n} + R_{i,n} \).
  - \( Y_{F,n+1} = \frac{K}{X_{R,n+1}} \).
  - \( F_{s,n} = Y_{F,n} - Y_{F,n+1} \) (positive, removed from pool).
  - \( F_{e,n} = F_{s,n} + F_{i,n} \) (minted as ERC20 TTDV).
  - \( F_{t,n+1} = F_{t,n} + F_{e,n} \).
  - \( Z_{F,n+1} = Z_{F,n} \).
- **Reverse Swap**:
  - Input: \( F_{e,n} \) (TTDV burned).
  - \( Y_{F,n+1} = Y_{F,n} + F_{s,n} \).
  - \( X_{R,n+1} = \frac{K}{Y_{F,n+1}} \).
  - \( R_{s,n} = X_{R,n} - X_{R,n+1} \) (solved via quadratic).
  - \( F_{r,n} = R_{s,n} \cdot P_{R,n} \).
  - \( F_{s,n} = F_{e,n} - F_{r,n} \) (positive, added to pool).
  - Quadratic: \( P_{R,n} R_{s,n}^2 - (Y_{F,n} + F_{e,n} + P_{R,n} X_{R,n}) R_{s,n} + (Y_{F,n} + F_{e,n}) X_{R,n} - K = 0 \).
  - \( F_{t,n+1} = F_{t,n} - F_{e,n} \).

### 3.6 Implicit Derived State (IDS)
- **All Steps**:
  - \( P_{R,n} = \frac{S_{f,n}}{S_{r,n}} \).
  - \( \phi_n = \frac{P_{R,n}}{O_R} \).
  - \( \omega_n = \frac{S_{u,n}}{S_{r,n}} \).
  - \( \lambda(\phi_n, \omega_n) = \begin{cases} 1 & \text{if } \phi_n > 1 \text{ and } \omega_n = 1 \\ \phi_n & \text{otherwise} \end{cases} \).

---

## 4. Numerical Example

### Initial Conditions
- \( O_R = 7 \), \( \text{initRatio} = 2 \), \( T_R = 9 \).

### \( n = 1 \): Alice Converts 300 USDC to 300 USDV
- **Virtualizer**: 
  - \( U_d = 300 \).
  - \( S_{v,1}(1, Alice) = 0 + 300 = 300 \).
  - \( U_{nr,1} = 0 + 300 = 300 \).
- **Treasury**: \( S_{u,1} (Treasury) = 300 + 0 + 0 + 0 = 300 \).
- **Farm**: \( S_{u,1} = 0 \), \( U_{val,1} = 0 \).

### \( n = 2 \): Alice Stakes 100 USDV into sUSDV
- **Farm**:
  - \( U_{stake} = 100 \).
  - \( S_{v,1}(2) = 0 \), so \( S_{stake} = 100 \).
  - \( S_{v,2}(1, Alice) = 300 - 100 = 200 \).
  - \( S_{v,2}(2, Alice) = 0 + 100 = 100 \).
  - \( S_{v,2}(2) = 100 \).
  - \( S_{u,2} = 0 + 100 = 100 \).
- **Treasury**: 
  - \( U_{nr,2} = 300 - 100 = 200 \).
  - \( U_{ns,2} = 0 + 100 = 100 \).
  - \( S_{u,2} (Treasury) = 200 + 100 + 0 + 0 = 300 \).
- **Valuation**: \( U_{val,2} = 100 \), Share price = \( \frac{100}{100} = 1 \).

### \( n = 3 \): Bob Converts 10 USDC to 10 USDV
- **Virtualizer**: 
  - \( U_d = 10 \).
  - \( S_{v,3}(1, Bob) = 0 + 10 = 10 \).
  - \( U_{nr,3} = 200 + 10 = 210 \).
- **Treasury**: \( S_{u,3} (Treasury) = 210 + 100 + 0 + 0 = 310 \).
- **Farm**: \( S_{u,3} = 100 \), \( U_{val,3} = 100 \).

### \( n = 4 \): Bob Stakes 10 USDV and 90 TTDC
- **Bob**: 
  - \( S_{v,4}(1, Bob) = 10 - 10 = 0 \) (held for VFE).
  - 90 TTDC (pending OTC).
- **Treasury**: \( U_{nr,4} = 210 \), \( U_{ns,4} = 100 \), \( S_{u,4} (Treasury) = 310 \).
- **Farm**: \( S_{u,4} = 100 \), \( U_{val,4} = 100 \).

### \( n = 5 \): Farm Initializes VFE-TTD, Bob LPs Stable Swap
- **FQS Initialization**:
  - \( U_{i,n} = 100 \).
  - \( S_{u,5} = 100 - 100 = 0 \).
  - \( F_{i,n} = 100 \cdot 7 = 700 \).
  - \( R_{i,n} = 100 \cdot 1 = 100 \) (\( \phi_n = 1 \), \( \omega_n = 1 \)).
  - \( S_{r,5} = 0 + 100 = 100 \).
  - \( S_{f,5} = 0 + 700 = 700 \).
- **VP-AMM Initialization**:
  - \( X_{R,5} = 100 \).
  - \( Y_{F,5} = 100 \cdot 2 = 200 \).
  - \( K = 100 \cdot 200 = 20,000 \).
  - \( Z_{F,5} = 700 - 200 = 500 \) (\( S_{v,5}(3, Farm) = 500 \)).
  - \( F_{t,5} = 0 \).
- **OTC Swap**:
  - Farm: \( S_{v,5}(3, Farm) = 500 - 90 = 410 \), \( S_{u,5} = 0 + 10 = 10 \).
  - Bob: \( S_{v,5}(3, Bob) = 90 \).
- **Stable Swap**: 
  - \( X = 90 \) TTDV, \( Y = 90 \) TTDC, \( k = 90 + 90 = 180 \).
- **IDS**: 
  - \( P_{R,5} = \frac{700}{100} = 7 \).
  - \( \phi_5 = \frac{7}{7} = 1 \).
  - \( \omega_5 = \frac{10}{100} = 0.1 \) (post-OTC).
  - \( \lambda_5 = 1 \) (since \( \phi_5 = 1 \)).
- **Valuation**: 
  - \( S_{u,5} = 10 \).
  - \( \frac{Y_{F,5}}{T_R} = \frac{200}{9} \approx 22.2222 \).
  - \( A_R = \frac{200}{100} = 2 \).
  - \( \frac{X_{R,5} \cdot A_R}{T_R} = \frac{100 \cdot 2}{9} \approx 22.2222 \).
  - \( \frac{S_{v,5}(3, Farm)}{T_R} = \frac{410}{9} \approx 45.5556 \).
  - \( U_{val,5} = 10 + 22.2222 + 22.2222 + 45.5556 = 100 \).

### \( n = 6 \): Charlie Converts 1 USDC to 1 USDV
- **Virtualizer**: 
  - \( U_d = 1 \).
  - \( S_{v,6}(1, Charlie) = 0 + 1 = 1 \).
  - \( U_{nr,6} = 210 + 1 = 211 \).
- **Treasury**: \( S_{u,6} (Treasury) = 211 + 100 + 0 + 0 = 311 \).
- **Farm**: \( S_{u,6} = 10 \), \( U_{val,6} = 100 \).

### \( n = 7 \): Charlie Converts 1 USDV to TTDV, Then TTDC
- **Forward Swap**:
  - \( U_{i,n} = 1 \).
  - \( S_{u,n+1} = 10 + 1 = 11 \).
  - \( F_{i,n} = 1 \cdot 7 = 7 \).
  - \( R_{i,n} = 1 \cdot 1 = 1 \) (\( \phi_6 = 1 \), \( \omega_6 = 0.1 \)).
  - \( S_{r,n+1} = 100 + 1 = 101 \).
  - \( S_{f,n+1} = 700 + 7 = 707 \).
  - \( X_{R,n+1} = 100 + 1 = 101 \).
  - \( Y_{F,n+1} = \frac{20,000}{101} \approx 198.0198 \).
  - \( F_{s,n} = 200 - 198.0198 \approx 1.9802 \).
  - \( F_{e,n} = 1.9802 + 7 = 8.9802 \) (TTDV minted).
  - \( F_{t,n+1} = 0 + 8.9802 = 8.9802 \).
  - \( Z_{F,n+1} = 410 \) (unchanged).
  - Charlie: \( S_{v,7}(1, Charlie) = 1 - 1 = 0 \), \( S_{v,7}(3, Charlie) = 8.9802 \).
- **IDS**: 
  - \( P_{R,7} = \frac{707}{101} \approx 7 \).
  - \( \phi_7 = \frac{7}{7} = 1 \).
  - \( \omega_7 = \frac{11}{101} \approx 0.1089 \).
  - \( \lambda_7 = 1 \).
- **Valuation**: 
  - \( S_{u,7} = 11 \).
  - \( \frac{Y_{F,7}}{T_R} = \frac{198.0198}{9} \approx 22.0022 \).
  - \( A_R = \frac{198.0198}{101} \approx 1.9606 \).
  - \( \frac{X_{R,7} \cdot A_R}{T_R} = \frac{101 \cdot 1.9606}{9} \approx 22.0022 \).
  - \( \frac{S_{v,7}(3, Farm)}{T_R} = \frac{410}{9} \approx 45.5556 \).
  - \( U_{val,7} = 11 + 22.0022 + 22.0022 + 45.5556 \approx 100.56 \) (includes 1 USDV input).
- **Stable Swap**:
  - \( \Delta X = 8.9802 \).
  - \( \Delta Y = \Delta X = 8.9802 \).
  - \( X = 90 + 8.9802 = 98.9802 \), \( Y = 90 - 8.9802 = 81.0198 \).
  - Charlie: \( S_{v,7}(3, Charlie) = 0 \), 8.9802 TTDC.

---

## 5. Discussion

- **\( U_{val} \)**: Increases by 0.56 due to 1 USDV input (no fee applied yet—needs adjustment).
- **IDS**: Maintains \( \phi_n = 1 \), indicating equilibrium.
- **Swaps**: Forward swap correctly mints TTDV, and Stable Swap converts to TTDC.

## 6. Conclusion

The VFE-TTD protocol robustly integrates USDV with TTDV, with all mathematical components fully specified. Future refinements will include swap fees (\( U_{fee} \)) and dynamic \( O_R \).
