// A port of the resampling of the `image` crate (v0.25.10,
// `imageops/sample.rs`) as used by `DynamicImage::resize_exact`, and of the
// `Rgba<u8>` pixel view of a `DynamicImage` (`GenericImageView::pixels`).
//
// Images are passed as raw sample buffers in the layout of the given
// `ColorType`: row-major, interleaved channels, one byte per sample for the
// 8-bit types and one little-endian `u16` per sample for the 16-bit types.
//
// All arithmetic is `f32` (`Float`) exactly as upstream, so that the results
// are bit-identical.

///|
/// Available Sampling Filters.
pub(all) enum FilterType {
  /// Nearest Neighbor
  Nearest
  /// Linear Filter
  Triangle
  /// Cubic Filter
  CatmullRom
  /// Gaussian Filter
  Gaussian
  /// Lanczos with window 3
  Lanczos3
} derive(Eq, Hash, Debug)

///|
/// A Representation of a separable filter.
priv struct Filter {
  /// The filter's filter function.
  kernel : (Float) -> Float
  /// The window on which this filter operates.
  support : Float
}

///|
/// `f32::consts::PI`.
let f32_pi : Float = Float::reinterpret_from_uint(0x40490fdb)

///|
// sinc function: the ideal sampling filter.
fn sinc(t : Float) -> Float {
  let a = t * f32_pi
  if t == 0.0 {
    1.0
  } else {
    libm_sinf(a) / a
  }
}

///|
// lanczos kernel function. A windowed sinc function.
fn lanczos(x : Float, t : Float) -> Float {
  if x.abs() < t {
    sinc(x) * sinc(x / t)
  } else {
    0.0
  }
}

///|
/// Rust's `f32::powi` for the small positive exponents used here (LLVM
/// expands it into the same multiplication tree as compiler-rt's
/// `__powisf2`).
fn powi(x : Float, n : Int) -> Float {
  let mut r : Float = 1.0
  let mut a = x
  let mut b = n
  while true {
    if (b & 1) != 0 {
      r = r * a
    }
    b = b / 2
    if b == 0 {
      break
    }
    a = a * a
  }
  r
}

///|
// Calculate a splice based on the b and c parameters.
// from authors Mitchell and Netravali.
fn bc_cubic_spline(x : Float, b : Float, c : Float) -> Float {
  let a = x.abs()
  let k : Float = if a < 1.0 {
    ((12.0 : Float) - (9.0 : Float) * b - (6.0 : Float) * c) * powi(a, 3) +
    ((-18.0 : Float) + (12.0 : Float) * b + (6.0 : Float) * c) * powi(a, 2) +
    ((6.0 : Float) - (2.0 : Float) * b)
  } else if a < 2.0 {
    (-b - (6.0 : Float) * c) * powi(a, 3) +
    ((6.0 : Float) * b + (30.0 : Float) * c) * powi(a, 2) +
    ((-12.0 : Float) * b - (48.0 : Float) * c) * a +
    ((8.0 : Float) * b + (24.0 : Float) * c)
  } else {
    0.0
  }
  k / 6.0
}

///|
/// The Gaussian Function.
/// `r` is the standard deviation.
fn gaussian(x : Float, r : Float) -> Float {
  (1.0 : Float) /
  (((2.0 : Float) * f32_pi).sqrt() * r) *
  libm_expf(-powi(x, 2) / ((2.0 : Float) * powi(r, 2)))
}

///|
/// Calculate the lanczos kernel with a window of 3
fn lanczos3_kernel(x : Float) -> Float {
  lanczos(x, 3.0)
}

///|
/// Calculate the gaussian function with a
/// standard deviation of 0.5
fn gaussian_kernel(x : Float) -> Float {
  gaussian(x, 0.5)
}

///|
/// Calculate the Catmull-Rom cubic spline.
/// Also known as a form of `BiCubic` sampling in two dimensions.
fn catmullrom_kernel(x : Float) -> Float {
  bc_cubic_spline(x, 0.0, 0.5)
}

///|
/// Calculate the triangle function.
/// Also known as `BiLinear` sampling in two dimensions.
fn triangle_kernel(x : Float) -> Float {
  if x.abs() < 1.0 {
    (1.0 : Float) - x.abs()
  } else {
    0.0
  }
}

///|
/// Calculate the box kernel.
/// Only pixels inside the box should be considered, and those
/// contribute equally.  So this method simply returns 1.
fn box_kernel(_x : Float) -> Float {
  1.0
}

///|
/// A raw sample buffer converted to `f32` samples (exact for `u8`/`u16`).
fn samples_to_f32(
  color : ColorType,
  buf : Bytes,
  len : Int,
) -> FixedArray[Float] {
  let buf = buf[:]
  let out = FixedArray::make(len, (0.0 : Float))
  if is_wide(color) {
    for i in 0..<len {
      out[i] = Float::from_int(u16_le(buf, 2 * i))
    }
  } else {
    for i in 0..<len {
      out[i] = Float::from_int(buf[i].to_int())
    }
  }
  out
}

