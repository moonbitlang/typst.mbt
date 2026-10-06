// Generated from gen/manifest.json (#[ty] definitions). Do not edit.

///|
let alignment_type_data : NativeTypeData = NativeTypeData::new(
  name="alignment",
  long_name="alignment",
  title="Alignment",
  docs="Where to align something along an axis.",
)

///|
/// The `alignment` type (upstream `Alignment`).
pub fn Type::alignment() -> Type {
  Type(alignment_type_data)
}

///|
let angle_type_data : NativeTypeData = NativeTypeData::new(
  name="angle",
  long_name="angle",
  title="Angle",
  docs="An angle describing a rotation.",
)

///|
/// The `angle` type (upstream `Angle`).
pub fn Type::angle() -> Type {
  Type(angle_type_data)
}

///|
let args_type_data : NativeTypeData = NativeTypeData::new(
  name="arguments",
  long_name="arguments",
  title="Arguments",
  docs="Captured arguments to a function.",
)

///|
/// The `arguments` type (upstream `Args`).
pub fn Type::args() -> Type {
  Type(args_type_data)
}

///|
let array_type_data : NativeTypeData = NativeTypeData::new(
  name="array",
  long_name="array",
  title="Array",
  docs="A sequence of values.",
)

///|
/// The `array` type (upstream `Array`).
pub fn Type::array() -> Type {
  Type(array_type_data)
}

///|
let auto_type_data : NativeTypeData = NativeTypeData::new(
  name="auto",
  long_name="auto",
  title="Auto",
  docs="A value that indicates a smart default.",
)

///|
/// The `auto` type (upstream `AutoValue`).
pub fn Type::auto() -> Type {
  Type(auto_type_data)
}

///|
let bool_type_data : NativeTypeData = NativeTypeData::new(
  name="bool",
  long_name="boolean",
  title="Boolean",
  docs="A type with two states.",
)

///|
/// The `bool` type (upstream `bool`).
pub fn Type::bool() -> Type {
  Type(bool_type_data)
}

///|
let bytes_type_data : NativeTypeData = NativeTypeData::new(
  name="bytes",
  long_name="bytes",
  title="Bytes",
  docs="A sequence of bytes.",
)

///|
/// The `bytes` type (upstream `Bytes`).
pub fn Type::bytes() -> Type {
  Type(bytes_type_data)
}

///|
let color_type_data : NativeTypeData = NativeTypeData::new(
  name="color",
  long_name="color",
  title="Color",
  docs="A color in a specific color space.",
)

///|
/// The `color` type (upstream `Color`).
pub fn Type::color() -> Type {
  Type(color_type_data)
}

///|
let content_type_data : NativeTypeData = NativeTypeData::new(
  name="content",
  long_name="content",
  title="Content",
  docs="A piece of document content.",
)

///|
/// The `content` type (upstream `Content`).
pub fn Type::content() -> Type {
  Type(content_type_data)
}

///|
let counter_type_data : NativeTypeData = NativeTypeData::new(
  name="counter",
  long_name="counter",
  title="Counter",
  docs="Counts through pages, elements, and more.",
)

///|
/// The `counter` type (upstream `Counter`).
pub fn Type::counter() -> Type {
  Type(counter_type_data)
}

///|
let datetime_type_data : NativeTypeData = NativeTypeData::new(
  name="datetime",
  long_name="datetime",
  title="Datetime",
  docs="Represents a date, a time, or a combination of both.",
)

///|
/// The `datetime` type (upstream `Datetime`).
pub fn Type::datetime() -> Type {
  Type(datetime_type_data)
}

///|
let decimal_type_data : NativeTypeData = NativeTypeData::new(
  name="decimal",
  long_name="decimal",
  title="Decimal",
  docs="A fixed-point decimal number type.",
)

///|
/// The `decimal` type (upstream `Decimal`).
pub fn Type::decimal() -> Type {
  Type(decimal_type_data)
}

///|
let dict_type_data : NativeTypeData = NativeTypeData::new(
  name="dictionary",
  long_name="dictionary",
  title="Dictionary",
  docs="A map from string keys to values.",
)

///|
/// The `dictionary` type (upstream `Dict`).
pub fn Type::dict() -> Type {
  Type(dict_type_data)
}

///|
let direction_type_data : NativeTypeData = NativeTypeData::new(
  name="direction",
  long_name="direction",
  title="Direction",
  docs="The four directions into which content can be laid out.",
)

