// Port of `typst-library/src/text/raw.rs` (the element itself is
// generated): `RawContent`, highlighting with syntect (`syntect/`) and
// Typst's own highlighter (`syntax/highlight`), and the `syntaxes` and
// `theme` fields.
//
// `Derived<S, D>` fields store only their source value `S` (see
// `scripts/typemap.py`); the derived syntaxes/themes are recorded when the
// field is parsed and looked up by their source when highlighting.

///|
/// The content of the raw text.
///
/// Stored in the element's `text` field like upstream: `Text` as the string
/// value, `Lines` (which the evaluator creates from the lines of raw
/// syntax, each with the span of its syntax node) as the internal
/// `DynValue::RawContent`. Users see the string through the field's output
/// conversion (`raw_elem_text_output`, upstream's `IntoValue`), so the
/// lines never become a Typst value.
pub(all) enum RawContent {
  /// From a string.
  Text(String)
  /// From lines of text.
  Lines(Array[(String, @syntax.Span)])
} derive(Hash, Debug)

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RawContent with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RawContent with @debug.Debug::{to_repr}

///|
/// Returns or synthesizes the text content of the raw text.
pub fn RawContent::get(self : RawContent) -> String {
  match self {
    Text(text) => text
    Lines(lines) =>
      if lines.length() <= 1 {
        match lines.get(0) {
          Some((line, _)) => line
          None => ""
        }
      } else {
        lines.map(l => l.0).join("\n")
      }
  }
}

