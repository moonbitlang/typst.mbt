// Port of `hayagriva/src/interop.rs`: conversion from BibLaTeX.

///|
/// `impl From<&tex::Person> for Person`.
fn person_from_tex(person : @biblatex.Person) -> Person {
  fn optional(part : String) -> String? {
    if !part.is_empty() {
      Some(part)
    } else {
      None
    }
  }

  {
    name: person.name,
    given_name: optional(person.given_name),
    prefix: optional(person.prefix),
    suffix: optional(person.suffix),
    comma_suffix: false,
    alias_: None,
  }
}

///|
/// `impl From<tex::Date> for Date`.
fn date_from_tex(date : @biblatex.Date) -> Date {
  let approximate = date.uncertain || date.approximate
  match date.value {
    At(x) | After(x) | Before(x) =>
      { year: x.year, month: x.month, day: x.day, approximate, season: None }
    Between(_, x) =>
      { year: x.year, month: x.month, day: x.day, approximate, season: None }
  }
}

///|
/// `impl From<&[Spanned<Chunk>]> for ChunkedString`.
fn chunked_from_tex(chunks : ArrayView[@biblatex.Spanned[@biblatex.Chunk]]) -> ChunkedString {
  let res = ChunkedString::new()
  for chunk in chunks {
    match chunk.v {
      Normal(s) => res.push_str(s, Normal)
      Verbatim(s) => res.push_str(s, Verbatim)
      Math(s) => res.push_str(s, Math)
    }
  }
  res
}

///|
/// `impl From<&[Spanned<Chunk>]> for FormatString`.
fn format_from_tex(chunks : ArrayView[@biblatex.Spanned[@biblatex.Chunk]]) -> FormatString {
  { value: chunked_from_tex(chunks), short: None }
}

///|
/// `impl From<&[Spanned<Chunk>]> for MaybeTyped<Numeric>`.
fn numeric_from_tex(
  chunks : ArrayView[@biblatex.Spanned[@biblatex.Chunk]],
) -> MaybeTyped[Numeric] {
  MaybeTyped::numeric_from_str(@biblatex.format_verbatim(chunks))
}

///|
/// `impl From<&PermissiveType<i64>> for MaybeTyped<Numeric>`.
fn numeric_from_permissive(
  v : @biblatex.PermissiveType[Int64],
) -> MaybeTyped[Numeric] {
  match v {
    Typed(i) => Typed(Numeric::new(i.to_int()))
    Chunks(c) => MaybeTyped::numeric_from_str(@biblatex.format_verbatim(c))
  }
}

///|
fn ed_role(role : @biblatex.EditorType, entry_type : @biblatex.EntryType) -> PersonRole? {
  match role {
    Editor => None
    Compiler => Some(Compiler)
    Founder => Some(Founder)
    Continuator => None
    Redactor => None
    Reviser => None
    Collaborator => Some(Collaborator)
    Organizer => Some(Organizer)
    Director => Some(Director)
    Unknown(role) => {
      let other_entry_type = match entry_type {
        Unknown(t) => Some(@unscanny.to_ascii_lowercase(t))
        _ => None
      }
      match (@unscanny.to_ascii_lowercase(role), other_entry_type) {
        // See p. 26 of the biblatex-chicago manual and biblatex-apa
        ("producer", _) => Some(Producer)
        // The pervasive Zotero plugin zotero-better-biblatex produces this.
        ("scriptwriter", _) => Some(Writer)
        // The biblatex-apa style expects `writer` for videos.
        ("writer", Some("video")) => Some(Writer)
        // See p. 26 of the biblatex-chicago manual
        ("none", Some("video") | Some("music")) => Some(CastMember)
        _ => Some(Unknown(role))
      }
    }
  }
}

///|
fn book(item : Entry, parent : Bool) -> Entry? {
  if parent {
    item.parents.get(0)
  } else {
    None
  }
}

///|
fn mv(item : Entry, parent : Bool, mv_parent : Bool) -> Entry? {
  if parent && mv_parent {
    item.parents[0].parents.get(0)
  } else if mv_parent {
    item.parents.get(0)
  } else {
    None
  }
}

