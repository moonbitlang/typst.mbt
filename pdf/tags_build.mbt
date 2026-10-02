// Port of `typst-pdf/src/tags/tree/build.rs`.
//
// Building the logical tree.
//
// The tree of frames which is split up into pages doesn't necessarily
// represent the logical structure of the Typst document. The logical structure
// is instead defined by the start and end introspection tags and additional
// insertions of frames by the means of `Frame::set_parent`. These inserted
// frames resolve to groups of kind `GroupKind::LogicalChild`.
//
// This module resolves the logical structure in a pre-pass, so that the
// complete logical tree is available when the document's content is converted.

///|
priv struct TreeBuilder {
  options : CompletePdfOptions
  /// Each `FrameItem::Tag` and each `FrameItem::Group` with a parent
  /// will append a progression to this tree. This list of progressions is
  /// used to determine the location in the tree when doing the actual PDF
  /// generation and inserting the marked content sequences.
  progressions : Array[Int]
  breaks : Array[Break]
  unfinished : Array[Unfinished]
  groups : Groups
  ctx : Ctx
  logical_children : Map[@library.Location, Array[Int]]
  errors : Array[@library.SourceDiagnostic]
  stack : Array[StackEntry]
  /// Currently only used for table/grid cells that are broken across multiple
  /// regions, and thus can have opening/closing introspection tags that are
  /// in completely different frames, due to the logical parenting mechanism.
  unfinished_stacks : Map[@library.Location, Array[StackEntry]]
}

///|
fn TreeBuilder::new(
  document : @layout.PagedDocument,
  options : CompletePdfOptions,
) -> TreeBuilder {
  let doc_lang = match document.info().locale {
    Custom(l) => Some(l)
    Auto => None
  }
  let groups = Groups::new()
  let doc = groups.new_virtual(group_id_invalid, @syntax.Span::detached(), Root)
  groups.get(doc).lang = doc_lang
  {
    options,
    progressions: [doc],
    breaks: [],
    unfinished: [],
    groups,
    ctx: Ctx::new(),
    logical_children: {},
    errors: [],
    stack: [],
    unfinished_stacks: {},
  }
}

///|
fn TreeBuilder::finish(self : TreeBuilder) -> Tree {
  {
    prog_cursor: 0,
    progressions: self.progressions,
    break_cursor: 0,
    breaks: self.breaks,
    unfinished_cursor: 0,
    unfinished: self.unfinished,
    states: [TraversalState::new()],
    groups: self.groups,
    ctx: self.ctx,
    logical_children: self.logical_children,
    errors: self.errors,
  }
}

///|
fn TreeBuilder::root_document(self : TreeBuilder) -> Int {
  self.progressions[0]
}

///|
/// The last group in the progression.
fn TreeBuilder::current(self : TreeBuilder) -> Int {
  self.progressions[self.progressions.length() - 1]
}

///|
/// The last group on the stack or the root document.
fn TreeBuilder::parent(self : TreeBuilder) -> Int {
  match self.stack.last() {
    Some(e) => e.id
    None => self.root_document()
  }
}

///|
fn TreeBuilder::parent_kind(self : TreeBuilder) -> GroupKind {
  self.groups.get(self.parent()).kind
}

///|
priv struct StackEntry {
  /// The location of the stack entry. If this is `None` the stack entry has
  /// to be manually popped.
  loc : @library.Location?
  id : Int
  prog_idx : Int
}

///|
fn internal_error(
  span : @syntax.Span,
  msg : String,
  file : String,
) -> @library.SourceError {
  @library.SourceError([
    @library.SourceDiagnostic::error_at(
      span,
      "internal error: \{msg} (occurred at crates/typst-pdf/src/\{file})",
    ).with_hint("please report this as a bug"),
  ])
}

