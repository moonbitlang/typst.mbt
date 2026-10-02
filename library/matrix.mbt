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
pub impl Default for MathDelimiter with fn default() {
  MathDelimiter(None)
}

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
pub impl IntoValue for MathDelimiter with fn into_value(self) {
  match self.0 {
    Some(c) => Str(c.to_string())
    None => None
  }
}

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
/// A pair of delimiters (one closing, one opening) used for matrices, vectors
/// and cases.
pub(all) struct DelimiterPair {
  open : MathDelimiter
  close : MathDelimiter
} derive(Eq, Hash, Debug)

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
pub impl IntoValue for DelimiterPair with fn into_value(self) {
  Array(Arr::from_array([self.open.into_value(), self.close.into_value()]))
}

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
/// Parameters specifying how augmentation lines should be drawn on a matrix.
pub(all) struct Augment {
  hline : AugmentOffsets
  vline : AugmentOffsets
  stroke : Smart[Stroke]
} derive(Eq)

///|
pub impl Default for Augment with fn default() {
  { hline: AugmentOffsets([]), vline: AugmentOffsets([]), stroke: Auto, }
}

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
pub impl IntoValue for Augment with fn into_value(self) {
  // if the stroke is auto and there is only one vertical line,
  if self.stroke.is_auto() &&
    self.hline.0.is_empty() &&
    self.vline.0.length() == 1 {
    return Int(self.vline.0[0])
  }
  Dict(
    Dict::from_pairs([
      ("hline", self.hline.into_value()),
      ("vline", self.vline.into_value()),
      ("stroke", self.stroke.into_value()),
    ]),
  )
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
/// The offsets at which augmentation lines should be drawn on a matrix.
pub(all) struct AugmentOffsets(Array[Int64]) derive(Eq, Hash, Debug)

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
pub impl IntoValue for AugmentOffsets with fn into_value(self) {
  Array(Arr::from_array(self.0.map(v => Int(v))))
}

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
/// Augmentation parameters whose stroke lengths have been resolved (upstream
/// `Augment<Abs>`).
pub(all) struct ResolvedAugment {
  hline : AugmentOffsets
  vline : AugmentOffsets
  stroke : Smart[ResolvedStroke]
} derive(Eq)

///|
/// Upstream `Resolve for Augment`.
pub fn Augment::resolve(self : Augment, styles : StyleChain) -> ResolvedAugment {
  {
    hline: self.hline,
    vline: self.vline,
    stroke: self.stroke.map(s => s.resolve(styles)),
  }
}
