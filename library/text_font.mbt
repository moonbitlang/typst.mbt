// Port of the castable value types of `typst-library/src/text/font/`
// (`variant.rs`, `tag.rs`, `variations.rs`). Font loading and selection are
// not ported here.

// variant.rs

///|
/// The style of a font.
pub(all) enum FontStyle {
  /// The default, typically upright style.
  Normal
  /// A cursive style with custom letterform.
  Italic
  /// Just a slanted version of the normal style.
  Oblique
} derive(Eq, Hash, Compare, Debug)

///|
pub impl Default for FontStyle with fn default() {
  Normal
}

///|
pub extend FontStyle with Default::{default}

///|
let font_style_names : ReadOnlyArray[String] = ["normal", "italic", "oblique"]

///|
pub impl Reflect for FontStyle with fn input() {
  str_names_input(font_style_names)
}

///|
pub impl Reflect for FontStyle with fn output() {
  FontStyle::input()
}

///|
pub impl Reflect for FontStyle with fn castable(v) {
  str_names_find(font_style_names, v) is Some(_)
}

///|
pub extend FontStyle with Reflect::{output, input, castable}

///|
pub impl IntoValue for FontStyle with fn into_value(self) {
  Str(
    match self {
      Normal => "normal"
      Italic => "italic"
      Oblique => "oblique"
    },
  )
}

///|
pub extend FontStyle with IntoValue::{into_value}

///|
pub impl FromValue for FontStyle with fn from_value(v) {
  match str_names_find(font_style_names, v) {
    Some(0) => Normal
    Some(1) => Italic
    Some(_) => Oblique
    None => raise HintedError(FontStyle::input().error(v))
  }
}

///|
/// The conceptual distance between the styles, expressed as a number.
pub fn FontStyle::distance(self : FontStyle, other : FontStyle) -> Int {
  if self == other {
    // Both are the same.
    0
  } else if self != Normal && other != Normal {
    // One is italic and one is oblique. Better than if one were normal.
    1
  } else {
    // One is normal and one is italic or oblique.
    2
  }
}

///|
/// The weight of a font (100 - 900).
pub(all) struct FontWeight(Int) derive(Eq, Hash, Compare, Debug)

///|
/// Thin weight (100).
pub let font_weight_thin : FontWeight = FontWeight(100)

///|
/// Extra light weight (200).
pub let font_weight_extralight : FontWeight = FontWeight(200)

///|
/// Light weight (300).
pub let font_weight_light : FontWeight = FontWeight(300)

///|
/// Regular weight (400).
pub let font_weight_regular : FontWeight = FontWeight(400)

///|
/// Medium weight (500).
pub let font_weight_medium : FontWeight = FontWeight(500)

///|
/// Semibold weight (600).
pub let font_weight_semibold : FontWeight = FontWeight(600)

///|
/// Bold weight (700).
pub let font_weight_bold : FontWeight = FontWeight(700)

///|
/// Extrabold weight (800).
pub let font_weight_extrabold : FontWeight = FontWeight(800)

///|
/// Black weight (900).
pub let font_weight_black : FontWeight = FontWeight(900)

///|
let font_weight_names : ReadOnlyArray[String] = [
  "thin", "extralight", "light", "regular", "medium", "semibold", "bold", "extrabold",
  "black",
]

///|
pub impl Default for FontWeight with fn default() {
  font_weight_regular
}

///|
pub extend FontWeight with Default::{default}

///|
/// Create a font weight from a number between 100 and 900, clamping it if
/// necessary.
pub fn FontWeight::from_number(weight : Int) -> FontWeight {
  FontWeight(weight.clamp(min=100, max=900))
}

///|
/// The number between 100 and 900.
pub fn FontWeight::to_number(self : FontWeight) -> Int {
  self.0
}

///|
/// Add (or remove) weight, saturating at the boundaries of 100 and 900.
pub fn FontWeight::thicken(self : FontWeight, delta : Int) -> FontWeight {
  FontWeight((self.0 + delta).clamp(min=100, max=900))
}

///|
/// The absolute number distance between this and another font weight.
pub fn FontWeight::distance(self : FontWeight, other : FontWeight) -> Int {
  (self.0 - other.0).abs()
}

///|
pub impl Reflect for FontWeight with fn input() {
  CastInfo::Type(Type::int()).union_with(str_names_input(font_weight_names))
}

