// The block level of the flow (slice 2 of `docs/incremental-design.md`):
// `layout_single_impl` and `layout_multi_impl` (`layout/flow_collect.mbt`)
// are memoized like upstream's (`typst-layout/src/flow/collect.rs:420` and
// `:520`), through the store of paragraphs and fragments. What is tested
// here is that the layouts of blocks are found again, by a later
// compilation and by a later iteration of one, and that what is found is
// what a compilation without memoization gives.
//
// The worlds of these tests have no fonts: what is laid out is shapes of a
// given size, which is all that a block's frame needs to differ.

///|
/// The block layouts that `f` found in the store and that it computed
/// (`@layout.block_memo_stats`).
fn block_memo_delta(f : () -> Unit raise) -> (Int32, Int32) raise {
  let before = @layout.block_memo_stats()
  f()
  let after = @layout.block_memo_stats()
  (after.0 - before.0, after.1 - before.1)
}

///|
/// The world with another text in its main file, as a watching compiler
/// has it after an edit: the source that `Source::replace` made of the one
/// it had, the same library and the same other files.
fn block_memo_edit(world : ReadingWorld, text : String) -> ReadingWorld {
  { ..world, main: world.main.replace(text).0, }
}

///|
/// The hashes of the pages of a compilation without memoization, which
/// asks no store and leaves nothing in one.
fn block_memo_reference(world : ReadingWorld) -> Array[@library.U128] raise {
  @library.set_layout_memo_enabled(false)
  defer @library.set_layout_memo_enabled(true)
  outside_page_hashes(world)
}

///|
/// A page with a table (header, footer, lines, a cell that spans), a grid,
/// blocks in blocks, shapes and a block that breaks across pages.
let block_memo_document : String =
  #|#set page(width: 160pt, height: 120pt, margin: 10pt)
  #|#let cell(w, h) = rect(width: w, height: h)
  #|#table(
  #|  columns: (30pt, 1fr, auto),
  #|  stroke: 1pt + black,
  #|  table.header(cell(10pt, 6pt), cell(12pt, 6pt), cell(14pt, 6pt)),
  #|  table.hline(stroke: 2pt),
  #|  table.cell(colspan: 2, cell(20pt, 8pt)), cell(8pt, 8pt),
  #|  cell(9pt, 9pt), table.cell(fill: red, cell(7pt, 7pt)), cell(5pt, 5pt),
  #|  table.footer(cell(3pt, 3pt), cell(4pt, 4pt), cell(5pt, 5pt)),
  #|)
  #|#grid(columns: 2, gutter: 3pt, cell(10pt, 10pt), cell(11pt, 11pt))
  #|#block(fill: blue, inset: 2pt, block(stroke: 1pt, inset: 3pt, cell(16pt, 6pt)))
  #|#block(breakable: false, cell(40pt, 12pt))
  #|#block(breakable: true, {
  #|  for i in range(8) { cell(50pt, 20pt) }
  #|})
  #|#ellipse(width: 20pt, height: 10pt)
  #|

///|
test "blocks: a table and a block are found again by the next compilation" {
  @library.evict(0)
  let world = reading_world(block_memo_document)
  let pages = []
  let first = block_memo_delta(() => pages.push(outside_page_hashes(world)))
  // Nothing to find in an empty store, in a document of one iteration.
  assert_eq(first.0, 0)
  // The table, the grid, the two blocks around the cell, the block that
  // does not break, the one that does, and the ellipse, at least.
  assert_true(first.1 >= 7)
  assert_true(pages[0].length() >= 2)
  // The next compilation of the same world computes none of them, and
  // asks for none: it finds its document (slice 3), and what is found asks
  // for nothing beneath it.
  let second = block_memo_delta(() => pages.push(outside_page_hashes(world)))
  assert_eq(second, (0, 0))
  assert_eq(pages[1], pages[0])
  assert_eq(block_memo_reference(world), pages[0])
  // After an edit at the end of the file the document and its page run
  // are laid out, and every block before the edit is found: the nodes
  // outside of the edit keep their span numbers.
  let edited = block_memo_edit(
    world,
    block_memo_document + "#rect(width: 5pt, height: 5pt)\n",
  )
  let third = block_memo_delta(() => pages.push(outside_page_hashes(edited)))
  assert_true(third.0 >= 6)
  // The new rectangle, and the block that breaks, whose regions end where
  // the page does and so with what follows it.
  assert_true(third.1 <= 2)
  assert_eq(block_memo_reference(edited), pages[2])
  assert_true(pages[2] != pages[0])
  // And with memoization off nothing is asked.
  let off = block_memo_delta(() => block_memo_reference(world) |> ignore)
  assert_eq(off, (0, 0))
}

