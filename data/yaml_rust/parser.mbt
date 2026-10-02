// Port of `yaml_rust::parser` (yaml-rust 0.4.5).

///|
priv enum State {
  StreamStart
  ImplicitDocumentStart
  DocumentStart
  DocumentContent
  DocumentEnd
  BlockNode
  // BlockNodeOrIndentlessSequence,
  // FlowNode,
  BlockSequenceFirstEntry
  BlockSequenceEntry
  IndentlessSequenceEntry
  BlockMappingFirstKey
  BlockMappingKey
  BlockMappingValue
  FlowSequenceFirstEntry
  FlowSequenceEntry
  FlowSequenceEntryMappingKey
  FlowSequenceEntryMappingValue
  FlowSequenceEntryMappingEnd
  FlowMappingFirstKey
  FlowMappingKey
  FlowMappingValue
  FlowMappingEmptyValue
  End
} derive(Eq)

///|
/// `Event` is used with the low-level event base parsing API,
/// see `MarkedEventReceiver` trait.
pub(all) enum Event {
  /// Reserved for internal use
  Nothing
  StreamStart
  StreamEnd
  DocumentStart
  DocumentEnd
  /// Refer to an anchor ID
  Alias(Int)
  /// Value, style, anchor_id, tag
  Scalar(String, TScalarStyle, Int, TokenType?)
  /// Anchor ID
  SequenceStart(Int)
  SequenceEnd
  /// Anchor ID
  MappingStart(Int)
  MappingEnd
} derive(Eq, Debug)

///|
fn Event::empty_scalar() -> Event {
  // a null scalar
  Event::Scalar("~", Plain, 0, None)
}

///|
fn Event::empty_scalar_with_anchor(anchor : Int, tag : TokenType?) -> Event {
  Event::Scalar("", Plain, anchor, tag)
}

///|
pub struct Parser {
  priv scanner : Scanner
  priv states : Array[State]
  priv mut state : State
  priv mut token : Token?
  priv mut current : (Event, Marker)?
  priv anchors : Map[String, Int]
  priv mut anchor_id : Int
}

///|
/// Receives the events of `Parser::load` together with their marks.
/// (Upstream also has an unmarked `EventReceiver` with a blanket impl; MoonBit
/// has no blanket impls, so receivers implement this trait directly.)
pub(open) trait MarkedEventReceiver {
  fn on_event(Self, Event, Marker) -> Unit
}

///|
pub fn Parser::new(src : String) -> Parser {
  {
    scanner: Scanner::new(src),
    states: [],
    state: StreamStart,
    token: None,
    current: None,
    anchors: {},
    // valid anchor_id starts from 1
    anchor_id: 1,
  }
}

///|
pub fn Parser::peek(self : Parser) -> (Event, Marker) raise ScanError {
  match self.current {
    Some(x) => x
    None => {
      self.current = Some(self.next())
      self.peek()
    }
  }
}

///|
pub fn Parser::next(self : Parser) -> (Event, Marker) raise ScanError {
  match self.current {
    None => self.parse()
    Some(x) => {
      self.current = None
      x
    }
  }
}

///|
fn Parser::peek_token(self : Parser) -> Token raise ScanError {
  match self.token {
    None => {
      let tok = self.scan_next_token()
      self.token = Some(tok)
      tok
    }
    Some(tok) => tok
  }
}

///|
fn Parser::scan_next_token(self : Parser) -> Token raise ScanError {
  let token = self.scanner.next()
  match token {
    None =>
      match self.scanner.get_error() {
        None => raise ScanError::new(self.scanner.mark(), "unexpected eof")
        Some(e) => raise e
      }
    Some(tok) => tok
  }
}

///|
fn Parser::fetch_token(self : Parser) -> Token {
  guard self.token is Some(tok) else {
    abort("fetch_token needs to be preceded by peek_token")
  }
  self.token = None
  tok
}

