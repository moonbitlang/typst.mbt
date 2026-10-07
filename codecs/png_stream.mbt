// Port of the `png` crate (v0.18.1) `src/decoder/stream.rs`: the
// `StreamingDecoder`, a state machine over the chunks of a PNG file. It
// decides what a damaged file is: which chunks' CRCs are checked (all, by
// default; a mismatch is an error in a critical chunk and makes an ancillary
// chunk ignored), which chunk contents are errors, and in which order errors
// are found.
//
// The input is the whole file (upstream reads it through a `BufRead`, whose
// buffer `ReadDecoder` passes to `update`; for the `Cursor`s of `image`,
// krilla and tiny-skia that is all remaining data). Chunk data is not copied
// into `raw_bytes`: that `Vec` is a range of the input here, and only its
// length and capacity are kept, since the limit on allocations
// (`Limits::bytes`) counts its growth.

///|
const PNG_IHDR : UInt = 0x49484452

///|
const PNG_PLTE : UInt = 0x504C5445

///|
const PNG_IDAT : UInt = 0x49444154

///|
const PNG_IEND : UInt = 0x49454E44

///|
const PNG_TRNS : UInt = 0x74524E53

///|
const PNG_BKGD : UInt = 0x624B4744

///|
const PNG_PHYS : UInt = 0x70485973

///|
const PNG_CHRM : UInt = 0x6348524D

///|
const PNG_GAMA : UInt = 0x67414D41

///|
const PNG_SRGB : UInt = 0x73524742

///|
const PNG_ICCP : UInt = 0x69434350

///|
const PNG_CICP : UInt = 0x63494350

///|
const PNG_MDCV : UInt = 0x6D444356

///|
const PNG_CLLI : UInt = 0x634C4C49

///|
const PNG_EXIF : UInt = 0x65584966

///|
const PNG_TEXT : UInt = 0x74455874

///|
const PNG_ZTXT : UInt = 0x7A545874

///|
const PNG_ITXT : UInt = 0x69545874

///|
const PNG_SBIT : UInt = 0x73424954

///|
const PNG_ACTL : UInt = 0x6163544C

///|
const PNG_FCTL : UInt = 0x6663544C

///|
const PNG_FDAT : UInt = 0x66644154

///|
/// Returns true if the chunk is critical (upstream `chunk::is_critical`; a
/// chunk type is its four bytes as a big-endian number here).
fn chunk_is_critical(type_ : UInt) -> Bool {
  ((type_ >> 24) & 32) == 0
}

///|
/// Upstream `char::escape_debug` of a byte as a character (`char::from(u8)`):
/// the escapes of the control characters, of the quotes and of the
/// backslash, and `\u{..}` for the characters of Latin-1 that are not
/// printable (C0, DEL, C1, NBSP, SHY).
fn escape_debug_latin1(out : StringBuilder, c : Int) -> Unit {
  match c {
    0 => out.write_string("\\0")
    0x09 => out.write_string("\\t")
    0x0D => out.write_string("\\r")
    0x0A => out.write_string("\\n")
    0x5C => out.write_string("\\\\")
    0x22 => out.write_string("\\\"")
    0x27 => out.write_string("\\'")
    _ =>
      if c < 0x20 || (c >= 0x7F && c <= 0xA0) || c == 0xAD {
        out.write_string("\\u{")
        out.write_string(c.to_string(radix=16))
        out.write_string("}")
      } else {
        out.write_char(c.unsafe_to_char())
      }
  }
}

///|
/// The `Debug` output of upstream's `ChunkType`.
fn chunk_type_debug(type_ : UInt) -> String {
  let out = StringBuilder()
  out.write_string("ChunkType { type: ")
  for shift in [24, 16, 8, 0] {
    escape_debug_latin1(out, ((type_ >> shift) & 0xff).reinterpret_as_int())
  }
  out.write_string(", critical: ")
  out.write_string(chunk_is_critical(type_).to_string())
  // `is_private`
  out.write_string(", private: ")
  out.write_string((((type_ >> 16) & 32) != 0).to_string())
  // `reserved_set`
  out.write_string(", reserved: ")
  out.write_string((((type_ >> 8) & 32) != 0).to_string())
  // `safe_to_copy`
  out.write_string(", safecopy: ")
  out.write_string(((type_ & 32) != 0).to_string())
  out.write_string(" }")
  out.to_string()
}

///|
/// The `Debug` output of upstream's `ColorType`.
fn png_color_type_debug(color_type : PngColorType) -> String {
  match color_type {
    Grayscale => "Grayscale"
    Rgb => "Rgb"
    Indexed => "Indexed"
    GrayscaleAlpha => "GrayscaleAlpha"
    Rgba => "Rgba"
  }
}

///|
/// The `Debug` output of upstream's `BitDepth`.
fn png_bit_depth_debug(bit_depth : Int) -> String {
  match bit_depth {
    1 => "One"
    2 => "Two"
    4 => "Four"
    8 => "Eight"
    _ => "Sixteen"
  }
}

///|
/// The kinds of `std::io::Error` that the decoder makes.
priv enum IoErrorKind {
  UnexpectedEof
  InvalidData
}

///|
/// Any kind of error during PNG decoding (upstream `DecodingError`).
priv suberror DecodingError {
  /// An error in IO of the underlying reader.
  IoError(IoErrorKind)
  /// The input image was not a valid PNG. The payload is the `Display`
  /// output of upstream's `FormatError`.
  Format(String)
  /// An interface was used incorrectly. The payload is the `Display` output
  /// of upstream's `ParameterError`.
  Parameter(String)
  /// The image would have required exceeding the limits configured with the decoder.
  LimitsExceeded
}

///|
/// Upstream `impl fmt::Display for DecodingError`.
fn DecodingError::to_string(self : DecodingError) -> String {
  match self {
    // `impl fmt::Display for std::io::ErrorKind` (an `io::Error` made from a
    // kind prints the kind's description).
    IoError(UnexpectedEof) => "unexpected end of file"
    IoError(InvalidData) => "invalid data"
    Parameter(desc) => desc
    Format(desc) => desc
    LimitsExceeded => "limits are exceeded"
  }
}

