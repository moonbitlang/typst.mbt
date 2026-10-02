// Port of `fancy-regex` 0.16.2 `src/parse.rs`: a regex parser yielding an
// AST. The parser works on the UTF-8 bytes of the pattern, so all positions
// (also in errors) are UTF-8 byte offsets like upstream.

///|
/// The maximum nesting depth of groups (upstream `MAX_RECURSION`).
const MAX_RECURSION : Int = 64

///|
/// Stand-in for Rust's `usize::MAX` (unbounded repeats, unset slots).
pub const USIZE_MAX : Int = 0x7FFFFFFF

///|
/// A set of group numbers (upstream `bit_set::BitSet`), kept sorted.
pub struct BitSet {
  priv items : Array[Int]
} derive(Eq, Debug)

///|
pub fn BitSet::new() -> BitSet {
  { items: [], }
}

///|
pub fn BitSet::insert(self : BitSet, x : Int) -> Bool {
  match self.items.binary_search(x) {
    Ok(_) => false
    Err(i) => {
      self.items.insert(i, x)
      true
    }
  }
}

///|
pub fn BitSet::contains(self : BitSet, x : Int) -> Bool {
  self.items.binary_search(x) is Ok(_)
}

///|
/// The members in increasing order.
pub fn BitSet::iter(self : BitSet) -> Iter[Int] {
  self.items.iter()
}

///|
/// The largest member.
pub fn BitSet::last(self : BitSet) -> Int? {
  self.items.last()
}

///|
/// The parsed expression tree with information gathered while parsing.
pub struct ExprTree {
  /// The expression.
  mut expr : Expr
  /// The groups that are referenced by backrefs.
  backrefs : BitSet
  /// The named groups.
  named_groups : Map[String, Int]
  contains_subroutines : Bool
  self_recursive : Bool
} derive(Debug)

///|
priv struct Parser {
  re : Bytes // source
  backrefs : BitSet
  mut flags : Int
  named_groups : Map[String, Int]
  mut numeric_backrefs : Bool
  mut curr_group : Int // need to keep track of which group number we're parsing
  mut contains_subroutines : Bool
  mut has_unresolved_subroutines : Bool
  mut self_recursive : Bool
}

///|
priv struct NamedBackrefOrSubroutine {
  ix : Int
  group_ix : Int?
  group_name : String?
  recursion_level : Int?
}

///|
fn perr(ix : Int, e : ParseError) -> FancyError {
  FancyError::ParseError(ix, e)
}

///|
fn Parser::parse_with_flags(
  re : String,
  flags : Int,
) -> ExprTree raise FancyError {
  let p = Parser::new(re, flags)
  let (ix, expr) = p.parse_re(0, 0)
  if ix < p.re.length() {
    raise perr(ix, GeneralParseError("end of string not reached"))
  }
  let expr = if p.has_unresolved_subroutines {
    p.has_unresolved_subroutines = false
    p.resolve_named_subroutine_calls(expr)
  } else {
    expr
  }
  {
    expr,
    backrefs: p.backrefs,
    named_groups: p.named_groups,
    contains_subroutines: p.contains_subroutines,
    self_recursive: p.self_recursive,
  }
}

///|
fn Parser::new(re : String, flags : Int) -> Parser {
  let flags = flags | FLAG_UNICODE
  {
    re: @utf8.encode(re),
    backrefs: BitSet::new(),
    named_groups: {},
    numeric_backrefs: false,
    flags,
    curr_group: 0,
    contains_subroutines: false,
    has_unresolved_subroutines: false,
    self_recursive: false,
  }
}

///|
fn Parser::len(self : Parser) -> Int {
  self.re.length()
}

///|
/// The byte at `ix` (`ix` must be in bounds).
fn Parser::byte(self : Parser, ix : Int) -> Int {
  self.re[ix].to_int()
}

///|
/// The byte at `ix`, or -1 if out of bounds (upstream `bytes.get(ix)`).
fn Parser::get(self : Parser, ix : Int) -> Int {
  if ix >= 0 && ix < self.re.length() {
    self.re[ix].to_int()
  } else {
    -1
  }
}

///|
/// Whether the pattern continues with the ASCII string `s` at `ix`.
fn Parser::starts_with(self : Parser, ix : Int, s : String) -> Bool {
  bytes_starts_with(self.re, ix, s)
}

///|
/// The pattern slice `start..end` as a string.
fn Parser::slice(self : Parser, start : Int, end : Int) -> String {
  @utf8.decode_lossy(self.re[start:end])
}

///|
fn bytes_starts_with(re : Bytes, ix : Int, s : String) -> Bool {
  if ix + s.length() > re.length() {
    return false
  }
  for i in 0..<s.length() {
    if re[ix + i].to_int() != s[i].to_int() {
      return false
    }
  }
  true
}

