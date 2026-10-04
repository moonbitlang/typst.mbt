// Port of `typst-library/src/model/bibliography.rs` (the element itself is
// generated).
//
// `Derived<S, D>` fields store only their source value `S` (see
// `scripts/typemap.py`); the derived data (`Bibliography`, `CslStyle`) is
// recomputed from the source when needed. This is cheap because the decoded
// data is cached by the loaded bytes (upstream memoizes `Bibliography::decode`
// and `CslStyle::from_data` with comemo).

///|
/// Upstream `Synthesize for Packed<BibliographyElem>`.
fn bibliography_elem_synthesize(
  _engine : Engine,
  content : Content,
  styles : StyleChain,
) -> Content raise SourceError {
  BibliographyElem(content)
  .with_lang(TextElem::lang_in(styles))
  .with_region(TextElem::region_in(styles))
  .pack()
}

///|
/// Upstream `ShowSet for Packed<BibliographyElem>`.
fn bibliography_elem_show_set(
  _content : Content,
  _styles : StyleChain,
) -> Styles {
  let indent = Em::new(1.0)
  let out = Styles::new()
  out.push(HeadingElem::set_numbering(None))
  out.push(PadElem::set_left(Rel::from_abs(Length::from_em(indent))))
  out
}

///|
/// Upstream `LocalName for Packed<BibliographyElem>`.
fn bibliography_elem_local_name_key() -> String {
  "bibliography"
}

///|
/// `#[parse]` of `BibliographyElem::sources`.
fn bibliography_elem_sources_parse(
  engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let sources : @syntax.Spanned[OneOrMultiple[DataSource]] = args.expect_spanned(
    "sources",
  )
  let _ = Bibliography::load(engine.world, sources)
  Some(sources.v.into_value())
}

///|
/// `#[parse]` of `BibliographyElem::style`.
fn bibliography_elem_style_parse(
  engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let source : @syntax.Spanned[CslSource]? = args.named_spanned("style")
  match source {
    Some(source) => {
      let (source, _) = CslStyle::load(engine, source)
      Some(source.into_value())
    }
    None => None
  }
}

///|
/// `#[default]` of `BibliographyElem::style`.
fn bibliography_elem_style_default() -> Value {
  let default = @hayagriva.ArchivedStyle::InstituteOfElectricalAndElectronicsEngineers
  CslSource::Named(default, None).into_value()
}

///|
/// Whether any bibliography contains the given key.
pub fn BibliographyElem::has(
  engine : Engine,
  key : Label,
  span : @syntax.Span,
) -> Bool {
  engine
  .introspect(query_introspection(bibliography_elem().select(), span))
  .iter()
  .any(elem => BibliographyElem(elem).database(engine.world).has(key))
}

///|
/// Find all bibliography keys.
pub fn BibliographyElem::keys(
  world : &World,
  introspector : Introspector,
) -> Array[(Label, String?)] {
  let vec = []
  for elem in introspector.query(bibliography_elem().select()) {
    let this = BibliographyElem(elem)
    for pair in this.database(world).iter() {
      let (key, entry) = pair
      let detail = entry.title().map(title => title.value.to_str())
      vec.push((key, detail))
    }
  }
  vec
}

///|
/// The loaded bibliography (upstream `sources.derived`).
///
/// The sources were already successfully loaded when the element was
/// constructed, so this cannot fail in practice.
pub fn BibliographyElem::database(
  self : BibliographyElem,
  world : &World,
) -> Bibliography {
  let sources : @syntax.Spanned[OneOrMultiple[DataSource]] = {
    v: self.sources(),
    span: self.0.span(),
  }
  Bibliography::load(world, sources) catch {
    _ => Bibliography::empty()
  }
}

///|
/// The loaded style (upstream `style.derived`).
pub fn BibliographyElem::csl_style(
  self : BibliographyElem,
  world : &World,
) -> CslStyle {
  let source : CslSource = self.style(StyleChain::empty()).cast() catch {
      _ => CslSource::default_source()
    }
  source.derived_style(world, self.0.span())
}

///|
/// Produces the heading for the bibliography, if any.
pub fn BibliographyElem::realize_title(
  self : BibliographyElem,
  styles : StyleChain,
) -> Content? {
  let title = match self.title(styles) {
    Custom(title) => title
    Auto => Some(TextElem::packed(bibliography_elem().local_name_in(styles)))
  }
  title.map(title => {
    HeadingElem::new(title)
    .with_depth(NonZeroUSize(1))
    .pack()
    .spanned(self.0.span())
  })
}

///|
/// A loaded bibliography.
pub struct Bibliography {
  priv entries : Array[(Label, @hayagriva.Entry)]
  priv index : Map[Label, Int]
}

///|
fn Bibliography::empty() -> Bibliography {
  { entries: [], index: Map([]), }
}

///|
/// Decoded bibliographies, keyed by the loaded data (upstream memoizes
/// `Bibliography::decode`).
let bibliography_cache : Array[(Array[(LoadSource, Bytes)], Bibliography)] = []

///|
/// Load a bibliography from data sources.
fn Bibliography::load(
  world : &World,
  sources : @syntax.Spanned[OneOrMultiple[DataSource]],
) -> Bibliography raise SourceError {
  let loaded = load_many({ v: sources.v.0, span: sources.span, }, world)
  Bibliography::decode(loaded)
}

///|
/// Decode a bibliography from loaded data sources.
fn Bibliography::decode(data : Array[Loaded]) -> Bibliography raise SourceError {
  let key = data.map(d => (d.source.v, d.data))
  for entry in bibliography_cache {
    if entry.0 == key {
      return entry.1
    }
  }
  let map = Bibliography::empty()
  let duplicates : Array[String] = []

  // We might have multiple bib/yaml files
  for d in data {
    let library = decode_library(d)
    for entry in library.entries() {
      let label = match Label::new(entry.key()) {
        Some(label) => label
        None =>
          bail_at(d.source.span, "bibliography contains entry with empty key")
      }
      if map.index.contains(label) {
        duplicates.push(entry.key())
      } else {
        map.index.set(label, map.entries.length())
        map.entries.push((label, entry))
      }
    }
  }
  if !duplicates.is_empty() {
    // TODO: Store spans of entries for duplicate key error messages.
    // Requires hayagriva entries to store their location, which should be
    // fine, since they are 1kb anyway.
    let span = data[0].source.span
    bail_at(span, "duplicate bibliography keys: \{duplicates.join(", ")}")
  }
  if bibliography_cache.length() >= 64 {
    bibliography_cache.remove(0) |> ignore
  }
  bibliography_cache.push((key, map))
  map
}

