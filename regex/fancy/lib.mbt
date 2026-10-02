// Port of `fancy-regex` 0.16.2 `src/lib.rs` (public API).
//
// An implementation of regexes, supporting a relatively rich set of
// features, including backreferences and lookaround.
//
// If your regex or parts of it does not use any special features, the
// matching is delegated to the `regex` package (a port of the Rust `regex`
// crate). That means it has linear runtime. But if you use "fancy" features
// such as backreferences or look-around, an engine with backtracking needs to
// be used. In that case, the regex can be slow and take exponential time to
// run because of what is called "catastrophic backtracking".
//
// All positions in the public API are UTF-8 byte offsets (like upstream).
//
// Text reuse: searching a `String` decodes it first. To run many searches
// (with any number of regexes) on the same text, build a `Text` once with
// `Text::new` and use the `*_text` variants (e.g.
// `Regex::captures_from_pos_text`), which take `Text` instead of `String`.
// `Text::prefix(end)` gives a cheap view of `text[..end]` (as if the string
// ended there, like upstream's `&text[..end]`).

///|
/// The input text of a search: a decoded string that can be searched many
/// times by different regexes without decoding it again.
pub struct Text {
  priv hay : @regex.Haystack
}

///|
/// Decode a string for searching.
pub fn Text::new(s : String) -> Text {
  { hay: @regex.Haystack::new(s) }
}

///|
/// A view of the first `end` bytes (like `&text[..end]`; `end` must be a char
/// boundary, otherwise the whole text is returned).
pub fn Text::prefix(self : Text, end : Int) -> Text {
  match self.hay.char_pos(end) {
    Some(n) => { hay: self.hay.prefix(n) }
    None => self
  }
}

///|
/// The length in UTF-8 bytes.
pub fn Text::len(self : Text) -> Int {
  self.hay.byte_len()
}

///|
/// The (visible) text as a string.
pub fn Text::as_str(self : Text) -> String {
  self.hay.substring(0, self.hay.char_len())
}

///|
/// The char position of a byte offset (`None` if not a char boundary or out
/// of bounds).
fn Text::char_pos(self : Text, byte : Int) -> Int? {
  self.hay.char_pos(byte)
}

///|
/// The configuration forwarded to the delegated `regex` engine (upstream
/// `regex_automata::util::syntax::Config`, reduced to the used options).
pub struct SyntaxConfig {
  case_insensitive : Bool
  multi_line : Bool
  dot_matches_new_line : Bool
  ignore_whitespace : Bool
  unicode : Bool
} derive(Eq, Debug)

///|
fn SyntaxConfig::default() -> SyntaxConfig {
  {
    case_insensitive: false,
    multi_line: false,
    dot_matches_new_line: false,
    ignore_whitespace: false,
    unicode: true,
  }
}

///|
priv struct RegexOptions {
  mut pattern : String
  mut syntaxc : SyntaxConfig
  mut backtrack_limit : Int
  mut oniguruma_mode : Bool
}

///|
fn RegexOptions::get_flag_value(flag_value : Bool, enum_value : Int) -> Int {
  if flag_value {
    enum_value
  } else {
    0
  }
}

///|
fn RegexOptions::compute_flags(self : RegexOptions) -> Int {
  let insensitive = RegexOptions::get_flag_value(
    self.syntaxc.case_insensitive,
    FLAG_CASEI,
  )
  let multiline = RegexOptions::get_flag_value(
    self.syntaxc.multi_line,
    FLAG_MULTI,
  )
  let whitespace = RegexOptions::get_flag_value(
    self.syntaxc.ignore_whitespace,
    FLAG_IGNORE_SPACE,
  )
  let dotnl = RegexOptions::get_flag_value(
    self.syntaxc.dot_matches_new_line,
    FLAG_DOTNL,
  )
  let unicode = RegexOptions::get_flag_value(self.syntaxc.unicode, FLAG_UNICODE)
  let oniguruma_mode = RegexOptions::get_flag_value(
    self.oniguruma_mode,
    FLAG_ONIGURUMA_MODE,
  )
  insensitive | multiline | whitespace | dotnl | unicode | oniguruma_mode
}

