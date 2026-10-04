// Port of `resvg/src/filter/mod.rs`.
//
// Upstream's `ImageRef`/`ImageRefMut` (RGBA8 slices) are the pixmap's packed
// pixels (`FixedArray[UInt]`, red in the lowest byte) plus its size.

// TODO: apply single primitive filters in-place

///|
priv suberror FilterError {
  InvalidRegion
  NoResults
}

///|
fn px_r(p : UInt) -> Int {
  (p & 0xFF).reinterpret_as_int()
}

///|
fn px_g(p : UInt) -> Int {
  ((p >> 8) & 0xFF).reinterpret_as_int()
}

///|
fn px_b(p : UInt) -> Int {
  ((p >> 16) & 0xFF).reinterpret_as_int()
}

///|
fn px_a(p : UInt) -> Int {
  (p >> 24).reinterpret_as_int()
}

///|
fn px_pack(r : Int, g : Int, b : Int, a : Int) -> UInt {
  (r & 0xFF).reinterpret_as_uint() |
  ((g & 0xFF).reinterpret_as_uint() << 8) |
  ((b & 0xFF).reinterpret_as_uint() << 16) |
  ((a & 0xFF).reinterpret_as_uint() << 24)
}

///|
fn try_create(width : UInt, height : UInt) -> @skia.Pixmap raise FilterError {
  match @skia.Pixmap::new(width, height) {
    Some(p) => p
    None => raise InvalidRegion
  }
}

///|
fn copy_region(
  pixmap : @skia.Pixmap,
  region : @path.IntRect,
) -> @skia.Pixmap raise FilterError {
  let rect = match
    @path.IntRect::from_xywh(
      region.x(),
      region.y(),
      region.width(),
      region.height(),
    ) {
    Some(r) => r
    None => raise InvalidRegion
  }
  match pixmap.clone_rect(rect) {
    Some(p) => p
    None => raise InvalidRegion
  }
}

///|
fn clear(pixmap : @skia.Pixmap) -> Unit {
  pixmap.fill(@skia.color_transparent)
}

///|
fn into_srgb(pixmap : @skia.Pixmap) -> Unit {
  let data = pixmap.pixels()
  demultiply_alpha(data)
  from_linear_rgb(data)
  multiply_alpha(data)
}

///|
fn into_linear_rgb(pixmap : @skia.Pixmap) -> Unit {
  let data = pixmap.pixels()
  demultiply_alpha(data)
  to_linear_rgb(data)
  multiply_alpha(data)
}

///|
/// Multiplies provided pixels alpha.
fn multiply_alpha(data : FixedArray[UInt]) -> Unit {
  for i in 0..<data.length() {
    let p = data[i]
    let a = Float::from_int(px_a(p)) / 255.0
    let b = f32_to_u8(Float::from_int(px_b(p)) * a + 0.5)
    let g = f32_to_u8(Float::from_int(px_g(p)) * a + 0.5)
    let r = f32_to_u8(Float::from_int(px_r(p)) * a + 0.5)
    data[i] = px_pack(r, g, b, px_a(p))
  }
}

///|
/// Demultiplies provided pixels alpha.
fn demultiply_alpha(data : FixedArray[UInt]) -> Unit {
  for i in 0..<data.length() {
    let p = data[i]
    let a = Float::from_int(px_a(p)) / 255.0
    let b = f32_to_u8(Float::from_int(px_b(p)) / a + 0.5)
    let g = f32_to_u8(Float::from_int(px_g(p)) / a + 0.5)
    let r = f32_to_u8(Float::from_int(px_r(p)) / a + 0.5)
    data[i] = px_pack(r, g, b, px_a(p))
  }
}

