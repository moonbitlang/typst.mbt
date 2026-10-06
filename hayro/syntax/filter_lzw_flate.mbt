// Port of `hayro-syntax/src/filter/lzw_flate.rs` and `filter/png`: LZW and
// flate decoding with predictors.

///|
/// Decode a flate-encoded stream.
///
/// Upstream (with the `unsafe` feature) tries a zlib stream, then a raw
/// deflate stream and then pdf.js' lenient decoder.
pub fn flate_decode(data : BytesView, params : Dict) -> Bytes? {
  // `flate2`'s `ZlibDecoder`/`DeflateDecoder` with `read_to_end`.
  let decoded = @codecs.inflate_read_to_end(data, zlib=true) catch {
    _ =>
      @codecs.inflate_read_to_end(data, zlib=false) catch {
        _ =>
          // flate stream is broken, decoding with fallback
          match flate_fallback_decode(data) {
            Some(d) => d
            None => return None
          }
      }
  }
  let params = PredictorParams::from_params(params)
  apply_predictor(decoded, params)
}

///|
const LZW_CLEAR_TABLE : Int = 256

///|
const LZW_EOD : Int = 257

///|
const LZW_MAX_ENTRIES : Int = 4096

///|
const LZW_INITIAL_SIZE : Int = 258

///|
/// Decode a LZW-encoded stream.
pub fn lzw_decode(data : BytesView, params : Dict) -> Bytes? {
  let params = PredictorParams::from_params(params)
  guard lzw_decode_impl(data, params.early_change) is Some(decoded) else {
    return None
  }
  apply_predictor(decoded, params)
}

///|
priv struct LzwTable {
  early_change : Bool
  entries : Array[Bytes?]
}

///|
fn LzwTable::new(early_change : Bool) -> LzwTable {
  let entries : Array[Bytes?] = []
  for b in 0..<=255 {
    entries.push(Some(Bytes::make(1, b.to_byte())))
  }
  // Clear table and EOD don't have any data.
  entries.push(None)
  entries.push(None)
  { early_change, entries, }
}

///|
fn LzwTable::push(self : LzwTable, entry : Bytes) -> Bytes? {
  if self.entries.length() >= LZW_MAX_ENTRIES {
    None
  } else {
    self.entries.push(Some(entry))
    Some(entry)
  }
}

///|
fn LzwTable::register(self : LzwTable, prev : Int, new_byte : Byte) -> Bytes? {
  guard self.get(prev) is Some(prev_entry) else { return None }
  let new_entry = Bytes::makei(prev_entry.length() + 1, i => {
    if i < prev_entry.length() {
      prev_entry[i]
    } else {
      new_byte
    }
  })
  self.push(new_entry)
}

///|
fn LzwTable::get(self : LzwTable, index : Int) -> Bytes? {
  if index >= 0 && index < self.entries.length() {
    self.entries[index]
  } else {
    None
  }
}

///|
fn LzwTable::clear(self : LzwTable) -> Unit {
  self.entries.truncate(LZW_INITIAL_SIZE)
}

///|
fn LzwTable::size(self : LzwTable) -> Int {
  self.entries.length()
}

///|
fn LzwTable::code_length(self : LzwTable) -> Int {
  let adjusted = self.entries.length() + (if self.early_change { 1 } else { 0 })
  if adjusted >= 2048 {
    12
  } else if adjusted >= 1024 {
    11
  } else if adjusted >= 512 {
    10
  } else {
    9
  }
}

