// Port of `typst-library/src/layout/size.rs`.
//
// Upstream `Size` is a type alias for `Axes<Abs>`. Here it is a type of
// its own, a `#valtype` struct of two `Abs` (not upstream). A generic
// struct cannot be a value type, so every `Axes[Abs]` was an object on the
// heap, and sizes are what layout computes with most: 839 000 of the 38.6
// million objects of a compilation and export of `bench/longer.typ`. An
// `Abs` is a `Double` at run time, so a `Size` is two doubles that are
// passed and returned in registers and stored inline in a frame, a region
// or a frame item, like a `Point`.
//
// The seam with the generic `Axes[T]`:
//
// - Where upstream says `Size`, the port says `Size`, and also in the three
//   places where upstream spells the same type `Axes<Abs>`
//   (`typst-render` `pre_scale`, `typst-svg` `render_image`, the `line`
//   tuples of `typst-layout`'s `math/mod.rs`). `Axes[Abs]` is still a
//   type, the one that a generic function gives for `T = Abs`
//   (`axes.map(v => Abs::inches(..))`); nothing takes one.
// - What upstream calls on a size through `impl<T> Axes<T>` is a method of
//   `Size` with the same name and `T = Abs`: `new`, `splat`, `with_x`,
//   `with_y`, `min`, `max`, `min_by_side`, `max_by_side`, `get`,
//   `with_axis_value` (the port's name for `set`), `any`, `all`, and `map`
//   and `zip_map` where they give a size again. They do what the generic
//   ones do (`min`/`max` are `Ord`'s, as there, not `Abs::min`).
//   `map_axes` is `map` to another component type
//   (`size.map_axes(Abs::is_finite)`); `zip_map` takes an `Axes[V]`, and
//   `zip_map_size` another size.
// - What `size.rs` adds has upstream's names, which the alias could not
//   have next to the generic methods: `Size::zero()`, `is_zero()`,
//   `is_finite()`, `+`, `-`, unary `-` (they were `Axes::zero_size`,
//   `is_zero_size`, `is_finite_size`, `add_size`, `sub_size`, `neg_size`),
//   and `impl Numeric for Size`.
// - Three generic functions that upstream instantiates with `Abs` have a
//   twin that takes and returns sizes (`layout_support.mbt`):
//   `Axes[Bool]::select_size` (`select`), `Axes[T]::zip_map_size`
//   (`zip_map` with a size, to a size) and `Sides[Abs]::sum_by_axis_size`
//   (`sum_by_axis`). `Axes[Rel[Abs]]::relative_to` and
//   `Sides[Rel[Abs]]::relative_to` were not generic and take a `Size`.
// - `to_axes` and `Size::from_axes` convert. `to_axes` makes an object;
//   the port does not call it. `from_axes` is called where a tiling is
//   constructed (its `size` argument is an `Axes[Length]` that is mapped)
//   and by the cast.
//
// What a value type does not have, and what it costs elsewhere:
//
// - No identity: `physical_equal` on value types is always false on
//   native. Nothing compared sizes that way.
// - It is boxed in an option: the option of an object was the object, and
//   `Some(size)` is an object now. That is what an `Iter[Size]` yields
//   (`Regions::iter`: one object more than before per iterator, for the
//   first region, 12 700 in `longer.typ`) and what `pdf`'s
//   `FrameContext::page_size` returns (which is asked for artifacts only,
//   see `pdf/tags_tree.mbt`). In an array, a tuple, a struct or the
//   payload of an enum it is inline.
//
// `Eq`, `Hash` and `Default` are derived and are what the derived impls of
// `Axes[Abs]` were (the components in order). There is no `Fingerprint`
// impl, as there was none for `Axes[T]`: sizes are written into
// memoization keys and frame hashes component by component (the keys of
// `layout_fragment` and `layout_par`, `write_size`, `svg`'s `hash_size`).

