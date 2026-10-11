// The tracked world (`library/tracked_world.mbt`) through whole
// compilations: the world reads that entries of the three stores keep,
// under the recording check (`@library.set_memo_check`: every result that
// is kept is computed a second time from scratch, and its entry must hold
// exactly what that run asked of the world), and what a scope is.

///|
/// A world with sources and data files that a test changes.
priv struct ReadingWorld {
  main : @syntax.Source
  library : @library.Library
  sources : Map[@syntax.FileId, @syntax.Source]
  data : Map[@syntax.FileId, Bytes]
}

///|
impl @library.World for ReadingWorld with fn library(self) {
  self.library
}

///|
impl @library.World for ReadingWorld with fn main(self) {
  self.main.id()
}

///|
impl @library.World for ReadingWorld with fn source(self, id) {
  if id == self.main.id() {
    return self.main
  }
  match self.sources.get(id) {
    Some(source) => source
    None => raise @library.FileError::NotFound(id.vpath().get_without_slash())
  }
}

///|
impl @library.World for ReadingWorld with fn file(self, id) {
  match self.data.get(id) {
    Some(data) => data
    None => raise @library.FileError::NotFound(id.vpath().get_without_slash())
  }
}

///|
impl @library.World for ReadingWorld with fn today(_, _) {
  None
}

///|
fn reading_id(path : String) -> @syntax.FileId {
  let vpath = @syntax.VirtualPath::new(path) catch {
    _ => abort("invalid path")
  }
  @syntax.RootedPath::new(Project, vpath).intern()
}

///|
fn reading_world(
  text : String,
  sources? : Array[(String, String)] = [],
  data? : Array[(String, String)] = [],
  library? : @library.Library = library([]),
) -> ReadingWorld {
  let world : ReadingWorld = {
    main: @syntax.Source::detached(text),
    library,
    sources: Map([]),
    data: Map([]),
  }
  for file in sources {
    let id = reading_id(file.0)
    world.sources[id] = @syntax.Source::new(id, file.1)
  }
  for file in data {
    world.data[reading_id(file.0)] = @utf8.encode(file.1)
  }
  world
}

///|
/// What a compilation under the recording check gave: the text of the
/// pages (or the errors), the warnings, the number of entries that were
/// checked and the entries whose reads are not those of a run from
/// scratch.
priv struct Checked {
  text : String
  warnings : Array[String]
  entries : Int
  differ : Array[String]
}

///|
fn checked_compile(world : ReadingWorld) -> Checked {
  @library.set_memo_check(true)
  defer @library.set_memo_check(false)
  @library.take_memo_check_report() |> ignore
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = compile(world)
  let text = match warned.output {
    Ok(document) => {
      let texts = []
      for
        elem in document
        .introspector()
        .query(Elem(@library.metadata_elem(), None)) {
        if @library.MetadataElem::of(elem) is Some(metadata) {
          texts.push(metadata.value().repr())
        }
      }
      texts.join(" ")
    }
    Err(errors) => "error: " + errors.map(e => e.message).join(" | ")
  }
  let (entries, differ) = @library.take_memo_check_report()
  { text, warnings: warned.warnings.map(w => w.message), entries, differ, }
}

///|
test "recording: a module's reads are those of the call that imports it, computed or found" {
  // `f` imports a module that the main file has evaluated already: the
  // call finds the module, and its entry has what the module read.
  let world = reading_world(
    "#import \"a.typ\": x\n#let f() = { import \"a.typ\": x; x }\n#metadata(f() + f() + x)",
    sources=[("a.typ", "#let x = read(\"d.txt\")\n")],
    data=[("d.txt", "one")],
  )
  let checked = checked_compile(world)
  inspect(checked.text, content="\"oneoneone\"")
  inspect(checked.differ.join("\n"), content="")
  assert_true(checked.entries >= 2)
  // The other way round: the call evaluates the module, the main file
  // finds it.
  let world = reading_world(
    "#let f() = { import \"a.typ\": x; x }\n#let y = f()\n#import \"a.typ\": x\n#metadata(y + x)",
    sources=[("a.typ", "#let x = read(\"d.txt\")\n")],
    data=[("d.txt", "one")],
  )
  let checked = checked_compile(world)
  inspect(checked.text, content="\"oneone\"")
  inspect(checked.differ.join("\n"), content="")
}

///|
test "recording: a module that failed is found with its reads" {
  // Errors inside `context` are delayed, so the blocks are laid out and
  // kept (a block realizes its body inside its layout; the `context` of a
  // paragraph at the top level runs before the paragraph is laid out, in
  // no memoized call). The second block finds the kept error of the
  // module; both have the module's reads, the failed one among them.
  let world = reading_world(
    "#block[A #context { import \"bad.typ\": x; x }]\n\n#block[B #context { import \"bad.typ\": x; [again] }]",
    sources=[("bad.typ", "#let x = read(\"missing.txt\")\n")],
  )
  let checked = checked_compile(world)
  inspect(
    checked.text,
    content="error: file not found (searched at missing.txt)",
  )
  inspect(checked.differ.join("\n"), content="")
  assert_true(checked.entries >= 2)
}

