// Port of `resvg/src/clip.rs`.

///|
/// Upstream `clip::apply`.
fn clip_apply(
  clip : @usvg.ClipPath,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  let clip_pixmap = @skia.Pixmap::new(
    pixmap.width().reinterpret_as_uint(),
    pixmap.height().reinterpret_as_uint(),
  ).unwrap()
  clip_pixmap.fill(@skia.color_black)
  draw_children(
    clip.root(),
    Clear,
    transform.pre_concat(clip.transform()),
    clip_pixmap,
  )
  if clip.clip_path() is Some(clip) {
    clip_apply(clip, transform, pixmap)
  }
  let mask = @skia.Mask::from_pixmap(clip_pixmap, Alpha)
  mask.invert()
  pixmap.apply_mask(mask)
}

///|
fn draw_children(
  parent : @usvg.Group,
  mode : @skia.BlendMode,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  for child in parent.children() {
    match child {
      Path(path) => {
        if !path.is_visible() {
          continue
        }

        // We could use any values here. They will not be used anyway.
        let ctx = { max_bbox: @path.IntRect::from_xywh(0, 0, 1, 1).unwrap(), }
        fill_path(path, mode, ctx, transform, pixmap) |> ignore
      }
      Text(text) => draw_children(text.flattened(), mode, transform, pixmap)
      Group(group) => {
        let transform = transform.pre_concat(group.transform())
        if group.clip_path() is Some(clip) {
          // If a `clipPath` child also has a `clip-path`
          // then we should render this child on a new canvas,
          // clip it, and only then draw it to the `clipPath`.
          clip_group(group, clip, transform, pixmap)
        } else {
          draw_children(group, mode, transform, pixmap)
        }
      }
      _ => ()
    }
  }
}

///|
fn clip_group(
  children : @usvg.Group,
  clip : @usvg.ClipPath,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  let clip_pixmap = @skia.Pixmap::new(
    pixmap.width().reinterpret_as_uint(),
    pixmap.height().reinterpret_as_uint(),
  ).unwrap()
  draw_children(children, SourceOver, transform, clip_pixmap)
  clip_apply(clip, transform, clip_pixmap)
  let paint : @skia.PixmapPaint = {
    ..@skia.PixmapPaint::default(),
    blend_mode: Xor,
  }
  pixmap.draw_pixmap(
    0,
    0,
    clip_pixmap,
    paint,
    @path.Transform::identity(),
    None,
  )
}