///|
fn lzw_decode_impl(data : BytesView, early_change : Bool) -> Bytes? {
  let table = LzwTable::new(early_change)
  let mut bit_size = table.code_length()
  let reader = BitReader::new(data)
  let decoded = Buffer()
  let mut prev : Int? = None
  while true {
    let next = match reader.read(bit_size) {
      Some(code) => code.reinterpret_as_int()
      None =>
        // premature EOF in LZW stream, EOD code missing
        return Some(decoded.to_bytes())
    }
    if next == LZW_CLEAR_TABLE {
      table.clear()
      prev = None
      bit_size = table.code_length()
    } else if next == LZW_EOD {
      return Some(decoded.to_bytes())
    } else {
      let new = next
      if new > table.size() {
        // invalid LZW code
        return None
      }
      if new < table.size() {
        guard table.get(new) is Some(entry) else { return None }
        let first_byte = entry[0]
        decoded.write_bytes(entry)
        if prev is Some(prev_code) {
          table.register(prev_code, first_byte) |> ignore
        }
      } else if new == table.size() && prev is Some(prev_code) {
        guard table.get(prev_code) is Some(prev_entry) else { return None }
        let first_byte = prev_entry[0]
        guard table.register(prev_code, first_byte) is Some(new_entry) else {
          return None
        }
        decoded.write_bytes(new_entry)
      } else {
        // LZW decode error: code not found and prev is None
        return None
      }
      bit_size = table.code_length()
      prev = Some(new)
    }
  }
  None
}

///|
priv struct PredictorParams {
  predictor : Int
  colors : Int
  bits_per_component : Int
  columns : Int
  early_change : Bool
}

///|
fn PredictorParams::bits_per_pixel(self : PredictorParams) -> Int {
  // u8 arithmetic in upstream (wrapping).
  (self.bits_per_component * self.colors) & 0xff
}

///|
fn PredictorParams::row_length_in_bytes(self : PredictorParams) -> Int {
  (self.columns * self.bits_per_pixel() + 7) / 8
}

///|
fn PredictorParams::from_params(dict : Dict) -> PredictorParams {
  let get_u8 = (key : String, default : Int) => {
    match (dict.get(key) : Byte?) {
      Some(v) => v.to_int()
      None => default
    }
  }
  let columns = match (dict.get("Columns") : UInt64?) {
    Some(v) => v.to_int()
    None => 1
  }
  {
    predictor: get_u8("Predictor", 1),
    colors: get_u8("Colors", 1),
    bits_per_component: get_u8("BitsPerComponent", 8),
    columns,
    early_change: match (dict.get("EarlyChange") : Byte?) {
      Some(e) => e != 0
      None => true
    },
  }
}

///|
fn apply_predictor(data : Bytes, params : PredictorParams) -> Bytes? {
  if params.predictor == 1 {
    return Some(data)
  }
  let i = params.predictor
  let is_png_predictor = i >= 10
  let row_len = params.row_length_in_bytes()
  let total_row_len = if is_png_predictor {
    // + 1 Because each row must start with the predictor that is used for PNG predictors.
    row_len + 1
  } else {
    row_len
  }
  if total_row_len == 0 {
    return None
  }
  let num_rows = data.length() / total_row_len
  if !(params.bits_per_component is (1 | 2 | 4 | 8 | 16)) {
    // invalid bits per component
    return None
  }
  let (bit_size, chunk_len) = if is_png_predictor {
    (8, (((params.colors * params.bits_per_component) & 0xff) + 7) / 8)
  } else {
    (params.bits_per_component, params.colors)
  }
  if bit_size == 8 &&
    chunk_len > 0 &&
    row_len % chunk_len == 0 &&
    chunk_len is (1 | 2 | 3 | 4 | 6 | 8) {
    return apply_predictor_8bit_png(
      data, i, is_png_predictor, row_len, total_row_len, num_rows, chunk_len,
    )
  }
  if !(bit_size >= 1 && bit_size <= 16) || chunk_len == 0 {
    return None
  }
  let out = FixedArray::make(num_rows * row_len, b'\x00')
  // The previous (decoded) row, as chunks of samples.
  let mut prev_row : Array[Array[Int]] = read_chunks(
    FixedArray::make(row_len, b'\x00'),
    0,
    row_len,
    bit_size,
    chunk_len,
  )
  let mut out_pos = 0
  for row in 0..<num_rows {
    let in_row = data[row * total_row_len:(row + 1) * total_row_len]
    let writer = BitWriter::new(out, out_pos * 8, bit_size)
    if is_png_predictor {
      let predictor = in_row[0].to_int()
      let in_data = in_row[1:]
      let cur = bytes_chunks(in_data, bit_size, chunk_len)
      match predictor {
        1 => predict_row(prev_row, cur, writer, bit_size, chunk_len, Sub)
        2 => predict_row(prev_row, cur, writer, bit_size, chunk_len, Up)
        3 => predict_row(prev_row, cur, writer, bit_size, chunk_len, Avg)
        4 => predict_row(prev_row, cur, writer, bit_size, chunk_len, Paeth)
        _ => {
          // Just copy the data.
          let reader = BitReader::new(in_data)
          while reader.read(bit_size) is Some(v) {
            writer.write(v) |> ignore
          }
        }
      }
    } else if i == 2 {
      let cur = bytes_chunks(in_row, bit_size, chunk_len)
      predict_row(prev_row, cur, writer, bit_size, chunk_len, Sub)
    } else {
      // unknown predictor
      return None
    }
    // Upstream splits off the written bytes and continues writing after
    // them.
    let written = writer.cur_pos() / 8
    prev_row = read_chunks(out, out_pos, written, bit_size, chunk_len)
    out_pos += written
  }
  Some(Bytes::from_array(out[:]))
}

