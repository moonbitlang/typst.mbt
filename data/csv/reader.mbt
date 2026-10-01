// Port of the parts of the `csv` crate 1.4.0 (`reader.rs`,
// `string_record.rs`, `byte_record.rs`, `error.rs`) and `csv-core` 0.1.13
// (`reader.rs`, the NFA) that Typst's `csv` function uses: a reader over a
// byte slice with a configurable delimiter and `has_headers`, and otherwise
// default settings (CRLF terminator, `"` quotes with doubling, no escape, no
// comments, not flexible, no trimming).

///|
/// A position in CSV data (upstream `csv::Position`).
pub(all) struct Position {
  /// The byte offset.
  byte : Int
  /// The line number (starting at 1).
  line : Int
  /// The record index (starting at 0).
  record : Int
} derive(Eq, Debug)

///|
/// The kind of a CSV error (upstream `csv::ErrorKind`, as far as it can
/// occur when reading from a byte slice).
pub(all) enum ErrorKind {
  /// A UTF-8 decoding error that occurred while trying to convert a byte
  /// record to a string record.
  Utf8(pos~ : Position?, field~ : Int, valid_up_to~ : Int)
  /// A record with a different number of fields than the first record.
  UnequalLengths(pos~ : Position?, expected_len~ : Int, len~ : Int)
} derive(Eq, Debug)

///|
/// A CSV error (upstream `csv::Error`).
pub(all) suberror CsvError {
  CsvError(ErrorKind)
} derive(Debug)

///|
/// The position of the error, if available (upstream `ErrorKind::position`).
pub fn ErrorKind::position(self : ErrorKind) -> Position? {
  match self {
    Utf8(pos~, ..) => pos
    UnequalLengths(pos~, ..) => pos
  }
}

///|
/// The states of the `csv-core` NFA.
priv enum NfaState {
  EndFieldTerm
  InRecordTerm
  End
  StartRecord
  StartField
  InField
  InQuotedField
  // `InEscapedQuote` and `InComment` are unreachable without an escape and a
  // comment character.
  InDoubleEscapedQuote
  EndFieldDelim
  EndRecord
  CRLF
} derive(Eq)

///|
/// Returns true if this state indicates that a field has been parsed.
fn NfaState::is_field_final(self : NfaState) -> Bool {
  self is (End | EndRecord | CRLF | EndFieldDelim)
}

///|
/// What to do with an input byte.
priv enum NfaInputAction {
  Epsilon
  CopyToOutput
  Discard
}

///|
/// A CSV reader over a byte slice (upstream `csv::Reader` with a `csv_core`
/// reader inside).
pub struct Reader {
  priv data : Bytes
  priv delimiter : Byte
  priv has_headers : Bool
  /// The current input index.
  priv mut index : Int
  /// The current NFA state.
  priv mut nfa_state : NfaState
  /// Whether the BOM check was done (upstream `has_read`).
  priv mut has_read : Bool
  /// The current line (as counted by the occurrences of `\n`).
  priv mut line : Int
  /// The current position.
  priv mut cur_pos : Position
  /// Whether EOF was reached.
  priv mut eof : Bool
  /// The headers (raw fields), once read.
  priv mut headers : Array[Bytes]?
  /// The position of the header record.
  priv mut headers_pos : Position?
  /// Whether the first record was yielded.
  priv mut first : Bool
  /// The number of fields of the first record.
  priv mut first_field_count : Int?
}

///|
/// Create a reader over `data` (upstream `ReaderBuilder::new()
/// .has_headers(..).delimiter(..).from_reader(..)`).
pub fn Reader::new(
  data : Bytes,
  delimiter~ : Byte,
  has_headers~ : Bool,
) -> Reader {
  {
    data,
    delimiter,
    has_headers,
    index: 0,
    nfa_state: StartRecord,
    has_read: false,
    line: 1,
    cur_pos: { byte: 0, line: 1, record: 0, },
    eof: false,
    headers: None,
    headers_pos: None,
    first: false,
    first_field_count: None,
  }
}

///|
fn is_term(c : Byte) -> Bool {
  c == b'\r' || c == b'\n'
}

///|
/// Compute the final NFA transition after all input has been exhausted.
fn transition_final_nfa(state : NfaState) -> NfaState {
  match state {
    End | StartRecord | EndRecord | CRLF => End
    StartField
    | EndFieldDelim
    | EndFieldTerm
    | InField
    | InQuotedField
    | InDoubleEscapedQuote
    | InRecordTerm => EndRecord
  }
}