///|
test "blocks: found by the later iterations of one compilation" {
  @library.evict(0)
  // The page count is known in the second iteration; the table does not
  // ask for it and is laid out once: its page run is laid out again (the
  // number beside the table is another child), and the table is found. The
  // block of the second page is not asked for a second time: its run is
  // found (slice 3).
  let world = reading_world(
    (
      #|#set page(width: 160pt, height: 120pt, margin: 10pt)
      #|#context counter(page).final().first()
      #|#table(columns: 2, rect(width: 10pt, height: 10pt), rect(width: 5pt, height: 5pt))
      #|#pagebreak()
      #|#block(rect(width: 10pt, height: 10pt))
      #|
    ),
  )
  let pages = []
  let runs = @layout.page_run_memo_stats()
  let counts = block_memo_delta(() => pages.push(outside_page_hashes(world)))
  assert_true(counts.0 >= 1)
  assert_true(@layout.page_run_memo_stats().0 - runs.0 >= 1)
  assert_eq(block_memo_reference(world), pages[0])
}

///|
/// One table that stays and one that changes in one thing. Every variant
/// is another key: its table is laid out, the other table is found, and
/// the pages are those of a compilation without memoization.
test "blocks: tables that differ in one cell, stroke, track or header flag are different keys" {
  @library.evict(0)
  let document = (second : String) => {
    (
      #|#set page(width: 200pt, height: auto, margin: 10pt)
      #|#let cell(w, h) = rect(width: w, height: h)
      #|#table(columns: 2, cell(10pt, 10pt), cell(20pt, 10pt), cell(5pt, 5pt), cell(6pt, 6pt))
      #|
    ) +
    second +
    "\n"
  }
  let table = (
    columns : String,
    stroke : String,
    repeat : String,
    last : String,
    extra : String,
  ) => {
    "#table(columns: \{columns}, stroke: \{stroke}, " +
    "table.header(repeat: \{repeat}, cell(8pt, 4pt), cell(9pt, 4pt)), " +
    "cell(12pt, 12pt), cell(13pt, 13pt), cell(14pt, 14pt), \{last}\{extra})"
  }
  let base = table("(40pt, 50pt)", "1pt", "true", "cell(15pt, 15pt)", "")
  let variants = [
    ("a cell", table("(40pt, 50pt)", "1pt", "true", "cell(15pt, 16pt)", "")),
    (
      "the fill of a cell",
      table(
        "(40pt, 50pt)", "1pt", "true", "table.cell(fill: red, cell(15pt, 15pt))",
        "",
      ),
    ),
    ("a stroke", table("(40pt, 50pt)", "2pt", "true", "cell(15pt, 15pt)", "")),
    (
      "the stroke of one cell",
      table(
        "(40pt, 50pt)", "1pt", "true", "table.cell(stroke: (bottom: 3pt), cell(15pt, 15pt))",
        "",
      ),
    ),
    (
      "a column size",
      table("(40pt, 51pt)", "1pt", "true", "cell(15pt, 15pt)", ""),
    ),
    (
      "a header flag",
      table("(40pt, 50pt)", "1pt", "false", "cell(15pt, 15pt)", ""),
    ),
    (
      "a line",
      table(
        "(40pt, 50pt)", "1pt", "true", "cell(15pt, 15pt)", ", table.hline(stroke: 4pt)",
      ),
    ),
    (
      "a footer",
      table(
        "(40pt, 50pt)", "1pt", "true", "cell(15pt, 15pt)", ", table.footer(cell(1pt, 1pt), cell(2pt, 2pt))",
      ),
    ),
  ]
  let world = reading_world(document(base))
  let pages = outside_page_hashes(world)
  let seen = [pages]
  for variant in variants {
    let (name, second) = variant
    let edited = block_memo_edit(world, document(second))
    let mut got = []
    let counts = block_memo_delta(() => got = outside_page_hashes(edited))
    // The table that changed is laid out, and so are the cells in it that
    // are blocks; the other table is found with everything in it.
    if counts.1 < 1 {
      fail("\{name}: no block was laid out")
    }
    if counts.0 < 1 {
      fail("\{name}: the table that did not change was laid out again")
    }
    if got != block_memo_reference(edited) {
      fail("\{name}: not the pages of a compilation without memoization")
    }
    for other in seen {
      if other == got {
        fail("\{name}: the pages of another table")
      }
    }
    seen.push(got)
    // The same text again finds everything.
    let again = block_memo_delta(() => {
      assert_eq(outside_page_hashes(edited), got)
    })
    if again.1 != 0 {
      fail("\{name}: laid out again for the same text")
    }
  }
  // And back: the first document is found as it was, as a document
  // (slice 3), so that no block is asked for.
  let back = block_memo_edit(world, document(base))
  let documents = @layout.document_memo_stats()
  let counts = block_memo_delta(() => {
    assert_eq(outside_page_hashes(back), pages)
  })
  assert_eq(counts, (0, 0))
  assert_true(@layout.document_memo_stats().0 - documents.0 >= 1)
}

