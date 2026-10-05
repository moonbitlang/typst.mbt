# The review loop of the MoonBit EDSL

An AI writes a document as MoonBit code (`docs/edsl-design.md`); a human
reads the rendered pages, points at something and comments; the comment
should reach the AI **with the MoonBit source location that produced what
was pointed at**, so that the AI edits the right code without searching.

The loop is built in slices, each a small pull request with its own
section here. A section says what its slice guarantees and what it does
not do yet.

| Slice | What it adds | State |
|---|---|---|
| 1 | Click to source: the preview page, the origin of every rendered piece, the click lookup | below |
| 2 | Select text across runs, comment, copy the feedback as text and JSON | below |
| 3 | Source excerpts and source characters where they can be verified | below |
| 4 | `Keyed` data keys, callbacks, raw lines, limits, source line → page positions | later |

The appendix holds the design that the slices are cut from. It is **not
under review**; its text moves into a slice's section, shortened, when
the slice is built.

## Slice 1: click to source

### What it does

```moonbit
let report = document.compile_paged(world)   // the normal compilation

// The preview page: one self-contained HTML document.
let html : String = report.review_html().unwrap()

// The same question from code: what is at this point of page 1?
match report.origin_at(1, 120.0, 210.5) {
  Some(origin) => println(origin.describe())
  // doc/twins/bench.mbt:223:13 (Heading, argument 1)
  None => println("nothing with a source location")
}
```

- `CompileReport::review_html(title?) -> ExportReport[String]` writes the
  preview page: every page of the document as the SVG that `svg_pages`
  exports, and over each page an invisible **layer** with one shape per
  glyph run, shape and image. A shape of the layer carries the number of
  its origin; the table of origins is embedded in the page. A click shows
  the origin in a panel: file, line and column range, constructor,
  parameter, and the data key of a `Keyed` wrapper if there is one. All
  pieces with the same origin are highlighted.
- `CompileReport::origin_at(page, x, y) -> Origin?` is the lookup behind
  the page: the origin of the topmost text, shape or image at a point.
- `CompileReport::jump_from_click(page, x, y) -> Jump?` is upstream's
  `jump_from_click` (`typst-ide/src/jump.rs`) on our frames: links first
  (`Jump::Url`, `Jump::Position`), then `Jump::Source(origin)`.
- `doc/examples/review`: `preview [name] [-o file]` writes the page of one
  of the bench documents (default: the showcase), `at <name> <page> <x>
  <y>` prints the origin at a point.

An **origin** is what `Origins::resolve` gives for the span of a glyph,
shape or image (D 12.3): the constructor call, and the argument if the
span is narrower than the call. Its line and column range is the
argument's if there is one, the call's otherwise. For content of
`Markup`/`Equation` the origin is the call; for content made in a
callback it is the constructor call inside the callback.

### What it guarantees

1. **The export changes nothing.** `review_html` reads a compiled
   document. It is not a compilation mode: no lowering, layout or export
   code is touched, so the bytes of the normal SVG, HTML and PDF exports
   are what they were (the differential stages run unchanged, and the
   SVG inside the preview page is tested to be the string that
   `svg_pages` returns).
2. **Call provenance only.** The page names the constructor call and the
   argument. It makes no claim about a position inside a string — no
   text offsets, no source characters. Those come with slice 3.
3. **The page shows what the library answers.** The layer has, per item,
   the geometry that the click search tests (the box of a glyph run, the
   interior of a filled shape, the stroke of a stroked one, the rectangle
   of an image, the clip of a group applied before its transform). The
   browser's own hit testing finds the shape under the pointer, so the
   page's script contains no geometry. The page carries the library's
   answers for a grid of points per page; opening it with `#selftest`
   compares them with what the browser finds.
4. **Self-contained.** One file; style sheet, script and data are inline;
   no request leaves the page. Light and dark themes come from tokens on
   `:root` (`prefers-color-scheme`, `[data-theme]`); at phone width the
   panel is a sheet at the bottom edge and the page does not scroll
   sideways. The script uses no dialogs, no printing and no downloads.

### How the click lookup differs from upstream

`jump_from_click` is a faithful port, with two differences that the
source states: a span is resolved with the report's origins instead of
the parsed source of its file (there is no Typst source), and a glyph
whose span has no origin does not shift the boxes of the glyphs after it
(upstream skips the advance for such a glyph).

`origin_at` runs the same search with five rules changed, because the
question is "where does this come from", not "where should the editor
jump", and because the page's layer must answer it the same way:

- a link does not hide the content under it (outline entries, citations
  and references are links);
- a shape or image without a source location is transparent instead of
  ending the search;
- a filled curve (or a clip) counts as it is painted, with open subpaths
  closed, where upstream tests the open path and finds nothing inside
  it;
- a dashed stroke counts as a whole line, gaps included (upstream
  expands the dashes; the work of that grows with their number);
- a group whose transform has no inverse draws nothing and is skipped
  (upstream's `invert` answers a scale of zero with a translation).

In the page, the exporter's SVG is inert: the links of the document can
be neither followed nor focused, so the page does not lead anywhere.

`kurbo/winding.mbt` adds the port of kurbo 0.13.1's `PathSeg::winding`,
`BezPath::winding` and `BezPath::contains`, which upstream's
`Curve::contains` needs.

### Known limits of this slice

- Content that the engine generates without a source location has no
  origin: list markers, numbers of headings and equations, the
  supplement of a caption (`Table 1:`), the rules of a table, page
  fills. A click on it says so. (Mapping it to the enclosing element is
  a later slice.)
- All strings of one array argument and all runs of one `Prose` have the
  same origin, the argument. (Slice 2 tells them apart as pieces.)
- A parameter is shown by its position among the constructor's declared
  parameters, not by its name.
- The stroke of a dashed line is hit in its gaps as well, in the page
  and in `origin_at`. `jump_from_click` expands the dashes like
  upstream, so a line with an extreme number of dashes is as expensive
  there as it is upstream.
- A curve that does not start with a move is read from the origin by the
  layer.
- The layer rounds coordinates to four decimals of a point (transform
  coefficients are not rounded), so the page and the library can differ
  within that distance of an edge.
- The page of slice 1 is for pointing: selecting text and commenting
  come with slice 2.
- HTML and bundle targets are not covered: the page is built from paged
  frames.

### Tests

- `doc/review_test.mbt`: upstream's click cases that need no Typst
  source (a filled rectangle, also rotated, scaled and clipped; shapes by
  fill and by stroke; an open filled path), text with its call and
  argument, a link in both lookups, generated content, points outside the
  page; the page (the exporter's SVG unchanged inside it, the layer, the
  table, no external reference, both themes, a failed compilation).
- `doc/examples/review/review_wbtest.mbt`, on the showcase: a heading, a
  figure caption, a table cell built in a loop, the page header made by a
  `Context` callback and the three images lead to the line and column of
  their constructor call. The expected positions are found by searching
  the source file, the points to click by searching the frames.
- The self-test of the generated page in a browser: at 3,072 points of
  the showcase's four pages the page finds the origin that the library
  finds, before and after every shape of the layer is marked.

## Slice 2: select text and copy feedback

### What it does

```moonbit
let report = document.compile_paged(world)
let text = report.review_text()                // the words, in reading order
let selection = text.find("Knuth–Plass style optimizer,").unwrap()
let feedback = text.feedback(selection, "Tighten this sentence.")
println(feedback.to_text())
```

```
Review comment on "typst.mbt Showcase" (a document rendered from MoonBit source by typst.mbt)
Comment: Tighten this sentence.
Selected text: "Knuth–Plass style optimizer," (page 1)
Source 1 of 1: doc/twins/bench.mbt:202:7-215:18, Prose(..), parameter 1
  rendered: "Knuth–Plass style optimizer,"
  3 pieces of this argument are selected; they share this location, which is the argument as a whole.
Locations are constructor calls and their arguments in the MoonBit source (line:column, columns in code points), not positions inside a string.
```

- **Words.** The text of the document is cut into words: glyphs of one
  text item that follow each other, belong to one piece, and have no
  white space between them. A *piece* is text with one span: lowering
  gives every run of a `Prose` and every string of an array a span of its
  own (D 12.2), so pieces are told apart although they share an origin,
  the argument. The layer of the preview page has one box per word, with
  the number of the word.
- **Selecting.** In the page, dragging with a mouse selects the words
  from where the button went down to the pointer; a click selects one
  word, a shape or an image; "Extend" (or shift) and a second click
  select up to that word, which is how a range is selected on a touch
  screen, where a finger scrolls. In the library, `ReviewText::find(text,
  nth?)` selects the words that an occurrence of a text touches and
  `ReviewText::range(from, to)` a range of word numbers.
- **Feedback.** `ReviewText::feedback(selection, comment)` is the record:
  the comment, the selected text as rendered, the pages, and the origins
  of the selection, each once, in reading order. Per origin it has the
  text that was rendered from it (`…` where words of another origin lie
  between) and the selected text of each piece. `to_text()` is a block
  that explains itself when pasted into a message; `to_json()` is the
  same as data (the format is documented at `Feedback::to_json`).
  `origin_feedback(origin, page, comment)` is the record for a shape or
  an image.
- **The panel** shows the selection, one card per origin (location,
  constructor and parameter, range, data key, rendered text), a comment
  box, "Copy feedback", "Copy JSON" and "Add to list"; under the pages is
  the list of comments with "Copy all". When several pieces of one
  argument are selected, the card says so in plain words: they share one
  location, which is the argument as a whole.
- `doc/examples/review`: `feedback <name> <text> [comment] [--nth n]
  [--json]` prints the record for an occurrence of a text.

### What it guarantees

1. **One rule, applied twice, compared.** The page builds the record in
   its script, the library in MoonBit, from the same words. The page
   carries the library's records for a set of selections;
   `node scripts/review_page_check.mjs preview.html` and the page's
   `#selftest` check that the script builds the same records and texts.
2. **Origins are complete and ordered.** Every word of the selection
   contributes its origin; an origin appears once, at its first word.
   Pieces are never merged across spans: two strings of an array are two
   pieces even if they touch.
3. **Still call provenance only.** A record names constructor calls and
   arguments, and quotes rendered text. It does not say where in a
   string literal a piece is; the rendered text of the piece is what the
   author searches for. (Slice 3 adds source characters where they can
   be established.)
4. **Nothing else changes.** The export still only reads the compiled
   document. Copying uses the clipboard when the page may; when it may
   not, the text is put into a text area and selected, and the page says
   so. The list of comments lives in the page; `localStorage` keeps it
   across reloads where the browser allows it and is not relied on.

### Known limits of this slice

- Reading order is the order in which the engine placed the text items:
  what a range covers across columns, floats, footnotes and table cells
  follows that order, not the eye. Right-to-left text is in reading
  order inside a text item; the items of a line are in visual order.
- A word that the engine hyphenates at a line break is two words that
  touch: selected together they read as the written word, without the
  hyphen. A written hyphen at a line break stays, and a space follows it.
- The gap between two words has an origin (a click on it is answered by
  `origin_at`) but is nothing to select: a click on it changes nothing.
- Text without a source location (list markers, numbers, supplements) is
  not selectable and is left out of the selected text.
- Beyond 65,535 bytes of one text item the text of a word is not known
  (glyph ranges are stored in 16 bits): it is shown as `…`, with its
  right origin.
- Text that a clip hides completely is still among the words (a group
  that draws nothing because of a scale of zero is not).
- A cluster that the engine splits over two text items (a mark set in
  another font or at another height) appears in both, so its characters
  are twice in the selected text. The origins are right.
- A selection is one range of words, or one shape or image. Dragging
  starts and ends on words; there is no rectangle selection.
- `find` matches rendered text exactly (case, punctuation, the typeset
  quotes); white space stands for any gap between words.
- The page shows a parameter by its position, as in slice 1.

### Tests

- `doc/review_test.mbt`: words and their order; a written word of two
  origins; ranges and `find` (parts of words, occurrences, no match, an
  empty document, a long repetitive needle); Unicode white space; text
  through a box in a line; text in a group scaled to zero; a text item
  of 80,000 bytes from two strings; the runs of a `Prose` and the strings of an array as
  pieces of one origin, with a gap; a `Keyed` data key; a word
  hyphenated at a line break; the text block and the JSON of a record,
  exactly; a shape; a long selection; the page's data and controls.
- `doc/examples/review/review_wbtest.mbt`, on the showcase: words of a
  prose block (one origin, three pieces), a selection from a heading into
  its paragraph (two origins in order, at the source positions found by
  searching the file), cells of the table built in a loop.
- `node scripts/review_page_check.mjs` on the showcase's page: 36
  records equal the library's. In a browser: `#selftest` (the same, plus
  3,072 points of hit testing, twice, and a check that nothing covers a
  page and no effect is on a page, its artwork or its layer), a drag
  over two lines, "Extend" at phone width, both themes, the copy
  fallback, the list of comments.
