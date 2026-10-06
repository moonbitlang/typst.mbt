// quill 0.8.0, grid model: gates, controls (closed, open, classical),
// targets, swaps, phases, meters, multi-qubit gates with inputs/outputs,
// sticks with braces, wire bundles, setwire, labels, gate groups, slices,
// repeat blocks, permutations, manual placement, scaled circuits. Stresses
// measure in context, absolute placement, math layout inside boxes.

#import "@preview/quill:0.8.0": *

#set page(width: 17cm, height: 23cm, margin: 1.6cm, numbering: "1")
#set heading(numbering: "1.1")
#set par(justify: true)
#show figure.caption: set text(9pt)

#let ket(x) = $lr(|#x chevron.r)$
#let bra(x) = $lr(chevron.l #x|)$

= Entanglement in small circuits

A circuit is a grid: every row is a wire, every cell a gate or a piece of
wire. An integer stands for that many empty cells, and `[\ ]` begins the
next wire. @fig-bell prepares a Bell pair and measures it.

#figure(
  quantum-circuit(
    lstick(ket(0)), $H$, ctrl(1), 1, meter(), setwire(2), 1, rstick($a$), [\ ],
    lstick(ket(0)), 1, targ(), 1, meter(), setwire(2), 1, rstick($b$),
  ),
  caption: [A Bell pair. After the meters, the double lines are classical
    wires.],
) <fig-bell>

The same pair shared between two parties lets one of them send a qubit
with two classical bits (@fig-teleport). The gate groups mark who does
what; the slices mark the three stages.

#figure(
  quantum-circuit(
    row-spacing: 14pt,
    column-spacing: 14pt,
    lstick(ket($psi$)), 2, ctrl(1), $H$, meter(), setwire(2), 1, ctrl(2, wire-count: 2), 1, [\ ],
    lstick(ket(0)), $H$, ctrl(1), targ(), 1, meter(), setwire(2), ctrl(1, wire-count: 2), 2, [\ ],
    lstick(ket(0)), 1, targ(), 4, $X$, $Z$, rstick(ket($psi$)),
    gategroup(x: 1, y: 1, 2, 2, stroke: (paint: blue, dash: "dotted", thickness: 0.8pt), radius: 3pt, padding: 2pt, label: (content: text(8pt, fill: blue)[source], pos: bottom)),
    gategroup(x: 3, y: 0, 2, 3, fill: yellow.lighten(80%), stroke: none, radius: 3pt, padding: 2pt, label: text(8pt)[sender]),
    gategroup(x: 6, y: 2, 1, 2, fill: green.lighten(80%), stroke: none, radius: 3pt, padding: 2pt, label: (content: text(8pt)[receiver], pos: bottom)),
    slice(x: 3, label: text(7pt, fill: red)[1]),
    slice(x: 6, label: text(7pt, fill: red)[2]),
  ),
  caption: [Teleportation of #ket($psi$).],
) <fig-teleport>

== Controls of every kind

#figure(
  table(
    columns: 4,
    align: center + horizon,
    stroke: 0.4pt + gray,
    inset: 8pt,
    table.header[controlled-$X$][open control][controlled-$Z$][controlled-$Y$],
    quantum-circuit(1, ctrl(1), 1, [\ ], 1, targ(), 1),
    quantum-circuit(1, ctrl(1, open: true), 1, [\ ], 1, targ(), 1),
    quantum-circuit(1, ctrl(1), 1, [\ ], 1, ctrl(), 1),
    quantum-circuit(1, ctrl(1), 1, [\ ], 1, targ-y(), 1),
    table.header[swap][controlled-$U$][Toffoli][phase],
    quantum-circuit(1, swap(1), 1, [\ ], 1, swap(), 1),
    quantum-circuit(1, ctrl(1), 1, [\ ], 1, $U$, 1),
    quantum-circuit(1, ctrl(1), 1, [\ ], 1, ctrl(1), 1, [\ ], 1, targ(), 1),
    quantum-circuit(1, phase($alpha$), 1, [\ ], 1, phase($beta$, open: true), 1),
    table.header[classical control][measure-controlled][permutation][bundle],
    quantum-circuit(setwire(2), 1, ctrl(1, wire-count: 2), 1, [\ ], 1, $X$, 1),
    quantum-circuit(1, meter(target: 1), [\ ], setwire(2), 1, ctrl(), 1),
    quantum-circuit(1, permute(2, 0, 1), 1, [\ ], 3, [\ ], 3),
    quantum-circuit(1, nwire($n$), $H^(times.o n)$, 1),
  ),
  caption: [Two- and three-qubit building blocks.],
) <tab-controls>

= Multi-qubit gates and labels

A gate may span wires, name its inputs and outputs, and carry labels at any
of its corners. The adder of @fig-adder does all three.

