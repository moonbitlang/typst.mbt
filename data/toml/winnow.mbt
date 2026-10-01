// A minimal emulation of the parts of `winnow` 0.7.1 that `toml_edit`'s
// parser uses. Parsers are plain functions `(Input) -> T raise ErrMode`; the
// helpers below reproduce winnow's combinator semantics exactly where they
// matter for error reporting: which errors are recoverable (`Backtrack`) or
// fatal (`Cut`), which context is attached, and -- most importantly -- where
// the input is left when an error propagates (the final error offset is the
// position of the input at that point, see `Parser::parse`).

///|
/// `winnow::error::StrContextValue`.
priv enum StrContextValue {
  CharLiteral(Char)
  StringLiteral(String)
  Description(String)
}

///|
/// `winnow::error::StrContext`.
priv enum StrContext {
  Label(String)
  Expected(StrContextValue)
}

///|
/// `winnow::error::ContextError<StrContext>`: the accumulated context (in the
/// order it was added, i.e. innermost first) and an optional external cause
/// (stored as its `Display` output).
priv struct ContextError {
  context : Array[StrContext]
  cause : String?
}

///|
fn ContextError::new() -> ContextError {
  { context: [], cause: None, }
}

///|
/// `ContextError::from_external_error`.
fn ContextError::external(cause : String) -> ContextError {
  { context: [], cause: Some(cause), }
}

///|
/// `winnow::error::ErrMode` (without `Incomplete`, which complete parsers
/// never produce).
priv suberror ErrMode {
  Backtrack(ContextError)
  Cut(ContextError)
}

///|
fn ErrMode::inner(self : ErrMode) -> ContextError {
  match self {
    Backtrack(e) | Cut(e) => e
  }
}

///|
/// A fresh recoverable error (`ParserError::from_input`).
fn backtrack() -> ErrMode {
  Backtrack(ContextError::new())
}

///|
/// The parser input: the UTF-8 bytes of the document, the current offset and
/// the recursion-check state (`RecursionCheck`), which -- like winnow's
/// `Stateful` -- is not restored by checkpoints.
priv struct Input {
  bytes : Bytes
  mut pos : Int
  mut depth : Int
}

///|
fn Input::new(bytes : Bytes) -> Input {
  { bytes, pos: 0, depth: 0, }
}

///|
fn Input::at_eof(self : Input) -> Bool {
  self.pos >= self.bytes.length()
}

///|
/// The byte at `pos + k`, or `-1` past the end.
fn Input::byte_at(self : Input, k : Int) -> Int {
  let p = self.pos + k
  if p < self.bytes.length() {
    self.bytes[p].to_int()
  } else {
    -1
  }
}

///|
/// Decodes the bytes `start..end` (always on char boundaries) as a string.
fn Input::slice(self : Input, start : Int, end : Int) -> String {
  @utf8.decode_lossy(self.bytes[start:end])
}

///|
/// `peek(any)`: the next byte without consuming it.
fn peek_any(i : Input) -> Int raise ErrMode {
  if i.at_eof() {
    raise backtrack()
  }
  i.byte_at(0)
}

///|
/// `any`: consumes and returns the next byte.
fn any(i : Input) -> Int raise ErrMode {
  if i.at_eof() {
    raise backtrack()
  }
  let b = i.byte_at(0)
  i.pos += 1
  b
}

///|
/// `one_of(set)` (`any.verify(..)`): does not advance on failure.
fn one_of(i : Input, pred : (Int) -> Bool) -> Int raise ErrMode {
  if i.at_eof() || !pred(i.byte_at(0)) {
    raise backtrack()
  }
  let b = i.byte_at(0)
  i.pos += 1
  b
}

///|
/// `one_of(byte)` / a byte literal parser.
fn byte(i : Input, b : Int) -> Unit raise ErrMode {
  ignore(one_of(i, c => c == b))
}

///|
/// A literal (ASCII) token; does not advance on failure.
fn literal(i : Input, s : String) -> Unit raise ErrMode {
  let n = s.length()
  for k in 0..<n {
    if i.byte_at(k) != s[k].to_int() {
      raise backtrack()
    }
  }
  i.pos += n
}

///|
/// Whether the input continues with the literal `s`.
fn Input::starts_with(self : Input, s : String) -> Bool {
  for k in 0..<s.length() {
    if self.byte_at(k) != s[k].to_int() {
      return false
    }
  }
  true
}

///|
/// `take_while(0.., set)`: returns the start offset of the taken slice.
fn take_while0(i : Input, pred : (Int) -> Bool) -> Int {
  let start = i.pos
  while !i.at_eof() && pred(i.byte_at(0)) {
    i.pos += 1
  }
  start
}

///|
/// `take_while(1.., set)`: fails without advancing if nothing matches.
fn take_while1(i : Input, pred : (Int) -> Bool) -> Int raise ErrMode {
  let start = take_while0(i, pred)
  if i.pos == start {
    raise backtrack()
  }
  start
}

