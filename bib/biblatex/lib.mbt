// Port of `biblatex/src/lib.rs` (0.12.0): parsing Bib(La)TeX files.
//
// The BibLaTeX/BibTeX writers and `Entry::verify` are not ported (not used
// by hayagriva's loading).

///|
/// A fully parsed bibliography.
pub struct Bibliography {
  /// The bibliography entries.
  priv entries : Array[Entry]
  /// Maps from citation keys to indices in `items`.
  priv keys : Map[String, Int]
}

///|
/// A bibliography entry containing chunk fields, which can be parsed into
/// more specific types on demand.
pub(all) struct Entry {
  /// The citation key.
  key : String
  /// Denotes the type of bibliography item (e.g., `Article`).
  entry_type : EntryType
  /// Maps from field names to their associated chunk vectors.
  fields : Map[String, Chunks]
}

///|
/// Errors that can occur when retrieving a field of an [`Entry`].
pub(all) enum RetrievalError {
  /// The entry has no field with this name.
  Missing(String)
  /// The field contains malformed data.
  TypeError(TypeError)
} derive(Eq, Debug)

///|
pub impl Show for RetrievalError with fn output(self, logger) {
  match self {
    Missing(s) => logger.write_string("field \{s} is missing")
    TypeError(err) => logger.write_string("\{err}")
  }
}

///|
fn[T] convert_result(r : Result[T, RetrievalError]) -> Result[T?, TypeError] {
  match r {
    Ok(val) => Ok(Some(val))
    Err(Missing(_)) => Ok(None)
    Err(TypeError(err)) => Err(err)
  }
}

///|
/// Create a new, empty bibliography.
pub fn Bibliography::new() -> Bibliography {
  { entries: [], keys: {}, }
}

///|
/// Parse a bibliography from a source string.
pub fn Bibliography::parse(src : String) -> Result[Bibliography, ParseError] {
  match RawBibliography::parse(src) {
    Ok(raw) => Bibliography::from_raw(raw)
    Err(e) => Err(e)
  }
}

///|
/// Construct a bibliography from a raw bibliography, with the `xdata` and
/// `crossref` links resolved.
pub fn Bibliography::from_raw(
  raw : RawBibliography,
) -> Result[Bibliography, ParseError] {
  let res = Bibliography::new()
  let abbr : Map[String, Field] = Map([])
  for p in raw.abbreviations {
    abbr.set(p.key.v, p.value.v)
  }
  for entry in raw.entries {
    // Check that the key is not repeated
    if res.get(entry.v.key.v) is Some(_) {
      return Err({ span: entry.span, kind: DuplicateKey(entry.v.key.v), })
    }
    let fields : Map[String, Chunks] = Map([])
    for spanned_field in entry.v.fields {
      let field_key = @unscanny.to_ascii_lowercase(spanned_field.key.v)
      match parse_field(field_key, spanned_field.value.v, abbr) {
        Ok(parsed) => fields.set(field_key, parsed)
        Err(e) => return Err(e)
      }
    }
    res.insert({
      key: entry.v.key.v,
      entry_type: EntryType::new(entry.v.kind.v),
      fields,
    })
    |> ignore
  }
  let entries = res.entries.map(e => e.copy())
  for entry in entries {
    if entry.resolve_crossrefs(res) is Err(e) {
      return Err({ span: e.span, kind: ResolutionError(e.kind), })
    }
  }
  res.entries.clear()
  res.entries.append(entries)
  Ok(res)
}

///|
/// The number of bibliography entries.
pub fn Bibliography::length(self : Bibliography) -> Int {
  self.entries.length()
}

///|
/// Whether the bibliography is empty.
pub fn Bibliography::is_empty(self : Bibliography) -> Bool {
  self.entries.is_empty()
}

///|
/// Returns the entry with the given cite key.
pub fn Bibliography::get(self : Bibliography, key : String) -> Entry? {
  match self.keys.get(key) {
    Some(index) => self.entries.get(index)
    None => None
  }
}

