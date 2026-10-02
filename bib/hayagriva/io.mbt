// Port of `hayagriva/src/io.rs` and of the `serde::Deserialize`
// implementations of the hayagriva data model (`Library`, `NakedEntry` and
// the field types), applied to the generic YAML data tree.

///|
/// An error from loading a YAML bibliography (upstream `serde_yaml::Error`).
pub(all) struct YamlLoadError {
  /// The error message.
  message : String
  /// The location of a YAML syntax error, if any.
  location : @yaml.Location?
} derive(Eq, Debug)

///|
pub impl Show for YamlLoadError with fn output(self, logger) {
  logger.write_string(self.message)
}

///|
priv suberror De {
  De(String)
}

///|
/// Describe a value for `invalid type` errors (serde's `Unexpected`).
fn unexpected(d : @serde.Data) -> String {
  match d {
    None => "unit value"
    Bool(b) => "boolean `\{b}`"
    Int(i) => "integer `\{i}`"
    Float(f) => "floating point `\{@serde.format_display(f)}`"
    Str(s) => "string \{@unicode.rust_debug_str(s)}"
    Bytes(_) => "byte array"
    Seq(_) => "sequence"
    Map(_) => "map"
  }
}

///|
fn invalid_type(d : @serde.Data, expected : String) -> De {
  De("invalid type: \{unexpected(d)}, expected \{expected}")
}

///|
/// Parse a bibliography from a YAML string.
pub fn from_yaml_str(s : String) -> Result[Library, YamlLoadError] {
  let data = @yaml.parse(@utf8.encode(s)) catch {
    @yaml.YamlError(message~, location~) => return Err({ message, location, })
  }
  try de_library(data) catch {
    De(message) => Err({ message, location: None, })
  } noraise {
    lib => Ok(lib)
  }
}

///|
fn data_key(d : @serde.Data) -> String {
  match d {
    Str(s) => s
    Int(i) => i.to_string()
    Float(f) => @serde.format_display(f)
    Bool(b) => b.to_string()
    None => "~"
    _ => ""
  }
}

///|
fn de_library(data : @serde.Data) -> Library raise De {
  guard data is Map(pairs) else {
    raise invalid_type(data, "a map between cite keys and entries")
  }
  let entries : Array[Entry] = []
  for pair in pairs {
    let (key, value) = pair
    if entries.iter().any(e => e.key == key) {
      raise De("duplicate key \{key}")
    }
    let naked = de_naked_entry(value)
    entries.push(naked.into_entry(key, None))
  }
  Library::from_entries(entries)
}

///|
/// An entry before its type is resolved (upstream `NakedEntry`).
priv struct NakedEntry {
  entry_type : EntryType?
  parents : Array[NakedEntry]
  fields : Entry
}

///|
fn NakedEntry::into_entry(
  self : NakedEntry,
  key : String,
  child_entry_type : EntryType?,
) -> Entry raise De {
  let entry_type = match self.entry_type {
    Some(t) => t
    None =>
      match child_entry_type {
        Some(c) => c.default_parent()
        None => raise De("no entry type for `\{key}`")
      }
  }
  let parents = self.parents.map(p => p.into_entry(key, Some(entry_type)))
  let e = self.fields
  { ..e, key, entry_type, parents, }
}

