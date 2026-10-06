// Dumpers that mirror the oracle program (scratch `oracle/src/main.rs`):
// every pen command is printed with f32 values as hex bit patterns so that
// outputs can be compared exactly.

///|
pub fn hex_f32(v : Float) -> String {
  let bits = v.reinterpret_as_uint()
  let digits = "0123456789abcdef"
  let sb = StringBuilder()
  for i in 0..<8 {
    let d = ((bits >> ((7 - i) * 4)) & 0xFU).reinterpret_as_int()
    sb.write_char(digits.get_char(d).unwrap())
  }
  sb.to_string()
}

///|
pub fn hex_u64(v : UInt64) -> String {
  let digits = "0123456789abcdef"
  let sb = StringBuilder()
  for i in 0..<16 {
    let d = ((v >> ((15 - i) * 4)) & 0xFUL).to_int()
    sb.write_char(digits.get_char(d).unwrap())
  }
  sb.to_string()
}

///|
pub fn fnv(data : BytesView) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = h ^ b.to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
pub fn fnv_str(s : String) -> UInt64 {
  // The oracle hashes UTF-8; dumps are ASCII except for glyph names which
  // are printed as Latin-1 chars (`b as char`), so encode as UTF-8.
  let buf = Buffer()
  for c in s {
    let c = c.to_int()
    if c < 0x80 {
      buf.write_byte(c.to_byte())
    } else if c < 0x800 {
      buf.write_byte((0xC0 | (c >> 6)).to_byte())
      buf.write_byte((0x80 | (c & 0x3F)).to_byte())
    } else if c < 0x10000 {
      buf.write_byte((0xE0 | (c >> 12)).to_byte())
      buf.write_byte((0x80 | ((c >> 6) & 0x3F)).to_byte())
      buf.write_byte((0x80 | (c & 0x3F)).to_byte())
    } else {
      buf.write_byte((0xF0 | (c >> 18)).to_byte())
      buf.write_byte((0x80 | ((c >> 12) & 0x3F)).to_byte())
      buf.write_byte((0x80 | ((c >> 6) & 0x3F)).to_byte())
      buf.write_byte((0x80 | (c & 0x3F)).to_byte())
    }
  }
  fnv(buf.to_bytes())
}

///|
/// A pen that records commands in the oracle's text format.
pub struct TextPen {
  sb : StringBuilder
}

///|
pub fn TextPen::new() -> TextPen {
  { sb: StringBuilder(), }
}

///|
pub fn TextPen::to_string(self : TextPen) -> String {
  self.sb.to_string()
}

///|
pub impl @read_fonts.OutlinePen for TextPen with fn move_to(self, x, y) {
  self.sb.write_string("M \{hex_f32(x)} \{hex_f32(y)}\n")
}

///|
pub impl @read_fonts.OutlinePen for TextPen with fn line_to(self, x, y) {
  self.sb.write_string("L \{hex_f32(x)} \{hex_f32(y)}\n")
}

///|
pub impl @read_fonts.OutlinePen for TextPen with fn quad_to(self, cx, cy, x, y) {
  self.sb.write_string(
    "Q \{hex_f32(cx)} \{hex_f32(cy)} \{hex_f32(x)} \{hex_f32(y)}\n",
  )
}

///|
pub impl @read_fonts.OutlinePen for TextPen with fn curve_to(
  self,
  cx0,
  cy0,
  cx1,
  cy1,
  x,
  y,
) {
  self.sb.write_string(
    "C \{hex_f32(cx0)} \{hex_f32(cy0)} \{hex_f32(cx1)} \{hex_f32(cy1)} \{hex_f32(x)} \{hex_f32(y)}\n",
  )
}

///|
pub impl @read_fonts.OutlinePen for TextPen with fn close(self) {
  self.sb.write_string("Z\n")
}

///|
#deprecated("call as `OutlinePen::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextPen with @read_fonts.OutlinePen::{
  close,
  curve_to,
  line_to,
  quad_to,
  move_to,
}

///|
fn latin1(b : BytesView) -> String {
  let sb = StringBuilder()
  for c in b {
    sb.write_char(Int::unsafe_to_char(c.to_int()))
  }
  sb.to_string()
}

///|
fn opt_i32(v : Int?) -> String {
  match v {
    Some(v) => "Some(\{v})"
    None => "None"
  }
}

