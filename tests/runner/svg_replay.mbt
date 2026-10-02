// The `svg-replay` stage: tests the SVG exporter independently of layout.
//
// Instead of compiling the test, it decodes upstream's laid-out document from
// the `paged` goldens (`typst-frame-v1`, see `oracle/src/paged.rs`), exports
// it with `@svg.svg_merged` like the `svg` stage and compares the result with
// the `svg` goldens (canonicalized like the `svg` stage).
//
// The frame format is lossless for everything the SVG exporter reads, except
// for raw pixel images (only the hash of their data is recorded) and PDF
// images; documents containing them are reported as unsupported. Fonts and
// image files are found by the SHA-256 of their data among the test fonts and
// the `typst-dev-assets` files.

///|
/// Decode a document from its `typst-frame-v1` records and export it.
fn svg_replay_report(rel : String, tc : TestCase) -> String {
  let golden = paged_golden(rel).get(tc.name).unwrap_or("")
  let records = []
  for line in golden.split("\n") {
    if line.is_empty() {
      continue
    }
    let json = @json.parse(line.to_owned()) catch {
      _ => return "<unsupported: malformed frame record>\n"
    }
    guard json is Array(fields) && fields.length() > 0 else {
      return "<unsupported: malformed frame record>\n"
    }
    records.push(fields)
  }
  let decoder = FrameDecoder::new()
  for rec in records {
    if rec[0] is String("diagnostics") && rec[1] is String("err") {
      return "<error>\n"
    }
  }
  if records.is_empty() {
    return "<unsupported: missing paged golden>\n"
  }
  let doc = decoder.document(records) catch {
    Unsupported(msg) => return "<unsupported: \{msg}>\n"
  }
  @svg.svg_merged(
    doc,
    { render_bleed: false, format: { pretty: Some(true), }, },
    @library.Abs::pt(1.0),
  )
}

///|
/// The parsed `paged` golden of a test file, cached per file.
fn paged_golden(rel : String) -> Map[String, String] {
  if paged_golden_cache.get(rel) is Some(m) {
    return m
  }
  let path = golden_dir +
    "/paged/" +
    rel.unsafe_substring(start=0, end=rel.length() - 4) +
    ".txt"
  let m = split_golden(read(path))
  paged_golden_cache.clear()
  paged_golden_cache[rel] = m
  m
}

///|
let paged_golden_cache : Map[String, Map[String, String]] = {}

///|
priv suberror Unsupported {
  Unsupported(String)
}

///|
/// A decoded frame record with its items.
priv struct FrameRec {
  size : @library.Axes[@library.Abs]
  baseline : @library.Abs?
  kind : @library.FrameKind
  items : Array[(@library.Point, Array[Json])]
}

///|
priv struct FrameDecoder {
  frames : Map[String, FrameRec]
  fonts : Map[Int, @library.FontInstance]
  images : Map[Int, Array[Json]]
}

///|
fn FrameDecoder::new() -> FrameDecoder {
  { frames: {}, fonts: {}, images: {}, }
}

///|
fn FrameDecoder::document(
  self : FrameDecoder,
  records : Array[Array[Json]],
) -> @layout.PagedDocument raise Unsupported {
  let pages = []
  for rec in records {
    guard rec[0] is String(kind) else { continue }
    match kind {
      "font" => self.fonts[dec_int(rec[1])] = decode_font(rec)
      "image-resource" => self.images[dec_int(rec[1])] = rec
      "page" => pages.push(rec)
      "frame" => {
        guard rec[1] is String(r) else { raise Unsupported("frame id") }
        self.frames[r] = {
          size: dec_size(rec[2]),
          baseline: if rec[3] is Null {
            None
          } else {
            Some(dec_abs(rec[3]))
          },
          kind: if rec[4] is String("hard") {
            Hard
          } else {
            Soft
          },
          items: [],
        }
      }
      "group" | "text" | "shape" | "image" | "link" => {
        guard rec[1] is String(r) else { raise Unsupported("frame id") }
        guard self.frames.get(r) is Some(frame) else {
          raise Unsupported("item before frame")
        }
        frame.items.push((dec_point(rec[3]), rec))
      }
      _ => ()
    }
  }
  let out = []
  for rec in pages {
    let p = dec_int(rec[1])
    let bleed = match rec[3] {
      Array(b) =>
        @library.Sides::new(
          dec_abs(b[0]),
          dec_abs(b[1]),
          dec_abs(b[2]),
          dec_abs(b[3]),
        )
      _ => raise Unsupported("bleed")
    }
    let fill : @library.Smart[@library.Paint?] = match rec[4] {
      String("auto") => Auto
      Null => Custom(None)
      paint => Custom(Some(self.paint(paint)))
    }
    out.push(
      (
        {
          frame: self.frame("p\{p}"),
          bleed,
          fill,
          numbering: None,
          supplement: @library.Content::empty(),
          number: dec_int(rec[2]).to_uint64(),
        } : @layout.Page),
    )
  }
  @layout.PagedDocument::new(
    out,
    @library.DocumentInfo::new(),
    @library.DocumentFormatOptions::new(),
  )
}

