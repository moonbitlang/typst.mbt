// A port of the parts of the `url` crate (WHATWG URL parsing without a
// base) that hayagriva relies on: `Url::parse` and the serialization
// (`Display`). International domain names are lowercased and punycoded
// without the full UTS 46 mapping.

///|
/// A parsed, serialized URL.
pub(all) struct Url {
  /// The serialization of the URL.
  serialization : String
} derive(Eq, Hash, Debug)

///|
pub impl Show for Url with fn output(self, logger) {
  logger.write_string(self.serialization)
}

///|
/// Errors that can occur during parsing (`url::ParseError`).
pub(all) enum UrlParseError {
  EmptyHost
  IdnaError
  InvalidPort
  InvalidIpv4Address
  InvalidIpv6Address
  InvalidDomainCharacter
  RelativeUrlWithoutBase
} derive(Eq, Debug)

///|
pub impl Show for UrlParseError with fn output(self, logger) {
  logger.write_string(
    match self {
      EmptyHost => "empty host"
      IdnaError => "invalid international domain name"
      InvalidPort => "invalid port number"
      InvalidIpv4Address => "invalid IPv4 address"
      InvalidIpv6Address => "invalid IPv6 address"
      InvalidDomainCharacter => "invalid domain character"
      RelativeUrlWithoutBase => "relative URL without a base"
    },
  )
}

///|
pub extend UrlParseError with Show::{to_string, output}

///|
fn special_default_port(scheme : String) -> Int? {
  match scheme {
    "http" | "ws" => Some(80)
    "https" | "wss" => Some(443)
    "ftp" => Some(21)
    "file" => None
    _ => None
  }
}

///|
fn is_special_scheme(scheme : String) -> Bool {
  scheme is ("http" | "https" | "ws" | "wss" | "ftp" | "file")
}

///|
/// Percent-encode a char (as UTF-8) if `in_set` says so.
fn percent_encode_char(
  out : StringBuilder,
  c : Char,
  in_set : (Int) -> Bool,
) -> Unit {
  let n = c.to_int()
  if n < 0x80 {
    if in_set(n) {
      out.write_string("%" + hex2(n))
    } else {
      out.write_char(c)
    }
  } else {
    for b in @utf8.encode(c.to_string()) {
      out.write_string("%" + hex2(b.to_int()))
    }
  }
}

///|
fn hex2(n : Int) -> String {
  let digits = "0123456789ABCDEF"
  digits[n / 16:n / 16 + 1].to_owned() + digits[n % 16:n % 16 + 1].to_owned()
}

///|
fn c0_control(n : Int) -> Bool {
  n < 0x20 || n == 0x7F
}

///|
fn fragment_set(n : Int) -> Bool {
  c0_control(n) || n is (0x20 | 0x22 | 0x3C | 0x3E | 0x60)
}

///|
fn query_set(n : Int) -> Bool {
  c0_control(n) || n is (0x20 | 0x22 | 0x23 | 0x3C | 0x3E)
}

///|
fn special_query_set(n : Int) -> Bool {
  query_set(n) || n == 0x27
}

///|
fn path_set(n : Int) -> Bool {
  query_set(n) || n is (0x3F | 0x60 | 0x7B | 0x7D)
}

///|
fn userinfo_set(n : Int) -> Bool {
  path_set(n) ||
  n is (0x2F | 0x3A | 0x3B | 0x3D | 0x40 | 0x5B | 0x5C | 0x5D | 0x5E | 0x7C)
}

