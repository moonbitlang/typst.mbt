// Port of `citationberg/src/taxonomy.rs`: CSL constants that describe
// entries, terms, and variables.

///|
/// A CSL variable.
pub(all) enum Variable {
  /// The set of variables with no other attributes.
  Standard(StandardVariable)
  /// The page variable. Can be formatted as a page range.
  Page(PageVariable)
  /// Variables that can be formatted as numbers and are not page ranges.
  Number(NumberVariable)
  /// Variables that can be formatted as dates.
  Date(DateVariable)
  /// Variables that can be formatted as names.
  Name(NameVariable)
} derive(Eq, Hash, Debug)

///|
/// Check if the variable starts with `number-of-` to control contextual
/// label behavior.
pub fn Variable::is_number_of_variable(self : Variable) -> Bool {
  match self {
    Number(v) => v.is_number_of_variable()
    _ => false
  }
}

///|
pub impl Show for Variable with fn output(self, logger) {
  match self {
    Standard(v) => logger.write_string(v.to_string())
    Number(v) => logger.write_string(v.to_string())
    Date(v) => logger.write_string(v.to_string())
    Name(v) => logger.write_string(v.to_string())
    Page(v) => logger.write_string(v.to_string())
  }
}

///|
/// Parse a variable (untagged: standard, page, number, date, name).
pub fn Variable::from_str(s : String) -> Variable? {
  if StandardVariable::from_str(s) is Some(v) {
    return Some(Standard(v))
  }
  if PageVariable::from_str(s) is Some(v) {
    return Some(Page(v))
  }
  if NumberVariable::from_str(s) is Some(v) {
    return Some(Number(v))
  }
  if DateVariable::from_str(s) is Some(v) {
    return Some(Date(v))
  }
  if NameVariable::from_str(s) is Some(v) {
    return Some(Name(v))
  }
  None
}

///|
/// The set of variables with no other attributes.
pub(all) enum StandardVariable {
  Abstract
  Annote
  Archive
  ArchiveCollection
  ArchiveLocation
  ArchivePlace
  Authority
  CallNumber
  CitationKey
  CitationLabel
  CollectionTitle
  ContainerTitle
  ContainerTitleShort
  Dimensions
  Division
  DOI
  Event
  EventTitle
  EventPlace
  Genre
  ISBN
  ISSN
  Jurisdiction
  Keyword
  Language
  License
  Medium
  Note
  OriginalPublisher
  OriginalPublisherPlace
  OriginalTitle
  PartTitle
  PMCID
  PMID
  Publisher
  PublisherPlace
  References
  ReviewedGenre
  ReviewedTitle
  Scale
  Source
  Status
  Title
  TitleShort
  URL
  VolumeTitle
  YearSuffix
} derive(Eq, Hash, Debug)

///|
let standard_variable_names : ReadOnlyArray[(StandardVariable, String)] = [
  (Abstract, "abstract"),
  (Annote, "annote"),
  (Archive, "archive"),
  (ArchiveCollection, "archive_collection"),
  (ArchiveLocation, "archive_location"),
  (ArchivePlace, "archive-place"),
  (Authority, "authority"),
  (CallNumber, "call-number"),
  (CitationKey, "citation-key"),
  (CitationLabel, "citation-label"),
  (CollectionTitle, "collection-title"),
  (ContainerTitle, "container-title"),
  (ContainerTitleShort, "container-title-short"),
  (Dimensions, "dimensions"),
  (Division, "division"),
  (DOI, "DOI"),
  (Event, "event"),
  (EventTitle, "event-title"),
  (EventPlace, "event-place"),
  (Genre, "genre"),
  (ISBN, "ISBN"),
  (ISSN, "ISSN"),
  (Jurisdiction, "jurisdiction"),
  (Keyword, "keyword"),
  (Language, "language"),
  (License, "license"),
  (Medium, "medium"),
  (Note, "note"),
  (OriginalPublisher, "original-publisher"),
  (OriginalPublisherPlace, "original-publisher-place"),
  (OriginalTitle, "original-title"),
  (PartTitle, "part-title"),
  (PMCID, "PMCID"),
  (PMID, "PMID"),
  (Publisher, "publisher"),
  (PublisherPlace, "publisher-place"),
  (References, "references"),
  (ReviewedGenre, "reviewed-genre"),
  (ReviewedTitle, "reviewed-title"),
  (Scale, "scale"),
  (Source, "source"),
  (Status, "status"),
  (Title, "title"),
  (TitleShort, "title-short"),
  (URL, "URL"),
  (VolumeTitle, "volume-title"),
  (YearSuffix, "year-suffix"),
]

