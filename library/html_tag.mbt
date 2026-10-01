// Port of `HtmlTag` (`typst-html/src/dom.rs`) and the predefined constants
// and predicates of `typst-html/src/tag.rs`.
//
// Lives in `library` because `HtmlElem` stores it in a field. Upstream's
// `tag::x` constants are `tag_x` here (`tag::mathml::x` is
// `tag_mathml_x`) and the predicates `tag::is_x(tag)` are methods
// `tag.is_x()`. Upstream matches on interned constants; we match on the
// resolved name, which is equivalent.

///|
/// The tag of an HTML element.
pub struct HtmlTag(String) derive(Eq, Hash)

///|
/// Intern an HTML tag string at runtime.
pub fn HtmlTag::intern(string : String) -> HtmlTag raise HintedError {
  if string.is_empty() {
    bail("tag name must not be empty")
  }
  let mut has_hyphen = false
  let mut has_uppercase = false
  for c in string {
    if c == '-' {
      has_hyphen = true
    } else if !charsets_is_valid_in_tag_name(c) {
      bail(
        "the character \{repr_str(c.to_string())} is not valid in a tag name",
      )
    } else {
      has_uppercase = has_uppercase || c.is_ascii_uppercase()
    }
  }

  // If we encounter a hyphen, we are dealing with a custom element rather
  // than a standard HTML element.
  //
  // A valid custom element name must:
  // - Contain at least one hyphen (U+002D)
  // - Start with an ASCII lowercase letter (a-z)
  // - Not contain any ASCII uppercase letters (A-Z)
  // - Not be one of the reserved names
  // - Only contain valid characters (ASCII alphanumeric and hyphens)
  //
  // See https://html.spec.whatwg.org/multipage/custom-elements.html#valid-custom-element-name
  if has_hyphen {
    if !string.get_char(0).unwrap().is_ascii_lowercase() {
      bail("custom element name must start with a lowercase letter")
    }
    if has_uppercase {
      bail("custom element name must not contain uppercase letters")
    }

    // These names are used in SVG and MathML. Since `html.elem` only
    // supports creation of _HTML_ elements, they are forbidden.
    if string
      is ("annotation-xml"
      | "color-profile"
      | "font-face"
      | "font-face-src"
      | "font-face-uri"
      | "font-face-format"
      | "font-face-name"
      | "missing-glyph") {
      bail("name is reserved and not valid for a custom element")
    }
  }
  HtmlTag(string)
}

///|
/// Creates a constant `HtmlTag`.
///
/// Aborts if the name is not valid (upstream panics at compile time).
pub fn HtmlTag::constant(string : String) -> HtmlTag {
  if string.is_empty() {
    abort("tag name must not be empty")
  }
  for c in string {
    if !c.is_ascii() || !charsets_is_valid_in_tag_name(c) {
      abort("not all characters are valid in a tag name")
    }
  }
  HtmlTag(string)
}

///|
/// Resolves the tag to a string.
pub fn HtmlTag::resolve(self : HtmlTag) -> String {
  self.0
}

///|
/// Upstream `Display for HtmlTag` (also used for `Debug`): `<tag>`.
pub impl Show for HtmlTag with fn output(self, logger) {
  logger.write_string("<")
  logger.write_string(self.0)
  logger.write_string(">")
}

///|
pub impl Reflect for HtmlTag with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for HtmlTag with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for HtmlTag with fn castable(v) {
  input_castable_str(v)
}

///|
pub impl IntoValue for HtmlTag with fn into_value(self) {
  Str(self.0)
}

///|
pub impl FromValue for HtmlTag with fn from_value(v) {
  // Upstream casts from `Str` (which also accepts symbols).
  let s : String = v.cast()
  HtmlTag::intern(s)
}

///|
/// Whether the value is castable to `Str`.
fn input_castable_str(v : Value) -> Bool {
  html_castable_of((Ty::new() : Ty[String]), v)
}

// Predefined constants for HTML tags (upstream `tag::*`).

///|
pub let tag_a : HtmlTag = HtmlTag::constant("a")

///|
pub let tag_abbr : HtmlTag = HtmlTag::constant("abbr")

///|
pub let tag_address : HtmlTag = HtmlTag::constant("address")

///|
pub let tag_area : HtmlTag = HtmlTag::constant("area")

