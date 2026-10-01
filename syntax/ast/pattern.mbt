// Patterns, destructuring and bindings.

///|
/// The kind of a pattern.
pub(all) enum Pattern {
  /// A single expression: `x`.
  Normal(Expr)
  /// A placeholder: `_`.
  Placeholder(Underscore)
  /// A parenthesized pattern.
  Parenthesized(Parenthesized)
  /// A destructuring pattern: `(x, _, ..y)`.
  Destructuring(Destructuring)
}

///|
pub impl AstNode for Pattern with fn from_untyped(node) {
  match node.kind() {
    Underscore => Some(Pattern::Placeholder(Underscore::{ node, }))
    Parenthesized => Some(Pattern::Parenthesized(Parenthesized::{ node, }))
    Destructuring => Some(Pattern::Destructuring(Destructuring::{ node, }))
    _ => Expr::from_untyped(node).map(v => Pattern::Normal(v))
  }
}

///|
pub impl AstNode for Pattern with fn to_untyped(self) {
  match self {
    Normal(v) => v.to_untyped()
    Placeholder(v) => v.node
    Parenthesized(v) => v.node
    Destructuring(v) => v.node
  }
}

///|
pub impl AstNode for Pattern with fn placeholder() {
  Pattern::Normal(Expr::placeholder())
}

///|
pub extend Pattern with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// Returns a list of all new bindings introduced by the pattern.
pub fn Pattern::bindings(self : Pattern) -> Array[Ident] {
  match self {
    Normal(Ident(ident)) => [ident]
    Parenthesized(v) => v.pattern().bindings()
    Destructuring(v) => v.bindings()
    _ => []
  }
}

///|
/// The items of the destructuring.
pub fn Destructuring::items(self : Destructuring) -> Iter[DestructuringItem] {
  cast_children(self.node)
}

///|
/// Returns a list of all new bindings introduced by the destructuring.
pub fn Destructuring::bindings(self : Destructuring) -> Array[Ident] {
  let out = []
  for binding in self.items() {
    match binding {
      Pattern(pattern) => out.append(pattern.bindings())
      Named(named) => out.append(named.pattern().bindings())
      Spread(spread) =>
        if spread.sink_ident() is Some(ident) {
          out.push(ident)
        }
    }
  }
  out
}

///|
/// The kind of an element in a destructuring pattern.
pub(all) enum DestructuringItem {
  /// A sub-pattern: `x`.
  Pattern(Pattern)
  /// A renamed destructuring: `x: y`.
  Named(Named)
  /// A destructuring sink: `..y` or `..`.
  Spread(Spread)
}

///|
pub impl AstNode for DestructuringItem with fn from_untyped(node) {
  match node.kind() {
    Named => Some(DestructuringItem::Named(Named::{ node, }))
    Spread => Some(DestructuringItem::Spread(Spread::{ node, }))
    _ => Pattern::from_untyped(node).map(v => DestructuringItem::Pattern(v))
  }
}

///|
pub impl AstNode for DestructuringItem with fn to_untyped(self) {
  match self {
    Pattern(v) => v.to_untyped()
    Named(v) => v.node
    Spread(v) => v.node
  }
}

///|
pub impl AstNode for DestructuringItem with fn placeholder() {
  DestructuringItem::Pattern(Pattern::placeholder())
}

///|
pub extend DestructuringItem with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// The kind of a let binding, either a normal one or a closure.
pub(all) enum LetBindingKind {
  /// A normal binding: `let x = 1`.
  Normal(Pattern)
  /// A closure binding: `let f(x) = 1`.
  Closure(Ident)
}

///|
/// Returns a list of all new bindings introduced by the let binding.
pub fn LetBindingKind::bindings(self : LetBindingKind) -> Array[Ident] {
  match self {
    Normal(pattern) => pattern.bindings()
    Closure(ident) => [ident]
  }
}

///|
/// The kind of the let binding.
pub fn LetBinding::kind(self : LetBinding) -> LetBindingKind {
  match (cast_first(self.node) : Pattern) {
    Normal(Closure(closure)) =>
      Closure(closure.name().unwrap_or_else(Ident::placeholder))
    pattern => Normal(pattern)
  }
}

///|
/// The expression the binding is initialized with.
pub fn LetBinding::init(self : LetBinding) -> Expr? {
  match self.kind() {
    Normal(Normal(_) | Parenthesized(_)) =>
      (cast_children(self.node) : Iter[Expr]).nth(1)
    Normal(_) => try_cast_first(self.node)
    Closure(_) => try_cast_first(self.node)
  }
}

///|
/// The pattern of the assignment.
pub fn DestructAssignment::pattern(self : DestructAssignment) -> Pattern {
  cast_first(self.node)
}

///|
/// The expression that is assigned.
pub fn DestructAssignment::value(self : DestructAssignment) -> Expr {
  cast_last(self.node)
}
