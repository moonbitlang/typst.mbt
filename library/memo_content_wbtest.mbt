// Results kept by content (`memo_content.mbt`) and the first of them, the
// decoded raster images (`RasterImage::new`): what such a cache can get
// wrong.

///|
/// A PNG of `width` x `height` RGB pixels, each `(seed + i) * k` in turn.
fn memo_test_png(width : Int, height : Int, seed : Int) -> Bytes {
  let pixels = Bytes::makei(width * height * 3, i => ((seed + i) * 7).to_byte())
  @codecs.encode_png(pixels[:], width, height, Rgb)
}

///|
/// Starts from empty caches, whatever ran before.
fn memo_test_reset() -> Unit {
  set_layout_memo_enabled(true)
  raster_image_cache.evict(0)
  data_hashes.clear()
}

///|
/// The error of decoding, if it fails.
fn memo_test_error(
  data : Bytes,
  format : RasterFormat,
  icc : Smart[Bytes],
) -> HintedString? {
  try RasterImage::new(data, format, icc) catch {
    HintedError(error) => Some(error)
  } noraise {
    _ => None
  }
}

///|
/// A copy of the data in another object.
fn memo_test_copy(data : Bytes) -> Bytes {
  Bytes::makei(data.length(), i => data[i])
}

///|
test "raster images: the same data is decoded once, also from another object" {
  memo_test_reset()
  let data = memo_test_png(20, 20, 1)
  let a = RasterImage::new(data, Exchange(Png), Auto)
  let b = RasterImage::new(data, Exchange(Png), Auto)
  // One image, shared like upstream's `Arc`.
  assert_true(physical_equal(a, b))
  assert_eq(raster_image_cache.length(), 1)
  // The same bytes read again (another path, another compilation).
  let copy = memo_test_copy(data)
  assert_false(physical_equal(copy, data))
  let c = RasterImage::new(copy, Exchange(Png), Auto)
  assert_true(physical_equal(a, c))
  assert_eq(raster_image_cache.length(), 1)
}

///|
test "raster images: different images of equal dimensions and length" {
  memo_test_reset()
  let one = memo_test_png(20, 20, 1)
  let two = memo_test_png(20, 20, 2)
  let a = RasterImage::new(one, Exchange(Png), Auto)
  let b = RasterImage::new(two, Exchange(Png), Auto)
  assert_true(a.width() == b.width() && a.height() == b.height())
  assert_false(physical_equal(a, b))
  assert_true(a.dynamic().buf != b.dynamic().buf)
  assert_true(a.data() == one && b.data() == two)
  assert_eq(raster_image_cache.length(), 2)
  // Raw pixels that differ in one byte in the middle: the objects are
  // filed under the same probe, and their hashes differ.
  let x = Bytes::makei(1200, i => i.to_byte())
  let y = Bytes::makei(1200, i => if i == 601 { b'\xFF' } else { i.to_byte() })
  assert_eq(data_probe(x), data_probe(y))
  assert_true(data_hash(x) != data_hash(y))
  let format = RasterFormat::Pixel({
    encoding: Rgb8,
    width: U32(20),
    height: U32(20),
  })
  let px = RasterImage::new(x, format, Auto)
  let py = RasterImage::new(y, format, Auto)
  assert_true(px.dynamic().buf == x && py.dynamic().buf == y)
}

