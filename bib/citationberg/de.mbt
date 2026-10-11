// XML deserialization of CSL styles and locales.
//
// Upstream derives `serde::Deserialize` and uses `quick_xml::de` with
// `serde_path_to_error`. This file ports the resulting behavior by hand:
// attributes are keys prefixed with `@`, child elements are keys named by
// their tag, `$value` collects all children that are not named fields and
// `$text` the text content. Whitespace-only text is skipped. Errors carry
// the path to the failing field like `serde_path_to_error`.

///|
/// Error type for functions that deserialize XML.
pub(all) struct XmlDeError {
  /// The underlying error message.
  message : String
  /// The path to the error location in the XML.
  path : String?
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend XmlDeError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend XmlDeError with @debug.Debug::{to_repr}

///|
pub impl Show for XmlDeError with fn output(self, logger) {
  logger.write_string("Deserialization error occured")
  if self.path is Some(path) {
    logger.write_string(" at `\{path}`")
  }
}

///|
pub extend XmlDeError with Show::{to_string, output}

///|
priv suberror DeErr {
  DeErr(String, String) // message, path
}

///|
/// A simplified XML element (like the event stream quick-xml presents).
priv struct XNode {
  tag : String
  attrs : Array[(String, String)]
  /// Attribute values before entity expansion (quick-xml splits list values
  /// on whitespace before unescaping the items).
  raw_attrs : Array[(String, String)]
  children : Array[XChild]
}

///|
priv enum XChild {
  Elem(XNode)
  Text(String)
}

///|
fn qualified_attr_name(node : @xml.Node, a : @xml.Attribute) -> String {
  match a.namespace_() {
    Some(ns) if ns == @xml.NS_XML_URI => "xml:" + a.name()
    Some(ns) =>
      match node.lookup_prefix(ns) {
        Some(p) if !p.is_empty() => p + ":" + a.name()
        _ => a.name()
      }
    None => a.name()
  }
}

///|
fn qualified_tag_name(node : @xml.Node) -> String {
  let name = node.tag_name()
  match name.uri {
    Some(ns) =>
      match node.lookup_prefix(ns) {
        Some(p) if !p.is_empty() => p + ":" + name.name
        _ => name.name
      }
    None => name.name
  }
}

///|
fn convert_node(node : @xml.Node, input : Bytes) -> XNode {
  let attrs = node
    .attributes()
    .map(a => (qualified_attr_name(node, a), a.value()))
  let raw_attrs = node
    .attributes()
    .map(a => {
      let (start, end) = a.range_value()
      let raw = @utf8.decode_lossy(input[start:end])
      (qualified_attr_name(node, a), raw)
    })
  let children : Array[XChild] = []
  let text = StringBuilder()
  let mut has_text = false
  for child in node.children() {
    if child.is_text() {
      text.write_string(child.text().unwrap_or(""))
      has_text = true
    } else if child.is_element() {
      if has_text {
        children.push(Text(text.to_string()))
        text.reset()
        has_text = false
      }
      children.push(Elem(convert_node(child, input)))
    }
    // Comments and processing instructions do not interrupt text.
  }
  if has_text {
    children.push(Text(text.to_string()))
  }
  { tag: qualified_tag_name(node), attrs, raw_attrs, children, }
}

///|
fn parse_xml(xml : String) -> XNode raise DeErr {
  // quick-xml accepts whitespace before the XML declaration, roxmltree does
  // not.
  let mut start = 0
  while start < xml.length() &&
        xml.code_unit_at(start) is (' ' | '\t' | '\r' | '\n') {
    start += 1
  }
  let xml = if start > 0 { xml[start:].to_owned() } else { xml }
  let doc = @xml.Document::parse(xml) catch {
    e => raise DeErr(e.to_string(), "")
  }
  convert_node(doc.root_element(), @utf8.encode(xml))
}

///|
fn join_path(path : String, seg : String) -> String {
  if path.is_empty() {
    seg
  } else if seg.has_prefix("[") {
    path + seg
  } else {
    path + "." + seg
  }
}

///|
fn XNode::raw_attr(self : XNode, name : String) -> String? {
  for a in self.raw_attrs {
    if a.0 == name {
      return Some(a.1)
    }
  }
  None
}

///|
/// Expand the predefined entities and character references in `s`.
fn unescape_xml(s : String) -> String {
  if !s.contains("&") {
    return s
  }
  let out = StringBuilder()
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '&' {
      let mut j = i + 1
      while j < chars.length() && chars[j] != ';' {
        j += 1
      }
      if j < chars.length() {
        let name = String::from_array(chars[i + 1:j])
        let rep : Char? = match name {
          "amp" => Some('&')
          "lt" => Some('<')
          "gt" => Some('>')
          "quot" => Some('"')
          "apos" => Some('\'')
          _ =>
            if name.has_prefix("#x") {
              let mut v = 0
              for d in name[2:] {
                v = v * 16 +
                  (match d {
                    '0'..<='9' => d.to_int() - '0'.to_int()
                    'a'..<='f' => d.to_int() - 'a'.to_int() + 10
                    'A'..<='F' => d.to_int() - 'A'.to_int() + 10
                    _ => 0
                  })
              }
              Some(Int::unsafe_to_char(v))
            } else if name.has_prefix("#") {
              let mut v = 0
              for d in name[1:] {
                v = v * 10 + (d.to_int() - '0'.to_int())
              }
              Some(Int::unsafe_to_char(v))
            } else {
              None
            }
        }
        if rep is Some(r) {
          out.write_char(r)
          i = j + 1
          continue
        }
      }
    }
    out.write_char(c)
    i += 1
  }
  out.to_string()
}

///|
fn XNode::attr(self : XNode, name : String) -> String? {
  for a in self.attrs {
    if a.0 == name {
      return Some(a.1)
    }
  }
  None
}

///|
fn is_blank(s : String) -> Bool {
  s.iter().all(c => c is (' ' | '\r' | '\n' | '\t'))
}

///|
/// The elements with the given tag.
fn XNode::elems(self : XNode, tag : String) -> Array[XNode] {
  let out = []
  for c in self.children {
    if c is Elem(e) && e.tag == tag {
      out.push(e)
    }
  }
  out
}