///|
fn RegexOptions::default() -> RegexOptions {
  {
    pattern: "",
    syntaxc: SyntaxConfig::default(),
    backtrack_limit: 1_000_000,
    oniguruma_mode: false,
  }
}

///|
fn RegexOptions::clone(self : RegexOptions) -> RegexOptions {
  { ..self }
}

///|
/// A builder for a `Regex` to allow configuring options.
pub struct RegexBuilder {
  priv options : RegexOptions
}

///|
/// Create a new regex builder with a regex pattern.
///
/// If the pattern is invalid, the call to `build` will fail later.
pub fn RegexBuilder::new(pattern : String) -> RegexBuilder {
  let builder = { options: RegexOptions::default() }
  builder.options.pattern = pattern
  builder
}

///|
/// Build the `Regex`.
///
/// Raises a `FancyError` if the pattern could not be parsed.
pub fn RegexBuilder::build(self : RegexBuilder) -> Regex raise FancyError {
  Regex::new_options(self.options.clone())
}

///|
/// Override default case insensitive
/// this is to enable/disable casing via builder instead of a flag within
/// the raw string provided to the regex builder
///
/// Default is false
pub fn RegexBuilder::case_insensitive(
  self : RegexBuilder,
  yes : Bool,
) -> RegexBuilder {
  self.options.syntaxc = { ..self.options.syntaxc, case_insensitive: yes }
  self
}

///|
/// Enable multi-line regex
pub fn RegexBuilder::multi_line(self : RegexBuilder, yes : Bool) -> RegexBuilder {
  self.options.syntaxc = { ..self.options.syntaxc, multi_line: yes }
  self
}

///|
/// Allow ignore whitespace
pub fn RegexBuilder::ignore_whitespace(
  self : RegexBuilder,
  yes : Bool,
) -> RegexBuilder {
  self.options.syntaxc = { ..self.options.syntaxc, ignore_whitespace: yes }
  self
}

///|
/// Enable or disable the "dot matches any character" flag.
/// When this is enabled, `.` will match any character. When it's disabled,
/// then `.` will match any character except for a new line character.
pub fn RegexBuilder::dot_matches_new_line(
  self : RegexBuilder,
  yes : Bool,
) -> RegexBuilder {
  self.options.syntaxc = { ..self.options.syntaxc, dot_matches_new_line: yes }
  self
}

///|
/// Enable verbose mode in the regular expression.
///
/// The same as ignore_whitespace
pub fn RegexBuilder::verbose_mode(
  self : RegexBuilder,
  yes : Bool,
) -> RegexBuilder {
  self.options.syntaxc = { ..self.options.syntaxc, ignore_whitespace: yes }
  self
}

///|
/// Enable or disable the Unicode flag (`u`) by default.
pub fn RegexBuilder::unicode_mode(
  self : RegexBuilder,
  yes : Bool,
) -> RegexBuilder {
  self.options.syntaxc = { ..self.options.syntaxc, unicode: yes }
  self
}

///|
/// Limit for how many times backtracking should be attempted for fancy
/// regexes (where backtracking is used). If this limit is exceeded,
/// execution raises `RuntimeError(BacktrackLimitExceeded)`.
///
/// Default is `1_000_000` (1 million).
pub fn RegexBuilder::backtrack_limit(
  self : RegexBuilder,
  limit : Int,
) -> RegexBuilder {
  self.options.backtrack_limit = limit
  self
}

///|
/// Set the approximate size limit of the compiled regular expression
/// (accepted for compatibility; the `regex` package has no size limit).
pub fn RegexBuilder::delegate_size_limit(
  self : RegexBuilder,
  limit : Int,
) -> RegexBuilder {
  ignore(limit)
  self
}

///|
/// Set the approximate size of the cache used by the DFA (accepted for
/// compatibility; unused).
pub fn RegexBuilder::delegate_dfa_size_limit(
  self : RegexBuilder,
  limit : Int,
) -> RegexBuilder {
  ignore(limit)
  self
}

