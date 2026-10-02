// Port of `hayro-interpret/src/color.rs`: PDF colors and color spaces.

///|
/// A storage for the components of colors.
pub type ColorComponents = Array[Float]

///|
/// An RGB color with an alpha channel.
pub(all) struct AlphaColor {
  priv components : FixedArray[Float]
}

///|
/// A black color.
pub let alpha_color_black : AlphaColor = AlphaColor::new([0.0, 0.0, 0.0, 1.0])

///|
/// A transparent color.
pub let alpha_color_transparent : AlphaColor = AlphaColor::new([
  0.0, 0.0, 0.0, 0.0,
])

///|
/// A white color.
pub let alpha_color_white : AlphaColor = AlphaColor::new([1.0, 1.0, 1.0, 1.0])

///|
/// Create a new color from the given components.
pub fn AlphaColor::new(components : FixedArray[Float]) -> AlphaColor {
  { components: [components[0], components[1], components[2], components[3]], }
}

///|
/// Create a new color from RGB8 values.
pub fn AlphaColor::from_rgb8(r : Byte, g : Byte, b : Byte) -> AlphaColor {
  AlphaColor::new([u8_to_f32(r), u8_to_f32(g), u8_to_f32(b), 1.0])
}

///|
/// Return the color as premulitplied RGBF32.
pub fn AlphaColor::premultiplied(self : AlphaColor) -> FixedArray[Float] {
  let c = self.components
  [c[0] * c[3], c[1] * c[3], c[2] * c[3], c[3]]
}

///|
/// Create a new color from RGBA8 values.
pub fn AlphaColor::from_rgba8(
  r : Byte,
  g : Byte,
  b : Byte,
  a : Byte,
) -> AlphaColor {
  AlphaColor::new([u8_to_f32(r), u8_to_f32(g), u8_to_f32(b), u8_to_f32(a)])
}

///|
/// Return the color as RGBA8.
pub fn AlphaColor::to_rgba8(self : AlphaColor) -> FixedArray[Byte] {
  let c = self.components
  [
    f32_as_u8(c[0] * 255.0 + 0.5),
    f32_as_u8(c[1] * 255.0 + 0.5),
    f32_as_u8(c[2] * 255.0 + 0.5),
    f32_as_u8(c[3] * 255.0 + 0.5),
  ]
}

///|
/// Return the components of the color as RGBF32.
pub fn AlphaColor::components(self : AlphaColor) -> FixedArray[Float] {
  let c = self.components
  [c[0], c[1], c[2], c[3]]
}

///|
fn u8_to_f32(x : Byte) -> Float {
  x.to_float() * (1.0 / 255.0)
}

///|
priv enum ColorSpaceType {
  DeviceCmyk
  DeviceGray
  DeviceRgb
  Pattern(ColorSpace)
  Indexed(Indexed)
  ICCBased(ICCProfile)
  CalGray(CalGray)
  CalRgb(CalRgb)
  Lab(Lab)
  Separation(Separation)
  DeviceN(DeviceN)
}

///|
fn ColorSpaceType::new(
  object : @hayro_syntax.Object,
  cache : Cache,
) -> ColorSpaceType? {
  ColorSpaceType::new_inner(object, cache)
}

///|
fn ColorSpaceType::new_inner(
  object : @hayro_syntax.Object,
  cache : Cache,
) -> ColorSpaceType? {
  if object is Name(name) {
    return ColorSpaceType::new_from_name(name)
  } else if object is Array(color_array) {
    let iter = color_array.flex_iter()
    guard (iter.next() : @hayro_syntax.Name?) is Some(name) else { return None }
    match name.as_str() {
      "ICCBased" => {
        guard (iter.next() : @hayro_syntax.Stream?) is Some(icc_stream) else {
          return None
        }
        let dict = icc_stream.dict()
        guard (dict.get("N") : Int?) is Some(num_components) else {
          return None
        }
        return cache.get_or_insert_color_space_type(
          CacheKey::cache_key(icc_stream),
          () => {
            if icc_stream.decoded() is Ok(decoded) {
              match ICCProfile::new(decoded, num_components) {
                Some(icc) =>
                  // TODO: For SVG and PNG we can assume that the output color
                  // space is sRGB. If we ever implement PDF-to-PDF, we probably
                  // want to let the user pass the native color type and don't
                  // make this optimization if it's not sRGB.
                  if icc.is_srgb() {
                    Some(DeviceRgb)
                  } else {
                    Some(ICCBased(icc))
                  }
                None => {
                  let alt = match
                    (dict.get("Alternate") : @hayro_syntax.Object?) {
                    Some(o) => ColorSpaceType::new(o, cache)
                    None => None
                  }
                  match alt {
                    Some(_) => alt
                    None =>
                      match (dict.get("N") : Byte?) {
                        Some(b'\x01') => Some(DeviceGray)
                        Some(b'\x03') => Some(DeviceRgb)
                        Some(b'\x04') => Some(DeviceCmyk)
                        _ => None
                      }
                  }
                }
              }
            } else {
              None
            }
          },
        )
      }
      "CalCMYK" => return Some(DeviceCmyk)
      "CalGray" => {
        guard (iter.next() : @hayro_syntax.Dict?) is Some(cal_dict) else {
          return None
        }
        guard CalGray::new(cal_dict) is Some(c) else { return None }
        return Some(CalGray(c))
      }
      "CalRGB" => {
        guard (iter.next() : @hayro_syntax.Dict?) is Some(cal_dict) else {
          return None
        }
        guard CalRgb::new(cal_dict) is Some(c) else { return None }
        return Some(CalRgb(c))
      }
      "DeviceRGB" | "RGB" => return Some(DeviceRgb)
      "DeviceGray" | "G" => return Some(DeviceGray)
      "DeviceCMYK" | "CMYK" => return Some(DeviceCmyk)
      "Lab" => {
        guard (iter.next() : @hayro_syntax.Dict?) is Some(lab_dict) else {
          return None
        }
        guard Lab::new(lab_dict) is Some(l) else { return None }
        return Some(Lab(l))
      }
      "Indexed" | "I" => {
        guard Indexed::new(color_array, cache) is Some(i) else { return None }
        return Some(Indexed(i))
      }
      "Separation" => {
        guard Separation::new(color_array, cache) is Some(s) else {
          return None
        }
        return Some(Separation(s))
      }
      "DeviceN" => {
        guard DeviceN::new(color_array, cache) is Some(d) else { return None }
        return Some(DeviceN(d))
      }
      "Pattern" => {
        let _ : @hayro_syntax.Name? = iter.next()
        let cs = match (iter.next() : @hayro_syntax.Object?) {
          Some(o) => ColorSpace::new(o, cache)
          None => None
        }
        return Some(Pattern(cs.unwrap_or(ColorSpace::device_rgb())))
      }
      _ =>
        // warn!("unsupported color space: {}", name.as_str());
        return None
    }
  }
  None
}