///|
/// Serde names (deserialization).
pub fn StandardVariable::from_str(s : String) -> StandardVariable? {
  for p in standard_variable_names[:] {
    if p.1 == s {
      return Some(p.0)
    }
  }
  None
}

///|
pub impl Show for StandardVariable with fn output(self, logger) {
  let s = match self {
    ArchivePlace => "archive_place"
    _ => {
      let mut name = ""
      for p in standard_variable_names[:] {
        if p.0 == self {
          name = p.1
        }
      }
      name
    }
  }
  logger.write_string(s)
}

///|
pub extend StandardVariable with Show::{to_string, output}

///|
/// Number variables as the CSL spec knows them, though we separate between
/// number variables and page ranges.
pub(all) enum NumberOrPageVariable {
  /// The page variable.
  Page(PageVariable)
  /// Variables formattable as numbers.
  Number(NumberVariable)
} derive(Eq, Hash, Debug)

///|
pub fn NumberOrPageVariable::from_str(s : String) -> NumberOrPageVariable? {
  if PageVariable::from_str(s) is Some(v) {
    return Some(Page(v))
  }
  if NumberVariable::from_str(s) is Some(v) {
    return Some(Number(v))
  }
  None
}

///|
pub fn NumberOrPageVariable::to_variable(
  self : NumberOrPageVariable,
) -> Variable {
  match self {
    Page(p) => Page(p)
    Number(n) => Number(n)
  }
}

///|
pub fn NumberOrPageVariable::to_term(self : NumberOrPageVariable) -> Term {
  match self {
    Page(_) => PageVariable
    Number(n) => NumberVariable(n)
  }
}

///|
/// Variable that can be formatted as page numbers
pub(all) enum PageVariable {
  /// Range of pages the item (e.g. a journal article) covers in a container
  /// (e.g. a journal issue).
  Page
} derive(Eq, Hash, Debug)

///|
pub fn PageVariable::from_str(s : String) -> PageVariable? {
  if s == "page" {
    Some(Page)
  } else {
    None
  }
}

///|
pub impl Show for PageVariable with fn output(_, logger) {
  logger.write_string("page")
}

///|
pub extend PageVariable with Show::{to_string, output}

///|
/// Variables that can be formatted as numbers.
pub(all) enum NumberVariable {
  ChapterNumber
  CitationNumber
  CollectionNumber
  Edition
  FirstReferenceNoteNumber
  Issue
  Locator
  Number
  NumberOfPages
  NumberOfVolumes
  PageFirst
  PartNumber
  PrintingNumber
  Section
  SupplementNumber
  Version
  Volume
} derive(Eq, Hash, Debug)

///|
let number_variable_names : ReadOnlyArray[(NumberVariable, String)] = [
  (ChapterNumber, "chapter-number"),
  (CitationNumber, "citation-number"),
  (CollectionNumber, "collection-number"),
  (Edition, "edition"),
  (FirstReferenceNoteNumber, "first-reference-note-number"),
  (Issue, "issue"),
  (Locator, "locator"),
  (Number, "number"),
  (NumberOfPages, "number-of-pages"),
  (NumberOfVolumes, "number-of-volumes"),
  (PageFirst, "page-first"),
  (PartNumber, "part-number"),
  (PrintingNumber, "printing-number"),
  (Section, "section"),
  (SupplementNumber, "supplement-number"),
  (Version, "version"),
  (Volume, "volume"),
]

///|
pub fn NumberVariable::from_str(s : String) -> NumberVariable? {
  if s == "printing" {
    return Some(PrintingNumber)
  }
  for p in number_variable_names[:] {
    if p.1 == s {
      return Some(p.0)
    }
  }
  None
}

///|
pub impl Show for NumberVariable with fn output(self, logger) {
  for p in number_variable_names[:] {
    if p.0 == self {
      logger.write_string(p.1)
      return
    }
  }
}

///|
pub extend NumberVariable with Show::{to_string, output}

