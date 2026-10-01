// Port of `unsafe-libyaml` 0.2.11 `scanner.rs` (libyaml's scanner).

///|
/// `yaml_parser_set_scanner_error`.
fn Parser::set_scanner_error(
  self : Parser,
  context : String?,
  context_mark : Mark,
  problem : String,
) -> Fail {
  self.error = ScannerError
  self.context = context
  self.context_mark = context_mark
  self.problem = problem
  self.problem_mark = self.mark()
  Fail
}

///|
/// `ENQUEUE` on the token queue.
fn Parser::enqueue(
  self : Parser,
  data : TokenData,
  start : Mark,
  end : Mark,
) -> Unit {
  self.tokens.push({ data, start_mark: start, end_mark: end, })
}

///|
/// `yaml_parser_fetch_more_tokens`.
fn Parser::fetch_more_tokens(self : Parser) -> Unit raise Fail {
  while true {
    let mut need_more_tokens = false
    if self.tokens_head == self.tokens.length() {
      need_more_tokens = true
    } else {
      self.stale_simple_keys()
      for i in self.not_simple_keys..<self.simple_keys.length() {
        let simple_key = self.simple_keys[i]
        if simple_key.possible && simple_key.token_number == self.tokens_parsed {
          need_more_tokens = true
          break
        }
      }
    }
    if !need_more_tokens {
      break
    }
    self.fetch_next_token()
  }
  self.token_available = true
}

///|
/// `yaml_parser_fetch_next_token`.
fn Parser::fetch_next_token(self : Parser) -> Unit raise Fail {
  self.cache(1)
  if !self.stream_start_produced {
    self.fetch_stream_start()
    return
  }
  self.scan_to_next_token()
  self.stale_simple_keys()
  self.unroll_indent(self.mark_column)
  self.cache(4)
  if self.is_z_at(0) {
    return self.fetch_stream_end()
  }
  if self.mark_column == 0 && self.check('%') {
    return self.fetch_directive()
  }
  if self.mark_column == 0 &&
    self.check_at('-', 0) &&
    self.check_at('-', 1) &&
    self.check_at('-', 2) &&
    self.is_blankz_at(3) {
    return self.fetch_document_indicator(DocumentStart)
  }
  if self.mark_column == 0 &&
    self.check_at('.', 0) &&
    self.check_at('.', 1) &&
    self.check_at('.', 2) &&
    self.is_blankz_at(3) {
    return self.fetch_document_indicator(DocumentEnd)
  }
  if self.check('[') {
    return self.fetch_flow_collection_start(FlowSequenceStart)
  }
  if self.check('{') {
    return self.fetch_flow_collection_start(FlowMappingStart)
  }
  if self.check(']') {
    return self.fetch_flow_collection_end(FlowSequenceEnd)
  }
  if self.check('}') {
    return self.fetch_flow_collection_end(FlowMappingEnd)
  }
  if self.check(',') {
    return self.fetch_flow_entry()
  }
  if self.check('-') && self.is_blankz_at(1) {
    return self.fetch_block_entry()
  }
  if self.check('?') && (self.flow_level != 0 || self.is_blankz_at(1)) {
    return self.fetch_key()
  }
  if self.check(':') && (self.flow_level != 0 || self.is_blankz_at(1)) {
    return self.fetch_value()
  }
  if self.check('*') {
    return self.fetch_anchor(false)
  }
  if self.check('&') {
    return self.fetch_anchor(true)
  }
  if self.check('!') {
    return self.fetch_tag()
  }
  if self.check('|') && self.flow_level == 0 {
    return self.fetch_block_scalar(true)
  }
  if self.check('>') && self.flow_level == 0 {
    return self.fetch_block_scalar(false)
  }
  if self.check('\'') {
    return self.fetch_flow_scalar(true)
  }
  if self.check('"') {
    return self.fetch_flow_scalar(false)
  }
  let c = self.at(0)
  if !(self.is_blankz_at(0) ||
    c == '-' ||
    c == '?' ||
    c == ':' ||
    c == ',' ||
    c == '[' ||
    c == ']' ||
    c == '{' ||
    c == '}' ||
    c == '#' ||
    c == '&' ||
    c == '*' ||
    c == '!' ||
    c == '|' ||
    c == '>' ||
    c == '\'' ||
    c == '"' ||
    c == '%' ||
    c == '@' ||
    c == '`') ||
    (c == '-' && !self.is_blank_at(1)) ||
    (self.flow_level == 0 && (c == '?' || c == ':') && !self.is_blankz_at(1)) {
    return self.fetch_plain_scalar()
  }
  raise self.set_scanner_error(
    Some("while scanning for the next token"),
    self.mark(),
    "found character that cannot start any token",
  )
}

///|
/// `yaml_parser_stale_simple_keys`.
fn Parser::stale_simple_keys(self : Parser) -> Unit raise Fail {
  let start = self.not_simple_keys
  for i in start..<self.simple_keys.length() {
    let simple_key = self.simple_keys[i]
    if simple_key.possible &&
      (
        simple_key.mark.line < self.mark_line ||
        simple_key.mark.index + 1024 < self.mark_index
      ) {
      if simple_key.required {
        raise self.set_scanner_error(
          Some("while scanning a simple key"),
          simple_key.mark,
          "could not find expected ':'",
        )
      }
      simple_key.possible = false
      if self.not_simple_keys == i {
        self.not_simple_keys += 1
      }
    }
  }
}

