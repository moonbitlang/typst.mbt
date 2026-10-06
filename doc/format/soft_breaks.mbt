///|
/// The zero-width space, U+200B: a place where a line may break, without
/// width and without a hyphen.
const ZERO_WIDTH_SPACE : Char = '\u{200B}'

///|
/// `s` with a zero-width space (U+200B) after each character that occurs in
/// `after`, so that a long word without spaces (a path, an identifier, a
/// URL: inline code in a narrow table cell) can break there:
/// `soft_breaks("a_b/c")` is "a_" U+200B "b/" U+200B "c".
///
/// The inserted characters are part of the text. They are invisible on the
/// page, but they are in what a reader copies out of the PDF and in what a
/// search has to match, so a copied path or command has to be cleaned of
/// them before it is used. Use this for text that is read, not for text
/// that is meant to be copied.
///
/// - None is added at the end of `s`, and none where the next character
///   already is a zero-width space, so applying the function twice gives
///   the same text as applying it once.
/// - Each character of a run gets its own: "a::b" may break after either
///   colon.
/// - `after` is a set of characters (code points; their order and
///   repetitions do not matter). The default is `_ / . : -`. With an empty
///   set `s` is returned as it is. A zero-width space in `after` is
///   ignored.
pub fn soft_breaks(s : String, after? : String = "_/.:-") -> String {
  if after == "" || s == "" {
    return s
  }
  let buf = StringBuilder()
  // A character waits here until the one after it is known.
  let mut pending = false
  for ch in s {
    if pending && ch != ZERO_WIDTH_SPACE {
      buf.write_char(ZERO_WIDTH_SPACE)
    }
    buf.write_char(ch)
    pending = ch != ZERO_WIDTH_SPACE && after.contains_char(ch)
  }
  buf.to_string()
}
