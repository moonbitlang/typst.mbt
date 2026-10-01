// Code nodes: blocks, collections, operators, calls and closures.

///|
/// The contained code.
pub fn CodeBlock::body(self : CodeBlock) -> Code {
  cast_first(self.node)
}

///|
/// The list of expressions contained in the code.
pub fn Code::exprs(self : Code) -> Iter[Expr] {
  cast_children(self.node)
}

///|
/// The contained markup.
pub fn ContentBlock::body(self : ContentBlock) -> Markup {
  cast_first(self.node)
}

///|
/// The wrapped expression.
///
/// Should only be accessed if this is contained in an `Expr`.
pub fn Parenthesized::expr(self : Parenthesized) -> Expr {
  cast_first(self.node)
}

///|
/// The wrapped pattern.
///
/// Should only be accessed if this is contained in a `Pattern`.
pub fn Parenthesized::pattern(self : Parenthesized) -> Pattern {
  cast_first(self.node)
}

///|
/// The array's items.
pub fn ArrayLit::items(self : ArrayLit) -> Iter[ArrayItem] {
  cast_children(self.node)
}

///|
/// An item in an array.
pub(all) enum ArrayItem {
  /// A bare expression: `12`.
  Pos(Expr)
  /// A spread expression: `..things`.
  Spread(Spread)
}

///|
pub impl AstNode for ArrayItem with fn from_untyped(node) {
  match node.kind() {
    Spread => Some(ArrayItem::Spread(Spread::{ node, }))
    _ => Expr::from_untyped(node).map(v => ArrayItem::Pos(v))
  }
}

///|
pub impl AstNode for ArrayItem with fn to_untyped(self) {
  match self {
    Pos(v) => v.to_untyped()
    Spread(v) => v.node
  }
}

///|
pub impl AstNode for ArrayItem with fn placeholder() {
  ArrayItem::Pos(Expr::placeholder())
}

///|
pub extend ArrayItem with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// The dictionary's items.
pub fn Dict::items(self : Dict) -> Iter[DictItem] {
  cast_children(self.node)
}

///|
/// An item in an dictionary expression.
pub(all) enum DictItem {
  /// A named pair: `thickness: 3pt`.
  Named(Named)
  /// A keyed pair: `"spacy key": true`.
  Keyed(Keyed)
  /// A spread expression: `..things`.
  Spread(Spread)
}

///|
pub impl AstNode for DictItem with fn from_untyped(node) {
  match node.kind() {
    Named => Some(DictItem::Named(Named::{ node, }))
    Keyed => Some(DictItem::Keyed(Keyed::{ node, }))
    Spread => Some(DictItem::Spread(Spread::{ node, }))
    _ => None
  }
}

///|
pub impl AstNode for DictItem with fn to_untyped(self) {
  match self {
    Named(v) => v.node
    Keyed(v) => v.node
    Spread(v) => v.node
  }
}

///|
pub impl AstNode for DictItem with fn placeholder() {
  DictItem::Spread(Spread::placeholder())
}

///|
pub extend DictItem with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// The name: `thickness`.
pub fn Named::name(self : Named) -> Ident {
  cast_first(self.node)
}

///|
/// The right-hand side of the pair: `3pt`.
///
/// This should only be accessed if this `Named` is contained in a
/// `DictItem`, `Arg`, or `Param`.
pub fn Named::expr(self : Named) -> Expr {
  cast_last(self.node)
}

///|
/// The right-hand side of the pair as a pattern.
///
/// This should only be accessed if this `Named` is contained in a
/// `Destructuring`.
pub fn Named::pattern(self : Named) -> Pattern {
  cast_last(self.node)
}

///|
/// The key: `"spacy key"`.
pub fn Keyed::key(self : Keyed) -> Expr {
  cast_first(self.node)
}

///|
/// The right-hand side of the pair: `true`.
///
/// This should only be accessed if this `Keyed` is contained in a
/// `DictItem`.
pub fn Keyed::expr(self : Keyed) -> Expr {
  cast_last(self.node)
}

///|
/// The spread expression.
///
/// This should only be accessed if this `Spread` is contained in an
/// `ArrayItem`, `DictItem`, or `Arg`.
pub fn Spread::expr(self : Spread) -> Expr {
  cast_first(self.node)
}

///|
/// The sink identifier, if present.
///
/// This should only be accessed if this `Spread` is contained in a
/// `Param` or binding `DestructuringItem`.
pub fn Spread::sink_ident(self : Spread) -> Ident? {
  try_cast_first(self.node)
}

///|
/// The sink expressions, if present.
///
/// This should only be accessed if this `Spread` is contained in a
/// `DestructuringItem`.
pub fn Spread::sink_expr(self : Spread) -> Expr? {
  try_cast_first(self.node)
}