///|
pub fn Bibliography::has(self : Bibliography, key : Label) -> Bool {
  self.index.contains(key)
}

///|
pub fn Bibliography::get(self : Bibliography, key : Label) -> @hayagriva.Entry? {
  match self.index.get(key) {
    Some(i) => Some(self.entries[i].1)
    None => None
  }
}

///|
pub fn Bibliography::iter(
  self : Bibliography,
) -> Iter[(Label, @hayagriva.Entry)] {
  self.entries.iter()
}

///|
/// Upstream `Debug for Bibliography`.
pub impl Show for Bibliography with fn output(self, logger) {
  logger.write_string(
    "{" + self.entries.map(e => "\"" + e.0.resolve() + "\"").join(", ") + "}",
  )
}

///|
/// Decode on library from one data source.
fn decode_library(loaded : Loaded) -> @hayagriva.Library raise SourceError {
  let data = within(loaded, () => bytes_as_str(loaded.data))
  if loaded.source.v is Path(file_id) {
    // If we got a path, use the extension to determine whether it is YAML
    // or BibLaTeX.
    let ext = file_id.vpath().extension().unwrap_or("")
    match ext.to_lower() {
      "yml" | "yaml" =>
        within(loaded, () => {
          match @hayagriva.from_yaml_str(data) {
            Ok(library) => library
            Err(err) => raise LoadErr(format_hayagriva_yaml_error(err))
          }
        })
      "bib" =>
        within(loaded, () => {
          match @hayagriva.from_biblatex_str(data) {
            Ok(library) => library
            Err(errs) => raise LoadErr(format_biblatex_error(errs))
          }
        })
      _ =>
        bail_at(
          loaded.source.span,
          "unknown bibliography format (must be .yaml/.yml or .bib)",
        )
    }
  } else {
    // If we just got bytes, we need to guess. If it can be decoded as
    // hayagriva YAML, we'll use that.
    let haya_err = match @hayagriva.from_yaml_str(data) {
      Ok(library) => return library
      Err(err) => err
    }

    // If it can be decoded as BibLaTeX, we use that instead.
    let bib_errs : Array[@hayagriva.BibLaTeXError]? = match
      @hayagriva.from_biblatex_str(data) {
      // If the file is almost valid yaml, but contains no `@` character it
      // will be successfully parsed as an empty BibLaTeX library, since
      // BibLaTeX does support arbitrary text outside of entries.
      Ok(library) if !library.is_empty() => return library
      Ok(_) => None
      Err(err) => Some(err)
    }

    // If neither decoded correctly, check whether `:` or `{` appears more
    // often to guess whether it's more likely to be YAML or BibLaTeX and
    // emit the more appropriate error.
    let mut yaml = 0
    let mut biblatex = 0
    for c in data {
      match c {
        ':' => yaml += 1
        '{' => biblatex += 1
        _ => ()
      }
    }
    match bib_errs {
      Some(bib_errs) if biblatex >= yaml =>
        within(loaded, () => raise LoadErr(format_biblatex_error(bib_errs)))
      _ =>
        within(loaded, () => {
          raise LoadErr(format_hayagriva_yaml_error(haya_err))
        })
    }
  }
}

///|
/// The extension of a path's file name (upstream `Path::extension`).
fn path_extension(path : String) -> String? {
  let name = match path.rev_find("/") {
    Some(i) => path[i + 1:].to_owned()
    None => path
  }
  if name == ".." {
    return None
  }
  match name.rev_find(".") {
    Some(0) | None => None
    Some(i) => Some(name[i + 1:].to_owned())
  }
}

///|
/// `format_yaml_error` for the error of `hayagriva::io::from_yaml_str`.
fn format_hayagriva_yaml_error(err : @hayagriva.YamlLoadError) -> LoadError {
  format_yaml_error(@yaml.YamlError(message=err.message, location=err.location))
}

///|
/// Format a BibLaTeX loading error.
fn format_biblatex_error(errors : Array[@hayagriva.BibLaTeXError]) -> LoadError {
  // TODO: return multiple errors?
  guard errors.get(0) is Some(error) else {
    // TODO: can this even happen, should we just unwrap?
    return LoadError::text(
      NoPos,
      "failed to parse BibLaTeX",
      "something went wrong",
    )
  }
  let (range, msg) = match error {
    Parse(error) => (error.span, error.kind.to_string())
    Type(error) => (error.span, error.kind.to_string())
  }
  LoadError::text(
    Range(range.start, range.end),
    "failed to parse BibLaTeX",
    msg,
  )
}

///|
/// A loaded CSL style.
pub struct CslStyle {
  priv style : @citationberg.IndependentStyle
}

///|
/// Styles loaded from data, keyed by their bytes (upstream memoizes
/// `CslStyle::from_data`).
let csl_style_cache : Array[(Bytes, CslStyle)] = []

///|
/// Load a CSL style from a data source (upstream returns a
/// `Derived<CslSource, CslStyle>`).
pub fn CslStyle::load(
  engine : Engine,
  source : @syntax.Spanned[CslSource],
) -> (CslSource, CslStyle) raise SourceError {
  let { v: source, span, } = source
  let style = match source {
    Named(style, deprecation) => {
      if deprecation is Some(message) {
        engine.sink.warn(SourceDiagnostic::warning_at(span, message))
      }
      CslStyle::from_archived(style)
    }
    Normal(source) => {
      let loaded = source.load(span, engine.world)
      within(loaded, () => CslStyle::from_data(loaded.data))
    }
  }
  (source, style)
}

