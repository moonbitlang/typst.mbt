// The `font` stage: dumps what `otf` reports for every font of the test
// world, in the format of `oracle/src/font.rs`.

///|
fn run_font_stage(filter : String?, verbose : Bool) -> Unit {
  let mut passed = 0
  let mut failed = 0
  let mut index = 0
  for file in test_font_files() {
    let (path, bytes) = file
    let data = bytes[:]
    let count = @otf.fonts_in_collection(data).unwrap_or(1)
    for face_index in 0U..<count {
      let name = (if index < 10 { "0" } else { "" }) + index.to_string()
      if filter is Some(f) && !path.contains(f) && name != f {
        index += 1
        continue
      }
      let text = StringBuilder::new()
      font_dump_face(text, index, data, face_index)
      let actual = text.to_string()
      if dump_actual.val {
        let out = "_build/actual/font/\{name}.txt"
        ensure_parent_dir(out)
        @fs.write_string_to_file(out, actual) catch {
          _ => ()
        }
      }
      let expected = read(golden_dir + "/font/\{name}.txt")
      if actual == expected {
        passed += 1
      } else {
        failed += 1
        println("FAIL font \{name} \{path}")
        if verbose {
          println(first_diff(expected, actual))
        }
      }
      index += 1
    }
  }
  println("font: \{passed} passed, \{failed} failed")
}

