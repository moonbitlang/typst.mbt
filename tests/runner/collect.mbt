// A port of the oracle's minimal test collector (mirrors upstream
// `tests/src/collect.rs` + the first half of `tests/src/notes.rs`).

///|
priv struct TestCase {
  name : String
  attrs : String
  /// Body text with annotation lines removed, every line ending in `\n`.
  body : String
}

///|
fn is_nl(c : Char) -> Bool {
  @syntax.is_newline(c)
}

///|
/// Index of the first newline char at or after `i`, or the length.
fn find_newline(text : String, i : Int) -> Int {
  let mut j = i
  while j < text.length() {
    if is_nl(Int::unsafe_to_char(text.code_unit_at(j).to_int())) {
      return j
    }
    j += 1
  }
  j
}

///|
/// Skip one newline (`\r\n` counts as one) at `i`.
fn eat_newline(text : String, i : Int) -> Int {
  if i >= text.length() {
    return i
  }
  let c = text.code_unit_at(i).to_int()
  if c == '\r' {
    if i + 1 < text.length() && text.code_unit_at(i + 1) == '\n' {
      i + 2
    } else {
      i + 1
    }
  } else if is_nl(Int::unsafe_to_char(c)) {
    i + 1
  } else {
    i
  }
}

///|
fn starts_with_at(text : String, i : Int, prefix : String) -> Bool {
  if i + prefix.length() > text.length() {
    return false
  }
  for k in 0..<prefix.length() {
    if text.code_unit_at(i + k) != prefix.code_unit_at(k) {
      return false
    }
  }
  true
}

///|
fn split_tests(text : String) -> Array[TestCase] {
  let tests = []
  let mut i = 0
  // Skip the preamble.
  while i < text.length() && !starts_with_at(text, i, "---") {
    i = eat_newline(text, find_newline(text, i))
  }
  while starts_with_at(text, i, "---") {
    let after = i + 3
    let header_end = find_newline(text, after)
    let header = text
      .unsafe_substring(start=after, end=header_end)
      .trim(chars=" \t")
      .to_string()
    let (name, attrs) = match header.find(" ") {
      Some(k) =>
        (
          header.unsafe_substring(start=0, end=k),
          header.unsafe_substring(start=k + 1, end=header.length()),
        )
      None => (header, "")
    }
    i = eat_newline(text, header_end)
    let start = i
    while i < text.length() && !starts_with_at(text, i, "---") {
      i = eat_newline(text, find_newline(text, i))
    }
    tests.push({
      name,
      attrs,
      body: strip_notes(text.unsafe_substring(start~, end=i)),
    })
  }
  tests
}

///|
/// Rust's `str::lines`: split on `\n`, strip a trailing `\r`, no final empty
/// line.
fn rust_lines(text : String) -> Array[String] {
  let out = []
  let mut start = 0
  for i in 0..<text.length() {
    if text.code_unit_at(i) == '\n' {
      let mut end = i
      if end > start && text.code_unit_at(end - 1) == '\r' {
        end -= 1
      }
      out.push(text.unsafe_substring(start~, end~))
      start = i + 1
    }
  }
  if start < text.length() {
    let mut end = text.length()
    if end > start && text.code_unit_at(end - 1) == '\r' {
      end -= 1
    }
    out.push(text.unsafe_substring(start~, end~))
  }
  out
}

///|
fn strip_notes(full_body : String) -> String {
  let buf = StringBuilder()
  for line in rust_lines(full_body) {
    let trimmed = line.trim_start(chars=" ")
    let is_note = trimmed.has_prefix("// Error:") ||
      trimmed.has_prefix("// Warning:") ||
      trimmed.has_prefix("// Hint:")
    if !is_note {
      buf.write_string(line)
      buf.write_char('\n')
    }
  }
  buf.to_string()
}
