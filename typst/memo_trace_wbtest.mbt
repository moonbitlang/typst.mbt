// IDE tracing (`trace`) with memoized closure calls: a call that is reused
// replays the values it traced, and a call that ran where nothing is traced
// (an evaluated string) is not the call of the document. The expected
// values are those of an evaluation without memoization, which every test
// also runs (upstream has no command line for tracing).

///|
/// The spans of the identifiers `name` of a tree, in order.
fn ident_spans(
  node : @syntax.SyntaxNode,
  name : String,
  out : Array[@syntax.Span],
) -> Unit {
  if node.kind() is (Ident | MathIdent) && node.leaf_text() == name {
    out.push(node.span())
  }
  for child in node.children() {
    ident_spans(child, name, out)
  }
}

///|
/// The reprs of the values traced at the `index`-th identifier `name` of
/// the file `file` (the main file if it is empty), and the messages of the
/// errors; with memoization and without.
fn traced_at(
  source : String,
  name : String,
  index : Int,
  files? : Array[(String, String)] = [],
  file? : String = "",
) -> (Array[String], Array[String]) raise {
  oracle_memo_on_off(() => {
    let world = test_world(source, files~)
    let traced_source = if file == "" {
      world.main
    } else {
      let found = world.files
        .values()
        .filter(s => s.id().vpath().get_without_slash() == file)
      guard found.collect() is [found] else { fail("no file \{file}") }
      found
    }
    let spans = []
    ident_spans(traced_source.root(), name, spans)
    guard index < spans.length() else { fail("no identifier \{name}") }
    let sink = @library.Sink::new()
    let traced = @library.Traced::new(traced=spans[index])
    let errors = try
      (compile_impl(world, traced, sink) : @layout.PagedDocument)
    catch {
      @library.SourceError(errors) => deduplicate(errors).map(e => e.message)
    } noraise {
      _ => []
    }
    (sink.values().map(pair => pair.0.repr()), errors)
  })
}

///|
test "trace: a call in an evaluated string is not the document's call" {
  // The evaluated string runs without tracing (`eval_root`); both maps call
  // `f` with the same function, arguments and spans.
  let source =
    #|#let f(x) = x
    #|#let ignored = eval("(1,).map(f)", scope: (f: f))
    #|#let result = (1,).map(f)
    #|
  // The body's `x`.
  @debug.assert_eq(traced_at(source, "x", 1), (["1"], []))
  // And the other way round.
  let source =
    #|#let f(x) = x
    #|#let result = (1,).map(f)
    #|#let ignored = eval("(1, 2).map(f)", scope: (f: f))
    #|
  @debug.assert_eq(traced_at(source, "x", 1), (["1"], []))
}

///|
test "trace: reused calls replay their values, up to the limit" {
  let source =
    #|#let f(x) = x
    #|#let result = (1, 1, 2, 1).map(f)
    #|
  @debug.assert_eq(traced_at(source, "x", 1), (["1", "1", "2", "1"], []))
  // The parameter itself (the binding is traced too).
  @debug.assert_eq(traced_at(source, "x", 0), (["1", "1", "2", "1"], []))
  // The sink keeps ten values.
  let source =
    #|#let f(x) = x
    #|#let result = range(30).map(i => calc.rem(i, 3)).map(f)
    #|
  let (values, _) = traced_at(source, "x", 1)
  @debug.assert_eq(values, ["0", "1", "2", "0", "1", "2", "0", "1", "2", "0"])
  // A call inside a reused call.
  let source =
    #|#let g(y) = y + 1
    #|#let f(x) = g(x) * 2
    #|#let result = (1, 1, 2).map(f) + (1, 3).map(g)
    #|
  @debug.assert_eq(traced_at(source, "y", 1), (["1", "1", "2", "1", "3"], []))
}

