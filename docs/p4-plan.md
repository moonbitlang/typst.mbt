# P4 plan: fonts, shaping, paged layout and export

Goal: paged documents with frame-level parity against upstream (2168
`paged` suite cases), then SVG and PDF export. Drafted with Codex
(gpt-6-astra); upstream references are to the pinned revision.

I recommend making P4 **fonts + frame-level paged parity**, with SVG developed alongside it. Port rustybuzz faithfully in stages; a bespoke Latin shaper would become a second implementation to replace. Bring math into P4 rather than leaving it behind PDF.

Read-only review completed; no files modified. References below are to the pinned checkout.

**Use a frame dump as the primary differential contract.**

Compile through the existing convergence driver to `PagedDocument`, then dump the accepted document and diagnostics. Do not compare an intermediate layout iteration.

Add these oracle stages:

| Stage | Output and purpose |
|---|---|
| `font` | Font metadata, coverage, metrics, variation instances, MATH values, glyph bounds/outlines. Isolates parser faults. |
| `shape` | Input font/direction/script/language/features/text; output glyph IDs, UTF-8 clusters, integer advances/offsets, unsafe-to-break flags. Isolates shaping faults. |
| `break` | Bidi levels/runs, break opportunities, hyphenation points, chosen line ranges. Isolates paragraph faults. |
| `paged` | Final frame tree, page metadata, tags, links, diagnostics. Primary layout gate. |
| `svg` | Upstream SVG text, followed by port SVG comparison. |
| `pdf-semantic` | Extracted PDF structure, text, destinations, tags and metadata. Separate from byte hashes. |

The frame schema must preserve all six [`FrameItem` variants](.repos/typst/crates/typst-library/src/layout/frame.rs:486), including group hardness and logical parents. Flattening everything into drawing commands would lose gradient boundaries and introspection order.

Proposed exact format: **`typst-frame-v1`, canonical JSON arrays, one record per LF-terminated line**. Fixed record positions; no optional field omission; `null` for absent values. This is a schema, with symbolic field names:

```text
["header","typst-frame-v1",revision,font_manifest_sha256,test_name]
["diagnostics",existing_diagnostic_encoding]
["document",info,format_options,page_count]
["font",F,asset_sha256,face_index,variations,family,postscript_name,upem]
["image-resource",I,kind,asset_sha256,page_index,intrinsic_size,dpi,exif,icc_sha256,dependencies]
["content",C,canonical_content]
["page",P,logical_number,bleed,fill,numbering,supplement_C]
["frame",R,size,explicit_baseline_or_null,"soft|hard",item_count]
["group",R,index,position,child_R,transform,clip,label,parent]
["text",R,index,position,F,size,fill,stroke,lang,region,text,glyphs]
["shape",R,index,position,geometry,fill,fill_rule,stroke,span]
["image",R,index,position,I,size,alt,scaling,span]
["link",R,index,position,size,destination]
["tag-start",R,index,position,L,C,introspectable,tagged]
["tag-end",R,index,position,L,K,introspectable,tagged]
["end"]
```

Define the nested values precisely:

- **Numbers:** integer fields are decimal JSON integers; `f64` values are strings `f64:` followed by 16 lowercase IEEE-754 hex digits; `f32` uses eight. Encode `Abs::to_raw()` rather than converting to points; reports display `raw / 127`. Encode `Em::get()`, ratios and radians without rounding. Preserve signed zero in the raw dump.
- **Coordinates:** frame positions are local, x-right/y-down. Transform is `[sx,ky,kx,sy,tx,ty]`, meaning `x′=sx*x+kx*y+tx`, `y′=ky*x+sy*y+ty`.
- **Glyph:** `[id,x_advance,y_advance,x_offset,y_offset,byte_start,byte_end,span,span_offset]`. Advances/offsets are **em units, y-up**. Text includes whitespace and default-ignorable effects exactly. Upstream retains both vertical values and UTF-8 ranges in [`Glyph`](.repos/typst/crates/typst-library/src/text/item.rs:94).
- **Geometry:** `["line",point]`, `["rect",size]`, or `["curve",commands]`; commands are `["M",point]`, `["L",point]`, `["C",p1,p2,p3]`, `["Z"]`.
- **Stroke:** `[paint,thickness,cap,join,dash_or_null,miter_limit]`; dash is `[lengths,phase]`.
- **Paint:** tagged solid/linear/radial/conic/tiling. Preserve original color space/components, spot-color name/fallback/tint, ordered stops, interpolation space, relative mode and antialias flag. Gradients retain all geometric fields; tilings retain frame reference, size, spacing, offset, angle and relative mode.
- **Page:** preserve `auto` versus `none` versus explicit fill, bleed, numbering and supplement. `auto` resolves differently for PDF and SVG—see [`Page`](.repos/typst/crates/typst-layout/src/document.rs:98).
- **Identity:** assign `F/I/C/L/K` by deterministic first encounter; frame IDs are structural paths such as `p0/3/1`. Walk pages/items in stored order, recursively visiting groups and paint frames. Preserve repeated identity and references.
- **Spans:** repository-relative virtual file path, resolved byte range, detached marker; retain glyph span offset separately. No absolute paths or raw span intern numbers.
- **Content:** reuse the structural realization encoder, extending it where necessary; do not substitute `repr`. Preserve fields needed for counters, queries and tagging. Normalize location references consistently.

Keep raw location/key hashes in an **optional identity-debug sidecar**. Canonical IDs make layout comparison independent of Rust hashing, but do not validate locator/convergence correctness; retain separate introspection tests.

