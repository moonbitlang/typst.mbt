///|
/// The `images` directory of the `typst-dev-assets` checkout, if present.
fn dev_assets_images() -> String? {
  let home = @env.get_env_vars().get("HOME").unwrap_or("")
  let base = home + "/.cargo/git/checkouts"
  let dirs = @fs.read_dir(base) catch { _ => return None }
  for d in dirs {
    if d.has_prefix("typst-dev-assets-") {
      let revs = @fs.read_dir(base + "/" + d) catch { _ => continue }
      for r in revs {
        return Some(base + "/" + d + "/" + r + "/files/images")
      }
    }
  }
  None
}

///|
/// Summarizes a decoded raster image like the Rust probe that produced the
/// expectations below (`RasterImage::plain` with each exchange format).
fn raster_summary(data : Bytes, format : String) -> String {
  let format : @library.ExchangeFormat = match format {
    "Png" => Png
    "Jpg" => Jpg
    "Gif" => Gif
    _ => Webp
  }
  let image = @library.RasterImage::plain(data, Exchange(format)) catch {
    @library.HintedError(err) => return "err \{err.message}"
    _ => return "err"
  }
  let dpi = match image.dpi() {
    Some(dpi) => @library.rust_debug_f64(dpi)
    None => "None"
  }
  let rot = match image.exif_rotation() {
    Some(rot) => rot.to_string()
    None => "None"
  }
  let icc = match image.icc() {
    Some(icc) => {
      let mut sum = 0
      for b in icc {
        sum += b.to_int()
      }
      "\{icc.length()}/\{sum}"
    }
    None => "None"
  }
  let color = match image.color() {
    L8 => "L8"
    La8 => "La8"
    Rgb8 => "Rgb8"
    Rgba8 => "Rgba8"
    L16 => "L16"
    La16 => "La16"
    Rgb16 => "Rgb16"
    Rgba16 => "Rgba16"
  }
  "w=\{image.width()} h=\{image.height()} dpi=\{dpi} rot=\{rot} icc=\{icc} color=\{color}"
}

///|
/// Summarizes a decoded SVG like the Rust probe (`SvgImage::new`).
fn svg_summary(data : Bytes) -> String {
  let svg = @library.SvgImage::new(data) catch {
    @library.LoadErr(err) => return "err \{err.message}"
    _ => return "err"
  }
  "\{@library.rust_debug_f64(svg.width())} \{@library.rust_debug_f64(svg.height())}"
}

///|
test "decode the images of the test suite like upstream" {
  guard dev_assets_images() is Some(dir) else { return }
  for vector in image_vectors {
    let (name, format, expected) = vector
    let data = @fs.read_file_to_bytes(dir + "/" + name)
    let actual = if format == "svg" {
      svg_summary(data)
    } else {
      raster_summary(data, format)
    }
    assert_eq(actual, expected, msg="\{name} as \{format}")
  }
}

