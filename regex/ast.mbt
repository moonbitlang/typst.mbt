// Port of the abstract syntax of `regex-syntax` (`ast/mod.rs`), reduced to
// what the translator needs.

///|
/// A position in the pattern. `offset` is a UTF-16 index (upstream: byte
/// offset); `line` and `column` are 1-based, columns count chars.
priv struct Position {
  offset : Int
  line : Int
  column : Int
} derive(Eq, Compare)

///|
/// A span of the pattern.
priv struct Span {
  start : Position
  end : Position
} derive(Eq, Compare)

///|
fn Span::splat(pos : Position) -> Span {
  { start: pos, end: pos, }
}

///|
fn Span::with_end(self : Span, end : Position) -> Span {
  { start: self.start, end, }
}

///|
fn Span::is_one_line(self : Span) -> Bool {
  self.start.line == self.end.line
}

///|
/// The kind of a parse error (upstream `ast::ErrorKind`).
priv enum AstErrorKind {
  ClassEscapeInvalid
  ClassRangeInvalid
  ClassRangeLiteral
  ClassUnclosed
  DecimalInvalid
  EscapeHexEmpty
  EscapeHexInvalid
  EscapeHexInvalidDigit
  EscapeUnexpectedEof
  EscapeUnrecognized
  FlagDanglingNegation
  FlagDuplicate(Span)
  FlagRepeatedNegation(Span)
  FlagUnexpectedEof
  FlagUnrecognized
  GroupNameDuplicate(Span)
  GroupNameEmpty
  GroupNameInvalid
  GroupNameUnexpectedEof
  GroupUnclosed
  GroupUnopened
  NestLimitExceeded(Int)
  RepetitionCountInvalid
  RepetitionCountDecimalEmpty
  RepetitionCountUnclosed
  RepetitionMissing
  SpecialWordBoundaryUnclosed
  SpecialWordBoundaryUnrecognized
  SpecialWordOrRepetitionUnexpectedEof
  UnicodeClassInvalid
  UnsupportedBackreference
  UnsupportedLookAround
}

///|
fn AstErrorKind::message(self : AstErrorKind) -> String {
  match self {
    ClassEscapeInvalid => "invalid escape sequence found in character class"
    ClassRangeInvalid =>
      "invalid character class range, the start must be <= the end"
    ClassRangeLiteral => "invalid range boundary, must be a literal"
    ClassUnclosed => "unclosed character class"
    DecimalInvalid => "decimal literal invalid"
    EscapeHexEmpty => "hexadecimal literal empty"
    EscapeHexInvalid => "hexadecimal literal is not a Unicode scalar value"
    EscapeHexInvalidDigit => "invalid hexadecimal digit"
    EscapeUnexpectedEof =>
      "incomplete escape sequence, reached end of pattern prematurely"
    EscapeUnrecognized => "unrecognized escape sequence"
    FlagDanglingNegation => "dangling flag negation operator"
    FlagDuplicate(_) => "duplicate flag"
    FlagRepeatedNegation(_) => "flag negation operator repeated"
    FlagUnexpectedEof => "expected flag but got end of regex"
    FlagUnrecognized => "unrecognized flag"
    GroupNameDuplicate(_) => "duplicate capture group name"
    GroupNameEmpty => "empty capture group name"
    GroupNameInvalid => "invalid capture group character"
    GroupNameUnexpectedEof => "unclosed capture group name"
    GroupUnclosed => "unclosed group"
    GroupUnopened => "unopened group"
    NestLimitExceeded(limit) =>
      "exceed the maximum number of nested parentheses/brackets (\{limit})"
    RepetitionCountInvalid =>
      "invalid repetition count range, the start must be <= the end"
    RepetitionCountDecimalEmpty =>
      "repetition quantifier expects a valid decimal"
    RepetitionCountUnclosed => "unclosed counted repetition"
    RepetitionMissing => "repetition operator missing expression"
    SpecialWordBoundaryUnclosed =>
      "special word boundary assertion is either unclosed or contains an invalid character"
    SpecialWordBoundaryUnrecognized =>
      "unrecognized special word boundary assertion, valid choices are: start, end, start-half or end-half"
    SpecialWordOrRepetitionUnexpectedEof =>
      "found either the beginning of a special word boundary or a bounded repetition on a \\b with an opening brace, but no closing brace"
    UnicodeClassInvalid => "invalid Unicode character class"
    UnsupportedBackreference => "backreferences are not supported"
    UnsupportedLookAround =>
      "look-around, including look-ahead and look-behind, is not supported"
  }
}

///|
/// The auxiliary span of an error, if any.
fn AstErrorKind::aux_span(self : AstErrorKind) -> Span? {
  match self {
    FlagDuplicate(s) | FlagRepeatedNegation(s) | GroupNameDuplicate(s) =>
      Some(s)
    _ => None
  }
}

