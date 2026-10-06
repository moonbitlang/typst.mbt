# What fourteen ports showed, and what the EDSL changes (proposal, revision 1)

Status: proposal, not yet reviewed. It extends `docs/edsl-design.md`
(revision 8); where the two disagree, that document holds until this one is
accepted and folded into it.

## 1. The experiment

Fourteen HTML pages (reports, tutorials, dashboards, one in Chinese; 18 to
85 KB each) were ported to PDF as single-file MoonBit scripts against the
published package (`moonbitlang/typst@0.1.4/doc`), by five independent
authors (the coordinator and four agents) who each reported every place where
the EDSL lacked something, was verbose, surprised them, or reported an error
badly. The scripts, PDFs and page images are in `_build/edsl-demo/ports/`
(not committed: the pages are private).

Result in numbers:

| | |
|---|---|
| Ports that build and read as the same document | 14 of 14 |
| Ports that needed embedded Typst source (`Markup`) | 0 |
| Engine errors (`DocError`) across about 45 builds | 2, both located at run time only |
| Lines of script | about 15,700 |
| of which helper code a library could provide | about 5,600 (36%) |
| Silent wrong output found only by looking at the page | 6 kinds (section 2.1) |
| Build and run per iteration | 15 to 18 s (12 s link, 5 s run) |

So the engine is expressive enough; nothing was impossible. The cost is
(a) output that is wrong without any diagnostic, and (b) a third of every
script being the same helpers written again: cards, chips, tables, a canvas,
number formats, inline markup.

## 2. Findings, by cause

`n/5` is the number of authors who hit it independently.

### 2.1 Silent wrong output

| # | What happens | n/5 |
|---|---|---|
| S1 | Two adjacent inline items in a sequence (a `Prose`, a string, a `Text`) are typeset as one paragraph with no space between them: "…incremental.Two execution modes…" | 3 |
| S2 | A `Block`/`Box` with a fixed height does not grow: text runs out below it, and across a page break the rest lands outside the box on the next page | 4 |
| S3 | `Block(height=Pct(100))` in a grid cell takes the rest of the page (an extra page appears) | 2 |
| S4 | A character no font covers is drawn as an empty box; `warnings` is empty | 1 |
| S5 | Inline code in a table cell does not break and runs over the cell border | 2 |
| S6 | `Prose` turns `'` after a digit into a prime ("#1770′s") | 1 |

### 2.2 Things every script wrote again

| # | Helper | n/5 | lines each time |
|---|---|---|---|
| H1 | Paragraph wrapper around `Prose` (because of S1) | 3 | 3 + one call per paragraph |
| H2 | Inline markup: `c("x")` for code at 100 to 150 sites, or a parser for `` `code` ``, `**strong**`, links | 4 | 55 to 103 |
| H3 | Equal-height cards in a row, with rounded corners (`Context` + `measure`, each card built twice, the row width typed in by hand) | 5 | 13 to 50 |
| H4 | Chip/pill: inline box that does not wrap and sits on the text baseline | 4 | 10 to 20 |
| H5 | Framed data table: header style, row rules, numeric columns, a marked row, rounded frame | 4 | 49 to 60 |
| H6 | Canvas: absolute placement, text anchored at a point, arrowheads, a scale | 4 | 68 to 320 |
| H7 | Number and date formats (`toFixed`, grouping, k/M, dates, `localeCompare`) | 4 | 30 to 147 |
| H8 | Code block with coloured or dimmed spans (not a `raw`: `Raw` takes a string) | 3 | 30 to 55 |
| H9 | A wrapping row of boxes with vertical centring (pipelines) | 1 | 40 |

### 2.3 Typed API gaps

| # | Gap | Workaround used |
|---|---|---|
| T1 | `Box(baseline=)` (unmapped type) | `Grid(align=Horizon)`, `outset` |
| T2 | `top_edge`/`bottom_edge` on text and highlight (unmapped) | `extra=[("top-edge", ..)]`, added gaps |
| T3 | `Stroke(dash=)` is a `Value` | `Value::str("dotted")`, `Value::array(..)` |
| T4 | No alpha, mix, lighten on `Paint` | 8-digit hex strings, a hand-written mixer |
| T5 | No `Layout` (the available size) | page width typed in as a constant |
| T6 | `Length`, `Sizing`, `Spacing` do not convert (`Rel(len)` exists and nobody found it) | helpers return `Double`, `Pt(px(14))` at 70 to 92 sites |
| T7 | No `Upper`/`Lower` for content (`Call("upper", ..)` exists and nobody found it) | `s.to_upper()` on strings |
| T8 | `Sides::none()` type-checks as an inset and fails at run time | `Sides(all=Pt(0))` |
| T9 | `Outline(title=)` cannot be `none` | `Value::none()` |
| T10 | `Stroke(paint=None)` fails with no source location | `Stroke::none()` |

