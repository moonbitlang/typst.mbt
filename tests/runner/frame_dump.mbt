// Encoder of the `typst-frame-v1` format: a `PagedDocument` as canonical
// JSON records, one per line. The format is specified in
// `oracle/src/paged.rs`, whose encoder this mirrors record by record.

///|
/// Encodes a paged document as `typst-frame-v1` records.
priv struct FrameEncoder {
  out : StringBuilder
  /// Encodes spans (`null` or `[path,start,end]`).
  span_enc : (@syntax.Span) -> String
  /// Shared with canonical content (location numbering).
  dumper : Dumper
  fonts : Map[String, Int]
  images : Map[String, Int]
  contents : Map[String, Int]
  keys : Map[@library.U128, Int]
}

///|
fn FrameEncoder::new(span_enc : (@syntax.Span) -> String) -> FrameEncoder {
  {
    out: StringBuilder(),
    span_enc,
    dumper: Dumper::new(),
    fonts: {},
    images: {},
    contents: {},
    keys: {},
  }
}

///|
/// Write a record.
fn FrameEncoder::record(self : FrameEncoder, fields : Array[String]) -> Unit {
  self.out.write_char('[')
  self.out.write_string(fields.join(","))
  self.out.write_string("]\n")
}

///|
fn FrameEncoder::header(
  self : FrameEncoder,
  revision : String,
  manifest_sha : String,
  name : String,
) -> Unit {
  self.record([
    json_str("header"),
    json_str("typst-frame-v1"),
    json_str(revision),
    json_str(manifest_sha),
    json_str(name),
  ])
}

///|
/// The diagnostics record; `lines` are diagnostic lines in the format of the
/// other stages (without trailing newlines).
fn FrameEncoder::diagnostics(
  self : FrameEncoder,
  status : String,
  lines : Array[String],
) -> Unit {
  self.record([
    json_str("diagnostics"),
    json_str(status),
    array(lines.map(json_str)),
  ])
}

///|
fn FrameEncoder::end(self : FrameEncoder) -> Unit {
  self.record([json_str("end")])
}

///|
fn FrameEncoder::document(
  self : FrameEncoder,
  doc : @layout.PagedDocument,
) -> Unit {
  let pages = doc.pages()
  self.record([
    json_str("document"),
    info_enc(doc.info()),
    self.format_options(doc.options()),
    pages.length().to_string(),
  ])
  for p, page in pages {
    let supplement = self.content(page.supplement)
    let r = "p\{p}"
    let deferred = []
    let fill = match page.fill {
      Auto => json_str("auto")
      Custom(None) => "null"
      Custom(Some(paint)) => self.paint(paint, "\{r}/fill", deferred)
    }
    let numbering = match page.numbering {
      Some(n) => json_str(@library.IntoValue::into_value(n).repr())
      None => "null"
    }
    let bleed = page.bleed
    self.record([
      json_str("page"),
      p.to_string(),
      page.number.to_string(),
      array([bleed.left, bleed.top, bleed.right, bleed.bottom].map(abs_enc)),
      fill,
      numbering,
      supplement.to_string(),
    ])
    self.frames(deferred)
    self.frame(page.frame, r)
  }
}

///|
fn FrameEncoder::format_options(
  self : FrameEncoder,
  options : @library.DocumentFormatOptions,
) -> String {
  let formats = []
  for format in options.0 {
    let fields = []
    for field in format.elem.fields() {
      if field.kind is (Settable | Ghost) {
        let v = format.get(field.id)
        fields.push(
          array([
            json_str(field.name),
            json_str(v.v.repr()),
            (self.span_enc)(v.span),
          ]),
        )
      }
    }
    formats.push(array([json_str(format.elem.name()), array(fields)]))
  }
  array(formats)
}

///|
/// The id of some content, emitting its record if it is new.
fn FrameEncoder::content(
  self : FrameEncoder,
  content : @library.Content,
) -> Int {
  let encoded = self.dumper.content(content)
  if self.contents.get(encoded) is Some(id) {
    return id
  }
  let id = self.contents.length()
  self.contents[encoded] = id
  self.record([json_str("content"), id.to_string(), json_str(encoded)])
  id
}

///|
fn FrameEncoder::location(self : FrameEncoder, loc : @library.Location) -> Int {
  self.dumper.loc_id(loc)
}

