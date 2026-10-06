// Port of `hayagriva/src/types/page.rs`.

///|
/// Ranges of page numbers, e.g., `1-4, 5 & 6`.
pub(all) struct PageRanges {
  /// The given ranges.
  ranges : Array[PageRangesPart]
} derive(Eq, Hash, Debug)

///|
/// Create a new `PageRanges` struct.
pub fn PageRanges::new(ranges : Array[PageRangesPart]) -> PageRanges {
  { ranges, }
}

///|
/// `impl From<i32> for PageRanges`.
pub fn PageRanges::from_int(value : Int) -> PageRanges {
  { ranges: [SinglePage(Numeric::new(value))], }
}

///|
/// Get the first page of the first range.
pub fn PageRanges::first(self : PageRanges) -> Numeric? {
  for r in self.ranges {
    if r.start() is Some(n) {
      return Some(n)
    }
  }
  None
}

///|
/// Order the values according to CSL rules.
pub fn PageRanges::csl_cmp(self : PageRanges, other : PageRanges) -> Int {
  let n = if self.ranges.length() < other.ranges.length() {
    self.ranges.length()
  } else {
    other.ranges.length()
  }
  for i in 0..<n {
    let c = self.ranges[i].csl_cmp(other.ranges[i])
    if c != 0 {
      return c
    }
  }
  compare_int(self.ranges.length(), other.ranges.length())
}

///|
/// Whether to pluralize the `pages` term, when used with this page range.
pub fn PageRanges::is_plural(self : PageRanges) -> Bool {
  let mut count = 0
  for range in self.ranges {
    match range {
      SinglePage(_) => count += 1
      Range(s, e) | EscapedRange(s, e) => {
        if s != e {
          return true
        }
        count += 1
      }
      _ => ()
    }
  }
  count > 1
}

///|
/// `Display for PageRanges` into a writer.
pub fn[W : FmtWrite] PageRanges::fmt(self : PageRanges, f : W) -> Unit {
  for r in self.ranges {
    r.fmt(f)
  }
}

///|
pub impl Show for PageRanges with fn output(self, logger) {
  logger.write_string(fmt_to_string(b => self.fmt(b)))
}

///|
/// `impl FromStr for PageRanges`.
pub fn PageRanges::from_str(
  s : String,
) -> Result[PageRanges, PageRangesPartErr] {
  // Split input into different ranges separated by `&` or `,`
  let ranges = []
  for
    part in group_by(s, (c, d) => {
      !(c == ',' || c == '&' || d == ',' || d == '&')
    }) {
    match PageRangesPart::from_str(part) {
      Ok(p) => ranges.push(p)
      Err(e) => return Err(e)
    }
  }
  Ok({ ranges, })
}

///|
/// Parts of the page ranges.
pub(all) enum PageRangesPart {
  /// An and, i.e, `&`.
  Ampersand
  /// A comma, i.e., `,`.
  Comma
  /// An escaped range with start and end, e.g., `1\-4`.
  EscapedRange(Numeric, Numeric)
  /// A single page, e.g., `5`.
  SinglePage(Numeric)
  /// A full range, e.g., `1n8--1n14`.
  Range(Numeric, Numeric)
} derive(Eq, Hash, Debug)

///|
/// The start of a range, if any.
pub fn PageRangesPart::start(self : PageRangesPart) -> Numeric? {
  match self {
    EscapedRange(s, _) => Some(s)
    SinglePage(s) => Some(s)
    Range(s, _) => Some(s)
    _ => None
  }
}

///|
/// The end of a range, if any.
pub fn PageRangesPart::end(self : PageRangesPart) -> Numeric? {
  match self {
    EscapedRange(_, e) => Some(e)
    Range(_, e) => Some(e)
    _ => None
  }
}