///|
/// Attempts to better match Oniguruma's default behavior.
///
/// Currently this amounts to treating `\<` and `\>` as the literals `<` and
/// `>` instead of left and right word bounds.
pub fn RegexBuilder::oniguruma_mode(
  self : RegexBuilder,
  yes : Bool,
) -> RegexBuilder {
  self.options.oniguruma_mode = yes
  self
}

///|
/// A compiled regular expression.
pub struct Regex {
  priv inner : RegexImpl
  priv named_groups : Map[String, Int]
}

///|
// Separate enum because we don't want to expose any of this
priv enum RegexImpl {
  Wrap(
    inner~ : @regex.Regex,
    options~ : RegexOptions,
    /// Some optimizations avoid the VM, but need to use an extra capture
    /// group to represent the match boundaries
    explicit_capture_group_0~ : Bool,
    debug_pattern~ : String
  )
  Fancy(prog~ : Prog, n_groups~ : Int, options~ : RegexOptions)
}

///|
/// Shows the original regular expression.
pub impl Show for Regex with fn output(self, logger) {
  logger.write_string(self.as_str())
}

///|
/// Parse and compile a regex with default options, see `RegexBuilder`.
///
/// Raises a `FancyError` if the pattern could not be parsed.
pub fn Regex::new(re : String) -> Regex raise FancyError {
  let options = RegexOptions::default()
  options.pattern = re
  Regex::new_options(options)
}

///|
fn Regex::new_options(options : RegexOptions) -> Regex raise FancyError {
  let tree = Expr::parse_tree_with_flags(options.pattern, options.compute_flags())

  // try to optimize the expression tree
  let requires_capture_group_fixup = optimize(tree)
  let info = analyze(tree, requires_capture_group_fixup)
  if !info.hard {
    // easy case, wrap regex

    // we do our own to_str because escapes are different
    let re_cooked = StringBuilder()
    tree.expr.to_str(re_cooked, 0)
    let re_cooked = re_cooked.to_string()
    let inner = compile_inner(re_cooked, options)
    return {
      inner: Wrap(
        inner~,
        options~,
        explicit_capture_group_0=requires_capture_group_fixup,
        debug_pattern=re_cooked,
      ),
      named_groups: tree.named_groups,
    }
  }
  let prog = compile(info, can_compile_as_anchored(tree.expr))
  {
    inner: Fancy(prog~, n_groups=info.end_group, options~),
    named_groups: tree.named_groups,
  }
}

///|
/// Returns the original string of this regex.
pub fn Regex::as_str(self : Regex) -> String {
  match self.inner {
    Wrap(options~, ..) => options.pattern
    Fancy(options~, ..) => options.pattern
  }
}

///|
/// Whether this regex is executed by the backtracking VM (upstream
/// `RegexImpl::Fancy`) rather than delegated entirely to the `regex` engine.
pub fn Regex::is_fancy(self : Regex) -> Bool {
  self.inner is Fancy(_)
}

///|
/// Check if the regex matches the input text.
pub fn Regex::is_match(self : Regex, text : String) -> Bool raise FancyError {
  self.is_match_text(Text::new(text))
}

///|
/// `is_match` on a reusable `Text`.
pub fn Regex::is_match_text(self : Regex, text : Text) -> Bool raise FancyError {
  match self.inner {
    Wrap(inner~, ..) => {
      let slots = FixedArray::make(2, -1)
      inner.search_slots(text.hay, 0, anchored=false, slots)
    }
    Fancy(prog~, options~, ..) => run(prog, text.hay, 0, 0, options) is Some(_)
  }
}

///|
/// Returns an iterator for each successive non-overlapping match in `text`.
pub fn Regex::find_iter(self : Regex, text : String) -> Matches {
  self.find_iter_text(Text::new(text))
}

