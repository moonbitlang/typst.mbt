// Port of `roxmltree` 0.21.1 `src/parse.rs`.

///|
/// A list of all possible errors (upstream `roxmltree::Error`).
pub(all) suberror XmlError {
  /// The `xmlns:xml` attribute must have an <http://www.w3.org/XML/1998/namespace> URI.
  InvalidXmlPrefixUri(TextPos)
  /// Only the `xmlns:xml` attribute can have the <http://www.w3.org/XML/1998/namespace> URI.
  UnexpectedXmlUri(TextPos)
  /// The <http://www.w3.org/2000/xmlns/> URI must not be declared.
  UnexpectedXmlnsUri(TextPos)
  /// `xmlns` can't be used as an element prefix.
  InvalidElementNamePrefix(TextPos)
  /// A namespace was already defined on this element.
  DuplicatedNamespace(String, TextPos)
  /// An unknown namespace.
  ///
  /// Indicates that an element or an attribute has an unknown qualified name
  /// prefix. The first value is a prefix.
  UnknownNamespace(String, TextPos)
  /// Incorrect tree structure.
  ///
  /// expected, actual, position
  UnexpectedCloseTag(String, String, TextPos)
  /// Entity value starts with a close tag.
  ///
  /// Example:
  /// ```xml
  /// <!DOCTYPE test [ <!ENTITY p '</p>'> ]>
  /// <root>&p;</root>
  /// ```
  UnexpectedEntityCloseTag(TextPos)
  /// A reference to an entity that was not defined in the DTD.
  UnknownEntityReference(String, TextPos)
  /// A malformed entity reference.
  ///
  /// A `&` character inside an attribute value or text indicates an entity
  /// reference. Otherwise, the document is not well-formed.
  MalformedEntityReference(TextPos)
  /// A possible entity reference loop.
  ///
  /// The current depth limit is 10. The max number of references per
  /// reference is 255.
  EntityReferenceLoop(TextPos)
  /// Attribute value cannot have a `<` character.
  InvalidAttributeValue(TextPos)
  /// An element has a duplicated attributes.
  ///
  /// This also includes namespaces resolving.
  /// So an element like this will lead to an error.
  /// ```xml
  /// <e xmlns:n1='http://www.w3.org' xmlns:n2='http://www.w3.org' n1:a='b1' n2:a='b2'/>
  /// ```
  DuplicatedAttribute(String, TextPos)
  /// The XML document must have at least one element.
  NoRootNode
  /// The root node was opened but never closed.
  UnclosedRootNode
  /// An XML document can have only one XML declaration
  /// and it must be at the start of the document.
  UnexpectedDeclaration(TextPos)
  /// An XML with DTD detected.
  ///
  /// This error will be emitted only when `ParsingOptions::allow_dtd` is set
  /// to `false`.
  DtdDetected
  /// Indicates that the `ParsingOptions::nodes_limit` was reached.
  NodesLimitReached
  /// Indicates that too many attributes were parsed.
  AttributesLimitReached
  /// Indicates that too many namespaces were parsed.
  NamespacesLimitReached
  /// An invalid name.
  InvalidName(TextPos)
  /// A non-XML character has occurred.
  ///
  /// Valid characters are: <https://www.w3.org/TR/xml/#char32>
  NonXmlChar(Char, TextPos)
  /// An invalid/unexpected character.
  ///
  /// expected, actual, position
  InvalidChar(Byte, Byte, TextPos)
  /// An invalid/unexpected character.
  ///
  /// expected, actual, position
  InvalidChar2(String, Byte, TextPos)
  /// An unexpected string.
  ///
  /// Contains what string was expected.
  InvalidString(String, TextPos)
  /// An invalid ExternalID in the DTD.
  InvalidExternalID(TextPos)
  /// The given entity resolved yielded an errror.
  EntityResolver(TextPos, String)
  /// A comment cannot contain `--` or end with `-`.
  InvalidComment(TextPos)
  /// A Character Data node contains an invalid data.
  ///
  /// Currently, only `]]>` is not allowed.
  InvalidCharacterData(TextPos)
  /// An unknown token.
  UnknownToken(TextPos)
  /// The steam ended earlier than we expected.
  ///
  /// Should only appear on invalid input data.
  UnexpectedEndOfStream
}