///|
fn Parser::parse_re(
  self : Parser,
  ix : Int,
  depth : Int,
) -> (Int, Expr) raise FancyError {
  let (ix, child) = self.parse_branch(ix, depth)
  let mut ix = self.optional_whitespace(ix)
  if self.starts_with(ix, "|") {
    let children = [child]
    while self.starts_with(ix, "|") {
      ix += 1
      let (next, child) = self.parse_branch(ix, depth)
      children.push(child)
      ix = self.optional_whitespace(next)
    }
    return (ix, Alt(children))
  }
  // can't have numeric backrefs and named backrefs
  if self.numeric_backrefs && !self.named_groups.is_empty() {
    raise FancyError::CompileError(NamedBackrefOnly)
  }
  (ix, child)
}

///|
fn Parser::parse_branch(
  self : Parser,
  ix : Int,
  depth : Int,
) -> (Int, Expr) raise FancyError {
  let children = []
  let mut ix = ix
  while ix < self.len() {
    let (next, child) = self.parse_piece(ix, depth)
    if next == ix {
      break
    }
    if child != Empty {
      children.push(child)
    }
    ix = next
  }
  match children.length() {
    0 => (ix, Empty)
    1 => (ix, children[0])
    _ => (ix, Concat(children))
  }
}

///|
fn Parser::parse_piece(
  self : Parser,
  ix : Int,
  depth : Int,
) -> (Int, Expr) raise FancyError {
  let (ix, child) = self.parse_atom(ix, depth)
  let mut ix = self.optional_whitespace(ix)
  if ix < self.len() {
    // fail when child is empty?
    let (lo, hi) = match self.byte(ix) {
      '?' => (0, 1)
      '*' => (0, USIZE_MAX)
      '+' => (1, USIZE_MAX)
      '{' =>
        try self.parse_repeat(ix) catch {
          _ =>
            // Invalid repeat syntax, which results in `{` being treated as a literal
            return (ix, child)
        } noraise {
          (next, lo, hi) => {
            ix = next - 1
            (lo, hi)
          }
        }
      _ => return (ix, child)
    }
    if !self.is_repeatable(child) {
      raise perr(ix, TargetNotRepeatable)
    }
    ix += 1
    ix = self.optional_whitespace(ix)
    let mut greedy = true
    if ix < self.len() && self.byte(ix) == '?' {
      greedy = false
      ix += 1
    }
    if self.flag(FLAG_SWAP_GREED) {
      greedy = !greedy
    }
    let mut node = Repeat(child~, lo~, hi~, greedy~)
    if ix < self.len() && self.byte(ix) == '+' {
      ix += 1
      node = AtomicGroup(node)
    }
    return (ix, node)
  }
  (ix, child)
}

///|
fn Parser::is_repeatable(_self : Parser, child : Expr) -> Bool {
  match child {
    LookAround(_, _) => false
    Empty => false
    Assertion(_) => false
    KeepOut => false
    ContinueFromPreviousMatchEnd => false
    BackrefExistsCondition(_) => false
    _ => true
  }
}

///|
/// Returns (ix, lo, hi).
fn Parser::parse_repeat(
  self : Parser,
  ix : Int,
) -> (Int, Int, Int) raise FancyError {
  let ix = self.optional_whitespace(ix + 1) // skip opening '{'
  if ix == self.len() {
    raise perr(ix, InvalidRepeat)
  }
  let mut end = ix
  let lo = if self.byte(ix) == ',' {
    0
  } else if parse_decimal(self.re, ix) is Some((next, lo)) {
    end = next
    lo
  } else {
    raise perr(ix, InvalidRepeat)
  }
  let ix = self.optional_whitespace(end) // past lo number
  if ix == self.len() {
    raise perr(ix, InvalidRepeat)
  }
  end = ix
  let hi = match self.byte(ix) {
    '}' => lo
    ',' => {
      end = self.optional_whitespace(ix + 1) // past ','
      if parse_decimal(self.re, end) is Some((next, hi)) {
        end = next
        hi
      } else {
        USIZE_MAX
      }
    }
    _ => raise perr(ix, InvalidRepeat)
  }
  let ix = self.optional_whitespace(end) // past hi number
  if ix == self.len() || self.byte(ix) != '}' {
    raise perr(ix, InvalidRepeat)
  }
  (ix + 1, lo, hi)
}

