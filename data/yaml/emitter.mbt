// Port of `unsafe-libyaml` 0.2.11 `emitter.rs` (libyaml's emitter),
// restricted to what `serde_yaml::Serializer` produces: one implicit
// document, no anchors, aliases, tags or directives, unicode output and
// unlimited line width (`yaml_emitter_set_width(-1)`).

///|
/// `yaml_scalar_style_t` as requested by serde_yaml / chosen by the emitter.
priv enum EStyle {
  AnyStyle
  PlainStyle
  SingleQuotedStyle
  DoubleQuotedStyle
  LiteralStyle
  FoldedStyle
} derive(Eq)

///|
/// The emitter events serde_yaml produces.
priv enum EEvent {
  EStreamStart
  EDocumentStart
  EDocumentEnd
  EScalar(Bytes, EStyle)
  ESequenceStart
  ESequenceEnd
  EMappingStart
  EMappingEnd
}

///|
/// `yaml_emitter_state_t`.
priv enum EmitterState {
  EmitStreamStartState
  EmitFirstDocumentStartState
  EmitDocumentStartState
  EmitDocumentContentState
  EmitDocumentEndState
  EmitFlowSequenceFirstItemState
  EmitFlowSequenceItemState
  EmitFlowMappingFirstKeyState
  EmitFlowMappingKeyState
  EmitFlowMappingSimpleValueState
  EmitFlowMappingValueState
  EmitBlockSequenceFirstItemState
  EmitBlockSequenceItemState
  EmitBlockMappingFirstKeyState
  EmitBlockMappingKeyState
  EmitBlockMappingSimpleValueState
  EmitBlockMappingValueState
}

///|
/// `yaml_emitter_t`. The event queue holds all events; `head` is the event
/// being processed (serde_yaml's event stream always provides the lookahead
/// libyaml waits for).
priv struct Emitter {
  out : Array[Byte]
  events : Array[EEvent]
  mut head : Int
  best_indent : Int
  best_width : Int
  mut state : EmitterState
  states : Array[EmitterState]
  indents : Array[Int]
  mut indent : Int
  mut flow_level : Int
  mut mapping_context : Bool
  mut simple_key_context : Bool
  mut column : Int
  mut whitespace : Bool
  mut indention : Bool
  mut open_ended : Int
  // `scalar_data`.
  mut value : Bytes
  mut multiline : Bool
  mut flow_plain_allowed : Bool
  mut block_plain_allowed : Bool
  mut single_quoted_allowed : Bool
  mut block_allowed : Bool
  mut style : EStyle
}

///|
/// `yaml_emitter_initialize` + serde_yaml's settings.
fn Emitter::new(events : Array[EEvent]) -> Emitter {
  {
    out: [],
    events,
    head: 0,
    best_indent: 2,
    best_width: 0x7FFF_FFFF,
    state: EmitStreamStartState,
    states: [],
    indents: [],
    indent: 0,
    flow_level: 0,
    mapping_context: false,
    simple_key_context: false,
    column: 0,
    whitespace: false,
    indention: false,
    open_ended: 0,
    value: b"",
    multiline: false,
    flow_plain_allowed: false,
    block_plain_allowed: false,
    single_quoted_allowed: false,
    block_allowed: false,
    style: AnyStyle,
  }
}

///|
/// Emits all events (`yaml_emitter_emit` for each) and returns the output.
fn Emitter::run(self : Emitter) -> Bytes {
  while self.head < self.events.length() {
    let event = self.events[self.head]
    self.analyze_event(event)
    self.state_machine(event)
    self.head += 1
  }
  Bytes::from_array(self.out)
}

// Output primitives (`PUT`, `PUT_BREAK`, `WRITE`, `WRITE_BREAK`).

///|
fn Emitter::put(self : Emitter, value : Byte) -> Unit {
  self.out.push(value)
  self.column += 1
}

///|
fn Emitter::put_break(self : Emitter) -> Unit {
  self.out.push(b'\n')
  self.column = 0
}

