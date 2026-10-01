// Port of `typst-assets/src/html.rs` (rev pinned in `oracle/Cargo.toml`):
// data describing HTML elements and attributes and how the attributes map to
// Typst types. The data itself (`elems`, `attrs`, `attrs_global`,
// `attr_strings`) is generated into `data_gen.mbt` by
// `oracle/src/bin/gen_html.rs` from the very same crate.

///|
/// Details about an HTML element.
pub struct ElemInfo {
  /// The element's tag name.
  name : String
  /// A description for the element.
  docs : String
  /// Indices of the element's attributes in `attrs()`.
  attrs : Array[Int]
}

///|
/// Creates element information from its parts.
///
/// The `attrs` slice consists of indices pointing into `attrs()`. It must be
/// sorted by index (and, by extension, also by name of the pointed-to
/// attributes because the attributes themselves are sorted).
pub fn ElemInfo::new(
  name : String,
  docs : String,
  attrs : Array[Int],
) -> ElemInfo {
  { name, docs, attrs, }
}

///|
/// Iterates over all attributes an element of this type can have (both
/// specific and global).
pub fn ElemInfo::attributes(self : ElemInfo) -> Array[AttrInfo] {
  let table = attrs()
  let out = self.attrs.map(i => table[i])
  for i in 0..<attrs_global {
    out.push(table[i])
  }
  out
}

///|
/// Provides metadata for an attribute with the given name if it exists for
/// this element. The attribute may be specific or global.
pub fn ElemInfo::get_attr(self : ElemInfo, name : String) -> AttrInfo? {
  let i = match self.get_specific_attr(name) {
    Some(i) => Some(i)
    None => get_global_attr(name)
  }
  i.map(i => attrs()[i])
}

///|
/// Tries to locate the index of a specific attribute in `attrs()`.
fn ElemInfo::get_specific_attr(self : ElemInfo, name : String) -> Int? {
  let table = attrs()
  match self.attrs.binary_search_by(i => lex_compare(table[i].name, name)) {
    Ok(k) => Some(self.attrs[k])
    Err(_) => None
  }
}

///|
/// Tries to locate the index of a global attribute in `attrs()`.
fn get_global_attr(name : String) -> Int? {
  let table = attrs()
  match
    table[0:attrs_global].binary_search_by(attr => lex_compare(attr.name, name)) {
    Ok(i) => Some(i)
    Err(_) => None
  }
}

///|
/// Details about an HTML attribute.
pub struct AttrInfo {
  /// The attribute's name.
  name : String
  /// A description for the attribute.
  docs : String
  /// Type information for the attribute.
  ty : Type
}

///|
/// Creates attribute information from its parts.
pub fn AttrInfo::new(name : String, docs : String, ty : Type) -> AttrInfo {
  { name, docs, ty, }
}

///|
/// Defines how an attribute maps to Typst types.
///
/// Each variant's documentation describes which Typst type is accepted and
/// into what kind of HTML attribute string it is converted.
pub(all) enum Type {
  /// `bool` → attribute is present or absent.
  Presence
  /// `none` → `"none"`. (upstream `None`)
  None_
  /// `none` → `""`.
  NoneEmpty
  /// `none` → `"undefined"`.
  NoneUndefined
  /// `auto` → `"auto"`.
  Auto
  /// `boolean` → `"true"` or `"false"`.
  TrueFalse
  /// `boolean` → `"yes"` or `"no"`.
  YesNo
  /// `boolean` → `"on"` or `"off"`.
  OnOff
  /// `ltr` or `rtl` → `"ltr"` or `"rtl"`.
  HorizontalDir
  /// `string` → string.
  Str
  /// `char` → string.
  Char
  /// `int` → stringified int.
  Int
  /// `int >= 0` → stringified int.
  NonNegativeInt
  /// `int > 0` → stringified int.
  PositiveInt
  /// `float` → stringified float.
  Float
  /// `float` > 0 → stringified float.
  PositiveFloat
  /// `datetime` → stringified datetime.
  Datetime
  /// `duration` → stringified duration.
  Duration
  /// `color` → stringified CSS color.
  Color
  /// `array (w, h)` of two `int >= 0` → `"{w}x{h}"`.
  IconSize
  /// `dictionary` with keys `src` (string) and optionally `width` (int) or
  /// `density` (positive float) → `"{src}"` plus optionally space-separated
  /// `"{width}w"` or `{density}d`.
  ImageCandidate
  /// `dictionary` with keys `condition` (string) and `size` (length) →
  /// `"({condition}) {size}"`
  SourceSize
  /// For `Strings(a, b)`, any of the strings in `attr_strings()[a:b]` →
  /// string.
  Strings(Int, Int)
  /// Any of the listed types → the respective output.
  Union(Array[Type])
  /// An array of the listed type, or, if the bool is true, the listed type
  /// itself as a shorthand → a string containing the respective outputs
  /// separated by the char.
  List(Type, Char, Bool)
} derive(Eq, Debug)

///|
/// Lexicographic comparison of (ASCII) names, like Rust's `str` ordering
/// (MoonBit's `String::compare` orders by length first).
fn lex_compare(a : String, b : String) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let order = a.code_unit_at(i).compare(b.code_unit_at(i))
    if order != 0 {
      return order
    }
  }
  a.length().compare(b.length())
}
