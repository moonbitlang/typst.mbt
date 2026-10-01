// Port of `unsafe-libyaml` 0.2.11 `parser.rs` (libyaml's parser) and of the
// event conversion in `serde_yaml::libyaml::parser`.

///|
/// A parsing event with its start mark (the only mark serde_yaml uses).
priv struct Event {
  data : EventData
  start_mark : Mark
}

///|
/// `PEEK_TOKEN`.
fn Parser::peek_token(self : Parser) -> Token raise Fail {
  if !self.token_available {
    self.fetch_more_tokens()
  }
  self.tokens[self.tokens_head]
}

///|
/// `SKIP_TOKEN`.
fn Parser::skip_token(self : Parser) -> Unit {
  self.token_available = false
  self.tokens_parsed += 1
  self.stream_end_produced = self.tokens[self.tokens_head].data is StreamEnd
  self.tokens_head += 1
  if self.tokens_head == self.tokens.length() {
    self.tokens.clear()
    self.tokens_head = 0
  }
}

///|
/// `serde_yaml::libyaml::parser::Parser::next`: the next event or the
/// parser's error.
fn Parser::next(self : Parser) -> Result[Event, LibyamlError] {
  if self.error != NoError {
    return Err(self.parse_error())
  }
  if self.stream_end_produced || self.state == EndState {
    // `YAML_NO_EVENT`, which serde_yaml never asks for.
    abort("unreachable")
  }
  try self.state_machine() catch {
    Fail => Err(self.parse_error())
  } noraise {
    event => Ok(event)
  }
}

///|
/// `yaml_parser_set_parser_error`.
fn Parser::set_parser_error(
  self : Parser,
  problem : String,
  problem_mark : Mark,
) -> Fail {
  self.error = ParserError
  self.problem = problem
  self.problem_mark = problem_mark
  Fail
}

///|
/// `yaml_parser_set_parser_error_context`.
fn Parser::set_parser_error_context(
  self : Parser,
  context : String,
  context_mark : Mark,
  problem : String,
  problem_mark : Mark,
) -> Fail {
  self.error = ParserError
  self.context = Some(context)
  self.context_mark = context_mark
  self.problem = problem
  self.problem_mark = problem_mark
  Fail
}

///|
/// `yaml_parser_state_machine`.
fn Parser::state_machine(self : Parser) -> Event raise Fail {
  match self.state {
    StreamStartState => self.parse_stream_start()
    ImplicitDocumentStartState => self.parse_document_start(true)
    DocumentStartState => self.parse_document_start(false)
    DocumentContentState => self.parse_document_content()
    DocumentEndState => self.parse_document_end()
    BlockNodeState => self.parse_node(true, false)
    BlockSequenceFirstEntryState => self.parse_block_sequence_entry(true)
    BlockSequenceEntryState => self.parse_block_sequence_entry(false)
    IndentlessSequenceEntryState => self.parse_indentless_sequence_entry()
    BlockMappingFirstKeyState => self.parse_block_mapping_key(true)
    BlockMappingKeyState => self.parse_block_mapping_key(false)
    BlockMappingValueState => self.parse_block_mapping_value()
    FlowSequenceFirstEntryState => self.parse_flow_sequence_entry(true)
    FlowSequenceEntryState => self.parse_flow_sequence_entry(false)
    FlowSequenceEntryMappingKeyState =>
      self.parse_flow_sequence_entry_mapping_key()
    FlowSequenceEntryMappingValueState =>
      self.parse_flow_sequence_entry_mapping_value()
    FlowSequenceEntryMappingEndState =>
      self.parse_flow_sequence_entry_mapping_end()
    FlowMappingFirstKeyState => self.parse_flow_mapping_key(true)
    FlowMappingKeyState => self.parse_flow_mapping_key(false)
    FlowMappingValueState => self.parse_flow_mapping_value(false)
    FlowMappingEmptyValueState => self.parse_flow_mapping_value(true)
    EndState => raise Fail
  }
}

///|
/// `POP!(parser.states)`.
fn Parser::pop_state(self : Parser) -> ParserState {
  self.states.pop().unwrap()
}

