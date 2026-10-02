// Ports of image-webp 0.2.4 `src/transform.rs` (inverse DCT and WHT),
// `src/loop_filter.rs` (VP8 loop filters, RFC 6386 section 15) and the
// fancy-upsampling YUV -> RGB conversion of `src/yuv.rs`.

// ---------------------------------------------------------------------------
// transform.rs

///|
/// `vp8_idct4x4` on `block[off..off + 16]`.
fn vp8_idct4x4(block : FixedArray[Int], off : Int) -> Unit {
  let const1 = 20091L
  let const2 = 35468L
  let fetch = (idx : Int) => block[off + idx].to_int64()
  for i in 0..<4 {
    let a1 = fetch(i) + fetch(8 + i)
    let b1 = fetch(i) - fetch(8 + i)
    let t1 = (fetch(4 + i) * const2) >> 16
    let t2 = fetch(12 + i) + ((fetch(12 + i) * const1) >> 16)
    let c1 = t1 - t2
    let t1 = fetch(4 + i) + ((fetch(4 + i) * const1) >> 16)
    let t2 = (fetch(12 + i) * const2) >> 16
    let d1 = t1 + t2
    block[off + i] = (a1 + d1).to_int()
    block[off + 4 + i] = (b1 + c1).to_int()
    block[off + 4 * 3 + i] = (a1 - d1).to_int()
    block[off + 4 * 2 + i] = (b1 - c1).to_int()
  }
  for i in 0..<4 {
    let a1 = fetch(4 * i) + fetch(4 * i + 2)
    let b1 = fetch(4 * i) - fetch(4 * i + 2)
    let t1 = (fetch(4 * i + 1) * const2) >> 16
    let t2 = fetch(4 * i + 3) + ((fetch(4 * i + 3) * const1) >> 16)
    let c1 = t1 - t2
    let t1 = fetch(4 * i + 1) + ((fetch(4 * i + 1) * const1) >> 16)
    let t2 = (fetch(4 * i + 3) * const2) >> 16
    let d1 = t1 + t2
    block[off + 4 * i] = ((a1 + d1 + 4L) >> 3).to_int()
    block[off + 4 * i + 3] = ((a1 - d1 + 4L) >> 3).to_int()
    block[off + 4 * i + 1] = ((b1 + c1 + 4L) >> 3).to_int()
    block[off + 4 * i + 2] = ((b1 - c1 + 4L) >> 3).to_int()
  }
}

///|
/// `vp8_iwht4x4` (section 14.3).
fn vp8_iwht4x4(block : FixedArray[Int]) -> Unit {
  for i in 0..<4 {
    let a1 = block[i] + block[12 + i]
    let b1 = block[4 + i] + block[8 + i]
    let c1 = block[4 + i] - block[8 + i]
    let d1 = block[i] - block[12 + i]
    block[i] = a1 + b1
    block[4 + i] = c1 + d1
    block[8 + i] = a1 - b1
    block[12 + i] = d1 - c1
  }
  for r in 0..<4 {
    let o = r * 4
    let a1 = block[o] + block[o + 3]
    let b1 = block[o + 1] + block[o + 2]
    let c1 = block[o + 1] - block[o + 2]
    let d1 = block[o] - block[o + 3]
    let a2 = a1 + b1
    let b2 = c1 + d1
    let c2 = a1 - b1
    let d2 = d1 - c1
    block[o] = (a2 + 3) >> 3
    block[o + 1] = (b2 + 3) >> 3
    block[o + 2] = (c2 + 3) >> 3
    block[o + 3] = (d2 + 3) >> 3
  }
}

// ---------------------------------------------------------------------------
// loop_filter.rs
//
// The horizontal filters work on the 8 pixels `pixels[at..at + 8]` around a
// vertical edge (between `at + 3` and `at + 4`); the vertical ones on the
// column through `point` with the given stride.

///|
fn lf_c(val : Int) -> Int {
  if val < -128 {
    -128
  } else if val > 127 {
    127
  } else {
    val
  }
}

///|
fn lf_u2s(val : Byte) -> Int {
  val.to_int() - 128
}

///|
fn lf_s2u(val : Int) -> Byte {
  (lf_c(val) + 128).to_byte()
}

///|
fn lf_diff(a : Byte, b : Byte) -> Int {
  let d = a.to_int() - b.to_int()
  if d < 0 {
    -d
  } else {
    d
  }
}

