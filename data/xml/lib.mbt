// Port of `roxmltree` 0.21.1 `src/lib.rs`: represent an XML document as a
// read-only tree.

///|
/// The <http://www.w3.org/XML/1998/namespace> URI.
pub const NS_XML_URI : String = "http://www.w3.org/XML/1998/namespace"

///|
/// The prefix 'xml', which is by definition bound to NS_XML_URI
const NS_XML_PREFIX : String = "xml"

///|
/// The <http://www.w3.org/2000/xmlns/> URI.
pub const NS_XMLNS_URI : String = "http://www.w3.org/2000/xmlns/"

///|
/// The string 'xmlns', which is used to declare new namespaces
const XMLNS : String = "xmlns"

///|
/// Position in text.
///
/// Position indicates a row/line and a column in the original text. Starting
/// from 1:1. The column is counted in chars.
pub(all) struct TextPos {
  row : Int
  col : Int
} derive(Eq, Debug)

///|
/// Constructs a new `TextPos`.
pub fn TextPos::new(row : Int, col : Int) -> TextPos {
  { row, col, }
}

///|
/// Formats as `row:col` (upstream `impl Display for TextPos`).
pub impl Show for TextPos with fn output(self, logger) {
  logger.write_string("\{self.row}:\{self.col}")
}

///|
/// An XML tree container (upstream `Document`).
pub struct Document {
  /// The original data (UTF-8). Required for `text_pos_at`.
  priv text : Bytes
  priv nodes : Array[NodeData]
  priv attributes : Array[AttributeData]
  priv namespaces : Namespaces
}

///|
/// Returns the root node.
pub fn Document::root(self : Document) -> Node {
  { doc: self, id: 0, }
}

///|
/// Returns the node of the tree with the given id (0 is the root node).
pub fn Document::get_node(self : Document, id : Int) -> Node? {
  if id >= 0 && id < self.nodes.length() {
    Some({ doc: self, id, })
  } else {
    None
  }
}

///|
/// Returns the root element of the document.
///
/// Unlike `root`, will return a first element node.
pub fn Document::root_element(self : Document) -> Node {
  // Safe, because the `Document` is guarantee to have at least one element.
  self.root().first_element_child().unwrap()
}

///|
/// Returns all nodes of the document in document order.
///
/// Shorthand for `doc.root().descendants()`.
pub fn Document::descendants(self : Document) -> Array[Node] {
  self.root().descendants()
}

///|
/// Calculates `TextPos` in the original document from position in bytes.
pub fn Document::text_pos_at(self : Document, pos : Int) -> TextPos {
  Stream::new(self.text).gen_text_pos_from(pos)
}

///|
/// Returns the input text of the original document.
pub fn Document::input_text(self : Document) -> String {
  @utf8.decode_lossy(self.text)
}

///|
/// A list of supported node types.
pub(all) enum NodeType {
  /// The root node of the `Document`.
  Root
  /// An element node.
  ///
  /// Only an element can have a tag name and attributes.
  Element
  /// A processing instruction.
  PI
  /// A comment node.
  Comment
  /// A text node.
  Text
} derive(Eq, Debug)

///|
/// A processing instruction.
pub(all) struct PI {
  target : String
  value : String?
} derive(Eq, Debug)

///|
/// A short range (indices into a document-internal array).
priv struct ShortRange {
  start : Int
  end : Int
}

///|
priv enum NodeKind {
  Root
  Element(
    tag_name~ : ExpandedNameIndexed,
    attributes~ : ShortRange,
    namespaces~ : ShortRange
  )
  PI(PI)
  Comment(String)
  Text(String)
}

///|
priv struct NodeData {
  parent : Int?
  mut prev_sibling : Int?
  mut next_subtree : Int?
  mut last_child : Int?
  mut kind : NodeKind
  range_start : Int
  mut range_end : Int
}

///|
priv struct AttributeData {
  name : ExpandedNameIndexed
  value : String
  range_start : Int
  range_end : Int
  qname_len : Int
  eq_len : Int // includes any surrounding spaces
}

