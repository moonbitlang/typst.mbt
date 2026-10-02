// Port of `resvg/src/filter/morphology.rs`.

///|
/// Applies a morphology filter.
///
/// `src` pixels should have a **premultiplied alpha**.
///
/// # Allocations
///
/// This method will allocate a copy of the `src` image as a back buffer.
fn morphology_apply(
  operator : @usvg.MorphologyOperator,
  rx : Float,
  ry : Float,
  src : @skia.Pixmap,
) -> Unit {
  let width = src.width()
  let height = src.height()
  // No point in making matrix larger than image.
  let columns = umin(
    f32_to_u32(@skia.ceilf(rx)) * 2,
    width.reinterpret_as_uint(),
  ).reinterpret_as_int()
  let rows = umin(
    f32_to_u32(@skia.ceilf(ry)) * 2,
    height.reinterpret_as_uint(),
  ).reinterpret_as_int()
  let target_x = f32_to_u32(@skia.floorf(Float::from_int(columns) / 2.0)).reinterpret_as_int()
  let target_y = f32_to_u32(@skia.floorf(Float::from_int(rows) / 2.0)).reinterpret_as_int()
  let width_max = width - 1
  let height_max = height - 1
  let data = src.pixels()
  let buf = FixedArray::make(data.length(), 0U)
  let erode = operator == Erode
  let mut x = 0
  let mut y = 0
  for _ in 0..<data.length() {
    let init = if erode { 255 } else { 0 }
    let mut nr = init
    let mut ng = init
    let mut nb = init
    let mut na = init
    for oy in 0..<rows {
      for ox in 0..<columns {
        let tx = x - target_x + ox
        let ty = y - target_y + oy
        if tx < 0 || tx > width_max || ty < 0 || ty > height_max {
          continue
        }
        let p = data[width * ty + tx]
        if erode {
          nr = imin(px_r(p), nr)
          ng = imin(px_g(p), ng)
          nb = imin(px_b(p), nb)
          na = imin(px_a(p), na)
        } else {
          nr = imax(px_r(p), nr)
          ng = imax(px_g(p), ng)
          nb = imax(px_b(p), nb)
          na = imax(px_a(p), na)
        }
      }
    }
    buf[width * y + x] = px_pack(nr, ng, nb, na)
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

///|
fn umin(a : UInt, b : UInt) -> UInt {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn imax(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
