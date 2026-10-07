// Port of the `png` crate (v0.18.1) `src/decoder/zlib.rs`,
// `src/decoder/unfiltering_buffer.rs`, `src/decoder/read_decoder.rs`,
// `src/decoder/interlace_info.rs`, `src/adam7.rs` (the iterator and
// `expand_pass`) and `src/decoder/mod.rs` (`Decoder`, `Reader`): image data
// is decompressed into a buffer of rows, a row is unfiltered once the
// decompressor does not need it any more, and the rows of a frame are read
// one by one. Like in `png_stream.mbt` the order of these steps is
// upstream's, since it decides which error a damaged file gives.
//
// What differs: the frame is written into a buffer that grows with the rows
// that are written (`FrameBuffer`), where upstream's callers allocate the
// whole frame first (`vec![0; total_bytes]`), and the scratch row of an
// interlaced image has the size of the row that is read, not of the widest
// one. So memory follows the data that a file has, not the dimensions that
// it claims, and nothing is allocated for a header alone. `usize` is 64
// bits like on upstream's reference platforms; a buffer that would be
// larger than an array can be (`PNG_MAX_ALLOCATION`) is `LimitsExceeded`
// when it is needed.

///|
/// [PNG spec](https://www.w3.org/TR/2003/REC-PNG-20031110/#10Compression) says that
/// "deflate/inflate compression with a sliding window (which is an upper bound on the
/// distances appearing in the deflate stream) of at most 32768 bytes".
///
/// `fdeflate` requires that we keep this many most recently decompressed bytes in the
/// `out_buffer` - this allows referring back to them when handling "length and distance
/// codes" in the deflate stream).
const LOOKBACK_SIZE : Int = 32768

///|
/// Upstream `UnfilteringBuffer::GROWTH_BYTES`.
const GROWTH_BYTES : Int = 8 * 1024

///|
/// Ergonomics wrapper around `miniz_oxide::inflate::stream` for zlib compressed data.
priv struct ZlibStream {
  /// Current decoding state.
  mut state : Decompressor
  /// If there has been a call to decompress already.
  mut started : Bool
  // `ignore_adler32` is upstream's default, `true`: the decoder does not
  // calculate the Adler-32 checksum.
}

///|
fn ZlibStream::new() -> ZlibStream {
  { state: Decompressor::new(), started: false, }
}

///|
fn ZlibStream::reset(self : ZlibStream) -> Unit {
  self.started = false
  self.state = Decompressor::new()
}

///|
/// Fill the decoded buffer as far as possible from `data`.
/// On success returns the number of consumed input bytes.
fn ZlibStream::decompress(
  self : ZlibStream,
  data : BytesView,
  image_data : UnfilteringBuffer,
) -> Int raise DecodingError {
  // There may be more data past the adler32 checksum at the end of the deflate stream. We
  // match libpng's default behavior and ignore any trailing data. In the future we may want
  // to add a flag to control this behavior.
  if self.state.is_done() {
    return data.length()
  }
  if !self.started {
    self.state.ignore_adler32 = true
  }

  // `UnfilterBuf::decompress`
  let output_limit = if image_data.data_len - image_data.filled < GROWTH_BYTES {
    image_data.data_len
  } else {
    image_data.filled + GROWTH_BYTES
  }
  let out_consumed = self.state.read(
    data,
    image_data.data_stream,
    image_data.available,
    output_limit,
    image_data.filled - image_data.available,
    false,
  ) catch {
    err => raise corrupt_flate_stream(err)
  }
  image_data.filled += out_consumed
  if self.state.is_done() {
    image_data.available = image_data.filled
  } else if image_data.filled >= LOOKBACK_SIZE {
    let new_available = image_data.filled - LOOKBACK_SIZE
    // The decompressed data may have started in the middle of the buffer,
    // so ensure that `self.available` never goes backward.  This is needed
    // to avoid miscommunicating the size of the "look-back" window when calling
    // `fdeflate::Decompressor::read` a bit earlier and passing
    // `&mut self.buffer[*self.available..output_limit]`.
    if new_available > image_data.available {
      image_data.available = new_available
    }
  }
  self.started = true
  self.state.in_consumed
}

///|
/// Output any remaining buffered data within the decompressor.
///
/// Returns `true` if all data has been decompressed and there is no
/// more data that will be produced, or `false` if there's potentially
/// more output.
///
/// Raises if the zlib stream is corrupt or truncated too early.
fn ZlibStream::finish(
  self : ZlibStream,
  image_data : UnfilteringBuffer,
) -> Bool raise DecodingError {
  if !self.started || self.state.is_done() {
    return true
  }

  // If the zlib stream isn't done but we've already output all the pixel
  // data needed, then either there's too much compressed data or the
  // checksum is missing. Those aren't allowed by the spec, but libpng
  // generally doesn't treat them as fatal.
  if image_data.filled == image_data.data_len {
    return true
  }
  let out_consumed = self.state.read(
    b""[:],
    image_data.data_stream,
    image_data.available,
    image_data.data_len,
    image_data.filled - image_data.available,
    false,
  ) catch {
    err => raise corrupt_flate_stream(err)
  }
  image_data.filled += out_consumed
  if self.state.is_done() {
    image_data.available = image_data.filled
    return true
  }

  // More output is only possible if zlib stream hasn't finished and the
  // output buffer *is* full. (Empty space in the output buffer tells us
  // there wasn't more data to write into it.)
  if image_data.filled == image_data.data_len {
    image_data.available = @cmp.maximum(
      image_data.available,
      @cmp.maximum(image_data.filled - LOOKBACK_SIZE, 0),
    )
    return false
  }

  // The zlib stream was truncated before the end of the pixel data. This
  // would ordinarily be caught within fdeflate if we'd passed
  // end_of_input=true. But we intentionally don't pass that flag so that
  // we're able to drain all available pixel data first.
  raise corrupt_flate_stream(InsufficientInput)
}

