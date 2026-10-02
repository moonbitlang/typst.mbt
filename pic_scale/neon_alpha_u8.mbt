// Port of pic-scale's `neon/alpha_u8.rs`: `neon_premultiply_alpha_rgba` and
// `neon_unpremultiply_alpha_rgba` with the `NeonDisassociateAlphaFast`
// executor (chosen for `WorkloadStrategy::PreferSpeed` when the CPU has
// `rdm`). The 64/16-byte blocks and the zero-padded tail compute every pixel
// the same way, so they are emulated pixel by pixel.

///|
/// `neon_div_by_255_n`: `vqrshrn_n_u16::<8>(vrsraq_n_u16::<8>(v, v))`.
fn neon_div_by_255(v : Int) -> Int {
  let t = v + ((v + 128) >> 8)
  let r = (t + 128) >> 8
  if r > 255 {
    255
  } else {
    r
  }
}

///|
/// `neon_premultiply_alpha_rgba` on one row of `width` pixels: colors are
/// multiplied by alpha (`vmull_u8` + `neon_div_by_255_n`), alpha is kept.
fn neon_premultiply_alpha_rgba(
  dst : FixedArray[Byte],
  dst_offset : Int,
  src : FixedArray[Byte],
  src_offset : Int,
  width : Int,
) -> Unit {
  for x in 0..<width {
    let s = src_offset + x * 4
    let d = dst_offset + x * 4
    let a = src[s + 3].to_int()
    dst[d] = neon_div_by_255(src[s].to_int() * a).to_byte()
    dst[d + 1] = neon_div_by_255(src[s + 1].to_int() * a).to_byte()
    dst[d + 2] = neon_div_by_255(src[s + 2].to_int() * a).to_byte()
    dst[d + 3] = src[s + 3]
  }
}

///|
/// `vcvtq_s32_f32` (round toward zero, saturating) of a positive value.
fn cvt_s32_f32(v : Float) -> Int {
  let d = v.to_double()
  if d >= 2147483648.0 {
    0x7fffffff
  } else {
    d.to_int()
  }
}

///|
/// `NeonDisassociateAlphaFast::disassociate` on one row of `width` pixels:
/// the reciprocal `Q / a` (`Q = ((1 << 31) - 1) as f32`, i.e. 2^31) is
/// converted to Q0.31 and applied to `c * 255` with `vqrdmulhq_s32`, then
/// narrowed with `vqmovun_s32` + `vqmovn_u16`; pixels with zero alpha become
/// transparent black, alpha is kept.
fn neon_unpremultiply_alpha_rgba(
  in_place : FixedArray[Byte],
  offset : Int,
  width : Int,
) -> Unit {
  let q : Float = Float::from_int(0x7fffffff)
  for x in 0..<width {
    let p = offset + x * 4
    let a = in_place[p + 3].to_int()
    if a == 0 {
      in_place[p] = b'\x00'
      in_place[p + 1] = b'\x00'
      in_place[p + 2] = b'\x00'
      continue
    }
    let reciprocal = cvt_s32_f32(q / Float::from_int(a))
    for c in 0..<3 {
      let v = vqrdmulh_s32(in_place[p + c].to_int() * 255, reciprocal)
      // vqmovun_s32 then vqmovn_u16
      let v = if v < 0 { 0 } else if v > 65535 { 65535 } else { v }
      let v = if v > 255 { 255 } else { v }
      in_place[p + c] = v.to_byte()
    }
  }
}