///|
/// The single element with the given tag (a duplicate is an error).
fn XNode::elem(self : XNode, tag : String, path : String) -> XNode? raise DeErr {
  let es = self.elems(tag)
  if es.length() > 1 {
    raise DeErr("duplicate field `\{tag}`", path)
  }
  es.get(0)
}

///|
/// A required single element.
fn XNode::req_elem(
  self : XNode,
  tag : String,
  path : String,
) -> XNode raise DeErr {
  match self.elem(tag, path) {
    Some(e) => e
    None => raise DeErr("missing field `\{tag}`", path)
  }
}

///|
/// The children that are not named fields (`$value`).
fn XNode::value_children(self : XNode, fields : Array[String]) -> Array[XChild] {
  self.children.filter(c => {
    match c {
      Elem(e) => !fields.contains(e.tag)
      Text(t) => !is_blank(t)
    }
  })
}

///|
/// The non-blank text content (`$text`).
fn XNode::text_content(self : XNode) -> String? {
  for c in self.children {
    if c is Text(t) && !is_blank(t) {
      return Some(t)
    }
  }
  None
}

///|
/// Deserialize a `String` from an element (its text content).
fn XNode::string_value(self : XNode, path : String) -> String raise DeErr {
  for c in self.children {
    if c is Elem(_) {
      raise DeErr("invalid type: map, expected a string", path)
    }
  }
  let buf = StringBuilder()
  for c in self.children {
    if c is Text(t) {
      buf.write_string(t)
    }
  }
  let s = buf.to_string()
  // A whitespace-only text is skipped like an empty element.
  if is_blank(s) {
    ""
  } else {
    s
  }
}

///|
fn req_attr(n : XNode, name : String, path : String) -> String raise DeErr {
  match n.attr(name) {
    Some(v) => v
    None => raise DeErr("missing field `@\{name}`", path)
  }
}

///|
fn[T] enum_attr(
  n : XNode,
  name : String,
  path : String,
  parse : (String) -> T?,
) -> T? raise DeErr {
  match n.attr(name) {
    Some(v) =>
      match parse(v) {
        Some(x) => Some(x)
        None =>
          raise DeErr("unknown variant `\{v}`", join_path(path, "@" + name))
      }
    None => None
  }
}

///|
fn[T] req_enum_attr(
  n : XNode,
  name : String,
  path : String,
  parse : (String) -> T?,
) -> T raise DeErr {
  match enum_attr(n, name, path, parse) {
    Some(x) => x
    None => raise DeErr("missing field `@\{name}`", path)
  }
}

///|
/// `deserialize_bool`.
fn bool_attr(n : XNode, name : String) -> Bool? {
  n.attr(name).map(s => s.to_lower() == "true")
}

///|
/// `deserialize_u32_option`.
fn u32_attr(n : XNode, name : String, path : String) -> Int? raise DeErr {
  match n.attr(name) {
    Some(s) =>
      match @unscanny.parse_u32(@unscanny.trim(s)) {
        Some(v) if v <= 2147483647L => Some(v.to_int())
        _ =>
          raise DeErr(
            "invalid digit found in string",
            join_path(path, "@" + name),
          )
      }
    None => None
  }
}

///|
/// An `i16` attribute.
fn i16_attr(n : XNode, name : String, path : String) -> Int? raise DeErr {
  match n.attr(name) {
    Some(s) =>
      match @unscanny.parse_int_in(s, -32768L, 32767L) {
        Some(v) => Some(v.to_int())
        None =>
          raise DeErr(
            "invalid digit found in string",
            join_path(path, "@" + name),
          )
      }
    None => None
  }
}

///|
/// A list attribute (`xs:list`).
fn[T] list_attr(
  n : XNode,
  name : String,
  path : String,
  parse : (String) -> T?,
) -> Array[T]? raise DeErr {
  match n.raw_attr(name) {
    Some(s) => {
      let out = []
      for item in @unscanny.split_by(s, c => c is (' ' | '\t' | '\r' | '\n')) {
        if item.is_empty() {
          continue
        }
        let item = unescape_xml(item)
        match parse(item) {
          Some(v) => out.push(v)
          None =>
            raise DeErr(
              "unknown variant `\{item}`",
              join_path(path, "@" + name),
            )
        }
      }
      Some(out)
    }
    None => None
  }
}

// Enum string tables (serde names).

///|
fn style_class_from_str(s : String) -> StyleClass? {
  match s {
    "in-text" => Some(InText)
    "note" => Some(Note)
    _ => None
  }
}

///|
fn page_range_format_from_str(s : String) -> PageRangeFormat? {
  match s {
    "chicago" | "chicago-15" => Some(Chicago15)
    "chicago-16" => Some(Chicago16)
    "expanded" => Some(Expanded)
    "minimal" => Some(Minimal)
    "minimal-two" => Some(MinimalTwo)
    _ => None
  }
}

///|
fn demote_from_str(s : String) -> DemoteNonDroppingParticle? {
  match s {
    "never" => Some(Never)
    "sort-only" => Some(SortOnly)
    "display-and-sort" => Some(DisplayAndSort)
    _ => None
  }
}

///|
fn citation_format_from_str(s : String) -> CitationFormat? {
  match s {
    "author-date" => Some(AuthorDate)
    "author" => Some(Author)
    "numeric" => Some(Numeric)
    "label" => Some(Label)
    "note" => Some(Note)
    _ => None
  }
}

///|
fn field_from_str(s : String) -> Field? {
  match s {
    "anthropology" => Some(Anthropology)
    "astronomy" => Some(Astronomy)
    "biology" => Some(Biology)
    "botany" => Some(Botany)
    "chemistry" => Some(Chemistry)
    "communications" => Some(Communications)
    "engineering" => Some(Engineering)
    "generic-base" => Some(GenericBase)
    "geography" => Some(Geography)
    "geology" => Some(Geology)
    "history" => Some(History)
    "humanities" => Some(Humanities)
    "law" => Some(Law)
    "linguistics" => Some(Linguistics)
    "literature" => Some(Literature)
    "math" => Some(Math)
    "medicine" => Some(Medicine)
    "philosophy" => Some(Philosophy)
    "physics" => Some(Physics)
    "political_science" => Some(PoliticalScience)
    "psychology" => Some(Psychology)
    "science" => Some(Science)
    "social_science" => Some(SocialScience)
    "sociology" => Some(Sociology)
    "theology" => Some(Theology)
    "zoology" => Some(Zoology)
    _ => None
  }
}