///|
/// Mirrors the oracle's `cff` command.
pub fn dump_cff(data : BytesView) -> String {
  let out = StringBuilder()
  let font = @ps.CffFontRef::new(data, 0, None) catch {
    e => {
      out.write_string("error \{e}\n")
      return out.to_string()
    }
  }
  let cff : @ps.Cff? = Some(@ps.Cff::read(data)) catch { _ => None }
  out.write_string(
    "num_glyphs \{font.num_glyphs()} is_cid \{font.is_cid()} num_subfonts \{font.num_subfonts()} upem \{font.upem()}\n",
  )
  match font.charset() {
    Some(charset) => {
      for item in charset.iter() {
        let (gid, sid) = item
        let name = match cff {
          Some(c) =>
            match c.string(sid) {
              Some(b) => latin1(b)
              None => "-"
            }
          None => "-"
        }
        out.write_string("cs \{gid.to_u32()} \{sid.to_u16()} \{name}\n")
      }
      let n = font.num_glyphs() + 500
      let n = if n < 65535 { n } else { 65535 }
      for s in 0..<n {
        let g = charset.glyph_id(@ps.Sid::new(s)) catch { _ => continue }
        out.write_string("gid_of \{s} \{g.to_u32()}\n")
      }
    }
    None => out.write_string("no charset\n")
  }
  match font.encoding() {
    Some(enc) =>
      for code in 0..<256 {
        if enc.map(code.to_byte()) is Some(g) {
          out.write_string("enc \{code} \{g.to_u32()}\n")
        }
      }
    None => out.write_string("no encoding\n")
  }
  let subfonts : Array[@ps.Subfont?] = []
  for i in 0..<font.num_subfonts() {
    let s = font.subfont(i, []) catch {
      e => {
        out.write_string("subfont \{i} error \{e}\n")
        subfonts.push(None)
        continue
      }
    }
    let dw = match s.default_width() {
      Some(w) => Some(w.to_bits())
      None => None
    }
    out.write_string(
      "subfont \{i} subrs \{s.subrs_offset()} dw \{opt_i32(dw)} nw \{s.nominal_width().to_bits()}\n",
    )
    subfonts.push(Some(s))
  }
  for gid in 0..<font.num_glyphs() {
    let glyph = @font_types.GlyphId::from_int(gid)
    guard font.subfont_index(glyph) is Some(idx) else {
      out.write_string("glyph \{gid} no subfont\n")
      continue
    }
    guard subfonts.get(idx) is Some(Some(subfont)) else {
      out.write_string("glyph \{gid} bad subfont \{idx}\n")
      continue
    }
    let pen = TextPen::new()
    let res = font.draw(subfont, glyph, [], Some(1000.0), pen) catch {
      e => {
        out.write_string("glyph \{gid} sf \{idx} error \{e}\n")
        out.write_string(pen.to_string())
        continue
      }
    }
    let w = match res {
      Some(w) => hex_f32(w)
      None => "-"
    }
    out.write_string("glyph \{gid} sf \{idx} w \{w}\n")
    out.write_string(pen.to_string())
  }
  out.to_string()
}

///|
fn hash_lines(lines : StringBuilder) -> String {
  hex_u64(fnv_str(lines.to_string()))
}

