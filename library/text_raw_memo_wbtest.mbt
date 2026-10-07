// The highlighted lines of raw text kept by content (`RawElem::highlight`,
// `memo_content.mbt`): which arguments are one entry and which are not.
// What documents observe is in `typst/highlight_memo_wbtest.mbt`.

///|
/// A theme that colours keywords.
fn raw_test_theme(keyword : String) -> Bytes {
  @utf8.encode(
    (
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<plist version="1.0"><dict>
      #|<key>name</key><string>Test</string>
      #|<key>settings</key><array>
      #|<dict><key>settings</key><dict>
      #|<key>foreground</key><string>#000000</string>
      #|</dict></dict>
      #|<dict><key>scope</key><string>keyword</string>
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
fn raw_test_syntax(word : String) -> Bytes {
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
/// A piece of a highlighted line: its text, after the values of the styles
/// around it (the fill, the offset in its span).
fn raw_test_piece(content : Content, out : StringBuilder) -> Unit {
  if content.is_(styled_elem()) {
    out.write_char('<')
    for style in StyledElem::styles(content).items {
      if style is Property(property) {
        out.write_string(property.value.repr())
        out.write_char(' ')
      }
    }
    raw_test_piece(StyledElem::child(content), out)
    out.write_char('>')
  } else if content.to_sequence() is Some(children) {
    for child in children {
      raw_test_piece(child, out)
    }
  } else if content.is_(text_elem()) {
    out.write_string(content.plain_text())
  } else {
    // What a routine or a font style wrapped.
    out.write_string(content.elem().name())
    out.write_char('(')
    content.traverse(inner => {
      if !physical_equal(inner, content) && inner.is_(text_elem()) {
        out.write_string(inner.plain_text())
      }
      true
    })
    |> ignore
    out.write_char(')')
  }
}

///|
/// What highlighting gave: the lines with their pieces.
fn raw_test_dump(lines : Array[RawLine]) -> String {
  let out = StringBuilder()
  for line in lines {
    out.write_string("\{line.text()}: ")
    raw_test_piece(line.body(), out)
    out.write_char('\n')
  }
  out.to_string()
}

///|
/// Highlights with the cache and without it, checks that both give the same,
/// and returns the lines of the cache.
fn raw_test_highlight(
  elem : RawElem,
  engine : Engine,
  styles : StyleChain,
) -> Array[RawLine] raise {
  let lines = elem.highlight(engine, styles)
  set_layout_memo_enabled(false)
  let plain = elem.highlight(engine, styles)
  set_layout_memo_enabled(true)
  assert_eq(raw_test_dump(lines), raw_test_dump(plain))
  assert_eq(lines.length(), plain.length())
  for i in 0..<lines.length() {
    // Spans and the rest of what a line is.
    assert_true(hash128(lines[i].0) == hash128(plain[i].0))
  }
  lines
}

///|
/// A raw element with a theme given as bytes, as the field's parser stores
/// it: the source in the field, the decoded theme in its companion.
fn raw_test_with_theme(elem : RawElem, theme : Bytes) -> RawElem raise {
  let decoded = RawTheme::decode(theme) catch { _ => fail("invalid theme") }
  RawElem(
    elem.with_theme(Custom(Some(Bytes(theme)))).0.with_field(
      raw_elem_theme_derived,
      Dyn(RawTheme(decoded)),
    ),
  )
}

///|
fn raw_test_reset() -> Unit {
  set_layout_memo_enabled(true)
  raw_highlight_cache.evict(0)
}

///|
test "highlight: equal elements and styles are highlighted once" {
  raw_test_reset()
  let engine = memo_engine()
  let styles = StyleChain::empty()
  let elem = RawElem::new(Text("let x = 1;\nfn main() {}")).with_lang(
    Some("rust"),
  )
  let first = raw_test_highlight(elem, engine, styles)
  assert_eq(raw_highlight_cache.length(), 1)
  let again = elem.highlight(engine, styles)
  assert_eq(raw_highlight_cache.length(), 1)
  // The same lines (immutable content, shared like upstream's `Arc`s) in an
  // array of the caller's own.
  assert_eq(first.length(), 2)
  assert_false(physical_equal(first, again))
  for i in 0..<first.length() {
    assert_true(physical_equal(first[i].0, again[i].0))
  }
  again.clear()
  assert_eq(elem.highlight(engine, styles).length(), 2)
  // An equal element that is another object, in equal styles that are
  // another chain.
  let twin = RawElem::new(Text("let x = 1;\nfn main() {}")).with_lang(
    Some("rust"),
  )
  let styles2 = StyleChain::empty().chain(Styles::from_array([]))
  let styles3 = StyleChain::empty().chain(Styles::from_array([]))
  let a = twin.highlight(engine, styles2)
  let entries = raw_highlight_cache.length()
  let b = elem.highlight(engine, styles3)
  assert_eq(raw_highlight_cache.length(), entries)
  assert_true(physical_equal(a[0].0, b[0].0))
  // With memoization off nothing is found or kept.
  set_layout_memo_enabled(false)
  let plain = elem.highlight(engine, styles)
  set_layout_memo_enabled(true)
  assert_false(physical_equal(plain[0].0, first[0].0))
  assert_eq(raw_highlight_cache.length(), entries)
}

///|
test "highlight: language, text, tab size, theme and syntaxes are in the key" {
  raw_test_reset()
  let engine = memo_engine()
  let styles = StyleChain::empty()
  let text = "let x = 1;\n\tfoo bar"
  let dumps : Array[String] = []
  let distinct = (lines : Array[RawLine]) => {
    let dump = raw_test_dump(lines)
    if dumps.contains(dump) {
      fail("highlighted like another: \{dump}")
    }
    dumps.push(dump)
  }
  // The language, in the element and in the styles.
  let rust = RawElem::new(Text(text)).with_lang(Some("rust"))
  let python = RawElem::new(Text(text)).with_lang(Some("py"))
  let plain = RawElem::new(Text(text))
  distinct(raw_test_highlight(rust, engine, styles))
  distinct(raw_test_highlight(python, engine, styles))
  distinct(raw_test_highlight(plain, engine, styles))
  assert_eq(raw_highlight_cache.length(), 3)
  let js = styles.chain(Styles::from_array([RawElem::set_lang(Some("js"))]))
  distinct(raw_test_highlight(plain, engine, js))
  assert_eq(raw_highlight_cache.length(), 4)
  // The text.
  distinct(
    raw_test_highlight(
      RawElem::new(Text("let y = 1;\n\tfoo bar")).with_lang(Some("rust")),
      engine,
      styles,
    ),
  )
  // The tab size, from the styles.
  let tab8 = styles.chain(Styles::from_array([RawElem::set_tab_size(USize(8))]))
  distinct(raw_test_highlight(rust, engine, tab8))
  assert_eq(raw_highlight_cache.length(), 6)
  // The theme: none (the lines as they are, like those of text without a
  // language), one, another.
  let red = raw_test_theme("#ff0000")
  let blue = raw_test_theme("#0000ff")
  assert_eq(
    raw_test_dump(
      raw_test_highlight(rust.with_theme(Custom(None)), engine, styles),
    ),
    dumps[2],
  )
  distinct(raw_test_highlight(raw_test_with_theme(rust, red), engine, styles))
  distinct(raw_test_highlight(raw_test_with_theme(rust, blue), engine, styles))
  assert_eq(raw_highlight_cache.length(), 9)
  // The syntaxes: the language `foo` is unknown without one.
  let foo = RawElem::new(Text(text)).with_lang(Some("foo"))
  let unknown = raw_test_dump(raw_test_highlight(foo, engine, styles))
  assert_eq(unknown, raw_test_dump(plain.highlight(engine, styles)))
  let with_syntax = (word : String) => {
    let bytes = raw_test_syntax(word)
    let syntax = RawSyntax::decode(bytes) catch { _ => fail("invalid syntax") }
    RawElem(
      raw_test_with_theme(foo, red).with_syntaxes(OneOrMultiple([Bytes(bytes)])).0.with_field(
        raw_elem_syntaxes_derived,
        raw_syntaxes_value([syntax]),
      ),
    )
  }
  distinct(raw_test_highlight(with_syntax("foo"), engine, styles))
  distinct(raw_test_highlight(with_syntax("bar"), engine, styles))
  // Each was computed once.
  let entries = raw_highlight_cache.length()
  ignore(with_syntax("foo").highlight(engine, styles))
  ignore(raw_test_with_theme(rust, blue).highlight(engine, styles))
  ignore(rust.highlight(engine, tab8))
  assert_eq(raw_highlight_cache.length(), entries)
}

///|
test "highlight: the same path with another theme behind it" {
  raw_test_reset()
  let engine = memo_engine()
  let styles = StyleChain::empty()
  // The source is a path, which is all the field says: the decoded theme in
  // the companion field tells two files apart (two directories with a
  // `theme.tmTheme` each, or one file before and after it changed).
  let source = DataSource::Path(Str("theme.tmTheme"))
  let with_file = (bytes : Bytes) => {
    let decoded = RawTheme::decode(bytes) catch { _ => fail("invalid theme") }
    RawElem(
      RawElem::new(Text("let x = 1;"))
      .with_lang(Some("rust"))
      .with_theme(Custom(Some(source))).0.with_field(
        raw_elem_theme_derived,
        Dyn(RawTheme(decoded)),
      ),
    )
  }
  let red = with_file(raw_test_theme("#ff0000"))
  let blue = with_file(raw_test_theme("#0000ff"))
  assert_true(red.0 == blue.0)
  assert_false(hash128(red.0) == hash128(blue.0))
  let a = raw_test_dump(raw_test_highlight(red, engine, styles))
  let b = raw_test_dump(raw_test_highlight(blue, engine, styles))
  assert_true(a.contains("ff0000") && !a.contains("0000ff"))
  assert_true(b.contains("0000ff") && !b.contains("ff0000"))
  assert_eq(raw_highlight_cache.length(), 2)
  // The same in the styles (a set rule stores the two as two properties).
  let set = (bytes : Bytes) => {
    let decoded = RawTheme::decode(bytes) catch { _ => fail("invalid theme") }
    styles.chain(
      Styles::from_array([
        RawElem::set_theme(Custom(Some(source))),
        Property(
          Property::new(
            raw_elem(),
            raw_elem_theme_derived,
            Dyn(RawTheme(decoded)),
          ),
        ),
      ]),
    )
  }
  let elem = RawElem::new(Text("let x = 1;")).with_lang(Some("rust"))
  let c = raw_test_dump(
    raw_test_highlight(elem, engine, set(raw_test_theme("#ff0000"))),
  )
  let d = raw_test_dump(
    raw_test_highlight(elem, engine, set(raw_test_theme("#0000ff"))),
  )
  assert_eq(c, a)
  assert_eq(d, b)
  assert_eq(raw_highlight_cache.length(), 4)
  // The same bytes decoded again (after `evict`) are the same theme.
  raw_theme_cache.clear()
  ignore(with_file(raw_test_theme("#ff0000")).highlight(engine, styles))
  assert_eq(raw_highlight_cache.length(), 4)
}

///|
test "highlight: folded syntaxes, and derived data that is missing" {
  raw_test_reset()
  let engine = memo_engine()
  let foo = raw_test_syntax("foo")
  let bar = raw_test_syntax("bar")
  let decode = (bytes : Bytes) => {
    RawSyntax::decode(bytes) catch {
      _ => fail("invalid syntax")
    }
  }
  let property = (bytes : Bytes) => {
    Styles::from_array([
      RawElem::set_syntaxes(OneOrMultiple([Bytes(bytes)])),
      Property(
        Property::new(
          raw_elem(),
          raw_elem_syntaxes_derived,
          raw_syntaxes_value([decode(bytes)]),
        ),
      ),
    ])
  }
  // Two set rules: the sources fold to both, outer first, and so do the
  // syntaxes.
  let styles = StyleChain::empty().chain(property(foo)).chain(property(bar))
  let elem = raw_test_with_theme(
    RawElem::new(Text("foo bar")).with_lang(Some("foo")),
    raw_test_theme("#ff0000"),
  )
  let read_world = Ref(false)
  let derived = elem.derived_syntaxes(engine, styles, read_world)
  assert_false(read_world.val)
  assert_eq(derived.length(), 2)
  assert_true(derived[0] == decode(foo) && derived[1] == decode(bar))
  assert_true(elem.syntaxes(styles).0 == [Bytes(foo), Bytes(bar)])
  // Both define the language: the outer one wins, in which `foo` is the
  // keyword.
  let dump = raw_test_dump(raw_test_highlight(elem, engine, styles))
  inspect(dump, content="foo bar: <rgb(\"#ff0000\") foo><3  bar>\n")
  assert_eq(raw_highlight_cache.length(), 1)
  // Sources without their syntaxes (a property that no parser made): they
  // are loaded from the world, and what the world gave is not kept.
  let bare = StyleChain::empty().chain(
    Styles::from_array([RawElem::set_syntaxes(OneOrMultiple([Bytes(foo)]))]),
  )
  let read_world = Ref(false)
  assert_eq(elem.derived_syntaxes(engine, bare, read_world).length(), 1)
  assert_true(read_world.val)
  assert_eq(raw_test_dump(raw_test_highlight(elem, engine, bare)), dump)
  assert_eq(raw_highlight_cache.length(), 1)
  // The same for a theme without its decoded form.
  let bare_theme = RawElem::new(Text("let x = 1;"))
    .with_lang(Some("rust"))
    .with_theme(Custom(Some(Bytes(raw_test_theme("#00ff00")))))
  let lines = raw_test_highlight(bare_theme, engine, StyleChain::empty())
  assert_true(raw_test_dump(lines).contains("00ff00"))
  assert_eq(raw_highlight_cache.length(), 1)
}

///|
test "highlight: the styles around the text and the routines" {
  raw_test_reset()
  let engine = memo_engine()
  let elem = RawElem::new(Text("let x = 1;")).with_lang(Some("rust"))
  let styles = StyleChain::empty()
  let size = (pt : Double) => {
    styles.chain(
      Styles::from_array([
        TextElem::set_size(TextSize(Length::from_abs(Abs::pt(pt)))),
      ]),
    )
  }
  // Highlighting does not read the text size, but the styles are an
  // argument: an entry each, as for upstream.
  let small = raw_test_highlight(elem, engine, size(8.0))
  let large = raw_test_highlight(elem, engine, size(12.0))
  assert_eq(raw_test_dump(small), raw_test_dump(large))
  assert_false(physical_equal(small[0].0, large[0].0))
  assert_eq(raw_highlight_cache.length(), 2)
  assert_true(
    physical_equal(small[0].0, elem.highlight(engine, size(8.0))[0].0),
  )
  // For HTML the routine `html_span_filled` makes the coloured spans, and a
  // host can bring its own table of routines: a result belongs to the table
  // it was made with.
  let html = styles.chain(Styles::from_array([TargetElem::set_target(Html)]))
  let routines = (marker : String) => {
    Routines::new(
      eval_string=(_, _, _, _, _, _) => None,
      eval_closure=(_, _, _, _, _) => None,
      html_span_filled=(content, _) => {
        Content::sequence([TextElem::packed(marker), content])
      },
    )
  }
  let library_a = Library::builder(routines("MARK-A"), []).build()
  let library_b = Library::builder(routines("MARK-B"), []).build()
  let with_a = { ..engine, library: library_a, }
  let with_b = { ..engine, library: library_b, }
  let a = raw_test_dump(raw_test_highlight(elem, with_a, html))
  let b = raw_test_dump(raw_test_highlight(elem, with_b, html))
  assert_true(a.contains("MARK-A") && !a.contains("MARK-B"))
  assert_true(b.contains("MARK-B") && !b.contains("MARK-A"))
  assert_eq(raw_test_dump(elem.highlight(with_a, html)), a)
  assert_eq(raw_test_dump(elem.highlight(with_b, html)), b)
  // And not the paged one's.
  assert_false(raw_test_dump(elem.highlight(engine, styles)).contains("MARK-A"))
}

///|
test "highlight: evict" {
  raw_test_reset()
  let engine = memo_engine()
  let styles = StyleChain::empty()
  let one = RawElem::new(Text("let x = 1;")).with_lang(Some("rust"))
  let two = RawElem::new(Text("let y = 2;")).with_lang(Some("rust"))
  let first = one.highlight(engine, styles)
  ignore(two.highlight(engine, styles))
  evict(1)
  assert_true(physical_equal(first[0].0, one.highlight(engine, styles)[0].0))
  evict(1)
  // `two` was not asked for since two calls.
  assert_eq(raw_highlight_cache.length(), 1)
  assert_true(physical_equal(first[0].0, one.highlight(engine, styles)[0].0))
  // Highlighted again, it is what it was.
  assert_eq(
    raw_test_dump(two.highlight(engine, styles)),
    raw_test_dump(raw_test_highlight(two, engine, styles)),
  )
  evict(0)
  assert_eq(raw_highlight_cache.length(), 0)
}