///|
/// Load a built-in CSL style.
pub fn CslStyle::from_archived(archived : @hayagriva.ArchivedStyle) -> CslStyle {
  match archived.get() {
    Independent(style) => { style, }
    // Ensured by `test_bibliography_load_builtin_styles`.
    Dependent(_) => abort("archive should not contain dependent styles")
  }
}

///|
/// Load a CSL style from file contents.
pub fn CslStyle::from_data(bytes : Bytes) -> CslStyle raise LoadErr {
  for entry in csl_style_cache {
    if entry.0 == bytes {
      return entry.1
    }
  }
  let text = bytes_as_str(bytes)
  let style = match @citationberg.IndependentStyle::from_xml(text) {
    Ok(style) => { style, }
    Err(err) =>
      raise LoadErr(
        LoadError::text(NoPos, "failed to load CSL style", err.to_string()),
      )
  }
  if csl_style_cache.length() >= 32 {
    csl_style_cache.remove(0) |> ignore
  }
  csl_style_cache.push((bytes, style))
  style
}

///|
/// Get the underlying independent style.
pub fn CslStyle::get(self : CslStyle) -> @citationberg.IndependentStyle {
  self.style
}

///|
/// Source for a CSL style.
pub(all) enum CslSource {
  /// A predefined named style and potentially a deprecation warning.
  Named(@hayagriva.ArchivedStyle, String?)
  /// A normal data source.
  Normal(DataSource)
} derive(Eq, Hash)

///|
fn CslSource::default_source() -> CslSource {
  Named(InstituteOfElectricalAndElectronicsEngineers, None)
}

///|
/// Recompute the derived style of a source that was already successfully
/// loaded once (when the element was constructed).
fn CslSource::derived_style(
  self : CslSource,
  world : &World,
  span : @syntax.Span,
) -> CslStyle {
  match self {
    Named(style, _) => CslStyle::from_archived(style)
    Normal(source) =>
      try {
        let loaded = source.load(span, world)
        within(loaded, () => CslStyle::from_data(loaded.data))
      } catch {
        _ =>
          CslStyle::from_archived(InstituteOfElectricalAndElectronicsEngineers)
      }
  }
}

///|
/// All possible names and their short documentation for `ArchivedStyle`,
/// including aliases.
fn archived_style_names() -> Array[(String, String)] {
  let out = []
  for style in @hayagriva.ArchivedStyle::all()[:] {
    let names = style.names()
    let main_name = names[0]
    out.push((main_name, style.display_name()))
    for i in 1..<names.length() {
      out.push((names[i], "A short alias of `\{main_name}`"))
    }
  }
  out
}

///|
pub impl Reflect for CslSource with fn input() {
  let source = [DataSource::input()]
  let names = archived_style_names().map(pair => {
    CastInfo::Value(Str(pair.0), pair.1)
  })
  Union(source + names)
}

///|
pub impl Reflect for CslSource with fn output() {
  DataSource::output()
}

///|
pub impl Reflect for CslSource with fn castable(v) {
  DataSource::castable(v)
}

///|
pub impl FromValue for CslSource with fn from_value(value) {
  if value is Str(string) {
    if path_extension(string) is None {
      let replacement = csl_replacement(string)
      let deprecation = replacement.map(instead => {
        "style `\{Value::Str(string).repr()}` has been deprecated in favor of `\{Value::Str(instead).repr()}`"
      })
      let style = match @hayagriva.ArchivedStyle::by_name(string) {
        Some(style) => style
        None =>
          raise HintedError(
            HintedString::new(
              match deprecation {
                Some(d) => d
                None => "unknown style: \{string}"
              },
            ),
          )
      }
      return Named(style, deprecation)
    }
  }
  Normal(DataSource::from_value(value))
}

///|
pub impl IntoValue for CslSource with fn into_value(self) {
  match self {
    // We prefer the shorter names which are at the back of the array.
    Named(v, _) => Str(v.names().last().unwrap())
    Normal(v) => v.into_value()
  }
}

///|
/// Maps from style names to their replacements.
///
/// TODO: Fully move this into hayagriva somehow.
fn csl_replacement(style : String) -> String? {
  Some(
    match style {
      "chicago-fullnotes" => "chicago-notes"
      "modern-humanities-research-association" =>
        "modern-humanities-research-association-notes"
      "council-of-science-editors" =>
        "cse-citation-sequence-brackets-8th-edition"
      "council-of-science-editors-author-date" => "cse-name-year"
      "modern-language-association-8" | "mla-8" => "modern-language-association"
      "vancouver" => "nlm-citation-sequence"
      "vancouver-superscript" => "nlm-citation-sequence-superscript"
      _ => return None
    },
  )
}

///|
/// Fully formatted citation groups and bibliographies, generated once for
/// the whole document.
///
/// This setup is necessary because citation formatting is inherently
/// stateful and we need access to all citations to do it.
pub struct Works {
  /// The document's rendered [`BibliographyElem`]s, keyed by their
  /// locations.
  priv bibliographies : Map[
    Location,
    Result[RenderedBibliography, Array[SourceDiagnostic]],
  ]
  /// The document's rendered [`CiteGroup`]s, keyed by their locations.
  priv groups : Map[Location, Result[Content, Array[SourceDiagnostic]]]
}

///|
/// The rendered parts for a bibliography.
pub(all) struct RenderedBibliography {
  /// Lists all entries in the bibliography, with optional prefix.
  entries : Array[RenderedEntry]
  /// Whether the bibliography should have hanging indent applied.
  hanging_indent : Bool
}

///|
/// The rendered parts for a bibliography entry.
pub(all) struct RenderedEntry {
  /// An optional prefix. This is exposed separately because this will go
  /// into its own column for grid-based styles.
  prefix : Content?
  /// The main content of the rendered bibliography entry.
  body : Content
  /// A location that should be attached to the rendered entry in some way.
  /// Citations will link there.
  backlink : Location
}

///|
/// Memoization of [Works::generate] (upstream uses comemo): the last
/// generated works for an introspector and a list of elements.
let works_cache : Ref[(Introspector, Array[Content], Works)?] = { val: None, }