///|
/// An attribute.
pub struct Attribute {
  priv doc : Document
  priv data : AttributeData
}

///|
/// Returns attribute's namespace URI.
pub fn Attribute::namespace(self : Attribute) -> String? {
  self.data.name.ns(self.doc).map(fn(ns) { ns.uri })
}

///|
/// Returns attribute's (local) name.
pub fn Attribute::name(self : Attribute) -> String {
  self.data.name.local_name
}

///|
/// Returns attribute's value.
pub fn Attribute::value(self : Attribute) -> String {
  self.data.value
}

///|
/// Returns attribute's range in bytes in the original document.
///
/// ```text
/// <e n:attr='value'/>
///    ^^^^^^^^^^^^^^
/// ```
pub fn Attribute::range(self : Attribute) -> (Int, Int) {
  (self.data.range_start, self.data.range_end)
}

///|
/// Returns attribute's qname's range in bytes in the original document.
pub fn Attribute::range_qname(self : Attribute) -> (Int, Int) {
  (self.data.range_start, self.data.range_start + self.data.qname_len)
}

///|
/// Returns attribute's value's range in bytes in the original document,
/// excluding the surrounding quotes.
pub fn Attribute::range_value(self : Attribute) -> (Int, Int) {
  // +1 on start and -1 on end are to exclude the quotes around the value
  // (all valid quotes are 1 byte)
  let start = self.data.range_start + self.data.qname_len + self.data.eq_len + 1
  (start, self.data.range_end - 1)
}

///|
/// A namespace.
///
/// Contains URI and *prefix* pair.
pub struct Namespace {
  priv name : String?
  priv uri : String
} derive(Eq, Debug)

///|
/// Returns namespace name/prefix.
pub fn Namespace::name(self : Namespace) -> String? {
  self.name
}

///|
/// Returns namespace URI.
pub fn Namespace::uri(self : Namespace) -> String {
  self.uri
}

///|
priv struct Namespaces {
  // Deduplicated namespace values used throughout the document
  values : Array[Namespace]
  // Indices into the above in tree order as the document is parsed
  tree_order : Array[Int]
  // Used for deduplication (upstream: indices sorted by value).
  dedup : Map[(String?, String), Int]
}

///|
fn Namespaces::new() -> Namespaces {
  { values: [], tree_order: [], dedup: Map([]), }
}

///|
fn Namespaces::push_ns(
  self : Namespaces,
  name : String?,
  uri : String,
) -> Unit raise XmlError {
  let idx = match self.dedup.get((name, uri)) {
    Some(idx) => idx
    None => {
      if self.values.length() > 0xFFFF {
        raise NamespacesLimitReached
      }
      let idx = self.values.length()
      self.values.push({ name, uri, })
      self.dedup[(name, uri)] = idx
      idx
    }
  }
  self.tree_order.push(idx)
}

///|
fn Namespaces::push_ref(self : Namespaces, tree_idx : Int) -> Unit {
  let idx = self.tree_order[tree_idx]
  self.tree_order.push(idx)
}

///|
fn Namespaces::exists(self : Namespaces, start : Int, prefix : String?) -> Bool {
  for i in start..<self.tree_order.length() {
    if self.values[self.tree_order[i]].name == prefix {
      return true
    }
  }
  false
}

///|
fn Namespaces::get(self : Namespaces, idx : Int) -> Namespace {
  self.values[idx]
}

///|
priv struct ExpandedNameIndexed {
  namespace_idx : Int?
  local_name : String
}

///|
fn ExpandedNameIndexed::ns(
  self : ExpandedNameIndexed,
  doc : Document,
) -> Namespace? {
  self.namespace_idx.map(fn(idx) { doc.namespaces.get(idx) })
}

///|
fn ExpandedNameIndexed::as_expanded_name(
  self : ExpandedNameIndexed,
  doc : Document,
) -> ExpandedName {
  { uri: self.ns(doc).map(fn(ns) { ns.uri }), name: self.local_name, }
}