///|
/// Check if the variable starts with `number-of-` to control contextual
/// label behavior.
pub fn NumberVariable::is_number_of_variable(self : NumberVariable) -> Bool {
  self is (NumberOfPages | NumberOfVolumes)
}

///|
/// Variables that can be formatted as dates.
pub(all) enum DateVariable {
  Accessed
  AvailableDate
  EventDate
  Issued
  OriginalDate
  Submitted
} derive(Eq, Hash, Debug)

///|
let date_variable_names : ReadOnlyArray[(DateVariable, String)] = [
  (Accessed, "accessed"),
  (AvailableDate, "available-date"),
  (EventDate, "event-date"),
  (Issued, "issued"),
  (OriginalDate, "original-date"),
  (Submitted, "submitted"),
]

///|
pub fn DateVariable::from_str(s : String) -> DateVariable? {
  for p in date_variable_names[:] {
    if p.1 == s {
      return Some(p.0)
    }
  }
  None
}

///|
pub impl Show for DateVariable with fn output(self, logger) {
  for p in date_variable_names[:] {
    if p.0 == self {
      logger.write_string(p.1)
      return
    }
  }
}

///|
pub extend DateVariable with Show::{to_string, output}

///|
/// Variables that can be formatted as names.
pub(all) enum NameVariable {
  Author
  Chair
  CollectionEditor
  Compiler
  Composer
  ContainerAuthor
  Contributor
  Curator
  Director
  Editor
  EditorialDirector
  EditorTranslator
  ExecutiveProducer
  Guest
  Host
  Illustrator
  Interviewer
  Narrator
  Organizer
  OriginalAuthor
  Performer
  Producer
  Recipient
  ReviewedAuthor
  ScriptWriter
  SeriesCreator
  Translator
} derive(Eq, Hash, Debug)

///|
let name_variable_names : ReadOnlyArray[(NameVariable, String)] = [
  (Author, "author"),
  (Chair, "chair"),
  (CollectionEditor, "collection-editor"),
  (Compiler, "compiler"),
  (Composer, "composer"),
  (ContainerAuthor, "container-author"),
  (Contributor, "contributor"),
  (Curator, "curator"),
  (Director, "director"),
  (Editor, "editor"),
  (EditorialDirector, "editorial-director"),
  (EditorTranslator, "editor-translator"),
  (ExecutiveProducer, "executive-producer"),
  (Guest, "guest"),
  (Host, "host"),
  (Illustrator, "illustrator"),
  (Interviewer, "interviewer"),
  (Narrator, "narrator"),
  (Organizer, "organizer"),
  (OriginalAuthor, "original-author"),
  (Performer, "performer"),
  (Producer, "producer"),
  (Recipient, "recipient"),
  (ReviewedAuthor, "reviewed-author"),
  (ScriptWriter, "script-writer"),
  (SeriesCreator, "series-creator"),
  (Translator, "translator"),
]

///|
pub fn NameVariable::from_str(s : String) -> NameVariable? {
  if s == "editortranslator" {
    return Some(EditorTranslator)
  }
  for p in name_variable_names[:] {
    if p.1 == s {
      return Some(p.0)
    }
  }
  None
}

///|
pub impl Show for NameVariable with fn output(self, logger) {
  for p in name_variable_names[:] {
    if p.0 == self {
      logger.write_string(p.1)
      return
    }
  }
}

///|
pub extend NameVariable with Show::{to_string, output}

///|
/// Localizable terms.
pub(all) enum Term {
  /// Kind of the cited item.
  Kind(Kind)
  /// Variables that can be formatted as names.
  NameVariable(NameVariable)
  /// Variables that can be formatted as numbers.
  NumberVariable(NumberVariable)
  /// The Page variable.
  PageVariable
  /// A locator.
  Locator(Locator)
  /// Terms that are not defined via types, name or number variables.
  Other(OtherTerm)
} derive(Eq, Hash, Debug)

///|
/// Parse a term (untagged: kind, name variable, number variable, locator,
/// other term). The unit variant `PageVariable` never matches a string.
pub fn Term::from_str(s : String) -> Term? {
  if Kind::from_str(s) is Some(k) {
    return Some(Kind(k))
  }
  if NameVariable::from_str(s) is Some(v) {
    return Some(NameVariable(v))
  }
  if NumberVariable::from_str(s) is Some(v) {
    return Some(NumberVariable(v))
  }
  if Locator::from_str(s) is Some(l) {
    return Some(Locator(l))
  }
  if OtherTerm::from_str(s) is Ok(o) {
    return Some(Other(o))
  }
  None
}

