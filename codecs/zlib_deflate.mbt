// Port of zlib-rs 0.6.8 `src/deflate.rs` (the zlib-ng derived compressor),
// `src/deflate/window.rs`, `src/deflate/hash_calc.rs` and
// `src/deflate/slide_hash.rs`, restricted to what flate2's `ZlibEncoder`
// uses: zlib wrapper, window bits 15, memLevel 8, the default strategy and
// the compression levels handled by `deflate_medium` (3..=6). gzip headers,
// dictionaries, `deflateParams` and the other compression functions
// (stored/quick/fast/slow/huff/rle) are not ported.

///|
/// Number of elements in hash table.
const HASH_SIZE : Int = 65536

///|
/// The minimum match length mandated by the deflate standard.
const STD_MIN_MATCH : Int = 3

///|
/// The minimum wanted match length, affects deflate_quick, deflate_fast,
/// deflate_medium and deflate_slow.
const WANT_MIN_MATCH : Int = 4

///|
const MIN_LOOKAHEAD : Int = 262 // STD_MAX_MATCH (258) + STD_MIN_MATCH + 1

///|
const STRATEGY_DEFAULT : Int = 0

///|
const STRATEGY_FIXED : Int = 4

///|
/// Flush modes (upstream `DeflateFlush`).
const FLUSH_NO : Int = 0

///|
const FLUSH_PARTIAL : Int = 1

///|
const FLUSH_SYNC : Int = 2

///|
const FLUSH_FULL : Int = 3

///|
const FLUSH_FINISH : Int = 4

///|
const FLUSH_BLOCK : Int = 5

///|
/// Return codes (upstream `ReturnCode`).
const Z_OK : Int = 0

///|
const Z_STREAM_END : Int = 1

///|
const Z_STREAM_ERROR : Int = -2

///|
const Z_BUF_ERROR : Int = -5

///|
/// Stream status (upstream `Status`).
const STATUS_INIT : Int = 1

///|
const STATUS_BUSY : Int = 2

///|
const STATUS_FINISH : Int = 3

///|
/// Block state (upstream `BlockState`).
priv enum BlockState {
  /// block not completed, need more input or more output
  NeedMore
  /// block flush performed
  BlockDone
  /// finish started, need only more output at next deflate
  FinishStarted
  /// finish done, accept no more input or output
  FinishDone
}

///|
/// Compression parameters (upstream `algorithm::Config`).
priv struct Config {
  /// reduce lazy search above this match length
  good_length : Int
  /// do not perform lazy search above this match length
  max_lazy : Int
  /// quit search above this match length
  nice_length : Int
  max_chain : Int
}

///|
let configuration_table : ReadOnlyArray[Config] = [
  { good_length: 0, max_lazy: 0, nice_length: 0, max_chain: 0, }, // 0 store only
  { good_length: 0, max_lazy: 0, nice_length: 0, max_chain: 0, }, // 1
  { good_length: 4, max_lazy: 4, nice_length: 8, max_chain: 4, }, // 2 max speed, no lazy matches
  { good_length: 4, max_lazy: 6, nice_length: 16, max_chain: 6, }, // 3
  { good_length: 4, max_lazy: 12, nice_length: 32, max_chain: 24, }, // 4 lazy matches
  { good_length: 8, max_lazy: 16, nice_length: 32, max_chain: 32, }, // 5
  { good_length: 8, max_lazy: 16, nice_length: 128, max_chain: 128, }, // 6
  { good_length: 8, max_lazy: 32, nice_length: 128, max_chain: 256, }, // 7
  { good_length: 32, max_lazy: 128, nice_length: 258, max_chain: 1024, }, // 8
  { good_length: 32, max_lazy: 258, nice_length: 258, max_chain: 4096, }, // 9 max compression
]