///|
fn Parser::skip(self : Parser) -> Unit {
  self.token = None
  //self.peek_token();
}

///|
fn Parser::pop_state(self : Parser) -> Unit {
  self.state = self.states.unsafe_pop()
}

///|
fn Parser::push_state(self : Parser, state : State) -> Unit {
  self.states.push(state)
}

///|
fn Parser::parse(self : Parser) -> (Event, Marker) raise ScanError {
  if self.state == End {
    return (Event::StreamEnd, self.scanner.mark())
  }
  let (ev, mark) = self.state_machine()
  (ev, mark)
}

///|
pub fn[R : MarkedEventReceiver] Parser::load(
  self : Parser,
  recv : R,
  multi : Bool,
) -> Unit raise ScanError {
  if !self.scanner.stream_started() {
    let (ev, mark) = self.next()
    guard! ev == Event::StreamStart
    recv.on_event(ev, mark)
  }
  if self.scanner.stream_ended() {
    // XXX has parsed?
    recv.on_event(Event::StreamEnd, self.scanner.mark())
    return
  }
  while true {
    let (ev, mark) = self.next()
    if ev == Event::StreamEnd {
      recv.on_event(ev, mark)
      return
    }
    // clear anchors before a new document
    self.anchors.clear()
    self.load_document(ev, mark, recv)
    if !multi {
      break
    }
  }
}

///|
fn[R : MarkedEventReceiver] Parser::load_document(
  self : Parser,
  first_ev : Event,
  mark : Marker,
  recv : R,
) -> Unit raise ScanError {
  guard! first_ev == Event::DocumentStart
  recv.on_event(first_ev, mark)
  let (ev, mark) = self.next()
  self.load_node(ev, mark, recv)

  // DOCUMENT-END is expected.
  let (ev, mark) = self.next()
  guard! ev == Event::DocumentEnd
  recv.on_event(ev, mark)
}

///|
fn[R : MarkedEventReceiver] Parser::load_node(
  self : Parser,
  first_ev : Event,
  mark : Marker,
  recv : R,
) -> Unit raise ScanError {
  match first_ev {
    Alias(_) | Scalar(_, _, _, _) => recv.on_event(first_ev, mark)
    SequenceStart(_) => {
      recv.on_event(first_ev, mark)
      self.load_sequence(recv)
    }
    MappingStart(_) => {
      recv.on_event(first_ev, mark)
      self.load_mapping(recv)
    }
    _ => abort("UNREACHABLE EVENT")
  }
}

///|
fn[R : MarkedEventReceiver] Parser::load_mapping(
  self : Parser,
  recv : R,
) -> Unit raise ScanError {
  let (ev0, mark0) = self.next()
  let mut key_ev = ev0
  let mut key_mark = mark0
  while key_ev != Event::MappingEnd {
    // key
    self.load_node(key_ev, key_mark, recv)

    // value
    let (ev, mark) = self.next()
    self.load_node(ev, mark, recv)

    // next event
    let (ev, mark) = self.next()
    key_ev = ev
    key_mark = mark
  }
  recv.on_event(key_ev, key_mark)
}

///|
fn[R : MarkedEventReceiver] Parser::load_sequence(
  self : Parser,
  recv : R,
) -> Unit raise ScanError {
  let (ev0, mark0) = self.next()
  let mut ev = ev0
  let mut mark = mark0
  while ev != Event::SequenceEnd {
    self.load_node(ev, mark, recv)

    // next event
    let (next_ev, next_mark) = self.next()
    ev = next_ev
    mark = next_mark
  }
  recv.on_event(ev, mark)
}