///|
/// The byte at `i` of `s`, NUL past the end (C strings are NUL-terminated).
fn byte_at(s : Bytes, i : Int) -> Int {
  if i < s.length() {
    s[i].to_int()
  } else {
    0
  }
}

///|
/// `WIDTH_AT`.
fn width_at(s : Bytes, i : Int) -> Int {
  let c = byte_at(s, i)
  if (c & 0x80) == 0x00 {
    1
  } else if (c & 0xE0) == 0xC0 {
    2
  } else if (c & 0xF0) == 0xE0 {
    3
  } else if (c & 0xF8) == 0xF0 {
    4
  } else {
    0
  }
}

///|
/// `IS_BREAK_AT`.
fn is_break_at(s : Bytes, i : Int) -> Bool {
  let c = byte_at(s, i)
  c == '\r' ||
  c == '\n' ||
  (c == 0xC2 && byte_at(s, i + 1) == 0x85) ||
  (c == 0xE2 && byte_at(s, i + 1) == 0x80 && byte_at(s, i + 2) == 0xA8) ||
  (c == 0xE2 && byte_at(s, i + 1) == 0x80 && byte_at(s, i + 2) == 0xA9)
}

///|
/// `IS_SPACE_AT`.
fn is_space_at(s : Bytes, i : Int) -> Bool {
  byte_at(s, i) == ' '
}

///|
/// `IS_BLANKZ_AT`.
fn is_blankz_at(s : Bytes, i : Int) -> Bool {
  let c = byte_at(s, i)
  c == ' ' || c == '\t' || is_break_at(s, i) || c == 0
}

///|
/// `IS_PRINTABLE`.
fn is_printable_at(s : Bytes, i : Int) -> Bool {
  match byte_at(s, i) {
    // ASCII
    0x0A | 0x20..<=0x7E => true
    // U+A0 ... U+BF
    0xC2 => byte_at(s, i + 1) is (0xA0..<=0xBF)
    // U+C0 ... U+CFFF
    0xC3..<=0xEC => true
    // U+D000 ... U+D7FF
    0xED => byte_at(s, i + 1) is (0x00..<=0x9F)
    // U+E000 ... U+EFFF
    0xEE => true
    // U+F000 ... U+FFFD
    0xEF =>
      match byte_at(s, i + 1) {
        // except U+FEFF
        0xBB => byte_at(s, i + 2) != 0xBF
        0xBF => !(byte_at(s, i + 2) is (0xBE | 0xBF))
        _ => true
      }
    // U+10000 ... U+10FFFF
    0xF0..<=0xF4 => true
    _ => false
  }
}

///|
/// `WRITE`: copies one character of `s` at `i`; returns the next index.
fn Emitter::write(self : Emitter, s : Bytes, i : Int) -> Int {
  let width = width_at(s, i)
  for k in 0..<width {
    self.out.push(s[i + k])
  }
  self.column += 1
  i + width
}

///|
/// `WRITE_BREAK`: copies one line break of `s` at `i`; returns the next
/// index.
fn Emitter::write_break(self : Emitter, s : Bytes, i : Int) -> Int {
  if byte_at(s, i) == '\n' {
    self.put_break()
    i + 1
  } else {
    let width = width_at(s, i)
    for k in 0..<width {
      self.out.push(s[i + k])
    }
    self.column = 0
    i + width
  }
}

///|
/// `yaml_emitter_increase_indent`.
fn Emitter::increase_indent(
  self : Emitter,
  flow : Bool,
  indentless : Bool,
) -> Unit {
  self.indents.push(self.indent)
  if self.indent < 0 {
    self.indent = if flow { self.best_indent } else { 0 }
  } else if !indentless {
    self.indent += self.best_indent
  }
}

///|
fn Emitter::pop_indent(self : Emitter) -> Unit {
  self.indent = self.indents.pop().unwrap()
}

///|
fn Emitter::pop_state(self : Emitter) -> Unit {
  self.state = self.states.pop().unwrap()
}