///|
/// Returns the error position (upstream `Error::pos`).
pub fn XmlError::pos(self : XmlError) -> TextPos {
  match self {
    InvalidXmlPrefixUri(pos) => pos
    UnexpectedXmlUri(pos) => pos
    UnexpectedXmlnsUri(pos) => pos
    InvalidElementNamePrefix(pos) => pos
    DuplicatedNamespace(_, pos) => pos
    UnknownNamespace(_, pos) => pos
    UnexpectedCloseTag(_, _, pos) => pos
    UnexpectedEntityCloseTag(pos) => pos
    UnknownEntityReference(_, pos) => pos
    MalformedEntityReference(pos) => pos
    EntityReferenceLoop(pos) => pos
    InvalidAttributeValue(pos) => pos
    DuplicatedAttribute(_, pos) => pos
    NoRootNode => TextPos::new(1, 1)
    UnclosedRootNode => TextPos::new(1, 1)
    UnexpectedDeclaration(pos) => pos
    DtdDetected => TextPos::new(1, 1)
    NodesLimitReached => TextPos::new(1, 1)
    AttributesLimitReached => TextPos::new(1, 1)
    NamespacesLimitReached => TextPos::new(1, 1)
    InvalidName(pos) => pos
    NonXmlChar(_, pos) => pos
    InvalidChar(_, _, pos) => pos
    InvalidChar2(_, _, pos) => pos
    InvalidString(_, pos) => pos
    InvalidExternalID(pos) => pos
    EntityResolver(pos, _) => pos
    InvalidComment(pos) => pos
    InvalidCharacterData(pos) => pos
    UnknownToken(pos) => pos
    UnexpectedEndOfStream => TextPos::new(1, 1)
  }
}

///|
/// `*byte as char`: interprets a byte as a Latin-1 char.
fn byte_as_char(b : Byte) -> Char {
  b.to_int().unsafe_to_char()
}

///|
/// The error message (upstream `impl Display for Error`).
pub fn XmlError::to_string(self : XmlError) -> String {
  match self {
    InvalidXmlPrefixUri(pos) =>
      "'xml' namespace prefix mapped to wrong URI at \{pos}"
    UnexpectedXmlUri(pos) =>
      "the 'xml' namespace URI is used for not 'xml' prefix at \{pos}"
    UnexpectedXmlnsUri(pos) =>
      "the 'xmlns' URI is used at \{pos}, but it must not be declared"
    InvalidElementNamePrefix(pos) =>
      "the 'xmlns' prefix is used at \{pos}, but it must not be"
    DuplicatedNamespace(name, pos) =>
      "namespace '\{name}' at \{pos} is already defined"
    UnknownNamespace(name, pos) =>
      "an unknown namespace prefix '\{name}' at \{pos}"
    UnexpectedCloseTag(expected, actual, pos) =>
      "expected '\{expected}' tag, not '\{actual}' at \{pos}"
    UnexpectedEntityCloseTag(pos) => "unexpected close tag at \{pos}"
    MalformedEntityReference(pos) => "malformed entity reference at \{pos}"
    UnknownEntityReference(name, pos) =>
      "unknown entity reference '\{name}' at \{pos}"
    EntityReferenceLoop(pos) =>
      "a possible entity reference loop is detected at \{pos}"
    InvalidAttributeValue(pos) => "unescaped '<' found at \{pos}"
    DuplicatedAttribute(name, pos) =>
      "attribute '\{name}' at \{pos} is already defined"
    NoRootNode => "the document does not have a root node"
    UnclosedRootNode => "the root node was opened but never closed"
    UnexpectedDeclaration(pos) => "unexpected XML declaration at \{pos}"
    DtdDetected => "XML with DTD detected"
    NodesLimitReached => "nodes limit reached"
    AttributesLimitReached => "more than 2^32 attributes were parsed"
    NamespacesLimitReached => "more than 2^16 unique namespaces were parsed"
    InvalidName(pos) => "invalid name token at \{pos}"
    NonXmlChar(c, pos) =>
      "a non-XML character \{@unicode.rust_debug_char(c)} found at \{pos}"
    InvalidChar(expected, actual, pos) => {
      let expected = byte_as_char(expected)
      let actual = byte_as_char(actual)
      "expected '\{expected}' not '\{actual}' at \{pos}"
    }
    InvalidChar2(expected, actual, pos) => {
      let actual = byte_as_char(actual)
      "expected \{expected} not '\{actual}' at \{pos}"
    }
    InvalidString(expected, pos) => "expected '\{expected}' at \{pos}"
    InvalidExternalID(pos) => "invalid ExternalID at \{pos}"
    EntityResolver(pos, msg) => "entity resolver failed at \{pos}: \{msg}"
    InvalidComment(pos) => "comment at \{pos} contains '--'"
    InvalidCharacterData(pos) =>
      "']]>' at \{pos} is not allowed inside a character data"
    UnknownToken(pos) => "unknown token at \{pos}"
    UnexpectedEndOfStream => "unexpected end of stream"
  }
}

