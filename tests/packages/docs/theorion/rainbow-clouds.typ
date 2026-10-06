// theorion 0.6.0: rainbow cosmos for the main text and clouds cosmos for an
// insert (both share the query-based counters), custom fills, nested
// environments (corollary inside a theorem), numbered equations next to
// proofs, a combined outline of several kinds, pages in two columns.
// Stresses nested figures, counters inherited through nesting, ref show
// rules stacked per kind, breakable blocks with one-sided strokes.
#import "@preview/theorion:0.6.0": *
#import cosmos.rainbow: *
#import cosmos.clouds as clouds
#show: show-theorion

#set page(width: 14cm, height: 19cm, margin: (x: 1.3cm, y: 1.6cm), footer: context align(right, text(size: 8pt)[Probability primer · #counter(page).display()]))
#set text(size: 9.5pt)
#set par(justify: true)
#set heading(numbering: "I.1")
#set math.equation(numbering: "(1)")
#set-theorion-numbering("I.1.1")

#let theorem = theorem.with(fill: blue.darken(10%))
#let theorem-box = theorem-box.with(fill: blue.darken(10%))

#outline(
  title: [Statements],
  target: figure.where(kind: "theorem").or(figure.where(kind: "definition")).or(figure.where(kind: "corollary")),
)

= Events

== Probability spaces

#definition[
  A _probability space_ is a triple $(Omega, cal(F), P)$ where $cal(F)$ is a
  $sigma$-algebra on $Omega$ and $P$ a measure on $cal(F)$ with $P(Omega) = 1$.
] <def:space>

#axiom[Countable additivity][
  For pairwise disjoint events $A_1, A_2, dots$
  $ P(union.big_n A_n) = sum_n P(A_n). $ <eq:sigma>
] <ax:sigma>

#theorem[Union bound][
  For arbitrary events $A_1, A_2, dots$ in a space as in @def:space,
  $ P(union.big_n A_n) <= sum_n P(A_n). $ <eq:union>

  #corollary[
    A countable union of null sets is a null set.
  ] <cor:null>

  The corollary above is numbered below the theorem that contains it.
] <thm:union>

#proof[
  Make the events disjoint, $B_n = A_n without union.big_(k < n) A_k$, and
  apply @eq:sigma from @ax:sigma to the $B_n$:
  $ P(union.big_n A_n) = sum_n P(B_n) <= sum_n P(A_n). $
]

Equation @eq:union is used again in @cor:null and in @thm:bc[!!].

#property[
  If $A subset B$ then $P(A) <= P(B)$.
]

#assumption[
  All random variables below are defined on one fixed probability space.
]

== Limits of events

#theorem[Borel–Cantelli][
  If $sum_n P(A_n) < oo$, then almost surely only finitely many of the
  events $A_n$ occur.
] <thm:bc>

#proof[
  For every $N$ the event that infinitely many occur is contained in
  $union.big_(n >= N) A_n$, whose probability is at most the tail
  $sum_(n >= N) P(A_n)$ by @thm:union. The tails tend to zero.
]

#lemma[
  The converse holds for independent events.
] <lem:bc2>

#conjecture[
  Nobody reads a lemma without a proof twice.
]

#caution-block[
  Independence cannot be dropped in @lem:bc2: take $A_n = A$ for all $n$.
]

= Random variables

== The clouds cosmos as an insert

The boxes in this section are drawn by the other cosmos; numbers continue
because both use the same counters.

#let cloud-theorem = clouds.theorem.with(fill: aqua.lighten(70%), radius: 0pt)

#clouds.definition[Expectation][
  For a non-negative random variable $X$ put $E[X] = integral X dif P$.
] <def:exp>

#cloud-theorem[Markov's inequality][
  For $X >= 0$ and $a > 0$,
  $ P(X >= a) <= E[X] / a. $ <eq:markov>
] <thm:markov>

#clouds.corollary[Chebyshev][
  $P(|X - mu| >= k sigma) <= 1 / k^2$ for $k > 0$.
] <cor:cheb>

#clouds.proposition(fill: yellow.lighten(60%))[
  @eq:markov applied to $(X - mu)^2$ gives @cor:cheb; both rest on @def:exp.
]

#clouds.example[
  A fair die shows at least five with probability $1/3$; @thm:markov only
  gives $3.5 / 5 = 0.7$.
]

#clouds.remark[A remark in the clouds style.]
#clouds.note[A note in the clouds style.]
#clouds.problem[Find a variable for which @thm:markov[-] is sharp.]

== In two columns

#columns(2, gutter: 1em)[
  #theorem(breakable: true)[Weak law][
    Let $X_1, X_2, dots$ be independent with mean $mu$ and variance
    $sigma^2$. Then for every $epsilon > 0$
    $ P(|S_n / n - mu| >= epsilon) -> 0. $

    #lorem(45)
  ] <thm:wlln>

  #proof[
    The variance of $S_n / n$ is $sigma^2 / n$; apply @cor:cheb.
    #lorem(30)
  ]

  #exercise[
    Show that @thm:wlln fails without a finite mean. #lorem(20)
  ]

  #postulate[
    A column break inside a statement is acceptable.
  ]

  #remark[
    #lorem(35)
  ]
]

== Restated in rainbow

#theorion-restate(filter: it => it.identifier == "corollary", render: it => it.render)