///|
/// Raises `DecodingError::Format` with the message of
/// `FormatErrorInner::CrcMismatch`.
fn[T] crc_mismatch(
  crc_val : UInt,
  crc_sum : UInt,
  chunk : UInt,
) -> T raise DecodingError {
  raise Format(
    "CRC error: expected 0x\{crc_val.to_string(radix=16)} have 0x\{crc_sum.to_string(radix=16)} while decoding \{chunk_type_debug(chunk)} chunk.",
  )
}

///|
/// The message of `FormatErrorInner::CorruptFlateStream`.
fn corrupt_flate_stream(err : DecompressionError) -> DecodingError {
  Format("Corrupt deflate stream. \{err.debug()}")
}

///|
/// Frame control information (upstream `FrameControl`; the delay, dispose
/// and blend fields are validated and not kept).
priv struct FrameControl {
  /// Width of the following frame
  width : UInt
  /// Height of the following frame
  height : UInt
  /// X position at which to render the following frame
  x_offset : UInt
  /// Y position at which to render the following frame
  y_offset : UInt
}

///|
/// PNG info struct (upstream `Info`). Of the chunks that nothing reads
/// (`sBIT`, `gAMA`, `cHRM`, `sRGB`, `cICP`, `mDCV`, `cLLI`, `bKGD`, `eXIf`,
/// text) only what the decoder itself asks is kept: whether one was seen.
priv struct StreamInfo {
  width : UInt
  height : UInt
  bit_depth : Int
  /// How colors are stored in the image.
  color_type : PngColorType
  interlaced : Bool
  /// The image's `sBIT` chunk, if present; contains significant bits of the sample.
  mut sbit : Bool
  /// The image's `tRNS` chunk, if present; contains the alpha channel of the image's palette, 1 byte per entry.
  mut trns : Bytes?
  mut pixel_dims : PixelDimensions?
  /// The image's `PLTE` chunk, if present; contains the RGB channels (in that order) of the image's palettes, 3 bytes per entry (1 per channel).
  mut palette : Bytes?
  /// The contents of the image's gAMA chunk, if present.
  mut gama_chunk : Bool
  /// The contents of the image's `cHRM` chunk, if present.
  mut chrm_chunk : Bool
  /// The contents of the image's `bKGD` chunk, if present.
  mut bkgd : Bool
  mut frame_control : FrameControl?
  /// `AnimationControl::num_frames` of the `acTL` chunk.
  mut animation_control : UInt?
  /// The rendering intent of an SRGB image.
  mut srgb : Bool
  /// The ICC profile for the image.
  mut icc_profile : Bytes?
  /// The coding-independent code points for video signal type identification of the image.
  mut coding_independent_code_points : Bool
  /// The mastering display color volume for the image.
  mut mastering_display_color_volume : Bool
  /// The content light information for the image.
  mut content_light_level : Bool
  /// The EXIF metadata for the image.
  mut exif_metadata : Bool
}

///|
/// Returns the number of bytes needed for one deinterlaced row of width
/// `width` (upstream `ColorType::raw_row_length_from_width`; `usize` is 64
/// bits).
fn raw_row_length_from_width(
  color_type : PngColorType,
  depth : Int,
  width : UInt,
) -> Int64 {
  let samples = width.to_int64() * color_type.samples().to_int64()
  1L +
  (match depth {
    16 => samples * 2L
    8 => samples
    subbyte => {
      let samples_per_byte = (8 / subbyte).to_int64()
      let whole = samples / samples_per_byte
      let fract = if samples % samples_per_byte > 0L { 1L } else { 0L }
      whole + fract
    }
  })
}

///|
/// Returns the number of bytes needed for one deinterlaced row of width `width`.
fn StreamInfo::raw_row_length_from_width(
  self : StreamInfo,
  width : UInt,
) -> Int64 {
  raw_row_length_from_width(self.color_type, self.bit_depth, width)
}

///|
/// Upstream `Info::bytes_per_pixel` (and `bpp_in_prediction`): the number of
/// bytes for a pixel used in prediction.
fn StreamInfo::bytes_per_pixel(self : StreamInfo) -> Int {
  self.color_type.samples() * ((self.bit_depth + 7) >> 3)
}

///|
/// Limits on the resources the `Decoder` is allowed too use (upstream
/// `Limits`).
priv struct Limits {
  /// maximum number of bytes the decoder is allowed to allocate, default is 64Mib
  mut bytes : UInt64
}

///|
fn Limits::reserve_bytes(
  self : Limits,
  bytes : UInt64,
) -> Unit raise DecodingError {
  if self.bytes >= bytes {
    self.bytes -= bytes
  } else {
    raise LimitsExceeded
  }
}

///|
/// Upstream `CHUNK_BUFFER_SIZE`.
const CHUNK_BUFFER_SIZE : UInt64 = 128

///|
/// Kind of `u32` value that is being read via `State::U32`.
priv enum U32ValueKind {
  /// First 4 bytes of the PNG signature - see
  /// http://www.libpng.org/pub/png/spec/1.2/PNG-Structure.html#PNG-file-signature
  Signature1stU32
  /// Second 4 bytes of the PNG signature - see
  /// http://www.libpng.org/pub/png/spec/1.2/PNG-Structure.html#PNG-file-signature
  Signature2ndU32
  /// Chunk length - see
  /// http://www.libpng.org/pub/png/spec/1.2/PNG-Structure.html#Chunk-layout
  Length
  /// Chunk type - see
  /// http://www.libpng.org/pub/png/spec/1.2/PNG-Structure.html#Chunk-layout
  Type(UInt)
  /// Chunk checksum - see
  /// http://www.libpng.org/pub/png/spec/1.2/PNG-Structure.html#Chunk-layout
  Crc(UInt)
  /// Sequence number from an `fdAT` chunk - see
  /// https://wiki.mozilla.org/APNG_Specification#.60fdAT.60:_The_Frame_Data_Chunk
  ApngSequenceNumber
}

