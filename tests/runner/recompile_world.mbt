// The world of the `recompile` stage (`recompile_stage.mbt`): one world
// object that is compiled again and again while its files change.
//
// What it guarantees:
//
// - Files reach the engine exactly as in `typst watch`. The world keeps
//   them in the `@kit.FileStore` that `cli/world.mbt`'s `SystemWorld` uses
//   (a port of typst-kit's, which upstream's CLI uses), over a loader that
//   reads memory instead of the file system. `RecompileWorld::reset` is
//   `SystemWorld::reset`: every slot becomes stale, a file is loaded again
//   on its next access, and the source of a file that was a source before
//   is the same `Source` object with its text replaced and its tree
//   reparsed incrementally (`Source::replace`), so its nodes outside of the
//   reparsed range keep their span numbers and the others get new ones.
//   A fresh world numbers the same text differently. Spans are in the keys
//   of memoized calls and in the hashes of located elements, which is why
//   the incremental side must not be given new sources.
// - `dependencies` is `FileStore::dependencies`: the files that were
//   accessed since the last reset, i.e. what a watcher would watch.
// - A world is fresh if it is made by `RecompileWorld::new`: a new file
//   store (new sources, parsed from scratch) and a library object that no
//   incremental world has. The `Font` objects are shared (see the README
//   for what else is: `tests/recompile/README.md`).
//
// What changes between two compilations is a [FileSet] (the bytes of the
// files) and a [Variant] (what is not a file: the main file, `sys.inputs`,
// the date, the fonts). A [Snapshot] of both is all a fresh world needs.

///|
/// The files of a project: those on disk, which never change during a run,
/// and over them the files that edits changed.
priv struct FileSet {
  /// The files on disk (a pure function of the id).
  base : (@syntax.FileId) -> Bytes raise @library.FileError
  /// What `base` gave. Shared by all file sets of a document.
  base_cache : Map[@syntax.FileId, Result[Bytes, @library.FileError]]
  /// The edited files: their bytes, or `None` for a file that was removed.
  overlay : Map[@syntax.FileId, Bytes?]
}

///|
/// A file set over the files on disk, with `files` in memory.
fn FileSet::new(
  base : (@syntax.FileId) -> Bytes raise @library.FileError,
  files : Array[(@syntax.FileId, Bytes)],
) -> FileSet {
  let overlay : Map[@syntax.FileId, Bytes?] = Map([])
  for file in files {
    overlay[file.0] = Some(file.1)
  }
  { base, base_cache: Map([]), overlay, }
}

///|
/// The same files in a set of its own: later edits of `self` do not reach
/// it.
fn FileSet::copy(self : FileSet) -> FileSet {
  {
    base: self.base,
    base_cache: self.base_cache,
    overlay: self.overlay.copy(),
  }
}

///|
/// The bytes of a file on disk.
fn FileSet::on_disk(
  self : FileSet,
  id : @syntax.FileId,
) -> Result[Bytes, @library.FileError] {
  match self.base_cache.get(id) {
    Some(result) => result
    None => {
      let result = try (self.base)(id) catch {
        err => Err(err)
      } noraise {
        bytes => Ok(bytes)
      }
      self.base_cache[id] = result
      result
    }
  }
}

///|
/// The bytes of a file as they are now.
fn FileSet::get(
  self : FileSet,
  id : @syntax.FileId,
) -> Result[Bytes, @library.FileError] {
  match self.overlay.get(id) {
    Some(Some(bytes)) => Ok(bytes)
    Some(None) => Err(@library.FileError::NotFound(file_path(id)))
    None => self.on_disk(id)
  }
}

///|
/// Gives a file its bytes, or removes it. A file that is not on disk
/// either is then what it was before any edit (with the error of the
/// disk).
fn FileSet::set(self : FileSet, id : @syntax.FileId, content : Bytes?) -> Unit {
  if content is None && self.on_disk(id) is Err(_) {
    self.overlay.remove(id)
  } else {
    self.overlay[id] = content
  }
}

