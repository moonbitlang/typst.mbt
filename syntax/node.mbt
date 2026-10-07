// Port of `crates/typst-syntax/src/node.rs`.
//
// # Who may write to a node
//
// Upstream's nodes are values with `Arc`s inside (`Node::Inner(Arc<InnerNode>,
// ..)`, `Error(Arc<ErrorNode>, ..)`, `Warning(Arc<WarningWrapper>, ..)`), and
// every write goes through `Arc::make_mut` (`inner_and_span_mut`, node.rs:85;
// `hints_mut`, :99; `synthesize_with`, :398; `convert_to_kind`, :484): a
// record that somebody else holds is copied before it is written, so whoever
// holds a node keeps what it held. A closure holds the node of its body, a
// module the closures; after `Source::edit` they still describe the text
// they were made from.
//
// Here a node is an object with mutable fields and there is no reference
// count to ask. The rule that gives the same semantics:
//
// 1. **A node is owned by the parse or the edit that made it until it is
//    published, and immutable from then on.** A node is made by the lexer
//    and the parser ([parse], [parse_code], [parse_math], [reparse_block],
//    [reparse_markup]), by a constructor ([SyntaxNode::leaf],
//    [SyntaxNode::inner], [SyntaxNode::error], [SyntaxNode::placeholder]) or
//    as a copy ([SyntaxNode::deep_clone], [SyntaxNode::make_mut]). It is
//    published when it is handed to anybody who may keep it: when it becomes
//    the root of a [Source] ([Source::new], [Source::with_root],
//    [Source::edit]), and when its maker returns it to code outside of this
//    package that does not own it alone.
// 2. **Only its owner writes to it.** The functions that write, and whom
//    they are for:
//    - while a tree is built (lexer and parser, on the nodes of the parse
//      that runs): [SyntaxNode::warn], [SyntaxNode::warn_at],
//      [SyntaxNode::hint], [SyntaxNode::hint_at], [SyntaxNode::with_hints],
//      [SyntaxNode::convert_to_kind], [SyntaxNode::convert_to_error],
//      [SyntaxNode::expected], [SyntaxNode::unexpected],
//      [SyntaxNode::children_mut];
//    - [SyntaxNode::numberize], on a tree that was just parsed
//      ([Source::new], and [reparse] when it parses the whole text);
//    - during an edit (`reparser.mbt`), on the copies of that edit only:
//      [SyntaxNode::children_mut], [SyntaxNode::update_parent],
//      [SyntaxNode::replace_children], which numbers the nodes it puts in
//      and, where it has to renumber their neighbours, copies of those;
//    - [SyntaxNode::synthesize] and [SyntaxNode::synthesize_ranges], the
//      two that are public: for a tree that its caller made and has not
//      given away (the evaluator calls them on what `parse` returned for a
//      string, `eval/lib.mbt`). Never for a tree that came out of a
//      [Source], nor for a tree built from nodes of one
//      ([SyntaxNode::inner] takes the children as they are): copy it first
//      ([SyntaxNode::deep_clone]).
// 3. **What an edit copies** (`reparse`, `try_reparse`,
//    [SyntaxNode::replace_children]): the root; every node on the way from
//    the root to the innermost node whose children are replaced, each with
//    its inner record, its children array (not the children) and the
//    warnings wrapped around it ([SyntaxNode::make_mut], the copy that
//    `Arc::make_mut` makes of a shared record); and, with all their
//    descendants, the neighbours of the replaced children that have to be
//    renumbered when the numbers between them run out
//    ([SyntaxNode::deep_clone]). The replacement comes from the parser and
//    is the edit's own. Nothing else is written, so everything else is
//    shared between the tree before and the tree after: the same objects,
//    with the same spans.
//
// The fields are private, so only this package can break the rule, and of
// what it exports only the two `synthesize` functions write. The compiler
// does not check the rest: see the note on [SyntaxNode::make_mut].
//
// The cost, against upstream: `Arc::make_mut` copies a record only if it is
// shared, this port always. Per edit that is, for the root and each node on
// the path, one node, one inner record and one array of as many references
// as the node has children (for top-level markup: one per word and space of
// the file), with a reference count taken for each child on the native
// backend. Upstream pays the same when a compilation still holds the tree
// (its copy of a `Vec<SyntaxNode>` clones every child), and nothing when
// nobody does.

