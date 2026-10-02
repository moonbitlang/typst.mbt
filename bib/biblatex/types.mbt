// Port of `biblatex/src/types/mod.rs`: strong field types parsable from
// chunks. Upstream's `Type` trait is ported as a set of `parse_*` /
// `*_to_chunks` functions (MoonBit has no specialization for `Vec<T>`).

///|
/// An error that may occur while parsing the chunks in a field into a
/// specific type.
pub(all) struct TypeError {
  /// Where in the source the error occurred.
  span : Span
  /// What kind of error occurred.
  kind : TypeErrorKind
} derive(Eq, Debug)

///|
pub fn TypeError::new(span : Span, kind : TypeErrorKind) -> TypeError {
  { span, kind, }
}

///|
fn TypeError::offset(self : TypeError, amount : Int) -> TypeError {
  {
    ..self,
    span: {
      start: sat_add(self.span.start, amount),
      end: sat_add(self.span.end, amount),
    },
  }
}

///|
pub impl Show for TypeError with fn output(self, logger) {
  logger.write_string("\{self.kind}: \{self.span.start}-\{self.span.end}")
}

///|
/// Error conditions that might occur while parsing the chunks in a field
/// into a specific type.
pub(all) enum TypeErrorKind {
  /// The date range was open on both sides.
  UndefinedRange
  /// The day in a date was out of range (1-31).
  DayOutOfRange
  /// The month in a date was out of range (1-12).
  MonthOutOfRange
  /// The given input did not contain a valid number.
  InvalidNumber
  /// The given input did not contain a number.
  MissingNumber
  /// A number did not have the right number of digits.
  WrongNumberOfDigits
  /// The entry was not in a format valid for that type.
  InvalidFormat
  /// There is no [`Gender`] variant for this input.
  UnknownGender
  /// There was no integer range.
  InvalidIntegerRange
  /// There is no [`Pagination`] variant for this input.
  UnknownPagination
  /// There is no [`EditorType`] variant for this input.
  UnknownEditorType
  /// There is no [`Language`] variant for this input.
  UnknownLangId
  /// The year 0 CE or BCE does not exist.
  YearZeroCE
} derive(Eq, Debug)

///|
pub impl Show for TypeErrorKind with fn output(self, logger) {
  logger.write_string(
    match self {
      UndefinedRange => "range must not be open on both sides"
      DayOutOfRange => "day out of range (must be between 1 and 31)"
      MonthOutOfRange => "month out of range (must be between 1 and 12)"
      InvalidNumber => "invalid number"
      MissingNumber => "missing number"
      WrongNumberOfDigits => "wrong number of digits"
      InvalidFormat => "invalid format"
      UnknownGender => "unknown gender"
      InvalidIntegerRange => "invalid integer range"
      UnknownPagination => "unknown pagination"
      UnknownEditorType => "unknown editor type"
      UnknownLangId => "unknown language id"
      YearZeroCE => "year 0 CE or BCE does not exist"
    },
  )
}

