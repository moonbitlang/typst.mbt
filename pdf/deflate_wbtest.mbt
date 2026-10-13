// The compressed content streams that are kept by their bytes
// (`deflate_encode_memoized`, `library/memo_content.mbt`): what a result is
// found by, that it is the compression of its data whenever it was made,
// and how long it stays.

///|
/// Data that compresses to something: other bytes for every seed.
fn deflate_test_data(n : Int32, seed : Int32) -> Bytes {
  Bytes::makei(n, i => ((i / 7 * seed + i % 5 * 31 + seed) % 251).to_byte())
}

///|
/// The exporter's compression (what it hands to the lookup).
fn deflate_encode(data : Bytes) -> Bytes {
  @flate.pdf_flate_encode(data)
}

///|
/// An empty cache, memoization on.
fn deflate_test_reset() -> Unit {
  @library.set_layout_memo_enabled(true)
  @library.evict(0)
}

///|
test "deflate: a content stream is found by its bytes" {
  deflate_test_reset()
  let a = deflate_test_data(4000, 3)
  let (found, computed) = deflate_memo_stats()
  let first = deflate_encode_memoized(a, deflate_encode)
  assert_eq(deflate_cache.length(), 1)
  assert_eq(deflate_memo_stats(), (found, computed + 1))
  // What is kept is the stream that the exporter's own compression gives
  // (what a document without a host writes), a zlib stream of the data.
  assert_eq(first, deflate_encode(a))
  assert_eq(first, @flate.pdf_flate_encode(a))
  assert_eq(@codecs.zlib_decompress(first), a)
  assert_true(first.length() < a.length())
  // The same object again, and the same bytes in another object (the
  // stream of a page is made anew by every export).
  assert_true(physical_equal(deflate_encode_memoized(a, deflate_encode), first))
  let again = deflate_test_data(4000, 3)
  assert_false(physical_equal(again, a))
  assert_true(
    physical_equal(deflate_encode_memoized(again, deflate_encode), first),
  )
  assert_eq(deflate_cache.length(), 1)
  assert_eq(deflate_memo_stats(), (found + 2, computed + 1))
  // Other bytes are another stream: one byte more, one byte less, one byte
  // changed (at the start, in the middle, at the end).
  let variants = [
    deflate_test_data(4001, 3),
    deflate_test_data(3999, 3),
    Bytes::makei(4000, i => {
      if i == 0 {
        (a[i].to_int() ^ 1).to_byte()
      } else {
        a[i]
      }
    }),
    Bytes::makei(4000, i => {
      if i == 2000 {
        (a[i].to_int() ^ 1).to_byte()
      } else {
        a[i]
      }
    }),
    Bytes::makei(4000, i => {
      if i == 3999 {
        (a[i].to_int() ^ 1).to_byte()
      } else {
        a[i]
      }
    }),
    // A prefix of the data and the data twice.
    Bytes::makei(8, i => a[i]),
    Bytes::makei(8000, i => a[i % 4000]),
  ]
  for i, data in variants {
    let encoded = deflate_encode_memoized(data, deflate_encode)
    assert_eq(deflate_cache.length(), i + 2)
    assert_eq(@codecs.zlib_decompress(encoded), data)
    assert_true(
      physical_equal(deflate_encode_memoized(data, deflate_encode), encoded),
    )
  }
  assert_eq(
    deflate_memo_stats(),
    (found + 2 + variants.length(), computed + 1 + variants.length()),
  )
  // The first is still what it was.
  assert_true(physical_equal(deflate_encode_memoized(a, deflate_encode), first))
}

///|
test "deflate: the compressor is called for a stream that is not kept, and only then" {
  deflate_test_reset()
  let mut calls = 0
  let counting = (data : Bytes) => {
    calls += 1
    deflate_encode(data)
  }
  let a = deflate_test_data(4000, 5)
  let first = deflate_encode_memoized(a, counting)
  assert_eq(calls, 1)
  assert_eq(first, deflate_encode(a))
  assert_true(physical_equal(deflate_encode_memoized(a, counting), first))
  assert_eq(calls, 1)
  // With memoization off, every time.
  @library.set_layout_memo_enabled(false)
  {
    defer @library.set_layout_memo_enabled(true)
    assert_eq(deflate_encode_memoized(a, counting), first)
    assert_eq(deflate_encode_memoized(a, counting), first)
  }
  assert_eq(calls, 3)
}

