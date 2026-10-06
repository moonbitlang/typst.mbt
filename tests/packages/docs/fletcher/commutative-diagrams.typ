// fletcher 0.5.8: commutative diagrams in math mode and call mode, labelled
// edges with math, hooks, two-headed, dashed and double arrows, bends,
// crossings, parallel shifted edges, 2-cells. Diagrams as numbered block
// equations with references, inline in text, in a grid and in a theorem box;
// measure-driven elastic grid layout on top of cetz 0.3.4.

#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

#set page(width: 16cm, height: 22cm, margin: (x: 1.6cm, y: 1.8cm), numbering: "1")
#set heading(numbering: "1.")
#set math.equation(numbering: "(1)")
#set par(justify: true)

#let Hom = math.op("Hom")
#let im = math.op("im")
#let coker = math.op("coker")
#let id = math.op("id")

#let claim-counter = counter("claim")
#let claim(kind, body) = block(
  width: 100%,
  inset: (left: 8pt, y: 4pt),
  stroke: (left: 1.5pt + gray),
  {
    claim-counter.step()
    strong[#kind #context claim-counter.display().]
    h(0.4em)
    body
  },
)

= Squares and triangles

A square of maps commutes when both ways around it agree. The square
@eq-pullback is moreover a _pullback_ when every pair $(u, v)$ with
$f compose u = g compose v$ factors through $P$ by exactly one dashed arrow.

$
  #diagram(
    spacing: (14mm, 12mm),
    node((0, 0), $T$, name: <t>),
    node((1, 1), $P$, name: <p>),
    node((2, 1), $X$, name: <x>),
    node((1, 2), $Y$, name: <y>),
    node((2, 2), $Z$, name: <z>),
    edge(<p>, <x>, "->", $p_1$),
    edge(<p>, <y>, "->", $p_2$, label-side: right),
    edge(<x>, <z>, "->", $f$),
    edge(<y>, <z>, "->", $g$, label-side: right),
    edge(<t>, <x>, "->", $u$, bend: 25deg),
    edge(<t>, <y>, "->", $v$, bend: -25deg, label-side: right),
    edge(<t>, <p>, "-->", $exists! thin h$, label-pos: 0.6, label-fill: white, label-side: center),
    // The little corner that marks a pullback.
    edge((1.25, 1.1), (1.25, 1.25), (1.1, 1.25), stroke: 0.4pt),
  )
$ <eq-pullback>

#claim[Lemma][
  If the right square of @eq-pasting is a pullback, then the left square is a
  pullback if and only if the outer rectangle is.
]

$
  #diagram(
    cell-size: 12mm,
    $
      A edge(a, ->) edge("d", alpha, ->) & B edge(b, ->) edge("d", beta, ->) & C edge("d", gamma, ->) \
      A' edge(a', ->, label-side: #right) & B' edge(b', ->, label-side: #right) & C'
    $,
  )
$ <eq-pasting>

In running text a small diagram such as
#box(baseline: 40%, diagram(spacing: 9mm, label-size: 0.8em, $X edge(f, ->, shift: #2pt) edge(g, ->, shift: #(-2pt), label-side: #right) & Y edge(q, ->>) & Q$))
names a coequaliser without leaving the paragraph, and
#box(baseline: 40%, diagram(spacing: 9mm, $K edge(k, "hook->") & X$))
a monomorphism.

= Kinds of arrows

The table collects the arrow styles used in these notes. Every cell on the
right is a diagram of its own.

#let ar(..args) = diagram(spacing: 16mm, node((0, 0), $A$), edge(..args), node((1, 0), $B$))

#figure(
  table(
    columns: 4,
    align: (left + horizon, center + horizon) * 2,
    stroke: none,
    table.hline(),
    table.header[Meaning][Arrow][Meaning][Arrow],
    table.hline(stroke: 0.5pt),
    [map], ar("->", $f$), [monomorphism], ar("hook->", $i$),
    [epimorphism], ar("->>", $q$), [isomorphism], ar("<->", $tilde.equiv$),
    [unique map], ar("-->", $exists !$), [equality], ar("="),
    [natural transformation], ar("=>", $eta$), [maps to], ar("|->"),
    [adjoint pair], ar("<=>"), [partial map], ar("-harpoon", $p$),
    [inclusion, dotted], ar("hook..>"), [triple], ar("==>", extrude: (-3, 0, 3)),
    table.hline(),
  ),
  caption: [Arrow styles.],
) <tab-arrows>

= Longer diagrams

== The snake

Two exact rows and three vertical maps give a six-term exact sequence; the
connecting map $delta$ of @eq-snake is drawn as one edge through four
corners.

