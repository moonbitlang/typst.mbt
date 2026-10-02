// Port of `hayagriva/src/types/strings.rs`.

///|
/// A string for presentation.
///
/// It can contain an optional short version and control case folding.
pub(all) struct FormatString {
  /// The canonical version of the string.
  value : ChunkedString
  /// The short version of the string.
  short : ChunkedString?
} derive(Eq, Hash, Debug)

///|
/// Creates a new empty `FormatStr`.
pub fn FormatString::new() -> FormatString {
  { value: ChunkedString::new(), short: None }
}

///|
/// Creates a new `FormatStr` for the value string.
pub fn FormatString::with_value(value : String) -> FormatString {
  { value: ChunkedString::from_chunk(StringChunk::normal(value)), short: None }
}

///|
/// Creates a new `FormatStr` from a long and a short string.
pub fn FormatString::with_short(value : String, short : String) -> FormatString {
  {
    value: ChunkedString::from_chunk(StringChunk::normal(value)),
    short: Some(ChunkedString::from_chunk(StringChunk::normal(short))),
  }
}

///|
/// Format this formattable string in title case.
pub fn FormatString::format_title_case(
  self : FormatString,
  props : TitleCase,
) -> String {
  self.value.format_title_case(props)
}

///|
/// Format this formattable string in sentence case.
pub fn FormatString::format_sentence_case(
  self : FormatString,
  props : SentenceCase,
) -> String {
  self.value.format_sentence_case(props)
}

///|
/// Returns the right variant for the given form.
pub fn FormatString::select(
  self : FormatString,
  form : @citationberg.LongShortForm,
) -> ChunkedString {
  match form {
    Long => self.value
    Short => self.short.unwrap_or(self.value)
  }
}

///|
pub impl Show for FormatString with output(self, logger) {
  logger.write_string(self.value.to_string())
}

///|
/// `impl FromStr for FormatString`.
pub fn FormatString::from_str(s : String) -> Result[FormatString, ChunkedStrParseError] {
  match ChunkedString::from_str(s) {
    Ok(value) => Ok({ value, short: None })
    Err(e) => Err(e)
  }
}

///|
/// A string whose elements can set whether they do case folding.
pub(all) struct ChunkedString(Array[StringChunk]) derive(Eq, Hash, Debug)

///|
/// Creates a new empty `ChunkedString`.
pub fn ChunkedString::new() -> ChunkedString {
  ChunkedString([])
}

///|
/// `impl From<StringChunk> for ChunkedString`.
pub fn ChunkedString::from_chunk(chunk : StringChunk) -> ChunkedString {
  ChunkedString([chunk])
}

///|
/// `impl From<String> for ChunkedString`.
pub fn ChunkedString::from_string(s : String) -> ChunkedString {
  ChunkedString::from_chunk(StringChunk::normal(s))
}

///|
/// A deep copy of the string.
pub fn ChunkedString::copy(self : ChunkedString) -> ChunkedString {
  ChunkedString(self.0.map(c => { value: c.value, kind: c.kind }))
}

///|
/// Appends a string to the last chunk if it has the same kind or starts a
/// new chunk if the types differ.
pub fn ChunkedString::push_str(
  self : ChunkedString,
  s : String,
  kind : ChunkKind,
) -> Unit {
  match self.0.last() {
    Some(last) if last.kind == kind => last.value = last.value + s
    _ => self.0.push(StringChunk::new(s, kind))
  }
}

///|
/// Appends a character to the last chunk if it has the same kind or starts
/// a new chunk if the types differ.
pub fn ChunkedString::push_char(
  self : ChunkedString,
  c : Char,
  kind : ChunkKind,
) -> Unit {
  self.push_str(c.to_string(), kind)
}

///|
/// Appends a chunk to the end of the string.
pub fn ChunkedString::push_chunk(self : ChunkedString, chunk : StringChunk) -> Unit {
  self.0.push(chunk)
}

///|
/// Returns the string.
pub fn ChunkedString::to_str(self : ChunkedString) -> String {
  if self.0.is_empty() {
    ""
  } else if self.0.length() == 1 {
    self.0[0].value
  } else {
    self.to_string()
  }
}

///|
/// Write the chunked string as a parenthesized string.
pub fn[W : FmtWrite] ChunkedString::fmt_serialized(
  self : ChunkedString,
  buf : W,
) -> Unit {
  for chunk in self.0 {
    chunk.fmt_serialized(buf)
  }
}

///|
/// Return the length of the string (in UTF-8 bytes).
pub fn ChunkedString::len(self : ChunkedString) -> Int {
  let mut n = 0
  for c in self.0 {
    n += c.len()
  }
  n
}

///|
/// Returns whether the string is empty.
pub fn ChunkedString::is_empty(self : ChunkedString) -> Bool {
  self.0.iter().all(c => c.is_empty())
}

///|
/// Extend with another `ChunkedString`.
pub fn ChunkedString::extend_chunks(self : ChunkedString, other : ChunkedString) -> Unit {
  self.0.append(other.0)
}

///|
/// Format this formattable string in title case.
pub fn ChunkedString::format_title_case(
  self : ChunkedString,
  props : TitleCase,
) -> String {
  let c = CaseFolder::with_config(Title(props))
  self.fold_case(c)
  c.finish()
}

///|
/// Format this formattable string in sentence case.
pub fn ChunkedString::format_sentence_case(
  self : ChunkedString,
  props : SentenceCase,
) -> String {
  let c = CaseFolder::with_config(Sentence(props))
  self.fold_case(c)
  c.finish()
}

