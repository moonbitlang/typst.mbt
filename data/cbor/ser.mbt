// Port of the parts of `ciborium` 0.2.2 (`ser/mod.rs`) and `ciborium-ll`
// 0.2.2 (`enc.rs`, `hdr.rs`) used by `ciborium::into_writer` for Typst
// values. Collections always have a known length; floats use the shortest
// lossless encoding (half, single or double precision).

///|
/// Serialize a value into CBOR bytes (upstream `ciborium::into_writer`).
pub fn to_bytes(value : @serde.Data) -> Bytes {
  let buf = Buffer()
  write_value(buf, value)
  buf.to_bytes()
}

///|
/// Write a header with an integer argument in its shortest form (upstream
/// `impl From<Header> for Title`).
fn write_title(buf : Buffer, major : Int, arg : UInt64) -> Unit {
  let prefix = major << 5
  if arg <= 23UL {
    buf.write_byte((prefix | arg.to_int()).to_byte())
  } else if arg <= 0xFFUL {
    buf.write_byte((prefix | 24).to_byte())
    buf.write_byte(arg.to_byte())
  } else if arg <= 0xFFFFUL {
    buf.write_byte((prefix | 25).to_byte())
    write_be(buf, arg, 2)
  } else if arg <= 0xFFFF_FFFFUL {
    buf.write_byte((prefix | 26).to_byte())
    write_be(buf, arg, 4)
  } else {
    buf.write_byte((prefix | 27).to_byte())
    write_be(buf, arg, 8)
  }
}

///|
fn write_be(buf : Buffer, v : UInt64, n : Int) -> Unit {
  for i in 0..<n {
    let shift = (n - 1 - i) * 8
    buf.write_byte((v >> shift).to_byte())
  }
}

///|
fn write_value(buf : Buffer, value : @serde.Data) -> Unit {
  match value {
    // `serialize_none`.
    None => buf.write_byte(b'\xf6')
    // `serialize_bool`.
    Bool(false) => buf.write_byte(b'\xf4')
    Bool(true) => buf.write_byte(b'\xf5')
    // `serialize_i64`.
    Int(v) =>
      if v < 0L {
        write_title(buf, 1, (v ^ -1L).reinterpret_as_uint64())
      } else {
        write_title(buf, 0, v.reinterpret_as_uint64())
      }
    // `serialize_f64`.
    Float(v) => write_float(buf, v)
    // `serialize_str`.
    Str(s) => {
      let bytes = @utf8.encode(s)
      write_title(buf, 3, bytes.length().to_uint64())
      buf.write_bytes(bytes)
    }
    // `serialize_bytes`.
    Bytes(bytes) => {
      write_title(buf, 2, bytes.length().to_uint64())
      buf.write_bytes(bytes)
    }
    // `serialize_seq(Some(len))`.
    Seq(items) => {
      write_title(buf, 4, items.length().to_uint64())
      for item in items {
        write_value(buf, item)
      }
    }
    // `serialize_map(Some(len))`.
    Map(entries) => {
      write_title(buf, 5, entries.length().to_uint64())
      for entry in entries {
        let (key, value) = entry
        write_value(buf, Str(key))
        write_value(buf, value)
      }
    }
  }
}

///|
/// Write a float in the shortest encoding that preserves its bits.
fn write_float(buf : Buffer, v : Double) -> Unit {
  match f16_bits(v) {
    Some(bits) => {
      buf.write_byte(b'\xf9')
      write_be(buf, bits.to_uint64(), 2)
    }
    None => {
      let single = v.to_float()
      if single.to_double().reinterpret_as_uint64() == v.reinterpret_as_uint64() {
        buf.write_byte(b'\xfa')
        write_be(buf, single.reinterpret_as_uint().to_uint64(), 4)
      } else {
        buf.write_byte(b'\xfb')
        write_be(buf, v.reinterpret_as_uint64(), 8)
      }
    }
  }
}

///|
/// The bits of `v` as an IEEE half-precision float if the conversion
/// `f16::from_f64` round-trips bit-exactly through `f64::from`.
fn f16_bits(v : Double) -> Int? {
  let bits = v.reinterpret_as_uint64()
  let sign = if bits >> 63 != 0UL { 0x8000 } else { 0 }
  let exp = ((bits >> 52) & 0x7FFUL).to_int()
  let mant = bits & 0xF_FFFF_FFFF_FFFFUL
  if exp == 0x7FF {
    // Infinity or NaN: `half` keeps the top 10 mantissa bits (and sets the
    // quiet bit for NaNs); it round-trips if the dropped bits are zero.
    if mant == 0UL {
      return Some(sign | 0x7C00)
    }
    if (mant & 0x3FF_FFFF_FFFFUL) != 0UL {
      return None
    }
    let m = (mant >> 42).to_int()
    // A NaN whose payload would become zero gets the quiet bit; that does
    // not round-trip unless it was already set.
    let h = sign | 0x7C00 | 0x200 | m
    if (m | 0x200) != m {
      return None
    }
    return Some(h)
  }
  if exp == 0 && mant == 0UL {
    return Some(sign)
  }
  if exp == 0 {
    // Double subnormals are far too small for a half.
    return None
  }
  // The unbiased exponent.
  let e = exp - 1023
  if e > 15 || e < -24 {
    return None
  }
  if e >= -14 {
    // Normal half: 10 mantissa bits.
    if (mant & 0x3FF_FFFF_FFFFUL) != 0UL {
      return None
    }
    Some(sign | ((e + 15) << 10) | (mant >> 42).to_int())
  } else {
    // Subnormal half: value = m * 2^-24 with m < 1024.
    let shift = -14 - e // 1..=10
    let full = mant | 0x10_0000_0000_0000UL // 53 bits with implicit one
    // The half mantissa keeps the top (11 - shift) bits of `full`.
    let drop = 42 + shift
    if (full & ((1UL << drop) - 1UL)) != 0UL {
      return None
    }
    Some(sign | (full >> drop).to_int())
  }
}
