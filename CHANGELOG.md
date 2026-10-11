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

- `syntax`: a `Source` and a `Lines` never change, and an edit returns the
  edited value instead of changing the one it is called on (upstream
  edits `&mut self` through `Arc::make_mut`, so a clone taken before keeps
  the old state; here every holder of the old value does).
  `Source::edit(Int, Int, String)` and `Source::replace(String)` return
  `(Source, (Int, Int))`, the edited source and the reparsed range (they
  returned the range); `Lines::edit(Int, Int, String)` returns the edited
  `Lines` (it returned `Unit`), and `Lines::replace(String)` returns
  `Lines?`, `None` if the text is the same (it returned a `Bool`). A world
  that keeps its sources stores what the edit returned: `source =
  source.replace(text).0`. `replace` with the same text returns the same
  object. The edited source shares with the one before every syntax node
  that the edit did not have to write to; no node of a source is written
  to any more (an edit used to change the nodes on the way to it, and the
  root, in place), so a node that is held across an edit, by a closure for
  one, stays what it was. `SyntaxNode::synthesize` and `synthesize_ranges`
  still write to the tree they are called on: they are for a tree that the
  caller parsed and has not handed out (`deep_clone` one that comes from a
  `Source`).
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
- `library`: the engine reads the world through a tracked world
  (upstream's `Tracked<dyn World>`; `docs/incremental-design.md`, section
  5.2), so that what a memoized call read of the world is known.
  `Engine.world` is a `TrackedWorld` (it was a `&World`): code that builds
  an `Engine` writes `world: @library.TrackedWorld::new(world)`. The
  functions that took the world of an engine take the tracked world:
  `world_range`, `analyze` (which also takes the `Library` now: it asked
  the world for it), `DataSource::load`, `load_many`,
  `SvgImage::with_fonts_images`, `BibliographyElem::keys`, `database` and
  `csl_style`; in `layout`, the method `world` of the trait
  `SharedShapingContext` returns it; in `eval`, `eval_source` takes it as
  its first argument. A `World` implementation does not change.