///|
/// `find_iter` on a reusable `Text`.
pub fn Regex::find_iter_text(self : Regex, text : Text) -> Matches {
  { re: self, text, last_end: 0, last_match: None }
}

///|
/// Find the first match in the input text.
pub fn Regex::find(self : Regex, text : String) -> Match? raise FancyError {
  self.find_from_pos(text, 0)
}

///|
/// Returns the first match in `text`, starting from the specified byte
/// position `pos`. Returns `None` if `pos` is not a char boundary of `text`.
///
/// Note that in some cases this is not the same as using the `find`
/// method and passing a slice of the string, see `Regex::captures_from_pos`.
pub fn Regex::find_from_pos(
  self : Regex,
  text : String,
  pos : Int,
) -> Match? raise FancyError {
  self.find_from_pos_text(Text::new(text), pos)
}

///|
/// `find_from_pos` on a reusable `Text`.
pub fn Regex::find_from_pos_text(
  self : Regex,
  text : Text,
  pos : Int,
) -> Match? raise FancyError {
  guard text.char_pos(pos) is Some(pos) else { return None }
  self.find_from_pos_with_option_flags(text, pos, 0)
}

///|
/// `pos` is a char position.
fn Regex::find_from_pos_with_option_flags(
  self : Regex,
  text : Text,
  pos : Int,
  option_flags : Int,
) -> Match? raise FancyError {
  match self.inner {
    Wrap(inner~, explicit_capture_group_0~, ..) =>
      if !explicit_capture_group_0 {
        let slots = FixedArray::make(2, -1)
        if inner.search_slots(text.hay, pos, anchored=false, slots) {
          Some(Match::new(text, slots[0], slots[1]))
        } else {
          None
        }
      } else {
        let slots = FixedArray::make(4, -1)
        if inner.search_slots(text.hay, pos, anchored=false, slots) {
          Some(Match::new(text, slots[2], slots[3]))
        } else {
          None
        }
      }
    Fancy(prog~, options~, ..) => {
      let result = run(prog, text.hay, pos, option_flags, options)
      result.map(saves => Match::new(text, saves[0], saves[1]))
    }
  }
}

///|
/// Returns an iterator over all the non-overlapping capture groups matched
/// in `text`.
pub fn Regex::captures_iter(self : Regex, text : String) -> CaptureMatches {
  self.captures_iter_text(Text::new(text))
}

///|
/// `captures_iter` on a reusable `Text`.
pub fn Regex::captures_iter_text(self : Regex, text : Text) -> CaptureMatches {
  { inner: self.find_iter_text(text) }
}

///|
/// Returns the capture groups for the first match in `text`.
///
/// If no match is found, then `None` is returned.
pub fn Regex::captures(self : Regex, text : String) -> Captures? raise FancyError {
  self.captures_from_pos(text, 0)
}

///|
/// Returns the capture groups for the first match in `text`, starting from
/// the specified byte position `pos`. Returns `None` if `pos` is not a char
/// boundary of `text`.
///
/// Note that in some cases this is not the same as using the `captures`
/// method and passing a slice of the string: the text before `pos` is seen
/// by look-behind and assertions like `^` and `\b`.
pub fn Regex::captures_from_pos(
  self : Regex,
  text : String,
  pos : Int,
) -> Captures? raise FancyError {
  self.captures_from_pos_text(Text::new(text), pos)
}

///|
/// `captures_from_pos` on a reusable `Text` (`pos` is a byte offset).
pub fn Regex::captures_from_pos_text(
  self : Regex,
  text : Text,
  pos : Int,
) -> Captures? raise FancyError {
  guard text.char_pos(pos) is Some(pos) else { return None }
  self.captures_from_char_pos(text, pos)
}

