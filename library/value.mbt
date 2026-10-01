// Port of `typst-library/src/foundations/value.rs`.

///|
/// A computational value.
pub(all) enum Value {
  /// The value that indicates the absence of a meaningful value.
  None
  /// A value that indicates some smart default behaviour.
  Auto
  /// A boolean: `true, false`.
  Bool(Bool)
  /// An integer: `120`.
  Int(Int64)
  /// A floating-point number: `1.2`, `10e-4`.
  Float(Double)
  /// A length: `12pt`, `3cm`, `1.5em`, `1em - 2pt`.
  Length(Length)
  /// An angle: `1.5rad`, `90deg`.
  Angle(Angle)
  /// A ratio: `50%`.
  Ratio(Ratio)
  /// A relative length, combination of a ratio and a length: `20% + 5cm`.
  Relative(Rel[Length])
  /// A fraction: `1fr`.
  Fraction(Fr)
  /// A color value: `#f79143ff`.
  Color(Color)
  /// A gradient value: `gradient.linear(...)`.
  Gradient(Gradient)
  /// A tiling fill: `tiling(...)`.
  Tiling(Tiling)
  /// A symbol: `arrow.l`.
  Symbol(Symbol)
  /// A version.
  Version(Version)
  /// A string: `"string"`. Typst strings are indexed by UTF-8 bytes.
  Str(String)
  /// Raw bytes.
  Bytes(BytesValue)
  /// A label: `<intro>`.
  Label(Label)
  /// A datetime.
  Datetime(Datetime)
  /// A decimal value: `decimal("123.4500")`.
  Decimal(Decimal)
  /// A duration.
  Duration(Duration)
  /// A content value: `[*Hi* there]`.
  Content(Content)
  /// Content styles.
  Styles(Styles)
  /// An array of values: `(1, "hi", 12cm)`.
  Array(Arr)
  /// A dictionary value: `(a: 1, b: "hi")`.
  Dict(Dict)
  /// An executable function.
  Func(Func)
  /// Captured arguments to a function.
  Args(Args)
  /// A type.
  Type(Type)
  /// A module.
  Module(Module)
  /// A dynamic value (internal native types).
  Dyn(DynValue)
}

///|
/// Mark containers in this value as shared (upstream: cloning a value bumps
/// reference counts, so a later mutation copies). Returns the value itself.
pub fn Value::shared(self : Value) -> Value {
  match self {
    Array(a) => a.shared = true
    Dict(d) => d.shared = true
    _ => ()
  }
  self
}

///|
/// Create a numeric value from a number with a unit.
pub fn Value::numeric(v : Double, unit : NumericUnit) -> Value {
  match unit {
    Pt => Length(Length::from_abs(Abs::pt(v)))
    Mm => Length(Length::from_abs(Abs::mm(v)))
    Cm => Length(Length::from_abs(Abs::cm(v)))
    In => Length(Length::from_abs(Abs::inches(v)))
    Rad => Angle(Angle::rad(v))
    Deg => Angle(Angle::deg(v))
    Em => Length(Length::from_em(Em::new(v)))
    Fr => Fraction(Fr::new(v))
    Percent => Ratio(Ratio::new(v / 100.0))
  }
}

///|
/// The units of numeric literals (upstream `ast::Unit`).
pub(all) enum NumericUnit {
  Pt
  Mm
  Cm
  In
  Rad
  Deg
  Em
  Fr
  Percent
} derive(Eq, Debug)

///|
/// The type of this value.
pub fn Value::ty(self : Value) -> Type {
  match self {
    None => Type::none()
    Auto => Type::auto()
    Bool(_) => Type::bool()
    Int(_) => Type::int()
    Float(_) => Type::float()
    Length(_) => Type::length()
    Angle(_) => Type::angle()
    Ratio(_) => Type::ratio()
    Relative(_) => Type::relative()
    Fraction(_) => Type::fraction()
    Color(_) => Type::color()
    Gradient(_) => Type::gradient()
    Tiling(_) => Type::tiling()
    Symbol(_) => Type::symbol()
    Version(_) => Type::version()
    Str(_) => Type::str()
    Bytes(_) => Type::bytes()
    Label(_) => Type::label()
    Datetime(_) => Type::datetime()
    Decimal(_) => Type::decimal()
    Duration(_) => Type::duration()
    Content(_) => Type::content()
    Styles(_) => Type::styles()
    Array(_) => Type::array()
    Dict(_) => Type::dict()
    Func(_) => Type::func()
    Args(_) => Type::args()
    Type(_) => Type::type_()
    Module(_) => Type::module()
    Dyn(v) => v.ty()
  }
}

