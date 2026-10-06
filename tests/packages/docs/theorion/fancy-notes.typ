// theorion 0.6.0: fancy cosmos (showybox frames), numbering inherited from
// two heading levels, references ([-], [!!], custom supplement), a list of
// theorems, proofs with QED placement, appendix numbering, restated theorems.
// Stresses query-based counters (metadata + labels), state.at/final, show
// rules on figure/ref/outline, breakable figures over several pages.
#import "@preview/theorion:0.6.0": *
#import cosmos.fancy: *
#show: show-theorion

#set page(
  width: 14.8cm,
  height: 21cm,
  margin: (x: 1.5cm, y: 1.8cm),
  numbering: "1",
  header: context {
    let before = query(selector(heading.where(level: 1)).before(here()))
    set text(size: 8pt, style: "italic")
    if before.len() > 0 { before.last().body } else [Walks on graphs]
    h(1fr)
    [Seminar notes]
  },
)
#set text(size: 10pt, lang: "en")
#set par(justify: true)
#set heading(numbering: "1.1")

#outline(title: [Sections], depth: 2)

#outline(title: [Theorems], target: figure.where(kind: "theorem"))

#outline(title: [Definitions], target: figure.where(kind: "definition"))

= Graphs and degrees

== First notions

#definition[Graph][
  A _graph_ $G = (V, E)$ consists of a finite set $V$ of vertices and a set
  $E$ of two-element subsets of $V$, the edges.
] <def:graph>

#definition[
  The _degree_ $d(v)$ of a vertex $v$ is the number of edges that contain it.
] <def:degree>

#theorem[Handshake lemma][
  In every graph, as in @def:graph, the degrees add up to twice the number of
  edges:
  $ sum_(v in V) d(v) = 2 |E|. $
] <thm:handshake>

#proof[
  Count the pairs $(v, e)$ with $v in e$ in two ways. Each vertex $v$ lies in
  $d(v)$ such pairs; each edge lies in exactly two. Hence
  $ sum_(v in V) d(v) = 2 |E|. $
]

#corollary[
  The number of vertices of odd degree is even.
] <cor:odd>

#proof[Proof of @cor:odd][
  By @thm:handshake[-] the sum of all degrees is even, so the odd summands
  come in pairs.
]

#example[
  At a party of seven people it is impossible that everybody shakes hands
  with exactly three others; this is @cor:odd[!!] in disguise. Compare
  @thm:handshake[!!] and, with another supplement, @thm:handshake[Thm.].
]

== Walks and paths

#definition[Walk][
  A _walk_ of length $k$ is a sequence $v_0, v_1, dots, v_k$ of vertices in
  which consecutive vertices are adjacent. It is a _path_ if all its vertices
  are distinct.
] <def:walk>

#lemma[
  Every walk from $u$ to $v$ contains a path from $u$ to $v$.
] <lem:walk-path>

#proof[
  Take a shortest walk from $u$ to $v$ among those whose vertices all occur
  in the given walk.
  - If no vertex repeats, it is a path. #qedhere
  - Otherwise cutting out the part between two occurrences of a repeated
    vertex gives a shorter walk, a contradiction.
]

#proposition[Counting walks][
  Let $A$ be the adjacency matrix of $G$. The number of walks of length $k$
  from $v_i$ to $v_j$ is the entry $(A^k)_(i j)$.
] <prop:count>

#tip-block[
  @prop:count turns counting into linear algebra: the eigenvalues of $A$
  control how fast the number of walks grows.
]

#theorem-box(outlined: false)[Without a number][
  This statement has no number and is left out of the list of theorems.
] <thm:plain>

See @thm:plain and @lem:walk-path.

= Trees

== Characterisations

#definition[Tree][
  A _tree_ is a connected graph without cycles.
] <def:tree>

#theorem[
  For a graph $T$ on $n$ vertices the following are equivalent:
  + $T$ is a tree in the sense of @def:tree;
  + $T$ is connected and has $n - 1$ edges;
  + any two vertices of $T$ are joined by exactly one path.
] <thm:tree-char>

#proof[
  We only sketch $(1) => (2)$ by induction on $n$. A tree with $n >= 2$
  vertices has a leaf (follow a longest path; see @def:walk). Removing it
  leaves a tree on $n - 1$ vertices, which has $n - 2$ edges.
]

#warning-block[
  The equivalence fails for infinite graphs: a two-way infinite path is a
  tree in which "number of edges" has no meaning.
]

#theorem(title: "Cayley", number: "C", supplement: [Formula])[
  There are $n^(n - 2)$ trees on the vertex set ${1, dots, n}$.
] <thm:cayley>

#theorem(number: (2, 1, 7))[
  This one continues the count from an explicit value; the next theorem is
  numbered after it.
]

#theorem(full-title: [A named result, not numbered in its title])[
  A tree is bipartite.
] <thm:bip>

#remark[
  @thm:cayley is the first statement in these notes that is not proved here.
]

#important-block[
  Every statement about trees in the next section rests on @thm:tree-char.
]

#set-primary-border-color(red.darken(20%))
#set-primary-body-color(red.lighten(95%))
#set-primary-symbol[#sym.suit.diamond.filled]
#set-fancy-radius(0em)

== Spanning trees

#definition[
  A _spanning tree_ of $G$ is a subgraph that is a tree and contains every
  vertex of $G$.
]

#theorem(breakable: true)[Existence][
  A graph has a spanning tree if and only if it is connected.

  #lorem(60)

  #lorem(40)
] <thm:spanning>

#exercise[
  + Find all spanning trees of the cycle $C_5$.
  + How many spanning trees does the complete graph $K_4$ have?
]

#solution[
  Removing any one of the five edges of $C_5$ gives a spanning tree, and by
  @thm:cayley the graph $K_4$ has $4^2 = 16$.
]

#conclusion[
  Connectedness is exactly the existence of a spanning tree.
]

// Appendix
#counter(heading).update(0)
#set heading(numbering: "A.1")
#set-theorion-numbering("A.1")

= Supplements

== Matrices

#axiom[
  All matrices in this appendix have real entries.
]

#theorem[Matrix tree theorem][
  The number of spanning trees of $G$ equals any cofactor of its Laplacian
  $L = D - A$.
] <thm:kirchhoff>

#note-block[
  @thm:kirchhoff gives @thm:cayley as a special case, and it refers back to
  @thm:spanning in the main part.
]

#quote-block[
  A good notation has a subtlety and suggestiveness which at times make it
  seem almost like a live teacher.
]

#emph-block[
  Summary: degrees, walks, trees, and one determinant.
]

== All theorems again

#theorion-restate(filter: it => it.outlined and it.identifier == "theorem")

== One lemma, restated plainly

#theorion-restate(
  filter: <lem:walk-path>,
  render: it => (prefix: none, title: "", full-title: auto, body) => block(inset: (left: 1em))[#strong[#full-title.]#sym.space#emph(body)],
)
