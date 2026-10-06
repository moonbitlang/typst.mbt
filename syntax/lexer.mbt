///|
/// An iterator over a source code string which returns tokens.
priv struct Lexer {
  /// The scanner: contains the underlying string and the cursor.
  s : Scanner
  /// The mode the lexer is in.
  mut mode : SyntaxMode
  /// An error plus hints for the current token being produced.
  mut error : (String, Array[String])?
}

///|
fn Lexer::new(text : String, mode : SyntaxMode) -> Lexer {
  { s: Scanner::new(text), mode, error: None, }
}

///|
fn Lexer::copy(self : Lexer) -> Lexer {
  { s: self.s.copy(), mode: self.mode, error: None, }
}

///|
/// The index at which the last token ends and the next token will start.
fn Lexer::cursor(self : Lexer) -> Int {
  self.s.cursor
}

///|
/// Change the lexing mode.
fn Lexer::set_mode(self : Lexer, mode : SyntaxMode) -> Unit {
  self.mode = mode
}

///|
/// Jump to the given index in the string.
fn Lexer::jump(self : Lexer, index : Int) -> Unit {
  self.s.jump(index)
}

///|
/// The number of characters until the most recent newline from an index.
fn Lexer::column(self : Lexer, index : Int) -> Int {
  let mut i = if index > self.s.text.length() {
    self.s.text.length()
  } else {
    index
  }
  let mut count = 0
  while i > 0 {
    let { cp: c, idx: prev, } = @unicode.decode_before(self.s.text, i)
    if is_newline(Int::unsafe_to_char(c)) {
      break
    }
    count += 1
    i = prev
  }
  count
}

///|
/// Construct a full-positioned syntax error.
fn Lexer::error(self : Lexer, message : String) -> SyntaxKind {
  self.error = Some((message, []))
  Error
}

///|
/// If the current node is an error, adds a hint.
fn Lexer::hint(self : Lexer, message : String) -> Unit {
  if self.error is Some((_, hints)) {
    hints.push(message)
  }
}

///|
/// Return the next token in our text.
fn Lexer::next(self : Lexer) -> (SyntaxKind, SyntaxNode) {
  let start = self.s.cursor
  let kind = match self.s.eat() {
    Some(c) if is_space(c, self.mode) => self.whitespace(start, c)
    Some('#') if start == 0 && self.s.eat_if_char('!') => self.shebang()
    Some('/') if self.s.eat_if_char('/') => self.line_comment()
    Some('/') if self.s.eat_if_char('*') => self.block_comment()
    Some('*') if self.s.eat_if_char('/') => {
      let error = self.error("unexpected end of block comment")
      self.hint(
        "consider escaping the `*` with a backslash or opening the block comment with `/*`",
      )
      error
    }
    Some('`') if self.mode != Math => return self.raw()
    Some(c) =>
      match self.mode {
        Markup => self.markup(start, c)
        Math =>
          match self.math(start, c) {
            (kind, None) => kind
            (kind, Some(node)) => return (kind, node)
          }
        Code => self.code(start, c)
      }
    None => End
  }
  let text = self.s.from(start)
  let node = match self.error {
    Some((message, hints)) => {
      self.error = None
      SyntaxNode::error(message, text).with_hints(hints)
    }
    None => SyntaxNode::leaf(kind, text)
  }
  (kind, node)
}

///|
/// Eat whitespace characters greedily.
fn Lexer::whitespace(self : Lexer, start : Int, c : Char) -> SyntaxKind {
  let mode = self.mode
  let more = self.s.eat_while(c => is_space(c, mode))
  let newlines = if c == ' ' && more.is_empty() {
    0
  } else {
    count_newlines(self.s.from(start))
  }
  if self.mode == Markup && newlines >= 2 {
    Parbreak
  } else if newlines > 0 {
    SpaceWithNewline
  } else {
    SpaceNoNewline
  }
}

///|
fn Lexer::shebang(self : Lexer) -> SyntaxKind {
  self.s.eat_until(is_newline) |> ignore
  Shebang
}

///|
fn Lexer::line_comment(self : Lexer) -> SyntaxKind {
  self.s.eat_until(is_newline) |> ignore
  LineComment
}

///|
fn Lexer::block_comment(self : Lexer) -> SyntaxKind {
  let mut state = '_'
  let mut depth = 1
  while self.s.eat() is Some(c) {
    state = match (state, c) {
      ('*', '/') => {
        depth -= 1
        if depth == 0 {
          break
        }
        '_'
      }
      ('/', '*') => {
        depth += 1
        '_'
      }
      _ => c
    }
  }
  BlockComment
}