///|
priv enum StreamState {
  /// In this state we are reading a u32 value from external input.  We start with
  /// `accumulated_count` set to `0`. After reading or accumulating the required 4 bytes we will
  /// call `parse_32` which will then move onto the next state. The fields
  /// are the kind, the accumulated bytes (big-endian, the first one in the
  /// most significant byte) and their count.
  U32(U32ValueKind, UInt, Int)
  /// In this state we are reading chunk data from external input, and appending it to
  /// `ChunkState::raw_bytes`. Then if all data has been read, we parse the chunk.
  ReadChunkData(UInt)
  /// In this state we are reading image data from external input and feeding it directly into
  /// `StreamingDecoder::inflater`.
  ImageData(UInt)
}

///|
fn StreamState::new_u32(kind : U32ValueKind) -> StreamState {
  U32(kind, 0, 0)
}

///|
/// Result of the decoding process
// The length of `ChunkBegin` and the chunks of `BadAncillaryChunk` and
// `SkippedAncillaryChunk` are for the callers of `update`, of which the
// `png` crate's own (`read_decoder.rs`) read none (png 0.18.1
// src/decoder/stream.rs:84-109).
#warnings("-unused_constructor-unused_field")
priv enum Decoded {
  /// Nothing decoded yet
  Nothing
  /// A chunk header (length and type fields) has been read.
  ChunkBegin(UInt, UInt)
  /// Chunk has been read successfully.
  ChunkComplete(UInt)
  /// An ancillary chunk has been read but it was in the wrong place, had corrupt contents, or had
  /// an invalid CRC.
  BadAncillaryChunk(UInt)
  /// Skipped an ancillary chunk because it was unrecognized or the decoder was configured to skip
  /// this type of chunk.
  SkippedAncillaryChunk(UInt)
  /// Decoded raw image data.
  ImageData
  /// The last of a consecutive chunk of IDAT was done.
  /// This is distinct from ChunkComplete which only marks that some IDAT chunk was completed but
  /// not that no additional IDAT chunk follows.
  ImageDataFlushed
}

///|
priv enum ChunkAction {
  Process
  Skip
  Reject
}

///|
/// PNG StreamingDecoder (low-level interface)
///
/// By default, the decoder does not verify Adler-32 checksum computation.
///
/// The decode options are upstream's defaults (`DecodeOptions::default()`,
/// which no caller of the ports changes): `ignore_adler32: true`,
/// `ignore_crc: false`, `ignore_text_chunk: false`, `ignore_iccp_chunk:
/// false`, `skip_ancillary_crc_failures: true`.
priv struct StreamingDecoder {
  mut state : StreamState?
  // `current_chunk: ChunkState`
  /// The type of the current chunk.
  /// Relevant for `IDAT` and `fdAT` which aggregate consecutive chunks of their own type.
  mut type_ : UInt
  /// Partial crc until now.
  mut crc : UInt
  /// Remaining bytes to be read.
  mut remaining : UInt
  /// Non-decoded bytes in the chunk (upstream `raw_bytes: Vec<u8>`): the
  /// input at `raw_bytes_start`, of length `raw_bytes_len`, and the
  /// capacity that the `Vec` would have.
  mut raw_bytes : BytesView
  mut raw_bytes_len : UInt64
  mut raw_bytes_capacity : UInt64
  /// Whether this chunk should be skipped or decoded.
  mut action : ChunkAction
  /// The inflater state handling consecutive `IDAT` and `fdAT` chunks.
  inflater : ZlibStream
  /// The complete image info read from all prior chunks.
  mut info : StreamInfo?
  /// The animation chunk sequence number.
  mut current_seq_no : UInt?
  /// Whether we have already seen a start of an IDAT chunk.  (Used to validate chunk ordering -
  /// some chunk types can only appear before or after an IDAT chunk.)
  mut have_idat : Bool
  /// Whether we are ready for a start of an `IDAT` chunk sequence.  Initially `true` and set to
  /// `false` when the first sequence of consecutive `IDAT` chunks ends.
  mut ready_for_idat_chunks : Bool
  /// Whether we are ready for a start of an `fdAT` chunk sequence.  Initially `false`.  Set to
  /// `true` after encountering an `fcTL` chunk. Set to `false` when a sequence of consecutive
  /// `fdAT` chunks ends.
  mut ready_for_fdat_chunks : Bool
  /// Whether we have already seen an iCCP chunk. Used to prevent parsing of duplicate iCCP chunks.
  mut have_iccp : Bool
  limits : Limits
  /// The first element of the result of `update` and of `next_state`: the
  /// number of bytes that have been consumed from the input buffer.
  mut consumed : Int
}

///|
/// Creates a new StreamingDecoder (upstream `new_with_options` with the
/// default options). Upstream's `new` has no limit (`usize::MAX`); `Decoder`
/// sets one.
fn StreamingDecoder::new(limits : Limits) -> StreamingDecoder {
  let inflater = ZlibStream::new()
  {
    state: Some(StreamState::new_u32(Signature1stU32)),
    type_: 0,
    crc: 0,
    remaining: 0,
    raw_bytes: b""[:],
    raw_bytes_len: 0,
    raw_bytes_capacity: CHUNK_BUFFER_SIZE,
    action: Process,
    inflater,
    info: None,
    current_seq_no: None,
    have_idat: false,
    have_iccp: false,
    ready_for_idat_chunks: true,
    ready_for_fdat_chunks: false,
    limits,
    consumed: 0,
  }
}

///|
/// The info of the image, which is read before any other chunk is parsed
/// (upstream `self.info.as_mut().unwrap()`).
fn StreamingDecoder::info_mut(self : StreamingDecoder) -> StreamInfo {
  guard self.info is Some(info) else { abort("no IHDR chunk was parsed") }
  info
}

///|
/// Low level StreamingDecoder interface.
///
/// Allows to stream partial data to the encoder. Returns the current
/// decoding result and sets `consumed` to the bytes that have been consumed
/// from the input buffer. If the decoded chunk was an image data chunk, it
/// also appends the read data to `image_data`.
fn StreamingDecoder::update(
  self : StreamingDecoder,
  buf : BytesView,
  image_data : UnfilteringBuffer?,
) -> Decoded raise DecodingError {
  if self.state is None {
    // `ParameterErrorKind::PolledAfterFatalError`
    raise Parameter("A fatal decoding error has been encounted earlier")
  }
  let len = buf.length()
  let mut pos = 0
  while pos < len {
    let result = self.next_state(buf[pos:], image_data)
    pos += self.consumed
    if !(result is Nothing) {
      self.consumed = pos
      return result
    }
  }
  self.consumed = pos
  Nothing
}