- `typst`: the callback of `compile_with` gets the tracked world of the
  compilation before the library (`(TrackedWorld, Library) -> Content`,
  it was `(Library) -> Content`); an engine it builds must hold that
  tracked world. `compile_with` has a new optional argument,
  `volatile_files? : (FileId) -> Bool`, for a world whose files change
  during a compilation (`doc`'s sessions): what reads such a file is not
  memoized.
- `library`: `compilation_epoch()`, `evaluation_begin()` and
  `evaluation_end()` are gone (they were added since 0.1.4). What they
  were for is a scope of a tracked world (`TrackedWorld::scoped`,
  `scope_token`, `world_scope_open`).
- `library`, `eval`, `typst`: what the engine memoizes outlives the
  compilation that computed it (step 5 of slice 1 of
  `docs/incremental-design.md`; upstream: comemo's caches, which is what
  makes `typst watch` fast). Module evaluations, closure calls, layouts,
  counter sequences and the works of a bibliography are kept by the
  process and found by a later compilation, with the same world or
  another, if they are still valid: for the same `Library` object, and
  if the world answers what the result asked of it as it did (sources,
  files, the font book and fonts as objects, the date). A process that
  compiles again and again calls `evict(max_age)` between compilations
  (`typst watch`: `evict(10)`), or it keeps what every compilation
  computed (at most four results per key and twelve evaluations per
  source); `evict(0)` drops everything; `set_layout_memo_enabled(false)`
  compiles from scratch, taking nothing from an earlier compilation and
  leaving nothing for a later one. Until now every compilation started
  with empty stores. What a host sees: a second compilation is faster and
  the process holds more memory between compilations; code that counted
  computations across compilations (`closure_memo_stats`,
  `module_memo_stats`) sees hits where it saw computations; and one
  result can differ from a compilation from scratch, as it does in
  upstream's `typst watch`: a call that is found again returns the module
  it returned before, which `==` tells from the module of the same file
  evaluated now (`tests/recompile/upstream`).
- `layout`: `layout_document` and `layout_document_for_bundle` are
  memoized, and so are the page runs inside them (slice 3 of
  `docs/incremental-design.md`; upstream: `#[comemo::memoize]` on
  `layout_document_impl`, `layout_document_for_bundle_impl` and
  `layout_page_run_impl`). In a compilation, and from one compilation of
  a process to the next, a document whose content and styles are what
  they were is not laid out again if the world and the introspector
  answer what its layout asked as they did. What a host sees: a
  recompilation after which nothing on the pages changed is the export
  and little else; a document that is found has the introspector of the
  earlier layout (`document.introspector().serial()` is the same number,
  where every layout made another); and every document that these two
  functions return, computed or found, has pages whose frames and groups
  are its own at every depth, so a holder may write to them
  (`Frame::deep_clone`; the kept layouts shared their groups with the
  document before, and a write to a group taken out of `Frame::items`
  reached them). The process holds more between compilations: the frames
  of the documents and page runs of the last eleven compilations under
  `evict(10)`.
- `layout`: `PagedIntrospector::frame_link_targets()` returns a copy of
  the set (it returned the set that the introspector keeps, which a kept
  document and the documents handed out share).
- `library`: an `ElementIntrospector` keeps the results of at most 65 536
  queries and forgets them all when it has that many (upstream's
  `QueryCache` has no bound; an introspector now lives as long as a kept
  document is found).
- `library`: `evict(max_age)` is comemo's for everything it knows: every
  kept result gets older by one with each call and is dropped when it was
  not found for more than `max_age` calls, and a result that is found is
  young again. The decode caches (syntaxes and themes of `raw`,
  bibliographies, CSL styles, PDF documents, plugins and the results of
  their calls) were dropped as a whole on every `max_age`-th call; they
  have ages now, so a plugin that every compilation loads stays one
  module for the whole session, as upstream's does. It may be called
  during a compilation.
- `doc`: a compilation (`Document::compile`, `compile_paged`, ..) or a
  lowering (`Document::lower`) ends with `@library.evict(10)`, as a
  recompilation of `typst watch` does: a process that compiles many
  documents holds what the last ones computed, not all of it, and finds
  again what two of them have in common (the layout of equal content,
  evaluated packages, decoded images). What involves a callback ends with
  its compilation, as before.
- `library`: nothing is memoized for an engine whose world is in no scope.
  A compilation, `eval_source`, `eval_string` and `doc`'s `lower` open
  one; a host that calls memoized functions of the engine directly
  (`memoized_layout`, `memoized_closure`) with `with_layout_memo` around
  them wraps them in `world.scoped(..)` too.
- `library`: a world must hand out the font book and the font objects it
  has, not make them per call: the tracked world takes a book and a font
  for the same answer only as the same object (`FontBook::edition`,
  `Font::serial`). It stays correct otherwise, and finds less again.
- `eval`: `eval_source` is memoized like upstream's `eval` (the store of
  module evaluations, which only imports went through): two calls in one
  scope of a world with the same source, library, route and traced span
  give the same module, and the second replays the warnings of the first
  instead of evaluating. The main file of a compilation is evaluated
  through it. An evaluation is found by the source, with its span
  numbers (`@library.source_fingerprint`), not by the text of its file.
- `library`: what an introspector's query returns is a view.
  `Introspector::query`, `ElementIntrospector::query` and the method
  `query` of the trait `IntrospectorBackend` return `ArrayView[Content]`
  (they returned `Array[Content]`, the array that the introspector keeps
  for the selector, which a caller could write to), and
  `query_introspection` returns `Introspect[ArrayView[Content]]`. A caller
  that needs an array of its own writes `.to_owned()`; an implementation
  of the trait returns its array as it did (an `Array` is taken where a
  view is expected). `ArrayView[T]` implements `Fingerprint`, as a slice.
- `library`: `Module::canonical` is gone (it was added since 0.1.4), with
  the notion it was for: memoized calls take a module by its hash, as
  upstream's do, and no longer by its identity. `==` on modules is what it
  was, upstream's: the same name and the same object. What a document can
  see of it: at one call site, a memoized call that is given a second
  module with the hash of the first returns what it returned for the
  first. Two plugins that export no function give such modules:
  `(a, b).map(m => m == a)` is `(true, true)`, as it is for upstream (it
  was `(true, false)`).
- `library`: `memo_fingerprint` returns a `MemoKey` (it returned the
  `U128`), which `memoized_layout` takes: the fingerprint with what it
  says about its own arguments (whether they hold a host function).
- `library`: every `Introspector::new` makes another introspector to the
  entries of memoized calls (`Introspector::serial`): a host that asks one
  backend again and again keeps the `Introspector` it made, as a document
  does. It stays correct otherwise, and finds less again.