///|
fn Parser::parse_atom(
  self : Parser,
  ix : Int,
  depth : Int,
) -> (Int, Expr) raise FancyError {
  let ix = self.optional_whitespace(ix)
  if ix == self.len() {
    return (ix, Empty)
  }
  match self.byte(ix) {
    '.' => (ix + 1, Any(newline=self.flag(FLAG_DOTNL)))
    '^' =>
      (
        ix + 1,
        if self.flag(FLAG_MULTI) {
          // TODO: support crlf flag
          Assertion(StartLine(crlf=false))
        } else {
          Assertion(StartText)
        },
      )
    '$' =>
      (
        ix + 1,
        if self.flag(FLAG_MULTI) {
          // TODO: support crlf flag
          Assertion(EndLine(crlf=false))
        } else {
          Assertion(EndText)
        },
      )
    '(' => self.parse_group(ix, depth)
    '\\' => self.parse_escape(ix, false)
    '+' | '*' | '?' | '|' | ')' => (ix, Empty)
    '[' => self.parse_class(ix)
    b => {
      // TODO: maybe want to match multiple codepoints?
      let next = ix + codepoint_len(b)
      (next, Literal(val=self.slice(ix, next), casei=self.flag(FLAG_CASEI)))
    }
  }
}

///|
fn Parser::parse_named_backref(
  self : Parser,
  ix : Int,
  open : String,
  close : String,
  allow_relative : Bool,
) -> (Int, Expr) raise FancyError {
  let { ix: end, group_ix, group_name, recursion_level, } = self.parse_named_backref_or_subroutine(
    ix, open, close, allow_relative,
  )
  if group_ix is Some(group) {
    self.backrefs.insert(group) |> ignore
    return (
      end,
      if recursion_level is Some(recursion_level) {
        BackrefWithRelativeRecursionLevel(
          group~,
          relative_level=recursion_level,
          casei=self.flag(FLAG_CASEI),
        )
      } else {
        Backref(group~, casei=self.flag(FLAG_CASEI))
      },
    )
  }
  if group_name is Some(group_name) {
    // here the name was parsed but doesn't match a capture group we have already parsed
    raise perr(ix, InvalidGroupNameBackref(group_name))
  }
  abort("unreachable")
}

///|
fn Parser::parse_named_subroutine_call(
  self : Parser,
  ix : Int,
  open : String,
  close : String,
  allow_relative : Bool,
) -> (Int, Expr) raise FancyError {
  let { ix: end, group_ix, group_name, recursion_level, } = self.parse_named_backref_or_subroutine(
    ix, open, close, allow_relative,
  )
  if recursion_level is Some(_) {
    raise perr(ix, InvalidGroupName)
  }
  if group_ix is Some(group) {
    self.contains_subroutines = true
    if group == 0 {
      self.self_recursive = true
    }
    return (end, SubroutineCall(group))
  }
  if group_name is Some(group_name) {
    // here the name was parsed but doesn't match a capture group we have already parsed
    let expr = UnresolvedNamedSubroutineCall(name=group_name, ix~)
    self.has_unresolved_subroutines = true
    self.contains_subroutines = true
    return (end, expr)
  }
  abort("unreachable")
}

///|
fn Parser::parse_named_backref_or_subroutine(
  self : Parser,
  ix : Int,
  open : String,
  close : String,
  allow_relative : Bool,
) -> NamedBackrefOrSubroutine raise FancyError {
  if parse_id(self.re, ix, open, close, allow_relative)
    is Some({ id, relative, skip, }) {
    let mut relative = relative
    let group = if self.named_groups.get(id) is Some(group) {
      Some(group)
    } else if parse_usize(id) is Some(group) {
      Some(group)
    } else if relative is Some(relative_group) {
      if id.is_empty() {
        relative = None
        let n = self.curr_group +
          (if relative_group < 0 { relative_group + 1 } else { relative_group })
        if n >= 0 {
          Some(n)
        } else {
          None
        }
      } else {
        None
      }
    } else {
      None
    }
    if group is Some(group) {
      {
        ix: ix + skip,
        group_ix: Some(group),
        group_name: None,
        recursion_level: relative,
      }
    } else {
      // here the name was parsed but doesn't match a capture group we have already parsed
      {
        ix: ix + skip,
        group_ix: None,
        group_name: Some(id),
        recursion_level: relative,
      }
    }
  } else {
    // in this case the name can't be parsed
    raise perr(ix, InvalidGroupName)
  }
}

///|
fn Parser::parse_numbered_backref(
  self : Parser,
  ix : Int,
) -> (Int, Expr) raise FancyError {
  let (end, group) = self.parse_numbered_backref_or_subroutine_call(ix)
  self.numeric_backrefs = true
  self.backrefs.insert(group) |> ignore
  (end, Backref(group~, casei=self.flag(FLAG_CASEI)))
}

///|
fn Parser::parse_numbered_subroutine_call(
  self : Parser,
  ix : Int,
) -> (Int, Expr) raise FancyError {
  let (end, group) = self.parse_numbered_backref_or_subroutine_call(ix)
  self.numeric_backrefs = true
  self.contains_subroutines = true
  if group == 0 {
    self.self_recursive = true
  }
  (end, SubroutineCall(group))
}