///|
/// On which term this falls back if the given term is not available.
pub fn Term::term_fallback(self : Term) -> Term {
  match self {
    Other(LongOrdinal(i)) => Other(OrdinalN(i))
    _ => self
  }
}

///|
/// Whether this is an ordinal term.
pub fn Term::is_ordinal(self : Term) -> Bool {
  match self {
    Other(other) => other.is_ordinal()
    _ => false
  }
}

///|
/// Whether this is a numbered ordinal term.
pub fn Term::is_n_ordinal(self : Term) -> Bool {
  match self {
    Other(other) => other.is_n_ordinal()
    _ => false
  }
}

///|
/// Whether this is a gendered term.
pub fn Term::is_gendered(self : Term) -> Bool {
  if self.is_ordinal() {
    return true
  }
  self
  is Other(
    Month01
    | Month02
    | Month03
    | Month04
    | Month05
    | Month06
    | Month07
    | Month08
    | Month09
    | Month10
    | Month11
    | Month12
  )
}

///|
/// Compare a term to another one. Return `true` if they are serialized the
/// same.
pub fn Term::is_lexically_same(self : Term, other : Term) -> Bool {
  if self == other {
    return true
  }
  fn cmp(a : Term, b : Term) -> Bool {
    match (a, b) {
      (Locator(Issue), NumberVariable(Issue))
      | (Locator(Page), PageVariable)
      | (Locator(Section), NumberVariable(Section))
      | (Locator(Volume), NumberVariable(Volume))
      | (Locator(Book), Kind(Book))
      | (Locator(Chapter), Kind(Chapter))
      | (Locator(Figure), Kind(Figure)) => true
      _ => false
    }
  }

  cmp(self, other) || cmp(other, self)
}

///|
/// Kind of the cited item.
pub(all) enum Kind {
  Article
  ArticleJournal
  ArticleMagazine
  ArticleNewspaper
  Bill
  Book
  Broadcast
  Chapter
  Classic
  Collection
  Dataset
  Document
  Entry
  EntryDictionary
  EntryEncyclopedia
  Event
  Figure
  Graphic
  Hearing
  Interview
  LegalCase
  Legislation
  Manuscript
  Map
  MotionPicture
  MusicalScore
  Pamphlet
  PaperConference
  Patent
  Performance
  Periodical
  PersonalCommunication
  Post
  PostWeblog
  Regulation
  Report
  Review
  ReviewBook
  Software
  Song
  Speech
  Standard
  Thesis
  Treaty
  Webpage
} derive(Eq, Hash, Debug)

///|
let kind_names : ReadOnlyArray[(Kind, String)] = [
  (Article, "article"),
  (ArticleJournal, "article-journal"),
  (ArticleMagazine, "article-magazine"),
  (ArticleNewspaper, "article-newspaper"),
  (Bill, "bill"),
  (Book, "book"),
  (Broadcast, "broadcast"),
  (Chapter, "chapter"),
  (Classic, "classic"),
  (Collection, "collection"),
  (Dataset, "dataset"),
  (Document, "document"),
  (Entry, "entry"),
  (EntryDictionary, "entry-dictionary"),
  (EntryEncyclopedia, "entry-encyclopedia"),
  (Event, "event"),
  (Figure, "figure"),
  (Graphic, "graphic"),
  (Hearing, "hearing"),
  (Interview, "interview"),
  (LegalCase, "legal_case"),
  (Legislation, "legislation"),
  (Manuscript, "manuscript"),
  (Map, "map"),
  (MotionPicture, "motion_picture"),
  (MusicalScore, "musical_score"),
  (Pamphlet, "pamphlet"),
  (PaperConference, "paper-conference"),
  (Patent, "patent"),
  (Performance, "performance"),
  (Periodical, "periodical"),
  (PersonalCommunication, "personal_communication"),
  (Post, "post"),
  (PostWeblog, "post-weblog"),
  (Regulation, "regulation"),
  (Report, "report"),
  (Review, "review"),
  (ReviewBook, "review-book"),
  (Software, "software"),
  (Song, "song"),
  (Speech, "speech"),
  (Standard, "standard"),
  (Thesis, "thesis"),
  (Treaty, "treaty"),
  (Webpage, "webpage"),
]