### 2.4 Behaviour that is Typst's, and stays

Auto columns distribute by Typst's algorithm, not HTML's; `sticky` binds one
block; `raw` sets its size to 0.8em and em sizes compound; a stroke
dictionary with one side leaves the others at the default; smart quotes
follow Typst's rules (S6). The port is faithful to upstream, so the engine
does not change. The EDSL answers with a kit element that picks the right
settings (section 4), a lint (section 5) or documentation (section 7).

### 2.5 Outside the EDSL

- Fonts: no sans-serif face is embedded, which is the largest visual
  difference of every port; `system_fonts=true` raised one run from 5 s to
  39 s. Section 6.
- MoonBit: findings for the language, listed in section 8.

## 3. Changes to `doc` (the typed facade)

`doc` stays what revision 8 defines: typed constructors lowered through the
evaluator's own paths, each with a Typst twin. The changes below keep that.

### 3.1 Paragraphs

`Prose` stays inline (it is interpolated into other prose, and passed as a
body). New:

```moonbit
(
  $|Each dot is one complete trial of all nine milestones.
)
|> @doc.Para                        // = Par(Prose(text)), with par's options
@doc.Para("One line.", justify=true)
```

Twin: `#par[..]`. `Para` takes the options of `Par` and of `Prose`
(`quotes`, and `marks` of 3.2). S1 itself is reported by lint L1.

### 3.2 Marks in prose (opt-in)

Revision 8 decided that strings are never parsed. Four of five authors then
wrote the same parser. The proposal keeps the decision for plain strings and
for `Prose` by default, and adds an opt-in:

```moonbit
@doc.Para("Run `moon check` after **every** edit, see [the guide](#setup).", marks=true)
```

Exactly four marks, nothing else is special: `` `code` `` (a `raw`),
`**strong**`, `_emph_` at word boundaries, `[text](url)` or `[text](#label)`.
A backslash escapes a mark character. Interpolation works as before. Each
mark lowers to the same call the typed constructor makes (`Raw`, `Strong`,
`Emph`, `Link`), so the twin is the Typst markup of the same shape, and the
pieces take sub-ranges of the argument's span like interpolations do
(`Pieces`); the text-offset rule of section 12.4 maps positions through the
removed mark characters. Typst markup itself is not accepted here: `#`, `$`,
`@`, `<`, `*` in data ("#1770", "$43.86", "@app") must stay literal.

### 3.3 `Layout`

```moonbit
@doc.Layout() <| size => { .. size.width .. }   // pt, the region's size
```

`layout(size => ..)` with a host callback, like `Context`. Removes the
hand-typed page widths (T5) and is what the kit's `Cards`, `Flow` and
`Canvas` are built on.

### 3.4 Typed parameters and values

Through `scripts/docgen.py` (type table and facades):

- `Box(baseline=Length)` (T1).
- `top_edge`/`bottom_edge : TextEdge` on `Text`, `SetText`, `Highlight`
  (`Ascender`, `CapHeight`, `XHeight`, `Baseline`, `Bounds`, `Descender`,
  `Len(Length)`) (T2).
- `Stroke(dash=Dash)`: `Solid`, `Dotted`, `Dashed`, `DashDotted`, the
  `Densely*`/`Loosely*` presets, `Pattern(Array[Length], phase~)` (T3).
- `Paint::alpha(Double)`, `mix(Paint, Double)`, `lighten(Double)`,
  `darken(Double)`, lowered to the engine's `transparentize`, `color.mix`,
  `lighten`, `darken` (T4).
- `Length::sizing()`, `Length::spacing()`; the guide shows `Rel` (T6).
- `Upper(body)`, `Lower(body)` (the `upper`/`lower` functions) (T7).
- `Sides::zero()`; `Sides::none()` given to a length-typed parameter is an
  error raised at construction with the call's location (T8).
- `Outline(title=)` accepts `NoneValue()` like other content options (T9).
- Every value conversion error carries the location of the constructor that
  holds the value (T10).

## 4. A kit (new package `doc/kit`)

Composites that have no Typst element: they are built only from `doc`'s
public API, so each has a definition in EDSL primitives rather than a Typst
twin, and is tested against that definition (same frames). Nothing in `doc`
depends on the kit.

