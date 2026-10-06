// Port of `HtmlAttr` and `HtmlAttrs` (`typst-html/src/dom.rs`) and the
// predefined constants of `typst-html/src/attr.rs`.
//
// Lives in `library` because `HtmlElem` stores attributes in a field.
// Upstream's `attr::x` constants are `attr_x` here (`attr::r#type` is
// `attr_type`, `attr::mathml::x` is `attr_mathml_x`).

///|
/// An attribute of an HTML element.
pub struct HtmlAttr(String) derive(Eq, Hash)

///|
/// Intern an HTML attribute string at runtime.
pub fn HtmlAttr::intern(string : String) -> HtmlAttr raise HintedError {
  if string.is_empty() {
    bail("attribute name must not be empty")
  }
  for c in string {
    if !charsets_is_valid_in_attribute_name(c) {
      bail(
        "the character \{repr_str(c.to_string())} is not valid in an attribute name",
      )
    }
  }
  HtmlAttr(string)
}

///|
/// Creates a constant `HtmlAttr`.
///
/// Aborts if the name is not valid (upstream panics at compile time).
pub fn HtmlAttr::constant(string : String) -> HtmlAttr {
  if string.is_empty() {
    abort("attribute name must not be empty")
  }
  for c in string {
    if !c.is_ascii() || !charsets_is_valid_in_attribute_name(c) {
      abort("not all characters are valid in an attribute name")
    }
  }
  HtmlAttr(string)
}

///|
/// Resolves the attribute to a string.
pub fn HtmlAttr::resolve(self : HtmlAttr) -> String {
  self.0
}

///|
/// Upstream `Display for HtmlAttr` (also used for `Debug`).
pub impl Show for HtmlAttr with fn output(self, logger) {
  logger.write_string(self.0)
}

///|
pub impl Reflect for HtmlAttr with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for HtmlAttr with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for HtmlAttr with fn castable(v) {
  input_castable_str(v)
}

///|
pub impl IntoValue for HtmlAttr with fn into_value(self) {
  Str(self.0)
}

///|
pub impl FromValue for HtmlAttr with fn from_value(v) {
  // Upstream casts from `Str` (which also accepts symbols).
  let s : String = v.cast()
  HtmlAttr::intern(s)
}

///|
/// Attributes of an HTML element.
///
/// Upstream this is a copy-on-write `EcoVec`; here the methods that modify
/// the list mutate it in place, so callers must [HtmlAttrs::copy] a shared
/// list first.
pub struct HtmlAttrs(Array[(HtmlAttr, String)]) derive(Eq, Hash)

///|
/// Creates an empty attribute list.
pub fn HtmlAttrs::new() -> HtmlAttrs {
  HtmlAttrs([])
}

///|
pub impl Default for HtmlAttrs with fn default() {
  HtmlAttrs::new()
}

///|
/// A copy of the list that can be modified independently.
pub fn HtmlAttrs::copy(self : HtmlAttrs) -> HtmlAttrs {
  HtmlAttrs(self.0.copy())
}

///|
/// The attributes in order.
pub fn HtmlAttrs::pairs(self : HtmlAttrs) -> Array[(HtmlAttr, String)] {
  self.0
}

///|
/// Whether there are no attributes.
pub fn HtmlAttrs::is_empty(self : HtmlAttrs) -> Bool {
  self.0.is_empty()
}

///|
/// Adds an attribute.
pub fn HtmlAttrs::push(
  self : HtmlAttrs,
  attr : HtmlAttr,
  value : String,
) -> Unit {
  self.0.push((attr, value))
}

///|
/// Adds an attribute to the start of the list.
pub fn HtmlAttrs::push_front(
  self : HtmlAttrs,
  attr : HtmlAttr,
  value : String,
) -> Unit {
  self.0.insert(0, (attr, value))
}