///|
impl @kit.FileLoader for FileSet with fn load(self, id) {
  match self.get(id) {
    Ok(bytes) => bytes
    Err(err) => raise err
  }
}

///|
/// The library and the fonts of a document.
priv enum Flavor {
  /// Upstream's test world (`test_library`: all features unless the test
  /// names some, the test functions, small pages) with the test fonts.
  Suite(@library.Features?)
  /// The library of `typst-cli`, with the test fonts.
  Plain
  /// The world of the `packages` stage: the library of `typst-cli` with
  /// the embedded fonts.
  Packages
}

///|
/// The values of `sys.inputs` that the harness switches between.
let recompile_inputs : ReadOnlyArray[ReadOnlyArray[(String, String)]] = [
  [],
  [("mode", "draft")],
  [("mode", "final"), ("rev", "7")],
]

///|
/// A new library object of a flavor with one of the [recompile_inputs].
fn Flavor::library(self : Flavor, inputs : Int) -> @library.Library {
  let dict = @library.Dict::new()
  for pair in recompile_inputs[inputs][:] {
    dict.insert(pair.0, Str(pair.1))
  }
  let formats = [
    @library.html_format(),
    @library.pdf_format(),
    @library.svg_format(),
    @library.png_format(),
    @library.bundle_format(),
  ]
  match self {
    Suite(features) => {
      let lib = @typst.library_builder(formats)
        .with_features(@library.Features::all())
        .with_global(define_test_globals)
        .with_inputs(dict)
        .build()
      define_test_colors(lib)
      define_test_styles(lib)
      match features {
        Some(features) => { ..lib, features, }
        None => lib
      }
    }
    // No feature is on unless it is asked for, as in the CLI.
    Plain | Packages =>
      @typst.library_builder(formats)
      .with_features(@library.Features([]))
      .with_inputs(dict)
      .build()
  }
}

///|
/// The family that the font sets of the harness differ in: the default
/// font of text.
let recompile_dropped_family : String = "Libertinus Serif"

///|
/// The font sets of the flavors, by flavor and number.
let recompile_font_sets : Map[String, (Array[@library.Font], @library.FontBook)] = Map([],
)

///|
/// A font set of a flavor: 0 is all its fonts, 1 those that are not of
/// [recompile_dropped_family] (text in the default font is then set in a
/// fallback font, so every page changes).
fn Flavor::font_set(
  self : Flavor,
  set : Int,
) -> (Array[@library.Font], @library.FontBook) {
  let (kind, all, book) = match self {
    Suite(_) | Plain => ("test", test_fonts(), test_font_book())
    Packages => ("embedded", packages_fonts(), packages_font_book())
  }
  if set == 0 {
    return (all, book)
  }
  let key = "\{kind}/\{set}"
  match recompile_font_sets.get(key) {
    Some(fonts) => fonts
    None => {
      let fonts = all.filter(font => {
        font.info().family != recompile_dropped_family
      })
      let entry = (fonts, @library.FontBook::from_fonts(fonts))
      recompile_font_sets[key] = entry
      entry
    }
  }
}

///|
/// What a compilation sees besides the files.
priv struct Variant {
  /// The main file.
  main : @syntax.FileId
  /// The index of `sys.inputs` in [recompile_inputs].
  inputs : Int
  /// The date, in days since 1970-01-01 (upstream's test world: 0).
  day : Int
  /// The font set ([Flavor::font_set]).
  fonts : Int
}

///|
/// Everything a compilation is a function of: enough to make a fresh world.
priv struct Snapshot {
  files : FileSet
  variant : Variant
}

