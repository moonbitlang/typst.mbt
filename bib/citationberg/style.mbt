// Port of the data model of `citationberg/src/lib.rs` (0.7.0): CSL styles
// and locales. The XML deserialization lives in `de.mbt`.

///|
/// An independent CSL style.
pub(all) struct IndependentStyle {
  /// The style's metadata.
  info : StyleInfo
  /// The locale used if the user didn't specify one.
  default_locale : LocaleCode?
  /// The CSL version the style is compatible with.
  version : String
  /// How notes or in-text citations are displayed.
  citation : Citation
  /// How bibliographies are displayed.
  bibliography : Bibliography?
  /// The style's settings. Must be present in dependent styles.
  settings : IndependentStyleSettings
  /// Reusable formatting rules.
  macros : Array[CslMacro]
  /// Override localized strings.
  locale : Array[Locale]
} derive(Eq, Debug)

///|
/// A dependent CSL style.
pub(all) struct DependentStyle {
  /// The style's metadata.
  info : StyleInfo
  /// The locale used if the user didn't specify one.
  /// Overrides the default locale of the parent style.
  default_locale : LocaleCode?
  /// The CSL version the style is compatible with.
  version : String
  /// The link to the parent style.
  parent_link : InfoLink
} derive(Eq, Debug)

///|
/// A CSL style.
pub(all) enum Style {
  /// An independent style.
  Independent(IndependentStyle)
  /// A dependent style.
  Dependent(DependentStyle)
} derive(Eq, Debug)

///|
/// Get the style's metadata.
pub fn Style::info(self : Style) -> StyleInfo {
  match self {
    Independent(i) => i.info
    Dependent(d) => d.info
  }
}

///|
/// An error that occurred while validating a style.
pub(all) enum StyleValidationError {
  /// The CSL style did have a `cs:bibliography` child but not a
  /// `cs:citation`.
  MissingCitation
  /// A dependent style was missing the `independent-parent` link.
  MissingParent
  /// An independent style was missing the `class` attribute on `cs:style`
  MissingClassAttr
} derive(Eq, Debug)

///|
pub impl Show for StyleValidationError with output(self, logger) {
  logger.write_string(
    match self {
      MissingCitation => "root element is missing `cs:citation` child despite having a `cs:bibliography`"
      MissingParent => "`cs:link` tag with `independent-parent` as a `rel` attribute is missing but no `cs:citation` was defined"
      MissingClassAttr => "`cs:style` tag is missing the `class` attribute"
    },
  )
}

///|
/// A style with its own formatting rules.
pub(all) struct IndependentStyleSettings {
  /// How the citations are displayed.
  class : StyleClass
  /// Whether to use a hyphen when initializing a name.
  ///
  /// Defaults to `true`.
  initialize_with_hyphen : Bool
  /// Specifies how to reformat page ranges.
  page_range_format : PageRangeFormat?
  /// How to treat the non-dropping name particle when printing names.
  demote_non_dropping_particle : DemoteNonDroppingParticle
  /// Options for the names within. Only defined for dependent styles.
  options : InheritableNameOptions
} derive(Eq, Debug)

///|
/// An RFC 1766 language code.
pub(all) struct LocaleCode(String) derive(Eq, Hash, Debug)

///|
/// Get the US English locale.
pub fn LocaleCode::en_us() -> LocaleCode {
  LocaleCode("en-US")
}

///|
pub impl Show for LocaleCode with output(self, logger) {
  logger.write_string(self.0)
}

///|
/// The base language in a [`LocaleCode`].
pub(all) enum BaseLanguage {
  /// A language code.
  Iso639_1(String)
  /// An IANA language code.
  Iana(String)
  /// An unregistered / experimental language code.
  Unregistered(String)
} derive(Eq, Debug)

///|
/// Get the language code.
pub fn BaseLanguage::as_str(self : BaseLanguage) -> String {
  match self {
    Iso639_1(code) => code
    Iana(code) => code
    Unregistered(code) => code
  }
}

///|
/// Get the base language code.
pub fn LocaleCode::parse_base(self : LocaleCode) -> BaseLanguage? {
  let parts = @unscanny.split(self.0, "-")
  let first = parts[0]
  match first {
    "i" | "I" => {
      if parts.length() < 2 {
        return None
      }
      let second = parts[1]
      if second.is_empty() {
        return None
      }
      Some(Iana(second))
    }
    "x" | "X" => {
      if parts.length() < 2 {
        return None
      }
      let second = parts[1]
      let len = @unscanny.len_utf8(second)
      if len > 8 || len == 0 {
        return None
      }
      // Upstream stores the code zero-padded to 8 bytes.
      Some(Unregistered(second + String::make(8 - len, '\u{0}')))
    }
    _ if @unscanny.len_utf8(first) == 2 => Some(Iso639_1(first))
    _ => None
  }
}

///|
/// Get the language's extensions.
pub fn LocaleCode::extensions(self : LocaleCode) -> Array[String] {
  let out = []
  for i, e in @unscanny.split(self.0, "-") {
    if i == 0 && e is ("x" | "X" | "i" | "I") {
      continue
    }
    out.push(e)
  }
  // `.skip(1)` after the filter.
  if out.length() > 0 {
    out.remove(0) |> ignore
  }
  out
}

///|
/// Check whether the language is English.
pub fn LocaleCode::is_english(self : LocaleCode) -> Bool {
  self.0.has_prefix("en") && (self.0.length() == 2 || self.0[2:].has_prefix("-"))
}

///|
/// Get the fallback locale for a locale.
pub fn LocaleCode::fallback(self : LocaleCode) -> LocaleCode? {
  match self.parse_base() {
    Some(Iso639_1(code)) => {
      let f = match code {
        "af" => "af-ZA"
        "bg" => "bg-BG"
        "ca" => "ca-AD"
        "cs" => "cs-CZ"
        "da" => "da-DK"
        "de" => "de-DE"
        "el" => "el-GR"
        "en" => "en-US"
        "es" => "es-ES"
        "et" => "et-EE"
        "fa" => "fa-IR"
        "fi" => "fi-FI"
        "fr" => "fr-FR"
        "he" => "he-IL"
        "hr" => "hr-HR"
        "hu" => "hu-HU"
        "is" => "is-IS"
        "it" => "it-IT"
        "ja" => "ja-JP"
        "km" => "km-KH"
        "ko" => "ko-KR"
        "lt" => "lt-LT"
        "lv" => "lv-LV"
        "mn" => "mn-MN"
        "nb" => "nb-NO"
        "nl" => "nl-NL"
        "nn" => "nn-NO"
        "pl" => "pl-PL"
        "pt" => "pt-PT"
        "ro" => "ro-RO"
        "ru" => "ru-RU"
        "sk" => "sk-SK"
        "sl" => "sl-SI"
        "sr" => "sr-RS"
        "sv" => "sv-SE"
        "th" => "th-TH"
        "tr" => "tr-TR"
        "uk" => "uk-UA"
        "vi" => "vi-VN"
        "zh" => "zh-CN"
        _ => return None
      }
      if f == self.0 {
        None
      } else {
        Some(LocaleCode(f))
      }
    }
    _ => None
  }
}

///|
/// How the citations are displayed.
pub(all) enum StyleClass {
  /// Citations are inlined in the text.
  InText
  /// Citations are displayed in foot- or endnotes.
  Note
} derive(Eq, Hash, Debug)

///|
/// How to reformat page ranges.
pub(all) enum PageRangeFormat {
  /// “321–28”
  /// Aliases: `chicago` until CSL 1.1
  Chicago15
  /// “321–28”
  Chicago16
  /// “321–328”
  Expanded
  /// “321–8”
  Minimal
  /// “321–28”
  MinimalTwo
} derive(Eq, Hash, Debug)

///|
pub impl Default for PageRangeFormat with default() {
  Expanded
}

///|
/// Use a page range format to format a range of pages.
///
/// Closely follows the Haskell implementation of pandoc.
pub fn PageRangeFormat::format(
  self : PageRangeFormat,
  buf : StringBuilder,
  start : String,
  end : String,
  separator : String?,
) -> Unit {
  let separator = separator.unwrap_or("–")
  let start = @unscanny.trim(start)
  let end = @unscanny.trim(end)

  // Split into the maximal suffix that is all digits (`x`|`y`),
  // and the prefix.
  let (start_pre, x) = split_max_digit_suffix(start)
  let (end_pre, y) = split_max_digit_suffix(end)
  if start_pre == end_pre {
    let pref = start_pre
    let x_len = x.length()
    let y_len = y.length()
    // If `y` is shorter, it is a shorthand notation, e.g., `101-7`.
    let y = if x_len <= y_len { y } else { x[:x_len - y_len].to_owned() + y }

    // Write what stays the same early
    buf.write_string(pref + x + separator)
    match self {
      Chicago15 | Chicago16 if x_len < 3 || x.has_suffix("00") =>
        // For `x` < 100 or multiples of 100, write all digits.
        buf.write_string(y)
      Chicago15 | Chicago16 if x[x_len - 2:].has_prefix("0") =>
        // For 1 < `x` % 100 < 10, use changed part only.
        minimal(buf, 1, x, y)
      Chicago15 if x_len == 4 && changed_digits(x, y) >= 3 =>
        // If `x` has 4 digits and 3 change, write all digits.
        buf.write_string(y)
      Chicago15 | Chicago16 =>
        // Otherwise (for Chicago), write at least 2 digits.
        minimal(buf, 2, x, y)
      Expanded => buf.write_string(pref + y)
      Minimal => minimal(buf, 1, x, y)
      MinimalTwo => minimal(buf, 2, x, y)
    }
  } else {
    // Prefix is different, write entire range.
    buf.write_string(start + separator + end)
  }
}