///|
fn common_adjust_vertical(
  use_outer_taps : Bool,
  pixels : FixedArray[Byte],
  point : Int,
  stride : Int,
) -> Int {
  let p1 = lf_u2s(pixels[point - 2 * stride])
  let p0 = lf_u2s(pixels[point - stride])
  let q0 = lf_u2s(pixels[point])
  let q1 = lf_u2s(pixels[point + stride])
  let outer = if use_outer_taps { lf_c(p1 - q1) } else { 0 }
  let a = lf_c(outer + 3 * (q0 - p0))
  let b = lf_c(a + 3) >> 3
  let a = lf_c(a + 4) >> 3
  pixels[point] = lf_s2u(q0 - a)
  pixels[point - stride] = lf_s2u(p0 + b)
  a
}

///|
fn common_adjust_horizontal(
  use_outer_taps : Bool,
  pixels : FixedArray[Byte],
  at : Int,
) -> Int {
  let p1 = lf_u2s(pixels[at + 2])
  let p0 = lf_u2s(pixels[at + 3])
  let q0 = lf_u2s(pixels[at + 4])
  let q1 = lf_u2s(pixels[at + 5])
  let outer = if use_outer_taps { lf_c(p1 - q1) } else { 0 }
  let a = lf_c(outer + 3 * (q0 - p0))
  let b = lf_c(a + 3) >> 3
  let a = lf_c(a + 4) >> 3
  pixels[at + 4] = lf_s2u(q0 - a)
  pixels[at + 3] = lf_s2u(p0 + b)
  a
}

///|
fn simple_threshold_vertical(
  filter_limit : Int,
  pixels : FixedArray[Byte],
  point : Int,
  stride : Int,
) -> Bool {
  lf_diff(pixels[point - stride], pixels[point]) * 2 +
  lf_diff(pixels[point - 2 * stride], pixels[point + stride]) / 2 <=
  filter_limit
}

///|
fn simple_threshold_horizontal(
  filter_limit : Int,
  pixels : FixedArray[Byte],
  at : Int,
) -> Bool {
  lf_diff(pixels[at + 3], pixels[at + 4]) * 2 +
  lf_diff(pixels[at + 2], pixels[at + 5]) / 2 <=
  filter_limit
}

///|
fn should_filter_vertical(
  interior_limit : Int,
  edge_limit : Int,
  pixels : FixedArray[Byte],
  point : Int,
  stride : Int,
) -> Bool {
  simple_threshold_vertical(edge_limit, pixels, point, stride) &&
  lf_diff(pixels[point - 4 * stride], pixels[point - 3 * stride]) <=
  interior_limit &&
  lf_diff(pixels[point - 3 * stride], pixels[point - 2 * stride]) <=
  interior_limit &&
  lf_diff(pixels[point - 2 * stride], pixels[point - stride]) <= interior_limit &&
  lf_diff(pixels[point + 3 * stride], pixels[point + 2 * stride]) <=
  interior_limit &&
  lf_diff(pixels[point + 2 * stride], pixels[point + stride]) <= interior_limit &&
  lf_diff(pixels[point + stride], pixels[point]) <= interior_limit
}

///|
fn should_filter_horizontal(
  interior_limit : Int,
  edge_limit : Int,
  pixels : FixedArray[Byte],
  at : Int,
) -> Bool {
  simple_threshold_horizontal(edge_limit, pixels, at) &&
  lf_diff(pixels[at], pixels[at + 1]) <= interior_limit &&
  lf_diff(pixels[at + 1], pixels[at + 2]) <= interior_limit &&
  lf_diff(pixels[at + 2], pixels[at + 3]) <= interior_limit &&
  lf_diff(pixels[at + 7], pixels[at + 6]) <= interior_limit &&
  lf_diff(pixels[at + 6], pixels[at + 5]) <= interior_limit &&
  lf_diff(pixels[at + 5], pixels[at + 4]) <= interior_limit
}

///|
fn high_edge_variance_vertical(
  threshold : Int,
  pixels : FixedArray[Byte],
  point : Int,
  stride : Int,
) -> Bool {
  lf_diff(pixels[point - 2 * stride], pixels[point - stride]) > threshold ||
  lf_diff(pixels[point + stride], pixels[point]) > threshold
}

///|
fn high_edge_variance_horizontal(
  threshold : Int,
  pixels : FixedArray[Byte],
  at : Int,
) -> Bool {
  lf_diff(pixels[at + 2], pixels[at + 3]) > threshold ||
  lf_diff(pixels[at + 5], pixels[at + 4]) > threshold
}

///|
fn simple_segment_vertical(
  edge_limit : Int,
  pixels : FixedArray[Byte],
  point : Int,
  stride : Int,
) -> Unit {
  if simple_threshold_vertical(edge_limit, pixels, point, stride) {
    common_adjust_vertical(true, pixels, point, stride) |> ignore
  }
}