///|
/// The world.
priv struct RecompileWorld {
  flavor : Flavor
  /// The store of `SystemWorld`, over memory.
  files : @kit.FileStore[FileSet]
  mut variant : Variant
  mut library : @library.Library
  /// The libraries this world had, by their inputs: a host that goes back
  /// to earlier inputs may well go back to the library it built for them.
  libraries : Map[Int, @library.Library]
  /// The files that were given out as sources since the last reset.
  sourced : Map[@syntax.FileId, Unit]
}

///|
/// A fresh world of `files` (which it keeps: edit them, then
/// [RecompileWorld::reset]).
fn RecompileWorld::new(
  flavor : Flavor,
  files : FileSet,
  variant : Variant,
) -> RecompileWorld {
  let library = flavor.library(variant.inputs)
  {
    flavor,
    files: @kit.FileStore::new(files),
    variant,
    library,
    libraries: Map([(variant.inputs, library)]),
    sourced: Map([]),
  }
}

///|
/// The files, to edit them.
fn RecompileWorld::file_set(self : RecompileWorld) -> FileSet {
  self.files.loader()
}

///|
/// What the world is now, for a fresh world of the same.
fn RecompileWorld::snapshot(self : RecompileWorld) -> Snapshot {
  { files: self.file_set().copy(), variant: self.variant, }
}

///|
/// Changes what is not a file.
fn RecompileWorld::set_variant(
  self : RecompileWorld,
  variant : Variant,
) -> Unit {
  if variant.inputs != self.variant.inputs {
    self.library = match self.libraries.get(variant.inputs) {
      Some(library) => library
      None => {
        let library = self.flavor.library(variant.inputs)
        self.libraries[variant.inputs] = library
        library
      }
    }
  }
  self.variant = variant
}

///|
/// `SystemWorld::reset`: "Reset the compilation state in preparation of a
/// new compilation." (Its `now.reset()` has nothing to do here: the date
/// is read from the variant.)
fn RecompileWorld::reset(self : RecompileWorld) -> Unit {
  self.files.reset()
  self.sourced.clear()
}

///|
/// The sources that were given out since the last reset whose syntax tree
/// is not what a parse of their text gives (apart from spans).
///
/// A source that was edited in place is reparsed in part, and upstream's
/// reparser, which the port follows, is not always equivalent to a parse:
/// `##let x #let= 4` with its first character deleted keeps a node of the
/// old tree and reports "expected pattern", which a parse of the new text
/// does not (so `typst watch` prints an error that `typst compile` does
/// not, upstream too). The compilation of such a tree is not comparable
/// with a compilation from scratch. Only reads sources that the store
/// already has, so it changes nothing.
fn RecompileWorld::reparsed(self : RecompileWorld) -> Array[String] {
  let out = []
  for id, _ in self.sourced {
    let source = self.files.source(id) catch { _ => continue }
    if !source.root().spanless_eq(@syntax.parse(source.text())) {
      out.push(file_path(id))
    }
  }
  out
}

///|
/// The files that were accessed since the last reset, sorted.
fn RecompileWorld::dependencies(self : RecompileWorld) -> Array[String] {
  let out = self.files.dependencies().map(file_path)
  out.sort_by(@library.compare_str)
  out
}

///|
impl @library.World for RecompileWorld with fn library(self) {
  self.library
}

///|
impl @library.World for RecompileWorld with fn book(self) {
  self.flavor.font_set(self.variant.fonts).1
}

///|
impl @library.World for RecompileWorld with fn main(self) {
  self.variant.main
}

///|
impl @library.World for RecompileWorld with fn source(self, id) {
  let source = self.files.source(id)
  self.sourced[id] = ()
  source
}

///|
impl @library.World for RecompileWorld with fn file(self, id) {
  self.files.file(id)
}

///|
impl @library.World for RecompileWorld with fn font(self, index) {
  self.flavor.font_set(self.variant.fonts).0.get(index)
}

///|
impl @library.World for RecompileWorld with fn today(self, offset) {
  today_on(self.variant.day, offset)
}