///|
fn info_link_rel_from_str(s : String) -> InfoLinkRel? {
  match s {
    "self" => Some(Zelf)
    "template" => Some(Template)
    "documentation" => Some(Documentation)
    "independent-parent" => Some(IndependentParent)
    _ => None
  }
}

///|
fn disambiguation_rule_from_str(s : String) -> DisambiguationRule? {
  match s {
    "all-names" => Some(AllNames)
    "all-names-with-initials" => Some(AllNamesWithInitials)
    "primary-name" => Some(PrimaryName)
    "primary-name-with-initials" => Some(PrimaryNameWithInitials)
    "by-cite" => Some(ByCite)
    _ => None
  }
}

///|
fn collapse_from_str(s : String) -> Collapse? {
  match s {
    "citation-number" => Some(CitationNumber)
    "year" => Some(Year)
    "year-suffix" => Some(YearSuffix)
    "year-suffix-ranged" => Some(YearSuffixRanged)
    _ => None
  }
}

///|
fn second_field_align_from_str(s : String) -> SecondFieldAlign? {
  match s {
    "margin" => Some(Margin)
    "flush" => Some(Flush)
    _ => None
  }
}

///|
fn subsequent_rule_from_str(s : String) -> SubsequentAuthorSubstituteRule? {
  match s {
    "complete-all" => Some(CompleteAll)
    "complete-each" => Some(CompleteEach)
    "partial-each" => Some(PartialEach)
    "partial-first" => Some(PartialFirst)
    _ => None
  }
}

///|
fn sort_direction_from_str(s : String) -> SortDirection? {
  match s {
    "ascending" => Some(Ascending)
    "descending" => Some(Descending)
    _ => None
  }
}

///|
fn font_style_from_str(s : String) -> FontStyle? {
  match s {
    "normal" => Some(Normal)
    "italic" => Some(Italic)
    _ => None
  }
}

///|
fn font_variant_from_str(s : String) -> FontVariant? {
  match s {
    "normal" => Some(Normal)
    "small-caps" => Some(SmallCaps)
    _ => None
  }
}

///|
fn font_weight_from_str(s : String) -> FontWeight? {
  match s {
    "normal" => Some(Normal)
    "bold" => Some(Bold)
    "light" => Some(Light)
    _ => None
  }
}

///|
fn text_decoration_from_str(s : String) -> TextDecoration? {
  match s {
    "none" => Some(None_)
    "underline" => Some(Underline)
    _ => None
  }
}

///|
fn vertical_align_from_str(s : String) -> VerticalAlign? {
  match s {
    "" => Some(None_)
    "baseline" => Some(Baseline)
    "sup" => Some(Sup)
    "sub" => Some(Sub)
    _ => None
  }
}

///|
fn display_from_str(s : String) -> Display? {
  match s {
    "block" => Some(Block)
    "left-margin" => Some(LeftMargin)
    "right-inline" => Some(RightInline)
    "indent" => Some(Indent)
    _ => None
  }
}

///|
fn text_case_from_str(s : String) -> TextCase? {
  match s {
    "lowercase" => Some(Lowercase)
    "uppercase" => Some(Uppercase)
    "capitalize-first" => Some(CapitalizeFirst)
    "capitalize-all" => Some(CapitalizeAll)
    "sentence" => Some(SentenceCase)
    "title" => Some(TitleCase)
    _ => None
  }
}

///|
fn long_short_form_from_str(s : String) -> LongShortForm? {
  match s {
    "long" => Some(Long)
    "short" => Some(Short)
    _ => None
  }
}

///|
fn term_form_from_str(s : String) -> TermForm? {
  match s {
    "long" => Some(Long)
    "short" => Some(Short)
    "verb" => Some(Verb)
    "verb-short" => Some(VerbShort)
    "symbol" => Some(Symbol)
    _ => None
  }
}

///|
fn date_form_from_str(s : String) -> DateForm? {
  match s {
    "numeric" => Some(Numeric)
    "text" => Some(Text)
    _ => None
  }
}

///|
fn date_parts_from_str(s : String) -> DateParts? {
  match s {
    "year" => Some(Year)
    "year-month" => Some(YearMonth)
    "year-month-day" => Some(YearMonthDay)
    _ => None
  }
}

///|
fn date_part_name_from_str(s : String) -> DatePartName? {
  match s {
    "day" => Some(Day)
    "month" => Some(Month)
    "year" => Some(Year)
    _ => None
  }
}

///|
fn date_any_form_from_str(s : String) -> DateAnyForm? {
  match s {
    "numeric" => Some(Numeric)
    "numeric-leading-zeros" => Some(NumericLeadingZeros)
    "ordinal" => Some(Ordinal)
    "long" => Some(Long)
    "short" => Some(Short)
    _ => None
  }
}

///|
fn number_form_from_str(s : String) -> NumberForm? {
  match s {
    "numeric" => Some(Numeric)
    "ordinal" => Some(Ordinal)
    "long-ordinal" => Some(LongOrdinal)
    "roman" => Some(Roman)
    _ => None
  }
}

///|
fn name_and_from_str(s : String) -> NameAnd? {
  match s {
    "text" => Some(Text)
    "symbol" => Some(Symbol)
    _ => None
  }
}

///|
fn delimiter_behavior_from_str(s : String) -> DelimiterBehavior? {
  match s {
    "contextual" => Some(Contextual)
    "after-inverted-name" => Some(AfterInvertedName)
    "always" => Some(Always)
    "never" => Some(Never)
    _ => None
  }
}

///|
fn name_form_from_str(s : String) -> NameForm? {
  match s {
    "long" => Some(Long)
    "short" => Some(Short)
    "count" => Some(Count)
    _ => None
  }
}

///|
fn name_as_sort_order_from_str(s : String) -> NameAsSortOrder? {
  match s {
    "first" => Some(First)
    "all" => Some(All)
    _ => None
  }
}

///|
fn name_part_name_from_str(s : String) -> NamePartName? {
  match s {
    "given" => Some(Given)
    "family" => Some(Family)
    _ => None
  }
}

///|
fn et_al_term_from_str(s : String) -> EtAlTerm? {
  match s {
    "et al" | "et-al" => Some(EtAl)
    "and others" | "and-others" => Some(AndOthers)
    _ => None
  }
}

