///|
/// An expression in markup, math or code.
pub(all) enum Expr {
  /// Plain text without markup.
  Text(Text)
  /// Whitespace in markup or math. Has at most one newline in markup, as more
  /// indicate a paragraph break.
  Space(Space)
  /// A forced line break: `\`.
  Linebreak(Linebreak)
  /// A paragraph break, indicated by contiguous whitespace containing at
  /// least two newlines. Only produced in Markup.
  Parbreak(Parbreak)
  /// An escape sequence: `\#`, `\u{1F5FA}`.
  Escape(Escape)
  /// A shorthand for a unicode codepoint. For example, `~` for non-breaking
  /// space or `-?` for a soft hyphen.
  Shorthand(Shorthand)
  /// A smart quote: `'` or `"`.
  SmartQuote(SmartQuote)
  /// Strong content: `*Strong*`.
  Strong(Strong)
  /// Emphasized content: `_Emphasized_`.
  Emph(Emph)
  /// Raw text with optional syntax highlighting: `` `...` ``.
  Raw(Raw)
  /// A hyperlink: `https://typst.org`.
  Link(Link)
  /// A label: `<intro>`.
  Label(Label)
  /// A reference: `@target`, `@target[..]`.
  Ref(Ref)
  /// A section heading: `= Introduction`.
  Heading(Heading)
  /// An item in a bullet list: `- ...`.
  ListItem(ListItem)
  /// An item in an enumeration (numbered list): `+ ...` or `1. ...`.
  EnumItem(EnumItem)
  /// An item in a term list: `/ Term: Details`.
  TermItem(TermItem)
  /// A mathematical equation: `$x$`, `$ x^2 $`.
  Equation(Equation)
  /// The contents of a mathematical equation: `x^2 + 1`.
  Math(Math)
  /// A lone text fragment in math: `x`, `25`, `3.1415`, `=`, `[`.
  MathText(MathText)
  /// An identifier in math: `pi`.
  MathIdent(MathIdent)
  /// A field access in math: `arrow.r.long.double.bar`.
  MathFieldAccess(MathFieldAccess)
  /// A shorthand for a unicode codepoint in math: `a <= b`.
  MathShorthand(MathShorthand)
  /// An alignment point in math: `&`.
  MathAlignPoint(MathAlignPoint)
  /// A function call in math: `mat(delim: "[", a, b; ..#($c$,), d)`
  MathCall(MathCall)
  /// Matched delimiters in math: `[x + y]`.
  MathDelimited(MathDelimited)
  /// A base with optional attachments in math: `a_1^2`.
  MathAttach(MathAttach)
  /// Grouped primes in math: `a'''`.
  MathPrimes(MathPrimes)
  /// A fraction in math: `x/2`.
  MathFrac(MathFrac)
  /// A root in math: `√x`, `∛x` or `∜x`.
  MathRoot(MathRoot)
  /// An identifier: `left`.
  Ident(Ident)
  /// The `none` literal.
  None(None)
  /// The `auto` literal.
  Auto(Auto)
  /// A boolean: `true`, `false`.
  Bool(BoolLit)
  /// An integer: `120`.
  Int(IntLit)
  /// A floating-point number: `1.2`, `10e-4`.
  Float(FloatLit)
  /// A numeric value with a unit: `12pt`, `3cm`, `2em`, `90deg`, `50%`.
  Numeric(Numeric)
  /// A quoted string: `"..."`.
  Str(Str)
  /// A code block: `{ let x = 1; x + 2 }`.
  CodeBlock(CodeBlock)
  /// A content block: `[*Hi* there!]`.
  ContentBlock(ContentBlock)
  /// A grouped expression: `(1 + 2)`.
  Parenthesized(Parenthesized)
  /// An array: `(1, "hi", 12cm)`.
  Array(ArrayLit)
  /// A dictionary: `(thickness: 3pt, dash: "solid")`.
  Dict(Dict)
  /// A unary operation: `-x`.
  Unary(Unary)
  /// A binary operation: `a + b`.
  Binary(Binary)
  /// A field access: `properties.age`.
  FieldAccess(FieldAccess)
  /// An invocation of a function or method: `f(x, y)`.
  FuncCall(FuncCall)
  /// A closure: `(x, y) => z`.
  Closure(Closure)
  /// A let binding: `let x = 1`.
  LetBinding(LetBinding)
  /// A destructuring assignment: `(x, y) = (1, 2)`.
  DestructAssignment(DestructAssignment)
  /// A set rule: `set text(...)`.
  SetRule(SetRule)
  /// A show rule: `show heading: it => emph(it.body)`.
  ShowRule(ShowRule)
  /// A contextual expression: `context text.lang`.
  Contextual(Contextual)
  /// An if-else conditional: `if x { y } else { z }`.
  Conditional(Conditional)
  /// A while loop: `while x { y }`.
  WhileLoop(WhileLoop)
  /// A for loop: `for x in y { z }`.
  ForLoop(ForLoop)
  /// A module import: `import "utils.typ": a, b, c`.
  ModuleImport(ModuleImport)
  /// A module include: `include "chapter1.typ"`.
  ModuleInclude(ModuleInclude)
  /// A break from a loop: `break`.
  LoopBreak(LoopBreak)
  /// A continue in a loop: `continue`.
  LoopContinue(LoopContinue)
  /// A return from a function: `return`, `return x + 1`.
  FuncReturn(FuncReturn)
}

