// Port of `hayagriva/src/lib.rs` (0.10.1): the bibliography data model.

///|
/// A collection of bibliographic entries.
pub struct Library {
  priv entries : Array[Entry]
}

///|
/// Construct a new, empty bibliography library.
pub fn Library::new() -> Library {
  { entries: [], }
}

///|
/// Add an entry to the library (replacing an entry with the same key in
/// place, like `IndexMap::insert`).
pub fn Library::push(self : Library, entry : Entry) -> Unit {
  for i, e in self.entries {
    if e.key == entry.key {
      self.entries[i] = entry
      return
    }
  }
  self.entries.push(entry)
}

///|
/// Retrieve an entry from the library.
pub fn Library::get(self : Library, key : String) -> Entry? {
  for e in self.entries {
    if e.key == key {
      return Some(e)
    }
  }
  None
}

///|
/// Get an iterator over the entries in the library.
pub fn Library::iter(self : Library) -> Iter[Entry] {
  self.entries.iter()
}

///|
/// The entries in the library.
pub fn Library::entries(self : Library) -> Array[Entry] {
  self.entries
}

///|
/// Get the keys in the library.
pub fn Library::keys(self : Library) -> Array[String] {
  self.entries.map(e => e.key)
}

///|
/// Get the length of the library.
pub fn Library::length(self : Library) -> Int {
  self.entries.length()
}

///|
/// Check whether the library is empty.
pub fn Library::is_empty(self : Library) -> Bool {
  self.entries.is_empty()
}

///|
/// Get the nth entry in the library.
pub fn Library::nth(self : Library, n : Int) -> Entry? {
  self.entries.get(n)
}

///|
/// `FromIterator<Entry> for Library` (later duplicates replace earlier
/// ones in place).
pub fn Library::from_entries(entries : Array[Entry]) -> Library {
  let lib = Library::new()
  for e in entries {
    lib.push(e)
  }
  lib
}

