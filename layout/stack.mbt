// Port of `typst-layout/src/stack.rs`.

///|
/// Layout the stack.
pub fn layout_stack(
  elem : @library.StackElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  layout_stack_internal(
    elem.children().map(c => StackLayoutChild::StackChild(c)),
    elem.pack().span(),
    elem.spacing(styles),
    elem.dir(styles),
    engine,
    locator,
    styles,
    regions,
  )
}

///|
/// Similar to a [StackChild], but with an additional variant that allows
/// specifying a custom layouter for a child. Useful when using stack layout
/// to create other layouters, such as that of lists.
pub enum StackLayoutChild {
  /// A stack child with content or spacing.
  StackChild(@library.StackChild)
  /// A child with a custom layouter, producing its own frames.
  CustomLayouter(
    (@library.Engine, @library.StyleChain, @library.Regions) -> @library.Fragment raise @library.SourceError
  )
}

///|
/// Layout multiple cells like a stack. Requires only the spacing to insert
/// between blocks, the stack growth direction, its children, as well as
/// relevant layout information.
///
/// In particular, this doesn't require creating a stack element explicitly,
/// as it requires `Content`, which has restrictions as to which values it can
/// hold. In particular, elements, even if internal, cannot contain
/// borrows/lifetime generics, even though they can have custom layout
/// procedures. Therefore, calling this function allows customizing stack
/// layout more deeply, such as for lists, which need a custom layout function
/// that might borrow data from the environment for each list item (a stack
/// child). Each child receives relevant layout data from the stack as well.
pub fn layout_stack_internal(
  children : Array[StackLayoutChild],
  span : @syntax.Span,
  spacing : @library.Spacing?,
  dir : @library.Dir,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let layouter = StackLayouter::new(span, dir, locator, styles, regions)
  let axis = layouter.dir.axis()
  let mut deferred = None
  for child in children {
    match child {
      StackChild(Spacing(kind)) => {
        layouter.layout_spacing(kind)
        deferred = None
      }
      StackChild(Block(block)) => {
        // Transparently handle `h`.
        if axis == X && @library.HElem::of(block) is Some(h) {
          layouter.layout_spacing(h.amount())
          deferred = None
          continue
        }

        // Transparently handle `v`.
        if axis == Y && @library.VElem::of(block) is Some(v) {
          layouter.layout_spacing(v.amount())
          deferred = None
          continue
        }
        if deferred is Some(kind) {
          layouter.layout_spacing(kind)
        }
        layouter.layout_block(engine, block, styles)
        deferred = spacing
      }
      CustomLayouter(custom_layouter) => {
        if deferred is Some(kind) {
          layouter.layout_spacing(kind)
        }
        layouter.layout_custom_layouter(engine, custom_layouter, styles)
        deferred = spacing
      }
    }
  }
  layouter.finish()
}

///|
/// Performs stack layout.
priv struct StackLayouter {
  /// The span to raise errors at during layout.
  span : @syntax.Span
  /// The stacking direction.
  dir : @library.Dir
  /// The axis of the stacking direction.
  axis : @library.Axis
  /// Provides unique locations to the stack's children.
  locator : @library.SplitLocator
  /// The inherited styles.
  styles : @library.StyleChain
  /// The regions to layout children into.
  mut regions : @library.Regions
  /// Whether the stack itself should expand to fill the region.
  expand : @library.Axes[Bool]
  /// The initial size of the current region before we started subtracting.
  mut initial : @library.Axes[@library.Abs]
  /// The generic size used by the frames for the current region.
  mut used : GenericSize
  /// The sum of fractions in the current region.
  mut fr : @library.Fr
  /// Already layouted items whose exact positions are not yet known due to
  /// fractional spacing.
  items : Array[StackItem]
  /// Finished frames for previous regions.
  finished : Array[@library.Frame]
}

///|
/// A prepared item in a stack layout.
priv enum StackItem {
  /// Absolute spacing between other items.
  Absolute(@library.Abs)
  /// Fractional spacing between other items.
  Fractional(@library.Fr)
  /// A frame for a layouted block.
  Frame(@library.Frame, @library.Axes[@library.FixedAlignment])
}