///|
pub impl AstNode for Expr with fn from_untyped(node) {
  match node.kind() {
    // Spaces are skipped unless using `cast_with_space`.
    Text => Some(Expr::Text(Text::{ node, }))
    Linebreak => Some(Expr::Linebreak(Linebreak::{ node, }))
    Parbreak => Some(Expr::Parbreak(Parbreak::{ node, }))
    Escape => Some(Expr::Escape(Escape::{ node, }))
    Shorthand => Some(Expr::Shorthand(Shorthand::{ node, }))
    SmartQuote => Some(Expr::SmartQuote(SmartQuote::{ node, }))
    Strong => Some(Expr::Strong(Strong::{ node, }))
    Emph => Some(Expr::Emph(Emph::{ node, }))
    Raw => Some(Expr::Raw(Raw::{ node, }))
    Link => Some(Expr::Link(Link::{ node, }))
    Label => Some(Expr::Label(Label::{ node, }))
    Ref => Some(Expr::Ref(Ref::{ node, }))
    Heading => Some(Expr::Heading(Heading::{ node, }))
    ListItem => Some(Expr::ListItem(ListItem::{ node, }))
    EnumItem => Some(Expr::EnumItem(EnumItem::{ node, }))
    TermItem => Some(Expr::TermItem(TermItem::{ node, }))
    Equation => Some(Expr::Equation(Equation::{ node, }))
    Math => Some(Expr::Math(Math::{ node, }))
    MathText => Some(Expr::MathText(MathText::{ node, }))
    MathIdent => Some(Expr::MathIdent(MathIdent::{ node, }))
    MathFieldAccess => Some(Expr::MathFieldAccess(MathFieldAccess::{ node, }))
    MathShorthand => Some(Expr::MathShorthand(MathShorthand::{ node, }))
    MathAlignPoint => Some(Expr::MathAlignPoint(MathAlignPoint::{ node, }))
    MathCall => Some(Expr::MathCall(MathCall::{ node, }))
    MathDelimited => Some(Expr::MathDelimited(MathDelimited::{ node, }))
    MathAttach => Some(Expr::MathAttach(MathAttach::{ node, }))
    MathPrimes => Some(Expr::MathPrimes(MathPrimes::{ node, }))
    MathFrac => Some(Expr::MathFrac(MathFrac::{ node, }))
    MathRoot => Some(Expr::MathRoot(MathRoot::{ node, }))
    Ident => Some(Expr::Ident(Ident::{ node, }))
    None => Some(Expr::None(None::{ node, }))
    Auto => Some(Expr::Auto(Auto::{ node, }))
    Bool => Some(Expr::Bool(BoolLit::{ node, }))
    Int => Some(Expr::Int(IntLit::{ node, }))
    Float => Some(Expr::Float(FloatLit::{ node, }))
    Numeric => Some(Expr::Numeric(Numeric::{ node, }))
    Str => Some(Expr::Str(Str::{ node, }))
    CodeBlock => Some(Expr::CodeBlock(CodeBlock::{ node, }))
    ContentBlock => Some(Expr::ContentBlock(ContentBlock::{ node, }))
    Parenthesized => Some(Expr::Parenthesized(Parenthesized::{ node, }))
    Array => Some(Expr::Array(ArrayLit::{ node, }))
    Dict => Some(Expr::Dict(Dict::{ node, }))
    Unary => Some(Expr::Unary(Unary::{ node, }))
    Binary => Some(Expr::Binary(Binary::{ node, }))
    FieldAccess => Some(Expr::FieldAccess(FieldAccess::{ node, }))
    FuncCall => Some(Expr::FuncCall(FuncCall::{ node, }))
    Closure => Some(Expr::Closure(Closure::{ node, }))
    LetBinding => Some(Expr::LetBinding(LetBinding::{ node, }))
    DestructAssignment =>
      Some(Expr::DestructAssignment(DestructAssignment::{ node, }))
    SetRule => Some(Expr::SetRule(SetRule::{ node, }))
    ShowRule => Some(Expr::ShowRule(ShowRule::{ node, }))
    Contextual => Some(Expr::Contextual(Contextual::{ node, }))
    Conditional => Some(Expr::Conditional(Conditional::{ node, }))
    WhileLoop => Some(Expr::WhileLoop(WhileLoop::{ node, }))
    ForLoop => Some(Expr::ForLoop(ForLoop::{ node, }))
    ModuleImport => Some(Expr::ModuleImport(ModuleImport::{ node, }))
    ModuleInclude => Some(Expr::ModuleInclude(ModuleInclude::{ node, }))
    LoopBreak => Some(Expr::LoopBreak(LoopBreak::{ node, }))
    LoopContinue => Some(Expr::LoopContinue(LoopContinue::{ node, }))
    FuncReturn => Some(Expr::FuncReturn(FuncReturn::{ node, }))
    _ => None
  }
}