- By hand, at a small viewport: scroll to every page and see that it
  paints. (Captures of a browser pane that is not shown are unreliable
  after the first frame: a second capture of the same scroll position
  can be blank although the page is fine. Judge by a visible pane.)

## Slice 3: source excerpts and source characters

### What it does

```moonbit
let text = report.review_text(sources=@system.sources())
let feedback = text.feedback(text.find("Knuth–Plass style optimizer,").unwrap(), "Tighten.")
```

```
Source 1 of 1: doc/twins/bench.mbt:202:7-215:18, Prose(..), parameter 1
  rendered: "Knuth–Plass style optimizer,"
  source characters: 202:36-202:64
   202 |       $|Typst lays out text with a Knuth–Plass style optimizer, OpenType shaping and
       |                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

and, where the argument is a variable:

```
Source 1 of 1: doc/twins/bench.mbt:178:14-178:22, Text(..), parameter 1
  rendered: "the Typst typesetting engine"
  note: the argument is the variable `subtitle`: the text comes from a binding, not from a literal at this location
   178 |         Text(subtitle, size=Pt(13)),
       |              ^^^^^^^^
```

- **A source provider** is a function `(file, module) -> String?` that
  gives the text of a MoonBit source file; `@system.sources(root?)`
  reads the files below the module root. `review_text` and `review_html`
  take it as `sources`. Without it nothing is read and everything stays
  as in slice 2.
- **Excerpts.** Every origin of a record has the lines of its source:
  the lines of the source characters if it has them, the lines of the
  location (argument or call) otherwise; at most six, with the number of
  lines left out. The text block marks the characters (or a location
  that is on one line) with `^`; the panel shows the same excerpt with
  the same marks.
- **Tiers.** Each origin has a tier, shown in the panel and in the
  record: **3, source characters** — the runs of characters of the
  source that spell the selected text; **2, the argument** as a whole;
  **1, the call**. For tiers 1 and 2 a sentence says why it is not
  narrower (`why`).
- **What is embedded.** The page is made with the sources at hand:
  the source characters of every word that has them, the tier and the
  sentence of every origin, and the source lines of every location
  are data of the page. The page reads no file and asks no server.

### When source characters are given

The argument at the origin's location is read from the source
(`doc/review_source.mbt`): a string literal, a multi-line string
(`#|`, `$|`), or an array whose elements are such literals. Its
characters are taken with their line and column — escapes decoded,
interpolations `\{..}` and elements that are no literal skipped.

Then one comparison decides (`ReviewText::match_literal`): **all the text
that the origin has on the page, in reading order, must be the literal's
text, one or more times over, character by character.** White space is
not compared (the page breaks lines, `Prose` reflows), nor are soft
hyphens and directional formatting characters; a typographic quotation
mark equals the plain one of the source. If the comparison holds, a
character on the page is the character at the same position of the
literal, and its line and column are known. If it does not hold, no
source character is given for that origin: tier 2, with the reason.

What that gives:

| The argument | Result |
|---|---|
| a string literal, an array of them, a `Prose` block, shown as written (also twice: a heading and its outline entry; also hyphenated, with typeset quotes, across pages) | tier 3 |
| a variable | tier 2: "the argument is the variable `name`: the text comes from a binding, not from a literal at this location". The binding is not followed |
| a call, an operator, anything else | tier 2: "an expression, not a literal" |
| a literal with an interpolation that adds text, or an array with a computed string | tier 2: the literal is not all of the text |
| a literal whose text the engine changes (case, a show rule), draws in another order (right-to-left items of a line), or shows only in part (hidden, clipped away, scaled to zero) | tier 2: the literal is not the text on the page |
| no argument: `Markup`, `Equation`, `Raw`, a shape, an image | tier 1: the call |
| no provider, a file it does not have, a file without that location | tier 2 (or 1), no excerpt |

### What it guarantees

1. **A source character is only given after the comparison above.** The
   record never points into a literal because an offset says so; it
   points there because the whole text of the origin on the page is that
   literal's text.
2. **The excerpt is the source at the location**, read when the record
   (or the page) is made. If the file changed since the document was
   compiled, the comparison fails for the literals that changed and the
   excerpt shows the new text at the old location; nothing checks that
   the file is the one that was compiled.
3. **The page and the library agree**, as in slice 2: the page's script
   only joins runs of selected words and picks excerpt lines; the sample
   records embedded in the page are compared by
   `scripts/review_page_check.mjs` and `#selftest`.
4. **Reading sources is opt-in and changes nothing else**: no provider,
   no file access. `@system.sources` reads the files that the source
   locations name, below its root; it takes only plain relative names
   (no absolute path, drive, `..` or backslash) and follows links inside
   the root like any other file.

### Known limits of this slice

- The comparison is about the origin's whole text. One changed word (a
  show rule that replaces it), one hidden part, or one text item of a
  line in another order takes the source characters away from the whole
  argument, not only from the selection.
- The comparison is by text, not by identity: if equal stretches of text
  are drawn in exchanged places (a rule that reorders them), a selected
  stretch is mapped to the source characters at its *position*, which
  spell the same text.
- A string that is used at two places of the source has two origins;
  each is compared with its own text.
- Text of `Markup` and `Equation` is the call (tier 1), not a position
  in the source string; raw text likewise. (A later slice.)
- A parameter is still shown by its position; a `Keyed` data key is
  shown, not used to find the row in the source.
- `$|` lines with a backslash that starts no interpolation, and escapes
  other than `\n \r \t \b \\ \" \' \u{..} \uXXXX`, are not read: tier 2
  ("an expression").
- The excerpt shows at most six lines and does not shorten long lines.
- The reader follows brackets 64 levels deep; an argument nested deeper
  is "an expression".

### Tests

- `doc/review_source_wbtest.mbt`: the reader — strings, escapes,
  interpolations, multi-line strings, arrays with other elements,
  parentheses and comments, bindings, expressions, what it refuses.
- `doc/review_test.mbt`: a provider in memory (asked once per file; the
  runs, the excerpt, the marks, the page's data); a file with another
  text at the location; a file that is too short; no provider.
- `doc/examples/review/review_wbtest.mbt`, with the sources read from
  disk: documents written in the test file itself (a literal, escapes,
  an array with a call between its strings, a `Prose` block over two
  lines with an interpolation and quotes, a heading with its outline
  entry; a variable, an expression, an interpolated string, text in
  upper case, hidden and scaled-away content, `Markup`); the expected
  places are found by searching the file. On the showcase: words of a
  prose block at the position found by searching `bench.mbt`, a
  hyphenated word, the `subtitle` variable.
- On the showcase's page: 36 of 78 origins are tier 3 (301 of 762 words
  have source characters), 36 are calls, 5 are variables or
  expressions, 1 is right-to-left text; `node
  scripts/review_page_check.mjs` and `#selftest` pass.

## Appendix: later slices (not under review)

What follows is the design of the whole loop as it stood when the work
was cut into slices (its tenth revision, after nine reviews of the plan
as a whole). It describes more than slice 1 builds and is kept as the
source for the sections of the later slices: selections and feedback
records, the recording of runtime texts (`compile_review`), source
literals and the verification of text offsets, containers, positions.
The reviews it cites (`docs/edsl-reviews/review-loop-plan-*.md`) are with
that work and come with the slices they concern. Nothing in this
appendix is a claim about the code of slice 1.

## The review loop of the MoonBit EDSL (design, revision 10)