///|
/// Compute the next NFA state given the current NFA state and the current
/// input byte.
fn Reader::transition_nfa(
  self : Reader,
  state : NfaState,
  c : Byte,
) -> (NfaState, NfaInputAction) {
  match state {
    End => (End, Epsilon)
    StartRecord =>
      if is_term(c) {
        (StartRecord, Discard)
      } else {
        (StartField, Epsilon)
      }
    EndRecord => (StartRecord, Epsilon)
    StartField =>
      if c == b'"' {
        (InQuotedField, Discard)
      } else if c == self.delimiter {
        (EndFieldDelim, Discard)
      } else if is_term(c) {
        (EndFieldTerm, Epsilon)
      } else {
        (InField, CopyToOutput)
      }
    EndFieldDelim => (StartField, Epsilon)
    EndFieldTerm => (InRecordTerm, Epsilon)
    InField =>
      if c == self.delimiter {
        (EndFieldDelim, Discard)
      } else if is_term(c) {
        (EndFieldTerm, Epsilon)
      } else {
        (InField, CopyToOutput)
      }
    InQuotedField =>
      if c == b'"' {
        (InDoubleEscapedQuote, Discard)
      } else {
        (InQuotedField, CopyToOutput)
      }
    InDoubleEscapedQuote =>
      if c == b'"' {
        (InQuotedField, CopyToOutput)
      } else if c == self.delimiter {
        (EndFieldDelim, Discard)
      } else if is_term(c) {
        (EndFieldTerm, Epsilon)
      } else {
        (InField, CopyToOutput)
      }
    InRecordTerm =>
      if c == b'\r' {
        (CRLF, Discard)
      } else {
        (EndRecord, Discard)
      }
    CRLF =>
      if c == b'\n' {
        (StartRecord, Discard)
      } else {
        (StartRecord, Epsilon)
      }
  }
}

///|
/// Read a byte record from the input, without accounting for headers
/// (upstream `Reader::read_byte_record_impl`). Returns the fields and the
/// record's position, or `None` fields at EOF.
fn Reader::read_byte_record_impl(
  self : Reader,
) -> (Array[Bytes]?, Position) raise CsvError {
  let pos = self.cur_pos
  if self.eof {
    return (None, pos)
  }
  // Strip off a possible UTF-8 BOM at the start of the input.
  if !self.has_read {
    self.has_read = true
    if self.data.length() >= 3 &&
      self.data[0] == b'\xef' &&
      self.data[1] == b'\xbb' &&
      self.data[2] == b'\xbf' {
      self.index = 3
    }
  }
  let fields : Array[Bytes] = []
  let field = Buffer()
  let mut state = self.nfa_state
  let mut complete = false
  while self.index < self.data.length() {
    let c = self.data[self.index]
    let (s, io) = self.transition_nfa(state, c)
    match io {
      CopyToOutput => {
        field.write_byte(c)
        self.consume(c)
      }
      Discard => self.consume(c)
      Epsilon => ()
    }
    state = s
    if state.is_field_final() {
      fields.push(field.to_bytes())
      field.reset()
      if state != EndFieldDelim {
        complete = true
        break
      }
    }
  }
  if !complete {
    // The input is exhausted.
    let s = transition_final_nfa(state)
    state = s
    if s == End {
      self.nfa_state = s
      self.eof = true
      self.cur_pos = { ..self.cur_pos, byte: self.index, line: self.line, }
      return (None, pos)
    }
    fields.push(field.to_bytes())
  }
  self.nfa_state = state
  self.cur_pos = { ..self.cur_pos, byte: self.index, line: self.line, }
  self.add_record(fields, pos)
  (Some(fields), pos)
}

///|
fn Reader::consume(self : Reader, c : Byte) -> Unit {
  self.index += 1
  if c == b'\n' {
    self.line += 1
  }
}

///|
/// Upstream `ReaderState::add_record`.
fn Reader::add_record(
  self : Reader,
  record : Array[Bytes],
  pos : Position,
) -> Unit raise CsvError {
  self.cur_pos = { ..self.cur_pos, record: self.cur_pos.record + 1, }
  match self.first_field_count {
    None => self.first_field_count = Some(record.length())
    Some(expected) =>
      if record.length() != expected {
        raise CsvError(
          UnequalLengths(
            pos=Some(pos),
            expected_len=expected,
            len=record.length(),
          ),
        )
      }
  }
}

