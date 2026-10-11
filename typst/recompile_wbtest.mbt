// Compilations of one world whose files change in between, as in `typst
// watch` (upstream: comemo reuses a memoized evaluation only if what it read
// from the world is still the same).

///|
/// The text of the content, as an output.
priv struct Texted(String)

///|
impl @library.Output for Texted with fn target() {
  Paged
}

///|
impl @library.Output for Texted with fn create(_, content, _) {
  Texted(content.plain_text())
}

///|
impl @library.Output for Texted with fn introspector(_) {
  @library.Introspector::empty()
}

///|
/// The text a world's document evaluates to, or its errors.
fn evaluated_text(world : TestWorld) -> String {
  let warned : @library.Warned[Result[Texted, Array[@library.SourceDiagnostic]]] = compile(
    world,
  )
  match warned.output {
    Ok(Texted(text)) => text
    Err(errors) => "error: " + errors.map(e => e.message).join(" | ")
  }
}

///|
/// Replaces the text of a file of the world by an edit of its source, as
/// `FileStore` does after a reset.
fn edit_file(world : TestWorld, file : String, text : String) -> Unit raise {
  for id, source in world.files {
    if id.vpath().get_without_slash() == file {
      world.files[id] = source.replace(text).0
      return
    }
  }
  fail("no file \{file}")
}

///|
test "a later compilation sees the files of the world as they are then" {
  let texts = oracle_memo_on_off(() => {
    let world = test_world("#import \"a.typ\": a\n#a", files=[
      ("a.typ", "#import \"b.typ\": b\n#let a = [a sees #b]\n"),
      ("b.typ", "#let b = [one]\n"),
    ])
    let texts = [evaluated_text(world)]
    // The file that changes is not the one whose evaluation is found again
    // by its text.
    edit_file(world, "b.typ", "#let b = [two]\n")
    texts.push(evaluated_text(world))
    // An error in it, and its repair.
    edit_file(world, "b.typ", "#let b = \n")
    texts.push(evaluated_text(world))
    edit_file(world, "b.typ", "#let b = [three]\n")
    texts.push(evaluated_text(world))
    texts
  })
  inspect(
    texts.join("; "),
    content="a sees one; a sees two; error: expected expression; a sees three",
  )
}

///|
test "a file is evaluated once in a compilation" {
  // Modules compare by identity, so both imports must give the same one.
  let world = test_world(
    "#import \"a.typ\"\n#import \"a.typ\" as again\n#(a == again)",
    files=[("a.typ", "#let x = 1\n")],
  )
  inspect(evaluated_text(world), content="true")
  inspect(evaluated_text(world), content="true")
}

///|
test "the main file is evaluated through the store of module evaluations" {
  // Upstream's `eval` is one memoized function for the main file and for
  // imports. A `context` block is laid out with the route of the layout,
  // which the main file is not on, so it can import the main file: that
  // finds the module that the compilation evaluated.
  let world = test_world(
    "#let x = \"once\"\n#context { import \"main.typ\": x; metadata(x) }",
  )
  let before = @eval.module_memo_stats()
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = compile(world)
  let after = @eval.module_memo_stats()
  guard warned.output is Ok(document) else { fail("the document failed") }
  inspect(oracle_strings(document).join(" "), content="once")
  // Evaluated once, and found by every layout of the block.
  inspect(after.1 - before.1, content="1")
  assert_true(after.0 - before.0 >= 1)
}

///|
/// The text a world's main file evaluates to, without a compilation.
fn evaluated_directly(world : TestWorld) -> String {
  try
    @eval.eval_source(
      @library.TrackedWorld::new(world),
      world.library,
      @library.Traced::new(),
      @library.Sink::new(),
      @library.Route::root(),
      world.main,
    )
  catch {
    @library.SourceError(errors) =>
      "error: " + errors.map(e => e.message).join(" | ")
  } noraise {
    module_ => module_.content().plain_text()
  }
}

///|
test "an evaluation outside of a compilation sees the files as they are then" {
  let world = test_world("#import \"a.typ\": a\n#a", files=[
    ("a.typ", "#import \"b.typ\": b\n#let a = [a sees #b]\n"),
    ("b.typ", "#let b = [one]\n"),
  ])
  inspect(evaluated_directly(world), content="a sees one")
  edit_file(world, "b.typ", "#let b = [two]\n")
  inspect(evaluated_directly(world), content="a sees two")
  // A compilation, and an evaluation after it.
  edit_file(world, "b.typ", "#let b = [three]\n")
  inspect(evaluated_text(world), content="a sees three")
  edit_file(world, "b.typ", "#let b = [four]\n")
  inspect(evaluated_directly(world), content="a sees four")
}

///|
/// What a string evaluates to outside of a compilation, as a host evaluates
/// one (`doc`'s `lower` for a fragment of Typst source).
fn evaluated_string(world : TestWorld, code : String) -> String {
  let engine : @library.Engine = {
    library: world.library,
    world: @library.TrackedWorld::new(world),
    introspector: @library.Introspector::empty(),
    traced: @library.Traced::new(),
    sink: @library.Sink::new(),
    route: @library.Route::root(),
  }
  // (With the main file's id, so that paths resolve.)
  try
    @eval.eval_string_mapped(
      engine,
      @library.Context::none(),
      code,
      world.main.id(),
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
test "a string evaluated outside of a compilation imports a file once" {
  // The route of a string is the root, like that of a file evaluated on its
  // own: its imports must not each start an evaluation of their own, or the
  // module of `a.typ` is one object here and another inside `b.typ`
  // (upstream's suite: `import-nested-item`, as `doc` lowers it).
  let world = test_world("", files=[
    ("a.typ", "#let x = 1\n"),
    ("b.typ", "#import \"a.typ\"\n"),
  ])
  let code = "{ import \"a.typ\" as direct; import \"b.typ\": a; direct == a }"
  inspect(evaluated_string(world, code), content="true")
  // And the next evaluation sees the files as they are then.
  edit_file(world, "a.typ", "#let x = 2\n")
  inspect(evaluated_string(world, "{ import \"b.typ\": a; a.x }"), content="2")
}
