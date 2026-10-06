# What fourteen ports showed, and what the EDSL changes (proposal, revision 5)

Status: accepted for implementation after three review rounds by Codex
(xhigh): `docs/edsl-reviews/ports-proposal-1.md` (eight required changes),
`ports-proposal-2.md` (six) and `ports-proposal-3.md` (one); section 11 says
how each is resolved. Details of later steps are settled in their pull
requests. Revision 5 corrects section 2 by the reproductions of step 0
(`doc/ports_findings_test.mbt`): section 13. This document extends
`docs/edsl-design.md` (revision 8); where the two disagree, that document
holds until this one is accepted and folded into it.

## 1. The experiment

Fourteen HTML pages (reports, tutorials, dashboards, one in Chinese; 18 to
85 KB each) were ported to PDF as single-file MoonBit scripts against the
published package (`moonbitlang/typst@0.1.4/doc`). The coordinator ported
one (`bench`); four agents ported the other thirteen. The agents were given
`bench.mbtx` as a reference, were told to copy its helpers, and were given
the findings known at that point (the brief is `_build/edsl-demo/ports/
BRIEF.md`). So the ports are not independent experiments: a finding counts
as confirmed by an author only if that author hit it in their own documents
after reading the brief; findings that were only in the brief are marked
"brief". The scripts, PDFs and page images are in `_build/edsl-demo/ports/`
(not committed: the pages are private).

| | |
|---|---|
| Ports that build and read as the same document | 14 of 14 |
| Ports that needed embedded Typst source (`Markup`) | 0 |
| Engine errors (`DocError`) across about 45 builds | 2, both at run time |
| Build and run per iteration | 15 to 18 s (12 s link, 5 s run) |

Per port, as each author counted (helper = code a library could have
provided; generated data and the extracted text of the pages are content):

| Port | Pages | Lines | Helper lines |
|---|---|---|---|
| bench | 3 | 910 | about 330 |
| mooncakes-health | 18 | 1382 | 368 |
| orgs-health (same code, other data) | 17 | 1353 | 368 |
| typst-evaluation | 5 | 1047 | 342 |
| record-visitors | 3 | 725 | 210 |
| schemas-age-well | 8 | 1179 | 295 |
| session-migrations | 9 | 1897 | 552 |
| openseek-text-output | 4 | 1238 | 512 |
| shell-prompt-ab | 4 | 848 | 330 |
| shell-vs-myshell | 3 | 1030 | 477 |
| minisql-field-report | 7 | 1508 | 574 |
| moonc-startup | 1 | 563 | 234 |
| mooncakes-consolidation | 4 | 888 | 371 |
| tun-poc-zh | 4 | 1137 | 616 |
| Total | 90 | 15,705 | about 5,580 (36% pooled; 27% to 54% per port) |

The helper boundary was drawn by each author, not by one rule; section 9
fixes a rule before anything is measured again.

The engine is expressive enough: nothing was impossible. The cost is
(a) output that is wrong without a diagnostic, and (b) the same helpers
written again in each script.

## 2. Findings, by cause

`n` is the number of authors (of five) who hit the finding in their own
documents.

### 2.1 Wrong output without a diagnostic

| # | What happens | n |
|---|---|---|
| S1 | Two adjacent inline items in a sequence (a `Prose`, a string, a `Text`) are typeset as one paragraph with nothing between them: "…incremental.Two execution modes…" | 3 |
| S2a | A `Block` with a fixed height that meets a page break is split, and when its content nearly fills the height the content runs out below the fragment on the next page | 2 |
| S2b | A `Block` or `Box` with a fixed height does not grow: content runs out below it (a `Box` is laid out in an unbreakable region, a `Block` may fragment) | 2 + brief |
| S3 | `Block(height=Pct(100))` in a grid cell takes the height of the region: every card is as high as the page, and an extra page appears (nothing is out of bounds) | 2 |
| S4 | A character no font covers is drawn as an empty box; `warnings` is empty | 1 |
| S5 | A long word of inline code in a table cell (an identifier, a path) does not break and runs over the cell border; raw text does break at spaces and at U+200B | 2 |
| S6 | `Prose` turns `'` after a digit into a prime ("#1770′s") | 1 |

### 2.2 Things the scripts wrote again

| # | Helper | n | lines each time |
|---|---|---|---|
| H1 | Paragraph wrapper around `Prose` (because of S1) | 3 | 3 + one call per paragraph |
| H2 | Inline markup. Two different answers: a helper `c("x")` interpolated at 100 to 150 sites (2 authors), or a parser for marks in strings (2 authors; their grammars differ: `` `code` `` and `**strong**` in both, `__x__` is emphasis in one and dimmed text in the other, one adds `{{chip}}`) | 4 | 5, or 55 to 103 |
| H3 | Equal-height cards in a row. Two answers: fill and stroke on the grid's cells (1 author; square corners, no measuring), or `Context` + `measure` with each card built twice and the row width typed in by hand (3 authors; rounded corners) | 4 | 10, or 13 to 50 |
| H4 | Chip/pill: an inline box that does not wrap and sits on the text baseline | 4 | 10 to 20 |
| H5 | Framed data table: column sizing, header style, row rules, numeric columns, a marked row, rounded frame | 4 | 49 to 60 |
| H6 | Canvas: absolute placement, text anchored at a point (baseline estimated as `0.72 × size`), arrowheads, a scale; plus tick generation for charts | 4 | 68 to 320 |
| H7 | Number and date formats (`toFixed`, grouping, k/M, a date stamp, `localeCompare`) | 4 | 30 to 147 |
| H8 | Code block with coloured or dimmed spans (not a `raw`: `Raw` takes a string) | 3 | 30 to 55 |
| H9 | A wrapping row of boxes with vertical centring (pipelines) | 1 | 40 |

### 2.3 Typed API gaps

| # | Gap | Workaround used |
|---|---|---|
| T1 | `Box(baseline=)` (unmapped type) | `Grid(align=Horizon)`, `outset` |
| T2 | `top_edge`/`bottom_edge` on text and highlight (unmapped) | `extra=[("top-edge", ..)]`, added gaps |
| T3 | `Stroke(dash=)` is a `Value` | `Value::str("dotted")`, `Value::array(..)` |
| T4 | No typed colour operations on `Paint` (`Value::call("color.mix", ..)` works; nobody found it) | 8-digit hex strings (an absolute alpha), a hand-written sRGB mixer |
| T5 | No `Layout` (the size of the enclosing region) | page width typed in as a constant |
| T6 | `Length`, `Sizing`, `Spacing` do not convert (`Rel(len)` exists; nobody found it) | helpers return `Double`, `Pt(px(14))` at 70 to 92 sites |
| T7 | No `Upper`/`Lower` for content (`Call("upper", ..)` exists; nobody found it) | `s.to_upper()` on strings |
| T8 | `Sides::none()` given as an inset fails at run time (located) | `Sides(all=Pt(0))` |
| T9 | `Outline(title=NoneValue())` works; one author wrote `Value::none()` instead | documentation |
| T10 | Withdrawn. `Stroke(paint=None)` in a table is a located error in every variant tried (about 35, and against 0.1.3 and 0.1.4). The location is the nearest argument that has a site; when the stroke is a helper's parameter that is the helper's line, which is probably what was read as "no location" | `Stroke::none()` |
| T11 | `Ctx::measure` returns a size and drops the baseline the engine computes. For one line of default text the measured height is the baseline offset (0.66 × size, not the 0.72 the ports assumed); the baseline is needed for content with insets | `0.72 × size` |

### 2.4 Behaviour that is Typst's, and stays

- Auto columns take their measured content width, and what remains goes to
  fractional columns or is taken from the auto columns; this is not HTML's
  algorithm, and tables with several prose columns need weights.
- `sticky` attaches a block to the block that follows it, and consecutive
  sticky blocks form a group: a heading, a paragraph of controls and a table
  stay together only if the paragraph is sticky too (or shares the heading's
  block), which the port that hit this did not know.
- `raw` sets its text size to 0.8em: an em size or an absolute size set
  around a `raw` is scaled by it (`Text(Raw(..), size=Pt(9))` is 7.2pt); only
  a show-set on `raw` with an absolute size gives that size.
- A stroke dictionary that names one side leaves the others unspecified, and
  they fold from the outer value: for a table that is its default stroke.
- Smart quotes follow Typst's rules (S6).

The port is faithful to upstream, so the engine does not change. The EDSL
answers with a kit element that makes the right choice explicitly
(section 4), a lint (section 5) or the guide (section 7).

### 2.5 Outside the EDSL

- Fonts: no sans-serif face is embedded, which is the largest visual
  difference of every port; `system_fonts=true` raised one run from 5 s to
  39 s. Section 6.
- MoonBit: findings for the language, section 8.

## 3. Changes to `doc` (the typed facade)

