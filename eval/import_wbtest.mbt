// The store of module evaluations (`eval_source_memoized` in `import.mbt`)
// at the level of the store: what an entry is found by, when it is valid,
// and that what it keeps stays what it was.
//
// Nothing is kept from one compilation to the next yet: an entry ends with
// the scope that stored it. Most of these tests keep the store over
// several scopes of one world (`eval_memo_kept`), which is what the later
// steps of `docs/incremental-design.md` do for real, as the tests of
// `library/tracked_world_wbtest.mbt` do for the stores of `memoize`.

///|
/// A world with sources and data files that a test changes between two
/// scopes.
priv struct StoreWorld {
  mut library : @library.Library
  mut main : @syntax.Source
  sources : Map[@syntax.FileId, @syntax.Source]
  data : Map[@syntax.FileId, Bytes]
}

///|
impl @library.World for StoreWorld with fn library(self) {
  self.library
}

///|
impl @library.World for StoreWorld with fn main(self) {
  self.main.id()
}

///|
impl @library.World for StoreWorld with fn source(self, id) {
  if id == self.main.id() {
    return self.main
  }
  match self.sources.get(id) {
    Some(source) => source
    None => raise @library.FileError::NotFound(id.vpath().get_without_slash())
  }
}

///|
impl @library.World for StoreWorld with fn file(self, id) {
  match self.data.get(id) {
    Some(data) => data
    None => raise @library.FileError::NotFound(id.vpath().get_without_slash())
  }
}

///|
impl @library.World for StoreWorld with fn today(_, _) {
  None
}

///|
fn store_id(path : String) -> @syntax.FileId {
  let vpath = @syntax.VirtualPath::new(path) catch {
    _ => abort("invalid path")
  }
  @syntax.RootedPath::new(Project, vpath).intern()
}

///|
/// A library that evaluates (its other routines are never called).
fn store_library() -> @library.Library {
  let routines = @library.Routines::new(eval_string~, eval_closure~)
  @library.Library::builder(routines, []).build()
}

///|
let store_library_cell : Ref[@library.Library?] = Ref(None)

///|
/// The library that the worlds of these tests share.
fn store_shared_library() -> @library.Library {
  match store_library_cell.val {
    Some(library) => library
    None => {
      let library = store_library()
      store_library_cell.val = Some(library)
      library
    }
  }
}

///|
fn store_world(
  text : String,
  sources? : Array[(String, String)] = [],
  data? : Array[(String, String)] = [],
) -> StoreWorld {
  let world : StoreWorld = {
    library: store_shared_library(),
    main: @syntax.Source::new(store_id("main.typ"), text),
    sources: Map([]),
    data: Map([]),
  }
  for file in sources {
    let id = store_id(file.0)
    world.sources[id] = @syntax.Source::new(id, file.1)
  }
  for file in data {
    world.data[store_id(file.0)] = @utf8.encode(file.1)
  }
  world
}

///|
/// Replaces the text of a file by an edit of its source, as the file store
/// of a watching compiler does after a reset (`kit/files.mbt`).
fn StoreWorld::edit(self : StoreWorld, path : String, text : String) -> Unit {
  let id = store_id(path)
  if id == self.main.id() {
    self.main = self.main.replace(text).0
  } else {
    self.sources[id] = self.sources[id].replace(text).0
  }
}

///|
/// The file, the text and the place in it that a span points at in the
/// world as it is.
fn StoreWorld::place(self : StoreWorld, span : @syntax.DiagSpan) -> String {
  guard span.id() is Some(id) else { return "nowhere" }
  let name = id.vpath().get_without_slash()
  let source = @library.World::source(self, id) catch {
    _ => return "\{name}:gone"
  }
  let range = match span.get() {
    Detached => None
    Number(num~, sub_range~, ..) => source.range(num, sub_range)
    Range(start~, end~, ..) => Some((start, end))
  }
  match range {
    Some((start, end)) =>
      "\{name}:\{start}..\{end} `\{@syntax.utf8_slice(source.text(), start, end)}`"
    None => "\{name}:unresolved"
  }
}

