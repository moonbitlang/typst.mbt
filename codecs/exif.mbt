// Port of the parts of the `kamadak-exif` crate (v0.6.1) that Typst uses:
// `Reader::read_from_container` (`src/reader.rs`, with the JPEG, PNG, WebP
// and TIFF containers of `src/jpeg.rs`, `src/png.rs`, `src/webp.rs`), the
// TIFF IFD parser (`src/tiff.rs`) and `Exif::get_field` for fields of the
// primary image. HEIF containers are not supported (Typst never passes
// them).

///|
/// The context (IFD kind) of a tag (upstream `exif::Context`).
pub(all) enum ExifContext {
  Tiff
  Exif
  Gps
  Interop
} derive(Eq, Hash, Debug)

///|
/// A field value (upstream `exif::Value`, numeric variants only).
pub(all) enum ExifValue {
  Byte(Array[UInt])
  Short(Array[UInt])
  Long(Array[UInt])
  /// Pairs of numerator and denominator.
  Rational(Array[(UInt, UInt)])
  /// Any other type.
  Other
} derive(Debug)

///|
/// Returns the unsigned integer at `index` (upstream `Value::get_uint`).
pub fn ExifValue::get_uint(self : ExifValue, index : Int) -> UInt? {
  match self {
    Byte(v) | Short(v) | Long(v) if index < v.length() => Some(v[index])
    _ => None
  }
}

///|
/// A parsed field.
priv struct ExifField {
  ctx : ExifContext
  tag : Int
  ifd_num : Int
  value : ExifValue
}

///|
/// Parsed Exif attributes (upstream `exif::Exif`).
pub struct Exif {
  priv fields : Array[ExifField]
}

///|
/// Returns the value of the field with the given tag in the given IFD
/// (upstream `Exif::get_field`; the last matching entry wins like upstream's
/// entry map).
pub fn Exif::get_field(
  self : Exif,
  ctx : ExifContext,
  tag : Int,
  ifd_num : Int,
) -> ExifValue? {
  let mut found = None
  for field in self.fields {
    if field.ctx == ctx && field.tag == tag && field.ifd_num == ifd_num {
      found = Some(field.value)
    }
  }
  found
}

///|
/// Tag number of `Orientation`.
pub let exif_tag_orientation : Int = 0x112

///|
/// Tag number of `XResolution`.
pub let exif_tag_x_resolution : Int = 0x11a

///|
/// Tag number of `YResolution`.
pub let exif_tag_y_resolution : Int = 0x11b

///|
/// An Exif reading error (upstream `exif::Error`).
pub(all) suberror ExifError {
  ExifError(String)
} derive(Debug)

///|
/// Parses the Exif data of an image file (upstream
/// `Reader::read_from_container`).
pub fn read_exif_from_container(data : BytesView) -> Exif raise ExifError {
  let buf = if starts_with(data, b"MM\x00\x2a") ||
    starts_with(data, b"II\x2a\x00") {
    data
  } else if starts_with(data, b"\xff\xd8") {
    exif_from_jpeg(data)
  } else if starts_with(data, png_signature[:]) {
    exif_from_png(data)
  } else if data.length() >= 12 && data[0:4] == b"RIFF" && data[8:12] == b"WEBP" {
    exif_from_webp(data)
  } else {
    raise ExifError("Unknown image format")
  }
  parse_tiff(buf)
}

