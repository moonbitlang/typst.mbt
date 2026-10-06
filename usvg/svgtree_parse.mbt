// Port of `usvg` 0.47.0 `src/parser/svgtree/parse.rs`: builds an svgtree
// `Document` from a roxmltree (`@xml`) document.

///|
let svg_ns : String = "http://www.w3.org/2000/svg"

///|
let xlink_ns : String = "http://www.w3.org/1999/xlink"

///|
let xml_namespace_ns : String = "http://www.w3.org/XML/1998/namespace"

///|
/// Parses a [`Document`] from a [`roxmltree::Document`].
pub fn Document::parse_tree(
  xml : @xml.Document,
  injected_stylesheet? : String,
) -> Document raise @xml.XmlError {
  svgtree_parse(xml, injected_stylesheet)
}

///|
fn Document::append(self : Document, parent_id : Int, kind : NodeKind) -> Int {
  let new_child_id = self.nodes.length()
  self.nodes.push({
    parent: Some(parent_id),
    next_sibling: None,
    children: None,
    kind,
  })
  let last_child_id = self.nodes[parent_id].children.map(c => c.1)
  if last_child_id is Some(id) {
    self.nodes[id].next_sibling = Some(new_child_id)
  }
  self.nodes[parent_id].children = Some(
    if self.nodes[parent_id].children is Some((first_child_id, _)) {
      (first_child_id, new_child_id)
    } else {
      (new_child_id, new_child_id)
    },
  )
  new_child_id
}

///|
fn Document::append_attribute(
  self : Document,
  name : AId,
  value : String,
  important : Bool,
) -> Unit {
  self.attrs.push({ name, value, important, })
}

///|
fn svgtree_parse(
  xml : @xml.Document,
  injected_stylesheet : String?,
) -> Document raise @xml.XmlError {
  let doc : Document = { nodes: [], attrs: [], links: {}, }

  // build a map of id -> node for resolve_href
  let id_map : Map[String, @xml.Node] = Map([])
  for node in xml.descendants() {
    if node.attribute("id") is Some(id) {
      if !id_map.contains(id) {
        id_map[id] = node
      }
    }
  }

  // Add a root node.
  doc.nodes.push({
    parent: None,
    next_sibling: None,
    children: None,
    kind: Root,
  })
  let style_sheet = resolve_css(xml, injected_stylesheet)
  parse_xml_node_children(
    xml.root(),
    xml.root(),
    doc.root().id,
    style_sheet,
    false,
    0,
    doc,
    id_map,
  )

  // Check that the root element is `svg`.
  match doc.root().first_element_child() {
    Some(child) =>
      if child.tag_name() != Some(EId::Svg) {
        raise @xml.XmlError::NoRootNode
      }
    None => raise @xml.XmlError::NoRootNode
  }

  // Collect all elements with `id` attribute.
  let links = Map([])
  for node in doc.descendants() {
    let id : String? = node.attribute(AId::Id)
    if id is Some(id) {
      links[id] = node.id
    }
  }
  doc.links = links
  fix_recursive_patterns(doc)
  fix_recursive_links(EId::ClipPath, AId::ClipPath, doc)
  fix_recursive_links(EId::Mask, AId::Mask, doc)
  fix_recursive_links(EId::Filter, AId::Filter, doc)
  fix_recursive_fe_image(doc)
  doc
}

///|
fn parse_tag_name(node : @xml.Node) -> EId? {
  if !node.is_element() {
    return None
  }
  match node.tag_name().namespace() {
    None => ()
    Some(ns) if ns == svg_ns => ()
    _ => return None
  }
  EId::from_str(node.tag_name().name())
}

///|
fn parse_xml_node_children(
  parent : @xml.Node,
  origin : @xml.Node,
  parent_id : Int,
  style_sheet : @simplecss.StyleSheet,
  ignore_ids : Bool,
  depth : Int,
  doc : Document,
  id_map : Map[String, @xml.Node],
) -> Unit raise @xml.XmlError {
  for node in parent.children() {
    parse_xml_node(
      node, origin, parent_id, style_sheet, ignore_ids, depth, doc, id_map,
    )
  }
}

