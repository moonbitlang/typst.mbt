// Port of `zune-jpeg` (v0.5.15) `src/errors.rs` and of the parts of
// `zune-core` (v0.5.3) `src/bytestream/reader.rs` that the JPEG decoder uses:
// the `ZReader` over a `ZCursor` with the `std` feature enabled (as in the
// `image` crate), where every read goes through `std::io::{Read, Seek}`.

///|
/// An I/O error of the byte reader (upstream `zune_core::bytestream::
/// ZByteIoError`).
priv enum ZByteIoError {
  /// Not enough bytes to satisfy a read: (read, requested).
  NotEnoughBytes(Int, Int)
  /// A standard library error.
  StdIoError(String)
  /// An error that may occur randomly.
  Generic(String)
}

///|
/// Upstream `Debug for ZByteIoError` (written with `writeln!`).
fn ZByteIoError::debug(self : ZByteIoError) -> String {
  match self {
    NotEnoughBytes(found, expected) =>
      "Not enough bytes, expected \{expected} but found \{found}\n"
    StdIoError(err) => "Underlying I/O error \{err}\n"
    Generic(err) => "Generic I/O error: \{err}\n"
  }
}

///|
/// Common decode errors (upstream `zune_jpeg::errors::DecodeErrors`).
priv suberror DecodeErrors {
  /// Any other thing we do not know.
  Format(String)
  /// Any other thing we do not know but we don't need to allocate space on
  /// the heap.
  FormatStatic(String)
  /// Illegal magic bytes.
  IllegalMagicBytes(Int)
  /// Problems with the Huffman tables in a JPEG file.
  HuffmanDecode(String)
  /// Image has zero width.
  ZeroError
  /// Discrete quantization tables error.
  DqtError(String)
  /// Start of scan errors.
  SosError(String)
  /// Start of frame errors.
  SofError(String)
  /// Exhausted data.
  ExhaustedData
  /// Too small output for size.
  TooSmallOutput(Int, Int)
  IoErrors(ZByteIoError)
  /// Not upstream: a condition where upstream panics (e.g. an out of bounds
  /// slice index on corrupt input).
  Panic(String)
}

///|
/// Upstream `Display for DecodeErrors` (which forwards to `Debug`).
fn DecodeErrors::display(self : DecodeErrors) -> String {
  match self {
    Format(a) => rust_debug_str(a)
    FormatStatic(a) => rust_debug_str(a)
    HuffmanDecode(reason) => "Error decoding huffman values: \{reason}"
    ZeroError => "Image width or height is set to zero, cannot continue"
    DqtError(reason) => "Error parsing DQT segment. Reason:\{reason}"
    SosError(reason) => "Error parsing SOS Segment. Reason:\{reason}"
    SofError(reason) => "Error parsing SOF segment. Reason:\{reason}"
    IllegalMagicBytes(bytes) =>
      "Error parsing image. Illegal start bytes:\{bytes.to_string(radix=16).to_upper()}"
    ExhaustedData => "Exhausted data in the image"
    TooSmallOutput(expected, found) =>
      "Too small output, expected buffer with at least \{expected} bytes but got one with \{found} bytes"
    IoErrors(error) => "I/O errors \{error.debug()}"
    Panic(msg) => "panicked: \{msg}"
  }
}

///|
/// Rust's `Debug` output of a string.
fn rust_debug_str(s : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      '\u{0}' => buf.write_string("\\0")
      c if c.to_int() < 0x20 || c.to_int() == 0x7f =>
        buf.write_string("\\u{\{c.to_int().to_string(radix=16)}}")
      c => buf.write_char(c)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
/// A byte reader over an in-memory buffer (upstream `ZReader<ZCursor<&[u8]>>`).
///
/// Like upstream, the position may move past the end of the buffer through
/// `skip`; reads past the end then return no bytes.
priv struct ZReader {
  data : BytesView
  mut position : Int
}

///|
fn ZReader::new(data : BytesView) -> ZReader {
  { data, position: 0, }
}

///|
/// The number of bytes a read of `n` bytes can return.
fn ZReader::available(self : ZReader, n : Int) -> Int {
  let rem = self.data.length() - self.position
  if rem <= 0 {
    0
  } else if rem < n {
    rem
  } else {
    n
  }
}

///|
/// Read a single byte, returning 0 if there is none.
fn ZReader::read_u8(self : ZReader) -> Int {
  if self.position >= 0 && self.position < self.data.length() {
    let b = self.data[self.position].to_int()
    self.position += 1
    b
  } else {
    0
  }
}

///|
/// Read exactly `n` bytes, returning a view of them. On failure the
/// position is unchanged.
fn ZReader::read_exact_bytes(
  self : ZReader,
  n : Int,
) -> BytesView raise DecodeErrors {
  let got = self.available(n)
  if got < n {
    raise IoErrors(NotEnoughBytes(got, n))
  }
  let v = self.data[self.position:self.position + n]
  self.position += n
  v
}

///|
/// Read a single byte returning an error if the read cannot be satisfied.
fn ZReader::read_u8_err(self : ZReader) -> Int raise DecodeErrors {
  self.read_exact_bytes(1)[0].to_int()
}

///|
/// Read a big endian `u16`, returning an error if there are not enough
/// bytes.
fn ZReader::get_u16_be_err(self : ZReader) -> Int raise DecodeErrors {
  let v = self.read_exact_bytes(2)
  (v[0].to_int() << 8) | v[1].to_int()
}

///|
/// Read a big endian `u16`; missing bytes read as zero (upstream
/// `get_u16_be`, which reads as many bytes as are available).
fn ZReader::get_u16_be(self : ZReader) -> Int {
  let got = self.available(2)
  let mut v = 0
  for i in 0..<2 {
    v = v << 8
    if i < got {
      v = v | self.data[self.position + i].to_int()
    }
  }
  self.position += got
  v
}

///|
/// Skip ahead `num` bytes. This never fails.
fn ZReader::skip(self : ZReader, num : Int) -> Unit {
  self.position += num
}

///|
/// Move back `num` bytes.
fn ZReader::rewind(self : ZReader, num : Int) -> Unit raise DecodeErrors {
  if self.position - num < 0 {
    raise IoErrors(StdIoError("Negative seek"))
  }
  self.position -= num
}

///|
/// Look ahead `position` bytes and return `num_bytes` from there without
/// advancing.
fn ZReader::peek_at(
  self : ZReader,
  position : Int,
  num_bytes : Int,
) -> BytesView raise DecodeErrors {
  if position != 0 {
    self.skip(position)
  }
  if num_bytes > 20 * 1024 * 1024 {
    self.rewind(num_bytes)
    raise IoErrors(Generic("Too many bytes skipped"))
  }
  let got = self.available(num_bytes)
  if got < num_bytes {
    self.rewind(position)
    raise IoErrors(NotEnoughBytes(got, num_bytes))
  }
  let v = self.data[self.position:self.position + num_bytes]
  if position != 0 {
    self.rewind(position)
  }
  v
}

///|
/// Whether the underlying buffer can no longer produce bytes.
fn ZReader::eof(self : ZReader) -> Bool {
  self.position >= self.data.length()
}