Comparison policy:

- Exact structure, ordering, glyph IDs/clusters, text, resource identities and diagnostics.
- Report **bit-exact** and **numeric-equivalent** counts separately. Start numeric tolerance at `1e-7 pt` for lengths and `1e-9` for dimensionless values; investigate exceptions individually.
- Retire PLAN.md’s blanket `0.01pt` layout tolerance: it is too loose around line/page break decisions.
- Never tolerate different line/page membership or missing tags.
- Store schema/revision/font/dependency manifests with goldens; regenerate deliberately.
- Audit the selection manifest first: my literal header count found **2,169** `paged` headers, versus the supplied 2,168 runnable cases. Record the collector/filter explanation.

**Font support needs the complete test world, with staged acceptance.**

[`oracle/src/world.rs:108`](oracle/src/world.rs:108) concatenates `typst-assets::fonts()` and `typst-dev-assets::fonts()` in that order. It does not scan system fonts.

I inspected the registered font files’ table directories:

| Source | Files | Outline/color inventory |
|---|---:|---|
| `typst-assets@94dcb99` | 17 | 13 CFF, 4 TrueType |
| `typst-dev-assets@e26d7ca` | 68 | 16 CFF, 48 TrueType, 3 CFF2, 1 bitmap-only |
| Combined | **85** | 7 variable fonts; CBDT/CBLC, COLR/CPAL and SVG color glyphs |

Bundled families: Libertinus Serif, New Computer Modern text/math, DejaVu Sans Mono.

Development families include:

- Arabic: Noto Sans Arabic; Hebrew: Noto Serif Hebrew.
- Devanagari: IBM Plex Sans Devanagari; Thai: Noto Sans Thai.
- CJK: Noto Serif CJK JP/KR/SC/TC.
- Math: Asana, Concrete, Garamond, IBM Plex, Libertinus, Noto Sans Math, Pennstander, STIX Two, XITS, TeX Gyre Bonum.
- Variable: Cantarell, Fraunces upright/italic, Mona Sans, Roboto Flex, Source Serif 4 upright/italic.
- Emoji: Noto CBDT, Noto COLR, Twitter SVG glyphs.

Freeze **every font’s bytes, face index and book order**, even while only some fonts are supported. A reduced font book changes fallback decisions.

| Component | Minimum useful slice | Required for suite closure |
|---|---|---|
| OpenType parser | Directory/TTC access; `head/maxp/cmap/hhea/hmtx/name/OS/2/post`; coverage and metrics | GDEF/GSUB/GPOS, legacy kern, CFF/CFF2, variations, MATH, color tables |
| Outlines | TrueType composites and CFF Type 2 bounds | Correct paths, subroutines, CID-keyed CFF; variable TrueType/CFF2 outlines |
| Font layer | `FontInfo`, exceptions, metrics, `FontBook`, exact selection/fallback | `FontInstance`, automatic/custom axes, color-glyph behavior |
| Shaper | Faithful buffer/normalization/feature planning/GSUB/GPOS pipeline | Arabic, Indic and remaining shapers; variation positioning and emoji clusters |
| `fontdb` | **No system discovery needed** | Small adapter for SVG-image font resolution; system discovery later |

Font selection is Typst’s own [`FontBook`](.repos/typst/crates/typst-library/src/text/font/book.rs:94), not a `fontdb` query. `fontdb` also appears in SVG image loading, so omit it from the initial engine without forgetting that later dependency.

Feature scope is substantially larger than `liga+kern`:

- Tests explicitly enable/disable `liga/clig`, `dlig`, `hlig`, `salt`, stylistic sets, `smcp/c2sc`, numeral styles/widths, `zero`, `frac`, and custom `cv02`; see [`inline/text.typ`](.repos/typst/tests/suite/layout/inline/text.typ:3).
- Preserve default `ccmp/locl`, contextual substitutions, Arabic joining/required ligatures, Indic reordering, GPOS pair/cursive/mark/mkmk behavior.
- **`kern` is ordinarily a GPOS feature or legacy kerning table, not a GSUB feature.**
- Math needs constants, italics corrections, accent attachments, math kerns, variants/assemblies, and GSUB features including `ssty`, `flac`, `dtls`.
- Feature names do not identify lookup coverage. Instrument the oracle to report executed GSUB/GPOS lookup types and selected script/language systems before declaring a subset complete.

