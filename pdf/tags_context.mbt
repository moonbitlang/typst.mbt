// Port of `typst-pdf/src/tags/context/{mod,list,outline,figure,grid}.rs`.

///|
priv struct Tags {
  mut in_tiling : Bool
  tree : Tree
  /// A list of placeholders for annotations in the tag tree.
  annotations : Array[@export.Identifier?]
}

///|
fn Tags::new(tree : Tree) -> Tags {
  { in_tiling: false, tree, annotations: [], }
}

///|
fn Tags::push_leaf(self : Tags, id : @export.Identifier) -> Unit {
  self.tree.groups.get(self.tree.current()).push_leaf(id)
}

///|
fn Tags::push_text(
  self : Tags,
  new_attrs : ResolvedTextAttrs,
  text_id : @export.Identifier,
) -> Unit {
  self.tree.groups.get(self.tree.current()).push_text(new_attrs, text_id)
}

///|
fn Tags::reserve_annotation(self : Tags) -> Int {
  let id = self.annotations.length()
  self.annotations.push(None)
  id
}

///|
fn Tags::init_annotation(
  self : Tags,
  id : Int,
  annot : @export.Identifier,
) -> Unit {
  self.annotations[id] = Some(annot)
}

///|
fn Tags::take_annotation(self : Tags, id : Int) -> @export.Node {
  let annot = self.annotations[id].unwrap()
  self.annotations[id] = None
  Leaf(annot)
}

///|
priv struct Ctx {
  tables : Array[TableCtx]
  grids : Array[GridCtx]
  figures : Array[FigureCtx]
  lists : Array[ListCtx]
  outlines : Array[OutlineCtx]
  bboxes : Array[BBoxCtx]
}

///|
fn Ctx::new() -> Ctx {
  { tables: [], grids: [], figures: [], lists: [], outlines: [], bboxes: [], }
}

///|
fn Ctx::new_bbox(self : Ctx) -> Int {
  let id = self.bboxes.length()
  self.bboxes.push(BBoxCtx::new())
  id
}

///|
fn Ctx::bbox(self : Ctx, kind : GroupKind) -> BBoxCtx? {
  match kind.bbox() {
    Some(id) => Some(self.bboxes[id])
    None => None
  }
}

///|
fn Ctx::alt(self : Ctx, kind : GroupKind) -> String? {
  let styles = tags_styles()
  match kind {
    Figure(id, _) => self.figures[id].elem.alt(styles)
    Formula(formula, _) => formula.alt(styles)
    Image(image, _) => image.alt(styles)
    _ => None
  }
}

///|
priv struct BBoxCtx {
  /// The page index and the rectangle (min x, min y, max x, max y).
  mut rect : (Int, @library.Point, @library.Point)?
  mut multi_page : Bool
}

///|
fn BBoxCtx::new() -> BBoxCtx {
  { rect: None, multi_page: false, }
}

///|
fn BBoxCtx::copy(self : BBoxCtx) -> BBoxCtx {
  { rect: self.rect, multi_page: self.multi_page, }
}

///|
/// Expand the bounding box with a `rect` relative to the current frame
/// context transform.
fn BBoxCtx::expand_frame(
  self : BBoxCtx,
  fc : FrameContext,
  compute_rect : () -> @library.Rect,
) -> Unit {
  guard fc.page_idx is Some(page_idx) else { return }
  if self.multi_page {
    return
  }
  let (idx, min, max) = match self.rect {
    Some(r) => r
    None =>
      (
        page_idx,
        @library.Point::splat(@library.Abs::inf()),
        @library.Point::splat(@library.Abs::inf().neg()),
      )
  }
  if idx != page_idx {
    self.multi_page = true
    self.rect = None
    return
  }
  let rect = compute_rect()
  let size = rect.size()
  let mut min = min
  let mut max = max
  let ts = fc.state().transform
  for
    point in [
      rect.min,
      rect.min.add(@library.Point::with_x(size.x)),
      rect.min.add(@library.Point::with_y(size.y)),
      rect.max,
    ] {
    let p = point.transform(ts)
    min = min.min(p)
    max = max.max(p)
  }
  self.rect = Some((idx, min, max))
}