///|
test "recording: a module that failed at the top level is checked too" {
  // No memoized call is around the import: the entry of the module, which
  // keeps the error, is the only one that has the read.
  let world = reading_world("#import \"bad.typ\": x\n#x", sources=[
    ("bad.typ", "#let x = read(\"missing.txt\")\n"),
  ])
  let checked = checked_compile(world)
  inspect(
    checked.text,
    content="error: file not found (searched at missing.txt)",
  )
  inspect(checked.differ.join("\n"), content="")
  inspect(checked.entries, content="1")
}

///|
test "recording: the second run of the check sees the modules of the first" {
  // Modules compare by identity. The call that is repeated holds the
  // module of the first run in its argument; the import inside it must
  // give that module again, or the repeated call reads another file.
  let world = reading_world(
    (
      #|#import "m.typ" as m
      #|#let f(m) = {
      #|  import "m.typ" as n
      #|  if m == n { read("a.txt") } else { read("b.txt") }
      #|}
      #|#metadata(f(m))
    ),
    sources=[("m.typ", "#let x = 1\n")],
    data=[("a.txt", "the same"), ("b.txt", "another")],
  )
  let checked = checked_compile(world)
  inspect(checked.text, content="\"the same\"")
  inspect(checked.differ.join("\n"), content="")
  assert_true(checked.entries >= 2)
}

///|
test "recording: reads at every level, of files that are there and files that are not" {
  let world = reading_world(
    (
      #|#let pick(name) = read(name)
      #|#let both() = pick("d.txt") + pick("e.txt")
      #|#let guarded() = block(context { let v = read("missing.txt"); v })
      #|#metadata(both() + both())
      #|#context metadata(pick("d.txt"))
      #|
      #|#guarded()
      #|
      #|#guarded()
    ),
    data=[("d.txt", "one"), ("e.txt", "two")],
  )
  let checked = checked_compile(world)
  assert_true(checked.text.has_prefix("error: file not found"))
  inspect(checked.differ.join("\n"), content="")
  assert_true(checked.entries >= 4)
}

///|
test "recording: a function that reads a file, called from the history of a document that does not converge" {
  // The update function runs inside `History::compute`, whose engines
  // hold the compilation's tracked world.
  let world = reading_world(
    (
      #|#let c = counter("c")
      #|#let add() = int(read("d.txt"))
      #|#context {
      #|  let n = c.final().first()
      #|  c.update(m => m + n + add())
      #|}
      #|#context metadata(c.final().first())
    ),
    data=[("d.txt", "1")],
  )
  let checked = checked_compile(world)
  assert_true(
    checked.warnings.contains("document did not converge within five attempts"),
  )
  inspect(checked.differ.join("\n"), content="")
  assert_true(checked.entries >= 1)
}

///|
test "recording: the manifest of a package is a read of the call that imports it" {
  let world = reading_world(
    (
      #|#let f() = { import "@preview/example:0.1.0": x; x }
      #|#metadata(f() + f())
    ),
    data=[("d.txt", "one")],
  )
  let spec = @syntax.PackageSpec::from_str("@preview/example:0.1.0").unwrap()
  let in_package = (path : String) => {
    let vpath = @syntax.VirtualPath::new(path) catch {
      _ => abort("invalid path")
    }
    @syntax.RootedPath::new(Package(spec), vpath).intern()
  }
  world.data[in_package("typst.toml")] = @utf8.encode(
    (
      #|[package]
      #|name = "example"
      #|version = "0.1.0"
      #|entrypoint = "lib.typ"
      #|
    ),
  )
  let lib = in_package("lib.typ")
  world.sources[lib] = @syntax.Source::new(lib, "#let x = \"in the package\"\n")
  let checked = checked_compile(world)
  inspect(checked.text, content="\"in the packagein the package\"")
  inspect(checked.differ.join("\n"), content="")
  assert_true(checked.entries >= 1)
}

///|
/// Evaluates code outside of a compilation, as `typst eval` does.
fn evaluated_code(world : ReadingWorld, code : String) -> String {
  let engine : @library.Engine = {
    world: @library.TrackedWorld::new(world),
    library: world.library,
    introspector: @library.Introspector::empty(),
    traced: @library.Traced::new(),
    sink: @library.Sink::new(),
    route: @library.Route::root(),
  }
  try
    @eval.eval_string(
      engine,
      @library.Context::none(),
      code,
      world.main.root().span(),
      Code,
      @library.Scope::new(),
    )
  catch {
    @library.SourceError(errors) =>
      "error: " + errors.map(e => e.message).join(" | ")
  } noraise {
    value => value.repr()
  }
}

