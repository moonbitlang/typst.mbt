# Changelog

Changes to the public API of `moonbitlang/typst`, newest first. "Public API"
is what the `pkg.generated.mbti` files show; each section is taken from
their differences between two releases, so a rename or a changed signature
that is not listed here did not happen. Packages are named by their path in
the module (`library` is `moonbitlang/typst/library`).

## Unreleased

Since 0.1.4 (commit 7d2ee18).

### Breaking: renamed

MoonBit keywords and reserved words used as names get a trailing underscore
(like the existing `extend_`, `type_`); nothing else about these items
changed.

| package | before | now |
| --- | --- | --- |
| `library` | `Scope::define` | `Scope::define_` |
| `library` | `Type::module()` | `Type::module_()` |
| `library` | `Type::constructor` | `Type::constructor_` |
| `eval` | `Vm::define` | `Vm::define_` |
| `syntax` | field `PackageSpec.namespace` | `PackageSpec.namespace_` |
| `syntax` | field `VersionlessPackageSpec.namespace` | `VersionlessPackageSpec.namespace_` |
| `syntax` | field `PackageManifest.package` | `PackageManifest.package_` |
| `data/xml` | `Attribute::namespace()` | `Attribute::namespace_()` |
| `data/xml` | `ExpandedName::namespace()` | `ExpandedName::namespace_()` |
| `wasmi` | field `ImportName.module`, `ImportName::module()` | `module_`, `ImportName::module_()` |
| `wasmi` | `ImportType::module()` | `ImportType::module_()` |
| `wasmi` | `Linker::define` | `Linker::define_` |
| `wasmparser` | field `Frame.unreachable` | `Frame.unreachable_` |

Typst-level names (`type`, `module`, the `namespace` of a package spec in
Typst source) are unchanged.

### Breaking: changed

- `syntect`: `SyntaxSet::from_compact(String, ReadOnlyArray[String])` is
  now `from_compact(String, (Int) -> String)`: the contexts are given as a
  function of the syntax index (the embedded data is stored in pieces and
  joined when a syntax is first used).
- `wasmi`: `DedupFuncType` is an opaque struct (it was `pub(all) struct
  DedupFuncType(Int)`). It now records the engine it belongs to, and
  resolving it with another engine panics like upstream.
- `library`: the `pub(all)` structs `Closure` and `Tiling` have a new field
  each (`hash`, `frame_hash`, both `LazyFingerprint`); code that builds them
  with a struct literal must supply it (`LazyFingerprint::new()`).
- `library`: the `pub(all)` struct `BindingDocumentation` has two new
  fields, `since : Since?` and `keywords : ArrayView[String]` (upstream's
  `since` and `keywords`); code that builds one with a struct literal
  must supply them. The bindings of the standard library now carry their
  documentation (they had none), which changes their fingerprints.
- `hayro/interpret`: `GraphicsState` and `TextState`, `hayro/svg`:
  `SvgRenderer`, `otf`: `CffIndex` are no longer exported. They were
  abstract types that no public function accepted or returned.
- `doc`: `Stroke(dash=..)` takes a `Dash` (it was a `Value`): write a
  preset (`Dotted`, `Dashed`, ..), `Pattern([..], phase=..)`, or
  `RawValue(v)` for the value passed before.
- `doc`: the argument indices of origins (`Origin.param`, the ranges of
  `ArgsLoc`) shift where parameters were added: by two from `lang` on in
  `Text`/`SetText` and from `extent` on in `Highlight`/`SetHighlight`
  (`top_edge`, `bottom_edge`), by one from `fill` on in `Box`/`SetBox`
  (`baseline`).
- `doc`: `Size` (the result of `Ctx::measure`) has a third field,
  `baseline`; a pattern that names only `width` and `height` needs `..`.

### Changed: `Debug` output

These types print with core's `Debug` (`@debug.to_string`, `debug_inspect`,
inside derived `Debug` of other types) what upstream Typst prints for
`{:?}`, instead of a derived record:

