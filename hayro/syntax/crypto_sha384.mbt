// Port of `hayro-syntax/src/crypto/sha384.rs`.
//
// Ported from <https://github.com/mozilla/pdf.js/blob/master/src/core/calculate_sha_other.js>.

///|
/// Upstream `sha384::calculate`. Returns 48 bytes.
fn sha384_calculate(data : BytesView) -> Bytes {
  let h : FixedArray[UInt64] = [
    0xcbbb9d5dc1059ed8, 0x629a292a367cd507, 0x9159015a3070dd17, 0x152fecd8f70e5939,
    0x67332667ffc00b31, 0x8eb44a8768581511, 0xdb0c2e0d64f98fa7, 0x47b5481dbefa4fa4,
  ]
  sha512_calculate_with_initial_values(data, h)
  let result : Array[Byte] = Array(capacity=48)
  for i in 0..<6 {
    write_u64_be(result, h[i])
  }
  Bytes::from_array(result[:])
}
