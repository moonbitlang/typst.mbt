# Documents that use real packages

The upstream suite never imports a package from the registry. Popular
packages are large Typst programs (closures, state, counters, `context`,
show rules, introspection that needs several layout iterations,
WebAssembly plugins), and the first one that was tried (touying) found a
bug that 3,792 upstream test files had not. The `packages` stage compiles
documents that use such packages with upstream Typst and with the port and
compares the results.

## What is here

- `manifest.tsv`: the pinned packages (name, version, SHA-256 and size of
  the registry's archive, licence, role). The packages are **not** part of
  this repository: `scripts/packages.sh` downloads the archives from
  `https://packages.typst.org/preview/`, verifies them against the manifest
  and makes `.repos/typst-packages/preview/<name>/<version>/` exactly what
  they contain (`--check` verifies without changing anything or using the
  network; anything in that directory that the manifest does not list is an
  error). Their licences are those of their authors (the `licence` column, from
  each package's `typst.toml`).
- `docs/<package>/<name>.typ`: the documents, one case each, written for
  this repository (original content: none is a copy of a package's examples
  or manual). The directory is named after the package that the documents
  exercise; other files in it are data that they read (`.bib`, `.md`,
  `.csv`, ...). `docs` is the project root, so a document is
  `/<package>/<name>.typ`. Every document starts with a comment saying what
  it exercises; the list below is made from those comments. Documents named
  `error-*.typ` fail on purpose inside a package: the diagnostics, with the
  trace of calls through the package, are compared too.

## Running

```sh
scripts/packages.sh                 # fetch and verify the packages
scripts/goldens.sh packages         # upstream's results (needs Rust)
moon run tests/runner --target native --release -- packages [filter] [-v] [--times]
```

The oracle (`oracle/src/packages.rs`) and the runner
(`tests/runner/packages_stage.mbt`) compile every document in the same
world: what `typst compile --ignore-system-fonts --creation-timestamp
43200` sees (the standard library, the fonts embedded in the CLI, no system
fonts, the fixed time of the test world: 1970-01-01, 12:00 UTC). A template
that asks for a font that is not embedded falls back in both and warns in
both. They compare

- `packages frames`: the document in the `typst-frame-v1` format of the
  `paged` stage (every frame, glyph, shape, span and tag, floats as bits)
  with the diagnostics, each followed by its tracepoints; locations inside
  a package are written with the package (`"@preview/cetz:0.5.2/src/..."`);
- `packages svg`: the SVG of the `svg` stage (merged pages), after renaming
  the hash-derived ids; the stage also reports how many are byte-identical.

`scripts/packages_cli.py` runs the same documents through the two command
line programs instead (an upstream `typst` binary and the port's `cli`) and
compares what the stage cannot: the rendered diagnostics on stderr, the
exit status (1 for `error-*.typ`, else 0), the PNG pixels at 72 ppi, and
the time both need.

## When a document differs

Reduce it to a document without the package, find the upstream code that
defines the behaviour, fix the port, and add the reduction as a `packages:`
case to `scripts/gen_typst_oracle.py` (`typst/oracle_wbtest.mbt` records
what the upstream binary reports). Never change a document to hide a
difference, and never edit a golden.

## Adding a package

1. Add its line to `manifest.tsv` (`shasum -a 256` of the archive, its
   size, the licence of its `typst.toml`), and a line for every package it
   imports that is not listed yet (`grep -rhoE '@preview/[a-z0-9-]+:[0-9.]+'`
   over its sources); run `scripts/packages.sh`.
2. Write documents in `docs/<package>/`, starting with the comment.
3. `scripts/goldens.sh packages`, run the stage, and update the two
   `packages` lines of `scripts/ci/stages.tsv` and the list below.

## The documents

99 documents for 36 packages (the comment at the top of each file is the reference; this list repeats them).

### alchemist (0.2.0)

- `error-cycle-start.typ`: a panic raised by the package while it draws (a cycle whose body starts with a fragment). Compares the error message and the trace through alchemist's drawer and the cetz 0.5.2 canvas callbacks.
- `resonance-reactions.typ`: resonance and reaction schemes. Operators between molecules, resonance and polymer parentheses with indices, Lewis structures (pairs, single electrons, lines, rectangles, charges), hooks and remote links, hidden parts, cetz drawing in the same canvas (curved electron arrows), draw-skeleton inside a cetz canvas, skeletize-config. Schemes in numbered figures and a breakable list.
- `skeletal-formulas.typ`: skeletal formulas. Fragments from strings and equations (indices, exponents, charges, colours, vertical), single/double/triple bonds with offsets and strokes, filled, hollow and dashed wedges, branches, cycles with arcs, fused rings, named links, configuration. Molecules in a table, in figures, inline and at text size.

### arkheion (0.1.2)

- `custom-authors.typ`: the other paths of the template: `custom-authors` content instead of the author grid (the document metadata still comes from `authors`), no abstract, no keywords, no date, run-in level-4 headings, a table that breaks across pages with repeated header and footer, a footnote, no appendix and no bibliography. Engine paths: heading show rule by level (levels 3 and 4 take different branches), table header/footer repetition, grid cells with colspan, page numbering.
- `pollinator-preprint.typ`: an arXiv-style preprint with four authors (three with ORCID: the package's SVG icon inside a link inside a grid), abstract, keywords, date, headings to level 4 (run-in from level 4), numbered equations, tables, a drawn figure, footnotes, appendices via `arkheion-appendices` (letter numbering from a closure) and a bibliography. Engine paths: SVG image from a package, nested grids with negative padding, heading show rule by level, counter(heading).update + numbering function, page numbering, CSL.
- data: `refs.bib`

### basic-resume (0.2.9)

- `a4-centered.typ`: the other option values: A4, centred name and contact line, Libertinus Serif, larger sizes, another accent colour, `lang: "de"` with German text (hyphenation), a partial header (no pronouns, LinkedIn or ORCID: the filter of empty items), `edu` with `consistent: true`, and the generic one-by-two / two-by-two helpers used directly. Engine paths: German hyphenation and justification, align in show rules, rgb from string, math `dash.em` joined with strings, empty-string defaults.
- `hydrologist.typ`: a two-page US-letter resume with every header field (pronouns, phone, location, email, GitHub, LinkedIn, site, ORCID with the scienceicons icon), a coloured accent, and all entry helpers: edu, work, project (with and without role, url, dates), certificates, extracurriculars, dates-helper, nested lists. Engine paths: show rules on heading levels and links (underline + fill), `h(1fr)` rows, inline SVG icon from a package (image decoded from bytes), ligatures off, justified lists.

### cetz (0.3.4, 0.5.2)

- `error-unknown-anchor.typ`: an error raised inside the package while it resolves a coordinate (an anchor name that the element does not have). Compares the message, which lists the valid anchors, and the trace through nested groups, closures and the canvas.
- `hive-3d-loops.typ`: ortho and perspective projections (depth sorting, face culling, on-xy/on-xz/on-zy planes), a computed surface, and large composed 2D figures from loops (honeycomb, polar dance diagram, a linear congruential generator for jitter). Many drawables per canvas; vector/matrix helpers.
- `orchard-trees-marks.typ`: tree layout (wasm plugin + measured nodes), grids, arcs and angle marks, bezier/catmull/hobby curves, the mark catalogue, path decorations and braces, content placement (anchors, rotation, frames, two-point boxes). Canvases in a table, a grid and inline; intersections.
- `shapes-anchors.typ`: basic shapes, paths, named anchors, relative/polar/barycentric coordinates, transforms and style cascades, in figures with captions and references. Stresses the wasm plugin, measure of content nodes, nested groups, boolean path operations and context-dependent canvas lengths.
- `tram-map-v034.typ`: a schematic tram map with layers, groups with custom anchors, viewports, hidden helper paths, intersections, the 0.3 tree callbacks (node, parent) / (from, to, ..), angle marks and an ortho cut. Two cetz versions may be loaded in one run.

### cetz-plot (0.1.4)

- `charts-report.typ`: column and bar charts (basic, clustered, stacked, stacked100, error bars), pie and donut charts with inner/outer labels, radar chart, pyramid, box-and-whisker, violin and error-bar data plots with annotations, smartart process/cycle. Data from a CSV file; charts in figures, in a table cell, in a two-column grid and inline.
- `function-plots.typ`: sampled function plots (heavy float computation), axis styles scientific / scientific-auto / school-book / left, legends inside and outside, custom tick formats, log axes, secondary axes, fill-between, hypographs, parametric curves, contours, annotations and plot anchors. Figures with captions, references and a plot per grid cell.
- data: `library-loans.csv`

### charged-ieee (0.1.4)

- `a4-letter.typ`: the other option values: A4 paper (fixed margins), two authors, an abstract without index terms, `figure-supplement: [Figure]`, a listing figure (the generic-supplement branch of the caption rule), level-4 and unnumbered headings, the alternative spelling of the acknowledgement heading, multi-line aligned equations, a full bibliography of uncited entries. Engine paths: float placement with `auto`, figure kinds and counters, nested enum numbering "1)a)i)", term lists in columns.
- `sensor-paper.typ`: a two-column US-letter paper with four authors, abstract, index terms, headings to level 3, numbered equations and the template's equation references, floating single-column and page-wide figures/tables, footnotes, raw blocks and an IEEE bibliography. Engine paths: parent-scoped floats in columns, show rules on figure/ref/heading with counters, context, CSL (ieee) citations, footnotes inside columns, column balancing.
- data: `refs.bib`

### cmarker (0.1.10)

- `allotment-notes.typ`: a Markdown file next to the document (`read`) rendered by the package's WebAssembly plugin: headings, emphasis, sub/sup/mark, nested and ordered lists, task lists (`task-list-marker`), links and reference links, block quotes, hard breaks, thematic break, code blocks, pipe and HTML tables (row/colspan, head, foot), footnotes, description lists, inline SVG in a figure, custom HTML elements (`html:`), raw Typst in comments with `scope`, excluded sections, smart punctuation. Engine: wasm plugin, eval of generated markup with a scope of closures, counters and context in list markers, SVG image from bytes, labels from generated markup.
- `error-description-list.typ`: an HTML description list with the package's default `<dl>` handler, which passes (term, description) arrays to `terms`: a type error inside a closure of the package that is called from markup generated by the plugin and evaluated with `eval`. Engine: error trace through eval'd source into package closures.
- `levelling-report.typ`: two Markdown files read from disk, LaTeX math in Markdown (`math: mitex`, inline and display, environments), `h1-level`, `label-prefix` and `prefix-label-uses`, generated heading labels (duplicates numbered) referenced from Typst and from Markdown, citations from Markdown into a `.bib`, `scope` with custom functions, YAML front matter through `render-with-metadata`. Engine: two wasm plugins in one document (one calling into the other through eval), labels and references across evaluated fragments, bibliography, yaml, outline.
- `render-options.typ`: the options of `render` side by side on Markdown given inline as raw blocks: `smart-punctuation`, `h1-level` (0 with a document title, 3, negative), `heading-labels` (github, jupyter, none) with links to the generated labels, `raw-typst` on and off, `show-source`, `scope` overriding element functions (heading, link, strong, raw, quote, divider), `html` overriding a default element, `frontmatter-raw`. Engine: many small plugin calls with different option bytes, eval scopes that shadow built-in element functions, `title` and `divider` elements, labels with unusual characters.
- data: `allotment.md`, `levelling-appendix.md`, `levelling.bib`, `levelling.md`

### codly (1.3.0)

- `error-stale-annotations.typ`: an annotated block followed by a block with `ranges` and `smart-skip`. The package resets annotations one introspection iteration late, so in the second iteration the later block builds a grid whose cells do not fit and layout fails inside the package. Engine: an error that only exists in an intermediate iteration must still be fatal.
- `figures-references.typ`: listings inside labelled figures: references to lines (`@label:line`), to highlights and annotations by label, `reference-by` line/item, `reference-sep`, `reference-number-format`, an outline of listings, a floating listing; inline raw untouched. Engine: nested show rules (figure > raw > raw.line), generated labels, hidden placed figures as reference targets, ref show through custom numbering, links across pages.
- `long-listings.typ`: long listings that break across pages: repeated header and footer (`header-repeat`, `footer-repeat`, cell args and transforms), `breakable: false` blocks that move to the next page, a generated 90-line listing, gradient zebra fill (separate layer). Engine: breakable blocks with clip and radius, grid headers/footers across pages, raw built from strings, show rules on raw.line for many lines.
- `review-features.typ`: line numbers, language boxes (`languages`, icons, `typst-icon` PNG, `lang-format`, `aliases`), zebra, `highlights` with tags, `highlighted-lines`, `annotations`, `range`, `ranges` + `smart-skip`, `skips`, offsets (`codly-offset`, `offset-from`), disable/enable, `no-codly`, `local` overrides. Engine: show rules on raw and raw.line, state per block, measure, grids with fills and strokes, package image.

### drafting (0.2.2)

- `margin-notes.typ`: margin notes on both sides with automatic overlap avoidance, phrase-highlighting notes, inline notes, per-reviewer styles, custom rect, hidden notes, changed defaults, and the outline of notes. Stresses here().position(), state updated from measured heights (several layout iterations), place + curve in boxes, queries by label, links to positions; several pages.
- `positioning.typ`: inside/outside margins with binding (notes swap sides on odd and even pages), explicit margins given to set-page-properties, rule-grid (relative, absolute, divisions, square), absolute-place, place-margin-rects, margin-lines, notes inside a container with an offset. Stresses layout() + state in set-page-properties, measure, metadata queries for absolute placement, many placed lines and labels.

### fletcher (0.5.8)

- `commutative-diagrams.typ`: commutative diagrams in math mode and call mode, labelled edges with math, hooks, two-headed, dashed and double arrows, bends, crossings, parallel shifted edges, 2-cells. Diagrams as numbered block equations with references, inline in text, in a grid and in a theorem box; measure-driven elastic grid layout on top of cetz 0.3.4.
- `flowchart-states.typ`: flowcharts and state machines. Node shapes, extrusions, named nodes and cetz anchors, polyline/corner/bent/loop edges, mark shorthands, custom mark dictionaries and the MARKS state, decorations, crow's foot notation, enclosing nodes, layers, hidden parts, a custom render callback; diagrams in figures, a breakable table and with context.

### gentle-clues (1.3.1)

- `breaking.typ`: breakable clues that split across pages, clues nested in lists, enums, clues in clues, in columns and in a figure. Stresses sticky header blocks, clip + stroke on broken blocks, state for the global breakable flag, footnotes and counters inside broken blocks.
- `predefined.typ`: all predefined clues, overridden titles/colours/icons, custom clues, the numbered task counter, global `gentle-clues` settings and translated titles via linguify 0.5.0 (text.lang switches, fallback). Stresses SVG icons from the package, state updates, context text.lang, toml database lookup, clipped blocks with partial strokes.

### glossarium (0.5.10)

- `bakery-custom-print.typ`: three registered lists; a glossary printed in the roman-numbered front matter with custom title/description/back-reference/group printers, `minimum-refs`, deduplicated back references and extra shorthands; a second one with `show-all`, `disable-back-references` and a custom gloss; a third one `invisible`; first-use styles (footnote, short-long), `style-entries`, `gls-custom`, `print-gloss`, `count-all-refs`. Engine: forward state (`final`) feeding layout before the uses, page numbering at locations.
- `error-unknown-key.typ`: `gls` with a key that was never registered: the package panics with its own `key not found` message from inside a `context` block. Engine: error trace through package code called from contextual content.
- `observatory-handbook.typ`: registered glossary with short/long/plural/longplural/description/group, first vs. later use, `@key`, `@key:pl`, `@Key`, `:short`/`:long`, `gls` options, terms in headings, captions and the outline, `reset-counts`, printed glossary with back references. Engine: show rule on `ref`, state updates and `final()`, label queries, links, figures.

### hy-dro-gen (0.1.1)

- `error-invalid-language.typ`: `syllables` with a language the plugin has no patterns for and no fallback: the WebAssembly plugin itself reports the error. Stresses a plugin error message and the trace through the package.
- `syllables.typ`: its WebAssembly plugin (hypher patterns): `exists`, `syllables` for words in many languages and scripts, the `languages` dictionary read from the package, fallbacks for unknown languages. Stresses plugin calls with byte arguments and returned byte strings (many calls, non-ASCII input), next to the compiler's own hyphenation of the same words in narrow columns.

### hydra (0.6.3)

- `book-headers.typ`: running headers of a book (`book: true`, odd/even pages, chapter on verso and section on recto), `skip-starting`, hydra in the footer through `anchor()`. Engine: queries before/after `here()` from the page header, positions, counters at locations.
- `lexicon-guide-words.typ`: guide words of a lexicon from custom elements: labelled metadata (`selectors.custom(<entry>, ancestors: heading)`), figures of a custom kind, custom `display`, hydra in running text and footer via `anchor()`, default (auto) top margin. Engine: label and `figure.where` queries scoped by ancestors, metadata values, positions.
- `two-columns.typ`: headers of a two-column document (`page(columns: 2)`): first vs. last section of the page (`use-last`), level ranges (`selectors.by-level`), custom `display`, `prev-filter`/`next-filter`. Engine: header queries with column layout, floats, colbreaks.

### ilm (2.1.1)

- `bakers-handbook.typ`: a multi-chapter handbook with the default cover page (three authors, abstract, date format), preface, table of contents, chapter page breaks, the alternating footer with the chapter name, external-link circles, custom raw text settings, blockquotes, figures/tables/listings and their three indices, an appendix with its own numbering, footnotes, numbered equations and a bibliography. Engine paths: footer context with queries (heading before here, page of each chapter), show rules on link/raw/heading/table.cell, weak page breaks, outline with several targets, counter(figure.where(kind)) at the end, breakable table figures.
- `glasshouse-notes.typ`: the other option values: A5 paper, one author given as a string, another date format, abstract on the cover, no preface, a table of contents with a custom title, no chapter page breaks, no external-link circles, the right-aligned footer with chapter, Typst's default raw styling, indices and appendix with their default titles and numbering, an APA bibliography. Engine paths: several chapters per page (footer query of "chapter starts on this page"), long breakable table across pages, outline indent, default-valued dictionary lookups (`.at(key, default: ..)`), APA author-date citations.
- data: `refs.bib`

### lilaq (0.6.0)

- `bars-stats-fields.typ`: bar and hbar (grouped, stacked, custom tick labels through an elembic show rule), asymmetric error bars, fill-between bands, box plots and violins, contour (marching squares) and colormesh with colorbars, and a quiver field. Heavy array computation; images from generated pixel data; figures side by side and a diagram inside a table.
- `layout-set-rules.typ`: a multi-diagram dashboard. Shared settings through set and show rules of lilaq's elembic elements (set-diagram, set-tick, set-grid, set-legend, set-title, set-label, set-spine, cond-set, show_, selector), lq.layout for aligned grids with spanning cells (two-pass layout with query and metadata), scoped themes, style cycles, a datetime axis.
- `lines-scales-twin.typ`: line and scatter plots with legends, marks, manual and formatted ticks, subticks, log and symlog scales, twin and dependent secondary axes, error bars, steps, smoothing, annotations (place, line, rect, hlines/vlines). Stresses elembic elements (state-free styling via metadata/context/query), zero number formatting, measure and layout.

### lovelace (0.3.1)

- `algorithms.typ`: pseudocode-list with nested indentation, line numbers, line labels and references to lines, custom keywords, booktabs with numbered titles, inside figures of kind "algorithm" with captions. Stresses list -> grid transformation, grid cells with rowspans and partial strokes, figure counters updated per line, query before here().
- `low-level.typ`: the low-level `pseudocode` function with indent, no-number and with-line-label, preset configurations via `.with`, a long listing that breaks across pages (repeated title header), a list of algorithms and line references across pages. Stresses grid header/footer repetition, rowspan cells split at page breaks, references to figures inside boxes in grid cells.

### meander (0.4.4)

- `error-reflow.typ`: the documented entry point, `meander.reflow`, with placed obstacles, two containers, a circular contour and an overflow option. With Typst 0.15 it fails inside the package: `here().position()` is `none` for the location of a `layout` callback, and the package reads `.x` of it. Stresses the error trace through a layout callback and package closures.
- `internals-flow.typ`: `meander.reflow` fails with Typst 0.15 (see error-reflow), so this document drives the package's engine itself: elements from placed/container/content, `tiling` (separate, create-data, next-elem, push-elem) for the zones around obstacles, `internals.fill-box` for the bisection of content, and the contour functions (margin, grid, horiz, width, ascii-art, phantom), tags with `invisible`, and a query callback. Stresses measure() in layout(), deep content introspection and rebuilding (paragraphs, strong/emph, lists, math), many placed boxes, three pages.

### mitex (0.2.6, 0.2.7)

- `error-unbalanced.typ`: LaTeX that the converter rejects (an environment that is never closed and a stray closing brace): the error is raised by the WebAssembly plugin and reported through the package's call chain. Engine: plugin error results turned into diagnostics, trace through package functions.
- `formula-sheet-0-2-6.typ`: a one-page formula sheet set from LaTeX: `mitex`, `mi`, a macro, cases, a matrix, text mode with a list, and the converted source next to each formula. Engine: a second wasm module of the same package family, eval of generated math, grid.
- `latex-tour.typ`: LaTeX converted at compile time by the package's WebAssembly plugin: inline (`mi`) and display (`mitex`) math, environments (aligned, cases, matrix family, array), user macros, colours, text mode (`mitext`: sections, lists, labels and references), `mitex-convert` output, raw blocks turned into math by show rules. Engine: wasm plugin calls with bytes, `eval` of generated math/markup with a large scope, show rules on raw, equation numbering and references.
- `mixed-lecture.typ`: a longer document in which LaTeX formulas (`mitex`, `mi`, numbered and labelled) and native Typst math share one equation counter, are referenced from both sides, sit in tables, lists, footnotes and figures, and use macros defined once in a preamble string. Many plugin calls (about ninety) in one compilation. Engine: wasm plugin called repeatedly with different inputs, eval scope reuse, equation numbering and supplements, references into evaluated content, page breaks between formulas.

### modern-cv (0.10.0)

- `coverletter-fr.typ`: a French cover letter (`coverletter`, `hiring-entity-info`, `letter-heading`) with the default signature built from `author.signature` (a drawn curve), the default closing from lang.toml, custom heading/signature padding and alignment, paragraph spacing, a second page so that the footer counter runs, and a custom salutation. A second letter-heading uses the default "dear". Engine paths: linguify inside content (context + state database), three-box footer with 1fr widths, underline with `evade: false`, `align(bottom)` closing, pad with spread args.
- `error-custom-item.typ`: deliberately fails inside the package: a `custom` contact item without a `link` reaches `link("" + none)` ("URL must not be empty"). Engine paths: error with a trace through three package closures, warnings emitted before the error (unknown fonts), `str + none` joining.
- `resume-de.typ`: the other option values of `resume`: German (`language: "de"`, title and footer text from lang.toml), accent colour given as a string, uncoloured headers, no footer, no small caps, US-letter paper, a drawn profile picture (clipped to a circle by the template), embedded fonts for body and header, a custom contact separator and inset, entries with per-entry accent/location colours, no address icon. Engine paths: clip with radius on a block, grid with fixed row height, German hyphenation, linguify with a non-default language, gradients inside clipped content.
- `resume-en.typ`: an English resume with every author field (birth, phone, email, homepage, GitHub, GitLab, Bitbucket, LinkedIn, Twitter, Bluesky, Mastodon, Scholar, ORCID, website, custom items with and without icon, address with icon), no profile picture, and all section helpers: resume-entry (with title-link), resume-item, resume-gpa, resume-certification, resume-skill-item, resume-skill-grid, github-link, plus a publication list from a .bib (`full: true`). Two pages with the footer. Engine paths: fontawesome fallback glyphs (missing icon fonts), linguify lookups from TOML, `set document` inside context, sticky blocks, `box(width: 1fr)` rules, text weights "thin"/"light" resolved against the embedded fonts, page footer with counter.
- data: `publications.bib`

### numbly (0.1.0)

- `statutes.typ`: heading numbering patterns per level ({n:format}, plain {n}, none for a level, a function for a level, the default beyond the last pattern), the same for nested enums (full: true), page numbering, used with outline, references, and a switch of pattern for an appendix. Stresses numbering closures called from headings, outline entries, references and counters; regex replace with a callback; several pages.

### octique (0.1.1)

- `project-board.typ`: Octicons as SVG images built from strings (image from bytes, format "svg", recoloured by string replacement). Icons inline in paragraphs and headings, as list markers, in a status table, in a sized and coloured gallery, inside show rules, links, a page header and an outline; the raw SVG source through octique-svg. Many small SVG images.

### oxifmt (0.2.1, 1.0.0)

- `error-bad-format.typ`: a format string with an unclosed replacement field; the package rejects it with its own assertion. Stresses the error trace through the package's parser functions.
- `formats-0-2.typ`: the older strfmt (positional/named arguments, repr mode, fill/alignment/width, sign, zero padding, radix, precision, scientific notation, decimal separator), used to build a fixed-width report. Stresses its string code under the current compiler (type checks on values, regex, UTF-8 aware padding), raw blocks built from formatted lines, results in a table.
- `formats-1-0.typ`: strfmt with positional, indexed and named arguments, escaped braces, repr mode, fill/alignment/width (also from arguments), sign, zero padding, radix with prefixes, precision, scientific notation, decimals, inf/NaN, decimal and thousands separators (fixed and variable groups). Stresses string code: regex matching, codepoint slicing, float and decimal to string conversion, repr of many value types; results shown in tables.

### physica (0.9.8)

- `mechanics-notes.typ`: derivatives (`dv`, `pdv` with orders, mixed orders, styles), differentials (`dd`, `var`, `difference`), vectors and vector calculus, braces (`Set`, `Order`, `evaluated`, `expval`), bra-ket, special matrices (dmat, admat, imat, zmat, jmat, hmat, xmat, rotations, grammat, mdet), tensors, isotopes, Taylor terms, `hbar`, `signals`. Engine: math layout of attach/lr/mid/mat/frac built from code, `measure` inside context (large-style derivatives), numbered equations with references, inline vs. display.
- `transpose-dagger.typ`: the document-wide show rules `super-T-as-transpose` and `super-plus-as-dagger` (scoped and global, with their exceptions: integrals, sums, limits, scripts, norms), `TT`, row vectors, inner products, together with document-wide math settings (matrix delimiters, numbering per section, supplement, equation text size). Engine: show rule on math.attach that rebuilds attachments, element equality with `$..$.body`, counters in equation numbering, references to equations.

### pinit (0.2.2)

- `annotations.typ`: pins in text and in math, highlights and rects over pin groups, arrows and double arrows between pins, point-to / point-from / line-to annotations, placed content, the same pin names reused on a later page, a custom callback computing from pin positions. Stresses labels built from page numbers, query(...before(here())), location().position(), absolute placement by negative offsets, curves.
- `fletcher-edges.typ`: pins in table cells and in a list with arrows, pins inside raw code through a show rule, and one pinit-fletcher-edge with the fletcher 0.5.8 module passed explicitly (a bent, labelled edge). Stresses a fletcher/cetz diagram placed absolutely, a pin inside a hidden diagram queried one layout iteration later (the edge is the last annotation of the document so that layout converges), regex show rules on raw text.
- `fletcher-unconverged.typ`: two pinit-fletcher-edge calls (fletcher 0.5.8 passed explicitly) in one document. Each edge needs every layout iteration for itself, and the second one's queries see the first one's late elements, so the document does not converge: the warning with the observed element counts per run is the point of this document. Stresses the convergence check and its diagnostics (hints, run counts).

### quill (0.8.0)

- `circuits-grid-model.typ`: quill 0.8.0, grid model: gates, controls (closed, open, classical), targets, swaps, phases, meters, multi-qubit gates with inputs/outputs, sticks with braces, wire bundles, setwire, labels, gate groups, slices, repeat blocks, permutations, manual placement, scaled circuits. Stresses measure in context, absolute placement, math layout inside boxes.
- `error-baseline.typ`: an error raised inside the package while the circuit is laid out (a content baseline reaches an undefined variable in quantum-circuit.typ). Compares the diagnostic and its trace through package code and a context block.
- `tequila-composed.typ`: quill 0.8.0, tequila submodule: instruction-driven circuits (single, controlled and multi-controlled gates, ranges of qubits, barriers, measurements to classical wires), templates (qft, graph-state), composed sub-circuits at offsets, decorations on top. Circuits generated in loops, in figures with subcaption grids, in a numbered equation and a table.

### showybox (2.0.4)

- `breakable.typ`: breakable boxes that split across pages, nested boxes, boxes in columns, with footnotes and a running header. Stresses breakable blocks with fill/stroke/radius over several regions, shadows around broken blocks, column breaks, footnotes inside blocks.
- `styles.typ`: titled boxes with frames, dashes, shadows, separators, footers, boxed titles (anchors, offsets) and reusable styles. Stresses counter + state per box, state.final() for the boxed title height, place/hide pre-rendering, nested blocks with strokes and radii.

### subpar (0.2.2)

- `grids.typ`: subpar.grid with drawn sub figures, references to sub figures and super figures, custom numberings (pattern and function), grid arguments passed through, a list of figures with and without sub figures. Stresses nested figures with show-set rules per kind, counters stepped and rolled back, context numbering, references across pages, outline of figures.
- `super.typ`: subpar.super with free layouts (stack, columns), table and raw kinds, show-sub and show-sub-caption overrides, floating super figures (placement, scope) in a two-column page, translated supplements. Stresses show rules that wrap figures and captions, kinds gathered from content, floats with parent scope, counter(figure.where(kind)) per kind.

### theorion (0.6.0)

- `fancy-notes.typ`: fancy cosmos (showybox frames), numbering inherited from two heading levels, references ([-], [!!], custom supplement), a list of theorems, proofs with QED placement, appendix numbering, restated theorems. Stresses query-based counters (metadata + labels), state.at/final, show rules on figure/ref/outline, breakable figures over several pages.
- `rainbow-clouds.typ`: rainbow cosmos for the main text and clouds cosmos for an insert (both share the query-based counters), custom fills, nested environments (corollary inside a theorem), numbered equations next to proofs, a combined outline of several kinds, pages in two columns. Stresses nested figures, counters inherited through nesting, ref show rules stacked per kind, breakable blocks with one-sided strokes.
- `simple-custom.typ`: simple cosmos, custom environments from make-frame (own counter, counter shared with another frame, counter inherited from another richer counter), zero-fill/leading-zero, inherited levels, indent modes, QED symbols, hidden answers, supplements in several languages. Stresses dictionaries of closures, query before/after, state.final, figure kinds with show rules, par first-line-indent repair.

### timeliney (0.4.0)

- `hut-renovation.typ`: Gantt charts with two header lines, header groups, task groups with bars and bar labels, tasks with several bars, in-place and aligned milestones, grids, offsets and custom line styles. The chart width follows `layout`, so the same function is drawn on a portrait page, in a figure, on a landscape page and in a narrow column.

### touying (0.8.0)

- `error-heading-level.typ`: deliberately fails inside the package: a heading built in code with `level:` instead of `depth:` has no `depth` field when the slide splitter inspects it (`field "depth" in heading is not known at this point`). Engine paths: field access on unsynthesized content, error trace through package code.
- `feature-tour.typ`: a feature tour on a theme defined in the document (`touying-slides` with own slide/title/section/focus functions, config-page/-colors/-methods/-store, progress bar, left-and-right/left-mid-right, progressive outline): pause/meanwhile/jump, uncover/only, alternatives(-match/-fn/-cases), effect, item-by-item(-fn), waypoints, animate + swap, callback-style slides, covers, math with pauses, numbered equations, touying-mitex (wasm), touying-raw, cetz 0.5.2 and fletcher 0.5.8 reducers, composer/cols/lazy layout, fit-to-height/width, checkerboard, speaker notes, per-slide config, touying-recall, labels and references across slides, appendix with frozen counters. Engine paths: metadata-driven content rewriting, states/counters across 78 pages, measure/layout in context, hide, query-based headers, wasm plugin, frozen counters.
- `handout-notes.typ`: handout mode with speaker notes on a second screen (simple theme): `config-common(handout: true, handout-subslides: ..)` keeps chosen subslides of each animated slide, `show-notes-on-second-screen: right` doubles the page width and puts the notes panel beside every slide, `handout-only`/`presentation-only` content, notes with pauses, per-subslide notes, Markdown-mode notes, a per-slide handout override, footnotes and a bibliography-free reference list. Engine paths: page width computed from config, `place` of a panel outside the margins, state read in the footer (current note), dropped subslides and their counters.
- `long-generated.typ`: a long deck generated from data (dewdrop theme with the sidebar navigation): four rounds of three quiz questions, every question slide built by one function with a pause, `item-by-item` over a generated enum, `uncover` and `alternatives`; headings come out of `for` loops; a state is updated once per round and read in the footer and on a final summary that also queries the headings. About 80 pages. Engine paths: slides split out of code-generated sequences, progressive outline in the sidebar of every page, slide/page counters and `final()`, state across many pages, repeated layout of similar content (memoization, location disambiguation).
- `minimal-default.typ`: a minimal deck: the default theme with no configuration at all, slides split by headings and by `---`, a few `#pause`s, one `#meanwhile`, plain lists, a table and an equation. Engine paths: the heading-driven slide splitter (content tree walk), subslide repetition with `hide`, slide and page counters, invisible headings.
- `theme-aqua.typ`: the aqua theme with title, outline and focus slides. The same deck for every theme: `#pause` and `#meanwhile` in text and lists, `uncover`/`only`/`alternatives`, a two-column slide with a table, equations with pauses and `touying-equation`, raw code, a figure, sections and subsections. Engine paths: the theme's show rules and page setup, heading-driven slide splitting, subslide repetition, counters and states read in headers and footers.
- `theme-default.typ`: the default theme without title, outline or focus slides (the bare theme). The same deck for every theme: `#pause` and `#meanwhile` in text and lists, `uncover`/`only`/`alternatives`, a two-column slide with a table, equations with pauses and `touying-equation`, raw code, a figure, sections and subsections. Engine paths: the theme's show rules and page setup, heading-driven slide splitting, subslide repetition, counters and states read in headers and footers.
- `theme-dewdrop.typ`: the dewdrop theme with title, outline and focus slides, a footer function and the mini-slides navigation. The same deck for every theme: `#pause` and `#meanwhile` in text and lists, `uncover`/`only`/`alternatives`, a two-column slide with a table, equations with pauses and `touying-equation`, raw code, a figure, sections and subsections. Engine paths: the theme's show rules and page setup, heading-driven slide splitting, subslide repetition, counters and states read in headers and footers.
- `theme-metropolis.typ`: the metropolis theme with title and focus slides. The same deck for every theme: `#pause` and `#meanwhile` in text and lists, `uncover`/`only`/`alternatives`, a two-column slide with a table, equations with pauses and `touying-equation`, raw code, a figure, sections and subsections. Engine paths: the theme's show rules and page setup, heading-driven slide splitting, subslide repetition, counters and states read in headers and footers.
- `theme-simple.typ`: the simple theme with a footer and without title, outline or focus slides. The same deck for every theme: `#pause` and `#meanwhile` in text and lists, `uncover`/`only`/`alternatives`, a two-column slide with a table, equations with pauses and `touying-equation`, raw code, a figure, sections and subsections. Engine paths: the theme's show rules and page setup, heading-driven slide splitting, subslide repetition, counters and states read in headers and footers.
- `theme-stargazer.typ`: the stargazer theme with title, outline and focus slides. The same deck for every theme: `#pause` and `#meanwhile` in text and lists, `uncover`/`only`/`alternatives`, a two-column slide with a table, equations with pauses and `touying-equation`, raw code, a figure, sections and subsections. Engine paths: the theme's show rules and page setup, heading-driven slide splitting, subslide repetition, counters and states read in headers and footers.
- `theme-university.typ`: the university theme with title and focus slides. The same deck for every theme: `#pause` and `#meanwhile` in text and lists, `uncover`/`only`/`alternatives`, a two-column slide with a table, equations with pauses and `touying-equation`, raw code, a figure, sections and subsections. Engine paths: the theme's show rules and page setup, heading-driven slide splitting, subslide repetition, counters and states read in headers and footers.
- `theorems-numbly.typ`: theorems, lemmas, corollaries, definitions, examples and proofs (rainbow cosmos) inside the metropolis theme at 4:3 with `slide-level: 3`, numbly heading numbers, the theorem counter frozen across subslides, references to theorems, equations and figures on other slides (`@thm[-]`, `@thm[!!]`), `theorion-restate`, an outline of theorems, `touying-recall` of a labelled slide and of a labelled table, the theme's outline and focus slides, and an appendix with new numbering. Engine paths: rich counters inherited from headings, state/counter freezing by `update(at(..))`, figure kinds and outline targets, labels placed on last subslides only, queries for restating, numbering functions built from pattern strings.

### unequivocal-ams (0.1.2)

- `a4-note.typ`: the other option values: A4 paper (absolute margins), two authors (joined by "and", alternating in the header), no abstract, theorems whose counter is reset by each level-1 heading, proofs ending in display math and in a list, lists with the template's indents, links (mono font fallback), cite forms, and equation numbering per section set by the document. Engine paths: counter(heading).display() inside a figure numbering, numbering functions, `cite(form: ..)`, header on even/odd pages, weak spacing.
- `lattice-paths.typ`: an AMS-style article with three authors (department, organization, location, email, url), abstract, `theorem` (numbered and unnumbered) and `proof`, a lemma built on the same figure kind, numbered equations with labels, references to theorems, sections and equations, a table and a drawn figure, footnotes and a bibliography. Engine paths: running header/footer from the page counter in context, figure kinds with a numbering closure reading counter(heading), counter reset in a heading show rule, springer-mathphys CSL style, justified paragraphs over five pages.
- data: `refs.bib`

### unify (0.8.1)

- `languages.typ`: language-dependent unit tables: Russian (`set text(lang: "ru")`), English inside a Russian document, fallback to English for a language without tables, decimal commas, `add-unit` registered per language. Engine: `text.lang` read in context, state keyed by language, Cyrillic text in math (font fallback for upright letters), `eval` of generated math.
- `pump-datasheet.typ`: `num`, `unit`, `qty`, `numrange`, `qtyrange` in running text, tables and display math: prefixes (words and shorthand), per modes (symbol, fraction, fraction-short), symmetric and asymmetric uncertainties, exponents, separators, multipliers, raw units, angle/money/binary units, `add-unit`, `add-prefix`. Engine: regex captures, csv data of the package, state read in context, `eval` of math markup strings built at run time.

### uniwarn (0.1.1)

- `namespaces.typ`: custom warnings by namespace: default namespace, a registered namespace with a bound prefix, disabling and re-enabling, a second registration reported as a warning (panic: false), messages with non-ASCII text, warnings raised from inside a function used in a table. Stresses `unknown font family` warnings whose family name carries control characters (backspaces) and long text, state per namespace, deduplication of equal warnings.

### wrap-it (0.1.1)

- `error-size-without-context.typ`: an explicit `size` skips the package's layout() call, so measure() runs without context and fails inside the package. Stresses the error trace through package functions and closures.
- `field-guide.typ`: wrap-content left/right/top/bottom around drawn figures, wrap-top-bottom, grid arguments (gutter, fixed columns), styled and emphasised text being split, several wraps across page breaks. Stresses repeated measure() inside layout(), content introspection (fields(), func(), rebuilding styled elements), grids of two rows.

### zero (0.7.1)

- `aligned-tables.typ`: number alignment in tables: `ztable` with `format:` (none/auto/dictionaries of `num` options), `format-table` as a show rule on `table`, alignment at the decimal point, the uncertainty and the power, `nonum`, protected header cells, `align-column`, and a generated table of 90 rows that breaks across pages with a repeated header. Engine: two-pass layout through labelled metadata queries (`before`/`after`), measure of cell parts, show rules on table.cell that rebuild cells, table headers across pages.
- `error-unit-alt.typ`: a unit built from math content without a manual `alt`: the package cannot generate the alt description and fails an assertion deep in its accessibility module. Engine: error trace through several package functions, `repr` of math content in a message.
- `number-formatting.typ`: `num` (input forms, exponent modes sci/eng/fixed, digits, signs, base, product, tight, `math: false`), uncertainties in three modes and asymmetric, rounding (places, figures, pad, direction, ties, following the uncertainty), digit grouping, global options through `set-num`/`set-round`/`set-group`/`set-unit`, units and quantities (`zi`, `zi.declare`, `quan`, fractions, engineering prefixes). Engine: state-driven formatting in context, math attachments and spacing built from code, decimal string arithmetic, queryable metadata next to every number.
