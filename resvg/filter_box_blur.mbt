// Port of `resvg/src/filter/box_blur.rs`.
//
// Based on https://github.com/fschutt/fastblur

///|
let box_blur_steps : Int = 5

///|
/// Applies a box blur.
///
/// Input image pixels should have a **premultiplied alpha**.
///
/// A negative or zero `sigma_x`/`sigma_y` will disable the blur along that axis.
///
/// # Allocations
///
/// This method will allocate a copy of the `src` image as a back buffer.
fn box_blur_apply(
  sigma_x : Double,
  sigma_y : Double,
  src : @skia.Pixmap,
) -> Unit {
  let boxes_horz = create_box_gauss(Float::from_double(sigma_x))
  let boxes_vert = create_box_gauss(Float::from_double(sigma_y))
  let width = src.width()
  let height = src.height()
  let frontbuf = src.pixels()
  let backbuf = frontbuf.copy()
  for i in 0..<box_blur_steps {
    let box_size_horz = boxes_horz[i]
    let box_size_vert = boxes_vert[i]
    let radius_horz = (box_size_horz - 1) / 2
    let radius_vert = (box_size_vert - 1) / 2
    box_blur_impl(radius_horz, radius_vert, width, height, backbuf, frontbuf)
  }
}

///|
fn create_box_gauss(sigma : Float) -> FixedArray[Int] {
  if sigma > 0.0 {
    let n_float = Float::from_int(box_blur_steps)

    // Ideal averaging filter width
    let c12 : Float = 12.0
    let w_ideal = (c12 * sigma * sigma / n_float).sqrt() + 1.0
    let mut wl = f32_to_i32(@skia.floorf(w_ideal))
    if wl % 2 == 0 {
      wl -= 1
    }
    let wu = wl + 2
    let wl_float = Float::from_int(wl)
    let c4 : Float = 4.0
    let c3 : Float = 3.0
    let m_ideal = (
        c12 * sigma * sigma -
        n_float * wl_float * wl_float -
        c4 * n_float * wl_float -
        c3 * n_float
      ) /
      (-c4 * wl_float - c4)
    let m = f32_to_usize(@skia.roundf(m_ideal))
    let sizes = FixedArray::make(box_blur_steps, 0)
    for i in 0..<box_blur_steps {
      if i.to_int64() < m {
        sizes[i] = wl
      } else {
        sizes[i] = wu
      }
    }
    sizes
  } else {
    FixedArray::make(box_blur_steps, 1)
  }
}

///|
/// `x as usize` for an `f32` (saturating, NaN maps to 0).
fn f32_to_usize(x : Float) -> Int64 {
  if x != x || x <= 0.0 {
    0L
  } else {
    f64_to_i64(x.to_double())
  }
}

///|
fn box_blur_impl(
  blur_radius_horz : Int,
  blur_radius_vert : Int,
  width : Int,
  height : Int,
  backbuf : FixedArray[UInt],
  frontbuf : FixedArray[UInt],
) -> Unit {
  box_blur_vert(blur_radius_vert, width, height, frontbuf, backbuf)
  box_blur_horz(blur_radius_horz, width, height, backbuf, frontbuf)
}

///|
/// Fast rounding for x <= 2^23.
/// This is orders of magnitude faster than built-in rounding intrinsic.
///
/// Source: https://stackoverflow.com/a/42386149/585725
fn box_round(x : Float) -> Float {
  let x = x + 12582912.0
  x - 12582912.0
}

///|
fn box_px(
  val_r : Int,
  val_g : Int,
  val_b : Int,
  val_a : Int,
  iarr : Float,
) -> UInt {
  px_pack(
    f32_to_u8(box_round(Float::from_int(val_r) * iarr)),
    f32_to_u8(box_round(Float::from_int(val_g) * iarr)),
    f32_to_u8(box_round(Float::from_int(val_b) * iarr)),
    f32_to_u8(box_round(Float::from_int(val_a) * iarr)),
  )
}

