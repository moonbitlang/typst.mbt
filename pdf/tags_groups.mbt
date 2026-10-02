// Port of `typst-pdf/src/tags/groups.rs`.
//
// Group IDs are indices into `Groups::list`; `group_id_root` and
// `group_id_invalid` correspond to `GroupId::ROOT` and `GroupId::INVALID`.
// The language stored by most group kinds lives in `Group::lang` (see
// `GroupKind::has_lang`).

///|
/// The invalid group ID.
let group_id_invalid : Int = -1

///|
let group_id_root : Int = 0

///|
priv struct Groups {
  locations : Map[@library.Location, LocatedGroup]
  list : Array[Group]
  tags : Array[@export.TagKind?]
}

///|
fn Groups::new() -> Groups {
  { locations: {}, list: [], tags: [], }
}

///|
fn Groups::by_loc(self : Groups, loc : @library.Location) -> LocatedGroup? {
  self.locations.get(loc)
}

///|
fn Groups::get(self : Groups, id : Int) -> Group {
  self.list[id]
}

///|
fn Groups::next_id(self : Groups) -> Int {
  self.list.length()
}

///|
fn Groups::push_list(self : Groups, group : Group) -> Int {
  let id = self.list.length()
  self.list.push(group)
  id
}

///|
/// See [`propagate_lang`].
fn Groups::propagate_lang(
  self : Groups,
  id : Int,
  lang : @library.Locale,
) -> @library.Locale? {
  // TODO: walk up to the first parent that has a language.
  let group = self.get(id)
  if !group.kind.has_lang() {
    return Some(lang)
  }
  let parent = Ref::new(group.lang)
  let res = propagate_lang(parent, Some(lang))
  group.lang = parent.val
  res
}

///|
/// Create a located group. If the location has already been taken,
/// create a new virtual group.
fn Groups::new_located(
  self : Groups,
  loc : @library.Location,
  parent : Int,
  span : @syntax.Span,
  kind : GroupKind,
) -> Int {
  let id = self.new_virtual(parent, span, kind)
  match self.locations.get(loc) {
    Some(located) =>
      // Multiple introspection tags have the same location,
      // for example because an element was queried and then
      // placed again. Create a new group that doesn't have
      // a location mapping.
      located.multiple_parents = true
    None => self.locations[loc] = { id, multiple_parents: false, }
  }
  id
}

///|
/// Create a new virtual group, not associated with any location.
fn Groups::new_virtual(
  self : Groups,
  parent : Int,
  span : @syntax.Span,
  kind : GroupKind,
) -> Int {
  self.push_list(Group::new(parent, span, kind, false))
}

///|
/// Create a new weak group, not associated with any location.
fn Groups::new_weak(
  self : Groups,
  parent : Int,
  span : @syntax.Span,
  kind : GroupKind,
) -> Int {
  self.push_list(Group::new(parent, span, kind, true))
}

