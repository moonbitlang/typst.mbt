// Port of the parts of `data-url` 0.3 (`src/lib.rs`, `src/mime.rs`,
// `src/forgiving_base64.rs`) that usvg uses: `DataUrl::process`,
// `DataUrl::mime_type` (type and subtype only; parameters do not affect
// them) and `DataUrl::decode_to_vec`. Works on the UTF-8 bytes of the input
// like upstream.

///|
priv struct DataUrl {
  mime_type : (String, String)
  base64 : Bool
  encoded_body_plus_fragment : Bytes
}

///|
fn DataUrl::process(input : String) -> DataUrl? {
  let input = @utf8.encode(input)
  guard pretend_parse_data_url(input) is Some(after_colon) else { return None }
  guard find_comma_before_fragment(after_colon)
    is Some((from_colon_to_comma, encoded_body_plus_fragment)) else {
    return None
  }
  let (mime_type, base64) = parse_data_url_header(from_colon_to_comma)
  Some({ mime_type, base64, encoded_body_plus_fragment, })
}

///|
fn is_ascii_ws_or_ctrl(b : Byte) -> Bool {
  b <= b' '
}

///|
fn pretend_parse_data_url(input : Bytes) -> Bytes? {
  let n = input.length()
  let mut start = 0
  while start < n && is_ascii_ws_or_ctrl(input[start]) {
    start += 1
  }
  let expected : ReadOnlyArray[_] = [b'd', b'a', b't', b'a', b':']
  let mut i = start
  let mut k = 0
  while k < 5 {
    if i >= n {
      return None
    }
    let b = input[i]
    i += 1
    if b is (b'\t' | b'\n' | b'\r') {
      continue
    }
    let lower = if b >= b'A' && b <= b'Z' { b + 32 } else { b }
    if k < 4 {
      if lower != expected[k] {
        return None
      }
    } else if b != b':' {
      return None
    }
    k += 1
  }
  let mut end = n
  while end > i && is_ascii_ws_or_ctrl(input[end - 1]) {
    end -= 1
  }
  Some(input[i:end].to_bytes())
}

///|
fn find_comma_before_fragment(after_colon : Bytes) -> (Bytes, Bytes)? {
  for i in 0..<after_colon.length() {
    let byte = after_colon[i]
    if byte == b',' {
      return Some((after_colon[0:i].to_bytes(), after_colon[i + 1:].to_bytes()))
    }
    if byte == b'#' {
      break
    }
  }
  None
}

///|
fn parse_data_url_header(
  from_colon_to_comma : Bytes,
) -> ((String, String), Bool) {
  let n = from_colon_to_comma.length()
  let mut s = 0
  let mut e = n
  while s < e && from_colon_to_comma[s] is (b' ' | b'\t' | b'\n' | b'\r') {
    s += 1
  }
  while e > s && from_colon_to_comma[e - 1] is (b' ' | b'\t' | b'\n' | b'\r') {
    e -= 1
  }
  let trimmed = from_colon_to_comma[s:e].to_bytes()
  let without_base64_suffix = remove_base64_suffix(trimmed)
  let base64 = without_base64_suffix is Some(_)
  let mime_type = without_base64_suffix.unwrap_or(trimmed)
  let string = StringBuilder::new()
  if mime_type.length() > 0 && mime_type[0] == b';' {
    string.write_string("text/plain")
  }
  let mut in_query = false
  for byte in mime_type {
    match byte {
      b'\t' | b'\n' | b'\r' => continue
      b'\x00'..=b'\x1F' | b'\x7F'..=b'\xFF' => percent_encode_byte(byte, string)
      b' ' | b'"' | b'<' | b'>' if in_query => percent_encode_byte(byte, string)
      b'?' => {
        in_query = true
        string.write_char('?')
      }
      _ => string.write_char(byte.to_int().unsafe_to_char())
    }
  }
  let mime_type = match parse_mime(string.to_string()) {
    Some(m) => m
    None => ("text", "plain")
  }
  (mime_type, base64)
}