///|
/// Precomputed sRGB to LinearRGB table.
///
/// Since we are storing the result in `u8`, there is no need to compute those
/// values each time. Mainly because it's very expensive.
///
/// ```text
/// if (C_srgb <= 0.04045)
///     C_lin = C_srgb / 12.92;
///  else
///     C_lin = pow((C_srgb + 0.055) / 1.055, 2.4);
/// ```
///
/// Thanks to librsvg for the idea.
let srgb_to_linear_rgb_table : ReadOnlyArray[Int] = [
  0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3,
  3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 8, 8, 8, 8, 9, 9,
  9, 10, 10, 10, 11, 11, 12, 12, 12, 13, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17,
  17, 18, 18, 19, 19, 20, 20, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 27, 27, 28,
  29, 29, 30, 30, 31, 32, 32, 33, 34, 35, 35, 36, 37, 37, 38, 39, 40, 41, 41, 42,
  43, 44, 45, 45, 46, 47, 48, 49, 50, 51, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
  61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 76, 77, 78, 79, 80, 81,
  82, 84, 85, 86, 87, 88, 90, 91, 92, 93, 95, 96, 97, 99, 100, 101, 103, 104, 105,
  107, 108, 109, 111, 112, 114, 115, 116, 118, 119, 121, 122, 124, 125, 127, 128,
  130, 131, 133, 134, 136, 138, 139, 141, 142, 144, 146, 147, 149, 151, 152, 154,
  156, 157, 159, 161, 163, 164, 166, 168, 170, 171, 173, 175, 177, 179, 181, 183,
  184, 186, 188, 190, 192, 194, 196, 198, 200, 202, 204, 206, 208, 210, 212, 214,
  216, 218, 220, 222, 224, 226, 229, 231, 233, 235, 237, 239, 242, 244, 246, 248,
  250, 253, 255,
]

///|
/// Precomputed LinearRGB to sRGB table.
///
/// Since we are storing the result in `u8`, there is no need to compute those
/// values each time. Mainly because it's very expensive.
///
/// ```text
/// if (C_lin <= 0.0031308)
///     C_srgb = C_lin * 12.92;
/// else
///     C_srgb = 1.055 * pow(C_lin, 1.0 / 2.4) - 0.055;
/// ```
///
/// Thanks to librsvg for the idea.
let linear_rgb_to_srgb_table : ReadOnlyArray[Int] = [
  0, 13, 22, 28, 34, 38, 42, 46, 50, 53, 56, 59, 61, 64, 66, 69, 71, 73, 75, 77,
  79, 81, 83, 85, 86, 88, 90, 92, 93, 95, 96, 98, 99, 101, 102, 104, 105, 106, 108,
  109, 110, 112, 113, 114, 115, 117, 118, 119, 120, 121, 122, 124, 125, 126, 127,
  128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143,
  144, 145, 146, 147, 148, 148, 149, 150, 151, 152, 153, 154, 155, 155, 156, 157,
  158, 159, 159, 160, 161, 162, 163, 163, 164, 165, 166, 167, 167, 168, 169, 170,
  170, 171, 172, 173, 173, 174, 175, 175, 176, 177, 178, 178, 179, 180, 180, 181,
  182, 182, 183, 184, 185, 185, 186, 187, 187, 188, 189, 189, 190, 190, 191, 192,
  192, 193, 194, 194, 195, 196, 196, 197, 197, 198, 199, 199, 200, 200, 201, 202,
  202, 203, 203, 204, 205, 205, 206, 206, 207, 208, 208, 209, 209, 210, 210, 211,
  212, 212, 213, 213, 214, 214, 215, 215, 216, 216, 217, 218, 218, 219, 219, 220,
  220, 221, 221, 222, 222, 223, 223, 224, 224, 225, 226, 226, 227, 227, 228, 228,
  229, 229, 230, 230, 231, 231, 232, 232, 233, 233, 234, 234, 235, 235, 236, 236,
  237, 237, 238, 238, 238, 239, 239, 240, 240, 241, 241, 242, 242, 243, 243, 244,
  244, 245, 245, 246, 246, 246, 247, 247, 248, 248, 249, 249, 250, 250, 251, 251,
  251, 252, 252, 253, 253, 254, 254, 255, 255,
]

///|
/// Converts input pixel from sRGB into LinearRGB.
///
/// Provided pixels should have an **unpremultiplied alpha**.
///
/// RGB channels order of the input image doesn't matter, but alpha channel must be the last one.
fn to_linear_rgb(data : FixedArray[UInt]) -> Unit {
  let t = srgb_to_linear_rgb_table
  for i in 0..<data.length() {
    let p = data[i]
    data[i] = px_pack(t[px_r(p)], t[px_g(p)], t[px_b(p)], px_a(p))
  }
}

