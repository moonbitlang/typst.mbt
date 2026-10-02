// Port of `hayagriva/src/csl/taxonomy.rs`: resolving CSL variables on
// entries (`EntryLike for Entry`).

///|
fn sel_ty(t : EntryType) -> Selector {
  Selector::Entry(t)
}

///|
fn sel_bind(name : String, s : Selector) -> Selector {
  Binding(name, s)
}

///|
fn sel_anc(a : Selector, b : Selector) -> Selector {
  Ancestrage(a, b)
}

///|
fn sel_alt(xs : Array[Selector]) -> Selector {
  Alt(xs)
}

///|
fn sel_tys(ts : Array[EntryType]) -> Selector {
  Alt(ts.map(t => Selector::Entry(t)))
}

///|
/// `select!(* > ("p":(Exhibition | Conference | Misc)))`
fn event_selector() -> Selector {
  sel_anc(Wildcard, sel_bind("p", sel_tys([Exhibition, Conference, Misc])))
}

///|
fn[T] opt_or(a : T?, b : () -> T?) -> T? {
  match a {
    Some(_) => a
    None => b()
  }
}

///|
fn parse_maybe_numeric(s : String) -> MaybeTyped[Numeric] {
  match Numeric::from_str(s) {
    Ok(n) => Typed(n)
    Err(_) => String(s)
  }
}

///|
/// `EntryLike::resolve_number_variable`.
pub fn Entry::resolve_number_variable(
  self : Entry,
  variable : @citationberg.NumberVariable,
) -> MaybeTyped[Numeric]? {
  match variable {
    ChapterNumber =>
      opt_or(self.chapter(), () => {
        let sel = sel_alt([
          sel_anc(
            sel_bind("e", sel_ty(Anthos)),
            sel_bind("p", sel_ty(Anthology)),
          ),
          sel_anc(sel_bind("e", Wildcard), sel_bind("p", sel_ty(Reference))),
          sel_anc(
            sel_bind("e", sel_ty(Article)),
            sel_bind("p", sel_ty(Proceedings)),
          ),
          sel_anc(sel_bind("e", Wildcard), sel_bind("p", sel_ty(Book))),
        ])
        match self.bound_select(sel, "e") {
          Some(e) => e.volume()
          None => None
        }
      })
    CitationNumber => abort("processor must resolve this")
    CollectionNumber =>
      match self.get_collection() {
        Some(e) => e.volume()
        None => None
      }
    Edition => self.map(e => e.edition())
    FirstReferenceNoteNumber => abort("processor must resolve this")
    Issue => self.map(e => e.issue())
    Locator => abort("processor must resolve this")
    Number =>
      match self.serial_number() {
        Some(s) if s.get("serial") is Some(v) => Some(parse_maybe_numeric(v))
        _ =>
          // User can specify either 'serial-number: 3' or 'chapter: 3' for
          // chapter entries, with the same result.
          match self.bound_select(sel_bind("e", sel_ty(Chapter)), "e") {
            Some(s) => s.chapter()
            None => None
          }
      }
    NumberOfPages => self.page_total().map(n => MaybeTyped::Typed(n))
    NumberOfVolumes => self.volume_total().map(n => MaybeTyped::Typed(n))
    PageFirst =>
      match self.page_range() {
        Some(Typed(r)) => r.first().map(n => MaybeTyped::Typed(n))
        _ => None
      }
    PartNumber => {
      let sel = sel_anc(
        sel_bind("e", Wildcard),
        sel_tys([Article, Blog, Book, Legislation]),
      )
      match self.bound_select(sel, "e") {
        Some(e) => e.volume()
        None => None
      }
    }
    PrintingNumber =>
      match self.map(e => e.serial_number()) {
        Some(s) if s.get("printing") is Some(v) => Some(parse_maybe_numeric(v))
        _ => None
      }
    Section => None
    SupplementNumber => None
    Version =>
      match self.bound_select(sel_bind("e", sel_ty(Repository)), "e") {
        Some(e) =>
          match e.serial_number() {
            Some(s) if s.get("version") is Some(v) =>
              Some(parse_maybe_numeric(v))
            _ => None
          }
        None => None
      }
    Volume =>
      opt_or(
        match self.get_container() {
          Some(e) => e.volume()
          None => None
        },
        () => self.volume(),
      )
  }
}

///|
/// `EntryLike::resolve_page_variable`.
pub fn Entry::resolve_page_variable(
  self : Entry,
  _variable : @citationberg.PageVariable,
) -> MaybeTyped[PageRanges]? {
  self.page_range()
}

///|
fn select_form(
  f : FormatString?,
  form : @citationberg.LongShortForm,
) -> ChunkedString? {
  f.map(f => f.select(form))
}

