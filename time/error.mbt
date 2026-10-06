// Port of `time/src/error/{component_range,invalid_format_description,format}.rs`.

///|
/// An error type indicating that a component provided to a method was out of
/// range, causing a failure.
pub(all) suberror ComponentRange {
  ComponentRange(name~ : String, is_conditional~ : Bool)
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ComponentRange with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ComponentRange with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ComponentRange with @debug.Debug::{to_repr}

///|
fn ComponentRange::unconditional(name : String) -> ComponentRange {
  ComponentRange(name~, is_conditional=false)
}

///|
fn ComponentRange::conditional(name : String) -> ComponentRange {
  ComponentRange(name~, is_conditional=true)
}

///|
/// Obtain the name of the component whose value was out of range.
pub fn ComponentRange::name(self : ComponentRange) -> String {
  let ComponentRange(name~, ..) = self
  name
}

///|
/// Whether the value's permitted range is conditional, i.e. whether an input
/// with this value could have succeeded if the values of other components
/// were different.
pub fn ComponentRange::is_conditional(self : ComponentRange) -> Bool {
  let ComponentRange(is_conditional~, ..) = self
  is_conditional
}

///|
pub impl Show for ComponentRange with fn output(self, logger) {
  logger.write_string("\{self.name()} was not in range")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ComponentRange with Show::{to_string, output}

///|
/// The format description provided was not valid.
pub(all) suberror InvalidFormatDescription {
  /// There was a bracket pair that was opened but not closed.
  UnclosedOpeningBracket(index~ : Int)
  /// A component name is not valid.
  InvalidComponentName(name~ : String, index~ : Int)
  /// A modifier is not valid.
  InvalidModifier(value~ : String, index~ : Int)
  /// A component name is missing.
  MissingComponentName(index~ : Int)
  /// A required modifier is missing.
  MissingRequiredModifier(name~ : String, index~ : Int)
  /// Something was expected, but not found.
  Expected(what~ : String, index~ : Int)
  /// Certain behavior is not supported in the given context.
  NotSupported(what~ : String, context~ : String, index~ : Int)
  /// A modifier is duplicated.
  DuplicateModifier(name~ : String, index~ : Int)
  /// A modifier is not valid for the given component.
  InvalidModifierCombination(
    modifier~ : String,
    context~ : String,
    index~ : Int
  )
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InvalidFormatDescription with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InvalidFormatDescription with @debug.Debug::{to_repr}

///|
pub impl Show for InvalidFormatDescription with fn output(self, logger) {
  let s = match self {
    UnclosedOpeningBracket(index~) =>
      "unclosed opening bracket at byte index \{index}"
    InvalidComponentName(name~, index~) =>
      "invalid component name `\{name}` at byte index \{index}"
    InvalidModifier(value~, index~) =>
      "invalid modifier `\{value}` at byte index \{index}"
    MissingComponentName(index~) =>
      "missing component name at byte index \{index}"
    MissingRequiredModifier(name~, index~) =>
      "missing required modifier `\{name}` for component at byte index \{index}"
    Expected(what~, index~) => "expected \{what} at byte index \{index}"
    NotSupported(what~, context~, index~) =>
      if context == "" {
        "\{what} is not supported at byte index \{index}"
      } else {
        "\{what} is not supported in \{context} at byte index \{index}"
      }
    DuplicateModifier(name~, index~) =>
      "duplicate modifier `\{name}` at byte index \{index}"
    InvalidModifierCombination(modifier~, context~, index~) =>
      "the `\{modifier}` modifier is not valid at byte index \{index} \{context}"
  }
  logger.write_string(s)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InvalidFormatDescription with Show::{to_string, output}

///|
/// An error occurred when formatting.
pub(all) suberror Format {
  /// The type being formatted does not contain sufficient information to
  /// format a component.
  InsufficientTypeInformation
  /// The component named has a value that cannot be formatted into the
  /// requested format.
  InvalidComponent(String)
  /// A component provided was out of range.
  ComponentRange(ComponentRange)
  /// A value of `std::io::Error` was returned internally.
  StdIo(String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Format with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Format with @debug.Debug::{to_repr}

///|
pub impl Show for Format with fn output(self, logger) {
  match self {
    InsufficientTypeInformation =>
      logger.write_string(
        "The type being formatted does not contain sufficient information to format a component.",
      )
    InvalidComponent(component) =>
      logger.write_string(
        "The \{component} component cannot be formatted into the requested format.",
      )
    ComponentRange(err) => Show::output(err, logger)
    StdIo(err) => logger.write_string(err)
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Format with Show::{to_string, output}
