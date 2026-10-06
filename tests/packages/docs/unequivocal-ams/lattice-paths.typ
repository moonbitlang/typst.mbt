// unequivocal-ams 0.1.2: an AMS-style article with three authors (department, organization,
// location, email, url), abstract, `theorem` (numbered and unnumbered) and `proof`, a lemma
// built on the same figure kind, numbered equations with labels, references to theorems,
// sections and equations, a table and a drawn figure, footnotes and a bibliography.
// Engine paths: running header/footer from the page counter in context, figure kinds with a
// numbering closure reading counter(heading), counter reset in a heading show rule,
// springer-mathphys CSL style, justified paragraphs over five pages.
#import "@preview/unequivocal-ams:0.1.2": ams-article, proof, theorem

#show: ams-article.with(
  title: [Lattice paths below a line of rational slope],
  authors: (
    (
      name: "Tunde Abara",
      department: [Department of Mathematics],
      organization: [University of Ibadan],
      location: [Ibadan, Nigeria],
      email: "t.abara@math-ibadan.example",
      url: "https://math-ibadan.example/~abara",
    ),
    (
      name: "Maja Lindgren",
      department: [Matematiska institutionen],
      organization: [Norrstrand University],
      location: [Norrstrand, Sweden],
      email: "maja.lindgren@norrstrand.example",
    ),
    (
      name: "Clemens Voss",
      organization: [Institute for Discrete Structures],
      location: [Graz, Austria],
      url: "https://ids-graz.example/voss",
    ),
  ),
  abstract: [
    We count lattice paths with unit east and north steps that stay weakly below the line
    $a y = b x$ for coprime positive integers $a$ and $b$. A cycle lemma gives the number of
    paths ending on the line, a first-return decomposition gives a functional equation for
    the generating function, and for $b = 1$ both specialise to the Fuss--Catalan numbers.
    We include a table of small values and an elementary proof that the counts are
    log-convex along each diagonal.
  ],
  bibliography: bibliography("refs.bib"),
)

#set math.equation(numbering: "(1)")

// A lemma is a theorem-kind figure with another supplement; it shares the counter and
// the template's show rule.
#let lemma(body) = figure(
  body,
  kind: "theorem",
  supplement: [Lemma],
  numbering: n => counter(heading).display() + [#n],
)
#let corollary(body) = figure(
  body,
  kind: "theorem",
  supplement: [Corollary],
  numbering: n => counter(heading).display() + [#n],
)

// A lattice with a path and a boundary line, drawn with shapes.
#let lattice(n, m, steps, a, b, unit: 14pt) = box(width: n * unit, height: m * unit, {
  for i in range(n + 1) {
    place(left + bottom, dx: i * unit, line(angle: -90deg, length: m * unit, stroke: 0.3pt + luma(170)))
  }
  for j in range(m + 1) {
    place(left + bottom, dy: -j * unit, line(length: n * unit, stroke: 0.3pt + luma(170)))
  }
  // The boundary a y = b x from the origin to (n, n b / a).
  place(left + bottom, line(start: (0pt, 0pt), end: (n * unit, -n * b / a * unit), stroke: (thickness: 0.6pt, dash: "dashed")))
  let (x, y) = (0, 0)
  for s in steps.clusters() {
    let (nx, ny) = if s == "E" { (x + 1, y) } else { (x, y + 1) }
    place(left + bottom, line(start: (x * unit, -y * unit), end: (nx * unit, -ny * unit), stroke: 1.4pt))
    (x, y) = (nx, ny)
  }
  place(left + bottom, dx: -2pt, dy: 2pt, circle(radius: 2pt, fill: black))
  place(left + bottom, dx: x * unit - 2pt, dy: -y * unit + 2pt, circle(radius: 2pt, fill: black))
})

= Introduction

