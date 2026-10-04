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

///|
fn math_variant(body : Content, variant : MathVariant) -> Content {
  body.set(
    equation_elem(),
    equation_elem_variant,
    IntoValue::into_value(Some(variant)),
  )
}

///|
fn math_size(body : Content, size : MathSize, cramped : Bool) -> Content {
  body
  .set(equation_elem(), equation_elem_size, size.into_value())
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
  math_variant(body_, Plain)
}

///|
/// Sans-serif font style in math.
fn impl_math_sans(body_ : Content) -> Content raise HintedError {
  math_variant(body_, SansSerif)
}

///|
/// Calligraphic (chancery) font style in math.
fn impl_math_cal(body_ : Content) -> Content raise HintedError {
  math_variant(body_, Chancery)
}

///|
/// Script (roundhand) font style in math.
fn impl_math_scr(body_ : Content) -> Content raise HintedError {
  math_variant(body_, Roundhand)
}

///|
/// Fraktur font style in math.
fn impl_math_frak(body_ : Content) -> Content raise HintedError {
  math_variant(body_, Fraktur)
}

///|
/// Monospace font style in math.
fn impl_math_mono(body_ : Content) -> Content raise HintedError {
  math_variant(body_, Monospace)
}

///|
/// Blackboard bold (double-struck) font style in math.
fn impl_math_bb(body_ : Content) -> Content raise HintedError {
  math_variant(body_, DoubleStruck)
}

///|
/// Forced display style in math.
fn impl_math_display(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  math_size(body_, Display, cramped_)
}

///|
/// Forced inline (text) style in math.
fn impl_math_inline(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  math_size(body_, Text, cramped_)
}

///|
/// Forced script style in math.
fn impl_math_script(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  math_size(body_, Script, cramped_)
}

///|
/// Forced second script style in math.
fn impl_math_sscript(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  math_size(body_, ScriptScript, cramped_)
}

///|
/// The size of elements in an equation.
///
/// See the TeXbook p. 141.
pub(all) enum MathSize {
  /// Second-level sub- and superscripts.
  ScriptScript
  /// Sub- and superscripts.
  Script
  /// Math in text.
  Text
  /// Math on its own line.
  Display
} derive(Eq, Hash, Compare, Debug)

///|
fn equation_elem_size_default() -> Value {
  MathSize::Text.into_value()
}

///|
pub impl Reflect for MathSize with fn input() {
  Union([
    Value(Str("script-script"), "Second-level sub- and superscripts."),
    Value(Str("script"), "Sub- and superscripts."),
    Value(Str("text"), "Math in text."),
    Value(Str("display"), "Math on its own line."),
  ])
}

///|
pub impl Reflect for MathSize with fn output() {
  MathSize::input()
}

///|
pub impl Reflect for MathSize with fn castable(v) {
  v is Str("script-script" | "script" | "text" | "display")
}

///|
pub impl IntoValue for MathSize with fn into_value(self) {
  match self {
    ScriptScript => Str("script-script")
    Script => Str("script")
    Text => Str("text")
    Display => Str("display")
  }
}

///|
pub impl FromValue for MathSize with fn from_value(v) {
  match v {
    Str("script-script") => ScriptScript
    Str("script") => Script
    Str("text") => Text
    Str("display") => Display
    v => raise HintedError(MathSize::input().error(v))
  }
}

///|
/// Base math styles used in Typst (upstream `codex::styling::MathVariant`).
pub(all) enum MathVariant {
  Plain
  Fraktur
  SansSerif
  Monospace
  DoubleStruck
  Chancery
  Roundhand
} derive(Eq, Hash, Debug)

// Upstream `MathVariant` has no cast: it is only stored in the internal
// `EquationElem::variant` field and never exposed to users. Its value form
// here is the kebab-case name of the variant.

///|
fn MathVariant::name(self : MathVariant) -> String {
  match self {
    Plain => "plain"
    Fraktur => "fraktur"
    SansSerif => "sans-serif"
    Monospace => "monospace"
    DoubleStruck => "double-struck"
    Chancery => "chancery"
    Roundhand => "roundhand"
  }
}

///|
let math_variants : ReadOnlyArray[MathVariant] = [
  Plain,
  Fraktur,
  SansSerif,
  Monospace,
  DoubleStruck,
  Chancery,
  Roundhand,
]

