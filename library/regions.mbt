// Port of `typst-library/src/layout/regions.rs`.
//
// Upstream `Region` and `Regions` are `Copy` values that are frequently
// copied and mutated locally. Here they are immutable; the mutating methods
// (`next`) return the updated value instead (`regions = regions.next()`), and
// field updates use struct update syntax (`{ ..regions, size }`).

///|
/// A single region to layout into (upstream `layout::Region`; renamed
/// because `Region` is the text region of `text/lang.rs`).
pub(all) struct LayoutRegion {
  /// The size of the region.
  size : Axes[Abs]
  /// Whether elements should expand to fill the regions instead of shrinking
  /// to fit the content.
  expand : Axes[Bool]
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LayoutRegion with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LayoutRegion with Hash::{hash, hash_combine}

///|
/// Create a new region.
pub fn LayoutRegion::new(size : Axes[Abs], expand : Axes[Bool]) -> LayoutRegion {
  { size, expand, }
}

///|
/// A sequence of regions to layout into.
///
/// A *region* is a contiguous rectangular space in which elements can be
/// laid out. All regions within a `Regions` object have the same width,
/// namely `self.size.x`. This means that it is not currently possible to, for
/// instance, have content wrap to the side of a floating element.
pub(all) struct Regions {
  /// The remaining size of the first region.
  size : Axes[Abs]
  /// Whether elements should expand to fill the regions instead of shrinking
  /// to fit the content.
  expand : Axes[Bool]
  /// The full height of the region for relative sizing.
  full : Abs
  /// The height of followup regions. The width is the same for all regions.
  backlog : ArrayView[Abs]
  /// The height of the final region that is repeated once the backlog is
  /// drained. The width is the same for all regions.
  last : Abs?
}

///|
/// Upstream `From<Region> for Regions`.
pub fn Regions::from_region(region : LayoutRegion) -> Regions {
  {
    size: region.size,
    expand: region.expand,
    full: region.size.y,
    backlog: [][:],
    last: None,
  }
}

///|
/// Create a new sequence of same-size regions that repeats indefinitely.
pub fn Regions::repeat(size : Axes[Abs], expand : Axes[Bool]) -> Regions {
  { size, full: size.y, backlog: [][:], last: Some(size.y), expand, }
}

///|
/// The base size, which doesn't take into account that the regions is
/// already partially used up.
///
/// This is also used for relative sizing.
pub fn Regions::base(self : Regions) -> Axes[Abs] {
  Axes::new(self.size.x, self.full)
}

///|
/// Create new regions where all sizes are mapped with `f`.
///
/// Note that since all regions must have the same width, the width returned
/// by `f` is ignored for the backlog and the final region. (Upstream fills
/// a caller-provided backlog buffer; here a new array is allocated.)
pub fn Regions::map(self : Regions, f : (Axes[Abs]) -> Axes[Abs]) -> Regions {
  let x = self.size.x
  let backlog = self.backlog.iter().map(y => f(Axes::new(x, y)).y).collect()
  {
    size: f(self.size),
    full: f(Axes::new(x, self.full)).y,
    backlog: backlog[:],
    last: self.last.map(y => f(Axes::new(x, y)).y),
    expand: self.expand,
  }
}

///|
/// Whether the first region is full and a region break is called for.
pub fn Regions::is_full(self : Regions) -> Bool {
  Abs::zero().fits(self.size.y) && self.may_progress()
}

///|
/// Whether a region break is permitted.
pub fn Regions::may_break(self : Regions) -> Bool {
  !self.backlog.is_empty() || self.last is Some(_)
}

///|
/// Whether calling `next()` may improve a situation where there is a lack of
/// space.
pub fn Regions::may_progress(self : Regions) -> Bool {
  !self.backlog.is_empty() ||
  (self.last is Some(height) && self.size.y != height)
}

///|
/// Advance to the next region if there is any (upstream `next(&mut self)`;
/// returns the advanced regions).
pub fn Regions::next(self : Regions) -> Regions {
  if self.backlog is [first, .. tail] {
    { ..self, backlog: tail, size: { ..self.size, y: first, }, full: first, }
  } else if self.last is Some(height) {
    { ..self, size: { ..self.size, y: height, }, full: height, }
  } else {
    self
  }
}

///|
/// An iterator that returns the sizes of the first and all following
/// regions, equivalently to what would be produced by calling
/// [`next()`](Self::next) repeatedly until all regions are exhausted. This
/// iterator may be infinite.
pub fn Regions::iter(self : Regions) -> Iter[Axes[Abs]] {
  let mut first = true
  let mut i = 0
  Iter::new(() => {
    if first {
      first = false
      return Some(self.size)
    }
    if i < self.backlog.length() {
      let h = self.backlog[i]
      i += 1
      return Some(Axes::new(self.size.x, h))
    }
    self.last.map(h => Axes::new(self.size.x, h))
  })
}

///|
/// Upstream `Debug for Regions`.
pub impl Show for Regions with fn output(self, logger) {
  let size = (s : Axes[Abs]) => {
    "Axes(\{rust_debug_f64(s.x.to_pt())}pt, \{rust_debug_f64(s.y.to_pt())}pt)"
  }
  let entries = [size(self.size)]
  let mut prev = self.size.y
  for height in self.backlog {
    entries.push(size(Axes::new(self.size.x, height)))
    prev = height
  }
  if self.last is Some(last) {
    if last != prev {
      entries.push(size(Axes::new(self.size.x, last)))
    }
    entries.push("..")
  }
  logger.write_string("Regions [\{entries.join(", ")}]")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Regions with Show::{to_string, output}
