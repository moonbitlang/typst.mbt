// Port of `resvg/src/render.rs`.

///|
priv struct Context {
  max_bbox : @path.IntRect
}

///|
fn render_nodes(
  parent : @usvg.Group,
  ctx : Context,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  for node in parent.children() {
    render_node_inner(node, ctx, transform, pixmap)
  }
}

///|
/// Upstream `render::render_node`.
fn render_node_inner(
  node : @usvg.Node,
  ctx : Context,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  match node {
    Group(group) => render_group(group, ctx, transform, pixmap) |> ignore
    Path(path) => render_path(path, SourceOver, ctx, transform, pixmap)
    Image(image) => render_image(image, transform, pixmap)
    Text(text) =>
      render_group(text.flattened(), ctx, transform, pixmap) |> ignore
  }
}

///|
fn render_group(
  group : @usvg.Group,
  ctx : Context,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit? {
  let transform = transform.pre_concat(group.transform())
  if !group.should_isolate() {
    render_nodes(group, ctx, transform, pixmap)
    return Some(())
  }
  guard group.layer_bounding_box().transform(transform) is Some(bbox) else {
    return None
  }
  let mut ibbox = if group.filters().is_empty() {
    // Convert group bbox into an integer one, expanding each side outwards by 2px
    // to make sure that anti-aliased pixels would not be clipped.
    guard checked_sub_i32(f32_to_i32(@skia.floorf(bbox.x())), 2) is Some(x) else {
      return None
    }
    guard checked_sub_i32(f32_to_i32(@skia.floorf(bbox.y())), 2) is Some(y) else {
      return None
    }
    guard checked_add_u32(f32_to_u32(@skia.ceilf(bbox.width())), 4) is Some(w) else {
      return None
    }
    guard checked_add_u32(f32_to_u32(@skia.ceilf(bbox.height())), 4) is Some(h) else {
      return None
    }
    guard @path.IntRect::from_xywh(x, y, w, h) is Some(r) else { return None }
    r
  } else {
    // The bounding box for groups with filters is special and should not be expanded by 2px,
    // because it's already acting as a clipping region.
    let bbox = bbox.to_int_rect()
    // Make sure our filter region is not bigger than 4x the canvas size.
    // This is required mainly to prevent huge filter regions that would tank the performance.
    // It should not affect the final result in any way.
    guard fit_to_rect(bbox, ctx.max_bbox) is Some(r) else { return None }
    r
  }

  // Make sure our layer is not bigger than 4x the canvas size.
  // This is required to prevent huge layers.
  if group.filters().is_empty() {
    guard fit_to_rect(ibbox, ctx.max_bbox) is Some(r) else { return None }
    ibbox = r
  }
  let shift_ts = {
    // Original shift.
    let mut dx = bbox.x()
    let mut dy = bbox.y()

    // Account for subpixel positioned layers.
    dx -= bbox.x() - i32_to_f32(ibbox.x())
    dy -= bbox.y() - i32_to_f32(ibbox.y())
    @path.Transform::from_translate(-dx, -dy)
  }
  let transform = shift_ts.pre_concat(transform)
  // Failed to allocate a group layer.
  guard @skia.Pixmap::new(ibbox.width(), ibbox.height()) is Some(sub_pixmap) else {
    return None
  }
  render_nodes(group, ctx, transform, sub_pixmap)
  if !group.filters().is_empty() {
    for filter in group.filters() {
      filter_apply(filter, transform, sub_pixmap)
    }
  }
  if group.clip_path() is Some(clip_path) {
    clip_apply(clip_path, transform, sub_pixmap)
  }
  if group.mask() is Some(mask) {
    mask_apply(mask, ctx, transform, sub_pixmap)
  }
  let paint : @skia.PixmapPaint = {
    opacity: group.opacity().get(),
    blend_mode: convert_blend_mode(group.blend_mode()),
    quality: Nearest,
  }
  pixmap.draw_pixmap(
    ibbox.x(),
    ibbox.y(),
    sub_pixmap,
    paint,
    @path.Transform::identity(),
    None,
  )
  Some(())
}

///|
fn convert_blend_mode(mode : @usvg.BlendMode) -> @skia.BlendMode {
  match mode {
    Normal => SourceOver
    Multiply => Multiply
    Screen => Screen
    Overlay => Overlay
    Darken => Darken
    Lighten => Lighten
    ColorDodge => ColorDodge
    ColorBurn => ColorBurn
    HardLight => HardLight
    SoftLight => SoftLight
    Difference => Difference
    Exclusion => Exclusion
    Hue => Hue
    Saturation => Saturation
    Color => Color
    Luminosity => Luminosity
  }
}