///|
/// `yaml_emitter_state_machine`.
fn Emitter::state_machine(self : Emitter, event : EEvent) -> Unit {
  match self.state {
    EmitStreamStartState => self.emit_stream_start(event)
    EmitFirstDocumentStartState => self.emit_document_start(event, true)
    EmitDocumentStartState => self.emit_document_start(event, false)
    EmitDocumentContentState => self.emit_document_content(event)
    EmitDocumentEndState => self.emit_document_end(event)
    EmitFlowSequenceFirstItemState => self.emit_flow_sequence_item(event, true)
    EmitFlowSequenceItemState => self.emit_flow_sequence_item(event, false)
    EmitFlowMappingFirstKeyState => self.emit_flow_mapping_key(event, true)
    EmitFlowMappingKeyState => self.emit_flow_mapping_key(event, false)
    EmitFlowMappingSimpleValueState => self.emit_flow_mapping_value(event, true)
    EmitFlowMappingValueState => self.emit_flow_mapping_value(event, false)
    EmitBlockSequenceFirstItemState =>
      self.emit_block_sequence_item(event, true)
    EmitBlockSequenceItemState => self.emit_block_sequence_item(event, false)
    EmitBlockMappingFirstKeyState => self.emit_block_mapping_key(event, true)
    EmitBlockMappingKeyState => self.emit_block_mapping_key(event, false)
    EmitBlockMappingSimpleValueState =>
      self.emit_block_mapping_value(event, true)
    EmitBlockMappingValueState => self.emit_block_mapping_value(event, false)
  }
}

///|
/// `yaml_emitter_emit_stream_start`.
fn Emitter::emit_stream_start(self : Emitter, event : EEvent) -> Unit {
  self.open_ended = 0
  guard event is EStreamStart else { abort("expected STREAM-START") }
  self.indent = -1
  self.column = 0
  self.whitespace = true
  self.indention = true
  self.state = EmitFirstDocumentStartState
}

///|
/// `yaml_emitter_emit_document_start` (implicit documents without
/// directives).
fn Emitter::emit_document_start(
  self : Emitter,
  event : EEvent,
  first : Bool,
) -> Unit {
  match event {
    EDocumentStart => {
      let implicit = first
      self.open_ended = 0
      if !implicit {
        self.write_indent()
        self.write_indicator("---", true, false, false)
      }
      self.state = EmitDocumentContentState
      self.open_ended = 0
    }
    // serde_yaml's `to_string` drops the serializer without emitting
    // STREAM-END, so no closing `...` is ever written.
    _ => abort("expected DOCUMENT-START or STREAM-END")
  }
}

///|
/// `yaml_emitter_emit_document_content`.
fn Emitter::emit_document_content(self : Emitter, event : EEvent) -> Unit {
  self.states.push(EmitDocumentEndState)
  self.emit_node(event, true, false, false, false)
}

///|
/// `yaml_emitter_emit_document_end` (implicit document end).
fn Emitter::emit_document_end(self : Emitter, event : EEvent) -> Unit {
  guard event is EDocumentEnd else { abort("expected DOCUMENT-END") }
  self.write_indent()
  if self.open_ended == 0 {
    self.open_ended = 1
  }
  self.state = EmitDocumentStartState
}

///|
/// `yaml_emitter_emit_flow_sequence_item`.
fn Emitter::emit_flow_sequence_item(
  self : Emitter,
  event : EEvent,
  first : Bool,
) -> Unit {
  if first {
    self.write_indicator("[", true, true, false)
    self.increase_indent(true, false)
    self.flow_level += 1
  }
  if event is ESequenceEnd {
    self.flow_level -= 1
    self.pop_indent()
    self.write_indicator("]", false, false, false)
    self.pop_state()
    return
  }
  if !first {
    self.write_indicator(",", false, false, false)
  }
  if self.column > self.best_width {
    self.write_indent()
  }
  self.states.push(EmitFlowSequenceItemState)
  self.emit_node(event, false, true, false, false)
}