///|
/// Calculates how many digits are different between `x` and `y`, starting
/// from the back.
///
/// Returns as soon as two digits differ.
fn changed_digits(x : String, y : String) -> Int {
  let x = if x.length() < y.length() {
    String::make(y.length() - x.length(), ' ') + x
  } else {
    x
  }
  let xs = @unscanny.chars(x).rev()
  let ys = @unscanny.chars(y).rev()
  let n = if xs.length() < ys.length() { xs.length() } else { ys.length() }
  for i in 0..<n {
    if xs[i] == ys[i] {
      return i
    }
  }
  x.length()
}

///|
/// Writes the minimal digits that have changed from `x` to `y`---but at
/// minimum `thresh` digits---to `buf`.
fn minimal(buf : StringBuilder, thresh : Int, x : String, y : String) -> Unit {
  if y.length() > x.length() {
    // y is no abbrev. write it
    buf.write_string(y)
    return
  }
  let xc = @unscanny.chars(x)
  let yc = @unscanny.chars(y)
  let n = if xc.length() < yc.length() { xc.length() } else { yc.length() }
  let ys = StringBuilder()
  let mut skipping = true
  for i in 0..<n {
    if skipping && xc[i] == yc[i] {
      continue
    }
    skipping = false
    ys.write_char(yc[i])
  }
  let ys = ys.to_string()
  if ys.length() < thresh && y.length() >= thresh {
    buf.write_string(y[y.length() - thresh:].to_owned())
  } else {
    buf.write_string(ys)
  }
}

///|
/// Split `s` into the maximal suffix that is only digits and a prefix.
fn split_max_digit_suffix(s : String) -> (String, String) {
  let mut idx = s.length()
  while idx > 0 && s.code_unit_at(idx - 1).to_int() >= '0'.to_int() &&
        s.code_unit_at(idx - 1).to_int() <= '9'.to_int() {
    idx -= 1
  }
  (s[:idx].to_owned(), s[idx:].to_owned())
}

///|
/// How to treat the non-dropping name particle when printing names.
pub(all) enum DemoteNonDroppingParticle {
  /// Treat as part of the first name.
  Never
  /// Treat as part of the first name except when sorting.
  SortOnly
  /// Treat as part of the family name.
  DisplayAndSort
} derive(Eq, Hash, Debug)

///|
/// Citation style metadata
pub(all) struct StyleInfo {
  /// The authors of the style
  authors : Array[StyleAttribution]
  /// Contributors to the style
  contributors : Array[StyleAttribution]
  /// Which format the citations are in.
  category : Array[StyleCategory]
  /// Which academic field the style is used in.
  field : Array[Field]
  /// A unique identifier for the style. May be a URL or an UUID.
  id : String
  /// The ISSN for the source of the style's publication.
  issn : Array[String]
  /// The eISSN for the source of the style's publication.
  eissn : String?
  /// The ISSN-L for the source of the style's publication.
  issnl : String?
  /// Links with more information about the style.
  link : Array[InfoLink]
  /// When the style was initially published.
  published : Timestamp?
  /// Under which license the style is published.
  rights : License?
  /// A short description of the style.
  summary : LocalString?
  /// The title of the style.
  title : LocalString
  /// A shortened version of the title.
  title_short : LocalString?
  /// When the style was last updated.
  updated : Timestamp?
} derive(Eq, Debug)

///|
/// A string annotated with a locale.
pub(all) struct LocalString {
  /// The string's locale.
  lang : LocaleCode?
  /// The string's value.
  value : String
} derive(Eq, Debug)

///|
/// A person affiliated with the style.
pub(all) struct StyleAttribution {
  /// The person's name.
  name : String
  /// The person's email address.
  email : String?
  /// A URI for the person.
  uri : String?
} derive(Eq, Debug)

///|
/// Which category this style belongs in.
pub(all) enum StyleCategory {
  /// Which format the citations are in. May only appear once as a child of
  /// `category`.
  CitationFormat(CitationFormat)
  /// Which academic field the style is used in. May appear multiple times as
  /// a child of `category`.
  Field(Field)
} derive(Eq, Debug)

///|
/// What type of in-text citation is used.
pub(all) enum CitationFormat {
  /// “… (Doe, 1999)”
  AuthorDate
  /// “… (Doe)”
  Author
  /// “… \[1\]”
  Numeric
  /// “… \[doe99\]”
  Label
  /// The citation appears as a foot- or endnote.
  Note
} derive(Eq, Hash, Debug)

///|
/// In which academic field the style is used.
pub(all) enum Field {
  Anthropology
  Astronomy
  Biology
  Botany
  Chemistry
  Communications
  Engineering
  /// Used for generic styles like Harvard and APA.
  GenericBase
  Geography
  Geology
  History
  Humanities
  Law
  Linguistics
  Literature
  Math
  Medicine
  Philosophy
  Physics
  PoliticalScience
  Psychology
  Science
  SocialScience
  Sociology
  Theology
  Zoology
} derive(Eq, Hash, Debug)

///|
/// A link with more information about the style.
pub(all) struct InfoLink {
  /// The link's URL.
  href : String
  /// How the link relates to the style.
  rel : InfoLinkRel
  /// A human-readable description of the link.
  description : String?
  /// The link's locale.
  locale : LocaleCode?
} derive(Eq, Debug)

///|
/// How a link relates to the style.
pub(all) enum InfoLinkRel {
  /// Website of the style.
  Zelf
  /// URL from which the style is derived. Must not appear in dependent
  /// styles.
  Template
  /// URL of the style's documentation.
  Documentation
  /// Parent of a dependent style. Must appear in dependent styles.
  IndependentParent
} derive(Eq, Hash, Debug)

///|
/// An ISO 8601 chapter 5.4 timestamp.
pub(all) struct Timestamp {
  /// The timestamp's value.
  raw : String
} derive(Eq, Debug)

///|
/// A license description.
pub(all) struct License {
  /// The license's name.
  name : String
  /// The license's URL.
  license : String?
  /// The license string's locale.
  lang : LocaleCode?
} derive(Eq, Debug)

///|
/// Formatting instructions for in-text or note citations.
pub(all) struct Citation {
  /// How items are sorted within the citation.
  sort : Sort?
  /// The citation's formatting rules.
  layout : Layout
  /// Expand names that are ambiguous in short form.
  ///
  /// Default: `false`
  disambiguate_add_givenname : Bool
  /// When to expand names that are ambiguous in short form.
  givenname_disambiguation_rule : DisambiguationRule
  /// Disambiguate by adding more names that would otherwise be hidden by et
  /// al.
  ///
  /// Default: `false`
  disambiguate_add_names : Bool
  /// Disambiguate by adding an alphabetical suffix to the year.
  ///
  /// Default: `false`
  disambiguate_add_year_suffix : Bool
  /// Group items in cite by name.
  cite_group_delimiter : String?
  /// How to collapse cites with similar items.
  collapse : Collapse?
  /// Delimiter between year suffixes.
  year_suffix_delimiter : String?
  /// Delimiter after a collapsed cite group.
  after_collapse_delimiter : String?
  /// When near-note-distance is true.
  ///
  /// Default: `5`
  near_note_distance : Int
  /// Options for the names within.
  name_options : InheritableNameOptions
} derive(Eq, Debug)

///|
/// Return the default value for `cite_group_delimiter` if implicitly needed
/// due to presence of a `collapse` attribute.
pub let citation_default_cite_group_delimiter : String = ", "

///|
/// Return a citation with default settings and the given layout.
pub fn Citation::with_layout(layout : Layout) -> Citation {
  {
    sort: None,
    layout,
    disambiguate_add_givenname: false,
    givenname_disambiguation_rule: ByCite,
    disambiguate_add_names: false,
    disambiguate_add_year_suffix: false,
    cite_group_delimiter: None,
    collapse: None,
    year_suffix_delimiter: None,
    after_collapse_delimiter: None,
    near_note_distance: 5,
    name_options: InheritableNameOptions::default(),
  }
}

///|
/// Return the `year_suffix_delimiter`.
pub fn Citation::get_year_suffix_delimiter(self : Citation) -> String {
  match self.year_suffix_delimiter {
    Some(d) => d
    None => self.layout.delimiter.unwrap_or("")
  }
}

///|
/// Return the `after_collapse_delimiter`.
pub fn Citation::get_after_collapse_delimiter(self : Citation) -> String {
  match self.after_collapse_delimiter {
    Some(d) => d
    None => self.layout.delimiter.unwrap_or("")
  }
}