///|
/// The `direction` type (upstream `Dir`).
pub fn Type::direction() -> Type {
  Type(direction_type_data)
}

///|
let duration_type_data : NativeTypeData = NativeTypeData::new(
  name="duration",
  long_name="duration",
  title="Duration",
  docs="Represents a positive or negative span of time.",
)

///|
/// The `duration` type (upstream `Duration`).
pub fn Type::duration() -> Type {
  Type(duration_type_data)
}

///|
let float_type_data : NativeTypeData = NativeTypeData::new(
  name="float",
  long_name="float",
  title="Float",
  docs="A floating-point number.",
)

///|
/// The `float` type (upstream `f64`).
pub fn Type::float() -> Type {
  Type(float_type_data)
}

///|
let fraction_type_data : NativeTypeData = NativeTypeData::new(
  name="fraction",
  long_name="fraction",
  title="Fraction",
  docs="Defines how the remaining space in a layout is distributed.",
)

///|
/// The `fraction` type (upstream `Fr`).
pub fn Type::fraction() -> Type {
  Type(fraction_type_data)
}

///|
let func_type_data : NativeTypeData = NativeTypeData::new(
  name="function",
  long_name="function",
  title="Function",
  docs="A mapping from argument values to a return value.",
)

///|
/// The `function` type (upstream `Func`).
pub fn Type::func() -> Type {
  Type(func_type_data)
}

///|
let gradient_type_data : NativeTypeData = NativeTypeData::new(
  name="gradient",
  long_name="gradient",
  title="Gradient",
  docs="A color gradient.",
)

///|
/// The `gradient` type (upstream `Gradient`).
pub fn Type::gradient() -> Type {
  Type(gradient_type_data)
}

///|
let int_type_data : NativeTypeData = NativeTypeData::new(
  name="int",
  long_name="integer",
  title="Integer",
  docs="An integer: a positive whole number, a negative whole number, or zero.",
)

///|
/// The `int` type (upstream `i64`).
pub fn Type::int() -> Type {
  Type(int_type_data)
}

///|
let label_type_data : NativeTypeData = NativeTypeData::new(
  name="label",
  long_name="label",
  title="Label",
  docs="A label for an element.",
)

///|
/// The `label` type (upstream `Label`).
pub fn Type::label() -> Type {
  Type(label_type_data)
}

///|
let length_type_data : NativeTypeData = NativeTypeData::new(
  name="length",
  long_name="length",
  title="Length",
  docs="A size or distance, possibly expressed with contextual units.",
)

///|
/// The `length` type (upstream `Length`).
pub fn Type::length() -> Type {
  Type(length_type_data)
}

///|
let location_type_data : NativeTypeData = NativeTypeData::new(
  name="location",
  long_name="location",
  title="Location",
  docs="Identifies an element in the document.",
)

///|
/// The `location` type (upstream `Location`).
pub fn Type::location() -> Type {
  Type(location_type_data)
}

///|
let module__type_data : NativeTypeData = NativeTypeData::new(
  name="module",
  long_name="module",
  title="Module",
  docs="A collection of variables and functions that are commonly related to a single theme.",
)

///|
/// The `module` type (upstream `Module`).
pub fn Type::module_() -> Type {
  Type(module__type_data)
}

///|
let none_type_data : NativeTypeData = NativeTypeData::new(
  name="none",
  long_name="none",
  title="None",
  docs="A value that indicates the absence of any other value.",
)

///|
/// The `none` type (upstream `NoneValue`).
pub fn Type::none() -> Type {
  Type(none_type_data)
}

///|
let path_type_data : NativeTypeData = NativeTypeData::new(
  name="path",
  long_name="path",
  title="Path",
  docs="A file system path.",
)

///|
/// The `path` type (upstream `RootedPath`).
pub fn Type::path() -> Type {
  Type(path_type_data)
}

///|
let ratio_type_data : NativeTypeData = NativeTypeData::new(
  name="ratio",
  long_name="ratio",
  title="Ratio",
  docs="A ratio of a whole.",
)

///|
/// The `ratio` type (upstream `Ratio`).
pub fn Type::ratio() -> Type {
  Type(ratio_type_data)
}

///|
let regex_type_data : NativeTypeData = NativeTypeData::new(
  name="regex",
  long_name="regex",
  title="Regex",
  docs="A regular expression.",
)

///|
/// The `regex` type (upstream `Regex`).
pub fn Type::regex() -> Type {
  Type(regex_type_data)
}