///|
/// The text a world's main file evaluates to in a compilation in which the
/// file `changing` changes during the scope.
fn evaluated_with_volatile(world : ReadingWorld, changing : String) -> String {
  let sink = @library.Sink::new()
  let traced = @library.Traced::new()
  let file = reading_id(changing)
  try
    compile_with(
      world,
      traced,
      sink,
      (tracked, library) => {
        @eval.eval_source(
          tracked,
          library,
          traced,
          sink,
          @library.Route::root(),
          world.main,
        ).content()
      },
      volatile_files=id => id == file,
    )
  catch {
    @library.SourceError(errors) =>
      "error: " + errors.map(e => e.message).join(" | ")
  } noraise {
    Texted(text) => text
  }
}

///|
test "volatile files: the module of a file that changes during the scope is not kept" {
  // A file is evaluated once in a compilation, so two imports of it are
  // one module. Not if it is declared to change during the compilation:
  // its source is read before the reads of a module entry start, so no
  // entry is looked up or stored for it, and every import evaluates what
  // the world hands out then.
  let source = "#import \"v.typ\" as a\n#import \"v.typ\" as b\n#(a == b)"
  let files = [("v.typ", "#let x = 1\n")]
  inspect(
    evaluated_with_volatile(reading_world(source, sources=files), "other.typ"),
    content="true",
  )
  inspect(
    evaluated_with_volatile(reading_world(source, sources=files), "v.typ"),
    content="false",
  )
}

///|
test "scopes: an evaluated string outside of a compilation is a scope of its own" {
  let world = reading_world(
    "",
    sources=[("a.typ", "#let x = read(\"d.txt\")\n")],
    data=[("d.txt", "one")],
  )
  let code = "{ import \"a.typ\" as a; import \"a.typ\" as b; (a.x, a == b) }"
  inspect(evaluated_code(world, code), content="(\"one\", true)")
  // The data file that the module read changes: the module of the
  // evaluation before is not found.
  world.data[reading_id("d.txt")] = @utf8.encode("two")
  inspect(evaluated_code(world, code), content="(\"two\", true)")
}

///|
test "scopes: a compilation inside a host function has its own answers, and is not kept" {
  // The inner world has the same sources and another data file.
  let inner = reading_world("#metadata(read(\"d.txt\"))", data=[
    ("d.txt", "inner"),
  ])
  let compile_inner : @library.NativeFn = (_, _, args) => {
    args.finish()
    let warned : @library.Warned[
      Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
    ] = compile(inner)
    match warned.output {
      Ok(document) =>
        match
          document
          .introspector()
          .query(Elem(@library.metadata_elem(), None))
          .get(0) {
          Some(elem) => @library.MetadataElem::of(elem).unwrap().value()
          None => None
        }
      Err(errors) => raise @library.SourceError(errors)
    }
  }
  let outer_library = library_builder([])
    .with_global(scope => {
      scope.define_(
        "inner",
        Func(
          @library.Func::host(
            @library.HostFunc::new(@library.hash128("inner"), compile_inner),
          ),
        ),
      )
      |> ignore
    })
    .build()
  let world = reading_world(
    (
      #|#let own() = read("d.txt")
      #|#let both() = own() + "/" + inner()
      #|#metadata(both() + " " + both() + " " + own())
    ),
    data=[("d.txt", "outer")],
    library=outer_library,
  )
  let checked = checked_compile(world)
  inspect(checked.text, content="\"outer/inner outer/inner outer\"")
  inspect(checked.differ.join("\n"), content="")
  // A call that reads through another tracked world is not kept either
  // (a nested compilation also ends the generation of the stores, a read
  // does not): when that world changes during the outer compilation, the
  // next call sees it.
  let mut calls = 0
  let peek : @library.NativeFn = (_, _, args) => {
    args.finish()
    calls += 1
    inner.data[reading_id("d.txt")] = @utf8.encode("inner \{calls}")
    let data = @library.TrackedWorld::new(inner).file(reading_id("d.txt")) catch {
      _ => return None
    }
    Str(@utf8.decode(data) catch { _ => "" })
  }
  let peeking_library = library_builder([])
    .with_global(scope => {
      scope.define_(
        "peek",
        Func(
          @library.Func::host(
            @library.HostFunc::new(@library.hash128("peek"), peek),
          ),
        ),
      )
      |> ignore
    })
    .build()
  let world = reading_world(
    (
      #|#let both() = read("d.txt") + "/" + peek()
      #|#metadata(both() + " " + both())
    ),
    data=[("d.txt", "outer")],
    library=peeking_library,
  )
  let texts = oracle_memo_on_off(() => {
    calls = 0
    let warned : @library.Warned[
      Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
    ] = compile(world)
    match warned.output {
      Ok(document) =>
        document
        .introspector()
        .query(Elem(@library.metadata_elem(), None))
        .map(elem => @library.MetadataElem::of(elem).unwrap().value().repr())
      Err(errors) => errors.map(e => e.message)
    }
  })
  inspect(texts.join(" "), content="\"outer/inner 1 outer/inner 2\"")
}
