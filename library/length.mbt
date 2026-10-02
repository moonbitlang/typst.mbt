// Port of `typst-library/src/layout/length.rs` (without the scope methods,
// which live with the other native functions).

///|
/// A size or distance, possibly expressed with contextual units.
pub(all) struct Length {
  /// The absolute part.
  abs : Abs
  /// The font-relative part.
  em : Em
} derive(Default, Eq, Hash)

///|
pub fn Length::zero() -> Length {
  { abs: Abs::zero(), em: Em::zero(), }
}

///|
pub fn Length::from_abs(abs : Abs) -> Length {
  { abs, em: Em::zero(), }
}

///|
pub fn Length::from_em(em : Em) -> Length {
  { abs: Abs::zero(), em, }
}

///|
/// Try to compute the absolute value of the length.
pub fn Length::try_abs(self : Length) -> Length? {
  if self.abs.is_zero() || self.em.is_zero() {
    Some({ abs: self.abs.abs(), em: self.em.abs(), })
  } else {
    None
  }
}

///|
/// Try to divide two lengths.
pub fn Length::try_div(self : Length, other : Length) -> Double? {
  if self.abs.is_zero() && other.abs.is_zero() {
    Some(self.em.ratio_to(other.em))
  } else if self.em.is_zero() && other.em.is_zero() {
    Some(self.abs.ratio_to(other.abs))
  } else {
    None
  }
}

///|
/// Convert to an absolute length at the given font size.
pub fn Length::at(self : Length, font_size : Abs) -> Abs {
  self.abs + self.em.at(font_size)
}

///|
/// Fails with an error if the length has a non-zero font-relative part.
fn Length::ensure_that_em_is_zero(
  self : Length,
  span : @syntax.Span,
  unit : String,
) -> Unit raise SourceError {
  if self.em == Em::zero() {
    return
  }
  bail_at(
    span,
    "cannot convert a length with non-zero em units (`\{self.repr()}`) to \{unit}",
    hints=[
      "use `length.to-absolute()` to resolve its em component (requires context)",
      "or use `length.abs.\{unit}()` instead to ignore its em component",
    ],
  )
}

///|
/// Converts this length to points.
fn impl_length_to_pt(
  self_ : Length,
  span : @syntax.Span,
) -> Double raise SourceError {
  self_.ensure_that_em_is_zero(span, "pt")
  self_.abs.to_pt()
}

///|
/// Converts this length to millimeters.
fn impl_length_to_mm(
  self_ : Length,
  span : @syntax.Span,
) -> Double raise SourceError {
  self_.ensure_that_em_is_zero(span, "mm")
  self_.abs.to_mm()
}

///|
/// Converts this length to centimeters.
fn impl_length_to_cm(
  self_ : Length,
  span : @syntax.Span,
) -> Double raise SourceError {
  self_.ensure_that_em_is_zero(span, "cm")
  self_.abs.to_cm()
}

///|
/// Converts this length to inches.
fn impl_length_to_inches(
  self_ : Length,
  span : @syntax.Span,
) -> Double raise SourceError {
  self_.ensure_that_em_is_zero(span, "inches")
  self_.abs.to_inches()
}

///|
/// Resolve this length to an absolute length.
fn impl_length_to_absolute(
  self_ : Length,
  context : Context,
) -> Length raise HintedError {
  Length::from_abs(self_.resolve(context.get_styles()))
}

///|
/// Resolve the length to an absolute length (upstream `Resolve for Length`).
pub fn Length::resolve(self : Length, styles : StyleChain) -> Abs {
  self.abs + self.em.resolve(styles)
}

///|
/// Resolve the em length to an absolute length (upstream `Resolve for Em`).
pub fn Em::resolve(self : Em, styles : StyleChain) -> Abs {
  if self.is_zero() {
    Abs::zero()
  } else {
    self.at(resolve_text_size(styles))
  }
}

///|
/// The resolved font size (upstream `styles.resolve(TextElem::size)`).
fn resolve_text_size(styles : StyleChain) -> Abs {
  TextElem::size_in(styles).resolve(styles)
}

///|
pub impl Fold for Length with fn fold(self, _) {
  self
}

///|
pub fn Length::repr(self : Length) -> String {
  match (self.abs.is_zero(), self.em.is_zero()) {
    (false, false) => "\{self.abs.repr()} + \{self.em.repr()}"
    (true, false) => self.em.repr()
    (_, true) => self.abs.repr()
  }
}

///|
/// Upstream `PartialOrd for Length`.
pub fn Length::partial_cmp(self : Length, other : Length) -> Int? {
  if self.em.is_zero() && other.em.is_zero() {
    Some(self.abs.compare(other.abs))
  } else if self.abs.is_zero() && other.abs.is_zero() {
    Some(self.em.compare(other.em))
  } else {
    None
  }
}

///|
pub impl Add for Length with fn add(self, other) {
  { abs: self.abs + other.abs, em: self.em + other.em, }
}

///|
pub impl Sub for Length with fn sub(self, other) {
  { abs: self.abs - other.abs, em: self.em - other.em, }
}

///|
pub impl Neg for Length with fn neg(self) {
  { abs: -self.abs, em: -self.em, }
}

///|
pub impl Numeric for Length with fn zero() {
  Length::zero()
}

///|
pub impl Numeric for Length with fn is_finite(self) {
  self.abs.is_finite() && Numeric::is_finite(self.em)
}

///|
pub impl Numeric for Length with fn scale(self, factor) {
  { abs: self.abs.times(factor), em: self.em.times(factor), }
}

///|
pub impl Numeric for Length with fn div_scale(self, factor) {
  self.div_by(factor)
}

///|
pub fn Length::times(self : Length, factor : Double) -> Length {
  { abs: self.abs.times(factor), em: self.em.times(factor), }
}

///|
pub fn Length::div_by(self : Length, factor : Double) -> Length {
  { abs: self.abs.div_by(factor), em: self.em.div_by(factor), }
}

///|
pub fn Length::is_zero(self : Length) -> Bool {
  self.abs.is_zero() && self.em.is_zero()
}
