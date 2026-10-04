// Port of `hayagriva/src/lang/mod.rs`: language-dependant string
// transformations.
//
// Buffer positions are UTF-16 indices into the MoonBit string; wherever
// upstream compares byte lengths with constants, the UTF-8 length of the
// respective range is used instead.

///|
/// Rules for the title case transformation.
pub(all) struct TitleCase {
  /// Always capitalize after a full stop, question or exclamation mark, and
  /// colon even if the punctuation is followed by a word on the
  /// capitalization blacklist.
  always_capitalize_after_punctuation : Bool
  /// Always capitalize the last word of the title, even if it is on the
  /// capitalization blacklist.
  always_capitalize_last_word : Bool
  /// Always capitalize a word matching or exceeding a certain length, even
  /// if it is on the capitalization blacklist.
  always_capitalize_min_len : Int?
  /// Treat the hyphen as a word separator, i. e. capitalize in hyphenated
  /// expressions.
  hyphen_word_separator : Bool
  /// Do not touch all-uppercase words like "USA" if the title contains
  /// lower-case characters at all.
  keep_all_uppercase_words : Bool
  /// Enable usage of the capitalization blacklist.
  use_exception_dictionary : Bool
  /// Discard whitespace at the start of the title.
  trim_start : Bool
  /// Discard whitespace at the end of the title.
  trim_end : Bool
} derive(Eq, Hash, Debug)

///|
pub impl Default for TitleCase with fn default() {
  {
    always_capitalize_after_punctuation: true,
    always_capitalize_last_word: false,
    always_capitalize_min_len: None,
    hyphen_word_separator: true,
    keep_all_uppercase_words: true,
    use_exception_dictionary: true,
    trim_start: true,
    trim_end: true,
  }
}

///|
/// Rules for the sentence case transformation.
pub(all) struct SentenceCase {
  /// Capitalize words that contain caps in a non-start position (e. g.
  /// `fahrCard`).
  capitalize_words_with_caps_inside : Bool
  /// Enables the output of characters that directly follow a dot in the case
  /// that they appear in the source argument (e. g. `fig. 4.C`).
  do_not_format_after_dot : Bool
  /// Do not touch all-uppercase words like "ISS" if the title contains
  /// lower-case characters at all.
  keep_all_uppercase_words : Bool
  /// Enable usage of the capitalization whitelist.
  use_exception_dictionary : Bool
  /// Discard whitespace at the start of the title.
  trim_start : Bool
  /// Discard whitespace at the end of the title.
  trim_end : Bool
} derive(Eq, Hash, Debug)

///|
pub impl Default for SentenceCase with fn default() {
  {
    capitalize_words_with_caps_inside: true,
    do_not_format_after_dot: true,
    keep_all_uppercase_words: true,
    use_exception_dictionary: true,
    trim_start: true,
    trim_end: true,
  }
}

///|
/// Which case to transform to
pub(all) enum Case {
  /// Capitalize all words except for some words using customary English
  /// rules.
  Title(TitleCase)
  /// Capitalize at the start of sentences as well as proper nouns.
  Sentence(SentenceCase)
  /// CAPITALIZE EVERYTHING.
  Uppercase
  /// lowercase everything.
  Lowercase
  /// Do not apply a case transformation.
  NoTransform
  /// Capitalize the first letter of the first word if it is lowercase.
  FirstUpper
  /// Capitalize the first letter of each word.
  AllUpper
} derive(Eq, Hash, Debug)

///|
pub impl Default for Case with fn default() {
  NoTransform
}

///|
/// Transform a string to a case.
pub fn Case::transform(self : Case, s : String) -> String {
  let buf = CaseFolder::with_config(self)
  buf.push_str(s)
  buf.finish()
}

///|
/// `impl From<TextCase> for Case`.
pub fn Case::from_text_case(case : @citationberg.TextCase) -> Case {
  match case {
    Uppercase => Uppercase
    Lowercase => Lowercase
    TitleCase => Title(TitleCase::default())
    SentenceCase => Sentence(SentenceCase::default())
    CapitalizeFirst => FirstUpper
    CapitalizeAll => AllUpper
  }
}

///|
priv enum CharClass {
  NewSentence
  MaybeNewSentence
  NewSubclause
  MaybeSubclause
  NewWord
  InWord
} derive(Eq)

