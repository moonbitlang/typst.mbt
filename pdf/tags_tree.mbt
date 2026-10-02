// Port of `typst-pdf/src/tags/tree/mod.rs`.

///|
priv struct Tree {
  /// Points at the current group in the `progressions` list.
  mut prog_cursor : Int
  progressions : Array[Int]
  /// Points at the next break in the `breaks` list.
  mut break_cursor : Int
  breaks : Array[Break]
  /// Points at the next intem in the `unfinished` list.
  mut unfinished_cursor : Int
  unfinished : Array[Unfinished]
  /// A stack of traversal states, the topmost entry represents the current
  /// state in the tree. New stack entries are pushed on when entering a
  /// logical child and popped off when leaving one. Always non-empty.
  states : Array[TraversalState]
  groups : Groups
  ctx : Ctx
  logical_children : Map[@library.Location, Array[Int]]
  errors : Array[@library.SourceDiagnostic]
}

///|
fn Tree::empty(
  document : @layout.PagedDocument,
  options : CompletePdfOptions,
) -> Tree {
  TreeBuilder::new(document, options).finish()
}

///|
fn Tree::state(self : Tree) -> TraversalState {
  self.states[self.states.length() - 1]
}

///|
fn Tree::current(self : Tree) -> Int {
  self.progressions[self.prog_cursor]
}

///|
/// Find the lowest link ancestor in the tree.
fn Tree::parent_link(self : Tree) -> (Int, @library.LinkMarker)? {
  let mut current = self.current()
  while current != group_id_invalid {
    let group = self.groups.get(current)
    if group.kind.as_link() is Some(link) {
      return Some((current, link))
    }
    current = group.parent
  }
  None
}

///|
/// Find the highest artifact ancestor in the tree.
fn Tree::parent_artifact(self : Tree) -> @export.Artifact? {
  match self.state().current_artifact {
    Some((_, ty)) => Some(ty)
    None => None
  }
}

///|
/// Find the lowest ancestor with a bounding box in the tree.
fn Tree::parent_bbox(self : Tree) -> BBoxCtx? {
  match self.state().bbox_stack.last() {
    Some(id) => Some(self.ctx.bboxes[id])
    None => None
  }
}

///|
/// Whether an ancestor has an alternative description.
fn Tree::parent_alt(self : Tree) -> Int? {
  self.state().current_alt
}

///|
fn Tree::assert_finished_traversal(
  self : Tree,
) -> Unit raise @library.SourceError {
  if self.prog_cursor + 1 != self.progressions.length() ||
    self.break_cursor != self.breaks.length() ||
    self.unfinished_cursor != self.unfinished.length() {
    raise @library.SourceError([
      @library.SourceDiagnostic::error_at(
        @syntax.Span::detached(),
        "internal error: tree traversal didn't complete properly (occurred at crates/typst-pdf/src/tags/tree/mod.rs)",
      ).with_hint("please report this as a bug"),
    ])
  }
}

///|
/// Stores frequently accessed properties about the current tree traversal
/// position. This is an optimization to avoid searching all ancestors; instead
/// this is updated on each step.
priv struct TraversalState {
  /// The highest artifact ancestor in the tree.
  mut current_artifact : (Int, @export.Artifact)?
  /// The highest ancestor that has an alternative description.
  mut current_alt : Int?
  /// The stack of ancestors that have a [`GroupKind::bbox`].
  bbox_stack : Array[Int]
  /// The stack of text attributes.
  text_attrs : TextAttrs
}

///|
fn TraversalState::new() -> TraversalState {
  {
    current_artifact: None,
    current_alt: None,
    bbox_stack: [],
    text_attrs: TextAttrs::new(),
  }
}

///|
/// Update the traversal state when moving out of a group.
fn TraversalState::pop_group(
  self : TraversalState,
  surface : @export.Surface,
  id : Int,
  group : Group,
) -> Unit {
  if self.current_artifact is Some((i, _)) && i == id {
    self.current_artifact = None
    surface.end_tagged()
  }
  if self.current_alt is Some(i) && i == id {
    self.current_alt = None
  }
  if group.kind.bbox() is Some(bid) &&
    self.bbox_stack.last() is Some(last) &&
    last == bid {
    self.bbox_stack.pop() |> ignore
  }
  self.text_attrs.pop(id) |> ignore
}

///|
/// Marks a point where the entries on the stack were split up.
priv struct Break {
  /// The index of the progression at which point the broken up groups need to
  /// be closed.
  prog_idx : Int
  /// The number of groups which have to be closed, from the previous
  /// group upwards in the parent hierarchy.
  mut num_closed : Int
  /// The number of groups which have to be closed, from the next group
  /// upwards in the parent hierarchy.
  mut num_opened : Int
}

