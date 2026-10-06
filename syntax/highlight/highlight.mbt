// Port of `typst-syntax/src/highlight.rs`.
//
// This is a separate package (upstream it lives in `typst-syntax` itself)
// because it needs the typed AST of `syntax/ast`, which depends on `syntax`.

///|
/// A syntax highlighting tag.
pub(all) enum Tag {
  /// A line or block comment.
  Comment
  /// Punctuation in code.
  Punctuation
  /// An escape sequence or shorthand.
  Escape
  /// Strong markup.
  Strong
  /// Emphasized markup.
  Emph
  /// A hyperlink.
  Link
  /// Raw text.
  Raw
  /// A label.
  Label
  /// A reference to a label.
  Ref
  /// A section heading.
  Heading
  /// A marker of a list, enumeration, or term list.
  ListMarker
  /// A term in a term list.
  ListTerm
  /// The delimiters of an equation.
  MathDelimiter
  /// An operator with special meaning in an equation.
  MathOperator
  /// Parentheses used for grouping in an equation.
  MathGroupingParens
  /// A keyword.
  Keyword
  /// An operator in code.
  Operator
  /// A numeric literal.
  Number
  /// A string literal.
  String
  /// A function or method name.
  Function
  /// An interpolated variable in markup or math.
  Interpolated
  /// A syntax error.
  Error
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Tag with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Tag with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Tag with @debug.Debug::{to_repr}

///|
/// The list of all tags, in the same order as they are defined.
pub let tag_list : ReadOnlyArray[Tag] = [
  Comment,
  Punctuation,
  Escape,
  Strong,
  Emph,
  Link,
  Raw,
  Label,
  Ref,
  Heading,
  ListMarker,
  ListTerm,
  MathDelimiter,
  MathOperator,
  MathGroupingParens,
  Keyword,
  Operator,
  Number,
  String,
  Function,
  Interpolated,
  Error,
]

///|
/// Return the recommended TextMate grammar scope for the given highlighting
/// tag.
pub fn Tag::tm_scope(self : Tag) -> String {
  match self {
    Comment => "comment.typst"
    Punctuation => "punctuation.typst"
    Escape => "constant.character.escape.typst"
    Strong => "markup.bold.typst"
    Emph => "markup.italic.typst"
    Link => "markup.underline.link.typst"
    Raw => "markup.raw.typst"
    MathDelimiter => "punctuation.definition.math.typst"
    MathOperator => "keyword.operator.math.typst"
    MathGroupingParens => "punctuation.math.typst"
    Heading => "markup.heading.typst"
    ListMarker => "punctuation.definition.list.typst"
    ListTerm => "markup.list.term.typst"
    Label => "entity.name.label.typst"
    Ref => "markup.other.reference.typst"
    Keyword => "keyword.typst"
    Operator => "keyword.operator.typst"
    Number => "constant.numeric.typst"
    String => "string.quoted.double.typst"
    Function => "entity.name.function.typst"
    Interpolated => "meta.interpolation.typst"
    Error => "invalid.typst"
  }
}

///|
/// The recommended CSS class for the highlighting tag.
pub fn Tag::css_class(self : Tag) -> String {
  match self {
    Comment => "typ-comment"
    Punctuation => "typ-punct"
    Escape => "typ-escape"
    Strong => "typ-strong"
    Emph => "typ-emph"
    Link => "typ-link"
    Raw => "typ-raw"
    Label => "typ-label"
    Ref => "typ-ref"
    Heading => "typ-heading"
    ListMarker => "typ-marker"
    ListTerm => "typ-term"
    MathDelimiter => "typ-math-delim"
    MathOperator => "typ-math-op"
    MathGroupingParens => "typ-math-group"
    Keyword => "typ-key"
    Operator => "typ-op"
    Number => "typ-num"
    String => "typ-str"
    Function => "typ-func"
    Interpolated => "typ-pol"
    Error => "typ-error"
  }
}

///|
/// Determine the highlight tag of a linked syntax node.
///
/// Returns `None` if the node should not be highlighted.
pub fn highlight(node : @syntax.LinkedNode) -> Tag? {
  let parent_kind = node.parent_kind()
  match node.kind() {
    Markup if parent_kind == Some(TermItem) &&
      node.next_sibling_kind() == Some(Colon) => Some(ListTerm)
    Markup => None
    Text => None
    SpaceNoNewline => None
    SpaceWithNewline => None
    Linebreak => Some(Escape)
    Parbreak => None
    Escape => Some(Escape)
    Shorthand => Some(Escape)
    SmartQuote => None
    Strong => Some(Strong)
    Emph => Some(Emph)
    Raw => Some(Raw)
    RawLang => None
    RawTrimmed => None
    RawDelim => None
    Link => Some(Link)
    Label => Some(Label)
    Ref => Some(Ref)
    RefMarker => None
    Heading => Some(Heading)
    HeadingMarker => None
    ListItem => None
    ListMarker => Some(ListMarker)
    EnumItem => None
    EnumMarker => Some(ListMarker)
    TermItem => None
    TermMarker => Some(ListMarker)
    Equation => None
    Math => None
    MathText => None
    MathIdent => highlight_ident(node)
    MathFieldAccess => None
    MathShorthand => Some(Escape)
    MathAlignPoint => Some(MathOperator)
    MathCall => None
    MathArgs => None
    MathDelimited => None
    MathAttach => None
    MathFrac => None
    MathRoot => None
    MathPrimes => Some(MathOperator)
    Hash => highlight_hash(node)
    LeftBrace => Some(Punctuation)
    RightBrace => Some(Punctuation)
    LeftBracket => Some(Punctuation)
    RightBracket => Some(Punctuation)
    LeftParen =>
      match parent_kind {
        Some(Math) => Some(MathGroupingParens)
        _ => Some(Punctuation)
      }
    RightParen =>
      match parent_kind {
        Some(Math) => Some(MathGroupingParens)
        _ => Some(Punctuation)
      }
    Comma => Some(Punctuation)
    Semicolon => Some(Punctuation)
    Colon => Some(Punctuation)
    Star =>
      match parent_kind {
        Some(Strong) => None
        _ => Some(Operator)
      }
    Underscore =>
      match parent_kind {
        Some(MathAttach) => Some(MathOperator)
        _ => None
      }
    Dollar => Some(MathDelimiter)
    Plus => Some(Operator)
    Minus => Some(Operator)
    Slash =>
      Some(
        match parent_kind {
          Some(MathFrac) => MathOperator
          _ => Operator
        },
      )
    Hat => Some(MathOperator)
    Dot => Some(Punctuation)
    Eq =>
      match parent_kind {
        Some(Heading) => None
        _ => Some(Operator)
      }
    EqEq => Some(Operator)
    ExclEq => Some(Operator)
    Lt => Some(Operator)
    LtEq => Some(Operator)
    Gt => Some(Operator)
    GtEq => Some(Operator)
    PlusEq => Some(Operator)
    HyphEq => Some(Operator)
    StarEq => Some(Operator)
    SlashEq => Some(Operator)
    Dots => Some(Operator)
    Arrow => Some(Operator)
    Root => Some(MathOperator)
    Bang => None
    Not => Some(Keyword)
    And => Some(Keyword)
    Or => Some(Keyword)
    @syntax.SyntaxKind::None => Some(Keyword)
    Auto => Some(Keyword)
    Let => Some(Keyword)
    Set => Some(Keyword)
    Show => Some(Keyword)
    Context => Some(Keyword)
    If => Some(Keyword)
    Else => Some(Keyword)
    For => Some(Keyword)
    In => Some(Keyword)
    While => Some(Keyword)
    Break => Some(Keyword)
    Continue => Some(Keyword)
    Return => Some(Keyword)
    Import => Some(Keyword)
    Include => Some(Keyword)
    As => Some(Keyword)
    Code => None
    Ident => highlight_ident(node)
    Bool => Some(Keyword)
    Int => Some(Number)
    Float => Some(Number)
    Numeric => Some(Number)
    Str => Some(String)
    CodeBlock => None
    ContentBlock => None
    Parenthesized => None
    Array => None
    Dict => None
    Named => None
    Keyed => None
    Unary => None
    Binary => None
    FieldAccess => None
    FuncCall => None
    Args => None
    Spread => None
    Closure => None
    Params => None
    LetBinding => None
    SetRule => None
    ShowRule => None
    Contextual => None
    Conditional => None
    WhileLoop => None
    ForLoop => None
    ModuleImport => None
    ImportItems => None
    ImportItemPath => None
    RenamedImportItem => None
    ModuleInclude => None
    LoopBreak => None
    LoopContinue => None
    FuncReturn => None
    Destructuring => None
    DestructAssignment => None
    Shebang => Some(Comment)
    LineComment => Some(Comment)
    BlockComment => Some(Comment)
    Error => Some(Error)
    End => None
  }
}

///|
/// Highlight an identifier based on context.
fn highlight_ident(node : @syntax.LinkedNode) -> Tag? {
  // Are we directly before an argument list?
  let next_leaf = node.next_leaf()
  if next_leaf is Some(next) &&
    node.range().1 == next.offset() &&
    (
    // Either at a paren, followed by arguments...
      (
        next.kind() == LeftParen &&
        next.parent_kind() is Some(Args | MathArgs | Params)
      ) ||
      (
      // ...or at a bracket, followed by content
        next.kind() == LeftBracket && next.parent_kind() == Some(ContentBlock)
      )
    ) {
    return Some(Function)
  }

  // Are we in math?
  if node.kind() is (MathIdent | MathFieldAccess) {
    return Some(Interpolated)
  }

  // Find the first non-field access ancestor.
  let mut ancestor = node
  while ancestor.parent_kind() == Some(FieldAccess) {
    guard ancestor.parent() is Some(parent) else { return None }
    ancestor = parent
  }

  // Are we directly before or behind a show rule colon?
  if ancestor.parent_kind() == Some(ShowRule) &&
    (
      next_leaf.map(leaf => leaf.kind()) == Some(Colon) ||
      node.prev_leaf().map(leaf => leaf.kind()) == Some(Colon)
    ) {
    return Some(Function)
  }

  // Are we (or an ancestor field access) directly after a hash.
  if ancestor.prev_leaf().map(leaf => leaf.kind()) == Some(Hash) {
    return Some(Interpolated)
  }

  // Are we behind a dot, that is behind another identifier?
  guard node.prev_leaf() is Some(prev) else { return None }
  if prev.kind() == Dot {
    guard prev.prev_leaf() is Some(prev_prev) else { return None }
    if is_ident(prev_prev) {
      return highlight_ident(prev_prev)
    }
  }
  None
}

///|
/// Highlight a hash based on context.
fn highlight_hash(node : @syntax.LinkedNode) -> Tag? {
  guard node.next_sibling() is Some(next) else { return None }
  guard (@ast.Expr::from_untyped(next.get()) : @ast.Expr?) is Some(expr) else {
    return None
  }
  if !expr.hash() {
    return None
  }
  guard next.leftmost_leaf() is Some(leaf) else { return None }
  highlight(leaf)
}

///|
/// Whether the node is one of the two identifier nodes.
fn is_ident(node : @syntax.LinkedNode) -> Bool {
  node.kind() is (Ident | MathIdent)
}

///|
/// Highlight a node to an HTML `code` element.
///
/// This uses these [CSS classes for categories](Tag::css_class).
pub fn highlight_html(root : @syntax.SyntaxNode) -> String {
  let buf = StringBuilder()
  buf.write_string("<code>")
  let node = @syntax.LinkedNode::new(root)
  highlight_html_impl(buf, node)
  buf.write_string("</code>")
  buf.to_string()
}

///|
/// Highlight one source node, emitting HTML.
fn highlight_html_impl(html : StringBuilder, node : @syntax.LinkedNode) -> Unit {
  let mut span = false
  if highlight(node) is Some(tag) && tag != Error {
    span = true
    html.write_string("<span class=\"")
    html.write_string(tag.css_class())
    html.write_string("\">")
  }
  let text = node.get().leaf_text()
  if !text.is_empty() {
    for c in text {
      match c {
        '<' => html.write_string("&lt;")
        '>' => html.write_string("&gt;")
        '&' => html.write_string("&amp;")
        '\'' => html.write_string("&#39;")
        '"' => html.write_string("&quot;")
        _ => html.write_char(c)
      }
    }
  } else {
    for child in node.children() {
      highlight_html_impl(html, child)
    }
  }
  if span {
    html.write_string("</span>")
  }
}