///|
fn simple_segment_horizontal(
  edge_limit : Int,
  pixels : FixedArray[Byte],
  at : Int,
) -> Unit {
  if simple_threshold_horizontal(edge_limit, pixels, at) {
    common_adjust_horizontal(true, pixels, at) |> ignore
  }
}

///|
fn subblock_filter_vertical(
  hev_threshold : Int,
  interior_limit : Int,
  edge_limit : Int,
  pixels : FixedArray[Byte],
  point : Int,
  stride : Int,
) -> Unit {
  if should_filter_vertical(interior_limit, edge_limit, pixels, point, stride) {
    let hv = high_edge_variance_vertical(hev_threshold, pixels, point, stride)
    let a = (common_adjust_vertical(hv, pixels, point, stride) + 1) >> 1
    if !hv {
      pixels[point + stride] = lf_s2u(lf_u2s(pixels[point + stride]) - a)
      pixels[point - 2 * stride] = lf_s2u(
        lf_u2s(pixels[point - 2 * stride]) + a,
      )
    }
  }
}

///|
fn subblock_filter_horizontal(
  hev_threshold : Int,
  interior_limit : Int,
  edge_limit : Int,
  pixels : FixedArray[Byte],
  at : Int,
) -> Unit {
  if should_filter_horizontal(interior_limit, edge_limit, pixels, at) {
    let hv = high_edge_variance_horizontal(hev_threshold, pixels, at)
    let a = (common_adjust_horizontal(hv, pixels, at) + 1) >> 1
    if !hv {
      pixels[at + 5] = lf_s2u(lf_u2s(pixels[at + 5]) - a)
      pixels[at + 2] = lf_s2u(lf_u2s(pixels[at + 2]) + a)
    }
  }
}

///|
fn macroblock_filter_vertical(
  hev_threshold : Int,
  interior_limit : Int,
  edge_limit : Int,
  pixels : FixedArray[Byte],
  point : Int,
  stride : Int,
) -> Unit {
  if should_filter_vertical(interior_limit, edge_limit, pixels, point, stride) {
    if !high_edge_variance_vertical(hev_threshold, pixels, point, stride) {
      let p2 = lf_u2s(pixels[point - 3 * stride])
      let p1 = lf_u2s(pixels[point - 2 * stride])
      let p0 = lf_u2s(pixels[point - stride])
      let q0 = lf_u2s(pixels[point])
      let q1 = lf_u2s(pixels[point + stride])
      let q2 = lf_u2s(pixels[point + 2 * stride])
      let w = lf_c(lf_c(p1 - q1) + 3 * (q0 - p0))
      let a = lf_c((27 * w + 63) >> 7)
      pixels[point] = lf_s2u(q0 - a)
      pixels[point - stride] = lf_s2u(p0 + a)
      let a = lf_c((18 * w + 63) >> 7)
      pixels[point + stride] = lf_s2u(q1 - a)
      pixels[point - 2 * stride] = lf_s2u(p1 + a)
      let a = lf_c((9 * w + 63) >> 7)
      pixels[point + 2 * stride] = lf_s2u(q2 - a)
      pixels[point - 3 * stride] = lf_s2u(p2 + a)
    } else {
      common_adjust_vertical(true, pixels, point, stride) |> ignore
    }
  }
}

///|
fn macroblock_filter_horizontal(
  hev_threshold : Int,
  interior_limit : Int,
  edge_limit : Int,
  pixels : FixedArray[Byte],
  at : Int,
) -> Unit {
  if should_filter_horizontal(interior_limit, edge_limit, pixels, at) {
    if !high_edge_variance_horizontal(hev_threshold, pixels, at) {
      let p2 = lf_u2s(pixels[at + 1])
      let p1 = lf_u2s(pixels[at + 2])
      let p0 = lf_u2s(pixels[at + 3])
      let q0 = lf_u2s(pixels[at + 4])
      let q1 = lf_u2s(pixels[at + 5])
      let q2 = lf_u2s(pixels[at + 6])
      let w = lf_c(lf_c(p1 - q1) + 3 * (q0 - p0))
      let a = lf_c((27 * w + 63) >> 7)
      pixels[at + 4] = lf_s2u(q0 - a)
      pixels[at + 3] = lf_s2u(p0 + a)
      let a = lf_c((18 * w + 63) >> 7)
      pixels[at + 5] = lf_s2u(q1 - a)
      pixels[at + 2] = lf_s2u(p1 + a)
      let a = lf_c((9 * w + 63) >> 7)
      pixels[at + 6] = lf_s2u(q2 - a)
      pixels[at + 1] = lf_s2u(p2 + a)
    } else {
      common_adjust_horizontal(true, pixels, at) |> ignore
    }
  }
}

