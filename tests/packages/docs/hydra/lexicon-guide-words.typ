// hydra 0.6.3: guide words of a lexicon from custom elements: labelled metadata
// (`selectors.custom(<entry>, ancestors: heading)`), figures of a custom kind, custom
// `display`, hydra in running text and footer via `anchor()`, default (auto) top margin.
// Engine: label and `figure.where` queries scoped by ancestors, metadata values, positions.
#import "@preview/hydra:0.6.3": hydra, anchor, selectors

#let entries = selectors.custom(<entry>, ancestors: heading)
#let plates = figure.where(kind: "plate")
#let word(ctx, e) = upper(e.value)

#set page(
  width: 120mm,
  height: 130mm,
  // No vertical margin given: hydra has to derive the default top margin.
  margin: (x: 12mm),
  header: context {
    anchor()
    set text(size: 8pt, tracking: 0.5pt)
    // first and last entry on the page, as in a printed dictionary
    hydra(entries, display: word, skip-starting: false)
    h(1fr)
    text(tracking: 0pt, style: "italic", hydra(heading, skip-starting: false))
    h(1fr)
    hydra(entries, display: word, skip-starting: false, use-last: true)
    v(-5pt)
    line(length: 100%, stroke: 0.4pt)
  },
  footer: context {
    set text(size: 8pt)
    let plate = hydra(plates, skip-starting: false, display: (ctx, fig) => [
      #fig.supplement #numbering(fig.numbering, ..fig.counter.at(fig.location())):
      #fig.caption.body
    ])
    plate
    h(1fr)
    counter(page).display("i")
  },
)
#set text(size: 9pt)
#set par(justify: true)
#show heading.where(level: 1): set align(center)
#show heading.where(level: 1): set block(above: 1.4em, below: 1em)

#let entry(term, kind, body) = block(below: 0.9em, {
  [#metadata(term) <entry>]
  strong(term)
  [ ]
  emph(kind)
  [ ]
  body
})

#let plate(caption, body) = figure(
  kind: "plate",
  supplement: [Plate],
  caption: caption,
  block(width: 70%, height: 22mm, stroke: 0.5pt, inset: 4pt, body),
)

#align(center, text(15pt, weight: "bold")[A Small Lexicon of Sailing Terms])

This lexicon is consulted like any other: the header of each page names
the first and the last term on it. While you read this paragraph, the
running letter is "#context hydra(heading, skip-starting: false)" and
the nearest term is "#context hydra(entries, display: (ctx, e) => e.value, skip-starting: false)".

= A

#entry("abeam", "adv.")[At right angles to the keel of the vessel. #lorem(28)]
#entry("aft", "adv.")[Towards the stern. #lorem(35)]
#entry("anchor watch", "n.")[The part of the crew that stays on deck while the ship lies at anchor. #lorem(40)]
#entry("astern", "adv.")[Behind the vessel. #lorem(22)]

= B

#entry("backstay", "n.")[A stay leading aft from a mast. #lorem(45)]

#plate[Standing rigging of a cutter][
  #place(center + horizon, polygon(
    stroke: 0.6pt,
    (0mm, 18mm), (20mm, 0mm), (20mm, 18mm), (44mm, 18mm), (20mm, 2mm),
  ))
]

#entry("beat", "v.")[To sail to windward by a series of tacks. #lorem(50)]
#entry("bilge", "n.")[The lowest inner part of the hull. #lorem(30)]
#entry("bowline", "n.")[A knot forming a fixed loop. #lorem(60)]
#entry("bulkhead", "n.")[An upright partition below deck. #lorem(26)]

= C

#entry("cleat", "n.")[A fitting on which a rope is made fast. #lorem(34)]
#entry("close-hauled", "adj.")[Sailing as near to the wind as possible. #lorem(80)]

#plate[Points of sail][
  #place(center + horizon, circle(radius: 9mm, stroke: 0.6pt))
  #place(center + horizon, line(angle: 40deg, length: 18mm, stroke: 0.6pt))
  #place(center + horizon, line(angle: 140deg, length: 18mm, stroke: 0.6pt))
]

#entry("coaming", "n.")[A raised border round a hatch. #lorem(42)]
#entry("cringle", "n.")[A ring worked into the edge of a sail. #lorem(36)]

= D

Here the text between the heading and the first term is long enough to
fill most of a page, so that page has a letter but, for a while, the
guide words still point back at the previous letter's scope. #lorem(150)

#entry("davit", "n.")[A small crane for boats. #lorem(30)]
#entry("draught", "n.")[The depth of water a vessel needs. #lorem(48)]

In running text, still on the page whose header says so: the current
plate is "#context hydra(plates, skip-starting: false, display: (ctx, f) => f.caption.body)".

= E

#entry("ebb", "n.")[The falling tide. #lorem(25)]
#entry("ensign", "n.")[The national flag worn at the stern. #lorem(70)]
#entry("eye splice", "n.")[A permanent loop at the end of a rope. #lorem(55)]