///|
/// Parse a Roman numeral like `roman_numerals_rs::RomanNumeral::from_str`.
pub fn parse_roman(s : String) -> Int? {
  if s.is_empty() {
    return None
  }
  let chars = if s.iter().all(c => c.is_ascii_uppercase()) {
    @unscanny.chars(s)
  } else if s.iter().all(c => c.is_ascii_lowercase()) {
    @unscanny.chars(@unscanny.to_ascii_uppercase(s))
  } else {
    return None
  }
  if chars.iter().any(c => !(c is ('I' | 'V' | 'X' | 'L' | 'C' | 'D' | 'M'))) {
    return None
  }
  let n = chars.length()
  let mut result = 0
  let mut idx = 0
  fn at(i : Int, c : Char) -> Bool {
    i < n && chars[i] == c
  }

  fn starts(i : Int, a : Char, b : Char) -> Bool {
    at(i, a) && at(i + 1, b)
  }

  for _ in 0..<4 {
    if at(idx, 'M') {
      result += 1000
      idx += 1
    } else {
      break
    }
  }
  if n == idx {
    return Some(result)
  }
  if starts(idx, 'C', 'M') {
    result += 900
    idx += 2
  } else if starts(idx, 'C', 'D') {
    result += 400
    idx += 2
  } else {
    if at(idx, 'D') {
      result += 500
      idx += 1
    }
    for _ in 0..<3 {
      if at(idx, 'C') {
        result += 100
        idx += 1
      } else {
        break
      }
    }
  }
  if n == idx {
    return Some(result)
  }
  if starts(idx, 'X', 'C') {
    result += 90
    idx += 2
  } else if starts(idx, 'X', 'L') {
    result += 40
    idx += 2
  } else {
    if at(idx, 'L') {
      result += 50
      idx += 1
    }
    for _ in 0..<3 {
      if at(idx, 'X') {
        result += 10
        idx += 1
      } else {
        break
      }
    }
  }
  if n == idx {
    return Some(result)
  }
  if starts(idx, 'I', 'X') {
    result += 9
    idx += 2
  } else if starts(idx, 'I', 'V') {
    result += 4
    idx += 2
  } else {
    if at(idx, 'V') {
      result += 5
      idx += 1
    }
    for _ in 0..<3 {
      if at(idx, 'I') {
        result += 1
        idx += 1
      } else {
        break
      }
    }
  }
  if n == idx {
    Some(result)
  } else {
    None
  }
}

///|
/// `impl Type for i64`.
pub fn parse_i64(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Int64, TypeError] {
  let span = chunks_span(chunks)
  let s = @unscanny.trim(format_verbatim(chunks))
  match @unscanny.parse_i64(s) {
    Some(n) => Ok(n)
    None =>
      match parse_roman(s) {
        Some(r) => Ok(r.to_int64())
        None =>
          if span.is_empty() {
            Err({ span, kind: MissingNumber, })
          } else {
            Err({ span, kind: InvalidNumber, })
          }
      }
  }
}

///|
/// `impl Type for i64` (`to_chunks`).
pub fn i64_to_chunks(v : Int64) -> Chunks {
  [Spanned::detached(Chunk::Normal(v.to_string()))]
}

