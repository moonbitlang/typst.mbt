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
  let summary = "w=\{image.width()} h=\{image.height()} dpi=\{dpi} rot=\{rot} icc=\{icc} color=\{color}"
  match image.dynamic() {
    Some(dynamic) => {
      // FNV-1a-style hash of the samples (with the offset basis of the probe).
      let mut h = 1469598103934665603UL
      for b in dynamic.buf {
        h = (h ^ b.to_uint64()) * 1099511628211UL
      }
      let hex = h.to_string(radix=16)
      let hex = String::make(16 - hex.length(), '0') + hex
      summary + " pixels=\{dynamic.buf.length()}/\{hex}"
    }
    None => summary
  }
}

///|
fn hex_to_bytes(s : String) -> Bytes {
  let chars = s.to_array()
  let digit = (c : Char) => {
    let c = c.to_int()
    if c <= '9'.to_int() {
      c - '0'.to_int()
    } else {
      c - 'a'.to_int() + 10
    }
  }
  Bytes::makei(chars.length() / 2, i => {
    (digit(chars[2 * i]) * 16 + digit(chars[2 * i + 1])).to_byte()
  })
}

///|
test "decode PNG pixels like upstream" {
  let failures = []
  for vector in png_vectors {
    let (name, hex, expected) = vector
    let actual = raster_summary(hex_to_bytes(hex), "Png")
    if actual != expected {
      failures.push("\{name}: \{actual}")
    }
  }
  assert_eq(failures, [])
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
  let failures = []
  for vector in image_vectors {
    let (name, format, expected) = vector
    let data = @fs.read_file_to_bytes(dir + "/" + name)
    let actual = if format == "svg" {
      svg_summary(data)
    } else {
      raster_summary(data, format)
    }
    if actual != expected {
      failures.push("\{name} as \{format}: \{actual}")
    }
  }
  assert_eq(failures, [])
}

