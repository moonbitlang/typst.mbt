// quill 0.8.0, tequila submodule: instruction-driven circuits (single,
// controlled and multi-controlled gates, ranges of qubits, barriers,
// measurements to classical wires), templates (qft, graph-state), composed
// sub-circuits at offsets, decorations on top. Circuits generated in loops,
// in figures with subcaption grids, in a numbered equation and a table.

#import "@preview/quill:0.8.0" as quill: gategroup, lstick, quantum-circuit, rstick, setwire, slice, tequila as tq

#set page(width: 18cm, height: 24cm, margin: 1.6cm, numbering: "1", header: align(right, text(8pt, fill: gray)[Lab course, sheet 5]))
#set heading(numbering: "1.")
#set math.equation(numbering: "(1)")
#set par(justify: true)
#show figure.caption: set text(9pt)

#let ket(x) = $lr(|#x chevron.r)$

= Circuits from instructions

In the instruction model a circuit is a list of operations on numbered
qubits. The package packs them into columns as tightly as the wires allow.
The three lines `h(0)`, `cx(0, 1)`, `cx(1, 2)` give a three-qubit GHZ state:

#align(center, quantum-circuit(
  ..tq.build(
    tq.h(0),
    tq.cx(0, 1),
    tq.cx(1, 2),
  ),
))

Qubit arguments may be ranges, and gates take the styling arguments of the
grid model. @fig-layer applies a layer of rotations to five qubits, then a
ladder of controlled-$Z$ gates, then measures every qubit into one
classical register.