///|
pub let tag_article : HtmlTag = HtmlTag::constant("article")

///|
pub let tag_aside : HtmlTag = HtmlTag::constant("aside")

///|
pub let tag_audio : HtmlTag = HtmlTag::constant("audio")

///|
pub let tag_b : HtmlTag = HtmlTag::constant("b")

///|
pub let tag_base : HtmlTag = HtmlTag::constant("base")

///|
pub let tag_bdi : HtmlTag = HtmlTag::constant("bdi")

///|
pub let tag_bdo : HtmlTag = HtmlTag::constant("bdo")

///|
pub let tag_blockquote : HtmlTag = HtmlTag::constant("blockquote")

///|
pub let tag_body : HtmlTag = HtmlTag::constant("body")

///|
pub let tag_br : HtmlTag = HtmlTag::constant("br")

///|
pub let tag_button : HtmlTag = HtmlTag::constant("button")

///|
pub let tag_canvas : HtmlTag = HtmlTag::constant("canvas")

///|
pub let tag_caption : HtmlTag = HtmlTag::constant("caption")

///|
pub let tag_cite : HtmlTag = HtmlTag::constant("cite")

///|
pub let tag_code : HtmlTag = HtmlTag::constant("code")

///|
pub let tag_col : HtmlTag = HtmlTag::constant("col")

///|
pub let tag_colgroup : HtmlTag = HtmlTag::constant("colgroup")

///|
pub let tag_data : HtmlTag = HtmlTag::constant("data")

///|
pub let tag_datalist : HtmlTag = HtmlTag::constant("datalist")

///|
pub let tag_dd : HtmlTag = HtmlTag::constant("dd")

///|
pub let tag_del : HtmlTag = HtmlTag::constant("del")

///|
pub let tag_details : HtmlTag = HtmlTag::constant("details")

///|
pub let tag_dfn : HtmlTag = HtmlTag::constant("dfn")

///|
pub let tag_dialog : HtmlTag = HtmlTag::constant("dialog")

///|
pub let tag_div : HtmlTag = HtmlTag::constant("div")

///|
pub let tag_dl : HtmlTag = HtmlTag::constant("dl")

///|
pub let tag_dt : HtmlTag = HtmlTag::constant("dt")

///|
pub let tag_em : HtmlTag = HtmlTag::constant("em")

///|
pub let tag_embed : HtmlTag = HtmlTag::constant("embed")

///|
pub let tag_fieldset : HtmlTag = HtmlTag::constant("fieldset")

///|
pub let tag_figcaption : HtmlTag = HtmlTag::constant("figcaption")

///|
pub let tag_figure : HtmlTag = HtmlTag::constant("figure")

///|
pub let tag_footer : HtmlTag = HtmlTag::constant("footer")

///|
pub let tag_form : HtmlTag = HtmlTag::constant("form")

///|
pub let tag_h1 : HtmlTag = HtmlTag::constant("h1")

///|
pub let tag_h2 : HtmlTag = HtmlTag::constant("h2")

///|
pub let tag_h3 : HtmlTag = HtmlTag::constant("h3")

///|
pub let tag_h4 : HtmlTag = HtmlTag::constant("h4")

///|
pub let tag_h5 : HtmlTag = HtmlTag::constant("h5")

///|
pub let tag_h6 : HtmlTag = HtmlTag::constant("h6")

///|
pub let tag_head : HtmlTag = HtmlTag::constant("head")

///|
pub let tag_header : HtmlTag = HtmlTag::constant("header")

///|
pub let tag_hgroup : HtmlTag = HtmlTag::constant("hgroup")

///|
pub let tag_hr : HtmlTag = HtmlTag::constant("hr")

///|
pub let tag_html : HtmlTag = HtmlTag::constant("html")

///|
pub let tag_i : HtmlTag = HtmlTag::constant("i")

///|
pub let tag_iframe : HtmlTag = HtmlTag::constant("iframe")

///|
pub let tag_img : HtmlTag = HtmlTag::constant("img")

///|
pub let tag_input : HtmlTag = HtmlTag::constant("input")

///|
pub let tag_ins : HtmlTag = HtmlTag::constant("ins")

///|
pub let tag_kbd : HtmlTag = HtmlTag::constant("kbd")

