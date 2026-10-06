// Port of the parts of `ciborium` 0.2.2 (`de/mod.rs`, `de/error.rs`) and
// `ciborium-ll` 0.2.2 (`dec.rs`, `hdr.rs`, `seg.rs`) that
// `ciborium::from_reader::<Value>` exercises for Typst values (always
// `deserialize_any` with Typst's `ValueVisitor`).

///|
/// A CBOR decoding error (upstream `ciborium::de::Error<std::io::Error>`).
pub(all) suberror CborError {
  /// An error occurred while reading bytes (always an unexpected EOF when
  /// reading from a slice).
  Io(String)
  /// An error occurred while parsing bytes, at the given offset.
  Syntax(Int)
  /// An error occurred while processing a parsed value.
  Semantic(Int?, String)
  /// The input caused serde to recurse too much.
  RecursionLimitExceeded
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CborError with @debug.Debug::{to_repr}

///|
/// The message Typst shows for the error (upstream `format_cbor_error`;
/// ciborium's own `Display` just forwards to `Debug`).
pub fn CborError::message(self : CborError) -> String {
  match self {
    Io(e) => "IO error: \{e}"
    Syntax(_) => "syntax error"
    Semantic(_, s) => s
    RecursionLimitExceeded => "recursion limit exceeded"
  }
}

///|
/// The message of `std::io::ErrorKind::UnexpectedEof` from `read_exact`.
let unexpected_eof : String = "failed to fill whole buffer"

///|
/// A CBOR item header (upstream `ciborium_ll::Header`).
priv enum Header {
  Positive(UInt64)
  Negative(UInt64)
  Float(Double)
  Simple(Int)
  Tag(UInt64)
  Break
  Bytes(Int?)
  Text(Int?)
  Array(Int?)
  Map(Int?)
}

// Simple values: 20 = false, 21 = true, 22 = null, 23 = undefined.

///|
let tag_bigpos : UInt64 = 2

///|
let tag_bigneg : UInt64 = 3

///|
/// The scratch buffer size of `ciborium::from_reader`.
let scratch_len : Int = 4096

///|
/// The deserializer state (upstream `Deserializer` with its `Decoder`).
priv struct Deserializer {
  data : Bytes
  mut index : Int
  /// A header pushed back by `push` (upstream `Decoder::buffer`).
  mut buffer : Header?
  mut recurse : Int
}

///|
/// Deserialize a value from CBOR bytes (upstream
/// `ciborium::from_reader::<Value>`). Trailing data is ignored.
pub fn from_slice(data : Bytes) -> @serde.Data raise CborError {
  let de : Deserializer = { data, index: 0, buffer: None, recurse: 256, }
  de.deserialize_any()
}

///|
fn Deserializer::read_exact(
  self : Deserializer,
  len : Int,
) -> BytesView raise CborError {
  if self.index + len > self.data.length() {
    self.index = self.data.length()
    raise Io(unexpected_eof)
  }
  let view = self.data[self.index:self.index + len]
  self.index += len
  view
}

///|
fn be_uint(bytes : BytesView) -> UInt64 {
  let mut v = 0UL
  for b in bytes {
    v = (v << 8) | b.to_uint64()
  }
  v
}

///|
/// Pull the next header (upstream `Decoder::pull`).
fn Deserializer::pull(self : Deserializer) -> Header raise CborError {
  if self.buffer is Some(header) {
    self.buffer = None
    return header
  }
  let offset = self.index
  let prefix = self.read_exact(1)[0].to_int()
  let major = prefix >> 5
  let minor = prefix & 0b11111
  // `None` stands for `Minor::More`.
  let (arg, width) : (UInt64?, Int) = if minor < 24 {
    (Some(minor.to_uint64()), 0)
  } else if minor == 24 {
    (Some(be_uint(self.read_exact(1))), 1)
  } else if minor == 25 {
    (Some(be_uint(self.read_exact(2))), 2)
  } else if minor == 26 {
    (Some(be_uint(self.read_exact(4))), 4)
  } else if minor == 27 {
    (Some(be_uint(self.read_exact(8))), 8)
  } else if minor == 31 {
    (None, 0)
  } else {
    raise Syntax(offset)
  }
  let int = fn() -> UInt64 raise CborError {
    match arg {
      Some(x) => x
      None => raise Syntax(offset)
    }
  }
  let len = fn() -> Int? raise CborError {
    match arg {
      Some(x) =>
        if x > 0x7FFF_FFFF_FFFF_FFFFUL {
          raise Syntax(offset)
        } else {
          Some(x.reinterpret_as_int64().to_int())
        }
      None => None
    }
  }
  match major {
    0 => Positive(int())
    1 => Negative(int())
    2 => Bytes(len())
    3 => Text(len())
    4 => Array(len())
    5 => Map(len())
    6 => Tag(int())
    _ =>
      match (arg, width) {
        (None, _) => Break
        (Some(x), 0) => Simple(x.to_int())
        (Some(x), 1) => Simple(x.to_int())
        (Some(x), 2) => Float(f16_to_double(x.to_int()))
        (Some(x), 4) =>
          Float(Float::reinterpret_from_uint(x.to_uint()).to_double())
        (Some(x), _) => Float(x.reinterpret_as_double())
      }
  }
}

///|
/// Push a header back (upstream `Decoder::push`).
fn Deserializer::push(self : Deserializer, header : Header) -> Unit {
  self.buffer = Some(header)
}

///|
/// Convert the bits of an IEEE half-precision float to a double.
fn f16_to_double(bits : Int) -> Double {
  let sign = if (bits & 0x8000) != 0 { -1.0 } else { 1.0 }
  let exp = (bits >> 10) & 0x1F
  let mant = bits & 0x3FF
  if exp == 0 {
    sign * mant.to_double() * @math.pow(2.0, -24.0)
  } else if exp == 0x1F {
    if mant == 0 {
      sign * @double.infinity
    } else {
      // Preserve the payload like `half`'s conversion.
      let bits64 = (if sign < 0.0 { 0x8000_0000_0000_0000UL } else { 0UL }) |
        0x7FF0_0000_0000_0000UL |
        (mant.to_uint64() << 42)
      bits64.reinterpret_as_double()
    }
  } else {
    sign * (1024 + mant).to_double() * @math.pow(2.0, (exp - 25).to_double())
  }
}

///|
/// The serde `Unexpected` description of a header (upstream
/// `impl Expected for Header`).
fn Header::unexpected(self : Header) -> String {
  match self {
    Positive(x) => "integer `\{x}`"
    Negative(x) =>
      "integer `\{(x ^ 0xFFFF_FFFF_FFFF_FFFFUL).reinterpret_as_int64()}`"
    Bytes(_) => "bytes"
    Text(_) => "string"
    Array(_) => "sequence"
    Map(_) => "map"
    Tag(_) => "tag"
    Simple(20) => "boolean `false`"
    Simple(21) => "boolean `true`"
    Simple(22) => "null"
    Simple(23) => "undefined"
    Simple(_) => "simple"
    Float(x) => "floating point `\{@serde.with_decimal_point(x)}`"
    Break => "break"
  }
}

///|
fn Header::expected(self : Header, kind : String) -> CborError {
  Semantic(None, @serde.invalid_type(self.unexpected(), kind))
}

///|
fn Deserializer::recurse(
  self : Deserializer,
  f : () -> @serde.Data raise CborError,
) -> @serde.Data raise CborError {
  if self.recurse == 0 {
    raise RecursionLimitExceeded
  }
  self.recurse -= 1
  let result = f()
  self.recurse += 1
  result
}

///|
/// Read an integer (upstream `Deserializer::integer`): whether it is
/// negative and its raw magnitude (as a big integer, since bignums can
/// have up to 16 bytes).
fn Deserializer::integer(
  self : Deserializer,
  header : Header?,
) -> (Bool, @bigint.BigInt) raise CborError {
  let mut header = header
  while true {
    let h = match header {
      Some(h) => {
        header = None
        h
      }
      None => self.pull()
    }
    let neg = match h {
      Positive(x) => return (false, @bigint.BigInt::from_uint64(x))
      Negative(x) => return (true, @bigint.BigInt::from_uint64(x))
      Tag(t) if t == tag_bigpos => false
      Tag(t) if t == tag_bigneg => true
      Tag(_) => continue
      h => raise h.expected("integer")
    }
    match self.pull() {
      Bytes(len) => {
        let mut value = @bigint.BigInt::from_int(0)
        let mut index = 0
        for segment in self.byte_segments(len) {
          for b in segment {
            if index == 16 {
              raise Semantic(None, "bigint too large")
            }
            // Skip leading zeros.
            if index == 0 && b == 0 {
              continue
            }
            value = value * 256 + @bigint.BigInt::from_int(b.to_int())
            index += 1
          }
        }
        return (neg, value)
      }
      h => raise h.expected("bytes")
    }
  }
  panic()
}

///|
/// Read the segments of a (possibly indefinite-length) byte string whose
/// header was already pulled (upstream `Decoder::bytes` + `Segments`).
fn Deserializer::byte_segments(
  self : Deserializer,
  len : Int?,
) -> Array[BytesView] raise CborError {
  self.push(Bytes(len))
  self.segments(h => {
    match h {
      Bytes(len) => Ok(len)
      _ => Err(())
    }
  })
}

///|
/// Pull all segments (upstream `Segments::pull` + `Segment::pull`).
fn Deserializer::segments(
  self : Deserializer,
  unwrap : (Header) -> Result[Int?, Unit],
) -> Array[BytesView] raise CborError {
  let out = []
  let mut nested = 0
  let mut finish = false
  while !finish {
    let offset = self.index
    match self.pull() {
      Break if nested == 1 => return out
      Break if nested > 1 => nested -= 1
      header =>
        match unwrap(header) {
          Err(_) => raise Syntax(offset)
          Ok(None) => nested += 1
          Ok(Some(len)) => {
            finish = nested == 0
            out.push(self.read_exact(len))
          }
        }
    }
  }
  out
}

///|
/// Read the segments of a (possibly indefinite-length) text string whose
/// header was already pulled, validating UTF-8 per segment (upstream
/// `Decoder::text` + `Segments` with the `Text` parser).
fn Deserializer::text_segments(
  self : Deserializer,
  len : Int?,
) -> String raise CborError {
  let offset = self.index
  self.push(Text(len))
  let segments = self.segments(h => {
    match h {
      Text(len) => Ok(len)
      _ => Err(())
    }
  })
  let buf = StringBuilder()
  for segment in segments {
    guard @serde.decode_utf8(segment) is Some(s) else { raise Syntax(offset) }
    buf.write_string(s)
  }
  buf.to_string()
}

///|
/// Convert a raw magnitude (`raw`, or `-1 - raw` if `neg`) to data the way
/// Typst's `IntoValue` for `u128`/`i128` does.
fn int_data(neg : Bool, raw : @bigint.BigInt) -> @serde.Data {
  let value = if neg { -raw - 1 } else { raw }
  let min = @bigint.BigInt::from_int64(-0x8000_0000_0000_0000L)
  let max = @bigint.BigInt::from_int64(0x7FFF_FFFF_FFFF_FFFFL)
  if value >= min && value <= max {
    Int(value.to_int64())
  } else {
    Float(@string.parse_double(value.to_string()) catch { _ => 0.0 })
  }
}

///|
/// Upstream `deserialize_any` driving Typst's `ValueVisitor`.
fn Deserializer::deserialize_any(
  self : Deserializer,
) -> @serde.Data raise CborError {
  let header = self.pull()
  match header {
    // `deserialize_u64` / `deserialize_i64` / `deserialize_i128`.
    Positive(x) => @serde.Data::from_u64(x)
    Negative(x) => int_data(true, @bigint.BigInt::from_uint64(x))
    // `deserialize_bytes` / `deserialize_byte_buf`.
    Bytes(Some(len)) if len <= scratch_len =>
      Bytes(self.read_exact(len).to_owned())
    Bytes(len) => {
      let buf = Buffer()
      for segment in self.byte_segments(len) {
        buf.write_bytesview(segment)
      }
      Bytes(buf.to_bytes())
    }
    // `deserialize_str` / `deserialize_string`.
    Text(Some(len)) if len <= scratch_len => {
      let offset = self.index
      guard @serde.decode_utf8(self.read_exact(len)) is Some(s) else {
        raise Syntax(offset - 1)
      }
      Str(s)
    }
    Text(len) => Str(self.text_segments(len))
    // `deserialize_seq`.
    Array(len) =>
      self.recurse(() => {
        let items = []
        let mut remaining = len
        while true {
          match remaining {
            Some(0) => break
            Some(x) => remaining = Some(x - 1)
            None =>
              match self.pull() {
                Break => break
                header => self.push(header)
              }
          }
          items.push(self.deserialize_any())
        }
        Seq(items)
      })
    // `deserialize_map`.
    Map(len) =>
      self.recurse(() => {
        let entries = []
        let mut remaining = len
        while true {
          match remaining {
            Some(0) => break
            Some(x) => remaining = Some(x - 1)
            None =>
              match self.pull() {
                Break => break
                header => self.push(header)
              }
          }
          let key = self.deserialize_str()
          let value = self.deserialize_any()
          entries.push((key, value))
        }
        Map(entries)
      })
    Tag(tag) => {
      // Peek at the next item. If it is bytes, capture the length.
      let next = self.pull()
      self.push(next)
      let len = match next {
        Bytes(x) => x
        _ => None
      }
      match len {
        Some(len) if (tag == tag_bigpos || tag == tag_bigneg) && len <= 16 => {
          let (neg, raw) = self.integer(Some(Tag(tag)))
          if neg &&
            raw >
            @bigint.BigInt::from_string(
              "170141183460469231731687303715884105727",
            ) {
            raise Semantic(None, "integer too large")
          }
          int_data(neg, raw)
        }
        // Typst's `ValueVisitor` does not implement `visit_enum`.
        _ =>
          self.recurse(() => {
            raise Semantic(
              None,
              @serde.invalid_type("enum", @serde.expecting_typst_value),
            )
          })
      }
    }
    // `deserialize_f64`.
    Float(x) => Float(x)
    // `deserialize_bool` / `deserialize_option`.
    Simple(20) => Bool(false)
    Simple(21) => Bool(true)
    Simple(22) | Simple(23) => None
    h =>
      raise h.expected(
        if h is Break {
          "non-break"
        } else {
          "known simple value"
        },
      )
  }
}

///|
/// Upstream `deserialize_str` for map keys (Typst's `Str` deserializes via
/// `EcoString`'s `deserialize_str`).
fn Deserializer::deserialize_str(self : Deserializer) -> String raise CborError {
  while true {
    let offset = self.index
    match self.pull() {
      Tag(_) => continue
      Text(Some(len)) if len <= scratch_len =>
        match @serde.decode_utf8(self.read_exact(len)) {
          Some(s) => return s
          None => raise Syntax(offset)
        }
      header => raise header.expected("str")
    }
  }
  panic()
}
