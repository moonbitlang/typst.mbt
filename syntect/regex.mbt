// Port of `syntect/src/parsing/regex.rs` with the `regex-fancy` backend
// (Typst builds syntect with `regex-fancy`), on top of the port of
// `fancy-regex` in `regex/fancy`.

///|
/// An abstraction for regex patterns.
///
/// * Allows swapping out the regex implementation because it's only in this
///   module.
/// * Makes regexes serializable and deserializable using just the pattern
///   string.
/// * Lazily compiles regexes on first use to improve initialization time.
pub struct Regex {
  priv regex_str : String
  priv mut regex : @fancy.Regex?
}

///|
/// A region contains text positions for capture groups in a match result.
pub struct Region {
  priv positions : Array[(Int, Int)?]
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Region with Eq::{not_equal, equal}

///|
/// A line prepared for searching: the text with its UTF-8 offsets and the
/// regex engine's decoded form, shared by all searches on the line.
pub struct SearchText {
  priv index : ByteIndex
  priv text : @fancy.Text
}

///|
pub fn SearchText::new(index : ByteIndex) -> SearchText {
  { index, text: @fancy.Text::new(index.text()), }
}

///|
pub fn SearchText::text(self : SearchText) -> ByteIndex {
  self.index
}

///|
/// The UTF-8 length of the text.
pub fn SearchText::len(self : SearchText) -> Int {
  self.index.len()
}

///|
/// `line[start..].char_indices().nth(1)`: the offset of the char after the
/// one at `start`, if there is one.
pub fn SearchText::next_char_offset(self : SearchText, start : Int) -> Int? {
  let mut next = start + 1
  while next < self.index.len() && self.index.utf16(next) < 0 {
    next += 1
  }
  if next < self.index.len() {
    Some(next)
  } else {
    None
  }
}

///|
/// Create a new regex from the pattern string.
///
/// Note that the regex compilation happens on first use, which is why this
/// method does not return a result.
pub fn Regex::new(regex_str : String) -> Regex {
  { regex_str, regex: None, }
}

///|
fn compile(regex_str : String) -> @fancy.Regex raise @fancy.FancyError {
  @fancy.RegexBuilder::new(regex_str).oniguruma_mode(true).build()
}

///|
/// Check whether the pattern compiles as a valid regex or not. Returns the
/// error's message if not.
pub fn Regex::try_compile(regex_str : String) -> String? {
  try compile(regex_str) catch {
    e => Some(e.to_string())
  } noraise {
    _ => None
  }
}

///|
/// Return the regex pattern.
pub fn Regex::regex_str(self : Regex) -> String {
  self.regex_str
}

///|
/// Check if the regex matches the given text.
pub fn Regex::is_match(self : Regex, text : String) -> Bool {
  // Errors are treated as non-matches
  self.regex().is_match(text) catch {
    _ => false
  }
}

///|
/// Search for the pattern in the given text from begin/end positions.
///
/// If a region is passed, it is used for storing match group positions.
pub fn Regex::search(
  self : Regex,
  text : ByteIndex,
  begin : Int,
  end : Int,
  region : Region?,
) -> Bool {
  self.search_text(SearchText::new(text), begin, end, region)
}

///|
/// Like `search`, on a prepared text.
pub fn Regex::search_text(
  self : Regex,
  text : SearchText,
  begin : Int,
  end : Int,
  region : Region?,
) -> Bool {
  // If there's an error during search, treat it as non-matching. For
  // example, in case of catastrophic backtracking, fancy-regex should fail
  // with an error eventually.
  let regex = self.regex()
  let haystack = if end == text.len() {
    text.text
  } else {
    text.text.prefix(end)
  }
  let captures = regex.captures_from_pos_text(haystack, begin) catch {
    _ => return false
  }
  match captures {
    Some(captures) => {
      if region is Some(region) {
        region.init_from_captures(captures)
      }
      true
    }
    None => false
  }
}

///|
fn Regex::regex(self : Regex) -> @fancy.Regex {
  match self.regex {
    Some(regex) => regex
    None => {
      let regex = compile(self.regex_str) catch {
        _ => abort("regex string should be pre-tested")
      }
      self.regex = Some(regex)
      regex
    }
  }
}

///|
pub fn Region::new() -> Region {
  { positions: [], }
}

///|
pub fn Region::clone(self : Region) -> Region {
  { positions: self.positions.copy(), }
}

///|
fn Region::init_from_captures(
  self : Region,
  captures : @fancy.Captures,
) -> Unit {
  self.positions.clear()
  for i in 0..<captures.len() {
    let pos = captures.get(i).map(m => (m.start(), m.end()))
    self.positions.push(pos)
  }
}

///|
/// Get the start/end positions of the capture group with given index.
///
/// If there is no match for that group or the index does not correspond to
/// a group, `None` is returned. The index 0 returns the whole match.
pub fn Region::pos(self : Region, i : Int) -> (Int, Int)? {
  if i < self.positions.length() {
    self.positions[i]
  } else {
    None
  }
}