///|
pub let tag_label : HtmlTag = HtmlTag::constant("label")

///|
pub let tag_legend : HtmlTag = HtmlTag::constant("legend")

///|
pub let tag_li : HtmlTag = HtmlTag::constant("li")

///|
pub let tag_link : HtmlTag = HtmlTag::constant("link")

///|
pub let tag_main : HtmlTag = HtmlTag::constant("main")

///|
pub let tag_map : HtmlTag = HtmlTag::constant("map")

///|
pub let tag_mark : HtmlTag = HtmlTag::constant("mark")

///|
pub let tag_menu : HtmlTag = HtmlTag::constant("menu")

///|
pub let tag_meta : HtmlTag = HtmlTag::constant("meta")

///|
pub let tag_meter : HtmlTag = HtmlTag::constant("meter")

///|
pub let tag_nav : HtmlTag = HtmlTag::constant("nav")

///|
pub let tag_noscript : HtmlTag = HtmlTag::constant("noscript")

///|
pub let tag_object : HtmlTag = HtmlTag::constant("object")

///|
pub let tag_ol : HtmlTag = HtmlTag::constant("ol")

///|
pub let tag_optgroup : HtmlTag = HtmlTag::constant("optgroup")

///|
pub let tag_option : HtmlTag = HtmlTag::constant("option")

///|
pub let tag_output : HtmlTag = HtmlTag::constant("output")

///|
pub let tag_p : HtmlTag = HtmlTag::constant("p")

///|
pub let tag_picture : HtmlTag = HtmlTag::constant("picture")

///|
pub let tag_pre : HtmlTag = HtmlTag::constant("pre")

///|
pub let tag_progress : HtmlTag = HtmlTag::constant("progress")

///|
pub let tag_q : HtmlTag = HtmlTag::constant("q")

///|
pub let tag_rp : HtmlTag = HtmlTag::constant("rp")

///|
pub let tag_rt : HtmlTag = HtmlTag::constant("rt")

///|
pub let tag_ruby : HtmlTag = HtmlTag::constant("ruby")

///|
pub let tag_s : HtmlTag = HtmlTag::constant("s")

///|
pub let tag_samp : HtmlTag = HtmlTag::constant("samp")

///|
pub let tag_script : HtmlTag = HtmlTag::constant("script")

///|
pub let tag_search : HtmlTag = HtmlTag::constant("search")

///|
pub let tag_section : HtmlTag = HtmlTag::constant("section")

///|
pub let tag_select : HtmlTag = HtmlTag::constant("select")

///|
pub let tag_slot : HtmlTag = HtmlTag::constant("slot")

///|
pub let tag_small : HtmlTag = HtmlTag::constant("small")

///|
pub let tag_source : HtmlTag = HtmlTag::constant("source")

///|
pub let tag_span : HtmlTag = HtmlTag::constant("span")

///|
pub let tag_strong : HtmlTag = HtmlTag::constant("strong")

///|
pub let tag_style : HtmlTag = HtmlTag::constant("style")

///|
pub let tag_sub : HtmlTag = HtmlTag::constant("sub")

///|
pub let tag_summary : HtmlTag = HtmlTag::constant("summary")

///|
pub let tag_sup : HtmlTag = HtmlTag::constant("sup")

///|
pub let tag_table : HtmlTag = HtmlTag::constant("table")

///|
pub let tag_tbody : HtmlTag = HtmlTag::constant("tbody")

///|
pub let tag_td : HtmlTag = HtmlTag::constant("td")

///|
pub let tag_template : HtmlTag = HtmlTag::constant("template")

///|
pub let tag_textarea : HtmlTag = HtmlTag::constant("textarea")

///|
pub let tag_tfoot : HtmlTag = HtmlTag::constant("tfoot")

///|
pub let tag_th : HtmlTag = HtmlTag::constant("th")

///|
pub let tag_thead : HtmlTag = HtmlTag::constant("thead")

///|
pub let tag_time : HtmlTag = HtmlTag::constant("time")

///|
pub let tag_title : HtmlTag = HtmlTag::constant("title")

///|
pub let tag_tr : HtmlTag = HtmlTag::constant("tr")

///|
pub let tag_track : HtmlTag = HtmlTag::constant("track")

