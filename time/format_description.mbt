// Port of `time/src/format_description/{component,modifier,
// borrowed_format_item,owned_format_item}.rs`.
//
// Modifier structs (`modifier::Day { padding }` etc.) are flattened into
// labeled constructor arguments of `Component`. Deprecated components that
// are no longer emitted by parsers are omitted.

///|
/// Type of padding to ensure a minimum width.
pub(all) enum Padding {
  /// A space character (` `) should be used as padding.
  Space
  /// A zero character (`0`) should be used as padding.
  Zero
  /// There is no padding. This can result in a width below the otherwise
  /// minimum number of characters. (`Padding::None` upstream.)
  None_
} derive(Eq, Hash, Debug)

///|
/// The number of digits present in a subsecond representation.
pub(all) enum SubsecondDigits {
  /// Exactly one digit.
  One
  /// Exactly two digits.
  Two
  /// Exactly three digits.
  Three
  /// Exactly four digits.
  Four
  /// Exactly five digits.
  Five
  /// Exactly six digits.
  Six
  /// Exactly seven digits.
  Seven
  /// Exactly eight digits.
  Eight
  /// Exactly nine digits.
  Nine
  /// Any number of digits (up to nine) that is at least one. When formatting,
  /// the minimum digits necessary will be used.
  OneOrMore
} derive(Eq, Hash, Debug)

///|
/// Indicate whether to permit trailing input when parsing.
pub(all) enum TrailingInput {
  /// Trailing input is not permitted and will cause an error.
  Prohibit
  /// Trailing input is permitted but discarded.
  Discard
} derive(Eq, Hash, Debug)

///|
/// A component of a larger format description.
pub(all) enum Component {
  /// Day of the month.
  Day(padding~ : Padding)
  /// Month of the year using the short form of the month name.
  MonthShort(case_sensitive~ : Bool)
  /// Month of the year using the long form of the month name.
  MonthLong(case_sensitive~ : Bool)
  /// Month of the year using a numerical representation (1 = January).
  MonthNumerical(padding~ : Padding)
  /// Ordinal day of the year.
  Ordinal(padding~ : Padding)
  /// Day of the week using the short form of the weekday.
  WeekdayShort(case_sensitive~ : Bool)
  /// Day of the week using the long form of the weekday.
  WeekdayLong(case_sensitive~ : Bool)
  /// Day of the week using a numerical representation with Sunday as the
  /// first day of the week.
  WeekdaySunday(one_indexed~ : Bool)
  /// Day of the week using a numerical representation with Monday as the
  /// first day of the week.
  WeekdayMonday(one_indexed~ : Bool)
  /// Week number of the year using the ISO week numbering.
  WeekNumberIso(padding~ : Padding)
  /// Week number of the year, where week 1 starts on the first Sunday.
  WeekNumberSunday(padding~ : Padding)
  /// Week number of the year, where week 1 starts on the first Monday.
  WeekNumberMonday(padding~ : Padding)
  /// The calendar year (extended range).
  CalendarYearFullExtendedRange(padding~ : Padding, sign_is_mandatory~ : Bool)
  /// The calendar year (standard range).
  CalendarYearFullStandardRange(padding~ : Padding, sign_is_mandatory~ : Bool)
  /// The ISO week-based year (extended range).
  IsoYearFullExtendedRange(padding~ : Padding, sign_is_mandatory~ : Bool)
  /// The ISO week-based year (standard range).
  IsoYearFullStandardRange(padding~ : Padding, sign_is_mandatory~ : Bool)
  /// The century of the calendar year (extended range).
  CalendarYearCenturyExtendedRange(
    padding~ : Padding,
    sign_is_mandatory~ : Bool
  )
  /// The century of the calendar year (standard range).
  CalendarYearCenturyStandardRange(
    padding~ : Padding,
    sign_is_mandatory~ : Bool
  )
  /// The century of the ISO week-based year (extended range).
  IsoYearCenturyExtendedRange(padding~ : Padding, sign_is_mandatory~ : Bool)
  /// The century of the ISO week-based year (standard range).
  IsoYearCenturyStandardRange(padding~ : Padding, sign_is_mandatory~ : Bool)
  /// The last two digits of the calendar year.
  CalendarYearLastTwo(padding~ : Padding)
  /// The last two digits of the ISO week-based year.
  IsoYearLastTwo(padding~ : Padding)
  /// Hour of the day using the 12-hour clock.
  Hour12(padding~ : Padding)
  /// Hour of the day using the 24-hour clock.
  Hour24(padding~ : Padding)
  /// Minute within the hour.
  Minute(padding~ : Padding)
  /// AM/PM part of the time.
  Period(is_uppercase~ : Bool, case_sensitive~ : Bool)
  /// Second within the minute.
  Second(padding~ : Padding)
  /// Subsecond within the second.
  Subsecond(digits~ : SubsecondDigits)
  /// Hour of the UTC offset.
  OffsetHour(sign_is_mandatory~ : Bool, padding~ : Padding)
  /// Minute within the hour of the UTC offset.
  OffsetMinute(padding~ : Padding)
  /// Second within the minute of the UTC offset.
  OffsetSecond(padding~ : Padding)
  /// A number of bytes to ignore when parsing. This has no effect on
  /// formatting.
  Ignore(count~ : Int)
  /// A Unix timestamp in seconds.
  UnixTimestampSecond(sign_is_mandatory~ : Bool)
  /// A Unix timestamp in milliseconds.
  UnixTimestampMillisecond(sign_is_mandatory~ : Bool)
  /// A Unix timestamp in microseconds.
  UnixTimestampMicrosecond(sign_is_mandatory~ : Bool)
  /// A Unix timestamp in nanoseconds.
  UnixTimestampNanosecond(sign_is_mandatory~ : Bool)
  /// The end of input. Parsing this component will fail if there is any
  /// input remaining. This component neither affects formatting nor consumes
  /// any input when parsing.
  End(trailing_input~ : TrailingInput)
} derive(Eq, Hash, Debug)

///|
/// A complete description of how to format and parse a type.
///
/// This unifies `BorrowedFormatItem` and `OwnedFormatItem`.
pub(all) enum FormatItem {
  /// A string that is formatted as-is.
  StringLiteral(String)
  /// A minimal representation of a single non-literal item.
  Component(Component)
  /// A series of literals or components that collectively form a partial or
  /// complete description.
  Compound(Array[FormatItem])
  /// A `FormatItem` that may or may not be present when parsing. This variant
  /// has no effect on formatting, as the value is guaranteed to be present.
  Optional(FormatItem)
  /// A series of `FormatItem`s where, when parsing, the first successful
  /// parse is used. When formatting, the first element of the slice is used.
  /// An empty slice is a no-op when formatting or parsing.
  First(Array[FormatItem])
} derive(Eq, Hash, Debug)