///|
fn is_wide(color : ColorType) -> Bool {
  match color {
    L16 | La16 | Rgb16 | Rgba16 => true
    _ => false
  }
}

///|
/// The number of bytes per sample.
fn sample_size(color : ColorType) -> Int {
  if is_wide(color) {
    2
  } else {
    1
  }
}

///|
/// Clamp an `i64` slice bound (upstream `utils::clamp`).
fn clamp_i(a : Int64, min : Int64, max : Int64) -> Int64 {
  if a < min {
    min
  } else if a > max {
    max
  } else {
    a
  }
}

///|
/// Rust's saturating `f32 as i64` cast.
fn f32_to_i64(v : Float) -> Int64 {
  v.to_double().to_int64()
}

///|
/// Compute the normalized filter weights for one output position (shared by
/// `vertical_sample` and `horizontal_sample`). Returns `left` and the weights
/// of the input positions `left..right`.
fn sample_weights(
  outx : UInt,
  size : UInt,
  ratio : Float,
  sratio : Float,
  src_support : Float,
  filter : Filter,
  ws : Array[Float],
) -> Int {
  // Find the point in the input image corresponding to the centre
  // of the current pixel in the output image.
  let inputx = (Float::from_uint(outx) + 0.5) * ratio

  // Left and right are slice bounds for the input pixels relevant
  // to the output pixel we are calculating.  Pixel x is relevant
  // if and only if (x >= left) && (x < right).

  // Invariant: 0 <= left < right <= width
  let left = f32_to_i64((inputx - src_support).floor())
  let left = clamp_i(left, 0, size.to_int64() - 1)
  let right = f32_to_i64((inputx + src_support).ceil())
  let right = clamp_i(right, left + 1, size.to_int64())
  let left = left.to_int()
  let right = right.to_int()

  // Go back to left boundary of pixel, to properly compare with i
  // below, as the kernel treats the centre of a pixel as 0.
  let inputx = inputx - 0.5
  ws.clear()
  let mut sum : Float = 0.0
  for i in left..<right {
    let w = (filter.kernel)(
      (Float::from_uint(i.reinterpret_as_uint()) - inputx) / sratio,
    )
    ws.push(w)
    sum = sum + w
  }
  for k in 0..<ws.length() {
    ws[k] = ws[k] / sum
  }
  left
}

///|
// Sample the columns of the supplied image using the provided filter.
// The width of the image remains unchanged.
// `new_height` is the desired height of the new image
// `filter` is the filter to use for sampling.
// The return value keeps the channels of the image (upstream stores them in
// an `Rgba32FImage`, padding absent channels, which are discarded later).
fn vertical_sample(
  image : FixedArray[Float],
  width : UInt,
  height : UInt,
  channels : Int,
  new_height : UInt,
  filter : Filter,
) -> FixedArray[Float] {
  let w = width.reinterpret_as_int()
  let nh = new_height.reinterpret_as_int()
  let out = FixedArray::make(w * nh * channels, (0.0 : Float))
  let ws = []
  let ratio = Float::from_uint(height) / Float::from_uint(new_height)
  let sratio : Float = if ratio < 1.0 { 1.0 } else { ratio }
  let src_support = filter.support * sratio
  for outy in 0..<nh {
    // For an explanation of this algorithm, see the comments
    // in horizontal_sample.
    let left = sample_weights(
      outy.reinterpret_as_uint(),
      height,
      ratio,
      sratio,
      src_support,
      filter,
      ws,
    )
    // Every sample of the row is `sum(image[left + i][j] * ws[i])`, summed
    // from 0.0 in the order of `i` (upstream's `t`, per pixel and channel).
    vertical_sample_row(image, out, w * channels, outy * w * channels, left, ws)
  }
  out
}

