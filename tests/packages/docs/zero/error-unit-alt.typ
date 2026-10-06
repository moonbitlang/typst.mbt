// zero 0.7.1: a unit built from math content without a manual `alt`: the package cannot
// generate the alt description and fails an assertion deep in its accessibility module.
// Engine: error trace through several package functions, `repr` of math content in a message.
#import "@preview/zero:0.7.1": zi

#set page(width: 100mm, height: 50mm, margin: 10mm)

#let sun-yr = zi.declare($M_dot.o$, ("yr", -1))

The star loses #sun-yr[3e-6] through its wind.