///|
/// `yaml_parser_save_simple_key`.
fn Parser::save_simple_key(self : Parser) -> Unit raise Fail {
  let required = self.flow_level == 0 && self.indent == self.mark_column
  if self.simple_key_allowed {
    let token_number = self.tokens_parsed +
      (self.tokens.length() - self.tokens_head)
    let mark = self.mark()
    self.remove_simple_key()
    let top = self.simple_keys[self.simple_keys.length() - 1]
    top.possible = true
    top.required = required
    top.token_number = token_number
    top.mark = mark
    if self.not_simple_keys == self.simple_keys.length() {
      self.not_simple_keys -= 1
    }
  }
}

///|
/// `yaml_parser_remove_simple_key`.
fn Parser::remove_simple_key(self : Parser) -> Unit raise Fail {
  let simple_key = self.simple_keys[self.simple_keys.length() - 1]
  if simple_key.possible {
    if simple_key.required {
      raise self.set_scanner_error(
        Some("while scanning a simple key"),
        simple_key.mark,
        "could not find expected ':'",
      )
    }
  }
  simple_key.possible = false
}

///|
/// `yaml_parser_increase_flow_level`.
fn Parser::increase_flow_level(self : Parser) -> Unit {
  self.simple_keys.push({
    possible: false,
    required: false,
    token_number: 0,
    mark: zero_mark,
  })
  self.flow_level += 1
}

///|
/// `yaml_parser_decrease_flow_level`.
fn Parser::decrease_flow_level(self : Parser) -> Unit {
  if self.flow_level != 0 {
    self.flow_level -= 1
    if self.not_simple_keys == self.simple_keys.length() {
      self.not_simple_keys -= 1
    }
    let _ = self.simple_keys.pop()
  }
}

///|
/// `yaml_parser_roll_indent`. `number` is -1 to append the token, otherwise
/// the token number before which it is inserted.
fn Parser::roll_indent(
  self : Parser,
  column : Int,
  number : Int,
  data : TokenData,
  mark : Mark,
) -> Unit {
  if self.flow_level != 0 {
    return
  }
  if self.indent < column {
    self.indents.push(self.indent)
    self.indent = column
    let token = { data, start_mark: mark, end_mark: mark, }
    if number == -1 {
      self.tokens.push(token)
    } else {
      self.tokens.insert(
        self.tokens_head + (number - self.tokens_parsed),
        token,
      )
    }
  }
}

///|
/// `yaml_parser_unroll_indent`.
fn Parser::unroll_indent(self : Parser, column : Int) -> Unit {
  if self.flow_level != 0 {
    return
  }
  while self.indent > column {
    self.enqueue(BlockEnd, self.mark(), self.mark())
    self.indent = self.indents.pop().unwrap()
  }
}

///|
/// `yaml_parser_fetch_stream_start`.
fn Parser::fetch_stream_start(self : Parser) -> Unit {
  self.indent = -1
  self.simple_keys.push({
    possible: false,
    required: false,
    token_number: 0,
    mark: zero_mark,
  })
  self.not_simple_keys = 1
  self.simple_key_allowed = true
  self.stream_start_produced = true
  self.enqueue(StreamStart, self.mark(), self.mark())
}

///|
/// `yaml_parser_fetch_stream_end`.
fn Parser::fetch_stream_end(self : Parser) -> Unit raise Fail {
  if self.mark_column != 0 {
    self.mark_column = 0
    self.mark_line += 1
  }
  self.unroll_indent(-1)
  self.remove_simple_key()
  self.simple_key_allowed = false
  self.enqueue(StreamEnd, self.mark(), self.mark())
}

///|
/// `yaml_parser_fetch_directive`.
fn Parser::fetch_directive(self : Parser) -> Unit raise Fail {
  self.unroll_indent(-1)
  self.remove_simple_key()
  self.simple_key_allowed = false
  let token = self.scan_directive()
  self.tokens.push(token)
}

///|
/// `yaml_parser_fetch_document_indicator`.
fn Parser::fetch_document_indicator(
  self : Parser,
  data : TokenData,
) -> Unit raise Fail {
  self.unroll_indent(-1)
  self.remove_simple_key()
  self.simple_key_allowed = false
  let start_mark = self.mark()
  self.skip()
  self.skip()
  self.skip()
  let end_mark = self.mark()
  self.enqueue(data, start_mark, end_mark)
}

///|
/// `yaml_parser_fetch_flow_collection_start`.
fn Parser::fetch_flow_collection_start(
  self : Parser,
  data : TokenData,
) -> Unit raise Fail {
  self.save_simple_key()
  self.increase_flow_level()
  self.simple_key_allowed = true
  let start_mark = self.mark()
  self.skip()
  let end_mark = self.mark()
  self.enqueue(data, start_mark, end_mark)
}