///|
fn Parser::parse_numbered_backref_or_subroutine_call(
  self : Parser,
  ix : Int,
) -> (Int, Int) raise FancyError {
  if parse_decimal(self.re, ix) is Some((end, group)) {
    // protect BitSet against unreasonably large value
    if group < self.len() / 2 {
      return (end, group)
    }
  }
  raise perr(ix, InvalidBackref)
}

///|
/// `ix` points to `\` character
fn Parser::parse_escape(
  self : Parser,
  ix : Int,
  in_class : Bool,
) -> (Int, Expr) raise FancyError {
  let b = self.get(ix + 1)
  if b < 0 {
    raise perr(ix, TrailingBackslash)
  }
  let end = ix + 1 + codepoint_len(b)
  if is_ascii_digit(b) {
    return self.parse_numbered_backref(ix + 1)
  } else if b == 'k' && !in_class {
    // Named backref: \k<name>
    if self.get(end) == '\'' {
      return self.parse_named_backref(end, "'", "'", true)
    } else {
      return self.parse_named_backref(end, "<", ">", true)
    }
  } else if b == 'A' && !in_class {
    (end, Assertion(StartText))
  } else if b == 'z' && !in_class {
    (end, Assertion(EndText))
  } else if b == 'Z' && !in_class {
    (end, LookAround(Delegate(inner="\\n*$", size=0, casei=false), LookAhead))
  } else if b == 'b' && !in_class {
    if self.get(end) == '{' {
      // Support for \b{...} is not implemented yet
      raise perr(ix, InvalidEscape("\\\{self.slice(ix + 1, end)}"))
    }
    (end, Assertion(WordBoundary))
  } else if b == 'B' && !in_class {
    if self.get(end) == '{' {
      // Support for \b{...} is not implemented yet
      raise perr(ix, InvalidEscape("\\\{self.slice(ix + 1, end)}"))
    }
    (end, Assertion(NotWordBoundary))
  } else if b == '<' && !in_class {
    let expr = if self.flag(FLAG_ONIGURUMA_MODE) {
      make_literal("<")
    } else {
      Assertion(LeftWordBoundary)
    }
    (end, expr)
  } else if b == '>' && !in_class {
    let expr = if self.flag(FLAG_ONIGURUMA_MODE) {
      make_literal(">")
    } else {
      Assertion(RightWordBoundary)
    }
    (end, expr)
  } else if (b | 32) is ('d' | 's' | 'w') {
    (
      end,
      Delegate(inner=self.slice(ix, end), size=1, casei=self.flag(FLAG_CASEI)),
    )
  } else if (b | 32) == 'h' {
    let s = if b == 'h' { "[0-9A-Fa-f]" } else { "[^0-9A-Fa-f]" }
    (end, Delegate(inner=s, size=1, casei=false))
  } else if b == 'x' {
    return self.parse_hex(end, 2)
  } else if b == 'u' {
    return self.parse_hex(end, 4)
  } else if b == 'U' {
    return self.parse_hex(end, 8)
  } else if (b | 32) == 'p' && end != self.len() {
    let mut end = end
    let b = self.byte(end)
    end += codepoint_len(b)
    if b == '{' {
      while true {
        if end == self.len() {
          raise perr(ix, UnclosedUnicodeName)
        }
        let b = self.byte(end)
        if b == '}' {
          end += 1
          break
        }
        end += codepoint_len(b)
      }
    }
    (
      end,
      Delegate(inner=self.slice(ix, end), size=1, casei=self.flag(FLAG_CASEI)),
    )
  } else if b == 'K' && !in_class {
    (end, KeepOut)
  } else if b == 'G' && !in_class {
    (end, ContinueFromPreviousMatchEnd)
  } else if b == 'O' && !in_class {
    (end, Any(newline=true))
  } else if b == 'g' && !in_class {
    if end == self.len() {
      raise perr(ix, InvalidEscape("\\g"))
    }
    let b = self.byte(end)
    if is_ascii_digit(b) {
      self.parse_numbered_subroutine_call(end)
    } else if b == '\'' {
      self.parse_named_subroutine_call(end, "'", "'", true)
    } else {
      self.parse_named_subroutine_call(end, "<", ">", true)
    }
  } else {
    // printable ASCII (including space, see issue #29)
    let lit = match b {
      'a' => "\u{07}" // BEL
      'b' => "\u{08}" // BS
      'f' => "\u{0c}" // FF
      'n' => "\n" // LF
      'r' => "\r" // CR
      't' => "\t" // TAB
      'v' => "\u{0b}" // VT
      'e' => "\u{1b}" // ESC
      ' ' => " "
      b => {
        let s = self.slice(ix + 1, end)
        if is_ascii_alphabetic(b) &&
          !(b is ('k' | 'A' | 'z' | 'b' | 'B' | '<' | '>' | 'K' | 'G')) {
          raise perr(ix, InvalidEscape("\\\{s}"))
        } else {
          s
        }
      }
    }
    (end, make_literal(lit))
  }
}