///|
/// A node in the untyped syntax tree.
///
/// Unlike upstream (which uses copy-on-write `Arc`s), nodes are objects with
/// mutable fields that are written by their owner only and by nobody once
/// they are published (see the header of this file).
pub struct SyntaxNode {
  /// The underlying node data, potentially with wrapped warning messages.
  priv mut data : Node
  /// The node's span.
  priv mut span : Span
}

///|
/// The data for nodes in the tree, plus their [SyntaxKind].
priv enum Node {
  /// Text, kind, and UTF-8 byte length of the text.
  Leaf(String, SyntaxKind, Int)
  Inner(InnerNode, SyntaxKind)
  Error(ErrorNode)
  Warning(WarningWrapper, SyntaxKind)
}

///|
/// An inner node in the untyped syntax tree.
priv struct InnerNode {
  /// The byte length of the node in the source.
  mut len : Int
  /// The number of nodes in the whole subtree, including this node.
  mut descendants : Int
  /// Whether this node or any of its children contain a diagnostic.
  mut diagnosis : Diagnosis
  /// The upper bound of this node's numbering range.
  mut upper : UInt64
  /// This node's children, losslessly make up this node.
  children : Array[SyntaxNode]
}

///|
/// An error node in the untyped syntax tree.
priv struct ErrorNode {
  /// The source text of the node.
  text : String
  /// The UTF-8 byte length of `text`.
  len : Int
  /// The error message.
  message : String
  /// Additional hints, optionally targeting a sub-range of `text`.
  hints : Array[(String, SubRange?)]
}

///|
/// A warning message wrapped around a node in the tree.
priv struct WarningWrapper {
  /// The wrapped node data.
  mut child : Node
  /// A relative sub-range for targeting text not grouped by an existing span.
  mut sub_range : SubRange?
  /// The warning message.
  message : String
  /// Additional hints.
  hints : Array[(String, SubRange?)]
}