///|
/// The deflate stream and its internal state (upstream `DeflateStream` and
/// `State`). Positions are `u16`s upstream (`Pos`).
priv struct DeflateStream {
  // -- stream --
  mut input : BytesView
  mut next_in : Int
  mut avail_in : Int
  mut output : Buffer
  mut avail_out : Int
  mut total_out : Int64
  mut data_type : Int
  mut adler : UInt
  // -- state --
  mut status : Int
  /// value of flush param for previous deflate call
  mut last_flush : Int
  /// bit 0 true for zlib, bit 1 true for gzip
  mut wrap : Int
  strategy : Int
  mut level : Int
  /// Use a faster search when the previous match is longer than this
  mut good_match : Int
  /// Stop searching when current match exceeds this
  mut nice_match : Int
  /// start of matching string
  mut match_start : Int
  /// start of string to insert
  mut strstart : Int
  window : FixedArray[Byte]
  /// LZ77 window size (32K by default)
  w_size : Int
  /// number of valid bytes ahead in window
  mut lookahead : Int
  /// prev[N], where N is an offset in the current window, contains the offset
  /// in the window of the previous 4-byte sequence that hashes to the same
  /// value as the 4-byte sequence starting at N.
  prev : FixedArray[Int]
  /// head[H] contains the offset of the last 4-character sequence seen so far
  /// in the current window that hashes to H.
  head : FixedArray[Int]
  /// Length of the best match at previous step.
  mut prev_length : Int
  /// To speed up deflation, hash chains are never searched beyond this length.
  mut max_chain_length : Int
  /// Attempt to find a better match only when the current match is strictly
  /// smaller than this value (also used as max_insert_length).
  mut max_lazy_match : Int
  /// number of string matches in current block (saturating 8-bit counter)
  mut matches : Int
  /// Window position at the beginning of the current output block. Gets
  /// negative when the window is moved backwards.
  mut block_start : Int
  sym_buf : SymBuf
  /// Actual size of window: 2*w_size.
  mut window_size : Int
  bit_writer : BitWriter
  /// bit length of current block with optimal trees
  mut opt_len : Int
  /// bit length of current block with static trees
  mut static_len : Int
  /// bytes at end of window left to insert
  mut insert : Int
  /// literal and length tree
  l_desc : TreeDesc
  /// distance tree
  d_desc : TreeDesc
  /// Huffman tree for bit lengths
  bl_desc : TreeDesc
}

///|
/// Upstream `init` with a zlib wrapper, window bits 15, memLevel 8
/// (`DEF_MEM_LEVEL`) and the default strategy, followed by `reset`.
fn DeflateStream::new(level : Int) -> DeflateStream {
  let level = if level == -1 { 6 } else { level }
  guard level >= 3 && level <= 6 else {
    abort("only deflate_medium levels (3..=6) are ported")
  }
  let window_bits = 15
  let mem_level = 8
  let lit_bufsize = 1 << (mem_level + 6) // 16K elements by default
  let w_size = 1 << window_bits
  let stream : DeflateStream = {
    input: b""[:],
    next_in: 0,
    avail_in: 0,
    output: Buffer(),
    avail_out: 0,
    total_out: 0,
    data_type: Z_UNKNOWN,
    adler: 0,
    status: STATUS_INIT,
    last_flush: 0,
    wrap: 1,
    strategy: STRATEGY_DEFAULT,
    level,
    good_match: 0,
    nice_match: 0,
    match_start: 0,
    strstart: 0,
    window: FixedArray::make(2 * w_size, b'\x00'),
    w_size,
    lookahead: 0,
    prev: FixedArray::make(w_size, 0),
    head: FixedArray::make(HASH_SIZE, 0),
    prev_length: 0,
    max_chain_length: 0,
    max_lazy_match: 0,
    matches: 0,
    block_start: 0,
    sym_buf: SymBuf::new(lit_bufsize),
    window_size: 0,
    bit_writer: {
      pending: Pending::new(4 * lit_bufsize),
      bit_buffer: 0,
      bits_valid: 0,
    },
    opt_len: 0,
    static_len: 0,
    insert: 0,
    l_desc: TreeDesc::new(HEAP_SIZE, static_l_desc),
    d_desc: TreeDesc::new(2 * D_CODES + 1, static_d_desc),
    bl_desc: TreeDesc::new(2 * BL_CODES + 1, static_bl_desc),
  }
  stream.reset()
  stream
}

