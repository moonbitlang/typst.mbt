// Port of `typst-library/src/layout/rel.rs`.

///|
/// A length in relation to some known length.
pub(all) struct Rel[T] {
  /// The relative part.
  rel : Ratio
  /// The absolute part.
  abs : T
} derive(Default, Eq, Hash)

///|
pub fn[T : Numeric] Rel::zero() -> Rel[T] {
  { rel: Ratio::zero(), abs: T::zero(), }
}

///|
pub fn[T : Numeric] Rel::one() -> Rel[T] {
  { rel: Ratio::one(), abs: T::zero(), }
}

///|
pub fn[T] Rel::new(rel : Ratio, abs : T) -> Rel[T] {
  { rel, abs, }
}

///|
pub fn[T : Numeric] Rel::from_abs(abs : T) -> Rel[T] {
  { rel: Ratio::zero(), abs, }
}

///|
pub fn[T : Numeric] Rel::from_ratio(rel : Ratio) -> Rel[T] {
  { rel, abs: T::zero(), }
}

///|
pub fn[T : Numeric] Rel::is_zero(self : Rel[T]) -> Bool {
  self.rel.is_zero() && self.abs == T::zero()
}

///|
pub fn[T : Numeric] Rel::is_one(self : Rel[T]) -> Bool {
  self.rel.is_one() && self.abs == T::zero()
}

///|
/// Evaluate this relative to the given `whole`.
pub fn[T : Numeric] Rel::relative_to(self : Rel[T], whole : T) -> T {
  self.rel.of(whole) + self.abs
}

///|
/// Map the absolute part with `f`.
pub fn[T, U] Rel::map(self : Rel[T], f : (T) -> U) -> Rel[U] {
  { rel: self.rel, abs: f(self.abs), }
}

///|
/// Try to divide two relative lengths.
pub fn Rel::try_div_length(self : Rel[Length], other : Rel[Length]) -> Double? {
  if self.rel.is_zero() && other.rel.is_zero() {
    self.abs.try_div(other.abs)
  } else if self.abs.is_zero() && other.abs.is_zero() {
    Some(self.rel.ratio_to(other.rel))
  } else {
    None
  }
}

///|
pub fn Rel::repr_length(self : Rel[Length]) -> String {
  "\{self.rel.repr()} + \{self.abs.repr()}"
}

///|
/// Upstream `PartialOrd for Rel<Length>`.
pub fn Rel::partial_cmp_length(self : Rel[Length], other : Rel[Length]) -> Int? {
  if self.rel.is_zero() && other.rel.is_zero() {
    self.abs.partial_cmp(other.abs)
  } else if self.abs.is_zero() && other.abs.is_zero() {
    Some(self.rel.compare(other.rel))
  } else {
    None
  }
}

///|
pub impl[T : Numeric] Add for Rel[T] with fn add(self, other) {
  { rel: self.rel + other.rel, abs: self.abs + other.abs, }
}

///|
pub impl[T : Numeric] Sub for Rel[T] with fn sub(self, other) {
  { rel: self.rel - other.rel, abs: self.abs - other.abs, }
}

///|
pub impl[T : Numeric] Neg for Rel[T] with fn neg(self) {
  { rel: -self.rel, abs: -self.abs, }
}

///|
pub impl[T : Numeric] Numeric for Rel[T] with fn zero() {
  Rel::zero()
}

///|
pub impl[T : Numeric] Numeric for Rel[T] with fn is_finite(self) {
  Numeric::is_finite(self.rel) && self.abs.is_finite()
}

///|
pub impl[T : Numeric] Numeric for Rel[T] with fn scale(self, factor) {
  { rel: self.rel.times(factor), abs: self.abs.scale(factor), }
}

///|
pub impl[T : Numeric] Numeric for Rel[T] with fn div_scale(self, factor) {
  { rel: self.rel.div_by(factor), abs: self.abs.div_scale(factor), }
}

///|
pub fn[T : Numeric] Rel::times(self : Rel[T], factor : Double) -> Rel[T] {
  { rel: self.rel.times(factor), abs: self.abs.scale(factor), }
}

///|
pub fn[T : Numeric] Rel::div_by(self : Rel[T], factor : Double) -> Rel[T] {
  { rel: self.rel.div_by(factor), abs: self.abs.div_scale(factor), }
}