///|
pub impl Reflect for MathVariant with fn input() {
  str_names_input(math_variants.map(v => v.name()))
}

///|
pub impl Reflect for MathVariant with fn output() {
  MathVariant::input()
}

///|
pub impl Reflect for MathVariant with fn castable(v) {
  math_variants.iter().any(variant => v is Str(s) && s == variant.name())
}

///|
pub impl IntoValue for MathVariant with fn into_value(self) {
  Str(self.name())
}

///|
pub impl FromValue for MathVariant with fn from_value(v) {
  for variant in math_variants[:] {
    if v is Str(s) && s == variant.name() {
      return variant
    }
  }
  raise HintedError(MathVariant::input().error(v))
}

///|
/// `(i16, i16)` (the internal `EquationElem::script_scale` field), cast like
/// upstream's tuple-free storage as a two-element array.
pub impl[A : Reflect, B : Reflect] Reflect for (A, B) with fn input() {
  Type(Type::array())
}

///|
pub impl[A : Reflect, B : Reflect] Reflect for (A, B) with fn output() {
  Type(Type::array())
}

///|
pub impl[A : Reflect, B : Reflect] Reflect for (A, B) with fn castable(v) {
  v is Array(_)
}

///|
pub impl[A : IntoValue, B : IntoValue] IntoValue for (A, B) with fn into_value(
  self,
) {
  Array(
    Arr::from_array([
      IntoValue::into_value(self.0),
      IntoValue::into_value(self.1),
    ]),
  )
}

///|
pub impl[A : FromValue, B : FromValue] FromValue for (A, B) with fn from_value(
  v,
) {
  match v {
    Array(arr) if arr.len() == 2 => {
      let items = arr.iter().collect()
      (A::from_value(items[0]), B::from_value(items[1]))
    }
    v => raise HintedError(CastInfo::Type(Type::array()).error(v))
  }
}

///|
fn equation_elem_script_scale_default() -> Value {
  IntoValue::into_value((I16(70L), I16(50L)))
}

///|
/// Sets flac OpenType feature.
pub fn style_flac() -> Style {
  TextElem::set_features(
    FontFeatures([(OpenTypeTag::from_bytes_lossy("flac"), 1L)]),
  )
}

///|
/// Sets dtls OpenType feature.
pub fn style_dtls() -> Style {
  TextElem::set_features(
    FontFeatures([(OpenTypeTag::from_bytes_lossy("dtls"), 1L)]),
  )
}

///|
/// Styles something as cramped.
///
/// This is equivalent (in MathML Core) to the following CSS:
/// `math-shift: compact;`
pub fn style_cramped() -> Style {
  EquationElem::set_cramped(true)
}

///|
/// The style for superscripts in the current style.
///
/// This is equivalent (in MathML Core) to the following CSS:
/// `math-style: compact; math-depth: add(1);`
pub fn style_for_superscript(styles : StyleChain) -> Style {
  EquationElem::set_size(
    match EquationElem::size_in(styles) {
      Display | Text => Script
      Script | ScriptScript => ScriptScript
    },
  )
}

///|
/// The style for subscripts in the current style.
///
/// This is equivalent (in MathML Core) to the following CSS:
/// `math-style: compact; math-depth: add(1); math-shift: compact;`
pub fn style_for_subscript(styles : StyleChain) -> Styles {
  Styles::from_array([style_for_superscript(styles), style_cramped()])
}

///|
/// The style for numerators in the current style.
///
/// This is equivalent (in MathML Core) to the following CSS:
/// `math-style: compact; math-depth: auto-add;`
pub fn style_for_numerator(styles : StyleChain) -> Style {
  EquationElem::set_size(
    match EquationElem::size_in(styles) {
      Display => Text
      Text => Script
      Script | ScriptScript => ScriptScript
    },
  )
}

///|
/// The style for denominators in the current style.
///
/// This is equivalent (in MathML Core) to the following CSS:
/// `math-style: compact; math-depth: auto-add; math-shift: compact;`
pub fn style_for_denominator(styles : StyleChain) -> Styles {
  Styles::from_array([style_for_numerator(styles), style_cramped()])
}