///|
fn DeflateStream::reset(self : DeflateStream) -> Unit {
  self.reset_keep()
  self.lm_init()
}

///|
fn DeflateStream::reset_keep(self : DeflateStream) -> Unit {
  self.total_out = 0
  self.data_type = Z_UNKNOWN
  self.bit_writer.pending.pending = 0
  // can be made negative by deflate(..., Z_FINISH);
  self.wrap = self.wrap.abs()
  self.status = STATUS_INIT
  self.adler = ADLER32_INITIAL_VALUE
  self.last_flush = -2
  self.zng_tr_init()
}

///|
fn DeflateStream::zng_tr_init(self : DeflateStream) -> Unit {
  self.bit_writer.bit_buffer = 0
  self.bit_writer.bits_valid = 0
  // Initialize the first block of the first file:
  self.init_block()
}

///|
fn DeflateStream::lm_init(self : DeflateStream) -> Unit {
  self.window_size = 2 * self.w_size
  self.head.fill(0)
  // Set the default configuration parameters:
  self.lm_set_level(self.level)
  self.strstart = 0
  self.block_start = 0
  self.lookahead = 0
  self.insert = 0
  self.prev_length = 0
  self.match_start = 0
}

///|
fn DeflateStream::lm_set_level(self : DeflateStream, level : Int) -> Unit {
  let config = configuration_table[level]
  self.max_lazy_match = config.max_lazy
  self.good_match = config.good_length
  self.nice_match = config.nice_length
  self.max_chain_length = config.max_chain
  // `HashCalcVariant::for_max_chain_length`: the rolling hash is only used
  // for max_chain_length > 1024 (level 9), which is not ported.
  self.level = level
}

///|
/// log2(w_size)
fn DeflateStream::w_bits(self : DeflateStream) -> Int {
  self.w_size.ctz()
}

///|
fn DeflateStream::w_mask(self : DeflateStream) -> Int {
  self.w_size - 1
}

///|
fn DeflateStream::max_dist(self : DeflateStream) -> Int {
  self.w_size - MIN_LOOKAHEAD
}

///|
fn DeflateStream::max_insert_length(self : DeflateStream) -> Int {
  self.max_lazy_match
}

///|
fn DeflateStream::header(self : DeflateStream) -> Int {
  // preset dictionary flag in zlib header
  let preset_dict = 0x20
  // The deflate compression method (the only one supported in this version)
  let z_deflated = 8
  let dict = match self.strstart {
    0 => 0
    _ => preset_dict
  }
  let h = ((z_deflated + ((self.w_bits() - 8) << 4)) << 8) |
    (self.level_flags() << 6) |
    dict
  h + 31 - h % 31
}

///|
fn DeflateStream::level_flags(self : DeflateStream) -> Int {
  if self.level < 2 {
    0
  } else if self.level < 6 {
    1
  } else if self.level == 6 {
    2
  } else {
    3
  }
}

// -- hash_calc.rs (`StandardHashCalc`) --

///|
fn read_u32_le(window : FixedArray[Byte], i : Int) -> UInt {
  // One bounds check for all four bytes (performance).
  guard i >= 0 && i + 4 <= window.length() else { abort("index out of bounds") }
  // Intrinsic conversions only (core's `Byte::to_uint` is not inlined).
  (window.unsafe_get(i).to_int() |
  (window.unsafe_get(i + 1).to_int() << 8) |
  (window.unsafe_get(i + 2).to_int() << 16) |
  (window.unsafe_get(i + 3).to_int() << 24)).reinterpret_as_uint()
}