$
  #diagram(
    spacing: (11mm, 11mm),
    label-size: 0.85em,
    {
      let obs = (
        ($ker a$, $ker b$, $ker c$),
        ($A$, $B$, $C$),
        ($A'$, $B'$, $C'$),
        ($coker a$, $coker b$, $coker c$),
      )
      for (r, row) in obs.enumerate() {
        for (c, ob) in row.enumerate() {
          node((c + 1, r), ob)
          if r < 3 {
            edge((c + 1, r), (c + 1, r + 1), "->", if r == 1 { ($a$, $b$, $c$).at(c) })
          }
          if c < 2 {
            edge((c + 1, r), (c + 2, r), "->")
          }
        }
      }
      node((4, 1), $0$)
      node((0, 2), $0$)
      edge((3, 1), (4, 1), "->")
      edge((0, 2), (1, 2), "->")
      edge(
        (3, 0), (3.5, 0), (3.5, 1.5), (0.5, 1.5), (0.5, 3), (1, 3),
        "->",
        $delta$,
        stroke: red + 0.6pt,
        corner-radius: 5pt,
        label-pos: 0.48,
        label-fill: white,
        label-side: center,
        crossing: true,
      )
    },
  )
$ <eq-snake>

== A cube

Faces of a commutative cube are squares in three directions. The edges
behind are dotted and cross under the front ones.

#align(center, diagram(
  spacing: (10mm, 10mm),
  {
    let front = ((0, 1), (2, 1), (0, 3), (2, 3))
    let back = front.map(((x, y)) => (x + 1, y - 1))
    let names = ($A$, $B$, $C$, $D$)
    for (i, p) in back.enumerate() {
      node(p, $#(names.at(i))'$, name: label("b" + str(i)))
    }
    for (i, p) in front.enumerate() {
      node(p, names.at(i), name: label("f" + str(i)))
    }
    for (i, j) in ((0, 1), (0, 2), (1, 3), (2, 3)) {
      edge(label("b" + str(i)), label("b" + str(j)), "..>")
      edge(label("f" + str(i)), label("f" + str(j)), "->", crossing: true)
    }
    for i in range(4) {
      edge(label("f" + str(i)), label("b" + str(i)), "->", stroke: blue)
    }
  },
))

= Adjunctions

An adjunction $F tack.l G$ is a natural bijection
$Hom(F A, B) tilde.equiv Hom(A, G B)$. Its unit and counit satisfy the two
triangle identities of @eq-triangles, drawn side by side in a grid.

$
  #grid(
    columns: 2,
    column-gutter: 1.2cm,
    diagram(
      spacing: 13mm,
      $
        F edge(F eta, =>) edge("dr", id, "=", label-side: #right) & F G F edge("d", epsilon F, =>) \
        & F
      $,
    ),
    diagram(
      spacing: 13mm,
      $
        G edge(eta G, =>) edge("dr", id, "=", label-side: #right) & G F G edge("d", G epsilon, =>) \
        & G
      $,
    ),
  )
$ <eq-triangles>

Between two categories the functors themselves are drawn as bent arrows, and
the transformation as a double arrow between them:

#figure(
  diagram(
    spacing: 30mm,
    node((0, 0), $cal(C)$),
    node((1, 0), $cal(D)$),
    edge((0, 0), (1, 0), "->", $F$, bend: 40deg),
    edge((0, 0), (1, 0), "->", $G$, bend: -40deg, label-side: right),
    edge((0.5, -0.22), (0.5, 0.22), "=>", $alpha$, label-side: left),
    edge((1, 0), (1, 0), "->", $T = G F$, bend: 130deg, loop-angle: 0deg),
  ),
  caption: [A natural transformation $alpha: F => G$ and a monad on $cal(D)$.],
) <fig-2cell>

#claim[Remark][
  Compare @eq-pullback with @eq-snake: the first is a universal property, the
  second a computation. The styles of @tab-arrows are used in both, and in
  @fig-2cell.
]

== First isomorphism theorem, three ways

The same statement for groups, rings and vector spaces; only the labels
change, so one function draws all three.

#let first-iso(ob, quot) = diagram(
  cell-size: 11mm,
  label-size: 0.8em,
  node((0, 0), ob),
  node((1, 0), $im phi$),
  node((0, 1), quot),
  edge((0, 0), (1, 0), "->>", $phi$),
  edge((0, 0), (0, 1), "->>", $pi$, label-side: right),
  edge((0, 1), (1, 0), "hook-->", $overline(phi)$, label-side: right),
)

#grid(
  columns: (1fr,) * 3,
  align: center,
  row-gutter: 6pt,
  first-iso($G$, $G slash ker phi$), first-iso($R$, $R slash frak(a)$), first-iso($V$, $V slash W$),
  [groups], [rings], [vector spaces],
)