///|
/// Converts input pixel from LinearRGB into sRGB.
///
/// Provided pixels should have an **unpremultiplied alpha**.
///
/// RGB channels order of the input image doesn't matter, but alpha channel must be the last one.
fn from_linear_rgb(data : FixedArray[UInt]) -> Unit {
  let t = linear_rgb_to_srgb_table
  for i in 0..<data.length() {
    let p = data[i]
    data[i] = px_pack(t[px_r(p)], t[px_g(p)], t[px_b(p)], px_a(p))
  }
}

///|
fn f32_bound(min : Float, val : Float, max : Float) -> Float {
  if val > max {
    max
  } else if val < min {
    min
  } else {
    val
  }
}

///|
priv struct FImage {
  /// Filter primitive result.
  ///
  /// All images have the same size which is equal to the current filter region.
  image : @skia.Pixmap
  /// Image's region that has actual data.
  ///
  /// Region is in global coordinates and not in `image` one.
  ///
  /// Image's content outside this region will be transparent/cleared.
  ///
  /// Currently used only for `feTile`.
  region : @path.IntRect
  /// The current color space.
  color_space : @usvg.ColorInterpolation
}

///|
fn FImage::from_image(
  image : @skia.Pixmap,
  color_space : @usvg.ColorInterpolation,
) -> FImage {
  let w = image.width().reinterpret_as_uint()
  let h = image.height().reinterpret_as_uint()
  { image, region: @path.IntRect::from_xywh(0, 0, w, h).unwrap(), color_space, }
}

///|
fn FImage::into_color_space(
  self : FImage,
  color_space : @usvg.ColorInterpolation,
) -> FImage {
  if color_space != self.color_space {
    let region = self.region
    let image = self.take()
    match color_space {
      SRGB => into_srgb(image)
      LinearRGB => into_linear_rgb(image)
    }
    { image, region, color_space, }
  } else {
    self
  }
}

///|
/// Upstream unwraps the `Rc` or clones the shared pixmap; images are always
/// copied here since results may be shared.
fn FImage::take(self : FImage) -> @skia.Pixmap {
  self.image.clone()
}

///|
fn FImage::width(self : FImage) -> UInt {
  self.image.width().reinterpret_as_uint()
}

///|
fn FImage::height(self : FImage) -> UInt {
  self.image.height().reinterpret_as_uint()
}

///|
priv struct FilterResult {
  name : String
  image : FImage
}

///|
/// Upstream `filter::apply`.
fn filter_apply(
  filter : @usvg.Filter,
  ts : @path.Transform,
  source : @skia.Pixmap,
) -> Unit {
  try {
    let image = apply_inner(filter, ts, source)
    apply_to_canvas(image, source)
  } catch {
    // Clear on error.
    InvalidRegion =>
      // Filter has an invalid region.
      source.fill(@skia.color_transparent)
    NoResults => source.fill(@skia.color_transparent)
  }
}

///|
fn transform_rect(
  r : @path.NonZeroRect,
  ts : @path.Transform,
) -> @path.IntRect raise FilterError {
  match r.transform(ts) {
    Some(r) => r.to_int_rect()
    None => raise InvalidRegion
  }
}

///|
fn find_result(results : Array[FilterResult], name : String) -> FImage? {
  for i = results.length() - 1; i >= 0; i = i - 1 {
    if results[i].name == name {
      return Some(results[i].image)
    }
  }
  None
}