///|
/// Marks a point at the end of a logical child or parent where the stack was
/// not fully closed, and the open groups were handled in the next logical
/// child.
priv struct Unfinished {
  /// The index of the progression at which point the broken up groups need to
  /// be closed.
  prog_idx : Int
  group_to_close : Int
}

///|
fn step_start_tag(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
) -> Unit {
  let tree = gc.tags.tree
  guard step(tree) is Some((prev, next)) else { return }
  if consume_break(tree) is Some(brk) {
    step_break(gc, fc, surface, prev, next, brk)
  } else {
    open_group(
      tree.groups,
      tree.ctx,
      tree.state(),
      fc,
      gc.options,
      surface,
      next,
    )
  }
}

///|
fn step_end_tag(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
) -> Unit {
  let tree = gc.tags.tree
  guard step(tree) is Some((prev, next)) else { return }
  if consume_break(tree) is Some(brk) {
    step_break(gc, fc, surface, prev, next, brk)
  } else {
    close_group(tree, surface, prev) |> ignore
  }
}

///|
/// This can move to a completely different position in the tree.
fn enter_logical_child(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
) -> Unit {
  let tree = gc.tags.tree
  guard step(tree) is Some((_, next)) else { return }

  // Close any artifact in the previous location.
  if tree.parent_artifact() is Some(_) {
    surface.end_tagged()
  }

  // Compute the traversal state for the new location in the tree and push it.
  let new_state = TraversalState::new()
  let rev = []
  let mut current = next
  while current != group_id_invalid {
    rev.push(current)
    current = tree.groups.get(current).parent
  }
  open_multiple_groups(tree, new_state, fc, gc.options, surface, rev)
  tree.states.push(new_state)
}

///|
/// This moves back to the previous location in the tree.
fn leave_logical_child(tree : Tree, surface : @export.Surface) -> Unit {
  guard step(tree) is Some((prev, _)) else { return }

  // The stack within a logical child, could also be unfinished, in
  // which case a `BreakKind::Unfinished` is inserted to close the
  // `LogicalChild` group.
  if consume_unfinished(tree) is Some(unfinished) {
    close_group(tree, surface, unfinished.group_to_close) |> ignore
  } else {
    close_group(tree, surface, prev) |> ignore
  }

  // Close any artifact in the logical child.
  if tree.parent_artifact() is Some(_) {
    surface.end_tagged()
  }
  tree.states.pop() |> ignore

  // Reopen any artifact in the restored location of the tree.
  if tree.parent_artifact() is Some(ty) {
    surface.start_tagged(Artifact(ty)) |> ignore
  }
}

///|
fn step(tree : Tree) -> (Int, Int)? {
  let prev = tree.current()
  tree.prog_cursor += 1
  let next = tree.current()

  // We didn't move into a new group, no actions are necessary.
  if prev == next {
    return None
  }
  Some((prev, next))
}

///|
fn consume_break(tree : Tree) -> Break? {
  guard tree.breaks.get(tree.break_cursor) is Some(brk) else { return None }
  if brk.prog_idx == tree.prog_cursor {
    tree.break_cursor += 1
    return Some(brk)
  }
  None
}

///|
fn consume_unfinished(tree : Tree) -> Unfinished? {
  guard tree.unfinished.get(tree.unfinished_cursor) is Some(unfinished) else {
    return None
  }
  if unfinished.prog_idx == tree.prog_cursor {
    tree.unfinished_cursor += 1
    return Some(unfinished)
  }
  None
}

///|
fn step_break(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
  prev : Int,
  next : Int,
  brk : Break,
) -> Unit {
  let tree = gc.tags.tree
  // Close groups.
  let mut current = prev
  for _ in 0..<brk.num_closed {
    current = close_group(tree, surface, current)
  }

  // Open groups.
  let rev = []
  let mut current = next
  for _ in 0..<brk.num_opened {
    rev.push(current)
    current = tree.groups.get(current).parent
  }
  open_multiple_groups(tree, tree.state(), fc, gc.options, surface, rev)
}

///|
fn open_group(
  groups : Groups,
  ctx : Ctx,
  state : TraversalState,
  fc : FrameContext,
  options : CompletePdfOptions,
  surface : @export.Surface,
  id : Int,
) -> Unit {
  let group = groups.get(id)
  if state.current_artifact is None &&
    group.kind.to_artifact(options, fc.page_size()) is Some(ty) {
    state.current_artifact = Some((id, ty))
    surface.start_tagged(Artifact(ty)) |> ignore
  }
  if state.current_alt is None && ctx.alt(group.kind) is Some(_) {
    state.current_alt = Some(id)
  }
  if group.kind.bbox() is Some(bbox) {
    state.bbox_stack.push(bbox)
  }
  if group.kind is TextAttr(attr) {
    state.text_attrs.push(id, attr)
  }
}