///|
/// Order the values according to CSL rules.
pub fn PageRangesPart::csl_cmp(
  self : PageRangesPart,
  other : PageRangesPart,
) -> Int {
  match (self, other) {
    (Ampersand, Ampersand) => 0
    (Ampersand, _) => -1
    (_, Ampersand) => 1
    (Comma, Comma) => 0
    (Comma, _) => -1
    (_, Comma) => 1
    (SinglePage(n1), SinglePage(n2)) => n1.csl_cmp(n2)
    (SinglePage(_), _) => -1
    (_, SinglePage(_)) => 1
    (EscapedRange(s1, e1), EscapedRange(s2, e2)) => {
      let ord = s1.csl_cmp(s2)
      if ord != 0 {
        return ord
      }
      e1.csl_cmp(e2)
    }
    (EscapedRange(_, _), _) => -1
    (_, EscapedRange(_, _)) => 1
    (Range(s1, e1), Range(s2, e2)) => {
      let ord = s1.csl_cmp(s2)
      if ord != 0 {
        return ord
      }
      e1.csl_cmp(e2)
    }
  }
}

///|
/// `Display for PageRangesPart` into a writer.
pub fn[W : FmtWrite] PageRangesPart::fmt(self : PageRangesPart, f : W) -> Unit {
  match self {
    Ampersand => f.write_str("&")
    Comma => f.write_str(", ")
    EscapedRange(s, e) | Range(s, e) => {
      s.fmt(f)
      f.write_str("-")
      e.fmt(f)
    }
    SinglePage(s) => s.fmt(f)
  }
}

///|
pub impl Show for PageRangesPart with fn output(self, logger) {
  logger.write_string(fmt_to_string(b => self.fmt(b)))
}

///|
/// Parsing error for page ranges.
pub(all) enum PageRangesPartErr {
  /// The string is malformed.
  Malformed
  /// The string is empty.
  Empty
  /// An error from parsing a numeric value.
  NumericErr(NumericError)
} derive(Eq, Debug)

///|
pub impl Show for PageRangesPartErr with fn output(self, logger) {
  logger.write_string(
    match self {
      Malformed => "page range string malformed"
      Empty => "page range is empty"
      NumericErr(_) => "page range contained invalid numeric value"
    },
  )
}

///|
pub extend PageRangesPartErr with Show::{to_string, output}

///|
/// `impl FromStr for PageRangesPart`.
pub fn PageRangesPart::from_str(
  s : String,
) -> Result[PageRangesPart, PageRangesPartErr] {
  let s = @unscanny.trim(s)
  if s.is_empty() {
    return Err(Empty)
  }
  let num = (x : String) => {
    match Numeric::from_str(x) {
      Ok(n) => Ok(n)
      Err(e) => Err(PageRangesPartErr::NumericErr(e))
    }
  }
  if s == "&" {
    Ok(Ampersand)
  } else if s == "," {
    Ok(Comma)
  } else if s.contains("\\-") {
    // If `-` chars are escaped, write `-`.
    let parts = @unscanny.split(s, "\\-").map(p => @unscanny.trim(p))
    if parts.length() < 2 {
      return Err(Empty)
    }
    let start = match num(parts[0]) {
      Ok(n) => n
      Err(e) => return Err(e)
    }
    let end = match num(parts[1]) {
      Ok(n) => n
      Err(e) => return Err(e)
    }
    if parts.length() > 2 {
      return Err(Malformed)
    }
    Ok(EscapedRange(start, end))
  } else {
    // Otherwise, split into the two halves of the dash.
    let parts = @unscanny.split_by(s, c => c == '-' || c == '–').map(p => {
      @unscanny.trim(p)
    })
    let r = if parts.length() == 1 {
      match num(parts[0]) {
        Ok(n) => SinglePage(n)
        Err(e) => return Err(e)
      }
    } else {
      let start = match num(parts[0]) {
        Ok(n) => n
        Err(e) => return Err(e)
      }
      let end = match num(parts[1]) {
        Ok(n) => n
        Err(e) => return Err(e)
      }
      Range(start, end)
    }
    if parts.length() > 2 {
      return Err(Malformed)
    }
    Ok(r)
  }
}

///|
/// Split `s` into maximal chunks such that two successive chars satisfy
/// `pred`.
pub fn group_by(s : String, pred : (Char, Char) -> Bool) -> Array[String] {
  let out = []
  let cs = @unscanny.chars(s)
  let mut i = 0
  while i < cs.length() {
    let buf = StringBuilder()
    buf.write_char(cs[i])
    let mut j = i
    while j + 1 < cs.length() && pred(cs[j], cs[j + 1]) {
      buf.write_char(cs[j + 1])
      j += 1
    }
    out.push(buf.to_string())
    i = j + 1
  }
  out
}
