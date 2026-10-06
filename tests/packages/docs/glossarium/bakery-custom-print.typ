// glossarium 0.5.10: three registered lists; a glossary printed in the roman-numbered front
// matter with custom title/description/back-reference/group printers, `minimum-refs`,
// deduplicated back references and extra shorthands; a second one with `show-all`,
// `disable-back-references` and a custom gloss; a third one `invisible`; first-use styles
// (footnote, short-long), `style-entries`, `gls-custom`, `print-gloss`, `count-all-refs`.
// Engine: forward state (`final`) feeding layout before the uses, page numbering at locations.
#import "@preview/glossarium:0.5.10": (
  make-glossary, register-glossary, print-glossary, print-gloss, gls, glspl, Gls, Glspl,
  gls-custom, gls-group, gls-plural, get-entry-back-references, style-entries,
  count-all-refs, there-are-refs,
)

#set page(width: 120mm, height: 135mm, margin: (x: 11mm, y: 13mm), numbering: "i")
#set text(size: 9pt)
#set par(justify: true)
#show link: set text(fill: rgb("#7a3b10"))
#show: make-glossary.with(heading-always-first: false, figure-caption-always-first: false)

#let dough-terms = (
  (
    key: "levain",
    description: "A portion of starter built up for one bake",
    group: "Fermentation",
    custom: (origin: "French"),
  ),
  (
    key: "autolyse",
    description: "A rest of flour and water before salt and leaven are added",
    group: "Fermentation",
    custom: (origin: "French"),
  ),
  (
    key: "bulk",
    short: "BF",
    long: "bulk fermentation",
    description: "The first rise, in one mass",
    group: "Fermentation",
    styles: ("short-long",),
    custom: (origin: "English"),
  ),
  (
    key: "ddt",
    short: "DDT",
    long: "desired dough temperature",
    description: "The temperature aimed at after mixing",
    group: "Fermentation",
    styles: ("footnote",),
    custom: (origin: "English"),
  ),
  (
    key: "banneton",
    plural: "bannetons",
    description: "A cane basket in which a loaf proves",
    group: "Tools",
    custom: (origin: "French"),
  ),
  (
    key: "lame",
    description: "A razor blade on a handle, for scoring",
    group: "Tools",
    custom: (origin: "French"),
  ),
  (
    key: "peel",
    description: "A flat shovel for loading the oven",
    group: "Tools",
    custom: (origin: "English"),
  ),
  // referenced once only: below `minimum-refs`, so it is not printed
  (
    key: "couche",
    description: "A linen cloth that supports long loaves",
    group: "Tools",
    custom: (origin: "French"),
  ),
  (
    key: "spring",
    short: "oven spring",
    sort: "aaa-first",
    description: "The last expansion of a loaf in the oven",
    custom: (origin: "English"),
  ),
)

#let measures = (
  (key: "bp", short: "BP", long: "baker's percentage", description: "Weight relative to the flour weight"),
  (key: "hyd", long: "hydration", description: "Water as a baker's percentage"),
  (key: "tdw", short: "TDW", long: "total dough weight", description: "Everything in the bowl"),
)

#let hidden = (
  (key: "crumb", long: "crumb structure"),
  (key: "ear", short: "ear", plural: "ears"),
)

#register-glossary(dough-terms)
#register-glossary(measures, use-key-as-short: false)
#register-glossary(hidden)
// every description ends with a full stop from here on
#style-entries("description", d => if d != none [#d.])