///|
pub fn Kind::from_str(s : String) -> Kind? {
  for p in kind_names[:] {
    if p.1 == s {
      return Some(p.0)
    }
  }
  None
}

///|
pub impl Show for Kind with fn output(self, logger) {
  for p in kind_names[:] {
    if p.0 == self {
      logger.write_string(p.1)
      return
    }
  }
}

///|
/// A locator.
pub(all) enum Locator {
  Act
  Appendix
  ArticleLocator
  Book
  Canon
  Chapter
  Column
  Elocation
  Equation
  Figure
  Folio
  Issue
  Line
  Note
  Opus
  Page
  Paragraph
  Part
  Rule
  Scene
  Section
  SubVerbo
  Supplement
  Table
  Timestamp
  Title
  TitleLocator
  Verse
  Volume
  /// The custom type is a `citationberg` addition. It will render nothing in
  /// the locator's `cs:label` element.
  Custom
} derive(Eq, Hash, Debug)

///|
pub fn Locator::from_str(s : String) -> Locator? {
  match s {
    "act" => Some(Act)
    "appendix" => Some(Appendix)
    "article-locator" => Some(ArticleLocator)
    "book" => Some(Book)
    "canon" => Some(Canon)
    "chapter" => Some(Chapter)
    "column" => Some(Column)
    "elocation" => Some(Elocation)
    "equation" => Some(Equation)
    "figure" => Some(Figure)
    "folio" => Some(Folio)
    "issue" => Some(Issue)
    "line" => Some(Line)
    "note" => Some(Note)
    "opus" => Some(Opus)
    "page" => Some(Page)
    "paragraph" => Some(Paragraph)
    "part" => Some(Part)
    "rule" => Some(Rule)
    "scene" => Some(Scene)
    "section" => Some(Section)
    "sub verbo" | "sub-verbo" => Some(SubVerbo)
    "supplement" => Some(Supplement)
    "table" => Some(Table)
    "timestamp" => Some(Timestamp)
    "title" => Some(Title)
    "title-locator" => Some(TitleLocator)
    "verse" => Some(Verse)
    "volume" => Some(Volume)
    _ => None
  }
}

///|
/// Terms that are not defined via types, name or number variables.
pub(all) enum OtherTerm {
  // Months
  Month01
  Month02
  Month03
  Month04
  Month05
  Month06
  Month07
  Month08
  Month09
  Month10
  Month11
  Month12
  // Ordinals
  Ordinal
  /// Between 0 and 99.
  OrdinalN(Int)
  /// Between 0 and 10.
  LongOrdinal(Int)
  // Punctuation
  OpenQuote
  CloseQuote
  OpenInnerQuote
  CloseInnerQuote
  PageRangeDelimiter
  Colon
  Comma
  Semicolon
  // Seasons
  Season01
  Season02
  Season03
  Season04
  // Disciplines
  Anthropology
  Astronomy
  Biology
  Botany
  Chemistry
  Engineering
  GenericBase
  Geography
  Geology
  History
  Humanities
  Literature
  Math
  Medicine
  Philosophy
  Physics
  Psychology
  Sociology
  Science
  PoliticalScience
  SocialScience
  Theology
  Zoology
  // Miscellaneous
  Accessed
  Ad
  AdvanceOnlinePublication
  Album
  And
  AndOthers
  Anonymous
  At
  AudioRecording
  AvailableAt
  Bc
  Bce
  By
  Ce
  Circa
  Cited
  EtAl
  Film
  Forthcoming
  From
  Henceforth
  Ibid
  In
  InPress
  Internet
  Interview
  Letter
  LocCit
  NoDate
  NoPlace
  NoPublisher
  On
  Online
  OpCit
  OriginalWorkPublished
  PersonalCommunication
  Podcast
  PodcastEpisode
  Preprint
  PresentedAt
  RadioBroadcast
  RadioSeries
  RadioSeriesEpisode
  Reference
  Retrieved
  ReviewOf
  Scale
  SpecialIssue
  SpecialSection
  TelevisionBroadcast
  TelevisionSeries
  TelevisionSeriesEpisode
  Video
  WorkingPaper
} derive(Eq, Hash, Debug)

