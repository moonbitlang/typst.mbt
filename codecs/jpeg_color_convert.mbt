// Port of `zune-jpeg` (v0.5.15) `src/color_convert.rs` and
// `src/color_convert/scalar.rs`: YCbCr to RGB conversion of 16 samples.
//
// On aarch64 upstream uses `ycbcr_to_rgb_neon`/`ycbcr_to_rgba_neon`; they
// compute the same BT.601 14-bit fixed point sums (widening multiply-adds,
// a truncating saturating shift right by 14 and saturation to u8, i.e. the
// scalar `clamp(x >> 14)`), so the scalar code is ported.

///|
// Bt.601 Full Range inverse coefficients computed with 14 bits of precision
// with MPFR.
const Y_CF : Int = 16384

///|
const CR_CF : Int = 22970

///|
const CB_CF : Int = 29032

///|
const C_G_CR_COEF_1 : Int = -11700

///|
const C_G_CB_COEF_2 : Int = -5638

///|
const YUV_PREC : Int = 14

///|
// Rounding const for YUV -> RGB conversion: floating equivalent 0.499(9).
const YUV_RND : Int = (1 << (YUV_PREC - 1)) - 1

///|
/// Convert 16 YCbCr samples (`y[yo..yo + 16]` etc.) to RGB (`num_components
/// == 3`) or RGBA (`4`) at `output[out_pos..]`.
fn ycbcr_to_rgb_16(
  y : FixedArray[Int],
  yo : Int,
  cb : FixedArray[Int],
  cbo : Int,
  cr : FixedArray[Int],
  cro : Int,
  output : FixedArray[Byte],
  out_pos : Int,
  num_components : Int,
) -> Unit {
  for i in 0..<16 {
    let cr = i16(cr[cro + i] - 128)
    let cb = i16(cb[cbo + i] - 128)
    let y0 = y[yo + i] * Y_CF + YUV_RND
    let r = (y0 + cr * CR_CF) >> YUV_PREC
    let g = (y0 + cr * C_G_CR_COEF_1 + cb * C_G_CB_COEF_2) >> YUV_PREC
    let b = (y0 + cb * CB_CF) >> YUV_PREC
    let o = out_pos + i * num_components
    output[o] = clamp255(r).to_byte()
    output[o + 1] = clamp255(g).to_byte()
    output[o + 2] = clamp255(b).to_byte()
    if num_components == 4 {
      output[o + 3] = b'\xFF'
    }
  }
}