///|
pub impl Show for XmlError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Parsing options (upstream `ParsingOptions`).
///
/// The upstream `entity_resolver` option is not supported: external entities
/// are always discarded (like with the default `None` resolver).
pub(all) struct ParsingOptions {
  /// Allow DTD parsing.
  ///
  /// When set to `false`, XML with DTD will cause an error.
  /// Empty DTD block is not an error.
  ///
  /// Default: false
  allow_dtd : Bool
  /// Sets the maximum number of nodes to parse.
  ///
  /// Useful when dealing with random input to limit memory usage.
  ///
  /// Default: u32::MAX (no limit)
  nodes_limit : UInt
}

///|
pub fn ParsingOptions::default() -> ParsingOptions {
  { allow_dtd: false, nodes_limit: 0xFFFF_FFFFU, }
}

///|
priv struct TempAttributeData {
  prefix : String
  local_name : String
  value : String
  range : Range
  qname_len : Int
  eq_len : Int
}

///|
/// Parses the input XML string (upstream `Document::parse`).
///
/// This is a shorthand for
/// `Document::parse_with_options(data, ParsingOptions::default())`.
pub fn Document::parse(text : String) -> Document raise XmlError {
  Document::parse_with_options(text, ParsingOptions::default())
}

///|
/// Parses the input XML string using to selected options (upstream
/// `Document::parse_with_options`).
pub fn Document::parse_with_options(
  text : String,
  opt : ParsingOptions,
) -> Document raise XmlError {
  parse(@utf8.encode(text), opt)
}

///|
/// Parses UTF-8 encoded input XML (which must be valid UTF-8).
pub fn Document::parse_utf8_with_options(
  text : Bytes,
  opt : ParsingOptions,
) -> Document raise XmlError {
  parse(text, opt)
}

///|
priv struct Entity {
  name : String
  value : StrSpan
}

///|
priv struct TagNameSpan {
  prefix : String
  name : String
  pos : Int
  prefix_pos : Int
}

///|
fn TagNameSpan::new_null() -> TagNameSpan {
  { prefix: "", name: "", pos: 0, prefix_pos: 0, }
}

///|
/// An entity loop detector.
///
/// Limits:
/// - Entities depth is 10.
/// - Maximum number of entity references per entity reference is 255.
///
/// Basically, if a text or an attribute has an entity reference and this
/// reference has more than 10 nested references - this is an error.
///
/// And, if a text or an attribute has an entity reference and it references
/// more than 255 references - this is an error (billion laughs attack).
priv struct LoopDetector {
  /// References depth.
  mut depth : Int
  /// Number of references resolved by the root reference.
  mut references : Int
}

///|
fn LoopDetector::inc_depth(
  self : LoopDetector,
  stream : Stream,
) -> Unit raise XmlError {
  if self.depth < 10 {
    self.depth += 1
  } else {
    raise EntityReferenceLoop(stream.gen_text_pos())
  }
}

///|
fn LoopDetector::dec_depth(self : LoopDetector) -> Unit {
  if self.depth > 0 {
    self.depth -= 1
  }
  // Reset references count after reaching zero depth.
  if self.depth == 0 {
    self.references = 0
  }
}

///|
fn LoopDetector::inc_references(
  self : LoopDetector,
  stream : Stream,
) -> Unit raise XmlError {
  if self.depth == 0 {
    // Allow infinite amount of references at zero depth.
    ()
  } else {
    if self.references == 255 {
      raise EntityReferenceLoop(stream.gen_text_pos())
    }
    self.references += 1
  }
}

///|
priv struct Context {
  opt : ParsingOptions
  mut namespace_start_idx : Int
  current_attributes : Array[TempAttributeData]
  awaiting_subtree : Array[Int]
  parent_prefixes : Array[String]
  entities : Array[Entity]
  after_text : Array[String]
  mut parent_id : Int
  mut tag_name : TagNameSpan
  loop_detector : LoopDetector
  doc : Document
}