///|
fn parse_xml_node(
  node : @xml.Node,
  origin : @xml.Node,
  parent_id : Int,
  style_sheet : @simplecss.StyleSheet,
  ignore_ids : Bool,
  depth : Int,
  doc : Document,
  id_map : Map[String, @xml.Node],
) -> Unit raise @xml.XmlError {
  if depth > 1024 {
    raise @xml.XmlError::NodesLimitReached
  }
  let mut tag_name = match parse_tag_name(node) {
    Some(id) => id
    None => return
  }
  if tag_name == EId::Style {
    return
  }

  // TODO: remove?
  // Treat links as groups.
  if tag_name == EId::A {
    tag_name = EId::G
  }
  let node_id = parse_svg_element(
    node, parent_id, tag_name, style_sheet, ignore_ids, doc,
  )
  if tag_name == EId::Text {
    parse_svg_text_element(node, node_id, style_sheet, doc)
  } else if tag_name == EId::Use {
    parse_svg_use_element(
      node,
      origin,
      node_id,
      style_sheet,
      depth + 1,
      doc,
      id_map,
    )
  } else {
    parse_xml_node_children(
      node,
      origin,
      node_id,
      style_sheet,
      ignore_ids,
      depth + 1,
      doc,
      id_map,
    )
  }
}

///|
fn parse_svg_element(
  xml_node : @xml.Node,
  parent_id : Int,
  tag_name : EId,
  style_sheet : @simplecss.StyleSheet,
  ignore_ids : Bool,
  doc : Document,
) -> Int raise @xml.XmlError {
  let attrs_start_idx = doc.attrs.length()

  // Copy presentational attributes first.
  for attr in xml_node.attributes() {
    match attr.namespace() {
      None => ()
      Some(ns) if ns == svg_ns || ns == xlink_ns || ns == xml_namespace_ns => ()
      _ => continue
    }
    let aid = match AId::from_str(attr.name()) {
      Some(v) => v
      None => continue
    }

    // During a `use` resolving, all `id` attributes must be ignored.
    // Otherwise we will get elements with duplicated id's.
    if ignore_ids && aid == AId::Id {
      continue
    }

    // For some reason those properties are allowed only inside a `style` attribute and CSS.
    if aid is (AId::MixBlendMode | AId::Isolation | AId::FontKerning) {
      continue
    } else if aid == AId::ImageRendering &&
      attr.value() is ("smooth" | "high-quality" | "crisp-edges" | "pixelated") {
      continue
    }
    append_attribute(parent_id, tag_name, aid, attr.value(), false, doc)
    |> ignore
  }
  let insert_attribute = (aid : AId, value : String, important : Bool) => {
    // Check that attribute already exists.
    let mut idx = None
    for i in attrs_start_idx..<doc.attrs.length() {
      if doc.attrs[i].name == aid {
        idx = Some(i - attrs_start_idx)
        break
      }
    }

    // Append an attribute as usual.
    let added = append_attribute(
      parent_id, tag_name, aid, value, important, doc,
    )

    // Check that attribute was actually added, because it could be skipped.
    if added {
      if idx is Some(idx) {
        let last_idx = doc.attrs.length() - 1
        let existing_idx = attrs_start_idx + idx

        // See https://developer.mozilla.org/en-US/docs/Web/CSS/important
        // When a declaration is important, the order of precedence is reversed.
        // ...
        // Which means:
        // 1) Existing is not important, new is not important -> swap
        // 2) Existing is important, new is not important -> don't swap
        // 3) Existing is not important, new is important -> swap
        // 4) Existing is important, new is important -> don't swap (since the order
        // is reversed, so existing important attributes take precedence over new
        // important attributes)
        let has_precedence = !doc.attrs[existing_idx].important
        if has_precedence {
          doc.attrs.swap(existing_idx, last_idx)
        }

        // Remove last.
        doc.attrs.pop() |> ignore
      }
    }
  }
  let write_declaration = (declaration : @simplecss.Declaration) => {
    // TODO: perform XML attribute normalization
    let imp = declaration.important
    let val = declaration.value
    if declaration.name == "marker" {
      insert_attribute(AId::MarkerStart, val, imp)
      insert_attribute(AId::MarkerMid, val, imp)
      insert_attribute(AId::MarkerEnd, val, imp)
    } else if declaration.name == "font" {
      try @svgtypes.FontShorthand::from_str(val) catch {
        _ =>
          // Upstream warns: Failed to parse font value.
          ()
      } noraise {
        shorthand => {
          // First we need to reset all values to their default.
          insert_attribute(AId::FontStyle, "normal", imp)
          insert_attribute(AId::FontVariant, "normal", imp)
          insert_attribute(AId::FontWeight, "normal", imp)
          insert_attribute(AId::FontStretch, "normal", imp)
          insert_attribute(AId::LineHeight, "normal", imp)
          insert_attribute(AId::FontSizeAdjust, "none", imp)
          insert_attribute(AId::FontKerning, "auto", imp)
          insert_attribute(AId::FontVariantCaps, "normal", imp)
          insert_attribute(AId::FontVariantLigatures, "normal", imp)
          insert_attribute(AId::FontVariantNumeric, "normal", imp)
          insert_attribute(AId::FontVariantEastAsian, "normal", imp)
          insert_attribute(AId::FontVariantPosition, "normal", imp)

          // Then, we set the properties that have been declared.
          if shorthand.font_stretch is Some(s) {
            insert_attribute(AId::FontStretch, s, imp)
          }
          if shorthand.font_weight is Some(s) {
            insert_attribute(AId::FontWeight, s, imp)
          }
          if shorthand.font_variant is Some(s) {
            insert_attribute(AId::FontVariant, s, imp)
          }
          if shorthand.font_style is Some(s) {
            insert_attribute(AId::FontStyle, s, imp)
          }
          insert_attribute(AId::FontSize, shorthand.font_size, imp)
          insert_attribute(AId::FontFamily, shorthand.font_family, imp)
        }
      }
    } else if AId::from_str(declaration.name) is Some(aid) {
      // Parse only the presentation attributes.
      if aid.is_presentation() {
        insert_attribute(aid, val, imp)
      }
    }
  }

  // Apply CSS.
  for rule in style_sheet.rules {
    if rule.selector.matches(XmlNode(xml_node)) {
      for declaration in rule.declarations {
        write_declaration(declaration)
      }
    }
  }

  // Split a `style` attribute.
  if xml_node.attribute("style") is Some(value) {
    let tokenizer = @simplecss.DeclarationTokenizer::from(value)
    while tokenizer.next() is Some(declaration) {
      write_declaration(declaration)
    }
  }
  if doc.nodes.length() > 1_000_000 {
    raise @xml.XmlError::NodesLimitReached
  }
  let node_id = doc.append(
    parent_id,
    Element(tag_name~, attributes=(attrs_start_idx, doc.attrs.length())),
  )
  node_id
}

