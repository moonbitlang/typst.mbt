// touying 0.8.0: a minimal deck: the default theme with no configuration at all, slides
// split by headings and by `---`, a few `#pause`s, one `#meanwhile`, plain lists, a table
// and an equation. Engine paths: the heading-driven slide splitter (content tree walk),
// subslide repetition with `hide`, slide and page counters, invisible headings.
#import "@preview/touying:0.8.0": *
#import themes.default: *

#show: default-theme

= Brewing Tea

== Water

Good tea starts with the water, not with the leaves.

#pause

- Soft water for green teas.
- Harder water is fine for black teas. #pause
- Never reboil: the dissolved air is gone.

== Temperature

#table(
  columns: 3,
  table.header[Tea][Water][Steep],
  [Sencha], [70 °C], [1 min],
  [Oolong], [90 °C], [3 min],
  [Assam], [98 °C], [4 min],
)

#pause

Cooling from the boil takes about $t = tau ln((T_0 - T_"room") / (T - T_"room"))$ minutes.

#meanwhile

The table is there from the start; the formula arrives later.

---

A slide that begins after a horizontal rule and has no heading of its own.

= Serving

== Cups

Warm the cups. #pause Pour in turns, a little into each. #pause Stop talking and drink.
