// Port of `resvg/src/filter/displacement_map.rs`.

///|
/// Applies a displacement map.
///
/// - `map` pixels should have a **unpremultiplied alpha**.
/// - `src` pixels can have any alpha method.
///
/// `sx` and `sy` indicate canvas scale.
///
/// # Panics
///
/// When `src`, `map` and `dest` have different sizes.
fn displacement_map_apply(
  fe : @usvg.FeDisplacementMap,
  sx : Float,
  sy : Float,
  src : @skia.Pixmap,
  map : @skia.Pixmap,
  dest : @skia.Pixmap,
) -> Unit {
  guard! src.width() == map.width() && src.width() == dest.width()
  guard! src.height() == map.height() && src.height() == dest.height()
  let w = src.width()
  let h = src.height()
  let src_data = src.pixels()
  let dest_data = dest.pixels()
  let mut x = 0
  let mut y = 0
  for pixel in map.pixels() {
    let calc_offset = fn(channel : @usvg.ColorChannel) -> Float {
      let c = match channel {
        B => px_b(pixel)
        G => px_g(pixel)
        R => px_r(pixel)
        A => px_a(pixel)
      }
      Float::from_int(c) / 255.0 - 0.5
    }
    let dx = calc_offset(fe.x_channel_selector)
    let dy = calc_offset(fe.y_channel_selector)
    let ox = f32_to_i32(@skia.roundf(Float::from_int(x) + dx * sx * fe.scale))
    let oy = f32_to_i32(@skia.roundf(Float::from_int(y) + dy * sy * fe.scale))

    // TODO: we should use some kind of anti-aliasing when offset is on a pixel border
    if x < w && y < h && ox >= 0 && ox < w && oy >= 0 && oy < h {
      let idx = oy * w + ox
      let idx1 = y * w + x
      dest_data[idx1] = src_data[idx]
    }
    x += 1
    if x == w {
      x = 0
      y += 1
    }
  }
}
