// Tests of raw text (`library/text_raw.mbt`, `eval/markup.mbt`): what the
// evaluator stores in a raw element and what highlighting makes of it.
// What a document observes is compared with upstream in
// `oracle_wbtest.mbt`.

///|
/// The raw elements of the evaluated content of a main source, in order.
fn raw_elems(source : @syntax.Source) -> Array[@library.RawElem] raise {
  let world = { main: source, library: library([]), }
  let content = @eval.eval_source(
    world,
    world.library,
    @library.Traced::new(),
    @library.Sink::new(),
    @library.Route::root(),
    source,
  ).content()
  let out = []
  content.traverse(elem => {
    if @library.RawElem::of(elem) is Some(raw) {
      out.push(raw)
    }
    true
  })
  |> ignore
  out
}

///|
/// The syntax nodes of the raw literals of a source, in order.
fn raw_nodes(node : @syntax.SyntaxNode, out : Array[@ast.Raw]) -> Unit {
  if (@ast.Raw::from_untyped(node) : @ast.Raw?) is Some(raw) {
    out.push(raw)
  }
  for child in node.children() {
    raw_nodes(child, out)
  }
}

///|
test "the evaluator stores the lines of raw syntax with their spans" {
  // Upstream `impl Eval for ast::Raw`: `RawContent::Lines` of
  // `(line.get(), line.span())`, the block flag and the language.
  let source = @syntax.Source::detached(
    "`a` ```py\nx = 1\n  y\n``` `` ```\n\n``` #raw(\"a\\nb\") #[`c`]",
  )
  let nodes = []
  raw_nodes(source.root(), nodes)
  let elems = raw_elems(source)
  // The function call is not raw syntax.
  assert_eq(nodes.length(), 5)
  assert_eq(elems.length(), 6)
  let dump = []
  let mut i = 0
  for elem in elems {
    match elem.text() {
      Text(text) => dump.push("text \{@library.repr_str(text)}")
      Lines(lines) => {
        let node = nodes[i]
        i += 1
        let expected = node
          .lines()
          .map(line => (line.get(), line.span()))
          .collect()
        assert_eq(lines.length(), expected.length())
        for j in 0..<lines.length() {
          assert_eq(lines[j].0, expected[j].0)
          assert_true(lines[j].1 == expected[j].1)
          // A span of the line's own, inside the literal.
          assert_true(!lines[j].1.is_detached())
          assert_true(lines[j].1 != node.span())
        }
        // The element has the span of the literal.
        assert_true(elem.pack().span() == node.span())
        assert_eq(elem.block_local(), Some(node.block()))
        assert_eq(
          elem.lang_local().map(lang => lang),
          node.lang().map(lang => Some(lang.get())),
        )
        dump.push(
          "lines [\{lines.map(line => @library.repr_str(line.0)).join(", ")}]",
        )
      }
    }
  }
  inspect(
    dump.join("\n"),
    content=(
      #|lines ["a"]
      #|lines ["x = 1", "  y"]
      #|lines []
      #|lines [""]
      #|text "a\nb"
      #|lines ["c"]
    ),
  )
}

///|
test "raw content: lines and text are equal by text, lines by line" {
  // Upstream `PartialEq for RawContent`.
  let span = @syntax.Span::detached()
  let lines = (lines : Array[String]) => {
    @library.RawContent::Lines(lines.map(line => (line, span)))
  }
  let text = (text : String) => @library.RawContent::Text(text)
  assert_true(lines([]) == text(""))
  assert_true(lines([""]) == text(""))
  assert_true(text("") == lines([""]))
  assert_true(lines([]) != lines([""]))
  assert_true(lines(["a", "b"]) == text("a\nb"))
  assert_true(lines(["a", "b"]) == lines(["a", "b"]))
  assert_true(lines(["a", "b"]) != lines(["a\nb"]))
  assert_true(lines(["a\nb"]) == text("a\nb"))
  assert_true(text("a") != text("b"))
  // `get`: the lines joined by line feeds.
  assert_eq(lines([]).get(), "")
  assert_eq(lines(["a"]).get(), "a")
  assert_eq(lines(["a", "", "b"]).get(), "a\n\nb")
  assert_eq(text("a\r\nb").get(), "a\r\nb")
}

///|
test "raw content: the stored lines are no Typst value" {
  // The field stores the lines; every way a document reads the field gives
  // the string (upstream `RawContent`'s `IntoValue`).
  let source = @syntax.Source::detached("```\na\nb\n```")
  let elem = raw_elems(source)[0].pack()
  assert_true(
    elem.field_raw(@library.raw_elem_text) is Some(Dyn(RawContent(Lines(_)))),
  )
  assert_true(elem.get(@library.raw_elem_text) is Str("a\nb"))
  assert_true(elem.get_by_name("text") is Str("a\nb"))
  assert_true(elem.fields().map.get("text") is Some(Str("a\nb")))
  inspect(elem.repr(), content="raw(text: \"a\\nb\", block: true)")
  inspect(elem.plain_text(), content="a\nb")
  // Element equality is the equality of raw content.
  let by_function = @library.RawElem::new(Text("a\nb")).with_block(true).pack()
  assert_true(elem == by_function)
  assert_true(by_function == elem)
  assert_true(
    elem != @library.RawElem::new(Text("a b")).with_block(true).pack(),
  )
}