///|
fn Context::append_node(
  self : Context,
  kind : NodeKind,
  range : Range,
) -> Int raise XmlError {
  if self.doc.nodes.length().reinterpret_as_uint() >= self.opt.nodes_limit {
    raise NodesLimitReached
  }
  let new_child_id = self.doc.nodes.length()
  let appending_element = kind is Element(_)
  self.doc.nodes.push({
    parent: Some(self.parent_id),
    prev_sibling: None,
    next_subtree: None,
    last_child: None,
    kind,
    range_start: range.start,
    range_end: range.end,
  })
  let last_child_id = self.doc.nodes[self.parent_id].last_child
  self.doc.nodes[new_child_id].prev_sibling = last_child_id
  self.doc.nodes[self.parent_id].last_child = Some(new_child_id)
  for id in self.awaiting_subtree {
    self.doc.nodes[id].next_subtree = Some(new_child_id)
  }
  self.awaiting_subtree.clear()
  if !appending_element {
    self.awaiting_subtree.push(self.doc.nodes.length() - 1)
  }
  new_child_id
}

///|
fn Context::append_text(
  self : Context,
  text : String,
  range : Range,
) -> Unit raise XmlError {
  if self.after_text.is_empty() {
    self.append_node(Text(text), range) |> ignore
  }
  self.after_text.push(text)
}

///|
fn Context::merge_text(self : Context) -> Unit {
  let node = self.doc.nodes[self.doc.nodes.length() - 1]
  guard node.kind is Text(_) else { abort("unreachable") }
  let buf = StringBuilder()
  for t in self.after_text {
    buf.write_string(t)
  }
  node.kind = Text(buf.to_string())
}

///|
fn Context::reset_after_text(self : Context) -> Unit {
  if self.after_text.is_empty() {
    return
  }
  if self.after_text.length() > 1 {
    self.merge_text()
  }
  self.after_text.clear()
}

///|
/// Upstream `parse::parse`.
fn parse(text : Bytes, opt : ParsingOptions) -> Document raise XmlError {
  // Init document.
  let doc : Document = {
    text,
    nodes: [],
    attributes: [],
    namespaces: Namespaces::new(),
  }

  // Add a root node.
  doc.nodes.push({
    parent: None,
    prev_sibling: None,
    next_subtree: None,
    last_child: None,
    kind: Root,
    range_start: 0,
    range_end: text.length(),
  })
  doc.namespaces.push_ns(Some(NS_XML_PREFIX), NS_XML_URI)
  let allow_dtd = opt.allow_dtd
  let ctx : Context = {
    opt,
    namespace_start_idx: 1,
    current_attributes: [],
    entities: [],
    awaiting_subtree: [],
    parent_prefixes: [""],
    after_text: [],
    parent_id: 0,
    tag_name: TagNameSpan::new_null(),
    loop_detector: { depth: 0, references: 0, },
    doc,
  }
  tokenize(text, allow_dtd, ctx)
  let doc = ctx.doc
  if !doc.root().children().iter().any(fn(n) { n.is_element() }) {
    raise NoRootNode
  }
  if ctx.parent_prefixes.length() > 1 {
    raise UnclosedRootNode
  }
  doc
}

///|
/// Upstream `impl XmlEvents for Context`: `token`.
fn Context::token(self : Context, token : Token) -> Unit raise XmlError {
  match token {
    ProcessingInstruction(target, value, range) => {
      self.reset_after_text()
      let pi = NodeKind::PI({ target, value, })
      self.append_node(pi, range) |> ignore
    }
    Comment(text, range) => {
      self.reset_after_text()
      self.append_node(Comment(text), range) |> ignore
    }
    EntityDeclaration(name, definition) =>
      self.entities.push({ name, value: definition, })
    ElementStart(prefix, local_name, start) => {
      self.reset_after_text()
      if prefix == XMLNS {
        let pos = self.doc.text_pos_at(start + 1)
        raise InvalidElementNamePrefix(pos)
      }
      self.tag_name = {
        prefix,
        name: local_name,
        pos: start,
        prefix_pos: start + 1,
      }
    }
    Attribute(range, qname_len, eq_len, prefix, local_name, value) =>
      process_attribute(
        range, qname_len, eq_len, prefix, local_name, value, self,
      )
    ElementEnd(end, range) => {
      self.reset_after_text()
      process_element(end, range, self)
    }
    Text(text, range) => process_text(text, range, self)
    Cdata(text, range) => process_cdata(text, range, self)
  }
}

