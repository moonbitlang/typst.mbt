// Port of the castable value types of `typst-library/src/model/par.rs`
// (`JustificationLimits`, `Limits`, `Linebreaks`, `FirstLineIndent`,
// `LineNumberingScope`) and the `ParElem`/`ParLine` field hooks.

///|
/// Configures how justification may distribute spacing.
pub(all) struct JustificationLimits {
  /// Limits for spacing, relative to the space width.
  spacing : Limits[Rel[Length]]?
  /// Limits for tracking, _in addition_ to the glyph width.
  tracking : Limits[Length]?
} derive(Eq, Hash)

///|
pub impl Default for JustificationLimits with fn default() {
  {
    spacing: Some(limits_spacing_default()),
    tracking: Some(limits_tracking_default()),
  }
}

///|
pub impl Reflect for JustificationLimits with fn input() {
  Type(Type::dict())
}

///|
pub impl Reflect for JustificationLimits with fn output() {
  Type(Type::dict())
}

///|
pub impl Reflect for JustificationLimits with fn castable(v) {
  v is Dict(_)
}

///|
pub extend JustificationLimits with Reflect::{output, input, castable}

///|
pub impl IntoValue for JustificationLimits with fn into_value(self) {
  let dict = Dict::new()
  if self.spacing is Some(spacing) {
    dict.insert("spacing", spacing.into_value())
  }
  if self.tracking is Some(tracking) {
    dict.insert("tracking", tracking.into_value())
  }
  Dict(dict)
}

///|
pub extend JustificationLimits with IntoValue::{into_value}

///|
pub impl FromValue for JustificationLimits with fn from_value(v) {
  match v {
    Dict(dict) => {
      if dict.keys_within(["spacing", "tracking"]) {
        // The same casts in the same order as below, without copying the
        // dictionary (performance).
        let spacing = match dict.map.get("spacing") {
          Some(v) =>
            Some(Limits::cast(v, "spacing", rel_checked_min, rel_checked_max))
          None => None
        }
        let tracking = match dict.map.get("tracking") {
          Some(v) =>
            Some(
              Limits::cast(
                v, "tracking", length_checked_min, length_checked_max,
              ),
            )
          None => None
        }
        return { spacing, tracking, }
      }
      let dict = dict.copy()
      let spacing = if dict.contains("spacing") {
        Some(
          Limits::cast(
            dict.take("spacing"),
            "spacing",
            rel_checked_min,
            rel_checked_max,
          ),
        )
      } else {
        None
      }
      let tracking = if dict.contains("tracking") {
        Some(
          Limits::cast(
            dict.take("tracking"),
            "tracking",
            length_checked_min,
            length_checked_max,
          ),
        )
      } else {
        None
      }
      dict.finish(["spacing", "tracking"])
      { spacing, tracking, }
    }
    v => raise HintedError(JustificationLimits::input().error(v))
  }
}

///|
pub impl Fold for JustificationLimits with fn fold(self, outer) {
  {
    spacing: fold_or(self.spacing, outer.spacing),
    tracking: fold_or(self.tracking, outer.tracking),
  }
}

///|
/// Determines the minimum and maximum size by or to which spacing may be shrunk
/// and stretched.
pub(all) struct Limits[T] {
  /// Minimum allowable adjustment.
  min : T
  /// Maximum allowable adjustment.
  max : T
} derive(Eq, Hash)

///|
fn limits_spacing_default() -> Limits[Rel[Length]] {
  {
    min: Rel::from_ratio(Ratio::new(2.0 / 3.0)),
    max: Rel::from_ratio(Ratio::new(1.5)),
  }
}

///|
fn limits_tracking_default() -> Limits[Length] {
  { min: Length::zero(), max: Length::zero(), }
}

///|
pub impl[T : IntoValue] IntoValue for Limits[T] with fn into_value(self) {
  Dict(
    Dict::from_pairs([
      ("min", IntoValue::into_value(self.min)),
      ("max", IntoValue::into_value(self.max)),
    ]),
  )
}

///|
pub extend Limits with IntoValue::{into_value}

///|
pub impl[T] Fold for Limits[T] with fn fold(self, _) {
  self
}