///|
/// What an evaluation gave: the text of the module or its errors with
/// their places and tracepoints, and how many evaluations of files the
/// store answered and how many it computed.
priv struct Evaluated {
  text : String
  found : Int
  computed : Int
}

///|
/// Evaluates a source of the world in a scope of its own, as a compilation
/// evaluates its main file.
fn StoreWorld::evaluate_source(
  self : StoreWorld,
  source : @syntax.Source,
) -> Evaluated {
  let before = module_memo_stats()
  let sink = @library.Sink::new()
  let text = try
    eval_source(
      @library.TrackedWorld::new(self),
      self.library,
      @library.Traced::new(),
      sink,
      @library.Route::root(),
      source,
    )
  catch {
    @library.SourceError(errors) =>
      "error: " +
      errors
      .map(error => {
        let trace = error.trace.map(point => {
          " [\{point.v} at \{self.place(@syntax.DiagSpan::from_span(point.span))}]"
        })
        "\{error.message} at \{self.place(error.span)}\{trace.join("")}"
      })
      .join(" | ")
  } noraise {
    module_ => module_.content().plain_text()
  }
  let warnings = sink
    .warnings()
    .map(warning => " (warning: \{warning.message})")
  let after = module_memo_stats()
  {
    text: text + warnings.join(""),
    found: after.0 - before.0,
    computed: after.1 - before.1,
  }
}

///|
fn StoreWorld::evaluate(self : StoreWorld) -> Evaluated {
  self.evaluate_source(self.main)
}

///|
/// [StoreWorld::evaluate] as one line.
fn StoreWorld::evaluated(self : StoreWorld) -> String {
  let result = self.evaluate()
  "\{result.text}: found \{result.found}, evaluated \{result.computed}"
}

///|
/// Runs a test with a store that outlives its scopes (see the file
/// header), and leaves no entry behind.
fn[T] with_kept_store(f : () -> T raise) -> T raise {
  eval_memo.entries.clear()
  eval_memo_kept.val = true
  defer {
    eval_memo_kept.val = false
    eval_memo.entries.clear()
  }
  f()
}

///|
test "module store: an entry is found in a later scope while its reads hold, the main file's too" {
  with_kept_store(() => {
    let world = store_world(
      "#import \"a.typ\": x\n#import \"b.typ\": y\n#x #y",
      sources=[
        ("a.typ", "#let x = read(\"d.txt\")\n"),
        ("b.typ", "#let y = [b]\n"),
      ],
      data=[("d.txt", "one")],
    )
    inspect(world.evaluated(), content="one b: found 0, evaluated 3")
    // Nothing changed: the evaluation of the main file is found, and with
    // it everything that it imported.
    inspect(world.evaluated(), content="one b: found 1, evaluated 0")
    // A file that `a.typ` read: the entry of the main file has the read
    // (it is its caller's), so the main file is evaluated again, and
    // `a.typ` with it. `b.typ` is found.
    world.data[store_id("d.txt")] = @utf8.encode("two")
    inspect(world.evaluated(), content="two b: found 1, evaluated 2")
    // An edit of `b.typ`: another source, so another key, and another
    // answer to the read of the main file. `a.typ` is found.
    world.edit("b.typ", "#let y = [c]\n")
    inspect(world.evaluated(), content="two c: found 1, evaluated 2")
    // An edit of the main file: both imports are found.
    world.edit("main.typ", "#import \"a.typ\": x\n#import \"b.typ\": y\n#y #x")
    inspect(world.evaluated(), content="c two: found 2, evaluated 1")
    // The same text written again is the same source.
    world.edit("main.typ", "#import \"a.typ\": x\n#import \"b.typ\": y\n#y #x")
    inspect(world.evaluated(), content="c two: found 1, evaluated 0")
  })
}