///|
fn CharClass::step(
  self : CharClass,
  c : Char,
  hyphen_separates : Bool,
) -> CharClass {
  match c {
    '.' | '?' | '!' | '…' | '‽' | '。' | ':' =>
      if self.is_in_word() {
        MaybeNewSentence
      } else {
        self
      }
    '(' | '[' | '{' => NewSubclause
    ')' | ']' | '}' => self
    '"' | '”' | '“' | '»' | '›' | '«' | '‹' | '‘' | '\'' => self
    ',' | ';' => if self.is_in_word() { MaybeSubclause } else { self }
    _ if @unscanny.is_whitespace(c) ||
      (hyphen_separates && c is ('-' | '–' | '—')) =>
      match self {
        MaybeNewSentence => NewSentence
        MaybeSubclause => NewSubclause
        InWord => NewWord
        _ => self
      }
    _ => InWord
  }
}

///|
fn CharClass::is_new_sentence(self : CharClass) -> Bool {
  self is NewSentence
}

///|
fn CharClass::is_new_subclause(self : CharClass) -> Bool {
  self is (NewSubclause | NewSentence)
}

///|
fn CharClass::is_new_word(self : CharClass) -> Bool {
  self is (NewWord | NewSubclause | NewSentence)
}

///|
fn CharClass::is_in_word(self : CharClass) -> Bool {
  self is (InWord | MaybeSubclause | MaybeNewSentence)
}

///|
priv enum WordCase {
  Lowercase
  HasNonStartUpper
  AllUpper
} derive(Eq)

///|
fn WordCase::feed(self : WordCase, is_upper : Bool, second : Bool) -> WordCase {
  match (self, is_upper, second) {
    (Lowercase, true, _) => HasNonStartUpper
    (AllUpper, false, false) => HasNonStartUpper
    (AllUpper, false, true) => Lowercase
    _ => self
  }
}

///|
priv struct WordData {
  start : Int
  end : Int
  case_ : WordCase
  follows_punctuation : Bool
  start_was_upper : Bool
}

///|
fn WordData::new(
  c : Char,
  buf_before : Int,
  buf_now : Int,
  prev_class : CharClass,
  char_class : CharClass,
) -> WordData? {
  let start_was_upper = @unscanny.is_uppercase(c)
  if char_class.is_in_word() {
    Some({
      start: buf_before,
      end: buf_now,
      case_: if start_was_upper {
        AllUpper
      } else {
        Lowercase
      },
      follows_punctuation: prev_class.is_new_subclause(),
      start_was_upper,
    })
  } else {
    None
  }
}

///|
fn WordData::feed(
  self : WordData,
  c : Char,
  buf : String,
  buf_before : Int,
  buf_now : Int,
  prev_class : CharClass,
  char_class : CharClass,
) -> WordData? {
  if char_class.is_new_word() {
    return None
  }
  if !prev_class.is_in_word() && char_class == InWord {
    let start_was_upper = @unscanny.is_uppercase(c)
    return Some({
      start: buf_before,
      end: buf_now,
      case_: if start_was_upper {
        AllUpper
      } else {
        Lowercase
      },
      follows_punctuation: prev_class.is_new_subclause(),
      start_was_upper,
    })
  }
  // Upstream compares byte offsets: `self.end - self.start == 1`.
  let second = range_len_utf8(buf, self.start, self.end) == 1
  let case_ = if c.is_ascii_punctuation() {
    self.case_
  } else {
    self.case_.feed(@unscanny.is_uppercase(c), second)
  }
  Some({
    start: self.start,
    end: buf_now,
    case_,
    follows_punctuation: self.follows_punctuation,
    start_was_upper: self.start_was_upper,
  })
}

///|
/// The UTF-8 length of `buf[start:end]` (clamped).
fn range_len_utf8(buf : String, start : Int, end : Int) -> Int {
  let n = buf.length()
  let s = if start > n { n } else { start }
  let e = if end > n { n } else { end }
  if e <= s {
    0
  } else {
    @unscanny.len_utf8(buf[s:e])
  }
}

///|
fn WordData::is_all_upper(self : WordData, buf : String) -> Bool {
  self.case_ is AllUpper && range_len_utf8(buf, self.start, self.end) > 1
}

///|
fn WordData::is_continuing_word(self : WordData, other : WordData?) -> Bool {
  match other {
    Some(other) => self.start == other.start
    None => false
  }
}

///|
priv enum WordVerdict {
  AllUpper
  Capitalize
  Lowercase
  Keep
}