///|
/// The representation of the value (upstream `Repr`).
pub fn Value::repr(self : Value) -> String {
  match self {
    None => "none"
    Auto => "auto"
    Bool(v) => v.to_string()
    Int(v) => repr_int(v)
    Float(v) => repr_float(v)
    Length(v) => v.repr()
    Angle(v) => v.repr()
    Ratio(v) => v.repr()
    Relative(v) => v.repr_length()
    Fraction(v) => v.repr()
    Color(v) => v.repr()
    Gradient(v) => v.repr()
    Tiling(v) => v.repr()
    Symbol(v) => v.repr()
    Version(v) => v.repr()
    Str(v) => repr_str(v)
    Bytes(v) => v.repr()
    Label(v) => v.repr()
    Datetime(v) => v.repr()
    Decimal(v) => v.repr()
    Duration(v) => v.repr()
    Content(v) => v.repr()
    Styles(_) => "styles(..)"
    Array(v) => v.repr()
    Dict(v) => v.repr()
    Func(v) => v.repr()
    Args(v) => v.repr()
    Type(v) => v.repr()
    Module(v) => v.repr()
    Dyn(v) => v.repr()
  }
}

///|
/// Upstream `Repr for i64` (Rust `{:?}`: ASCII minus).
pub fn repr_int(v : Int64) -> String {
  v.to_string()
}

///|
/// Upstream `Repr for f64`.
pub fn repr_float(v : Double) -> String {
  format_float(v, true, "")
}

///|
/// Upstream `Repr for str`: a quoted string with escapes.
pub fn repr_str(s : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for c in s {
    match c {
      '\u{0}' => buf.write_string("\\u{0}")
      '\'' => buf.write_char('\'')
      '"' => buf.write_string("\\\"")
      _ => buf.write_string(rust_escape_debug_char(c))
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
/// Rust's `char::escape_debug` as used by upstream `Repr for str`.
fn rust_escape_debug_char(c : Char) -> String {
  match c {
    '\t' => "\\t"
    '\r' => "\\r"
    '\n' => "\\n"
    '\\' => "\\\\"
    _ => {
      // Reuse the generated Debug-escape tables (escape_debug escapes
      // grapheme extenders and non-printable characters).
      let quoted = @unicode.rust_debug_str(c.to_string())
      quoted.unsafe_substring(start=1, end=quoted.length() - 1)
    }
  }
}

///|
/// Return the display representation of the value.
pub fn Value::display(self : Value) -> Content {
  match self {
    None => Content::empty()
    Int(v) => TextElem::packed(format_int_with_base(v, 10))
    Float(v) => TextElem::packed(display_float(v))
    Decimal(v) => TextElem::packed(v.to_string())
    Str(v) => TextElem::packed(v)
    Version(v) => TextElem::packed(v.to_string())
    Symbol(v) => SymbolElem::packed(v.get())
    Content(v) => v
    Module(module) => module.content()
    _ => RawElem::packed_code(self.repr())
  }
}

///|
/// Attempt to access a field on the value.
pub fn Value::field(
  self : Value,
  field : String,
  guard_ : BindingGuard,
) -> Value raise HintedError {
  match self {
    Symbol(symbol) => Symbol(symbol.modified(guard_, field))
    Version(version) => Int(version.component(field))
    Dict(dict) => dict.get(field).shared()
    Args(args) => args.field(field).shared()
    Content(content) => content.field_by_name(field)
    Type(ty) => ty.field(field, guard_)
    Func(func) => func.field(field, guard_)
    Module(module) => module.field(field, guard_)
    _ => fields_field(self, field)
  }
}

///|
/// The associated scope, if this is a function, type, or module.
pub fn Value::scope(self : Value) -> Scope? {
  match self {
    Func(func) => func.scope()
    Type(ty) => Some(ty.scope())
    Module(module) => Some(module.scope())
    _ => None
  }
}

///|
pub impl Eq for Value with fn equal(self, other) {
  equal(self, other)
}

///|
/// Attach a span to the value, if possible.
pub fn Value::spanned(self : Value, span : @syntax.Span) -> Value {
  match self {
    Content(v) => Content(v.spanned(span))
    Func(v) => Func(v.spanned(span))
    v => v
  }
}
