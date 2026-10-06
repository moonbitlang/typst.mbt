///|
/// A syntax node in a context: knows its exact offset in the file and provides
/// access to its children, parent and siblings.
///
/// **Note that all sibling and leaf accessors skip over trivia!**
pub struct LinkedNode {
  /// The underlying syntax node.
  node : SyntaxNode
  /// The parent of this node.
  parent : LinkedNode?
  /// The index of this node in its parent's children array.
  index : Int
  /// This node's UTF-8 byte offset in the source file.
  offset : Int
}

///|
/// Start a new traversal at a root node.
pub fn LinkedNode::new(root : SyntaxNode) -> LinkedNode {
  { node: root, parent: None, index: 0, offset: 0, }
}

///|
/// The contained syntax node.
pub fn LinkedNode::get(self : LinkedNode) -> SyntaxNode {
  self.node
}

///|
/// The index of this node in its parent's children list.
pub fn LinkedNode::index(self : LinkedNode) -> Int {
  self.index
}

///|
/// The absolute byte offset of this node in the source file.
pub fn LinkedNode::offset(self : LinkedNode) -> Int {
  self.offset
}

///|
/// The byte range of this node in the source file.
pub fn LinkedNode::range(self : LinkedNode) -> (Int, Int) {
  (self.offset, self.offset + self.node.len())
}

///|
pub fn LinkedNode::kind(self : LinkedNode) -> SyntaxKind {
  self.node.kind()
}

///|
pub fn LinkedNode::len(self : LinkedNode) -> Int {
  self.node.len()
}

///|
/// This node's children as linked nodes.
pub fn LinkedNode::children(self : LinkedNode) -> Array[LinkedNode] {
  let out = []
  let mut offset = self.offset
  for i, child in self.node.children() {
    out.push({ node: child, parent: Some(self), index: i, offset, })
    offset += child.len()
  }
  out
}

///|
/// Find a descendant with the given span.
pub fn LinkedNode::find(self : LinkedNode, span : Span) -> LinkedNode? {
  match span.get() {
    Detached => None
    Number(num~, ..) => self.find_number(num)
    Range(start~, end~, ..) => self.find_range(start, end)
  }
}

///|
/// Find the descendant whose span number matches the given number.
pub fn LinkedNode::find_number(
  self : LinkedNode,
  target : SpanNumber,
) -> LinkedNode? {
  let number = self.node.span().number()
  if number == target.0 {
    return Some(self)
  }
  if self.node.is_inner() && number < target.0 {
    let children = self.children()
    for i, child in children {
      let next_larger = i + 1 >= children.length() ||
        children[i + 1].node.span().number() > target.0
      if next_larger && child.find_number(target) is Some(found) {
        return Some(found)
      }
    }
  }
  None
}

///|
/// Find the descendant whose byte range matches the given range exactly.
pub fn LinkedNode::find_range(
  self : LinkedNode,
  start : Int,
  end : Int,
) -> LinkedNode? {
  if start == self.offset && end == self.offset + self.len() {
    return Some(self)
  }
  for child in self.children() {
    if child.offset <= start && end <= child.offset + child.len() {
      return child.find_range(start, end)
    }
  }
  None
}

///|
/// Get this node's parent.
pub fn LinkedNode::parent(self : LinkedNode) -> LinkedNode? {
  self.parent
}

///|
/// Get the kind of this node's parent.
pub fn LinkedNode::parent_kind(self : LinkedNode) -> SyntaxKind? {
  self.parent.map(p => p.node.kind())
}

///|
/// Get the first previous non-trivia sibling node.
pub fn LinkedNode::prev_sibling(self : LinkedNode) -> LinkedNode? {
  guard self.parent is Some(parent) else { return None }
  let children = parent.node.children()
  let mut offset = self.offset
  for index = self.index - 1; index >= 0; index = index - 1 {
    let node = children[index]
    offset -= node.len()
    if !node.kind().is_trivia() {
      return Some({ node, parent: Some(parent), index, offset, })
    }
  }
  None
}

///|
/// Get the first previous sibling node, including potential trivia.
pub fn LinkedNode::prev_sibling_with_trivia(self : LinkedNode) -> LinkedNode? {
  guard self.parent is Some(parent) && self.index > 0 else { return None }
  let index = self.index - 1
  let node = parent.node.children()[index]
  Some({ node, parent: Some(parent), index, offset: self.offset - node.len(), })
}

///|
/// Get the next non-trivia sibling node.
pub fn LinkedNode::next_sibling(self : LinkedNode) -> LinkedNode? {
  guard self.parent is Some(parent) else { return None }
  let children = parent.node.children()
  let mut offset = self.offset + self.len()
  for index in (self.index + 1)..<children.length() {
    let node = children[index]
    if !node.kind().is_trivia() {
      return Some({ node, parent: Some(parent), index, offset, })
    }
    offset += node.len()
  }
  None
}