///|
/// An expanded name.
///
/// Contains an namespace URI and name pair.
pub(all) struct ExpandedName {
  uri : String?
  name : String
} derive(Eq)

///|
/// Returns a namespace URI.
pub fn ExpandedName::namespace(self : ExpandedName) -> String? {
  self.uri
}

///|
/// Returns a local name.
pub fn ExpandedName::name(self : ExpandedName) -> String {
  self.name
}

///|
/// Formats as `{uri}name` or `name` (upstream `impl Debug for ExpandedName`).
pub impl Show for ExpandedName with fn output(self, logger) {
  match self.uri {
    Some(ns) => logger.write_string("{\{ns}}\{self.name}")
    None => logger.write_string(self.name)
  }
}

///|
/// A node in a document.
pub struct Node {
  /// The tree containing the node.
  priv doc : Document
  /// Node's ID.
  priv id : Int
}

///|
pub impl Eq for Node with fn equal(self, other) {
  self.id == other.id && physical_equal(self.doc, other.doc)
}

///|
fn Node::d(self : Node) -> NodeData {
  self.doc.nodes[self.id]
}

///|
/// Returns node's type.
pub fn Node::node_type(self : Node) -> NodeType {
  match self.d().kind {
    Root => Root
    Element(_) => Element
    PI(_) => PI
    Comment(_) => Comment
    Text(_) => Text
  }
}

///|
/// Checks that node is a root node.
pub fn Node::is_root(self : Node) -> Bool {
  self.node_type() == Root
}

///|
/// Checks that node is an element node.
pub fn Node::is_element(self : Node) -> Bool {
  self.node_type() == Element
}

///|
/// Checks that node is a processing instruction node.
pub fn Node::is_pi(self : Node) -> Bool {
  self.node_type() == PI
}

///|
/// Checks that node is a comment node.
pub fn Node::is_comment(self : Node) -> Bool {
  self.node_type() == Comment
}

///|
/// Checks that node is a text node.
pub fn Node::is_text(self : Node) -> Bool {
  self.node_type() == Text
}

///|
/// Returns node's document.
pub fn Node::document(self : Node) -> Document {
  self.doc
}

///|
/// Returns node's ID (an index into the document's nodes; 0 is the root).
pub fn Node::id(self : Node) -> Int {
  self.id
}

///|
/// Returns node's tag name.
///
/// Returns an empty name with no namespace if the current node is not an
/// element.
pub fn Node::tag_name(self : Node) -> ExpandedName {
  match self.d().kind {
    Element(tag_name~, ..) => tag_name.as_expanded_name(self.doc)
    _ => { uri: None, name: "", }
  }
}

///|
/// Checks that node has a specified tag name (compares the namespace too if
/// `ns` is given).
pub fn Node::has_tag_name(self : Node, name : String, ns? : String) -> Bool {
  match self.d().kind {
    Element(tag_name~, ..) =>
      match ns {
        Some(_) => tag_name.as_expanded_name(self.doc) == { uri: ns, name, }
        None => tag_name.local_name == name
      }
    _ => false
  }
}

///|
/// Returns node's default namespace URI.
pub fn Node::default_namespace(self : Node) -> String? {
  for ns in self.namespaces() {
    if ns.name is None {
      return Some(ns.uri)
    }
  }
  None
}

///|
/// Returns a prefix for a given namespace URI.
pub fn Node::lookup_prefix(self : Node, uri : String) -> String? {
  if uri == NS_XML_URI {
    return Some(NS_XML_PREFIX)
  }
  for ns in self.namespaces() {
    if ns.uri == uri {
      return ns.name
    }
  }
  None
}

///|
/// Returns an URI for a given prefix.
pub fn Node::lookup_namespace_uri(self : Node, prefix : String?) -> String? {
  for ns in self.namespaces() {
    if ns.name == prefix {
      return Some(ns.uri)
    }
  }
  None
}

