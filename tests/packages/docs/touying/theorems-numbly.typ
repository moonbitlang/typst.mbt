// touying 0.8.0 with theorion 0.6.0 and numbly 0.1.0: theorems, lemmas, corollaries,
// definitions, examples and proofs (rainbow cosmos) inside the metropolis theme at 4:3 with
// `slide-level: 3`, numbly heading numbers, the theorem counter frozen across subslides,
// references to theorems, equations and figures on other slides (`@thm[-]`, `@thm[!!]`),
// `theorion-restate`, an outline of theorems, `touying-recall` of a labelled slide and of a
// labelled table, the theme's outline and focus slides, and an appendix with new numbering.
// Engine paths: rich counters inherited from headings, state/counter freezing by
// `update(at(..))`, figure kinds and outline targets, labels placed on last subslides only,
// queries for restating, numbering functions built from pattern strings.
#import "@preview/touying:0.8.0": *
#import themes.metropolis: *
#import "@preview/numbly:0.1.0": numbly
#import "@preview/theorion:0.6.0": *
#import cosmos.rainbow: *
#show: show-theorion

#show: metropolis-theme.with(
  aspect-ratio: "4-3",
  footer: self => self.info.institution,
  config-common(slide-level: 3, frozen-counters: (theorem-counter,)),
  config-info(
    title: [Trees and Their Leaves],
    subtitle: [Four ways to say "connected and acyclic"],
    author: [Nnamdi Okonkwo],
    date: datetime(year: 2025, month: 11, day: 3),
    institution: [Seminar on Discrete Structures],
  ),
)

#set heading(numbering: numbly("{1:I}.", "{1:I}.{2}", "{1:I}.{2}.{3:a}"))
#set-inherited-levels(1)
#set-theorion-numbering("I.1")
#set math.equation(numbering: "(1)")

// A small tree drawn with shapes: positions in a unit grid, edges as index pairs.
#let draw-graph(points, edges, unit: 1.1cm, highlight: ()) = box(
  width: 5 * unit,
  height: 3 * unit,
  {
    for (a, b) in edges {
      let (x1, y1) = points.at(a)
      let (x2, y2) = points.at(b)
      place(top + left, line(start: (x1 * unit, y1 * unit), end: (x2 * unit, y2 * unit), stroke: 1.2pt))
    }
    for (i, (x, y)) in points.enumerate() {
      place(top + left, dx: x * unit - 5pt, dy: y * unit - 5pt, circle(
        radius: 5pt,
        fill: if i in highlight { rgb("#eb811b") } else { rgb("#23373b") },
      ))
    }
  },
)
#let tree-points = ((0.3, 1.5), (1.3, 0.6), (1.3, 2.4), (2.5, 1.5), (3.6, 0.5), (3.6, 2.5), (4.7, 1.5))
#let tree-edges = ((0, 1), (1, 3), (2, 3), (3, 4), (3, 5), (5, 6))

#title-slide()

#outline-slide(level: 1)

= Definitions

== Graphs

=== Words we need

#definition[
  A _graph_ $G = (V, E)$ consists of a finite set $V$ of vertices and a set $E$ of
  two-element subsets of $V$, the edges. It is _connected_ if any two vertices are joined by
  a path, and _acyclic_ if it contains no cycle.
] <def:graph>

#definition(title: "Tree")[
  A *tree* is a connected acyclic graph. A vertex of degree one is a _leaf_.
] <def:tree>

=== A picture

#figure(
  draw-graph(tree-points, tree-edges, highlight: (0, 2, 4, 6)),
  caption: [A tree on seven vertices; its four leaves are highlighted],
) <fig:tree>

#example[
  The graph of @fig:tree has $7$ vertices and $6$ edges. Removing any edge disconnects it,
  and adding any edge closes a cycle.
]

== Counting

=== Degrees

In every graph the degrees sum to twice the number of edges:
$ sum_(v in V) deg(v) = 2 |E|. $ <eq:handshake>

#remark[
  @eq:handshake is the handshake lemma. It holds for all graphs; trees enter on the next
  slides.
]

= Leaves and Edges

== Leaves

=== Every tree has leaves

#lemma(title: "Two leaves")[
  Every tree with at least two vertices has at least two leaves.
] <lem:leaves>

#pause