///|
/// NOTE: this needs to be kept in sync with [`Groups::break_group`].
fn Groups::breakable(self : Groups, kind : GroupKind) -> BreakOpportunity {
  match kind {
    Root => Never
    Artifact(_) => Always(Span)
    LogicalParent(_) => Never
    LogicalChild(_, _) => Never
    Outline(_) => Never
    OutlineEntry(_) => Never
    Table(_, _) => Never
    TableCell(_, _) => Never
    Grid(_) => Never
    GridCell(_) => Never
    List(_, _) => Never
    ListItemLabel => Never
    ListItemBody => Never
    TermsItemLabel => Never
    TermsItemBody(_) => Never
    BibEntry => Never
    FigureWrapper(_) => Never
    Figure(_, _) => Never
    FigureCaption(_) => Never
    Image(_, _) => Never
    Formula(_, _) => Never
    Link(_) => NoPdfUa(Span)
    CodeBlock => Never
    CodeBlockLine => Never
    Par => NoPdfUa(Par)
    TextAttr(_) => Always(TextAttr)
    Transparent => Never
    Standard(tag) =>
      match self.tag(tag).name {
        Part => Never
        Article => Never
        Section => Never
        Div => Never
        BlockQuote => Never
        Caption => Never
        TOC => Never
        TOCI => Never
        Index => Never
        P => NoPdfUa(Par)
        Hn => Never
        L => Never
        LI => Never
        Lbl => Never
        LBody => Never
        Table => Never
        TR => Never
        TH => Never
        TD => Never
        THead => Never
        TBody => Never
        TFoot => Never
        Span => Always(Span)
        InlineQuote => Never
        Note => Never
        Reference => NoPdfUa(Span)
        BibEntry => Never
        Code => NoPdfUa(Span)
        Link => NoPdfUa(Span)
        Annot => Never
        Figure => Never
        Formula => Never
        Form => Never
        NonStruct => Never
        Datetime => Never
        Terms => Never
        Title => Never
        Strong => Always(Span)
        Em => Always(Span)
      }
  }
}

///|
/// NOTE: this needs to be kept in sync with [`Groups::breakable`].
fn Groups::break_group(self : Groups, id : Int, new_parent : Int) -> Int {
  let group = self.get(id)
  let span = group.span
  let new_kind : GroupKind = match group.kind {
    Artifact(ty) => Artifact(ty)
    Link(elem) => Link(elem)
    Par => Par
    TextAttr(attr) => TextAttr(attr)
    Standard(old) => {
      let tag = tag_clone(self.tag(old))
      let new = self.push_tag_storage(tag)
      Standard(new)
    }
    _ => abort("unreachable")
  }
  self.push_list(Group::new(new_parent, span, new_kind, true))
}

///|
priv enum BreakOpportunity {
  /// The group is unbreakable.
  Never
  /// The group can only be broken when PDF/UA isn't targeted.
  NoPdfUa(BreakPriority)
  /// The group can always be broken.
  Always(BreakPriority)
} derive(Eq)

///|
fn BreakOpportunity::get(
  self : BreakOpportunity,
  is_pdf_ua : Bool,
) -> BreakPriority? {
  match self {
    Never => None
    NoPdfUa(p) if !is_pdf_ua => Some(p)
    NoPdfUa(_) => None
    Always(p) => Some(p)
  }
}

///|
priv enum BreakPriority {
  Par
  Span
  TextAttr
  Artifact
} derive(Eq, Compare)

///|
let break_priority_max : BreakPriority = Artifact

// These methods are the only way to insert nested groups in the
// [`Group::nodes`] list.

///|
/// Create a new group with a standard tag and push it into the parent.
fn Groups::push_tag(self : Groups, parent : Int, tag : @export.TagKind) -> Int {
  let tag_id = self.push_tag_storage(tag)
  let kind = GroupKind::Standard(tag_id)
  let id = self.push_list(
    Group::new(parent, @syntax.Span::detached(), kind, false),
  )
  self.get(parent).nodes.push(Group(id))
  id
}

///|
/// Prepend multiple existing group to the start of the parent.
fn Groups::prepend_groups(
  self : Groups,
  parent : Int,
  children : Array[Int],
) -> Unit {
  let nodes = self.get(parent).nodes
  for i, child in children {
    nodes.insert(i, Group(child))
  }
}

///|
/// Append an existing group to the end of the parent.
fn Groups::push_group(self : Groups, parent : Int, child : Int) -> Unit {
  self.get(parent).nodes.push(Group(child))
}

///|
/// Append multiple existing groups to the end of the parent.
fn Groups::push_groups(
  self : Groups,
  parent : Int,
  children : Array[Int],
) -> Unit {
  let nodes = self.get(parent).nodes
  for child in children {
    nodes.push(Group(child))
  }
}

// Tag storage (upstream `TagStorage`).