///|
/// `yaml_parser_fetch_flow_collection_end`.
fn Parser::fetch_flow_collection_end(
  self : Parser,
  data : TokenData,
) -> Unit raise Fail {
  self.remove_simple_key()
  self.decrease_flow_level()
  self.simple_key_allowed = false
  let start_mark = self.mark()
  self.skip()
  let end_mark = self.mark()
  self.enqueue(data, start_mark, end_mark)
}

///|
/// `yaml_parser_fetch_flow_entry`.
fn Parser::fetch_flow_entry(self : Parser) -> Unit raise Fail {
  self.remove_simple_key()
  self.simple_key_allowed = true
  let start_mark = self.mark()
  self.skip()
  let end_mark = self.mark()
  self.enqueue(FlowEntry, start_mark, end_mark)
}

///|
/// `yaml_parser_fetch_block_entry`.
fn Parser::fetch_block_entry(self : Parser) -> Unit raise Fail {
  if self.flow_level == 0 {
    if !self.simple_key_allowed {
      raise self.set_scanner_error(
        None,
        self.mark(),
        "block sequence entries are not allowed in this context",
      )
    }
    self.roll_indent(self.mark_column, -1, BlockSequenceStart, self.mark())
  }
  self.remove_simple_key()
  self.simple_key_allowed = true
  let start_mark = self.mark()
  self.skip()
  let end_mark = self.mark()
  self.enqueue(BlockEntry, start_mark, end_mark)
}

///|
/// `yaml_parser_fetch_key`.
fn Parser::fetch_key(self : Parser) -> Unit raise Fail {
  if self.flow_level == 0 {
    if !self.simple_key_allowed {
      raise self.set_scanner_error(
        None,
        self.mark(),
        "mapping keys are not allowed in this context",
      )
    }
    self.roll_indent(self.mark_column, -1, BlockMappingStart, self.mark())
  }
  self.remove_simple_key()
  self.simple_key_allowed = self.flow_level == 0
  let start_mark = self.mark()
  self.skip()
  let end_mark = self.mark()
  self.enqueue(Key, start_mark, end_mark)
}

///|
/// `yaml_parser_fetch_value`.
fn Parser::fetch_value(self : Parser) -> Unit raise Fail {
  let simple_key = self.simple_keys[self.simple_keys.length() - 1]
  if simple_key.possible {
    self.tokens.insert(
      self.tokens_head + (simple_key.token_number - self.tokens_parsed),
      { data: Key, start_mark: simple_key.mark, end_mark: simple_key.mark, },
    )
    self.roll_indent(
      simple_key.mark.column,
      simple_key.token_number,
      BlockMappingStart,
      simple_key.mark,
    )
    simple_key.possible = false
    self.simple_key_allowed = false
  } else {
    if self.flow_level == 0 {
      if !self.simple_key_allowed {
        raise self.set_scanner_error(
          None,
          self.mark(),
          "mapping values are not allowed in this context",
        )
      }
      self.roll_indent(self.mark_column, -1, BlockMappingStart, self.mark())
    }
    self.simple_key_allowed = self.flow_level == 0
  }
  let start_mark = self.mark()
  self.skip()
  let end_mark = self.mark()
  self.enqueue(Value, start_mark, end_mark)
}

///|
/// `yaml_parser_fetch_anchor` (`anchor` selects anchor vs. alias).
fn Parser::fetch_anchor(self : Parser, anchor : Bool) -> Unit raise Fail {
  self.save_simple_key()
  self.simple_key_allowed = false
  let token = self.scan_anchor(anchor)
  self.tokens.push(token)
}

///|
/// `yaml_parser_fetch_tag`.
fn Parser::fetch_tag(self : Parser) -> Unit raise Fail {
  self.save_simple_key()
  self.simple_key_allowed = false
  let token = self.scan_tag()
  self.tokens.push(token)
}

///|
/// `yaml_parser_fetch_block_scalar`.
fn Parser::fetch_block_scalar(self : Parser, literal : Bool) -> Unit raise Fail {
  self.remove_simple_key()
  self.simple_key_allowed = true
  let token = self.scan_block_scalar(literal)
  self.tokens.push(token)
}

///|
/// `yaml_parser_fetch_flow_scalar`.
fn Parser::fetch_flow_scalar(self : Parser, single : Bool) -> Unit raise Fail {
  self.save_simple_key()
  self.simple_key_allowed = false
  let token = self.scan_flow_scalar(single)
  self.tokens.push(token)
}

///|
/// `yaml_parser_fetch_plain_scalar`.
fn Parser::fetch_plain_scalar(self : Parser) -> Unit raise Fail {
  self.save_simple_key()
  self.simple_key_allowed = false
  let token = self.scan_plain_scalar()
  self.tokens.push(token)
}

///|
/// `yaml_parser_scan_to_next_token`.
fn Parser::scan_to_next_token(self : Parser) -> Unit raise Fail {
  while true {
    self.cache(1)
    if self.mark_column == 0 && self.is_bom() {
      self.skip()
    }
    self.cache(1)
    while self.check(' ') ||
          (
            (self.flow_level != 0 || !self.simple_key_allowed) &&
            self.check('\t')
          ) {
      self.skip()
      self.cache(1)
    }
    if self.check('#') {
      while !self.is_breakz_at(0) {
        self.skip()
        self.cache(1)
      }
    }
    if !self.is_break_at(0) {
      break
    }
    self.cache(2)
    self.skip_line()
    if self.flow_level == 0 {
      self.simple_key_allowed = true
    }
  }
}