///|
fn apply_inner(
  filter : @usvg.Filter,
  ts : @path.Transform,
  source : @skia.Pixmap,
) -> FImage raise FilterError {
  let region = transform_rect(filter.rect(), ts)
  let results : Array[FilterResult] = []
  for primitive in filter.primitives() {
    let mut subregion = transform_rect(primitive.rect(), ts)

    // `feOffset` inherits its region from the input.
    if primitive.kind() is Offset(fe) && fe.input is Reference(name) {
      if find_result(results, name) is Some(res) {
        subregion = res.region
      }
    }
    let cs = primitive.color_interpolation()
    let mut result = match primitive.kind() {
      Blend(fe) => {
        let input1 = get_input(fe.input1, region, source, results)
        let input2 = get_input(fe.input2, region, source, results)
        apply_blend(fe, cs, region, input1, input2)
      }
      DropShadow(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_drop_shadow(fe, cs, ts, input)
      }
      Flood(fe) => apply_flood(fe, region)
      GaussianBlur(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_blur(fe, cs, ts, input)
      }
      Offset(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_offset(fe, ts, input)
      }
      Composite(fe) => {
        let input1 = get_input(fe.input1, region, source, results)
        let input2 = get_input(fe.input2, region, source, results)
        apply_composite(fe, cs, region, input1, input2)
      }
      Merge(fe) => apply_merge(fe, cs, region, source, results)
      Tile(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_tile(input, region)
      }
      Image(fe) => apply_image(fe, region, subregion, ts)
      ComponentTransfer(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_component_transfer(fe, cs, input)
      }
      ColorMatrix(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_color_matrix(fe, cs, input)
      }
      ConvolveMatrix(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_convolve_matrix(fe, cs, input)
      }
      Morphology(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_morphology(fe, cs, ts, input)
      }
      DisplacementMap(fe) => {
        let input1 = get_input(fe.input1, region, source, results)
        let input2 = get_input(fe.input2, region, source, results)
        apply_displacement_map(fe, region, cs, ts, input1, input2)
      }
      Turbulence(fe) => apply_turbulence(fe, region, cs, ts)
      DiffuseLighting(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_diffuse_lighting(fe, region, cs, ts, input)
      }
      SpecularLighting(fe) => {
        let input = get_input(fe.input, region, source, results)
        apply_specular_lighting(fe, region, cs, ts, input)
      }
    }
    if region != subregion {
      // Clip result.

      // TODO: explain
      let subregion2 = (if primitive.kind() is Offset(_) {
        // We do not support clipping on feOffset.
        region.translate_to(0, 0)
      } else {
        subregion.translate(-region.x(), -region.y())
      }).unwrap()
      let color_space = result.color_space
      let pixmap = {
        // This is cropping by clearing the pixels outside the region.
        let paint = @skia.Paint::default()
        paint.set_color(@skia.color_black)
        paint.blend_mode = Clear
        let pixmap = result.take()
        let w = i32_to_f32(pixmap.width())
        let h = i32_to_f32(pixmap.height())
        let id = @path.Transform::identity()
        if @path.Rect::from_xywh(0.0, 0.0, w, i32_to_f32(subregion2.y()))
          is Some(rect) {
          pixmap.fill_rect(rect, paint, id, None)
        }
        if @path.Rect::from_xywh(0.0, 0.0, i32_to_f32(subregion2.x()), h)
          is Some(rect) {
          pixmap.fill_rect(rect, paint, id, None)
        }
        if @path.Rect::from_xywh(i32_to_f32(subregion2.right()), 0.0, w, h)
          is Some(rect) {
          pixmap.fill_rect(rect, paint, id, None)
        }
        if @path.Rect::from_xywh(0.0, i32_to_f32(subregion2.bottom()), w, h)
          is Some(rect) {
          pixmap.fill_rect(rect, paint, id, None)
        }
        pixmap
      }
      result = { image: pixmap, region: subregion, color_space, }
    }
    results.push({ name: primitive.result(), image: result, })
  }
  match results.pop() {
    Some(res) => res.image
    None => raise NoResults
  }
}

///|
fn get_input(
  input : @usvg.FilterInput,
  region : @path.IntRect,
  source : @skia.Pixmap,
  results : Array[FilterResult],
) -> FImage {
  match input {
    SourceGraphic => {
      let image = source.clone()
      { image, region, color_space: SRGB, }
    }
    SourceAlpha => {
      let image = source.clone()
      // Set RGB to black. Keep alpha as is.
      let data = image.pixels()
      for i in 0..<data.length() {
        data[i] = data[i] & 0xFF000000U
      }
      { image, region, color_space: SRGB, }
    }
    Reference(name) =>
      match find_result(results, name) {
        Some(v) => v
        None =>
          // Technically unreachable.
          // Unknown filter primitive reference.
          get_input(SourceGraphic, region, source, results)
      }
  }
}

