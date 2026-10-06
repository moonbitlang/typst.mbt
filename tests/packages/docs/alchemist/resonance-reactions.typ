// alchemist 0.2.0 (on cetz 0.5.2): resonance and reaction schemes.
// Operators between molecules, resonance and polymer parentheses with
// indices, Lewis structures (pairs, single electrons, lines, rectangles,
// charges), hooks and remote links, hidden parts, cetz drawing in the same
// canvas (curved electron arrows), draw-skeleton inside a cetz canvas,
// skeletize-config. Schemes in numbered figures and a breakable list.

#import "@preview/alchemist:0.2.0": *

#set page(width: 17cm, height: 23cm, margin: 1.5cm, numbering: "1")
#set heading(numbering: "1.1")
#set par(justify: true)
#show figure.caption: set text(9pt)
#show figure.where(kind: "scheme"): set figure(supplement: [Scheme])

// A drawer with the settings of this sheet.
#let draw = skeletize-config((angle-increment: 30deg, atom-sep: 2.4em, fragment-margin: 0.15em))
#let scheme(body, caption) = figure(body, caption: caption, kind: "scheme", supplement: [Scheme])

= Electrons on paper

== Lewis structures

Dots and lines around an atom show its outer electrons. Each element of
the list `lewis` is placed at an angle around the fragment
(@sch-lewis).

#scheme(
  grid(
    columns: 5,
    column-gutter: 1.6em,
    row-gutter: 8pt,
    align: center + horizon,
    skeletize({
      fragment("H")
      single()
      fragment("O", lewis: (lewis-double(angle: 90deg), lewis-double(angle: -90deg)))
      single()
      fragment("H")
    }),
    skeletize({
      fragment("N", lewis: (lewis-line(angle: 180deg),))
      triple()
      fragment("N", lewis: (lewis-line(angle: 0deg),))
    }),
    skeletize({
      fragment("O", lewis: (lewis-rectangle(angle: 135deg), lewis-rectangle(angle: -135deg)))
      double()
      fragment("C")
      double()
      fragment("O", lewis: (lewis-rectangle(angle: 45deg), lewis-rectangle(angle: -45deg)))
    }),
    skeletize({
      fragment("Cl", lewis: (
        lewis-double(angle: 90deg),
        lewis-double(angle: 180deg),
        lewis-double(angle: -90deg),
        lewis-single(angle: 0deg, offset: "center", fill: red, stroke: red),
      ))
    }),
    skeletize({
      fragment("H_3C")
      single()
      fragment("", lewis: (lewis-charge(charge: $plus.o$, angle: 60deg, radius: 0.5em),))
      branch({ single(angle: 2); fragment("CH_3") })
      single()
      fragment("CH_3")
    }),
    [water], [nitrogen], [carbon dioxide], [chlorine atom], [a carbocation],
  ),
  [Lone pairs as dots, lines and boxes; a radical; a charge on an atom that
    is not written.],
) <sch-lewis>

== Resonance

When one structure is not enough, several are written in brackets with a
double-headed arrow between them. The operator starts a new molecule; the
parentheses in resonance mode wrap a whole structure (@sch-carboxylate).