///|
fn build_tree(
  document : @layout.PagedDocument,
  options : CompletePdfOptions,
) -> Tree raise @library.SourceError {
  let tree = TreeBuilder::new(document, options)
  for page in document.pages() {
    visit_frame(tree, page.frame)
  }
  if tree.stack.last() is Some(last) {
    raise internal_error(
      tree.groups.get(last.id).span,
      "tags weren't properly closed",
      "tags/tree/build.rs",
    )
  }
  if !tree.unfinished_stacks.is_empty() ||
    tree.progressions[0] != tree.progressions[tree.progressions.length() - 1] {
    raise internal_error(
      @syntax.Span::detached(),
      "tags weren't properly closed",
      "tags/tree/build.rs",
    )
  }

  // Insert logical children into the tree.
  for loc, children in tree.logical_children {
    guard tree.groups.by_loc(loc) is Some(located) else {
      raise internal_error(
        @syntax.Span::detached(),
        "parent group",
        "tags/tree/build.rs",
      )
    }
    if options.validators().ua is Some(a11y) && located.multiple_parents {
      let validator = accessibility_as_str(a11y)
      let group = tree.groups.get(located.id)
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          group.span,
          "\{validator} error: ambiguous logical parent",
        ).with_hint("please report this as a bug"),
      ])
    }
    for child in children {
      let child = tree.groups.get(child)
      guard child.kind is LogicalChild(inherit_, logical_parent) else {
        abort("unreachable")
      }
      logical_parent.val = located.id

      // Move the child into its logical parent, so artifact, bbox, and
      // text attributes are inherited.
      if inherit_ == Yes {
        child.parent = located.id
      }
    }
  }
  tree.finish()
}

///|
fn visit_frame(
  tree : TreeBuilder,
  frame : @library.Frame,
) -> Unit raise @library.SourceError {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => visit_group_frame(tree, group)
      Tag(Start(elem, flags)) => if flags.tagged { visit_start_tag(tree, elem) }
      Tag(End(loc, _, flags)) => if flags.tagged { visit_end_tag(tree, loc) }
      Text(_) => ()
      Shape(_, _) => ()
      Image(_, _, _) => ()
      Link(_, _) => ()
    }
  }
}

///|
/// Handle children frames logically belonging to another element, because
/// `GroupItem::parent` has been set. All elements that can have children set
/// by this mechanism must be handled in `tags_handle_start` and must produce a
/// located `Group`, so the children can be inserted there.
///
/// Currently the frame parent is only set for:
/// - place elements `PlaceElem`
/// - footnote entries `FootnoteEntry`
/// - broken table/grid cells `TableCell`/`GridCell`
fn visit_group_frame(
  tree : TreeBuilder,
  group : @library.GroupItem,
) -> Unit raise @library.SourceError {
  guard group.parent is Some(parent) else {
    return visit_frame(tree, group.frame)
  }

  // Push the logical child.
  let prev = tree.current()
  let stack_idx = tree.stack.length()
  let id = push_logical_child(tree, parent)
  tree.progressions.push(id)

  // Handle the group frame.
  visit_frame(tree, group.frame)

  // Pop logical child.
  pop_logical_child(tree, parent, stack_idx)
  tree.progressions.push(prev)
}

///|
fn push_logical_child(tree : TreeBuilder, parent : @library.FrameParent) -> Int {
  let id = tree.groups.new_virtual(
    match parent.inherit_ {
      Yes => group_id_invalid
      No => tree.current()
    },
    @syntax.Span::detached(),
    LogicalChild(parent.inherit_, Ref::new(group_id_invalid)),
  )
  match tree.logical_children.get(parent.location) {
    Some(children) => children.push(id)
    None => tree.logical_children[parent.location] = [id]
  }
  push_stack_entry(tree, None, id) |> ignore
  if tree.unfinished_stacks.get(parent.location) is Some(stack) {
    tree.unfinished_stacks.remove(parent.location)
    for e in stack {
      tree.stack.push(e)
    }
  }
  // Move to the top of the stack, including the pushed on unfinished stack.
  tree.stack[tree.stack.length() - 1].id
}