///|
/// Insert an entry into the bibliography.
///
/// If an entry with the same cite key is already present, the entry is
/// updated and the old entry is returned.
pub fn Bibliography::insert(self : Bibliography, entry : Entry) -> Entry? {
  match self.keys.get(entry.key) {
    Some(index) => {
      let prev = self.entries[index]
      self.entries[index] = entry
      Some(prev)
    }
    None => {
      let index = self.entries.length()
      self.keys.set(entry.key, index)
      match convert_result(entry.get_as("ids", parse_string_list)) {
        Ok(Some(ids)) =>
          for alias_ in ids {
            self.keys.set(alias_, index)
          }
        // Upstream unwraps; parsing a string list never fails.
        _ => ()
      }
      self.entries.push(entry)
      None
    }
  }
}

///|
/// An iterator over the bibliography's entries.
pub fn Bibliography::iter(self : Bibliography) -> Iter[Entry] {
  self.entries.iter()
}

///|
/// The bibliography's entries.
pub fn Bibliography::entries(self : Bibliography) -> Array[Entry] {
  self.entries
}

///|
/// An iterator over the bibliography's entry keys.
pub fn Bibliography::keys(self : Bibliography) -> Array[String] {
  self.entries.map(e => e.key)
}

///|
/// Construct new, empty entry.
pub fn Entry::new(key : String, entry_type : EntryType) -> Entry {
  { key, entry_type, fields: {}, }
}

///|
/// A deep copy of the entry.
pub fn Entry::copy(self : Entry) -> Entry {
  let fields : Map[String, Chunks] = Map([])
  for k, v in self.fields {
    fields.set(k, clone_chunks(v))
  }
  { key: self.key, entry_type: self.entry_type, fields, }
}

///|
/// The field keys in sorted order (upstream's `BTreeMap` order).
pub fn Entry::sorted_keys(self : Entry) -> Array[String] {
  let keys = self.fields.keys().collect()
  keys.sort_by((a, b) => @unscanny.compare_str(a, b))
  keys
}

///|
/// Get the chunk slice of a field.
///
/// The field key must be lowercase.
pub fn Entry::get(self : Entry, key : String) -> Chunks? {
  self.fields.get(key)
}

///|
/// Parse the value of a field into a specific type.
///
/// The field key must be lowercase.
pub fn[T] Entry::get_as(
  self : Entry,
  key : String,
  parse : (ArrayView[Spanned[Chunk]]) -> Result[T, TypeError],
) -> Result[T, RetrievalError] {
  match self.get(key) {
    None => Err(Missing(key))
    Some(chunks) =>
      match parse(chunks) {
        Ok(v) => Ok(v)
        Err(e) => Err(TypeError(e))
      }
  }
}

///|
/// Set the chunk slice for a field.
///
/// The field key is lowercase before insertion.
pub fn Entry::set(self : Entry, key : String, chunks : Chunks) -> Unit {
  self.fields.set(@unscanny.to_lowercase(key), chunks)
}

///|
/// Remove a field from the entry.
pub fn Entry::remove(self : Entry, key : String) -> Chunks? {
  let v = self.fields.get(key)
  self.fields.remove(key)
  v
}

///|
/// The parents of an entry in a semantic sense (`crossref` and `xref`).
pub fn Entry::parents(self : Entry) -> Result[Array[String], TypeError] {
  let parents = []
  match convert_result(self.get_as("crossref", parse_string)) {
    Ok(Some(crossref)) => parents.push(crossref)
    Ok(None) => ()
    Err(e) => return Err(e)
  }
  match convert_result(self.get_as("xref", parse_string_list)) {
    Ok(Some(xrefs)) => parents.append(xrefs)
    Ok(None) => ()
    Err(e) => return Err(e)
  }
  Ok(parents)
}

///|
/// Get an entry but return None for empty chunk slices.
fn Entry::get_non_empty(self : Entry, key : String) -> Chunks? {
  match self.get(key) {
    Some(entry) if !entry.is_empty() => Some(entry)
    _ => None
  }
}

///|
/// Resolves all data dependencies defined by `crossref` and `xdata` fields.
fn Entry::resolve_crossrefs(
  self : Entry,
  bib : Bibliography,
) -> Result[Unit, TypeError] {
  let refs = []
  match convert_result(self.get_as("crossref", parse_string)) {
    Ok(Some(crossref)) =>
      if bib.get(crossref) is Some(e) {
        refs.push(e.copy())
      }
    Ok(None) => ()
    Err(e) => return Err(e)
  }
  match convert_result(self.get_as("xdata", parse_string_list)) {
    Ok(Some(keys)) =>
      for key in keys {
        if bib.get(key) is Some(e) {
          refs.push(e.copy())
        }
      }
    Ok(None) => ()
    Err(e) => return Err(e)
  }
  for crossref in refs {
    if crossref.resolve_crossrefs(bib) is Err(e) {
      return Err(e)
    }
    if self.resolve_single_crossref(crossref) is Err(e) {
      return Err(e)
    }
  }
  self.remove("xdata") |> ignore
  Ok(())
}

