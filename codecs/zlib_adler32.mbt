// Port of zlib-rs 0.6.8 `src/adler32.rs` / `src/adler32/generic.rs`. The SIMD
// variants (NEON on aarch64) compute the same checksum.

///|
/// Largest prime smaller than 65536.
const ADLER_BASE : UInt = 65521

///|
/// NMAX is the largest n such that 255n(n+1)/2 + (n+1)(BASE-1) <= 2^32-1.
const ADLER_NMAX : Int = 5552

///|
/// The initial value of an Adler-32 checksum.
const ADLER32_INITIAL_VALUE : UInt = 1

///|
/// Updates the Adler-32 checksum `start_checksum` with `data` (upstream
/// `adler32`).
fn adler32(start_checksum : UInt, data : BytesView) -> UInt {
  // split Adler-32 into component sums
  let mut sum2 = (start_checksum >> 16) & 0xffff
  let mut adler = start_checksum & 0xffff
  let len = data.length()
  let mut i = 0
  while i < len {
    let n = @cmp.minimum(ADLER_NMAX, len - i)
    for j in i..<(i + n) {
      adler += data[j].to_uint()
      sum2 += adler
    }
    adler %= ADLER_BASE
    sum2 %= ADLER_BASE
    i += n
  }
  adler | (sum2 << 16)
}