Rust source sizing from the installed locked dependencies: **rustybuzz 0.20.1: 29,264 lines; ttf-parser 0.25.1: 23,196 lines**, including comments/generated tables. Rustybuzz is a HarfBuzz algorithm port, with reusable shape plans and cluster-aware buffers ([versioned documentation](https://docs.rs/rustybuzz/0.20.1/rustybuzz/)).

Recommendation: **faithful architecture, staged coverage**:

1. Common shaping pipeline plus static Latin/Greek/Cyrillic fonts.
2. Arabic/Hebrew, Devanagari, Thai, CJK and emoji.
3. Variable fonts and remaining observed lookup paths.

Generate normalization/property/state-machine tables where appropriate. Defer unexercised AAT/WASM paths explicitly. A cmap-only shaper is acceptable for scaffolding, never as the accepted paragraph implementation. Preserve fallback of whole clusters and `unsafe_to_break`; Typst uses these when reshaping line slices and assigning PDF `ActualText` ([shaping.rs:955](.repos/typst/crates/typst-layout/src/inline/shaping.rs:955)).

Unicode/text work should proceed independently:

- **Bidi:** port `unicode-bidi 0.3.18` behavior, or verify an existing MoonBit implementation against it. Test byte-indexed levels, isolates, brackets, line-end whitespace reset and visual run order.
- **Line opportunities:** match locked ICU behavior, not merely generic UAX #14. Upstream uses `new_lstm`, plus a custom Chinese/Japanese curly-quote segmenter ([linebreak.rs:37](.repos/typst/crates/typst-layout/src/inline/linebreak.rs:37)); the suite contains Thai segmentation.
- **Line selection:** faithfully port both greedy and optimized Knuth–Plass paths, costs, pruning, CJK adjustments, justification and boundary reshaping.
- **Hyphenation:** port hypher 0.1.8 with its exact patterns/language mapping and Typst’s surrounding restrictions.
- Extend existing `unicode/` generators for missing properties; retain UTF-8 indices throughout. Do not externally normalize text before passing it to the shaper.

**Sequence implementation around shared contracts, then independent ownership.**

Keep public runtime types in `library`; place the engine in `layout`, with upstream module/file names. Initially use files/subdirectories within that package where flow/grid/math/inline call each other. Splitting each into independent packages would create unnecessary cycles.

| Work unit | Ownership and dependencies | Completion gate |
|---|---|---|
| A. Contracts + oracle | One integrator: replace `Frame`/`LayoutRegion` placeholders; add `FrameItem`, `Regions`, `Fragment`, text/font interfaces; generator changes | Synthetic frames exercise every dump variant |
| B. OpenType/fonts | Generic `otf` package, library font adapters, test-world manifest | Metadata/metrics/bounds parity for all 85 files |
| C. Shaping | Dedicated `shape` package; consumes B | Exact glyph/cluster/position/flag goldens |
| D. Unicode/breaking | Generated tables, bidi, ICU-compatible opportunities, hypher | Exact bidi/break/hyphenation goldens |
| E. Primitive layout | `shapes`, `transforms`, `pad`, `stack`, `repeat`, `image`, modifiers | Non-text frame cases; child-layout callbacks |
| F. Inline | `inline/*`, about **4.7k Rust lines**; B/C/D/E | Paragraph frame parity, including reshaping |
| G. Flow/pages | `flow/*` **3.5k**, `pages/*` **0.7k**, document/introspector | Multipage flow, columns, placement, footnotes, convergence |
| H. Grid/table | `grid/*` **5.4k**, plus library `CellGrid` resolution | Spans, gutters, repeated rows, fragmentation, strokes |
| I. Math | `math/*` **3.9k**; existing math IR + B/C/MATH | Inline/display equations and stretch assemblies |
| J. Export | SVG first; independent office.mbt PDF enhancements | Exporter gates described below |

Suggested four-agent scheduling for implementation:

- Start: **A/oracle**, **B/parser**, **C/shaper scaffold**, **D/Unicode**.
- After contracts: integrator takes **E + minimal G**; font/shaping work continues.
- Once basic paragraphs work: **F**, **G**, **H**, **I** become separate owners.
- Assign SVG and PDF work as lanes free up; PDF need not delay frame parity.

Single-owner files: `Routines`, `World`, closed runtime variants, `typemap.py`, registration, runner and generated outputs. Regenerate after merges.

Critical path:

`contracts → font metrics/shaping → inline → flow/pages → paged introspection`

Grid and math join after the frame/font interfaces stabilize. **Do not postpone math:** the checkout has 403 `paged` headers under `math/`, and math also occurs elsewhere.

First vertical slice: test-world defaults → “Hello fi” → shaped paragraph → auto-height page → frame dump → SVG. Then fixed-height multipage text, contextual `measure/layout`, and queries/counters. Finish floats/footnotes/grid fragmentation after the ordinary flow path works.

**Add SVG early; make PDF parity semantic.**

SVG milestones:

1. Synthetic frames: paths, clipping, transforms and solid paints.
2. Static CFF/TrueType glyph outlines and text positioning.
3. Gradients/tilings, raster images, SVG images, color glyphs and variable outlines.
4. Connect `html.frame` and remaining HTML frame cases immediately.

Match the upstream harness: **pretty SVG, merged pages, 1pt gap** ([output.rs:417](.repos/typst/tests/src/output.rs:417)). Preserve its nine-decimal numeric rounding and Rust round semantics.

There are two SVG acceptance levels:

- **Canonical SVG parity:** consistently rename generated IDs and references; preserve geometry, paint, order and user labels.
- **Raw byte/hash parity:** also reproduce Rust hash inputs/encoding for fonts, instances, glyph keys, clips and paints. IDs contain `hash128` values ([svg/lib.rs:518](.repos/typst/crates/typst-svg/src/lib.rs:518)).

Do not call the first level upstream hash parity. Retain raw oracle SVG alongside canonical goldens.

Raster checks should initially compare **both SVGs through the same renderer**. Comparisons against upstream PNGs additionally require the harness’s page gaps/backgrounds and link overlays; those PNGs are not plain SVG rasterizations ([output.rs:601](.repos/typst/tests/src/output.rs:601)).

Use **pdflite plus a Typst-specific PDF adapter**, rather than porting all of krilla. The required backend surface is still substantial:

| Krilla functionality used by Typst | office.mbt enhancement |
|---|---|
| Positioned glyphs, cluster text, font instances | Glyph-ID drawing API with offsets, advances, text ranges, ToUnicode and cluster-level ActualText |
| TrueType/CFF/CFF2 and variable-font embedding | Glyph-driven subsetting; CFF CID conversion/subroutine handling; instantiate variable fonts into embeddable static subsets |
| Paths, clips, fills/strokes, transforms | Small retained graphics/resource interface |
| RGB/gray/CMYK, spot colors, ICC | Color-space resources, output intents, alpha/soft masks |
| Linear/radial/sweep gradients and tilings | Shadings/patterns, sampled color interpolation, transforms and transparency |
| Raster/SVG/PDF images, color glyphs | JPEG passthrough, PNG alpha/ICC, SVG painting, imported PDF forms, color-glyph resources |
| Links/outlines/page labels/attachments/metadata | Adapt existing facilities; preserve named destinations and transformed annotation geometry |
| Tagged PDF and validation | MCID allocation, StructTree/ParentTree, annotation OBJR, role/attribute maps, reading order, artifacts, language/alt text |

Keep Typst’s semantic tag construction in the port; generic PDF object construction belongs in office.mbt. Tagging is enabled by default upstream, so the eventual exporter must support it ([pdf/lib.rs:159](.repos/typst/crates/typst-pdf/src/lib.rs:159)).

Current office.mbt findings:

- The `entrySelector`/`rangeShift` bugs mentioned in PLAN.md are **already fixed** ([core:177](~/git/office.mbt/pdflite/pdf_truetype_core.mbt:177)).
- `recompute_head=true` already recomputes checksums; reuse it ([subset_font:232](~/git/office.mbt/pdflite/pdf_truetype_subset_font.mbt:232)).
- The public subset entry point remains codepoint-based. Add an entry point taking **actual shaped glyph IDs**, retaining composites and `.notdef`. After shaping, PDF subsets generally do not need GSUB/MATH tables.
- Structure-tree extraction/replacement already exists; audit and reuse it, while adding an export-oriented tagging builder.
- A PDF reader alone does not provide PDF-to-SVG interpretation or complete imported-page rendering.

PDF gates: structural validation → positioned text/extraction → visual comparison through one renderer → links/outlines/metadata → upstream `pdftags` formatted output → PDF/A/UA validation. **Do not require upstream PDF byte hashes from a pdflite backend**; compression, object numbering and subset serialization will differ.

**The principal risks are measurable.**

| Risk | Control |
|---|---|
| Floating-point branch drift | Preserve operation order and f32/f64 boundaries. `Abs` stores 127 raw units/pt; its epsilon is `1e-4` **raw units**, about `7.87e-7pt`. No layout quantization or fast-math. |
| CFF bounds/variation drift | Compare metrics, bounding boxes and outlines before diagnosing line/page layout. CFF is required even without rendering. |
| Font/hash instability | SHA-256 asset identity + face index + normalized variation coordinates; exact font-book order; separate semantic equality from Rust hash compatibility. |
| Mutable frame aliasing | Match upstream value/COW behavior when resizing, translating or appending shared frames. |
| Lost logical ordering | Preserve tags and `GroupItem.parent` through floats, repeated headers and fragmented cells. Reuse the existing two-layer convergence recording. |
| Native runtime cost | Release runner, shared font bytes, parsed-face/instance/shape-plan caches, paragraph reuse; benchmark p50/p95, glyph throughput and worst cases. Do not predict a speed ratio without measurement. |
| Memory growth | Byte views into immutable fonts, compact glyph arrays, bounded caches, release rejected iteration frames, stream per-case dumps. Avoid retaining the entire suite’s documents. |
| Full-suite dependency tail | Track bibliography, highlighting, image interpretation and other unsupported features separately. A layout percentage must not conceal their contribution. |

The immediate deliverable should be **the font manifest, versioned oracle schemas, and one real-font paragraph-to-page-to-SVG slice**. That establishes useful differential feedback before the large flow, grid and math ports begin.

## Status: work unit A (contracts + oracle)

**Oracle.** `scripts/goldens.sh fonts` writes `tests/golden/fonts.json`
(`typst-fonts-v1`: one object per face in book order — 85 faces from 85
files, no collections — with source, path, face index, SHA-256, size,
family, PostScript name, upem and variant; see `oracle/src/fonts.rs`).
`scripts/goldens.sh paged` dumps `tests/golden/paged/**` in
`typst-frame-v1`. The format is specified precisely (all nested encodings)
in the module docs of `oracle/src/paged.rs`; the MoonBit encoder
(`tests/runner/frame_dump.mbt`) mirrors it record by record and the runner
stage is `moon run tests/runner --target native -- paged`.

**Selection audit.** Upstream compiles a paged document when
`implied_stages().with_required()` contains `PAGED`: tests with a `paged`,
`pdf` or `pdftags` attribute in files not starting with `// SKIP`
(`tests/skip.txt` is empty). That is 2169 literal `paged` headers (none in
a skipped file, no duplicate names) plus 130 `pdf`/`pdftags`-only tests,
2299 in total, all of which the oracle dumps. The "2168" figure above could
not be reproduced from the collector; 2169 is the `paged` count.

**Runtime contracts** (`library`): `Frame` (copy-on-write: `Frame::clone`
shares items and the first mutation copies them, cloning nested group
frames; moved frames must not be reused), `FrameItem` (all six variants),
`GroupItem`, `FrameParent`/`Inherit`, `FrameKind`, `LayoutRegion`/`Regions`
(immutable; `next()` returns the advanced regions), `Fragment`, `Point`,
`Size` (= `Axes[Abs]`, methods on `Axes[Abs]`), `Rect`, `Transform`,
`Curve`/`CurveItem`, `Shape`/`Geometry`, `Image`/`ImageKind` with
`RasterImage`/`SvgImage`/`PdfImage` built from decoded metadata,
`TextItem`/`Glyph`/`TextItemView`, and `Font`/`FontInstance` backed by the
`FontFace`/`FontInstanceFace` trait objects that unit B implements
(`library/font.mbt`). The math IR's `TextItem`/`GroupItem` were renamed to
`MathTextItem`/`MathGroupItem`. `PagedDocument` and `Page` live in the new
`layout` package (`layout/document.mbt`); `layout_document` is a stub that
fails until unit G lands, and `PagedDocument::new` uses an empty
introspector until `PagedIntrospector` is ported.

**Known gaps.** Kurbo-based bounding boxes (`Curve::bbox`,
`Geometry::bbox`) are not ported; the HTML frame traversals
(`discover_frame`, `traverse_frame`) are still TODOs. (Tilings now carry
their laid-out frame, see units E + G.)

## Status: work units E (primitive layout) + G (flow/pages)

**Layout package** (`layout/`, files named after `typst-layout/src`):
`flow.mbt` (`layout_frame`, `layout_fragment`, `layout_columns`,
`layout_flow`, configuration, `Work`), `flow_collect.mbt`,
`flow_compose.mbt` (columns, floats, footnotes, line numbers),
`flow_distribute.mbt`, `flow_block.mbt`; `pages.mbt` (`layout_document`,
`layout_document_for_bundle`), `pages_collect.mbt`, `pages_run.mbt`,
`pages_finalize.mbt`; `document.mbt`, `introspect.mbt`
(`PagedIntrospector`); `rules.mbt` (`register`, all paged show rules);
`shapes.mbt`, `transforms.mbt`, `pad.mbt`, `stack.mbt`, `repeat.mbt`,
`image.mbt`, `lists.mbt`, `modifiers.mbt`; `kurbo.mbt` (cubic bounding
boxes); `resolve.mbt` (helpers for upstream's generic `Resolve`). The typst
driver registers the rules and installs `layout_frame` in `Routines`.

Upstream's `RelayoutStop`/`InsertionStop`/`Stop` control flow is raised as
one error type (`FlowStop`) next to `SourceError`; memoized functions are
plain calls that keep upstream's `LocatorLink` boundaries; `CachedCell`
compares inputs bitwise (upstream compares hashes).

**Temporary stubs** (`layout/stubs.mbt`, upstream signatures, they bail
with "… layout is not yet ported"): `layout_par`, `layout_inline` and
`ParSituation` (unit F), `layout_grid`/`layout_table` (unit H),
`layout_equation_block`/`layout_equation_inline` (unit I). The citation and
bibliography rules bail until `CiteGroup::realize`/`Works::generate` exist.

**Library additions:** block/inline layout callbacks (`BlockBody::
SingleLayouter`/`MultiLayouter`, `InlineCallback`, `InlineItem`, stored as
internal `DynValue`s), `Decoration`/`DecoLine` (`TextElem::deco`),
`Destination::alt_text`, `ManualPageCounter`, `OutlineEntry::page`/
`indented`, content constructors (`aligned`, `padded`, `linked`, …),
`measure()`/`layout()`, tiling frames, `pdf.attach` paged rule. Fixed
`Abs::max` (ties return the second value, like `Ord::max`) and
`Frame::inline` (zero positions keep item positions unchanged), both
visible through signed zeros.

**Result:** `paged` 315/2299. Of the failures, ~1290 need inline layout,
~270 math, ~340 grid/table; `python3 scripts/classify_paged.py
[--text-free] [--list]` buckets them (run the stage with `--dump` first).
## Status: work unit H (grid/table layout)

**Layout package:** `grid.mbt` (`layout_grid`, `layout_table`,
`layout_cell` with the manual cell tags), `grid_layouter.mbt`
(`GridLayouter`: column measurement, auto/relative/fractional rows,
multi-region rows, region finishing, fills and line rendering),
`grid_rowspans.mbt` (rowspan layout, unbreakable row groups, rowspan
simulation), `grid_repeated.mbt` (headers/subheaders/footers, orphan
prevention), `grid_lines.mbt` (line segments and stroke priority). The
`layout_grid`/`layout_table` stubs are gone. Upstream's lazy
`generate_line_segments` iterator is collected eagerly (the stroke callback
is pure); `Iterator::sum` over lengths starts at `-0.0` like Rust's float
`Sum` (`abs_sum`), which is visible through signed zeros; the line sort uses
the original index as tie breaker to stay stable.

**Validation:** almost every grid/table suite test contains text, so
`paged` only gains 21 tests (336/2299). To check the port without inline
layout, the grid/table suite tests were rewritten text-free (innermost
`[text]` markup replaced by fixed-size blocks or by stacks of line-like
blocks, `lorem(n)` by tall blocks), dumped with the oracle and compared with
the runner run from that tree: all 304 cases whose upstream dump is
text-free match bit-exactly, in both variants (the remaining ones need
inline/math layout or bibliography).

## Status: work unit C (shaping)

**Package `shape/`**: a faithful port of rustybuzz 0.20.1 (the version
locked by Typst; sources fetched into `.repos/rustybuzz` by
`scripts/upstream.sh`), one file per rustybuzz module: buffer, common, face
(`hb_font_t` over `@otf.Face`), set_digest, ot_map, ot_shape(_plan),
ot_shape_normalize, ot_shape_fallback, ot_layout(_common, _gsubgpos,
_gsub_table, _gpos_table), kerning (legacy `kern` incl. state machines),
paint_extents (COLRv1 glyph extents), tag + tag_table, the complex shapers
(Arabic incl. stch and Mongolian, Hebrew, Thai incl. PUA fallback, Hangul,
Indic, Khmer, Myanmar incl. Zawgyi, USE, syllabic, vowel constraints) and
the AAT layout (morx, kerx, trak, aat_map). WASM shaping is not ported
(rustybuzz feature not enabled by Typst). Public API as used by Typst:
`Face::from_face`/`from_slice`, `UnicodeBuffer`, `ShapePlan::new`,
`shape_with_plan`/`shape`, `GlyphBuffer::glyph_infos`/`glyph_positions`,
`GlyphInfo::unsafe_to_break`, `Feature`, `Script::from_iso15924_tag`,
`Language::from_str`, `BUFFER_FLAG_*`. Building a `Face` parses all
GSUB/GPOS lookups (like rustybuzz); callers should cache it per
`FontInstance`, and shape plans per (font, direction, script, language,
features) like upstream's memoized `create_shape_plan`.

**Tables** are generated, never transcribed: `oracle/src/bin/
gen_shape_unicode.rs` writes `unicode/shaping_tables_gen.mbt`
(General_Category, Script as rustybuzz maps it, ccc, bidi mirroring, from
the exact crates rustybuzz uses); `scripts/gen_shape_tables.py` converts
rustybuzz's own generated data/code (normalization, emoji, Arabic joining,
Indic/USE categories, Ragel machines, tag table, AAT feature mappings) into
`shape/*_gen.mbt`.

**Oracle stage `shape`**: the oracle patches rustybuzz with a tap crate
(`oracle/rustybuzz-tap`, compiling the pristine sources from
`.repos/rustybuzz`) that records every `shape_with_plan` call while the
paged suite compiles; `scripts/goldens.sh shape` dumps the 4598 unique runs
per font to `tests/golden/shape/` (font book index, normalized variation
coordinates, plan direction/script/language/features, buffer script and
flags, text; output glyph ids, clusters, glyph flags, advances, offsets).
**Stage `shape-hb`**: rustybuzz's own test suite (2250 HarfBuzz shaping
tests incl. AOTS, text-rendering-tests, in-house, macOS system fonts),
extracted by `scripts/goldens.sh shape-hb` (`scripts/shape_hb_tests.py`).

**Result:** `shape` 4598/4598 (all scripts: Latn, Math, Hani, Hira, Kana,
Hang, Arab, Hebr, Deva, Cyrl, Grek, Thai, Ethi, Zzzz; all 49 fonts used),
`shape-hb` 2250/2250, plus the rustybuzz unit tests for feature parsing and
tags (`moon test shape`).

## Status: work unit F (inline layout)

**Layout package** (files named after `typst-layout/src/inline`):
`inline.mbt` (mod.rs: `layout_par`, `layout_inline`, `ParSituation`,
configuration), `inline_collect.mbt`, `inline_prepare.mbt`,
`inline_shaping.mbt`, `inline_linebreak.mbt` (simple + Knuth-Plass; break
opportunities come from the `linebreak` package), `inline_line.mbt`,
`inline_deco.mbt` (with the kurbo segment/line intersection it needs),
`inline_finalize.mbt`, `inline_box.mbt` (`layout_box`). The paragraph text
is stored once as a UTF-8 indexed `Utf8Str` (`inline_text.mbt`); substrings
are `Utf8Slice`s. Inline-private types that clash with flow's names are
prefixed (`InlineItem`, `InlineConfig`, `InlineCollector`,
`collect_inline`). `Glyphs` keeps upstream's `Cow` semantics (shared until
`to_mut`). `libm_native.mbt` binds the C libm (`cbrt`, `atan2`, `sin`,
`cos`) like `svg/` for kurbo's `solve_cubic`.

