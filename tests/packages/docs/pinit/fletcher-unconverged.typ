// pinit 0.2.2: two pinit-fletcher-edge calls (fletcher 0.5.8 passed
// explicitly) in one document. Each edge needs every layout iteration for
// itself, and the second one's queries see the first one's late elements, so
// the document does not converge: the warning with the observed element
// counts per run is the point of this document.
// Stresses the convergence check and its diagnostics (hints, run counts).
#import "@preview/pinit:0.2.2": *
#import "@preview/fletcher:0.5.8"

#set page(width: 10cm, height: 7cm, margin: 1cm)

The up train leaves #pin(1)platform one#pin(2) at noon.

#pinit-fletcher-edge(fletcher, 1, end: 2, (0, 0), (1, 0), [first], "<->", bend: -20deg)

#v(2em)

The down train leaves #pin(3)platform two#pin(4) a minute later.

#pinit-fletcher-edge(fletcher, 3, end: 4, (0, 0), (1, 0), "->", stroke: blue)
