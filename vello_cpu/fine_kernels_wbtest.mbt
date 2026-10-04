// The target-selected compositing kernels (`fine_v128.mbt` on native/wasm,
// the lane emulations on wasm-gc/js) against the emulations of `fine.mbt`,
// which are compiled on every target: lengths, offsets, exact buffer ends,
// sentinels, masks, aliased buffers and undersized buffers (panics).

///|
fn vbytes(n : Int, seed : Int) -> FixedArray[Byte] {
  let mut x = seed.reinterpret_as_uint() * 2654435761U + 12345
  FixedArray::makei(n, _ => {
    x = x * 1103515245U + 12345U
    (x >> 16).reinterpret_as_int().to_byte()
  })
}

///|
/// Premultiplied RGBA pixels (color <= alpha), with opaque and transparent
/// runs.
fn vpixels(n_px : Int, seed : Int) -> FixedArray[Byte] {
  let raw = vbytes(4 * n_px, seed)
  let out = FixedArray::make(4 * n_px, b'\x00')
  for p in 0..<n_px {
    let a = match p % 5 {
      0 => 255
      1 => 0
      _ => raw[4 * p + 3].to_int()
    }
    for c in 0..<3 {
      out[4 * p + c] = (raw[4 * p + c].to_int() % (a + 1)).to_byte()
    }
    out[4 * p + 3] = a.to_byte()
  }
  out
}

///|
fn vassert_eq(
  a : FixedArray[Byte],
  b : FixedArray[Byte],
  what : String,
) -> Unit raise {
  assert_eq(a.length(), b.length())
  for i in 0..<a.length() {
    if a[i] != b[i] {
      fail("\{what}: byte \{i} differs: \{a[i]} vs \{b[i]}")
    }
  }
}

///|
test "alpha_composite_solid matches the emulation" {
  for len_px in 0..<=40 {
    for start in [0, 4, 12, 60] {
      for extra in [0, 4] {
        for seed in 0..<3 {
          let dest = vpixels(start / 4 + len_px + extra, seed + len_px)
          let color = vpixels(1, seed * 7 + 1)
          let src = FixedArray::makei(4, i => color[i].to_int())
          let alpha_buf = Array::from_fixed_array(vbytes(len_px + 9, seed))
          for alphas in [None, Some(0), Some(5)] {
            let d1 = dest.copy()
            let d2 = dest.copy()
            alpha_composite_solid(d1, start, 4 * len_px, src, alpha_buf, alphas)
            alpha_composite_solid_scalar(
              d2,
              start,
              4 * len_px,
              src,
              alpha_buf,
              alphas,
            )
            vassert_eq(d1, d2, "solid")
          }
        }
      }
    }
  }
}

///|
test "alpha_composite_buffer matches the emulation" {
  for len_px in 0..<=40 {
    for start in [0, 4, 12] {
      for src_start in [0, 8, 36] {
        for seed in 0..<3 {
          let dest = vpixels(start / 4 + len_px + 1, seed + len_px)
          let src = vpixels(src_start / 4 + len_px, seed + 99)
          let alpha_buf = Array::from_fixed_array(vbytes(len_px + 9, seed))
          for alphas in [None, Some(0), Some(7)] {
            let d1 = dest.copy()
            let d2 = dest.copy()
            alpha_composite_buffer(
              d1,
              start,
              4 * len_px,
              src,
              src_start,
              alpha_buf,
              alphas,
            )
            alpha_composite_buffer_scalar(
              d2,
              start,
              4 * len_px,
              src,
              src_start,
              alpha_buf,
              alphas,
            )
            vassert_eq(d1, d2, "buffer")
          }
        }
      }
    }
  }
}

///|
test "alpha_composite_buffer with the source aliasing the destination" {
  for shift in [0, 4, 8, 16, 32, 64] {
    for alphas in [None, Some(0)] {
      let b1 = vpixels(64 + 24, shift)
      let b2 = b1.copy()
      let alpha_buf = Array::from_fixed_array(vbytes(64, 3))
      // Source ahead of and behind the destination.
      alpha_composite_buffer(b1, shift, 256, b1, 0, alpha_buf, alphas)
      alpha_composite_buffer_scalar(b2, shift, 256, b2, 0, alpha_buf, alphas)
      vassert_eq(b1, b2, "aliased buffer")
      let c1 = vpixels(64 + 24, shift + 1)
      let c2 = c1.copy()
      alpha_composite_buffer(c1, 0, 256, c1, shift, alpha_buf, alphas)
      alpha_composite_buffer_scalar(c2, 0, 256, c2, shift, alpha_buf, alphas)
      vassert_eq(c1, c2, "aliased buffer")
    }
  }
}

