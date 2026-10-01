// Port of `time-core/src/util.rs` and `time/src/util.rs`.

///|
/// The minimum valid year (without the `large-dates` feature).
pub const MIN_YEAR : Int = -9999

///|
/// The maximum valid year (without the `large-dates` feature).
pub const MAX_YEAR : Int = 9999

///|
/// Returns if the provided year is a leap year in the proleptic Gregorian
/// calendar. Uses [astronomical year numbering](https://en.wikipedia.org/wiki/Astronomical_year_numbering).
pub fn is_leap_year(year : Int) -> Bool {
  // https://hueffner.de/falk/blog/a-leap-year-check-in-three-instructions.html
  let abs = year.to_int64().abs().reinterpret_as_uint64()
  ((abs * 0x4000_0000_28F5_C28FUL) & 0xC000_000F_8000_000FUL) <= 0xF_8000_0000UL
}

///|
/// Get the number of calendar days in a given year.
pub fn days_in_year(year : Int) -> Int {
  if is_leap_year(year) {
    366
  } else {
    365
  }
}

///|
/// Get the number of weeks in the ISO year.
pub fn weeks_in_year(year : Int) -> Int {
  match year % 400 {
    -396
    | -391
    | -385
    | -380
    | -374
    | -368
    | -363
    | -357
    | -352
    | -346
    | -340
    | -335
    | -329
    | -324
    | -318
    | -312
    | -307
    | -301
    | -295
    | -289
    | -284
    | -278
    | -272
    | -267
    | -261
    | -256
    | -250
    | -244
    | -239
    | -233
    | -228
    | -222
    | -216
    | -211
    | -205
    | -199
    | -193
    | -188
    | -182
    | -176
    | -171
    | -165
    | -160
    | -154
    | -148
    | -143
    | -137
    | -132
    | -126
    | -120
    | -115
    | -109
    | -104
    | -97
    | -92
    | -86
    | -80
    | -75
    | -69
    | -64
    | -58
    | -52
    | -47
    | -41
    | -36
    | -30
    | -24
    | -19
    | -13
    | -8
    | -2
    | 4
    | 9
    | 15
    | 20
    | 26
    | 32
    | 37
    | 43
    | 48
    | 54
    | 60
    | 65
    | 71
    | 76
    | 82
    | 88
    | 93
    | 99
    | 105
    | 111
    | 116
    | 122
    | 128
    | 133
    | 139
    | 144
    | 150
    | 156
    | 161
    | 167
    | 172
    | 178
    | 184
    | 189
    | 195
    | 201
    | 207
    | 212
    | 218
    | 224
    | 229
    | 235
    | 240
    | 246
    | 252
    | 257
    | 263
    | 268
    | 274
    | 280
    | 285
    | 291
    | 296
    | 303
    | 308
    | 314
    | 320
    | 325
    | 331
    | 336
    | 342
    | 348
    | 353
    | 359
    | 364
    | 370
    | 376
    | 381
    | 387
    | 392
    | 398 => 53
    _ => 52
  }
}

///|
/// Get the number of days in the month of a given year.
pub fn days_in_month(month : Month, year : Int) -> Int {
  days_in_month_leap(month.number(), is_leap_year(year))
}

///|
/// Get the number of days in the month (1-12) given whether the year is a
/// leap year.
fn days_in_month_leap(month : Int, is_leap_year : Bool) -> Int {
  if month == 2 {
    if is_leap_year {
      29
    } else {
      28
    }
  } else {
    30 | (month ^ (month >> 3))
  }
}

///|
/// `time_core::util::range_validated::is_leap_year`: only valid for years in
/// `MIN_YEAR..=MAX_YEAR`.
fn range_validated_is_leap_year(year : Int) -> Bool {
  let abs = year.abs().reinterpret_as_uint()
  ((abs * 0x20003D7U) & 0x6007C0FU) <= 0x7C00U
}

///|
fn range_validated_days_in_year(year : Int) -> Int {
  if range_validated_is_leap_year(year) {
    366
  } else {
    365
  }
}

///|
/// Port of the `div_floor!` macro.
fn div_floor(this : Int, rhs : Int) -> Int {
  let d = this / rhs
  let r = this % rhs
  let correction = (this ^ rhs) >> 31
  if r != 0 {
    d + correction
  } else {
    d
  }
}

///|
/// Whether a date adjustment is needed (`time::util::DateAdjustment`).
priv enum DateAdjustment {
  Previous
  Next
  None_
}
