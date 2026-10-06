// alchemist 0.2.0: a panic raised by the package while it draws (a cycle
// whose body starts with a fragment). Compares the error message and the
// trace through alchemist's drawer and the cetz 0.5.2 canvas callbacks.

#import "@preview/alchemist:0.2.0": *

#set page(width: 10cm, height: 6cm)

Pyridine, written with the nitrogen first:

#skeletize({
  cycle(6, {
    fragment("N")
    single()
    double()
    single()
    double()
    single()
    double()
  })
})
