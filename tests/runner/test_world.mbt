// The test world, mirroring upstream `tests/src/world.rs` (as adapted in
// `oracle/src/world.rs`).

///|
/// Root of the upstream checkout (test files are resolved relative to it).
let upstream_root = ".repos/typst"

///|
/// Root of the `typst-dev-assets` files (for `/assets/...` paths).
fn dev_assets_root() -> String {
  let home = @env.get_env_vars().get("HOME").unwrap_or("")
  let base = home + "/.cargo/git/checkouts"
  let dirs = (@fs.read_dir(base) catch { _ => [][:] }).to_array()
  for d in dirs {
    if d.has_prefix("typst-dev-assets-") {
      let revs = (@fs.read_dir(base + "/" + d) catch { _ => [][:] }).to_array()
      for r in revs {
        return base + "/" + d + "/" + r + "/files"
      }
    }
  }
  ""
}

///|
/// Interns virtual paths (absolute, with leading slash) into file ids.
priv struct PathInterner {
  ids : Map[String, @syntax.FileId]
  paths : Array[String]
}

///|
let interner : PathInterner = { ids: {}, paths: [""], }

///|
fn intern_path(vpath : String) -> @syntax.FileId {
  match interner.ids.get(vpath) {
    Some(id) => id
    None => {
      let id = @syntax.FileId(interner.paths.length().to_uint16())
      interner.paths.push(vpath)
      interner.ids[vpath] = id
      id
    }
  }
}

///|
fn path_of(id : @syntax.FileId) -> String {
  interner.paths[id.0.to_int()]
}

///|
/// Normalize a virtual path (resolve `.` and `..`).
fn normalize_vpath(path : String) -> String {
  let parts = []
  for part in path.split("/") {
    let part = part.to_string()
    match part {
      "" | "." => ()
      ".." => parts.pop() |> ignore
      p => parts.push(p)
    }
  }
  "/" + parts.join("/")
}

///|
/// The test world.
priv struct TestWorld {
  main : @syntax.Source
  library : @library.Library
  sources : Map[Int, @syntax.Source]
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
    return self.main
  }
  match self.sources.get(id.0.to_int()) {
    Some(s) => s
    None => {
      let bytes = load_file(path_of(id))
      let text = @utf8.decode(bytes) catch {
        _ => raise @library.FileError::InvalidUtf8
      }
      let source = @syntax.Source::new(id, text)
      self.sources[id.0.to_int()] = source
      source
    }
  }
}

///|
impl @library.World for TestWorld with fn file(self, id) {
  if id == self.main.id() {
    return @utf8.encode(self.main.text())
  }
  load_file(path_of(id))
}

///|
impl @library.World for TestWorld with fn today(_self, _offset) {
  None
}

///|
impl @library.World for TestWorld with fn resolve_path(_self, within, path) {
  let base = match within {
    Some(id) => {
      let p = path_of(id)
      match p.rev_find("/") {
        Some(i) => p.unsafe_substring(start=0, end=i)
        None => ""
      }
    }
    None => ""
  }
  let full = if path.has_prefix("/") { path } else { base + "/" + path }
  intern_path(normalize_vpath(full))
}

///|
impl @library.World for TestWorld with fn file_stem(_self, id) {
  let p = path_of(id)
  let name = match p.rev_find("/") {
    Some(i) => p.unsafe_substring(start=i + 1, end=p.length())
    None => p
  }
  match name.rev_find(".") {
    Some(i) if i > 0 => name.unsafe_substring(start=0, end=i)
    _ => name
  }
}

///|
fn load_file(vpath : String) -> Bytes raise @library.FileError {
  let real = if vpath.has_prefix("/assets/") {
    dev_assets_root() + vpath.unsafe_substring(start=7, end=vpath.length())
  } else {
    upstream_root + vpath
  }
  let is_dir = @fs.is_dir(real) catch { _ => false }
  if is_dir {
    raise @library.FileError::IsDirectory
  }
  @fs.read_file_to_bytes(real) catch {
    _ => raise @library.FileError::NotFound(real)
  }
}

///|
let test_library_cell : Ref[@library.Library?] = Ref::new(None)

///|
/// The library with test-only definitions.
fn test_library() -> @library.Library {
  match test_library_cell.val {
    Some(lib) => lib
    None => {
      let routines : @library.Routines = {
        eval_string: @eval.routines_eval_string(),
        eval_closure: @eval.routines_eval_closure(),
      }
      let lib = @library.Library::builder(routines)
        .with_global(define_test_globals)
        .build()
      test_library_cell.val = Some(lib)
      lib
    }
  }
}

///|
fn define_test_globals(scope : @library.Scope) -> Unit {
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
  let check = @library.Scope::new()
  check
  .define("deprecated", None)
  .with_deprecation(
    @library.Deprecation::new().with_message("this value is useless"),
  )
  |> ignore
  check.define("gated", None).with_feature(Html) |> ignore
  scope.define("check", Module(@library.Module::new("check", check))) |> ignore
}

///|
/// Evaluate a test case in the oracle's report format.
fn eval_report(rel : String, tc : TestCase) -> String {
  let vpath = "/tests/suite/" + rel
  let id = intern_path(vpath)
  let source = @syntax.Source::new(id, tc.body)
  let library = test_library()
  let features = parse_features(tc.attrs)
  let library = match features {
    Some(f) => { ..library, features: f, }
    None => library
  }
  let world : TestWorld = { main: source, library, sources: {}, }
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
      for diag in deduplicate(errors) {
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
    let attr = attr.to_string()
    if attr.has_prefix("features(") && attr.has_suffix(")") {
      let inner = attr.unsafe_substring(start=9, end=attr.length() - 1)
      let list = []
      for p in inner.split(",") {
        let p = p.trim(chars=" ").to_string()
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
fn deduplicate(
  diags : Array[@library.SourceDiagnostic],
) -> Array[@library.SourceDiagnostic] {
  let seen : Map[String, Unit] = {}
  let out = []
  for d in diags {
    let key = "\{d.span.span.0}/\{d.span.extra}/\{d.message}"
    if !seen.contains(key) {
      seen[key] = ()
      out.push(d)
    }
  }
  out
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
    let p = path_of(id)
    "\{@unicode.rust_debug_str(p.unsafe_substring(start=1, end=p.length()))}:\{start}..\{end}"
  }
}