///|
fn FrameDecoder::frame(
  self : FrameDecoder,
  r : String,
) -> @library.Frame raise Unsupported {
  guard self.frames.get(r) is Some(rec) else {
    raise Unsupported("missing frame \{r}")
  }
  let frame = @library.Frame::new(rec.size, rec.kind)
  if rec.baseline is Some(b) {
    frame.set_baseline(b)
  }
  for entry in rec.items {
    let (pos, item) = entry
    frame.push(pos, self.item(item))
  }
  frame
}

///|
fn FrameDecoder::item(
  self : FrameDecoder,
  rec : Array[Json],
) -> @library.FrameItem raise Unsupported {
  guard rec[0] is String(kind) else { raise Unsupported("item") }
  match kind {
    "group" => {
      guard rec[4] is String(child) else { raise Unsupported("group child") }
      let group = @library.GroupItem::new(self.frame(child))
      group.transform = dec_transform(rec[5])
      group.clip = if rec[6] is Null { None } else { Some(dec_curve(rec[6])) }
      group.label = match rec[7] {
        String(s) => @library.Label::new(s)
        _ => None
      }
      Group(group)
    }
    "text" => {
      guard self.fonts.get(dec_int(rec[4])) is Some(font) else {
        raise Unsupported("missing font")
      }
      let glyphs = match rec[11] {
        Array(gs) =>
          gs.map(g => {
            guard g is Array(g) else { raise Unsupported("glyph") }
            (
              {
                id: dec_int(g[0]).to_uint16(),
                x_advance: @library.Em::new(dec_f64(g[1])),
                y_advance: @library.Em::new(dec_f64(g[2])),
                x_offset: @library.Em::new(dec_f64(g[3])),
                y_offset: @library.Em::new(dec_f64(g[4])),
                range_start: dec_int(g[5]).to_uint16(),
                range_end: dec_int(g[6]).to_uint16(),
                span: (@syntax.Span::detached(), dec_int(g[8]).to_uint16()),
              } : @library.Glyph)
          })
        _ => raise Unsupported("glyphs")
      }
      Text({
        font,
        size: dec_abs(rec[5]),
        fill: self.paint(rec[6]),
        stroke: self.stroke(rec[7]),
        lang: match rec[8] {
          String(s) => @library.Lang(s)
          _ => raise Unsupported("lang")
        },
        region: match rec[9] {
          String(s) => Some(@library.Region(s))
          _ => None
        },
        text: match rec[10] {
          String(s) => s
          _ => raise Unsupported("text")
        },
        glyphs,
      })
    }
    "shape" => {
      let geometry : @library.Geometry = match rec[4] {
        Array([String("line"), p]) => Line(dec_point(p))
        Array([String("rect"), s]) => Rect(dec_size(s))
        Array([String("curve"), c]) => Curve(dec_curve(c))
        _ => raise Unsupported("geometry")
      }
      Shape(
        {
          geometry,
          fill: if rec[5] is Null {
            None
          } else {
            Some(self.paint(rec[5]))
          },
          fill_rule: if rec[6] is String("even-odd") {
            EvenOdd
          } else {
            NonZero
          },
          stroke: self.stroke(rec[7]),
        },
        @syntax.Span::detached(),
      )
    }
    "image" => {
      guard self.images.get(dec_int(rec[4])) is Some(res) else {
        raise Unsupported("missing image")
      }
      let alt = match rec[6] {
        String(s) => Some(s)
        _ => None
      }
      let scaling : @library.Smart[@library.ImageScaling] = match rec[7] {
        String("smooth") => Custom(Smooth)
        String("pixelated") => Custom(Pixelated)
        _ => Auto
      }
      let image = @library.Image::new(decode_image(res), alt, scaling)
      Image(image, dec_size(rec[5]), @syntax.Span::detached())
    }
    "link" => {
      let dest : @library.Destination = match rec[5] {
        Array([String("url"), String(url)]) => Url(@library.Url(url))
        Array([String("position"), _, p]) =>
          Position({ ..@library.PagedPosition::origin(), point: dec_point(p), })
        Array([String("location"), l]) =>
          Location(
            @library.Location::new(
              @library.U128::from_u64(dec_int(l).to_uint64()),
            ),
          )
        _ => raise Unsupported("link")
      }
      Link(dest, dec_size(rec[4]))
    }
    _ => raise Unsupported("item \{kind}")
  }
}

