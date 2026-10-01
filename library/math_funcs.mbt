// Native math functions of `typst-library/src/math/{root.rs, style.rs}`
// (the `lr.rs` ones are in `lr.mbt`).

///|
/// Set a style property on content (upstream `Content::set`).
pub fn Content::set(
  self : Content,
  elem : Element,
  id : Int,
  value : Value,
) -> Content {
  self.styled(Property(Property::new(elem, id, value)))
}

///|
/// A square root.
fn impl_math_sqrt(
  span : @syntax.Span,
  radicand_ : Content,
) -> Content raise HintedError {
  Content::new(root_elem(), [(root_elem_radicand, Content(radicand_))]).spanned(
    span,
  )
}

// style.rs
//
// `MathVariant` and `MathSize` values are stored as their kebab-case cast
// names.

///|
fn math_variant(body : Content, variant : String) -> Content {
  body.set(equation_elem(), equation_elem_variant, Str(variant))
}

///|
fn math_size(body : Content, size : String, cramped : Bool) -> Content {
  body
  .set(equation_elem(), equation_elem_size, Str(size))
  .set(equation_elem(), equation_elem_cramped, Bool(cramped))
}

///|
/// Bold font style in math.
fn impl_math_bold(body_ : Content) -> Content raise HintedError {
  body_.set(equation_elem(), equation_elem_bold, Bool(true))
}

///|
/// Italic font style in math.
fn impl_math_italic(body_ : Content) -> Content raise HintedError {
  body_.set(equation_elem(), equation_elem_italic, Bool(true))
}

///|
/// Serif (roman) font style in math.
fn impl_math_serif(body_ : Content) -> Content raise HintedError {
  math_variant(body_, "plain")
}

///|
/// Sans-serif font style in math.
fn impl_math_sans(body_ : Content) -> Content raise HintedError {
  math_variant(body_, "sans-serif")
}

///|
/// Calligraphic (chancery) font style in math.
fn impl_math_cal(body_ : Content) -> Content raise HintedError {
  math_variant(body_, "chancery")
}

///|
/// Script (roundhand) font style in math.
fn impl_math_scr(body_ : Content) -> Content raise HintedError {
  math_variant(body_, "roundhand")
}

///|
/// Fraktur font style in math.
fn impl_math_frak(body_ : Content) -> Content raise HintedError {
  math_variant(body_, "fraktur")
}

///|
/// Monospace font style in math.
fn impl_math_mono(body_ : Content) -> Content raise HintedError {
  math_variant(body_, "monospace")
}

///|
/// Blackboard bold (double-struck) font style in math.
fn impl_math_bb(body_ : Content) -> Content raise HintedError {
  math_variant(body_, "double-struck")
}

///|
/// Forced display style in math.
fn impl_math_display(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  math_size(body_, "display", cramped_)
}

///|
/// Forced inline (text) style in math.
fn impl_math_inline(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  math_size(body_, "text", cramped_)
}

///|
/// Forced script style in math.
fn impl_math_script(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  math_size(body_, "script", cramped_)
}

///|
/// Forced second script style in math.
fn impl_math_sscript(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  math_size(body_, "script-script", cramped_)
}