///|
priv suberror TexErr {
  TexErr(@biblatex.TypeError)
}

///|
fn[T] map_res(result : Result[T, @biblatex.RetrievalError]) -> T? raise TexErr {
  match result {
    Ok(x) => Some(x)
    Err(Missing(_)) => None
    Err(TypeError(t)) => raise TexErr(t)
  }
}

///|
/// `impl TryFrom<&tex::Entry> for Entry`.
pub fn entry_from_biblatex(
  entry : @biblatex.Entry,
) -> Result[Entry, @biblatex.TypeError] {
  try entry_from_biblatex_impl(entry) catch {
    TexErr(e) => Err(e)
  } noraise {
    e => Ok(e)
  }
}

///|
fn entry_from_biblatex_impl(entry : @biblatex.Entry) -> Entry raise TexErr {
  let mv_attributes = !(entry.main_title() is Err(Missing(_))) &&
    !(entry.volume() is Err(Missing(_)))
  let (new_kind, top_level, expand_mv) : (EntryType, EntryType?, Bool) = match
    entry.entry_type {
    Article => (Article, Some(Periodical), false)
    Book => (Book, None, true)
    Booklet => (Misc, None, false)
    InBook => (Chapter, Some(Book), true)
    InCollection => (Anthos, Some(Anthology), true)
    InProceedings => (Article, Some(Proceedings), true)
    Manual => (Reference, None, false)
    MastersThesis => (Thesis, None, false)
    PhdThesis => (Thesis, None, false)
    Thesis => (Thesis, None, false)
    Misc => (Misc, None, false)
    Proceedings => (Proceedings, None, true)
    Report => (Report, None, true)
    TechReport => (Report, None, true)
    Unpublished => (Manuscript, None, true)
    MvBook => (Book, None, false)
    BookInBook => (Book, Some(Book), true)
    SuppBook => (Misc, Some(Book), true)
    Periodical => (Periodical, None, true)
    SuppPeriodical => (Misc, Some(Periodical), true)
    Collection => (Anthology, None, true)
    SuppCollection => (Misc, Some(Anthology), true)
    Reference => (Reference, None, true)
    MvReference => (Reference, None, false)
    InReference => (Entry, Some(Reference), true)
    MvProceedings => (Proceedings, None, false)
    MvCollection => (Anthology, None, false)
    Patent => (Patent, None, false)
    Online => (Web, None, false)
    Software => (Misc, None, false)
    Dataset => (Repository, None, false)
    Set => (Misc, None, false)
    XData => (Misc, None, false)
    Unknown(_) => (Misc, None, false)
  }
  let item = Entry::new(entry.key, new_kind)
  match top_level {
    Some(kind) => {
      let tl_parent = Entry::new(entry.key, kind)
      if expand_mv && mv_attributes {
        let parent = Entry::new(entry.key, kind)
        tl_parent.add_parent(parent)
      }
      item.add_parent(tl_parent)
    }
    None =>
      if expand_mv && mv_attributes {
        let parent = Entry::new(entry.key, new_kind)
        item.add_parent(parent)
      }
  }
  let parent = top_level is Some(_)
  let mv_parent = expand_mv && mv_attributes
  if entry.author() is Ok(a) {
    item.authors_ = Some(a.map(person_from_tex))
  }
  let eds : Array[Person] = []
  let collaborators = []
  let editors = match entry.editors() {
    Ok(e) => e
    Err(e) => raise TexErr(e)
  }
  for pair in editors {
    let (editors, role) = pair
    match ed_role(role, entry.entry_type) {
      None => eds.append(editors.map(person_from_tex))
      Some(role) =>
        collaborators.push(
          PersonsWithRoles::new(editors.map(person_from_tex), role),
        )
    }
  }
  if !eds.is_empty() {
    item.editors_ = Some(eds)
  }
  if !collaborators.is_empty() {
    item.affiliated_ = Some(collaborators)
  }
  if map_res(entry.holder()) is Some(a) {
    item.add_affiliated_persons(a.map(person_from_tex), Holder)
  }
  if book(item, parent) is Some(parent) &&
    map_res(entry.book_author()) is Some(a) {
    parent.authors_ = Some(a.map(person_from_tex))
  }
  if map_res(entry.annotator()) is Some(a) {
    item.add_affiliated_persons(a.map(person_from_tex), Annotator)
  }
  if map_res(entry.commentator()) is Some(a) {
    item.add_affiliated_persons(a.map(person_from_tex), Commentator)
  }
  if map_res(entry.translator()) is Some(a) {
    item.add_affiliated_persons(a.map(person_from_tex), Translator)
  }

  // Take the first language or the langid.
  let lang_res = entry.language()
  let langid_res = match entry.langid() {
    Ok(l) => Some(l)
    Err(_) => None
  }
  // If we cannot parse the language, ignore it
  let l = match map_res(lang_res) {
    Some(langs) if langs.length() > 0 => Some(langs[0])
    _ => langid_res
  }
  if l is Some(Typed(lang)) {
    item.language_ = LanguageIdentifier::parse(lang.to_langid())
  }
  if map_res(entry.afterword()) is Some(a) {
    item.add_affiliated_persons(a.map(person_from_tex), Afterword)
  }
  if map_res(entry.foreword()) is Some(a) {
    item.add_affiliated_persons(a.map(person_from_tex), Foreword)
  }
  if map_res(entry.introduction()) is Some(a) {
    item.add_affiliated_persons(a.map(person_from_tex), Introduction)
  }
  if map_res(entry.title()) is Some(title) {
    let title = chunked_from_tex(title)
    match map_res(entry.short_title()) {
      Some(short_title) =>
        item.title_ = Some({ value: title, short: Some(chunked_from_tex(short_title)) })
      None => item.title_ = Some({ value: title, short: None })
    }
  }

  // NOTE: Ignoring subtitle and titleaddon for now
  if mv(item, parent, mv_parent) is Some(p) &&
    map_res(entry.main_title()) is Some(title) {
    p.title_ = Some(format_from_tex(title))
  }
  if book(item, parent) is Some(p) {
    if entry.entry_type == Article {
      if map_res(entry.journal_title()) is Some(title) {
        p.title_ = Some(format_from_tex(title))
      }
    } else if map_res(entry.book_title()) is Some(title) {
      p.title_ = Some(format_from_tex(title))
    }
  }
  if entry.entry_type is (Proceedings | MvProceedings | InProceedings) &&
    (map_res(entry.event_date()) is Some(_) ||
    map_res(entry.eventtitle()) is Some(_) ||
    map_res(entry.venue()) is Some(_)) {
    let conference = Entry::new(entry.key, Conference)
    if map_res(entry.event_date()) is Some(Typed(d)) {
      conference.date_ = Some(date_from_tex(d))
    }
    if map_res(entry.eventtitle()) is Some(title) {
      conference.title_ = Some(format_from_tex(title))
    }
    if map_res(entry.venue()) is Some(venue) {
      conference.location_ = Some(format_from_tex(venue))
    }
    item.add_parent(conference)
  }
  if map_res(entry.date()) is Some(Typed(d)) {
    item.date_ = Some(date_from_tex(d))
  }
  if map_res(entry.edition()) is Some(d) {
    let edition = numeric_from_permissive(d)
    match book(item, parent) {
      Some(p) => p.edition_ = Some(edition)
      None => item.edition_ = Some(edition)
    }
  }
  if entry.entry_type is (Article | Proceedings) {
    if map_res(entry.issue()) is Some(d) {
      let issue = numeric_from_tex(d)
      match book(item, parent) {
        Some(p) => p.issue_ = Some(issue)
        None => item.issue_ = Some(issue)
      }
    }
    if map_res(entry.issue_title()) is Some(t) {
      let ititle = format_from_tex(t)
      match book(item, parent) {
        Some(p) => p.title_ = Some(ititle)
        None => item.title_ = Some(ititle)
      }
    }
  }

  // "number" is generally used in Biblatex for "The number of a journal or
  // the volume/number of a book in a series". However, it is also used for
  // patent entries as "the number or record token of a patent or patent
  // request", and is also listed as an optional field for report, manual,
  // and dataset, where it fits the use for patent. Hayagriva uses "issue"
  // for the journal/book sense of biblatex's number, and "serial-number" for
  // the record number / token sense.
  if map_res(entry.number()) is Some(d) {
    let number = numeric_from_tex(d)
    match book(item, parent) {
      Some(p) => p.issue_ = Some(number)
      None =>
        match item.entry_type {
          Report | Patent | Entry | Reference =>
            item.set_keyed_serial_number("serial", number.to_str())
          _ => item.issue_ = Some(number)
        }
    }
  }
  if map_res(entry.volume()) is Some(volume) {
    let val = numeric_from_permissive(volume)
    match book(item, parent) {
      Some(p) => p.volume_ = Some(val)
      None => item.volume_ = Some(val)
    }
  }
  if mv(item, parent, mv_parent) is Some(p) &&
    map_res(entry.volumes()) is Some(volumes) {
    p.volume_total_ = Some(Numeric::new(volumes.to_int()))
  }
  if map_res(entry.version()) is Some(version) {
    item.set_keyed_serial_number("version", @biblatex.format_verbatim(version))
  }
  if map_res(entry.doi()) is Some(doi) {
    item.set_keyed_serial_number("doi", doi)
  }
  if map_res(entry.isbn()) is Some(isbn) {
    item.set_keyed_serial_number("isbn", @biblatex.format_verbatim(isbn))
  }
  if map_res(entry.issn()) is Some(issn) {
    item.set_keyed_serial_number("issn", @biblatex.format_verbatim(issn))
  }
  if map_res(entry.eprint()) is Some(eprint) {
    let eprint_type = map_res(
      match entry.eprint_type() {
        Ok(c) => Ok(@unscanny.to_lowercase(@biblatex.format_verbatim(c)))
        Err(e) => Err(e)
      },
    )
    if eprint_type == Some("arxiv") {
      item.set_keyed_serial_number("arxiv", eprint)
    } else if eprint_type == Some("pubmed") {
      item.set_keyed_serial_number("pmid", eprint)
    }
  }
  if map_res(entry.isan()) is Some(isan) {
    item.set_keyed_serial_number("isan", @biblatex.format_verbatim(isan))
  }
  if map_res(entry.ismn()) is Some(ismn) {
    item.set_keyed_serial_number("ismn", @biblatex.format_verbatim(ismn))
  }
  if map_res(entry.iswc()) is Some(iswc) {
    item.set_keyed_serial_number("iswc", @biblatex.format_verbatim(iswc))
  }
  if map_res(entry.url()) is Some(s) && Url::parse(s) is Ok(url) {
    let date = match map_res(entry.url_date()) {
      Some(Typed(d)) => Some(date_from_tex(d))
      _ => None
    }
    item.url_ = Some({ value: url, visit_date: date })
  }
  match map_res(entry.publisher()) {
    Some(pubs) => {
      let publisher_name = comma_list(pubs)
      let location = map_res(entry.location()).map(d => format_from_tex(d))
      let publisher = Publisher::new(Some(publisher_name), location)
      match book(item, parent) {
        Some(p) => p.publisher_ = Some(publisher)
        None => item.publisher_ = Some(publisher)
      }
    }
    None =>
      if map_res(entry.location()) is Some(d) {
        let publisher = Publisher::new(None, Some(format_from_tex(d)))
        match book(item, parent) {
          Some(p) => p.publisher_ = Some(publisher)
          None => item.publisher_ = Some(publisher)
        }
      }
  }
  match map_res(entry.organization()) {
    Some(orgs) => {
      let organization = comma_list(orgs)
      match book(item, parent) {
        Some(p) => p.organization_ = Some(organization)
        None => item.organization_ = Some(organization)
      }
    }
    None =>
      if map_res(entry.institution()) is Some(d) {
        let organization = format_from_tex(d)
        match book(item, parent) {
          Some(p) => p.organization_ = Some(organization)
          None => item.organization_ = Some(organization)
        }
      }
  }
  if map_res(entry.how_published()) is Some(d) {
    let note = format_from_tex(d)
    match book(item, parent) {
      Some(p) => p.note_ = Some(note)
      None => item.note_ = Some(note)
    }
  }
  if map_res(entry.pages()) is Some(pages) {
    item.page_range_ = Some(
      match pages {
        Typed(pages) =>
          Typed(
            PageRanges::new(
              pages.map(p => {
                if p.0 == p.1 {
                  PageRangesPart::SinglePage(Numeric::new(p.0.to_int()))
                } else {
                  Range(Numeric::new(p.0.to_int()), Numeric::new(p.1.to_int()))
                }
              }),
            ),
          )
        Chunks(chunks) =>
          MaybeTyped::page_ranges_from_str(@biblatex.format_verbatim(chunks))
      },
    )
  }
  if map_res(entry.page_total()) is Some(c) &&
    numeric_parse(@biblatex.format_verbatim(c)) is Some(ptotal) {
    match book(item, parent) {
      Some(p) => p.page_total_ = Some(ptotal)
      None => item.page_total_ = Some(ptotal)
    }
  }
  if map_res(entry.note()) is Some(d) {
    item.note_ = Some(format_from_tex(d))
  }
  let annotation = match map_res(entry.annotation()) {
    Some(a) => Some(a)
    None =>
      match entry.addendum() {
        Ok(a) => Some(a)
        Err(_) => None
      }
  }
  if annotation is Some(d) && item.note_ is None {
    item.note_ = Some(format_from_tex(d))
  }
  if map_res(entry.abstract_()) is Some(d) {
    item.abstract__ = Some(format_from_tex(d))
  }

  // BibLaTeX describes "type" as "The type of a manual, patent, report, or
  // thesis. This field may also be useful for the custom types listed in §
  // 2.1.3." Hayagriva uses "genre" for 'Type, class, or subtype of the item
  // (e.g. "Doctoral dissertation" for a PhD thesis; "NIH Publication" for an
  // NIH technical report)'
  match map_res(entry.type_()) {
    Some(type_) => item.genre_ = Some(FormatString::with_value(type_))
    None =>
      match entry.entry_type {
        // These are the default genres according to the BibLaTeX manual
        // §2.1.2, which is in agreement with "BibTeXing" §2.2.
        MastersThesis =>
          item.genre_ = Some(FormatString::with_value("Master's thesis"))
        PhdThesis =>
          item.genre_ = Some(FormatString::with_value("Doctoral dissertation"))
        TechReport =>
          // capitalized as in the BibLaTeX manual
          item.genre_ = Some(FormatString::with_value("technical report"))
        _ => ()
      }
  }
  if map_res(entry.series()) is Some(series) {
    let title = format_from_tex(series)
    let new = Entry::new(entry.key, item.entry_type)
    new.title_ = Some(title)
    match mv(item, parent, mv_parent) {
      Some(p) => {
        new.entry_type = p.entry_type
        p.add_parent(new)
      }
      None =>
        match book(item, parent) {
          Some(p) => {
            new.entry_type = p.entry_type
            p.add_parent(new)
          }
          None => item.add_parent(new)
        }
    }
  }
  if map_res(entry.chapter()) is Some(chapter) {
    // Per BibLaTeX manual, v3.20:
    // "chapter (field): a chapter or section or any other unit of a work"
    // This means it corresponds to the CSL "chapter-number" field - that is,
    // describes the number of the chapter where the referenced information
    // can be found - rather than, necessarily, the chapter entry type
    // (referring to an entire chapter), which is better corresponded to by
    // the `@InBook` BibLaTeX entry type: "A part of a book which forms a
    // self-contained unit with its own title."
    item.chapter_ = Some(numeric_from_tex(chapter))
  }
  item
}

///|
/// `str::parse::<Numeric>().ok()`.
fn numeric_parse(s : String) -> Numeric? {
  match Numeric::from_str(s) {
    Ok(n) => Some(n)
    Err(_) => None
  }
}

///|
fn comma_list(items : Array[@biblatex.Chunks]) -> FormatString {
  let value = ChunkedString::new()
  for i, entity in items {
    if i != 0 {
      value.push_str(", ", Normal)
    }
    value.extend_chunks(chunked_from_tex(entity))
  }
  { value, short: None }
}