`doc` stays what revision 8 defines: typed constructors lowered through the
evaluator's own paths, invalid descriptions reported as located diagnostics
when they are lowered (constructors do not raise), and a functional Typst
twin for each constructor. Nothing below changes those rules.

### 3.1 `Para`

`Prose` stays inline (it is interpolated into prose and passed as a body).

```moonbit
(
  $|Each dot is one complete trial of all nine milestones.
)
|> @doc.Para
@doc.Para("One line.", justify=true)
```

`Para(text, ..)` is the text of a `Prose` between two paragraph breaks,
with `par`'s options as a set rule for that text. Twin:
`[#set par(..);#parbreak() .. #parbreak()]` around the functional expansion
of the prose (section 4.4 of revision 8). Provenance: one site, `Para`,
whose first argument is the prose text; no other site is registered (the
registry deduplicates by location and key path, so two differently shaped
constructors must not share a location).

(As accepted, this section had `Para` as `Par(Prose(text), ..)`, the `par`
element around the prose, and step 1 first built that. The evidence below
replaced it.)

As built (step 1): `Para(text, quotes~, leading~, spacing~, justify~,
linebreaks~, hanging_indent~, extra~)` in `doc/para.mbt`.

Why it is not the `par` element. Two ports of mathematics papers (22 pages
with about 290 formulas; 39 pages with 214 displays) wrote paragraphs as
the guide then taught, `Par(Prose(..))`, with displayed formulas
interpolated. The engine drops a block in the body of `par` ("block may not
occur inside of a paragraph and was ignored"). What the engine does, each
point pinned by an "engine: .." test of `doc/para_test.mbt` on Typst
source:

- (a) `par[..]` cannot hold a block: it is dropped with that warning. Text
  between paragraph breaks keeps it.
- (b) A block ends the paragraph (realization: a block interrupts the
  paragraph grouping), and the text after it is a paragraph of its own, in
  the flow's situation "after something else" (`ParSituation::Other`; a
  paragraph after a paragraph is `Consecutive`). The first-line indent is
  for `Consecutive` paragraphs, or for all with `all: true`. So without
  `all` the text after a display is not indented, and neither is a new
  paragraph after a display; with `all` both are. Neither setting gives
  what a paper wants.
- (c) For text without blocks, `par(options)[text]` and
  `[#set par(options);#parbreak() text #parbreak()]` are drawn the same
  (text runs and shapes at the same positions, no diagnostics) in 17
  containers (the flow, list and enum items, table and grid cells, blocks,
  a box, a figure, a footnote, columns, a stack, `align`, a quote, `pad`,
  `place`) under 5 settings of indents and options, 85 comparisons; both
  are `par` elements for a query. They are not the same thing, and differ
  in these places (each pinned):
  1. options that are *set* reach the paragraphs inside the text (the entry
     of a footnote, a box with paragraphs); the arguments of `par(..)` do
     not;
  2. a tight list attaches to a paragraph before it, but not across a
     paragraph break: after the delimited text it is set off like after a
     blank line in markup (5.5pt more at 10pt text); inside the delimited
     text it attaches;
  3. a `show par: set par(..)` of the document wins over a set rule around
     the text and loses to an argument of `par(..)`;
  4. without text there is no paragraph, where `par[]` is an empty one that
     takes its spacing (and is one more result of `query(par)`);
  5. inside a paragraph neither is one: the breaks are ignored with a
     warning each and the text stays; a nested `par` is dropped.
- (d) Paragraph breaks collapse, and one at the start or end of a container
  is nothing (it only makes the text there a paragraph).

What `Para` lowers to, from these facts: a sequence with the site of the
call: `set par(..)` if an option is given, a paragraph break, the pieces of
the prose, a paragraph break. The text after an interpolated block, up to
the next block or blank line, is a nested sequence (the private node
`NPieces`, whose children stay pieces of the text argument) that starts
with `set par(first-line-indent: 0pt)`: the continuation is not indented
under either setting, and nothing else is touched. So:

- a displayed formula in a `Para` is kept, without a warning and with its
  own origin; the text before and after it reads as one paragraph (an
  interpolated `Parbreak()` is a paragraph break like a blank line, not a
  block with a continuation);
- the next `Para` is a new paragraph, and it is indented if indents are on
  for all paragraphs (`all: true`), or if the `Para` before it ends with
  text;
- a blank line in the text is a paragraph break (two paragraphs, no
  warning), where `Par(Prose(..))` has the engine's "parbreak may not occur
  inside of a paragraph" and joined text;
- origins, review text, tiers, source characters and `positions` are those
  of the text of a `Prose` (`doc/para_test.mbt`, `doc/examples/review`),
  and for text without blocks the frames are those of `Par(Prose(..))`.

What the engine does not give, and the author still does by hand:

- Without `all`, a `Para` after a `Para` that *ends* with a display is not
  indented: it follows a block, like a paragraph after a figure or a list.
  The author sets `all: true` for the document (then the first paragraph
  and the one after a heading are indented, too), or gives that paragraph
  its indent: `extra=[("first-line-indent", Value::dict([("all",
  Value::bool(true))]))]`, which keeps the document's amount (the engine
  folds the dictionary). `Para` cannot do it by itself: a description does
  not know what comes before it, `all` on every `Para` would indent the
  first paragraph and the one after a heading as well, and an empty
  paragraph in between (the trick Typst users have) adds space.
- A list (or another block) written as an item after a `Para` is set off
  from it like after a blank line (difference 2 above). What belongs to
  the paragraph is interpolated into its text, where it attaches as in
  Typst source.
- A `show par: set par(first-line-indent: ..)` of the document wins over
  the continuation rule and over the options of a `Para` (difference 3).
- The continuation rule is for blocks that the description shows (the
  constructors lint L1 takes for blocks, `Equation(block=true)`); after a
  block that a callback, a `Call`, `Markup` or a view makes, the text is
  indented as the engine indents it.
- The rule and the options are set rules, so they reach paragraphs nested
  in that text: a footnote in the text after a display has an entry without
  first-line indent when `all` is on (the rule sets the amount to `0pt`;
  `all` is inherited).
- `label` is gone: there is no `par` element to carry it. `extra` gives
  further arguments to the `set par`.
- `Para` is handwritten: an option that `Par` gains in the generator
  (`scripts/docgen.py`) has to be added to it by hand; until then `extra`
  reaches it.

### 3.2 `Layout`

```moonbit
@doc.Layout() <| (size, cx) => { .. size.width .. cx.measure(..) .. }
```

`layout(size => ..)` with a host callback `(Region, Ctx) -> &IntoContent
raise`, on the path `Context` uses; the engine already passes location and
styles to it. `Region` has `width` and `height` only (the engine's
dictionary; it is not the `Size` that `measure` returns). It is the base
size of the enclosing region
(`regions.base()`): the width and height of the container, not the space
that remains on the page, and a dimension can be infinite (an auto-sized
container). Like every callback it falls under the creation rule
(revision 8, section 11): it cannot be created inside another callback.

As built (step 2): the type is `LayoutSize`, not `Region`. `doc` already
has a public `Region` (the box on a page that `ReviewText::positions`
returns, published in 0.1.4). Measured: the size is the block's own where it
has one and the surrounding region's otherwise (a box or block without a
width reports the width around it, not an infinite one); a dimension is
infinite on a page with `height: auto` or `width: auto`, and both are while
the content is measured without a size (`doc/ports_test.mbt`).

### 3.3 `Size` with a baseline

`Ctx::measure` returns the engine's baseline as well (`Size.baseline`), so
text can be anchored on its baseline without a font-size estimate (T11).

As built (step 2), measured at 10pt in the embedded serif
(`doc/ports_test.mbt`): the baseline is that of the first line, from the top
of the measured frame. With Typst's default text edges (cap height to
baseline) it equals the height of one line (6.58pt); with
`bottom_edge=Descender` the height is 9.04pt and the baseline stays 6.58pt.
A block or box reports the baseline of its first line including its inset
(a box with a `baseline` of its own the one it was given: 4.58pt for
`baseline=Pt(2)`), content without a baseline of its own (a shape) its
height, empty content 0.

### 3.4 Typed parameters and values

Through `scripts/docgen.py` (type table) and the facades. Each keeps the
engine's explicit states, and the untyped escape (`extra=`, `Value`) stays.

- `Box(baseline=Length)`: the shift form only (`box(baseline: len)`, how far
  the box is moved down from the text baseline). The `(at:, shift:)` and
  alignment forms stay reachable through `extra` (T1).
- `top_edge : TopEdge` (`Ascender`, `CapHeight`, `XHeight`, `Baseline`,
  `Bounds`, `Len(Length)`) and `bottom_edge : BottomEdge` (`Baseline`,
  `Descender`, `Bounds`, `Len(Length)`) on `Text`, `SetText`, `Highlight`:
  two types, because the engine accepts different names for each (T2).