// ---------------------------------------------------------------------------
// yuv.rs (fancy upsampling)

///|
/// `_mm_mulhi_epu16` emulation.
fn yuv_mulhi(v : Int, coeff : Int) -> Int {
  (v * coeff) >> 8
}

///|
fn yuv_clip(v : Int) -> Int {
  let v = v >> 6
  if v < 0 {
    0
  } else if v > 255 {
    255
  } else {
    v
  }
}

///|
fn yuv_set_pixel(
  rgb : FixedArray[Byte],
  at : Int,
  y : Int,
  u : Int,
  v : Int,
) -> Unit {
  rgb[at] = yuv_clip(yuv_mulhi(y, 19077) + yuv_mulhi(v, 26149) - 14234).to_byte()
  rgb[at + 1] = yuv_clip(
    yuv_mulhi(y, 19077) - yuv_mulhi(u, 6419) - yuv_mulhi(v, 13320) + 8708,
  ).to_byte()
  rgb[at + 2] = yuv_clip(yuv_mulhi(y, 19077) + yuv_mulhi(u, 33050) - 17685).to_byte()
}

///|
fn get_fancy_chroma_value(
  main : Int,
  secondary1 : Int,
  secondary2 : Int,
  tertiary : Int,
) -> Int {
  (9 * main + 3 * secondary1 + 3 * secondary2 + tertiary + 8) / 16
}

///|
/// `fill_rgb_buffer_fancy::<bpp>`.
fn fill_rgb_buffer_fancy(
  buffer : FixedArray[Byte],
  bpp : Int,
  y_buffer : FixedArray[Byte],
  u_buffer : FixedArray[Byte],
  v_buffer : FixedArray[Byte],
  width : Int,
  height : Int,
  buffer_width : Int,
) -> Unit {
  // buffer width is always even so don't need to do div_ceil
  let chroma_buffer_width = buffer_width / 2
  let chroma_width = (width + 1) / 2

  // fill top row first since it only uses the top u/v row
  fill_row_fancy_with_1_uv_row(
    buffer, 0, bpp, width, y_buffer, 0, u_buffer, 0, v_buffer, 0, chroma_width,
  )
  // The pairs of rows after the first: limited by the row buffer chunks,
  // the y chunks and the u/v windows.
  let row_pairs = (buffer.length() - width * bpp) / (width * bpp * 2)
  let y_pairs = (height * buffer_width - buffer_width) / (buffer_width * 2)
  let uv_windows = if u_buffer.length() >= chroma_buffer_width * 2 {
    (u_buffer.length() - chroma_buffer_width * 2) / chroma_buffer_width + 1
  } else {
    0
  }
  let n = imin3(row_pairs, y_pairs, uv_windows)
  for k in 0..<n {
    let row_off = width * bpp + k * width * bpp * 2
    let y_off = buffer_width + k * buffer_width * 2
    let u1 = k * chroma_buffer_width
    let u2 = u1 + chroma_buffer_width
    fill_row_fancy_with_2_uv_rows(
      buffer, row_off, bpp, width, y_buffer, y_off, u_buffer, u1, u2, v_buffer, u1,
      u2, chroma_width,
    )
    fill_row_fancy_with_2_uv_rows(
      buffer,
      row_off + width * bpp,
      bpp,
      width,
      y_buffer,
      y_off + buffer_width,
      u_buffer,
      u2,
      u1,
      v_buffer,
      u2,
      u1,
      chroma_width,
    )
  }

  // if the image has even height there will be one final row with only one u/v row matching it
  // (`into_remainder` / `remainder` of the exact chunk iterators.)
  let final_row = width * bpp + row_pairs * width * bpp * 2
  if final_row < buffer.length() {
    let final_y = buffer_width + y_pairs * buffer_width * 2
    let chroma_height = (height + 1) / 2
    let start_chroma_index = (chroma_height - 1) * chroma_buffer_width
    fill_row_fancy_with_1_uv_row(
      buffer, final_row, bpp, width, y_buffer, final_y, u_buffer, start_chroma_index,
      v_buffer, start_chroma_index, chroma_width,
    )
  }
}

///|
fn imin3(a : Int, b : Int, c : Int) -> Int {
  let m = if a < b { a } else { b }
  if m < c {
    m
  } else {
    c
  }
}