///|
fn pop_logical_child(
  tree : TreeBuilder,
  parent : @library.FrameParent,
  stack_idx : Int,
) -> Unit {
  // Remove all stack entries after the idx.
  if stack_idx + 1 < tree.stack.length() {
    let stack = []
    for i in (stack_idx + 1)..<tree.stack.length() {
      stack.push(tree.stack[i])
    }
    tree.stack.truncate(stack_idx + 1)
    tree.unfinished_stacks[parent.location] = stack
    tree.unfinished.push({
      prog_idx: tree.progressions.length(),
      group_to_close: tree.stack[stack_idx].id,
    })
  }
  tree.stack.pop().unwrap() |> ignore
}

///|
fn visit_start_tag(tree : TreeBuilder, elem : @library.Content) -> Unit {
  let group_id = progress_tree_start(tree, elem)
  tree.progressions.push(group_id)
}

///|
fn visit_end_tag(
  tree : TreeBuilder,
  loc : @library.Location,
) -> Unit raise @library.SourceError {
  let group = progress_tree_end(tree, loc)
  tree.progressions.push(group)
}

///|
fn progress_tree_start(tree : TreeBuilder, elem : @library.Content) -> Int {
  let styles = tags_styles()
  // Artifacts
  if @library.HideElem::of(elem) is Some(_) {
    push_artifact(tree, elem, Other)
  } else if @library.ArtifactElem::of(elem) is Some(artifact) {
    let kind = artifact.kind(styles)
    push_artifact(tree, elem, artifact_kind_to_export(kind))
  } else if @library.RepeatElem::of(elem) is Some(_) {
    push_artifact(tree, elem, Layout)

    // Elements
  } else if @library.PdfPdfMarkerTag::of(elem) is Some(tag) {
    match tag.kind() {
      OutlineBody => {
        let id = tree.ctx.outlines.length()
        tree.ctx.outlines.push(OutlineCtx::new())
        push_group(tree, elem, Outline(id))
      }
      Bibliography(numbered) => {
        let numbering : @export.ListNumbering = if numbered {
          Decimal
        } else {
          NoNumbering
        }
        let id = tree.ctx.lists.length()
        tree.ctx.lists.push(ListCtx::new())
        push_group(tree, elem, List(id, numbering))
      }
      BibEntry => push_group(tree, elem, BibEntry)
      ListItemLabel => push_group(tree, elem, ListItemLabel)
      ListItemBody => push_group(tree, elem, ListItemBody)
      TermsItemLabel => push_group(tree, elem, TermsItemLabel)
      TermsItemBody => push_group(tree, elem, TermsItemBody(Ref::new(None)))
      Label => push_tag(tree, elem, new_tag(Lbl))
    }
  } else if @library.LinkMarker::of(elem) is Some(link) {
    push_group(tree, elem, Link(link))
  } else if @library.TitleElem::of(elem) is Some(_) {
    push_tag(tree, elem, new_tag(Title))
  } else if @library.OutlineEntry::of(elem) is Some(entry) {
    push_group(tree, elem, OutlineEntry(entry))
  } else if @library.ListElem::of(elem) is Some(_) {
    // TODO: infer numbering from `list.marker`
    let id = tree.ctx.lists.length()
    tree.ctx.lists.push(ListCtx::new())
    push_group(tree, elem, List(id, Circle))
  } else if @library.EnumElem::of(elem) is Some(_) {
    // TODO: infer numbering from `enum.numbering`
    let id = tree.ctx.lists.length()
    tree.ctx.lists.push(ListCtx::new())
    push_group(tree, elem, List(id, Decimal))
  } else if @library.TermsElem::of(elem) is Some(_) {
    let id = tree.ctx.lists.length()
    tree.ctx.lists.push(ListCtx::new())
    push_group(tree, elem, List(id, NoNumbering))
  } else if @library.FigureElem::of(elem) is Some(figure) {
    let lang = figure.locale()
    let bbox = tree.ctx.new_bbox()
    let group_id = tree.groups.next_id()
    let figure_id = tree.ctx.figures.length()
    tree.ctx.figures.push(FigureCtx::new(group_id, figure))
    push_group(tree, elem, Figure(figure_id, bbox), lang~)
  } else if @library.FigureCaption::of(elem) is Some(_) {
    let bbox = tree.ctx.new_bbox()
    push_group(tree, elem, FigureCaption(bbox))
  } else if @library.ImageElem::of(elem) is Some(image) {
    let lang = image.locale()
    let bbox = tree.ctx.new_bbox()
    push_group(tree, elem, Image(image, bbox), lang~)
  } else if @library.EquationElem::of(elem) is Some(equation) {
    let lang = equation.locale()
    let bbox = tree.ctx.new_bbox()
    push_group(tree, elem, Formula(equation, bbox), lang~)
  } else if @library.TableElem::of(elem) is Some(table) {
    let group_id = tree.groups.next_id()
    let table_id = tree.ctx.tables.length()
    tree.ctx.tables.push(TableCtx::new(group_id, table_id, table))
    let bbox = tree.ctx.new_bbox()
    push_group(tree, elem, Table(table_id, bbox))
  } else if @library.TableCell::of(elem) is Some(cell) {
    // Only repeated table headers and footer cells are laid out multiple
    // times. Mark duplicate headers as artifacts, since they have no
    // semantic meaning in the tag tree, which doesn't use page breaks for
    // it's semantic structure.
    let kind : GroupKind = if cell.is_repeated(styles) {
      Artifact(PaginationOther)
    } else {
      let tag = tree.groups.push_tag_storage(new_tag(TD))
      TableCell(cell, tag)
    }
    push_located(tree, elem, kind)
  } else if @library.GridElem::of(elem) is Some(grid) {
    let group_id = tree.groups.next_id()
    let id = tree.ctx.grids.length()
    tree.ctx.grids.push(GridCtx::new(group_id, grid))
    push_group(tree, elem, Grid(id))
  } else if @library.GridCell::of(elem) is Some(cell) {
    // The grid cells are collected into a grid to ensure proper reading
    // order even when using rowspans, which may be laid out later than
    // other cells in the same row.
    let kind : GroupKind = if !(tree.parent_kind() is Grid(_)) {
      // If there is no grid parent, this means a grid layouter is used
      // internally.
      Transparent
    } else if cell.is_repeated(styles) {
      // Only repeated grid headers and footer cells are laid out multiple
      // times. Mark duplicate headers as artifacts, since they have no
      // semantic meaning in the tag tree, which doesn't use page breaks
      // for it's semantic structure.
      Artifact(PaginationOther)
    } else {
      GridCell(cell)
    }
    push_located(tree, elem, kind)
  } else if @library.HeadingElem::of(elem) is Some(heading) {
    let level = heading.resolve_level(styles).0
    let level = if level > 65535L { 65535 } else { level.to_int() }
    let title = heading.body().plain_text()
    if title.is_empty() && tree.options.validators().ua is Some(accessibility) {
      let contains_context = !heading
        .body()
        .traverse(c => @library.ContextElem::of(c) is None)
      let validator = accessibility_as_str(accessibility)
      tree.errors.push(
        if contains_context {
          @library.SourceDiagnostic::error_at(
            heading.pack().span(),
            "\{validator} error: heading title could not be determined",
          ).with_hints([
            "this seems to be caused by a context expression within the heading",
            "consider wrapping the entire heading in a context expression instead",
          ])
        } else {
          @library.SourceDiagnostic::error_at(
            heading.pack().span(),
            "\{validator} error: heading title is empty",
          )
        },
      )
    }
    push_tag(
      tree,
      elem,
      new_tag(Hn).with_attr(HeadingLevel(level)).with_attr(Title(title)),
    )
  } else if @library.FootnoteElem::of(elem) is Some(_) {
    push_located(tree, elem, LogicalParent(elem))
  } else if @library.FootnoteEntry::of(elem) is Some(_) {
    push_tag(tree, elem, new_tag(Note))
  } else if @library.QuoteElem::of(elem) is Some(quote) {
    // TODO: should the attribution be handled somehow?
    if quote.block(styles) {
      push_tag(tree, elem, new_tag(BlockQuote))
    } else {
      push_tag(tree, elem, new_tag(InlineQuote))
    }
  } else if @library.RawElem::of(elem) is Some(raw) {
    if raw.block(styles) {
      push_group(tree, elem, CodeBlock)
    } else {
      push_tag(tree, elem, new_tag(Code))
    }
  } else if @library.RawLine::of(elem) is Some(_) {
    // If the raw element is inline, the content can be inserted directly.
    if tree.parent_kind() is CodeBlock {
      push_group(tree, elem, CodeBlockLine)
    } else {
      no_progress(tree)
    }
  } else if @library.PlaceElem::of(elem) is Some(place) {
    if place.float(styles) {
      push_located(tree, elem, LogicalParent(elem))
    } else {
      no_progress(tree)
    }
  } else if @library.ParElem::of(elem) is Some(_) {
    push_weak(tree, elem, Par)

    // Text attributes
  } else if @library.StrongElem::of(elem) is Some(_) {
    push_text_attr(tree, elem, Strong)
  } else if @library.EmphElem::of(elem) is Some(_) {
    push_text_attr(tree, elem, Emph)
  } else if @library.SubElem::of(elem) is Some(sub) {
    push_text_attr(tree, elem, SubScript(sub))
  } else if @library.SuperElem::of(elem) is Some(sup) {
    push_text_attr(tree, elem, SuperScript(sup))
  } else if @library.HighlightElem::of(elem) is Some(highlight) {
    push_text_attr(tree, elem, Highlight(highlight))
  } else if @library.UnderlineElem::of(elem) is Some(underline) {
    push_text_attr(tree, elem, Underline(underline))
  } else if @library.OverlineElem::of(elem) is Some(overline) {
    push_text_attr(tree, elem, Overline(overline))
  } else if @library.StrikeElem::of(elem) is Some(strike) {
    push_text_attr(tree, elem, Strike(strike))
  } else {
    no_progress(tree)
  }
}