///|
/// `EntryLike::resolve_standard_variable`.
pub fn Entry::resolve_standard_variable(
  self : Entry,
  form : @citationberg.LongShortForm,
  variable : @citationberg.StandardVariable,
) -> ChunkedString? {
  let entry = self
  match variable {
    Abstract => select_form(entry.map(e => e.abstract_()), form)
    Annote => select_form(entry.map(e => e.note()), form)
    Archive => select_form(entry.map(e => e.archive()), form)
    ArchiveCollection => None
    ArchiveLocation => select_form(entry.archive_location(), form)
    ArchivePlace => None
    Authority => select_form(entry.organization(), form)
    CallNumber => select_form(entry.call_number(), form)
    CitationKey =>
      Some(ChunkedString::from_chunk(StringChunk::verbatim(entry.key)))
    CitationLabel =>
      Some(ChunkedString::from_string(Alphanumerical::new().citation(entry)))
    // Get third-order title first, then second-order title.
    CollectionTitle =>
      match entry.get_collection() {
        Some(e) => select_form(e.title(), form)
        None => None
      }
    ContainerTitle =>
      match entry.get_container() {
        Some(e) => select_form(e.title(), form)
        None => None
      }
    ContainerTitleShort =>
      match entry.get_container() {
        Some(e) => select_form(e.title(), Short)
        None => None
      }
    Dimensions =>
      entry
      .runtime()
      .map(r => ChunkedString::from_chunk(StringChunk::normal(r.to_str())))
    Division => None
    DOI =>
      entry.doi().map(d => ChunkedString::from_chunk(StringChunk::verbatim(d)))
    Event | EventTitle =>
      match entry.bound_select(event_selector(), "p") {
        Some(p) => select_form(p.title(), form)
        None => None
      }
    EventPlace =>
      match entry.bound_select(event_selector(), "p") {
        Some(p) => select_form(p.location(), form)
        None => None
      }
    Genre => select_form(entry.map(e => e.genre()), form)
    ISBN =>
      entry.isbn().map(d => ChunkedString::from_chunk(StringChunk::verbatim(d)))
    ISSN =>
      entry.issn().map(d => ChunkedString::from_chunk(StringChunk::verbatim(d)))
    Jurisdiction => None
    Keyword => None
    Language =>
      entry
      .map(e => e.language())
      .map(l => ChunkedString::from_chunk(StringChunk::normal(csl_language(l))))
    License => None
    Medium => None
    Note => select_form(entry.note(), form)
    OriginalPublisher =>
      match entry.get_original() {
        Some(e) =>
          match e.publisher() {
            Some(p) => select_form(p.name, form)
            None => None
          }
        None => None
      }
    OriginalPublisherPlace =>
      match entry.get_original() {
        Some(e) =>
          match e.publisher() {
            Some(p) => select_form(p.location, form)
            None => None
          }
        None => None
      }
    OriginalTitle =>
      match entry.get_original() {
        Some(e) => select_form(e.title(), form)
        None => None
      }
    PartTitle => None
    PMCID =>
      entry
      .pmcid()
      .map(d => ChunkedString::from_chunk(StringChunk::verbatim(d)))
    PMID =>
      entry.pmid().map(d => ChunkedString::from_chunk(StringChunk::verbatim(d)))
    Publisher =>
      match entry.map(e => e.publisher()) {
        Some(p) => select_form(p.name, form)
        None => None
      }
    PublisherPlace =>
      match entry.map(e => e.publisher()) {
        Some(p) => select_form(p.location, form)
        None => None
      }
    References => None
    ReviewedGenre => None
    ReviewedTitle => None
    Scale => None
    Source =>
      match
        entry.bound_select(
          sel_anc(Wildcard, sel_bind("p", sel_ty(Repository))),
          "p",
        ) {
        Some(p) => select_form(p.title(), form)
        None => None
      }
    Status => None
    Title => select_form(entry.title(), form)
    TitleShort => select_form(entry.title(), Short)
    URL =>
      entry
      .map(e => e.url())
      .map(d => ChunkedString::from_chunk(StringChunk::verbatim(d.to_string())))
    VolumeTitle => {
      let selector = sel_alt([
        sel_anc(sel_ty(Anthos), sel_bind("p", sel_ty(Anthology))),
        sel_anc(sel_ty(Entry), sel_bind("p", Wildcard)),
        sel_anc(Wildcard, sel_bind("p", sel_ty(Reference))),
        sel_anc(sel_ty(Article), sel_bind("p", sel_ty(Proceedings))),
      ])
      match self.bound_select(selector, "p") {
        Some(p) => select_form(p.title(), form)
        None => None
      }
    }
    YearSuffix => abort("processor must resolve this")
  }
}

