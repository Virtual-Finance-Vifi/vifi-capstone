# derivation.txt

# Full Derivation of the Reverse Swap Quadratic

We consider a scenario in which we know five parameters:

- $P_R$ — the protocol rate, often $P_R = \frac{S_F}{S_R}$.
- $Y_F$ — the current Fiat side of the AMM reserve.
- $F_e$ — the final Fiat or “exit” amount we wish to account for.
- $X_R$ — the current Reserve side of the AMM (i.e., R in the pool).
- $k$ — the AMM constant, often $k = X_R \times Y_F$ in a constant-product or some generalized form.

In the “reverse swap” equation, we want to find $X$ (often denoted $R_s$) that satisfies:

1. The portion from the AMM: $\frac{k}{\,X_R - X}$ (how much Fiat is pulled from the AMM if we deposit $X$ of the Reserve).
2. The portion from the protocol redemption: $X \times P_R$.
3. These combined must match the total Fiat needed, which is $Y_F + F_e$, or equivalently we shift terms and end up with:

\[
f(X) 
\;=\; 
\frac{k}{X_R - X} 
\;-\; 
Y_F 
\;+\; 
X P_R 
\;-\; 
F_e.
\]

We want $f(X) = 0$. In other words:

$$
\frac{k}{X_R - X} + X P_R = Y_F + F_e.
$$

Let us denote the right-hand side as:

$$
\text{RHS} = Y_F + F_e.
$$

Hence,

$$
\frac{k}{X_R - X} + X P_R = \text{RHS}.
$$

---

## Multiply Both Sides by $(X_R - X)$

Multiply both sides by $(X_R - X)$. On the left side, this cancels the fraction:

$$
k + (X_R - X)\,(X P_R) = \text{RHS}\,(X_R - X).
$$

Let us expand the terms:

1. **Left Side**  

   $$
   k + (X_R - X)(X P_R)
   = k + P_R(X_R X - X^2)
   = k + P_R X_R X - P_R X^2.
   $$

2. **Right Side**  

   $$
   \text{RHS}\,(X_R - X)
   = \text{RHS}\,X_R - \text{RHS}\,X.
   $$

So the equality is:

$$
k + P_R X_R X - P_R X^2
= \text{RHS}\,X_R - \text{RHS}\,X.
$$

---

## Bring All Terms to One Side

We want a polynomial in $X$ of the form $0 = a X^2 + b X + c.$ Rearrange to make the right side zero:

$$
0 
= \text{RHS}\,X_R - \text{RHS}\,X - k - P_R X_R X + P_R X^2.
$$

Group them carefully by powers of $X$:

- The $X^2$ term is $P_R X^2.$
- The $X^1$ term is $-\,(\text{RHS} + P_R X_R).$
- The constant term is $\text{RHS}\,X_R - k.$

Hence, in standard quadratic form:

$$
P_R X^2 
- \bigl(\text{RHS} + P_R X_R\bigr)\,X 
+ \bigl(\text{RHS}\,X_R - k\bigr) 
= 0.
$$

Thus:

- $a = P_R,$
- $b = -\bigl[\text{RHS} + P_R\,X_R\bigr],$
- $c = \text{RHS}\,X_R - k.$

---

## Solve via the Quadratic Formula

Recall the quadratic formula for $a X^2 + b X + c = 0$:

$$X = \frac{-b \pm \sqrt{\,b^2 - 4 a c\,}}{2 a}$$

1. Compute $\Delta = b^2 - 4 a c.$
2. Then the two candidate roots are:

$$X_{1,2} = \frac{-b \pm \sqrt{\Delta}}{2 a}$$

3. **Physical Constraint**: We typically require $0 \le X \le X_R$ for a valid solution in an AMM scenario (and we also want $(X_R - X) > 0$). So we pick whichever root satisfies that domain constraint. If both are out of domain or the discriminant is negative, we have no real solution.

That is how we solve for $X$ — often denoted $R_s$ in a “reverse swap” context — using a direct algebraic approach instead of a numerical bisection.