///|
/// Get the Exif attribute information segment from a JPEG file.
fn exif_from_jpeg(data : BytesView) -> BytesView raise ExifError {
  let broken = () => raise ExifError("Broken JPEG file")
  let mut pos = 2
  while true {
    // Find a marker prefix.
    while pos < data.length() && data[pos] != b'\xff' {
      pos += 1
    }
    if pos >= data.length() {
      broken()
    }
    pos += 1
    // Get a marker code.
    let mut code = 0xff
    while code == 0xff {
      if pos >= data.length() {
        broken()
      }
      code = data[pos].to_int()
      pos += 1
    }
    // Continue or return early on stand-alone markers.
    match code {
      0x00 | 0x01 | 0xd0 | 0xd1 | 0xd2 | 0xd3 | 0xd4 | 0xd5 | 0xd6 | 0xd7 =>
        continue
      0xd8 => raise ExifError("Unexpected SOI")
      0xd9 => raise ExifError("JPEG")
      _ => ()
    }
    // Read marker segments.
    if pos + 2 > data.length() {
      broken()
    }
    let len = u16_be(data, pos) - 2
    if len < 0 {
      raise ExifError("Invalid segment length")
    }
    pos += 2
    if pos + len > data.length() {
      broken()
    }
    let seg = data[pos:pos + len]
    pos += len
    if code == 0xe1 && starts_with(seg, b"Exif\x00\x00") {
      return seg[6:]
    }
  }
  abort("unreachable")
}

///|
/// Get the contents of the eXIf chunk from a PNG file.
fn exif_from_png(data : BytesView) -> BytesView raise ExifError {
  let mut pos = 8
  while true {
    if pos >= data.length() {
      raise ExifError("PNG")
    }
    if pos + 8 > data.length() {
      raise ExifError("Broken PNG file")
    }
    let len = u32_be(data, pos).reinterpret_as_int()
    let ctype = data[pos + 4:pos + 8]
    pos += 8
    if ctype == b"eXIf" {
      if len < 0 || pos + len > data.length() {
        raise ExifError("Broken PNG file")
      }
      return data[pos:pos + len]
    }
    // Chunk data and CRC.
    if len < 0 || pos + len + 4 > data.length() {
      raise ExifError("Broken PNG file")
    }
    pos += len + 4
  }
  abort("unreachable")
}

///|
/// Get the contents of the Exif chunk from a WebP file.
fn exif_from_webp(data : BytesView) -> BytesView raise ExifError {
  let mut file_size = u32_le(data, 4).to_int64() - 4
  if file_size < 0 {
    raise ExifError("Invalid header file size")
  }
  let mut pos = 12
  while file_size > 0 {
    file_size -= 8
    if file_size < 0 {
      raise ExifError("Chunk overflowing parent")
    }
    if pos + 8 > data.length() {
      raise ExifError("Broken WebP file")
    }
    let mut size = u32_le(data, pos + 4).to_int64()
    let fcc = data[pos:pos + 4]
    pos += 8
    file_size -= size
    if file_size < 0 {
      raise ExifError("Chunk overflowing parent")
    }
    if fcc == b"EXIF" {
      if pos.to_int64() + size > data.length().to_int64() {
        raise ExifError("Broken WebP file")
      }
      return data[pos:pos + size.to_int()]
    }
    if size % 2 != 0 && file_size > 0 {
      file_size -= 1
      size += 1
    }
    if pos.to_int64() + size > data.length().to_int64() {
      raise ExifError("Broken WebP file")
    }
    pos += size.to_int()
  }
  raise ExifError("WebP")
}

///|
priv struct TiffParser {
  data : BytesView
  le : Bool
  fields : Array[ExifField]
}

///|
fn TiffParser::u16(self : TiffParser, i : Int) -> Int {
  if self.le {
    u16_le(self.data, i)
  } else {
    u16_be(self.data, i)
  }
}

///|
fn TiffParser::u32(self : TiffParser, i : Int) -> UInt {
  if self.le {
    u32_le(self.data, i)
  } else {
    u32_be(self.data, i)
  }
}