///|
fn apply_drop_shadow(
  fe : @usvg.FeDropShadow,
  cs : @usvg.ColorInterpolation,
  ts : @path.Transform,
  input : FImage,
) -> FImage raise FilterError {
  let (dx, dy) = scale_coordinates(fe.dx, fe.dy, ts)
  let pixmap = try_create(input.width(), input.height())
  let input_pixmap = input.into_color_space(cs).take()
  let shadow_pixmap = input_pixmap.clone()
  if resolve_std_dev(fe.std_dev_x.get(), fe.std_dev_y.get(), ts)
    is Some((std_dx, std_dy, use_box_blur)) {
    if use_box_blur {
      box_blur_apply(std_dx, std_dy, shadow_pixmap)
    } else {
      iir_blur_apply(std_dx, std_dy, shadow_pixmap)
    }
  }

  // flood
  let color = @skia.Color::from_rgba8(
    fe.color.red,
    fe.color.green,
    fe.color.blue,
    fe.opacity.to_u8(),
  )
  let pixels = shadow_pixmap.pixels()
  for i in 0..<pixels.length() {
    let color = color.apply_opacity(Float::from_int(px_a(pixels[i])) / 255.0)
    pixels[i] = color.premultiply().to_color_u8().0
  }
  match cs {
    SRGB => into_srgb(shadow_pixmap)
    LinearRGB => into_linear_rgb(shadow_pixmap)
  }
  pixmap.draw_pixmap(
    f32_to_i32(dx),
    f32_to_i32(dy),
    shadow_pixmap,
    @skia.PixmapPaint::default(),
    @path.Transform::identity(),
    None,
  )
  pixmap.draw_pixmap(
    0,
    0,
    input_pixmap,
    @skia.PixmapPaint::default(),
    @path.Transform::identity(),
    None,
  )
  FImage::from_image(pixmap, cs)
}

///|
fn apply_blur(
  fe : @usvg.FeGaussianBlur,
  cs : @usvg.ColorInterpolation,
  ts : @path.Transform,
  input : FImage,
) -> FImage {
  let (std_dx, std_dy, use_box_blur) = match
    resolve_std_dev(fe.std_dev_x.get(), fe.std_dev_y.get(), ts) {
    Some(v) => v
    None => return input
  }
  let pixmap = input.into_color_space(cs).take()
  if use_box_blur {
    box_blur_apply(std_dx, std_dy, pixmap)
  } else {
    iir_blur_apply(std_dx, std_dy, pixmap)
  }
  FImage::from_image(pixmap, cs)
}

///|
fn apply_offset(
  fe : @usvg.FeOffset,
  ts : @path.Transform,
  input : FImage,
) -> FImage raise FilterError {
  let (dx, dy) = scale_coordinates(fe.dx, fe.dy, ts)
  if @path.approx_eq_ulps(dx, 0.0, 4) && @path.approx_eq_ulps(dy, 0.0, 4) {
    return input
  }
  let pixmap = try_create(input.width(), input.height())
  pixmap.draw_pixmap(
    f32_to_i32(dx),
    f32_to_i32(dy),
    input.image,
    @skia.PixmapPaint::default(),
    @path.Transform::identity(),
    None,
  )
  FImage::from_image(pixmap, input.color_space)
}

///|
fn apply_blend(
  fe : @usvg.FeBlend,
  cs : @usvg.ColorInterpolation,
  region : @path.IntRect,
  input1 : FImage,
  input2 : FImage,
) -> FImage raise FilterError {
  let input1 = input1.into_color_space(cs)
  let input2 = input2.into_color_space(cs)
  let pixmap = try_create(region.width(), region.height())
  pixmap.draw_pixmap(
    0,
    0,
    input2.image,
    @skia.PixmapPaint::default(),
    @path.Transform::identity(),
    None,
  )
  pixmap.draw_pixmap(
    0,
    0,
    input1.image,
    { ..@skia.PixmapPaint::default(), blend_mode: convert_blend_mode(fe.mode), },
    @path.Transform::identity(),
    None,
  )
  FImage::from_image(pixmap, cs)
}