///|
/// `ix` points after `\x`, eg to `A0` or `{12345}`, or after `\u` or `\U`
fn Parser::parse_hex(
  self : Parser,
  ix : Int,
  digits : Int,
) -> (Int, Expr) raise FancyError {
  if ix >= self.len() {
    // Incomplete escape sequence
    raise perr(ix, InvalidHex)
  }
  let b = self.byte(ix)
  let all_hex = ix + digits <= self.len() &&
    (for i in ix..<(ix + digits) {
      if !is_hex_digit(self.byte(i)) {
        break false
      }
    } nobreak {
      true
    })
  let (end, start, stop) = if all_hex {
    let end = ix + digits
    (end, ix, end)
  } else if b == '{' {
    let starthex = ix + 1
    let mut endhex = starthex
    while true {
      if endhex == self.len() {
        raise perr(ix, InvalidHex)
      }
      let b = self.byte(endhex)
      if endhex > starthex && b == '}' {
        break
      }
      if is_hex_digit(b) && endhex < starthex + 8 {
        endhex += 1
      } else {
        raise perr(ix, InvalidHex)
      }
    }
    (endhex + 1, starthex, endhex)
  } else {
    raise perr(ix, InvalidHex)
  }
  let mut codepoint = 0L
  for i in start..<stop {
    codepoint = codepoint * 16L + hex_value(self.byte(i)).to_int64()
  }
  if codepoint <= 0x10FFFFL && !(codepoint >= 0xD800L && codepoint <= 0xDFFFL) {
    let c = codepoint.to_int()
    (end, Literal(val=char_to_string(c), casei=self.flag(FLAG_CASEI)))
  } else {
    raise perr(ix, InvalidCodepointValue)
  }
}

///|
fn Parser::parse_class(self : Parser, ix : Int) -> (Int, Expr) raise FancyError {
  let mut ix = ix + 1 // skip opening '['
  let class = StringBuilder()
  let mut nest = 1
  class.write_char('[')

  // Negated character class
  if self.get(ix) == '^' {
    class.write_char('^')
    ix += 1
  }

  // `]` does not have to be escaped after opening `[` or `[^`
  if self.get(ix) == ']' {
    class.write_char(']')
    ix += 1
  }
  while true {
    if ix == self.len() {
      raise perr(ix, InvalidClass)
    }
    let end = match self.byte(ix) {
      '\\' => {
        // We support more escapes than regex, so parse it ourselves before delegating.
        let (end, expr) = self.parse_escape(ix, true)
        match expr {
          Literal(val~, ..) => escape_into(val, class)
          Delegate(inner~, ..) => class.write_string(inner)
          _ => raise perr(ix, InvalidClass)
        }
        end
      }
      '[' => {
        nest += 1
        class.write_char('[')
        ix + 1
      }
      ']' => {
        nest -= 1
        class.write_char(']')
        if nest == 0 {
          break
        }
        ix + 1
      }
      b => {
        let end = ix + codepoint_len(b)
        class.write_string(self.slice(ix, end))
        end
      }
    }
    ix = end
  }
  let class = Expr::Delegate(
    inner=class.to_string(),
    size=1,
    casei=self.flag(FLAG_CASEI),
  )
  let ix = ix + 1 // skip closing ']'
  (ix, class)
}

