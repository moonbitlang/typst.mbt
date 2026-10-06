// Port of `typst-pdf/src/tags/resolve/{mod,accumulator}.rs`.

///|
priv enum TagNode {
  Group(Int)
  Leaf(@export.Identifier)
  /// Allows inserting a annotation into the tag tree.
  /// Currently used for `Page::add_tagged_annotation`.
  Annotation(Int)
  /// If the attributes are non-empty this will resolve to a `Tag::Span`,
  /// otherwise the items are inserted directly.
  Text(ResolvedTextAttrs, Array[@export.Identifier])
}

///|
priv struct Resolver {
  options : CompletePdfOptions
  ctx : Ctx
  groups : Groups
  tags : Tags
  mut last_heading_level : Int?
  mut flatten : Bool
  errors : Array[@library.SourceDiagnostic]
}

///|
fn tags_resolve(
  gc : GlobalContext,
) -> (@library.Locale?, @export.TagTree) raise @library.SourceError {
  gc.tags.tree.assert_finished_traversal()
  if !tags_disabled(gc) {
    tags_context_finish(gc.tags.tree)
  }
  let root = gc.tags.tree.groups.get(group_id_root)
  let doc_lang = Ref(root.lang)
  if tags_disabled(gc) {
    return (doc_lang.val, @export.TagTree::new())
  }
  let rs : Resolver = {
    options: gc.options,
    ctx: gc.tags.tree.ctx,
    groups: gc.tags.tree.groups,
    tags: gc.tags,
    last_heading_level: None,
    flatten: false,
    errors: gc.tags.tree.errors.copy(),
  }
  gc.tags.tree.errors.clear()
  let accum = Accumulator::root()
  let no_bbox : Ref[BBoxCtx?] = Ref(None)
  for child in root.nodes {
    resolve_node(rs, doc_lang, no_bbox, accum, child)
  }
  if !rs.errors.is_empty() {
    raise @library.SourceError(rs.errors)
  }
  let children = accum.finish()
  (doc_lang.val, { children, lang: None, })
}

///|
/// Resolves nodes into an accumulator.
fn resolve_node(
  rs : Resolver,
  parent_lang : Ref[@library.Locale?],
  parent_bbox : Ref[BBoxCtx?],
  accum : Accumulator,
  node : TagNode,
) -> Unit {
  match node {
    Group(id) => resolve_group_node(rs, parent_lang, parent_bbox, accum, id)
    Leaf(identifier) => accum.push(Leaf(identifier))
    Annotation(id) => accum.push(rs.tags.take_annotation(id))
    Text(attrs, ids) => resolve_text(accum, attrs, ids)
  }
}

