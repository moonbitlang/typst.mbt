// Port of `resvg/src/filter/iir_blur.rs`.
//
// An IIR blur.
//
// Based on http://www.getreuer.info/home/gaussianiir
//
// Licensed under 'Simplified BSD License'.
//
//
// Implements the fast Gaussian convolution algorithm of Alvarez and Mazorra,
// where the Gaussian is approximated by a cascade of first-order infinite
// impulsive response (IIR) filters.  Boundaries are handled with half-sample
// symmetric extension.
//
// Gaussian convolution is approached as approximating the heat equation and
// each timestep is performed with an efficient recursive computation.  Using
// more steps yields a more accurate approximation of the Gaussian.  A
// reasonable default value for `numsteps` is 4.
//
// Reference:
// Alvarez, Mazorra, "Signal and Image Restoration using Shock Filters and
// Anisotropic Diffusion," SIAM J. on Numerical Analysis, vol. 31, no. 2,
// pp. 590-605, 1994.

// TODO: Blurs right and bottom sides twice for some reason.

///|
priv struct BlurData {
  width : Int
  height : Int
  sigma_x : Double
  sigma_y : Double
  steps : Int
}

///|
/// Applies an IIR blur.
///
/// Input image pixels should have a **premultiplied alpha**.
///
/// A negative or zero `sigma_x`/`sigma_y` will disable the blur along that axis.
///
/// # Allocations
///
/// This method will allocate a 2x `src` buffer.
fn iir_blur_apply(sigma_x : Double, sigma_y : Double, src : @skia.Pixmap) -> Unit {
  let buf_size = src.width() * src.height()
  let buf = FixedArray::make(buf_size, 0.0)
  let d = {
    width: src.width(),
    height: src.height(),
    sigma_x,
    sigma_y,
    steps: 4,
  }
  let data = src.pixels()
  gaussian_channel(data, d, 0, buf)
  gaussian_channel(data, d, 1, buf)
  gaussian_channel(data, d, 2, buf)
  gaussian_channel(data, d, 3, buf)
}

///|
fn gaussian_channel(
  data : FixedArray[UInt],
  d : BlurData,
  channel : Int,
  buf : FixedArray[Double],
) -> Unit {
  let shift = channel * 8
  for i in 0..<data.length() {
    buf[i] = ((data[i] >> shift) & 0xFF).to_double() / 255.0
  }
  gaussianiir2d(d, buf)
  let mask = (0xFFU << shift).lnot()
  for i in 0..<data.length() {
    let v = f64_to_u8(buf[i] * 255.0).reinterpret_as_uint()
    data[i] = (data[i] & mask) | (v << shift)
  }
}

///|
fn gaussianiir2d(d : BlurData, buf : FixedArray[Double]) -> Unit {
  // Filter horizontally along each row.
  let (lambda_x, dnu_x) = if d.sigma_x > 0.0 {
    let (lambda, dnu) = gen_coefficients(d.sigma_x, d.steps)
    for y in 0..<d.height {
      for _ in 0..<d.steps {
        let idx = d.width * y

        // Filter rightwards.
        for x in 1..<d.width {
          buf[idx + x] += dnu * buf[idx + x - 1]
        }
        let mut x = d.width - 1

        // Filter leftwards.
        while x > 0 {
          buf[idx + x - 1] += dnu * buf[idx + x]
          x -= 1
        }
      }
    }
    (lambda, dnu)
  } else {
    (1.0, 1.0)
  }

  // Filter vertically along each column.
  let (lambda_y, dnu_y) = if d.sigma_y > 0.0 {
    let (lambda, dnu) = gen_coefficients(d.sigma_y, d.steps)
    let len = buf.length()
    for x in 0..<d.width {
      for _ in 0..<d.steps {
        let idx = x

        // Filter downwards.
        let mut y = d.width
        while y < len {
          buf[idx + y] += dnu * buf[idx + y - d.width]
          y += d.width
        }
        y = len - d.width

        // Filter upwards.
        while y > 0 {
          buf[idx + y - d.width] += dnu * buf[idx + y]
          y -= d.width
        }
      }
    }
    (lambda, dnu)
  } else {
    (1.0, 1.0)
  }
  let post_scale = powi(
    (dnu_x * dnu_y).sqrt() / (lambda_x * lambda_y).sqrt(),
    2 * d.steps,
  )
  for i in 0..<buf.length() {
    buf[i] *= post_scale
  }
}

///|
fn gen_coefficients(sigma : Double, steps : Int) -> (Double, Double) {
  let lambda = sigma * sigma / (2.0 * steps.to_double())
  let dnu = (1.0 + 2.0 * lambda - (1.0 + 4.0 * lambda).sqrt()) / (2.0 * lambda)
  (lambda, dnu)
}

///|
/// `f64::powi` (LLVM's `__powidf2`: repeated squaring).
fn powi(a : Double, b : Int) -> Double {
  let recip = b < 0
  let mut a = a
  let mut b = b
  let mut r = 1.0
  while true {
    if (b & 1) != 0 {
      r *= a
    }
    b /= 2
    if b == 0 {
      break
    }
    a *= a
  }
  if recip {
    1.0 / r
  } else {
    r
  }
}