///|
/// Since the groups need to be opened in order, but we can only iterate the
/// parent hierarchy from bottom to top, this cannot simply call [`open_group`].
fn open_multiple_groups(
  tree : Tree,
  state : TraversalState,
  fc : FrameContext,
  options : CompletePdfOptions,
  surface : @export.Surface,
  rev : Array[Int],
) -> Unit {
  let mut new_artifact = None
  let mut new_alt = None
  let bbox_start = state.bbox_stack.length()
  let text_attr_start = state.text_attrs.len()
  for id in rev {
    let group = tree.groups.get(id)
    if group.kind.to_artifact(options, fc.page_size()) is Some(ty) {
      new_artifact = Some((id, ty))
    }
    if tree.ctx.alt(group.kind) is Some(_) {
      new_alt = Some(id)
    }
    if group.kind.bbox() is Some(bbox) {
      state.bbox_stack.insert(bbox_start, bbox)
    }
    if group.kind is TextAttr(attr) {
      state.text_attrs.insert(text_attr_start, id, attr)
    }
  }
  if state.current_artifact is None && new_artifact is Some((_, ty)) {
    state.current_artifact = new_artifact
    surface.start_tagged(Artifact(ty)) |> ignore
  }
  if state.current_alt is None {
    state.current_alt = new_alt
  }
}

