// Emulation of `icu_collator::Collator::compare` for the root locale with
// default options, as used by hayagriva's sorting (`csl/sort.rs`).
//
// The per-code-point data in `collation_gen.mbt` is extracted from
// `icu_collator` by `oracle/src/bin/gen_collation.rs`, which also validates
// this algorithm against the real collator. Strings are compared level by
// level: primary weights are concatenated while emulating ICU's primary
// lead-byte compression; secondary and tertiary weights are compared
// uncompressed (which orders the same as ICU's compressed sort keys).
// Contractions and canonical reordering across characters are not modelled;
// code points outside the table get implicit weights.

///|
priv struct CollEntry {
  first : Int?
  rest : Bytes
  end : Int?
  sec : Bytes
  ter : Bytes
}

///|
fn coll_digit(c : Char) -> Int {
  let c = c.to_int()
  if c >= '0'.to_int() && c <= '9'.to_int() {
    c - '0'.to_int()
  } else {
    c - 'A'.to_int() + 10
  }
}

///|
fn coll_hex(s : String) -> Bytes {
  if s == "-" {
    return b""
  }
  let digit = coll_digit
  let chars = s.to_array()
  Bytes::makei(chars.length() / 2, i => {
    (digit(chars[2 * i]) * 16 + digit(chars[2 * i + 1])).to_byte()
  })
}

///|
fn coll_hex_opt(s : String) -> Int? {
  if s == "-" {
    None
  } else {
    Some(coll_hex(s)[0].to_int())
  }
}

///|
let collation_table : Ref[Map[Int, CollEntry]?] = { val: None, }

///|
fn collation_table_get() -> Map[Int, CollEntry] {
  match collation_table.val {
    Some(t) => t
    None => {
      let t = Map([])
      for line in collation_table_data.split("\n") {
        let parts = line.split(" ").map(p => p.to_owned()).collect()
        if parts.length() != 6 {
          continue
        }
        let mut cp = 0
        for c in parts[0] {
          cp = cp * 16 + coll_digit(c)
        }
        t.set(cp, {
          first: coll_hex_opt(parts[1]),
          rest: coll_hex(parts[2]),
          end: coll_hex_opt(parts[3]),
          sec: coll_hex(parts[4]),
          ter: coll_hex(parts[5]),
        })
      }
      collation_table.val = Some(t)
      t
    }
  }
}

///|
fn coll_is_han(cp : Int) -> Bool {
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  (cp >= 0xF900 && cp <= 0xFAFF) ||
  (cp >= 0x20000 && cp <= 0x3FFFF)
}

///|
/// Implicit weights for code points outside the table.
fn coll_fallback(cp : Int) -> CollEntry {
  {
    first: Some(if coll_is_han(cp) { 0xFA } else { 0xF0 }),
    rest: Bytes::from_array([
      ((cp >> 16) + 2).to_byte(),
      ((cp >> 8) | 1).to_byte(),
      (cp | 1).to_byte(),
    ]),
    end: None,
    sec: b"\x05",
    ter: b"\x05",
  }
}

///|
fn coll_key(s : String) -> (Bytes, Bytes, Bytes) {
  let table = collation_table_get()
  let p = Buffer()
  let sec = Buffer()
  let ter = Buffer()
  let mut prev : Int? = None
  let decomposed = []
  for ch in s {
    let cp = ch.to_int()
    if cp >= 0xAC00 && cp <= 0xD7A3 {
      // Hangul syllables decompose algorithmically into jamo.
      let si = cp - 0xAC00
      decomposed.push(0x1100 + si / 588)
      decomposed.push(0x1161 + si % 588 / 28)
      if si % 28 != 0 {
        decomposed.push(0x11A7 + si % 28)
      }
    } else {
      decomposed.push(cp)
    }
  }
  for cp in decomposed {
    let e = match table.get(cp) {
      Some(e) => e
      None => coll_fallback(cp)
    }
    if e.first is Some(first) {
      if prev == Some(first) {
        p.write_bytes(e.rest)
      } else {
        if prev is Some(pl) {
          if first < pl {
            if first > 2 {
              p.write_byte(b'\x03')
            }
          } else {
            p.write_byte(b'\xff')
          }
        }
        p.write_byte(first.to_byte())
        p.write_bytes(e.rest)
      }
      prev = e.end
    }
    sec.write_bytes(e.sec)
    ter.write_bytes(e.ter)
  }
  (p.to_bytes(), sec.to_bytes(), ter.to_bytes())
}

///|
fn coll_cmp_bytes(a : Bytes, b : Bytes) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] != b[i] {
      return if a[i] < b[i] { -1 } else { 1 }
    }
  }
  compare_int(a.length(), b.length())
}

///|
/// Compare two strings with the ICU root collation (tertiary strength).
fn root_collation_compare(a : String, b : String) -> Int {
  let (pa, sa, ta) = coll_key(a)
  let (pb, sb, tb) = coll_key(b)
  let c = coll_cmp_bytes(pa, pb)
  if c != 0 {
    return c
  }
  let c = coll_cmp_bytes(sa, sb)
  if c != 0 {
    return c
  }
  coll_cmp_bytes(ta, tb)
}
