// Port of `typst-render/src/lib.rs` and `format.rs`: rendering of Typst
// documents into raster images.

///|
/// Document settings for PNG export (upstream
/// `PngFormatOptions<Complete>`).
pub(all) struct PngFormatOptions {
  /// The PPI (pixels per inch) to render at when exporting a PNG.
  ppi : Double
} derive(Eq)

///|
/// The PNG format options configured by a document (upstream
/// `options.get::<PngFormat>()`).
pub fn PngFormatOptions::get(
  options : @library.DocumentFormatOptions,
) -> PngFormatOptions {
  let o = options.get(@library.png_format_elem())
  let ppi = o.get(@library.png_format_elem_ppi)
  let ppi = match ppi.v {
    Float(f) => f
    Int(i) => i.to_double()
    _ => 144.0
  }
  { ppi, }
}

///|
/// Partially specified PNG settings (upstream `PngFormatOptions<Partial>`).
pub(all) struct PartialPngFormatOptions {
  ppi : Double?
} derive(Eq, Default)

///|
/// Resolves the partial options to complete ones, given defaults.
pub fn PartialPngFormatOptions::resolve(
  self : PartialPngFormatOptions,
  default : PngFormatOptions,
) -> PngFormatOptions {
  { ppi: self.ppi.unwrap_or(default.ppi), }
}

///|
/// Settings for raster image export (upstream `RenderOptions<Partial>`).
pub(all) struct RenderOptions {
  /// By default, rendered pages are bounded to the page size. In some
  /// circumstances, such as when preparing documents for print, it may be
  /// desirable to include content beyond these bounds to account for bleed
  /// margins. This field allows expanding the rendered area to include such
  /// bleed.
  render_bleed : Bool
  /// Format options that override the defaults set by the document.
  format : PartialPngFormatOptions
} derive(Eq, Default)

///|
/// Resolved settings for raster export (upstream `RenderOptions<Complete>`).
pub(all) struct CompleteRenderOptions {
  render_bleed : Bool
  format : PngFormatOptions
} derive(Eq)

///|
/// Resolves the final options given those set by the document.
pub fn RenderOptions::resolve(
  self : RenderOptions,
  doc : PngFormatOptions,
) -> CompleteRenderOptions {
  { render_bleed: self.render_bleed, format: self.format.resolve(doc), }
}

///|
/// Renders an SVG image into a texture (upstream
/// `resvg::render(tree, ts, &mut texture.as_mut())`). Installed once `usvg`
/// and `resvg` are ported; until then SVG images and glyphs are skipped.
pub let svg_image_renderer : Ref[
  ((@library.SvgImage, @skia.Pixmap, UInt, UInt) -> Unit)?,
] = Ref::new(None)

///|
/// Export a page into a raster image.
///
/// This renders the page at the given number of pixels per inch and returns
/// the resulting `tiny-skia` pixel buffer.
pub fn render(
  page : @layout.Page,
  opts : CompleteRenderOptions,
) -> @skia.Pixmap raise RenderPanic {
  let bleed = if opts.render_bleed {
    page.bleed
  } else {
    @library.Sides::splat(@library.Abs::zero())
  }
  let size = page.frame.size().add_size(bleed.sum_by_axis())
  let pixel_per_pt = opts.format.ppi.to_float() / 72.0
  let pxw = @skia.f32_to_u32(
    @skia.fmax(@skia.roundf(pixel_per_pt * to_f32(size.x)), 1.0),
  )
  let pxh = @skia.f32_to_u32(
    @skia.fmax(@skia.roundf(pixel_per_pt * to_f32(size.y)), 1.0),
  )
  let ts = @path.Transform::from_scale(pixel_per_pt, pixel_per_pt)
  let state = State::new(size, ts, pixel_per_pt)
  let canvas = must(@skia.Pixmap::new(pxw, pxh))
  if page.fill_or_white() is Some(fill) {
    if fill is Solid(color) {
      canvas.fill(to_sk_color(color.to_process()))
    } else {
      let rect = @library.Geometry::Rect(size).filled(fill)
      render_shape(canvas, state, rect)
    }
  }
  let state = state.pre_translate({ x: bleed.left, y: bleed.top, })
  render_frame(canvas, state, page.frame)
  canvas
}

///|
/// Export a document with potentially multiple pages into a single raster
/// image.
pub fn render_merged(
  document : @layout.PagedDocument,
  opts : RenderOptions,
  gap : @library.Abs,
  fill : @library.Color?,
) -> @skia.Pixmap raise RenderPanic {
  let opts = opts.resolve(PngFormatOptions::get(document.options()))
  let pixmaps = document.pages().map(page => render(page, opts))
  let pixel_per_pt = opts.format.ppi.to_float() / 72.0
  let gap = @skia.f32_to_u32(@skia.roundf(pixel_per_pt * to_f32(gap)))
  let mut pxw = 0U
  let mut pxh = 0U
  for pixmap in pixmaps {
    let w = pixmap.width().reinterpret_as_uint()
    if w > pxw {
      pxw = w
    }
    pxh += pixmap.height().reinterpret_as_uint()
  }
  let n = pixmaps.length()
  pxh += gap * (if n > 0 { n - 1 } else { 0 }).reinterpret_as_uint()
  let canvas = must(@skia.Pixmap::new(pxw, pxh))
  if fill is Some(fill) {
    canvas.fill(to_sk_color(fill.to_process()))
  }
  let mut y = 0U
  for pixmap in pixmaps {
    canvas.draw_pixmap(
      0,
      y.reinterpret_as_int(),
      pixmap,
      @skia.PixmapPaint::default(),
      @path.Transform::identity(),
      None,
    )
    y += pixmap.height().reinterpret_as_uint() + gap
  }
  canvas
}

