// Port of the data-loading part of upstream `typst-library/src/diag.rs`:
// `LoadError`, `LoadedWithin`, `ReportTextPos`, `LineCol` and
// `format_xml_like_error`.

///|
/// A call site independent error that occurred during data loading. This
/// avoids polluting the memoization with spans and file ids from source
/// files. Can be turned into a [SourceDiagnostic] using [LoadError::within].
pub(all) struct LoadError {
  /// The position in the file at which the error occurred, or `None` for
  /// binary sources.
  text_pos : ReportTextPos?
  /// Must contain a message formatted like this: `"failed to do thing
  /// (cause)"`.
  message : String
} derive(Eq, Hash, Debug)

///|
/// A data-loading error (upstream `LoadResult<T>`'s error).
pub(all) suberror LoadErr {
  LoadErr(LoadError)
} derive(Debug)

///|
/// Creates a new error from a position in a text file, a base message (e.g.
/// `failed to parse JSON`) and a concrete error (e.g. `invalid number`).
pub fn LoadError::text(
  pos : ReportTextPos,
  message : String,
  error : String,
) -> LoadError {
  { text_pos: Some(pos), message: "\{message} (\{error})" }
}

///|
/// Creates a new error from a base message (e.g. `failed to parse PDF`) and
/// a concrete error (e.g. `invalid number`). For use with binary sources,
/// which do not have useful position information.
pub fn LoadError::binary(message : String, error : String) -> LoadError {
  { text_pos: None, message: "\{message} (\{error})" }
}

///|
/// Upstream `impl From<Utf8Error> for LoadError`.
pub fn LoadError::from_utf8_error(err : Utf8Error) -> LoadError {
  let start = err.valid_up_to
  let end = start + err.error_len.unwrap_or(0)
  LoadError::text(
    Range(start, end),
    "failed to convert to string",
    "file is not valid UTF-8",
  )
}

///|
/// Report an error, possibly in an external file (upstream
/// `LoadedWithin::within`).
pub fn LoadError::within(self : LoadError, loaded : Loaded) -> SourceDiagnostic {
  match self.text_pos {
    Some(pos) => load_err_in_text(loaded, pos, self.message)
    None => load_err_in_binary(loaded, None, self.message)
  }
}

///|
/// Run `f` and convert its [LoadErr] into a [SourceError] by adding the
/// [Loaded] context (upstream `Result::within`).
pub fn[T] within(loaded : Loaded, f : () -> T raise LoadErr) -> T raise SourceError {
  f() catch {
    LoadErr(err) => raise SourceError([err.within(loaded)])
  }
}

///|
/// Report an error, possibly in an external file. This will delegate to
/// [load_err_in_binary] if the data isn't valid UTF-8.
fn load_err_in_text(
  loaded : Loaded,
  pos : ReportTextPos,
  message : String,
) -> SourceDiagnostic {
  // This also does UTF-8 validation. Only report an error in an external
  // file if it is human readable (valid UTF-8), otherwise fall back to
  // `load_err_in_binary`.
  guard bytes_to_str(loaded.data) is Some(text) else {
    return load_err_in_binary(loaded, Some(pos), message)
  }
  let lines = @syntax.Lines::new(text)
  match loaded.source.v {
    Path(file_id) => {
      if pos.range(lines) is Some((start, end)) {
        let span = @syntax.DiagSpan::from_range(file_id, start, end)
        return SourceDiagnostic::error(span, message)
      }

      // Either `ReportPos::None` was provided, or resolving the range from
      // the line/column failed. If present report the possibly wrong
      // line/column in the error message anyway.
      let span = @syntax.DiagSpan::from_range(
        file_id,
        0,
        loaded.data.length(),
      )
      let message = match pos.line_col(lines) {
        Some(pair) => {
          let (line, col) = pair.numbers()
          pop_char(message) + " at \{line}:\{col})"
        }
        None => message
      }
      SourceDiagnostic::error(span, message)
    }
    Bytes => {
      let message = match pos.line_col(lines) {
        Some(pair) => {
          let (line, col) = pair.numbers()
          pop_char(message) + " at \{line}:\{col})"
        }
        None => message
      }
      SourceDiagnostic::error_at(loaded.source.span, message)
    }
  }
}