///|
fn FrameEncoder::key(self : FrameEncoder, key : @library.U128) -> Int {
  match self.keys.get(key) {
    Some(id) => id
    None => {
      let id = self.keys.length()
      self.keys[key] = id
      id
    }
  }
}

///|
/// Emit the records of deferred (tiling) frames.
fn FrameEncoder::frames(
  self : FrameEncoder,
  deferred : Array[(@library.Frame, String)],
) -> Unit {
  for entry in deferred {
    self.frame(entry.0, entry.1)
  }
}

///|
fn FrameEncoder::frame(
  self : FrameEncoder,
  frame : @library.Frame,
  r : String,
) -> Unit {
  let baseline = if frame.has_baseline() {
    abs_enc(frame.baseline())
  } else {
    "null"
  }
  let kind = if frame.kind().is_hard() { "hard" } else { "soft" }
  let items = frame.items()
  self.record([
    json_str("frame"),
    json_str(r),
    size_enc(frame.size()),
    baseline,
    json_str(kind),
    items.length().to_string(),
  ])
  for i, entry in items {
    self.item(r, i, entry.0, entry.1)
  }
}

///|
fn FrameEncoder::item(
  self : FrameEncoder,
  r : String,
  i : Int,
  pos : @library.Point,
  item : @library.FrameItem,
) -> Unit {
  let head = (kind : String) => {
    [json_str(kind), json_str(r), i.to_string(), point_enc(pos)]
  }
  let deferred = []
  match item {
    Group(group) => {
      let child = "\{r}/\{i}"
      let clip = match group.clip {
        Some(curve) => commands_enc(curve)
        None => "null"
      }
      let label = match group.label {
        Some(label) => json_str(label.resolve())
        None => "null"
      }
      let parent = match group.parent {
        Some(parent) => {
          let l = self.location(parent.location)
          array([l.to_string(), (parent.inherit_ is Yes).to_string()])
        }
        None => "null"
      }
      let rec = head("group")
      rec.append([
        json_str(child),
        transform_enc(group.transform),
        clip,
        label,
        parent,
      ])
      self.record(rec)
      self.frame(group.frame, child)
    }
    Text(text) => {
      let f = self.font(text.font)
      let fill = self.paint(text.fill, "\{r}/\{i}/fill", deferred)
      let stroke = self.stroke(text.stroke, "\{r}/\{i}/stroke", deferred)
      let rec = head("text")
      rec.append([
        f.to_string(),
        abs_enc(text.size),
        fill,
        stroke,
        json_str(text.lang.as_str()),
        match text.region {
          Some(region) => json_str(region.as_str())
          None => "null"
        },
        json_str(text.text),
        self.glyphs(text),
      ])
      self.record(rec)
    }
    Shape(shape, span) => {
      let fill = match shape.fill {
        Some(paint) => self.paint(paint, "\{r}/\{i}/fill", deferred)
        None => "null"
      }
      let stroke = self.stroke(shape.stroke, "\{r}/\{i}/stroke", deferred)
      let fill_rule = match shape.fill_rule {
        NonZero => "non-zero"
        EvenOdd => "even-odd"
      }
      let rec = head("shape")
      rec.append([
        geometry_enc(shape.geometry),
        fill,
        json_str(fill_rule),
        stroke,
        (self.span_enc)(span),
      ])
      self.record(rec)
    }
    Image(image, size, span) => {
      let id = self.image(image)
      let alt = match image.alt() {
        Some(alt) => json_str(alt)
        None => "null"
      }
      let scaling = match image.scaling() {
        Auto => "auto"
        Custom(Smooth) => "smooth"
        Custom(Pixelated) => "pixelated"
      }
      let rec = head("image")
      rec.append([
        id.to_string(),
        size_enc(size),
        alt,
        json_str(scaling),
        (self.span_enc)(span),
      ])
      self.record(rec)
    }
    Link(dest, size) => {
      let dest = match dest {
        Url(url) => array([json_str("url"), json_str(url.0)])
        Position(pos) =>
          array([
            json_str("position"),
            pos.page.0.to_string(),
            point_enc(pos.point),
          ])
        Location(loc) =>
          array([json_str("location"), self.location(loc).to_string()])
      }
      let rec = head("link")
      rec.append([size_enc(size), dest])
      self.record(rec)
    }
    Tag(Start(elem, flags)) => {
      let l = self.location(elem.location().unwrap())
      let c = self.content(elem)
      let rec = head("tag-start")
      rec.append([l.to_string(), c.to_string()])
      rec.append(tag_flags_enc(flags))
      self.record(rec)
    }
    Tag(End(loc, key, flags)) => {
      let l = self.location(loc)
      let k = self.key(key)
      let rec = head("tag-end")
      rec.append([l.to_string(), k.to_string()])
      rec.append(tag_flags_enc(flags))
      self.record(rec)
    }
  }
  self.frames(deferred)
}

