// The image conversion of the PDF exporter (`convert_raster`, kept by
// content: `library/memo_content.mbt`): what the conversion gives, and which
// images are one entry and one image of the PDF.

///|
/// The conversion as it was before it was a loop per colour type: every
/// sample through one function (the reference).
fn reference_samples(
  width : Int,
  height : Int,
  color : @codecs.ColorType,
  buf : Bytes,
) -> (Bytes, Bytes?) {
  let channels = color.channel_count()
  let sixteen = color is (L16 | La16 | Rgb16 | Rgba16)
  let has_alpha = color is (La8 | Rgba8 | La16 | Rgba16)
  let color_channels = if channels >= 3 { 3 } else { 1 }
  let bpc = if sixteen { 2 } else { 1 }
  let n = width * height
  let sample = (i : Int) => {
    if sixteen {
      u16_to_u8(buf[i].to_int() | (buf[i + 1].to_int() << 8))
    } else {
      buf[i]
    }
  }
  let color_buf = Array::make(n * color_channels, b'\x00')
  let alpha_buf = Array::make(if has_alpha { n } else { 0 }, b'\x00')
  for p in 0..<n {
    let base = p * channels * bpc
    for c in 0..<color_channels {
      color_buf[p * color_channels + c] = sample(base + c * bpc)
    }
    if has_alpha {
      alpha_buf[p] = sample(base + (channels - 1) * bpc)
    }
  }
  (
    Bytes::from_array(color_buf),
    if has_alpha {
      Some(Bytes::from_array(alpha_buf))
    } else {
      None
    },
  )
}

///|
test "convert_samples: every colour type, against the reference" {
  let mut seed = 0x9E3779B97F4A7C15UL
  let next = () => {
    seed = seed ^ (seed << 13)
    seed = seed ^ (seed >> 7)
    seed = seed ^ (seed << 17)
    (seed >> 24).to_byte()
  }
  let icc = b"profile"
  let colors : Array[@codecs.ColorType] = [
    L8,
    La8,
    Rgb8,
    Rgba8,
    L16,
    La16,
    Rgb16,
    Rgba16,
  ]
  for color in colors {
    let sixteen = color is (L16 | La16 | Rgb16 | Rgba16)
    let bytes_per_pixel = color.channel_count() * (if sixteen { 2 } else { 1 })
    for size in [(1, 1), (5, 3), (16, 2), (7, 9)] {
      let (width, height) = size
      // A buffer of exactly the pixels, and one that is longer.
      for extra in [0, 3] {
        let buf = Bytes::makei(width * height * bytes_per_pixel + extra, _ => {
          next()
        })
        let (expected_color, expected_alpha) = reference_samples(
          width, height, color, buf,
        )
        guard convert_samples("key", width, height, color, buf, Some(icc), true)
          is Ok(image) else {
          fail("not converted")
        }
        guard image.data is Samples(color_data, alpha_data) else {
          fail("not samples")
        }
        assert_true(color_data == expected_color)
        assert_true(alpha_data == expected_alpha)
        assert_eq(image.key, "key")
        assert_eq((image.width, image.height), (width, height))
        assert_true(
          image.colorspace ==
          (if color.channel_count() >= 3 { Rgb } else { Luma }),
        )
        assert_true(image.interpolate)
        assert_false(image.inverted_cmyk)
        // The profile is only kept for 8-bit images.
        assert_true(image.icc == (if sixteen { None } else { Some(icc) }))
        // Pixels that are luma8 or rgb8 already are used as they are.
        assert_eq(
          physical_equal(color_data, buf),
          color is (L8 | Rgb8) && extra == 0,
        )
      }
      // Too few bytes.
      let short = Bytes::makei(width * height * bytes_per_pixel - 1, _ => next())
      assert_true(
        convert_samples("key", width, height, color, short, None, false)
        is Err("image data is truncated"),
      )
    }
  }
}

///|
/// A PNG of `width` x `height` pixels of `channels` 8-bit samples.
fn test_png(width : Int, height : Int, channels : Int, seed : Int) -> Bytes {
  let pixels = Bytes::makei(width * height * channels, i => {
    ((seed + i) * 7).to_byte()
  })
  @codecs.encode_png(
    pixels[:],
    width,
    height,
    match channels {
      1 => Grayscale
      2 => GrayscaleAlpha
      3 => Rgb
      _ => Rgba
    },
  )
}

