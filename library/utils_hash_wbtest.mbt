// `SipHasher128`'s writers for strings and short integers collect bytes
// into words themselves; they must hash what the byte-wise writers hash.

///|
/// `write_u8` as a byte of the stream, written out (the reference).
fn ref_write_u8(h : SipHasher128, b : Byte) -> Unit {
  h.tail = h.tail | (b.to_uint64() << (8 * h.ntail))
  h.ntail += 1
  h.length += 1
  if h.ntail == 8 {
    h.compress(h.tail)
    h.tail = 0
    h.ntail = 0
  }
}

///|
/// A string as its UTF-8 bytes followed by `0xff`.
fn ref_write_str(h : SipHasher128, s : String) -> Unit {
  for c in s {
    let code = c.to_int()
    if code < 0x80 {
      ref_write_u8(h, code.to_byte())
    } else if code < 0x800 {
      ref_write_u8(h, (0xc0 | (code >> 6)).to_byte())
      ref_write_u8(h, (0x80 | (code & 0x3f)).to_byte())
    } else if code < 0x10000 {
      ref_write_u8(h, (0xe0 | (code >> 12)).to_byte())
      ref_write_u8(h, (0x80 | ((code >> 6) & 0x3f)).to_byte())
      ref_write_u8(h, (0x80 | (code & 0x3f)).to_byte())
    } else {
      ref_write_u8(h, (0xf0 | (code >> 18)).to_byte())
      ref_write_u8(h, (0x80 | ((code >> 12) & 0x3f)).to_byte())
      ref_write_u8(h, (0x80 | ((code >> 6) & 0x3f)).to_byte())
      ref_write_u8(h, (0x80 | (code & 0x3f)).to_byte())
    }
  }
  ref_write_u8(h, b'\xff')
}

///|
test "SipHasher128: strings and short integers hash as their bytes" {
  let mut seed = 0x9E3779B97F4A7C15UL
  let next = () => {
    seed = seed ^ (seed << 13)
    seed = seed ^ (seed >> 7)
    seed = seed ^ (seed << 17)
    seed
  }
  let pieces = [
    "", "a", "ab", "abcdefg", "abcdefgh", "abcdefghi", "é", "aé", "éa", "abcdefgé",
    "abcdefghé", "日本語", "a日b本c語d", "😀", "abc😀def😀", "x\u{0}y",
    "\u{7f}\u{80}\u{7ff}\u{800}\u{ffff}\u{10000}", "the quick brown fox jumps over the lazy dog",
    "stroke-thickness", "naïve café",
  ]
  for round in 0..<400 {
    let a = SipHasher128::new()
    let b = SipHasher128::new()
    let steps = (next() % 12UL).to_int() + (if round < 20 { 0 } else { 1 })
    for _ in 0..<steps {
      let r = next()
      match (r % 5UL).to_int() {
        0 => {
          let byte = (r >> 8).to_byte()
          a.write_u8(byte)
          ref_write_u8(b, byte)
        }
        1 => {
          let v = (r >> 8).to_uint()
          a.write_u32(v)
          for i in 0..<4 {
            ref_write_u8(b, (v >> (8 * i)).to_byte())
          }
        }
        2 => {
          a.write_u64(r)
          for i in 0..<8 {
            ref_write_u8(b, (r >> (8 * i)).to_byte())
          }
        }
        3 => {
          let flag = ((r >> 8) & 1UL) == 1UL
          a.write_bool(flag)
          ref_write_u8(b, if flag { b'\x01' } else { b'\x00' })
        }
        _ => {
          // One piece, two joined, or a part of one.
          let p = pieces[((r >> 8) % pieces.length().to_uint64()).to_int()]
          let q = pieces[((r >> 24) % pieces.length().to_uint64()).to_int()]
          let text = if ((r >> 40) & 1UL) == 1UL { p + q } else { p }
          a.write_str(text)
          ref_write_str(b, text)
        }
      }
    }
    assert_eq(a.finish128(), b.finish128())
  }
  // A view into a string hashes as its text.
  let text = "0123456789éabcdefghij"
  for start in [0, 3, 11] {
    for len in [0, 1, 7, 8, 9] {
      let view = text[start:start + len]
      let a = SipHasher128::new()
      a.write_str(view)
      let b = SipHasher128::new()
      ref_write_str(b, view.to_owned())
      assert_eq(a.finish128(), b.finish128())
    }
  }
}

///|
test "SipHasher128: write_bytes hashes what a write_u8 per byte hashes" {
  let mut seed = 0xD1B54A32D192ED03UL
  let next = () => {
    seed = seed ^ (seed << 13)
    seed = seed ^ (seed >> 7)
    seed = seed ^ (seed << 17)
    seed
  }
  let data = Bytes::makei(96, _ => (next() >> 24).to_byte())
  // Every pending-word length before the bytes, every length, views at
  // every offset of a word, and more bytes after them.
  for before in 0..<9 {
    for offset in 0..<9 {
      for length in 0..<70 {
        let a = SipHasher128::new()
        let b = SipHasher128::new()
        for i in 0..<before {
          a.write_u8(data[i])
          ref_write_u8(b, data[i])
        }
        a.write_bytes(data[offset:offset + length])
        for i in offset..<(offset + length) {
          ref_write_u8(b, data[i])
        }
        a.write_u32(0xDEADBEEFU)
        for i in 0..<4 {
          ref_write_u8(b, (0xDEADBEEFU >> (8 * i)).to_byte())
        }
        assert_eq(a.finish128(), b.finish128())
      }
    }
  }
}
