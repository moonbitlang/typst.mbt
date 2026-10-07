// What is kept by content beyond a compilation (`library/memo_content.mbt`:
// decoded raster images), seen from documents: a
// world whose files change between compilations, as in `typst watch`, must
// give what a first compilation of the changed files gives, and what
// compilations without memoization give.

///|
/// A world of text and binary files that a test replaces between
/// compilations.
priv struct FilesWorld {
  library : @library.Library
  sources : Map[@syntax.FileId, @syntax.Source]
  files : Map[@syntax.FileId, Bytes]
  /// The number of files handed out (reads of the world).
  mut reads : Int
}

///|
fn files_id(path : String) -> @syntax.FileId {
  let vpath = @syntax.VirtualPath::new(path) catch {
    _ => abort("invalid path")
  }
  @syntax.RootedPath::new(Project, vpath).intern()
}

///|
impl @library.World for FilesWorld with fn library(self) {
  self.library
}

///|
impl @library.World for FilesWorld with fn main(_) {
  files_id("main.typ")
}

///|
impl @library.World for FilesWorld with fn source(self, id) {
  match self.sources.get(id) {
    Some(source) => source
    None => raise @library.FileError::NotFound("?")
  }
}

///|
impl @library.World for FilesWorld with fn file(self, id) {
  self.reads += 1
  match self.files.get(id) {
    // A new object for every read, like a file that is read again.
    Some(bytes) => Bytes::makei(bytes.length(), i => bytes[i])
    None => raise @library.FileError::NotFound("?")
  }
}

///|
impl @library.World for FilesWorld with fn today(_, _) {
  None
}

///|
fn files_world(
  sources : Array[(String, String)],
  files : Array[(String, Bytes)],
) -> FilesWorld {
  let world = {
    library: library([]),
    sources: Map([]),
    files: Map([]),
    reads: 0,
  }
  for source in sources {
    let id = files_id(source.0)
    world.sources[id] = @syntax.Source::new(id, source.1)
  }
  for file in files {
    world.files[files_id(file.0)] = file.1
  }
  world
}

///|
/// The metadata strings of the world's document, or its errors.
fn files_strings(world : FilesWorld) -> Array[String] {
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = compile(world)
  match warned.output {
    Ok(doc) => oracle_strings(doc)
    Err(errors) => errors.map(e => "error: " + e.message)
  }
}

///|
test "images: a file that changes behind its path, and a broken one" {
  let png = (seed : Int) => {
    let pixels = Bytes::makei(4 * 3 * 3, i => ((seed + i) * 7).to_byte())
    @codecs.encode_png(pixels[:], 4, 3, Rgb)
  }
  let wide = {
    let pixels = Bytes::makei(8 * 3 * 3, i => (i * 5).to_byte())
    @codecs.encode_png(pixels[:], 8, 3, Rgb)
  }
  let main =
    #|#let report(path) = context {
    #|  let size = measure(image(path))
    #|  metadata(path + " " + repr(size.width) + " " + repr(size.height))
    #|}
    #|#report("a.png") #report("b.png") #report("a.png")
    #|#image("a.png") #image("b.png") #image("a.png")
    #|
  let reports = oracle_memo_on_off(() => {
    let world = files_world([("main.typ", main)], [
      ("a.png", png(1)),
      ("b.png", png(2)),
    ])
    let reports = [files_strings(world).join(" | ")]
    // Every use read its file, and this world gives another object for
    // every read: the images are found by what the bytes are.
    assert_true(world.reads >= 6)
    // Another image behind the path.
    @library.evict(10)
    world.files[files_id("a.png")] = wide
    reports.push(files_strings(world).join(" | "))
    // A broken one, used four times in each of two compilations: the same
    // error every time (one diagnostic per compilation, as they are equal).
    @library.evict(10)
    world.files[files_id("a.png")] = Bytes::makei(wide.length() - 20, i => {
      wide[i]
    })
    reports.push(files_strings(world).join(" | "))
    @library.evict(10)
    reports.push(files_strings(world).join(" | "))
    // And repaired.
    world.files[files_id("a.png")] = png(1)
    reports.push(files_strings(world).join(" | "))
    reports
  })
  inspect(
    reports.join("\n"),
    content=(
      #|a.png 4pt 3pt | b.png 4pt 3pt | a.png 4pt 3pt
      #|a.png 8pt 3pt | b.png 4pt 3pt | a.png 8pt 3pt
      #|error: failed to decode image (Format error decoding Png: Unexpected end of data within a chunk.)
      #|error: failed to decode image (Format error decoding Png: Unexpected end of data within a chunk.)
      #|a.png 4pt 3pt | b.png 4pt 3pt | a.png 4pt 3pt
    ),
  )
}