///|
fn StreamingDecoder::next_state(
  self : StreamingDecoder,
  buf : BytesView,
  image_data : UnfilteringBuffer?,
) -> Decoded raise DecodingError {
  // Driver should ensure that state is never None
  guard self.state is Some(state) else { abort("state is never None") }
  self.state = None
  match state {
    U32(kind, bytes, accumulated_count) =>
      if accumulated_count == 0 && buf.length() >= 4 {
        // Handling these `accumulated_count` and `buf.len()` values in a separate `if`
        // branch is not strictly necessary - the `else` statement below is already
        // capable of handling these values.  The main reason for special-casing these
        // values is that they occur fairly frequently and special-casing them results
        // in performance gains.
        self.parse_u32(kind, u32_be(buf, 0), buf[0:4], image_data, 4)
      } else {
        let remaining_count = 4 - accumulated_count
        let available_count = @cmp.minimum(remaining_count, buf.length())
        let mut bytes = bytes
        for i in 0..<available_count {
          bytes = bytes |
            (
              buf[i].to_int().reinterpret_as_uint() <<
              (8 * (3 - accumulated_count - i))
            )
        }
        let accumulated_count = accumulated_count + available_count
        let consumed_bytes = available_count
        if accumulated_count < 4 {
          self.state = Some(U32(kind, bytes, accumulated_count))
          self.consumed = consumed_bytes
          Nothing
        } else {
          let type_bytes = Bytes::from_array([
            (bytes >> 24).to_byte(),
            (bytes >> 16).to_byte(),
            (bytes >> 8).to_byte(),
            bytes.to_byte(),
          ])
          self.parse_u32(kind, bytes, type_bytes[:], image_data, consumed_bytes)
        }
      }
    ReadChunkData(type_str) =>
      if self.remaining == 0 {
        self.state = Some(StreamState::new_u32(Crc(type_str)))
        self.consumed = 0
        Nothing
      } else {
        let buf_avail = self.raw_bytes_capacity - self.raw_bytes_len
        let bytes_avail = @cmp.minimum(buf.length().to_uint64(), buf_avail)
        // `min(*remaining, bytes_avail as u32)`
        let n = @cmp.minimum(
          self.remaining,
          (bytes_avail & 0xFFFFFFFFUL).to_uint(),
        ).reinterpret_as_int()
        let buf = buf[:n]
        self.crc = crc32_braid(self.crc, buf)
        if self.action is Process {
          if self.raw_bytes_len == self.raw_bytes_capacity {
            if self.limits.bytes == 0 {
              raise LimitsExceeded
            }

            // Double the size of the Vec, but not beyond the allocation limit.
            let reserve_size = @cmp.minimum(
              self.raw_bytes_capacity,
              self.limits.bytes,
            )
            self.limits.reserve_bytes(reserve_size)
            self.raw_bytes_capacity += reserve_size
          }
          // `raw_bytes.extend_from_slice(buf)`: the bytes of a chunk follow
          // each other in the input.
          if self.raw_bytes_len == 0 {
            self.raw_bytes = buf
          } else {
            let data = self.raw_bytes.data()
            let start = self.raw_bytes.start_offset()
            self.raw_bytes = data[start:start + self.raw_bytes_len.to_int() + n]
          }
          self.raw_bytes_len += n.to_uint64()
        }
        self.remaining -= n.reinterpret_as_uint()
        if self.remaining == 0 {
          self.state = Some(StreamState::new_u32(Crc(type_str)))
        } else {
          self.state = Some(ReadChunkData(type_str))
        }
        self.consumed = n
        Nothing
      }
    ImageData(type_str) => {
      let len = if self.remaining.to_uint64() < buf.length().to_uint64() {
        self.remaining.reinterpret_as_int()
      } else {
        buf.length()
      }
      let buf = buf[:len]
      let consumed = match image_data {
        Some(image_data) => self.inflater.decompress(buf, image_data)
        None => len
      }
      self.crc = crc32_braid(self.crc, buf[:consumed])
      self.remaining -= consumed.reinterpret_as_uint()
      if self.remaining == 0 {
        self.state = Some(StreamState::new_u32(Crc(type_str)))
      } else {
        self.state = Some(ImageData(type_str))
      }
      self.consumed = consumed
      ImageData
    }
  }
}