///|
/// A size in 2D.
#valtype
pub(all) struct Size {
  /// The horizontal component.
  x : Abs
  /// The vertical component.
  y : Abs
} derive(Eq, Hash, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with Hash::{hash, hash_combine}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with Default::{default}

///|
/// The zero value.
pub fn Size::zero() -> Size {
  { x: Abs::zero(), y: Abs::zero(), }
}

///|
/// Create a new instance from the two components (upstream `Axes::new`).
pub fn Size::new(x : Abs, y : Abs) -> Size {
  { x, y, }
}

///|
/// Create a new instance with two equal components (upstream
/// `Axes::splat`).
pub fn Size::splat(v : Abs) -> Size {
  { x: v, y: v, }
}

///|
/// Create a new instance with y set to its default value (upstream
/// `Axes::with_x`).
pub fn Size::with_x(x : Abs) -> Size {
  { x, y: Abs::zero(), }
}

///|
/// Create a new instance with x set to its default value (upstream
/// `Axes::with_y`).
pub fn Size::with_y(y : Abs) -> Size {
  { x: Abs::zero(), y, }
}

///|
/// The generic container of the two components. This allocates: use it
/// where an `Axes[T]` is needed for a `T` that is not known to be `Abs`.
pub fn Size::to_axes(self : Size) -> Axes[Abs] {
  { x: self.x, y: self.y, }
}

///|
/// The size of a generic container of two lengths.
pub fn Size::from_axes(axes : Axes[Abs]) -> Size {
  { x: axes.x, y: axes.y, }
}

///|
/// Map the individual fields with `f` (upstream `Axes::map`, where the
/// result is a size again).
pub fn Size::map(self : Size, f : (Abs) -> Abs) -> Size {
  { x: f(self.x), y: f(self.y), }
}

///|
/// Map the individual fields with `f` (upstream `Axes::map`, where the
/// result is not a size: `size.map(Abs::is_finite)`).
pub fn[U] Size::map_axes(self : Size, f : (Abs) -> U) -> Axes[U] {
  { x: f(self.x), y: f(self.y), }
}

///|
/// Apply a function to this and another-instance componentwise (upstream
/// `Axes::zip_map`, where the result is a size again).
pub fn[V] Size::zip_map(
  self : Size,
  other : Axes[V],
  f : (Abs, V) -> Abs,
) -> Size {
  { x: f(self.x, other.x), y: f(self.y, other.y), }
}

///|
/// `zip_map` of two sizes (upstream `Axes::zip_map`; the name of the twin
/// of `Axes[T]`, `zip_map_size`).
pub fn Size::zip_map_size(
  self : Size,
  other : Size,
  f : (Abs, Abs) -> Abs,
) -> Size {
  { x: f(self.x, other.x), y: f(self.y, other.y), }
}

///|
/// Whether a condition is true for at least one of fields.
pub fn Size::any(self : Size, f : (Abs) -> Bool) -> Bool {
  f(self.x) || f(self.y)
}

///|
/// Whether a condition is true for both fields.
pub fn Size::all(self : Size, f : (Abs) -> Bool) -> Bool {
  f(self.x) && f(self.y)
}

///|
/// The component-wise minimum of this and another instance.
pub fn Size::min(self : Size, other : Size) -> Size {
  { x: ord_min(self.x, other.x), y: ord_min(self.y, other.y), }
}

///|
/// The component-wise maximum of this and another instance.
pub fn Size::max(self : Size, other : Size) -> Size {
  { x: ord_max(self.x, other.x), y: ord_max(self.y, other.y), }
}

///|
/// The minimum of width and height.
pub fn Size::min_by_side(self : Size) -> Abs {
  ord_min(self.x, self.y)
}

///|
/// The maximum of width and height.
pub fn Size::max_by_side(self : Size) -> Abs {
  ord_max(self.x, self.y)
}

///|
/// The component for the given axis (upstream `Get<Axis>`).
pub fn Size::get(self : Size, axis : Axis) -> Abs {
  match axis {
    X => self.x
    Y => self.y
  }
}

///|
/// Returns the size with the component for the specified axis replaced by
/// `v` (upstream `Axes::set`, which mutates in place).
pub fn Size::with_axis_value(self : Size, axis : Axis, v : Abs) -> Size {
  match axis {
    X => { x: v, y: self.y, }
    Y => { x: self.x, y: v, }
  }
}

///|
/// Whether the other size fits into this one (smaller width and height).
pub fn Size::fits(self : Size, other : Size) -> Bool {
  self.x.fits(other.x) && self.y.fits(other.y)
}

///|
/// Convert to a point.
pub fn Size::to_point(self : Size) -> Point {
  Point::new(self.x, self.y)
}

///|
/// Converts to a ratio of width to height.
pub fn Size::aspect_ratio(self : Size) -> Ratio {
  Ratio::new(self.x.ratio_to(self.y))
}

///|
/// Whether both components are zero (upstream `Numeric::is_zero`).
pub fn Size::is_zero(self : Size) -> Bool {
  self.x == Abs::zero() && self.y == Abs::zero()
}

///|
/// Whether both components are finite (upstream `Numeric::is_finite`).
pub fn Size::is_finite(self : Size) -> Bool {
  self.x.is_finite() && self.y.is_finite()
}

///|
/// Multiply both components by a factor (upstream `Size * f64`).
pub fn Size::times(self : Size, factor : Double) -> Size {
  { x: self.x.times(factor), y: self.y.times(factor), }
}

///|
/// Divide both components by a factor (upstream `Size / f64`).
pub fn Size::div_by(self : Size, factor : Double) -> Size {
  { x: self.x.div_by(factor), y: self.y.div_by(factor), }
}

///|
/// Component-wise addition (upstream `Size + Size`).
pub impl Add for Size with fn add(self, other) {
  { x: self.x + other.x, y: self.y + other.y, }
}

///|
#deprecated("call as `Add::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with Add::{add}

///|
/// Component-wise subtraction (upstream `Size - Size`).
pub impl Sub for Size with fn sub(self, other) {
  { x: self.x - other.x, y: self.y - other.y, }
}

///|
#deprecated("call as `Sub::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with Sub::{sub}

///|
/// Component-wise negation (upstream `-Size`).
pub impl Neg for Size with fn neg(self) {
  { x: -self.x, y: -self.y, }
}

///|
#deprecated("call as `Neg::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with Neg::{neg}

///|
pub impl Numeric for Size with fn zero() {
  Size::zero()
}

///|
pub impl Numeric for Size with fn is_finite(self) {
  self.x.is_finite() && self.y.is_finite()
}

///|
pub impl Numeric for Size with fn scale(self, factor) {
  self.times(factor)
}

///|
pub impl Numeric for Size with fn div_scale(self, factor) {
  self.div_by(factor)
}

///|
// `zero` is not named here: the type already has a method of this name.
// `is_finite` is not named here: the type already has a method of this name.
#deprecated("call as `Numeric::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with Numeric::{scale, div_scale}

// The casts of `Axes<Abs>` (upstream `axes.rs`: an array of two lengths).

///|
pub impl Reflect for Size with fn input() {
  Type(Type::array())
}

///|
pub impl Reflect for Size with fn output() {
  Type(Type::array())
}

///|
pub impl Reflect for Size with fn castable(value) {
  value is Array(_)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with Reflect::{output, input, castable}

///|
pub impl FromValue for Size with fn from_value(value) {
  let axes : Axes[Abs] = value.cast()
  Size::from_axes(axes)
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with FromValue::{from_value}

///|
pub impl IntoValue for Size with fn into_value(self) {
  Array(
    Arr::from_array([
      IntoValue::into_value(self.x),
      IntoValue::into_value(self.y),
    ]),
  )
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Size with IntoValue::{into_value}