| package | type | before | now |
| --- | --- | --- | --- |
| `syntax` | `PackageSpec` | `{ namespace: "preview", name: "foo", version: { major: 0, minor: 1, patch: 0 } }` (broken over lines) | `@preview/foo:0.1.0` |
| `syntax` | `VersionlessPackageSpec` | `{ namespace: "preview", name: "foo" }` | `@preview/foo` |
| `syntax` | `PackageVersion` | `{ major: 0, minor: 1, patch: 0 }` | `0.1.0` |
| `syntax` | `VersionBound` | `{ major: 0, minor: Some(1), patch: None }` | `0.1` |
| `syntax` | `FileId` | `FileId(1)` | `"/main.typ"`, in a package `@preview/foo:0.1.0"/lib.typ"` |

`Debug` of a `FileId` that was never interned now panics, as upstream's
does. `Show` of the package types is unchanged (`FileId` has none).

Without a change of output: `wasmparser`'s `Frame` implements `Debug` by
hand (it still prints the field as `unreachable`), and `wasmi/ir`'s
`OutOfBoundsConst` and `wasmi`'s `Any` implement `Show` by hand instead of
deriving it.

### Changed: trait methods called through their type

MoonBit is removing the rule that makes the methods of `impl Trait for T`
callable as methods of `T` (`x.hash()`, `T::default()`). Every public impl
and every trait derived for a public type now says which of its methods
are methods of the type, with a `pub extend T with Trait::{..}`:

- 547 more impls in 32 packages, the ones this repository itself calls
  that way, declare it plainly (0.1.4 had 103 such declarations, in
  `syntax/ast` and `wasmi/core`; now 650 in 34 packages). Their methods,
  about 1,030 more, are now listed in the interfaces as methods of the
  type (`pub fn T::m`) and are callable as before; most are in `library`
  (the `Reflect`/`IntoValue`/`FromValue` casts, `Fingerprint`,
  `Show::to_string`, `Default::default`), `usvg`, `wasmparser`, `otf` and
  `bib/hayagriva`.
- For every other public impl (4,438 declarations in 67 packages) the
  declaration is deprecated and hidden from the interface: these methods
  are not meant to be methods of the type. Calling one through the type
  compiles as before, now with a warning that says what to write, e.g.
  ``call as `Hash::m(x)`, or un-deprecate this `extend` to make it a
  method``: write the call with its trait (`Hash::hash(x)`,
  `Default::default()`, `@debug.Debug::to_repr(x)`).
- `doc` (the EDSL): the conversion traits are called through the trait,
  for every type alike. `x.to_value()` and `x.into_content()` on a
  concrete facade or description type (`Length`, `Paint`, `Stroke`,
  `Heading`, `Context`, ..), and `x.to_repr()`, which implicit promotion
  allowed in 0.1.4, are deprecated: write `ToValue::to_value(x)`,
  `IntoContent::into_content(x)`, `@debug.Debug::to_repr(x)`. Passing
  such a value to a constructor, which is how documents use them (typed
  parameters, `&IntoContent` for content, the bound `T : ToValue` of the
  generic facades), is unchanged, and so are calls on a trait object and
  printing with core's `debug(x)` / `debug_inspect(x)`. The interface of
  `doc` lists none of these as methods, as in 0.1.4.

Operators (`==`, `<`, `+`), string interpolation, `inspect`/`debug` and
generic code with trait bounds call the trait and are not affected.

Where two traits of a type have a method of the same name, one of them is
the method of the type: `T::output()` is `Reflect`'s (the cast info, as in
upstream) for `Decimal`, `HtmlAttr`, `HtmlTag`, `Location`, `PdfStandards`,
`Symbol`, `Tag`, `Target`, `Type` and `Version` in `library`; `Show`'s
`output` of these types is `Show::output(x, logger)`.

### Fixed

- Compiling a world again after its files changed (as `typst watch` and a
  host that keeps a `World` do): a module of an imported file was found
  again by the text of that file alone, so it was reused although a file
  that it imports or reads (`json`, `read`, ..) had changed, and those
  files were not read again. Memoized module evaluations now end with the
  compilation (`library`: `compilation_epoch()`), and outside of one with
  the evaluation (`eval_source` with the root route; `library`:
  `note_evaluation(route)`). Within one compilation nothing changes: a
  file is still evaluated once.

- PDF export: a coordinate that lies exactly halfway between two shortest
  decimals is written with the even digit, as upstream writes it
  (`142.20312`, it was `142.20313`: a difference of 0.00001pt in about one
  number in 200). The fix is in `moonbitlang/pdflite` 0.3.8, which the
  module now depends on (it was 0.3.6).