///|
/// `val` is the big-endian value of the four bytes `u32_be_bytes`.
fn StreamingDecoder::parse_u32(
  self : StreamingDecoder,
  kind : U32ValueKind,
  val : UInt,
  u32_be_bytes : BytesView,
  image_data : UnfilteringBuffer?,
  consumed_bytes : Int,
) -> Decoded raise DecodingError {
  self.consumed = consumed_bytes
  match kind {
    Signature1stU32 =>
      // [137, 80, 78, 71]
      if val == 0x89504E47 {
        self.state = Some(StreamState::new_u32(Signature2ndU32))
        Nothing
      } else {
        raise Format("Invalid PNG signature.")
      }
    Signature2ndU32 =>
      // [13, 10, 26, 10]
      if val == 0x0D0A1A0A {
        self.state = Some(StreamState::new_u32(Length))
        Nothing
      } else {
        raise Format("Invalid PNG signature.")
      }
    Length => {
      self.state = Some(StreamState::new_u32(Type(val)))
      Nothing
    }
    Type(length) => {
      let type_str = val
      if self.info is None && type_str != PNG_IHDR {
        raise Format(
          "\{chunk_type_debug(type_str)} chunk appeared before IHDR chunk",
        )
      }
      if type_str != self.type_ &&
        (self.type_ == PNG_IDAT || self.type_ == PNG_FDAT) {
        let finished = match image_data {
          Some(image_data) => self.inflater.finish(image_data)
          None => true
        }

        // We ended up handling IDAT/fdAT data rather than the chunk
        // type header atually received. Thus rewind `self.state` to
        // what it was before this function was called.
        self.state = Some(U32(kind, val, 4 - consumed_bytes))
        self.consumed = 0
        if finished {
          // We've processed all the image data necessary. Update
          // `current_chunk.type_`so this codepath isn't taken
          // again next time.
          self.type_ = type_str
          self.ready_for_idat_chunks = false
          self.ready_for_fdat_chunks = false
          return ImageDataFlushed
        } else {
          // Report that we processed some image data without
          // consuming any input. This gives the caller a chance
          // to grow the output buffer and call us again.
          return ImageData
        }
      }
      self.type_ = type_str
      // `crc.reset(); crc.update(&type_str.0)`
      self.crc = crc32_braid(0, u32_be_bytes)
      self.remaining = length
      // `raw_bytes.clear()`
      self.raw_bytes_len = 0
      self.raw_bytes = b""[:]
      self.state = match type_str {
        PNG_FDAT => {
          if !self.ready_for_fdat_chunks {
            raise Format(
              "Unexpected restart of \{chunk_type_debug(PNG_FDAT)} chunk sequence",
            )
          }
          if length < 4 {
            raise Format("fdAT chunk shorter than 4 bytes")
          }
          self.action = Process
          Some(StreamState::new_u32(ApngSequenceNumber))
        }
        PNG_IDAT => {
          if !self.ready_for_idat_chunks {
            raise Format(
              "Unexpected restart of \{chunk_type_debug(PNG_IDAT)} chunk sequence",
            )
          }
          self.have_idat = true
          self.action = Process
          Some(ImageData(type_str))
        }
        _ => Some(self.start_chunk(type_str, length))
      }
      ChunkBegin(length, type_str)
    }
    Crc(type_str) => {
      let sum = self.crc
      if val == sum {
        match self.action {
          Process => {
            // A fatal error in chunk parsing leaves the decoder in state 'None' to enforce
            // that parsing can't continue after an error.
            let decoded = self.parse_chunk(type_str)
            if type_str != PNG_IEND {
              self.state = Some(StreamState::new_u32(Length))
            }
            decoded
          }
          Skip => {
            self.state = Some(StreamState::new_u32(Length))
            SkippedAncillaryChunk(self.type_)
          }
          Reject => {
            self.state = Some(StreamState::new_u32(Length))
            BadAncillaryChunk(type_str)
          }
        }
      } else if !chunk_is_critical(type_str) {
        // Ignore ancillary chunk with invalid CRC
        self.state = Some(StreamState::new_u32(Length))
        BadAncillaryChunk(type_str)
      } else {
        crc_mismatch(val, sum, type_str)
      }
    }
    ApngSequenceNumber => {
      let next_seq_no = val

      // Should be verified by the FdatShorterThanFourBytes check earlier.
      self.remaining -= 4
      match self.current_seq_no {
        Some(seq_no) => {
          if next_seq_no != seq_no + 1 {
            raise Format(
              "Sequence is not in order, expected #\{seq_no + 1} got #\{next_seq_no}.",
            )
          }
          self.current_seq_no = Some(next_seq_no)
        }
        None => raise Format("fcTL chunk missing before fdAT chunk.")
      }
      self.crc = crc32_braid(self.crc, u32_be_bytes)
      self.state = Some(ImageData(PNG_FDAT))
      Nothing
    }
  }
}

///|
fn StreamingDecoder::start_chunk(
  self : StreamingDecoder,
  type_str : UInt,
  length : UInt,
) -> StreamState raise DecodingError {
  let (min, max) : (UInt, UInt) = match type_str {
    PNG_IHDR => (13, 13)
    PNG_PLTE => (3, 768)
    PNG_IEND => (0, 0)
    PNG_SBIT => (1, 4)
    PNG_TRNS => (1, 256)
    PNG_PHYS => (9, 9)
    PNG_GAMA => (4, 4)
    PNG_ACTL => (8, 8)
    PNG_FCTL => (26, 26)
    PNG_CHRM => (32, 32)
    PNG_SRGB => (1, 1)
    PNG_CICP => (4, 4)
    PNG_MDCV => (24, 24)
    PNG_CLLI => (8, 8)
    PNG_BKGD => (1, 6)

    // Unbounded size chunks
    // TODO: allow skipping.
    PNG_EXIF | PNG_ICCP | PNG_TEXT | PNG_ZTXT | PNG_ITXT =>
      (0, 0xFFFFFFFFU >> 1)
    _ => {
      // (`IDAT` and `fdAT` do not come here.)
      if chunk_is_critical(type_str) {
        raise Format(
          "Unrecognized critical chunk: \{chunk_type_debug(type_str)}",
        )
      }
      self.action = Skip
      return ReadChunkData(type_str)
    }
  }
  if length < min || length > max {
    match type_str {
      PNG_IHDR | PNG_PLTE | PNG_IEND | PNG_FCTL =>
        raise Format("Chunk length wrong: \{chunk_type_debug(type_str)}")
      _ => self.action = Reject
    }
  } else {
    self.action = Process
  }
  ReadChunkData(type_str)
}