| Element | Replaces | Built from |
|---|---|---|
| `Chip(body, fill~, text~, stroke~, radius~, inset~)` | H4 | `Box` with `baseline`, measured width so it does not wrap |
| `Cards(items, columns~, gutter~, fill~, stroke~, radius~, inset~)` | H3, S3 | `Layout` + `measure`; rows of equal height; cards unbreakable |
| `Flow(items, gap~, row_gap~, align~)` | H9 | `Layout` + `measure`, greedy rows |
| `DataTable(head, rows, numeric~, mark~, frame~, header~, rule~, column_text~, key~)` | H5 | `Table` with the three `Cells` closures, `TableHeader`, a clipped rounded `Block`; rows keyed for provenance; `rest=Stroke::none()` set for the author |
| `Canvas(width~, height, items, unit~)` with `text(x, y, body, anchor~)`, `line`, `rect`, `circle`, `curve`, `arrow(.., head~)` | H6 | `Block` + `Place`; anchored text by `measure`; `width=Auto` takes the region's width from `Layout`; arrowheads as polygons |
| `Verbatim(text, lang~)` | H8 | monospaced text that keeps spaces and line breaks and takes interpolated styled spans (`\{kw("#let")}`); not a `raw` element, and says so |
| `format`: `fixed`, `grouped`, `percent`, `compact` (k/M), `date`, `break_anywhere` | H7, S5 | plain MoonBit, no engine |

The kit is where "what settings make this come out right" lives, so that
section 2.4 does not have to be learned by each author.

## 5. Lints

Checks the EDSL can make that the engine does not, reported as
`report.lints` (separate from `warnings`, which stay identical to upstream's
diagnostics), each with the origin of the offending call:

- L1 (S1): in a sequence at block level, two adjacent inline children.
- L2 (S4): a glyph that resolved to `.notdef`, with the character.
- L3 (S2, S3): content that extends beyond its fixed-size container or the
  page by more than a tolerance, unless the container clips.
- L4: many elements from one call site without `Keyed` (a helper without
  `#callsite`, a loop): a note, since only the review loop is affected.

L1 and L4 read the description tree; L2 and L3 read the frames.

## 6. Fonts

- A decision for the owner: embed one sans-serif family for `doc` (four
  styles, about 1.2 MB, OFL) next to the three families upstream embeds, or
  keep parity with upstream's set and document `font_paths`.
- System font discovery costs 34 s in an mbtx run (debug wasm): to profile
  separately; not part of this proposal.

## 7. Documentation

A guide, `docs/edsl-guide.md`, written from the ports: the `using @doc { .. }`
prelude (which removes two thirds of the `@doc.` prefixes), helpers that keep
the caller's location (`#callsite(autofill(loc, args_loc))`, found by
experiment by one author), `Rel`, `Call`, the table of section 2.4, and one
reference script per kind of document.

## 8. For the language (not EDSL work)

1. `if`/`match` branches of different concrete types do not unify to an
   expected `&Trait` (`has type : Prose wanted : Box`); same in `map`
   closures. Every script has `let x : &IntoContent = ..; x` dances.
2. A `#|` string passed directly as an argument warns (`deprecated_syntax`),
   so each needs parentheses on their own lines.
3. `f(x) <| y => @pkg.g(..)` is a parse error; the body needs braces.
4. `using @doc { type Sides }` reports the name unused when it is only used
   as a constructor.
5. No number formatting in core (`toFixed`, grouping).
6. Three enums with the same constructor names (`Pt`, `Em`, ..) cannot share
   one helper's return type; an implicit conversion or a common trait would
   remove about 160 call-site wrappers across two scripts.

## 9. Order of work

Small pull requests, each with tests and its twin or definition check:

1. `Para`, lint L1, located value errors, `Sides::zero` (the silent and the
   unlocated first).
2. Typed parameters and values of 3.4, `Layout`.
3. Kit: `Chip`, `Cards`, `Flow`, `DataTable`.
4. Kit: `Canvas`, `Verbatim`, `format`.
5. Marks in prose.
6. Lints L2 to L4.
7. The guide; five ports rewritten against the kit (bench, mooncakes-health,
   tun-poc-zh, session-migrations, typst-evaluation) as `doc/examples`
   with synthetic data, and the measurement below.

Success is measured on the rewritten ports: helper code under 10% of the
script (from 36%), every silent failure of 2.1 either impossible or reported
by a lint with a test, and the pages unchanged.

## 10. Open questions

1. Is `marks=true` worth a second inline syntax next to interpolation, or
   should the guide teach `c("x")` and stop there?
2. Should lints be on by default?
3. Kit as a package of this module (`doc/kit`) or a separate module that can
   move faster than the engine?
4. The sans-serif family (section 6).
