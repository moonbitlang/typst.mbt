// Port of `simplecss` 0.2.2 `src/lib.rs`.
//
// A simple [CSS 2.1](https://www.w3.org/TR/CSS21/) parser and selector.
//
// Limitations:
// - At-rules are not supported. They will be skipped during parsing.
// - Property values are not parsed.
// - CDO/CDC comments are not supported.
// - Parser is case sensitive. All keywords must be lowercase.
// - Unicode escape, like `\26`, is not supported.
//
// Upstream logs warnings via `log::warn!`; the port drops logging.

///|
/// A list of possible errors.
pub(all) suberror CssError {
  /// The steam ended earlier than we expected.
  ///
  /// Should only appear on invalid input data.
  UnexpectedEndOfStream
  /// An invalid ident.
  InvalidIdent(TextPos)
  /// An unclosed comment.
  InvalidComment(TextPos)
  /// An invalid declaration value.
  InvalidValue(TextPos)
  /// An invalid byte.
  InvalidByte(expected~ : Byte, actual~ : Byte, pos~ : TextPos)
  /// A missing selector.
  SelectorMissing
  /// An unexpected selector.
  UnexpectedSelector
  /// An unexpected combinator.
  UnexpectedCombinator
  /// An invalid or unsupported attribute selector.
  InvalidAttributeSelector
  /// An invalid language pseudo-class.
  InvalidLanguagePseudoClass
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssError with @debug.Debug::{to_repr}

///|
/// Upstream `Display`.
pub impl Show for CssError with fn output(self, logger) {
  match self {
    UnexpectedEndOfStream => logger.write_string("unexpected end of stream")
    InvalidIdent(pos) => logger.write_string("invalid ident at \{pos}")
    InvalidComment(pos) => logger.write_string("invalid comment at \{pos}")
    InvalidValue(pos) => logger.write_string("invalid value at \{pos}")
    InvalidByte(expected~, actual~, pos~) => {
      logger.write_string("expected '")
      logger.write_char(expected.to_int().unsafe_to_char())
      logger.write_string("' not '")
      logger.write_char(actual.to_int().unsafe_to_char())
      logger.write_string("' at \{pos}")
    }
    SelectorMissing => logger.write_string("selector missing")
    UnexpectedSelector => logger.write_string("unexpected selector")
    UnexpectedCombinator => logger.write_string("unexpected combinator")
    InvalidAttributeSelector =>
      logger.write_string("invalid or unsupported attribute selector")
    InvalidLanguagePseudoClass =>
      logger.write_string("invalid language pseudo-class")
  }
}

///|
pub extend CssError with Show::{to_string, output}

///|
/// A position in text.
///
/// Position indicates a row/line and a column in the original text. Starting
/// from 1:1.
pub(all) struct TextPos {
  row : UInt
  col : UInt
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextPos with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextPos with @debug.Debug::{to_repr}

///|
/// Constructs a new `TextPos`.
pub fn TextPos::new(row : UInt, col : UInt) -> TextPos {
  { row, col, }
}

///|
/// Upstream `Display`: `row:col`.
pub impl Show for TextPos with fn output(self, logger) {
  logger.write_string("\{self.row}:\{self.col}")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextPos with Show::{to_string, output}

///|
/// A declaration.
pub(all) struct Declaration {
  name : String
  value : String
  important : Bool
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Declaration with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Declaration with @debug.Debug::{to_repr}

///|
/// A rule.
pub(all) struct Rule {
  /// A rule selector.
  selector : Selector
  /// A rule declarations.
  mut declarations : Array[Declaration]
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rule with @debug.Debug::{to_repr}

///|
/// A style sheet.
pub(all) struct StyleSheet {
  /// A list of rules.
  mut rules : Array[Rule]
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StyleSheet with @debug.Debug::{to_repr}

///|
/// Creates an empty style sheet.
pub fn StyleSheet::new() -> StyleSheet {
  { rules: [], }
}

///|
pub fn StyleSheet::default() -> StyleSheet {
  StyleSheet::new()
}

///|
/// Parses a style sheet from text.
///
/// At-rules are not supported and will be skipped.
///
/// Doesn't produce any errors. In worst case scenario will return an empty
/// stylesheet.
pub fn StyleSheet::parse(text : String) -> StyleSheet {
  let sheet = StyleSheet::new()
  sheet.parse_more(text)
  sheet
}

///|
/// Parses a style sheet from a text to the current style sheet.
pub fn StyleSheet::parse_more(self : StyleSheet, text : String) -> Unit {
  let s = Stream::from_string(text)
  s.skip_spaces_and_comments() catch {
    _ => return
  }
  while !s.at_end() {
    s.skip_spaces_and_comments() catch {
      _ => break
    }
    consume_statement(s, self.rules) catch {
      _ => ()
    }
  }

  // Remove empty rules.
  self.rules.retain(rule => !rule.declarations.is_empty())

  // Sort the rules by specificity (stable, like `sort_by_cached_key`).
  let keyed = self.rules.mapi((i, rule) => (rule.selector.specificity(), i))
  keyed.sort_by((a, b) => {
    let c = compare_specificity(a.0, b.0)
    if c != 0 {
      c
    } else {
      a.1.compare(b.1)
    }
  })
  let rules = self.rules
  self.rules = keyed.map(k => rules[k.1])
}

///|
fn compare_specificity(a : FixedArray[Byte], b : FixedArray[Byte]) -> Int {
  for i in 0..<3 {
    let c = a[i].compare(b[i])
    if c != 0 {
      return c
    }
  }
  0
}

///|
/// Upstream `Display`.
pub impl Show for StyleSheet with fn output(self, logger) {
  for i, rule in self.rules {
    logger.write_string("\{rule.selector} { ")
    for dec in rule.declarations {
      logger.write_string("\{dec.name}:\{dec.value}")
      if dec.important {
        logger.write_string(" !important")
      }
      logger.write_string(";")
    }
    logger.write_string(" }")
    if i != self.rules.length() - 1 {
      logger.write_string("\n")
    }
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StyleSheet with Show::{to_string, output}

///|
fn consume_statement(s : Stream, rules : Array[Rule]) -> Unit raise CssError {
  if s.curr_byte_ok() == Some(b'@') {
    s.advance(1)
    consume_at_rule(s)
  } else {
    consume_rule_set(s, rules)
  }
}

///|
fn consume_at_rule(s : Stream) -> Unit raise CssError {
  let _ident = s.consume_ident()
  s.skip_bytes(c => c != b';' && c != b'{')
  match s.curr_byte() {
    b';' => s.advance(1)
    b'{' => consume_block(s)
    _ => ()
  }
}

///|
fn consume_rule_set(s : Stream, rules : Array[Rule]) -> Unit raise CssError {
  let start_rule_idx = rules.length()
  while s.curr_byte() == b',' || start_rule_idx == rules.length() {
    if s.curr_byte() == b',' {
      s.advance(1)
    }
    let (selector, offset) = parse_selector(s.slice_tail())
    s.advance(offset)
    s.skip_spaces()
    if selector is Some(selector) {
      rules.push({ selector, declarations: [], })
    }
    match s.curr_byte() {
      b'{' => break
      b',' => ()
      _ => {
        s.skip_bytes(c => c != b'{')
        break
      }
    }
  }
  s.try_consume_byte(b'{')
  let declarations = consume_declarations(s)
  for i in start_rule_idx..<rules.length() {
    rules[i].declarations = declarations.copy()
  }
  s.try_consume_byte(b'}')
}

///|
fn consume_block(s : Stream) -> Unit {
  s.try_consume_byte(b'{')
  consume_until_block_end(s)
}

///|
fn consume_until_block_end(s : Stream) -> Unit {
  // Block can have nested blocks, so we have to check for matching braces.
  // We simply counting the number of opening braces, which is incorrect,
  // since `{` can be inside a string, but it's fine for majority of the cases.
  let mut braces = 0
  while !s.at_end() {
    match s.curr_byte_unchecked() {
      b'{' => braces += 1
      b'}' => if braces == 0 { break } else { braces -= 1 }
      _ => ()
    }
    s.advance(1)
  }
  s.try_consume_byte(b'}')
}

///|
fn consume_declarations(s : Stream) -> Array[Declaration] {
  let declarations = []
  while !s.at_end() && s.curr_byte_ok() != Some(b'}') {
    try consume_declaration(s) catch {
      _ => {
        consume_until_block_end(s)
        break
      }
    } noraise {
      declaration => declarations.push(declaration)
    }
  }
  declarations
}

///|
/// A declaration tokenizer.
///
/// Tokenizer will stop at the first invalid token.
///
/// ```mbt check
/// test {
///   let t = @simplecss.DeclarationTokenizer::from(
///     "background: url(\"img.png\"); color:red !important",
///   )
///   assert_eq(
///     t.next(),
///     Some({ name: "background", value: "url(\"img.png\")", important: false, }),
///   )
///   assert_eq(t.next(), Some({ name: "color", value: "red", important: true, }))
/// }
/// ```
pub struct DeclarationTokenizer {
  priv stream : Stream
}

///|
pub fn DeclarationTokenizer::from(text : String) -> DeclarationTokenizer {
  { stream: Stream::from_string(text), }
}

///|
pub fn DeclarationTokenizer::next(self : DeclarationTokenizer) -> Declaration? {
  self.stream.skip_spaces_and_comments() catch {
    _ => ()
  }
  if self.stream.at_end() {
    return None
  }
  try consume_declaration(self.stream) catch {
    _ => {
      self.stream.jump_to_end()
      None
    }
  } noraise {
    v => Some(v)
  }
}

///|
pub fn DeclarationTokenizer::iter(
  self : DeclarationTokenizer,
) -> Iter[Declaration] {
  Iter::new(() => self.next())
}

///|
fn consume_declaration(s : Stream) -> Declaration raise CssError {
  s.skip_spaces_and_comments()

  // Parse name.

  // https://snook.ca/archives/html_and_css/targetting_ie7
  if s.curr_byte_ok() == Some(b'*') {
    s.advance(1)
  }
  let name = s.consume_ident()
  s.skip_spaces_and_comments()
  s.consume_byte(b':')
  s.skip_spaces_and_comments()

  // Parse value.
  let start = s.pos()
  let mut end = s.pos()
  while true {
    consume_term(s) catch {
      _ => break
    }
    end = s.pos()
    s.skip_spaces_and_comments()
  }
  let value = rust_trim(s.slice_range(start, end))
  s.skip_spaces_and_comments()

  // Check for `important`.
  let mut important = false
  if s.curr_byte_ok() == Some(b'!') {
    s.advance(1)
    s.skip_spaces_and_comments()
    if s.slice_tail() is [.. b"important", ..] {
      s.advance(9)
      important = true
    }
  }
  s.skip_spaces_and_comments()
  while s.curr_byte_ok() == Some(b';') {
    s.advance(1)
    s.skip_spaces_and_comments()
  }
  s.skip_spaces_and_comments()
  if value.is_empty() {
    raise InvalidValue(s.gen_text_pos_from(start))
  }
  { name, value, important, }
}

///|
fn consume_term(s : Stream) -> Unit raise CssError {
  fn consume_digits(s : Stream) {
    while s.curr_byte_ok() is Some(b'0'..<=b'9') {
      s.advance(1)
    }
  }

  match s.curr_byte() {
    b'#' => {
      s.advance(1)
      try s.consume_ident() catch {
        _ =>
          // Try consume as a hex color.
          while s.curr_byte_ok() is Some(c) {
            match c {
              b'0'..<=b'9' | b'a'..<=b'f' | b'A'..<=b'F' => s.advance(1)
              _ => break
            }
          }
      } noraise {
        _ => ()
      }
    }
    b'+' | b'-' | b'0'..<=b'9' | b'.' => {
      // Consume number.
      s.advance(1)
      consume_digits(s)
      if s.curr_byte_ok() == Some(b'.') {
        s.advance(1)
        consume_digits(s)
      }
      if s.curr_byte_ok() == Some(b'%') {
        s.advance(1)
      } else {
        // Consume suffix if any.
        ignore(s.consume_ident() catch { _ => "" })
      }
    }
    b'\'' | b'"' => s.consume_string() |> ignore
    b',' => s.advance(1)
    _ => {
      s.consume_ident() |> ignore

      // Consume function.
      if s.curr_byte_ok() == Some(b'(') {
        s.skip_bytes(c => c != b')')
        s.consume_byte(b')')
      }
    }
  }
}
