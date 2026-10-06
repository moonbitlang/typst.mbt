// Port of `hayagriva/src/types/mod.rs`: base types for the bibliography
// items and their content.

///|
/// Describes which kind of work a database entry refers to.
pub(all) enum EntryType {
  /// A short text, possibly of journalistic or scientific nature, appearing
  /// in some greater publication.
  Article
  /// A section of a greater containing work.
  Chapter
  /// A short segment of media on some subject matter. Could appear in a
  /// work of reference or a data set
  Entry
  /// Text published within an Anthology.
  Anthos
  /// A document compiled by authors that may be affiliated to an
  /// organization. Presents information for a specific audience or purpose.
  Report
  /// Scholarly work delivered to fulfill degree requirements at a higher
  /// education institution.
  Thesis
  /// Piece of content that can be found on the internet and is native to
  /// the medium.
  Web
  /// A part of a show or another type of performed media, typically all
  /// taking place in the same location.
  Scene
  /// A form of artistic/creative expression.
  Artwork
  /// A technical document deposited at a government agency that describes
  /// an invention to legally limit the rights of reproduction to the
  /// inventors.
  Patent
  /// Reference to a legal case that was or is to be heard at a court of
  /// law.
  Case
  /// The issue of a newspaper that was published on a given day.
  Newspaper
  /// Legal document or draft there of that is, is to be, or was to be
  /// enacted into binding law.
  Legislation
  /// A document that is not yet published.
  Manuscript
  /// A post on a social media platform.
  Post
  /// Items that do not match any of the other Entry type composites.
  Misc
  /// A live performance.
  Performance
  /// A publication that periodically publishes issues with unique content.
  Periodical
  /// The official published record of the events at a professional
  /// conference.
  Proceedings
  /// Long-form work published physically as a set of bound sheets.
  Book
  /// Set of self-published articles on a website.
  Blog
  /// A work of reference. This could be a manual or a dictionary.
  Reference
  /// Professional conference.
  Conference
  /// Collection of different texts on a single topic/theme.
  Anthology
  /// Publicly visible storage of the source code for a particular software
  /// and its modifications over time.
  Repository
  /// Written discussion on the internet triggered by an original post.
  Thread
  /// Motion picture of any form, possibly with accompanying audio.
  Video
  /// Recorded audible sound of any kind.
  Audio
  /// A curated set of artworks.
  Exhibition
  /// A prior publication of the same item.
  Original
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EntryType with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EntryType with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EntryType with @debug.Debug::{to_repr}

///|
let entry_type_names : ReadOnlyArray[(EntryType, String, String)] = [
  (Article, "article", "Article"),
  (Chapter, "chapter", "Chapter"),
  (Entry, "entry", "Entry"),
  (Anthos, "anthos", "Anthos"),
  (Report, "report", "Report"),
  (Thesis, "thesis", "Thesis"),
  (Web, "web", "Web"),
  (Scene, "scene", "Scene"),
  (Artwork, "artwork", "Artwork"),
  (Patent, "patent", "Patent"),
  (Case, "case", "Case"),
  (Newspaper, "newspaper", "Newspaper"),
  (Legislation, "legislation", "Legislation"),
  (Manuscript, "manuscript", "Manuscript"),
  (Post, "post", "Post"),
  (Misc, "misc", "Misc"),
  (Performance, "performance", "Performance"),
  (Periodical, "periodical", "Periodical"),
  (Proceedings, "proceedings", "Proceedings"),
  (Book, "book", "Book"),
  (Blog, "blog", "Blog"),
  (Reference, "reference", "Reference"),
  (Conference, "conference", "Conference"),
  (Anthology, "anthology", "Anthology"),
  (Repository, "repository", "Repository"),
  (Thread, "thread", "Thread"),
  (Video, "video", "Video"),
  (Audio, "audio", "Audio"),
  (Exhibition, "exhibition", "Exhibition"),
  (Original, "original", "Original"),
]

///|
/// The serde variant names (for error messages).
fn entry_type_expected() -> String {
  entry_type_names.map(t => "`\{t.2}`, `\{t.1}`").join(", ")
}

///|
/// `impl FromStr for EntryType` (serde names and aliases).
pub fn EntryType::from_str(s : String) -> Result[EntryType, String] {
  for t in entry_type_names[:] {
    if t.1 == s || t.2 == s {
      return Ok(t.0)
    }
  }
  Err("unknown variant `\{s}`, expected one of \{entry_type_expected()}")
}

///|
pub impl Show for EntryType with fn output(self, logger) {
  for t in entry_type_names[:] {
    if t.0 == self {
      logger.write_string(t.1)
      return
    }
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EntryType with Show::{to_string, output}

///|
/// Entry parents have implicit defaults. This function returns the default
/// parent for this entry type.
pub fn EntryType::default_parent(self : EntryType) -> EntryType {
  match self {
    Article => Periodical
    Chapter => Book
    Entry => Reference
    Anthos => Anthology
    Web => Web
    Scene => Video
    Artwork => Exhibition
    Legislation => Anthology
    Post => Post
    Video => Video
    Audio => Audio
    _ => Misc
  }
}

///|
/// A type that may be a string or a strictly typed value.
pub(all) enum MaybeTyped[T] {
  /// The typed variant.
  Typed(T)
  /// The fallback string variant.
  String(String)
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MaybeTyped with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MaybeTyped with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MaybeTyped with @debug.Debug::{to_repr}

///|
/// Get the typed value, if it is present.
pub fn[T] MaybeTyped::as_typed(self : MaybeTyped[T]) -> T? {
  match self {
    Typed(t) => Some(t)
    String(_) => None
  }
}

///|
pub impl[T : Show] Show for MaybeTyped[T] with fn output(self, logger) {
  match self {
    Typed(t) => t.output(logger)
    String(s) => logger.write_string(s)
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MaybeTyped with Show::{to_string, output}

///|
/// Convert the value to a string.
pub fn[T : Show] MaybeTyped::to_str(self : MaybeTyped[T]) -> String {
  match self {
    Typed(t) => t.to_string()
    String(s) => s
  }
}

///|
/// `MaybeTyped::infallible_from_str` for numerics.
pub fn MaybeTyped::numeric_from_str(s : String) -> MaybeTyped[Numeric] {
  match Numeric::from_str(s) {
    Ok(t) => Typed(t)
    Err(_) => String(s)
  }
}

///|
/// `MaybeTyped::infallible_from_str` for page ranges.
pub fn MaybeTyped::page_ranges_from_str(s : String) -> MaybeTyped[PageRanges] {
  match PageRanges::from_str(s) {
    Ok(t) => Typed(t)
    Err(_) => String(s)
  }
}

///|
/// `MaybeTyped::infallible_from_str` for durations.
pub fn MaybeTyped::duration_from_str(s : String) -> MaybeTyped[Duration] {
  match Duration::from_str(s) {
    Ok(t) => Typed(t)
    Err(_) => String(s)
  }
}

///|
/// `MaybeTyped::infallible_from_str` for duration ranges.
pub fn MaybeTyped::duration_range_from_str(
  s : String,
) -> MaybeTyped[DurationRange] {
  match DurationRange::from_str(s) {
    Ok(t) => Typed(t)
    Err(_) => String(s)
  }
}

///|
/// `MaybeTyped<Cow<Numeric>>::csl_cmp`: order the values according to CSL
/// rules.
pub fn MaybeTyped::numeric_csl_cmp(
  self : MaybeTyped[Numeric],
  other : MaybeTyped[Numeric],
) -> Int {
  match (self, other) {
    (Typed(a), Typed(b)) => a.csl_cmp(b)
    _ => @unscanny.compare_str(self.to_str(), other.to_str())
  }
}

///|
/// `MaybeTyped<PageRanges>::csl_cmp`: order the values according to CSL
/// rules.
pub fn MaybeTyped::page_ranges_csl_cmp(
  self : MaybeTyped[PageRanges],
  other : MaybeTyped[PageRanges],
) -> Int {
  match (self, other) {
    (Typed(a), Typed(b)) => a.csl_cmp(b)
    _ => @unscanny.compare_str(self.to_str(), other.to_str())
  }
}

///|
/// An URL, possibly with a last visited date.
pub(all) struct QualifiedUrl {
  /// The [Url].
  value : Url
  /// The last visited date.
  visit_date : Date?
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend QualifiedUrl with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend QualifiedUrl with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend QualifiedUrl with @debug.Debug::{to_repr}

///|
/// Create a new qualified URL.
pub fn QualifiedUrl::new(value : Url, visit_date : Date?) -> QualifiedUrl {
  { value, visit_date, }
}

///|
/// `impl FromStr for QualifiedUrl`.
pub fn QualifiedUrl::from_str(
  s : String,
) -> Result[QualifiedUrl, UrlParseError] {
  match Url::parse(s) {
    Ok(value) => Ok({ value, visit_date: None, })
    Err(e) => Err(e)
  }
}

///|
pub impl Show for QualifiedUrl with fn output(self, logger) {
  logger.write_string(self.value.serialization)
}

///|
pub extend QualifiedUrl with Show::{to_string, output}

///|
/// A publisher, possibly with a location.
pub(all) struct Publisher {
  /// Publisher of the item.
  name : FormatString?
  /// Physical location at which the item was published or created.
  location : FormatString?
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Publisher with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Publisher with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Publisher with @debug.Debug::{to_repr}

///|
/// Create a new publisher.
pub fn Publisher::new(
  name : FormatString?,
  location : FormatString?,
) -> Publisher {
  { name, location, }
}

///|
/// Creates a new publisher with `s` as its name and no location.
pub fn Publisher::from_str(
  s : String,
) -> Result[Publisher, ChunkedStrParseError] {
  match FormatString::from_str(s) {
    Ok(f) => Ok({ name: Some(f), location: None, })
    Err(e) => Err(e)
  }
}

///|
/// A set of serial numbers like DOIs, ISBNs, or ISSNs. Keys should be
/// lowercase.
pub(all) struct SerialNumber(Map[String, String]) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SerialNumber with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SerialNumber with @debug.Debug::{to_repr}

///|
pub impl Hash for SerialNumber with fn hash_combine(self, hasher) {
  for k in self.sorted_keys() {
    hasher.combine_string(k)
    hasher.combine_string(self.0.get(k).unwrap())
  }
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SerialNumber with Hash::{hash, hash_combine}

///|
/// The keys in `BTreeMap` order.
pub fn SerialNumber::sorted_keys(self : SerialNumber) -> Array[String] {
  let keys = self.0.keys().collect()
  keys.sort_by((a, b) => @unscanny.compare_str(a, b))
  keys
}

///|
/// Get a serial number by key.
pub fn SerialNumber::get(self : SerialNumber, key : String) -> String? {
  self.0.get(key)
}