///|
/// `POP!(parser.marks)`.
fn Parser::pop_mark(self : Parser) -> Mark {
  self.marks.pop().unwrap()
}

///|
/// `yaml_parser_parse_stream_start`.
fn Parser::parse_stream_start(self : Parser) -> Event raise Fail {
  let token = self.peek_token()
  if !(token.data is StreamStart) {
    raise self.set_parser_error(
      "did not find expected <stream-start>",
      token.start_mark,
    )
  }
  self.state = ImplicitDocumentStartState
  self.skip_token()
  { data: StreamStartEvent, start_mark: token.start_mark, }
}

///|
/// `yaml_parser_parse_document_start`.
fn Parser::parse_document_start(
  self : Parser,
  implicit : Bool,
) -> Event raise Fail {
  let mut token = self.peek_token()
  if !implicit {
    while token.data is DocumentEnd {
      self.skip_token()
      token = self.peek_token()
    }
  }
  if implicit &&
    !(token.data is VersionDirective(_, _)) &&
    !(token.data is TagDirective(_, _)) &&
    !(token.data is DocumentStart) &&
    !(token.data is StreamEnd) {
    self.process_directives()
    self.states.push(DocumentEndState)
    self.state = BlockNodeState
    { data: DocumentStartEvent, start_mark: token.start_mark, }
  } else if !(token.data is StreamEnd) {
    let start_mark = token.start_mark
    self.process_directives()
    let token = self.peek_token()
    if !(token.data is DocumentStart) {
      raise self.set_parser_error(
        "did not find expected <document start>",
        token.start_mark,
      )
    }
    self.states.push(DocumentEndState)
    self.state = DocumentContentState
    self.skip_token()
    { data: DocumentStartEvent, start_mark, }
  } else {
    self.state = EndState
    self.skip_token()
    { data: StreamEndEvent, start_mark: token.start_mark, }
  }
}

///|
/// `yaml_parser_parse_document_content`.
fn Parser::parse_document_content(self : Parser) -> Event raise Fail {
  let token = self.peek_token()
  match token.data {
    VersionDirective(_, _)
    | TagDirective(_, _)
    | DocumentStart
    | DocumentEnd
    | StreamEnd => {
      self.state = self.pop_state()
      process_empty_scalar(token.start_mark)
    }
    _ => self.parse_node(true, false)
  }
}

///|
/// `yaml_parser_parse_document_end`.
fn Parser::parse_document_end(self : Parser) -> Event raise Fail {
  let token = self.peek_token()
  let start_mark = token.start_mark
  if token.data is DocumentEnd {
    self.skip_token()
  }
  self.tag_directives.clear()
  self.state = DocumentStartState
  { data: DocumentEndEvent, start_mark, }
}

