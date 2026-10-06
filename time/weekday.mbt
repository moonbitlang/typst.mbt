// Port of `time/src/weekday.rs`.

///|
/// Days of the week.
///
/// As order is dependent on context (Sunday could be either two days after or
/// five days before Friday), this type does not implement `Compare`.
pub(all) enum Weekday {
  Monday
  Tuesday
  Wednesday
  Thursday
  Friday
  Saturday
  Sunday
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Weekday with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Weekday with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Weekday with @debug.Debug::{to_repr}

///|
/// Get the previous weekday.
pub fn Weekday::previous(self : Weekday) -> Weekday {
  match self {
    Monday => Sunday
    Tuesday => Monday
    Wednesday => Tuesday
    Thursday => Wednesday
    Friday => Thursday
    Saturday => Friday
    Sunday => Saturday
  }
}

///|
/// Get the next weekday.
pub fn Weekday::next(self : Weekday) -> Weekday {
  match self {
    Monday => Tuesday
    Tuesday => Wednesday
    Wednesday => Thursday
    Thursday => Friday
    Friday => Saturday
    Saturday => Sunday
    Sunday => Monday
  }
}

///|
/// Get the one-indexed number of days from Monday.
pub fn Weekday::number_from_monday(self : Weekday) -> Int {
  self.number_days_from_monday() + 1
}

///|
/// Get the one-indexed number of days from Sunday.
pub fn Weekday::number_from_sunday(self : Weekday) -> Int {
  self.number_days_from_sunday() + 1
}

///|
/// Get the zero-indexed number of days from Monday.
pub fn Weekday::number_days_from_monday(self : Weekday) -> Int {
  match self {
    Monday => 0
    Tuesday => 1
    Wednesday => 2
    Thursday => 3
    Friday => 4
    Saturday => 5
    Sunday => 6
  }
}

///|
/// Get the zero-indexed number of days from Sunday.
pub fn Weekday::number_days_from_sunday(self : Weekday) -> Int {
  match self {
    Monday => 1
    Tuesday => 2
    Wednesday => 3
    Thursday => 4
    Friday => 5
    Saturday => 6
    Sunday => 0
  }
}

///|
/// The English name of the weekday.
pub fn Weekday::name(self : Weekday) -> String {
  weekday_names[self.number_days_from_monday()]
}

///|
pub impl Show for Weekday with fn output(self, logger) {
  logger.write_string(self.name())
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Weekday with Show::{to_string, output}
