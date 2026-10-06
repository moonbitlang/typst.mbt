///|
/// The text with "|" for each zero-width space, to read the expectations.
fn marked(s : String) -> String {
  s.replace_all(old="\u{200B}", new="|")
}

///|
test "soft_breaks" {
  assert_eq(@format.soft_breaks("a_b/c"), "a_\u{200B}b/\u{200B}c")
  assert_eq(
    marked(@format.soft_breaks("src/session_migrations/v2.rs")),
    "src/|session_|migrations/|v2.|rs",
  )
  assert_eq(
    marked(@format.soft_breaks("std::collections::hash-map")),
    "std:|:|collections:|:|hash-|map",
  )
  assert_eq(
    marked(@format.soft_breaks("https://example.org/a.b")),
    "https:|/|/|example.|org/|a.|b",
  )
  // Not at the end.
  assert_eq(marked(@format.soft_breaks("a.b.")), "a.|b.")
  assert_eq(marked(@format.soft_breaks("...")), ".|.|.")
  assert_eq(marked(@format.soft_breaks("_")), "_")
  assert_eq(@format.soft_breaks(""), "")
  assert_eq(@format.soft_breaks("plain words"), "plain words")
  // Not doubled: an existing zero-width space is kept, none is added.
  assert_eq(@format.soft_breaks("a_\u{200B}b"), "a_\u{200B}b")
  assert_eq(marked(@format.soft_breaks("a_\u{200B}b_c")), "a_|b_|c")
  assert_eq(marked(@format.soft_breaks("a\u{200B}_b")), "a|_|b")
  assert_eq(marked(@format.soft_breaks("a_\u{200B}")), "a_|")
  // Other sets of characters.
  assert_eq(
    marked(@format.soft_breaks("{\"a\":1,\"b\":2}", after=",")),
    "{\"a\":1,|\"b\":2}",
  )
  assert_eq(marked(@format.soft_breaks("a_b/c", after="/")), "a_b/|c")
  assert_eq(@format.soft_breaks("a_b/c", after=""), "a_b/c")
  assert_eq(marked(@format.soft_breaks("a_b/c", after="//__//")), "a_|b/|c")
  // Characters outside of the basic plane, in the text and in the set.
  assert_eq(marked(@format.soft_breaks("😀_😀")), "😀_|😀")
  assert_eq(
    marked(@format.soft_breaks("a😀b→c", after="😀→")),
    "a😀|b→|c",
  )
  assert_eq(
    marked(@format.soft_breaks("路径/文件.名")),
    "路径/|文件.|名",
  )
  // A zero-width space in the set does nothing.
  assert_eq(
    marked(@format.soft_breaks("a\u{200B}b_c", after="\u{200B}_")),
    "a|b_|c",
  )
  assert_eq(
    @format.soft_breaks("a\u{200B}\u{200B}b", after="\u{200B}"),
    "a\u{200B}\u{200B}b",
  )
}

///|
test "soft_breaks: once is enough, and nothing else changes" {
  let alphabet = [
    'a', 'b', '_', '/', '.', ':', '-', ' ', '\u{200B}', '😀', ',',
  ]
  let mut state = 0x9E3779B97F4A7C15UL
  for _ in 0..<2000 {
    let buf = StringBuilder()
    state = state * 6364136223846793005UL + 1442695040888963407UL
    let len = (state >> 40).to_int() % 12
    for _ in 0..<len {
      state = state * 6364136223846793005UL + 1442695040888963407UL
      buf.write_char(alphabet[(state >> 40).to_int() % alphabet.length()])
    }
    let s = buf.to_string()
    let once = @format.soft_breaks(s)
    assert_eq(@format.soft_breaks(once), once)
    // Only zero-width spaces were added.
    assert_eq(
      once.replace_all(old="\u{200B}", new=""),
      s.replace_all(old="\u{200B}", new=""),
    )
    // None at the end that was not there, none next to one that was added.
    assert_eq(once.has_suffix("\u{200B}"), s.has_suffix("\u{200B}"))
    if !s.contains("\u{200B}") {
      assert_true(!once.contains("\u{200B}\u{200B}"))
      // One after each of the characters but the last.
      let chars = s.to_array()
      let mut expected = 0
      for i, ch in chars {
        if i + 1 < chars.length() && "_/.:-".contains_char(ch) {
          expected += 1
        }
      }
      assert_eq(once.char_length() - s.char_length(), expected)
    }
  }
}