#proof[
  Take a longest path $v_0, v_1, dots, v_k$ in the tree. If $v_0$ had a neighbour other
  than $v_1$, that neighbour would either extend the path or close a cycle. So $v_0$ is a
  leaf, and by symmetry so is $v_k$.
]

== Edges

=== Small cases <slide:small>

The number of trees on $n$ labelled vertices, and of their shapes:

#table(
  columns: 7,
  align: center,
  table.header[$n$][1][2][3][4][5][6],
  [labelled], [1], [1], [3], [16], [125], [1296],
  [shapes], [1], [1], [1], [2], [3], [6],
)

#pause

Every one of them has one edge fewer than it has vertices.

=== The edge count

#theorem(title: "Edges of a tree")[
  A tree on $n >= 1$ vertices has exactly $n - 1$ edges.
] <thm:edges>

#proof[
  By induction on $n$. For $n = 1$ there is nothing to show. Otherwise remove a leaf, which
  exists by @lem:leaves[-]; what remains is a tree on $n - 1$ vertices with one edge fewer.
]

=== Consequences

#corollary[
  The average degree of a tree on $n$ vertices is $2 - 2 \/ n < 2$.
] <cor:average>

#corollary(title: "Forests")[
  A forest with $n$ vertices and $c$ components has $n - c$ edges.
] <cor:forest>

Both follow from @thm:edges and @eq:handshake; the first explains @lem:leaves again, since
an average below two needs vertices of degree one.

= Characterisations

== Equivalences

=== Four descriptions

#theorem(title: "Characterisation of trees")[
  For a graph $G$ on $n$ vertices the following are equivalent:
  + $G$ is a tree (@def:tree[-]);
  + $G$ is connected and has $n - 1$ edges;
  + $G$ is acyclic and has $n - 1$ edges;
  + any two vertices of $G$ are joined by exactly one path.
] <thm:char>

#note-block[
  The implications from the first statement to the second and third are @thm:edges[!!].
]

=== The table of the proof <slide:table>

#figure(
  table(
    columns: (auto, 1fr),
    align: (center, left),
    table.header[Step][Argument],
    [1 #sym.arrow.r 2], [the edge count, already proved],
    [2 #sym.arrow.r 3], [a cycle could lose an edge and stay connected],
    [3 #sym.arrow.r 4], [@cor:forest[-] gives one component; two paths make a cycle],
    [4 #sym.arrow.r 1], [unique paths: connected, and no cycle],
  ),
  caption: [The cycle of implications],
) <tab:proof>

== Counting trees

=== Cayley's formula

#theorem(title: "Cayley")[
  There are $n^(n-2)$ trees on the vertex set ${1, dots, n}$.
] <thm:cayley>

#example[
  For $n = 4$ the formula gives $16$: the path can be labelled in $12$ ways and the star in
  $4$.
]

#tip-block[
  The proof by Prüfer codes removes the smallest leaf repeatedly, which again rests on
  @lem:leaves.
]

= Looking Back

== Summary

=== The statements again

#theorion-restate(filter: it => it.outlined and it.identifier == "theorem", render: it => it.render)

=== One of them, by label

#theorion-restate(filter: <lem:leaves>)

It was used in @thm:edges, in @cor:average and for @thm:cayley.

=== All numbered results

#outline(title: none, target: figure.where(kind: "theorem"))

== Recalls

=== The proof table, recalled

#touying-recall(<tab:proof>)

The table of @tab:proof is the same element, placed a second time by `touying-recall`.

#touying-recall(<slide:small>)

#focus-slide[Every tree has $n - 1$ edges.]

#show: appendix
// The section counter runs on (the supplement is section E): letters cannot show a zero.
#set heading(numbering: numbly("{1:A}.", "{1:A}.{2}", "{1:A}.{2}.{3:a}"))
#set-theorion-numbering("A.1")

= Supplement

== Exercises

=== Two to try

#exercise[
  Show that a graph is a forest exactly if every induced subgraph has a vertex of degree at
  most one.
]

#exercise[
  How many leaves does a tree have whose inner vertices all have degree three?
]

#solution[
  With $ell$ leaves and $i$ inner vertices, @eq:handshake gives $ell + 3 i = 2 (ell + i - 1)$,
  hence $ell = i + 2$.
]