///|
/// FNV-1a 64-bit hash of an ASCII string.
fn fnv(s : String) -> UInt64 {
  let mut h : UInt64 = 0xcbf29ce484222325UL
  for i in 0..<s.length() {
    h = h ^ s.code_unit_at(i).to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
/// FNV-1a 64-bit hash of bytes.
fn fnv_bytes(data : BytesView) -> UInt64 {
  let mut h : UInt64 = 0xcbf29ce484222325UL
  for b in data {
    h = h ^ b.to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
/// Zero-padded lowercase hex.
fn hex_pad(n : UInt64, width : Int) -> String {
  let digits = "0123456789abcdef"
  let buf = StringBuilder::new()
  let chars = []
  let mut v = n
  while v != 0 {
    chars.push(digits.code_unit_at((v & 15).to_int()).unsafe_to_char())
    v = v >> 4
  }
  for _ in chars.length()..<width {
    buf.write_char('0')
  }
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn hex16(n : UInt64) -> String {
  hex_pad(n, 16)
}

///|
/// Escapes a string to printable ASCII.
fn esc(s : String) -> String {
  let out = StringBuilder::new()
  for c in s {
    if c >= ' ' && c <= '~' && c != '"' && c != '\\' {
      out.write_char(c)
    } else {
      out.write_string("\\u{" + hex_pad(c.to_int().to_uint64(), 0) + "}")
    }
  }
  out.to_string()
}

///|
/// An f32 printed as Rust's `Display` of the value widened to f64.
fn ff(x : Float) -> String {
  @library.rust_display_f64(x.to_double())
}

///|
fn[T : Show] fopt(v : T?) -> String {
  match v {
    Some(v) => v.to_string()
    None => "-"
  }
}

///|
priv struct PathBuilder {
  buf : StringBuilder
}

///|
impl @otf.OutlineBuilder for PathBuilder with fn move_to(self, x, y) {
  self.buf.write_string("M \{ff(x)} \{ff(y)} ")
}

///|
impl @otf.OutlineBuilder for PathBuilder with fn line_to(self, x, y) {
  self.buf.write_string("L \{ff(x)} \{ff(y)} ")
}

///|
impl @otf.OutlineBuilder for PathBuilder with fn quad_to(self, x1, y1, x, y) {
  self.buf.write_string("Q \{ff(x1)} \{ff(y1)} \{ff(x)} \{ff(y)} ")
}

///|
impl @otf.OutlineBuilder for PathBuilder with fn curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  self.buf.write_string(
    "C \{ff(x1)} \{ff(y1)} \{ff(x2)} \{ff(y2)} \{ff(x)} \{ff(y)} ",
  )
}

///|
impl @otf.OutlineBuilder for PathBuilder with fn close(self) {
  self.buf.write_string("Z ")
}

///|
fn font_rect(r : @otf.Rect?) -> String {
  match r {
    Some(r) => "\{r.x_min},\{r.y_min},\{r.x_max},\{r.y_max}"
    None => "-"
  }
}

///|
fn font_line_metrics(m : @otf.LineMetrics?) -> String {
  match m {
    Some(m) => "\{m.position} \{m.thickness}"
    None => "-"
  }
}

///|
fn font_script_metrics(m : @otf.ScriptMetrics?) -> String {
  match m {
    Some(m) => "\{m.x_size} \{m.y_size} \{m.x_offset} \{m.y_offset}"
    None => "-"
  }
}

///|
fn font_platform(p : @otf.PlatformId) -> String {
  match p {
    Unicode => "Unicode"
    Macintosh => "Macintosh"
    Iso => "Iso"
    Windows => "Windows"
    Custom => "Custom"
  }
}

///|
fn font_style(s : @otf.Style) -> String {
  match s {
    Normal => "Normal"
    Italic => "Italic"
    Oblique => "Oblique"
  }
}

///|
fn font_permissions(p : @otf.Permissions?) -> String {
  match p {
    Some(Installable) => "Installable"
    Some(Restricted) => "Restricted"
    Some(PreviewAndPrint) => "PreviewAndPrint"
    Some(Editable) => "Editable"
    None => "-"
  }
}

///|
fn font_raster_format(f : @otf.RasterImageFormat) -> String {
  match f {
    PNG => "PNG"
    BitmapMono => "BitmapMono"
    BitmapMonoPacked => "BitmapMonoPacked"
    BitmapGray2 => "BitmapGray2"
    BitmapGray2Packed => "BitmapGray2Packed"
    BitmapGray4 => "BitmapGray4"
    BitmapGray4Packed => "BitmapGray4Packed"
    BitmapGray8 => "BitmapGray8"
    BitmapPremulBgra32 => "BitmapPremulBgra32"
  }
}

///|
/// Whether a glyph is printed in full.
fn is_sample(gid : Int, count : Int) -> Bool {
  gid < 40 || gid % 397 == 0 || gid + 1 == count
}

///|
fn font_dump_face(
  out : StringBuilder,
  index : Int,
  data : BytesView,
  face_index : UInt,
) -> Unit {
  out.write_string(
    "font \{index} face \{face_index} len \{data.length()} fnv \{hex16(fnv_bytes(data))}\n",
  )
  let face = @otf.Face::parse(data, face_index) catch {
    err => {
      out.write_string("error \{err}\n")
      return
    }
  }
  for record in face.raw_face().table_records.iter() {
    out.write_string(
      "table \{esc(record.tag.to_string())} \{hex_pad(record.check_sum.to_uint64(), 8)} \{record.offset} \{record.length}\n",
    )
  }
  font_dump_metrics(out, face)
  out.write_string("permissions \{font_permissions(face.permissions())}\n")
  out.write_string("is_subsetting_allowed \{face.is_subsetting_allowed()}\n")
  out.write_string(
    "is_outline_embedding_allowed \{face.is_outline_embedding_allowed()}\n",
  )
  let ranges = face.unicode_ranges()
  out.write_string("unicode_ranges \{hex16(ranges.hi)}\{hex16(ranges.lo)}\n")
  out.write_string(
    "style \{font_style(face.style())} weight \{face.weight().to_number()} width \{face.width().to_number()} italic_angle \{ff(face.italic_angle())}\n",
  )
  out.write_string(
    "flags regular=\{face.is_regular()} italic=\{face.is_italic()} bold=\{face.is_bold()} oblique=\{face.is_oblique()} monospaced=\{face.is_monospaced()} variable=\{face.is_variable()}\n",
  )
  let mut i = 0
  for name in face.names().iter() {
    let text = match name.to_string() {
      Some(s) => "\"" + esc(s) + "\""
      None => {
        let buf = StringBuilder::new()
        buf.write_string("bytes:")
        for b in name.name {
          buf.write_string(hex_pad(b.to_uint64(), 2))
        }
        buf.to_string()
      }
    }
    out.write_string(
      "name \{i} \{font_platform(name.platform_id)} \{name.encoding_id} \{name.language_id} \{name.name_id} lang=\"\{esc(name.language().to_string())}\" \{text}\n",
    )
    i += 1
  }
  font_dump_cmap(out, face)
  font_dump_kern(out, face)
  font_dump_cff(out, face)
  font_dump_glyphs(out, face, "")
  font_dump_layout(out, face)
  font_dump_math(out, face)
  font_dump_colr(out, face)

  // Variations.
  let axes = face.variation_axes().iter().to_array()
  for axis in axes {
    out.write_string(
      "axis \{esc(axis.tag.to_string())} min \{ff(axis.min_value)} def \{ff(axis.def_value)} max \{ff(axis.max_value)} name_id \{axis.name_id} hidden \{axis.hidden}\n",
    )
  }
  if face.is_variable() {
    let instances : Array[(String, (@otf.VariationAxis) -> Float)] = [
      ("min", a => a.min_value),
      ("max", a => a.max_value),
      ("mid", a => (a.def_value + a.max_value) / 2.0),
    ]
    for inst in instances {
      let (label, value) = inst
      let face = face.clone()
      for axis in axes {
        face.set_variation(axis.tag, value(axis)) |> ignore
      }
      let coords = face
        .variation_coordinates()
        .iter()
        .map(c => c.get().to_string())
        .to_array()
      out.write_string("instance \{label} coords \{coords.join(" ")}\n")
      font_dump_metrics(out, face)
      font_dump_glyphs(out, face, label)
    }
  }
}

///|
fn font_dump_metrics(out : StringBuilder, face : @otf.Face) -> Unit {
  out.write_string("number_of_glyphs \{face.number_of_glyphs()}\n")
  out.write_string("units_per_em \{face.units_per_em()}\n")
  out.write_string(
    "global_bbox \{font_rect(Some(face.global_bounding_box()))}\n",
  )
  out.write_string(
    "hmetrics \{face.ascender()} \{face.descender()} \{face.height()} \{face.line_gap()}\n",
  )
  out.write_string(
    "typographic \{fopt(face.typographic_ascender())} \{fopt(face.typographic_descender())} \{fopt(face.typographic_line_gap())}\n",
  )
  out.write_string(
    "vmetrics \{fopt(face.vertical_ascender())} \{fopt(face.vertical_descender())} \{fopt(face.vertical_height())} \{fopt(face.vertical_line_gap())}\n",
  )
  out.write_string(
    "x_height \{fopt(face.x_height())} capital_height \{fopt(face.capital_height())}\n",
  )
  out.write_string("underline \{font_line_metrics(face.underline_metrics())}\n")
  out.write_string("strikeout \{font_line_metrics(face.strikeout_metrics())}\n")
  out.write_string(
    "subscript \{font_script_metrics(face.subscript_metrics())}\n",
  )
  out.write_string(
    "superscript \{font_script_metrics(face.superscript_metrics())}\n",
  )
}

///|
fn cmap_format_number(format : @otf.CmapFormat) -> Int {
  match format {
    ByteEncodingTable(_) => 0
    HighByteMappingThroughTable(_) => 2
    SegmentMappingToDeltaValues(_) => 4
    TrimmedTableMapping(_) => 6
    MixedCoverage => 8
    TrimmedArray(_) => 10
    SegmentedCoverage(_) => 12
    ManyToOneRangeMappings(_) => 13
    UnicodeVariationSequences(_) => 14
  }
}

///|
fn gid_opt(g : @otf.GlyphId?) -> String {
  match g {
    Some(g) => g.0.to_string()
    None => "-"
  }
}

///|
fn font_dump_cmap(out : StringBuilder, face : @otf.Face) -> Unit {
  guard face.tables().cmap is Some(cmap) else {
    out.write_string("cmap -\n")
    return
  }
  let all : @hashset.HashSet[UInt] = @hashset.new()
  let mut i = 0
  for subtable in cmap.subtables.iter() {
    let cps = []
    subtable.codepoints(cp => cps.push(cp))
    let text = StringBuilder::new()
    for cp in cps {
      text.write_string("\{cp}:\{gid_opt(subtable.glyph_index(cp))};")
      all.add(cp)
    }
    out.write_string(
      "cmap \{i} \{font_platform(subtable.platform_id)} \{subtable.encoding_id} format \{cmap_format_number(subtable.format)} unicode \{subtable.is_unicode()} count \{cps.length()} fnv \{hex16(fnv(text.to_string()))}\n",
    )
    i += 1
  }

  // Face-level lookups over the union of all mapped code points.
  let all = all.iter().to_array()
  all.sort()
  let text = StringBuilder::new()
  let vs_text = StringBuilder::new()
  let mut found = 0
  let mut vs_found = 0
  let samples = StringBuilder::new()
  for k, cp in all {
    if cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
      continue
    }
    let c = cp.reinterpret_as_int().unsafe_to_char()
    let gid = face.glyph_index(c)
    if gid is Some(_) {
      found += 1
    }
    text.write_string("\{cp}:\{gid_opt(gid)};")
    if k < 20 || k % 1009 == 0 {
      samples.write_string("glyph_index \{cp} \{gid_opt(gid)}\n")
    }
    for vs in [0xFE00, 0xFE0E, 0xFE0F, 0xE0100] {
      let v = face.glyph_variation_index(c, vs.unsafe_to_char())
      if v is Some(_) {
        vs_found += 1
      }
      vs_text.write_string("\{gid_opt(v)};")
    }
  }
  out.write_string(
    "coverage \{all.length()} found \{found} fnv \{hex16(fnv(text.to_string()))} vs_found \{vs_found} vs_fnv \{hex16(fnv(vs_text.to_string()))}\n",
  )
  out.write_string(samples.to_string())
}

///|
fn font_dump_kern(out : StringBuilder, face : @otf.Face) -> Unit {
  guard face.tables().kern is Some(kern) else { return }
  let n = face.number_of_glyphs().to_int()
  let n = if n < 128 { n } else { 128 }
  let mut i = 0
  for subtable in kern.subtables.iter() {
    let format = match subtable.format {
      Format0(_) => 0
      Format1(_) => 1
      Format2(_) => 2
      Format3(_) => 3
    }
    let text = StringBuilder::new()
    if subtable.format is Format0(st) {
      for pair in st.pairs.iter() {
        text.write_string(
          "\{pair.left().0}:\{pair.right().0}:\{pair.value}:\{fopt(subtable.glyphs_kerning(pair.left(), pair.right()))};",
        )
      }
    }
    for l in 0..<n {
      for r in 0..<n {
        if subtable.glyphs_kerning(
            @otf.GlyphId(l.to_uint16()),
            @otf.GlyphId(r.to_uint16()),
          )
          is Some(v) {
          text.write_string("\{l}:\{r}:\{v};")
        }
      }
    }
    out.write_string(
      "kern \{i} horizontal \{subtable.horizontal} variable \{subtable.variable} cross \{subtable.has_cross_stream} state \{subtable.has_state_machine} format \{format} fnv \{hex16(fnv(text.to_string()))}\n",
    )
    i += 1
  }
}

///|
fn font_dump_cff(out : StringBuilder, face : @otf.Face) -> Unit {
  guard face.tables().cff is Some(cff) else { return }
  let m = cff.matrix()
  out.write_string(
    "cff glyphs \{cff.number_of_glyphs()} matrix \{ff(m.sx)} \{ff(m.ky)} \{ff(m.kx)} \{ff(m.sy)} \{ff(m.tx)} \{ff(m.ty)}\n",
  )
  let text = StringBuilder::new()
  for code in 0..<=255 {
    text.write_string("\{gid_opt(cff.glyph_index(code.to_byte()))};")
  }
  out.write_string("cff glyph_index fnv \{hex16(fnv(text.to_string()))}\n")
  let text = StringBuilder::new()
  let count = cff.number_of_glyphs().to_int()
  for gid in 0..<count {
    let g = @otf.GlyphId(gid.to_uint16())
    let name = match cff.glyph_name(g) {
      Some(n) => esc(n)
      None => "-"
    }
    let line = "\{gid} \{fopt(cff.glyph_width(g))} \{fopt(cff.glyph_cid(g))} \{name}"
    if is_sample(gid, count) {
      out.write_string("cff glyph \{line}\n")
    }
    text.write_string(line)
    text.write_char('\n')
  }
  out.write_string("cff glyphs fnv \{hex16(fnv(text.to_string()))}\n")
}

///|
fn font_dump_glyphs(
  out : StringBuilder,
  face : @otf.Face,
  label : String,
) -> Unit {
  let count = face.number_of_glyphs().to_int()
  let block = StringBuilder::new()
  let mut block_start = 0
  for gid in 0..<count {
    let g = @otf.GlyphId(gid.to_uint16())
    let path : PathBuilder = { buf: StringBuilder::new(), }
    let bbox = face.outline_glyph(g, path)
    let path = path.buf.to_string()
    let raster = match face.glyph_raster_image(g, 0xFFFF) {
      Some(img) =>
        "\{font_raster_format(img.format)},\{img.x},\{img.y},\{img.width},\{img.height},\{img.pixels_per_em},\{img.data.length()},\{hex16(fnv_bytes(img.data))}"
      None => "-"
    }
    let svg = match face.glyph_svg_image(g) {
      Some(doc) =>
        "\{doc.start_glyph_id.0}..\{doc.end_glyph_id.0},\{doc.data.length()},\{hex16(fnv_bytes(doc.data))}"
      None => "-"
    }
    let name = match face.glyph_name(g) {
      Some(n) => esc(n)
      None => "-"
    }
    let line = "glyph \{gid} adv \{fopt(face.glyph_hor_advance(g))} vadv \{fopt(face.glyph_ver_advance(g))} lsb \{fopt(face.glyph_hor_side_bearing(g))} tsb \{fopt(face.glyph_ver_side_bearing(g))} yorg \{fopt(face.glyph_y_origin(g))} name \{name} bbox \{font_rect(bbox)} path \{hex16(fnv(path))} color \{face.is_color_glyph(g)} raster \{raster} svg \{svg}"
    if is_sample(gid, count) {
      out.write_string("\{label}\{line}\n")
      if path != "" {
        out.write_string("\{label}path \{gid} \{path.trim_end(chars=" ")}\n")
      }
    }
    block.write_string(line)
    block.write_char('\n')
    if (gid + 1) % 256 == 0 || gid + 1 == count {
      out.write_string(
        "\{label}glyphs \{block_start}..\{gid} fnv \{hex16(fnv(block.to_string()))}\n",
      )
      block.reset()
      block_start = gid + 1
    }
  }
}
