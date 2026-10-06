// Port of `hayro-interpret/src/cache.rs`.

///|
/// A value stored in the object cache (upstream stores `Box<dyn Any>` and
/// downcasts on access; the cached types are enumerated here).
priv enum CacheValue {
  ColorSpace(ColorSpace?)
  ColorSpaceType(ColorSpaceType?)
}

///|
/// A cache for objects that are expensive to construct.
pub struct Cache {
  priv map : Map[U128, CacheValue]
}

///|
/// Create a new cache.
pub fn Cache::new() -> Cache {
  { map: {}, }
}

///|
/// Get the cached color space for `id`, or construct and cache it.
fn Cache::get_or_insert_color_space(
  self : Cache,
  id : U128,
  f : () -> ColorSpace?,
) -> ColorSpace? {
  match self.map.get(id) {
    Some(ColorSpace(v)) => v
    // The cached value has a different type (a failed downcast).
    Some(_) => None
    None => {
      let val = f()
      self.map[id] = ColorSpace(val)
      val
    }
  }
}

///|
/// Get the cached color space type for `id`, or construct and cache it.
fn Cache::get_or_insert_color_space_type(
  self : Cache,
  id : U128,
  f : () -> ColorSpaceType?,
) -> ColorSpaceType? {
  match self.map.get(id) {
    Some(ColorSpaceType(v)) => v
    Some(_) => None
    None => {
      let val = f()
      self.map[id] = ColorSpaceType(val)
      val
    }
  }
}

///|
/// A trait for objects that can generate a unique cache key.
pub(open) trait CacheKey {
  /// Returns the cache key for this object.
  fn cache_key(Self) -> U128
}

///|
/// The cache key of a pair (upstream `impl CacheKey for (T, U)`).
pub fn[T : CacheKey, U : CacheKey] pair_cache_key(a : T, b : U) -> U128 {
  hash128_keys([CacheKey::cache_key(a), CacheKey::cache_key(b)])
}

///|
pub impl CacheKey for @hayro_syntax.Dict with fn cache_key(self) {
  hash128(h => h.write_bytes(self.data()))
}

///|
pub impl CacheKey for @hayro_syntax.Stream with fn cache_key(self) {
  CacheKey::cache_key(self.dict())
}

///|
pub impl CacheKey for Bool with fn cache_key(self) {
  hash128(h => h.write_u8(if self { b'\x01' } else { b'\x00' }))
}

///|
pub impl CacheKey for @hayro_syntax.Number with fn cache_key(self) {
  hash128(h => h.write_f64(self.as_f64()))
}

///|
pub impl CacheKey for @hayro_syntax.PdfString with fn cache_key(self) {
  hash128(h => h.write_bytes(self.as_bytes()))
}

///|
pub impl CacheKey for @hayro_syntax.Name with fn cache_key(self) {
  hash128(h => {
    h.write_u8(b'N')
    h.write_bytes(self.as_bytes())
  })
}

///|
pub impl CacheKey for @hayro_syntax.PdfArray with fn cache_key(self) {
  hash128(h => h.write_bytes(self.data()))
}

///|
pub impl CacheKey for @hayro_syntax.Object with fn cache_key(self) {
  match self {
    Null => hash128(h => h.write_u8(b'\x00'))
    Boolean(b) => CacheKey::cache_key(b)
    Number(n) => CacheKey::cache_key(n)
    String(s) => CacheKey::cache_key(s)
    Name(n) => CacheKey::cache_key(n)
    Dict(d) => CacheKey::cache_key(d)
    Array(a) => CacheKey::cache_key(a)
    Stream(s) => CacheKey::cache_key(s)
  }
}

///|
pub impl CacheKey for @hayro_syntax.ObjRef with fn cache_key(self) {
  hash128(h => {
    h.write_u32(self.obj_number.reinterpret_as_uint())
    h.write_u32(self.gen_number.reinterpret_as_uint())
  })
}

///|
pub impl[T : CacheKey] CacheKey for @hayro_syntax.MaybeRef[T] with fn cache_key(
  self,
) {
  match self {
    Ref(r) => CacheKey::cache_key(r)
    NotRef(o) => CacheKey::cache_key(o)
  }
}

///|
pub impl CacheKey for @kurbo.Affine with fn cache_key(self) {
  let c = self.as_coeffs()
  hash128(h => {
    for v in c {
      h.write_f64(v)
    }
  })
}

///|
pub impl CacheKey for @kurbo.Rect with fn cache_key(self) {
  hash128(h => {
    h.write_f64(self.x0)
    h.write_f64(self.y0)
    h.write_f64(self.x1)
    h.write_f64(self.y1)
  })
}

///|
pub impl CacheKey for U128 with fn cache_key(self) {
  hash128(h => h.write_u128(self))
}

///|
#deprecated("call as `CacheKey::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend U128 with CacheKey::{cache_key}
