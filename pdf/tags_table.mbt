// Port of `typst-pdf/src/tags/context/table.rs`.

///|
priv struct TableCtx {
  group_id : Int
  table_id : Int
  elem : @library.TableElem
  row_kinds : Array[@library.TableCellKind]
  cells : GridCells[TableCellData]
  mut border_thickness : Double?
  mut border_color : @export.NaiveRgbColor?
}

///|
priv struct TableCellData {
  tag : Int
  kind : @library.TableCellKind
  headers : Array[Bytes]
  stroke : SidesMut
}

///|
/// The prioritized strokes of the four sides of a cell (upstream
/// `Sides<PrioritzedStroke>`).
priv struct SidesMut {
  mut left : PrioritzedStroke
  mut top : PrioritzedStroke
  mut right : PrioritzedStroke
  mut bottom : PrioritzedStroke
}

///|
fn SidesMut::to_array(self : SidesMut) -> Array[PrioritzedStroke] {
  [self.left, self.top, self.right, self.bottom]
}

///|
priv struct PrioritzedStroke {
  stroke : @library.ResolvedStroke?
  priority : StrokePriority
}

///|
priv enum StrokePriority {
  GridStroke
  CellStroke
  ExplicitLine
} derive(Eq, Compare)

///|
fn TableCtx::new(
  group_id : Int,
  table_id : Int,
  table : @library.TableElem,
) -> TableCtx {
  let grid = table.grid().unwrap()
  let width = grid.non_gutter_column_count()
  let height = grid.non_gutter_row_count()

  // Generate the default row kinds.
  let headers = grid.headers
  let mut hi = 0
  let default_row_kinds = []
  for y in 0..<height {
    let grid_y = grid_to_effective(grid, y)

    // Find current header
    while hi < headers.length() && headers[hi].inner.range.end <= grid_y {
      hi += 1
    }
    if hi < headers.length() && headers[hi].inner.range.contains(grid_y) {
      default_row_kinds.push(
        @library.TableCellKind::Header(headers[hi].inner.level, Column),
      )
      continue
    }
    if grid.footer is Some(footer) && footer.inner.range().contains(grid_y) {
      default_row_kinds.push(@library.TableCellKind::Footer)
      continue
    }
    default_row_kinds.push(@library.TableCellKind::Data)
  }
  {
    group_id,
    table_id,
    elem: table,
    row_kinds: default_row_kinds,
    cells: GridCells::new(width, height),
    border_thickness: None,
    border_color: None,
  }
}

///|
fn TableCtx::insert(
  self : TableCtx,
  cell : @library.TableCell,
  tag : Int,
  id : Int,
) -> Unit {
  let styles = tags_styles()
  guard cell.x(styles) is Custom(x) && cell.y(styles) is Custom(y) else {
    abort("unreachable")
  }
  let x = saturating_u32(x.0)
  let y = saturating_u32(y.0)
  let rowspan = saturating_u32(cell.rowspan(styles).0)
  let colspan = saturating_u32(cell.colspan(styles).0)
  let grid = self.elem.grid().unwrap()
  let kind = match cell.kind() {
    Some(Custom(kind)) => kind
    _ => self.row_kinds[y]
  }
  let grid_cell = grid
    .cell(grid_to_effective(grid, x), grid_to_effective(grid, y))
    .unwrap()
  let prio = (overridden : Bool) => {
    if overridden {
      StrokePriority::CellStroke
    } else {
      StrokePriority::GridStroke
    }
  }
  let s = grid_cell.stroke
  let o = grid_cell.stroke_overridden
  let stroke : SidesMut = {
    left: { stroke: s.left, priority: prio(o.left), },
    top: { stroke: s.top, priority: prio(o.top), },
    right: { stroke: s.right, priority: prio(o.right), },
    bottom: { stroke: s.bottom, priority: prio(o.bottom), },
  }
  self.cells.insert({
    data: { tag, kind, headers: [], stroke, },
    x,
    y,
    rowspan,
    colspan,
    id,
  })
}

///|
fn TableCtx::build_tag(self : TableCtx) -> @export.TagKind {
  let tag = new_tag(Table)
  tag_set_opt(
    tag,
    self.elem.summary(tags_styles()).map(s => @export.Attr::Summary(s)),
    Summary(""),
  )
  tag_set_border_thickness(
    tag,
    self.border_thickness.map(t => @export.Sides::uniform(t)),
  )
  tag_set_border_color(
    tag,
    self.border_color.map(c => @export.Sides::uniform(c)),
  )
  tag
}