///|
/// Upstream tracks the locator of a block layout; here the resolved locator
/// is in the key. One call gives one content with one span: what tells
/// the three layouts apart is where they are.
test "blocks: the same block at three places is three layouts" {
  @library.evict(0)
  let world = reading_world(
    (
      #|#set page(width: 160pt, height: auto, margin: 10pt)
      #|#let stamp() = block(breakable: false, context {
      #|  rect(width: here().position().y, height: 4pt)
      #|})
      #|#stamp()
      #|#stamp()
      #|#stamp()
      #|
    ),
  )
  let pages = outside_page_hashes(world)
  assert_eq(block_memo_reference(world), pages)
  // A compilation that lays the page run out again (a rectangle more at
  // its end; the same text would find the document) finds all three.
  let edited = block_memo_edit(
    world,
    world.main.text() + "#rect(width: 5pt, height: 5pt)\n",
  )
  let mut after = []
  let again = block_memo_delta(() => after = outside_page_hashes(edited))
  assert_true(again.1 <= 1)
  assert_true(again.0 >= 3)
  assert_eq(block_memo_reference(edited), after)
}

///|
/// The style chain is in the key: a block whose text did not change is
/// another layout under another set rule before it.
test "blocks: the same block under other styles is another layout" {
  @library.evict(0)
  let document = (inset : Int32) => {
    "#set page(width: 160pt, height: auto, margin: 10pt)\n" +
    "#set block(inset: \{inset}pt)\n" +
    "#block(rect(width: 20pt, height: 10pt))\n" +
    "#block(breakable: true, rect(width: 30pt, height: 10pt))\n"
  }
  let world = reading_world(document(2))
  let narrow = outside_page_hashes(world)
  let edited = block_memo_edit(world, document(7))
  let mut wide = []
  let counts = block_memo_delta(() => wide = outside_page_hashes(edited))
  // The two blocks; the rectangles in them are blocks under the same
  // styles as before (the inset of a block is not inherited).
  assert_true(counts.1 >= 2)
  assert_true(wide != narrow)
  assert_eq(block_memo_reference(edited), wide)
  let back = block_memo_edit(world, document(2))
  let counts = block_memo_delta(() => {
    assert_eq(outside_page_hashes(back), narrow)
  })
  assert_eq(counts.1, 0)
}

///|
/// The regions of a block that breaks are in the key with the heights of
/// the regions after the first: a block that spills onto a page with less
/// room than the page before promised (a footnote of its own) is laid out
/// again for the regions as they are.
test "blocks: a block that breaks is laid out for the regions it gets" {
  @library.evict(0)
  let world = reading_world(
    (
      #|#set page(width: 160pt, height: 120pt, margin: 10pt)
      #|#rect(width: 20pt, height: 40pt)
      #|#block(breakable: true, {
      #|  for i in range(12) {
      #|    rect(width: 50pt, height: 14pt)
      #|    if i == 5 { footnote(rect(width: 30pt, height: 30pt)) }
      #|  }
      #|})
      #|
    ),
  )
  let pages = outside_page_hashes(world)
  assert_true(pages.length() >= 3)
  assert_eq(block_memo_reference(world), pages)
  let again = block_memo_delta(() => {
    assert_eq(outside_page_hashes(world), pages)
  })
  assert_eq(again.1, 0)
}