///|
fn label_pluralize_from_str(s : String) -> LabelPluralize? {
  match s {
    "contextual" => Some(Contextual)
    "always" => Some(Always)
    "never" => Some(Never)
    _ => None
  }
}

///|
fn test_position_from_str(s : String) -> TestPosition? {
  match s {
    "first" => Some(First)
    "subsequent" => Some(Subsequent)
    "ibid-with-locator" => Some(IbidWithLocator)
    "ibid" => Some(Ibid)
    "near-note" => Some(NearNote)
    _ => None
  }
}

///|
fn choose_match_from_str(s : String) -> ChooseMatch? {
  match s {
    "all" => Some(All)
    "any" => Some(Any)
    "none" => Some(None_)
    _ => None
  }
}

///|
fn ordinal_match_from_str(s : String) -> OrdinalMatch? {
  match s {
    "last-digit" => Some(LastDigit)
    "last-two-digits" => Some(LastTwoDigits)
    "whole-number" => Some(WholeNumber)
    _ => None
  }
}

///|
fn grammar_gender_from_str(s : String) -> GrammarGender? {
  match s {
    "feminine" => Some(Feminine)
    "masculine" => Some(Masculine)
    _ => None
  }
}

///|
fn locale_code_from_str(s : String) -> LocaleCode? {
  Some(LocaleCode(s))
}

///|
fn term_from_str(s : String) -> Term? {
  Term::from_str(s)
}

// Struct deserializers.

///|
fn de_formatting(n : XNode, path : String) -> Formatting raise DeErr {
  {
    font_style: enum_attr(n, "font-style", path, font_style_from_str),
    font_variant: enum_attr(n, "font-variant", path, font_variant_from_str),
    font_weight: enum_attr(n, "font-weight", path, font_weight_from_str),
    text_decoration: enum_attr(
      n, "text-decoration", path, text_decoration_from_str,
    ),
    vertical_align: enum_attr(
      n, "vertical-align", path, vertical_align_from_str,
    ),
  }
}

///|
fn de_affixes(n : XNode) -> Affixes {
  { prefix: n.attr("prefix"), suffix: n.attr("suffix"), }
}

///|
fn de_name_options(
  n : XNode,
  path : String,
) -> InheritableNameOptions raise DeErr {
  {
    and_: enum_attr(n, "and", path, name_and_from_str),
    name_delimiter: n.attr("name-delimiter"),
    names_delimiter: n.attr("names-delimiter"),
    delimiter_precedes_et_al: enum_attr(
      n, "delimiter-precedes-et-al", path, delimiter_behavior_from_str,
    ),
    delimiter_precedes_last: enum_attr(
      n, "delimiter-precedes-last", path, delimiter_behavior_from_str,
    ),
    et_al_min: u32_attr(n, "et-al-min", path),
    et_al_use_first: u32_attr(n, "et-al-use-first", path),
    et_al_subsequent_min: u32_attr(n, "et-al-subsequent-min", path),
    et_al_subsequent_use_first: u32_attr(n, "et-al-subsequent-use-first", path),
    et_al_use_last: bool_attr(n, "et-al-use-last"),
    name_form: enum_attr(n, "name-form", path, name_form_from_str),
    initialize: bool_attr(n, "initialize"),
    initialize_with: n.attr("initialize-with"),
    name_as_sort_order: enum_attr(
      n, "name-as-sort-order", path, name_as_sort_order_from_str,
    ),
    sort_separator: n.attr("sort-separator"),
  }
}

///|
fn de_settings(
  n : XNode,
  path : String,
) -> IndependentStyleSettings raise DeErr {
  {
    class: req_enum_attr(n, "class", path, style_class_from_str),
    initialize_with_hyphen: bool_attr(n, "initialize-with-hyphen").unwrap_or(
      true,
    ),
    page_range_format: enum_attr(
      n, "page-range-format", path, page_range_format_from_str,
    ),
    demote_non_dropping_particle: enum_attr(
      n, "demote-non-dropping-particle", path, demote_from_str,
    ).unwrap_or(DisplayAndSort),
    options: de_name_options(n, path),
  }
}

///|
fn de_local_string(n : XNode, path : String) -> LocalString raise DeErr {
  {
    lang: enum_attr(n, "lang", path, locale_code_from_str),
    value: n.string_value(path),
  }
}

///|
fn de_attribution(n : XNode, path : String) -> StyleAttribution raise DeErr {
  {
    name: n.req_elem("name", path).string_value(join_path(path, "name")),
    email: match n.elem("email", path) {
      Some(e) => Some(e.string_value(join_path(path, "email")))
      None => None
    },
    uri: match n.elem("uri", path) {
      Some(e) => Some(e.string_value(join_path(path, "uri")))
      None => None
    },
  }
}

///|
fn de_info_link(n : XNode, path : String) -> InfoLink raise DeErr {
  {
    href: req_attr(n, "href", path),
    rel: req_enum_attr(n, "rel", path, info_link_rel_from_str),
    description: n.text_content(),
    locale: enum_attr(n, "xml:lang", path, locale_code_from_str),
  }
}

///|
fn de_timestamp(n : XNode, path : String) -> Timestamp raise DeErr {
  match n.text_content() {
    Some(t) => { raw: t, }
    None => raise DeErr("missing field `$text`", path)
  }
}

///|
fn de_license(n : XNode, path : String) -> License raise DeErr {
  {
    name: match n.text_content() {
      Some(t) => t
      None => raise DeErr("missing field `$text`", path)
    },
    license: n.attr("license"),
    lang: enum_attr(n, "xml:lang", path, locale_code_from_str),
  }
}

///|
fn de_category(n : XNode, path : String) -> StyleCategory raise DeErr {
  if n.attr("citation-format") is Some(s) &&
    citation_format_from_str(s) is Some(f) {
    return CitationFormat(f)
  }
  if n.attr("field") is Some(s) && field_from_str(s) is Some(f) {
    return Field(f)
  }
  raise DeErr(
    "data did not match any variant of untagged enum StyleCategory", path,
  )
}