///|
fn process_attribute(
  range : Range,
  qname_len : Int,
  eq_len : Int,
  prefix : String,
  local_name : String,
  value : StrSpan,
  ctx : Context,
) -> Unit raise XmlError {
  let value = normalize_attribute(value, ctx)
  if prefix == XMLNS {
    // The xmlns namespace MUST NOT be declared as the default namespace.
    if value == NS_XMLNS_URI {
      let pos = ctx.doc.text_pos_at(range.start)
      raise UnexpectedXmlnsUri(pos)
    }
    let is_xml_ns_uri = value == NS_XML_URI

    // The prefix 'xml' is by definition bound to the namespace name
    // http://www.w3.org/XML/1998/namespace.
    // It MUST NOT be bound to any other namespace name.
    if local_name == NS_XML_PREFIX {
      if !is_xml_ns_uri {
        let pos = ctx.doc.text_pos_at(range.start)
        raise InvalidXmlPrefixUri(pos)
      }
    } else if is_xml_ns_uri {
      // The xml namespace MUST NOT be bound to a non-xml prefix.
      let pos = ctx.doc.text_pos_at(range.start)
      raise UnexpectedXmlUri(pos)
    }

    // Check for duplicated namespaces.
    if ctx.doc.namespaces.exists(ctx.namespace_start_idx, Some(local_name)) {
      let pos = ctx.doc.text_pos_at(range.start)
      raise DuplicatedNamespace(local_name, pos)
    }

    // Xml namespace should not be added to the namespaces.
    if !is_xml_ns_uri {
      ctx.doc.namespaces.push_ns(Some(local_name), value)
    }
  } else if local_name == XMLNS {
    // The xml namespace MUST NOT be declared as the default namespace.
    if value == NS_XML_URI {
      let pos = ctx.doc.text_pos_at(range.start)
      raise UnexpectedXmlUri(pos)
    }

    // The xmlns namespace MUST NOT be declared as the default namespace.
    if value == NS_XMLNS_URI {
      let pos = ctx.doc.text_pos_at(range.start)
      raise UnexpectedXmlnsUri(pos)
    }
    ctx.doc.namespaces.push_ns(None, value)
  } else {
    ctx.current_attributes.push({
      prefix,
      local_name,
      value,
      range,
      qname_len,
      eq_len,
    })
  }
}

///|
fn process_element(
  end_token : ElementEnd,
  token_range : Range,
  ctx : Context,
) -> Unit raise XmlError {
  if ctx.tag_name.name.is_empty() {
    // May occur in XML like this:
    // <!DOCTYPE test [ <!ENTITY p '</p>'> ]>
    // <root>&p;</root>
    if end_token is Close(_, _) {
      raise UnexpectedEntityCloseTag(ctx.doc.text_pos_at(token_range.start))
    } else {
      abort("should be already checked by the tokenizer")
    }
  }
  let namespaces = ctx.resolve_namespaces()
  ctx.namespace_start_idx = ctx.doc.namespaces.tree_order.length()
  let attributes = resolve_attributes(namespaces, ctx)
  match end_token {
    Empty => {
      let tag_ns_idx = get_ns_idx_by_prefix(
        namespaces,
        ctx.tag_name.prefix_pos,
        ctx.tag_name.prefix,
        ctx.doc,
      )
      let new_element_id = ctx.append_node(
        Element(
          tag_name={ namespace_idx: tag_ns_idx, local_name: ctx.tag_name.name, },
          attributes~,
          namespaces~,
        ),
        { start: ctx.tag_name.pos, end: token_range.end, },
      )
      ctx.awaiting_subtree.push(new_element_id)
    }
    Close(prefix, local_name) => {
      let parent_node = ctx.doc.nodes[ctx.parent_id]
      // should never panic as we start with the single prefix of the
      // root node and always push another one when changing the parent
      let parent_prefix = ctx.parent_prefixes[ctx.parent_prefixes.length() - 1]
      parent_node.range_end = token_range.end
      if parent_node.kind is Element(tag_name~, ..) {
        if prefix != parent_prefix || local_name != tag_name.local_name {
          raise UnexpectedCloseTag(
            gen_qname_string(parent_prefix, tag_name.local_name),
            gen_qname_string(prefix, local_name),
            ctx.doc.text_pos_at(token_range.start),
          )
        }
      }
      ctx.awaiting_subtree.push(ctx.parent_id)
      match parent_node.parent {
        Some(id) => {
          ctx.parent_id = id
          ctx.parent_prefixes.pop() |> ignore
        }
        None =>
          // May occur in XML like this:
          // <!DOCTYPE test [ <!ENTITY p '<p></p></p>'> ]>
          // <p>&p;&p;
          raise UnexpectedEntityCloseTag(ctx.doc.text_pos_at(token_range.start))
      }
    }
    Open => {
      let tag_ns_idx = get_ns_idx_by_prefix(
        namespaces,
        ctx.tag_name.prefix_pos,
        ctx.tag_name.prefix,
        ctx.doc,
      )
      ctx.parent_id = ctx.append_node(
        Element(
          tag_name={ namespace_idx: tag_ns_idx, local_name: ctx.tag_name.name, },
          attributes~,
          namespaces~,
        ),
        { start: ctx.tag_name.pos, end: token_range.end, },
      )
      ctx.parent_prefixes.push(ctx.tag_name.prefix)
    }
  }
}