///|
fn Parser::state_machine(self : Parser) -> (Event, Marker) raise ScanError {
  match self.state {
    StreamStart => self.stream_start()
    ImplicitDocumentStart => self.document_start(true)
    DocumentStart => self.document_start(false)
    DocumentContent => self.document_content()
    DocumentEnd => self.document_end()
    BlockNode => self.parse_node(true, false)
    // State::BlockNodeOrIndentlessSequence => self.parse_node(true, true),
    // State::FlowNode => self.parse_node(false, false),
    BlockMappingFirstKey => self.block_mapping_key(true)
    BlockMappingKey => self.block_mapping_key(false)
    BlockMappingValue => self.block_mapping_value()
    BlockSequenceFirstEntry => self.block_sequence_entry(true)
    BlockSequenceEntry => self.block_sequence_entry(false)
    FlowSequenceFirstEntry => self.flow_sequence_entry(true)
    FlowSequenceEntry => self.flow_sequence_entry(false)
    FlowMappingFirstKey => self.flow_mapping_key(true)
    FlowMappingKey => self.flow_mapping_key(false)
    FlowMappingValue => self.flow_mapping_value(false)
    IndentlessSequenceEntry => self.indentless_sequence_entry()
    FlowSequenceEntryMappingKey => self.flow_sequence_entry_mapping_key()
    FlowSequenceEntryMappingValue => self.flow_sequence_entry_mapping_value()
    FlowSequenceEntryMappingEnd => self.flow_sequence_entry_mapping_end()
    FlowMappingEmptyValue => self.flow_mapping_value(true)
    // impossible
    End => panic()
  }
}

///|
fn Parser::stream_start(self : Parser) -> (Event, Marker) raise ScanError {
  match self.peek_token() {
    Token(mark, StreamStart(_)) => {
      self.state = ImplicitDocumentStart
      self.skip()
      (Event::StreamStart, mark)
    }
    Token(mark, _) =>
      raise ScanError::new(mark, "did not find expected <stream-start>")
  }
}

///|
fn Parser::document_start(
  self : Parser,
  implicit : Bool,
) -> (Event, Marker) raise ScanError {
  if !implicit {
    while self.peek_token().1 is DocumentEnd {
      self.skip()
    }
  }
  match self.peek_token() {
    Token(mark, StreamEnd) => {
      self.state = End
      self.skip()
      (Event::StreamEnd, mark)
    }
    Token(_, VersionDirective(_, _))
    | Token(_, TagDirective(_, _))
    | Token(_, DocumentStart) =>
      // explicit document
      self._explicit_document_start()
    Token(mark, _) if implicit => {
      self.parser_process_directives()
      self.push_state(DocumentEnd)
      self.state = BlockNode
      (Event::DocumentStart, mark)
    }
    _ =>
      // explicit document
      self._explicit_document_start()
  }
}

///|
fn Parser::parser_process_directives(self : Parser) -> Unit raise ScanError {
  while true {
    match self.peek_token().1 {
      VersionDirective(_, _) =>
        // XXX parsing with warning according to spec
        //if major != 1 || minor > 2 {
        //    return Err(ScanError::new(tok.0,
        //        "found incompatible YAML document"));
        //}
        ()
      TagDirective(_, _) =>
        // TODO add tag directive
        ()
      _ => break
    }
    self.skip()
  }
  // TODO tag directive
}

///|
fn Parser::_explicit_document_start(
  self : Parser,
) -> (Event, Marker) raise ScanError {
  self.parser_process_directives()
  match self.peek_token() {
    Token(mark, DocumentStart) => {
      self.push_state(DocumentEnd)
      self.state = DocumentContent
      self.skip()
      (Event::DocumentStart, mark)
    }
    Token(mark, _) =>
      raise ScanError::new(mark, "did not find expected <document start>")
  }
}

///|
fn Parser::document_content(self : Parser) -> (Event, Marker) raise ScanError {
  match self.peek_token() {
    Token(mark, VersionDirective(_, _))
    | Token(mark, TagDirective(_, _))
    | Token(mark, DocumentStart)
    | Token(mark, DocumentEnd)
    | Token(mark, StreamEnd) => {
      self.pop_state()
      // empty scalar
      (Event::empty_scalar(), mark)
    }
    _ => self.parse_node(true, false)
  }
}