///|
/// Whether this is a numbered ordinal term.
pub fn OtherTerm::is_n_ordinal(self : OtherTerm) -> Bool {
  self is (OrdinalN(_) | LongOrdinal(_))
}

///|
/// Whether this is an ordinal term.
pub fn OtherTerm::is_ordinal(self : OtherTerm) -> Bool {
  self is (Ordinal | OrdinalN(_) | LongOrdinal(_))
}

///|
/// Get the month for a number between 0 and 11.
pub fn OtherTerm::month(i : Int) -> OtherTerm? {
  match i {
    0 => Some(Month01)
    1 => Some(Month02)
    2 => Some(Month03)
    3 => Some(Month04)
    4 => Some(Month05)
    5 => Some(Month06)
    6 => Some(Month07)
    7 => Some(Month08)
    8 => Some(Month09)
    9 => Some(Month10)
    10 => Some(Month11)
    11 => Some(Month12)
    _ => None
  }
}

///|
/// Get the term to describe a particular season.
pub fn OtherTerm::season(value : Season) -> OtherTerm {
  match value {
    Spring => Season01
    Summer => Season02
    Autumn => Season03
    Winter => Season04
  }
}

///|
/// An error that can occur when converting a string to a term.
pub(all) enum TermConversionError {
  /// The month, season, ordinal, or long ordinal is out of range.
  OutOfRange
  /// The term is unknown.
  Unknown
} derive(Eq, Hash, Debug)

///|
pub impl Show for TermConversionError with fn output(self, logger) {
  match self {
    OutOfRange => logger.write_string("value out of range")
    Unknown => logger.write_string("unknown term")
  }
}

///|
/// Rust's `str::parse::<u8>` with its error kinds.
fn parse_u8_term(s : String) -> Result[Int, TermConversionError] {
  match @unscanny.parse_i64(s) {
    Some(v) =>
      if v >= 0L && v <= 255L {
        Ok(v.to_int())
      } else {
        Err(OutOfRange)
      }
    None => {
      // Overflowing digit strings are out of range, everything else is
      // unknown.
      let digits = if s.has_prefix("+") || s.has_prefix("-") {
        s[1:].to_owned()
      } else {
        s
      }
      if !digits.is_empty() && digits.iter().all(c => c.is_ascii_digit()) {
        Err(OutOfRange)
      } else {
        Err(Unknown)
      }
    }
  }
}

