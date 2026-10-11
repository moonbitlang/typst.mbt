// The `node!` structs of upstream `ast.rs`: typed wrappers around a
// [@syntax.SyntaxNode] whose kind matches the struct name.

///|
/// A line comment: `// ...`.
pub struct LineComment {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for LineComment with fn from_untyped(node) {
  if node.kind() is LineComment {
    Some(LineComment::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for LineComment with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for LineComment with fn placeholder() {
  LineComment::{ node: @syntax.SyntaxNode::placeholder(LineComment), }
}

///|
pub extend LineComment with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A block comment: `/* ... */`.
pub struct BlockComment {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for BlockComment with fn from_untyped(node) {
  if node.kind() is BlockComment {
    Some(BlockComment::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for BlockComment with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for BlockComment with fn placeholder() {
  BlockComment::{ node: @syntax.SyntaxNode::placeholder(BlockComment), }
}

///|
pub extend BlockComment with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// The syntactical root capable of representing a full parsed document.
pub struct Markup {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Markup with fn from_untyped(node) {
  if node.kind() is Markup {
    Some(Markup::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Markup with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Markup with fn placeholder() {
  Markup::{ node: @syntax.SyntaxNode::placeholder(Markup), }
}

///|
pub extend Markup with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// Plain text without markup.
pub struct Text {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Text with fn from_untyped(node) {
  if node.kind() is Text {
    Some(Text::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Text with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Text with fn placeholder() {
  Text::{ node: @syntax.SyntaxNode::placeholder(Text), }
}

///|
pub extend Text with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A forced line break: `\`.
pub struct Linebreak {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Linebreak with fn from_untyped(node) {
  if node.kind() is Linebreak {
    Some(Linebreak::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Linebreak with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Linebreak with fn placeholder() {
  Linebreak::{ node: @syntax.SyntaxNode::placeholder(Linebreak), }
}

///|
pub extend Linebreak with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A paragraph break, indicated by contiguous whitespace containing at
/// least two newlines. Only produced in Markup.
pub struct Parbreak {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Parbreak with fn from_untyped(node) {
  if node.kind() is Parbreak {
    Some(Parbreak::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Parbreak with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Parbreak with fn placeholder() {
  Parbreak::{ node: @syntax.SyntaxNode::placeholder(Parbreak), }
}

///|
pub extend Parbreak with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// An escape sequence: `\#`, `\u{1F5FA}`.
pub struct Escape {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Escape with fn from_untyped(node) {
  if node.kind() is Escape {
    Some(Escape::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Escape with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Escape with fn placeholder() {
  Escape::{ node: @syntax.SyntaxNode::placeholder(Escape), }
}

///|
pub extend Escape with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A shorthand for a unicode codepoint. For example, `~` for a non-breaking
/// space or `-?` for a soft hyphen.
pub struct Shorthand {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Shorthand with fn from_untyped(node) {
  if node.kind() is Shorthand {
    Some(Shorthand::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Shorthand with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Shorthand with fn placeholder() {
  Shorthand::{ node: @syntax.SyntaxNode::placeholder(Shorthand), }
}

///|
pub extend Shorthand with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A smart quote: `'` or `"`.
pub struct SmartQuote {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for SmartQuote with fn from_untyped(node) {
  if node.kind() is SmartQuote {
    Some(SmartQuote::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for SmartQuote with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for SmartQuote with fn placeholder() {
  SmartQuote::{ node: @syntax.SyntaxNode::placeholder(SmartQuote), }
}

///|
pub extend SmartQuote with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// Strong content: `*Strong*`.
pub struct Strong {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Strong with fn from_untyped(node) {
  if node.kind() is Strong {
    Some(Strong::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Strong with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Strong with fn placeholder() {
  Strong::{ node: @syntax.SyntaxNode::placeholder(Strong), }
}

///|
pub extend Strong with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// Emphasized content: `_Emphasized_`.
pub struct Emph {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Emph with fn from_untyped(node) {
  if node.kind() is Emph {
    Some(Emph::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Emph with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Emph with fn placeholder() {
  Emph::{ node: @syntax.SyntaxNode::placeholder(Emph), }
}

///|
pub extend Emph with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// Raw text with optional syntax highlighting: `` `...` ``.
pub struct Raw {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Raw with fn from_untyped(node) {
  if node.kind() is Raw {
    Some(Raw::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Raw with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Raw with fn placeholder() {
  Raw::{ node: @syntax.SyntaxNode::placeholder(Raw), }
}

///|
pub extend Raw with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A language tag at the start of raw element: ``typ ``.
pub struct RawLang {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for RawLang with fn from_untyped(node) {
  if node.kind() is RawLang {
    Some(RawLang::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for RawLang with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for RawLang with fn placeholder() {
  RawLang::{ node: @syntax.SyntaxNode::placeholder(RawLang), }
}

///|
pub extend RawLang with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A raw delimiter in single or 3+ backticks: `` ` ``.
pub struct RawDelim {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for RawDelim with fn from_untyped(node) {
  if node.kind() is RawDelim {
    Some(RawDelim::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for RawDelim with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for RawDelim with fn placeholder() {
  RawDelim::{ node: @syntax.SyntaxNode::placeholder(RawDelim), }
}

///|
pub extend RawDelim with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A hyperlink: `https://typst.org`.
pub struct Link {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Link with fn from_untyped(node) {
  if node.kind() is Link {
    Some(Link::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Link with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Link with fn placeholder() {
  Link::{ node: @syntax.SyntaxNode::placeholder(Link), }
}

///|
pub extend Link with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A label: `<intro>`.
pub struct Label {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Label with fn from_untyped(node) {
  if node.kind() is Label {
    Some(Label::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Label with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Label with fn placeholder() {
  Label::{ node: @syntax.SyntaxNode::placeholder(Label), }
}

///|
pub extend Label with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A reference: `@target`, `@target[..]`.
pub struct Ref {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Ref with fn from_untyped(node) {
  if node.kind() is Ref {
    Some(Ref::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Ref with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Ref with fn placeholder() {
  Ref::{ node: @syntax.SyntaxNode::placeholder(Ref), }
}

///|
pub extend Ref with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A section heading: `= Introduction`.
pub struct Heading {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Heading with fn from_untyped(node) {
  if node.kind() is Heading {
    Some(Heading::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Heading with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Heading with fn placeholder() {
  Heading::{ node: @syntax.SyntaxNode::placeholder(Heading), }
}

///|
pub extend Heading with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// An item in a bullet list: `- ...`.
pub struct ListItem {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for ListItem with fn from_untyped(node) {
  if node.kind() is ListItem {
    Some(ListItem::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for ListItem with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for ListItem with fn placeholder() {
  ListItem::{ node: @syntax.SyntaxNode::placeholder(ListItem), }
}

///|
pub extend ListItem with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// An item in an enumeration (numbered list): `+ ...` or `1. ...`.
pub struct EnumItem {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for EnumItem with fn from_untyped(node) {
  if node.kind() is EnumItem {
    Some(EnumItem::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for EnumItem with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for EnumItem with fn placeholder() {
  EnumItem::{ node: @syntax.SyntaxNode::placeholder(EnumItem), }
}

///|
pub extend EnumItem with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// An item in a term list: `/ Term: Details`.
pub struct TermItem {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for TermItem with fn from_untyped(node) {
  if node.kind() is TermItem {
    Some(TermItem::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for TermItem with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for TermItem with fn placeholder() {
  TermItem::{ node: @syntax.SyntaxNode::placeholder(TermItem), }
}

///|
pub extend TermItem with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A mathematical equation: `$x$`, `$ x^2 $`.
pub struct Equation {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Equation with fn from_untyped(node) {
  if node.kind() is Equation {
    Some(Equation::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Equation with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Equation with fn placeholder() {
  Equation::{ node: @syntax.SyntaxNode::placeholder(Equation), }
}

///|
pub extend Equation with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// The contents of a mathematical equation: `x^2 + 1`.
pub struct Math {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Math with fn from_untyped(node) {
  if node.kind() is Math {
    Some(Math::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Math with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Math with fn placeholder() {
  Math::{ node: @syntax.SyntaxNode::placeholder(Math), }
}

///|
pub extend Math with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A lone text fragment in math: `x`, `25`, `3.1415`, `=`, `[`.
pub struct MathText {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathText with fn from_untyped(node) {
  if node.kind() is MathText {
    Some(MathText::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathText with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathText with fn placeholder() {
  MathText::{ node: @syntax.SyntaxNode::placeholder(MathText), }
}

///|
pub extend MathText with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// An identifier in math: `pi`.
pub struct MathIdent {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathIdent with fn from_untyped(node) {
  if node.kind() is MathIdent {
    Some(MathIdent::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathIdent with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathIdent with fn placeholder() {
  MathIdent::{ node: @syntax.SyntaxNode::placeholder(MathIdent), }
}

///|
pub extend MathIdent with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A field access in math: `arrow.r.long.double.bar`.
pub struct MathFieldAccess {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathFieldAccess with fn from_untyped(node) {
  if node.kind() is MathFieldAccess {
    Some(MathFieldAccess::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathFieldAccess with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathFieldAccess with fn placeholder() {
  MathFieldAccess::{ node: @syntax.SyntaxNode::placeholder(MathFieldAccess), }
}

///|
pub extend MathFieldAccess with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A shorthand for a unicode codepoint in math: `a <= b`.
pub struct MathShorthand {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathShorthand with fn from_untyped(node) {
  if node.kind() is MathShorthand {
    Some(MathShorthand::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathShorthand with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathShorthand with fn placeholder() {
  MathShorthand::{ node: @syntax.SyntaxNode::placeholder(MathShorthand), }
}

///|
pub extend MathShorthand with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A function call in math: `mat(delim: "[", a, b; ..#($c$,), d)`.
pub struct MathCall {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathCall with fn from_untyped(node) {
  if node.kind() is MathCall {
    Some(MathCall::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathCall with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathCall with fn placeholder() {
  MathCall::{ node: @syntax.SyntaxNode::placeholder(MathCall), }
}

///|
pub extend MathCall with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// Function arguments in math: `(delim: "[", a, b; ..#($c$,), d)`.
pub struct MathArgs {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathArgs with fn from_untyped(node) {
  if node.kind() is MathArgs {
    Some(MathArgs::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathArgs with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathArgs with fn placeholder() {
  MathArgs::{ node: @syntax.SyntaxNode::placeholder(MathArgs), }
}

///|
pub extend MathArgs with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// An alignment point in math: `&`.
pub struct MathAlignPoint {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathAlignPoint with fn from_untyped(node) {
  if node.kind() is MathAlignPoint {
    Some(MathAlignPoint::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathAlignPoint with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathAlignPoint with fn placeholder() {
  MathAlignPoint::{ node: @syntax.SyntaxNode::placeholder(MathAlignPoint), }
}

///|
pub extend MathAlignPoint with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// Matched delimiters in math: `[x + y]`.
pub struct MathDelimited {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathDelimited with fn from_untyped(node) {
  if node.kind() is MathDelimited {
    Some(MathDelimited::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathDelimited with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathDelimited with fn placeholder() {
  MathDelimited::{ node: @syntax.SyntaxNode::placeholder(MathDelimited), }
}

///|
pub extend MathDelimited with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A base with optional attachments in math: `a_1^2`.
pub struct MathAttach {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathAttach with fn from_untyped(node) {
  if node.kind() is MathAttach {
    Some(MathAttach::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathAttach with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathAttach with fn placeholder() {
  MathAttach::{ node: @syntax.SyntaxNode::placeholder(MathAttach), }
}

///|
pub extend MathAttach with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// Grouped primes in math: `a'''`.
pub struct MathPrimes {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathPrimes with fn from_untyped(node) {
  if node.kind() is MathPrimes {
    Some(MathPrimes::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathPrimes with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathPrimes with fn placeholder() {
  MathPrimes::{ node: @syntax.SyntaxNode::placeholder(MathPrimes), }
}

///|
pub extend MathPrimes with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A fraction in math: `x/2`
pub struct MathFrac {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathFrac with fn from_untyped(node) {
  if node.kind() is MathFrac {
    Some(MathFrac::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathFrac with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathFrac with fn placeholder() {
  MathFrac::{ node: @syntax.SyntaxNode::placeholder(MathFrac), }
}

///|
pub extend MathFrac with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A root in math: `√x`, `∛x` or `∜x`.
pub struct MathRoot {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for MathRoot with fn from_untyped(node) {
  if node.kind() is MathRoot {
    Some(MathRoot::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for MathRoot with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for MathRoot with fn placeholder() {
  MathRoot::{ node: @syntax.SyntaxNode::placeholder(MathRoot), }
}

///|
pub extend MathRoot with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// An identifier: `it`.
pub struct Ident {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Ident with fn from_untyped(node) {
  if node.kind() is Ident {
    Some(Ident::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Ident with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Ident with fn placeholder() {
  Ident::{ node: @syntax.SyntaxNode::placeholder(Ident), }
}

///|
pub extend Ident with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// The `none` literal.
pub struct None {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for None with fn from_untyped(node) {
  if node.kind() is None {
    Some(None::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for None with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for None with fn placeholder() {
  None::{ node: @syntax.SyntaxNode::placeholder(None), }
}

///|
pub extend None with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// The `auto` literal.
pub struct Auto {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Auto with fn from_untyped(node) {
  if node.kind() is Auto {
    Some(Auto::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Auto with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Auto with fn placeholder() {
  Auto::{ node: @syntax.SyntaxNode::placeholder(Auto), }
}

///|
pub extend Auto with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A boolean: `true`, `false`.
///
/// Upstream: `Bool` (renamed, see the package notes in `ast.mbt`).
pub struct BoolLit {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for BoolLit with fn from_untyped(node) {
  if node.kind() is Bool {
    Some(BoolLit::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for BoolLit with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for BoolLit with fn placeholder() {
  BoolLit::{ node: @syntax.SyntaxNode::placeholder(Bool), }
}

///|
pub extend BoolLit with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// An integer: `120`.
///
/// Upstream: `Int` (renamed, see the package notes in `ast.mbt`).
pub struct IntLit {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for IntLit with fn from_untyped(node) {
  if node.kind() is Int {
    Some(IntLit::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for IntLit with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for IntLit with fn placeholder() {
  IntLit::{ node: @syntax.SyntaxNode::placeholder(Int), }
}

///|
pub extend IntLit with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A floating-point number: `1.2`, `10e-4`.
pub struct FloatLit {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for FloatLit with fn from_untyped(node) {
  if node.kind() is Float {
    Some(FloatLit::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for FloatLit with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for FloatLit with fn placeholder() {
  FloatLit::{ node: @syntax.SyntaxNode::placeholder(Float), }
}

///|
pub extend FloatLit with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A numeric value with a unit: `12pt`, `3cm`, `2em`, `90deg`, `50%`.
pub struct Numeric {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Numeric with fn from_untyped(node) {
  if node.kind() is Numeric {
    Some(Numeric::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Numeric with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Numeric with fn placeholder() {
  Numeric::{ node: @syntax.SyntaxNode::placeholder(Numeric), }
}

///|
pub extend Numeric with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A quoted string: `"..."`.
pub struct Str {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Str with fn from_untyped(node) {
  if node.kind() is Str {
    Some(Str::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Str with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Str with fn placeholder() {
  Str::{ node: @syntax.SyntaxNode::placeholder(Str), }
}

///|
pub extend Str with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A code block: `{ let x = 1; x + 2 }`.
pub struct CodeBlock {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for CodeBlock with fn from_untyped(node) {
  if node.kind() is CodeBlock {
    Some(CodeBlock::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for CodeBlock with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for CodeBlock with fn placeholder() {
  CodeBlock::{ node: @syntax.SyntaxNode::placeholder(CodeBlock), }
}

///|
pub extend CodeBlock with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// The body of a code block.
pub struct Code {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Code with fn from_untyped(node) {
  if node.kind() is Code {
    Some(Code::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Code with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Code with fn placeholder() {
  Code::{ node: @syntax.SyntaxNode::placeholder(Code), }
}

///|
pub extend Code with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A content block: `[*Hi* there!]`.
pub struct ContentBlock {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for ContentBlock with fn from_untyped(node) {
  if node.kind() is ContentBlock {
    Some(ContentBlock::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for ContentBlock with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for ContentBlock with fn placeholder() {
  ContentBlock::{ node: @syntax.SyntaxNode::placeholder(ContentBlock), }
}

///|
pub extend ContentBlock with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A grouped expression: `(1 + 2)`.
pub struct Parenthesized {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Parenthesized with fn from_untyped(node) {
  if node.kind() is Parenthesized {
    Some(Parenthesized::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Parenthesized with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Parenthesized with fn placeholder() {
  Parenthesized::{ node: @syntax.SyntaxNode::placeholder(Parenthesized), }
}

///|
pub extend Parenthesized with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// An array: `(1, "hi", 12cm)`.
///
/// Upstream: `Array` (renamed, see the package notes in `ast.mbt`).
pub struct ArrayLit {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for ArrayLit with fn from_untyped(node) {
  if node.kind() is Array {
    Some(ArrayLit::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for ArrayLit with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for ArrayLit with fn placeholder() {
  ArrayLit::{ node: @syntax.SyntaxNode::placeholder(Array), }
}

///|
pub extend ArrayLit with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A dictionary: `(thickness: 3pt, dash: "solid")`.
pub struct Dict {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Dict with fn from_untyped(node) {
  if node.kind() is Dict {
    Some(Dict::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Dict with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Dict with fn placeholder() {
  Dict::{ node: @syntax.SyntaxNode::placeholder(Dict), }
}

///|
pub extend Dict with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A named pair: `thickness: 3pt`.
pub struct Named {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Named with fn from_untyped(node) {
  if node.kind() is Named {
    Some(Named::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Named with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Named with fn placeholder() {
  Named::{ node: @syntax.SyntaxNode::placeholder(Named), }
}

///|
pub extend Named with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A keyed pair: `"spacy key": true`.
pub struct Keyed {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Keyed with fn from_untyped(node) {
  if node.kind() is Keyed {
    Some(Keyed::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Keyed with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Keyed with fn placeholder() {
  Keyed::{ node: @syntax.SyntaxNode::placeholder(Keyed), }
}

///|
pub extend Keyed with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A spread: `..x` or `..x.at(0)`.
pub struct Spread {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Spread with fn from_untyped(node) {
  if node.kind() is Spread {
    Some(Spread::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Spread with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Spread with fn placeholder() {
  Spread::{ node: @syntax.SyntaxNode::placeholder(Spread), }
}

///|
pub extend Spread with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A unary operation: `-x`.
pub struct Unary {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Unary with fn from_untyped(node) {
  if node.kind() is Unary {
    Some(Unary::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Unary with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Unary with fn placeholder() {
  Unary::{ node: @syntax.SyntaxNode::placeholder(Unary), }
}

///|
pub extend Unary with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A binary operation: `a + b`.
pub struct Binary {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Binary with fn from_untyped(node) {
  if node.kind() is Binary {
    Some(Binary::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Binary with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Binary with fn placeholder() {
  Binary::{ node: @syntax.SyntaxNode::placeholder(Binary), }
}

///|
pub extend Binary with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A field access: `properties.age`.
pub struct FieldAccess {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for FieldAccess with fn from_untyped(node) {
  if node.kind() is FieldAccess {
    Some(FieldAccess::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for FieldAccess with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for FieldAccess with fn placeholder() {
  FieldAccess::{ node: @syntax.SyntaxNode::placeholder(FieldAccess), }
}

///|
pub extend FieldAccess with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// An invocation of a function or method: `f(x, y)`.
pub struct FuncCall {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for FuncCall with fn from_untyped(node) {
  if node.kind() is FuncCall {
    Some(FuncCall::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for FuncCall with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for FuncCall with fn placeholder() {
  FuncCall::{ node: @syntax.SyntaxNode::placeholder(FuncCall), }
}

///|
pub extend FuncCall with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A function call's argument list: `(12pt, y)`.
pub struct Args {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Args with fn from_untyped(node) {
  if node.kind() is Args {
    Some(Args::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Args with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Args with fn placeholder() {
  Args::{ node: @syntax.SyntaxNode::placeholder(Args), }
}

///|
pub extend Args with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A closure: `(x, y) => z`.
pub struct Closure {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Closure with fn from_untyped(node) {
  if node.kind() is Closure {
    Some(Closure::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Closure with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Closure with fn placeholder() {
  Closure::{ node: @syntax.SyntaxNode::placeholder(Closure), }
}

///|
pub extend Closure with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A closure's parameters: `(x, y)`.
pub struct Params {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Params with fn from_untyped(node) {
  if node.kind() is Params {
    Some(Params::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Params with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Params with fn placeholder() {
  Params::{ node: @syntax.SyntaxNode::placeholder(Params), }
}

///|
pub extend Params with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// An underscore: `_`
pub struct Underscore {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Underscore with fn from_untyped(node) {
  if node.kind() is Underscore {
    Some(Underscore::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Underscore with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Underscore with fn placeholder() {
  Underscore::{ node: @syntax.SyntaxNode::placeholder(Underscore), }
}

///|
pub extend Underscore with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A destructuring pattern: `x` or `(x, _, ..y)`.
pub struct Destructuring {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Destructuring with fn from_untyped(node) {
  if node.kind() is Destructuring {
    Some(Destructuring::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Destructuring with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Destructuring with fn placeholder() {
  Destructuring::{ node: @syntax.SyntaxNode::placeholder(Destructuring), }
}

///|
pub extend Destructuring with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A let binding: `let x = 1`.
pub struct LetBinding {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for LetBinding with fn from_untyped(node) {
  if node.kind() is LetBinding {
    Some(LetBinding::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for LetBinding with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for LetBinding with fn placeholder() {
  LetBinding::{ node: @syntax.SyntaxNode::placeholder(LetBinding), }
}

///|
pub extend LetBinding with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// An assignment expression `(x, y) = (1, 2)`.
pub struct DestructAssignment {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for DestructAssignment with fn from_untyped(node) {
  if node.kind() is DestructAssignment {
    Some(DestructAssignment::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for DestructAssignment with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for DestructAssignment with fn placeholder() {
  DestructAssignment::{
    node: @syntax.SyntaxNode::placeholder(DestructAssignment),
  }
}

///|
pub extend DestructAssignment with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A set rule: `set text(...)`.
pub struct SetRule {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for SetRule with fn from_untyped(node) {
  if node.kind() is SetRule {
    Some(SetRule::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for SetRule with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for SetRule with fn placeholder() {
  SetRule::{ node: @syntax.SyntaxNode::placeholder(SetRule), }
}

///|
pub extend SetRule with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A show rule: `show heading: it => emph(it.body)`.
pub struct ShowRule {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for ShowRule with fn from_untyped(node) {
  if node.kind() is ShowRule {
    Some(ShowRule::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for ShowRule with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for ShowRule with fn placeholder() {
  ShowRule::{ node: @syntax.SyntaxNode::placeholder(ShowRule), }
}

///|
pub extend ShowRule with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A contextual expression: `context text.lang`.
pub struct Contextual {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Contextual with fn from_untyped(node) {
  if node.kind() is Contextual {
    Some(Contextual::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Contextual with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Contextual with fn placeholder() {
  Contextual::{ node: @syntax.SyntaxNode::placeholder(Contextual), }
}

///|
pub extend Contextual with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// An if-else conditional: `if x { y } else { z }`.
pub struct Conditional {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for Conditional with fn from_untyped(node) {
  if node.kind() is Conditional {
    Some(Conditional::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for Conditional with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Conditional with fn placeholder() {
  Conditional::{ node: @syntax.SyntaxNode::placeholder(Conditional), }
}

///|
pub extend Conditional with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A while loop: `while x { y }`.
pub struct WhileLoop {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for WhileLoop with fn from_untyped(node) {
  if node.kind() is WhileLoop {
    Some(WhileLoop::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for WhileLoop with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for WhileLoop with fn placeholder() {
  WhileLoop::{ node: @syntax.SyntaxNode::placeholder(WhileLoop), }
}

///|
pub extend WhileLoop with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A for loop: `for x in y { z }`.
pub struct ForLoop {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for ForLoop with fn from_untyped(node) {
  if node.kind() is ForLoop {
    Some(ForLoop::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for ForLoop with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for ForLoop with fn placeholder() {
  ForLoop::{ node: @syntax.SyntaxNode::placeholder(ForLoop), }
}

///|
pub extend ForLoop with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A module import: `import "utils.typ": a, b, c`.
pub struct ModuleImport {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for ModuleImport with fn from_untyped(node) {
  if node.kind() is ModuleImport {
    Some(ModuleImport::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for ModuleImport with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for ModuleImport with fn placeholder() {
  ModuleImport::{ node: @syntax.SyntaxNode::placeholder(ModuleImport), }
}

///|
pub extend ModuleImport with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// Items to import from a module: `a, b, c`.
pub struct ImportItems {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for ImportItems with fn from_untyped(node) {
  if node.kind() is ImportItems {
    Some(ImportItems::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for ImportItems with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for ImportItems with fn placeholder() {
  ImportItems::{ node: @syntax.SyntaxNode::placeholder(ImportItems), }
}

///|
pub extend ImportItems with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A path to a submodule's imported name: `a.b.c`.
pub struct ImportItemPath {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for ImportItemPath with fn from_untyped(node) {
  if node.kind() is ImportItemPath {
    Some(ImportItemPath::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for ImportItemPath with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for ImportItemPath with fn placeholder() {
  ImportItemPath::{ node: @syntax.SyntaxNode::placeholder(ImportItemPath), }
}

///|
pub extend ImportItemPath with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A renamed import item: `a as d`
pub struct RenamedImportItem {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for RenamedImportItem with fn from_untyped(node) {
  if node.kind() is RenamedImportItem {
    Some(RenamedImportItem::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for RenamedImportItem with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for RenamedImportItem with fn placeholder() {
  RenamedImportItem::{
    node: @syntax.SyntaxNode::placeholder(RenamedImportItem),
  }
}

///|
pub extend RenamedImportItem with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A module include: `include "chapter1.typ"`.
pub struct ModuleInclude {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for ModuleInclude with fn from_untyped(node) {
  if node.kind() is ModuleInclude {
    Some(ModuleInclude::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for ModuleInclude with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for ModuleInclude with fn placeholder() {
  ModuleInclude::{ node: @syntax.SyntaxNode::placeholder(ModuleInclude), }
}

///|
pub extend ModuleInclude with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A break from a loop: `break`.
pub struct LoopBreak {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for LoopBreak with fn from_untyped(node) {
  if node.kind() is LoopBreak {
    Some(LoopBreak::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for LoopBreak with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for LoopBreak with fn placeholder() {
  LoopBreak::{ node: @syntax.SyntaxNode::placeholder(LoopBreak), }
}

///|
pub extend LoopBreak with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// A continue in a loop: `continue`.
pub struct LoopContinue {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for LoopContinue with fn from_untyped(node) {
  if node.kind() is LoopContinue {
    Some(LoopContinue::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for LoopContinue with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for LoopContinue with fn placeholder() {
  LoopContinue::{ node: @syntax.SyntaxNode::placeholder(LoopContinue), }
}

///|
pub extend LoopContinue with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}

///|
/// A return from a function: `return`, `return x + 1`.
pub struct FuncReturn {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
pub impl AstNode for FuncReturn with fn from_untyped(node) {
  if node.kind() is FuncReturn {
    Some(FuncReturn::{ node, })
  } else {
    None
  }
}

///|
pub impl AstNode for FuncReturn with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for FuncReturn with fn placeholder() {
  FuncReturn::{ node: @syntax.SyntaxNode::placeholder(FuncReturn), }
}

///|
pub extend FuncReturn with AstNode::{
  from_untyped,
  to_untyped,
  span,
  placeholder,
}