///|
let relative_type_data : NativeTypeData = NativeTypeData::new(
  name="relative",
  long_name="relative length",
  title="Relative Length",
  docs="A length in relation to some known length.",
)

///|
/// The `relative` type (upstream `Rel`).
pub fn Type::relative() -> Type {
  Type(relative_type_data)
}

///|
let selector_type_data : NativeTypeData = NativeTypeData::new(
  name="selector",
  long_name="selector",
  title="Selector",
  docs="A filter for selecting elements within the document.",
)

///|
/// The `selector` type (upstream `Selector`).
pub fn Type::selector() -> Type {
  Type(selector_type_data)
}

///|
let spot_type_data : NativeTypeData = NativeTypeData::new(
  name="spot",
  long_name="spot colorant",
  title="Spot Colorant",
  docs="A spot colorant from which spot colors can be created.",
)

///|
/// The `spot` type (upstream `SpotColorant`).
pub fn Type::spot() -> Type {
  Type(spot_type_data)
}

///|
let state_type_data : NativeTypeData = NativeTypeData::new(
  name="state",
  long_name="state",
  title="State",
  docs="Manages stateful parts of your document.",
)

///|
/// The `state` type (upstream `State`).
pub fn Type::state() -> Type {
  Type(state_type_data)
}

///|
let str_type_data : NativeTypeData = NativeTypeData::new(
  name="str",
  long_name="string",
  title="String",
  docs="A sequence of Unicode codepoints.",
)

///|
/// The `str` type (upstream `Str`).
pub fn Type::str() -> Type {
  Type(str_type_data)
}

///|
let stroke_type_data : NativeTypeData = NativeTypeData::new(
  name="stroke",
  long_name="stroke",
  title="Stroke",
  docs="Defines how to draw a line.",
)

///|
/// The `stroke` type (upstream `Stroke`).
pub fn Type::stroke() -> Type {
  Type(stroke_type_data)
}

///|
let styles_type_data : NativeTypeData = NativeTypeData::new(
  name="styles",
  long_name="styles",
  title="Styles",
  docs="A list of style properties.",
)

///|
/// The `styles` type (upstream `Styles`).
pub fn Type::styles() -> Type {
  Type(styles_type_data)
}

///|
let symbol_type_data : NativeTypeData = NativeTypeData::new(
  name="symbol",
  long_name="symbol",
  title="Symbol",
  docs="A Unicode symbol.",
)

///|
/// The `symbol` type (upstream `Symbol`).
pub fn Type::symbol() -> Type {
  Type(symbol_type_data)
}

///|
let tiling_type_data : NativeTypeData = NativeTypeData::new(
  name="tiling",
  long_name="tiling",
  title="Tiling",
  docs="A repeating tiling fill.",
)

///|
/// The `tiling` type (upstream `Tiling`).
pub fn Type::tiling() -> Type {
  Type(tiling_type_data)
}

///|
let type__type_data : NativeTypeData = NativeTypeData::new(
  name="type",
  long_name="type",
  title="Type",
  docs="Describes a kind of value.",
)

///|
/// The `type` type (upstream `Type`).
pub fn Type::type_() -> Type {
  Type(type__type_data)
}

///|
let version_type_data : NativeTypeData = NativeTypeData::new(
  name="version",
  long_name="version",
  title="Version",
  docs="A version with an arbitrary number of components.",
)

///|
/// The `version` type (upstream `Version`).
pub fn Type::version() -> Type {
  Type(version_type_data)
}

///|
/// All native types defined in the library, by short name.
pub fn Type::all_native() -> Array[Type] {
  [
    Type::alignment(),
    Type::angle(),
    Type::args(),
    Type::array(),
    Type::auto(),
    Type::bool(),
    Type::bytes(),
    Type::color(),
    Type::content(),
    Type::counter(),
    Type::datetime(),
    Type::decimal(),
    Type::dict(),
    Type::direction(),
    Type::duration(),
    Type::float(),
    Type::fraction(),
    Type::func(),
    Type::gradient(),
    Type::int(),
    Type::label(),
    Type::length(),
    Type::location(),
    Type::module_(),
    Type::none(),
    Type::path(),
    Type::ratio(),
    Type::regex(),
    Type::relative(),
    Type::selector(),
    Type::spot(),
    Type::state(),
    Type::str(),
    Type::stroke(),
    Type::styles(),
    Type::symbol(),
    Type::tiling(),
    Type::type_(),
    Type::version(),
  ]
}