Status: revision 10. Revisions 1 to 7 and 9 were reviewed in
`docs/edsl-reviews/review-loop-plan-1.md` to `review-loop-plan-7.md` and
`review-loop-plan-9.md` (REQUEST CHANGES; 12, 8, 5, 3, 2, 2, 2 and 3
findings); sections 11 to 17 and 19 map each finding to its resolution.
Revision 8 resolved review 7; before it was reviewed, the EDSL itself
changed under it (D 12.2, "pieces": everything without a location of its
own now has a span of its own in every compilation), and revision 9
rebuilt section 3 on that: what was a compilation mode with other spans
is now a **recording** that changes no span (section 18). This document designs
phase 3's "preview provenance" of `docs/edsl-design.md` (section 18: region
queries, container fallback, review-comment packaging) and the IDE
adaptation that its section 12.3 announces. "D 12.2" refers to a section
of `docs/edsl-design.md`.

The loop: an AI writes a document as MoonBit code; a human reads the
rendered pages, **selects a region and writes a comment**; the comment
reaches the AI **with the MoonBit source location that produced the
region**, so the AI edits the right code without searching.

Settled by the project owner and kept: documents are MoonBit code; every
constructor records its call site with `#callsite(autofill(loc, args_loc))`;
provenance has the three tiers of D 12.1; plain strings are literal text and
running text is `( $|... ) |> Prose`.

### 1. What exists, and what the frames tell us

Measured on `full_showcase()` (`doc/twins/bench.mbt`, 4 pages, 113 origins):

- every glyph keeps `span` and `span_offset` (`library/text_item.mbt`); a
  shape and an image keep a span; `Origins::resolve` turns a span of the
  session's virtual files into an `Origin` (D 12.3);
- the text of a constructor argument resolves to the call **and the
  argument** (`Heading("Text and paragraphs")`: `Heading, argument 1`);
  several strings of one array argument share that argument's location,
  and so do all text runs of one `Prose` (D 4.4, "Origins"), but each
  has a **span of its own**: a *piece* of the argument (D 12.2; a
  sub-range of the argument's token in the origin listing, which
  resolves to the same origin and argument);
- glyphs of `Markup`/`Equation` resolve to the call plus the byte range of
  the syntax node in the source string (`plus.minus`: bytes 8..18);
- glyphs made inside a `Context` callback resolve to the constructor calls
  inside the callback;
- **detached** spans occur for what the engine generates: the spaces of
  `Prose`, list markers, enum numbers, footnote numbers, the supplement
  `Table 1:`, operators from the math scope (`cos`, `dif`), page fills;
- frames contain the engine's introspection tags (`FrameItem::Tag`) around
  what a locatable element produced, and `GroupItem::parent` names the
  logical parent of content that was laid out elsewhere (placed floats,
  footnote entries, the later parts of a cell that breaks across pages;
  `pdf/tags_build.mbt` documents the three cases).

How the engine produces a glyph's `(span, span_offset)` — every place was
read, because the tier rules of section 5 rest on it:

- `collect_inline` (`layout/inline_collect.mbt`) appends each child's text
  to the paragraph text and records `(length, child.span())`. A text
  element contributes an optional directional embedding character, its
  text after optional case mapping, and an optional pop character.
  Adjacent text with equal styles is merged into one shaping segment
  **regardless of its span**.
- shaping (`layout/inline_shaping.mbt`, `ShapedText::build`) gives every
  glyph the span of the child that contains the **start** of its cluster
  and, as offset, the distance from that child's start (0 if above
  65,535), plus the `span-offset` style of raw text, saturated to 16 bits.
  `range_start`/`range_end` (the cluster's bytes in the item text) are
  saturated to 16 bits as well.
- a text or regex show rule (`realize/realize.mbt`) replaces a text
  element by **slices** of it (`slice_textual`) that keep the element's
  span; a slice's offsets start at zero again. A match that spans several
  elements becomes a fresh text element with the span of the first.

- line building adds a hyphen at a break inside a word
  (`ShapedText::hyphen`): a glyph with the span and offset of the break,
  whose text is a soft hyphen or a hyphen;
- shaping drops newlines, tabs and default-ignorable characters
  (`shape_segment`), so they have no glyph;
- frame construction splits the glyphs of one shaped run by font, size
  and vertical offset into several text items; a base letter and its
  combining mark can land in two items that both carry the cluster's
  text and range;
- math lays out glyphs on its own (`layout/math_text.mbt`,
  `GlyphFragment::with_span`): every glyph of a math item gets the item's
  span and **offset 0**;
- the engine makes text elements of its own and gives them the span of
  the **element that makes them**: the lines and highlighted pieces of
  raw text that is given as a string (`library/text_raw.mbt`, with
  offsets that restart in every line), the title of an outline, the
  entries of a bibliography, the text of a symbol, numbers of headings
  and equations. In the EDSL that element's span is the span of a
  constructor **call**. (Raw text written in markup keeps the
  evaluator's lines: each line has the span of its syntax node, and its
  highlighted pieces count their offsets from the start of the line.)

So in running text a glyph's offset is `true offset − p + e`, where
`p ≥ 0` is the start of the slice the glyph is in (0 without slicing) and
`e ≥ 0` the length of an embedding prefix, and the text may be
case-mapped; a cluster can start in one text element and end in the next.
Slicing and embedding can combine (review 2, finding 1: two slices of
`"€€"`, one of them embedded, exchange their offsets). In math an offset
says nothing.

Language facts verified with moon 0.1.20260920 and used below:

1. Line and column of `SourceLoc` are one-based and count Unicode code
   points. The file is relative to the module root, the module follows `@`.
2. An argument's range covers the value only (not `label=`, not enclosing
   parentheses).
3. For `x |> F` the call's range is the identifier `F`; the argument's
   range is `x` (for a multi-line string: from the first `$|`/`#|` to the
   end of the last line).
4. A multi-line string uses one prefix for all lines; `#|` is raw, `$|`
   interpolates `\{..}`; other escapes in `$|` are deprecated.

### 2. Decisions

1. **The visual layer is the exporter's SVG, unchanged; provenance is a
   second layer.** The preview shows each page as the string
   `@svg.svg(page, options)` returns and puts an invisible interaction
   layer over it, built from the review map. No exporter or engine code
   changes; the exporter draws text as outlines, which cannot be selected
   anyway.
2. **Fine provenance is an opt-in recording that changes no span.**
   Spans are observable: content fingerprints include them
   (`library/value_hash.mbt`), realization derives element locations from
   those fingerprints (`realize/realize.mbt`), locators and memo keys
   follow. The runs of a `Prose` and the strings of an array have
   distinct spans in every compilation (D 12.2); what a span does not
   say is *which* piece it is and what text it was given.
   `Document::compile_review` lowers exactly like
   `Document::compile_paged` — the same spans, the same content, the
   same listing — and **records** that beside the lowering (section 3).
   That the two are equal is stated and checked (section 3.5).
3. **One model, two consumers.** A `ReviewMap` is built once from the
   paged document, the report's `Origins` and an optional source provider.
   The library reads it; the page embeds it as data, with the geometry it
   needs, and applies the same rules. The page computes no provenance of
   its own.
4. **An offset is a candidate until it is verified, and verification is
   only attempted where the transformations are known** (section 5.3).
   The recording has, as side data that no span depends on, the runtime
   text of every text node that is lowered, and whether the document can
   contain text show rules at all. A cluster's offset is *verified* only
   in a document without text show rules, outside math, and if the
   clusters of its node reproduce the recorded text and tile it; tier 3
   additionally needs the source literal to decode to the same text.
   Everywhere else the output says "hint" and reports the coarser exact
   thing (the argument, the syntax node).
5. **Engine code is not changed.** Everything is in `doc`, `doc/system`
   and `doc/examples`, plus one faithful addition to the `kurbo` port
   (`PathSeg::winding`, `BezPath::winding`/`contains`), which upstream's
   `Curve::contains` needs.

### 3. Recording

```moonbit
pub fn Document::compile_review(self : Document, world : &@library.World)
  -> CompileReport[@layout.PagedDocument]
```

It lowers like `compile_paged` and fills side tables of the session while
it does (`Registry::recording`). The tables are keyed by span; nothing
reads them during the compilation.

#### 3.1 Pieces, and which piece a span is

Lowering gives everything without a location of its own inside an
argument a span from one counter per argument (D 12.2, `Pieces` in
`doc/lower.mbt`): the plain strings and values of a sequence, the runs,
quotes and paragraph breaks of a `Prose`, the arguments that share a
location, the arguments of call values. The k-th span is the sub-range of
the argument's token that ends `k` bytes before its end; when the token
is used up, the sub-ranges of the same token in a *further occurrence* of
the origin (a listing line under a key that starts with U+FDD2, which no
`Keyed` key can). All of them resolve to the same origin and parameter:
`Origins` drops those keys, and the review map takes the origin's own
entry for an occurrence (`Registry::origin_entry`).

The number `k` counts lowering order — a value with nested arguments
takes several, a located child none — so it is not the position of a
string in its array. The recording notes that position when it is known:

- for a child of `Seq([..])`/`Document([..])` that is a plain string: its
  position among the children (`PIndex`);
- for an argument that is a plain string: its position among the
  arguments of the same parameter (the elements of a variadic array);
- for a run of a `Prose`: where it is in the text (3.2).

`Origin` gets `index : Int?` and `run : ProseRun?` from that record.

**A span can be given out again, so a record must be complete.** The
counter of an argument starts anew whenever the node that has the
argument is lowered: in another layout iteration, for a description that
is used in two places, and for a call site that is run again with other
children (a function that builds a `Seq`, called twice; a callback). The
same lowering gives the same record; another one may give the span to
another piece, or to something that is no piece of the array at all (a
displayed string value takes a span of the counter like a string does).
Therefore:

- every use of a span for a text element is counted
  (`Registry::note_text`), and so is every note of its piece
  (`note_piece`) and of its follower (`note_follow`, 3.4);
- a span has an index or a run only if **every** text element that was
  lowered with it noted one — the counts are equal — and all notes agree
  (review 9, finding 1: `Seq([first, "a"])` run with a string value as
  `first` and with a `Lit`: the first span of the argument is the value
  once and the literal at index 1 once; one use has no note, so the span
  has no index, and section 4 finds no literal for it). The same rule
  holds for followers; a text that disagrees takes the runtime text away
  (3.4). The snapshot keeps only the records that hold
  (`Registry::freeze`).

The runtime text of such a span can still be verified (both uses have the
same text); only the source literal is not claimed.