///|
/// Fills a row with the fancy interpolation as detailed.
fn fill_row_fancy_with_2_uv_rows(
  buf : FixedArray[Byte],
  row : Int,
  bpp : Int,
  width : Int,
  y : FixedArray[Byte],
  yo : Int,
  u : FixedArray[Byte],
  u1 : Int,
  u2 : Int,
  v : FixedArray[Byte],
  v1 : Int,
  v2 : Int,
  chroma_width : Int,
) -> Unit {
  let g = (b : FixedArray[Byte], i : Int) => b[i].to_int()
  // need to do left pixel separately since it will only have one u/v value
  {
    let u_value = get_fancy_chroma_value(g(u, u1), g(u, u1), g(u, u2), g(u, u2))
    let v_value = get_fancy_chroma_value(g(v, v1), g(v, v1), g(v, v2), g(v, v2))
    yuv_set_pixel(buf, row, g(y, yo), u_value, v_value)
  }
  // we do two pixels at a time since they share the same u/v values
  let pairs = imin3((width - 1) / 2, (width - 1) / 2, chroma_width - 1)
  for i in 0..<pairs {
    let at = row + bpp + i * bpp * 2
    let yi = yo + 1 + 2 * i
    let a1 = g(u, u1 + i)
    let b1 = g(u, u1 + i + 1)
    let a2 = g(u, u2 + i)
    let b2 = g(u, u2 + i + 1)
    let c1 = g(v, v1 + i)
    let d1 = g(v, v1 + i + 1)
    let c2 = g(v, v2 + i)
    let d2 = g(v, v2 + i + 1)
    yuv_set_pixel(
      buf,
      at,
      g(y, yi),
      get_fancy_chroma_value(a1, b1, a2, b2),
      get_fancy_chroma_value(c1, d1, c2, d2),
    )
    yuv_set_pixel(
      buf,
      at + bpp,
      g(y, yi + 1),
      get_fancy_chroma_value(b1, a1, b2, a2),
      get_fancy_chroma_value(d1, c1, d2, c2),
    )
  }
  // The final pixel (when the row chunks and y chunks both leave exactly one
  // pixel).
  let rest = width - 1
  if rest % 2 == 1 && pairs == rest / 2 {
    let at = row + bpp + pairs * bpp * 2
    let fu1 = g(u, u1 + chroma_width - 1)
    let fu2 = g(u, u2 + chroma_width - 1)
    let fv1 = g(v, v1 + chroma_width - 1)
    let fv2 = g(v, v2 + chroma_width - 1)
    yuv_set_pixel(
      buf,
      at,
      g(y, yo + width - 1),
      get_fancy_chroma_value(fu1, fu1, fu2, fu2),
      get_fancy_chroma_value(fv1, fv1, fv2, fv2),
    )
  }
}

///|
fn fill_row_fancy_with_1_uv_row(
  buf : FixedArray[Byte],
  row : Int,
  bpp : Int,
  width : Int,
  y : FixedArray[Byte],
  yo : Int,
  u : FixedArray[Byte],
  uo : Int,
  v : FixedArray[Byte],
  vo : Int,
  chroma_width : Int,
) -> Unit {
  let g = (b : FixedArray[Byte], i : Int) => b[i].to_int()
  // doing left pixel first
  yuv_set_pixel(buf, row, g(y, yo), g(u, uo), g(v, vo))
  // two pixels at a time since they share the same u/v value
  let pairs = imin3((width - 1) / 2, (width - 1) / 2, chroma_width - 1)
  for i in 0..<pairs {
    let at = row + bpp + i * bpp * 2
    let yi = yo + 1 + 2 * i
    let a = g(u, uo + i)
    let b = g(u, uo + i + 1)
    let c = g(v, vo + i)
    let d = g(v, vo + i + 1)
    yuv_set_pixel(
      buf,
      at,
      g(y, yi),
      get_fancy_chroma_value(a, b, a, b),
      get_fancy_chroma_value(c, d, c, d),
    )
    yuv_set_pixel(
      buf,
      at + bpp,
      g(y, yi + 1),
      get_fancy_chroma_value(b, a, b, a),
      get_fancy_chroma_value(d, c, d, c),
    )
  }
  let rest = width - 1
  if rest % 2 == 1 && pairs == rest / 2 {
    let at = row + bpp + pairs * bpp * 2
    yuv_set_pixel(
      buf,
      at,
      g(y, yo + width - 1),
      g(u, uo + chroma_width - 1),
      g(v, vo + chroma_width - 1),
    )
  }
}