- `library`: native functions, elements and types are fingerprinted by a
  number of the descriptor object, not by their texts (the name, title and
  documentation of a function, the key of an element, the long name of a
  type): two that a host makes with the same texts were one value to
  everything that compares by fingerprint. The fingerprints of all content
  change, and depend on the order in which a process first uses its
  elements; nothing that is written to an output is derived from them.
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

- `library`: the `pub(all)` enum `DynValue` has two new cases,
  `RawSyntax(RawSyntax)` and `RawTheme(RawTheme)` (the decoded syntaxes and
  the theme of a raw element, in its internal fields `syntaxes-derived`
  and `theme-derived`); a `match` over all cases must handle them.

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

- Memoized calls kept objects that their callers could write to. The
  warnings and delayed errors of a call that was found again were the
  objects that an earlier caller had received: a hint or a tracepoint
  added to one (`SourceDiagnostic::hint`, `trace`) was in what every
  later caller got. The same for the styles of traced values, for a value
  of the type `arguments` that a call returned, for the entries of a
  rendered bibliography (`Works::bibliography`), and for the errors that
  plugin loads, plugin calls and a flow's cached child layouts raise
  again. Each is a copy now.
- Two native functions, elements or types that a host makes with the same
  name, title and documentation were one value wherever values are
  compared by their fingerprints: a closure that captured the one was
  equal to a closure that captured the other, and a memoized call of the
  first answered for the second.
- Compiling a world again after its files changed (as `typst watch` and a
  host that keeps a `World` do): a module of an imported file was found
  again by the text of that file alone, so it was reused although a file
  that it imports or reads (`json`, `read`, ..) had changed, and those
  files were not read again. Memoized module evaluations now end with
  their scope: the compilation, or outside of one the evaluation that a
  host started (`eval_source`, `eval_string`, `doc`'s `lower`: a string
  that is evaluated outside of a compilation and the files it imports are
  one scope, two evaluations in a row are two). Within one compilation
  nothing changes: a file is still evaluated once.
- A `doc` document whose Typst code reads the session's own virtual files
  (the origin listing, a markup fragment) got what an earlier call had
  read, since closure calls are memoized and the listing grows while a
  document is compiled. Such files are declared to the engine now and
  what reads them is not kept.
- A function that was called with an engine of another world or another
  library inside a compilation (a host function that evaluates with a
  world of its own) could be answered from a call made for the
  compilation's world. Entries of memoized calls are compared by their
  library and by what they read of the world now.

