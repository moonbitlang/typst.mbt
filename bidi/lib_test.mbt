// Tests ported from `unicode-bidi 0.3.18` (`lib.rs`). The Unicode
// conformance files are covered by the runner's `break` stage.

///|
fn reorder_paras(text : String) -> Array[String] {
  let bidi_info = @bidi.BidiInfo::new(text, None)
  bidi_info.paragraphs.map(para => bidi_info.reorder_line(para, para.range))
}

///|
test "reorder_line" {
  let tests : Array[(String, Array[String])] = [
    // Bidi_Class: L L L B L L L B L L L
    ("abc\ndef\nghi", ["abc\n", "def\n", "ghi"]),
    // Bidi_Class: L L EN B L L EN B L L EN
    ("ab1\nde2\ngh3", ["ab1\n", "de2\n", "gh3"]),
    // Bidi_Class: L L L B AL AL AL
    ("abc\nابج", ["abc\n", "جبا"]),
    // Bidi_Class: AL AL AL B L L L
    ("\u{0627}\u{0628}\u{062C}\nabc", ["\n\u{062C}\u{0628}\u{0627}", "abc"]),
    ("1.-2", ["1.-2"]),
    ("1-.2", ["1-.2"]),
    ("abc אבג", ["abc גבא"]),
    // Numbers being weak LTR characters, cannot reorder strong RTL
    ("123 \u{05D0}\u{05D1}\u{05D2}", ["גבא 123"]),
    ("abc\u{202A}def", ["abc\u{202A}def"]),
    ("abc\u{202A}def\u{202C}ghi", ["abc\u{202A}def\u{202C}ghi"]),
    ("abc\u{2066}def\u{2069}ghi", ["abc\u{2066}def\u{2069}ghi"]),
    // Testing for RLE Character
    ("\u{202B}abc אבג\u{202C}", ["\u{202b}גבא abc\u{202c}"]),
    // Testing neutral characters
    ("\u{05D0}בג? אבג", ["גבא ?גבא"]),
    // Testing neutral characters with special case
    ("A אבג?", ["A גבא?"]),
    // Testing neutral characters with Implicit RTL Marker
    ("A אבג?\u{200F}", ["A \u{200F}?גבא"]),
    ("\u{05D0}בג abc", ["abc גבא"]),
    ("abc\u{2067}.-\u{2069}ghi", ["abc\u{2067}-.\u{2069}ghi"]),
    (
      "Hello, \u{2068}\u{202E}world\u{202C}\u{2069}!",
      ["Hello, \u{2068}\u{202E}\u{202C}dlrow\u{2069}!"],
    ),
    // With mirrorable characters in RTL run
    ("\u{05D0}(ב)ג.", [".ג)ב(א"]),
    // With mirrorable characters on level boundary
    ("\u{05D0}ב(גד[&ef].)gh", ["gh).]ef&[דג(בא"]),
  ]
  for t in tests {
    assert_eq(reorder_paras(t.0), t.1)
  }
}

///|
fn levels(v : Array[Int]) -> Array[@bidi.Level] {
  @bidi.Level::vec(v)
}

///|
test "reordered_levels" {
  // BidiTest:946 (LRI PDI)
  let info = @bidi.BidiInfo::new("\u{2067}\u{2069}", None)
  let para = info.paragraphs[0]
  assert_eq(info.reordered_levels(para, para.range), levels([0, 0, 0, 0, 0, 0]))
  assert_eq(info.reordered_levels_per_char(para, para.range), levels([0, 0]))
  // BidiTest:69635 (AL ET EN)
  let info = @bidi.BidiInfo::new("\u{060B}\u{20CF}\u{06F9}", None)
  let para = info.paragraphs[0]
  assert_eq(
    info.reordered_levels(para, para.range),
    levels([1, 1, 1, 1, 1, 2, 2]),
  )
  assert_eq(info.reordered_levels_per_char(para, para.range), levels([1, 1, 2]))
  let info = @bidi.BidiInfo::new("aa טֶ", None)
  assert_eq(
    info.reordered_levels(info.paragraphs[0], { start: 3, end: 7, }),
    levels([0, 0, 0, 1, 1, 1, 1]),
  )
}

///|
test "reorder_visual" {
  let l0 = @bidi.Level(0)
  let l1 = @bidi.Level(1)
  let l2 = @bidi.Level(2)
  assert_eq(@bidi.BidiInfo::reorder_visual([l0, l0, l0, l0][:]), [0, 1, 2, 3])
  assert_eq(
    @bidi.BidiInfo::reorder_visual([l0, l0, l0, l1, l1, l1, l2, l2][:]),
    [0, 1, 2, 6, 7, 5, 4, 3],
  )
}

///|
test "get_base_direction" {
  assert_eq(@bidi.get_base_direction("abc"), Ltr)
  assert_eq(@bidi.get_base_direction("\u{05D0}bc"), Rtl)
  assert_eq(@bidi.get_base_direction("123"), Mixed)
  assert_eq(@bidi.get_base_direction("\u{2067}abc\u{2069}\u{05D0}"), Rtl)
  assert_eq(@bidi.get_base_direction("123\u{2029}abc"), Mixed)
  assert_eq(@bidi.get_base_direction_full("123\u{2029}abc"), Ltr)
}
