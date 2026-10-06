// Port of the castable value types of `typst-library/src/layout/container.rs`
// (`BlockBody`, `BaselinePos`, the layout callbacks) and the
// `BoxElem`/`BlockElem` field defaults and constructors.
// `Sizing` lives in `spacing.mbt`.

///|
/// `InlineElem` cannot be constructed manually (upstream `Construct for
/// InlineElem`).
fn inline_elem_init(e : Element) -> Unit {
  e.hooks().construct = Some((_, args) => {
    bail_at(args.span, "cannot be constructed manually")
  })
}

///|
/// Create an inline-level item with a custom layouter.
pub fn[T : NativeElement] InlineElem::layouter(
  captured : T,
  callback : (T, Engine, Locator, StyleChain, Axes[Abs]) -> Array[InlineItem] raise SourceError,
) -> InlineElem {
  InlineElem::new(InlineCallback::new(captured, callback))
}

///|
/// Layout the element.
pub fn InlineElem::layout(
  self : InlineElem,
  engine : Engine,
  locator : Locator,
  styles : StyleChain,
  region : Axes[Abs],
) -> Array[InlineItem] raise SourceError {
  self.body().call(engine, locator, styles, region)
}

///|
/// Layouted items suitable for placing in a paragraph.
pub(all) enum InlineItem {
  /// Absolute spacing between other items, and whether it is weak.
  Space(Abs, Bool)
  /// Layouted inline-level content.
  Frame(Frame)
}

///|
/// Creates a new block element with a normal content body and directly packs
/// it into type-erased content.
pub fn BlockElem::packed(body : Content) -> Content {
  BlockElem::new().with_body(Some(Content(body))).pack()
}

///|
/// Create a block with a custom single-region layouter.
///
/// Such a block must have `breakable: false` (which is set by this
/// constructor).
pub fn[T : NativeElement] BlockElem::single_layouter(
  captured : T,
  f : (T, Engine, Locator, StyleChain, LayoutRegion) -> Frame raise SourceError,
) -> BlockElem {
  BlockElem::new()
  .with_breakable(false)
  .with_body(Some(SingleLayouter(BlockSingleCallback::new(captured, f))))
}

///|
/// Create a block with a custom multi-region layouter.
pub fn[T : NativeElement] BlockElem::multi_layouter(
  captured : T,
  f : (T, Engine, Locator, StyleChain, Regions) -> Fragment raise SourceError,
) -> BlockElem {
  BlockElem::new().with_body(
    Some(MultiLayouter(BlockMultiCallback::new(captured, f))),
  )
}

///|
/// Create a block with a custom multi-region layouter that captures plain
/// content instead of a typed element (used by the test runner's `bounds`,
/// whose upstream element only exists in the test harness).
pub fn BlockElem::multi_layouter_content(
  captured : Content,
  f : (Content, Engine, Locator, StyleChain, Regions) -> Fragment raise SourceError,
) -> BlockElem {
  BlockElem::new().with_body(Some(MultiLayouter({ captured, f, })))
}

///|
/// The contents of a block.
pub(all) enum BlockBody {
  /// The block contains normal content.
  Content(Content)
  /// The block contains a layout callback that needs access to just one
  /// base region.
  SingleLayouter(BlockSingleCallback)
  /// The block contains a layout callback that needs access to the exact
  /// regions.
  MultiLayouter(BlockMultiCallback)
} derive(Eq)

///|
pub impl Default for BlockBody with fn default() {
  Content(Content::empty())
}

///|
pub impl Reflect for BlockBody with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for BlockBody with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for BlockBody with fn castable(v) {
  // The callback variants are only created internally.
  Content::castable(v) ||
  v is Dyn(BlockSingleCallback(_) | BlockMultiCallback(_))
}

///|
/// Upstream casts callbacks to `auto`; since element fields are stored as
/// values here, the callbacks are kept in internal dynamic values instead
/// (which display like `auto`).
pub impl IntoValue for BlockBody with fn into_value(self) {
  match self {
    Content(content) => Content(content)
    SingleLayouter(callback) => Dyn(BlockSingleCallback(callback))
    MultiLayouter(callback) => Dyn(BlockMultiCallback(callback))
  }
}

