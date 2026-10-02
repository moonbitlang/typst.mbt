// Port of the castable value types of `typst-library/src/text/raw.rs`
// (`RawContent`). Syntax highlighting, syntaxes and themes are not ported
// here.

///|
/// The content of the raw text.
///
/// Upstream also has a `Lines` variant (lines with their spans) created by
/// the evaluator for raw blocks; it is stored as its joined text here.
pub(all) enum RawContent {
  /// From a string.
  Text(String)
} derive(Eq, Hash, Debug)

///|
/// Returns or synthesizes the text content of the raw text.
pub fn RawContent::get(self : RawContent) -> String {
  match self {
    Text(text) => text
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
  _engine : Engine,
  content : Content,
  styles : StyleChain,
) -> Content raise SourceError {
  let elem = RawElem(content)
  elem.with_lines(elem.highlight(styles)).pack()
}

///|
/// Splits the raw text into lines (upstream `Packed<RawElem>::highlight`).
///
/// TODO: Syntax highlighting (syntect for most languages and Typst's own
/// highlighter for `typ`, `typc` and `typm`) is not ported yet, so all lines
/// are produced unhighlighted. For plain text (the default) and unknown
/// languages, this is exactly what upstream produces.
fn RawElem::highlight(self : RawElem, styles : StyleChain) -> Array[RawLine] {
  let lines = raw_preprocess(self.text(), styles, self.0.span())
  let count = lines.length().to_int64()
  lines.mapi((i, line) => {
    let (text, line_span) = line
    RawLine(
      RawLine::new(
        i.to_int64() + 1,
        count,
        text,
        TextElem::packed(text).spanned(line_span),
      )
      .pack()
      .spanned(line_span),
    )
  })
}

///|
/// Splits the text into lines with their spans, aligning tabs (upstream
/// `preprocess`).
fn raw_preprocess(
  text : RawContent,
  styles : StyleChain,
  span : @syntax.Span,
) -> Array[(String, @syntax.Span)] {
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