///|
/// `yaml_parser_scan_directive`.
fn Parser::scan_directive(self : Parser) -> Token raise Fail {
  let start_mark = self.mark()
  self.skip()
  let name = self.scan_directive_name(start_mark)
  let token = if name == b"YAML" {
    let (major, minor) = self.scan_version_directive_value(start_mark)
    { data: VersionDirective(major, minor), start_mark, end_mark: self.mark(), }
  } else if name == b"TAG" {
    let (handle, prefix) = self.scan_tag_directive_value(start_mark)
    { data: TagDirective(handle, prefix), start_mark, end_mark: self.mark(), }
  } else {
    raise self.set_scanner_error(
      Some("while scanning a directive"),
      start_mark,
      "found unknown directive name",
    )
  }
  self.cache(1)
  while self.is_blank_at(0) {
    self.skip()
    self.cache(1)
  }
  if self.check('#') {
    while !self.is_breakz_at(0) {
      self.skip()
      self.cache(1)
    }
  }
  if !self.is_breakz_at(0) {
    raise self.set_scanner_error(
      Some("while scanning a directive"),
      start_mark,
      "did not find expected comment or line break",
    )
  }
  if self.is_break_at(0) {
    self.cache(2)
    self.skip_line()
  }
  token
}

///|
/// `yaml_parser_scan_directive_name`.
fn Parser::scan_directive_name(
  self : Parser,
  start_mark : Mark,
) -> Bytes raise Fail {
  let string : Array[Byte] = []
  self.cache(1)
  while self.is_alpha() {
    self.read(string)
    self.cache(1)
  }
  if string.is_empty() {
    raise self.set_scanner_error(
      Some("while scanning a directive"),
      start_mark,
      "could not find expected directive name",
    )
  } else if !self.is_blankz_at(0) {
    raise self.set_scanner_error(
      Some("while scanning a directive"),
      start_mark,
      "found unexpected non-alphabetical character",
    )
  }
  Bytes::from_array(string)
}

///|
/// `yaml_parser_scan_version_directive_value`.
fn Parser::scan_version_directive_value(
  self : Parser,
  start_mark : Mark,
) -> (Int, Int) raise Fail {
  self.cache(1)
  while self.is_blank_at(0) {
    self.skip()
    self.cache(1)
  }
  let major = self.scan_version_directive_number(start_mark)
  if !self.check('.') {
    raise self.set_scanner_error(
      Some("while scanning a %YAML directive"),
      start_mark,
      "did not find expected digit or '.' character",
    )
  }
  self.skip()
  let minor = self.scan_version_directive_number(start_mark)
  (major, minor)
}

///|
/// `MAX_NUMBER_LENGTH`.
const MAX_NUMBER_LENGTH : Int = 9

///|
/// `yaml_parser_scan_version_directive_number`.
fn Parser::scan_version_directive_number(
  self : Parser,
  start_mark : Mark,
) -> Int raise Fail {
  let mut value = 0
  let mut length = 0
  self.cache(1)
  while self.is_digit() {
    length += 1
    if length > MAX_NUMBER_LENGTH {
      raise self.set_scanner_error(
        Some("while scanning a %YAML directive"),
        start_mark,
        "found extremely long version number",
      )
    }
    value = value * 10 + (self.at(0) - '0')
    self.skip()
    self.cache(1)
  }
  if length == 0 {
    raise self.set_scanner_error(
      Some("while scanning a %YAML directive"),
      start_mark,
      "did not find expected version number",
    )
  }
  value
}

///|
/// `yaml_parser_scan_tag_directive_value`.
fn Parser::scan_tag_directive_value(
  self : Parser,
  start_mark : Mark,
) -> (Bytes, Bytes) raise Fail {
  self.cache(1)
  while true {
    if self.is_blank_at(0) {
      self.skip()
      self.cache(1)
      continue
    }
    let handle = self.scan_tag_handle(true, start_mark)
    self.cache(1)
    if !self.is_blank_at(0) {
      raise self.set_scanner_error(
        Some("while scanning a %TAG directive"),
        start_mark,
        "did not find expected whitespace",
      )
    }
    while self.is_blank_at(0) {
      self.skip()
      self.cache(1)
    }
    let prefix = self.scan_tag_uri(true, true, None, start_mark)
    self.cache(1)
    if !self.is_blankz_at(0) {
      raise self.set_scanner_error(
        Some("while scanning a %TAG directive"),
        start_mark,
        "did not find expected whitespace or line break",
      )
    }
    return (handle, prefix)
  }
  abort("unreachable")
}