///|
/// Generates and formats all bibliographies and citations.
pub fn Works::generate(
  engine : Engine,
  span : @syntax.Span,
) -> Works raise SourceError {
  let bibs_and_groups = engine.introspect(bibliography_introspection(span))
  if works_cache.val is Some((introspector, elems, works)) &&
    physical_equal(introspector, engine.introspector) &&
    elems == bibs_and_groups {
    return works
  }
  let works = Works::generate_impl(engine, bibs_and_groups)
  works_cache.val = Some((engine.introspector, bibs_and_groups, works))
  works
}

///|
/// The internal implementation of [`Works::generate`].
fn Works::generate_impl(
  engine : Engine,
  bibs_and_groups : Array[Content],
) -> Works {
  let engine = { ..engine, route: Route::extend(engine.route), }

  // Prepare bibliographies and citation groups for rendering with
  // hayagriva.
  let p = prepare(engine, bibs_and_groups)

  // Render the bibliography and citations with hayagriva.
  let offsets : Map[String, Int] = Map([])
  let rendered = p.bibs.map(bib => render(bib, offsets))
  {
    bibliographies: show_bibliographies(engine, p, rendered),
    groups: show_cite_groups(engine, p, rendered),
  }
}

///|
/// Returns the shown content for a citation.
pub fn Works::citation(
  self : Works,
  loc : Location,
  span : @syntax.Span,
) -> Content raise SourceError {
  match self.groups.get(loc) {
    Some(Ok(content)) => content
    Some(Err(errors)) => raise SourceError(errors)
    None =>
      raise SourceError([citation_could_not_be_located().into_error_at(span)])
  }
}

///|
/// Returns the shown content for a bibliography.
pub fn Works::bibliography(
  self : Works,
  loc : Location,
  span : @syntax.Span,
) -> RenderedBibliography raise SourceError {
  match self.bibliographies.get(loc) {
    Some(Ok(bib)) => bib
    Some(Err(errors)) => raise SourceError(errors)
    None =>
      raise SourceError([
        bibliography_could_not_be_located().into_error_at(span),
      ])
  }
}

///|
/// Preprocessed information for all bibliographies and citation groups in
/// the document, ready for rendering with hayagriva.
priv struct Preparation {
  /// Preprocessed information for all bibliographies in the document, in
  /// document order.
  bibs : Array[PreparedBibliography]
  /// Preprocessed information for all [`CiteGroup`] elements in the
  /// document, keyed by their [`Location`] (in document order).
  groups : Array[(Location, Result[PreparedCiteGroup, Array[SourceDiagnostic]])]
}

///|
/// Preprocessed information for a bibliography and the citations assigned
/// to it, ready for processing by hayagriva.
priv struct PreparedBibliography {
  /// The underlying bibliography element.
  elem : BibliographyElem
  /// The loaded bibliography (upstream `elem.sources.derived`).
  database : Bibliography
  /// The loaded style (upstream `elem.style.derived`).
  style : CslStyle
  /// Information about citation subgroups assigned to this bibliography, in
  /// document order. Each subgroup turns into one citation sent to
  /// hayagriva. A single [`CiteGroup`] can comprise multiple subgroups
  /// assigned to different bibliographies.
  subgroups : Array[Subgroup]
}

///|
/// Holds consecutive citations from a `CiteGroup` that were assigned to the
/// same bibliography.
priv struct Subgroup {
  /// The underlying citation group.
  elem : Content
  /// The citations in this subgroup.
  citations : Array[CiteElem]
  /// The style picked for this subgroup. Citations are not segmented by
  /// style (at least currently); we simply pick the style of the first
  /// citation.
  style : CslStyle
}

///|
/// Preprocessed information for a [`CiteGroup`]. Can be used to show the
/// group as [`Content`] after bibliographies are processed with hayagriva.
priv struct PreparedCiteGroup(Array[GroupPart])

///|
/// A segment in a preprocessed [`CiteGroup`].
priv enum GroupPart {
  /// This content should be displayed verbatim. In practice, this is only
  /// ever a [`SpaceElem`] between subgroups.
  Content(Content)
  /// Points to a subgroup in one of the bibliographies in the document and
  /// should be substituted by the content produced for the citation.
  Subgroup(Int, Int)
}

///|
/// Prepares the document's bibliographies and citation groups for rendering
/// with hayagriva.
fn prepare(engine : Engine, bibs_and_groups : Array[Content]) -> Preparation {
  // Maps from citations to bibliography indices for citations that were
  // explicitly selected via a bibliography with a `target`.
  let selected : Map[Location, Int] = Map([])

  // First, we process bibliographies.
  let bibs : Array[PreparedBibliography] = []
  for elem in bibs_and_groups {
    guard BibliographyElem::of(elem) is Some(bib) else { continue }
    let idx = bibs.length()
    bibs.push({
      elem: bib,
      database: bib.database(engine.world),
      style: bib.csl_style(engine.world),
      subgroups: [],
    })
    if bib.target(StyleChain::empty()) is Custom(LocatableSelector(selector)) {
      for
        citation in engine.introspect(
          query_introspection(selector, elem.span()),
        ) {
        let loc = citation.location().unwrap()
        if !selected.contains(loc) {
          selected.set(loc, idx)
        }
      }
    }
  }

  // Then, we process citations groups.
  let groups = []
  let mut bib_cursor = 0
  for elem in bibs_and_groups {
    guard CiteGroup::of(elem) is Some(group) else {
      bib_cursor += 1
      continue
    }
    let loc = elem.location().unwrap()
    let result = Ok(
      prepare_cite_group(engine, bibs, bib_cursor, group, selected),
    ) catch {
      SourceError(errors) => Err(errors)
    }
    groups.push((loc, result))
  }
  { bibs, groups, }
}

