// wrap-it 0.1.1: an explicit `size` skips the package's layout() call, so
// measure() runs without context and fails inside the package.
// Stresses the error trace through package functions and closures.
#import "@preview/wrap-it:0.1.1": wrap-content

#set page(width: 10cm, height: 8cm, margin: 1cm)

A pressed leaf is glued to the left of this note.

#wrap-content(
  rect(width: 2cm, height: 2cm, fill: green.lighten(50%)),
  [The text beside it would wrap below the leaf if this call could measure anything.],
  size: (width: 8cm, height: 6cm),
)
