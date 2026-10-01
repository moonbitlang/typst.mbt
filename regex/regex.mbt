// A regular expression engine with the syntax and semantics of the Rust
// `regex` crate (leftmost-first matching, Unicode-aware classes, UTF-8 byte
// offsets), as used by Typst's `regex` type.
//
// Supported syntax (as in `regex-syntax` 0.8): literals and escapes
// (`\n`, `\t`, `\x7F`, `\x{10FFFF}`, `\u007F`, `\U0010FFFF`, escaped
// metacharacters), `.`, classes (`[a-z]`, `[^...]`, nested classes, `&&`,
// `--`, `~~`, ASCII classes like `[[:alpha:]]`), Perl classes (`\d`, `\w`,
// `\s` and negations), Unicode classes (`\pL`, `\p{Letter}`, `\p{Greek}`,
// `\p{gc=Lu}`, `\p{sc=Greek}`, binary properties), anchors and word
// boundaries (`^`, `$`, `\A`, `\z`, `\b`, `\B`, `\b{start}`, `\<`, ...),
// groups (`(...)`, `(?:...)`, `(?P<name>...)`, `(?<name>...)`), flags
// (`i`, `m`, `s`, `U`, `u`, `R`, `x`), alternation and greedy/lazy
// repetition (`*`, `+`, `?`, `{n}`, `{n,}`, `{n,m}`).
//
// Not supported: `Script_Extensions`, `Age` and segmentation properties.

///|
/// A compiled regular expression.
pub struct Regex {
  priv pattern : String
  priv nfa : Nfa
  priv names : Array[String?]
}

///|
/// Compile a regular expression. Errors are formatted like the `Display` of
/// the `regex` crate's error.
pub fn Regex::new(pattern : String) -> Regex raise RegexError {
  let parser = Parser::new(pattern)
  let ast = parser.parse()
  let translator : Translator = {
    pattern,
    flags: {
      case_insensitive: None,
      multi_line: None,
      dot_matches_new_line: None,
      swap_greed: None,
      unicode: None,
      crlf: None,
    },
    names: [],
  }
  let hir = translator.translate(ast)
  let group_len = parser.capture_index + 1
  let names = Array::makei(group_len, i => {
    translator.names.get(i).unwrap_or(None)
  })
  { pattern, nfa: compile(hir, group_len), names, }
}

///|
/// The original pattern.
pub fn Regex::as_str(self : Regex) -> String {
  self.pattern
}

///|
/// The names of the capture groups (including the unnamed group 0).
pub fn Regex::capture_names(self : Regex) -> Array[String?] {
  self.names
}

///|
pub impl Eq for Regex with fn equal(self, other) {
  self.pattern == other.pattern
}

///|
pub impl Hash for Regex with fn hash_combine(self, hasher) {
  hasher.combine(self.pattern)
}

///|
pub impl Show for Regex with fn output(self, logger) {
  logger.write_string("Regex(")
  logger.write_string(self.pattern)
  logger.write_string(")")
}

///|
/// A match: UTF-8 byte offsets into the haystack and the matched text.
pub(all) struct Match {
  start : Int
  end : Int
  text : String
} derive(Eq, Debug)

///|
/// The capture groups of a match. Group 0 is the overall match.
pub struct Captures {
  priv groups : Array[Match?]
}

///|
/// The match of a capture group, if it participated.
pub fn Captures::get(self : Captures, i : Int) -> Match? {
  self.groups.get(i).unwrap_or(None)
}

///|
/// The number of capture groups (including group 0).
pub fn Captures::len(self : Captures) -> Int {
  self.groups.length()
}

///|
/// Iterate over all groups (including group 0).
pub fn Captures::iter(self : Captures) -> Iter[Match?] {
  self.groups.iter()
}

///|
fn make_match(s : String, hay : Haystack, start : Int, end : Int) -> Match {
  {
    start: hay.bytes[start],
    end: hay.bytes[end],
    text: s.unsafe_substring(start=hay.utf16[start], end=hay.utf16[end]),
  }
}

