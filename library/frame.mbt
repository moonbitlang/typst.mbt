// Port of `typst-library/src/layout/frame.rs`.
//
// Value semantics: upstream `Frame` is a value whose items live in a
// copy-on-write `Arc`; cloning is cheap and mutating a clone never affects
// the original. Here a `Frame` is a mutable object, so:
//
// - Where upstream clones a frame (`frame.clone()`), call `Frame::clone`.
//   It shares the item array and marks both frames as shared; the first
//   mutation of either copies the array (like `Arc::make_mut`) and clones the
//   group items in it, so that nested frames are copied on write as well.
// - Where upstream moves a frame (passing it by value, e.g. to `push_frame`,
//   `GroupItem::new` or `Fragment::frame`), the moved frame must not be used
//   anymore, just like in Rust.
// - Item arrays returned by `items()` are read-only views.
//
// Methods taking `&mut self` upstream mutate the frame in place; methods
// taking `mut self` and returning `Self` (builders) return the same object.

///|
/// A finished layout with items at fixed positions.
pub struct Frame {
  /// The size of the frame.
  priv mut size : Axes[Abs]
  /// The baseline of the frame measured from the top. If this is `None`, the
  /// frame's implicit baseline is at the bottom.
  priv mut baseline : Abs?
  /// The items composing this layout.
  priv mut items : Array[(Point, FrameItem)]
  /// Whether `items` may be shared with another frame and must be copied
  /// before mutation (upstream: the `Arc`'s strong count is above one).
  priv mut shared : Bool
  /// The hardness of this frame.
  ///
  /// Determines whether it is a boundary for gradient drawing.
  priv mut kind : FrameKind
}

// Constructor, accessors and setters.

///|
/// Create a new, empty frame.
///
/// Panics if the size is not finite.
pub fn Frame::new(size : Axes[Abs], kind : FrameKind) -> Frame {
  guard size.is_finite_size() else { abort("frame size must be finite") }
  { size, baseline: None, items: [], shared: false, kind, }
}

///|
/// Create a new, empty soft frame.
///
/// Panics if the size is not finite.
pub fn Frame::soft(size : Axes[Abs]) -> Frame {
  Frame::new(size, Soft)
}

///|
/// Create a new, empty hard frame.
///
/// Panics if the size is not finite.
pub fn Frame::hard(size : Axes[Abs]) -> Frame {
  Frame::new(size, Hard)
}