///|
/// A JPEG of 8 x 8 pixels.
fn test_jpeg() -> Bytes {
  let hex = (
    #|ffd8ffe000104a46494600010100004800480000ffe1004c4578696600004d4d002a0000
    #|0008000187690004000000010000001a000000000003a00100030000000100010000a002
    #|00040000000100000008a0030004000000010000000800000000ffed003850686f746f73
    #|686f7020332e30003842494d04040000000000003842494d0425000000000010d41d8cd9
    #|8f00b204e9800998ecf8427effc00011080008000803012200021101031101ffc4001f00
    #|00010501010101010100000000000000000102030405060708090a0bffc400b510000201
    #|0303020403050504040000017d01020300041105122131410613516107227114328191a1
    #|082342b1c11552d1f02433627282090a161718191a25262728292a3435363738393a4344
    #|45464748494a535455565758595a636465666768696a737475767778797a838485868788
    #|898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8
    #|c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f01
    #|00030101010101010101010000000000000102030405060708090a0bffc400b511000201
    #|020404030407050404000102770001020311040521310612415107617113223281081442
    #|91a1b1c109233352f0156272d10a162434e125f11718191a262728292a35363738393a43
    #|4445464748494a535455565758595a636465666768696a737475767778797a8283848586
    #|8788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6
    #|c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2f3f4f5f6f7f8f9faffdb004300
    #|0404040404040604040609060606090c090909090c0f0c0c0c0c0c0f120f0f0f0f0f0f12
    #|1212121212121215151515151519191919191c1c1c1c1c1c1c1c1c1cffdb004301040505
    #|0707070c07070c1d1410141d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d
    #|1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1dffdd00040001ffda000c03
    #|010002110311003f00e5bc2df0bfee7ee7f4aeff00fe157ffd31fd2bbdf0b7f0577f5e56
    #|3f3dc6fb67ef9af09f12661fd994fdf3ffd9
  ).replace_all(old="\n", new="")
  let digit = (c : Int) => if c >= 'a' { c - 'a' + 10 } else { c - '0' }
  Bytes::makei(hex.length() / 2, i => {
    (digit(hex.unsafe_get(2 * i).to_int()) * 16 +
    digit(hex.unsafe_get(2 * i + 1).to_int())).to_byte()
  })
}

///|
/// Whether two converted images hold the same data.
fn same_data(a : @export.Image, b : @export.Image) -> Bool {
  match (a.data, b.data) {
    (Samples(c1, a1), Samples(c2, a2)) => c1 == c2 && a1 == a2
    (Jpeg(x), Jpeg(y)) => x == y
    _ => false
  }
}

///|
fn test_copy(data : Bytes) -> Bytes {
  Bytes::makei(data.length(), i => data[i])
}

///|
fn test_converted(
  raster : @library.RasterImage,
  interpolate : Bool,
) -> @export.Image raise {
  match convert_raster(raster, interpolate) {
    Ok(image) => image
    Err(message) => fail(message)
  }
}

///|
/// Starts from empty caches, whatever ran before.
fn test_reset() -> Unit {
  @library.set_layout_memo_enabled(true)
  @library.evict(0)
}

///|
test "convert_raster: one conversion per image and interpolation" {
  test_reset()
  let data = test_png(6, 4, 4, 1)
  let raster = @library.RasterImage::plain(data, Exchange(Png))
  let a = test_converted(raster, false)
  let b = test_converted(raster, false)
  // One image, shared like krilla's `Arc`.
  assert_true(physical_equal(a, b))
  assert_eq(raster_cache.length(), 1)
  assert_eq((a.width, a.height), (6, 4))
  assert_false(a.interpolate)
  guard a.data is Samples(color, Some(alpha)) else { fail("no alpha") }
  assert_eq((color.length(), alpha.length()), (6 * 4 * 3, 6 * 4))
  // The same bytes in another object (another path, the next compilation):
  // the same raster image, the same conversion.
  let again = @library.RasterImage::plain(test_copy(data), Exchange(Png))
  assert_true(physical_equal(a, test_converted(again, false)))
  // And if it is another raster image of the same data (decoded without
  // memoization), by its hash.
  @library.set_layout_memo_enabled(false)
  let other = @library.RasterImage::plain(test_copy(data), Exchange(Png))
  @library.set_layout_memo_enabled(true)
  assert_false(physical_equal(other, raster))
  assert_true(physical_equal(a, test_converted(other, false)))
  assert_eq(raster_cache.length(), 1)
  // `interpolate` is the second argument: an image of its own, with the
  // same key (the exporter tells them apart by the flag).
  let smooth = test_converted(raster, true)
  assert_false(physical_equal(a, smooth))
  assert_true(smooth.interpolate)
  assert_eq(smooth.key, a.key)
  assert_true(same_data(smooth, a))
  assert_true(physical_equal(smooth, test_converted(again, true)))
  assert_eq(raster_cache.length(), 2)
}