///|
fn remove_base64_suffix(s : Bytes) -> Bytes? {
  // Iterate from the back, skipping tabs and newlines.
  let mut i = s.length()
  let next = () => {
    while i > 0 {
      i -= 1
      let b = s[i]
      if !(b is (b'\t' | b'\n' | b'\r')) {
        return Some(b)
      }
    }
    None
  }
  let lower = (b : Byte) => if b >= b'A' && b <= b'Z' { b + 32 } else { b }
  if next() != Some(b'4') {
    return None
  }
  if next() != Some(b'6') {
    return None
  }
  if next().map(lower) != Some(b'e') {
    return None
  }
  if next().map(lower) != Some(b's') {
    return None
  }
  if next().map(lower) != Some(b'a') {
    return None
  }
  if next().map(lower) != Some(b'b') {
    return None
  }
  let mut b = next()
  while b == Some(b' ') {
    b = next()
  }
  if b != Some(b';') {
    return None
  }
  Some(s[0:i].to_bytes())
}

///|
fn percent_encode_byte(byte : Byte, string : StringBuilder) -> Unit {
  let hex = "0123456789ABCDEF"
  string.write_char('%')
  string.write_char(hex.unsafe_get((byte >> 4).to_int()).unsafe_to_char())
  string.write_char(hex.unsafe_get((byte & 0x0F).to_int()).unsafe_to_char())
}

///|
fn is_http_whitespace(c : Char) -> Bool {
  c is (' ' | '\t' | '\n' | '\r')
}

///|
fn is_http_token_code_point(c : Char) -> Bool {
  c
  is ('!'
  | '#'..='\''
  | '*'
  | '+'
  | '-'
  | '.'
  | '0'..='9'
  | 'A'..='Z'
  | '^'..='z'
  | '|'
  | '~')
}

///|
/// `mime::parse`, returning `(type, subtype)` (lowercased).
fn parse_mime(s : String) -> (String, String)? {
  let chars = s.to_array()
  let mut a = 0
  let mut b = chars.length()
  while a < b && is_http_whitespace(chars[a]) {
    a += 1
  }
  while b > a && is_http_whitespace(chars[b - 1]) {
    b -= 1
  }
  let trimmed = chars[a:b]
  let slash = trimmed.search('/')
  let type_ = match slash {
    Some(i) => trimmed[0:i]
    None => trimmed
  }
  if type_.is_empty() || !type_.iter().all(is_http_token_code_point) {
    return None
  }
  let rest = match slash {
    Some(i) => trimmed[i + 1:]
    None => return None
  }
  let subtype = match rest.search(';') {
    Some(i) => rest[0:i]
    None => rest
  }
  let mut e = subtype.length()
  while e > 0 && is_http_whitespace(subtype[e - 1]) {
    e -= 1
  }
  let subtype = subtype[0:e]
  if subtype.is_empty() || !subtype.iter().all(is_http_token_code_point) {
    return None
  }
  Some(
    (
      String::from_iter(type_.iter()).to_lower(),
      String::from_iter(subtype.iter()).to_lower(),
    ),
  )
}

///|
/// `DataUrl::decode_to_vec`; `None` for invalid base64.
fn DataUrl::decode_to_vec(self : DataUrl) -> Bytes? {
  let body = @buffer.new()
  if self.base64 {
    let decoder = ForgivingBase64Decoder::new(body)
    let mut ok = true
    decode_without_base64(self.encoded_body_plus_fragment, bytes => {
      if ok && !decoder.feed(bytes) {
        ok = false
      }
    })
    if !ok || !decoder.finish() {
      return None
    }
  } else {
    decode_without_base64(self.encoded_body_plus_fragment, bytes => {
      body.write_bytesview(bytes)
    })
  }
  Some(body.to_bytes())
}

///|
fn hex_digit(b : Byte) -> Int? {
  match b {
    b'0'..=b'9' => Some((b - b'0').to_int())
    b'a'..=b'f' => Some((b - b'a').to_int() + 10)
    b'A'..=b'F' => Some((b - b'A').to_int() + 10)
    _ => None
  }
}

