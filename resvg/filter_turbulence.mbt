// Port of `resvg/src/filter/turbulence.rs`.

///|
let rand_m : Int = 2147483647 // 2**31 - 1

///|
let rand_a : Int = 16807 // 7**5; primitive root of m

///|
let rand_q : Int = 127773 // m / a

///|
let rand_r : Int = 2836 // m % a

///|
let b_size : Int = 0x100

///|
let b_len : Int = 0x100 + 0x100 + 2

///|
let bm : Int = 0xff

///|
let perlin_n : Int = 0x1000

///|
priv struct StitchInfo {
  mut width : Int // How much to subtract to wrap for stitching.
  mut height : Int
  mut wrap_x : Int // Minimum value to wrap.
  mut wrap_y : Int
}

///|
/// Applies a turbulence filter.
///
/// `dest` image pixels will have an **unpremultiplied alpha**.
///
/// - `offset_x` and `offset_y` indicate filter region offset.
/// - `sx` and `sy` indicate canvas scale.
fn turbulence_apply(
  offset_x : Double,
  offset_y : Double,
  sx : Double,
  sy : Double,
  base_frequency_x : Double,
  base_frequency_y : Double,
  num_octaves : UInt,
  seed : Int,
  stitch_tiles : Bool,
  fractal_noise : Bool,
  dest : @skia.Pixmap,
) -> Unit {
  let (lattice_selector, gradient) = turbulence_init(seed)
  let width = dest.width()
  let height = dest.height()
  let data = dest.pixels()
  let mut x = 0
  let mut y = 0
  for i in 0..<data.length() {
    let turb = fn(channel : Int) -> Int {
      let (tx, ty) = (
        (x.to_double() + offset_x) / sx,
        (y.to_double() + offset_y) / sy,
      )
      let n = turbulence(
        channel,
        tx,
        ty,
        x.to_double(),
        y.to_double(),
        width.to_double(),
        height.to_double(),
        base_frequency_x,
        base_frequency_y,
        num_octaves,
        fractal_noise,
        stitch_tiles,
        lattice_selector,
        gradient,
      )
      let n = if fractal_noise {
        (n * 255.0 + 255.0) / 2.0
      } else {
        n * 255.0
      }
      f32_to_u8(f32_bound(0.0, n.to_float(), 255.0) + 0.5)
    }
    let r = turb(0)
    let g = turb(1)
    let b = turb(2)
    let a = turb(3)
    data[i] = px_pack(r, g, b, a)
    x += 1
    if x == width {
      x = 0
      y += 1
    }
  }
}

///|
/// The gradient table is stored flat: `gradient[k][i][j]` is at
/// `(k * b_len + i) * 2 + j`.
fn turbulence_init(seed : Int) -> (FixedArray[Int], FixedArray[Double]) {
  let lattice_selector = FixedArray::make(b_len, 0)
  let gradient = FixedArray::make(4 * b_len * 2, 0.0)
  let gi = fn(k : Int, i : Int, j : Int) -> Int { (k * b_len + i) * 2 + j }
  let mut seed = seed
  if seed <= 0 {
    seed = -seed % (rand_m - 1) + 1
  }
  if seed > rand_m - 1 {
    seed = rand_m - 1
  }
  for k in 0..<4 {
    for i in 0..<b_size {
      lattice_selector[i] = i
      for j in 0..<2 {
        seed = random(seed)
        gradient[gi(k, i, j)] = (seed % (b_size + b_size) - b_size).to_double() /
          b_size.to_double()
      }
      let s = (
        gradient[gi(k, i, 0)] * gradient[gi(k, i, 0)] +
        gradient[gi(k, i, 1)] * gradient[gi(k, i, 1)]
      ).sqrt()
      gradient[gi(k, i, 0)] /= s
      gradient[gi(k, i, 1)] /= s
    }
  }
  for i = b_size - 1; i >= 1; i = i - 1 {
    let k = lattice_selector[i]
    seed = random(seed)
    let j = seed % b_size
    lattice_selector[i] = lattice_selector[j]
    lattice_selector[j] = k
  }
  for i in 0..<(b_size + 2) {
    lattice_selector[b_size + i] = lattice_selector[i]
    for g in 0..<4 {
      for j in 0..<2 {
        gradient[gi(g, b_size + i, j)] = gradient[gi(g, i, j)]
      }
    }
  }
  (lattice_selector, gradient)
}

