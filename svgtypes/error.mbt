// Port of `svgtypes` 0.16.1 `src/error.rs`.
//
// Upstream's type is called `Error`, which is a reserved type name in
// MoonBit, so it is `SvgTypesError` here.

///|
/// List of all errors.
pub(all) suberror SvgTypesError {
  /// An input data ended earlier than expected.
  ///
  /// Should only appear on invalid input data.
  /// Errors in a valid XML should be handled by errors below.
  UnexpectedEndOfStream
  /// An input text contains unknown data.
  UnexpectedData(Int)
  /// A provided string doesn't have a valid data.
  ///
  /// For example, if we try to parse a color form `zzz`
  /// string - we will get this error.
  /// But if we try to parse a number list like `1.2 zzz`,
  /// then we will get `InvalidNumber`, because at least some data is valid.
  InvalidValue
  /// An invalid ident.
  ///
  /// CSS idents have certain rules with regard to the characters they may contain.
  /// For example, they may not start with a number. If an invalid ident is encountered,
  /// this error will be returned.
  InvalidIdent
  /// An invalid/unexpected character.
  ///
  /// The first byte is an actual one, others - expected.
  InvalidChar(Array[Byte], Int)
  /// An unexpected character instead of an XML space.
  ///
  /// The first string is an actual one, others - expected.
  InvalidString(Array[String], Int)
  /// An invalid number.
  InvalidNumber(Int)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SvgTypesError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SvgTypesError with @debug.Debug::{to_repr}

///|
/// Upstream's `Display`.
pub impl Show for SvgTypesError with fn output(self, logger) {
  match self {
    UnexpectedEndOfStream => logger.write_string("unexpected end of stream")
    UnexpectedData(pos) =>
      logger.write_string("unexpected data at position \{pos}")
    InvalidValue => logger.write_string("invalid value")
    InvalidIdent => logger.write_string("invalid ident")
    InvalidChar(chars, pos) => {
      // Vec<u8> -> Vec<String>
      let list : Array[String] = []
      for i in 1..<chars.length() {
        list.push(chars[i].to_int().unsafe_to_char().to_string())
      }
      let actual = chars[0].to_int().unsafe_to_char()
      logger.write_string(
        "expected '\{list.join("', '")}' not '\{actual}' at position \{pos}",
      )
    }
    InvalidString(strings, pos) => {
      let list : Array[String] = []
      for i in 1..<strings.length() {
        list.push(strings[i])
      }
      logger.write_string(
        "expected '\{list.join("', '")}' not '\{strings[0]}' at position \{pos}",
      )
    }
    InvalidNumber(pos) =>
      logger.write_string("invalid number at position \{pos}")
  }
}

///|
pub extend SvgTypesError with Show::{to_string, output}