A _path_ in this paper is a finite sequence of unit steps $E = (1, 0)$ and $N = (0, 1)$
starting at the origin. For coprime positive integers $a$ and $b$ we say that a path is
_$(a, b)$-subdiagonal_ if every one of its points $(x, y)$ satisfies $a y <= b x$. The case
$a = b = 1$ is the classical ballot problem, solved by the reflection principle
@varga1987ballot; the case $b = 1$ leads to the Fuss--Catalan numbers
@okonkwo2004paths[Chapter 4]. For general slopes reflection fails, because the mirror image
of a lattice point in a line of slope $b \/ a$ is usually not a lattice point.#footnote[It
is one exactly when $a^2 + b^2$ divides $2 a (a y - b x)$, which for coprime $a, b$ with
$a b > 1$ excludes most points.]

Two tools replace it. The first is the cycle lemma in the form surveyed by Ferrand
@ferrand2009survey, which counts the paths that end _on_ the line. The second is the kernel
method of Ishikawa and Dubois @ishikawa2012kernel, which handles arbitrary endpoints at the
price of algebraic generating functions. We use the first in @sec:cycle and a
decomposition that avoids the second in @sec:gf.

Throughout, $P_(a,b)(n)$ denotes the number of $(a, b)$-subdiagonal paths from the origin to
$(a n, b n)$. Our main result is the following.

#theorem[
  For coprime positive integers $a, b$ and every $n >= 1$,
  $ P_(a,b)(n) = sum_(lambda tack.r n) product_(i >= 1) 1 / (m_i (lambda) !)
    (1 / ((a + b) i) binom((a + b) i, a i))^(m_i (lambda)), $ <eq:main>
  where the sum is over the partitions $lambda$ of $n$ and $m_i (lambda)$ is the number of
  parts of $lambda$ equal to $i$.
] <thm:main>

For $n = 1$ the sum in @eq:main has one term and gives the well-known count
$1 / (a + b) binom(a + b, a)$ of paths that touch the line only at their ends. @thm:main is
due, in an equivalent form, to Moreau @moreau1998thesis; a short proof by Kaplan
@kaplan2023note appeared while this paper was being written. Our proof in @sec:gf is
different from both and yields @cor:logconvex as a by-product.

#figure(
  lattice(7, 5, "EENEENENEENN", 7, 5),
  caption: [A $(7, 5)$-subdiagonal path from the origin to $(7, 5)$ and the line $7 y = 5 x$],
) <fig:path>

= The cycle lemma <sec:cycle>

Let $w = w_1 w_2 dots.c w_(a+b)$ be a word with $a$ letters $E$ and $b$ letters $N$. Give
each $E$ the weight $b$ and each $N$ the weight $-a$, so that the total weight is zero, and
write $s_k (w)$ for the weight of the prefix of length $k$.

#lemma[
  Among the $a + b$ cyclic shifts of $w$ exactly one has all proper prefix weights
  strictly positive, that is, $s_k > 0$ for $0 < k < a + b$.
] <lem:cycle>

#proof[
  Extend $s$ periodically. Because $a$ and $b$ are coprime, the values
  $s_0, s_1, dots, s_(a+b-1)$ are pairwise distinct: if $s_i = s_j$ with $i < j$, the
  factor $w_(i+1) dots.c w_j$ would have $e$ letters $E$ and $f$ letters $N$ with
  $b e = a f$, forcing $a | e$ and hence $e in {0, a}$, which is impossible for a proper
  factor of positive length. Let $m$ be the unique index where $s$ attains its minimum.
  The shift starting after position $m$ has prefix weights $s_(m+k) - s_m > 0$ for
  $0 < k < a + b$, and any other starting point $j$ has the non-positive prefix weight
  $s_m - s_j$ (or $s_(m + a + b) - s_j$).
]

A path is subdiagonal precisely when all its prefix weights are non-negative, so
@lem:cycle counts the paths that stay _strictly_ below the line after the first step, up
to the trivial shift of that step.

#corollary[
  The number of $(a, b)$-subdiagonal paths from the origin to $(a, b)$ that meet the line
  only at their endpoints is
  $ 1 / (a + b) binom(a + b, a). $ <eq:primitive>
] <cor:primitive>

