// mitex 0.2.7: LaTeX converted at compile time by the package's WebAssembly plugin: inline
// (`mi`) and display (`mitex`) math, environments (aligned, cases, matrix family, array),
// user macros, colours, text mode (`mitext`: sections, lists, labels and references),
// `mitex-convert` output, raw blocks turned into math by show rules.
// Engine: wasm plugin calls with bytes, `eval` of generated math/markup with a large scope,
// show rules on raw, equation numbering and references.
#import "@preview/mitex:0.2.7": mi, mitex, mitext, mimath, mitex-convert

#set page(width: 150mm, height: 185mm, margin: (x: 13mm, y: 14mm), numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.")
#show raw.where(lang: "latex", block: true): it => mitex(it.text)
#show raw.where(lang: "tex", block: false): it => mi(it.text)

#align(center, text(14pt, weight: "bold")[A Tour of Fourier Series, Typed in LaTeX])

= Inline and display

A function #mi(`f`) of period #mi("2\pi") is expanded in the functions
#mi(`\cos nx`) and #mi(`\sin nx`); the coefficients are #mi(`a_n, b_n \in \mathbb{R}`)
and, written with a show rule on inline raw text, ```tex c_n = \tfrac12 (a_n - i b_n)```
for ```tex n \ge 1```. The series itself:

#mitex(`
  f(x) \sim \frac{a_0}{2} + \sum_{n=1}^{\infty} \left( a_n \cos nx + b_n \sin nx \right),
  \qquad
  a_n = \frac{1}{\pi} \int_{-\pi}^{\pi} f(x) \cos nx \, \mathrm{d}x .
`)

A block of raw LaTeX with the language tag is converted by the other show rule:

```latex
\left\| f - S_N f \right\|_2^2
  = \| f \|_2^2 - \pi \left( \frac{a_0^2}{2} + \sum_{n=1}^{N} \bigl( a_n^2 + b_n^2 \bigr) \right)
  \xrightarrow{\; N \to \infty \;} 0
```

= Environments

#mitex(`
  \begin{aligned}
    S_N f(x) &= \frac{a_0}{2} + \sum_{n=1}^{N} (a_n \cos nx + b_n \sin nx) \\
             &= \sum_{n=-N}^{N} c_n e^{inx} \\
             &= \frac{1}{2\pi} \int_{-\pi}^{\pi} f(t) \, D_N(x - t) \, \mathrm{d}t ,
  \end{aligned}
  \qquad
  D_N(u) = \frac{\sin\left( N + \frac12 \right) u}{\sin \frac{u}{2}}
`)

#mitex(`
  \operatorname{sq}(x) =
  \begin{cases}
    1  & 0 < x < \pi, \\
    0  & x = 0, \\
    -1 & -\pi < x < 0,
  \end{cases}
  \qquad
  |x| = \begin{cases} x & \text{if } x \ge 0 \\ -x & \text{otherwise} \end{cases}
`)

#mitex(`
  \begin{pmatrix} \cos\theta & -\sin\theta \\ \sin\theta & \cos\theta \end{pmatrix}
  \begin{bmatrix} a_n \\ b_n \end{bmatrix}
  =
  \begin{bmatrix} a_n' \\ b_n' \end{bmatrix},
  \quad
  \begin{vmatrix} 1 & 1 \\ e^{ix} & e^{-ix} \end{vmatrix} = -2i \sin x,
  \quad
  \begin{Bmatrix} 1 & 0 \\ 0 & 1 \end{Bmatrix},
  \quad
  \begin{matrix} a & b \\ c & d \end{matrix}
`)

#mitex(`
  \begin{array}{c|ccc}
    n   & 1 & 3 & 5 \\ \hline
    b_n & \frac{4}{\pi} & \frac{4}{3\pi} & \frac{4}{5\pi}
  \end{array}
  \qquad
  \underbrace{\frac{4}{\pi} \sum_{k=0}^{\infty} \frac{\sin (2k+1)x}{2k+1}}_{\text{square wave}}
  \;=\; \overbrace{\operatorname{sq}(x)}^{\text{almost everywhere}}
`)

= Macros and colour

#mitex(`
  \newcommand{\ip}[2]{\left\langle #1, #2 \right\rangle}
  \newcommand{\e}[1]{e^{i #1 x}}
  \newcommand{\R}{\mathbb{R}}
  \ip{\e{m}}{\e{n}} = \int_{-\pi}^{\pi} \e{m} \, \overline{\e{n}} \, \mathrm{d}x
    = 2\pi \, \delta_{mn},
  \qquad
  \textcolor{red}{c_n} = \frac{1}{2\pi} \ip{f}{\e{n}},
  \qquad
  f \colon \R \to {\color{blue} \mathbb{C}}
`)

Accents and fonts: #mi(`\hat{f}(\xi)`), #mi(`\tilde{f}`), #mi(`\bar{z}`), #mi(`\vec{v}`),
#mi(`\dot{x}`), #mi(`\ddot{x}`), #mi(`\mathcal{F}`), #mi(`\mathfrak{g}`), #mi(`\mathbf{A}`),
#mi(`\boldsymbol{\beta}`), #mi(`\mathrm{sinc}`), #mi(`\mathsf{T}`), #mi(`\mathtt{0x1F}`);
roots, binomials and limits: #mi(`\sqrt[3]{x^2 + 1}`), #mi(`\binom{n}{k}`),
#mi(`\lim_{N \to \infty} S_N f = f`), #mi(`\limsup_{n} |c_n|^{1/n}`),
#mi(`\prod_{k=1}^{n} \left(1 - \frac{x^2}{k^2 \pi^2}\right)`); display style inside a line:
#mi(`\displaystyle \sum_{n \in \mathbb{Z}} |c_n|^2`).

= What the plugin returns

`mitex-convert` gives the Typst source that is evaluated afterwards:

#let samples = (
  `\frac{1}{2}_3`.text,
  `\alpha x`.text,
  `(\frac{a}{b})`.text,
  `\sqrt[n]{x} \le \infty`.text,
  `\begin{cases} a & b \\ c & d \end{cases}`.text,
)
#table(
  columns: (1fr, 1.4fr),
  inset: 4pt,
  stroke: 0.4pt,
  table.header[*LaTeX*][*Typst*],
  ..samples.map(s => (raw(s, lang: "latex"), raw(mitex-convert(s)))).flatten(),
)

= Text mode

#mitext(`
  \iftypst
    #set math.equation(numbering: "(1)", supplement: "equation")
  \fi

  \subsection{Parseval}

  For a \textbf{square integrable} function the \emph{energy} can be read off the
  coefficients, see \eqref{eq:parseval}, with $c_n$ as above:

  \begin{equation}
    \frac{1}{2\pi} \int_{-\pi}^{\pi} |f(x)|^2 \, dx = \sum_{n=-\infty}^{\infty} |c_n|^2
    \label{eq:parseval}
  \end{equation}

  \subsection{Checklist}

  \begin{itemize}
    \item compute $a_0$ first,
    \item use symmetry: even functions have $b_n = 0$,
    \item compare with \eqref{eq:parseval}.
  \end{itemize}

  \begin{enumerate}
    \item Integrate by parts.
    \item Simplify $\cos n\pi = (-1)^n$.
  \end{enumerate}
`)