///|
/// Prepares a [`CiteGroup`] by
/// - splitting it into subgroups assigned to the same bibliography
/// - storing a [`Subgroup`] for each of these in the approprate slot in
///   `bibs`
/// - creating a [`PreparedCiteGroup`] which can be used to stitch the shown
///   content for the subgroups together after it was rendered with
///   hayagriva.
fn prepare_cite_group(
  engine : Engine,
  bibs : Array[PreparedBibliography],
  bib_cursor : Int,
  group : CiteGroup,
  selected : Map[Location, Int],
) -> PreparedCiteGroup raise SourceError {
  // Holds the collected segments of the citation group.
  let parts = []
  // Citations that make up the current subgroup.
  let mut subgroup = []
  // The bibliography index for the current subgroup. If `Some(_)`, then
  // `subgroup` is not empty.
  let mut subgroup_bib : Int? = None
  // The elements in `group.children[tail..i]` are interior spaces.
  let mut tail = 0
  // Holds errors for any uncovered citation. We collect them instead of
  // bailing early so that we can give multiple errors at once.
  let errors = []
  let children = group.children()
  for i, child in children {
    // The children are either citations or spaces. We skip interior spaces
    // without updating `tail`, so that at any point we can produce a slice
    // with the trailing spaces.
    guard CiteElem::of(child) is Some(citation) else { continue }
    let spaces = children[tail:i].to_owned()
    tail = i + 1

    // Determine the pre-selected bibliography or assign an auto
    // bibliography.
    let bib_idx = match selected.get(child.location().unwrap()) {
      Some(idx) => {
        // Ensure that the bibliography contains the key.
        let bib = bibs[idx]
        if !bib.database.has(citation.key()) {
          errors.push(key_does_not_exist(citation, bib))
          continue
        }
        idx
      }
      None =>
        match select_auto_bib(citation, bibs, bib_cursor) {
          Some(idx) => idx
          None => {
            errors.push(uncovered_citation(citation, bibs))
            continue
          }
        }
    }

    // If the assigned bibliography changes, flush the previous subgroup and
    // the spaces between it and the current `child`.
    if subgroup_bib is Some(sb) && sb != bib_idx {
      parts.push(save_subgroup(engine, bibs, sb, group, subgroup))
      subgroup = []
      for s in spaces {
        parts.push(GroupPart::Content(s))
      }
    }
    subgroup_bib = Some(bib_idx)
    subgroup.push(citation)
  }

  // Flush the final subgroup if any.
  if subgroup_bib is Some(sb) {
    parts.push(save_subgroup(engine, bibs, sb, group, subgroup))
  }
  if !errors.is_empty() {
    raise SourceError(errors)
  }
  PreparedCiteGroup(parts)
}

///|
/// Builds a [`Subgroup`] and stores it in the selected bibliography. Returns
/// a [`GroupPart`] to remember that this subgroup belongs to the
/// [`CiteGroup`] that's currently being prepared.
fn save_subgroup(
  engine : Engine,
  bibs : Array[PreparedBibliography],
  bib_idx : Int,
  elem : CiteGroup,
  citations : Array[CiteElem],
) -> GroupPart {
  let bib = bibs[bib_idx]
  let style = match citations.get(0) {
    Some(first) =>
      match first.style(StyleChain::empty()) {
        Auto => bib.style
        v =>
          try {
            let source : CslSource = v.cast()
            source.derived_style(engine.world, first.0.span())
          } catch {
            _ => bib.style
          }
      }
    None => bib.style
  }
  let sub_idx = bib.subgroups.length()
  bib.subgroups.push({ elem: elem.0, citations, style, })
  Subgroup(bib_idx, sub_idx)
}

///|
/// Selects the appropriate bibliography for a citation that was not
/// explicitly targeted by a bibliography.
///
/// The priority is:
/// 1. First following auto bibliography containing the citation key
/// 2. First preceding auto bibliography containing the citation key
///
/// Returns `None` if no auto bibliography contains the key.
fn select_auto_bib(
  citation : CiteElem,
  bibs : Array[PreparedBibliography],
  bib_cursor : Int,
) -> Int? {
  let ok = (idx : Int) => {
    let bib = bibs[idx]
    bib.elem.target(StyleChain::empty()) is Auto &&
    bib.database.has(citation.key())
  }
  for idx in bib_cursor..<bibs.length() {
    if ok(idx) {
      return Some(idx)
    }
  }
  let before = if bib_cursor < bibs.length() {
    bib_cursor
  } else {
    bibs.length()
  }
  for idx = before - 1; idx >= 0; idx = idx - 1 {
    if ok(idx) {
      return Some(idx)
    }
  }
  None
}

///|
/// The key of a bibliography group for numbering offsets (upstream
/// `Smart<&str>`).
fn group_key(group : Smart[String]) -> String {
  match group {
    Auto => "auto"
    Custom(s) => "custom:" + s
  }
}

///|
/// Renders the bibliography and citation groups with hayagriva.
fn render(
  bib : PreparedBibliography,
  offsets : Map[String, Int],
) -> @hayagriva.Rendered {
  let locales = @hayagriva.locales()
  let database = bib.database
  let mut driver = @hayagriva.BibliographyDriver::new()
  let offset_key = bib.elem.group(StyleChain::empty()).map(group_key)
  if offset_key is Some(key) {
    if !offsets.contains(key) {
      offsets.set(key, 0)
    }
    driver = driver.with_citation_number_offset(offsets.get(key).unwrap())
  }
  for group in bib.subgroups {
    let items = group.citations.map(child => {
      let entry = database.get(child.key()).unwrap()
      citation_item(entry, child)
    })
    let first = group.citations[0]
    let locale = csl_locale(
      first.lang().unwrap_or(lang_english),
      first.region().unwrap_or(None),
    )
    driver.citation(
      @hayagriva.CitationRequest::new(
        items,
        group.style.get(),
        Some(locale),
        locales,
        None,
      ),
    )
  }
  let bib_style = bib.style
  let locale = csl_locale(
    bib.elem.lang().unwrap_or(lang_english),
    bib.elem.region().unwrap_or(None),
  )

  // Add hidden items for everything if we should print the whole
  // bibliography.
  if bib.elem.full(StyleChain::empty()) {
    for pair in database.iter() {
      driver.citation(
        @hayagriva.CitationRequest::new(
          [@hayagriva.CitationItem::new(pair.1, None, None, true, None)],
          bib_style.get(),
          Some(locale),
          locales,
          None,
        ),
      )
    }
  }
  let rendered = driver.finish({
    style: bib_style.get(),
    locale: Some(locale),
    locale_files: locales,
  })
  if offset_key is Some(key) && rendered.bibliography is Some(b) {
    // Check whether the bibliography or any citation displays citation
    // numbers. Only then does the bibliography occupy a numbering range that
    // subsequent bibliographies in the same group must skip.
    if b.items.iter().any(displays_citation_number) ||
      rendered.citations
      .iter()
      .any(rendered => rendered.citation.find_meta(CitationNumber) is Some(_)) {
      offsets.set(key, offsets.get(key).unwrap() + b.items.length())
    }
  }
  rendered
}