///|
/// Resolve data dependencies using another entry.
fn Entry::resolve_single_crossref(
  self : Entry,
  crossref : Entry,
) -> Result[Unit, TypeError] {
  let req = self.entry_type.requirements()
  let relevant = req.required.copy()
  relevant.append(req.optional)
  relevant.append(req.page_chapter_field.possible())
  relevant.append(req.author_eds_field.possible())
  if self.entry_type == XData {
    for f in crossref.sorted_keys() {
      relevant.push(f)
    }
  }
  for f in relevant {
    if self.get(f) is Some(_) {
      continue
    }
    match f {
      "journaltitle" | "journalsubtitle" if crossref.entry_type == Periodical => {
        let key = if f.contains("s") { "subtitle" } else { "title" }
        if crossref.get(key) is Some(item) {
          self.set(f, clone_chunks(item))
        }
      }
      "booktitle" | "booksubtitle" | "booktitleaddon" if crossref.entry_type.is_collection() => {
        let key = if f.contains("s") {
          "subtitle"
        } else if f.contains("a") {
          "titleaddon"
        } else {
          "title"
        }
        if crossref.get(key) is Some(item) {
          self.set(f, clone_chunks(item))
        }
      }
      "maintitle" | "mainsubtitle" | "maintitleaddon" if crossref.entry_type.is_multi_volume() => {
        let key = if f.contains("s") {
          "subtitle"
        } else if f.contains("a") {
          "titleaddon"
        } else {
          "title"
        }
        if crossref.get(key) is Some(item) {
          self.set(f, clone_chunks(item))
        }
      }
      "address" =>
        match or_opt(crossref.get(f), crossref.get("location")) {
          Some(item) => self.set(f, clone_chunks(item))
          None => ()
        }
      "institution" =>
        match or_opt(crossref.get(f), crossref.get("school")) {
          Some(item) => self.set(f, clone_chunks(item))
          None => ()
        }
      "school" =>
        match or_opt(crossref.get(f), crossref.get("institution")) {
          Some(item) => self.set(f, clone_chunks(item))
          None => ()
        }
      "journaltitle" =>
        match or_opt(crossref.get(f), crossref.get("journal")) {
          Some(item) => self.set(f, clone_chunks(item))
          None => ()
        }
      "title" | "addendum" | "note" => ()
      _ => if crossref.get(f) is Some(item) { self.set(f, clone_chunks(item)) }
    }
  }
  if self.entry_type == XData {
    return Ok(())
  }
  if req.needs_date {
    match convert_result(crossref.date()) {
      Ok(Some(date)) => self.set_date(date)
      Ok(None) => ()
      Err(e) => return Err(e)
    }
  }
  Ok(())
}

// Field getters (upstream's `fields!`, `alias_fields!` and `date_fields!`
// macros).

///|
fn Entry::chunks_field(
  self : Entry,
  field : String,
) -> Result[Chunks, RetrievalError] {
  match self.get(field) {
    Some(c) => Ok(c)
    None => Err(Missing(field))
  }
}

///|
fn Entry::alias_chunks(
  self : Entry,
  field : String,
  alias_ : String,
) -> Result[Chunks, RetrievalError] {
  match or_opt(self.get(field), self.get(alias_)) {
    Some(c) => Ok(c)
    None => Err(Missing(field))
  }
}

///|
fn[T] Entry::typed_field(
  self : Entry,
  field : String,
  parse : (ArrayView[Spanned[Chunk]]) -> Result[T, TypeError],
) -> Result[T, RetrievalError] {
  self.get_as(field, parse)
}

///|
fn[T] Entry::alias_typed(
  self : Entry,
  field : String,
  alias_ : String,
  parse : (ArrayView[Spanned[Chunk]]) -> Result[T, TypeError],
) -> Result[T, RetrievalError] {
  match or_opt(self.get(field), self.get(alias_)) {
    Some(c) =>
      match parse(c) {
        Ok(v) => Ok(v)
        Err(e) => Err(TypeError(e))
      }
    None => Err(Missing(field))
  }
}