///|
fn apply_composite(
  fe : @usvg.FeComposite,
  cs : @usvg.ColorInterpolation,
  region : @path.IntRect,
  input1 : FImage,
  input2 : FImage,
) -> FImage raise FilterError {
  let input1 = input1.into_color_space(cs)
  let input2 = input2.into_color_space(cs)
  let pixmap = try_create(region.width(), region.height())
  if fe.operator is Arithmetic(k1~, k2~, k3~, k4~) {
    let pixmap1 = input1.take()
    let pixmap2 = input2.take()
    composite_arithmetic(k1, k2, k3, k4, pixmap1, pixmap2, pixmap)
    return FImage::from_image(pixmap, cs)
  }
  pixmap.draw_pixmap(
    0,
    0,
    input2.image,
    @skia.PixmapPaint::default(),
    @path.Transform::identity(),
    None,
  )
  let blend_mode : @skia.BlendMode = match fe.operator {
    Over => SourceOver
    In => SourceIn
    Out => SourceOut
    Atop => SourceAtop
    Xor => Xor
    Arithmetic(..) => SourceOver
  }
  pixmap.draw_pixmap(
    0,
    0,
    input1.image,
    { ..@skia.PixmapPaint::default(), blend_mode, },
    @path.Transform::identity(),
    None,
  )
  FImage::from_image(pixmap, cs)
}

///|
fn apply_merge(
  fe : @usvg.FeMerge,
  cs : @usvg.ColorInterpolation,
  region : @path.IntRect,
  source : @skia.Pixmap,
  results : Array[FilterResult],
) -> FImage raise FilterError {
  let pixmap = try_create(region.width(), region.height())
  for input in fe.inputs {
    let input = get_input(input, region, source, results)
    let input = input.into_color_space(cs)
    pixmap.draw_pixmap(
      0,
      0,
      input.image,
      @skia.PixmapPaint::default(),
      @path.Transform::identity(),
      None,
    )
  }
  FImage::from_image(pixmap, cs)
}

///|
fn apply_flood(
  fe : @usvg.FeFlood,
  region : @path.IntRect,
) -> FImage raise FilterError {
  let c = fe.color
  let pixmap = try_create(region.width(), region.height())
  pixmap.fill(
    @skia.Color::from_rgba8(c.red, c.green, c.blue, fe.opacity.to_u8()),
  )
  FImage::from_image(pixmap, SRGB)
}

///|
fn apply_tile(
  input : FImage,
  region : @path.IntRect,
) -> FImage raise FilterError {
  let subregion = input.region.translate(-region.x(), -region.y()).unwrap()
  let tile_pixmap = copy_region(input.image, subregion)
  let paint = @skia.Paint::default()
  paint.shader = @skia.Pattern::new(
    tile_pixmap,
    Repeat,
    Bicubic,
    1.0,
    @path.Transform::from_translate(
      i32_to_f32(subregion.x()),
      i32_to_f32(subregion.y()),
    ),
  )
  let pixmap = try_create(region.width(), region.height())
  let rect = @path.Rect::from_xywh(
    0.0,
    0.0,
    u32_to_f32(region.width()),
    u32_to_f32(region.height()),
  ).unwrap()
  pixmap.fill_rect(rect, paint, @path.Transform::identity(), None)
  FImage::from_image(pixmap, SRGB)
}

///|
fn apply_image(
  fe : @usvg.FeImage,
  region : @path.IntRect,
  subregion : @path.IntRect,
  ts : @path.Transform,
) -> FImage raise FilterError {
  let pixmap = try_create(region.width(), region.height())
  let (sx, sy) = ts.get_scale()
  let transform = @path.Transform::from_row(
    sx,
    0.0,
    0.0,
    sy,
    i32_to_f32(subregion.x()),
    i32_to_f32(subregion.y()),
  )
  let ctx = {
    max_bbox: @path.IntRect::from_xywh(0, 0, region.width(), region.height()).unwrap(),
  }
  render_nodes(fe.root(), ctx, transform, pixmap)
  FImage::from_image(pixmap, SRGB)
}