///|
/// A language identifier (port of the parts of `unic_langid` that are
/// used).
pub(all) struct LanguageIdentifier {
  /// The language subtag (lowercase).
  language : String
  /// The script subtag (titlecase).
  script : String?
  /// The region subtag (uppercase).
  region : String?
  /// Variant subtags (lowercase).
  variants : Array[String]
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LanguageIdentifier with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LanguageIdentifier with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LanguageIdentifier with @debug.Debug::{to_repr}

///|
/// Parse a language identifier like `unic_langid`.
pub fn LanguageIdentifier::parse(s : String) -> LanguageIdentifier? {
  let parts = @unscanny.split_by(s, c => c == '-' || c == '_')
  if parts.is_empty() {
    return None
  }
  let all_alpha = (p : String) => p.iter().all(c => c.is_ascii_alphabetic())
  let all_digit = (p : String) => p.iter().all(c => c.is_ascii_digit())
  let all_alnum = (p : String) => {
    p.iter().all(c => c.is_ascii_alphabetic() || c.is_ascii_digit())
  }
  let lang = parts[0]
  let language = if lang == "und" {
    "und"
  } else if all_alpha(lang) &&
    (
      lang.length() == 2 ||
      lang.length() == 3 ||
      (lang.length() >= 5 && lang.length() <= 8)
    ) {
    @unscanny.to_ascii_lowercase(lang)
  } else {
    return None
  }
  let mut i = 1
  let mut script = None
  let mut region = None
  let variants = []
  if i < parts.length() && parts[i].length() == 4 && all_alpha(parts[i]) {
    let p = @unscanny.to_ascii_lowercase(parts[i])
    script = Some(
      @unscanny.to_ascii_uppercase(p[0:1].to_owned()) + p[1:].to_owned(),
    )
    i += 1
  }
  if i < parts.length() &&
    (
      (parts[i].length() == 2 && all_alpha(parts[i])) ||
      (parts[i].length() == 3 && all_digit(parts[i]))
    ) {
    region = Some(@unscanny.to_ascii_uppercase(parts[i]))
    i += 1
  }
  while i < parts.length() {
    let p = parts[i]
    let ok = all_alnum(p) &&
      (
        (p.length() >= 5 && p.length() <= 8) ||
        (p.length() == 4 && p.iter().take(1).all(c => c.is_ascii_digit()))
      )
    if !ok {
      return None
    }
    variants.push(@unscanny.to_ascii_lowercase(p))
    i += 1
  }
  Some({ language, script, region, variants, })
}

///|
pub impl Show for LanguageIdentifier with fn output(self, logger) {
  logger.write_string(self.language)
  if self.script is Some(s) {
    logger.write_string("-" + s)
  }
  if self.region is Some(r) {
    logger.write_string("-" + r)
  }
  for v in self.variants {
    logger.write_string("-" + v)
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LanguageIdentifier with Show::{to_string, output}

///|
/// A citable item in a bibliography.
pub(all) struct Entry {
  /// The key of the entry.
  key : String
  /// The type of the item.
  mut entry_type : EntryType
  /// Title of the item.
  mut title_ : FormatString?
  /// Persons primarily responsible for creating the item.
  mut authors_ : Array[Person]?
  /// Date at which the item was published.
  mut date_ : Date?
  /// Persons responsible for selecting and revising the content of the
  /// item.
  mut editors_ : Array[Person]?
  /// Persons involved in the production of the item that are not authors
  /// or editors.
  mut affiliated_ : Array[PersonsWithRoles]?
  /// Publisher of the item, which may have a name and a location.
  mut publisher_ : Publisher?
  /// Physical location at which an entry is physically located or took
  /// place.
  mut location_ : FormatString?
  /// Organization at/for which the item was created.
  mut organization_ : FormatString?
  /// For an item whose parent has multiple issues, indicates the position in
  /// the issue sequence. Also used to indicate the episode number for TV.
  mut issue_ : MaybeTyped[Numeric]?
  /// The number of the chapter in the referenced work where this item can be
  /// found.
  mut chapter_ : MaybeTyped[Numeric]?
  /// For an item whose parent has multiple volumes/parts/seasons ... of
  /// which this item is one.
  mut volume_ : MaybeTyped[Numeric]?
  /// Total number of volumes/parts/seasons ... this item consists of.
  mut volume_total_ : Numeric?
  /// Published version of an item.
  mut edition_ : MaybeTyped[Numeric]?
  /// The range of pages within the parent this item occupies
  mut page_range_ : MaybeTyped[PageRanges]?
  /// The total number of pages the item has.
  mut page_total_ : Numeric?
  /// The time range within the parent this item starts and ends at.
  mut time_range_ : MaybeTyped[DurationRange]?
  /// The total runtime of the item.
  mut runtime_ : MaybeTyped[Duration]?
  /// Canonical public URL of the item, can have access date.
  mut url_ : QualifiedUrl?
  /// Any serial number or version describing the item.
  mut serial_number_ : SerialNumber?
  /// The language of the item.
  mut language_ : LanguageIdentifier?
  /// Name of the institution/collection where the item is kept.
  mut archive_ : FormatString?
  /// Physical location of the institution/collection where the item is
  /// kept.
  mut archive_location_ : FormatString?
  /// The call number of the item in the institution/collection.
  mut call_number_ : FormatString?
  /// Additional description to be appended in the bibliographic entry.
  mut note_ : FormatString?
  /// Abstract of the item (e.g. the abstract of a journal article).
  mut abstract__ : FormatString?
  /// Type, class, or subtype of the item.
  mut genre_ : FormatString?
  /// Item in which the item was published / to which it is strongly
  /// associated to.
  mut parents : Array[Entry]
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Entry with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Entry with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Entry with @debug.Debug::{to_repr}

///|
/// Construct a new, empty entry.
pub fn Entry::new(key : String, entry_type : EntryType) -> Entry {
  {
    key,
    entry_type,
    title_: None,
    authors_: None,
    date_: None,
    editors_: None,
    affiliated_: None,
    publisher_: None,
    location_: None,
    organization_: None,
    issue_: None,
    chapter_: None,
    volume_: None,
    volume_total_: None,
    edition_: None,
    page_range_: None,
    page_total_: None,
    time_range_: None,
    runtime_: None,
    url_: None,
    serial_number_: None,
    language_: None,
    archive_: None,
    archive_location_: None,
    call_number_: None,
    note_: None,
    abstract__: None,
    genre_: None,
    parents: [],
  }
}

///|
/// Get the key of the entry.
pub fn Entry::key(self : Entry) -> String {
  self.key
}

///|
/// Check whether the entry has some key.
pub fn Entry::has(self : Entry, key : String) -> Bool {
  match key {
    "title" => self.title_ is Some(_)
    "author" => self.authors_ is Some(_)
    "date" => self.date_ is Some(_)
    "editor" => self.editors_ is Some(_)
    "affiliated" => self.affiliated_ is Some(_)
    "publisher" => self.publisher_ is Some(_)
    "location" => self.location_ is Some(_)
    "organization" => self.organization_ is Some(_)
    "issue" => self.issue_ is Some(_)
    "chapter" => self.chapter_ is Some(_)
    "volume" => self.volume_ is Some(_)
    "volume-total" => self.volume_total_ is Some(_)
    "edition" => self.edition_ is Some(_)
    "page-range" => self.page_range_ is Some(_)
    "page-total" => self.page_total_ is Some(_)
    "time-range" => self.time_range_ is Some(_)
    "runtime" => self.runtime_ is Some(_)
    "url" => self.url_ is Some(_)
    "serial-number" => self.serial_number_ is Some(_)
    "language" => self.language_ is Some(_)
    "archive" => self.archive_ is Some(_)
    "archive-location" => self.archive_location_ is Some(_)
    "call-number" => self.call_number_ is Some(_)
    "note" => self.note_ is Some(_)
    "abstract" => self.abstract__ is Some(_)
    "genre" => self.genre_ is Some(_)
    _ => false
  }
}

// Getters.

///|
pub fn Entry::title(self : Entry) -> FormatString? {
  self.title_
}

///|
pub fn Entry::authors(self : Entry) -> Array[Person]? {
  self.authors_
}

///|
pub fn Entry::date(self : Entry) -> Date? {
  self.date_
}

///|
pub fn Entry::editors(self : Entry) -> Array[Person]? {
  self.editors_
}

///|
pub fn Entry::affiliated(self : Entry) -> Array[PersonsWithRoles]? {
  self.affiliated_
}

///|
pub fn Entry::publisher(self : Entry) -> Publisher? {
  self.publisher_
}

///|
pub fn Entry::location(self : Entry) -> FormatString? {
  self.location_
}

///|
pub fn Entry::organization(self : Entry) -> FormatString? {
  self.organization_
}

///|
pub fn Entry::issue(self : Entry) -> MaybeTyped[Numeric]? {
  self.issue_
}

///|
pub fn Entry::chapter(self : Entry) -> MaybeTyped[Numeric]? {
  self.chapter_
}

///|
pub fn Entry::volume(self : Entry) -> MaybeTyped[Numeric]? {
  self.volume_
}

///|
pub fn Entry::volume_total(self : Entry) -> Numeric? {
  self.volume_total_
}

///|
pub fn Entry::edition(self : Entry) -> MaybeTyped[Numeric]? {
  self.edition_
}

///|
pub fn Entry::page_range(self : Entry) -> MaybeTyped[PageRanges]? {
  self.page_range_
}

///|
pub fn Entry::page_total(self : Entry) -> Numeric? {
  self.page_total_
}

///|
pub fn Entry::time_range(self : Entry) -> MaybeTyped[DurationRange]? {
  self.time_range_
}

///|
pub fn Entry::runtime(self : Entry) -> MaybeTyped[Duration]? {
  self.runtime_
}

///|
pub fn Entry::url(self : Entry) -> QualifiedUrl? {
  self.url_
}

///|
pub fn Entry::serial_number(self : Entry) -> SerialNumber? {
  self.serial_number_
}

///|
pub fn Entry::language(self : Entry) -> LanguageIdentifier? {
  self.language_
}

///|
pub fn Entry::archive(self : Entry) -> FormatString? {
  self.archive_
}

///|
pub fn Entry::archive_location(self : Entry) -> FormatString? {
  self.archive_location_
}

///|
pub fn Entry::call_number(self : Entry) -> FormatString? {
  self.call_number_
}

///|
pub fn Entry::note(self : Entry) -> FormatString? {
  self.note_
}

///|
pub fn Entry::abstract_(self : Entry) -> FormatString? {
  self.abstract__
}

///|
pub fn Entry::genre(self : Entry) -> FormatString? {
  self.genre_
}

///|
/// Get the type of the entry.
pub fn Entry::entry_type(self : Entry) -> EntryType {
  self.entry_type
}

///|
/// Get the parents of the entry.
pub fn Entry::parents(self : Entry) -> Array[Entry] {
  self.parents
}

///|
/// Get and parse the `affiliated` field and only return persons of a given
/// role.
pub fn Entry::affiliated_with_role(
  self : Entry,
  role : PersonRole,
) -> Array[Person] {
  let out = []
  if self.affiliated_ is Some(affs) {
    for p in affs {
      if p.role == role {
        out.append(p.names)
      }
    }
  }
  out
}

///|
/// Get the unconverted value of a certain field from this entry or any of
/// its parents.
pub fn[T] Entry::map(self : Entry, f : (Entry) -> T?) -> T? {
  match f(self) {
    Some(v) => Some(v)
    None => self.map_parents(f)
  }
}

///|
/// Get the unconverted value of a certain field from the parents only by
/// BFS.
pub fn[T] Entry::map_parents(self : Entry, f : (Entry) -> T?) -> T? {
  let path : Array[Int] = [0]
  fn up(path : Array[Int]) -> Unit {
    path.pop() |> ignore
    if path.length() > 0 {
      path[path.length() - 1] += 1
    }
  }

  while true {
    // Index parents with the items in path. If, at any level, the index
    // exceeds the number of parents, increment the index at the previous
    // level. If no other level remains, return.
    guard path.length() > 0 else { return None }
    let first_path = path[0]
    if self.parents.length() <= first_path {
      return None
    }
    let mut item = self.parents[first_path]
    let mut restart = false
    for i in 1..<path.length() {
      if path[i] >= item.parents.length() {
        up(path)
        restart = true
        break
      }
      item = item.parents[path[i]]
    }
    if restart {
      continue
    }
    path[0] += 1
    if f(item) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
/// Apply a selector and return a bound parent entry or self.
pub fn Entry::bound_select(
  self : Entry,
  selector : Selector,
  binding : String,
) -> Entry? {
  match selector.apply(self) {
    Some(map) => map.get(binding)
    None => None
  }
}

///|
/// Will recursively get a date off either the entry or any of its
/// ancestors.
pub fn Entry::date_any(self : Entry) -> Date? {
  self.map(e => e.date_)
}

///|
/// Will recursively get an URL off either the entry or any of its
/// ancestors.
pub fn Entry::url_any(self : Entry) -> QualifiedUrl? {
  self.map(e => e.url_)
}

///|
/// Retrieve a keyed serial number.
pub fn Entry::keyed_serial_number(self : Entry, key : String) -> String? {
  match self.serial_number_ {
    Some(s) => s.0.get(key)
    None => None
  }
}

///|
/// Set a keyed serial number.
pub fn Entry::set_keyed_serial_number(
  self : Entry,
  key : String,
  value : String,
) -> Unit {
  match self.serial_number_ {
    Some(serials) => serials.0.set(key, value)
    None => {
      let map = Map([])
      map.set(key, value)
      self.serial_number_ = Some(SerialNumber(map))
    }
  }
}

///|
/// The Digital Object Identifier of the item.
pub fn Entry::doi(self : Entry) -> String? {
  self.keyed_serial_number("doi")
}

///|
/// International Standard Book Number (ISBN), prefer ISBN-13.
pub fn Entry::isbn(self : Entry) -> String? {
  self.keyed_serial_number("isbn")
}

///|
/// International Standard Serial Number (ISSN).
pub fn Entry::issn(self : Entry) -> String? {
  self.keyed_serial_number("issn")
}

///|
/// PubMed Identifier (PMID).
pub fn Entry::pmid(self : Entry) -> String? {
  self.keyed_serial_number("pmid")
}

///|
/// PubMed Central Identifier (PMCID).
pub fn Entry::pmcid(self : Entry) -> String? {
  self.keyed_serial_number("pmcid")
}

///|
/// ArXiv identifier.
pub fn Entry::arxiv(self : Entry) -> String? {
  self.keyed_serial_number("arxiv")
}

///|
/// Get the container of an entry like CSL defines it.
pub fn Entry::get_container(self : Entry) -> Entry? {
  let retrieve_container = (possible : Array[EntryType]) => {
    for possibility in possible {
      for e in self.parents {
        if e.entry_type == possibility {
          return Some(e)
        }
      }
    }
    None
  }
  match self.entry_type {
    Article =>
      retrieve_container([
        Book,
        // Proceedings must come before Conference.
        // Because @inproceedings will result in a Article entry with a
        // Proceedings and a Conference parent. But only the Proceedings has
        // the correct title.
        Proceedings,
        Conference,
        Periodical,
        Newspaper,
        Blog,
        Reference,
        Web,
      ])
    Anthos => retrieve_container([Book, Anthology, Reference, Report])
    Chapter => retrieve_container([Book, Anthology, Reference, Report])
    Report => retrieve_container([Book, Anthology])
    Web => retrieve_container([Web])
    Scene => retrieve_container([Audio, Video, Performance, Artwork])
    Case => retrieve_container([Book, Anthology, Reference, Report])
    Post => retrieve_container([Thread, Blog, Web])
    Thread => retrieve_container([Thread, Web, Blog])
    _ => None
  }
}

///|
/// Get the non-partial parent of the entry.
pub fn Entry::get_full(self : Entry) -> Entry {
  let mut parent = self.parents.get(0)
  let mut entry = self
  let chapter_or_scene = Selector::Alt([Entry(Chapter), Entry(Scene)])
  while chapter_or_scene.matches(entry) && entry.title_ is None {
    match parent {
      Some(p) => {
        entry = p
        parent = entry.parents.get(0)
      }
      None => break
    }
  }
  entry
}

///|
/// Get the collection of an entry like CSL defines it.
pub fn Entry::get_collection(self : Entry) -> Entry? {
  match self.entry_type {
    Anthology
    | Newspaper
    | Performance
    | Periodical
    | Proceedings
    | Book
    | Reference
    | Exhibition => {
      for e in self.parents {
        if e.entry_type == self.entry_type || e.entry_type == Anthology {
          return Some(e)
        }
      }
      None
    }
    _ => {
      for e in self.parents {
        if e.get_collection() is Some(c) {
          return Some(c)
        }
      }
      None
    }
  }
}

///|
/// Search a parent by DFS.
pub fn Entry::dfs_parent(self : Entry, kind : EntryType) -> Entry? {
  if self.entry_type == kind {
    return Some(self)
  }
  for parent in self.parents {
    if parent.dfs_parent(kind) is Some(entry) {
      return Some(entry)
    }
  }
  None
}

///|
/// Get the original entry.
pub fn Entry::get_original(self : Entry) -> Entry? {
  self.dfs_parent(Original)
}

///|
/// Adds a parent to the current entry.
pub fn Entry::add_parent(self : Entry, entry : Entry) -> Unit {
  self.parents.push(entry)
}

///|
/// Adds affiliated persons. The list will be created if there is none.
pub fn Entry::add_affiliated_persons(
  self : Entry,
  names : Array[Person],
  role : PersonRole,
) -> Unit {
  let obj = PersonsWithRoles::new(names, role)
  match self.affiliated_ {
    Some(affiliated) => affiliated.push(obj)
    None => self.affiliated_ = Some([obj])
  }
}