///|
fn make_captures(
  s : String,
  hay : Haystack,
  slots : FixedArray[Int],
) -> Captures {
  let groups = []
  for i = 0; i + 1 < slots.length(); i = i + 2 {
    if slots[i] >= 0 && slots[i + 1] >= 0 {
      groups.push(Some(make_match(s, hay, slots[i], slots[i + 1])))
    } else {
      groups.push(None)
    }
  }
  { groups, }
}

///|
/// Search starting at the char position `at`.
fn Regex::search(self : Regex, hay : Haystack, at : Int) -> FixedArray[Int]? {
  self.nfa.search(hay, at)
}

///|
/// Whether the regex matches somewhere in the string.
pub fn Regex::is_match(self : Regex, s : String) -> Bool {
  self.search(Haystack::new(s), 0) is Some(_)
}

///|
/// The leftmost-first match in the string.
pub fn Regex::find(self : Regex, s : String) -> Match? {
  self.find_at(s, 0)
}

///|
/// The leftmost-first match starting the search at the UTF-8 byte offset
/// `start` (with the surrounding context taken into account).
pub fn Regex::find_at(self : Regex, s : String, start : Int) -> Match? {
  let hay = Haystack::new(s)
  guard hay.char_pos(start) is Some(at) else { return None }
  match self.search(hay, at) {
    Some(slots) => Some(make_match(s, hay, slots[0], slots[1]))
    None => None
  }
}

///|
/// The capture groups of the leftmost-first match.
pub fn Regex::captures(self : Regex, s : String) -> Captures? {
  let hay = Haystack::new(s)
  match self.search(hay, 0) {
    Some(slots) => Some(make_captures(s, hay, slots))
    None => None
  }
}

///|
/// All successive non-overlapping matches as capture slots (upstream
/// `Searcher::advance`, including its handling of empty matches).
fn Regex::all_slots(self : Regex, hay : Haystack) -> Array[FixedArray[Int]] {
  let out = []
  let len = hay.chars.length()
  let mut start = 0
  let mut last_match_end : Int? = None
  while start <= len {
    let mut slots = match self.search(hay, start) {
      Some(slots) => slots
      None => break
    }
    if slots[0] == slots[1] && last_match_end == Some(slots[1]) {
      // An empty match overlapping the end of the last match: search again
      // one char further.
      start += 1
      if start > len {
        break
      }
      slots = match self.search(hay, start) {
        Some(slots) => slots
        None => break
      }
    }
    start = slots[1]
    last_match_end = Some(slots[1])
    out.push(slots)
  }
  out
}

///|
/// All successive non-overlapping matches.
pub fn Regex::find_iter(self : Regex, s : String) -> Array[Match] {
  let hay = Haystack::new(s)
  self.all_slots(hay).map(slots => make_match(s, hay, slots[0], slots[1]))
}

///|
/// The capture groups of all successive non-overlapping matches.
pub fn Regex::captures_iter(self : Regex, s : String) -> Array[Captures] {
  let hay = Haystack::new(s)
  self.all_slots(hay).map(slots => make_captures(s, hay, slots))
}

///|
/// The substrings between the matches.
pub fn Regex::split(self : Regex, s : String) -> Array[String] {
  let hay = Haystack::new(s)
  let out = []
  let mut last = 0
  for slots in self.all_slots(hay) {
    out.push(s.unsafe_substring(start=hay.utf16[last], end=hay.utf16[slots[0]]))
    last = slots[1]
  }
  out.push(s.unsafe_substring(start=hay.utf16[last], end=s.length()))
  out
}

///|
/// Whether the pattern parses (without translation) to a single dot,
/// literal or character class (upstream: matching the `regex_syntax::ast::Ast`
/// of a font coverage regex against `ClassBracketed | ClassUnicode |
/// ClassPerl | Dot | Literal`).
pub fn ast_is_single_char(pattern : String) -> Bool {
  let ast = Parser::new(pattern).parse() catch { _ => return false }
  ast
  is (ClassBracketed(_) | ClassUnicode(_) | ClassPerl(_) | Dot(_) | Literal(_))
}