///|
/// Buffer that adjusts word case on the fly.
pub struct CaseFolder {
  priv mut case_ : Case
  /// Only true if the only characters after a configuration change were
  /// whitespace.
  priv mut pristine : Bool
  priv mut char_class : CharClass
  priv mut buf : String
  /// Index of finished at which the last configuration change happened.
  priv mut last_reconfig : Int
  /// Index of the last word in the buffer.
  priv mut last_word : WordData?
}

///|
/// Create a new case folder.
pub fn CaseFolder::new() -> CaseFolder {
  {
    case_: NoTransform,
    pristine: true,
    char_class: NewSentence,
    buf: "",
    last_reconfig: 0,
    last_word: None,
  }
}

///|
/// Create a case folder with a case configuration.
pub fn CaseFolder::with_config(case_ : Case) -> CaseFolder {
  let f = CaseFolder::new()
  f.case_ = case_
  f
}

///|
/// Add a string to the buffer.
pub fn CaseFolder::push_str(self : CaseFolder, s : String) -> Unit {
  match self.case_ {
    NoTransform => {
      self.buf = self.buf + s
      self.char_class = NewSentence
    }
    Uppercase => {
      self.buf = self.buf + @unscanny.to_uppercase(s)
      self.char_class = NewSentence
    }
    Lowercase => {
      self.buf = self.buf + @unscanny.to_lowercase(s)
      self.char_class = NewSentence
    }
    _ =>
      for c in s {
        self.push(c)
      }
  }
  self.pristine = false
}

///|
/// Prevent whitespace trimming before and after the current position.
pub fn CaseFolder::prevent_trimming(self : CaseFolder) -> Unit {
  self.last_reconfig = self.buf.length()
  self.pristine = false
}

///|
/// Add a string chunk to the buffer.
pub fn CaseFolder::push_verbatim(self : CaseFolder, value : String) -> Unit {
  let conf = self.case_
  self.case_ = NoTransform
  self.last_reconfig = self.buf.length()
  self.push_str(value)
  self.last_reconfig = self.buf.length()
  self.case_ = conf
  self.char_class = InWord
}

///|
/// Add a character to the buffer.
pub fn CaseFolder::push(self : CaseFolder, c : Char) -> Unit {
  let prev_class = self.char_class
  let hyphen_separates = match self.case_ {
    Title(props) => props.hyphen_word_separator
    _ => false
  }
  self.char_class = prev_class.step(c, hyphen_separates)
  let old_buf_len = self.buf.length()
  match self.case_ {
    Title(config) if config.trim_start &&
      self.pristine &&
      @unscanny.is_whitespace(c) => ()
    Title(_) =>
      if prev_class.is_new_word() {
        self.buf = self.buf + @unscanny.char_to_uppercase(c)
      } else {
        self.buf = self.buf + @unscanny.char_to_lowercase(c)
      }
    Sentence(config) if config.trim_start &&
      self.pristine &&
      @unscanny.is_whitespace(c) => ()
    Sentence(config) =>
      if prev_class.is_new_sentence() {
        self.buf = self.buf + @unscanny.char_to_uppercase(c)
      } else if config.do_not_format_after_dot &&
        prev_class is (MaybeNewSentence | MaybeSubclause) {
        self.buf = self.buf + c.to_string()
      } else {
        self.buf = self.buf + @unscanny.char_to_lowercase(c)
      }
    FirstUpper =>
      if self.pristine && @unscanny.is_lowercase(c) {
        self.buf = self.buf + @unscanny.char_to_uppercase(c)
      } else {
        self.buf = self.buf + c.to_string()
      }
    AllUpper =>
      if prev_class.is_new_word() && @unscanny.is_lowercase(c) {
        self.buf = self.buf + @unscanny.char_to_uppercase(c)
      } else {
        self.buf = self.buf + c.to_string()
      }
    Uppercase => self.buf = self.buf + @unscanny.char_to_uppercase(c)
    Lowercase => self.buf = self.buf + @unscanny.char_to_lowercase(c)
    NoTransform => self.buf = self.buf + c.to_string()
  }
  self.last_word = match self.last_word {
    Some(data) => {
      let new_data = data.feed(
        c,
        self.buf,
        old_buf_len,
        self.buf.length(),
        prev_class,
        self.char_class,
      )
      if !data.is_continuing_word(new_data) {
        self.process_word()
      }
      new_data
    }
    None =>
      WordData::new(
        c,
        old_buf_len,
        self.buf.length(),
        prev_class,
        self.char_class,
      )
  }
  self.pristine = self.pristine && @unscanny.is_whitespace(c)
}

