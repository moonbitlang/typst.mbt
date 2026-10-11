// Port of the regular expression parser of `regex-syntax` (`ast/parse.rs`).

///|
priv enum GroupState {
  /// A group that is being built, with the concatenation before it.
  Group(Ast, Group, Bool)
  /// An alternation that is being built.
  Alternation(Span, Array[Ast])
}

///|
priv enum ClassState {
  /// An open bracketed class, with the parent union.
  Open(ClassSetUnion, ClassBracketed)
  /// A binary operation whose right hand side is being parsed.
  Op(ClassSetBinaryOpKind, ClassSet)
}

///|
priv enum Primitive {
  Literal(Literal)
  Assertion(Span, AssertionKind)
  Dot(Span)
  Perl(ClassPerl)
  Unicode(ClassUnicode)
}

///|
fn Primitive::span(self : Primitive) -> Span {
  match self {
    Literal(l) => l.span
    Assertion(s, _) | Dot(s) => s
    Perl(p) => p.span
    Unicode(u) => u.span
  }
}

///|
fn Primitive::into_ast(self : Primitive) -> Ast {
  match self {
    Literal(l) => Literal(l)
    Assertion(s, k) => Assertion(s, k)
    Dot(s) => Dot(s)
    Perl(p) => ClassPerl(p)
    Unicode(u) => ClassUnicode(u)
  }
}

///|
/// The parser state (upstream `Parser` + `ParserI`).
priv struct Parser {
  pattern : String
  mut pos : Position
  mut capture_index : Int
  capture_names : Array[(String, Span)]
  mut ignore_whitespace : Bool
  stack_group : Array[GroupState]
  stack_class : Array[ClassState]
}

///|
const NEST_LIMIT = 250

///|
fn Parser::new(pattern : String) -> Parser {
  {
    pattern,
    pos: { offset: 0, line: 1, column: 1, },
    capture_index: 0,
    capture_names: [],
    ignore_whitespace: false,
    stack_group: [],
    stack_class: [],
  }
}

///|
fn[T] Parser::error(
  self : Parser,
  span : Span,
  kind : AstErrorKind,
) -> T raise RegexError {
  syntax_error(self.pattern, span, kind.aux_span(), kind.message())
}

///|
fn Parser::offset(self : Parser) -> Int {
  self.pos.offset
}

///|
fn Parser::char_at(self : Parser, i : Int) -> Int {
  let c = self.pattern.code_unit_at(i).to_int()
  if c >= 0xD800 && c <= 0xDBFF && i + 1 < self.pattern.length() {
    let d = self.pattern.code_unit_at(i + 1).to_int()
    if d >= 0xDC00 && d <= 0xDFFF {
      return 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00)
    }
  }
  c
}

///|
fn char_len16(c : Int) -> Int {
  if c >= 0x10000 {
    2
  } else {
    1
  }
}

///|
fn Parser::char(self : Parser) -> Int {
  self.char_at(self.offset())
}

///|
fn Parser::is_eof(self : Parser) -> Bool {
  self.offset() == self.pattern.length()
}

///|
fn Parser::next_capture_index(self : Parser) -> Int {
  self.capture_index += 1
  self.capture_index
}

///|
fn Parser::add_capture_name(
  self : Parser,
  name : String,
  span : Span,
) -> Unit raise RegexError {
  for entry in self.capture_names {
    if entry.0 == name {
      self.error(span, GroupNameDuplicate(entry.1))
    }
  }
  self.capture_names.push((name, span))
}

///|
/// Advance by one char. Returns false if EOF was reached.
fn Parser::bump(self : Parser) -> Bool {
  if self.is_eof() {
    return false
  }
  let { offset, line, column, } = self.pos
  let c = self.char()
  self.pos = if c == '\n' {
    { offset: offset + char_len16(c), line: line + 1, column: 1, }
  } else {
    { offset: offset + char_len16(c), line, column: column + 1, }
  }
  !self.is_eof()
}

///|
/// If the remaining pattern starts with `prefix`, advance past it.
fn Parser::bump_if(self : Parser, prefix : String) -> Bool {
  let rest = self.pattern.view(start_offset=self.offset())
  if rest.has_prefix(prefix) {
    for _ in prefix {
      self.bump() |> ignore
    }
    true
  } else {
    false
  }
}

///|
fn Parser::is_lookaround_prefix(self : Parser) -> Bool {
  self.bump_if("?=") ||
  self.bump_if("?!") ||
  self.bump_if("?<=") ||
  self.bump_if("?<!")
}

///|
fn Parser::bump_and_bump_space(self : Parser) -> Bool {
  if !self.bump() {
    return false
  }
  self.bump_space()
  !self.is_eof()
}

///|
fn is_whitespace(c : Int) -> Bool {
  @unicode.is_whitespace(c.unsafe_to_char())
}

///|
/// Skip whitespace and comments in `x` mode.
fn Parser::bump_space(self : Parser) -> Unit {
  if !self.ignore_whitespace {
    return
  }
  while !self.is_eof() {
    if is_whitespace(self.char()) {
      self.bump() |> ignore
    } else if self.char() == '#' {
      self.bump() |> ignore
      while !self.is_eof() {
        let c = self.char()
        self.bump() |> ignore
        if c == '\n' {
          break
        }
      }
    } else {
      break
    }
  }
}

