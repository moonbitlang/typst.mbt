// touying 0.8.0: deliberately fails inside the package: a heading built in code with
// `level:` instead of `depth:` has no `depth` field when the slide splitter inspects it
// (`field "depth" in heading is not known at this point`).
// Engine paths: field access on unsynthesized content, error trace through package code.
#import "@preview/touying:0.8.0": *
#import themes.simple: *

#show: simple-theme.with(aspect-ratio: "16-9")

= Generated headings

== Written in markup

This slide is fine.

#for name in ("Monday", "Tuesday") {
  heading(level: 2, name)
  [Opening hours on #name: nine to five.]
}