///|
fn no_progress(tree : TreeBuilder) -> Int {
  tree.current()
}

///|
fn push_tag(
  tree : TreeBuilder,
  elem : @library.Content,
  tag : @export.TagKind,
) -> Int {
  let id = tree.groups.push_tag_storage(tag)
  push_group(tree, elem, Standard(id))
}

///|
fn push_text_attr(
  tree : TreeBuilder,
  elem : @library.Content,
  attr : TextAttr,
) -> Int {
  push_group(tree, elem, TextAttr(attr))
}

///|
fn push_artifact(
  tree : TreeBuilder,
  elem : @library.Content,
  ty : @export.ArtifactType,
) -> Int {
  push_group(tree, elem, Artifact(ty))
}

///|
fn push_group(
  tree : TreeBuilder,
  elem : @library.Content,
  kind : GroupKind,
  lang? : @library.Locale? = None,
) -> Int {
  let loc = elem.location().unwrap()
  let span = elem.span()
  let parent = tree.current()
  let id = tree.groups.new_virtual(parent, span, kind)
  tree.groups.get(id).lang = lang
  push_stack_entry(tree, Some(loc), id)
}

///|
fn push_located(
  tree : TreeBuilder,
  elem : @library.Content,
  kind : GroupKind,
) -> Int {
  let loc = elem.location().unwrap()
  let span = elem.span()
  let parent = tree.current()
  let id = tree.groups.new_located(loc, parent, span, kind)
  push_stack_entry(tree, Some(loc), id)
}

