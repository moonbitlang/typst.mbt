// quill 0.8.0: an error raised inside the package while the circuit is laid
// out (a content baseline reaches an undefined variable in
// quantum-circuit.typ). Compares the diagnostic and its trace through
// package code and a context block.

#import "@preview/quill:0.8.0": *

#set page(width: 10cm, height: 5cm)

The identity below should align its circuits with the equals sign.

$
  #quantum-circuit(baseline: "=", 1, $H$, $Z$, $H$, 1) = #quantum-circuit(baseline: "=", 1, $X$, 1)
$