///|
fn Context::resolve_namespaces(self : Context) -> ShortRange {
  if self.doc.nodes[self.parent_id].kind is Element(namespaces~, ..) {
    let parent_ns = namespaces
    if self.namespace_start_idx == self.doc.namespaces.tree_order.length() {
      return parent_ns
    }
    for i in parent_ns.start..<parent_ns.end {
      let name = self.doc.namespaces.get(self.doc.namespaces.tree_order[i]).name
      if !self.doc.namespaces.exists(self.namespace_start_idx, name) {
        self.doc.namespaces.push_ref(i)
      }
    }
  }
  {
    start: self.namespace_start_idx,
    end: self.doc.namespaces.tree_order.length(),
  }
}

///|
fn resolve_attributes(
  namespaces : ShortRange,
  ctx : Context,
) -> ShortRange raise XmlError {
  if ctx.current_attributes.is_empty() {
    return { start: 0, end: 0, }
  }
  if ctx.doc.attributes.length().to_int64() +
    ctx.current_attributes.length().to_int64() >=
    0xFFFF_FFFFL {
    raise AttributesLimitReached
  }
  let start_idx = ctx.doc.attributes.length()
  let current = ctx.current_attributes.copy()
  ctx.current_attributes.clear()
  for attr in current {
    let namespace_idx = if attr.prefix == NS_XML_PREFIX {
      // The prefix 'xml' is by definition bound to the namespace name
      // http://www.w3.org/XML/1998/namespace. This namespace is added
      // to the document on creation and is always element 0.
      Some(0)
    } else if attr.prefix.is_empty() {
      // 'The namespace name for an unprefixed attribute name
      // always has no value.'
      None
    } else {
      get_ns_idx_by_prefix(namespaces, attr.range.start, attr.prefix, ctx.doc)
    }
    let attr_name : ExpandedNameIndexed = {
      namespace_idx,
      local_name: attr.local_name,
    }

    // Check for duplicated attributes.
    let expanded = attr_name.as_expanded_name(ctx.doc)
    for i in start_idx..<ctx.doc.attributes.length() {
      if ctx.doc.attributes[i].name.as_expanded_name(ctx.doc) == expanded {
        let pos = ctx.doc.text_pos_at(attr.range.start)
        raise DuplicatedAttribute(attr.local_name, pos)
      }
    }
    ctx.doc.attributes.push({
      name: attr_name,
      value: attr.value,
      range_start: attr.range.start,
      range_end: attr.range.end,
      qname_len: attr.qname_len,
      eq_len: attr.eq_len,
    })
  }
  { start: start_idx, end: ctx.doc.attributes.length(), }
}

///|
fn process_text(
  text : String,
  range : Range,
  ctx : Context,
) -> Unit raise XmlError {
  // Add text as is if it has only valid characters.
  if !text.contains_char('&') && !text.contains_char('\r') {
    ctx.append_text(text, range)
    return
  }
  let text_buffer = TextBuffer::new()
  let mut is_as_is = false // TODO: explain
  let stream = Stream::from_substr(ctx.doc.text, range)
  while !stream.at_end() {
    match parse_next_chunk(stream, ctx.entities) {
      Byte(c) =>
        if is_as_is {
          text_buffer.push_raw(c)
          is_as_is = false
        } else {
          text_buffer.push_from_text(c, stream.at_end())
        }
      Char(c) =>
        for b in char_to_bytes(c) {
          if ctx.loop_detector.depth > 0 {
            text_buffer.push_from_text(b, stream.at_end())
          } else {
            // Characters not from entity should be added as is.
            // Not sure why... At least `lxml` produces the same result.
            text_buffer.push_raw(b)
            is_as_is = true
          }
        }
      Text(fragment) => {
        is_as_is = false
        if !text_buffer.is_empty() {
          ctx.append_text(text_buffer.finish(), range)
        }
        ctx.loop_detector.inc_references(stream)
        ctx.loop_detector.inc_depth(stream)
        let stream = Stream::from_substr(ctx.doc.text, {
          start: fragment.start,
          end: fragment.end,
        })
        let prev_tag_name = ctx.tag_name
        ctx.tag_name = TagNameSpan::new_null()
        parse_content(stream, ctx)
        ctx.tag_name = prev_tag_name
        text_buffer.clear()
        ctx.loop_detector.dec_depth()
      }
    }
  }
  if !text_buffer.is_empty() {
    ctx.append_text(text_buffer.finish(), range)
  }
}

