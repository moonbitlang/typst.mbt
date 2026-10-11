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
  VDiv(Value, Value)
  VNeg(Value)
  VArray(Array[Value])
  VDict(Array[(String, Value)])
  VContent(Content)
  /// `label(name)`.
  VLabel(String)
  /// The result of a function call.
  VCall(Callee, Array[ArgNode])
  /// A binding of the library's global scope by qualified name (`red`,
  /// `color.map.rainbow`, `heading`).
  VGlobal(String)
  /// A host callback.
  VCallback(Callback)
  /// `..value` in an argument list.
  VSpread(Value)
  /// An engine value produced by the engine, passed through.
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
  ToValue::to_value(value)
}

///|
/// A fraction (`1fr`).
pub fn Value::fr(value : Double) -> Value {
  Value::of(VNumeric(value, @library.NumericUnit::Fr))
}

///|
pub fn Value::angle(value : Angle) -> Value {
  ToValue::to_value(value)
}

///|
/// A paint (a colour).
pub fn Value::paint(value : Paint) -> Value {
  ToValue::to_value(value)
}

///|
pub fn Value::stroke(value : Stroke) -> Value {
  ToValue::to_value(value)
}

///|
pub fn Value::alignment(value : Alignment) -> Value {
  ToValue::to_value(value)
}

///|
/// A track or box size (`auto`, a length, a fraction).
pub fn Value::sizing(value : Sizing) -> Value {
  ToValue::to_value(value)
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
  Value::of(VContent(described(body)))
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
/// `self + other` with Typst's operator: evaluated when the value is
/// lowered, left operand first, with Typst's result and errors (`1pt +
/// red` is a stroke, `"a" + 1` is `cannot add string and integer`).
pub fn Value::add(self : Value, other : Value) -> Value {
  Value::of(VAdd(self, other))
}

///|
/// `self - other` with Typst's operator.
pub fn Value::sub(self : Value, other : Value) -> Value {
  Value::of(VSub(self, other))
}

///|
/// `self * other` with Typst's operator.
pub fn Value::mul(self : Value, other : Value) -> Value {
  Value::of(VMul(self, other))
}

///|
/// `self / other` with Typst's operator.
pub fn Value::div(self : Value, other : Value) -> Value {
  Value::of(VDiv(self, other))
}

///|
/// `-self` with Typst's operator.
pub fn Value::neg(self : Value) -> Value {
  Value::of(VNeg(self))
}

///|
/// `..value` among the positional arguments of a call ([Value::call],
/// [Call], the stops of a gradient): an array is spread into positional
/// arguments, a dictionary into named ones and `arguments` into both, as in
/// Typst. Anywhere else it is a lowering error.
pub fn Value::spread(value : Value) -> Value {
  Value::of(VSpread(value))
}

///|
/// An engine value, passed through unchanged. Not public: every engine
/// value of a compilation is produced by the engine's own functions (from
/// descriptions, or read from engine content through views), never built
/// by the host, so the EDSL cannot hand the engine a malformed value graph.
fn Value::engine(value : @library.Value) -> Value {
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
#deprecated("call as `ToValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Value with ToValue::{to_value}

///|
pub impl ToValue for Content with fn to_value(self) {
  Value::of(VContent(self))
}

///|
#deprecated("call as `ToValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Content with ToValue::{to_value}

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
/// A value where content is expected: as an argument it is the value
/// itself (`Value::none()` for a content field is Typst's `none`); in a
/// sequence it is displayed like `#value` in markup.
pub impl IntoContent for Value with fn into_content(self) {
  Content::of(NValue(self))
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Value with IntoContent::{into_content}

///|
/// Explicit `none` for a content parameter (`header=NoneValue()`); as
/// content it is empty.
pub struct NoneValue {
  priv content : Content
}

///|
pub fn NoneValue::NoneValue() -> NoneValue {
  { content: Content::of(NValue(Value::none())), }
}

///|
pub impl IntoContent for NoneValue with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NoneValue with IntoContent::{into_content}

///|
/// Explicit `auto` for a content parameter (`title=AutoValue()`).
pub struct AutoValue {
  priv content : Content
}

///|
pub fn AutoValue::AutoValue() -> AutoValue {
  { content: Content::of(NValue(Value::auto())), }
}

///|
pub impl IntoContent for AutoValue with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AutoValue with IntoContent::{into_content}

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
  { serial, origin, invoke: scoped_callback(invoke), }
}
