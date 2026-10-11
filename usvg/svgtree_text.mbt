// Port of `usvg` 0.47.0 `src/parser/svgtree/text.rs`: `text` element
// preprocessing (whitespace handling, `tref` resolving).

///|
fn parse_svg_text_element(
  parent : @xml.Node,
  parent_id : Int,
  style_sheet : @simplecss.StyleSheet,
  doc : Document,
) -> Unit raise @xml.XmlError {
  let space = if doc.get(parent_id).has_attribute(AId::Space) {
    get_xmlspace(doc, parent_id, XmlSpaceDefault)
  } else if doc
    .get(parent_id)
    .ancestors()
    .find_first(n => n.has_attribute(AId::Space))
    is Some(node) {
    get_xmlspace(doc, node.id, XmlSpaceDefault)
  } else {
    XmlSpaceDefault
  }
  parse_svg_text_element_impl(parent, parent_id, style_sheet, space, doc)
  trim_text_nodes(parent_id, space, doc)
}

///|
fn parse_svg_text_element_impl(
  parent : @xml.Node,
  parent_id : Int,
  style_sheet : @simplecss.StyleSheet,
  space : XmlSpace,
  doc : Document,
) -> Unit raise @xml.XmlError {
  for node in parent.children() {
    if node.is_text() {
      let text = trim_text(node.text().unwrap(), space)
      doc.append(parent_id, Text(text)) |> ignore
      continue
    }
    let mut tag_name = match parse_tag_name(node) {
      Some(v) => v
      None => continue
    }
    if tag_name == EId::A {
      // Treat links as simple text.
      tag_name = EId::Tspan
    }
    if !(tag_name is (EId::Tspan | EId::Tref | EId::TextPath)) {
      continue
    }

    // `textPath` must be a direct `text` child.
    if tag_name == EId::TextPath && parent.tag_name().name() != "text" {
      continue
    }

    // We are converting `tref` into `tspan` to simplify later use.
    let mut is_tref = false
    if tag_name == EId::Tref {
      tag_name = EId::Tspan
      is_tref = true
    }
    let node_id = parse_svg_element(
      node, parent_id, tag_name, style_sheet, false, doc,
    )
    let space = get_xmlspace(doc, node_id, space)
    if is_tref {
      let link_value = match node.attribute("href", ns=xlink_ns) {
        Some(v) => Some(v)
        None => node.attribute("href")
      }
      if link_value is Some(href) {
        if resolve_tref_text(node.document(), href) is Some(text) {
          let text = trim_text(text, space)
          doc.append(node_id, Text(text)) |> ignore
        }
      }
    } else {
      parse_svg_text_element_impl(node, node_id, style_sheet, space, doc)
    }
  }
}

///|
fn resolve_tref_text(xml : @xml.Document, href : String) -> String? {
  guard (Some(@svgtypes.IRI::from_str(href)) catch { _ => None }) is Some(iri) else {
    return None
  }
  let id = iri.0

  // Find linked element in the original tree.
  guard xml.descendants().iter().find_first(n => n.attribute("id") == Some(id))
    is Some(node) else {
    return None
  }

  // `tref` should be linked to an SVG element.
  guard parse_tag_name(node) is Some(_) else { return None }

  // 'All character data within the referenced element, including character data enclosed
  // within additional markup, will be rendered.'
  //
  // So we don't care about attributes and everything. Just collecting text nodes data.
  //
  // Note: we have to filter nodes by `is_text()` first since `text()` will look up
  // for text nodes in element children therefore we will get duplicates.
  let text = StringBuilder()
  for n in node.descendants() {
    if n.is_text() && n.text() is Some(t) {
      text.write_string(t)
    }
  }
  let text = text.to_string()
  if text.is_empty() {
    None
  } else {
    Some(text)
  }
}

///|
priv enum XmlSpace {
  XmlSpaceDefault
  XmlSpacePreserve
} derive(Eq)

