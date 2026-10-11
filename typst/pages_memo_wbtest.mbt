// Page runs and documents that are kept from one layout to the next
// (`docs/incremental-design.md`, section 8, slice 3;
// `library/memo_pages.mbt`, `layout/pages_run.mbt`, `layout/pages.mbt`):
// what is found again, what is laid out again, and that what a caller is
// handed is not what an entry keeps.
//
// The documents draw boxes and hold `metadata`: the world of these tests
// has no font.

///|
/// A world of one file that is edited between compilations, as a watching
/// compiler's is.
priv struct PagesWorld {
  mut main : @syntax.Source
  library : @library.Library
}

///|
impl @library.World for PagesWorld with fn library(self) {
  self.library
}

///|
impl @library.World for PagesWorld with fn main(self) {
  self.main.id()
}

///|
impl @library.World for PagesWorld with fn source(self, id) {
  if id == self.main.id() {
    return self.main
  }
  raise @library.FileError::NotFound(id.vpath().get_without_slash())
}

///|
impl @library.World for PagesWorld with fn file(_, _) {
  raise @library.FileError::AccessDenied
}

///|
impl @library.World for PagesWorld with fn today(_, _) {
  None
}

///|
fn pages_world(
  text : String,
  library? : @library.Library = library([]),
) -> PagesWorld {
  { main: @syntax.Source::detached(text), library, }
}

///|
/// The text of the main file replaced by an edit of its source, as
/// `FileStore` does after a reset: the nodes that the edit does not touch
/// keep their span numbers.
fn PagesWorld::edit(self : PagesWorld, text : String) -> Unit {
  self.main = self.main.replace(text).0
}

///|
/// What a compilation gave and what it asked of the stores of documents
/// and of page runs.
priv struct PagesStep {
  /// The document, or the messages of its errors.
  output : Result[@layout.PagedDocument, String]
  warnings : Array[String]
  /// "documents: found, computed; page runs: found, computed".
  counts : String
}

///|
fn PagesWorld::step(self : PagesWorld) -> PagesStep {
  let documents = @layout.document_memo_stats()
  let runs = @layout.page_run_memo_stats()
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = compile(self)
  let (found, computed) = @layout.document_memo_stats()
  let (run_found, run_computed) = @layout.page_run_memo_stats()
  let counts = "documents: \{found - documents.0} found, \{computed - documents.1} computed; page runs: \{run_found - runs.0} found, \{run_computed - runs.1} computed"
  {
    output: match warned.output {
      Ok(document) => Ok(document)
      Err(errors) => Err(errors.map(error => error.message).join(" | "))
    },
    warnings: warned.warnings.map(warning => {
      if warning.hints.is_empty() {
        warning.message
      } else {
        warning.message + " (" + warning.hints.map(h => h.v).join("; ") + ")"
      }
    }),
    counts,
  }
}

///|
/// The pages of a compilation from scratch of the world as it is, with
/// memoization and without: what a recompilation must give
/// ([document_prints]). It leaves the stores empty.
fn PagesWorld::scratch(self : PagesWorld) -> Array[String] raise {
  oracle_memo_on_off(() => {
    @library.evict(0)
    let prints = document_prints(self.step().document())
    @library.evict(0)
    prints
  })
}

///|
fn PagesStep::document(self : PagesStep) -> @layout.PagedDocument raise {
  match self.output {
    Ok(document) => document
    Err(errors) => fail(errors)
  }
}

///|
/// The errors of a compilation that failed ("" if it did not).
fn PagesStep::errors(self : PagesStep) -> String {
  match self.output {
    Ok(_) => ""
    Err(errors) => errors
  }
}

///|
/// What the `metadata` elements of the document say, in order.
fn PagesStep::says(self : PagesStep) -> String raise {
  oracle_strings(self.document()).join(" ")
}

///|
/// The pages of a document as their fingerprints (upstream's `Hash for
/// Page`: every item of the frame with its span, the fill, the numbering,
/// the supplement, the number), with the info and the format options.
fn document_prints(document : @layout.PagedDocument) -> Array[String] {
  let prints = []
  for page in document.pages() {
    let print = @library.hash128(page)
    prints.push("\{print}")
  }
  let info = document.info()
  prints.push(
    "title " +
    info.title.unwrap_or("none") +
    " authors " +
    info.author.join(",") +
    " keywords " +
    info.keywords.join(","),
  )
  let print = @library.hash128(document.options())
  prints.push("\{print}")
  prints
}