///|
fn build_table(tree : Tree, table_id : Int) -> Unit {
  let table_ctx = tree.ctx.tables[table_id]

  // Table layouting ensures that there are no overlapping cells, and that
  // any gaps left by the user are filled with empty cells.
  // A show rule, can prevent the table from being properly laid out, in which
  // case cells will be missing.
  if table_ctx.cells.is_empty() ||
    table_ctx.cells.entries.iter().any(e => e.is_missing()) {
    // Insert all children, so the content is included in the tag tree,
    // otherwise krilla might panic.
    for entry in table_ctx.cells.entries {
      if entry is Cell(cell) {
        tree.groups.push_group(table_ctx.group_id, cell.id)
      }
    }
    return
  }
  let width = table_ctx.cells.width()
  let height = table_ctx.cells.height()
  let grid = table_ctx.elem.grid().unwrap()

  // Only generate row groups such as `THead`, `TFoot`, and `TBody` if
  // there are no rows with mixed cell kinds, and there is at least one
  // header or a footer.
  let gen_row_groups = {
    let mut uniform_rows = true
    let mut has_header_or_footer = false
    let mut has_body = false
    for y in 0..<height {
      let row = table_ctx.cells.row(y)
      let first_cell = table_ctx.cells.resolve(row[0]).unwrap()
      let first_kind = first_cell.data.kind
      let mut broken = false
      for entry in row {
        guard table_ctx.cells.resolve(entry) is Some(cell) else { continue }
        if cell.data.kind is Header(_, scope) && scope != Column {
          uniform_rows = false
          broken = true
          break
        }
        if first_kind != cell.data.kind {
          uniform_rows = false
          broken = true
          break
        }
      }
      if broken {
        break
      }

      // If all cells in the row have the same custom kind, the row
      // kind is overwritten.
      table_ctx.row_kinds[y] = first_kind
      has_header_or_footer = has_header_or_footer || first_kind != Data
      has_body = has_body || first_kind == Data
    }
    uniform_rows && has_header_or_footer && has_body
  }

  // Compute the headers attribute column-wise.
  for x in 0..<width {
    let column_headers = []
    let headers = grid.headers
    let mut hi = 0
    for y in 0..<height {
      // Find current header region
      let grid_y = grid_to_effective(grid, y)
      while hi < headers.length() && headers[hi].inner.range.end <= grid_y {
        hi += 1
      }
      let region_range = if hi < headers.length() &&
        headers[hi].inner.range.contains(grid_y) {
        // Convert from the `CellGrid` coordinates to normal ones.
        let range = headers[hi].inner.range
        Some(
          (
            grid_from_effective(grid, range.start),
            grid_from_effective(grid, range.end),
          ),
        )
      } else {
        None
      }
      resolve_cell_headers(
        table_ctx.table_id,
        table_ctx.cells,
        column_headers,
        region_range,
        s => s.refers_to_column(),
        x,
        y,
      )
    }
  }
  // Compute the headers attribute row-wise.
  for y in 0..<height {
    let row_headers = []
    for x in 0..<width {
      resolve_cell_headers(
        table_ctx.table_id,
        table_ctx.cells,
        row_headers,
        None,
        s => s.refers_to_row(),
        x,
        y,
      )
    }
  }

  // Place h-lines, overwriting the cells stroke.
  place_explicit_lines(table_ctx.cells, grid.hlines, height, width, fn(
    cells,
    block,
    inline,
    pos,
    stroke,
  ) {
    guard cells.cell(inline, block) is Some(cell) else { return }
    match pos {
      Before => cell.data.stroke.bottom = stroke
      After => cell.data.stroke.top = stroke
    }
  })
  // Place v-lines, overwriting the cells stroke.
  place_explicit_lines(table_ctx.cells, grid.vlines, width, height, fn(
    cells,
    block,
    inline,
    pos,
    stroke,
  ) {
    guard cells.cell(block, inline) is Some(cell) else { return }
    match pos {
      Before => cell.data.stroke.right = stroke
      After => cell.data.stroke.left = stroke
    }
  })

  // Remove overlapping border strokes between cells.
  for y in 0..<height {
    for x in 0..<(width - 1) {
      prioritize_strokes(
        table_ctx.cells,
        (x, y),
        (x + 1, y),
        a => a.stroke.right,
        b => b.stroke.left,
        (a, v) => a.stroke.right = v,
        (b, v) => b.stroke.left = v,
      )
    }
  }
  for x in 0..<width {
    for y in 0..<(height - 1) {
      prioritize_strokes(
        table_ctx.cells,
        (x, y),
        (x, y + 1),
        a => a.stroke.bottom,
        b => b.stroke.top,
        (a, v) => a.stroke.bottom = v,
        (b, v) => b.stroke.top = v,
      )
    }
  }
  let (thickness, color) = try_resolve_table_stroke(table_ctx.cells)
  table_ctx.border_thickness = thickness
  table_ctx.border_color = color
  let mut chunk_kind = table_ctx.row_kinds[0]
  let mut chunk_id = group_id_invalid
  for y in 0..<height {
    let row = table_ctx.cells.row(y)
    let parent = if gen_row_groups {
      let row_kind = table_ctx.row_kinds[y]
      let is_first = chunk_id == group_id_invalid
      if is_first || !should_group_rows(chunk_kind, row_kind) {
        let tag = match row_kind {
          // Only one `THead` group at the start of the table is permitted.
          Header(_, _) if is_first => new_tag(THead)
          Header(_, _) => new_tag(TBody)
          Footer => new_tag(TFoot)
          Data => new_tag(TBody)
        }
        chunk_kind = row_kind
        chunk_id = tree.groups.push_tag(table_ctx.group_id, tag)
      }
      chunk_id
    } else {
      table_ctx.group_id
    }
    let row_id = tree.groups.push_tag(parent, new_tag(TR))
    let row_nodes = []
    for entry in row {
      guard entry is Cell(cell) else { continue }
      let rowspan = if cell.rowspan != 1 { Some(cell.rowspan) } else { None }
      let colspan = if cell.colspan != 1 { Some(cell.colspan) } else { None }
      let headers = cell.data.headers.copy()
      cell.data.headers.clear()
      let tag = match cell.data.kind {
        Header(_, scope) => {
          let id = table_cell_id(table_ctx.table_id, cell.x, cell.y)
          new_tag(TH)
          .with_attr(HeaderScope(table_header_scope_to_export(scope)))
          .with_attr(Id(id))
          .with_attr(CellHeaders(headers))
        }
        Footer | Data => new_tag(TD).with_attr(CellHeaders(headers))
      }
      tag_set_opt(tag, rowspan.map(n => @export.Attr::RowSpan(n)), RowSpan(1))
      tag_set_opt(tag, colspan.map(n => @export.Attr::ColSpan(n)), ColSpan(1))
      resolve_cell_border_and_background(
        grid,
        table_ctx.border_thickness,
        table_ctx.border_color,
        cell.x,
        cell.y,
        cell.data.stroke,
        tag,
      )
      tree.groups.set_tag(cell.data.tag, tag)
      row_nodes.push(cell.id)
    }
    tree.groups.push_groups(row_id, row_nodes)
  }
}