- Damaged PNG images: the decoder checked no chunk CRC and allocated the
  frame that the header claims, so a file with a damaged header either
  killed the process in an allocation or was shown as if it were sound.
  Decoding now follows the `png` crate step by step (`codecs`: a port of
  its `StreamingDecoder` and `Reader` and of `fdeflate`'s decompressor):
  a file gives the error that upstream gives, with its text (`failed to
  decode image (Format error decoding Png: CRC error: expected 0x.. have
  0x.. while decoding ChunkType { type: IHDR, .. } chunk.)`, `unexpected
  end of file`, `Corrupt deflate stream. ..`, ..), or upstream's pixels
  where upstream accepts it (a wrong CRC in an ancillary chunk, which is
  ignored; a wrong Adler-32; a missing `IEND`). Nothing is allocated for
  the dimensions alone. Decoding is also faster (12 ms instead of 65 ms
  for a 5.4 megapixel screenshot). With it:
  - a raster image over the decoder's limits is `file is too large`, as
    upstream reports it (it was `failed to decode image (Memory limit
    exceeded)`; also for GIF frames);
  - PDF export of an SVG that holds a PNG which cannot be decoded fails
    with `failed to process image (..)` like upstream (the image was left
    out);
  - an image inside an SVG whose header claims a size that leaves it no
    height in its box no longer aborts (upstream panics; the image is left
    out), and the size of a PNG of 2^31 pixels and more is read as upstream
    reads it.

  `codecs`: `decode_png` is what the `image` crate does, the new
  `decode_png_frame(data, strip16?)` (error: `PngFrameError`) what
  `png::Decoder::new` does for krilla and tiny-skia; `read_png_info` takes
  `limits? : PngLimits`; `is_limit_error(message)`.

- PDF export: a coordinate that lies exactly halfway between two shortest
  decimals is written with the even digit, as upstream writes it
  (`142.20312`, it was `142.20313`: a difference of 0.00001pt in about one
  number in 200). The fix is in `moonbitlang/pdflite` 0.3.8, which the
  module now depends on (it was 0.3.6).

- Raw text whose `theme` or `syntaxes` are paths: the decoded files were
  looked up by the path as it was written when the text was highlighted,
  so two files in different directories that both say
  `#set raw(theme: "theme.tmTheme")` shared the theme of the one that was
  evaluated last. The decoded theme and syntaxes are now stored with the
  field, in the element or the set rule (upstream's `Derived`), and
  syntaxes of nested set rules are folded with their sources.

- `typst watch` with one PNG per page (`page-{p}.png`): a page that shows
  an SVG whose linked image (`<image href="photo.png"/>`) changed was not
  written again and kept the old image, since the hash of an SVG image covered
  its data and its fonts and not the images it links. A decoded SVG image
  is now also identified by the data of the linked files it loaded and
  by which of its fonts was chosen for which text (two decodings of one
  SVG that set a text without a font family in different fonts of the
  text around the image, both of which the SVG also names, were one
  image): `==`, `Hash` and `Fingerprint` of `SvgImage` (and with it of
  `Image`, frames, tilings and pages) include both. Upstream's hash does
  not, and upstream shows one image for two SVG files with the same
  bytes next to different linked images; the port shows two, as before.
- The works of a bibliography (`Works::generate`) were kept in a cell and
  found by the engine's introspector object, whatever the bibliography
  files were by then: a host that kept an engine and called it again
  after a `.bib` file or a CSL style changed got the works of the first
  call. They are a memoized call of the compilation now, found by the
  bibliography and citation elements and taken only if the files they
  were loaded from still are what they were (upstream memoizes
  `Works::generate_impl`). The works are also generated once for all
  citations of an iteration, where every block or table cell with a
  citation generated them again (a table of twelve cells that cite: 75
  times, now 3), and the errors they keep are raised as copies, as
  upstream clones them (a citation of a key that no bibliography has
  could gather the tracepoints of earlier layouts).
- A file that fails and is imported more than once in a compilation (from
  two `context` blocks, whose errors are delayed) was reported with the
  tracepoints of all imports that found its evaluation; it has that of
  its own import, as upstream's. The store of module evaluations keeps a
  copy of an error and hands out copies.
- A file that is imported at two depths of the call stack is evaluated
  again where the route is deeper than the depth checks of its first
  evaluation allow (upstream tracks `Route::within`): a document whose
  second import no longer fits the maximum call depth compiled, and now
  fails with upstream's "maximum function call depth exceeded".

- PDF export: raster images with the same bytes were taken for one image
  and embedded once, the first one for all of them: the same bytes read as
  pixels of another format (`format: (encoding: "luma8", ..)` and
  `"rgb8"`, or other dimensions), or the same file with another `icc`
  profile. An image is now identified as upstream identifies it, by its
  data, format and ICC profile (a JPEG, which is embedded as it is, still
  by its data).

### Added

- `library`: `Introspector::serial`, a number (`Int64`) that says which
  introspector one is (the same for the recording and the untracked forms
  of one, zero for the empty ones). `Sink::kept` and `Sink::extend_from_kept`: a copy of
  a sink for a store that keeps the effects of a call, and its replay,
  which hands out copies of the diagnostics and of the styles of traced
  values.

- `library`: `TrackedWorld` (`new(world, volatile_files?)`, the reads
  `source`, `file`, `book`, `font`, `today`, and for hosts and stores
  `scoped`, `in_scope`, `scope_token`, `is_volatile`, `reads_begin`,
  `reads_end`, `reads_abort`, `validate`), `WorldReads` (`is_volatile`,
  `length`, `describe`), `WorldReadsMark`, `world_scope_open`.
  `FontBook::edition`, `Font::serial`.
- `library`: `SvgImage::links()`, the hashes of the data of the linked
  images that a decoded SVG was built from, and `SvgImage::selections()`,
  what its font resolver answered (both are part of the image's
  identity), and `works_generation_count()`, how often the works of a
  bibliography were generated since the process started (for tests and
  measurements).
- `library`: a check of what memoized calls record of the world, for
  tests: `set_memo_check`, `memo_check_enabled`, `take_memo_check_report`,
  `memo_check_reads`, `memo_check_running_now`,
  `register_memo_check_store` (the runner's
  `--check-reads`).
- `syntax`: `Source::serial`, `is_pristine`, and a slot of two words that
  a caller keeps with a source (`has_memo`, `memo_hi`, `memo_lo`,
  `set_memo`).
- `library`: `source_fingerprint(Source)`, what a memoized evaluation of a
  source is found by; `RouteShifts` (`allows`, `note_reused`),
  `route_shifts_begin` and `route_shifts_end`, the depth checks of a
  memoized evaluation of a source file; `SourceDiagnostic::clone`, a copy
  with a trace and hints of its own.
- `eval`: `module_memo_stats()`, how many evaluations of source files were
  found and how many computed (for tests and measurements).
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
  (upstream `comemo::evict`): every result that the process keeps gets
  older by one and is dropped when it was not found for more than
  `max_age` calls (above, "Breaking: changed").
- `library`: `closure_memo_entries()` and `layout_memo_entries()`, `eval`:
  `module_memo_entries()`: how many closure calls, layouts and
  evaluations of files the stores keep (for tests and measurements);
  `ContentCache::clear()`.
- `library`: `PageMemo[T]` (`new(label)`, `stats()`, `entries()`) and
  `memoized_pages(memo, engine, key, content, children, styles, copy,
  cacheable, f)`: a store of memoized layouts whose results are not
  frames (the pages of a run, a document), with the copy of a result and
  the test for what may be kept given by the caller. `frame_cacheable`
  and `paint_cacheable` (they were private): whether a frame or a paint
  may be kept by an entry (no host closure in a tag or in the frame of a
  tiling). `Frame::deep_clone()`: a copy of a frame that shares no frame
  and no group with it, at any depth, for a holder that the engine does
  not know (`Frame::clone` shares the groups of the items).
- `layout`: `page_run_memo_stats()` and `document_memo_stats()`, how many
  page runs and documents were found and how many were laid out since
  the process started, and `page_run_memo_entries()` and
  `document_memo_entries()`, how many are kept (for tests and
  measurements).
- `library`: decoded raster images are kept by content (upstream memoizes
  `RasterImage::new_impl`): `RasterImage::new` decodes equal data with an
  equal format and ICC argument once per process and returns the same
  image, also for a decoding error. An image that is on many pages, or
  laid out again in a later introspection iteration or in the next
  compilation of `typst watch`, was decoded every time. An image stays
  for `max_age` calls of `evict(max_age)` that find it unused and goes
  with the next (comemo's rule); a process that compiles many documents
  and never calls `evict` keeps them all.
  With `set_layout_memo_enabled(false)` nothing is kept. New for caches of
  this kind: `ContentCache[T]` (`new`, `get`, `insert`, `evict`, `length`;
  results by a fingerprint, with comemo's ages), `register_evictor(f)`
  (what `evict` calls with its `max_age`), `data_hash(bytes)` (`hash128`
  of data, computed once per `Bytes` object), `content_memo_enabled()`,
  and `HintedString::clone()`.
- `library`: highlighted raw text is kept by content in the same way
  (upstream memoizes `Packed<RawElem>::highlight`): a raw element with
  equal fields, spans and styles is highlighted once per process, not once
  per introspection iteration and compilation.
- `pdf`: the image conversion of the exporter is kept by content too
  (upstream memoizes `convert_raster`): a raster image is converted once
  per process and `interpolate` flag, not once per place it is drawn at.
  `library`: `RasterImage::hash128()`, the hash of an image (its data,
  format and ICC profile; upstream `Hash for RasterImage`).
- `pdf`: what is kept of a converted image is the image as the file
  embeds it, its samples compressed, as krilla's images are (no change of
  the interface; `moonbitlang/pdflite` 0.3.9, `Image::deflated`). An
  export does not compress a raster image again that an earlier export
  of the process embedded, for as long as `evict` keeps it (images inside
  SVGs and bitmap glyphs are made, and compressed, for every export): the
  second export of a deck of 28 screenshots takes 6 ms instead of 371 ms,
  and `typst watch` recompiles it to a PDF in 53 ms instead of 420 ms.
  The converted samples are no longer held between exports (72 MB of the
  deck's). The bytes of a PDF are what they were. The module depends on
  `moonbitlang/pdflite` 0.3.9 (it was 0.3.8).
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
