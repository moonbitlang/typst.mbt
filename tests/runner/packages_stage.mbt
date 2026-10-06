// The `packages` stage (see `oracle/src/packages.rs`): compile the
// documents of `tests/packages/docs`, which use real packages of the Typst
// package registry (`tests/packages/manifest.tsv`, fetched by
// `scripts/packages.sh`), and compare what the `paged` and `svg` stages
// compare: the document in the `typst-frame-v1` format (with the
// diagnostics and their tracepoints) and the merged SVG.

///|
/// The project root of the documents (`<group>/<name>.typ`).
let packages_docs_dir = "tests/packages/docs"

///|
/// The unpacked packages (`<namespace>/<name>/<version>`).
let packages_dir = ".repos/typst-packages"

///|
/// The world of the `packages` stage (the oracle's `TestWorld::packages`):
/// what `typst compile --ignore-system-fonts` sees.
priv struct PackagesWorld {
  main : @syntax.Source
  library : @library.Library
}

///|
impl @library.World for PackagesWorld with fn library(self) {
  self.library
}

///|
impl @library.World for PackagesWorld with fn main(self) {
  self.main.id()
}

///|
impl @library.World for PackagesWorld with fn source(self, id) {
  if id == self.main.id() {
    self.main
  } else {
    packages_file_store.source(id)
  }
}

///|
impl @library.World for PackagesWorld with fn file(self, id) {
  if id == self.main.id() {
    @utf8.encode(self.main.text())
  } else {
    packages_file_store.file(id)
  }
}

///|
impl @library.World for PackagesWorld with fn book(_self) {
  packages_font_book()
}

///|
impl @library.World for PackagesWorld with fn font(_self, index) {
  packages_fonts().get(index)
}

///|
impl @library.World for PackagesWorld with fn today(_self, offset) {
  test_today(offset)
}

///|
/// The files of the stage, cached across documents (the packages do not
/// change).
let packages_file_store : FileStore = {
  files: Map([]),
  sources: Map([]),
  load: packages_files_load,
}

///|
/// Load a file of the project or of a package (the oracle's
/// `TestFiles::Packages`).
fn packages_files_load(id : @syntax.FileId) -> Bytes raise @library.FileError {
  let root = match id.root() {
    Project => @kit.FsRoot::new(packages_docs_dir)
    Package(spec) =>
      match @kit.FsPackages::new(packages_dir).obtain(spec) {
        Some(root) => root
        None =>
          raise @library.FileError::Package(
            @library.PackageError::NotFound(spec),
          )
      }
  }
  root.load(id.vpath())
}

///|
/// The library of `typst-cli` without inputs and features.
fn packages_library() -> @library.Library {
  match packages_library_cell.val {
    Some(lib) => lib
    None => {
      let lib = @typst.library_builder([
        @library.html_format(),
        @library.pdf_format(),
        @library.svg_format(),
        @library.png_format(),
        @library.bundle_format(),
      ]).build()
      packages_library_cell.val = Some(lib)
      lib
    }
  }
}

///|
let packages_library_cell : Ref[@library.Library?] = Ref(None)

///|
/// The fonts embedded in the CLI (upstream `typst_assets::fonts()`): the
/// fonts of the test world that come from typst-assets, in order.
fn packages_fonts() -> Array[@library.Font] {
  match packages_fonts_cell.val {
    Some(fonts) => fonts
    None => {
      let fonts = []
      for file in test_font_files() {
        if file.0.has_prefix("typst-assets/") {
          for font in @library.Font::iter(file.1) {
            fonts.push(font)
          }
        }
      }
      packages_fonts_cell.val = Some(fonts)
      fonts
    }
  }
}

///|
let packages_fonts_cell : Ref[Array[@library.Font]?] = Ref(None)

///|
fn packages_font_book() -> @library.FontBook {
  match packages_font_book_cell.val {
    Some(book) => book
    None => {
      let book = @library.FontBook::from_fonts(packages_fonts())
      packages_font_book_cell.val = Some(book)
      book
    }
  }
}

///|
let packages_font_book_cell : Ref[@library.FontBook?] = Ref(None)

///|
/// The tracepoints of a diagnostic (the oracle's `eval::write_trace`).
fn write_world_trace(
  out : StringBuilder,
  world : &@library.World,
  main : @syntax.FileId,
  diag : @library.SourceDiagnostic,
) -> Unit {
  for point in diag.trace {
    let (kind, name) = match point.v {
      Call(name) => ("call", name)
      Show(name) => ("show", Some(name))
      Import(name) => ("import", Some(name))
      Include(name) => ("include", Some(name))
    }
    let name = match name {
      Some(name) => @unicode.rust_debug_str(name)
      None => "-"
    }
    let at = locate(world, main, @syntax.DiagSpan::from_span(point.span))
    out.write_string("  trace \{at} \{kind} \{name}\n")
  }
}

