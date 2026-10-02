///|
/// Expected PNG sizes and CRC-32 checksums of the output of upstream
/// `image::codecs::png::PngEncoder` (image 0.25.10, png 0.18.1) for
/// generated pixel data, produced with a Rust probe.
let png_vectors : Array[(String, Int, Int, String, Int, UInt)] = [
  ("Rgb8", 3, 3, "grad", 98, 0xD9F15588U),
  ("Rgb8", 17, 9, "grad", 536, 0xC07807B3U),
  ("Rgb8", 40, 30, "rand", 3698, 0x656317BCU),
  ("Rgb8", 64, 64, "grad", 12420, 0x5A8519BEU),
  ("Rgb8", 5, 7, "zero", 133, 0x577CDC9EU),
  ("Rgb8", 300, 300, "smooth", 98439, 0xB2AE6E83U),
  ("Rgba8", 3, 3, "grad", 107, 0xB4B6A091U),
  ("Rgba8", 17, 9, "grad", 689, 0x38F4DAEEU),
  ("Rgba8", 40, 30, "rand", 4898, 0x96D03D4AU),
  ("Rgba8", 64, 64, "grad", 640, 0x62C8C343U),
  ("Rgba8", 5, 7, "zero", 142, 0x0197ACE5U),
  ("Rgba8", 300, 300, "smooth", 99903, 0x7D61743DU),
  ("Luma8", 3, 3, "grad", 80, 0xEB49A937U),
  ("Luma8", 17, 9, "grad", 230, 0xC40AA7AEU),
  ("Luma8", 40, 30, "rand", 1298, 0xEA202738U),
  ("Luma8", 64, 64, "grad", 3745, 0x786AD9C6U),
  ("Luma8", 5, 7, "zero", 110, 0xD116F4B6U),
  ("Luma8", 300, 300, "smooth", 34076, 0xC2F36422U),
  ("Lumaa8", 3, 3, "grad", 89, 0xA524D033U),
  ("Lumaa8", 17, 9, "grad", 376, 0xA00FBA26U),
  ("Lumaa8", 40, 30, "rand", 2498, 0x12303229U),
  ("Lumaa8", 64, 64, "grad", 8324, 0x6FEF1FD9U),
  ("Lumaa8", 5, 7, "zero", 136, 0xDDCF8B75U),
  ("Lumaa8", 300, 300, "smooth", 67878, 0x350AFF9AU),
]

///|
test "encode_png matches upstream" {
  let mut seed = 12345U
  for vector in png_vectors {
    let (enc, w, h, kind, len, crc) = vector
    let (color, ch) : (@codecs.PngColorType, Int) = match enc {
      "Rgb8" => (Rgb, 3)
      "Rgba8" => (Rgba, 4)
      "Luma8" => (Grayscale, 1)
      _ => (GrayscaleAlpha, 2)
    }
    let n = w * h * ch
    let data = Bytes::makei(n, j => {
      match kind {
        "grad" => (j * 7 % 256).to_byte()
        "rand" => {
          seed = seed * 1103515245U + 12345U
          (seed >> 16).to_byte()
        }
        "zero" => b'\x00'
        _ => (j / ch / 300 + j % 5).to_byte()
      }
    })
    let png = @codecs.encode_png(data[:], w, h, color)
    assert_eq(png.length(), len, msg="\{enc} \{w}x\{h} \{kind}")
    assert_eq(@codecs.crc32([png[:]]), crc, msg="\{enc} \{w}x\{h} \{kind}")
  }
}