///|
pub let tag_u : HtmlTag = HtmlTag::constant("u")

///|
pub let tag_ul : HtmlTag = HtmlTag::constant("ul")

///|
pub let tag_var : HtmlTag = HtmlTag::constant("var")

///|
pub let tag_video : HtmlTag = HtmlTag::constant("video")

///|
pub let tag_wbr : HtmlTag = HtmlTag::constant("wbr")

// Elements in the MathML namespace (upstream `tag::mathml`).
//
// Only the MathML Core elements at the moment.

///|
pub let tag_mathml_annotation : HtmlTag = HtmlTag::constant("annotation")

///|
pub let tag_mathml_annotation_xml : HtmlTag = HtmlTag::constant(
  "annotation-xml",
)

///|
pub let tag_mathml_maction : HtmlTag = HtmlTag::constant("maction")

///|
pub let tag_mathml_math : HtmlTag = HtmlTag::constant("math")

///|
pub let tag_mathml_merror : HtmlTag = HtmlTag::constant("merror")

///|
pub let tag_mathml_mfrac : HtmlTag = HtmlTag::constant("mfrac")

///|
pub let tag_mathml_mi : HtmlTag = HtmlTag::constant("mi")

///|
pub let tag_mathml_mmultiscripts : HtmlTag = HtmlTag::constant("mmultiscripts")

///|
pub let tag_mathml_mn : HtmlTag = HtmlTag::constant("mn")

///|
pub let tag_mathml_mo : HtmlTag = HtmlTag::constant("mo")

///|
pub let tag_mathml_mover : HtmlTag = HtmlTag::constant("mover")

///|
pub let tag_mathml_mpadded : HtmlTag = HtmlTag::constant("mpadded")

///|
pub let tag_mathml_mphantom : HtmlTag = HtmlTag::constant("mphantom")

///|
pub let tag_mathml_mprescripts : HtmlTag = HtmlTag::constant("mprescripts")

///|
pub let tag_mathml_mroot : HtmlTag = HtmlTag::constant("mroot")

///|
pub let tag_mathml_mrow : HtmlTag = HtmlTag::constant("mrow")

///|
pub let tag_mathml_ms : HtmlTag = HtmlTag::constant("ms")

///|
pub let tag_mathml_mspace : HtmlTag = HtmlTag::constant("mspace")

///|
pub let tag_mathml_msqrt : HtmlTag = HtmlTag::constant("msqrt")

///|
pub let tag_mathml_mstyle : HtmlTag = HtmlTag::constant("mstyle")

///|
pub let tag_mathml_msub : HtmlTag = HtmlTag::constant("msub")

///|
pub let tag_mathml_msubsup : HtmlTag = HtmlTag::constant("msubsup")

///|
pub let tag_mathml_msup : HtmlTag = HtmlTag::constant("msup")

///|
pub let tag_mathml_mtable : HtmlTag = HtmlTag::constant("mtable")

///|
pub let tag_mathml_mtd : HtmlTag = HtmlTag::constant("mtd")

///|
pub let tag_mathml_mtext : HtmlTag = HtmlTag::constant("mtext")

///|
pub let tag_mathml_mtr : HtmlTag = HtmlTag::constant("mtr")

///|
pub let tag_mathml_munder : HtmlTag = HtmlTag::constant("munder")

///|
pub let tag_mathml_munderover : HtmlTag = HtmlTag::constant("munderover")

///|
pub let tag_mathml_semantics : HtmlTag = HtmlTag::constant("semantics")

// HTML spec § 13.1.2 Elements

///|
/// Whether this is a void tag whose associated element may not have
/// children.
/// (upstream `tag::is_void`)
pub fn HtmlTag::is_void(self : HtmlTag) -> Bool {
  self.0
  is ("area"
  | "base"
  | "br"
  | "col"
  | "embed"
  | "hr"
  | "img"
  | "input"
  | "link"
  | "meta"
  | "source"
  | "track"
  | "wbr")
}

///|
/// Whether this is a tag containing raw text.
/// (upstream `tag::is_raw`)
pub fn HtmlTag::is_raw(self : HtmlTag) -> Bool {
  self.0 is ("script" | "style")
}