///|
/// Returns element's attribute value (compares the namespace too if
/// `ns` is given).
pub fn Node::attribute(self : Node, name : String, ns? : String) -> String? {
  self.attribute_node(name, ns?).map(fn(a) { a.value() })
}

///|
/// Returns element's attribute object.
pub fn Node::attribute_node(
  self : Node,
  name : String,
  ns? : String,
) -> Attribute? {
  let expected : ExpandedName = { uri: ns, name, }
  for a in self.attributes() {
    let found = match ns {
      Some(_) => a.data.name.as_expanded_name(self.doc) == expected
      None => a.data.name.local_name == name
    }
    if found {
      return Some(a)
    }
  }
  None
}

///|
/// Checks that element has a specified attribute.
pub fn Node::has_attribute(self : Node, name : String, ns? : String) -> Bool {
  self.attribute_node(name, ns?) is Some(_)
}

///|
/// Returns element's attributes.
pub fn Node::attributes(self : Node) -> Array[Attribute] {
  match self.d().kind {
    Element(attributes~, ..) =>
      Array::makei(attributes.end - attributes.start, fn(i) {
        { doc: self.doc, data: self.doc.attributes[attributes.start + i], }
      })
    _ => []
  }
}

///|
/// Returns element's namespaces.
pub fn Node::namespaces(self : Node) -> Array[Namespace] {
  match self.d().kind {
    Element(namespaces~, ..) =>
      Array::makei(namespaces.end - namespaces.start, fn(i) {
        self.doc.namespaces.get(
          self.doc.namespaces.tree_order[namespaces.start + i],
        )
      })
    _ => []
  }
}

///|
/// Returns node's text.
///
/// - for an element will return a first text child
/// - for a comment will return a self text
/// - for a text node will return a self text
pub fn Node::text(self : Node) -> String? {
  match self.d().kind {
    Element(_) =>
      match self.first_child() {
        Some(child) if child.is_text() =>
          match child.d().kind {
            Text(text) => Some(text)
            _ => None
          }
        _ => None
      }
    Comment(text) => Some(text)
    Text(text) => Some(text)
    _ => None
  }
}

///|
/// Returns element's tail text.
pub fn Node::tail(self : Node) -> String? {
  if !self.is_element() {
    return None
  }
  match self.next_sibling() {
    Some(n) =>
      match n.d().kind {
        Text(text) => Some(text)
        _ => None
      }
    None => None
  }
}

///|
/// Returns node as Processing Instruction.
pub fn Node::pi(self : Node) -> PI? {
  match self.d().kind {
    PI(pi) => Some(pi)
    _ => None
  }
}

///|
/// Returns the parent of this node.
pub fn Node::parent(self : Node) -> Node? {
  self.d().parent.map(fn(id) { { doc: self.doc, id, } })
}

///|
/// Returns the parent element of this node.
pub fn Node::parent_element(self : Node) -> Node? {
  let mut cur = self.parent()
  while cur is Some(n) {
    if n.is_element() {
      return Some(n)
    }
    cur = n.parent()
  }
  None
}

///|
/// Returns the previous sibling of this node.
pub fn Node::prev_sibling(self : Node) -> Node? {
  self.d().prev_sibling.map(fn(id) { { doc: self.doc, id, } })
}

///|
/// Returns the previous sibling element of this node.
pub fn Node::prev_sibling_element(self : Node) -> Node? {
  let mut cur = self.prev_sibling()
  while cur is Some(n) {
    if n.is_element() {
      return Some(n)
    }
    cur = n.prev_sibling()
  }
  None
}