///|
/// A block whose layout reads `sys.inputs` is another layout under another
/// library. Upstream hashes the library into the key; here the store
/// compares it as an object, and a block that can tell two libraries apart
/// has another key under each besides: the closure of a `context` block
/// captured what it uses of the standard library, `sys` with the inputs
/// among it.
test "blocks: a block is laid out again under another library" {
  @library.evict(0)
  let text =
    #|#set page(width: 160pt, height: auto, margin: 10pt)
    #|#block(inset: 2pt, context {
    #|  let side = int(sys.inputs.at("side", default: "10")) * 1pt
    #|  rect(width: side, height: side)
    #|})
    #|
  let inputs = (side : String) => {
    let dict = @library.Dict::new()
    dict.insert("side", Str(side))
    library_builder([]).with_inputs(dict).build()
  }
  let world = reading_world(text)
  let other = { ..world, library: inputs("30"), }
  let same = { ..world, library: inputs("10"), }
  // (The hashes of pages are not compared across libraries: the elements
  // of two libraries are two sets of descriptors.)
  let height = (world : ReadingWorld) => {
    let warned : @library.Warned[
      Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
    ] = compile(world)
    guard warned.output is Ok(document) else { fail("the document compiles") }
    document.pages()[0].frame.height().to_pt()
  }
  let small = height(world)
  let mut large = 0.0
  let counts = block_memo_delta(() => large = height(other))
  assert_true(counts.1 >= 1)
  assert_eq(small, 34.0)
  assert_eq(large, 54.0)
  assert_eq(block_memo_reference(other), outside_page_hashes(other))
  // A library that says the same is still another library.
  let counts = block_memo_delta(() => assert_eq(height(same), small))
  assert_true(counts.1 >= 1)
  // And each finds its own again.
  let counts = block_memo_delta(() => {
    assert_eq(height(world), small)
    assert_eq(height(other), large)
    assert_eq(height(same), small)
  })
  assert_eq(counts.1, 0)
}

///|
/// A block of a host with a layout callback of its own (an element has one
/// callback per kind: this one stands for a rule), laid out as the only
/// child of a flow from a root locator, on a route of a given depth and
/// under a given library. Returns the height of the frame in whole points,
/// or the message of the error.
fn block_memo_probe(
  world : ReadingWorld,
  library : @library.Library,
  depth : Int32,
  block : @library.Content,
) -> String {
  let tracked = @library.TrackedWorld::new(world)
  let mut route = @library.Route::root()
  for _ in 0..<depth {
    route = @library.Route::extend_(route)
  }
  let engine : @library.Engine = {
    world: tracked,
    library,
    introspector: @library.Introspector::empty(),
    traced: @library.Traced::new(),
    sink: @library.Sink::new(),
    route,
  }
  let size = @library.Axes::new(
    @library.Abs::pt(100.0),
    @library.Abs::pt(100.0),
  )
  let frame = tracked.scoped(() => {
    @library.with_layout_memo(() => {
      @layout.layout_frame(
        engine,
        block,
        @library.Locator::root(),
        @library.StyleChain::new(library.styles),
        @library.LayoutRegion::new(size, @library.Axes::splat(false)),
      )
    })
  }) catch {
    @library.SourceError(errors) => return errors.map(e => e.message).join("; ")
  }
  frame.height().to_pt().round().to_int().to_string()
}

///|
/// Upstream tracks the route of a block layout; here the whole route is in
/// the key. In a document the route of a layout is as deep as the layout
/// is nested, and what is nested differently has another locator, so this
/// takes a host: one block, one locator, two depths, one of them a level
/// too deep for the callback.
test "blocks: a block is laid out for the route it is on" {
  @library.evict(0)
  let world = reading_world("")
  let mut calls = 0
  let block = @library.BlockElem::single_layouter(
    @library.PadElem::new(@library.Content::empty()),
    (_, engine, _, _, _) => {
      calls += 1
      @library.at(@syntax.Span::detached(), () => {
        engine.route.check_layout_depth()
      })
      @library.Frame::soft(
        @library.Axes::new(@library.Abs::pt(10.0), @library.Abs::pt(10.0)),
      )
    },
  ).pack()
  // The flow is one level below the route it is called on and the block
  // one below the flow.
  let deepest = @library.max_layout_depth - 2
  let found = block_memo_delta(() => {
    inspect(
      block_memo_probe(world, world.library, deepest, block),
      content="10",
    )
    inspect(
      block_memo_probe(world, world.library, deepest, block),
      content="10",
    )
  })
  assert_eq(calls, 1)
  assert_eq(found.1, 1)
  // A level deeper it is another layout, which fails.
  inspect(
    block_memo_probe(world, world.library, deepest + 1, block),
    content="maximum layout depth exceeded",
  )
  assert_eq(calls, 2)
  inspect(block_memo_probe(world, world.library, deepest, block), content="10")
  assert_eq(calls, 2)
}