///|
/// An already `unfilter`-ed, previous row (upstream `PrevRow`).
///
/// The data excludes the `RowFilter` byte - it only includes the actual pixel data.
priv enum PrevRowKind {
  /// No unfiltered row.
  ///
  /// `None` is the value of `UnfilteringBuffer::prev_row` before any row has
  /// been unfiltered (or at the start of a new interlace pass).
  NoRow
  /// The unfiltered row starts at `UnfilteringBuffer::prev_start` of
  /// `UnfilteringBuffer::data_stream`.
  ///
  /// It is used by `unfilter_curr_row_in_place`
  /// when setting `UnfilteringBuffer::prev_row`.
  InPlace
  /// Separate scratch buffer containing the unfiltered row data
  /// (`UnfilteringBuffer::prev_scratch`).
  ///
  /// It is used by
  /// `unfilter_curr_row_using_scratch_buffer`
  /// when setting `UnfilteringBuffer::prev_row`.
  Scratch
}

///|
/// Buffer for temporarily holding decompressed, not-yet-`unfilter`-ed rows.
///
/// (Upstream's `UnfilterBuf`, the view of this buffer that the decompressor
/// writes through, is the buffer itself here: `data_stream`, `available`,
/// `filled`.)
priv struct UnfilteringBuffer {
  /// Vec containing the uncompressed image data currently being processed
  /// (its capacity; the length of the `Vec` is `data_len`).
  mut data_stream : FixedArray[Byte]
  mut data_len : Int
  mut prev_row : PrevRowKind
  mut prev_start : Int
  mut prev_scratch : FixedArray[Byte]
  /// Index in `data_stream` where the current row starts.
  /// This points at the filter type byte of the current row (i.e. the actual pixel data starts at `current_start + 1`)
  /// The pixel data is not-yet-`unfilter`-ed.
  ///
  /// `current_start` can wrap around the length.
  mut current_start : Int
  /// Logical length of data that must be preserved.
  mut filled : Int
  /// Length of data that can be modified.
  mut available : Int
  /// The number of bytes before we shift the buffer back.
  shift_back_limit : Int64
  /// How many bytes are left to decompress into this buffer for the current frame.
  mut remaining_bytes : UInt64
}

///|
/// Upstream `checked_next_multiple_of` (of values that do not overflow).
fn next_multiple_of(val : Int64, factor : Int64) -> Int64 {
  let remainder = val % factor
  if remainder > 0L {
    val + (factor - remainder)
  } else {
    val
  }
}

///|
/// Create a buffer tuned for filtering rows of the image type.
fn UnfilteringBuffer::new(info : StreamInfo) -> UnfilteringBuffer {
  // (Upstream also derives the initial capacity of `data_stream` from the
  // size of the image, at most 128 KiB.)
  let shift_back_limit = {
    // Prefer shifting by powers of two and only after having done some number of
    // lines that then become free at the end of the buffer.
    // Ensure some number of rows are actually present before shifting back, i.e. next
    // time around we want to be able to decode them without reallocating the buffer.
    let rowlen_pot = next_multiple_of(
      info.raw_row_length_from_width(info.width) * 4L,
      // And also, we should be able to use aligned memcopy on the whole thing. Well at
      // least that is the idea but the parameter is just benchmarking. Higher numbers
      // did not result in performance gains but lowers also, so this is fickle. Maybe
      // our shift back behavior can not be tuned very well.
      64,
    )
    // But never shift back before we have a number of pages freed.
    @cmp.maximum(rowlen_pot, 128L * 1024L)
  }
  {
    data_stream: [],
    data_len: 0,
    prev_row: NoRow,
    prev_start: 0,
    prev_scratch: [],
    current_start: 0,
    filled: 0,
    available: 0,
    shift_back_limit,
    remaining_bytes: 0xFFFFFFFFFFFFFFFFUL,
  }
}

///|
/// Called to indicate that there is no previous row (e.g. when the current
/// row is the first scanline of a given Adam7 pass).
fn UnfilteringBuffer::reset_prev_row(self : UnfilteringBuffer) -> Unit {
  self.prev_row = NoRow
}

///|
fn UnfilteringBuffer::start_frame(
  self : UnfilteringBuffer,
  frame_bytes : UInt64,
) -> Unit {
  self.data_len = 0
  self.prev_row = NoRow
  self.current_start = 0
  self.filled = 0
  self.available = 0
  self.remaining_bytes = frame_bytes
}

///|
/// Returns how many bytes of the current row are present in the mutable
/// part of the buffer (32kB most recently decompressed bytes are read-only
/// to retain the "lookback" window as needed for inflate algorithm).  If a
/// full row is mutable, then it may be unfiltered using
/// `unfilter_curr_row_in_place`.
///
/// See also `readable_len_of_curr_row`.
fn UnfilteringBuffer::mutable_len_of_curr_row(self : UnfilteringBuffer) -> Int {
  @cmp.maximum(self.available - self.current_start, 0)
}

///|
/// Returns how many bytes of the current row have been already
/// decompressed.  If a full row is available, then it may be unfiltered
/// using `unfilter_curr_row_using_scratch_buffer`.
///
/// See also `mutable_len_of_curr_row`.
fn UnfilteringBuffer::readable_len_of_curr_row(self : UnfilteringBuffer) -> Int {
  self.filled - self.current_start
}