#proof[
  There are $binom(a + b, a)$ words; by the argument of @lem:cycle no word equals one of
  its proper shifts, so they fall into classes of size exactly $a + b$, and each class
  contains one good word.
]

The situation changes at $(a n, b n)$ with $n > 1$: prefix weights may now repeat, the
minimum is attained up to $n$ times, and words can have non-trivial periods. The following
unnumbered statement records what survives.

#theorem(numbered: false)[
  A word with $a n$ letters $E$ and $b n$ letters $N$ whose minimum prefix weight is
  attained exactly $r$ times has exactly $r$ cyclic shifts, counted with multiplicity,
  that are subdiagonal.
]

= The generating function <sec:gf>

== First returns

Let
$ F(t) = sum_(n >= 0) P_(a,b)(n) t^n $ <eq:F>
and let $G(t) = sum_(n >= 1) g_n t^n$ where $g_n$ counts subdiagonal paths to $(a n, b n)$
that meet the line only at their endpoints. Cutting a path at its first return to the line
gives $F = 1 + G F$, that is,
$ F(t) = 1 / (1 - G(t)). $ <eq:FG>
By @cor:primitive we know $g_1$, but for $n >= 2$ the cycle lemma no longer applies
verbatim.

== Counting with marked returns

Call a pair $(w, j)$ a _marked word_ if $w$ has $a n$ letters $E$ and $b n$ letters $N$ and
$j$ is a position at which the periodic extension of $s$ attains its minimum. The cyclic
group of order $(a + b) n$ acts freely on marked words, and each orbit contains exactly one
marked word with $j = 0$, which is a subdiagonal path. Counting marked words in two ways,
by $w$ first and by orbits first, gives
$ sum_w r(w) = (a + b) n dot P_(a,b)(n) \/ n dot [ "average number of returns" ], $
and the bookkeeping is cleanest on the level of series.

#lemma[
  With $B(t) = sum_(i >= 1) 1 / ((a + b) i) binom((a + b) i, a i) t^i$ we have
  $ F(t) = exp B(t). $ <eq:exp>
] <lem:exp>

#proof[
  Differentiate @eq:FG logarithmically:
  $ t F'(t) / F(t) = (t G'(t)) / (1 - G(t)) = sum_(n >= 1) c_n t^n, $ <eq:log>
  where $c_n$ counts pairs of a subdiagonal path to $(a n, b n)$ and a marked step of its
  last primitive factor. Rotating the path so that the marked step comes first is a
  bijection from such pairs to arbitrary words with $a n$ letters $E$ and $b n$ letters $N$
  that _begin a subdiagonal shift at a minimum_; by the unnumbered theorem of @sec:cycle
  every word is obtained exactly $a n + b n$ times out of $(a + b) n$ rotations of its
  marked versions, up to the factor $a\/(a + b)$ for the choice of a first step $E$. Hence
  $ c_n = 1 / (a + b) binom((a + b) n, a n) = n dot [t^n] B(t), $
  so the right-hand side of @eq:log equals $t B'(t)$, and integrating with $F(0) = 1$ gives
  @eq:exp.
]

#proof[
  _(of @thm:main)_ Expand the exponential in @eq:exp:
  $ exp B(t) = product_(i >= 1) sum_(m >= 0) 1 / m! (beta_i t^i)^m,
    quad beta_i = 1 / ((a + b) i) binom((a + b) i, a i), $
  and collect the coefficient of $t^n$. A choice of exponents $(m_i)$ with
  $sum_i i m_i = n$ is a partition of $n$, and its contribution is the summand of
  @eq:main.
]

== Small values

@tab:values lists $P_(a,b)(n)$ for the first few slopes. The row $(1, 1)$ is the Catalan
sequence and the row $(2, 1)$ the Fuss--Catalan numbers $1 / (2 n + 1) binom(3 n, n)$, in
agreement with @okonkwo2004paths; the row $(3, 2)$ is the first that is not of this type
and was computed by Abara, Lindgren and Voss in @abara2019staircase by a determinant.