///|
test "trace: with imports, forwarded arguments and delayed errors" {
  let files = [
    (
      "lib.typ",
      (
        #|#let load(p) = { import p as m; m.v }
        #|#let width(b) = measure(b).width
        #|#let pass(..args) = args.pos().first()
        #|
      ),
    ),
    ("a.typ", "#import \"b.typ\": w\n#let v = (w, w)\n"),
    ("b.typ", "#let w = (1, 2)\n"),
    (
      "c.typ", "#import \"lib.typ\": load\n#let again = (\"a.typ\",).map(load)\n",
    ),
  ]
  let source =
    #|#import "lib.typ": load, width, pass
    #|#show strong: it => box(width: query(<target>).first().value.first(), height: 1pt)
    #|#let both = ("a.typ", "a.typ").map(load)
    #|#import "c.typ": again
    #|#let fw(..args) = pass(..args)
    #|#let seen = (fw(both), fw(again), fw(both))
    #|#context metadata(repr((width([*x*]), width([*x*]))))
    #|#metadata((10pt,)) <target>
    #|
  // The path given to `load`, in the library: two calls from the main
  // file (the second is reused) and one from `c.typ`.
  @debug.assert_eq(
    traced_at(source, "p", 1, files~, file="lib.typ"),
    (["\"a.typ\"", "\"a.typ\"", "\"a.typ\""], []),
  )
  // The module's variable, in the imported file: the module is evaluated
  // once, and each reuse of the evaluation replays what it traced (the
  // sink's values are effects of upstream's memoized `eval` too).
  @debug.assert_eq(
    traced_at(source, "w", 1, files~, file="a.typ"),
    (["(1, 2)", "(1, 2)", "(1, 2)"], []),
  )
  // The forwarded arguments.
  let (values, errors) = traced_at(source, "args", 1, files~, file="lib.typ")
  @debug.assert_eq(errors, [])
  @debug.assert_eq(values.length(), 3)
  // The measured body: the first layout cannot resolve the query (a delayed
  // error that goes away), and the measurements of every layout are traced.
  let (values, errors) = traced_at(source, "b", 1, files~, file="lib.typ")
  @debug.assert_eq(errors, [])
  assert_true(values.length() >= 2)
  for value in values {
    @debug.assert_eq(value, "strong(body: [x])")
  }
  // A delayed error that stays is reported once, with the traced values.
  let failing =
    #|#import "lib.typ": width
    #|#show strong: it => panic("no")
    #|#context metadata(repr((width([*x*]), width([*x*]))))
    #|
  let (values, errors) = traced_at(failing, "b", 1, files~, file="lib.typ")
  @debug.assert_eq(errors, ["panicked with: no"])
  assert_true(values.length() >= 2)
}

///|
test "trace: an evaluated string imports the module of the document" {
  // The evaluated string runs without a traced span. Upstream tracks what
  // the evaluation of a file asks of the span (`Traced::get` for the files
  // whose code runs): `lib.typ` asks for itself, the span is elsewhere, and
  // both imports give one module.
  let files = [("lib.typ", "#let v = 1\n")]
  let source =
    #|#let load() = { import "lib.typ" as m; m }
    #|#let a = eval("load()", scope: (load: load))
    #|#let b = load()
    #|#let same = a == b
    #|#metadata(same)
    #|
  // The last `same`.
  @debug.assert_eq(traced_at(source, "same", 1, files~), (["true"], []))
  // A span in the imported file: the document's import evaluates it again
  // (the string's evaluation traced nothing), and so does upstream.
  @debug.assert_eq(
    traced_at(source, "v", 0, files~, file="lib.typ"),
    (["1"], []),
  )
  // The module is one for the evaluations of other files too.
  let files = [
    ("lib.typ", "#let v = 1\n"),
    (
      "mid.typ", "#import \"lib.typ\" as inner\n#let w = eval(\"m\", scope: (m: inner))\n",
    ),
  ]
  let source =
    #|#import "mid.typ": inner, w
    #|#import "lib.typ" as direct
    #|#let same = (inner == direct, w == direct, eval("import \"lib.typ\" as e; e") == direct)
    #|#metadata(same)
    #|
  @debug.assert_eq(
    traced_at(source, "same", 1, files~),
    (["(true, true, true)"], []),
  )
}