///|
/// `yaml_parser_scan_anchor` (`anchor` selects anchor vs. alias).
fn Parser::scan_anchor(self : Parser, anchor : Bool) -> Token raise Fail {
  let string : Array[Byte] = []
  let start_mark = self.mark()
  self.skip()
  self.cache(1)
  let mut length = 0
  while self.is_alpha() {
    self.read(string)
    self.cache(1)
    length += 1
  }
  let end_mark = self.mark()
  let c = self.at(0)
  if length == 0 ||
    !(self.is_blankz_at(0) ||
    c == '?' ||
    c == ':' ||
    c == ',' ||
    c == ']' ||
    c == '}' ||
    c == '%' ||
    c == '@' ||
    c == '`') {
    raise self.set_scanner_error(
      Some(
        if anchor {
          "while scanning an anchor"
        } else {
          "while scanning an alias"
        },
      ),
      start_mark,
      "did not find expected alphabetic or numeric character",
    )
  }
  let value = Bytes::from_array(string)
  {
    data: if anchor {
      Anchor(value)
    } else {
      Alias(value)
    },
    start_mark,
    end_mark,
  }
}

///|
/// Whether a C string is empty (its first byte is NUL).
fn c_empty(b : Bytes) -> Bool {
  b.length() == 0 || b[0] == b'\x00'
}

///|
/// `yaml_parser_scan_tag`.
fn Parser::scan_tag(self : Parser) -> Token raise Fail {
  let start_mark = self.mark()
  self.cache(2)
  let mut handle : Bytes = b""
  let mut suffix : Bytes = b""
  if self.check_at('<', 1) {
    handle = b""
    self.skip()
    self.skip()
    suffix = self.scan_tag_uri(true, false, None, start_mark)
    if !self.check('>') {
      raise self.set_scanner_error(
        Some("while scanning a tag"),
        start_mark,
        "did not find the expected '>'",
      )
    }
    self.skip()
  } else {
    handle = self.scan_tag_handle(false, start_mark)
    if handle[0] == b'!' &&
      handle.length() >= 2 &&
      handle[handle.length() - 1] == b'!' {
      suffix = self.scan_tag_uri(false, false, None, start_mark)
    } else {
      suffix = self.scan_tag_uri(false, false, Some(handle), start_mark)
      handle = b"!"
      if c_empty(suffix) {
        let tmp = handle
        handle = suffix
        suffix = tmp
      }
    }
  }
  self.cache(1)
  if !self.is_blankz_at(0) {
    if self.flow_level == 0 || !self.check(',') {
      raise self.set_scanner_error(
        Some("while scanning a tag"),
        start_mark,
        "did not find expected whitespace or line break",
      )
    }
  }
  let end_mark = self.mark()
  { data: Tag(handle, suffix), start_mark, end_mark, }
}

///|
/// `yaml_parser_scan_tag_handle`.
fn Parser::scan_tag_handle(
  self : Parser,
  directive : Bool,
  start_mark : Mark,
) -> Bytes raise Fail {
  let string : Array[Byte] = []
  self.cache(1)
  if !self.check('!') {
    raise self.set_scanner_error(
      Some(
        if directive {
          "while scanning a tag directive"
        } else {
          "while scanning a tag"
        },
      ),
      start_mark,
      "did not find expected '!'",
    )
  }
  self.read(string)
  self.cache(1)
  while self.is_alpha() {
    self.read(string)
    self.cache(1)
  }
  if self.check('!') {
    self.read(string)
  } else if directive && !(string.length() == 1 && string[0] == b'!') {
    raise self.set_scanner_error(
      Some("while parsing a tag directive"),
      start_mark,
      "did not find expected '!'",
    )
  }
  Bytes::from_array(string)
}

///|
/// `yaml_parser_scan_tag_uri`.
fn Parser::scan_tag_uri(
  self : Parser,
  uri_char : Bool,
  directive : Bool,
  head : Bytes?,
  start_mark : Mark,
) -> Bytes raise Fail {
  let mut length = match head {
    Some(h) => cstr(h).length()
    None => 0
  }
  let string : Array[Byte] = []
  if length > 1 {
    let h = head.unwrap()
    for i in 1..<length {
      string.push(h[i])
    }
  }
  self.cache(1)
  while true {
    let c = self.at(0)
    if !(self.is_alpha() ||
      c == ';' ||
      c == '/' ||
      c == '?' ||
      c == ':' ||
      c == '@' ||
      c == '&' ||
      c == '=' ||
      c == '+' ||
      c == '$' ||
      c == '.' ||
      c == '%' ||
      c == '!' ||
      c == '~' ||
      c == '*' ||
      c == '\'' ||
      c == '(' ||
      c == ')' ||
      (uri_char && (c == ',' || c == '[' || c == ']'))) {
      break
    }
    if c == '%' {
      self.scan_uri_escapes(directive, start_mark, string)
    } else {
      self.read(string)
    }
    length += 1
    self.cache(1)
  }
  if length == 0 {
    raise self.set_scanner_error(
      Some(
        if directive {
          "while parsing a %TAG directive"
        } else {
          "while parsing a tag"
        },
      ),
      start_mark,
      "did not find expected tag URI",
    )
  }
  Bytes::from_array(string)
}