///|
/// Parse an absolute URL.
pub fn Url::parse(input : String) -> Result[Url, UrlParseError] {
  // Remove leading and trailing C0 control or space, and all ASCII tab or
  // newline.
  let cs = @unscanny.chars(input)
  let mut a = 0
  let mut b = cs.length()
  while a < b && cs[a].to_int() <= 0x20 {
    a += 1
  }
  while b > a && cs[b - 1].to_int() <= 0x20 {
    b -= 1
  }
  let chars = []
  for i in a..<b {
    let c = cs[i]
    if c is ('\t' | '\n' | '\r') {
      continue
    }
    chars.push(c)
  }
  // Scheme.
  let mut i = 0
  if chars.is_empty() || !chars[0].is_ascii_alphabetic() {
    return Err(RelativeUrlWithoutBase)
  }
  while i < chars.length() &&
        (
          chars[i].is_ascii_alphabetic() ||
          chars[i].is_ascii_digit() ||
          chars[i] is ('+' | '-' | '.')
        ) {
    i += 1
  }
  if i >= chars.length() || chars[i] != ':' {
    return Err(RelativeUrlWithoutBase)
  }
  let scheme = @unscanny.to_ascii_lowercase(String::from_array(chars[0:i]))
  i += 1
  let special = is_special_scheme(scheme)
  let out = StringBuilder()
  out.write_string(scheme)
  out.write_char(':')
  let rest = chars[i:].to_owned()
  let is_slash = (c : Char) => c == '/' || (special && c == '\\')
  let mut pos = 0
  let has_authority = if special {
    // Skip any number of slashes.
    while pos < rest.length() && is_slash(rest[pos]) {
      pos += 1
    }
    true
  } else if rest.length() >= 2 && rest[0] == '/' && rest[1] == '/' {
    pos = 2
    true
  } else {
    false
  }
  if has_authority {
    out.write_string("//")
    // The authority ends at `/`, `?`, `#` (and `\` for special schemes).
    let mut end = pos
    while end < rest.length() &&
          !(is_slash(rest[end]) || rest[end] is ('?' | '#')) {
      end += 1
    }
    let authority = rest[pos:end].to_owned()
    pos = end
    // Userinfo.
    let mut at = -1
    for k, c in authority {
      if c == '@' {
        at = k
      }
    }
    let host_part = if at >= 0 {
      let userinfo = authority[0:at].to_owned()
      let mut colon = -1
      for k, c in userinfo {
        if c == ':' && colon < 0 {
          colon = k
        }
      }
      let user = if colon >= 0 {
        userinfo[0:colon].to_owned()
      } else {
        userinfo
      }
      let pass = if colon >= 0 { userinfo[colon + 1:].to_owned() } else { [] }
      if !user.is_empty() || !pass.is_empty() {
        for c in user {
          percent_encode_char(out, c, userinfo_set)
        }
        if !pass.is_empty() {
          out.write_char(':')
          for c in pass {
            percent_encode_char(out, c, userinfo_set)
          }
        }
        out.write_char('@')
      }
      authority[at + 1:].to_owned()
    } else {
      authority
    }
    // Host and port.
    let mut colon = -1
    let mut in_brackets = false
    for k, c in host_part {
      if c == '[' {
        in_brackets = true
      } else if c == ']' {
        in_brackets = false
      } else if c == ':' && !in_brackets {
        colon = k
        break
      }
    }
    let host_chars = if colon >= 0 {
      host_part[0:colon].to_owned()
    } else {
      host_part
    }
    let port_chars = if colon >= 0 {
      host_part[colon + 1:].to_owned()
    } else {
      []
    }
    if special && host_chars.is_empty() && scheme != "file" {
      return Err(EmptyHost)
    }
    match parse_host(String::from_array(host_chars), special) {
      Ok(h) => out.write_string(h)
      Err(e) => return Err(e)
    }
    if !port_chars.is_empty() {
      if !port_chars.iter().all(c => c.is_ascii_digit()) {
        return Err(InvalidPort)
      }
      let port = match @unscanny.parse_u32(String::from_array(port_chars)) {
        Some(p) if p <= 65535L => p.to_int()
        _ => return Err(InvalidPort)
      }
      if special_default_port(scheme) != Some(port) {
        out.write_string(":\{port}")
      }
    }
  }
  // Path.
  let mut path_end = pos
  while path_end < rest.length() && !(rest[path_end] is ('?' | '#')) {
    path_end += 1
  }
  let path = rest[pos:path_end].to_owned()
  pos = path_end
  if !has_authority && (path.is_empty() || path[0] != '/') {
    // Cannot-be-a-base URL: opaque path.
    for c in path {
      percent_encode_char(out, c, c0_control)
    }
  } else {
    let segments : Array[String] = []
    let path = if !path.is_empty() && is_slash(path[0]) {
      path[1:].to_owned()
    } else {
      path
    }
    let mut seg = StringBuilder()
    let mut seg_raw = StringBuilder()
    let flush = (last : Bool) => {
      let raw = @unscanny.to_ascii_lowercase(seg_raw.to_string())
      let s = seg.to_string()
      seg = StringBuilder()
      seg_raw = StringBuilder()
      if raw == ".." || raw == ".%2e" || raw == "%2e." || raw == "%2e%2e" {
        if segments.length() > 0 {
          segments.pop() |> ignore
        }
        if last {
          segments.push("")
        }
      } else if raw == "." || raw == "%2e" {
        if last {
          segments.push("")
        }
      } else {
        segments.push(s)
      }
    }
    if !path.is_empty() || special || has_authority {
      for c in path {
        if is_slash(c) {
          flush(false)
        } else {
          seg_raw.write_char(c)
          percent_encode_char(seg, c, path_set)
        }
      }
      if !path.is_empty() || special {
        flush(true)
      }
    }
    for s in segments {
      out.write_char('/')
      out.write_string(s)
    }
  }
  // Query.
  if pos < rest.length() && rest[pos] == '?' {
    pos += 1
    out.write_char('?')
    while pos < rest.length() && rest[pos] != '#' {
      percent_encode_char(
        out,
        rest[pos],
        if special {
          special_query_set
        } else {
          query_set
        },
      )
      pos += 1
    }
  }
  // Fragment.
  if pos < rest.length() && rest[pos] == '#' {
    pos += 1
    out.write_char('#')
    while pos < rest.length() {
      percent_encode_char(out, rest[pos], fragment_set)
      pos += 1
    }
  }
  Ok({ serialization: out.to_string(), })
}

