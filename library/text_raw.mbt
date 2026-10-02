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
/// The evaluator creates `Lines` for raw blocks upstream. Here, the element's
/// field stores the joined text (a `Value`), and the lines with their spans
/// are recovered from the raw syntax node the element was created from when
/// highlighting (see `RawElem::content`).
pub(all) enum RawContent {
  /// From a string.
  Text(String)
  /// From lines of text.
  Lines(Array[(String, @syntax.Span)])
} derive(Hash, Debug)

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
/// The raw content of the element: `Lines` with the spans of the raw
/// syntax node's lines if the element was created from raw syntax (as by
/// upstream's evaluator), otherwise the text.
fn RawElem::content(self : RawElem, engine : Engine) -> RawContent {
  let text = self.text()
  let span = self.0.span()
  guard span.id() is Some(id) else { return text }
  let source = engine.world.source(id) catch { _ => return text }
  guard @syntax.LinkedNode::new(source.root()).find(span) is Some(node) &&
    node.kind() == Raw &&
    (@ast.Raw::from_untyped(node.get()) : @ast.Raw?) is Some(raw) else {
    return text
  }
  let lines = raw.lines().map(line => (line.get(), line.span())).collect()
  let lines : RawContent = Lines(lines)
  if lines == text {
    lines
  } else {
    text
  }
}

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
  str_castable(v)
}

///|
pub impl IntoValue for RawContent with fn into_value(self) {
  Str(self.get())
}

///|
pub impl FromValue for RawContent with fn from_value(v) {
  Text(FromValue::from_value(v))
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
/// Highlights the raw text into lines (upstream `Packed<RawElem>::highlight`).
fn RawElem::highlight(
  self : RawElem,
  engine : Engine,
  styles : StyleChain,
) -> Array[RawLine] {
  let elem = self
  let routines = engine.routines()
  let lines = raw_preprocess(elem.content(engine), styles, elem.0.span())
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
      match RawTheme::derived(engine, source, elem.0.span()) {
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
    RawSyntax::find(engine, elem, styles, token) is Some((syntax_set, syntax)) {
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
}

///|
/// Decoded syntaxes, keyed by their bytes (upstream memoizes
/// `RawSyntax::decode`).
let raw_syntax_cache : Array[(Bytes, RawSyntax)] = []

///|
/// The derived syntaxes of data sources, recorded when the `syntaxes` field
/// is parsed (upstream stores them in the field as a `Derived`).
let raw_syntaxes_derived : Array[(Array[DataSource], Array[RawSyntax])] = []

///|
/// Load syntaxes from data sources (upstream returns a `Derived`).
fn RawSyntax::load(
  world : &World,
  sources : @syntax.Spanned[OneOrMultiple[DataSource]],
) -> Array[RawSyntax] raise SourceError {
  let loaded = load_many({ v: sources.v.0, span: sources.span, }, world)
  let list = loaded.map(data => within(data, () => RawSyntax::decode(data.data)))
  raw_syntaxes_derived.push((sources.v.0, list))
  list
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
  let syntax = { set: builder.build(), }
  raw_syntax_cache.push((bytes, syntax))
  syntax
}

///|
fn RawSyntax::get(self : RawSyntax) -> @syntect.SyntaxSet {
  self.set
}

///|
/// Finds the syntax for a language token, preferring user-provided syntaxes
/// over built-in ones.
fn RawSyntax::find(
  engine : Engine,
  elem : RawElem,
  styles : StyleChain,
  token : String,
) -> (@syntect.SyntaxSet, @syntect.SyntaxReference)? {
  let sources = elem.syntaxes(styles).0
  let derived = if sources.is_empty() {
    []
  } else {
    match raw_syntaxes_derived.iter().find_first(e => e.0 == sources) {
      Some(e) => e.1
      None =>
        RawSyntax::load(engine.world, {
          v: OneOrMultiple(sources),
          span: elem.0.span(),
        }) catch {
          _ => []
        }
    }
  }
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
}

///|
/// Decoded themes, keyed by their bytes (upstream memoizes
/// `RawTheme::decode`).
let raw_theme_cache : Array[(Bytes, RawTheme)] = []

///|
/// The derived themes of data sources, recorded when the `theme` field is
/// parsed (upstream stores them in the field as a `Derived`).
let raw_theme_derived : Array[(DataSource, RawTheme)] = []

///|
fn RawTheme::load(
  world : &World,
  source : @syntax.Spanned[DataSource],
) -> RawTheme raise SourceError {
  let loaded = source.v.load(source.span, world)
  let theme = within(loaded, () => RawTheme::decode(loaded.data))
  raw_theme_derived.push((source.v, theme))
  theme
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
  let theme = { theme, }
  raw_theme_cache.push((bytes, theme))
  theme
}

///|
/// The theme of a data source (upstream `theme.derived`).
fn RawTheme::derived(
  engine : Engine,
  source : DataSource,
  span : @syntax.Span,
) -> RawTheme? {
  match raw_theme_derived.iter().find_first(e => e.0 == source) {
    Some(e) => Some(e.1)
    None =>
      try RawTheme::load(engine.world, { v: source, span, }) catch {
        _ => None
      } noraise {
        theme => Some(theme)
      }
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
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let sources : @syntax.Spanned[OneOrMultiple[DataSource]]? = args.named_spanned(
    "syntaxes",
  )
  match sources {
    Some(sources) => {
      RawSyntax::load(engine.world, sources) |> ignore
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
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let theme : @syntax.Spanned[Smart[DataSource?]]? = args.named_spanned("theme")
  match theme {
    Some({ v: Custom(Some(source)), span, }) => {
      RawTheme::load(engine.world, { v: source, span, }) |> ignore
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