///|
priv enum Predictor {
  Sub
  Up
  Avg
  Paeth
}

///|
fn Predictor::predict(
  self : Predictor,
  cur_row : Int,
  prev_row : Int,
  prev_col : Int,
  top_left : Int,
) -> Int {
  match self {
    Sub => (cur_row + prev_col) & 0xffff
    Up => (cur_row + prev_row) & 0xffff
    Avg => (cur_row + (prev_col + prev_row) / 2) & 0xffff
    Paeth => {
      let a = prev_col
      let b = prev_row
      let c = top_left
      let p = a + b - c
      let pa = (p - a).abs()
      let pb = (p - b).abs()
      let pc = (p - c).abs()
      let paeth = if pa <= pb && pa <= pc {
        a
      } else if pb <= pc {
        b
      } else {
        c
      }
      (cur_row + paeth) & 0xffff
    }
  }
}

///|
/// Split bytes into chunks of `chunk_len` samples of `bit_size` bits
/// (upstream `BitChunks`); incomplete trailing chunks are dropped.
fn bytes_chunks(
  data : BytesView,
  bit_size : Int,
  chunk_len : Int,
) -> Array[Array[Int]] {
  let reader = BitReader::new(data)
  let chunks = []
  while true {
    let chunk = []
    for _ in 0..<chunk_len {
      match reader.read(bit_size) {
        Some(v) => chunk.push(v.reinterpret_as_int() & 0xffff)
        None => return chunks
      }
    }
    chunks.push(chunk)
  }
  chunks
}

///|
fn read_chunks(
  data : FixedArray[Byte],
  start : Int,
  len : Int,
  bit_size : Int,
  chunk_len : Int,
) -> Array[Array[Int]] {
  let bytes = Bytes::makei(len, i => data[start + i])
  bytes_chunks(bytes[:], bit_size, chunk_len)
}

///|
/// Upstream `apply::<T>`.
fn predict_row(
  prev_row : Array[Array[Int]],
  cur_row : Array[Array[Int]],
  writer : BitWriter,
  bit_size : Int,
  chunk_len : Int,
  predictor : Predictor,
) -> Unit {
  let mut prev_col = Array::make(chunk_len, 0)
  let mut top_left = Array::make(chunk_len, 0)
  let n = if cur_row.length() < prev_row.length() {
    cur_row.length()
  } else {
    prev_row.length()
  }
  for i in 0..<n {
    let cur = cur_row[i]
    let prev = prev_row[i]
    let new_col = []
    for j in 0..<chunk_len {
      let v = predictor.predict(cur[j], prev[j], prev_col[j], top_left[j]) &
        bit_mask(bit_size).reinterpret_as_int()
      writer.write(v.reinterpret_as_uint()) |> ignore
      // Re-reading the written value is equivalent to masking it.
      new_col.push(v & 0xffff)
    }
    prev_col = new_col
    top_left = prev
  }
}