///|
pub impl Reflect for FontWeight with fn output() {
  FontWeight::input()
}

///|
pub impl Reflect for FontWeight with fn castable(v) {
  str_names_find(font_weight_names, v) is Some(_) || v is Int(_)
}

///|
pub extend FontWeight with Reflect::{output, input, castable}

///|
pub impl IntoValue for FontWeight with fn into_value(self) {
  if self.0 % 100 == 0 && self.0 >= 100 && self.0 <= 900 {
    Str(font_weight_names[self.0 / 100 - 1])
  } else {
    Int(self.0.to_int64())
  }
}

///|
pub extend FontWeight with IntoValue::{into_value}

///|
pub impl FromValue for FontWeight with fn from_value(v) {
  match str_names_find(font_weight_names, v) {
    Some(i) => return FontWeight((i + 1) * 100)
    None => ()
  }
  match v {
    Int(i) => FontWeight::from_number(i.clamp(min=0L, max=65535L).to_int())
    v => raise HintedError(FontWeight::input().error(v))
  }
}

///|
pub extend FontWeight with FromValue::{from_value}

///|
/// The width of a font (stored in thousandths, 500 - 2000).
pub(all) struct FontStretch(Int) derive(Eq, Hash, Compare, Debug)

///|
/// Normal stretch (100%).
pub let font_stretch_normal : FontStretch = FontStretch(1000)

///|
pub impl Default for FontStretch with fn default() {
  font_stretch_normal
}

///|
pub extend FontStretch with Default::{default}

///|
/// Create a font stretch from a ratio between 0.5 and 2.0, clamping it if
/// necessary.
pub fn FontStretch::from_ratio(ratio : Ratio) -> FontStretch {
  let r = ratio.get()
  // Rust's `f64::clamp` propagates NaN, which `as u16` maps to zero.
  if r.is_nan() {
    return FontStretch(0)
  }
  let r = if r < 0.5 { 0.5 } else if r > 2.0 { 2.0 } else { r }
  FontStretch((r * 1000.0).to_int())
}

///|
/// The ratio between 0.5 and 2.0 corresponding to this stretch.
pub fn FontStretch::to_ratio(self : FontStretch) -> Ratio {
  Ratio::new(self.0.to_double() / 1000.0)
}

///|
pub fn FontStretch::repr(self : FontStretch) -> String {
  self.to_ratio().repr()
}

///|
pub impl Reflect for FontStretch with fn input() {
  Type(Type::ratio())
}

///|
pub impl Reflect for FontStretch with fn output() {
  Type(Type::ratio())
}

///|
pub impl Reflect for FontStretch with fn castable(v) {
  v is Ratio(_)
}

///|
pub extend FontStretch with Reflect::{output, input, castable}

///|
pub impl IntoValue for FontStretch with fn into_value(self) {
  Ratio(self.to_ratio())
}

///|
pub extend FontStretch with IntoValue::{into_value}

///|
pub impl FromValue for FontStretch with fn from_value(v) {
  match v {
    Ratio(r) => FontStretch::from_ratio(r)
    v => raise HintedError(FontStretch::input().error(v))
  }
}

// tag.rs

///|
/// A 4-byte OpenType tag (stored as its four printable ASCII characters).
///
/// Upstream `ttf_parser::Tag`; renamed because `Tag` is the introspection
/// tag of `introspection/tag.rs`.
pub(all) struct OpenTypeTag(String) derive(Eq, Hash, Compare, Debug)

///|
/// Creates a new tag from any number of bytes, padding with spaces.
pub fn OpenTypeTag::from_bytes_lossy(bytes : String) -> OpenTypeTag {
  let buf = StringBuilder()
  for i in 0..<4 {
    if i < bytes.length() {
      buf.write_char(bytes.unsafe_get(i).unsafe_to_char())
    } else {
      buf.write_char(' ')
    }
  }
  OpenTypeTag(buf.to_string())
}

///|
/// Turns this into a string.
pub fn OpenTypeTag::to_str_lossy(self : OpenTypeTag) -> String {
  self.0
}

///|
pub impl Reflect for OpenTypeTag with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for OpenTypeTag with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for OpenTypeTag with fn castable(v) {
  str_castable(v)
}

///|
pub extend OpenTypeTag with Reflect::{output, input, castable}