///|
/// `yaml_parser_parse_node`.
fn Parser::parse_node(
  self : Parser,
  block : Bool,
  indentless_sequence : Bool,
) -> Event raise Fail {
  let mut token = self.peek_token()
  if token.data is Alias(value) {
    self.state = self.pop_state()
    self.skip_token()
    return { data: AliasEvent(cstr(value)), start_mark: token.start_mark, }
  }
  let mut anchor : Bytes? = None
  let mut tag_handle : Bytes? = None
  let mut tag_suffix : Bytes = b""
  let mut tag : Bytes? = None
  let mut start_mark = token.start_mark
  let mut tag_mark = zero_mark
  if token.data is Anchor(value) {
    anchor = Some(value)
    start_mark = token.start_mark
    self.skip_token()
    token = self.peek_token()
    if token.data is Tag(handle, suffix) {
      tag_handle = Some(handle)
      tag_suffix = suffix
      tag_mark = token.start_mark
      self.skip_token()
      token = self.peek_token()
    }
  } else if token.data is Tag(handle, suffix) {
    tag_handle = Some(handle)
    tag_suffix = suffix
    tag_mark = token.start_mark
    start_mark = tag_mark
    self.skip_token()
    token = self.peek_token()
    if token.data is Anchor(value) {
      anchor = Some(value)
      self.skip_token()
      token = self.peek_token()
    }
  }
  if tag_handle is Some(handle) {
    if c_empty(handle) {
      tag = Some(cstr(tag_suffix))
    } else {
      let handle = cstr(handle)
      for tag_directive in self.tag_directives {
        if tag_directive.handle == handle {
          let buf : Array[Byte] = []
          for b in cstr(tag_directive.prefix) {
            buf.push(b)
          }
          for b in cstr(tag_suffix) {
            buf.push(b)
          }
          tag = Some(Bytes::from_array(buf))
          break
        }
      }
      if tag is None {
        raise self.set_parser_error_context(
          "while parsing a node", start_mark, "found undefined tag handle", tag_mark,
        )
      }
    }
  }
  let anchor = anchor.map(cstr)
  if indentless_sequence && token.data is BlockEntry {
    self.state = IndentlessSequenceEntryState
    return { data: SequenceStartEvent(anchor~, tag~), start_mark, }
  }
  match token.data {
    Scalar(value, style) => {
      self.state = self.pop_state()
      self.skip_token()
      { data: ScalarEvent(anchor~, tag~, value~, style~), start_mark, }
    }
    FlowSequenceStart => {
      self.state = FlowSequenceFirstEntryState
      { data: SequenceStartEvent(anchor~, tag~), start_mark, }
    }
    FlowMappingStart => {
      self.state = FlowMappingFirstKeyState
      { data: MappingStartEvent(anchor~, tag~), start_mark, }
    }
    BlockSequenceStart if block => {
      self.state = BlockSequenceFirstEntryState
      { data: SequenceStartEvent(anchor~, tag~), start_mark, }
    }
    BlockMappingStart if block => {
      self.state = BlockMappingFirstKeyState
      { data: MappingStartEvent(anchor~, tag~), start_mark, }
    }
    _ =>
      if anchor is Some(_) || tag is Some(_) {
        self.state = self.pop_state()
        {
          data: ScalarEvent(anchor~, tag~, value=b"", style=Plain),
          start_mark,
        }
      } else {
        raise self.set_parser_error_context(
          if block {
            "while parsing a block node"
          } else {
            "while parsing a flow node"
          },
          start_mark,
          "did not find expected node content",
          token.start_mark,
        )
      }
  }
}

///|
/// `yaml_parser_parse_block_sequence_entry`.
fn Parser::parse_block_sequence_entry(
  self : Parser,
  first : Bool,
) -> Event raise Fail {
  if first {
    let token = self.peek_token()
    self.marks.push(token.start_mark)
    self.skip_token()
  }
  let token = self.peek_token()
  match token.data {
    BlockEntry => {
      let mark = token.end_mark
      self.skip_token()
      let token = self.peek_token()
      if !(token.data is BlockEntry) && !(token.data is BlockEnd) {
        self.states.push(BlockSequenceEntryState)
        self.parse_node(true, false)
      } else {
        self.state = BlockSequenceEntryState
        process_empty_scalar(mark)
      }
    }
    BlockEnd => {
      self.state = self.pop_state()
      let _ = self.pop_mark()
      self.skip_token()
      { data: SequenceEndEvent, start_mark: token.start_mark, }
    }
    _ =>
      raise self.set_parser_error_context(
        "while parsing a block collection",
        self.pop_mark(),
        "did not find expected '-' indicator",
        token.start_mark,
      )
  }
}

///|
/// `yaml_parser_parse_indentless_sequence_entry`.
fn Parser::parse_indentless_sequence_entry(self : Parser) -> Event raise Fail {
  let token = self.peek_token()
  if token.data is BlockEntry {
    let mark = token.end_mark
    self.skip_token()
    let token = self.peek_token()
    match token.data {
      BlockEntry | Key | Value | BlockEnd => {
        self.state = IndentlessSequenceEntryState
        process_empty_scalar(mark)
      }
      _ => {
        self.states.push(IndentlessSequenceEntryState)
        self.parse_node(true, false)
      }
    }
  } else {
    self.state = self.pop_state()
    { data: SequenceEndEvent, start_mark: token.start_mark, }
  }
}