///|
/// `yaml_emitter_emit_flow_mapping_key`.
fn Emitter::emit_flow_mapping_key(
  self : Emitter,
  event : EEvent,
  first : Bool,
) -> Unit {
  if first {
    self.write_indicator("{", true, true, false)
    self.increase_indent(true, false)
    self.flow_level += 1
  }
  if event is EMappingEnd {
    self.flow_level -= 1
    self.pop_indent()
    self.write_indicator("}", false, false, false)
    self.pop_state()
    return
  }
  if !first {
    self.write_indicator(",", false, false, false)
  }
  if self.column > self.best_width {
    self.write_indent()
  }
  if self.check_simple_key() {
    self.states.push(EmitFlowMappingSimpleValueState)
    self.emit_node(event, false, false, true, true)
  } else {
    self.write_indicator("?", true, false, false)
    self.states.push(EmitFlowMappingValueState)
    self.emit_node(event, false, false, true, false)
  }
}

///|
/// `yaml_emitter_emit_flow_mapping_value`.
fn Emitter::emit_flow_mapping_value(
  self : Emitter,
  event : EEvent,
  simple : Bool,
) -> Unit {
  if simple {
    self.write_indicator(":", false, false, false)
  } else {
    if self.column > self.best_width {
      self.write_indent()
    }
    self.write_indicator(":", true, false, false)
  }
  self.states.push(EmitFlowMappingKeyState)
  self.emit_node(event, false, false, true, false)
}

///|
/// `yaml_emitter_emit_block_sequence_item`.
fn Emitter::emit_block_sequence_item(
  self : Emitter,
  event : EEvent,
  first : Bool,
) -> Unit {
  if first {
    self.increase_indent(false, self.mapping_context && !self.indention)
  }
  if event is ESequenceEnd {
    self.pop_indent()
    self.pop_state()
    return
  }
  self.write_indent()
  self.write_indicator("-", true, false, true)
  self.states.push(EmitBlockSequenceItemState)
  self.emit_node(event, false, true, false, false)
}

///|
/// `yaml_emitter_emit_block_mapping_key`.
fn Emitter::emit_block_mapping_key(
  self : Emitter,
  event : EEvent,
  first : Bool,
) -> Unit {
  if first {
    self.increase_indent(false, false)
  }
  if event is EMappingEnd {
    self.pop_indent()
    self.pop_state()
    return
  }
  self.write_indent()
  if self.check_simple_key() {
    self.states.push(EmitBlockMappingSimpleValueState)
    self.emit_node(event, false, false, true, true)
  } else {
    self.write_indicator("?", true, false, true)
    self.states.push(EmitBlockMappingValueState)
    self.emit_node(event, false, false, true, false)
  }
}

///|
/// `yaml_emitter_emit_block_mapping_value`.
fn Emitter::emit_block_mapping_value(
  self : Emitter,
  event : EEvent,
  simple : Bool,
) -> Unit {
  if simple {
    self.write_indicator(":", false, false, false)
  } else {
    self.write_indent()
    self.write_indicator(":", true, false, true)
  }
  self.states.push(EmitBlockMappingKeyState)
  self.emit_node(event, false, false, true, false)
}

///|
/// `yaml_emitter_emit_node` (libyaml never reads the root and sequence
/// contexts it records).
fn Emitter::emit_node(
  self : Emitter,
  event : EEvent,
  _root : Bool,
  _sequence : Bool,
  mapping : Bool,
  simple_key : Bool,
) -> Unit {
  self.mapping_context = mapping
  self.simple_key_context = simple_key
  match event {
    EScalar(_, style) => self.emit_scalar(style)
    ESequenceStart => self.emit_sequence_start()
    EMappingStart => self.emit_mapping_start()
    _ => abort("expected SCALAR, SEQUENCE-START, MAPPING-START, or ALIAS")
  }
}

///|
/// `yaml_emitter_emit_scalar`.
fn Emitter::emit_scalar(self : Emitter, style : EStyle) -> Unit {
  self.select_scalar_style(style)
  self.increase_indent(true, false)
  self.process_scalar()
  self.pop_indent()
  self.pop_state()
}