///|
fn get_xmlspace(doc : Document, node_id : Int, default : XmlSpace) -> XmlSpace {
  let value : String? = doc.get(node_id).attribute(AId::Space)
  match value {
    Some("preserve") => XmlSpacePreserve
    Some(_) => XmlSpaceDefault
    _ => default
  }
}

///|
fn Document::text_of(self : Document, node_id : Int) -> String {
  match self.nodes[node_id].kind {
    Text(text) => text
    _ => self.get(node_id).text()
  }
}

///|
fn Document::remove_first_space(self : Document, node_id : Int) -> Unit {
  if self.nodes[node_id].kind is Text(text) {
    self.nodes[node_id].kind = Text(
      text.unsafe_substring(start=1, end=text.length()),
    )
  }
}

///|
fn Document::remove_last_space(self : Document, node_id : Int) -> Unit {
  if self.nodes[node_id].kind is Text(text) {
    self.nodes[node_id].kind = Text(
      text.unsafe_substring(start=0, end=text.length() - 1),
    )
  }
}

///|
/// Prepares text nodes according to the spec: https://www.w3.org/TR/SVG11/text.html#WhiteSpace
///
/// This function handles:
/// - 'xml:space' processing
/// - tabs and newlines removing/replacing
/// - spaces trimming
fn trim_text_nodes(
  text_elem_id : Int,
  xmlspace : XmlSpace,
  doc : Document,
) -> Unit {
  let nodes = [] // TODO: allocate only once
  collect_text_nodes(doc.get(text_elem_id), 0, nodes)

  // `trim` method has already collapsed all spaces into a single one,
  // so we have to check only for one leading or trailing space.

  if nodes.length() == 1 {
    // Process element with a single text node child.

    let node_id = nodes[0].0
    if xmlspace == XmlSpaceDefault {
      if doc.nodes[node_id].kind is Text(text) {
        match text.length() {
          0 => () // An empty string. Do nothing.
          1 =>
            // If string has only one character and it's a space - clear this string.
            if text.unsafe_get(0) == ' ' {
              doc.nodes[node_id].kind = Text("")
            }
          _ => {
            // 'text' has at least 2 bytes, so indexing is safe.
            let c1 = text.unsafe_get(0)
            let c2 = text.unsafe_get(text.length() - 1)
            if c1 == ' ' {
              doc.remove_first_space(node_id)
            }
            if c2 == ' ' {
              doc.remove_last_space(node_id)
            }
          }
        }
      }
    } else {
      // Do nothing when xml:space=preserve.
    }
  } else if nodes.length() > 1 {
    // Process element with many text node children.

    // We manage all text nodes as a single text node
    // and trying to remove duplicated spaces across nodes.
    //
    // For example    '<text>Text <tspan> text </tspan> text</text>'
    // is the same is '<text>Text <tspan>text</tspan> text</text>'

    let mut i = 0
    let len = nodes.length() - 1
    let mut last_non_empty : Int? = None
    while i < len {
      // Process pairs.
      let (node1_id_, depth1) = nodes[i]
      let mut node1_id = node1_id_
      let (node2_id, depth2) = nodes[i + 1]
      if doc.text_of(node1_id).is_empty() {
        if last_non_empty is Some(n) {
          node1_id = n
        }
      }

      // Parent of the text node is always an element node and always exist,
      // so unwrap is safe.
      let xmlspace1 = get_xmlspace(
        doc,
        doc.get(node1_id).parent().unwrap().id,
        xmlspace,
      )
      let xmlspace2 = get_xmlspace(
        doc,
        doc.get(node2_id).parent().unwrap().id,
        xmlspace,
      )

      // >text<..>text<
      //  1  2    3  4
      let (c1, c2, c3, c4) = {
        let text1 = doc.text_of(node1_id)
        let text2 = doc.text_of(node2_id)
        // Only spaces are compared, so UTF-16 code units are equivalent to
        // upstream's UTF-8 bytes here.
        let first = (t : String) => {
          if t.is_empty() {
            None
          } else {
            Some(t.unsafe_get(0))
          }
        }
        let last = (t : String) => {
          if t.is_empty() {
            None
          } else {
            Some(t.unsafe_get(t.length() - 1))
          }
        }
        (first(text1), last(text1), first(text2), last(text2))
      }

      // NOTE: xml:space processing is mostly an undefined behavior,
      // because everyone do it differently.
      // We're mimicking the Chrome behavior.

      // Remove space from the second text node if both nodes has bound spaces.
      // From: '<text>Text <tspan> text</tspan></text>'
      // To:   '<text>Text <tspan>text</tspan></text>'
      //
      // See text-tspan-02-b.svg for details.
      if depth1 < depth2 {
        if c3 == Some(' ') {
          if xmlspace2 == XmlSpaceDefault {
            doc.remove_first_space(node2_id)
          }
        }
      } else if c2 == Some(' ') && c2 == c3 {
        if xmlspace1 == XmlSpaceDefault && xmlspace2 == XmlSpaceDefault {
          doc.remove_last_space(node1_id)
        } else if xmlspace1 == XmlSpacePreserve && xmlspace2 == XmlSpaceDefault {
          doc.remove_first_space(node2_id)
        }
      }
      let is_first = i == 0
      let is_last = i == len - 1
      if is_first &&
        c1 == Some(' ') &&
        xmlspace1 == XmlSpaceDefault &&
        !doc.text_of(node1_id).is_empty() {
        // Remove a leading space from a first text node.
        doc.remove_first_space(node1_id)
      } else if is_last &&
        c4 == Some(' ') &&
        !doc.text_of(node2_id).is_empty() &&
        xmlspace2 == XmlSpaceDefault {
        // Remove a trailing space from a last text node.
        // Also check that 'text2' is not empty already.
        doc.remove_last_space(node2_id)
      }
      if is_last &&
        c2 == Some(' ') &&
        !doc.text_of(node1_id).is_empty() &&
        doc.text_of(node2_id).is_empty() &&
        doc.text_of(node1_id).has_suffix(" ") {
        doc.remove_last_space(node1_id)
      }
      if !rust_trim(doc.text_of(node1_id)).is_empty() {
        last_non_empty = Some(node1_id)
      }
      i += 1
    }
  }

  // TODO: find a way to remove all empty text nodes
}