///|
fn parse_permissive_i64(
  c : ArrayView[Spanned[Chunk]],
) -> Result[PermissiveType[Int64], TypeError] {
  Ok(parse_permissive(c, parse_i64))
}

///|
fn parse_permissive_ranges(
  c : ArrayView[Spanned[Chunk]],
) -> Result[PermissiveType[Array[IntRange]], TypeError] {
  Ok(parse_permissive(c, parse_ranges))
}

///|
fn parse_permissive_language(
  c : ArrayView[Spanned[Chunk]],
) -> Result[PermissiveType[Language], TypeError] {
  Ok(parse_permissive(c, parse_language))
}

// BibTeX fields.

///|
/// Get the `author` field.
pub fn Entry::author(self : Entry) -> Result[Array[Person], RetrievalError] {
  self.typed_field("author", parse_persons)
}

///|
/// Get the `booktitle` field.
pub fn Entry::book_title(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("booktitle")
}

///|
/// Get the `chapter` field.
pub fn Entry::chapter(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("chapter")
}

///|
/// Get the `edition` field.
pub fn Entry::edition(
  self : Entry,
) -> Result[PermissiveType[Int64], RetrievalError] {
  self.typed_field("edition", parse_permissive_i64)
}

///|
/// Get the `howpublished` field.
pub fn Entry::how_published(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("howpublished")
}

///|
/// Get the `note` field.
pub fn Entry::note(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("note")
}

///|
/// Get the `number` field.
pub fn Entry::number(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("number")
}

///|
/// Get the `organization` field.
pub fn Entry::organization(
  self : Entry,
) -> Result[Array[Chunks], RetrievalError] {
  self.typed_field("organization", parse_chunks_list)
}

///|
/// Get the `pages` field.
pub fn Entry::pages(
  self : Entry,
) -> Result[PermissiveType[Array[IntRange]], RetrievalError] {
  self.typed_field("pages", parse_permissive_ranges)
}

///|
/// Get the `publisher` field.
pub fn Entry::publisher(self : Entry) -> Result[Array[Chunks], RetrievalError] {
  self.typed_field("publisher", parse_chunks_list)
}

///|
/// Get the `series` field.
pub fn Entry::series(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("series")
}

///|
/// Get the `title` field.
pub fn Entry::title(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("title")
}

///|
/// Get the `type` field.
pub fn Entry::type_(self : Entry) -> Result[String, RetrievalError] {
  self.typed_field("type", parse_string)
}

///|
/// Get the `volume` field.
pub fn Entry::volume(
  self : Entry,
) -> Result[PermissiveType[Int64], RetrievalError] {
  self.typed_field("volume", parse_permissive_i64)
}

// Alias fields.

///|
/// Get the `address` field, falling back on `location`.
pub fn Entry::address(self : Entry) -> Result[Chunks, RetrievalError] {
  self.alias_chunks("address", "location")
}

///|
/// Get the `location` field, falling back on `address`.
pub fn Entry::location(self : Entry) -> Result[Chunks, RetrievalError] {
  self.alias_chunks("location", "address")
}

///|
/// Get the `annotation` field, falling back on `annote`.
pub fn Entry::annotation(self : Entry) -> Result[Chunks, RetrievalError] {
  self.alias_chunks("annotation", "annote")
}

///|
/// Get the `eprinttype` field, falling back on `archiveprefix`.
pub fn Entry::eprint_type(self : Entry) -> Result[Chunks, RetrievalError] {
  self.alias_chunks("eprinttype", "archiveprefix")
}

///|
/// Get the `eprintclass` field, falling back on `primaryclass`.
pub fn Entry::eprint_class(self : Entry) -> Result[Chunks, RetrievalError] {
  self.alias_chunks("eprintclass", "primaryclass")
}

///|
/// Get the `journal` field, falling back on `journaltitle`.
pub fn Entry::journal(self : Entry) -> Result[Chunks, RetrievalError] {
  self.alias_chunks("journal", "journaltitle")
}

///|
/// Get the `journaltitle` field, falling back on `journal`.
pub fn Entry::journal_title(self : Entry) -> Result[Chunks, RetrievalError] {
  self.alias_chunks("journaltitle", "journal")
}

///|
/// Get the `key` field, falling back on `sortkey`.
pub fn Entry::sort_key(self : Entry) -> Result[String, RetrievalError] {
  self.alias_typed("key", "sortkey", parse_string)
}

