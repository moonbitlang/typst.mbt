// physica 0.9.8: the document-wide show rules `super-T-as-transpose` and
// `super-plus-as-dagger` (scoped and global, with their exceptions: integrals, sums, limits,
// scripts, norms), `TT`, row vectors, inner products, together with document-wide math
// settings (matrix delimiters, numbering per section, supplement, equation text size).
// Engine: show rule on math.attach that rebuilds attachments, element equality with
// `$..$.body`, counters in equation numbering, references to equations.
#import "@preview/physica:0.9.8": *

#set page(width: 150mm, height: 175mm, margin: (x: 13mm, y: 14mm), numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.")
#show heading.where(level: 1): it => {
  counter(math.equation).update(0)
  it
}
#set math.equation(
  numbering: n => numbering("(1.1)", counter(heading).get().first(), n),
  supplement: [Eq.],
)
#set math.mat(delim: "[")
#set math.vec(delim: "[")

#align(center, text(14pt, weight: "bold")[Least Squares and Unitary Gates])

= Before the rules

Without the show rules a superscript $T$ is an ordinary italic letter and a plus is
a plus: $A^T$, $(A B)^T = B^T A^T$, $U^+ U = I$. The upright symbol can be written by
hand, $A^TT$, which is what the rule does for us below.

$ vecrow(x_1, x_2, x_3)^T != vec(x_1, x_2, x_3) quad "typographically, but" quad
  vecrow(x_1, x_2, x_3, delim: "[")^TT = vec(x_1, x_2, x_3). $ <eq-plain>

#[
  #show: super-T-as-transpose
  Inside this block only the transpose rule is active: $A^T$, $M_(i j)^T$, $U^+$.
  $ (A^T)^T = A, quad (A + B)^T = A^T + B^T, quad (A^(-1))^T = (A^T)^(-1). $ <eq-scoped>
]

After the block the letter is italic again: $A^T$ (compare @eq-plain and @eq-scoped).

#show: super-T-as-transpose
#show: super-plus-as-dagger

= Least squares

From here on both rules hold for the whole document. For a tall matrix $X$ and
observations $vb(y)$, the residual $vb(r) = vb(y) - X vb(beta)$ is minimal when
$ X^T X vb(beta) = X^T vb(y), quad "so" quad
  hat(vb(beta)) = (X^T X)^(-1) X^T vb(y) = X^+ vb(y), $ <eq-normal>
where, in this section only, $X^+$ happens to be rendered like the adjoint. The
projector $P = X (X^T X)^(-1) X^T$ satisfies $P^T = P$ and $P^2 = P$. With weights,
$ vb(r)^T W vb(r) = sum_(i = 1)^T w_i r_i^2, quad
  W = dmat(w_1, w_2, dots.down, w_T), quad
  integral_0^T r(t)^2 dd(t) approx difference(t) sum_(i = 1)^T r_i^2. $ <eq-weights>
The upper limits $T$ of the sum and the integral in @eq-weights are not transposes
and stay italic; the same holds with explicit `limits` and `scripts`,
$limits(X)^T$ and $scripts(Y)^T$, and for a norm, $norm(vb(x))^T$, or an absolute
value, $|x|^T$, but $(vb(x))^T$, $[A B]^T$ and $vb(x)_k^T$ are transposed. Subscripts
survive: $A_(1 2)^T$, $Q_k^T Q_k = I$.

The Gram matrix of the columns and the Jacobian of the residual are
$ X^T X = grammat(vb(x)_1, vb(x)_2, vb(x)_3), quad
  J^T = jmat(r_1, r_2; beta_1, beta_2, big: #true)^T, \
  iprod(vb(u), A^T vb(v)) = iprod(A vb(u), vb(v)). $ <eq-gram>

= Unitary gates

A gate is a matrix with $U^+ U = U U^+ = I$. For a single qubit,
$ H = 1 / sqrt(2) mat(1, 1; 1, -1), quad
  S = dmat(1, i), quad S^+ = dmat(1, -i), \
  R_y (theta) = rot2mat(theta slash 2), quad H^+ = H^T = H. $ <eq-gates>
The adjoint of a product reverses the order, $(A B)^+ = B^+ A^+$, and for kets
$ket(psi)^+ = bra(psi)$, $(ketbra(phi, psi))^+ = ketbra(psi, phi)$,
$mel(phi, A^+, psi) = mel(psi, A, phi)^*$. Ladder operators: $a^+ a ket(n) = n ket(n)$,
$[a, a^+] = 1$, and with a subscript $a_k^+ a_k$.

A superscript plus that is not an adjoint has to opt out with `scripts`:
the ion $scripts("Na")^+$, the limit $lim_(x -> scripts(0)^+) f(x)$, the set
$scripts(RR)^+$. Without it the rule applies, as in $"Na"^+$.

$ expval(A^+ A, psi) = norm(A ket(psi))^2 >= 0, quad
  tr(rho^+ rho) <= 1, \
  (U_1 U_2 dots.c U_n)^+ = U_n^+ dots.c U_2^+ U_1^+, quad
  evaluated(dv(, t) U^+ U)_(t = 0) = 0. $ <eq-adj>

#set math.mat(delim: "(")
#show math.equation.where(block: true): set text(size: 9pt)

= Summary

With round delimiters and smaller display text for the last section:
$ mat(A, B; C, D)^T = mat(A^T, C^T; B^T, D^T), quad
  mat(A, B; C, D)^+ = mat(A^+, C^+; B^+, D^+), \
  hmat(f; x, y)^T = hmat(f; x, y). $ <eq-block>

#table(
  columns: (1fr, auto, auto),
  table.header[*Statement*][*Written*][*Reference*],
  [normal equations], [`X^T X`], [@eq-normal],
  [weighted residual], [`vb(r)^T W vb(r)`], [@eq-weights],
  [Gram matrix], [`grammat(..)`], [@eq-gram],
  [gates], [`S^+`], [@eq-gates],
  [adjoint of a product], [`(U_1 .. U_n)^+`], [@eq-adj],
  [block matrices], [`mat(..)^T`], [@eq-block],
)