///|
/// When to expand names that are ambiguous in short form.
pub(all) enum DisambiguationRule {
  /// Expand to disambiguate both cites and names.
  AllNames
  /// Expand to disambiguate cites and names but only use initials.
  AllNamesWithInitials
  /// Same as `AllNames` but only disambiguate the first person in a
  /// citation.
  PrimaryName
  /// Same as `AllNamesWithInitials` but only disambiguate the first person
  /// in a citation.
  PrimaryNameWithInitials
  /// Expand to disambiguate cites but not names.
  ByCite
} derive(Eq, Hash, Debug)

///|
/// Whether this rule allows full first names or only initials.
pub fn DisambiguationRule::allows_full_first_names(
  self : DisambiguationRule,
) -> Bool {
  self is (AllNames | PrimaryName | ByCite)
}

///|
/// Whether this rule allows looking beyond the first name.
pub fn DisambiguationRule::allows_multiple_names(
  self : DisambiguationRule,
) -> Bool {
  self is (AllNames | AllNamesWithInitials | ByCite)
}

///|
/// How to collapse cites with similar items.
pub(all) enum Collapse {
  /// Collapse items with increasing ranges for numeric styles.
  CitationNumber
  /// Collapse items with the same authors and different years by omitting
  /// the author.
  Year
  /// Same as `Year`, but equal years are omitted as well.
  YearSuffix
  /// Same as `YearSuffix`, but also collapse the suffixes into a range.
  YearSuffixRanged
} derive(Eq, Hash, Debug)

///|
/// Formatting instructions for the bibliography.
pub(all) struct Bibliography {
  /// How items are sorted within the citation.
  sort : Sort?
  /// The citation's formatting rules.
  layout : Layout
  /// Render the bibliography in a hanging indent.
  ///
  /// Default: `false`
  hanging_indent : Bool
  /// When set, the second field is aligned.
  second_field_align : SecondFieldAlign?
  /// The line spacing within the bibliography as a multiple of regular line
  /// spacing.
  line_spacing : Int
  /// Extra space between entries as a multiple of line height.
  entry_spacing : Int
  /// When set, subsequent identical names are replaced with this.
  subsequent_author_substitute : String?
  /// How to replace subsequent identical names.
  subsequent_author_substitute_rule : SubsequentAuthorSubstituteRule
  /// Options for the names within.
  name_options : InheritableNameOptions
} derive(Eq, Debug)

///|
/// Return a bibliography with default settings and the given layout.
pub fn Bibliography::with_layout(layout : Layout) -> Bibliography {
  {
    sort: None,
    layout,
    hanging_indent: false,
    second_field_align: None,
    line_spacing: 1,
    entry_spacing: 1,
    subsequent_author_substitute: None,
    subsequent_author_substitute_rule: CompleteAll,
    name_options: InheritableNameOptions::default(),
  }
}

///|
/// How to position the first field if the second field is aligned in a
/// bibliography.
pub(all) enum SecondFieldAlign {
  /// Put the first field in the margin and align with the margin.
  Margin
  /// Flush the first field with the margin.
  Flush
} derive(Eq, Hash, Debug)

///|
/// How to replace subsequent identical names in a bibliography.
pub(all) enum SubsequentAuthorSubstituteRule {
  /// When all names match, replace.
  CompleteAll
  /// When all names match, replace each name.
  CompleteEach
  /// Each matching name is replaced.
  PartialEach
  /// Only the first matching name is replaced.
  PartialFirst
} derive(Eq, Hash, Debug)

///|
/// How to sort elements in a bibliography or citation.
pub(all) struct Sort {
  /// The ordered list of sorting keys.
  keys : Array[SortKey]
} derive(Eq, Debug)

///|
/// A sorting key.
pub(all) enum SortKey {
  /// Sort by the value of a variable.
  Variable(variable~ : Variable, sort_direction~ : SortDirection)
  /// Sort by the output of a macro.
  MacroName(
    name~ : String,
    names_min~ : Int?,
    names_use_first~ : Int?,
    names_use_last~ : Bool?,
    sort_direction~ : SortDirection
  )
} derive(Eq, Debug)

///|
/// Retrieve the sort direction.
pub fn SortKey::sort_direction(self : SortKey) -> SortDirection {
  match self {
    Variable(sort_direction~, ..) => sort_direction
    MacroName(sort_direction~, ..) => sort_direction
  }
}

///|
/// The direction to sort in.
pub(all) enum SortDirection {
  /// Sort in ascending order.
  Ascending
  /// Sort in descending order.
  Descending
} derive(Eq, Hash, Debug)

///|
/// A formatting rule.
pub(all) struct Layout {
  /// Parts of the rule.
  elements : Array[LayoutRenderingElement]
  /// Set the font style.
  font_style : FontStyle?
  /// Choose normal or small caps.
  font_variant : FontVariant?
  /// Set the font weight.
  font_weight : FontWeight?
  /// Choose underlining.
  text_decoration : TextDecoration?
  /// Choose vertical alignment.
  vertical_align : VerticalAlign?
  /// The prefix.
  prefix : String?
  /// The suffix.
  suffix : String?
  /// Delimit pieces of the output.
  delimiter : String?
} derive(Eq, Debug)

///|
/// Return a layout.
pub fn Layout::new(
  elements : Array[LayoutRenderingElement],
  formatting : Formatting,
  affixes : Affixes?,
  delimiter : String?,
) -> Layout {
  let (prefix, suffix) = match affixes {
    Some(affixes) => (affixes.prefix, affixes.suffix)
    None => (None, None)
  }
  {
    elements,
    font_style: formatting.font_style,
    font_variant: formatting.font_variant,
    font_weight: formatting.font_weight,
    text_decoration: formatting.text_decoration,
    vertical_align: formatting.vertical_align,
    prefix,
    suffix,
    delimiter,
  }
}

///|
/// Return a layout with default settings and the given elements.
pub fn Layout::with_elements(elements : Array[LayoutRenderingElement]) -> Layout {
  Layout::new(elements, Formatting::default(), None, None)
}

///|
/// Obtain a `Formatting`.
pub fn Layout::to_formatting(self : Layout) -> Formatting {
  {
    font_style: self.font_style,
    font_variant: self.font_variant,
    font_weight: self.font_weight,
    text_decoration: self.text_decoration,
    vertical_align: self.vertical_align,
  }
}

///|
/// Obtain the `Affixes`.
pub fn Layout::to_affixes(self : Layout) -> Affixes {
  { prefix: self.prefix, suffix: self.suffix }
}

///|
/// Find the child element that will render the given variable.
pub fn Layout::find_variable_element(
  self : Layout,
  variable : Variable,
  macros : Array[CslMacro],
) -> LayoutRenderingElement? {
  for e in self.elements {
    if e.find_variable_element(variable, macros) is Some(r) {
      return Some(r)
    }
  }
  None
}

///|
/// Possible parts of a formatting rule.
pub(all) enum LayoutRenderingElement {
  /// Insert a term or variable.
  Text(Text)
  /// Format a date.
  Date(Date)
  /// Format a number.
  Number(Number)
  /// Format a list of names.
  Names(Names)
  /// Prints a label for a variable.
  Label(Label)
  /// Container for rendering elements.
  Group(Group)
  /// Conditional rendering.
  Choose(Choose)
} derive(Eq, Debug)

///|
/// Find the child element that will render the given variable.
pub fn LayoutRenderingElement::find_variable_element(
  self : LayoutRenderingElement,
  variable : Variable,
  macros : Array[CslMacro],
) -> LayoutRenderingElement? {
  match self {
    Text(t) => t.find_variable_element(variable, macros)
    Choose(c) => c.find_variable_element(variable, macros)
    Date(d) =>
      match d.variable {
        Some(v) if Variable::Date(v) == variable => Some(self)
        _ => None
      }
    Number(n) =>
      if n.variable.to_variable() == variable {
        Some(self)
      } else {
        None
      }
    Names(n) =>
      if n.variable.iter().any(v => Variable::Name(v) == variable) {
        Some(self)
      } else {
        None
      }
    Group(g) => {
      for e in g.children {
        if e.find_variable_element(variable, macros) is Some(r) {
          return Some(r)
        }
      }
      None
    }
    Label(_) => None
  }
}

///|
/// Rendering elements.
pub(all) enum RenderingElement {
  /// A layout element.
  Layout(Layout)
  /// Other rendering elements.
  Other(LayoutRenderingElement)
} derive(Eq, Debug)

///|
/// Print a term or variable.
pub(all) struct Text {
  /// The term or variable to print.
  target : TextTarget
  /// Override formatting style.
  formatting : Formatting
  /// Add prefix and suffix.
  affixes : Affixes
  /// Set layout level.
  display : Display?
  /// Whether to wrap this text in quotes.
  ///
  /// Default: `false`
  quotes : Bool
  /// Remove periods from the output.
  ///
  /// Default: `false`
  strip_periods : Bool
  /// Transform the text case.
  text_case : TextCase?
} derive(Eq, Debug)

