// Port of `typst-layout/src/math/run.rs`.

///|
/// Leading between rows in script and scriptscript size.
let tight_leading : @library.Em = @library.Em::new(0.25)

// A list of math fragments between alignment points and/or linebreaks
// (upstream `MathRun = Vec<MathFragment>`).
//
// For multiline equations this represents a distinct "cell", the list of
// fragments at a specific row and column. For tables, this represents a
// "sub-column", one of the parts that make up a cell in a table since
// alignment points can be used to align fragments within a cell for an
// individual column.

///|
/// Layout a [`MultilineItem`] into a [`MathRunFrameBuilder`].
fn layout_multiline(
  item : @library.MultilineItem,
  ctx : MathContext,
  styles : @library.StyleChain,
) -> MathRunFrameBuilder raise @library.SourceError {
  let nrows = item.rows.length()
  let ncols = match item.rows.get(0) {
    Some(r) => r.len()
    None => 0
  }
  if nrows == 0 || ncols == 0 {
    return MathRunFrameBuilder::default()
  }
  let col_widths = Array::make(ncols, @library.Abs::zero())
  let rows : Array[Array[Array[MathFragment]]] = []
  for row in item.rows {
    let cells = layout_aligned_row(row, ctx, styles)
    for c, cell in cells {
      col_widths[c] = col_widths[c].max(run_width(cell))
    }
    rows.push(cells)
  }
  let leading = if @library.EquationElem::size_in(styles) >=
    @library.MathSize::Text {
    @library.ParElem::leading_in(styles).resolve(styles)
  } else {
    tight_leading.resolve(styles)
  }
  let align = @library.AlignElem::alignment_in(styles).resolve(styles).x
  let rows = rows.map(cells => {
    let height = measure_row(cells)
    RowLayout::{ cells, frame_height: height, row_height: None, }
  })
  stack_rows(rows, col_widths, Right, align, leading, @library.Abs::zero())
}

///|
/// The summed width of a run (upstream `iter().map(width).sum()`).
fn run_width(run : Array[MathFragment]) -> @library.Abs {
  abs_sum(run.iter().map(f => f.width()))
}

///|
/// Layout an [`AlignedRow`].
fn layout_aligned_row(
  row : @library.AlignedRow,
  ctx : MathContext,
  styles : @library.StyleChain,
) -> Array[Array[MathFragment]] raise @library.SourceError {
  let cells = []
  let items = row.0
  for c, item in items {
    let frags = ctx.layout_into_fragments(item, styles)

    // For a (right-aligned, left-aligned) pair, move the lspace of the item
    // in the left-aligned column to the right-aligned column.
    if c % 2 == 0 &&
      items.get(c + 1) is Some(next_item) &&
      alignment_lspace(next_item) is Some(spacing) {
      frags.push(Space(spacing))
    }
    cells.push(frags)
  }
  cells
}

///|
/// A single row to be laid out in multiline math.
priv struct RowLayout {
  /// The row's content, split by alignment points.
  cells : Array[Array[MathFragment]]
  /// The ascent and descent that the row's final frame should have.
  frame_height : (@library.Abs, @library.Abs)
  /// The ascent and descent that should be used for this row when stacking
  /// rows together. If not specified,
  /// [`frame_height`](RowLayout::frame_height) is used instead.
  ///
  /// This is used in table layout, where within each column there are rows
  /// which need to be alignment. But when positioning rows together we need
  /// to align them based on the sizes of all columns of the table.
  row_height : (@library.Abs, @library.Abs)?
}

///|
/// Build and stack line frames for rows with aligned columns.
fn stack_rows(
  rows : Array[RowLayout],
  widths : Array[@library.Abs],
  alternator : @library.LeftRightAlternator,
  align : @library.FixedAlignment,
  leading : @library.Abs,
  start_y : @library.Abs,
) -> MathRunFrameBuilder {
  let (points, total_width) = cumulative_alignment_points(widths)
  let has_alignment = !points.is_empty()
  let frames = []
  let mut size = @library.Axes::new(@library.Abs::zero(), start_y)
  for i, row in rows {
    let sub = row_into_line_frame(
      row.cells,
      points,
      alternator,
      Some(row.frame_height),
    )
    let (row_ascent, row_descent) = row.row_height.unwrap_or(row.frame_height)
    if i > 0 {
      size = { ..size, y: size.y + leading, }
    }
    let mut pos = @library.Point::with_y(size.y + row_ascent - sub.ascent())
    if !has_alignment {
      pos = { ..pos, x: align.position(total_width - sub.width()), }
    }
    size = { ..size, x: size.x.max(sub.width()), }
    size = { ..size, y: size.y + (row_ascent + row_descent), }
    frames.push((sub, pos))
  }
  { size, frames, }
}