///|
/// Upstream hashes the library into the key of a block layout; here the
/// store compares it as an object. A block of a document that can tell two
/// libraries apart has another key under each (the test above this one's
/// neighbour, with `sys.inputs`); a callback that asks the library does
/// not.
test "blocks: a block whose callback asks the library is laid out per library" {
  @library.evict(0)
  let world = reading_world("")
  let plain = library_builder([])
    .with_features(@library.Features::none())
    .build()
  let mut calls = 0
  let block = @library.BlockElem::single_layouter(
    @library.PadElem::new(@library.Content::empty()),
    (_, engine, _, _, _) => {
      calls += 1
      let height = if engine.library.features.is_enabled(Html) {
        30.0
      } else {
        10.0
      }
      @library.Frame::soft(
        @library.Axes::new(@library.Abs::pt(10.0), @library.Abs::pt(height)),
      )
    },
  ).pack()
  inspect(block_memo_probe(world, world.library, 0, block), content="30")
  inspect(block_memo_probe(world, plain, 0, block), content="10")
  assert_eq(calls, 2)
  // Each finds its own.
  inspect(block_memo_probe(world, world.library, 0, block), content="30")
  inspect(block_memo_probe(world, plain, 0, block), content="10")
  assert_eq(calls, 2)
}

///|
/// A warning of the layout of a block is a warning of every compilation
/// that finds the layout.
test "blocks: the warnings of a block that is found are reported again" {
  @library.evict(0)
  let world = reading_world(
    (
      #|#set page(width: 160pt, height: auto, margin: 10pt)
      #|#block(par[#box(width: 5pt, height: 5pt) #parbreak() #box(width: 6pt, height: 6pt)])
      #|#context counter(page).final().first()
      #|
    ),
  )
  let warnings = (world : ReadingWorld) => {
    let warned : @library.Warned[
      Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
    ] = compile(world)
    guard warned.output is Ok(_) else { fail("the document compiles") }
    warned.warnings.map(warning => warning.message)
  }
  let expected = [
    "parbreak may not occur inside of a paragraph and was ignored",
  ]
  // The second iteration of the first compilation finds the page run with
  // the block in it (slice 3: the run asked the introspector nothing), and
  // the run says what its block said.
  let mut first = []
  let runs = @layout.page_run_memo_stats()
  block_memo_delta(() => first = warnings(world)) |> ignore
  assert_eq(first, expected)
  assert_true(@layout.page_run_memo_stats().0 - runs.0 >= 1)
  // The same text: the document is found, and says it too.
  let mut second = []
  let counts = block_memo_delta(() => second = warnings(world))
  assert_eq(counts, (0, 0))
  assert_eq(second, expected)
  // A rectangle more at the end: the page run is laid out again and the
  // block is found, by itself.
  let edited = block_memo_edit(
    world,
    world.main.text() + "#rect(width: 5pt, height: 5pt)\n",
  )
  let mut third = []
  let counts = block_memo_delta(() => third = warnings(edited))
  assert_true(counts.0 >= 1)
  assert_true(counts.1 <= 1)
  assert_eq(third, expected)
}

///|
test "blocks: a block that reads a file is laid out again when the file changes" {
  @library.evict(0)
  // The file is read while the block is laid out (a `context` expression
  // is evaluated by the layout of what it is in), so the read is one of
  // the block's entry and of nothing above it but the pages.
  let world = reading_world(
    (
      #|#set page(width: 160pt, height: auto, margin: 10pt)
      #|#block(inset: 2pt, context {
      #|  let side = int(read("side.txt")) * 1pt
      #|  rect(width: side, height: side)
      #|})
      #|#block(rect(width: 10pt, height: 10pt))
      #|
    ),
    data=[("side.txt", "12")],
  )
  let small = outside_page_hashes(world)
  let found = block_memo_delta(() => {
    assert_eq(outside_page_hashes(world), small)
  })
  assert_eq(found.1, 0)
  world.data[reading_id("side.txt")] = @utf8.encode("30")
  let mut large = []
  let counts = block_memo_delta(() => large = outside_page_hashes(world))
  // The block that read the file and the rectangle in it, which is a block
  // of another size now; not the other block.
  assert_eq(counts.1, 2)
  assert_true(counts.0 >= 1)
  assert_true(large != small)
  assert_eq(block_memo_reference(world), large)
  // The old bytes in a new object: the first layout is found again.
  world.data[reading_id("side.txt")] = @utf8.encode("12")
  let back = block_memo_delta(() => assert_eq(outside_page_hashes(world), small))
  assert_eq(back.1, 0)
}

