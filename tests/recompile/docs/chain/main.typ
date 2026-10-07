// Imports in a chain and in a diamond:
//
//   main -> a -> b -> c -> data.json
//   main -> d ------> c
//   main -> part (twice) -> b
//
// Every file is a document of its own too, so any of them can be the main
// file. A module is evaluated once in a compilation and must be evaluated
// again in the next one if anything below it changed.
#import "a.typ": a-show, a-value
#import "d.typ"
#import "a.typ" as again

#set page(width: 220pt, height: auto, margin: 12pt)

= Chain

#a-show[The chain says #a-value.]

The diamond says #d.d-value and #d.shared.

One module, imported twice: #(again.a-value == a-value).

#include "part.typ"
#include "part.typ"