///|
fn Regex::captures_from_char_pos(
  self : Regex,
  text : Text,
  pos : Int,
) -> Captures? raise FancyError {
  let named_groups = self.named_groups
  match self.inner {
    Wrap(inner~, explicit_capture_group_0~, ..) => {
      let slots = FixedArray::make(inner.group_len() * 2, -1)
      if inner.search_slots(text.hay, pos, anchored=false, slots) {
        let skip = if explicit_capture_group_0 { 2 } else { 0 }
        let saves = Array::makei(slots.length() - skip, i => slots[i + skip])
        Some({ text, saves, named_groups })
      } else {
        None
      }
    }
    Fancy(prog~, n_groups~, options~) => {
      let result = run(prog, text.hay, pos, 0, options)
      result.map(saves => {
        saves.truncate(n_groups * 2)
        for i in 0..<saves.length() {
          if saves[i] == USIZE_MAX {
            saves[i] = -1
          }
        }
        { text, saves, named_groups }
      })
    }
  }
}

///|
/// Returns the number of captures, including the implicit capture of the
/// entire expression.
pub fn Regex::captures_len(self : Regex) -> Int {
  match self.inner {
    Wrap(inner~, explicit_capture_group_0~, ..) =>
      inner.group_len() - (if explicit_capture_group_0 { 1 } else { 0 })
    Fancy(n_groups~, ..) => n_groups
  }
}

///|
/// Returns the capture names: the name of each group, or `None` if the
/// group has no name. Because capture group 0 cannot have a name, the first
/// item is always `None`.
pub fn Regex::capture_names(self : Regex) -> Array[String?] {
  let names : Array[String?] = Array::make(self.captures_len(), None)
  for name, i in self.named_groups {
    names[i] = Some(name)
  }
  names
}

///|
/// For debugging only.
pub fn Regex::debug_print(self : Regex) -> String {
  match self.inner {
    Wrap(debug_pattern~, explicit_capture_group_0~, ..) =>
      "wrapped Regex \{@unicode.rust_debug_str(debug_pattern)}, explicit_capture_group_0: \{explicit_capture_group_0}"
    Fancy(prog~, ..) => {
      let buf = StringBuilder()
      prog.debug_print(buf)
      buf.to_string()
    }
  }
}

///|
/// Replaces the leftmost-first match with the replacement provided. With
/// `Expand(s)`, `$N` and `$name` in `s` are expanded to match capture groups
/// (see `Captures::expand`).
///
/// If no match is found, then a copy of the string is returned unchanged.
/// Aborts on runtime errors (use `try_replacen` to handle them).
pub fn Regex::replace(self : Regex, text : String, rep : Replacer) -> String {
  self.replacen(text, 1, rep)
}

///|
/// Replaces all non-overlapping matches in `text` with the replacement
/// provided. This is the same as calling `replacen` with `limit` set to `0`.
pub fn Regex::replace_all(self : Regex, text : String, rep : Replacer) -> String {
  self.replacen(text, 0, rep)
}

///|
/// Replaces at most `limit` non-overlapping matches in `text` with the
/// replacement provided. If `limit` is 0, then all non-overlapping matches
/// are replaced. Aborts if any errors are encountered.
pub fn Regex::replacen(
  self : Regex,
  text : String,
  limit : Int,
  rep : Replacer,
) -> String {
  self.try_replacen(text, limit, rep) catch {
    e => abort(e.to_string())
  }
}

///|
/// Replaces at most `limit` non-overlapping matches in `text` with the
/// replacement provided. If `limit` is 0, then all non-overlapping matches
/// are replaced.
///
/// Propagates any errors encountered, such as `BacktrackLimitExceeded`.
pub fn Regex::try_replacen(
  self : Regex,
  text : String,
  limit : Int,
  rep : Replacer,
) -> String raise FancyError {
  let t = Text::new(text)
  // If we know that the replacement doesn't have any capture expansions,
  // then we can fast path.
  if rep.no_expansion() is Some(rep) {
    let it = self.find_iter_text(t)
    let mut first = it.next()
    if first is None {
      return text
    }
    let new = StringBuilder()
    let mut last_match = 0
    let mut i = 0
    while first is Some(m) {
      let m = m.unwrap_or_error()
      if limit > 0 && i >= limit {
        break
      }
      new.write_string(t.hay.substring(last_match, m.start_char))
      new.write_string(rep)
      last_match = m.end_char
      i += 1
      first = it.next()
    }
    new.write_string(t.hay.substring(last_match, t.hay.char_len()))
    return new.to_string()
  }

  // The slower path, which we use if the replacement needs access to
  // capture groups.
  let it = self.captures_iter_text(t)
  let mut first = it.next()
  if first is None {
    return text
  }
  let new = StringBuilder()
  let mut last_match = 0
  let mut i = 0
  while first is Some(cap) {
    let cap = cap.unwrap_or_error()
    if limit > 0 && i >= limit {
      break
    }
    // unwrap on 0 is OK because captures only reports matches
    let m = cap.get(0).unwrap()
    new.write_string(t.hay.substring(last_match, m.start_char))
    rep.replace_append(cap, new)
    last_match = m.end_char
    i += 1
    first = it.next()
  }
  new.write_string(t.hay.substring(last_match, t.hay.char_len()))
  new.to_string()
}

