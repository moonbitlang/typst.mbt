// Port of `typst-html/src/charsets.rs`: defines syntactical properties of
// HTML tags, attributes, and text.
//
// Lives in `library` (prefixed `charsets_`) because the HTML element field
// types (`HtmlTag`, `HtmlAttr`) validate with it; the `html` package reuses
// it for encoding.

///|
/// Check whether a character is in a tag name.
pub fn charsets_is_valid_in_tag_name(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '-'
}

///|
/// Check whether a character is valid in an attribute name.
pub fn charsets_is_valid_in_attribute_name(c : Char) -> Bool {
  match c {
    // These are forbidden.
    '\u{0}' | ' ' | '"' | '\'' | '>' | '/' | '=' => false
    c if charsets_is_whatwg_control_char(c) => false
    c if charsets_is_whatwg_non_char(c) => false
    // _Everything_ else is allowed, including U+2029 paragraph
    // separator. Go wild.
    _ => true
  }
}

///|
/// Check whether a character can be an used in an attribute value without
/// escaping.
///
/// See <https://html.spec.whatwg.org/multipage/syntax.html#attributes-2>
pub fn charsets_is_valid_in_attribute_value(c : Char) -> Bool {
  match c {
    // Ampersands are sometimes legal (i.e. when they are not _ambiguous
    // ampersands_) but it is not worth the trouble to check for that.
    '&' => false
    // Quotation marks are not allowed in double-quote-delimited attribute
    // values.
    '"' => false
    // All other text characters are allowed.
    c => charsets_is_w3c_text_char(c)
  }
}

///|
/// Check whether a character can be an used in normal text without
/// escaping.
pub fn charsets_is_valid_in_normal_element_text(c : Char) -> Bool {
  match c {
    // Ampersands are sometimes legal (i.e. when they are not _ambiguous
    // ampersands_) but it is not worth the trouble to check for that.
    '&' => false
    // Less-than signs are not allowed in text.
    '<' => false
    // All other text characters are allowed.
    c => charsets_is_w3c_text_char(c)
  }
}

///|
/// Check if something is valid text in HTML.
pub fn charsets_is_w3c_text_char(c : Char) -> Bool {
  match c {
    // Non-characters are obviously not text characters.
    c if charsets_is_whatwg_non_char(c) => false
    // Control characters are disallowed, except for whitespace.
    c if charsets_is_whatwg_control_char(c) => charsets_is_ascii_whitespace(c)
    // Everything else is allowed.
    _ => true
  }
}

///|
fn charsets_is_whatwg_non_char(c : Char) -> Bool {
  let n = c.to_int()
  match c {
    '\u{fdd0}'..='\u{fdef}' => true
    // Non-characters matching xxFFFE or xxFFFF up to x10FFFF (inclusive).
    _ if (n & 0xfffe) == 0xfffe && n <= 0x10ffff => true
    _ => false
  }
}

///|
fn charsets_is_whatwg_control_char(c : Char) -> Bool {
  match c {
    // C0 control characters.
    '\u{00}'..='\u{1f}' => true
    // Other control characters.
    '\u{7f}'..='\u{9f}' => true
    _ => false
  }
}

///|
/// Rust's `char::is_ascii_whitespace` (U+0020, U+0009, U+000A, U+000C,
/// U+000D; not U+000B).
fn charsets_is_ascii_whitespace(c : Char) -> Bool {
  c is (' ' | '\t' | '\n' | '\u{0c}' | '\r')
}