///|
/// `yaml_parser_parse_block_mapping_key`.
fn Parser::parse_block_mapping_key(
  self : Parser,
  first : Bool,
) -> Event raise Fail {
  if first {
    let token = self.peek_token()
    self.marks.push(token.start_mark)
    self.skip_token()
  }
  let token = self.peek_token()
  match token.data {
    Key => {
      let mark = token.end_mark
      self.skip_token()
      let token = self.peek_token()
      match token.data {
        Key | Value | BlockEnd => {
          self.state = BlockMappingValueState
          process_empty_scalar(mark)
        }
        _ => {
          self.states.push(BlockMappingValueState)
          self.parse_node(true, true)
        }
      }
    }
    BlockEnd => {
      self.state = self.pop_state()
      let _ = self.pop_mark()
      self.skip_token()
      { data: MappingEndEvent, start_mark: token.start_mark, }
    }
    _ =>
      raise self.set_parser_error_context(
        "while parsing a block mapping",
        self.pop_mark(),
        "did not find expected key",
        token.start_mark,
      )
  }
}

///|
/// `yaml_parser_parse_block_mapping_value`.
fn Parser::parse_block_mapping_value(self : Parser) -> Event raise Fail {
  let token = self.peek_token()
  if token.data is Value {
    let mark = token.end_mark
    self.skip_token()
    let token = self.peek_token()
    match token.data {
      Key | Value | BlockEnd => {
        self.state = BlockMappingKeyState
        process_empty_scalar(mark)
      }
      _ => {
        self.states.push(BlockMappingKeyState)
        self.parse_node(true, true)
      }
    }
  } else {
    self.state = BlockMappingKeyState
    process_empty_scalar(token.start_mark)
  }
}

///|
/// `yaml_parser_parse_flow_sequence_entry`.
fn Parser::parse_flow_sequence_entry(
  self : Parser,
  first : Bool,
) -> Event raise Fail {
  if first {
    let token = self.peek_token()
    self.marks.push(token.start_mark)
    self.skip_token()
  }
  let mut token = self.peek_token()
  if !(token.data is FlowSequenceEnd) {
    if !first {
      if token.data is FlowEntry {
        self.skip_token()
        token = self.peek_token()
      } else {
        raise self.set_parser_error_context(
          "while parsing a flow sequence",
          self.pop_mark(),
          "did not find expected ',' or ']'",
          token.start_mark,
        )
      }
    }
    if token.data is Key {
      self.state = FlowSequenceEntryMappingKeyState
      self.skip_token()
      return {
        data: MappingStartEvent(anchor=None, tag=None),
        start_mark: token.start_mark,
      }
    } else if !(token.data is FlowSequenceEnd) {
      self.states.push(FlowSequenceEntryState)
      return self.parse_node(false, false)
    }
  }
  self.state = self.pop_state()
  let _ = self.pop_mark()
  self.skip_token()
  { data: SequenceEndEvent, start_mark: token.start_mark, }
}

///|
/// `yaml_parser_parse_flow_sequence_entry_mapping_key`.
fn Parser::parse_flow_sequence_entry_mapping_key(
  self : Parser,
) -> Event raise Fail {
  let token = self.peek_token()
  match token.data {
    Value | FlowEntry | FlowSequenceEnd => {
      let mark = token.end_mark
      self.skip_token()
      self.state = FlowSequenceEntryMappingValueState
      process_empty_scalar(mark)
    }
    _ => {
      self.states.push(FlowSequenceEntryMappingValueState)
      self.parse_node(false, false)
    }
  }
}

///|
/// `yaml_parser_parse_flow_sequence_entry_mapping_value`.
fn Parser::parse_flow_sequence_entry_mapping_value(
  self : Parser,
) -> Event raise Fail {
  let mut token = self.peek_token()
  if token.data is Value {
    self.skip_token()
    token = self.peek_token()
    if !(token.data is FlowEntry) && !(token.data is FlowSequenceEnd) {
      self.states.push(FlowSequenceEntryMappingEndState)
      return self.parse_node(false, false)
    }
  }
  self.state = FlowSequenceEntryMappingEndState
  process_empty_scalar(token.start_mark)
}

///|
/// `yaml_parser_parse_flow_sequence_entry_mapping_end`.
fn Parser::parse_flow_sequence_entry_mapping_end(
  self : Parser,
) -> Event raise Fail {
  let token = self.peek_token()
  self.state = FlowSequenceEntryState
  { data: MappingEndEvent, start_mark: token.start_mark, }
}