///|
pub impl IntoValue for OpenTypeTag with fn into_value(self) {
  Str(self.0)
}

///|
// Tags must: https://learn.microsoft.com/en-us/typography/opentype/spec/otff#data-types
// - be one to four bytes in length
// - be representable as printable ASCII (0x20..=0x7E)
// - contain at least one character that isn't padding (0x20, space)
// - padding may only appear at the end of a tag
pub impl FromValue for OpenTypeTag with fn from_value(v) {
  if !str_castable(v) {
    raise HintedError(OpenTypeTag::input().error(v))
  }
  let v : String = (FromValue::from_value(v) : String)
  for cluster in @unicode.graphemes(v) {
    if !cluster.iter().all(c => c.to_int() >= 0x20 && c.to_int() <= 0x7E) {
      bail_hinted("tag may contain only printable ASCII characters", [
        "found invalid cluster `\{repr_str(cluster.to_owned())}`",
      ])
    }
  }
  // All characters are ASCII, so the length in bytes is the string length.
  let len = v.length()
  if !(len >= 1 && len <= 4) {
    bail_hinted("tag must be one to four characters in length", [
      "found \{len} characters",
    ])
  }
  let mut within_padding = false
  for i, c in v.to_array() {
    if (within_padding && c != ' ') || (i == 0 && c == ' ') {
      bail("spaces may only appear as padding following a tag")
    }
    within_padding = within_padding || c == ' '
  }
  OpenTypeTag::from_bytes_lossy(v)
}

///|
pub extend OpenTypeTag with FromValue::{from_value}

// variations.rs

///|
/// A value for a font variation axis (an `f32` upstream).
pub(all) struct AxisValue(Double) derive(Eq, Hash, Debug)

///|
pub impl Reflect for AxisValue with fn input() {
  Type(Type::float())
}

///|
pub impl Reflect for AxisValue with fn output() {
  Type(Type::float())
}

///|
pub impl Reflect for AxisValue with fn castable(v) {
  v is (Float(_) | Int(_))
}

///|
pub impl IntoValue for AxisValue with fn into_value(self) {
  Float(self.0)
}

///|
pub extend AxisValue with IntoValue::{into_value}

///|
pub impl FromValue for AxisValue with fn from_value(v) {
  let f : Double = (FromValue::from_value(v) : Double)
  // Round to `f32` precision like upstream's `v as f32`.
  AxisValue(Float::from_double(f).to_double())
}

///|
pub extend AxisValue with FromValue::{from_value}

///|
/// OpenType font variation settings.
pub(all) struct FontVariations(Array[(OpenTypeTag, AxisValue)]) derive (
  Eq,
  Hash,
  Debug,
)

///|
pub impl Default for FontVariations with fn default() {
  FontVariations([])
}

///|
pub extend FontVariations with Default::{default}

///|
pub impl Fold for FontVariations with fn fold(self, outer) {
  FontVariations(outer.0 + self.0)
}

///|
pub impl Reflect for FontVariations with fn input() {
  Type(Type::dict())
}

///|
pub impl Reflect for FontVariations with fn output() {
  Type(Type::dict())
}

///|
pub impl Reflect for FontVariations with fn castable(v) {
  v is Dict(_)
}

///|
pub extend FontVariations with Reflect::{output, input, castable}

///|
pub impl IntoValue for FontVariations with fn into_value(self) {
  let dict = Dict::new()
  for pair in self.0 {
    dict.insert(pair.0.to_str_lossy(), pair.1.into_value())
  }
  Dict(dict)
}

///|
pub extend FontVariations with IntoValue::{into_value}

///|
pub impl FromValue for FontVariations with fn from_value(v) {
  match v {
    Dict(values) => {
      let out = []
      let mut i = 0
      for k, v in values.map {
        let hint = tag_hint_helper(i, repr_str(k))
        let tag : OpenTypeTag = with_err_hint(
          () => OpenTypeTag::from_value(Str(k)),
          hint,
        )
        let value : AxisValue = with_err_hint(
          () => AxisValue::from_value(v),
          hint,
        )
        out.push((tag, value))
        i += 1
      }
      FontVariations(out)
    }
    v => raise HintedError(FontVariations::input().error(v))
  }
}

///|
fn tag_hint_helper(index : Int, key_repr : String) -> String {
  "occurred in tag at index \{index} (`\{key_repr}`)"
}