///|
pub using @syntax {type UnOp, type BinOp, type Assoc}

///|
/// The operator: `-`.
pub fn Unary::op(self : Unary) -> UnOp {
  for node in self.node.children() {
    if UnOp::from_kind(node.kind()) is Some(op) {
      return op
    }
  }
  Pos
}

///|
/// The expression to operate on: `x`.
pub fn Unary::expr(self : Unary) -> Expr {
  cast_last(self.node)
}

///|
/// The binary operator: `+`.
pub fn Binary::op(self : Binary) -> BinOp {
  let mut not = false
  for node in self.node.children() {
    match node.kind() {
      Not => not = true
      In if not => return NotIn
      kind => if BinOp::from_kind(kind) is Some(op) { return op }
    }
  }
  Add
}

///|
/// The left-hand side of the operation: `a`.
pub fn Binary::lhs(self : Binary) -> Expr {
  cast_first(self.node)
}

///|
/// The right-hand side of the operation: `b`.
pub fn Binary::rhs(self : Binary) -> Expr {
  cast_last(self.node)
}

///|
/// The expression to access the field on.
pub fn FieldAccess::target(self : FieldAccess) -> Expr {
  cast_first(self.node)
}

///|
/// The name of the field.
pub fn FieldAccess::field(self : FieldAccess) -> Ident {
  cast_last(self.node)
}

///|
/// The function to call.
pub fn FuncCall::callee(self : FuncCall) -> Expr {
  cast_first(self.node)
}

///|
/// The arguments to the function.
pub fn FuncCall::args(self : FuncCall) -> Args {
  cast_last(self.node)
}

///|
/// The positional and named arguments.
pub fn Args::items(self : Args) -> Iter[Arg] {
  cast_children(self.node)
}

///|
/// Whether there is a comma at the end.
pub fn Args::trailing_comma(self : Args) -> Bool {
  let children = self.node.children()
  for i = children.length() - 2; i >= 0; i = i - 1 {
    let kind = children[i].kind()
    if !kind.is_trivia() {
      return kind is Comma
    }
  }
  false
}

///|
/// An argument to a function call.
pub(all) enum Arg {
  /// A positional argument: `12`.
  Pos(Expr)
  /// A named argument: `draw: false`.
  Named(Named)
  /// A spread argument: `..things`.
  Spread(Spread)
}

///|
pub impl AstNode for Arg with fn from_untyped(node) {
  match node.kind() {
    Named => Some(Arg::Named(Named::{ node, }))
    Spread => Some(Arg::Spread(Spread::{ node, }))
    _ => Expr::from_untyped(node).map(v => Arg::Pos(v))
  }
}

///|
pub impl AstNode for Arg with fn to_untyped(self) {
  match self {
    Pos(v) => v.to_untyped()
    Named(v) => v.node
    Spread(v) => v.node
  }
}

///|
pub impl AstNode for Arg with fn placeholder() {
  Arg::Pos(Expr::placeholder())
}

///|
pub extend Arg with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// The name of the closure.
///
/// This only exists if you use the function syntax sugar: `let f(x) = y`.
pub fn Closure::name(self : Closure) -> Ident? {
  match self.node.children().get(0) {
    Some(first) => Ident::from_untyped(first)
    None => None
  }
}

///|
/// The parameter bindings.
pub fn Closure::params(self : Closure) -> Params {
  cast_first(self.node)
}

///|
/// The body of the closure.
pub fn Closure::body(self : Closure) -> Expr {
  cast_last(self.node)
}

///|
/// The parameter bindings.
pub fn Params::children(self : Params) -> Iter[Param] {
  cast_children(self.node)
}

///|
/// A parameter to a closure.
pub(all) enum Param {
  /// A positional parameter: `x`.
  Pos(Pattern)
  /// A named parameter with a default value: `draw: false`.
  Named(Named)
  /// An argument sink: `..args` or `..`.
  Spread(Spread)
}

///|
pub impl AstNode for Param with fn from_untyped(node) {
  match node.kind() {
    Named => Some(Param::Named(Named::{ node, }))
    Spread => Some(Param::Spread(Spread::{ node, }))
    _ => Pattern::from_untyped(node).map(v => Param::Pos(v))
  }
}

///|
pub impl AstNode for Param with fn to_untyped(self) {
  match self {
    Pos(v) => v.to_untyped()
    Named(v) => v.node
    Spread(v) => v.node
  }
}

///|
pub impl AstNode for Param with fn placeholder() {
  Param::Pos(Pattern::placeholder())
}

///|
pub extend Param with AstNode::{from_untyped, to_untyped, span, placeholder}