///|
/// Splits the string by matches of the regex.
///
/// Returns an iterator over the substrings of the target string that
/// *aren't* matched by the regex.
pub fn Regex::split(self : Regex, target : String) -> Split {
  let text = Text::new(target)
  { matches: self.find_iter_text(text), next_start: 0, target: text }
}

///|
/// Splits the string by matches of the regex at most `limit` times.
///
/// The `N`th substring is the remaining part of the target.
pub fn Regex::splitn(self : Regex, target : String, limit : Int) -> SplitN {
  { splits: self.split(target), limit }
}

///|
/// A single match of a regex or group in an input text
pub struct Match {
  priv text : Text
  priv start_char : Int
  priv end_char : Int
}

///|
fn Match::new(text : Text, start : Int, end : Int) -> Match {
  { text, start_char: start, end_char: end }
}

///|
/// Returns the starting byte offset of the match in the text.
pub fn Match::start(self : Match) -> Int {
  self.text.hay.byte_offset(self.start_char)
}

///|
/// Returns the ending byte offset of the match in the text.
pub fn Match::end(self : Match) -> Int {
  self.text.hay.byte_offset(self.end_char)
}

///|
/// Returns the range over the starting and ending byte offsets of the match
/// in text.
pub fn Match::range(self : Match) -> (Int, Int) {
  (self.start(), self.end())
}

///|
/// Returns the matched text.
pub fn Match::as_str(self : Match) -> String {
  self.text.hay.substring(self.start_char, self.end_char)
}

///|
pub impl Show for Match with fn output(self, logger) {
  logger.write_string(
    "Match { start: \{self.start()}, end: \{self.end()}, text: \{@unicode.rust_debug_str(self.as_str())} }",
  )
}

///|
pub impl Eq for Match with fn equal(self, other) {
  self.start() == other.start() &&
  self.end() == other.end() &&
  self.as_str() == other.as_str()
}

///|
/// An iterator over all non-overlapping matches for a particular string.
///
/// The iterator yields a `Result[Match, FancyError]`. The iterator stops when
/// no more matches can be found.
pub struct Matches {
  priv re : Regex
  priv text : Text
  /// Char positions.
  priv mut last_end : Int
  priv mut last_match : Int?
}

///|
/// Return the text being searched.
pub fn Matches::text(self : Matches) -> String {
  self.text.as_str()
}

///|
/// Return the underlying regex.
pub fn Matches::regex(self : Matches) -> Regex {
  self.re
}