#scheme(
  skeletize(config: (atom-sep: 2.4em), {
    parenthesis(l: "[", r: "]", resonance: true, {
      fragment("R")
      single()
      fragment("C")
      branch({
        double(angle: 1)
        fragment("O", lewis: (lewis-double(angle: 45deg), lewis-double(angle: 135deg)))
      })
      single(angle: -1)
      fragment("O^-", ignore-charge: true, lewis: (lewis-double(angle: 0deg), lewis-double(angle: -90deg), lewis-double(angle: 180deg)))
    })
    operator(math.arrow.l.r, margin: 1.2em)
    parenthesis(l: "[", r: "]", resonance: true, {
      fragment("R")
      single()
      fragment("C")
      branch({
        single(angle: 1)
        fragment("O^-", ignore-charge: true, lewis: (lewis-double(angle: 0deg), lewis-double(angle: 90deg), lewis-double(angle: 180deg)))
      })
      double(angle: -1)
      fragment("O", lewis: (lewis-double(angle: -45deg), lewis-double(angle: -135deg)))
    })
    operator($equiv$, margin: 1.2em)
    fragment("R")
    single()
    fragment("C")
    branch({
      single(angle: 1, stroke: (dash: "dashed"))
      double(angle: 1, offset: "right", stroke-right: (dash: "dotted"))
      fragment($O^(1 slash 2 -)$)
    })
    double(angle: -1, offset: "left", stroke-left: (dash: "dotted"))
    fragment($O^(1 slash 2 -)$)
  }),
  [The carboxylate ion: two limiting structures and the delocalised
    picture.],
) <sch-carboxylate>

Electron movement is drawn with curved arrows. They are ordinary cetz
paths between the anchors that bonds and fragments leave in the canvas
(@sch-arrows).

#scheme(
  skeletize(config: (atom-sep: 3em), {
    import cetz.draw: *
    fragment("H_2C", name: "c1")
    double(name: "pi")
    fragment("CH", name: "c2")
    single(name: "sigma")
    fragment("CH_2^+", name: "c3", ignore-charge: true)
    hobby(
      "pi.50%",
      (rel: (0.25, 0.7), to: "c2.north"),
      "sigma.50%",
      stroke: (paint: red, thickness: 0.7pt),
      mark: (end: ">", fill: red, scale: 0.8),
    )
    operator(math.arrow.l.r, margin: 1.5em)
    fragment("H_2C^+", ignore-charge: true)
    single()
    fragment("CH")
    double()
    fragment("CH_2")
  }),
  [The allyl cation; the red arrow moves the #sym.pi electrons.],
) <sch-arrows>

= Reactions

== Esterification

An acid and an alcohol give an ester and water. Plus signs and the
reaction arrow are operators; the catalyst sits above the arrow
(@sch-ester).

#scheme(
  draw({
    single(angle: 1)
    branch({ double(angle: 3); fragment("O") })
    single(angle: -1)
    fragment("OH", colors: (red,))
    operator($+$)
    fragment("HO", colors: (red, black))
    single(angle: 1)
    single(angle: -1)
    operator(math.attach(math.stretch(sym.harpoons.rtlb, size: 3em), t: [H#super[+]], b: text(7pt)[heat]), margin: 1.2em)
    single(angle: 1)
    branch({ double(angle: 3); fragment("O") })
    single(angle: -1)
    fragment("O")
    single(angle: 1)
    single(angle: -1)
    operator($+$)
    fragment("H_2O", colors: (red,))
  }),
  [Acetic acid and ethanol give ethyl acetate. Atoms that end up in the
    water are red.],
) <sch-ester>

== Polymers

Parentheses with an index mark a repeating unit. They are sized to the
body between them; `right` names the place of the closing bracket when the
body ends in a ring (@sch-polymers).

#scheme(
  grid(
    columns: 3,
    column-gutter: 2em,
    align: center + horizon,
    row-gutter: 8pt,
    draw({
      parenthesis(l: "[", r: "]", br: $n$, {
        single(angle: 1)
        single(angle: -1)
        single(angle: 1)
      })
    }),
    draw({
      fragment("HO")
      single(angle: 1)
      parenthesis(br: $n$, {
        single(angle: -1)
        branch({ double(angle: -3); fragment("O") })
        single(angle: 1)
        branch({ single(angle: 3) })
        single(angle: -1)
        fragment("O")
        single(angle: 1)
      })
      fragment("H")
    }),
    draw({
      single(angle: 1)
      parenthesis(l: "[", r: "]", br: $m$, tr: text(7pt)[atactic], right: "end", {
        single(angle: -1, name: "end")
        branch({
          single(angle: -3)
          cycle(6, arc: (:), {
            single()
            single()
            single()
            single()
            single()
            single()
          })
        })
      })
      single(angle: 1)
    }),
    [polyethylene], [polylactic acid], [polystyrene],
  ),
  [Repeating units of three plastics.],
) <sch-polymers>

= Rings that close late

== Hooks and remote links

A hook names a place; a later fragment or bond can link back to it. This
closes rings that are awkward to write as cycles, and draws bonds across a
molecule (@sch-hooks).

#scheme(
  grid(
    columns: 2,
    column-gutter: 3em,
    align: center + horizon,
    skeletize(config: (atom-sep: 2.6em), {
      fragment(name: "n1", "N")
      single(angle: 1)
      fragment("Cu", name: "cu")
      single(angle: -1)
      fragment(name: "n2", "N")
      single(angle: -3)
      fragment("O", name: "o", links: ("n1": single(stroke: (dash: "dashed")), "cu": single(stroke: blue + 1pt)))
    }),
    draw({
      hook("start")
      single(angle: 1)
      single(angle: -1)
      single(angle: 1)
      fragment("O")
      single(angle: -1)
      single(angle: -5, name: "back")
      single(angle: 5, links: ("start": double(stroke: purple)))
    }),
  ),
  [Left: links from the oxygen to two named fragments. Right: a chain
    that returns to its hook with a double bond.],
) <sch-hooks>