///|
fn is_forbidden_host_char(c : Char) -> Bool {
  c
  is ('\u{0}'
  | '\t'
  | '\n'
  | '\r'
  | ' '
  | '#'
  | '/'
  | ':'
  | '<'
  | '>'
  | '?'
  | '@'
  | '['
  | '\\'
  | ']'
  | '^'
  | '|')
}

///|
fn percent_decode(s : String) -> String {
  let bytes : Array[Byte] = []
  let hexval = (b : Byte) => {
    let n = b.to_int()
    if n >= '0'.to_int() && n <= '9'.to_int() {
      n - '0'.to_int()
    } else if n >= 'a'.to_int() && n <= 'f'.to_int() {
      n - 'a'.to_int() + 10
    } else if n >= 'A'.to_int() && n <= 'F'.to_int() {
      n - 'A'.to_int() + 10
    } else {
      -1
    }
  }
  let utf8 = @utf8.encode(s)
  let mut i = 0
  while i < utf8.length() {
    let b = utf8[i]
    if b == b'%' && i + 2 < utf8.length() {
      let h = hexval(utf8[i + 1])
      let l = hexval(utf8[i + 2])
      if h >= 0 && l >= 0 {
        bytes.push((h * 16 + l).to_byte())
        i += 3
        continue
      }
    }
    bytes.push(b)
    i += 1
  }
  @utf8.decode_lossy(Bytes::from_array(bytes))
}

///|
fn parse_host(input : String, special : Bool) -> Result[String, UrlParseError] {
  if input.has_prefix("[") {
    if !input.has_suffix("]") {
      return Err(InvalidIpv6Address)
    }
    return Ok(@unscanny.to_ascii_lowercase(input))
  }
  if !special {
    // Opaque host.
    let out = StringBuilder()
    for c in input {
      if is_forbidden_host_char(c) && c != '%' {
        return Err(InvalidDomainCharacter)
      }
      percent_encode_char(out, c, c0_control)
    }
    return Ok(out.to_string())
  }
  let domain = percent_decode(input)
  // Simplified domain to ASCII: lowercase and punycode non-ASCII labels.
  let ascii = domain_to_ascii(@unscanny.to_lowercase(domain))
  guard ascii is Some(ascii) else { return Err(IdnaError) }
  for c in ascii {
    if is_forbidden_host_char(c) ||
      c == '%' ||
      c.to_int() < 0x20 ||
      c == '\u{7f}' {
      return Err(InvalidDomainCharacter)
    }
  }
  if ascii.is_empty() {
    return Err(EmptyHost)
  }
  // IPv4: if the last label is numeric, parse as an IPv4 address.
  let labels = @unscanny.split(ascii, ".")
  let last = if labels.length() > 1 && labels[labels.length() - 1].is_empty() {
    labels[labels.length() - 2]
  } else {
    labels[labels.length() - 1]
  }
  if !last.is_empty() &&
    (
      last.iter().all(c => c.is_ascii_digit()) ||
      last.has_prefix("0x") ||
      last.has_prefix("0X")
    ) {
    return parse_ipv4(labels)
  }
  Ok(ascii)
}