///|
/// `impl Type for String`.
pub fn parse_string(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[String, TypeError] {
  Ok(format_verbatim(chunks))
}

///|
/// `impl Type for String` (`to_chunks`).
pub fn string_to_chunks(s : String) -> Chunks {
  [Spanned::detached(Chunk::Verbatim(s))]
}

///|
/// An integer range (upstream `Range<u32>`).
pub(all) struct IntRange(Int64, Int64) derive(Eq, Debug)

///|
/// `impl Type for Range<u32>`.
pub fn parse_range(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[IntRange, TypeError] {
  let span = chunks_span(chunks)
  match parse_ranges(chunks) {
    Ok(v) =>
      if v.is_empty() {
        Err({ span, kind: InvalidIntegerRange, })
      } else {
        Ok(v[0])
      }
    Err(e) => Err(e)
  }
}

///|
/// `impl Type for Vec<Chunks>`: splits the chunks at `"and"`s.
pub fn parse_chunks_list(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Array[Chunks], TypeError] {
  Ok(split_token_lists_with_kw(chunks, "and"))
}

///|
/// `impl Type for Vec<Chunks>` (`to_chunks`).
pub fn chunks_list_to_chunks(list : Array[Chunks]) -> Chunks {
  let merged = []
  let mut first = true
  for chunk in list {
    if first {
      first = false
    } else {
      merged.push(Spanned::detached(Chunk::Normal(" and ")))
    }
    merged.append(clone_chunks(chunk))
  }
  merged
}

///|
/// `impl Type for Vec<String>`: splits the chunks at commas.
pub fn parse_string_list(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Array[String], TypeError] {
  Ok(split_token_lists(chunks, ",").map(c => format_verbatim(c)))
}

///|
/// `impl Type for Vec<String>` (`to_chunks`).
pub fn string_list_to_chunks(list : Array[String]) -> Chunks {
  let chunks = list.map(s => Spanned::detached(Chunk::Normal(s)))
  join_chunk_list(chunks, ",")
}

///|
/// `impl Type for Vec<Range<u32>>`: splits the ranges at commas.
pub fn parse_ranges(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Array[IntRange], TypeError] {
  let range_vecs = split_token_lists(chunks, ",")
  let res = []
  fn number(s : @unscanny.Scanner, offset : Int) -> Result[Int64, TypeError] {
    s.eat_whitespace() |> ignore
    let idx = s.cursor()
    let num = s.eat_while(c => c.is_ascii_digit())
    match @unscanny.parse_u32(num) {
      Some(n) => Ok(n)
      None =>
        Err({
          span: { start: idx + offset, end: s.cursor() + offset, },
          kind: InvalidNumber,
        })
    }
  }

  for f in range_vecs {
    let range_candidate = format_verbatim(f)
    let span = chunks_span(f)
    let s = @unscanny.Scanner::new(range_candidate)
    let start = match number(s, span.start) {
      Ok(n) => n
      Err(e) => return Err(e)
    }
    s.eat_whitespace() |> ignore

    // The double and triple hyphen is converted into en dashes and em
    // dashes earlier.
    if !s.eat_if_any(['-', '–', '—']) {
      res.push(IntRange(start, start))
      if !s.done() {
        return Err({ span, kind: InvalidNumber, })
      }
      continue
    }
    s.eat_while_char('-') |> ignore
    s.eat_whitespace() |> ignore
    let offset = s.cursor()
    let end = match number(s, span.start) {
      Ok(n) => n
      Err(e) => return Err(e)
    }
    if !s.done() {
      return Err({
        span: { start: offset, end: span.end, },
        kind: InvalidNumber,
      })
    }
    res.push(IntRange(start, end))
  }
  Ok(res)
}

///|
/// `impl Type for Vec<Range<u32>>` (`to_chunks`).
pub fn ranges_to_chunks(ranges : Array[IntRange]) -> Chunks {
  let chunks = ranges.map(range => {
    Spanned::detached(Chunk::Normal("\{range.0}-\{range.1}"))
  })
  join_chunk_list(chunks, ",")
}

///|
/// A value that could be either a typed value or a literal string.
pub(all) enum PermissiveType[T] {
  /// A typed version of the value.
  Typed(T)
  /// A literal string, for example `"Reprinted, and revised edition"`.
  Chunks(Chunks)
} derive(Eq, Debug)

///|
/// `impl Type for PermissiveType<T>`: never fails.
pub fn[T] parse_permissive(
  chunks : ArrayView[Spanned[Chunk]],
  parse : (ArrayView[Spanned[Chunk]]) -> Result[T, TypeError],
) -> PermissiveType[T] {
  match parse(chunks) {
    Ok(val) => Typed(val)
    Err(_) => Chunks(clone_chunks(chunks))
  }
}

///|
/// `impl Type for PermissiveType<T>` (`to_chunks`).
pub fn[T] permissive_to_chunks(
  v : PermissiveType[T],
  to_chunks : (T) -> Chunks,
) -> Chunks {
  match v {
    Typed(val) => to_chunks(val)
    Chunks(chunks) => clone_chunks(chunks)
  }
}

///|
/// `impl Type for Vec<PermissiveType<Language>>`: splits the chunks at
/// `"and"`s.
pub fn parse_languages(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Array[PermissiveType[Language]], TypeError] {
  Ok(
    split_token_lists_with_kw(chunks, "and").map(c => {
      parse_permissive(c, parse_language)
    }),
  )
}

///|
/// Defines the pagination scheme to use for formatting purposes.
pub(all) enum Pagination {
  Page
  Column
  Line
  Verse
  Section
  Paragraph
} derive(Eq, Debug)

///|
pub impl Show for Pagination with fn output(self, logger) {
  logger.write_string(
    match self {
      Page => "page"
      Column => "column"
      Line => "line"
      Verse => "verse"
      Section => "section"
      Paragraph => "paragraph"
    },
  )
}

///|
/// `impl Type for Pagination`.
pub fn parse_pagination(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Pagination, TypeError] {
  let span = chunks_span(chunks)
  match @unscanny.to_lowercase(format_verbatim(chunks)) {
    "page" => Ok(Page)
    "column" => Ok(Column)
    "line" => Ok(Line)
    "verse" => Ok(Verse)
    "section" => Ok(Section)
    "paragraph" => Ok(Paragraph)
    _ => Err({ span, kind: UnknownPagination, })
  }
}

///|
/// Which role the according editor had.
///
/// The value of the `editor` through `editorc` fields.
pub(all) enum EditorType {
  Editor
  Compiler
  Founder
  Continuator
  Redactor
  Reviser
  Collaborator
  Organizer
  Director
  Unknown(String)
} derive(Eq, Debug)

///|
pub impl Show for EditorType with fn output(self, logger) {
  logger.write_string(
    match self {
      Editor => "editor"
      Compiler => "compiler"
      Founder => "founder"
      Continuator => "continuator"
      Redactor => "redactor"
      Reviser => "reviser"
      Collaborator => "collaborator"
      Organizer => "organizer"
      Director => "director"
      Unknown(s) => s
    },
  )
}

///|
/// `impl Type for EditorType`.
pub fn parse_editor_type(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[EditorType, TypeError] {
  Ok(
    match @unscanny.to_lowercase(format_verbatim(chunks)) {
      "editor" => Editor
      "compiler" => Compiler
      "founder" => Founder
      "continuator" => Continuator
      "redactor" => Redactor
      "reviser" => Reviser
      "collaborator" => Collaborator
      "organizer" => Organizer
      "director" => Director
      s => Unknown(s)
    },
  )
}

///|
/// Gender of the author or editor (if no author was specified).
pub(all) enum Gender {
  SingularFemale
  SingularMale
  SingularNeuter
  PluralFemale
  PluralMale
  PluralNeuter
} derive(Eq, Debug)

///|
pub impl Show for Gender with fn output(self, logger) {
  logger.write_string(
    match self {
      SingularFemale => "SingularFemale"
      SingularMale => "SingularMale"
      SingularNeuter => "SingularNeuter"
      PluralFemale => "PluralFemale"
      PluralMale => "PluralMale"
      PluralNeuter => "PluralNeuter"
    },
  )
}

///|
/// Puts the gender into plural.
pub fn Gender::plural(self : Gender) -> Gender {
  match self {
    SingularFemale => PluralFemale
    SingularMale => PluralMale
    SingularNeuter => PluralNeuter
    _ => self
  }
}

///|
/// Puts the gender into the singular.
pub fn Gender::singular(self : Gender) -> Gender {
  match self {
    PluralFemale => SingularFemale
    PluralMale => SingularMale
    PluralNeuter => SingularNeuter
    _ => self
  }
}

///|
/// Finds a gender that summarizes a list of genders.
pub fn Gender::coalesce(list : Array[Gender]) -> Gender? {
  if list.is_empty() {
    return None
  }
  if list.length() == 1 {
    return Some(list[0])
  }
  let mut was_female = false
  let mut was_male = false
  let mut was_neuter = false
  for g in list {
    match g {
      SingularFemale | PluralFemale => was_female = true
      SingularMale | PluralMale => was_male = true
      SingularNeuter | PluralNeuter => was_neuter = true
    }
  }
  if was_female && !was_male && !was_neuter {
    Some(PluralFemale)
  } else if was_male && !was_female && !was_neuter {
    Some(PluralMale)
  } else {
    Some(PluralNeuter)
  }
}

///|
/// `impl Type for Gender`.
pub fn parse_gender(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Gender, TypeError] {
  // Two-letter gender serialization in accordance with the BibLaTeX
  // standard.
  let span = chunks_span(chunks)
  match @unscanny.to_lowercase(format_verbatim(chunks)) {
    "sf" => Ok(SingularFemale)
    "sm" => Ok(SingularMale)
    "sn" => Ok(SingularNeuter)
    "pf" => Ok(PluralFemale)
    "pm" => Ok(PluralMale)
    "pn" => Ok(PluralNeuter)
    _ => Err({ span, kind: UnknownGender, })
  }
}
