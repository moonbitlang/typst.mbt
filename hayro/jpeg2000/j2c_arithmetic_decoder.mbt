// Port of `hayro-jpeg2000/src/j2c/arithmetic_decoder.rs`: the arithmetic
// decoder, described in Annex C.
//
// The arithmetic decoder keeps track of some state and continuously receives
// context labels as input, each time yielding a new bit from the original data
// as output.
//
// Contexts (`ArithmeticDecoderContext`) are bit-packed `u8`s stored in an
// `Int` array that is passed to `decode` together with the context label.

///|
priv struct ArithmeticDecoder {
  /// The underlying encoded data (`data[start..start + len]`).
  data : FixedArray[Byte]
  start : Int
  len : Int
  /// The C-register (see Table C.1).
  mut c : UInt
  /// The A-register (see Table C.1).
  mut a : UInt
  /// The pointer to the current byte.
  mut base_pointer : Int
  /// The bit shift counter.
  mut shift_count : Int
}

///|
fn ArithmeticDecoder::new(
  data : FixedArray[Byte],
  start : Int,
  len : Int,
) -> ArithmeticDecoder {
  let decoder = {
    data,
    start,
    len,
    c: 0,
    a: 0,
    base_pointer: 0,
    shift_count: 0,
  }
  decoder.initialize()
  decoder
}

///|
/// The INITDEC procedure from C.3.5.
///
/// We use the version from Annex G in <https://www.itu.int/rec/T-REC-T.88-201808-I>.
fn ArithmeticDecoder::initialize(self : ArithmeticDecoder) -> Unit {
  self.c = (self.current_byte().reinterpret_as_uint() ^ 0xff) << 16
  self.read_byte()
  self.c = self.c << 7
  self.shift_count -= 7
  self.a = 0x8000
}

///|
/// The BYTEIN procedure from C.3.4.
///
/// We use the version from Annex G from <https://www.itu.int/rec/T-REC-T.88-201808-I>.
fn ArithmeticDecoder::read_byte(self : ArithmeticDecoder) -> Unit {
  if self.current_byte() == 0xff {
    let b1 = self.next_byte()
    if b1 > 0x8f {
      self.shift_count = 8
    } else {
      self.base_pointer += 1
      self.c = self.c +
        0xfe00 -
        (self.current_byte().reinterpret_as_uint() << 9)
      self.shift_count = 7
    }
  } else {
    self.base_pointer += 1
    self.c = self.c + 0xff00 - (self.current_byte().reinterpret_as_uint() << 8)
    self.shift_count = 8
  }
}

///|
/// The RENORMD procedure from C.3.3.
fn ArithmeticDecoder::renormalize(self : ArithmeticDecoder) -> Unit {
  // Original code:
  // loop {
  //     if self.shift_count == 0 {
  //         self.read_byte();
  //     }
  //
  //     self.a <<= 1;
  //     self.c <<= 1;
  //     self.shift_count -= 1;
  //
  //     if self.a & 0x8000 != 0 {
  //         break;
  //     }
  // }

  // Optimization: Batch shifts.
  while (self.a & 0x8000) == 0 {
    if self.shift_count == 0 {
      self.read_byte()
    }
    let shifts_needed = self.a.clz() - 16
    let batch = if shifts_needed < self.shift_count {
      shifts_needed
    } else {
      self.shift_count
    }
    self.a = self.a << batch
    self.c = self.c << batch
    self.shift_count -= batch
  }
}

