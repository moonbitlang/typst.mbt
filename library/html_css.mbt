// Port of `typst-html/src/css/encode.rs`: conversion from Typst data types
// into CSS data types, and the CSS property list stored on HTML elements.
//
// Lives in `library` because `HtmlElem.css` stores a property list and the
// typed HTML API serializes lengths and colors into attributes. Upstream
// `css::Properties` / `css::Property` are `CssProperties` / `CssProperty`
// here. Warning sinks (upstream `WarningSink`) are closures receiving the
// warning message; `()` is `_ => ()`.

///|
/// A list of CSS properties with values, sorted by name.
///
/// Upstream this is a copy-on-write `EcoVec`; here the methods that modify
/// the list mutate it in place, so callers must [CssProperties::copy] a
/// shared list first.
pub struct CssProperties(Array[CssProperty]) derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssProperties with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssProperties with Hash::{hash, hash_combine}

///|
/// Creates an empty list.
pub fn CssProperties::new() -> CssProperties {
  CssProperties([])
}

///|
pub impl Default for CssProperties with fn default() {
  CssProperties::new()
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssProperties with Default::{default}

///|
/// A copy of the list that can be modified independently.
pub fn CssProperties::copy(self : CssProperties) -> CssProperties {
  CssProperties(self.0.copy())
}

///|
/// Creates a builder for adding properties that implement `ToCss`.
pub fn CssProperties::build(
  sink : (HintedString) -> Unit,
) -> CssPropertiesBuilder {
  CssPropertiesBuilder::new(sink)
}

///|
/// The properties in order (upstream `Deref<Target = [Property]>`).
pub fn CssProperties::iter(self : CssProperties) -> Iter[CssProperty] {
  self.0.iter()
}

///|
/// The number of properties.
pub fn CssProperties::length(self : CssProperties) -> Int {
  self.0.length()
}

///|
/// Whether there are no properties.
pub fn CssProperties::is_empty(self : CssProperties) -> Bool {
  self.0.is_empty()
}

///|
/// Adds a new, already serialized property to the list.
pub fn CssProperties::push(
  self : CssProperties,
  property : String,
  value : String,
) -> Unit {
  let property = CssProperty::new(property, value)
  match self.0.binary_search_by(p => css_compare_names(p.name, property.name)) {
    Ok(idx) => self.0[idx] = property
    Err(idx) => self.0.insert(idx, property)
  }
}

///|
/// Removes a property if it exists.
pub fn CssProperties::remove(self : CssProperties, property : String) -> Unit {
  if self.0.binary_search_by(p => css_compare_names(p.name, property)) is Ok(i) {
    self.0.remove(i) |> ignore
  }
}

///|
/// Adds a new, already serialized property in builder style (upstream
/// `with`; `with` is a keyword).
pub fn CssProperties::with_(
  self : CssProperties,
  property : String,
  value : String,
) -> CssProperties {
  let out = self.copy()
  out.push(property, value)
  out
}

///|
/// Converts the CSS properties into an inline style.
pub fn CssProperties::to_inline(self : CssProperties) -> String {
  let f = StringBuilder()
  for i, p in self.0 {
    if i > 0 {
      f.write_string("; ")
    }
    f.write_string(p.name)
    f.write_string(": ")
    f.write_string(p.value)
  }
  f.to_string()
}

///|
pub impl Reflect for CssProperties with fn input() {
  // Internal field type without a user-facing cast.
  Any
}

///|
pub impl Reflect for CssProperties with fn output() {
  Any
}

///|
pub impl Reflect for CssProperties with fn castable(v) {
  v is Dyn(HtmlCss(_))
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssProperties with Reflect::{output, input, castable}

///|
pub impl IntoValue for CssProperties with fn into_value(self) {
  Dyn(HtmlCss(self))
}

///|
pub extend CssProperties with IntoValue::{into_value}

///|
pub impl FromValue for CssProperties with fn from_value(v) {
  match v {
    Dyn(HtmlCss(p)) => p
    _ => bail("expected CSS properties, found \{v.ty()}")
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssProperties with FromValue::{from_value}

///|
/// Rust's `str` ordering (MoonBit's `String::compare` orders by length
/// first). Property names are ASCII.
fn css_compare_names(a : String, b : String) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let order = a.code_unit_at(i).compare(b.code_unit_at(i))
    if order != 0 {
      return order
    }
  }
  a.length().compare(b.length())
}

///|
/// A builder for [CssProperties].
///
/// Allows serializing Typst types into CSS while producing warnings for
/// unsupported constructs.
pub struct CssPropertiesBuilder {
  priv sink : (HintedString) -> Unit
  priv props : CssProperties
}

///|
/// Create a new builder that emits any warnings that may occur during
/// serialization into the given `sink`.
pub fn CssPropertiesBuilder::new(
  sink : (HintedString) -> Unit,
) -> CssPropertiesBuilder {
  { sink, props: CssProperties::new(), }
}

///|
/// Serializes a new property and adds it to the property list.
pub fn[T : ToCss] CssPropertiesBuilder::push(
  self : CssPropertiesBuilder,
  property : String,
  value : T,
) -> Unit {
  let writer = CssWriter::new(self.sink)
  writer.emit(value)
  if !writer.error {
    self.props.push(property, writer.buf.to_string())
  }
}

///|
/// Serializes a new property and adds it to the property list in builder
/// style (upstream `with`).
pub fn[T : ToCss] CssPropertiesBuilder::with_(
  self : CssPropertiesBuilder,
  property : String,
  value : T,
) -> CssPropertiesBuilder {
  self.push(property, value)
  self
}

///|
/// Finish building the properties and propagate warnings.
pub fn CssPropertiesBuilder::finish(
  self : CssPropertiesBuilder,
) -> CssProperties {
  self.props
}

///|
/// A CSS property pair such as `display: block`.
pub struct CssProperty {
  /// The property's name, e.g. `display`.
  // TODO: Use something similar to `HtmlAttr`.
  name : String
  /// The property's serialized value, e.g. `block`.
  value : String
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssProperty with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssProperty with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssProperty with @debug.Debug::{to_repr}

///|
/// Creates a new property pair from its parts.
pub fn CssProperty::new(name : String, value : String) -> CssProperty {
  { name, value, }
}

///|
/// Low-level writer for CSS syntax.
pub struct CssWriter {
  priv sink : (HintedString) -> Unit
  priv buf : StringBuilder
  priv mut error : Bool
}

///|
fn CssWriter::new(sink : (HintedString) -> Unit) -> CssWriter {
  { sink, buf: StringBuilder(), error: false, }
}

///|
/// Call a CSS function.
fn CssWriter::call(
  self : CssWriter,
  name : String,
  separator : CssSeparator,
) -> CssCallWriter {
  CssCallWriter::start(self, name, separator)
}

///|
/// Start a `calc` call expression.
fn CssWriter::calc(self : CssWriter) -> CssCalcWriter {
  CssCalcWriter::start(self)
}

///|
fn[T : ToCss] CssWriter::emit(self : CssWriter, value : T) -> Unit {
  value.emit(self)
}

///|
pub fn CssWriter::write(self : CssWriter, value : String) -> Unit {
  self.buf.write_string(value)
}

///|
fn CssWriter::ignored(self : CssWriter, what : String) -> Unit {
  (self.sink)(HintedString::new("\{what} was ignored during HTML export"))
}

///|
pub fn CssWriter::fail(self : CssWriter, what : String) -> Unit {
  self.ignored(what)
  self.error = true
}

///|
/// Writes a CSS function call. Upstream writes the closing parenthesis on
/// drop; here [CssCallWriter::finish] must be called.
priv struct CssCallWriter {
  w : CssWriter
  mut count : Int
  separator : CssSeparator
}

///|
fn CssCallWriter::start(
  w : CssWriter,
  name : String,
  separator : CssSeparator,
) -> CssCallWriter {
  w.write(name)
  w.write("(")
  { w, count: 0, separator, }
}

///|
fn[T : ToCss] CssCallWriter::arg(
  self : CssCallWriter,
  value : T,
) -> CssCallWriter {
  self.arg_with(value, self.separator)
}

///|
fn[T : ToCss] CssCallWriter::arg_with(
  self : CssCallWriter,
  value : T,
  separator : CssSeparator,
) -> CssCallWriter {
  if self.count > 0 {
    self.w.write(
      match separator {
        Space => " "
        Slash => " / "
      },
    )
  }
  self.w.emit(value)
  self.count += 1
  self
}

///|
/// Adds an alpha component argument to a CSS call if the alpha value is not
/// 1 (upstream `MaybeAlpha`).
fn CssCallWriter::maybe_alpha_arg(
  self : CssCallWriter,
  value : Double,
) -> CssCallWriter {
  if !css_is_very_close(value, 1.0) {
    self.arg_with(css_to_ratio(value), Slash)
  } else {
    self
  }
}

///|
/// Upstream `Drop for CallWriter`.
fn CssCallWriter::finish(self : CssCallWriter) -> Unit {
  self.w.write(")")
}

///|
/// A separator in a CSS function call argument list.
priv enum CssSeparator {
  Space
  Slash
}

///|
/// Writes a lazy CSS `calc(<calc-sum>) expression`.
/// If only a single operand is written, `calc(<calc-sum>)` is omitted.
/// Upstream finishes on drop; here [CssCalcWriter::finish] must be called.
priv struct CssCalcWriter {
  w : CssWriter
  /// The index in the [CssWriter::buf].
  start_idx : Int
  mut count : Int
}

///|
fn CssCalcWriter::start(w : CssWriter) -> CssCalcWriter {
  let start_idx = w.buf.to_string().length()
  { w, start_idx, count: 0, }
}

///|
/// Add a value.
///
/// - If it is zero, it will be omitted.
/// - If it is negative, it will be negated and subtracted. This makes the
///   assumption that the formatted string `"+ {val}"` is equivalent to
///   `"- {val.neg()}"`.
fn[T : ToCss + Numeric + Compare] CssCalcWriter::sum(
  self : CssCalcWriter,
  value : T,
) -> CssCalcWriter {
  if value == Numeric::zero() {
    return self
  }
  if self.count == 0 {
    self.w.emit(value)
  } else if value < Numeric::zero() {
    // Negate the value and subtract it, in case it is negative.
    self.w.write(" - ")
    self.w.emit(-value)
  } else {
    self.w.write(" + ")
    self.w.emit(value)
  }
  self.count += 1
  self
}

///|
/// Upstream `Drop for CalcWriter`.
fn CssCalcWriter::finish(self : CssCalcWriter) -> Unit {
  match self.count {
    0 =>
      // An empty `calc()` function call is invalid, so write a `0`,
      // which is also valid for lengths.
      self.w.write("0")
    1 => ()
    _ => {
      // NOTE: This assumes the `ToCss` implementation of all values
      // should only modify text that itself has written into the
      // buffer, which seems reasonable.
      let buf = self.w.buf.to_string()
      self.w.buf.reset()
      self.w.buf.write_string(buf.unsafe_substring(start=0, end=self.start_idx))
      self.w.buf.write_string("calc(")
      self.w.buf.write_string(
        buf.unsafe_substring(start=self.start_idx, end=buf.length()),
      )
      self.w.buf.write_string(")")
    }
  }
}

///|
/// Serializes a value into CSS.
pub(open) trait ToCss {
  /// Writes `self` into the writer.
  fn emit(Self, CssWriter) -> Unit
}

///|
/// Convert a value to a CSS string (upstream `ToCss::to_css`).
pub fn[T : ToCss] to_css(
  value : T,
  sink~ : (HintedString) -> Unit = _ => (),
) -> String {
  let w = CssWriter::new(sink)
  value.emit(w)
  w.buf.to_string()
}

///|
pub impl ToCss for String with fn emit(self, w) {
  w.write(self)
}

///|
/// Displays a number with four significant digits.
///
/// For a number between 0 and 1, four significant digits give us a precision
/// of `1/10_000`, which is more than 12 bits (see [css_is_very_close]).
priv struct CssNumber(Double)

///|
impl ToCss for CssNumber with fn emit(self, w) {
  w.emit(CssNumberWithPrecision(self.0, 4))
}

///|
/// Displays a number with N significant digits.
priv struct CssNumberWithPrecision(Double, Int)

///|
impl ToCss for CssNumberWithPrecision with fn emit(self, w) {
  w.write(rust_display_f64(round_with_precision(self.0, self.1)))
}

///|
pub impl ToCss for Abs with fn emit(self, w) {
  w.emit(CssNumber(self.to_pt()))
  w.write("pt")
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Abs with ToCss::{emit}

///|
pub impl ToCss for Em with fn emit(self, w) {
  w.emit(CssNumber(self.get()))
  w.write("em")
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Em with ToCss::{emit}

///|
pub impl ToCss for Length with fn emit(self, w) {
  w.calc().sum(self.em).sum(self.abs).finish()
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Length with ToCss::{emit}

///|
pub impl ToCss for Angle with fn emit(self, w) {
  w.emit(CssNumber(self.to_deg()))
  w.write("deg")
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Angle with ToCss::{emit}

///|
pub impl ToCss for Ratio with fn emit(self, w) {
  w.emit(CssNumberWithPrecision(self.get() * 100.0, 2))
  w.write("%")
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ratio with ToCss::{emit}

///|
pub impl ToCss for Rel[Length] with fn emit(self, w) {
  w.calc().sum(self.rel).sum(self.abs.em).sum(self.abs.abs).finish()
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rel with ToCss::{emit}

///|
pub impl ToCss for Paint with fn emit(self, w) {
  match self {
    Solid(color) => w.emit(color)
    Gradient(_) => w.fail("gradient")
    Tiling(_) => w.fail("tiling")
  }
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Paint with ToCss::{emit}

///|
pub impl ToCss for Color with fn emit(self, w) {
  // Convert to ProcessColor (spot colors use their fallback)
  let process = self.to_process()
  match process {
    Rgb(_) | Cmyk(_) | Luma(_) => w.emit(process.to_rgb())
    Oklab(v) => w.emit(v)
    Oklch(v) => w.emit(v)
    LinearRgb(v) => w.emit(v)
    Hsl(_) | Hsv(_) => w.emit(process.to_hsl())
  }
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Color with ToCss::{emit}

///|
pub impl ToCss for Rgb with fn emit(self, w) {
  // `self.into_format::<u8, u8>()`
  let (r, g, b, a) = (
    f32_to_u8_stimulus(self.red),
    f32_to_u8_stimulus(self.green),
    f32_to_u8_stimulus(self.blue),
    f32_to_u8_stimulus(self.alpha),
  )