**Pieces under `Keyed`.** A plain string or value inside `Keyed(key, ..)`
is a piece of the enclosing argument *under the key*: it takes the next
number of the argument's counter, and so does everything inside it, and
the number is turned into a span of the argument's token (or of the
call's line) in the origin's occurrence under the key (`Lower::keyed`:
the counter with `Registry::keyed_span` of its base as base). The
invariant: **all pieces under one key path come from one counter and one
base**, and `piece_span` is one-to-one for a base whatever its length
(the block is `k / length`, the shortening `k % length`) — a listing line
is longer under a key than without it, which is why the numbers, not the
sub-ranges, are carried over (review 9, finding 2: carrying the block and
the shortening of a piece of the unkeyed line into the keyed line lets a
later number of the keyed line land on it). The pieces without the key
are spans of another listing line. So the cells of one row that are
keyed with the row's key are distinct pieces — in every compilation: this
is the one change to normal lowering that the review loop makes (before
it, all plain strings of an argument under one key had one span, which
also made two equal ones a single element for the engine, the case D 12.2
removes everywhere else). It is covered by the differential gates, the
`edsl` stage and tests of the rollover (the 160 pieces of 80 keyed call
values in the scope of one `Markup`, whose line has fewer bytes; 300
strings of one array under two nested keys).

#### 3.2 The runs of `Prose`

`Prose` splits its text into runs at white space, quotes and placeholders
(D 4.4). A run is a private node `NRun(text, hole, offset)`: the number of
placeholders before it, and the number of code points between the end of
the last of them (or the start of the text) and the run. `Prose` also
keeps its **chunks**: the texts between its placeholders, in order.
`Debug`, the structural dump and the lowered content are unchanged: a
run lowers exactly like the plain string it was, with the piece span the
string would get.

When recording, the session interns the chunk list of each `Prose` it
lowers (`prose id`) and notes `(prose id, hole, offset)` for the span of
each run (`PRun`).

Correspondence with the source literal is established by two conditions,
not by counting (section 4 accepts a literal for a `Prose` only if both
hold):

1. **no character of the literal can become part of a placeholder**: the
   literal contains neither of the two delimiter characters, and no chunk
   that lies between two interpolations is non-empty and made of ASCII
   digits only. (A placeholder is delimiter, digits, delimiter. The
   literal has no delimiter, so a placeholder that swallows literal
   characters starts in one interpolation and ends in a later one, and
   swallows every literal chunk between them whole — which must then be
   digits. Review 2, finding 2, builds exactly this: `"\{left}1\{right}"`
   with `left` ending in an opening delimiter and `right` being a closing
   one; the chunk `1` between two interpolations is refused.)
2. **all chunks are equal**: the literal's chunks (the decoded texts
   between its `\{..}`) equal the runtime chunks, one by one.

Then the text of the runtime string consists of the literal's characters
(none was swallowed, by 1) plus whatever text the interpolations added;
its length equals the literal's (by 2); so the interpolations added no
text, every character of the runtime text is a character of the literal,
in order, and `(hole, offset)` is a position in the literal. A string
hole (which adds text), a string that smuggles a placeholder in together
with text (`let s = "\{Raw("x")}foo "; Prose("\{s}foo")`: runtime chunks
`["", "foo foo"]`, literal chunks `["", "foo"]`), and a `Show`
implementation that writes several placeholders fail condition 2 and
leave the `Prose` at tier 2.

#### 3.3 The record of a span

```
pieces  : Map[Span, PieceKind?]   PIndex(k) | PRun(prose id, hole, offset);
                                  None: the notes of the span disagree
texts   : Map[Span, text]         3.4
follows : Map[Span, Span]         3.4
text_uses, piece_uses, follow_uses : Map[Span, Int]     3.1
```

`mark_long_text` marks the origin's entry, also for a piece in a further
occurrence. The snapshot (`Origins`) copies the tables and, per entry,
the entry of its origin, so an old report resolves as before after later
compilations. A report of `compile_paged` has no tables: `index` and
`run` are `None`, no text is known, and every mapping is a hint (tiers 1
and 2).

#### 3.4 Side tables

The recording has, per span that is given to a text element (plain
strings, `Lit`, runs, displayed string values):

- its **runtime text** (`Map[Span, text]`). A span has a text only if
  the session used it for nothing but text elements with that one text.
  It is marked **uncontrolled**, for good, as soon as the session uses
  it in any other way: with a second, different text (a callback that
  builds different strings at one site), as the span of a call
  (`Func::call` gives it to the element or value that the function
  makes, and that element's own text inherits it: one `Call(path, ..)`
  site that is `str` in one use and `raw` in another; review 7, finding
  2; also a call in a value position, whose span is the span of the
  argument it is passed in), as the span of a callback (the engine calls
  the function with it, and a recipe gives its span to content without
  one), of a set or show rule, of a snippet's result, or of a displayed
  value that is not a string (`Registry::note_unknown`; the mark is
  never taken back, in whatever order the uses come, and a span that is
  given out again for another piece — 3.1 — falls under the same rule:
  another text, or another use, takes its text away). What remains
  controlled are the spans that only text elements of the session carry:
  the pieces of arguments (and of a call's line, for arguments without a
  location) that are plain strings, runs or string values, and the line
  of a `Lit`;
- its **follower**: the span of the text element that is its next sibling
  in the lowered sequence — recorded every time the span is lowered in a
  sequence, also when it has no such sibling. A span whose lowerings
  disagree (two different followers, or a follower once and none another
  time: a description that is used in two places) is *ambiguous* and has
  no follower (5.2); and so is a span that was also given to a text
  element whose follower was not noted (a string argument, a displayed
  string value): the record must be complete (3.1).

And one flag: whether the document **can contain text show rules**. A
text or regex show rule reaches the engine only as a recipe, and a recipe
is made in two places: by the session, when it lowers a
`Show`/`ShowSet`; and by the Typst evaluator, when it evaluates source.
Source is evaluated at exactly these entries (an audit of the engine:
the two calls of the `eval_string` routine in `library/`, and what the
session calls itself):

1. the session's snippets (`Lower::eval`);
2. the library function `eval` (`library/eval_funcs.mbt`);
3. **math in bibliography data**: a field of a bibliography entry that
   contains `$..$` is evaluated in math mode when the bibliography is
   shown (`show_math`, `library/bibliography.mbt`);
4. files that evaluated source imports or includes, and closures that it
   defines — reachable only from 1 to 3.

The flag is set by

- a show rule lowered by the session whose selector contains a regular
  expression anywhere (text selectors are regular expressions);
- a snippet — `Markup` **or `Equation`** — that is not **inert**, or
  whose scope contains anything but plain data (a function, a global, a
  call result, under any name). Inert is a positive property of the
  snippet's syntax tree, which the session parses with the engine's
  parser: every node is of a kind on a fixed list of kinds that evaluate
  no code. The list has the markup kinds (text, spaces, breaks, escapes,
  shorthands, smart quotes, strong, emphasis, raw, links, labels,
  references, headings, list, enumeration and term items, comments,
  content blocks of a reference), the math kinds (text, shorthands,
  alignment points, delimiters, attachments, primes, fractions, roots,
  strings, arguments with their names) and punctuation; and three kinds
  with a condition:
  - a math identifier, and the root of a math field access or math call,
    must be a name of the **library's math module** (`sqrt`, `mat`,
    `plus`, `theta`, ...) that is not itself a module, or a name of the
    snippet's scope. The math
    module has symbols and math functions; nothing in it evaluates
    source or looks up other functions. A name of the global scope
    (`eval`, `dictionary`, `std`, `lower`, ...) is not accepted, so a
    function can be neither named nor computed;
  - `#name` (a hash and one identifier, nothing applied to it) is
    accepted: it inserts a value and calls nothing;
  - an equation inside markup is accepted if its math is.

  Everything else — any other code after `#`, a function call, a field
  access, a code block, a keyword (`let`, `show`, `import`, `include`,
  `context`), a snippet in code mode — makes the snippet not inert. This
  replaces a search for forbidden words, which cannot see a function
  that is looked up by a computed name (`dictionary(std).at("e" +
  "val")`: review 5, finding 1);
- any use of the library's `eval` function: a `Call`, `Value::call` or
  `Set` that resolves to it, and a `Value::global` that names it (the
  native function is identified itself, not by the path that reached
  it); and any **module passed as a value** (a `Value::global` whose
  path ends at a module such as `std`): a function can be looked up in
  a module by a computed name (`dictionary(std).at(..)`), and the
  session cannot call a computed function itself — it calls by path —
  but a library function that is given one can;
- bibliography data that can contain math: a `.bib`, `.yml` or `.yaml`
  file (the extension in any case, as the engine reads it) with a `$`
  **or a backslash** that the engine loads through the
  session's world (the session wraps the world, so it sees every file
  the engine reads; these are the extensions from which the engine
  accepts a bibliography), and a bibliography whose sources are not
  given as path strings (bytes, whose content the session does not
  inspect). Math is a `$` in a decoded field; in the file a `$` is
  either written as such or produced by the decoder from an escape, and
  both decoders (YAML double-quoted scalars: `\x24`, `\u0024`; BibLaTeX
  commands) spell escapes with a backslash (review 7, finding 1). A file
  with neither character has no math field, so nothing of it is
  evaluated.

Math snippets are treated like markup snippets: content made inside an
equation can be taken out of it again (a query for the equation and its
`body` field, re-emitted by a callback: review 4, finding 1), so a recipe
in an equation is a recipe in the document. The flag is conservative: it
is about the whole document, not about where a rule applies. With the
flag clear, the Typst evaluator has run only on inert snippets, the
library's `eval` was never reachable from the session, and the session
lowered no regex rule: no recipe with a regular expression exists.

A second flag, **dynamic**, is set by anything that can replace or
rearrange lowered siblings before they are shaped: any show rule that
the session lowers (also one that selects elements: `text.where(text:
"i")` replaces a text element by other content), any callback (a host
function can re-emit the parts of what it is given), and everything that
sets the first flag. It gates the attribution of 5.2 only.

No span, no listing line and no lowered value depends on these tables.

#### 3.5 Recording changes nothing, and the check

