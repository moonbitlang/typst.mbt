// alchemist 0.2.0 (on cetz 0.5.2): skeletal formulas. Fragments from
// strings and equations (indices, exponents, charges, colours, vertical),
// single/double/triple bonds with offsets and strokes, filled, hollow and
// dashed wedges, branches, cycles with arcs, fused rings, named links,
// configuration. Molecules in a table, in figures, inline and at text size.

#import "@preview/alchemist:0.2.0": *

#set page(width: 17cm, height: 23cm, margin: 1.5cm, numbering: "1")
#set heading(numbering: "1.1")
#set par(justify: true)
#show figure.caption: set text(9pt)

// A zig-zag chain of n carbon atoms starting upwards.
#let chain(n, start: 1) = for i in range(n) {
  single(angle: if calc.even(i) { start } else { -start })
}

= Kitchen chemistry: what is in the jar

The spice rack and the fruit bowl hold small molecules that are easy to
draw. This sheet builds them from fragments and bonds, the way a chemist
writes them on paper.

== Bonds

A bond leaves the last fragment at an angle given in steps of the
`angle-increment`, which is 45° by default. @tab-bonds lists the kinds of
bonds; the last row changes strokes and gaps.

#figure(
  table(
    columns: 4,
    align: center + horizon,
    stroke: (x, y) => if y == 0 { (bottom: 0.6pt) } else { none },
    inset: 6pt,
    table.header[single][double][triple][plus],
    skeletize({ fragment("A"); single(); fragment("B") }),
    skeletize({ fragment("A"); double(); fragment("B") }),
    skeletize({ fragment("A"); triple(); fragment("B") }),
    skeletize({ fragment("A"); plus-link(); fragment("B") }),
    table.header[wedge][hollow wedge][dashed wedge][wedge, reversed],
    skeletize({ fragment("A"); cram-filled-right(); fragment("B") }),
    skeletize({ fragment("A"); cram-hollow-right(); fragment("B") }),
    skeletize({ fragment("A"); cram-dashed-right(); fragment("B") }),
    skeletize({ fragment("A"); cram-filled-left(); fragment("B") }),
    table.header[offset left][offset right][coloured][wide gap],
    skeletize({ fragment("A"); double(offset: "left"); fragment("B") }),
    skeletize({ fragment("A"); double(offset: "right"); fragment("B") }),
    skeletize({ fragment("A"); triple(stroke: 1pt, stroke-left: red, stroke-center: green, stroke-right: blue); fragment("B") }),
    skeletize({ fragment("A"); double(gap: 0.6em, stroke: (dash: "dashed")); fragment("B") }),
  ),
  caption: [Kinds of bonds.],
) <tab-bonds>

== Fragments

A fragment is a string that the package splits into atoms with indices,
exponents and charges, or an equation when that is not enough. A bond
attaches to the atom chosen with `from` and `to`.

#grid(
  columns: (1fr,) * 4,
  align: center + horizon,
  row-gutter: 8pt,
  skeletize({ fragment("H_3C"); single(); fragment("CH_2"); single(); fragment("OH") }),
  skeletize({ fragment("NH_4^+"); plus-link(); fragment("Cl^-") }),
  skeletize({ fragment($C(C H_3)_3$); single(); fragment("OH", colors: (red, black)) }),
  skeletize({ fragment("HOOC", vertical: true); single(from: 0, to: 0); fragment("CH_3") }),
  [ethanol], [salt of hartshorn], [_tert_-butanol], [a vertical fragment],
)

= Chains and branches

A branch leaves the main chain and returns to where it started. Acetic
acid, the acid of vinegar, needs one; citric acid needs five.

#figure(
  grid(
    columns: (1fr, 1.6fr),
    align: center + horizon,
    skeletize({
      fragment("H_3C")
      single()
      fragment("C")
      branch({
        double(angle: 2)
        fragment("O")
      })
      single()
      fragment("OH")
    }),
    skeletize(config: (atom-sep: 2.4em), {
      fragment("HO")
      single()
      fragment("C")
      branch({ double(angle: 2); fragment("O") })
      single()
      fragment("CH_2")
      single()
      fragment("C")
      branch({ single(angle: 2); fragment("OH") })
      branch({
        single(angle: -2)
        fragment("C")
        branch({ double(angle: -1); fragment("O") })
        single(angle: -3)
        fragment("OH")
      })
      single()
      fragment("CH_2")
      single()
      fragment("C")
      branch({ double(angle: 2); fragment("O") })
      single()
      fragment("OH")
    }),
  ),
  caption: [Acetic acid (left) and citric acid (right).],
) <fig-acids>

With `angle-increment: 30deg` the bonds make the zig-zag of a skeletal
formula, and carbon atoms are no longer written. Capsaicin, which makes
chilli hot, is a long chain on a ring (@fig-capsaicin).