  // Checks if the 8-bit representation of an f32 RGBA color is [very
  // close](css_is_very_close) to the original. If yes, uses a hex
  // representation, otherwise falls back to an `rgb` call.
  if css_is_very_close(self.red.to_double(), css_u8_to_f32(r)) &&
    css_is_very_close(self.blue.to_double(), css_u8_to_f32(b)) &&
    css_is_very_close(self.green.to_double(), css_u8_to_f32(g)) &&
    css_is_very_close(self.alpha.to_double(), css_u8_to_f32(a)) {
    w.write("#" + hex2(r) + hex2(g) + hex2(b))
    if a != 255 {
      w.write(hex2(a))
    }
  } else {
    w
    .call("rgb", Space)
    .arg(css_to_ratio(self.red.to_double()))
    .arg(css_to_ratio(self.green.to_double()))
    .arg(css_to_ratio(self.blue.to_double()))
    .maybe_alpha_arg(self.alpha.to_double())
    .finish()
  }
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rgb with ToCss::{emit}

///|
pub impl ToCss for Oklab with fn emit(self, w) {
  w
  .call("oklab", Space)
  .arg(css_to_ratio(self.l.to_double()))
  .arg(CssNumber(self.a.to_double()))
  .arg(CssNumber(self.b.to_double()))
  .maybe_alpha_arg(self.alpha.to_double())
  .finish()
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Oklab with ToCss::{emit}

///|
pub impl ToCss for Oklch with fn emit(self, w) {
  w
  .call("oklch", Space)
  .arg(css_to_ratio(self.l.to_double()))
  .arg(CssNumber(self.chroma.to_double()))
  .arg(css_to_angle(normalize_signed_angle(self.hue).to_double()))
  .maybe_alpha_arg(self.alpha.to_double())
  .finish()
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Oklch with ToCss::{emit}

///|
pub impl ToCss for LinearRgb with fn emit(self, w) {
  w
  .call("color", Space)
  .arg("srgb-linear")
  .arg(css_to_ratio(self.red.to_double()))
  .arg(css_to_ratio(self.green.to_double()))
  .arg(css_to_ratio(self.blue.to_double()))
  .maybe_alpha_arg(self.alpha.to_double())
  .finish()
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LinearRgb with ToCss::{emit}

///|
pub impl ToCss for Hsl with fn emit(self, w) {
  w
  .call("hsl", Space)
  .arg(css_to_angle(normalize_signed_angle(self.hue).to_double()))
  .arg(css_to_ratio(self.saturation.to_double()))
  .arg(css_to_ratio(self.lightness.to_double()))
  .maybe_alpha_arg(self.alpha.to_double())
  .finish()
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Hsl with ToCss::{emit}

///|
/// palette's `IntoStimulus<f32> for u8` (as used by `into_format`), widened
/// to `f64` like upstream's `is_very_close`.
fn css_u8_to_f32(x : Int) -> Double {
  let max : Float = 255.0
  (Float::from_int(x) * ((1.0 : Float) / max)).to_double()
}

///|
pub impl ToCss for CssDisplay with fn emit(self, w) {
  w.write(self.as_str())
}

///|
#deprecated("call as `ToCss::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssDisplay with ToCss::{emit}

///|
/// Convert a raw degree value into an `Angle`.
fn css_to_angle(degrees : Double) -> Angle {
  Angle::deg(degrees)
}

///|
/// Convert a raw value between 0 and 1 to a `Ratio`.
fn css_to_ratio(v : Double) -> Ratio {
  Ratio::new(v)
}

///|
/// Whether two component values are close enough that there is no
/// difference when encoding them with 12-bit. 12 bit is the highest
/// reasonable color bit depth found in the industry.
fn css_is_very_close(a : Double, b : Double) -> Bool {
  let max_bit_depth = 12
  let eps = 0.5 / (1 << max_bit_depth).to_double()
  (a - b).abs() < eps
}