///|
/// Expand the bounding box with a rectangle that's already transformed into
/// page coordinates.
fn BBoxCtx::expand_page(self : BBoxCtx, inner : BBoxCtx) -> Unit {
  self.multi_page = self.multi_page || inner.multi_page
  if self.multi_page {
    return
  }
  guard inner.rect is Some((page_idx, rmin, rmax)) else { return }
  let (idx, min, max) = match self.rect {
    Some(r) => r
    None =>
      (
        page_idx,
        @library.Point::splat(@library.Abs::inf()),
        @library.Point::splat(@library.Abs::inf().neg()),
      )
  }
  if idx != page_idx {
    self.multi_page = true
    self.rect = None
    return
  }
  self.rect = Some((idx, min.min(rmin), max.max(rmax)))
}

///|
fn BBoxCtx::to_export(self : BBoxCtx) -> (Int, @export.Rect)? {
  guard self.rect is Some((page_idx, min, max)) else { return None }
  let rect = @export.Rect::from_ltrb(
    to_f32(min.x),
    to_f32(min.y),
    to_f32(max.x),
    to_f32(max.y),
  ).unwrap()
  Some((page_idx, rect))
}

///|
fn tags_context_finish(tree : Tree) -> Unit {
  for figure_id in 0..<tree.ctx.figures.length() {
    build_figure(tree, figure_id)
  }
  for table_id in 0..<tree.ctx.tables.length() {
    build_table(tree, table_id)
  }
  for grid_id in 0..<tree.ctx.grids.length() {
    build_grid(tree, grid_id)
  }
}

// --- context/list.rs ---

///|
priv struct ListCtx {
  /// The id of the `LI` tag of the last item.
  mut last_item : Int?
}

///|
fn ListCtx::new() -> ListCtx {
  { last_item: None, }
}

///|
fn ListCtx::push_label(
  self : ListCtx,
  groups : Groups,
  list : Int,
  label : Int,
) -> Unit {
  if self.last_item is Some(item) {
    self.last_item = None
    groups.push_tag(item, new_tag(LBody)) |> ignore
  }
  let parent = groups.push_tag(list, new_tag(LI))
  groups.push_group(parent, label)
  self.last_item = Some(parent)
}

///|
fn ListCtx::ensure_within_item(
  self : ListCtx,
  groups : Groups,
  list : Int,
) -> Int {
  if self.last_item is Some(item) {
    self.last_item = None
    item
  } else {
    let item = groups.push_tag(list, new_tag(LI))
    groups.push_tag(item, new_tag(Lbl)) |> ignore
    item
  }
}

///|
fn ListCtx::push_body(
  self : ListCtx,
  groups : Groups,
  list : Int,
  body : Int,
) -> Unit {
  let item = self.ensure_within_item(groups, list)
  groups.push_group(item, body)

  // Nested lists are expected to have the following structure:
  //
  // Typst code
  // ```
  // - a
  // - b
  //     - c
  //     - d
  // - e
  // ```
  //
  // Structure tree
  // ```
  // <L>
  //     <LI>
  //         <Lbl> `-`
  //         <LBody> `a`
  //     <LI>
  //         <Lbl> `-`
  //         <LBody> `b`
  //     <L>
  //         <LI>
  //             <Lbl> `-`
  //             <LBody> `c`
  //         <LI>
  //             <Lbl> `-`
  //             <LBody> `d`
  //     <LI>
  //         <Lbl> `-`
  //         <LBody> `d`
  // ```
  //
  // So move the nested list out of the list item.
  if groups.get(body).nodes.last() is Some(Group(id)) &&
    groups.get(id).kind is List(_, _) {
    groups.get(body).pop_node() |> ignore
    groups.get(id).parent = list
    groups.push_group(list, id)
  }
}

///|
fn ListCtx::push_bib_entry(
  self : ListCtx,
  groups : Groups,
  list : Int,
  bib_entry : Int,
) -> Unit {
  // Bibliography lists are always flat, so there is no need to check for
  // an inner list. If they do contain a list it is semantically unrelated
  // and can be left within the list body.
  let item = self.ensure_within_item(groups, list)
  let body = groups.push_tag(item, new_tag(LBody))
  groups.push_group(body, bib_entry)
}

// --- context/outline.rs ---

///|
priv struct OutlineCtx {
  /// The stack of nested `TOC` entries.
  stack : Array[Int]
}

///|
fn OutlineCtx::new() -> OutlineCtx {
  { stack: [], }
}

///|
fn OutlineCtx::insert(
  self : OutlineCtx,
  groups : Groups,
  outline_id : Int,
  entry : @library.OutlineEntry,
  entry_id : Int,
) -> Unit {
  let expected_len = entry.level().0.to_int() - 1
  let mut parent = self.stack.last().unwrap_or(outline_id)
  if self.stack.length() > expected_len {
    self.stack.truncate(expected_len)
  } else {
    while self.stack.length() < expected_len {
      parent = groups.push_tag(parent, new_tag(TOC))
      self.stack.push(parent)
    }
  }
  let parent = self.stack.last().unwrap_or(outline_id)
  groups.push_group(parent, entry_id)
}

