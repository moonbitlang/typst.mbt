// Port of `hayro-jbig2/src/arithmetic_decoder.rs`.
//
// Note: This is a copy of the arithmetic decoder from `hayro-jpeg2000`,
// keep the two in sync.
//
// The arithmetic decoder, described in Annex C.
//
// The arithmetic decoder keeps track of some state and continuously receives
// context labels as input, each time yielding a new bit from the original data
// as output.
//
// (Upstream passes `&mut ArithmeticDecoderContext` into a context vector;
// here the contexts are `FixedArray[Byte]`s (bits 0-6 = index, bit 7 = mps,
// as upstream's packed `u8`) and the decoder takes the array and the index.)

///|
priv struct ArithmeticDecoder {
  /// The underlying encoded data.
  data : BytesView
  /// The C-register (see Table C.1).
  mut c : UInt
  /// The A-register (see Table C.1).
  mut a : UInt
  /// The pointer to the current byte.
  mut base_pointer : Int
  /// The bit shift counter.
  mut shift_count : UInt
}

///|
fn ArithmeticDecoder::new(data : BytesView) -> ArithmeticDecoder {
  let decoder = { data, c: 0, a: 0, base_pointer: 0, shift_count: 0, }
  decoder.initialize()
  decoder
}

///|
/// Read the next bit using the given context label.
#inline
fn ArithmeticDecoder::read_bit(
  self : ArithmeticDecoder,
  contexts : FixedArray[Byte],
  index : Int,
) -> UInt {
  self.decode(contexts, index)
}

///|
/// The INITDEC procedure from C.3.5.
///
/// We use the version from Annex G in <https://www.itu.int/rec/T-REC-T.88-201808-I>.
fn ArithmeticDecoder::initialize(self : ArithmeticDecoder) -> Unit {
  self.c = (self.current_byte().to_uint() ^ 0xff) << 16
  self.read_byte()
  self.c = self.c << 7
  self.shift_count -= 7
  self.a = 0x8000
}

///|
/// The BYTEIN procedure from C.3.4.
///
/// We use the version from Annex G from <https://www.itu.int/rec/T-REC-T.88-201808-I>.
#inline
fn ArithmeticDecoder::read_byte(self : ArithmeticDecoder) -> Unit {
  if self.current_byte() == 0xff {
    let b1 = self.next_byte()
    if b1 > 0x8f {
      self.shift_count = 8
    } else {
      self.base_pointer += 1
      self.c = self.c + 0xfe00 - (self.current_byte().to_uint() << 9)
      self.shift_count = 7
    }
  } else {
    self.base_pointer += 1
    self.c = self.c + 0xff00 - (self.current_byte().to_uint() << 8)
    self.shift_count = 8
  }
}

///|
/// The RENORMD procedure from C.3.3.
#inline
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
    let shifts_needed = self.a.clz().reinterpret_as_uint() - 16
    let batch = if shifts_needed < self.shift_count {
      shifts_needed
    } else {
      self.shift_count
    }
    let batch_i = batch.reinterpret_as_int()
    self.a = self.a << batch_i
    self.c = self.c << batch_i
    self.shift_count -= batch
  }
}

// (`exchange_lps` / `exchange_mps` are kept upstream only "for reference";
// the unified branchless version in `decode` is what runs.)

///|
/// The DECODE procedure from C.3.2.
///
/// We use the version from Annex G from <https://www.itu.int/rec/T-REC-T.88-201808-I>.
#inline
fn ArithmeticDecoder::decode(
  self : ArithmeticDecoder,
  contexts : FixedArray[Byte],
  index : Int,
) -> UInt {
  let context = contexts[index].to_uint()
  // (`QE_TABLE[context.index()]`, packed into one word; see `qe_packed`.)
  let qe_entry = qe_packed[(context & 0x7F).reinterpret_as_int()]
  let qe = qe_entry & 0xFFFF
  let mps = context >> 7
  self.a -= qe

  // This is a faster version that reduces branching, which has shown
  // itself to be the main limiting factor for better performance.
  // We short-circuit the case where just the most probably symbol is
  // returned, and otherwise use a code path that works for both,
  // MPS_EXCHANGE and LPS_EXCHANGE.
  if self.c >> 16 < self.a && (self.a & 0x8000) != 0 {
    return mps
  }

  // Unified branchless MPS_EXCHANGE / LPS_EXCHANGE.
  //
  // exchange_mps: d = mps ^ cond,       flip when cond,      index = cond*nlps + inv*nmps
  // exchange_lps: d = mps ^ inv_cond,   flip when inv_cond,  index = cond*nmps + inv*nlps
  //
  // This is equivalent to XOR-ing cond with is_lps, so we can handle
  // both paths with a single branchless computation.
  //
  // As can be seen above, renormalization is always performed.
  let is_lps : UInt = if self.c >> 16 >= self.a { 1 } else { 0 }

  // LPS: C -= A << 16 (no-op when MPS).
  let lps_mask = 0U - is_lps // 0xFFFF_FFFF if LPS, 0 if MPS
  self.c -= (self.a << 16) & lps_mask

  // Same condition as in exchange_mps / exchange_lps.
  let cond : UInt = if self.a < qe { 1 } else { 0 }

  // LPS: a = qe (no-op when MPS, a stays as a - qe).
  self.a = (self.a & lps_mask.lnot()) | (qe & lps_mask)

  // unified: d = mps ^ (cond ^ is_lps)
  let d = mps ^ cond ^ is_lps

  // unified: flip mps when (cond ^ is_lps) & switch
  let flip = (cond ^ is_lps) & (qe_entry >> 31)

  // unified: the result is always exactly nmps or nlps —
  //          pick nlps when (cond ^ is_lps) == 1, nmps otherwise.
  let new_index = if (cond ^ is_lps) != 0 {
    (qe_entry >> 24) & 0x7F
  } else {
    (qe_entry >> 16) & 0x7F
  }
  contexts[index] = (((mps ^ flip) << 7) | new_index).to_byte()
  self.renormalize()
  d
}