///|
/// Get the `file` field, falling back on `pdf`.
pub fn Entry::file(self : Entry) -> Result[String, RetrievalError] {
  self.alias_typed("file", "pdf", parse_string)
}

///|
/// Get the `school` field, falling back on `institution`.
pub fn Entry::school(self : Entry) -> Result[Chunks, RetrievalError] {
  self.alias_chunks("school", "institution")
}

///|
/// Get the `institution` field, falling back on `school`.
pub fn Entry::institution(self : Entry) -> Result[Chunks, RetrievalError] {
  self.alias_chunks("institution", "school")
}

// Date fields.

///|
fn Entry::date_field(
  self : Entry,
  prefix : String,
) -> Result[PermissiveType[Date], RetrievalError] {
  match self.get(prefix + "date") {
    Some(chunks) =>
      match Date::parse(chunks) {
        Ok(d) => Ok(Typed(d))
        Err(_) => Ok(Chunks(clone_chunks(chunks)))
      }
    None => {
      let year = match self.get(prefix + "year") {
        Some(y) => y
        None => return Err(Missing("year"))
      }
      let month = self.get(prefix + "month").map(c => c[:])
      let day = self.get(prefix + "day").map(c => c[:])
      match Date::parse_three_fields(year, month, day) {
        Ok(d) => Ok(Typed(d))
        Err(e) => Err(TypeError(e))
      }
    }
  }
}

///|
fn Entry::set_date_field(
  self : Entry,
  prefix : String,
  item : PermissiveType[Date],
) -> Unit {
  self.set(prefix + "date", permissive_to_chunks(item, date_to_chunks))
  self.remove(prefix + "year") |> ignore
  self.remove(prefix + "month") |> ignore
  self.remove(prefix + "day") |> ignore
}

///|
/// Get the `date` field, falling back on the `year`, `month`, and `day`
/// fields if it is not present.
pub fn Entry::date(
  self : Entry,
) -> Result[PermissiveType[Date], RetrievalError] {
  self.date_field("")
}

///|
/// Set the value of the `date` field, removing the `year`, `month`, and
/// `day` fields if present.
pub fn Entry::set_date(self : Entry, item : PermissiveType[Date]) -> Unit {
  self.set_date_field("", item)
}

///|
/// Get the `eventdate` field, falling back on the `eventyear`,
/// `eventmonth`, and `eventday` fields if it is not present.
pub fn Entry::event_date(
  self : Entry,
) -> Result[PermissiveType[Date], RetrievalError] {
  self.date_field("event")
}

///|
/// Get the `origdate` field, falling back on the `origyear`, `origmonth`,
/// and `origday` fields if it is not present.
pub fn Entry::orig_date(
  self : Entry,
) -> Result[PermissiveType[Date], RetrievalError] {
  self.date_field("orig")
}

///|
/// Get the `urldate` field, falling back on the `urlyear`, `urlmonth`, and
/// `urlday` fields if it is not present.
pub fn Entry::url_date(
  self : Entry,
) -> Result[PermissiveType[Date], RetrievalError] {
  self.date_field("url")
}

///|
/// Get the `editor` and `editora` through `editorc` fields and their
/// respective `editortype` annotation fields, returning a vector with zero
/// to four entries, one for each editorial role.
///
/// The default `EditorType::Editor` is assumed if the type field is empty.
pub fn Entry::editors(
  self : Entry,
) -> Result[Array[(Array[Person], EditorType)], TypeError] {
  let editors = []
  for
    pair in [
      ("editor", "editortype"),
      ("editora", "editoratype"),
      ("editorb", "editorbtype"),
      ("editorc", "editorctype"),
    ] {
    let (name_field, editor_field) = pair
    match convert_result(self.get_as(name_field, parse_persons)) {
      Ok(Some(persons)) => {
        let editor_type = match self.get(editor_field) {
          Some(chunks) =>
            match parse_editor_type(chunks) {
              Ok(t) => t
              Err(e) => return Err(e)
            }
          None => Editor
        }
        editors.push((persons, editor_type))
      }
      Ok(None) => ()
      Err(e) => return Err(e)
    }
  }
  Ok(editors)
}

// BibLaTeX supplemental fields.

///|
/// Get the `abstract` field.
pub fn Entry::abstract_(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("abstract")
}