///|
/// An empty soft frame of zero size (upstream `Frame::default()`).
pub impl Default for Frame with fn default() {
  Frame::soft(Axes::zero_size())
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Frame with Default::{default}

///|
/// A cheap copy of the frame that shares its items copy-on-write (upstream
/// `Clone`).
pub fn Frame::clone(self : Frame) -> Frame {
  self.shared = true
  {
    size: self.size,
    baseline: self.baseline,
    items: self.items,
    shared: true,
    kind: self.kind,
  }
}

///|
/// Sets the frame's hardness.
pub fn Frame::set_kind(self : Frame, kind : FrameKind) -> Unit {
  self.kind = kind
}

///|
/// Sets the frame's hardness builder-style.
pub fn Frame::with_kind(self : Frame, kind : FrameKind) -> Frame {
  self.kind = kind
  self
}

///|
/// Whether the frame is hard or soft.
pub fn Frame::kind(self : Frame) -> FrameKind {
  self.kind
}

///|
/// Whether the frame contains no items.
pub fn Frame::is_empty(self : Frame) -> Bool {
  self.items.is_empty()
}

///|
/// The size of the frame.
pub fn Frame::size(self : Frame) -> Axes[Abs] {
  self.size
}

///|
/// Set the size of the frame.
pub fn Frame::set_size(self : Frame, size : Axes[Abs]) -> Unit {
  self.size = size
}

///|
/// The width of the frame.
pub fn Frame::width(self : Frame) -> Abs {
  self.size.x
}

///|
/// The height of the frame.
pub fn Frame::height(self : Frame) -> Abs {
  self.size.y
}

///|
/// The vertical position of the frame's baseline.
pub fn Frame::baseline(self : Frame) -> Abs {
  self.baseline.unwrap_or(self.size.y)
}

///|
/// Whether the frame has a non-default baseline.
pub fn Frame::has_baseline(self : Frame) -> Bool {
  self.baseline is Some(_)
}

///|
/// Set the frame's baseline from the top.
pub fn Frame::set_baseline(self : Frame, baseline : Abs) -> Unit {
  self.baseline = Some(baseline)
}

///|
/// Remove the frame's natural baseline. This might be needed after applying
/// a certain transformation that would invalidate the baseline position, in
/// such a way that the ideal new position is not clear.
pub fn Frame::clear_baseline(self : Frame) -> Unit {
  self.baseline = None
}

///|
/// The distance from the baseline to the top of the frame.
///
/// This is the same as `baseline()`, but more in line with the terminology
/// used in math layout.
pub fn Frame::ascent(self : Frame) -> Abs {
  self.baseline()
}

///|
/// The distance from the baseline to the bottom of the frame.
pub fn Frame::descent(self : Frame) -> Abs {
  self.size.y - self.baseline()
}

///|
/// The items inside this frame alongside their positions relative to the
/// top-left of the frame. The view must not be mutated.
pub fn Frame::items(self : Frame) -> ArrayView[(Point, FrameItem)] {
  self.items[:]
}

///|
/// The items for mutation, copied first if they are shared (upstream
/// `Arc::make_mut`).
fn Frame::make_mut(self : Frame) -> Array[(Point, FrameItem)] {
  if self.shared {
    self.items = self.items.map(clone_entry)
    self.shared = false
  }
  self.items
}

///|
/// `(entry.0, entry.1.clone())`, sharing the (immutable) entry itself unless
/// it holds a group, whose frame must not be aliased.
fn clone_entry(entry : (Point, FrameItem)) -> (Point, FrameItem) {
  match entry.1 {
    Group(group) => (entry.0, Group(group.clone()))
    _ => entry
  }
}

// Insert items and subframes.

///|
/// The layer the next item will be added on. This corresponds to the number
/// of items in the frame.
pub fn Frame::layer(self : Frame) -> Int {
  self.items.length()
}

///|
/// Add an item at a position in the foreground.
pub fn Frame::push(self : Frame, pos : Point, item : FrameItem) -> Unit {
  self.make_mut().push((pos, item))
}

///|
/// Add multiple items at a position in the foreground.
///
/// The first item in the iterator will be the one that is most in the
/// background.
pub fn Frame::push_multiple(
  self : Frame,
  items : Iter[(Point, FrameItem)],
) -> Unit {
  let sink = self.make_mut()
  for item in items {
    sink.push(item)
  }
}

///|
/// Add a frame at a position in the foreground.
///
/// Automatically decides whether to inline the frame or to include it as a
/// group based on the number of items in it.
pub fn Frame::push_frame(self : Frame, pos : Point, frame : Frame) -> Unit {
  if self.should_inline(frame) {
    self.inline(self.layer(), pos, frame)
  } else {
    self.push(pos, Group(GroupItem::new(frame)))
  }
}

///|
/// Insert an item at the given layer in the frame.
///
/// This panics if the layer is greater than the number of layers present.
pub fn Frame::insert(
  self : Frame,
  layer : Int,
  pos : Point,
  item : FrameItem,
) -> Unit {
  self.make_mut().insert(layer, (pos, item))
}

///|
/// Add an item at a position in the background.
pub fn Frame::prepend(self : Frame, pos : Point, item : FrameItem) -> Unit {
  self.insert(0, pos, item)
}

///|
/// Add multiple items at a position in the background.
///
/// The first item in the iterator will be the one that is most in the
/// background.
pub fn Frame::prepend_multiple(
  self : Frame,
  items : Iter[(Point, FrameItem)],
) -> Unit {
  let sink = self.make_mut()
  let new = items.collect()
  new.append(sink)
  self.items = new
}

///|
/// Add a frame at a position in the background.
pub fn Frame::prepend_frame(self : Frame, pos : Point, frame : Frame) -> Unit {
  if self.should_inline(frame) {
    self.inline(0, pos, frame)
  } else {
    self.prepend(pos, Group(GroupItem::new(frame)))
  }
}

///|
/// Filters out items in the frame in-place. The filter may mutate the frames
/// of group items (they are not shared with other frames at this point).
pub fn Frame::retain(self : Frame, filter : (FrameItem) -> Bool) -> Unit {
  self.make_mut().retain(entry => filter(entry.1))
}

///|
/// Whether the given frame should be inlined.
fn Frame::should_inline(self : Frame, frame : Frame) -> Bool {
  // We do not inline big frames and hard frames.
  frame.kind().is_soft() && (self.items.is_empty() || frame.items.length() <= 5)
}

///|
/// Inline a frame at the given layer.
fn Frame::inline(self : Frame, layer : Int, pos : Point, frame : Frame) -> Unit {
  // Skip work if there's nothing to do.
  if frame.items.is_empty() {
    return
  }

  // Try to just reuse the items.
  if pos.is_zero() && self.items.is_empty() {
    self.items = frame.items
    // The moved frame may still be referenced by the caller.
    self.shared = true
    frame.shared = true
    return
  }

  // Transfer the items, adjusting their positions unless the position is
  // zero (upstream then transfers them unchanged, which matters for signed
  // zeros). Group items are cloned so that the moved frame's items are not
  // aliased.
  let sink = self.make_mut()
  if layer == sink.length() && !physical_equal(sink, frame.items) {
    // Inserting at the top layer (`push_frame`): append in place instead of
    // rebuilding the whole item list (performance).
    if pos.is_zero() {
      for entry in frame.items {
        sink.push(clone_entry(entry))
      }
    } else {
      for entry in frame.items {
        sink.push((entry.0 + pos, entry.1.clone()))
      }
    }
    return
  }
  let moved = if pos.is_zero() {
    frame.items.map(clone_entry)
  } else {
    frame.items.map(entry => (entry.0 + pos, entry.1.clone()))
  }
  let items = sink[:layer].to_owned()
  items.append(moved)
  items.append(sink[layer:])
  self.items = items
}

// Modify the frame.

///|
/// Remove all items from the frame.
pub fn Frame::clear(self : Frame) -> Unit {
  self.items = []
  self.shared = false
}

///|
/// Adjust the frame's size, translate the original content by an offset
/// computed according to the given alignments, and return the amount of
/// offset.
pub fn Frame::resize(
  self : Frame,
  target : Axes[Abs],
  align : Axes[FixedAlignment],
) -> Point {
  if self.size == target {
    return Point::zero()
  }
  let offset = align
    .zip_map(target.sub_size(self.size), FixedAlignment::position)
    .to_point()
  self.size = target
  self.translate(offset)
  offset
}

///|
/// Move the baseline and contents of the frame by an offset.
pub fn Frame::translate(self : Frame, offset : Point) -> Unit {
  if !offset.is_zero() {
    if self.baseline is Some(baseline) {
      self.baseline = Some(baseline + offset.y)
    }
    let items = self.make_mut()
    for i, entry in items {
      items[i] = (entry.0 + offset, entry.1)
    }
  }
}

///|
/// Move the contents of the frame without changing the baseline.
pub fn Frame::translate_visual(self : Frame, offset : Point) -> Unit {
  if !offset.is_zero() {
    let items = self.make_mut()
    for i, entry in items {
      items[i] = (entry.0 + offset, entry.1)
    }
  }
}

///|
/// Hide all content in the frame, but keep metadata.
pub fn Frame::hide(self : Frame) -> Unit {
  self.retain(item => {
    match item {
      Group(group) => {
        group.frame.hide()
        !group.frame.is_empty()
      }
      Tag(_) => true
      _ => false
    }
  })
}

///|
/// Add a background fill.
pub fn Frame::fill(self : Frame, fill : Paint) -> Unit {
  self.prepend(
    Point::zero(),
    Shape(Geometry::Rect(self.size()).filled(fill), @syntax.Span::detached()),
  )
}

///|
/// Arbitrarily transform the contents of the frame.
pub fn Frame::transform(self : Frame, transform : Transform) -> Unit {
  if !self.is_empty() {
    self.group(g => g.transform = transform)
  }
}

///|
/// Clip the contents of a frame to a clip curve.
///
/// The clip curve can be the size of the frame in the case of a rectangular
/// frame. In the case of a frame with rounded corner, this should be a curve
/// that matches the frame's outline.
pub fn Frame::clip(self : Frame, clip_curve : Curve) -> Unit {
  if !self.is_empty() {
    self.group(g => g.clip = Some(clip_curve))
  }
}

///|
/// Add a label to the frame.
pub fn Frame::label(self : Frame, label : Label) -> Unit {
  self.group(g => g.label = Some(label))
}

///|
/// Set a parent for the frame. As a result, all elements in the frame become
/// logically ordered immediately after the given location.
pub fn Frame::set_parent(self : Frame, parent : FrameParent) -> Unit {
  if !self.is_empty() {
    self.group(g => g.parent = Some(parent))
  }
}

///|
/// Wrap the frame's contents in a group and modify that group with `f`.
fn Frame::group(self : Frame, f : (GroupItem) -> Unit) -> Unit {
  let wrapper = Frame::soft(self.size)
  wrapper.baseline = self.baseline
  // `std::mem::take(self)`: move the contents into a new frame object.
  let inner : Frame = {
    size: self.size,
    baseline: self.baseline,
    items: self.items,
    shared: self.shared,
    kind: self.kind,
  }
  let group = GroupItem::new(inner)
  f(group)
  wrapper.push(Point::zero(), Group(group))
  // `*self = wrapper`
  self.size = wrapper.size
  self.baseline = wrapper.baseline
  self.items = wrapper.items
  self.shared = false
  self.kind = wrapper.kind
}

// Tools for debugging.

///|
/// Add a full size aqua background and a red baseline for debugging.
pub fn Frame::mark_box(self : Frame) -> Frame {
  self.mark_box_in_place()
  self
}

///|
/// Debug in place. Add a full size aqua background and a red baseline for
/// debugging.
pub fn Frame::mark_box_in_place(self : Frame) -> Unit {
  self.insert(
    0,
    Point::zero(),
    Shape(
      Geometry::Rect(self.size).filled(Solid(color_teal.with_alpha(0.5))),
      @syntax.Span::detached(),
    ),
  )
  self.insert(
    1,
    Point::with_y(self.baseline()),
    Shape(
      Geometry::Line(Point::with_x(self.size.x)).stroked(
        FixedStroke::from_pair(Solid(color_red), Abs::pt(1.0)),
      ),
      @syntax.Span::detached(),
    ),
  )
}

///|
/// Add a green marker at a position for debugging.
pub fn Frame::mark_point(self : Frame, pos : Point) -> Unit {
  let radius = Abs::pt(2.0)
  self.push(
    pos - Point::splat(radius),
    Shape(
      Geometry::Curve(Curve::ellipse(Axes::splat(radius.times(2.0)))).filled(
        Solid(color_green),
      ),
      @syntax.Span::detached(),
    ),
  )
}

///|
/// Add a green marker line at a position for debugging.
pub fn Frame::mark_line(self : Frame, y : Abs) -> Unit {
  self.push(
    Point::with_y(y),
    Shape(
      Geometry::Line(Point::with_x(self.size.x)).stroked(
        FixedStroke::from_pair(Solid(color_green), Abs::pt(1.0)),
      ),
      @syntax.Span::detached(),
    ),
  )
}

///|
/// Structural equality (upstream derives `PartialEq` through `Hash`-based
/// `LazyHash` comparison of the items).
pub impl Eq for Frame with fn equal(self, other) {
  self.size == other.size &&
  self.baseline == other.baseline &&
  self.kind == other.kind &&
  (physical_equal(self.items, other.items) || self.items == other.items)
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Frame with Eq::{not_equal, equal}

///|
/// The hardness of a frame.
///
/// This corresponds to whether or not the frame is considered to be the
/// innermost parent of its contents. This is used to determine the
/// coordinate reference system for gradients.
pub(all) enum FrameKind {
  /// A container which follows its parent's size.
  ///
  /// Soft frames are the default since they do not impact the layout of a
  /// gradient set on one of its children.
  Soft
  /// A container which uses its own size.
  ///
  /// This is used for pages, blocks, and boxes.
  Hard
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameKind with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameKind with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameKind with @debug.Debug::{to_repr}

///|
pub impl Default for FrameKind with fn default() {
  Soft
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameKind with Default::{default}

///|
/// Returns `true` if the frame is soft.
pub fn FrameKind::is_soft(self : FrameKind) -> Bool {
  self is Soft
}

///|
/// Returns `true` if the frame is hard.
pub fn FrameKind::is_hard(self : FrameKind) -> Bool {
  self is Hard
}

///|
/// The building block frames are composed of.
pub(all) enum FrameItem {
  /// A subframe with optional transformation and clipping.
  Group(GroupItem)
  /// A run of shaped text.
  Text(TextItem)
  /// A geometric shape with optional fill and stroke.
  Shape(Shape, @syntax.Span)
  /// An image and its size.
  Image(Image, Axes[Abs], @syntax.Span)
  /// An internal or external link to a destination.
  Link(Destination, Axes[Abs])
  /// An introspectable element that produced something within this frame.
  Tag(Tag)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameItem with Eq::{not_equal, equal}

///|
/// A copy of the item whose group frame (if any) is a copy-on-write clone
/// (upstream `Clone`).
pub fn FrameItem::clone(self : FrameItem) -> FrameItem {
  match self {
    Group(group) => Group(group.clone())
    item => item
  }
}

///|
/// A subframe with optional transformation and clipping.
pub(all) struct GroupItem {
  /// The group's frame.
  mut frame : Frame
  /// A transformation to apply to the group.
  mut transform : Transform
  /// A curve which should be used to clip the group.
  mut clip : Curve?
  /// The group's label.
  mut label : Label?
  /// The group's logical parent. All elements in this group are logically
  /// ordered immediately after the parent's start location. This can be
  /// thought of as inserting the elements at the end but still inside of
  /// the parent.
  mut parent : FrameParent?
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GroupItem with Eq::{not_equal, equal}

///|
/// Create a new group with default settings.
pub fn GroupItem::new(frame : Frame) -> GroupItem {
  {
    frame,
    transform: Transform::identity(),
    clip: None,
    label: None,
    parent: None,
  }
}

///|
/// A copy of the group whose frame is a copy-on-write clone (upstream
/// `Clone`).
pub fn GroupItem::clone(self : GroupItem) -> GroupItem {
  { ..self, frame: self.frame.clone(), }
}

///|
/// The parent of a [GroupItem]. The child will be logically ordered at the
/// end but still inside of the parent.
pub(all) struct FrameParent {
  /// The location of the parent element.
  location : Location
  /// Whether the child has inherited the parent's styles.
  inherit_ : Inherit
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameParent with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameParent with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameParent with @debug.Debug::{to_repr}

///|
/// Create a new frame parent.
pub fn FrameParent::new(location : Location, inherit_ : Inherit) -> FrameParent {
  { location, inherit_, }
}

///|
/// Whether the child has inherited the parent's styles.
///
/// # Inherited
///
/// The placed text will inherit the styles from its parent (the place
/// element). So `explanation` will be underlined.
///
/// ```typ
/// #underline[
///   Some text #place(float: true, bottom + right)[explanation].
/// ]
/// ```
///
/// # Not Inherited
///
/// The footnote entry won't inherit the styles from it's parent (the
/// footnote). So `explanation` won't be underlined, unless other styles
/// apply.
///
/// ```typ
/// #underline[
///   Some text #footnote[explanation].
/// ]
/// ```
pub(all) enum Inherit {
  Yes
  No
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Inherit with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Inherit with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Inherit with @debug.Debug::{to_repr}
