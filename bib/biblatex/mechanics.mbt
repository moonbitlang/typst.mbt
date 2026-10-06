// Port of `biblatex/src/mechanics.rs`: entry types and which fields should
// be attached to each of them.

///|
/// Describes the type of a bibliographical entry.
pub(all) enum EntryType {
  // BibTeX
  Article
  Book
  Booklet
  InBook
  InCollection
  InProceedings
  Manual
  MastersThesis
  PhdThesis
  Misc
  Proceedings
  TechReport
  Unpublished
  // BibLaTeX
  MvBook
  BookInBook
  SuppBook
  Periodical
  SuppPeriodical
  Collection
  MvCollection
  SuppCollection
  Reference
  MvReference
  InReference
  MvProceedings
  Report
  Patent
  Thesis
  Online
  Software
  Dataset
  Set
  XData
  Unknown(String)
} derive(Eq, Debug)

///|
/// The strum `lowercase` serializations of the entry types.
let entry_type_names : ReadOnlyArray[(String, EntryType)] = [
  ("article", Article),
  ("book", Book),
  ("booklet", Booklet),
  ("inbook", InBook),
  ("incollection", InCollection),
  ("inproceedings", InProceedings),
  ("manual", Manual),
  ("mastersthesis", MastersThesis),
  ("phdthesis", PhdThesis),
  ("misc", Misc),
  ("proceedings", Proceedings),
  ("techreport", TechReport),
  ("unpublished", Unpublished),
  ("mvbook", MvBook),
  ("bookinbook", BookInBook),
  ("suppbook", SuppBook),
  ("periodical", Periodical),
  ("suppperiodical", SuppPeriodical),
  ("collection", Collection),
  ("mvcollection", MvCollection),
  ("suppcollection", SuppCollection),
  ("reference", Reference),
  ("mvreference", MvReference),
  ("inreference", InReference),
  ("mvproceedings", MvProceedings),
  ("report", Report),
  ("patent", Patent),
  ("thesis", Thesis),
  ("online", Online),
  ("software", Software),
  ("dataset", Dataset),
  ("set", Set),
  ("xdata", XData),
  ("unknown", Unknown("")),
]

///|
/// Strum's `Display` (lowercase variant name).
pub impl Show for EntryType with fn output(self, logger) {
  for pair in entry_type_names[:] {
    if pair.1 == self {
      logger.write_string(pair.0)
      return
    }
  }
  logger.write_string("unknown")
}

///|
priv enum AuthorMode {
  NoneRequired
  OneRequired
  BothRequired
  AuthorRequired
  AuthorRequiredEditorOptional
  EditorRequiredAuthorForbidden
}

///|
fn AuthorMode::possible(self : AuthorMode) -> Array[String] {
  match self {
    OneRequired | BothRequired | AuthorRequiredEditorOptional =>
      ["author", "editor"]
    AuthorRequired => ["author"]
    EditorRequiredAuthorForbidden => ["editor"]
    _ => []
  }
}

///|
// Like upstream (mechanics.rs:179): `None` is only reached through
// wildcards, `PagesRequired` is never built (`#[allow(dead_code)]`,
// mechanics.rs:192) and `BothForbidden` is only read by the unported
// `Entry::verify` (lib.rs:453).
#warnings("-unused_constructor")
priv enum PagesChapterMode {
  None_
  OneRequired
  BothOptional
  BothForbidden
  PagesOptional
  PagesRequired
}

///|
fn PagesChapterMode::possible(self : PagesChapterMode) -> Array[String] {
  match self {
    OneRequired | BothOptional => ["pages", "chapter"]
    PagesOptional | PagesRequired => ["pages"]
    _ => []
  }
}

///|
priv struct Requirements {
  mut required : Array[String]
  optional : Array[String]
  forbidden : Array[String]
  mut author_eds_field : AuthorMode
  mut page_chapter_field : PagesChapterMode
  mut needs_date : Bool
}

///|
/// Parse an entry type from a string.
pub fn EntryType::new(name : String) -> EntryType {
  let name = @unscanny.to_lowercase(name)
  for pair in entry_type_names[:] {
    if pair.0 == name {
      return pair.1
    }
  }
  match name {
    // These aliases are documented on [`EntryType`].
    "conference" => InProceedings
    "electronic" => Online
    "www" => Online
    _ => Unknown(name)
  }
}

///|
/// Whether this is a multi-volume entry type.
pub fn EntryType::is_multi_volume(self : EntryType) -> Bool {
  self is (MvBook | MvCollection | MvReference | MvProceedings)
}

///|
/// Whether this is a single-volume composite entry type.
pub fn EntryType::is_collection(self : EntryType) -> Bool {
  self is (Book | Collection | Periodical | Reference | Proceedings)
}