///|
/// Find the word with only alphabetic characters that starts at
/// `self.last_word.start`.
fn CaseFolder::find_word(self : CaseFolder) -> String? {
  guard self.last_word is Some(data) else { return None }
  let n = self.buf.length()
  let start = if data.start > n { n } else { data.start }
  let end = if data.end > n { n } else { data.end }
  let mut alphabetic_end = start
  while alphabetic_end < end {
    let (c, next) = @unicode.decode_at(self.buf, alphabetic_end)
    if !@unscanny.is_alphanumeric(Int::unsafe_to_char(c)) {
      break
    }
    alphabetic_end = next
  }
  Some(self.buf[start:alphabetic_end].to_owned())
}

///|
fn CaseFolder::process_word(self : CaseFolder) -> Unit {
  let mut verdict = WordVerdict::Keep
  guard self.last_word is Some(data) else { return }
  match self.case_ {
    Title(config) =>
      if config.keep_all_uppercase_words && data.is_all_upper(self.buf) {
        verdict = AllUpper
      } else if config.use_exception_dictionary {
        // Check if the word should be decapitalized.
        let mut lookup = true

        // Do not lowercase if the word follows punctuation.
        lookup = lookup &&
          (
            !config.always_capitalize_after_punctuation ||
            !data.follows_punctuation
          )
        if config.always_capitalize_min_len is Some(min_len) {
          // Do not lowercase if word is too long.
          lookup = lookup &&
            range_len_utf8(self.buf, data.start, data.end) < min_len
        }
        let term = self.find_word().unwrap_or("")
        if lookup {
          verdict = if rust_binary_search(never_capitalize, term) {
            Lowercase
          } else {
            Keep
          }
        }
      }
    Sentence(config) =>
      if config.capitalize_words_with_caps_inside &&
        data.case_ == HasNonStartUpper {
        verdict = Capitalize
      } else if config.keep_all_uppercase_words && data.is_all_upper(self.buf) {
        verdict = AllUpper
      } else if config.use_exception_dictionary {
        let term = self.find_word().unwrap_or("")
        verdict = if rust_binary_search(always_capitalize, term) {
          Capitalize
        } else {
          Keep
        }
      }
    _ => ()
  }
  match verdict {
    AllUpper =>
      self.buf = map_chars(self.buf, data.start, data.end, c => {
        if @unscanny.is_lowercase(c) {
          Some(@unscanny.char_to_uppercase(c))
        } else {
          None
        }
      })
    Capitalize => self.buf = capitalize_char(self.buf, data.start)
    Lowercase =>
      if data.start < self.buf.length() {
        let (ci, next) = @unicode.decode_at(self.buf, data.start)
        let c = Int::unsafe_to_char(ci)
        if @unscanny.is_uppercase(c) {
          self.buf = map_chars(self.buf, data.start, next, c => {
            Some(@unscanny.char_to_lowercase(c))
          })
        }
      }
    Keep => ()
  }
}

///|
fn CaseFolder::may_trim_end(self : CaseFolder) -> Unit {
  let trim = match self.case_ {
    Title(config) => config.trim_end
    Sentence(config) => config.trim_end
    _ => false
  }

  // Trim all whitespace at the end of the buffer until self.last_reconfig.
  while trim && self.buf.length() > self.last_reconfig {
    match @unscanny.last_char(self.buf) {
      Some(c) if @unscanny.is_whitespace(c) =>
        self.buf = self.buf[:self.buf.length() - c.utf16_len()].to_owned()
      _ => break
    }
  }
  match self.case_ {
    Title(config) if config.always_capitalize_last_word => {
      let start = match self.last_word {
        Some(data) => Some(data.start)
        None => {
          let mut idx = None
          let mut i = self.buf.length()
          while i > 0 {
            let (c, prev) = @unicode.decode_before(self.buf, i)
            if @unscanny.is_whitespace(Int::unsafe_to_char(c)) {
              idx = Some(i)
              break
            }
            i = prev
          }
          idx
        }
      }
      guard start is Some(start) else { return }
      if start < self.last_reconfig || start >= self.buf.length() {
        return
      }
      self.buf = capitalize_char(self.buf, start)
    }
    _ => ()
  }
}

