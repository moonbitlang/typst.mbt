// Port of the element definitions of `typst-html/src/format.rs` (the
// `HtmlFormat`, `HtmlElem` and `FrameElem` descriptors are generated into
// `elems_gen.mbt`; their typed views into `elem_views_gen.mbt`). The typed
// HTML API (`#[defs]`) is in `html_typed.mbt`.

///|
/// `impl Construct for HtmlFormat`.
fn html_format_elem_init(e : Element) -> Unit {
  e.hooks().construct = Some((_engine, args) => {
    bail_at(args.span, "cannot be constructed manually")
  })
}

///|
/// Document settings for HTML export (upstream
/// `HtmlFormatOptions<Complete>`).
pub(all) struct HtmlFormatOptions {
  pretty : SpannedValue[Bool]
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend HtmlFormatOptions with Eq::{not_equal, equal}

///|
/// The HTML format options configured by a document (upstream
/// `options.get::<HtmlFormat>()`).
pub fn HtmlFormatOptions::get(
  options : DocumentFormatOptions,
) -> HtmlFormatOptions {
  let o = options.get(html_format_elem())
  let pretty = o.get(html_format_elem_pretty)
  { pretty: { v: pretty.v is Bool(true), span: pretty.span, }, }
}

///|
/// Partially specified document settings for HTML export (upstream
/// `HtmlFormatOptions<Partial>`).
pub(all) struct PartialHtmlFormatOptions {
  pretty : Bool?
} derive(Eq, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PartialHtmlFormatOptions with Eq::{not_equal, equal}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PartialHtmlFormatOptions with Default::{default}

///|
/// Resolves the partial options to complete ones, given defaults.
pub fn PartialHtmlFormatOptions::resolve(
  self : PartialHtmlFormatOptions,
  default : HtmlFormatOptions,
) -> HtmlFormatOptions {
  {
    pretty: match self.pretty {
      Some(v) => SpannedValue::detached(v)
      None => default.pretty
    },
  }
}

///|
/// `HtmlAttrs::default()`.
fn html_elem_attrs_default() -> Value {
  HtmlAttrs::new().into_value()
}

///|
/// `#[fold]` of `HtmlElem.attrs` (`Fold for HtmlAttrs`).
fn html_elem_attrs_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[HtmlAttrs]), inner, outer)
}

///|
/// `css::Properties::default()`.
fn html_elem_css_default() -> Value {
  CssProperties::new().into_value()
}

///|
/// `#[parse(Some(css::Properties::default()))]` of `HtmlElem.css`.
// Cannot fail; a parse hook (typst-html/src/format.rs:216).
#warnings("-unused_error_type")
fn html_elem_css_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  Some(CssProperties::new().into_value())
}

///|
/// Add an attribute to the element.
pub fn HtmlElem::with_attr(
  self : HtmlElem,
  attr : HtmlAttr,
  value : String,
) -> HtmlElem {
  let attrs = match self.attrs_local() {
    Some(attrs) => attrs.copy()
    None => HtmlAttrs::new()
  }
  attrs.push(attr, value)
  self.with_attrs(attrs)
}

///|
/// Adds the attribute to the element if value is not `None`.
pub fn HtmlElem::with_optional_attr(
  self : HtmlElem,
  attr : HtmlAttr,
  value : String?,
) -> HtmlElem {
  match value {
    Some(value) => self.with_attr(attr, value)
    None => self
  }
}