///|
/// `yaml_emitter_emit_sequence_start`.
fn Emitter::emit_sequence_start(self : Emitter) -> Unit {
  if self.flow_level != 0 || self.check_empty_sequence() {
    self.state = EmitFlowSequenceFirstItemState
  } else {
    self.state = EmitBlockSequenceFirstItemState
  }
}

///|
/// `yaml_emitter_emit_mapping_start`.
fn Emitter::emit_mapping_start(self : Emitter) -> Unit {
  if self.flow_level != 0 || self.check_empty_mapping() {
    self.state = EmitFlowMappingFirstKeyState
  } else {
    self.state = EmitBlockMappingFirstKeyState
  }
}

///|
/// `yaml_emitter_check_empty_sequence`.
fn Emitter::check_empty_sequence(self : Emitter) -> Bool {
  if self.events.length() - self.head < 2 {
    return false
  }
  self.events[self.head] is ESequenceStart &&
  self.events[self.head + 1] is ESequenceEnd
}

///|
/// `yaml_emitter_check_empty_mapping`.
fn Emitter::check_empty_mapping(self : Emitter) -> Bool {
  if self.events.length() - self.head < 2 {
    return false
  }
  self.events[self.head] is EMappingStart &&
  self.events[self.head + 1] is EMappingEnd
}

///|
/// `yaml_emitter_check_simple_key`.
fn Emitter::check_simple_key(self : Emitter) -> Bool {
  let length = match self.events[self.head] {
    EScalar(_, _) => {
      if self.multiline {
        return false
      }
      self.value.length()
    }
    ESequenceStart => {
      if !self.check_empty_sequence() {
        return false
      }
      0
    }
    EMappingStart => {
      if !self.check_empty_mapping() {
        return false
      }
      0
    }
    _ => return false
  }
  length <= 128
}

///|
/// `yaml_emitter_select_scalar_style` (untagged, implicit scalars).
fn Emitter::select_scalar_style(self : Emitter, style : EStyle) -> Unit {
  let mut style = style
  if style == AnyStyle {
    style = PlainStyle
  }
  if self.simple_key_context && self.multiline {
    style = DoubleQuotedStyle
  }
  if style == PlainStyle {
    if (self.flow_level != 0 && !self.flow_plain_allowed) ||
      (self.flow_level == 0 && !self.block_plain_allowed) {
      style = SingleQuotedStyle
    }
    if self.value.length() == 0 &&
      (self.flow_level != 0 || self.simple_key_context) {
      style = SingleQuotedStyle
    }
  }
  if style == SingleQuotedStyle {
    if !self.single_quoted_allowed {
      style = DoubleQuotedStyle
    }
  }
  if style == LiteralStyle || style == FoldedStyle {
    if !self.block_allowed || self.flow_level != 0 || self.simple_key_context {
      style = DoubleQuotedStyle
    }
  }
  self.style = style
}

///|
/// `yaml_emitter_process_scalar`.
fn Emitter::process_scalar(self : Emitter) -> Unit {
  match self.style {
    PlainStyle => self.write_plain_scalar(self.value, !self.simple_key_context)
    SingleQuotedStyle =>
      self.write_single_quoted_scalar(self.value, !self.simple_key_context)
    DoubleQuotedStyle =>
      self.write_double_quoted_scalar(self.value, !self.simple_key_context)
    LiteralStyle => self.write_literal_scalar(self.value)
    FoldedStyle | AnyStyle => abort("unreachable")
  }
}

///|
/// `yaml_emitter_analyze_event`.
fn Emitter::analyze_event(self : Emitter, event : EEvent) -> Unit {
  self.value = b""
  if event is EScalar(value, _) {
    self.analyze_scalar(value)
  }
}