**Shared with math:** `rusty(font)` (cached `@shape.Face` per
`FontInstance`, upstream `FontInstance::rusty`), `create_shape_plan`
(memoized per font/direction/script/language/features), `features`,
`language`, `SharedShapingContext`, `get_font_and_covers` (families are a
`FamilyIter`), `layout_box`, `layout_inline`. Library: `families`,
`variant`, `FontFamily::covers`/`Covers::as_regex`,
`ScriptKind::{default_metrics, read_metrics, feature}`,
`JustificationLimits::{spacing_limits, tracking_limits}`.

**Result:** `paged` 338 -> 1683/2299, `svg` 384 -> 1709. Every remaining
paged failure outside math (452), raw highlighting (~85: highlighted
bodies and raw text spans), bibliography/citations (~50) and PDF/SVG image
loading is a single grid/table stroke span (`table-tags-unstable-functions`).

## Status: work unit I (math layout)

**Layout package**, one file per upstream module of
`typst-layout/src/math`: `math.mbt` (`mod.rs`: `layout_equation_inline`,
`layout_equation_block` with region breaking and equation numbers,
`MathContext`, item dispatch, font stack with script-scale styles),
`math_fragment.mbt` (`MathFragment`, `FrameFragment`, math kerning lookup),
`math_glyph.mbt` (`GlyphFragment`: shaping plan with `flac`/`ssty` feature
fallback, italics correction, top accent attachment, extended shapes,
stretching via MATH variants and assemblies), `math_shaping.mbt`,
`math_run.mbt` (multiline rows, alignment points, inline line-break items),
`math_scripts.mbt`, `math_fraction.mbt`, `math_fenced.mbt`,
`math_radical.mbt`, `math_accent.mbt`, `math_cancel.mbt`, `math_line.mbt`,
`math_table.mbt` and `math_text.mbt`. Functions whose upstream names clash
with other layouters in the package carry a `math` infix
(`layout_math_table`, `layout_math_line`, `layout_math_text`, ...). The
equation stubs in `stubs.mbt` are gone.