///|
test "module store: without the kept store an entry ends with its scope" {
  let world = store_world("#import \"a.typ\": x\n#x", sources=[
    ("a.typ", "#let x = [a]\n"),
  ])
  inspect(world.evaluated(), content="a: found 0, evaluated 2")
  inspect(world.evaluated(), content="a: found 0, evaluated 2")
}

///|
test "module store: a file is one module in a scope, whoever imports it first" {
  let world = store_world(
    "#import \"a.typ\"\n#import \"b.typ\": inner\n#import \"a.typ\" as again\n#(a == again) #(a == inner)",
    sources=[
      ("a.typ", "#let x = 1\n"),
      ("b.typ", "#import \"a.typ\" as inner\n"),
    ],
  )
  inspect(world.evaluated(), content="true true: found 2, evaluated 3")
}

///|
/// The text of a file with a function that fails, and the place of the
/// failing call in it.
let store_failing : String = "#let f() = panic(\"here\")\n#let later = [text]\n"

///|
test "module store: the same text with other span numbers is another source (A, B, A)" {
  with_kept_store(() => {
    let world = store_world("#import \"a.typ\": f\n#f()", sources=[
      ("a.typ", store_failing),
    ])
    let first = world.sources[store_id("a.typ")]
    let expected = "error: panicked with: here at a.typ:11..24 `panic(\"here\")` [while calling `f` at main.typ:20..23 `f()`]"
    inspect(world.evaluated(), content=expected + ": found 0, evaluated 2")
    // B: the call is edited, and the edit is undone. The source then has
    // the first text again, and its tree was reparsed where the edits
    // were: the call has another span number than in the first parse.
    world.edit("a.typ", "#let f() = panic(\"there\")\n#let later = [text]\n")
    inspect(
      world.evaluated(),
      content="error: panicked with: there at a.typ:11..25 `panic(\"there\")` [while calling `f` at main.typ:20..23 `f()`]: found 0, evaluated 2",
    )
    world.edit("a.typ", store_failing)
    let third = world.sources[store_id("a.typ")]
    assert_eq(third.text(), first.text())
    assert_true(first.is_pristine())
    assert_false(third.is_pristine())
    // (That the numbers differ is what makes this a test: the span of the
    // call in the first tree is not the call in the third.)
    let call_of = (source : @syntax.Source) => {
      @syntax.LinkedNode::new(source.root())
      .leaf_at(12, After)
      .unwrap()
      .get()
      .span()
    }
    assert_true(call_of(first) != call_of(third))
    // So the entries of the first scope are not for this source: the
    // module is evaluated again, with the spans of the tree at hand, and
    // the error points at the call. (Found by the text, the kept error of
    // the first scope would be reported, with a span that is not in the
    // tree any more.)
    inspect(world.evaluated(), content=expected + ": found 0, evaluated 2")
    // A world that parses the text anew (`Source::new`) hands out the
    // first tree again, number for number: that is the source of the
    // first scope, as another object, and its entries are found.
    world.sources[store_id("a.typ")] = @syntax.Source::new(
      store_id("a.typ"),
      store_failing,
    )
    inspect(world.evaluated(), content=expected + ": found 1, evaluated 0")
  })
}

///|
test "module store: the library is part of what an entry is for" {
  with_kept_store(() => {
    let world = store_world("#import \"a.typ\": x\n#x", sources=[
      ("a.typ", "#let x = sys.inputs.at(\"mode\", default: \"none\")\n"),
    ])
    inspect(world.evaluated(), content="none: found 0, evaluated 2")
    let inputs = @library.Dict::new()
    inputs.insert("mode", Str("draft"))
    let routines = @library.Routines::new(eval_string~, eval_closure~)
    world.library = @library.Library::builder(routines, [])
      .with_inputs(inputs)
      .build()
    inspect(world.evaluated(), content="draft: found 0, evaluated 2")
    // Back to the first library: its entries are found.
    world.library = store_shared_library()
    inspect(world.evaluated(), content="none: found 1, evaluated 0")
  })
}

