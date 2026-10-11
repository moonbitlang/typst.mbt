// Port of `yaml_rust::scanner` (yaml-rust 0.4.5).

///|
pub(all) enum TEncoding {
  Utf8
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TEncoding with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TEncoding with @debug.Debug::{to_repr}

///|
pub(all) enum TScalarStyle {
  Any
  Plain
  SingleQuoted
  DoubleQuoted
  Literal
  Foled
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TScalarStyle with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TScalarStyle with @debug.Debug::{to_repr}

///|
/// A position in the input. `index` counts chars (code points), `line` starts
/// from 1 and `col` from 0.
pub struct Marker {
  priv index : Int
  priv line : Int
  priv col : Int
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Marker with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Marker with @debug.Debug::{to_repr}

///|
fn Marker::new(index : Int, line : Int, col : Int) -> Marker {
  { index, line, col, }
}

///|
pub fn Marker::index(self : Marker) -> Int {
  self.index
}

///|
pub fn Marker::line(self : Marker) -> Int {
  self.line
}

///|
pub fn Marker::col(self : Marker) -> Int {
  self.col
}

///|
pub(all) suberror ScanError {
  ScanError(mark~ : Marker, info~ : String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScanError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScanError with @debug.Debug::{to_repr}

///|
pub fn ScanError::new(loc : Marker, info : String) -> ScanError {
  ScanError(mark=loc, info~)
}

///|
pub fn ScanError::marker(self : ScanError) -> Marker {
  let ScanError(mark~, ..) = self
  mark
}

///|
/// The error description (`Error::description` upstream).
pub fn ScanError::info(self : ScanError) -> String {
  let ScanError(info~, ..) = self
  info
}

///|
/// `impl Display for ScanError`; col starts from 0.
pub impl Show for ScanError with fn output(self, logger) {
  let ScanError(mark~, info~) = self
  logger.write_string("\{info} at line \{mark.line} column \{mark.col + 1}")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScanError with Show::{to_string, output}

///|
pub(all) enum TokenType {
  NoToken
  StreamStart(TEncoding)
  StreamEnd
  /// major, minor
  VersionDirective(UInt, UInt)
  /// handle, prefix
  TagDirective(String, String)
  DocumentStart
  DocumentEnd
  BlockSequenceStart
  BlockMappingStart
  BlockEnd
  FlowSequenceStart
  FlowSequenceEnd
  FlowMappingStart
  FlowMappingEnd
  BlockEntry
  FlowEntry
  Key
  Value
  Alias(String)
  Anchor(String)
  /// handle, suffix
  Tag(String, String)
  Scalar(TScalarStyle, String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TokenType with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TokenType with @debug.Debug::{to_repr}

///|
pub(all) struct Token(Marker, TokenType) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Token with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Token with @debug.Debug::{to_repr}

///|
priv struct SimpleKey {
  mut possible : Bool
  mut required : Bool
  mut token_number : Int
  mark : Marker
}

///|
fn SimpleKey::new(mark : Marker) -> SimpleKey {
  { possible: false, required: false, token_number: 0, mark, }
}

///|
/// The YAML tokenizer. The input is consumed char by char (code points),
/// like upstream's `Iterator<Item = char>`.
pub struct Scanner {
  priv rdr : Array[Char]
  /// Position in `rdr` of `buffer[0]`; chars past the end read as `'\0'`.
  priv mut pos : Int
  priv mut mark : Marker
  priv tokens : Array[Token]
  priv mut tokens_head : Int
  priv mut error : ScanError?
  priv mut stream_start_produced : Bool
  priv mut stream_end_produced : Bool
  priv mut adjacent_value_allowed_at : Int
  priv mut simple_key_allowed : Bool
  priv simple_keys : Array[SimpleKey]
  priv mut indent : Int
  priv indents : Array[Int]
  priv mut flow_level : Int
  priv mut tokens_parsed : Int
  priv mut token_available : Bool
}

///|
/// Iterator implementation: `None` at the end of the stream or after an error
/// (see `get_error`).
pub fn Scanner::next(self : Scanner) -> Token? {
  if self.error is Some(_) {
    return None
  }
  self.next_token() catch {
    e => {
      self.error = Some(e)
      None
    }
  }
}

///|
fn is_z(c : Char) -> Bool {
  c == '\u{0}'
}

///|
fn is_break(c : Char) -> Bool {
  c == '\n' || c == '\r'
}

///|
fn is_breakz(c : Char) -> Bool {
  is_break(c) || is_z(c)
}

///|
fn is_blank(c : Char) -> Bool {
  c == ' ' || c == '\t'
}

///|
fn is_blankz(c : Char) -> Bool {
  is_blank(c) || is_breakz(c)
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_alpha(c : Char) -> Bool {
  match c {
    '0'..<='9' | 'a'..<='z' | 'A'..<='Z' => true
    '_' | '-' => true
    _ => false
  }
}

///|
fn is_hex(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
fn as_hex(c : Char) -> UInt {
  match c {
    '0'..<='9' => (c.to_int() - '0'.to_int()).reinterpret_as_uint()
    'a'..<='f' => (c.to_int() - 'a'.to_int() + 10).reinterpret_as_uint()
    'A'..<='F' => (c.to_int() - 'A'.to_int() + 10).reinterpret_as_uint()
    _ => panic()
  }
}

///|
fn is_flow(c : Char) -> Bool {
  match c {
    ',' | '[' | ']' | '{' | '}' => true
    _ => false
  }
}

///|
/// `char::from_u32`.
fn char_from_u32(code : UInt) -> Char? {
  if code > 0x10FFFFU || (code >= 0xD800U && code <= 0xDFFFU) {
    None
  } else {
    Some(code.reinterpret_as_int().unsafe_to_char())
  }
}

///|
/// Creates the YAML tokenizer.
pub fn Scanner::new(rdr : String) -> Scanner {
  let chars = []
  for c in rdr {
    chars.push(c)
  }
  {
    rdr: chars,
    pos: 0,
    mark: Marker::new(0, 1, 0),
    tokens: [],
    tokens_head: 0,
    error: None,
    stream_start_produced: false,
    stream_end_produced: false,
    adjacent_value_allowed_at: 0,
    simple_key_allowed: true,
    simple_keys: [],
    indent: -1,
    indents: [],
    flow_level: 0,
    tokens_parsed: 0,
    token_available: false,
  }
}

///|
pub fn Scanner::get_error(self : Scanner) -> ScanError? {
  self.error
}

///|
/// Upstream fills `buffer` from the reader; here the whole input is decoded up
/// front, so this is a no-op kept for structural fidelity.
#inline
fn Scanner::lookahead(_self : Scanner, _count : Int) -> Unit {

}

///|
/// `self.buffer[i]`.
#inline
fn Scanner::buf(self : Scanner, i : Int) -> Char {
  let p = self.pos + i
  if p < self.rdr.length() {
    self.rdr[p]
  } else {
    '\u{0}'
  }
}

///|
fn Scanner::skip(self : Scanner) -> Unit {
  let c = self.buf(0)
  self.pos += 1
  let m = self.mark
  self.mark = if c == '\n' {
    Marker::new(m.index + 1, m.line + 1, 0)
  } else {
    Marker::new(m.index + 1, m.line, m.col + 1)
  }
}

///|
fn Scanner::skip_line(self : Scanner) -> Unit {
  if self.buf(0) == '\r' && self.buf(1) == '\n' {
    self.skip()
    self.skip()
  } else if is_break(self.buf(0)) {
    self.skip()
  }
}

///|
#inline
fn Scanner::ch(self : Scanner) -> Char {
  self.buf(0)
}

///|
#inline
fn Scanner::ch_is(self : Scanner, c : Char) -> Bool {
  self.buf(0) == c
}

///|
pub fn Scanner::stream_started(self : Scanner) -> Bool {
  self.stream_start_produced
}

///|
pub fn Scanner::stream_ended(self : Scanner) -> Bool {
  self.stream_end_produced
}

///|
pub fn Scanner::mark(self : Scanner) -> Marker {
  self.mark
}

///|
fn Scanner::read_break(self : Scanner, s : StringBuilder) -> Unit {
  if self.buf(0) == '\r' && self.buf(1) == '\n' {
    s.write_char('\n')
    self.skip()
    self.skip()
  } else if self.buf(0) == '\r' || self.buf(0) == '\n' {
    s.write_char('\n')
    self.skip()
  } else {
    panic()
  }
}

///|
fn Scanner::tokens_len(self : Scanner) -> Int {
  self.tokens.length() - self.tokens_head
}

///|
fn Scanner::push_token(self : Scanner, tok : Token) -> Unit {
  self.tokens.push(tok)
}

///|
fn Scanner::insert_token(self : Scanner, pos : Int, tok : Token) -> Unit {
  let old_len = self.tokens_len()
  guard! pos <= old_len
  self.tokens.insert(self.tokens_head + pos, tok)
}

///|
fn Scanner::allow_simple_key(self : Scanner) -> Unit {
  self.simple_key_allowed = true
}

///|
fn Scanner::disallow_simple_key(self : Scanner) -> Unit {
  self.simple_key_allowed = false
}

///|
fn Scanner::err(self : Scanner, info : String) -> ScanError {
  ScanError::new(self.mark, info)
}

///|
pub fn Scanner::fetch_next_token(self : Scanner) -> Unit raise ScanError {
  self.lookahead(1)
  if !self.stream_start_produced {
    self.fetch_stream_start()
    return
  }
  self.skip_to_next_token()
  self.stale_simple_keys()
  let mark = self.mark
  self.unroll_indent(mark.col)
  self.lookahead(4)
  if is_z(self.ch()) {
    self.fetch_stream_end()
    return
  }

  // Is it a directive?
  if self.mark.col == 0 && self.ch_is('%') {
    return self.fetch_directive()
  }
  if self.mark.col == 0 &&
    self.buf(0) == '-' &&
    self.buf(1) == '-' &&
    self.buf(2) == '-' &&
    is_blankz(self.buf(3)) {
    self.fetch_document_indicator(TokenType::DocumentStart)
    return
  }
  if self.mark.col == 0 &&
    self.buf(0) == '.' &&
    self.buf(1) == '.' &&
    self.buf(2) == '.' &&
    is_blankz(self.buf(3)) {
    self.fetch_document_indicator(TokenType::DocumentEnd)
    return
  }
  let c = self.buf(0)
  let nc = self.buf(1)
  match c {
    '[' => self.fetch_flow_collection_start(TokenType::FlowSequenceStart)
    '{' => self.fetch_flow_collection_start(TokenType::FlowMappingStart)
    ']' => self.fetch_flow_collection_end(TokenType::FlowSequenceEnd)
    '}' => self.fetch_flow_collection_end(TokenType::FlowMappingEnd)
    ',' => self.fetch_flow_entry()
    '-' if is_blankz(nc) => self.fetch_block_entry()
    '?' if is_blankz(nc) => self.fetch_key()
    ':' if is_blankz(nc) ||
      (
        self.flow_level > 0 &&
        (is_flow(nc) || self.mark.index == self.adjacent_value_allowed_at)
      ) => self.fetch_value()
    // Is it an alias?
    '*' => self.fetch_anchor(true)
    // Is it an anchor?
    '&' => self.fetch_anchor(false)
    '!' => self.fetch_tag()
    // Is it a literal scalar?
    '|' if self.flow_level == 0 => self.fetch_block_scalar(true)
    // Is it a folded scalar?
    '>' if self.flow_level == 0 => self.fetch_block_scalar(false)
    '\'' => self.fetch_flow_scalar(true)
    '"' => self.fetch_flow_scalar(false)
    // plain scalar
    '-' if !is_blankz(nc) => self.fetch_plain_scalar()
    ':' | '?' if !is_blankz(nc) && self.flow_level == 0 =>
      self.fetch_plain_scalar()
    '%' | '@' | '`' =>
      raise ScanError::new(self.mark, "unexpected character: `\{c}'")
    _ => self.fetch_plain_scalar()
  }
}

///|
pub fn Scanner::next_token(self : Scanner) -> Token? raise ScanError {
  if self.stream_end_produced {
    return None
  }
  if !self.token_available {
    self.fetch_more_tokens()
  }
  let t = self.tokens[self.tokens_head]
  self.tokens_head += 1
  if self.tokens_head == self.tokens.length() {
    self.tokens.clear()
    self.tokens_head = 0
  }
  self.token_available = false
  self.tokens_parsed += 1
  if t.1 is StreamEnd {
    self.stream_end_produced = true
  }
  Some(t)
}

///|
pub fn Scanner::fetch_more_tokens(self : Scanner) -> Unit raise ScanError {
  let mut need_more = false
  while true {
    need_more = false
    if self.tokens_len() == 0 {
      need_more = true
    } else {
      self.stale_simple_keys()
      for sk in self.simple_keys {
        if sk.possible && sk.token_number == self.tokens_parsed {
          need_more = true
          break
        }
      }
    }
    if !need_more {
      break
    }
    self.fetch_next_token()
  }
  self.token_available = true
}

///|
fn Scanner::stale_simple_keys(self : Scanner) -> Unit raise ScanError {
  for sk in self.simple_keys {
    if sk.possible &&
      (sk.mark.line < self.mark.line || sk.mark.index + 1024 < self.mark.index) {
      if sk.required {
        raise self.err("simple key expect ':'")
      }
      sk.possible = false
    }
  }
}

///|
fn Scanner::skip_to_next_token(self : Scanner) -> Unit {
  while true {
    self.lookahead(1)
    // TODO(chenyh) BOM
    match self.ch() {
      ' ' => self.skip()
      '\t' if self.flow_level > 0 || !self.simple_key_allowed => self.skip()
      '\n' | '\r' => {
        self.lookahead(2)
        self.skip_line()
        if self.flow_level == 0 {
          self.allow_simple_key()
        }
      }
      '#' =>
        while !is_breakz(self.ch()) {
          self.skip()
          self.lookahead(1)
        }
      _ => break
    }
  }
}

///|
fn Scanner::fetch_stream_start(self : Scanner) -> Unit {
  let mark = self.mark
  self.indent = -1
  self.stream_start_produced = true
  self.allow_simple_key()
  self.push_token(Token(mark, TokenType::StreamStart(Utf8)))
  self.simple_keys.push(SimpleKey::new(Marker::new(0, 0, 0)))
}

///|
fn Scanner::fetch_stream_end(self : Scanner) -> Unit raise ScanError {
  // force new line
  if self.mark.col != 0 {
    self.mark = Marker::new(self.mark.index, self.mark.line + 1, 0)
  }
  self.unroll_indent(-1)
  self.remove_simple_key()
  self.disallow_simple_key()
  self.push_token(Token(self.mark, TokenType::StreamEnd))
}

///|
fn Scanner::fetch_directive(self : Scanner) -> Unit raise ScanError {
  self.unroll_indent(-1)
  self.remove_simple_key()
  self.disallow_simple_key()
  let tok = self.scan_directive()
  self.push_token(tok)
}

///|
fn Scanner::scan_directive(self : Scanner) -> Token raise ScanError {
  let start_mark = self.mark
  self.skip()
  let name = self.scan_directive_name()
  let tok = match name {
    "YAML" => self.scan_version_directive_value(start_mark)
    "TAG" => self.scan_tag_directive_value(start_mark)
    // XXX This should be a warning instead of an error
    _ => {
      // skip current line
      self.lookahead(1)
      while !is_breakz(self.ch()) {
        self.skip()
        self.lookahead(1)
      }
      // XXX return an empty TagDirective token
      Token(start_mark, TokenType::TagDirective("", ""))
    }
  }
  self.lookahead(1)
  while is_blank(self.ch()) {
    self.skip()
    self.lookahead(1)
  }
  if self.ch() == '#' {
    while !is_breakz(self.ch()) {
      self.skip()
      self.lookahead(1)
    }
  }
  if !is_breakz(self.ch()) {
    raise ScanError::new(
      start_mark, "while scanning a directive, did not find expected comment or line break",
    )
  }

  // Eat a line break
  if is_break(self.ch()) {
    self.lookahead(2)
    self.skip_line()
  }
  tok
}

///|
fn Scanner::scan_version_directive_value(
  self : Scanner,
  mark : Marker,
) -> Token raise ScanError {
  self.lookahead(1)
  while is_blank(self.ch()) {
    self.skip()
    self.lookahead(1)
  }
  let major = self.scan_version_directive_number(mark)
  if self.ch() != '.' {
    raise ScanError::new(
      mark, "while scanning a YAML directive, did not find expected digit or '.' character",
    )
  }
  self.skip()
  let minor = self.scan_version_directive_number(mark)
  Token(mark, TokenType::VersionDirective(major, minor))
}

///|
fn Scanner::scan_directive_name(self : Scanner) -> String raise ScanError {
  let start_mark = self.mark
  let string = StringBuilder()
  self.lookahead(1)
  while is_alpha(self.ch()) {
    string.write_char(self.ch())
    self.skip()
    self.lookahead(1)
  }
  if string.is_empty() {
    raise ScanError::new(
      start_mark, "while scanning a directive, could not find expected directive name",
    )
  }
  if !is_blankz(self.ch()) {
    raise ScanError::new(
      start_mark, "while scanning a directive, found unexpected non-alphabetical character",
    )
  }
  string.to_string()
}

///|
fn Scanner::scan_version_directive_number(
  self : Scanner,
  mark : Marker,
) -> UInt raise ScanError {
  let mut val = 0U
  let mut length = 0
  self.lookahead(1)
  while is_digit(self.ch()) {
    if length + 1 > 9 {
      raise ScanError::new(
        mark, "while scanning a YAML directive, found extremely long version number",
      )
    }
    length += 1
    val = val * 10 + (self.ch().to_int() - '0'.to_int()).reinterpret_as_uint()
    self.skip()
    self.lookahead(1)
  }
  if length == 0 {
    raise ScanError::new(
      mark, "while scanning a YAML directive, did not find expected version number",
    )
  }
  val
}

///|
fn Scanner::scan_tag_directive_value(
  self : Scanner,
  mark : Marker,
) -> Token raise ScanError {
  self.lookahead(1)
  // Eat whitespaces.
  while is_blank(self.ch()) {
    self.skip()
    self.lookahead(1)
  }
  let handle = self.scan_tag_handle(true, mark)
  self.lookahead(1)
  // Eat whitespaces.
  while is_blank(self.ch()) {
    self.skip()
    self.lookahead(1)
  }
  let is_secondary = handle == "!!"
  let prefix = self.scan_tag_uri(true, is_secondary, "", mark)
  self.lookahead(1)
  if is_blankz(self.ch()) {
    Token(mark, TokenType::TagDirective(handle, prefix))
  } else {
    raise ScanError::new(
      mark, "while scanning TAG, did not find expected whitespace or line break",
    )
  }
}

///|
fn Scanner::fetch_tag(self : Scanner) -> Unit raise ScanError {
  self.save_simple_key()
  self.disallow_simple_key()
  let tok = self.scan_tag()
  self.push_token(tok)
}

///|
fn Scanner::scan_tag(self : Scanner) -> Token raise ScanError {
  let start_mark = self.mark
  let mut handle = ""
  let mut suffix = ""
  let mut secondary = false

  // Check if the tag is in the canonical form (verbatim).
  self.lookahead(2)
  if self.buf(1) == '<' {
    // Eat '!<'
    self.skip()
    self.skip()
    suffix = self.scan_tag_uri(false, false, "", start_mark)
    if self.ch() != '>' {
      raise ScanError::new(
        start_mark, "while scanning a tag, did not find the expected '>'",
      )
    }
    self.skip()
  } else {
    // The tag has either the '!suffix' or the '!handle!suffix'
    handle = self.scan_tag_handle(false, start_mark)
    // Check if it is, indeed, handle.
    if handle.length() >= 2 && handle.has_prefix("!") && handle.has_suffix("!") {
      if handle == "!!" {
        secondary = true
      }
      suffix = self.scan_tag_uri(false, secondary, "", start_mark)
    } else {
      suffix = self.scan_tag_uri(false, false, handle, start_mark)
      handle = "!"
      // A special case: the '!' tag.  Set the handle to '' and the
      // suffix to '!'.
      if suffix.is_empty() {
        handle = ""
        suffix = "!"
      }
    }
  }
  self.lookahead(1)
  if is_blankz(self.ch()) {
    // XXX: ex 7.2, an empty scalar can follow a secondary tag
    Token(start_mark, TokenType::Tag(handle, suffix))
  } else {
    raise ScanError::new(
      start_mark, "while scanning a tag, did not find expected whitespace or line break",
    )
  }
}

///|
fn Scanner::scan_tag_handle(
  self : Scanner,
  directive : Bool,
  mark : Marker,
) -> String raise ScanError {
  let string = StringBuilder()
  self.lookahead(1)
  if self.ch() != '!' {
    raise ScanError::new(
      mark, "while scanning a tag, did not find expected '!'",
    )
  }
  string.write_char(self.ch())
  self.skip()
  self.lookahead(1)
  while is_alpha(self.ch()) {
    string.write_char(self.ch())
    self.skip()
    self.lookahead(1)
  }

  // Check if the trailing character is '!' and copy it.
  if self.ch() == '!' {
    string.write_char(self.ch())
    self.skip()
  } else if directive && string.to_string() != "!" {
    // It's either the '!' tag or not really a tag handle.  If it's a %TAG
    // directive, it's an error.  If it's a tag token, it must be a part of
    // URI.
    raise ScanError::new(
      mark, "while parsing a tag directive, did not find expected '!'",
    )
  }
  string.to_string()
}

///|
fn Scanner::scan_tag_uri(
  self : Scanner,
  directive : Bool,
  _is_secondary : Bool,
  head : String,
  mark : Marker,
) -> String raise ScanError {
  // `head` is ASCII, so its UTF-16 length equals its byte length.
  let mut length = head.length()
  let string = StringBuilder()

  // Copy the head if needed.
  // Note that we don't copy the leading '!' character.
  if length > 1 {
    string.write_string(head.unsafe_substring(start=1, end=head.length()))
  }
  self.lookahead(1)
  // The set of characters that may appear in URI is as follows:
  //
  //      '0'-'9', 'A'-'Z', 'a'-'z', '_', '-', ';', '/', '?', ':', '@', '&',
  //      '=', '+', '$', ',', '.', '!', '~', '*', '\'', '(', ')', '[', ']',
  //      '%'.
  while (match self.ch() {
          ';' | '/' | '?' | ':' | '@' | '&' => true
          '='
          | '+'
          | '$'
          | ','
          | '.'
          | '!'
          | '~'
          | '*'
          | '\''
          | '('
          | ')'
          | '['
          | ']' => true
          '%' => true
          c if is_alpha(c) => true
          _ => false
        }) {
    // Check if it is a URI-escape sequence.
    if self.ch() == '%' {
      string.write_char(self.scan_uri_escapes(directive, mark))
    } else {
      string.write_char(self.ch())
      self.skip()
    }
    length += 1
    self.lookahead(1)
  }
  if length == 0 {
    raise ScanError::new(
      mark, "while parsing a tag, did not find expected tag URI",
    )
  }
  string.to_string()
}

///|
fn Scanner::scan_uri_escapes(
  self : Scanner,
  _directive : Bool,
  mark : Marker,
) -> Char raise ScanError {
  let mut width = 0
  let mut code = 0U
  while true {
    self.lookahead(3)
    if !(self.ch() == '%' && is_hex(self.buf(1)) && is_hex(self.buf(2))) {
      raise ScanError::new(
        mark, "while parsing a tag, did not find URI escaped octet",
      )
    }
    let octet = (as_hex(self.buf(1)) << 4) + as_hex(self.buf(2))
    if width == 0 {
      width = if (octet & 0x80) == 0x00 {
        1
      } else if (octet & 0xE0) == 0xC0 {
        2
      } else if (octet & 0xF0) == 0xE0 {
        3
      } else if (octet & 0xF8) == 0xF0 {
        4
      } else {
        raise ScanError::new(
          mark, "while parsing a tag, found an incorrect leading UTF-8 octet",
        )
      }
      code = octet
    } else {
      if (octet & 0xc0) != 0x80 {
        raise ScanError::new(
          mark, "while parsing a tag, found an incorrect trailing UTF-8 octet",
        )
      }
      code = (code << 8) + octet
    }
    self.skip()
    self.skip()
    self.skip()
    width -= 1
    if width == 0 {
      break
    }
  }
  match char_from_u32(code) {
    Some(ch) => ch
    None =>
      raise ScanError::new(
        mark, "while parsing a tag, found an invalid UTF-8 codepoint",
      )
  }
}

///|
fn Scanner::fetch_anchor(self : Scanner, alias_ : Bool) -> Unit raise ScanError {
  self.save_simple_key()
  self.disallow_simple_key()
  let tok = self.scan_anchor(alias_)
  self.push_token(tok)
}

///|
fn Scanner::scan_anchor(self : Scanner, alias_ : Bool) -> Token raise ScanError {
  let string = StringBuilder()
  let start_mark = self.mark
  self.skip()
  self.lookahead(1)
  while is_alpha(self.ch()) {
    string.write_char(self.ch())
    self.skip()
    self.lookahead(1)
  }
  if string.is_empty() ||
    (match self.ch() {
      c if is_blankz(c) => false
      '?' | ':' | ',' | ']' | '}' | '%' | '@' | '`' => false
      _ => true
    }) {
    raise ScanError::new(
      start_mark, "while scanning an anchor or alias, did not find expected alphabetic or numeric character",
    )
  }
  if alias_ {
    Token(start_mark, TokenType::Alias(string.to_string()))
  } else {
    Token(start_mark, TokenType::Anchor(string.to_string()))
  }
}

///|
fn Scanner::fetch_flow_collection_start(
  self : Scanner,
  tok : TokenType,
) -> Unit raise ScanError {
  // The indicators '[' and '{' may start a simple key.
  self.save_simple_key()
  self.increase_flow_level()
  self.allow_simple_key()
  let start_mark = self.mark
  self.skip()
  self.push_token(Token(start_mark, tok))
}

///|
fn Scanner::fetch_flow_collection_end(
  self : Scanner,
  tok : TokenType,
) -> Unit raise ScanError {
  self.remove_simple_key()
  self.decrease_flow_level()
  self.disallow_simple_key()
  let start_mark = self.mark
  self.skip()
  self.push_token(Token(start_mark, tok))
}

///|
fn Scanner::fetch_flow_entry(self : Scanner) -> Unit raise ScanError {
  self.remove_simple_key()
  self.allow_simple_key()
  let start_mark = self.mark
  self.skip()
  self.push_token(Token(start_mark, TokenType::FlowEntry))
}

///|
fn Scanner::increase_flow_level(self : Scanner) -> Unit raise ScanError {
  self.simple_keys.push(SimpleKey::new(Marker::new(0, 0, 0)))
  // `flow_level` is a `u8` upstream (`checked_add`).
  if self.flow_level >= 255 {
    raise self.err("recursion limit exceeded")
  }
  self.flow_level += 1
}

///|
fn Scanner::decrease_flow_level(self : Scanner) -> Unit {
  if self.flow_level > 0 {
    self.flow_level -= 1
    self.simple_keys.pop() |> ignore
  }
}

///|
fn Scanner::fetch_block_entry(self : Scanner) -> Unit raise ScanError {
  if self.flow_level == 0 {
    // Check if we are allowed to start a new entry.
    if !self.simple_key_allowed {
      raise self.err("block sequence entries are not allowed in this context")
    }
    let mark = self.mark
    // generate BLOCK-SEQUENCE-START if indented
    self.roll_indent(mark.col, None, TokenType::BlockSequenceStart, mark)
  } else {
    // - * only allowed in block
    raise self.err("\"-\" is only valid inside a block")
  }
  self.remove_simple_key()
  self.allow_simple_key()
  let start_mark = self.mark
  self.skip()
  self.push_token(Token(start_mark, TokenType::BlockEntry))
}

///|
fn Scanner::fetch_document_indicator(
  self : Scanner,
  t : TokenType,
) -> Unit raise ScanError {
  self.unroll_indent(-1)
  self.remove_simple_key()
  self.disallow_simple_key()
  let mark = self.mark
  self.skip()
  self.skip()
  self.skip()
  self.push_token(Token(mark, t))
}

///|
fn Scanner::fetch_block_scalar(
  self : Scanner,
  literal : Bool,
) -> Unit raise ScanError {
  self.save_simple_key()
  self.allow_simple_key()
  let tok = self.scan_block_scalar(literal)
  self.push_token(tok)
}

///|
fn Scanner::scan_block_scalar(
  self : Scanner,
  literal : Bool,
) -> Token raise ScanError {
  let start_mark = self.mark
  let mut chomping = 0
  let mut increment = 0
  let indent = Ref(0)
  let mut trailing_blank = false
  let mut leading_blank = false
  let string = StringBuilder()
  let leading_break = StringBuilder()
  let trailing_breaks = StringBuilder()

  // skip '|' or '>'
  self.skip()
  self.lookahead(1)
  if self.ch() == '+' || self.ch() == '-' {
    if self.ch() == '+' {
      chomping = 1
    } else {
      chomping = -1
    }
    self.skip()
    self.lookahead(1)
    if is_digit(self.ch()) {
      if self.ch() == '0' {
        raise ScanError::new(
          start_mark, "while scanning a block scalar, found an indentation indicator equal to 0",
        )
      }
      increment = self.ch().to_int() - '0'.to_int()
      self.skip()
    }
  } else if is_digit(self.ch()) {
    if self.ch() == '0' {
      raise ScanError::new(
        start_mark, "while scanning a block scalar, found an indentation indicator equal to 0",
      )
    }
    increment = self.ch().to_int() - '0'.to_int()
    self.skip()
    self.lookahead(1)
    if self.ch() == '+' || self.ch() == '-' {
      if self.ch() == '+' {
        chomping = 1
      } else {
        chomping = -1
      }
      self.skip()
    }
  }

  // Eat whitespaces and comments to the end of the line.
  self.lookahead(1)
  while is_blank(self.ch()) {
    self.skip()
    self.lookahead(1)
  }
  if self.ch() == '#' {
    while !is_breakz(self.ch()) {
      self.skip()
      self.lookahead(1)
    }
  }

  // Check if we are at the end of the line.
  if !is_breakz(self.ch()) {
    raise ScanError::new(
      start_mark, "while scanning a block scalar, did not find expected comment or line break",
    )
  }
  if is_break(self.ch()) {
    self.lookahead(2)
    self.skip_line()
  }
  if increment > 0 {
    indent.val = if self.indent >= 0 {
      self.indent + increment
    } else {
      increment
    }
  }
  // Scan the leading line breaks and determine the indentation level if needed.
  self.block_scalar_breaks(indent, trailing_breaks)
  self.lookahead(1)
  let start_mark = self.mark
  while self.mark.col == indent.val && !is_z(self.ch()) {
    // We are at the beginning of a non-empty line.
    trailing_blank = is_blank(self.ch())
    if !literal &&
      !leading_break.is_empty() &&
      !leading_blank &&
      !trailing_blank {
      if trailing_breaks.is_empty() {
        string.write_char(' ')
      }
      leading_break.reset()
    } else {
      string.write_string(leading_break.to_string())
      leading_break.reset()
    }
    string.write_string(trailing_breaks.to_string())
    trailing_breaks.reset()
    leading_blank = is_blank(self.ch())
    while !is_breakz(self.ch()) {
      string.write_char(self.ch())
      self.skip()
      self.lookahead(1)
    }
    // break on EOF
    if is_z(self.ch()) {
      break
    }
    self.lookahead(2)
    self.read_break(leading_break)

    // Eat the following indentation spaces and line breaks.
    self.block_scalar_breaks(indent, trailing_breaks)
  }

  // Chomp the tail.
  if chomping != -1 {
    string.write_string(leading_break.to_string())
  }
  if chomping == 1 {
    string.write_string(trailing_breaks.to_string())
  }
  if literal {
    Token(start_mark, TokenType::Scalar(Literal, string.to_string()))
  } else {
    Token(start_mark, TokenType::Scalar(Foled, string.to_string()))
  }
}

///|
fn Scanner::block_scalar_breaks(
  self : Scanner,
  indent : Ref[Int],
  breaks : StringBuilder,
) -> Unit raise ScanError {
  let mut max_indent = 0
  while true {
    self.lookahead(1)
    while (indent.val == 0 || self.mark.col < indent.val) && self.buf(0) == ' ' {
      self.skip()
      self.lookahead(1)
    }
    if self.mark.col > max_indent {
      max_indent = self.mark.col
    }

    // Check for a tab character messing the indentation.
    if (indent.val == 0 || self.mark.col < indent.val) && self.buf(0) == '\t' {
      raise self.err(
        "while scanning a block scalar, found a tab character where an indentation space is expected",
      )
    }
    if !is_break(self.ch()) {
      break
    }
    self.lookahead(2)
    // Consume the line break.
    self.read_break(breaks)
  }
  if indent.val == 0 {
    indent.val = max_indent
    if indent.val < self.indent + 1 {
      indent.val = self.indent + 1
    }
    if indent.val < 1 {
      indent.val = 1
    }
  }
}

///|
fn Scanner::fetch_flow_scalar(
  self : Scanner,
  single : Bool,
) -> Unit raise ScanError {
  self.save_simple_key()
  self.disallow_simple_key()
  let tok = self.scan_flow_scalar(single)

  // From spec: To ensure JSON compatibility, if a key inside a flow mapping is JSON-like,
  // YAML allows the following value to be specified adjacent to the “:”.
  self.adjacent_value_allowed_at = self.mark.index
  self.push_token(tok)
}

///|
fn Scanner::scan_flow_scalar(
  self : Scanner,
  single : Bool,
) -> Token raise ScanError {
  let start_mark = self.mark
  let string = StringBuilder()
  let leading_break = StringBuilder()
  let trailing_breaks = StringBuilder()
  let whitespaces = StringBuilder()
  let mut leading_blanks = false

  // Eat the left quote.
  self.skip()
  while true {
    // Check for a document indicator.
    self.lookahead(4)
    if self.mark.col == 0 &&
      (
        (self.buf(0) == '-' && self.buf(1) == '-' && self.buf(2) == '-') ||
        (self.buf(0) == '.' && self.buf(1) == '.' && self.buf(2) == '.')
      ) &&
      is_blankz(self.buf(3)) {
      raise ScanError::new(
        start_mark, "while scanning a quoted scalar, found unexpected document indicator",
      )
    }
    if is_z(self.ch()) {
      raise ScanError::new(
        start_mark, "while scanning a quoted scalar, found unexpected end of stream",
      )
    }
    self.lookahead(2)
    leading_blanks = false
    // Consume non-blank characters.
    while !is_blankz(self.ch()) {
      match self.ch() {
        // Check for an escaped single quote.
        '\'' if self.buf(1) == '\'' && single => {
          string.write_char('\'')
          self.skip()
          self.skip()
        }
        // Check for the right quote.
        '\'' if single => break
        '"' if !single => break
        // Check for an escaped line break.
        '\\' if !single && is_break(self.buf(1)) => {
          self.lookahead(3)
          self.skip()
          self.skip_line()
          leading_blanks = true
          break
        }
        // Check for an escape sequence.
        '\\' if !single => {
          let mut code_length = 0
          match self.buf(1) {
            '0' => string.write_char('\u{0}')
            'a' => string.write_char('\u{07}')
            'b' => string.write_char('\u{08}')
            't' | '\t' => string.write_char('\t')
            'n' => string.write_char('\n')
            'v' => string.write_char('\u{0b}')
            'f' => string.write_char('\u{0c}')
            'r' => string.write_char('\u{0d}')
            'e' => string.write_char('\u{1b}')
            ' ' => string.write_char('\u{20}')
            '"' => string.write_char('"')
            '\'' => string.write_char('\'')
            '\\' => string.write_char('\\')
            // NEL (#x85)
            'N' => string.write_char('\u{85}')
            // #xA0
            '_' => string.write_char('\u{A0}')
            // LS (#x2028)
            'L' => string.write_char('\u{2028}')
            // PS (#x2029)
            'P' => string.write_char('\u{2029}')
            'x' => code_length = 2
            'u' => code_length = 4
            'U' => code_length = 8
            _ =>
              raise ScanError::new(
                start_mark, "while parsing a quoted scalar, found unknown escape character",
              )
          }
          self.skip()
          self.skip()
          // Consume an arbitrary escape code.
          if code_length > 0 {
            self.lookahead(code_length)
            let mut value = 0U
            for i in 0..<code_length {
              if !is_hex(self.buf(i)) {
                raise ScanError::new(
                  start_mark, "while parsing a quoted scalar, did not find expected hexadecimal number",
                )
              }
              value = (value << 4) + as_hex(self.buf(i))
            }
            let ch = match char_from_u32(value) {
              Some(v) => v
              None =>
                raise ScanError::new(
                  start_mark, "while parsing a quoted scalar, found invalid Unicode character escape code",
                )
            }
            string.write_char(ch)
            for _ in 0..<code_length {
              self.skip()
            }
          }
        }
        c => {
          string.write_char(c)
          self.skip()
        }
      }
      self.lookahead(2)
    }
    self.lookahead(1)
    match self.ch() {
      '\'' if single => break
      '"' if !single => break
      _ => ()
    }

    // Consume blank characters.
    while is_blank(self.ch()) || is_break(self.ch()) {
      if is_blank(self.ch()) {
        // Consume a space or a tab character.
        if leading_blanks {
          self.skip()
        } else {
          whitespaces.write_char(self.ch())
          self.skip()
        }
      } else {
        self.lookahead(2)
        // Check if it is a first line break.
        if leading_blanks {
          self.read_break(trailing_breaks)
        } else {
          whitespaces.reset()
          self.read_break(leading_break)
          leading_blanks = true
        }
      }
      self.lookahead(1)
    }
    // Join the whitespaces or fold line breaks.
    if leading_blanks {
      if leading_break.is_empty() {
        string.write_string(leading_break.to_string())
        string.write_string(trailing_breaks.to_string())
        trailing_breaks.reset()
        leading_break.reset()
      } else {
        if trailing_breaks.is_empty() {
          string.write_char(' ')
        } else {
          string.write_string(trailing_breaks.to_string())
          trailing_breaks.reset()
        }
        leading_break.reset()
      }
    } else {
      string.write_string(whitespaces.to_string())
      whitespaces.reset()
    }
  } // loop

  // Eat the right quote.
  self.skip()
  if single {
    Token(start_mark, TokenType::Scalar(SingleQuoted, string.to_string()))
  } else {
    Token(start_mark, TokenType::Scalar(DoubleQuoted, string.to_string()))
  }
}

///|
fn Scanner::fetch_plain_scalar(self : Scanner) -> Unit raise ScanError {
  self.save_simple_key()
  self.disallow_simple_key()
  let tok = self.scan_plain_scalar()
  self.push_token(tok)
}

///|
fn Scanner::scan_plain_scalar(self : Scanner) -> Token raise ScanError {
  let indent = self.indent + 1
  let start_mark = self.mark
  let string = StringBuilder()
  let leading_break = StringBuilder()
  let trailing_breaks = StringBuilder()
  let whitespaces = StringBuilder()
  let mut leading_blanks = false
  while true {
    // Check for a document indicator.
    self.lookahead(4)
    if self.mark.col == 0 &&
      (
        (self.buf(0) == '-' && self.buf(1) == '-' && self.buf(2) == '-') ||
        (self.buf(0) == '.' && self.buf(1) == '.' && self.buf(2) == '.')
      ) &&
      is_blankz(self.buf(3)) {
      break
    }
    if self.ch() == '#' {
      break
    }
    while !is_blankz(self.ch()) {
      // indicators can end a plain scalar, see 7.3.3. Plain Style
      match self.ch() {
        ':' if is_blankz(self.buf(1)) ||
          (self.flow_level > 0 && is_flow(self.buf(1))) => break
        ',' | '[' | ']' | '{' | '}' if self.flow_level > 0 => break
        _ => ()
      }
      if leading_blanks || !whitespaces.is_empty() {
        if leading_blanks {
          if leading_break.is_empty() {
            string.write_string(leading_break.to_string())
            string.write_string(trailing_breaks.to_string())
            trailing_breaks.reset()
            leading_break.reset()
          } else {
            if trailing_breaks.is_empty() {
              string.write_char(' ')
            } else {
              string.write_string(trailing_breaks.to_string())
              trailing_breaks.reset()
            }
            leading_break.reset()
          }
          leading_blanks = false
        } else {
          string.write_string(whitespaces.to_string())
          whitespaces.reset()
        }
      }
      string.write_char(self.ch())
      self.skip()
      self.lookahead(2)
    }
    // is the end?
    if !(is_blank(self.ch()) || is_break(self.ch())) {
      break
    }
    self.lookahead(1)
    while is_blank(self.ch()) || is_break(self.ch()) {
      if is_blank(self.ch()) {
        if leading_blanks && self.mark.col < indent && self.ch() == '\t' {
          raise ScanError::new(
            start_mark, "while scanning a plain scalar, found a tab",
          )
        }
        if leading_blanks {
          self.skip()
        } else {
          whitespaces.write_char(self.ch())
          self.skip()
        }
      } else {
        self.lookahead(2)
        // Check if it is a first line break
        if leading_blanks {
          self.read_break(trailing_breaks)
        } else {
          whitespaces.reset()
          self.read_break(leading_break)
          leading_blanks = true
        }
      }
      self.lookahead(1)
    }

    // check indentation level
    if self.flow_level == 0 && self.mark.col < indent {
      break
    }
  }
  if leading_blanks {
    self.allow_simple_key()
  }
  Token(start_mark, TokenType::Scalar(Plain, string.to_string()))
}

///|
fn Scanner::fetch_key(self : Scanner) -> Unit raise ScanError {
  let start_mark = self.mark
  if self.flow_level == 0 {
    // Check if we are allowed to start a new key (not necessarily simple).
    if !self.simple_key_allowed {
      raise self.err("mapping keys are not allowed in this context")
    }
    self.roll_indent(
      start_mark.col,
      None,
      TokenType::BlockMappingStart,
      start_mark,
    )
  }
  self.remove_simple_key()
  if self.flow_level == 0 {
    self.allow_simple_key()
  } else {
    self.disallow_simple_key()
  }
  self.skip()
  self.push_token(Token(start_mark, TokenType::Key))
}

///|
fn Scanner::fetch_value(self : Scanner) -> Unit raise ScanError {
  let sk = self.simple_keys[self.simple_keys.length() - 1]
  let sk_possible = sk.possible
  let sk_mark = sk.mark
  let sk_token_number = sk.token_number
  let start_mark = self.mark
  if sk_possible {
    // insert simple key
    let tok = Token(sk_mark, TokenType::Key)
    let tokens_parsed = self.tokens_parsed
    self.insert_token(sk_token_number - tokens_parsed, tok)

    // Add the BLOCK-MAPPING-START token if needed.
    self.roll_indent(
      sk_mark.col,
      Some(sk_token_number),
      TokenType::BlockMappingStart,
      start_mark,
    )
    self.simple_keys[self.simple_keys.length() - 1].possible = false
    self.disallow_simple_key()
  } else {
    // The ':' indicator follows a complex key.
    if self.flow_level == 0 {
      if !self.simple_key_allowed {
        raise ScanError::new(
          start_mark, "mapping values are not allowed in this context",
        )
      }
      self.roll_indent(
        start_mark.col,
        None,
        TokenType::BlockMappingStart,
        start_mark,
      )
    }
    if self.flow_level == 0 {
      self.allow_simple_key()
    } else {
      self.disallow_simple_key()
    }
  }
  self.skip()
  self.push_token(Token(start_mark, TokenType::Value))
}

///|
fn Scanner::roll_indent(
  self : Scanner,
  col : Int,
  number : Int?,
  tok : TokenType,
  mark : Marker,
) -> Unit {
  if self.flow_level > 0 {
    return
  }
  if self.indent < col {
    self.indents.push(self.indent)
    self.indent = col
    let tokens_parsed = self.tokens_parsed
    match number {
      Some(n) => self.insert_token(n - tokens_parsed, Token(mark, tok))
      None => self.push_token(Token(mark, tok))
    }
  }
}

///|
fn Scanner::unroll_indent(self : Scanner, col : Int) -> Unit {
  if self.flow_level > 0 {
    return
  }
  while self.indent > col {
    self.push_token(Token(self.mark, TokenType::BlockEnd))
    self.indent = self.indents.unsafe_pop()
  }
}

///|
fn Scanner::save_simple_key(self : Scanner) -> Unit raise ScanError {
  let required = self.flow_level > 0 && self.indent == self.mark.col
  if self.simple_key_allowed {
    let sk = SimpleKey::new(self.mark)
    sk.possible = true
    sk.required = required
    sk.token_number = self.tokens_parsed + self.tokens_len()
    self.remove_simple_key()
    self.simple_keys.pop() |> ignore
    self.simple_keys.push(sk)
  }
}

///|
fn Scanner::remove_simple_key(self : Scanner) -> Unit raise ScanError {
  let last = self.simple_keys[self.simple_keys.length() - 1]
  if last.possible && last.required {
    raise self.err("simple key expected")
  }
  last.possible = false
}