///|
fn apply_predictor_8bit_png(
  data : Bytes,
  predictor : Int,
  is_png_predictor : Bool,
  row_len : Int,
  total_row_len : Int,
  num_rows : Int,
  tbpp : Int,
) -> Bytes? {
  if row_len == 0 || total_row_len == 0 {
    return None
  }
  let out_len = num_rows * row_len
  let data = FixedArray::makei(data.length(), i => data[i])
  for row_idx in 0..<num_rows {
    let src_start = row_idx * total_row_len
    let dst_start = row_idx * row_len
    let has_prev = dst_start >= row_len
    if is_png_predictor {
      let predictor = data[src_start].to_int()
      for k in 0..<row_len {
        data[dst_start + k] = data[src_start + 1 + k]
      }
      if predictor >= 0 && predictor <= 4 {
        png_unfilter(
          predictor,
          tbpp,
          data,
          dst_start - row_len,
          has_prev,
          dst_start,
          row_len,
        )
      }
    } else if predictor == 2 {
      png_unfilter(
        1,
        tbpp,
        data,
        dst_start - row_len,
        has_prev,
        dst_start,
        row_len,
      )
    } else {
      // unknown predictor
      return None
    }
  }
  Some(Bytes::makei(out_len, i => data[i]))
}

///|
/// PNG row unfiltering (`filter/png/mod.rs`, taken from the png crate):
/// `filter` 0 = none, 1 = sub, 2 = up, 3 = avg, 4 = paeth.
fn png_unfilter(
  filter : Int,
  bpp : Int,
  buf : FixedArray[Byte],
  prev_start : Int,
  has_prev : Bool,
  start : Int,
  len : Int,
) -> Unit {
  // If the previous row is empty, then treat it as if it were filled with zeros.
  let mut filter = filter
  if !has_prev {
    if filter == 4 {
      filter = 1
    } else if filter == 2 {
      filter = 0
    }
  }
  let full = len / bpp * bpp
  match filter {
    1 =>
      for i in bpp..<full {
        buf[start + i] = buf[start + i] + buf[start + i - bpp]
      }
    2 =>
      for i in 0..<len {
        buf[start + i] = buf[start + i] + buf[prev_start + i]
      }
    3 =>
      if !has_prev {
        for i in bpp..<full {
          buf[start + i] = buf[start + i] + buf[start + i - bpp] / 2
        }
      } else {
        for i in 0..<full {
          let left = if i >= bpp { buf[start + i - bpp].to_int() } else { 0 }
          let above = buf[prev_start + i].to_int()
          buf[start + i] = buf[start + i] + ((above + left) / 2).to_byte()
        }
      }
    4 =>
      for i in 0..<full {
        let a = if i >= bpp { buf[start + i - bpp].to_int() } else { 0 }
        let b = buf[prev_start + i].to_int()
        let c = if i >= bpp { buf[prev_start + i - bpp].to_int() } else { 0 }
        buf[start + i] = buf[start + i] + filter_paeth(a, b, c).to_byte()
      }
    _ => ()
  }
}

///|
fn filter_paeth(a : Int, b : Int, c : Int) -> Int {
  let pa = (b - c).abs()
  let pb = (a - c).abs()
  let pc = (a - c + (b - c)).abs()
  let mut out = a
  let mut min = pa
  if pb < min {
    min = pb
    out = b
  }
  if pc < min {
    out = c
  }
  out
}
