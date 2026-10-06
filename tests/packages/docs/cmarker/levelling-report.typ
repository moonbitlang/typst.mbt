// cmarker 0.1.10 with mitex 0.2.7: two Markdown files read from disk, LaTeX math in
// Markdown (`math: mitex`, inline and display, environments), `h1-level`, `label-prefix`
// and `prefix-label-uses`, generated heading labels (duplicates numbered) referenced from
// Typst and from Markdown, citations from Markdown into a `.bib`, `scope` with custom
// functions, YAML front matter through `render-with-metadata`.
// Engine: two wasm plugins in one document (one calling into the other through eval),
// labels and references across evaluated fragments, bibliography, yaml, outline.
#import "@preview/cmarker:0.1.10"
#import "@preview/mitex:0.2.7": mitex

#set page(width: 150mm, height: 190mm, margin: (x: 14mm, y: 15mm), numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.1")
#set math.equation(numbering: "(1)")
#show link: set text(fill: rgb("#7b3f00"))
#set table(stroke: 0.4pt, inset: 4pt)

#let rule-box(body) = block(
  width: 100%,
  stroke: (left: 2.5pt + rgb("#7b3f00")),
  fill: rgb("#fbf3e8"),
  inset: 7pt,
  body,
)

#align(center, text(15pt, weight: "bold")[Survey Office Notes])

#outline(depth: 2)

// Chapter one: top-level Markdown headings become level-one headings.
#cmarker.render(
  read("levelling.md"),
  math: mitex,
  label-prefix: "lev-",
  // Uses of labels are not prefixed, so that `[@key]` can also cite the bibliography.
  prefix-label-uses: false,
  scope: (rule-box: rule-box),
)

= From the Typst side <typst-side>

The headings of the Markdown file can be referenced from here through
their generated labels: the bound is derived in @lev-error-budget, the
bending of the line in @lev-refraction, and the two sections that share
a title are @lev-field-rules and @lev-field-rules-1 on pages
#context counter(page).at(<lev-field-rules>).first() and
#context counter(page).at(<lev-field-rules-1>).first(). The same works for
the appendix, whose headings sit one level deeper: @app-worked-example
and @app-error-budget.

// The appendix: its headings are shifted by one level and its metadata
// block is parsed as YAML.
#let (meta, appendix) = cmarker.render-with-metadata(
  read("levelling-appendix.md"),
  math: mitex,
  h1-level: 2,
  label-prefix: "app-",
  metadata-block: "frontmatter-yaml",
)

== Appendix: #meta.title

#table(
  columns: 4,
  table.header[*Surveyor*][*Date*][*Instrument*][*Loop*],
  meta.surveyor,
  [#meta.date (#type(meta.date))],
  [#meta.instrument.model ($sigma_0 = #meta.instrument.sigma0_mm "mm"$)],
  [#meta.loop_km km],
)

#appendix

#bibliography("levelling.bib", title: [Sources])