///|
fn Groups::push_tag_storage(self : Groups, tag : @export.TagKind) -> Int {
  let id = self.tags.length()
  self.tags.push(Some(tag))
  id
}

///|
fn Groups::set_tag(self : Groups, id : Int, tag : @export.TagKind) -> Unit {
  self.tags[id] = Some(tag)
}

///|
fn Groups::tag(self : Groups, id : Int) -> @export.TagKind {
  self.tags[id].unwrap()
}

///|
fn Groups::take_tag(self : Groups, id : Int) -> @export.TagKind {
  let tag = self.tags[id].unwrap()
  self.tags[id] = None
  tag
}

///|
priv struct LocatedGroup {
  id : Int
  mut multiple_parents : Bool
}

///|
priv struct Group {
  /// The parent of this group. Must not be the direct parent in the concrete
  /// tag tree that will be built. But it must be an ancestor in the resulting
  /// tree. For example for a [`GroupKind::TableCell`] this will point to the
  /// parent [`GroupKind::Table`] even though the concrete tag tree will have
  /// intermediate [`TagKind::TR`] or [`TagKind::TBody`] groups in the
  /// generated `nodes`.
  mut parent : Int
  span : @syntax.Span
  kind : GroupKind
  /// The language of group kinds that have one (`GroupKind::has_lang`).
  mut lang : @library.Locale?
  /// Only mutate this list through the `Groups` API, to ensure the parent
  /// will be set for child groups.
  nodes : Array[TagNode]
  /// Whether this group was split off another group as a result of
  /// overlapping tags. A weak group will be omitted if it has no children.
  weak : Bool
}

///|
fn Group::new(
  parent : Int,
  span : @syntax.Span,
  kind : GroupKind,
  weak : Bool,
) -> Group {
  { parent, span, kind, lang: None, nodes: [], weak, }
}

///|
fn Group::push_leaf(self : Group, id : @export.Identifier) -> Unit {
  self.nodes.push(Leaf(id))
}

///|
fn Group::push_annotation(self : Group, annot_id : Int) -> Unit {
  self.nodes.push(Annotation(annot_id))
}

///|
fn Group::push_text(
  self : Group,
  new_attrs : ResolvedTextAttrs,
  text_id : @export.Identifier,
) -> Unit {
  if new_attrs.is_empty() {
    self.push_leaf(text_id)
    return
  }
  if self.nodes.last() is Some(Text(prev_attrs, nodes)) &&
    prev_attrs == new_attrs {
    nodes.push(text_id)
  } else {
    self.nodes.push(Text(new_attrs, [text_id]))
  }
}

///|
fn Group::pop_node(self : Group) -> TagNode? {
  self.nodes.pop()
}

///|
/// The language of the group, if the kind has one (upstream
/// `GroupKind::lang`).
fn Group::kind_lang(self : Group) -> @library.Locale?? {
  if self.kind.has_lang() {
    Some(self.lang)
  } else {
    None
  }
}

///|
priv enum GroupKind {
  Root
  Artifact(@export.ArtifactType)
  LogicalParent(@library.Content)
  /// The logical parent is resolved after the tree has been built.
  LogicalChild(@library.Inherit, Ref[Int])
  Outline(Int)
  OutlineEntry(@library.OutlineEntry)
  Table(Int, Int)
  TableCell(@library.TableCell, Int)
  Grid(Int)
  GridCell(@library.GridCell)
  List(Int, @export.ListNumbering)
  ListItemLabel
  ListItemBody
  TermsItemLabel
  TermsItemBody(Ref[Int?])
  BibEntry
  /// An wrapper element that enclosed the figure tag and its caption.
  /// If there is no caption, this is omitted.
  FigureWrapper(Int)
  Figure(Int, Int)
  /// The figure caption has a bbox so marked content sequences won't expand
  /// the bbox of the parent figure group kind. The caption might be moved
  /// into table, or next to the figure tag.
  FigureCaption(Int)
  Image(@library.ImageElem, Int)
  Formula(@library.EquationElem, Int)
  Link(@library.LinkMarker)
  CodeBlock
  CodeBlockLine
  /// A paragraph. A `weak` paragraph is omitted when it contains no
  /// children. This can happen when there are overlapping tags and a
  /// pragraph is split up.
  Par
  TextAttr(TextAttr)
  Transparent
  Standard(Int)
}

