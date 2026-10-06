# Levelling a Baseline

A level line is run from benchmark *A* to benchmark *B* and back. Each
set-up contributes a height difference $\Delta h_i = b_i - f_i$ from the
backsight $b_i$ and the foresight $f_i$, so that

$$
H_B = H_A + \sum_{i=1}^{n} \Delta h_i ,
\qquad
\sum_{i=1}^{n} b_i - \sum_{i=1}^{n} f_i = H_B - H_A .
$$

The method is described in [@halvorsen1998] and, for digital
instruments, in [@okafor2011] and [@lindqvist2004].

## Error budget

With a standard deviation $\sigma_0$ per kilometre of double run, the
closing error of a loop of length $L$ should satisfy

$$
|w| \le 2 \, \sigma_0 \sqrt{L},
\qquad
\sigma_{\bar{h}} = \frac{\sigma_0}{\sqrt{2}} \sqrt{L} .
$$

For unequal sight lengths the collimation error $\alpha$ enters as
$\delta = (s_b - s_f) \tan\alpha$, which is why sights are balanced; see
[the field rules](#lev-field-rules) and, for refraction, [@lev-refraction].

## Refraction

Close to the ground the line of sight bends by

$$
r = \frac{k \, s^2}{2 R},
\quad
k \approx
\begin{cases}
  0.13 & \text{standard atmosphere} \\
  -1 \ldots 1 & \text{within } 1\,\mathrm{m} \text{ of the ground}
\end{cases}
$$

with the earth radius $R$ and the sight length $s$.

## Field rules

1. Keep $s_b \approx s_f$, each below $40\,\mathrm{m}$.
2. Read no lower than $0.5\,\mathrm{m}$ on the staff ([Section][@lev-refraction] explains why).
3. Close every loop; compare $w$ with the bound from [@lev-error-budget].

<!--raw-typst
#rule-box[Balanced sights cancel collimation *and* most of the curvature term $c = s^2 / (2 R)$.]
-->

## Field rules

A second section with the same title gets a numbered label; it is linked
[here](#lev-field-rules-1). Because the
document turns `prefix-label-uses` off for this file, its own labels are
written with their prefix, and citation keys stay as they are in the
bibliography.