///|
fn resolve_group_node(
  rs : Resolver,
  parent_lang : Ref[@library.Locale?],
  parent_bbox : Ref[BBoxCtx?],
  accum : Accumulator,
  id : Int,
) -> Unit {
  let group = rs.groups.get(id)
  let tag = build_group_tag(rs, group)
  let lang : Ref[@library.Locale?]? = match group.kind_lang() {
    Some(l) if tag is Some(_) => Some(Ref(l))
    _ => None
  }
  let bbox : Ref[BBoxCtx?] = Ref(rs.ctx.bbox(group.kind).map(b => b.copy()))

  // If this group doesn't produce a tag, don't create a nested accumulator
  // and push the children directly into the parent.
  let nested_children = match tag {
    Some(tag) => Some(accum.nest(element_kind(tag)))
    None => None
  }
  let children = nested_children.unwrap_or(accum)

  // If a tag has an alternative description specified, flatten the children
  // tags, only retaining link tags, because they are required. The inner tags
  // won't be ingested by AT anyway, but would still have to comply with all
  // rules, which can be annoying.
  let flatten = tag is Some(t) && t.alt_text() is Some(_)
  let prev_flatten = rs.flatten
  rs.flatten = rs.flatten || flatten
  {
    let lang = lang.unwrap_or(parent_lang)
    let bbox = if bbox.val is Some(_) { bbox } else { parent_bbox }

    // In PDF 1.7, don't include artifacts in the tag tree. In PDF 2.0
    // this might become an `Artifact` tag.
    if group.kind.is_artifact() {
      for child in group.nodes {
        resolve_artifact_node(rs, bbox, child)
      }
    } else {
      for child in group.nodes {
        resolve_node(rs, lang, bbox, children, child)
      }
    }
  }
  rs.flatten = prev_flatten

  // Try to propagate the group's language to the parent tag.
  let lang = propagate_lang(
    parent_lang,
    match lang {
      Some(l) => l.val
      None => None
    },
  )

  // Update the parent bbox.
  if parent_bbox.val is Some(parent) && bbox.val is Some(child) {
    parent.expand_page(child)
  }

  // If this isn't a tagged group the children have already been inserted
  // directly into the parent
  guard tag is Some(tag) && nested_children is Some(nested_children) else {
    return
  }

  // Omit the weak group if it is empty.
  let nodes = nested_children.finish()
  if group.weak && nodes.is_empty() {
    return
  }
  tag_set_lang(tag, lang.map(l => l.rfc_3066()))
  if bbox.val is Some(bbox) {
    match tag.name {
      Table | Figure | Formula => tag_set_bbox(tag, bbox.to_export())
      _ => ()
    }
  }
  if rs.options.validators().ua is Some(_) {
    validate_children(rs, tag, nodes)
  }
  accum.push(Group(@export.TagGroup::with_children(tag, nodes)))
}

///|
fn resolve_text(
  accum : Accumulator,
  attrs : ResolvedTextAttrs,
  children : Array[@export.Identifier],
) -> Unit {
  let mut prev : @export.Node? = None
  let into_nodes = (prev : @export.Node?) => {
    match prev {
      None => children.map(id => @export.Node::Leaf(id))
      Some(group) => [group]
    }
  }
  if attrs.script is Some(_) ||
    attrs.background is Some(_) ||
    attrs.deco is Some(_) {
    let tag = new_tag(Span)
    tag_set_opt(
      tag,
      attrs.script.map(s => @export.Attr::LineHeight(s.lineheight)),
      LineHeight(NormalHeight),
    )
    tag_set_opt(
      tag,
      attrs.script.map(s => @export.Attr::BaselineShift(s.baseline_shift)),
      BaselineShift(0.0),
    )
    tag_set_background_color(
      tag,
      match attrs.background {
        Some(c) => c
        None => None
      },
    )
    tag_set_opt(
      tag,
      attrs.deco.map(d => @export.Attr::TextDecorationType(d.kind.to_export())),
      TextDecorationType(NoDecoration),
    )
    tag_set_opt(
      tag,
      match attrs.deco {
        Some({ color: Some(c), .. }) =>
          Some(@export.Attr::TextDecorationColor(c))
        _ => None
      },
      TextDecorationColor({ red: 0, green: 0, blue: 0, }),
    )
    tag_set_opt(
      tag,
      match attrs.deco {
        Some({ thickness: Some(t), .. }) =>
          Some(@export.Attr::TextDecorationThickness(t))
        _ => None
      },
      TextDecorationThickness(0.0),
    )
    prev = Some(Group(@export.TagGroup::with_children(tag, into_nodes(prev))))
  }
  if attrs.strong == Some(true) {
    prev = Some(
      Group(@export.TagGroup::with_children(new_tag(Strong), into_nodes(prev))),
    )
  }
  if attrs.emph == Some(true) {
    prev = Some(
      Group(@export.TagGroup::with_children(new_tag(Em), into_nodes(prev))),
    )
  }
  match prev {
    Some(group) => accum.push(group)
    None =>
      for id in children {
        accum.push(Leaf(id))
      }
  }
}

