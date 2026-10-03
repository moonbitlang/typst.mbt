// Port of `hayro-ccitt/src/decode.rs`.

///|
/// End-of-facsimile-block marker (T.6 Section 2.4.1.1).
/// Two consecutive EOL codes: 000000000001 000000000001.
const EOFB : UInt = 0x1001

///|
/// 2D coding modes (T.4 Section 4.2.1.3.2, T.6 Section 2.2.3).
priv enum Mode {
  /// Pass mode (T.4 Section 4.2.1.3.2a, T.6 Section 2.2.3.1).
  Pass
  /// Horizontal mode (T.4 Section 4.2.1.3.2c, T.6 Section 2.2.3.3).
  Horizontal
  /// Vertical mode with offset (T.4 Section 4.2.1.3.2b, T.6 Section 2.2.3.2).
  Vertical(Int)
}

///|
/// Decode a run length using the given state machine (T.4 Section 4.1.1, T.6 Section 2.2.4).
///
/// Run lengths 0-63 use terminating codes.
/// Run lengths 64+ use one or more make-up codes followed by a terminating code.
fn BitReader::decode_run_inner(
  self : BitReader,
  states : FixedArray[State],
) -> UInt raise DecodeError {
  let mut total : UInt = 0
  let mut state = 0
  while true {
    let bit = self.read_bit()
    let transition = if bit == 0 {
      states[state].on_0
    } else {
      states[state].on_1
    }
    if transition == INVALID {
      raise InvalidCode
    } else if (transition & TERMINAL) != 0 {
      let len = (transition & VALUE_MASK).reinterpret_as_uint()
      // `checked_add`
      if total + len < total {
        raise Overflow
      }
      total = total + len
      // For decoding black/white runs, less than 64 means we have
      // a terminating code. For mode decoding, all values are less
      // than 64 anyway, so this condition can be used for all methods.
      if len < 64 {
        return total
      }
      state = 0
    } else {
      state = transition
    }
  }
  panic()
}

///|
/// Decode a white run length.
fn BitReader::decode_white_run(self : BitReader) -> UInt raise DecodeError {
  self.decode_run_inner(white_states()) catch {
    // See 0506179.pdf. We are lenient and check whether perhaps
    // the opposite color works.
    _ => self.decode_run_inner(black_states())
  }
}

///|
/// Decode a black run length.
fn BitReader::decode_black_run(self : BitReader) -> UInt raise DecodeError {
  self.decode_run_inner(black_states()) catch {
    // See 0506179.pdf. We are lenient and check whether perhaps
    // the opposite color works.
    _ => self.decode_run_inner(white_states())
  }
}

///|
/// Decode a run length for the specified color.
fn BitReader::decode_run(
  self : BitReader,
  color : Color,
) -> UInt raise DecodeError {
  match color {
    White => self.decode_white_run()
    Black => self.decode_black_run()
  }
}

///|
/// Decode a 2D mode code.
fn BitReader::decode_mode(self : BitReader) -> Mode raise DecodeError {
  let mode_value = self.decode_run_inner(mode_states())
  match mode_value {
    0 => Pass
    1 => Horizontal
    2 => Vertical(0)
    3 => Vertical(1)
    4 => Vertical(2)
    5 => Vertical(3)
    6 => Vertical(-1)
    7 => Vertical(-2)
    8 => Vertical(-3)
    _ => raise InvalidCode
  }
}

///|
/// Read EOL (End-of-Line) codes if present (T.4 Section 4.1.2).
///
/// EOL is defined as `000000000001` (11 zeros followed by a 1).
/// Fill bits (T.4 Section 4.1.3) may precede the EOL as a variable-length
/// string of zeros.
fn BitReader::read_eol_if_available(self : BitReader) -> Int {
  let mut count = 0
  // T.4 Section 4.1.2: EOL = 000000000001
  // T.4 Section 4.1.3: Fill = variable length string of 0s before EOL
  while true {
    let mut fill_bits = 0
    // Let's limit the maximum number of fill bits to prevent
    // exponential explosion in malformed files.
    let max_fill_bits = 24
    while fill_bits < max_fill_bits {
      match self.peak_bits(fill_bits + 1) {
        Some(0) => fill_bits += 1
        _ => break
      }
    }
    if fill_bits >= 11 && self.peak_bits(fill_bits + 1) == Some(1) {
      // Found EOL with fill bits, consume all of it.
      // (`read_bits(fill_bits + 1).unwrap()`: the peek above succeeded.)
      self.bit_offset += fill_bits + 1
      count += 1
      continue
    }
    return count
  }
  count
}
