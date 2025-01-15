# Full Derivation of the Forward Issuance-Swap

This document parallels the “reverse swap” derivation, but in the **forward** direction:  
we have newly **issued** (minted) Reserve and Fiat, and we want to derive how much additional Fiat can be obtained (or how much Reserve must be deposited in the AMM) to reach a desired final amount of Fiat \(F_o\).

---

## 1. Scenario and Parameters

1. **\(F_o\)**  
   - The **final Fiat** (in ERC-20 form) that the user wants to walk away with after issuance and a potential swap.  

2. **\(F_i\)**  
   - The **initial Fiat** minted to the user from the protocol (e.g., the protocol might mint some quantity of Fiat based on collateral deposited).  

3. **\(R_i\)**  
   - The **Reserve tokens** minted by the protocol.  
   - However, depending on design, these \(R_i\) might or might not enter the user’s custody.  
   - In a pure forward-swap scenario (if the user *does* hold \(R_i\)), they can choose how much of it (\(R_s\)) to swap in the AMM.  

4. **\(R_s\)**  
   - The **portion of Reserve** that the user deposits (swaps) *into* the AMM to get more Fiat.  
   - In many protocols, \(0 \le R_s \le R_i\).  

5. **\((X_R, Y_F)\)**  
   - The **current** balances of Reserve and Fiat in the AMM pool, *before* the user’s swap.  

6. **\(k\)**  
   - The AMM’s **invariant constant**, often \(k = X_R \times Y_F\) for a standard constant-product market maker.  

---

## 2. The Forward Issuance-Swap Idea

### 2.1 What the User Already Has

Upon issuance, the user might be given:  
- \(F_i\) units of Fiat, and  
- \(R_i\) units of Reserve.

### 2.2 The User’s Goal

The user wants a final total of **\(F_o\) Fiat** in their wallet. If they only have \(F_i\) from issuance, they may need to perform a swap of some Reserve (\(R_s\)) in the AMM to gain **additional** Fiat.

Thus, we define:

\[
F_s 
\;=\;
\text{(extra Fiat gained from the AMM swap)}.
\]

Hence, the final Fiat in the user’s wallet is:

\[
F_o 
\;=\;
F_i \;+\; F_s.
\]

Rearrange to express \(F_s\):

\[
F_s 
\;=\;
F_o - F_i.
\tag{eq1}
\]

---

## 3. AMM Swap Equation

We use the **constant-product** rule for the AMM:

- Before the swap, the AMM has \((X_R, Y_F)\).  
- The user **deposits** \(R_s\) Reserve into the pool, so the new Reserve balance is
  \[
    X'_R 
    \;=\; 
    X_R + R_s.
  \]
