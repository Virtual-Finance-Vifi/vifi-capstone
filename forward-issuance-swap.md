# Full Derivation of the Forward Issuance-Swap

This document parallels the “reverse swap” derivation but proceeds in a **forward** direction:

- The protocol **issues** Fiat $F_i$ (the “F issued”) and Reserve $R_i$, but **the user does not custody** $R_i$.  
- Instead, some or all of that **newly issued** Reserve (denoted $R_s$) is **swapped** through the AMM, ultimately yielding **F out** ($F_o$) to the user.

---

## 1. Scenario and Parameters

1. **$F_o$ (“F out”)**  
   - The **final** amount of Fiat (in ERC-20 form) that the user ends up with after the issuance and potential swap.

2. **$F_i$ (“F issued”)**  
   - The amount of **Fiat** that the protocol mints and delivers (or credits) to the user.  

3. **$R_i$ (“R issued”)**  
   - The amount of **Reserve** the protocol mints.  
   - **However**, the user **does not** directly custody $R_i$.  
   - A portion $R_s$ of $R_i$ (possibly all) is swapped in the AMM on the user’s behalf.

4. **$R_s$**  
   - The amount of **Reserve** actually used in the **swap** inside the AMM.  
   - This reserve is effectively “issued by the protocol” but placed into the AMM for the user to obtain additional Fiat.

5. **$(X_R, Y_F)$**  
   - The **current** balances of Reserve ($X_R$) and Fiat ($Y_F$) in the AMM, *before* $R_s$ is swapped in.

6. **$k$**  
   - The AMM’s invariant constant, typically $k = X_R \times Y_F$ for a constant-product AMM.

---

## 2. The Forward Issuance-Swap Logic

1. The protocol **issues**:
   - **Fiat $F_i$** (to the user).  
   - **Reserve $R_i$** (but not into the user’s wallet; it remains in a contract, ready to be swapped).

2. The user (or the protocol on their behalf) **swaps** an amount $R_s \le R_i$ **into** the AMM.  
   - By depositing $R_s$ to the AMM, the user (contract) receives extra Fiat $F_s$.

3. Finally, the user’s total “F out” is:

$$
F_o \;=\; F_i \;+\; F_s.
$$

Here:  
- $F_i$ = **F issued**, minted directly for the user.  
- $F_s$ = **extra Fiat** obtained via the swap (where $R_s$ is deposited to the AMM).

---

## 3. AMM Swap Equation

Using the **constant-product** formula:

- **Before swap**: The AMM has $(X_R, Y_F)$ and $k = X_R \times Y_F$.  
- **After the user deposits** $R_s$ Reserve:
  \[
    X'_R = X_R + R_s.
  \]
- The pool must keep $k$ constant, so the **new** Fiat balance is
  \[
    Y'_F = \frac{k}{\,X_R + R_s\,}.
  \]
- Therefore, the **Fiat** that flows out to the user from this swap is
  \[
    F_s
    \;=\;
    Y_F
    \;-\;
    Y'_F
    \;=\;
    Y_F
    \;-\;
    \frac{k}{\,X_R + R_s\,}.
  \tag{1}
  \]

---

## 4. Matching the Desired $F_o$

The user wants a **final** Fiat amount $F_o$, which must satisfy:

$$
F_o 
\;=\;
F_i + F_s.
$$

Hence,

$$
F_s 
\;=\;
F_o \;-\; F_i.
\tag{2}
$$

We already have an expression for $F_s$ from the AMM in (1).  **Equate** these two forms:

$$
F_o \;-\; F_i 
\;=\; 
Y_F \;-\; \frac{k}{\,X_R + R_s\,}.
$$

Rearrange:

$$
Y_F \;-\;\bigl(F_o - F_i\bigr)
\;=\;
\frac{k}{\,X_R + R_s\,}.
$$

Define a convenient constant:

$$
M 
\;:=\; 
Y_F \;-\; \bigl(F_o - F_i\bigr)
\;=\; 
Y_F \;-\; F_o \;+\; F_i.
$$

Thus,

$$
M \;=\; \frac{k}{\,X_R + R_s\,}.
$$

Take reciprocals:

$$
X_R + R_s
\;=\;
\frac{k}{\,M\,}.
$$

So the **required Reserve** $R_s$ to deposit into the AMM is:

$$
R_s 
\;=\;
\frac{k}{\,M\,} 
\;-\;
X_R
\quad\text{where}
\quad
M = Y_F - F_o + F_i.
$$

---

## 5. Final Formula

Putting it all together:

$$
\boxed{
R_s 
\;=\;
\frac{k}{\,Y_F - F_o + F_i\,}
\;-\;
X_R
}
$$

provided that $Y_F - F_o + F_i \neq 0$.

**Notes**:

- $R_s \ge 0$ requires $\frac{k}{\,Y_F - F_o + F_i\,} \;\ge\; X_R$.  
- If $R_s > R_i$ is implied, the system cannot swap that much Reserve (since only $R_i$ was issued).  
- $Y_F - F_o + F_i$ must be positive for a feasible deposit (otherwise you’d get negative or infinite $R_s$).

---

## 6. Key Observations

1. **No Quadratic**:  
   - Unlike the “reverse swap” case (where a redemption constraint $F_r = R_s \times P_R$ also applied), here we have **only** the AMM equation.  
   - Hence, we get a **linear** expression (in reciprocal form) for $R_s$.

2. **$R_i$ Does Not Enter User Custody**:  
   - The protocol “mints” $R_i$, but it resides in a contract or AMM.  
   - Only an amount $R_s \le R_i$ is effectively used in the swap to obtain $F_s$.

3. **$F_o$ (“F out”)**:  
   - The total Fiat the user ends up holding.  
   - Computed as **the initially issued Fiat** ($F_i$) **plus** the Fiat from the swap ($F_s$).

4. **If $X_R$ Becomes Small**:  
   - The AMM might not be able to provide large $F_s$.  
   - In some protocols, if $X_R$ is insufficient, the system halts new issuance or triggers other safeguards.

---

## 7. Conclusion

The **forward issuance-swap** derivation shows that, if the user (or protocol) wants $F_o$ (“F out”) in total, knowing they already hold (or are credited with) $F_i$ from issuance, the **required** Reserve deposit $R_s$ into a constant-product AMM is

$$
R_s 
\;=\;
\frac{k}{\,Y_F - (F_o - F_i)\,}
\;-\;
X_R,
$$

where $k = X_R \times Y_F$ is the AMM invariant. This formula directly follows from the single swap equation, without introducing a second redemption constraint, and therefore **no quadratic** arises in this forward scenario.