No span, no listing line and no lowered value depends on the tables, and
no code path of lowering branches on `recording` except to write them
(the test of a snippet's inertness, 3.4, parses the snippet a second
time and has no effect on the session). So a recording compilation and a
normal one are the same compilation. This is checked, not assumed:

- tests: for a document with headings, `Prose`, lists, a context
  callback with a query, a figure with a table, a footnote and an
  equation, the origin listing, the span of every glyph, the SVG of every
  page and the PDF bytes are equal for `compile_review` and
  `compile_paged`; for the showcase the pages are equal
  (`CompileReport::same_pages`);
- `doc/examples/review` compiles the document both ways and refuses to
  write a preview whose pages differ from the normal compilation (the
  preview would not show what `pdf()` exports); the page states that the
  check passed;
- the differential stages and the `edsl` stage (34 cases: equal
  structure, layout, SVG and PDF bytes with their Typst twins) are
  unchanged.

#### 3.6 `Origin`

```moonbit
pub struct Origin {
  ...                       // as before
  call : SourceRange        // the constructor call itself
  extent : SourceRange      // the call and all its arguments (for `x |> F` the
                            // call is the identifier only)
  index : Int?              // 3.1 (recorded)
  run : ProseRun?           // 3.2: { prose, hole, offset } (recorded)
}
pub struct SourceRange { start_line; start_column; end_line; end_column : Int }
```

Snippet origins keep `param = None` as today; the snippet now records
which parameter its source string is.

### 4. The source side: literals

A **source provider** is a function `(file, module_name) -> String?`
(`doc` does no OS access; `@system.sources(root?)` reads `<root>/<file>`).
Without it there are no excerpts and no tier 3; everything else works.

`doc` contains a small reader for the argument text that an `ArgsLoc`
range delimits. It recognises exactly: a string literal `"..."` with the
escapes `\n \r \t \b \\ \" \'`, `\xHH`, `\o000`, `\uXXXX`, `\u{X..}` and
interpolations `\{expr}`; a multi-line string (`#|` raw; `$|` with
interpolations only — any other backslash makes it unreadable, fact 4);
an array literal (top-level elements; a spread element makes the
elements after it unaddressable); surrounding white space, comments and
parentheses. Everything else is "not a literal". A literal that was read
is its **chunks** (the decoded texts between interpolations) with the
source position of every decoded character.

| Origin | Literal | Accepted if |
|---|---|---|
| content argument with `index = k` | the argument if it is a string literal and `k = 0`; element `k` of an array literal | one chunk, equal to the node's recorded runtime text |
| `Prose` text with `run` | the argument | the two conditions of 3.2 hold for its chunks and the recorded chunks of that `Prose` |
| `Lit(s)` | the call's first argument | one chunk, equal to the runtime text |
| `Markup`/`Equation` | the source argument | one chunk, equal to the snippet text in `Origins` |

A literal is thus never used on the strength of its position alone: its
decoded text must be the text the engine was given.

### 5. The review map

```moonbit
pub fn CompileReport::review(
  self : CompileReport[@layout.PagedDocument],
  sources? : (String, String) -> String?,
) -> ReviewMap raise DocError            // the report's errors if it has no output
```

It works on any report; without the recording there are no runtime
texts, so nothing is verified (tiers 1 and 2-as-hint).

#### 5.1 Items, clusters, the text stream

The map walks every page frame once, in paint order, and records
**items**: one per frame text item, shape and image, numbered over the
document, with the map to page coordinates, the chain of clips above it
(each in the coordinates in which upstream tests it: before the group's
own transform) and a page bounding box.

A text item's glyph ranges are validated first: every range must be
non-empty, inside the item text, on character boundaries, and below the
16-bit saturation value. An item that fails (a single unbroken item of
more than 65,535 bytes) is kept as **one opaque cluster** with the item's
text and the origins of its glyphs at tier 1; nothing finer is derived
from saturated numbers. Otherwise its **clusters** are the maximal groups
of consecutive glyphs with one text range, each with its text, advance
and mapping.

**Split clusters.** Frame construction splits the glyphs of one shaped
cluster over several text items where their vertical offset changes (a
base letter and a raised mark; `ShapedText::build`). The parts carry the
same span, offset and text — and so does a second occurrence of the same
text that follows the first at another baseline. Glyphs, advances,
positions and candidate offsets do not tell the two apart (review 4,
finding 3; review 5, finding 2; review 6, finding 2), and the engine
keeps no cluster identity. The map therefore does not merge: a text item
that *continues* the text item directly before it in the same frame —
same font and size, another baseline, and its first cluster has the span,
offset and text of the other's last cluster — keeps its cluster as a
cluster of its own. Such a cluster is marked: its node is **not
verified**, and the mapping says that the text may be listed twice
because the engine either split a cluster or drew the same text twice.
No text is ever dropped from the stream.

The **text stream** is the one logical order used by search, selection
and feedback: items in paint order; within an item the clusters by text
range (so a right-to-left item reads logically); between two text items
no separator if the second continues the first (it starts where the first
ends on the same baseline, or the first ends in a soft hyphen), otherwise
a space. Searches and `selected_text` collapse white space and drop soft
hyphens. A position of the normalized stream maps back to its cluster.
Limit: in a right-to-left *paragraph* the items of a line are painted in
visual order, so the stream follows visual order across items there.

#### 5.2 Mapping

Let `span` be a glyph's span (a shape's, an image's).

1. **Direct**: `Origins::resolve(span)` is an origin.
   - listing span (text): the candidate range is `o = span_offset`,
     `n` = the cluster's bytes; no candidate if the entry is marked
     `long_text`;
   - snippet span: the syntax node's byte range `a..b` in the source
     string is exact. If the node is `Text` or `MathText`, the candidate
     cluster range is `a + o .. a + o + n` (upstream `jump_from_click`).
2. **Container**: a detached span, or a span of a file outside the
   session (content of a Typst file that a `Markup` imported; the note
   names the file). The mapping is the innermost enclosing element whose
   span has an origin. "Enclosing" is logical, as in the PDF tag tree
   (`pdf/tags_build.mbt`): the walk keeps the stack of open tags; a group
   with `GroupItem::parent` is visited with the stack replaced by that
   parent followed by **the elements that were still open when the
   previous fragment of the same parent ended** (kept per parent, so an
   element that starts in the first part of a broken cell and ends in the
   second is still the innermost one there); afterwards the physical
   stack is restored. Above a parent the chain continues with the element
   that was open around its start tag, recorded in a first pass over all
   pages. White-space clusters without a mapping of their own stay
   unmapped.
3. Otherwise unmapped (a page fill).

**Clusters across text elements.** A glyph has one span, that of the
element in which its cluster starts; a ligature or combining sequence
across two descriptions therefore names only the first. A cluster of
one character belongs to one element. For a cluster of **several
characters** the map must establish where all of them come from, and says
so when it cannot:

- the node is verified (5.3): the cluster lies inside the node's text;
- or the cluster is *attributed*: the document is **not dynamic** (3.4:
  no show rule of any kind, no callback, no evaluated source that could
  bring one — so the lowered sequence is what is shaped, sibling next to
  sibling), the conditions (b) and (c) of 5.3 hold, every other cluster
  of the node passes the check, the cluster starts inside the node's text
  `T` and its text continues past the end of `T`, and the node has an
  unambiguous follower (3.4) whose text starts with the rest (repeatedly,
  for a rest longer than the follower). The mapping then lists the
  followers after the node. A matching prefix alone never establishes a
  contributor (review 4, finding 2: an element show rule replaces the
  follower by other content that shapes to the same character);
- **otherwise the mapping states that the glyph may include characters
  of neighbouring content whose origin is not recorded** — whether or
  not the cluster's text happens to equal the text at its candidate
  range (a slice `"f"` of `"fiXf"` joined with a following `"i"` equals
  the start of the original text: review 3, finding 2).

Nodes involved in an attribution are unverified.

#### 5.3 Verification and tiers

Verification is attempted for a node only if all of the following hold;
otherwise its offsets stay hints:

- **(0) the document was compiled with the recording.** A clear flag
  means "nothing that can make a text show rule was found" only if it
  was looked for: the test of a snippet's inertness runs in a recording
  compilation (3.4). A report of `compile_paged` verifies nothing and
  reports no source characters — also not for a snippet, whose text is
  known from its source (review 9, finding 3: the swapped euro signs of
  review 2 as a `Markup` literal, mapped from a normal report).
- **(a) the document cannot contain text show rules** (the flag of 3.4 is
  clear). Then no text element is ever sliced or replaced by a match:
  every text element that reaches paragraph collection with the node's
  span is the element that was lowered, with its whole text.
- **(b) none of the node's clusters is inside an equation** (an open
  `math.equation` element in the logical stack): math sets offsets to 0.
- **(c) the node's text `T` is known and its span is controlled** (3.4):
  a recorded runtime text of a span that the session used for nothing
  else or, for a `Text` node of a markup snippet that is not a line of
  raw text, the snippet text `a..b` (a syntax node's span belongs to
  that node; a raw line is laid out from highlighted pieces, with tabs
  replaced, so it maps as a whole and has no `T`). Text that the
  engine makes has the span of a call (section 1), and a call's span is
  never controlled: raw text, counter displays, outline titles and
  bibliography entries have no `T`, whatever else was lowered at the
  same site.

Let the node's clusters be all clusters in the document with its span.
The node is **verified** if

1. every cluster's candidate range lies in `T` on character boundaries
   and `T[o .. o+n]` equals the cluster's text — except a cluster that
   fails and whose text is a soft hyphen (U+00AD): the hyphen that the
   line breaker adds at the end of a line. It is made with that text and
   the offset of the break (`ShapedText::hyphen`), maps to no character
   and is left out of 2. (A soft hyphen of the text itself has its own
   offset and passes.) And
2. there is `k ≥ 1` such that every character of `T` that is neither
   white space nor a soft hyphen is covered by exactly `k` clusters, and
   no character by more.

