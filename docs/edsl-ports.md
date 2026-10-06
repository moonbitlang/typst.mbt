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

`Para(text, ..)` is `Par(Prose(text, quotes~), ..par's options)`. Twin:
`par(..)[..]` around the functional expansion of the prose (section 4.4 of
revision 8), not `#par[text]`. Provenance: one site, `Para`, whose first
argument is the prose text; the inner `Par` and `Prose` are built with that
site and do not register sites of their own (the registry deduplicates by
location and key path, so two differently shaped constructors must not share
a location).

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

### 3.3 `Size` with a baseline

`Ctx::measure` returns the engine's baseline as well (`Size.baseline`), so
text can be anchored on its baseline without a font-size estimate (T11).

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
constructed before `build` ran and A measuring element calls the hook again, with the same site, inside its
callback, for the ordinary descriptions it rebuilds there; creating a new
callback description there stays the existing error. So a selection inside a chip's text resolves
to the caller's string or `Prose`, and a selection of the chip's box to the
caller's `Chip(..)` call.

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
  that are each a string, a `Prose`, or a `Text`/`Strong`/`Emph`/`Link`
  wrapping one, when the array also holds at least one block-level
  constructor (so a purely inline sequence, as in a `Text` body, is not
  reported). It is a heuristic: it does not see through callbacks, `Call`
  or embedded content. `Para` is the fix it names.
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
call instead of using their own parameter indices (4).

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
