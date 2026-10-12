// The subsets of fonts, kept between exports (krilla's `text/cid.rs`:
// `subset_font`).
//
// Like the compressed content streams (`deflate.mbt`): krilla memoizes the
// function with comemo, the exporter keeps nothing between documents and
// asks its host (`@export.Memo`), and the lookup here keeps the subsets by
// what they are a function of (`library/memo_content.mbt`).

///|
/// The subsets of fonts (upstream `#[comemo::memoize]` on krilla's
/// `subset_font`), see [subset_font_memoized].
let subset_cache : @library.ContentCache[@export.FontSubset] = @library.ContentCache::new()

///|
/// krilla's `subset_font` (`text/cid.rs:437`, `#[comemo::memoize]`): the
/// subset of a font that a document embeds for the glyphs it uses, with
/// the bounding box of their outlines, which is drawn glyph by glyph
/// (krilla memoizes that too, `compute_bbox`, by the subset and the glyph:
/// found exactly when the subset is). A document whose text has the glyphs
/// it had, in the order of their first use, embeds the subsets it embedded:
/// in the next export of `typst watch` they are not made again, and making
/// them is half of what an export of a document with several fonts costs
/// once its content streams are kept (`bench/showcase.typ`).
///
/// The key. krilla hashes its two arguments: the font, as its `FontInfo`
/// (the index, the checksum of the `head` table, the length of the data,
/// the variation coordinates and metrics: not the data, which "can be
/// dozens of megabytes"), and the glyph remapper. Here the font is the
/// font object of the engine that the exporter's font was made of
/// ([@library.Font::serial], as the tracked world identifies a font:
/// hashing the data of a system font collection takes 24 ms), with the
/// variation coordinates of the exporter's font; and the glyphs are the
/// remapper's, the glyph IDs that the document uses in the order of the
/// subset, which is all a remapper holds (the components of composite
/// glyphs are the subsetter's to add, the same for the same glyphs). That
/// is finer than krilla's key where it differs (two
/// font objects of the same data are two fonts, and a world that wants
/// subsets found again hands out the font objects it has), and it never
/// takes two fonts for one. A font that has no font object of the engine,
/// one that only the text of an SVG image uses, is subset for every
/// export.
///
/// What is kept is the subset, which nothing writes to. An error is not
/// kept, where comemo keeps the `Result`: it names the exporter's font,
/// an object of one export, which [finish] finds the engine's font by.
/// Computed again, the error is the same error for this export's font.
///
/// With memoization off nothing is looked up or kept, and a subset is what
/// `compute` gives, whenever it was made.
fn subset_font_memoized(
  fonts : Array[(@export.Font, @library.FontInstance)],
  font : @export.Font,
  glyphs : ArrayView[Int32],
  compute : () -> @export.FontSubset raise @export.ExportError,
) -> @export.FontSubset raise @export.ExportError {
  if !@library.content_memo_enabled() {
    return compute()
  }
  let mut instance : @library.FontInstance? = None
  for entry in fonts {
    if physical_equal(entry.0, font) {
      instance = Some(entry.1)
      break
    }
  }
  guard instance is Some(instance) else { return compute() }
  let state = @library.SipHasher128::new()
  state.write_usize(instance.font().serial())
  let variations = font.variation_coordinates()
  state.write_usize(variations.length())
  for i in 0..<variations.length() {
    let (tag, value) = variations[i]
    state.write_bytes(tag.get()[:])
    state.write_u32(value.reinterpret_as_uint())
  }
  state.write_usize(glyphs.length())
  for i in 0..<glyphs.length() {
    state.write_u32(glyphs[i].reinterpret_as_uint())
  }
  let key = state.finish128()
  subset_memo_counts[0] += 1
  match subset_cache.get(key) {
    Some(subset) => subset
    None => {
      subset_memo_counts[1] += 1
      let subset = compute()
      subset_cache.insert(key, subset)
      subset
    }
  }
}

///|
/// The calls of [subset_font_memoized] with memoization on for a font of
/// the engine, and those among them that made the subset (the others found
/// it).
let subset_memo_counts : FixedArray[Int32] = [0, 0]

///|
/// The number of font subsets that an export found and that it made, in
/// this process, with memoization on (for tests and measurements, like
/// [deflate_memo_stats]).
pub fn subset_memo_stats() -> (Int32, Int32) {
  (subset_memo_counts[0] - subset_memo_counts[1], subset_memo_counts[1])
}

///|
/// What is kept for the exporter between the documents of this package:
/// the compressed content streams ([deflate_encode_memoized]) and the
/// subsets of the fonts ([subset_font_memoized]). `fonts` is the table of
/// the export that says which font of the engine a font of the exporter
/// is (`GlobalContext.fonts_backward`).
fn export_memo(
  fonts : Array[(@export.Font, @library.FontInstance)],
) -> @export.Memo {
  @export.Memo(deflate=deflate_encode_memoized, subset=(font, glyphs, compute) => {
    subset_font_memoized(fonts, font, glyphs, compute)
  })
}