///|
/// `take_while(m..=n, set)`: fails without advancing if fewer than `m` match.
fn take_while_m_n(
  i : Input,
  m : Int,
  n : Int,
  pred : (Int) -> Bool,
) -> Int raise ErrMode {
  let start = i.pos
  let mut count = 0
  while count < n && i.pos + count < i.bytes.length() && pred(i.byte_at(count)) {
    count += 1
  }
  if count < m {
    raise backtrack()
  }
  i.pos = start + count
  start
}

///|
/// `eof`.
fn eof(i : Input) -> Unit raise ErrMode {
  if !i.at_eof() {
    raise backtrack()
  }
}

///|
/// `opt(parser)`: resets the input on a recoverable error.
fn[T] opt(i : Input, p : (Input) -> T raise ErrMode) -> T? raise ErrMode {
  let start = i.pos
  try p(i) catch {
    Backtrack(_) => {
      i.pos = start
      None
    }
    e => raise e
  } noraise {
    v => Some(v)
  }
}

///|
/// `peek(parser)`: always resets the input.
fn[T] peek(i : Input, p : (Input) -> T raise ErrMode) -> T raise ErrMode {
  let start = i.pos
  defer {
    i.pos = start
  }
  p(i)
}

///|
/// `cut_err(parser)`.
fn[T] cut_err(i : Input, p : (Input) -> T raise ErrMode) -> T raise ErrMode {
  p(i) catch {
    Backtrack(e) => raise Cut(e)
    e => raise e
  }
}

///|
/// `parser.context(c1).context(c2)...`: adds the contexts (in order) to both
/// recoverable and fatal errors.
fn[T] context(
  i : Input,
  p : (Input) -> T raise ErrMode,
  ctx : Array[StrContext],
) -> T raise ErrMode {
  p(i) catch {
    Backtrack(e) => {
      e.context.append(ctx)
      raise Backtrack(e)
    }
    Cut(e) => {
      e.context.append(ctx)
      raise Cut(e)
    }
  }
}

///|
/// `alt((p1, p2, ...))`: the input is reset before each alternative; when all
/// alternatives backtrack, the last error wins and the input is left where
/// the last alternative left it.
fn[T] alt(i : Input, ps : Array[(Input) -> T raise ErrMode]) -> T raise ErrMode {
  let start = i.pos
  let mut err : ErrMode? = None
  for k, p in ps {
    if k > 0 {
      i.pos = start
    }
    try p(i) catch {
      Backtrack(e) => err = Some(Backtrack(e))
      e => raise e
    } noraise {
      v => return v
    }
  }
  match err {
    Some(e) => raise e
    None => raise backtrack()
  }
}

///|
/// `repeat(0.., parser)` (with the accumulated output discarded).
fn repeat0(i : Input, p : (Input) -> Unit raise ErrMode) -> Unit raise ErrMode {
  for ;; {
    let start = i.pos
    try p(i) catch {
      Backtrack(_) => {
        i.pos = start
        return
      }
      e => raise e
    } noraise {
      _ =>
        // infinite loop check (`ParserError::assert` in release builds)
        if i.pos == start {
          raise Cut(ContextError::new())
        }
    }
  }
}

///|
/// `repeat(1.., parser)`.
fn repeat1(i : Input, p : (Input) -> Unit raise ErrMode) -> Unit raise ErrMode {
  p(i)
  repeat0(i, p)
}

///|
/// `separated(1.., parser, sep)`.
fn[T] separated1(
  i : Input,
  p : (Input) -> T raise ErrMode,
  sep : (Input) -> Unit raise ErrMode,
) -> Array[T] raise ErrMode {
  let acc = [p(i)]
  separated_rest(i, p, sep, acc)
}

///|
/// `separated(0.., parser, sep)`.
fn[T] separated0(
  i : Input,
  p : (Input) -> T raise ErrMode,
  sep : (Input) -> Unit raise ErrMode,
) -> Array[T] raise ErrMode {
  let start = i.pos
  let first = p(i) catch {
    Backtrack(_) => {
      i.pos = start
      return []
    }
    e => raise e
  }
  separated_rest(i, p, sep, [first])
}

///|
fn[T] separated_rest(
  i : Input,
  p : (Input) -> T raise ErrMode,
  sep : (Input) -> Unit raise ErrMode,
  acc : Array[T],
) -> Array[T] raise ErrMode {
  for ;; {
    let start = i.pos
    try sep(i) catch {
      Backtrack(_) => {
        i.pos = start
        return acc
      }
      e => raise e
    } noraise {
      _ => ()
    }
    if i.pos == start {
      raise Cut(ContextError::new())
    }
    try p(i) catch {
      Backtrack(_) => {
        i.pos = start
        return acc
      }
      e => raise e
    } noraise {
      v => acc.push(v)
    }
  }
}

///|
/// Reports a failed `try_map`/`verify`: winnow resets the input to where the
/// mapped parser started and raises a recoverable error carrying the cause.
fn map_failure(i : Input, start : Int, cause : String?) -> ErrMode {
  i.pos = start
  Backtrack({ context: [], cause, })
}
