// Port of `hayro-jbig2/src/symbol_id_decoder.rs`: symbol ID (IAID) decoder
// (A.3).

///|
priv struct SymbolIdDecoder {
  contexts : FixedArray[Byte]
  code_len : UInt
}

///|
fn SymbolIdDecoder::new(code_len : UInt) -> SymbolIdDecoder {
  // A.3: "The number of contexts required is 2^SBSYMCODELEN, which is less
  // than twice the maximum symbol ID."
  let num_contexts = 1 << code_len.reinterpret_as_int()
  { contexts: new_contexts(num_contexts), code_len, }
}

///|
fn SymbolIdDecoder::decode(
  self : SymbolIdDecoder,
  decoder : ArithmeticDecoder,
) -> UInt {
  let mut prev = 1U
  for _ in 0U..<self.code_len {
    let ctx_mask = (1U << (self.code_len + 1).reinterpret_as_int()) - 1
    let ctx_idx = (prev & ctx_mask).reinterpret_as_int()
    let d = decoder.read_bit(self.contexts, ctx_idx)
    prev = (prev << 1) | d
  }
  prev -= 1U << self.code_len.reinterpret_as_int()
  prev
}
