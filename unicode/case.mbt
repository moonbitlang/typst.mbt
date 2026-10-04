// Case conversion equivalent to Rust's `str::to_lowercase` and
// `str::to_uppercase`, backed by `text_tables_gen.mbt`.

///|
/// Binary search a `[c, mapped, ...]` table.
fn lookup_single(table : ReadOnlyArray[Int], c : Int) -> Int? {
  let n = table.length() / 2
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    let k = table[2 * mid]
    if c < k {
      continue lo, mid
    } else if c > k {
      continue mid + 1, hi
    } else {
      break Some(table[2 * mid + 1])
    }
  } nobreak {
    None
  }
}

///|
/// Look up a `[c, len, chars..., ...]` table (linear; the tables are small).
/// Returns the start and length of the mapping.
fn lookup_multi(table : ReadOnlyArray[Int], c : Int) -> (Int, Int)? {
  let mut i = 0
  while i < table.length() {
    let len = table[i + 1]
    if table[i] == c {
      return Some((i + 2, len))
    }
    i += 2 + len
  }
  None
}

///|
fn write_mapped(
  buf : StringBuilder,
  c : Int,
  single : ReadOnlyArray[Int],
  multi : ReadOnlyArray[Int],
) -> Unit {
  match lookup_single(single, c) {
    Some(m) => buf.write_char(m.unsafe_to_char())
    None =>
      match lookup_multi(multi, c) {
        Some((start, len)) =>
          for j in start..<(start + len) {
            buf.write_char(multi[j].unsafe_to_char())
          }
        None => buf.write_char(c.unsafe_to_char())
      }
  }
}

///|
/// Unicode `Cased`.
fn is_cased(c : Int) -> Bool {
  in_ranges(cased_table, c)
}

///|
/// Unicode `Case_Ignorable`.
fn is_case_ignorable(c : Int) -> Bool {
  in_ranges(case_ignorable_table, c)
}

///|
/// Rust's `char::to_lowercase`, as chars.
pub fn char_to_lowercase(c : Char) -> String {
  let buf = StringBuilder()
  write_mapped(buf, c.to_int(), to_lowercase_table, to_lowercase_multi_table)
  buf.to_string()
}

///|
/// Rust's `char::to_uppercase`, as chars.
pub fn char_to_uppercase(c : Char) -> String {
  let buf = StringBuilder()
  write_mapped(buf, c.to_int(), to_uppercase_table, to_uppercase_multi_table)
  buf.to_string()
}

///|
/// Rust's `str::to_lowercase` (including the contextual mapping of `Σ` to
/// `ς` at the end of a word).
pub fn to_lowercase(s : StringView) -> String {
  let chars : Array[Int] = []
  let mut i = 0
  while i < s.length() {
    let (c, next) = decode_at(s, i)
    chars.push(c)
    i = next
  }
  let buf = StringBuilder()
  for i, c in chars {
    if c == 0x3A3 {
      // See https://www.unicode.org/versions/Unicode7.0.0/ch03.pdf#G33992
      // for the definition of `Final_Sigma`.
      let before = case_ignorable_then_cased(chars, i - 1, -1)
      let after = case_ignorable_then_cased(chars, i + 1, 1)
      buf.write_char(if before && !after { 'ς' } else { 'σ' })
    } else {
      write_mapped(buf, c, to_lowercase_table, to_lowercase_multi_table)
    }
  }
  buf.to_string()
}

///|
/// Whether, skipping case-ignorable chars from `start` in direction `step`,
/// the first other char is cased.
fn case_ignorable_then_cased(
  chars : Array[Int],
  start : Int,
  step : Int,
) -> Bool {
  for i = start; i >= 0 && i < chars.length(); i = i + step {
    if !is_case_ignorable(chars[i]) {
      return is_cased(chars[i])
    }
  }
  false
}

///|
/// Rust's `str::to_uppercase`.
pub fn to_uppercase(s : StringView) -> String {
  let buf = StringBuilder()
  let mut i = 0
  while i < s.length() {
    let (c, next) = decode_at(s, i)
    write_mapped(buf, c, to_uppercase_table, to_uppercase_multi_table)
    i = next
  }
  buf.to_string()
}