#let n = 5
#figure(
  quantum-circuit(
    wires: (1,) * n + (2,),
    row-spacing: 9pt,
    ..range(n).map(i => lstick($q_#i$, y: i, x: 0)),
    lstick($c$, y: n, x: 0),
    ..tq.build(
      n: n + 1,
      tq.h(range(n)),
      tq.rz($theta$, range(n), fill: aqua.lighten(60%)),
      tq.cz(range(0, n - 1), range(1, n)),
      tq.barrier(),
      tq.rx($pi slash 2$, range(0, n, step: 2), fill: yellow.lighten(60%)),
      tq.ry($phi$, range(1, n, step: 2), fill: orange.lighten(60%)),
      tq.barrier(),
      ..range(n).map(i => tq.measure(i, n, label: text(6pt)[#i])),
    ),
  ),
  caption: [A hardware-efficient layer on #n qubits; the double wire is the
    classical register.],
) <fig-layer>

== All single-qubit instructions

#figure(
  table(
    columns: 8,
    align: center + horizon,
    inset: 5pt,
    stroke: 0.3pt + gray,
    ..(
      ("x", tq.x(0)), ("y", tq.y(0)), ("z", tq.z(0)), ("h", tq.h(0)),
      ("s", tq.s(0)), ("sdg", tq.sdg(0)), ("t", tq.t(0)), ("tdg", tq.tdg(0)),
      ("sx", tq.sx(0)), ("sxdg", tq.sxdg(0)), ("p", tq.p($lambda$, 0)), ("rx", tq.rx($theta$, 0)),
      ("ry", tq.ry($theta$, 0)), ("rz", tq.rz($theta$, 0)), ("u", tq.u($theta$, $phi$, $lambda$, 0)), ("meter", tq.meter(0)),
    ).map(((name, op)) => (raw(name), quantum-circuit(scale: 85%, ..tq.build(op)))).flatten(),
  ),
  caption: [The single-qubit instructions and what they draw.],
) <tab-single>

== Controlled instructions

Controls and targets can be any distance apart, and more than one control
is allowed:

#grid(
  columns: (1fr,) * 4,
  align: center + bottom,
  row-gutter: 6pt,
  quantum-circuit(..tq.build(tq.cx(0, 2), tq.cz(1, 2), tq.swap(0, 1))),
  quantum-circuit(..tq.build(tq.ccx(0, 1, 2), tq.ccz(2, 0, 1), tq.cca(0, 2, 1, $V$))),
  quantum-circuit(..tq.build(tq.cccx(0, 1, 2, 3), tq.ca(3, 0, $R_k$))),
  quantum-circuit(..tq.build(tq.multi-controlled-gate((0, 1, 3), 2, quill.gate.with($W$, fill: red.lighten(70%))), tq.cx((0, 1), (1, 2)))),
  [`cx`, `cz`, `swap`], [`ccx`, `ccz`, `cca`], [`cccx`, `ca`], [multi-controlled, ranges],
)

= Templates

== Fourier transform

The template `qft(n)` writes the transform on $n$ qubits. For $n = 4$ it
is the circuit of @fig-qft; its action on a basis state is
$
  ket(j) arrow.r.bar 1 / sqrt(2^n) sum_(k = 0)^(2^n - 1) e^(2 pi i j k slash 2^n) ket(k).
$ <eq-qft>

#figure(
  quantum-circuit(
    column-spacing: 9pt,
    ..range(4).map(i => lstick($j_#(i + 1)$, y: i, x: 0)),
    ..tq.qft(4),
    ..range(3).map(i => slice(x: 5 - i + range(i).map(k => 4 - k).sum(default: 0), stroke: (paint: gray, dash: "dotted", thickness: 0.6pt))),
  ),
  caption: [Fourier transform on four qubits, as given by the template.],
) <fig-qft>

Growing $n$ shows how the instruction model scales. The circuits below are
drawn at decreasing scale from the same call.

#for (k, s) in ((2, 100%), (3, 85%), (5, 60%)) {
  box(inset: (right: 1em), align(horizon, quantum-circuit(scale: s, ..tq.qft(k))))
}

== Graph states

A graph state has one qubit per vertex and one controlled-$Z$ per edge.
The template takes the edges; with `invert` it gives the circuit that
undoes the state. @fig-graph composes three sub-circuits at different
offsets of one grid and frames them.

#figure(
  quantum-circuit(
    ..tq.graph-state((0, 1), (1, 2), (2, 3), (3, 0)),
    ..tq.build(
      x: 7,
      y: 1,
      tq.p($alpha$, 0),
      tq.sx(1),
      tq.cx(0, 1),
      tq.tdg(1),
    ),
    ..tq.graph-state(x: 11, invert: true, (0, 1), (1, 2), (2, 3), (3, 0)),
    gategroup(x: 1, y: 0, 4, 5, fill: blue.lighten(88%), stroke: none, radius: 3pt, label: text(8pt)[prepare ring]),
    gategroup(x: 7, y: 1, 2, 3, fill: yellow.lighten(75%), stroke: none, radius: 3pt, label: (content: text(8pt)[act on 1, 2], pos: bottom)),
    gategroup(x: 11, y: 0, 4, 5, fill: blue.lighten(88%), stroke: none, radius: 3pt, label: text(8pt)[undo]),
    slice(x: 6),
    slice(x: 10),
  ),
  caption: [A ring graph state, an operation on two of its qubits, and the
    inverse preparation.],
) <fig-graph>

= Mixing both models

The output of `build` is a list of placed gates, so it can sit next to
grid-model elements. In @eq-swap, the left circuit is written as a grid
and the right one as instructions; in the figure after it, a built block
is the middle of a hand-written circuit.

$
  #quantum-circuit(baseline: 0.5fr, 1, quill.swap(1), 1, [\ ], 1, quill.swap(), 1)
  =
  #quantum-circuit(baseline: 0.5fr, ..tq.build(tq.cx(0, 1), tq.cx(1, 0), tq.cx(0, 1)))
$ <eq-swap>

#figure(
  quantum-circuit(
    lstick($a$), quill.mqgate($E$, n: 2, fill: green.lighten(70%)), 6, quill.mqgate($D$, n: 2, fill: green.lighten(70%)), rstick($a$), [\ ],
    lstick(ket(0)), 8, rstick(ket(0)), [\ ],
    lstick(ket(0)), 7, setwire(2), 1, rstick($s$),
    ..tq.build(
      x: 2,
      n: 3,
      append-wire: false,
      tq.cx(0, 2),
      tq.cx(1, 2),
      tq.barrier(),
      tq.gate(0, $cal(N)$, stroke: red, fill: red.lighten(85%)),
      tq.barrier(),
      tq.cx(0, 2),
      tq.cx(1, 2),
      tq.meter(2),
    ),
  ),
  caption: [A parity check written as instructions, between an encoder and
    a decoder written as grid cells.],
) <fig-mixed>

@fig-layer, @tab-single, @fig-qft with @eq-qft, @fig-graph, @eq-swap and
@fig-mixed cover the sheet.