///|
/// Report an error (possibly from an external file) that isn't valid UTF-8.
fn load_err_in_binary(
  loaded : Loaded,
  pos : ReportTextPos?,
  message : String,
) -> SourceDiagnostic {
  let line_col = match pos {
    Some(pos) => pos.try_line_col(loaded.data).map(p => p.numbers())
    None => None
  }
  let mut message = message
  match loaded.source.v {
    Path(file) => {
      message = pop_char(message)
      match file.root() {
        Project => message = message + " in \{file.vpath().get_without_slash()}"
        Package(spec) =>
          message = message + " in \{spec}\{file.vpath().get_with_slash()}"
      }
      if line_col is Some((line, col)) {
        message = message + ":\{line}:\{col}"
      }
      message = message + ")"
    }
    Bytes =>
      if line_col is Some((line, col)) {
        message = pop_char(message) + " at \{line}:\{col})"
      }
  }
  SourceDiagnostic::error_at(loaded.source.span, message)
}

///|
/// Remove the last character of a string (upstream `EcoString::pop`).
fn pop_char(s : String) -> String {
  if s.is_empty() {
    return s
  }
  let mut end = s.length() - 1
  if end > 0 && s.code_unit_at(end).is_trailing_surrogate() {
    end -= 1
  }
  s.unsafe_substring(start=0, end~)
}

///|
/// A position in a text document at which an error was reported.
pub(all) enum ReportTextPos {
  /// Contains a range, and a line/column pair.
  Full(Int, Int, LineCol)
  /// Contains a range.
  Range(Int, Int)
  /// Contains a line/column pair.
  LineCol(LineCol)
  /// No position (upstream `ReportTextPos::None`, renamed to avoid clashing
  /// with `Value::None`).
  NoPos
} derive(Eq, Hash, Debug)

///|
/// Creates a position from a pre-existing range and line-column pair.
pub fn ReportTextPos::full(start : Int, end : Int, pair : LineCol) -> ReportTextPos {
  Full(start, end, pair)
}

///|
/// Tries to determine the byte range for this position.
fn ReportTextPos::range(self : ReportTextPos, lines : @syntax.Lines) -> (Int, Int)? {
  match self {
    Full(start, end, _) => Some((start, end))
    Range(start, end) => Some((start, end))
    LineCol(pair) =>
      match lines.line_column_to_byte(pair.line, pair.col) {
        Some(i) => Some((i, i))
        None => None
      }
    NoPos => None
  }
}

///|
/// Tries to determine the line/column for this position.
fn ReportTextPos::line_col(
  self : ReportTextPos,
  lines : @syntax.Lines,
) -> LineCol? {
  match self {
    Full(_, _, pair) => Some(pair)
    Range(start, _) =>
      match lines.byte_to_line_column(start) {
        Some((line, col)) => Some(LineCol::zero_based(line, col))
        None => None
      }
    LineCol(pair) => Some(pair)
    NoPos => None
  }
}

///|
/// Either gets the line/column pair, or tries to compute it from possibly
/// invalid UTF-8 data.
fn ReportTextPos::try_line_col(self : ReportTextPos, bytes : Bytes) -> LineCol? {
  match self {
    Full(_, _, pair) => Some(pair)
    Range(start, _) => LineCol::try_from_byte_pos(start, bytes)
    LineCol(pair) => Some(pair)
    NoPos => None
  }
}

///|
/// A line/column pair.
pub(all) struct LineCol {
  /// The 0-based line.
  line : Int
  /// The 0-based column.
  col : Int
} derive(Eq, Hash, Debug)

///|
/// Constructs the line/column pair from 0-based indices.
pub fn LineCol::zero_based(line : Int, col : Int) -> LineCol {
  { line, col }
}