///|
#inline
fn ArithmeticDecoder::current_byte(self : ArithmeticDecoder) -> Byte {
  let p = self.base_pointer
  if p >= 0 && p < self.data.length() {
    self.data[p]
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
#inline
fn ArithmeticDecoder::next_byte(self : ArithmeticDecoder) -> Byte {
  let p = self.base_pointer + 1
  if p >= 0 && p < self.data.length() {
    self.data[p]
  } else {
    0xFF
  }
}

///|
/// A fresh context vector (`vec![ArithmeticDecoderContext::default(); n]`).
fn new_contexts(n : Int) -> FixedArray[Byte] {
  FixedArray::make(n, b'\x00')
}

///|
priv struct QeData {
  qe : UInt
  nmps : UInt
  nlps : UInt
  switch_ : Bool
}

///|
/// `qe_table` packed as `qe | nmps << 16 | nlps << 24 | switch << 31`, so
/// that `decode` needs a single load per bit.
let qe_packed : FixedArray[UInt] = FixedArray::makei(qe_table.length(), i => {
  let e = qe_table[i]
  e.qe |
  (e.nmps << 16) |
  (e.nlps << 24) |
  (if e.switch_ { 1U << 31 } else { 0 })
})

///|
/// QE values and associated data from Table C.2.
let qe_table : ReadOnlyArray[QeData] = [
  { qe: 0x5601, nmps: 1, nlps: 1, switch_: true, },
  { qe: 0x3401, nmps: 2, nlps: 6, switch_: false, },
  { qe: 0x1801, nmps: 3, nlps: 9, switch_: false, },
  { qe: 0x0AC1, nmps: 4, nlps: 12, switch_: false, },
  { qe: 0x0521, nmps: 5, nlps: 29, switch_: false, },
  { qe: 0x0221, nmps: 38, nlps: 33, switch_: false, },
  { qe: 0x5601, nmps: 7, nlps: 6, switch_: true, },
  { qe: 0x5401, nmps: 8, nlps: 14, switch_: false, },
  { qe: 0x4801, nmps: 9, nlps: 14, switch_: false, },
  { qe: 0x3801, nmps: 10, nlps: 14, switch_: false, },
  { qe: 0x3001, nmps: 11, nlps: 17, switch_: false, },
  { qe: 0x2401, nmps: 12, nlps: 18, switch_: false, },
  { qe: 0x1C01, nmps: 13, nlps: 20, switch_: false, },
  { qe: 0x1601, nmps: 29, nlps: 21, switch_: false, },
  { qe: 0x5601, nmps: 15, nlps: 14, switch_: true, },
  { qe: 0x5401, nmps: 16, nlps: 14, switch_: false, },
  { qe: 0x5101, nmps: 17, nlps: 15, switch_: false, },
  { qe: 0x4801, nmps: 18, nlps: 16, switch_: false, },
  { qe: 0x3801, nmps: 19, nlps: 17, switch_: false, },
  { qe: 0x3401, nmps: 20, nlps: 18, switch_: false, },
  { qe: 0x3001, nmps: 21, nlps: 19, switch_: false, },
  { qe: 0x2801, nmps: 22, nlps: 19, switch_: false, },
  { qe: 0x2401, nmps: 23, nlps: 20, switch_: false, },
  { qe: 0x2201, nmps: 24, nlps: 21, switch_: false, },
  { qe: 0x1C01, nmps: 25, nlps: 22, switch_: false, },
  { qe: 0x1801, nmps: 26, nlps: 23, switch_: false, },
  { qe: 0x1601, nmps: 27, nlps: 24, switch_: false, },
  { qe: 0x1401, nmps: 28, nlps: 25, switch_: false, },
  { qe: 0x1201, nmps: 29, nlps: 26, switch_: false, },
  { qe: 0x1101, nmps: 30, nlps: 27, switch_: false, },
  { qe: 0x0AC1, nmps: 31, nlps: 28, switch_: false, },
  { qe: 0x09C1, nmps: 32, nlps: 29, switch_: false, },
  { qe: 0x08A1, nmps: 33, nlps: 30, switch_: false, },
  { qe: 0x0521, nmps: 34, nlps: 31, switch_: false, },
  { qe: 0x0441, nmps: 35, nlps: 32, switch_: false, },
  { qe: 0x02A1, nmps: 36, nlps: 33, switch_: false, },
  { qe: 0x0221, nmps: 37, nlps: 34, switch_: false, },
  { qe: 0x0141, nmps: 38, nlps: 35, switch_: false, },
  { qe: 0x0111, nmps: 39, nlps: 36, switch_: false, },
  { qe: 0x0085, nmps: 40, nlps: 37, switch_: false, },
  { qe: 0x0049, nmps: 41, nlps: 38, switch_: false, },
  { qe: 0x0025, nmps: 42, nlps: 39, switch_: false, },
  { qe: 0x0015, nmps: 43, nlps: 40, switch_: false, },
  { qe: 0x0009, nmps: 44, nlps: 41, switch_: false, },
  { qe: 0x0005, nmps: 45, nlps: 42, switch_: false, },
  { qe: 0x0001, nmps: 45, nlps: 43, switch_: false, },
  { qe: 0x5601, nmps: 46, nlps: 46, switch_: false, },
]
