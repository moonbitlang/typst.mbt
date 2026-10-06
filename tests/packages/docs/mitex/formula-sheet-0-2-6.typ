// mitex 0.2.6 (the previous release, with its own plugin binary): a one-page formula sheet
// set from LaTeX: `mitex`, `mi`, a macro, cases, a matrix, text mode with a list, and the
// converted source next to each formula.
// Engine: a second wasm module of the same package family, eval of generated math, grid.
#import "@preview/mitex:0.2.6": mi, mitex, mitext, mitex-convert

#set page(width: 150mm, height: 170mm, margin: 12mm)
#set text(size: 9.5pt)
#set math.equation(numbering: "(1)")

#align(center, text(13pt, weight: "bold")[Optics Formula Sheet])

#let entries = (
  ([Thin lens], `\frac{1}{f} = \frac{1}{s_o} + \frac{1}{s_i}`),
  ([Lensmaker], `\frac{1}{f} = (n - 1) \left( \frac{1}{R_1} - \frac{1}{R_2} \right)`),
  ([Snell], `n_1 \sin\theta_1 = n_2 \sin\theta_2`),
  ([Brewster angle], `\tan\theta_B = \frac{n_2}{n_1}`),
  ([Airy disc], `\sin\theta \approx 1.22 \, \frac{\lambda}{D}`),
  ([Grating], `d \sin\theta_m = m \lambda, \quad m \in \mathbb{Z}`),
  ([Gaussian beam], `w(z) = w_0 \sqrt{1 + \left( \frac{z}{z_R} \right)^2}`),
  ([Malus], `I = I_0 \cos^2 \varphi`),
)

#table(
  columns: (auto, 1fr, 1.2fr),
  align: (left + horizon, center + horizon, left + horizon),
  inset: 5pt,
  stroke: 0.4pt,
  table.header[*Law*][*Formula*][*Converted source*],
  ..entries
    .map(((name, tex)) => (name, mi(tex.text), text(7pt, raw(mitex-convert(tex.text)))))
    .flatten(),
)

The Fresnel coefficients for the two polarisations, with a macro for the
recurring products:

#mitex(`
  \newcommand{\nc}[2]{n_{#1} \cos\theta_{#2}}
  r_s = \frac{\nc{1}{i} - \nc{2}{t}}{\nc{1}{i} + \nc{2}{t}},
  \qquad
  r_p = \frac{\nc{2}{i} - \nc{1}{t}}{\nc{2}{i} + \nc{1}{t}}
`) <eq-fresnel>

#mitex(`
  T(\delta) =
  \begin{cases}
    1 & \delta = 2 \pi m, \\
    \dfrac{1}{1 + F \sin^2(\delta / 2)} & \text{otherwise},
  \end{cases}
  \qquad
  \begin{pmatrix} y_2 \\ \alpha_2 \end{pmatrix}
  =
  \begin{pmatrix} 1 & d \\ -1/f & 1 - d/f \end{pmatrix}
  \begin{pmatrix} y_1 \\ \alpha_1 \end{pmatrix}
`) <eq-etalon>

@eq-fresnel gives the amplitudes, @eq-etalon the transmission of an etalon and
a ray-transfer matrix.

#mitext(`
  \textbf{Conventions.} Distances are \emph{positive} to the right of the lens.
  \begin{itemize}
    \item angles are measured from the normal, $\theta \in [0, \pi/2]$;
    \item $n$ is the refractive index, $\lambda$ the vacuum wavelength.
  \end{itemize}
`)
