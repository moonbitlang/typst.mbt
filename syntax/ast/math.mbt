// Math nodes.

///|
/// The contained math.
pub fn Equation::body(self : Equation) -> Math {
  cast_first(self.node)
}

///|
/// Whether the equation should be displayed as a separate block.
pub fn Equation::block(self : Equation) -> Bool {
  let children = self.node.children()
  let is_space = (i : Int) => {
    i >= 0 &&
    i < children.length() &&
    children[i].kind() is (SpaceNoNewline | SpaceWithNewline)
  }
  is_space(1) && is_space(children.length() - 2)
}

///|
/// The expressions the mathematical content consists of.
pub fn Math::exprs(self : Math) -> Iter[Expr] {
  self.node.children().iter().filter_map(Expr::cast_with_space)
}

///|
/// Whether this `Math` node was originally parenthesized.
pub fn Math::was_deparenthesized(self : Math) -> Bool {
  let children = self.node.children()
  children.length() >= 2 &&
  children[0].kind() is LeftParen &&
  children[children.length() - 1].kind() is RightParen
}

///|
/// The underlying text kind.
pub(all) enum MathTextKind {
  Grapheme(String)
  Number(String)
}

///|
/// Return the underlying text.
pub fn MathText::get(self : MathText) -> MathTextKind {
  let text = self.node.leaf_text()
  if @unicode.is_numeric(text.get_char(0).unwrap_or('\u{0}')) {
    // Numbers are potentially grouped as multiple characters. This is
    // done in `Lexer::math_text()`.
    Number(text)
  } else {
    Grapheme(text)
  }
}

///|
/// Get the identifier.
pub fn MathIdent::get(self : MathIdent) -> String {
  self.node.leaf_text()
}

///|
/// Get the identifier as a string slice.
pub fn MathIdent::as_str(self : MathIdent) -> String {
  self.get()
}

///|
/// The expression to access the field on.
pub fn MathFieldAccess::target(self : MathFieldAccess) -> MathAccess {
  cast_first(self.node)
}

///|
/// The name of the field.
pub fn MathFieldAccess::field(self : MathFieldAccess) -> MathIdent {
  cast_last(self.node)
}

///|
/// A variable or field access in math.
pub(all) enum MathAccess {
  MathIdent(MathIdent)
  MathFieldAccess(MathFieldAccess)
}

///|
pub impl AstNode for MathAccess with fn from_untyped(node) {
  match node.kind() {
    MathIdent => Some(MathAccess::MathIdent(MathIdent::{ node, }))
    MathFieldAccess =>
      Some(MathAccess::MathFieldAccess(MathFieldAccess::{ node, }))
    _ => None
  }
}

///|
pub impl AstNode for MathAccess with fn to_untyped(self) {
  match self {
    MathIdent(v) => v.node
    MathFieldAccess(v) => v.node
  }
}

///|
pub impl AstNode for MathAccess with fn placeholder() {
  MathAccess::MathIdent(MathIdent::placeholder())
}

///|
pub extend MathAccess with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A list of all shorthands in math mode.
pub let math_shorthand_list : ReadOnlyArray[(String, Char)] = [
  ("...", '…'),
  ("-", '−'),
  ("*", '∗'),
  ("~", '∼'),
  ("!=", '≠'),
  (":=", '≔'),
  ("::=", '⩴'),
  ("=:", '≕'),
  ("<<", '≪'),
  ("<<<", '⋘'),
  (">>", '≫'),
  (">>>", '⋙'),
  ("<=", '≤'),
  (">=", '≥'),
  ("->", '→'),
  ("-->", '⟶'),
  ("|->", '↦'),
  (">->", '↣'),
  ("->>", '↠'),
  ("<-", '←'),
  ("<--", '⟵'),
  ("<-<", '↢'),
  ("<<-", '↞'),
  ("<->", '↔'),
  ("<-->", '⟷'),
  ("~>", '⇝'),
  ("~~>", '⟿'),
  ("<~", '⇜'),
  ("<~~", '⬳'),
  ("=>", '⇒'),
  ("|=>", '⤇'),
  ("==>", '⟹'),
  ("<==", '⟸'),
  ("<=>", '⇔'),
  ("<==>", '⟺'),
  ("[|", '⟦'),
  ("|]", '⟧'),
  ("||", '‖'),
]

///|
/// Get the shorthanded character.
pub fn MathShorthand::get(self : MathShorthand) -> Char {
  lookup_shorthand(math_shorthand_list, self.node.leaf_text())
}

///|
/// The function to call. If not actually a function, will be rendered as
/// content next to its arguments.
pub fn MathCall::callee(self : MathCall) -> MathAccess {
  cast_first(self.node)
}

///|
/// The arguments to the function.
pub fn MathCall::args(self : MathCall) -> MathArgs {
  cast_last(self.node)
}

///|
/// An argument in a [`MathCall`] for an actual function and whether it ends
/// in a semicolon.
pub(all) struct MathArg {
  /// The argument.
  arg : Arg
  /// Whether the argument ends with a semicolon and should create
  /// two-dimensional args. This excludes semicolons that end embedded code
  /// expressions.
  ends_in_semicolon : Bool
}

