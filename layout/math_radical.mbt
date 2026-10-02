// Port of `typst-layout/src/math/radical.rs`.

///|
/// Lays out a [`RadicalItem`].
///
/// TeXbook page 443, page 360
/// See also: <https://www.w3.org/TR/mathml-core/#radicals-msqrt-mroot>
fn layout_radical(
  item : @library.RadicalItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let radicand = ctx.layout_into_fragment(item.radicand, styles).into_frame()
  let target = {
    let sqrt = ctx.layout_into_fragment(item.sqrt, styles)
    let styles = item.sqrt.styles().unwrap_or(styles)
    let (font, size) = sqrt.font(ctx, styles)
    let thickness = font.math().radical_rule_thickness.at(size)
    let gap = (match @library.EquationElem::size_in(styles) {
      Display => font.math().radical_display_style_vertical_gap
      _ => font.math().radical_vertical_gap
    }).at(size)
    radicand.height() + thickness + gap
  }

  // Layout root symbol.
  item.sqrt.set_stretch_relative_to(target, Y)
  let sqrt = ctx.layout_into_fragment(item.sqrt, styles)
  let sqrt_styles = item.sqrt.styles().unwrap_or(styles)
  let (font, size) = sqrt.font(ctx, sqrt_styles)
  let thickness = font.math().radical_rule_thickness.at(size)
  let extra_ascender = font.math().radical_extra_ascender.at(size)
  let kern_before = font.math().radical_kern_before_degree.at(size)
  let kern_after = font.math().radical_kern_after_degree.at(size)
  let raise_factor = font.math().radical_degree_bottom_raise_percent
  let gap = (match @library.EquationElem::size_in(sqrt_styles) {
    Display => font.math().radical_display_style_vertical_gap
    _ => font.math().radical_vertical_gap
  }).at(size)
  let text_fill = match sqrt.fill() {
    Some(fill) => fill
    None => @library.TextElem::fill_in(sqrt_styles).as_decoration()
  }
  let line_width = radicand.width()
  let sqrt_stroke = sqrt.stroke()
  let sqrt = sqrt.into_frame()

  // Layout the index.
  let index = match item.index {
    Some(index) => Some(ctx.layout_into_fragment(index, styles).into_frame())
    None => None
  }

  // TeXbook, page 443, item 11
  // Keep original gap, and then distribute any remaining free space
  // equally above and below.
  let gap = gap.max(
    (sqrt.height() - thickness - radicand.height() + gap).div_by(2.0),
  )
  let sqrt_ascent = radicand.ascent() + gap + thickness
  let descent = sqrt.height() - sqrt_ascent
  let inner_ascent = sqrt_ascent + extra_ascender
  let mut sqrt_offset = @library.Abs::zero()
  let mut shift_up = @library.Abs::zero()
  let mut ascent = inner_ascent
  if index is Some(index) {
    sqrt_offset = kern_before + index.width() + kern_after
    // The formula below for how much raise the index by comes from
    // the TeXbook, page 360, in the definition of `\root`.
    // However, the `+ index.descent()` part is different from TeX.
    // Without it, descenders can collide with the surd, a rarity
    // in practice, but possible.  MS Word also adjusts index positions
    // for descenders.
    shift_up = (inner_ascent - descent).times(raise_factor) + index.descent()
    ascent = ascent.max(shift_up + index.ascent())
  }
  let sqrt_x = sqrt_offset.max(@library.Abs::zero())
  let radicand_x = sqrt_x + sqrt.width()
  let radicand_y = ascent - radicand.ascent()
  let size = @library.Axes::new(radicand_x + line_width, ascent + descent)

  // The extra "- thickness" comes from the fact that the sqrt is placed
  // in `push_frame` with respect to its top, not its baseline.
  let sqrt_pos = @library.Point::new(sqrt_x, radicand_y - gap - thickness)
  let line_pos = @library.Point::new(
    radicand_x,
    radicand_y - gap - thickness.div_by(2.0),
  )
  let radicand_pos = @library.Point::new(radicand_x, radicand_y)
  let frame = @library.Frame::soft(size)
  frame.set_baseline(ascent)
  if index is Some(index) {
    let index_x = -sqrt_offset.min(@library.Abs::zero()) + kern_before
    let index_pos = @library.Point::new(
      index_x,
      ascent - index.ascent() - shift_up,
    )
    frame.push_frame(index_pos, index)
  }
  frame.push_frame(sqrt_pos, sqrt)

  // Add the horizontal line of the root symbol.
  match sqrt_stroke {
    Some(fixed_stroke) => {
      let sides = styled_rect(
        @library.Axes::new(line_width, thickness),
        @library.Corners::splat(@library.Rel::zero()),
        Some(text_fill),
        @library.Sides::new(
          None, // Omit the left-side edge.
          Some(fixed_stroke),
          Some(fixed_stroke),
          Some(fixed_stroke),
        ),
      )
      for shape in sides {
        frame.push(
          line_pos - @library.Point::with_y(thickness.div_by(2.0)),
          Shape(shape, props.span),
        )
      }
    }
    None => {
      let line : @library.FrameItem = Shape(
        @library.Geometry::Line(@library.Point::with_x(line_width)).stroked(
          @library.FixedStroke::from_pair(text_fill, thickness),
        ),
        props.span,
      )
      frame.push(line_pos, line)
    }
  }
  frame.push_frame(radicand_pos, radicand)
  ctx.push(Frame(FrameFragment::new(props, styles, frame)))
}