*Claim.* For a verified node, each cluster's candidate range is its true
range in `T`. *Argument.* By (c) the only text elements with the node's
span are the ones the session lowered with the text `T` (the engine puts
an argument's span on the wrappers it builds around the argument — a
cell, a caption, an item — but gives the text it generates the span of a
call or none); by (a) none of them is sliced. So the span reaches
collection only on whole occurrences of the element with the text `T`,
and no slice start is subtracted.
What remains of section 1, per occurrence: the same embedding prefix
`e ∈ {0, 3}` on every offset; case mapping; and the fact that an
occurrence renders each character of `T` in exactly one cluster, except
white space trimmed at a line end and the characters that shaping drops
(the same in every occurrence), and except characters drawn by a cluster
of a neighbouring element. Call a character *significant* if it is
neither white space nor a soft hyphen, and let `c` be the last
significant character of `T`. By 2, `c` is covered, so shaping keeps it
and no neighbour draws it; hence every occurrence that has clusters has
one that truly is on `c`. In an occurrence with `e = 3` that cluster
claims a range behind `c`, where `T` has only white space and soft
hyphens or ends; its text contains `c`, so it fails 1, and it is not the
hyphen exception (its text is not a soft hyphen). So every occurrence
has `e = 0`, and every candidate range is the true range; 1 then only
confirms that case mapping changed nothing in the selected clusters. The
other behaviours make a node unverified, never wrongly verified: dropped
characters and characters drawn by a neighbouring cluster leave 2
unsatisfied; zeroed offsets pile up on the first characters and violate
2; a cluster that reaches into the next element fails 1; a split cluster
counts twice and violates 2 (and is marked, 5.1).

The claim rests on (a): it is the session's own knowledge of what it
lowered, plus the textual test of snippets. Section 9 lists what this
excludes.

| Tier | Reported | Condition |
|---|---|---|
A mapping has a tier and a **precision**; they are separate statements:

| Tier | Reported | Condition |
|---|---|---|
| 1 `call` | file, call range, argument range, constructor, keys | every mapping (containers: `via: "container"`) |
| 2 `text` | + a byte range of the runtime text (of the source string, for snippets) | text: a candidate range exists; snippets: always (the syntax node) |
| 3 `source` | + source characters (range and text) | a literal was accepted (section 4), and for text the node is verified |

| Precision | Meaning | Where |
|---|---|---|
| `cluster` | the range is that of the selected glyph clusters, verified | text and snippet text nodes that are verified |
| `node` | the range is the whole syntax node of the source string, which the span identifies exactly; no position inside it is claimed | snippets: nodes that are not text, and text nodes that are not verified (equations; documents with text show rules) |
| `hint` | the range is the engine's offset, unverified | text nodes that are not verified |

So tier 3 is either source characters of the selected clusters
(`cluster`) or the source characters of a whole syntax node of a literal
`Markup`/`Equation` argument (`node`); tier 3 never has precision
`hint`. Tier 2 can have each. The feedback record carries the precision
per piece (`verified` is `precision == "cluster"`), and the page words
it: "source characters, verified", "source characters of the whole
syntax node", "text range, verified", "range of the syntax node",
"text range, hint".

A selection reports, per piece (6.2), the lowest tier and the weakest
precision of its clusters.

### 6. Selections and feedback

#### 6.1 Selections

```moonbit
pub(all) struct Pick { item : Int; start : Int; end : Int }  // clusters start..end (logical order) of a text item; 0..0 for a shape or image
pub struct Selection { picks : Array[Pick] }

pub fn ReviewMap::select_point(self, page : Int, x : Double, y : Double, word? : Bool = false) -> Selection?
pub fn ReviewMap::select_rect(self, page : Int, x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> Selection
pub fn ReviewMap::select_text(self, needle : String, nth? : Int = 0) -> Selection?
pub fn ReviewMap::select_range(self, from : Selection, to : Selection) -> Selection
pub fn ReviewMap::select_picks(self, picks : Array[Pick]) -> Selection
```

Coordinates are points on the page from its top left; pages start at 1.
`select_picks` normalizes: picks of items that do not exist are dropped;
a cluster range is clamped to the item's clusters and dropped if it is
then empty or reversed (`start >= end`); for a shape or image the range
is ignored; picks are sorted by item and start, and overlapping or
adjacent picks of one item are merged. Every `Selection` is in this
form. Functions that take coordinates return nothing for a page that
does not exist and for coordinates that are not finite; `select_rect`
orders its corners; `select_range` accepts its two selections in either
order. A DOM range is half-open: the page converts it to picks by the
character offsets, so a selection that ends at offset 0 of a cluster
does not include that cluster, and one that starts at a cluster's end
does not either.
`select_point` is the click search of section 7 without the link step,
where items without a mapping are transparent; with `word` the cluster is
extended to the neighbouring non-space clusters of its item.
`select_rect` takes the clusters whose box centre is inside the rectangle
and the shapes and images whose bounding box lies inside it.
`select_text` finds the `nth` occurrence of `needle` in the normalized
stream. `select_range` is everything of the stream from the first
cluster of one selection to the last of the other (what the page's
"extend" does).

#### 6.2 Packaging (library and page apply the same rule)

1. `selected_text`: the picked clusters in stream order with the
   stream's separators, normalized.
2. Each picked cluster, shape and image contributes its mappings (one,
   or several for a cluster across elements). Unmapped white space is
   skipped. Mappings are grouped by **origin** — entry, parameter and
   `via` — in order of first appearance; within an origin by **piece**:
   the node (one span: one string of an array, one run of a `Prose`, one
   syntax node of a snippet). Unmapped picks form a last origin "no
   source location".
3. A piece carries its identity (`index`, or the run, or the snippet
   node's range), the rendered text of its picked clusters, its tier,
   the byte ranges in **its own** text (merged; never merged across
   pieces), the node text when verified, the source ranges with their
   text at tier 3, and the page boxes of the picked clusters (merged per
   line).
4. An origin carries the lines to edit and the excerpt: the lines of its
   pieces' source ranges if all are tier 3, else the lines of the
   argument, else of the call's extent; at most 12 lines (the first 8,
   an ellipsis, the last 3); only with a source provider.

```moonbit
pub struct Feedback {
  format : String                  // "typst-mbt-review/1"
  document : String                // the document's title
  snapshot : String                // a hash of the origin listing and of the source files read
  comment : String
  selected_text : String
  pages : Array[Int]
  origins : Array[FeedbackOrigin]
}
pub struct FeedbackOrigin {
  file : String; module_name : String
  constructor : String
  param : Int?; param_name : String?
  call : SourceRange; argument : SourceRange?
  keys : Array[String]
  via : String                    // "text" | "markup" | "shape" | "image" | "container" | "none"
  tier : Int                      // the lowest tier of its pieces; 0 for "none"
  pieces : Array[FeedbackPiece]
  edit_lines : (Int, Int)
  excerpt : Array[(Int, String)]
  note : String                   // why the tier is what it is
}
pub struct FeedbackPiece {
  index : Int?; run : ProseRun?; node_range : (Int, Int)?
  rendered_text : String
  tier : Int
  precision : String              // "cluster" | "node" | "hint" | "" (tier 1)
  verified : Bool                 // precision == "cluster"
  node_text : String?
  text_ranges : Array[(Int, Int)]
  source_ranges : Array[(SourceRange, String)]
  regions : Array[Region]         // { page, x, y, width, height }
}
pub fn ReviewMap::feedback(self, selection : Selection, comment : String) -> Feedback
pub fn Feedback::to_json(self) -> String
pub fn Feedback::to_text(self) -> String
pub fn edit_targets(feedback_json : String, sources? : (String, String) -> String?) -> String raise
```

`to_text` is the block a reviewer pastes into a chat, written to be
understood without this document:

```
Review comment on "typst.mbt Showcase" (rendered from MoonBit source)
Comment: say "optimiser" here
Selected text: "Knuth–Plass style optimizer," (page 1)
Source 1 of 1: doc/twins/bench.mbt:202:36-202:64, text of Prose(..)
  mapping: source characters, verified (the literal equals the text the
  engine was given, and the rendered glyphs reproduce it)
  202 |       $|Typst lays out text with a Knuth–Plass style optimizer, OpenType shaping and
      |                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

`edit_targets` changes nothing: for each origin of a feedback JSON it
prints `file:first-last` and, with a provider, the current lines; if they
differ from the excerpt it says that the source changed since the
preview was made (the excerpt and `snapshot` identify the version).

### 7. Reverse lookups

**Click** (`jump_from_click`). A port of upstream
`jump_from_click_in_frame` (`crates/typst-ide/src/jump.rs`) on a mirror of
the frame tree: links first, then the items in reverse paint order; a
group tests its clip at the click in the group's own position (before
inverting the transform) and skips a singular transform; a glyph is hit
in the box `advance × size` above its baseline; a shape by fill
(rectangle, or `Curve::contains` with the shape's fill rule; a line has
no fill) and by stroke (`stroke_contains`: kurbo's stroke expansion with
the stroke's cap, join, miter limit and dashes at tolerance 0.01, then
non-zero containment); an image by its box. Upstream needs a parsed Typst
source (`source.find(span)`) to produce a byte offset; the port returns
the hit cluster, which the map resolves (D 12.3 announced this). Kept
from upstream: the half-advance rule (`after`), and that a glyph without
a mapping does not stop the search.

```moonbit
pub(all) enum Jump {
  Source(Selection, after~ : Bool)
  Url(String)
  Position(page~ : Int, x~ : Double, y~ : Double)
}
pub fn ReviewMap::jump_from_click(self, page : Int, x : Double, y : Double) -> Jump?
```

**Cursor** (`jump_from_cursor`).

```moonbit
pub fn ReviewMap::positions(self, file : String, line : Int, column? : Int,
  module_name? : String, keys? : Array[String]) -> Array[Region]