///|
/// `yaml_parser_parse_flow_mapping_key`.
fn Parser::parse_flow_mapping_key(
  self : Parser,
  first : Bool,
) -> Event raise Fail {
  if first {
    let token = self.peek_token()
    self.marks.push(token.start_mark)
    self.skip_token()
  }
  let mut token = self.peek_token()
  if !(token.data is FlowMappingEnd) {
    if !first {
      if token.data is FlowEntry {
        self.skip_token()
        token = self.peek_token()
      } else {
        raise self.set_parser_error_context(
          "while parsing a flow mapping",
          self.pop_mark(),
          "did not find expected ',' or '}'",
          token.start_mark,
        )
      }
    }
    if token.data is Key {
      self.skip_token()
      token = self.peek_token()
      match token.data {
        Value | FlowEntry | FlowMappingEnd => {
          self.state = FlowMappingValueState
          return process_empty_scalar(token.start_mark)
        }
        _ => {
          self.states.push(FlowMappingValueState)
          return self.parse_node(false, false)
        }
      }
    } else if !(token.data is FlowMappingEnd) {
      self.states.push(FlowMappingEmptyValueState)
      return self.parse_node(false, false)
    }
  }
  self.state = self.pop_state()
  let _ = self.pop_mark()
  self.skip_token()
  { data: MappingEndEvent, start_mark: token.start_mark, }
}

///|
/// `yaml_parser_parse_flow_mapping_value`.
fn Parser::parse_flow_mapping_value(
  self : Parser,
  empty : Bool,
) -> Event raise Fail {
  let mut token = self.peek_token()
  if empty {
    self.state = FlowMappingKeyState
    return process_empty_scalar(token.start_mark)
  }
  if token.data is Value {
    self.skip_token()
    token = self.peek_token()
    if !(token.data is FlowEntry) && !(token.data is FlowMappingEnd) {
      self.states.push(FlowMappingKeyState)
      return self.parse_node(false, false)
    }
  }
  self.state = FlowMappingKeyState
  process_empty_scalar(token.start_mark)
}

///|
/// `yaml_parser_process_empty_scalar`.
fn process_empty_scalar(mark : Mark) -> Event {
  {
    data: ScalarEvent(anchor=None, tag=None, value=b"", style=Plain),
    start_mark: mark,
  }
}

///|
/// `yaml_parser_process_directives` (the version and tag directives of the
/// document are not needed by serde_yaml, only their validation).
fn Parser::process_directives(self : Parser) -> Unit raise Fail {
  let mut has_version_directive = false
  let mut token = self.peek_token()
  while true {
    match token.data {
      VersionDirective(major, minor) =>
        if has_version_directive {
          raise self.set_parser_error(
            "found duplicate %YAML directive",
            token.start_mark,
          )
        } else if major != 1 || (minor != 1 && minor != 2) {
          raise self.set_parser_error(
            "found incompatible YAML document",
            token.start_mark,
          )
        } else {
          has_version_directive = true
        }
      TagDirective(handle, prefix) =>
        self.append_tag_directive({ handle, prefix, }, false, token.start_mark)
      _ => break
    }
    self.skip_token()
    token = self.peek_token()
  }
  let default_tag_directives : Array[TagDirective] = [
    { handle: b"!", prefix: b"!", },
    { handle: b"!!", prefix: b"tag:yaml.org,2002:", },
  ]
  for default_tag_directive in default_tag_directives {
    self.append_tag_directive(default_tag_directive, true, token.start_mark)
  }
}

///|
/// `yaml_parser_append_tag_directive`.
fn Parser::append_tag_directive(
  self : Parser,
  value : TagDirective,
  allow_duplicates : Bool,
  mark : Mark,
) -> Unit raise Fail {
  let handle = cstr(value.handle)
  for tag_directive in self.tag_directives {
    if tag_directive.handle == handle {
      if allow_duplicates {
        return
      }
      raise self.set_parser_error("found duplicate %TAG directive", mark)
    }
  }
  self.tag_directives.push({ handle, prefix: cstr(value.prefix), })
}
