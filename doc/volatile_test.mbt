// The virtual files of a session change while it compiles: the origin
// listing grows with every origin that is registered, also by callbacks
// during layout. The engine is told so (`Registry::changes`, the "volatile
// files" of `library/tracked_world.mbt`) and keeps no result that read one
// (`docs/incremental-design.md`, section 5.2).

///|
/// The values of the metadata elements of a compiled document.
fn metadata_values(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> Array[String] raise {
  guard report.output() is Some(document) else {
    fail(report.errors.map(e => e.message).join(" | "))
  }
  document
  .introspector()
  .query(Elem(@library.metadata_elem(), None))
  .map(elem => @library.MetadataElem::of(elem).unwrap().value().repr())
}

///|
test "a function that reads the origin listing is not answered from an earlier call" {
  // `n()` is called before and after a show callback makes nodes, whose
  // origins are appended to the listing, both times from the same place
  // (a call is found again by its function, its arguments and their
  // spans). It must not be kept here.
  let build = () => {
    compile_paged([
      @doc.Show(@doc.Select::heading()) <| ((it, _) => {
        @doc.Block(@doc.Seq([it, @doc.Emph("shown")]))
      }),
      @doc.Markup(
        (
          #|#let n() = read("<edsl-origins>").len()
          #|#let m() = context metadata(n())
          #|#m()
          #|
          #|= Heading
          #|
          #|#m()
        ),
      ),
    ])
  }
  let memoized = metadata_values(build())
  @library.set_layout_memo_enabled(false)
  let plain = {
    defer @library.set_layout_memo_enabled(true)
    metadata_values(build())
  }
  assert_eq(memoized, plain)
  assert_eq(memoized.length(), 2)
  // The listing grew between the two calls.
  assert_true(memoized[0] != memoized[1])
}

///|
fn compile_paged(
  children : Array[&@doc.IntoContent],
) -> @doc.CompileReport[@layout.PagedDocument] {
  @doc.Document(children).compile_paged(@doc.DocWorld::in_memory())
}

///|
test "the fragments of one lowering are one scope; two lowerings are two" {
  // A world that counts how often a data file is read.
  let mut reads = 0
  let mut data = "one"
  let world = @doc.DocWorld::new(
    load=id => {
      match id.vpath().get_without_slash() {
        "a.typ" => b"#let x = read(\"d.txt\")\n"
        "d.txt" => {
          reads += 1
          @utf8.encode(data)
        }
        path => raise @library.FileError::NotFound(path)
      }
    },
    book=@library.FontBook::new(),
    font=_ => Option::None,
  )
  let lowered = () => {
    let report = @doc.Document([
      @doc.Markup("#import \"a.typ\": x\n#x"),
      @doc.Markup("#import \"a.typ\": x\n#x!"),
    ]).lower(world)
    guard report.output() is Some(content) else {
      fail(report.errors.map(e => e.message).join(" | "))
    }
    content.plain_text()
  }
  // Both fragments import the file: it is evaluated once (a module per
  // file and scope), so its data file is read once.
  assert_true(lowered().contains("one"))
  assert_eq(reads, 1)
  // The next lowering is another scope: it sees the file as it is then.
  data = "two"
  let again = lowered()
  assert_true(again.contains("two") && !again.contains("one"))
  assert_eq(reads, 2)
}