///|
fn box_blur_vert(
  blur_radius : Int,
  width : Int,
  height : Int,
  backbuf : FixedArray[UInt],
  frontbuf : FixedArray[UInt],
) -> Unit {
  if blur_radius == 0 {
    copy_pixels(backbuf, frontbuf)
    return
  }
  let iarr = (1.0 : Float) / Float::from_int(blur_radius + blur_radius + 1)
  let blur_radius_prev = blur_radius - height
  let blur_radius_next = blur_radius + 1
  for i in 0..<width {
    let col_start = i //inclusive
    let col_end = i + width * (height - 1) //inclusive
    let mut ti = i
    let mut li = ti
    let mut ri = ti + blur_radius * width
    // `fv` and `lv` are transparent black.
    let mut val_r = blur_radius_next * 0
    let mut val_g = blur_radius_next * 0
    let mut val_b = blur_radius_next * 0
    let mut val_a = blur_radius_next * 0
    for j in 0..<imin(blur_radius, height) {
      let bb = backbuf[ti + j * width]
      val_r += px_r(bb)
      val_g += px_g(bb)
      val_b += px_b(bb)
      val_a += px_a(bb)
    }
    if blur_radius > height {
      val_r += blur_radius_prev * 0
      val_g += blur_radius_prev * 0
      val_b += blur_radius_prev * 0
      val_a += blur_radius_prev * 0
    }
    for _ in 0..<imin(height, blur_radius + 1) {
      // Get the pixel at the specified index, or the last pixel of the column
      // if the index is beyond the bottom edge of the image
      let bb = if ri > col_end { 0U } else { backbuf[ri] }
      ri += width
      val_r += px_r(bb)
      val_g += px_g(bb)
      val_b += px_b(bb)
      val_a += px_a(bb)
      frontbuf[ti] = box_px(val_r, val_g, val_b, val_a, iarr)
      ti += width
    }
    if height <= blur_radius {
      // otherwise `(height - blur_radius)` will underflow
      continue
    }
    for _ in (blur_radius + 1)..<(height - blur_radius) {
      let bb1 = backbuf[ri]
      ri += width
      let bb2 = backbuf[li]
      li += width
      val_r += px_r(bb1) - px_r(bb2)
      val_g += px_g(bb1) - px_g(bb2)
      val_b += px_b(bb1) - px_b(bb2)
      val_a += px_a(bb1) - px_a(bb2)
      frontbuf[ti] = box_px(val_r, val_g, val_b, val_a, iarr)
      ti += width
    }
    for _ in 0..<imin(height - blur_radius - 1, blur_radius) {
      // Get the pixel at the specified index, or the first pixel of the column
      // if the index is beyond the top edge of the image
      let bb = if li < col_start { 0U } else { backbuf[li] }
      li += width
      val_r -= px_r(bb)
      val_g -= px_g(bb)
      val_b -= px_b(bb)
      val_a -= px_a(bb)
      frontbuf[ti] = box_px(val_r, val_g, val_b, val_a, iarr)
      ti += width
    }
  }
}

///|
fn box_blur_horz(
  blur_radius : Int,
  width : Int,
  height : Int,
  backbuf : FixedArray[UInt],
  frontbuf : FixedArray[UInt],
) -> Unit {
  if blur_radius == 0 {
    copy_pixels(backbuf, frontbuf)
    return
  }
  let iarr = (1.0 : Float) / Float::from_int(blur_radius + blur_radius + 1)
  for i in 0..<height {
    let row_start = i * width // inclusive
    let row_end = (i + 1) * width - 1 // inclusive
    let mut ti = i * width // VERTICAL: $i;
    let mut li = ti
    let mut ri = ti + blur_radius
    let mut val_r = 0
    let mut val_g = 0
    let mut val_b = 0
    let mut val_a = 0
    for j in 0..<imin(blur_radius, width) {
      let bb = backbuf[ti + j] // VERTICAL: ti + j * width
      val_r += px_r(bb)
      val_g += px_g(bb)
      val_b += px_b(bb)
      val_a += px_a(bb)
    }

    // Process the left side where we need pixels from beyond the left edge
    for _ in 0..<imin(width, blur_radius + 1) {
      // Get the pixel at the specified index, or the last pixel of the row
      // if the index is beyond the right edge of the image
      let bb = if ri > row_end { 0U } else { backbuf[ri] }
      ri += 1
      val_r += px_r(bb)
      val_g += px_g(bb)
      val_b += px_b(bb)
      val_a += px_a(bb)
      frontbuf[ti] = box_px(val_r, val_g, val_b, val_a, iarr)
      ti += 1 // VERTICAL : ti += width, same with the other areas
    }
    if width <= blur_radius {
      // otherwise `(width - blur_radius)` will underflow
      continue
    }

    // Process the middle where we know we won't bump into borders
    // without the extra indirection of get_left/get_right. This is faster.
    for _ in (blur_radius + 1)..<(width - blur_radius) {
      let bb1 = backbuf[ri]
      ri += 1
      let bb2 = backbuf[li]
      li += 1
      val_r += px_r(bb1) - px_r(bb2)
      val_g += px_g(bb1) - px_g(bb2)
      val_b += px_b(bb1) - px_b(bb2)
      val_a += px_a(bb1) - px_a(bb2)
      frontbuf[ti] = box_px(val_r, val_g, val_b, val_a, iarr)
      ti += 1
    }

    // Process the right side where we need pixels from beyond the right edge
    for _ in 0..<imin(width - blur_radius - 1, blur_radius) {
      // Get the pixel at the specified index, or the first pixel of the row
      // if the index is beyond the left edge of the image
      let bb = if li < row_start { 0U } else { backbuf[li] }
      li += 1
      val_r -= px_r(bb)
      val_g -= px_g(bb)
      val_b -= px_b(bb)
      val_a -= px_a(bb)
      frontbuf[ti] = box_px(val_r, val_g, val_b, val_a, iarr)
      ti += 1
    }
  }
}

///|
fn imin(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// `frontbuf.data.copy_from_slice(backbuf.data)`.
fn copy_pixels(src : FixedArray[UInt], dst : FixedArray[UInt]) -> Unit {
  for i in 0..<src.length() {
    dst[i] = src[i]
  }
}