///|
// Sample the rows of the supplied image using the provided filter.
// The height of the image remains unchanged.
// `new_width` is the desired width of the new image
// `filter` is the filter to use for sampling.
fn horizontal_sample(
  image : FixedArray[Float],
  width : UInt,
  height : UInt,
  channels : Int,
  new_width : UInt,
  filter : Filter,
  color : ColorType,
) -> Bytes {
  let w = width.reinterpret_as_int()
  let h = height.reinterpret_as_int()
  let nw = new_width.reinterpret_as_int()
  let size = sample_size(color)
  let out = FixedArray::make(nw * h * channels * size, (0 : Byte))
  let ws = []
  let max : Float = if size == 2 { 65535.0 } else { 255.0 }
  let min : Float = 0.0
  let ratio = Float::from_uint(width) / Float::from_uint(new_width)
  let sratio : Float = if ratio < 1.0 { 1.0 } else { ratio }
  let src_support = filter.support * sratio
  let t = FixedArray::make(channels, (0.0 : Float))
  for outx in 0..<nw {
    let left = sample_weights(
      outx.reinterpret_as_uint(),
      width,
      ratio,
      sratio,
      src_support,
      filter,
      ws,
    )
    for y in 0..<h {
      t.fill(0.0)
      for i, wt in ws {
        let base = (y * w + left + i) * channels
        for c in 0..<channels {
          t[c] = t[c] + image[base + c] * wt
        }
      }
      let base = (y * nw + outx) * channels
      for c in 0..<channels {
        // `NumCast::from(FloatNearest(clamp(t, min, max)))`
        let v = round_half_away(clamp_f(t[c], min, max)).to_int()
        if size == 2 {
          out[2 * (base + c)] = v.to_byte()
          out[2 * (base + c) + 1] = (v >> 8).to_byte()
        } else {
          out[base + c] = v.to_byte()
        }
      }
    }
  }
  Bytes::from_array(out[:])
}

///|
/// Upstream `utils::clamp` on `f32`.
fn clamp_f(a : Float, min : Float, max : Float) -> Float {
  if a < min {
    min
  } else if a > max {
    max
  } else {
    a
  }
}

///|
/// Rust's `f32::round` (half away from zero).
fn round_half_away(x : Float) -> Float {
  let t = x.trunc()
  if (x - t).abs() >= 0.5 {
    t + (if x < 0.0 { -1.0 } else { 1.0 })
  } else {
    t
  }
}

///|
/// Resize the supplied image to the specified dimensions (upstream
/// `imageops::resize`, which `DynamicImage::resize_exact` maps over all color
/// types).
///
/// `buf` holds the samples of a `width` x `height` image of the given color
/// type; the result holds the samples of the `nwidth` x `nheight` image in
/// the same color type.
///
/// This method assumes alpha pre-multiplication for images that contain
/// non-constant alpha (i.e. it does not premultiply itself).
pub fn resize_exact(
  width : UInt,
  height : UInt,
  color : ColorType,
  buf : Bytes,
  nwidth : UInt,
  nheight : UInt,
  filter : FilterType,
) -> Bytes {
  let channels = color.channel_count()
  let size = sample_size(color)

  // Check if there is nothing to sample from.
  if width == 0 || height == 0 {
    return Bytes::make(
      (nwidth * nheight).reinterpret_as_int() * channels * size,
      0,
    )
  }

  // check if the new dimensions are the same as the old. if they are, make a
  // copy instead of resampling
  if nwidth == width && nheight == height {
    let len = (width * height).reinterpret_as_int() * channels * size
    return Bytes::makei(len, i => buf[i])
  }
  let filt : Filter = match filter {
    Nearest => { kernel: box_kernel, support: 0.0, }
    Triangle => { kernel: triangle_kernel, support: 1.0, }
    CatmullRom => { kernel: catmullrom_kernel, support: 2.0, }
    Gaussian => { kernel: gaussian_kernel, support: 3.0, }
    Lanczos3 => { kernel: lanczos3_kernel, support: 3.0, }
  }
  let image = samples_to_f32(
    color,
    buf,
    (width * height).reinterpret_as_int() * channels,
  )
  let tmp = vertical_sample(image, width, height, channels, nheight, filt)
  horizontal_sample(tmp, width, nheight, channels, nwidth, filt, color)
}

///|
/// Convert an image to RGBA8 pixels, as upstream's
/// `GenericImageView::pixels` of a `DynamicImage` yields them
/// (`p.get_pixel(x, y).to_rgba().into_color()`): luma is replicated, absent
/// alpha is opaque and 16-bit samples map to 8 bits by `(c + 128) / 257`.
pub fn to_rgba8(
  width : UInt,
  height : UInt,
  color : ColorType,
  buf : Bytes,
) -> Bytes {
  let n = (width * height).reinterpret_as_int()
  let out = FixedArray::make(n * 4, (0 : Byte))
  let channels = color.channel_count()
  let wide = is_wide(color)
  let buf = buf[:]
  let sample = (i : Int) => {
    if wide {
      ((u16_le(buf, 2 * i) + 128) / 257).to_byte()
    } else {
      buf[i]
    }
  }
  for p in 0..<n {
    let base = p * channels
    let (r, g, b, a) = match channels {
      1 => {
        let l = sample(base)
        (l, l, l, (255 : Byte))
      }
      2 => {
        let l = sample(base)
        (l, l, l, sample(base + 1))
      }
      3 => (sample(base), sample(base + 1), sample(base + 2), (255 : Byte))
      _ => (sample(base), sample(base + 1), sample(base + 2), sample(base + 3))
    }
    out[4 * p] = r
    out[4 * p + 1] = g
    out[4 * p + 2] = b
    out[4 * p + 3] = a
  }
  Bytes::from_array(out[:])
}
