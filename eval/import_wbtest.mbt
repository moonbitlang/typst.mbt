// The store of module evaluations (`eval_source_memoized` in `import.mbt`)
// at the level of the store: what an entry is found by, when it is valid,
// how long it lives, and that what it keeps stays what it was.
//
// An entry outlives the scope that stored it (step 5 of slice 1 of
// `docs/incremental-design.md`): the tests evaluate in several scopes of
// one world, as the compilations of a watching compiler do, and each
// starts with an empty store ([with_empty_store]), since the store is the
// process's and the tests of this file share a library.

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
/// Runs a test with a store that is empty when it starts, and leaves no
/// entry behind.
fn[T] with_empty_store(f : () -> T raise) -> T raise {
  @library.evict(0)
  defer @library.evict(0)
  f()
}

///|
test "module store: an entry is found in a later scope while its reads hold, the main file's too" {
  with_empty_store(() => {
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
test "module store: an entry has comemo's age" {
  with_empty_store(() => {
    let world = store_world("#import \"a.typ\": x\n#import \"b.typ\": y\n#x", sources=[
      ("a.typ", "#let x = [a]\n"),
      ("b.typ", "#let y = [b]\n"),
    ])
    inspect(world.evaluated(), content="a: found 0, evaluated 3")
    assert_eq(module_memo_entries(), 3)
    // Not taken for `max_age` calls of `evict`: still there. (The main
    // file's entry is found, so those of its imports are not asked for.)
    for _ in 0..<3 {
      @library.evict(3)
    }
    assert_eq(module_memo_entries(), 3)
    inspect(world.evaluated(), content="a: found 1, evaluated 0")
    // The hit made the main file's entry young; the two others go with
    // the next call, the main file's three calls later.
    @library.evict(3)
    assert_eq(module_memo_entries(), 1)
    @library.evict(3)
    @library.evict(3)
    assert_eq(module_memo_entries(), 1)
    inspect(world.evaluated(), content="a: found 1, evaluated 0")
    // An edit of the main file: its imports are evaluated again, their
    // entries were dropped while the main file's answered for them.
    world.edit("main.typ", "#import \"a.typ\": x\n#import \"b.typ\": y\n#x #y")
    inspect(world.evaluated(), content="a b: found 0, evaluated 3")
    // `evict(0)` drops everything.
    @library.evict(0)
    assert_eq(module_memo_entries(), 0)
    inspect(world.evaluated(), content="a b: found 0, evaluated 3")
  })
}

///|
test "module store: a source has a limited number of entries without `evict`" {
  with_empty_store(() => {
    // A file that reads another, which is different in every scope: one
    // entry per answer of the world, and `evict` is never called.
    let world = store_world(
      "#import \"a.typ\": x\n#x",
      sources=[("a.typ", "#let x = read(\"d.txt\")\n")],
      data=[("d.txt", "0")],
    )
    for i in 0..<(3 * eval_memo_max_entries) {
      world.data[store_id("d.txt")] = @utf8.encode(i.to_string())
      inspect(world.evaluated(), content="\{i}: found 0, evaluated 2")
    }
    // Two sources (the main file and `a.typ`), each with the entries of
    // the last scopes.
    assert_eq(module_memo_entries(), 2 * eval_memo_max_entries)
    // The last answers are found, the first are gone.
    world.data[store_id("d.txt")] = @utf8.encode(
      (3 * eval_memo_max_entries - 2).to_string(),
    )
    inspect(
      world.evaluated(),
      content="\{3 * eval_memo_max_entries - 2}: found 1, evaluated 0",
    )
    world.data[store_id("d.txt")] = @utf8.encode("0")
    inspect(world.evaluated(), content="0: found 0, evaluated 2")
  })
}

///|
test "module store: with memoization off an entry ends with its scope" {
  with_empty_store(() => {
    let world = store_world(
      "#import \"a.typ\"\n#import \"a.typ\" as again\n#(a == again)",
      sources=[("a.typ", "#let x = [a]\n")],
    )
    inspect(world.evaluated(), content="true: found 1, evaluated 2")
    inspect(world.evaluated(), content="true: found 1, evaluated 0")
    // Off: nothing of the scopes before is found, and a file is still one
    // module for the two imports of one scope.
    @library.set_layout_memo_enabled(false)
    defer @library.set_layout_memo_enabled(true)
    inspect(world.evaluated(), content="true: found 1, evaluated 2")
    inspect(world.evaluated(), content="true: found 1, evaluated 2")
    // On again: what the scopes without memoization evaluated is not
    // found, what the scopes before them left is.
    @library.set_layout_memo_enabled(true)
    inspect(world.evaluated(), content="true: found 1, evaluated 0")
    // The entries that ended with their scope are dropped by the next
    // scope that stores one: what is left besides the entries of the
    // evaluations with memoization is the last one's (`a.typ`).
    world.edit(
      "main.typ", "#import \"a.typ\"\n#import \"a.typ\" as again\n#(a != again)",
    )
    @library.set_layout_memo_enabled(false)
    inspect(world.evaluated(), content="false: found 1, evaluated 2")
    @library.set_layout_memo_enabled(true)
    assert_eq(module_memo_entries(), 4)
    inspect(world.evaluated(), content="false: found 2, evaluated 1")
    assert_eq(module_memo_entries(), 5)
    @library.evict(0)
    assert_eq(module_memo_entries(), 0)
  })
}

///|
test "module store: a file is one module in a scope, whoever imports it first" {
  // (The store is the process's: what the tests before left is dropped.)
  @library.evict(0)
  defer @library.evict(0)
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
  with_empty_store(() => {
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
  with_empty_store(() => {
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
  with_empty_store(() => {
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
test "module store: the error an entry keeps is not the one an import adds its tracepoint to" {
  with_empty_store(() => {
    let world = store_world("#import \"bad.typ\": x", sources=[
      ("bad.typ", "#let x = panic(\"bad\")\n"),
    ])
    let failed = "error: panicked with: bad at bad.typ:9..21 `panic(\"bad\")`"
    inspect(
      world.evaluated(),
      content=failed +
        " [while importing `bad.typ` at main.typ:1..20 `import \"bad.typ\": x`]: found 0, evaluated 2",
    )
    // The main file changes, the file that fails does not: its error is
    // found, and every import that finds it reports it with its own
    // tracepoint alone. (Upstream: comemo hands out a clone of what it
    // keeps, and a tracepoint is added to the clone.)
    world.edit("main.typ", "\n#import \"bad.typ\": x")
    inspect(
      world.evaluated(),
      content=failed +
        " [while importing `bad.typ` at main.typ:2..21 `import \"bad.typ\": x`]: found 1, evaluated 1",
    )
    world.edit("main.typ", "\n\n#import \"bad.typ\": x")
    inspect(
      world.evaluated(),
      content=failed +
        " [while importing `bad.typ` at main.typ:3..22 `import \"bad.typ\": x`]: found 1, evaluated 1",
    )
  })
}

///|
test "module store: a caller that writes to the errors it got does not write to the entry" {
  with_empty_store(() => {
    let world = store_world("#import \"bad.typ\": x", sources=[
      ("bad.typ", "#let x = panic(\"bad\")\n"),
    ])
    let bad = world.sources[store_id("bad.typ")]
    // The errors of the evaluation that computes the entry, and those of
    // two that find it: each caller adds a hint and a tracepoint to what
    // it got and empties the array.
    let seen = []
    for _ in 0..<3 {
      let before = module_memo_stats()
      let _ = eval_source(
        @library.TrackedWorld::new(world),
        world.library,
        @library.Traced::new(),
        @library.Sink::new(),
        @library.Route::root(),
        bad,
      ) catch {
        @library.SourceError(errors) => {
          let after = module_memo_stats()
          // (Without an index: where the entry hands out its own array,
          // the second caller gets it empty.)
          let first = match errors.get(0) {
            Some(error) =>
              "\{error.trace.length()} tracepoints, \{error.hints.length()} hints"
            None => "nothing in it"
          }
          seen.push(
            "\{errors.length()} error, \{first}, found \{after.0 - before.0}",
          )
          for error in errors {
            error.hint("a caller's hint")
            error.with_tracepoint(Call(None), world.main.root().span())
            |> ignore
          }
          errors.clear()
          continue
        }
      }
      fail("the evaluation did not fail")
    }
    inspect(
      seen.join("; "),
      content="1 error, 0 tracepoints, 0 hints, found 0; 1 error, 0 tracepoints, 0 hints, found 1; 1 error, 0 tracepoints, 0 hints, found 1",
    )
  })
}

///|
test "module store: the warnings an entry keeps are not those of the sinks it is replayed into" {
  // (The store is the process's: what the tests before left is dropped.)
  @library.evict(0)
  defer @library.evict(0)
  // A sink's diagnostics are objects that their holder can append hints
  // and tracepoints to, and an entry replays its sink into the sink of
  // every evaluation that finds it: copies, of a copy that the entry keeps
  // (`@library.Sink::kept`).
  with_empty_store(() => {
    let world = store_world("#import \"a.typ\": x as x\n#x", sources=[
      ("a.typ", "#let x = [a]\n"),
    ])
    let warnings = () => {
      let before = module_memo_stats()
      let sink = @library.Sink::new()
      eval_source(
        @library.TrackedWorld::new(world),
        world.library,
        @library.Traced::new(),
        sink,
        @library.Route::root(),
        world.main,
      )
      |> ignore
      let seen = sink
        .warnings()
        .map(warning => "\{warning.message}: \{warning.hints.length()} hints")
      // What a host can do with the warnings it was given.
      for warning in sink.warnings() {
        warning.hint("a hint of the host's")
      }
      let after = module_memo_stats()
      "\{seen.join("; ")} (found \{after.0 - before.0})"
    }
    inspect(
      warnings(),
      content="unnecessary import rename to same name: 0 hints (found 0)",
    )
    for _ in 0..<2 {
      inspect(
        warnings(),
        content="unnecessary import rename to same name: 0 hints (found 1)",
      )
    }
  })
}

///|
test "module store: a call that is found again returns the module of the evaluation before" {
  // (The store is the process's: what the tests before left is dropped.)
  @library.evict(0)
  defer @library.evict(0)
  // Upstream's rule, and the port's (the owner's decision of 2026-10-11):
  // `==` on modules compares the objects, and a memoized call is found by
  // the hashes of its arguments, a module's being its name and what it
  // holds. `get` captured the module of `a.typ`. After a comment in
  // `a.typ` the file is evaluated again and gives another module with the
  // hash of the first, `get` is a closure with the hash it had, and
  // `get()` is found: it returns the module of the first evaluation, which
  // is not `==` to the module of the second. That is what upstream's
  // `typst watch` shows after such an edit
  // (`tests/recompile/upstream/getter.json`), and what the port shows
  // once closure calls are kept from one compilation to the next. Here
  // they are kept by running both evaluations in one compilation.
  //
  // The module exports `float.nan`: what it holds is compared by its hash,
  // which has the bits of the float, never by `==`.
  let a = (comment : Int) => {
    "#let v = 1\n#let x = float.nan\n// comment \{comment}\n"
  }
  let main = "#import \"a.typ\" as m\n#let get() = m\n#repr((get() == m, m == m, get().v == m.v))"
  let world = store_world(main, sources=[("a.typ", a(0))])
  let seen = []
  let mut found = 0
  @library.with_layout_memo(() => {
    seen.push(world.evaluated())
    let before = @library.closure_memo_stats().0
    world.edit("a.typ", a(1))
    seen.push(world.evaluated())
    // The calls were found, not computed (`get` is called in two places).
    found = @library.closure_memo_stats().0 - before
    // An edit that changes what the module holds: another hash, another
    // closure, another call.
    world.edit("a.typ", "#let v = 2\n")
    seen.push(world.evaluated())
  })
  assert_eq(seen, [
    "(true, true, true): found 0, evaluated 2", "(false, true, true): found 0, evaluated 2",
    "(true, true, true): found 0, evaluated 2",
  ])
  assert_eq(found, 2)
  // From scratch, as in every compilation of the tree as it is, the
  // module is one.
  let fresh = store_world(main, sources=[("a.typ", a(1))])
  inspect(fresh.evaluated(), content="(true, true, true): found 0, evaluated 2")
}

///|
test "module store: an entry of an outer scope is found in a scope inside it if its reads hold there" {
  // (The store is the process's: what the tests before left is dropped.)
  @library.evict(0)
  defer @library.evict(0)
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
test "module store: an outer scope keeps an entry that it took from a scope inside it" {
  with_empty_store(() => {
    let world = store_world("#let v = 1\n")
    let outer = @library.TrackedWorld::new(world)
    let inner = @library.TrackedWorld::new(world)
    let evaluate = (tracked : @library.TrackedWorld) => {
      eval_source(
        tracked,
        world.library,
        @library.Traced::new(),
        @library.Sink::new(),
        @library.Route::root(),
        world.main,
      )
    }
    let modules = []
    outer.scoped(() => {
      inner.scoped(() => {
        // The scope inside stores the evaluation, the outer one takes it
        // while both are open.
        modules.push(evaluate(inner))
        modules.push(evaluate(outer))
      })
      // The scope that stored it is closed. The outer one is not: the
      // file must stay the module it is for it, whatever is evicted.
      @library.evict(0)
      modules.push(evaluate(outer))
    })
    assert_true(modules[0] == modules[1])
    assert_true(modules[1] == modules[2])
    assert_eq(module_memo_entries(), 1)
    @library.evict(0)
    assert_eq(module_memo_entries(), 0)
  })
}

///|
test "module store: an entry is only taken for the source it was computed for" {
  with_empty_store(() => {
    // Two sources of one file with two texts, to which a caller gave the
    // same two words (`Source::set_memo`, where the engine keeps the
    // fingerprint of a parsed text): the store finds the entry of the
    // first for the second and does not take it.
    let world = store_world("")
    let id = store_id("a.typ")
    let one = @syntax.Source::new(id, "one")
    let two = @syntax.Source::new(id, "two")
    one.set_memo(1, 2)
    two.set_memo(1, 2)
    assert_true(
      @library.source_fingerprint(one) == @library.source_fingerprint(two),
    )
    let first = world.evaluate_source(one)
    let second = world.evaluate_source(two)
    inspect(
      "\{first.text} \{first.found}, \{second.text} \{second.found}",
      content="one 0, two 0",
    )
    // The same text parsed again is the same source.
    let again = @syntax.Source::new(id, "two")
    again.set_memo(1, 2)
    let third = world.evaluate_source(again)
    inspect("\{third.text} \{third.found}", content="two 1")
  })
}

///|
test "module store: the recording check repeats an import with the module of the world at hand" {
  // (The store is the process's: what the tests before left is dropped.)
  @library.evict(0)
  defer @library.evict(0)
  // Two scopes are open: one of a world whose `choose.txt` says
  // `old.txt`, and inside it one of a world with the same sources whose
  // `choose.txt` says `new.txt`. The store has the module of `a.typ` of
  // the outer scope when the inner one evaluates the main file under the
  // recording check. The second run of the check imports `a.typ` again
  // and must get the module that the first run of this world got, not the
  // outer one's, which the store also holds for that source: with that
  // one the run reads `old.txt`, and the check reports a difference that
  // is not one.
  @library.set_memo_check(true)
  defer @library.set_memo_check(false)
  @library.take_memo_check_report() |> ignore
  let data = (choice : String) => {
    [("choose.txt", choice), ("old.txt", "old"), ("new.txt", "new")]
  }
  let outer = store_world(
    "#import \"a.typ\": path\n#read(path)",
    sources=[("a.typ", "#let path = read(\"choose.txt\")\n")],
    data=data("old.txt"),
  )
  let a = outer.sources[store_id("a.typ")]
  let inner = store_world("", data=data("new.txt"))
  inner.main = outer.main
  inner.sources[store_id("a.typ")] = a
  let tracked = @library.TrackedWorld::new(outer)
  let texts = []
  tracked.scoped(() => {
    let _ = eval_source(
      tracked,
      outer.library,
      @library.Traced::new(),
      @library.Sink::new(),
      @library.Route::root(),
      a,
    )
    texts.push(inner.evaluate().text)
  }) catch {
    _ => fail("the evaluation failed")
  }
  inspect(texts.join(" "), content="new")
  let (entries, differ) = @library.take_memo_check_report()
  inspect(differ.join("\n"), content="")
  assert_true(entries >= 3)
}

///|
test "module store: the depth of the route is among what an evaluation asked" {
  // (The store is the process's: what the tests before left is dropped.)
  @library.evict(0)
  defer @library.evict(0)
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
  // (Another world with the same file: the entry of the first is found by
  // both imports.)
  inspect(world.evaluated(), content="0 0: found 2, evaluated 1")
  let world = store_world(nested + "#nest(10) #nest(30)", sources=[
    ("deep.typ", deep),
  ])
  let result = world.evaluate()
  assert_true(
    result.text.has_prefix("error: maximum function call depth exceeded"),
  )
  // The first import finds the entry; the second is too deep for it and
  // is evaluated again, and fails.
  inspect(
    "found \{result.found}, evaluated \{result.computed}",
    content="found 1, evaluated 2",
  )
}