///|
fn should_group_rows(
  a : @library.TableCellKind,
  b : @library.TableCellKind,
) -> Bool {
  match (a, b) {
    (Header(_, _), Header(_, _)) => true
    (Footer, Footer) => true
    (Data, Data) => true
    (_, _) => false
  }
}

///|
priv struct HeaderCells {
  /// If this header is inside a table header regions defined by a
  /// `table.header()` call, this is the range of that region.
  /// Currently this is only supported for multi row headers.
  region_range : (Int, Int)?
  level : Int64
  cell_ids : Array[Bytes]
}

///|
fn resolve_cell_headers(
  table_id : Int,
  cells : GridCells[TableCellData],
  header_stack : Array[HeaderCells],
  region_range : (Int, Int)?,
  refers_to_dir : (@library.TableHeaderScope) -> Bool,
  x : Int,
  y : Int,
) -> Unit {
  guard cells.cell(x, y) is Some(cell) else { return }
  let cell_ids = resolve_cell_header_ids(
    table_id, header_stack, region_range, refers_to_dir, cell,
  )
  if cell_ids is Some(header) {
    for id in header.cell_ids {
      if !cell.data.headers.contains(id) {
        cell.data.headers.push(id)
      }
    }
  }
}

///|
fn resolve_cell_header_ids(
  table_id : Int,
  header_stack : Array[HeaderCells],
  region_range : (Int, Int)?,
  refers_to_dir : (@library.TableHeaderScope) -> Bool,
  cell : CtxCell[TableCellData],
) -> HeaderCells? {
  guard cell.data.kind is Header(level, scope) else {
    return header_stack.last()
  }
  if !refers_to_dir(scope) {
    return header_stack.last()
  }
  let level = level.0

  // Remove all headers with a higher level.
  while header_stack.last() is Some(h) && h.level > level {
    header_stack.pop() |> ignore
  }
  let tag_id = table_cell_id(table_id, cell.x, cell.y)

  // Check for multi-row header regions with the same level.
  let n = header_stack.length()
  match header_stack.last() {
    Some(prev) if prev.level == level =>
      // If the current header region encompasses the cell, add the cell id to
      // the header. This way multiple consecutive header cells in a single
      // header region will be listed for the next cells.
      if prev.region_range is Some((start, end)) &&
        start <= cell.y &&
        cell.y < end {
        prev.cell_ids.push(tag_id)
      } else {
        // The current region doesn't encompass the cell.
        // Replace the previous heading that had the same level.
        header_stack[n - 1] = { region_range, level, cell_ids: [tag_id], }
      }
    _ => header_stack.push({ region_range, level, cell_ids: [tag_id], })
  }
  let n = header_stack.length()
  if n >= 2 {
    Some(header_stack[n - 2])
  } else {
    None
  }
}

