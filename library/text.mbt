// Port of the castable value types of `typst-library/src/text/mod.rs` and
// the `TextElem` field hooks (defaults, folds, `#[parse]`). Font selection,
// shaping and other layout-time helpers are not ported here.

// FontFamily, Covers, FontList

///|
/// A lowercased font family like "arial".
pub(all) struct FontFamily {
  /// The name of the font family.
  name : String
  /// A regex that defines the Unicode codepoints supported by the font.
  covers : Covers?
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFamily with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFamily with Hash::{hash, hash_combine}

///|
/// Create a named font family variant.
pub fn FontFamily::new(string : String) -> FontFamily {
  FontFamily::with_coverage(string, None)
}

///|
/// Create a font family by name and optional Unicode coverage.
pub fn FontFamily::with_coverage(
  string : String,
  covers : Covers?,
) -> FontFamily {
  { name: string.to_lower(), covers, }
}

///|
/// The lowercased family name.
pub fn FontFamily::as_str(self : FontFamily) -> String {
  self.name
}

///|
pub impl Reflect for FontFamily with fn input() {
  CastInfo::Type(Type::str()).union_with(Type(Type::dict()))
}

///|
pub impl Reflect for FontFamily with fn output() {
  FontFamily::input()
}

///|
pub impl Reflect for FontFamily with fn castable(v) {
  str_castable(v) || v is Dict(_)
}

///|
pub extend FontFamily with Reflect::{output, input, castable}

///|
pub impl IntoValue for FontFamily with fn into_value(self) {
  match self.covers {
    Some(covers) =>
      Dict(
        Dict::from_pairs([
          ("name", Str(self.name)),
          ("covers", covers.into_value()),
        ]),
      )
    None => Str(self.name)
  }
}

///|
pub extend FontFamily with IntoValue::{into_value}

///|
pub impl FromValue for FontFamily with fn from_value(v) {
  if str_castable(v) {
    let string : String = (FromValue::from_value(v) : String)
    return FontFamily::new(string)
  }
  match v {
    Dict(v) => {
      let v = v.copy()
      let name : String = v.take("name").cast()
      let covers : Covers? = dict_take_cast(v, "covers")
      let ret = FontFamily::with_coverage(name, covers)
      v.finish(["name", "covers"])
      ret
    }
    v => raise HintedError(FontFamily::input().error(v))
  }
}

///|
pub extend FontFamily with FromValue::{from_value}

///|
/// Defines which codepoints a font family will be used for.
pub(all) enum Covers {
  /// Covers all codepoints except those used both in Latin and CJK fonts.
  LatinInCjk
  /// Covers the set of codepoints for which the regex matches.
  Regex(Regex)
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Covers with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Covers with Hash::{hash, hash_combine}

///|
pub impl Reflect for Covers with fn input() {
  CastInfo::Value(
    Str("latin-in-cjk"),
    "Covers all codepoints except those used both in Latin and CJK fonts.",
  ).union_with(Type(Type::regex()))
}

///|
pub impl Reflect for Covers with fn output() {
  Covers::input()
}

///|
pub impl Reflect for Covers with fn castable(v) {
  v is (Str("latin-in-cjk") | Dyn(Regex(_)))
}

///|
pub extend Covers with Reflect::{output, input, castable}

///|
pub impl IntoValue for Covers with fn into_value(self) {
  match self {
    LatinInCjk => Str("latin-in-cjk")
    Regex(regex) => Dyn(Regex(regex))
  }
}

///|
pub extend Covers with IntoValue::{into_value}

///|
pub impl FromValue for Covers with fn from_value(v) {
  match v {
    Str("latin-in-cjk") => LatinInCjk
    Dyn(Regex(regex)) => {
      if !@regex.ast_is_single_char(regex.as_str()) {
        raise HintedError(
          HintedString::new(
            "coverage regex may only use dot, letters, and character classes",
          ).with_hint("the regex is applied to each letter individually"),
        )
      }
      Regex(regex)
    }
    v => raise HintedError(Covers::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Covers with FromValue::{from_value}

///|
/// Font family fallback list.
///
/// Must contain at least one font.
pub(all) struct FontList(Array[FontFamily]) derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontList with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontList with Hash::{hash, hash_combine}

///|
pub fn FontList::new(fonts : Array[FontFamily]) -> FontList raise HintedError {
  if fonts.is_empty() {
    bail("font fallback list must not be empty")
  } else {
    FontList(fonts)
  }
}

///|
pub impl Reflect for FontList with fn input() {
  FontFamily::input().union_with(Type(Type::array()))
}

///|
pub impl Reflect for FontList with fn output() {
  FontList::input()
}

///|
pub impl Reflect for FontList with fn castable(v) {
  FontFamily::castable(v) || v is Array(_)
}

///|
pub extend FontList with Reflect::{output, input, castable}

///|
pub impl IntoValue for FontList with fn into_value(self) {
  if self.0.length() == 1 {
    self.0[0].into_value()
  } else {
    IntoValue::into_value(self.0)
  }
}

///|
pub extend FontList with IntoValue::{into_value}

///|
pub impl FromValue for FontList with fn from_value(v) {
  if FontFamily::castable(v) {
    return FontList([FontFamily::from_value(v)])
  }
  match v {
    Array(values) =>
      FontList::new(values.items.map(v => FontFamily::from_value(v)))
    v => raise HintedError(FontList::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontList with FromValue::{from_value}

///|
/// The default font list (upstream
/// `FontList(vec![FontFamily::new("Libertinus Serif")])`).
let text_elem_font_default_value : Value = FontList([
    FontFamily::new("Libertinus Serif"),
  ])
  .into_value()
  .shared()

///|
/// The default is built once and shared (marked shared, so that mutating a
/// copy of it copies first, see [Value::shared]): it was rebuilt on every
/// style lookup of the field (performance).
fn text_elem_font_default() -> Value {
  text_elem_font_default_value
}

///|
fn text_elem_font_parse(
  engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let font_list : @syntax.Spanned[FontList]? = args.named_spanned("font")
  if font_list is Some(list) {
    check_font_list(engine, list)
  }
  font_list.map(list => list.v.into_value())
}

///|
/// Checks for font families that are not available.
fn check_font_list(engine : Engine, list : @syntax.Spanned[FontList]) -> Unit {
  let book = engine.world.book()
  for family in list.v.0 {
    if book.select_family(family.as_str()).is_empty() {
      engine.sink.warn(
        SourceDiagnostic::warning_at(
          list.span,
          "unknown font family: \{family.as_str()}",
        ),
      )
    }
  }
}

// FontStyle, FontWeight, FontStretch (see text_font.mbt)

///|
fn text_elem_style_default() -> Value {
  FontStyle::default().into_value()
}

///|
fn text_elem_weight_default() -> Value {
  FontWeight::default().into_value()
}

///|
fn text_elem_stretch_default() -> Value {
  FontStretch::default().into_value()
}

// TextSize

///|
/// The size of text.
pub(all) struct TextSize(Length) derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextSize with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextSize with Hash::{hash, hash_combine}

///|
pub impl Fold for TextSize with fn fold(self, outer) {
  // Multiply the two linear functions.
  TextSize({
    em: Em::new(self.0.em.get() * outer.0.em.get()),
    abs: outer.0.abs.times(self.0.em.get()) + self.0.abs,
  })
}

///|
pub extend TextSize with Fold::{fold}

///|
/// Upstream `Resolve for TextSize`.
pub fn TextSize::resolve(self : TextSize, styles : StyleChain) -> Abs {
  let factor = match EquationElem::size_in(styles) {
    Display | Text => 1.0
    Script => EquationElem::script_scale_in(styles).0.0.to_double() / 100.0
    ScriptScript =>
      EquationElem::script_scale_in(styles).1.0.to_double() / 100.0
  }
  self.0.resolve(styles).times(factor)
}

///|
pub impl Reflect for TextSize with fn input() {
  Type(Type::length())
}

///|
pub impl Reflect for TextSize with fn output() {
  Type(Type::length())
}

///|
pub impl Reflect for TextSize with fn castable(v) {
  v is Length(_)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextSize with Reflect::{output, input, castable}

///|
pub impl IntoValue for TextSize with fn into_value(self) {
  Length(self.0)
}

///|
pub extend TextSize with IntoValue::{into_value}

///|
pub impl FromValue for TextSize with fn from_value(v) {
  TextSize(Length::from_value(v))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextSize with FromValue::{from_value}

///|
let text_elem_size_default_value : Value = TextSize(
    Length::from_abs(Abs::pt(11.0)),
  )
  .into_value()
  .shared()

///|
/// The default is built once and shared (marked shared, so that mutating a
/// copy of it copies first, see [Value::shared]): it was rebuilt on every
/// style lookup of the field (performance).
fn text_elem_size_default() -> Value {
  text_elem_size_default_value
}

///|
fn text_elem_size_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[TextSize]), inner, outer)
}

// TopEdge, BottomEdge

///|
/// Specifies the top edge of text.
pub(all) enum TopEdge {
  /// An edge specified via font metrics or bounding box.
  Metric(TopEdgeMetric)
  /// An edge specified as a length.
  Length(Length)
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TopEdge with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TopEdge with Hash::{hash, hash_combine}

///|
pub impl Reflect for TopEdge with fn input() {
  TopEdgeMetric::input().union_with(Type(Type::length()))
}

///|
pub impl Reflect for TopEdge with fn output() {
  TopEdge::input()
}

///|
pub impl Reflect for TopEdge with fn castable(v) {
  TopEdgeMetric::castable(v) || v is Length(_)
}

///|
pub extend TopEdge with Reflect::{output, input, castable}

///|
pub impl IntoValue for TopEdge with fn into_value(self) {
  match self {
    Metric(metric) => metric.into_value()
    Length(length) => Length(length)
  }
}

///|
pub extend TopEdge with IntoValue::{into_value}

///|
pub impl FromValue for TopEdge with fn from_value(v) {
  if TopEdgeMetric::castable(v) {
    return Metric(TopEdgeMetric::from_value(v))
  }
  match v {
    Length(l) => Length(l)
    v => raise HintedError(TopEdge::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TopEdge with FromValue::{from_value}

///|
/// Metrics that describe the top edge of text.
pub(all) enum TopEdgeMetric {
  /// The font's ascender, which typically exceeds the height of all glyphs.
  Ascender
  /// The approximate height of uppercase letters.
  CapHeight
  /// The approximate height of non-ascending lowercase letters.
  XHeight
  /// The baseline on which the letters rest.
  Baseline
  /// The top edge of the glyph's bounding box.
  Bounds
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TopEdgeMetric with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TopEdgeMetric with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TopEdgeMetric with @debug.Debug::{to_repr}

///|
let top_edge_metric_names : ReadOnlyArray[String] = [
  "ascender", "cap-height", "x-height", "baseline", "bounds",
]

///|
let top_edge_metric_values : ReadOnlyArray[TopEdgeMetric] = [
  Ascender,
  CapHeight,
  XHeight,
  Baseline,
  Bounds,
]

///|
pub impl Reflect for TopEdgeMetric with fn input() {
  str_names_input(top_edge_metric_names)
}

///|
pub impl Reflect for TopEdgeMetric with fn output() {
  TopEdgeMetric::input()
}

///|
pub impl Reflect for TopEdgeMetric with fn castable(v) {
  str_names_find(top_edge_metric_names, v) is Some(_)
}

///|
pub extend TopEdgeMetric with Reflect::{output, input, castable}

///|
pub impl IntoValue for TopEdgeMetric with fn into_value(self) {
  for i, m in top_edge_metric_values[:] {
    if m == self {
      return Str(top_edge_metric_names[i])
    }
  }
  None
}

///|
pub extend TopEdgeMetric with IntoValue::{into_value}

///|
pub impl FromValue for TopEdgeMetric with fn from_value(v) {
  match str_names_find(top_edge_metric_names, v) {
    Some(i) => top_edge_metric_values[i]
    None => raise HintedError(TopEdgeMetric::input().error(v))
  }
}

///|
pub extend TopEdgeMetric with FromValue::{from_value}

///|
fn text_elem_top_edge_default() -> Value {
  TopEdge::Metric(CapHeight).into_value()
}

///|
/// Specifies the bottom edge of text.
pub(all) enum BottomEdge {
  /// An edge specified via font metrics or bounding box.
  Metric(BottomEdgeMetric)
  /// An edge specified as a length.
  Length(Length)
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BottomEdge with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BottomEdge with Hash::{hash, hash_combine}

///|
pub impl Reflect for BottomEdge with fn input() {
  BottomEdgeMetric::input().union_with(Type(Type::length()))
}

///|
pub impl Reflect for BottomEdge with fn output() {
  BottomEdge::input()
}

///|
pub impl Reflect for BottomEdge with fn castable(v) {
  BottomEdgeMetric::castable(v) || v is Length(_)
}

///|
pub extend BottomEdge with Reflect::{output, input, castable}

///|
pub impl IntoValue for BottomEdge with fn into_value(self) {
  match self {
    Metric(metric) => metric.into_value()
    Length(length) => Length(length)
  }
}

///|
pub extend BottomEdge with IntoValue::{into_value}

///|
pub impl FromValue for BottomEdge with fn from_value(v) {
  if BottomEdgeMetric::castable(v) {
    return Metric(BottomEdgeMetric::from_value(v))
  }
  match v {
    Length(l) => Length(l)
    v => raise HintedError(BottomEdge::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BottomEdge with FromValue::{from_value}

///|
/// Metrics that describe the bottom edge of text.
pub(all) enum BottomEdgeMetric {
  /// The baseline on which the letters rest.
  Baseline
  /// The font's descender, which typically exceeds the depth of all glyphs.
  Descender
  /// The bottom edge of the glyph's bounding box.
  Bounds
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BottomEdgeMetric with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BottomEdgeMetric with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BottomEdgeMetric with @debug.Debug::{to_repr}

///|
let bottom_edge_metric_names : ReadOnlyArray[String] = [
  "baseline", "descender", "bounds",
]

///|
let bottom_edge_metric_values : ReadOnlyArray[BottomEdgeMetric] = [
  Baseline,
  Descender,
  Bounds,
]

///|
pub impl Reflect for BottomEdgeMetric with fn input() {
  str_names_input(bottom_edge_metric_names)
}

///|
pub impl Reflect for BottomEdgeMetric with fn output() {
  BottomEdgeMetric::input()
}

///|
pub impl Reflect for BottomEdgeMetric with fn castable(v) {
  str_names_find(bottom_edge_metric_names, v) is Some(_)
}

///|
pub extend BottomEdgeMetric with Reflect::{output, input, castable}

///|
pub impl IntoValue for BottomEdgeMetric with fn into_value(self) {
  for i, m in bottom_edge_metric_values[:] {
    if m == self {
      return Str(bottom_edge_metric_names[i])
    }
  }
  None
}

///|
pub extend BottomEdgeMetric with IntoValue::{into_value}

///|
pub impl FromValue for BottomEdgeMetric with fn from_value(v) {
  match str_names_find(bottom_edge_metric_names, v) {
    Some(i) => bottom_edge_metric_values[i]
    None => raise HintedError(BottomEdgeMetric::input().error(v))
  }
}

///|
pub extend BottomEdgeMetric with FromValue::{from_value}

///|
fn text_elem_bottom_edge_default() -> Value {
  BottomEdge::Metric(Baseline).into_value()
}

// TextDir

///|
/// The direction of text and inline objects in their line.
pub(all) struct TextDir(Smart[Dir]) derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextDir with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextDir with Hash::{hash, hash_combine}

///|
pub impl Reflect for TextDir with fn input() {
  input_of((Ty::new() : Ty[Smart[Dir]]))
}

///|
pub impl Reflect for TextDir with fn output() {
  TextDir::input()
}

///|
pub impl Reflect for TextDir with fn castable(v) {
  v is Auto || Dir::castable(v)
}

///|
pub extend TextDir with Reflect::{output, input, castable}

///|
pub impl IntoValue for TextDir with fn into_value(self) {
  self.0.into_value()
}

///|
pub extend TextDir with IntoValue::{into_value}

///|
pub impl FromValue for TextDir with fn from_value(v) {
  let v : Smart[Dir] = Smart::from_value(v)
  if v.is_custom_and(dir => dir.axis() == Y) {
    bail("text direction must be horizontal")
  }
  TextDir(v)
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextDir with FromValue::{from_value}

///|
fn text_elem_dir_default() -> Value {
  TextDir(Auto).into_value()
}

// Alternates, StylisticSets

///|
/// A selection into the Stylistic Alternates.
pub(all) struct Alternates(Int64) derive(Eq, Hash, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Alternates with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Alternates with Hash::{hash, hash_combine}

///|
pub extend Alternates with Default::{default}

///|
pub impl Reflect for Alternates with fn input() {
  CastInfo::Type(Type::bool()).union_with(Type(Type::int()))
}

///|
pub impl Reflect for Alternates with fn output() {
  Alternates::input()
}

///|
pub impl Reflect for Alternates with fn castable(v) {
  v is (Bool(_) | Int(_))
}

///|
pub extend Alternates with Reflect::{output, input, castable}

///|
pub impl IntoValue for Alternates with fn into_value(self) {
  Int(self.0)
}

///|
pub extend Alternates with IntoValue::{into_value}

///|
pub impl FromValue for Alternates with fn from_value(v) {
  match v {
    Bool(b) => Alternates(if b { 1 } else { 0 })
    Int(_) => Alternates(U32::from_value(v).0)
    v => raise HintedError(Alternates::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Alternates with FromValue::{from_value}

///|
fn text_elem_alternates_default() -> Value {
  Alternates::default().into_value()
}

///|
/// A set of stylistic sets to enable.
pub(all) struct StylisticSets(Int) derive(Eq, Hash, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StylisticSets with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StylisticSets with Hash::{hash, hash_combine}

///|
pub extend StylisticSets with Default::{default}

///|
/// Returns whether this set contains a particular stylistic set.
pub fn StylisticSets::has(self : StylisticSets, ss : Int) -> Bool {
  (self.0 & (1 << ss)) != 0
}

///|
/// Returns all stylistic sets to enable.
pub fn StylisticSets::sets(self : StylisticSets) -> Array[Int] {
  let out = []
  for i in 1..<=20 {
    if self.has(i) {
      out.push(i)
    }
  }
  out
}

///|
pub impl Reflect for StylisticSets with fn input() {
  CastInfo::Type(Type::none())
  .union_with(Type(Type::int()))
  .union_with(Type(Type::array()))
}

///|
pub impl Reflect for StylisticSets with fn output() {
  StylisticSets::input()
}

///|
pub impl Reflect for StylisticSets with fn castable(v) {
  v is (None | Int(_) | Array(_))
}

///|
pub extend StylisticSets with Reflect::{output, input, castable}

///|
pub impl IntoValue for StylisticSets with fn into_value(self) {
  Array(Arr::from_array(self.sets().map(i => Int(i.to_int64()))))
}

///|
pub extend StylisticSets with IntoValue::{into_value}

///|
pub impl FromValue for StylisticSets with fn from_value(v) {
  match v {
    None => StylisticSets(0)
    Int(v) =>
      if v >= 1L && v <= 20L {
        StylisticSets(1 << v.to_int())
      } else {
        bail("stylistic set must be between 1 and 20")
      }
    Array(_) => {
      let v : Array[Int64] = FromValue::from_value(v)
      let mut flags = 0
      for i in v {
        if i >= 1L && i <= 20L {
          flags = flags | (1 << i.to_int())
        } else {
          bail("stylistic set must be between 1 and 20")
        }
      }
      StylisticSets(flags)
    }
    v => raise HintedError(StylisticSets::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StylisticSets with FromValue::{from_value}

///|
let text_elem_stylistic_set_default_value : Value = StylisticSets::default()
  .into_value()
  .shared()

///|
/// The default is built once and shared (marked shared, so that mutating a
/// copy of it copies first, see [Value::shared]): it was rebuilt on every
/// style lookup of the field (performance).
fn text_elem_stylistic_set_default() -> Value {
  text_elem_stylistic_set_default_value
}

// NumberType, NumberWidth

///|
/// Which kind of numbers / figures to select.
pub(all) enum NumberType {
  /// Numbers that fit well with capital text (the OpenType `lnum` font
  /// feature).
  Lining
  /// Numbers that fit well into a flow of upper- and lowercase text (the
  /// OpenType `onum` font feature).
  OldStyle
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberType with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberType with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberType with @debug.Debug::{to_repr}

///|
let number_type_names : ReadOnlyArray[String] = ["lining", "old-style"]

///|
pub impl Reflect for NumberType with fn input() {
  str_names_input(number_type_names)
}

///|
pub impl Reflect for NumberType with fn output() {
  NumberType::input()
}

///|
pub impl Reflect for NumberType with fn castable(v) {
  str_names_find(number_type_names, v) is Some(_)
}

///|
pub extend NumberType with Reflect::{output, input, castable}

///|
pub impl IntoValue for NumberType with fn into_value(self) {
  match self {
    Lining => Str("lining")
    OldStyle => Str("old-style")
  }
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberType with IntoValue::{into_value}

///|
pub impl FromValue for NumberType with fn from_value(v) {
  match str_names_find(number_type_names, v) {
    Some(0) => Lining
    Some(_) => OldStyle
    None => raise HintedError(NumberType::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberType with FromValue::{from_value}

///|
/// The width of numbers / figures.
pub(all) enum NumberWidth {
  /// Numbers with glyph-specific widths (the OpenType `pnum` font feature).
  Proportional
  /// Numbers of equal width (the OpenType `tnum` font feature).
  Tabular
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberWidth with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberWidth with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberWidth with @debug.Debug::{to_repr}

///|
let number_width_names : ReadOnlyArray[String] = ["proportional", "tabular"]

///|
pub impl Reflect for NumberWidth with fn input() {
  str_names_input(number_width_names)
}

///|
pub impl Reflect for NumberWidth with fn output() {
  NumberWidth::input()
}

///|
pub impl Reflect for NumberWidth with fn castable(v) {
  str_names_find(number_width_names, v) is Some(_)
}

///|
pub extend NumberWidth with Reflect::{output, input, castable}

///|
pub impl IntoValue for NumberWidth with fn into_value(self) {
  match self {
    Proportional => Str("proportional")
    Tabular => Str("tabular")
  }
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberWidth with IntoValue::{into_value}

///|
pub impl FromValue for NumberWidth with fn from_value(v) {
  match str_names_find(number_width_names, v) {
    Some(0) => Proportional
    Some(_) => Tabular
    None => raise HintedError(NumberWidth::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberWidth with FromValue::{from_value}

// FontFeatures

///|
/// OpenType font features settings.
pub(all) struct FontFeatures(Array[(OpenTypeTag, Int64)]) derive (
  Eq,
  Hash,
  Default,
)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFeatures with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFeatures with Hash::{hash, hash_combine}

///|
pub extend FontFeatures with Default::{default}

///|
pub impl Reflect for FontFeatures with fn input() {
  CastInfo::Type(Type::array()).union_with(Type(Type::dict()))
}

///|
pub impl Reflect for FontFeatures with fn output() {
  FontFeatures::input()
}

///|
pub impl Reflect for FontFeatures with fn castable(v) {
  v is (Array(_) | Dict(_))
}

///|
pub extend FontFeatures with Reflect::{output, input, castable}

///|
pub impl IntoValue for FontFeatures with fn into_value(self) {
  let dict = Dict::new()
  for pair in self.0 {
    dict.insert(pair.0.to_str_lossy(), Int(pair.1))
  }
  Dict(dict)
}

///|
pub extend FontFeatures with IntoValue::{into_value}

///|
pub impl FromValue for FontFeatures with fn from_value(v) {
  match v {
    Array(values) => {
      let out = []
      for i, v in values.items {
        let tag = with_err_hint(
          () => OpenTypeTag::from_value(v),
          tag_hint_helper(i, v.repr()),
        ) catch {
          HintedError(e) => {
            // Append a hint if the value is a string containing the
            // assignment operator `=` or another type was supplied.
            let append = match v {
              Str(s) => s.contains("=")
              Symbol(s) => s.get().contains("=")
              _ => true
            }
            if append {
              e.hint(
                "to set features with custom values, consider supplying a dictionary",
              )
            }
            raise HintedError(e)
          }
        }
        out.push((tag, 1L))
      }
      FontFeatures(out)
    }
    Dict(values) => {
      let out = []
      let mut i = 0
      for k, v in values.map {
        let hint = tag_hint_helper(i, repr_str(k))
        let tag = with_err_hint(() => OpenTypeTag::from_value(Str(k)), hint)
        let num = with_err_hint(() => U32::from_value(v).0, hint)
        out.push((tag, num))
        i += 1
      }
      FontFeatures(out)
    }
    v => raise HintedError(FontFeatures::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFeatures with FromValue::{from_value}

///|
pub impl Fold for FontFeatures with fn fold(self, outer) {
  FontFeatures(outer.0 + self.0)
}

///|
#deprecated("call as `Fold::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFeatures with Fold::{fold}

///|
let text_elem_features_default_value : Value = FontFeatures::default()
  .into_value()
  .shared()

///|
/// The default is built once and shared (marked shared, so that mutating a
/// copy of it copies first, see [Value::shared]): it was rebuilt on every
/// style lookup of the field (performance).
fn text_elem_features_default() -> Value {
  text_elem_features_default_value
}

///|
fn text_elem_features_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[FontFeatures]), inner, outer)
}

///|
let text_elem_variations_default_value : Value = FontVariations::default()
  .into_value()
  .shared()

///|
/// The default is built once and shared (marked shared, so that mutating a
/// copy of it copies first, see [Value::shared]): it was rebuilt on every
/// style lookup of the field (performance).
fn text_elem_variations_default() -> Value {
  text_elem_variations_default_value
}

///|
fn text_elem_variations_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[FontVariations]), inner, outer)
}

// ItalicToggle, WeightDelta

///|
/// A toggle that turns on and off alternatingly if folded.
///
/// Internal field type without upstream casts; stored as a boolean.
pub(all) struct ItalicToggle(Bool) derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ItalicToggle with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ItalicToggle with Hash::{hash, hash_combine}

///|
pub impl Fold for ItalicToggle with fn fold(self, outer) {
  ItalicToggle(self.0 != outer.0)
}

///|
#deprecated("call as `Fold::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ItalicToggle with Fold::{fold}

///|
pub impl Reflect for ItalicToggle with fn input() {
  Type(Type::bool())
}

///|
pub impl Reflect for ItalicToggle with fn output() {
  Type(Type::bool())
}

///|
pub impl Reflect for ItalicToggle with fn castable(v) {
  v is Bool(_)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ItalicToggle with Reflect::{output, input, castable}

///|
pub impl IntoValue for ItalicToggle with fn into_value(self) {
  Bool(self.0)
}

///|
pub extend ItalicToggle with IntoValue::{into_value}

///|
pub impl FromValue for ItalicToggle with fn from_value(v) {
  ItalicToggle((FromValue::from_value(v) : Bool))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ItalicToggle with FromValue::{from_value}

///|
fn text_elem_emph_default() -> Value {
  ItalicToggle(false).into_value()
}

///|
fn text_elem_emph_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[ItalicToggle]), inner, outer)
}

///|
/// A delta that is summed up when folded.
///
/// Internal field type without upstream casts; stored as an integer.
pub(all) struct WeightDelta(Int64) derive(Eq, Hash, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WeightDelta with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WeightDelta with Hash::{hash, hash_combine}

///|
pub extend WeightDelta with Default::{default}

///|
pub impl Fold for WeightDelta with fn fold(self, outer) {
  WeightDelta(outer.0 + self.0)
}

///|
#deprecated("call as `Fold::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WeightDelta with Fold::{fold}

///|
pub impl Reflect for WeightDelta with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for WeightDelta with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for WeightDelta with fn castable(v) {
  v is Int(_)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WeightDelta with Reflect::{output, input, castable}

///|
pub impl IntoValue for WeightDelta with fn into_value(self) {
  Int(self.0)
}

///|
pub extend WeightDelta with IntoValue::{into_value}

///|
pub impl FromValue for WeightDelta with fn from_value(v) {
  WeightDelta((FromValue::from_value(v) : Int64))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WeightDelta with FromValue::{from_value}

///|
fn text_elem_delta_default() -> Value {
  WeightDelta::default().into_value()
}

///|
fn text_elem_delta_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[WeightDelta]), inner, outer)
}

// Costs

///|
/// Costs for various layout decisions.
///
/// Costs are updated (prioritizing the later value) when folded.
pub(all) struct Costs {
  hyphenation : Ratio?
  runt : Ratio?
  widow : Ratio?
  orphan : Ratio?
} derive(Eq, Hash, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Costs with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Costs with Hash::{hash, hash_combine}

///|
pub extend Costs with Default::{default}

///|
pub fn Costs::hyphenation(self : Costs) -> Ratio {
  self.hyphenation.unwrap_or(Ratio::one())
}

///|
pub fn Costs::runt(self : Costs) -> Ratio {
  self.runt.unwrap_or(Ratio::one())
}

///|
pub fn Costs::widow(self : Costs) -> Ratio {
  self.widow.unwrap_or(Ratio::one())
}

///|
pub fn Costs::orphan(self : Costs) -> Ratio {
  self.orphan.unwrap_or(Ratio::one())
}

///|
pub impl Fold for Costs with fn fold(self, outer) {
  {
    hyphenation: self.hyphenation |> opt_or(outer.hyphenation),
    runt: self.runt |> opt_or(outer.runt),
    widow: self.widow |> opt_or(outer.widow),
    orphan: self.orphan |> opt_or(outer.orphan),
  }
}

///|
#deprecated("call as `Fold::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Costs with Fold::{fold}

///|
pub impl Reflect for Costs with fn input() {
  Type(Type::dict())
}

///|
pub impl Reflect for Costs with fn output() {
  Type(Type::dict())
}

///|
pub impl Reflect for Costs with fn castable(v) {
  v is Dict(_)
}

///|
pub extend Costs with Reflect::{output, input, castable}

///|
pub impl IntoValue for Costs with fn into_value(self) {
  // Only the entries that were set, so that the stored field value keeps
  // which costs were given (required for folding). Users see the full
  // dictionary of upstream's cast via `text_elem_costs_output`.
  let pairs = []
  for
    (key, v) in [
      ("hyphenation", self.hyphenation),
      ("runt", self.runt),
      ("widow", self.widow),
      ("orphan", self.orphan),
    ] {
    if v is Some(ratio) {
      pairs.push((key, Value::Ratio(ratio)))
    }
  }
  Dict(Dict::from_pairs(pairs))
}

///|
pub extend Costs with IntoValue::{into_value}

///|
pub impl FromValue for Costs with fn from_value(v) {
  match v {
    Dict(v) => {
      if v.keys_within(["hyphenation", "runt", "widow", "orphan"]) {
        // Without copying the dictionary (performance).
        return {
          hyphenation: dict_get_cast(v, "hyphenation"),
          runt: dict_get_cast(v, "runt"),
          widow: dict_get_cast(v, "widow"),
          orphan: dict_get_cast(v, "orphan"),
        }
      }
      let v = v.copy()
      let ret = {
        hyphenation: dict_take_cast(v, "hyphenation"),
        runt: dict_take_cast(v, "runt"),
        widow: dict_take_cast(v, "widow"),
        orphan: dict_take_cast(v, "orphan"),
      }
      v.finish(["hyphenation", "runt", "widow", "orphan"])
      ret
    }
    v => raise HintedError(Costs::input().error(v))
  }
}

///|
pub extend Costs with FromValue::{from_value}

///|
/// Upstream's cast of `Costs` into a value: all four costs.
fn text_elem_costs_output(v : Value) -> Value {
  let costs : Costs = Costs::from_value(v) catch { _ => return v }
  Dict(
    Dict::from_pairs([
      ("hyphenation", Ratio(costs.hyphenation())),
      ("runt", Ratio(costs.runt())),
      ("widow", Ratio(costs.widow())),
      ("orphan", Ratio(costs.orphan())),
    ]),
  )
}

///|
let text_elem_costs_default_value : Value = Costs::default()
  .into_value()
  .shared()

///|
/// The default is built once and shared (marked shared, so that mutating a
/// copy of it copies first, see [Value::shared]): it was rebuilt on every
/// style lookup of the field (performance).
fn text_elem_costs_default() -> Value {
  text_elem_costs_default_value
}

///|
fn text_elem_costs_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[Costs]), inner, outer)
}

// Never

///|
/// A type that can never be constructed (upstream `Never`, used as
/// `Smart<Option<Never>>`).
pub(all) enum Never {} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Never with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Never with Hash::{hash, hash_combine}

///|
pub impl Reflect for Never with fn input() {
  Union([])
}

///|
pub impl Reflect for Never with fn output() {
  Union([])
}

///|
pub impl Reflect for Never with fn castable(_) {
  false
}

///|
pub extend Never with Reflect::{output, input, castable}

///|
pub impl IntoValue for Never with fn into_value(self) {
  match self {

  }
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Never with IntoValue::{into_value}

///|
pub impl FromValue for Never with fn from_value(v) {
  raise HintedError(Never::input().error(v))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Never with FromValue::{from_value}

///|
/// Default of `TextElem::fill` (upstream
/// `#[default(Color::BLACK.into())]`).
fn text_elem_fill_default() -> Value {
  Paint::Solid(color_black).into_value()
}