///|
pub fn OtherTerm::from_str(
  value : String,
) -> Result[OtherTerm, TermConversionError] {
  if value.strip_prefix("month-") is Some(month) {
    let n = match parse_u8_term(month.to_owned()) {
      Ok(n) => n
      Err(e) => return Err(e)
    }
    return match n {
      1 => Ok(Month01)
      2 => Ok(Month02)
      3 => Ok(Month03)
      4 => Ok(Month04)
      5 => Ok(Month05)
      6 => Ok(Month06)
      7 => Ok(Month07)
      8 => Ok(Month08)
      9 => Ok(Month09)
      10 => Ok(Month10)
      11 => Ok(Month11)
      12 => Ok(Month12)
      _ => Err(OutOfRange)
    }
  }
  if value.strip_prefix("season-") is Some(season) {
    let n = match parse_u8_term(season.to_owned()) {
      Ok(n) => n
      Err(e) => return Err(e)
    }
    return match Season::try_from_csl_number(n) {
      Some(season) => Ok(OtherTerm::season(season))
      None => Err(OutOfRange)
    }
  }
  if value.strip_prefix("ordinal-") is Some(ordinal) {
    let n = match parse_u8_term(ordinal.to_owned()) {
      Ok(n) => n
      Err(e) => return Err(e)
    }
    if n > 99 {
      return Err(OutOfRange)
    }
    return Ok(OrdinalN(n))
  }
  if value.strip_prefix("long-ordinal-") is Some(long_ordinal) {
    let n = match parse_u8_term(long_ordinal.to_owned()) {
      Ok(n) => n
      Err(e) => return Err(e)
    }
    if n > 10 {
      return Err(OutOfRange)
    }
    return Ok(LongOrdinal(n))
  }
  match value {
    "ordinal" => Ok(Ordinal)
    "open-quote" => Ok(OpenQuote)
    "close-quote" => Ok(CloseQuote)
    "open-inner-quote" => Ok(OpenInnerQuote)
    "close-inner-quote" => Ok(CloseInnerQuote)
    "page-range-delimiter" => Ok(PageRangeDelimiter)
    "colon" => Ok(Colon)
    "comma" => Ok(Comma)
    "semicolon" => Ok(Semicolon)
    "anthropology" => Ok(Anthropology)
    "astronomy" => Ok(Astronomy)
    "biology" => Ok(Biology)
    "botany" => Ok(Botany)
    "chemistry" => Ok(Chemistry)
    "engineering" => Ok(Engineering)
    "generic-base" => Ok(GenericBase)
    "geography" => Ok(Geography)
    "geology" => Ok(Geology)
    "history" => Ok(History)
    "humanities" => Ok(Humanities)
    "literature" => Ok(Literature)
    "math" => Ok(Math)
    "medicine" => Ok(Medicine)
    "philosophy" => Ok(Philosophy)
    "physics" => Ok(Physics)
    "psychology" => Ok(Psychology)
    "sociology" => Ok(Sociology)
    "science" => Ok(Science)
    "political-science" | "political_science" => Ok(PoliticalScience)
    "social-science" | "social_science" => Ok(SocialScience)
    "theology" => Ok(Theology)
    "zoology" => Ok(Zoology)
    "accessed" => Ok(Accessed)
    "ad" => Ok(Ad)
    "advance-online-publication" => Ok(AdvanceOnlinePublication)
    "album" => Ok(Album)
    "and" => Ok(And)
    "and-others" | "and others" => Ok(AndOthers)
    "anonymous" => Ok(Anonymous)
    "at" => Ok(At)
    "audio-recording" => Ok(AudioRecording)
    "available at" | "available-at" => Ok(AvailableAt)
    "bc" => Ok(Bc)
    "bce" => Ok(Bce)
    "by" => Ok(By)
    "ce" => Ok(Ce)
    "circa" => Ok(Circa)
    "cited" => Ok(Cited)
    "et-al" => Ok(EtAl)
    "film" => Ok(Film)
    "forthcoming" => Ok(Forthcoming)
    "from" => Ok(From)
    "henceforth" => Ok(Henceforth)
    "ibid" => Ok(Ibid)
    "in" => Ok(In)
    "in press" | "in-press" => Ok(InPress)
    "internet" => Ok(Internet)
    "interview" => Ok(Interview)
    "letter" => Ok(Letter)
    "loc-cit" => Ok(LocCit)
    "no date" | "no-date" => Ok(NoDate)
    "no-place" => Ok(NoPlace)
    "no-publisher" => Ok(NoPublisher)
    "on" => Ok(On)
    "online" => Ok(Online)
    "op-cit" => Ok(OpCit)
    "original-work-published" => Ok(OriginalWorkPublished)
    "personal-communication" => Ok(PersonalCommunication)
    "podcast" => Ok(Podcast)
    "podcast-episode" => Ok(PodcastEpisode)
    "preprint" => Ok(Preprint)
    "presented at" | "presented-at" => Ok(PresentedAt)
    "radio-broadcast" => Ok(RadioBroadcast)
    "radio-series" => Ok(RadioSeries)
    "radio-series-episode" => Ok(RadioSeriesEpisode)
    "reference" => Ok(Reference)
    "retrieved" => Ok(Retrieved)
    "review-of" => Ok(ReviewOf)
    "scale" => Ok(Scale)
    "special-issue" => Ok(SpecialIssue)
    "special-section" => Ok(SpecialSection)
    "television-broadcast" => Ok(TelevisionBroadcast)
    "television-series" => Ok(TelevisionSeries)
    "television-series-episode" => Ok(TelevisionSeriesEpisode)
    "video" => Ok(Video)
    "working-paper" => Ok(WorkingPaper)
    _ => Err(Unknown)
  }
}

///|
fn pad2(i : Int) -> String {
  if i < 10 {
    "0\{i}"
  } else {
    i.to_string()
  }
}