- `Stroke(dash=Dash)`: `Auto`, `None`, the presets by upstream's names
  (`Solid` lowers to `"solid"`, which is not `none`), `Pattern(Array[DashLen],
  phase~)` with `DashLen` = `Dot` | `Len(Length)`, and `Raw(Value)` for what
  a script passes today (T3).
- Colour operations on `Paint`, lowered to the engine's native functions
  with the receiver as first argument. Amounts are percentages (`Double`)
  lowered to the engine's `Ratio`; clamping and negative amounts are the
  engine's. `transparentize(p)`: alpha × (1 − p/100), upstream's meaning,
  not "set the alpha". `lighten(p)`, `darken(p)`. `mix(other, weight~ = 50,
  space~ = Auto)` lowers to `color.mix((self, (100 − w)%), (other, w%),
  space: ..)`; `space : ColorSpace` is an enum (`Auto`, `Oklab`, `Oklch`,
  `Rgb`, `LinearRgb`, `Luma`, `Cmyk`, `Hsl`, `Hsv`) lowered to the engine's
  space values (`oklab`, `rgb`, `color.linear-rgb`, ..), and `Auto` is
  upstream's default (Oklab, or the common spot colorant). No equivalence
  with CSS `color-mix` is claimed: Typst mixes channels without
  premultiplying alpha. The operations are defined for colours; a gradient
  or tiling is the engine's located cast error (T4).
- `Length::sizing()`, `Length::spacing()` (= `Rel(self)`) (T6).
- `Upper(body)`, `Lower(body)`. Twin: `upper[#body]`; on content this sets a
  text case property, which is not the same structure as `upper("x")` on a
  string (T7).
- `Sides::zero()` (uniform `0pt`) for insets and margins. `Sides::none()`
  as an inset stays a located lowering error (T8).
- T10 is withdrawn (section 2.3); the guide explains where the location of
  a value's error points and how `#callsite` moves it to a helper's caller.

As built (step 2), where the list above could not be taken literally:

- The untyped case of `Dash` is `RawValue(Value)`, not `Raw(Value)`: with a
  case `Raw`, `@doc.Raw("code")` (the raw element's constructor, written
  with its package) is an ambiguous constructor (error 4124).
  `Stroke(dash=..)` changes type, which breaks `dash=Value::..`: there is no
  implicit path from `Value` (a trait-object parameter would stop the cases
  from resolving, revision 8, fact 5); such a call becomes
  `dash=RawValue(..)` or a typed case.
- MoonBit has no optional fields in enum cases, so `Pattern(lengths,
  phase=..)` always names its phase, and lowers to the dictionary form.
- The cases of `ColorSpace` for `rgb` and `luma` are `Srgb` and
  `Grayscale`, not `Rgb` and `Luma`: a second enum of the package with
  those cases makes `@doc.Rgb("#..")` and `@doc.Luma(..)` ambiguous where
  no type is expected (`let c = @doc.Rgb(..)`), and they must stay the
  colours of `Paint` as in 0.1.4 (pinned by a test). `Gray` is a case of
  `Paint` too. The lowered values are Typst's `rgb` and `luma`.
- `Upper`/`Lower` are generated function facades whose argument is content;
  they are left out of the translator's table (`api=False` in
  `scripts/docgen.py`), since `upper("x")` of a string literal is a string,
  not text with a case property.
- New parameters stand where the engine's fields do, so the parameter
  indices of origins (`Origin.param`, `ArgsLoc`) move for what follows them:
  by two from `lang` on in `Text`/`SetText` and from `extent` on in
  `Highlight`/`SetHighlight`, by one from `fill` on in `Box`/`SetBox`
  (`extra` and `label` included).
- `transparentize` with a negative percentage is Typst's `opacify`
  (`a + (1 − a) × |p|/100`), not the formula above with a negative `p`.

## 4. A kit (new package `doc/kit`)

Composites that are not one Typst element. Each is defined by an expansion
into `doc` primitives, and each has a functional Typst twin: a Typst
function written with the same primitives (`doc/twins/kit.typ`), checked by
the `edsl` stage like every other pair: structure, frames with memoization
on and off, SVG and PDF bytes. Nothing in `doc` depends on the kit.

Provenance of a composite. The kit is a separate package, so it cannot use
`doc`'s private `Site`. `doc` gets one public hook:

```moonbit
#callsite(autofill(loc, args_loc))
pub fn Chip(body, fill~, .., loc~ : SourceLoc, args_loc~ : ArgsLoc) -> @doc.Composite {
  @doc.Composite("Chip", loc, args_loc, site => {
    @doc.Box(site.arg(0, body), fill=site.arg(1, fill), ..)
  })
}
```