///|
fn Parser::peek(self : Parser) -> Int? {
  if self.is_eof() {
    return None
  }
  let next = self.offset() + char_len16(self.char())
  if next >= self.pattern.length() {
    None
  } else {
    Some(self.char_at(next))
  }
}

///|
fn Parser::peek_space(self : Parser) -> Int? {
  if !self.ignore_whitespace {
    return self.peek()
  }
  if self.is_eof() {
    return None
  }
  let mut i = self.offset() + char_len16(self.char())
  let mut in_comment = false
  while i < self.pattern.length() {
    let c = self.char_at(i)
    if is_whitespace(c) {
      ()
    } else if !in_comment && c == '#' {
      in_comment = true
    } else if in_comment && c == '\n' {
      in_comment = false
    } else {
      return Some(c)
    }
    i += char_len16(c)
  }
  None
}

///|
fn Parser::span(self : Parser) -> Span {
  Span::splat(self.pos)
}

///|
fn Parser::span_char(self : Parser) -> Span {
  let c = self.char()
  let next : Position = if c == '\n' {
    {
      offset: self.offset() + char_len16(c),
      line: self.pos.line + 1,
      column: 1,
    }
  } else {
    {
      offset: self.offset() + char_len16(c),
      line: self.pos.line,
      column: self.pos.column + 1,
    }
  }
  { start: self.pos, end: next, }
}

///|
/// A concatenation under construction.
priv struct Concat {
  mut span : Span
  asts : Array[Ast]
}

///|
fn Concat::into_ast(self : Concat) -> Ast {
  match self.asts.length() {
    0 => Empty(self.span)
    1 => self.asts[0]
    _ => Concat(self.span, self.asts)
  }
}

///|
fn alternation_into_ast(span : Span, asts : Array[Ast]) -> Ast {
  match asts.length() {
    0 => Empty(span)
    1 => asts[0]
    _ => Alternation(span, asts)
  }
}

///|
fn Parser::push_alternate(self : Parser, concat : Concat) -> Concat {
  concat.span = concat.span.with_end(self.pos)
  self.push_or_add_alternation(concat)
  self.bump() |> ignore
  { span: self.span(), asts: [], }
}

///|
fn Parser::push_or_add_alternation(self : Parser, concat : Concat) -> Unit {
  if self.stack_group.last() is Some(Alternation(_, asts)) {
    asts.push(concat.into_ast())
    return
  }
  self.stack_group.push(
    Alternation({ start: concat.span.start, end: self.pos, }, [
      concat.into_ast(),
    ]),
  )
}

///|
/// Parse a group start and push it (or apply set flags).
fn Parser::push_group(
  self : Parser,
  concat : Concat,
) -> Concat raise RegexError {
  match self.parse_group() {
    Left((span, flags)) => {
      if flags.flag_state('x') is Some(v) {
        self.ignore_whitespace = v
      }
      concat.asts.push(SetFlags(span, flags))
      concat
    }
    Right(group) => {
      let old = self.ignore_whitespace
      let new = match group.kind {
        NonCapturing(flags) => flags.flag_state('x').unwrap_or(old)
        _ => old
      }
      self.stack_group.push(Group(concat.into_ast_keep(), group, old))
      self.ignore_whitespace = new
      { span: self.span(), asts: [], }
    }
  }
}

///|
/// Keep the concatenation as-is (it is restored when the group is popped).
fn Concat::into_ast_keep(self : Concat) -> Ast {
  Concat(self.span, self.asts)
}

///|
fn Parser::pop_group(
  self : Parser,
  group_concat : Concat,
) -> Concat raise RegexError {
  let (prior, group, ignore_ws, alt) = match self.stack_group.pop() {
    Some(Group(prior, group, ws)) => (prior, group, ws, None)
    Some(Alternation(span, asts)) =>
      match self.stack_group.pop() {
        Some(Group(prior, group, ws)) => (prior, group, ws, Some((span, asts)))
        _ => self.error(self.span_char(), GroupUnopened)
      }
    None => self.error(self.span_char(), GroupUnopened)
  }
  self.ignore_whitespace = ignore_ws
  group_concat.span = group_concat.span.with_end(self.pos)
  self.bump() |> ignore
  group.span = group.span.with_end(self.pos)
  match alt {
    Some((span, asts)) => {
      asts.push(group_concat.into_ast())
      group.ast = alternation_into_ast(
        span.with_end(group_concat.span.end),
        asts,
      )
    }
    None => group.ast = group_concat.into_ast()
  }
  guard prior is Concat(span, asts) else { abort("unreachable") }
  asts.push(Group(group))
  { span, asts, }
}

