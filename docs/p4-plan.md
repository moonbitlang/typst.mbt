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