///|
test "deflate: with memoization off nothing is looked up or kept, and the bytes are the same" {
  deflate_test_reset()
  let a = deflate_test_data(4000, 7)
  let b = deflate_test_data(4000, 8)
  let kept = deflate_encode_memoized(a, deflate_encode)
  let stats = deflate_memo_stats()
  @library.set_layout_memo_enabled(false)
  let (plain_a, plain_b) = {
    defer @library.set_layout_memo_enabled(true)
    (
      deflate_encode_memoized(a, deflate_encode),
      deflate_encode_memoized(b, deflate_encode),
    )
  }
  // Not the kept object, and nothing new in the cache.
  assert_eq(plain_a, kept)
  assert_false(physical_equal(plain_a, kept))
  assert_eq(deflate_cache.length(), 1)
  assert_eq(deflate_memo_stats(), stats)
  // On again: what was kept before is found, the other is compressed now
  // and is what it was without memoization.
  assert_true(physical_equal(deflate_encode_memoized(a, deflate_encode), kept))
  assert_eq(deflate_encode_memoized(b, deflate_encode), plain_b)
  assert_eq(deflate_cache.length(), 2)
}

///|
test "deflate: a kept stream has comemo's age" {
  deflate_test_reset()
  let a = deflate_test_data(4000, 11)
  let b = deflate_test_data(4000, 12)
  let first_a = deflate_encode_memoized(a, deflate_encode)
  let first_b = deflate_encode_memoized(b, deflate_encode)
  // `a` is found after every eviction, `b` never: it survives ten and goes
  // with the eleventh.
  for i in 0..<10 {
    @library.evict(10)
    assert_true(
      physical_equal(deflate_encode_memoized(a, deflate_encode), first_a),
    )
    assert_eq(deflate_cache.length(), 2, msg="eviction \{i + 1}")
  }
  @library.evict(10)
  assert_eq(deflate_cache.length(), 1)
  assert_true(
    physical_equal(deflate_encode_memoized(a, deflate_encode), first_a),
  )
  // What was dropped is compressed again, to the same bytes.
  let second_b = deflate_encode_memoized(b, deflate_encode)
  assert_false(physical_equal(second_b, first_b))
  assert_eq(second_b, first_b)
  // A hit makes a stream young: found after ten evictions, it stays for
  // ten more.
  for _ in 0..<10 {
    @library.evict(10)
  }
  assert_true(
    physical_equal(deflate_encode_memoized(b, deflate_encode), second_b),
  )
  for _ in 0..<10 {
    @library.evict(10)
  }
  assert_eq(deflate_cache.length(), 1)
  assert_true(
    physical_equal(deflate_encode_memoized(b, deflate_encode), second_b),
  )
  // `evict(0)` drops everything.
  @library.evict(0)
  assert_eq(deflate_cache.length(), 0)
}

///|
test "deflate: a document's content streams are kept, its binary streams are not" {
  deflate_test_reset()
  // A page with a path, whose content stream compresses.
  let file = (shift : Double, compress : Bool) => {
    let settings : @export.SerializeSettings = {
      ..@export.SerializeSettings::default(),
      compress_content_streams: compress,
      enable_tagging: false,
    }
    let document = @export.Document::new_with(settings, memo=export_memo)
    for p in 0..<3 {
      let page = document.start_page_with(
        @export.PageSettings::from_wh(300.0, 300.0).unwrap(),
      )
      let surface = page.surface()
      surface.set_fill(Some(@export.Fill::default()))
      for i in 0..<40 {
        let builder = @export.PathBuilder::new()
        // The last page is the one that changes.
        let x = i.to_double() * 5.0 + (if p == 2 { shift } else { 0.0 })
        builder.push_rect(
          @export.Rect::from_xywh(x, p.to_double() * 7.0 + 1.0, 3.0, 4.0).unwrap(),
        )
        surface.draw_path(builder.finish().unwrap())
      }
      surface.finish()
      page.finish()
    }
    document.finish() catch {
      _ => fail("no file")
    }
  }
  let (found, computed) = deflate_memo_stats()
  let first = file(0.0, true)
  // Three pages, three content streams; the profiles of the colour spaces
  // and the metadata are not content streams.
  assert_eq(deflate_cache.length(), 3)
  assert_eq(deflate_memo_stats(), (found, computed + 3))
  // The same document again: nothing is compressed, and the file is the
  // same bytes.
  assert_true(file(0.0, true) == first)
  assert_eq(deflate_memo_stats(), (found + 3, computed + 3))
  // Another last page: one stream is compressed.
  let edited = file(0.5, true)
  assert_true(edited != first)
  assert_eq(deflate_memo_stats(), (found + 5, computed + 4))
  assert_eq(deflate_cache.length(), 4)
  // From nothing and without memoization the files are the same bytes.
  @library.evict(0)
  @library.set_layout_memo_enabled(false)
  let (plain_first, plain_edited) = {
    defer @library.set_layout_memo_enabled(true)
    (file(0.0, true), file(0.5, true))
  }
  assert_eq(deflate_cache.length(), 0)
  assert_true(plain_first == first)
  assert_true(plain_edited == edited)
  // Content streams that are not compressed (`pretty`) are not looked up.
  let stats = deflate_memo_stats()
  file(0.0, false) |> ignore
  assert_eq(deflate_memo_stats(), stats)
  assert_eq(deflate_cache.length(), 0)
}
