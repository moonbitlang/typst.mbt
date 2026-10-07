// What is kept by content beyond a compilation (`library/memo_content.mbt`:
// decoded raster images, highlighted raw text), seen from documents: a
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
/// A theme that colours keywords.
fn files_theme(keyword : String) -> Bytes {
  @utf8.encode(
    (
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<plist version="1.0"><dict>
      #|<key>name</key><string>Test</string>
      #|<key>settings</key><array>
      #|<dict><key>settings</key><dict>
      #|<key>foreground</key><string>#000000</string>
      #|</dict></dict>
      #|<dict><key>scope</key><string>keyword, storage</string>
      #|<key>settings</key><dict>
      #|<key>foreground</key><string>KEYWORD</string>
      #|</dict></dict>
      #|</array></dict></plist>
      #|
    ).replace(old="KEYWORD", new=keyword),
  )
}

///|
/// A syntax for the language `foo` in which `word` is a keyword.
fn files_syntax(word : String) -> Bytes {
  @utf8.encode(
    (
      #|%YAML 1.2
      #|---
      #|name: Foo
      #|file_extensions: [foo]
      #|scope: source.foo
      #|contexts:
      #|  main:
      #|    - match: \bWORD\b
      #|      scope: keyword.foo
      #|
    ).replace(old="WORD", new=word),
  )
}

///|
/// Reports every piece of highlighted text with its fill, and the lines.
let files_raw_prelude : String =
  #|#show raw: it => {
  #|  show text: t => context {
  #|    metadata(t.text + " " + repr(text.fill))
  #|    t
  #|  }
  #|  metadata("lines " + str(it.lines.len()))
  #|  it
  #|}
  #|

///|
test "raw: a theme and a syntax that change behind their paths" {
  let reports = oracle_memo_on_off(() => {
    let world = files_world(
      [
        (
          "main.typ",
          files_raw_prelude +
          "#set raw(theme: \"t.tmTheme\", syntaxes: \"foo.sublime-syntax\")\n" +
          "```rust\nlet x = 1;\n```\n```foo\nfoo bar\n```\n",
        ),
      ],
      [
        ("t.tmTheme", files_theme("#ff0000")),
        ("foo.sublime-syntax", files_syntax("foo")),
      ],
    )
    let reports = [files_strings(world).join(" | ")]
    // The set rule read the two files; highlighting did not ask the world.
    assert_eq(world.reads, 2)
    // The same sources, another theme: `typst watch` after the theme file
    // was saved (and its `evict` after the compilation).
    @library.evict(10)
    world.files[files_id("t.tmTheme")] = files_theme("#0000ff")
    reports.push(files_strings(world).join(" | "))
    // Another syntax.
    @library.evict(10)
    world.files[files_id("foo.sublime-syntax")] = files_syntax("bar")
    reports.push(files_strings(world).join(" | "))
    // And back to the first files: what was highlighted for them then.
    @library.evict(10)
    world.files[files_id("t.tmTheme")] = files_theme("#ff0000")
    world.files[files_id("foo.sublime-syntax")] = files_syntax("foo")
    reports.push(files_strings(world).join(" | "))
    // A broken theme, twice, and its repair.
    world.files[files_id("t.tmTheme")] = b"<plist"
    reports.push(files_strings(world).join(" | "))
    reports.push(files_strings(world).join(" | "))
    world.files[files_id("t.tmTheme")] = files_theme("#00ff00")
    reports.push(files_strings(world).join(" | "))
    reports
  })
  inspect(
    reports.join("\n"),
    content=(
      #|lines 1 | let rgb("#ff0000") |  x  luma(0%) | = rgb("#ff0000") |   luma(0%) | 1 luma(0%) | ; luma(0%) | lines 1 | foo rgb("#ff0000") |  bar luma(0%)
      #|lines 1 | let rgb("#0000ff") |  x  luma(0%) | = rgb("#0000ff") |   luma(0%) | 1 luma(0%) | ; luma(0%) | lines 1 | foo rgb("#0000ff") |  bar luma(0%)
      #|lines 1 | let rgb("#0000ff") |  x  luma(0%) | = rgb("#0000ff") |   luma(0%) | 1 luma(0%) | ; luma(0%) | lines 1 | foo  luma(0%) | bar rgb("#0000ff")
      #|lines 1 | let rgb("#ff0000") |  x  luma(0%) | = rgb("#ff0000") |   luma(0%) | 1 luma(0%) | ; luma(0%) | lines 1 | foo rgb("#ff0000") |  bar luma(0%)
      #|error: failed to parse theme (Invalid syntax theme settings)
      #|error: failed to parse theme (Invalid syntax theme settings)
      #|lines 1 | let rgb("#00ff00") |  x  luma(0%) | = rgb("#00ff00") |   luma(0%) | 1 luma(0%) | ; luma(0%) | lines 1 | foo rgb("#00ff00") |  bar luma(0%)
    ),
  )
}