///|
fn ColorSpaceType::new_from_name(name : @hayro_syntax.Name) -> ColorSpaceType? {
  match name.as_str() {
    "DeviceRGB" | "RGB" => Some(DeviceRgb)
    "DeviceGray" | "G" => Some(DeviceGray)
    "DeviceCMYK" | "CMYK" => Some(DeviceCmyk)
    "CalCMYK" => Some(DeviceCmyk)
    "Pattern" => Some(Pattern(ColorSpace::device_rgb()))
    _ => None
  }
}

///|
/// A PDF color space.
pub struct ColorSpace {
  priv inner : ColorSpaceType
}

///|
/// Create a new color space from the given object.
fn ColorSpace::new(object : @hayro_syntax.Object, cache : Cache) -> ColorSpace? {
  guard ColorSpaceType::new(object, cache) is Some(t) else { return None }
  Some({ inner: t, })
}

///|
/// Create a new color space from the name.
fn ColorSpace::new_from_name(name : @hayro_syntax.Name) -> ColorSpace? {
  match ColorSpaceType::new_from_name(name) {
    Some(c) => Some({ inner: c, })
    None => None
  }
}

///|
/// Return the device gray color space.
fn ColorSpace::device_gray() -> ColorSpace {
  { inner: DeviceGray, }
}

///|
/// Return the device RGB color space.
fn ColorSpace::device_rgb() -> ColorSpace {
  { inner: DeviceRgb, }
}

///|
/// Return the device CMYK color space.
fn ColorSpace::device_cmyk() -> ColorSpace {
  { inner: DeviceCmyk, }
}

///|
/// Return the pattern color space.
fn ColorSpace::pattern() -> ColorSpace {
  { inner: Pattern(ColorSpace::device_gray()), }
}

///|
fn ColorSpace::pattern_cs(self : ColorSpace) -> ColorSpace? {
  match self.inner {
    Pattern(cs) => Some(cs)
    _ => None
  }
}

///|
/// Return `true` if the current color space is the pattern color space.
fn ColorSpace::is_pattern(self : ColorSpace) -> Bool {
  self.inner is Pattern(_)
}

///|
/// Return `true` if the current color space is an indexed color space.
fn ColorSpace::is_indexed(self : ColorSpace) -> Bool {
  self.inner is Indexed(_)
}

