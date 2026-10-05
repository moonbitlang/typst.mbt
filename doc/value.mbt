// Value descriptions (docs/edsl-design.md, sections 6 and 13): immutable
// descriptions of non-content engine values, lowered by `lower.mbt` through
// Typst's public functions.

///|
/// An opaque, immutable description of an engine value. Typed facades
/// (`Length`, `Paint`, `Stroke`, ...) convert to it; it is also the generic
/// escape hatch for arguments the typed constructors do not cover.
pub struct Value {
  priv val : Val
}

///|
priv enum Val {
  VNone
  VAuto
  VBool(Bool)
  VInt(Int64)
  VFloat(Double)
  VStr(String)
  /// A number with a unit, evaluated like a numeric literal (`11pt`).
  VNumeric(Double, @library.NumericUnit)
  /// `a + b`, `a - b`, `a * b` and `-a` with Typst's operators.
  VAdd(Value, Value)
  VSub(Value, Value)
  VMul(Value, Value)
  VNeg(Value)
  VArray(Array[Value])
  VDict(Array[(String, Value)])
  VContent(Content)
  /// `label(name)`.
  VLabel(String)
  /// The result of a function call.
  VCall(FuncRef, Array[ArgNode])
  /// A binding of the library's global scope by qualified name (`red`,
  /// `color.map.rainbow`, `heading`).
  VGlobal(String)
  /// A host callback.
  VCallback(Callback)
  /// An engine value, passed through.
  VEngine(@library.Value)
  /// A description that cannot be lowered (the message is reported at the
  /// argument).
  VInvalid(String)
}

///|
fn Value::of(val : Val) -> Value {
  { val, }
}

///|
/// `none`.
pub fn Value::none() -> Value {
  Value::of(VNone)
}

///|
/// `auto`.
pub fn Value::auto() -> Value {
  Value::of(VAuto)
}

///|
pub fn Value::bool(value : Bool) -> Value {
  Value::of(VBool(value))
}

///|
pub fn Value::int(value : Int64) -> Value {
  Value::of(VInt(value))
}

///|
pub fn Value::float(value : Double) -> Value {
  Value::of(VFloat(value))
}

///|
/// A string value (not content).
pub fn Value::str(value : String) -> Value {
  Value::of(VStr(value))
}

///|
/// A length, ratio or relative length.
pub fn Value::length(value : Length) -> Value {
  value.to_value()
}

///|
/// A fraction (`1fr`).
pub fn Value::fr(value : Double) -> Value {
  Value::of(VNumeric(value, @library.NumericUnit::Fr))
}

///|
pub fn Value::angle(value : Angle) -> Value {
  value.to_value()
}

///|
pub fn Value::array(items : Array[Value]) -> Value {
  Value::of(VArray(items.copy()))
}

///|
pub fn Value::dict(pairs : Array[(String, Value)]) -> Value {
  Value::of(VDict(pairs.copy()))
}

///|
/// Content as a value.
pub fn Value::content(body : &IntoContent) -> Value {
  Value::of(VContent(body.into_content()))
}

///|
/// A label (`label(name)`).
pub fn Value::label(name : String) -> Value {
  Value::of(VLabel(name))
}

///|
/// A binding of Typst's global scope by its qualified name, e.g. `"red"`,
/// `"color.map.rainbow"` or the function `"heading"`.
pub fn Value::global(path : String) -> Value {
  Value::of(VGlobal(path))
}

///|
/// The result of calling the public Typst function with the qualified name
/// `path` (`"rgb"`, `"gradient.linear"`, `"table.cell"`).
pub fn Value::call(
  path : String,
  positional? : Array[Value] = [],
  named? : Array[(String, Value)] = [],
) -> Value {
  Value::of(VCall(FPath(path), generic_args(positional, named)))
}

///|
/// An engine value, passed through unchanged.
pub fn Value::engine(value : @library.Value) -> Value {
  Value::of(VEngine(value))
}

///|
/// The arguments of a generic call: they take the call's own span.
fn generic_args(
  positional : Array[Value],
  named : Array[(String, Value)],
) -> Array[ArgNode] {
  let args : Array[ArgNode] = []
  for value in positional {
    args.push({ name: None, value, param: -1, })
  }
  for pair in named {
    args.push({ name: Some(pair.0), value: pair.1, param: -1, })
  }
  args
}

///|
/// A call of a native function with positional and named value arguments.
fn Value::native(
  func : @library.NativeFuncData,
  positional : Array[Value],
  named? : Array[(String, Value)] = [],
) -> Value {
  Value::of(VCall(FNative(func), generic_args(positional, named)))
}

///|
/// Types with a value description. Implemented by the value facades of this
/// package; it is the bound of generic facades such as `Cells[T]` and
/// `Sides[T]`.
pub trait ToValue {
  fn to_value(Self) -> Value
}

///|
pub impl ToValue for Value with fn to_value(self) {
  self
}

///|
pub impl ToValue for Content with fn to_value(self) {
  Value::of(VContent(self))
}

///|
pub impl ToValue for Bool with fn to_value(self) {
  Value::of(VBool(self))
}

///|
pub impl ToValue for Int with fn to_value(self) {
  Value::of(VInt(self.to_int64()))
}

///|
pub impl ToValue for Int64 with fn to_value(self) {
  Value::of(VInt(self))
}

///|
pub impl ToValue for Double with fn to_value(self) {
  Value::of(VFloat(self))
}

///|
/// A string is a string value here (content positions take `IntoContent`).
pub impl ToValue for String with fn to_value(self) {
  Value::of(VStr(self))
}

///|
pub impl[T : ToValue] ToValue for T? with fn to_value(self) {
  match self {
    None => Value::none()
    Some(value) => value.to_value()
  }
}

///|
pub impl[T : ToValue] ToValue for @library.Smart[T] with fn to_value(self) {
  match self {
    Auto => Value::auto()
    Custom(value) => value.to_value()
  }
}

///|
pub impl[T : ToValue] ToValue for Array[T] with fn to_value(self) {
  Value::of(VArray(self.map(v => v.to_value())))
}

// Host callbacks.

///|
/// The serial number of the next callback description (process-wide). A
/// session compares it with its starting value to reject callbacks that
/// were constructed during the compilation.
let callback_serial : @ref.Ref[Int] = { val: 0, }

///|
/// A host callback description: a MoonBit closure that the engine calls as
/// a function. `invoke` receives the invocation's context and the engine's
/// arguments and returns the description of the result.
priv struct Callback {
  serial : Int
  origin : Site
  invoke : (Ctx, @library.Args) -> Value raise
}

///|
fn Callback::new(
  origin : Site,
  invoke : (Ctx, @library.Args) -> Value raise,
) -> Callback {
  let serial = callback_serial.val
  callback_serial.val = serial + 1
  { serial, origin, invoke, }
}
