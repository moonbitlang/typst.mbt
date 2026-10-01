// Data structures of `unsafe-libyaml` 0.2.11 (`yaml.rs`) used by the
// reader, scanner and parser ports.

///|
/// `yaml_error_type_t` (memory errors cannot happen here).
priv enum ErrorType {
  NoError
  ReaderError
  ScannerError
  ParserError
} derive(Eq)

///|
/// `yaml_scalar_style_t` (without `YAML_ANY_SCALAR_STYLE`, which the parser
/// never produces).
priv enum ScalarStyle {
  Plain
  SingleQuoted
  DoubleQuoted
  Literal
  Folded
} derive(Eq)

///|
/// `yaml_token_t` payloads (`yaml_token_type_t` plus `data`).
priv enum TokenData {
  StreamStart
  StreamEnd
  VersionDirective(Int, Int)
  /// Handle and prefix.
  TagDirective(Bytes, Bytes)
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
  Alias(Bytes)
  Anchor(Bytes)
  /// Handle and suffix.
  Tag(Bytes, Bytes)
  Scalar(Bytes, ScalarStyle)
}

///|
/// `yaml_token_t`.
priv struct Token {
  data : TokenData
  start_mark : Mark
  end_mark : Mark
}

///|
/// `yaml_simple_key_t`.
priv struct SimpleKey {
  mut possible : Bool
  mut required : Bool
  mut token_number : Int
  mut mark : Mark
}

///|
/// `yaml_parser_state_t` (without the states libyaml never enters,
/// `YAML_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE` and
/// `YAML_PARSE_FLOW_NODE_STATE`).
priv enum ParserState {
  StreamStartState
  ImplicitDocumentStartState
  DocumentStartState
  DocumentContentState
  DocumentEndState
  BlockNodeState
  BlockSequenceFirstEntryState
  BlockSequenceEntryState
  IndentlessSequenceEntryState
  BlockMappingFirstKeyState
  BlockMappingKeyState
  BlockMappingValueState
  FlowSequenceFirstEntryState
  FlowSequenceEntryState
  FlowSequenceEntryMappingKeyState
  FlowSequenceEntryMappingValueState
  FlowSequenceEntryMappingEndState
  FlowMappingFirstKeyState
  FlowMappingKeyState
  FlowMappingValueState
  FlowMappingEmptyValueState
  EndState
} derive(Eq)

///|
/// `yaml_event_t` payloads, converted the way
/// `serde_yaml::libyaml::parser::convert_event` does (anchors and tags as
/// C strings, i.e. cut at the first NUL byte).
priv enum EventData {
  StreamStartEvent
  StreamEndEvent
  DocumentStartEvent
  DocumentEndEvent
  AliasEvent(Bytes)
  ScalarEvent(
    anchor~ : Bytes?,
    tag~ : Bytes?,
    value~ : Bytes,
    style~ : ScalarStyle
  )
  SequenceStartEvent(anchor~ : Bytes?, tag~ : Bytes?)
  SequenceEndEvent
  MappingStartEvent(anchor~ : Bytes?, tag~ : Bytes?)
  MappingEndEvent
}

///|
/// `yaml_tag_directive_t`.
priv struct TagDirective {
  handle : Bytes
  prefix : Bytes
}

///|
/// The fail signal of libyaml functions (`Success::FAIL`); the details are
/// stored in the parser's error fields.
priv suberror Fail

///|
/// `yaml_parser_t` with the reader, scanner and parser state.
priv struct Parser {
  input : Bytes
  // Error state.
  mut error : ErrorType
  mut problem : String
  mut problem_offset : Int
  mut problem_mark : Mark
  mut context : String?
  mut context_mark : Mark
  // Reader state. The decoded buffer is `input[0..raw_pos]` (decoding
  // re-encodes valid UTF-8 unchanged), `ptr` is `buffer.pointer`.
  mut raw_pos : Int
  mut raw_last : Int
  mut eof : Bool
  mut unread : Int
  mut ptr : Int
  // Scanner state.
  mut mark_index : Int
  mut mark_line : Int
  mut mark_column : Int
  mut stream_start_produced : Bool
  mut stream_end_produced : Bool
  mut flow_level : Int
  tokens : Array[Token]
  mut tokens_head : Int
  mut tokens_parsed : Int
  mut token_available : Bool
  indents : Array[Int]
  mut indent : Int
  mut simple_key_allowed : Bool
  simple_keys : Array[SimpleKey]
  mut not_simple_keys : Int
  // Parser state.
  mut state : ParserState
  states : Array[ParserState]
  marks : Array[Mark]
  tag_directives : Array[TagDirective]
}

///|
/// `yaml_parser_initialize` + `yaml_parser_set_encoding(YAML_UTF8_ENCODING)`
/// + `yaml_parser_set_input_string`.
fn Parser::new(input : Bytes) -> Parser {
  {
    input,
    error: NoError,
    problem: "",
    problem_offset: 0,
    problem_mark: zero_mark,
    context: None,
    context_mark: zero_mark,
    raw_pos: 0,
    raw_last: 0,
    eof: false,
    unread: 0,
    ptr: 0,
    mark_index: 0,
    mark_line: 0,
    mark_column: 0,
    stream_start_produced: false,
    stream_end_produced: false,
    flow_level: 0,
    tokens: [],
    tokens_head: 0,
    tokens_parsed: 0,
    token_available: false,
    indents: [],
    indent: 0,
    simple_key_allowed: false,
    simple_keys: [],
    not_simple_keys: 0,
    state: StreamStartState,
    states: [],
    marks: [],
    tag_directives: [],
  }
}

///|
/// The current `parser.mark`.
fn Parser::mark(self : Parser) -> Mark {
  { index: self.mark_index, line: self.mark_line, column: self.mark_column, }
}

///|
/// The libyaml error stored in the parser
/// (`serde_yaml::libyaml::error::Error::parse_error`).
fn Parser::parse_error(self : Parser) -> LibyamlError {
  {
    problem: self.problem,
    problem_offset: self.problem_offset,
    problem_mark: self.problem_mark,
    context: self.context,
    context_mark: self.context_mark,
  }
}

///|
/// A C string view of a byte string: everything before the first NUL.
fn cstr(b : Bytes) -> Bytes {
  for i in 0..<b.length() {
    if b[i] == b'\x00' {
      return b[0:i].to_owned()
    }
  }
  b
}
