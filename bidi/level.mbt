// Port of `unicode-bidi 0.3.18`: `level.rs`.
//
// Bidi Embedding Level
//
// <http://www.unicode.org/reports/tr9/#BD2>

///|
/// Embedding Level
///
/// Embedding Levels are numbers between 0 and 126 (inclusive), where even values denote a
/// left-to-right (LTR) direction and odd values a right-to-left (RTL) direction.
///
/// This struct maintains a *valid* status for level numbers, meaning that creating a new level, or
/// mutating an existing level, with the value smaller than `0` (before conversion to `u8`) or
/// larger than 125 results in an `Error`.
///
/// <http://www.unicode.org/reports/tr9/#BD2>
pub(all) struct Level(Int) derive(Eq, Compare, Hash, Debug)

///|
pub let ltr_level : Level = Level(0)

///|
pub let rtl_level : Level = Level(1)

///|
let max_depth : Int = 125

///|
/// During explicit level resolution, embedding level can go as high as `max_depth`.
pub let max_explicit_depth : Int = max_depth

///|
/// During implicit level resolution, embedding level can go as high as `max_depth + 1`.
pub let max_implicit_depth : Int = max_depth + 1

///|
/// Errors that can occur on Level creation or mutation
pub(all) enum LevelError {
  /// Out-of-range (invalid) embedding level number.
  OutOfRangeNumber
} derive(Eq, Debug)

///|
/// New LTR level with smallest number value (0).
pub fn Level::ltr() -> Level {
  ltr_level
}

///|
/// New RTL level with smallest number value (1).
pub fn Level::rtl() -> Level {
  rtl_level
}

///|
/// Maximum depth of the directional status stack during implicit resolutions.
pub fn Level::max_implicit_depth() -> Int {
  max_implicit_depth
}

///|
/// Maximum depth of the directional status stack during explicit resolutions.
pub fn Level::max_explicit_depth() -> Int {
  max_explicit_depth
}

///|
/// Create new level, fail if number is larger than `max_depth + 1`.
pub fn Level::new(number : Int) -> Result[Level, LevelError] {
  if number >= 0 && number <= max_implicit_depth {
    Ok(Level(number))
  } else {
    Err(OutOfRangeNumber)
  }
}

///|
/// Create new level, fail if number is larger than `max_depth`.
pub fn Level::new_explicit(number : Int) -> Result[Level, LevelError] {
  if number >= 0 && number <= max_explicit_depth {
    Ok(Level(number))
  } else {
    Err(OutOfRangeNumber)
  }
}

///|
/// The level number.
pub fn Level::number(self : Level) -> Int {
  self.0
}

///|
/// If this level is left-to-right.
pub fn Level::is_ltr(self : Level) -> Bool {
  self.0 % 2 == 0
}

///|
/// If this level is right-to-left.
pub fn Level::is_rtl(self : Level) -> Bool {
  self.0 % 2 == 1
}

///|
/// Raise level by `amount`, fail if number is larger than `max_depth + 1`.
pub fn Level::raise_level(
  self : Level,
  amount : Int,
) -> Result[Level, LevelError] {
  let number = self.0 + amount
  if number <= 255 && number <= max_implicit_depth {
    Ok(Level(number))
  } else {
    Err(OutOfRangeNumber)
  }
}

///|
/// Raise level by `amount`, fail if number is larger than `max_depth`.
pub fn Level::raise_level_explicit(
  self : Level,
  amount : Int,
) -> Result[Level, LevelError] {
  let number = self.0 + amount
  if number <= 255 && number <= max_explicit_depth {
    Ok(Level(number))
  } else {
    Err(OutOfRangeNumber)
  }
}

///|
/// Lower level by `amount`, fail if number goes below zero.
pub fn Level::lower(self : Level, amount : Int) -> Result[Level, LevelError] {
  let number = self.0 - amount
  if number >= 0 {
    Ok(Level(number))
  } else {
    Err(OutOfRangeNumber)
  }
}

///|
/// The next LTR (even) level greater than this, or fail if number is larger than `max_depth`.
pub fn Level::new_explicit_next_ltr(self : Level) -> Result[Level, LevelError] {
  Level::new_explicit((self.0 + 2) & -2)
}

///|
/// The next RTL (odd) level greater than this, or fail if number is larger than `max_depth`.
pub fn Level::new_explicit_next_rtl(self : Level) -> Result[Level, LevelError] {
  Level::new_explicit((self.0 + 1) | 1)
}

///|
/// The lowest RTL (odd) level greater than or equal to this, or fail if number is larger than
/// `max_depth + 1`.
pub fn Level::new_lowest_ge_rtl(self : Level) -> Result[Level, LevelError] {
  Level::new(self.0 | 1)
}

///|
/// Generate a character type based on a level (as specified in steps X10 and N2).
pub fn Level::bidi_class(self : Level) -> BidiClass {
  if self.is_rtl() {
    R
  } else {
    L
  }
}

///|
/// Create a vector of levels from numbers (panics on invalid numbers).
pub fn Level::vec(v : Array[Int]) -> Array[Level] {
  v.map(x => Level::new(x).unwrap())
}

///|
/// If levels has any RTL (odd) level
///
/// This information is usually used to skip re-ordering of text when no RTL level is present
pub fn has_rtl(levels : ArrayView[Level]) -> Bool {
  levels.iter().any(lvl => lvl.is_rtl())
}

///|
fn[T] expect_level(r : Result[T, LevelError], msg : String) -> T {
  match r {
    Ok(v) => v
    Err(_) => abort(msg)
  }
}
