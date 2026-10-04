// Port of `hayagriva/src/types/persons.rs`.

///|
/// A list of persons with a common role.
pub(all) struct PersonsWithRoles {
  /// The persons.
  names : Array[Person]
  /// The role the persons had in the creation of the cited item.
  role : PersonRole
} derive(Eq, Hash, Debug)

///|
/// Create a new list of persons with a common role.
pub fn PersonsWithRoles::new(
  names : Array[Person],
  role : PersonRole,
) -> PersonsWithRoles {
  { names, role, }
}

///|
/// Specifies the role a group of persons had in the creation to the cited
/// item.
pub(all) enum PersonRole {
  /// Translated the work from a foreign language to the cited edition.
  Translator
  /// Authored an afterword.
  Afterword
  /// Authored an foreword.
  Foreword
  /// Authored an introduction.
  Introduction
  /// Provided value-adding annotations.
  Annotator
  /// Commented the work.
  Commentator
  /// Holds a patent or similar.
  Holder
  /// Compiled the works in an Anthology.
  Compiler
  /// Founded the publication.
  Founder
  /// Collaborated on the cited item.
  Collaborator
  /// Organized the creation of the cited item.
  Organizer
  /// Performed in the cited item.
  CastMember
  /// Composed all or parts of the cited item's musical / audible
  /// components.
  Composer
  /// Produced the cited item.
  Producer
  /// Lead Producer for the cited item.
  ExecutiveProducer
  /// Did the writing for the cited item.
  Writer
  /// Shot film/video for the cited item.
  Cinematography
  /// Directed the cited item.
  Director
  /// Illustrated the cited item.
  Illustrator
  /// Provided narration or voice-over for the cited item.
  Narrator
  /// Various other roles described by the contained string.
  Unknown(String)
} derive(Eq, Hash, Debug)

///|
/// Serde (kebab-case) names of the person roles.
pub fn PersonRole::from_str(s : String) -> PersonRole? {
  match s {
    "translator" => Some(Translator)
    "afterword" => Some(Afterword)
    "foreword" => Some(Foreword)
    "introduction" => Some(Introduction)
    "annotator" => Some(Annotator)
    "commentator" => Some(Commentator)
    "holder" => Some(Holder)
    "compiler" => Some(Compiler)
    "founder" => Some(Founder)
    "collaborator" => Some(Collaborator)
    "organizer" => Some(Organizer)
    "cast-member" => Some(CastMember)
    "composer" => Some(Composer)
    "producer" => Some(Producer)
    "executive-producer" => Some(ExecutiveProducer)
    "writer" => Some(Writer)
    "cinematography" => Some(Cinematography)
    "director" => Some(Director)
    "illustrator" => Some(Illustrator)
    "narrator" => Some(Narrator)
    _ => None
  }
}

///|
/// Holds the name of a person.
pub(all) struct Person {
  /// The family name.
  name : String
  /// The given name / forename.
  given_name : String?
  /// A prefix of the family name such as 'van' or 'de'.
  prefix : String?
  /// A suffix of the family name such as 'Jr.' or 'IV'.
  suffix : String?
  /// Whether a comma should be inserted before the suffix.
  comma_suffix : Bool
  /// Another name (often user name) the person might be known under.
  alias_ : String?
} derive(Eq, Hash, Debug)

///|
/// Error that may occur when parsing a slice of strings as a name.
pub(all) enum PersonError {
  /// The name has too many parts to be appropriately parsed.
  TooManyParts
  /// The name is empty.
  Empty
  /// The role is unknown.
  UnknownRole
} derive(Eq, Debug)

///|
pub impl Show for PersonError with fn output(self, logger) {
  logger.write_string(
    match self {
      TooManyParts => "too many parts"
      Empty => "part list is empty"
      UnknownRole => "unknown role"
    },
  )
}

