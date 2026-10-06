// Port of `hayro/src/lib.rs`: rendering PDF pages into pixmaps with
// vello_cpu.

///|
/// A cache used by the renderer.
///
/// Ideally, such a cache should be constructed once per PDF and then reused
/// across multiple render invocations on the same document.
pub struct RenderCache {
  priv interpreter_cache : @interpret.InterpreterCache
  priv outline_cache : Map[@interpret.U128, @kurbo.BezPath]
}

///|
/// Create a new render cache.
pub fn RenderCache::new() -> RenderCache {
  { interpreter_cache: @interpret.InterpreterCache::new(), outline_cache: {}, }
}

///|
/// Settings to apply during rendering.
pub(all) struct RenderSettings {
  /// How much the contents should be scaled into the x direction.
  x_scale : Float
  /// How much the contents should be scaled into the y direction.
  y_scale : Float
  /// The width of the viewport. If this is set to `None`, the width will be
  /// chosen automatically based on the scale factor and the dimensions of
  /// the PDF.
  width : Int?
  /// The height of the viewport. If this is set to `None`, the height will
  /// be chosen automatically based on the scale factor and the dimensions of
  /// the PDF.
  height : Int?
  /// The background color. Determines the color of the base rectangle
  /// during rendering to a pixmap.
  bg_color : @vello_cpu.AlphaColor
}

///|
pub impl Default for RenderSettings with fn default() {
  {
    x_scale: 1.0,
    y_scale: 1.0,
    width: None,
    height: None,
    bg_color: @vello_cpu.transparent,
  }
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RenderSettings with Default::{default}

///|
/// `f64 as u16` (saturating, NaN maps to 0).
fn f64_as_u16(x : Double) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 65535.0 {
    65535
  } else {
    x.to_int()
  }
}

///|
/// Render the page with the given settings to a pixmap.
pub fn render(
  page : @hayro_syntax.Page,
  cache : RenderCache,
  interpreter_settings : @interpret.InterpreterSettings,
  render_settings : RenderSettings,
) -> @vello_cpu.Pixmap {
  let x_scale = render_settings.x_scale
  let y_scale = render_settings.y_scale
  let (width, height) = page.render_dimensions()
  let scaled_width = (width * x_scale).to_double()
  let scaled_height = (height * y_scale).to_double()
  let initial_transform = @kurbo.Affine::scale_non_uniform(
      x_scale.to_double(),
      y_scale.to_double(),
    ) *
    @interpret.transform_to_kurbo(page.initial_transform(true))
  let pix_width = match render_settings.width {
    Some(w) => w
    None => f64_as_u16(scaled_width.floor())
  }
  let pix_height = match render_settings.height {
    Some(h) => h
    None => f64_as_u16(scaled_height.floor())
  }
  let state = @interpret.Context::new(
    initial_transform,
    @kurbo.Rect::new(0.0, 0.0, pix_width.to_double(), pix_height.to_double()),
    cache.interpreter_cache,
    page.xref(),
    interpreter_settings,
  )
  let device = Renderer::new(pix_width, pix_height, cache.outline_cache)
  device.ctx.set_paint(Solid(render_settings.bg_color))
  device.ctx.fill_rect(
    @kurbo.Rect::new(0.0, 0.0, pix_width.to_double(), pix_height.to_double()),
  )
  let clip_path = @interpret.rect_to_kurbo(page.intersected_crop_box())
    .to_path(0.1)
    .transform(initial_transform)
  @interpret.Device::push_clip_path(device, { path: clip_path, fill: NonZero, })
  @interpret.Device::push_transparency_group(device, 1.0, None, Normal)
  @interpret.interpret_page(page, state, device)
  @interpret.Device::pop_transparency_group(device)
  @interpret.Device::pop_clip(device)
  let pixmap = @vello_cpu.Pixmap::new(pix_width, pix_height)
  device.ctx.render(pixmap)
  pixmap
}