///|
/// Currently only done to resolve bounding boxes.
fn resolve_artifact_node(
  rs : Resolver,
  parent_bbox : Ref[BBoxCtx?],
  node : TagNode,
) -> Unit {
  match node {
    Group(id) => {
      let group = rs.groups.get(id)
      let bbox : Ref[BBoxCtx?] = Ref(rs.ctx.bbox(group.kind).map(b => b.copy()))
      {
        let bbox = if bbox.val is Some(_) { bbox } else { parent_bbox }
        for child in group.nodes {
          resolve_artifact_node(rs, bbox, child)
        }
      }

      // Update the parent bbox.
      if parent_bbox.val is Some(parent) && bbox.val is Some(child) {
        parent.expand_page(child)
      }
    }
    Leaf(_) => ()
    Annotation(_) => ()
    Text(_, _) => ()
  }
}

///|
fn build_group_tag(rs : Resolver, group : Group) -> @export.TagKind? {
  let styles = tags_styles()
  let tag = match group.kind {
    Root => abort("unreachable")
    Artifact(_) => return None
    LogicalParent(_) => return None
    LogicalChild(_, _) => return None
    Outline(_) => new_tag(TOC)
    OutlineEntry(_) => new_tag(TOCI)
    Table(id, _) => rs.ctx.tables[id].build_tag()
    TableCell(_, tag) => rs.groups.take_tag(tag)
    Grid(_) => new_tag(Div)
    GridCell(_) => new_tag(Div)
    List(_, numbering) => new_tag(L).with_attr(ListNumbering(numbering))
    ListItemLabel => new_tag(Lbl)
    ListItemBody => new_tag(LBody)
    TermsItemLabel => new_tag(Lbl)
    TermsItemBody(_) => new_tag(LBody)
    BibEntry => new_tag(BibEntry)
    FigureWrapper(id) =>
      match rs.ctx.figures[id].build_wrapper_tag() {
        Some(t) => t
        None => return None
      }
    Figure(id, _) =>
      match rs.ctx.figures[id].build_tag() {
        Some(t) => t
        None => return None
      }
    FigureCaption(_) => new_tag(Caption)
    Image(image, _) => {
      let tag = new_tag(Figure)
      tag_set_alt_text(tag, image.alt(styles))
      tag_set_placement(tag, Some(Block))
      tag
    }
    Formula(equation, _) => {
      let tag = new_tag(Formula)
      tag_set_alt_text(tag, equation.alt(styles))
      tag_set_placement(
        tag,
        if equation.block(styles) {
          Some(Block)
        } else {
          None
        },
      )
      tag
    }
    Link(_) => new_tag(Link)
    CodeBlock => {
      let tag = new_tag(Code)
      tag_set_placement(tag, Some(Block))
      tag
    }
    CodeBlockLine => new_tag(P)
    Par => new_tag(P)
    TextAttr(_) => return None
    Transparent => return None
    Standard(tag) => rs.groups.take_tag(tag)
  }
  tag.location = Some(group.span.0)
  if rs.flatten && !group.kind.is_link() {
    return None
  }

  // Check that no heading levels were skipped.
  if tag.name is Hn {
    let prev_level = rs.last_heading_level.unwrap_or(0)
    let next_level = tag.heading_level()
    if rs.options.validators().ua is Some(accessibility) &&
      next_level - prev_level > 1 {
      let span = to_span(tag.location)
      let validator = accessibility_as_str(accessibility)
      if rs.last_heading_level is None {
        rs.errors.push(
          @library.SourceDiagnostic::error_at(
            span,
            "\{validator} error: the first heading must be of level 1",
          ),
        )
      } else {
        rs.errors.push(
          @library.SourceDiagnostic::error_at(
            span,
            "\{validator} error: skipped from heading level \{prev_level} to \{next_level}",
          ).with_hint("heading levels must be consecutive"),
        )
      }
    }
    rs.last_heading_level = Some(next_level)
  }
  Some(tag)
}

