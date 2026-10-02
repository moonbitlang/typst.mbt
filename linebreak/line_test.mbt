// Tests ported from `icu_segmenter 2.3.0` (`line.rs`).

///|
fn check_line(
  s : String,
  expected : Array[String],
  seg : @linebreak.LineSegmenter,
) -> Unit raise {
  let breaks = seg.segment_str(s)
  let bytes = @utf8.encode(s)
  let actual = []
  for k in 1..<breaks.length() {
    actual.push(@utf8.decode(bytes[breaks[k - 1]:breaks[k]]))
  }
  assert_eq(actual, expected)
}

///|
test "linebreak" {
  let segmenter = @linebreak.LineSegmenter::new_lstm(
    @linebreak.LineBreakOptions::default(),
  )
  check_line("hello world", ["hello ", "world"], segmenter)
  check_line("$10 $10", ["$10 ", "$10"], segmenter)
  // LB14
  check_line("[  abc def", ["[  abc ", "def"], segmenter)
  // LB15 used to prevent the break at 6, but has been removed in Unicode 15.1.
  check_line("abc\u{0022}  (def", ["abc\u{0022}  ", "(def"], segmenter)
  // Instead, in Unicode 15.1, LB15a and LB15b prevent these breaks.
  check_line("« miaou »", ["« miaou »"], segmenter)
  // But not these:
  check_line(
    "Die Katze hat »miau« gesagt.",
    ["Die ", "Katze ", "hat ", "»miau« ", "gesagt."],
    segmenter,
  )
  // LB16
  check_line("\u{0029}\u{203C}", ["\u{0029}\u{203C}"], segmenter)
  check_line("\u{0029}  \u{203C}", ["\u{0029}  \u{203C}"], segmenter)
  // LB17
  check_line("\u{2014}\u{2014}aa", ["\u{2014}\u{2014}", "aa"], segmenter)
  check_line("\u{2014}  \u{2014}aa", ["\u{2014}  \u{2014}", "aa"], segmenter)
  check_line(
    "\u{2014}\u{2014}  \u{2014}\u{2014}123 abc",
    ["\u{2014}\u{2014}  \u{2014}\u{2014}", "123 ", "abc"],
    segmenter,
  )
  // LB25
  check_line("(0,1)+(2,3)", ["(0,1)+(2,3)"], segmenter)
  check_line(
    "——  ——123 abc",
    ["——  ——", "123 ", "abc"],
    segmenter,
  )
  check_line("\u{1F3FB} \u{1F3FB}", ["\u{1F3FB} ", "\u{1F3FB}"], segmenter)
}

///|
test "complex scripts (lstm)" {
  let segmenter = @linebreak.LineSegmenter::new_lstm(
    @linebreak.LineBreakOptions::default(),
  )
  check_line(
    "ภาษาไทยภาษาไทย",
    ["ภาษา", "ไทย", "ภาษา", "ไทย"],
    segmenter,
  )
  check_line("ภาษา", ["ภาษา"], segmenter)
  check_line(
    "မြန်မာဘာသာစကား",
    ["မြန်", "မာ", "ဘာသာ", "စကား"],
    segmenter,
  )
  check_line(
    "សេចក្ដីប្រកាសជាសកលស្ដីពីសិទ្ធិមនុស្ស",
    [
      "សេចក្ដីប្រកាស", "ជាស", "កល", "ស្ដីពី",
      "សិទ្ធិមនុស្ស",
    ],
    segmenter,
  )
  check_line(
    "ກ່ຽວກັບສິດຂອງມະນຸດ",
    ["ກ່ຽວ", "ກັບ", "ສິດ", "ຂອງ", "ມະນຸດ"],
    segmenter,
  )
}

///|
test "empty string" {
  let segmenter = @linebreak.LineSegmenter::new_for_non_complex_scripts(
    @linebreak.LineBreakOptions::default(),
  )
  assert_eq(segmenter.segment_str(""), [0])
}

///|
test "hello world doc example" {
  let segmenter = @linebreak.LineSegmenter::new_lstm(
    @linebreak.LineBreakOptions::default(),
  )
  assert_eq(segmenter.segment_str("Summary\r\nThis annex…"), [0, 9, 14, 22])
  assert_eq(segmenter.segment_str("Hello World"), [0, 6, 11])
}
