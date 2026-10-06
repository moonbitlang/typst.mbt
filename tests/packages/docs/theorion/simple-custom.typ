// theorion 0.6.0: simple cosmos, custom environments from make-frame (own
// counter, counter shared with another frame, counter inherited from another
// richer counter), zero-fill/leading-zero, inherited levels, indent modes,
// QED symbols, hidden answers, supplements in several languages.
// Stresses dictionaries of closures, query before/after, state.final,
// figure kinds with show rules, par first-line-indent repair.
#import "@preview/theorion:0.6.0": *
#import cosmos.simple: *
#show: show-theorion

#set page(width: 13cm, height: 18cm, margin: 1.4cm, numbering: "i")
#set text(size: 10pt)
#set par(justify: true, first-line-indent: 1.2em)
#set heading(numbering: "1.1")

// A claim with its own counter that follows the first heading level.
#let (claim-counter, claim-box, claim, show-claim) = make-frame(
  "claim",
  (en: "Claim", de: "Behauptung", fr: "Affirmation"),
  inherited-levels: 1,
  render: (prefix: none, title: "", full-title: auto, body) => block(
    width: 100%,
    inset: (left: 0.8em, y: 0.4em),
    stroke: (left: 2pt + eastern),
  )[#smallcaps(full-title). #body],
)
#show: show-claim

// A step that counts below the claims: (claim number).(step).
#let (step-counter, step-box, step, show-step) = make-frame(
  "step",
  "Step",
  inherited-from: claim-counter,
  numbering: "1.1.a",
  render: (prefix: none, title: "", full-title: auto, body) => [#underline(full-title): #body],
)
#show: show-step

// An observation that shares the claims' counter.
#let (obs-counter, obs-box, obs, show-obs) = make-frame(
  "observation",
  "Observation",
  counter: claim-counter,
  render: (prefix: none, title: "", full-title: auto, body) => par(first-line-indent: 0pt)[_#full-title._ #body],
)
#show: show-obs

= Sequences

== Monotone sequences

The simple cosmos sets statements like a classical article. Paragraphs in
this document have a first-line indent, which the environments repair.

#definition[
  A sequence $(a_n)$ of real numbers is _increasing_ if $a_n <= a_(n+1)$ for
  all $n$, and _bounded_ if there is a $C$ with $|a_n| <= C$ for all $n$.
] <def:mono>

A paragraph between two environments, long enough to show its indent on the
first line and to wrap once or twice.

#theorem[Monotone convergence][
  Every increasing bounded sequence converges, and its limit is the supremum
  of its terms.
] <thm:mct>

#proof[
  Let $s = sup_n a_n$, which exists by boundedness. Given $epsilon > 0$ there
  is an $N$ with $a_N > s - epsilon$, and then for $n >= N$
  $ s - epsilon < a_N <= a_n <= s. $
]

#lemma[
  A sequence that is increasing in the sense of @def:mono is bounded below.
]

#claim[
  The sequence $a_n = (1 + 1/n)^n$ is increasing.
] <claim:e>

#step[By the inequality of arithmetic and geometric means applied to one $1$ and $n$ copies of $1 + 1/n$.] <step:amgm>
#step[Rearranging gives $a_n <= a_(n+1)$.]

#claim[Boundedness][
  For all $n$ one has $a_n < 3$.
] <claim:bound>

#step[Expand by the binomial theorem.]
#step[Compare with a geometric series.] <step:geo>

#obs[
  @claim:e and @claim:bound together with @thm:mct show that $(a_n)$
  converges. The steps are @step:amgm and @step:geo; without supplement:
  @step:geo[-].
] <obs:e>

#remark[
  The limit is Euler's number; see @obs:e.
]

= Series <sec:series>

#set-inherited-levels(1)
#set-theorion-numbering("1-1")

== Tests

From here on theorems inherit one heading level and print with a dash.

#theorem[Comparison test][
  If $0 <= a_n <= b_n$ and $sum b_n$ converges, then $sum a_n$ converges.
] <thm:comparison>

#claim[
  The series $sum 1/n^2$ converges.
]

#step[Compare with $sum 1/(n(n-1))$, which telescopes, and use @thm:comparison.]

#set-qed-symbol[#math.qed]

#proof[A second proof][
  Condense: $sum 2^k dot 2^(-2k) = sum 2^(-k)$ converges.
]

#proof(qed: $suit.spade$)[
  A proof may also choose its own end mark.
]

#set-indent-mode((amount: 2em, all: true))

#example[
  With the indent mode set to a dictionary, this body is indented by two ems.

  And so is its second paragraph.
]

#set-indent-mode(none)

#note[
  With the indent mode `none`, the package leaves the indent alone.
]

#set-indent-mode(auto)

== Exercises without answers

#set-result("noanswer")

#problem[
  Does $sum 1/(n log n)$ converge?
]

#solution[
  No; this answer is hidden by the result mode.
]

#exercise[
  Decide the convergence of $sum (n!)/n^n$.
]

#proof[Hidden as well.]

// Unnumbered sections show the zero-fill and leading-zero options.
#set heading(numbering: none)
#set-result("answer")
#set-inherited-levels(2)
#set-theorion-numbering("1.1")
#counter(heading).update(0)

= Loose ends

#set-zero-fill(true)
#set-leading-zero(true)

#conjecture[
  With zero fill and leading zeros, this number keeps both inherited levels.
] <conj:zero>

#set-zero-fill(false)
#set-leading-zero(false)

#proposition[
  And this one drops the leading zero again. See @conj:zero.
]

= Translations

#for lang in ("en", "de", "fr", "es", "it", "pt", "nl", "pl", "sv") [
  #set text(lang: lang)
  #theorem-box(outlined: false)[#upper(lang)][$1 + 1 = 2$.]
  #claim-box[$2 + 2 = 4$.]
]

#outline(title: [Claims], target: figure.where(kind: "claim"))