///|
/// Measure the ascent and descent of a row.
fn measure_row(
  cells : Array[Array[MathFragment]],
) -> (@library.Abs, @library.Abs) {
  let mut acc : (@library.Abs, @library.Abs)? = None
  for sc in cells {
    for f in sc {
      if f is Tag(_) {
        continue
      }
      let (a2, d2) = (f.ascent(), f.descent())
      acc = match acc {
        None => Some((a2, d2))
        Some((a1, d1)) => Some((a1.max(a2), d1.max(d2)))
      }
    }
  }
  acc.unwrap_or((@library.Abs::zero(), @library.Abs::zero()))
}

///|
/// Upstream `MathFragmentsExt::into_frame`.
fn math_run_into_frame(run : Array[MathFragment]) -> @library.Frame {
  row_into_line_frame([run], [], Right, None)
}

///|
/// Convert this run of math fragments into a vector of inline items for
/// paragraph layout. Creates multiple fragments when relation or binary
/// operators are present to allow for line-breaking opportunities later
/// (upstream `MathFragmentsExt::into_par_items`).
fn math_run_into_par_items(
  run : Array[MathFragment],
) -> Array[@library.InlineItem] {
  let items : Array[@library.InlineItem] = []
  let mut x = @library.Abs::zero()
  let mut ascent = @library.Abs::zero()
  let mut descent = @library.Abs::zero()
  let mut frame = @library.Frame::soft(@library.Axes::zero_size())
  let mut empty = true
  let finalize_frame = (
    frame : @library.Frame,
    x : @library.Abs,
    ascent : @library.Abs,
    descent : @library.Abs,
  ) => {
    frame.set_size(@library.Axes::new(x, ascent + descent))
    frame.set_baseline(@library.Abs::zero())
    frame.translate(@library.Point::with_y(ascent))
  }
  let mut space_is_visible = false
  let is_space = (f : MathFragment) => f is Space(_)
  let is_line_break_opportunity = (
    class : @unicode.MathClass,
    next_fragment : @unicode.MathClass?,
  ) => {
    match class {
      // Don't split when two relations are in a row or when preceding a
      // closing parenthesis.
      Binary => next_fragment != Some(Closing)
      Relation => !(next_fragment is Some(Relation | Closing))
      _ => false
    }
  }
  for i, fragment in run {
    let peek = run.get(i + 1)
    if space_is_visible && is_space(fragment) {
      items.push(Space(fragment.width(), true))
      continue
    }
    let class = fragment.class()
    let y = fragment.ascent()
    ascent = ascent.max(y)
    descent = descent.max(fragment.descent())
    let pos = @library.Point::new(x, -y)
    x = x + fragment.width()
    frame.push_frame(pos, fragment.into_frame())
    empty = false

    // Split our current frame when we encounter a binary operator or
    // relation so that there is a line-breaking opportunity.
    if is_line_break_opportunity(class, peek.map(f => f.class())) {
      let frame_prev = frame
      frame = @library.Frame::soft(@library.Axes::zero_size())
      finalize_frame(frame_prev, x, ascent, descent)
      items.push(Frame(frame_prev))
      empty = true
      x = @library.Abs::zero()
      ascent = @library.Abs::zero()
      descent = @library.Abs::zero()
      space_is_visible = true
      if peek is Some(f_next) && !is_space(f_next) {
        items.push(Space(@library.Abs::zero(), true))
      }
    } else {
      space_is_visible = false
    }
  }

  // Don't use `frame.is_empty()` because even an empty frame can
  // contribute width (if it had hidden content).
  if !empty {
    finalize_frame(frame, x, ascent, descent)
    items.push(Frame(frame))
  }
  items
}