///|
/// Lex an entire raw segment.
fn Lexer::raw(self : Lexer) -> (SyntaxKind, SyntaxNode) {
  let start = self.s.cursor - 1
  // Determine number of opening backticks.
  let mut backticks = 1
  while self.s.eat_if_char('`') {
    backticks += 1
  }
  // Special case for ``.
  if backticks == 2 {
    let nodes = [
      SyntaxNode::leaf(RawDelim, "`"),
      SyntaxNode::leaf(RawDelim, "`"),
    ]
    return (Raw, SyntaxNode::inner_owned(Raw, nodes))
  }
  // Find end of raw text.
  let mut found = 0
  while found < backticks {
    match self.s.eat() {
      Some('`') => found += 1
      Some(_) => found = 0
      None => {
        let error = SyntaxNode::error("unclosed raw text", self.s.from(start))
        return (Error, error)
      }
    }
  }
  let end = self.s.cursor
  let inner = Scanner::new(self.s.get(start + backticks, end - backticks))
  let inner_len = utf8_len(inner.text)

  // Opening delimiter.
  let delim_text = self.s.from(end - backticks)
  let nodes = [SyntaxNode::leaf(RawDelim, delim_text)]
  let mut tag : String? = None
  let mut diff_future_tag_len : Int? = None
  if backticks >= 3 {
    let (t, d) = raw_lang_tag(inner)
    tag = t
    diff_future_tag_len = d
    if t is Some(t) {
      nodes.push(SyntaxNode::leaf(RawLang, t))
    }
    blocky_raw(inner, nodes)
  } else {
    inline_raw(inner, nodes)
  }

  // Closing delimiter.
  nodes.push(SyntaxNode::leaf(RawDelim, delim_text))
  let raw = SyntaxNode::inner_owned(Raw, nodes)
  add_raw_warnings(raw, backticks, diff_future_tag_len, tag, inner_len)
  (Raw, raw)
}

///|
/// Lex the raw language tag into an optional string and return the UTF-8
/// length of the future language tag if it will differ in the next version.
fn raw_lang_tag(s : Scanner) -> (String?, Int?) {
  let start = s.cursor
  let future_tag = s.eat_until(c => @unicode.is_whitespace(c) || c == '`')
  if future_tag.is_empty() {
    return (None, None)
  }
  s.jump(start)
  let tag = if s.eat_if_pred(is_id_start) {
    s.eat_while(is_id_continue) |> ignore
    Some(s.from(start))
  } else {
    None
  }
  let future_len = utf8_len(future_tag)
  let diff = match tag {
    None => Some(future_len)
    Some(t) => if utf8_len(t) != future_len { Some(future_len) } else { None }
  }
  (tag, diff)
}

///|
fn is_all_whitespace(s : String) -> Bool {
  s.iter().all(@unicode.is_whitespace)
}

///|
/// Raw blocks parse a language tag, have smart behavior for trimming
/// whitespace in the start/end lines, and trim common leading whitespace from
/// all other lines as the "dedent".
fn blocky_raw(s : Scanner, nodes : Array[SyntaxNode]) -> Unit {
  // The lines between the backticks.
  let lines = split_newlines(s.after())

  // Determine dedent level.
  let mut dedent : Int? = None
  let consider = (line : String) => {
    let n = line.iter().take_while(@unicode.is_whitespace).count()
    dedent = match dedent {
      None => Some(n)
      Some(d) => Some(if n < d { n } else { d })
    }
  }
  for i in 1..<lines.length() {
    if !is_all_whitespace(lines[i]) {
      consider(lines[i])
    }
  }
  if lines.last() is Some(last) {
    consider(last)
  }
  let dedent = dedent.unwrap_or(0)

  // Trim whitespace from the last line.
  if lines.last() is Some(last) && is_all_whitespace(last) {
    lines.pop() |> ignore
  } else if lines.last() is Some(last) {
    if trim_end_unicode(last).has_suffix("`") {
      if last.has_suffix(" ") {
        lines[lines.length() - 1] = last.unsafe_substring(
          start=0,
          end=last.length() - 1,
        )
      }
    }
  }
  let mut prev = s.cursor
  let push_leaf = (kind : SyntaxKind) => {
    nodes.push(SyntaxNode::leaf(kind, s.from(prev)))
    prev = s.cursor
  }
  let mut idx = 0
  // Handle the first line.
  if lines.length() > 0 {
    let first_line = lines[0]
    idx = 1
    if is_all_whitespace(first_line) {
      s.jump(s.cursor + first_line.length())
    } else {
      let line_end = s.cursor + first_line.length()
      if s.eat_if_char(' ') {
        push_leaf(RawTrimmed)
      }
      s.jump(line_end)
      push_leaf(Text)
    }
  }
  // Add lines.
  for i in idx..<lines.length() {
    let line = lines[i]
    let mut offset = 0
    let mut taken = 0
    for c in line {
      if taken >= dedent {
        break
      }
      offset += c.len_utf16()
      taken += 1
    }
    scanner_eat_newline(s) |> ignore
    s.jump(s.cursor + offset)
    push_leaf(RawTrimmed)
    s.jump(s.cursor + line.length() - offset)
    push_leaf(Text)
  }
  // Add final trimmed.
  if !s.done() {
    nodes.push(SyntaxNode::leaf(RawTrimmed, s.after()))
  }
}

///|
/// Trim trailing Unicode whitespace.
fn trim_end_unicode(s : String) -> String {
  let mut end = s.length()
  while end > 0 {
    let { cp: c, idx: prev, } = @unicode.decode_before(s, end)
    if !@unicode.is_whitespace(Int::unsafe_to_char(c)) {
      break
    }
    end = prev
  }
  s.unsafe_substring(start=0, end~)
}

