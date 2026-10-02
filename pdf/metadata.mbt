// Port of `typst-pdf/src/metadata.rs`.

///|
fn build_metadata(
  gc : GlobalContext,
  doc_lang : @library.Locale?,
) -> @export.Metadata {
  // Always write a language, PDF/UA-1 implicitly requires a document
  // language so the metadata and outline entries have an applicable
  // language.
  let lang = doc_lang.unwrap_or(@library.Locale::default())
  let dir : @export.TextDirection = if lang.lang.dir() == RTL {
    RightToLeft
  } else {
    LeftToRight
  }
  let info = gc.document.info()
  let mut metadata = @export.Metadata::new()
    .keywords(info.keywords.copy())
    .authors(info.author.copy())
    .language(lang.rfc_3066())
  let creator = match gc.options.creator {
    Custom(c) => c
    Auto => {
      let (major, minor, patch) = @library.typst_version
      Some("Typst \{major}.\{minor}.\{patch}")
    }
  }
  if creator is Some(creator) {
    metadata = metadata.creator(creator)
  }
  if info.title is Some(title) {
    metadata = metadata.title(title)
  }
  if info.description is Some(description) {
    metadata = metadata.description(description)
  }
  if gc.options.ident is Custom(ident) {
    metadata = metadata.document_id(ident)
  }
  if creation_date(gc) is Some(date) {
    metadata = metadata.creation_date(date)
  }
  metadata.text_direction(dir)
}

///|
/// (1) If the `document.date` is set to specific `datetime` or `none`, use
///     it.
/// (2) If the `document.date` is set to `auto` or not set, try to use the
///     date from the options.
/// (3) Otherwise, we don't write date metadata.
fn creation_date(gc : GlobalContext) -> @export.DateTime? {
  let (datetime, tz) = match (gc.document.info().date, gc.options.timestamp) {
    (Custom(Some(date)), _) => (date, None)
    (Auto, Some(timestamp)) => (timestamp.datetime, Some(timestamp.timezone))
    _ => return None
  }
  guard datetime.year() is Some(year) && year >= 0 else { return None }
  let mut kd = @export.DateTime::new(year)
  if datetime.month() is Some(month) {
    kd = kd.month(month)
  }
  if datetime.day() is Some(day) {
    kd = kd.day(day)
  }
  if datetime.hour() is Some(h) {
    kd = kd.hour(h)
  }
  if datetime.minute() is Some(m) {
    kd = kd.minute(m)
  }
  if datetime.second() is Some(s) {
    kd = kd.second(s)
  }
  match tz {
    Some(UTC) => kd = kd.utc_offset_hour(0).utc_offset_minute(0)
    Some(Local(h, m)) => kd = kd.utc_offset_hour(h).utc_offset_minute(m)
    None => ()
  }
  Some(kd)
}