///|
/// Adapted from the `regex` crate. Calls `find_from_pos` repeatedly.
/// Ignores empty matches immediately after a match.
pub fn Matches::next(self : Matches) -> Result[Match, FancyError]? {
  let len = self.text.hay.char_len()
  if self.last_end > len {
    return None
  }
  let option_flags = if self.last_match is Some(last_match) {
    if self.last_end > last_match {
      OPTION_SKIPPED_EMPTY_MATCH
    } else {
      0
    }
  } else {
    0
  }
  let mat = self.re.find_from_pos_with_option_flags(
      self.text,
      self.last_end,
      option_flags,
    ) catch {
    error => {
      // Stop on first error: If an error is encountered, return it, and set the "last match position"
      // to the string length, so that the next next() call will return None, to prevent an infinite loop.
      self.last_end = len + 1
      return Some(Err(error))
    }
  } noraise {
    None => return None
    Some(mat) => mat
  }
  if mat.start_char == mat.end_char {
    // This is an empty match. To ensure we make progress, start
    // the next search at the smallest possible starting position
    // of the next match following this one.
    self.last_end = mat.end_char + 1
    // Don't accept empty matches immediately following a match.
    // Just move on to the next match.
    if Some(mat.end_char) == self.last_match {
      return self.next()
    }
  } else {
    self.last_end = mat.end_char
  }
  self.last_match = Some(mat.end_char)
  Some(Ok(mat))
}

///|
pub fn Matches::iter(self : Matches) -> Iter[Result[Match, FancyError]] {
  Iter::new(() => self.next())
}

///|
/// An iterator that yields all non-overlapping capture groups matching a
/// particular regular expression.
pub struct CaptureMatches {
  priv inner : Matches
}

///|
/// Return the text being searched.
pub fn CaptureMatches::text(self : CaptureMatches) -> String {
  self.inner.text.as_str()
}

///|
/// Return the underlying regex.
pub fn CaptureMatches::regex(self : CaptureMatches) -> Regex {
  self.inner.re
}

///|
/// Adapted from the `regex` crate. Calls `captures_from_pos` repeatedly.
/// Ignores empty matches immediately after a match.
pub fn CaptureMatches::next(self : CaptureMatches) -> Result[Captures, FancyError]? {
  let m = self.inner
  let len = m.text.hay.char_len()
  if m.last_end > len {
    return None
  }
  let captures = m.re.captures_from_char_pos(m.text, m.last_end) catch {
    error => {
      // Stop on first error: If an error is encountered, return it, and set the "last match position"
      // to the string length, so that the next next() call will return None, to prevent an infinite loop.
      m.last_end = len + 1
      return Some(Err(error))
    }
  } noraise {
    None => return None
    Some(captures) => captures
  }
  guard captures.get(0) is Some(mat) else {
    abort("`Captures` is expected to have entire match at 0th position")
  }
  if mat.start_char == mat.end_char {
    m.last_end = mat.end_char + 1
    if Some(mat.end_char) == m.last_match {
      return self.next()
    }
  } else {
    m.last_end = mat.end_char
  }
  m.last_match = Some(mat.end_char)
  Some(Ok(captures))
}

///|
pub fn CaptureMatches::iter(
  self : CaptureMatches,
) -> Iter[Result[Captures, FancyError]] {
  Iter::new(() => self.next())
}

///|
/// A set of capture groups found for a regex.
pub struct Captures {
  priv text : Text
  /// Char positions of the groups' starts and ends (-1 if unset).
  priv saves : Array[Int]
  priv named_groups : Map[String, Int]
}

///|
/// Get the capture group by its index in the regex.
///
/// If there is no match for that group or the index does not correspond to
/// a group, `None` is returned. The index 0 returns the whole match.
pub fn Captures::get(self : Captures, i : Int) -> Match? {
  let slot = i * 2
  if i < 0 || slot >= self.saves.length() {
    return None
  }
  let lo = self.saves[slot]
  if lo < 0 {
    return None
  }
  let hi = self.saves[slot + 1]
  Some({ text: self.text, start_char: lo, end_char: hi })
}

///|
/// Returns the match for a named capture group. Returns `None` the capture
/// group did not match or if there is no group with the given name.
pub fn Captures::name(self : Captures, name : String) -> Match? {
  match self.named_groups.get(name) {
    Some(i) => self.get(i)
    None => None
  }
}