### Added

- The CLI has `watch` (`typst watch input.typ [output]`, native and wasm):
  the port of `typst-cli`'s, without its HTTP server for HTML export.
- `kit/watcher`, a new package (upstream's `watcher` feature of typst-kit):
  `Watcher` (`new(output, tasks)`, and the `async` functions
  `update(paths)` and `wait()`), `run` (runs a function on the event loop
  of `moonbitlang/async` and hands it the `Tasks` for a watcher) on the
  native and wasm targets. On wasm-gc and js, where there are no file
  system events, the package is `unsupported : String` alone. The module
  has a new dependency for it, `moonbitlang/async` (0.22.4); only this
  package imports it, so a program links that runtime only if it imports
  `kit/watcher`.
- `kit/platform`: `monotonic_nanos()` (a clock for durations),
  `raise_fd_limit()` (raises the soft limit of open files to the hard one),
  `os_error(code)` (the `IoError` of an OS error number) and
  `is_same_file(path1, path2)` (the same device and inode, like the
  `same-file` crate; on wasm the same canonical path).
- `library`: `format_duration(nanoseconds)` (upstream
  `typst_utils::format_duration`: `2.85 s`, `294.82 ms`, `1 h 4 min`).
- `library`: `evict(max_age)`, for a process that compiles again and again
  (upstream `comemo::evict`): on every `max_age`-th call it drops the data
  that is kept by content for the process (decoded `raw` syntaxes and
  themes, bibliographies, CSL styles, PDF documents, plugins and the
  results of their calls), which otherwise only grows when files change.
- `library`: decoded raster images are kept by content (upstream memoizes
  `RasterImage::new_impl`): `RasterImage::new` decodes equal data with an
  equal format and ICC argument once per process and returns the same
  image, also for a decoding error. An image that is on many pages, or
  laid out again in a later introspection iteration or in the next
  compilation of `typst watch`, was decoded every time. `evict(max_age)`
  drops an image that `max_age` calls in a row did not use; a process
  that compiles many documents and never calls `evict` keeps them all.
  With `set_layout_memo_enabled(false)` nothing is kept. New for caches of
  this kind: `ContentCache[T]` (`new`, `get`, `insert`, `evict`, `length`;
  results by a fingerprint, with comemo's ages), `register_evictor(f)`
  (what `evict` calls with its `max_age`), `data_hash(bytes)` (`hash128`
  of data, computed once per `Bytes` object), `content_memo_enabled()`,
  and `HintedString::clone()`.
- `layout`: `Fingerprint` for `Page` (upstream derives `Hash`).
- `doc/fonts`, a new package: `sans()`, the font files of a sans-serif
  family for the EDSL, IBM Plex Sans (SIL Open Font License 1.1) in
  regular, italic, bold, bold italic and medium. `doc`: `sans_fonts()`,
  its fonts with their font book entries; `DocWorld::in_memory` and
  `@system.world` add them under `embedded_fonts`, so
  `Text(font=["IBM Plex Sans"])` works without font files of the user.
  The family is found by its name only and is no fallback font: a
  document that does not name it is laid out as before. The Typst
  command line does not load the package.
- `libm`, a new package: `cbrt`, a port of the `libm` crate's correctly
  rounded cube root, and `f64_cbrt`, Rust's `f64::cbrt` (the C library's
  `cbrt` on Apple targets and Windows, `cbrt` everywhere else, as Rust
  links it for its glibc and wasm targets). `kurbo`, `layout` and `svg` call it in `solve_cubic`: on
  Linux the roots of a cubic (the gaps of an underline, offsets of
  strokes) are now upstream's to the last bit, where glibc's `cbrt` could
  be an ulp off; on the wasm and js targets it replaces `@math.cbrt`.
- `doc/format`, a new package without dependencies (it does not import
  `doc` or the engine): `fixed(x, digits, trim?)` (the exact value of the
  double rounded half away from zero, JavaScript's `toFixed`), `grouped`
  and `grouped_int` (thousands separators), `percent`, `compact` (k, M, B),
  `soft_breaks` (zero-width spaces after `_ / . : -`, for long words in
  narrow cells) and `ticks` (round axis values).
- `syntax`: `Debug` for `RootedPath` and `VirtualPath` (the text their
  `Show` already had, upstream's `Debug`).
- `syntax`: the trait `NodeHasher` (`write_u64`, `write_str`) and
  `SyntaxNode::hash_into`.
- `library`: `LazyFingerprint` (`new`, `reset`, `write`, `write_cached`,
  `flags`; `Eq`, `Hash`); `Fingerprint` for `Binding`, `Category`, `Color`, `ColorSpace`,
  `Curve`, `Datetime`, `Destination`, `FixedStroke`, `Font`, `FontInstance`,
  `Frame`, `FrameItem`, `Glyph`, `Gradient`, `GroupItem`, `Image`, `Module`,
  `Paint`, `ProcessColor`, `Scope`, `Shape`, `SpotColorant`, `Stroke`,
  `Symbol`, `TextItem`, `Tiling`, `Transform`; `NodeHasher` for
  `SipHasher128`; `Tiling::frame_fingerprint_flags`.
- `library`: `Since` (when a feature was introduced: `Forever`,
  `Version(major, minor, patch)`, `Unreleased`; castable like upstream);
  the field `since` on `NativeFuncData`, `NativeTypeData` and
  `ElementData`, `keywords` on `NativeTypeData`, and the optional
  parameters `since` / `keywords` of `NativeFuncData::new`,
  `NativeTypeData::new`, `Element::new`; `Type::since`, `Type::keywords`,
  `Element::since`, `Element::keywords`; `Binding::is_documented`,
  `name`, `title`, `docs`, `since`, `keywords`;
  `BindingDocumentation::from_func`, `from_type`, `from_elem`.
- `read_fonts`: the `hdmx` table: `FontRef::hdmx`; `Hdmx` (`read`,
  `version`, `num_records`, `size_device_record`, `record_for_size`);
  `DeviceRecord` (fields and accessors `pixel_size`, `max_width`,
  `widths`). `skrifa` uses it for the advance of hinted glyphs, like
  upstream.

- `doc`: `Layout` (the size of the enclosing region, with `LayoutSize`);
  `Size.baseline`; `Box(baseline=)`; `top_edge`/`bottom_edge` (`TopEdge`,
  `BottomEdge`) on `Text`, `SetText`, `Highlight`, `SetHighlight`; `Dash`
  and `DashLen`; colour operations on `Paint` (`transparentize`, `lighten`,
  `darken`, `mix` with `ColorSpace`); `Length::sizing`, `Length::spacing`;
  `Upper`, `Lower`; `Sides::zero`. See `docs/edsl-ports.md` and
  `docs/edsl-guide.md`.
- `doc`: `Para(text, quotes?, leading?, spacing?, justify?, linebreaks?,
  hanging_indent?, extra?)`, a paragraph of prose: the text of a `Prose`
  between two paragraph breaks, with one origin. Unlike `Par(Prose(..))`
  it can hold a block (a displayed formula is kept, and the text after it
  is not indented as a new paragraph), and a blank line in its text is a
  paragraph break. Its options are `par`'s, as a set rule for that text.
- `doc`: lints. `CompileReport` has a new field `lints : Array[Lint]`;
  `Lint` (`kind : LintKind`, `message`, `hints : Array[Hint]`,
  `location : Location?`; `Lint::render`); `LintKind` (one case,
  `AdjacentInline`: two text items next to each other in a sequence are
  typeset as one paragraph with nothing between them; `LintKind::name`).
  `Document::compile`, `compile_paged` and `lower` take `lints? : Bool =
  true`; `lints=false` turns the lints off. Nothing breaks: `CompileReport`
  cannot be built outside `doc` (it has a private field), and the new
  parameter is optional. `LintKind` will get more cases: match it with a
  wildcard.
- `doc`: the lints of the pages. `LintKind` has three more cases:
  `MissingGlyph` (a character that no font has a glyph for),
  `OutsidePage` (text, a shape or an image that leaves the page with its
  bleed by more than a point) and `OutsideContainer` (the same for a
  `Block` or `Box` that was built with a width or a height in absolute
  units, so also for the kit's `Canvas`). `Lint` has a new field `page :
  Int?`, the page of the finding (`None` for `AdjacentInline`), and
  `Lint::render` prints it (`on page N`). They are in the report of
  `Document::compile_paged`, which now holds more lints than before for a
  document that has such a defect; `lower` and the generic `compile` have
  no pages and so none of them. `Lint` cannot be built outside `doc`
  (its fields are read-only there), so the new field breaks nothing.
- `doc`: `Composite(name, loc, args_loc, build)` with `CompositeSite`
  (`arg`, `invalid`): the hook for elements that a package outside `doc`
  defines by an expansion into its constructors, with the provenance of
  one constructor call. The constructors that run in `build` (and in the
  callbacks that it creates) are the call of the composite;
  `site.arg(i, v)` marks an argument of a constructor as the caller's
  argument `i`; `site.invalid(message, arg?)` is an error at an argument or
  at the call.
- `doc/kit`, a new package on `doc` only: elements that are not one Typst
  element. Its first is `Cards(items, columns?, gutter?, column_gutter?,
  row_gutter?, fill?, stroke?, inset?, radius?)`: cards in rows, the cards
  of a row equally high. Without `radius` they are the cells of a grid;
  with it, rounded unbreakable blocks whose rows are measured first (a
  callback, so it is built outside of callbacks).
- `doc/kit`: `Chip(text, fill?, stroke?, radius?, inset?, outset?)`, a
  label in a box in a line of text: the padding to the sides is the box's
  inset and the padding above and below its outset (the label stays on the
  baseline, the line keeps its height), and the spaces of the label are
  no-break spaces. `Chip::of(body, ..)` is the same box around content.
- `doc/kit`: `DataTable(head, rows, columns~, inset?, align?, fill?,
  stroke?, radius?, frame_fill?, breakable?, key?)`, a table of data given
  by rows: a header that repeats, rows that are not split, one stroke as
  the rule under each row with no other line, and with `radius` a rounded
  frame. A row whose cells do not fill the columns (spans counted) is an
  error at `rows` under the key of the row. `frame_fill` is the fill of
  the frame, the surface of a framed table on a page that is not white
  (`fill` is the table's, per cell: a fill of every cell is painted over
  the edge of the frame's outline); without `radius` it is an error.
- `doc`: `Content::table_cell_spans()`, the columns and the rows that a
  description takes as a cell of a table (`None` for a child that a table
  does not place in its row): what `DataTable` counts with, since a
  description is opaque outside `doc`.
- `doc`: for the lint of adjacent text and for the text after a block in
  a `Para`, a sequence of rules and then one block is that block (it was
  inline content, like every other sequence): an element that gives its
  block a rule of its own, like `DataTable`, is a block.
- `doc/kit`: `Canvas(width, height, items, clip?, key?)`, a drawing
  surface for charts and diagrams: an unbreakable block of a fixed size in
  points whose items are placed by coordinates (origin at the top left, y
  down). Its items are `CanvasItem`s, each a call site of its own:
  `Canvas::place(at, body, anchor?)` (content with one of nine sides at a
  point, by the engine's alignment; with the anchor `Baseline` on its
  measured first baseline, which is a callback), `Canvas::line(start,
  end_, stroke?)`, `Canvas::rect(at, width, height, fill?, stroke?,
  radius?)`, `Canvas::circle(center, radius, fill?, stroke?)`,
  `Canvas::curve(start, segments, fill?, stroke?)` and
  `Canvas::arrow(start, segments, stroke?, head?)`, a path with a filled
  triangle at its end that points along the path. With them the enums
  `AnchorX` (`Left`, `Center`, `Right`), `AnchorY` (`Top`, `Horizon`,
  `Bottom`, `Baseline`) and `Segment` (`LineTo`, `QuadTo`, `CubicTo`).
- `doc`: `Stroke::paint()`, the paint that a stroke was made with (`None`
  for one without, or with `auto`): what `Canvas::arrow` fills its head
  with, since a stroke is opaque outside `doc`.

### Not a change for users

- Type parameters that a type never used are written `_` in the interface:
  `library` `Ty[_]`; `otf` `LazyArray16[_]`, `LazyArray32[_]`,
  `LazyOffsetArray16[_]`, `RecordList[_]`, `LookupSubtablesIter[_]`,
  `ExtendedStateTable[_]`; `wasmparser` `SectionLimited[_]`. Uses such as
  `LazyArray16[UInt16]` are unaffected.
- `hayro/interpret`: `DummyDevice` is shown as an empty struct (its unused
  private field is gone); `DummyDevice::new()` is unchanged.