///|
fn Parser::pop_group_end(
  self : Parser,
  concat : Concat,
) -> Ast raise RegexError {
  concat.span = concat.span.with_end(self.pos)
  let ast = match self.stack_group.pop() {
    None => concat.into_ast()
    Some(Alternation(span, asts)) => {
      asts.push(concat.into_ast())
      Alternation(span.with_end(self.pos), asts)
    }
    Some(Group(_, group, _)) => self.error(group.span, GroupUnclosed)
  }
  match self.stack_group.pop() {
    None => ast
    Some(Group(_, group, _)) => self.error(group.span, GroupUnclosed)
    Some(Alternation(_, _)) => abort("unreachable")
  }
}

///|
fn Parser::push_class_open(
  self : Parser,
  parent_union : ClassSetUnion,
) -> ClassSetUnion raise RegexError {
  let (nested_set, nested_union) = self.parse_set_class_open()
  self.stack_class.push(Open(parent_union, nested_set))
  nested_union
}

///|
/// Pop a class at `]`: returns the parent union if nested, or the finished
/// class.
fn Parser::pop_class(
  self : Parser,
  nested_union : ClassSetUnion,
) -> Result[ClassSetUnion, ClassBracketed] {
  let item = ClassSet::Item(nested_union.into_item())
  let prevset = self.pop_class_op(item)
  match self.stack_class.pop() {
    Some(Open(union, set)) => {
      self.bump() |> ignore
      set.span = set.span.with_end(self.pos)
      set.kind = prevset
      if self.stack_class.is_empty() {
        Err(set)
      } else {
        union.push(Bracketed(set))
        Ok(union)
      }
    }
    _ => abort("unexpected class state")
  }
}

///|
fn[T] Parser::unclosed_class_error(self : Parser) -> T raise RegexError {
  for i = self.stack_class.length() - 1; i >= 0; i = i - 1 {
    if self.stack_class[i] is Open(_, set) {
      self.error(set.span, ClassUnclosed)
    }
  }
  abort("no open character class found")
}

///|
fn Parser::push_class_op(
  self : Parser,
  kind : ClassSetBinaryOpKind,
  union : ClassSetUnion,
) -> ClassSetUnion {
  let item = ClassSet::Item(union.into_item())
  let new_lhs = self.pop_class_op(item)
  self.stack_class.push(Op(kind, new_lhs))
  { span: self.span(), items: [], }
}

///|
fn Parser::pop_class_op(self : Parser, rhs : ClassSet) -> ClassSet {
  match self.stack_class.last() {
    Some(Op(kind, lhs)) => {
      self.stack_class.pop() |> ignore
      let span : Span = { start: lhs.span().start, end: rhs.span().end, }
      BinaryOp(span, kind, lhs, rhs)
    }
    _ => rhs
  }
}

///|
/// Parse the whole pattern.
fn Parser::parse(self : Parser) -> Ast raise RegexError {
  let mut concat : Concat = { span: self.span(), asts: [], }
  while true {
    self.bump_space()
    if self.is_eof() {
      break
    }
    match self.char() {
      '(' => concat = self.push_group(concat)
      ')' => concat = self.pop_group(concat)
      '|' => concat = self.push_alternate(concat)
      '[' => {
        let class = self.parse_set_class()
        concat.asts.push(ClassBracketed(class))
      }
      '?' => concat = self.parse_uncounted_repetition(concat, ZeroOrOne)
      '*' => concat = self.parse_uncounted_repetition(concat, ZeroOrMore)
      '+' => concat = self.parse_uncounted_repetition(concat, OneOrMore)
      '{' => concat = self.parse_counted_repetition(concat)
      _ => concat.asts.push(self.parse_primitive().into_ast())
    }
  }
  let ast = self.pop_group_end(concat)
  self.check_nest_limit(ast, 0)
  ast
}

///|
fn Parser::parse_uncounted_repetition(
  self : Parser,
  concat : Concat,
  kind : RepetitionKind,
) -> Concat raise RegexError {
  let op_start = self.pos
  let ast = match concat.asts.pop() {
    Some(ast) => ast
    None => self.error(self.span(), RepetitionMissing)
  }
  if ast is (Empty(_) | SetFlags(_, _)) {
    self.error(self.span(), RepetitionMissing)
  }
  let _ = op_start
  let mut greedy = true
  if self.bump() && self.char() == '?' {
    greedy = false
    self.bump() |> ignore
  }
  concat.asts.push(Repetition(ast.span().with_end(self.pos), kind, greedy, ast))
  concat
}

