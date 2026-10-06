// Port of `hayagriva/src/io.rs` and of the `serde::Deserialize`
// implementations of the hayagriva data model (`Library`, `NakedEntry` and
// the field types), applied to the located YAML node tree of `data/yaml`.
//
// Errors are attributed like `serde_yaml::error::fix_mark` does: a custom
// error gets the mark and path of the innermost node whose `serde_yaml`
// `deserialize_*` call was active when it was raised ([at_node]). Untagged
// enums (`MaybeTyped`, `OneOrMany`, `Choice`) report their final error after
// the node's own `deserialize_any` returned, so it is attributed to the
// enclosing node.

///|
/// An error from loading a YAML bibliography (upstream `serde_yaml::Error`).
pub(all) struct YamlLoadError {
  /// The error message (upstream `Display`).
  message : String
  /// The location of the error, if any (upstream `location()`).
  location : @yaml.Location?
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend YamlLoadError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend YamlLoadError with @debug.Debug::{to_repr}

///|
pub impl Show for YamlLoadError with fn output(self, logger) {
  logger.write_string(self.message)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend YamlLoadError with Show::{to_string, output}

///|
priv suberror De {
  /// A custom error that has not been attributed to a node yet.
  De(String)
  /// An error with its final message and location.
  DeAt(String, @yaml.Location?)
}

///|
/// Run a deserializer for a node, attributing unmarked errors to it.
fn[T] at_node(n : @yaml.YamlNode, f : () -> T raise De) -> T raise De {
  f() catch {
    De(msg) => {
      let @yaml.YamlError(message~, location~) = n.error(msg)
      raise DeAt(message, location)
    }
    err => raise err
  }
}

///|
/// The parse error that ended the document, if a deserializer reads past
/// the children of an incomplete node.
let current_parse_error : Ref[@yaml.YamlError?] = { val: None, }

///|
/// The children of a container node; reading past the present children of
/// an incomplete node reports the document's parse error.
fn check_complete(n : @yaml.YamlNode) -> Unit raise De {
  if n.incomplete && current_parse_error.val is Some(err) {
    let @yaml.YamlError(message~, location~) = err
    raise DeAt(message, location)
  }
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
fn invalid_type(n : @yaml.YamlNode, expected : String) -> De {
  De("invalid type: \{unexpected(n.data)}, expected \{expected}")
}

///|
/// The key/value pairs of a mapping node.
fn map_entries(n : @yaml.YamlNode) -> Array[(String, @yaml.YamlNode)] {
  match n.data {
    Map(pairs) => pairs.mapi((i, pair) => (pair.0, n.children[i]))
    _ => []
  }
}

///|
/// Parse a bibliography from a YAML string.
pub fn from_yaml_str(s : String) -> Result[Library, YamlLoadError] {
  let nodes = @yaml.parse_nodes(@utf8.encode(s)) catch {
    @yaml.YamlError(message~, location~) => return Err({ message, location, })
  }
  current_parse_error.val = nodes.error
  let result = try at_node(nodes.root, () => de_library(nodes.root)) catch {
    De(message) => Err({ message, location: None, })
    DeAt(message, location) => Err({ message, location, })
  } noraise {
    lib => Ok(lib)
  }
  current_parse_error.val = None
  match (result, nodes.error) {
    (Ok(_), Some(@yaml.YamlError(message~, location~))) =>
      Err({ message, location, })
    _ => result
  }
}

///|
fn de_library(n : @yaml.YamlNode) -> Library raise De {
  guard n.data is Map(_) || n.empty else {
    raise invalid_type(n, "a map between cite keys and entries")
  }
  let entries : Array[Entry] = []
  for pair in map_entries(n) {
    let (key, value) = pair
    if entries.iter().any(e => e.key == key) {
      raise De("duplicate key \{key}")
    }
    // Convert immediately so errors report the correct position
    let entry = at_node(value, () => {
      let naked = de_naked_entry(value)
      naked.into_entry(key, None)
    })
    entries.push(entry)
  }
  check_complete(n)
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
/// `Option<T>`: YAML null deserializes to `None`.
fn[T] de_opt(
  n : @yaml.YamlNode,
  f : (@yaml.YamlNode) -> T raise De,
) -> T? raise De {
  match n.data {
    None => None
    _ => Some(f(n))
  }
}

///|
/// A field value deserialized with its own `serde_yaml` call.
fn[T] de_field(
  n : @yaml.YamlNode,
  f : (@yaml.YamlNode) -> T raise De,
) -> T? raise De {
  de_opt(n, n => at_node(n, () => f(n)))
}

///|
fn de_naked_entry(n : @yaml.YamlNode) -> NakedEntry raise De {
  guard n.data is Map(_) || n.empty else {
    raise invalid_type(n, "a map representing a bibliography entry")
  }
  let e = Entry::new("", Misc)
  let mut entry_type = None
  let mut parents = []
  let seen : Array[String] = []
  for pair in map_entries(n) {
    let (k, v) = pair
    let canonical = if k == "serial" { "serial-number" } else { k }
    if seen.contains(canonical) {
      raise De("duplicate field `\{canonical}`")
    }
    seen.push(canonical)
    match k {
      "type" =>
        entry_type = de_field(v, v => {
          match v.data {
            Str(s) =>
              match EntryType::from_str(s) {
                Ok(t) => t
                Err(msg) => raise De(msg)
              }
            _ => raise invalid_type(v, "string or map")
          }
        })
      "parent" =>
        // Untagged `OneOrMany<NakedEntry>`.
        parents = match v.data {
          Seq(_) => {
            let items = []
            let ok = try {
              for child in v.children {
                items.push(de_naked_entry(child))
              }
              true
            } catch {
              _ => false
            }
            if !ok {
              raise De(
                "data did not match any variant of untagged enum OneOrMany",
              )
            }
            items
          }
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
      "title" => e.title_ = de_field(v, de_format_string)
      "author" =>
        e.authors_ = de_field(v, d => de_one_or_many(d, de_person, "person"))
      "date" => e.date_ = de_field(v, de_date)
      "editor" =>
        e.editors_ = de_field(v, d => de_one_or_many(d, de_person, "person"))
      "affiliated" =>
        e.affiliated_ = de_field(v, d => {
          de_one_or_many(d, de_persons_with_roles, "struct PersonsWithRoles")
        })
      "publisher" => e.publisher_ = de_field(v, de_publisher)
      "location" => e.location_ = de_field(v, de_format_string)
      "organization" => e.organization_ = de_field(v, de_format_string)
      "issue" => e.issue_ = de_opt(v, de_maybe_numeric)
      "chapter" => e.chapter_ = de_opt(v, de_maybe_numeric)
      "volume" => e.volume_ = de_opt(v, de_maybe_numeric)
      "volume-total" => e.volume_total_ = de_field(v, de_numeric)
      "edition" => e.edition_ = de_opt(v, de_maybe_numeric)
      "page-range" => e.page_range_ = de_opt(v, de_maybe_page_ranges)
      "page-total" => e.page_total_ = de_field(v, de_numeric)
      "time-range" => e.time_range_ = de_opt(v, de_maybe_duration_range)
      "runtime" => e.runtime_ = de_opt(v, de_maybe_duration)
      "url" => e.url_ = de_field(v, de_qualified_url)
      "serial-number" | "serial" =>
        e.serial_number_ = de_opt(v, de_serial_number)
      "language" => e.language_ = de_field(v, de_language)
      "archive" => e.archive_ = de_field(v, de_format_string)
      "archive-location" => e.archive_location_ = de_field(v, de_format_string)
      "call-number" => e.call_number_ = de_field(v, de_format_string)
      "note" => e.note_ = de_field(v, de_format_string)
      "abstract" => e.abstract__ = de_field(v, de_format_string)
      "genre" => e.genre_ = de_field(v, de_format_string)
      _ => ()
    }
  }
  check_complete(n)
  { entry_type, parents, fields: e, }
}

///|
/// `deserialize_one_or_many_opt` (`MapOneOrMany`).
fn[T] de_one_or_many(
  n : @yaml.YamlNode,
  f : (@yaml.YamlNode) -> T raise De,
  _what : String,
) -> Array[T] raise De {
  match n.data {
    Str(_) | Map(_) | Int(_) => [f(n)]
    Seq(_) => {
      let out = []
      for child in n.children {
        out.push(at_node(child, () => f(child)))
      }
      check_complete(n)
      out
    }
    _ => raise invalid_type(n, "a map, a string, or a list")
  }
}

///|
fn de_chunked_string(n : @yaml.YamlNode) -> ChunkedString raise De {
  match n.data {
    Str(s) =>
      match ChunkedString::from_str(s) {
        Ok(c) => c
        Err(e) => raise De(e.to_string())
      }
    Map(_) => {
      let mut value = None
      let mut verbatim = false
      for pair in map_entries(n) {
        let (k, v) = pair
        match k {
          "value" =>
            value = Some(
              at_node(v, () => {
                match v.data {
                  Str(s) => s
                  _ => raise invalid_type(v, "a string")
                }
              }),
            )
          "verbatim" =>
            verbatim = at_node(v, () => {
              match v.data {
                Bool(b) => b
                _ => raise invalid_type(v, "a boolean")
              }
            })
          _ => ()
        }
      }
      check_complete(n)
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
    _ => raise invalid_type(n, "a formattable string")
  }
}

///|
fn de_format_string(n : @yaml.YamlNode) -> FormatString raise De {
  match n.data {
    Str(s) =>
      match FormatString::from_str(s) {
        Ok(f) => f
        Err(e) => raise De(e.to_string())
      }
    Map(_) => {
      // Untagged: `Full { value, short }` or `Val(ChunkedString)`.
      check_complete(n)
      let full = try {
        let mut value = None
        let mut short = None
        for pair in map_entries(n) {
          let (k, v) = pair
          match k {
            "value" => value = Some(de_chunked_string(v))
            "short" => short = de_opt(v, de_chunked_string)
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
            value: de_chunked_string(n) catch {
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
        n, "a formattable string or a dictionary with an optional short version",
      )
  }
}

///|
fn de_string(n : @yaml.YamlNode) -> String raise De {
  match n.data {
    Str(s) => s
    _ => raise invalid_type(n, "a string")
  }
}

///|
fn de_person(n : @yaml.YamlNode) -> Person raise De {
  match n.data {
    Str(s) =>
      match Person::from_str(s) {
        Ok(p) => p
        Err(e) => raise De(e.to_string())
      }
    Map(_) => {
      let mut name = None
      let mut given_name = None
      let mut prefix = None
      let mut suffix = None
      let mut comma_suffix = false
      let mut alias_ = None
      for pair in map_entries(n) {
        let (k, v) = pair
        match k {
          "name" => name = Some(at_node(v, () => de_string(v)))
          "given-name" => given_name = de_field(v, de_string)
          "prefix" => prefix = de_field(v, de_string)
          "suffix" => suffix = de_field(v, de_string)
          "comma-suffix" =>
            comma_suffix = at_node(v, () => {
              match v.data {
                Bool(b) => b
                _ => raise invalid_type(v, "a boolean")
              }
            })
          "alias" => alias_ = de_field(v, de_string)
          _ => ()
        }
      }
      check_complete(n)
      guard name is Some(name) else { raise De("missing field `name`") }
      { name, given_name, prefix, suffix, comma_suffix, alias_, }
    }
    _ =>
      raise invalid_type(n, "a name string or a dictionary with a \"name\" key")
  }
}

///|
fn de_persons_with_roles(n : @yaml.YamlNode) -> PersonsWithRoles raise De {
  guard n.data is Map(_) || n.empty else {
    raise invalid_type(n, "struct PersonsWithRoles")
  }
  let mut names = None
  let mut role = None
  for pair in map_entries(n) {
    let (k, v) = pair
    match k {
      "names" =>
        names = Some(at_node(v, () => de_one_or_many(v, de_person, "person")))
      "role" =>
        role = Some(
          at_node(v, () => {
            match v.data {
              Str(s) =>
                match PersonRole::from_str(s) {
                  Some(r) => r
                  None =>
                    raise De(
                      "unknown variant `\{s}`, expected one of `translator`, `afterword`, `foreword`, `introduction`, `annotator`, `commentator`, `holder`, `compiler`, `founder`, `collaborator`, `organizer`, `cast-member`, `composer`, `producer`, `executive-producer`, `writer`, `cinematography`, `director`, `illustrator`, `narrator`",
                    )
                }
              _ => raise invalid_type(v, "enum PersonRole")
            }
          }),
        )
      _ => ()
    }
  }
  check_complete(n)
  guard names is Some(names) else { raise De("missing field `names`") }
  guard role is Some(role) else { raise De("missing field `role`") }
  { names, role, }
}

///|
fn de_date(n : @yaml.YamlNode) -> Date raise De {
  match n.data {
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
    Map(_) => {
      let mut year = None
      let mut month = None
      let mut day = None
      let mut approximate = false
      let mut season = None
      let u8 = (v : @yaml.YamlNode) => {
        match v.data {
          Int(i) if i >= 0L && i <= 255L => i.to_int()
          _ => raise invalid_type(v, "u8")
        }
      }
      for pair in map_entries(n) {
        let (k, v) = pair
        match k {
          "year" =>
            year = Some(
              at_node(v, () => {
                match v.data {
                  Int(i) if i >= -2147483648L && i <= 2147483647L => i.to_int()
                  _ => raise invalid_type(v, "i32")
                }
              }),
            )
          "month" => month = de_field(v, u8)
          "day" => day = de_field(v, u8)
          "approximate" =>
            approximate = at_node(v, () => {
              match v.data {
                Bool(b) => b
                _ => raise invalid_type(v, "a boolean")
              }
            })
          "season" => season = de_field(v, u8)
          _ => ()
        }
      }
      check_complete(n)
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
    _ => raise invalid_type(n, "a date in the format YYYY-MM-DD")
  }
}

///|
fn de_publisher(n : @yaml.YamlNode) -> Publisher raise De {
  match n.data {
    Str(s) =>
      match Publisher::from_str(s) {
        Ok(p) => p
        Err(e) => raise De(e.to_string())
      }
    Map(_) => {
      let mut name = None
      let mut location = None
      for pair in map_entries(n) {
        let (k, v) = pair
        match k {
          "name" => name = de_field(v, de_format_string)
          "location" => location = de_field(v, de_format_string)
          _ => ()
        }
      }
      check_complete(n)
      { name, location, }
    }
    _ =>
      raise invalid_type(
        n, "FormatString string or dictionary with \"name\" and \"location\"",
      )
  }
}

///|
fn de_numeric(n : @yaml.YamlNode) -> Numeric raise De {
  match n.data {
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
      raise invalid_type(n, "a numeric value with optional prefix and suffix")
  }
}

///|
/// `MaybeTyped<T>` (untagged: typed first, then string).
fn[T] de_maybe_typed(
  n : @yaml.YamlNode,
  typed : (@yaml.YamlNode) -> T raise De,
) -> MaybeTyped[T] raise De {
  check_complete(n)
  try typed(n) catch {
    _ =>
      match n.data {
        Str(s) => String(s)
        _ =>
          raise De("data did not match any variant of untagged enum MaybeTyped")
      }
  } noraise {
    t => Typed(t)
  }
}

///|
fn de_maybe_numeric(n : @yaml.YamlNode) -> MaybeTyped[Numeric] raise De {
  de_maybe_typed(n, de_numeric)
}

///|
fn de_page_ranges(n : @yaml.YamlNode) -> PageRanges raise De {
  match n.data {
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
    _ => raise invalid_type(n, "pages, page ranges, ampersands, and commas")
  }
}

///|
fn de_maybe_page_ranges(n : @yaml.YamlNode) -> MaybeTyped[PageRanges] raise De {
  de_maybe_typed(n, de_page_ranges)
}

///|
fn de_duration(n : @yaml.YamlNode) -> Duration raise De {
  match n.data {
    Str(s) =>
      match Duration::from_str(s) {
        Ok(v) => v
        Err(e) => raise De(e.to_string())
      }
    _ => raise invalid_type(n, "a borrowed string")
  }
}

///|
fn de_maybe_duration(n : @yaml.YamlNode) -> MaybeTyped[Duration] raise De {
  de_maybe_typed(n, de_duration)
}

///|
fn de_duration_range(n : @yaml.YamlNode) -> DurationRange raise De {
  match n.data {
    Str(s) =>
      match DurationRange::from_str(s) {
        Ok(v) => v
        Err(e) => raise De(e.to_string())
      }
    Map(_) => {
      let mut start = None
      let mut end = None
      for pair in map_entries(n) {
        let (k, v) = pair
        match k {
          "start" => start = Some(at_node(v, () => de_duration(v)))
          "end" => end = Some(at_node(v, () => de_duration(v)))
          _ => ()
        }
      }
      check_complete(n)
      guard start is Some(start) else { raise De("missing field `start`") }
      guard end is Some(end) else { raise De("missing field `end`") }
      { start, end, }
    }
    _ =>
      raise invalid_type(
        n, "two durations separated by a hyphen or a map with a `from` and `to` field",
      )
  }
}

///|
fn de_maybe_duration_range(
  n : @yaml.YamlNode,
) -> MaybeTyped[DurationRange] raise De {
  de_maybe_typed(n, de_duration_range)
}

///|
fn de_url(n : @yaml.YamlNode) -> Url raise De {
  match n.data {
    Str(s) =>
      match Url::parse(s) {
        Ok(u) => u
        Err(e) => raise De(e.to_string())
      }
    _ => raise invalid_type(n, "a string representing an URL")
  }
}

///|
fn de_qualified_url(n : @yaml.YamlNode) -> QualifiedUrl raise De {
  match n.data {
    Str(s) =>
      match QualifiedUrl::from_str(s) {
        Ok(u) => u
        Err(e) => raise De(e.to_string())
      }
    Map(_) => {
      let mut value = None
      let mut visit_date = None
      for pair in map_entries(n) {
        let (k, v) = pair
        match k {
          "value" => value = Some(at_node(v, () => de_url(v)))
          "date" => visit_date = de_field(v, de_date)
          _ => ()
        }
      }
      check_complete(n)
      guard value is Some(value) else { raise De("missing field `value`") }
      { value, visit_date, }
    }
    _ =>
      raise invalid_type(
        n, "URL string or dictionary with keys \"url\" and \"date\"",
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
fn de_serial_number(n : @yaml.YamlNode) -> SerialNumber raise De {
  check_complete(n)
  match n.data {
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
      match string_or_number(n.data) {
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
fn de_language(n : @yaml.YamlNode) -> LanguageIdentifier raise De {
  match n.data {
    Str(s) =>
      match LanguageIdentifier::parse(s) {
        Some(l) => l
        None => raise De("Invalid subtag")
      }
    _ => raise invalid_type(n, "a string")
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
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BibLaTeXError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BibLaTeXError with @debug.Debug::{to_repr}

///|
pub impl Show for BibLaTeXError with fn output(self, logger) {
  match self {
    Parse(err) => logger.write_string("biblatex parse error: \{err}")
    Type(err) => logger.write_string("biblatex type error: \{err}")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BibLaTeXError with Show::{to_string, output}

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