///|
fn StreamingDecoder::parse_chunk(
  self : StreamingDecoder,
  type_str : UInt,
) -> Decoded raise DecodingError {
  try {
    match type_str {
      // Critical non-data chunks.
      PNG_IHDR => self.parse_ihdr()
      PNG_PLTE => self.parse_plte()
      // TODO: Check chunk size.
      PNG_IEND => ()

      // Data chunks handled separately.
      PNG_IDAT => ()
      PNG_FDAT => ()

      // Recognized bounded-size ancillary chunks.
      PNG_SBIT => self.parse_sbit()
      PNG_TRNS => self.parse_trns()
      PNG_PHYS => self.parse_phys()
      PNG_GAMA => self.parse_gama()
      PNG_ACTL => self.parse_actl()
      PNG_FCTL => self.parse_fctl()
      PNG_CHRM => self.parse_chrm()
      PNG_SRGB => self.parse_srgb()
      PNG_CICP => self.parse_cicp()
      PNG_MDCV => self.parse_mdcv()
      PNG_CLLI => self.parse_clli()
      PNG_BKGD => self.parse_bkgd()

      // Ancillary chunks with unbounded size.
      PNG_EXIF => self.parse_exif()
      PNG_ICCP => self.parse_iccp()
      PNG_TEXT | PNG_ZTXT | PNG_ITXT => self.parse_text()

      // Unrecognized chunks.
      _ =>
        abort(
          "Unrecognized chunk \{chunk_type_debug(type_str)} should have been caught in start_chunk",
        )
    }
    ChunkComplete(type_str)
  } catch {
    // `parse_chunk` is invoked after gathering **all** bytes of a chunk, so
    // `UnexpectedEof` from something like `read_be` is permanent and indicates an
    // invalid PNG that should be represented as a `FormatError`, rather than as a
    // (potentially recoverable) `IoError` / `UnexpectedEof`.
    // (`FormatErrorInner::ChunkLengthWrong { kind: type_str }`)
    IoError(UnexpectedEof) | Format(_) as e =>
      if type_str != PNG_FCTL && !chunk_is_critical(type_str) {
        // Ignore benign errors in most auxiliary chunks. `LimitsExceeded`, `Parameter` and
        // other error kinds are *not* treated as benign. We don't ignore errors in `fcTL`
        // chunks because the fallback to the static/non-animated image has to be
        // implemented *on top* of the `StreamingDecoder` API.
        //
        // TODO: Consider supporting a strict mode where even benign errors are reported up.
        // See https://github.com/image-rs/image-png/pull/569#issuecomment-2642062285
        BadAncillaryChunk(type_str)
      } else {
        match e {
          IoError(UnexpectedEof) =>
            raise Format("Chunk length wrong: \{chunk_type_debug(type_str)}")
          e => raise e
        }
      }
    e => raise e
  }
}

///|
/// Upstream `buf.read_be()?` for a `u32` at `self.raw_bytes[pos..]`.
fn StreamingDecoder::read_be_u32(
  self : StreamingDecoder,
  pos : Int,
) -> UInt raise DecodingError {
  if pos + 4 > self.raw_bytes.length() {
    raise IoError(UnexpectedEof)
  }
  u32_be(self.raw_bytes, pos)
}

///|
/// Upstream `buf.read_be()?` for a `u8` at `self.raw_bytes[pos..]`.
fn StreamingDecoder::read_be_u8(
  self : StreamingDecoder,
  pos : Int,
) -> Int raise DecodingError {
  if pos + 1 > self.raw_bytes.length() {
    raise IoError(UnexpectedEof)
  }
  self.raw_bytes[pos].to_int()
}

///|
fn StreamingDecoder::parse_fctl(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let next_seq_no = self.read_be_u32(0)

  // Assuming that fcTL is required before *every* fdAT-sequence
  self.current_seq_no = Some(
    match self.current_seq_no {
      Some(seq_no) => {
        if next_seq_no != seq_no + 1 {
          raise Format(
            "Sequence is not in order, expected #\{seq_no + 1} got #\{next_seq_no}.",
          )
        }
        next_seq_no
      }
      None => {
        if next_seq_no != 0 {
          raise Format(
            "Sequence is not in order, expected #0 got #\{next_seq_no}.",
          )
        }
        0
      }
    },
  )
  self.inflater.reset()
  self.ready_for_fdat_chunks = self.have_idat
  let width = self.read_be_u32(4)
  let height = self.read_be_u32(8)
  let x_offset = self.read_be_u32(12)
  let y_offset = self.read_be_u32(16)
  // `delay_num`, `delay_den`: two `u16`s (the chunk has 26 bytes)
  let dispose_op = self.read_be_u8(24)
  if dispose_op > 2 {
    raise Format("Invalid dispose op \{dispose_op}.")
  }
  let blend_op = self.read_be_u8(25)
  if blend_op > 1 {
    raise Format("Invalid blend op \{blend_op}.")
  }
  let fc = { width, height, x_offset, y_offset, }
  let info = self.info_mut()
  // `Info::validate`
  if fc.width == 0 || fc.height == 0 {
    raise Format("Invalid image dimensions")
  }
  // Validate mathematically: fc.width + fc.x_offset <= self.width
  let in_x_bounds = info.width >= fc.x_offset &&
    fc.width <= info.width - fc.x_offset
  // Validate mathematically: fc.height + fc.y_offset <= self.height
  let in_y_bounds = info.height >= fc.y_offset &&
    fc.height <= info.height - fc.y_offset
  if !in_x_bounds || !in_y_bounds {
    // TODO: do we want to display the bad bounds?
    raise Format("Sub frame is out-of-bounds.")
  }
  if !self.have_idat {
    // `Info::validate_default_image`
    //
    // https://www.w3.org/TR/png-3/#fcTL-chunk says that:
    //
    // > The fcTL chunk corresponding to the default image, if it exists, has these
    // > restrictions:
    // >
    // > * The x_offset and y_offset fields must be 0.
    // > * The width and height fields must equal
    // >   the corresponding fields from the IHDR chunk.
    if fc.x_offset != 0 ||
      fc.y_offset != 0 ||
      fc.width != info.width ||
      fc.height != info.height {
      raise Format("Sub frame is out-of-bounds.")
    }
  }
  info.frame_control = Some(fc)
}

///|
fn StreamingDecoder::parse_actl(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_ACTL)} is invalid after IDAT chunk.",
    )
  } else if info.animation_control is Some(_) {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_ACTL)} must appear at most once.",
    )
  } else {
    let num_frames = self.read_be_u32(0)
    let num_plays = self.read_be_u32(4)
    // The spec says that "0 is not a valid value" for `num_frames`.
    // So let's ignore such malformed `acTL` chunks.
    if num_frames == 0 {
      return
    }

    // The spec also says that the number of frames and number of plays should be limited
    // to (2^31)-1. Same as the other condition we enforce it by ignoring the chunk.
    // Another option may be saturation which would lose us some frames but encourage
    // rather dubious handling.
    if num_frames > 0x7FFFFFFF || num_plays > 0x7FFFFFFF {
      return
    }
    info.animation_control = Some(num_frames)
  }
}

///|
fn StreamingDecoder::parse_plte(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if info.palette is Some(_) {
    // Only one palette is allowed
    raise Format(
      "Chunk \{chunk_type_debug(PNG_PLTE)} must appear at most once.",
    )
  } else {
    info.palette = Some(self.raw_bytes.to_owned())
  }
}