///|
/// `yaml_parser_scan_uri_escapes`.
fn Parser::scan_uri_escapes(
  self : Parser,
  directive : Bool,
  start_mark : Mark,
  string : Array[Byte],
) -> Unit raise Fail {
  let context = if directive {
    "while parsing a %TAG directive"
  } else {
    "while parsing a tag"
  }
  let mut width = 0
  while true {
    self.cache(3)
    if !(self.check('%') && self.is_hex_at(1) && self.is_hex_at(2)) {
      raise self.set_scanner_error(
        Some(context),
        start_mark,
        "did not find URI escaped octet",
      )
    }
    let octet = (self.as_hex_at(1) << 4) + self.as_hex_at(2)
    if width == 0 {
      width = if (octet & 0x80) == 0 {
        1
      } else if (octet & 0xE0) == 0xC0 {
        2
      } else if (octet & 0xF0) == 0xE0 {
        3
      } else if (octet & 0xF8) == 0xF0 {
        4
      } else {
        0
      }
      if width == 0 {
        raise self.set_scanner_error(
          Some(context),
          start_mark,
          "found an incorrect leading UTF-8 octet",
        )
      }
    } else if (octet & 0xC0) != 0x80 {
      raise self.set_scanner_error(
        Some(context),
        start_mark,
        "found an incorrect trailing UTF-8 octet",
      )
    }
    string.push(octet.to_byte())
    self.skip()
    self.skip()
    self.skip()
    width -= 1
    if width == 0 {
      break
    }
  }
}

///|
/// Appends `b` to `a` and clears `b` (`JOIN` followed by `CLEAR`).
fn join_clear(a : Array[Byte], b : Array[Byte]) -> Unit {
  a.append(b)
  b.clear()
}

///|
/// `yaml_parser_scan_block_scalar`.
fn Parser::scan_block_scalar(self : Parser, literal : Bool) -> Token raise Fail {
  let string : Array[Byte] = []
  let leading_break : Array[Byte] = []
  let trailing_breaks : Array[Byte] = []
  let mut chomping = 0
  let mut increment = 0
  let mut indent = 0
  let mut leading_blank = false
  let start_mark = self.mark()
  self.skip()
  self.cache(1)
  if self.check('+') || self.check('-') {
    chomping = if self.check('+') { 1 } else { -1 }
    self.skip()
    self.cache(1)
    if self.is_digit() {
      if self.check('0') {
        raise self.set_scanner_error(
          Some("while scanning a block scalar"),
          start_mark,
          "found an indentation indicator equal to 0",
        )
      }
      increment = self.at(0) - '0'
      self.skip()
    }
  } else if self.is_digit() {
    if self.check('0') {
      raise self.set_scanner_error(
        Some("while scanning a block scalar"),
        start_mark,
        "found an indentation indicator equal to 0",
      )
    }
    increment = self.at(0) - '0'
    self.skip()
    self.cache(1)
    if self.check('+') || self.check('-') {
      chomping = if self.check('+') { 1 } else { -1 }
      self.skip()
    }
  }
  self.cache(1)
  while self.is_blank_at(0) {
    self.skip()
    self.cache(1)
  }
  if self.check('#') {
    while !self.is_breakz_at(0) {
      self.skip()
      self.cache(1)
    }
  }
  if !self.is_breakz_at(0) {
    raise self.set_scanner_error(
      Some("while scanning a block scalar"),
      start_mark,
      "did not find expected comment or line break",
    )
  }
  if self.is_break_at(0) {
    self.cache(2)
    self.skip_line()
  }
  let mut end_mark = self.mark()
  if increment != 0 {
    indent = if self.indent >= 0 { self.indent + increment } else { increment }
  }
  let (new_indent, new_end) = self.scan_block_scalar_breaks(
    indent, trailing_breaks, start_mark, end_mark,
  )
  indent = new_indent
  end_mark = new_end
  self.cache(1)
  while self.mark_column == indent && !self.is_z_at(0) {
    let trailing_blank = self.is_blank_at(0)
    if !literal &&
      leading_break.length() > 0 &&
      leading_break[0] == b'\n' &&
      !leading_blank &&
      !trailing_blank {
      if trailing_breaks.is_empty() {
        string.push(b' ')
      }
      leading_break.clear()
    } else {
      join_clear(string, leading_break)
    }
    join_clear(string, trailing_breaks)
    leading_blank = self.is_blank_at(0)
    while !self.is_breakz_at(0) {
      self.read(string)
      self.cache(1)
    }
    self.cache(2)
    self.read_line(leading_break)
    let (new_indent, new_end) = self.scan_block_scalar_breaks(
      indent, trailing_breaks, start_mark, end_mark,
    )
    indent = new_indent
    end_mark = new_end
  }
  if chomping != -1 {
    string.append(leading_break)
  }
  if chomping == 1 {
    string.append(trailing_breaks)
  }
  {
    data: Scalar(
      Bytes::from_array(string),
      if literal {
        Literal
      } else {
        Folded
      },
    ),
    start_mark,
    end_mark,
  }
}