///|
fn de_info(n : XNode, path : String) -> StyleInfo raise DeErr {
  let opt = (tag : String, f : (XNode, String) -> LocalString raise DeErr) => {
    match n.elem(tag, path) {
      Some(e) => Some(f(e, join_path(path, tag)))
      None => None
    }
  }
  {
    authors: n
    .elems("author")
    .mapi((i, e) => de_attribution(e, join_path(path, "author[\{i}]"))),
    contributors: n
    .elems("contributor")
    .mapi((i, e) => de_attribution(e, join_path(path, "contributor[\{i}]"))),
    category: n
    .elems("category")
    .mapi((i, e) => de_category(e, join_path(path, "category[\{i}]"))),
    field: n
    .elems("field")
    .mapi((i, e) => {
      let s = e.string_value(path)
      match field_from_str(s) {
        Some(f) => f
        None =>
          raise DeErr("unknown variant `\{s}`", join_path(path, "field[\{i}]"))
      }
    }),
    id: n.req_elem("id", path).string_value(join_path(path, "id")),
    issn: n.elems("issn").map(e => e.string_value(join_path(path, "issn"))),
    eissn: match n.elem("eissn", path) {
      Some(e) => Some(e.string_value(join_path(path, "eissn")))
      None => None
    },
    issnl: match n.elem("issnl", path) {
      Some(e) => Some(e.string_value(join_path(path, "issnl")))
      None => None
    },
    link: n
    .elems("link")
    .mapi((i, e) => de_info_link(e, join_path(path, "link[\{i}]"))),
    published: match n.elem("published", path) {
      Some(e) => Some(de_timestamp(e, join_path(path, "published")))
      None => None
    },
    rights: match n.elem("rights", path) {
      Some(e) => Some(de_license(e, join_path(path, "rights")))
      None => None
    },
    summary: opt("summary", de_local_string),
    title: de_local_string(n.req_elem("title", path), join_path(path, "title")),
    title_short: opt("title-short", de_local_string),
    updated: match n.elem("updated", path) {
      Some(e) => Some(de_timestamp(e, join_path(path, "updated")))
      None => None
    },
  }
}

///|
fn de_sort(n : XNode, path : String) -> Sort raise DeErr {
  let keys = n
    .elems("key")
    .mapi((i, e) => {
      let p = join_path(path, "key[\{i}]")
      // Untagged: `Variable` first, then `MacroName`.
      let sort_direction = enum_attr(e, "sort", p, sort_direction_from_str).unwrap_or(
        Ascending,
      )
      if e.attr("variable") is Some(v) &&
        Variable::from_str(v) is Some(variable) {
        SortKey::Variable(variable~, sort_direction~)
      } else if e.attr("macro") is Some(name) {
        MacroName(
          name~,
          names_min=u32_attr(e, "names-min", p),
          names_use_first=u32_attr(e, "names-use-first", p),
          names_use_last=bool_attr(e, "names-use-last"),
          sort_direction~,
        )
      } else {
        raise DeErr(
          "data did not match any variant of untagged enum SortKey", p,
        )
      }
    })
  if keys.is_empty() {
    raise DeErr("missing field `key`", path)
  }
  { keys, }
}

///|
fn de_layout(n : XNode, path : String) -> Layout raise DeErr {
  {
    elements: de_rendering_elements(n, [], join_path(path, "$value")),
    font_style: enum_attr(n, "font-style", path, font_style_from_str),
    font_variant: enum_attr(n, "font-variant", path, font_variant_from_str),
    font_weight: enum_attr(n, "font-weight", path, font_weight_from_str),
    text_decoration: enum_attr(
      n, "text-decoration", path, text_decoration_from_str,
    ),
    vertical_align: enum_attr(
      n, "vertical-align", path, vertical_align_from_str,
    ),
    prefix: n.attr("prefix"),
    suffix: n.attr("suffix"),
    delimiter: n.attr("delimiter"),
  }
}

///|
/// Deserialize the `$value` children as rendering elements.
fn de_rendering_elements(
  n : XNode,
  fields : Array[String],
  path : String,
) -> Array[LayoutRenderingElement] raise DeErr {
  let out = []
  for i, c in n.value_children(fields) {
    let p = join_path(path, "[\{i}]")
    match c {
      Elem(e) => out.push(de_rendering_element(e, p))
      Text(t) =>
        raise DeErr(
          "unknown variant `\{t}`, expected one of `text`, `date`, `number`, `names`, `label`, `group`, `choose`",
          p,
        )
    }
  }
  out
}

///|
fn de_rendering_element(
  e : XNode,
  path : String,
) -> LayoutRenderingElement raise DeErr {
  let p = join_path(path, e.tag)
  match e.tag {
    "text" => Text(de_text(e, p))
    "date" => Date(de_date(e, p))
    "number" => Number(de_number(e, p))
    "names" => Names(de_names(e, p))
    "label" => Label(de_label(e, p))
    "group" => Group(de_group(e, p))
    "choose" => Choose(de_choose(e, p))
    tag =>
      raise DeErr(
        "unknown variant `\{tag}`, expected one of `text`, `date`, `number`, `names`, `label`, `group`, `choose`",
        path,
      )
  }
}

///|
fn de_text_target(n : XNode, path : String) -> TextTarget raise DeErr {
  // Untagged: `Variable`, `Macro`, `Term`, `Value`.
  if n.attr("variable") is Some(v) && Variable::from_str(v) is Some(var_) {
    let form = match n.attr("form") {
      Some(f) => long_short_form_from_str(f)
      None => Some(LongShortForm::Long)
    }
    if form is Some(form) {
      return Variable(var_~, form~)
    }
  }
  if n.attr("macro") is Some(name) {
    return Macro(name~)
  }
  if n.attr("term") is Some(t) && Term::from_str(t) is Some(term) {
    let form = match n.attr("form") {
      Some(f) => term_form_from_str(f)
      None => Some(TermForm::Long)
    }
    if form is Some(form) {
      return Term(term~, form~, plural=bool_attr(n, "plural").unwrap_or(false))
    }
  }
  if n.attr("value") is Some(val) {
    return Value(val~)
  }
  raise DeErr(
    "data did not match any variant of untagged enum TextTarget", path,
  )
}

///|
fn de_text(n : XNode, path : String) -> Text raise DeErr {
  {
    target: de_text_target(n, path),
    formatting: de_formatting(n, path),
    affixes: de_affixes(n),
    display: enum_attr(n, "display", path, display_from_str),
    quotes: bool_attr(n, "quotes").unwrap_or(false),
    strip_periods: bool_attr(n, "strip-periods").unwrap_or(false),
    text_case: enum_attr(n, "text-case", path, text_case_from_str),
  }
}