///|
fn append_attribute(
  parent_id : Int,
  tag_name : EId,
  aid : AId,
  value : String,
  important : Bool,
  doc : Document,
) -> Bool {
  match aid {
    // The `style` attribute will be split into attributes, so we don't need it.
    AId::Style
    // No need to copy a `class` attribute since CSS were already resolved.
    | AId::Class => return false
    _ => ()
  }

  // Ignore `xlink:href` on `tspan` (which was originally `tref` or `a`),
  // because we will convert `tref` into `tspan` anyway.
  if tag_name == EId::Tspan && aid == AId::Href {
    return false
  }
  if aid.allows_inherit_value() && value == "inherit" {
    return resolve_inherit(parent_id, aid, doc)
  }
  doc.append_attribute(aid, value, important)
  true
}

///|
fn resolve_inherit(parent_id : Int, aid : AId, doc : Document) -> Bool {
  if aid.is_inheritable() {
    // Inheritable attributes can inherit a value from an any ancestor.
    let node_id = doc
      .get(parent_id)
      .ancestors()
      .find_first(n => n.has_attribute(aid))
      .map(n => n.id)
    if node_id is Some(node_id) {
      if doc.get(node_id).attributes().iter().find_first(a => a.name == aid)
        is Some(attr) {
        doc.attrs.push({
          name: aid,
          value: attr.value,
          important: attr.important,
        })
        return true
      }
    }
  } else if doc
    .get(parent_id)
    .attributes()
    .iter()
    .find_first(a => a.name == aid)
    is Some(attr) {
    // Non-inheritable attributes can inherit a value only from a direct parent.
    doc.attrs.push({ name: aid, value: attr.value, important: attr.important, })
    return true
  }

  // Fallback to a default value if possible.
  let value = match aid {
    AId::ImageRendering | AId::ShapeRendering | AId::TextRendering => "auto"
    AId::ClipPath
    | AId::Filter
    | AId::MarkerEnd
    | AId::MarkerMid
    | AId::MarkerStart
    | AId::Mask
    | AId::Stroke
    | AId::StrokeDasharray
    | AId::TextDecoration => "none"
    AId::FontStretch
    | AId::FontStyle
    | AId::FontVariant
    | AId::FontWeight
    | AId::LetterSpacing
    | AId::WordSpacing => "normal"
    AId::Fill | AId::FloodColor | AId::StopColor => "black"
    AId::FillOpacity
    | AId::FloodOpacity
    | AId::Opacity
    | AId::StopOpacity
    | AId::StrokeOpacity => "1"
    AId::ClipRule | AId::FillRule => "nonzero"
    AId::BaselineShift => "baseline"
    AId::ColorInterpolationFilters => "linearRGB"
    AId::Direction => "ltr"
    AId::Display => "inline"
    AId::FontSize => "medium"
    AId::Overflow => "visible"
    AId::StrokeDashoffset => "0"
    AId::StrokeLinecap => "butt"
    AId::StrokeLinejoin => "miter"
    AId::StrokeMiterlimit => "4"
    AId::StrokeWidth => "1"
    AId::TextAnchor => "start"
    AId::Visibility => "visible"
    AId::WritingMode => "lr-tb"
    _ => return false
  }
  doc.append_attribute(aid, value, false)
  true
}