///|
/// Get the default decode array for the color space.
fn ColorSpace::default_decode_arr(
  self : ColorSpace,
  n : Float,
) -> Array[(Float, Float)] {
  match self.inner {
    DeviceCmyk => [(0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (0.0, 1.0)]
    DeviceGray => [(0.0, 1.0)]
    DeviceRgb => [(0.0, 1.0), (0.0, 1.0), (0.0, 1.0)]
    ICCBased(i) => Array::make(i.number_components, (0.0, 1.0))
    CalGray(_) => [(0.0, 1.0)]
    CalRgb(_) => [(0.0, 1.0), (0.0, 1.0), (0.0, 1.0)]
    Lab(l) => [(0.0, 100.0), (l.range[0], l.range[1]), (l.range[2], l.range[3])]
    Indexed(_) => [(0.0, powf(2.0, n) - 1.0)]
    Separation(_) => [(0.0, 1.0)]
    DeviceN(d) => Array::make(d.num_components, (0.0, 1.0))
    // Not a valid image color space.
    Pattern(_) => [(0.0, 1.0)]
  }
}

///|
fn ColorSpace::inverted_default_decode_arr(
  self : ColorSpace,
  n : Float,
) -> Array[(Float, Float)] {
  self.default_decode_arr(n).map(p => (p.1, p.0))
}

///|
/// Get the initial color of the color space.
fn ColorSpace::initial_color(self : ColorSpace) -> ColorComponents {
  match self.inner {
    DeviceCmyk => [0.0, 0.0, 0.0, 1.0]
    DeviceGray => [0.0]
    DeviceRgb => [0.0, 0.0, 0.0]
    ICCBased(icc) =>
      match icc.number_components {
        1 => [0.0]
        3 => [0.0, 0.0, 0.0]
        4 => [0.0, 0.0, 0.0, 1.0]
        _ => abort("unreachable")
      }
    CalGray(_) => [0.0]
    CalRgb(_) => [0.0, 0.0, 0.0]
    Lab(_) => [0.0, 0.0, 0.0]
    Indexed(_) => [0.0]
    Separation(_) => [1.0]
    Pattern(c) => c.initial_color()
    DeviceN(d) => Array::make(d.num_components, 1.0)
  }
}

///|
fn ColorSpace::is_device_gray(self : ColorSpace) -> Bool {
  self.inner is DeviceGray
}

///|
fn ColorSpace::is_device_rgb(self : ColorSpace) -> Bool {
  self.inner is DeviceRgb
}

///|
/// Get the number of components of the color space.
fn ColorSpace::num_components(self : ColorSpace) -> Int {
  match self.inner {
    DeviceCmyk => 4
    DeviceGray => 1
    DeviceRgb => 3
    ICCBased(icc) => icc.number_components & 0xff
    CalGray(_) => 1
    CalRgb(_) => 3
    Lab(_) => 3
    Indexed(_) => 1
    Separation(_) => 1
    Pattern(p) => p.num_components()
    DeviceN(d) => d.num_components
  }
}

///|
/// Turn the given component values and opacity into an RGBA color.
pub fn ColorSpace::to_rgba(
  self : ColorSpace,
  c : ArrayView[Float],
  opacity : Float,
  manual_scale : Bool,
) -> AlphaColor {
  let alpha = f32_to_u8(opacity)
  let get = (i : Int) => if i < c.length() { f32_to_u8(c[i]) } else { b'\x00' }
  match self.inner {
    DeviceGray => {
      let gray = get(0)
      AlphaColor::from_rgba8(gray, gray, gray, alpha)
    }
    DeviceRgb => AlphaColor::from_rgba8(get(0), get(1), get(2), alpha)
    DeviceCmyk if c.length() == 4 => {
      let input = Bytes::from_array([
        f32_to_u8(c[0]),
        f32_to_u8(c[1]),
        f32_to_u8(c[2]),
        f32_to_u8(c[3]),
      ])
      let output = FixedArray::make(3, b'\x00')
      if cmyk_transform().convert_u8(input, output) is Some(_) {
        AlphaColor::from_rgba8(output[0], output[1], output[2], alpha)
      } else {
        alpha_color_black
      }
    }
    _ =>
      to_alpha_color(self, c, opacity, manual_scale).unwrap_or(
        alpha_color_black,
      )
  }
}

///|
impl ToRgb for ColorSpace with fn convert_f32(self, input, output, manual_scale) {
  match self.inner {
    DeviceCmyk =>
      if input.length() == 4 {
        let converted = Bytes::from_array([
          f32_to_u8(input[0]),
          f32_to_u8(input[1]),
          f32_to_u8(input[2]),
          f32_to_u8(input[3]),
        ])
        cmyk_transform().convert_u8(converted, output)
      } else {
        let converted = Bytes::from_iter(input.iter().map(f32_to_u8))
        cmyk_transform().convert_u8(converted, output)
      }
    DeviceGray => {
      let n = @cmp.minimum(input.length(), output.length() / 3)
      for i in 0..<n {
        let gray = f32_to_u8(input[i])
        output[i * 3] = gray
        output[i * 3 + 1] = gray
        output[i * 3 + 2] = gray
      }
      Some(())
    }
    DeviceRgb => {
      let n = @cmp.minimum(input.length(), output.length())
      for i in 0..<n {
        output[i] = f32_to_u8(input[i])
      }
      Some(())
    }
    Pattern(i) => i.convert_f32(input, output, manual_scale)
    Indexed(i) => i.convert_f32(input, output, manual_scale)
    ICCBased(i) => i.convert_f32(input, output, manual_scale)
    CalGray(i) => i.convert_f32(input, output, manual_scale)
    CalRgb(i) => i.convert_f32(input, output, manual_scale)
    Lab(i) => i.convert_f32(input, output, manual_scale)
    Separation(i) => i.convert_f32(input, output, manual_scale)
    DeviceN(i) => i.convert_f32(input, output, manual_scale)
  }
}

///|
impl ToRgb for ColorSpace with fn supports_u8(self) {
  match self.inner {
    DeviceCmyk => true
    DeviceGray => true
    DeviceRgb => true
    Pattern(i) => i.supports_u8()
    Indexed(i) => i.supports_u8()
    ICCBased(i) => i.supports_u8()
    CalGray(i) => i.supports_u8()
    CalRgb(i) => i.supports_u8()
    Lab(i) => i.supports_u8()
    Separation(i) => i.supports_u8()
    DeviceN(i) => i.supports_u8()
  }
}

///|
impl ToRgb for ColorSpace with fn convert_u8(self, input, output) {
  match self.inner {
    DeviceCmyk => cmyk_transform().convert_u8(input, output)
    DeviceGray => {
      let n = @cmp.minimum(input.length(), output.length() / 3)
      for i in 0..<n {
        output[i * 3] = input[i]
        output[i * 3 + 1] = input[i]
        output[i * 3 + 2] = input[i]
      }
      Some(())
    }
    DeviceRgb => {
      let n = @cmp.minimum(input.length(), output.length())
      for i in 0..<n {
        output[i] = input[i]
      }
      Some(())
    }
    Pattern(i) => i.convert_u8(input, output)
    Indexed(i) => i.convert_u8(input, output)
    ICCBased(i) => i.convert_u8(input, output)
    CalGray(i) => i.convert_u8(input, output)
    CalRgb(i) => i.convert_u8(input, output)
    Lab(i) => i.convert_u8(input, output)
    Separation(i) => i.convert_u8(input, output)
    DeviceN(i) => i.convert_u8(input, output)
  }
}

///|
impl ToRgb for ColorSpace with fn is_none(self) {
  match self.inner {
    Separation(s) => s.is_none()
    DeviceN(d) => d.is_none()
    _ => false
  }
}

///|
priv struct CalGray {
  white_point : FixedArray[Float]
  black_point : FixedArray[Float]
  gamma : Float
}

// See <https://github.com/mozilla/pdf.js/blob/06f44916c8936b92f464d337fe3a0a6b2b78d5b4/src/core/colorspace.js#L752>

///|
fn CalGray::new(dict : @hayro_syntax.Dict) -> CalGray? {
  let white_point = get_f32_array(dict, "WhitePoint", 3).unwrap_or([
    1.0, 1.0, 1.0,
  ])
  let black_point = get_f32_array(dict, "BlackPoint", 3).unwrap_or([
    0.0, 0.0, 0.0,
  ])
  let gamma = (dict.get("Gamma") : Float?).unwrap_or(1.0)
  Some({ white_point, black_point, gamma, })
}

///|
impl ToRgb for CalGray with fn convert_f32(self, input, output, _) {
  let n = @cmp.minimum(input.length(), output.length() / 3)
  for i in 0..<n {
    let g = self.gamma
    let yw = self.white_point[1]
    let a = input[i]
    let ag = powf(a, g)
    let l = yw * ag
    let val = f32_as_u8(
      f32_max(0.0, 295.8 * powf(l, 0.333_333_34) - 40.8) + 0.5,
    )
    output[i * 3] = val
    output[i * 3 + 1] = val
    output[i * 3 + 2] = val
  }
  Some(())
}

///|
priv struct CalRgb {
  white_point : FixedArray[Float]
  black_point : FixedArray[Float]
  matrix : FixedArray[Float]
  gamma : FixedArray[Float]
}

// See <https://github.com/mozilla/pdf.js/blob/06f44916c8936b92f464d337fe3a0a6b2b78d5b4/src/core/colorspace.js#L846>
// Completely copied from there without really understanding the logic, but we get the same results as Firefox
// which should be good enough (and by viewing the `calrgb.pdf` test file in different viewers you will
// see that in many cases each viewer does whatever it wants, even Acrobat), so this is good enough for us.

///|
fn CalRgb::new(dict : @hayro_syntax.Dict) -> CalRgb? {
  let white_point = get_f32_array(dict, "WhitePoint", 3).unwrap_or([
    1.0, 1.0, 1.0,
  ])
  let black_point = get_f32_array(dict, "BlackPoint", 3).unwrap_or([
    0.0, 0.0, 0.0,
  ])
  let matrix = get_f32_array(dict, "Matrix", 9).unwrap_or([
    1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
  ])
  let gamma = get_f32_array(dict, "Gamma", 3).unwrap_or([1.0, 1.0, 1.0])
  Some({ white_point, black_point, matrix, gamma, })
}

///|
let bradford_scale_matrix : FixedArray[Float] = [
  0.8951, 0.2664, -0.1614, -0.7502, 1.7135, 0.0367, 0.0389, -0.0685, 1.0296,
]

///|
let bradford_scale_inverse_matrix : FixedArray[Float] = [
  0.9869929, -0.1470543, 0.1599627, 0.4323053, 0.5183603, 0.0492912, -0.0085287,
  0.0400428, 0.9684867,
]

///|
let srgb_d65_xyz_to_rgb_matrix : FixedArray[Float] = [
  3.2404542, -1.5371385, -0.4985314, -0.969_266, 1.8760108, 0.0415560, 0.0556434,
  -0.2040259, 1.0572252,
]

///|
let flat_whitepoint : FixedArray[Float] = [1.0, 1.0, 1.0]

///|
let d65_whitepoint : FixedArray[Float] = [0.95047, 1.0, 1.08883]

///|
fn cal_rgb_decode_l_constant() -> Float {
  powi((8.0 + 16.0) / 116.0, 3) / 8.0
}

///|
fn cal_rgb_srgb_transfer_function(color : Float) -> Float {
  if color <= 0.0031308 {
    f32_clamp(12.92 * color, 0.0, 1.0)
  } else if color >= 0.99554525 {
    1.0
  } else {
    f32_clamp((1.0 + 0.055) * powf(color, 1.0 / 2.4) - 0.055, 0.0, 1.0)
  }
}

///|
fn cal_rgb_matrix_product(
  a : FixedArray[Float],
  b : FixedArray[Float],
) -> FixedArray[Float] {
  [
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
    a[3] * b[0] + a[4] * b[1] + a[5] * b[2],
    a[6] * b[0] + a[7] * b[1] + a[8] * b[2],
  ]
}

///|
fn cal_rgb_to_flat(
  source_white_point : FixedArray[Float],
  lms : FixedArray[Float],
) -> FixedArray[Float] {
  [
    lms[0] / source_white_point[0],
    lms[1] / source_white_point[1],
    lms[2] / source_white_point[2],
  ]
}

///|
fn cal_rgb_to_d65(
  source_white_point : FixedArray[Float],
  lms : FixedArray[Float],
) -> FixedArray[Float] {
  [
    lms[0] * d65_whitepoint[0] / source_white_point[0],
    lms[1] * d65_whitepoint[1] / source_white_point[1],
    lms[2] * d65_whitepoint[2] / source_white_point[2],
  ]
}

///|
fn cal_rgb_decode_l(l : Float) -> Float {
  if l < 0.0 {
    -cal_rgb_decode_l(-l)
  } else if l > 8.0 {
    powi((l + 16.0) / 116.0, 3)
  } else {
    l * cal_rgb_decode_l_constant()
  }
}

///|
fn cal_rgb_compensate_black_point(
  source_bp : FixedArray[Float],
  xyz_flat : FixedArray[Float],
) -> FixedArray[Float] {
  if source_bp[0] == 0.0 && source_bp[1] == 0.0 && source_bp[2] == 0.0 {
    return xyz_flat
  }
  let zero_decode_l = cal_rgb_decode_l(0.0)
  let out : FixedArray[Float] = [0.0, 0.0, 0.0]
  for i in 0..<3 {
    let src = cal_rgb_decode_l(source_bp[i])
    let one : Float = 1.0
    let scale = (one - zero_decode_l) / (one - src)
    let offset = one - scale
    out[i] = xyz_flat[i] * scale + offset
  }
  out
}

///|
fn CalRgb::normalize_white_point_to_flat(
  _self : CalRgb,
  source_white_point : FixedArray[Float],
  xyz : FixedArray[Float],
) -> FixedArray[Float] {
  if source_white_point[0] == 1.0 && source_white_point[2] == 1.0 {
    return xyz
  }
  let lms = cal_rgb_matrix_product(bradford_scale_matrix, xyz)
  let lms_flat = cal_rgb_to_flat(source_white_point, lms)
  cal_rgb_matrix_product(bradford_scale_inverse_matrix, lms_flat)
}

///|
fn CalRgb::normalize_white_point_to_d65(
  _self : CalRgb,
  source_white_point : FixedArray[Float],
  xyz : FixedArray[Float],
) -> FixedArray[Float] {
  let lms = cal_rgb_matrix_product(bradford_scale_matrix, xyz)
  let lms_d65 = cal_rgb_to_d65(source_white_point, lms)
  cal_rgb_matrix_product(bradford_scale_inverse_matrix, lms_d65)
}

///|
impl ToRgb for CalRgb with fn convert_f32(self, input, output, _) {
  let n = @cmp.minimum(input.length() / 3, output.length() / 3)
  for k in 0..<n {
    let r = f32_clamp(input[k * 3], 0.0, 1.0)
    let g = f32_clamp(input[k * 3 + 1], 0.0, 1.0)
    let b = f32_clamp(input[k * 3 + 2], 0.0, 1.0)
    let gr = self.gamma[0]
    let gg = self.gamma[1]
    let gb = self.gamma[2]
    let agr : Float = if r == 1.0 { 1.0 } else { powf(r, gr) }
    let bgg : Float = if g == 1.0 { 1.0 } else { powf(g, gg) }
    let cgb : Float = if b == 1.0 { 1.0 } else { powf(b, gb) }
    let m = self.matrix
    let x = m[0] * agr + m[3] * bgg + m[6] * cgb
    let y = m[1] * agr + m[4] * bgg + m[7] * cgb
    let z = m[2] * agr + m[5] * bgg + m[8] * cgb
    let xyz : FixedArray[Float] = [x, y, z]
    let xyz_flat = self.normalize_white_point_to_flat(self.white_point, xyz)
    let xyz_black = cal_rgb_compensate_black_point(self.black_point, xyz_flat)
    let xyz_d65 = self.normalize_white_point_to_d65(flat_whitepoint, xyz_black)
    let srgb_xyz = cal_rgb_matrix_product(srgb_d65_xyz_to_rgb_matrix, xyz_d65)
    output[k * 3] = f32_as_u8(
      cal_rgb_srgb_transfer_function(srgb_xyz[0]) * 255.0 + 0.5,
    )
    output[k * 3 + 1] = f32_as_u8(
      cal_rgb_srgb_transfer_function(srgb_xyz[1]) * 255.0 + 0.5,
    )
    output[k * 3 + 2] = f32_as_u8(
      cal_rgb_srgb_transfer_function(srgb_xyz[2]) * 255.0 + 0.5,
    )
  }
  Some(())
}

///|
priv struct Lab {
  range : FixedArray[Float]
  profile : ICCProfile
}

///|
fn Lab::new(dict : @hayro_syntax.Dict) -> Lab? {
  let white_point = get_f32_array(dict, "WhitePoint", 3).unwrap_or([
    1.0, 1.0, 1.0,
  ])
  // Not sure how this should be used.
  let _black_point = get_f32_array(dict, "BlackPoint", 3).unwrap_or([
    0.0, 0.0, 0.0,
  ])
  let range = get_f32_array(dict, "Range", 4).unwrap_or([
    -100.0, 100.0, -100.0, 100.0,
  ])
  let profile = @moxcms.ColorProfile::new_from_slice(lab_icc()[:]) catch {
    _ => return None
  }
  profile.set_white_point(
    @moxcms.Xyzd::new(
      white_point[0].to_double(),
      white_point[1].to_double(),
      white_point[2].to_double(),
    ),
  )
  guard ICCProfile::new_from_src_profile(
      profile, false,
      // This flag is only used to scale the values to [0.0, 1.0], but
      // we already take care of this in the `convert_f32` method.
      // Therefore, leave this as false, even though this is a LAB profile.
       false, 3,
    )
    is Some(profile) else {
    return None
  }
  Some({ range, profile, })
}

///|
impl ToRgb for Lab with fn convert_f32(self, input, output, manual_scale) {
  if !manual_scale {
    // moxcms expects values between 0.0 and 1.0, so we need to undo
    // the scaling.
    let scaled = []
    for k in 0..<(input.length() / 3) {
      let l = input[k * 3] / 100.0
      let a = (input[k * 3 + 1] + 128.0) / 255.0
      let b = (input[k * 3 + 2] + 128.0) / 255.0
      scaled.push(l)
      scaled.push(a)
      scaled.push(b)
    }
    self.profile.convert_f32(scaled[:], output, manual_scale)
  } else {
    self.profile.convert_f32(input, output, manual_scale)
  }
}

///|
priv struct Indexed {
  values : Array[Array[Float]]
  hival : Int
  base : ColorSpace
}

///|
fn Indexed::new(array : @hayro_syntax.PdfArray, cache : Cache) -> Indexed? {
  let iter = array.flex_iter()
  // Skip name
  guard (iter.next() : @hayro_syntax.Name?) is Some(_) else { return None }
  guard (iter.next() : @hayro_syntax.Object?) is Some(base_obj) else {
    return None
  }
  guard ColorSpace::new(base_obj, cache) is Some(base_color_space) else {
    return None
  }
  guard (iter.next() : UInt?) is Some(hival) else { return None }
  let hival = if hival > 255 { 255 } else { hival.reinterpret_as_int() }
  let data : BytesView = match (iter.next() : @hayro_syntax.Stream?) {
    Some(s) =>
      match s.decoded() {
        Ok(d) => d
        Err(_) =>
          match (iter.next() : @hayro_syntax.PdfString?) {
            Some(s) => s.as_bytes()[:]
            None => return None
          }
      }
    None =>
      match (iter.next() : @hayro_syntax.PdfString?) {
        Some(s) => s.as_bytes()[:]
        None => return None
      }
  }
  let num_components = base_color_space.num_components()
  let mut pos = 0
  let vals = []
  for _ in 0..<=hival {
    let temp = []
    for _ in 0..<num_components {
      guard pos < data.length() else { return None }
      temp.push(data[pos].to_float() / 255.0)
      pos += 1
    }
    vals.push(temp)
  }
  Some({ values: vals, hival, base: base_color_space, })
}

///|
impl ToRgb for Indexed with fn convert_f32(self, input, output, _) {
  let nc = self.base.num_components()
  let indexed = FixedArray::make(input.length() * nc, (0.0 : Float))
  for i in 0..<input.length() {
    let idx = f32_as_u32(f32_clamp(input[i], 0.0, self.hival.to_float()) + 0.5)
    let v = self.values[idx]
    for j in 0..<nc {
      indexed[i * nc + j] = v[j]
    }
  }
  self.base.convert_f32(Array::from_fixed_array(indexed)[:], output, true)
}

///|
priv struct Separation {
  alternate_space : ColorSpace
  tint_transform : @function.Function
  is_none_separation : Bool
}

///|
fn Separation::new(
  array : @hayro_syntax.PdfArray,
  cache : Cache,
) -> Separation? {
  let iter = array.flex_iter()
  // Skip `/Separation`
  guard (iter.next() : @hayro_syntax.Name?) is Some(_) else { return None }
  guard (iter.next() : @hayro_syntax.Name?) is Some(name) else { return None }
  guard (iter.next() : @hayro_syntax.Object?) is Some(alt) else { return None }
  guard ColorSpace::new(alt, cache) is Some(alternate_space) else {
    return None
  }
  guard (iter.next() : @hayro_syntax.Object?) is Some(f) else { return None }
  guard @function.Function::new(f) is Some(tint_transform) else { return None }
  // Either I did something wrong, or no other viewers properly handles
  // `All`, so let's just ignore it as well.
  let is_none_separation = name.as_str() == "None"
  Some({ alternate_space, tint_transform, is_none_separation, })
}

///|
impl ToRgb for Separation with fn convert_f32(self, input, output, _) {
  let evaluated = []
  for n in input {
    let out = self.tint_transform
      .eval([n])
      .unwrap_or(self.alternate_space.initial_color())
    for v in out {
      evaluated.push(v)
    }
  }
  self.alternate_space.convert_f32(evaluated[:], output, false)
}

///|
impl ToRgb for Separation with fn is_none(self) {
  self.is_none_separation
}

///|
priv struct DeviceN {
  alternate_space : ColorSpace
  num_components : Int
  tint_transform : @function.Function
  is_none : Bool
}

///|
fn DeviceN::new(array : @hayro_syntax.PdfArray, cache : Cache) -> DeviceN? {
  let iter = array.flex_iter()
  // Skip `/DeviceN`
  guard (iter.next() : @hayro_syntax.Name?) is Some(_) else { return None }
  // Skip `Name`.
  guard (iter.next() : @hayro_syntax.PdfArray?) is Some(names_arr) else {
    return None
  }
  let names : Array[@hayro_syntax.Name] = names_arr.iter().collect()
  guard names.length() <= 255 else { return None }
  let num_components = names.length()
  let all_none = names.iter().all(n => n.as_str() == "None")
  guard (iter.next() : @hayro_syntax.Object?) is Some(alt) else { return None }
  guard ColorSpace::new(alt, cache) is Some(alternate_space) else {
    return None
  }
  guard (iter.next() : @hayro_syntax.Object?) is Some(f) else { return None }
  guard @function.Function::new(f) is Some(tint_transform) else { return None }
  if num_components == 0 {
    return None
  }
  Some({ alternate_space, num_components, tint_transform, is_none: all_none, })
}

///|
impl ToRgb for DeviceN with fn convert_f32(self, input, output, _) {
  let evaluated = []
  let n = self.num_components
  for k in 0..<(input.length() / n) {
    let chunk = input[k * n:(k + 1) * n].to_array()
    let out = self.tint_transform
      .eval(chunk)
      .unwrap_or(self.alternate_space.initial_color())
    for v in out {
      evaluated.push(v)
    }
  }
  self.alternate_space.convert_f32(evaluated[:], output, false)
}

///|
impl ToRgb for DeviceN with fn is_none(self) {
  self.is_none
}

///|
priv struct ICCProfile {
  src_profile : @moxcms.ColorProfile
  src_layout : @moxcms.Layout
  number_components : Int
  is_srgb : Bool
  is_lab : Bool
  transform_u8 : @moxcms.Transform8BitExecutor
  mut transform_f32 : @moxcms.TransformF32Executor?
}

///|
fn ICCProfile::new(profile : BytesView, number_components : Int) -> ICCProfile? {
  let src_profile = @moxcms.ColorProfile::new_from_slice(profile) catch {
    _ => return None
  }
  let is_srgb = profile.length() >= 56 &&
    profile[52] == b's' &&
    profile[53] == b'R' &&
    profile[54] == b'G' &&
    profile[55] == b'B'
  let is_lab = src_profile.color_space == Lab
  ICCProfile::new_from_src_profile(
    src_profile, is_srgb, is_lab, number_components,
  )
}

///|
fn ICCProfile::new_from_src_profile(
  src_profile : @moxcms.ColorProfile,
  is_srgb : Bool,
  is_lab : Bool,
  number_components : Int,
) -> ICCProfile? {
  let src_layout : @moxcms.Layout = match number_components {
    1 => Gray
    3 => Rgb
    4 => Rgba
    _ =>
      // warn!("unsupported number of components {number_components} for ICC profile");
      return None
  }
  let dest_profile = @moxcms.ColorProfile::new_srgb()
  let transform_u8 = src_profile
    .clone()
    .create_transform_8bit(
      src_layout,
      dest_profile,
      Rgb,
      @moxcms.TransformOptions::default(),
    ) catch {
      _ => return None
    }
  Some({
    src_profile,
    src_layout,
    number_components,
    is_srgb,
    is_lab,
    transform_u8,
    transform_f32: None,
  })
}

///|
fn ICCProfile::is_srgb(self : ICCProfile) -> Bool {
  self.is_srgb
}

///|
fn ICCProfile::transform_f32(self : ICCProfile) -> @moxcms.TransformF32Executor {
  // From my benchmarking, creating the f32 transforms is usually much
  // more expensive than u8. Therefore, we only create it lazily when
  // really needed.
  match self.transform_f32 {
    Some(t) => t
    None => {
      let dest_profile = @moxcms.ColorProfile::new_srgb()
      let t = self.src_profile
        .clone()
        .create_transform_f32(
          self.src_layout,
          dest_profile,
          Rgb,
          @moxcms.TransformOptions::default(),
        ) catch {
          // Since the u8 version was valid, hopefully this should never panic?
          _ => abort("failed to create f32 transform")
        }
      self.transform_f32 = Some(t)
      t
    }
  }
}

///|
impl ToRgb for ICCProfile with fn convert_f32(self, input, output, _) {
  let temp = FixedArray::make(output.length(), (0.0 : Float))
  if self.is_lab {
    // moxcms expects normalized values.
    let scaled = []
    for k in 0..<(input.length() / 3) {
      scaled.push(input[k * 3] * (1.0 / 100.0))
      scaled.push((input[k * 3 + 1] + 128.0) * (1.0 / 255.0))
      scaled.push((input[k * 3 + 2] + 128.0) * (1.0 / 255.0))
    }
    self.transform_f32().transform(scaled[:], temp) catch {
      _ => return None
    }
  } else {
    self.transform_f32().transform(input, temp) catch {
      _ => return None
    }
  }
  for i in 0..<temp.length() {
    output[i] = f32_as_u8(temp[i] * 255.0 + 0.5)
  }
  Some(())
}

///|
impl ToRgb for ICCProfile with fn supports_u8(_self) {
  true
}

///|
impl ToRgb for ICCProfile with fn convert_u8(self, input, output) {
  if self.is_srgb {
    for i in 0..<input.length() {
      output[i] = input[i]
    }
  } else {
    self.transform_u8.transform(input, output) catch {
      _ => return None
    }
  }
  Some(())
}

///|
fn f32_to_u8(val : Float) -> Byte {
  f32_as_u8(val * 255.0 + 0.5)
}

///|
/// A color.
pub struct Color {
  priv color_space : ColorSpace
  priv components : ColorComponents
  priv opacity : Float
}

///|
fn Color::new(
  color_space : ColorSpace,
  components : ColorComponents,
  opacity : Float,
) -> Color {
  { color_space, components, opacity, }
}

///|
/// Return the color as an RGBA color.
pub fn Color::to_rgba(self : Color) -> AlphaColor {
  self.color_space.to_rgba(self.components[:], self.opacity, false)
}

///|
/// Create a color from RGBA.
pub fn Color::from_rgba(rgba : AlphaColor) -> Color {
  let c = rgba.components()
  {
    color_space: ColorSpace::device_rgb(),
    components: [c[0], c[1], c[2]],
    opacity: c[3],
  }
}

///|
let cmyk_transform_cell : Ref[ICCProfile?] = Ref::new(None)

///|
fn cmyk_transform() -> ICCProfile {
  match cmyk_transform_cell.val {
    Some(t) => t
    None => {
      let t = match ICCProfile::new(cgats001_compat_v2_micro_icc()[:], 4) {
        Some(t) => t
        None => abort("failed to load the CMYK profile")
      }
      cmyk_transform_cell.val = Some(t)
      t
    }
  }
}

///|
priv trait ToRgb {
  fn convert_f32(Self, ArrayView[Float], FixedArray[Byte], Bool) -> Unit?
  fn supports_u8(Self) -> Bool = _
  fn convert_u8(Self, BytesView, FixedArray[Byte]) -> Unit? = _
  fn is_none(Self) -> Bool = _
}

///|
impl ToRgb with fn supports_u8(_self) {
  false
}

///|
impl ToRgb with fn convert_u8(_self, _input, _output) {
  abort("not implemented")
}

///|
impl ToRgb with fn is_none(_self) {
  false
}

///|
fn[T : ToRgb] convert_sample(
  cs : T,
  input : ArrayView[Float],
  output : FixedArray[Byte],
  manual_scale : Bool,
) -> Unit? {
  // We prefer using the u8 variant for single samples, which is especially
  // important for ICC profiles to avoid constructing the (more expensive)
  // f32 variant.
  if cs.supports_u8() {
    let converted = Bytes::from_iter(input.iter().map(f32_to_u8))
    if cs.convert_u8(converted, output) is Some(_) {
      return Some(())
    }
  }
  cs.convert_f32(input, output, manual_scale)
}

///|
fn[T : ToRgb] to_alpha_color(
  cs : T,
  input : ArrayView[Float],
  opacity : Float,
  manual_scale : Bool,
) -> AlphaColor? {
  let mut opacity = opacity
  let output = FixedArray::make(3, b'\x00')
  guard convert_sample(cs, input, output, manual_scale) is Some(_) else {
    return None
  }
  // For separation color spaces:
  // "The special colourant name None shall not produce any visible output.
  // Painting operations in a Separation space with this colourant name
  // shall have no effect on the current page."
  if cs.is_none() {
    opacity = 0.0
  }
  Some(
    AlphaColor::from_rgba8(
      output[0],
      output[1],
      output[2],
      f32_as_u8(opacity * 255.0 + 0.5),
    ),
  )
}

///|
/// Read an array of exactly `n` floats (upstream `dict.get::<[f32; N]>`).
fn get_f32_array(
  dict : @hayro_syntax.Dict,
  key : String,
  n : Int,
) -> FixedArray[Float]? {
  guard (dict.get_fixed(key, n) : Array[Float]?) is Some(a) else { return None }
  Some(FixedArray::from_array(a))
}

///|
let lab_icc_cell : Ref[Bytes?] = Ref::new(None)

///|
fn lab_icc() -> Bytes {
  match lab_icc_cell.val {
    Some(b) => b
    None => {
      let b = decode_base64(lab_icc_base64)
      lab_icc_cell.val = Some(b)
      b
    }
  }
}

///|
let cgats_icc_cell : Ref[Bytes?] = Ref::new(None)

///|
fn cgats001_compat_v2_micro_icc() -> Bytes {
  match cgats_icc_cell.val {
    Some(b) => b
    None => {
      let b = decode_base64(cgats001_compat_v2_micro_icc_base64)
      cgats_icc_cell.val = Some(b)
      b
    }
  }
}

///|
fn decode_base64(s : String) -> Bytes {
  let clean = StringBuilder::new()
  for c in s {
    if c != '\n' {
      clean.write_char(c)
    }
  }
  @base64.decode(clean.to_string()) catch {
    _ => abort("invalid embedded asset")
  }
}