///|
/// The DECODE procedure from C.3.2, reading the next bit with the context
/// `contexts[label]`.
///
/// We use the version from Annex G from <https://www.itu.int/rec/T-REC-T.88-201808-I>.
fn ArithmeticDecoder::read_bit(
  self : ArithmeticDecoder,
  contexts : FixedArray[Int],
  label : Int,
) -> Int {
  // `label` is always a valid context label (< 19) and the index bits of a
  // context are always a valid `QE_TABLE` index (< 47), so the hot path
  // skips the bounds checks.
  let context = contexts.unsafe_get(label)
  let index = context & 0x7F
  let qe = qe_table_qe.unsafe_get(index)
  self.a = self.a - qe

  // This is a faster version that reduces branching, which has shown
  // itself to be the main limiting factor for better performance.
  // We short-circuit the case where just the most probably symbol is
  // returned, and otherwise use a code path that works for both,
  // MPS_EXCHANGE and LPS_EXCHANGE.

  let c_high = self.c >> 16
  if c_high < self.a && (self.a & 0x8000) != 0 {
    return context >> 7
  }

  // Unified MPS_EXCHANGE / LPS_EXCHANGE.
  //
  // exchange_mps: d = mps ^ cond,       flip when cond,      index = cond*nlps + inv*nmps
  // exchange_lps: d = mps ^ inv_cond,   flip when inv_cond,  index = cond*nmps + inv*nlps
  //
  // This is equivalent to XOR-ing cond with is_lps, so we can handle
  // both paths with a single computation.
  //
  // As can be seen above, renormalization is always performed.
  let is_lps = c_high >= self.a

  // LPS: C -= A << 16 (no-op when MPS).
  if is_lps {
    self.c = self.c - (self.a << 16)
  }

  // Same condition as in exchange_mps / exchange_lps.
  let cond = self.a < qe

  // LPS: a = qe (no-op when MPS, a stays as a - qe).
  if is_lps {
    self.a = qe
  }
  let flip = cond != is_lps
  let mps = context >> 7
  let d = if flip { mps ^ 1 } else { mps }
  let mut new_context = context
  if flip && qe_table_switch.unsafe_get(index) {
    new_context = new_context ^ 0x80
  }
  let new_index = if flip {
    qe_table_nlps.unsafe_get(index)
  } else {
    qe_table_nmps.unsafe_get(index)
  }
  contexts.unsafe_set(label, (new_context & 0x80) | new_index)
  self.renormalize()
  d
}

///|
fn ArithmeticDecoder::current_byte(self : ArithmeticDecoder) -> Int {
  if self.base_pointer < self.len {
    self.data[self.start + self.base_pointer].to_int()
  } else {
    // "The number of bytes corresponding to the coding passes is
    // specified in the packet header. Often at that point there are
    // more symbols to be decoded. Therefore, the decoder shall extend
    // the input bit stream to the arithmetic coder with 0xFF bytes,
    // as necessary, until all symbols have been decoded."
    0xFF
  }
}

///|
fn ArithmeticDecoder::next_byte(self : ArithmeticDecoder) -> Int {
  if self.base_pointer + 1 < self.len {
    self.data[self.start + self.base_pointer + 1].to_int()
  } else {
    0xFF
  }
}

// `ArithmeticDecoderContext`: bits 0-6 = index (0-46), bit 7 = mps (0 or 1).
// `reset` sets it to 0, `reset_with_index(i)` to `i`.

// QE values and associated data from Table C.2.

///|
let qe_table_qe : ReadOnlyArray[UInt] = [
  0x5601, 0x3401, 0x1801, 0x0AC1, 0x0521, 0x0221, 0x5601, 0x5401, 0x4801, 0x3801,
  0x3001, 0x2401, 0x1C01, 0x1601, 0x5601, 0x5401, 0x5101, 0x4801, 0x3801, 0x3401,
  0x3001, 0x2801, 0x2401, 0x2201, 0x1C01, 0x1801, 0x1601, 0x1401, 0x1201, 0x1101,
  0x0AC1, 0x09C1, 0x08A1, 0x0521, 0x0441, 0x02A1, 0x0221, 0x0141, 0x0111, 0x0085,
  0x0049, 0x0025, 0x0015, 0x0009, 0x0005, 0x0001, 0x5601,
]

///|
let qe_table_nmps : ReadOnlyArray[Int] = [
  1, 2, 3, 4, 5, 38, 7, 8, 9, 10, 11, 12, 13, 29, 15, 16, 17, 18, 19, 20, 21, 22,
  23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42,
  43, 44, 45, 45, 46,
]

///|
let qe_table_nlps : ReadOnlyArray[Int] = [
  1, 6, 9, 12, 29, 33, 6, 14, 14, 14, 17, 18, 20, 21, 14, 14, 15, 16, 17, 18, 19,
  19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38,
  39, 40, 41, 42, 43, 46,
]

///|
let qe_table_switch : ReadOnlyArray[Bool] = [
  true, false, false, false, false, false, true, false, false, false, false, false,
  false, false, true, false, false, false, false, false, false, false, false, false,
  false, false, false, false, false, false, false, false, false, false, false, false,
  false, false, false, false, false, false, false, false, false, false, false,
]
