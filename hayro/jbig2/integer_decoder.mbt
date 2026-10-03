// Port of `hayro-jbig2/src/integer_decoder.rs`.

///|
/// The integer arithmetic decoder (A.2).
priv struct IntegerDecoder {
  /// `CX` - Context memory for the integer decoder.
  contexts : FixedArray[Byte]
}

///|
/// Create a new integer decoder with fresh contexts.
fn IntegerDecoder::new() -> IntegerDecoder {
  // A.2: "Each arithmetic integer decoding procedure requires 512 bytes of
  // storage for its context memory."
  { contexts: new_contexts(512), }
}

///|
/// The integer arithmetic decoding procedure (A.2, Figure A.1).
///
/// Returns `Some(value)` on success, or `None` if OOB (out-of-band) is decoded.
fn IntegerDecoder::decode(
  self : IntegerDecoder,
  decoder : ArithmeticDecoder,
) -> Int? {
  // A.2 step 1: "Set: PREV = 1"
  // `PREV` - Context prefix, contains bits decoded so far plus a leading 1.
  let prev = Ref::new(1U)

  // A.2 step 2: "Follow the flowchart in Figure A.1. Decode each bit with
  // CX equal to 'IAx + PREV' where 'IAx' represents the identifier of the
  // current arithmetic integer decoding procedure, '+' represents
  // concatenation, and the rightmost 9 bits of PREV are used."

  // `S` - Sign bit.
  let s = self.decode_bit(decoder, prev)

  // `V` - Magnitude value, decoded according to Figure A.1 flowchart.
  let v = if self.decode_bit(decoder, prev) == 0 {
    // Figure A.1: "V = next 2 bits"
    self.decode_n_bits(decoder, prev, 2)
  } else if self.decode_bit(decoder, prev) == 0 {
    // Figure A.1: "V = (next 4 bits) + 4"
    self.decode_n_bits(decoder, prev, 4) + 4
  } else if self.decode_bit(decoder, prev) == 0 {
    // Figure A.1: "V = (next 6 bits) + 20"
    self.decode_n_bits(decoder, prev, 6) + 20
  } else if self.decode_bit(decoder, prev) == 0 {
    // Figure A.1: "V = (next 8 bits) + 84"
    self.decode_n_bits(decoder, prev, 8) + 84
  } else if self.decode_bit(decoder, prev) == 0 {
    // Figure A.1: "V = (next 12 bits) + 340"
    self.decode_n_bits(decoder, prev, 12) + 340
  } else {
    // Figure A.1: "V = (next 32 bits) + 4436"
    self.decode_n_bits(decoder, prev, 32) + 4436
  }

  // A.2: "The result of the integer arithmetic decoding procedure is equal to:
  // - V if S = 0
  // - -V if S = 1 and V > 0
  // - OOB if S = 1 and V = 0"
  if s == 0 {
    Some(v.reinterpret_as_int())
  } else if v > 0 {
    Some(-v.reinterpret_as_int())
  } else {
    None
  }
}

///|
/// Decode a single bit and update `PREV` (A.2 step 3).
///
/// A.2 step 3: "After each bit is decoded: If PREV < 256 set:
/// PREV = (PREV << 1) OR D. Otherwise set:
/// PREV = (((PREV << 1) OR D) AND 511) OR 256"
#inline
fn IntegerDecoder::decode_bit(
  self : IntegerDecoder,
  decoder : ArithmeticDecoder,
  prev : Ref[UInt],
) -> UInt {
  let ctx_idx = (prev.val & 0x1FF).reinterpret_as_int()
  // `D` - The just-decoded bit.
  let d = decoder.read_bit(self.contexts, ctx_idx)

  // A.2 step 3: Update PREV.
  if prev.val < 256 {
    prev.val = (prev.val << 1) | d
  } else {
    // A.2: "PREV always contains the values of the eight most-recently-
    // decoded bits, plus a leading 1 bit, which is used to indicate the
    // number of bits decoded so far."
    prev.val = (((prev.val << 1) | d) & 511) | 256
  }
  d
}

///|
/// Decode `n` bits and update `PREV` for each.
#inline
fn IntegerDecoder::decode_n_bits(
  self : IntegerDecoder,
  decoder : ArithmeticDecoder,
  prev : Ref[UInt],
  n : Int,
) -> UInt {
  let mut value = 0U
  for _ in 0..<n {
    let bit = self.decode_bit(decoder, prev)
    value = (value << 1) | bit
  }
  value
}