#figure(
  skeletize(config: (angle-increment: 30deg, atom-sep: 2.1em), {
    fragment("HO")
    single(angle: 1)
    cycle(6, align: true, arc: (:), {
      single()
      branch({
        single()
        fragment("O")
        single(angle: -1)
        fragment("CH_3")
      })
      single()
      single()
      single()
      branch({
        single()
        single(angle: -1)
        fragment("N")
        branch({ single(angle: 3); fragment("H") })
        single(angle: 1)
        branch({ double(angle: 3); fragment("O") })
        chain(4, start: -1)
        double(angle: -1, offset: "left")
        single(angle: 1)
        branch({ single(angle: 3) })
        single(angle: -1)
      })
      single()
      single()
    })
  }),
  caption: [Capsaicin; the ring is drawn with an arc for its delocalised
    electrons.],
) <fig-capsaicin>

= Rings

== One ring

A cycle takes the number of its sides and a body of bonds. Fragments in
the body sit on the corners (@fig-rings).

#figure(
  grid(
    columns: 4,
    column-gutter: 1.2em,
    align: center + bottom,
    row-gutter: 6pt,
    skeletize({
      cycle(6, {
        single()
        double()
        single()
        double()
        single()
        double()
      })
    }),
    skeletize({
      cycle(5, {
        single()
        fragment("O")
        single()
        double()
        single()
        double()
      })
    }),
    skeletize({
      cycle(6, arc: (start: 30deg, end: 330deg, stroke: (dash: "dashed")), {
        single()
        fragment("N")
        single()
        single()
        single()
        single()
        single()
      })
    }),
    skeletize({
      cycle(3, {
        single()
        fragment("O")
        single()
        single()
      })
    }),
    [benzene], [furan], [pyridine, open arc], [an epoxide],
  ),
  caption: [Rings of six, five and three atoms.],
) <fig-rings>

== Fused rings and substituents

A cycle inside a cycle shares the bond it starts from. Caffeine is a
six-ring fused to a five-ring with three methyl groups (@fig-caffeine);
vanillin a benzene ring with three substituents.

#figure(
  grid(
    columns: 2,
    column-gutter: 2em,
    align: center + horizon,
    skeletize(config: (atom-sep: 2.4em), {
      fragment("H_3C")
      single()
      fragment("N")
      cycle(6, {
        single()
        branch({ double(); fragment("O") })
        single()
        fragment("N")
        branch({ single(); fragment("CH_3") })
        single()
        cycle(5, {
          single()
          fragment("N")
          double()
          single()
          fragment("N")
          branch({ single(); fragment("CH_3") })
          single()
        })
        double()
        single()
        branch({ double(); fragment("O") })
        single()
      })
    }),
    skeletize(config: (angle-increment: 30deg, atom-sep: 2.4em), {
      fragment("HO")
      single(angle: 1)
      cycle(6, align: true, {
        single()
        double()
        single()
        branch({
          single()
          branch({ double(angle: 2); fragment("O") })
          single(angle: -2)
          fragment("H")
        })
        double()
        single()
        branch({ single(); fragment("O"); single(angle: -5); fragment("CH_3") })
        double()
      })
    }),
  ),
  caption: [Caffeine (left) and vanillin (right).],
) <fig-caffeine>

= Shape in space

Wedges show what points towards the reader and what away. The two forms
of carvone smell of spearmint and of caraway; they differ in one wedge
(@fig-carvone).

#let carvone(wedge) = skeletize(config: (angle-increment: 30deg, atom-sep: 2.2em), {
  cycle(6, {
    single()
    branch({ double(); fragment("O") })
    single()
    branch({ single() })
    double()
    single()
    single()
    branch({
      wedge()
      branch({ double(relative: 60deg) })
      single(relative: -60deg)
    })
    single()
  })
})

#figure(
  grid(
    columns: 2,
    column-gutter: 3em,
    row-gutter: 6pt,
    align: center,
    carvone(cram-filled-right), carvone(cram-dashed-right),
    [(_R_)-carvone, spearmint], [(_S_)-carvone, caraway],
  ),
  caption: [One function draws both carvones; the bond kind is its
    argument.],
) <fig-carvone>

Formulas scale with the text, since all their lengths are in `em`. Inline,
at the size of the paragraph, water is
#box(baseline: 30%, skeletize(config: (atom-sep: 1.6em), { fragment("H"); single(angle: 1); fragment("O"); single(angle: -1); fragment("H") }))
and in a footnote-sized remark
#text(7pt, box(baseline: 30%, skeletize(config: (atom-sep: 1.6em), { fragment("H"); single(angle: 1); fragment("O"); single(angle: -1); fragment("H") })))
it is smaller. See @tab-bonds, @fig-acids, @fig-capsaicin, @fig-rings,
@fig-caffeine and @fig-carvone.