///|
/// Inline raw text is split on lines with non-newlines as `Text` kinds and
/// newlines as `RawTrimmed`.
fn inline_raw(s : Scanner, nodes : Array[SyntaxNode]) -> Unit {
  let mut prev = s.cursor
  while !s.done() {
    if s.at_pred(is_newline) {
      nodes.push(SyntaxNode::leaf(Text, s.from(prev)))
      prev = s.cursor
      scanner_eat_newline(s) |> ignore
      nodes.push(SyntaxNode::leaf(RawTrimmed, s.from(prev)))
      prev = s.cursor
      continue
    }
    s.eat() |> ignore
  }
  nodes.push(SyntaxNode::leaf(Text, s.from(prev)))
}

///|
/// Add warnings if the raw language tag will differ in the next version of
/// Typst or if there is a language tag but the raw text is empty.
fn add_raw_warnings(
  raw : SyntaxNode,
  backticks : Int,
  diff_future_tag_len : Int?,
  tag : String?,
  inner_len : Int,
) -> Unit {
  match diff_future_tag_len {
    Some(future_tag_len) => {
      let fs = backticks
      let fe = backticks + future_tag_len
      match tag {
        Some(tag) => {
          raw.warn_at(fs, fe, "no whitespace between language tag and raw text")
          raw.hint("currently, Typst is treating `\{tag}` as the language tag")
          raw.hint(
            "in the next version of Typst, this will change and we will treat all text until the first whitespace as the language tag",
          )
          let te = backticks + utf8_len(tag)
          raw.hint_at(
            backticks,
            te,
            "if the current behavior is correct, please add a space after `\{tag}`",
          )
          raw.hint_at(
            backticks, te, "otherwise, add a space or newline after the initial backticks",
          )
        }
        None => {
          raw.warn_at(fs, fe, "no whitespace before raw text")
          raw.hint(
            "in the next version of Typst, this text will be treated as the language tag for this element",
          )
          raw.hint("to avoid this, add a space after the initial backticks")
        }
      }
    }
    None =>
      if tag is Some(tag) && inner_len == utf8_len(tag) {
        raw.warn("empty raw text")
        raw.hint("Typst is treating `\{tag}` as the language tag")
        raw.hint_at(
          backticks,
          backticks + utf8_len(tag),
          "to treat this as text, add a space after the initial backticks",
        )
      }
  }
}

///|
fn Lexer::markup(self : Lexer, start : Int, c : Char) -> SyntaxKind {
  match c {
    '\\' => self.backslash()
    'h' if self.s.eat_if_str("ttp://") => self.link()
    'h' if self.s.eat_if_str("ttps://") => self.link()
    '<' if self.s.at_pred(is_id_continue) => self.label()
    '@' if self.s.at_pred(is_id_continue) => self.ref_marker()
    '.' if self.s.eat_if_str("..") => Shorthand
    '-' if self.s.eat_if_str("--") => Shorthand
    '-' if self.s.eat_if_char('-') => Shorthand
    '-' if self.s.eat_if_char('?') => Shorthand
    '-' if self.s.at_pred(@unicode.is_numeric) => Shorthand
    '*' if !self.in_word() => Star
    '_' if !self.in_word() => Underscore
    '#' => Hash
    '[' => LeftBracket
    ']' => RightBracket
    '\'' => SmartQuote
    '"' => SmartQuote
    '$' => Dollar
    '~' => Shorthand
    ':' => Colon
    '=' => {
      self.s.eat_while(c => c == '=') |> ignore
      if self.space_or_end() {
        HeadingMarker
      } else {
        self.text()
      }
    }
    '-' if self.space_or_end() => ListMarker
    '+' if self.space_or_end() => EnumMarker
    '/' if self.space_or_end() => TermMarker
    '0'..='9' => self.numbering(start)
    _ => self.text()
  }
}

///|
fn Lexer::backslash(self : Lexer) -> SyntaxKind {
  if self.s.eat_if_str("u{") {
    let hex = self.s.eat_while(is_ascii_alphanumeric)
    if !self.s.eat_if_char('}') {
      return self.error("unclosed Unicode escape sequence")
    }
    if parse_codepoint(hex) is None {
      return self.error("invalid Unicode codepoint: \{hex}")
    }
    return Escape
  }
  if self.s.done() || self.s.at_pred(@unicode.is_whitespace) {
    Linebreak
  } else {
    self.s.eat() |> ignore
    Escape
  }
}

///|
/// Parse hex digits (as `u32::from_str_radix(hex, 16)` + `char::from_u32`).
pub fn parse_codepoint(hex : StringView) -> Char? {
  if hex.length() == 0 {
    return None
  }
  let mut v = 0L
  for c in hex {
    let d = match c {
      '0'..='9' => c.to_int() - '0'.to_int()
      'a'..='f' => c.to_int() - 'a'.to_int() + 10
      'A'..='F' => c.to_int() - 'A'.to_int() + 10
      _ => return None
    }
    v = v * 16 + d.to_int64()
    if v > 0xFFFFFFFFL {
      return None
    }
  }
  if v > 0x10FFFFL || (v >= 0xD800L && v <= 0xDFFFL) {
    None
  } else {
    Some(Int::unsafe_to_char(v.to_int()))
  }
}