///|
/// Three page runs. The first two say nothing about the rest of the
/// document; the last has a block that reads the final value of a counter
/// that the first two step (a block realizes its body when it is laid
/// out, so the read is the page run's).
fn three_runs(first : String) -> String {
  "#set page(width: 100pt, height: 100pt, margin: 10pt)\n" +
  "#let c = counter(\"c\")\n" +
  first +
  "\n#rect(width: 30pt, height: 30pt)\n" +
  "#pagebreak()\n" +
  "#c.step()\n#rect(width: 40pt, height: 40pt)\n" +
  "#pagebreak()\n" +
  "#block(context metadata(\"final \" + str(c.final().first())))\n" +
  "#rect(width: 50pt, height: 50pt)\n"
}

///|
test "pages: a document that is what it was is not laid out again" {
  @library.evict(0)
  let world = pages_world(three_runs("#c.step()"))
  // Two iterations: the last page reads the counter, which the first
  // iteration sees as it is in an empty document. In the second, the runs
  // of the first two pages are found (they asked the introspector
  // nothing), and the third is laid out again.
  let first = world.step()
  inspect(first.says(), content="final 2")
  inspect(
    first.counts,
    content="documents: 0 found, 2 computed; page runs: 2 found, 4 computed",
  )
  let pages = document_prints(first.document())
  // The same files: the module is found, and the document of each
  // iteration. No page run is asked for.
  let second = world.step()
  inspect(
    second.counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
  inspect(second.says(), content="final 2")
  assert_eq(document_prints(second.document()), pages)
  // A comment at the end. The file is evaluated again, and its content is
  // not what it was: it ends with the space before the comment and the one
  // after it. So the document is laid out, as upstream's is; its page runs
  // have the children they had and are found.
  world.edit(three_runs("#c.step()") + "// a comment\n")
  let third = world.step()
  inspect(
    third.counts,
    content="documents: 0 found, 2 computed; page runs: 6 found, 0 computed",
  )
  assert_eq(document_prints(third.document()), pages)
  // Another comment in its place: the content is what it was, with the
  // spans it had, and the document is found.
  world.edit(three_runs("#c.step()") + "// another comment, a longer one\n")
  let fourth = world.step()
  inspect(
    fourth.counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
  assert_eq(document_prints(fourth.document()), pages)
  // Comemo's ages: found after ten evictions, gone after the eleventh.
  for _ in 0..<10 {
    @library.evict(10)
  }
  inspect(
    world.step().counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
  for _ in 0..<11 {
    @library.evict(10)
  }
  inspect(
    world.step().counts,
    content="documents: 0 found, 2 computed; page runs: 2 found, 4 computed",
  )
  // With memoization off nothing is asked and nothing is left.
  @library.evict(0)
  @library.set_layout_memo_enabled(false)
  let plain = {
    defer @library.set_layout_memo_enabled(true)
    let plain = world.step()
    inspect(
      plain.counts,
      content="documents: 0 found, 0 computed; page runs: 0 found, 0 computed",
    )
    plain
  }
  assert_eq(document_prints(plain.document()), pages)
  inspect(@layout.document_memo_entries(), content="0")
  inspect(@layout.page_run_memo_entries(), content="0")
}

///|
test "pages: a page run is found again when another run of the document changed" {
  @library.evict(0)
  let world = pages_world(three_runs("#c.step()"))
  let first = world.step()
  inspect(first.says(), content="final 2")
  let before = document_prints(first.document())
  // The first run steps the counter once more. The document is another
  // one. Of its runs: the first is laid out once (it asks the introspector
  // nothing, so the second iteration finds it), the second is found in
  // both iterations, and the third is found in the first iteration (an
  // empty document has no update of the counter, as before) and laid out
  // again in the second: its children are what they were, and the one
  // thing that changed for it is the value of the counter that it reads.
  world.edit(three_runs("#c.step()\n#c.step()"))
  let second = world.step()
  inspect(second.says(), content="final 3")
  inspect(
    second.counts,
    content="documents: 0 found, 2 computed; page runs: 4 found, 2 computed",
  )
  let after = document_prints(second.document())
  // The page of the run that was found is the page it was.
  assert_eq(after[1], before[1])
  assert_false(after[2] == before[2])
  // And back: the entries of the first compilation are still there.
  world.edit(three_runs("#c.step()"))
  let third = world.step()
  inspect(third.says(), content="final 2")
  assert_eq(document_prints(third.document()), before)
  // What compilations from scratch give, of the same sources (a fresh
  // parse would number the nodes anew).
  assert_eq(world.scratch(), before)
  world.edit(three_runs("#c.step()\n#c.step()"))
  assert_eq(world.scratch(), after)
}

///|
test "pages: a document whose only change is a counter value read on page 3 is laid out again" {
  // Within one compilation: the document of the first iteration was laid
  // out against an empty introspector, and the second iteration asks for
  // the same content and styles against the introspector of that
  // document. The entry is under the same key; what rejects it is the
  // read of the counter on page 3, which answers 2 now and answered 0.
  @library.evict(0)
  let world = pages_world(three_runs("#c.step()"))
  let first = world.step()
  inspect(first.says(), content="final 2")
  inspect(@layout.document_memo_entries(), content="2")
  // Both documents are kept, and each is found only by the iteration
  // whose introspector answers what it asked: the next compilation gives
  // the document of the second iteration, not that of the first.
  let second = world.step()
  inspect(second.says(), content="final 2")
  inspect(
    second.counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
  // A document that needs a third iteration: the block on page 1 is as
  // high as the counter says, so the pages move when it is known.
  @library.evict(0)
  let moving = "#set page(width: 100pt, height: 100pt, margin: 10pt)\n" +
    "#let c = counter(\"c\")\n" +
    "#block(context rect(width: 10pt, height: c.final().first() * 30pt))\n" +
    "#c.step()\n#rect(width: 30pt, height: 30pt)\n" +
    "#c.step()\n#rect(width: 30pt, height: 30pt)\n" +
    "#block(context metadata(\"page \" + str(here().page()) + \" of \" + str(counter(page).final().first())))\n"
  let world = pages_world(moving)
  let first = world.step()
  inspect(first.says(), content="page 3 of 3")
  inspect(
    first.counts,
    content="documents: 0 found, 3 computed; page runs: 0 found, 3 computed",
  )
  let second = world.step()
  inspect(second.says(), content="page 3 of 3")
  inspect(
    second.counts,
    content="documents: 3 found, 0 computed; page runs: 0 found, 0 computed",
  )
  assert_eq(
    document_prints(second.document()),
    document_prints(first.document()),
  )
}

///|
test "pages: what a caller writes to a document it was handed is not written to the kept one" {
  @library.evict(0)
  let source = "#set document(title: [Kept], author: (\"A\", \"B\"), keywords: (\"k\",))\n" +
    three_runs("#c.step()")
  let world = pages_world(source, library=library(@library.default_formats()))
  let first = world.step().document()
  let pristine = document_prints(first)
  // A host that holds a document and writes to all of it.
  let scribble = (document : @layout.PagedDocument) => {
    for page in document.pages() {
      // The frame of the page itself, and the frames inside it (the
      // marginals and the flow of the page run are groups).
      page.frame.push(
        @library.Point::zero(),
        Shape(
          @library.Geometry::Rect(
            @library.Axes::new(@library.Abs::pt(3.0), @library.Abs::pt(3.0)),
          ).filled(Solid(@library.color_white)),
          @syntax.Span::detached(),
        ),
      )
      page.frame.translate(
        @library.Point::new(@library.Abs::pt(5.0), @library.Abs::pt(7.0)),
      )
      page.frame.hide()
      page.frame.set_size(
        @library.Axes::new(@library.Abs::pt(1.0), @library.Abs::pt(1.0)),
      )
    }
    let info = document.info_mut()
    info.title = Some("Scribbled")
    info.author.push("C")
    info.keywords.clear()
    document
    .options()
    .populate(
      @library.StyleChain::new(
        @library.Styles::from_array([@library.SvgFormat::set_pretty(true)]),
      ),
      @syntax.Span::detached(),
    )
  }
  scribble(first)
  // (Every part was written to: a page, the info, the format options.)
  let scribbled = document_prints(first)
  let last = pristine.length() - 1
  assert_false(scribbled[0] == pristine[0])
  assert_false(scribbled[last - 1] == pristine[last - 1])
  assert_false(scribbled[last] == pristine[last])
  // The document that the entry kept is what was laid out.
  let second = world.step()
  inspect(
    second.counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
  let second = second.document()
  assert_eq(document_prints(second), pristine)
  // And so is the one that an entry hands out: writing to it does not
  // reach the entry or the document that was handed out before it.
  let held = world.step().document()
  scribble(second)
  assert_eq(document_prints(held), pristine)
  assert_eq(document_prints(world.step().document()), pristine)
  // The introspector is the one thing they share: it is made once, of the
  // pages as they were laid out, and answers what it answered.
  inspect(oracle_strings(first).join(" "), content="final 2")
  assert_true(first.introspector().serial() == second.introspector().serial())
}

///|
test "pages: what a caller writes to the pages of a run it was handed is not written to the kept run" {
  // `finalize_page` moves the frames of a run's pages into the frame of
  // the page, and whoever holds the document can write to them there.
  @library.evict(0)
  let world = pages_world(three_runs("#c.step()"))
  let first = world.step().document()
  let pristine = document_prints(first)
  for page in first.pages() {
    page.frame.hide()
    page.frame.translate(
      @library.Point::new(@library.Abs::pt(5.0), @library.Abs::pt(7.0)),
    )
  }
  assert_false(document_prints(first)[1] == pristine[1])
  // Another first run: the document is laid out again, and the run of its
  // second page is found.
  world.edit(three_runs("#c.step()\n#c.step()"))
  let second = world.step()
  inspect(
    second.counts,
    content="documents: 0 found, 2 computed; page runs: 4 found, 2 computed",
  )
  let second = second.document()
  assert_eq(document_prints(second)[1], pristine[1])
  // Once more, with the pages of the run that was just found written to.
  for page in second.pages() {
    page.frame.hide()
  }
  world.edit(three_runs("#c.step()\n#c.step()\n#c.step()"))
  assert_eq(document_prints(world.step().document())[1], pristine[1])
}

///|
/// Writes to every group of a frame and to the frames inside them, as a
/// holder that takes the groups out of `Frame::items`: the transform, the
/// clip and the label of each, and the innermost frames are emptied.
/// Returns the number of groups and the greatest depth.
fn scribble_groups(frame : @library.Frame, depth : Int) -> (Int, Int) {
  let mut groups = 0
  let mut deepest = depth
  for entry in frame.items() {
    guard entry.1 is Group(group) else { continue }
    let (inside, below) = scribble_groups(group.frame, depth + 1)
    groups += 1 + inside
    if below > deepest {
      deepest = below
    }
    group.transform = @library.Transform::translate(
      @library.Abs::pt(3.0),
      @library.Abs::pt(4.0),
    )
    group.clip = Some(
      @library.Curve::rect(
        @library.Axes::new(@library.Abs::pt(1.0), @library.Abs::pt(1.0)),
      ),
    )
    group.label = @library.Label::new("scribbled")
    if inside == 0 {
      group.frame.clear()
    }
  }
  (groups, deepest)
}

///|
test "pages: what a caller writes to a group inside a page it was handed is written to no kept layout" {
  // A copy-on-write clone of a frame shares its groups with what it was
  // cloned from, and the frames of a document are clones of the frames
  // that the entries of the document, of its page runs and of its blocks
  // keep. The document that a caller gets has groups and frames of its own
  // at every depth.
  let nested = "#c.step()\n#block(clip: true, inset: 2pt, rotate(10deg, block(clip: true, inset: 2pt, rect(width: 10pt, height: 10pt))))\n"
  let source = (first : String) => {
    "#set page(width: 100pt, height: 100pt, margin: 10pt)\n" +
    "#let c = counter(\"c\")\n" +
    first +
    "\n#rect(width: 30pt, height: 30pt)\n#pagebreak()\n" +
    nested +
    "#pagebreak()\n" +
    "#block(context metadata(\"final \" + str(c.final().first())))\n"
  }
  @library.evict(0)
  let world = pages_world(source("#c.step()"))
  // The document of a computation.
  let first = world.step().document()
  let pristine = document_prints(first)
  let (groups, depth) = scribble_groups(first.pages()[1].frame, 0)
  inspect("\{groups} groups, \{depth} deep", content="3 groups, 3 deep")
  for page in first.pages() {
    scribble_groups(page.frame, 0) |> ignore
  }
  assert_false(document_prints(first)[1] == pristine[1])
  // The document that is found is what was laid out, and writing to it
  // changes nothing for the next one.
  let second = world.step()
  inspect(
    second.counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
  let second = second.document()
  assert_eq(document_prints(second), pristine)
  for page in second.pages() {
    scribble_groups(page.frame, 0) |> ignore
  }
  assert_eq(document_prints(world.step().document()), pristine)
  // Another first run: the document is laid out, the run of the second
  // page is found, with the frames it had; and the same once more for the
  // blocks of that page (their fragments are kept layouts too), whose run
  // is laid out again when its first child changes.
  world.edit(source("#c.step()\n#c.step()"))
  let third = world.step()
  inspect(
    third.counts,
    content="documents: 0 found, 2 computed; page runs: 4 found, 2 computed",
  )
  let third = third.document()
  assert_eq(document_prints(third)[1], pristine[1])
  for page in third.pages() {
    scribble_groups(page.frame, 0) |> ignore
  }
  world.edit(source("#c.step()\n#c.step()\n#c.step()"))
  let fourth = world.step().document()
  assert_eq(document_prints(fourth)[1], pristine[1])
  // What compilations from scratch give.
  let after = document_prints(fourth)
  assert_eq(world.scratch(), after)
}

///|
test "pages: a document and a page run are those of their library" {
  // Upstream hashes the library into the key of every memoized function
  // that builds an engine; here an entry is taken for the library object
  // it was computed with. Two libraries with the same styles and other
  // formats: the content, the styles and the children of the run are the
  // same, and the format options of the document are not.
  @library.evict(0)
  let source = three_runs("#c.step()")
  let plain = pages_world(source)
  let first = plain.step()
  inspect(
    first.counts,
    content="documents: 0 found, 2 computed; page runs: 2 found, 4 computed",
  )
  let with_formats = pages_world(
    source,
    library=library(@library.default_formats()),
  )
  let second = with_formats.step()
  inspect(
    second.counts,
    content="documents: 0 found, 2 computed; page runs: 2 found, 4 computed",
  )
  let first = document_prints(first.document())
  let second = document_prints(second.document())
  // The pages are the same, the format options (the last line) are those
  // of each library.
  assert_eq(second[0:3].to_owned(), first[0:3].to_owned())
  assert_false(second[second.length() - 1] == first[first.length() - 1])
  // Each library finds its own.
  inspect(
    plain.step().counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
  inspect(
    with_formats.step().counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
  assert_eq(document_prints(with_formats.step().document()), second)
}

///|
test "pages: runs with the same children are told apart by where they are" {
  // Empty pages one after the other are runs without children under the
  // same styles. What tells them apart is their locator, which the key
  // holds (upstream tracks it): the elements of their footers get their
  // locations from it. With one layout for all of them, the footers
  // would be one element at one place.
  let source = "#set page(width: 100pt, height: 100pt, margin: 20pt, footer: context metadata(\"page \" + str(here().page())))\n" +
    "#rect(width: 10pt, height: 10pt)\n" +
    "#pagebreak()\n#pagebreak()\n#pagebreak()\n#pagebreak()\n" +
    "#rect(width: 10pt, height: 10pt)\n"
  let says = oracle_memo_on_off(() => {
    @library.evict(0)
    let step = pages_world(source).step()
    (step.says(), step.document().pages().length())
  })
  inspect(says.0, content="page 1 page 2 page 3 page 4 page 5")
  inspect(says.1, content="5")
  // And in a watching process, with a page more before them.
  @library.evict(0)
  let world = pages_world(source)
  inspect(world.step().says(), content="page 1 page 2 page 3 page 4 page 5")
  world.edit(
    source.replace(
      old="#rect(width: 10pt, height: 10pt)\n#pagebreak()",
      new="#rect(width: 10pt, height: 10pt)\n#pagebreak()\n#rect(width: 12pt, height: 12pt)\n#pagebreak()",
    ),
  )
  let second = world.step()
  inspect(second.says(), content="page 1 page 2 page 3 page 4 page 5 page 6")
  @library.evict(10)
  inspect(
    world.step().says(),
    content="page 1 page 2 page 3 page 4 page 5 page 6",
  )
}

///|
test "pages: the documents of a bundle are told apart by where they are" {
  // `layout_document_for_bundle` is given a locator (upstream tracks it,
  // `typst-layout/src/pages/mod.rs:102`; here the key holds it resolved):
  // two documents of a bundle with the same content and styles have
  // elements at other locations.
  @library.evict(0)
  let world = pages_world(
    "#metadata(\"m\") <m>\n#rect(width: 10pt, height: 10pt)\n",
  )
  let tracked = @library.TrackedWorld::new(world)
  let (locations, counts) = tracked.scoped(() => {
    @library.with_layout_memo(() => {
      let sink = @library.Sink::new()
      let content = @eval.eval_source(
        tracked,
        world.library,
        @library.Traced::new(),
        sink,
        @library.Route::root(),
        world.main,
      ).content()
      let styles = @library.StyleChain::new(world.library.styles)
      let engine : @library.Engine = {
        library: world.library,
        world: tracked,
        introspector: @library.Introspector::empty(),
        traced: @library.Traced::new(),
        sink,
        route: @library.Route::root(),
      }
      let split = @library.Locator::root().split()
      let first = split.next(1)
      let second = split.next(2)
      let before = @layout.document_memo_stats()
      let locations = []
      // At one place, at another, and at the first again.
      for locator in [first.relayout(), second, first] {
        let document = @layout.layout_document_for_bundle(
          engine, content, locator, styles,
        )
        let found = document
          .introspector()
          .query(Elem(@library.metadata_elem(), None))
        locations.push(found[0].location().unwrap())
      }
      let after = @layout.document_memo_stats()
      (locations, "\{after.0 - before.0} found, \{after.1 - before.1} computed")
    })
  })
  inspect(counts, content="1 found, 2 computed")
  assert_false(locations[0] == locations[1])
  assert_true(locations[0] == locations[2])
}

///|
test "pages: a document that is found says what its layout said" {
  // A delayed error of a block's `context`, and a warning: the sink of
  // the layout, which a hit replays.
  @library.evict(0)
  let world = pages_world(
    "#set page(width: 100pt, height: 100pt)\n#block(context panic(\"boom\"))\n",
  )
  let first = world.step()
  inspect(first.errors(), content="panicked with: boom")
  let second = world.step()
  inspect(second.errors(), content="panicked with: boom")
  inspect(
    second.counts,
    content="documents: 1 found, 0 computed; page runs: 0 found, 0 computed",
  )
  // A document that does not converge: the warning names what was asked
  // of the introspector, from the sink of the five layouts.
  @library.evict(0)
  let world = pages_world(
    "#set page(width: 100pt, height: 100pt)\n" +
    "#let s = state(\"s\", 1)\n" +
    "#block(context s.update(s.final() + 1))\n" +
    "#block(context metadata(\"value \" + str(s.get())))\n",
  )
  let first = world.step()
  @library.evict(10)
  let second = world.step()
  inspect(first.says(), content="value 5")
  inspect(second.says(), content="value 5")
  assert_true(first.warnings.length() > 0)
  assert_eq(second.warnings, first.warnings)
  assert_true(
    first.warnings[0].has_prefix(
      "document did not converge within five attempts",
    ),
  )
  inspect(
    first.counts,
    content="documents: 0 found, 5 computed; page runs: 0 found, 5 computed",
  )
  // Five documents under one key, and four results per key among those
  // that no `evict` has seen (`memo_max_entries`): the first was dropped
  // for the fifth. So the next compilation of a watching process lays out
  // the first iteration again, to the document it was, and finds the
  // others by their reads; after that all five are there.
  inspect(
    second.counts,
    content="documents: 4 found, 1 computed; page runs: 0 found, 1 computed",
  )
  @library.evict(10)
  let third = world.step()
  inspect(
    third.counts,
    content="documents: 5 found, 0 computed; page runs: 0 found, 0 computed",
  )
  assert_eq(third.warnings, first.warnings)
  assert_eq(
    document_prints(third.document()),
    document_prints(first.document()),
  )
}

///|
test "pages: blank pages, parity and two-sided margins of runs that are found" {
  // The pages of a run do not know their number: `finalize_page` gives a
  // page its margins by it. A run that is found after pages were added
  // before it is finalized on the other side.
  let source = (extra : String) => {
    "#set page(width: 100pt, height: 100pt, margin: (inside: 30pt, outside: 10pt, y: 10pt), fill: yellow)\n" +
    extra +
    "#rect(width: 100%, height: 20pt) <m>\n" +
    "#pagebreak(to: \"odd\")\n" +
    "#block(context { let found = query(<m>); if found.len() > 0 { let at = found.first().location(); metadata(\"m on \" + str(at.page()) + \" at \" + repr(at.position().x) + \", this on \" + str(here().page())) } })\n"
  }
  let fresh = (text : String) => {
    oracle_memo_on_off(() => {
      @library.evict(0)
      let step = pages_world(text).step()
      (step.says(), step.document().pages().length())
    })
  }
  let more = "#rect(width: 20pt, height: 20pt)\n#pagebreak()\n"
  let expected = [
    fresh(source("")),
    fresh(source(more)),
    fresh(source(more + more)),
  ]
  @library.evict(0)
  let world = pages_world(source(""))
  // The labelled run is on the first page, a blank page follows it for
  // the parity.
  let first = world.step()
  inspect(first.says(), content="m on 1 at 30pt, this on 3")
  assert_eq((first.says(), first.document().pages().length()), expected[0])
  // One page more at the start: the run with the label has the children
  // it had and is found, on an even page now, and the blank page is not
  // needed.
  world.edit(source(more))
  let second = world.step()
  inspect(second.says(), content="m on 2 at 10pt, this on 3")
  assert_eq((second.says(), second.document().pages().length()), expected[1])
  world.edit(source(more + more))
  let third = world.step()
  inspect(third.says(), content="m on 3 at 30pt, this on 5")
  assert_eq((third.says(), third.document().pages().length()), expected[2])
  // And back, with every run and blank page found.
  world.edit(source(""))
  let fourth = world.step()
  assert_eq(
    document_prints(fourth.document()),
    document_prints(first.document()),
  )
  inspect(
    fourth.counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
}

///|
test "pages: a layout that failed inside a function read the file for its tracepoint" {
  // Upstream's `Trace::trace` asks the tracked world for the range of the
  // call (`world.range(span)`, a read of the source), so a memoized layout
  // in which a function call failed depends on the file of the call. The
  // port reads the same (`world_range`). Here the first iteration fails
  // inside `where()` (an empty document has no `<m>`; the error is delayed
  // and gone when the second iteration succeeds), so its document and its
  // page run are laid out again after every edit of the file, also one
  // that changes nothing; those of the second iteration are found.
  @library.evict(0)
  let source = "#set page(width: 100pt, height: 100pt)\n" +
    "#let where() = locate(<m>).page()\n" +
    "#rect(width: 10pt, height: 10pt) <m>\n" +
    "#block(context metadata(\"m on \" + str(where())))\n"
  let world = pages_world(source + "// a comment\n")
  let first = world.step()
  inspect(first.says(), content="m on 1")
  inspect(
    first.counts,
    content="documents: 0 found, 2 computed; page runs: 0 found, 2 computed",
  )
  // The same file: nothing was read that is not what it was.
  inspect(
    world.step().counts,
    content="documents: 2 found, 0 computed; page runs: 0 found, 0 computed",
  )
  world.edit(source + "// another comment\n")
  let second = world.step()
  inspect(second.says(), content="m on 1")
  inspect(
    second.counts,
    content="documents: 1 found, 1 computed; page runs: 0 found, 1 computed",
  )
  assert_eq(
    document_prints(second.document()),
    document_prints(first.document()),
  )
}
