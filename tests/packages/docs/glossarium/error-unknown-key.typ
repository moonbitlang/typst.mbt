// glossarium 0.5.10: `gls` with a key that was never registered: the package panics with
// its own `key not found` message from inside a `context` block.
// Engine: error trace through package code called from contextual content.
#import "@preview/glossarium:0.5.10": make-glossary, register-glossary, print-glossary, gls

#set page(width: 100mm, height: 60mm, margin: 10mm)
#show: make-glossary

#let stations = (
  (key: "ts", short: "TS", long: "tide station", description: "A gauge that records the sea level."),
  (key: "msl", short: "MSL", long: "mean sea level"),
)
#register-glossary(stations)

The @ts at the pier reports the level relative to @msl every six minutes.
The harbour master also consults the #gls("lat") when dredging is planned.

#print-glossary(stations)