///|
pub impl Show for OtherTerm with fn output(self, logger) {
  let s = match self {
    Ordinal => "ordinal"
    OpenQuote => "open-quote"
    CloseQuote => "close-quote"
    OpenInnerQuote => "open-inner-quote"
    CloseInnerQuote => "close-inner-quote"
    PageRangeDelimiter => "page-range-delimiter"
    Colon => "colon"
    Comma => "comma"
    Semicolon => "semicolon"
    Anthropology => "anthropology"
    Astronomy => "astronomy"
    Biology => "biology"
    Botany => "botany"
    Chemistry => "chemistry"
    Engineering => "engineering"
    GenericBase => "generic-base"
    Geography => "geography"
    Geology => "geology"
    History => "history"
    Humanities => "humanities"
    Literature => "literature"
    Math => "math"
    Medicine => "medicine"
    Philosophy => "philosophy"
    Physics => "physics"
    Psychology => "psychology"
    Sociology => "sociology"
    Science => "science"
    PoliticalScience => "political_science"
    SocialScience => "social_science"
    Theology => "theology"
    Zoology => "zoology"
    Accessed => "accessed"
    Ad => "ad"
    AdvanceOnlinePublication => "advance-online-publication"
    Album => "album"
    And => "and"
    AndOthers => "and-others"
    Anonymous => "anonymous"
    At => "at"
    AudioRecording => "audio-recording"
    AvailableAt => "available at"
    Bc => "bc"
    Bce => "bce"
    By => "by"
    Ce => "ce"
    Circa => "circa"
    Cited => "cited"
    EtAl => "et-al"
    Film => "film"
    Forthcoming => "forthcoming"
    From => "from"
    Henceforth => "henceforth"
    Ibid => "ibid"
    In => "in"
    InPress => "in press"
    Internet => "internet"
    Interview => "interview"
    Letter => "letter"
    LocCit => "loc-cit"
    NoDate => "no date"
    NoPlace => "no-place"
    NoPublisher => "no-publisher"
    On => "on"
    Online => "online"
    OpCit => "op-cit"
    OriginalWorkPublished => "original-work-published"
    PersonalCommunication => "personal-communication"
    Podcast => "podcast"
    PodcastEpisode => "podcast-episode"
    Preprint => "preprint"
    PresentedAt => "presented at"
    RadioBroadcast => "radio-broadcast"
    RadioSeries => "radio-series"
    RadioSeriesEpisode => "radio-series-episode"
    Reference => "reference"
    Retrieved => "retrieved"
    ReviewOf => "review-of"
    Scale => "scale"
    SpecialIssue => "special-issue"
    SpecialSection => "special-section"
    TelevisionBroadcast => "television-broadcast"
    TelevisionSeries => "television-series"
    TelevisionSeriesEpisode => "television-series-episode"
    Video => "video"
    WorkingPaper => "working-paper"
    OrdinalN(i) => "ordinal-\{pad2(i)}"
    LongOrdinal(i) => "long-ordinal-\{pad2(i)}"
    Season01 => "season-01"
    Season02 => "season-02"
    Season03 => "season-03"
    Season04 => "season-04"
    Month01 => "month-01"
    Month02 => "month-02"
    Month03 => "month-03"
    Month04 => "month-04"
    Month05 => "month-05"
    Month06 => "month-06"
    Month07 => "month-07"
    Month08 => "month-08"
    Month09 => "month-09"
    Month10 => "month-10"
    Month11 => "month-11"
    Month12 => "month-12"
  }
  logger.write_string(s)
}

///|
/// Seasons of the year.
pub(all) enum Season {
  /// Spring (CSL season 01).
  Spring
  /// Summer (CSL season 02).
  Summer
  /// Autumn (CSL season 03).
  Autumn
  /// Winter (CSL season 04).
  Winter
} derive(Eq, Hash, Debug)

///|
/// Converts a season number in the range 1-4 (as defined by the CSL spec)
/// to a Season instance.
pub fn Season::try_from_csl_number(i : Int) -> Season? {
  match i {
    1 => Some(Spring)
    2 => Some(Summer)
    3 => Some(Autumn)
    4 => Some(Winter)
    _ => None
  }
}

///|
/// Converts a season to its number as defined by the CSL spec.
pub fn Season::to_csl_number(self : Season) -> Int {
  match self {
    Spring => 1
    Summer => 2
    Autumn => 3
    Winter => 4
  }
}