== Showing a part only

`hide` keeps the space of a part without drawing it, so that a series of
figures stays aligned while a mechanism is built up. The three steps below
are one function with a different hidden part.

#let build-up(step) = draw({
  let maybe(k, body) = if step >= k { body } else { hide(body) }
  fragment("HO")
  single(angle: 1)
  single(angle: -1)
  maybe(1, {
    single(angle: 1)
    branch({ double(angle: 3); fragment("O") })
  })
  maybe(2, {
    single(angle: -1)
    fragment("NH_2")
  })
})

#enum(
  numbering: "Step 1:",
  spacing: 1.2em,
  ..range(3).map(k => box(baseline: 40%, build-up(k))),
)

== Molecules in a larger drawing

`draw-skeleton` returns cetz elements instead of a canvas, so molecules
can be nodes of a drawing: here an energy diagram with the two chair forms
of a ring and the barrier between them.

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let chair = (angle-increment: 30deg, atom-sep: 1.6em)
    line((0, 0), (0, 4.2), mark: (end: "stealth", fill: black), name: "axis")
    content("axis.end", anchor: "south", padding: 3pt, text(8pt)[energy])
    hobby((0.8, 1), (2, 1.1), (4.5, 3.6), (7, 1.5), (8.2, 1.4), stroke: 1pt + navy, name: "path")
    for (x, y, label) in ((1.2, 1, [chair A]), (4.5, 3.6, [half chair]), (7.8, 1.4, [chair B])) {
      line((x - 0.6, y), (x + 0.6, y), stroke: 1.5pt)
      content((x, y + 0.25), anchor: "south", text(8pt, label))
    }
    group({
      translate((1.2, -0.2))
      draw-skeleton(config: chair, name: "a", mol-anchor: "north", {
        cycle(6, { single(); single(); single(); single(); single(); single() })
      })
    })
    group({
      translate((7.8, -0.2))
      draw-skeleton(config: chair, name: "b", {
        cycle(6, { single(); double(); single(); single(); single(); single() })
      })
    })
    line((4.5, 1), (4.5, 3.6), stroke: (dash: "dotted"), mark: (start: "|", end: "|"), name: "barrier")
    content("barrier.mid", anchor: "west", padding: 3pt, text(8pt)[$Delta E^(dagger.double)$])
  }),
  caption: [Two skeletons as elements of one cetz canvas.],
) <fig-energy>

@sch-lewis, @sch-carboxylate, @sch-arrows, @sch-ester, @sch-polymers and
@sch-hooks are numbered as schemes, @fig-energy as a figure.