// --- context/figure.rs ---

///|
/// Which tag should be used to represent this figure in the PDF tag tree.
///
/// There is a fundamental mismatch between Typst figures and PDF figures.
/// In Typst a figure is used to group some illustrative content, optionally give
/// it a caption, and often reference it by labelling it.
/// In PDF a figure is more comparable to an image, and in PDF/UA it *must* have
/// an alternative description. This alternative description *must* describe the
/// entire enclosed content and any AT will not attempt to interpret any content
/// within that tag. This makes the `Figure` tag completely unsuited for figures
/// that contain tables or other structured data.
priv enum FigureTagKind {
  /// Use a `Figure` tag.
  Figure
  /// Use a `Div` tag.
  Div
  /// Don't use any tag.
  NoTag
}

///|
priv struct FigureCtx {
  group_id : Int
  elem : @library.FigureElem
  mut captions : Array[Int]
  mut tag_kind : FigureTagKind
}

///|
fn FigureCtx::new(group_id : Int, elem : @library.FigureElem) -> FigureCtx {
  { group_id, elem, captions: [], tag_kind: Div, }
}

///|
fn FigureCtx::build_tag(self : FigureCtx) -> @export.TagKind? {
  let alt = self.elem.alt(tags_styles())
  match self.tag_kind {
    Figure => {
      let tag = new_tag(Figure)
      tag_set_alt_text(tag, alt)
      tag_set_placement(tag, Some(Block))
      Some(tag)
    }
    Div => {
      let tag = new_tag(Div)
      tag_set_alt_text(tag, alt)
      tag_set_placement(tag, Some(Block))
      Some(tag)
    }
    NoTag => None
  }
}

///|
/// Generate an enclosing `Div` tag if there is a caption.
fn FigureCtx::build_wrapper_tag(self : FigureCtx) -> @export.TagKind? {
  if self.captions.is_empty() {
    None
  } else {
    Some(new_tag(Div))
  }
}

///|
fn build_figure(tree : Tree, figure_id : Int) -> Unit {
  let figure_ctx = tree.ctx.figures[figure_id]
  let group = tree.groups.get(figure_ctx.group_id)
  let wrapper = group.parent
  if figure_ctx.elem.alt(tags_styles()) is Some(_) {
    // If a figure has an alternative description, always use the
    // figure tag.
    figure_ctx.tag_kind = Figure
  } else if single_semantic_child(tree.groups, group) is Some(child) {
    if tree.groups.get(child).kind is Table(_, _) {
      // Move the caption inside the table.
      let table = child
      let captions = figure_ctx.captions
      figure_ctx.captions = []
      for caption in captions {
        tree.groups.get(caption).parent = table
      }
      tree.groups.prepend_groups(table, captions)
    }

    // Omit an additional wrapping tag.
    figure_ctx.tag_kind = NoTag
  } else if !group.nodes.iter().any(n => n is Group(_)) {
    // The figure contains only marked content.
    figure_ctx.tag_kind = Figure
  }

  // Insert the captions inside the figure.
  // an enclosing element.
  if !figure_ctx.captions.is_empty() {
    for caption in figure_ctx.captions {
      tree.groups.get(caption).parent = wrapper
    }
    tree.groups.prepend_groups(wrapper, figure_ctx.captions)
  }
}

///|
fn single_semantic_child(groups : Groups, group : Group) -> Int? {
  let mut group = group
  while group.nodes is [Group(id)] {
    group = groups.get(id)
    if group.kind.is_semantic() {
      return Some(id)
    }
  }
  None
}

// --- context/grid.rs ---

///|
/// A cell of a `GridCells` grid.
priv struct CtxCell[D] {
  data : D
  x : Int
  y : Int
  rowspan : Int
  colspan : Int
  id : Int
}

///|
priv enum GridEntry[D] {
  Cell(CtxCell[D])
  Spanned(Int)
  Missing
}

///|
fn[D] GridEntry::as_cell(self : GridEntry[D]) -> CtxCell[D]? {
  if self is Cell(v) {
    Some(v)
  } else {
    None
  }
}

///|
fn[D] GridEntry::is_missing(self : GridEntry[D]) -> Bool {
  self is Missing
}

///|
priv struct GridCells[T] {
  width : Int
  entries : Array[GridEntry[T]]
}