#figure(
  table(
    columns: 7,
    align: (center,) + (right,) * 6,
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header($(a, b)$, $n = 1$, $2$, $3$, $4$, $5$, $6$),
    table.hline(stroke: 0.4pt),
    $(1, 1)$, $1$, $2$, $5$, $14$, $42$, $132$,
    $(2, 1)$, $1$, $3$, $12$, $55$, $273$, $1428$,
    $(3, 1)$, $1$, $4$, $22$, $140$, $969$, $7084$,
    $(3, 2)$, $2$, $23$, $377$, $7229$, $151491$, $3361598$,
    $(5, 2)$, $3$, $99$, $4830$, $278085$, $17599941$, $1184938608$,
    table.hline(stroke: 0.6pt),
  ),
  caption: [The numbers $P_(a,b)(n)$ of subdiagonal paths from the origin to $(a n, b n)$],
) <tab:values>

=== A check
For $(a, b) = (3, 2)$ and $n = 2$ the partitions are $2$ and $1 + 1$, with
$beta_1 = 1 / 5 binom(5, 3) = 2$ and $beta_2 = 1 / 10 binom(10, 6) = 21$, so @eq:main gives
$21 + 2^2 \/ 2 = 23$, as in the table.

=== A second check
For $n = 3$ we need $beta_3 = 1 / 15 binom(15, 9) = 1001 \/ 3$, and the three partitions
contribute $1001 \/ 3 + 2 dot 21 + 2^3 \/ 6 = 377$.

= Log-convexity <sec:convex>

#corollary[
  For fixed coprime $a, b$ the sequence $P_(a,b)(n)$ is log-convex:
  $ P_(a,b)(n - 1) P_(a,b)(n + 1) >= P_(a,b)(n)^2 quad "for all" n >= 1. $ <eq:logconvex>
] <cor:logconvex>

#proof[
  The coefficients $beta_i$ of $B$ satisfy $beta_(i-1) beta_(i+1) >= beta_i^2$ and
  $i beta_i$ is increasing; both follow from the ratio
  $ beta_(i+1) / beta_i = i / (i + 1) dot
    product_(k=1)^(a+b) ((a + b) i + k) / (product_(k=1)^a (a i + k) product_(k=1)^b (b i + k)), $
  which is increasing in $i$. The exponential of a series with non-negative, log-convex
  coefficients $(i beta_i)$ again has log-convex coefficients; this is a classical closure
  property, proved for instance in @okonkwo2004paths[Section 7.3]. Applying it to @eq:exp
  gives @eq:logconvex.
]

The inequality is far from tight: for $(a, b) = (3, 2)$ the ratios
$P(n + 1) \/ P(n)$ are $11.5$, $16.39$, $19.18$, $20.96$ and $22.19$, approaching the
growth rate $5^5 \/ (3^3 2^2) approx 28.94$ from below.

#lorem(120)

== Asymptotics

By Stirling's formula $beta_i tilde C i^(-3 \/ 2) rho^i$ with
$rho = (a + b)^(a + b) \/ (a^a b^b)$, so $B$ has a square-root singularity at $1 \/ rho$
where it stays finite. Consequently
$ P_(a,b)(n) tilde C e^(B(1 \/ rho)) n^(-3 \/ 2) rho^n, quad
  C = 1 / (a + b) sqrt((a + b) / (2 pi a b)). $ <eq:asym>
For the classical case, @eq:asym reads $4^n \/ (sqrt(pi) n^(3 \/ 2))$ times
$e^(B(1 \/ 4)) \/ 2 = 1$, as it must.

#lorem(160)

= Open questions

+ Is there a bijective proof of @eq:exp that does not pass through the logarithmic
  derivative?
+ Does @cor:logconvex extend to paths ending at arbitrary points below the line, where
  the kernel method @ishikawa2012kernel gives algebraic but not explicit series?
+ For which boundaries other than lines does a formula of the shape of @eq:main hold?
  The staircase boundaries of @abara2019staircase suggest that periodicity is essential.

#lorem(80)
