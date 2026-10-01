///|
/// A node in the untyped syntax tree.
///
/// Unlike upstream (which uses copy-on-write `Arc`s), nodes are mutable
/// objects. The parser only ever mutates nodes it exclusively owns; use
/// [SyntaxNode::deep_clone] whenever a node must be duplicated.
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
  loop self {
    Warning(w, _) => continue w.child
    other => other
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
  let text = text.to_string()
  { data: Leaf(text, kind, utf8_len(text)), span: Span::detached(), }
}

///|
/// Create a new inner node with children. The children array is copied, so
/// the caller keeps no alias into the new node.
pub fn SyntaxNode::inner(
  kind : SyntaxKind,
  children : ArrayView[SyntaxNode],
) -> SyntaxNode {
  SyntaxNode::inner_owned(kind, children.to_array())
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
  let text = text.to_string()
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
  let repl = repl.to_array()
  let tail = inner.children[end:].to_array()
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
  while true {
    let rs = start - left
    let re = end + right
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
/// Set a synthetic span for the node and all its descendants, and add hints
/// with the original indices to any syntax errors or warnings.
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