///|
fn FrameDecoder::stroke(
  self : FrameDecoder,
  json : Json,
) -> @library.FixedStroke? raise Unsupported {
  guard json is Array(s) else { return None }
  Some({
    paint: self.paint(s[0]),
    thickness: dec_abs(s[1]),
    cap: match s[2] {
      String("round") => Round
      String("square") => Square
      _ => Butt
    },
    join: match s[3] {
      String("round") => Round
      String("bevel") => Bevel
      _ => Miter
    },
    dash: match s[4] {
      Array([Array(lengths), phase]) =>
        Some({ array: lengths.map(dec_abs), phase: dec_abs(phase), })
      _ => None
    },
    miter_limit: @library.Ratio::new(dec_f64(s[5])),
  })
}

///|
fn FrameDecoder::paint(
  self : FrameDecoder,
  json : Json,
) -> @library.Paint raise Unsupported {
  guard json is Array(p) && p[0] is String(kind) else {
    raise Unsupported("paint")
  }
  match kind {
    "solid" => Solid(dec_color(p[1]))
    "linear" =>
      Gradient(
        Linear({
          stops: dec_stops(p[1]),
          angle: @library.Angle::raw(dec_f64(p[2])),
          space: dec_space(p[3]),
          relative: dec_relative(p[4]),
          anti_alias: p[5] is True,
        }),
      )
    "radial" =>
      Gradient(
        Radial({
          stops: dec_stops(p[1]),
          center: dec_ratios(p[2]),
          radius: @library.Ratio::new(dec_f64(p[3])),
          focal_center: dec_ratios(p[4]),
          focal_radius: @library.Ratio::new(dec_f64(p[5])),
          space: dec_space(p[6]),
          relative: dec_relative(p[7]),
          anti_alias: p[8] is True,
        }),
      )
    "conic" =>
      Gradient(
        Conic({
          stops: dec_stops(p[1]),
          angle: @library.Angle::raw(dec_f64(p[2])),
          center: dec_ratios(p[3]),
          space: dec_space(p[4]),
          relative: dec_relative(p[5]),
          anti_alias: p[6] is True,
        }),
      )
    "tiling" => {
      guard p[1] is String(r) else { raise Unsupported("tiling frame") }
      Tiling({
        frame: self.frame(r),
        size: dec_size(p[2]),
        spacing: dec_size(p[3]),
        offset: dec_size(p[4]),
        angle: @library.Angle::raw(dec_f64(p[5])),
        relative: dec_relative(p[6]),
      })
    }
    _ => raise Unsupported("paint \{kind}")
  }
}

// Decoders of plain values.

///|
fn dec_int(json : Json) -> Int raise Unsupported {
  match json {
    Number(n, ..) => n.to_int()
    _ => raise Unsupported("integer")
  }
}

///|
fn hex_bits(s : String, prefix : String) -> UInt64 raise Unsupported {
  guard s.has_prefix(prefix) else { raise Unsupported("number \{s}") }
  let mut v : UInt64 = 0
  for c in s.view(start_offset=prefix.length()) {
    let d = match c {
      '0'..='9' => c.to_int() - '0'.to_int()
      'a'..='f' => c.to_int() - 'a'.to_int() + 10
      _ => raise Unsupported("hex digit")
    }
    v = (v << 4) | d.to_uint64()
  }
  v
}

///|
fn dec_f64(json : Json) -> Double raise Unsupported {
  guard json is String(s) else { raise Unsupported("f64") }
  hex_bits(s, "f64:").reinterpret_as_double()
}

///|
fn dec_f32(json : Json) -> Float raise Unsupported {
  guard json is String(s) else { raise Unsupported("f32") }
  hex_bits(s, "f32:").to_uint().reinterpret_as_float()
}

