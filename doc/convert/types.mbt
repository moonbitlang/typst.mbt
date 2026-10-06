// The Typst-to-EDSL translator (docs/edsl-convert.md): data structures.
//
// The translator walks the Typst AST and emits MoonBit source that builds
// the same document with the EDSL of `doc`. It translates statically what
// it can type (markup, element calls with literal arguments, set and show
// rules, literal bindings) and keeps everything else as Typst source in
// fallback fragments (`Markup(..)`), which are reported.

///|
/// How a document was expressed (docs/edsl-convert.md, section 6.5).
pub(all) enum Tier {
  /// Only typed constructors, set rules, show rules and callbacks.
  T1
  /// Typed, plus the value-level hatches (`Value::..`, `Call`, `Set`,
  /// `ShowWith`, `extra=`).
  T2
  /// Contains source evaluated by the front end: fragments (`Markup`) or
  /// math strings (`Equation`).
  T3
  /// Not convertible.
  T4
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Tier with Eq::{not_equal, equal}

///|
pub impl Show for Tier with fn output(self, logger) {
  logger.write_string(
    match self {
      T1 => "T1"
      T2 => "T2"
      T3 => "T3"
      T4 => "T4"
    },
  )
}

///|
pub extend Tier with Show::{to_string, output}

///|
/// A fallback fragment: Typst source the translator could not type.
pub struct Fallback {
  /// The construct that forced the fallback (`closure`, `method-call`,
  /// `let`, `import`, ...).
  construct : String
  /// `"item"`: one embedded expression; `"stream"`: a whole content block
  /// or document; `"callback"`: the body of a host callback.
  kind : String
  /// The UTF-8 length of the source kept as Typst.
  bytes : Int
}

///|
/// The result of translating one Typst document.
pub struct Translation {
  /// A MoonBit block body: statements, then an expression of type
  /// `@doc.Document`.
  body : String
  tier : Tier
  /// Whether the only source evaluation is math strings (`Equation`): the
  /// document is `T3` by the letter, typed otherwise.
  math_only : Bool
  fallbacks : Array[Fallback]
  /// The UTF-8 length of the source.
  source_bytes : Int
  /// The UTF-8 length of the source inside fragments.
  fallback_bytes : Int
  /// The number of typed constructor, rule and callback expressions.
  typed : Int
  /// For `T4`: why the document is not convertible.
  note : String
}

///|
/// The construct cannot be translated in the requested way; the caller
/// falls back. The payload names the construct.
priv suberror Bail {
  Bail(String)
}

///|
/// The static type of a translated binding: what its MoonBit variable is.
priv enum Ty {
  /// `Int64`.
  TInt
  /// `Double`.
  TFloat
  /// `String`.
  TStr
  /// `Bool`.
  TBool
  /// `@doc.Length`.
  TLength
  /// `@doc.Paint`.
  TPaint
  /// The view of a show-rule callback (`true`: a typed element view, which
  /// has `.view()`).
  TView(Bool)
} derive(Eq)

///|
/// The translated bindings in scope: Typst name to MoonBit variable and
/// type. (A stream with any other binding is a fragment as a whole, so
/// there is nothing else to track.)
priv struct Env {
  vars : Map[String, (String, Ty)]
  /// Inside a host callback: callbacks cannot be created here (the
  /// creation rule of the EDSL).
  in_callback : Bool
}

///|
fn Env::new() -> Env {
  { vars: Map([]), in_callback: false, }
}

///|
fn Env::copy(self : Env) -> Env {
  { vars: self.vars.copy(), in_callback: self.in_callback, }
}

///|
/// An emitted MoonBit expression of a content type, and whether lowering
/// it is total: it cannot fail or warn (docs/edsl-convert.md, section 4.2).
priv struct Code {
  code : String
  total : Bool
}

///|
/// One step of building a sequence of content.
priv enum Op {
  /// Append an expression of a content type.
  Push(Code)
  /// A statement (a literal `let`).
  Stmt(String)
  /// Markup text: `Lit(..)`.
  Word(String)
  /// Markup's space (`true`: with a newline): `Space()`.
  Gap(Bool)
  /// A paragraph break: `Parbreak()`.
  Break
  /// A smart quote (`true`: double): `Smartquote(double=..)`.
  Quote(Bool)
}

///|
/// The state of one translation.
priv struct Tr {
  lib : @library.Library
  /// The names that are assigned or mutated somewhere in the document.
  mutated : Map[String, Unit]
  fallbacks : Array[Fallback]
  /// Whether a value-level hatch was used.
  mut hatch : Bool
  /// Whether a math string (`Equation`) was emitted.
  mut math : Bool
  mut fallback_bytes : Int
  /// The number of typed expressions emitted.
  mut typed : Int
  mut fresh : Int
  /// The MoonBit variable names in use, with their number of uses.
  names : Map[String, Int]
  /// Emit `Prose(..)` for the streams it can express exactly (the readable
  /// mode, docs/edsl-convert.md, section 4.7).
  prose : Bool
}

///|
/// The part of the state that a failed attempt rolls back.
priv struct Mark {
  fallbacks : Int
  hatch : Bool
  math : Bool
  fallback_bytes : Int
  typed : Int
}

///|
fn Tr::mark(self : Tr) -> Mark {
  {
    fallbacks: self.fallbacks.length(),
    hatch: self.hatch,
    math: self.math,
    fallback_bytes: self.fallback_bytes,
    typed: self.typed,
  }
}

///|
fn Tr::rollback(self : Tr, mark : Mark) -> Unit {
  while self.fallbacks.length() > mark.fallbacks {
    ignore(self.fallbacks.pop())
  }
  self.hatch = mark.hatch
  self.math = mark.math
  self.fallback_bytes = mark.fallback_bytes
  self.typed = mark.typed
}