///|
fn push_weak(
  tree : TreeBuilder,
  elem : @library.Content,
  kind : GroupKind,
) -> Int {
  let loc = elem.location().unwrap()
  let span = elem.span()
  let parent = tree.current()
  let id = tree.groups.new_weak(parent, span, kind)
  push_stack_entry(tree, Some(loc), id)
}

///|
fn push_stack_entry(
  tree : TreeBuilder,
  loc : @library.Location?,
  id : Int,
) -> Int {
  let prog_idx = tree.progressions.length()
  tree.stack.push({ loc, id, prog_idx, })
  id
}

///|
fn progress_tree_end(
  tree : TreeBuilder,
  loc : @library.Location,
) -> Int raise @library.SourceError {
  if tree.stack.last() is Some(e) && e.loc == Some(loc) {
    tree.stack.pop() |> ignore
    // The tag nesting was properly closed.
    return tree.parent()
  }

  // Search for an improperly nested starting tag, that is being closed.
  let mut stack_idx = -1
  for i = tree.stack.length() - 1; i >= 0; i = i - 1 {
    if tree.stack[i].loc == Some(loc) {
      stack_idx = i
      break
    }
  }
  if stack_idx < 0 {
    // The start tag isn't in the tag stack, just ignore the end tag.
    return no_progress(tree)
  }
  let entry = tree.stack[stack_idx]
  let outer = tree.groups.get(entry.id)

  // There are overlapping tags in the tag tree. Figure out whether breaking
  // up the current tag stack is semantically ok, and how to do it.
  let is_pdf_ua = tree.options.validators().ua is Some(_)
  let mut inner_break_priority : BreakPriority? = Some(break_priority_max)
  let mut inner_non_breakable_span = @syntax.Span::detached()
  let mut inner_non_breakable_in_pdf_ua = false
  for i in (stack_idx + 1)..<tree.stack.length() {
    let e = tree.stack[i]
    let group = tree.groups.get(e.id)
    let opportunity = tree.groups.breakable(group.kind)
    guard opportunity.get(is_pdf_ua) is Some(priority) else {
      if inner_non_breakable_span.is_detached() {
        inner_non_breakable_span = group.span
      }
      if opportunity is NoPdfUa(_) {
        inner_non_breakable_in_pdf_ua = true
      }
      inner_break_priority = None
      continue
    }
    if inner_break_priority is Some(inner) {
      inner_break_priority = Some(
        if priority < inner {
          priority
        } else {
          inner
        },
      )
    }
  }
  let outer_break_opportunity = tree.groups.breakable(outer.kind)
  let outer_break_priority = outer_break_opportunity.get(is_pdf_ua)
  match (outer_break_priority, inner_break_priority) {
    (Some(outer_priority), Some(inner_priority)) =>
      // Prefer splitting up the inner groups.
      if inner_priority >= outer_priority {
        split_inner_groups(tree, outer.parent, stack_idx)
      } else {
        split_outer_group(tree, outer.parent, stack_idx)
      }
    (Some(_), None) => split_outer_group(tree, outer.parent, stack_idx)
    (None, Some(_)) => split_inner_groups(tree, outer.parent, stack_idx)
    (None, None) => {
      let non_breakable_span = if inner_non_breakable_span.is_detached() {
        outer.span
      } else {
        inner_non_breakable_span
      }
      let non_breakable_in_pdf_ua = inner_non_breakable_in_pdf_ua ||
        outer_break_opportunity is NoPdfUa(_)
      if non_breakable_in_pdf_ua {
        let validator = validators_to_comma_list(tree.options.validators())
        raise @library.SourceError([
          @library.SourceDiagnostic::error_at(
            non_breakable_span,
            "\{validator} error: invalid document structure, this element's PDF tag would be split up",
          ).with_hints([
            "this is probably caused by paragraph grouping", "maybe you've used a `parbreak`, `colbreak`, or `pagebreak`",
          ]),
        ])
      } else {
        raise @library.SourceError([
          @library.SourceDiagnostic::error_at(
            non_breakable_span, "invalid document structure, this element's PDF tag would be split up",
          ).with_hint("please report this as a bug"),
        ])
      }
    }
  }
}