///|
fn collect_text_nodes(
  parent : SvgNode,
  depth : Int,
  nodes : Array[(Int, Int)],
) -> Unit {
  for child in parent.children() {
    if child.is_text() {
      nodes.push((child.id, depth))
    } else if child.is_element() {
      collect_text_nodes(child, depth + 1, nodes)
    }
  }
}

///|
fn trim_text(text : String, space : XmlSpace) -> String {
  let s = StringBuilder()
  let mut prev = '0'
  for c in text {
    // \r, \n and \t should be converted into spaces.
    let c = match c {
      '\r' | '\n' | '\t' => ' '
      _ => c
    }

    // Skip continuous spaces.
    if space == XmlSpaceDefault && c == ' ' && c == prev {
      continue
    }
    prev = c
    s.write_char(c)
  }
  s.to_string()
}

///|
/// Rust's `str::trim` (Unicode `White_Space`).
fn rust_trim(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() && is_rust_whitespace(chars[i]) {
    i += 1
  }
  start = i
  let mut j = chars.length()
  while j > start && is_rust_whitespace(chars[j - 1]) {
    j -= 1
  }
  end = j
  String::from_array(chars[start:end])
}

///|
/// Rust's `char::is_whitespace` (the Unicode `White_Space` property).
fn is_rust_whitespace(c : Char) -> Bool {
  c
  is ('\u{9}'..<='\u{d}'
  | ' '
  | '\u{85}'
  | '\u{a0}'
  | '\u{1680}'
  | '\u{2000}'..<='\u{200a}'
  | '\u{2028}'
  | '\u{2029}'
  | '\u{202f}'
  | '\u{205f}'
  | '\u{3000}')
}