///|
fn de_naked_entry(data : @serde.Data) -> NakedEntry raise De {
  guard data is Map(pairs) else {
    raise invalid_type(data, "a map representing a bibliography entry")
  }
  let e = Entry::new("", Misc)
  let mut entry_type = None
  let mut parents = []
  let seen : Array[String] = []
  for pair in pairs {
    let (k, v) = pair
    let canonical = if k == "serial" { "serial-number" } else { k }
    if seen.contains(canonical) {
      raise De("duplicate field `\{canonical}`")
    }
    seen.push(canonical)
    match k {
      "type" =>
        entry_type = match v {
          None => None
          Str(s) =>
            match EntryType::from_str(s) {
              Ok(t) => Some(t)
              Err(msg) => raise De(msg)
            }
          _ => raise invalid_type(v, "string or map")
        }
      "parent" =>
        parents = match v {
          Seq(items) => items.map(de_naked_entry)
          None =>
            raise De(
              "data did not match any variant of untagged enum OneOrMany",
            )
          _ =>
            [
              de_naked_entry(v) catch {
                _ =>
                  raise De(
                    "data did not match any variant of untagged enum OneOrMany",
                  )
              },
            ]
        }
      "title" => e.title_ = de_opt(v, de_format_string)
      "author" => e.authors_ = de_opt(v, d => de_one_or_many(d, de_person))
      "date" => e.date_ = de_opt(v, de_date)
      "editor" => e.editors_ = de_opt(v, d => de_one_or_many(d, de_person))
      "affiliated" =>
        e.affiliated_ = de_opt(v, d => de_one_or_many(d, de_persons_with_roles))
      "publisher" => e.publisher_ = de_opt(v, de_publisher)
      "location" => e.location_ = de_opt(v, de_format_string)
      "organization" => e.organization_ = de_opt(v, de_format_string)
      "issue" => e.issue_ = de_opt(v, de_maybe_numeric)
      "chapter" => e.chapter_ = de_opt(v, de_maybe_numeric)
      "volume" => e.volume_ = de_opt(v, de_maybe_numeric)
      "volume-total" => e.volume_total_ = de_opt(v, de_numeric)
      "edition" => e.edition_ = de_opt(v, de_maybe_numeric)
      "page-range" => e.page_range_ = de_opt(v, de_maybe_page_ranges)
      "page-total" => e.page_total_ = de_opt(v, de_numeric)
      "time-range" => e.time_range_ = de_opt(v, de_maybe_duration_range)
      "runtime" => e.runtime_ = de_opt(v, de_maybe_duration)
      "url" => e.url_ = de_opt(v, de_qualified_url)
      "serial-number" | "serial" =>
        e.serial_number_ = de_opt(v, de_serial_number)
      "language" => e.language_ = de_opt(v, de_language)
      "archive" => e.archive_ = de_opt(v, de_format_string)
      "archive-location" => e.archive_location_ = de_opt(v, de_format_string)
      "call-number" => e.call_number_ = de_opt(v, de_format_string)
      "note" => e.note_ = de_opt(v, de_format_string)
      "abstract" => e.abstract__ = de_opt(v, de_format_string)
      "genre" => e.genre_ = de_opt(v, de_format_string)
      _ => ()
    }
  }
  { entry_type, parents, fields: e, }
}

///|
/// `Option<T>`: YAML null deserializes to `None`.
fn[T] de_opt(d : @serde.Data, f : (@serde.Data) -> T raise De) -> T? raise De {
  match d {
    None => None
    _ => Some(f(d))
  }
}

///|
/// `deserialize_one_or_many_opt` (`MapOneOrMany`).
fn[T] de_one_or_many(
  d : @serde.Data,
  f : (@serde.Data) -> T raise De,
) -> Array[T] raise De {
  match d {
    Str(_) | Map(_) | Int(_) => [f(d)]
    Seq(items) => items.map(f)
    _ => raise invalid_type(d, "a map, a string, or a list")
  }
}

///|
fn de_chunked_string(d : @serde.Data) -> ChunkedString raise De {
  match d {
    Str(s) =>
      match ChunkedString::from_str(s) {
        Ok(c) => c
        Err(e) => raise De(e.to_string())
      }
    Map(pairs) => {
      let mut value = None
      let mut verbatim = false
      for pair in pairs {
        match pair.0 {
          "value" =>
            value = match pair.1 {
              Str(s) => Some(s)
              other => raise invalid_type(other, "a string")
            }
          "verbatim" =>
            verbatim = match pair.1 {
              Bool(b) => b
              other => raise invalid_type(other, "a boolean")
            }
          _ => ()
        }
      }
      guard value is Some(value) else { raise De("missing field `value`") }
      if verbatim {
        ChunkedString::from_chunk(StringChunk::verbatim(value))
      } else {
        match ChunkedString::from_str(value) {
          Ok(c) => c
          Err(e) => raise De(e.to_string())
        }
      }
    }
    _ => raise invalid_type(d, "a formattable string")
  }
}