///|
/// `yaml_parser_scan_block_scalar_breaks`; returns the updated indentation
/// and end mark.
fn Parser::scan_block_scalar_breaks(
  self : Parser,
  indent : Int,
  breaks : Array[Byte],
  start_mark : Mark,
  end_mark : Mark,
) -> (Int, Mark) raise Fail {
  let mut indent = indent
  let mut end_mark = end_mark
  let mut max_indent = 0
  end_mark = self.mark()
  while true {
    self.cache(1)
    while (indent == 0 || self.mark_column < indent) && self.is_space_at(0) {
      self.skip()
      self.cache(1)
    }
    if self.mark_column > max_indent {
      max_indent = self.mark_column
    }
    if (indent == 0 || self.mark_column < indent) && self.is_tab_at(0) {
      raise self.set_scanner_error(
        Some("while scanning a block scalar"),
        start_mark,
        "found a tab character where an indentation space is expected",
      )
    }
    if !self.is_break_at(0) {
      break
    }
    self.cache(2)
    self.read_line(breaks)
    end_mark = self.mark()
  }
  if indent == 0 {
    indent = max_indent
    if indent < self.indent + 1 {
      indent = self.indent + 1
    }
    if indent < 1 {
      indent = 1
    }
  }
  (indent, end_mark)
}

///|
/// Pushes the UTF-8 encoding of `value` (`value <= 0x10FFFF`).
fn push_utf8(string : Array[Byte], value : Int) -> Unit {
  if value <= 0x7F {
    string.push(value.to_byte())
  } else if value <= 0x7FF {
    string.push((0xC0 + (value >> 6)).to_byte())
    string.push((0x80 + (value & 0x3F)).to_byte())
  } else if value <= 0xFFFF {
    string.push((0xE0 + (value >> 12)).to_byte())
    string.push((0x80 + ((value >> 6) & 0x3F)).to_byte())
    string.push((0x80 + (value & 0x3F)).to_byte())
  } else {
    string.push((0xF0 + (value >> 18)).to_byte())
    string.push((0x80 + ((value >> 12) & 0x3F)).to_byte())
    string.push((0x80 + ((value >> 6) & 0x3F)).to_byte())
    string.push((0x80 + (value & 0x3F)).to_byte())
  }
}

///|
/// `yaml_parser_scan_flow_scalar`.
fn Parser::scan_flow_scalar(self : Parser, single : Bool) -> Token raise Fail {
  let string : Array[Byte] = []
  let leading_break : Array[Byte] = []
  let trailing_breaks : Array[Byte] = []
  let whitespaces : Array[Byte] = []
  let quote : Int = if single { '\'' } else { '"' }
  let start_mark = self.mark()
  self.skip()
  while true {
    self.cache(4)
    if self.mark_column == 0 &&
      (
        (
          self.check_at('-', 0) &&
          self.check_at('-', 1) &&
          self.check_at('-', 2)
        ) ||
        (
          self.check_at('.', 0) &&
          self.check_at('.', 1) &&
          self.check_at('.', 2)
        )
      ) &&
      self.is_blankz_at(3) {
      raise self.set_scanner_error(
        Some("while scanning a quoted scalar"),
        start_mark,
        "found unexpected document indicator",
      )
    } else if self.is_z_at(0) {
      raise self.set_scanner_error(
        Some("while scanning a quoted scalar"),
        start_mark,
        "found unexpected end of stream",
      )
    }
    self.cache(2)
    let mut leading_blanks = false
    while !self.is_blankz_at(0) {
      if single && self.check_at('\'', 0) && self.check_at('\'', 1) {
        string.push(b'\'')
        self.skip()
        self.skip()
      } else {
        if self.check(quote) {
          break
        }
        if !single && self.check('\\') && self.is_break_at(1) {
          self.cache(3)
          self.skip()
          self.skip_line()
          leading_blanks = true
          break
        } else if !single && self.check('\\') {
          let mut code_length = 0
          match self.at(1) {
            '0' => string.push(b'\x00')
            'a' => string.push(b'\x07')
            'b' => string.push(b'\x08')
            't' | '\t' => string.push(b'\t')
            'n' => string.push(b'\n')
            'v' => string.push(b'\x0B')
            'f' => string.push(b'\x0C')
            'r' => string.push(b'\r')
            'e' => string.push(b'\x1B')
            ' ' => string.push(b' ')
            '"' => string.push(b'"')
            '/' => string.push(b'/')
            '\\' => string.push(b'\\')
            // NEL (#x85)
            'N' => {
              string.push(b'\xC2')
              string.push(b'\x85')
            }
            // #xA0
            '_' => {
              string.push(b'\xC2')
              string.push(b'\xA0')
            }
            // LS (#x2028)
            'L' => {
              string.push(b'\xE2')
              string.push(b'\x80')
              string.push(b'\xA8')
            }
            // PS (#x2029)
            'P' => {
              string.push(b'\xE2')
              string.push(b'\x80')
              string.push(b'\xA9')
            }
            'x' => code_length = 2
            'u' => code_length = 4
            'U' => code_length = 8
            _ =>
              raise self.set_scanner_error(
                Some("while parsing a quoted scalar"),
                start_mark,
                "found unknown escape character",
              )
          }
          self.skip()
          self.skip()
          if code_length != 0 {
            self.cache(code_length)
            let mut value : UInt = 0
            for k in 0..<code_length {
              if !self.is_hex_at(k) {
                raise self.set_scanner_error(
                  Some("while parsing a quoted scalar"),
                  start_mark,
                  "did not find expected hexadecimal number",
                )
              }
              value = (value << 4) + self.as_hex_at(k).reinterpret_as_uint()
            }
            if (value >= 0xD800U && value <= 0xDFFFU) || value > 0x10FFFFU {
              raise self.set_scanner_error(
                Some("while parsing a quoted scalar"),
                start_mark,
                "found invalid Unicode character escape code",
              )
            }
            push_utf8(string, value.reinterpret_as_int())
            for _ in 0..<code_length {
              self.skip()
            }
          }
        } else {
          self.read(string)
        }
      }
      self.cache(2)
    }
    self.cache(1)
    if self.check(quote) {
      break
    }
    self.cache(1)
    while self.is_blank_at(0) || self.is_break_at(0) {
      if self.is_blank_at(0) {
        if !leading_blanks {
          self.read(whitespaces)
        } else {
          self.skip()
        }
      } else {
        self.cache(2)
        if !leading_blanks {
          whitespaces.clear()
          self.read_line(leading_break)
          leading_blanks = true
        } else {
          self.read_line(trailing_breaks)
        }
      }
      self.cache(1)
    }
    if leading_blanks {
      if leading_break.length() > 0 && leading_break[0] == b'\n' {
        if trailing_breaks.is_empty() {
          string.push(b' ')
        } else {
          join_clear(string, trailing_breaks)
        }
        leading_break.clear()
      } else {
        join_clear(string, leading_break)
        join_clear(string, trailing_breaks)
      }
    } else {
      join_clear(string, whitespaces)
    }
  }
  self.skip()
  let end_mark = self.mark()
  {
    data: Scalar(
      Bytes::from_array(string),
      if single {
        SingleQuoted
      } else {
        DoubleQuoted
      },
    ),
    start_mark,
    end_mark,
  }
}