///|
/// `yaml_emitter_analyze_scalar`.
fn Emitter::analyze_scalar(self : Emitter, value : Bytes) -> Unit {
  let mut block_indicators = false
  let mut flow_indicators = false
  let mut line_breaks = false
  let mut special_characters = false
  let mut leading_space = false
  let mut leading_break = false
  let mut trailing_space = false
  let mut trailing_break = false
  let mut break_space = false
  let mut space_break = false
  let mut previous_space = false
  let mut previous_break = false
  self.value = value
  let end = value.length()
  if end == 0 {
    self.multiline = false
    self.flow_plain_allowed = false
    self.block_plain_allowed = true
    self.single_quoted_allowed = true
    self.block_allowed = false
    return
  }
  if (
      byte_at(value, 0) == '-' &&
      byte_at(value, 1) == '-' &&
      byte_at(value, 2) == '-'
    ) ||
    (
      byte_at(value, 0) == '.' &&
      byte_at(value, 1) == '.' &&
      byte_at(value, 2) == '.'
    ) {
    block_indicators = true
    flow_indicators = true
  }
  let mut preceded_by_whitespace = true
  let mut followed_by_whitespace = is_blankz_at(value, width_at(value, 0))
  let mut i = 0
  while i != end {
    let c = byte_at(value, i)
    if i == 0 {
      if c
        is ('#'
        | ','
        | '['
        | ']'
        | '{'
        | '}'
        | '&'
        | '*'
        | '!'
        | '|'
        | '>'
        | '\''
        | '"'
        | '%'
        | '@'
        | '`') {
        flow_indicators = true
        block_indicators = true
      }
      if c == '?' || c == ':' {
        flow_indicators = true
        if followed_by_whitespace {
          block_indicators = true
        }
      }
      if c == '-' && followed_by_whitespace {
        flow_indicators = true
        block_indicators = true
      }
    } else {
      if c is (',' | '?' | '[' | ']' | '{' | '}') {
        flow_indicators = true
      }
      if c == ':' {
        flow_indicators = true
        if followed_by_whitespace {
          block_indicators = true
        }
      }
      if c == '#' && preceded_by_whitespace {
        flow_indicators = true
        block_indicators = true
      }
    }
    if !is_printable_at(value, i) {
      special_characters = true
    }
    if is_break_at(value, i) {
      line_breaks = true
    }
    if is_space_at(value, i) {
      if i == 0 {
        leading_space = true
      }
      if i + width_at(value, i) == end {
        trailing_space = true
      }
      if previous_break {
        break_space = true
      }
      previous_space = true
      previous_break = false
    } else if is_break_at(value, i) {
      if i == 0 {
        leading_break = true
      }
      if i + width_at(value, i) == end {
        trailing_break = true
      }
      if previous_space {
        space_break = true
      }
      previous_space = false
      previous_break = true
    } else {
      previous_space = false
      previous_break = false
    }
    preceded_by_whitespace = is_blankz_at(value, i)
    i += width_at(value, i)
    if i != end {
      followed_by_whitespace = is_blankz_at(value, i + width_at(value, i))
    }
  }
  self.multiline = line_breaks
  self.flow_plain_allowed = true
  self.block_plain_allowed = true
  self.single_quoted_allowed = true
  self.block_allowed = true
  if leading_space || leading_break || trailing_space || trailing_break {
    self.flow_plain_allowed = false
    self.block_plain_allowed = false
  }
  if trailing_space {
    self.block_allowed = false
  }
  if break_space {
    self.flow_plain_allowed = false
    self.block_plain_allowed = false
    self.single_quoted_allowed = false
  }
  if space_break || special_characters {
    self.flow_plain_allowed = false
    self.block_plain_allowed = false
    self.single_quoted_allowed = false
    self.block_allowed = false
  }
  if line_breaks {
    self.flow_plain_allowed = false
    self.block_plain_allowed = false
  }
  if flow_indicators {
    self.flow_plain_allowed = false
  }
  if block_indicators {
    self.block_plain_allowed = false
  }
}