///|
/// Mirrors the oracle's `otf` command.
pub fn dump_otf(
  data : BytesView,
  index : Int,
  hinted? : Bool = false,
) -> String {
  let out = StringBuilder()
  let font = @read_fonts.FontRef::from_index(data, index) catch {
    e => {
      out.write_string("error \{e}\n")
      return out.to_string()
    }
  }
  match res(() => font.post()) {
    Ok(post) => {
      let (maj, min) = post.version().to_major_minor()
      out.write_string("post \{maj} \{min}\n")
      if post.glyph_name_index() is Some(idx) {
        out.write_string(
          "post_idx " + idx.map(i => i.to_string()).join(" ") + "\n",
        )
      }
      if post.string_data() is Some(sd) {
        for e in sd {
          match e {
            Ok(s) => out.write_string("post_str \{s}\n")
            Err(e) => out.write_string("post_str_err \{e}\n")
          }
        }
      }
    }
    Err(e) => out.write_string("post error \{e}\n")
  }
  match res(() => font.cff()) {
    Ok(cff) => {
      let d = cff.offset_data()
      out.write_string("cff \{d.length()} \{hex_u64(fnv(d))}\n")
    }
    Err(e) => out.write_string("cff error \{e}\n")
  }
  match res(() => font.cmap()) {
    Ok(cmap) => {
      for record in cmap.encoding_records() {
        out.write_string(
          "cmap \{debug_platform(record.platform_id())} \{record.encoding_id()}",
        )
        match res(() => record.subtable(cmap.offset_data())) {
          Ok(sub) => {
            let h = StringBuilder()
            let mut n = 0
            for c in 0U..<0x11000U {
              if sub.map_codepoint(c) is Some(g) {
                h.write_string("\{c} \{g.to_u32()}\n")
                n += 1
              }
            }
            out.write_string(" fmt \{sub.format()} n \{n} h \{hash_lines(h)}\n")
          }
          Err(e) => out.write_string(" error \{e}\n")
        }
      }
      let h = StringBuilder()
      let mut n = 0
      for c in 0U..<0x11000U {
        if cmap.map_codepoint(c) is Some(g) {
          h.write_string("\{c} \{g.to_u32()}\n")
          n += 1
        }
      }
      out.write_string("cmap_map n \{n} h \{hash_lines(h)}\n")
    }
    Err(e) => out.write_string("cmap error \{e}\n")
  }
  {
    let cm = @skrifa.Charmap::new(font)
    let h = StringBuilder()
    let mut n = 0
    for c in 0U..<0x11000U {
      if c >= 0xD800U && c <= 0xDFFFU {
        continue
      }
      if cm.map(c) is Some(g) {
        h.write_string("\{c} \{g.to_u32()}\n")
        n += 1
      }
    }
    out.write_string("charmap n \{n} h \{hash_lines(h)}\n")
  }
  let attrs = @skrifa.Attributes::new(font)
  let style = match attrs.style {
    Normal => "Normal"
    Italic => "Italic"
    Oblique(None) => "Oblique(None)"
    Oblique(Some(a)) => "Oblique(\{hex_f32(a)})"
  }
  out.write_string(
    "attrs weight \{hex_f32(attrs.weight.value())} style \{style} stretch \{hex_f32(attrs.stretch.ratio())}\n",
  )
  let m = @skrifa.Metrics::new(
    font,
    @skrifa.Size::unscaled(),
    @skrifa.LocationRef::default(),
  )
  out.write_string("metrics upem \{m.units_per_em} mono \{m.is_monospace}\n")
  let outlines = @skrifa.OutlineGlyphCollection::new(font)
  out.write_string("require_interpreter \{outlines.require_interpreter()}\n")
  let gm = @skrifa.GlyphMetrics::new(
    font,
    @skrifa.Size::new(1000.0),
    @skrifa.LocationRef::default(),
  )
  let num_glyphs = match res(() => font.maxp()) {
    Ok(m) => m.num_glyphs()
    Err(_) => 0
  }
  out.write_string("num_glyphs \{num_glyphs}\n")
  let instance = if hinted {
    try
      @skrifa.HintingInstance::new(
        outlines,
        @skrifa.Size::new(1000.0),
        @skrifa.LocationRef::default(),
        { engine: Interpreter, target: Mono, },
      )
    catch {
      e => {
        out.write_string("hinting error \{e}\n")
        None
      }
    } noraise {
      i => Some(i)
    }
  } else {
    None
  }
  for gid in 0..<(num_glyphs + 1) {
    let glyph = @font_types.GlyphId::from_int(gid)
    let aw = match gm.advance_width(glyph) {
      Some(w) => hex_f32(w)
      None => "-"
    }
    guard outlines.get(glyph) is Some(outline) else {
      out.write_string("glyph \{gid} aw \{aw} none\n")
      continue
    }
    let pen = TextPen::new()
    let settings = match instance {
      Some(i) => @skrifa.DrawSettings::hinted(i, false)
      None =>
        @skrifa.DrawSettings::unhinted(
          @skrifa.Size::new(1000.0),
          @skrifa.LocationRef::default(),
        )
    }
    try outline.draw(settings, pen) catch {
      e => out.write_string("glyph \{gid} aw \{aw} error \{e}\n")
    } noraise {
      _ => out.write_string("glyph \{gid} aw \{aw}\n")
    }
    out.write_string(pen.to_string())
  }
  out.to_string()
}

///|
fn debug_platform(p : @read_fonts.PlatformId) -> String {
  match p {
    Unicode => "Unicode"
    Macintosh => "Macintosh"
    ISO => "ISO"
    Windows => "Windows"
    Custom => "Custom"
    Unknown => "Unknown"
  }
}

///|
/// Runs `f`, capturing the result.
fn[T] res(
  f : () -> T raise @read_fonts.ReadError,
) -> Result[T, @read_fonts.ReadError] {
  try f() catch {
    e => Err(e)
  } noraise {
    v => Ok(v)
  }
}

///|
/// Mirrors the oracle's `t1` command.
pub fn dump_t1(data : BytesView) -> String {
  let out = StringBuilder()
  let font = @ps.Type1Font::new(data) catch {
    e => {
      out.write_string("error \{e}\n")
      return out.to_string()
    }
  }
  out.write_string("num_glyphs \{font.num_glyphs()} upem \{font.upem()}\n")
  for item in font.glyph_names() {
    let (gid, name) = item
    out.write_string("name \{gid.to_u32()} \{name}\n")
  }
  match font.encoding() {
    Some(enc) =>
      for code in 0..<256 {
        let g = match enc.map(code.to_byte()) {
          Some(g) => g.to_u32().to_int64()
          None => -1L
        }
        let n = enc.glyph_name(code.to_byte()).unwrap_or("-")
        if g >= 0L || n != "-" {
          out.write_string("enc \{code} \{g} \{n}\n")
        }
      }
    None => out.write_string("no encoding\n")
  }
  for gid in 0..<font.num_glyphs() {
    let pen = TextPen::new()
    let glyph = @font_types.GlyphId::from_int(gid)
    try font.draw(glyph, Some(1000.0), pen) catch {
      e => out.write_string("glyph \{gid} error \{e}\n")
    } noraise {
      Some(w) => out.write_string("glyph \{gid} w \{hex_f32(w)}\n")
      None => out.write_string("glyph \{gid} w -\n")
    }
    out.write_string(pen.to_string())
  }
  out.to_string()
}
