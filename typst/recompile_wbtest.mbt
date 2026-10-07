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
/// Replaces the text of a file of the world in place, as `FileStore` does
/// after a reset.
fn edit_file(world : TestWorld, file : String, text : String) -> Unit raise {
  for source in world.files.values() {
    if source.id().vpath().get_without_slash() == file {
      source.replace(text) |> ignore
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
/// The text a world's main file evaluates to, without a compilation.
fn evaluated_directly(world : TestWorld) -> String {
  try
    @eval.eval_source(
      world,
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
