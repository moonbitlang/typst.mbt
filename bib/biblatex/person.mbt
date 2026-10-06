// Port of `biblatex/src/types/person.rs`.

///|
/// An author, editor, or some other person affiliated with a cited work.
///
/// When parsed through [`Person::parse`], the whitespace is trimmed from the
/// fields.
pub(all) struct Person {
  /// The surname / family name / last name.
  name : String
  /// The given name / first name / forename.
  given_name : String
  /// The prefix is placed between given name and name. It could, for
  /// example, be a nobiliary particle.
  prefix : String
  /// The suffix is placed after the name (e.g., "Jr.").
  suffix : String
  /// A special parameter which may be used to override the hash used to
  /// detect identical names.
  id : String?
  /// Manual initials for the preifx.
  prefix_initials : String?
  /// Manual initials for the given name.
  given_initials : String?
  /// Whether the prefix of this name should be considered part of the family
  /// name.
  use_prefix : Bool?
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Person with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Person with @debug.Debug::{to_repr}

///|
fn Person::simple(
  name : String,
  given_name : String,
  prefix : String,
  suffix : String,
) -> Person {
  {
    name,
    given_name,
    prefix,
    suffix,
    id: None,
    prefix_initials: None,
    given_initials: None,
    use_prefix: None,
  }
}

///|
/// Constructs a new person from a chunk vector:
/// 1. according to the specs of Nicolas Markey in "Tame the BeaST",
///    pp. 23-24.
/// 2. biblatex extended name format according to the documentation of
///    biblatex, section 3.4 pp. 80-81, and section §4.2.3 pp. 164-165.
///    Support is limited to default `nameparts`: prefix, family, suffix,
///    given, and `id`, `prefix-i`, `useprefix`.
pub fn Person::parse(chunks : ArrayView[Spanned[Chunk]]) -> Person {
  // Extended Name Format
  if chunks.iter().any(val => val.v.get().contains("=")) {
    return Person::parse_extended_name_format(chunks)
  }
  // BibTeX
  Person::parse_bibtex(chunks)
}

///|
/// Constructs new person from chunk slices.
fn Person::parse_extended_name_format(
  chunks : ArrayView[Spanned[Chunk]],
) -> Person {
  let person : Map[String, String] = Map([])
  for chunk in split_token_lists(chunks, ",") {
    let (key, value) = split_at_normal_char(chunk, '=', true)
    let key = format_verbatim(key)
    let value = format_verbatim(value)
    person.set(key, value)
  }
  let take = (k : String) => {
    let v = person.get(k)
    person.remove(k)
    v
  }
  let name = take("family").unwrap_or("")
  let given_name = take("given").unwrap_or("")
  let prefix = take("prefix").unwrap_or("")
  let suffix = take("suffix").unwrap_or("")
  let id = take("id")
  let prefix_initials = take("prefix-i")
  let given_initials = take("given-i")
  let use_prefix = take("useprefix").map(p => p == "true")
  {
    name,
    given_name,
    prefix,
    suffix,
    id,
    prefix_initials,
    given_initials,
    use_prefix,
  }
}

///|
fn Person::parse_bibtex(chunks : ArrayView[Spanned[Chunk]]) -> Person {
  let num_commas = count_num_char(chunks, ',')
  match num_commas {
    0 => Person::parse_unified(chunks) // `<First> <Prefix> <Last>`
    1 => {
      let (v1, v2) = split_at_normal_char(chunks, ',', true)
      Person::parse_single_comma(v1, v2)
    } // `<Prefix> <Last>, <First>`
    _ => {
      let (v1, v2) = split_at_normal_char(chunks, ',', true)
      let (v2, v3) = split_at_normal_char(v2, ',', true)
      Person::parse_two_commas(v1, v2, v3)
    } // `<Prefix> <Last>, <Suffix>, <First>`.
  }
}

///|
/// Constructs new person from a chunk slice if in the form
/// `<First> <Prefix> <Last>`.
fn Person::parse_unified(chunks : ArrayView[Spanned[Chunk]]) -> Person {
  // Find end of first sequence of capitalized words (denominated by first
  // lowercase word), start of last capitalized sequence.
  // If there is no subsequent capitalized word, take last one.
  // Treat verbatim as capital letters.
  let mut word_start = true
  let mut capital = false
  let mut seen_lowercase = false
  let mut seen_uppercase = false
  let mut seen_uppercase2 = false
  let mut cap_new_start = 0
  let mut cap_word_end = 0
  let mut last_word_start = 0
  let mut last_lowercase_start = 0
  let cc = chunk_chars(chunks)
  for index, pair in cc {
    let (c, v) = pair
    if @unscanny.is_whitespace(c) && !v {
      word_start = true
      continue
    }
    if word_start {
      last_word_start = index
      capital = if v || @unscanny.is_uppercase(c) {
        seen_uppercase = true
        if seen_lowercase && last_lowercase_start >= cap_new_start {
          seen_uppercase2 = true
          cap_new_start = index
        }
        true
      } else {
        last_lowercase_start = index
        seen_lowercase = true
        false
      }
    }
    if capital && !seen_lowercase {
      cap_word_end = index
    }
    word_start = false
  }
  let name = StringBuilder()
  let given_name = StringBuilder()
  let prefix = StringBuilder()
  for index, pair in cc {
    let (c, _) = pair
    if (
        index <= cap_word_end &&
        seen_lowercase &&
        seen_uppercase &&
        !(index == 0 && @unscanny.is_lowercase(c))
      ) ||
      (index < last_word_start && !seen_lowercase) {
      given_name.write_char(c)
    } else if (index < cap_new_start && cap_new_start > cap_word_end) ||
      (
        index < last_word_start &&
        (
          !seen_uppercase2 ||
          (last_word_start == last_lowercase_start && index < cap_new_start)
        )
      ) {
      prefix.write_char(c)
    } else {
      name.write_char(c)
    }
  }
  Person::simple(
    @unscanny.trim_start(name.to_string()),
    @unscanny.trim_end(given_name.to_string()),
    @unscanny.trim(prefix.to_string()),
    "",
  )
}

///|
/// Constructs new person from chunk slices if in the form
/// `<Prefix> <Last>, <First>`.
/// - `s1` corresponds to the part before the comma,
/// - `s2` to the part behind it.
///
/// The arguments should not contain the comma.
fn Person::parse_single_comma(
  s1 : ArrayView[Spanned[Chunk]],
  s2 : ArrayView[Spanned[Chunk]],
) -> Person {
  if s2.is_empty() || (s2.length() == 1 && format_verbatim(s2).is_empty()) {
    let formatted = format_verbatim(s1)
    let last_space = formatted.rev_find(" ").unwrap_or(0)
    let prefix = formatted[:last_space].to_owned()
    let last = formatted[last_space:].to_owned()
    return Person::simple(
      @unscanny.trim_start(last),
      "",
      @unscanny.trim_end(prefix),
      "",
    )
  }
  let given_name = format_verbatim(s2)
  let mut word_start = true
  let mut last_lower_case_end = -1
  let mut is_lowercase = false
  let mut last_word_start = 0
  let mut has_seen_uppercase_words = false
  let cc = chunk_chars(s1)
  for index, pair in cc {
    let (c, v) = pair
    if @unscanny.is_whitespace(c) && !v {
      word_start = true
      continue
    }
    if word_start {
      last_word_start = index
      if @unscanny.is_lowercase(c) || v {
        is_lowercase = true
      } else {
        is_lowercase = false
        has_seen_uppercase_words = true
      }
    }
    if is_lowercase {
      last_lower_case_end = index
    }
    word_start = false
  }
  let name = StringBuilder()
  let prefix = StringBuilder()
  for index, pair in cc {
    let (c, _) = pair
    if (index <= last_lower_case_end && has_seen_uppercase_words) ||
      (!has_seen_uppercase_words && index < last_word_start) {
      prefix.write_char(c)
    } else if has_seen_uppercase_words || index >= last_word_start {
      name.write_char(c)
    }
  }
  Person::simple(
    @unscanny.trim_start(name.to_string()),
    @unscanny.trim_start(given_name),
    @unscanny.trim_end(prefix.to_string()),
    "",
  )
}

///|
/// Constructs new person from chunk slices if in the form
/// `<Prefix> <Last>, <Suffix>, <First>`.
fn Person::parse_two_commas(
  s1 : ArrayView[Spanned[Chunk]],
  s2 : ArrayView[Spanned[Chunk]],
  s3 : ArrayView[Spanned[Chunk]],
) -> Person {
  let p = Person::parse_single_comma(s1, s3)
  { ..p, suffix: format_verbatim(s2), }
}

///|
/// `impl Type for Vec<Person>`.
pub fn parse_persons(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Array[Person], TypeError] {
  Ok(split_token_lists_with_kw(chunks, "and").map(sub => Person::parse(sub)))
}

///|
pub impl Show for Person with fn output(self, logger) {
  if !self.given_name.is_empty() {
    logger.write_string(self.given_name + " ")
  }
  if !self.prefix.is_empty() {
    logger.write_string(self.prefix + " ")
  }
  logger.write_string(self.name)
  if !self.suffix.is_empty() {
    logger.write_string(" " + self.suffix)
  }
}

///|
pub extend Person with Show::{to_string, output}