///|
/// Whether a rendered bibliography item displays a citation number.
///
/// For styles with `second-field-align` (like IEEE), the number resides in
/// the item's first field rather than in its content.
fn displays_citation_number(item : @hayagriva.BibliographyItem) -> Bool {
  item.content.find_meta(CitationNumber) is Some(_) ||
  (match item.first_field {
    Some(Elem(elem)) =>
      elem.meta == Some(CitationNumber) ||
      elem.children.find_meta(CitationNumber) is Some(_)
    _ => false
  })
}

///|
/// Creates a hayagriva citation item for a citation element.
fn citation_item(
  entry : @hayagriva.Entry,
  child : CiteElem,
) -> @hayagriva.CitationItem {
  let supplement = child.supplement(StyleChain::empty())
  let locator = supplement.map(c => {
    @hayagriva.SpecificLocator(
      Custom,
      Transparent(@hayagriva.TransparentLocator::new(c.repr())),
    )
  })
  let mut hidden = false
  let special_form : @hayagriva.CitePurpose? = match
    child.form(StyleChain::empty()) {
    None => {
      hidden = true
      None
    }
    Some(Normal) => None
    Some(Prose) => Some(Prose)
    Some(Full) => Some(Full)
    Some(Author) => Some(Author)
    Some(Year) => Some(Year)
  }
  @hayagriva.CitationItem::new(entry, locator, None, hidden, special_form)
}

///|
/// Produces the structured content for all [`BibliographyElem`]s in the
/// document.
fn show_bibliographies(
  engine : Engine,
  p : Preparation,
  rendered : Array[@hayagriva.Rendered],
) -> Map[Location, Result[RenderedBibliography, Array[SourceDiagnostic]]] {
  let out = Map([])
  for i, bib in p.bibs {
    let rendered = rendered[i]
    let loc = bib.elem.0.location().unwrap()
    let span = bib.elem.0.span()
    let result = match rendered.bibliography {
      None => {
        let source : CslSource = bib.elem.style(StyleChain::empty()).cast() catch {
            _ => CslSource::default_source()
          }
        Err([SourceDiagnostic::error_at(span, style_unsuitable(source))])
      }
      Some(r) =>
        Ok(show_bibliography(engine, bib, r)) catch {
          HintedError(err) => Err([err.into_error_at(span)])
        }
    }
    out.set(loc, result)
  }
  out
}

///|
/// Turns a bibliography rendered with hayagriva into a final
/// [`RenderedBibliography`].
fn show_bibliography(
  engine : Engine,
  bib : PreparedBibliography,
  rendered : @hayagriva.RenderedBibliography,
) -> RenderedBibliography raise HintedError {
  let to_citations = links_to_citations(bib.subgroups)
  let entries = []
  for k, item in rendered.items {
    let ctx : ShowCtx = {
      engine,
      span: bib.elem.0.span(),
      supplement: _ => None,
      link: _ => None,
    }

    // Render the first field.
    let prefix : Ref[Content?] = {
      val: match item.first_field {
        Some(elem) => Some(show_elem_child(ctx, elem, None, false))
        None => None
      },
    }

    // Render the main reference content.
    let body = show_elem_children(ctx, item.content, Some(prefix), false)

    // Attach link to citation to the prefix.
    let prefix = prefix.val.map(content => {
      match to_citations.get(item.key) {
        Some(location) => {
          let alt = content.plain_text()
          let body = content.spanned(ctx.span)
          DirectLinkElem::new(location, body, Some(alt)).pack()
        }
        None => content
      }
    })
    entries.push({ prefix, body, backlink: entry_location(bib, k), })
  }
  { entries, hanging_indent: rendered.hanging_indent, }
}

///|
/// Produces the content for all [`CiteGroup`]s in the document.
fn show_cite_groups(
  engine : Engine,
  p : Preparation,
  rendered : Array[@hayagriva.Rendered],
) -> Map[Location, Result[Content, Array[SourceDiagnostic]]] {
  let to_entries = links_to_entries(p, rendered)
  let out = Map([])
  for pair in p.groups {
    let (loc, group) = pair
    let result = match group {
      Ok(group) =>
        Ok(
          show_cite_group(engine, group, p.bibs, rendered, (idx, key) => {
            to_entries.get((idx, key))
          }),
        ) catch {
          SourceError(errors) => Err(errors)
        }
      Err(errors) => Err(errors)
    }
    out.set(loc, result)
  }
  out
}

///|
/// Produces the content for a [`CiteGroup`] by stitching together the
/// hayagriva output for each subgroup and interspersing potential space
/// elements that were retained between subgroups.
fn show_cite_group(
  engine : Engine,
  group : PreparedCiteGroup,
  prepared : Array[PreparedBibliography],
  rendered : Array[@hayagriva.Rendered],
  to_entry : (Int, String) -> Location?,
) -> Content raise SourceError {
  let seq = []
  for part in group.0 {
    seq.push(
      match part {
        Content(c) => c
        Subgroup(bib_idx, sub_idx) => {
          let subgroup = prepared[bib_idx].subgroups[sub_idx]
          let item = rendered[bib_idx].citations[sub_idx]
          show_subgroup(engine, subgroup, item, key => to_entry(bib_idx, key))
        }
      },
    )
  }
  Content::sequence(seq)
}

///|
/// Upstream `Span::find`: the first non-detached span.
fn span_find(spans : Array[@syntax.Span]) -> @syntax.Span {
  for span in spans {
    if !span.is_detached() {
      return span
    }
  }
  @syntax.Span::detached()
}