///|
/// How the rows from the math run should be aligned and merged into a
/// [`Frame`].
priv struct MathRunFrameBuilder {
  /// The size of the resulting frame.
  mut size : @library.Axes[@library.Abs]
  /// Each row's frame, and the position where the frame should
  /// be pushed into the resulting frame.
  frames : Array[(@library.Frame, @library.Point)]
}

///|
fn MathRunFrameBuilder::default() -> MathRunFrameBuilder {
  { size: @library.Axes::zero_size(), frames: [], }
}

///|
/// Consumes the builder and returns a [`Frame`].
fn MathRunFrameBuilder::build(
  self : MathRunFrameBuilder,
  set_baseline : Bool,
) -> @library.Frame {
  let mut set_baseline = set_baseline
  let frame = @library.Frame::soft(self.size)
  for entry in self.frames {
    let (sub, pos) = entry
    if set_baseline && sub.has_baseline() {
      frame.set_baseline(sub.baseline())
    }
    frame.push_frame(pos, sub)
    set_baseline = false
  }
  frame
}

///|
/// Consumes the builder and returns a [`Frame`] with the baseline of the
/// first item.
fn MathRunFrameBuilder::build_aligned(
  self : MathRunFrameBuilder,
) -> @library.Frame {
  self.build(true)
}

///|
/// Consumes the builder and returns a [`Frame`] without a default
/// baseline, which must be manually calculated later.
fn MathRunFrameBuilder::build_unaligned(
  self : MathRunFrameBuilder,
) -> @library.Frame {
  self.build(false)
}

///|
/// Upstream `From<Frame> for MathRunFrameBuilder`.
fn MathRunFrameBuilder::from_frame(
  frame : @library.Frame,
) -> MathRunFrameBuilder {
  { size: frame.size(), frames: [(frame, @library.Point::zero())], }
}

///|
/// Build a frame from a row's cell fragments positioned at alignment points.
fn row_into_line_frame(
  cells : Array[Array[MathFragment]],
  points : Array[@library.Abs],
  alternator : @library.LeftRightAlternator,
  height : (@library.Abs, @library.Abs)?,
) -> @library.Frame {
  let (ascent, descent) = match height {
    Some(h) => h
    None => measure_row(cells)
  }
  let frame = @library.Frame::soft(
    @library.Axes::new(@library.Abs::zero(), ascent + descent),
  )
  frame.set_baseline(ascent)
  let alternator = Ref(alternator)
  let mut prev_point = @library.Abs::zero()
  let mut point_index = 0
  let mut x_end = @library.Abs::zero()
  for cell in cells {
    let width = run_width(cell)
    let cell_x = if points.get(point_index) is Some(point) {
      point_index += 1
      // `LeftRightAlternator::next` always yields.
      let alt = @library.LeftRightAlternator::next(alternator)
      let x = match alt {
        Right => point - width
        _ => prev_point
      }
      prev_point = point
      x
    } else {
      prev_point
    }
    let mut x = cell_x
    for frag in cell {
      let y = ascent - frag.ascent()
      let w = frag.width()
      frame.push_frame(@library.Point::new(x, y), frag.into_frame())
      x = x + w
    }
    x_end = x
  }
  frame.set_size({ ..frame.size(), x: x_end, })
  frame
}

///|
/// Compute cumulative alignment points from column widths.
fn cumulative_alignment_points(
  widths : Array[@library.Abs],
) -> (Array[@library.Abs], @library.Abs) {
  if widths.length() <= 1 {
    return ([], widths.get(0).unwrap_or(@library.Abs::zero()))
  }
  let points = []
  let mut cumulative = @library.Abs::zero()
  for w in widths {
    cumulative = cumulative + w
    points.push(cumulative)
  }
  (points, cumulative)
}

///|
/// Returns the resolved alignment lspace of the first non-tag item in a cell,
/// if it has `align_form_infix` set.
fn alignment_lspace(cell : @library.MathItem) -> @library.Abs? {
  for item in cell.as_slice() {
    if item is Tag(_) {
      continue
    }
    return match item {
      Comp(comp) if comp.props.align_form_infix =>
        comp.props.lspace.map(lspace => lspace.resolve(comp.styles))
      _ => None
    }
  }
  None
}