///|
test "panic alpha_composite_solid past the destination's end" {
  let dest = vpixels(15, 1)
  alpha_composite_solid(dest, 0, 64, [1, 2, 3, 255], [], None)
}

///|
test "panic alpha_composite_solid with a short color" {
  let dest = vpixels(16, 1)
  alpha_composite_solid(dest, 0, 64, [1, 2, 3], [], None)
}

///|
test "panic alpha_composite_buffer past the source's end" {
  let dest = vpixels(8, 1)
  alpha_composite_buffer(dest, 0, 32, vpixels(7, 2), 0, [], None)
}

///|
test "panic alpha_composite_buffer past the masks' end" {
  let dest = vpixels(8, 1)
  let alphas = Array::from_fixed_array(vbytes(8, 1))
  alpha_composite_buffer(dest, 0, 32, vpixels(8, 2), 0, alphas, Some(1))
}

///|
test "panic alpha_composite_buffer with a negative start" {
  let dest = vpixels(8, 1)
  alpha_composite_buffer(dest, -4, 32, vpixels(8, 2), 0, [], None)
}

///|
fn region_of(
  buf : FixedArray[Byte],
  width : Int,
  stride : Int,
  offset : Int,
) -> Region {
  { row_idx: 0, width, height: TILE_HEIGHT, buf, stride, offset, }
}

///|
test "pack_region matches the emulation" {
  for width in 0..<=20 {
    for offset in [0, 4, 15] {
      for slack in [0, 4] {
        let stride = 4 * width + slack
        let scratch = vbytes(width * TILE_HEIGHT_COMPONENTS + 3, width)
        // Ending exactly at the last row's end, or with spare room.
        for extra in [0, 5] {
          let len = offset + 3 * stride + 4 * width + extra
          let b1 = FixedArray::make(len, b'\x5a')
          let b2 = FixedArray::make(len, b'\x5a')
          pack_region(scratch, region_of(b1, width, stride, offset))
          pack_region_scalar(scratch, region_of(b2, width, stride, offset))
          vassert_eq(b1, b2, "pack")
        }
      }
    }
  }
}

///|
test "pack_region with the scratch aliasing the region's buffer" {
  for width in [1, 3, 8] {
    for offset in [0, 4, 16] {
      let stride = 4 * width
      let n = offset + 4 * stride + 4 * width * 4 + 16
      let b1 = vbytes(n, width + offset)
      let b2 = b1.copy()
      pack_region(b1, region_of(b1, width, stride, offset))
      pack_region_scalar(b2, region_of(b2, width, stride, offset))
      vassert_eq(b1, b2, "aliased pack")
    }
  }
}

///|
test "panic pack_region past the buffer's end" {
  let scratch = vbytes(4 * TILE_HEIGHT_COMPONENTS, 1)
  let buf = FixedArray::make(3 * 16 + 15, b'\x00')
  pack_region(scratch, region_of(buf, 4, 16, 0))
}

///|
test "panic pack_region with a short scratch" {
  let scratch = vbytes(4 * TILE_HEIGHT_COMPONENTS - 1, 1)
  let buf = FixedArray::make(4 * 16, b'\x00')
  pack_region(scratch, region_of(buf, 4, 16, 0))
}

///|
test "panic pack_region with a negative offset" {
  let scratch = vbytes(4 * TILE_HEIGHT_COMPONENTS, 1)
  let buf = FixedArray::make(4 * 16 + 4, b'\x00')
  pack_region(scratch, region_of(buf, 4, 16, -4))
}

///|
test "pack_region with overlapping rows" {
  // stride < 4 * width: the rows overlap and the write order matters.
  for width in [2, 3, 5] {
    for stride in [0, 4, 4 * width - 4] {
      let scratch = FixedArray::makei(width * TILE_HEIGHT_COMPONENTS, i => {
        i.to_byte()
      })
      let len = 3 * stride + 4 * width
      let b1 = FixedArray::make(len, b'\x5a')
      let b2 = FixedArray::make(len, b'\x5a')
      pack_region(scratch, region_of(b1, width, stride, 0))
      pack_region_scalar(scratch, region_of(b2, width, stride, 0))
      vassert_eq(b1, b2, "overlapping rows")
    }
  }
}