///|
/// Displays a single citation subgroup.
fn show_subgroup(
  engine : Engine,
  group : Subgroup,
  citation : @hayagriva.RenderedCitation,
  to_entry : (String) -> Location?,
) -> Content raise SourceError {
  if group.citations.iter().all(sub => sub.form(StyleChain::empty()) is None) {
    return Content::empty()
  }
  let span = span_find(group.citations.map(elem => elem.0.span()))
  let supplement = (i : Int) => {
    match group.citations.get(i) {
      Some(c) => c.supplement(StyleChain::empty())
      None => None
    }
  }
  let link = (i : Int) => {
    match group.citations.get(i) {
      Some(c) => to_entry(c.key().resolve())
      None => None
    }
  }
  let ctx : ShowCtx = { engine, span, supplement, link, }
  let mut realized = at(span, () => {
    show_elem_children(ctx, citation.citation, None, true)
  })
  if group.style.get().settings.class == Note &&
    group.citations
    .iter()
    .all(sub => sub.form(StyleChain::empty()) is (None | Some(Normal))) {
    realized = FootnoteElem::with_content(realized).pack()
  }
  realized
}

///|
/// Creates a map from citation keys to the citation group containing the
/// first citation assigned to a particular bibliography that references the
/// key.
///
/// This is used by bibliography entries to link back to the first citation
/// that references them.
fn links_to_citations(groups : Array[Subgroup]) -> Map[String, Location] {
  let map = Map([])
  for group in groups {
    for child in group.citations {
      let key = child.key().resolve()
      if !map.contains(key) {
        map.set(key, group.elem.location().unwrap())
      }
    }
  }
  map
}

///|
/// Creates a map from a bibliography index + citation key to the
/// corresponding entry in the bibliography.
///
/// This is used by citations to link forward to the bibliography entry they
/// reference.
fn links_to_entries(
  p : Preparation,
  rendered : Array[@hayagriva.Rendered],
) -> Map[(Int, String), Location] {
  let links = Map([])
  for i, bib in p.bibs {
    guard rendered[i].bibliography is Some(r) else { continue }
    for k, item in r.items {
      links.set((i, item.key), entry_location(bib, k))
    }
  }
  links
}

///|
/// Each reference is assigned a manually created well-known location that is
/// derived from the bibliography's location. This way, citations can link to
/// them without having to query for them (which would incur an extra layout
/// iteration).
fn entry_location(bib : PreparedBibliography, k : Int) -> Location {
  bib.elem.0.location().unwrap().variant(k + 1)
}

///|
/// Additional data needed to show hayagriva elements as content.
priv struct ShowCtx {
  /// The engine that is used to evaluate mathematical material (upstream
  /// only passes the world).
  engine : Engine
  /// The span that is attached to all of the resulting content.
  span : @syntax.Span
  /// Resolves the supplement of i-th citation in the request.
  supplement : (Int) -> Content?
  /// Resolves where the i-th citation in the request should link to.
  link : (Int) -> Location?
}

///|
/// Displays rendered hayagriva elements.
///
/// The `prefix` can be a separate content storage where `left-margin`
/// elements will be accumulated into.
///
/// `is_citation` dictates whether whitespace at the start of the citation
/// will be eliminated. Some CSL styles yield whitespace at the start of
/// their citations, which should instead be handled by Typst.
fn show_elem_children(
  ctx : ShowCtx,
  elems : @hayagriva.ElemChildren,
  prefix : Ref[Content?]?,
  is_citation : Bool,
) -> Content raise HintedError {
  let out = []
  for i, elem in elems.0 {
    out.push(show_elem_child(ctx, elem, prefix, is_citation && i == 0))
  }
  Content::sequence(out)
}

///|
/// Displays a rendered hayagriva element.
fn show_elem_child(
  ctx : ShowCtx,
  elem : @hayagriva.ElemChild,
  prefix : Ref[Content?]?,
  trim_start : Bool,
) -> Content raise HintedError {
  match elem {
    Text(formatted) => show_formatted(ctx, formatted, trim_start)
    Elem(elem) => show_elem(ctx, elem, prefix)
    Markup(markup) => show_math(ctx, markup)
    Link(text~, url~) => show_link(ctx, text, url)
    Transparent(cite_idx~, format~) => show_transparent(ctx, cite_idx, format)
  }
}

///|
/// Displays a block-level element.
fn show_elem(
  ctx : ShowCtx,
  elem : @hayagriva.Elem,
  prefix : Ref[Content?]?,
) -> Content raise HintedError {
  let block_level = elem.display is Some(Block | Indent)
  let mut content = show_elem_children(
    ctx,
    elem.children,
    if block_level {
      None
    } else {
      prefix
    },
    false,
  )
  match elem.display {
    Some(Block) =>
      content = BlockElem::new()
        .with_body(Some(BlockBody::Content(content)))
        .pack()
        .spanned(ctx.span)
    Some(Indent) =>
      content = CslIndentElem::new(content).pack().spanned(ctx.span)
    Some(LeftMargin) =>
      // The `display="left-margin"` attribute is only supported at the
      // top-level (when prefix is `Some(_)`). Within a block-level
      // container, it is ignored. The CSL spec is not specific about this,
      // but it is in line with citeproc.js's behaviour.
      if prefix is Some(prefix) {
        prefix.val = Some(
          match prefix.val {
            Some(p) => p.add(content)
            None => Content::empty().add(content)
          },
        )
        return Content::empty()
      }
    _ => ()
  }
  content = content.spanned(ctx.span)
  if elem.meta is Some(Entry(i)) && (ctx.link)(i) is Some(location) {
    let alt = content.plain_text()
    content = DirectLinkElem::new(location, content, Some(alt)).pack()
  }
  content
}

///|
/// Displays math.
fn show_math(ctx : ShowCtx, math : String) -> Content {
  let engine : Engine = {
    world: ctx.engine.world,
    library: ctx.engine.library,
    introspector: Introspector::empty(),
    traced: Traced::new(),
    // TODO: propagate warnings
    sink: Sink::new(),
    route: Route::root(),
  }
  let value = (engine.library.routines.eval_string)(
    engine,
    Context::none(),
    math,
    ctx.span,
    @syntax.SyntaxMode::Math,
    Scope::new(),
  ) catch {
    _ => return TextElem::packed(math).spanned(ctx.span)
  }
  value.display()
}