///|
fn read_u64_le(window : FixedArray[Byte], i : Int) -> UInt64 {
  // One bounds check for all eight bytes (performance).
  guard i >= 0 && i + 8 <= window.length() else { abort("index out of bounds") }
  let lo = window.unsafe_get(i).to_int() |
    (window.unsafe_get(i + 1).to_int() << 8) |
    (window.unsafe_get(i + 2).to_int() << 16) |
    (window.unsafe_get(i + 3).to_int() << 24)
  let hi = window.unsafe_get(i + 4).to_int() |
    (window.unsafe_get(i + 5).to_int() << 8) |
    (window.unsafe_get(i + 6).to_int() << 16) |
    (window.unsafe_get(i + 7).to_int() << 24)
  UInt64::extend_uint(lo.reinterpret_as_uint()) |
  (UInt64::extend_uint(hi.reinterpret_as_uint()) << 32)
}

///|
fn hash_update(val : UInt) -> Int {
  ((val * 2654435761U) >> 16).reinterpret_as_int() & (HASH_SIZE - 1)
}

///|
fn DeflateStream::quick_insert_string(
  self : DeflateStream,
  string : Int,
) -> Int {
  let val = read_u32_le(self.window, string)
  let hm = hash_update(val)
  let head = self.head[hm]
  if head != string {
    self.prev[string & self.w_mask()] = head
    self.head[hm] = string
  }
  head
}

///|
fn DeflateStream::insert_string(
  self : DeflateStream,
  string : Int,
  count : Int,
) -> Unit {
  // it can happen that insufficient bytes are initialized
  let len = @cmp.minimum(self.window.length() - string, count + 3)
  let w_mask = self.w_mask()
  for i in 0..<(len - 3) {
    let idx = (string + i) & 0xffff
    let val = read_u32_le(self.window, string + i)
    let hm = hash_update(val)
    let head = self.head[hm]
    if head != idx {
      self.prev[idx & w_mask] = head
      self.head[hm] = idx
    }
  }
}

// -- slide_hash.rs --

///|
fn DeflateStream::slide_hash(self : DeflateStream) -> Unit {
  let wsize = self.w_size
  let head = self.head
  for i in 0..<head.length() {
    let m = head.unsafe_get(i)
    head.unsafe_set(i, if m >= wsize { m - wsize } else { 0 })
  }
  let prev = self.prev
  for i in 0..<prev.length() {
    let m = prev.unsafe_get(i)
    prev.unsafe_set(i, if m >= wsize { m - wsize } else { 0 })
  }
}

///|
/// Read a new buffer from the current input stream, update the adler32 and
/// total number of bytes read.
fn DeflateStream::read_buf_window(
  self : DeflateStream,
  offset : Int,
  size : Int,
) -> Int {
  let len = @cmp.minimum(self.avail_in, size)
  if len == 0 {
    return 0
  }
  self.avail_in -= len
  let src = self.input[self.next_in:self.next_in + len]
  guard offset >= 0 && offset + len <= self.window.length() else {
    abort("index out of bounds")
  }
  let window = self.window
  for i in 0..<len {
    window.unsafe_set(offset + i, src[i])
  }
  if self.wrap == 1 {
    self.adler = adler32(self.adler, src)
  }
  self.next_in += len
  len
}