///|
/// Return a text with default settings and the given target.
pub fn Text::with_target(target : TextTarget) -> Text {
  {
    target,
    formatting: Formatting::default(),
    affixes: Affixes::default(),
    display: None,
    quotes: false,
    strip_periods: false,
    text_case: None,
  }
}

///|
/// Find the child element that will render the given variable.
pub fn Text::find_variable_element(
  self : Text,
  variable : Variable,
  macros : Array[CslMacro],
) -> LayoutRenderingElement? {
  match self.target {
    Variable(var_~, ..) =>
      if var_ == variable {
        Some(Text(self))
      } else {
        None
      }
    Macro(name~) => {
      for m in macros {
        if m.name == name {
          for e in m.children {
            if e.find_variable_element(variable, macros) is Some(r) {
              return Some(r)
            }
          }
          return None
        }
      }
      None
    }
    Term(..) => None
    Value(..) => None
  }
}

///|
/// Various kinds of text targets.
pub(all) enum TextTarget {
  /// Prints the value of a variable.
  Variable(var_~ : Variable, form~ : LongShortForm)
  /// Prints the text output of a macro.
  Macro(name~ : String)
  /// Prints a localized term.
  Term(term~ : Term, form~ : TermForm, plural~ : Bool)
  /// Prints a given string.
  Value(val~ : String)
} derive(Eq, Debug)

///|
/// Formats a date.
pub(all) struct Date {
  /// The date to format.
  variable : DateVariable?
  /// How the localized date should be formatted.
  form : DateForm?
  /// Which parts of the localized date should be included.
  parts : DateParts?
  /// Override the default date parts. Also specifies the order of the parts
  /// if `form` is `None`.
  date_part : Array[DatePart]
  /// Override formatting style.
  formatting : Formatting
  /// Add prefix and suffix. Ignored when this defines a localized date
  /// format.
  affixes : Affixes
  /// Delimit pieces of the output. Ignored when this defines a localized
  /// date format.
  delimiter : String?
  /// Set layout level.
  display : Display?
  /// Transform the text case.
  text_case : TextCase?
} derive(Eq, Debug)

///|
/// Whether this is a localized or a standalone date.
pub fn Date::is_localized(self : Date) -> Bool {
  self.form is Some(_)
}

///|
/// Localized date formats.
pub(all) enum DateForm {
  /// “12-15-2005”
  Numeric
  /// “December 15, 2005”
  Text
} derive(Eq, Hash, Debug)

///|
/// Which parts of a date should be included.
pub(all) enum DateParts {
  Year
  YearMonth
  YearMonthDay
} derive(Eq, Hash, Debug)

///|
pub impl Default for DateParts with default() {
  YearMonthDay
}

///|
/// Check if the date shall contain a month.
pub fn DateParts::has_month(self : DateParts) -> Bool {
  self is (YearMonth | YearMonthDay)
}

///|
/// Check if the date shall contain a day.
pub fn DateParts::has_day(self : DateParts) -> Bool {
  self is YearMonthDay
}

///|
/// Override the default date parts.
pub(all) struct DatePart {
  /// Kind of the date part.
  name : DatePartName
  /// Form of the date part.
  form_ : DateAnyForm?
  /// The string used to delimit two date parts.
  range_delimiter : String?
  /// Override formatting style.
  formatting : Formatting
  /// Add prefix and suffix. Ignored when this defines a localized date
  /// format.
  affixes : Affixes
  /// Remove periods from the date part.
  ///
  /// Default: `false`
  strip_periods : Bool
  /// Transform the text case.
  text_case : TextCase?
} derive(Eq, Debug)

///|
/// Retrieve the default delimiter for the date part.
pub let date_part_default_delimiter : String = "–"

///|
/// Retrieve the form.
pub fn DatePart::form(self : DatePart) -> DateStrongAnyForm {
  DateStrongAnyForm::for_name(self.name, self.form_)
}

///|
/// The kind of a date part with its `form` attribute.
pub(all) enum DatePartName {
  Day
  Month
  Year
} derive(Eq, Hash, Debug)

///|
/// Any allowable date part format.
pub(all) enum DateAnyForm {
  /// “1”
  Numeric
  /// “01”
  NumericLeadingZeros
  /// “1st”
  Ordinal
  /// “January”
  Long
  /// “Jan.”
  Short
} derive(Eq, Hash, Debug)

///|
/// Strongly typed date part formats.
pub(all) enum DateStrongAnyForm {
  Day(DateDayForm)
  Month(DateMonthForm)
  Year(LongShortForm)
} derive(Eq, Hash, Debug)

///|
/// Get a strongly typed date form for a name. Must return `Some` for valid
/// CSL files.
pub fn DateStrongAnyForm::for_name(
  name : DatePartName,
  form : DateAnyForm?,
) -> DateStrongAnyForm {
  match name {
    Day => Day(form.map(f => f.form_for_day()).unwrap_or(DateDayForm::Numeric))
    Month =>
      Month(form.map(f => f.form_for_month()).unwrap_or(DateMonthForm::Long))
    Year => Year(form.map(f => f.form_for_year()).unwrap_or(LongShortForm::Long))
  }
}

///|
/// Retrieve the form for a day.
pub fn DateAnyForm::form_for_day(self : DateAnyForm) -> DateDayForm {
  match self {
    NumericLeadingZeros => NumericLeadingZeros
    Ordinal => Ordinal
    _ => Numeric
  }
}

///|
/// Retrieve the form for a month.
pub fn DateAnyForm::form_for_month(self : DateAnyForm) -> DateMonthForm {
  match self {
    Short => Short
    Numeric => Numeric
    NumericLeadingZeros => NumericLeadingZeros
    _ => Long
  }
}

///|
/// Retrieve the form for a year.
pub fn DateAnyForm::form_for_year(self : DateAnyForm) -> LongShortForm {
  match self {
    Short => Short
    _ => Long
  }
}

///|
/// How a day is formatted.
pub(all) enum DateDayForm {
  /// “1”
  Numeric
  /// “01”
  NumericLeadingZeros
  /// “1st”
  Ordinal
} derive(Eq, Hash, Debug)

///|
/// How a month is formatted.
pub(all) enum DateMonthForm {
  /// “January”
  Long
  /// “Jan.”
  Short
  /// “1”
  Numeric
  /// “01”
  NumericLeadingZeros
} derive(Eq, Hash, Debug)

///|
/// Whether to format something in long or short form.
pub(all) enum LongShortForm {
  Long
  Short
} derive(Eq, Hash, Debug)

///|
/// Renders a number.
pub(all) struct Number {
  /// The variable whose value is used.
  variable : NumberOrPageVariable
  /// How the number is formatted.
  form : NumberForm
  /// Override formatting style.
  formatting : Formatting
  /// Add prefix and suffix.
  affixes : Affixes
  /// Set layout level.
  display : Display?
  /// Transform the text case.
  text_case : TextCase?
} derive(Eq, Debug)

///|
/// How a number is formatted.
pub(all) enum NumberForm {
  /// “1”
  Numeric
  /// “1st”
  Ordinal
  /// “first”
  LongOrdinal
  /// “I”
  Roman
} derive(Eq, Hash, Debug)

///|
/// Renders a list of names.
pub(all) struct Names {
  /// The variable whose value is used.
  variable : Array[NameVariable]
  /// Child elements.
  children : Array[NamesChild]
  /// Delimiter between names.
  delimiter_ : String?
  /// Delimiter between second-to-last and last name.
  and_ : NameAnd?
  /// Delimiter before et al.
  delimiter_precedes_et_al : DelimiterBehavior?
  /// Whether to use the delimiter before the last name.
  delimiter_precedes_last : DelimiterBehavior?
  /// Minimum number of names to use et al.
  et_al_min : Int?
  /// Maximum number of names to use before et al.
  et_al_use_first : Int?
  /// Minimum number of names to use et al. for repeated citations.
  et_al_subsequent_min : Int?
  /// Maximum number of names to use before et al. for repeated citations.
  et_al_subsequent_use_first : Int?
  /// Whether to use the last name in the author list when there are at
  /// least `et_al_min` names.
  et_al_use_last : Bool?
  /// Which name parts to display for personal names.
  name_form : NameForm?
  /// Whether to initialize the first name if `initialize-with` is Some.
  initialize : Bool?
  /// String to initialize the first name with.
  initialize_with : String?
  /// Whether to turn the name around.
  name_as_sort_order : NameAsSortOrder?
  /// Delimiter between given name and first name. Only used if
  /// `name-as-sort-order` is Some.
  sort_separator : String?
  /// Set the font style.
  font_style : FontStyle?
  /// Choose normal or small caps.
  font_variant : FontVariant?
  /// Set the font weight.
  font_weight : FontWeight?
  /// Choose underlining.
  text_decoration : TextDecoration?
  /// Choose vertical alignment.
  vertical_align : VerticalAlign?
  /// The prefix.
  prefix : String?
  /// The suffix.
  suffix : String?
  /// Set layout level.
  display : Display?
} derive(Eq, Debug)