///|
fn close_group(tree : Tree, surface : @export.Surface, id : Int) -> Int {
  let group = tree.groups.get(id)
  let direct_parent = group.parent
  let semantic_parent = semantic_parent(tree, direct_parent)
  tree.state().pop_group(surface, id, group)
  match group.kind {
    Root => abort("unreachable")
    Artifact(_) => tree.groups.push_group(direct_parent, id)
    LogicalParent(elem) => {
      let loc = elem.location().unwrap()
      // Insert logical children when closing the logical parent, so they
      // are at the end of the group. In some cases there might be
      // multiple parent groups with the same location, only insert the
      // children for the first parent group.
      if tree.groups.by_loc(loc) is Some(located) &&
        located.id == id &&
        tree.logical_children.get(loc) is Some(children) {
        tree.groups.push_groups(id, children)
      }
      tree.groups.push_group(direct_parent, id)
    }
    LogicalChild(inherit_, logical_parent) =>
      if inherit_ == No {
        // If this logical child doesn't inherit its parent's styles and
        // is not inside of an artifact, inserting it into a parent that
        // is inside of an artifact would mean the content will be
        // discarded. If that's the case, ignore the logical parent
        // structure and insert it wherever it appeared in the frame
        // tree.
        let logical_parent_is_in_artifact = {
          let mut res = false
          let mut current = tree.groups.get(logical_parent.val).parent
          while current != group_id_invalid {
            let group = tree.groups.get(current)
            if group.kind.is_artifact() {
              res = true
              break
            }
            current = group.parent
          }
          res
        }
        if tree.parent_artifact() is None && logical_parent_is_in_artifact {
          tree.groups.push_group(direct_parent, id)
        }
      } else if !(tree.groups.get(direct_parent).kind is LogicalParent(_)) {
        // `GroupKind::LogicalParent` handles inserting of children at its
        // end, see above. Children of table/grid cells are always ordered
        // correctly and are treated a little bit differently.
        tree.groups.push_group(direct_parent, id)
      }
    Outline(_) => tree.groups.push_group(direct_parent, id)
    OutlineEntry(entry) =>
      if tree.groups.get(semantic_parent).kind is Outline(outline) {
        let outline_ctx = tree.ctx.outlines[outline]
        tree.groups.get(id).parent = semantic_parent
        outline_ctx.insert(tree.groups, semantic_parent, entry, id)
      } else {
        tree.groups.push_group(direct_parent, id)
      }
    Table(_, _) => tree.groups.push_group(direct_parent, id)
    TableCell(cell, tag) =>
      if move_into(tree, semantic_parent, id, k => k.as_table()) is Some(table) {
        let table_ctx = tree.ctx.tables[table]
        table_ctx.insert(cell, tag, id)
      } else {
        // Avoid panicking, the nesting will be validated later.
        tree.groups.push_group(direct_parent, id)
      }
    Grid(_) => tree.groups.push_group(direct_parent, id)
    GridCell(cell) =>
      if move_into(tree, semantic_parent, id, k => k.as_grid()) is Some(grid) {
        let grid_ctx = tree.ctx.grids[grid]
        grid_ctx.insert(cell, id)
      } else {
        // Avoid panicking, the nesting will be validated later.
        tree.groups.push_group(direct_parent, id)
      }
    List(_, _) => tree.groups.push_group(direct_parent, id)
    ListItemLabel =>
      if move_into(tree, semantic_parent, id, k => k.as_list()) is Some(list) {
        let list_ctx = tree.ctx.lists[list]
        list_ctx.push_label(tree.groups, semantic_parent, id)
      } else {
        // Avoid panicking, the nesting will be validated later.
        tree.groups.push_group(direct_parent, id)
      }
    ListItemBody =>
      if move_into(tree, semantic_parent, id, k => k.as_list()) is Some(list) {
        let list_ctx = tree.ctx.lists[list]
        list_ctx.push_body(tree.groups, semantic_parent, id)
      } else {
        // Avoid panicking, the nesting will be validated later.
        tree.groups.push_group(direct_parent, id)
      }
    TermsItemLabel =>
      if tree.groups.get(semantic_parent).kind is TermsItemBody(lbl) {
        lbl.val = Some(id)
      } else {
        // Avoid panicking, the nesting will be validated later.
        tree.groups.push_group(direct_parent, id)
      }
    TermsItemBody(lbl) =>
      if move_into(tree, semantic_parent, id, k => k.as_list()) is Some(list) {
        let list_ctx = tree.ctx.lists[list]
        if lbl.val is Some(lbl) {
          tree.groups.get(lbl).parent = semantic_parent
          list_ctx.push_label(tree.groups, semantic_parent, lbl)
        }
        list_ctx.push_body(tree.groups, semantic_parent, id)
      } else {
        // Avoid panicking, the nesting will be validated later.
        tree.groups.push_group(direct_parent, id)
      }
    BibEntry =>
      if move_into(tree, semantic_parent, id, k => k.as_list()) is Some(list) {
        let list_ctx = tree.ctx.lists[list]
        list_ctx.push_bib_entry(tree.groups, semantic_parent, id)
      } else {
        // Avoid panicking, the nesting will be validated later.
        tree.groups.push_group(direct_parent, id)
      }
    FigureWrapper(_) => abort("only generated below")
    Figure(figure, _) => {
      // Insert the wrapper.
      let kind = GroupKind::FigureWrapper(figure)
      let wrapper = tree.groups.new_virtual(direct_parent, group.span, kind)
      tree.groups.push_group(direct_parent, wrapper)

      // Push the figure into the wrapper.
      tree.groups.get(id).parent = wrapper
      tree.groups.push_group(wrapper, id)
    }
    FigureCaption(_) =>
      if tree.groups.get(semantic_parent).kind is Figure(figure, _) {
        let figure_ctx = tree.ctx.figures[figure]
        figure_ctx.captions.push(id)
      } else {
        tree.groups.push_group(direct_parent, id)
      }
    Image(_, _) => tree.groups.push_group(direct_parent, id)
    Formula(_, _) => tree.groups.push_group(direct_parent, id)
    Link(_) => {
      // Wrap link in reference tag if inside an outline entry.
      let mut parent = direct_parent
      if tree.groups.get(direct_parent).kind is OutlineEntry(_) {
        parent = tree.groups.push_tag(parent, new_tag(Reference))
      }
      tree.groups.push_group(parent, id)
    }
    CodeBlock => tree.groups.push_group(direct_parent, id)
    CodeBlockLine => tree.groups.push_group(direct_parent, id)
    Par => tree.groups.push_group(direct_parent, id)
    TextAttr(_) => tree.groups.push_group(direct_parent, id)
    Transparent => tree.groups.push_group(direct_parent, id)
    Standard(_) => tree.groups.push_group(direct_parent, id)
  }
  direct_parent
}

///|
fn[T] move_into(
  tree : Tree,
  semantic_parent : Int,
  child : Int,
  f : (GroupKind) -> T?,
) -> T? {
  let res = f(tree.groups.get(semantic_parent).kind)
  if res is Some(_) {
    tree.groups.get(child).parent = semantic_parent
  }
  res
}

///|
fn semantic_parent(tree : Tree, direct_parent : Int) -> Int {
  let mut parent = direct_parent
  while true {
    let group = tree.groups.get(parent)
    if group.kind.is_semantic() {
      return parent
    }
    parent = group.parent
  }
  parent
}