///|
/// Whether a node has diagnostic errors and/or warnings in it or its children.
pub(all) struct Diagnosis {
  errors : Bool
  warnings : Bool
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Diagnosis with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Diagnosis with @debug.Debug::{to_repr}

///|
pub fn Diagnosis::default() -> Diagnosis {
  { errors: false, warnings: false, }
}

///|
/// Whether there were errors or warnings.
pub fn Diagnosis::either(self : Diagnosis) -> Bool {
  self.errors || self.warnings
}

///|
/// Whether there were both errors and warnings.
pub fn Diagnosis::both(self : Diagnosis) -> Bool {
  self.errors && self.warnings
}

///|
/// Apply the `OR` of both fields separately.
pub fn Diagnosis::or(self : Diagnosis, other : Diagnosis) -> Diagnosis {
  {
    errors: self.errors || other.errors,
    warnings: self.warnings || other.warnings,
  }
}

///|
fn Diagnosis::any(nodes : ArrayView[SyntaxNode]) -> Diagnosis {
  nodes.fold(init=Diagnosis::default(), (d, n) => d.or(n.diagnosis()))
}

///|
/// A syntactical error or warning.
pub(all) struct SyntaxDiagnostic {
  /// `true` if the diagnostic is an error, `false` if it's a warning.
  is_error : Bool
  /// The span targeted by the diagnostic.
  span : DiagSpan
  /// The main diagnostic message.
  message : String
  /// Additional hints.
  hints : Array[DiagSpanned[String]]
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SyntaxDiagnostic with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SyntaxDiagnostic with @debug.Debug::{to_repr}

///|
/// The UTF-8 byte length of a string.
pub fn utf8_len(s : StringView) -> Int {
  let mut n = 0
  let len = s.length()
  for i = 0; i < len; {
    let c = s.code_unit_at(i).to_int()
    if c < 0x80 {
      n += 1
      continue i + 1
    } else if c < 0x800 {
      n += 2
      continue i + 1
    } else if c >= 0xD800 && c <= 0xDBFF && i + 1 < len {
      let d = s.code_unit_at(i + 1).to_int()
      if d >= 0xDC00 && d <= 0xDFFF {
        n += 4
        continue i + 2
      }
      n += 3
      continue i + 1
    } else {
      n += 3
      continue i + 1
    }
  }
  n
}

///|
fn InnerNode::new(children : Array[SyntaxNode]) -> InnerNode {
  let mut len = 0
  let mut descendants = 1
  let mut diagnosis = Diagnosis::default()
  for child in children {
    len += child.len()
    descendants += child.descendants()
    diagnosis = diagnosis.or(child.diagnosis())
  }
  { len, descendants, diagnosis, upper: 0, children, }
}

///|
/// Descend through warnings to the underlying data.
fn Node::base(self : Node) -> Node {
  for node = self {
    match node {
      Warning(w, _) => continue w.child
      other => break other
    }
  }
}

///|
fn Node::kind(self : Node) -> SyntaxKind {
  match self {
    Leaf(_, kind, _) | Inner(_, kind) | Warning(_, kind) => kind
    Error(_) => Error
  }
}

///|
fn Node::deep_clone(self : Node) -> Node {
  match self {
    Leaf(_, _, _) => self
    Inner(inner, kind) =>
      Inner(
        {
          len: inner.len,
          descendants: inner.descendants,
          diagnosis: inner.diagnosis,
          upper: inner.upper,
          children: inner.children.map(c => c.deep_clone()),
        },
        kind,
      )
    Error(err) =>
      Error({
        text: err.text,
        len: err.len,
        message: err.message,
        hints: err.hints.copy(),
      })
    Warning(w, kind) =>
      Warning(
        {
          child: w.child.deep_clone(),
          sub_range: w.sub_range,
          message: w.message,
          hints: w.hints.copy(),
        },
        kind,
      )
  }
}

///|
/// Create a new leaf node.
pub fn SyntaxNode::leaf(kind : SyntaxKind, text : StringView) -> SyntaxNode {
  let text = text.to_owned()
  { data: Leaf(text, kind, utf8_len(text)), span: Span::detached(), }
}

///|
/// Create a new inner node with children. The children array is copied, so
/// the caller keeps no alias into the new node.
pub fn SyntaxNode::inner(
  kind : SyntaxKind,
  children : ArrayView[SyntaxNode],
) -> SyntaxNode {
  SyntaxNode::inner_owned(kind, children.to_owned())
}

///|
/// Create a new inner node taking ownership of `children`.
fn SyntaxNode::inner_owned(
  kind : SyntaxKind,
  children : Array[SyntaxNode],
) -> SyntaxNode {
  { data: Inner(InnerNode::new(children), kind), span: Span::detached(), }
}

///|
/// Create a new error node with a message for the given text.
pub fn SyntaxNode::error(message : String, text : StringView) -> SyntaxNode {
  let text = text.to_owned()
  {
    data: Error({ text, len: utf8_len(text), message, hints: [], }),
    span: Span::detached(),
  }
}

///|
/// Create a dummy node of the given kind.
pub fn SyntaxNode::placeholder(kind : SyntaxKind) -> SyntaxNode {
  { data: Leaf("", kind, 0), span: Span::detached(), }
}

///|
/// A fully independent copy of this node and its subtree.
pub fn SyntaxNode::deep_clone(self : SyntaxNode) -> SyntaxNode {
  { data: self.data.deep_clone(), span: self.span, }
}

///|
/// The copy that `Arc::make_mut` makes of a shared record, one level deep:
/// the inner record with its children array (the children are the same
/// objects) and the warnings wrapped around it.
fn Node::make_mut(self : Node) -> Node {
  match self {
    // Immutable.
    Leaf(_, _, _) => self
    Inner(inner, kind) =>
      Inner(
        {
          len: inner.len,
          descendants: inner.descendants,
          diagnosis: inner.diagnosis,
          upper: inner.upper,
          children: inner.children.copy(),
        },
        kind,
      )
    // Not written by an edit: only `hints_mut` and `synthesize` write to an
    // error, and those are for trees that are being built.
    Error(_) => self
    Warning(w, kind) =>
      Warning(
        {
          child: w.child.make_mut(),
          sub_range: w.sub_range,
          message: w.message,
          hints: w.hints.copy(),
        },
        kind,
      )
  }
}

///|
/// A node that an edit may write to in place of this one, which stays as it
/// is: this node's kind, span and data, with a copy of the inner record, of
/// its children array (not of the children) and of the warnings around it.
///
/// Not upstream, where it is implicit: every write to an inner node goes
/// through `inner_and_span_mut` (node.rs:85-96), whose `Arc::make_mut`
/// (:91, and :93 for a warning) copies exactly this if the record is shared
/// and nothing if it is not. The port cannot ask, so the reparser calls this
/// for every node it is about to write to that it did not make itself, and
/// puts the copy where the node was (the node itself is an object here,
/// with its span; upstream's is a value inside its parent's `Vec`, copied
/// with the parent's record).
///
/// On enforcing the rule of this file's header with types: a tree under
/// construction and a published tree would have to be two types, a private
/// one with mutable fields for the lexer, the parser and the reparser, and
/// the public one without. Publishing is then either a copy of the whole
/// tree, which doubles the allocations of every parse, or a conversion
/// that costs nothing, which MoonBit has for a wrapper around one node
/// (`struct SyntaxNode(Builder)`) but not for the array of children inside
/// it: `children()` could no longer be a view of the stored array, and
/// every reader of a tree (`syntax/ast`, the evaluator, the highlighter,
/// `LinkedNode`) goes through it. `synthesize` would move to the private
/// type, with entry points that parse and synthesize in one step. That is
/// a change of the reading interface of the whole package for a guarantee
/// that concerns two public functions and this package's own code, so it
/// is not done here; if it is, start from how often `children()` is called
/// on the paths that matter.
fn SyntaxNode::make_mut(self : SyntaxNode) -> SyntaxNode {
  { data: self.data.make_mut(), span: self.span, }
}

///|
/// Add a warning message to an existing node.
fn SyntaxNode::warn(self : SyntaxNode, message : String) -> Unit {
  let kind = self.kind()
  self.data = Warning(
    { child: self.data, sub_range: None, message, hints: [], },
    kind,
  )
}

///|
/// Add a warning around this node at a particular sub-range of its text.
fn SyntaxNode::warn_at(
  self : SyntaxNode,
  start : Int,
  end : Int,
  message : String,
) -> Unit {
  guard end <= self.len() && SubRange::new(start, end) is Some(sub_range) else {
    abort("invalid warning sub-range")
  }
  let kind = self.kind()
  self.data = Warning(
    { child: self.data, sub_range: Some(sub_range), message, hints: [], },
    kind,
  )
}

///|
fn SyntaxNode::hints_mut(self : SyntaxNode) -> Array[(String, SubRange?)] {
  match self.data {
    Error(err) => err.hints
    Warning(w, _) => w.hints
    _ => abort("expected an error or warning")
  }
}

///|
/// Add a user-presentable hint to an existing error or warning.
fn SyntaxNode::hint(self : SyntaxNode, hint : String) -> Unit {
  self.hints_mut().push((hint, None))
}

///|
/// Add a hint to an existing error or warning at a sub-range of the text.
fn SyntaxNode::hint_at(
  self : SyntaxNode,
  start : Int,
  end : Int,
  hint : String,
) -> Unit {
  guard end <= self.len() && SubRange::new(start, end) is Some(sub_range) else {
    abort("invalid hint sub-range")
  }
  self.hints_mut().push((hint, Some(sub_range)))
}

///|
/// Add multiple hints to an error or warning.
fn SyntaxNode::with_hints(
  self : SyntaxNode,
  hints : ArrayView[String],
) -> SyntaxNode {
  let target = self.hints_mut()
  for h in hints {
    target.push((h, None))
  }
  self
}

///|
/// The type of the node.
pub fn SyntaxNode::kind(self : SyntaxNode) -> SyntaxKind {
  self.data.kind()
}

///|
/// Whether the node has zero length.
pub fn SyntaxNode::is_empty(self : SyntaxNode) -> Bool {
  self.len() == 0
}

///|
/// The UTF-8 byte length of the node in the source text.
pub fn SyntaxNode::len(self : SyntaxNode) -> Int {
  match self.data.base() {
    Leaf(_, _, len) => len
    Inner(inner, _) => inner.len
    Error(err) => err.len
    Warning(_, _) => abort("unreachable")
  }
}

///|
/// The span of the node.
pub fn SyntaxNode::span(self : SyntaxNode) -> Span {
  self.span
}

///|
/// The text of the node if it is a leaf or error node, otherwise empty.
pub fn SyntaxNode::leaf_text(self : SyntaxNode) -> String {
  match self.data.base() {
    Leaf(text, _, _) => text
    Error(err) => err.text
    _ => ""
  }
}

///|
/// The full text of the node, traversing the tree for inner nodes.
pub fn SyntaxNode::full_text(self : SyntaxNode) -> String {
  match self.data {
    Leaf(text, _, _) => text
    Error(err) => err.text
    _ => {
      let buf = StringBuilder()
      self.write_text(buf)
      buf.to_string()
    }
  }
}

///|
fn SyntaxNode::write_text(self : SyntaxNode, buf : StringBuilder) -> Unit {
  match self.data.base() {
    Leaf(text, _, _) => buf.write_string(text)
    Error(err) => buf.write_string(err.text)
    Inner(inner, _) =>
      for child in inner.children {
        child.write_text(buf)
      }
    Warning(_, _) => ()
  }
}

///|
/// The node's children.
pub fn SyntaxNode::children(self : SyntaxNode) -> ArrayView[SyntaxNode] {
  match self.data.base() {
    Inner(inner, _) => inner.children[:]
    _ => []
  }
}

///|
/// Whether the node has diagnostic errors and/or warnings in it or its
/// children.
pub fn SyntaxNode::diagnosis(self : SyntaxNode) -> Diagnosis {
  let base = match self.data.base() {
    Leaf(_, _, _) | Warning(_, _) => Diagnosis::default()
    Inner(inner, _) => inner.diagnosis
    Error(_) => { errors: true, warnings: false, }
  }
  match self.data {
    Warning(_, _) => { errors: base.errors, warnings: true, }
    _ => base
  }
}

///|
fn build_diagnostic_hints(
  parent_span : Span,
  hints : Array[(String, SubRange?)],
) -> Array[DiagSpanned[String]] {
  hints.map(h => {
    let (message, sub_range) = h
    match sub_range {
      Some(sr) =>
        { v: message, span: DiagSpan::from_span(parent_span, sub_range=sr), }
      None => { v: message, span: DiagSpan::detached(), }
    }
  })
}

///|
/// The error and warning diagnostics for this node and its descendants.
pub fn SyntaxNode::errors_and_warnings(
  self : SyntaxNode,
) -> (Array[SyntaxDiagnostic], Array[SyntaxDiagnostic]) {
  let errors = []
  let warnings = []
  fn go(node : SyntaxNode) {
    let mut data = node.data
    while true {
      match data {
        Inner(inner, _) => {
          if inner.diagnosis.either() {
            for child in inner.children {
              go(child)
            }
          }
          break
        }
        Leaf(_, _, _) => break
        Error(err) => {
          errors.push({
            is_error: true,
            span: DiagSpan::from_span(node.span),
            message: err.message,
            hints: build_diagnostic_hints(node.span, err.hints),
          })
          break
        }
        Warning(w, _) => {
          let span = match w.sub_range {
            Some(sr) => DiagSpan::from_span(node.span, sub_range=sr)
            None => DiagSpan::from_span(node.span)
          }
          warnings.push({
            is_error: false,
            span,
            message: w.message,
            hints: build_diagnostic_hints(node.span, w.hints),
          })
          data = w.child
        }
      }
    }
  }

  go(self)
  (errors, warnings)
}

///|
/// Whether the two syntax nodes are the same apart from spans.
pub fn SyntaxNode::spanless_eq(self : SyntaxNode, other : SyntaxNode) -> Bool {
  self.kind() == other.kind() && spanless_eq_data(self.data, other.data)
}

///|
fn spanless_eq_data(a : Node, b : Node) -> Bool {
  match (a, b) {
    (Leaf(x, _, _), Leaf(y, _, _)) => x == y
    (Inner(x, _), Inner(y, _)) =>
      x.len == y.len &&
      x.descendants == y.descendants &&
      x.diagnosis == y.diagnosis &&
      x.children.length() == y.children.length() &&
      x.children.mapi((i, c) => c.spanless_eq(y.children[i])).all(b => b)
    (Error(x), Error(y)) =>
      x.text == y.text && x.message == y.message && x.hints == y.hints
    (Warning(x, _), Warning(y, _)) =>
      x.message == y.message &&
      x.hints == y.hints &&
      spanless_eq_data(x.child, y.child)
    _ => false
  }
}

///|
/// Convert the node to another kind. Aborts on errors.
fn SyntaxNode::convert_to_kind(
  self : SyntaxNode,
  new_kind : SyntaxKind,
) -> Unit {
  guard !new_kind.is_error() && !self.kind().is_error() else {
    abort("cannot convert to or from an error")
  }
  fn convert(data : Node) -> Node {
    match data {
      Leaf(text, _, len) => Leaf(text, new_kind, len)
      Inner(inner, _) => Inner(inner, new_kind)
      Error(_) => abort("unreachable")
      Warning(w, _) => {
        w.child = convert(w.child)
        Warning(w, new_kind)
      }
    }
  }

  self.data = convert(self.data)
}

///|
/// Convert the node to an error, if it isn't already one.
fn SyntaxNode::convert_to_error(self : SyntaxNode, message : String) -> Unit {
  if !self.kind().is_error() {
    let text = self.full_text()
    self.data = Error({ text, len: utf8_len(text), message, hints: [], })
    self.span = Span::detached()
  }
}

///|
/// Convert the node to an error stating that `expected` was expected, but the
/// current kind was found.
fn SyntaxNode::expected(self : SyntaxNode, expected : String) -> Unit {
  let kind = self.kind()
  self.convert_to_error("expected \{expected}, found \{kind.name()}")
  if kind.is_keyword() && (expected == "identifier" || expected == "pattern") {
    let text = self.leaf_text()
    self.hint(
      "keyword `\{text}` is not allowed as an identifier; try `\{text}_` instead",
    )
  }
}

///|
/// Convert the node to an error stating it was unexpected.
fn SyntaxNode::unexpected(self : SyntaxNode) -> Unit {
  self.convert_to_error("unexpected \{self.kind().name()}")
}

///|
/// Indicates that a node cannot be numbered within a given interval.
priv suberror Unnumberable

///|
/// The inner node data, descending past warnings.
fn SyntaxNode::inner_node(self : SyntaxNode) -> InnerNode? {
  match self.data.base() {
    Inner(inner, _) => Some(inner)
    _ => None
  }
}

///|
/// Assign spans to each node.
///
/// Writes to every node of the subtree: for a tree that its caller owns
/// (see the header of this file).
fn SyntaxNode::numberize(
  self : SyntaxNode,
  id : FileId,
  start : UInt64,
  end : UInt64,
) -> Unit raise Unnumberable {
  if start >= end {
    raise Unnumberable
  }
  match self.inner_node() {
    Some(inner) => inner.numberize(self, id, None, start, end)
    None => self.span = Span::from_number(id, SpanNumber((start + end) / 2))
  }
}

///|
/// Assign span numbers within `[start, end)` to this node's subtree or just a
/// range of its children.
fn InnerNode::numberize(
  self : InnerNode,
  owner : SyntaxNode,
  id : FileId,
  range : (Int, Int)?,
  start : UInt64,
  end : UInt64,
) -> Unit raise Unnumberable {
  let descendants = match range {
    Some((a, b)) => {
      if a >= b {
        return
      }
      let mut sum = 0
      for i in a..<b {
        sum += self.children[i].descendants()
      }
      sum
    }
    None => self.descendants
  }
  let space = end - start
  let mut stride = space / (2 * descendants).to_uint64()
  if stride == 0 {
    stride = space / self.descendants.to_uint64()
    if stride == 0 {
      raise Unnumberable
    }
  }
  let mut start = start
  if range is None {
    let e = start + stride
    owner.span = Span::from_number(id, SpanNumber((start + e) / 2))
    self.upper = end
    start = e
  }
  let (a, b) = match range {
    Some(r) => r
    None => (0, self.children.length())
  }
  for i in a..<b {
    let child = self.children[i]
    let e = start + child.descendants().to_uint64() * stride
    child.numberize(id, start, e)
    start = e
  }
}

///|
/// The number of descendants, including the node itself.
fn SyntaxNode::descendants(self : SyntaxNode) -> Int {
  match self.data.base() {
    Inner(inner, _) => inner.descendants
    _ => 1
  }
}

///|
/// Whether this is a leaf node.
pub fn SyntaxNode::is_leaf(self : SyntaxNode) -> Bool {
  self.data.base() is Leaf(_, _, _)
}

///|
/// Whether this is an inner node.
pub fn SyntaxNode::is_inner(self : SyntaxNode) -> Bool {
  self.data.base() is Inner(_, _)
}

///|
/// The node's children, mutably (empty for non-inner nodes).
///
/// The stored array: for a node that its caller owns (the parser's while it
/// builds, the reparser's copies).
fn SyntaxNode::children_mut(self : SyntaxNode) -> Array[SyntaxNode] {
  match self.inner_node() {
    Some(inner) => inner.children
    None => []
  }
}

///|
/// The upper bound of assigned numbers in this subtree.
fn SyntaxNode::upper(self : SyntaxNode) -> UInt64 {
  match self.inner_node() {
    Some(inner) => inner.upper
    None => self.span.number() + 1
  }
}

///|
/// Update this node after changes were made to one of its children.
///
/// Writes to this node: it must be the caller's copy
/// ([SyntaxNode::make_mut]).
fn SyntaxNode::update_parent(
  self : SyntaxNode,
  prev_len : Int,
  new_len : Int,
  prev_descendants : Int,
  new_descendants : Int,
) -> Unit {
  if self.inner_node() is Some(inner) {
    inner.len = inner.len + new_len - prev_len
    inner.descendants = inner.descendants + new_descendants - prev_descendants
    inner.diagnosis = Diagnosis::any(inner.children)
  }
}

///|
/// Replaces a range of children with a replacement and renumbers them.
///
/// Writes to this node, which must be the caller's copy
/// ([SyntaxNode::make_mut]), and to the nodes of `replacement`, which must
/// be the caller's too (they come from the parser). The children that stay
/// are not written to: where they have to be renumbered, copies take their
/// place.
///
/// May have changed this node and the replacement if it raises.
fn SyntaxNode::replace_children(
  self : SyntaxNode,
  from : Int,
  to : Int,
  replacement : Array[SyntaxNode],
) -> Unit raise Unnumberable {
  guard self.inner_node() is Some(inner) else { return }
  guard self.span.id() is Some(id) else { raise Unnumberable }
  let mut start = from
  let mut end = to
  let mut rstart = 0
  let mut rend = replacement.length()
  // Trim off common prefix.
  while start < end &&
        rstart < rend &&
        inner.children[start].spanless_eq(replacement[rstart]) {
    start += 1
    rstart += 1
  }
  // Trim off common suffix.
  while start < end &&
        rstart < rend &&
        inner.children[end - 1].spanless_eq(replacement[rend - 1]) {
    end -= 1
    rend -= 1
  }
  let repl = replacement[rstart:rend]
  let superseded = inner.children[start:end]
  inner.len = inner.len +
    repl.fold(init=0, (s, n) => s + n.len()) -
    superseded.fold(init=0, (s, n) => s + n.len())
  inner.descendants = inner.descendants +
    repl.fold(init=0, (s, n) => s + n.descendants()) -
    superseded.fold(init=0, (s, n) => s + n.descendants())
  let replaced = Diagnosis::any(repl)
  if !inner.diagnosis.either() || replaced.both() {
    inner.diagnosis = replaced
  } else {
    inner.diagnosis = replaced.or(
      Diagnosis::any(inner.children[:start]).or(
        Diagnosis::any(inner.children[end:]),
      ),
    )
  }
  let repl = repl.to_owned()
  let tail = inner.children[end:].to_owned()
  inner.children.truncate(start)
  inner.children.append(repl)
  inner.children.append(tail)
  end = start + repl.length()

  // Renumber the new children, taking exponentially more children into
  // account until it works.
  let mut left = 0
  let mut right = 0
  let max_left = start
  let max_right = inner.children.length() - end
  // Not upstream: the children that this call may write to. Those of
  // `start..end` are the replacement, which the caller made. The others are
  // of the tree before the edit and may be held by somebody: before they
  // are renumbered they are replaced by copies of their whole subtrees
  // (`numberize` writes the span of every node and the upper bound of every
  // inner node). Upstream reaches them through `inner_and_span_mut`
  // (node.rs:524 from the loop at :712), whose `Arc::make_mut` copies a
  // shared record on the way down.
  let mut owned_start = start
  let mut owned_end = end
  while true {
    let rs = start - left
    let re = end + right
    for i in rs..<owned_start {
      inner.children[i] = inner.children[i].deep_clone()
    }
    for i in owned_end..<re {
      inner.children[i] = inner.children[i].deep_clone()
    }
    owned_start = rs
    owned_end = re
    let start_number = if rs == 0 {
      self.span.number() + 1
    } else {
      inner.children[rs - 1].upper()
    }
    let end_number = if re < inner.children.length() {
      inner.children[re].span.number()
    } else {
      inner.upper
    }
    let ok = try
      inner.numberize(self, id, Some((rs, re)), start_number, end_number)
    catch {
      Unnumberable => false
    } noraise {
      _ => true
    }
    if ok {
      return
    }
    if left == max_left && right == max_right {
      raise Unnumberable
    }
    left = @cmp.minimum(next_power_of_two(left + 1), max_left)
    right = @cmp.minimum(next_power_of_two(right + 1), max_right)
  }
}

///|
fn next_power_of_two(n : Int) -> Int {
  let mut p = 1
  while p < n {
    p *= 2
  }
  p
}

///|
/// Set a raw range span for each node, like upstream `synthesize_mapped`
/// with the identity mapper `RangeMapper::new(Some(0..len))` (the text is
/// the whole file `id`): every node receives the range span of its own
/// range and sub-ranges are kept.
///
/// Writes to every node of the tree: only for a tree that the caller made
/// and that nobody else holds (see the header of this file), never for one
/// that is or was in a [Source].
pub fn SyntaxNode::synthesize_ranges(self : SyntaxNode, id : FileId) -> Unit {
  self.synthesize_ranges_at(0, id)
}

///|
fn SyntaxNode::synthesize_ranges_at(
  self : SyntaxNode,
  offset : Int,
  id : FileId,
) -> Unit {
  let len = self.len()
  self.span = Span::from_range(id, offset, offset + len)
  let mut data = self.data
  while true {
    match data {
      Leaf(_, _, _) => break
      Inner(inner, _) => {
        inner.upper = self.span.number()
        let mut off = offset
        for child in inner.children {
          child.synthesize_ranges_at(off, id)
          off += child.len()
        }
        break
      }
      Error(_) => break
      Warning(w, _) => data = w.child
    }
  }
}

///|
/// Set a synthetic span for the node and all its descendants, and add hints
/// with the original indices to any syntax errors or warnings.
///
/// Writes to every node of the tree: only for a tree that the caller made
/// and that nobody else holds (see the header of this file), never for one
/// that is or was in a [Source].
pub fn SyntaxNode::synthesize(self : SyntaxNode, span : Span) -> Unit {
  self.synthesize_at(0, span)
}

///|
fn SyntaxNode::synthesize_at(
  self : SyntaxNode,
  offset : Int,
  span : Span,
) -> Unit {
  let len = self.len()
  self.span = span
  let at_hint = if len == 0 {
    "at index `\{offset}`"
  } else {
    "from index `\{offset}` to `\{offset + len}`"
  }
  let mut data = self.data
  while true {
    match data {
      Leaf(_, _, _) => break
      Inner(inner, _) => {
        inner.upper = span.number()
        let mut off = offset
        for child in inner.children {
          child.synthesize_at(off, span)
          off += child.len()
        }
        break
      }
      Error(err) => {
        for i in 0..<err.hints.length() {
          err.hints[i] = (err.hints[i].0, None)
        }
        err.hints.push((at_hint, None))
        break
      }
      Warning(w, _) => {
        w.sub_range = None
        for i in 0..<w.hints.length() {
          w.hints[i] = (w.hints[i].0, None)
        }
        w.hints.push((at_hint, None))
        data = w.child
      }
    }
  }
}

///|
/// The sink of [SyntaxNode::hash_into] (not upstream: this package cannot
/// name the hasher of `typst_utils::hash128`, which lives in `library`).
pub(open) trait NodeHasher {
  fn write_u64(Self, UInt64) -> Unit
  fn write_str(Self, StringView) -> Unit
}

///|
/// Feeds what upstream's derived `Hash for SyntaxNode` covers into `state`:
/// the node data (kind, text or children, lengths, diagnostics and
/// numbering bounds, error and warning messages with their hints) and the
/// span, recursively.
pub fn[H : NodeHasher] SyntaxNode::hash_into(
  self : SyntaxNode,
  state : H,
) -> Unit {
  hash_node(self.data, state)
  state.write_u64(self.span.0)
}

///|
fn[H : NodeHasher] hash_node(data : Node, state : H) -> Unit {
  match data {
    // The length is derived from the text.
    Leaf(text, kind, _) => {
      state.write_u64(0)
      state.write_str(text)
      state.write_u64(kind.index().to_uint64())
    }
    Inner(inner, kind) => {
      state.write_u64(1)
      state.write_u64(inner.len.to_uint64())
      state.write_u64(inner.descendants.to_uint64())
      state.write_u64(
        (if inner.diagnosis.errors { 1UL } else { 0UL }) |
        (if inner.diagnosis.warnings { 2UL } else { 0UL }),
      )
      state.write_u64(inner.upper)
      state.write_u64(inner.children.length().to_uint64())
      for child in inner.children {
        child.hash_into(state)
      }
      state.write_u64(kind.index().to_uint64())
    }
    Error(err) => {
      state.write_u64(2)
      state.write_str(err.text)
      state.write_str(err.message)
      hash_hints(err.hints, state)
    }
    Warning(warning, kind) => {
      state.write_u64(3)
      hash_node(warning.child, state)
      hash_sub_range(warning.sub_range, state)
      state.write_str(warning.message)
      hash_hints(warning.hints, state)
      state.write_u64(kind.index().to_uint64())
    }
  }
}

///|
fn[H : NodeHasher] hash_hints(
  hints : Array[(String, SubRange?)],
  state : H,
) -> Unit {
  state.write_u64(hints.length().to_uint64())
  for hint in hints {
    state.write_str(hint.0)
    hash_sub_range(hint.1, state)
  }
}

///|
fn[H : NodeHasher] hash_sub_range(range : SubRange?, state : H) -> Unit {
  match range {
    None => state.write_u64(0)
    Some(range) => {
      state.write_u64(1)
      state.write_u64(range.start.to_uint64())
      state.write_u64(range.end.to_uint64())
    }
  }
}