```

With a column inside tier-3 source characters: the clusters of those
characters (upstream's text-node case). Otherwise the picked parts of the
items whose direct origin is the innermost range (argument, else call
extent) around the position, restricted to a module and to a `Keyed`
occurrence if given. Upstream returns one point per page; boxes are
returned because the page outlines them.

### 8. The preview page

`ReviewMap::html(title? : String, standalone? : Bool = true) -> String`.

- **Pages.** One `<section>` per page: the exporter's SVG inline, and an
  empty layer `<div>` over it.
- **Data.** One `<script type="application/json">` (with `<` escaped):
  files and the source lines that origins refer to; origins; nodes
  (origin, piece identity, verified, node text); per item its page, map,
  clip chain and geometry (a text item: its text and per cluster the
  UTF-16 length, position, advance, node, candidate range and tier-3
  source position, run-length encoded; a shape: its path, fill rule,
  whether it is filled, its stroke style; an image: its size), the
  stream separators, and **probes**: a sample of points and text ranges
  with the library's answers.
- **Text layer.** The script builds, per page when it comes into view,
  one absolutely positioned HTML `<span>` per cluster from the data
  (position and advance from the frames, in units of the page width;
  transparent text). HTML spans, not SVG text: selection across elements
  and pages is the browser's ordinary text selection, as in PDF viewers.
  Spans are in stream order, so the order of a selection is the stream's.
- **Selecting.** (a) Native text selection: the range's first and last
  selected cluster spans (half-open, 6.1) give `select_range`. (b) A
  click or tap: the script's **own hit test** on the embedded geometry,
  the same search as section 7: clips before transforms, glyph boxes,
  and for shapes the **same winding computation as the library** — a
  port of kurbo's `PathSeg::winding` (lines and cubics, without implicit
  closing of open paths) on the shape's path, and for strokes on the
  **stroke outline that the library computed** with kurbo and serialized
  into the page. The page does not use the canvas for containment (its
  rules differ: it closes open paths). It selects the word or object. (c) "Extend": the next tap
  extends the selection to that word along the stream (for touch
  devices). The current selection is kept by the script and drawn as
  boxes, so it stays visible while the comment box has the focus.
- **Parity.** With `#selftest` in the address the page runs its hit test
  and its packaging on the probes and reports any difference from the
  library's answers; `scripts/review_page_check.mjs` runs the packaging
  half in node. The canvas half needs a browser and is run there.
- **Panel.** Selected text; per origin: location, constructor, parameter,
  key, the tier in words ("source characters, verified", "call and
  argument, with a text range (verified | hint)", "call and argument",
  "enclosing element"), the excerpt with the range marked; a comment box;
  `Copy` (the text block), `Copy JSON`, `Add to list`. Choosing an origin
  or a list entry outlines its regions.
- **Comment list.** In the page; kept in `localStorage` as a convenience
  (every access in `try/catch`); `Copy all`.
- **Copying.** `navigator.clipboard.writeText` in the click handler; on
  rejection the text is selected in a read-only text area with the hint
  to copy it by hand. The text area with the current block is always
  there, so the path needs no permission.
- **Constraints.** Self-contained (inline CSS and JS; images are the data
  URIs the exporter writes); colours are tokens on `:root` with dark
  values under `prefers-color-scheme` (guarded by
  `:root:not([data-theme="light"])`) and under
  `:root[data-theme="dark"]`; the paper stays white; at phone width the
  pages scale to the column and the panel is a bottom sheet, 16px
  gutters, no horizontal scrolling; no `alert`/`confirm`/`prompt`, no
  printing, no downloads. `standalone=false` omits doctype, `html`,
  `head` and `body` for hosts that wrap the page.

### 9. Limits, stated in the output

