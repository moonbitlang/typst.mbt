// mitex 0.2.7: a longer document in which LaTeX formulas (`mitex`, `mi`, numbered and
// labelled) and native Typst math share one equation counter, are referenced from both
// sides, sit in tables, lists, footnotes and figures, and use macros defined once in a
// preamble string. Many plugin calls (about ninety) in one compilation.
// Engine: wasm plugin called repeatedly with different inputs, eval scope reuse, equation
// numbering and supplements, references into evaluated content, page breaks between formulas.
#import "@preview/mitex:0.2.7": mi, mitex, mitext, mitex-convert

#set page(width: 155mm, height: 200mm, margin: (x: 14mm, y: 15mm), numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.1")
#set math.equation(numbering: "(1)", supplement: [Eq.])
#show link: set text(fill: rgb("#1a5276"))

// Macros shared by all LaTeX formulas of the document.
#let preamble = `
  \newcommand{\dd}{\mathrm{d}}
  \newcommand{\pd}[2]{\frac{\partial #1}{\partial #2}}
  \newcommand{\avg}[1]{\left\langle #1 \right\rangle}
  \newcommand{\kB}{k_{\mathrm{B}}}
  \newcommand{\vect}[1]{\boldsymbol{#1}}
`.text
#let tex(body, ..args) = mitex(preamble + body.text, ..args)
#let itex(body) = mi(preamble + body.text)

#align(center)[
  #text(14pt, weight: "bold")[Heat, Diffusion and Random Walks] \
  lecture notes, week 6
]

#outline(depth: 2)

= The heat equation

== Statement

The temperature #itex(`u(\vect{x}, t)`) in a homogeneous body obeys

#tex(`
  \pd{u}{t} = \kappa \, \nabla^2 u ,
  \qquad
  \kappa = \frac{\lambda}{\rho \, c_p} .
`) <eq-heat>

The same equation in native Typst math, for comparison, in one dimension:

$ (partial u) / (partial t) = kappa (partial^2 u) / (partial x^2), quad u(x, 0) = u_0(x). $ <eq-heat-1d>

@eq-heat was typed in LaTeX and @eq-heat-1d in Typst; both take their numbers
from the same counter. Units: #itex(`[\kappa] = \mathrm{m^2\,s^{-1}}`), and for
copper #itex(`\kappa \approx 1.1 \times 10^{-4}\ \mathrm{m^2/s}`).

== Fundamental solution

A point source at the origin spreads as a Gaussian,

#tex(`
  G(x, t) = \frac{1}{\sqrt{4 \pi \kappa t}} \exp\!\left( - \frac{x^2}{4 \kappa t} \right),
  \qquad
  \int_{-\infty}^{\infty} G(x, t) \, \dd x = 1 ,
`) <eq-kernel>

and every solution on the line is a convolution with it:

#tex(`
  u(x, t) = (G(\cdot, t) * u_0)(x) = \int_{-\infty}^{\infty} G(x - y, t) \, u_0(y) \, \dd y .
`) <eq-conv>

The width of the kernel in @eq-kernel grows like #itex(`\sqrt{2 \kappa t}`): to
diffuse twice as far takes four times as long.#footnote[In LaTeX:
  #itex(`\avg{x^2} = 2 \kappa t`); in Typst: $chevron.l x^2 chevron.r = 2 kappa t$.]

== Separation of variables

On a rod of length #itex(`L`) with cold ends, the ansatz #itex(`u = X(x) T(t)`) gives

#tex(`
  \begin{aligned}
    \frac{T'}{\kappa T} &= \frac{X''}{X} = -\mu^2 , \\
    X_n(x) &= \sin \frac{n \pi x}{L} , \qquad \mu_n = \frac{n \pi}{L} , \\
    u(x, t) &= \sum_{n=1}^{\infty} b_n \, e^{-\kappa \mu_n^2 t} \, \sin \frac{n \pi x}{L} ,
  \end{aligned}
`) <eq-series>

with the coefficients

#tex(`
  b_n = \frac{2}{L} \int_0^L u_0(x) \sin \frac{n \pi x}{L} \, \dd x .
`, numbering: none)

The last formula was set without a number, so the counter is not advanced;
the next numbered one continues after @eq-series.

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    align: (center, center, center),
    inset: 5pt,
    table.header[*Boundary*][*Eigenfunctions (LaTeX)*][*Eigenvalues (Typst)*],
    [cold--cold], itex(`\sin \frac{n \pi x}{L}`), $mu_n = (n pi) / L$,
    [insulated], itex(`\cos \frac{n \pi x}{L}`), $mu_n = (n pi) / L, n >= 0$,
    [cold--insulated], itex(`\sin \frac{(2n - 1) \pi x}{2L}`), $mu_n = ((2n - 1) pi) / (2L)$,
    [periodic], itex(`e^{2 \pi i n x / L}`), $mu_n = (2 pi n) / L$,
  ),
  caption: [Eigenfunctions for the rod; compare #itex(`X_n`) in @eq-series],
) <tab-eigen>

= Random walks

== Discrete steps

A walker jumps #itex(`\pm a`) every #itex(`\tau`) seconds. After #itex(`N`) steps,

#tex(`
  P_N(m) = \binom{N}{\frac{N + m}{2}} \, 2^{-N} ,
  \qquad
  \avg{m} = 0, \quad \avg{m^2} = N .
`) <eq-binom>

Stirling's formula turns @eq-binom into the kernel of @eq-kernel:

#tex(`
  P_N(m) \;\xrightarrow{N \to \infty}\; \sqrt{\frac{2}{\pi N}} \, e^{-m^2 / 2N} ,
  \qquad
  \kappa = \lim_{a, \tau \to 0} \frac{a^2}{2 \tau} .
`) <eq-limit>

- The master equation: #itex(`P_{N+1}(m) = \tfrac12 P_N(m - 1) + \tfrac12 P_N(m + 1)`).
- Subtracting #itex(`P_N(m)`) on both sides gives a discrete second difference.
- In the limit of @eq-limit this is exactly @eq-heat-1d.

+ Generating function: #itex(`\sum_m P_N(m) z^m = \left( \frac{z + z^{-1}}{2} \right)^N`).
+ Characteristic function: #itex(`\avg{e^{i k m}} = \cos^N k`).
+ Return probability: #itex(`P_{2n}(0) = \binom{2n}{n} 4^{-n} \sim (\pi n)^{-1/2}`).

== Higher dimensions

In #itex(`d`) dimensions the walker returns to its origin with probability

#tex(`
  p_d =
  \begin{cases}
    1 & d = 1, 2 , \\
    1 - \dfrac{1}{u_d} < 1 & d \ge 3 ,
  \end{cases}
  \qquad
  u_d = \frac{d}{(2\pi)^d} \int_{[-\pi, \pi]^d} \frac{\dd^d k}{d - \sum_{j=1}^{d} \cos k_j} .
`) <eq-polya>

For the cubic lattice @eq-polya gives #itex(`p_3 \approx 0.3405`). The covariance of
the position after #itex(`N`) steps is

#tex(`
  \avg{\vect{r} \, \vect{r}^{\mathsf{T}}} =
  \frac{N a^2}{d}
  \begin{pmatrix}
    1      & 0      & \cdots & 0 \\
    0      & 1      & \cdots & 0 \\
    \vdots & \vdots & \ddots & \vdots \\
    0      & 0      & \cdots & 1
  \end{pmatrix} .
`) <eq-cov>

= Einstein's relation

A particle of radius #itex(`r`) in a fluid of viscosity #itex(`\eta`) at temperature
#itex(`T`) has

#tex(`
  D = \mu \, \kB T = \frac{\kB T}{6 \pi \eta r} ,
`) <eq-einstein>

which in Typst reads $D = (k_"B" T) / (6 pi eta r)$. With @eq-einstein and the
kernel of @eq-kernel, the mean square displacement in three dimensions is
#itex(`\avg{\vect{r}^2} = 6 D t`). Mixed in one line: $D$ from Typst, #itex(`\kB`) from LaTeX,
$sqrt(6 D t)$ from Typst, #itex(`\sqrt{6 D t}`) from LaTeX.

#tex(`
  \underbrace{\pd{\rho}{t}}_{\text{change}}
  = \underbrace{D \, \nabla^2 \rho}_{\text{diffusion}}
  - \underbrace{\nabla \cdot (\mu \vect{F} \rho)}_{\text{drift}} ,
  \qquad
  \rho_{\mathrm{eq}} \propto \exp\left( - \frac{U}{\kB T} \right) .
`) <eq-fp>

== Summary of the numbered equations

#table(
  columns: (auto, 1fr, auto),
  inset: 4pt,
  stroke: 0.4pt,
  table.header[*Ref.*][*Content*][*Source*],
  [@eq-heat], [heat equation], [LaTeX],
  [@eq-heat-1d], [the same in one dimension], [Typst],
  [@eq-kernel], [Gaussian kernel], [LaTeX],
  [@eq-conv], [convolution], [LaTeX],
  [@eq-series], [Fourier series on the rod], [LaTeX],
  [@eq-binom], [binomial distribution], [LaTeX],
  [@eq-limit], [continuum limit], [LaTeX],
  [@eq-polya], [return probability], [LaTeX],
  [@eq-cov], [covariance matrix], [LaTeX],
  [@eq-einstein], [Einstein relation], [LaTeX],
  [@eq-fp], [Fokker--Planck equation], [LaTeX],
)

The source that the plugin produced for @eq-einstein is
#raw(mitex-convert(`D = \frac{k T}{6 \pi \eta r}`.text)).
