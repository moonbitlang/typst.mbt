// Port of krilla's `graphics/image/png.rs`: PNGs whose image data can be
// embedded as is (with a PNG predictor) instead of being decoded.

///|
/// The parts of a PNG that are embedded as is (krilla's `PngData`).
priv struct PngData {
  /// The concatenated `IDAT` chunks.
  idat : Bytes
  bit_depth : Int
  color_type : @codecs.PngColorType
  /// The `PLTE` chunk of an indexed image.
  palette : Bytes?
}

///|
/// A chunk of a PNG file (krilla's `PngChunk`).
priv struct PngChunk {
  kind : BytesView
  data : BytesView
  crc : UInt
  is_critical : Bool
}

///|
fn PngChunk::has_valid_crc(self : PngChunk) -> Bool {
  @codecs.crc32([self.kind, self.data]) == self.crc
}

///|
/// Reads the chunks of a PNG: `None` at the end of the data, `Some(Err(()))`
/// for a truncated chunk (after which there are no more chunks).
priv struct PngChunks {
  data : BytesView
  mut pos : Int
  mut failed : Bool
}

///|
fn PngChunks::new(data : BytesView) -> PngChunks? {
  let magic = b"\x89\x50\x4E\x47\x0D\x0A\x1A\x0A"
  if data.length() < magic.length() || data[0:magic.length()] != magic {
    return None
  }
  Some({ data, pos: magic.length(), failed: false, })
}

///|
fn PngChunks::read_u32(self : PngChunks) -> UInt? {
  if self.data.length() - self.pos < 4 {
    return None
  }
  let d = self.data
  let p = self.pos
  self.pos += 4
  Some(
    (d[p].to_uint() << 24) |
    (d[p + 1].to_uint() << 16) |
    (d[p + 2].to_uint() << 8) |
    d[p + 3].to_uint(),
  )
}

///|
fn PngChunks::read_chunk(self : PngChunks) -> PngChunk? {
  guard self.read_u32() is Some(chunk_len) else { return None }
  let kind_start = self.pos
  guard self.read_u32() is Some(_) else { return None }
  let kind = self.data[kind_start:kind_start + 4]
  if chunk_len.to_uint64() > (self.data.length() - self.pos).to_uint64() {
    return None
  }
  let len = chunk_len.reinterpret_as_int()
  let data = self.data[self.pos:self.pos + len]
  self.pos += len
  guard self.read_u32() is Some(crc) else { return None }
  // `chunk::is_critical`: the first letter is uppercase.
  Some({ kind, data, crc, is_critical: (kind[0].to_int() & 32) == 0, })
}

///|
fn PngChunks::next(self : PngChunks) -> PngChunk?? {
  if self.failed || self.pos >= self.data.length() {
    return None
  }
  let chunk = self.read_chunk()
  self.failed = chunk is None
  Some(chunk)
}

///|
/// Reads the PNG data that can be embedded as is: non-interlaced grayscale,
/// RGB or indexed images without transparency (`tRNS`), whose critical
/// chunks have valid checksums.
fn PngData::new(data : BytesView) -> PngData? {
  guard PngChunks::new(data) is Some(chunks) else { return None }
  guard chunks.next() is Some(Some(ihdr)) else { return None }
  if ihdr.kind != b"IHDR" || !ihdr.has_valid_crc() {
    return None
  }
  guard png_header(ihdr.data) is Some((bit_depth, color_type, interlaced)) else {
    return None
  }
  if interlaced || !(color_type is (Grayscale | Rgb | Indexed)) {
    return None
  }
  let idat = Buffer()
  let mut has_idat = false
  let mut palette : Bytes? = None
  let mut palette_seen = false
  let mut reached_iend = false
  while chunks.next() is Some(png_chunk) {
    guard png_chunk is Some(png_chunk) else { return None }
    if png_chunk.is_critical && !png_chunk.has_valid_crc() {
      return None
    }
    match png_chunk.kind {
      b"IHDR" | b"tRNS" => return None
      b"PLTE" => {
        let max_len = match color_type {
          Indexed => 3 * (1 << bit_depth)
          Rgb => 3 * 256
          _ => return None
        }
        if palette_seen ||
          has_idat ||
          png_chunk.data.length() == 0 ||
          png_chunk.data.length() % 3 != 0 ||
          png_chunk.data.length() > max_len {
          return None
        }
        palette_seen = true

        // See 4.1.2: https://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html
        // For RGB images, we can safely ignore it.
        if color_type is Indexed {
          palette = Some(png_chunk.data.to_owned())
        }
      }
      b"IDAT" => {
        has_idat = true
        idat.write_bytesview(png_chunk.data)
      }
      b"IEND" => {
        reached_iend = true
        break
      }
      _ if png_chunk.is_critical => return None
      _ => ()
    }
  }
  if color_type is Indexed && palette is None {
    return None
  }
  if !reached_iend || !has_idat {
    return None
  }
  // Note: For performance reasons we don't inflate and validate whether
  // the actual length of the data is correct. This does mean that
  // invalid data might be embedded in case the original PNG was
  // corrupted.
  Some({ idat: idat.to_bytes(), bit_depth, color_type, palette, })
}

///|
/// Parses an `IHDR` chunk (krilla's `Header::new`): the bit depth, the color
/// type and whether the image is interlaced.
fn png_header(data : BytesView) -> (Int, @codecs.PngColorType, Bool)? {
  if data.length() != 13 {
    return None
  }
  let u32_at = (i : Int) => {
    (data[i].to_uint() << 24) |
    (data[i + 1].to_uint() << 16) |
    (data[i + 2].to_uint() << 8) |
    data[i + 3].to_uint()
  }
  let width = u32_at(0)
  let height = u32_at(4)
  let bit_depth = data[8].to_int()
  guard bit_depth is (1 | 2 | 4 | 8 | 16) else { return None }
  guard @codecs.PngColorType::from_code(data[9].to_int()) is Some(color_type) else {
    return None
  }
  if width == 0 || height == 0 || data[10] != 0 || data[11] != 0 {
    return None
  }
  let interlaced = match data[12] {
    0 => false
    1 => true
    _ => return None
  }
  Some((bit_depth, color_type, interlaced))
}