///|
/// While the whole purpose of CDATA is to indicate to an XML library that
/// this text has to be stored as is, carriage return (`\r`) is still has to
/// be replaced with `\n`.
fn process_cdata(
  text : String,
  range : Range,
  ctx : Context,
) -> Unit raise XmlError {
  // Add text as is if it has only valid characters.
  if !text.contains_char('\r') {
    ctx.append_text(text, range)
    return
  }
  let buf = StringBuilder()
  let mut skip_lf = false
  for c in text {
    if skip_lf {
      skip_lf = false
      if c == '\n' {
        continue
      }
    }
    if c == '\r' {
      buf.write_char('\n')
      skip_lf = true
    } else {
      buf.write_char(c)
    }
  }
  ctx.append_text(buf.to_string(), range)
}

///|
priv enum NextChunk {
  Byte(Byte)
  Char(Char)
  Text(StrSpan)
}

///|
fn parse_next_chunk(
  stream : Stream,
  entities : Array[Entity],
) -> NextChunk raise XmlError {
  let c = stream.curr_byte_unchecked()

  // Check for character/entity references.
  if c == b'&' {
    let start = stream.pos
    match stream.consume_reference() {
      Some(Char(ch)) => Char(ch)
      Some(Entity(name)) =>
        match entities.search_by(fn(e) { e.name == name }) {
          Some(i) => Text(entities[i].value)
          None => {
            let pos = stream.gen_text_pos_from(start)
            raise UnknownEntityReference(name, pos)
          }
        }
      None => {
        let pos = stream.gen_text_pos_from(start)
        raise MalformedEntityReference(pos)
      }
    }
  } else {
    stream.advance(1)
    Byte(c)
  }
}

///|
/// https://www.w3.org/TR/REC-xml/#AVNormalize
fn normalize_attribute(text : StrSpan, ctx : Context) -> String raise XmlError {
  // We assume that `&` indicates an entity or a character reference.
  // But in rare cases it can be just an another character.
  let mut needs = false
  for i in text.start..<text.end {
    let b = ctx.doc.text[i]
    if b == b'&' || b == b'\t' || b == b'\n' || b == b'\r' {
      needs = true
      break
    }
  }
  if needs {
    let text_buffer = TextBuffer::new()
    normalize_attribute_inner(text, text_buffer, ctx)
    text_buffer.finish()
  } else {
    slice_str(ctx.doc.text, text.start, text.end)
  }
}

///|
/// Upstream `_normalize_attribute`.
fn normalize_attribute_inner(
  text : StrSpan,
  buffer : TextBuffer,
  ctx : Context,
) -> Unit raise XmlError {
  let stream = Stream::from_substr(ctx.doc.text, {
    start: text.start,
    end: text.end,
  })
  while !stream.at_end() {
    let c = stream.curr_byte_unchecked()
    if c != b'&' {
      stream.advance(1)
      let next = if stream.at_end() {
        None
      } else {
        Some(stream.curr_byte_unchecked())
      }
      buffer.push_from_attr(c, next)
      continue
    }

    // Check for character/entity references.
    let start = stream.pos
    match stream.consume_reference() {
      Some(Char(ch)) =>
        for b in char_to_bytes(ch) {
          if ctx.loop_detector.depth > 0 {
            // Escaped `<` inside an ENTITY is an error.
            // Escaped `<` outside an ENTITY is ok.
            if b == b'<' {
              raise InvalidAttributeValue(stream.gen_text_pos_from(start))
            }
            buffer.push_from_attr(b, None)
          } else {
            // Characters not from entity should be added as is.
            // Not sure why... At least `lxml` produces the same results.
            buffer.push_raw(b)
          }
        }
      Some(Entity(name)) =>
        match ctx.entities.search_by(fn(e) { e.name == name }) {
          Some(i) => {
            let entity = ctx.entities[i]
            ctx.loop_detector.inc_references(stream)
            ctx.loop_detector.inc_depth(stream)
            normalize_attribute_inner(entity.value, buffer, ctx)
            ctx.loop_detector.dec_depth()
          }
          None => {
            let pos = stream.gen_text_pos_from(start)
            raise UnknownEntityReference(name, pos)
          }
        }
      None => {
        let pos = stream.gen_text_pos_from(start)
        raise MalformedEntityReference(pos)
      }
    }
  }
}