///|
fn Parser::document_end(self : Parser) -> (Event, Marker) raise ScanError {
  let marker : Marker = match self.peek_token() {
    Token(mark, DocumentEnd) => {
      self.skip()
      mark
    }
    Token(mark, _) => mark
  }

  // TODO tag handling
  self.state = DocumentStart
  (Event::DocumentEnd, marker)
}

///|
fn Parser::register_anchor(self : Parser, name : String, _mark : Marker) -> Int {
  // anchors can be overridden/reused
  // if self.anchors.contains_key(name) {
  //     return Err(ScanError::new(*mark,
  //         "while parsing anchor, found duplicated anchor"));
  // }
  let new_id = self.anchor_id
  self.anchor_id += 1
  self.anchors.set(name, new_id)
  new_id
}

///|
fn Parser::parse_node(
  self : Parser,
  block : Bool,
  indentless_sequence : Bool,
) -> (Event, Marker) raise ScanError {
  let mut anchor_id = 0
  let mut tag = None
  match self.peek_token() {
    Token(_, Alias(_)) => {
      self.pop_state()
      guard self.fetch_token() is Token(mark, Alias(name)) else { panic() }
      match self.anchors.get(name) {
        None =>
          raise ScanError::new(mark, "while parsing node, found unknown anchor")
        Some(id) => return (Event::Alias(id), mark)
      }
    }
    Token(_, Anchor(_)) => {
      guard self.fetch_token() is Token(mark, Anchor(name)) else { panic() }
      anchor_id = self.register_anchor(name, mark)
      if self.peek_token().1 is Tag(_, _) {
        tag = Some(self.fetch_token().1)
      }
    }
    Token(_, Tag(_, _)) => {
      tag = Some(self.fetch_token().1)
      if self.peek_token().1 is Anchor(_) {
        guard self.fetch_token() is Token(mark, Anchor(name)) else { panic() }
        anchor_id = self.register_anchor(name, mark)
      }
    }
    _ => ()
  }
  match self.peek_token() {
    Token(mark, BlockEntry) if indentless_sequence => {
      self.state = IndentlessSequenceEntry
      (Event::SequenceStart(anchor_id), mark)
    }
    Token(_, Scalar(_, _)) => {
      self.pop_state()
      guard self.fetch_token() is Token(mark, Scalar(style, v)) else { panic() }
      (Event::Scalar(v, style, anchor_id, tag), mark)
    }
    Token(mark, FlowSequenceStart) => {
      self.state = FlowSequenceFirstEntry
      (Event::SequenceStart(anchor_id), mark)
    }
    Token(mark, FlowMappingStart) => {
      self.state = FlowMappingFirstKey
      (Event::MappingStart(anchor_id), mark)
    }
    Token(mark, BlockSequenceStart) if block => {
      self.state = BlockSequenceFirstEntry
      (Event::SequenceStart(anchor_id), mark)
    }
    Token(mark, BlockMappingStart) if block => {
      self.state = BlockMappingFirstKey
      (Event::MappingStart(anchor_id), mark)
    }
    // ex 7.2, an empty scalar can follow a secondary tag
    Token(mark, _) if tag is Some(_) || anchor_id > 0 => {
      self.pop_state()
      (Event::empty_scalar_with_anchor(anchor_id, tag), mark)
    }
    Token(mark, _) =>
      raise ScanError::new(
        mark, "while parsing a node, did not find expected node content",
      )
  }
}

