///|
/// A unary operator.
pub(all) enum UnOp {
  /// The plus operator: `+`.
  Pos
  /// The negation operator: `-`.
  Neg
  /// The boolean `not`.
  Not
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UnOp with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UnOp with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UnOp with @debug.Debug::{to_repr}

///|
/// Try to convert the token into a unary operation.
pub fn UnOp::from_kind(token : SyntaxKind) -> UnOp? {
  match token {
    Plus => Some(Pos)
    Minus => Some(Neg)
    Not => Some(Not)
    _ => None
  }
}

///|
/// The precedence of this operator.
pub fn UnOp::precedence(self : UnOp) -> Int {
  match self {
    Pos | Neg => 7
    Not => 4
  }
}

///|
/// The string representation of this operation.
pub fn UnOp::as_str(self : UnOp) -> String {
  match self {
    Pos => "+"
    Neg => "-"
    Not => "not"
  }
}

///|
/// A binary operator.
pub(all) enum BinOp {
  Add
  Sub
  Mul
  Div
  And
  Or
  Eq
  Neq
  Lt
  Leq
  Gt
  Geq
  Assign
  In
  NotIn
  AddAssign
  SubAssign
  MulAssign
  DivAssign
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BinOp with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BinOp with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BinOp with @debug.Debug::{to_repr}

///|
/// Try to convert the token into a binary operation.
pub fn BinOp::from_kind(token : SyntaxKind) -> BinOp? {
  match token {
    Plus => Some(Add)
    Minus => Some(Sub)
    Star => Some(Mul)
    Slash => Some(Div)
    And => Some(And)
    Or => Some(Or)
    EqEq => Some(Eq)
    ExclEq => Some(Neq)
    Lt => Some(Lt)
    LtEq => Some(Leq)
    Gt => Some(Gt)
    GtEq => Some(Geq)
    Eq => Some(Assign)
    In => Some(In)
    PlusEq => Some(AddAssign)
    HyphEq => Some(SubAssign)
    StarEq => Some(MulAssign)
    SlashEq => Some(DivAssign)
    _ => None
  }
}

///|
/// The precedence of this operator.
pub fn BinOp::precedence(self : BinOp) -> Int {
  match self {
    Mul | Div => 6
    Add | Sub => 5
    Eq | Neq | Lt | Leq | Gt | Geq | In | NotIn => 4
    And => 3
    Or => 2
    Assign | AddAssign | SubAssign | MulAssign | DivAssign => 1
  }
}

///|
/// The associativity of a binary operator.
pub(all) enum Assoc {
  Left
  Right
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Assoc with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Assoc with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Assoc with @debug.Debug::{to_repr}

///|
/// The associativity of this operator.
pub fn BinOp::assoc(self : BinOp) -> Assoc {
  match self {
    Assign | AddAssign | SubAssign | MulAssign | DivAssign => Right
    _ => Left
  }
}

///|
/// The string representation of this operation.
pub fn BinOp::as_str(self : BinOp) -> String {
  match self {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div => "/"
    And => "and"
    Or => "or"
    Eq => "=="
    Neq => "!="
    Lt => "<"
    Leq => "<="
    Gt => ">"
    Geq => ">="
    In => "in"
    NotIn => "not in"
    Assign => "="
    AddAssign => "+="
    SubAssign => "-="
    MulAssign => "*="
    DivAssign => "/="
  }
}

///|
/// Resolve the escape sequences of a string literal's text (including its
/// quotes), like upstream `ast::Str::get`.
pub fn unescape_str_literal(text : String) -> String {
  let unquoted = text.unsafe_substring(start=1, end=text.length() - 1)
  if !unquoted.contains("\\") {
    return unquoted
  }
  let out = StringBuilder()
  let s = Scanner::new(unquoted)
  while s.eat() is Some(c) {
    if c != '\\' {
      out.write_char(c)
      continue
    }
    let start = s.cursor - 1
    match s.eat() {
      Some('\\') => out.write_char('\\')
      Some('"') => out.write_char('"')
      Some('n') => out.write_char('\n')
      Some('r') => out.write_char('\r')
      Some('t') => out.write_char('\t')
      Some('u') if s.eat_if_char('{') => {
        let sequence = s.eat_while(is_ascii_hexdigit)
        s.eat_if_char('}') |> ignore
        match parse_codepoint(sequence) {
          Some(c) => out.write_char(c)
          None => out.write_string(s.from(start))
        }
      }
      _ => out.write_string(s.from(start))
    }
  }
  out.to_string()
}

///|
fn is_ascii_hexdigit(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}
