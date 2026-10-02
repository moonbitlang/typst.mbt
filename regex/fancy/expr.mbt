// Port of the AST part of `fancy-regex` 0.16.2 `src/lib.rs` (`Expr`,
// `LookAround`, `Assertion`, `Expr::to_str`, `escape`).

///|
/// Regular expression AST. This is public for now but may change.
pub(all) enum Expr {
  /// An empty expression, e.g. the last branch in `(a|b|)`
  Empty
  /// Any character, regex `.`; `newline`: whether it also matches newlines
  Any(newline~ : Bool)
  /// An assertion
  Assertion(Assertion)
  /// The string as a literal, e.g. `a`; `casei`: whether match is
  /// case-insensitive
  Literal(val~ : String, casei~ : Bool)
  /// Concatenation of multiple expressions, must match in order
  Concat(Array[Expr])
  /// Alternative of multiple expressions, one of them must match
  Alt(Array[Expr])
  /// Capturing group of expression, e.g. `(a.)`
  Group(Expr)
  /// Look-around (e.g. positive/negative look-ahead or look-behind) with an
  /// expression
  LookAround(Expr, LookAround)
  /// Repeat of an expression, e.g. `a*` or `a+` or `a{1,3}` (`hi` is
  /// `USIZE_MAX` if unbounded)
  Repeat(child~ : Expr, lo~ : Int, hi~ : Int, greedy~ : Bool)
  /// Delegate a regex to the regex crate. This is used as a simplification
  /// so that we don't have to represent all the expressions in the AST, e.g.
  /// character classes. `size`: how many characters the regex matches.
  Delegate(inner~ : String, size~ : Int, casei~ : Bool)
  /// Back reference to a capture group, e.g. `\1` in `(abc|def)\1`
  Backref(group~ : Int, casei~ : Bool)
  /// Back reference to a capture group at the given specified relative
  /// recursion level.
  BackrefWithRelativeRecursionLevel(
    group~ : Int,
    relative_level~ : Int,
    casei~ : Bool
  )
  /// Atomic non-capturing group, e.g. `(?>ab|a)`
  AtomicGroup(Expr)
  /// Keep matched text so far out of overall match
  KeepOut
  /// Anchor to match at the position where the previous match ended
  ContinueFromPreviousMatchEnd
  /// Conditional expression based on whether the numbered capture group
  /// matched or not
  BackrefExistsCondition(Int)
  /// If/Then/Else Condition. If there is no Then/Else, these will just be
  /// empty expressions.
  Conditional(condition~ : Expr, true_branch~ : Expr, false_branch~ : Expr)
  /// Subroutine call to the specified group number
  SubroutineCall(Int)
  /// Unresolved subroutine call to the specified group name (`ix`: the
  /// position in the original regex pattern where the call is made)
  UnresolvedNamedSubroutineCall(name~ : String, ix~ : Int)
} derive(Eq, Debug)

///|
/// Type of look-around assertion as used for a look-around expression.
pub(all) enum LookAround {
  /// Look-ahead assertion, e.g. `(?=a)`
  LookAhead
  /// Negative look-ahead assertion, e.g. `(?!a)`
  LookAheadNeg
  /// Look-behind assertion, e.g. `(?<=a)`
  LookBehind
  /// Negative look-behind assertion, e.g. `(?<!a)`
  LookBehindNeg
} derive(Eq, Debug)

///|
/// Type of assertions
pub(all) enum Assertion {
  /// Start of input text
  StartText
  /// End of input text
  EndText
  /// Start of a line
  StartLine(crlf~ : Bool)
  /// End of a line
  EndLine(crlf~ : Bool)
  /// Left word boundary
  LeftWordBoundary
  /// Right word boundary
  RightWordBoundary
  /// Both word boundaries
  WordBoundary
  /// Not word boundary
  NotWordBoundary
} derive(Eq, Debug)

