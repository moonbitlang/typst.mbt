// Port of the internal types of `typst-library/src/text/shift.rs`
// (`ShiftSettings`, `ScriptKind`) and `typst-library/src/text/smallcaps.rs`
// (`Smallcaps`), stored in the internal `TextElem::{shift_settings,
// smallcaps}` fields.
//
// Upstream these types have no casts since they are only stored in internal
// fields. Their value forms here are internal: `Smallcaps` is its kebab-case
// name and `ShiftSettings` a dictionary (ems as floats).

///|
/// What becomes small capitals.
pub(all) enum Smallcaps {
  /// Minuscules become small capitals.
  Minuscules
  /// All letters become small capitals.
  All
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for Smallcaps with fn input() {
  Union([Value(Str("minuscules"), ""), Value(Str("all"), "")])
}

///|
pub impl Reflect for Smallcaps with fn output() {
  Smallcaps::input()
}

///|
pub impl Reflect for Smallcaps with fn castable(v) {
  v is Str("minuscules" | "all")
}

///|
pub impl IntoValue for Smallcaps with fn into_value(self) {
  match self {
    Minuscules => Str("minuscules")
    All => Str("all")
  }
}

///|
pub impl FromValue for Smallcaps with fn from_value(v) {
  match v {
    Str("minuscules") => Minuscules
    Str("all") => All
    v => raise HintedError(Smallcaps::input().error(v))
  }
}

///|
/// Configuration values for sub- or superscript text.
pub(all) struct ShiftSettings {
  /// Whether the OpenType feature should be used if possible.
  typographic : Bool
  /// The baseline shift of the script, relative to the outer text size.
  ///
  /// For superscripts, this is positive. For subscripts, this is negative. A
  /// value of `Auto` indicates that the value should be obtained from font
  /// metrics.
  shift : Smart[Em]
  /// The size of the script, relative to the outer text size.
  ///
  /// A value of `Auto` indicates that the value should be obtained from font
  /// metrics.
  size : Smart[Em]
  /// The kind of script (either a subscript, or a superscript).
  ///
  /// This is used to know which OpenType table to use to resolve `Auto`
  /// values.
  kind : ScriptKind
} derive(Eq, Hash)

///|
/// The kind of script.
pub(all) enum ScriptKind {
  Sub
  Super
} derive(Eq, Hash, Debug)

///|
fn smart_em_into_value(v : Smart[Em]) -> Value {
  match v {
    Auto => Auto
    Custom(em) => Float(em.get())
  }
}

///|
fn smart_em_from_value(v : Value) -> Smart[Em] raise HintedError {
  match v {
    Auto => Auto
    Float(f) => Custom(Em::new(f))
    v => raise HintedError(CastInfo::Type(Type::float()).error(v))
  }
}

///|
pub impl Reflect for ShiftSettings with fn input() {
  Type(Type::dict())
}

///|
pub impl Reflect for ShiftSettings with fn output() {
  Type(Type::dict())
}

///|
pub impl Reflect for ShiftSettings with fn castable(v) {
  v is Dict(_)
}

///|
pub impl IntoValue for ShiftSettings with fn into_value(self) {
  Dict(
    Dict::from_pairs([
      ("typographic", Bool(self.typographic)),
      ("shift", smart_em_into_value(self.shift)),
      ("size", smart_em_into_value(self.size)),
      (
        "kind",
        Str(
          match self.kind {
            Sub => "sub"
            Super => "super"
          },
        ),
      ),
    ]),
  )
}

///|
pub impl FromValue for ShiftSettings with fn from_value(v) {
  match v {
    Dict(dict) => {
      let typographic : Bool = dict.get("typographic").cast()
      let shift = smart_em_from_value(dict.get("shift"))
      let size = smart_em_from_value(dict.get("size"))
      let kind : ScriptKind = match dict.get("kind") {
        Str("sub") => Sub
        Str("super") => Super
        v => raise HintedError(CastInfo::Type(Type::str()).error(v))
      }
      { typographic, shift, size, kind }
    }
    v => raise HintedError(ShiftSettings::input().error(v))
  }
}
