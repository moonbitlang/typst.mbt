// Unicode property data for regular expressions (as in regex-syntax's
// `unicode.rs`), backed by `text_tables_gen.mbt`.

///|
/// Convert a flat `[lo0, hi0, lo1, hi1, ...]` table into ranges.
fn table_ranges(table : ReadOnlyArray[Int]) -> Array[(Int, Int)] {
  let out = []
  for i = 0; i + 1 < table.length(); i = i + 2 {
    out.push((table[i], table[i + 1]))
  }
  out
}

///|
/// The ranges of `\w` (regex-syntax `perl_word`).
pub fn perl_word_ranges() -> Array[(Int, Int)] {
  table_ranges(perl_word_table)
}

///|
/// The ranges of `\d` (regex-syntax `perl_digit`, general category Nd).
pub fn perl_digit_ranges() -> Array[(Int, Int)] {
  table_ranges(perl_digit_table)
}

///|
/// The ranges of `\s` (regex-syntax `perl_space`, `White_Space`).
pub fn perl_space_ranges() -> Array[(Int, Int)] {
  table_ranges(perl_space_table)
}

///|
/// Whether `c` is a word character as defined by regex-syntax's
/// `is_word_character` (used for `\b`).
pub fn is_word_character(c : Int) -> Bool {
  if c < 0x80 {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_'
  } else {
    in_ranges(perl_word_table, c)
  }
}

///|
/// Lexicographic comparison of ASCII strings (Rust `str` ordering).
fn lex_compare(a : String, b : String) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let o = a.code_unit_at(i).compare(b.code_unit_at(i))
    if o != 0 {
      return o
    }
  }
  a.length().compare(b.length())
}

///|
/// Binary search a sorted `[key, value, key, value, ...]` table.
fn lookup_pairs(table : ReadOnlyArray[String], key : String) -> String? {
  let n = table.length() / 2
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    let o = lex_compare(key, table[2 * mid])
    if o < 0 {
      continue lo, mid
    } else if o > 0 {
      continue mid + 1, hi
    } else {
      break Some(table[2 * mid + 1])
    }
  } nobreak {
    None
  }
}

///|
/// The canonical property name for a normalized property name (regex-syntax
/// `canonical_prop`).
pub fn canonical_property_name(normalized : String) -> String? {
  lookup_pairs(property_name_pairs, normalized)
}

///|
/// The canonical general category for a normalized value (regex-syntax
/// `property_values("General_Category")`).
pub fn canonical_general_category(normalized : String) -> String? {
  lookup_pairs(gc_alias_pairs, normalized)
}

///|
/// The canonical script for a normalized value (regex-syntax
/// `property_values("Script")`).
pub fn canonical_script(normalized : String) -> String? {
  lookup_pairs(script_alias_pairs, normalized)
}

///|
/// Merge sorted ranges that touch.
fn merge_ranges(ranges : Array[(Int, Int)]) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  for r in ranges {
    match out.last() {
      Some((a, b)) if b + 1 >= r.0 =>
        out[out.length() - 1] = (a, if r.1 > b { r.1 } else { b })
      _ => out.push(r)
    }
  }
  out
}

///|
/// The ranges of a valued table whose value satisfies `pred`; chars missing
/// from the table have value `default`.
fn valued_ranges(
  table : ReadOnlyArray[Int],
  default : Int,
  pred : (Int) -> Bool,
) -> Array[(Int, Int)] {
  let out = []
  let mut next = 0
  for i = 0; i + 2 < table.length(); i = i + 3 {
    let (lo, hi, v) = (table[i], table[i + 1], table[i + 2])
    if lo > next && pred(default) {
      out.push((next, lo - 1))
    }
    if pred(v) {
      out.push((lo, hi))
    }
    next = hi + 1
  }
  if next <= 0x10FFFF && pred(default) {
    out.push((next, 0x10FFFF))
  }
  merge_ranges(out)
}

///|
/// The ranges of a canonical general category (leaf or group), excluding the
/// special `Any`, `Assigned` and `ASCII`. `None` if there is no data for it.
pub fn general_category_ranges(canonical : String) -> Array[(Int, Int)]? {
  let leaves : Array[Int] = []
  for i, name in gc_names[:] {
    if name == canonical {
      leaves.push(i)
    }
  }
  if leaves.is_empty() {
    let mut i = 0
    while i < gc_groups.length() {
      let group = gc_groups[i]
      i += 1
      while gc_groups[i] != "" {
        if group == canonical {
          for j, name in gc_names[:] {
            if name == gc_groups[i] {
              leaves.push(j)
            }
          }
        }
        i += 1
      }
      i += 1
    }
  }
  if leaves.is_empty() {
    return None
  }
  Some(valued_ranges(gc_table, gc_unassigned, v => leaves.contains(v)))
}

///|
/// The ranges of a canonical script. `None` if there is no data for it.
pub fn script_ranges(canonical : String) -> Array[(Int, Int)]? {
  for i, name in regex_script_names[:] {
    if name == canonical {
      return Some(valued_ranges(regex_script_table, -1, v => v == i))
    }
  }
  None
}

///|
/// The `Script_Extensions` ranges of a canonical script. `None` if there is
/// no data for it.
pub fn script_extension_ranges(canonical : String) -> Array[(Int, Int)]? {
  for i, name in regex_script_names[:] {
    if name == canonical {
      let out = []
      for j = script_extension_offsets[i]
          j < script_extension_offsets[i + 1]
          j = j + 2 {
        out.push((script_extension_table[j], script_extension_table[j + 1]))
      }
      return Some(out)
    }
  }
  None
}

///|
/// The ranges of a canonical binary property. `None` if there is no data
/// for it.
pub fn bool_property_ranges(canonical : String) -> Array[(Int, Int)]? {
  for i, name in bool_prop_names[:] {
    if name == canonical {
      let out = []
      for j = bool_prop_offsets[i]; j < bool_prop_offsets[i + 1]; j = j + 2 {
        out.push((bool_prop_ranges[j], bool_prop_ranges[j + 1]))
      }
      return Some(out)
    }
  }
  None
}

///|
/// The next character in the simple case folding orbit of `c` (regex-syntax
/// `SimpleCaseFolder`), or `None` if `c` has no case variants.
pub fn simple_fold_next(c : Int) -> Int? {
  let n = case_fold_table.length() / 2
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    let k = case_fold_table[2 * mid]
    if c < k {
      continue lo, mid
    } else if c > k {
      continue mid + 1, hi
    } else {
      break Some(case_fold_table[2 * mid + 1])
    }
  } nobreak {
    None
  }
}

///|
/// All characters in `lo..=hi` that have case variants.
pub fn chars_with_case_variants(lo : Int, hi : Int) -> Array[Int] {
  let n = case_fold_table.length() / 2
  // First entry >= lo.
  let start = for l = 0, h = n; l < h; {
    let mid = l + (h - l) / 2
    if case_fold_table[2 * mid] < lo {
      continue mid + 1, h
    } else {
      continue l, mid
    }
  } nobreak {
    l
  }
  let out = []
  for i = start; i < n && case_fold_table[2 * i] <= hi; i = i + 1 {
    out.push(case_fold_table[2 * i])
  }
  out
}