///|
fn Parser::parse_group(
  self : Parser,
  ix : Int,
  depth : Int,
) -> (Int, Expr) raise FancyError {
  let depth = depth + 1
  if depth >= MAX_RECURSION {
    raise perr(ix, RecursionExceeded)
  }
  let ix = self.optional_whitespace(ix + 1)
  let (la, skip) = if self.starts_with(ix, "?=") {
    (Some(LookAround::LookAhead), 2)
  } else if self.starts_with(ix, "?!") {
    (Some(LookAheadNeg), 2)
  } else if self.starts_with(ix, "?<=") {
    (Some(LookBehind), 3)
  } else if self.starts_with(ix, "?<!") {
    (Some(LookBehindNeg), 3)
  } else if self.starts_with(ix, "?<") || self.starts_with(ix, "?'") {
    // Named capture group using Oniguruma syntax: (?<name>...) or (?'name'...)
    self.curr_group += 1
    let (open, close) = if self.starts_with(ix, "?<") {
      ("<", ">")
    } else {
      ("'", "'")
    }
    if parse_id(self.re, ix + 1, open, close, false)
      is Some({ id, relative: None, skip, }) {
      self.named_groups[id] = self.curr_group
      (None, skip + 1)
    } else {
      raise perr(ix, InvalidGroupName)
    }
  } else if self.starts_with(ix, "?P<") {
    // Named capture group using Python syntax: (?P<name>...)
    self.curr_group += 1 // this is a capture group
    if parse_id(self.re, ix + 2, "<", ">", false)
      is Some({ id, relative: None, skip, }) {
      self.named_groups[id] = self.curr_group
      (None, skip + 2)
    } else {
      raise perr(ix, InvalidGroupName)
    }
  } else if self.starts_with(ix, "?P=") {
    // Backref using Python syntax: (?P=name)
    return self.parse_named_backref(ix + 3, "", ")", false)
  } else if self.starts_with(ix, "?>") {
    (None, 2)
  } else if self.starts_with(ix, "?(") {
    return self.parse_conditional(ix + 2, depth)
  } else if self.starts_with(ix, "?P>") {
    return self.parse_named_subroutine_call(ix + 3, "", ")", false)
  } else if self.starts_with(ix, "?") {
    return self.parse_flags(ix, depth)
  } else {
    self.curr_group += 1 // this is a capture group
    (None, 0)
  }
  let ix = ix + skip
  let (ix, child) = self.parse_re(ix, depth)
  let ix = self.check_for_close_paren(ix)
  let result = match (la, skip) {
    (Some(la), _) => LookAround(child, la)
    (None, 2) => AtomicGroup(child)
    _ => Group(child)
  }
  (ix, result)
}

///|
fn Parser::check_for_close_paren(
  self : Parser,
  ix : Int,
) -> Int raise FancyError {
  let ix = self.optional_whitespace(ix)
  if ix == self.len() {
    raise perr(ix, UnclosedOpenParen)
  } else if self.byte(ix) != ')' {
    raise perr(ix, GeneralParseError("expected close paren"))
  }
  ix + 1
}

///|
/// `ix` points to `?` in `(?`
fn Parser::parse_flags(
  self : Parser,
  ix : Int,
  depth : Int,
) -> (Int, Expr) raise FancyError {
  let start = ix + 1
  fn unknown_flag(p : Parser, start : Int, end : Int) -> FancyError {
    let after_end = end + codepoint_len(p.byte(end))
    let s = "(?\{p.slice(start, after_end)}"
    perr(start, UnknownFlag(s))
  }

  let mut ix = start
  let mut neg = false
  let oldflags = self.flags
  while true {
    ix = self.optional_whitespace(ix)
    if ix == self.len() {
      raise perr(ix, UnclosedOpenParen)
    }
    let b = self.byte(ix)
    match b {
      'i' => self.update_flag(FLAG_CASEI, neg)
      'm' => self.update_flag(FLAG_MULTI, neg)
      's' => self.update_flag(FLAG_DOTNL, neg)
      'U' => self.update_flag(FLAG_SWAP_GREED, neg)
      'x' => self.update_flag(FLAG_IGNORE_SPACE, neg)
      'u' => if neg { raise perr(ix, NonUnicodeUnsupported) }
      '-' => {
        if neg {
          raise unknown_flag(self, start, ix)
        }
        neg = true
      }
      ')' => {
        if ix == start || (neg && ix == start + 1) {
          raise unknown_flag(self, start, ix)
        }
        return (ix + 1, Empty)
      }
      ':' => {
        if neg && ix == start + 1 {
          raise unknown_flag(self, start, ix)
        }
        ix += 1
        let (ix, child) = self.parse_re(ix, depth)
        if ix == self.len() {
          raise perr(ix, UnclosedOpenParen)
        } else if self.byte(ix) != ')' {
          raise perr(ix, GeneralParseError("expected close paren"))
        }
        self.flags = oldflags
        return (ix + 1, child)
      }
      _ => raise unknown_flag(self, start, ix)
    }
    ix += 1
  }
  abort("unreachable")
}