///|
/// Expands all instances of `$group` in `replacement` to the corresponding
/// capture group `name`, and appends them to `dst`.
///
/// `group` may be an integer corresponding to the index of the capture group
/// (counted by order of opening parenthesis where `\0` is the entire match)
/// or it can be a name (consisting of letters, digits or underscores)
/// corresponding to a named capture group.
///
/// If `group` isn't a valid capture group (whether the name doesn't exist or
/// isn't a valid index), then it is replaced with the empty string.
///
/// The longest possible name is used. e.g., `$1a` looks up the capture group
/// named `1a` and not the capture group at index `1`. To exert more precise
/// control over the name, use braces, e.g., `${1}a`.
///
/// To write a literal `$`, use `$$`.
pub fn Captures::expand(
  self : Captures,
  replacement : String,
  dst : StringBuilder,
) -> Unit {
  Expander::default().append_expansion(dst, replacement, self)
}

///|
/// Iterate over the captured groups in order in which they appeared in the
/// regex. The first capture corresponds to the whole match.
pub fn Captures::iter(self : Captures) -> Iter[Match?] {
  let mut i = 0
  Iter::new(() => if i < self.len() {
    let result = self.get(i)
    i += 1
    Some(result)
  } else {
    None
  })
}

///|
/// How many groups were captured. This is always at least 1 because group 0
/// returns the whole match.
pub fn Captures::len(self : Captures) -> Int {
  self.saves.length() / 2
}

///|
/// Get a group's text by index. Aborts if there is no group at the given
/// index (upstream `Index<usize>`).
pub fn Captures::at(self : Captures, i : Int) -> String {
  match self.get(i) {
    Some(m) => m.as_str()
    None => abort("no group at index '\{i}'")
  }
}

///|
/// Get a group's text by name. Aborts if there is no group named by the
/// given value (upstream `Index<&str>`).
pub fn Captures::at_name(self : Captures, name : String) -> String {
  match self.name(name) {
    Some(m) => m.as_str()
    None => abort("no group named '\{name}'")
  }
}

///|
/// An iterator over all substrings delimited by a regex.
pub struct Split {
  priv matches : Matches
  /// Char position.
  priv mut next_start : Int
  priv target : Text
}

///|
/// Returns the next substring that results from splitting the target string
/// by the regex.
///
/// If no more matches are found, returns the remaining part of the string,
/// or `None` if all substrings have been yielded.
pub fn Split::next(self : Split) -> Result[String, FancyError]? {
  match self.matches.next() {
    None => {
      let len = self.target.hay.char_len()
      if self.next_start > len {
        // No more substrings to return
        None
      } else {
        // Return the last part of the target string
        // Next call will return None
        let part = self.target.hay.substring(self.next_start, len)
        self.next_start = len + 1
        Some(Ok(part))
      }
    }
    // Return the next substring
    Some(Ok(m)) => {
      let part = self.target.hay.substring(self.next_start, m.start_char)
      self.next_start = m.end_char
      Some(Ok(part))
    }
    Some(Err(e)) => Some(Err(e))
  }
}

///|
pub fn Split::iter(self : Split) -> Iter[Result[String, FancyError]] {
  Iter::new(() => self.next())
}

///|
/// An iterator over at most `N` substrings delimited by a regex.
pub struct SplitN {
  priv splits : Split
  priv mut limit : Int
}

///|
/// Returns the next substring resulting from splitting the target by the
/// regex, limited to `N` splits.
pub fn SplitN::next(self : SplitN) -> Result[String, FancyError]? {
  if self.limit == 0 {
    // Limit reached. No more substrings available.
    return None
  }

  // Decrement the limit for each split.
  self.limit -= 1
  if self.limit > 0 {
    return self.splits.next()
  }

  // Nth split
  let len = self.splits.target.hay.char_len()
  if self.splits.next_start > len {
    // No more substrings available.
    None
  } else {
    // Return the remaining part of the target
    let start = self.splits.next_start
    self.splits.next_start = len + 1
    Some(Ok(self.splits.target.hay.substring(start, len)))
  }
}

///|
pub fn SplitN::iter(self : SplitN) -> Iter[Result[String, FancyError]] {
  Iter::new(() => self.next())
}
