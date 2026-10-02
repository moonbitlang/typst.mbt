// Port of `hayro-interpret/src/shading.rs`: PDF shadings.
//
// TODO: placeholder; the shading types are not ported yet, so `Shading::new`
// always fails (shadings are not drawn).

///|
/// A PDF shading.
pub(all) struct Shading {
  priv cache_key : U128
  /// The color space of the shading.
  color_space : ColorSpace
  /// A clip path that should be applied to the shading.
  clip_path : @kurbo.BezPath?
  /// The background color of the shading.
  background : Array[Float]?
}

///|
fn Shading::new(
  _dict : @hayro_syntax.Dict,
  _stream : @hayro_syntax.Stream?,
  _cache : Cache,
) -> Shading? {
  None
}

///|
pub impl CacheKey for Shading with fn cache_key(self) {
  self.cache_key
}
