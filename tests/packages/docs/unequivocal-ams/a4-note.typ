// unequivocal-ams 0.1.2: the other option values: A4 paper (absolute margins), two authors
// (joined by "and", alternating in the header), no abstract, theorems whose counter is
// reset by each level-1 heading, proofs ending in display math and in a list, lists with the
// template's indents, links (mono font fallback), cite forms, and equation numbering per
// section set by the document. Engine paths: counter(heading).display() inside a figure
// numbering, numbering functions, `cite(form: ..)`, header on even/odd pages, weak spacing.
#import "@preview/unequivocal-ams:0.1.2": ams-article, proof, theorem

#show: ams-article.with(
  title: [Three remarks on sums of two triangular numbers],
  authors: (
    (
      name: "Céline Moreau",
      department: [Laboratoire de Mathématiques],
      organization: [Université de Clermont],
      location: [Clermont-Ferrand, France],
      email: "celine.moreau@math-clermont.example",
    ),
    (
      name: "Dov Kaplan",
      organization: [Negev Institute of Science],
      location: [Be'er Sheva, Israel],
      email: "kaplan@negev-inst.example",
      url: "https://negev-inst.example/people/kaplan",
    ),
  ),
  paper-size: "a4",
  bibliography: bibliography("refs.bib", full: true),
)

// Equations are numbered within sections: (2.3) is the third equation of section 2.
#set math.equation(numbering: n => {
  let sec = counter(heading).get().first()
  numbering("(1.1)", sec, n)
})
#show heading.where(level: 1): it => it + counter(math.equation).update(0)

#let triangular(n) = int(n * (n + 1) / 2)
#let remark(body) = figure(body, kind: "theorem", supplement: [Remark], numbering: n => counter(heading).display() + [#n])

= Triangular numbers

The $n$-th triangular number is $T_n = n (n + 1) \/ 2$; the first ten are
#range(1, 11).map(n => str(triangular(n))).join(", ", last: " and "). Completing the square
turns statements about them into statements about odd squares:
$ 8 T_n + 1 = (2 n + 1)^2. $ <eq:square>

#theorem[
  A non-negative integer $m$ is a sum of two triangular numbers if and only if $4 m + 1$ is
  a sum of two squares.
] <thm:two>

#proof[
  By @eq:square, $m = T_x + T_y$ is equivalent to
  $ 8 m + 2 = (2 x + 1)^2 + (2 y + 1)^2. $ <eq:odd>
  If $4 m + 1 = u^2 + v^2$ then $u$ and $v$ have different parity and
  $8 m + 2 = (u + v)^2 + (u - v)^2$ is a sum of two odd squares. Conversely, from @eq:odd
  put $u = x + y + 1$ and $v = x - y$ to get
  $ u^2 + v^2 = ((2 x + 1)^2 + (2 y + 1)^2) / 2 = 4 m + 1. $
]

The criterion of @thm:two was known to the authors of the classical treatises; see
#cite(<okonkwo2004paths>, form: "prose") for a combinatorial reading and
#cite(<varga1987ballot>, supplement: [p.~101]) for the earliest statement we could find.
A machine-checked version is at #link("https://example.org/formal/triangular").

== Density
Since a positive proportion of integers is _not_ a sum of two squares, the same holds for
sums of two triangular numbers.

== The first exceptions
The integers below 30 that are not of the form $T_x + T_y$ are
#{
  let sums = ()
  for x in range(0, 9) {
    for y in range(0, 9) {
      sums.push(triangular(x) + triangular(y))
    }
  }
  range(0, 30).filter(m => m not in sums).map(str).join(", ")
}.

=== A pattern
All of them are congruent to $5$ or $8$ modulo $9$ or have $4 m + 1$ divisible by a prime
$p equiv 3 mod 4$ to an odd power, which is the same condition in disguise.

= Counting representations

Write $r(m)$ for the number of pairs $(x, y)$ of non-negative integers with
$T_x + T_y = m$.

#theorem[
  For every $m >= 0$,
  $ r(m) = d_1 (4 m + 1) - d_3 (4 m + 1), $ <eq:count>
  where $d_j (k)$ is the number of positive divisors of $k$ congruent to $j$ modulo $4$.
] <thm:count>

#proof[
  The map of the previous proof is a bijection between the solutions of @eq:odd in positive
  odd integers and the representations $4 m + 1 = u^2 + v^2$ with $u > 0$ odd and $v$
  even of either sign; there are $r_2 (4 m + 1) \/ 4$ of the latter, and Jacobi's formula
  $r_2 (k) = 4 (d_1 (k) - d_3 (k))$ finishes the proof. The steps are:
  - pass from $m$ to $4 m + 1$ by @eq:square;
  - identify ordered odd pairs with pairs of opposite parity;
  - divide by the four sign changes that the bijection has already used up.
]

#remark[
  Formula @eq:count shows at once that $r(m)$ is unbounded: for $4 m + 1 = 5^k$ it gives
  $r(m) = k + 1$.
] <rem:unbounded>

#figure(
  table(
    columns: 11,
    align: center,
    $m$, ..range(0, 10).map(m => $#m$),
    $4 m + 1$, ..range(0, 10).map(m => $#(4 * m + 1)$),
    $r(m)$, $1$, $2$, $1$, $2$, $2$, $0$, $3$, $2$, $0$, $2$,
  ),
  caption: [The number of representations as an ordered sum of two triangular numbers],
) <tab:r>

@tab:r agrees with @thm:count: for instance $4 dot 6 + 1 = 25$ has the divisors $1, 5, 25$,
all congruent to $1$, so $r(6) = 3$, the representations being $6 + 0$, $0 + 6$ and $3 + 3$.

+ The zeros of $r$ are exactly the exceptions listed after @thm:two.
+ The average of $r(m)$ over $m <= M$ tends to $pi \/ 4$.
  + This is the area of a quarter disc of radius $sqrt(2 M)$ divided by $2 M$, counting
    lattice points with odd coordinates.
  + The error term is that of the Gauss circle problem.

= A picture

#figure(
  {
    let unit = 9pt
    box(width: 11 * unit, height: 11 * unit, {
      for x in range(0, 11) {
        for y in range(0, 11) {
          let m = triangular(x) + triangular(y)
          let shade = if calc.rem(m, 3) == 0 { luma(60) } else if calc.rem(m, 3) == 1 { luma(150) } else { luma(225) }
          place(left + bottom, dx: x * unit, dy: -y * unit, square(size: unit - 1pt, fill: shade))
        }
      }
    })
  },
  caption: [The residue of $T_x + T_y$ modulo $3$ for $0 <= x, y <= 10$: the pattern has period $3$ in both directions],
) <fig:mod3>

@fig:mod3 illustrates the third remark: $T_n mod 3$ takes the values $0, 1, 0$
periodically, so $T_x + T_y equiv 2 mod 3$ happens only when both indices are congruent to
$1$, which is one case in nine. @rem:unbounded and the periodicity together imply that
$r$ is unbounded on each residue class modulo $3$.

#theorem(numbered: false)[
  For each residue $c$ modulo $3$ the function $r$ is unbounded on the integers
  $m equiv c mod 3$.
]

#proof[
  Take $4 m + 1 = 5^k q$ with a prime $q equiv 1 mod 4$ chosen in the right class modulo
  $3$, which exists by Dirichlet's theorem; then
  $ r(m) = 2 (k + 1). $
]

#lorem(140)

= Acknowledgements

#lorem(40)
