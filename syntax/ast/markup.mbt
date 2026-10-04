// Markup nodes: comments, text, spaces, escapes, strong/emph, raw, links,
// labels, references, headings and list items.

///|
/// The contents of the line comment.
pub fn LineComment::text(self : LineComment) -> String {
  let text = self.node.leaf_text()
  if text.has_prefix("//") {
    text.unsafe_substring(start=2, end=text.length())
  } else {
    text
  }
}

///|
/// The contents of the block comment.
pub fn BlockComment::text(self : BlockComment) -> String {
  let text = self.node.leaf_text()
  if text.has_prefix("/*") {
    let rest = text.unsafe_substring(start=2, end=text.length())
    if rest.has_suffix("*/") {
      return rest.unsafe_substring(start=0, end=rest.length() - 2)
    }
  }
  text
}

///|
/// The expressions.
pub fn Markup::exprs(self : Markup) -> Iter[Expr] {
  let out = []
  let mut was_stmt = false
  for node in self.node.children() {
    // Ignore newline directly after statements without semicolons.
    let kind = node.kind()
    let is_space = kind is (SpaceNoNewline | SpaceWithNewline)
    let keep = !was_stmt || !is_space
    was_stmt = kind.is_stmt()
    if keep && Expr::cast_with_space(node) is Some(expr) {
      out.push(expr)
    }
  }
  out.iter()
}

///|
/// Get the text.
pub fn Text::get(self : Text) -> String {
  self.node.leaf_text()
}

///|
/// Whitespace in markup or math. Has at most one newline in markup, as more
/// indicate a paragraph break.
pub struct Space {
  /// The underlying syntax node.
  node : @syntax.SyntaxNode
}

///|
/// Whether the Space contains a newline.
pub fn Space::had_newline(self : Space) -> Bool {
  self.node.kind() is SpaceWithNewline
}

///|
pub impl AstNode for Space with fn from_untyped(node) {
  match node.kind() {
    SpaceNoNewline | SpaceWithNewline => Some(Space::{ node, })
    _ => None
  }
}

///|
pub impl AstNode for Space with fn to_untyped(self) {
  self.node
}

///|
pub impl AstNode for Space with fn placeholder() {
  Space::{ node: @syntax.SyntaxNode::placeholder(SpaceNoNewline), }
}

///|
pub extend Space with AstNode::{from_untyped, to_untyped, span, placeholder}

///|
/// Get the escaped character.
pub fn Escape::get(self : Escape) -> Char {
  let text = self.node.leaf_text()
  // Upstream `expect`s the backslash (and would panic without it).
  let mut i = if text.has_prefix("\\") { 1 } else { 0 }
  let rest = text.unsafe_substring(start=i, end=text.length())
  if rest.has_prefix("u{") {
    i += 2
    let start = i
    while i < text.length() && is_ascii_hexdigit(text.code_unit_at(i).to_int()) {
      i += 1
    }
    @syntax.parse_codepoint(text.unsafe_substring(start~, end=i)).unwrap_or(
      '\u{0}',
    )
  } else {
    rest.get_char(0).unwrap_or('\u{0}')
  }
}

///|
fn is_ascii_hexdigit(c : Int) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
/// A list of all shorthands in markup mode.
pub let shorthand_list : ReadOnlyArray[(String, Char)] = [
  ("...", '…'),
  ("~", '\u{00A0}'),
  ("-", '\u{2212}'), // Only before a digit
  ("--", '\u{2013}'),
  ("---", '\u{2014}'),
  ("-?", '\u{00AD}'),
]

///|
/// Get the shorthanded character.
pub fn Shorthand::get(self : Shorthand) -> Char {
  lookup_shorthand(shorthand_list, self.node.leaf_text())
}

///|
fn lookup_shorthand(
  list : ReadOnlyArray[(String, Char)],
  text : String,
) -> Char {
  for entry in list[:] {
    if entry.0 == text {
      return entry.1
    }
  }
  '\u{0}'
}

///|
/// Whether this is a double quote.
pub fn SmartQuote::double(self : SmartQuote) -> Bool {
  self.node.leaf_text() == "\""
}

///|
/// The contents of the strong node.
pub fn Strong::body(self : Strong) -> Markup {
  cast_first(self.node)
}

///|
/// The contents of the emphasis node.
pub fn Emph::body(self : Emph) -> Markup {
  cast_first(self.node)
}

///|
/// The lines in the raw block.
pub fn Raw::lines(self : Raw) -> Iter[Text] {
  cast_children(self.node)
}

///|
/// An optional identifier specifying the language to syntax-highlight in.
pub fn Raw::lang(self : Raw) -> RawLang? {
  // Only blocky literals are supposed to contain a language.
  guard (try_cast_first(self.node) : RawDelim?) is Some(delim) else {
    return None
  }
  if delim.node.len() < 3 {
    return None
  }
  try_cast_first(self.node)
}

///|
/// Whether the raw text should be displayed in a separate block.
pub fn Raw::block(self : Raw) -> Bool {
  (try_cast_first(self.node) : RawDelim?) is Some(delim) &&
  delim.node.len() >= 3 &&
  self.node
  .children()
  .iter()
  .any(e => {
    e.kind() is RawTrimmed &&
    e.leaf_text().iter().any(c => @syntax.is_newline(c))
  })
}

///|
/// Get the language tag.
pub fn RawLang::get(self : RawLang) -> String {
  self.node.leaf_text()
}

///|
/// Get the URL.
pub fn Link::get(self : Link) -> String {
  self.node.leaf_text()
}

///|
/// Get the label's text.
pub fn Label::get(self : Label) -> String {
  self.node.leaf_text().trim_start(chars="<").trim_end(chars=">").to_owned()
}

///|
/// Get the target.
///
/// Will not be empty.
pub fn Ref::target(self : Ref) -> String {
  for node in self.node.children() {
    if node.kind() is RefMarker {
      return node.leaf_text().trim_start(chars="@").to_owned()
    }
  }
  ""
}

///|
/// Get the supplement.
pub fn Ref::supplement(self : Ref) -> ContentBlock? {
  try_cast_last(self.node)
}

///|
/// The contents of the heading.
pub fn Heading::body(self : Heading) -> Markup {
  cast_first(self.node)
}

///|
/// The section depth (number of equals signs).
pub fn Heading::depth(self : Heading) -> Int {
  for node in self.node.children() {
    if node.kind() is HeadingMarker {
      return if node.len() > 0 { node.len() } else { 1 }
    }
  }
  1
}

///|
/// The contents of the list item.
pub fn ListItem::body(self : ListItem) -> Markup {
  cast_first(self.node)
}

///|
/// The explicit numbering, if any: `23.`.
pub fn EnumItem::number(self : EnumItem) -> UInt64? {
  for node in self.node.children() {
    if node.kind() is EnumMarker {
      let text = node.leaf_text().trim_end(chars=".").to_owned()
      if u64_from_str_radix(text, 10) is Ok(n) {
        return Some(n)
      }
    }
  }
  None
}

///|
/// The contents of the list item.
pub fn EnumItem::body(self : EnumItem) -> Markup {
  cast_first(self.node)
}

///|
/// The term described by the item.
pub fn TermItem::term(self : TermItem) -> Markup {
  cast_first(self.node)
}

///|
/// The description of the term.
pub fn TermItem::description(self : TermItem) -> Markup {
  cast_last(self.node)
}