///|
/// Return names with default settings and the given variables.
pub fn Names::with_variables(variables : Array[NameVariable]) -> Names {
  {
    variable: variables,
    children: [],
    delimiter_: None,
    and_: None,
    delimiter_precedes_et_al: None,
    delimiter_precedes_last: None,
    et_al_min: None,
    et_al_use_first: None,
    et_al_subsequent_min: None,
    et_al_subsequent_use_first: None,
    et_al_use_last: None,
    name_form: None,
    initialize: None,
    initialize_with: None,
    name_as_sort_order: None,
    sort_separator: None,
    font_style: None,
    font_variant: None,
    font_weight: None,
    text_decoration: None,
    vertical_align: None,
    prefix: None,
    suffix: None,
    display: None,
  }
}

///|
/// Return the delimiter given some name options.
pub fn Names::delimiter(
  self : Names,
  name_options : InheritableNameOptions,
) -> String {
  match self.delimiter_ {
    Some(d) => d
    None => name_options.name_delimiter.unwrap_or("")
  }
}

///|
/// Return the name element.
pub fn Names::name(self : Names) -> Name? {
  for c in self.children {
    if c is Name(n) {
      return Some(n)
    }
  }
  None
}

///|
/// Return the et-al element.
pub fn Names::et_al(self : Names) -> EtAl? {
  for c in self.children {
    if c is EtAl(e) {
      return Some(e)
    }
  }
  None
}

///|
/// Return the label element.
pub fn Names::label(self : Names) -> (VariablelessLabel, NameLabelPosition)? {
  let mut pos = NameLabelPosition::BeforeName
  for c in self.children {
    match c {
      Label(l) => return Some((l, pos))
      Name(_) => pos = AfterName
      _ => ()
    }
  }
  None
}

///|
/// Return the substitute element.
pub fn Names::substitute(self : Names) -> Substitute? {
  for c in self.children {
    if c is Substitute(s) {
      return Some(s)
    }
  }
  None
}

///|
/// Return the inheritable name options.
pub fn Names::options(self : Names) -> InheritableNameOptions {
  {
    and_: self.and_,
    delimiter_precedes_et_al: self.delimiter_precedes_et_al,
    delimiter_precedes_last: self.delimiter_precedes_last,
    et_al_min: self.et_al_min,
    et_al_use_first: self.et_al_use_first,
    et_al_subsequent_min: self.et_al_subsequent_min,
    et_al_subsequent_use_first: self.et_al_subsequent_use_first,
    et_al_use_last: self.et_al_use_last,
    name_form: self.name_form,
    initialize: self.initialize,
    initialize_with: self.initialize_with,
    name_as_sort_order: self.name_as_sort_order,
    sort_separator: self.sort_separator,
    name_delimiter: None,
    names_delimiter: self.delimiter_,
  }
}

///|
/// Obtain a `Formatting`.
pub fn Names::to_formatting(self : Names) -> Formatting {
  {
    font_style: self.font_style,
    font_variant: self.font_variant,
    font_weight: self.font_weight,
    text_decoration: self.text_decoration,
    vertical_align: self.vertical_align,
  }
}

///|
/// Obtain the `Affixes`.
pub fn Names::to_affixes(self : Names) -> Affixes {
  { prefix: self.prefix, suffix: self.suffix }
}

///|
fn[T] or_opt(a : T?, b : T?) -> T? {
  match a {
    Some(_) => a
    None => b
  }
}

///|
/// Convert a [`Names`] within a substitute to a name using the parent
/// element.
pub fn Names::from_names_substitute(self : Names, child : Names) -> Names {
  if child.name() is Some(_) ||
    child.et_al() is Some(_) ||
    child.substitute() is Some(_) {
    return child
  }
  let formatting = child.to_formatting().apply(self.to_formatting())
  let options = self.options().apply(child.options())
  {
    variable: if child.variable.is_empty() {
      self.variable
    } else {
      child.variable
    },
    children: self.children.filter(c => !(c is Substitute(_))),
    delimiter_: or_opt(child.delimiter_, self.delimiter_),
    and_: options.and_,
    delimiter_precedes_et_al: options.delimiter_precedes_et_al,
    delimiter_precedes_last: options.delimiter_precedes_last,
    et_al_min: options.et_al_min,
    et_al_use_first: options.et_al_use_first,
    et_al_subsequent_min: options.et_al_subsequent_min,
    et_al_subsequent_use_first: options.et_al_subsequent_use_first,
    et_al_use_last: options.et_al_use_last,
    name_form: options.name_form,
    initialize: options.initialize,
    initialize_with: options.initialize_with,
    name_as_sort_order: options.name_as_sort_order,
    sort_separator: options.sort_separator,
    font_style: formatting.font_style,
    font_variant: formatting.font_variant,
    font_weight: formatting.font_weight,
    text_decoration: formatting.text_decoration,
    vertical_align: formatting.vertical_align,
    prefix: or_opt(child.prefix, self.prefix),
    suffix: or_opt(child.suffix, self.suffix),
    display: or_opt(child.display, self.display),
  }
}

///|
/// Where the `cs:label` element within a `cs:names` element appeared
/// relative to `cs:name`.
pub(all) enum NameLabelPosition {
  /// The label appeared after the name element.
  AfterName
  /// The label appeared before the name element.
  BeforeName
} derive(Eq, Hash, Debug)

///|
/// Possible children for a `cs:names` element.
pub(all) enum NamesChild {
  /// A `cs:name` element.
  Name(Name)
  /// A `cs:et-al` element.
  EtAl(EtAl)
  /// A `cs:label` element.
  Label(VariablelessLabel)
  /// A `cs:substitute` element.
  Substitute(Substitute)
} derive(Eq, Debug)

///|
/// Configuration of how to print names.
pub(all) struct Name {
  /// Delimiter between names.
  delimiter : String?
  /// Which name parts to display for personal names.
  form : NameForm?
  /// Name parts for formatting for the given and family name.
  parts : Array[NamePart]
  /// Options for this name.
  options_ : InheritableNameOptions
  /// Override formatting style.
  formatting : Formatting
  /// Add prefix and suffix.
  affixes : Affixes
} derive(Eq, Debug)

///|
pub impl Default for Name with default() {
  {
    delimiter: None,
    form: None,
    parts: [],
    options_: InheritableNameOptions::default(),
    formatting: Formatting::default(),
    affixes: Affixes::default(),
  }
}

///|
/// Retrieve [`NamePart`] configuration for the given name.
pub fn Name::name_part_given(self : Name) -> NamePart? {
  for p in self.parts {
    if p.name == Given {
      return Some(p)
    }
  }
  None
}

///|
/// Retrieve [`NamePart`] configuration for the family name.
pub fn Name::name_part_family(self : Name) -> NamePart? {
  for p in self.parts {
    if p.name == Family {
      return Some(p)
    }
  }
  None
}

///|
/// Retrieve the [`NameOptions`] for this name.
pub fn Name::options(self : Name, inherited : InheritableNameOptions) -> NameOptions {
  let applied = inherited.apply(self.options_)
  {
    and_: applied.and_,
    delimiter: match self.delimiter {
      Some(d) => d
      None => inherited.name_delimiter.unwrap_or(", ")
    },
    delimiter_precedes_et_al: applied.delimiter_precedes_et_al.unwrap_or(
      Contextual,
    ),
    delimiter_precedes_last: applied.delimiter_precedes_last.unwrap_or(
      Contextual,
    ),
    et_al_min: applied.et_al_min,
    et_al_use_first: applied.et_al_use_first,
    et_al_subsequent_min: applied.et_al_subsequent_min,
    et_al_subsequent_use_first: applied.et_al_subsequent_use_first,
    et_al_use_last: applied.et_al_use_last.unwrap_or(false),
    form: or_opt(self.form, inherited.name_form).unwrap_or(Long),
    initialize: applied.initialize.unwrap_or(true),
    initialize_with: or_opt(
      self.options_.initialize_with,
      inherited.initialize_with,
    ),
    name_as_sort_order: applied.name_as_sort_order,
    sort_separator: match self.options_.sort_separator {
      Some(s) => s
      None => inherited.sort_separator.unwrap_or(", ")
    },
  }
}

///|
/// Global configuration of how to print names.
pub(all) struct InheritableNameOptions {
  /// Delimiter between second-to-last and last name.
  and_ : NameAnd?
  /// Delimiter inherited to `cs:name` elements.
  name_delimiter : String?
  /// Delimiter inherited to `cs:names` elements.
  names_delimiter : String?
  /// Delimiter before et al.
  delimiter_precedes_et_al : DelimiterBehavior?
  /// Whether to use the delimiter before the last name.
  delimiter_precedes_last : DelimiterBehavior?
  /// Minimum number of names to use et al.
  et_al_min : Int?
  /// Maximum number of names to use before et al.
  et_al_use_first : Int?
  /// Minimum number of names to use et al. for repeated citations.
  et_al_subsequent_min : Int?
  /// Maximum number of names to use before et al. for repeated citations.
  et_al_subsequent_use_first : Int?
  /// Whether to use the last name in the author list when there are at
  /// least `et_al_min` names.
  et_al_use_last : Bool?
  /// Which name parts to display for personal names.
  name_form : NameForm?
  /// Whether to initialize the first name if `initialize-with` is Some.
  initialize : Bool?
  /// String to initialize the first name with.
  initialize_with : String?
  /// Whether to turn the name around.
  name_as_sort_order : NameAsSortOrder?
  /// Delimiter between given name and first name. Only used if
  /// `name-as-sort-order` is Some.
  sort_separator : String?
} derive(Eq, Debug)

