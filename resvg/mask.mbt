// Port of `resvg/src/mask.rs`.

///|
/// Upstream `mask::apply`.
fn mask_apply(
  mask : @usvg.Mask,
  ctx : Context,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  if mask.root().children().is_empty() {
    pixmap.fill(@skia.color_transparent)
    return
  }
  let w = pixmap.width().reinterpret_as_uint()
  let h = pixmap.height().reinterpret_as_uint()
  let mask_pixmap = @skia.Pixmap::new(w, h).unwrap()
  {
    // TODO: only when needed
    // Mask has to be clipped by mask.region
    let alpha_mask = @skia.Mask::new(w, h).unwrap()
    alpha_mask.fill_path(
      @path.PathBuilder::from_rect(mask.rect().to_rect()),
      Winding,
      true,
      transform,
    )
    render_nodes(mask.root(), ctx, transform, mask_pixmap)
    mask_pixmap.apply_mask(alpha_mask)
  }
  if mask.mask() is Some(mask) {
    mask_apply(mask, ctx, transform, pixmap)
  }
  let mask_type : @skia.MaskType = match mask.kind() {
    Luminance => Luminance
    Alpha => Alpha
  }
  let mask = @skia.Mask::from_pixmap(mask_pixmap, mask_type)
  pixmap.apply_mask(mask)
}