///|
/// Returns the next sibling of this node.
pub fn Node::next_sibling(self : Node) -> Node? {
  match self.d().next_subtree {
    Some(id) => {
      let node : Node = { doc: self.doc, id, }
      // next_subtree will always have a previous sibling
      if node.d().prev_sibling == Some(self.id) {
        Some(node)
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// Returns the next sibling element of this node.
pub fn Node::next_sibling_element(self : Node) -> Node? {
  let mut cur = self.next_sibling()
  while cur is Some(n) {
    if n.is_element() {
      return Some(n)
    }
    cur = n.next_sibling()
  }
  None
}

///|
/// Returns the first child of this node.
pub fn Node::first_child(self : Node) -> Node? {
  self.d().last_child.map(fn(_) { { doc: self.doc, id: self.id + 1, } })
}

///|
/// Returns the first element child of this node.
pub fn Node::first_element_child(self : Node) -> Node? {
  for n in self.children() {
    if n.is_element() {
      return Some(n)
    }
  }
  None
}

///|
/// Returns the last child of this node.
pub fn Node::last_child(self : Node) -> Node? {
  self.d().last_child.map(fn(id) { { doc: self.doc, id, } })
}

///|
/// Returns the last element child of this node.
pub fn Node::last_element_child(self : Node) -> Node? {
  let mut cur = self.last_child()
  while cur is Some(n) {
    if n.is_element() {
      return Some(n)
    }
    cur = n.prev_sibling()
  }
  None
}

///|
/// Returns true if this node has siblings.
pub fn Node::has_siblings(self : Node) -> Bool {
  self.d().prev_sibling is Some(_) || self.next_sibling() is Some(_)
}

///|
/// Returns true if this node has children.
pub fn Node::has_children(self : Node) -> Bool {
  self.d().last_child is Some(_)
}

///|
/// Returns the children of this node (upstream `Children` iterator).
pub fn Node::children(self : Node) -> Array[Node] {
  let result = []
  let back = self.last_child()
  let mut front = self.first_child()
  while front is Some(node) {
    result.push(node)
    if Some(node) == back {
      break
    }
    front = node.next_sibling()
  }
  result
}

///|
/// Returns this node and its descendants in document order.
pub fn Node::descendants(self : Node) -> Array[Node] {
  let from = self.id
  let until = match self.d().next_subtree {
    Some(id) => id
    None => self.doc.nodes.length()
  }
  Array::makei(until - from, fn(i) { { doc: self.doc, id: from + i, } })
}

///|
/// Returns node's range in bytes in the original document.
pub fn Node::range(self : Node) -> (Int, Int) {
  let d = self.d()
  (d.range_start, d.range_end)
}

///|
pub impl @debug.Debug for Node with fn to_repr(self) {
  @debug.Repr(Show::to_string(self))
}

///|
/// Formats similar to upstream `impl Debug for Node`.
pub impl Show for Node with fn output(self, logger) {
  match self.d().kind {
    Root => logger.write_string("Root")
    Element(_) => {
      logger.write_string(
        "Element { tag_name: \{self.tag_name()}, attributes: [",
      )
      for i, a in self.attributes() {
        if i > 0 {
          logger.write_string(", ")
        }
        logger.write_string(
          "Attribute { name: \{a.data.name.as_expanded_name(self.doc)}, value: \{@unicode.rust_debug_str(a.data.value)} }",
        )
      }
      logger.write_string("], namespaces: [")
      for i, ns in self.namespaces() {
        if i > 0 {
          logger.write_string(", ")
        }
        let name = match ns.name {
          Some(n) => "Some(\{@unicode.rust_debug_str(n)})"
          None => "None"
        }
        logger.write_string(
          "Namespace { name: \{name}, uri: \{@unicode.rust_debug_str(ns.uri)} }",
        )
      }
      logger.write_string("] }")
    }
    PI(pi) => {
      let value = match pi.value {
        Some(v) => "Some(\{@unicode.rust_debug_str(v)})"
        None => "None"
      }
      logger.write_string(
        "PI { target: \{@unicode.rust_debug_str(pi.target)}, value: \{value} }",
      )
    }
    Comment(text) =>
      logger.write_string("Comment(\{@unicode.rust_debug_str(text)})")
    Text(text) => logger.write_string("Text(\{@unicode.rust_debug_str(text)})")
  }
}