///|
/// Consider the following introspection tags:
/// ```txt
/// start a
///   start b
///     start c
/// end   a
///     end   c
///   end   b
/// ```
/// This will split the inner groups, producing the following tag tree:
/// ```yml
/// - a:
///   - b:
///     - c:
/// - b:
///   - c:
/// ```
fn split_inner_groups(tree : TreeBuilder, parent : Int, stack_idx : Int) -> Int {
  let mut parent = parent
  // Since the broken groups won't be visited again in any future progression,
  // they'll need to be closed when this progression is visited.
  let num_closed = tree.stack.length() - stack_idx
  tree.breaks.push({
    prog_idx: tree.progressions.length(),
    num_closed,
    num_opened: num_closed - 1,
  })

  // Remove the closed entry.
  tree.stack.remove(stack_idx) |> ignore

  // Duplicate all broken entries.
  for i in stack_idx..<tree.stack.length() {
    let entry = tree.stack[i]
    let new_id = tree.groups.break_group(entry.id, parent)
    tree.stack[i] = {
      loc: entry.loc,
      id: new_id,
      prog_idx: tree.progressions.length(),
    }
    parent = new_id
  }

  // We're now in a new duplicated group
  tree.parent()
}

///|
/// Consider the following introspection tags:
/// ```txt
/// OPEN a
///   OPEN b
///     OPEN c
/// END  a
///     END  c
///   END  b
/// ```
/// This will split the outer group, producing the following tag tree:
/// ```yml
/// - a:
/// - b:
///   - a:
///   - c:
///     - a:
/// ```
fn split_outer_group(tree : TreeBuilder, parent : Int, stack_idx : Int) -> Int {
  // Remove the closed entry;
  let outer = tree.stack.remove(stack_idx)

  // Move the nested group out of the outer entry.
  tree.groups.get(tree.stack[stack_idx].id).parent = parent
  for k in stack_idx..<tree.stack.length() {
    let entry = tree.stack[k]
    let next_entry = if k + 1 < tree.stack.length() {
      Some(tree.stack[k + 1].id)
    } else {
      None
    }
    let nested = tree.groups.break_group(outer.id, entry.id)

    // Move all children of the stack entry into the nested group.
    for id = tree.groups.list.length() - 1; id >= 0; id = id - 1 {
      // Avoid searching *all* groups! The children of this group are
      // guaranteed to be created after the outer group and thus have a
      // higher ID.
      if id == outer.id {
        break
      }
      let group = tree.groups.list[id]

      // Don't move the nested group into itself, or the next stack entry
      // into the nested group.
      if group.parent == entry.id && id != nested && Some(id) != next_entry {
        group.parent = nested
      }
    }

    // Update progressions to jump into the inner entry instead.
    let prev = entry.id
    for i in entry.prog_idx..<tree.progressions.length() {
      if tree.progressions[i] == prev {
        tree.progressions[i] = nested
      }
    }

    // Either update an existing break, or insert a new one.
    let mut break_idx : Int? = Some(tree.breaks.length())
    for i = tree.breaks.length() - 1; i >= 0; i = i - 1 {
      let brk = tree.breaks[i]
      if brk.prog_idx == entry.prog_idx {
        brk.num_closed += 1
        brk.num_opened += 1
        break_idx = None
        break
      } else if brk.prog_idx < entry.prog_idx {
        break_idx = Some(i + 1)
        break
      }
    }
    if break_idx is Some(idx) {
      // Insert a break to close the previous broken group, and enter
      // the new group.
      tree.breaks.insert(idx, {
        prog_idx: entry.prog_idx,
        num_closed: 1,
        num_opened: 2,
      })
    }
  }

  // We're still in the same group, but the outer group has been split up.
  tree.parent()
}