///|
fn GroupKind::is_artifact(self : GroupKind) -> Bool {
  self is Artifact(_)
}

///|
fn GroupKind::is_link(self : GroupKind) -> Bool {
  self is Link(_)
}

///|
fn GroupKind::is_figure(self : GroupKind) -> Bool {
  self is (Figure(_, _) | Image(_, _))
}

///|
fn GroupKind::to_artifact(
  self : GroupKind,
  options : CompletePdfOptions,
  page_size : @library.Axes[@library.Abs]?,
) -> @export.Artifact? {
  guard self is Artifact(artifact) else { return None }
  if options.version() == Pdf17 && artifact == Background {
    // Background artifacts were introduced in PDF 1.7. However,
    // they require a bounding box there, which may not be readily
    // available throughout Typst. In PDF 2.0, this requirement is
    // dropped. Hence, to not have to make up a bounding box, we
    // explicitly override the type as `Other` for PDF 1.7. For PDF
    // 1.6 and below, Krilla handles the type mapping. For PDF 2.0
    // and above, we use the correct artifact type.
    return Some(
      match page_size {
        Some(size) => {
          let bbox = @export.Rect::from_ltrb(
            0.0,
            0.0,
            f32(size.x.to_pt()),
            f32(size.y.to_pt()),
          ).unwrap()
          { kind: Background, bbox: Some(bbox), }
        }
        None => { kind: Other, bbox: None, }
      },
    )
  }
  Some({ kind: artifact, bbox: None, })
}

///|
fn GroupKind::as_link(self : GroupKind) -> @library.LinkMarker? {
  if self is Link(v) {
    Some(v)
  } else {
    None
  }
}

///|
fn GroupKind::as_table(self : GroupKind) -> Int? {
  if self is Table(id, _) {
    Some(id)
  } else {
    None
  }
}

///|
fn GroupKind::as_grid(self : GroupKind) -> Int? {
  if self is Grid(id) {
    Some(id)
  } else {
    None
  }
}

///|
fn GroupKind::as_list(self : GroupKind) -> Int? {
  if self is List(id, _) {
    Some(id)
  } else {
    None
  }
}

///|
fn GroupKind::bbox(self : GroupKind) -> Int? {
  match self {
    Table(_, id) => Some(id)
    Figure(_, id) => Some(id)
    FigureCaption(id) => Some(id)
    Image(_, id) => Some(id)
    Formula(_, id) => Some(id)
    _ => None
  }
}

///|
/// Whether the kind carries a language (upstream `GroupKind::lang` returning
/// `Some`).
fn GroupKind::has_lang(self : GroupKind) -> Bool {
  match self {
    Artifact(_)
    | LogicalParent(_)
    | LogicalChild(_, _)
    | FigureWrapper(_)
    | TextAttr(_)
    | Transparent => false
    _ => true
  }
}

///|
/// Whether this group is a semantic parent or child group. Non-semantic
/// groups will be ignored when searching the tree hierarchy.
fn GroupKind::is_semantic(self : GroupKind) -> Bool {
  // While paragraphs do have a semantic meaning, they are automatically
  // generated and may interfere with other more strongly structured
  // nesting groups. For example the `TermsItemLabel` might be wrapped by
  // a paragraph, out of which it is moved into the parent `LI`.
  !(self
  is (Transparent | LogicalParent(_) | LogicalChild(_, _) | TextAttr(_) | Par))
}
