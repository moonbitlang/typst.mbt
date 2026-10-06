// Port of `time/src/month.rs`.

///|
/// Months of the year.
pub(all) enum Month {
  January
  February
  March
  April
  May
  June
  July
  August
  September
  October
  November
  December
} derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Month with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Month with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Month with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Month with @debug.Debug::{to_repr}

///|
/// `Month::from_number`: create a month from its number (1-12).
fn Month::from_number(n : Int) -> Month raise ComponentRange {
  match n {
    1 => January
    2 => February
    3 => March
    4 => April
    5 => May
    6 => June
    7 => July
    8 => August
    9 => September
    10 => October
    11 => November
    12 => December
    _ => raise ComponentRange::unconditional("month")
  }
}

///|
/// `TryFrom<u8> for Month`.
pub fn Month::try_from_u8(value : Int) -> Month? {
  try Month::try_from(value) catch {
    _ => None
  } noraise {
    m => Some(m)
  }
}

///|
/// `TryFrom<u8> for Month`, keeping the error.
pub fn Month::try_from(value : Int) -> Month raise ComponentRange {
  Month::from_number(value)
}

///|
/// `From<Month> for u8`: the number of the month (January is 1).
pub fn Month::number(self : Month) -> Int {
  match self {
    January => 1
    February => 2
    March => 3
    April => 4
    May => 5
    June => 6
    July => 7
    August => 8
    September => 9
    October => 10
    November => 11
    December => 12
  }
}

///|
/// Get the number of days in the month of a given year.
pub fn Month::length(self : Month, year : Int) -> Int {
  days_in_month(self, year)
}

///|
/// Get the previous month.
pub fn Month::previous(self : Month) -> Month {
  match self {
    January => December
    February => January
    March => February
    April => March
    May => April
    June => May
    July => June
    August => July
    September => August
    October => September
    November => October
    December => November
  }
}

///|
/// Get the next month.
pub fn Month::next(self : Month) -> Month {
  match self {
    January => February
    February => March
    March => April
    April => May
    May => June
    June => July
    July => August
    August => September
    September => October
    October => November
    November => December
    December => January
  }
}

///|
/// The English name of the month.
pub fn Month::name(self : Month) -> String {
  month_names[self.number() - 1]
}

///|
pub impl Show for Month with fn output(self, logger) {
  logger.write_string(self.name())
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Month with Show::{to_string, output}