///|
fn get_ns_idx_by_prefix(
  namespaces : ShortRange,
  prefix_pos : Int,
  prefix : String,
  doc : Document,
) -> Int? raise XmlError {
  // Prefix CAN be empty when the default namespace was defined.
  //
  // Example:
  // <e xmlns='http://www.w3.org'/>
  let prefix_opt = if prefix.is_empty() { None } else { Some(prefix) }
  for i in namespaces.start..<namespaces.end {
    let idx = doc.namespaces.tree_order[i]
    if doc.namespaces.get(idx).name == prefix_opt {
      return Some(idx)
    }
  }
  if !prefix.is_empty() {
    // If an URI was not found and prefix IS NOT empty than
    // we have an unknown namespace.
    //
    // Example:
    // <e random:a='b'/>
    let pos = doc.text_pos_at(prefix_pos)
    raise UnknownNamespace(prefix, pos)
  } else {
    // If an URI was not found and prefix IS empty than
    // an element or an attribute doesn't have a namespace.
    //
    // Example:
    // <e a='b'/>
    None
  }
}

///|
fn gen_qname_string(prefix : String, local_name : String) -> String {
  if prefix.is_empty() {
    local_name
  } else {
    "\{prefix}:\{local_name}"
  }
}

///|
/// Upstream `CharToBytes`: the UTF-8 bytes of a char.
fn char_to_bytes(c : Char) -> Array[Byte] {
  let n = c.to_int()
  if n < 0x80 {
    [n.to_byte()]
  } else if n < 0x800 {
    [(0xC0 | (n >> 6)).to_byte(), (0x80 | (n & 0x3F)).to_byte()]
  } else if n < 0x10000 {
    [
      (0xE0 | (n >> 12)).to_byte(),
      (0x80 | ((n >> 6) & 0x3F)).to_byte(),
      (0x80 | (n & 0x3F)).to_byte(),
    ]
  } else {
    [
      (0xF0 | (n >> 18)).to_byte(),
      (0x80 | ((n >> 12) & 0x3F)).to_byte(),
      (0x80 | ((n >> 6) & 0x3F)).to_byte(),
      (0x80 | (n & 0x3F)).to_byte(),
    ]
  }
}

///|
priv struct TextBuffer {
  buffer : Array[Byte]
}

///|
fn TextBuffer::new() -> TextBuffer {
  { buffer: [], }
}

///|
fn TextBuffer::push_raw(self : TextBuffer, c : Byte) -> Unit {
  self.buffer.push(c)
}

///|
fn TextBuffer::push_from_attr(
  self : TextBuffer,
  current : Byte,
  next : Byte?,
) -> Unit {
  // \r in \r\n should be ignored.
  if current == b'\r' && next == Some(b'\n') {
    return
  }

  // \n, \r and \t should be converted into spaces.
  let current = match current {
    b'\n' | b'\r' | b'\t' => b' '
    _ => current
  }
  self.buffer.push(current)
}

///|
/// Translate \r\n and any \r that is not followed by \n into a single \n
/// character.
///
/// https://www.w3.org/TR/xml/#sec-line-ends
fn TextBuffer::push_from_text(
  self : TextBuffer,
  c : Byte,
  at_end : Bool,
) -> Unit {
  let len = self.buffer.length()
  if len > 0 && self.buffer[len - 1] == b'\r' {
    self.buffer[len - 1] = b'\n'
    if at_end && c == b'\r' {
      self.buffer.push(b'\n')
    } else if c != b'\n' {
      self.buffer.push(c)
    }
  } else if at_end && c == b'\r' {
    self.buffer.push(b'\n')
  } else {
    self.buffer.push(c)
  }
}

///|
fn TextBuffer::clear(self : TextBuffer) -> Unit {
  self.buffer.clear()
}

///|
fn TextBuffer::is_empty(self : TextBuffer) -> Bool {
  self.buffer.is_empty()
}

///|
fn TextBuffer::finish(self : TextBuffer) -> String {
  // The buffer must contain a valid UTF-8 string.
  let s = @utf8.decode_lossy(Bytes::from_array(self.buffer[:]))
  self.buffer.clear()
  s
}
