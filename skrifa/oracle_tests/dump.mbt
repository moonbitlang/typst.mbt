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
  let buf = @buffer.new()
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
