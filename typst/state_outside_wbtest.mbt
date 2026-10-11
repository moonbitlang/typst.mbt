// State outside the arguments of a memoized call
// (`docs/incremental-design.md`, section 5.5; step 2 of slice 1), seen
// from documents: the works of a bibliography, which were kept in a cell
// and found by the engine's introspector object, and an SVG image, whose
// identity did not cover the images it links.

///|
/// A bibliography with one book of the given title.
fn outside_bib(title : String) -> Bytes {
  @utf8.encode(
    "@book{knuth, title={\{title}}, author={Knuth, Donald}, year={1984}}\n",
  )
}

///|
/// The entries of the first bibliography of the engine's document, as the
/// works of `engine` have them.
fn outside_entries(
  engine : @library.Engine,
) -> String raise @library.SourceError {
  let span = @syntax.Span::detached()
  let works = @library.Works::generate(engine, span)
  let bibliography = engine.introspector.query(
      Elem(@library.bibliography_elem(), None),
    )[0]
  works.bibliography(bibliography.location().unwrap(), span).entries
  .map(entry => entry.body.plain_text())
  .join(" | ")
}

///|
/// A host that kept a world and the introspector of its document: the
/// world, the engine and its tracked world.
priv struct Cited {
  world : ReadingWorld
  engine : @library.Engine
  tracked : @library.TrackedWorld
}

///|
fn Cited::new(text : String, files : Array[(String, Bytes)]) -> Cited raise {
  let world = reading_world(text)
  for file in files {
    world.data[reading_id(file.0)] = file.1
  }
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = compile(world)
  guard warned.output is Ok(document) else { fail("the document compiles") }
  let tracked = @library.TrackedWorld::new(world)
  let engine : @library.Engine = {
    world: tracked,
    library: world.library,
    introspector: document.introspector(),
    traced: @library.Traced::new(),
    sink: @library.Sink::new(),
    route: @library.Route::root(),
  }
  { world, engine, tracked, }
}

///|
fn Cited::set(self : Cited, path : String, data : Bytes) -> Unit {
  self.world.data[reading_id(path)] = data
}

///|
/// The entries of the bibliography in a scope of its own.
fn Cited::entries(self : Cited) -> String raise @library.SourceError {
  self.tracked.scoped(() => outside_entries(self.engine))
}

///|
/// The same, with the number of times the works were generated for it.
fn Cited::step(self : Cited) -> String raise @library.SourceError {
  let start = @library.works_generation_count()
  let entries = self.entries()
  "\{entries} (generated \{@library.works_generation_count() - start})"
}

///|
test "works: one engine in two scopes, with a bibliography that changes in between" {
  // The works were kept in a cell and found by the engine's introspector
  // object and the elements, which hold the path of the file and not its
  // data: the second scope got the works of the first.
  let cited = Cited::new("@knuth\n#bibliography(\"refs.bib\")", [
    ("refs.bib", outside_bib("Alpha")),
  ])
  inspect(
    cited.entries(),
    content=(
      #|D. Knuth, Alpha. 1984.
    ),
  )
  cited.set("refs.bib", outside_bib("Beta"))
  inspect(
    cited.entries(),
    content=(
      #|D. Knuth, Beta. 1984.
    ),
  )
}

///|
test "works: an entry of the store is found by its key and taken if the files answer the same" {
  let cited = Cited::new("@knuth\n#bibliography(\"refs.bib\")", [
    ("refs.bib", outside_bib("Alpha")),
  ])
  let steps = @library.with_layout_memo(() => {
    let steps = []
    // Computed.
    steps.push(cited.step())
    // Found in another scope: the bibliography file is read again and is
    // what it was.
    steps.push(cited.step())
    // The same bytes in another object.
    cited.set("refs.bib", outside_bib("Alpha"))
    steps.push(cited.step())
    // Other bytes: the entry is rejected by its world reads.
    cited.set("refs.bib", outside_bib("Beta"))
    steps.push(cited.step())
    // And back: both entries are there.
    cited.set("refs.bib", outside_bib("Alpha"))
    steps.push(cited.step())
    cited.set("refs.bib", outside_bib("Beta"))
    steps.push(cited.step())
    steps
  })
  inspect(
    steps.join("\n"),
    content=(
      #|D. Knuth, Alpha. 1984. (generated 1)
      #|D. Knuth, Alpha. 1984. (generated 0)
      #|D. Knuth, Alpha. 1984. (generated 0)
      #|D. Knuth, Beta. 1984. (generated 1)
      #|D. Knuth, Alpha. 1984. (generated 0)
      #|D. Knuth, Beta. 1984. (generated 0)
    ),
  )
  // Outside of a compilation nothing is kept.
  inspect(
    cited.step(),
    content=(
      #|D. Knuth, Beta. 1984. (generated 1)
    ),
  )
  inspect(
    cited.step(),
    content=(
      #|D. Knuth, Beta. 1984. (generated 1)
    ),
  )
}

///|
test "works: a CSL style that changes behind its path" {
  // The style is loaded from its source by the call that generates the
  // works, like the bibliography.
  let style = (delimiter : String) => {
    @utf8.encode(
      (
        #|<?xml version="1.0" encoding="utf-8"?>
        #|<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
        #|  <info><title>Test</title><id>test</id></info>
        #|  <citation><layout><text variable="title"/></layout></citation>
        #|  <bibliography><layout>
        #|    <text variable="title" prefix="DELIM" suffix="DELIM"/>
        #|  </layout></bibliography>
        #|</style>
        #|
      ).replace_all(old="DELIM", new=delimiter),
    )
  }
  let cited = Cited::new(
    "@knuth\n#bibliography(\"refs.bib\", style: \"s.csl\")",
    [("refs.bib", outside_bib("Alpha")), ("s.csl", style("*"))],
  )
  let steps = @library.with_layout_memo(() => {
    let steps = [cited.step(), cited.step()]
    cited.set("s.csl", style("+"))
    steps.push(cited.step())
    steps
  })
  inspect(
    steps.join("\n"),
    content=(
      #|*Alpha* (generated 1)
      #|*Alpha* (generated 0)
      #|+Alpha+ (generated 1)
    ),
  )
}

///|
test "works: generated once for all the calls of an iteration that cite" {
  // Every cell of the table is laid out by a memoized call with an
  // introspector object of its own, for which the cell of the last works
  // found nothing: the works of the document were generated once per cell
  // and layout, 75 times for this document. Now once for every list of
  // elements that an iteration has: none, the bibliography, all of them.
  // (The cells and the bibliography are shown at different depths of the
  // route, which is not in the key.)
  let cells = StringBuilder()
  for _ in 0..<12 {
    cells.write_string("[See @knuth.], ")
  }
  let world = reading_world(
    "#table(columns: 3, \{cells.to_string()})\n#bibliography(\"refs.bib\")",
  )
  world.data[reading_id("refs.bib")] = outside_bib("Alpha")
  let start = @library.works_generation_count()
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = compile(world)
  guard warned.output is Ok(_) else { fail("the document compiles") }
  inspect(@library.works_generation_count() - start, content="3")
  // Under the recording check: the entries that found the works have the
  // read of the bibliography file, as a run from scratch makes it.
  let checked = checked_compile(world)
  assert_eq(checked.differ, [])
  assert_true(checked.entries >= 12)
}