///|
/// Whether this is a tag containing escapable raw text.
/// (upstream `tag::is_escapable_raw`)
pub fn HtmlTag::is_escapable_raw(self : HtmlTag) -> Bool {
  self.0 is ("textarea" | "title")
}

///|
/// Whether this is a foreign tag whose associated element is from another
/// namespace (upstream `tag::is_foreign`).
///
/// Currently includes MathML tags, but could be extended to SVG.
pub fn HtmlTag::is_foreign(self : HtmlTag) -> Bool {
  self.is_mathml()
}

///|
/// Whether this is a foreign element whose tag is self-closing.
/// (upstream `tag::is_foreign_self_closing`)
pub fn HtmlTag::is_foreign_self_closing(self : HtmlTag) -> Bool {
  self.0 is ("mprescripts" | "mspace")
}

// HTML spec § 3.2.5.2 Kinds of content

///|
/// Whether an element is considered metadata content.
/// (upstream `tag::is_metadata_content`)
pub fn HtmlTag::is_metadata_content(self : HtmlTag) -> Bool {
  self.0
  is ("base"
  | "link"
  | "meta"
  | "noscript"
  | "script"
  | "style"
  | "template"
  | "title")
}

///|
/// Wether an element is considered flow content.
/// (upstream `tag::is_flow_content`)
pub fn HtmlTag::is_flow_content(self : HtmlTag) -> Bool {
  self.0
  is ("a"
  | "abbr"
  | "address"
  | "area"
  | "article"
  | "aside"
  | "audio"
  | "b"
  | "bdi"
  | "bdo"
  | "blockquote"
  | "br"
  | "button"
  | "canvas"
  | "cite"
  | "code"
  | "data"
  | "datalist"
  | "del"
  | "details"
  | "dfn"
  | "dialog"
  | "div"
  | "dl"
  | "em"
  | "embed"
  | "fieldset"
  | "figure"
  | "footer"
  | "form"
  | "h1"
  | "h2"
  | "h3"
  | "h4"
  | "h5"
  | "h6"
  | "header"
  | "hgroup"
  | "hr"
  | "i"
  | "iframe"
  | "img"
  | "input"
  | "ins"
  | "kbd"
  | "label"
  | "link"
  | "main"
  | "map"
  | "mark"
  | "math"
  | "menu"
  | "meta"
  | "meter"
  | "nav"
  | "noscript"
  | "object"
  | "ol"
  | "output"
  | "p"
  | "picture"
  | "pre"
  | "progress"
  | "q"
  | "ruby"
  | "s"
  | "samp"
  | "script"
  | "search"
  | "section"
  | "select"
  | "slot"
  | "small"
  | "span"
  | "strong"
  | "sub"
  | "sup"
  | "table"
  | "template"
  | "textarea"
  | "time"
  | "u"
  | "ul"
  | "var"
  | "video"
  | "wbr")
}

///|
/// Whether an element is considered sectioning content.
/// (upstream `tag::is_sectioning_content`)
pub fn HtmlTag::is_sectioning_content(self : HtmlTag) -> Bool {
  self.0 is ("article" | "aside" | "nav" | "section")
}

///|
/// Whether an element is considered heading content.
/// (upstream `tag::is_heading_content`)
pub fn HtmlTag::is_heading_content(self : HtmlTag) -> Bool {
  self.0 is ("h1" | "h2" | "h3" | "h4" | "h5" | "h6" | "hgroup")
}

///|
/// Whether an element is considered phrasing content.
/// (upstream `tag::is_phrasing_content`)
pub fn HtmlTag::is_phrasing_content(self : HtmlTag) -> Bool {
  self.0
  is ("a"
  | "abbr"
  | "area"
  | "audio"
  | "b"
  | "bdi"
  | "bdo"
  | "br"
  | "button"
  | "canvas"
  | "cite"
  | "code"
  | "data"
  | "datalist"
  | "del"
  | "dfn"
  | "em"
  | "embed"
  | "i"
  | "iframe"
  | "img"
  | "input"
  | "ins"
  | "kbd"
  | "label"
  | "link"
  | "map"
  | "mark"
  | "math"
  | "meta"
  | "meter"
  | "noscript"
  | "object"
  | "output"
  | "picture"
  | "progress"
  | "q"
  | "ruby"
  | "s"
  | "samp"
  | "script"
  | "select"
  | "slot"
  | "small"
  | "span"
  | "strong"
  | "sub"
  | "sup"
  | "template"
  | "textarea"
  | "time"
  | "u"
  | "var"
  | "video"
  | "wbr")
}