#let title(entry) = {
  smallcaps(text(weight: "bold", entry.short))
  if entry.long != none [ (#entry.long)]
  if entry.custom != none {
    h(0.4em)
    box(stroke: 0.4pt, inset: (x: 2pt), outset: (y: 1.5pt), text(6pt, entry.custom.origin))
  }
}

#let pages(entry, deduplicate: false) = {
  let refs = get-entry-back-references(entry, deduplicate: deduplicate)
  if refs.len() > 0 {
    h(1fr)
    text(8pt)[#if refs.len() == 1 [p.] else [pp.] #refs.join(" · ")]
  }
}

#align(center, text(14pt, weight: "bold")[Notes from the Bakehouse])

#heading(outlined: false)[Terms]

#print-glossary(
  dough-terms,
  minimum-refs: 2,
  deduplicate-back-references: true,
  description-separator: [ --- ],
  group-heading-level: 2,
  group-sortkey: g => if g == "" { "zzz" } else { g },
  shorthands: ("plural", "capitalize", "capitalize-plural", "short", "long", "description"),
  user-print-title: title,
  user-print-description: entry => emph(entry.description),
  user-print-back-references: pages,
  user-print-group-heading: (group, level: none) => block(
    above: 1em,
    below: 0.6em,
    width: 100%,
    stroke: (bottom: 0.5pt),
    inset: (bottom: 2pt),
    heading(level: level, outlined: false, upper(group)),
  ),
  user-group-break: () => v(2pt),
)

#heading(outlined: false)[Measures]

#print-glossary(
  measures,
  show-all: true,
  disable-back-references: true,
  user-print-gloss: (entry, ..args) => grid(
    columns: (14mm, 34mm, 1fr),
    gutter: 2mm,
    strong(if entry.short != none { entry.short } else [--]), entry.long, entry.description,
  ),
)

#print-glossary(hidden, invisible: true)

#context {
  let counts = count-all-refs(entry-list: dough-terms, groups: ("Tools",))
  [Tools are mentioned #counts.map(c => [#c.at(0): #c.at(1)]).join(", ") times;
    measures are #if there-are-refs(entry-list: measures) [used] else [unused] in the text.]
}

#outline(title: [Chapters])

#pagebreak()
#set page(numbering: "1")
#counter(page).update(1)
#set heading(numbering: "1.")

= Mixing with @bp

All recipes are written in @bp, so that a batch scales with the flour.
A dough of 75 % @hyd is easy to handle; above 80 % @hyd the @bulk must be
shorter and cooler. The @levain is fed the evening before. A young
@levain smells of yoghurt, an old one of vinegar.

#lorem(50)

The @ddt for this bread is 26 °C. If the kitchen is cold, the water is
warmed until the @ddt is met; the @tdw of a standard batch is 1.9 kg.
An @autolyse of forty minutes makes the dough extensible. #lorem(45)

#block(stroke: 0.5pt, inset: 6pt, width: 100%)[
  *From the glossary:* #print-gloss("levain", disable-back-references: true)
]

= Shaping

After the @bulk the dough is divided. Each piece rests, is shaped and
goes seam-up into a @banneton. Two @banneton:pl fit on one shelf of the
fridge. #Glspl("banneton") must be floured with rice flour; long loaves lie in
a @couche instead.
#lorem(70)

The word #gls("banneton") is #context gls-custom("banneton", ctx: false).origin;
it belongs to the group "#gls-group("banneton")" and its plural is
"#gls-plural("banneton")". #lorem(40)

#pagebreak()

= Baking

The loaf is turned out on a @peel and scored with a @lame. A shallow
cut at a low angle gives the best @spring and a pronounced @ear; two
@ear:pl are possible on a long loaf. #lorem(60)

Half of the @spring happens in the first eight minutes.
#Gls("spring") is lost if the dough was proved too long. The
@crumb tells afterwards whether the @bulk was right: an even
@crumb:long with a few large holes is the aim. #gls("bulk", first: true)
is the step most often cut short.

#figure(
  table(
    columns: 4,
    table.header[Step][Minutes][°C][Tool],
    [@autolyse], [40], [24], [---],
    [@bulk], [240], [26], [---],
    [Prove], [600], [4], [@banneton],
    [Bake], [45], [240], [@peel],
  ),
  caption: [Timetable of one bake, loaded with the @peel],
)

#lorem(80) A second @lame is kept in reserve.
