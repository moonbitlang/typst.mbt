// Port of `typst-layout/src/math/line.rs`.

///|
/// Lays out a [`LineItem`] (upstream `math::line::layout_line`).
fn layout_math_line(
  item : @library.LineItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let content = ctx.layout_into_fragment(item.base, styles)
  let (font, size) = content.font(ctx, item.base.styles().unwrap_or(styles))
  let (extra_height, line_pos, content_pos, baseline, thickness, line_adjust) = match
    item.position {
    Below => {
      let sep = font.math().underbar_extra_descender.at(size)
      let thickness = font.math().underbar_rule_thickness.at(size)
      let gap = font.math().underbar_vertical_gap.at(size)
      let extra_height = sep + thickness + gap
      let line_pos = @library.Point::with_y(
        content.height() + gap + thickness.div_by(2.0),
      )
      let content_pos = @library.Point::zero()
      let baseline = content.ascent()
      let line_adjust = -content.italics_correction()
      (extra_height, line_pos, content_pos, baseline, thickness, line_adjust)
    }
    Above => {
      let sep = font.math().overbar_extra_ascender.at(size)
      let thickness = font.math().overbar_rule_thickness.at(size)
      let gap = font.math().overbar_vertical_gap.at(size)
      let extra_height = sep + thickness + gap
      let line_pos = @library.Point::with_y(sep + thickness.div_by(2.0))
      let content_pos = @library.Point::with_y(extra_height)
      let baseline = content.ascent() + extra_height
      let line_adjust = @library.Abs::zero()
      (extra_height, line_pos, content_pos, baseline, thickness, line_adjust)
    }
  }
  let width = content.width()
  let height = content.height() + extra_height
  let size = @library.Axes::new(width, height)
  let line_width = width + line_adjust
  let content_text_like = content.is_text_like()
  let content_italics_correction = content.italics_correction()
  let frame = @library.Frame::soft(size)
  frame.set_baseline(baseline)
  frame.push_frame(content_pos, content.into_frame())
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
  ctx.push(
    Frame(
      FrameFragment::new(props, styles, frame)
      .with_italics_correction(content_italics_correction)
      .with_text_like(content_text_like),
    ),
  )
}