///|
/// Cast limits from a dictionary, validating them with the given checks.
fn[T : FromValue] Limits::cast(
  value : Value,
  field : String,
  checked_min : (T) -> T raise HintedError,
  checked_max : (T) -> T raise HintedError,
) -> Limits[T] raise HintedError {
  let dict : Dict = FromValue::from_value(value)
  // Without unexpected keys, the keys are read without copying the
  // dictionary (performance); `get` fails like `take` for missing keys.
  let fast = dict.keys_within(["min", "max"])
  let dict = if fast { dict } else { dict.copy() }
  let min = limits_take(dict, fast, "min", field, checked_min)
  let max = limits_take(dict, fast, "max", field, checked_max)
  if !fast {
    dict.finish(["min", "max"])
  }
  { min, max, }
}

///|
/// The `take` closure of [Limits::cast] (removing the key unless `fast`).
fn[T : FromValue] limits_take(
  dict : Dict,
  fast : Bool,
  key : String,
  field : String,
  check : (T) -> T raise HintedError,
) -> T raise HintedError {
  let value = if fast { dict.get(key) } else { dict.take(key) }
  let checked = check(T::from_value(value)) catch {
    HintedError(err) =>
      bail("`\{key}` value of `\{field}` is invalid (\{err.message})")
  }
  checked
}

///|
fn length_checked_min(v : Length) -> Length raise HintedError {
  if v.abs > Abs::zero() || v.em > Em::zero() {
    bail("length must be negative or zero")
  }
  v
}

///|
fn length_checked_max(v : Length) -> Length raise HintedError {
  if v.abs < Abs::zero() || v.em < Em::zero() {
    bail("length must be positive or zero")
  }
  v
}

///|
fn rel_checked_min(v : Rel[Length]) -> Rel[Length] raise HintedError {
  if v.rel <= Ratio::zero() {
    bail("ratio must be positive")
  }
  length_checked_min(v.abs) |> ignore
  v
}

///|
fn rel_checked_max(v : Rel[Length]) -> Rel[Length] raise HintedError {
  if v.rel <= Ratio::zero() {
    bail("ratio must be positive")
  }
  length_checked_max(v.abs) |> ignore
  v
}

///|
let par_elem_justification_limits_default_value : Value = JustificationLimits::default()
  .into_value()
  .shared()

///|
/// The default is built once and shared (marked shared, so that mutating a
/// copy of it copies first, see [Value::shared]): it was rebuilt on every
/// style lookup of the field (performance).
fn par_elem_justification_limits_default() -> Value {
  par_elem_justification_limits_default_value
}

///|
fn par_elem_justification_limits_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[JustificationLimits]), inner, outer)
}

///|
/// How to determine line breaks in a paragraph.
pub(all) enum Linebreaks {
  /// Determine the line breaks in a simple first-fit style.
  Simple
  /// Optimize the line breaks for the whole paragraph.
  ///
  /// Typst will try to produce more evenly filled lines of text by
  /// considering the whole paragraph when calculating line breaks.
  Optimized
} derive(Eq, Hash, Debug)

///|
let linebreaks_names : ReadOnlyArray[String] = ["simple", "optimized"]

///|
pub impl Reflect for Linebreaks with fn input() {
  str_names_input(linebreaks_names)
}

///|
pub impl Reflect for Linebreaks with fn output() {
  Linebreaks::input()
}

///|
pub impl Reflect for Linebreaks with fn castable(v) {
  str_names_find(linebreaks_names, v) is Some(_)
}

///|
pub extend Linebreaks with Reflect::{output, input, castable}

///|
pub impl IntoValue for Linebreaks with fn into_value(self) {
  match self {
    Simple => Str("simple")
    Optimized => Str("optimized")
  }
}

///|
pub impl FromValue for Linebreaks with fn from_value(v) {
  match str_names_find(linebreaks_names, v) {
    Some(0) => Simple
    Some(_) => Optimized
    None => raise HintedError(Linebreaks::input().error(v))
  }
}

///|
/// Configuration for first line indent.
///
/// Here `None` means unspecified and fields set to it are inherited.
pub(all) struct FirstLineIndent {
  /// The amount of indent.
  amount : Length?
  /// Whether to indent all paragraphs, not just consecutive ones.
  all : Bool?
} derive(Eq, Hash)