///|
/// Finds an attribute value.
pub fn HtmlAttrs::get(self : HtmlAttrs, attr : HtmlAttr) -> String? {
  for pair in self.0 {
    if pair.0 == attr {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Replaces the value of the first attribute with the given name, if any
/// (upstream `get_mut`). Returns whether the attribute was found.
pub fn HtmlAttrs::set_existing(
  self : HtmlAttrs,
  attr : HtmlAttr,
  value : String,
) -> Bool {
  for i, pair in self.0 {
    if pair.0 == attr {
      self.0[i] = (attr, value)
      return true
    }
  }
  false
}

///|
pub impl Fold for HtmlAttrs with fn fold(self, outer) {
  // TODO: We might want to use a data structure where this is more
  // efficient (while keeping small attribute lists efficient, too), but
  // for now, this is okay.
  let out = self.0.copy()
  for pair in outer.0 {
    if !out.iter().any(p => p.0 == pair.0) {
      out.push(pair)
    }
  }
  HtmlAttrs(out)
}

///|
pub impl Reflect for HtmlAttrs with fn input() {
  Type(Type::dict())
}

///|
pub impl Reflect for HtmlAttrs with fn output() {
  Type(Type::dict())
}

///|
pub impl Reflect for HtmlAttrs with fn castable(v) {
  v is Dict(_)
}

///|
pub extend HtmlAttrs with Reflect::{output, input, castable}

///|
pub impl IntoValue for HtmlAttrs with fn into_value(self) {
  Dict(Dict::from_pairs(self.0.map(pair => (pair.0.resolve(), Str(pair.1)))))
}

///|
pub impl FromValue for HtmlAttrs with fn from_value(v) {
  match v {
    Dict(values) => {
      let out = []
      for k, v in values.iter() {
        let attr = HtmlAttr::intern(k)
        let value : String = v.cast()
        out.push((attr, value))
      }
      HtmlAttrs(out)
    }
    _ => cast_fail_with(HtmlAttrs::input(), v)
  }
}

// Predefined constants for HTML attributes (upstream `attr::*`).

///|
pub let attr_abbr : HtmlAttr = HtmlAttr::constant("abbr")

///|
pub let attr_accept : HtmlAttr = HtmlAttr::constant("accept")

///|
pub let attr_accept_charset : HtmlAttr = HtmlAttr::constant("accept-charset")

///|
pub let attr_accesskey : HtmlAttr = HtmlAttr::constant("accesskey")

///|
pub let attr_action : HtmlAttr = HtmlAttr::constant("action")

///|
pub let attr_allow : HtmlAttr = HtmlAttr::constant("allow")

///|
pub let attr_allowfullscreen : HtmlAttr = HtmlAttr::constant("allowfullscreen")

///|
pub let attr_alpha : HtmlAttr = HtmlAttr::constant("alpha")

///|
pub let attr_alt : HtmlAttr = HtmlAttr::constant("alt")

///|
pub let attr_aria_activedescendant : HtmlAttr = HtmlAttr::constant(
  "aria-activedescendant",
)

///|
pub let attr_aria_atomic : HtmlAttr = HtmlAttr::constant("aria-atomic")

///|
pub let attr_aria_autocomplete : HtmlAttr = HtmlAttr::constant(
  "aria-autocomplete",
)

///|
pub let attr_aria_busy : HtmlAttr = HtmlAttr::constant("aria-busy")

///|
pub let attr_aria_checked : HtmlAttr = HtmlAttr::constant("aria-checked")

///|
pub let attr_aria_colcount : HtmlAttr = HtmlAttr::constant("aria-colcount")

///|
pub let attr_aria_colindex : HtmlAttr = HtmlAttr::constant("aria-colindex")

///|
pub let attr_aria_colspan : HtmlAttr = HtmlAttr::constant("aria-colspan")

///|
pub let attr_aria_controls : HtmlAttr = HtmlAttr::constant("aria-controls")

///|
pub let attr_aria_current : HtmlAttr = HtmlAttr::constant("aria-current")

///|
pub let attr_aria_describedby : HtmlAttr = HtmlAttr::constant(
  "aria-describedby",
)

///|
pub let attr_aria_details : HtmlAttr = HtmlAttr::constant("aria-details")

///|
pub let attr_aria_disabled : HtmlAttr = HtmlAttr::constant("aria-disabled")

///|
pub let attr_aria_errormessage : HtmlAttr = HtmlAttr::constant(
  "aria-errormessage",
)

///|
pub let attr_aria_expanded : HtmlAttr = HtmlAttr::constant("aria-expanded")

///|
pub let attr_aria_flowto : HtmlAttr = HtmlAttr::constant("aria-flowto")

///|
pub let attr_aria_haspopup : HtmlAttr = HtmlAttr::constant("aria-haspopup")

///|
pub let attr_aria_hidden : HtmlAttr = HtmlAttr::constant("aria-hidden")

///|
pub let attr_aria_invalid : HtmlAttr = HtmlAttr::constant("aria-invalid")

///|
pub let attr_aria_keyshortcuts : HtmlAttr = HtmlAttr::constant(
  "aria-keyshortcuts",
)

///|
pub let attr_aria_label : HtmlAttr = HtmlAttr::constant("aria-label")

///|
pub let attr_aria_labelledby : HtmlAttr = HtmlAttr::constant("aria-labelledby")

///|
pub let attr_aria_level : HtmlAttr = HtmlAttr::constant("aria-level")

///|
pub let attr_aria_live : HtmlAttr = HtmlAttr::constant("aria-live")

///|
pub let attr_aria_modal : HtmlAttr = HtmlAttr::constant("aria-modal")

///|
pub let attr_aria_multiline : HtmlAttr = HtmlAttr::constant("aria-multiline")

///|
pub let attr_aria_multiselectable : HtmlAttr = HtmlAttr::constant(
  "aria-multiselectable",
)

///|
pub let attr_aria_orientation : HtmlAttr = HtmlAttr::constant(
  "aria-orientation",
)

///|
pub let attr_aria_owns : HtmlAttr = HtmlAttr::constant("aria-owns")

///|
pub let attr_aria_placeholder : HtmlAttr = HtmlAttr::constant(
  "aria-placeholder",
)

///|
pub let attr_aria_posinset : HtmlAttr = HtmlAttr::constant("aria-posinset")

///|
pub let attr_aria_pressed : HtmlAttr = HtmlAttr::constant("aria-pressed")

///|
pub let attr_aria_readonly : HtmlAttr = HtmlAttr::constant("aria-readonly")

///|
pub let attr_aria_relevant : HtmlAttr = HtmlAttr::constant("aria-relevant")

///|
pub let attr_aria_required : HtmlAttr = HtmlAttr::constant("aria-required")

///|
pub let attr_aria_roledescription : HtmlAttr = HtmlAttr::constant(
  "aria-roledescription",
)

///|
pub let attr_aria_rowcount : HtmlAttr = HtmlAttr::constant("aria-rowcount")

///|
pub let attr_aria_rowindex : HtmlAttr = HtmlAttr::constant("aria-rowindex")

///|
pub let attr_aria_rowspan : HtmlAttr = HtmlAttr::constant("aria-rowspan")

///|
pub let attr_aria_selected : HtmlAttr = HtmlAttr::constant("aria-selected")

///|
pub let attr_aria_setsize : HtmlAttr = HtmlAttr::constant("aria-setsize")

///|
pub let attr_aria_sort : HtmlAttr = HtmlAttr::constant("aria-sort")

///|
pub let attr_aria_valuemax : HtmlAttr = HtmlAttr::constant("aria-valuemax")

///|
pub let attr_aria_valuemin : HtmlAttr = HtmlAttr::constant("aria-valuemin")

///|
pub let attr_aria_valuenow : HtmlAttr = HtmlAttr::constant("aria-valuenow")

///|
pub let attr_aria_valuetext : HtmlAttr = HtmlAttr::constant("aria-valuetext")

///|
pub let attr_as : HtmlAttr = HtmlAttr::constant("as")

///|
pub let attr_async : HtmlAttr = HtmlAttr::constant("async")

///|
pub let attr_autocapitalize : HtmlAttr = HtmlAttr::constant("autocapitalize")

///|
pub let attr_autocomplete : HtmlAttr = HtmlAttr::constant("autocomplete")

///|
pub let attr_autocorrect : HtmlAttr = HtmlAttr::constant("autocorrect")

///|
pub let attr_autofocus : HtmlAttr = HtmlAttr::constant("autofocus")

///|
pub let attr_autoplay : HtmlAttr = HtmlAttr::constant("autoplay")

///|
pub let attr_blocking : HtmlAttr = HtmlAttr::constant("blocking")

///|
pub let attr_charset : HtmlAttr = HtmlAttr::constant("charset")

///|
pub let attr_checked : HtmlAttr = HtmlAttr::constant("checked")

///|
pub let attr_cite : HtmlAttr = HtmlAttr::constant("cite")

///|
pub let attr_class : HtmlAttr = HtmlAttr::constant("class")

///|
pub let attr_closedby : HtmlAttr = HtmlAttr::constant("closedby")

///|
pub let attr_color : HtmlAttr = HtmlAttr::constant("color")

///|
pub let attr_colorspace : HtmlAttr = HtmlAttr::constant("colorspace")

///|
pub let attr_cols : HtmlAttr = HtmlAttr::constant("cols")

///|
pub let attr_colspan : HtmlAttr = HtmlAttr::constant("colspan")

///|
pub let attr_command : HtmlAttr = HtmlAttr::constant("command")

///|
pub let attr_commandfor : HtmlAttr = HtmlAttr::constant("commandfor")

///|
pub let attr_content : HtmlAttr = HtmlAttr::constant("content")

///|
pub let attr_contenteditable : HtmlAttr = HtmlAttr::constant("contenteditable")

///|
pub let attr_controls : HtmlAttr = HtmlAttr::constant("controls")

///|
pub let attr_coords : HtmlAttr = HtmlAttr::constant("coords")

///|
pub let attr_crossorigin : HtmlAttr = HtmlAttr::constant("crossorigin")

///|
pub let attr_data : HtmlAttr = HtmlAttr::constant("data")

///|
pub let attr_datetime : HtmlAttr = HtmlAttr::constant("datetime")

///|
pub let attr_decoding : HtmlAttr = HtmlAttr::constant("decoding")

///|
pub let attr_default : HtmlAttr = HtmlAttr::constant("default")

///|
pub let attr_defer : HtmlAttr = HtmlAttr::constant("defer")

///|
pub let attr_dir : HtmlAttr = HtmlAttr::constant("dir")

///|
pub let attr_dirname : HtmlAttr = HtmlAttr::constant("dirname")

///|
pub let attr_disabled : HtmlAttr = HtmlAttr::constant("disabled")

///|
pub let attr_download : HtmlAttr = HtmlAttr::constant("download")

///|
pub let attr_draggable : HtmlAttr = HtmlAttr::constant("draggable")

///|
pub let attr_enctype : HtmlAttr = HtmlAttr::constant("enctype")

///|
pub let attr_enterkeyhint : HtmlAttr = HtmlAttr::constant("enterkeyhint")

///|
pub let attr_fetchpriority : HtmlAttr = HtmlAttr::constant("fetchpriority")

///|
pub let attr_for : HtmlAttr = HtmlAttr::constant("for")

///|
pub let attr_form : HtmlAttr = HtmlAttr::constant("form")

///|
pub let attr_formaction : HtmlAttr = HtmlAttr::constant("formaction")

///|
pub let attr_formenctype : HtmlAttr = HtmlAttr::constant("formenctype")

///|
pub let attr_formmethod : HtmlAttr = HtmlAttr::constant("formmethod")

///|
pub let attr_formnovalidate : HtmlAttr = HtmlAttr::constant("formnovalidate")

///|
pub let attr_formtarget : HtmlAttr = HtmlAttr::constant("formtarget")

///|
pub let attr_headers : HtmlAttr = HtmlAttr::constant("headers")

///|
pub let attr_height : HtmlAttr = HtmlAttr::constant("height")

///|
pub let attr_hidden : HtmlAttr = HtmlAttr::constant("hidden")

///|
pub let attr_high : HtmlAttr = HtmlAttr::constant("high")

///|
pub let attr_href : HtmlAttr = HtmlAttr::constant("href")

///|
pub let attr_hreflang : HtmlAttr = HtmlAttr::constant("hreflang")

///|
pub let attr_http_equiv : HtmlAttr = HtmlAttr::constant("http-equiv")

///|
pub let attr_id : HtmlAttr = HtmlAttr::constant("id")

///|
pub let attr_imagesizes : HtmlAttr = HtmlAttr::constant("imagesizes")

///|
pub let attr_imagesrcset : HtmlAttr = HtmlAttr::constant("imagesrcset")

///|
pub let attr_inert : HtmlAttr = HtmlAttr::constant("inert")

///|
pub let attr_inputmode : HtmlAttr = HtmlAttr::constant("inputmode")

///|
pub let attr_integrity : HtmlAttr = HtmlAttr::constant("integrity")

///|
pub let attr_is : HtmlAttr = HtmlAttr::constant("is")

///|
pub let attr_ismap : HtmlAttr = HtmlAttr::constant("ismap")

///|
pub let attr_itemid : HtmlAttr = HtmlAttr::constant("itemid")

///|
pub let attr_itemprop : HtmlAttr = HtmlAttr::constant("itemprop")

///|
pub let attr_itemref : HtmlAttr = HtmlAttr::constant("itemref")

///|
pub let attr_itemscope : HtmlAttr = HtmlAttr::constant("itemscope")

///|
pub let attr_itemtype : HtmlAttr = HtmlAttr::constant("itemtype")

///|
pub let attr_kind : HtmlAttr = HtmlAttr::constant("kind")

///|
pub let attr_label : HtmlAttr = HtmlAttr::constant("label")

///|
pub let attr_lang : HtmlAttr = HtmlAttr::constant("lang")

///|
pub let attr_list : HtmlAttr = HtmlAttr::constant("list")

///|
pub let attr_loading : HtmlAttr = HtmlAttr::constant("loading")

///|
pub let attr_loop : HtmlAttr = HtmlAttr::constant("loop")

///|
pub let attr_low : HtmlAttr = HtmlAttr::constant("low")

///|
pub let attr_max : HtmlAttr = HtmlAttr::constant("max")

///|
pub let attr_maxlength : HtmlAttr = HtmlAttr::constant("maxlength")

///|
pub let attr_media : HtmlAttr = HtmlAttr::constant("media")

///|
pub let attr_method : HtmlAttr = HtmlAttr::constant("method")

///|
pub let attr_min : HtmlAttr = HtmlAttr::constant("min")

///|
pub let attr_minlength : HtmlAttr = HtmlAttr::constant("minlength")

///|
pub let attr_multiple : HtmlAttr = HtmlAttr::constant("multiple")

///|
pub let attr_muted : HtmlAttr = HtmlAttr::constant("muted")

///|
pub let attr_name : HtmlAttr = HtmlAttr::constant("name")

///|
pub let attr_nomodule : HtmlAttr = HtmlAttr::constant("nomodule")

///|
pub let attr_nonce : HtmlAttr = HtmlAttr::constant("nonce")

///|
pub let attr_novalidate : HtmlAttr = HtmlAttr::constant("novalidate")

///|
pub let attr_open : HtmlAttr = HtmlAttr::constant("open")

///|
pub let attr_optimum : HtmlAttr = HtmlAttr::constant("optimum")

///|
pub let attr_pattern : HtmlAttr = HtmlAttr::constant("pattern")

///|
pub let attr_ping : HtmlAttr = HtmlAttr::constant("ping")

///|
pub let attr_placeholder : HtmlAttr = HtmlAttr::constant("placeholder")

///|
pub let attr_playsinline : HtmlAttr = HtmlAttr::constant("playsinline")

///|
pub let attr_popover : HtmlAttr = HtmlAttr::constant("popover")

///|
pub let attr_popovertarget : HtmlAttr = HtmlAttr::constant("popovertarget")

///|
pub let attr_popovertargetaction : HtmlAttr = HtmlAttr::constant(
  "popovertargetaction",
)

///|
pub let attr_poster : HtmlAttr = HtmlAttr::constant("poster")

///|
pub let attr_preload : HtmlAttr = HtmlAttr::constant("preload")

///|
pub let attr_readonly : HtmlAttr = HtmlAttr::constant("readonly")

///|
pub let attr_referrerpolicy : HtmlAttr = HtmlAttr::constant("referrerpolicy")

///|
pub let attr_rel : HtmlAttr = HtmlAttr::constant("rel")

///|
pub let attr_required : HtmlAttr = HtmlAttr::constant("required")

///|
pub let attr_reversed : HtmlAttr = HtmlAttr::constant("reversed")

///|
pub let attr_role : HtmlAttr = HtmlAttr::constant("role")

///|
pub let attr_rows : HtmlAttr = HtmlAttr::constant("rows")

///|
pub let attr_rowspan : HtmlAttr = HtmlAttr::constant("rowspan")

///|
pub let attr_sandbox : HtmlAttr = HtmlAttr::constant("sandbox")

///|
pub let attr_scope : HtmlAttr = HtmlAttr::constant("scope")

///|
pub let attr_selected : HtmlAttr = HtmlAttr::constant("selected")

///|
pub let attr_shadowrootclonable : HtmlAttr = HtmlAttr::constant(
  "shadowrootclonable",
)

///|
pub let attr_shadowrootcustomelementregistry : HtmlAttr = HtmlAttr::constant(
  "shadowrootcustomelementregistry",
)

///|
pub let attr_shadowrootdelegatesfocus : HtmlAttr = HtmlAttr::constant(
  "shadowrootdelegatesfocus",
)

///|
pub let attr_shadowrootmode : HtmlAttr = HtmlAttr::constant("shadowrootmode")

///|
pub let attr_shadowrootserializable : HtmlAttr = HtmlAttr::constant(
  "shadowrootserializable",
)

///|
pub let attr_shape : HtmlAttr = HtmlAttr::constant("shape")

///|
pub let attr_size : HtmlAttr = HtmlAttr::constant("size")

///|
pub let attr_sizes : HtmlAttr = HtmlAttr::constant("sizes")

///|
pub let attr_slot : HtmlAttr = HtmlAttr::constant("slot")

///|
pub let attr_span : HtmlAttr = HtmlAttr::constant("span")

///|
pub let attr_spellcheck : HtmlAttr = HtmlAttr::constant("spellcheck")

///|
pub let attr_src : HtmlAttr = HtmlAttr::constant("src")

///|
pub let attr_srcdoc : HtmlAttr = HtmlAttr::constant("srcdoc")

///|
pub let attr_srclang : HtmlAttr = HtmlAttr::constant("srclang")

///|
pub let attr_srcset : HtmlAttr = HtmlAttr::constant("srcset")

///|
pub let attr_start : HtmlAttr = HtmlAttr::constant("start")

///|
pub let attr_step : HtmlAttr = HtmlAttr::constant("step")

///|
pub let attr_style : HtmlAttr = HtmlAttr::constant("style")

///|
pub let attr_tabindex : HtmlAttr = HtmlAttr::constant("tabindex")

///|
pub let attr_target : HtmlAttr = HtmlAttr::constant("target")

///|
pub let attr_title : HtmlAttr = HtmlAttr::constant("title")

///|
pub let attr_translate : HtmlAttr = HtmlAttr::constant("translate")

///|
pub let attr_type : HtmlAttr = HtmlAttr::constant("type")

///|
pub let attr_usemap : HtmlAttr = HtmlAttr::constant("usemap")

///|
pub let attr_value : HtmlAttr = HtmlAttr::constant("value")

///|
pub let attr_width : HtmlAttr = HtmlAttr::constant("width")

///|
pub let attr_wrap : HtmlAttr = HtmlAttr::constant("wrap")

///|
pub let attr_writingsuggestions : HtmlAttr = HtmlAttr::constant(
  "writingsuggestions",
)

// MathML attributes (upstream `attr::mathml`).
// (Only a subset of the ones defined in MathML Core at the moment.)

///|
pub let attr_mathml_display : HtmlAttr = HtmlAttr::constant("display")

///|
pub let attr_mathml_displaystyle : HtmlAttr = HtmlAttr::constant("displaystyle")

///|
pub let attr_mathml_scriptlevel : HtmlAttr = HtmlAttr::constant("scriptlevel")

///|
pub let attr_mathml_linethickness : HtmlAttr = HtmlAttr::constant(
  "linethickness",
)

///|
pub let attr_mathml_mathvariant : HtmlAttr = HtmlAttr::constant("mathvariant")

///|
pub let attr_mathml_form : HtmlAttr = HtmlAttr::constant("form")

///|
pub let attr_mathml_fence : HtmlAttr = HtmlAttr::constant("fence")

///|
pub let attr_mathml_separator : HtmlAttr = HtmlAttr::constant("separator")

///|
pub let attr_mathml_lspace : HtmlAttr = HtmlAttr::constant("lspace")

///|
pub let attr_mathml_rspace : HtmlAttr = HtmlAttr::constant("rspace")

///|
pub let attr_mathml_stretchy : HtmlAttr = HtmlAttr::constant("stretchy")

///|
pub let attr_mathml_symmetric : HtmlAttr = HtmlAttr::constant("symmetric")

///|
pub let attr_mathml_maxsize : HtmlAttr = HtmlAttr::constant("maxsize")

///|
pub let attr_mathml_minsize : HtmlAttr = HtmlAttr::constant("minsize")

///|
pub let attr_mathml_largeop : HtmlAttr = HtmlAttr::constant("largeop")

///|
pub let attr_mathml_movablelimits : HtmlAttr = HtmlAttr::constant(
  "movablelimits",
)

///|
pub let attr_mathml_width : HtmlAttr = HtmlAttr::constant("width")

///|
pub let attr_mathml_height : HtmlAttr = HtmlAttr::constant("height")

///|
pub let attr_mathml_accent : HtmlAttr = HtmlAttr::constant("accent")

///|
pub let attr_mathml_accentunder : HtmlAttr = HtmlAttr::constant("accentunder")

///|
pub let attr_mathml_columnspan : HtmlAttr = HtmlAttr::constant("columnspan")

///|
pub let attr_mathml_rowspan : HtmlAttr = HtmlAttr::constant("rowspan")