#figure(
  quantum-circuit(
    lstick($a$, n: 2, brace: "{"), nwire(4), mqgate($"ADD"$, n: 3, width: 5em, inputs: ((qubit: 0, label: $x$), (qubit: 1, label: $y$), (qubit: 2, label: $c_"in"$)), outputs: ((qubit: 0, label: $x$), (qubit: 1, label: $s$), (qubit: 2, label: $c_"out"$)), fill: aqua.lighten(70%), radius: 2pt), 1, rstick($a$), [\ ],
    1, nwire(4), 2, gate($Q$, label: ((content: text(7pt)[north], pos: top), (content: text(7pt)[sw], pos: bottom + left))), rstick($a + b$), [\ ],
    lstick(ket(0)), 3, meter(label: $c$), setwire(2), 1,
  ),
  caption: [An adder as a multi-qubit gate with named ports.],
) <fig-adder>

A gate that leaves a wire in the middle untouched lets it pass through,
and the left brace may group any number of wires:

#align(center, quantum-circuit(
  lstick($ket(00) + ket(11)$, n: 2), 1, mqgate($V$, n: 3, pass-through: (1,), fill: orange.lighten(70%)), 1, ctrl(2), 1, rstick($A$), [\ ],
  1, $R_z (theta)$, 1, $T^dagger$, 2, rstick($B$), [\ ],
  lstick(ket($+$)), 3, targ(fill: white), meter(), [\ ],
  lstick($rho$), setwire(1, stroke: red + 1pt), gate($cal(E)$, stroke: red, radius: 100%), 3, rstick($cal(E)(rho)$),
))

== Repetition

#figure(
  grid(
    columns: 2,
    column-gutter: 1.5cm,
    align: horizon,
    quantum-circuit(
      lstick($ket(0)^(times.o n)$), nwire($n$), $H^(times.o n)$, repeat-block(2, wires: 2, label: $sqrt(N)$), mqgate($O_f$, n: 2), $2 ket(s) bra(s) - 1$, meter(), [\ ],
      lstick(ket($-$)), 2, 2, 1,
    ),
    quantum-circuit(
      scale: 80%,
      lstick($q_0$), repeat-block(3, brace: "||:", label: $k$), $R_x$, ctrl(1), 1, 1, [\ ],
      lstick($q_1$), $R_y$, targ(), ctrl(1), 1, [\ ],
      break-line(),
      lstick($q_n$), $R_z$, 1, targ(), 1,
    ),
  ),
  caption: [Left: Grover iteration, repeated $sqrt(N)$ times. Right: one
    layer of an ansatz with omitted wires, drawn at 80 %.],
) <fig-repeat>

#pagebreak()

= A longer circuit

== Phase estimation

The register of $t$ qubits collects the phase bit by bit; the inverse
Fourier transform turns it into a number (@fig-qpe). Gates are placed
automatically, and the labels under the controls are placed by hand.

#let t = 4
#figure(
  quantum-circuit(
    row-spacing: 9pt,
    ..range(t).map(i => (
      lstick(ket(0)),
      $H$,
      ..if i > 0 { (i,) },
      ctrl(t - i),
      ..if t - 1 - i > 0 { (t - 1 - i,) },
      [\ ],
    )).join(),
    lstick(ket($u$)),
    nwire($m$),
    ..range(t).map(i => $U^(2^#i)$),
    2,
    rstick(ket($u$)),
    mqgate($"QFT"^dagger$, x: t + 2, y: 0, n: t, fill: purple.lighten(80%)),
    ..range(t).map(i => meter(x: t + 3, y: i, label: (content: text(7pt)[$phi_#(t - i)$], pos: top + right, dx: 0pt))),
    slice(x: 2, label: (content: text(7pt)[superposition], pos: bottom)),
  ),
  caption: [Phase estimation with $t = #t$ counting qubits.],
) <fig-qpe>

== Custom drawing

`annotate` hands the coordinates of cells to a callback, which can draw
anything on top of the circuit; here a shaded region and a bracket that the
grid model has no element for.

#align(center, quantum-circuit(
  lstick($q_0$), $H$, ctrl(1), 2, $H$, 1, [\ ],
  lstick($q_1$), 1, targ(), $T$, ctrl(1), 2, [\ ],
  lstick($q_2$), 3, 1, targ(), $S$, 1,
  annotate((2, 5), (0, 2), ((x0, x1), (y0, y1)) => {
    place(dx: x0 - 6pt, dy: y0 - 12pt, rect(width: x1 - x0 + 12pt, height: y1 - y0 + 24pt, fill: red.transparentize(88%), stroke: (paint: red, dash: "dashed", thickness: 0.5pt), radius: 4pt))
    place(dx: x0, dy: y1 + 14pt, box(width: x1 - x0, align(center, text(7pt, fill: red)[noisy block])))
  }),
))

Circuits also sit inside formulas. A fractional `baseline` names a height
in units of wires, so `0.5fr` puts the equals sign between the two wires:
$
  #quantum-circuit(baseline: 0.5fr, 1, $H$, ctrl(1), 1, [\ ], 1, $H$, targ(), 1) = #quantum-circuit(baseline: 0.5fr, 1, targ(), $H$, 1, [\ ], 1, ctrl(-1), $H$, 1)
$
and inline, #box(quantum-circuit(scale: 70%, baseline: 3pt, 1, $X$, $Z$, 1)) equals
#box(quantum-circuit(scale: 70%, baseline: 3pt, 1, $-i Y$, 1)) up to phase.
See @fig-bell, @fig-teleport, @tab-controls, @fig-adder, @fig-repeat and
@fig-qpe.
