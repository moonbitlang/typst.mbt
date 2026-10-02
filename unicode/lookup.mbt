///|
/// Binary search a flat `[lo0, hi0, lo1, hi1, ...]` range table.
fn in_ranges(table : FixedArray[Int], c : Int) -> Bool {
  let n = table.length() / 2
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    if c < table[2 * mid] {
      continue lo, mid
    } else if c > table[2 * mid + 1] {
      continue mid + 1, hi
    } else {
      break true
    }
  } nobreak {
    false
  }
}

///|
/// Binary search a flat `[lo0, hi0, v0, lo1, hi1, v1, ...]` table, returning
/// the value of the matching range or `default`.
fn in_valued(table : FixedArray[Int], c : Int, default : Int) -> Int {
  let n = table.length() / 3
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    if c < table[3 * mid] {
      continue lo, mid
    } else if c > table[3 * mid + 1] {
      continue mid + 1, hi
    } else {
      break table[3 * mid + 2]
    }
  } nobreak {
    default
  }
}

///|
/// Unicode `XID_Start`.
pub fn is_xid_start(c : Char) -> Bool {
  let c = c.to_int()
  if c < 0x80 {
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
  } else {
    in_ranges(xid_start_table, c)
  }
}

///|
/// Unicode `XID_Continue`.
pub fn is_xid_continue(c : Char) -> Bool {
  let c = c.to_int()
  if c < 0x80 {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_'
  } else {
    in_ranges(xid_continue_table, c)
  }
}

///|
/// Equivalent of Rust's `char::is_whitespace` (Unicode `White_Space`).
pub fn is_whitespace(c : Char) -> Bool {
  let c = c.to_int()
  if c < 0x80 {
    c == ' ' || (c >= 0x09 && c <= 0x0D)
  } else {
    in_ranges(white_space_table, c)
  }
}

///|
/// Whether a codepoint is Unicode `Default_Ignorable` (upstream
/// `typst_library::text::is_default_ignorable`).
pub fn is_default_ignorable(c : Char) -> Bool {
  in_ranges(default_ignorable_table, c.to_int())
}

///|
/// Equivalent of Rust's `char::is_alphabetic`.
pub fn is_alphabetic(c : Char) -> Bool {
  let c = c.to_int()
  if c < 0x80 {
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
  } else {
    in_ranges(alphabetic_table, c)
  }
}

///|
/// Equivalent of Rust's `char::is_numeric` (general categories Nd, Nl, No).
pub fn is_numeric(c : Char) -> Bool {
  let c = c.to_int()
  if c < 0x80 {
    c >= '0' && c <= '9'
  } else {
    in_ranges(numeric_table, c)
  }
}

///|
/// Equivalent of Rust's `char::is_alphanumeric`.
pub fn is_alphanumeric(c : Char) -> Bool {
  is_alphabetic(c) || is_numeric(c)
}

///|
/// Equivalent of Rust's `char::is_lowercase`.
pub fn is_lowercase(c : Char) -> Bool {
  in_ranges(lowercase_table, c.to_int())
}

///|
/// Equivalent of Rust's `char::is_uppercase`.
pub fn is_uppercase(c : Char) -> Bool {
  in_ranges(uppercase_table, c.to_int())
}

///|
/// Equivalent of Rust's `char::is_control`.
pub fn is_control(c : Char) -> Bool {
  in_ranges(control_table, c.to_int())
}

///|
/// The full name of the character's Unicode script, as printed by Rust's
/// `unicode_script::Script` debug format (e.g. `"Latin"`, `"Han"`).
pub fn script(c : Char) -> String {
  script_names[in_valued(script_table, c.to_int(), script_unknown)]
}

///|
/// Whether the script of `c` is one of Han, Hiragana, Katakana or Hangul.
pub fn is_cjk_script(c : Char) -> Bool {
  match script(c) {
    "Han" | "Hiragana" | "Katakana" | "Hangul" => true
    _ => false
  }
}

///|
/// A Unicode math class, as defined in `MathClass.txt`.
pub(all) enum MathClass {
  Normal
  Alphabetic
  Binary
  Closing
  Diacritic
  Fence
  GlyphPart
  Large
  Opening
  Punctuation
  Relation
  Space
  Unary
  Vary
  Special
} derive(Eq, Debug, Hash)

///|
let math_classes : FixedArray[MathClass] = [
  Normal,
  Alphabetic,
  Binary,
  Closing,
  Diacritic,
  Fence,
  GlyphPart,
  Large,
  Opening,
  Punctuation,
  Relation,
  Space,
  Unary,
  Vary,
  Special,
]

///|
/// Typst's default math class for a character (`typst_utils::default_math_class`).
pub fn default_math_class(c : Char) -> MathClass? {
  let v = in_valued(math_class_table, c.to_int(), -1)
  if v < 0 {
    None
  } else {
    Some(math_classes[v])
  }
}

///|
/// Whether to discard an inferred space between two strings (codex
/// `space_discarding::discard_space_between`). This is `true` when the inner
/// character of _either_ string is unambiguously from a writing system which
/// does not use space characters (Chinese, Japanese, Yi and ideographic
/// punctuation). Otherwise the inferred space should be kept.
pub fn discard_space_between(before : StringView, after : StringView) -> Bool {
  // Get the inner characters first since we often need to check both.
  let before_c = before.rev_iter().head()
  let after_c = after.iter().head()
  // Discard spaces if either character's writing system does not use spaces.
  // Keep spaces if both character's writing system uses spaces.
  (before_c is Some(c) && in_ranges(no_space_writing_table, c.to_int())) ||
  (after_c is Some(c) && in_ranges(no_space_writing_table, c.to_int()))
}

///|
/// The displayed width of a character in columns, like `unicode-width`
/// 0.1.14's `UnicodeWidthChar::width` (`None` for control characters).
pub fn char_width(c : Char) -> Int? {
  match in_valued(char_width_table, c.to_int(), 2) {
    0 => None
    v => Some(v - 1)
  }
}