`Composite(name, loc, args_loc, build)` registers one site, the caller's
call of the kit element with its argument ranges, and runs `build` (eagerly,
at construction, so callbacks created in it exist before compilation).
Constructors that run inside `build` (the kit's own `Box`, `Grid`, `Place`)
do not register sites, and their own parameter indices are not used for
locations (a primitive's argument index means nothing in the caller's
argument list): what they produce is attributed to the composite's call as
a whole. `site.arg(i, v)` ties a forwarded value or a body without a
location of its own (a plain string) to the caller's argument `i`, so it
resolves to that argument's range. Descriptions the caller passed in were
constructed before `build` ran and keep their own origins. A measuring
element calls the hook again, with the same site, inside its callback, for
the ordinary descriptions it rebuilds there; creating a new callback
description there stays the existing error. So a selection inside a chip's
text resolves to the caller's string or `Prose`, and a selection of the
chip's box to the caller's `Chip(..)` call.

Rule for callbacks: a kit element that measures creates a `Layout` or
`Context` callback, so under the creation rule it cannot be built inside a
callback (a show rule, a `Cells` function, another measuring element).
The kit therefore avoids measuring wherever the engine can do the work, and
says for each element whether it measures.

| Element | Replaces | Expansion | Measures |
|---|---|---|---|
| `Chip(body, fill~, text~, stroke~, radius~, inset~)` | H4 | `Box` with horizontal insets and the vertical padding as an outset, which keeps the text on the line's baseline (a `baseline` shift would move it off; it is only for a box of fixed height); a string body gets no-break spaces. A content body can wrap in a narrow column (documented) | no |
| `Cards(items, columns~, gutter~, fill~, stroke~, inset~)` | H3, S3 | a `Grid` whose cells carry fill, stroke and inset: the engine makes the cells of a row equally high. Square corners | no |
| `Cards(.., radius~)` | H3 | with a radius the cells cannot draw the card: rows are measured at the column width from `Layout`, each card is a rounded unbreakable `Block` of the row's height. Measured and final content are the same descriptions with the same keys | yes |
| `Flow(items, gap~, row_gap~, align~)` | H9 | `Layout` + `measure`, greedy rows, each row a `Grid` aligned on the cross axis; an item wider than the region gets a row of its own; an infinite width gives one row | yes |
| `DataTable(head, rows, columns~, numeric~, mark~, frame~, header~, rule~, column_text~, key~)` | H5 | `Table` with `TableHeader` (repeats on each page), cells unbreakable, the three `Cells` functions built once outside any callback, `rest=Stroke::none()` set explicitly, a clipped rounded `Block` as frame; `columns` is required (2.4); cells may be `TableCell` with spans; rows keyed by `key` or by index | no |
| `Canvas(width, height, items, unit~)` with `text(x, y, body, anchor~)`, `line`, `rect`, `circle`, `curve`, `arrow(.., head~)` | H6 | an unbreakable `Block` of that size (one region, so one coordinate system) with `Place`d items. Horizontal anchors use `Place`'s own alignment in the known width (`Center` with `dx = x − width/2`), vertical anchors `Top`, `Horizon`, `Bottom` likewise; arrowheads are polygons | no |
| `Canvas(.., width=Auto)`, `anchor=Baseline` | H6 | the width from `Layout`; the baseline from `measure` (3.3) | yes |
| `Lines(lines)` | H8 | monospaced lines: each line a sequence of strings and styled spans, joined by `Linebreak`; empty lines and a trailing empty line are kept; leading spaces are no-break spaces; tabs expand to the next multiple of `tab_size` columns counted across the line's spans; a line longer than the measure wraps as text does, without hyphenation. It is not a `raw` element (no highlighting, `Select::raw` does not match) and its name says so | no |

Chart helpers (`ticks(lo, hi, n)`, a linear scale) come with `Canvas`.

Separate from layout, package `doc/format` (plain MoonBit, no engine):
`fixed(x, digits)`, `grouped`, `percent`, `compact` (k/M) with stated
contracts (negative values, half away from zero, NaN and infinities as
`"NaN"`/`"∞"`), and `soft_breaks(s, after~)`, which inserts U+200B after the
given punctuation (S5; it changes the text that is copied from the PDF, which
the documentation says). Dates and collation are not included: both need a
locale and a time zone policy, and one port's 40-line `localeCompare` is
not evidence enough for a design.

### As built (step 3): `Composite`, the package, `Cards`

**The hook** (`doc/composite.mbt`; tests `doc/composite_test.mbt`, whose
elements are defined with the public API only, as a package outside `doc`
defines them):

```moonbit
pub fn Composite::Composite(name : String, loc : SourceLoc, args_loc : ArgsLoc,
  build : (CompositeSite) -> &IntoContent) -> Composite
#callsite(autofill(loc))
pub fn[T] CompositeSite::arg(self, param : Int, value : T, loc~ : SourceLoc) -> T
pub fn CompositeSite::invalid(self, message : String, arg? : Int) -> Content
```

What the section left open, and how it is decided:

- `site.arg(i, v)` returns `v` itself, of its own type, so the sketch
  type-checks as written (`fill=site.arg(1, fill)` for a `Paint`
  parameter). A value cannot carry the mark: the facades are public enums
  and structs without a place for a location, and a `Bool`, an `Int64` or a
  `String` has none at all. The mark is tied to the constructor's argument
  by what the compiler already records for provenance: `site.arg` has the
  location of its own call (`#callsite(autofill(loc))`), every constructor
  has the locations of its argument expressions (`args_loc`), and an
  argument expression that contains the call of `site.arg(i, ..)` is the
  caller's argument `i`. Constructors find their sites in one place
  (`Site::new`); while a `build` runs it returns the composite's call with
  a table from the constructor's parameters to the composite's, and
  lowering reads every parameter index through that table (`Site::param`).
  No constructor and no generator changed.
- The rule is lexical: a mark belongs to the innermost constructor call
  around it (arguments are evaluated before the constructor runs, so that
  one takes it first). Where it does not hold, the argument is the call of
  the composite as a whole, never another argument: a value bound to a name
  before it is passed; an argument that contains marks of different
  parameters (`Seq([site.arg(0, a), site.arg(1, b)])`: a `Seq` per
  argument marks each). A wrong index is not detected: an element tests
  every argument that it passes on (convention 7 below).
- The result of `build` is not an argument of a constructor, so a string
  of the caller that is the whole result is the call; in a constructor it
  is an argument (`Seq([site.arg(0, body)])`). (A first version gave the
  result the marks that no constructor had taken; a mark of a value that
  was only bound to a name then attributed an unrelated result to that
  argument, which the review found.) The composite is a node of the
  description (`NComposite`) that lowers to its body and is transparent
  for what reads descriptions (inserted expressions, a rule in a
  sequence, a value in a content argument, the lint of adjacent text,
  `Para`'s blocks); `Debug` prints its name around its expansion.
- What origins report is the composite's name (`Origin.kind`), the call,
  and the argument where one is marked; under the keys of the enclosing
  `Keyed`, as for any constructor.
- A composite built inside the `build` of another one is a constructor
  like the others there: its site is the outer call, its parameters are the
  outer parameters that its arguments were marked as, and what it generates
  is the outer call. One rule, no case of its own.
- Callbacks: the section had the element call the hook again inside its
  callback. It is automatic instead: a callback runs where it was created
  (`Callback::new` captures the running `build`, or that there is none).
  One that a `build` creates is a part of it, so when the engine calls it
  the constructors that it runs are the composite's, `cx.measure(..)`
  included, and `site.arg` marks their arguments. One of the caller runs
  as the caller's, also when the engine calls it while a callback of an
  element is running (the element measures content that has a `Context`
  in it; the review found that it ran as the element's). Revision 8
  already gives an invocation its occurrence and keys without the
  callback's author doing anything (section 11.2); the site of a
  composite is one more thing of that kind, and an element cannot forget
  it. A callback description that is created while a callback runs is
  still the error of the creation rule, at the call of the element; an
  element without a callback can be built anywhere.
- The `into_content` of a type of the caller runs when the value is passed
  to a constructor, which is inside `build`. It is the caller's code, so
  `doc` converts content outside of the running `build` (`described`): what
  it builds keeps its own call sites. A function of the caller that `build`
  calls is not covered: an element that takes one calls it before the
  hook.
- An argument that an element cannot accept is
  `site.invalid(message, arg=i)`, an error at that argument, or at the
  call without `arg` (constructors do not raise).

Each rule has its test in `doc/composite_test.mbt`: the index mismatch of
the third review (written first; on a hook that only substituted the
composite's call it failed with the gutter's error at the fill, `Tiles a3`
for `Tiles a2`), one site and the expansion, the caller's descriptions and
custom types, a click, a selection with tiers 1 to 3 and `positions`, keys
of the caller and of the element, one description used twice, a composite
in a composite, callbacks (provenance of their content, a callback of the
caller inside a measuring element, an error, the creation rule), where a
mark counts, an element that is a rule or a value, the lint.

**The package** `doc/kit` imports `doc` and core only; it is in the
published package (`.moonignore` leaves it in). Its conventions are in
`doc/kit/kit.mbt`:

1. An element is an expansion into constructors of `doc`, and has no
   behaviour of its own in the engine.
2. It is a type with a constructor of its name, and content like the
   elements of `doc`. Its parameters have the names, types and defaults of
   the primitives that they are passed to, in the type of the primitive
   that draws them; a default of its own only where that default is the
   reason for the element, and said so. No fixed height, no `extra`, no
   `label`.
3. Provenance through `Composite`: everything is built inside `build`,
   every forwarded argument is marked where it is passed, and a part per
   item of the caller's data is `Keyed` with the item's index.
4. It measures only where the engine cannot do the work, says "Measures"
   in its documentation, and says what happens in an unbounded region and
   at a page break. In the callback: the caller's content was converted in
   `build`; what is measured and what is placed are the same descriptions
   under the same keys, from one function; sizes are not computed by hand
   (a row is measured as a row of the grid that places it); a property of
   a primitive that only places is given explicitly, so that a rule of
   the document cannot make what is measured differ from what is placed.
5. Invalid arguments are `site.invalid`; what the engine rejects is the
   engine's error at the argument. The caller's arrays are copied.
6. Its twin is a Typst function with the same expansion, which passes on
   only the arguments it was given; documents that use both are pairs of
   the `edsl` stage.
7. Its tests: the expansion, the property it exists for (from the frames),
   provenance through the review loop including an error in every
   forwarded argument at that argument's index, and for a measuring
   element the creation rule, an unbounded region, a page break, and that
   nothing leaves the page.

**`Cards`** (`doc/kit/cards.mbt`, tests `doc/kit/cards_test.mbt`):
`Cards(items, columns~, gutter~, column_gutter~, row_gutter~, fill~,
stroke~, inset~, radius~)`. The tracks have `Grid`'s types, the look
`GridCell`'s and `Block`'s (`Paint`, `Sides[Stroke]`, `Sides[Length]`,
`Corners[Length]`): one look for all cards, not a `Cells` function, which
a block cannot take. `columns` defaults to one `1fr` column per item (one
row of equally wide cards; `Grid`'s default is one `auto` column, which
stacks them): that default is the element's own. Every card is `Keyed`
with its index.

- Without `radius`: a `Grid` of `GridCell(item, fill, stroke, inset)`. The
  look is on the cells, not on the grid: the grid fills and strokes the
  cells that it adds to complete a row, which would draw empty cards. So
  an item is the body of a card and a `GridCell` among the items is not a
  cell of the grid (the guide's hand-written helper allowed that). No
  callback.
- With `radius`: a `Layout` whose `Grid` holds `Block(item,
  width=Pct(100), height=<row>, breakable=false, fill, stroke, radius,
  inset)`. What the section's row did not say:
  - a block in a cell is as wide as its content, not as its cell: the card
    needs `width=Pct(100)`;
  - "the column width from `Layout`" cannot be computed in host code for
    the tracks and gutters that `Grid` accepts (`Em`, `Pct`, `Fr`): the
    row is measured as a grid of that one row, with the same tracks, at
    the region's width, and the engine resolves them, in the measurement
    and in the placement alike. The cards are the same boxes as without a
    radius (tested on the page, in a block with an inset, a grid cell, a
    pad and columns);
  - an `Auto` column is an error at `columns`: it is as wide as the
    widest card of all rows, which a row measured alone does not know,
    and a card that is measured wider than it is placed would run out of
    its height;
  - the grid of the blocks has `inset=0pt` explicitly: the look is the
    blocks', and a `set grid(inset: ..)` of the document, which may depend
    on the row, would otherwise differ between the measured first row and
    the placed one. A rule that depends on the row of a cell in another
    way (`show grid.cell.where(y: 1): ..`) is not covered, and the
    documentation says so;
  - an unbounded width: the rows are measured without a width, as the
    grid is laid out there (fractional tracks have no width in an
    unbounded region, with or without a radius);
  - a row that is higher than the region: an unbreakable block that no
    page holds leaves the page without a diagnostic (pinned as the
    engine's fact), so the cards of such a row are breakable blocks of
    their own height: nothing leaves the page, and that row is not
    equalized;
  - a page break between rows: a row that does not fit moves as a whole
    (without a radius the grid breaks the row like any row).
- S3 stays pinned as the engine's behaviour (`doc/ports_findings_test.mbt`),
  and `Cards` is tested against it: equal heights for unequal content in
  both forms, no added page, no split card.

**Twins** (`doc/twins/kit.mbt`, the pairs `kit-cards` and
`kit-cards-radius`; the `edsl` stage has 44 pairs): the Typst function is a
string of that file, like every twin, not a `kit.typ`. A function differs
from an element in two ways that the pairs are written around: its
definition is an expression of the markup (the EDSL document starts with
`Value::none()`), and an expression in its body has one span for all its
calls, while each call of the element is a call site: two calls that make
equal elements (two empty grids) are one element twice for Typst and two
elements for the EDSL, which the frame dump shows in the numbering of
their keys.

**The measurement** (section 9, taken early): `doc/examples/report`, a
one-page report with invented text (a row of four tiles and two groups of
cards, the second in two rows), written twice: with the measured cards
that the ports wrote by hand (`before_helpers.mbt`: the page's text width
as a constant, each card built twice) and with `Cards` (`after.mbt`). The
files are split by the rule of section 9, and
`python3 scripts/edsl_helper_lines.py` counts their lines of code:

| | helper lines | of them for the cards |
|---|---|---|
| before | 80 | 56 |
| after | 42 | 18 |

(24 lines are in both: colours, measures, and what is inside a tile and a
card.) The pages are identical: the SVG of every page and the PDF bytes are
equal (`report_wbtest.mbt`). Building and compiling one document
(`moon run doc/examples/report --target native --release -- time 500`,
the embedded fonts, aarch64 macOS) takes about 6.1 ms before and 6.5 ms
after (the means of 500 runs in three repetitions: 5.9, 6.2 and 6.1 ms;
6.3, 6.6 and 6.6 ms). The version with the kit is about 7% slower. What
differs in the work: it measures five rows as grids where the hand-written
version measures thirteen blocks, and every constructor of the element
finds its site through the hook; how the 0.4 ms divide between the two was
not measured.

### As built (step 4): `Chip`, `DataTable`, soft breaks in cells

Both elements follow the conventions of step 3. Where the table above
(written before any element existed) does not fit them, it is amended
here; the amendments to the conventions themselves are at the end.

**`Chip`** (`doc/kit/chip.mbt`, tests `doc/kit/chip_test.mbt`):
`Chip(text : String, fill~, stroke~, radius~, inset~, outset~)` and
`Chip::of(body, ..)` with the same parameters. It is `Box(label,
inset=Sides(x=Em(0.6)), outset=Sides(y=Em(0.3)), fill~, stroke~, radius~)`,
the label being the text with its spaces as U+00A0.

- The parameters are `Box`'s, with its names and types. The two defaults
  are the element's own and are its reason: the padding to the sides is
  the box's inset, the padding above and below its outset (finding T1). In
  em, so that they follow the size of the label; 0.6 and 0.3 are the
  middle of what the ports wrote (4.5 to 6pt and 2.4 to 3.2pt around text
  of 7pt in text of 9 to 10pt). No default for `fill`, `stroke` or
  `radius`: a look is the caller's.
- Not a parameter: `text~` of the table above. The style of the label is a
  `Text` around the chip (`Text(Chip("ok", fill=soft), size=Pt(7),
  fill=green)`): a parameter would repeat some of `Text`'s twenty-five, and
  with the `Text` around the box the em of the paddings is the label's
  size. Also not: a width, a height, `baseline` (convention 2; they are
  what moves the label off the line), `clip`.
- Two constructors, where the table has one `body`. A description is
  opaque, so an element cannot tell a string from other content, and "a
  string body gets no-break spaces" needs to know. `Chip(text)` takes the
  string; `Chip::of(body)` takes content, which can be broken, as the
  table says. Considered and not built: one constructor with a show rule
  on the text `" "` inside the box (it works for every body, but it makes
  three text runs of two words, with the space attributed to the call,
  and the pages are then not those of the hand-written pill); one
  constructor that asks `doc` whether its body is a string (then
  `Chip(Text("two words"))`, the form every port wrote, is broken without
  a diagnostic).
- Established from the frames: the baselines of a paragraph of three lines
  are the same with a chip in its second line and with a word in its
  place (16.6, 29.7, 42.7 and 55.8pt; with the padding as the box's inset
  the line of the chip and those after it are 3pt lower); the label is on
  the baseline of its neighbours; in a column of 70pt a label of four
  words is one run, where the same box without the element has three
  lines. Only spaces are changed: the same label with hyphens for its
  spaces is three lines in a chip too (pinned), so the contract is "not
  broken at a space", not "one line".
- Through the review loop: a selection in a label is the `text` argument,
  and with the source file the characters of its literal, also in a label
  with a space (`"to do"`: `do` is the literal's characters 4 and 5).
- What "does not wrap" is worth, which the table does not say: a box is
  laid out in the width of its line and wraps only when its content is
  wider than that, so the no-break spaces only ever act in a column that
  is narrower than the label. There the label then runs out of its cell,
  and the engine does not make the box wider than the line (the width of
  a paragraph is at most the region's): the fill ends before the text.
  That is pinned by a test and said in the documentation, with the remedy
  (an `Auto` column, which is as wide as its chips). It is the engine's
  S5 in another place, and a case for lint L3's successor (content outside
  its container), not for the element.
- No callback, no measuring: it can be built anywhere.

**`DataTable`** (`doc/kit/data_table.mbt`, tests
`doc/kit/data_table_test.mbt`): `DataTable(head, rows, columns~, inset~,
align~, fill~, stroke~, radius~, breakable~, key~)`. It is

```
Seq([
  SetTableCell(breakable=false),
  Table([TableHeader(head), ..cells], columns~, inset~, align~, fill~,
    stroke=Cells::all(Sides(bottom=stroke, rest=Stroke::none()))),
])
```

and with `radius`, that sequence in `Block(.., radius~,
stroke=Sides(all=stroke), clip=true)` with `TableHline(stroke=Stroke::
none())` as the table's last child. Against the table above
(`numeric~, mark~, frame~, header~, rule~, column_text~`):

| There | As built | Why |
|---|---|---|
| `rule~` | `stroke : Stroke` | The primitive's name. One stroke, not `Cells[Sides[Stroke]]`: the element names the other sides (2.4), which is its reason, and a `Sides` is opaque. It is also the outline of the frame: all six framed helpers of the ports used one hairline for both |
| `frame~` | `radius : Corners[Length]` | `Block`'s parameter; its presence is the choice of the frame, as for `Cards`. The frame has no fill of its own: the table's `fill` is clipped to it |
| `numeric~` | `align : Cells[Alignment]` | The table's own parameter does it without a callback: `Cells::columns([Left, Right])`, which no port found (five wrote a `Cells` function) |
| `mark~`, the fill of `header~` | `fill : Cells[Paint]` | The table's own. A tinted row was written by one author (two ports), a filled header by one: by the rule "not what one port needed" they are the caller's function, with the row offset documented (row 0 is the header) |
| the text of `header~`, `column_text~` | rules of the document | `ShowSet(Select::table_cell(y=0), SetText(..))` and `..(x=2)..`: the element has no parameter for text (it would repeat `SetText`), and the rules reach its cells because it is a table. Tested inside the element, also with both on one cell (the later wins) |
| "the three `Cells` functions built once" | no callback at all | An alignment per column and one stroke for all cells are values; the rule under the last row is taken away by a line (below). So the element can be built inside a callback, which the hand-written helpers could not |
| | `inset : Cells[Sides[Length]]` | The table's own; every port set it |
| | `breakable : Bool = false` | `TableCell`'s. The default is the element's ("cells unbreakable"), and it needs a way out: see the row higher than a page |

`rows` (the tracks) and the gutters of `Table` are not parameters:
`SetTable(..)` before the element sets them (tested with `row_gutter`),
like the stroke of the rules when `stroke` is not given.

- **Rows.** `head : Array[&IntoContent]`, `rows : Array[Array[&IntoContent]]`.
  Each row is placed as a table places cells: every cell in the next
  column that no cell from a row above takes, over its `colspan` columns,
  and taking them for `rowspan` rows. A row that does not fill the columns
  is `Keyed(key, site.invalid(message, arg=1))`: an error at `rows`, under
  the key of the row, with ``` `rows[1]` has cells for 2 columns: this
  `DataTable` has 3 columns ``` (N9; a `Table` of the same cells compiles
  and shifts, pinned beside it). Also errors: a span into a column that a
  cell from above takes, a span below the last row, a cell of the head
  that spans rows (the header is one row), an item that a table does not
  place in its row (a `TableCell` with `x` or `y`, a line, a header, a
  footer), no `columns`. An empty head is no header (an empty
  `TableHeader` is an empty row).
- **One accessor in `doc`**, `Content::table_cell_spans() -> (Int, Int)?`:
  the `(colspan, rowspan)` that a description takes as a child of a table
  (`(1, 1)` for what is not a cell of its own; `None` for a child that is
  not placed in order). The kit is outside `doc` and cannot read a
  description; the Typst twin reads the same with `cell.func()` and
  `cell.fields()`. It sees a cell under `Keyed`, with a label, as the
  only child of a `Seq` (which lowers to its child), in a composite, and
  as a view; the last argument of a name wins. Its test
  (`doc/composite_test.mbt`) puts each description first in a table and
  compares the answer with the column in which the engine places the next
  cell. (The first version answered `(1, 1)` for a sequence of one cell
  and kept a position that a later `auto` took back; the review found
  both, and the test against the engine is what would have.) Three things
  are not in a description and are one column for the count: a `Markup`
  (which is a cell with a span only if its source is nothing but one), a
  computed span, and a span that a rule of the document sets. A row with
  such a `Markup` is reported although it fits (pinned): the alternative,
  not checking rows that hold a `Markup`, gives up the check for every
  row with a piece of markup in it.
- **Looks stay the table's.** The element never wraps or changes a cell:
  what it sets is on the table (stroke) or a rule (breakable), so a
  `TableCell` of the caller with a span behaves like every other cell (it
  gets the fill of its row), and its own arguments win, as in any table.
- **A row is not split.** `SetTableCell(breakable=false)` around the
  table: a table has no parameter for it. The engine's fact, pinned: a row
  of unbreakable cells that no page holds is moved to the next page and
  runs out of it, without a diagnostic (S2 again). The element cannot
  know without measuring, so `breakable=true` is the way out, and the
  documentation says when. A row is as breakable as its least breakable
  cell, so one `TableCell(.., breakable=true)` of the caller does not
  split its row.
- **At a page break inside a frame.** The engine draws, at the end of
  every region that a table continues after, the line of the table's
  bottom border, with the lines under that region's last row behind it
  "so that they don't disappear" (`layout/grid_layouter.mbt`, upstream's
  `render_fills_strokes`); and it draws every part of a broken block as a
  whole box, with all four sides and corners. So a table whose rows have
  a rule under them but the last (what every framed helper of the ports
  wrote, with a `Cells` function of `y == last`) has, on a page that it
  continues after, the rule of that page's
  last row exactly on the bottom outline of the frame: two lines in one
  place, which is the "double rule" one port reported (visible when rule
  and outline differ, or when the paint is translucent). A line without a
  stroke takes away the lines at its place, and one at the table's bottom
  border does so at the end of every region. `DataTable` with a frame ends
  with that line: no rule under the table's last row and none under the
  last row of a page, without a callback. Without a frame there is a rule
  under every row, also the last of a page.
- **Keys.** Every cell of row `i` is `Keyed` with `key(i)`, by default
  the index: a string of a row resolves to `rows` under that key, rows
  from a loop are distinct occurrences, and a description of the caller
  in a row has the key too. A key that `Keyed` does not take (it starts
  with U+FDD2) is an error at `key`, not at the cells that would carry
  it.
- **Twins** (`doc/twins/kit.mbt`): the functions `chip` and `data-table`,
  the second with the element's check and messages. `doc/twins/
  kit_wbtest.mbt` gives the function and the element the same ten
  rejected inputs: the messages are the same after the `assertion failed:
  ` that Typst's `assert` puts before its message. The pairs `kit-chip`,
  `kit-data-table` and `kit-data-table-frame` (a framed table over two
  pages with chips in a column, a row-dependent fill, spans, split rows,
  rules of the document) are the documents that compile. The `edsl` stage
  has 47 pairs.
- **A block for what reads descriptions.** Without a frame the element is
  a sequence: a rule and a table. `doc`'s lint of adjacent text and
  `Para`'s rule for the text after a block took a sequence for inline
  content unless it was a `Para`, so the table was no evidence of a flow
  for L1 and the text after one in a `Para` was indented. A block around
  the sequence would have hidden that at the price of a second box around
  the table's own. Instead `is_block` (`doc/lint.mbt`) takes rules and
  then one block for that block, which it is in the flow
  (`[#set table.cell(..);#table(..)]`); other sequences are still not
  looked into. Tested in `doc/lint_test.mbt` and `doc/para_test.mbt`, and
  for the element with and without a frame.
- **What it is not.** A `Table` can have cells with a position, lines and
  a footer among its cells, a header of several rows, and a frame in
  another stroke than its rules: a `DataTable` cannot, and says so. A
  `SetText` before the element sizes the em of the frame's spacing too,
  as before any table.

**`soft_breaks` in cells** (S5) is not built into the element: a cell of
inline code is `Raw(@format.soft_breaks(name))` (the guide, 7.2). Tested
in the kit and in the guide: `garden_bed_watering_schedule` in a column of
80pt is one run that leaves its cell, and with soft breaks three runs
inside it.

**The measurement.** `doc/examples/report` got a second page: a table of
ten beds (a header, a column of numbers, the row of the best bed tinted,
a chip for the state of each bed), by hand as the ports wrote it (`pill`:
a box with an outset and no-break spaces; `framed_table`: three `Cells`
functions in a clipped block) and with the kit.

| | helper lines | of them for the table | for the chip |
|---|---|---|---|
| before | 177 | 66 + 3 at the call | 15 |
| after | 103 | 34 + 9 at the call | 9 |

(`python3 scripts/edsl_helper_lines.py`; 32 lines are in both.) What is
left in the helper with the kit is the caller's design: the fill function
for the header and the marked row (13 lines), two rules for the text, and
the call.

The pages are identical: the SVG of both pages and the PDF bytes
(`report_wbtest.mbt`). For that, the size of the cells' text is a show-set
rule on the cells in the version with the kit, where the hand-written
helper set it inside its frame: as a `SetText` before the element it
would also be the em of the frame's spacing. Where the table continues on
a next page the two differ, by the one rule described above: on a page
that holds seven rows, the text, the fills, the chips and the frames are
drawn the same at the same places, and the hand-written table has one
line more, under the last row of the first page. There the element is
right and the helper is what the port reported.

Building and compiling one document (`report time 500`, embedded fonts,
aarch64 macOS, means of 500 runs in three repetitions): 10.9, 11.0 and
10.9 ms before; 11.4, 11.5 and 11.4 ms after. The table alone on a page
(`report time 500 table`): 5.48, 5.52 and 5.46 ms before; 5.54, 5.59 and
5.53 ms after, 1% slower. The rest of the difference is the cards of
step 3.

**Conventions amended** (`doc/kit/kit.mbt`, each marked "step 4"):

1. An expansion can hold a rule of its own, scoped to it, and is not
   wrapped in a block for that (convention 1).
2. A parameter can be a part of a primitive's parameter, in that part's
   type, where the element supplies the rest; per-cell parameters stay
   per cell; no parameter for the style of text; a second constructor
   `of` where a string is treated differently from content; `key` for
   data by items (convention 2).
3. Parts per item are keyed by index or by `key`; what an element has to
   know about a description it asks `doc` (convention 3).
4. No callback where a value of the primitive does the work; a callback
   in an argument is the caller's; an element that does not measure still
   says what it does at a page break (convention 4).
5. What is wrong with one item is an error at the argument under the key
   of the item; a key of the caller's that `Keyed` does not take is an
   error at `key` (convention 5).
6. The twin checks what the element checks, and a test gives both the
   same rejected input (convention 6).
7. For an element without a callback: that it can be built inside one,
   and the engine's facts about what can leave the page or its place
   (convention 7).

## 5. Marks (a trial, in the kit)

Revision 8 decided that strings are never parsed, and guarantees that `_`,
`*`, backslashes and other punctuation stay literal in `Prose`. Two authors
wrote a parser for marks anyway, with different grammars; two used an
interpolated helper. That is evidence that inline code is too heavy at 100+
sites per document, not yet evidence for one grammar. So `Prose` does not
change, and the kit gets a separately named constructor to try:

```moonbit
@kit.Marked("Run `moon check` after **every** edit, see [the guide](#setup).")
```

- Marks: `` `code` `` (no nesting, no marks inside, may not span lines),
  `**strong**`, `_emph_` (opening `_` after start, white space or opening
  punctuation, closing `_` before end, white space or punctuation; never
  inside a word, and never between CJK characters without spaces, where
  `Emph(..)` is written instead), `[text](target)` with `target` a URL or
  `#label` (parentheses in a URL are percent-encoded by the author).
  `**` and `_` nest in each other, not in themselves. An unmatched mark is
  literal text. A backslash before a mark character makes it literal, and is
  processed before marks.
- Interpolated strings are text of the argument like any other, so marks in
  `\{data}` are parsed; `\{@doc.Lit(data)}` keeps data literal. Interpolated
  descriptions are placeholders as in `Prose` and are never parsed. A
  placeholder inside a code mark or inside a link's target cannot be lowered
  (`raw` and a URL are strings): it is a located error, "a description cannot
  be interpolated inside `code`" (resp. "a link target"); inside `**`, `_`
  and a link's text it is content like anywhere else.
- Lowering: each mark is the call its typed constructor makes. Twin:
  `raw("..")`, `strong[..]`, `emph[..]`, `link(..)[..]` around literal text
  with `Prose`'s white-space and quote expansion; not Typst markup of the
  same shape.
- Provenance: the pieces get distinct spans inside the argument's (`Pieces`),
  so a selection resolves to the argument, as for any text whose rendered
  characters are not the literal's (tier 2 of the review loop). No character
  mapping through removed marks is claimed; that would be the engine work
  section 12.4 of revision 8 reserves.

Whether `Marked` moves into `doc` is decided after the rewritten ports
(section 9) show whether authors choose it over `c("x")`.

## 6. Lints

Checks the EDSL can make that the engine does not, in `report.lints`
(separate from `warnings`, which stay upstream's diagnostics), each with an
origin. They run by default; `lints=false` on `compile_*` turns them off.
What each can and cannot promise:

- L1, adjacent inline items (S1). On the description tree, at author level:
  in the item array of `Document`, `Seq` or a kit container, two neighbours
  are reported
  (a) if both are a bare `Prose` (the `Prose` itself, not one wrapped in
  `Text`/`Strong`/`Emph`/`Link`), in any array, with or without a block in
  it: a `Prose` drops the white space at its edges, so two in a row never
  have anything between them;
  (b) if each is a string, a `Prose`, or a `Text`/`Strong`/`Emph`/`Link`
  wrapping one, when the array also holds at least one block-level
  constructor (so a purely inline sequence of strings and wrapped text, as
  in a `Text` body, is not reported).
  It is a heuristic: it does not see through callbacks, `Call` or embedded
  content. `Para` is the fix it names.

  As built (step 1, `doc/lint.mbt`; rule (a) was added after the first
  implementation, which had only (b) and so missed the plainest form of S1,
  `Document([Prose(..), Prose(..)])`):
  - A lint is `Lint { kind : LintKind, message, hints : Array[Hint],
    location : Location? }` with `render()`; `LintKind` has the one case
    `AdjacentInline`. `Location` and `Hint` are those of diagnostics, so a
    later lint can point into a file of the world or nowhere, and a hint
    can carry a second place (for L1: the text before). A page number for
    L2 and L3 is a field to add then. `lints` is on `CompileReport` (not on
    `ExportReport`), also when the compilation failed; `lints?` is on
    `compile`, `compile_paged` and `lower`.
  - Block-level constructor: a call of an element that the engine keeps out
    of a paragraph whatever its arguments are: what the show rules wrap in
    a block unconditionally, the elements of the flow (`par`, `parbreak`,
    `pagebreak`, `colbreak`, `v`, `place`, `block`), list items, and
    `align`, whose style interrupts a paragraph; `raw`, `quote` and
    `Equation` only with a literal `block=true`. `doc/lint_wbtest.mbt`
    checks the list against the engine for all 77 constructors of the
    generator's table, so a new element has to be classified.
  - "A string" is a plain string. A `Lit` is not text for the lint: the
    translator writes markup as a stream of `Lit`s and spaces between
    `Parbreak`s, and counting it gave 11 reports on one correct document
    (`doc/convert/sample/gen_showcase.mbt`). An empty string is not text.
  - Neighbours are adjacent items of the array: a rule or anything else
    between two texts hides the pair (a false negative; no document showed
    a need to look through rules). `Keyed` and a label do not change what
    an item is. A pair with a block interpolated at its seam (a `Prose`
    that ends or starts with one) is not reported.
  - The place of a lint is the argument that has the text, as the review
    loop resolves that text on the page (`ReviewText::origin_positions`
    finds its boxes); one source location is reported once, however often
    its description is used or under how many keys.
  - The walker looks into arguments of constructors and of set rules
    (also the generic `Set`), into arrays, dictionaries and operands of
    values, and into the texts of `Prose` and `Para`; not into `Call` and
    call values, callbacks, `Markup`, `Equation` and views.
  - Measured: no report on the documents of the tests of `doc` but those
    written to show the defect, on the 42 documents of the `edsl` stage but
    one (the twin `prose` puts two
    `Prose` side by side on purpose; the stage does not look at lints), and
    none on the fourteen ports as written. With their paragraph helpers
    taken out, `typst-evaluation` and `session-migrations` report one pair
    each, which is every adjacent pair they have (the first is the seam the
    findings quote). Without the block condition of (b), about 30 places of
    correct inline composition would be reported.
  - Known false negatives: strings and wrapped text in an array without a
    block; `Text(Seq([..]))`, which is what the mark parsers of two ports
    produce; wrappers other than the four (`Highlight`, `Underline`).
- L2, missing glyphs (S4). From the frames: glyph id 0 in a text item, with
  the origin of that glyph's span (a text item can combine several origins)
  and the text of the cluster (a code-point sequence; for clusters beyond the
  65,535 range limit, the item's text). In a world without any font the
  text is not in the frames at all, so there is nothing to find; the engine's
  "unknown font family" warning is what remains.
- L3, content outside the page. From the frames: an item whose bounds leave
  the page by more than 1pt. Its origin is the item's span where it has one;
  decorations and other items with detached spans are reported with the
  origin of the nearest enclosing group that has one, or with the page only.
  Not covered: overflow of a fixed-size container (S2). Frames do not record
  which container had a fixed size or where it was declared; that needs a
  side channel from layout (container identity, bounds, origin, clipping,
  fragments), which is an engine instrumentation decision outside this
  proposal. Until then S2 is answered by the kit (apart from `Canvas`, whose
  height the author gives and which is unbreakable, its elements take no
  fixed heights, and measured cards are unbreakable) and the guide. S3 has no
  out-of-bounds geometry at all and is answered by `Cards`.
- L4, ambiguous origins. On the description tree the author passes to
  `compile_*`, before lowering: more than a threshold of distinct positions
  in the tree that hold one call site with one key path. Content returned by
  callbacks is not counted (callbacks are invoked an arbitrary number of
  times during layout and measurement, so counts taken while lowering say
  nothing). Reported as a note that the review loop cannot tell these
  positions apart (reuse of a description is valid), with `Keyed` and
  `#callsite` as remedies.

## 7. The guide

`docs/edsl-guide.md`, written first (section 10, step 0), from the ports:
the `using @doc { .. }` prelude (it removes two thirds of the `@doc.`
prefixes; `trait IntoContent`, not `type`), helpers that keep the caller's
location (`#callsite(autofill(loc, args_loc))`), `Rel`, `Call`,
`NoneValue()`, `font_paths` for fonts that are not embedded, the table of
section 2.4 with the remedy for each row, equal-height cards by cell fill,
and when the creation rule bites.

## 8. For the language (not EDSL work)

1. `if`/`match` branches of different concrete types do not unify to an
   expected `&Trait` (`has type : Prose wanted : Box`); the same in closures
   passed to `map`.
2. A `#|` string passed directly as an argument warns (`deprecated_syntax`),
   so each needs parentheses on lines of their own.
3. `f(x) <| y => @pkg.g(..)` is a parse error; the body needs braces.
4. `using @doc { type Sides }` reports the name unused when it is only used
   as a constructor.
5. No number formatting in core (`toFixed`, grouping).
6. Three enums with the same constructor names (`Pt`, `Em`, ..) cannot share
   one helper's return type.

## 9. How success is measured

Before anything is rewritten: five ports (bench, mooncakes-health,
tun-poc-zh, session-migrations, typst-evaluation) are reduced to committed
examples with synthetic data and fixed fonts, and their pages are stored as
baselines. One rule decides what a helper line is: a top-level function or
constant that does not contain text or data of the document. Then:

- Per finding, an acceptance test that states which of three outcomes holds:
  prevented (the construct that failed is replaced by one that cannot),
  reported (a lint or located error, with its test), or documented choice
  (a guide entry; S6 and the auto-column behaviour are of this kind).
- Per rewritten port: helper lines before and after by the rule above; pages
  compared with the baseline, each difference classified as none, or as an
  approved correction (a measured baseline replacing `0.72 × size`, a
  corrected overflow); compile and layout time before and after.
- The kit's pairs pass the `edsl` stage's full comparison.

A lower helper share alone is not success: it can be reached by moving
complexity into the kit, which is why the time and page comparisons are part
of the gate.

## 10. Order of work

Small pull requests, each with tests and its twin check.

0. Fixtures and the guide: a failing or documenting test for every row of
   2.1 and 2.3 (including a reproducer for T10), the five synthetic examples
   with baselines, `docs/edsl-guide.md`.
1. `Para`; lint L1.
2. Typed parameters and values of 3.4; `Size.baseline`; `Layout`.
3. One kit element end to end, with its twin and gates: `Cards` (both
   forms). The package's shape is settled on it before the rest.
4. `Chip`, `DataTable`, `doc/format`.
5. `Canvas`, `Lines`, `Flow`.
6. Lint L2 (a prototype comes with step 0's fixture), then L3 and L4.
7. `Marked`.
8. The five examples rewritten; the measurements of section 9.

## 11. Resolution of the first review

1. Text offsets through marks: the claim is removed; marks have a grammar,
   an interpolation rule, argument-level provenance and functional twins
   (section 5).
2. `Layout`: fallible callback with `Ctx`, base-size semantics, and the
   creation rule stated for it and for the kit, which says per element
   whether it measures (3.2, 4).
3. Baseline, edges, dash and colour contracts corrected, explicit states and
   escapes kept; `Outline(title=NoneValue())` reclassified as documentation
   (3.4, T9).
4. Conversion errors stay located lowering errors; `Sides::zero` only; T10
   waits for a reproducer (3.4).
5. Kit elements have functional Typst twins and pass section 16's gates (4).
6. Kit contracts: measurement width and keys, baseline from `measure`,
   pagination, table columns and spans, line handling of `Lines`, one site
   per composite (3.1, 3.3, 4).
7. Lints restated with what each reads and cannot see; fixed-container
   overflow is named as engine instrumentation outside the proposal (6).
8. Section 2.4 and the evidence claims corrected; the guide and fixtures
   come first; success is per finding and per port (1, 2.4, 9, 10).

Second review (`ports-proposal-2.md`):

1. Colour contract: percentages to `Ratio`, the `mix` pairs, `ColorSpace` as
   an enum over the engine's space values, `Auto` as upstream's default, no
   CSS equivalence (3.4).
2. `Canvas` is an unbreakable block; the sentence about fixed heights is
   corrected (4, 6).
3. Lints: L2 per glyph span, L3 with ancestor or page-only origins, L4 on
   the author's description tree, not on lowering counts (6).
4. Placeholders inside code marks and link targets are located errors (5).
5. Kit provenance through one public hook, `Composite` (4).
6. The sticky paragraph is corrected (2.4).
Its optional points: `Layout` passes a `Region`, not the `Size` of
`measure` (3.2); `Lines` states empty lines, tab stops and wrapping (4).

Third review (`ports-proposal-3.md`): `Composite` maps arguments explicitly
(`site.arg(i, v)`); primitives inside `build` fall back to the composite's
call instead of using their own parameter indices (4; as built in step 3).

Optional points of the first review taken: marks as a separately named constructor in the kit;
cards by cell fill before measurement; format utilities in their own
package; fonts by `font_paths` fixtures before any embedding decision.

## 12. Open questions for the owner

1. Embed a sans-serif family for `doc`, or keep upstream's three families
   and document `font_paths`? (Until answered: `font_paths`, no embedding.)
2. Lints on by default? Decided by the owner on 2026-10-06: yes
   (`compile_*(.., lints=false)` turns them off).
3. The engine side channel that fixed-container overflow (S2) needs: wanted?
   (Until answered: not built.)

## 13. Corrections from the reproductions (revision 5)

Step 0 wrote a test for every row of 2.1 and 2.3. All reproduce but one,
and some are narrower than the ports reported:

- T10 does not exist: the error is located. The coordinator's reading of
  the slide deck's error was wrong.
- S2a needs content that nearly fills the fixed height; S5 needs a long
  word. Both rows are restated.
- T4 and T7 are gaps of discovery (`Value::call`, `Call`), like T6 and T9.
  The typed forms of 3.4 stay: four authors did not find the untyped ones.
- `Chip` does not need `Box(baseline=)`; section 4 is corrected.
- The baseline estimate the ports used (0.72 × size) was not the engine's
  (0.66 for the default font), which is one more reason for `Size.baseline`.

## 14. Three papers (addendum)

After the fourteen HTML pages, three papers were ported in full against
`main`, each by one agent with the brief `_build/edsl-demo/papers/BRIEF.md`:
Lovelace's Notes to Menabrea's memoir (1843; Notes A, F, G with the diagram
of Note G; 22 pages, about 290 formulas and 420 formula cells), Einstein's
"Foundation of the Generalised Theory of Relativity" (1916, Bose's
translation of 1920; 39 pages, 684 formulas, 101 of them numbered), and
Ramanujan's "Modular equations and approximations to π" (1914; 14 pages in
two columns, 355 formulas). None needed embedded Typst source. The texts
came from web transcriptions and were not checked against scans; only the
Lovelace port is committed-quality as to rights (public domain worldwide),
and the three packages stay outside the repository until that is decided.

Mathematics is Typst math syntax in a string (`Equation(src, ..)`): the EDSL
adds nothing to the formula itself. What the ports show is what surrounds
it.

### 14.1 Wrong output without a diagnostic

| # | What happens | Papers |
|---|---|---|
| M1 | An unclosed or mismatched delimiter in a formula is not an error: `x^(n.` sets "(n." as the exponent, `(a + b]` is accepted. Two authors wrote an external bracket checker | 3 |
| M2 | A block equation wider than its column is set over the neighbouring column | 1 (two columns) |
| M3 | `Par(Prose(..))` with an interpolated block equation drops the equation with a warning (fixed by `Para`'s lowering, 3.1) | 2 |
| M4 | A fixed-size `Block` holding a drawing splits at a page end (S2a again) | 1 |
| M5 | Rows of `cases` and of `mat` are set in text style: fractions and nested matrices in a system behind a brace shrink unless each cell is wrapped in `display(..)` | 3 |

### 14.2 What each paper wrote again

| # | Helper | Lines |
|---|---|---|
| N1 | Inline formula in prose: `\{m("..")}` at 232 to 470 sites per paper, with a `#callsite` helper so errors point at the call | 5, plus the sites |
| N2 | Numbered display with a label, an unnumbered one, and a guard that label and number agree | 30 to 45 |
| N3 | An explicit equation tag ("(1a)", "(20a)"): one `Numbering::func` callback per equation | 101 callbacks in one paper |
| N4 | A reference in the paper's own form: `Ref` prints "Equation 1", or "1" without the supplement, never "(8.)" | 3 to 4, at every reference |
| N5 | A formula that does not break at a relation in running text: `Box(Equation(..))` | 1 |
| N6 | A function in a formula's scope (Christoffel symbols): `Value::call("eval", ..)`, and the scope passed to every `Equation` | 12 |
| N7 | A wide display in the middle of two-column text: end the columns, set the display, start balanced columns again | 55 |
| N8 | Running header by parity with the page number outside | 35 to 45 |
| N9 | A table by rows that checks the number of cells; a delimiter stretched over a row-spanning cell | 30 + 20 |

### 14.3 Diagnostics

- A formula error is located and has upstream's hints, but the location is
  the call (or the helper, without `#callsite`) plus a byte range in the
  string after interpolation; for a multi-line string that is not the line
  of the typo, and no excerpt is shown.
- One error per run (20 to 75 s per run for these documents in a debug
  build).

### 14.4 What follows

In `doc` and the kit, each with the gates of section 4, after `Cards`:

1. Lint L5, unbalanced delimiters in an `Equation` source (M1): on the
   string, with Typst math's own tokens (so that `\(`, quoted text and
   `mat(delim: ..)` are not misread); reported at the formula's location
   with line and column inside the string.
2. Formula error locations (14.3): map the engine's byte range to the line
   and column of the literal in the MoonBit source, as `review_source` does
   for prose, and print the excerpt. Reporting all errors of a run needs the
   evaluator to continue after an error, which upstream does not do either:
   not proposed.
3. Lint L6, a block equation wider than its region (M2): from the frames,
   where the equation's frame is wider than the region it was laid out in;
   whether the frames carry that needs to be established first.
4. Kit `Display(src, tag~, label~)`, `EqRef(label, form~)` and
   `Inline(src)` (N2 to N5): an explicit tag without a callback per
   equation, a reference that prints the tag in the equation's own
   numbering form, an inline formula that does not break. Their twins are
   `math.equation` with a numbering function, `ref`, and `box`.
5. Typed `first_line_indent` (with `all`), `Select::footnote_entry()`, a
   citation form without a mark, `Figure(kind=)`: the unmapped fields these
   ports met, through the generator's type table.
6. The guide gets a chapter on mathematics: escaping in `#|` and `$|`
   strings, text and spacing in formulas, `display(..)` in `cases` and `mat`
   (M5), prescripts, numbering, references, scopes with functions (N6),
   what an error looks like; and one on papers: `Para` with displays and
   indents, footnotes, `Cite` and `Bibliography` (title-casing, braces),
   headers by `Context`, `Columns` with `balanced` and footnotes in columns
   (N7).

Not proposed: typed constructors for mathematics. Three papers and 1,330
formulas were written as strings without one syntax failure in final work;
the cost was in what is listed above, not in the notation.

A two-column flow with spanning displays (N7) and a row-oriented table
builder (N9) are candidates for the kit once `DataTable` and `Flow` exist;
no design yet.