///|
fn Lexer::link(self : Lexer) -> SyntaxKind {
  let (link, balanced) = link_prefix(self.s.after())
  self.s.jump(self.s.cursor + link.length())
  if !balanced {
    return self.error(
      "automatic links cannot contain unbalanced brackets, use the `link` function instead",
    )
  }
  Link
}

///|
fn Lexer::numbering(self : Lexer, start : Int) -> SyntaxKind {
  self.s.eat_while(is_ascii_digit) |> ignore
  let read = self.s.from(start)
  if self.s.eat_if_char('.') && self.space_or_end() && fits_u64(read) {
    return EnumMarker
  }
  self.text()
}

///|
/// Whether a string of ASCII digits parses as a `u64`.
fn fits_u64(digits : String) -> Bool {
  if digits.is_empty() {
    return false
  }
  let max = "18446744073709551615"
  let mut i = 0
  while i < digits.length() - 1 && digits.code_unit_at(i) == '0' {
    i += 1
  }
  let trimmed = digits.unsafe_substring(start=i, end=digits.length())
  if trimmed.length() != max.length() {
    trimmed.length() < max.length()
  } else {
    trimmed <= max
  }
}

///|
fn Lexer::ref_marker(self : Lexer) -> SyntaxKind {
  self.s.eat_while(is_valid_in_label_literal) |> ignore
  // Don't include the trailing characters likely to be part of text.
  while self.s.scout(-1) is Some('.' | ':') {
    self.s.uneat()
  }
  RefMarker
}

///|
fn Lexer::label(self : Lexer) -> SyntaxKind {
  let label = self.s.eat_while(is_valid_in_label_literal)
  if label.is_empty() {
    return self.error("label cannot be empty")
  }
  if !self.s.eat_if_char('>') {
    return self.error("unclosed label")
  }
  Label
}

///|
fn is_markup_text_stop(c : Char) -> Bool {
  match c {
    ' '
    | '\t'
    | '\n'
    | '\u{0B}'
    | '\u{0C}'
    | '\r'
    | '\\'
    | '/'
    | '['
    | ']'
    | '~'
    | '-'
    | '.'
    | '\''
    | '"'
    | '*'
    | '_'
    | ':'
    | 'h'
    | '`'
    | '$'
    | '<'
    | '>'
    | '@'
    | '#' => true
    _ => c.to_int() >= 128 && @unicode.is_whitespace(c)
  }
}

///|
fn Lexer::text(self : Lexer) -> SyntaxKind {
  while true {
    self.s.eat_until(is_markup_text_stop) |> ignore
    // Continue with the same text node if the thing would become text anyway.
    let s = self.s.copy()
    let cont = match s.eat() {
      Some(' ') => s.at_pred(@unicode.is_alphanumeric)
      Some('/') => !s.at_char('/') && !s.at_char('*')
      Some('-') => !s.at_char('-') && !s.at_char('?')
      Some('.') => !s.at_str("..")
      Some('h') => !s.at_str("ttp://") && !s.at_str("ttps://")
      Some('@') => !s.at_pred(is_valid_in_label_literal)
      _ => false
    }
    if !cont {
      break
    }
    self.s.cursor = s.cursor
  }
  Text
}

///|
fn Lexer::in_word(self : Lexer) -> Bool {
  let wordy = (c : Char?) => {
    match c {
      Some(c) => @unicode.is_alphanumeric(c) && !@unicode.is_cjk_script(c)
      None => false
    }
  }
  let prev = self.s.scout(-2)
  let next = self.s.peek()
  wordy(prev) && wordy(next)
}

///|
fn Lexer::space_or_end(self : Lexer) -> Bool {
  self.s.done() ||
  self.s.at_pred(@unicode.is_whitespace) ||
  self.s.at_str("//") ||
  self.s.at_str("/*")
}

