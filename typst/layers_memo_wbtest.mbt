// The kept layouts of the three levels together: blocks (slice 2 of
// `docs/incremental-design.md`), page runs and documents (slice 3). What
// is found asks for nothing beneath it, and what is laid out again finds
// what is beneath it: the reads, the warnings and the frames of what is
// found must be those of the entry around it too.
//
// The helpers are those of `pages_memo_wbtest.mbt`; the documents draw
// boxes (the world of these tests has no font).

///|
/// A step of a world with what it asked of the store of blocks besides:
/// "documents: ..; page runs: ..; blocks: found, computed".
fn PagesWorld::layers(self : PagesWorld) -> PagesStep {
  let blocks = @layout.block_memo_stats()
  let step = self.step()
  let (found, computed) = @layout.block_memo_stats()
  {
    ..step,
    counts: step.counts +
    "; blocks: \{found - blocks.0} found, \{computed - blocks.1} computed",
  }
}

///|
/// Two page runs. The first has a block that reads the final value of a
/// counter, which the second steps, and a rectangle after it.
fn layered(tail : Int, steps : String) -> String {
  "#set page(width: 100pt, height: 100pt, margin: 10pt)\n" +
  "#let c = counter(\"c\")\n" +
  "#block(context [#rect(width: 10pt, height: c.final().first() * 10pt)#metadata(\"final \" + str(c.final().first()))])\n" +
  "#rect(width: \{tail}pt, height: 20pt)\n" +
  "#pagebreak()\n" +
  steps +
  "\n#rect(width: 30pt, height: 30pt)\n"
}

///|
test "layers: the reads of a block that is found are those of the run and of the document around it" {
  @library.evict(0)
  let world = pages_world(layered(20, "#c.step()"))
  let first = world.layers()
  inspect(first.says(), content="final 1")
  inspect(
    first.counts,
    content=(
      #|documents: 0 found, 2 computed; page runs: 1 found, 3 computed; blocks: 1 found, 6 computed
    ),
  )
  // The rectangle after the block changes: the document and the run of
  // the first page are laid out again, in both iterations, and the block
  // is found in both. Its read of the counter is not made; it must be a
  // read of the run that is laid out around it (below) and of the
  // document, whose loop would otherwise end with the first iteration,
  // where the counter is at zero.
  world.edit(layered(21, "#c.step()"))
  let second = world.layers()
  inspect(second.says(), content="final 1")
  inspect(
    second.counts,
    content=(
      #|documents: 0 found, 2 computed; page runs: 2 found, 2 computed; blocks: 3 found, 1 computed
    ),
  )
  // The other run steps the counter once more. The run of the first page
  // has the children it had, and its entries are those of the compilation
  // before, which found the block: the one of the second iteration is
  // rejected by the read that the block made when it was laid out, two
  // compilations ago.
  world.edit(layered(21, "#c.step()\n#c.step()"))
  let third = world.layers()
  inspect(third.says(), content="final 2")
  inspect(
    third.counts,
    content=(
      #|documents: 0 found, 2 computed; page runs: 2 found, 2 computed; blocks: 2 found, 2 computed
    ),
  )
  let pages = document_prints(third.document())
  assert_eq(world.scratch(), pages)
}

///|
test "layers: a block found inside a run found inside a document found says what a compilation from scratch says" {
  // A block whose layout warns, a block that reads the document, and a
  // second run. Whichever level is found, the warning is reported once.
  let source = (tail : Int, other : Int) => {
    "#set page(width: 100pt, height: 100pt, margin: 10pt)\n" +
    "#block(par[#box(width: 5pt, height: 5pt) #parbreak() #box(width: 6pt, height: 6pt)])\n" +
    "#block(context metadata(\"pages \" + str(counter(page).final().first())))\n" +
    "#rect(width: \{tail}pt, height: 20pt)\n" +
    "#pagebreak()\n" +
    "#rect(width: \{other}pt, height: 30pt)\n"
  }
  // From scratch, without memoization.
  let scratch = (text : String) => {
    @library.evict(0)
    @library.set_layout_memo_enabled(false)
    defer @library.set_layout_memo_enabled(true)
    let step = pages_world(text).step()
    (step.warnings, step.says(), step.document().pages().length())
  }
  let expected = scratch(source(20, 30))
  let other_run = scratch(source(20, 31))
  let both = scratch(source(21, 31))
  inspect(
    expected.0.join("; "),
    content="parbreak may not occur inside of a paragraph and was ignored",
  )
  let said = (step : PagesStep) => {
    (step.warnings, step.says(), step.document().pages().length())
  }
  @library.evict(0)
  let world = pages_world(source(20, 30))
  let first = world.layers()
  assert_eq(said(first), expected)
  inspect(
    first.counts,
    content="documents: 0 found, 2 computed; page runs: 1 found, 3 computed; blocks: 2 found, 5 computed",
  )
  // The same text: the document of each iteration is found, and nothing
  // beneath it is asked for.
  let second = world.layers()
  assert_eq(said(second), expected)
  inspect(
    second.counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed; blocks: 0 found, 0 computed",
  )
  assert_eq(
    document_prints(second.document()),
    document_prints(first.document()),
  )
  // The other run changes: the run with the two blocks is found, and no
  // block of it is asked for.
  world.edit(source(20, 31))
  let third = world.layers()
  assert_eq(said(third), other_run)
  inspect(
    third.counts,
    content="documents: 0 found, 2 computed; page runs: 3 found, 1 computed; blocks: 0 found, 1 computed",
  )
  // The rectangle beside the blocks changes: their run is laid out again
  // and both blocks are found, each by itself.
  world.edit(source(21, 31))
  let fourth = world.layers()
  assert_eq(fourth.warnings, expected.0)
  inspect(
    fourth.counts,
    content=(
      #|documents: 0 found, 2 computed; page runs: 2 found, 2 computed; blocks: 5 found, 1 computed
    ),
  )
  assert_eq(said(fourth), both)
}

