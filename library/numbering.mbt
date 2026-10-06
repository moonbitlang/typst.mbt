// Port of `typst-library/src/model/numbering.rs`.

///|
/// Applies a numbering to a sequence of numbers.
///
/// A numbering defines how a sequence of numbers should be displayed as
/// content. It is defined either through a pattern string or an arbitrary
/// function.
fn impl_numbering(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  numbering_ : Numbering,
  numbers_ : Array[U64],
) -> Value raise SourceError {
  numbering_.apply(engine, context, span, numbers_.map(n => n.get()))
}

///|
/// How to number a sequence of things.
pub(all) enum Numbering {
  /// A pattern with prefix, numbering, lower / upper case and suffix.
  Pattern(NumberingPattern)
  /// A closure mapping from an item's number to content.
  Func(Func)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Numbering with Eq::{not_equal, equal}

///|
/// Apply the pattern to the given numbers.
pub fn Numbering::apply(
  self : Numbering,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  numbers : ArrayView[Int64],
) -> Value raise SourceError {
  match self {
    Pattern(pattern) =>
      Str(at(span, () => pattern.apply(Some((engine, span)), numbers)))
    Func(func) =>
      func.call_values(
        engine,
        context,
        numbers.iter().map(n => Value::Int(n)).collect(),
      )
  }
}

///|
/// Trim the prefix suffix if this is a pattern.
pub fn Numbering::trimmed(self : Numbering) -> Numbering {
  match self {
    Pattern(pattern) => Pattern({ ..pattern, trimmed: true, })
    other => other
  }
}

// cast! {
//     Numbering,
//     self => match self {
//         Self::Pattern(pattern) => pattern.into_value(),
//         Self::Func(func) => func.into_value(),
//     },
//     v: NumberingPattern => Self::Pattern(v),
//     v: Func => Self::Func(v),
// }

///|
pub impl Reflect for Numbering with fn input() {
  NumberingPattern::input().union_with(Func::input())
}

///|
pub impl Reflect for Numbering with fn output() {
  Numbering::input()
}

///|
pub impl Reflect for Numbering with fn castable(v) {
  NumberingPattern::castable(v) || Func::castable(v)
}

///|
pub extend Numbering with Reflect::{output, input, castable}

///|
pub impl IntoValue for Numbering with fn into_value(self) {
  match self {
    Pattern(pattern) => pattern.into_value()
    Func(func) => Func(func)
  }
}

///|
pub extend Numbering with IntoValue::{into_value}

///|
pub impl FromValue for Numbering with fn from_value(v) {
  if NumberingPattern::castable(v) {
    return Pattern(NumberingPattern::from_value(v))
  }
  if Func::castable(v) {
    return Func(Func::from_value(v))
  }
  raise HintedError(Numbering::input().error(v))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Numbering with FromValue::{from_value}

///|
/// How to turn a number into text.
///
/// A pattern consists of a prefix, followed by one of the counter symbols
/// (see `numbering()` docs), and then a suffix.
///
/// Examples of valid patterns:
/// - `1)`
/// - `a.`
/// - `(I)`
pub(all) struct NumberingPattern {
  pieces : Array[(String, NamedNumeralSystem)]
  suffix : String
  priv trimmed : Bool
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumberingPattern with Eq::{not_equal, equal}

///|
/// Apply the pattern to the given number.
///
/// If `warning_context` is not `None`, when an error would normally be
/// returned, a warning is emitted instead and the returned value uses Arabic
/// numerals in place of the numeral system that caused the error.
pub fn NumberingPattern::apply(
  self : NumberingPattern,
  warning_context : (Engine, @syntax.Span)?,
  numbers : ArrayView[Int64],
) -> String raise HintedError {
  match warning_context {
    Some((engine, span)) =>
      self.apply_with(numbers, (system, n) => {
        apply_system_with_fallback(engine, span, system, n)
      })
    None => self.apply_with(numbers, apply_system)
  }
}

///|
/// Auxiliary method for [NumberingPattern::apply].
fn NumberingPattern::apply_with(
  self : NumberingPattern,
  numbers : ArrayView[Int64],
  apply_system : (NamedNumeralSystem, Int64) -> String raise HintedError,
) -> String raise HintedError {
  let fmt = StringBuilder()
  let mut consumed = 0
  for i, piece in self.pieces {
    guard i < numbers.length() else { break }
    let (prefix, system) = piece
    let n = numbers[i]
    if i > 0 || !self.trimmed {
      fmt.write_string(prefix)
    }
    fmt.write_string(apply_system(system, n))
    consumed = i + 1
  }
  if self.pieces.last() is Some((prefix, system)) {
    for n in numbers[consumed:] {
      if prefix.is_empty() {
        fmt.write_string(self.suffix)
      } else {
        fmt.write_string(prefix)
      }
      fmt.write_string(apply_system(system, n))
    }
  }
  if !self.trimmed {
    fmt.write_string(self.suffix)
  }
  fmt.to_string()
}

///|
/// Apply only the k-th segment of the pattern to a number.
pub fn NumberingPattern::apply_kth(
  self : NumberingPattern,
  engine : Engine,
  span : @syntax.Span,
  k : Int,
  number : Int64,
) -> String {
  let fmt = StringBuilder()
  if self.pieces.get(0) is Some((prefix, _)) {
    fmt.write_string(prefix)
  }
  let system = if k < self.pieces.length() {
    Some(self.pieces[k].1)
  } else {
    self.pieces.last().map(p => p.1)
  }
  if system is Some(system) {
    fmt.write_string(apply_system_with_fallback(engine, span, system, number))
  }
  fmt.write_string(self.suffix)
  fmt.to_string()
}

///|
/// How many counting symbols this pattern has.
pub fn NumberingPattern::num_pieces(self : NumberingPattern) -> Int {
  self.pieces.length()
}

///|
fn apply_system(
  system : NamedNumeralSystem,
  number : Int64,
) -> String raise HintedError {
  match system.system().represent(number.reinterpret_as_uint64()) {
    Ok(represented) => represented
    Err(Zero) =>
      bail("the numeral system `\{system.name()}` cannot represent zero")
    Err(TooLarge) =>
      bail(
        "the number \{number} is too large to be represented with the `\{system.name()}` numeral system",
      )
  }
}

///|
/// Applies a numeral system to a number. In case of an error, fall back to
/// Arabic numerals.
///
/// This is a temporary function that should be replaced by [apply_system]
/// when the deprecation warning is turned into a hard error.
fn apply_system_with_fallback(
  engine : Engine,
  span : @syntax.Span,
  system : NamedNumeralSystem,
  number : Int64,
) -> String {
  apply_system(system, number) catch {
    HintedError(err) => {
      engine.sink.warn(
        SourceDiagnostic::warning_at(span, err.message).with_hint(
          "this will become a hard error in the future",
        ),
      )
      apply_system(Arabic, number) catch {
        _ => abort("`arabic` should be able to represent \{number}")
      }
    }
  }
}

///|
/// Parse a numbering pattern (upstream `FromStr for NumberingPattern`).
pub fn NumberingPattern::from_str(
  pattern : String,
) -> NumberingPattern raise HintedError {
  let pieces = []
  let current = StringBuilder()
  for c in pattern {
    match NamedNumeralSystem::from_shorthand(c.to_string()) {
      Some(kind) => {
        pieces.push((current.to_string(), kind))
        current.reset()
      }
      None => current.write_char(c)
    }
  }
  let suffix = current.to_string()
  if pieces.is_empty() {
    bail("invalid numbering pattern")
  }
  { pieces, suffix, trimmed: false, }
}

///|
/// The pattern as a string (upstream `IntoValue for NumberingPattern`).
pub fn NumberingPattern::to_string(self : NumberingPattern) -> String {
  let pat = StringBuilder()
  for piece in self.pieces {
    let (prefix, system) = piece
    pat.write_string(prefix)
    match system.shorthand() {
      Some(s) => pat.write_string(s)
      None =>
        abort(
          "it is not possible to construct numbering systems that don't have a shorthand within Typst for now",
        )
    }
  }
  pat.write_string(self.suffix)
  pat.to_string()
}

///|
pub impl Reflect for NumberingPattern with fn input() {
  input_of((Ty::new() : Ty[String]))
}

///|
pub impl Reflect for NumberingPattern with fn output() {
  input_of((Ty::new() : Ty[String]))
}

///|
pub impl Reflect for NumberingPattern with fn castable(v) {
  castable_of((Ty::new() : Ty[String]), v)
}

///|
pub extend NumberingPattern with Reflect::{output, input, castable}

///|
pub impl IntoValue for NumberingPattern with fn into_value(self) {
  Str(self.to_string())
}

///|
pub extend NumberingPattern with IntoValue::{into_value}

///|
pub impl FromValue for NumberingPattern with fn from_value(v) {
  if castable_of((Ty::new() : Ty[String]), v) {
    // Patterns are stored as strings in styles, so the same pattern is cast
    // over and over; parsed patterns are immutable and cached (performance).
    let pattern : String = v.cast()
    if numbering_pattern_cache.get(pattern) is Some(parsed) {
      return parsed
    }
    let parsed = NumberingPattern::from_str(pattern)
    numbering_pattern_cache[pattern] = parsed
    return parsed
  }
  raise HintedError(NumberingPattern::input().error(v))
}

///|
pub extend NumberingPattern with FromValue::{from_value}

///|
/// Successfully parsed numbering patterns by pattern string.
let numbering_pattern_cache : Map[String, NumberingPattern] = Map([])

// Numbering defaults of element fields.

///|
/// `Numbering::Pattern(NumberingPattern::from_str("1.").unwrap())`
fn enum_elem_numbering_default() -> Value {
  Str("1.")
}

///|
/// `Some(NumberingPattern::from_str("1").unwrap().into())`
fn figure_elem_numbering_default() -> Value {
  Str("1")
}

///|
/// `Numbering::Pattern(NumberingPattern::from_str("1").unwrap())`
fn footnote_elem_numbering_default() -> Value {
  Str("1")
}