///|
fn dec_abs(json : Json) -> @library.Abs raise Unsupported {
  @library.Abs::raw(dec_f64(json))
}

///|
fn dec_point(json : Json) -> @library.Point raise Unsupported {
  guard json is Array([x, y]) else { raise Unsupported("point") }
  { x: dec_abs(x), y: dec_abs(y), }
}

///|
fn dec_size(json : Json) -> @library.Axes[@library.Abs] raise Unsupported {
  guard json is Array([x, y]) else { raise Unsupported("size") }
  { x: dec_abs(x), y: dec_abs(y), }
}

///|
fn dec_ratios(json : Json) -> @library.Axes[@library.Ratio] raise Unsupported {
  guard json is Array([x, y]) else { raise Unsupported("ratios") }
  { x: @library.Ratio::new(dec_f64(x)), y: @library.Ratio::new(dec_f64(y)), }
}

///|
fn dec_transform(json : Json) -> @library.Transform raise Unsupported {
  guard json is Array([sx, ky, kx, sy, tx, ty]) else {
    raise Unsupported("transform")
  }
  {
    sx: @library.Ratio::new(dec_f64(sx)),
    ky: @library.Ratio::new(dec_f64(ky)),
    kx: @library.Ratio::new(dec_f64(kx)),
    sy: @library.Ratio::new(dec_f64(sy)),
    tx: dec_abs(tx),
    ty: dec_abs(ty),
  }
}

///|
fn dec_curve(json : Json) -> @library.Curve raise Unsupported {
  guard json is Array(cmds) else { raise Unsupported("curve") }
  let curve = @library.Curve::new()
  for cmd in cmds {
    match cmd {
      Array([String("M"), p]) => curve.move_(dec_point(p))
      Array([String("L"), p]) => curve.line(dec_point(p))
      Array([String("C"), a, b, c]) =>
        curve.cubic(dec_point(a), dec_point(b), dec_point(c))
      Array([String("Z")]) => curve.close()
      _ => raise Unsupported("curve command")
    }
  }
  curve
}

///|
fn dec_relative(json : Json) -> @library.Smart[@library.RelativeTo] {
  match json {
    String("self") => Custom(Self_)
    String("parent") => Custom(Parent)
    _ => Auto
  }
}

///|
fn dec_stops(
  json : Json,
) -> Array[(@library.Color, @library.Ratio)] raise Unsupported {
  guard json is Array(stops) else { raise Unsupported("stops") }
  stops.map(s => {
    guard s is Array([c, r]) else { raise Unsupported("stop") }
    (dec_color(c), @library.Ratio::new(dec_f64(r)))
  })
}

///|
fn dec_process_color(json : Json) -> @library.ProcessColor raise Unsupported {
  guard json is Array(c) && c[0] is String(kind) else {
    raise Unsupported("color")
  }
  let v = (i : Int) => dec_f32(c[i])
  match kind {
    "Luma" => Luma({ luma: v(1), alpha: v(2), })
    "Oklab" => Oklab({ l: v(1), a: v(2), b: v(3), alpha: v(4), })
    "Oklch" => Oklch({ l: v(1), chroma: v(2), hue: v(3), alpha: v(4), })
    "Rgb" => Rgb({ red: v(1), green: v(2), blue: v(3), alpha: v(4), })
    "LinearRgb" =>
      LinearRgb({ red: v(1), green: v(2), blue: v(3), alpha: v(4), })
    "Cmyk" => Cmyk({ c: v(1), m: v(2), y: v(3), k: v(4), })
    "Hsl" => Hsl({ hue: v(1), saturation: v(2), lightness: v(3), alpha: v(4), })
    "Hsv" => Hsv({ hue: v(1), saturation: v(2), value: v(3), alpha: v(4), })
    _ => raise Unsupported("color \{kind}")
  }
}

///|
fn dec_colorant(json : Json) -> @library.SpotColorant raise Unsupported {
  guard json is Array([name, fallback]) else { raise Unsupported("colorant") }
  {
    name: match name {
      Array([String("All")]) => Some(All)
      Array([String("Custom"), String(s)]) => Some(Custom(s))
      _ => None
    },
    fallback: dec_process_color(fallback),
  }
}

///|
fn dec_color(json : Json) -> @library.Color raise Unsupported {
  match json {
    Array([String("Spot"), c, tint]) =>
      Spot({
        colorant: dec_colorant(c),
        tint: @library.Ratio::new(dec_f64(tint)),
      })
    _ => Process(dec_process_color(json))
  }
}