///|
fn apply_component_transfer(
  fe : @usvg.FeComponentTransfer,
  cs : @usvg.ColorInterpolation,
  input : FImage,
) -> FImage {
  let pixmap = input.into_color_space(cs).take()
  demultiply_alpha(pixmap.pixels())
  component_transfer_apply(fe, pixmap.pixels())
  multiply_alpha(pixmap.pixels())
  FImage::from_image(pixmap, cs)
}

///|
fn apply_color_matrix(
  fe : @usvg.FeColorMatrix,
  cs : @usvg.ColorInterpolation,
  input : FImage,
) -> FImage {
  let pixmap = input.into_color_space(cs).take()
  demultiply_alpha(pixmap.pixels())
  color_matrix_apply(fe.kind, pixmap.pixels())
  multiply_alpha(pixmap.pixels())
  FImage::from_image(pixmap, cs)
}

///|
fn apply_convolve_matrix(
  fe : @usvg.FeConvolveMatrix,
  cs : @usvg.ColorInterpolation,
  input : FImage,
) -> FImage {
  let pixmap = input.into_color_space(cs).take()
  if fe.preserve_alpha {
    demultiply_alpha(pixmap.pixels())
  }
  convolve_matrix_apply(fe, pixmap)
  FImage::from_image(pixmap, cs)
}

///|
fn apply_morphology(
  fe : @usvg.FeMorphology,
  cs : @usvg.ColorInterpolation,
  ts : @path.Transform,
  input : FImage,
) -> FImage {
  let pixmap = input.into_color_space(cs).take()
  let (rx, ry) = scale_coordinates(fe.radius_x.get(), fe.radius_y.get(), ts)
  if !(rx > 0.0 && ry > 0.0) {
    clear(pixmap)
    return FImage::from_image(pixmap, cs)
  }
  morphology_apply(fe.operator, rx, ry, pixmap)
  FImage::from_image(pixmap, cs)
}

///|
fn apply_displacement_map(
  fe : @usvg.FeDisplacementMap,
  region : @path.IntRect,
  cs : @usvg.ColorInterpolation,
  ts : @path.Transform,
  input1 : FImage,
  input2 : FImage,
) -> FImage raise FilterError {
  let pixmap1 = input1.into_color_space(cs).take()
  let pixmap2 = input2.into_color_space(cs).take()
  let pixmap = try_create(region.width(), region.height())
  let (sx, sy) = scale_coordinates(fe.scale, fe.scale, ts)
  displacement_map_apply(fe, sx, sy, pixmap1, pixmap2, pixmap)
  FImage::from_image(pixmap, cs)
}

///|
fn apply_turbulence(
  fe : @usvg.FeTurbulence,
  region : @path.IntRect,
  cs : @usvg.ColorInterpolation,
  ts : @path.Transform,
) -> FImage raise FilterError {
  let pixmap = try_create(region.width(), region.height())
  let (sx, sy) = ts.get_scale()
  if @path.approx_eq_ulps(sx, 0.0, 4) || @path.approx_eq_ulps(sy, 0.0, 4) {
    return FImage::from_image(pixmap, cs)
  }
  turbulence_apply(
    region.x().to_double() - ts.tx.to_double(),
    region.y().to_double() - ts.ty.to_double(),
    sx.to_double(),
    sy.to_double(),
    fe.base_frequency_x.get().to_double(),
    fe.base_frequency_y.get().to_double(),
    fe.num_octaves,
    fe.seed,
    fe.stitch_tiles,
    fe.kind == FractalNoise,
    pixmap,
  )
  multiply_alpha(pixmap.pixels())
  FImage::from_image(pixmap, cs)
}

