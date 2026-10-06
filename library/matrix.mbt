// Port of the types of `typst-library/src/math/matrix.rs` (`Delimiter`,
// `DelimiterPair`, `Augment`, `AugmentOffsets`) and the `VecElem`,
// `MatElem` and `CasesElem` field defaults. The elements are generated.

///|
let math_default_row_gap : Em = Em::new(0.2)

///|
let math_default_col_gap : Em = Em::new(0.5)

///|
fn vec_elem_gap_default() -> Value {
  Relative(Rel::from_abs(Length::from_em(math_default_row_gap)))
}

///|
fn mat_elem_row_gap_default() -> Value {
  Relative(Rel::from_abs(Length::from_em(math_default_row_gap)))
}

///|
fn mat_elem_column_gap_default() -> Value {
  Relative(Rel::from_abs(Length::from_em(math_default_col_gap)))
}

///|
fn cases_elem_gap_default() -> Value {
  Relative(Rel::from_abs(Length::from_em(math_default_row_gap)))
}

///|
fn vec_elem_delim_default() -> Value {
  DelimiterPair::paren().into_value()
}

///|
fn mat_elem_delim_default() -> Value {
  DelimiterPair::paren().into_value()
}

///|
fn cases_elem_delim_default() -> Value {
  DelimiterPair::brace().into_value()
}

///|
/// A delimiter is a single character that is used to delimit a matrix, vector
/// or cases. The character has to be a Unicode codepoint tagged as a math
/// "opening", "closing" or "fence".
///
/// Typically, the delimiter is stretched to fit the height of whatever it
/// delimits. (upstream `math::Delimiter`)
pub(all) struct MathDelimiter(Char?) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathDelimiter with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathDelimiter with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathDelimiter with @debug.Debug::{to_repr}

