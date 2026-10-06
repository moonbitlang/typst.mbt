// The test world, mirroring upstream `tests/src/world.rs` (as adapted in
// `oracle/src/world.rs`).
//
// The oracle runs with the upstream checkout as its working directory, so
// real paths (as shown in file errors) are relative to it. Here, they are
// realized relative to the empty root like in the oracle and only prefixed
// with `upstream_root` for the actual file system access.

///|
/// Root of the upstream checkout (test files are resolved relative to it).
let upstream_root = ".repos/typst"

///|
/// Root of the `typst-dev-assets` files (for `assets/...` paths).
fn dev_assets_root() -> String {
  let home = @env.get_env_vars().get("HOME").unwrap_or("")
  let base = home + "/.cargo/git/checkouts"
  let dirs = (@fs.read_dir(base) catch { _ => [][:] }).to_owned()
  for d in dirs {
    if d.has_prefix("typst-dev-assets-") {
      let revs = (@fs.read_dir(base + "/" + d) catch { _ => [][:] }).to_owned()
      for r in revs {
        return base + "/" + d + "/" + r + "/files"
      }
    }
  }
  ""
}

///|
/// The test world.
priv struct TestWorld {
  main : @syntax.Source
  library : @library.Library
}

///|
/// Create the main source for a test body at a path relative to the upstream
/// checkout, like upstream `parse_test_body`.
fn TestWorld::main_source(path : String, body : String) -> @syntax.Source {
  let vpath = @syntax.VirtualPath::virtualize("", path) catch {
    e => abort(e.to_string())
  }
  @syntax.Source::new(@syntax.RootedPath::new(Project, vpath).intern(), body)
}

///|
impl @library.World for TestWorld with fn library(self) {
  self.library
}

///|
impl @library.World for TestWorld with fn main(self) {
  self.main.id()
}

///|
impl @library.World for TestWorld with fn source(self, id) {
  if id == self.main.id() {
    self.main
  } else {
    file_store.source(id)
  }
}

///|
impl @library.World for TestWorld with fn file(self, id) {
  if id == self.main.id() {
    @utf8.encode(self.main.text())
  } else {
    file_store.file(id)
  }
}

///|
impl @library.World for TestWorld with fn book(_self) {
  test_font_book()
}

///|
impl @library.World for TestWorld with fn font(_self, index) {
  test_fonts().get(index)
}

///|
impl @library.World for TestWorld with fn today(_self, offset) {
  // Like upstream's test world: `typst_kit::datetime::Time::fixed` at
  // 1970-01-01 12:00:00 UTC, shifted by the offset.
  let now = 12L * 3600L
  let with_offset = match offset {
    None => now
    Some(offset) => {
      let seconds = offset.seconds().trunc()
      // Check whether we can convert seconds from f64 to i32.
      if seconds.is_nan() ||
        seconds.is_inf() ||
        seconds < -2147483648.0 ||
        seconds > 2147483647.0 {
        return None
      }
      // `FixedOffset::east_opt` only accepts offsets below one day.
      let seconds = seconds.to_int64()
      if seconds <= -86400L || seconds >= 86400L {
        return None
      }
      now + seconds
    }
  }
  let days = if with_offset >= 0L {
    with_offset / 86400L
  } else {
    (with_offset - 86399L) / 86400L
  }
  let (year, month, day) = civil_from_days(days)
  @library.Datetime::from_ymd(year, month, day)
}

///|
/// The proleptic Gregorian date of a day count since 1970-01-01.
fn civil_from_days(days : Int64) -> (Int, Int, Int) {
  let z = days + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = if mp < 10L { mp + 3L } else { mp - 9L }
  let y = if m <= 2L { y + 1L } else { y }
  (y.to_int(), m.to_int(), d.to_int())
}

///|
/// Caches loaded files and sources (upstream `typst_kit::files::FileStore`).
priv struct FileStore {
  files : Map[@syntax.FileId, Result[Bytes, @library.FileError]]
  sources : Map[@syntax.FileId, Result[@syntax.Source, @library.FileError]]
}

///|
let file_store : FileStore = { files: Map([]), sources: Map([]), }

///|
fn FileStore::file(
  self : FileStore,
  id : @syntax.FileId,
) -> Bytes raise @library.FileError {
  let result = match self.files.get(id) {
    Some(result) => result
    None => {
      let result = try test_files_load(id) catch {
        e => Err(e)
      } noraise {
        bytes => Ok(bytes)
      }
      self.files[id] = result
      result
    }
  }
  match result {
    Ok(bytes) => bytes
    Err(e) => raise e
  }
}