///|
/// Lowercase the string.
pub fn ChunkedString::to_lowercase(self : ChunkedString) -> String {
  let c = CaseFolder::with_config(Lowercase)
  self.fold_case(c)
  c.finish()
}

///|
/// Uppercase the string.
pub fn ChunkedString::to_uppercase(self : ChunkedString) -> String {
  let c = CaseFolder::with_config(Uppercase)
  self.fold_case(c)
  c.finish()
}

///|
/// Apply case-folding.
pub fn ChunkedString::fold_case(self : ChunkedString, c : CaseFolder) -> Unit {
  let config = c.case()
  for chunk in self.0 {
    match chunk.kind {
      Normal => c.reconfigure(config)
      Verbatim | Math => c.reconfigure(NoTransform)
    }
    c.push_str(chunk.value)
  }
}

///|
/// Check whether this is a control character for [`ChunkedString`].
fn is_chunk_control(c : Char) -> Bool {
  c == '\\' || c == '{' || c == '}' || c == '$'
}

///|
/// Error that occurs when parsing a [`ChunkedString`].
///
/// Occurs when there are unbalanced braces. The field contains the position
/// of the unmatched closing brace.
pub(all) struct ChunkedStrParseError(Int) derive(Eq, Debug)

///|
pub impl Show for ChunkedStrParseError with output(self, logger) {
  logger.write_string("unmatched closing brace at position \{self.0}")
}

///|
/// `impl FromStr for ChunkedString`.
pub fn ChunkedString::from_str(
  s : String,
) -> Result[ChunkedString, ChunkedStrParseError] {
  let s = @unscanny.Scanner::new(s)
  let chunks = ChunkedString::new()
  let mut kind : ChunkKind = Normal
  let mut depth = 0
  while s.eat() is Some(c) {
    if c == '\\' && s.peek() is Some(p) && is_chunk_control(p) {
      chunks.push_char(s.eat().unwrap(), kind)
      continue
    }
    match c {
      '{' if kind != Math => {
        depth += 1
        kind = Verbatim
      }
      '}' if kind != Math => {
        if depth == 0 {
          let pos = s.cursor() - 1
          return Err(ChunkedStrParseError(if pos < 0 { 0 } else { pos }))
        }
        depth -= 1
        if depth == 0 {
          kind = Normal
        }
      }
      '$' if kind == Math => kind = if depth > 0 { Verbatim } else { Normal }
      '$' => kind = Math
      _ => chunks.push_char(c, kind)
    }
  }
  Ok(chunks)
}

///|
pub impl FmtWrite for ChunkedString with write_str(self, s) {
  self.push_str(s, Normal)
}

///|
pub impl FmtWrite for ChunkedString with write_char(self, c) {
  self.push_char(c, Normal)
}

///|
pub impl Show for ChunkedString with output(self, logger) {
  for chunk in self.0 {
    logger.write_string(chunk.to_string())
  }
}

///|
/// A chunk of a string.
pub(all) struct StringChunk {
  /// The string value.
  mut value : String
  /// Whether the chunk is subject to case folding or contains math.
  kind : ChunkKind
} derive(Eq, Hash, Debug)

///|
/// Creates a new `StrChunk` from a string and a kind.
pub fn StringChunk::new(value : String, kind : ChunkKind) -> StringChunk {
  { value, kind }
}

///|
/// Creates a new `StrChunk` with the `ChunkKind::Normal` kind.
pub fn StringChunk::normal(value : String) -> StringChunk {
  { value, kind: Normal }
}

///|
/// Creates a new `StrChunk` with the `ChunkKind::Verbatim` kind.
pub fn StringChunk::verbatim(value : String) -> StringChunk {
  { value, kind: Verbatim }
}

///|
/// Creates a new `StrChunk` with the `ChunkKind::Math` kind.
pub fn StringChunk::math(value : String) -> StringChunk {
  { value, kind: Math }
}

///|
/// Return the length of the string value (in UTF-8 bytes).
pub fn StringChunk::len(self : StringChunk) -> Int {
  @unscanny.len_utf8(self.value)
}

///|
/// Returns whether the chunk is empty.
pub fn StringChunk::is_empty(self : StringChunk) -> Bool {
  self.value.is_empty()
}

///|
pub impl Show for StringChunk with output(self, logger) {
  if self.kind == Math {
    logger.write_string("$" + self.value + "$")
  } else {
    logger.write_string(self.value)
  }
}

///|
/// Writes the chunk as a parenthesized string.
fn[W : FmtWrite] StringChunk::fmt_serialized(self : StringChunk, buf : W) -> Unit {
  fn write_escaped(val : StringChunk, buf : W) -> Unit {
    for c in val.value {
      if is_chunk_control(c) {
        buf.write_char('\\')
      }
      buf.write_char(c)
    }
  }

  match self.kind {
    Normal => write_escaped(self, buf)
    Verbatim => {
      buf.write_char('{')
      write_escaped(self, buf)
      buf.write_char('}')
    }
    Math => {
      buf.write_char('$')
      write_escaped(self, buf)
      buf.write_char('$')
    }
  }
}

///|
/// The kind of a string chunk.
pub(all) enum ChunkKind {
  /// Case-folding will be applied.
  Normal
  /// Case-folding will not be applied.
  Verbatim
  /// The contained markup is expected to be evaluated using Typst.
  Math
} derive(Eq, Hash, Debug)