///|
/// `yaml_emitter_write_indent`.
fn Emitter::write_indent(self : Emitter) -> Unit {
  let indent = if self.indent >= 0 { self.indent } else { 0 }
  if !self.indention ||
    self.column > indent ||
    (self.column == indent && !self.whitespace) {
    self.put_break()
  }
  while self.column < indent {
    self.put(b' ')
  }
  self.whitespace = true
  self.indention = true
}

///|
/// `yaml_emitter_write_indicator`.
fn Emitter::write_indicator(
  self : Emitter,
  indicator : String,
  need_whitespace : Bool,
  is_whitespace : Bool,
  is_indention : Bool,
) -> Unit {
  if need_whitespace && !self.whitespace {
    self.put(b' ')
  }
  for c in indicator {
    self.out.push(c.to_int().to_byte())
    self.column += 1
  }
  self.whitespace = is_whitespace
  self.indention = self.indention && is_indention
}

///|
/// `yaml_emitter_write_plain_scalar`.
fn Emitter::write_plain_scalar(
  self : Emitter,
  value : Bytes,
  allow_breaks : Bool,
) -> Unit {
  let mut spaces = false
  let mut breaks = false
  let end = value.length()
  if !self.whitespace && (end != 0 || self.flow_level != 0) {
    self.put(b' ')
  }
  let mut i = 0
  while i != end {
    if is_space_at(value, i) {
      if allow_breaks &&
        !spaces &&
        self.column > self.best_width &&
        !is_space_at(value, i + 1) {
        self.write_indent()
        i += width_at(value, i)
      } else {
        i = self.write(value, i)
      }
      spaces = true
    } else if is_break_at(value, i) {
      if !breaks && byte_at(value, i) == '\n' {
        self.put_break()
      }
      i = self.write_break(value, i)
      self.indention = true
      breaks = true
    } else {
      if breaks {
        self.write_indent()
      }
      i = self.write(value, i)
      self.indention = false
      spaces = false
      breaks = false
    }
  }
  self.whitespace = false
  self.indention = false
}

///|
/// `yaml_emitter_write_single_quoted_scalar`.
fn Emitter::write_single_quoted_scalar(
  self : Emitter,
  value : Bytes,
  allow_breaks : Bool,
) -> Unit {
  let mut spaces = false
  let mut breaks = false
  let end = value.length()
  self.write_indicator("'", true, false, false)
  let mut i = 0
  while i != end {
    if is_space_at(value, i) {
      if allow_breaks &&
        !spaces &&
        self.column > self.best_width &&
        i != 0 &&
        i != end - 1 &&
        !is_space_at(value, i + 1) {
        self.write_indent()
        i += width_at(value, i)
      } else {
        i = self.write(value, i)
      }
      spaces = true
    } else if is_break_at(value, i) {
      if !breaks && byte_at(value, i) == '\n' {
        self.put_break()
      }
      i = self.write_break(value, i)
      self.indention = true
      breaks = true
    } else {
      if breaks {
        self.write_indent()
      }
      if byte_at(value, i) == '\'' {
        self.put(b'\'')
      }
      i = self.write(value, i)
      self.indention = false
      spaces = false
      breaks = false
    }
  }
  if breaks {
    self.write_indent()
  }
  self.write_indicator("'", false, false, false)
  self.whitespace = false
  self.indention = false
}

///|
/// An uppercase hexadecimal digit.
fn hex_digit(d : Int) -> Byte {
  (if d < 10 { d + '0' } else { d - 10 + 'A' }).to_byte()
}