///|
/// Expectations produced with upstream Typst (`RasterImage::plain`,
/// `SvgImage::new`) on the `typst-dev-assets` images.
let image_vectors : Array[(String, String, String)] = [
  (
    "bad.svg", "svg", "err failed to parse SVG (found closing tag 'g' instead of 'style')",
  ),
  (
    "chart-bad-deuteranopia.png", "Png", "w=958 h=637 dpi=72.009 rot=None icc=None color=Rgb8 pixels=1830738/5d565e8b71c7b275",
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
    "chart-bad-regular.png", "Png", "w=958 h=637 dpi=None rot=None icc=None color=Rgb8 pixels=1830738/85001f0d29116cac",
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
  (
    "chart-good.png", "Png", "w=958 h=637 dpi=None rot=None icc=None color=Rgb8 pixels=1830738/d36be56e1b7b7ff0",
  ),
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
    "color-contrast.png", "Png", "w=1536 h=708 dpi=216.0016 rot=None icc=None color=Rgba8 pixels=4349952/5e244f75ba2e473d",
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
  (
    "f2t.png", "Png", "w=48 h=80 dpi=None rot=1 icc=None color=Rgba8 pixels=15360/1e2a7a7e5b002f83",
  ),
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
    "graph.png", "Png", "w=1191 h=341 dpi=143.99259999999998 rot=None icc=None color=Rgba8 pixels=1624524/2a3dff7afd966823",
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
  (
    "rhino.png", "Png", "w=512 h=347 dpi=71.9328 rot=None icc=None color=Rgba8 pixels=710656/07301246f359b2fd",
  ),
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
  (
    "small.png", "Png", "w=26 h=12 dpi=None rot=None icc=None color=Rgb8 pixels=936/f6c98e83b1288a53",
  ),
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
/// Synthetic PNGs covering bit depths, color types, transparency, palettes,
/// interlacing and EXIF orientations, with expectations produced with
/// upstream Typst (`RasterImage::plain`; the pixel hash is FNV-1a over
/// `DynamicImage::as_bytes`).
let png_vectors : Array[(String, String, String)] = [
  (
    "exif3.png", "89504e470d0a1a0a0000000d49484452000000040000000308040000001efd664d0000001a6558496649492a0008000000010012010300010000000300000000000000ffa81f4d000000124944415478da63943ba09ba5f8aace95c13846e8ba3196f82e260000001249444154db1e77c6792d7f6ed96e3ef3130084c80ba71db736b30000000049454e44ae426082",
    "w=4 h=3 dpi=None rot=3 icc=None color=La8 pixels=24/2160f95cb8b543fe",
  ),
  (
    "exif5.png", "89504e470d0a1a0a0000000d4948445200000004000000030800000000919ff11a0000001a6558496649492a000800000001001201030001000000050000000000000039c716ca0000000c4944415478da635834d3518741e4cc79ea3d18560000000c4944415449c63367e79d01002a970675981c73300000000049454e44ae426082",
    "w=3 h=4 dpi=None rot=5 icc=None color=L8 pixels=12/ea74e60989bc10e6",
  ),
  (
    "exif6.png", "89504e470d0a1a0a0000000d4948445200000005000000030802000000d45452af0000001a655849664d4d002a00000008000101120003000000010006000000000000d6674b69000000097048597300000ec400000ec301da6a98dc0000001d4944415478da013000cfff00a4effe97eebfdad6265cb80e0a17a90130f7f8191a7bc2c1500000001e49444154758b2f405c7b01c2b0e300deafd8801a9495b5fcceaa8bb068fc583d19779b3fec0f0000000049454e44ae426082",
    "w=3 h=5 dpi=96.012 rot=6 icc=None color=Rgb8 pixels=45/86f7c0c23cfec8ac",
  ),
  (
    "exif7.png", "89504e470d0a1a0a0000000d4948445200000004000000021002000000a05a36770000001a6558496649492a00080000000100120103000100000007000000000000007be211b70000001e4944415478da013200cdff0014293cd9d796cf2ee497226a073cc6374f82f36dd328d094bd400000001f49444154343f012a75f1c36caf233f16306ef0b5befdd364ac2bae6bf700d62aab177ca6ea5e550000000049454e44ae426082",
    "w=2 h=4 dpi=None rot=7 icc=None color=Rgb16 pixels=48/44c533b9b0c517a7",
  ),
  (
    "exif8.png", "89504e470d0a1a0a0000000d4948445200000003000000020800000000b81f39c60000001a6558496649492a0008000000010012010300010000000800000000000000a2c2031b000000084944415478da63e46c79cff01675b5bb00000008494441542c5e12000b9b02dce67137890000000049454e44ae426082",
    "w=2 h=3 dpi=None rot=8 icc=None color=L8 pixels=6/64658fa8e3dbba13",
  ),
  (
    "g1.png", "89504e470d0a1a0a0000000d494844520000000b000000050100000000bbdd2bfb0000000b4944415478da6370626038d1c068efbe1f49ae0000000c49444154c868c7c4b0f90100189503e08055b6d80000000049454e44ae426082",
    "w=11 h=5 dpi=None rot=None icc=None color=L8 pixels=55/c7807e4dd71428d6",
  ),
  (
    "g16.png", "89504e470d0a1a0a0000000d49484452000000050000000310000000002ecd4667000000164944415478da012100deff0163ea17a75395a7f1f24401fc4dba5e6a68000000001649444154bf58ca007781c200f1c984b26325b045e4fb1e3111ae86e94b5f0000000049454e44ae426082",
    "w=5 h=3 dpi=None rot=None icc=None color=L16 pixels=30/e6c35b3a5d9f34f8",
  ),
  (
    "g16t.png", "89504e470d0a1a0a0000000d49484452000000050000000310000000002ecd46670000000274524e5304d27a22bbc4000000154944415478da6364b96450ed70a3a6b3848381e552c6e2ef72573e85da00000015494441540cbfbed632b25c529f26f4a7b36b813c00dea20df2c703dd850000000049454e44ae426082",
    "w=5 h=3 dpi=None rot=None icc=None color=La16 pixels=60/4e212a0ee5fd7dd8",
  ),
  (
    "g2.png", "89504e470d0a1a0a0000000d494844520000000900000004020000000033d452b30000000c4944415478da63d07bdcc0e0937a80e115a58b850000000d49444154e3cf038cbba7bd0700381f07ee0a47d6240000000049454e44ae426082",
    "w=9 h=4 dpi=None rot=None icc=None color=L8 pixels=36/43faaa05fc25fe57",
  ),
  (
    "g4.png", "89504e470d0a1a0a0000000d4948445200000007000000030400000000bf58a7180000000c4944415478da638898e0bb817149d5ba1a2ad5a70000000c494441542f0c87ff8829000031bf069c941892520000000049454e44ae426082",
    "w=7 h=3 dpi=None rot=None icc=None color=L8 pixels=21/9f525259576bcabd",
  ),
  (
    "g4t.png", "89504e470d0a1a0a0000000d4948445200000007000000030400000000bf58a7180000000274524e53000506f939b70000000c4944415478da638cdaf9518731e0dabcc5e1d24a0000000c494441543d8cd1337c1602003255069439face570000000049454e44ae426082",
    "w=7 h=3 dpi=None rot=None icc=None color=La8 pixels=42/b71611ac95958bbc",
  ),
  (
    "g8t.png", "89504e470d0a1a0a0000000d4948445200000006000000030800000000956a21270000000274524e53004d7efef0150000000f4944415478da63f0f53459dffe95d1775f5cc03f9d4ecf0000000f49444154a4430cbe7aadbb43b70100592a08ca7b5cefae0000000049454e44ae426082",
    "w=6 h=3 dpi=None rot=None icc=None color=La8 pixels=36/b73ac8d264aa2435",
  ),
  (
    "i_g2.png", "89504e470d0a1a0a0000000d494844520000000a000000090200000001137acaf80000001e4944415478da630860706074606060f802c41f1802185819185a1d18621a184c1818c4651acc0000001f494441540dcf337836306c61607c70b79921f64603c384450f182aff180000319c0f0b0b0363650000000049454e44ae426082",
    "w=10 h=9 dpi=None rot=None icc=None color=L8 pixels=90/2c2ccf98943b044c",
  ),
  (
    "i_p4.png", "89504e470d0a1a0a0000000d49484452000000090000000a0403000001e32c591b0000000f504c5445a54dca182530bb1d6d132cded6237b8e7045ee000000274944415478da63106210660860746014fdcd68c298cc60ca28a47f9fc12c448151f50d438822a3900063f239b3c076000000284944415426c6d4078c6a067c1b7f33080588321a30b2fe1594bdc06020e46a10c098f885f1ff6b00f9311169a3c199340000000049454e44ae426082",
    "w=9 h=10 dpi=None rot=None icc=None color=Rgb8 pixels=270/f0fd1f77142482ec",
  ),
  (
    "i_rgb8.png", "89504e470d0a1a0a0000000d494844520000000d0000000b08020000015cd7a0a0000000e74944415478da01c3013cfe01393224c6a50501f25d6fca8771018ea17c2b29e9001513a5f2cc3600517ed02b6a313e96967d784e0185720089609dafa25f00a652da58774482856500c4b73f9cd79dfaee7800ef109fe2563729b3d7b69edd64bee4f20fd2c011ed00821368be5e9ffdf7204f2e53919dd5d4d509cf680300be12658ea7c018b8e7be87c0a929e297819e714c94019962c66c3825eede932993e56769768e39fe01c1bfa94069e63e4233edaf30368cc81c2a5a002111f6352487d7ffe4d5eb788f89bee07e5f0105a7d122c13fa9cbbafb57074f15e5a0c5120015cc504c7e623cc7e97f6e6130a6000000e749444154d9c75b0b01e4ea5b015dce52f9b9e8dffa8f87c9efb910602ba6f9010395226668443666104f0e11a9c676c83bfb76aa52f4ff23432d670ed68aafc8427042b46f390a00201f836320adb98bab1686a28d9801210c7736f3eec580dcfc43fe5d049b4d78a7a3ebb92865c8009060a721ca807d7633ed123402f376e5bf1496773d19616326be5be5850336b36f13bcae48166801de50d85cdef780bd84881cc706c413758c1df53a08a591e56dd92ed645b15d6105cf8b37aba312012241b7ba7a770659e660168ce6f1211df260f35622c33011768e5f1030f20b98a4f60c210484398e63d4afea9e11ce0000000049454e44ae426082",
    "w=13 h=11 dpi=None rot=None icc=None color=Rgb8 pixels=429/7370bc60b026076d",
  ),
  (
    "i_rgba16.png", "89504e470d0a1a0a0000000d4948445200000003000000091006000001d0247a0c0000007a4944415478da01e90016ff000571c704facc3677014e2b6ac5ce1255f801f03573b44ae3b4cd00664db24833c1e9df00f055b5a175fe88eb016d1b2840e08e3be4011cfd81428c78c380ba53560f28d1c44200f847db632bbcb9902ba9a63f47e2b0b701138780a06f8e525901cca31f7d06d0267e00d39aefaa96b44015a43bf3970000007a49444154014e359b38c52d1d37002e499816650dfd2a0168f3f393083fbd654797df86e1b1ae2baf91f6db55ba4b700037f072e89b63cd0b7015c8afec9a6c8c543d4233234662e700c09681d1da2a5f2cf69001618ffab7487d6c9a88a401f5870007ac05e06b6424dd9603800333f94914779f5f0fe767b16153666b83539e1af20000000049454e44ae426082",
    "w=3 h=9 dpi=None rot=None icc=None color=Rgba16 pixels=216/6b37b14c7e7eef02",
  ),
  (
    "iccp.png", "89504e470d0a1a0a0000000d49484452000000030000000208020000001216f14d000000d96943435070726f660000789c01c80037ff000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c75a284dbdeb945e340000000e4944415478da63d49ef6ffc01b69d5665646268e633e0000000e49444154768de333ca7ba3ea7d0153c807efd915a13d0000000049454e44ae426082",
    "w=3 h=2 dpi=None rot=None icc=200/19900 color=Rgb8 pixels=18/6df503798d0976c8",
  ),
  (
    "la16.png", "89504e470d0a1a0a0000000d4948445200000003000000031004000000acb1a177000000194944415478da012700d8ff01803a12eb87a1f7855a25eaa3017dc9e4e46cf6d6b70000001949444154b9a1f962c706ecfc009d956e2c7589af7665b24789995114b85e71f9cd0000000049454e44ae426082",
    "w=3 h=3 dpi=None rot=None icc=None color=La16 pixels=36/6550639bc66d872d",
  ),
  (
    "la8.png", "89504e470d0a1a0a0000000d49484452000000040000000308040000001efd664d000000124944415478da632c541293493c7ef40263a753af85d29fe4ae2200000012494441540dbfe30c31e9f3e7644e79120d008ca50b5e7630b8870000000049454e44ae426082",
    "w=4 h=3 dpi=None rot=None icc=None color=La8 pixels=24/4cad44ad7e20cf02",
  ),
  (
    "p1.png", "89504e470d0a1a0a0000000d494844520000000d000000030103000000722f174f00000006504c5445a54dca182530893ab98b000000084944415478da638ca86034b1a37c21e9000000094944415461383c01000a2a029669a2075e0000000049454e44ae426082",
    "w=13 h=3 dpi=None rot=None icc=None color=Rgb8 pixels=117/81f3107a148c260f",
  ),
  (
    "p2.png", "89504e470d0a1a0a0000000d49484452000000090000000302030000003c64cde50000000c504c5445a54dca182530bb1d6d132cdece1b01180000000a4944415478da63e8fce3c0681faf9cc33e850000000a49444154c4d8a1320500192403c85b5bbf3a0000000049454e44ae426082",
    "w=9 h=3 dpi=None rot=None icc=None color=Rgb8 pixels=81/610e19ce83bbaf34",
  ),
  (
    "p4.png", "89504e470d0a1a0a0000000d4948445200000007000000030403000000aded08f60000000f504c5445a54dca182530bb1d6d132cded6237b8e7045ee0000000b4944415478da63604b35716010650832a6b2ef0000000c49444154366070134d32000011210265d1d890c00000000049454e44ae426082",
    "w=7 h=3 dpi=None rot=None icc=None color=Rgb8 pixels=63/cae478874f09bde0",
  ),
  (
    "p8.png", "89504e470d0a1a0a0000000d49484452000000050000000308030000006ce835ca0000000f504c5445a54dca182530bb1d6d132cded6237b8e7045ee0000000d4944415478da6360606461636660616466663863a00000000d49444154626360666664610400018b002bcb5144740000000049454e44ae426082",
    "w=5 h=3 dpi=None rot=None icc=None color=Rgb8 pixels=45/fe74a9c5e5c24e38",
  ),
  (
    "p8t.png", "89504e470d0a1a0a0000000d49484452000000050000000308030000006ce835ca0000000f504c5445a54dca182530bb1d6d132cded6237b8e7045ee0000000374524e530080ffecf7b3180000000d4944415478da6360636066626164facff2a391929d0000000d494441549f8181958d8d8d11001379022d0b6f2a390000000049454e44ae426082",
    "w=5 h=3 dpi=None rot=None icc=None color=Rgba8 pixels=60/dc86f90b1e034382",
  ),
  (
    "p8tlong.png", "89504e470d0a1a0a0000000d49484452000000050000000308030000006ce835ca00000006504c5445a54dca182530893ab98b0000000374524e530080ffecf7b3180000000b4944415478da63606664600482ffcc5beae7200000000c494441547f19802c86ff4c00148a030bbbc7a2dd0000000049454e44ae426082",
    "w=5 h=3 dpi=None rot=None icc=None color=Rgba8 pixels=60/8792f256490298a2",
  ),
  (
    "rgb16.png", "89504e470d0a1a0a0000000d49484452000000040000000310020000006b06e5d20000002b4944415478da014b00b4ff018debe799f4c1f1e19d5073f86756c24d6e98592382ad0d0c00a1c825247b35db4f2570e7f6bf830000002b494441546ce59b053ea44f13bb7c49348197014646ef7b706deaebdc6d890d2328a7a2593189975c365bf57b392339905c37810000000049454e44ae426082",
    "w=4 h=3 dpi=None rot=None icc=None color=Rgb16 pixels=72/0d93e5fdedc7f1c1",
  ),
  (
    "rgb16t.png", "89504e470d0a1a0a0000000d49484452000000040000000310020000006b06e5d20000000674524e53006400c8012cb66b4c46000000274944415478da6360486138c1a8c3f9732df7ab6b0f9b399d8e9c58b96bbaabc22b468884f6b276832ede97c1f2ff8300000027494441545657fffcb7d313acb1fdf5910122b1bc48f76cdf43d992d8fb370fab0a776ee09807009e582040ff7925e30000000049454e44ae426082",
    "w=4 h=3 dpi=None rot=None icc=None color=Rgba16 pixels=96/b523495ecdb68cf3",
  ),
  (
    "rgb8t.png", "89504e470d0a1a0a0000000d4948445200000005000000040802000000c95162170000000674524e53000100020003c94babf5000000224944415478da636064627e7b563b30dc91cff79dd7a7cd8c403e9b91cb757d55035986f6df5674ce0d8e000000234944415420bedce6e73b7a938de60bfcccfecd00e4cb2ffb6e265b9fd82b6af49c0f0089261529be7ebf760000000049454e44ae426082",
    "w=5 h=4 dpi=None rot=None icc=None color=Rgba8 pixels=80/b02303108dc93ec1",
  ),
  (
    "rgba16.png", "89504e470d0a1a0a0000000d4948445200000003000000021006000000cde4ba590000001e4944415478da013200cdff004277074c243582dddc8a53951c5d2b41c30290597c037c28fa150000001f49444154960b011729eb3d5ee650a87296f906a3f4361f31b1c426a4ccf761d9e514f211b189cf0000000049454e44ae426082",
    "w=3 h=2 dpi=None rot=None icc=None color=Rgba16 pixels=48/21e28762352dcb28",
  ),
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