///|
pub impl Default for InheritableNameOptions with default() {
  {
    and_: None,
    name_delimiter: None,
    names_delimiter: None,
    delimiter_precedes_et_al: None,
    delimiter_precedes_last: None,
    et_al_min: None,
    et_al_use_first: None,
    et_al_subsequent_min: None,
    et_al_subsequent_use_first: None,
    et_al_use_last: None,
    name_form: None,
    initialize: None,
    initialize_with: None,
    name_as_sort_order: None,
    sort_separator: None,
  }
}

///|
/// Definite name options. Obtain from [`Name::options`] using
/// [`InheritableNameOptions`].
pub(all) struct NameOptions {
  /// Delimiter between second-to-last and last name.
  and_ : NameAnd?
  /// Delimiter to separate names.
  delimiter : String
  /// Delimiter before et al.
  delimiter_precedes_et_al : DelimiterBehavior
  /// Whether to use the delimiter before the last name.
  delimiter_precedes_last : DelimiterBehavior
  /// Minimum number of names to use et al.
  et_al_min : Int?
  /// Maximum number of names to use before et al.
  et_al_use_first : Int?
  /// Minimum number of names to use et al. for repeated citations.
  et_al_subsequent_min : Int?
  /// Maximum number of names to use before et al. for repeated citations.
  et_al_subsequent_use_first : Int?
  /// Whether to use the last name in the author list when there are at
  /// least `et_al_min` names.
  et_al_use_last : Bool
  /// Which name parts to display for personal names.
  form : NameForm
  /// Whether to initialize the first name if `initialize-with` is Some.
  initialize : Bool
  /// String to initialize the first name with.
  initialize_with : String?
  /// Whether to turn the name around.
  name_as_sort_order : NameAsSortOrder?
  /// Delimiter between given name and first name. Only used if
  /// `name-as-sort-order` is Some.
  sort_separator : String
}

///|
/// Apply the child options to the parent options.
pub fn InheritableNameOptions::apply(
  self : InheritableNameOptions,
  child : InheritableNameOptions,
) -> InheritableNameOptions {
  {
    and_: or_opt(child.and_, self.and_),
    name_delimiter: or_opt(child.name_delimiter, self.name_delimiter),
    names_delimiter: or_opt(child.names_delimiter, self.names_delimiter),
    delimiter_precedes_et_al: or_opt(
      child.delimiter_precedes_et_al,
      self.delimiter_precedes_et_al,
    ),
    delimiter_precedes_last: or_opt(
      child.delimiter_precedes_last,
      self.delimiter_precedes_last,
    ),
    et_al_min: or_opt(child.et_al_min, self.et_al_min),
    et_al_use_first: or_opt(child.et_al_use_first, self.et_al_use_first),
    et_al_subsequent_min: or_opt(
      child.et_al_subsequent_min,
      self.et_al_subsequent_min,
    ),
    et_al_subsequent_use_first: or_opt(
      child.et_al_subsequent_use_first,
      self.et_al_subsequent_use_first,
    ),
    et_al_use_last: or_opt(child.et_al_use_last, self.et_al_use_last),
    name_form: or_opt(child.name_form, self.name_form),
    initialize: or_opt(child.initialize, self.initialize),
    initialize_with: or_opt(child.initialize_with, self.initialize_with),
    name_as_sort_order: or_opt(child.name_as_sort_order, self.name_as_sort_order),
    sort_separator: or_opt(child.sort_separator, self.sort_separator),
  }
}

///|
/// Whether the nth name is suppressed given the number of names and this
/// configuration.
pub fn NameOptions::is_suppressed(
  self : NameOptions,
  idx : Int,
  length : Int,
  is_subsequent : Bool,
) -> Bool {
  // This is not suppressed if we print the last element and this is it.
  if self.et_al_use_last && idx + 1 >= length {
    return false
  }

  // If this is a subsequent citation of the same item, use other CSL
  // options, if they exist
  let (et_al_min, et_al_use_first) = if is_subsequent {
    (
      or_opt(self.et_al_subsequent_min, self.et_al_min),
      or_opt(self.et_al_subsequent_use_first, self.et_al_use_first),
    )
  } else {
    (self.et_al_min, self.et_al_use_first)
  }
  let max = 2147483647
  let et_al_min = et_al_min.unwrap_or(max)
  let et_al_use_first = et_al_use_first.unwrap_or(max)
  length >= et_al_min && idx + 1 > et_al_use_first
}

///|
/// How to render the delimiter before the last name.
pub(all) enum NameAnd {
  /// Use the string "and".
  Text
  /// Use the ampersand character.
  Symbol
} derive(Eq, Hash, Debug)

///|
/// When delimiters shall be inserted.
pub(all) enum DelimiterBehavior {
  /// Only used for lists with more than one (`-precedes-et-al`) or two
  /// (`-precedes-last`) names.
  Contextual
  /// Only use if the preceding name is inverted (per `name-as-sort-order`).
  AfterInvertedName
  /// Always use the delimiter for this condition.
  Always
  /// Never use the delimiter for this condition.
  Never
} derive(Eq, Hash, Debug)

///|
/// How many name parts to print.
pub(all) enum NameForm {
  /// Print all name parts
  Long
  /// Print only the family name part and non-dropping-particle.
  Short
  /// Count the total number of names.
  Count
} derive(Eq, Hash, Debug)

///|
/// In which order to print the names.
pub(all) enum NameAsSortOrder {
  /// Only the first name is turned around.
  First
  /// All names are turned around.
  All
} derive(Eq, Hash, Debug)

///|
/// How to format a given name part.
pub(all) struct NamePart {
  /// Which name part this applies to.
  name : NamePartName
  /// Override formatting style.
  formatting : Formatting
  /// Add prefix and suffix.
  affixes : Affixes
  /// Transform the text case.
  text_case : TextCase?
} derive(Eq, Debug)

///|
/// Which part of the name a [`NamePart`] applies to.
pub(all) enum NamePartName {
  /// The given name.
  Given
  /// The family name.
  Family
} derive(Eq, Hash, Debug)

///|
/// Configure the et al. abbreviation.
pub(all) struct EtAl {
  /// Which term to use.
  term : EtAlTerm
  /// Override formatting style.
  formatting : Formatting
} derive(Eq, Debug)

///|
/// Which term to use for et al.
pub(all) enum EtAlTerm {
  /// “et al.”
  EtAl
  /// “and others”
  AndOthers
} derive(Eq, Hash, Debug)

///|
pub fn EtAlTerm::to_term(self : EtAlTerm) -> Term {
  match self {
    EtAl => Other(EtAl)
    AndOthers => Other(AndOthers)
  }
}

///|
/// What to do if the name variable is empty.
pub(all) struct Substitute {
  /// The layout to use instead.
  children : Array[LayoutRenderingElement]
} derive(Eq, Debug)

///|
/// Print a label for a number variable.
pub(all) struct Label {
  /// The variable for which to print the label.
  variable : NumberOrPageVariable
  /// The form of the label.
  label : VariablelessLabel
} derive(Eq, Debug)

///|
/// A label without its variable.
pub(all) struct VariablelessLabel {
  /// What variant of label is chosen.
  form : TermForm
  /// How to pluralize the label.
  plural : LabelPluralize
  /// Override formatting style.
  formatting : Formatting
  /// Add prefix and suffix.
  affixes : Affixes
  /// Transform the text case.
  text_case : TextCase?
  /// Remove periods from the output.
  ///
  /// Default: `false`
  strip_periods : Bool
} derive(Eq, Debug)

///|
/// How to pluralize a label.
pub(all) enum LabelPluralize {
  /// Match plurality of the variable.
  Contextual
  /// Always use the plural form.
  Always
  /// Always use the singular form.
  Never
} derive(Eq, Hash, Debug)

///|
/// A group of formatting instructions that is only shown if no variable is
/// referenced or at least one referenced variable is populated.
pub(all) struct Group {
  /// The formatting instructions.
  children : Array[LayoutRenderingElement]
  /// Set the font style.
  font_style : FontStyle?
  /// Choose normal or small caps.
  font_variant : FontVariant?
  /// Set the font weight.
  font_weight : FontWeight?
  /// Choose underlining.
  text_decoration : TextDecoration?
  /// Choose vertical alignment.
  vertical_align : VerticalAlign?
  /// The prefix.
  prefix : String?
  /// The suffix.
  suffix : String?
  /// Delimit pieces of the output.
  delimiter : String?
  /// Set layout level.
  display : Display?
} derive(Eq, Debug)