///|
test "blocks: a block whose content queries the document is laid out again when the answer changes" {
  @library.evict(0)
  let document = (headings : Int32) => {
    (
      #|#set page(width: 160pt, height: auto, margin: 10pt)
      #|#block(inset: 2pt, context {
      #|  let side = query(heading).len() * 10pt + 5pt
      #|  rect(width: side, height: side)
      #|})
      #|#block(rect(width: 10pt, height: 10pt))
      #|
    ) +
    "#heading(rect(width: 3pt, height: 3pt))\n".repeat(headings)
  }
  let world = reading_world(document(1))
  let one = outside_page_hashes(world)
  assert_eq(block_memo_reference(world), one)
  let found = block_memo_delta(() => assert_eq(outside_page_hashes(world), one))
  assert_eq(found.1, 0)
  // Another heading after the blocks: their text, their styles, their
  // regions and their places are what they were, and the block that asked
  // for the headings is not what it was.
  let edited = block_memo_edit(world, document(2))
  let mut two = []
  let counts = block_memo_delta(() => two = outside_page_hashes(edited))
  assert_true(counts.1 >= 1)
  assert_true(counts.0 >= 1)
  assert_true(two != one)
  assert_eq(block_memo_reference(edited), two)
}

///|
/// What a store keeps is not what a caller has: a host that holds a
/// document may do to its pages what the engine does to frames, through
/// the methods of the frame it owns (they copy on write, also the frames
/// of the groups in it: the header of `library/frame.mbt`), and the next
/// compilation still finds the layouts as they were made.
///
/// A frame taken out of a group of an `items()` view and written to
/// directly is not covered by a copy-on-write clone: such a frame is the
/// object that the store's copy holds too. Since slice 3 the document that
/// `layout_document` returns has frames and groups of its own at every
/// depth (`Frame::deep_clone`); `typst/layers_memo_wbtest.mbt` writes to
/// them.
test "blocks: the frames of a kept layout are not those of the document" {
  @library.evict(0)
  let world = reading_world(block_memo_document)
  let compile_pages = (world : ReadingWorld) => {
    let warned : @library.Warned[
      Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
    ] = compile(world)
    guard warned.output is Ok(document) else { fail("the document compiles") }
    document
  }
  let hashes = (document : @layout.PagedDocument) => {
    document.pages().map(page => @library.hash128(page))
  }
  let first = compile_pages(world)
  let expected = hashes(first)
  // Every page of the first document: what is not a tag removed at every
  // depth (`hide` goes into the groups), the rest moved and resized.
  for page in first.pages() {
    let frame = page.frame
    frame.hide()
    frame.translate(
      @library.Point::new(@library.Abs::pt(7.0), @library.Abs::pt(9.0)),
    )
    frame.set_size(
      @library.Axes::new(@library.Abs::pt(1.0), @library.Abs::pt(1.0)),
    )
    frame.set_baseline(@library.Abs::pt(1.0))
  }
  assert_true(hashes(first) != expected)
  // The same text: the document is found (slice 3), as it was laid out.
  let mut second = []
  let counts = block_memo_delta(() => second = hashes(compile_pages(world)))
  assert_eq(counts, (0, 0))
  assert_eq(second, expected)
  // A rectangle more at the end: the page run is laid out again, of the
  // blocks that are kept, which are what they were.
  let edited = block_memo_edit(
    world,
    block_memo_document + "#rect(width: 5pt, height: 5pt)\n",
  )
  let mut third = []
  let counts = block_memo_delta(() => third = hashes(compile_pages(edited)))
  assert_true(counts.0 >= 6)
  assert_true(counts.1 <= 2)
  assert_eq(block_memo_reference(edited), third)
  // The same with the pages emptied.
  for page in compile_pages(edited).pages() {
    page.frame.clear()
  }
  let again = block_memo_edit(
    edited,
    block_memo_document + "#rect(width: 5pt, height: 6pt)\n",
  )
  assert_eq(block_memo_reference(again), hashes(compile_pages(again)))
}