///|
pub impl AstNode for Expr with fn to_untyped(self) {
  match self {
    Text(v) => v.node
    Space(v) => v.node
    Linebreak(v) => v.node
    Parbreak(v) => v.node
    Escape(v) => v.node
    Shorthand(v) => v.node
    SmartQuote(v) => v.node
    Strong(v) => v.node
    Emph(v) => v.node
    Raw(v) => v.node
    Link(v) => v.node
    Label(v) => v.node
    Ref(v) => v.node
    Heading(v) => v.node
    ListItem(v) => v.node
    EnumItem(v) => v.node
    TermItem(v) => v.node
    Equation(v) => v.node
    Math(v) => v.node
    MathText(v) => v.node
    MathIdent(v) => v.node
    MathFieldAccess(v) => v.node
    MathShorthand(v) => v.node
    MathAlignPoint(v) => v.node
    MathCall(v) => v.node
    MathDelimited(v) => v.node
    MathAttach(v) => v.node
    MathPrimes(v) => v.node
    MathFrac(v) => v.node
    MathRoot(v) => v.node
    Ident(v) => v.node
    None(v) => v.node
    Auto(v) => v.node
    Bool(v) => v.node
    Int(v) => v.node
    Float(v) => v.node
    Numeric(v) => v.node
    Str(v) => v.node
    CodeBlock(v) => v.node
    ContentBlock(v) => v.node
    Parenthesized(v) => v.node
    Array(v) => v.node
    Dict(v) => v.node
    Unary(v) => v.node
    Binary(v) => v.node
    FieldAccess(v) => v.node
    FuncCall(v) => v.node
    Closure(v) => v.node
    LetBinding(v) => v.node
    DestructAssignment(v) => v.node
    SetRule(v) => v.node
    ShowRule(v) => v.node
    Contextual(v) => v.node
    Conditional(v) => v.node
    WhileLoop(v) => v.node
    ForLoop(v) => v.node
    ModuleImport(v) => v.node
    ModuleInclude(v) => v.node
    LoopBreak(v) => v.node
    LoopContinue(v) => v.node
    FuncReturn(v) => v.node
  }
}

///|
pub impl AstNode for Expr with fn placeholder() {
  Expr::None(None::placeholder())
}

///|
pub extend Expr with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
fn Expr::cast_with_space(node : @syntax.SyntaxNode) -> Expr? {
  match node.kind() {
    SpaceNoNewline | SpaceWithNewline => Some(Expr::Space(Space::{ node, }))
    _ => Expr::from_untyped(node)
  }
}

///|
/// Can this expression be embedded into markup with a hash?
pub fn Expr::hash(self : Expr) -> Bool {
  self
  is (Ident(_)
  | None(_)
  | Auto(_)
  | Bool(_)
  | Int(_)
  | Float(_)
  | Numeric(_)
  | Str(_)
  | CodeBlock(_)
  | ContentBlock(_)
  | Array(_)
  | Dict(_)
  | Parenthesized(_)
  | FieldAccess(_)
  | FuncCall(_)
  | LetBinding(_)
  | SetRule(_)
  | ShowRule(_)
  | Contextual(_)
  | Conditional(_)
  | WhileLoop(_)
  | ForLoop(_)
  | ModuleImport(_)
  | ModuleInclude(_)
  | LoopBreak(_)
  | LoopContinue(_)
  | FuncReturn(_))
}

///|
/// Is this a literal?
pub fn Expr::is_literal(self : Expr) -> Bool {
  self
  is (None(_) | Auto(_) | Bool(_) | Int(_) | Float(_) | Numeric(_) | Str(_))
}