///|
fn de_format_string(d : @serde.Data) -> FormatString raise De {
  match d {
    Str(s) =>
      match FormatString::from_str(s) {
        Ok(f) => f
        Err(e) => raise De(e.to_string())
      }
    Map(pairs) => {
      // Untagged: `Full { value, short }` or `Val(ChunkedString)`.
      let full = try {
        let mut value = None
        let mut short = None
        for pair in pairs {
          match pair.0 {
            "value" => value = Some(de_chunked_string(pair.1))
            "short" => short = de_opt(pair.1, de_chunked_string)
            _ => ()
          }
        }
        guard value is Some(value) else { raise De("missing field `value`") }
        Some(FormatString::{ value, short, })
      } catch {
        _ => None
      }
      match full {
        Some(f) => f
        None =>
          FormatString::{
            value: de_chunked_string(d) catch {
              _ =>
                raise De(
                  "data did not match any variant of untagged enum Inner",
                )
            },
            short: None,
          }
      }
    }
    _ =>
      raise invalid_type(
        d, "a formattable string or a dictionary with an optional short version",
      )
  }
}

///|
fn de_string(d : @serde.Data) -> String raise De {
  match d {
    Str(s) => s
    _ => raise invalid_type(d, "a string")
  }
}

///|
fn de_person(d : @serde.Data) -> Person raise De {
  match d {
    Str(s) =>
      match Person::from_str(s) {
        Ok(p) => p
        Err(e) => raise De(e.to_string())
      }
    Map(pairs) => {
      let mut name = None
      let mut given_name = None
      let mut prefix = None
      let mut suffix = None
      let mut comma_suffix = false
      let mut alias_ = None
      for pair in pairs {
        let (k, v) = pair
        match k {
          "name" => name = Some(de_string(v))
          "given-name" => given_name = de_opt(v, de_string)
          "prefix" => prefix = de_opt(v, de_string)
          "suffix" => suffix = de_opt(v, de_string)
          "comma-suffix" =>
            comma_suffix = match v {
              Bool(b) => b
              _ => raise invalid_type(v, "a boolean")
            }
          "alias" => alias_ = de_opt(v, de_string)
          _ => ()
        }
      }
      guard name is Some(name) else { raise De("missing field `name`") }
      { name, given_name, prefix, suffix, comma_suffix, alias_, }
    }
    _ =>
      raise invalid_type(d, "a name string or a dictionary with a \"name\" key")
  }
}

///|
fn de_persons_with_roles(d : @serde.Data) -> PersonsWithRoles raise De {
  guard d is Map(pairs) else {
    raise invalid_type(d, "struct PersonsWithRoles")
  }
  let mut names = None
  let mut role = None
  for pair in pairs {
    match pair.0 {
      "names" => names = Some(de_one_or_many(pair.1, de_person))
      "role" =>
        role = match pair.1 {
          Str(s) =>
            match PersonRole::from_str(s) {
              Some(r) => Some(r)
              None =>
                raise De(
                  "unknown variant `\{s}`, expected one of `translator`, `afterword`, `foreword`, `introduction`, `annotator`, `commentator`, `holder`, `compiler`, `founder`, `collaborator`, `organizer`, `cast-member`, `composer`, `producer`, `executive-producer`, `writer`, `cinematography`, `director`, `illustrator`, `narrator`",
                )
            }
          other => raise invalid_type(other, "enum PersonRole")
        }
      _ => ()
    }
  }
  guard names is Some(names) else { raise De("missing field `names`") }
  guard role is Some(role) else { raise De("missing field `role`") }
  { names, role, }
}

///|
fn de_date(d : @serde.Data) -> Date raise De {
  match d {
    Str(s) =>
      match Date::from_str(s) {
        Ok(d) => d
        Err(e) => raise De(e.to_string())
      }
    Int(i) =>
      if i >= -2147483648L && i <= 2147483647L {
        Date::from_year(i.to_int())
      } else {
        raise De("year out of bounds")
      }
    Map(pairs) => {
      let mut year = None
      let mut month = None
      let mut day = None
      let mut approximate = false
      let mut season = None
      let u8 = (v : @serde.Data) => {
        match v {
          Int(i) if i >= 0L && i <= 255L => i.to_int()
          _ => raise invalid_type(v, "u8")
        }
      }
      for pair in pairs {
        let (k, v) = pair
        match k {
          "year" =>
            year = match v {
              Int(i) if i >= -2147483648L && i <= 2147483647L =>
                Some(i.to_int())
              _ => raise invalid_type(v, "i32")
            }
          "month" => month = de_opt(v, u8)
          "day" => day = de_opt(v, u8)
          "approximate" =>
            approximate = match v {
              Bool(b) => b
              _ => raise invalid_type(v, "a boolean")
            }
          "season" => season = de_opt(v, u8)
          _ => ()
        }
      }
      guard year is Some(year) else { raise De("missing field `year`") }
      {
        year,
        month,
        day,
        approximate,
        season: match season {
          Some(s) => @citationberg.Season::try_from_csl_number(s)
          None => None
        },
      }
    }
    _ => raise invalid_type(d, "a date in the format YYYY-MM-DD")
  }
}

