// Port of `hayro-syntax/src/filter/jbig2.rs` (on `hayro/jbig2`).

///|
/// Decode JBIG2 data from a PDF stream.
///
/// The `params` dictionary may contain a `JBIG2Globals` entry pointing to
/// a stream with shared symbol dictionaries.
fn jbig2_decode(
  data : BytesView,
  params : Dict,
  image_params : ImageDecodeParams,
) -> FilterResult? {
  // TODO(port): hayro/jbig2 is being ported.
  ignore((data, params, image_params))
  None
}