///|
fn de_date(n : XNode, path : String) -> Date raise DeErr {
  {
    variable: enum_attr(n, "variable", path, DateVariable::from_str),
    form: enum_attr(n, "form", path, date_form_from_str),
    parts: enum_attr(n, "date-parts", path, date_parts_from_str),
    date_part: n
    .elems("date-part")
    .mapi((i, e) => de_date_part(e, join_path(path, "date-part[\{i}]"))),
    formatting: de_formatting(n, path),
    affixes: de_affixes(n),
    delimiter: n.attr("delimiter"),
    display: enum_attr(n, "display", path, display_from_str),
    text_case: enum_attr(n, "text-case", path, text_case_from_str),
  }
}

///|
fn de_date_part(n : XNode, path : String) -> DatePart raise DeErr {
  {
    name: req_enum_attr(n, "name", path, date_part_name_from_str),
    form_: enum_attr(n, "form", path, date_any_form_from_str),
    range_delimiter: n.attr("range-delimiter"),
    formatting: de_formatting(n, path),
    affixes: de_affixes(n),
    strip_periods: bool_attr(n, "strip-periods").unwrap_or(false),
    text_case: enum_attr(n, "text-case", path, text_case_from_str),
  }
}

///|
fn de_number(n : XNode, path : String) -> Number raise DeErr {
  {
    variable: req_enum_attr(n, "variable", path, NumberOrPageVariable::from_str),
    form: enum_attr(n, "form", path, number_form_from_str).unwrap_or(Numeric),
    formatting: de_formatting(n, path),
    affixes: de_affixes(n),
    display: enum_attr(n, "display", path, display_from_str),
    text_case: enum_attr(n, "text-case", path, text_case_from_str),
  }
}

///|
fn de_names(n : XNode, path : String) -> Names raise DeErr {
  let children = []
  for i, c in n.value_children([]) {
    let p = join_path(path, "$value[\{i}]")
    match c {
      Elem(e) =>
        children.push(
          match e.tag {
            "name" => NamesChild::Name(de_name(e, join_path(p, "name")))
            "et-al" => EtAl(de_et_al(e, join_path(p, "et-al")))
            "label" => Label(de_variableless_label(e, join_path(p, "label")))
            "substitute" =>
              Substitute(de_substitute(e, join_path(p, "substitute")))
            tag =>
              raise DeErr(
                "unknown variant `\{tag}`, expected one of `name`, `et-al`, `label`, `substitute`",
                p,
              )
          },
        )
      Text(t) =>
        raise DeErr(
          "unknown variant `\{t}`, expected one of `name`, `et-al`, `label`, `substitute`",
          p,
        )
    }
  }
  {
    variable: list_attr(n, "variable", path, NameVariable::from_str).unwrap_or([]),
    children,
    delimiter_: n.attr("delimiter"),
    and_: enum_attr(n, "and", path, name_and_from_str),
    delimiter_precedes_et_al: enum_attr(
      n, "delimiter-precedes-et-al", path, delimiter_behavior_from_str,
    ),
    delimiter_precedes_last: enum_attr(
      n, "delimiter-precedes-last", path, delimiter_behavior_from_str,
    ),
    et_al_min: u32_attr(n, "et-al-min", path),
    et_al_use_first: u32_attr(n, "et-al-use-first", path),
    et_al_subsequent_min: u32_attr(n, "et-al-subsequent-min", path),
    et_al_subsequent_use_first: u32_attr(n, "et-al-subsequent-use-first", path),
    et_al_use_last: bool_attr(n, "et-al-use-last"),
    name_form: enum_attr(n, "name-form", path, name_form_from_str),
    initialize: bool_attr(n, "initialize"),
    initialize_with: n.attr("initialize-with"),
    name_as_sort_order: enum_attr(
      n, "name-as-sort-order", path, name_as_sort_order_from_str,
    ),
    sort_separator: n.attr("sort-separator"),
    font_style: enum_attr(n, "font-style", path, font_style_from_str),
    font_variant: enum_attr(n, "font-variant", path, font_variant_from_str),
    font_weight: enum_attr(n, "font-weight", path, font_weight_from_str),
    text_decoration: enum_attr(
      n, "text-decoration", path, text_decoration_from_str,
    ),
    vertical_align: enum_attr(
      n, "vertical-align", path, vertical_align_from_str,
    ),
    prefix: n.attr("prefix"),
    suffix: n.attr("suffix"),
    display: enum_attr(n, "display", path, display_from_str),
  }
}

///|
fn de_name(n : XNode, path : String) -> Name raise DeErr {
  {
    delimiter: n.attr("delimiter"),
    form: enum_attr(n, "form", path, name_form_from_str),
    parts: n
    .elems("name-part")
    .mapi((i, e) => de_name_part(e, join_path(path, "name-part[\{i}]"))),
    options_: de_name_options(n, path),
    formatting: de_formatting(n, path),
    affixes: de_affixes(n),
  }
}

///|
fn de_name_part(n : XNode, path : String) -> NamePart raise DeErr {
  {
    name: req_enum_attr(n, "name", path, name_part_name_from_str),
    formatting: de_formatting(n, path),
    affixes: de_affixes(n),
    text_case: enum_attr(n, "text-case", path, text_case_from_str),
  }
}

///|
fn de_et_al(n : XNode, path : String) -> EtAl raise DeErr {
  {
    term: enum_attr(n, "term", path, et_al_term_from_str).unwrap_or(EtAl),
    formatting: de_formatting(n, path),
  }
}

///|
fn de_substitute(n : XNode, path : String) -> Substitute raise DeErr {
  if n.value_children([]).is_empty() {
    raise DeErr("missing field `$value`", path)
  }
  { children: de_rendering_elements(n, [], join_path(path, "$value")), }
}

///|
fn de_variableless_label(
  n : XNode,
  path : String,
) -> VariablelessLabel raise DeErr {
  {
    form: enum_attr(n, "form", path, term_form_from_str).unwrap_or(Long),
    plural: enum_attr(n, "plural", path, label_pluralize_from_str).unwrap_or(
      Contextual,
    ),
    formatting: de_formatting(n, path),
    affixes: de_affixes(n),
    text_case: enum_attr(n, "text-case", path, text_case_from_str),
    strip_periods: bool_attr(n, "strip-periods").unwrap_or(false),
  }
}