///|
fn Lexer::math(
  self : Lexer,
  start : Int,
  c : Char,
) -> (SyntaxKind, SyntaxNode?) {
  let s = self.s
  let kind = match c {
    '\\' => self.backslash()
    '"' => self.string()
    '-' if s.eat_if_str(">>") => MathShorthand
    '-' if s.eat_if_char('>') => MathShorthand
    '-' if s.eat_if_str("->") => MathShorthand
    ':' if s.eat_if_char('=') => MathShorthand
    ':' if s.eat_if_str(":=") => MathShorthand
    '!' if s.eat_if_char('=') => MathShorthand
    '.' if s.eat_if_str("..") => MathShorthand
    '<' if s.eat_if_str("==>") => MathShorthand
    '<' if s.eat_if_str("-->") => MathShorthand
    '<' if s.eat_if_str("--") => MathShorthand
    '<' if s.eat_if_str("-<") => MathShorthand
    '<' if s.eat_if_str("->") => MathShorthand
    '<' if s.eat_if_str("<-") => MathShorthand
    '<' if s.eat_if_str("<<") => MathShorthand
    '<' if s.eat_if_str("=>") => MathShorthand
    '<' if s.eat_if_str("==") => MathShorthand
    '<' if s.eat_if_str("~~") => MathShorthand
    '<' if s.eat_if_char('=') => MathShorthand
    '<' if s.eat_if_char('<') => MathShorthand
    '<' if s.eat_if_char('-') => MathShorthand
    '<' if s.eat_if_char('~') => MathShorthand
    '>' if s.eat_if_str("->") => MathShorthand
    '>' if s.eat_if_str(">>") => MathShorthand
    '=' if s.eat_if_str("=>") => MathShorthand
    '=' if s.eat_if_char('>') => MathShorthand
    '=' if s.eat_if_char(':') => MathShorthand
    '>' if s.eat_if_char('=') => MathShorthand
    '>' if s.eat_if_char('>') => MathShorthand
    '|' if s.eat_if_str("->") => MathShorthand
    '|' if s.eat_if_str("=>") => MathShorthand
    '|' if s.eat_if_char('|') => MathShorthand
    '~' if s.eat_if_str("~>") => MathShorthand
    '~' if s.eat_if_char('>') => MathShorthand
    '*' | '-' | '~' => MathShorthand
    '.' => Dot
    ',' => Comma
    ';' => Semicolon
    '#' => Hash
    '_' => Underscore
    '$' => Dollar
    '/' => Slash
    '^' => Hat
    '&' => MathAlignPoint
    '√' | '∛' | '∜' => Root
    '!' => Bang
    '\'' => {
      s.eat_while(c => c == '\'') |> ignore
      MathPrimes
    }
    '(' => LeftParen
    ')' => RightParen
    '[' if s.eat_if_char('|') => LeftBrace
    '|' if s.eat_if_char(']') => RightBrace
    c if @unicode.default_math_class(c) is Some(Opening) => LeftBrace
    c if @unicode.default_math_class(c) is Some(Closing) => RightBrace
    // Identifiers.
    c if is_math_id_start(c) && s.at_pred(is_math_id_continue) => {
      s.eat_while(is_math_id_continue) |> ignore
      let text = s.from(start)
      if @unicode.grapheme_end(text, 0) >= text.length() {
        // If this was just a single grapheme.
        MathText
      } else {
        let (kind, node) = self.math_ident_or_field(start)
        return (kind, Some(node))
      }
    }
    // Other math atoms.
    _ => self.math_text(start, c)
  }
  (kind, None)
}

///|
/// Parse a single `MathIdent` or an entire `MathFieldAccess`.
fn Lexer::math_ident_or_field(
  self : Lexer,
  start : Int,
) -> (SyntaxKind, SyntaxNode) {
  let mut kind = MathIdent
  let mut node = SyntaxNode::leaf(kind, self.s.from(start))
  while self.maybe_dot_ident() is Some(ident) {
    kind = MathFieldAccess
    let children = [
      node,
      SyntaxNode::leaf(Dot, "."),
      SyntaxNode::leaf(MathIdent, ident),
    ]
    node = SyntaxNode::inner_owned(kind, children)
  }
  (kind, node)
}

///|
/// If at a dot and a math identifier, eat and return the identifier.
fn Lexer::maybe_dot_ident(self : Lexer) -> String? {
  if self.s.scout(1) is Some(c) &&
    is_math_id_start(c) &&
    self.s.eat_if_char('.') {
    let ident_start = self.s.cursor
    self.s.eat() |> ignore
    self.s.eat_while(is_math_id_continue) |> ignore
    Some(self.s.from(ident_start))
  } else {
    None
  }
}

///|
fn Lexer::math_text(self : Lexer, start : Int, c : Char) -> SyntaxKind {
  // Keep numbers and grapheme clusters together.
  if @unicode.is_numeric(c) {
    self.s.eat_while(@unicode.is_numeric) |> ignore
    let s = self.s.copy()
    if s.eat_if_char('.') && !s.eat_while(@unicode.is_numeric).is_empty() {
      self.s.cursor = s.cursor
    }
  } else {
    let end = @unicode.grapheme_end(self.s.text, start)
    self.s.jump(end)
  }
  MathText
}

///|
/// Handle named arguments in math function call.
fn Lexer::maybe_math_named_arg(self : Lexer, start : Int) -> SyntaxNode? {
  let cursor = self.s.cursor
  self.s.jump(start)
  if self.s.eat_if_pred(is_id_start) {
    self.s.eat_while(is_id_continue) |> ignore
    // Check that a colon directly follows the identifier, and not the `:=`
    // or `::=` math shorthands.
    if self.s.at_char(':') && !self.s.at_str(":=") && !self.s.at_str("::=") {
      let text = self.s.from(start)
      let node = if text != "_" {
        SyntaxNode::leaf(Ident, text)
      } else {
        SyntaxNode::error("expected identifier, found underscore", text)
      }
      return Some(node)
    }
  }
  self.s.jump(cursor)
  None
}

///|
/// Handle spread arguments in math function call.
fn Lexer::maybe_math_spread_arg(self : Lexer, start : Int) -> SyntaxNode? {
  let cursor = self.s.cursor
  self.s.jump(start)
  if self.s.eat_if_str("..") {
    if !self.space_or_end() &&
      !self.s.at_pred(c => c is ('.' | ',' | ';' | ')' | '$')) {
      return Some(SyntaxNode::leaf(Dots, self.s.from(start)))
    }
  }
  self.s.jump(cursor)
  None
}