///|
fn resolve_href(
  node : @xml.Node,
  id_map : Map[String, @xml.Node],
) -> @xml.Node? {
  let link_value = match node.attribute("href", ns=xlink_ns) {
    Some(v) => v
    None =>
      match node.attribute("href") {
        Some(v) => v
        None => return None
      }
  }
  guard (Some(@svgtypes.IRI::from_str(link_value)) catch { _ => None })
    is Some(link_id) else {
    return None
  }
  id_map.get(link_id.0)
}

///|
fn parse_svg_use_element(
  node : @xml.Node,
  origin : @xml.Node,
  parent_id : Int,
  style_sheet : @simplecss.StyleSheet,
  depth : Int,
  doc : Document,
  id_map : Map[String, @xml.Node],
) -> Unit raise @xml.XmlError {
  let link = match resolve_href(node, id_map) {
    Some(v) => v
    None => return
  }
  if link == node || link == origin {
    // Upstream warns: Recursive 'use' detected.
    return
  }

  // Make sure we're linked to an SVG element.
  if parse_tag_name(link) is None {
    return
  }

  // Check that none of the linked node's children reference current `use` node
  // via other `use` node.
  //
  // Example:
  // <g id="g1">
  //     <use xlink:href="#use1" id="use2"/>
  // </g>
  // <use xlink:href="#g1" id="use1"/>
  //
  // `use2` should be removed.
  //
  // Also, child should not reference its parent:
  // <g id="g1">
  //     <use xlink:href="#g1" id="use1"/>
  // </g>
  //
  // `use1` should be removed.
  let mut is_recursive = false
  let descendants = link.descendants()
  for i in 1..<descendants.length() {
    let link_child = descendants[i]
    if !link_child.has_tag_name("use", ns=svg_ns) {
      continue
    }
    if resolve_href(link_child, id_map) is Some(link2) {
      if link2 == node || link2 == link {
        is_recursive = true
        break
      }
    }
  }
  if is_recursive {
    // Upstream warns: Recursive 'use' detected.
    return
  }
  parse_xml_node(
    link,
    node,
    parent_id,
    style_sheet,
    true,
    depth + 1,
    doc,
    id_map,
  )
}

///|
fn resolve_css(
  xml : @xml.Document,
  style_sheet : String?,
) -> @simplecss.StyleSheet {
  let sheet = @simplecss.StyleSheet::new()

  // Injected style sheets do not override internal ones (we mimic the logic of rsvg-convert),
  // so we need to parse it first.
  if style_sheet is Some(style_sheet) {
    sheet.parse_more(style_sheet)
  }
  for node in xml.descendants() {
    if !node.has_tag_name("style") {
      continue
    }
    match node.attribute("type") {
      Some("text/css") => ()
      Some(_) => continue
      None => ()
    }
    let text = match node.text() {
      Some(v) => v
      None => continue
    }
    sheet.parse_more(text)
  }
  sheet
}

///|
priv struct XmlNode(@xml.Node)

///|
impl @simplecss.Element for XmlNode with fn parent_element(self) {
  self.0.parent_element().map(x => XmlNode(x))
}

///|
impl @simplecss.Element for XmlNode with fn prev_sibling_element(self) {
  self.0.prev_sibling_element().map(x => XmlNode(x))
}

///|
impl @simplecss.Element for XmlNode with fn has_local_name(self, local_name) {
  self.0.tag_name().name() == local_name
}