///|
/// Get the `addendum` field.
pub fn Entry::addendum(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("addendum")
}

///|
/// Get the `afterword` field.
pub fn Entry::afterword(self : Entry) -> Result[Array[Person], RetrievalError] {
  self.typed_field("afterword", parse_persons)
}

///|
/// Get the `annotator` field.
pub fn Entry::annotator(self : Entry) -> Result[Array[Person], RetrievalError] {
  self.typed_field("annotator", parse_persons)
}

///|
/// Get the `authortype` field.
pub fn Entry::author_type(self : Entry) -> Result[String, RetrievalError] {
  self.typed_field("authortype", parse_string)
}

///|
/// Get the `bookauthor` field.
pub fn Entry::book_author(
  self : Entry,
) -> Result[Array[Person], RetrievalError] {
  self.typed_field("bookauthor", parse_persons)
}

///|
/// Get the `bookpagination` field.
pub fn Entry::book_pagination(
  self : Entry,
) -> Result[Pagination, RetrievalError] {
  self.typed_field("bookpagination", parse_pagination)
}

///|
/// Get the `booksubtitle` field.
pub fn Entry::book_subtitle(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("booksubtitle")
}

///|
/// Get the `booktitleaddon` field.
pub fn Entry::book_title_addon(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("booktitleaddon")
}

///|
/// Get the `commentator` field.
pub fn Entry::commentator(
  self : Entry,
) -> Result[Array[Person], RetrievalError] {
  self.typed_field("commentator", parse_persons)
}

///|
/// Get the `doi` field.
pub fn Entry::doi(self : Entry) -> Result[String, RetrievalError] {
  self.typed_field("doi", parse_string)
}

///|
/// Get the `eid` field.
pub fn Entry::eid(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("eid")
}

///|
/// Get the `entrysubtype` field.
pub fn Entry::entry_subtype(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("entrysubtype")
}

///|
/// Get the `eprint` field.
pub fn Entry::eprint(self : Entry) -> Result[String, RetrievalError] {
  self.typed_field("eprint", parse_string)
}

///|
/// Get the `eventtitle` field.
pub fn Entry::eventtitle(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("eventtitle")
}

///|
/// Get the `eventtitleaddon` field.
pub fn Entry::eventtitle_addon(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("eventtitleaddon")
}

///|
/// Get the `foreword` field.
pub fn Entry::foreword(self : Entry) -> Result[Array[Person], RetrievalError] {
  self.typed_field("foreword", parse_persons)
}

///|
/// Get the `holder` field.
pub fn Entry::holder(self : Entry) -> Result[Array[Person], RetrievalError] {
  self.typed_field("holder", parse_persons)
}

///|
/// Get the `indextitle` field.
pub fn Entry::index_title(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("indextitle")
}

///|
/// Get the `introduction` field.
pub fn Entry::introduction(
  self : Entry,
) -> Result[Array[Person], RetrievalError] {
  self.typed_field("introduction", parse_persons)
}

///|
/// Get the `isan` field.
pub fn Entry::isan(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("isan")
}

///|
/// Get the `isbn` field.
pub fn Entry::isbn(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("isbn")
}

///|
/// Get the `ismn` field.
pub fn Entry::ismn(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("ismn")
}

///|
/// Get the `isrn` field.
pub fn Entry::isrn(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("isrn")
}

///|
/// Get the `issn` field.
pub fn Entry::issn(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("issn")
}

///|
/// Get the `issue` field.
pub fn Entry::issue(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("issue")
}

///|
/// Get the `issuesubtitle` field.
pub fn Entry::issue_subtitle(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("issuesubtitle")
}

///|
/// Get the `issuetitle` field.
pub fn Entry::issue_title(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("issuetitle")
}

///|
/// Get the `issuetitleaddon` field.
pub fn Entry::issue_title_addon(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("issuetitleaddon")
}

///|
/// Get the `iswc` field.
pub fn Entry::iswc(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("iswc")
}

///|
/// Get the `journalsubtitle` field.
pub fn Entry::journal_subtitle(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("journalsubtitle")
}

///|
/// Get the `journaltitleaddon` field.
pub fn Entry::journal_title_addon(
  self : Entry,
) -> Result[Chunks, RetrievalError] {
  self.chunks_field("journaltitleaddon")
}

///|
/// Get the `keywords` field.
pub fn Entry::keywords(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("keywords")
}