///|
fn table_cell_id(table_id : Int, x : Int, y : Int) -> Bytes {
  // 32 bytes is the maximum length the ID string can have.
  let s = "\{table_id + 1}x\{x}y\{y}"
  // krilla's `TagId::from` disambiguates ids provided by the user from ids
  // automatically assigned to notes by prefixing them with a `U`.
  let buf = [b'U']
  for c in s {
    if buf.length() < 33 {
      buf.push(c.to_int().to_byte())
    }
  }
  Bytes::from_array(buf)
}

///|
fn place_explicit_lines(
  cells : GridCells[TableCellData],
  lines : Array[Array[@library.Line]],
  block_end : Int,
  inline_end : Int,
  set_side : (
    GridCells[TableCellData],
    Int,
    Int,
    @library.LinePosition,
    PrioritzedStroke,
  ) -> Unit,
) -> Unit {
  for group in lines {
    for line in group {
      let end = match line.end {
        Some(n) => if n < inline_end { n } else { inline_end }
        None => inline_end
      }
      let explicit_stroke : PrioritzedStroke = {
        stroke: line.stroke,
        priority: ExplicitLine,
      }

      // Fixup line positions before the first, or after the last cell.
      let mut pos = line.position
      if line.index == 0 {
        pos = After
      } else if line.index + 1 == block_end {
        pos = Before
      }
      let block_idx = match pos {
        Before => line.index - 1
        After => line.index
      }
      for inline_idx in line.start..<end {
        set_side(cells, block_idx, inline_idx, pos, explicit_stroke)
      }
    }
  }
}

///|
/// PDF tables don't support gutters, remove all overlapping strokes,
/// that aren't equal. Leave strokes that would overlap but are the same
/// because then only a single value has to be written for `BorderStyle`,
/// `BorderThickness`, and `BorderColor` instead of an array for each.
fn prioritize_strokes(
  cells : GridCells[TableCellData],
  a : (Int, Int),
  b : (Int, Int),
  get_a : (TableCellData) -> PrioritzedStroke,
  get_b : (TableCellData) -> PrioritzedStroke,
  set_a : (TableCellData, PrioritzedStroke) -> Unit,
  set_b : (TableCellData, PrioritzedStroke) -> Unit,
) -> Unit {
  // Cells are disjoint if their positions don't resolve to the same parent
  // cell.
  let ia = cells.parent_idx(a.0, a.1)
  let ib = cells.parent_idx(b.0, b.1)
  if ia == ib {
    return
  }
  guard cells.entries[ia] is Cell(ca) && cells.entries[ib] is Cell(cb) else {
    return
  }
  let sa = get_a(ca.data)
  let sb = get_b(cb.data)

  // Only remove contesting (different) edge strokes.
  if sa.stroke != sb.stroke {
    // Prefer the right stroke on same priorities.
    if sa.priority <= sb.priority {
      set_a(ca.data, { ..sa, stroke: sb.stroke, })
    } else {
      set_b(cb.data, { ..sb, stroke: sa.stroke, })
    }
  }
}