///|
/// Create a new stack layouter.
fn StackLayouter::new(
  span : @syntax.Span,
  dir : @library.Dir,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> StackLayouter {
  let axis = dir.axis()
  let expand = regions.expand

  // Disable expansion along the block axis for children.
  let regions = {
    ..regions,
    expand: regions.expand.with_axis_value(axis, false),
  }
  {
    span,
    dir,
    axis,
    locator: locator.split(),
    styles,
    regions,
    expand,
    initial: regions.size,
    used: GenericSize::zero(),
    fr: @library.Fr::zero(),
    items: [],
    finished: [],
  }
}

///|
/// Add spacing along the spacing direction.
fn StackLayouter::layout_spacing(
  self : StackLayouter,
  spacing : @library.Spacing,
) -> Unit {
  match spacing {
    Rel(v) => {
      // Resolve the spacing and limit it to the remaining space.
      let resolved = v
        .resolve(self.styles)
        .relative_to(self.regions.base().get(self.axis))
      let remaining = self.regions.size.get(self.axis)
      let limited = resolved.min(remaining)
      if self.dir.axis() == Y {
        self.regions = {
          ..self.regions,
          size: self.regions.size.with_axis_value(
            self.axis,
            remaining - limited,
          ),
        }
      }
      self.used = { ..self.used, main: self.used.main + limited, }
      self.items.push(Absolute(resolved))
    }
    Fr(v) => {
      self.fr = self.fr + v
      self.items.push(Fractional(v))
    }
  }
}

///|
/// Layout an arbitrary block.
fn StackLayouter::layout_block(
  self : StackLayouter,
  engine : @library.Engine,
  block : @library.Content,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  if self.regions.is_full() {
    self.finish_region()
  }

  // Block-axis alignment of the `AlignElem` is respected by stacks.
  let align = (if @library.AlignElem::of(block) is Some(align) {
    align.alignment(styles)
  } else if block.is_(@library.styled_elem()) {
    @library.AlignElem::alignment_in(
      styles.chain(@library.StyledElem::styles(block)),
    )
  } else {
    @library.AlignElem::alignment_in(styles)
  }).resolve(styles)
  let fragment = layout_fragment(
    engine,
    block,
    self.locator.next(block.span()),
    styles,
    self.regions,
  )
  self.layout_fragment(align, fragment)
}

///|
/// Layout a child with a custom layouter procedure.
fn StackLayouter::layout_custom_layouter(
  self : StackLayouter,
  engine : @library.Engine,
  layouter : (@library.Engine, @library.StyleChain, @library.Regions) -> @library.Fragment raise @library.SourceError,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  if self.regions.is_full() {
    self.finish_region()
  }
  let align = @library.AlignElem::alignment_in(styles).resolve(styles)
  let fragment = layouter(engine, styles, self.regions)
  self.layout_fragment(align, fragment)
}

///|
/// Store laid out content, coming from either a block or a custom layouter.
fn StackLayouter::layout_fragment(
  self : StackLayouter,
  align : @library.Axes[@library.FixedAlignment],
  fragment : @library.Fragment,
) -> Unit raise @library.SourceError {
  let len = fragment.len()
  for i, frame in fragment.into_frames() {
    // Grow our size, shrink the region and save the frame for later.
    let specific_size = frame.size()
    if self.dir.axis() == Y {
      self.regions = {
        ..self.regions,
        size: { ..self.regions.size, y: self.regions.size.y - specific_size.y, },
      }
    }
    let generic_size = match self.axis {
      X => GenericSize::new(specific_size.y, specific_size.x)
      Y => GenericSize::new(specific_size.x, specific_size.y)
    }
    self.used = {
      main: self.used.main + generic_size.main,
      cross: self.used.cross.max(generic_size.cross),
    }
    self.items.push(Frame(frame, align))
    if i + 1 < len {
      self.finish_region()
    }
  }
}

///|
/// Advance to the next region.
fn StackLayouter::finish_region(
  self : StackLayouter,
) -> Unit raise @library.SourceError {
  // Determine the size of the stack in this region depending on whether the
  // region expands.
  let mut size = self.expand
    .select(self.initial, self.used.into_axes(self.axis))
    .min(self.initial)

  // Expand fully if there are fr spacings.
  let full = self.initial.get(self.axis)
  let remaining = full - self.used.main
  if self.fr.get() > 0.0 && full.is_finite() {
    self.used = { ..self.used, main: full, }
    size = size.with_axis_value(self.axis, full)
  }
  if !size.is_finite_size() {
    @library.bail_at(self.span, "stack spacing is infinite")
  }
  let output = @library.Frame::soft(size)
  let mut cursor = @library.Abs::zero()
  let mut ruler = @library.FixedAlignment::from_side(self.dir.start())

  // Place all frames.
  for item in self.items {
    match item {
      Absolute(v) => cursor = cursor + v
      Fractional(v) => cursor = cursor + v.share(self.fr, remaining)
      Frame(frame, align) => {
        if self.dir.is_positive() {
          ruler = fixed_align_max(ruler, align.get(self.axis))
        } else {
          ruler = fixed_align_min(ruler, align.get(self.axis))
        }

        // Align along the main axis.
        let parent = size.get(self.axis)
        let child = frame.size().get(self.axis)
        let main = ruler.position(parent - self.used.main) +
          (if self.dir.is_positive() {
            cursor
          } else {
            self.used.main - child - cursor
          })

        // Align along the cross axis.
        let other = self.axis.other()
        let cross = align
          .get(other)
          .position(size.get(other) - frame.size().get(other))
        let pos = GenericSize::new(cross, main).to_point(self.axis)
        cursor = cursor + child
        output.push_frame(pos, frame)
      }
    }
  }
  self.items.clear()

  // Advance to the next region.
  self.regions = self.regions.next()
  self.initial = self.regions.size
  self.used = GenericSize::zero()
  self.fr = @library.Fr::zero()
  self.finished.push(output)
}

///|
/// Finish layouting and return the resulting frames.
fn StackLayouter::finish(
  self : StackLayouter,
) -> @library.Fragment raise @library.SourceError {
  self.finish_region()
  @library.Fragment::frames(self.finished)
}

///|
/// A generic size with main and cross axes. The axes are generic, meaning
/// the main axis could correspond to either the X or the Y axis.
priv struct GenericSize {
  /// The cross component, along the axis perpendicular to the main.
  cross : @library.Abs
  /// The main component.
  main : @library.Abs
}

///|
/// Create a new instance from the two components.
fn GenericSize::new(cross : @library.Abs, main : @library.Abs) -> GenericSize {
  { cross, main, }
}

///|
/// Convert to the specific representation, given the current main axis.
fn GenericSize::into_axes(
  self : GenericSize,
  main : @library.Axis,
) -> @library.Axes[@library.Abs] {
  match main {
    X => @library.Axes::new(self.main, self.cross)
    Y => @library.Axes::new(self.cross, self.main)
  }
}

///|
/// The zero value.
fn GenericSize::zero() -> GenericSize {
  { cross: @library.Abs::zero(), main: @library.Abs::zero(), }
}

///|
/// Convert to a point.
fn GenericSize::to_point(
  self : GenericSize,
  main : @library.Axis,
) -> @library.Point {
  self.into_axes(main).to_point()
}