///|
fn[T] GridCells::new(width : Int, height : Int) -> GridCells[T] {
  { width, entries: Array::make(width * height, Missing), }
}

///|
fn[T] GridCells::is_empty(self : GridCells[T]) -> Bool {
  self.entries.is_empty()
}

///|
fn[T] GridCells::width(self : GridCells[T]) -> Int {
  self.width
}

///|
fn[T] GridCells::height(self : GridCells[T]) -> Int {
  self.entries.length() / self.width
}

///|
fn[T] GridCells::row(self : GridCells[T], y : Int) -> ArrayView[GridEntry[T]] {
  self.entries[y * self.width:(y + 1) * self.width]
}

///|
fn[T] GridCells::cell(self : GridCells[T], x : Int, y : Int) -> CtxCell[T]? {
  let idx = self.cell_idx(x, y)
  match self.entries[idx] {
    Cell(c) => Some(c)
    Spanned(idx) => self.entries[idx].as_cell()
    Missing => None
  }
}

///|
/// The index of the parent cell entry at a position. The position must not
/// point to a `Missing` entry.
fn[T] GridCells::parent_idx(self : GridCells[T], x : Int, y : Int) -> Int {
  let idx = self.cell_idx(x, y)
  match self.entries[idx] {
    Cell(_) => idx
    Spanned(idx) => idx
    Missing => abort("unreachable")
  }
}

///|
fn[T] GridCells::resolve(
  self : GridCells[T],
  cell : GridEntry[T],
) -> CtxCell[T]? {
  match cell {
    Cell(cell) => Some(cell)
    Spanned(idx) => self.entries[idx].as_cell()
    Missing => None
  }
}

///|
fn[T] GridCells::insert(self : GridCells[T], cell : CtxCell[T]) -> Unit {
  let x = cell.x
  let y = cell.y
  let rowspan = cell.rowspan
  let colspan = cell.colspan
  let parent_idx = self.cell_idx(x, y)
  guard self.entries[parent_idx].is_missing() else { abort("cell is present") }

  // Store references to the cell for all spanned cells.
  for j in y..<(y + rowspan) {
    for i in x..<(x + colspan) {
      let idx = self.cell_idx(i, j)
      self.entries[idx] = Spanned(parent_idx)
    }
  }
  self.entries[parent_idx] = Cell(cell)
}

///|
fn[T] GridCells::cell_idx(self : GridCells[T], x : Int, y : Int) -> Int {
  y * self.width + x
}

///|
/// Convert from "effective" positions inside the cell grid, which may
/// include gutter tracks in addition to the cells, to conventional
/// positions.
fn grid_from_effective(grid : @library.CellGrid, i : Int) -> Int {
  if grid.has_gutter {
    i / 2
  } else {
    i
  }
}

///|
/// Convert from conventional positions to "effective" positions inside the
/// cell grid, which may include gutter tracks in addition to the cells.
fn grid_to_effective(grid : @library.CellGrid, i : Int) -> Int {
  if grid.has_gutter {
    2 * i
  } else {
    i
  }
}

///|
priv struct GridCtx {
  group_id : Int
  cells : GridCells[Unit]
}

///|
fn GridCtx::new(group_id : Int, grid : @library.GridElem) -> GridCtx {
  let grid = grid.grid().unwrap()
  let width = grid.non_gutter_column_count()
  let height = grid.non_gutter_row_count()
  { group_id, cells: GridCells::new(width, height), }
}

///|
fn GridCtx::insert(self : GridCtx, cell : @library.GridCell, id : Int) -> Unit {
  let styles = tags_styles()
  guard cell.x(styles) is Custom(x) && cell.y(styles) is Custom(y) else {
    abort("unreachable")
  }
  self.cells.insert({
    data: (),
    x: saturating_u32(x.0),
    y: saturating_u32(y.0),
    rowspan: saturating_u32(cell.rowspan(styles).0),
    colspan: saturating_u32(cell.colspan(styles).0),
    id,
  })
}

///|
fn saturating_u32(v : Int64) -> Int {
  if v > 0x7FFFFFFFL {
    0x7FFFFFFF
  } else {
    v.to_int()
  }
}

///|
fn build_grid(tree : Tree, grid_id : Int) -> Unit {
  let grid_ctx = tree.ctx.grids[grid_id]
  for entry in grid_ctx.cells.entries {
    if entry is Cell(cell) {
      tree.groups.push_group(grid_ctx.group_id, cell.id)
    }
  }
}