///|
/// Obtain a `Formatting`.
pub fn Group::to_formatting(self : Group) -> Formatting {
  {
    font_style: self.font_style,
    font_variant: self.font_variant,
    font_weight: self.font_weight,
    text_decoration: self.text_decoration,
    vertical_align: self.vertical_align,
  }
}

///|
/// Obtain the `Affixes`.
pub fn Group::to_affixes(self : Group) -> Affixes {
  { prefix: self.prefix, suffix: self.suffix }
}

///|
/// A conditional group of formatting instructions.
pub(all) struct Choose {
  /// If branch of the conditional group.
  if_ : ChooseBranch
  /// Other branches of the conditional group. The first matching branch is
  /// used.
  else_if : Array[ChooseBranch]
  /// The formatting instructions to use if no branch matches.
  otherwise : ElseBranch?
} derive(Eq, Debug)

///|
/// Return all branches with a condition.
pub fn Choose::branches(self : Choose) -> Array[ChooseBranch] {
  [self.if_, ..self.else_if]
}

///|
/// Find the child element that renders the given variable.
pub fn Choose::find_variable_element(
  self : Choose,
  variable : Variable,
  macros : Array[CslMacro],
) -> LayoutRenderingElement? {
  for b in self.branches() {
    for c in b.children {
      if c.find_variable_element(variable, macros) is Some(r) {
        return Some(r)
      }
    }
  }
  None
}

///|
/// A single branch of a conditional group.
pub(all) struct ChooseBranch {
  /// Other than this choose, two elements would result in the same
  /// rendering.
  disambiguate : Bool?
  /// The variable contains numeric data.
  is_numeric : Array[Variable]?
  /// The variable contains an approximate date.
  is_uncertain_date : Array[DateVariable]?
  /// The locator matches the given type.
  locator : Array[Locator]?
  /// Tests the position of this citation in the citations to the same item.
  /// Only ever true for citations.
  position : Array[TestPosition]?
  /// Tests whether the item is of a certain type.
  type_ : Array[Kind]?
  /// Tests whether the default form of this variable is non-empty.
  variable : Array[Variable]?
  /// How to handle the set of tests.
  match_ : ChooseMatch
  /// The formatting instructions to use if the condition matches.
  children : Array[LayoutRenderingElement]
} derive(Eq, Debug)

///|
/// Retrieve the test of this branch. Valid CSL files must return `Some`
/// here.
pub fn ChooseBranch::test_(self : ChooseBranch) -> ChooseTest? {
  if self.disambiguate is Some(disambiguate) {
    if !disambiguate {
      None
    } else {
      Some(Disambiguate)
    }
  } else if self.is_numeric is Some(is_numeric) {
    Some(IsNumeric(is_numeric))
  } else if self.is_uncertain_date is Some(is_uncertain_date) {
    Some(IsUncertainDate(is_uncertain_date))
  } else if self.locator is Some(locator) {
    Some(Locator(locator))
  } else if self.position is Some(position) {
    Some(Position(position))
  } else if self.type_ is Some(type_) {
    Some(Type(type_))
  } else {
    self.variable.map(variable => Variable(variable))
  }
}

///|
/// The formatting instructions to use if no branch matches.
pub(all) struct ElseBranch {
  /// The formatting instructions.
  children : Array[LayoutRenderingElement]
} derive(Eq, Debug)

///|
/// A single test in a conditional group.
pub(all) enum ChooseTest {
  /// Other than this choose, two elements would result in the same
  /// rendering.
  Disambiguate
  /// The variable contains numeric data.
  IsNumeric(Array[Variable])
  /// The variable contains an approximate date.
  IsUncertainDate(Array[DateVariable])
  /// The locator matches the given type.
  Locator(Array[Locator])
  /// Tests the position of this citation in the citations to the same item.
  /// Only ever true for citations.
  Position(Array[TestPosition])
  /// Tests whether the item is of a certain type.
  Type(Array[Kind])
  /// Tests whether the default form of this variable is non-empty.
  Variable(Array[Variable])
} derive(Eq, Debug)

///|
/// Possible positions of a citation in the citations to the same item.
pub(all) enum TestPosition {
  /// The first citation to the item.
  First
  /// Previously cited.
  Subsequent
  /// Directly following a citation to the same item but the locators don't
  /// necessarily match.
  IbidWithLocator
  /// Directly following a citation to the same item with the same locators.
  Ibid
  /// Other citation within `near-note-distance` of the same item.
  NearNote
} derive(Eq, Hash, Debug)

///|
/// How to handle the set of tests in a conditional group.
pub(all) enum ChooseMatch {
  /// All tests must match.
  All
  /// At least one test must match.
  Any
  /// No test must match.
  None_
} derive(Eq, Hash, Debug)

///|
/// Check whether the iterator of tests is true for this match type.
pub fn ChooseMatch::test_(self : ChooseMatch, tests : Iter[Bool]) -> Bool {
  match self {
    All => tests.all(t => t)
    Any => tests.any(t => t)
    None_ => tests.all(t => !t)
  }
}

///|
/// A reusable set of formatting instructions.
pub(all) struct CslMacro {
  /// The name of the macro.
  name : String
  /// The formatting instructions.
  children : Array[LayoutRenderingElement]
} derive(Eq, Debug)

///|
/// Root element of a locale file.
pub(all) struct LocaleFile {
  /// The version of the locale file.
  version : String
  /// Which languages or dialects this data applies to.
  lang : LocaleCode
  /// Metadata of the locale.
  info : LocaleInfo?
  /// The terms used in the locale.
  terms : Terms?
  /// How to format dates in the locale file.
  date : Array[Date]
  /// Style options for the locale.
  style_options : LocaleOptions?
} derive(Eq, Debug)

///|
/// Supplemental localization data in a citation style.
pub(all) struct Locale {
  /// Which languages or dialects this data applies to. Must be `Some` if
  /// this appears in a locale file.
  lang : LocaleCode?
  /// Metadata of the locale.
  info : LocaleInfo?
  /// The terms used in the locale.
  terms : Terms?
  /// How to format dates in the locale file.
  date : Array[Date]
  /// Style options for the locale.
  style_options : LocaleOptions?
} derive(Eq, Debug)

///|
/// `impl From<LocaleFile> for Locale`.
pub fn LocaleFile::to_locale(self : LocaleFile) -> Locale {
  {
    lang: Some(self.lang),
    info: self.info,
    terms: self.terms,
    date: self.date,
    style_options: self.style_options,
  }
}

///|
/// Get a term translation.
pub fn Locale::term(self : Locale, term : Term, form : TermForm) -> LocalizedTerm? {
  match self.terms {
    Some(terms) => {
      for t in terms.terms {
        if t.name.is_lexically_same(term) && t.form == form {
          return Some(t)
        }
      }
      None
    }
    None => None
  }
}

///|
/// Retrieve a struct for ordinal term lookups if this locale contains any
/// ordinal terms.
pub fn Locale::ordinals(self : Locale) -> OrdinalLookup? {
  match self.terms {
    Some(terms) =>
      if terms.terms.iter().any(t => t.name.is_ordinal()) {
        Some(OrdinalLookup::new(terms.terms.filter(t => t.name.is_ordinal())))
      } else {
        None
      }
    None => None
  }
}

///|
/// Get the right forms of ordinal terms for numbers.
pub struct OrdinalLookup {
  priv terms : Array[LocalizedTerm]
  priv legacy_behavior : Bool
}

///|
fn OrdinalLookup::new(terms : Array[LocalizedTerm]) -> OrdinalLookup {
  let mut legacy_behavior = false
  // Must not define "OtherTerm::Ordinal"
  let defines_ordinal = terms.iter().any(t => t.name == Other(Ordinal))
  if !defines_ordinal {
    // Contains OtherTerm::OrdinalN(1) - OtherTerm::OrdinalN(4)
    legacy_behavior = true
    for n in 1..=4 {
      if !terms.iter().any(t => t.name == Other(OrdinalN(n))) {
        legacy_behavior = false
      }
    }
  }
  { terms, legacy_behavior }
}

///|
/// Create an empty lookup that will never return matches.
pub fn OrdinalLookup::empty() -> OrdinalLookup {
  { terms: [], legacy_behavior: false }
}

///|
fn abs_int(x : Int) -> Int {
  if x < 0 {
    -x
  } else {
    x
  }
}