///|
test "raster images: the format and the ICC profile are part of the key" {
  memo_test_reset()
  // The same 1200 bytes as 20x20 RGB pixels, as 40x30 and 30x40 gray
  // pixels and as 30x20 gray pixels with alpha.
  let pixels = Bytes::makei(1200, i => (i * 3).to_byte())
  let pixel = (encoding : PixelEncoding, width : Int, height : Int) => {
    RasterFormat::Pixel({
      encoding,
      width: U32(width.to_int64()),
      height: U32(height.to_int64()),
    })
  }
  let rgb = RasterImage::new(pixels, pixel(Rgb8, 20, 20), Auto)
  let wide = RasterImage::new(pixels, pixel(Luma8, 40, 30), Auto)
  let tall = RasterImage::new(pixels, pixel(Luma8, 30, 40), Auto)
  let alpha = RasterImage::new(pixels, pixel(Lumaa8, 30, 20), Auto)
  assert_true(rgb.width() == 20 && rgb.height() == 20 && rgb.color() is Rgb8)
  assert_true(wide.width() == 40 && wide.height() == 30 && wide.color() is L8)
  assert_true(tall.width() == 30 && tall.height() == 40 && tall.color() is L8)
  assert_true(
    alpha.width() == 30 && alpha.height() == 20 && alpha.color() is La8,
  )
  assert_eq(raster_image_cache.length(), 4)
  // A PNG as a PNG, and (wrongly) as a JPEG: an error of its own.
  let png = memo_test_png(20, 20, 3)
  let image = RasterImage::new(png, Exchange(Png), Auto)
  assert_true(image.format() == Exchange(Png))
  assert_true(memo_test_error(png, Exchange(Jpg), Auto) is Some(_))
  assert_true(physical_equal(image, RasterImage::new(png, Exchange(Png), Auto)))
  // The profile that was passed: none, one, another, the first again in
  // another object.
  let icc1 = Bytes::makei(300, i => i.to_byte())
  let icc2 = Bytes::makei(300, i => (i + 1).to_byte())
  let with1 = RasterImage::new(png, Exchange(Png), Custom(icc1))
  let with2 = RasterImage::new(png, Exchange(Png), Custom(icc2))
  let again = RasterImage::new(png, Exchange(Png), Custom(memo_test_copy(icc1)))
  assert_true(image.icc() is None)
  assert_true(with1.icc() == Some(icc1))
  assert_true(with2.icc() == Some(icc2))
  assert_true(physical_equal(with1, again))
  assert_false(physical_equal(with1, image))
  // A short profile is hashed on every call (not filed by identity).
  let short1 = RasterImage::new(png, Exchange(Png), Custom(b"abc"))
  let short2 = RasterImage::new(png, Exchange(Png), Custom(b"abd"))
  assert_true(short1.icc() == Some(b"abc") && short2.icc() == Some(b"abd"))
  // An empty profile is not `auto`.
  let empty = RasterImage::new(png, Exchange(Png), Custom(b""))
  assert_true(empty.icc() == Some(b""))
  assert_false(physical_equal(empty, image))
}

///|
test "raster images: a broken image used twice" {
  memo_test_reset()
  let png = memo_test_png(20, 20, 4)
  // Cut in the middle of the image data.
  let broken = Bytes::makei(png.length() - 40, i => png[i])
  let message = (data : Bytes) => {
    try RasterImage::new(data, Exchange(Png), Auto) catch {
      HintedError(error) => {
        // What a caller may do with its error.
        let text = error.message
        error.hint("a hint of the first caller")
        text
      }
    } noraise {
      _ => "decoded"
    }
  }
  let first = message(broken)
  assert_true(first.has_prefix("failed to decode image ("))
  // The second use reports the same, without the first caller's hint.
  guard memo_test_error(broken, Exchange(Png), Auto) is Some(error) else {
    fail("decoded")
  }
  assert_eq(error.message, first)
  assert_eq(error.hints.length(), 0)
  // It was kept, like comemo keeps the `Result`.
  assert_eq(raster_image_cache.length(), 1)
  // The same with memoization off.
  set_layout_memo_enabled(false)
  assert_eq(message(broken), first)
  assert_eq(message(memo_test_copy(broken)), first)
  set_layout_memo_enabled(true)
  // The whole image still decodes.
  assert_eq(message(png), "decoded")
  // Errors of pixel formats.
  let zero = RasterFormat::Pixel({
    encoding: Rgb8,
    width: U32(0),
    height: U32(2),
  })
  guard memo_test_error(b"", zero, Auto) is Some(error) else {
    fail("accepted")
  }
  assert_eq(error.message, "zero-sized images are not allowed")
}

///|
test "raster images: with memoization off nothing is kept or found" {
  memo_test_reset()
  let data = memo_test_png(20, 20, 5)
  let kept = RasterImage::new(data, Exchange(Png), Auto)
  set_layout_memo_enabled(false)
  let a = RasterImage::new(data, Exchange(Png), Auto)
  let b = RasterImage::new(data, Exchange(Png), Auto)
  set_layout_memo_enabled(true)
  assert_false(physical_equal(a, b))
  assert_false(physical_equal(a, kept))
  // Equal all the same (`Eq for RasterImage`: data, format, profile), and
  // the same pixels.
  assert_true(a == b && a == kept)
  assert_true(a.dynamic().buf == kept.dynamic().buf)
  assert_eq(raster_image_cache.length(), 1)
  assert_true(physical_equal(kept, RasterImage::new(data, Exchange(Png), Auto)))
}