///|
fn Lexer::code(self : Lexer, start : Int, c : Char) -> SyntaxKind {
  let s = self.s
  match c {
    '<' if s.at_pred(is_id_continue) => self.label()
    '0'..='9' => self.number(start, c)
    '.' if s.at_pred(is_ascii_digit) => self.number(start, c)
    '"' => self.string()
    '=' if s.eat_if_char('=') => EqEq
    '!' if s.eat_if_char('=') => ExclEq
    '<' if s.eat_if_char('=') => LtEq
    '>' if s.eat_if_char('=') => GtEq
    '+' if s.eat_if_char('=') => PlusEq
    '-' | '\u{2212}' if s.eat_if_char('=') => HyphEq
    '*' if s.eat_if_char('=') => StarEq
    '/' if s.eat_if_char('=') => SlashEq
    '.' if s.eat_if_char('.') => Dots
    '=' if s.eat_if_char('>') => Arrow
    '{' => LeftBrace
    '}' => RightBrace
    '[' => LeftBracket
    ']' => RightBracket
    '(' => LeftParen
    ')' => RightParen
    '$' => Dollar
    ',' => Comma
    ';' => Semicolon
    ':' => Colon
    '.' => Dot
    '+' => Plus
    '-' | '\u{2212}' => Minus
    '*' => Star
    '/' => Slash
    '=' => Eq
    '<' => Lt
    '>' => Gt
    c if is_id_start(c) => self.ident(start)
    c => self.invalid_char_in_code(c)
  }
}

///|
/// Error for an invalid character in code, with hints for commonly confused
/// operators.
fn Lexer::invalid_char_in_code(self : Lexer, c : Char) -> SyntaxKind {
  let invalid_char = "the character `\{c}` is not valid in code"
  let invalid_str = (s : String) => "`\{s}` is not valid in code"
  if self.s.scout(-2) is Some('#') {
    self.error(invalid_char) |> ignore
    self.hint("the preceding hash is causing this to parse in code mode")
    self.hint("try escaping the preceding hash: `\\#`")
  } else {
    match c {
      '#' => {
        self.error(invalid_char) |> ignore
        self.hint("you are already in code mode")
        self.hint("try removing the `#`")
      }
      '&' if self.s.eat_if_char('&') => {
        self.error(invalid_str("&&")) |> ignore
        self.hint("in Typst, `and` is used for logical AND")
      }
      '|' if self.s.eat_if_char('|') => {
        self.error(invalid_str("||")) |> ignore
        self.hint("in Typst, `or` is used for logical OR")
      }
      '!' => {
        self.error(invalid_char) |> ignore
        self.hint("in Typst, `not` is used for negation")
        self.hint("or did you mean to write `!=` for not-equal?")
      }
      '~' if self.s.eat_if_char('=') => {
        self.error(invalid_str("~=")) |> ignore
        self.hint("in Typst, `!=` is used for not-equal")
      }
      _ => self.error(invalid_char) |> ignore
    }
  }
  Error
}

///|
fn Lexer::ident(self : Lexer, start : Int) -> SyntaxKind {
  self.s.eat_while(is_id_continue) |> ignore
  let ident = self.s.from(start)
  // Look at the (ASCII) characters before the identifier without copying.
  let text = self.s.text
  let unit_at = (i : Int) => {
    if i >= 0 {
      text.code_unit_at(i).to_int()
    } else {
      -1
    }
  }
  let p1 = unit_at(start - 1)
  let p2 = unit_at(start - 2)
  if !(p1 == '.' || p1 == '@') || (p1 == '.' && p2 == '.') {
    if keyword(ident) is Some(kw) {
      return kw
    }
  }
  if ident == "_" {
    Underscore
  } else {
    Ident
  }
}