///|
fn Parser::parse_counted_repetition(
  self : Parser,
  concat : Concat,
) -> Concat raise RegexError {
  let start = self.pos
  let ast = match concat.asts.pop() {
    Some(ast) => ast
    None => self.error(self.span(), RepetitionMissing)
  }
  if ast is (Empty(_) | SetFlags(_, _)) {
    self.error(self.span(), RepetitionMissing)
  }
  if !self.bump_and_bump_space() {
    self.error({ start, end: self.pos, }, RepetitionCountUnclosed)
  }
  let count_start : Result[Int, (Span, AstErrorKind)] = self.parse_decimal_spec()
  if self.is_eof() {
    self.error({ start, end: self.pos, }, RepetitionCountUnclosed)
  }
  let range = if self.char() == ',' {
    if !self.bump_and_bump_space() {
      self.error({ start, end: self.pos, }, RepetitionCountUnclosed)
    }
    if self.char() != '}' {
      let count_start = match count_start {
        Ok(c) => c
        Err((span, kind)) => self.error(span, kind)
      }
      let count_end = match self.parse_decimal_spec() {
        Ok(c) => c
        Err((span, kind)) => self.error(span, kind)
      }
      Bounded(count_start, count_end)
    } else {
      match count_start {
        Ok(c) => AtLeast(c)
        Err((span, kind)) => self.error(span, kind)
      }
    }
  } else {
    match count_start {
      Ok(c) => Exactly(c)
      Err((span, kind)) => self.error(span, kind)
    }
  }
  if self.is_eof() || self.char() != '}' {
    self.error({ start, end: self.pos, }, RepetitionCountUnclosed)
  }
  let mut greedy = true
  if self.bump_and_bump_space() && self.char() == '?' {
    greedy = false
    self.bump() |> ignore
  }
  let op_span : Span = { start, end: self.pos, }
  if range is Bounded(s, e) && s > e {
    self.error(op_span, RepetitionCountInvalid)
  }
  concat.asts.push(
    Repetition(ast.span().with_end(self.pos), range, greedy, ast),
  )
  concat
}

///|
/// `parse_decimal` with `DecimalEmpty` specialized to
/// `RepetitionCountDecimalEmpty`; errors are returned, not raised.
fn Parser::parse_decimal_spec(
  self : Parser,
) -> Result[Int, (Span, AstErrorKind)] {
  while !self.is_eof() && is_whitespace(self.char()) {
    self.bump() |> ignore
  }
  let start = self.pos
  let digits = StringBuilder()
  while !self.is_eof() && self.char() >= '0' && self.char() <= '9' {
    digits.write_char(self.char().unsafe_to_char())
    self.bump_and_bump_space() |> ignore
  }
  let span : Span = { start, end: self.pos, }
  while !self.is_eof() && is_whitespace(self.char()) {
    self.bump_and_bump_space() |> ignore
  }
  let digits = digits.to_string()
  if digits.is_empty() {
    return Err((span, RepetitionCountDecimalEmpty))
  }
  // Must fit into a u32.
  let mut n = 0L
  for c in digits {
    n = n * 10L + (c.to_int() - '0').to_int64()
    if n > 0xFFFFFFFFL {
      return Err((span, DecimalInvalid))
    }
  }
  Ok(n.to_int())
}

///|
/// Parse a group: either set flags `(?flags)` or the start of a group.
fn Parser::parse_group(
  self : Parser,
) -> Either[(Span, Flags), Group] raise RegexError {
  let open_span = self.span_char()
  self.bump() |> ignore
  self.bump_space()
  if self.is_lookaround_prefix() {
    self.error(
      { start: open_span.start, end: self.pos, },
      UnsupportedLookAround,
    )
  }
  let inner_span = self.span()
  if self.bump_if("?P<") || self.bump_if("?<") {
    let index = self.next_capture_index()
    let name = self.parse_capture_name()
    Right({
      span: open_span,
      kind: CaptureName(name, index),
      ast: Empty(self.span()),
    })
  } else if self.bump_if("?") {
    if self.is_eof() {
      self.error(open_span, GroupUnclosed)
    }
    let flags = self.parse_flags()
    let char_end = self.char()
    self.bump() |> ignore
    if char_end == ')' {
      // We don't allow empty flags, e.g., `(?)`.
      if flags.items.is_empty() {
        self.error(inner_span, RepetitionMissing)
      }
      Left(({ start: open_span.start, end: self.pos, }, flags))
    } else {
      Right({
        span: open_span,
        kind: NonCapturing(flags),
        ast: Empty(self.span()),
      })
    }
  } else {
    let index = self.next_capture_index()
    Right({
      span: open_span,
      kind: CaptureIndex(index),
      ast: Empty(self.span()),
    })
  }
}

///|
priv enum Either[A, B] {
  Left(A)
  Right(B)
}

///|
fn is_capture_char(c : Int, first : Bool) -> Bool {
  if first {
    c == '_' || @unicode.is_alphabetic(c.unsafe_to_char())
  } else {
    c == '_' ||
    c == '.' ||
    c == '[' ||
    c == ']' ||
    @unicode.is_alphanumeric(c.unsafe_to_char())
  }
}

///|
fn Parser::parse_capture_name(self : Parser) -> String raise RegexError {
  if self.is_eof() {
    self.error(self.span(), GroupNameUnexpectedEof)
  }
  let start = self.pos
  while true {
    if self.char() == '>' {
      break
    }
    if !is_capture_char(self.char(), self.pos == start) {
      self.error(self.span_char(), GroupNameInvalid)
    }
    if !self.bump() {
      break
    }
  }
  let end = self.pos
  if self.is_eof() {
    self.error(self.span(), GroupNameUnexpectedEof)
  }
  self.bump() |> ignore
  let name = self.pattern.unsafe_substring(start=start.offset, end=end.offset)
  if name.is_empty() {
    self.error({ start, end: start, }, GroupNameEmpty)
  }
  self.add_capture_name(name, { start, end, })
  name
}

