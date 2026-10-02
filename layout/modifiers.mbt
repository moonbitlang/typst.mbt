// Port of `typst-layout/src/modifiers.rs`.

///|
/// Frame-level modifications resulting from styles that do not impose any
/// layout structure.
///
/// These are always applied at the highest level of style uniformity.
/// Consequently, they must be applied by all layouters that manually manage
/// styles of their children (because they can produce children with varying
/// styles). This currently includes flow, inline, and math layout.
///
/// Other layouters don't manually need to handle it because their parents
/// that result from realization will take care of it and the styles can only
/// apply to them as a whole, not part of it (since they don't manage styles).
///
/// Currently existing frame modifiers are:
/// - `HideElem::hidden`
/// - `LinkElem::dests`
pub struct FrameModifiers {
  /// A destination to link to.
  priv dest : @library.Destination?
  /// Whether the contents of the frame should be hidden.
  priv hidden : Bool
}

///|
/// Retrieve all modifications that should be applied per-frame.
pub fn FrameModifiers::get_in(styles : @library.StyleChain) -> FrameModifiers {
  {
    dest: @library.LinkElem::current_in(styles),
    hidden: @library.HideElem::hidden_in(styles),
  }
}

///|
/// Applies [FrameModifiers].
pub(open) trait FrameModify {
  /// Apply the modifiers in-place.
  fn modify(Self, FrameModifiers) -> Unit
}

///|
pub impl FrameModify for @library.Frame with fn modify(self, modifiers) {
  modify_frame(self, modifiers, None)
}

///|
pub impl FrameModify for @library.Fragment with fn modify(self, modifiers) {
  for frame in self.iter() {
    FrameModify::modify(frame, modifiers)
  }
}

///|
/// Apply the modifiers, and return the modified result.
pub fn[T : FrameModify] modified(value : T, modifiers : FrameModifiers) -> T {
  value.modify(modifiers)
  value
}

///|
/// Resolve and apply [FrameModifiers] for this text frame (upstream
/// `FrameModifyText::modify_text`).
pub fn modify_text(
  frame : @library.Frame,
  styles : @library.StyleChain,
) -> Unit {
  let modifiers = FrameModifiers::get_in(styles)
  let expand_y = @library.ParElem::leading_in(styles).resolve(styles).times(0.5)
  let outset = @library.Sides::new(
    @library.Abs::zero(),
    expand_y,
    @library.Abs::zero(),
    expand_y,
  )
  modify_frame(frame, modifiers, Some(outset))
}

///|
fn modify_frame(
  frame : @library.Frame,
  modifiers : FrameModifiers,
  link_box_outset : @library.Sides[@library.Abs]?,
) -> Unit {
  if modifiers.dest is Some(dest) {
    let mut pos = @library.Point::zero()
    let mut size = frame.size()
    if link_box_outset is Some(outset) {
      pos = @library.Point::new(pos.x - outset.left, pos.y - outset.top)
      size = size.add_size(outset.sum_by_axis())
    }
    frame.push(pos, Link(dest, size))
  }
  if modifiers.hidden {
    frame.hide()
  }
}

///|
/// Performs layout and modification in one step.
///
/// This just runs `layout(styles).modified(&FrameModifiers::get_in(styles))`,
/// but with the additional step that redundant modifiers (which are already
/// applied here) are removed from the `styles` passed to `layout`. This is
/// used for the layout of containers like `block`.
pub fn[R : FrameModify] layout_and_modify(
  styles : @library.StyleChain,
  layout : (@library.StyleChain) -> R raise @library.SourceError,
) -> R raise @library.SourceError {
  let modifiers = FrameModifiers::get_in(styles)

  // Disable the current link internally since it's already applied at this
  // level of layout. This means we don't generate redundant nested links,
  // which may bloat the output considerably.
  let outer = styles
  let mut styles = styles
  if modifiers.dest is Some(_) {
    let reset = @library.Styles::from_array([
      @library.LinkElem::set_current(None),
    ])
    styles = outer.chain(reset)
  }
  modified(layout(styles), modifiers)
}