///|
pub impl FromValue for BlockBody with fn from_value(v) {
  match v {
    Dyn(BlockSingleCallback(callback)) => SingleLayouter(callback)
    Dyn(BlockMultiCallback(callback)) => MultiLayouter(callback)
    v => Content(FromValue::from_value(v))
  }
}

// Manual closure implementations for layout callbacks (upstream module
// `callbacks`). Each stores the type-erased captured element and a function
// that is called with it. Equality only compares the captured content (like
// upstream, which skips comparing function pointers).

///|
/// A layout callback of an `InlineElem`.
pub struct InlineCallback {
  priv captured : Content
  priv f : (Content, Engine, Locator, StyleChain, Axes[Abs]) -> Array[
    InlineItem,
  ] raise SourceError
}

///|
pub fn[T : NativeElement] InlineCallback::new(
  captured : T,
  f : (T, Engine, Locator, StyleChain, Axes[Abs]) -> Array[InlineItem] raise SourceError,
) -> InlineCallback {
  {
    // Type-erase the content.
    captured: captured.into_content(),
    f: (c, engine, locator, styles, region) => {
      f(T::from_content_unchecked(c), engine, locator, styles, region)
    },
  }
}

///|
pub fn InlineCallback::call(
  self : InlineCallback,
  engine : Engine,
  locator : Locator,
  styles : StyleChain,
  region : Axes[Abs],
) -> Array[InlineItem] raise SourceError {
  (self.f)(self.captured, engine, locator, styles, region)
}

///|
pub fn InlineCallback::captured(self : InlineCallback) -> Content {
  self.captured
}

///|
pub impl Eq for InlineCallback with fn equal(self, other) {
  self.captured == other.captured
}

///|
pub impl Reflect for InlineCallback with fn input() {
  Type(Type::auto())
}

///|
pub impl Reflect for InlineCallback with fn output() {
  Type(Type::auto())
}

///|
pub impl Reflect for InlineCallback with fn castable(v) {
  v is Dyn(InlineCallback(_))
}

///|
pub extend InlineCallback with Reflect::{output, input, castable}

///|
pub impl IntoValue for InlineCallback with fn into_value(self) {
  Dyn(InlineCallback(self))
}

///|
pub impl FromValue for InlineCallback with fn from_value(v) {
  match v {
    Dyn(InlineCallback(callback)) => callback
    v => raise HintedError(InlineCallback::input().error(v))
  }
}

///|
/// A single-region layout callback of a `BlockElem`.
pub struct BlockSingleCallback {
  priv captured : Content
  priv f : (Content, Engine, Locator, StyleChain, LayoutRegion) -> Frame raise SourceError
}

///|
pub fn[T : NativeElement] BlockSingleCallback::new(
  captured : T,
  f : (T, Engine, Locator, StyleChain, LayoutRegion) -> Frame raise SourceError,
) -> BlockSingleCallback {
  {
    captured: captured.into_content(),
    f: (c, engine, locator, styles, region) => {
      f(T::from_content_unchecked(c), engine, locator, styles, region)
    },
  }
}

///|
pub fn BlockSingleCallback::call(
  self : BlockSingleCallback,
  engine : Engine,
  locator : Locator,
  styles : StyleChain,
  region : LayoutRegion,
) -> Frame raise SourceError {
  (self.f)(self.captured, engine, locator, styles, region)
}

///|
pub fn BlockSingleCallback::captured(self : BlockSingleCallback) -> Content {
  self.captured
}

///|
pub impl Eq for BlockSingleCallback with fn equal(self, other) {
  self.captured == other.captured
}

///|
/// A multi-region layout callback of a `BlockElem`.
pub struct BlockMultiCallback {
  priv captured : Content
  priv f : (Content, Engine, Locator, StyleChain, Regions) -> Fragment raise SourceError
}