///|
pub impl Default for MathDelimiter with fn default() {
  MathDelimiter(None)
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathDelimiter with Default::{default}

///|
pub fn MathDelimiter::none() -> MathDelimiter {
  MathDelimiter(None)
}

///|
pub fn MathDelimiter::char(c : Char) -> MathDelimiter raise HintedError {
  if !(@unicode.default_math_class(c) is Some(Opening | Closing | Fence)) {
    bail("invalid delimiter: \"\{c}\"")
  }
  MathDelimiter(Some(c))
}

///|
pub fn MathDelimiter::get(self : MathDelimiter) -> Char? {
  self.0
}

///|
pub fn MathDelimiter::find_matching(self : MathDelimiter) -> MathDelimiter {
  match self.0 {
    None => MathDelimiter::none()
    Some('[') => MathDelimiter(Some(']'))
    Some(']') => MathDelimiter(Some('['))
    Some('{') => MathDelimiter(Some('}'))
    Some('}') => MathDelimiter(Some('{'))
    Some(c) =>
      match @unicode.default_math_class(c) {
        Some(Opening) => MathDelimiter(char_from_u32(c.to_int() + 1))
        Some(Closing) => MathDelimiter(char_from_u32(c.to_int() - 1))
        _ => MathDelimiter(Some(c))
      }
  }
}

///|
/// Upstream `char::from_u32`: `None` for surrogates and out-of-range values.
fn char_from_u32(n : Int) -> Char? {
  if n < 0 || n > 0x10FFFF || (n >= 0xD800 && n <= 0xDFFF) {
    None
  } else {
    Some(n.unsafe_to_char())
  }
}

///|
pub impl Reflect for MathDelimiter with fn input() {
  CastInfo::Type(Type::none())
  .union_with(Type(Type::symbol()))
  .union_with(input_of((Ty::new() : Ty[Char])))
}

///|
pub impl Reflect for MathDelimiter with fn output() {
  CastInfo::Type(Type::none())
  .union_with(Type(Type::symbol()))
  .union_with(output_of((Ty::new() : Ty[Char])))
}

///|
pub impl Reflect for MathDelimiter with fn castable(v) {
  v is None || v is Symbol(_) || castable_of((Ty::new() : Ty[Char]), v)
}

///|
pub extend MathDelimiter with Reflect::{output, input, castable}

///|
pub impl IntoValue for MathDelimiter with fn into_value(self) {
  match self.0 {
    Some(c) => Str(c.to_string())
    None => None
  }
}

///|
pub extend MathDelimiter with IntoValue::{into_value}

///|
pub impl FromValue for MathDelimiter with fn from_value(v) {
  match v {
    None => MathDelimiter::none()
    Symbol(s) =>
      match single_char(s.get()) {
        Some(c) => MathDelimiter::char(c)
        None => bail("expected a single-codepoint symbol")
      }
    v if castable_of((Ty::new() : Ty[Char]), v) =>
      MathDelimiter::char(FromValue::from_value(v))
    v => raise HintedError(MathDelimiter::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathDelimiter with FromValue::{from_value}

///|
/// A pair of delimiters (one closing, one opening) used for matrices, vectors
/// and cases.
pub(all) struct DelimiterPair {
  open : MathDelimiter
  close : MathDelimiter
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DelimiterPair with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DelimiterPair with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DelimiterPair with @debug.Debug::{to_repr}

///|
pub fn DelimiterPair::paren() -> DelimiterPair {
  { open: MathDelimiter(Some('(')), close: MathDelimiter(Some(')')), }
}

///|
pub fn DelimiterPair::brace() -> DelimiterPair {
  { open: MathDelimiter(Some('{')), close: MathDelimiter(Some('}')), }
}

///|
/// The delimiter's opening character.
pub fn DelimiterPair::open(self : DelimiterPair) -> Char? {
  self.open.get()
}

///|
/// The delimiter's closing character.
pub fn DelimiterPair::close(self : DelimiterPair) -> Char? {
  self.close.get()
}

///|
pub impl Reflect for DelimiterPair with fn input() {
  CastInfo::Type(Type::array()).union_with(MathDelimiter::input())
}

///|
pub impl Reflect for DelimiterPair with fn output() {
  CastInfo::Type(Type::array()).union_with(MathDelimiter::output())
}

///|
pub impl Reflect for DelimiterPair with fn castable(v) {
  v is Array(_) || MathDelimiter::castable(v)
}

///|
pub extend DelimiterPair with Reflect::{output, input, castable}

///|
pub impl IntoValue for DelimiterPair with fn into_value(self) {
  Array(Arr::from_array([self.open.into_value(), self.close.into_value()]))
}

///|
pub extend DelimiterPair with IntoValue::{into_value}

///|
pub impl FromValue for DelimiterPair with fn from_value(v) {
  match v {
    Array(arr) =>
      if arr.len() == 2 {
        let items = arr.iter().collect()
        { open: items[0].cast(), close: items[1].cast(), }
      } else {
        bail("expected 2 delimiters, found \{arr.len()}")
      }
    v if MathDelimiter::castable(v) => {
      let open : MathDelimiter = v.cast()
      { open, close: open.find_matching(), }
    }
    v => raise HintedError(DelimiterPair::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DelimiterPair with FromValue::{from_value}

///|
/// Parameters specifying how augmentation lines should be drawn on a matrix.
pub(all) struct Augment {
  hline : AugmentOffsets
  vline : AugmentOffsets
  stroke : Smart[Stroke]
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Augment with Eq::{not_equal, equal}

///|
pub impl Default for Augment with fn default() {
  { hline: AugmentOffsets([]), vline: AugmentOffsets([]), stroke: Auto, }
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Augment with Default::{default}

///|
pub impl Fold for Augment with fn fold(self, outer) {
  {
    ..self,
    stroke: match (self.stroke, outer.stroke) {
      (Custom(inner), Custom(outer)) => Custom(inner.fold(outer))
      // Usually, folding an inner `auto` with an `outer` prefers the
      // explicit `auto`. However, here `auto` means unspecified and thus we
      // want `outer`.
      (inner, outer) => inner.or_(outer)
    },
  }
}

///|
#deprecated("call as `Fold::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Augment with Fold::{fold}

///|
pub impl Reflect for Augment with fn input() {
  CastInfo::Type(Type::int()).union_with(Type(Type::dict()))
}

///|
pub impl Reflect for Augment with fn output() {
  CastInfo::Type(Type::int()).union_with(Type(Type::dict()))
}

///|
pub impl Reflect for Augment with fn castable(v) {
  v is Int(_) || v is Dict(_)
}

///|
pub extend Augment with Reflect::{output, input, castable}

///|
pub impl IntoValue for Augment with fn into_value(self) {
  // The stored form of the field: like upstream's cast, but without the
  // `stroke` entry when it is `auto` (upstream's cast writes `stroke: auto`,
  // which its own `FromValue` rejects; it stores the Rust value instead).
  // Users see upstream's form via `augment_output`.
  if self.stroke.is_auto() &&
    self.hline.0.is_empty() &&
    self.vline.0.length() == 1 {
    return Int(self.vline.0[0])
  }
  let pairs = [
    ("hline", self.hline.into_value()),
    ("vline", self.vline.into_value()),
  ]
  if self.stroke is Custom(stroke) {
    pairs.push(("stroke", stroke.into_value()))
  }
  Dict(Dict::from_pairs(pairs))
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Augment with IntoValue::{into_value}

///|
/// Upstream's cast of `Augment` into a value (shown to users).
fn augment_output(v : Value) -> Value {
  let augment : Augment = Augment::from_value(v) catch { _ => return v }
  if augment.stroke.is_auto() &&
    augment.hline.0.is_empty() &&
    augment.vline.0.length() == 1 {
    return Int(augment.vline.0[0])
  }
  Dict(
    Dict::from_pairs([
      ("hline", augment.hline.into_value()),
      ("vline", augment.vline.into_value()),
      ("stroke", augment.stroke.into_value()),
    ]),
  )
}

///|
fn mat_elem_augment_output(v : Value) -> Value {
  augment_output(v)
}

///|
pub impl FromValue for Augment with fn from_value(v) {
  match v {
    Int(v) =>
      { hline: AugmentOffsets([]), vline: AugmentOffsets([v]), stroke: Auto, }
    Dict(dict) => {
      let dict = dict.copy()
      let take = (key : String) => {
        if dict.contains(key) {
          let offsets : AugmentOffsets = dict.take(key).cast()
          offsets
        } else {
          AugmentOffsets([])
        }
      }
      let hline = take("hline")
      let vline = take("vline")
      let stroke : Smart[Stroke] = if dict.contains("stroke") {
        Custom(dict.take("stroke").cast())
      } else {
        Auto
      }
      { hline, vline, stroke, }
    }
    v => raise HintedError(Augment::input().error(v))
  }
}

///|
pub extend Augment with FromValue::{from_value}

///|
/// The offsets at which augmentation lines should be drawn on a matrix.
pub(all) struct AugmentOffsets(Array[Int64]) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AugmentOffsets with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AugmentOffsets with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AugmentOffsets with @debug.Debug::{to_repr}

///|
pub impl Reflect for AugmentOffsets with fn input() {
  CastInfo::Type(Type::int()).union_with(Type(Type::array()))
}

///|
pub impl Reflect for AugmentOffsets with fn output() {
  CastInfo::Type(Type::int()).union_with(Type(Type::array()))
}

///|
pub impl Reflect for AugmentOffsets with fn castable(v) {
  v is Int(_) || v is Array(_)
}

///|
pub extend AugmentOffsets with Reflect::{output, input, castable}

///|
pub impl IntoValue for AugmentOffsets with fn into_value(self) {
  Array(Arr::from_array(self.0.map(v => Int(v))))
}

///|
pub extend AugmentOffsets with IntoValue::{into_value}

///|
pub impl FromValue for AugmentOffsets with fn from_value(v) {
  match v {
    Int(v) => AugmentOffsets([v])
    Array(arr) => {
      let out : Array[Int64] = []
      for item in arr.iter() {
        out.push(item.cast())
      }
      AugmentOffsets(out)
    }
    v => raise HintedError(AugmentOffsets::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AugmentOffsets with FromValue::{from_value}

///|
/// Augmentation parameters whose stroke lengths have been resolved (upstream
/// `Augment<Abs>`).
pub(all) struct ResolvedAugment {
  hline : AugmentOffsets
  vline : AugmentOffsets
  stroke : Smart[ResolvedStroke]
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ResolvedAugment with Eq::{not_equal, equal}

///|
/// Upstream `Resolve for Augment`.
pub fn Augment::resolve(self : Augment, styles : StyleChain) -> ResolvedAugment {
  {
    hline: self.hline,
    vline: self.vline,
    stroke: self.stroke.map(s => s.resolve(styles)),
  }
}