- Because \(k = X_R \times Y_F\) stays constant, the **new Fiat** side of the pool will be
  \[
    Y'_F 
    \;=\;
    \frac{k}{\,X'_R\,} 
    \;=\;
    \frac{k}{\,X_R + R_s\,}.
  \]
- The **Fiat** received by the user in this swap is
  \[
    F_s 
    \;=\; 
    \bigl(\text{old Fiat in pool}\bigr) 
    \;-\; 
    \bigl(\text{new Fiat in pool}\bigr)
    \;=\;
    Y_F 
    \;-\;
    \frac{k}{\,X_R + R_s\,}.
  \tag{eq2}
\]

---

## 4. Matching the Desired Fiat

From \(\,(eq1)\) and \(\,(eq2)\), we have two expressions for \(F_s\).  
We **equate** them to solve for \(R_s\) (the Reserve deposit needed):

\[
F_o - F_i
\;=\;
Y_F
\;-\;
\frac{k}{\,X_R + R_s\,}.
\]

### 4.1 Rearrange

\[
Y_F 
\;-\;
\bigl(F_o - F_i\bigr)
\;=\;
\frac{k}{\,X_R + R_s\,}.
\]

For convenience, define:

\[
M 
\;:=\; 
Y_F - \bigl(F_o - F_i\bigr) 
\;=\;
Y_F - F_o + F_i.
\]

Thus,

\[
M 
\;=\;
\frac{k}{\,X_R + R_s\,}.
\]

### 4.2 Solve for \(R_s\)

Take reciprocals:

\[
X_R + R_s 
\;=\; 
\frac{k}{\,M\,}.
\]

Hence,

\[
R_s
\;=\;
\frac{k}{\,M\,}
\;-\;
X_R.
\tag{eq3}
\]

Where \(M = Y_F - F_o + F_i\).

---

## 5. Interpreting the Result

1. **Domain Constraint**  
   - We typically need \(R_s \ge 0\). This implies
     \[
       \frac{k}{\,M\,} - X_R \;\ge\; 0
       \quad\Longrightarrow\quad
       \frac{k}{\,M\,} \;\ge\; X_R.
     \]
   - Likewise, if the user only has \(R_i\) minted, then \(R_s \le R_i\).  

2. **No Quadratic**  
   - Unlike the **reverse-swap** derivation (which included a protocol redemption step \(F_r = R_s \times P_R\) and thus introduced an additional unknown in the same equation), here we only have **one** operation: the AMM swap.  
   - As a result, solving for \(R_s\) is a **linear** step in the reciprocal sense (no extra product terms appear).

3. **Final Fiat**  
   - Once \(R_s\) is determined (from eq3), the user knows how much Reserve they must deposit into the AMM to get \(F_s = (F_o - F_i)\) in Fiat.  
   - Equivalently, if the user knows how much Reserve \(R_s\) they *want* to deposit, they can compute the resulting \(\,F_s = Y_F - \frac{k}{\,X_R + R_s\,}\). Either way, (eq3) is the direct solution if \(F_o\) is the target.

4. **Compare with Reverse Swap**  
   - In the reverse swap, we also accounted for a **redemption** step (\(F_r = P_R \times R_s\)), forcing a second constraint on the same variables. That led to a quadratic.  
   - In the forward swap, no such extra constraint exists (we do not have a direct “protocol rate” tying the Reserve to more minted Fiat). As a result, the math is simpler.

---

## 6. Summary

### 6.1 Main Formula

If a user **already** has minted Fiat \(F_i\) and wants to achieve a final Fiat balance \(F_o\) by swapping Reserve \(R_s\) into a constant-product AMM with \((X_R, Y_F)\) and \(k = X_R \times Y_F\), then:

\[
\boxed{
R_s 
\;=\;
\frac{k}{\,Y_F - F_o + F_i\,}
\;-\;
X_R
}
\quad
\text{provided that}
\quad
Y_F - F_o + F_i \;\neq\; 0.
\]

### 6.2 Physical Constraints

- **Reserve Domain**: Typically, \(0 \le R_s \le R_i\).  
- **Liquidity Requirement**: We also need \(\,X_R + R_s\) to remain within feasible AMM bounds (i.e., the pool can handle that deposit).  
- **Sign of \(M\)**: If \(M = Y_F - F_o + F_i \le 0\), the formula breaks or implies negative/infinite deposit. In practice, that means the user is demanding more Fiat (\(F_o\)) than the pool can provide given the minted amount \(F_i\).

---

## 7. Conclusion

In a **Forward Issuance-Swap**, once you fix:

1. The user’s **target final Fiat** \(F_o\),  
2. The protocol’s **already minted Fiat** \(F_i\),  
3. The AMM’s **current state** \(\,(X_R, Y_F, k)\),

then **the required Reserve deposit** \(R_s\) into the AMM to reach \(\,F_o\) is **linearly** determined by

\[
R_s 
= 
\frac{k}{\,Y_F - (F_o - F_i)\,} 
\;-\;
X_R
=
\frac{k}{\,Y_F - F_o + F_i\,}
\;-\;
X_R.
\]

No quadratic arises here because there is no second term (like a redemption ratio) linking Reserve and Fiat in the same equation. This direct solution is the “forward” analog to the more involved “reverse swap” derivation. 
