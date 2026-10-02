// A located variant of `parse` for typed deserializers built on top of the
// data (like hayagriva's `from_yaml_str`): every node carries the mark and
// the `serde_yaml` path that `serde_yaml::error::fix_mark` would attach to an
// error raised while deserializing it.

///|
/// A deserialized YAML node with its position.
pub(all) struct YamlNode {
  /// The data as Typst's `ValueVisitor` would observe it (children included).
  data : @serde.Data
  /// The location of the node's first event.
  location : Location
  /// The node's `serde_yaml` path (e.g. `foo.bar[0]`; `.` for the root).
  path : String
  /// The child nodes: sequence items or mapping values, in order.
  children : Array[YamlNode]
  /// Whether a parse error occurred inside this sequence or mapping, so not
  /// all of its children are present. Deserializers that read past the
  /// present children must report the document's parse error then.
  incomplete : Bool
  /// Whether the node is an empty document or an empty plain scalar, which
  /// `serde_yaml`'s `deserialize_map`/`deserialize_struct` accept as an
  /// empty mapping.
  empty : Bool
}

///|
/// Format an error raised by a custom deserializer at this node (upstream
/// `serde::de::Error::custom` followed by `fix_mark`).
pub fn YamlNode::error(self : YamlNode, msg : String) -> YamlError {
  let mark : Mark = {
    index: self.location.index,
    line: self.location.line - 1,
    column: self.location.column - 1,
  }
  YError(Message(msg, Some((mark, self.path)))).to_public()
}

///|
/// The result of [parse_nodes]: the (possibly partial) tree and the parse
/// error that ended the document, if any.
pub(all) struct YamlNodes {
  root : YamlNode
  /// A syntax error after which the remaining events are missing. Typed
  /// deserializers report it only once they are done with the tree (or when
  /// they read into an incomplete node), like `serde_yaml::from_str`.
  error : YamlError?
}

///|
/// Parses YAML into located nodes (see [YamlNode]). Errors that serde_yaml
/// raises independently of the target type (e.g. a document that does not
/// start) are raised; a syntax error inside the document is returned in
/// [YamlNodes::error] alongside the partial tree.
pub fn parse_nodes(input : Bytes) -> YamlNodes raise YamlError {
  let loader : Loader = { parser: Some(Parser::new(input)), document_count: 0, }
  let document = match loader.next_document() {
    Some(document) => document
    None => raise YError(EndOfStream).to_public()
  }
  let de : De = {
    document,
    pos: Ref(0),
    jumpcount: Ref(0),
    path: Root,
    remaining_depth: 128,
  }
  let root = de.build_node() catch { err => raise err.to_public() }
  let error = match document.error {
    Some(parse_error) => Some(YError(parse_error).to_public())
    None =>
      if loader.next_document() is None {
        None
      } else {
        Some(YError(MoreThanOneDocument).to_public())
      }
  }
  { root, error, }
}

///|
/// Build a node from the next event. Never raises the document's parse
/// error; truncated containers are marked incomplete instead.
fn De::build_node(self : De) -> YamlNode raise YError {
  guard self.pos.val < self.document.events.length() else {
    // Only reachable for an empty, broken document.
    return {
      data: None,
      location: zero_mark.to_location(),
      path: self.path.to_string(),
      children: [],
      incomplete: true,
      empty: true,
    }
  }
  let (next, mark) = self.next_event_mark()
  let location = mark.to_location()
  let path = self.path.to_string()
  match next {
    DAlias(id) => {
      let node = self.jump(id).build_node()
      { ..node, location, path, }
    }
    DScalar(tag~, value~, style~) => {
      let data = visit_scalar(tag, value, style) catch {
        err => raise fix_mark(err, mark, self.path)
      }
      let empty = value.length() == 0 && style == Plain
      { data, location, path, children: [], incomplete: false, empty, }
    }
    DSequenceStart(_) => {
      let previous_depth = self.enter(mark)
      let items = []
      let children = []
      let mut incomplete = false
      while true {
        if self.pos.val >= self.document.events.length() {
          incomplete = true
          break
        }
        match self.peek_event_mark() {
          (DSequenceEnd, _) | (Void, _) => {
            self.pos.val += 1
            break
          }
          _ => ()
        }
        let element_de = self.child(Seq(self.path, items.length()))
        let child = element_de.build_node()
        items.push(child.data)
        children.push(child)
        if child.incomplete {
          incomplete = true
          break
        }
      }
      self.remaining_depth = previous_depth
      { data: Seq(items), location, path, children, incomplete, empty: false, }
    }
    DMappingStart(_) => {
      let previous_depth = self.enter(mark)
      let entries = []
      let children = []
      let mut incomplete = false
      while true {
        if self.pos.val >= self.document.events.length() {
          incomplete = true
          break
        }
        let key_bytes = match self.peek_event_mark() {
          (DMappingEnd, _) | (Void, _) => {
            self.pos.val += 1
            break
          }
          (DScalar(value~, ..), _) => Some(value)
          _ => None
        }
        let key = self.deserialize_str()
        let child_path = match key_bytes.bind(from_utf8) {
          Some(key) => MapKey(self.path, key)
          None => Unknown(self.path)
        }
        if self.pos.val >= self.document.events.length() {
          incomplete = true
          break
        }
        let child = self.child(child_path).build_node()
        entries.push((key, child.data))
        children.push(child)
        if child.incomplete {
          incomplete = true
          break
        }
      }
      self.remaining_depth = previous_depth
      {
        data: Map(entries),
        location,
        path,
        children,
        incomplete,
        empty: false,
      }
    }
    Void =>
      {
        data: None,
        location,
        path,
        children: [],
        incomplete: false,
        empty: true,
      }
    DSequenceEnd => abort("unexpected end of sequence")
    DMappingEnd => abort("unexpected end of mapping")
  }
}