///|
test "module store: a failed read and a file that appears" {
  with_kept_store(() => {
    let world = store_world("#import \"a.typ\": x\n#x", sources=[
      ("a.typ", "#let x = read(\"d.txt\")\n"),
    ])
    let missing = "error: file not found (searched at d.txt) at a.typ:14..21 `\"d.txt\"` [while importing `a.typ` at main.typ:1..18 `import \"a.typ\": x`]"
    inspect(world.evaluated(), content=missing + ": found 0, evaluated 2")
    // The error is kept with the reads that led to it.
    inspect(world.evaluated(), content=missing + ": found 1, evaluated 0")
    world.data[store_id("d.txt")] = @utf8.encode("now")
    inspect(world.evaluated(), content="now: found 0, evaluated 2")
  })
}

///|
test "module store: an entry of an outer scope is found in a scope inside it if its reads hold there" {
  // No kept store here: both scopes are open. The inner world has the
  // sources of the outer one and, the second time, another data file.
  let outer = store_world("", sources=[("a.typ", "#read(\"d.txt\")")], data=[
    ("d.txt", "one"),
  ])
  let a = outer.sources[store_id("a.typ")]
  let same = store_world("", data=[("d.txt", "one")])
  let other = store_world("", data=[("d.txt", "two")])
  let lines = []
  let tracked = @library.TrackedWorld::new(outer)
  let _ = tracked.scoped(() => {
    let before = module_memo_stats()
    let _ = eval_source(
      tracked,
      outer.library,
      @library.Traced::new(),
      @library.Sink::new(),
      @library.Route::root(),
      a,
    )
    let after = module_memo_stats()
    lines.push(
      "outer: found \{after.0 - before.0}, evaluated \{after.1 - before.1}",
    )
    for inner in [same, other, same] {
      let result = inner.evaluate_source(a)
      lines.push(
        "inner \{result.text}: found \{result.found}, evaluated \{result.computed}",
      )
    }
  }) catch {
    _ => fail("the evaluation failed")
  }
  inspect(
    lines.join("; "),
    content="outer: found 0, evaluated 1; inner one: found 1, evaluated 0; inner two: found 0, evaluated 1; inner one: found 1, evaluated 0",
  )
}

///|
test "module store: the depth of the route is among what an evaluation asked" {
  // `deep.typ` calls 60 functions inside each other. Imported where the
  // route is 10 deep that is within the maximum call depth of 80, and
  // imported from inside 30 calls it is not: upstream evaluates the file
  // again there (comemo tracks `Route::within`) and reports the error.
  // (`typst compile` of upstream, with these two files: "error: maximum
  // function call depth exceeded".)
  let deep = "#let down(n) = if n == 0 { 0 } else { down(n - 1) }\n#let v = down(60)\n"
  let nested = "#let nest(n) = if n == 0 { import \"deep.typ\": v; v } else { nest(n - 1) }\n"
  let world = store_world(nested + "#nest(10) #nest(10)", sources=[
    ("deep.typ", deep),
  ])
  // The second import, at the same depth, finds the module.
  inspect(world.evaluated(), content="0 0: found 1, evaluated 2")
  let world = store_world(nested + "#nest(10) #nest(12)", sources=[
    ("deep.typ", deep),
  ])
  // Two calls deeper is still within what the first evaluation checked.
  inspect(world.evaluated(), content="0 0: found 1, evaluated 2")
  let world = store_world(nested + "#nest(10) #nest(30)", sources=[
    ("deep.typ", deep),
  ])
  let result = world.evaluate()
  assert_true(
    result.text.has_prefix("error: maximum function call depth exceeded"),
  )
  inspect(
    "found \{result.found}, evaluated \{result.computed}",
    content="found 0, evaluated 3",
  )
}