| Case | Result |
|---|---|
| a report without the recording (`compile_paged`) | tiers 1 and 2 (hint) only |
| text longer than 65,535 bytes; an item longer than 65,535 bytes | tier 1 |
| a document with a text or regex show rule anywhere, or with `Markup` that contains `show`, `import`, `include` or `eval` | no text offset is verified in the whole document: tier 2 as a hint; snippets keep their exact syntax nodes (tier 3 at node granularity when the argument is a literal) |
| text inside an equation | the syntax node (or the call), never a position inside it |
| engine-shifted offsets (embedding, case mapping) | not verified: tier 2 as a hint, never tier 3 |
| ligatures, combining sequences | the cluster's whole range; across two descriptions: both origins where 5.2 can attribute them; every cluster of several characters that is neither verified nor attributed carries the statement that it may include neighbouring content |
| a description used in two places, in front of different text | its follower is ambiguous: no attribution, the statement above |
| `Call("eval", ..)`, `Value::global("eval")`, a function in a snippet's scope, a `Markup` or `Equation` source with any code beyond `#name` or with a math name outside the math module, a bibliography file with a `$` or a backslash, a bibliography from bytes | counted as possible text show rules: no text offset is verified in the document |
| engine content with spans that the session did not give it: content of another compilation embedded as an engine value, or content that a callback builds with the engine's API and a span of its own choosing | outside the contract: the session answers for the spans it hands out in one compilation. (Whole text elements made this way cannot pass the checks with another text; only text sliced by hand with a kept span could, and no description does that) |
| a document with any show rule or callback | a ligature across two descriptions is not attributed; the glyph carries the statement that it may include neighbouring content |
| a cluster that the engine split over two text items (a letter with a raised combining mark, as in many scripts); the same text twice in a row at different baselines | kept as two clusters: the text is listed once per part, the mapping says so, and the node is not verified (tier 2 as a hint) |
| a module passed as a value (`Value::global("std")`) | counted as possible text show rules (a function can be looked up in it) |
| a variable, a call, concatenation, an interpolated string outside `Prose` | tier 2 (verified when the runtime text is known), with the node text |
| `Prose` whose literal chunks differ from its runtime chunks, or whose literal has a digit-only chunk between two interpolations | tier 2 |
| `Raw` text, `Lorem` and other string results of calls, counter displays, anything else at a call site | tier 1 or 2 as a hint (the text is not a text element that the session lowered; a call's span is never controlled) |
| `Markup`/`Equation` | the syntax node exactly; inside a text node the cluster range when verified; tier 3 when the argument is a literal |
| numbers, markers, supplements, math-scope operators, content of imported Typst files | tier 1, `via: "container"` |
| page fill | no source location |
| right-to-left paragraphs | stream order across the items of a line is visual |
| HTML and bundle targets | not covered: the map is built from paged frames |

### 10. Deliverables and tests

- `doc/origin.mbt`, `doc/lower.mbt`, `doc/session.mbt`, `doc/compile.mbt`,
  `doc/prose.mbt`, `doc/content.mbt`, `doc/debug.mbt`: section 3.
- `doc/review_source.mbt` (4), `doc/review_map.mbt` (5),
  `doc/review_select.mbt`, `doc/review_jump.mbt` (6.1, 7),
  `doc/review_feedback.mbt` (6.2), `doc/review_html.mbt`,
  `doc/review_page.mbt` (8).
- `kurbo/winding.mbt`: `PathSeg::winding`, `BezPath::winding`,
  `BezPath::contains` (kurbo 0.13.1).
- `doc/system`: `sources(root?)`.
- `doc/twins/bench.mbt`: `full_showcase()` is unchanged (same
  descriptions, same spans); `review_showcase()` is the same document
  with the rows of the stage table and of the computed table wrapped in
  `Keyed`, for the preview. A test checks that both have the same pages
  (SVG).
- `doc/examples/review`: `preview [name] [-o file] [--fragment]`,
  `feedback <name> (--find text [--nth n] | --at page,x,y) --comment c
  [--json]`, `targets feedback.json`, `positions <name> file:line[:col]`;
  `preview_document(build, ..)` takes any `() -> Document`.
- Tests (`doc`, in-memory world unless noted):
  - the literal reader;
  - recording: 3.5; the pieces of a sequence, of a `Prose` and under
    `Keyed` with their index or run; 900 elements of one array (the
    token's sub-ranges run out: further occurrences, one origin, every
    index); an old report still resolves after another compilation;
  - tiers: a literal, an array element, `Prose` (also with a string hole
    and with the smuggled placeholder of 3.2), a variable, escapes, long
    text, a long unbroken item, right-to-left text in a left-to-right
    paragraph, a hyphenated word, the show-rule counterexamples of
    review 1 (`"abcXabc"` with `X` removed; `Markup("#show \"x\":
    none\nabxcd")`) and of review 2 (the two exchanged euro signs; the
    swallowed digit chunk; `Lit("xf")`, `Lit("i")` with `x` removed), a
    ligature across `Seq([Lit("f"), Lit("i")])`, a combining mark in a
    second text item with and without tracking (both parts listed, the
    notice, not verified), and of review 3 (the euro example through
    `Call("eval", ..)`; `Lit("fiXf")`, `Lit("i")` with `fiX` removed: the
    notice; one `Lit("f")` in two sequences: no attribution), and of
    review 4 (the hidden equation whose body a query re-emits; the
    replaced follower under `lower`; stacked marks, tracked marks and the
    same text at two baselines), and of review 5 (the computed lookup of
    `eval` in a snippet; `0` followed by a raised slashed `0`: two
    clusters, both in the stream, not verified); inert and non-inert
    snippets (math with names of the math module, `#name`, a call, a
    keyword, a global name in math); and of review 6 (a bibliography
    whose data has `$`: nothing verified, and one without: verified;
    `aaaa` followed by the same text embedded right-to-left at another
    baseline: eight letters in the stream; a module passed as a
    value), and of review 7 (a bibliography whose `$` is written as a
    YAML escape; one `Call` site used as `str` and, hidden, as `raw`:
    the visible text is not verified); a line of raw text in markup (the
    line's node, not a position in it);
  - containers: markers, a cell broken across pages with an inner element
    that spans the break, a float, a footnote entry, content repeated in
    a header;
  - click: upstream's cases that need no Typst source (clip before
    transform, scale, rotation, shapes by fill and by stroke, links
    first, an open filled path that must not be hit inside its implicit
    closing), rectangle, text and range selection, the stream on
    mixed-script text, `select_picks` normalization and the boundary
    rules of 6.1;
  - cursor lookup with module and key; JSON round trip through
    `edit_targets`; a missing source file; the page (data present, no
    external reference, theme tokens).
  - `doc/examples/review` (native, `bench` as root, sources from the
    repository): the end-to-end table — a word inside a `Prose` block
    (tier 3), an interpolated `Raw(..)` inside prose (tier 1), a cell of
    the stage table under its `Keyed` row (tier 2 verified, key, node
    text), a heading (tier 3), a figure caption (tier 3), an equation
    (the syntax node, with the substring), the page header from the
    `Context` callback (tier 3 inside the callback), an image (tier 1,
    by coordinates). The expected lines and columns are computed in the
    test by searching the source file, independently of the map.
- Browser checks (the Browser pane; results in the report): selection
  within a line, across lines, across pages; tap and extend at phone
  width; `#selftest` parity; both themes; copying.
- Gates: all differential stages unchanged, `moon test`, `moon check` on
  native, wasm-gc and wasm without new warnings.

### 11. Resolution of review 1

| Finding | Resolution |
|---|---|
| 1 equality is not proof (BLOCKER) | 2.4, 5.3: runtime texts are recorded; a range is a candidate until the node is verified by equality **and** tiling, with the argument for the engine's known transformations; the wording is "verified", with the checks named |
| 2 placeholder count (BLOCKER) | 3.2, 4: correspondence by equality of all chunks, which implies that interpolations added no text; the smuggled-placeholder example fails it |
| 3 snippet offsets (BLOCKER) | 5.2, 5.3: the syntax node's range is exact; the cluster range inside a text node is a candidate under the same verification; the snippet records its source parameter |
| 4 overflow (MAJOR) | 5.1 validates glyph ranges per item and keeps a saturated item opaque; snippet nodes fall under 5.3 (zeroed offsets fail tiling) |
| 5 clusters across elements (BLOCKER) | 3.4, 5.2: known text lengths detect them; the follower table attributes the rest; an unknown rest is stated |
| 6 registry changes are observable (BLOCKER) | 2.2, 3: fine spans are an opt-in compilation mode; normal mode is unchanged; 3.5 states and checks the contract |
| 7 logical parents (MAJOR) | 5.2: `GroupItem::parent` switches the stack to the parent's chain; foreign-file spans are container mappings that name the file |
| 8 selection across SVG text (MAJOR) | 8: an HTML text layer of spans, native selection across lines and pages, plus tap and extend; the selection is held by the script |
| 9 click parity and geometry (MAJOR) | 8: the page's own hit test on embedded geometry, clip before transform, canvas fill and stroke tests; probes compare it with the library |
| 10 piece identity in feedback (MAJOR) | 6.2: pieces under origins; ranges merge only within a piece; regions from picked clusters |
| 11 one text stream (MAJOR) | 5.1: defined once, used by search, selection and feedback; its limit in right-to-left paragraphs is stated |
| 12 API and tests (MINOR) | 6.1 normalization; 7 module and key; 6.2 format, document, snapshot; 10 coordinates for images, independent expectations, the counterexamples |

### 12. Resolution of review 2

| Finding | Resolution |
|---|---|
| 1 equality and tiling are not proof when slicing and embedding combine (BLOCKER) | 1 completes the inventory (hyphens, dropped characters, item splitting, math); 5.3 attempts verification only where slicing is impossible — the session knows every show rule it lowers and tests snippets textually (3.4) — and outside math; the argument is redone for that subset. With any text show rule the whole document stays at hints |
| 2 a placeholder can swallow literal characters (BLOCKER) | 3.2: the literal must contain no delimiter and no digit-only chunk between two interpolations; with that, chunk equality implies that interpolations added no text |
| 3 clusters across elements after slicing (MAJOR) | 5.2: follower attribution only under the conditions of 5.3 and when the node's other clusters pass; otherwise the mapping states that the glyph may include neighbouring content |
| 4 unfinished inner stacks of split parents (MAJOR) | 5.2: the open elements are kept per logical parent between its fragments, as in `pdf/tags_build.mbt`; test with an inner element that spans the break |
| 5 one cluster in two text items (MAJOR) | 5.1: fragments; text and coverage once, regions for both |
| 6 canvas containment differs from kurbo (MAJOR) | 8: the page ports kurbo's winding and uses stroke outlines computed by the library; no canvas containment; the open-path case is a test and a probe |
| 7 `Keyed` in the showcase changes normal-mode spans (MINOR) | 10: `full_showcase()` is unchanged; `review_showcase()` is the keyed variant; a test compares their normal exports |
| 8 selection boundaries (MINOR) | 6.1: reversed and empty ranges, non-finite coordinates, order of range ends, half-open DOM ranges |

### 13. Resolution of review 3

| Finding | Resolution |
|---|---|
| 1 `eval` and callable scope values bypass the flag (BLOCKER) | 3.4: the flag covers every way a recipe can be made — the session's own show rules, its snippets (words, and any scope value that is not plain data), and every use of the library's `eval` function, identified as the function itself |
| 2 a crossing cluster can equal the recorded substring (MAJOR) | 5.2: the notice no longer depends on a mismatch; every cluster of several characters that is neither verified nor attributed carries it |
| 3 one follower per span (MAJOR) | 3.4, 5.2: followers are recorded per lowering, including "none"; disagreeing lowerings make the span ambiguous, and an ambiguous span is never attributed |
| 4 fragments with tracking (MAJOR) | 5.1: the rule follows from how the engine splits items — same span, offset, text, font and size, different baseline, different glyphs; no use of advances; the residual ambiguity and its effect are stated |
| 5 tier 3 and snippet nodes (MINOR) | 5.3: tier and precision are separate; `cluster`, `node`, `hint`; the record carries the precision and the page words it |

### 14. Resolution of review 4

| Finding | Resolution |
|---|---|
| 1 content of an equation can leave it (BLOCKER) | 3.4: `Equation` snippets set the flag like `Markup` snippets (words and scope); only their own rendered clusters are excluded by 5.3 (b) |
| 2 a unique follower can be replaced before shaping (MAJOR) | 3.4, 5.2: attribution only in documents that are not dynamic — no show rule of any kind, no callback, no evaluated source that could bring one; otherwise the known origin and the notice |
| 3 stacked identical marks (MAJOR) | 5.1: fragments are reconstructed as chains; a continuation whose glyphs are those of the chain's beginning is ambiguous, counted as an occurrence and kept out of verification |

### 15. Resolution of review 5

| Finding | Resolution |
|---|---|
| 1 a computed lookup of `eval` in a snippet (BLOCKER) | 3.4: the word search is replaced by a positive property — a snippet is inert only if every node of its syntax tree is of a kind that evaluates no code, math names are names of the math module (or scope data), and the only code is `#name`; everything else sets the flag. With the flag clear the evaluator has run only on inert snippets |
| 2 different glyphs do not prove one cluster (MAJOR) | 5.1: glyphs are no longer evidence. A continuing cluster is a fragment only where the node's known whole text proves that a second occurrence could not follow directly; otherwise both clusters are kept, the node is not verified and the mapping says that the text may be listed twice |

### 16. Resolution of review 6

Revision 7 also withdraws the fragment rules of revisions 3 to 6 (the
rows about fragments in sections 12 to 15 describe what was tried).

| Finding | Resolution |
|---|---|
| 1 math in bibliography data is evaluated by the engine itself (BLOCKER) | 3.4: the entries at which source is evaluated are enumerated from the engine; bibliography data sets the flag if a file that can be a bibliography has a `$`, or if the sources are bytes. The session's world sees the files |
| 2 the fragment argument used unverified offsets (MAJOR) | 5.1: split clusters are no longer merged at all. The engine keeps no cluster identity, and every rule tried so far (advances, glyphs, the node's text) could be defeated; a continuing cluster is kept, counted and listed, its node is not verified, and the mapping says why. The hyphen exception of 5.3 is reduced to what the engine provably makes (a failing cluster whose text is a soft hyphen) |
| (found while revising) a function looked up in a module that is passed as a value | 3.4: a module as a value sets the flag |

### 17. Resolution of review 7

| Finding | Resolution |
|---|---|
| 1 a `$` written as an escape in bibliography data (BLOCKER) | 3.4: a bibliography file sets the flag if it has a `$` or a backslash, the character with which both decoders spell escapes |
| 2 a recorded text verifies engine-made text of another use of the span (BLOCKER) | 3.4, 5.3 (c): a span has a text only while the session uses it for nothing but text elements with that text; any use as the span of a call (also of a call in a value position), a callback, a rule, a snippet result or a displayed non-string value makes it uncontrolled for good (`Registry::note_unknown`). Section 1 lists the text that the engine makes and whose span it gets. The string result of a call is therefore a hint, too (`Call("str", ..)`, `Lorem`). Tests: the review's fixture, and a string result alone |

### 18. Revision 9: recording instead of a mode

While revision 8 was waiting for its review, the EDSL changed on the main
branch (D 12.2, "pieces"; raw text keeps the evaluator's lines). What
that does to this design:

| Before (revisions 1 to 8) | Now |
|---|---|
| normal mode: the strings of an array and the runs of a `Prose` share the argument's span; review mode gives them spans of its own making (sub-ranges that encode the index, piece lines in the listing) | every compilation gives them distinct spans (D 12.2). `compile_review` uses exactly those and records which piece each is (3.1, 3.3) |
| review mode changes spans, with a checked compatibility contract (element locations can differ) | recording changes nothing; listing, glyph spans, SVG and PDF are equal and tested equal (3.5) |
| a piece's index is a function of its span | a span can be given out again for another piece (a call site lowered with other children); records that disagree leave the span without index, run, text or follower (3.1, 3.4) |
| `Keyed` keeps the index in review mode | a piece stays a piece under `Keyed` in every compilation (3.1): one change to normal lowering, under the gates |
| raw text in markup has the span of the raw element | each line is a syntax node with a span; a line maps as a whole node (its range in the source string is exact), offsets inside it are not claimed (5.3 (c)) |

Review 8 was started on revision 8 and stopped when the basis changed;
there is no review-loop-plan-8 for that revision. Its subject (review 7's
findings) is unchanged in revision 9: section 17.

### 19. Resolution of review 9

| Finding | Resolution |
|---|---|
| 1 a span that is given to a text without a piece note inherits another lowering's index (BLOCKER) | 3.1, 3.3: observations are total. Every text element lowered with a span is counted, and so are the notes of its piece and of its follower; an index, a run or a follower holds only if the counts are equal and the notes agree. Tests: the review's fixture in both orders (the shared span has no index and no source characters, its runtime range stays verified; the other span is index 1) |
| 2 `Keyed` carries block and shortening into a longer line (MAJOR) | 3.1: a keyed body takes a number of the argument's counter, and the number is turned into a span of the base under the key; one counter and one base per key path, `piece_span` one-to-one for a base. `Registry::keyed_span` is the plain mapping of a token or line again. Tests: 160 pieces of keyed call values in a scope (more than the line has bytes), 300 strings under nested keys, each with its index |
| 3 a normal report verifies snippet text without the inertness test (BLOCKER) | 5.3 (0): the recording is a condition of verification, and a report without it has no source characters (snippets included). Tests: an inert `Markup` and the swapped-euro `Markup` of review 2, each from `compile_paged` and from `compile_review` |
