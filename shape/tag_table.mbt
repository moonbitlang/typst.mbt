// Port of the handwritten helpers of rustybuzz 0.20.1 `src/hb/tag_table.rs`
// (emitted verbatim by HarfBuzz's gen-tag-table.py). The language table
// (`open_type_languages`) and `tags_from_complex_language` are generated into
// `tag_table_gen.mbt` by `scripts/gen_shape_tables.py`.
//
// Languages are byte strings here (one char per UTF-8 byte, see
// `byte_string` in tag.mbt), so indices and lengths are Rust byte offsets.

///|
fn subtag_matches(language : StringView, subtag : StringView) -> Bool {
  // `language.match_indices(subtag)`: non-overlapping matches, left to right.
  let mut start = 0
  while language[start:].find(subtag) is Some(j) {
    let i = start + j
    if byte_at(language, i + subtag.length()) is Some(c) {
      if !is_ascii_alphanumeric(c) {
        return true
      }
    } else {
      return true
    }
    start = i + subtag.length().max(1)
  }
  false
}

///|
fn lang_matches(language : StringView, spec : StringView) -> Bool {
  if language.has_prefix(spec) {
    return language.length() == spec.length() ||
      byte_at(language, spec.length()) == Some('-')
  }
  false
}

///|
fn strncmp(s1 : StringView, s2 : StringView, n : Int) -> Bool {
  let n1 = n.min(s1.length())
  let n2 = n.min(s2.length())
  s1[:n1] == s2[:n2]
}