///|
/// Retrieve the configuration of the CaseFolder.
pub fn CaseFolder::case(self : CaseFolder) -> Case {
  self.case_
}

///|
/// Change the configuration of the CaseFolder.
pub fn CaseFolder::reconfigure(self : CaseFolder, case_ : Case) -> Unit {
  if self.case_ == case_ {
    return
  }
  self.may_trim_end()
  self.last_reconfig = self.buf.length()
  self.pristine = true
  self.case_ = case_
}

///|
/// Yield the transformed string.
pub fn CaseFolder::finish(self : CaseFolder) -> String {
  self.process_word()
  self.may_trim_end()
  self.buf
}

///|
/// Whether the buffer is empty.
pub fn CaseFolder::is_empty(self : CaseFolder) -> Bool {
  self.buf.is_empty()
}

///|
/// Return the length of the buffer.
pub fn CaseFolder::len(self : CaseFolder) -> Int {
  self.buf.length()
}

///|
/// Whether the buffer contains only whitespace.
pub fn CaseFolder::has_content(self : CaseFolder) -> Bool {
  !self.buf.iter().all(@unscanny.is_whitespace)
}

///|
/// The buffer as a string (upstream `as_string_mut`, read side).
pub fn CaseFolder::buf_string(self : CaseFolder) -> String {
  self.buf
}

///|
/// Replace the buffer (upstream `as_string_mut`, write side). Must call
/// [`Self::mark_changed`] if the length of the string is changed.
pub fn CaseFolder::set_buf_string(self : CaseFolder, s : String) -> Unit {
  self.buf = s
}

///|
/// Check if the buffer ends with a character.
pub fn CaseFolder::ends_with(self : CaseFolder, pattern : Char) -> Bool {
  @unscanny.last_char(self.buf) == Some(pattern)
}

///|
/// Notify the struct that an outside manipulation to the underlying buffer
/// occurred.
pub fn CaseFolder::mark_changed(self : CaseFolder) -> Unit {
  self.last_reconfig = self.buf.length()
  self.last_word = None
}

///|
pub impl FmtWrite for CaseFolder with fn write_str(self, s) {
  self.push_str(s)
}

///|
pub impl FmtWrite for CaseFolder with fn write_char(self, c) {
  self.push(c)
}

///|
/// Maps the characters inside of a string. The mapping function returns
/// the replacement or `None` to indicate that the current character should
/// not be replaced.
fn map_chars(
  buf : String,
  start : Int,
  end : Int,
  f : (Char) -> String?,
) -> String {
  let out = StringBuilder()
  out.write_string(buf[:start].to_owned())
  let mut i = start
  while i < buf.length() && i < end {
    let (ci, next) = @unicode.decode_at(buf, i)
    let c = Int::unsafe_to_char(ci)
    match f(c) {
      Some(rep) => out.write_string(rep)
      None => out.write_char(c)
    }
    i = next
  }
  out.write_string(buf[i:].to_owned())
  out.to_string()
}

///|
fn capitalize_char(buf : String, start : Int) -> String {
  if start >= buf.length() {
    return buf
  }
  let (ci, next) = @unicode.decode_at(buf, start)
  let c = Int::unsafe_to_char(ci)
  if @unscanny.is_lowercase(c) {
    map_chars(buf, start, next, c => Some(@unscanny.char_to_uppercase(c)))
  } else {
    buf
  }
}

///|
/// Check if a character is a CJK character.
pub fn is_cjk(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  (cp >= 0x20000 && cp <= 0x2A6DF) ||
  (cp >= 0x2A700 && cp <= 0x2B73F) ||
  (cp >= 0x2B740 && cp <= 0x2B81F) ||
  (cp >= 0x2B820 && cp <= 0x2CEAF) ||
  (cp >= 0xF900 && cp <= 0xFAFF) ||
  (cp >= 0x2F800 && cp <= 0x2FA1F)
}

///|
/// Rust's `<[&str]>::binary_search(&x).is_ok()`, replicating the exact probe
/// sequence of the standard library (the word lists are not all sorted).
pub fn rust_binary_search(list : ReadOnlyArray[String], x : String) -> Bool {
  let mut size = list.length()
  if size == 0 {
    return false
  }
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    let cmp = @unscanny.compare_str(list[mid], x)
    if cmp <= 0 {
      base = mid
    }
    size -= half
  }
  @unscanny.compare_str(list[base], x) == 0
}