///|
/// Expectations produced with upstream Typst (`RasterImage::plain`,
/// `SvgImage::new`) on the `typst-dev-assets` images.
let image_vectors : Array[(String, String, String)] = [
  (
    "bad.svg", "svg", "err failed to parse SVG (found closing tag 'g' instead of 'style')",
  ),
  (
    "chart-bad-deuteranopia.png", "Png", "w=958 h=637 dpi=72.009 rot=None icc=None color=Rgb8",
  ),
  (
    "chart-bad-deuteranopia.png", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:8950)",
  ),
  (
    "chart-bad-deuteranopia.png", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "chart-bad-deuteranopia.png", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  (
    "chart-bad-regular.png", "Png", "w=958 h=637 dpi=None rot=None icc=None color=Rgb8",
  ),
  (
    "chart-bad-regular.png", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:8950)",
  ),
  (
    "chart-bad-regular.png", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "chart-bad-regular.png", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  ("chart-good.png", "Png", "w=958 h=637 dpi=None rot=None icc=None color=Rgb8"),
  (
    "chart-good.png", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:8950)",
  ),
  (
    "chart-good.png", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "chart-good.png", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  ("chinese.svg", "svg", "250.0 24.0"),
  (
    "color-contrast.png", "Png", "w=1536 h=708 dpi=216.0016 rot=None icc=None color=Rgba8",
  ),
  (
    "color-contrast.png", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:8950)",
  ),
  (
    "color-contrast.png", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "color-contrast.png", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  ("cylinder.svg", "svg", "32.0 32.0"),
  ("diagram.svg", "svg", "550.0 356.0"),
  ("docs.svg", "svg", "16.0 16.0"),
  (
    "f2t.jpg", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  ("f2t.jpg", "Jpg", "w=48 h=80 dpi=220.0 rot=1 icc=None color=L8"),
  (
    "f2t.jpg", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "f2t.jpg", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  ("f2t.png", "Png", "w=48 h=80 dpi=None rot=1 icc=None color=Rgba8"),
  (
    "f2t.png", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:8950)",
  ),
  (
    "f2t.png", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "f2t.png", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  (
    "glacier.jpg", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  (
    "glacier.jpg", "Jpg", "w=4272 h=2848 dpi=72.0 rot=None icc=524/21397 color=Rgb8",
  ),
  (
    "glacier.jpg", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "glacier.jpg", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  (
    "graph.png", "Png", "w=1191 h=341 dpi=143.99259999999998 rot=None icc=None color=Rgba8",
  ),
  (
    "graph.png", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:8950)",
  ),
  (
    "graph.png", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "graph.png", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  (
    "heron.jpg", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  (
    "heron.jpg", "Jpg", "w=2048 h=1302 dpi=None rot=None icc=456/25828 color=Rgb8",
  ),
  (
    "heron.jpg", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "heron.jpg", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  ("linked.svg", "svg", "39.0 86.0"),
  ("logo.svg", "svg", "16.0 16.0"),
  (
    "lynx.jpg", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  ("lynx.jpg", "Jpg", "w=1000 h=1498 dpi=72.0 rot=1 icc=None color=Rgb8"),
  (
    "lynx.jpg", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "lynx.jpg", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  (
    "molecular.jpg", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  ("molecular.jpg", "Jpg", "w=2819 h=2091 dpi=72.0 rot=1 icc=None color=Rgb8"),
  (
    "molecular.jpg", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "molecular.jpg", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  ("monkey.svg", "svg", "48.0 48.0"),
  ("pattern.svg", "svg", "200.0 150.0"),
  ("relative.svg", "svg", "266.6666564941406 266.6666564941406"),
  ("rhino.png", "Png", "w=512 h=347 dpi=71.9328 rot=None icc=None color=Rgba8"),
  (
    "rhino.png", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:8950)",
  ),
  (
    "rhino.png", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "rhino.png", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  (
    "small.gif", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  (
    "small.gif", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:4749)",
  ),
  ("small.gif", "Gif", "w=19 h=12 dpi=None rot=None icc=None color=Rgba8"),
  (
    "small.gif", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  (
    "small.jpeg", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  ("small.jpeg", "Jpg", "w=31 h=12 dpi=93.98 rot=None icc=None color=Rgb8"),
  (
    "small.jpeg", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "small.jpeg", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  (
    "small.jpg", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  ("small.jpg", "Jpg", "w=24 h=12 dpi=93.98 rot=None icc=None color=Rgb8"),
  (
    "small.jpg", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "small.jpg", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  ("small.png", "Png", "w=26 h=12 dpi=None rot=None icc=None color=Rgb8"),
  (
    "small.png", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:8950)",
  ),
  (
    "small.png", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "small.png", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  ("small.svg", "svg", "25.0 12.0"),
  (
    "small.webp", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  (
    "small.webp", "Jpg", "err failed to decode image (Format error decoding Jpeg: Error parsing image. Illegal start bytes:5249)",
  ),
  (
    "small.webp", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  ("small.webp", "Webp", "w=35 h=12 dpi=None rot=None icc=None color=Rgb8"),
  ("tetrahedron.svg", "svg", "32.0 32.0"),
  (
    "tiger.jpg", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  (
    "tiger.jpg", "Jpg", "w=1024 h=670 dpi=72.0 rot=None icc=3144/259021 color=Rgb8",
  ),
  (
    "tiger.jpg", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "tiger.jpg", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  (
    "typing.jpg", "Png", "err failed to decode image (Format error decoding Png: Invalid PNG signature.)",
  ),
  ("typing.jpg", "Jpg", "w=1766 h=1766 dpi=72.0 rot=1 icc=None color=Rgb8"),
  (
    "typing.jpg", "Gif", "err failed to decode image (Format error decoding Gif: malformed GIF header)",
  ),
  (
    "typing.jpg", "Webp", "err failed to decode image (Format error decoding WebP: Invalid Chunk header: [52, 49, 46, 46])",
  ),
  ("typst.svg", "svg", "91.0 35.0"),
]

///|
test "decode a compressed SVG" {
  let hex = "1f8b08000000000002ff8dcddb0d80200c40d1554807b055ff8c388c5a81041f816a1d5f19c0c4ef7b92dbe7cb997b8d5bb6e0458e0e51552b6dab3d396c88085f0146c32cde4243603c07e7c5424d30f48927f9886609315a483c03fe81633cb9c8321c1ea3307b4198000000"
  let chars = hex.to_array()
  let digit = (c : Char) => {
    let c = c.to_int()
    if c <= '9'.to_int() {
      c - '0'.to_int()
    } else {
      c - 'a'.to_int() + 10
    }
  }
  let data = Bytes::makei(chars.length() / 2, i => {
    (digit(chars[2 * i]) * 16 + digit(chars[2 * i + 1])).to_byte()
  })
  inspect(svg_summary(data), content="20.0 10.0")
  inspect(
    svg_summary(Bytes::makei(4, i => data[i])),
    content="err failed to parse SVG (file is not compressed correctly)",
  )
}