///|
test "layers: what a caller writes to the groups of a document is written to no kept block" {
  // The frames of a document are made of the frames that the entries of
  // blocks keep, as clones, which share their groups. The document that a
  // caller gets has groups of its own at every depth, so a run that is
  // laid out again from the kept blocks gets them as they were laid out.
  let source = (tail : Int) => {
    "#set page(width: 100pt, height: 100pt, margin: 10pt)\n" +
    "#block(clip: true, inset: 2pt, rotate(10deg, block(clip: true, inset: 2pt, rect(width: 10pt, height: 10pt))))\n" +
    "#block(fill: red, inset: 3pt, block(stroke: 1pt, inset: 2pt, rect(width: 12pt, height: 6pt)))\n" +
    "#rect(width: \{tail}pt, height: 20pt)\n"
  }
  @library.evict(0)
  let world = pages_world(source(20))
  let first = world.layers().document()
  let (groups, depth) = scribble_groups(first.pages()[0].frame, 0)
  inspect("\{groups} groups, \{depth} deep", content="5 groups, 3 deep")
  // The run is laid out again, of blocks that are found.
  world.edit(source(21))
  let second = world.layers()
  inspect(
    second.counts,
    content=(
      #|documents: 0 found, 1 computed; page runs: 0 found, 1 computed; blocks: 2 found, 1 computed
    ),
  )
  let pages = document_prints(second.document())
  // The same once more, with the document that was laid out of found
  // blocks written to.
  scribble_groups(second.document().pages()[0].frame, 0) |> ignore
  world.edit(source(22))
  let third = world.layers()
  let later = document_prints(third.document())
  assert_eq(world.scratch(), later)
  world.edit(source(21))
  assert_eq(world.scratch(), pages)
}

///|
/// The frames of the `html.frame` elements of an HTML document, in order.
fn html_frames(node : @html.HtmlNode, frames : Array[@library.Frame]) -> Unit {
  match node {
    Frame(frame) => frames.push(frame.inner)
    Element(element) =>
      for child in element.children {
        html_frames(child, frames)
      }
    _ => ()
  }
}

///|
test "layers: the frame of an HTML document is not the frame of the kept layout" {
  // `html.frame` lays its body out as a fragment, which is a kept layout,
  // and the frame becomes a node of the document that a host is handed.
  @library.evict(0)
  let source = "#html.frame(block(clip: true, inset: 2pt, rotate(10deg, block(clip: true, inset: 2pt, rect(width: 10pt, height: 10pt)))))\n"
  let world = pages_world(
    source,
    library=library_builder(@library.default_formats())
      .with_features(@library.Features::all())
      .build(),
  )
  let frames = () => {
    let warned : @library.Warned[
      Result[@html.HtmlDocument, Array[@library.SourceDiagnostic]],
    ] = compile(world)
    guard warned.output is Ok(document) else { fail("the document compiles") }
    let frames = []
    html_frames(document.root_node(), frames)
    frames
  }
  let first = frames()
  assert_eq(first.length(), 1)
  let pristine = @library.hash128(first[0])
  let (groups, _) = scribble_groups(first[0], 0)
  assert_true(groups >= 2)
  assert_false(@library.hash128(first[0]) == pristine)
  // The next compilation finds the fragment, as it was laid out.
  let layouts = @library.layout_memo_entries()
  let second = frames()
  assert_eq(@library.layout_memo_entries(), layouts)
  assert_true(@library.hash128(second[0]) == pristine)
}