///|
fn decode_without_base64(
  encoded_body_plus_fragment : Bytes,
  write_bytes : (BytesView) -> Unit,
) -> Unit {
  let bytes = encoded_body_plus_fragment
  let mut slice_start = 0
  for i in 0..<bytes.length() {
    let byte = bytes[i]
    if byte is (b'%' | b'#' | b'\t' | b'\n' | b'\r') {
      if i > slice_start {
        write_bytes(bytes[slice_start:i])
        slice_start = i
      }
      match byte {
        b'%' => {
          let l = if i + 2 < bytes.length() {
            hex_digit(bytes[i + 2])
          } else {
            None
          }
          let h = if i + 1 < bytes.length() {
            hex_digit(bytes[i + 1])
          } else {
            None
          }
          if (h, l) is (Some(h), Some(l)) {
            let one_byte = (h * 16 + l).to_byte()
            write_bytes(Bytes::from_array([one_byte])[:])
            slice_start = i + 3
          } else {
            // Do nothing. Leave slice_start unchanged.
            // The % sign will be part of the next slice.
          }
        }
        b'#' =>
          // The fragment is not needed.
          return
        _ => slice_start = i + 1
      }
    }
  }
  write_bytes(bytes[slice_start:])
}

///|
priv struct ForgivingBase64Decoder {
  out : @buffer.Buffer
  mut bit_buffer : UInt
  mut buffer_bit_length : Int
  mut padding_symbols : Int
}

///|
fn ForgivingBase64Decoder::new(out : @buffer.Buffer) -> ForgivingBase64Decoder {
  { out, bit_buffer: 0, buffer_bit_length: 0, padding_symbols: 0, }
}

///|
fn base64_decode_value(byte : Byte) -> Int {
  match byte {
    b'A'..=b'Z' => (byte - b'A').to_int()
    b'a'..=b'z' => (byte - b'a').to_int() + 26
    b'0'..=b'9' => (byte - b'0').to_int() + 52
    b'+' => 62
    b'/' => 63
    _ => -1
  }
}

///|
fn ForgivingBase64Decoder::feed(
  self : ForgivingBase64Decoder,
  input : BytesView,
) -> Bool {
  for byte in input {
    let value = base64_decode_value(byte)
    if value < 0 {
      // A character that’s not part of the alphabet

      // Remove ASCII whitespace
      if byte is (b' ' | b'\t' | b'\n' | b'\r' | b'\x0C') {
        continue
      }
      if byte == b'=' {
        self.padding_symbols = if self.padding_symbols < 255 {
          self.padding_symbols + 1
        } else {
          255
        }
        continue
      }
      return false
    }
    if self.padding_symbols > 0 {
      return false
    }
    self.bit_buffer = (self.bit_buffer << 6) | value.reinterpret_as_uint()
    if self.buffer_bit_length < 18 {
      self.buffer_bit_length += 6
    } else {
      // We’ve accumulated four times 6 bits, which equals three times 8 bits.
      self.out.write_byte((self.bit_buffer >> 16).to_byte())
      self.out.write_byte((self.bit_buffer >> 8).to_byte())
      self.out.write_byte(self.bit_buffer.to_byte())
      self.buffer_bit_length = 0
      // No need to reset bit_buffer,
      // since next time we’re only gonna read relevant bits.
    }
  }
  true
}

///|
fn ForgivingBase64Decoder::finish(self : ForgivingBase64Decoder) -> Bool {
  match (self.buffer_bit_length, self.padding_symbols) {
    (0, 0) => () // No data, no padding
    (12, 2) | (12, 0) => self.out.write_byte((self.bit_buffer >> 4).to_byte())
    (18, 1) | (18, 0) => {
      self.out.write_byte((self.bit_buffer >> 10).to_byte())
      self.out.write_byte((self.bit_buffer >> 2).to_byte())
    }
    (6, _) => return false
    _ => return false
  }
  true
}