///|
/// Convert into a type native to BibLaTeX.
pub fn EntryType::to_biblatex(self : EntryType) -> EntryType {
  match self {
    MastersThesis => Thesis
    PhdThesis => Thesis
    TechReport => Report
    Unknown(_) => Misc
    _ => self
  }
}

///|
/// Convert into a type supported by BibTeX.
pub fn EntryType::to_bibtex(self : EntryType) -> EntryType {
  match self {
    MvBook => Book
    BookInBook => InBook
    SuppBook => InBook
    Periodical => Misc
    SuppPeriodical => Article
    Collection => Proceedings
    MvCollection => Proceedings
    SuppCollection => InCollection
    Reference => Misc
    MvReference => Misc
    InReference => InCollection
    MvProceedings => Proceedings
    Report => TechReport
    Patent => Misc
    Thesis => PhdThesis
    Online => Misc
    Software => Misc
    Dataset => Misc
    Set => Misc
    XData => Misc
    Unknown(_) => Misc
    _ => self
  }
}

///|
fn EntryType::requirements(self : EntryType) -> Requirements {
  let reqs : Requirements = {
    required: [],
    optional: [],
    forbidden: [],
    author_eds_field: AuthorRequired,
    page_chapter_field: None_,
    needs_date: true,
  }
  reqs.required.push("title")
  reqs.optional.append([
    "note", "location", "titleadddon", "subtitle", "url", "urldate", "doi", "eprint",
    "eprintclass", "eprinttype", "pubstate", "language", "addendum",
  ])
  if self.is_multi_volume() {
    reqs.forbidden.append([
      "maintitle", "mainsubtitle", "maintitleaddon", "part", "volume",
    ])
  }
  match self {
    Article => {
      reqs.required.push("journaltitle")
      reqs.optional.remove(1) |> ignore
      reqs.optional.append([
        "number", "series", "version", "volume", "annotator", "commentator", "translator",
        "origlanguage", "journalsubtitle", "issue", "issuetitle", "issuesubtitle",
        "eid", "issn",
      ])
      reqs.page_chapter_field = PagesOptional
      reqs.author_eds_field = AuthorRequiredEditorOptional
    }
    Book => {
      reqs.required.push("publisher")
      reqs.optional.append([
        "edition", "number", "series", "part", "volume", "volumes", "annotator",
        "commentator", "translator", "origlanguage", "afterword", "foreword", "introduction",
        "maintitle", "mainsubtitle", "maintitleaddon", "isbn", "pagetotal",
      ])
      reqs.author_eds_field = OneRequired
      reqs.page_chapter_field = BothOptional
    }
    Booklet => {
      reqs.optional.append(["howpublished", "type", "pagetotal"])
      reqs.author_eds_field = OneRequired
      reqs.page_chapter_field = BothOptional
      reqs.needs_date = false
    }
    InBook => {
      reqs.required.append(["publisher", "booktitle"])
      reqs.optional.append([
        "bookauthor", "volume", "volumes", "part", "type", "series", "number", "edition",
        "annotator", "commentator", "translator", "origlanguage", "afterword", "foreword",
        "introduction", "maintitle", "mainsubtitle", "maintitleaddon", "booksubtitle",
        "booktitleaddon", "isbn",
      ])
      reqs.forbidden.push("pagetotal")
      reqs.author_eds_field = OneRequired
      reqs.page_chapter_field = OneRequired
    }
    InCollection => {
      reqs.required.append(["publisher", "booktitle"])
      reqs.optional.append([
        "volume", "type", "series", "number", "edition", "annotator", "commentator",
        "translator", "origlanguage", "afterword", "foreword", "introduction", "maintitle",
        "mainsubtitle", "maintitleaddon", "booksubtitle", "booktitleaddon", "part",
        "volumes", "isbn",
      ])
      reqs.forbidden.push("pagetotal")
      reqs.author_eds_field = BothRequired
      reqs.page_chapter_field = BothOptional
    }
    InProceedings => {
      reqs.required.push("booktitle")
      reqs.optional.append([
        "number", "organization", "series", "volume", "volumes", "part", "publisher",
        "maintitle", "mainsubtitle", "maintitleaddon", "booksubtitle", "booktitleaddon",
        "eventtitle", "eventsubtitle", "eventtitleaddon", "venue", "isbn", "publisher",
      ])
      reqs.forbidden.push("pagetotal")
      reqs.page_chapter_field = BothOptional
      reqs.author_eds_field = AuthorRequiredEditorOptional
    }
    Manual => {
      reqs.optional.append([
        "edition", "organization", "series", "version", "isbn", "publisher", "type",
        "pagetotal",
      ])
      reqs.author_eds_field = OneRequired
      reqs.page_chapter_field = BothOptional
      reqs.needs_date = false
    }
    MastersThesis => {
      reqs.required.push("school")
      reqs.optional.push("type")
      reqs.author_eds_field = AuthorRequired
    }
    Misc => {
      reqs.optional.remove(1) |> ignore
      reqs.optional.append(["howpublished", "organization", "type"])
      reqs.author_eds_field = OneRequired
      reqs.needs_date = false
    }
    Proceedings => {
      reqs.optional.append([
        "number", "organization", "series", "volume", "volumes", "part", "publisher",
        "maintitle", "mainsubtitle", "maintitleaddon", "isbn", "publisher", "pagetotal",
      ])
      reqs.author_eds_field = EditorRequiredAuthorForbidden
      reqs.page_chapter_field = BothOptional
    }
    TechReport => {
      reqs.required.push("institution")
      reqs.optional.append(["number", "type"])
    }
    Unpublished => {
      reqs.required.push("note")
      reqs.optional.remove(1) |> ignore
      reqs.optional.remove(0) |> ignore
      reqs.optional.append(["isbn", "howpublished"])
      reqs.needs_date = false
    }
    MvBook => {
      reqs.optional.append([
        "annotator", "commentator", "translator", "origlanguage", "afterword", "foreword",
        "introduction", "edition", "number", "series", "volumes", "isbn", "publisher",
        "pagetotal",
      ])
      reqs.page_chapter_field = BothOptional
      reqs.author_eds_field = AuthorRequiredEditorOptional
    }
    Periodical => {
      reqs.optional.append([
        "issue", "issuetitle", "issuesubtitle", "number", "series", "volume", "issn",
      ])
      reqs.author_eds_field = EditorRequiredAuthorForbidden
    }
    Collection => {
      reqs.optional.append([
        "annotator", "commentator", "translator", "origlanguage", "afterword", "foreword",
        "introduction", "maintitle", "mainsubtitle", "maintitleaddon", "edition",
        "number", "series", "part", "volume", "volumes", "isbn", "publisher", "pagetotal",
      ])
      reqs.author_eds_field = EditorRequiredAuthorForbidden
      reqs.page_chapter_field = BothOptional
    }
    MvCollection => {
      reqs.optional.append([
        "annotator", "commentator", "translator", "origlanguage", "afterword", "foreword",
        "introduction", "edition", "number", "series", "volumes", "isbn", "publisher",
        "pagetotal",
      ])
      reqs.author_eds_field = EditorRequiredAuthorForbidden
      reqs.page_chapter_field = BothForbidden
    }
    MvProceedings => {
      reqs.optional.append([
        "number", "series", "volumes", "publisher", "organization", "pagetotal",
      ])
      reqs.author_eds_field = EditorRequiredAuthorForbidden
      reqs.page_chapter_field = BothForbidden
    }
    Report => {
      reqs.required.append(["institution", "type"])
      reqs.optional.append(["number", "version", "isrn", "pagetotal"])
      reqs.page_chapter_field = BothOptional
    }
    Patent => {
      reqs.required.push("number")
      reqs.optional.append(["holder", "type"])
    }
    Thesis => {
      reqs.optional.push("isbn")
      reqs.required.append(["institution", "type"])
      reqs.optional.push("pagetotal")
      reqs.page_chapter_field = BothOptional
    }
    Online => {
      reqs.required.push("url")
      reqs.optional.remove(9) |> ignore
      reqs.optional.remove(8) |> ignore
      reqs.optional.remove(7) |> ignore
      reqs.optional.remove(6) |> ignore
      reqs.optional.remove(4) |> ignore
      reqs.optional.remove(1) |> ignore
      reqs.optional.push("organization")
      reqs.author_eds_field = OneRequired
    }
    Dataset => {
      reqs.optional.append([
        "edition", "type", "series", "number", "version", "organization", "publisher",
      ])
      reqs.author_eds_field = OneRequired
    }
    PhdThesis => return MastersThesis.requirements()
    SuppPeriodical => return Article.requirements()
    BookInBook => return InBook.requirements()
    SuppBook => return InBook.requirements()
    SuppCollection => return InCollection.requirements()
    Reference => return Collection.requirements()
    MvReference => return MvCollection.requirements()
    InReference => return InCollection.requirements()
    Software => return Misc.requirements()
    Set => {
      reqs.optional.clear()
      reqs.required = ["entryset"]
      reqs.author_eds_field = NoneRequired
      reqs.needs_date = false
    }
    XData => {
      reqs.optional.clear()
      reqs.required.clear()
      reqs.author_eds_field = NoneRequired
      reqs.needs_date = false
    }
    Unknown(_) => return MvCollection.requirements()
  }
  reqs
}

///|
/// Whether a field is verbatim (limited escapes).
pub fn is_verbatim_field(key : String) -> Bool {
  key
  is ("file"
  | "doi"
  | "uri"
  | "eprint"
  | "verba"
  | "verbb"
  | "verbc"
  | "pdf"
  | "url"
  | "urlraw")
}
