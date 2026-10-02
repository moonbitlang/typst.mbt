// Port of `krilla-svg/src/mask.rs`.

///|
/// Render a usvg `Mask` into a surface.
fn svg_mask_render(
  mask : @usvg.Mask,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Int {
  let sub_surface = surface.stream_surface()
  let mut pop_count = 0
  if mask.mask() is Some(sub_mask) {
    pop_count += svg_mask_render(sub_mask, sub_surface, process_context)
  }
  let clip_path = {
    let rect = mask.rect().to_rect()
    svg_rect_to_clip_path(
      @export.Rect::from_ltrb(
        rect.left().to_double(),
        rect.top().to_double(),
        rect.right().to_double(),
        rect.bottom().to_double(),
      ).unwrap(),
    )
  }
  sub_surface.push_clip_path(clip_path, NonZero)
  pop_count += 1
  svg_group_render(mask.root(), sub_surface, process_context)
  for _ in 0..<pop_count {
    sub_surface.pop()
  }
  let stream = sub_surface.finish_stream()
  surface.push_mask(stream, svg_convert_mask_type(mask.kind()))
  1
}