///|
fn FrameEncoder::glyphs(
  self : FrameEncoder,
  text : @library.TextItem,
) -> String {
  array(
    text.glyphs.map(g => {
      array([
        g.id.to_string(),
        f64_hex(g.x_advance.get()),
        f64_hex(g.y_advance.get()),
        f64_hex(g.x_offset.get()),
        f64_hex(g.y_offset.get()),
        g.range_start.to_string(),
        g.range_end.to_string(),
        (self.span_enc)(g.span),
        g.span_offset.to_string(),
      ])
    }),
  )
}

///|
/// The id of a font instance, emitting its record if it is new.
fn FrameEncoder::font(self : FrameEncoder, font : @library.FontInstance) -> Int {
  let inner = font.font()
  let variations = array(
    font.variations().0.map(v => {
      array([json_str(v.0.to_str_lossy()), f32_hex(Float::from_double(v.1.0))])
    }),
  )
  let fields = [
    json_str(asset_sha256(inner.data())),
    inner.index().to_string(),
    variations,
    json_str(inner.family()),
    match inner.post_script_name() {
      Some(name) => json_str(name)
      None => "null"
    },
    f64_hex(font.units_per_em()),
  ]
  let key = fields.join(",")
  if self.fonts.get(key) is Some(id) {
    return id
  }
  let id = self.fonts.length()
  self.fonts[key] = id
  self.out.write_string("[\{json_str("font")},\{id},\{key}]\n")
  id
}

///|
/// The id of an image, emitting its record if it is new.
fn FrameEncoder::image(self : FrameEncoder, image : @library.Image) -> Int {
  let (kind, sha, page_index, exif, icc) = match image.kind() {
    Raster(raster) => {
      let kind = match raster.format() {
        Exchange(Png) => "png"
        Exchange(Jpg) => "jpg"
        Exchange(Gif) => "gif"
        Exchange(Webp) => "webp"
        Pixel(format) =>
          match format.encoding {
            Rgb8 => "rgb8"
            Rgba8 => "rgba8"
            Luma8 => "luma8"
            Lumaa8 => "lumaa8"
          }
      }
      let exif = match raster.exif_rotation() {
        Some(r) => r.to_string()
        None => "null"
      }
      let icc = match raster.icc() {
        Some(icc) => json_str(asset_sha256(icc))
        None => "null"
      }
      (kind, asset_sha256(raster.data()), "null", exif, icc)
    }
    Svg(svg) => ("svg", asset_sha256(svg.data()), "null", "null", "null")
    Pdf(pdf) =>
      (
        "pdf",
        asset_sha256(pdf.document().data()),
        pdf.page_index().to_string(),
        "null",
        "null",
      )
  }
  let dpi = match image.dpi() {
    Some(dpi) => f64_hex(dpi)
    None => "null"
  }
  let fields = [
    json_str(kind),
    json_str(sha),
    page_index,
    array([f64_hex(image.width()), f64_hex(image.height())]),
    dpi,
    exif,
    icc,
    "null",
  ]
  let key = fields.join(",")
  if self.images.get(key) is Some(id) {
    return id
  }
  let id = self.images.length()
  self.images[key] = id
  self.out.write_string("[\{json_str("image-resource")},\{id},\{key}]\n")
  id
}

///|
fn FrameEncoder::stroke(
  self : FrameEncoder,
  stroke : @library.FixedStroke?,
  r : String,
  deferred : Array[(@library.Frame, String)],
) -> String {
  guard stroke is Some(stroke) else { return "null" }
  let cap = match stroke.cap {
    Butt => "butt"
    Round => "round"
    Square => "square"
  }
  let join = match stroke.join {
    Miter => "miter"
    Round => "round"
    Bevel => "bevel"
  }
  let dash = match stroke.dash {
    Some(dash) => array([array(dash.array.map(abs_enc)), abs_enc(dash.phase)])
    None => "null"
  }
  array([
    self.paint(stroke.paint, r, deferred),
    abs_enc(stroke.thickness),
    json_str(cap),
    json_str(join),
    dash,
    ratio_enc(stroke.miter_limit),
  ])
}