///|
fn de_label(n : XNode, path : String) -> Label raise DeErr {
  {
    variable: req_enum_attr(n, "variable", path, NumberOrPageVariable::from_str),
    label: de_variableless_label(n, path),
  }
}

///|
fn de_group(n : XNode, path : String) -> Group raise DeErr {
  if n.value_children([]).is_empty() {
    raise DeErr("missing field `$value`", path)
  }
  {
    children: de_rendering_elements(n, [], join_path(path, "$value")),
    font_style: enum_attr(n, "font-style", path, font_style_from_str),
    font_variant: enum_attr(n, "font-variant", path, font_variant_from_str),
    font_weight: enum_attr(n, "font-weight", path, font_weight_from_str),
    text_decoration: enum_attr(
      n, "text-decoration", path, text_decoration_from_str,
    ),
    vertical_align: enum_attr(
      n, "vertical-align", path, vertical_align_from_str,
    ),
    prefix: n.attr("prefix"),
    suffix: n.attr("suffix"),
    delimiter: n.attr("delimiter"),
    display: enum_attr(n, "display", path, display_from_str),
  }
}

///|
fn de_choose(n : XNode, path : String) -> Choose raise DeErr {
  {
    if_: de_choose_branch(n.req_elem("if", path), join_path(path, "if")),
    else_if: n
    .elems("else-if")
    .mapi((i, e) => de_choose_branch(e, join_path(path, "else-if[\{i}]"))),
    otherwise: match n.elem("else", path) {
      Some(e) => {
        let p = join_path(path, "else")
        if e.value_children([]).is_empty() {
          raise DeErr("missing field `$value`", p)
        }
        Some({ children: de_rendering_elements(e, [], join_path(p, "$value")), })
      }
      None => None
    },
  }
}

///|
fn de_choose_branch(n : XNode, path : String) -> ChooseBranch raise DeErr {
  {
    disambiguate: bool_attr(n, "disambiguate"),
    is_numeric: list_attr(n, "is-numeric", path, Variable::from_str),
    is_uncertain_date: list_attr(
      n,
      "is-uncertain-date",
      path,
      DateVariable::from_str,
    ),
    locator: list_attr(n, "locator", path, Locator::from_str),
    position: list_attr(n, "position", path, test_position_from_str),
    type_: list_attr(n, "type", path, Kind::from_str),
    variable: list_attr(n, "variable", path, Variable::from_str),
    match_: enum_attr(n, "match", path, choose_match_from_str).unwrap_or(All),
    children: de_rendering_elements(n, [], join_path(path, "$value")),
  }
}

///|
fn de_macro(n : XNode, path : String) -> CslMacro raise DeErr {
  {
    name: req_attr(n, "name", path),
    children: de_rendering_elements(n, [], join_path(path, "$value")),
  }
}

///|
fn de_citation(n : XNode, path : String) -> Citation raise DeErr {
  {
    sort: match n.elem("sort", path) {
      Some(e) => Some(de_sort(e, join_path(path, "sort")))
      None => None
    },
    layout: de_layout(n.req_elem("layout", path), join_path(path, "layout")),
    disambiguate_add_givenname: bool_attr(n, "disambiguate-add-givenname").unwrap_or(
      false,
    ),
    givenname_disambiguation_rule: enum_attr(
      n, "givenname-disambiguation-rule", path, disambiguation_rule_from_str,
    ).unwrap_or(ByCite),
    disambiguate_add_names: bool_attr(n, "disambiguate-add-names").unwrap_or(
      false,
    ),
    disambiguate_add_year_suffix: bool_attr(n, "disambiguate-add-year-suffix").unwrap_or(
      false,
    ),
    cite_group_delimiter: n.attr("cite-group-delimiter"),
    collapse: enum_attr(n, "collapse", path, collapse_from_str),
    year_suffix_delimiter: n.attr("year-suffix-delimiter"),
    after_collapse_delimiter: n.attr("after-collapse-delimiter"),
    near_note_distance: u32_attr(n, "near-note-distance", path).unwrap_or(5),
    name_options: de_name_options(n, path),
  }
}

///|
fn de_bibliography(n : XNode, path : String) -> Bibliography raise DeErr {
  let line_spacing = i16_attr(n, "line-spacing", path).unwrap_or(1)
  if line_spacing == 0 {
    raise DeErr("invalid value: integer `0`, expected a nonzero i16", path)
  }
  {
    sort: match n.elem("sort", path) {
      Some(e) => Some(de_sort(e, join_path(path, "sort")))
      None => None
    },
    layout: de_layout(n.req_elem("layout", path), join_path(path, "layout")),
    hanging_indent: bool_attr(n, "hanging-indent").unwrap_or(false),
    second_field_align: enum_attr(
      n, "second-field-align", path, second_field_align_from_str,
    ),
    line_spacing,
    entry_spacing: i16_attr(n, "entry-spacing", path).unwrap_or(1),
    subsequent_author_substitute: n.attr("subsequent-author-substitute"),
    subsequent_author_substitute_rule: enum_attr(
      n, "subsequent-author-substitute-rule", path, subsequent_rule_from_str,
    ).unwrap_or(CompleteAll),
    name_options: de_name_options(n, path),
  }
}

///|
fn de_locale_info(n : XNode, path : String) -> LocaleInfo raise DeErr {
  {
    translators: n
    .elems("translator")
    .mapi((i, e) => de_attribution(e, join_path(path, "translator[\{i}]"))),
    rights: match n.elem("rights", path) {
      Some(e) => Some(de_license(e, join_path(path, "rights")))
      None => None
    },
    updated: match n.elem("updated", path) {
      Some(e) => Some(de_timestamp(e, join_path(path, "updated")))
      None => None
    },
  }
}

///|
fn de_localized_term(n : XNode, path : String) -> LocalizedTerm raise DeErr {
  {
    name: req_enum_attr(n, "name", path, term_from_str),
    localization: n.text_content(),
    single_: match n.elem("single", path) {
      Some(e) => Some(e.string_value(join_path(path, "single")))
      None => None
    },
    multiple_: match n.elem("multiple", path) {
      Some(e) => Some(e.string_value(join_path(path, "multiple")))
      None => None
    },
    form: enum_attr(n, "form", path, term_form_from_str).unwrap_or(Long),
    match_: enum_attr(n, "match", path, ordinal_match_from_str),
    gender: enum_attr(n, "gender", path, grammar_gender_from_str),
    gender_form: enum_attr(n, "gender-form", path, grammar_gender_from_str),
  }
}