Math shaping uses the inline layout API (`rusty`, `create_shape_plan`,
`features`, `language`, `get_font_and_covers` via a `SharedShapingContext`
impl for `MathShapingContext`, `layout_box`, `layout_inline`); the math
font families (`typst_library::math::families`, with New Computer Modern
Math first in the fallback list) are `math_families` in `math.mbt`.
`Augment`'s cast accepts the `stroke: auto` its own `into_value` writes
(field values round-trip through `Value` here).

**Result:** `paged` 1766 → 2223, `svg` 1772 → 2220 (on top of unit F).
All 403 `math/` paged tests match; the 4 `math/` SVG failures are color
emoji glyphs in the SVG exporter (paged output identical). eval/realize/html
unchanged.

## Status: work unit J (PDF export)

**Backend:** pdflite's new `export` package (office.mbt branch
`typst-pdf-export`, worktree `../office.mbt-typst-pdf`) is a port of the
parts of krilla typst-pdf uses: object serialization (classic xref, flate
streams), `Surface` (transforms, clips, masks, opacity, isolated groups,
blend modes), paints (solid incl. Separation spot colors, axial/radial
shadings, PostScript-function sweep/repeat/reflect gradients, translucent
gradient stops via luminosity soft masks, tiling patterns), text (CID fonts
CID=GID with glyf subsetting keeping GIDs, CFF/CFF2 embedded whole as
`FontFile3/OpenType`, `ToUnicode`, krilla's `ActualText` glyph spanner,
Type 3 fonts for color glyphs), images (8-bit samples + `SMask`, ICC,
JPEG passthrough incl. inverted Adobe CMYK), link annotations (quad
points), XYZ/named destinations, outlines, page labels, Info + XMP
metadata, embedded files/AF, tagged PDF (`StructTreeRoot`, `ParentTree`,
`IDTree`, `RoleMap`, MCIDs/MCR/OBJR, attributes) and krilla's validation
tables for PDF/A and PDF/UA. pdflite now depends on `moonbitlang/x@0.5.5`;
typst.mbt links it through `moon.work` (member
`../office.mbt-typst-pdf/pdflite`; `.claude/worktrees/office.mbt-typst-pdf`
is a symlink so the relative path also resolves from agent worktrees).