///|
/// Parse the Exif attributes in the TIFF format.
fn parse_tiff(data : BytesView) -> Exif raise ExifError {
  if data.length() < 8 {
    raise ExifError("Truncated TIFF header")
  }
  let le = match u16_be(data, 0) {
    0x4d4d => false
    0x4949 => true
    _ => raise ExifError("Invalid TIFF byte order")
  }
  let p = { data, le, fields: [], }
  if p.u16(2) != 0x2a {
    raise ExifError("Invalid forty two")
  }
  let mut ifd_offset = p.u32(4).to_uint64()
  let mut ifd_num = 0
  while ifd_offset != 0 {
    // Limit the number of IFDs to defend against resource exhaustion
    // attacks.
    if ifd_num >= 8 {
      raise ExifError("Limit the IFD count to 8")
    }
    ifd_offset = p.parse_ifd(ifd_offset, Tiff, ifd_num)
    ifd_num += 1
  }
  { fields: p.fields, }
}

///|
/// The size of one unit of a TIFF field type.
fn tiff_unit_len(typ : Int) -> Int {
  match typ {
    1 | 2 | 6 | 7 => 1
    3 | 8 => 2
    4 | 9 | 11 => 4
    5 | 10 | 12 => 8
    _ => 0
  }
}

///|
/// Parse IFD [EXIF23 4.6.2].
fn TiffParser::parse_ifd(
  self : TiffParser,
  offset : UInt64,
  ctx : ExifContext,
  ifd_num : Int,
) -> UInt64 raise ExifError {
  let data = self.data
  // Count (the number of the entries).
  if data.length().to_uint64() < offset ||
    data.length().to_uint64() - offset < 2 {
    raise ExifError("Truncated IFD count")
  }
  let mut offset = offset.to_int()
  let count = self.u16(offset)
  offset += 2

  // Array of entries.
  for _ in 0..<count {
    if data.length() - offset < 12 {
      raise ExifError("Truncated IFD")
    }
    let tag = self.u16(offset)
    let typ = self.u16(offset + 2)
    let cnt = self.u32(offset + 4).to_uint64()
    let valofs_at = offset + 8
    offset += 12
    let unitlen = tiff_unit_len(typ).to_uint64()
    let vallen = unitlen * cnt
    let ofs = if vallen <= 4 {
      valofs_at
    } else {
      let ofs = self.u32(valofs_at).to_uint64()
      if data.length().to_uint64() < ofs ||
        data.length().to_uint64() - ofs < vallen {
        raise ExifError("Truncated field value")
      }
      ofs.to_int()
    }
    let value = self.parse_value(typ, cnt.to_int(), ofs)
    let child_ctx = match (ctx, tag) {
      (Tiff, 0x8769) => Some(ExifContext::Exif)
      (Tiff, 0x8825) => Some(Gps)
      (ExifContext::Exif, 0xa005) => Some(Interop)
      _ => None
    }
    match child_ctx {
      None => self.fields.push({ ctx, tag, ifd_num, value, })
      Some(child_ctx) => {
        // A pointer field has type == LONG and count == 1.
        guard value.get_uint(0) is Some(ofs) else {
          raise ExifError("Invalid pointer")
        }
        if self.parse_ifd(ofs.to_uint64(), child_ctx, ifd_num) != 0 {
          raise ExifError("Unexpected next IFD")
        }
      }
    }
  }

  // Offset to the next IFD.
  if data.length() - offset < 4 {
    raise ExifError("Truncated next IFD offset")
  }
  self.u32(offset).to_uint64()
}

///|
/// Parses a field value (upstream `get_type_info` parsers, numeric types
/// only).
fn TiffParser::parse_value(
  self : TiffParser,
  typ : Int,
  cnt : Int,
  ofs : Int,
) -> ExifValue {
  match typ {
    1 => Byte(Array::makei(cnt, i => self.data[ofs + i].to_uint()))
    3 =>
      Short(Array::makei(cnt, i => self.u16(ofs + 2 * i).reinterpret_as_uint()))
    4 => Long(Array::makei(cnt, i => self.u32(ofs + 4 * i)))
    5 =>
      Rational(
        Array::makei(cnt, i => {
          (self.u32(ofs + 8 * i), self.u32(ofs + 8 * i + 4))
        }),
      )
    _ => Other
  }
}
