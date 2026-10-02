// Port of `typst-layout/src/math/fraction.rs`.

///|
/// Lays out a [`FractionItem`].
fn layout_fraction(
  item : @library.FractionItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let num = ctx.layout_into_fragment(item.numerator, styles).into_frame()
  let denom = ctx.layout_into_fragment(item.denominator, styles).into_frame()
  let constants = ctx.font().math()
  let size = @library.TextElem::size_in(styles).resolve(styles)
  let math_size = props.size
  let display = math_size == @library.MathSize::Display
  let frame = if item.line {
    let axis = constants.axis_height.at(size)
    let thickness = constants.fraction_rule_thickness.at(size)
    let shift_up = (if display {
      constants.fraction_numerator_display_style_shift_up
    } else {
      constants.fraction_numerator_shift_up
    }).at(size)
    let shift_down = (if display {
      constants.fraction_denominator_display_style_shift_down
    } else {
      constants.fraction_denominator_shift_down
    }).at(size)
    let num_min = (if display {
      constants.fraction_num_display_style_gap_min
    } else {
      constants.fraction_numerator_gap_min
    }).at(size)
    let denom_min = (if display {
      constants.fraction_denom_display_style_gap_min
    } else {
      constants.fraction_denominator_gap_min
    }).at(size)
    let num_gap = (shift_up - (axis + thickness.div_by(2.0)) - num.descent()).max(
      num_min,
    )
    let denom_gap = (shift_down +
    (axis - thickness.div_by(2.0)) -
    denom.ascent()).max(denom_min)
    let line_width = num.width().max(denom.width())
    let width = line_width + item.padding.at(size).times(2.0)
    let height = num.height() + num_gap + thickness + denom_gap + denom.height()
    let size = @library.Axes::new(width, height)
    let num_pos = @library.Point::with_x((width - num.width()).div_by(2.0))
    let line_pos = @library.Point::new(
      (width - line_width).div_by(2.0),
      num.height() + num_gap + thickness.div_by(2.0),
    )
    let denom_pos = @library.Point::new(
      (width - denom.width()).div_by(2.0),
      height - denom.height(),
    )
    let baseline = line_pos.y + axis
    let frame = @library.Frame::soft(size)
    frame.set_baseline(baseline)
    frame.push_frame(num_pos, num)
    frame.push_frame(denom_pos, denom)
    let text_fill = @library.TextElem::fill_in(styles).as_decoration()
    let line = match @library.TextElem::stroke_in(styles) {
      Some(stroke) =>
        @library.Geometry::Rect(@library.Axes::new(line_width, thickness)).filled_and_stroked(
          text_fill,
          stroke.resolve(styles).unwrap_or_default(),
        )
      None =>
        @library.Geometry::Line(@library.Point::with_x(line_width)).stroked(
          @library.FixedStroke::from_pair(text_fill, thickness),
        )
    }
    frame.push(line_pos, Shape(line, props.span))
    frame
  } else {
    let shift_up = (if display {
      constants.stack_top_display_style_shift_up
    } else {
      constants.stack_top_shift_up
    }).at(size)
    let shift_down = (if display {
      constants.stack_bottom_display_style_shift_down
    } else {
      constants.stack_bottom_shift_down
    }).at(size)
    let gap_min = (if display {
      constants.stack_display_style_gap_min
    } else {
      constants.stack_gap_min
    }).at(size)
    let gap = shift_up - num.descent() + (shift_down - denom.ascent())
    let width = num.width().max(denom.width()) +
      item.padding.at(size).times(2.0)
    let height = num.height() + gap.max(gap_min) + denom.height()
    let size = @library.Axes::new(width, height)
    let num_pos = @library.Point::with_x((width - num.width()).div_by(2.0))
    let denom_pos = @library.Point::new(
      (width - denom.width()).div_by(2.0),
      height - denom.height(),
    )
    let baseline = num.ascent() +
      shift_up +
      (gap_min - gap).max(@library.Abs::zero()).div_by(2.0)
    let frame = @library.Frame::soft(size)
    frame.set_baseline(baseline)
    frame.push_frame(num_pos, num)
    frame.push_frame(denom_pos, denom)
    frame
  }
  ctx.push(Frame(FrameFragment::new(props, styles, frame)))
}

///|
/// Lay out a skewed fraction.
fn layout_skewed_fraction(
  item : @library.SkewedFractionItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  // Font-derived constants
  let constants = ctx.font().math()
  let size = @library.TextElem::size_in(styles).resolve(styles)
  let vgap = constants.skewed_fraction_vertical_gap.at(size)
  let hgap = constants.skewed_fraction_horizontal_gap.at(size)
  let axis = constants.axis_height.at(size)
  let num_frame = ctx.layout_into_fragment(item.numerator, styles).into_frame()
  let num_size = num_frame.size()
  let denom_frame = ctx
    .layout_into_fragment(item.denominator, styles)
    .into_frame()
  let denom_size = denom_frame.size()

  // Height of the fraction frame
  // We recalculate this value below if the slash glyph overflows
  let mut fraction_height = num_size.y + denom_size.y + vgap

  // Build the slash glyph to calculate its size
  item.slash.set_stretch_relative_to(fraction_height, Y)
  let slash_frag = ctx.layout_into_fragment(item.slash, styles)
  let slash_frame = slash_frag.into_frame()

  // Adjust the fraction height if the slash overflows
  let slash_size = slash_frame.size()
  let vertical_offset = @library.Abs::zero()
    .max(slash_size.y - fraction_height)
    .div_by(2.0)
  fraction_height = fraction_height.max(slash_size.y)

  // Reference points for all three objects, used to place them in the frame.
  let mut slash_up_left = @library.Point::new(
      num_size.x + hgap.div_by(2.0),
      fraction_height.div_by(2.0),
    ) -
    slash_size.to_point().div_by(2.0)
  let mut num_up_left = @library.Point::with_y(vertical_offset)
  let mut denom_up_left = num_up_left +
    num_size.to_point() +
    @library.Point::new(hgap, vgap)

  // Fraction width
  let fraction_width = (denom_up_left.x + denom_size.x).max(
      slash_up_left.x + slash_size.x,
    ) +
    @library.Abs::zero().max(-slash_up_left.x)
  // We have to shift everything right to avoid going in the negatives for
  // the x coordinate
  let horizontal_offset = @library.Point::with_x(
    @library.Abs::zero().max(-slash_up_left.x),
  )
  slash_up_left = slash_up_left + horizontal_offset
  num_up_left = num_up_left + horizontal_offset
  denom_up_left = denom_up_left + horizontal_offset

  // Build the final frame
  let fraction_frame = @library.Frame::soft(
    @library.Axes::new(fraction_width, fraction_height),
  )

  // Baseline (use axis height to center slash on the axis)
  fraction_frame.set_baseline(fraction_height.div_by(2.0) + axis)

  // Numerator, Denominator, Slash
  fraction_frame.push_frame(num_up_left, num_frame)
  fraction_frame.push_frame(denom_up_left, denom_frame)
  fraction_frame.push_frame(slash_up_left, slash_frame)
  ctx.push(Frame(FrameFragment::new(props, styles, fraction_frame)))
}