///|
/// Constructs the line/column pair from 1-based numbers.
pub fn LineCol::one_based(line : Int, col : Int) -> LineCol {
  LineCol::zero_based(saturating_sub1(line), saturating_sub1(col))
}

///|
fn saturating_sub1(x : Int) -> Int {
  if x > 0 {
    x - 1
  } else {
    0
  }
}

///|
/// Try to compute a line/column pair from possibly invalid UTF-8 data.
pub fn LineCol::try_from_byte_pos(pos : Int, bytes : Bytes) -> LineCol? {
  let pos = if pos > bytes.length() { bytes.length() } else { pos }
  let mut line = 0
  let mut last_newline = -1
  for i in 0..<pos {
    if bytes[i] == b'\n' {
      line += 1
      last_newline = i
    }
  }
  // Like upstream, the line start falls back to the end of the prefix if
  // there is no newline.
  let line_start = if last_newline >= 0 { last_newline + 1 } else { pos }
  let col = count_utf8_chars_lossy(bytes, line_start, pos)
  Some(LineCol::zero_based(line, col))
}

///|
/// Returns the 0-based line/column indices.
pub fn LineCol::indices(self : LineCol) -> (Int, Int) {
  (self.line, self.col)
}

///|
/// Returns the 1-based line/column numbers.
pub fn LineCol::numbers(self : LineCol) -> (Int, Int) {
  (self.line + 1, self.col + 1)
}

///|
/// A UTF-8 decoding error (upstream `std::str::Utf8Error`).
pub(all) struct Utf8Error {
  /// The index up to which valid UTF-8 was verified.
  valid_up_to : Int
  /// The length of the invalid byte sequence, or `None` if the end of the
  /// input was reached unexpectedly.
  error_len : Int?
} derive(Eq, Debug)

///|
/// Validate UTF-8 like Rust's `std::str::from_utf8`.
pub fn validate_utf8(bytes : BytesView) -> Utf8Error? {
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
      0
    }
    let err = fn(len : Int?) { Some({ valid_up_to: i, error_len: len }) }
    if width == 0 {
      return err(Some(1))
    }
    if i + 1 >= n {
      return err(None)
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
      return err(Some(1))
    }
    for k in 2..<width {
      if i + k >= n {
        return err(None)
      }
      let b = bytes[i + k].to_int()
      if b < 0x80 || b > 0xBF {
        return err(Some(k))
      }
    }
    i += width
  }
  None
}

///|
/// Decode UTF-8 bytes into a string, or `None` if they are invalid.
pub fn bytes_to_str(bytes : BytesView) -> String? {
  if validate_utf8(bytes) is Some(_) {
    return None
  }
  Some(@utf8.decode(bytes)) catch {
    _ => None
  }
}

///|
/// Decode UTF-8 bytes into a string (upstream `Bytes::to_str` /
/// `Bytes::as_str` with a `LoadError` from the `Utf8Error`).
pub fn bytes_as_str(bytes : BytesView) -> String raise LoadErr {
  match validate_utf8(bytes) {
    Some(err) => raise LoadErr(LoadError::from_utf8_error(err))
    None => @utf8.decode(bytes) catch { _ => panic() }
  }
}

///|
/// Count the characters of `bytes[start..end]`, counting each maximal
/// invalid subsequence as one item (upstream `ErrorReportingUtf8Chars`).
fn count_utf8_chars_lossy(bytes : Bytes, start : Int, end : Int) -> Int {
  let mut count = 0
  let mut i = start
  while i < end {
    let view = bytes[i:end]
    match validate_utf8(view) {
      None => {
        // Count the characters of the valid rest.
        for j in 0..<view.length() {
          if (view[j].to_int() & 0xC0) != 0x80 {
            count += 1
          }
        }
        break
      }
      Some(err) => {
        for j in 0..<err.valid_up_to {
          if (view[j].to_int() & 0xC0) != 0x80 {
            count += 1
          }
        }
        // The invalid sequence counts as one item.
        count += 1
        i += err.valid_up_to + err.error_len.unwrap_or(end - i - err.valid_up_to)
      }
    }
  }
  count
}