///|
fn FrameEncoder::paint(
  self : FrameEncoder,
  paint : @library.Paint,
  r : String,
  deferred : Array[(@library.Frame, String)],
) -> String {
  ignore(self)
  match paint {
    Solid(color) => array([json_str("solid"), color_enc(color)])
    Gradient(Linear(g)) =>
      array([
        json_str("linear"),
        stops_enc(g.stops),
        angle_enc(g.angle),
        space_enc(g.space),
        relative_enc(g.relative),
        g.anti_alias.to_string(),
      ])
    Gradient(Radial(g)) =>
      array([
        json_str("radial"),
        stops_enc(g.stops),
        ratios_enc(g.center),
        ratio_enc(g.radius),
        ratios_enc(g.focal_center),
        ratio_enc(g.focal_radius),
        space_enc(g.space),
        relative_enc(g.relative),
        g.anti_alias.to_string(),
      ])
    Gradient(Conic(g)) =>
      array([
        json_str("conic"),
        stops_enc(g.stops),
        angle_enc(g.angle),
        ratios_enc(g.center),
        space_enc(g.space),
        relative_enc(g.relative),
        g.anti_alias.to_string(),
      ])
    Tiling(tiling) => {
      deferred.push((tiling.frame.clone(), r))
      array([
        json_str("tiling"),
        json_str(r),
        size_enc(tiling.size),
        size_enc(tiling.spacing),
        size_enc(tiling.offset),
        angle_enc(tiling.angle),
        relative_enc(tiling.relative),
      ])
    }
  }
}

// Encoders of plain values.

///|
fn info_enc(info : @library.DocumentInfo) -> String {
  let opt = (s : String?) => {
    match s {
      Some(s) => json_str(s)
      None => "null"
    }
  }
  let list = (l : Array[String]) => array(l.map(json_str))
  let date = match info.date {
    Auto => "auto"
    Custom(None) => "none"
    Custom(Some(d)) => d.repr()
  }
  let locale = match info.locale {
    Auto => "auto"
    Custom(l) => l.rfc_3066()
  }
  array([
    opt(info.title),
    list(info.author),
    opt(info.description),
    list(info.keywords),
    json_str(date),
    json_str(locale),
  ])
}

///|
fn tag_flags_enc(flags : @library.TagFlags) -> Array[String] {
  [flags.introspectable.to_string(), flags.tagged.to_string()]
}

///|
fn geometry_enc(geometry : @library.Geometry) -> String {
  match geometry {
    Line(p) => array([json_str("line"), point_enc(p)])
    Rect(s) => array([json_str("rect"), size_enc(s)])
    Curve(c) => array([json_str("curve"), commands_enc(c)])
  }
}

///|
fn commands_enc(curve : @library.Curve) -> String {
  array(
    curve
    .items()
    .map(item => {
      match item {
        Move(p) => array([json_str("M"), point_enc(p)])
        Line(p) => array([json_str("L"), point_enc(p)])
        Cubic(a, b, c) =>
          array([json_str("C"), point_enc(a), point_enc(b), point_enc(c)])
        Close => array([json_str("Z")])
      }
    }),
  )
}

///|
fn color_enc(color : @library.Color) -> String {
  match color {
    Process(c) => process_color_enc(c)
    Spot(s) =>
      array([json_str("Spot"), colorant_enc(s.colorant), ratio_enc(s.tint)])
  }
}

///|
fn process_color_enc(color : @library.ProcessColor) -> String {
  let f = (name : String, cs : Array[Float]) => {
    let items = [json_str(name)]
    items.append(cs.map(f32_hex))
    array(items)
  }
  match color {
    Luma(c) => f("Luma", [c.luma, c.alpha])
    Oklab(c) => f("Oklab", [c.l, c.a, c.b, c.alpha])
    Oklch(c) => f("Oklch", [c.l, c.chroma, c.hue, c.alpha])
    Rgb(c) => f("Rgb", [c.red, c.green, c.blue, c.alpha])
    LinearRgb(c) => f("LinearRgb", [c.red, c.green, c.blue, c.alpha])
    Cmyk(c) => f("Cmyk", [c.c, c.m, c.y, c.k])
    Hsl(c) => f("Hsl", [c.hue, c.saturation, c.lightness, c.alpha])
    Hsv(c) => f("Hsv", [c.hue, c.saturation, c.value, c.alpha])
  }
}