///|
/// Fill the window when the lookahead becomes insufficient. Updates strstart
/// and lookahead.
fn DeflateStream::fill_window(self : DeflateStream) -> Unit {
  let wsize = self.w_size
  while true {
    let mut more = self.window_size - self.lookahead - self.strstart

    // If the window is almost full and there is insufficient lookahead,
    // move the upper half to the lower one to make room in the upper half.
    if self.strstart >= wsize + self.max_dist() {
      // shift the window to the left
      self.window.blit_to(self.window, len=wsize, src_offset=wsize)
      if self.match_start >= wsize {
        self.match_start -= wsize
      } else {
        self.match_start = 0
        self.prev_length = 0
      }
      self.strstart -= wsize // we now have strstart >= MAX_DIST
      self.block_start -= wsize
      self.insert = @cmp.minimum(self.insert, self.strstart)
      self.slide_hash()
      more += wsize
    }
    if self.avail_in == 0 {
      break
    }
    guard more >= 2 else { abort("more < 2") }
    let n = self.read_buf_window(self.strstart + self.lookahead, more)
    self.lookahead += n

    // Initialize the hash value now that we have some input:
    if self.lookahead + self.insert >= STD_MIN_MATCH {
      let string = self.strstart - self.insert
      // (max_chain_length > 1024 only for level 9, not ported)
      if string >= 1 {
        self.quick_insert_string(string + 2 - STD_MIN_MATCH) |> ignore
      }
      let mut count = self.insert
      if self.lookahead == 1 {
        count -= 1
      }
      if count > 0 {
        self.insert_string(string, count)
        self.insert -= count
      }
    }

    // If the whole input has less than STD_MIN_MATCH bytes, ins_h is garbage,
    // but this is not important since only literal bytes will be emitted.
    if !(self.lookahead < MIN_LOOKAHEAD && self.avail_in != 0) {
      break
    }
  }
  guard self.strstart <= self.window_size - MIN_LOOKAHEAD else {
    abort("not enough room for search")
  }
}

///|
/// Flush as much pending output as possible.
fn DeflateStream::flush_pending(self : DeflateStream) -> Unit {
  let bw = self.bit_writer
  bw.flush_bits()
  let pending = bw.pending
  let len = @cmp.minimum(pending.pending, self.avail_out)
  if len == 0 {
    return
  }
  for i in pending.out..<(pending.out + len) {
    self.output.write_byte(pending.buf[i])
  }
  self.total_out += len.to_int64()
  self.avail_out -= len
  pending.advance(len)
}

///|
fn DeflateStream::flush_block_only(
  self : DeflateStream,
  is_last : Bool,
) -> Unit {
  self.zng_tr_flush_block(
    if self.block_start >= 0 {
      Some(self.block_start)
    } else {
      None
    },
    self.strstart - self.block_start,
    is_last,
  )
  self.block_start = self.strstart
  self.flush_pending()
}

///|
fn rank_flush(f : Int) -> Int {
  // rank Z_BLOCK between Z_NO_FLUSH and Z_PARTIAL_FLUSH
  f * 2 - (if f > 4 { 9 } else { 0 })
}

///|
/// Upstream `algorithm::run`.
fn DeflateStream::run(self : DeflateStream, flush : Int) -> BlockState {
  // Only the default strategy and `deflate_medium` levels are ported.
  self.deflate_medium(flush)
}