///|
fn FileStore::source(
  self : FileStore,
  id : @syntax.FileId,
) -> @syntax.Source raise @library.FileError {
  let result = match self.sources.get(id) {
    Some(result) => result
    None => {
      let result = try {
        let bytes = self.file(id)
        // Strip a UTF-8 BOM like upstream.
        let view = if bytes.length() >= 3 &&
          bytes[0] == b'\xef' &&
          bytes[1] == b'\xbb' &&
          bytes[2] == b'\xbf' {
          bytes[3:]
        } else {
          bytes[:]
        }
        let text = @utf8.decode(view) catch {
          _ => raise @library.FileError::InvalidUtf8
        }
        @syntax.Source::new(id, text)
      } catch {
        e => Err(e)
      } noraise {
        source => Ok(source)
      }
      self.sources[id] = result
      result
    }
  }
  match result {
    Ok(source) => source
    Err(e) => raise e
  }
}

///|
/// Resolve a file id to a real path relative to the upstream checkout
/// (upstream `TestFiles::resolve`).
fn test_files_resolve(id : @syntax.FileId) -> String raise @library.FileError {
  let root = match id.root() {
    Project => ""
    Package(spec) => {
      guard spec.namespace == "test" else {
        abort("unexpected package namespace")
      }
      "tests/packages/\{spec.name}-\{spec.version}"
    }
  }
  id.vpath().realize(root) catch {
    e => raise @library.FileError::Realize(e)
  }
}

///|
let dev_assets_index : Ref[Map[String, String]?] = { val: None, }

///|
/// The dev assets by file name (fonts excluded; the first in directory
/// order wins).
fn dev_assets_by_name() -> Map[String, String] {
  if dev_assets_index.val is Some(index) {
    return index
  }
  let index : Map[String, String] = Map([])
  fn walk(dir : String) {
    let entries = (@fs.read_dir(dir) catch { _ => [][:] }).to_owned()
    entries.sort()
    for entry in entries {
      let path = dir + "/" + entry
      let is_dir = @fs.is_dir(path) catch { _ => false }
      if is_dir {
        if entry != "fonts" {
          walk(path)
        }
      } else if !index.contains(entry) {
        index[entry] = path
      }
    }
  }

  walk(dev_assets_root())
  dev_assets_index.val = Some(index)
  index
}

///|
/// Load a file (upstream `FileLoader for TestFiles`).
fn test_files_load(id : @syntax.FileId) -> Bytes raise @library.FileError {
  let path = test_files_resolve(id)
  // The examples of the documentation (the `edsl-suite` stage) name their
  // files like upstream's example world: a dev asset by its file name.
  if path.has_prefix("docs-examples/") {
    let name = match path.rev_find("/") {
      Some(i) => path.view(start_offset=i + 1).to_owned()
      None => path
    }
    guard dev_assets_by_name().get(name) is Some(real) else {
      raise @library.FileError::NotFound(path)
    }
    return @fs.read_file_to_bytes(real) catch {
      _ => raise @library.FileError::NotFound(path)
    }
  }
  if path.has_prefix("assets/") {
    let real = dev_assets_root() +
      "/" +
      path.unsafe_substring(start=7, end=path.length())
    return @fs.read_file_to_bytes(real) catch {
      _ => raise @library.FileError::NotFound(path)
    }
  }
  let real = upstream_root + "/" + path
  if !@fs.path_exists(real) {
    raise @library.FileError::NotFound(path)
  }
  let is_dir = @fs.is_dir(real) catch { _ => false }
  if is_dir {
    raise @library.FileError::IsDirectory
  }
  @fs.read_file_to_bytes(real) catch {
    _ => raise @library.FileError::AccessDenied
  }
}

///|
let test_library_cell : Ref[@library.Library?] = Ref(None)

///|
/// The library with test-only definitions.
fn test_library() -> @library.Library {
  match test_library_cell.val {
    Some(lib) => lib
    None => {
      let formats = [
        @library.html_format(),
        @library.pdf_format(),
        @library.svg_format(),
        @library.png_format(),
        @library.bundle_format(),
      ]
      let lib = @typst.library_builder(formats)
        .with_features(@library.Features::all())
        .with_global(define_test_globals)
        .build()
      define_test_colors(lib)
      define_test_styles(lib)
      test_library_cell.val = Some(lib)
      lib
    }
  }
}

///|
/// Set the test styles (small pages, like upstream's test world).
fn define_test_styles(lib : @library.Library) -> Unit {
  let pt = (v : Double) => @library.Length::from_abs(@library.Abs::pt(v))
  lib.styles.push(@library.PageElem::set_width(Custom(pt(120.0))))
  lib.styles.push(@library.PageElem::set_height(Auto))
  lib.styles.push(
    @library.PageElem::set_margin(
      Custom(
        @library.Margin::splat(Some(Custom(@library.Rel::from_abs(pt(10.0))))),
      ),
    ),
  )
  lib.styles.push(@library.TextElem::set_size(@library.TextSize(pt(10.0))))
}