///|
/// Items at the top-level of a [`MathCall`] argument list that will be
/// rendered into content if unparsing for a non-function.
///
/// This enum does not implement [`AstNode`] because the `Semicolon` variant
/// requires extra context to convert correctly making it a likely footgun.
pub(all) enum MathArgItem {
  /// A normal argument.
  Arg(Arg)
  /// A space between arguments and other punctuation.
  Space(Space)
  /// A comma separating arguments.
  Comma(Char, @syntax.SyntaxNode)
  /// A semicolon separating arguments. This excludes semicolons that end
  /// embedded code expressions.
  Semicolon(Char, @syntax.SyntaxNode)
  /// The left paren at the start of the arguments.
  LeftParen(Char, @syntax.SyntaxNode)
  /// The right paren at the end of the arguments.
  RightParen(Char, @syntax.SyntaxNode)
}

///|
/// Arguments for actual function calls in math.
pub fn MathArgs::arg_items(self : MathArgs) -> Iter[MathArg] {
  let items = self.content_items().to_array()
  let out = []
  let mut i = 0
  while i < items.length() {
    guard items[i] is Arg(arg) else {
      i += 1
      continue
    }
    i += 1
    // `self.content_items()` handles code-ending semicolons for us :)
    let mut ends_in_semicolon = false
    while i < items.length() {
      match items[i] {
        Arg(_) => break
        Semicolon(_, _) => {
          ends_in_semicolon = true
          break
        }
        _ => i += 1
      }
    }
    out.push({ arg, ends_in_semicolon, })
  }
  out.iter()
}

///|
/// Items at the top-level of the argument list that will be rendered into
/// content if unparsing for a non-function.
pub fn MathArgs::content_items(self : MathArgs) -> Iter[MathArgItem] {
  let out = []
  let mut prev_hash = false
  for node in self.node.children() {
    if Arg::from_untyped(node) is Some(arg) {
      out.push(MathArgItem::Arg(arg))
      continue
    }
    let semicolon_ends_code = prev_hash
    prev_hash = false
    let item = match node.kind() {
      SpaceNoNewline | SpaceWithNewline => MathArgItem::Space(Space::{ node, })
      Comma => MathArgItem::Comma(',', node)
      LeftParen => MathArgItem::LeftParen('(', node)
      RightParen => MathArgItem::RightParen(')', node)
      Semicolon if !semicolon_ends_code => MathArgItem::Semicolon(';', node)
      Hash => {
        prev_hash = true
        continue
      }
      _ => continue
    }
    out.push(item)
  }
  out.iter()
}

///|
/// The opening delimiter.
pub fn MathDelimited::open(self : MathDelimited) -> Expr {
  cast_first(self.node)
}

///|
/// The contents, including the delimiters.
pub fn MathDelimited::body(self : MathDelimited) -> Math {
  cast_first(self.node)
}

///|
/// The closing delimiter.
pub fn MathDelimited::close(self : MathDelimited) -> Expr {
  cast_last(self.node)
}

///|
/// The base, to which things are attached.
pub fn MathAttach::base(self : MathAttach) -> Expr {
  cast_first(self.node)
}

///|
/// The bottom attachment.
pub fn MathAttach::bottom(self : MathAttach) -> Expr? {
  find_after(self.node, Underscore)
}

///|
/// The top attachment.
pub fn MathAttach::top(self : MathAttach) -> Expr? {
  find_after(self.node, Hat)
}

///|
/// Extract attached primes if present.
pub fn MathAttach::primes(self : MathAttach) -> MathPrimes? {
  let children = self.node.children()
  for i, child in children {
    if (Expr::from_untyped(child) : Expr?) is Some(_) {
      return match children.get(i + 1) {
        Some(next) => MathPrimes::from_untyped(next)
        None => None
      }
    }
  }
  None
}

///|
/// The number of grouped primes.
pub fn MathPrimes::count(self : MathPrimes) -> Int {
  // We can use byte length since single quotes are one byte.
  @syntax.utf8_len(self.node.leaf_text())
}

///|
/// The numerator.
pub fn MathFrac::num(self : MathFrac) -> Expr {
  cast_first(self.node)
}

///|
/// The denominator.
pub fn MathFrac::denom(self : MathFrac) -> Expr {
  cast_last(self.node)
}

///|
/// The index of the root.
pub fn MathRoot::index(self : MathRoot) -> Byte? {
  match self.node.children().get(0) {
    Some(node) =>
      match node.leaf_text() {
        "∜" => Some(4)
        "∛" => Some(3)
        "√" => None
        _ => None
      }
    None => None
  }
}

///|
/// The radicand.
pub fn MathRoot::radicand(self : MathRoot) -> Expr {
  cast_first(self.node)
}

///|
/// Skip the children up to the first one of the given kind, then find the
/// first child (from there on, inclusive) that casts to `T`.
///
/// Upstream: `children().skip_while(|n| n.kind() != kind).find_map(cast)`.
fn[T : AstNode] find_after(
  node : @syntax.SyntaxNode,
  kind : @syntax.SyntaxKind,
) -> T? {
  let mut found = false
  for child in node.children() {
    if !found && child.kind() != kind {
      continue
    }
    found = true
    if T::from_untyped(child) is Some(v) {
      return Some(v)
    }
  }
  None
}
