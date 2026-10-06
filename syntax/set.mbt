///|
/// A set of syntax kinds (bitset over [SyntaxKind::index]).
pub(all) struct SyntaxSet {
  a : UInt64
  b : UInt64
  c : UInt64
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SyntaxSet with Eq::{not_equal, equal}

///|
pub fn SyntaxSet::new() -> SyntaxSet {
  { a: 0, b: 0, c: 0, }
}

///|
/// Build a set from a list of kinds.
pub fn SyntaxSet::of(kinds : ArrayView[SyntaxKind]) -> SyntaxSet {
  kinds.fold(init=SyntaxSet::new(), (s, k) => s.add(k))
}

///|
pub fn SyntaxSet::add(self : SyntaxSet, kind : SyntaxKind) -> SyntaxSet {
  let i = kind.index()
  let bit = 1UL << (i % 64)
  match i / 64 {
    0 => { ..self, a: self.a | bit, }
    1 => { ..self, b: self.b | bit, }
    _ => { ..self, c: self.c | bit, }
  }
}

///|
pub fn SyntaxSet::remove(self : SyntaxSet, kind : SyntaxKind) -> SyntaxSet {
  let i = kind.index()
  let bit = (1UL << (i % 64)).lnot()
  match i / 64 {
    0 => { ..self, a: self.a & bit, }
    1 => { ..self, b: self.b & bit, }
    _ => { ..self, c: self.c & bit, }
  }
}

///|
pub fn SyntaxSet::union(self : SyntaxSet, other : SyntaxSet) -> SyntaxSet {
  { a: self.a | other.a, b: self.b | other.b, c: self.c | other.c, }
}

///|
pub fn SyntaxSet::contains(self : SyntaxSet, kind : SyntaxKind) -> Bool {
  let i = kind.index()
  let word = match i / 64 {
    0 => self.a
    1 => self.b
    _ => self.c
  }
  ((word >> (i % 64)) & 1UL) != 0UL
}

///|
/// Syntax kinds that can start a statement.
pub let stmt_set : SyntaxSet = SyntaxSet::of([
  Let,
  Set,
  Show,
  Import,
  Include,
  Return,
])

///|
/// Syntax kinds that can start a math expression.
pub let math_expr_set : SyntaxSet = SyntaxSet::of([
  Hash,
  MathIdent,
  MathFieldAccess,
  Dot,
  Comma,
  Semicolon,
  LeftBrace,
  RightBrace,
  LeftParen,
  RightParen,
  MathText,
  MathShorthand,
  Linebreak,
  MathAlignPoint,
  MathPrimes,
  Escape,
  Str,
  Root,
  Bang,
])

///|
/// Syntax kinds that can start an atomic code expression.
pub let atomic_code_expr_set : SyntaxSet = SyntaxSet::of([
  Ident,
  LeftBrace,
  LeftBracket,
  LeftParen,
  Dollar,
  Let,
  Set,
  Show,
  Context,
  If,
  While,
  For,
  Import,
  Include,
  Break,
  Continue,
  Return,
  None,
  Auto,
  Int,
  Float,
  Bool,
  Numeric,
  Str,
  Label,
  Raw,
])

///|
/// Syntax kinds that are unary operators.
pub let unary_op_set : SyntaxSet = SyntaxSet::of([Plus, Minus, Not])

///|
/// Syntax kinds that can start a code expression.
pub let code_expr_set : SyntaxSet = atomic_code_expr_set
  .union(unary_op_set)
  .add(Underscore)

///|
/// Syntax kinds that are binary operators.
pub let binary_op_set : SyntaxSet = SyntaxSet::of([
  Plus,
  Minus,
  Star,
  Slash,
  And,
  Or,
  EqEq,
  ExclEq,
  Lt,
  LtEq,
  Gt,
  GtEq,
  Eq,
  In,
  PlusEq,
  HyphEq,
  StarEq,
  SlashEq,
])

///|
/// Syntax kinds that can start an argument in a function call.
pub let array_or_dict_item_set : SyntaxSet = code_expr_set.add(Dots)

///|
/// Syntax kinds that can start an argument in a function call.
pub let arg_set : SyntaxSet = code_expr_set.add(Dots)

///|
/// Syntax kinds that can start a pattern leaf.
pub let pattern_leaf_set : SyntaxSet = atomic_code_expr_set

///|
/// Syntax kinds that can start a pattern.
pub let pattern_set : SyntaxSet = pattern_leaf_set
  .add(LeftParen)
  .add(Underscore)

///|
/// Syntax kinds that can start a parameter in a parameter list.
pub let param_set : SyntaxSet = pattern_set.add(Dots)

///|
/// Syntax kinds that can start a destructuring item.
pub let destructuring_item_set : SyntaxSet = pattern_set.add(Dots)