///|
/// This function expects a list of strings with its length between one and
/// three. The first part will be interpreted as the `<prefix> <Name>`, the
/// second part as the given name and the third part as the suffix.
pub fn Person::from_strings(
  parts : Array[String],
) -> Result[Person, PersonError] {
  if parts.is_empty() {
    return Err(Empty)
  } else if parts.length() > 3 {
    return Err(TooManyParts)
  }
  let parts = parts.map(p => @unscanny.trim(p))
  let last_pre = parts[0]
  let given_name = if parts.length() > 1 {
    Some(parts[parts.length() - 1])
  } else {
    None
  }
  let suffix = if parts.length() > 2 { Some(parts[1]) } else { None }
  let mut word_start = true
  let mut last_lower_case_end = -1
  let mut is_lowercase = false
  let mut last_word_start = 0
  let mut has_seen_uppercase_words = false
  let cs = @unscanny.chars(last_pre)
  for index, c in cs {
    if @unscanny.is_whitespace(c) {
      word_start = true
      continue
    }
    if word_start {
      last_word_start = index
      if @unscanny.is_lowercase(c) {
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
  for index, c in cs {
    if (index <= last_lower_case_end && has_seen_uppercase_words) ||
      (!has_seen_uppercase_words && index < last_word_start) {
      prefix.write_char(c)
    } else if has_seen_uppercase_words || index >= last_word_start {
      name.write_char(c)
    }
  }
  let prefix = prefix.to_string()
  let mut name = name.to_string()
  let prefix = if prefix.is_empty() { None } else { Some(prefix) }
  if prefix is Some(_) {
    name = @unscanny.trim_start(name)
  }
  Ok({ name, given_name, prefix, suffix, comma_suffix: false, alias_: None, })
}

///|
/// Formats the given name into initials.
///
/// For example, `"Judith Beatrice"` would yield `"J. B."` if the
/// `delimiter` argument is set to `Some(". ")`, `"Klaus-Peter"` would
/// become `"K-P"` without a delimiter (or with an empty delimiter).
pub fn[W : FmtWrite] Person::initials(
  self : Person,
  buf : W,
  delimiter : String?,
  with_hyphen : Bool,
) -> Unit {
  guard self.given_name is Some(gn) else { return }
  let mut collect = true
  let mut non_empty = false
  // Whether we are at the start of a word (i.e., the initial char or
  // following a whitespace)
  let mut start_of_word = true
  // Whether the last char (excl. whitespace was lower case)
  let mut last_was_lower = false
  let delim_ends_in_whitespace = match delimiter {
    Some(d) =>
      match @unscanny.last_char(d) {
        Some(c) => @unscanny.is_whitespace(c)
        None => false
      }
    None => false
  }
  for gr0 in @unicode.graphemes(gn) {
    let gr = gr0.to_owned()
    if @unscanny.first_char(gr) is Some(c) &&
      (@unscanny.is_whitespace(c) || c == '-') {
      // The last word was in lower case. We enounter a whitespace and stop
      // collecting
      if last_was_lower {
        collect = false
      }
      if !collect {
        let hyphenate = with_hyphen && c == '-'
        // Do not emit delim if we just had a lower case word
        if !last_was_lower && delimiter is Some(delimiter) {
          // Use the given delimiter, including any spaces at its end if
          // there was a whitespace, but not if we should add a hyphen in a
          // compound given name.
          buf.write_str(
            if hyphenate {
              @unscanny.trim_end(delimiter)
            } else {
              delimiter
            },
          )
        }
        collect = true
        start_of_word = true
        if hyphenate {
          buf.write_char('-')
        } else if last_was_lower {
          // Write a space after a lower case word
          buf.write_char(' ')
        }
      }
      continue
    }
    if collect {
      if @unscanny.to_lowercase(gr) != gr {
        // Upper case letter => stop collecting; print initials
        collect = false
        last_was_lower = false
      } else if start_of_word {
        // We enter a lower-cased word
        last_was_lower = true
      }
      if last_was_lower && start_of_word {
        start_of_word = false
        if !delim_ends_in_whitespace {
          // Print a space if we just started a lower case word and the
          // delimiter did not already put a space
          buf.write_char(' ')
        }
      }
      buf.write_str(gr)
      non_empty = true
    }
  }
  if non_empty && !collect && delimiter is Some(delim) {
    buf.write_str(@unscanny.trim_end(delim))
  }
}

///|
/// Yields the first name of a person. Will add the delimiter after
/// initials / single letters.
pub fn[W : FmtWrite] Person::first_name_with_delimiter(
  self : Person,
  buf : W,
  delimiter : String?,
) -> Unit {
  guard self.given_name is Some(name) else { return }
  let mut first = true
  for item in @unscanny.split(name, " ") {
    if !first {
      buf.write_char(' ')
    }
    buf.write_str(item)
    if delimiter is Some(delimiter) && @unicode.graphemes(item).length() == 1 {
      buf.write_str(delimiter)
    }
    first = false
  }
}

///|
/// Get the name with the family name first, the initials afterwards,
/// separated by a comma.
pub fn Person::name_first(
  self : Person,
  initials : Bool,
  prefix_given_name : Bool,
) -> String {
  let res = StrBuf::new()
  if !prefix_given_name {
    match self.prefix {
      Some(prefix) => res.write_str(prefix + " " + self.name)
      None => res.write_str(self.name)
    }
  } else {
    res.write_str(self.name)
  }
  if initials {
    if self.given_name is Some(_) {
      res.write_str(", ")
      self.initials(res, Some(". "), true)
    }
  } else if self.given_name is Some(given_name) {
    res.write_str(", ")
    res.write_str(given_name)
  }
  if prefix_given_name && self.prefix is Some(prefix) {
    if self.given_name is Some(_) {
      res.write_char(' ')
    }
    res.write_str(prefix)
  }
  if self.suffix is Some(suffix) {
    res.write_str(", ")
    res.write_str(suffix)
  }
  res.to_string()
}

///|
/// Get the name with the given name first, the family name afterwards.
pub fn Person::given_first(self : Person, initials : Bool) -> String {
  let res = StrBuf::new()
  if initials {
    if self.given_name is Some(_) {
      self.initials(res, Some(". "), true)
      res.write_char(' ')
    }
  } else if self.given_name is Some(given_name) {
    res.write_str(given_name)
    res.write_char(' ')
  }
  if self.prefix is Some(prefix) {
    res.write_str(prefix)
    res.write_str(" ")
  }
  res.write_str(self.name)
  if self.suffix is Some(suffix) {
    res.write_str(" ")
    res.write_str(suffix)
  }
  res.to_string()
}

///|
/// Get the non-dropping name particle in the family name.
pub fn Person::name_particle(self : Person) -> String? {
  let mut i = self.name.length()
  while i > 0 {
    let { cp: c, idx: prev, } = @unicode.decode_before(self.name, i)
    i = prev
    if c != ' '.to_int() {
      continue
    }
    let particle = self.name[0:i].to_owned()
    let lowercase = @unscanny.to_lowercase(particle)
    if rust_binary_search(name_particles, lowercase) {
      return Some(particle)
    }
  }
  None
}

///|
/// Get the family name without the non-dropping particle.
pub fn Person::name_without_particle(self : Person) -> String {
  match self.name_particle() {
    Some(particle) =>
      @unscanny.trim_start(self.name[particle.length():].to_owned())
    None => self.name
  }
}

///|
/// Get only the dropping and non-dropping particle of the family name.
pub fn Person::name_particles(self : Person) -> String? {
  match (self.prefix, self.name_particle()) {
    (Some(dropping), Some(non_dropping)) => Some(dropping + " " + non_dropping)
    (Some(dropping), None) => Some(dropping)
    (None, Some(non_dropping)) => Some(non_dropping)
    (None, None) => None
  }
}

///|
/// Whether to treat this as an institutional name.
pub fn Person::is_institutional(self : Person) -> Bool {
  self.given_name is None && self.suffix is None && self.prefix is None
}

///|
/// Whether the name contains CJK characters.
pub fn Person::is_cjk(self : Person) -> Bool {
  self.name.iter().any(is_cjk) ||
  (match self.given_name {
    Some(gn) => gn.iter().any(is_cjk)
    None => false
  })
}

///|
/// Get the name without the leading article.
pub fn Person::name_without_article(self : Person) -> String {
  match self.name.find(" ") {
    Some(space_idx) =>
      if space_idx + 1 != self.name.length() &&
        rust_binary_search(articles, self.name[0:space_idx].to_owned()) {
        self.name[space_idx + 1:].to_owned()
      } else {
        self.name
      }
    None => self.name
  }
}

///|
/// Compare optional strings like Rust's `Option<String>` ordering.
fn compare_opt_str(a : String?, b : String?) -> Int {
  match (a, b) {
    (None, None) => 0
    (None, Some(_)) => -1
    (Some(_), None) => 1
    (Some(a), Some(b)) => @unscanny.compare_str(a, b)
  }
}

///|
/// Order according to the CSL specification.
pub fn Person::csl_cmp(
  self : Person,
  other : Person,
  form : @citationberg.LongShortForm,
  demote_particle : Bool,
) -> Int {
  let self_cjk = self.is_cjk()
  let other_cjk = other.is_cjk()
  let name_a = @unscanny.to_lowercase(self.name)
  let name_b = @unscanny.to_lowercase(other.name)
  let given_a = self.given_name.map(s => @unscanny.to_lowercase(s))
  let given_b = other.given_name.map(s => @unscanny.to_lowercase(s))
  if self_cjk != other_cjk {
    // Put CJK names last.
    return compare_bool(self_cjk, other_cjk)
  } else if self_cjk && other_cjk {
    // Apply special CJK rules.
    return match form {
      Long => {
        let c = @unscanny.compare_str(name_a, name_b)
        if c != 0 {
          c
        } else {
          compare_opt_str(given_a, given_b)
        }
      }
      Short => @unscanny.compare_str(name_a, name_b)
    }
  }
  let prefix_a = self.prefix.map(s => @unscanny.to_lowercase(s))
  let prefix_b = other.prefix.map(s => @unscanny.to_lowercase(s))
  let suffix_a = self.suffix.map(s => @unscanny.to_lowercase(s))
  let suffix_b = other.suffix.map(s => @unscanny.to_lowercase(s))
  let chain = (cs : Array[() -> Int]) => {
    for c in cs {
      let v = c()
      if v != 0 {
        return v
      }
    }
    0
  }
  if demote_particle {
    chain([
      () => {
        @unscanny.compare_str(
          @unscanny.to_lowercase(self.name_without_particle()),
          @unscanny.to_lowercase(other.name_without_particle()),
        )
      },
      () => {
        compare_opt_str(
          self.name_particles().map(c => @unscanny.to_lowercase(c)),
          other.name_particles().map(c => @unscanny.to_lowercase(c)),
        )
      },
      () => compare_opt_str(given_a, given_b),
      () => compare_opt_str(suffix_a, suffix_b),
    ])
  } else {
    chain([
      () => @unscanny.compare_str(name_a, name_b),
      () => compare_opt_str(prefix_a, prefix_b),
      () => compare_opt_str(given_a, given_b),
      () => compare_opt_str(suffix_a, suffix_b),
    ])
  }
}

///|
/// `impl FromStr for Person`.
pub fn Person::from_str(s : String) -> Result[Person, PersonError] {
  Person::from_strings(@unscanny.split(s, ","))
}
