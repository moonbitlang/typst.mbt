// The compressed content streams of a document, kept between exports
// (krilla's `stream.rs`: `deflate_encode_memoized`).
//
// The exporter (`moonbitlang/pdflite/export`) keeps nothing between
// documents: what krilla memoizes with comemo, its host looks up
// (`@export.Memo`). The lookup here is krilla's memoized function, kept by
// the bytes of the stream (`library/memo_content.mbt`). The compressor is
// the exporter's own, which it hands to the lookup, so a file is byte for
// byte what the exporter alone writes.

///|
/// The compressed content streams (upstream `#[comemo::memoize]` on
/// krilla's `deflate_encode_memoized`), see [deflate_encode_memoized].
let deflate_cache : @library.ContentCache[Bytes] = @library.ContentCache::new()

///|
/// krilla's `deflate_encode_memoized` (`stream.rs:435`,
/// `#[comemo::memoize]`): the filter of
/// `FilterStreamBuilder::new_from_content_stream`, so the content streams
/// of pages, form XObjects, tiling patterns and the glyphs of Type 3 fonts,
/// the ToUnicode CMaps and the PostScript functions of gradients, where
/// content streams are compressed at all (not with `pretty`). Binary data
/// (font programs, CID sets, ICC profiles, embedded files: krilla's
/// `deflate_encode`) is not memoized upstream and is not asked for here:
/// the exporter compresses it for every document.
///
/// `deflate` is krilla's `deflate_encode`: the exporter's compression, the
/// same function of the data in every call, which is why it is not part of
/// the key. The key is what comemo hashes, the one argument: the bytes of
/// the stream ([@library.transient_data_hash]: a stream is made for one
/// export, so its hash is not filed under the object as
/// [@library.data_hash] does). The result is immutable. Kept beyond the
/// export (`library/memo_content.mbt`): in the next export of `typst watch`
/// a page whose content stream is the bytes it was is not compressed again,
/// and compressing is the largest single part of what an export costs.
/// (The names of a page's resources and the marked content IDs of its tags
/// are numbered per page, in krilla and here. The glyphs of a font are
/// numbered in the order of their first use in the document, so an edit
/// that brings a new glyph changes the streams of the pages behind it that
/// use glyphs numbered after it, upstream too.)
///
/// With memoization off nothing is looked up or kept, and the bytes are
/// the same: a result is `deflate` of its key's data, whenever it was made.
fn deflate_encode_memoized(data : Bytes, deflate : (Bytes) -> Bytes) -> Bytes {
  if !@library.content_memo_enabled() {
    return deflate(data)
  }
  let key = @library.transient_data_hash(data)
  deflate_memo_counts[0] += 1
  match deflate_cache.get(key) {
    Some(encoded) => encoded
    None => {
      deflate_memo_counts[1] += 1
      let encoded = deflate(data)
      deflate_cache.insert(key, encoded)
      encoded
    }
  }
}

///|
/// The calls of [deflate_encode_memoized] with memoization on, and those
/// among them that compressed (the others were found).
let deflate_memo_counts : FixedArray[Int32] = [0, 0]

///|
/// The number of content streams that an export found compressed and that
/// it compressed, in this process, with memoization on (for tests and
/// measurements, like `@layout.block_memo_stats`).
pub fn deflate_memo_stats() -> (Int32, Int32) {
  (deflate_memo_counts[0] - deflate_memo_counts[1], deflate_memo_counts[1])
}