///|
fn de_publisher(d : @serde.Data) -> Publisher raise De {
  match d {
    Str(s) =>
      match Publisher::from_str(s) {
        Ok(p) => p
        Err(e) => raise De(e.to_string())
      }
    Map(pairs) => {
      let mut name = None
      let mut location = None
      for pair in pairs {
        match pair.0 {
          "name" => name = de_opt(pair.1, de_format_string)
          "location" => location = de_opt(pair.1, de_format_string)
          _ => ()
        }
      }
      { name, location, }
    }
    _ =>
      raise invalid_type(
        d, "FormatString string or dictionary with \"name\" and \"location\"",
      )
  }
}

///|
fn de_numeric(d : @serde.Data) -> Numeric raise De {
  match d {
    Int(i) =>
      if i >= -2147483648L && i <= 2147483647L {
        Numeric::new(i.to_int())
      } else if i > 0L {
        raise De("value too large")
      } else {
        raise De("value out of bounds")
      }
    Str(s) =>
      match Numeric::from_str(s) {
        Ok(n) => n
        Err(e) => raise De(e.to_string())
      }
    _ =>
      raise invalid_type(d, "a numeric value with optional prefix and suffix")
  }
}

///|
/// `MaybeTyped<T>` (untagged: typed first, then string).
fn[T] de_maybe_typed(
  d : @serde.Data,
  typed : (@serde.Data) -> T raise De,
) -> MaybeTyped[T] raise De {
  try typed(d) catch {
    _ =>
      match d {
        Str(s) => String(s)
        _ =>
          raise De("data did not match any variant of untagged enum MaybeTyped")
      }
  } noraise {
    t => Typed(t)
  }
}

///|
fn de_maybe_numeric(d : @serde.Data) -> MaybeTyped[Numeric] raise De {
  de_maybe_typed(d, de_numeric)
}

///|
fn de_page_ranges(d : @serde.Data) -> PageRanges raise De {
  match d {
    Int(i) =>
      if i >= -2147483648L && i <= 2147483647L {
        PageRanges::from_int(i.to_int())
      } else if i > 0L {
        raise De("value too large")
      } else {
        raise De("value out of bounds")
      }
    Str(s) =>
      match PageRanges::from_str(s) {
        Ok(p) => p
        Err(e) => raise De(e.to_string())
      }
    _ => raise invalid_type(d, "pages, page ranges, ampersands, and commas")
  }
}

///|
fn de_maybe_page_ranges(d : @serde.Data) -> MaybeTyped[PageRanges] raise De {
  de_maybe_typed(d, de_page_ranges)
}

///|
fn de_duration(d : @serde.Data) -> Duration raise De {
  match d {
    Str(s) =>
      match Duration::from_str(s) {
        Ok(v) => v
        Err(e) => raise De(e.to_string())
      }
    _ => raise invalid_type(d, "a borrowed string")
  }
}

///|
fn de_maybe_duration(d : @serde.Data) -> MaybeTyped[Duration] raise De {
  de_maybe_typed(d, de_duration)
}

///|
fn de_duration_range(d : @serde.Data) -> DurationRange raise De {
  match d {
    Str(s) =>
      match DurationRange::from_str(s) {
        Ok(v) => v
        Err(e) => raise De(e.to_string())
      }
    Map(pairs) => {
      let mut start = None
      let mut end = None
      for pair in pairs {
        match pair.0 {
          "start" => start = Some(de_duration(pair.1))
          "end" => end = Some(de_duration(pair.1))
          _ => ()
        }
      }
      guard start is Some(start) else { raise De("missing field `start`") }
      guard end is Some(end) else { raise De("missing field `end`") }
      { start, end, }
    }
    _ =>
      raise invalid_type(
        d, "two durations separated by a hyphen or a map with a `from` and `to` field",
      )
  }
}