///|
fn dec_space(json : Json) -> @library.ColorSpace raise Unsupported {
  match json {
    String("Oklab") => Process(Oklab)
    String("Oklch") => Process(Oklch)
    String("Srgb") => Process(Srgb)
    String("D65Gray") => Process(D65Gray)
    String("LinearRgb") => Process(LinearRgb)
    String("Hsl") => Process(Hsl)
    String("Hsv") => Process(Hsv)
    String("Cmyk") => Process(Cmyk)
    Array([String("Spot"), c]) => Spot(dec_colorant(c))
    _ => raise Unsupported("color space")
  }
}

///|
/// Find a test font by the SHA-256 of its data and its index, and
/// instantiate it with the recorded variations.
fn decode_font(rec : Array[Json]) -> @library.FontInstance raise Unsupported {
  guard rec[2] is String(sha) else { raise Unsupported("font sha") }
  let index = dec_int(rec[3])
  let variations = match rec[4] {
    Array(vs) =>
      vs.map(v => {
        guard v is Array([String(tag), value]) else {
          raise Unsupported("variation")
        }
        (
          @library.OpenTypeTag::from_bytes_lossy(tag),
          @library.AxisValue::new(dec_f32(value)),
        )
      })
    _ => raise Unsupported("variations")
  }
  for font in test_fonts() {
    if font.index().reinterpret_as_int() == index &&
      asset_sha256(font.data()) == sha {
      return font.instantiate_with(@library.FontVariations(variations))
    }
  }
  raise Unsupported("unknown font")
}

///|
/// The files of `typst-dev-assets` that tests embed as images, by the
/// SHA-256 of their data.
fn image_assets() -> Map[String, Bytes] {
  if image_assets_cell.val is Some(m) {
    return m
  }
  let m = {}
  fn walk(dir : String) {
    let entries = (@fs.read_dir(dir) catch { _ => [][:] }).to_array()
    for entry in entries {
      let path = dir + "/" + entry
      let is_dir = @fs.is_dir(path) catch { _ => false }
      if is_dir {
        walk(path)
      } else {
        let data = @fs.read_file_to_bytes(path) catch { _ => continue }
        m[sha256_hex(data[:])] = data
      }
    }
  }

  let root = dev_assets_root()
  for dir in ["images", "icons", "screenshots", "data", "text"] {
    walk(root + "/" + dir)
  }
  image_assets_cell.val = Some(m)
  m
}

///|
let image_assets_cell : Ref[Map[String, Bytes]?] = Ref::new(None)

///|
/// Reconstruct an image from its `image-resource` record.
fn decode_image(rec : Array[Json]) -> @library.ImageKind raise Unsupported {
  guard rec[2] is String(kind) && rec[3] is String(sha) else {
    raise Unsupported("image resource")
  }
  guard rec[5] is Array([w, h]) else { raise Unsupported("image size") }
  let width = dec_f64(w)
  let height = dec_f64(h)
  let format : @library.ExchangeFormat = match kind {
    "png" => Png
    "jpg" => Jpg
    "gif" => Gif
    "webp" => Webp
    "svg" => {
      guard image_assets().get(sha) is Some(data) else {
        raise Unsupported("unknown svg image")
      }
      return Svg(@library.SvgImage::synthetic(data, width, height))
    }
    "pdf" => {
      guard image_assets().get(sha) is Some(data) else {
        raise Unsupported("unknown pdf image")
      }
      guard rec[4] is Number(page_index, ..) else {
        raise Unsupported("pdf page index")
      }
      let document = @library.PdfDocument::new(data) catch {
        _ => raise Unsupported("invalid pdf image")
      }
      guard @library.PdfImage::new(document, page_index.to_int()) is Some(image) else {
        raise Unsupported("invalid pdf page")
      }
      return Pdf(image)
    }
    _ => raise Unsupported("\{kind} image")
  }
  guard image_assets().get(sha) is Some(data) else {
    raise Unsupported("unknown \{kind} image")
  }
  let dpi = match rec[6] {
    Null => None
    d => Some(dec_f64(d))
  }
  Raster(
    @library.RasterImage::synthetic(
      data,
      Exchange(format),
      width=width.to_int().reinterpret_as_uint(),
      height=height.to_int().reinterpret_as_uint(),
      dpi?,
    ),
  )
}