///|
fn colorant_enc(colorant : @library.SpotColorant) -> String {
  let name = match colorant.name {
    None => "null"
    Some(All) => array([json_str("All")])
    Some(Custom(s)) => array([json_str("Custom"), json_str(s)])
  }
  array([name, process_color_enc(colorant.fallback)])
}

///|
fn space_enc(space : @library.ColorSpace) -> String {
  match space {
    Process(s) =>
      json_str(
        match s {
          Oklab => "Oklab"
          Oklch => "Oklch"
          Srgb => "Srgb"
          D65Gray => "D65Gray"
          LinearRgb => "LinearRgb"
          Hsl => "Hsl"
          Hsv => "Hsv"
          Cmyk => "Cmyk"
        },
      )
    Spot(c) => array([json_str("Spot"), colorant_enc(c)])
  }
}

///|
fn stops_enc(stops : Array[(@library.Color, @library.Ratio)]) -> String {
  array(stops.map(s => array([color_enc(s.0), ratio_enc(s.1)])))
}

///|
fn relative_enc(relative : @library.Smart[@library.RelativeTo]) -> String {
  json_str(
    match relative {
      Auto => "auto"
      Custom(Self_) => "self"
      Custom(Parent) => "parent"
    },
  )
}

///|
fn transform_enc(ts : @library.Transform) -> String {
  array([
    ratio_enc(ts.sx),
    ratio_enc(ts.ky),
    ratio_enc(ts.kx),
    ratio_enc(ts.sy),
    abs_enc(ts.tx),
    abs_enc(ts.ty),
  ])
}

///|
fn point_enc(p : @library.Point) -> String {
  array([abs_enc(p.x), abs_enc(p.y)])
}

///|
fn size_enc(s : @library.Axes[@library.Abs]) -> String {
  array([abs_enc(s.x), abs_enc(s.y)])
}

///|
fn ratios_enc(r : @library.Axes[@library.Ratio]) -> String {
  array([ratio_enc(r.x), ratio_enc(r.y)])
}

///|
fn abs_enc(v : @library.Abs) -> String {
  f64_hex(v.to_raw())
}

///|
fn ratio_enc(v : @library.Ratio) -> String {
  f64_hex(v.get())
}

///|
fn angle_enc(v : @library.Angle) -> String {
  f64_hex(v.to_raw())
}

///|
/// An `f64` as `"f64:"` plus its 16 lowercase hex IEEE-754 digits.
fn f64_hex(v : Double) -> String {
  "\"f64:\{hex_padded(v.reinterpret_as_uint64(), 16)}\""
}

///|
/// An `f32` as `"f32:"` plus its 8 lowercase hex IEEE-754 digits.
fn f32_hex(v : Float) -> String {
  "\"f32:\{hex_padded(v.reinterpret_as_uint().to_uint64(), 8)}\""
}

///|
fn array(items : Array[String]) -> String {
  "[" + items.join(",") + "]"
}

///|
/// Encode a string as a JSON string literal. Only `"`, `\` and control
/// characters below U+0020 are escaped (as `\b`, `\t`, `\n`, `\f`, `\r` or
/// `\u00xx` with lowercase hex digits); everything else is emitted as is.
fn json_str(s : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for c in s {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\b' => out.write_string("\\b")
      '\t' => out.write_string("\\t")
      '\n' => out.write_string("\\n")
      '\u{c}' => out.write_string("\\f")
      '\r' => out.write_string("\\r")
      c if c.to_int() < 0x20 =>
        out.write_string("\\u\{hex_padded(c.to_int().to_uint64(), 4)}")
      c => out.write_char(c)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// SHA-256 digests of asset data, cached by identity (fonts are large and
/// shared by all tests).
let asset_digests : Array[(Bytes, String)] = []

///|
/// The SHA-256 of an asset's data.
fn asset_sha256(data : Bytes) -> String {
  for entry in asset_digests {
    if physical_equal(entry.0, data) {
      return entry.1
    }
  }
  let digest = sha256_hex(data[:])
  asset_digests.push((data, digest))
  digest
}