///|
/// Look up a short ordinal for a number.
pub fn OrdinalLookup::lookup(
  self : OrdinalLookup,
  n : Int,
  gender : GrammarGender?,
) -> String? {
  let mut best_match : LocalizedTerm? = None

  // Prefer match with o > 9 and the smallest difference to n
  let change_match = (other_match : LocalizedTerm) => {
    guard best_match is Some(current) else {
      best_match = Some(other_match)
      return
    }
    // Extract the number from the term name.
    guard other_match.name is Other(OrdinalN(other_n)) else { return }
    guard current.name is Other(OrdinalN(curr_n)) else {
      best_match = Some(other_match)
      return
    }
    best_match = Some(
      if other_n >= 10 && curr_n < 10 {
        other_match
      } else if other_n < 10 && curr_n >= 10 {
        current
      } else if gender == current.gender && gender != other_match.gender {
        // Both matches are either < 10 or >= 10.
        // Check the gender form.
        current
      } else if gender != current.gender && gender == other_match.gender {
        other_match
      } else {
        // Choose the smallest difference.
        let diff_other = abs_int(n - other_n)
        let diff_curr = abs_int(n - curr_n)
        if diff_other <= diff_curr {
          other_match
        } else {
          current
        }
      },
    )
  }
  for term in self.terms {
    guard term.name is Other(term_name) else { continue }
    let hit = match term_name {
      Ordinal => true
      OrdinalN(o) if self.legacy_behavior => {
        let class = if n >= 11 && n <= 13 {
          4
        } else {
          let v = n % 10
          if v >= 1 && v <= 3 {
            v
          } else {
            4
          }
        }
        o == class
      }
      OrdinalN(o) if o <= 9 =>
        match term.match_ {
          Some(LastDigit) | None => n % 10 == o
          Some(LastTwoDigits) => n % 100 == o
          Some(WholeNumber) => n == o
        }
      OrdinalN(o) if o >= 10 && o <= 99 =>
        match term.match_ {
          Some(LastTwoDigits) | None => n % 100 == o
          Some(WholeNumber) => n == o
          _ => false
        }
      _ => false
    }
    if hit {
      change_match(term)
    }
  }
  match best_match {
    Some(t) => or_opt(t.single(), t.multiple())
    None => None
  }
}

///|
/// Look up a long ordinal for a number. Does not include fallback to
/// regular ordinals.
pub fn OrdinalLookup::lookup_long(self : OrdinalLookup, n : Int) -> String? {
  for t in self.terms {
    guard t.name is Other(LongOrdinal(o)) else { continue }
    let ok = if n > 0 && n <= 10 {
      n == o
    } else {
      match t.match_ {
        Some(LastTwoDigits) | None => n % 100 == o
        Some(WholeNumber) => n == o
        _ => false
      }
    }
    if ok {
      return or_opt(t.single(), t.multiple())
    }
  }
  None
}

///|
/// Metadata of a locale.
pub(all) struct LocaleInfo {
  /// The translators of the locale.
  translators : Array[StyleAttribution]
  /// The license under which the locale is published.
  rights : License?
  /// When the locale was last updated.
  updated : Timestamp?
} derive(Eq, Debug)

///|
/// Term localization container.
pub(all) struct Terms {
  /// The terms.
  terms : Array[LocalizedTerm]
} derive(Eq, Debug)

///|
/// A localized term.
pub(all) struct LocalizedTerm {
  /// The term key.
  name : Term
  /// The localization.
  localization : String?
  /// The singular variant.
  single_ : String?
  /// The plural variant.
  multiple_ : String?
  /// The variant of this term translation.
  form : TermForm
  /// Specify the when this ordinal term is used.
  match_ : OrdinalMatch?
  /// Specify for which grammatical gender this term has to get
  /// corresponding ordinals
  gender : GrammarGender?
  /// Specify which grammatical gender this ordinal term matches
  gender_form : GrammarGender?
} derive(Eq, Debug)

///|
/// Get the singular variant of this term translation. Shall be defined for
/// valid CSL files.
pub fn LocalizedTerm::single(self : LocalizedTerm) -> String? {
  or_opt(self.single_, self.localization)
}

///|
/// Get the plural variant of this term translation. Shall be defined for
/// valid CSL files.
pub fn LocalizedTerm::multiple(self : LocalizedTerm) -> String? {
  or_opt(self.multiple_, self.localization)
}

///|
/// The variant of a term translation.
pub(all) enum TermForm {
  /// The default variant.
  Long
  /// The short noun variant.
  Short
  /// The related verb.
  Verb
  /// The related verb (short form).
  VerbShort
  /// The symbol variant.
  Symbol
} derive(Eq, Hash, Debug)

///|
/// Which form is the next fallback if this form is not available.
pub fn TermForm::fallback(self : TermForm) -> TermForm? {
  match self {
    Long => None
    Short => Some(Long)
    Verb => Some(Long)
    VerbShort => Some(Verb)
    Symbol => Some(Short)
  }
}

///|
/// Specify when which ordinal term is used.
pub(all) enum OrdinalMatch {
  /// Match the last digit for ordinal terms between zero and nine and the
  /// last two otherwise.
  LastDigit
  /// Always match on the last two non-zero digits.
  LastTwoDigits
  /// Match on the exact number.
  WholeNumber
} derive(Eq, Hash, Debug)

///|
/// A grammatical gender. Use `None` for neutral.
pub(all) enum GrammarGender {
  Feminine
  Masculine
} derive(Eq, Hash, Debug)

///|
/// Options for the locale.
pub(all) struct LocaleOptions {
  /// Only use ordinals for the first day in a month.
  ///
  /// Default: `false`
  limit_day_ordinals_to_day_1 : Bool?
  /// Whether to place punctuation inside of quotation marks.
  ///
  /// Default: `false`
  punctuation_in_quote : Bool?
} derive(Eq, Debug)

///|
/// Formatting properties.
pub(all) struct Formatting {
  /// Set the font style.
  font_style : FontStyle?
  /// Choose normal or small caps.
  font_variant : FontVariant?
  /// Set the font weight.
  font_weight : FontWeight?
  /// Choose underlining.
  text_decoration : TextDecoration?
  /// Choose vertical alignment.
  vertical_align : VerticalAlign?
} derive(Eq, Hash, Debug)

///|
pub impl Default for Formatting with default() {
  {
    font_style: None,
    font_variant: None,
    font_weight: None,
    text_decoration: None,
    vertical_align: None,
  }
}

///|
/// Check if this formatting is empty.
pub fn Formatting::is_empty(self : Formatting) -> Bool {
  self.font_style is None &&
  self.font_variant is None &&
  self.font_weight is None &&
  self.text_decoration is None &&
  self.vertical_align is None
}

///|
/// Merge with a base formatting.
pub fn Formatting::apply(self : Formatting, base : Formatting) -> Formatting {
  {
    font_style: or_opt(self.font_style, base.font_style),
    font_variant: or_opt(self.font_variant, base.font_variant),
    font_weight: or_opt(self.font_weight, base.font_weight),
    text_decoration: or_opt(self.text_decoration, base.text_decoration),
    vertical_align: or_opt(self.vertical_align, base.vertical_align),
  }
}

///|
/// Font style.
pub(all) enum FontStyle {
  /// Normal font style.
  Normal
  /// Italic font style.
  Italic
} derive(Eq, Hash, Debug)

///|
pub impl Default for FontStyle with default() {
  Normal
}

///|
/// Font variant.
pub(all) enum FontVariant {
  /// Normal font variant.
  Normal
  /// Small caps font variant.
  SmallCaps
} derive(Eq, Hash, Debug)

///|
pub impl Default for FontVariant with default() {
  Normal
}

///|
/// Font weight.
pub(all) enum FontWeight {
  /// Normal font weight.
  Normal
  /// Bold font weight.
  Bold
  /// Light font weight.
  Light
} derive(Eq, Hash, Debug)

///|
pub impl Default for FontWeight with default() {
  Normal
}

///|
/// Text decoration.
pub(all) enum TextDecoration {
  /// No text decoration.
  None_
  /// Underline text decoration.
  Underline
} derive(Eq, Hash, Debug)

///|
pub impl Default for TextDecoration with default() {
  None_
}

///|
/// Vertical alignment.
pub(all) enum VerticalAlign {
  /// No vertical alignment.
  None_
  /// Align on the baseline.
  Baseline
  /// Superscript vertical alignment.
  Sup
  /// Subscript vertical alignment.
  Sub
} derive(Eq, Hash, Debug)

///|
pub impl Default for VerticalAlign with default() {
  None_
}

///|
/// Prefixes and suffixes.
pub(all) struct Affixes {
  /// The prefix.
  prefix : String?
  /// The suffix.
  suffix : String?
} derive(Eq, Hash, Debug)

///|
pub impl Default for Affixes with default() {
  { prefix: None, suffix: None }
}

///|
/// On which layout level to display the citation.
pub(all) enum Display {
  /// Block stretching from margin to margin.
  Block
  /// Put in the left margin.
  LeftMargin
  /// Align on page after `LeftMargin`.
  RightInline
  /// `Block` and indented.
  Indent
} derive(Eq, Hash, Debug)

///|
/// How to format text.
pub(all) enum TextCase {
  /// lowercase.
  Lowercase
  /// UPPERCASE.
  Uppercase
  /// Capitalize the first word.
  CapitalizeFirst
  /// Capitalize All Words.
  CapitalizeAll
  /// Sentence case. *Deprecated*.
  SentenceCase
  /// Title case. Only applies to English.
  TitleCase
} derive(Eq, Hash, Debug)

///|
/// Check whether this case can be applied to languages other than English.
pub fn TextCase::is_language_independent(self : TextCase) -> Bool {
  self is (Lowercase | Uppercase | CapitalizeFirst | CapitalizeAll)
}