///|
/// Get the next sibling node, including potential trivia.
pub fn LinkedNode::next_sibling_with_trivia(self : LinkedNode) -> LinkedNode? {
  guard self.parent is Some(parent) else { return None }
  let children = parent.node.children()
  let index = self.index + 1
  guard index < children.length() else { return None }
  Some({
    node: children[index],
    parent: Some(parent),
    index,
    offset: self.offset + self.len(),
  })
}

///|
/// Get the kind of this node's first previous non-trivia sibling.
pub fn LinkedNode::prev_sibling_kind(self : LinkedNode) -> SyntaxKind? {
  self.prev_sibling().map(n => n.kind())
}

///|
/// Get the kind of this node's next non-trivia sibling.
pub fn LinkedNode::next_sibling_kind(self : LinkedNode) -> SyntaxKind? {
  self.next_sibling().map(n => n.kind())
}

///|
/// Indicates whether the cursor is before the related byte index, or after.
pub(all) enum Side {
  Before
  After
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Side with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Side with @debug.Debug::{to_repr}

///|
/// Get the rightmost non-trivia leaf before this node.
pub fn LinkedNode::prev_leaf(self : LinkedNode) -> LinkedNode? {
  let mut node = self
  while node.prev_sibling() is Some(prev) {
    if prev.rightmost_leaf() is Some(leaf) {
      return Some(leaf)
    }
    node = prev
  }
  self.parent.bind(p => p.prev_leaf())
}

///|
/// Find the leftmost contained non-trivia leaf.
pub fn LinkedNode::leftmost_leaf(self : LinkedNode) -> LinkedNode? {
  if self.node.is_leaf() && !self.kind().is_trivia() && !self.kind().is_error() {
    return Some(self)
  }
  for child in self.children() {
    if child.leftmost_leaf() is Some(leaf) {
      return Some(leaf)
    }
  }
  None
}

///|
/// Get the leaf immediately before the specified byte offset.
fn LinkedNode::leaf_before(self : LinkedNode, cursor : Int) -> LinkedNode? {
  if self.node.children().length() == 0 && cursor <= self.offset + self.len() {
    return Some(self)
  }
  let mut offset = self.offset
  let count = self.node.children().length()
  for i, child in self.children() {
    let len = child.len()
    if (offset < cursor && cursor <= offset + len) ||
      (offset == cursor && i + 1 == count) {
      return child.leaf_before(cursor)
    }
    offset += len
  }
  None
}

///|
/// Get the leaf after the specified byte offset.
fn LinkedNode::leaf_after(self : LinkedNode, cursor : Int) -> LinkedNode? {
  if self.node.children().length() == 0 && cursor < self.offset + self.len() {
    return Some(self)
  }
  let mut offset = self.offset
  for child in self.children() {
    let len = child.len()
    if offset <= cursor && cursor < offset + len {
      return child.leaf_after(cursor)
    }
    offset += len
  }
  None
}

///|
/// Get the leaf at the specified byte offset.
pub fn LinkedNode::leaf_at(
  self : LinkedNode,
  cursor : Int,
  side : Side,
) -> LinkedNode? {
  match side {
    Before => self.leaf_before(cursor)
    After => self.leaf_after(cursor)
  }
}

///|
/// Find the rightmost contained non-trivia leaf.
pub fn LinkedNode::rightmost_leaf(self : LinkedNode) -> LinkedNode? {
  if self.node.is_leaf() && !self.kind().is_trivia() {
    return Some(self)
  }
  let children = self.children()
  for i = children.length() - 1; i >= 0; i = i - 1 {
    if children[i].rightmost_leaf() is Some(leaf) {
      return Some(leaf)
    }
  }
  None
}

///|
/// Get the leftmost non-trivia leaf after this node.
pub fn LinkedNode::next_leaf(self : LinkedNode) -> LinkedNode? {
  let mut node = self
  while node.next_sibling() is Some(next) {
    if next.leftmost_leaf() is Some(leaf) {
      return Some(leaf)
    }
    node = next
  }
  self.parent.bind(p => p.next_leaf())
}

///|
/// Get the [SyntaxMode] we will be in when immediately after this node.
pub fn LinkedNode::mode_after(self : LinkedNode) -> SyntaxMode? {
  match self.kind().mode_after() {
    Known(mode) => Some(mode)
    NoMode => None
    Text if self.parent_kind() is Some(Raw) => None
    RawDelim if self.index == 0 => None
    Text => Some(Markup)
    Dollar if self.index == 0 => Some(Math)
    Space if self.parent_kind() is Some(Equation) => Some(Math)
    Embeddable if self.prev_sibling_with_trivia() is Some(prev) &&
      prev.kind() == Hash => Some(Code)
    Parent | RawDelim | Space | Dollar | Embeddable => self.parent_mode()
  }
}

///|
/// Get the [SyntaxMode] we will be in when immediately after the parent.
pub fn LinkedNode::parent_mode(self : LinkedNode) -> SyntaxMode? {
  self.parent.bind(p => p.mode_after())
}