///|
/// Displays a link.
fn show_link(
  ctx : ShowCtx,
  text : @hayagriva.Formatted,
  url : String,
) -> Content raise HintedError {
  let dest = Destination::Url(Url::new(url))
  LinkElem::new(Dest(dest), show_formatted(ctx, text, false))
  .pack()
  .spanned(ctx.span)
}

///|
/// Displays transparent pass-through content.
fn show_transparent(
  ctx : ShowCtx,
  i : Int,
  format : @hayagriva.Formatting,
) -> Content {
  let content = (ctx.supplement)(i).unwrap_or(Content::empty())
  show_with_formatting(content, format)
}

///|
/// Displays formatted hayagriva text as content.
fn show_formatted(
  ctx : ShowCtx,
  formatted : @hayagriva.Formatted,
  trim_start : Bool,
) -> Content {
  let formatted_text = if trim_start {
    rust_trim_start(formatted.text)
  } else {
    formatted.text
  }
  let content = TextElem::packed(formatted_text).spanned(ctx.span)
  show_with_formatting(content, formatted.formatting)
}

///|
/// Applies hayagriva formatting to content.
fn show_with_formatting(
  content : Content,
  format : @hayagriva.Formatting,
) -> Content {
  let mut content = content
  match format.font_style {
    @citationberg.FontStyle::Normal => ()
    Italic => {
      let span = content.span()
      content = EmphElem::new(content).pack().spanned(span)
    }
  }
  match format.font_variant {
    @citationberg.FontVariant::Normal => ()
    SmallCaps => content = SmallcapsElem::new(content).pack()
  }
  match format.font_weight {
    @citationberg.FontWeight::Normal => ()
    Bold => {
      let span = content.span()
      content = StrongElem::new(content).pack().spanned(span)
    }
    Light =>
      // We don't have a semantic element for "light" and a `StrongElem`
      // with negative delta does not have the appropriate semantics, so
      // keeping this as a direct style.
      content = CslLightElem::new(content).pack()
  }
  match format.text_decoration {
    None_ => ()
    Underline => {
      let span = content.span()
      content = UnderlineElem::new(content).pack().spanned(span)
    }
  }
  let span = content.span()
  match format.vertical_align {
    None_ => ()
    Baseline => ()
    Sup =>
      // Add zero-width weak spacing to make the superscript "sticky".
      content = h_hole().add(SuperElem::new(content).pack().spanned(span))
    Sub => content = h_hole().add(SubElem::new(content).pack().spanned(span))
  }
  content
}

///|
/// Upstream `HElem::hole`.
fn h_hole() -> Content {
  HElem::new(Rel(Rel::zero())).with_weak(true).pack()
}

///|
/// Creates a locale code from language and optionally region.
fn csl_locale(lang : Lang, region : Region?) -> @citationberg.LocaleCode {
  let value = StringBuilder()
  value.write_string(lang.as_str())
  if region is Some(region) {
    value.write_char('-')
    value.write_string(region.as_str())
  }
  @citationberg.LocaleCode(value.to_string())
}

///|
/// Retrieves all bibliographies and citation groups in the document.
///
/// This is separate from `QueryIntrospection` so that we can customize the
/// diagnostic as the `CiteGroup` is internal. The default query message is
/// also not that helpful in this case.
fn bibliography_introspection(
  span : @syntax.Span,
) -> Introspect[Array[Content]] {
  Introspect::new(
    (_, introspector) => {
      introspector.query(
        Or([bibliography_elem().select(), cite_group_elem().select()]),
      )
    },
    _ => {
      SourceDiagnostic::warning_at(
        span, "citations and bibliographies did not stabilize",
      )
    },
  )
}

///|
/// The diagnostic when a citation wasn't found in the pre-formatted list.
fn citation_could_not_be_located() -> HintedString {
  HintedString::new("citation could not be located")
  .with_hint("this citation is not stably present in the document")
  .with_hint("this can be caused by measurement or introspection")
}

///|
/// The diagnostic when a bibliography wasn't found in the pre-formatted
/// list.
fn bibliography_could_not_be_located() -> HintedString {
  HintedString::new("bibliography could not be located")
  .with_hint("this bibliography is not stably present in the document")
  .with_hint("this can be caused by measurement or introspection")
}

///|
/// The diagnostic when a citation is not picked up by any bibliography.
fn uncovered_citation(
  citation : CiteElem,
  bibs : Array[PreparedBibliography],
) -> SourceDiagnostic {
  let span = citation.0.span()
  let key = citation.key().resolve()
  if bibs.is_empty() {
    return SourceDiagnostic::error_at(
      span, "the document does not contain a bibliography",
    )
  }
  for bib in bibs {
    if bib.database.has(citation.key()) {
      let diag = SourceDiagnostic::error_at(
        span, "citation is not covered by any bibliography",
      )
      diag.spanned_hint(
        "a bibliography containing the key `\{key}` exists, but its `target` excludes this citation",
        @syntax.DiagSpan::from_span(bib.elem.0.span()),
      )
      return diag
    }
  }
  SourceDiagnostic::error_at(
    span,
    "citation key `\{key}` is not present in \{if bibs.length() == 1 { "the" } else { "any" }} bibliography",
  )
}

///|
/// The diagnostic when a citation is explicitly targeted by a bibliography,
/// but its key does not exist in said bibliography.
fn key_does_not_exist(
  citation : CiteElem,
  bib : PreparedBibliography,
) -> SourceDiagnostic {
  let diag = SourceDiagnostic::error_at(
    citation.0.span(),
    "key `\{citation.key().resolve()}` does not exist in the bibliography",
  )
  diag.spanned_hint(
    "the citation was assigned to this bibliography",
    @syntax.DiagSpan::from_span(bib.elem.0.span()),
  )
  diag
}

///|
/// The error message when a CSL style cannot be used for bibliographies.
fn style_unsuitable(source : CslSource) -> String {
  match source {
    Named(style, _) =>
      "CSL style \"\{style.display_name()}\" is not suitable for bibliographies"
    CslSource::Normal(_) => "CSL style is not suitable for bibliographies"
  }
}
