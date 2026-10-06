// The `paged` stage (see `oracle/src/paged.rs`): compile every test that the
// upstream runner compiles to a `PagedDocument` (attributes `paged`, `pdf`
// or `pdftags`; files starting with `// SKIP` excluded) and dump the
// document in the `typst-frame-v1` format.

///|
/// Whether the upstream runner compiles a test to a paged document.
fn is_paged(attrs : String) -> Bool {
  attrs
  .split(" ")
  .any(a => {
    let name = match a.find("(") {
      Some(i) => a.view(end_offset=i)
      None => a
    }
    name == "paged" || name == "pdf" || name == "pdftags"
  })
}

///|
/// The pinned upstream revision (`UPSTREAM_REV`).
let upstream_revision : String = read("UPSTREAM_REV").trim().to_owned()

///|
/// The SHA-256 of the font manifest (`tests/golden/fonts.json`).
let font_manifest_sha : String = {
  let text = read("tests/golden/fonts.json")
  sha256_hex(@utf8.encode(text)[:])
}

///|
/// Compile a single test case to a paged document and encode it.
fn paged_report(rel : String, tc : TestCase) -> String {
  let source = TestWorld::main_source("tests/suite/" + rel, tc.body)
  let main_id = source.id()
  let library = test_library()
  let library = match parse_features(tc.attrs) {
    Some(f) => { ..library, features: f, }
    None => library
  }
  let world : TestWorld = { main: source, library, }
  let enc = FrameEncoder::new(span => encode_span(world, span))
  enc.header(upstream_revision, font_manifest_sha, tc.name)
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = @typst.compile(world)
  let warnings = @typst.deduplicate(warned.warnings)
  let lines = (errors : Array[@library.SourceDiagnostic]) => {
    let buf = StringBuilder()
    for diag in errors {
      write_source_diag(buf, world, main_id, diag)
    }
    for diag in warnings {
      write_source_diag(buf, world, main_id, diag)
    }
    let text = buf.to_string()
    if text.is_empty() {
      []
    } else {
      text.trim_end(chars="\n").split("\n").map(l => l.to_owned()).collect()
    }
  }
  match warned.output {
    Ok(doc) => {
      enc.diagnostics("ok", lines([]))
      enc.document(doc)
    }
    Err(errors) => enc.diagnostics("err", lines(@typst.deduplicate(errors)))
  }
  enc.end()
  enc.out.to_string()
}

///|
/// A span as `null` (detached) or `[path,start,end]` (`null`s if the range
/// cannot be resolved).
fn encode_span(world : TestWorld, span : @syntax.Span) -> String {
  let diag = @syntax.DiagSpan::from_span(span)
  match diag.get() {
    Detached => "null"
    Number(id~, num~, sub_range~) => {
      let path = json_str(file_path(id))
      let range = try (world as &@library.World).source(id) catch {
        _ => None
      } noraise {
        source => source.range(num, sub_range)
      }
      match range {
        Some((s, e)) => array([path, s.to_string(), e.to_string()])
        None => array([path, "null", "null"])
      }
    }
    Range(id~, start~, end~) =>
      array([json_str(file_path(id)), start.to_string(), end.to_string()])
  }
}

///|
/// The repository-relative virtual path of a file.
fn file_path(id : @syntax.FileId) -> String {
  let path = id.vpath().get_without_slash()
  match id.root() {
    Project => path
    Package(spec) => "@\{spec.namespace_}/\{spec.name}:\{spec.version}/\{path}"
  }
}
