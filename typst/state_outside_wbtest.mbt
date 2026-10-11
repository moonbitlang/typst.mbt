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
  let document = match warned.output {
    Ok(document) => document
    Err(errors) => fail(errors.map(error => error.message).join("; "))
  }
  // The compilation generated the works of the document for this very
  // introspector, and the store keeps them: the tests are about a call
  // that generates them, so they start with nothing.
  @library.evict(0)
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
  // (The stores are the process's: the test starts with nothing.)
  @library.evict(0)
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
  // (The stores are the process's: the test starts with nothing.)
  @library.evict(0)
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
test "works: math in an entry is evaluated on a route of its own" {
  // (The stores are the process's: the test starts with nothing.)
  @library.evict(0)
  // The entry of the works tracks its route and is not kept if the call
  // asked the route anything. The math of a title is evaluated from the
  // root of a new route (upstream `show_math`, `eval_string`), whose depth
  // checks are not questions to the route of the call: with them taken
  // for such, a bibliography with a formula in it was generated for every
  // citation.
  // (The world has no fonts, and an equation cannot be laid out without
  // one: the bibliography is generated and not shown.)
  let cited = Cited::new(
    "#show bibliography: none\n@knuth\n#bibliography(\"refs.bib\")",
    [("refs.bib", outside_bib("On $sqrt(2)$ and $x^2$"))],
  )
  let steps = @library.with_layout_memo(() => [cited.step(), cited.step()])
  inspect(
    steps.join("\n"),
    content=(
      #|D. Knuth, On 2 and x2. 1984. (generated 1)
      #|D. Knuth, On 2 and x2. 1984. (generated 0)
    ),
  )
}

///|
test "works: a CSL style that changes behind its path" {
  // (The stores are the process's: the test starts with nothing.)
  @library.evict(0)
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
  // (The stores are the process's: the test starts with nothing.)
  @library.evict(0)
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
  // (From scratch again: a compilation that finds everything keeps, and
  // so checks, nothing.)
  @library.evict(0)
  let checked = checked_compile(world)
  assert_eq(checked.differ, [])
  assert_true(checked.entries >= 12)
}

///|
/// An opaque PNG of one colour.
fn outside_png(r : Int, g : Int, b : Int) -> Bytes {
  let pixels = Bytes::makei(4 * 4 * 3, i => {
    match i % 3 {
      0 => r.to_byte()
      1 => g.to_byte()
      _ => b.to_byte()
    }
  })
  @codecs.encode_png(pixels[:], 4, 4, Rgb)
}

///|
/// An SVG that shows the image next to it.
let outside_svg : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20">
  #|  <image href="photo.png" x="0" y="0" width="20" height="20"/>
  #|</svg>
  #|

///|
/// The hashes of the pages of the world's document, as `typst watch` keeps
/// them to decide whether a page is exported again (`cli/compile.mbt`,
/// `ExportCache`).
fn outside_page_hashes(world : ReadingWorld) -> Array[@library.U128] raise {
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = compile(world)
  guard warned.output is Ok(document) else { fail("the document compiles") }
  let hashes = []
  for page in document.pages() {
    hashes.push(@library.hash128(page))
  }
  hashes
}

///|
test "svg: a linked image that changes is another page" {
  // Two compilations of one world. The SVG file is what it was; the image
  // it links is not. The pages hashed the same, so a watching compiler did
  // not export the page again and its PNG kept the old photo.
  let world = reading_world("#image(\"art.svg\")")
  world.data[reading_id("art.svg")] = @utf8.encode(outside_svg)
  world.data[reading_id("photo.png")] = outside_png(255, 0, 0)
  let red = outside_page_hashes(world)
  assert_eq(outside_page_hashes(world), red)
  world.data[reading_id("photo.png")] = outside_png(0, 0, 255)
  let blue = outside_page_hashes(world)
  assert_true(blue != red)
  // The same bytes in another object are the same image.
  world.data[reading_id("photo.png")] = outside_png(0, 0, 255)
  assert_eq(outside_page_hashes(world), blue)
  world.data[reading_id("photo.png")] = outside_png(255, 0, 0)
  assert_eq(outside_page_hashes(world), red)
}

///|
test "svg: a tiling of an SVG is as good as the images the SVG links" {
  // A value that holds the decoded image: the tiling lays out its body
  // when it is made and keeps the frame. Whoever is handed the tiling (a
  // memoized closure call, for one) reads no file, so the tiling itself
  // must tell the two apart: its fingerprint, which is in keys, and its
  // equality, by which arguments are compared.
  let made = (r : Int, b : Int) => {
    let world = reading_world(
      "#let t = tiling(size: (20pt, 20pt), image(\"art.svg\", width: 20pt))\n#metadata(t)",
    )
    world.data[reading_id("art.svg")] = @utf8.encode(outside_svg)
    world.data[reading_id("photo.png")] = outside_png(r, 0, b)
    let warned : @library.Warned[
      Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
    ] = compile(world)
    guard warned.output is Ok(document) else { fail("the document compiles") }
    let elem = document
      .introspector()
      .query(Elem(@library.metadata_elem(), None))[0]
    guard @library.MetadataElem::of(elem) is Some(metadata) else {
      fail("metadata")
    }
    guard metadata.value() is Tiling(tiling) else { fail("a tiling") }
    tiling
  }
  let red = made(255, 0)
  let again = made(255, 0)
  let blue = made(0, 255)
  assert_true(red == again)
  assert_eq(@library.hash128(red), @library.hash128(again))
  assert_true(red != blue)
  assert_true(@library.hash128(red) != @library.hash128(blue))
}

///|
test "svg: the linked image is a read of every call that decodes the SVG" {
  // Upstream: `SvgImage::with_fonts_images` is memoized and tracks the
  // world, whose `file` the image resolver calls. Here the read is the
  // tracked world's, and the recording check compares what the entries
  // keep with what a run from scratch asks.
  let world = reading_world(
    "#let f() = image(\"art.svg\", width: 20pt)\n#block(f())\n#block(f())\n#box(fill: tiling(size: (20pt, 20pt), f()), width: 40pt, height: 40pt)",
  )
  world.data[reading_id("art.svg")] = @utf8.encode(outside_svg)
  world.data[reading_id("photo.png")] = outside_png(255, 0, 0)
  let checked = checked_compile(world)
  assert_eq(checked.text, "")
  assert_eq(checked.differ, [])
  assert_true(checked.entries >= 2)
  // A linked image that is not there fails the document, and comes back.
  world.data.remove(reading_id("photo.png"))
  let checked = checked_compile(world)
  assert_true(
    checked.text.contains("failed to load linked image photo.png in SVG"),
  )
  assert_eq(checked.differ, [])
  world.data[reading_id("photo.png")] = outside_png(0, 0, 255)
  let checked = checked_compile(world)
  assert_eq(checked.text, "")
  assert_eq(checked.differ, [])
}
