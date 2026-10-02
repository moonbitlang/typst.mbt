// Port of `resvg/src/filter/convolve_matrix.rs`.

///|
/// Applies a convolve matrix.
///
/// Input image pixels should have a **premultiplied alpha** when `preserve_alpha=false`.
///
/// # Allocations
///
/// This method will allocate a copy of the `src` image as a back buffer.
fn convolve_matrix_apply(
  matrix : @usvg.FeConvolveMatrix,
  src : @skia.Pixmap,
) -> Unit {
  fn bound(min : Int, val : Int, max : Int) -> Int {
    let v = if max < val { max } else { val }
    if min > v {
      min
    } else {
      v
    }
  }

  let width = src.width()
  let height = src.height()
  let width_max = width - 1
  let height_max = height - 1
  let data = src.pixels()
  let buf = FixedArray::make(data.length(), 0U)
  let m = matrix.matrix
  let rows = m.rows.reinterpret_as_int()
  let columns = m.columns.reinterpret_as_int()
  let target_x = m.target_x.reinterpret_as_int()
  let target_y = m.target_y.reinterpret_as_int()
  let divisor = matrix.divisor.get()
  let bias = matrix.bias
  let mut x = 0
  let mut y = 0
  for i in 0..<data.length() {
    let in_p = data[i]
    let mut new_r : Float = 0.0
    let mut new_g : Float = 0.0
    let mut new_b : Float = 0.0
    let mut new_a : Float = 0.0
    for oy in 0..<rows {
      for ox in 0..<columns {
        let mut tx = x - target_x + ox
        let mut ty = y - target_y + oy
        match matrix.edge_mode {
          EdgeNone =>
            if tx < 0 || tx > width_max || ty < 0 || ty > height_max {
              continue
            }
          Duplicate => {
            tx = bound(0, tx, width_max)
            ty = bound(0, ty, height_max)
          }
          Wrap => {
            while tx < 0 {
              tx += width
            }
            tx %= width
            while ty < 0 {
              ty += height
            }
            ty %= height
          }
        }
        let k = m.get(
          (columns - ox - 1).reinterpret_as_uint(),
          (rows - oy - 1).reinterpret_as_uint(),
        )
        let p = data[width * ty + tx]
        new_r += Float::from_int(px_r(p)) / 255.0 * k
        new_g += Float::from_int(px_g(p)) / 255.0 * k
        new_b += Float::from_int(px_b(p)) / 255.0 * k
        if !matrix.preserve_alpha {
          new_a += Float::from_int(px_a(p)) / 255.0 * k
        }
      }
    }
    if matrix.preserve_alpha {
      new_a = Float::from_int(px_a(in_p)) / 255.0
    } else {
      new_a = new_a / divisor + bias
    }
    let bounded_new_a = f32_bound(0.0, new_a, 1.0)
    let calc = fn(x : Float) -> Int {
      let x = x / divisor + bias * new_a
      let x = if matrix.preserve_alpha {
        f32_bound(0.0, x, 1.0) * bounded_new_a
      } else {
        f32_bound(0.0, x, bounded_new_a)
      }
      f32_to_u8(x * 255.0 + 0.5)
    }
    buf[width * y + x] = px_pack(
      calc(new_r),
      calc(new_g),
      calc(new_b),
      f32_to_u8(bounded_new_a * 255.0 + 0.5),
    )
    x += 1
    if x == width {
      x = 0
      y += 1
    }
  }

  // Do not use `mem::swap` because `data` referenced via FFI.
  for i in 0..<data.length() {
    data[i] = buf[i]
  }
}