///|
/// Compresses as much data as possible, and stops when the input buffer
/// becomes empty or the output buffer becomes full (upstream `deflate`).
fn DeflateStream::deflate(self : DeflateStream, flush : Int) -> Int {
  if self.status == STATUS_FINISH && flush != FLUSH_FINISH {
    return Z_STREAM_ERROR
  }
  if self.avail_out == 0 {
    return Z_BUF_ERROR
  }
  let old_flush = self.last_flush
  self.last_flush = flush

  // Flush as much pending output as possible
  if self.bit_writer.pending.pending != 0 {
    self.flush_pending()
    if self.avail_out == 0 {
      // Since avail_out is 0, deflate will be called again with more output
      // space, but possibly with both pending and avail_in equal to zero.
      // There won't be anything to do, but this is not an error situation so
      // make sure we return OK instead of BUF_ERROR at next call of deflate:
      self.last_flush = -1
      return Z_OK
    }
    // Make sure there is something to do and avoid duplicate consecutive
    // flushes. For repeated and useless calls with Z_FINISH, we keep
    // returning Z_STREAM_END instead of Z_BUF_ERROR.
  } else if self.avail_in == 0 &&
    rank_flush(flush) <= rank_flush(old_flush) &&
    flush != FLUSH_FINISH {
    return Z_BUF_ERROR
  }

  // User must not provide more input after the first FINISH:
  if self.status == STATUS_FINISH && self.avail_in != 0 {
    return Z_BUF_ERROR
  }

  // Write the header
  if self.status == STATUS_INIT && self.wrap == 0 {
    self.status = STATUS_BUSY
  }
  if self.status == STATUS_INIT {
    let header = self.header()
    self.bit_writer.pending.push((header >> 8).to_byte())
    self.bit_writer.pending.push((header & 0xff).to_byte())
    // (no preset dictionary)
    self.adler = ADLER32_INITIAL_VALUE
    self.status = STATUS_BUSY

    // compression must start with an empty pending buffer
    self.flush_pending()
    if self.bit_writer.pending.pending != 0 {
      self.last_flush = -1
      return Z_OK
    }
  }

  // Start a new block or continue the current one.
  if self.avail_in != 0 ||
    self.lookahead != 0 ||
    (flush != FLUSH_NO && self.status != STATUS_FINISH) {
    let bstate = self.run(flush)
    if bstate is (FinishStarted | FinishDone) {
      self.status = STATUS_FINISH
    }
    match bstate {
      NeedMore | FinishStarted => {
        if self.avail_out == 0 {
          self.last_flush = -1 // avoid BUF_ERROR next call, see above
        }
        return Z_OK
        // If flush != Z_NO_FLUSH && avail_out == 0, the next call of deflate
        // should use the same flush parameter to make sure that the flush is
        // complete. So we don't have to output an empty block here, this will
        // be done at next call. This also ensures that for a very small output
        // buffer, we emit at most one empty block.
      }
      BlockDone => {
        match flush {
          FLUSH_PARTIAL => self.bit_writer.align()
          FLUSH_SYNC =>
            // add an empty stored block that is marked as not final.
            self.zng_tr_stored_block(0, 0, false)
          FLUSH_FULL => {
            self.zng_tr_stored_block(0, 0, false)
            self.head.fill(0) // forget history
            if self.lookahead == 0 {
              self.strstart = 0
              self.block_start = 0
              self.insert = 0
            }
          }
          FLUSH_BLOCK => () // fall through
          _ => abort("unreachable")
        }
        self.flush_pending()
        if self.avail_out == 0 {
          self.last_flush = -1 // avoid BUF_ERROR at next call, see above
          return Z_OK
        }
      }
      FinishDone => () // do nothing
    }
  }
  if flush != FLUSH_FINISH {
    return Z_OK
  }

  // write the trailer
  if self.wrap == 1 {
    let adler = self.adler
    for i in 0..<4 {
      self.bit_writer.pending.push((adler >> (8 * (3 - i))).to_byte())
    }
  }
  self.flush_pending()

  // If avail_out is zero, the application will call deflate again to flush
  // the rest.
  if self.wrap > 0 {
    self.wrap = -self.wrap // write the trailer only once!
  }
  if self.bit_writer.pending.pending == 0 {
    guard self.bit_writer.bits_valid == 0 else { abort("bi_buf not flushed") }
    return Z_STREAM_END
  }
  Z_OK
}

///|
/// Upstream `Deflate::compress` (stable API): compresses `input` into
/// `output`, writing at most `avail_out` bytes. Returns the return code and
/// the number of input bytes consumed.
fn DeflateStream::compress(
  self : DeflateStream,
  input : BytesView,
  output : Buffer,
  avail_out : Int,
  flush : Int,
) -> (Int, Int) {
  self.input = input
  self.next_in = 0
  self.avail_in = input.length()
  self.output = output
  self.avail_out = avail_out
  let ret = self.deflate(flush)
  let consumed = self.next_in
  self.input = b""[:]
  self.next_in = 0
  self.avail_in = 0
  self.avail_out = 0
  (ret, consumed)
}
