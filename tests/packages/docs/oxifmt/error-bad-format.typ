// oxifmt 1.0.0: a format string with an unclosed replacement field; the
// package rejects it with its own assertion.
// Stresses the error trace through the package's parser functions.
#import "@preview/oxifmt:1.0.0": strfmt

#set page(width: 10cm, height: 6cm, margin: 1cm)

= Tide table

#let line(place, height) = strfmt("{:<10} {:>6.2 m", place, height)

#line("Skagen", 0.31)