///|
/// `ix` points to after the last `(` in `(?(`
fn Parser::parse_conditional(
  self : Parser,
  ix : Int,
  depth : Int,
) -> (Int, Expr) raise FancyError {
  if ix >= self.len() {
    raise perr(ix, UnclosedOpenParen)
  }
  // get the character after the open paren
  let b = self.byte(ix)
  let (next, condition) = if b == '\'' {
    self.parse_named_backref(ix, "'", "')", true)
  } else if b == '<' {
    self.parse_named_backref(ix, "<", ">)", true)
  } else if b == '+' || b == '-' || is_ascii_digit(b) {
    self.parse_named_backref(ix, "", ")", true)
  } else {
    let (next, condition) = self.parse_re(ix, depth)
    (self.check_for_close_paren(next), condition)
  }
  let (end, child) = self.parse_re(next, depth)
  if end == next {
    // Backreference validity checker
    if condition is Backref(group~, ..) {
      let after = self.check_for_close_paren(end)
      return (after, BackrefExistsCondition(group))
    } else {
      raise perr(
        end,
        GeneralParseError(
          "expected conditional to be a backreference or at least an expression for when the condition is true",
        ),
      )
    }
  }
  let (if_true, if_false) = if child is Alt(alternatives) {
    // the truth branch will be the first alternative
    let if_true = alternatives[0]
    let rest = alternatives[1:].to_owned()
    // if there is only one alternative left, take it out the Expr::Alt
    if rest.length() == 1 {
      (if_true, rest[0])
    } else {
      // otherwise the remaining branches become the false branch
      (if_true, Alt(rest))
    }
  } else {
    // there is only one branch - the truth branch. i.e. "if" without "else"
    (child, Empty)
  }
  let inner_condition = if condition is Backref(group~, ..) {
    Expr::BackrefExistsCondition(group)
  } else {
    condition
  }
  let after = self.check_for_close_paren(end)
  (
    after,
    if if_true == Empty && if_false == Empty {
      inner_condition
    } else {
      Conditional(
        condition=inner_condition,
        true_branch=if_true,
        false_branch=if_false,
      )
    },
  )
}

///|
fn Parser::flag(self : Parser, flag : Int) -> Bool {
  let v = self.flags & flag
  v == flag
}

///|
fn Parser::update_flag(self : Parser, flag : Int, neg : Bool) -> Unit {
  if neg {
    self.flags = self.flags & flag.lnot()
  } else {
    self.flags = self.flags | flag
  }
}

///|
fn Parser::optional_whitespace(self : Parser, ix : Int) -> Int raise FancyError {
  let mut ix = ix
  while true {
    if ix == self.len() {
      return ix
    }
    match self.byte(ix) {
      '#' if self.flag(FLAG_IGNORE_SPACE) => {
        let mut j = ix
        while j < self.len() && self.byte(j) != '\n' {
          j += 1
        }
        if j < self.len() {
          ix = j + 1
        } else {
          return self.len()
        }
      }
      ' ' | '\r' | '\n' | '\t' if self.flag(FLAG_IGNORE_SPACE) => ix += 1
      '(' if self.starts_with(ix, "(?#") => {
        ix += 3
        while true {
          if ix >= self.len() {
            raise perr(ix, UnclosedOpenParen)
          }
          match self.byte(ix) {
            ')' => {
              ix += 1
              break
            }
            '\\' => ix += 2
            _ => ix += 1
          }
        }
      }
      _ => return ix
    }
  }
  ix
}

///|
fn Parser::resolve_named_subroutine_calls(self : Parser, expr : Expr) -> Expr {
  match expr {
    UnresolvedNamedSubroutineCall(name~, ..) =>
      if self.named_groups.get(name) is Some(group) {
        SubroutineCall(group)
      } else {
        self.has_unresolved_subroutines = true
        expr
      }
    // recursively resolve in inner expressions
    Group(inner) => Group(self.resolve_named_subroutine_calls(inner))
    LookAround(inner, la) =>
      LookAround(self.resolve_named_subroutine_calls(inner), la)
    AtomicGroup(inner) =>
      AtomicGroup(self.resolve_named_subroutine_calls(inner))
    Concat(children) =>
      Concat(children.map(c => self.resolve_named_subroutine_calls(c)))
    Alt(children) =>
      Alt(children.map(c => self.resolve_named_subroutine_calls(c)))
    Repeat(child~, lo~, hi~, greedy~) =>
      Repeat(
        child=self.resolve_named_subroutine_calls(child),
        lo~,
        hi~,
        greedy~,
      )
    Conditional(condition~, true_branch~, false_branch~) =>
      Conditional(
        condition=self.resolve_named_subroutine_calls(condition),
        true_branch=self.resolve_named_subroutine_calls(true_branch),
        false_branch=self.resolve_named_subroutine_calls(false_branch),
      )
    _ => expr
  }
}

///|
/// Parse a decimal number of ASCII digits starting at `ix`, returning
/// `(end, value)` (fails on no digits or overflow).
pub fn parse_decimal(s : Bytes, ix : Int) -> (Int, Int)? {
  let mut end = ix
  while end < s.length() && is_ascii_digit(s[end].to_int()) {
    end += 1
  }
  if end == ix {
    return None
  }
  let mut val = 0L
  for i in ix..<end {
    val = val * 10L + (s[i].to_int() - '0').to_int64()
    if val > USIZE_MAX.to_int64() {
      return None
    }
  }
  Some((end, val.to_int()))
}