///|
priv enum ElementKind {
  Grouping
  Block
  Table
  Inline
} derive(Eq)

///|
fn element_kind(tag : @export.TagKind) -> ElementKind {
  match tag.name {
    Part
    | Article
    | Section
    | Div
    | BlockQuote
    | Caption
    | TOC
    | TOCI
    | Index
    | NonStruct => Grouping
    P | Hn | L | LI | Lbl | LBody | Table => Block
    THead | TBody | TFoot | TR | TH | TD => Table
    Span
    | InlineQuote
    | Note
    | Reference
    | BibEntry
    | Code
    | Link
    | Annot
    | Figure
    | Formula
    | Form => Inline
    // Mapped to `Span`.
    Datetime => Inline
    // Mapped to `Part`.
    Terms => Grouping
    // Mapped to `P`.
    Title => Block
    // Mapped to `Span`.
    Strong | Em => Inline
  }
}

///|
fn validate_children(
  rs : Resolver,
  tag : @export.TagKind,
  children : Array[@export.Node],
) -> Unit {
  match tag.name {
    TOC =>
      validate_children_groups(rs, tag, children, c => c.name is (TOC | TOCI))
    TOCI =>
      validate_children_groups(rs, tag, children, c => {
        c.name is (TOC | Reference | NonStruct | P | Lbl)
      })
    L =>
      validate_children_groups(rs, tag, children, c => {
        c.name is (Caption | L | LI)
      })
    LI =>
      validate_children_groups(rs, tag, children, c => c.name is (Lbl | LBody))
    Table =>
      validate_children_groups(rs, tag, children, c => {
        c.name is (Caption | THead | TBody | TFoot | TR)
      })
    THead | TBody | TFoot =>
      validate_children_groups(rs, tag, children, c => c.name is TR)
    TR => validate_children_groups(rs, tag, children, c => c.name is (TD | TH))
    _ => ()
  }
}

///|
fn validate_children_groups(
  rs : Resolver,
  parent : @export.TagKind,
  children : Array[@export.Node],
  is_valid : (@export.TagKind) -> Bool,
) -> Unit {
  let parent_span = to_span(parent.location)
  let caption_spans = []
  let mut contains_leaf_nodes = false
  for node in children {
    guard node is Group(child) else {
      contains_leaf_nodes = true
      continue
    }
    if !is_valid(child.tag) {
      let validator = validators_to_comma_list(rs.options.validators())
      let span = to_span(child.tag.location)
      let span = if span.is_detached() { parent_span } else { span }
      let parent = tag_name(parent)
      let child = tag_name(child.tag)
      rs.errors.push(
        @library.SourceDiagnostic::error_at(
          span,
          "\{validator} error: invalid \{parent} structure",
        ).with_hints([
          "\{parent} may not contain \{child}",
          "this is probably caused by a show rule",
        ]),
      )
    } else if child.tag.name is Caption {
      caption_spans.push(to_span(child.tag.location))
    }
  }
  if caption_spans.length() > 1 {
    let validator = validators_to_comma_list(rs.options.validators())
    let parent = tag_name(parent)
    let child = tag_name(new_tag(Caption))
    let caption_error = (span : @syntax.Span) => {
      @library.SourceDiagnostic::error_at(
        span,
        "\{validator} error: invalid \{parent} structure",
      ).with_hints([
        "\{parent} may not contain multiple \{child} tags",
        "avoid manually calling `figure.caption`",
      ])
    }
    if caption_spans.iter().all(s => !s.is_detached()) {
      for s in caption_spans {
        rs.errors.push(caption_error(s))
      }
    } else {
      rs.errors.push(caption_error(parent_span))
    }
  }
  if contains_leaf_nodes {
    let validator = validators_to_comma_list(rs.options.validators())
    let parent = tag_name(parent)
    rs.errors.push(
      @library.SourceDiagnostic::error_at(
        parent_span,
        "\{validator} error: invalid \{parent} structure",
      ).with_hints([
        "\{parent} may not contain marked content directly",
        "this is probably caused by a show rule",
      ]),
    )
  }
}