///|
/// `yaml_emitter_write_double_quoted_scalar`.
fn Emitter::write_double_quoted_scalar(
  self : Emitter,
  value : Bytes,
  allow_breaks : Bool,
) -> Unit {
  let mut spaces = false
  let end = value.length()
  self.write_indicator("\"", true, false, false)
  let mut i = 0
  while i != end {
    let c = byte_at(value, i)
    if !is_printable_at(value, i) ||
      (
        c == 0xEF &&
        byte_at(value, i + 1) == 0xBB &&
        byte_at(value, i + 2) == 0xBF
      ) ||
      is_break_at(value, i) ||
      c == '"' ||
      c == '\\' {
      let width = width_at(value, i)
      let mut v = if (c & 0x80) == 0 {
        c & 0x7F
      } else if (c & 0xE0) == 0xC0 {
        c & 0x1F
      } else if (c & 0xF0) == 0xE0 {
        c & 0x0F
      } else if (c & 0xF8) == 0xF0 {
        c & 0x07
      } else {
        0
      }
      for k in 1..<width {
        v = (v << 6) + (byte_at(value, i + k) & 0x3F)
      }
      i += width
      self.put(b'\\')
      match v {
        0x00 => self.put(b'0')
        0x07 => self.put(b'a')
        0x08 => self.put(b'b')
        0x09 => self.put(b't')
        0x0A => self.put(b'n')
        0x0B => self.put(b'v')
        0x0C => self.put(b'f')
        0x0D => self.put(b'r')
        0x1B => self.put(b'e')
        0x22 => self.put(b'"')
        0x5C => self.put(b'\\')
        0x85 => self.put(b'N')
        0xA0 => self.put(b'_')
        0x2028 => self.put(b'L')
        0x2029 => self.put(b'P')
        _ => {
          let digits = if v <= 0xFF {
            self.put(b'x')
            2
          } else if v <= 0xFFFF {
            self.put(b'u')
            4
          } else {
            self.put(b'U')
            8
          }
          let mut k = (digits - 1) * 4
          while k >= 0 {
            self.put(hex_digit((v >> k) & 0x0F))
            k -= 4
          }
        }
      }
      spaces = false
    } else if is_space_at(value, i) {
      if allow_breaks &&
        !spaces &&
        self.column > self.best_width &&
        i != 0 &&
        i != end - 1 {
        self.write_indent()
        if is_space_at(value, i + 1) {
          self.put(b'\\')
        }
        i += width_at(value, i)
      } else {
        i = self.write(value, i)
      }
      spaces = true
    } else {
      i = self.write(value, i)
      spaces = false
    }
  }
  self.write_indicator("\"", false, false, false)
  self.whitespace = false
  self.indention = false
}

///|
/// Moves back from `i` to the start of the previous UTF-8 character.
fn prev_char(s : Bytes, i : Int) -> Int {
  let mut i = i - 1
  while (byte_at(s, i) & 0xC0) == 0x80 {
    i -= 1
  }
  i
}

///|
/// `yaml_emitter_write_block_scalar_hints`.
fn Emitter::write_block_scalar_hints(self : Emitter, value : Bytes) -> Unit {
  if is_space_at(value, 0) || is_break_at(value, 0) {
    let indent_hint = ('0'.to_int() + self.best_indent)
      .unsafe_to_char()
      .to_string()
    self.write_indicator(indent_hint, false, false, false)
  }
  self.open_ended = 0
  let mut chomp_hint : String? = None
  let end = value.length()
  if end == 0 {
    chomp_hint = Some("-")
  } else {
    let mut p = prev_char(value, end)
    if !is_break_at(value, p) {
      chomp_hint = Some("-")
    } else if p == 0 {
      chomp_hint = Some("+")
      self.open_ended = 2
    } else {
      p = prev_char(value, p)
      if is_break_at(value, p) {
        chomp_hint = Some("+")
        self.open_ended = 2
      }
    }
  }
  if chomp_hint is Some(hint) {
    self.write_indicator(hint, false, false, false)
  }
}

///|
/// `yaml_emitter_write_literal_scalar`.
fn Emitter::write_literal_scalar(self : Emitter, value : Bytes) -> Unit {
  let mut breaks = true
  let end = value.length()
  self.write_indicator("|", true, false, false)
  self.write_block_scalar_hints(value)
  self.put_break()
  self.indention = true
  self.whitespace = true
  let mut i = 0
  while i != end {
    if is_break_at(value, i) {
      i = self.write_break(value, i)
      self.indention = true
      breaks = true
    } else {
      if breaks {
        self.write_indent()
      }
      i = self.write(value, i)
      self.indention = false
      breaks = false
    }
  }
}