///|
/// The kind of a translation error (upstream `hir::ErrorKind`).
priv enum HirErrorKind {
  UnicodeNotAllowed
  InvalidUtf8
  UnicodePropertyNotFound
  UnicodePropertyValueNotFound
}

///|
fn HirErrorKind::message(self : HirErrorKind) -> String {
  match self {
    UnicodeNotAllowed => "Unicode not allowed here"
    InvalidUtf8 => "pattern can match invalid UTF-8"
    UnicodePropertyNotFound => "Unicode property not found"
    UnicodePropertyValueNotFound => "Unicode property value not found"
  }
}

///|
/// An error while parsing or compiling a regular expression. The message is
/// formatted exactly like the `Display` of the `regex` crate's error.
pub suberror RegexError {
  RegexError(String)
}

///|
pub impl Show for RegexError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RegexError with Show::{to_string, output}

///|
/// The formatted message of the error.
pub fn RegexError::message(self : RegexError) -> String {
  match self {
    RegexError(msg) => msg
  }
}

///|
/// Raise a formatted syntax error (upstream `regex_syntax::error::Formatter`).
fn[T] syntax_error(
  pattern : String,
  span : Span,
  aux : Span?,
  message : String,
) -> T raise RegexError {
  raise RegexError(format_error(pattern, span, aux, message))
}

///|
/// Rust's `str::lines`.
fn rust_lines(s : String) -> Array[String] {
  let out = []
  let mut start = 0
  for i in 0..<s.length() {
    if s.code_unit_at(i) == '\n' {
      let mut end = i
      if end > start && s.code_unit_at(end - 1) == '\r' {
        end -= 1
      }
      out.push(s.unsafe_substring(start~, end~))
      start = i + 1
    }
  }
  if start < s.length() {
    let mut end = s.length()
    if s.code_unit_at(end - 1) == '\r' {
      end -= 1
    }
    out.push(s.unsafe_substring(start~, end~))
  }
  out
}

///|
fn format_error(
  pattern : String,
  span : Span,
  aux : Span?,
  message : String,
) -> String {
  let lines = rust_lines(pattern)
  let mut line_count = lines.length()
  if pattern.has_suffix("\n") {
    line_count += 1
  }
  let line_number_width = if line_count <= 1 {
    0
  } else {
    line_count.to_string().length()
  }
  let by_line : Array[Array[Span]] = Array::makei(line_count, _ => [])
  let multi_line : Array[Span] = []
  let add = (s : Span) => {
    if s.is_one_line() {
      let i = s.start.line - 1
      by_line[i].push(s)
      by_line[i].sort()
    } else {
      multi_line.push(s)
      multi_line.sort()
    }
  }
  add(span)
  if aux is Some(s) {
    add(s)
  }
  let notated = StringBuilder()
  for i, line in lines {
    if line_number_width > 0 {
      let n = (i + 1).to_string()
      for _ in 0..<(line_number_width - n.length()) {
        notated.write_char(' ')
      }
      notated.write_string(n)
      notated.write_string(": ")
    } else {
      notated.write_string("    ")
    }
    notated.write_string(line)
    notated.write_char('\n')
    if i < by_line.length() && !by_line[i].is_empty() {
      let padding = if line_number_width == 0 {
        4
      } else {
        2 + line_number_width
      }
      for _ in 0..<padding {
        notated.write_char(' ')
      }
      let mut pos = 0
      for s in by_line[i] {
        while pos < s.start.column - 1 {
          notated.write_char(' ')
          pos += 1
        }
        let note_len = s.end.column - s.start.column
        for _ in 0..<(if note_len > 1 { note_len } else { 1 }) {
          notated.write_char('^')
          pos += 1
        }
      }
      notated.write_char('\n')
    }
  }
  let out = StringBuilder()
  if pattern.contains("\n") {
    let divider = String::make(79, '~')
    out.write_string("regex parse error:\n")
    out.write_string(divider + "\n")
    out.write_string(notated.to_string())
    out.write_string(divider + "\n")
    if !multi_line.is_empty() {
      let notes = multi_line.map(s => {
        "on line \{s.start.line} (column \{s.start.column}) through line \{s.end.line} (column \{s.end.column - 1})"
      })
      out.write_string(notes.join("\n") + "\n")
    }
    out.write_string("error: " + message)
  } else {
    out.write_string("regex parse error:\n")
    out.write_string(notated.to_string())
    out.write_string("error: " + message)
  }
  out.to_string()
}

///|
/// A single character literal.
priv struct Literal {
  span : Span
  c : Int
  /// Whether this is a fixed `\xNN` escape (upstream `Literal::byte`).
  hex_x : Bool
}

///|
priv enum AssertionKind {
  StartLine
  EndLine
  StartText
  EndText
  WordBoundary
  NotWordBoundary
  WordBoundaryStart
  WordBoundaryEnd
  WordBoundaryStartAngle
  WordBoundaryEndAngle
  WordBoundaryStartHalf
  WordBoundaryEndHalf
}

///|
priv enum ClassPerlKind {
  Digit
  Space
  Word
}

