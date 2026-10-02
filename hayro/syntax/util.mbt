// Port of `hayro-syntax/src/util.rs`.

///|
let scalar_nearly_zero : Float = 1.0 / 4096.0

///|
/// Whether the number is approximately 0.
pub fn is_nearly_zero(x : Float) -> Bool {
  x.abs() <= scalar_nearly_zero
}

///|
/// Whether `data` contains the byte `b`.
pub fn bytes_contain(data : BytesView, b : Byte) -> Bool {
  for x in data {
    if x == b {
      return true
    }
  }
  false
}

///|
/// Find the first occurrence of `needle` in `haystack`.
pub fn find_needle(haystack : BytesView, needle : Bytes) -> Int? {
  if needle.length() == 0 {
    return Some(0)
  }
  let n = needle.length()
  let first = needle[0]
  let mut i = 0
  while i + n <= haystack.length() {
    if haystack[i] == first {
      let mut ok = true
      for j in 1..<n {
        if haystack[i + j] != needle[j] {
          ok = false
          break
        }
      }
      if ok {
        return Some(i)
      }
    }
    i += 1
  }
  None
}

///|
/// Find the last occurrence of `needle` in `haystack`.
pub fn findr_needle(haystack : BytesView, needle : Bytes) -> Int? {
  if needle.length() == 0 {
    return Some(haystack.length())
  }
  let n = needle.length()
  if n > haystack.length() {
    return None
  }
  let mut i = haystack.length() - n
  while i >= 0 {
    let mut ok = true
    for j in 0..<n {
      if haystack[i + j] != needle[j] {
        ok = false
        break
      }
    }
    if ok {
      return Some(i)
    }
    i -= 1
  }
  None
}

///|
/// Decode a latin-1 string (each char is a byte) into bytes.
pub fn latin1_bytes(s : String) -> Bytes {
  Bytes::makei(s.length(), i => s.code_unit_at(i).to_byte())
}

///|
/// Encode bytes as a latin-1 string (each byte becomes a char).
pub fn latin1_string(b : BytesView) -> String {
  let sb = StringBuilder::new(size_hint=b.length())
  for byte in b {
    sb.write_char(byte.to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Compare two latin-1 strings by their bytes (Rust `[u8]` order).
pub fn compare_latin1(a : String, b : String) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let c = a.code_unit_at(i).to_int() - b.code_unit_at(i).to_int()
    if c != 0 {
      return c
    }
  }
  a.length() - b.length()
}