///|
test "evict: results kept by content age like comemo's" {
  memo_test_reset()
  let one = memo_test_png(20, 20, 6)
  let two = memo_test_png(20, 20, 7)
  let a = RasterImage::new(one, Exchange(Png), Auto)
  let _ = RasterImage::new(two, Exchange(Png), Auto)
  assert_eq(raster_image_cache.length(), 2)
  // Used in every "compilation": kept. Not used for more than `max_age`
  // calls: dropped.
  evict(2)
  assert_true(physical_equal(a, RasterImage::new(one, Exchange(Png), Auto)))
  evict(2)
  assert_eq(raster_image_cache.length(), 2)
  assert_true(physical_equal(a, RasterImage::new(one, Exchange(Png), Auto)))
  evict(2)
  assert_eq(raster_image_cache.length(), 1)
  assert_true(physical_equal(a, RasterImage::new(one, Exchange(Png), Auto)))
  // Stale after `evict`: a dropped image is decoded again, to an equal one.
  let again = RasterImage::new(two, Exchange(Png), Auto)
  assert_eq(again.data(), two)
  assert_eq(raster_image_cache.length(), 2)
  // `evict(0)` drops everything.
  evict(0)
  assert_eq(raster_image_cache.length(), 0)
  let b = RasterImage::new(one, Exchange(Png), Auto)
  assert_false(physical_equal(a, b))
  assert_true(a == b && a.dynamic().buf == b.dynamic().buf)
}

///|
test "data_hash: once per object, dropped when the object is not asked for" {
  memo_test_reset()
  let data = Bytes::makei(4096, i => (i * 5).to_byte())
  let copy = memo_test_copy(data)
  let expected = data_hash_uncached(data)
  assert_eq(data_hash(data), expected)
  assert_eq(data_hash(data), expected)
  assert_eq(data_hash(copy), expected)
  // Two objects under one probe.
  assert_eq(data_hashes.length(), 1)
  assert_eq(data_hashes.get(data_probe(data)).map(b => b.length()), Some(2))
  // What `font_data_hash` and the fingerprint of an image write.
  let h = SipHasher128::new()
  h.write_data(data)
  assert_eq(h.finish128(), expected)
  // Short data is not filed.
  assert_eq(data_hash(b"short"), data_hash_uncached(b"short"))
  assert_eq(data_hashes.length(), 1)
  // The table is swept when a compilation starts and by `evict`; an entry
  // goes with the third sweep after it was asked for. A watch session:
  // compile, evict, compile, evict, ...
  let objects = () => {
    data_hashes.get(data_probe(data)).map(b => b.length()).unwrap_or(0)
  }
  // The first compilation used both objects (above).
  evict(10)
  // The second one reads the file again: `copy` is the new object, `data`
  // is not asked for any more.
  let mut inside = 0
  with_layout_memo(() => {
    ignore(data_hash(copy))
    // Not a compilation of its own: nothing is swept inside one.
    with_layout_memo(() => ())
    inside = objects()
  })
  assert_eq(inside, 2)
  // With the `evict` after it, `data` goes.
  evict(10)
  assert_eq(objects(), 1)
  // An object that every compilation asks for stays (a host that hands out
  // the same `Bytes` again).
  for _ in 0..<5 {
    with_layout_memo(() => ignore(data_hash(copy)))
    evict(10)
  }
  assert_eq(objects(), 1)
  // Exports without a compilation, each with a copy of its own (a glyph's
  // bitmap) and an `evict` after it: bounded.
  for _ in 0..<10 {
    ignore(data_hash(memo_test_copy(data)))
    evict(10)
  }
  assert_true(objects() <= 3)
  // Compilations without `evict`: bounded too.
  for _ in 0..<10 {
    with_layout_memo(() => ignore(data_hash(memo_test_copy(data))))
  }
  assert_true(objects() <= 3)
  // `evict(0)` drops all of them.
  evict(0)
  assert_eq(data_hashes.length(), 0)
  assert_eq(data_hash(data), expected)
}

///|
test "ContentCache: ages, replacement, evictors" {
  let cache : ContentCache[String] = ContentCache::new()
  let key = (i : Int) => hash128(i)
  assert_true(cache.get(key(1)) is None)
  cache.insert(key(1), "one")
  cache.insert(key(2), "two")
  cache.insert(key(1), "uno")
  assert_eq(cache.get(key(1)), Some("uno"))
  assert_eq(cache.length(), 2)
  // It registered itself: the library's `evict` reaches it.
  evict(1)
  assert_eq(cache.length(), 2)
  ignore(cache.get(key(2)))
  evict(1)
  assert_eq(cache.length(), 1)
  assert_eq(cache.get(key(2)), Some("two"))
  evict(0)
  assert_eq(cache.length(), 0)
}