///|
fn StreamingDecoder::parse_sbit(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if info.palette is Some(_) {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_SBIT)} is invalid after PLTE chunk.",
    )
  }
  if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_SBIT)} is invalid after IDAT chunk.",
    )
  }
  if info.sbit {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_SBIT)} must appear at most once.",
    )
  }
  let color_type = info.color_type
  // The sample depth for color type 3 is fixed at eight bits.
  let sample_depth = if color_type is Indexed { 8 } else { info.bit_depth }
  let len = self.raw_bytes.length()

  // expected lenth of the chunk
  let expected = match color_type {
    Grayscale => 1
    Rgb | Indexed => 3
    GrayscaleAlpha => 2
    Rgba => 4
  }

  // Check if the sbit chunk size is valid.
  if expected != len {
    raise Format(
      "The size of the sBIT chunk should be \{expected} byte(s), but \{len} byte(s) were provided for the \{png_color_type_debug(color_type)} color type.",
    )
  }
  for i in 0..<len {
    let sbit = self.raw_bytes[i].to_int()
    if sbit < 1 || sbit > sample_depth {
      raise Format(
        "Invalid sBIT value \{sbit}. It must be greater than zero and less than the sample depth \{png_bit_depth_debug(sample_depth)}.",
      )
    }
  }
  info.sbit = true
}

///|
fn StreamingDecoder::parse_trns(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if info.trns is Some(_) {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_PLTE)} must appear at most once.",
    )
  }
  let color_type = info.color_type
  let bit_depth = info.bit_depth
  let vec = self.raw_bytes
  let len = vec.length()
  match color_type {
    Grayscale => {
      if len < 2 {
        raise Format("Not enough palette entries, expect 2 got \{len}.")
      }
      info.trns = Some(
        if bit_depth < 16 {
          Bytes::from_array([vec[1]])
        } else {
          vec.to_owned()
        },
      )
    }
    Rgb => {
      if len < 6 {
        raise Format("Not enough palette entries, expect 6 got \{len}.")
      }
      info.trns = Some(
        if bit_depth < 16 {
          Bytes::from_array([vec[1], vec[3], vec[5]])
        } else {
          vec.to_owned()
        },
      )
    }
    Indexed => {
      // The transparency chunk must be after the palette chunk and
      // before the data chunk.
      if info.palette is None {
        raise Format(
          "Chunk \{chunk_type_debug(PNG_TRNS)} is invalid before PLTE chunk.",
        )
      } else if self.have_idat {
        raise Format(
          "Chunk \{chunk_type_debug(PNG_TRNS)} must appear between PLTE and IDAT chunks.",
        )
      }
      info.trns = Some(vec.to_owned())
    }
    c =>
      raise Format(
        "Transparency chunk found for color type \{png_color_type_debug(c)}.",
      )
  }
}

///|
fn StreamingDecoder::parse_phys(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_PHYS)} is invalid after IDAT chunk.",
    )
  } else if info.pixel_dims is Some(_) {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_PHYS)} must appear at most once.",
    )
  } else {
    let xppu = self.read_be_u32(0)
    let yppu = self.read_be_u32(4)
    let unit = self.read_be_u8(8)
    if unit > 1 {
      raise Format("Invalid physical pixel size unit \{unit}.")
    }
    info.pixel_dims = Some({ xppu, yppu, meter: unit == 1, })
  }
}

///|
fn StreamingDecoder::parse_chrm(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_CHRM)} is invalid after IDAT chunk.",
    )
  } else if info.chrm_chunk {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_CHRM)} must appear at most once.",
    )
  } else {
    // Eight `u32`s (the chunk has 32 bytes).
    let _ = self.read_be_u32(28)
    info.chrm_chunk = true
  }
}

///|
fn StreamingDecoder::parse_gama(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_GAMA)} is invalid after IDAT chunk.",
    )
  } else if info.gama_chunk {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_GAMA)} must appear at most once.",
    )
  } else {
    let source_gamma = self.read_be_u32(0)
    if source_gamma == 0 {
      raise Format("Bad gamma value.")
    }
    info.gama_chunk = true
  }
}

///|
fn StreamingDecoder::parse_srgb(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_SRGB)} is invalid after IDAT chunk.",
    )
  } else if info.srgb {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_SRGB)} must appear at most once.",
    )
  } else {
    // BE is is nonsense for single bytes, but this way the size is checked.
    let raw = self.read_be_u8(0)
    // `SrgbRenderingIntent::from_raw`
    if raw > 3 {
      raise Format("Invalid sRGB rendering intent \{raw}.")
    }

    // Set srgb and override source gamma and chromaticities.
    info.srgb = true
  }
}

///|
fn StreamingDecoder::parse_cicp(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()

  // The spec requires that the cICP chunk MUST come before the PLTE and IDAT chunks.
  if info.coding_independent_code_points {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_CICP)} must appear at most once.",
    )
  } else if info.palette is Some(_) {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_CICP)} is invalid after PLTE chunk.",
    )
  } else if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_CICP)} is invalid after IDAT chunk.",
    )
  }
  // `color_primaries`, `transfer_function`
  let matrix_coefficients = self.read_be_u8(2)
  let flag = self.read_be_u8(3)
  if flag > 1 {
    raise IoError(InvalidData)
  }

  // RGB is currently the only supported color model in PNG, and as
  // such Matrix Coefficients shall be set to 0.
  if matrix_coefficients != 0 {
    raise IoError(InvalidData)
  }
  if self.raw_bytes.length() != 4 {
    raise IoError(InvalidData)
  }
  info.coding_independent_code_points = true
}

///|
fn StreamingDecoder::parse_mdcv(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()

  // The spec requires that the mDCV chunk MUST come before the PLTE and IDAT chunks.
  if info.mastering_display_color_volume {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_MDCV)} must appear at most once.",
    )
  } else if info.palette is Some(_) {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_MDCV)} is invalid after PLTE chunk.",
    )
  } else if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_MDCV)} is invalid after IDAT chunk.",
    )
  }
  // Eight `u16`s and two `u32`s (the chunk has 24 bytes).
  let _ = self.read_be_u32(20)
  if self.raw_bytes.length() != 24 {
    raise IoError(InvalidData)
  }
  info.mastering_display_color_volume = true
}

