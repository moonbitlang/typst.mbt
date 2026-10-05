// The structural dump of the `edsl` stages on raw text.

///|
test "structural dump: raw text is compared by its lines" {
  let span = @syntax.Span::detached()
  let dump = (text : @library.RawContent) => {
    let dumper : StructDumper = { elems: [], locations: None, }
    dumper.content(@library.RawElem::new(text).with_block(true).pack())
  }
  let lines = (lines : Array[String]) => {
    @library.RawContent::Lines(lines.map(line => (line, span)))
  }
  // The lines of raw syntax and the string of the `raw` function with the
  // same lines are the same raw text.
  inspect(
    dump(lines(["a", " b"])),
    content="raw@0(text: lines(\"a\", \" b\"), block: true)",
  )
  assert_eq(dump(lines(["a", " b"])), dump(Text("a\n b")))
  assert_eq(dump(lines([""])), dump(Text("")))
  assert_eq(dump(lines(["", ""])), dump(Text("\n")))
  assert_eq(dump(lines(["a\tb"])), dump(Text("a\tb")))
  // A raw without lines is no `raw("")`, which has one empty line.
  inspect(dump(lines([])), content="raw@0(text: lines(), block: true)")
  inspect(dump(Text("")), content="raw@0(text: lines(\"\"), block: true)")
  // A string is split at every newline of Typst.
  inspect(
    dump(Text("a\r\nb\u{2028}c")),
    content="raw@0(text: lines(\"a\", \"b\", \"c\"), block: true)",
  )
}