///|
/// `self.data_stream.resize(len, 0)`. The bytes past `filled` are never
/// read (the decompressor writes them first), so they are not zeroed when
/// the `Vec` grows again after it shrank.
fn UnfilteringBuffer::resize(
  self : UnfilteringBuffer,
  len : Int64,
) -> Unit raise DecodingError {
  if len > PNG_MAX_ALLOCATION.reinterpret_as_int64() {
    raise LimitsExceeded
  }
  let len = len.to_int()
  if len > self.data_stream.length() {
    let capacity = if self.data_stream.length() >
      PNG_MAX_ALLOCATION.to_int() / 2 {
      PNG_MAX_ALLOCATION.to_int()
    } else {
      @cmp.maximum(len, 2 * self.data_stream.length())
    }
    let grown = FixedArray::make(capacity, b'\x00')
    self.data_stream.blit_to(grown, len=self.filled)
    self.data_stream = grown
  }
  self.data_len = len
}

///|
/// Prepares the underlying buffer for the decompressor (the part of
/// upstream's `with_unfilled_buffer` before it runs its argument).
///
/// Invariants of `self` depend on the assumption that the caller will only
/// append new bytes to the buffer (which is indeed the behavior of
/// `ReadDecoder` and `StreamingDecoder`).
fn UnfilteringBuffer::unfilled_buffer(
  self : UnfilteringBuffer,
) -> Unit raise DecodingError {
  // Potentially shift the buffer left to avoid unbounded growth.
  let discard_size = @cmp.minimum(
    self.available,
    match self.prev_row {
      NoRow | Scratch => self.current_start
      InPlace => self.prev_start
    },
  )
  if discard_size.to_int64() >= self.shift_back_limit &&
    // Avoid the shift back if the buffer is still very empty. Consider how we got here: a
    // previous decompression filled the buffer, then we unfiltered, we're now refilling
    // the buffer again. The condition implies, the previous decompression filled at most
    // half the buffer. Likely the same will happen again so the following decompression
    // attempt will not yet be limited by the buffer length.
    self.filled >= self.data_len / 2 {
    self.shift_buffer_left(discard_size)
  }
  if self.filled.to_int64() + GROWTH_BYTES.to_int64() > self.data_len.to_int64() {
    self.resize(self.filled.to_int64() + GROWTH_BYTES.to_int64())
  }
  // `remaining_bytes < usize::MAX && filled.saturating_add(remaining_bytes)
  // < data_stream.len()`
  if self.remaining_bytes < (self.data_len - self.filled).to_uint64() {
    self.resize(
      self.filled.to_int64() + self.remaining_bytes.reinterpret_as_int64(),
    )
  }
}

///|
/// The part of upstream's `with_unfilled_buffer` after it ran its argument;
/// `old_filled` is `filled` before.
fn UnfilteringBuffer::filled_buffer(
  self : UnfilteringBuffer,
  old_filled : Int,
) -> Unit {
  guard! self.filled >= old_filled
  self.remaining_bytes -= (self.filled - old_filled).to_uint64()
  if self.remaining_bytes == 0 {
    self.available = self.filled
  }
}

///|
/// Shifts the contents of `self.data_stream` left,
/// discarding the first `discard_size` bytes.
fn UnfilteringBuffer::shift_buffer_left(
  self : UnfilteringBuffer,
  discard_size : Int,
) -> Unit {
  // Violating this assertion will clobber the immutable "lookback"
  // window that needs to be maintained for decompressor.
  guard! discard_size <= self.available

  // We have to relocate the data to the start of the buffer. (Upstream
  // moves the bytes past `filled` too if there are fewer than 16.)
  self.data_stream.unsafe_blit(
    0,
    self.data_stream,
    discard_size,
    self.filled - discard_size,
  )

  // The data kept its relative position to `filled` which now lands exactly at
  // the distance between prev_start and filled.
  self.current_start -= discard_size
  self.available -= discard_size
  self.filled -= discard_size
  if self.prev_row is InPlace {
    self.prev_start -= discard_size
  }
}

///|
/// The filter of the current row (upstream `curr_row_filter`, whose result
/// is a `RowFilter`).
fn UnfilteringBuffer::curr_row_filter(
  self : UnfilteringBuffer,
) -> Int raise DecodingError {
  let filter = self.data_stream[self.current_start].to_int()
  if filter > 4 {
    raise Format("Unknown filter method \{filter}.")
  }
  filter
}

///|
/// Runs `unfilter` on the current row, and then shifts rows so that the
/// current row becomes the previous row.
///
/// `unfilter` will mutate the current row in-place, and therefore the
/// caller should first consult `mutable_len_of_curr_row` to check if all
/// bytes of the current row are indeed mutable.
fn UnfilteringBuffer::unfilter_curr_row_in_place(
  self : UnfilteringBuffer,
  rowlen : Int,
  bpp : Int,
) -> Unit raise DecodingError {
  let filter = self.curr_row_filter()
  // Skip the `RowFilter` byte.
  match self.prev_row {
    NoRow =>
      png_unfilter(
        filter,
        bpp,
        self.data_stream,
        0,
        false,
        self.data_stream,
        self.current_start + 1,
        rowlen - 1,
      )
    InPlace =>
      png_unfilter(
        filter,
        bpp,
        self.data_stream,
        self.prev_start,
        true,
        self.data_stream,
        self.current_start + 1,
        rowlen - 1,
      )
    Scratch =>
      png_unfilter(
        filter,
        bpp,
        self.prev_scratch,
        0,
        true,
        self.data_stream,
        self.current_start + 1,
        rowlen - 1,
      )
  }
  self.prev_row = InPlace
  self.prev_start = self.current_start + 1
  self.current_start += rowlen
}