///|
/// The numeric base of a non-decimal integer literal.
pub(all) enum NonDecimalBase {
  Hex
  Octal
  Binary
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NonDecimalBase with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NonDecimalBase with @debug.Debug::{to_repr}

///|
/// The value of the base.
pub fn NonDecimalBase::get(self : NonDecimalBase) -> Int {
  match self {
    Hex => 16
    Octal => 8
    Binary => 2
  }
}

///|
/// The name of the non-decimal base.
pub fn NonDecimalBase::name(self : NonDecimalBase) -> String {
  match self {
    Hex => "hexadecimal"
    Octal => "octal"
    Binary => "binary"
  }
}

///|
/// Errors of Rust's `i64::from_str_radix`.
// Like `core::num::IntErrorKind`, of which upstream only reads `Empty`
// (typst-syntax/src/lexer.rs:1020).
#warnings("-unused_constructor")
priv enum IntParseError {
  Empty
  InvalidDigit
  Overflow
}

///|
/// Parse an integer like Rust's `i64::from_str_radix`.
fn parse_i64_radix(s : StringView, radix : Int) -> Result[Int64, IntParseError] {
  if s.length() == 0 {
    return Err(Empty)
  }
  let mut i = 0
  let mut neg = false
  match s.get_char(0) {
    Some('+') => i = 1
    Some('-') => {
      i = 1
      neg = true
    }
    _ => ()
  }
  if i == s.length() {
    return Err(InvalidDigit)
  }
  let mut v = 0L
  let r = radix.to_int64()
  let mut overflow = false
  while i < s.length() {
    let c = s.code_unit_at(i).to_int()
    let d = if c >= '0' && c <= '9' {
      c - '0'
    } else if c >= 'a' && c <= 'z' {
      c - 'a' + 10
    } else if c >= 'A' && c <= 'Z' {
      c - 'A' + 10
    } else {
      99
    }
    if d >= radix {
      return Err(InvalidDigit)
    }
    if !overflow {
      let d = d.to_int64()
      if neg {
        if v < (@int64.MIN_VALUE + d) / r {
          overflow = true
        } else {
          v = v * r - d
        }
      } else if v > (@int64.MAX_VALUE - d) / r {
        overflow = true
      } else {
        v = v * r + d
      }
    }
    i += 1
  }
  if overflow {
    Err(Overflow)
  } else {
    Ok(v)
  }
}

///|
/// Lex a single number, either an integer or a float, possibly with a numeric
/// suffix.
fn Lexer::number(self : Lexer, start : Int, first_c : Char) -> SyntaxKind {
  let s = self.s
  // Handle alternative integer bases.
  let base : NonDecimalBase? = if first_c == '0' && s.eat_if_char('x') {
    Some(Hex)
  } else if first_c == '0' && s.eat_if_char('o') {
    Some(Octal)
  } else if first_c == '0' && s.eat_if_char('b') {
    Some(Binary)
  } else {
    None
  }
  // Read the initial digits.
  if base is Some(Hex) {
    s.eat_while(is_ascii_alphanumeric) |> ignore
  } else {
    s.eat_while(is_ascii_digit) |> ignore
  }
  // Read floating point digits and exponents.
  let mut is_float = false
  if base is None {
    if first_c == '.' {
      is_float = true
    } else if !s.at_str("..") &&
      !(s.scout(1) is Some(c) && is_id_start(c)) &&
      s.eat_if_char('.') {
      is_float = true
      s.eat_while(is_ascii_digit) |> ignore
    }
    // Read the exponent.
    if !s.at_str("em") && (s.eat_if_char('e') || s.eat_if_char('E')) {
      is_float = true
      (s.eat_if_char('+') || s.eat_if_char('-')) |> ignore
      s.eat_while(is_ascii_digit) |> ignore
    }
  }
  let number = s.from(start)
  let suffix = s.eat_while(c => is_ascii_alphanumeric(c) || c == '%')
  let mut suffix_result : Result[Bool, String] = match suffix {
    "" => Ok(false)
    "pt" | "mm" | "cm" | "in" | "deg" | "rad" | "em" | "fr" | "%" => Ok(true)
    _ => Err("invalid number suffix: `\{suffix}`")
  }
  let number_result : Result[Unit, String] = if is_float {
    if !is_valid_float(number) {
      Err("invalid floating point number: `\{number}`")
    } else {
      Ok(())
    }
  } else {
    match base {
      Some(non_decimal) => {
        let name = non_decimal.name()
        let digits = number.unsafe_substring(start=2, end=number.length())
        match parse_i64_radix(digits, non_decimal.get()) {
          Ok(_) if suffix.is_empty() => Ok(())
          Ok(value) => {
            if suffix_result is Ok(_) {
              suffix_result = Err(
                "try using a decimal number: `\{value}\{suffix}`",
              )
            }
            Err("\{name} numbers cannot have a suffix")
          }
          Err(Empty) => {
            let an = if non_decimal == Octal { "n" } else { "" }
            Err("expected a\{an} \{name} number")
          }
          Err(_) if suffix_result is Err(_) =>
            Err("invalid \{name} number: `\{number}`")
          Err(_) => Ok(())
        }
      }
      None => Ok(())
    }
  }
  match (number_result, suffix_result) {
    (Ok(_), Ok(false)) => if is_float { Float } else { Int }
    (Ok(_), Ok(true)) => Numeric
    (Err(number_err), Err(suffix_err)) => {
      let error = self.error(number_err)
      self.hint(suffix_err)
      error
    }
    (Ok(_), Err(msg)) | (Err(msg), Ok(_)) => self.error(msg)
  }
}

///|
/// Whether a float literal as produced by the lexer is accepted by Rust's
/// `str::parse::<f64>()`. The only failure is an exponent without digits.
fn is_valid_float(number : String) -> Bool {
  let mut i = 0
  let len = number.length()
  let mut digits = 0
  while i < len && is_ascii_digit_unit(number.code_unit_at(i)) {
    i += 1
    digits += 1
  }
  if i < len && number.code_unit_at(i) == '.' {
    i += 1
    while i < len && is_ascii_digit_unit(number.code_unit_at(i)) {
      i += 1
      digits += 1
    }
  }
  if digits == 0 {
    return false
  }
  if i < len && (number.code_unit_at(i) == 'e' || number.code_unit_at(i) == 'E') {
    i += 1
    if i < len &&
      (number.code_unit_at(i) == '+' || number.code_unit_at(i) == '-') {
      i += 1
    }
    let mut exp = 0
    while i < len && is_ascii_digit_unit(number.code_unit_at(i)) {
      i += 1
      exp += 1
    }
    if exp == 0 {
      return false
    }
  }
  i == len
}

///|
fn is_ascii_digit_unit(c : UInt16) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn Lexer::string(self : Lexer) -> SyntaxKind {
  let mut escaped = false
  self.s.eat_until(c => {
    let stop = c == '"' && !escaped
    escaped = c == '\\' && !escaped
    stop
  })
  |> ignore
  if !self.s.eat_if_char('"') {
    return self.error("unclosed string")
  }
  Str
}

///|
/// Try to parse an identifier into a keyword.
fn keyword(ident : String) -> SyntaxKind? {
  match ident {
    "none" => Some(None)
    "auto" => Some(Auto)
    "true" => Some(Bool)
    "false" => Some(Bool)
    "not" => Some(Not)
    "and" => Some(And)
    "or" => Some(Or)
    "let" => Some(Let)
    "set" => Some(Set)
    "show" => Some(Show)
    "context" => Some(Context)
    "if" => Some(If)
    "else" => Some(Else)
    "for" => Some(For)
    "in" => Some(In)
    "while" => Some(While)
    "break" => Some(Break)
    "continue" => Some(Continue)
    "return" => Some(Return)
    "import" => Some(Import)
    "include" => Some(Include)
    "as" => Some(As)
    _ => None
  }
}

///|
/// Eat a newline (treating `\r\n` as one).
fn scanner_eat_newline(s : Scanner) -> Bool {
  let ate = s.eat_if_pred(is_newline)
  if ate && s.text.code_unit_at(s.cursor - 1) == '\r' {
    s.eat_if_char('\n') |> ignore
  }
  ate
}

///|
/// Whether a character will become a space token.
fn is_space(c : Char, mode : SyntaxMode) -> Bool {
  match mode {
    Markup => c == ' ' || c == '\t' || is_newline(c)
    _ => @unicode.is_whitespace(c)
  }
}

///|
/// Whether a character is interpreted as a newline by Typst.
pub fn is_newline(c : Char) -> Bool {
  c
  is ('\n' | '\u{0B}' | '\u{0C}' | '\r' | '\u{0085}' | '\u{2028}' | '\u{2029}')
}

///|
/// Extracts a prefix of the text that is a link and also returns whether the
/// parentheses and brackets in the link were balanced.
pub fn link_prefix(text : String) -> (String, Bool) {
  let s = Scanner::new(text)
  let brackets : Array[Char] = []
  s.eat_while(c => {
    match c {
      '0'..='9'
      | 'a'..='z'
      | 'A'..='Z'
      | '!'
      | '#'
      | '$'
      | '%'
      | '&'
      | '*'
      | '+'
      | ','
      | '-'
      | '.'
      | '/'
      | ':'
      | ';'
      | '='
      | '?'
      | '@'
      | '_'
      | '~'
      | '\'' => true
      '[' => {
        brackets.push('[')
        true
      }
      '(' => {
        brackets.push('(')
        true
      }
      ']' => brackets.pop() is Some('[')
      ')' => brackets.pop() is Some('(')
      _ => false
    }
  })
  |> ignore
  // Don't include the trailing characters likely to be part of text.
  while s.scout(-1) is Some('!' | ',' | '.' | ':' | ';' | '?' | '\'') {
    s.uneat()
  }
  (s.before(), brackets.is_empty())
}

///|
/// Split text at newlines. These newline characters are not kept.
pub fn split_newlines(text : String) -> Array[String] {
  let s = Scanner::new(text)
  let lines = []
  let mut start = 0
  let mut end = 0
  while s.eat() is Some(c) {
    if is_newline(c) {
      if c == '\r' {
        s.eat_if_char('\n') |> ignore
      }
      lines.push(text.unsafe_substring(start~, end~))
      start = s.cursor
    }
    end = s.cursor
  }
  lines.push(text.unsafe_substring(start~, end=text.length()))
  lines
}

///|
/// Count the number of newlines in text.
fn count_newlines(text : String) -> Int {
  let s = Scanner::new(text)
  let mut newlines = 0
  while s.eat() is Some(c) {
    if is_newline(c) {
      if c == '\r' {
        s.eat_if_char('\n') |> ignore
      }
      newlines += 1
    }
  }
  newlines
}

///|
/// Whether a string is a valid Typst identifier.
pub fn is_ident(string : StringView) -> Bool {
  let mut first = true
  for c in string {
    if first {
      if !is_id_start(c) {
        return false
      }
      first = false
    } else if !is_id_continue(c) {
      return false
    }
  }
  !first
}

///|
/// Whether a character can start an identifier.
pub fn is_id_start(c : Char) -> Bool {
  @unicode.is_xid_start(c) || c == '_'
}

///|
/// Whether a character can continue an identifier.
pub fn is_id_continue(c : Char) -> Bool {
  @unicode.is_xid_continue(c) || c == '_' || c == '-'
}

///|
/// Whether a character can start an identifier in math.
fn is_math_id_start(c : Char) -> Bool {
  @unicode.is_xid_start(c)
}

///|
/// Whether a character can continue an identifier in math.
fn is_math_id_continue(c : Char) -> Bool {
  @unicode.is_xid_continue(c) && c != '_'
}

///|
/// Whether a character can be part of a label literal's name.
fn is_valid_in_label_literal(c : Char) -> Bool {
  is_id_continue(c) || c == ':' || c == '.'
}

///|
/// Returns true if this string is valid in a label literal.
pub fn is_valid_label_literal_id(id : StringView) -> Bool {
  id.length() > 0 && id.iter().all(is_valid_in_label_literal)
}

///|
fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_ascii_alphanumeric(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}
