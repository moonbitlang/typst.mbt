// Port of `typst-library/src/visualize/tiling.rs`.

///|
/// A repeating tiling fill.
pub(all) struct Tiling {
  /// The tile's laid out body.
  frame : Frame
  /// The size of the tile.
  size : Axes[Abs]
  /// The spacing between tiles.
  spacing : Axes[Abs]
  /// The offset of the tiling.
  offset : Axes[Abs]
  /// The rotation of the tiling.
  angle : Angle
  /// The relative placement of the tiling.
  relative : Smart[RelativeTo]
} derive(Eq)

///|
fn impl_tiling_construct__size_default() -> @syntax.Spanned[Smart[Axes[Length]]] raise SourceError {
  { v: Auto, span: @syntax.Span::detached(), }
}

///|
fn impl_tiling_construct__spacing_default() -> @syntax.Spanned[Axes[Length]] raise SourceError {
  {
    v: Axes::new(Length::zero(), Length::zero()),
    span: @syntax.Span::detached(),
  }
}

///|
fn impl_tiling_construct__offset_default() -> @syntax.Spanned[Axes[Rel[Length]]] raise SourceError {
  { v: Axes::new(Rel::zero(), Rel::zero()), span: @syntax.Span::detached(), }
}

///|
fn impl_tiling_construct__angle_default() -> @syntax.Spanned[Angle] raise SourceError {
  { v: Angle::zero(), span: @syntax.Span::detached(), }
}

///|
/// Construct a new tiling.
fn impl_tiling_construct(
  engine : Engine,
  span : @syntax.Span,
  size_ : @syntax.Spanned[Smart[Axes[Length]]],
  spacing_ : @syntax.Spanned[Axes[Length]],
  offset_ : @syntax.Spanned[Axes[Rel[Length]]],
  angle_ : @syntax.Spanned[Angle],
  relative_ : Smart[RelativeTo],
  body_ : Content,
) -> Tiling raise SourceError {
  let size_span = size_.span
  if size_.v is Custom(size) {
    // Ensure that sizes are absolute.
    if !size.x.em.is_zero() || !size.y.em.is_zero() {
      bail_at(size_span, "tile size must be absolute")
    }
    // Ensure that sizes are non-zero and finite.
    if size.x.is_zero() ||
      size.y.is_zero() ||
      !size.x.abs.is_finite() ||
      !size.y.abs.is_finite() {
      bail_at(size_span, "tile size must be non-zero and non-infinite")
    }
  }
  let spacing = spacing_.v
  // Ensure that spacing is absolute.
  if !spacing.x.em.is_zero() || !spacing.y.em.is_zero() {
    bail_at(spacing_.span, "tile spacing must be absolute")
  }
  // Ensure that spacing is finite.
  if !spacing.x.abs.is_finite() || !spacing.y.abs.is_finite() {
    bail_at(spacing_.span, "tile spacing must be finite")
  }
  let offset = offset_.v
  // Ensure that offset is not font-relative.
  if !offset.x.abs.em.is_zero() || !offset.y.abs.em.is_zero() {
    bail_at(offset_.span, "tile offset must not be font-relative")
  }
  // Ensure that offset is finite.
  if !Numeric::is_finite(offset.x.rel) ||
    !offset.x.abs.abs.is_finite() ||
    !Numeric::is_finite(offset.y.rel) ||
    !offset.y.abs.abs.is_finite() {
    bail_at(offset_.span, "tile offset must be finite")
  }
  if !Numeric::is_finite(angle_.v) {
    bail_at(angle_.span, "tile angle must be finite")
  }

  // The size of the frame
  let size = size_.v.map(l => l.map(a => a.abs))
  let region = size.unwrap_or(Axes::splat(Abs::inf()))

  // Layout the tiling.
  let locator = Locator::root()
  let styles = StyleChain::new(engine.library.styles)
  let pod = LayoutRegion::new(region, Axes::splat(false))
  let frame = (engine.routines().layout_frame)(
    engine, body_, locator, styles, pod,
  )

  // Set the size of the frame if the size is enforced.
  if size is Custom(size) {
    frame.set_size(size)
  }

  // Check that the frame is non-zero.
  if frame.width().is_zero() || frame.height().is_zero() {
    bail_at(span, "tile size must be non-zero", hints=[
      "try setting the size manually",
    ])
  }
  let size = frame.size()
  let spacing = Axes::new(spacing.x.abs, spacing.y.abs)
  let offset = Axes::new(
    offset.x.resolve(styles).relative_to(size.x + spacing.x),
    offset.y.resolve(styles).relative_to(size.y + spacing.y),
  )
  { frame, size, spacing, offset, angle: angle_.v, relative: relative_ }
}

///|
/// Set the relative placement of the tiling.
pub fn Tiling::with_relative(self : Tiling, relative : RelativeTo) -> Tiling {
  { ..self, relative: Custom(relative), }
}

///|
/// Returns the relative placement of the tiling.
pub fn Tiling::relative(self : Tiling) -> Smart[RelativeTo] {
  self.relative
}

///|
/// Returns the relative placement of the tiling, handling the special case
/// of `auto`.
pub fn Tiling::unwrap_relative(self : Tiling, on_text : Bool) -> RelativeTo {
  self.relative.unwrap_or_else(() => if on_text { Parent } else { Self_ })
}

///|
pub fn Tiling::repr(self : Tiling) -> String {
  let out = StringBuilder::new()
  out.write_string("tiling((\{self.size.x.repr()}, \{self.size.y.repr()})")
  if !(self.spacing.x.is_zero() && self.spacing.y.is_zero()) {
    out.write_string(", spacing: (")
    out.write_string(self.spacing.x.repr())
    out.write_string(", ")
    out.write_string(self.spacing.y.repr())
    out.write_char(')')
  }
  if !(self.offset.x.is_zero() && self.offset.y.is_zero()) {
    out.write_string(", offset: (")
    out.write_string(self.offset.x.repr())
    out.write_string(", ")
    out.write_string(self.offset.y.repr())
    out.write_char(')')
  }
  if self.angle != Angle::zero() {
    out.write_string(", angle: ")
    out.write_string(self.angle.repr())
  }
  out.write_string(", ..)")
  out.to_string()
}

///|
pub impl Reflect for Tiling with fn input() {
  Type(Type::tiling())
}

///|
pub impl Reflect for Tiling with fn output() {
  Type(Type::tiling())
}

///|
pub impl Reflect for Tiling with fn castable(v) {
  v is Tiling(_)
}

///|
pub impl IntoValue for Tiling with fn into_value(self) {
  Tiling(self)
}

///|
pub impl FromValue for Tiling with fn from_value(v) {
  match v {
    Tiling(t) => t
    v => raise HintedError(Tiling::input().error(v))
  }
}