///|
priv struct ClassPerl {
  span : Span
  kind : ClassPerlKind
  negated : Bool
}

///|
priv enum ClassUnicodeKind {
  OneLetter(Char)
  Named(String)
  NamedValue(name~ : String, value~ : String, not_equal~ : Bool)
}

///|
priv struct ClassUnicode {
  span : Span
  negated : Bool
  kind : ClassUnicodeKind
}

///|
fn ClassUnicode::is_negated(self : ClassUnicode) -> Bool {
  match self.kind {
    NamedValue(not_equal~, ..) => self.negated != not_equal
    _ => self.negated
  }
}

///|
priv struct ClassAscii {
  span : Span
  kind : String
  negated : Bool
}

///|
priv enum ClassSetItem {
  Empty(Span)
  Literal(Literal)
  Range(Span, Literal, Literal)
  Ascii(ClassAscii)
  Unicode(ClassUnicode)
  Perl(ClassPerl)
  Bracketed(ClassBracketed)
  Union(Span, Array[ClassSetItem])
}

///|
fn ClassSetItem::span(self : ClassSetItem) -> Span {
  match self {
    Empty(s) | Range(s, _, _) | Union(s, _) => s
    Literal(l) => l.span
    Ascii(a) => a.span
    Unicode(u) => u.span
    Perl(p) => p.span
    Bracketed(b) => b.span
  }
}

///|
priv enum ClassSetBinaryOpKind {
  Intersection
  Difference
  SymmetricDifference
}

///|
priv enum ClassSet {
  Item(ClassSetItem)
  BinaryOp(Span, ClassSetBinaryOpKind, ClassSet, ClassSet)
}

///|
fn ClassSet::span(self : ClassSet) -> Span {
  match self {
    Item(item) => item.span()
    BinaryOp(s, _, _, _) => s
  }
}

///|
priv struct ClassBracketed {
  mut span : Span
  negated : Bool
  mut kind : ClassSet
}

///|
/// A union of class set items under construction.
priv struct ClassSetUnion {
  mut span : Span
  items : Array[ClassSetItem]
}

///|
fn ClassSetUnion::push(self : ClassSetUnion, item : ClassSetItem) -> Unit {
  if self.items.is_empty() {
    self.span = { start: item.span().start, end: self.span.end, }
  }
  self.span = { start: self.span.start, end: item.span().end, }
  self.items.push(item)
}

///|
fn ClassSetUnion::into_item(self : ClassSetUnion) -> ClassSetItem {
  match self.items.length() {
    0 => Empty(self.span)
    1 => self.items[0]
    _ => Union(self.span, self.items)
  }
}

///|
priv enum RepetitionKind {
  ZeroOrOne
  ZeroOrMore
  OneOrMore
  Exactly(Int)
  AtLeast(Int)
  Bounded(Int, Int)
}

///|
priv enum FlagsItemKind {
  Negation
  Flag(Char)
} derive(Eq)

///|
priv struct FlagsItem {
  span : Span
  kind : FlagsItemKind
}

///|
priv struct Flags {
  mut span : Span
  items : Array[FlagsItem]
}

///|
/// Add an item; returns the index of an equal existing item instead.
fn Flags::add_item(self : Flags, item : FlagsItem) -> Int? {
  for i, x in self.items {
    if x.kind == item.kind {
      return Some(i)
    }
  }
  self.items.push(item)
  None
}

///|
/// The state of a flag: `Some(true)` if set, `Some(false)` if negated.
fn Flags::flag_state(self : Flags, flag : Char) -> Bool? {
  let mut negated = false
  for x in self.items {
    match x.kind {
      Negation => negated = true
      Flag(f) if f == flag => return Some(!negated)
      _ => ()
    }
  }
  None
}

///|
priv enum GroupKind {
  CaptureIndex(Int)
  CaptureName(String, Int)
  NonCapturing(Flags)
}

///|
priv struct Group {
  mut span : Span
  kind : GroupKind
  mut ast : Ast
}

///|
/// The abstract syntax of a regular expression.
priv enum Ast {
  Empty(Span)
  SetFlags(Span, Flags)
  Literal(Literal)
  Dot(Span)
  Assertion(Span, AssertionKind)
  ClassUnicode(ClassUnicode)
  ClassPerl(ClassPerl)
  ClassBracketed(ClassBracketed)
  Repetition(Span, RepetitionKind, Bool, Ast)
  Group(Group)
  Alternation(Span, Array[Ast])
  Concat(Span, Array[Ast])
}

///|
fn Ast::span(self : Ast) -> Span {
  match self {
    Empty(s)
    | SetFlags(s, _)
    | Dot(s)
    | Assertion(s, _)
    | Repetition(s, _, _, _)
    | Alternation(s, _)
    | Concat(s, _) => s
    Literal(l) => l.span
    ClassUnicode(c) => c.span
    ClassPerl(c) => c.span
    ClassBracketed(c) => c.span
    Group(g) => g.span
  }
}