///|
/// `EntryLike::resolve_date_variable`.
pub fn Entry::resolve_date_variable(
  self : Entry,
  variable : @citationberg.DateVariable,
) -> Date? {
  match variable {
    Accessed =>
      match self.url_any() {
        Some(u) => u.visit_date
        None => None
      }
    AvailableDate => None
    EventDate =>
      match self.bound_select(event_selector(), "p") {
        Some(p) => p.date()
        None => None
      }
    Issued => self.date_any()
    OriginalDate =>
      match self.get_original() {
        Some(e) => e.date()
        None => None
      }
    Submitted => None
  }
}

///|
/// `EntryLike::resolve_name_variable`.
pub fn Entry::resolve_name_variable(
  self : Entry,
  variable : @citationberg.NameVariable,
) -> Array[Person] {
  let audio_video = sel_alt([
    sel_anc(Wildcard, sel_bind("p", sel_tys([Audio, Video]))),
    sel_bind("p", sel_tys([Audio, Video])),
  ])
  let res : Array[Person]? = match variable {
    Author => self.authors()
    Chair =>
      self
      .bound_select(
        sel_anc(Wildcard, sel_bind("p", sel_tys([Proceedings, Conference]))),
        "p",
      )
      .map(e => e.affiliated_with_role(Director))
    CollectionEditor =>
      match self.get_collection() {
        Some(e) => e.editors()
        None => None
      }
    Compiler => self.map(e => Some(e.affiliated_with_role(Compiler)))
    Composer => self.map(e => Some(e.affiliated_with_role(Composer)))
    ContainerAuthor =>
      match self.get_container() {
        Some(e) => e.authors()
        None => None
      }
    Contributor => self.map(e => Some(e.affiliated_with_role(Collaborator)))
    Curator =>
      self
      .bound_select(sel_anc(Wildcard, sel_bind("p", sel_ty(Exhibition))), "p")
      .map(e => e.affiliated_with_role(Organizer))
    Director =>
      self
      .bound_select(audio_video, "p")
      .map(e => e.affiliated_with_role(Director))
    Editor =>
      opt_or(self.editors(), () => {
        match self.get_container() {
          Some(e) => e.editors()
          None => None
        }
      })
    EditorialDirector => None
    EditorTranslator => {
      let translator = self.affiliated_with_role(Translator)
      Some(self.editors().unwrap_or([]).filter(e => translator.contains(e)))
    }
    ExecutiveProducer =>
      self.map(e => Some(e.affiliated_with_role(ExecutiveProducer)))
    Guest => None
    Host => None
    Illustrator => self.map(e => Some(e.affiliated_with_role(Illustrator)))
    Interviewer => None
    Narrator => self.map(e => Some(e.affiliated_with_role(Narrator)))
    Organizer => self.map(e => Some(e.affiliated_with_role(Organizer)))
    OriginalAuthor =>
      match self.get_original() {
        Some(e) => e.authors()
        None => None
      }
    Performer => self.map(e => Some(e.affiliated_with_role(CastMember)))
    Producer => self.map(e => Some(e.affiliated_with_role(Producer)))
    Recipient => None
    ReviewedAuthor => None
    ScriptWriter => self.map(e => Some(e.affiliated_with_role(Writer)))
    SeriesCreator =>
      self
      .bound_select(audio_video, "p")
      .map(e => e.affiliated_with_role(Founder))
    Translator => self.map(e => Some(e.affiliated_with_role(Translator)))
  }
  res.unwrap_or([])
}