///|
fn Parser::parse_flags(self : Parser) -> Flags raise RegexError {
  let flags : Flags = { span: self.span(), items: [], }
  let mut last_was_negation = None
  while self.char() != ':' && self.char() != ')' {
    if self.char() == '-' {
      last_was_negation = Some(self.span_char())
      let item = { span: self.span_char(), kind: Negation, }
      if flags.add_item(item) is Some(i) {
        self.error(self.span_char(), FlagRepeatedNegation(flags.items[i].span))
      }
    } else {
      last_was_negation = None
      let item = { span: self.span_char(), kind: Flag(self.parse_flag()), }
      if flags.add_item(item) is Some(i) {
        self.error(self.span_char(), FlagDuplicate(flags.items[i].span))
      }
    }
    if !self.bump() {
      self.error(self.span(), FlagUnexpectedEof)
    }
  }
  if last_was_negation is Some(span) {
    self.error(span, FlagDanglingNegation)
  }
  flags.span = flags.span.with_end(self.pos)
  flags
}

///|
fn Parser::parse_flag(self : Parser) -> Char raise RegexError {
  match self.char() {
    'i' | 'm' | 's' | 'U' | 'u' | 'R' | 'x' => self.char().unsafe_to_char()
    _ => self.error(self.span_char(), FlagUnrecognized)
  }
}

///|
fn Parser::parse_primitive(self : Parser) -> Primitive raise RegexError {
  match self.char() {
    '\\' => self.parse_escape()
    '.' => {
      let ast = Primitive::Dot(self.span_char())
      self.bump() |> ignore
      ast
    }
    '^' => {
      let ast = Primitive::Assertion(self.span_char(), StartLine)
      self.bump() |> ignore
      ast
    }
    '$' => {
      let ast = Primitive::Assertion(self.span_char(), EndLine)
      self.bump() |> ignore
      ast
    }
    c => {
      let ast = Primitive::Literal({ span: self.span_char(), c, hex_x: false, })
      self.bump() |> ignore
      ast
    }
  }
}

///|
/// Upstream `regex_syntax::is_meta_character`.
fn is_meta_character(c : Int) -> Bool {
  c
  is ('\\'
  | '.'
  | '+'
  | '*'
  | '?'
  | '('
  | ')'
  | '|'
  | '['
  | ']'
  | '{'
  | '}'
  | '^'
  | '$'
  | '#'
  | '&'
  | '-'
  | '~')
}

///|
/// Upstream `regex_syntax::is_escapeable_character`.
fn is_escapeable_character(c : Int) -> Bool {
  if is_meta_character(c) {
    return true
  }
  if c >= 0x80 {
    return false
  }
  !((c >= '0' && c <= '9') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= 'a' && c <= 'z') ||
  c == '<' ||
  c == '>')
}

///|
fn Parser::parse_escape(self : Parser) -> Primitive raise RegexError {
  let start = self.pos
  if !self.bump() {
    self.error({ start, end: self.pos, }, EscapeUnexpectedEof)
  }
  let c = self.char()
  match c {
    '0'..<='9' =>
      self.error(
        { start, end: self.span_char().end, },
        UnsupportedBackreference,
      )
    'x' | 'u' | 'U' => {
      let lit = self.parse_hex()
      return Literal({ ..lit, span: { start, end: lit.span.end, }, })
    }
    'p' | 'P' => {
      let cls = self.parse_unicode_class()
      return Unicode({ ..cls, span: { start, end: cls.span.end, }, })
    }
    'd' | 's' | 'w' | 'D' | 'S' | 'W' => {
      let cls = self.parse_perl_class()
      return Perl({ ..cls, span: { start, end: cls.span.end, }, })
    }
    _ => ()
  }
  // Handle all of the one letter sequences inline.
  self.bump() |> ignore
  let span : Span = { start, end: self.pos, }
  if is_meta_character(c) || is_escapeable_character(c) {
    return Literal({ span, c, hex_x: false, })
  }
  let special = (c : Int) => Primitive::Literal({ span, c, hex_x: false, })
  match c {
    'a' => special(0x07)
    'f' => special(0x0C)
    't' => special('\t')
    'n' => special('\n')
    'r' => special('\r')
    'v' => special(0x0B)
    'A' => Assertion(span, StartText)
    'z' => Assertion(span, EndText)
    'b' => {
      let mut kind = AssertionKind::WordBoundary
      let mut span = span
      // After a \b, we "try" to parse things like \b{start} for special
      // word boundary assertions.
      if !self.is_eof() && self.char() == '{' {
        if self.maybe_parse_special_word_boundary(start) is Some(k) {
          kind = k
          span = span.with_end(self.pos)
        }
      }
      Assertion(span, kind)
    }
    'B' => Assertion(span, NotWordBoundary)
    '<' => Assertion(span, WordBoundaryStartAngle)
    '>' => Assertion(span, WordBoundaryEndAngle)
    _ => self.error(span, EscapeUnrecognized)
  }
}