///|
fn Parser::block_mapping_key(
  self : Parser,
  first : Bool,
) -> (Event, Marker) raise ScanError {
  // skip BlockMappingStart
  if first {
    let _ = self.peek_token()
    //self.marks.push(tok.0);
    self.skip()
  }
  match self.peek_token() {
    Token(_, Key) => {
      self.skip()
      match self.peek_token() {
        Token(mark, Key) | Token(mark, Value) | Token(mark, BlockEnd) => {
          self.state = BlockMappingValue
          // empty scalar
          (Event::empty_scalar(), mark)
        }
        _ => {
          self.push_state(BlockMappingValue)
          self.parse_node(true, true)
        }
      }
    }
    // XXX(chenyh): libyaml failed to parse spec 1.2, ex8.18
    Token(mark, Value) => {
      self.state = BlockMappingValue
      (Event::empty_scalar(), mark)
    }
    Token(mark, BlockEnd) => {
      self.pop_state()
      self.skip()
      (Event::MappingEnd, mark)
    }
    Token(mark, _) =>
      raise ScanError::new(
        mark, "while parsing a block mapping, did not find expected key",
      )
  }
}

///|
fn Parser::block_mapping_value(
  self : Parser,
) -> (Event, Marker) raise ScanError {
  match self.peek_token() {
    Token(_, Value) => {
      self.skip()
      match self.peek_token() {
        Token(mark, Key) | Token(mark, Value) | Token(mark, BlockEnd) => {
          self.state = BlockMappingKey
          // empty scalar
          (Event::empty_scalar(), mark)
        }
        _ => {
          self.push_state(BlockMappingKey)
          self.parse_node(true, true)
        }
      }
    }
    Token(mark, _) => {
      self.state = BlockMappingKey
      // empty scalar
      (Event::empty_scalar(), mark)
    }
  }
}

///|
fn Parser::flow_mapping_key(
  self : Parser,
  first : Bool,
) -> (Event, Marker) raise ScanError {
  if first {
    let _ = self.peek_token()
    self.skip()
  }
  let marker : Marker = match self.peek_token() {
    Token(mark, FlowMappingEnd) => mark
    Token(mark, _) => {
      if !first {
        match self.peek_token() {
          Token(_, FlowEntry) => self.skip()
          Token(mark, _) =>
            raise ScanError::new(
              mark, "while parsing a flow mapping, did not find expected ',' or '}'",
            )
        }
      }
      match self.peek_token() {
        Token(_, Key) => {
          self.skip()
          match self.peek_token() {
            Token(mark, Value)
            | Token(mark, FlowEntry)
            | Token(mark, FlowMappingEnd) => {
              self.state = FlowMappingValue
              return (Event::empty_scalar(), mark)
            }
            _ => {
              self.push_state(FlowMappingValue)
              return self.parse_node(false, false)
            }
          }
        }
        Token(marker, Value) => {
          self.state = FlowMappingValue
          return (Event::empty_scalar(), marker)
        }
        Token(_, FlowMappingEnd) => ()
        _ => {
          self.push_state(FlowMappingEmptyValue)
          return self.parse_node(false, false)
        }
      }
      mark
    }
  }
  self.pop_state()
  self.skip()
  (Event::MappingEnd, marker)
}

///|
fn Parser::flow_mapping_value(
  self : Parser,
  empty : Bool,
) -> (Event, Marker) raise ScanError {
  let mark : Marker = if empty {
    let Token(mark, _) = self.peek_token()
    self.state = FlowMappingKey
    return (Event::empty_scalar(), mark)
  } else {
    match self.peek_token() {
      Token(marker, Value) => {
        self.skip()
        match self.peek_token().1 {
          FlowEntry | FlowMappingEnd => ()
          _ => {
            self.push_state(FlowMappingKey)
            return self.parse_node(false, false)
          }
        }
        marker
      }
      Token(marker, _) => marker
    }
  }
  self.state = FlowMappingKey
  (Event::empty_scalar(), mark)
}