///|
/// Runs `unfilter` on the current row, and then shifts rows so that the
/// current row becomes the previous row.
///
/// Before running `unfilter`, the contents of the current row will be
/// copied into a scratch buffer.  This allows unfiltering to happen even
/// if `mutable_len_of_curr_row < rowlen` (e.g. when handling partial
/// or not-yet-complete input streams).
fn UnfilteringBuffer::unfilter_curr_row_using_scratch_buffer(
  self : UnfilteringBuffer,
  rowlen : Int,
  bpp : Int,
) -> Unit raise DecodingError {
  let filter = self.curr_row_filter()
  let row = FixedArray::make(rowlen - 1, b'\x00')
  self.data_stream.blit_to(
    row,
    len=rowlen - 1,
    src_offset=self.current_start + 1,
  )
  match self.prev_row {
    NoRow => png_unfilter(filter, bpp, row, 0, false, row, 0, rowlen - 1)
    InPlace =>
      png_unfilter(
        filter,
        bpp,
        self.data_stream,
        self.prev_start,
        true,
        row,
        0,
        rowlen - 1,
      )
    Scratch =>
      png_unfilter(filter, bpp, self.prev_scratch, 0, true, row, 0, rowlen - 1)
  }
  self.prev_row = Scratch
  self.prev_scratch = row
  self.current_start += rowlen
}