///|
test "raw content: the hash covers the lines and their spans" {
  // Upstream `#[derive(Hash)]` of `RawContent` (and so the keys of
  // locations and the memoization of layout): equal raw contents can
  // differ in their hash.
  let source = @syntax.Source::detached("```\n```\n```\n\n```")
  let elems = raw_elems(source)
  // No lines and one empty line: the same text, different content.
  assert_eq(elems[0].text().get(), elems[1].text().get())
  assert_true(elems[0].pack() != elems[1].pack())
  guard elems[1].text() is Lines([(_, span)]) else { fail("expected a line") }
  let key = (text : @library.RawContent) => {
    @library.hash128(@library.RawElem::new(text).pack())
  }
  assert_true(key(Lines([])) != key(Lines([("", span)])))
  assert_true(key(Lines([])) != key(Text("")))
  assert_true(key(Lines([("", span)])) != key(Text("")))
  assert_true(
    key(Lines([("", span)])) != key(Lines([("", @syntax.Span::detached())])),
  )
  assert_true(key(Lines([("", span)])) == key(Lines([("", span)])))
  assert_true(key(Text("a")) == key(Text("a")))
}

///|
/// The syntax nodes of the string literals of a source, in order.
fn str_nodes(
  node : @syntax.SyntaxNode,
  out : Array[@syntax.SyntaxNode],
) -> Unit {
  if node.kind() == Str {
    out.push(node)
  }
  for child in node.children() {
    str_nodes(child, out)
  }
}

///|
test "raw in an evaluated string: the lines have the span of the string" {
  // Upstream `eval` passes `SpanMode::Uniform` with the span of its source
  // argument: every node of the parsed string gets that span
  // (`root.synthesize(span)`), so the evaluator's lines carry it. (The
  // lines used to be looked up in the source by the element's span, which
  // finds the string literal, not raw syntax.)
  let source = @syntax.Source::detached(
    "#eval(\"```\\na\\nb\\n```\", mode: \"markup\")#eval(\"``\", mode: \"markup\")",
  )
  let strings = []
  str_nodes(source.root(), strings)
  let elems = raw_elems(source)
  // The sources and the modes.
  assert_eq(strings.length(), 4)
  assert_eq(elems.length(), 2)
  guard elems[0].text() is Lines([("a", first), ("b", second)]) else {
    fail("expected two lines")
  }
  assert_true(first == strings[0].span())
  assert_true(second == strings[0].span())
  assert_true(elems[0].pack().span() == strings[0].span())
  guard elems[1].text() is Lines([]) else { fail("expected no lines") }
  assert_true(elems[1].pack().span() == strings[2].span())
}

///|
/// The synthesized lines of the raw elements of a compiled document: per
/// element its span and the text and span of each line.
fn synthesized_lines(
  source : String,
) -> Array[(@syntax.Span, Array[(String, @syntax.Span)])] raise {
  let doc = oracle_compile(source)
  let out = []
  for elem in doc.introspector().query(Elem(@library.raw_elem(), None)) {
    guard @library.RawElem::of(elem) is Some(raw) && raw.lines() is Some(lines) else {
      fail("a raw element without lines")
    }
    out.push(
      (elem.span(), lines.map(line => (line.text(), line.pack().span()))),
    )
  }
  out
}

///|
test "raw lines: the spans of the syntax, or of the element after tabs" {
  // Upstream `preprocess`: lines without a tab are used as they are, with
  // their spans; otherwise the text is joined, its tabs are aligned and it
  // is split again, and every line gets the span of the element. A string
  // (`raw(..)`) is always split, with the span of the element.
  let found = synthesized_lines(
    "```\na\n b\n```\n```\na\n\tb\n```\n#raw(\"a\\n b\")",
  )
  assert_eq(found.length(), 3)
  let (elem, lines) = found[0]
  assert_eq(lines.map(line => line.0), ["a", " b"])
  assert_true(lines[0].1 != elem && lines[1].1 != elem)
  assert_true(lines[0].1 != lines[1].1)
  assert_true(!lines[0].1.is_detached() && !lines[1].1.is_detached())
  let (elem, lines) = found[1]
  assert_eq(lines.map(line => line.0), ["a", "  b"])
  assert_true(lines[0].1 == elem && lines[1].1 == elem)
  let (elem, lines) = found[2]
  assert_eq(lines.map(line => line.0), ["a", " b"])
  assert_true(lines[0].1 == elem && lines[1].1 == elem)
}