///|
test "convert_raster: images that differ in one argument" {
  test_reset()
  // Two images of equal dimensions.
  let one = @library.RasterImage::plain(test_png(6, 4, 3, 1), Exchange(Png))
  let two = @library.RasterImage::plain(test_png(6, 4, 3, 2), Exchange(Png))
  let a = test_converted(one, false)
  let b = test_converted(two, false)
  assert_true(a.key != b.key)
  assert_false(same_data(a, b))
  assert_eq((a.width, a.height), (b.width, b.height))
  // The same bytes as pixels of three formats: three images, where the key
  // was the data alone and the exporter embedded the first for all.
  let pixels = Bytes::makei(1200, i => (i * 3).to_byte())
  let pixel = (encoding : @library.PixelEncoding, width : Int, height : Int) => {
    @library.RasterImage::plain(
      pixels,
      Pixel({
        encoding,
        width: @library.U32(width.to_int64()),
        height: @library.U32(height.to_int64()),
      }),
    )
  }
  let rgb = test_converted(pixel(Rgb8, 20, 20), false)
  let wide = test_converted(pixel(Luma8, 40, 30), false)
  let tall = test_converted(pixel(Luma8, 30, 40), false)
  assert_eq((rgb.width, rgb.height), (20, 20))
  assert_eq((wide.width, wide.height), (40, 30))
  assert_eq((tall.width, tall.height), (30, 40))
  assert_true(rgb.colorspace == Rgb && wide.colorspace == Luma)
  assert_true(
    rgb.key != wide.key && wide.key != tall.key && rgb.key != tall.key,
  )
  // The same image with a profile, with another, without one.
  let png = test_png(6, 4, 3, 3)
  let icc1 = Bytes::makei(300, i => i.to_byte())
  let icc2 = Bytes::makei(300, i => (i + 1).to_byte())
  let plain = test_converted(
    @library.RasterImage::new(png, Exchange(Png), Auto),
    false,
  )
  let with1 = test_converted(
    @library.RasterImage::new(png, Exchange(Png), Custom(icc1)),
    false,
  )
  let with2 = test_converted(
    @library.RasterImage::new(png, Exchange(Png), Custom(icc2)),
    false,
  )
  assert_true(plain.icc is None)
  assert_true(with1.icc == Some(icc1) && with2.icc == Some(icc2))
  assert_true(
    plain.key != with1.key && with1.key != with2.key && plain.key != with2.key,
  )
  assert_true(
    physical_equal(
      with1,
      test_converted(
        @library.RasterImage::new(png, Exchange(Png), Custom(test_copy(icc1))),
        false,
      ),
    ),
  )
  // An image that was not decoded from its data (the runner's replay of
  // upstream's frames) is not the decoded one.
  let synthetic = test_converted(
    @library.RasterImage::synthetic(png, Exchange(Png), width=6, height=4),
    false,
  )
  assert_true(synthetic.key != plain.key)
  guard synthetic.data is Samples(_, Some(_)) else { fail("no alpha") }
  guard plain.data is Samples(_, None) else { fail("alpha") }
}

///|
test "convert_raster: a JPEG is embedded as it is, by its data" {
  test_reset()
  let data = test_jpeg()
  let raster = @library.RasterImage::plain(data, Exchange(Jpg))
  let image = test_converted(raster, false)
  guard image.data is Jpeg(embedded) else { fail("not embedded") }
  assert_true(physical_equal(embedded, data))
  assert_eq((image.width, image.height), (8, 8))
  assert_true(image.colorspace == Rgb)
  assert_true(physical_equal(image, test_converted(raster, false)))
  // krilla identifies a JPEG by its data alone (`from_jpeg_with_icc`), as
  // the exporter of SVG images does for a JPEG inside an SVG.
  assert_eq(image.key, bytes_key(data))
  let icc = Bytes::makei(300, i => i.to_byte())
  let with_icc = test_converted(
    @library.RasterImage::new(data, Exchange(Jpg), Custom(icc)),
    false,
  )
  assert_eq(with_icc.key, image.key)
  assert_true(with_icc.icc == Some(icc) && image.icc is None)
  // The conversions are two all the same: the profile is an argument.
  assert_false(physical_equal(with_icc, image))
  assert_eq(raster_cache.length(), 2)
}

///|
test "convert_raster: memoization off, and evict" {
  test_reset()
  let raster = @library.RasterImage::plain(test_png(6, 4, 4, 5), Exchange(Png))
  let kept = test_converted(raster, false)
  @library.set_layout_memo_enabled(false)
  let a = test_converted(raster, false)
  let b = test_converted(raster, false)
  @library.set_layout_memo_enabled(true)
  // Nothing is found or kept, and the conversions are equal.
  assert_false(physical_equal(a, b))
  assert_false(physical_equal(a, kept))
  assert_true(a.key == kept.key && same_data(a, kept) && same_data(b, kept))
  assert_eq(raster_cache.length(), 1)
  // The library's `evict` reaches the cache of this package.
  @library.evict(1)
  assert_true(physical_equal(kept, test_converted(raster, false)))
  @library.evict(1)
  @library.evict(1)
  assert_eq(raster_cache.length(), 0)
  // Converted again, the image is what it was.
  let again = test_converted(raster, false)
  assert_false(physical_equal(again, kept))
  assert_true(again.key == kept.key && same_data(again, kept))
}