///|
fn tag_name(tag : @export.TagKind) -> String {
  match tag.name {
    Part => "part (Part)"
    Article => "article (Art)"
    Section => "section (Section)"
    Div => "division (Div)"
    BlockQuote => "block quote (BlockQuote)"
    Caption => "caption (Caption)"
    TOC => "outline (TOC)"
    TOCI => "outline entry (TOCI)"
    Index => "index (Index)"
    P => "paragraph (P)"
    Hn => "heading (Hn)"
    L => "list (L)"
    LI => "list item (LI)"
    Lbl => "label (Lbl)"
    LBody => "list body (LBody)"
    Table => "table (Table)"
    TR => "table row (TR)"
    TH => "table header cell (TH)"
    TD => "table data cell (TD)"
    THead => "table header (THead)"
    TBody => "table body (TBody)"
    TFoot => "table footer (TFoot)"
    Span => "span (Span)"
    InlineQuote => "inline quote (Quote)"
    Note => "note (Note)"
    Reference => "reference (Reference)"
    BibEntry => "bibliography entry (BibEntry)"
    Code => "raw text (Code)"
    Link => "link (Link)"
    Annot => "annotation (Annot)"
    Figure => "figure (Figure)"
    Formula => "equation (Formula)"
    Form => "form field (Form)"
    NonStruct => "non structural element (NonStruct)"
    Datetime => "date time (Span)"
    Terms => "terms (P)"
    Title => "title (Title)"
    Strong => "strong (Strong/Span)"
    Em => "emph (Em/Span)"
  }
}

// --- resolve/accumulator.rs ---

///|
priv struct Accumulator {
  nesting : ElementKind
  buf : Array[@export.Node]
  /// An intermediate `Span` node to collect marked content sequences.
  /// Grouping elements may not contain marked content sequences directly, so
  /// they are wrapped into a `Span`.
  mut grouping_span : Array[@export.Node]?
}

///|
/// Create a new accumulator.
fn Accumulator::new(nesting : ElementKind) -> Accumulator {
  { nesting, buf: [], grouping_span: None, }
}

///|
/// Create a new accumulator.
fn Accumulator::root() -> Accumulator {
  Accumulator::new(Grouping)
}

///|
/// Create a new nested accumulator. This will flush any intermediate
/// grouping span, to ensure correct ordering of nested groups.
fn Accumulator::nest(self : Accumulator, nesting : ElementKind) -> Accumulator {
  self.flush_grouping_span()
  Accumulator::new(nesting)
}

///|
/// Flush any intermediate grouping span into the nodes array.
fn Accumulator::flush_grouping_span(self : Accumulator) -> Unit {
  if self.grouping_span is Some(span_nodes) {
    self.grouping_span = None
    let tag = new_tag(Span)
    tag_set_placement(tag, Some(Block))
    self.buf.push(Group(@export.TagGroup::with_children(tag, span_nodes)))
  }
}

///|
/// Push a node into this accumulator.
fn Accumulator::push(self : Accumulator, node : @export.Node) -> Unit {
  if self.nesting == Grouping {
    match node {
      Group(group) => {
        self.flush_grouping_span()

        // Ensure ILSE have block placement when inside grouping elements.
        if element_kind(group.tag) == Inline {
          tag_set_placement(group.tag, Some(Block))
        }
        self.buf.push(node)
      }
      Leaf(_) =>
        match self.grouping_span {
          Some(nodes) => nodes.push(node)
          None => self.grouping_span = Some([node])
        }
    }
  } else {
    self.buf.push(node)
  }
}

///|
/// Finish accumulating and return the nodes.
fn Accumulator::finish(self : Accumulator) -> Array[@export.Node] {
  self.flush_grouping_span()
  self.buf
}
