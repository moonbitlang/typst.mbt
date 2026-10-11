// Port of `typst-assets/src/mathml.rs` (rev pinned in `oracle/Cargo.toml`):
// data describing an operator's properties from the MathML Core operator
// dictionary. The tables themselves are generated into `mathml_data_gen.mbt`
// by `oracle/src/bin/gen_mathml.rs` from the very same crate.

///|
/// Information about an operator.
pub(all) struct OperatorInfo {
  /// An optional form for this operator.
  form : Form?
  /// The space to the left of this operator, in em.
  lspace : Double
  /// The space to the right of this operator, in em.
  rspace : Double
  /// The properties this operator has.
  properties : Properties
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OperatorInfo with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OperatorInfo with @debug.Debug::{to_repr}

///|
/// The form an operator can have.
pub(all) enum Form {
  Infix
  Prefix
  Postfix
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Form with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Form with @debug.Debug::{to_repr}

///|
/// Set of properties an operator can have.
pub(all) struct Properties(Int) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Properties with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Properties with @debug.Debug::{to_repr}

///|
pub let properties_stretchy : Properties = Properties(1 << 0)

///|
pub let properties_symmetric : Properties = Properties(1 << 1)

///|
pub let properties_largeop : Properties = Properties(1 << 2)

///|
pub let properties_movablelimits : Properties = Properties(1 << 3)

///|
/// Whether all flags in `other` are set.
pub fn Properties::contains(self : Properties, other : Properties) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// The categories of the operator dictionary, as indices into
/// `category_infos` (upstream `data::Category`).
let category_default : Int = 0

///|
let category_force_default : Int = 1

///|
let category_i : Int = 10

///|
let category_l : Int = 13

///|
let category_m : Int = 14

///|
/// Gets the `OperatorInfo` corresponding to the given (content, form) pair.
pub fn OperatorInfo::of(
  content : String,
  form : Form,
  explicit_form : Bool,
) -> OperatorInfo {
  let category = get_operator_category(content, form)
  let category = if explicit_form || category != category_default {
    category
  } else {
    get_implicit_operator_category(content)
  }
  category_infos[category]
}

///|
/// Performs Step 4 of the algorithm for determining the properties of an
/// embellished operator, from the MathML Core specification.
fn get_implicit_operator_category(content : String) -> Int {
  for form in [Infix, Postfix, Prefix] {
    let category = get_operator_category(content, form)
    if category != category_default {
      return category
    }
  }
  category_default
}

///|
/// The single character of the string, if it has exactly one (upstream
/// `str::parse::<char>`).
fn single_char(s : String) -> Char? {
  let mut result = None
  for i, c in s {
    if i > 0 {
      return None
    }
    result = Some(c)
  }
  result
}

///|
/// Implementation of the algorithm to determine the category of an
/// operator, as described in the MathML Core specification.
fn get_operator_category(content : String, form : Form) -> Int {
  // The string is stored as UTF-16, so its length is the UTF-16 count.
  let c : Char = match content.length() {
    1 => {
      // Content must be a single codepoint in the BMP.
      let c = content.get_char(0).unwrap()

      // Step 2.
      if c is ('\u{0320}'..<='\u{03FF}') {
        return category_default
      }

      // Otherwise, don't replace content.
      c
    }
    2 =>
      // Is this a surrogate pair?
      match single_char(content) {
        Some(c) =>
          // Step 2.1.
          if c is ('\u{1EEF0}' | '\u{1EEF1}') && form == Postfix {
            return category_i

            // Step 2.4.
          } else {
            return category_default
          }
        None => {
          // No, its two characters in BMP.
          let first = content.get_char(0).unwrap()
          let second = content.get_char(1).unwrap()

          // Step 2.2.
          if second is ('\u{0338}' | '\u{20D2}') {
            first

            // Step 2.3.
          } else if map_two_ascii_chars(content) is Some(c) {
            c

            // Step 2.4.
          } else {
            return category_default
          }
        }
      }
    _ =>
      // Step 1.
      return category_default
  }

  // Step 3.
  if form == Infix && c is ('\u{007C}' | '\u{223C}') {
    return category_force_default
  }
  match (c, form) {
    ('\u{2145}'..<='\u{2146}' | '\u{2202}' | '\u{221A}'..<='\u{221C}', Prefix) =>
      return category_l
    ('\u{002C}' | '\u{003A}' | '\u{003B}', Infix) => return category_m
    _ => ()
  }

  // Step 3.1.
  let content = c.to_int()
  let mut key = if content <= 0x03FF {
    content
  } else if content >= 0x2000 && content <= 0x2BFF {
    content - 0x1C00
  } else {
    return category_default
  }

  // Step 3.2.
  key += match form {
    Infix => 0x0000
    Prefix => 0x1000
    Postfix => 0x2000
  }

  // Step 3.4.
  let table = operator_table
  let mut lo = 0
  let mut hi = table.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let (k, data) = table[mid]
    // Note that `k` is already `% 0x4000` through the codegen.
    if key < k {
      hi = mid
    } else if key > k + (data & 0x0F) {
      lo = mid + 1
    } else {
      return from_encoding(data >> 4)
    }
  }
  category_default
}

///|
/// Maps an operator table encoding to its category.
fn from_encoding(encoding : Int) -> Int {
  for entry in category_encodings[:] {
    if entry.0 == encoding {
      return entry.1
    }
  }
  abort("unreachable")
}

///|
/// Whether the given text has the fence attribute.
pub fn is_fence(content : String) -> Bool {
  let c = match map_two_ascii_chars(content) {
    Some(c) => Some(c)
    None => single_char(content)
  }
  guard c is Some(c) else { return false }
  let c = c.to_int()
  let mut lo = 0
  let mut hi = fence_table.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let (s, len) = fence_table[mid]
    if c < s.to_int() {
      hi = mid
    } else if c >= s.to_int() + len {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
/// Whether the given text has the separator attribute.
pub fn is_separator(content : String) -> Bool {
  match single_char(content) {
    Some(c) => separator_table.contains(c)
    None => false
  }
}

///|
/// Whether the intrinsic stretch axis of the given Unicode character is
/// inline. If it is not inline, then it is block.
pub fn is_stretch_axis_inline(c : Char) -> Bool {
  let value = c.to_int()
  if value <= 0xFFFF {
    inline_axis_bmp_table.binary_search(value) is Ok(_)
  } else {
    inline_axis_non_bmp_table.contains(c)
  }
}

///|
/// Whether the given text is a single character and would be converted to
/// its italic variant if the `math-auto` property is present.
pub fn will_auto_transform(content : String) -> Bool {
  match single_char(content) {
    Some(c) =>
      c
      is ('A'..<='Z'
      | 'a'..<='z'
      | 'ı'
      | 'ȷ'
      | 'Α'..<='Ρ'
      | 'ϴ'
      | 'Σ'..<='Ω'
      | '∇'
      | 'α'..<='ω'
      | '∂'
      | 'ϵ'
      | 'ϑ'
      | 'ϰ'
      | 'ϕ'
      | 'ϱ'
      | 'ϖ')
    None => false
  }
}

///|
fn map_two_ascii_chars(content : String) -> Char? {
  for idx, s in two_ascii_chars_table[:] {
    if s == content {
      return Some((0x0320 + idx).unsafe_to_char())
    }
  }
  None
}