///|
fn turbulence(
  color_channel : Int,
  x : Double,
  y : Double,
  tile_x : Double,
  tile_y : Double,
  tile_width : Double,
  tile_height : Double,
  base_freq_x : Double,
  base_freq_y : Double,
  num_octaves : UInt,
  fractal_sum : Bool,
  do_stitching : Bool,
  lattice_selector : FixedArray[Int],
  gradient : FixedArray[Double],
) -> Double {
  let mut base_freq_x = base_freq_x
  let mut base_freq_y = base_freq_y
  // Adjust the base frequencies if necessary for stitching.
  let stitch = if do_stitching {
    // When stitching tiled turbulence, the frequencies must be adjusted
    // so that the tile borders will be continuous.
    if !@path.approx_eq_ulps_f64(base_freq_x, 0.0, 4L) {
      let lo_freq = (tile_width * base_freq_x).floor() / tile_width
      let hi_freq = (tile_width * base_freq_x).ceil() / tile_width
      if base_freq_x / lo_freq < hi_freq / base_freq_x {
        base_freq_x = lo_freq
      } else {
        base_freq_x = hi_freq
      }
    }
    if !@path.approx_eq_ulps_f64(base_freq_y, 0.0, 4L) {
      let lo_freq = (tile_height * base_freq_y).floor() / tile_height
      let hi_freq = (tile_height * base_freq_y).ceil() / tile_height
      if base_freq_y / lo_freq < hi_freq / base_freq_y {
        base_freq_y = lo_freq
      } else {
        base_freq_y = hi_freq
      }
    }

    // Set up initial stitch values.
    let width = f64_to_i32(tile_width * base_freq_x + 0.5)
    let height = f64_to_i32(tile_height * base_freq_y + 0.5)
    let wrap_x = f64_to_i32(
      tile_x * base_freq_x + perlin_n.to_double() + width.to_double(),
    )
    let wrap_y = f64_to_i32(
      tile_y * base_freq_y + perlin_n.to_double() + height.to_double(),
    )
    Some({ width, height, wrap_x, wrap_y })
  } else {
    None
  }
  let mut sum = 0.0
  let mut x = x * base_freq_x
  let mut y = y * base_freq_y
  let mut ratio = 1.0
  for _ in 0U..<num_octaves {
    if fractal_sum {
      sum += noise2(color_channel, x, y, lattice_selector, gradient, stitch) /
        ratio
    } else {
      sum += noise2(color_channel, x, y, lattice_selector, gradient, stitch).abs() /
        ratio
    }
    x *= 2.0
    y *= 2.0
    ratio *= 2.0
    if stitch is Some(stitch) {
      // Update stitch values. Subtracting PerlinN before the multiplication and
      // adding it afterward simplifies to subtracting it once.
      stitch.width *= 2
      stitch.wrap_x = 2 * stitch.wrap_x - perlin_n
      stitch.height *= 2
      stitch.wrap_y = 2 * stitch.wrap_y - perlin_n
    }
  }
  sum
}

///|
fn noise2(
  color_channel : Int,
  x : Double,
  y : Double,
  lattice_selector : FixedArray[Int],
  gradient : FixedArray[Double],
  stitch_info : StitchInfo?,
) -> Double {
  let t = x + perlin_n.to_double()
  let mut bx0 = f64_to_i32(t)
  let mut bx1 = bx0 + 1
  let rx0 = t - f64_to_i64(t).to_double()
  let rx1 = rx0 - 1.0
  let t = y + perlin_n.to_double()
  let mut by0 = f64_to_i32(t)
  let mut by1 = by0 + 1
  let ry0 = t - f64_to_i64(t).to_double()
  let ry1 = ry0 - 1.0

  // If stitching, adjust lattice points accordingly.
  if stitch_info is Some(info) {
    if bx0 >= info.wrap_x {
      bx0 -= info.width
    }
    if bx1 >= info.wrap_x {
      bx1 -= info.width
    }
    if by0 >= info.wrap_y {
      by0 -= info.height
    }
    if by1 >= info.wrap_y {
      by1 -= info.height
    }
  }
  bx0 = bx0 & bm
  bx1 = bx1 & bm
  by0 = by0 & bm
  by1 = by1 & bm
  let i = lattice_selector[bx0]
  let j = lattice_selector[bx1]
  let b00 = lattice_selector[i + by0]
  let b10 = lattice_selector[j + by0]
  let b01 = lattice_selector[i + by1]
  let b11 = lattice_selector[j + by1]
  let sx = s_curve(rx0)
  let sy = s_curve(ry0)
  let base = color_channel * b_len
  let q = (base + b00) * 2
  let u = rx0 * gradient[q] + ry0 * gradient[q + 1]
  let q = (base + b10) * 2
  let v = rx1 * gradient[q] + ry0 * gradient[q + 1]
  let a = lerp(sx, u, v)
  let q = (base + b01) * 2
  let u = rx0 * gradient[q] + ry1 * gradient[q + 1]
  let q = (base + b11) * 2
  let v = rx1 * gradient[q] + ry1 * gradient[q + 1]
  let b = lerp(sx, u, v)
  lerp(sy, a, b)
}

///|
fn random(seed : Int) -> Int {
  let mut result = rand_a * (seed % rand_q) - rand_r * (seed / rand_q)
  if result <= 0 {
    result += rand_m
  }
  result
}

///|
fn s_curve(t : Double) -> Double {
  t * t * (3.0 - 2.0 * t)
}

///|
fn lerp(t : Double, a : Double, b : Double) -> Double {
  a + t * (b - a)
}