///|
/// Additional metadata carried through the rendering process.
priv struct State {
  /// The transform of the current item.
  transform : @path.Transform
  /// The transform of the first hard frame in the hierarchy.
  container_transform : @path.Transform
  /// The mask of the current item.
  mask : @skia.Mask?
  /// The pixel per point ratio.
  pixel_per_pt : Float
  /// The size of the first hard frame in the hierarchy.
  size : @library.Axes[@library.Abs]
}

///|
fn State::new(
  size : @library.Axes[@library.Abs],
  transform : @path.Transform,
  pixel_per_pt : Float,
) -> State {
  { size, transform, container_transform: transform, pixel_per_pt, mask: None, }
}

///|
/// Pre translate the current item's transform.
fn State::pre_translate(self : State, pos : @library.Point) -> State {
  {
    ..self,
    transform: self.transform.pre_translate(to_f32(pos.x), to_f32(pos.y)),
  }
}

///|
fn State::pre_scale(self : State, scale : @library.Axes[@library.Abs]) -> State {
  {
    ..self,
    transform: self.transform.pre_scale(to_f32(scale.x), to_f32(scale.y)),
  }
}

///|
/// Pre concat the current item's transform.
fn State::pre_concat(self : State, transform : @path.Transform) -> State {
  { ..self, transform: self.transform.pre_concat(transform), }
}

///|
/// Sets the current mask.
///
/// If no mask is provided, the parent mask is used.
fn State::with_mask(self : State, mask : @skia.Mask?) -> State {
  { ..self, mask: if mask is Some(_) { mask } else { self.mask }, }
}

///|
/// Sets the size of the first hard frame in the hierarchy.
fn State::with_size(self : State, size : @library.Axes[@library.Abs]) -> State {
  { ..self, size, }
}

///|
/// Pre concat the container's transform.
fn State::pre_concat_container(
  self : State,
  transform : @path.Transform,
) -> State {
  {
    ..self,
    container_transform: self.container_transform.pre_concat(transform),
  }
}

///|
/// Render a frame into the canvas.
fn render_frame(
  canvas : @skia.Pixmap,
  state : State,
  frame : @library.Frame,
) -> Unit raise RenderPanic {
  for entry in frame.items() {
    let (pos, item) = entry
    match item {
      Group(group) => render_group(canvas, state, pos, group)
      Text(text) => render_text(canvas, state.pre_translate(pos), text)
      Shape(shape, _) => render_shape(canvas, state.pre_translate(pos), shape)
      Image(image, size, _) =>
        render_image(canvas, state.pre_translate(pos), image, size)
      Link(_, _) => ()
      Tag(_) => ()
    }
  }
}

///|
/// Render a group frame with optional transform and clipping into the canvas.
fn render_group(
  canvas : @skia.Pixmap,
  state : State,
  pos : @library.Point,
  group : @library.GroupItem,
) -> Unit raise RenderPanic {
  let sk_transform = to_sk_transform(group.transform)
  let state = match group.frame.kind() {
    Soft => state.pre_translate(pos).pre_concat(sk_transform)
    Hard =>
      state
      .pre_translate(pos)
      .pre_concat(sk_transform)
      .pre_concat_container(
        state.transform.post_concat(must(state.container_transform.invert())),
      )
      .pre_concat_container(
        to_sk_transform(@library.Transform::translate(pos.x, pos.y)),
      )
      .pre_concat_container(sk_transform)
      .with_size(group.frame.size())
  }
  let mut mask = state.mask
  if group.clip is Some(clip_curve) &&
    convert_curve(clip_curve).bind(path => path.transform(state.transform))
    is Some(path) {
    match mask {
      Some(m) => {
        let m = m.clone()
        m.intersect_path(path, Winding, true, @path.Transform::identity())
        mask = Some(m)
      }
      None => {
        let pxw = canvas.width().reinterpret_as_uint()
        let pxh = canvas.height().reinterpret_as_uint()
        guard @skia.Mask::new(pxw, pxh) is Some(m) else {
          // Fails if clipping rect is empty. In that case we just
          // clip everything by returning.
          return
        }
        m.fill_path(path, Winding, true, @path.Transform::identity())
        mask = Some(m)
      }
    }
  }
  render_frame(canvas, state.with_mask(mask), group.frame)
}

///|
fn to_sk_transform(transform : @library.Transform) -> @path.Transform {
  @path.Transform::from_row(
    transform.sx.get().to_float(),
    transform.ky.get().to_float(),
    transform.kx.get().to_float(),
    transform.sy.get().to_float(),
    to_f32(transform.tx),
    to_f32(transform.ty),
  )
}

///|
/// Convert to a number of points as f32 (`AbsExt::to_f32`).
fn to_f32(abs : @library.Abs) -> Float {
  abs.to_pt().to_float()
}