///|
pub impl Default for FirstLineIndent with fn default() {
  { amount: Some(Length::zero()), all: Some(false), }
}

///|
pub fn FirstLineIndent::amount(self : FirstLineIndent) -> Length {
  self.amount.unwrap_or(Length::zero())
}

///|
pub fn FirstLineIndent::all(self : FirstLineIndent) -> Bool {
  self.all.unwrap_or(false)
}

///|
pub impl Fold for FirstLineIndent with fn fold(self, outer) {
  {
    amount: self.amount |> opt_or(outer.amount),
    all: self.all |> opt_or(outer.all),
  }
}

///|
pub impl Reflect for FirstLineIndent with fn input() {
  CastInfo::Type(Type::length()).union_with(Type(Type::dict()))
}

///|
pub impl Reflect for FirstLineIndent with fn output() {
  FirstLineIndent::input()
}

///|
pub impl Reflect for FirstLineIndent with fn castable(v) {
  v is (Length(_) | Dict(_))
}

///|
pub extend FirstLineIndent with Reflect::{output, input, castable}

///|
pub impl IntoValue for FirstLineIndent with fn into_value(self) {
  let dict = Dict::new()
  if self.amount is Some(amount) {
    dict.insert("amount", Length(amount))
  }
  if self.all is Some(all) {
    dict.insert("all", Bool(all))
  }
  Dict(dict)
}

///|
pub extend FirstLineIndent with IntoValue::{into_value}

///|
pub impl FromValue for FirstLineIndent with fn from_value(v) {
  match v {
    Length(amount) => { amount: Some(amount), all: None, }
    Dict(dict) => {
      // Get a value by key, accepting either non-existence or something
      // convertible to type T.
      if dict.keys_within(["amount", "all"]) {
        // Without copying the dictionary (performance).
        return {
          amount: dict_get_cast(dict, "amount"),
          all: dict_get_cast(dict, "all"),
        }
      }
      let dict = dict.copy()
      let amount = dict_take_cast(dict, "amount")
      let all = dict_take_cast(dict, "all")
      dict.finish(["amount", "all"])
      { amount, all, }
    }
    v => raise HintedError(FirstLineIndent::input().error(v))
  }
}

///|
let par_elem_first_line_indent_default_value : Value = FirstLineIndent::default()
  .into_value()
  .shared()

///|
/// The default is built once and shared (marked shared, so that mutating a
/// copy of it copies first, see [Value::shared]): it was rebuilt on every
/// style lookup of the field (performance).
fn par_elem_first_line_indent_default() -> Value {
  par_elem_first_line_indent_default_value
}

///|
fn par_elem_first_line_indent_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[FirstLineIndent]), inner, outer)
}

///|
/// Possible line numbering scope options, indicating how often the line
/// number counter should be reset.
pub(all) enum LineNumberingScope {
  /// Indicates that the line number counter spans the whole document, i.e.,
  /// it's never automatically reset.
  Document
  /// Indicates that the line number counter should be reset at the start of
  /// every new page.
  Page
} derive(Eq, Hash, Debug)

///|
let line_numbering_scope_names : ReadOnlyArray[String] = ["document", "page"]

///|
pub impl Reflect for LineNumberingScope with fn input() {
  str_names_input(line_numbering_scope_names)
}

///|
pub impl Reflect for LineNumberingScope with fn output() {
  LineNumberingScope::input()
}

///|
pub impl Reflect for LineNumberingScope with fn castable(v) {
  str_names_find(line_numbering_scope_names, v) is Some(_)
}

///|
pub extend LineNumberingScope with Reflect::{output, input, castable}

///|
pub impl IntoValue for LineNumberingScope with fn into_value(self) {
  match self {
    Document => Str("document")
    Page => Str("page")
  }
}

///|
pub extend LineNumberingScope with IntoValue::{into_value}

///|
pub impl FromValue for LineNumberingScope with fn from_value(v) {
  match str_names_find(line_numbering_scope_names, v) {
    Some(0) => Document
    Some(_) => Page
    None => raise HintedError(LineNumberingScope::input().error(v))
  }
}

///|
fn par_line_elem_numbering_scope_default() -> Value {
  LineNumberingScope::Document.into_value()
}