///|
fn StreamingDecoder::parse_clli(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if info.content_light_level {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_CLLI)} must appear at most once.",
    )
  }
  // Two `u32`s (the chunk has 8 bytes).
  let _ = self.read_be_u32(4)
  if self.raw_bytes.length() != 8 {
    raise IoError(InvalidData)
  }
  info.content_light_level = true
}

///|
fn StreamingDecoder::parse_exif(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if info.exif_metadata {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_EXIF)} must appear at most once.",
    )
  }
  info.exif_metadata = true
}

///|
fn StreamingDecoder::parse_iccp(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_ICCP)} is invalid after IDAT chunk.",
    )
  } else if self.have_iccp {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_ICCP)} must appear at most once.",
    )
  } else {
    self.have_iccp = true
    // `let _ = self.parse_iccp_raw();`
    self.parse_iccp_raw() catch {
      _ => ()
    }
  }
}

///|
/// The largest size of an allocation here; upstream's is `isize::MAX`. The
/// length of an array is an `Int`, and offsets into a buffer are added to
/// (by the length of a back-reference, by the growth of a buffer, by a
/// pixel) before they are compared with its length: 64 KiB below `Int`'s
/// largest value, no such sum overflows.
const PNG_MAX_ALLOCATION : UInt64 = 0x7FFF0000

///|
fn StreamingDecoder::parse_iccp_raw(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  let buf = self.raw_bytes
  let mut pos = 0

  // read profile name
  for len in 0..<=80 {
    let raw = self.read_be_u8(pos)
    pos += 1
    if (raw == 0 && len == 0) || (raw != 0 && len == 80) {
      // `TextDecodingError::InvalidKeywordSize`
      raise Format("Keyword empty or longer than 79 bytes.")
    }
    if raw == 0 {
      break
    }
  }
  // compression method
  let n = self.read_be_u8(pos)
  pos += 1
  if n != 0 {
    raise Format("Unknown compression method \{n}.")
  }
  // A profile of more bytes than an array holds is not kept here (upstream
  // keeps one of any size that it can allocate); like every error in this
  // function, that leaves the image without a profile.
  let maxlen = @cmp.minimum(self.limits.bytes, PNG_MAX_ALLOCATION).to_int()
  let profile = decompress_to_vec_bounded(buf[pos:], maxlen) catch {
    Invalid(err) => raise corrupt_flate_stream(err)
    OutputTooLarge => raise LimitsExceeded
  }
  self.limits.reserve_bytes(profile.length().to_uint64())
  info.icc_profile = Some(profile)
}

///|
fn StreamingDecoder::parse_ihdr(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  if self.info is Some(_) {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_IHDR)} must appear at most once.",
    )
  }
  let width = self.read_be_u32(0)
  let height = self.read_be_u32(4)
  if width == 0 || height == 0 {
    raise Format("Invalid image dimensions")
  }
  let bit_depth = self.read_be_u8(8)
  if !(bit_depth is (1 | 2 | 4 | 8 | 16)) {
    raise Format("Invalid bit depth \{bit_depth}.")
  }
  let color_type = self.read_be_u8(9)
  let color_type = match PngColorType::from_code(color_type) {
    Some(color_type) =>
      // `ColorType::is_combination_invalid`:
      // Section 11.2.2 of the PNG standard disallows several combinations
      // of bit depth and color type
      if (
          bit_depth is (1 | 2 | 4) &&
          color_type is (Rgb | GrayscaleAlpha | Rgba)
        ) ||
        (bit_depth == 16 && color_type is Indexed) {
        raise Format(
          "Invalid color/depth combination in header: \{png_color_type_debug(color_type)}/\{png_bit_depth_debug(bit_depth)}",
        )
      } else {
        color_type
      }
    None => raise Format("Invalid color type \{color_type}.")
  }
  // compression method
  match self.read_be_u8(10) {
    0 => ()
    n => raise Format("Unknown compression method \{n}.")
  }
  // filter method
  match self.read_be_u8(11) {
    0 => ()
    n => raise Format("Unknown filter method \{n}.")
  }
  let interlaced = match self.read_be_u8(12) {
    0 => false
    1 => true
    n => raise Format("Unknown interlace method \{n}.")
  }
  self.info = Some({
    width,
    height,
    bit_depth,
    color_type,
    interlaced,
    sbit: false,
    trns: None,
    pixel_dims: None,
    palette: None,
    gama_chunk: false,
    chrm_chunk: false,
    bkgd: false,
    frame_control: None,
    animation_control: None,
    srgb: false,
    icc_profile: None,
    coding_independent_code_points: false,
    mastering_display_color_volume: false,
    content_light_level: false,
    exif_metadata: false,
  })
}

///|
/// Upstream `parse_text`, `parse_ztxt` and `parse_itxt`: the bytes of a text
/// chunk count against the limit; an error in its contents makes the chunk
/// ignored (`BadTextEncoding`, a `FormatError` of an ancillary chunk), and
/// nothing reads the text of a valid one.
fn StreamingDecoder::parse_text(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  self.limits.reserve_bytes(self.raw_bytes.length().to_uint64())
}

///|
fn StreamingDecoder::parse_bkgd(
  self : StreamingDecoder,
) -> Unit raise DecodingError {
  let info = self.info_mut()
  if info.bkgd {
    // Only one bKGD chunk is allowed
    raise Format(
      "Chunk \{chunk_type_debug(PNG_BKGD)} must appear at most once.",
    )
  } else if self.have_idat {
    raise Format(
      "Chunk \{chunk_type_debug(PNG_BKGD)} is invalid after IDAT chunk.",
    )
  }
  let expected = match info.color_type {
    Indexed => {
      if info.palette is None {
        raise IoError(InvalidData)
      }
      1
    }
    Grayscale | GrayscaleAlpha => 2
    Rgb | Rgba => 6
  }
  if self.raw_bytes.length() != expected {
    raise Format("Chunk length wrong: \{chunk_type_debug(PNG_BKGD)}")
  }
  info.bkgd = true
}