///|
fn parse_ipv4_number(s : String) -> Int64? {
  if s.is_empty() {
    return None
  }
  let (digits, radix) = if s.has_prefix("0x") || s.has_prefix("0X") {
    (s[2:].to_owned(), 16)
  } else if s.length() > 1 && s.has_prefix("0") {
    (s[1:].to_owned(), 8)
  } else {
    (s, 10)
  }
  if digits.is_empty() {
    return Some(0L)
  }
  let mut v = 0L
  for c in digits {
    let d = if c.is_ascii_digit() {
      c.to_int() - '0'.to_int()
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 'a'.to_int() + 10
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 'A'.to_int() + 10
    } else {
      return None
    }
    if d >= radix {
      return None
    }
    v = v * radix.to_int64() + d.to_int64()
    if v > 0xFFFFFFFFFFL {
      return None
    }
  }
  Some(v)
}

///|
fn parse_ipv4(labels : Array[String]) -> Result[String, UrlParseError] {
  let labels = if labels.length() > 1 && labels[labels.length() - 1].is_empty() {
    labels[0:labels.length() - 1].to_owned()
  } else {
    labels
  }
  if labels.length() > 4 {
    return Err(InvalidIpv4Address)
  }
  let nums = []
  for l in labels {
    match parse_ipv4_number(l) {
      Some(n) => nums.push(n)
      None => return Err(InvalidIpv4Address)
    }
  }
  let mut ipv4 = 0L
  for k in 0..<(nums.length() - 1) {
    if nums[k] > 255L {
      return Err(InvalidIpv4Address)
    }
    ipv4 = ipv4 * 256L + nums[k]
  }
  let last = nums[nums.length() - 1]
  let remaining = 5 - nums.length()
  let mut limit = 1L
  for _ in 0..<remaining {
    limit *= 256L
  }
  if last >= limit {
    return Err(InvalidIpv4Address)
  }
  for _ in 0..<remaining {
    ipv4 *= 256L
  }
  ipv4 = ipv4 + last
  let parts = []
  for k in 0..<4 {
    let shift = (3 - k) * 8
    parts.push(((ipv4 >> shift) & 255L).to_string())
  }
  Ok(parts.join("."))
}

///|
/// Lowercased domain to ASCII: punycode-encode non-ASCII labels.
fn domain_to_ascii(domain : String) -> String? {
  let labels = @unscanny.split(domain, ".")
  let out = []
  for label in labels {
    if label.iter().all(c => c.to_int() < 0x80) {
      out.push(label)
    } else {
      match punycode_encode(label) {
        Some(p) => out.push("xn--" + p)
        None => return None
      }
    }
  }
  Some(out.join("."))
}

///|
/// RFC 3492 punycode encoding.
fn punycode_encode(input : String) -> String? {
  let base = 36
  let tmin = 1
  let tmax = 26
  let skew = 38
  let damp = 700
  let initial_bias = 72
  let initial_n = 128
  let cps = @unscanny.chars(input).map(c => c.to_int())
  let out = StringBuilder()
  let mut b = 0
  for c in cps {
    if c < 0x80 {
      out.write_char(Int::unsafe_to_char(c))
      b += 1
    }
  }
  let mut h = b
  if b > 0 {
    out.write_char('-')
  }
  let encode_digit = (d : Int) => {
    if d < 26 {
      Int::unsafe_to_char('a'.to_int() + d)
    } else {
      Int::unsafe_to_char('0'.to_int() + d - 26)
    }
  }
  let adapt = (delta0 : Int, numpoints : Int, first : Bool) => {
    let mut delta = if first { delta0 / damp } else { delta0 / 2 }
    delta += delta / numpoints
    let mut k = 0
    while delta > (base - tmin) * tmax / 2 {
      delta /= base - tmin
      k += base
    }
    k + (base - tmin + 1) * delta / (delta + skew)
  }
  let mut n = initial_n
  let mut delta = 0
  let mut bias = initial_bias
  while h < cps.length() {
    let mut m = 0x7FFFFFFF
    for c in cps {
      if c >= n && c < m {
        m = c
      }
    }
    delta += (m - n) * (h + 1)
    n = m
    for c in cps {
      if c < n {
        delta += 1
      }
      if c == n {
        let mut q = delta
        let mut k = base
        while true {
          let t = if k <= bias {
            tmin
          } else if k >= bias + tmax {
            tmax
          } else {
            k - bias
          }
          if q < t {
            break
          }
          out.write_char(encode_digit(t + (q - t) % (base - t)))
          q = (q - t) / (base - t)
          k += base
        }
        out.write_char(encode_digit(q))
        bias = adapt(delta, h + 1, h == b)
        delta = 0
        h += 1
      }
    }
    delta += 1
    n += 1
  }
  Some(out.to_string())
}