///|
/// Try to resolve a table border stroke color and thickness that is inherited
/// by the cells. In Acrobat cells cannot override the border thickness or color
/// of the outer border around the table if the thickness is set.
fn try_resolve_table_stroke(
  cells : GridCells[TableCellData],
) -> (Double?, @export.NaiveRgbColor?) {
  // Omitted strokes are counted too for reasons explained above.
  let strokes : Array[(@library.ResolvedStroke?, Int)] = []
  for entry in cells.entries {
    guard entry is Cell(cell) else { continue }
    for side in cell.data.stroke.to_array() {
      let mut found = false
      for i, e in strokes {
        if e.0 == side.stroke {
          strokes[i] = (e.0, e.1 + 1)
          found = true
          break
        }
      }
      if !found {
        strokes.push((side.stroke, 1))
      }
    }
  }
  let uniform_stroke = strokes.length() == 1

  // Find the most used stroke and convert it to a fixed stroke.
  // NOTE: upstream iterates a hash map here, so ties are broken in an
  // unspecified order; the last most used stroke is taken here.
  let mut best : (@library.ResolvedStroke?, Int)? = None
  for e in strokes {
    match best {
      Some(b) if b.1 > e.1 => ()
      _ => best = Some(e)
    }
  }
  guard best is Some((Some(s), _)) else { return (None, None) }
  let stroke = s.unwrap_or_default()

  // Only set a parent stroke width if the table uses one uniform stroke.
  let thickness = if uniform_stroke {
    Some(to_f32(stroke.thickness))
  } else {
    None
  }
  let color = paint_to_color(stroke.paint)
  (thickness, color)
}

///|
fn resolve_cell_border_and_background(
  grid : @library.CellGrid,
  parent_border_thickness : Double?,
  parent_border_color : @export.NaiveRgbColor?,
  x : Int,
  y : Int,
  stroke : SidesMut,
  tag : @export.TagKind,
) -> Unit {
  // Resolve border attributes.
  let fixed = stroke
    .to_array()
    .map(s => s.stroke.map(s => s.unwrap_or_default()))

  // Acrobat completely ignores the border style attribute, but the spec
  // defines `BorderStyle::None` as the default. So make sure to write
  // the correct border styles.
  let border_style = resolve_sides(
    fixed,
    None,
    Some(@export.BorderStyle::NoBorder),
    s => {
      Some(
        match s.dash {
          Some(_) => @export.BorderStyle::Dashed
          None => @export.BorderStyle::Solid
        },
      )
    },
  )

  // In Acrobat `BorderThickness` takes precedence over `BorderStyle`. If
  // A `BorderThickness != 0` is specified for a side the border is drawn
  // even if `BorderStyle::None` is set. So explicitly write zeros for
  // sides that should be omitted.
  let border_thickness = resolve_sides(
    fixed,
    parent_border_thickness,
    Some(0.0),
    s => Some(to_f32(s.thickness)),
  )
  let border_color = resolve_sides(fixed, parent_border_color, None, s => {
    paint_to_color(s.paint)
  })
  tag_set_border_style(tag, border_style)
  tag_set_border_thickness(tag, border_thickness)
  tag_set_border_color(tag, border_color)
  let grid_cell = grid
    .cell(grid_to_effective(grid, x), grid_to_effective(grid, y))
    .unwrap()
  let background_color = match grid_cell.fill {
    Some(fill) => paint_to_color(fill)
    None => None
  }
  tag_set_background_color(tag, background_color)
}

///|
/// Try to minimize the attributes written per cell.
/// The parent value will be set on the table tag and is inherited by all table
/// cells. If all present values match the parent or all are missing, the
/// attribute can be omitted, and thus `None` is returned.
/// If one of the present values differs from the parent value, the cell
/// attribute needs to override the parent attribute, fill up the remaining
/// sides with a `default` value if provided, or any other present value.
///
/// Using an already present value has the benefit of saving storage space in
/// the resulting PDF, if all sides have the same value, because then a
/// uniform value can be written instead of a 4-element array.
///
/// `sides` is in the order left, top, right, bottom.
fn[T : Eq] resolve_sides(
  sides : Array[@library.FixedStroke?],
  parent : T?,
  default : T?,
  map_stroke : (@library.FixedStroke) -> T?,
) -> @export.Sides[T]? {
  let mapped : Array[T?] = sides.map(s => {
    match s {
      Some(s) => map_stroke(s)
      None => None
    }
  })
  if mapped.iter().all(v => v is None || v == parent) {
    // All present values are equal to the parent value.
    return None
  }
  let mut first : T? = None
  for v in mapped {
    if v is Some(_) {
      first = v
      break
    }
  }
  guard first is Some(first) else {
    // All values are missing
    return None
  }

  // At least one value is different from the parent, fill up the remaining
  // sides with a replacement value.
  let replacement = default.unwrap_or(first)
  let s = mapped.map(v => v.unwrap_or(replacement))

  // TODO(accessibility): handle `text(dir: rtl)`
  Some({ before: s[1], after: s[3], start: s[0], end: s[2], })
}