**Port:** `pdf/` mirrors typst-pdf: `lib`, `format` (`PdfFormatOptions`),
`convert`, `text`, `shape`, `paint`, `image`, `color_glyph` (COLR v0/v1
painting, PNG bitmap glyphs, outline fallback), `link`, `outline`,
`metadata`, `attach`, `util` and the whole tags module (`tags`,
`tags_groups`, `tags_tree`, `tags_build`, `tags_text`, `tags_context`
(context/{mod,list,outline,figure,grid}), `tags_table`, `tags_resolve`
(resolve + accumulator), `tags_util`). Bundles use it through
`BundleOptions.pdf` (runner: `bundle_options`).

**Stages:** `pdf-semantic` (oracle `pdf_semantic.rs`: a canonical dump of
version/info/catalog/XMP/page labels, per page the positioned text runs
(ToUnicode-decoded), filled/stroked paths, images, shadings and
annotations, then destinations, outline and attachments; numbers compared
within 0.02), `pdf-semantic-replay` (exports upstream's frames decoded from
the `paged` goldens, untagged), `pdf-extract-check` (MoonBit extractor on
upstream's PDFs, saved by the oracle with `ORACLE_SAVE_PDF`, passed as
`--upstream-pdfs=<dir>`), `pdftags` (upstream's `tests/src/pdftags.rs`
YAML, ported in `tests/runner/pdftags.mbt`) and `pdftags-check` (formatter
on upstream's PDFs). Internal errors carry upstream's caller location
(`crates/typst-pdf/src/...:line:col`); the oracle now strips its absolute
`.repos/typst/` prefix (`canonical_internal_error`).

**Result:** `pdf-semantic` 2271/2299, `pdftags` 133/133, `pdftags-check`
133/133, `pdf-extract-check` 2299/2299, `pdf-semantic-replay` 2261/2299,
`bundle` 38/39. Visual check (poppler `pdftoppm` 72 dpi, page matches if
≤0.5% of pixels differ): 2054/2141. The `pdf-semantic` failures are SVG
images (no usvg port yet) and PDF images; other gaps: variable font
instancing (krilla instantiates variable fonts), SVG-in-OpenType glyphs
(outline fallback), CFF subsetting, ICC-based colors/output intents for
PDF/A, GIF/WebP decoding.

**krilla-svg** (`pdf/svg*.mbt`, port of krilla-svg 0.8.1: `svg` (lib:
`draw_svg`, `render_svg_glyph`), `svg_group`, `svg_path`, `svg_clip_path`,
`svg_mask`, `svg_image`, `svg_text`, `svg_filter`, `svg_util`) draws SVG
images (`handle_image`) and SVG-table glyphs (color glyph hook: COLR, then
SVG, then bitmap). SVG text uses exporter fonts shared with Typst text
(`SvgFontCache`, keyed by font data identity + index, like krilla's
font-info dedup). Deviations: filters are not rasterized (no resvg port;
`svg_rasterize_filter` hook draws nothing; no test uses SVG filters),
variable fonts use the default instance, outlined glyphs (paint-order
stroke-then-fill) are drawn from the plain outline (no color glyphs),
16-bit PNGs are reduced to 8 bits, indexed PNGs are expanded to RGB
(krilla keeps the palette), GIF/WebP images are skipped. `pdf-semantic`
2271 → 2294 (remaining: `image-svg-linked-many-formats` (GIF, WebP,
indexed PNG) and the four PDF-image tests).

**PDF images** (`hayro/syntax`, port of hayro-syntax 0.7.2 at rev d8e24e2:
byte reader, lazily parsed objects (`Dict` keeps value offsets, `Name` is
a latin-1 string newtype, typed access via the `Readable`/`ObjectLike`
traits and type annotations: `let d : Dict? = dict.get("Key")`), xref
tables/streams with repair (`fallback`), object streams, stream filters
(ASCIIHex, ASCII85, RunLength, LZW, Flate with predictors; flate like
`flate2::read_to_end` then pdf.js' lenient decoder), pages with inherited
attributes and resources, content stream iterators (`TypedInstruction`,
converted from upstream's generated ops by `scripts/gen_hayro_ops.py`)).
`library/image_pdf.mbt` loads documents with it (memoized by data).
`hayro/write` (port of hayro-write 0.7.0) extracts pages as form XObjects
with their dependencies; `pdf/image.mbt` `draw_pdf_page` mirrors krilla's
`Surface::draw_pdf_page` (y-flip, scale, version check with upstream's
error) on pdflite's `Surface::draw_external_xobject` (office.mbt branch
`typst-pdf-images`; one hayro-write extraction context per document so
shared objects are written once, like krilla's per-document extraction).
Tests: `hayro/syntax/oracle_test.mbt`, generated by
`oracle/src/bin/gen_hayro_syntax_tests.rs` from the real crate over hayro's
own corpus (`hayro-tests/pdfs/{custom,load}`) and the dev-assets PDFs
(object dump hashes, page boxes/dimensions/transforms, decoded content and
operators). The replays now reconstruct PDF images and parse SVG assets.
Deviations: image filters (DCT/JPX/JBIG2/CCITT) are not decoded (upstream
`images` feature), document metadata (`Info`) is not parsed.

## Status: usvg port (SVG images and SVG glyphs)

**Packages** (ports of the crates at the versions in `oracle/Cargo.lock`):
`simplecss/` (simplecss 0.2), `svgtypes/` (svgtypes 0.15, incl. the kurbo
arc pieces it needs), `tiny_skia_path/` (tiny-skia-path 0.11 geometry:
`Path`, `PathBuilder`, `Transform`, `Rect`, bounds; plus `strict-num`) and
`usvg/` (usvg 0.47): the svgtree (`svgtree*.mbt`, reusing the roxmltree port
in `data/xml`), the converter (`converter.mbt`, `style.mbt`, `units.mbt`,
`shapes.mbt`, `use_node.mbt`, `switch.mbt`, `clippath.mbt`, `mask.mbt`,
`marker.mbt`, `paint_server.mbt`, `filter.mbt`, `image.mbt`), text
(`text.mbt` parsing, `text_layout.mbt` shaping via `@shape`/`@bidi`,
`text_flatten.mbt` outlines/COLR/SVG/bitmap glyphs, `text_colr.mbt`) with a
`fontdb` subset (`fontdb.mbt`), kurbo pieces for `arc_to` and text-on-path
(`kurbo*.mbt`), and the writer (`writer.mbt`, `Tree::to_string`). f32
arithmetic matches Rust bit for bit: libm via FFI (`libm_*.mbt`, with
`__sincos_stret` on Apple like LLVM merges `sin`/`cos`), `powi`, Rust f32
`Display` (`rust_fmt.mbt`). `Arc::get_mut` in `paint_server.mbt` is emulated
with reference counting over the tree (`RefCounter`).

**Wiring:** `library/image_svg.mbt` (`SvgImage::with_fonts_images` with
Typst's font resolver over the font book and the linked-image resolver,
exact error messages), `library/font_color.mbt` (`draw_svg_glyph` +
`fixup_svg`). Image decoding now passes the text font families like
upstream.

**Tests:** `scripts/goldens.sh usvg` (`oracle/src/bin/gen_usvg_golden.rs`):
dev-assets SVGs + `usvg_corpus.txt` trees, `usvg_text_corpus.txt` text
layouts, and every SVG-table glyph of the test fonts, compared by runner
stage `usvg`; the same cases are generated as `usvg/oracle_test.mbt`.
`scripts/goldens.sh usvg-images` (`oracle/src/usvg_images.rs`) dumps the
tree of every SVG image placed by a paged test (runner stage
`usvg-images`).

**Deviations:** the default string href resolver returns `None` (Typst
always overrides it); `imagesize` only knows JPEG/PNG/GIF/WebP (the
formats usvg accepts); fontdb's generic `fantasy` default is fixed.

**Result:** `svg` 2269 → 2294/2299 (all SVG-table color glyphs), `svg-replay`
2254 → 2279, `paged` 2283 (unchanged; image sizes were already right),
`usvg` 93/93 trees + text layouts and 3360/3360 glyphs, `usvg-images`
342/342. The remaining SVG-image paged failures (`image-svg-linked-*`,
`image-decode-bad-svg`) only differ in the error span: `ImageElem::decode`
reloads the source with the element span instead of the `source`
argument's span (see the deviation note in `library/image.mbt`).
