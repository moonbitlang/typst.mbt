// The hash inputs of the deduplication keys (upstream `Deduplicator` keys
// hashed with `typst_utils::hash128`, i.e. 128-bit SipHash-1-3 with zero
// keys). These feed exactly the byte streams of Rust's `Hash` impls (derived
// or handwritten upstream), so that the `<defs>` IDs are identical to
// upstream's:
//
// - integers are written little-endian with their width (`usize`/`isize`
//   as 8 bytes), `char` as `u32`, `bool` as `u8`;
// - enum discriminants (derived `Hash`, `mem::discriminant`) as `isize`;
// - slices/`Vec`s with a `usize` length prefix, `str` as its bytes followed
//   by `0xff`;
// - floats (`Scalar`, `AxisValue`, color components) by their bits;
// - `Bytes` (font data) as the `u128` of `hash128` of the data (`LazyHash`).

///|
fn hash_u16(h : @library.SipHasher128, v : UInt) -> Unit {
  h.write_u8((v & 0xFF).to_byte())
  h.write_u8(((v >> 8) & 0xFF).to_byte())
}

///|
fn hash_abs(h : @library.SipHasher128, v : @library.Abs) -> Unit {
  h.write_f64(v.to_raw())
}

///|
fn hash_ratio(h : @library.SipHasher128, v : @library.Ratio) -> Unit {
  h.write_f64(v.get())
}

///|
fn hash_angle(h : @library.SipHasher128, v : @library.Angle) -> Unit {
  h.write_f64(v.to_raw())
}

///|
fn hash_point(h : @library.SipHasher128, p : @library.Point) -> Unit {
  hash_abs(h, p.x)
  hash_abs(h, p.y)
}

///|
fn hash_size(
  h : @library.SipHasher128,
  s : @library.Axes[@library.Abs],
) -> Unit {
  hash_abs(h, s.x)
  hash_abs(h, s.y)
}

///|
fn hash_transform(h : @library.SipHasher128, ts : @library.Transform) -> Unit {
  hash_ratio(h, ts.sx)
  hash_ratio(h, ts.ky)
  hash_ratio(h, ts.kx)
  hash_ratio(h, ts.sy)
  hash_abs(h, ts.tx)
  hash_abs(h, ts.ty)
}

///|
/// `DedupId(char, u128)`.
fn hash_dedup_id(h : @library.SipHasher128, id : DedupId) -> Unit {
  h.write_u32(id.kind.to_int().reinterpret_as_uint())
  h.write_u128(id.hash)
}

///|
/// The byte streams of colors, color spaces, spot colorants, gradients,
/// curves and fonts are those of their [@library.Fingerprint] impls
/// (`library/visualize_hash.mbt`).
fn hash_curve(h : @library.SipHasher128, curve : @library.Curve) -> Unit {
  h.write(curve)
}

///|
fn hash_color(h : @library.SipHasher128, color : @library.Color) -> Unit {
  h.write(color)
}

///|
fn hash_gradient(
  h : @library.SipHasher128,
  gradient : @library.Gradient,
) -> Unit {
  h.write(gradient)
}

///|
/// `impl Hash for FontInstance`: the font (its data and index), then the
/// variations (`SmallVec<[(Tag, AxisValue); 2]>`).
fn hash_font(h : @library.SipHasher128, font : @library.FontInstance) -> Unit {
  h.write(font)
}
