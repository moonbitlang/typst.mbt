// Port of `typst-svg/src/write.rs`: a thin layer over `xmlwriter` for
// writing SVG elements and attributes, plus the number formatting shared by
// all SVG output.
//
// Upstream's `SvgElem`/`LazySvgElem` close their element on `Drop`; here the
// element must be closed explicitly with `end`/`finish`.

///|
/// An SVG element that is being written.
pub struct SvgElem {
  priv xml : @xmlwriter.XmlWriter
}

///|
/// Starts a new element.
pub fn SvgElem::new(xml : @xmlwriter.XmlWriter, name : String) -> SvgElem {
  xml.start_element(name)
  { xml, }
}

///|
/// Starts a child element. It must be closed with [SvgElem::end].
pub fn SvgElem::elem(self : SvgElem, name : String) -> SvgElem {
  SvgElem::new(self.xml, name)
}

///|
/// Creates a [LazySvgElem].
pub fn SvgElem::lazy_elem(self : SvgElem, name : String) -> LazySvgElem {
  LazySvgElem::new(self, name)
}

///|
/// Write an SVG attribute.
pub fn[T : SvgDisplay] SvgElem::attr(
  self : SvgElem,
  name : String,
  value : T,
) -> SvgElem {
  self.attr_with(name, attr => value.fmt(attr))
}

///|
/// Write an SVG attribute, to an [SvgFormatter].
pub fn SvgElem::attr_with(
  self : SvgElem,
  name : String,
  fmt : (SvgFormatter) -> Unit,
) -> SvgElem {
  // `xmlwriter`'s `write_attribute_raw`: the formatter escapes `&` and `<`,
  // the writer escapes the quotation mark.
  let f = SvgFormatter::new()
  fmt(f)
  self.xml.write_attribute(name, f.buf.to_string())
  self
}

///|
/// Closes the element (upstream `Drop`).
pub fn SvgElem::end(self : SvgElem) -> Unit {
  self.xml.end_element()
}

///|
/// Allows deferring the creation of a children element.
pub struct LazySvgElem {
  priv inner : SvgElem
  priv mut initialized : Bool
  priv name : String
}

///|
pub fn LazySvgElem::new(parent : SvgElem, name : String) -> LazySvgElem {
  { inner: parent, initialized: false, name, }
}

///|
/// Initialize the child element, if not already present.
pub fn LazySvgElem::init(self : LazySvgElem) -> SvgElem {
  if !self.initialized {
    self.inner.xml.start_element(self.name)
    self.initialized = true
  }
  self.inner
}

///|
/// Either get the child element, if it has been initialized, otherwise get
/// the parent.
pub fn LazySvgElem::lazy_(self : LazySvgElem) -> SvgElem {
  self.inner
}

///|
/// Closes the element if it was initialized (upstream `Drop`).
pub fn LazySvgElem::finish(self : LazySvgElem) -> Unit {
  if self.initialized {
    self.inner.xml.end_element()
  }
}

///|
/// Writes SVG attribute values or path data (upstream `SvgWrite` with the
/// `SvgFormatter` implementations).
///
/// When writing, the XML metacharacters `&` and `<` are escaped (the writer
/// itself only escapes the quotation mark). Otherwise a value such as a link
/// URL containing `&` or `<` yields malformed SVG.
pub struct SvgFormatter {
  priv buf : StringBuilder
}

///|
pub fn SvgFormatter::new() -> SvgFormatter {
  { buf: StringBuilder(), }
}

///|
/// The written text.
pub fn SvgFormatter::to_string(self : SvgFormatter) -> String {
  self.buf.to_string()
}

///|
/// Write a string, escaping XML metacharacters.
pub fn SvgFormatter::push_str(self : SvgFormatter, value : String) -> Unit {
  // Copy runs without metacharacters at once (performance).
  let mut start = 0
  for i in 0..<value.length() {
    let c = value.unsafe_get(i)
    if c == '&' || c == '<' {
      if start < i {
        self.buf.write_view(value.view(start_offset=start, end_offset=i))
      }
      self.buf.write_string(if c == '&' { "&amp;" } else { "&lt;" })
      start = i + 1
    }
  }
  if start == 0 {
    self.buf.write_string(value)
  } else if start < value.length() {
    self.buf.write_view(value.view(start_offset=start))
  }
}

///|
/// Write a character, escaping XML metacharacters.
pub fn SvgFormatter::push_char(self : SvgFormatter, value : Char) -> Unit {
  match value {
    '&' => self.buf.write_string("&amp;")
    '<' => self.buf.write_string("&lt;")
    _ => self.buf.write_char(value)
  }
}

///|
/// Write a number.
///
/// Numbers are rounded to nine decimal places to make them more deterministic
/// and to reduce the file size. Integers are written without a fractional
/// part (`itoa`), other numbers in the shortest round-trip representation
/// (`ryu`).
pub fn SvgFormatter::push_num(self : SvgFormatter, num : Double) -> Unit {
  self.buf.write_string(format_num(num))
}

///|
/// Write an integer.
pub fn SvgFormatter::push_int(self : SvgFormatter, num : Int64) -> Unit {
  self.buf.write_string(num.to_string())
}

///|
/// Convenience method to write a list of space separated numbers.
pub fn SvgFormatter::push_nums(
  self : SvgFormatter,
  nums : ArrayView[Double],
) -> Unit {
  for i, num in nums {
    if i > 0 {
      self.push_str(" ")
    }
    self.push_num(num)
  }
}

///|
/// Write a value that implements [SvgDisplay].
pub fn[T : SvgDisplay] SvgFormatter::push(
  self : SvgFormatter,
  value : T,
) -> Unit {
  value.fmt(self)
}

