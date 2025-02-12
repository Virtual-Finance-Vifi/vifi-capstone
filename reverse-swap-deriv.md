# Full Derivation of the Reverse Swap Quadratic

We consider a scenario in which we know five parameters:

- $F_e$ — the final Fiat or “exit” amount we wish to account for.
- $P_R$ — the protocol rate, often $P_R = \frac{S_F}{S_R}$.
- $Y_F$ — the current Fiat side of the AMM reserve.
- $X_R$ — the current Reserve side of the AMM (i.e., R in the pool).
- $k$ — the AMM constant, often $k = X_R \times Y_F$ in a constant-product or some generalized form.

---

We have the total amount of fiat being 'exited' denoted as $F_e$ 

$F_e$ must be split into $F_s$ and $F_r$ such that

$$F_e =  F_s + F_r$$

where
- $F_s$ is the amount of fiat used from a swap to obtain R_s
- $F_r$ is the amount of fiat used for protocol redemption

However for protocol redemption, $F_r$ must satisfy 

$$ F_r = R_s \times P_R$$

thus

**$F_e$ protocol redemptiom equation (eq1)**

$$ F_e = F_s + (R_s \times P_R)$$

$R_s$ is obtained from the AMM. the the pair $(R_s,F_r)$ is removed from the global $(S_U,S_R,S_F)$, "unminting" of R's and F's for U's.

$R_s$ is obtained via the amm by swapping in $F_s$ where

$$X_R \times Y_f = k$$

thus

$$Y'_F = Y_F + F_s$$

and

$$X'_R = \frac{k}{Y'_F}$$

$\Rightarrow $

$$R_s = X_R - X'$$

$$R_s = X_R - \frac{k}{Y'_F}$$

**$R_s$ AMM Derived Equation (eq2)**

$$R_s = X_R - \frac{k}{Y_F + F_s}$$

---

We have eq1 and eq2 which both express R_s and F_s which are unknown.

Let $X := R_s$

sub $X$ into eq2

$$X = X_R - \frac{k}{Y_F + F_s}$$

solve for $F_s$ in terms of $X$:

$$ X_R = X = \frac{k}{Y_F + F_s} $$

solve for $F_s$ in terms of $X$

$\Rightarrow $

$$Y_F + F_s = \frac{k}{X_R - X}$$

**$F_s$ AMM Derived Equation in terms of $X$ (eq3)**

$$F_s = \frac{k}{X_R-X}-Y_F$$

substituting $X$ into eq1 we get:

$$ F_e = F_s + (X \times P_R)$$

we can substitute $F_s$ from eq3 and we get:

$$ F_e = \left[\frac{k}{X_R-X}-Y_F\right] + (X \times P_R)$$

we can defind $f(X)$ as LHS - RHS:

$$f(X) = \frac{k}{X_R - X} -Y_F + X P_R -F_e$$

We want $f(X) = 0$ In other words:

$$\frac{k}{X_R - X} + X P_R = Y_F + F_e$$

---

## Multiply Both Sides by $(X_R - X)$

Multiply both sides by $(X_R - X)$ On the left side, this cancels the fraction:

$$k + (X_R - X)(X P_R) = (Y_F + F_e)(X_R - X)$$

Let us expand the terms:

1. **Left Side**  

   $$k + (X_R - X)(X P_R)= k + P_R(X_R X - X^2)= k + P_R X_R X - P_R X^2$$

2. **Right Side**  

   $$(Y_F + F_e)(X_R - X)= (Y_F + F_e)X_R - (Y_F + F_e)X$$

So the equality is:

$$k + P_R X_R X - P_R X^2= (Y_F + F_e)X_R - (Y_F + F_e)X$$

---

## Bring All Terms to One Side

We want a polynomial in $X$ of the form $0 = a X^2 + b X + c$ Rearrange to make the right side zero:

$$0 = (Y_F + F_e)X_R - (Y_F + F_e)X - k - P_R X_R X + P_R X^2$$

Hence, in standard quadratic form:

$$0 = \left[P_R \right] X^2 + -\left[ (Y_F + F_e) + P_R X_R \right] X + \left[  (Y_F + F_e)X_R - k \right]  $$

Group them carefully by powers of $X$:

- The $X^2$ term is $P_R$
- The $X^1$ term is $-\left[ (Y_F + F_e) + P_R X_R \right]$
- The constant term is $(Y_F + F_e)X_R - k$

Thus:

- $a = P_R$
- $b = -\left[ (Y_F + F_e) + P_R X_R \right]$
- $c = (Y_F + F_e)X_R - k$

---

## Solve via the Quadratic Formula

Recall the quadratic formula for $a X^2 + b X + c = 0$:

$$X = \frac{-b \pm \sqrt{\,b^2 - 4 a c\,}}{2 a}$$

1. Compute $\Delta = b^2 - 4 a c$
2. Then the two candidate roots are:

$$X_{1,2} = \frac{-b \pm \sqrt{\Delta}}{2 a}$$

3. **Physical Constraint**: We typically require $0 \le X \le X_R$ for a valid solution in an AMM scenario (and we also want $(X_R - X) > 0$). So we pick whichever root satisfies that domain constraint. If both are out of domain or the discriminant is negative, we have no real solution.

That is how we solve for $X$ — often denoted $R_s$ in a “reverse swap” context — using a direct algebraic approach instead of a numerical bisection.