///|
impl @simplecss.Element for XmlNode with fn attribute_matches(
  self,
  local_name,
  operator,
) {
  match self.0.attribute(local_name) {
    Some(value) => operator.matches(value)
    None => false
  }
}

///|
impl @simplecss.Element for XmlNode with fn pseudo_class_matches(self, class) {
  match class {
    @simplecss.PseudoClass::FirstChild => self.0.prev_sibling_element() is None
    // TODO: lang
    _ => false // Since we are querying a static SVG we can ignore other pseudo-classes.
  }
}

///|
fn fix_recursive_patterns(doc : Document) -> Unit {
  while find_recursive_pattern(AId::Fill, doc) is Some(node_id) {
    let idx = doc.get(node_id).attribute_id(AId::Fill).unwrap()
    doc.attrs[idx].value = "none"
  }
  while find_recursive_pattern(AId::Stroke, doc) is Some(node_id) {
    let idx = doc.get(node_id).attribute_id(AId::Stroke).unwrap()
    doc.attrs[idx].value = "none"
  }
}

///|
fn find_recursive_pattern(aid : AId, doc : Document) -> Int? {
  for pattern_node in doc.root().descendants() {
    if pattern_node.tag_name() != Some(EId::Pattern) {
      continue
    }
    for node in pattern_node.descendants() {
      let value : String = match node.attribute(aid) {
        Some(v) => v
        None => continue
      }
      if (Some(@svgtypes.Paint::from_str(value)) catch { _ => None })
        is Some(FuncIRI(link_id, _)) {
        if link_id == pattern_node.element_id() {
          // If a pattern child has a link to the pattern itself
          // then we have to replace it with `none`.
          // Otherwise we will get endless loop/recursion and stack overflow.
          return Some(node.id)
        } else if doc.element_by_id(link_id) is Some(linked_node) {
          // Check that linked node children doesn't link this pattern.
          for node2 in linked_node.descendants() {
            let value2 : String = match node2.attribute(aid) {
              Some(v) => v
              None => continue
            }
            if (Some(@svgtypes.Paint::from_str(value2)) catch { _ => None })
              is Some(FuncIRI(link_id2, _)) {
              if link_id2 == pattern_node.element_id() {
                return Some(node2.id)
              }
            }
          }
        }
      }
    }
  }
  None
}

///|
fn fix_recursive_links(eid : EId, aid : AId, doc : Document) -> Unit {
  while find_recursive_link(eid, aid, doc) is Some(node_id) {
    let idx = doc.get(node_id).attribute_id(aid).unwrap()
    doc.attrs[idx].value = "none"
  }
}

///|
fn find_recursive_link(eid : EId, aid : AId, doc : Document) -> Int? {
  for node in doc.root().descendants() {
    if node.tag_name() != Some(eid) {
      continue
    }
    for child in node.descendants() {
      if child.node_attribute(aid) is Some(link) {
        if link == node {
          // If an element child has a link to the element itself
          // then we have to replace it with `none`.
          // Otherwise we will get endless loop/recursion and stack overflow.
          return Some(child.id)
        } else {
          // Check that linked node children doesn't link this element.
          for node2 in link.descendants() {
            if node2.node_attribute(aid) is Some(link2) {
              if link2 == node {
                return Some(node2.id)
              }
            }
          }
        }
      }
    }
  }
  None
}

///|
/// Detects cases like:
///
/// ```xml
/// <filter id="filter1">
///   <feImage xlink:href="#rect1"/>
/// </filter>
/// <rect id="rect1" x="36" y="36" width="120" height="120" fill="green" filter="url(#filter1)"/>
/// ```
fn fix_recursive_fe_image(doc : Document) -> Unit {
  let ids = []
  for fe_node in doc.root().descendants() {
    if fe_node.tag_name() != Some(EId::FeImage) {
      continue
    }
    if fe_node.node_attribute(AId::Href) is Some(link) {
      let filter_uri : String? = link.attribute(AId::Filter)
      if filter_uri is Some(filter_uri) {
        let filter_id = fe_node.parent().unwrap().element_id()
        let p = @svgtypes.FilterValueListParser::from(filter_uri)
        while p.next() is Some(func) {
          // `.flatten()` skips errors.
          if func is Ok(Url(url)) && url == filter_id {
            ids.push(link.id)
          }
        }
      }
    }
  }
  for id in ids {
    let idx = doc.get(id).attribute_id(AId::Filter).unwrap()
    doc.attrs[idx].value = "none"
  }
}