///|
fn apply_diffuse_lighting(
  fe : @usvg.FeDiffuseLighting,
  region : @path.IntRect,
  cs : @usvg.ColorInterpolation,
  ts : @path.Transform,
  input : FImage,
) -> FImage raise FilterError {
  let pixmap = try_create(region.width(), region.height())
  let light_source = transform_light_source(fe.light_source, region, ts)
  diffuse_lighting(fe, light_source, input.image, pixmap)
  FImage::from_image(pixmap, cs)
}

///|
fn apply_specular_lighting(
  fe : @usvg.FeSpecularLighting,
  region : @path.IntRect,
  cs : @usvg.ColorInterpolation,
  ts : @path.Transform,
  input : FImage,
) -> FImage raise FilterError {
  let pixmap = try_create(region.width(), region.height())
  let light_source = transform_light_source(fe.light_source, region, ts)
  specular_lighting(fe, light_source, input.image, pixmap)
  FImage::from_image(pixmap, cs)
}

///|
// TODO: do not modify LightSource
fn transform_light_source(
  source : @usvg.LightSource,
  region : @path.IntRect,
  ts : @path.Transform,
) -> @usvg.LightSource {
  let sqrt_2 : Float = 1.41421356237309504880168872420969808
  match source {
    DistantLight(_) => source
    PointLight(light) => {
      let point = ts.map_point(@path.Point::from_xy(light.x, light.y))
      PointLight({
        x: point.x - i32_to_f32(region.x()),
        y: point.y - i32_to_f32(region.y()),
        z: light.z * (ts.sx * ts.sx + ts.sy * ts.sy).sqrt() / sqrt_2,
      })
    }
    SpotLight(light) => {
      let sz = (ts.sx * ts.sx + ts.sy * ts.sy).sqrt() / sqrt_2
      let point = ts.map_point(@path.Point::from_xy(light.x, light.y))
      let x = point.x - i32_to_f32(region.x())
      let y = point.y - i32_to_f32(region.x())
      let z = light.z * sz
      let point = ts.map_point(
        @path.Point::from_xy(light.points_at_x, light.points_at_y),
      )
      SpotLight({
        ..light,
        x,
        y,
        z,
        points_at_x: point.x - i32_to_f32(region.x()),
        points_at_y: point.y - i32_to_f32(region.x()),
        points_at_z: light.points_at_z * sz,
      })
    }
  }
}

///|
fn apply_to_canvas(input : FImage, pixmap : @skia.Pixmap) -> Unit {
  let input = input.into_color_space(SRGB)
  pixmap.fill(@skia.color_transparent)
  pixmap.draw_pixmap(
    0,
    0,
    input.image,
    @skia.PixmapPaint::default(),
    @path.Transform::identity(),
    None,
  )
}

///|
/// Calculates Gaussian blur sigmas for the current world transform.
///
/// If the last flag is set, then a box blur should be used. Or IIR otherwise.
fn resolve_std_dev(
  std_dx : Float,
  std_dy : Float,
  ts : @path.Transform,
) -> (Double, Double, Bool)? {
  let (std_dx, std_dy) = scale_coordinates(std_dx, std_dy, ts)
  let mut std_dx = std_dx
  let mut std_dy = std_dy

  // 'A negative value or a value of zero disables the effect of the given filter primitive
  // (i.e., the result is the filter input image).'
  if @path.approx_eq_ulps(std_dx, 0.0, 4) &&
    @path.approx_eq_ulps(std_dy, 0.0, 4) {
    return None
  }

  // Ignore tiny sigmas. In case of IIR blur it can lead to a transparent image.
  if std_dx < 0.05 {
    std_dx = 0.0
  }
  if std_dy < 0.05 {
    std_dy = 0.0
  }
  let blur_sigma_threshold : Float = 2.0
  // Check that the current feGaussianBlur filter can be applied using a box blur.
  let box_blur = std_dx >= blur_sigma_threshold ||
    std_dy >= blur_sigma_threshold
  Some((std_dx.to_double(), std_dy.to_double(), box_blur))
}

///|
fn scale_coordinates(
  x : Float,
  y : Float,
  ts : @path.Transform,
) -> (Float, Float) {
  let (sx, sy) = ts.get_scale()
  (x * sx, y * sy)
}