///|
/// Read a single row as raw byte fields (upstream
/// `Reader::read_byte_record`). Returns `None` when no more records could be
/// read.
fn Reader::read_byte_record(
  self : Reader,
) -> (Array[Bytes]?, Position) raise CsvError {
  if !self.has_headers && !self.first {
    // If the caller indicated "no headers" and we haven't yielded the first
    // record yet, then we should yield our header row if we have one.
    if self.headers is Some(headers) {
      self.first = true
      let pos = self.headers_pos.unwrap_or(self.cur_pos)
      return (if headers.is_empty() { None } else { Some(headers) }, pos)
    }
  }
  let (record, pos) = self.read_byte_record_impl()
  self.first = true
  if self.headers is None {
    self.headers = Some(record.unwrap_or([]))
    self.headers_pos = Some(pos)
    // If the end user indicated that we have headers, then we should never
    // return the first row. Instead, we should attempt to read and return
    // the next one.
    if self.has_headers {
      return self.read_byte_record_impl()
    }
  }
  (record, pos)
}

///|
/// Validate the UTF-8 of all fields (upstream `ByteRecord::validate`) and
/// decode them.
fn decode_fields(
  fields : Array[Bytes],
  pos : Position?,
) -> Array[String] raise CsvError {
  fields.mapi((i, field) => {
    match utf8_valid_up_to(field) {
      Some(valid_up_to) => raise CsvError(Utf8(pos~, field=i, valid_up_to~))
      None => @utf8.decode(field) catch { _ => panic() }
    }
  })
}

///|
/// Read a single row as strings (upstream `Reader::read_record`). Returns
/// `None` when no more records could be read.
pub fn Reader::read_record(self : Reader) -> Array[String]? raise CsvError {
  // The position before reading, as in upstream `StringRecord::read`.
  let pos = self.cur_pos
  let (record, _) = self.read_byte_record()
  match record {
    None => None
    Some(fields) => Some(decode_fields(fields, Some(pos)))
  }
}

///|
/// Returns the first row (upstream `Reader::headers`). If no row has been
/// read yet, then this will force parsing of the first row. If the input
/// is empty, this returns an empty record.
pub fn Reader::headers(self : Reader) -> Array[String] raise CsvError {
  if self.headers is None {
    let (record, pos) = self.read_byte_record_impl()
    self.headers = Some(record.unwrap_or([]))
    self.headers_pos = Some(pos)
  }
  decode_fields(self.headers.unwrap(), self.headers_pos)
}

///|
/// The index up to which `bytes` is valid UTF-8, or `None` if it is all
/// valid (like Rust's `Utf8Error::valid_up_to`).
fn utf8_valid_up_to(bytes : Bytes) -> Int? {
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let first = bytes[i].to_int()
    if first < 0x80 {
      i += 1
      continue
    }
    let width = if first >= 0xC2 && first <= 0xDF {
      2
    } else if first >= 0xE0 && first <= 0xEF {
      3
    } else if first >= 0xF0 && first <= 0xF4 {
      4
    } else {
      return Some(i)
    }
    if i + 1 >= n {
      return Some(i)
    }
    let second = bytes[i + 1].to_int()
    let second_ok = match width {
      2 => second >= 0x80 && second <= 0xBF
      3 =>
        (first == 0xE0 && second >= 0xA0 && second <= 0xBF) ||
        (first >= 0xE1 && first <= 0xEC && second >= 0x80 && second <= 0xBF) ||
        (first == 0xED && second >= 0x80 && second <= 0x9F) ||
        (first >= 0xEE && first <= 0xEF && second >= 0x80 && second <= 0xBF)
      _ =>
        (first == 0xF0 && second >= 0x90 && second <= 0xBF) ||
        (first >= 0xF1 && first <= 0xF3 && second >= 0x80 && second <= 0xBF) ||
        (first == 0xF4 && second >= 0x80 && second <= 0x8F)
    }
    if !second_ok {
      return Some(i)
    }
    for k in 2..<width {
      if i + k >= n {
        return Some(i)
      }
      let b = bytes[i + k].to_int()
      if b < 0x80 || b > 0xBF {
        return Some(i)
      }
    }
    i += width
  }
  None
}