///|
fn Parser::flow_sequence_entry(
  self : Parser,
  first : Bool,
) -> (Event, Marker) raise ScanError {
  // skip FlowMappingStart
  if first {
    let _ = self.peek_token()
    //self.marks.push(tok.0);
    self.skip()
  }
  match self.peek_token() {
    Token(mark, FlowSequenceEnd) => {
      self.pop_state()
      self.skip()
      return (Event::SequenceEnd, mark)
    }
    Token(_, FlowEntry) if !first => self.skip()
    Token(mark, _) if !first =>
      raise ScanError::new(
        mark, "while parsing a flow sequence, expected ',' or ']'",
      )
    _ => () // next
  }
  match self.peek_token() {
    Token(mark, FlowSequenceEnd) => {
      self.pop_state()
      self.skip()
      (Event::SequenceEnd, mark)
    }
    Token(mark, Key) => {
      self.state = FlowSequenceEntryMappingKey
      self.skip()
      (Event::MappingStart(0), mark)
    }
    _ => {
      self.push_state(FlowSequenceEntry)
      self.parse_node(false, false)
    }
  }
}

///|
fn Parser::indentless_sequence_entry(
  self : Parser,
) -> (Event, Marker) raise ScanError {
  match self.peek_token() {
    Token(_, BlockEntry) => ()
    Token(mark, _) => {
      self.pop_state()
      return (Event::SequenceEnd, mark)
    }
  }
  self.skip()
  match self.peek_token() {
    Token(mark, BlockEntry)
    | Token(mark, Key)
    | Token(mark, Value)
    | Token(mark, BlockEnd) => {
      self.state = IndentlessSequenceEntry
      (Event::empty_scalar(), mark)
    }
    _ => {
      self.push_state(IndentlessSequenceEntry)
      self.parse_node(true, false)
    }
  }
}

///|
fn Parser::block_sequence_entry(
  self : Parser,
  first : Bool,
) -> (Event, Marker) raise ScanError {
  // BLOCK-SEQUENCE-START
  if first {
    let _ = self.peek_token()
    //self.marks.push(tok.0);
    self.skip()
  }
  match self.peek_token() {
    Token(mark, BlockEnd) => {
      self.pop_state()
      self.skip()
      (Event::SequenceEnd, mark)
    }
    Token(_, BlockEntry) => {
      self.skip()
      match self.peek_token() {
        Token(mark, BlockEntry) | Token(mark, BlockEnd) => {
          self.state = BlockSequenceEntry
          (Event::empty_scalar(), mark)
        }
        _ => {
          self.push_state(BlockSequenceEntry)
          self.parse_node(true, false)
        }
      }
    }
    Token(mark, _) =>
      raise ScanError::new(
        mark, "while parsing a block collection, did not find expected '-' indicator",
      )
  }
}

///|
fn Parser::flow_sequence_entry_mapping_key(
  self : Parser,
) -> (Event, Marker) raise ScanError {
  match self.peek_token() {
    Token(mark, Value)
    | Token(mark, FlowEntry)
    | Token(mark, FlowSequenceEnd) => {
      self.skip()
      self.state = FlowSequenceEntryMappingValue
      (Event::empty_scalar(), mark)
    }
    _ => {
      self.push_state(FlowSequenceEntryMappingValue)
      self.parse_node(false, false)
    }
  }
}

///|
fn Parser::flow_sequence_entry_mapping_value(
  self : Parser,
) -> (Event, Marker) raise ScanError {
  match self.peek_token() {
    Token(_, Value) => {
      self.skip()
      self.state = FlowSequenceEntryMappingValue
      match self.peek_token() {
        Token(mark, FlowEntry) | Token(mark, FlowSequenceEnd) => {
          self.state = FlowSequenceEntryMappingEnd
          (Event::empty_scalar(), mark)
        }
        _ => {
          self.push_state(FlowSequenceEntryMappingEnd)
          self.parse_node(false, false)
        }
      }
    }
    Token(mark, _) => {
      self.state = FlowSequenceEntryMappingEnd
      (Event::empty_scalar(), mark)
    }
  }
}

///|
fn Parser::flow_sequence_entry_mapping_end(self : Parser) -> (Event, Marker) {
  self.state = FlowSequenceEntry
  (Event::MappingEnd, self.scanner.mark())
}