///|
/// The cases of the stage: `(group, name)` for every
/// `<docs>/<group>/<name>.typ`.
fn packages_cases() -> Array[(String, String)] {
  let out = []
  let groups = (@fs.read_dir(packages_docs_dir) catch { _ => [][:] }).to_owned()
  groups.sort_by(@library.compare_str)
  for group in groups {
    let dir = packages_docs_dir + "/" + group
    let is_dir = @fs.is_dir(dir) catch { _ => false }
    if !is_dir {
      continue
    }
    let files = (@fs.read_dir(dir) catch { _ => [][:] }).to_owned()
    files.sort_by(@library.compare_str)
    for file in files {
      if file.has_suffix(".typ") {
        out.push((group, file.unsafe_substring(start=0, end=file.length() - 4)))
      }
    }
  }
  out
}

///|
/// Compile a document; its frames report and its SVG.
fn packages_reports(group : String, name : String) -> (String, String) {
  let rel = "\{group}/\{name}.typ"
  let text = @fs.read_file_to_string(packages_docs_dir + "/" + rel) catch {
    _ => abort("cannot read \{packages_docs_dir}/\{rel}")
  }
  let vpath = @syntax.VirtualPath::new(rel) catch { e => abort(e.to_string()) }
  let source = @syntax.Source::new(
    @syntax.RootedPath::new(Project, vpath).intern(),
    text,
  )
  let main_id = source.id()
  let world : PackagesWorld = { main: source, library: packages_library(), }
  let dyn_world = world as &@library.World
  let enc = FrameEncoder::new(span => encode_world_span(dyn_world, span))
  enc.header(upstream_revision, font_manifest_sha, name)
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = @typst.compile(world)
  let warnings = @typst.deduplicate(warned.warnings)
  let lines = (errors : Array[@library.SourceDiagnostic]) => {
    let buf = StringBuilder()
    for diags in [errors, warnings] {
      for diag in diags {
        write_world_diag(buf, dyn_world, main_id, diag)
        write_world_trace(buf, dyn_world, main_id, diag)
      }
    }
    let text = buf.to_string()
    if text.is_empty() {
      []
    } else {
      text.trim_end(chars="\n").split("\n").map(l => l.to_owned()).collect()
    }
  }
  let svg = match warned.output {
    Ok(doc) => {
      enc.diagnostics("ok", lines([]))
      enc.document(doc)
      @svg.svg_merged(
        doc,
        { render_bleed: false, format: { pretty: Some(true), }, },
        @library.Abs::pt(1.0),
      )
    }
    Err(errors) => {
      enc.diagnostics("err", lines(@typst.deduplicate(errors)))
      "<error>\n"
    }
  }
  enc.end()
  (enc.out.to_string(), svg)
}

///|
/// Run the stage. `--times` also prints the milliseconds per document.
fn run_packages_stage(filter : String?, verbose : Bool, times : Bool) -> Unit {
  let kinds = ["frames", "svg"]
  let passed = [0, 0]
  let failed = [0, 0]
  let mut raw_svg = 0
  let failures = []
  // Without the packages nothing is compared: the summary has no cases then
  // (which `scripts/ci/stages.py` rejects).
  let cases = if @fs.path_exists(packages_dir) {
    packages_cases()
  } else {
    println("packages: \{packages_dir} is missing (run scripts/packages.sh)")
    []
  }
  for c in cases {
    let (group, name) = c
    let rel = "\{group}/\{name}"
    if filter is Some(f) && !rel.contains(f) {
      continue
    }
    if trace_tests.val {
      println("TRACE \{rel}")
    }
    let start = @env.now()
    let (frames, svg) = packages_reports(group, name)
    if times {
      println("TIME \{@env.now() - start} ms \{rel}")
    }
    let actual = [frames, svg]
    for k in 0..<2 {
      let path = "packages/\{kinds[k]}/\{rel}.txt"
      if dump_actual.val {
        let out = "_build/actual/" + path
        ensure_parent_dir(out)
        @fs.write_string_to_file(out, "=== \{name}\n\{actual[k]}") catch {
          _ => ()
        }
      }
      let expected = split_golden(read(golden_dir + "/" + path))
        .get(name)
        .unwrap_or("<missing golden>")
      let ok = if k == 0 {
        actual[k] == expected
      } else {
        if actual[k] == expected {
          raw_svg += 1
        }
        canonicalize_svg_ids(actual[k]) == canonicalize_svg_ids(expected)
      }
      if ok {
        passed[k] += 1
      } else {
        failed[k] += 1
        failures.push((kinds[k], rel, name, expected, actual[k]))
      }
    }
  }
  for f in failures {
    let (kind, rel, name, expected, actual) = f
    println("FAIL \{kind}/\{rel}.typ :: \{name}")
    if verbose {
      println(first_diff(expected, actual))
    }
  }
  for k in 0..<2 {
    println("packages \{kinds[k]}: \{passed[k]} passed, \{failed[k]} failed")
  }
  println("packages svg: \{raw_svg} byte-identical before canonicalization")
}