///|
/// Get the `label` field.
pub fn Entry::label(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("label")
}

///|
/// Get the `langid` field.
pub fn Entry::langid(
  self : Entry,
) -> Result[PermissiveType[Language], RetrievalError] {
  self.typed_field("langid", parse_permissive_language)
}

///|
/// Get the `language` field.
pub fn Entry::language(
  self : Entry,
) -> Result[Array[PermissiveType[Language]], RetrievalError] {
  self.typed_field("language", parse_languages)
}

///|
/// Get the `library` field.
pub fn Entry::library(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("library")
}

///|
/// Get the `mainsubtitle` field.
pub fn Entry::main_subtitle(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("mainsubtitle")
}

///|
/// Get the `maintitle` field.
pub fn Entry::main_title(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("maintitle")
}

///|
/// Get the `maintitleaddon` field.
pub fn Entry::main_title_addon(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("maintitleaddon")
}

///|
/// Get the `nameaddon` field.
pub fn Entry::name_addon(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("nameaddon")
}

///|
/// Get the `options` field.
pub fn Entry::options(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("options")
}

///|
/// Get the `origlanguage` field.
pub fn Entry::orig_language(
  self : Entry,
) -> Result[Array[String], RetrievalError] {
  self.typed_field("origlanguage", parse_string_list)
}

///|
/// Get the `origlocation` field.
pub fn Entry::orig_location(
  self : Entry,
) -> Result[Array[Chunks], RetrievalError] {
  self.typed_field("origlocation", parse_chunks_list)
}

///|
/// Get the `pagetotal` field.
pub fn Entry::page_total(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("pagetotal")
}

///|
/// Get the `pagination` field.
pub fn Entry::pagination(self : Entry) -> Result[Pagination, RetrievalError] {
  self.typed_field("pagination", parse_pagination)
}

///|
/// Get the `part` field.
pub fn Entry::part(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("part")
}

///|
/// Get the `pubstate` field.
pub fn Entry::pubstate(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("pubstate")
}

///|
/// Get the `reprinttitle` field.
pub fn Entry::reprint_title(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("reprinttitle")
}

///|
/// Get the `shortauthor` field.
pub fn Entry::short_author(
  self : Entry,
) -> Result[Array[Person], RetrievalError] {
  self.typed_field("shortauthor", parse_persons)
}

///|
/// Get the `shorteditor` field.
pub fn Entry::short_editor(
  self : Entry,
) -> Result[Array[Person], RetrievalError] {
  self.typed_field("shorteditor", parse_persons)
}

///|
/// Get the `shorthand` field.
pub fn Entry::shorthand(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("shorthand")
}

///|
/// Get the `shorthandintro` field.
pub fn Entry::shorthand_intro(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("shorthandintro")
}

///|
/// Get the `shortjournal` field.
pub fn Entry::short_journal(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("shortjournal")
}

///|
/// Get the `shortseries` field.
pub fn Entry::short_series(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("shortseries")
}

///|
/// Get the `shorttitle` field.
pub fn Entry::short_title(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("shorttitle")
}

///|
/// Get the `subtitle` field.
pub fn Entry::subtitle(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("subtitle")
}

///|
/// Get the `titleaddon` field.
pub fn Entry::title_addon(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("titleaddon")
}

///|
/// Get the `translator` field.
pub fn Entry::translator(self : Entry) -> Result[Array[Person], RetrievalError] {
  self.typed_field("translator", parse_persons)
}

///|
/// Get the `url` field.
pub fn Entry::url(self : Entry) -> Result[String, RetrievalError] {
  self.typed_field("url", parse_string)
}

///|
/// Get the `venue` field.
pub fn Entry::venue(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("venue")
}

///|
/// Get the `version` field.
pub fn Entry::version(self : Entry) -> Result[Chunks, RetrievalError] {
  self.chunks_field("version")
}

///|
/// Get the `volumes` field.
pub fn Entry::volumes(self : Entry) -> Result[Int64, RetrievalError] {
  self.typed_field("volumes", parse_i64)
}

///|
/// Get the `gender` field.
pub fn Entry::gender(self : Entry) -> Result[Gender, RetrievalError] {
  self.typed_field("gender", parse_gender)
}

///|
/// Rust's `Option::or`.
fn[T] or_opt(a : T?, b : T?) -> T? {
  match a {
    Some(_) => a
    None => b
  }
}