///|
fn Assertion::is_hard(self : Assertion) -> Bool {
  // these will make regex-automata use PikeVM
  self
  is (LeftWordBoundary | RightWordBoundary | WordBoundary | NotWordBoundary)
}

///|
/// Parse the regex and return an expression (AST) and a bit set with the
/// indexes of groups that are referenced by backrefs.
pub fn Expr::parse_tree(re : String) -> ExprTree raise FancyError {
  Parser::parse_with_flags(re, RegexOptions::default().compute_flags())
}

///|
/// Parse the regex and return an expression (AST). Flags should be bit based
/// on the `FLAG_*` constants.
pub fn Expr::parse_tree_with_flags(
  re : String,
  flags : Int,
) -> ExprTree raise FancyError {
  Parser::parse_with_flags(re, flags)
}

///|
/// Convert expression to a regex string in the regex crate's syntax.
///
/// Panics for expressions that are hard, i.e. can not be handled by the
/// regex crate.
pub fn Expr::to_str(self : Expr, buf : StringBuilder, precedence : Int) -> Unit {
  match self {
    Empty => ()
    Any(newline~) => buf.write_string(if newline { "(?s:.)" } else { "." })
    Literal(val~, casei~) => {
      if casei {
        buf.write_string("(?i:")
      }
      push_quoted(buf, val)
      if casei {
        buf.write_char(')')
      }
    }
    Assertion(StartText) => buf.write_char('^')
    Assertion(EndText) => buf.write_char('$')
    Assertion(StartLine(crlf=false)) => buf.write_string("(?m:^)")
    Assertion(EndLine(crlf=false)) => buf.write_string("(?m:$)")
    Assertion(StartLine(crlf=true)) => buf.write_string("(?Rm:^)")
    Assertion(EndLine(crlf=true)) => buf.write_string("(?Rm:$)")
    Concat(children) => {
      if precedence > 1 {
        buf.write_string("(?:")
      }
      for child in children {
        child.to_str(buf, 2)
      }
      if precedence > 1 {
        buf.write_char(')')
      }
    }
    Alt(children) => {
      if precedence > 0 {
        buf.write_string("(?:")
      }
      for i, child in children {
        if i != 0 {
          buf.write_char('|')
        }
        child.to_str(buf, 1)
      }
      if precedence > 0 {
        buf.write_char(')')
      }
    }
    Group(child) => {
      buf.write_char('(')
      child.to_str(buf, 0)
      buf.write_char(')')
    }
    Repeat(child~, lo~, hi~, greedy~) => {
      if precedence > 2 {
        buf.write_string("(?:")
      }
      child.to_str(buf, 3)
      match (lo, hi) {
        (0, 1) => buf.write_char('?')
        (0, USIZE_MAX) => buf.write_char('*')
        (1, USIZE_MAX) => buf.write_char('+')
        (lo, hi) => {
          buf.write_char('{')
          buf.write_string(lo.to_string())
          if lo != hi {
            buf.write_char(',')
            if hi != USIZE_MAX {
              buf.write_string(hi.to_string())
            }
          }
          buf.write_char('}')
        }
      }
      if !greedy {
        buf.write_char('?')
      }
      if precedence > 2 {
        buf.write_char(')')
      }
    }
    Delegate(inner~, casei~, ..) => {
      // at the moment, delegate nodes are just atoms
      if casei {
        buf.write_string("(?i:")
      }
      buf.write_string(inner)
      if casei {
        buf.write_char(')')
      }
    }
    _ => abort("attempting to format hard expr")
  }
}

///|
fn is_special(c : Char) -> Bool {
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
  | '#')
}

///|
fn push_quoted(buf : StringBuilder, s : String) -> Unit {
  for c in s {
    if is_special(c) {
      buf.write_char('\\')
    }
    buf.write_char(c)
  }
}

///|
/// Escapes special characters in `text` with '\\'. Returns a string which,
/// when interpreted as a regex, matches exactly `text`.
pub fn escape(text : String) -> String {
  let buf = StringBuilder()
  push_quoted(buf, text)
  buf.to_string()
}