///|
/// Formats a number like upstream's `SvgWrite::push_num`.
pub fn format_num(num : Double) -> String {
  let rounding_factor = 1.0e9
  let num = @library.rust_round(rounding_factor * num) / rounding_factor
  // `num == num as i64 as f64` (`as` saturates and maps NaN to zero).
  let as_int : Int64 = if num.is_nan() {
    0L
  } else if num >= 9223372036854775807.0 {
    9223372036854775807L
  } else if num <= -9223372036854775808.0 {
    -9223372036854775807L - 1L
  } else {
    num.to_int64()
  }
  if num == as_int.to_double() {
    return as_int.to_string()
  }
  ryu_format(num)
}

///|
/// The `ryu` crate's `Buffer::format` of a double (shortest round-trip
/// digits; exponent notation outside of `1e-5 <= |x| < 1e16`).
fn ryu_format(f : Double) -> String {
  if f.is_nan() {
    return "NaN"
  }
  if f.is_inf() {
    return if f > 0.0 { "inf" } else { "-inf" }
  }
  let buf = StringBuilder()
  let bits = f.reinterpret_as_uint64()
  if bits >> 63 != 0 {
    buf.write_char('-')
  }
  let f = f.abs()
  if f == 0.0 {
    buf.write_string("0.0")
    return buf.to_string()
  }
  // Extract the shortest digits and the decimal exponent from Rust's
  // `Display` (which uses the same shortest round-trip digits).
  let s = @library.rust_display_f64(f)
  let (int_part, frac_part) = match s.find(".") {
    Some(i) =>
      (
        s.unsafe_substring(start=0, end=i),
        s.unsafe_substring(start=i + 1, end=s.length()),
      )
    None => (s, "")
  }
  let all = int_part + frac_part
  let mut start = 0
  while start < all.length() && all.unsafe_get(start) == '0' {
    start += 1
  }
  let mut end = all.length()
  while end > start && all.unsafe_get(end - 1) == '0' {
    end -= 1
  }
  let mantissa = all.unsafe_substring(start~, end~)
  let length = mantissa.length()
  // `10^(kk-1) <= v < 10^kk`
  let kk = int_part.length() - start
  let k = kk - length
  if 0 <= k && kk <= 16 {
    // 1234e7 -> 12340000000.0
    buf.write_string(mantissa)
    for _ in length..<kk {
      buf.write_char('0')
    }
    buf.write_string(".0")
  } else if 0 < kk && kk <= 16 {
    // 1234e-2 -> 12.34
    buf.write_string(mantissa.unsafe_substring(start=0, end=kk))
    buf.write_char('.')
    buf.write_string(mantissa.unsafe_substring(start=kk, end=length))
  } else if -5 < kk && kk <= 0 {
    // 1234e-6 -> 0.001234
    buf.write_string("0.")
    for _ in 0..<-kk {
      buf.write_char('0')
    }
    buf.write_string(mantissa)
  } else if length == 1 {
    // 1e30
    buf.write_string(mantissa)
    buf.write_char('e')
    buf.write_string((kk - 1).to_string())
  } else {
    // 1234e30 -> 1.234e33
    buf.write_string(mantissa.unsafe_substring(start=0, end=1))
    buf.write_char('.')
    buf.write_string(mantissa.unsafe_substring(start=1, end=length))
    buf.write_char('e')
    buf.write_string((kk - 1).to_string())
  }
  buf.to_string()
}

///|
/// A value that can be written as (part of) an SVG attribute.
pub(open) trait SvgDisplay {
  fn fmt(Self, SvgFormatter) -> Unit
}

///|
pub impl SvgDisplay for Char with fn fmt(self, f) {
  f.push_char(self)
}

///|
pub impl SvgDisplay for String with fn fmt(self, f) {
  f.push_str(self)
}

///|
pub impl SvgDisplay for Double with fn fmt(self, f) {
  f.push_num(self)
}

///|
/// Displays as an SVG transform. The exact representation is chosen based on
/// the specific transform. Either `matrix`, `scale`, or `translate` is used.
///
/// See <https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/transform>
pub(all) struct SvgTransform(@library.Transform)

///|
pub impl SvgDisplay for SvgTransform with fn fmt(self, f) {
  let SvgTransform(ts) = self
  let sx = ts.sx.get()
  let sy = ts.sy.get()
  let kx = ts.kx.get()
  let ky = ts.ky.get()
  let tx = ts.tx.to_pt()
  let ty = ts.ty.to_pt()
  if ts.is_only_scale() {
    f.push_str("scale(")
    if sx == sy {
      f.push_num(sx)
    } else {
      f.push_nums([sx, sy])
    }
    f.push_str(")")
  } else if ts.is_only_translate() {
    f.push_str("translate(")
    if ty == 0.0 {
      f.push_num(tx)
    } else {
      f.push_nums([tx, ty])
    }
    f.push_str(")")
  } else {
    f.push_str("matrix(")
    f.push_nums([sx, ky, kx, sy, tx, ty])
    f.push_str(")")
  }
}

///|
/// An SVG URL.
pub(all) struct SvgUrl(DedupId)

///|
pub impl SvgDisplay for SvgUrl with fn fmt(self, f) {
  let SvgUrl(id) = self
  f.push_str("url(#")
  f.push(id)
  f.push_str(")")
}

///|
/// A referenced SVG ID.
pub(all) struct SvgIdRef(DedupId)

///|
pub impl SvgDisplay for SvgIdRef with fn fmt(self, f) {
  let SvgIdRef(id) = self
  f.push_str("#")
  f.push(id)
}