///|
fn Parser::maybe_parse_special_word_boundary(
  self : Parser,
  wb_start : Position,
) -> AssertionKind? raise RegexError {
  let is_valid_char = (c : Int) => {
    (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '-'
  }
  let start = self.pos
  if !self.bump_and_bump_space() {
    self.error(
      { start: wb_start, end: self.pos, },
      SpecialWordOrRepetitionUnexpectedEof,
    )
  }
  let start_contents = self.pos
  // If the first non-whitespace character isn't in [-A-Za-z], then this is
  // a counted repetition.
  if !is_valid_char(self.char()) {
    self.pos = start
    return None
  }
  let scratch = StringBuilder()
  while !self.is_eof() && is_valid_char(self.char()) {
    scratch.write_char(self.char().unsafe_to_char())
    self.bump_and_bump_space() |> ignore
  }
  if self.is_eof() || self.char() != '}' {
    self.error({ start, end: self.pos, }, SpecialWordBoundaryUnclosed)
  }
  let end = self.pos
  self.bump() |> ignore
  match scratch.to_string() {
    "start" => Some(WordBoundaryStart)
    "end" => Some(WordBoundaryEnd)
    "start-half" => Some(WordBoundaryStartHalf)
    "end-half" => Some(WordBoundaryEndHalf)
    _ =>
      self.error(
        { start: start_contents, end, },
        SpecialWordBoundaryUnrecognized,
      )
  }
}

///|
fn is_hex(c : Int) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
fn hex_value(s : String) -> Int? {
  let mut n = 0L
  for c in s {
    let c = c.to_int()
    let d = if c >= '0' && c <= '9' {
      c - '0'
    } else if c >= 'a' && c <= 'f' {
      c - 'a' + 10
    } else {
      c - 'A' + 10
    }
    n = n * 16L + d.to_int64()
    if n > 0xFFFFFFFFL {
      return None
    }
  }
  let n = n.to_int()
  if (n >= 0xD800 && n <= 0xDFFF) || n > 0x10FFFF || n < 0 {
    None
  } else {
    Some(n)
  }
}

///|
fn Parser::parse_hex(self : Parser) -> Literal raise RegexError {
  let digits = match self.char() {
    'x' => 2
    'u' => 4
    _ => 8
  }
  let is_x = self.char() == 'x'
  if !self.bump_and_bump_space() {
    self.error(self.span(), EscapeUnexpectedEof)
  }
  if self.char() == '{' {
    self.parse_hex_brace()
  } else {
    self.parse_hex_digits(digits, is_x)
  }
}

///|
fn Parser::parse_hex_digits(
  self : Parser,
  digits : Int,
  is_x : Bool,
) -> Literal raise RegexError {
  let scratch = StringBuilder()
  let start = self.pos
  for i in 0..<digits {
    if i > 0 && !self.bump_and_bump_space() {
      self.error(self.span(), EscapeUnexpectedEof)
    }
    if !is_hex(self.char()) {
      self.error(self.span_char(), EscapeHexInvalidDigit)
    }
    scratch.write_char(self.char().unsafe_to_char())
  }
  // The final bump just moves the parser past the literal, which may be EOF.
  self.bump_and_bump_space() |> ignore
  let end = self.pos
  match hex_value(scratch.to_string()) {
    None => self.error({ start, end, }, EscapeHexInvalid)
    Some(c) => { span: { start, end, }, c, hex_x: is_x, }
  }
}

///|
fn Parser::parse_hex_brace(self : Parser) -> Literal raise RegexError {
  let scratch = StringBuilder()
  let brace_pos = self.pos
  let start = self.span_char().end
  while self.bump_and_bump_space() && self.char() != '}' {
    if !is_hex(self.char()) {
      self.error(self.span_char(), EscapeHexInvalidDigit)
    }
    scratch.write_char(self.char().unsafe_to_char())
  }
  if self.is_eof() {
    self.error({ start: brace_pos, end: self.pos, }, EscapeUnexpectedEof)
  }
  let end = self.pos
  self.bump_and_bump_space() |> ignore
  let hex = scratch.to_string()
  if hex.is_empty() {
    self.error({ start: brace_pos, end: self.pos, }, EscapeHexEmpty)
  }
  match hex_value(hex) {
    None => self.error({ start, end, }, EscapeHexInvalid)
    Some(c) => { span: { start, end: self.pos, }, c, hex_x: false, }
  }
}

///|
fn Parser::parse_set_class(self : Parser) -> ClassBracketed raise RegexError {
  let mut union : ClassSetUnion = { span: self.span(), items: [], }
  while true {
    self.bump_space()
    if self.is_eof() {
      self.unclosed_class_error()
    }
    match self.char() {
      '[' => {
        // If we've already parsed the opening bracket, then attempt to
        // treat this as the beginning of an ASCII class.
        if !self.stack_class.is_empty() {
          if self.maybe_parse_ascii_class() is Some(cls) {
            union.push(Ascii(cls))
            continue
          }
        }
        union = self.push_class_open(union)
      }
      ']' =>
        match self.pop_class(union) {
          Ok(nested) => union = nested
          Err(class) => return class
        }
      '&' if self.peek() == Some('&') => {
        self.bump_if("&&") |> ignore
        union = self.push_class_op(Intersection, union)
      }
      '-' if self.peek() == Some('-') => {
        self.bump_if("--") |> ignore
        union = self.push_class_op(Difference, union)
      }
      '~' if self.peek() == Some('~') => {
        self.bump_if("~~") |> ignore
        union = self.push_class_op(SymmetricDifference, union)
      }
      _ => union.push(self.parse_set_class_range())
    }
  }
  abort("unreachable")
}

///|
fn Parser::parse_set_class_range(
  self : Parser,
) -> ClassSetItem raise RegexError {
  let prim1 = self.parse_set_class_item()
  self.bump_space()
  if self.is_eof() {
    self.unclosed_class_error()
  }
  // If the next char isn't a `-`, then we don't have a range. There are two
  // exceptions: `-]` and `--`.
  if self.char() != '-' ||
    self.peek_space() == Some(']') ||
    self.peek_space() == Some('-') {
    return self.into_class_set_item(prim1)
  }
  if !self.bump_and_bump_space() {
    self.unclosed_class_error()
  }
  let prim2 = self.parse_set_class_item()
  let span : Span = { start: prim1.span().start, end: prim2.span().end, }
  let start = self.into_class_literal(prim1)
  let end = self.into_class_literal(prim2)
  if start.c > end.c {
    self.error(span, ClassRangeInvalid)
  }
  Range(span, start, end)
}

///|
fn Parser::into_class_set_item(
  self : Parser,
  prim : Primitive,
) -> ClassSetItem raise RegexError {
  match prim {
    Literal(l) => Literal(l)
    Perl(p) => Perl(p)
    Unicode(u) => Unicode(u)
    x => self.error(x.span(), ClassEscapeInvalid)
  }
}

///|
fn Parser::into_class_literal(
  self : Parser,
  prim : Primitive,
) -> Literal raise RegexError {
  match prim {
    Literal(l) => l
    x => self.error(x.span(), ClassRangeLiteral)
  }
}

///|
fn Parser::parse_set_class_item(self : Parser) -> Primitive raise RegexError {
  if self.char() == '\\' {
    self.parse_escape()
  } else {
    let x = Primitive::Literal({
      span: self.span_char(),
      c: self.char(),
      hex_x: false,
    })
    self.bump() |> ignore
    x
  }
}

///|
fn Parser::parse_set_class_open(
  self : Parser,
) -> (ClassBracketed, ClassSetUnion) raise RegexError {
  let start = self.pos
  if !self.bump_and_bump_space() {
    self.error({ start, end: self.pos, }, ClassUnclosed)
  }
  let negated = if self.char() != '^' {
    false
  } else {
    if !self.bump_and_bump_space() {
      self.error({ start, end: self.pos, }, ClassUnclosed)
    }
    true
  }
  // Accept any number of `-` as literal `-`.
  let union : ClassSetUnion = { span: self.span(), items: [], }
  while self.char() == '-' {
    union.push(Literal({ span: self.span_char(), c: '-', hex_x: false, }))
    if !self.bump_and_bump_space() {
      self.error({ start, end: start, }, ClassUnclosed)
    }
  }
  // If `]` is the *first* char in a set, then interpret it as a literal.
  if union.items.is_empty() && self.char() == ']' {
    union.push(Literal({ span: self.span_char(), c: ']', hex_x: false, }))
    if !self.bump_and_bump_space() {
      self.error({ start, end: self.pos, }, ClassUnclosed)
    }
  }
  let set : ClassBracketed = {
    span: { start, end: self.pos, },
    negated,
    kind: Item(Union(Span::splat(union.span.start), [])),
  }
  (set, union)
}

///|
/// The ASCII classes by name.
fn ascii_class_ranges(name : String) -> Array[(Int, Int)]? {
  match name {
    "alnum" => Some([('0', '9'), ('A', 'Z'), ('a', 'z')])
    "alpha" => Some([('A', 'Z'), ('a', 'z')])
    "ascii" => Some([(0, 0x7F)])
    "blank" => Some([('\t', '\t'), (' ', ' ')])
    "cntrl" => Some([(0, 0x1F), (0x7F, 0x7F)])
    "digit" => Some([('0', '9')])
    "graph" => Some([('!', '~')])
    "lower" => Some([('a', 'z')])
    "print" => Some([(' ', '~')])
    "punct" => Some([('!', '/'), (':', '@'), ('[', '`'), ('{', '~')])
    "space" =>
      Some([
        ('\t', '\t'),
        ('\n', '\n'),
        (0x0B, 0x0B),
        (0x0C, 0x0C),
        ('\r', '\r'),
        (' ', ' '),
      ])
    "upper" => Some([('A', 'Z')])
    "word" => Some([('0', '9'), ('A', 'Z'), ('_', '_'), ('a', 'z')])
    "xdigit" => Some([('0', '9'), ('A', 'F'), ('a', 'f')])
    _ => None
  }
}

///|
fn Parser::maybe_parse_ascii_class(self : Parser) -> ClassAscii? {
  let start = self.pos
  let mut negated = false
  if !self.bump() || self.char() != ':' {
    self.pos = start
    return None
  }
  if !self.bump() {
    self.pos = start
    return None
  }
  if self.char() == '^' {
    negated = true
    if !self.bump() {
      self.pos = start
      return None
    }
  }
  let name_start = self.offset()
  while self.char() != ':' && self.bump() {

  }
  if self.is_eof() {
    self.pos = start
    return None
  }
  let name = self.pattern.unsafe_substring(start=name_start, end=self.offset())
  if !self.bump_if(":]") {
    self.pos = start
    return None
  }
  if ascii_class_ranges(name) is None {
    self.pos = start
    return None
  }
  Some({ span: { start, end: self.pos, }, kind: name, negated, })
}

///|
fn Parser::parse_unicode_class(self : Parser) -> ClassUnicode raise RegexError {
  let negated = self.char() == 'P'
  if !self.bump_and_bump_space() {
    self.error(self.span(), EscapeUnexpectedEof)
  }
  if self.char() == '{' {
    let start = self.span_char().end
    let scratch = StringBuilder()
    while self.bump_and_bump_space() && self.char() != '}' {
      scratch.write_char(self.char().unsafe_to_char())
    }
    if self.is_eof() {
      self.error(self.span(), EscapeUnexpectedEof)
    }
    self.bump() |> ignore
    let name = scratch.to_string()
    let kind = match name.find("!=") {
      Some(i) =>
        ClassUnicodeKind::NamedValue(
          name=name.unsafe_substring(start=0, end=i),
          value=name.unsafe_substring(start=i + 2, end=name.length()),
          not_equal=true,
        )
      None =>
        match name.find(":") {
          Some(i) =>
            NamedValue(
              name=name.unsafe_substring(start=0, end=i),
              value=name.unsafe_substring(start=i + 1, end=name.length()),
              not_equal=false,
            )
          None =>
            match name.find("=") {
              Some(i) =>
                NamedValue(
                  name=name.unsafe_substring(start=0, end=i),
                  value=name.unsafe_substring(start=i + 1, end=name.length()),
                  not_equal=false,
                )
              None => Named(name)
            }
        }
    }
    { span: { start, end: self.pos, }, negated, kind, }
  } else {
    let start = self.pos
    let c = self.char()
    if c == '\\' {
      self.error(self.span_char(), UnicodeClassInvalid)
    }
    self.bump_and_bump_space() |> ignore
    {
      span: { start, end: self.pos, },
      negated,
      kind: OneLetter(c.unsafe_to_char()),
    }
  }
}

///|
fn Parser::parse_perl_class(self : Parser) -> ClassPerl {
  let c = self.char()
  let span = self.span_char()
  self.bump() |> ignore
  let (negated, kind) = match c {
    'd' => (false, ClassPerlKind::Digit)
    'D' => (true, Digit)
    's' => (false, Space)
    'S' => (true, Space)
    'w' => (false, Word)
    _ => (true, Word)
  }
  { span, kind, negated, }
}

///|
/// Check the nesting limit (upstream `NestLimiter`).
fn Parser::check_nest_limit(
  self : Parser,
  ast : Ast,
  depth : Int,
) -> Unit raise RegexError {
  let enter = (span : Span) => {
    if depth + 1 > NEST_LIMIT {
      self.error(span, NestLimitExceeded(NEST_LIMIT))
    }
    depth + 1
  }
  match ast {
    Empty(_)
    | SetFlags(_, _)
    | Literal(_)
    | Dot(_)
    | Assertion(_, _)
    | ClassUnicode(_)
    | ClassPerl(_) => ()
    ClassBracketed(c) => {
      let d = enter(c.span)
      self.check_class_set_nest(c.kind, d)
    }
    Repetition(span, _, _, sub) => self.check_nest_limit(sub, enter(span))
    Group(g) => self.check_nest_limit(g.ast, enter(g.span))
    Alternation(span, asts) | Concat(span, asts) => {
      let d = enter(span)
      for a in asts {
        self.check_nest_limit(a, d)
      }
    }
  }
}

///|
fn Parser::check_class_set_nest(
  self : Parser,
  set : ClassSet,
  depth : Int,
) -> Unit raise RegexError {
  match set {
    Item(item) => self.check_class_item_nest(item, depth)
    BinaryOp(span, _, lhs, rhs) => {
      if depth + 1 > NEST_LIMIT {
        self.error(span, NestLimitExceeded(NEST_LIMIT))
      }
      self.check_class_set_nest(lhs, depth + 1)
      self.check_class_set_nest(rhs, depth + 1)
    }
  }
}

///|
fn Parser::check_class_item_nest(
  self : Parser,
  item : ClassSetItem,
  depth : Int,
) -> Unit raise RegexError {
  match item {
    Bracketed(c) => {
      if depth + 1 > NEST_LIMIT {
        self.error(c.span, NestLimitExceeded(NEST_LIMIT))
      }
      self.check_class_set_nest(c.kind, depth + 1)
    }
    Union(span, items) => {
      if depth + 1 > NEST_LIMIT {
        self.error(span, NestLimitExceeded(NEST_LIMIT))
      }
      for i in items {
        self.check_class_item_nest(i, depth + 1)
      }
    }
    _ => ()
  }
}