///|
/// Define the test colors (`conifer`, `forest`, `check.red`).
///
/// The oracle constructs them natively with `Color::from_u8`; here they are
/// evaluated from equivalent code so that the test world does not depend on
/// the internals of the color port. Colors that cannot be evaluated yet are
/// left undefined.
fn define_test_colors(lib : @library.Library) -> Unit {
  let world : TestWorld = { main: @syntax.Source::detached(""), library: lib, }
  let engine : @library.Engine = {
    world,
    library: lib,
    introspector: @library.Introspector::empty(),
    traced: @library.Traced::new(),
    sink: @library.Sink::new(),
    route: @library.Route::root(),
  }
  let color = (code : String) => {
    let value = @eval.eval_string(
      engine,
      @library.Context::none(),
      code,
      @syntax.Span::detached(),
      Code,
      @library.Scope::new(),
    ) catch {
      _ => return None
    }
    if value is Color(_) {
      Some(value)
    } else {
      None
    }
  }
  let global = lib.global.scope()
  if color("rgb(\"#9feb52\")") is Some(v) {
    global.define("conifer", v) |> ignore
  }
  if color("rgb(\"#43a127\")") is Some(v) {
    global.define("forest", v) |> ignore
  }
  if color("red") is Some(v) &&
    global.get("check") is Some(binding) &&
    binding.value is Module(check) {
    check.scope().define("red", v) |> ignore
  }
}

///|
fn define_test_globals(scope : @library.Scope) -> Unit {
  let check = @library.Scope::new()
  check
  .define("deprecated", None)
  .with_deprecation(
    @library.Deprecation::new().with_message("this value is useless"),
  )
  |> ignore
  check.define("gated", None).with_feature(Html) |> ignore
  scope.define("check", Module(@library.Module::new("check", check))) |> ignore
  let test_scope = () => {
    let s = @library.Scope::new()
    s
    .define_func(@library.native_func("deprecated", (_, _, _) => None))
    .with_deprecation(
      @library.Deprecation::new().with_message("this function is useless"),
    )
    |> ignore
    s
    .define_func(@library.native_func("gated", (_, _, _) => None))
    .with_feature(Html)
    |> ignore
    s
  }
  scope.define_func(
    @library.native_func("test", scope=test_scope, (_, _, args) => {
      let lhs : @library.Value = args.expect("lhs")
      let rhs : @library.Value = args.expect("rhs")
      args.take().finish()
      if lhs != rhs {
        @library.bail_at(
          args.span,
          "Assertion failed: \{lhs.repr()} != \{rhs.repr()}",
        )
      }
      None
    }),
  )
  |> ignore
  scope.define_func(
    @library.native_func("test-repr", (_, _, args) => {
      let lhs : @library.Value = args.expect("lhs")
      let rhs : @library.Value = args.expect("rhs")
      args.take().finish()
      if lhs.repr() != rhs.repr() {
        @library.bail_at(
          args.span,
          "Assertion failed: \{lhs.repr()} != \{rhs.repr()}",
        )
      }
      None
    }),
  )
  |> ignore
  scope.define_func(
    @library.native_func("print", (_, _, args) => {
      let _ : Array[@library.Value] = args.all()
      args.take().finish()
      None
    }),
  )
  |> ignore
  // Generates `count` lines of text based on the numbering.
  scope.define_func(
    @library.native_func("lines", (engine, context, args) => {
      let count : @library.U64 = args.expect("count")
      let numbering : @library.Numbering = match args.eat() {
        Some(numbering) => numbering
        None =>
          Pattern(
            @library.NumberingPattern::from_str("A") catch {
              _ => abort("valid pattern")
            },
          )
      }
      args.take().finish()
      let span = args.span
      // `(1..=count).map(..).collect::<Array>().join(Some("\n"), None, None)`
      let values = []
      for n in 1L..<=count.get() {
        values.push(numbering.apply(engine, context, span, [n]))
      }
      @library.at(span, () => {
        let mut result : @library.Value = None
        for i, value in values {
          if i > 0 {
            result = @library.join(result, Str("\n"))
          }
          result = @library.join(result, value)
        }
        result
      })
    }),
  )
  |> ignore
  scope.define_func(
    @library.native_func("bounds", (_, _, args) => {
      let content : @library.Content = args.expect("content")
      args.take().finish()
      // Upstream wraps the content in a block with a custom multi-layouter
      // body (`layout_bounds`), which reprs as `block(body: auto)`.
      Content(
        @library.BlockElem::multi_layouter_content(content, (
          body,
          engine,
          locator,
          styles,
          regions,
        ) => {
          let fragment = @layout.layout_fragment(
            engine, body, locator, styles, regions,
          )
          for frame in fragment.iter() {
            frame.mark_box_in_place()
          }
          fragment
        }).pack(),
      )
    }),
  )
  |> ignore
}