///|
fn de_terms(n : XNode, path : String) -> Terms raise DeErr {
  let es = n.elems("term")
  if es.is_empty() {
    raise DeErr("missing field `term`", path)
  }
  {
    terms: es.mapi((i, e) => de_localized_term(e, join_path(path, "term[\{i}]"))),
  }
}

///|
fn de_locale_options(n : XNode) -> LocaleOptions {
  {
    limit_day_ordinals_to_day_1: bool_attr(n, "limit-day-ordinals-to-day-1"),
    punctuation_in_quote: bool_attr(n, "punctuation-in-quote"),
  }
}

///|
fn de_locale(n : XNode, path : String) -> Locale raise DeErr {
  {
    lang: enum_attr(n, "xml:lang", path, locale_code_from_str),
    info: match n.elem("info", path) {
      Some(e) => Some(de_locale_info(e, join_path(path, "info")))
      None => None
    },
    terms: match n.elem("terms", path) {
      Some(e) => Some(de_terms(e, join_path(path, "terms")))
      None => None
    },
    date: n
    .elems("date")
    .mapi((i, e) => de_date(e, join_path(path, "date[\{i}]"))),
    style_options: match n.elem("style-options", path) {
      Some(e) => Some(de_locale_options(e))
      None => None
    },
  }
}

///|
/// A CSL style before validation (upstream `RawStyle`).
priv struct RawStyle {
  info : StyleInfo
  default_locale : LocaleCode?
  version : String
  citation : Citation?
  bibliography : Bibliography?
  independent_settings : IndependentStyleSettings?
  macros : Array[CslMacro]
  locale : Array[Locale]
}

///|
fn de_raw_style(n : XNode) -> RawStyle raise DeErr {
  let path = ""
  {
    info: de_info(n.req_elem("info", path), "info"),
    default_locale: enum_attr(n, "default-locale", path, locale_code_from_str),
    version: req_attr(n, "version", path),
    citation: match n.elem("citation", path) {
      Some(e) => Some(de_citation(e, "citation"))
      None => None
    },
    bibliography: match n.elem("bibliography", path) {
      Some(e) => Some(de_bibliography(e, "bibliography"))
      None => None
    },
    // `#[serde(flatten)] Option<_>`: errors turn into `None`.
    independent_settings: de_settings_opt(n),
    macros: n.elems("macro").mapi((i, e) => de_macro(e, "macro[\{i}]")),
    locale: n.elems("locale").mapi((i, e) => de_locale(e, "locale[\{i}]")),
  }
}

///|
fn RawStyle::parent_link(self : RawStyle) -> InfoLink? {
  for link in self.info.link {
    if link.rel == IndependentParent {
      return Some(link)
    }
  }
  None
}

///|
fn RawStyle::to_style(self : RawStyle) -> Result[Style, StyleValidationError] {
  let has_bibliography = self.bibliography is Some(_)
  match self.citation {
    Some(citation) =>
      match self.independent_settings {
        Some(settings) =>
          Ok(
            Independent({
              info: self.info,
              default_locale: self.default_locale,
              version: self.version,
              citation,
              bibliography: self.bibliography,
              settings,
              macros: self.macros,
              locale: self.locale,
            }),
          )
        None => Err(MissingClassAttr)
      }
    None =>
      if has_bibliography {
        Err(MissingCitation)
      } else {
        match self.parent_link() {
          Some(parent_link) =>
            Ok(
              Dependent({
                info: self.info,
                default_locale: self.default_locale,
                version: self.version,
                parent_link,
              }),
            )
          None => Err(MissingParent)
        }
      }
  }
}

///|

///|
fn de_settings_opt(n : XNode) -> IndependentStyleSettings? {
  try de_settings(n, "") catch {
    _ => None
  } noraise {
    s => Some(s)
  }
}

///|
fn de_style(xml : String) -> Style raise DeErr {
  let raw = de_raw_style(parse_xml(xml))
  match raw.to_style() {
    Ok(style) => style
    Err(e) => raise DeErr(e.to_string(), "")
  }
}

///|
fn to_xml_error(e : DeErr) -> XmlDeError {
  let DeErr(message, path) = e
  { message, path: Some(if path.is_empty() { "." } else { path }), }
}

///|
/// Create a style from an XML string.
pub fn Style::from_xml(xml : String) -> Result[Style, XmlDeError] {
  try de_style(xml) catch {
    e => Err(to_xml_error(e))
  } noraise {
    s => Ok(s)
  }
}

///|
/// Create an independent style from an XML string.
pub fn IndependentStyle::from_xml(
  xml : String,
) -> Result[IndependentStyle, XmlDeError] {
  match Style::from_xml(xml) {
    Ok(Independent(i)) => Ok(i)
    Ok(Dependent(_)) =>
      Err({
        message: "expected an independent style but got a dependent style",
        path: Some("."),
      })
    Err(e) => Err(e)
  }
}

///|
/// Create a dependent style from an XML string.
pub fn DependentStyle::from_xml(
  xml : String,
) -> Result[DependentStyle, XmlDeError] {
  match Style::from_xml(xml) {
    Ok(Dependent(d)) => Ok(d)
    Ok(Independent(_)) =>
      Err({
        message: "expected a dependent style but got an independent style",
        path: Some("."),
      })
    Err(e) => Err(e)
  }
}

///|
/// Create a locale from an XML string.
pub fn LocaleFile::from_xml(xml : String) -> Result[LocaleFile, XmlDeError] {
  try {
    let n = parse_xml(xml)
    let path = ""
    let file : LocaleFile = {
      version: req_attr(n, "version", path),
      lang: req_enum_attr(n, "xml:lang", path, locale_code_from_str),
      info: match n.elem("info", path) {
        Some(e) => Some(de_locale_info(e, "info"))
        None => None
      },
      terms: match n.elem("terms", path) {
        Some(e) => Some(de_terms(e, "terms"))
        None => None
      },
      date: n.elems("date").mapi((i, e) => de_date(e, "date[\{i}]")),
      style_options: match n.elem("style-options", path) {
        Some(e) => Some(de_locale_options(e))
        None => None
      },
    }
    file
  } catch {
    e => Err(to_xml_error(e))
  } noraise {
    f => Ok(f)
  }
}