///|
/// Upstream `filter::paeth::filter_paeth` (the predictor of the decoder).
fn png_paeth(a : Int, b : Int, c : Int) -> Int {
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

///|
/// Reverses the filter of a row in place (upstream `filter::unfilter`):
/// `current[cur..cur + len]` with the previous row `previous[prev..prev +
/// len]`, or without one if `!has_previous` (then it is treated as if it
/// were filled with zeros). `filter` is 0 to 4.
fn png_unfilter(
  filter : Int,
  bpp : Int,
  previous : FixedArray[Byte],
  prev : Int,
  has_previous : Bool,
  current : FixedArray[Byte],
  cur : Int,
  len : Int,
) -> Unit {
  // The accesses below are in bounds: `cur + len <= current.length()` and,
  // with a previous row, `prev + len <= previous.length()`.
  guard! cur >= 0 &&
    len >= 0 &&
    cur <= current.length() - len &&
    (!has_previous || (prev >= 0 && prev <= previous.length() - len))
  // `Sub` works on whole pixels (`chunks_exact_mut`); the other filters on
  // the row of bytes. A row is a whole number of pixels.
  match filter {
    // NoFilter
    0 => ()
    // Sub (and `Paeth` without a previous row)
    1 =>
      for i in bpp..<len {
        current.unsafe_set(
          cur + i,
          (current.unsafe_get(cur + i).to_int() +
          current.unsafe_get(cur + i - bpp).to_int()).to_byte(),
        )
      }
    // Up (`NoFilter` without a previous row)
    2 =>
      if has_previous {
        for i in 0..<len {
          current.unsafe_set(
            cur + i,
            (current.unsafe_get(cur + i).to_int() +
            previous.unsafe_get(prev + i).to_int()).to_byte(),
          )
        }
      }
    // Avg
    3 =>
      if has_previous {
        for i in 0..<@cmp.minimum(bpp, len) {
          current.unsafe_set(
            cur + i,
            (current.unsafe_get(cur + i).to_int() +
            previous.unsafe_get(prev + i).to_int() / 2).to_byte(),
          )
        }
        for i in bpp..<len {
          current.unsafe_set(
            cur + i,
            (current.unsafe_get(cur + i).to_int() +
            (
              current.unsafe_get(cur + i - bpp).to_int() +
              previous.unsafe_get(prev + i).to_int()
            ) /
            2).to_byte(),
          )
        }
      } else {
        for i in bpp..<len {
          current.unsafe_set(
            cur + i,
            (current.unsafe_get(cur + i).to_int() +
            current.unsafe_get(cur + i - bpp).to_int() / 2).to_byte(),
          )
        }
      }
    // Paeth
    _ =>
      if has_previous {
        for i in 0..<@cmp.minimum(bpp, len) {
          // `filter_paeth(0, b, 0)` is `b`.
          current.unsafe_set(
            cur + i,
            (current.unsafe_get(cur + i).to_int() +
            previous.unsafe_get(prev + i).to_int()).to_byte(),
          )
        }
        for i in bpp..<len {
          current.unsafe_set(
            cur + i,
            (current.unsafe_get(cur + i).to_int() +
            png_paeth(
              current.unsafe_get(cur + i - bpp).to_int(),
              previous.unsafe_get(prev + i).to_int(),
              previous.unsafe_get(prev + i - bpp).to_int(),
            )).to_byte(),
          )
        }
      } else {
        for i in bpp..<len {
          current.unsafe_set(
            cur + i,
            (current.unsafe_get(cur + i).to_int() +
            current.unsafe_get(cur + i - bpp).to_int()).to_byte(),
          )
        }
      }
  }
}

///|
/// Whether there may be additional data afterwards (upstream
/// `ImageDataCompletionStatus`).
priv enum ImageDataCompletionStatus {
  ExpectingMoreData
  Done
}

///|
/// Helper for encapsulating reading input from `Read` and feeding it into a `StreamingDecoder`
/// while hiding low-level `Decoded` events and only exposing a few high-level reading operations
/// like:
///
/// * `read_header_info` - reading until `IHDR` chunk
/// * `read_until_image_data` - reading until `IDAT` / `fdAT` sequence
/// * `decode_image_data` - reading from `IDAT` / `fdAT` sequence into `Vec<u8>`
/// * `finish_decoding_image_data()` - discarding remaining data from `IDAT` / `fdAT` sequence
priv struct ReadDecoder {
  /// The input that has not been read yet.
  mut reader : BytesView
  decoder : StreamingDecoder
}

///|
/// Returns the next decoded chunk. If the chunk is an ImageData chunk, its contents are written
/// into image_data.
fn ReadDecoder::decode_next(
  self : ReadDecoder,
  image_data : UnfilteringBuffer?,
) -> Decoded raise DecodingError {
  let buf = self.reader
  if buf.length() == 0 {
    raise IoError(UnexpectedEof)
  }
  let result = self.decoder.update(buf, image_data)
  self.reader = buf[self.decoder.consumed:]
  result
}

///|
/// Reads until the end of `IHDR` chunk.
///
/// Prerequisite: None (idempotent).
fn ReadDecoder::read_header_info(
  self : ReadDecoder,
) -> StreamInfo raise DecodingError {
  while true {
    if self.decoder.info is Some(info) {
      return info
    }
    let _ = self.decode_next(None)
  }
  abort("unreachable")
}

///|
/// Reads until the start of the next `IDAT` or `fdAT` chunk.
///
/// Prerequisite: **Not** within `IDAT` / `fdAT` chunk sequence.
fn ReadDecoder::read_until_image_data(
  self : ReadDecoder,
) -> Unit raise DecodingError {
  while true {
    match self.decode_next(None) {
      ChunkBegin(_, PNG_IDAT) | ChunkBegin(_, PNG_FDAT) => break
      ChunkComplete(PNG_IEND) => raise Format("IDAT or fdAT chunk is missing.")
      // Ignore all other chunk events. Any other chunk may be between IDAT chunks, fdAT
      // chunks and their control chunks.
      _ => ()
    }
  }
}

///|
/// Reads `image_data` and reports whether there may be additional data afterwards (i.e. if it
/// is okay to call `decode_image_data` and/or `finish_decoding_image_data` again)..
///
/// Prerequisite: Input is currently positioned within `IDAT` / `fdAT` chunk sequence.
fn ReadDecoder::decode_image_data(
  self : ReadDecoder,
  image_data : UnfilteringBuffer?,
) -> ImageDataCompletionStatus raise DecodingError {
  match self.decode_next(image_data) {
    ImageData => ExpectingMoreData
    ImageDataFlushed => Done
    // Ignore other events that may happen within an `IDAT` / `fdAT` chunks sequence.
    _ => ExpectingMoreData
  }
}

///|
/// Consumes and discards the rest of an `IDAT` / `fdAT` chunk sequence.
///
/// Prerequisite: Input is currently positioned within `IDAT` / `fdAT` chunk sequence.
fn ReadDecoder::finish_decoding_image_data(
  self : ReadDecoder,
) -> Unit raise DecodingError {
  while true {
    if self.decode_image_data(None) is Done {
      return
    }
  }
}

///|
/// The Adam7 passes (upstream `PassConstants::PASSES`): `x_sampling`,
/// `x_offset`, `y_sampling`, `y_offset`.
let adam7_passes : ReadOnlyArray[(Int, Int, Int, Int)] = [
  (8, 0, 8, 0),
  (8, 4, 8, 0),
  (4, 0, 8, 4),
  (4, 2, 4, 0),
  (2, 0, 4, 2),
  (2, 1, 2, 0),
  (1, 0, 2, 1),
]

///|
/// Upstream `PassConstants::count_samples` and `count_lines`:
/// `size.saturating_sub(offset).div_ceil(sampling)`.
fn adam7_count(size : UInt, sampling : Int, offset : Int) -> UInt {
  let offset = offset.reinterpret_as_uint()
  let sampling = sampling.reinterpret_as_uint()
  if size <= offset {
    0
  } else {
    let rest = size - offset
    rest / sampling + (if rest % sampling != 0 { 1 } else { 0 })
  }
}

///|
/// The rows of a frame in the order of the image data, with the row that is
/// read next (upstream `InterlaceInfoIter` over `InterlaceInfo`s, and
/// `SubframeInfo::current_interlace_info`).
priv struct InterlaceInfoIter {
  interlaced : Bool
  width : UInt
  height : UInt
  /// Whether there is a current row (`current_interlace_info.is_some()`).
  mut has_current : Bool
  /// The pass of the current row, 1 to 7 (`Adam7Info::pass`); 0 without
  /// interlacing (`InterlaceInfo::Null`).
  mut pass : Int
  /// The line of the current row in its pass (`line_number()`).
  mut line : UInt
  /// How many pixels the current row has (`Adam7Info::samples`; the width
  /// without interlacing).
  mut samples : UInt
  // `Adam7Iterator`
  mut next_line : UInt
  mut lines : UInt
  mut line_width : UInt
  mut current_pass : Int
}

///|
/// Upstream `InterlaceInfoIter::empty()` with no current row.
fn InterlaceInfoIter::empty() -> InterlaceInfoIter {
  {
    interlaced: false,
    width: 0,
    height: 0,
    has_current: false,
    pass: 0,
    line: 0,
    samples: 0,
    next_line: 0,
    lines: 0,
    line_width: 0,
    current_pass: 1,
  }
}

///|
/// Upstream `InterlaceInfoIter::new` followed by `next()`, which gives the
/// first row.
fn InterlaceInfoIter::new(
  width : UInt,
  height : UInt,
  interlaced : Bool,
) -> InterlaceInfoIter {
  let iter = {
    interlaced,
    width,
    height,
    has_current: false,
    pass: 0,
    line: 0,
    samples: width,
    next_line: 0,
    // `0..height`
    lines: height,
    line_width: 0,
    current_pass: 1,
  }
  if interlaced {
    iter.init_pass()
  }
  iter.next()
  iter
}

///|
fn InterlaceInfoIter::init_pass(self : InterlaceInfoIter) -> Unit {
  let (x_sampling, x_offset, y_sampling, y_offset) = adam7_passes[self.current_pass -
    1]
  self.line_width = adam7_count(self.width, x_sampling, x_offset)
  self.lines = adam7_count(self.height, y_sampling, y_offset)
  self.next_line = 0
}

///|
/// Moves to the next row (upstream `Iterator::next`).
fn InterlaceInfoIter::next(self : InterlaceInfoIter) -> Unit {
  if !self.interlaced {
    if self.next_line < self.lines {
      self.has_current = true
      self.line = self.next_line
      self.next_line += 1
    } else {
      self.has_current = false
    }
    return
  }
  while true {
    if self.next_line < self.lines && self.line_width > 0 {
      self.has_current = true
      self.pass = self.current_pass
      self.line = self.next_line
      self.samples = self.line_width
      self.next_line += 1
      return
    } else if self.current_pass < 7 {
      self.current_pass += 1
      self.init_pass()
    } else {
      self.has_current = false
      return
    }
  }
}

///|
/// The frame that is decoded: a buffer that grows with the rows written to
/// it. Upstream's callers pass `next_frame` a buffer of the whole frame
/// (`vec![0; total_bytes]`, zeroed pages that the system provides when they
/// are written); here the buffer is as long as its last written row
/// requires, and the whole frame only once its last row is written.
priv struct FrameBuffer {
  mut data : FixedArray[Byte]
  /// The length of the frame.
  total : Int64
}

///|
/// The largest frame that is allocated before its rows are read.
const FRAME_PREALLOCATION_LIMIT : Int64 = 256L * 1024L * 1024L

///|
/// `preallocate`: allocate the whole frame at once (the caller has checked
/// that this is a size that the input can fill).
fn FrameBuffer::new(total : Int64, preallocate : Bool) -> FrameBuffer {
  let data : FixedArray[Byte] = if preallocate {
    FixedArray::make(total.to_int(), b'\x00')
  } else {
    []
  }
  { data, total, }
}

///|
/// Makes `data[..end]` exist (`end <= total`).
fn FrameBuffer::reserve(
  self : FrameBuffer,
  end : Int64,
) -> Unit raise DecodingError {
  if end <= self.data.length().to_int64() {
    return
  }
  if end > PNG_MAX_ALLOCATION.reinterpret_as_int64() {
    raise LimitsExceeded
  }
  let limit = @cmp.minimum(
    self.total,
    PNG_MAX_ALLOCATION.reinterpret_as_int64(),
  )
  let capacity = @cmp.minimum(
    limit,
    @cmp.maximum(end, @cmp.maximum(2L * self.data.length().to_int64(), 4096L)),
  ).to_int()
  let grown = FixedArray::make(capacity, b'\x00')
  self.data.blit_to(grown, len=self.data.length())
  self.data = grown
}

///|
/// The subframe specific information.
///
/// In APNG the frames are constructed by combining previous frame and a new subframe (through a
/// combination of `dispose_op` and `overlay_op`). These sub frames specify individual dimension
/// information and reuse the global interlace options. This struct encapsulates the state of where
/// in a particular IDAT-frame or subframe we are.
priv struct SubframeInfo {
  width : UInt
  height : UInt
  rowlen : Int64
  /// `current_interlace_info` and `interlace_info_iter`
  interlace : InterlaceInfoIter
  mut consumed_and_flushed : Bool
}

///|
fn SubframeInfo::not_yet_init() -> SubframeInfo {
  {
    width: 0,
    height: 0,
    rowlen: 0,
    interlace: InterlaceInfoIter::empty(),
    consumed_and_flushed: false,
  }
}

///|
fn SubframeInfo::new(info : StreamInfo) -> SubframeInfo {
  // The apng fctnl overrides width and height.
  // All other data is set by the main info struct.
  let (width, height) = match info.frame_control {
    Some(fc) => (fc.width, fc.height)
    None => (info.width, info.height)
  }
  {
    width,
    height,
    rowlen: info.raw_row_length_from_width(width),
    interlace: InterlaceInfoIter::new(width, height, info.interlaced),
    consumed_and_flushed: false,
  }
}

///|
/// PNG reader (mostly high-level interface)
///
/// Provides a high level that iterates over lines or whole images.
///
/// The output transformation is upstream's `Transformations::EXPAND`, which
/// `image` and krilla set.
priv struct PngReader {
  decoder : ReadDecoder
  mut bpp : Int
  mut subframe : SubframeInfo
  /// How many frames remain to be decoded.  Decremented after each `IDAT` or `fdAT` sequence.
  mut remaining_frames : UInt
  /// Buffer with not-yet-`unfilter`-ed image rows
  unfiltering_buffer : UnfilteringBuffer
  /// Function that can transform decompressed, unfiltered rows into final output.
  /// See the `transform.rs` module for more details.
  mut transform_fn : PngTransform?
  /// The transformed row of an interlaced image.
  mut scratch_buffer : FixedArray[Byte]
}

///|
/// Create a new decoder configuration with custom limits and read all meta
/// data until the first IDAT chunk (upstream `Decoder::new_with_limits`,
/// `set_transformations(Transformations::EXPAND)` and `read_info`).
fn PngReader::read_info(
  data : BytesView,
  limits : Limits,
) -> PngReader raise DecodingError {
  let read_decoder = { reader: data, decoder: StreamingDecoder::new(limits), }
  let info = read_decoder.read_header_info()
  let unfiltering_buffer = UnfilteringBuffer::new(info)
  let reader = {
    decoder: read_decoder,
    bpp: 1,
    subframe: SubframeInfo::not_yet_init(),
    // Temporary value - fixed below after reading `acTL` and `fcTL`.
    remaining_frames: 0,
    unfiltering_buffer,
    transform_fn: None,
    scratch_buffer: [],
  }

  // Check if the decoding buffer of a single raw line has a valid size.
  // (`checked_raw_row_length` is `None` if the length does not fit a
  // `usize`, which a row of `u32::MAX` pixels of 64 bits does.)

  // Check if the output buffer has a valid size.
  //
  // FIXME: see above and
  // <https://github.com/image-rs/image-png/pull/608#issuecomment-3003576956>
  if reader.output_buffer_size() is None {
    raise LimitsExceeded
  }
  reader.read_until_image_data()
  reader.remaining_frames = match info.animation_control {
    // No `acTL` => only expecting `IDAT` frame.
    None => 1
    Some(num_frames) =>
      // Note: limited to (2^32 - 1) frames by the APNG spec so addition does not
      // overflow on 32-bit targets nor 64-bit targets.
      if info.frame_control is None {
        // No `fcTL` before `IDAT` => `IDAT` is not part of the animation, but
        // represents an *extra*, default frame for non-APNG-aware decoders.
        num_frames + 1
      } else {
        num_frames
      }
  }
  reader
}

///|
/// Reads all meta data until the next frame data starts.
/// Requires IHDR before the IDAT and fcTL before fdAT.
fn PngReader::read_until_image_data(
  self : PngReader,
) -> Unit raise DecodingError {
  self.decoder.read_until_image_data()
  let info = self.info()
  self.subframe = SubframeInfo::new(info)
  self.bpp = info.bytes_per_pixel()
  let frame_bytes = if info.interlaced {
    let mut bytes = 0UL
    for pass in adam7_passes[:] {
      let (x_sampling, x_offset, y_sampling, y_offset) = pass
      bytes += info
        .raw_row_length_from_width(
          adam7_count(self.subframe.width, x_sampling, x_offset),
        )
        .reinterpret_as_uint64() *
        adam7_count(self.subframe.height, y_sampling, y_offset).to_uint64()
    }
    bytes
  } else {
    self.subframe.rowlen.reinterpret_as_uint64() *
    self.subframe.height.to_uint64()
  }
  self.unfiltering_buffer.start_frame(frame_bytes)

  // Allocate output buffer.
  let buflen = self.unguarded_output_line_size(self.subframe.width)
  self.decoder.decoder.limits.reserve_bytes(buflen.reinterpret_as_uint64())
}

///|
/// Get information on the image.
///
/// The structure will change as new frames of an animated image are decoded.
fn PngReader::info(self : PngReader) -> StreamInfo {
  self.decoder.decoder.info_mut()
}

///|
/// Decodes the next frame into a buffer (upstream `next_frame`, whose
/// caller provides one that holds a complete frame; see `FrameBuffer`).
/// `input_len` is the length of the file.
///
/// Output lines will be written in row-major, packed matrix with width and height of the read
/// frame (or subframe), all samples are in big endian byte order where this matters.
fn PngReader::next_frame(
  self : PngReader,
  input_len : Int,
) -> FixedArray[Byte] raise DecodingError {
  if self.remaining_frames == 0 {
    // `ParameterErrorKind::PolledAfterEndOfImage`
    raise Parameter("End of image has been reached")
  }
  // (`subframe.consumed_and_flushed` is false: this is the first frame.)

  // Note that we only check if the buffer size calculation holds in a call to decoding the
  // frame. Consequently, we can represent the `Info` and frameless decoding even when the
  // target architecture's address space is too small for a frame. However reading the actual
  guard self.output_buffer_size() is Some(required_len) else {
    raise LimitsExceeded
  }
  let info = self.info()
  let line_size = self.unguarded_output_line_size(self.subframe.width)
  // A frame of a size that the input can fill (deflate compresses a
  // thousand times at most) and that is not large is allocated at once; any
  // other one row by row, as far as there is data for it.
  let buf = FrameBuffer::new(
    required_len,
    required_len <= 65536L + 1024L * input_len.to_int64() &&
    required_len <= FRAME_PREALLOCATION_LIMIT,
  )
  if info.interlaced {
    let stride = self.unguarded_output_line_size(info.width)
    let bytes_pp = self.output_bytes_per_pixel()
    while self.next_interlaced_row() {
      // `expand_pass` for whole bytes: pixel `i` of the row is pixel
      // `i * x_sampling + x_offset` of line `line * y_sampling + y_offset`.
      let interlace = self.subframe.interlace
      let (x_sampling, x_offset, y_sampling, y_offset) = adam7_passes[interlace.pass -
        1]
      // the equivalent line number in progressive scan
      let prog_line = y_sampling.to_int64() * interlace.line.to_int64() +
        y_offset.to_int64()
      buf.reserve((prog_line + 1L) * stride)
      let byte_start = (prog_line * stride).to_int()
      let row = self.scratch_buffer
      let img = buf.data
      let samples = interlace.samples.reinterpret_as_int()
      let step = x_sampling * bytes_pp
      let mut bytepos = byte_start + x_offset * bytes_pp
      for i in 0..<samples {
        for k in 0..<bytes_pp {
          img[bytepos + k] = row[i * bytes_pp + k]
        }
        bytepos += step
      }
      interlace.next()
    }
  } else {
    // (No row has been read yet: `already_done_rows` is 0.)
    let interlace = self.subframe.interlace
    while interlace.has_current {
      // The row is transformed into the frame once it is unfiltered.
      self.next_raw_interlaced_row(self.subframe.rowlen)
      let start = interlace.line.to_int64() * line_size
      buf.reserve(start + line_size)
      self.transform_row(buf.data, start.to_int(), line_size.to_int())
      self.subframe.interlace.next()
    }
  }

  // Advance over the rest of data for this (sub-)frame.
  self.finish_decoding()
  buf.reserve(required_len)
  buf.data
}

///|
fn PngReader::mark_subframe_as_consumed_and_flushed(self : PngReader) -> Unit {
  guard! self.remaining_frames > 0
  self.remaining_frames -= 1
  self.subframe.consumed_and_flushed = true
}

///|
/// Advance over the rest of data for this (sub-)frame.
/// Called after decoding the last row of a frame.
fn PngReader::finish_decoding(self : PngReader) -> Unit raise DecodingError {
  // Double-check that all rows of this frame have been decoded (i.e. that the potential
  // `finish_decoding` call below won't be discarding any data).
  guard! !self.subframe.interlace.has_current

  // Discard the remaining data in the current sequence of `IDAT` or `fdAT` chunks.
  if !self.subframe.consumed_and_flushed {
    self.decoder.finish_decoding_image_data()
    self.mark_subframe_as_consumed_and_flushed()
  }
}

///|
/// Reads the next processed row of an interlaced image into
/// `scratch_buffer` (upstream `next_interlaced_row` and `read_row`); the
/// row is the current one of `subframe.interlace`, which the caller moves
/// on. `false` if the current image frame has no more rows.
fn PngReader::next_interlaced_row(self : PngReader) -> Bool raise DecodingError {
  // `output_line_size(self.info().width)` is `Some`: the frame has a size.
  let interlace = self.subframe.interlace
  if !interlace.has_current {
    self.finish_decoding()
    return false
  }
  if interlace.line == 0 {
    self.unfiltering_buffer.reset_prev_row()
  }
  let rowlen = self.info().raw_row_length_from_width(interlace.samples)
  let output_line_size = self.unguarded_output_line_size(interlace.samples)
  self.next_raw_interlaced_row(rowlen)
  // The row is decompressed, so its transformation is at most 32 times a
  // length that fits an array.
  if output_line_size > PNG_MAX_ALLOCATION.reinterpret_as_int64() {
    raise LimitsExceeded
  }
  let output_line_size = output_line_size.to_int()
  if self.scratch_buffer.length() < output_line_size {
    self.scratch_buffer = FixedArray::make(output_line_size, b'\x00')
  }
  self.transform_row(self.scratch_buffer, 0, output_line_size)
  true
}

///|
/// Applies the transformations to the row that was unfiltered last and
/// writes the resulting data to `output[start..start + len]` (the second
/// half of upstream's `next_interlaced_row_impl`).
fn PngReader::transform_row(
  self : PngReader,
  output : FixedArray[Byte],
  start : Int,
  len : Int,
) -> Unit raise DecodingError {
  let buffer = self.unfiltering_buffer
  // `unfiltering_buffer.prev_row()`
  let (row, row_start) = match buffer.prev_row {
    InPlace => (buffer.data_stream, buffer.prev_start)
    Scratch => (buffer.prev_scratch, 0)
    NoRow => abort("a row was unfiltered")
  }
  let row_len = match buffer.prev_row {
    InPlace => buffer.current_start - buffer.prev_start
    _ => buffer.prev_scratch.length()
  }
  let info = self.info()
  let transform_fn = match self.transform_fn {
    Some(transform_fn) => transform_fn
    None => {
      let transform_fn = PngTransform::new(info)
      self.transform_fn = Some(transform_fn)
      transform_fn
    }
  }
  transform_fn.apply(row, row_start, row_len, output, start, len, info)
}

///|
/// Returns the color type and the number of bits per sample
/// of the data returned by `next_frame`, for `Transformations::EXPAND`.
fn PngReader::output_color_type(self : PngReader) -> (PngColorType, Int) {
  let info = self.info()
  let bits = if info.bit_depth < 8 { 8 } else { info.bit_depth }
  let has_trns = info.trns is Some(_)
  let color_type = match info.color_type {
    Grayscale if has_trns => GrayscaleAlpha
    Rgb if has_trns => Rgba
    Indexed if has_trns => Rgba
    Indexed => Rgb
    ct => ct
  }
  (color_type, bits)
}

///|
/// The number of bytes of a pixel of the output.
fn PngReader::output_bytes_per_pixel(self : PngReader) -> Int {
  let (color, depth) = self.output_color_type()
  color.samples() * (depth / 8)
}

///|
/// Return the number of bytes required to hold a deinterlaced image frame that is decoded
/// using the given input transformations.
///
/// Returns `None` if the output buffer does not fit into the memory space of the machine,
/// otherwise returns the byte length in `Some`. The length is smaller than [`isize::MAX`].
fn PngReader::output_buffer_size(self : PngReader) -> Int64? {
  let info = self.info()
  let (color, depth) = self.output_color_type()
  // The subtraction should always work, but we do this for consistency. Also note that by
  // calling `checked_raw_row_length` the row buffer is guaranteed to work whereas if we
  // ran other function that didn't include the filter byte that could later fail on an image
  // that is `1xN`...
  let linelen = raw_row_length_from_width(color, depth, info.width) - 1L
  let height = info.height.to_int64()
  // `linelen.checked_mul(height)?`, and ensure that it fits into address
  // space not only `usize` to allocate (`imglen <= isize::MAX`).
  if linelen > 0x7FFFFFFFFFFFFFFFL / height {
    return None
  }
  Some(linelen * height)
}

///|
/// Returns the number of bytes required to hold a deinterlaced row.
fn PngReader::unguarded_output_line_size(
  self : PngReader,
  width : UInt,
) -> Int64 {
  let (color, depth) = self.output_color_type()
  raw_row_length_from_width(color, depth, width) - 1L
}

///|
/// Unfilter the next raw interlaced row into `self.unfiltering_buffer`.
fn PngReader::next_raw_interlaced_row(
  self : PngReader,
  rowlen : Int64,
) -> Unit raise DecodingError {
  let buffer = self.unfiltering_buffer
  // Read image data until we have at least one full row (but possibly more than one).
  while buffer.mutable_len_of_curr_row().to_int64() < rowlen {
    if self.subframe.consumed_and_flushed {
      raise Format("IDAT or fDAT chunk does not have enough data for image.")
    }
    guard! buffer.remaining_bytes > 0
    buffer.unfilled_buffer()
    let old_filled = buffer.filled
    let completion_status = self.decoder.decode_image_data(Some(buffer)) catch {
      IoError(UnexpectedEof) as e => {
        buffer.filled_buffer(old_filled)
        if buffer.readable_len_of_curr_row().to_int64() >= rowlen {
          return buffer.unfilter_curr_row_using_scratch_buffer(
            rowlen.to_int(),
            self.bpp,
          )
        }
        raise e
      }
      e => raise e
    }
    buffer.filled_buffer(old_filled)
    if completion_status is Done {
      self.mark_subframe_as_consumed_and_flushed()
    }
  }
  buffer.unfilter_curr_row_in_place(rowlen.to_int(), self.bpp)
}
