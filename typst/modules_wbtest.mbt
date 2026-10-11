// Module equality is upstream's (the owner's decision of 2026-10-11):
// `==` compares the objects (`PartialEq for Module`), a memoized call
// takes a module by its hash (comemo). Where two module objects with one
// hash meet, `==` says `false` and a memoized call takes one for the
// other. A document compiled from scratch gets two such modules from two
// plugins that export no function (`oracle_wbtest.mbt`, "modules: ..",
// with upstream's answers). The other ways need a host, and are here: a
// file that is evaluated twice (IDE tracing), the modules of two
// libraries, and a call that is found again after its module's file was
// evaluated again, which is what a watching compiler does
// (`tests/recompile/upstream/` has upstream's `typst watch` for that).

///|
test "modules: a file that is evaluated twice gives two modules (tracing)" {
  // `a.typ` holds the traced span and is evaluated once with it, for the
  // document, and once without, for the evaluated string (which runs
  // without a traced span, upstream's `Traced::default()`): two module
  // objects, and `==` says `false`. Upstream says `false` too (section
  // 5.4 of `docs/incremental-design.md` has its answer; there is no
  // command line for tracing).
  let files = [("a.typ", "#let probe(v) = v\n")]
  let source =
    #|#import "a.typ" as m
    #|#let n = eval("import \"a.typ\" as m; m", mode: "code")
    #|#let r = (m == n)
    #|#m.probe(r)
    #|#r
    #|
  // Traced at the `v` of `probe`'s body: the argument it was called with.
  @debug.assert_eq(
    traced_at(source, "v", 1, files~, file="a.typ"),
    (["false"], []),
  )
  // Traced in the main file, `a.typ` is one module.
  @debug.assert_eq(traced_at(source, "r", 2, files~), (["true"], []))
}

///|
/// The string values of the metadata of `source` compiled with `library`.
fn modules_test_metadata(
  source : String,
  library : @library.Library,
  files? : Array[(String, String)] = [],
) -> Array[String] raise {
  let world : TestWorld = { ..test_world(source, files~), library, }
  match compile(world).output {
    Ok(doc) => oracle_strings(doc)
    Err(errors) => fail(errors.map(e => e.message).join(" | "))
  }
}

///|
test "modules: the modules of two libraries are two modules, and one argument of a memoized call" {
  // Every library builds its own `math`, with the same bindings: two
  // objects with one hash. A host can bring the one of another library
  // into an evaluation, through `sys.inputs`.
  let other = library([])
  let inputs = @library.Dict::new()
  inputs.insert("m", Module(other.math))
  let library = library_builder([]).with_inputs(inputs).build()
  assert_false(other.math == library.math)
  assert_eq(
    @library.hash128(@library.Value::Module(other.math)),
    @library.hash128(@library.Value::Module(library.math)),
  )
  // `==` tells them apart, as upstream's does (its answer is in section
  // 5.4 of the design).
  let source =
    #|#let theirs = sys.inputs.m
    #|#metadata(repr((theirs == math, math == math, theirs == theirs)))
    #|
  @debug.assert_eq(modules_test_metadata(source, library), [
    "(false, true, true)",
  ])
  // A memoized call does not: at one call site, the call with the second
  // module is answered with the result of the call with the first.
  // (Upstream's memoized calls take arguments by their hashes; a document
  // shows that with two plugins, `oracle_wbtest.mbt`.)
  let source =
    #|#let theirs = sys.inputs.m
    #|#let id(m) = m
    #|#metadata(repr((theirs, math).map(id).map(m => (m == theirs, m == math))))
    #|#metadata(repr((math, theirs).map(m => m == math)))
    #|
  @debug.assert_eq(modules_test_metadata(source, library), [
    "((true, false), (true, false))", "(true, true)",
  ])
  // With the port's memoization off every call is computed.
  @library.set_layout_memo_enabled(false)
  let plain = {
    defer @library.set_layout_memo_enabled(true)
    modules_test_metadata(source, library)
  }
  @debug.assert_eq(plain, ["((true, false), (false, true))", "(true, false)"])
}