///|
/// `EntryLike::matches_entry_type`.
pub fn Entry::matches_entry_type(
  self : Entry,
  kind : @citationberg.Kind,
) -> Bool {
  // Each match arm contains mutually exclusive entry kinds.
  match kind {
    Article
    | ArticleMagazine
    | ArticleNewspaper
    | ArticleJournal
    | PaperConference
    | Report
    | Thesis
    | Manuscript => {
      if kind == ArticleMagazine {
        // TODO: Hayagriva does not differentiate between scientific and
        // non-scientific magazines.
        return false
      }
      let is_journal = sel_anc(sel_ty(Article), sel_ty(Periodical)).matches(
        self,
      )
      if kind == ArticleJournal {
        return is_journal
      }
      let is_news = sel_anc(sel_ty(Article), sel_ty(Newspaper)).matches(self)
      if kind == ArticleNewspaper {
        return is_news
      }
      let is_conference = sel_anc(sel_ty(Article), sel_ty(Proceedings)).matches(
        self,
      )
      if kind == PaperConference {
        return is_conference
      }
      let is_report = sel_alt([
        sel_anc(Wildcard, sel_ty(Report)),
        sel_ty(Report),
      ]).matches(self)
      if kind == Report {
        return is_report
      }
      let is_thesis = sel_alt([
        sel_anc(Wildcard, sel_ty(Thesis)),
        sel_ty(Thesis),
      ]).matches(self)
      if kind == Thesis {
        return is_thesis
      }
      let is_manuscript = self.entry_type == Manuscript
      if kind == Manuscript {
        return is_manuscript
      }
      self.entry_type == Article &&
      !sel_anc(Wildcard, sel_ty(Blog)).matches(self) &&
      !(is_journal ||
      is_news ||
      is_conference ||
      is_report ||
      is_thesis ||
      is_manuscript)
    }
    Book | Classic | Periodical | Collection => {
      if !sel_tys([Book, Anthology, Proceedings]).matches(self) {
        return false
      }
      if kind == Classic {
        // TODO: Hayagriva does not support indicating something is a
        // classic.
        return false
      }
      let is_periodical = sel_alt([
        sel_anc(sel_ty(Book), sel_ty(Periodical)),
        sel_ty(Periodical),
      ]).matches(self)
      if kind == Periodical {
        return is_periodical
      }
      let is_collection = self.entry_type == Anthology
      if kind == Collection {
        return is_collection
      }
      !(is_periodical || is_collection)
    }
    Chapter =>
      sel_alt([
        sel_anc(sel_ty(Anthos), sel_ty(Anthology)),
        sel_anc(sel_ty(Chapter), sel_tys([Book, Anthology, Proceedings])),
      ]).matches(self)
    Entry | EntryDictionary | EntryEncyclopedia => {
      if kind == EntryDictionary {
        // TODO: We do not differentiate between dictionaries and other
        // references.
        return false
      }
      let is_encyclopedia = sel_anc(Wildcard, sel_ty(Reference)).matches(self)
      if kind == EntryEncyclopedia {
        return is_encyclopedia
      }
      self.entry_type == Entry && !is_encyclopedia
    }
    Event => self.entry_type == Exhibition
    Hearing | Interview | Performance | Speech => false
    Broadcast | MotionPicture | MusicalScore | Song => {
      let is_music_score = sel_anc(
        sel_ty(Audio),
        sel_tys([Book, Periodical, Reference, Misc, Blog, Web]),
      ).matches(self)
      if kind == MusicalScore {
        return is_music_score
      }
      let is_motion_picture = self.entry_type == Video &&
        self.parents.is_empty()
      if kind == MotionPicture {
        return is_motion_picture
      }
      let is_song = self.entry_type == Audio && self.parents.is_empty()
      if kind == Song {
        return is_song
      }
      self.entry_type is (Audio | Video) &&
      !(is_music_score || is_motion_picture || is_song)
    }
    Legislation | Bill => {
      if self.entry_type != Legislation {
        return false
      }
      let is_published = self.publisher() is Some(_)
      if kind == Bill {
        return !is_published
      }
      is_published
    }
    LegalCase => self.entry_type == Case
    Regulation | Standard | Treaty => false
    Patent => self.entry_type == Patent
    Webpage | PostWeblog | Post => {
      let is_blogpost = sel_anc(Wildcard, sel_ty(Blog)).matches(self)
      if kind == PostWeblog {
        return is_blogpost
      }
      let is_post = sel_alt([sel_ty(Post), sel_anc(Wildcard, sel_ty(Thread))]).matches(
        self,
      )
      if kind == Post {
        return is_post
      }
      sel_alt([
        Attr(sel_ty(Misc), ["url"]),
        sel_anc(Wildcard, sel_tys([Web, Blog])),
        sel_ty(Web),
        sel_ty(Blog),
        sel_ty(Thread),
      ]).matches(self) &&
      !(is_blogpost || is_post)
    }
    Dataset => false
    Figure | Graphic | Map => {
      let is_figure = sel_anc(sel_ty(Artwork), sel_ty(Article)).matches(self)
      if kind == Figure {
        return is_figure
      }
      if kind == Map {
        return false
      }
      self.entry_type == Artwork && !is_figure
    }
    Pamphlet => false
    PersonalCommunication => false
    Review | ReviewBook => false
    Software => self.entry_type == Repository
    Document => self.entry_type == Misc
  }
}

///|
/// `EntryLike::is_english`.
pub fn Entry::is_english(self : Entry) -> Bool? {
  self.language().map(l => l.language == "en")
}

///|
/// `csl_language`.
fn csl_language(lang_id : LanguageIdentifier) -> String {
  match lang_id.region {
    Some(region) => lang_id.language + "-" + region
    None => lang_id.language
  }
}

///|
/// The year suffix letter for a disambiguation index.
fn letter(val : Int) -> String {
  let mut result = ""
  let mut current = val
  while true {
    let remainder = current % 26
    let c = Int::unsafe_to_char(remainder + 'a'.to_int())
    result = c.to_string() + result
    if current < 26 {
      break
    }
    current = (current - 26) / 26
  }
  result
}
