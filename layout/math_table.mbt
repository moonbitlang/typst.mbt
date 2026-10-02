// Port of `typst-layout/src/math/table.rs`.

///|
let default_stroke_thickness : @library.Em = @library.Em::new(0.05)

///|
/// Layout a [`MathTableItem`] (upstream `math::table::layout_table`).
fn layout_math_table(
  item : @library.MathTableItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let rows = item.cells
  let nrows = rows.length()
  let ncols = match rows.get(0) {
    Some(row) => row.length()
    None => 0
  }
  if ncols == 0 || nrows == 0 {
    ctx.push(
      Frame(
        FrameFragment::new(
          props,
          styles,
          @library.Frame::soft(@library.Axes::zero_size()),
        ),
      ),
    )
    return
  }
  let gap = item.gap.zip_map(ctx.region.size, (rel, size) => {
    rel.relative_to(size)
  })
  let half_gap = gap.times(0.5)

  // We provide a default stroke thickness that scales
  // with font size to ensure that augmentation lines
  // look correct by default at all matrix sizes.
  // The line cap is also set to square because it looks more "correct".
  let default_stroke_thickness = default_stroke_thickness.resolve(styles)
  let default_stroke : @library.FixedStroke = {
    ..@library.FixedStroke::default(),
    thickness: default_stroke_thickness,
    paint: @library.TextElem::fill_in(styles).as_decoration(),
    cap: Square,
  }
  let (hline, vline, stroke) = match item.augment {
    Some(augment) => {
      // We need to get stroke here for ownership.
      let stroke = match augment.stroke {
        Custom(stroke) => stroke.unwrap_or(default_stroke)
        Auto => default_stroke
      }
      (augment.hline.0.copy(), augment.vline.0.copy(), stroke)
    }
    _ => ([], [], default_stroke)
  }

  // Before the full matrix body can be laid out, the
  // individual cells must first be independently laid out
  // so we can ensure alignment across rows and columns.
  let cols : Array[Array[CellLayout]] = Array::makei(ncols, _ => [])

  // This variable stores the maximum ascent and descent for each row.
  let heights = Array::make(nrows, (@library.Abs::zero(), @library.Abs::zero()))
  let denom_style = @library.style_for_denominator(styles)
  // We pad ascent and descent with the ascent and descent of the paren
  // to ensure that normal matrices are aligned with others unless they are
  // way too big.
  let (ascent, descent) = match
    GlyphFragment::synthetic(
      ctx.engine,
      styles.chain(denom_style),
      '(',
      @syntax.Span::detached(),
    ) {
    Some(glyph) => (glyph.ascent(), glyph.descent())
    None => (@library.Abs::zero(), @library.Abs::zero())
  }
  for r, row in rows {
    for c, cell in row {
      let cell = layout_math_cell(cell, ctx, styles)
      heights[r] = (
        heights[r].0.max(cell.height.0.max(ascent)),
        heights[r].1.max(cell.height.1.max(descent)),
      )
      cols[c].push(cell)
    }
  }
  for i, line in hline {
    if line < 0L {
      hline[i] = line + nrows.to_int64()
    }
  }
  for i, line in vline {
    if line < 0L {
      vline[i] = line + ncols.to_int64()
    }
  }

  // For each row, combine maximum ascent and descent into a row height.
  // Sum the row heights, then add the total height of the gaps between rows.
  let mut total_height = abs_sum(heights.iter().map(h => h.0 + h.1)) +
    gap.y.times((nrows - 1).to_double())
  if hline.contains(0L) {
    total_height = total_height + gap.y
  }
  if hline.contains(nrows.to_int64()) {
    total_height = total_height + gap.y
  }

  // Width starts at zero because it can't be calculated until later
  let frame = @library.Frame::soft(
    @library.Axes::new(@library.Abs::zero(), total_height),
  )
  let mut x = @library.Abs::zero()
  if vline.contains(0L) {
    frame.push(
      @library.Point::with_x(x + half_gap.x),
      line_item(total_height, true, stroke, props.span),
    )
    x = x + gap.x
  }
  for index, col in cols {
    let sub_widths = compute_sub_column_widths(col)
    let rows = col.mapi((row, cell_layout) => RowLayout::{
      cells: cell_layout.sub_columns,
      frame_height: cell_layout.height,
      row_height: Some(heights[row]),
    })
    let builder = stack_rows(
      rows,
      sub_widths,
      item.alternator,
      item.align,
      gap.y,
      if hline.contains(0L) {
        gap.y
      } else {
        @library.Abs::zero()
      },
    )
    for entry in builder.frames {
      let (cell, pos) = entry
      frame.push_frame({ ..pos, x: pos.x + x, }, cell)
    }

    // Advance to the end of the column
    x = x + builder.size.x

    // If a vertical line should be inserted after this column
    if vline.contains(index.to_int64() + 1L) {
      frame.push(
        @library.Point::with_x(x + half_gap.x),
        line_item(total_height, true, stroke, props.span),
      )
    }

    // Advance to the start of the next column
    x = x + gap.x
  }
  let total_width = if !vline.contains(ncols.to_int64()) {
    x - gap.x
  } else {
    x
  }

  // This allows the horizontal lines to be laid out
  for line in hline {
    let offset = if line == 0L {
      gap.y
    } else {
      abs_sum(heights[0:line.to_int()].iter().map(h => h.0 + h.1)) +
      gap.y.times((line - 1L).to_double()) +
      half_gap.y
    }
    frame.push(
      @library.Point::with_y(offset),
      line_item(total_width, false, stroke, props.span),
    )
  }
  frame.set_size({ ..frame.size(), x: total_width, })
  let axis = ctx.font().math().axis_height.resolve(styles)
  let height = frame.height()
  frame.set_baseline(height.div_by(2.0) + axis)
  ctx.push(Frame(FrameFragment::new(props, styles, frame)))
}

///|
priv struct CellLayout {
  sub_columns : Array[Array[MathFragment]]
  height : (@library.Abs, @library.Abs)
}

///|
/// Layout one cell, split at alignment points into sub-columns.
fn layout_math_cell(
  cell : @library.AlignedRow,
  ctx : MathContext,
  styles : @library.StyleChain,
) -> CellLayout raise @library.SourceError {
  let sub_columns = layout_aligned_row(cell, ctx, styles)
  let height = measure_row(sub_columns)
  { sub_columns, height, }
}

///|
/// Compute max sub-column widths across a table column.
fn compute_sub_column_widths(col : Array[CellLayout]) -> Array[@library.Abs] {
  let mut len : Int? = None
  for cell in col {
    let l = cell.sub_columns.length()
    len = match len {
      None => Some(l)
      Some(m) => Some(if l > m { l } else { m })
    }
  }
  let sub_widths = Array::make(len.unwrap_or(1), @library.Abs::zero())
  for cell in col {
    for i, sub_column in cell.sub_columns {
      sub_widths[i] = sub_widths[i].max(run_width(sub_column))
    }
  }
  sub_widths
}

///|
fn line_item(
  length : @library.Abs,
  vertical : Bool,
  stroke : @library.FixedStroke,
  span : @syntax.Span,
) -> @library.FrameItem {
  let line_geom : @library.Geometry = if vertical {
    Line(@library.Point::with_y(length))
  } else {
    Line(@library.Point::with_x(length))
  }
  Shape(
    {
      geometry: line_geom,
      fill: None,
      fill_rule: @library.FillRule::default(),
      stroke: Some(stroke),
    },
    span,
  )
}