///|
pub fn[T : NativeElement] BlockMultiCallback::new(
  captured : T,
  f : (T, Engine, Locator, StyleChain, Regions) -> Fragment raise SourceError,
) -> BlockMultiCallback {
  {
    captured: captured.into_content(),
    f: (c, engine, locator, styles, regions) => {
      f(T::from_content_unchecked(c), engine, locator, styles, regions)
    },
  }
}

///|
pub fn BlockMultiCallback::call(
  self : BlockMultiCallback,
  engine : Engine,
  locator : Locator,
  styles : StyleChain,
  regions : Regions,
) -> Fragment raise SourceError {
  (self.f)(self.captured, engine, locator, styles, regions)
}

///|
pub fn BlockMultiCallback::captured(self : BlockMultiCallback) -> Content {
  self.captured
}

///|
pub impl Eq for BlockMultiCallback with fn equal(self, other) {
  self.captured == other.captured
}

///|
/// Defines how to determine the baseline of a box.
///
/// Here `None` means unspecified and fields set to it are inherited.
pub(all) struct BaselinePos {
  /// Baseline's reference position relative to the height of the box's
  /// contents.
  at : Smart[VAlignment]?
  /// Amount to shift the baseline by.
  shift : Rel[Length]?
} derive(Eq, Hash)

///|
pub impl Default for BaselinePos with fn default() {
  { at: Some(Auto), shift: Some(Rel::zero()), }
}

///|
/// Baseline position relative to frame height, or `auto` to align with the
/// inner baseline.
pub fn BaselinePos::at(self : BaselinePos) -> Smart[VAlignment] {
  self.at.unwrap_or(Auto)
}

///|
/// Amount to shift by, with default resolved.
pub fn BaselinePos::shift(self : BaselinePos) -> Rel[Length] {
  self.shift.unwrap_or(Rel::zero())
}

///|
pub impl Fold for BaselinePos with fn fold(self, outer) {
  { at: self.at |> opt_or(outer.at), shift: self.shift |> opt_or(outer.shift), }
}

///|
pub impl Reflect for BaselinePos with fn input() {
  input_of((Ty::new() : Ty[Smart[VAlignment]]))
  .union_with(Type(Type::relative()))
  .union_with(Type(Type::dict()))
}

///|
pub impl Reflect for BaselinePos with fn output() {
  BaselinePos::input()
}

///|
pub impl Reflect for BaselinePos with fn castable(v) {
  v is Auto ||
  VAlignment::castable(v) ||
  v is (Relative(_) | Length(_) | Ratio(_) | Dict(_))
}

///|
pub extend BaselinePos with Reflect::{output, input, castable}

///|
pub impl IntoValue for BaselinePos with fn into_value(self) {
  let dict = Dict::new()
  if self.at is Some(at) {
    dict.insert("at", at.into_value())
  }
  if self.shift is Some(shift) {
    dict.insert("shift", shift.into_value())
  }
  Dict(dict)
}

///|
pub extend BaselinePos with IntoValue::{into_value}

///|
pub impl FromValue for BaselinePos with fn from_value(v) {
  if v is Auto || VAlignment::castable(v) {
    let at : Smart[VAlignment] = FromValue::from_value(v)
    return { at: Some(at), shift: None, }
  }
  match v {
    Relative(_) | Length(_) | Ratio(_) => {
      let shift : Rel[Length] = FromValue::from_value(v)
      { at: None, shift: Some(shift), }
    }
    Dict(dict) => {
      // Get a value by key, accepting either non-existence or something
      // convertible to type T.
      let dict = dict.copy()
      let at = dict_take_cast(dict, "at")
      let shift = dict_take_cast(dict, "shift")
      dict.finish(["at", "shift"])
      { at, shift, }
    }
    v => raise HintedError(BaselinePos::input().error(v))
  }
}

///|
fn box_elem_baseline_default() -> Value {
  BaselinePos::default().into_value()
}

///|
/// Upstream `Sizing::default()` (`auto`).
fn box_elem_width_default() -> Value {
  Auto
}

///|
/// Upstream `Sizing::default()` (`auto`).
fn block_elem_height_default() -> Value {
  Auto
}
