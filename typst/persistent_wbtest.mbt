// What an evaluation made is not changed by a later edit of its sources.
// A closure holds the syntax node of its body, a module holds closures, and
// `Source::replace` gives the file a new tree instead of writing to the one
// they were made from (upstream: `Arc::make_mut` in `Source::edit` and in
// the reparser; the rule is in the header of `syntax/node.mbt`). Keeping
// results across compilations (`docs/incremental-design.md`, 5.4) rests on
// this: a kept closure must still be what its fingerprint says.

///|
/// The module of a file of the world, as it is now.
fn evaluated_module(world : TestWorld, file : String) -> @library.Module raise {
  for id, source in world.files {
    if id.vpath().get_without_slash() == file {
      return @eval.eval_source(
        world,
        world.library,
        @library.Traced::new(),
        @library.Sink::new(),
        @library.Route::root(),
        source,
      )
    }
  }
  fail("no file \{file}")
}

///|
/// What the function `name` of a module returns for an integer, as text.
fn called(
  world : TestWorld,
  module_ : @library.Module,
  name : String,
  arg : Int64,
) -> String raise {
  let engine : @library.Engine = {
    library: world.library,
    world,
    introspector: @library.Introspector::empty(),
    traced: @library.Traced::new(),
    sink: @library.Sink::new(),
    route: @library.Route::root(),
  }
  let guard_ = engine.binding_guard(@syntax.Span::detached())
  guard module_.field(name, guard_) is Func(func) else {
    fail("\{name} is not a function")
  }
  match func.call_values(engine, @library.Context::none(), [Int(arg)]) {
    Content(content) => content.plain_text()
    value => value.repr()
  }
}

///|
/// What the three functions of a module return for 1.
fn called_all(world : TestWorld, module_ : @library.Module) -> String raise {
  ["f", "g", "h"].map(name => called(world, module_, name, 1L)).join(", ")
}

///|
test "a closure of an earlier evaluation runs the body it was made from" {
  let results = oracle_memo_on_off(() => {
    let world = test_world("", files=[
      (
        "lib.typ", "#let f(x) = { x + 1 }\n\n#let g(x) = [got #x]\n\n#let h(x) = f(x) * 2\n",
      ),
    ])
    let before = evaluated_module(world, "lib.typ")
    let out = [called_all(world, before)]
    // The body of `f` changes: a code block that is reparsed inside the
    // closure. The module of the earlier evaluation and its closures are
    // what they were.
    edit_file(
      world, "lib.typ", "#let f(x) = { x + 100 }\n\n#let g(x) = [got #x]\n\n#let h(x) = f(x) * 2\n",
    )
    out.push(called_all(world, before))
    let second = evaluated_module(world, "lib.typ")
    out.push(called_all(world, second))
    // Text in front of all three and another body for `g` (markup of a
    // content block), then a file that does not parse, then a repair that
    // is parsed as a whole.
    edit_file(
      world, "lib.typ", "Intro.\n\n#let f(x) = { x + 100 }\n\n#let g(x) = [had #x twice]\n\n#let h(x) = f(x) * 2\n",
    )
    out.push(called_all(world, before))
    out.push(called_all(world, second))
    let third = evaluated_module(world, "lib.typ")
    out.push(called_all(world, third))
    edit_file(world, "lib.typ", "#let f(x) = { x + \n\n#let g(x) = [")
    edit_file(
      world, "lib.typ", "#let f(x) = { x - 1 }\n#let g(x) = [none]\n#let h(x) = f(x) * 3\n",
    )
    out.push(called_all(world, before))
    out.push(called_all(world, second))
    out.push(called_all(world, third))
    out.push(called_all(world, evaluated_module(world, "lib.typ")))
    out
  })
  // The first evaluation's closures before and after the first edit, the
  // second evaluation's; the three after the second edit; the four after
  // the last.
  inspect(
    results.join(" | "),
    content="2, got 1, 4 | 2, got 1, 4 | 101, got 1, 202 | 2, got 1, 4 | 101, got 1, 202 | 101, had 1 twice, 202 | 2, got 1, 4 | 101, got 1, 202 | 101, had 1 twice, 202 | 0, none, 0",
  )
}