///|
/// Evaluate a test case in the oracle's report format.
fn eval_report(rel : String, tc : TestCase) -> String {
  let source = TestWorld::main_source("tests/suite/" + rel, tc.body)
  let id = source.id()
  let library = test_library()
  let features = parse_features(tc.attrs)
  let library = match features {
    Some(f) => { ..library, features: f, }
    None => library
  }
  let world : TestWorld = { main: source, library, }
  let sink = @library.Sink::new()
  let out = StringBuilder()
  try
    @eval.eval_source(
      world,
      library,
      @library.Traced::new(),
      sink,
      @library.Route::root(),
      source,
    )
  catch {
    @library.SourceError(errors) => {
      out.write_string("err\n")
      for diag in @typst.deduplicate(errors) {
        write_source_diag(out, world, id, diag)
      }
    }
  } noraise {
    module => out.write_string("ok \{module.content().repr()}\n")
  }
  for diag in sink.warnings {
    write_source_diag(out, world, id, diag)
  }
  out.to_string()
}

///|
fn parse_features(attrs : String) -> @library.Features? {
  for attr in attrs.split(" ") {
    let attr = attr.to_owned()
    if attr.has_prefix("features(") && attr.has_suffix(")") {
      let inner = attr.unsafe_substring(start=9, end=attr.length() - 1)
      let list = []
      for p in inner.split(",") {
        let p = p.trim(chars=" ").to_owned()
        if @library.Feature::from_str(p) is Some(f) {
          list.push(f)
        }
      }
      return Some(@library.Features(list))
    }
  }
  None
}

///|
fn write_source_diag(
  out : StringBuilder,
  world : TestWorld,
  main : @syntax.FileId,
  diag : @library.SourceDiagnostic,
) -> Unit {
  let severity = match diag.severity {
    Error => "error"
    Warning => "warning"
  }
  out.write_string(
    "\{severity} \{locate(world, main, diag.span)} \{@unicode.rust_debug_str(diag.message)}\n",
  )
  for hint in diag.hints {
    out.write_string(
      "  hint \{locate(world, main, hint.span)} \{@unicode.rust_debug_str(hint.v)}\n",
    )
  }
}

///|
fn locate(
  world : TestWorld,
  main : @syntax.FileId,
  span : @syntax.DiagSpan,
) -> String {
  let (id, start, end) = match span.get() {
    Detached => return "-"
    Number(id~, num~, sub_range~) => {
      let source = (world as &@library.World).source(id) catch {
        _ => return "?"
      }
      match source.range(num, sub_range) {
        Some((s, e)) => (id, s, e)
        None => return "?"
      }
    }
    Range(id~, start~, end~) => (id, start, end)
  }
  if id == main {
    "\{start}..\{end}"
  } else {
    let p = id.vpath().get_without_slash()
    "\{@unicode.rust_debug_str(p)}:\{start}..\{end}"
  }
}

///|
/// Compile a test case to HTML in the oracle's report format (see
/// `oracle/src/html.rs`).
fn html_report(rel : String, tc : TestCase) -> String {
  let source = TestWorld::main_source("tests/suite/" + rel, tc.body)
  let main_id = source.id()
  let library = test_library()
  let library = match parse_features(tc.attrs) {
    Some(f) => { ..library, features: f, }
    None => library
  }
  let world : TestWorld = { main: source, library, }
  let warned : @library.Warned[
    Result[@html.HtmlDocument, Array[@library.SourceDiagnostic]],
  ] = @typst.compile(world)
  let out = StringBuilder()
  match warned.output {
    Ok(doc) =>
      try
        @html.html(doc, {
          format: @library.PartialHtmlFormatOptions::{ pretty: Some(true), },
        })
      catch {
        @library.SourceError(errors) => {
          out.write_string("err\n")
          for diag in @typst.deduplicate(errors) {
            write_source_diag(out, world, main_id, diag)
          }
        }
      } noraise {
        html => {
          out.write_string("ok\n")
          out.write_string(html)
          if !html.has_suffix("\n") {
            out.write_char('\n')
          }
        }
      }
    Err(errors) => {
      out.write_string("err\n")
      for diag in errors {
        write_source_diag(out, world, main_id, diag)
      }
    }
  }
  for diag in @typst.deduplicate(warned.warnings) {
    write_source_diag(out, world, main_id, diag)
  }
  out.to_string()
}