///|
fn de_maybe_duration_range(
  d : @serde.Data,
) -> MaybeTyped[DurationRange] raise De {
  de_maybe_typed(d, de_duration_range)
}

///|
fn de_url(d : @serde.Data) -> Url raise De {
  match d {
    Str(s) =>
      match Url::parse(s) {
        Ok(u) => u
        Err(e) => raise De(e.to_string())
      }
    _ => raise invalid_type(d, "a string representing an URL")
  }
}

///|
fn de_qualified_url(d : @serde.Data) -> QualifiedUrl raise De {
  match d {
    Str(s) =>
      match QualifiedUrl::from_str(s) {
        Ok(u) => u
        Err(e) => raise De(e.to_string())
      }
    Map(pairs) => {
      let mut value = None
      let mut visit_date = None
      for pair in pairs {
        match pair.0 {
          "value" => value = Some(de_url(pair.1))
          "date" => visit_date = de_opt(pair.1, de_date)
          _ => ()
        }
      }
      guard value is Some(value) else { raise De("missing field `value`") }
      { value, visit_date, }
    }
    _ =>
      raise invalid_type(
        d, "URL string or dictionary with keys \"url\" and \"date\"",
      )
  }
}

///|
/// `StringOrNumber` (untagged) to its display string.
fn string_or_number(d : @serde.Data) -> String? {
  match d {
    Str(s) => Some(s)
    Int(i) => Some(i.to_string())
    Float(f) => Some(@serde.format_display(f))
    _ => None
  }
}

///|
fn de_serial_number(d : @serde.Data) -> SerialNumber raise De {
  match d {
    Map(pairs) => {
      let map : Map[String, String] = Map([])
      for pair in pairs {
        match string_or_number(pair.1) {
          Some(s) => map.set(pair.0, s)
          None =>
            raise De("data did not match any variant of untagged enum Choice")
        }
      }
      SerialNumber(map)
    }
    _ =>
      match string_or_number(d) {
        Some(s) => {
          let map : Map[String, String] = Map([])
          map.set("serial", s)
          SerialNumber(map)
        }
        None =>
          raise De("data did not match any variant of untagged enum Choice")
      }
  }
}

///|
fn de_language(d : @serde.Data) -> LanguageIdentifier raise De {
  match d {
    Str(s) =>
      match LanguageIdentifier::parse(s) {
        Some(l) => l
        None => raise De("Invalid subtag")
      }
    _ => raise invalid_type(d, "a string")
  }
}

///|
/// Errors that may occur when parsing a BibLaTeX file.
pub(all) enum BibLaTeXError {
  /// An error occurred when parsing a BibLaTeX file.
  Parse(@biblatex.ParseError)
  /// One of the BibLaTeX fields was malformed for its type.
  Type(@biblatex.TypeError)
} derive(Eq, Debug)

///|
pub impl Show for BibLaTeXError with fn output(self, logger) {
  match self {
    Parse(err) => logger.write_string("biblatex parse error: \{err}")
    Type(err) => logger.write_string("biblatex type error: \{err}")
  }
}

///|
/// Parse a bibliography from a BibLaTeX source string.
pub fn from_biblatex_str(
  biblatex : String,
) -> Result[Library, Array[BibLaTeXError]] {
  match @biblatex.Bibliography::parse(biblatex) {
    Err(e) => Err([Parse(e)])
    Ok(bibliography) =>
      match from_biblatex(bibliography) {
        Ok(lib) => Ok(lib)
        Err(errs) => Err(errs.map(e => Type(e)))
      }
  }
}

///|
/// Parse a bibliography from a BibLaTeX [`Bibliography`].
pub fn from_biblatex(
  bibliography : @biblatex.Bibliography,
) -> Result[Library, Array[@biblatex.TypeError]] {
  let res = bibliography.entries().map(entry_from_biblatex)
  let errors = []
  for item in res {
    if item is Err(err) {
      errors.push(err)
    }
  }
  if !errors.is_empty() {
    Err(errors)
  } else {
    Ok(Library::from_entries(res.map(item => item.unwrap())))
  }
}