///|
/// Whether an element is considered embedded content.
/// (upstream `tag::is_embedded_content`)
pub fn HtmlTag::is_embedded_content(self : HtmlTag) -> Bool {
  self.0
  is ("audio"
  | "canvas"
  | "embed"
  | "iframe"
  | "img"
  | "math"
  | "object"
  | "picture"
  | "video")
}

///|
/// Whether an element is considered interactive content.
/// (upstream `tag::is_interactive_content`)
pub fn HtmlTag::is_interactive_content(self : HtmlTag) -> Bool {
  self.0
  is ("a"
  | "audio"
  | "button"
  | "details"
  | "embed"
  | "iframe"
  | "img"
  | "input"
  | "label"
  | "select"
  | "textarea"
  | "video")
}

///|
/// Whether an element is considered palpable content.
/// (upstream `tag::is_palpable_content`)
pub fn HtmlTag::is_palpable_content(self : HtmlTag) -> Bool {
  self.0
  is ("a"
  | "abbr"
  | "address"
  | "article"
  | "aside"
  | "audio"
  | "b"
  | "bdi"
  | "bdo"
  | "blockquote"
  | "button"
  | "canvas"
  | "cite"
  | "code"
  | "data"
  | "del"
  | "details"
  | "dfn"
  | "div"
  | "dl"
  | "em"
  | "embed"
  | "fieldset"
  | "figure"
  | "footer"
  | "form"
  | "h1"
  | "h2"
  | "h3"
  | "h4"
  | "h5"
  | "h6"
  | "header"
  | "hgroup"
  | "i"
  | "iframe"
  | "img"
  | "input"
  | "ins"
  | "kbd"
  | "label"
  | "main"
  | "map"
  | "mark"
  | "math"
  | "menu"
  | "meter"
  | "nav"
  | "object"
  | "ol"
  | "output"
  | "p"
  | "picture"
  | "pre"
  | "progress"
  | "q"
  | "ruby"
  | "s"
  | "samp"
  | "search"
  | "section"
  | "select"
  | "small"
  | "span"
  | "strong"
  | "sub"
  | "sup"
  | "table"
  | "textarea"
  | "time"
  | "u"
  | "ul"
  | "var"
  | "video")
}

///|
/// Whether an element is considered a script-supporting element.
/// (upstream `tag::is_script_supporting_element`)
pub fn HtmlTag::is_script_supporting_element(self : HtmlTag) -> Bool {
  self.0 is ("script" | "template")
}

///|
/// Whether the element is considered a "replaced element".
///
/// See:
/// - § 15.4 Replaced elements
/// - <https://www.w3.org/TR/css-display-3/#replaced-element>
/// (upstream `tag::is_replaced`)
pub fn HtmlTag::is_replaced(self : HtmlTag) -> Bool {
  self.0
  is ("audio"
  | "canvas"
  | "embed"
  | "iframe"
  | "img"
  | "input"
  | "object"
  | "video")
}

///|
/// Whether this is a MathML token element.
/// (upstream `tag::mathml::is_token`)
pub fn HtmlTag::is_mathml_token(self : HtmlTag) -> Bool {
  self.0 is ("mtext" | "mi" | "mn" | "mo" | "mspace" | "ms")
}

///|
/// Whether this tag is an element in the MathML namespace.
/// (upstream `tag::mathml::is_mathml`)
pub fn HtmlTag::is_mathml(self : HtmlTag) -> Bool {
  self.0
  is ("annotation"
  | "annotation-xml"
  | "maction"
  | "math"
  | "merror"
  | "mfrac"
  | "mi"
  | "mmultiscripts"
  | "mn"
  | "mo"
  | "mover"
  | "mpadded"
  | "mphantom"
  | "mprescripts"
  | "mroot"
  | "mrow"
  | "ms"
  | "mspace"
  | "msqrt"
  | "mstyle"
  | "msub"
  | "msubsup"
  | "msup"
  | "mtable"
  | "mtd"
  | "mtext"
  | "mtr"
  | "munder"
  | "munderover"
  | "semantics")
}