///|
pub impl Eq for RawContent with fn equal(self, other) {
  match (self, other) {
    (Text(a), Text(b)) => a == b
    (Lines(_), Text(text)) | (Text(text), Lines(_)) =>
      text ==
      (match self {
        Lines(_) => self.get()
        Text(_) => other.get()
      })
    (Lines(a), Lines(b)) =>
      a.length() == b.length() &&
      a.iter().zip(b.iter()).all(p => p.0.0 == p.1.0)
  }
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RawContent with Eq::{not_equal, equal}

///|
pub impl Reflect for RawContent with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for RawContent with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for RawContent with fn castable(v) {
  v is Dyn(RawContent(_)) || str_castable(v)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RawContent with Reflect::{output, input, castable}

///|
/// The stored form of the raw content (see [RawContent]). Upstream's cast
/// to a string value is the field's output conversion,
/// `raw_elem_text_output`.
pub impl IntoValue for RawContent with fn into_value(self) {
  match self {
    Text(text) => Str(text)
    Lines(_) => Dyn(RawContent(self))
  }
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RawContent with IntoValue::{into_value}

///|
pub impl FromValue for RawContent with fn from_value(v) {
  match v {
    Dyn(RawContent(content)) => content
    v => Text(FromValue::from_value(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RawContent with FromValue::{from_value}

///|
/// The `text` field as users see it (upstream `RawContent`'s `IntoValue`:
/// `self.get().into_value()`).
fn raw_elem_text_output(v : Value) -> Value {
  match v {
    Dyn(RawContent(content)) => Str(content.get())
    v => v
  }
}

///|
/// Equality of two stored `text` fields (upstream `PartialEq for
/// RawContent`).
fn raw_elem_text_eq(a : Value, b : Value) -> Bool {
  match (a, b) {
    (Dyn(RawContent(x)), Dyn(RawContent(y))) => x == y
    (Dyn(RawContent(x)), Str(y)) => x == RawContent::Text(y)
    (Str(x), Dyn(RawContent(y))) => RawContent::Text(x) == y
    _ => a == b
  }
}

///|
/// Upstream `PlainText for Packed<RawElem>`.
fn raw_elem_init(e : Element) -> Unit {
  e.hooks().plain_text = Some((c, out) => {
    out.write_string(RawElem(c).text().get())
  })
}

///|
/// Upstream `PlainText for Packed<RawLine>`.
fn raw_line_elem_init(e : Element) -> Unit {
  e.hooks().plain_text = Some((c, out) => out.write_string(RawLine(c).text()))
}

///|
/// Upstream `ShowSet for Packed<RawElem>`.
fn raw_elem_show_set(content : Content, styles : StyleChain) -> Styles {
  let out = Styles::new()
  out.push(TextElem::set_overhang(false))
  out.push(TextElem::set_lang(lang_english))
  out.push(TextElem::set_hyphenate(Custom(false)))
  out.push(TextElem::set_size(TextSize(Length::from_em(Em::new(0.8)))))
  out.push(TextElem::set_font(FontList([FontFamily::new("DejaVu Sans Mono")])))
  out.push(TextElem::set_cjk_latin_spacing(Custom(None)))
  if RawElem(content).block(styles) {
    out.push(ParElem::set_justify(false))
  }
  out
}

///|
/// Upstream `LocalName for Packed<RawElem>`.
fn raw_elem_local_name_key() -> String {
  "raw"
}

///|
/// `Default::default()` of the raw syntaxes (RawElem.syntaxes): no sources.
fn raw_elem_syntaxes_default() -> Value {
  (OneOrMultiple([]) : OneOrMultiple[DataSource]).into_value()
}

///|
/// Upstream `Synthesize for Packed<RawElem>`.
// Cannot fail; a `Synthesize::synthesize` hook, `Ok(())` upstream
// (typst-library/src/text/raw.rs:515).
#warnings("-unused_error_type")
fn raw_elem_synthesize(
  engine : Engine,
  content : Content,
  styles : StyleChain,
) -> Content raise SourceError {
  let elem = RawElem(content)
  let seq = elem.highlight(engine, styles)
  elem.with_lines(seq).pack()
}

///|
/// A highlighted raw element: the arguments of [RawElem::highlight] and its
/// result.
priv struct RawHighlight {
  elem : Content
  styles : StyleChain
  routines : Routines
  lines : Array[RawLine]
}

///|
/// The highlighted lines of raw elements (upstream `#[comemo::memoize]` on
/// `Packed<RawElem>::highlight`), see [RawElem::highlight]: per key the
/// results for arguments that differ in what the key does not tell apart.
let raw_highlight_cache : ContentCache[Array[RawHighlight]] = ContentCache::new()

///|
/// Highlights the raw text into lines (upstream `Packed<RawElem>::highlight`,
/// which is `#[comemo::memoize]`d: the lookup is here, the function is
/// [RawElem::highlight_impl]).
///
/// The key is what upstream hashes: the element (`Hash for Packed<RawElem>`:
/// its fields, with the lines of the text and their spans, the syntaxes and
/// the theme with their decoded data, and its span, label, location and
/// lifecycle) and the style chain. Like the memoized calls of `memo.mbt` a
/// result is only reused for equal arguments, since a fingerprint does not
/// identify a host closure in the styles. Upstream's third argument, the
/// routines, hashes to nothing (`impl Hash for Routines`: a program has one
/// table); here a host can build another table with another
/// `html_span_filled`, which highlighting for HTML calls, so a result
/// belongs to the table it was made with.
///
/// Kept beyond the compilation (`memo_content.mbt`): a function of the
/// element and the styles alone, since the decoded syntaxes and the theme
/// are in them ([RawElem::derived_syntaxes], [RawElem::derived_theme]) and
/// the world is not asked. If it had to be asked (an element whose derived
/// data is missing), the result is not kept.
fn RawElem::highlight(
  self : RawElem,
  engine : Engine,
  styles : StyleChain,
) -> Array[RawLine] {
  let routines = engine.routines()
  if !content_memo_enabled() {
    return self.highlight_impl(engine, routines, styles, Ref(false))
  }
  let key = memo_fingerprint(state => {
    state.write(self.0)
    state.write_u128(styles.memo_hash())
  })
  let found = raw_highlight_cache.get(key)
  if found is Some(entries) {
    for entry in entries {
      if physical_equal(entry.routines, routines) &&
        content_memo_equal(entry.elem, self.0) &&
        chain_memo_equal(entry.styles, styles) {
        // The lines are immutable content; the array is the caller's.
        return entry.lines.copy()
      }
    }
  }
  let read_world = Ref(false)
  let lines = self.highlight_impl(engine, routines, styles, read_world)
  if !read_world.val {
    let entry = { elem: self.0, styles, routines, lines: lines.copy(), }
    match found {
      Some(entries) => {
        if entries.length() >= memo_max_entries {
          entries.remove(0) |> ignore
        }
        entries.push(entry)
      }
      None => raw_highlight_cache.insert(key, [entry])
    }
  }
  lines
}

///|
/// Upstream `Packed<RawElem>::highlight`. `read_world` is set if derived
/// data had to be loaded from the world (not upstream, where it is always
/// in the element or the styles).
fn RawElem::highlight_impl(
  self : RawElem,
  engine : Engine,
  routines : Routines,
  styles : StyleChain,
  read_world : Ref[Bool],
) -> Array[RawLine] {
  let elem = self
  let lines = raw_preprocess(elem.text(), styles, elem.0.span())
  let count = lines.length().to_int64()
  let lang = match elem.lang(styles) {
    Some(s) => Some(@unicode.to_lowercase(s))
    None => Some("txt")
  }
  fn non_highlighted_result(lines : Array[(String, @syntax.Span)]) {
    lines.mapi((i, line) => {
      let (line, line_span) = line
      RawLine(
        RawLine::new(
          i.to_int64() + 1,
          count,
          line,
          TextElem::packed(line).spanned(line_span),
        )
        .pack()
        .spanned(line_span),
      )
    })
  }

  let theme : @syntect.Theme = match elem.theme(styles) {
    Auto => raw_theme()
    Custom(Some(source)) =>
      match elem.derived_theme(engine, styles, source, read_world) {
        Some(theme) => theme.get()
        None => return non_highlighted_result(lines)
      }
    Custom(None) => return non_highlighted_result(lines)
  }
  let foreground = theme.settings.foreground.unwrap_or(@syntect.color_black)
  let target = TargetElem::target_in(styles)
  let seq = []
  if lang is Some("typ" | "typst" | "typc" | "typm") {
    let text = lines.map(l => l.0).join("\n")
    let root = match lang {
      Some("typc") => @syntax.parse_code(text)
      Some("typm") => @syntax.parse_math(text)
      _ => @syntax.parse(text)
    }
    let index = @syntect.ByteIndex::new(text)
    ThemedHighlighter::new(
      index,
      @syntax.LinkedNode::new(root),
      @syntect.Highlighter::new(theme),
      (i, _, range, style) => {
        // Find span and start of line.
        // Note: Dedent is already applied to the text
        let span = match lines.get(i) {
          Some(l) => l.1
          None => @syntax.Span::detached()
        }
        let before = index.slice(0, range.0)
        let span_offset = match before.rev_find("\n") {
          Some(j) =>
            range.0 -
            (@syntect.utf8_len(before.unsafe_substring(start=0, end=j)) + 1)
          None => 0
        }
        raw_styled(
          routines,
          target,
          index.slice(range.0, range.1),
          foreground,
          style,
          span,
          span_offset,
        )
      },
      (i, range, line) => {
        let span = match lines.get(i) {
          Some(l) => l.1
          None => @syntax.Span::detached()
        }
        seq.push(
          RawLine(
            RawLine::new(
              (i + 1).to_int64(),
              count,
              index.slice(range.0, range.1),
              Content::sequence(line.copy()),
            )
            .pack()
            .spanned(span),
          ),
        )
        line.clear()
      },
    ).highlight()
  } else if lang is Some(token) &&
    elem.find_syntax(engine, styles, token, read_world)
    is Some((syntax_set, syntax)) {
    let highlighter = @syntect.HighlightLines::new(syntax, theme)
    for i, entry in lines {
      let (line, line_span) = entry
      let line_content = []
      let mut span_offset = 0
      let pieces = highlighter.highlight_line(line, syntax_set) catch {
        _ => []
      }
      for piece in pieces {
        let (style, piece) = piece
        line_content.push(
          raw_styled(
            routines, target, piece, foreground, style, line_span, span_offset,
          ),
        )
        span_offset += @syntect.utf8_len(piece)
      }
      seq.push(
        RawLine(
          RawLine::new(
            i.to_int64() + 1,
            count,
            line,
            Content::sequence(line_content),
          )
          .pack()
          .spanned(line_span),
        ),
      )
    }
  } else {
    return non_highlighted_result(lines)
  }
  seq
}

///|
/// Style a piece of highlighted text (upstream `styled`).
fn raw_styled(
  routines : Routines,
  target : Target,
  piece : String,
  foreground : @syntect.Color,
  style : @syntect.Style,
  span : @syntax.Span,
  span_offset : Int,
) -> Content {
  let mut body = TextElem::packed(piece).spanned(span)
  if span_offset > 0 {
    body = body.styled(TextElem::set_span_offset(USize(span_offset.to_int64())))
  }
  if style.foreground != foreground {
    let color = raw_to_typst(style.foreground)
    body = match target {
      Html => (routines.html_span_filled)(body, color)
      _ => body.styled(TextElem::set_fill(Solid(color)))
    }
  }
  if style.font_style.contains(@syntect.font_style_bold) {
    body = body.strong().spanned(span)
  }
  if style.font_style.contains(@syntect.font_style_italic) {
    body = body.emph().spanned(span)
  }
  if style.font_style.contains(@syntect.font_style_underline) {
    body = body.underlined().spanned(span)
  }
  body
}

///|
fn raw_to_typst(color : @syntect.Color) -> Color {
  Color::from_u8(
    color.r.to_int(),
    color.g.to_int(),
    color.b.to_int(),
    color.a.to_int(),
  )
}

///|
/// Upstream `to_syn`: a Typst color as a syntect color.
fn raw_to_syn(color : Color) -> @syntect.Color {
  let c = color.to_vec4_u8()
  {
    r: c[0].to_byte(),
    g: c[1].to_byte(),
    b: c[2].to_byte(),
    a: c[3].to_byte(),
  }
}

///|
fn raw_theme_item(
  scope : String,
  color : String?,
  font_style : @syntect.FontStyle?,
) -> @syntect.ThemeItem {
  {
    scope: @syntect.ScopeSelectors::from_str(scope) catch {
      _ => abort("invalid scope selector")
    },
    style: {
      foreground: color.map(s => {
        match Color::from_str(s) {
          Ok(color) => raw_to_syn(color)
          Err(_) => abort("invalid color")
        }
      }),
      background: None,
      font_style,
    },
  }
}

///|
let raw_theme_cell : Ref[@syntect.Theme?] = Ref(None)

///|
/// The default theme (upstream `RAW_THEME`).
pub fn raw_theme() -> @syntect.Theme {
  match raw_theme_cell.val {
    Some(theme) => return theme
    None => ()
  }
  let bold = @syntect.font_style_bold
  let italic = @syntect.font_style_italic
  let underline = @syntect.font_style_underline
  let item = raw_theme_item
  let theme : @syntect.Theme = {
    name: Some("Typst Light"),
    author: Some("The Typst Project Developers"),
    settings: @syntect.ThemeSettings::default(),
    scopes: [
      item("comment", Some("#74747c"), None),
      item("constant.character.escape", Some("#1d6c76"), None),
      item("markup.bold", None, Some(bold)),
      item("markup.italic", None, Some(italic)),
      item("markup.underline", None, Some(underline)),
      item("markup.raw", Some("#6b6b6f"), None),
      item("string.other.math.typst", None, None),
      item("punctuation.definition.math", Some("#198810"), None),
      item(
        "keyword.operator.math, punctuation.math.typst",
        Some("#1d6c76"),
        None,
      ),
      item("markup.heading, entity.name.section", None, Some(bold)),
      item("markup.heading.typst", None, Some(bold | underline)),
      item("punctuation.definition.list", Some("#8b41b1"), None),
      item("markup.list.term", None, Some(bold)),
      item("entity.name.label, markup.other.reference", Some("#1d6c76"), None),
      item(
        "keyword, constant.language, variable.language",
        Some("#d73948"),
        None,
      ),
      item("storage.type, storage.modifier", Some("#d73948"), None),
      item("constant", Some("#b60157"), None),
      item("string", Some("#198810"), None),
      item("entity.name, variable.function, support", Some("#4b69c6"), None),
      item("support.macro", Some("#16718d"), None),
      item("meta.annotation", Some("#301414"), None),
      item("entity.other, meta.interpolation", Some("#8b41b1"), None),
      item("meta.diff.range", Some("#8b41b1"), None),
      item("markup.inserted, meta.diff.header.to-file", Some("#198810"), None),
      item("markup.deleted, meta.diff.header.from-file", Some("#d73948"), None),
      item(
        "meta.mapping.key.json string.quoted.double.json",
        Some("#4b69c6"),
        None,
      ),
      item(
        "meta.mapping.value.json string.quoted.double.json",
        Some("#198810"),
        None,
      ),
    ],
  }
  raw_theme_cell.val = Some(theme)
  theme
}

///|
/// The built-in syntaxes (upstream `RAW_SYNTAXES`).
pub fn raw_syntaxes() -> @syntect.SyntaxSet {
  @two_face.extra_no_newlines()
}

///|
/// A loaded syntax.
pub struct RawSyntax {
  priv set : @syntect.SyntaxSet
  /// `hash128` of the bytes it was decoded from: what a syntax hashes and
  /// compares as (upstream `ManuallyHash<SyntaxSet>`).
  priv hash : U128
}

///|
/// Upstream `PartialEq for ManuallyHash`: the hashes.
impl Eq for RawSyntax with fn equal(self, other) {
  self.hash == other.hash
}

///|
/// Upstream `Hash for ManuallyHash`: the hash.
impl Fingerprint for RawSyntax with fn fingerprint(self, state) {
  state.write_u128(self.hash)
}

///|
/// Decoded syntaxes, keyed by their bytes (upstream memoizes
/// `RawSyntax::decode`).
let raw_syntax_cache : Array[(Bytes, RawSyntax)] = []

///|
/// Load syntaxes from data sources (upstream returns a `Derived`: the
/// sources are the field's value, the list goes into its companion field
/// `syntaxes-derived`, see [raw_elem_syntaxes_parse]).
fn RawSyntax::load(
  world : &World,
  sources : @syntax.Spanned[OneOrMultiple[DataSource]],
) -> Array[RawSyntax] raise SourceError {
  let loaded = load_many({ v: sources.v.0, span: sources.span, }, world)
  loaded.map(data => within(data, () => RawSyntax::decode(data.data)))
}

///|
fn RawSyntax::decode(bytes : Bytes) -> RawSyntax raise LoadErr {
  for entry in raw_syntax_cache {
    if entry.0 == bytes {
      return entry.1
    }
  }
  let str = bytes_as_str(bytes)
  let syntax = @syntect.SyntaxDefinition::load_from_str(str, false, None) catch {
    e => raise LoadErr(format_syntax_error(e))
  }
  let builder = @syntect.SyntaxSetBuilder::new()
  builder.add(syntax)
  let syntax = { set: builder.build(), hash: data_hash(bytes), }
  raw_syntax_cache.push((bytes, syntax))
  syntax
}

///|
fn RawSyntax::get(self : RawSyntax) -> @syntect.SyntaxSet {
  self.set
}

///|
/// The stored form of the syntaxes of data sources (the companion field
/// `syntaxes-derived`; upstream `Derived::derived`, a `Vec<RawSyntax>`).
fn raw_syntaxes_value(list : Array[RawSyntax]) -> Value {
  Array(Arr::from_array(list.map(syntax => Value::Dyn(RawSyntax(syntax)))))
}

///|
/// `#[fold]` of the derived part of `RawElem::syntaxes` (upstream `Fold for
/// Derived<S, D>` folds the source and the derived data alike, and `Fold
/// for Vec<T>` puts the outer items first), so that the folded syntaxes are
/// those of the folded sources.
fn raw_elem_syntaxes_derived_fold(inner : Value, outer : Value) -> Value {
  match (inner, outer) {
    (Array(inner), Array(outer)) => {
      let items = outer.items.copy()
      items.append(inner.items)
      Array(Arr::from_array(items))
    }
    _ => inner
  }
}

///|
/// The syntaxes of the element's sources (upstream `elem.syntaxes
/// .get_cloned(styles).derived`): what the parser of the field loaded, from
/// the element or the styles.
///
/// Not upstream: if that is not there for every source (a field that was
/// set without its parser), the sources are loaded from the world, and
/// `read_world` is set.
fn RawElem::derived_syntaxes(
  self : RawElem,
  engine : Engine,
  styles : StyleChain,
  read_world : Ref[Bool],
) -> Array[RawSyntax] {
  let sources = self.syntaxes(styles).0
  if sources.is_empty() {
    return []
  }
  let e = raw_elem()
  let stored = styles.get_value_with_local(
    e,
    e.fields()[raw_elem_syntaxes_derived],
    self.0.field_raw(raw_elem_syntaxes_derived),
  )
  if stored is Array(stored) && stored.items.length() == sources.length() {
    let derived = []
    for item in stored.items {
      if item is Dyn(RawSyntax(syntax)) {
        derived.push(syntax)
      }
    }
    if derived.length() == sources.length() {
      return derived
    }
  }
  read_world.val = true
  RawSyntax::load(engine.world, {
    v: OneOrMultiple(sources),
    span: self.0.span(),
  }) catch {
    _ => []
  }
}

///|
/// Finds the syntax for a language token, preferring user-provided syntaxes
/// over built-in ones.
fn RawElem::find_syntax(
  self : RawElem,
  engine : Engine,
  styles : StyleChain,
  token : String,
  read_world : Ref[Bool],
) -> (@syntect.SyntaxSet, @syntect.SyntaxReference)? {
  let derived = self.derived_syntaxes(engine, styles, read_world)
  let sets = derived.map(syntax => syntax.get())
  sets.push(raw_syntaxes())
  for set in sets {
    if set.find_syntax_by_token(token) is Some(syntax) {
      return Some((set, syntax))
    }
  }
  None
}

///|
fn format_syntax_error(error : @syntect.ParseSyntaxError) -> LoadError {
  let pos = syntax_error_pos(error)
  LoadError::text(pos, "failed to parse syntax", error.to_string())
}

///|
fn syntax_error_pos(error : @syntect.ParseSyntaxError) -> ReportTextPos {
  match error {
    InvalidYaml(scan_error) => {
      let m = scan_error.marker()
      ReportTextPos::full(
        m.index(),
        m.index(),
        LineCol::one_based(m.line(), m.col() + 1),
      )
    }
    _ => NoPos
  }
}

///|
/// A loaded theme.
pub struct RawTheme {
  priv theme : @syntect.Theme
  /// `hash128` of the bytes it was decoded from: what a theme hashes and
  /// compares as (upstream `ManuallyHash<synt::Theme>`).
  priv hash : U128
}

///|
/// Upstream `PartialEq for ManuallyHash`: the hashes.
impl Eq for RawTheme with fn equal(self, other) {
  self.hash == other.hash
}

///|
/// Upstream `Hash for ManuallyHash`: the hash.
impl Fingerprint for RawTheme with fn fingerprint(self, state) {
  state.write_u128(self.hash)
}

///|
/// Decoded themes, keyed by their bytes (upstream memoizes
/// `RawTheme::decode`).
let raw_theme_cache : Array[(Bytes, RawTheme)] = []

///|
/// Load a theme from a data source (upstream returns a `Derived`: the
/// source is the field's value, the theme goes into its companion field
/// `theme-derived`, see [raw_elem_theme_parse]).
fn RawTheme::load(
  world : &World,
  source : @syntax.Spanned[DataSource],
) -> RawTheme raise SourceError {
  let loaded = source.v.load(source.span, world)
  within(loaded, () => RawTheme::decode(loaded.data))
}

///|
fn RawTheme::decode(bytes : Bytes) -> RawTheme raise LoadErr {
  for entry in raw_theme_cache {
    if entry.0 == bytes {
      return entry.1
    }
  }
  let theme = @syntect.ThemeSet::load_from_reader(bytes) catch {
    e => raise LoadErr(format_theme_error(e))
  }
  let theme = { theme, hash: data_hash(bytes), }
  raw_theme_cache.push((bytes, theme))
  theme
}

///|
/// The theme of the element's data source (upstream `theme.derived`): what
/// the parser of the field loaded, from the element or the styles.
///
/// Not upstream: if that is not there (a field that was set without its
/// parser), the source is loaded from the world, and `read_world` is set.
fn RawElem::derived_theme(
  self : RawElem,
  engine : Engine,
  styles : StyleChain,
  source : DataSource,
  read_world : Ref[Bool],
) -> RawTheme? {
  let e = raw_elem()
  let stored = styles.get_value_with_local(
    e,
    e.fields()[raw_elem_theme_derived],
    self.0.field_raw(raw_elem_theme_derived),
  )
  if stored is Dyn(RawTheme(theme)) {
    return Some(theme)
  }
  read_world.val = true
  try RawTheme::load(engine.world, { v: source, span: self.0.span(), }) catch {
    _ => None
  } noraise {
    theme => Some(theme)
  }
}

///|
pub fn RawTheme::get(self : RawTheme) -> @syntect.Theme {
  self.theme
}

///|
fn format_theme_error(error : @syntect.LoadingError) -> LoadError {
  let pos = match error {
    ParseSyntax(err, _) => syntax_error_pos(err)
    _ => NoPos
  }
  LoadError::text(pos, "failed to parse theme", error.to_string())
}

///|
/// `#[parse]` of `RawElem::syntaxes`.
fn raw_elem_syntaxes_parse(
  engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let sources : @syntax.Spanned[OneOrMultiple[DataSource]]? = args.named_spanned(
    "syntaxes",
  )
  match sources {
    Some(sources) => {
      let list = RawSyntax::load(engine.world, sources)
      locals.set("syntaxes-derived", Some(raw_syntaxes_value(list)))
      Some(sources.v.into_value())
    }
    None => None
  }
}

///|
/// `#[parse]` of `RawElem::theme`.
fn raw_elem_theme_parse(
  engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let theme : @syntax.Spanned[Smart[DataSource?]]? = args.named_spanned("theme")
  match theme {
    Some({ v: Custom(Some(source)), span, }) => {
      let theme = RawTheme::load(engine.world, { v: source, span, })
      locals.set("theme-derived", Some(Dyn(RawTheme(theme))))
      Some(Smart::Custom(Some(source)).into_value())
    }
    Some({ v: Custom(None), .. }) => Some(Smart::Custom(None).into_value())
    Some({ v: Auto, .. }) => Some(Auto)
    None => None
  }
}

///|
/// Highlights Typst code with a syntect theme (upstream `ThemedHighlighter`).
priv struct ThemedHighlighter {
  code : @syntect.ByteIndex
  mut node : @syntax.LinkedNode
  highlighter : @syntect.Highlighter
  mut scopes : Array[@syntect.Scope]
  current_line : Array[Content]
  mut range : (Int, Int)
  mut line : Int
  style_fn : (Int, @syntax.LinkedNode, (Int, Int), @syntect.Style) -> Content
  line_fn : (Int, (Int, Int), Array[Content]) -> Unit
}

///|
fn ThemedHighlighter::new(
  code : @syntect.ByteIndex,
  top : @syntax.LinkedNode,
  highlighter : @syntect.Highlighter,
  style_fn : (Int, @syntax.LinkedNode, (Int, Int), @syntect.Style) -> Content,
  line_fn : (Int, (Int, Int), Array[Content]) -> Unit,
) -> ThemedHighlighter {
  {
    code,
    node: top,
    highlighter,
    range: (0, 0),
    scopes: [],
    current_line: [],
    line: 0,
    style_fn,
    line_fn,
  }
}

///|
fn ThemedHighlighter::highlight(self : ThemedHighlighter) -> Unit {
  self.highlight_inner()
  if !self.current_line.is_empty() {
    (self.line_fn)(
      self.line,
      (self.range.0, self.code.len()),
      self.current_line,
    )
    self.current_line.clear()
  }
}

///|
fn ThemedHighlighter::highlight_inner(self : ThemedHighlighter) -> Unit {
  if self.node.children().length() == 0 {
    let style = self.highlighter.style_for_stack(self.scopes[:])
    let (node_start, node_end) = self.node.range()
    let segment = self.code.slice(node_start, node_end)
    let mut len = 0
    for i, line in @syntax.split_newlines(segment) {
      if i != 0 {
        (self.line_fn)(
          self.line,
          (self.range.0, self.range.1 + len - 1),
          self.current_line,
        )
        self.range = (self.range.1 + len, self.range.1)
        self.line += 1
      }
      let offset = node_start + len
      let line_len = @syntect.utf8_len(line)
      let token_range = (offset, offset + line_len)
      self.current_line.push(
        (self.style_fn)(self.line, self.node, token_range, style),
      )
      len += line_len + 1
    }
    self.range = (self.range.0, self.range.1 + (node_end - node_start))
  }
  for child in self.node.children() {
    let mut scopes = self.scopes.copy()
    if @highlight.highlight(child) is Some(tag) {
      scopes.push(
        @syntect.Scope::new(tag.tm_scope()) catch {
          _ => abort("called `Result::unwrap()` on an `Err` value")
        },
      )
    }
    let saved = self.scopes
    self.scopes = scopes
    self.node = child
    self.highlight_inner()
    scopes = self.scopes
    self.scopes = saved
    ignore(scopes)
  }
}

///|
/// Splits the text into lines with their spans, aligning tabs (upstream
/// `preprocess`).
fn raw_preprocess(
  text : RawContent,
  styles : StyleChain,
  span : @syntax.Span,
) -> Array[(String, @syntax.Span)] {
  if text is Lines(lines) && lines.iter().all(l => !l.0.contains("\t")) {
    return lines.copy()
  }
  let mut text = text.get()
  if text.contains("\t") {
    let tab_size = RawElem::tab_size_in(styles).0.to_int()
    text = align_tabs(text, tab_size)
  }
  @syntax.split_newlines(text).map(line => (line, span))
}

///|
/// Replace tabs with spaces to align with multiples of `tab_size`.
fn align_tabs(text : String, tab_size : Int) -> String {
  let replacement = " ".repeat(tab_size)
  let divisor = if tab_size > 1 { tab_size } else { 1 }
  let res = StringBuilder()
  let mut column = 0
  for grapheme in @unicode.graphemes(text) {
    let single = grapheme.length() > 0 && grapheme.char_length() == 1
    if grapheme == "\t" {
      let required = tab_size - column % divisor
      res.write_string(replacement.unsafe_substring(start=0, end=required))
      column += required
    } else if (single && @syntax.is_newline(grapheme.get_char(0).unwrap())) ||
      grapheme == "\r\n" {
      res.write_view(grapheme)
      column = 0
    } else {
      res.write_view(grapheme)
      column += 1
    }
  }
  res.to_string()
}