///|
/// Rust's `str::parse::<usize>` (on identifiers: an optional `+` is not
/// possible there).
fn parse_usize(s : String) -> Int? {
  if s.is_empty() {
    return None
  }
  let mut val = 0L
  for i in 0..<s.length() {
    let c = s[i].to_int()
    if !is_ascii_digit(c) {
      return None
    }
    val = val * 10L + (c - '0').to_int64()
    if val > USIZE_MAX.to_int64() {
      return None
    }
  }
  Some(val.to_int())
}

///|
/// The result of `parse_id`.
pub struct ParsedId {
  id : String
  relative : Int?
  skip : Int
} derive(Eq, Debug)

///|
/// Attempts to parse an identifier, optionally followed by a relative number
/// between the specified opening and closing delimiters, in `s` starting at
/// byte `start`. On success, returns the id, the relative number and `skip`,
/// how many bytes of the string were used.
pub fn parse_id(
  s : Bytes,
  start : Int,
  open : String,
  close : String,
  allow_relative : Bool,
) -> ParsedId? {
  let len = s.length() - start
  if !bytes_starts_with(s, start, open) || len <= open.length() + close.length() {
    return None
  }
  let id_start = start + open.length()
  let mut i = id_start
  let mut after_id : Int? = None
  while i < s.length() {
    let (c, n) = decode_utf8(s, i)
    if !is_id_char(c) {
      after_id = Some(i)
      break
    }
    i += n
  }
  let id_end = match after_id {
    Some(i) => i
    None if close.is_empty() => s.length()
    _ => id_start
  }
  let id_len = id_end - id_start
  if id_len > 0 && bytes_starts_with(s, id_end, close) {
    return Some({
      id: @utf8.decode_lossy(s[id_start:id_end]),
      relative: None,
      skip: id_end + close.length() - start,
    })
  } else if !allow_relative {
    return None
  }
  let relative_sign = s[id_end].to_int()
  if relative_sign == '+' || relative_sign == '-' {
    if parse_decimal(s, id_end + 1) is Some((end, relative_amount)) {
      if bytes_starts_with(s, end, close) {
        if relative_amount == 0 && id_len == 0 {
          return None
        }
        let relative_amount_signed = if relative_sign == '-' {
          -relative_amount
        } else {
          relative_amount
        }
        return Some({
          id: @utf8.decode_lossy(s[id_start:id_end]),
          relative: Some(relative_amount_signed),
          skip: end + close.length() - start,
        })
      }
    }
  }
  None
}

///|
fn is_id_char(c : Int) -> Bool {
  c == '_' || @unicode.is_alphanumeric(Int::unsafe_to_char(c))
}

///|
fn is_hex_digit(b : Int) -> Bool {
  is_ascii_digit(b) || ((b | 32) >= 'a' && (b | 32) <= 'f')
}

///|
fn hex_value(b : Int) -> Int {
  if is_ascii_digit(b) {
    b - '0'
  } else {
    (b | 32) - 'a' + 10
  }
}

///|
fn is_ascii_digit(b : Int) -> Bool {
  b >= '0' && b <= '9'
}

///|
fn is_ascii_alphabetic(b : Int) -> Bool {
  (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z')
}

///|
/// The length of the UTF-8 sequence starting with byte `b`.
fn codepoint_len(b : Int) -> Int {
  if b < 0x80 {
    1
  } else if b < 0xe0 {
    2
  } else if b < 0xf0 {
    3
  } else {
    4
  }
}

///|
/// Decode the (valid) UTF-8 sequence at `i`: (char, length).
fn decode_utf8(s : Bytes, i : Int) -> (Int, Int) {
  let b = s[i].to_int()
  let n = codepoint_len(b)
  let mut c = match n {
    1 => b
    2 => b & 0x1F
    3 => b & 0x0F
    _ => b & 0x07
  }
  for k in 1..<n {
    if i + k < s.length() {
      c = (c << 6) | (s[i + k].to_int() & 0x3F)
    }
  }
  (c, n)
}

///|
fn char_to_string(c : Int) -> String {
  Int::unsafe_to_char(c).to_string()
}

///|
/// regex-syntax's `escape_into`: escape the meta characters of `text`.
fn escape_into(text : String, buf : StringBuilder) -> Unit {
  for c in text {
    if is_meta_character(c) {
      buf.write_char('\\')
    }
    buf.write_char(c)
  }
}

///|
/// regex-syntax's `is_meta_character`.
fn is_meta_character(c : Char) -> Bool {
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
pub fn make_literal(s : String) -> Expr {
  make_literal_case_insensitive(s, false)
}

///|
pub fn make_literal_case_insensitive(
  s : String,
  case_insensitive : Bool,
) -> Expr {
  Literal(val=s, casei=case_insensitive)
}