///|
/// `yaml_parser_scan_plain_scalar`.
fn Parser::scan_plain_scalar(self : Parser) -> Token raise Fail {
  let string : Array[Byte] = []
  let leading_break : Array[Byte] = []
  let trailing_breaks : Array[Byte] = []
  let whitespaces : Array[Byte] = []
  let mut leading_blanks = false
  let indent = self.indent + 1
  let mut end_mark = self.mark()
  let start_mark = end_mark
  while true {
    self.cache(4)
    if self.mark_column == 0 &&
      (
        (
          self.check_at('-', 0) &&
          self.check_at('-', 1) &&
          self.check_at('-', 2)
        ) ||
        (
          self.check_at('.', 0) &&
          self.check_at('.', 1) &&
          self.check_at('.', 2)
        )
      ) &&
      self.is_blankz_at(3) {
      break
    }
    if self.check('#') {
      break
    }
    while !self.is_blankz_at(0) {
      if self.flow_level != 0 && self.check(':') {
        let n = self.at(1)
        if n == ',' || n == '?' || n == '[' || n == ']' || n == '{' || n == '}' {
          raise self.set_scanner_error(
            Some("while scanning a plain scalar"),
            start_mark,
            "found unexpected ':'",
          )
        }
      }
      let c = self.at(0)
      if (c == ':' && self.is_blankz_at(1)) ||
        (
          self.flow_level != 0 &&
          (c == ',' || c == '[' || c == ']' || c == '{' || c == '}')
        ) {
        break
      }
      if leading_blanks || !whitespaces.is_empty() {
        if leading_blanks {
          if leading_break.length() > 0 && leading_break[0] == b'\n' {
            if trailing_breaks.is_empty() {
              string.push(b' ')
            } else {
              join_clear(string, trailing_breaks)
            }
            leading_break.clear()
          } else {
            join_clear(string, leading_break)
            join_clear(string, trailing_breaks)
          }
          leading_blanks = false
        } else {
          join_clear(string, whitespaces)
        }
      }
      self.read(string)
      end_mark = self.mark()
      self.cache(2)
    }
    if !(self.is_blank_at(0) || self.is_break_at(0)) {
      break
    }
    self.cache(1)
    while self.is_blank_at(0) || self.is_break_at(0) {
      if self.is_blank_at(0) {
        if leading_blanks && self.mark_column < indent && self.is_tab_at(0) {
          raise self.set_scanner_error(
            Some("while scanning a plain scalar"),
            start_mark,
            "found a tab character that violates indentation",
          )
        } else if !leading_blanks {
          self.read(whitespaces)
        } else {
          self.skip()
        }
      } else {
        self.cache(2)
        if !leading_blanks {
          whitespaces.clear()
          self.read_line(leading_break)
          leading_blanks = true
        } else {
          self.read_line(trailing_breaks)
        }
      }
      self.cache(1)
    }
    if self.flow_level == 0 && self.mark_column < indent {
      break
    }
  }
  if leading_blanks {
    self.simple_key_allowed = true
  }
  { data: Scalar(Bytes::from_array(string), Plain), start_mark, end_mark, }
}