///|
test "raw: the same relative path in two directories" {
  // The field says `theme.tmTheme` in both files: what was loaded is part
  // of the element and of the styles.
  let part =
    #|#let part(body) = {
    #|  set raw(theme: "theme.tmTheme", syntaxes: "foo.sublime-syntax")
    #|  body
    #|}
    #|#let block = part[```foo foo bar```]
    #|
  let reports = oracle_memo_on_off(() => {
    let world = files_world(
      [
        (
          "main.typ",
          files_raw_prelude +
          "#import \"a/part.typ\" as a\n#import \"b/part.typ\" as b\n" +
          "#a.block #b.block #a.part[```foo foo bar```] #b.part[```foo foo bar```]\n" +
          // Folded: the syntaxes of both, the outer one first; the theme of
          // the inner one.
          "#a.part(b.part[```foo foo bar```]) #b.part(a.part[```foo foo bar```])\n",
        ),
        ("a/part.typ", part),
        ("b/part.typ", part),
      ],
      [
        ("a/theme.tmTheme", files_theme("#ff0000")),
        ("b/theme.tmTheme", files_theme("#0000ff")),
        ("a/foo.sublime-syntax", files_syntax("foo")),
        ("b/foo.sublime-syntax", files_syntax("bar")),
      ],
    )
    files_strings(world)
  })
  inspect(
    reports.join("\n"),
    content=(
      #|lines 1
      #|foo rgb("#ff0000")
      #| bar luma(0%)
      #|lines 1
      #|foo  luma(0%)
      #|bar rgb("#0000ff")
      #|lines 1
      #|foo rgb("#ff0000")
      #| bar luma(0%)
      #|lines 1
      #|foo  luma(0%)
      #|bar rgb("#0000ff")
      #|lines 1
      #|foo rgb("#0000ff")
      #| bar luma(0%)
      #|lines 1
      #|foo  luma(0%)
      #|bar rgb("#ff0000")
    ),
  )
}

///|
test "raw: blocks that differ in one argument of highlighting" {
  let theme = "bytes(\"" +
    @utf8.decode(files_theme("#ff0000")).replace_all(old="\"", new="\\\"") +
    "\")"
  let reports = oracle_memo_on_off(() => {
    let world = files_world(
      [
        (
          "main.typ",
          files_raw_prelude +
          // The same text as Rust, as Python, without a language.
          "```rust\nlet x = 1;\n```\n```py\nlet x = 1;\n```\n```\nlet x = 1;\n```\n" +
          // In another theme, and without one.
          "#raw(\"let x = 1;\", lang: \"rust\", theme: " +
          theme +
          ")\n#raw(\"let x = 1;\", lang: \"rust\", theme: none)\n" +
          // With tabs of two sizes (from the styles: like upstream,
          // highlighting does not read the element's own `tab-size`).
          "#raw(\"let\\tx\", lang: \"rust\") #raw(\"let\\tx\", lang: \"rust\", tab-size: 8)\n" +
          "#[#set raw(tab-size: 8)\n#raw(\"let\\tx\", lang: \"rust\")]\n" +
          // In text of another colour and size: highlighted the same, the
          // rest of the text takes the colour.
          "#text(fill: blue, size: 20pt)[```rust\nlet x = 1;\n```]\n" +
          // And the first again.
          "```rust\nlet x = 1;\n```\n",
        ),
      ],
      [],
    )
    let first = files_strings(world)
    // A second compilation of the same world gives the same.
    @library.evict(10)
    assert_eq(files_strings(world), first)
    first
  })
  inspect(
    reports.join("\n"),
    content=(
      #|lines 1
      #|let rgb("#d73948")
      #| x  luma(0%)
      #|= rgb("#d73948")
      #|  luma(0%)
      #|1 rgb("#b60157")
      #|; luma(0%)
      #|lines 1
      #|let luma(0%)
      #|  luma(0%)
      #|x luma(0%)
      #|  luma(0%)
      #|= rgb("#d73948")
      #|  luma(0%)
      #|1 rgb("#b60157")
      #|; luma(0%)
      #|lines 1
      #|let x = 1; luma(0%)
      #|lines 1
      #|let rgb("#ff0000")
      #| x  luma(0%)
      #|= rgb("#ff0000")
      #|  luma(0%)
      #|1 luma(0%)
      #|; luma(0%)
      #|lines 1
      #|let x = 1; luma(0%)
      #|lines 1
      #|let rgb("#d73948")
      #| x luma(0%)
      #|lines 1
      #|let rgb("#d73948")
      #| x luma(0%)
      #|lines 1
      #|let rgb("#d73948")
      #|     x luma(0%)
      #|lines 1
      #|let rgb("#d73948")
      #| x  rgb("#0074d9")
      #|= rgb("#d73948")
      #|  rgb("#0074d9")
      #|1 rgb("#b60157")
      #|; rgb("#0074d9")
      #|lines 1
      #|let rgb("#d73948")
      #| x  luma(0%)
      #|= rgb("#d73948")
      #|  luma(0%)
      #|1 rgb("#b60157")
      #|; luma(0%)
    ),
  )
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
