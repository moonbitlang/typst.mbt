// Port of `typst-library/src/math/ir/item.rs`.
//
// Rust's `Cell`s and `&mut` access are modelled with mutable fields: math
// items are reference types here, and every component owns its own
// properties.

///|
/// An element in the resolver's item stream: either a math item, or a
/// `Linebreak` or `Align` item that only exist during resolution.
pub(all) enum RawMathItem {
  /// A math item.
  Item(MathItem)
  /// A line break.
  Linebreak
  /// An alignment point.
  Align
}

///|
/// Whether this item should be ignored for spacing calculations.
pub fn RawMathItem::is_ignorant(self : RawMathItem) -> Bool {
  match self {
    Item(item) => item.is_ignorant()
    Linebreak | Align => false
  }
}

///|
/// Unwraps this into its inner `MathItem`.
///
/// Returns `None` if this is a `Linebreak` or `Align`.
pub fn RawMathItem::into_item(self : RawMathItem) -> MathItem? {
  match self {
    Item(item) => Some(item)
    Linebreak | Align => None
  }
}

///|
/// The top-level item in the math IR.
pub(all) enum MathItem {
  /// A layoutable component with associated properties and styles.
  Comp(MathComponent)
  /// Explicit spacing with the font size at the point of creation. The
  /// boolean indicates whether the spacing is weak.
  Spacing(Length, Abs, Bool)
  /// A regular space.
  Space
  /// An introspection tag.
  Tag(Tag)
}

///|
/// Wraps the given items into a group item, or returns the single item if
/// there is only one.
pub fn MathItem::wrap(items : Array[MathItem], styles : StyleChain) -> MathItem {
  if items.length() == 1 {
    items[0]
  } else {
    MathGroupItem::create(items, styles)
  }
}

///|
/// Returns the limit placement configuration for this item.
pub fn MathItem::limits(self : MathItem) -> MathLimits {
  match self {
    Comp(comp) => comp.props.limits
    _ => Never
  }
}

///|
/// Returns the math class of this item.
pub fn MathItem::class(self : MathItem) -> @unicode.MathClass {
  self.raw_class().unwrap_or(Normal)
}

///|
pub fn MathItem::raw_class(self : MathItem) -> @unicode.MathClass? {
  match self {
    Comp(comp) => comp.props.class
    Spacing(_, _, _) | Space => Some(Space)
    Tag(_) => Some(Special)
  }
}

///|
/// Returns the effective math class on the right side of this item.
///
/// For fenced items with a closing delimiter and no explicit class, this
/// returns the closing class instead of the item's overall class.
pub fn MathItem::rclass(self : MathItem) -> @unicode.MathClass {
  match self {
    Comp({ kind: Fenced(fence), props: { class: None, .. }, .. }) if fence.close
      is Some(_) => Closing
    _ => self.class()
  }
}

///|
/// Returns the effective math class on the left side of this item.
///
/// For fenced items with an opening delimiter and no explicit class, this
/// returns the opening class instead of the item's overall class.
pub fn MathItem::lclass(self : MathItem) -> @unicode.MathClass {
  match self {
    Comp({ kind: Fenced(fence), props: { class: None, .. }, .. }) if fence.open
      is Some(_) => Opening
    _ => self.class()
  }
}

///|
/// Returns the math size of this item, if it is a component.
pub fn MathItem::size(self : MathItem) -> MathSize? {
  match self {
    Comp(comp) => Some(comp.props.size)
    _ => None
  }
}

///|
/// Whether this item should have explicit spaces around it.
pub fn MathItem::is_spaced(self : MathItem) -> Bool {
  if self.class() == Fence {
    return true
  }
  if self is Comp(comp) &&
    comp.props.spaced &&
    comp.props.class() is (Normal | Alphabetic) {
    true
  } else {
    false
  }
}

///|
/// Whether this item should be ignored for spacing calculations.
pub fn MathItem::is_ignorant(self : MathItem) -> Bool {
  match self {
    Comp(comp) => comp.props.ignorant
    Tag(_) => true
    _ => false
  }
}

///|
/// Returns the source span of this item.
pub fn MathItem::span(self : MathItem) -> @syntax.Span {
  match self {
    Comp(comp) => comp.props.span
    _ => @syntax.Span::detached()
  }
}

///|
/// Returns the style chain of this item, if it is a component.
pub fn MathItem::styles(self : MathItem) -> StyleChain? {
  match self {
    Comp(comp) => Some(comp.styles)
    _ => None
  }
}

///|
/// Returns whether this glyph has been stretched as a middle delimiter.
pub fn MathItem::mid_stretched(self : MathItem) -> Bool? {
  if self is Comp({ kind: Glyph(glyph), .. }) {
    glyph.mid_stretched
  } else {
    None
  }
}

///|
/// Whether this item is a multiline item.
pub fn MathItem::is_multiline(self : MathItem) -> Bool {
  self is Comp({ kind: Multiline(_), .. })
}

///|
/// Returns the inner items if this is a group, or an array containing just
/// this item otherwise.
pub fn MathItem::as_slice(self : MathItem) -> ArrayView[MathItem] {
  if self is Comp({ kind: Group(group), .. }) {
    group.items[:]
  } else {
    [self][:]
  }
}

///|
/// Sets the limit placement configuration for this item.
pub fn MathItem::set_limits(self : MathItem, limits : MathLimits) -> Unit {
  if self is Comp(comp) {
    comp.props.limits = limits
  }
}

///|
/// Sets the effective math class of this item.
pub fn MathItem::set_class(self : MathItem, class : @unicode.MathClass) -> Unit {
  if self is Comp(comp) {
    comp.props.class = Some(class)
  }
}

///|
/// Sets the effective math class and applies it to glyph layout.
pub fn MathItem::set_explicit_class(
  self : MathItem,
  class : @unicode.MathClass,
) -> Unit {
  self.set_class(class)
  if self is Comp({ kind: Glyph(glyph), props, .. }) {
    glyph.class = class

    // Small hack to ensure the non-explicit stretch gets added, as the class
    // is not recursive. This applies an equivalent stretch to the one in
    // `resolve_symbol`.
    if class == Large &&
      props.size == MathSize::Display &&
      !glyph.stretch.is_explicit(Y) {
      let info = StretchInfo::default()
      glyph.stretch = glyph.stretch.with_y(info)
    }
  }
}

///|
/// Sets the left spacing for this item if not already set.
pub fn MathItem::set_lspace(self : MathItem, lspace : Em?) -> Unit {
  if self is Comp(comp) && comp.props.lspace is None {
    comp.props.lspace = lspace
  }
}

///|
/// Sets the right spacing for this item if not already set.
pub fn MathItem::set_rspace(self : MathItem, rspace : Em?) -> Unit {
  if self is Comp(comp) && comp.props.rspace is None {
    comp.props.rspace = rspace
  }
}

///|
/// If this is a multiline item, sets the centered field to true.
pub fn MathItem::with_multiline_centering(self : MathItem) -> MathItem {
  if self is Comp({ kind: Multiline(multiline), .. }) {
    multiline.centered = true
  }
  self
}

///|
/// Sets whether this glyph has been stretched as a middle delimiter.
pub fn MathItem::set_mid_stretched(
  self : MathItem,
  mid_stretched : Bool?,
) -> Unit {
  if self is Comp({ kind: Glyph(glyph), .. }) {
    glyph.mid_stretched = mid_stretched
  }
}

///|
/// Sets the stretch configuration for this glyph, marking it as explicit.
pub fn MathItem::set_stretch(self : MathItem, stretch : Stretch) -> Unit {
  let x = stretch.x.map(info => { ..info, explicit: true, })
  let y = stretch.y.map(info => { ..info, explicit: true, })
  self.replace_stretch({ x, y, })
}

///|
/// Sets the stretch configuration for this glyph.
pub fn MathItem::replace_stretch(self : MathItem, stretch : Stretch) -> Unit {
  if self is Comp({ kind: Glyph(glyph), .. }) {
    glyph.stretch = stretch
  }
}

///|
/// Updates the vertical stretch info for this glyph.
pub fn MathItem::set_y_stretch(self : MathItem, info : StretchInfo) -> Unit {
  if self is Comp({ kind: Glyph(glyph), .. }) {
    glyph.stretch = glyph.stretch.with_y({ ..info, explicit: true, })
  }
}

///|
/// Updates the stretch info for both axes of this glyph.
pub fn MathItem::update_stretch(self : MathItem, info : StretchInfo) -> Unit {
  if self is Comp({ kind: Glyph(glyph), .. }) {
    glyph.stretch = glyph.stretch.update(info)
  }
}

///|
/// Sets the reference size for relative stretching on the given axis.
pub fn MathItem::set_stretch_relative_to(
  self : MathItem,
  relative_to : Abs,
  axis : Axis,
) -> Unit {
  if self is Comp({ kind: Glyph(glyph), .. }) {
    glyph.stretch = glyph.stretch.relative_to(relative_to, axis)
  }
}

///|
/// Sets the font size to use for short-fall calculations on the given axis.
pub fn MathItem::set_stretch_font_size(
  self : MathItem,
  font_size : Abs,
  axis : Axis,
) -> Unit {
  if self is Comp({ kind: Glyph(glyph), .. }) {
    glyph.stretch = glyph.stretch.font_size(font_size, axis)
  }
}

///|
/// Enables the flac OpenType feature for this glyph.
pub fn MathItem::set_flac(self : MathItem) -> Unit {
  if self is Comp({ kind: Glyph(glyph), .. }) {
    glyph.flac = true
  }
}

///|
/// A generic component that bundles a specific math item kind with common
/// properties and styles.
pub struct MathComponent {
  /// The specific kind of math item.
  kind : MathKind
  /// The properties attached to this component.
  props : MathProperties
  /// The item's styles.
  styles : StyleChain
}

///|
/// The specific kind of a layoutable math item.
pub(all) enum MathKind {
  /// A group of math items laid out horizontally.
  Group(MathGroupItem)
  /// A multiline equation with items pre-split into rows and columns.
  Multiline(MultilineItem)
  /// A radical (square root or nth root).
  Radical(RadicalItem)
  /// An item enclosed in delimiters.
  Fenced(FencedItem)
  /// A vertical fraction.
  Fraction(FractionItem)
  /// An inline skewed fraction.
  SkewedFraction(SkewedFractionItem)
  /// A 2D collection of math items laid out as a table/matrix.
  Table(MathTableItem)
  /// A base with scripts (subscripts/superscripts) and/or limits attached.
  Scripts(ScriptsItem)
  /// A base with an accent mark above or below.
  Accented(AccentItem)
  /// A base with a line overlaid.
  Cancel(CancelItem)
  /// A base with a line drawn above or below.
  Line(LineItem)
  /// Grouped prime symbols.
  Primes(PrimesItem)
  /// A text string.
  Text(MathTextItem)
  /// A number.
  Number(NumberItem)
  /// A single glyph (grapheme cluster).
  Glyph(GlyphItem)
  /// Inline content.
  Box(BoxItem)
  /// A MathML HTML element.
  Mathml(MathmlItem)
  /// External content that needs to be laid out separately.
  External(ExternalItem)
}

///|
/// Shared properties for all layoutable math components.
pub struct MathProperties {
  /// How attachments should be positioned.
  mut limits : MathLimits
  /// The math class.
  mut class : @unicode.MathClass?
  /// The current math size.
  size : MathSize
  /// Whether this item is in a cramped style.
  cramped : Bool
  /// Whether this item should be ignored for spacing calculations.
  mut ignorant : Bool
  /// Whether this item should have explicit spaces around it.
  mut spaced : Bool
  /// The amount of spacing to the left of this item.
  mut lspace : Em?
  /// The amount of spacing to the right of this item.
  mut rspace : Em?
  /// Whether this item is at the start of a left-aligned column but
  /// semantically infix.
  mut align_form_infix : Bool
  /// The source span.
  span : @syntax.Span
}

///|
/// Creates properties with an explicit class, avoiding the style lookup.
fn MathProperties::new(
  styles : StyleChain,
  class : @unicode.MathClass?,
  span : @syntax.Span,
) -> MathProperties {
  {
    limits: Never,
    class,
    size: EquationElem::size_in(styles),
    cramped: EquationElem::cramped_in(styles),
    ignorant: false,
    spaced: false,
    lspace: None,
    rspace: None,
    align_form_infix: false,
    span,
  }
}

///|
/// Creates default properties from the given styles.
///
/// This gets the math size from the styles.
pub fn MathProperties::default(
  styles : StyleChain,
  span : @syntax.Span,
) -> MathProperties {
  MathProperties::new(styles, None, span)
}

///|
/// Returns the class, using the default normal class if None.
pub fn MathProperties::class(self : MathProperties) -> @unicode.MathClass {
  self.class.unwrap_or(Normal)
}

///|
/// Sets how attachments should be positioned for this item.
fn MathProperties::with_limits(
  self : MathProperties,
  limits : MathLimits,
) -> MathProperties {
  self.limits = limits
  self
}

///|
/// Sets whether this item should be ignored for spacing calculations.
fn MathProperties::with_ignorant(
  self : MathProperties,
  ignorant : Bool,
) -> MathProperties {
  self.ignorant = ignorant
  self
}

///|
/// Sets whether this item should have explicit spaces around it.
fn MathProperties::with_spaced(
  self : MathProperties,
  spaced : Bool,
) -> MathProperties {
  self.spaced = spaced
  self
}

///|
/// Bundles a kind with properties and styles into an item.
fn math_component(
  kind : MathKind,
  props : MathProperties,
  styles : StyleChain,
) -> MathItem {
  Comp({ kind, props, styles, })
}

///|
/// A group of math items laid out horizontally (upstream math IR
/// `GroupItem`; renamed because `GroupItem` is the frame group of
/// `layout/frame.rs`).
pub struct MathGroupItem {
  /// The items in the group.
  items : Array[MathItem]
}

///|
/// Creates a new group item.
pub fn MathGroupItem::create(
  items : Array[MathItem],
  styles : StyleChain,
) -> MathItem {
  let props = MathProperties::default(styles, @syntax.Span::detached())
  math_component(Group({ items, }), props, styles)
}

///|
/// A multiline equation with items pre-split into rows and columns.
pub struct MultilineItem {
  /// The cells, organized by row.
  ///
  /// Rows correspond to linebreaks in the source. Columns within each row
  /// correspond to alignment points. All rows are padded to have the same
  /// number of columns.
  rows : Array[AlignedRow]
  /// Whether the resulting frame should be aligned on the math axis.
  ///
  /// Only used in paged export.
  mut centered : Bool
}

///|
/// Creates a new multiline item.
pub fn MultilineItem::create(
  rows : Array[AlignedRow],
  styles : StyleChain,
) -> MathItem {
  let props = MathProperties::default(styles, @syntax.Span::detached())
  math_component(Multiline({ rows, centered: false, }), props, styles)
}

///|
/// A radical (square root or nth root).
pub struct RadicalItem {
  /// The item under the radical symbol.
  radicand : MathItem
  /// The index for nth roots. `None` for square roots.
  index : MathItem?
  /// The radical symbol.
  ///
  /// Only used in paged export.
  sqrt : MathItem
}

///|
/// Creates a new radical item.
pub fn RadicalItem::create(
  radicand : MathItem,
  index : MathItem?,
  sqrt : MathItem,
  styles : StyleChain,
  span : @syntax.Span,
) -> MathItem {
  let props = MathProperties::default(styles, span)
  math_component(Radical({ radicand, index, sqrt, }), props, styles)
}

///|
/// An item enclosed in delimiters.
pub struct FencedItem {
  /// The optional opening delimiter.
  open : MathItem?
  /// The optional closing delimiter.
  close : MathItem?
  /// The item between the delimiters.
  body : FencedBody
  /// How the target height for the delimiters should be calculated.
  ///
  /// If true, the height for each body item is two times the maximum of its
  /// ascent and descent. If false, the height for each body item is simply
  /// its height.
  ///
  /// Only used in paged export.
  balanced : Bool
}

///|
/// Creates a new fenced item.
pub fn FencedItem::create(
  open : MathItem?,
  close : MathItem?,
  body : FencedBody,
  balanced : Bool,
  styles : StyleChain,
  span : @syntax.Span,
) -> MathItem {
  let props = MathProperties::default(styles, span)
  math_component(Fenced({ open, close, body, balanced, }), props, styles)
}

///|
/// A vertical fraction.
pub struct FractionItem {
  /// The item in the top part of the fraction.
  numerator : MathItem
  /// The item in the bottom part of the fraction.
  denominator : MathItem
  /// Whether to draw a fraction line between the numerator and denominator.
  line : Bool
  /// The amount of padding added before and after the fraction.
  padding : Em
}

///|
/// Creates a new fraction item.
pub fn FractionItem::create(
  numerator : MathItem,
  denominator : MathItem,
  line : Bool,
  padding : Em,
  styles : StyleChain,
  span : @syntax.Span,
) -> MathItem {
  let props = MathProperties::default(styles, span)
  math_component(
    Fraction({ numerator, denominator, line, padding, }),
    props,
    styles,
  )
}

///|
/// An inline skewed fraction.
pub struct SkewedFractionItem {
  /// The item in the top-left part of the fraction.
  numerator : MathItem
  /// The item in the bottom-right part of the fraction.
  denominator : MathItem
  /// The fraction slash symbol.
  ///
  /// Only used in paged export.
  slash : MathItem
}

///|
/// Creates a new skewed fraction item.
pub fn SkewedFractionItem::create(
  numerator : MathItem,
  denominator : MathItem,
  slash : MathItem,
  styles : StyleChain,
  span : @syntax.Span,
) -> MathItem {
  let props = MathProperties::default(styles, span)
  math_component(
    SkewedFraction({ numerator, denominator, slash, }),
    props,
    styles,
  )
}

///|
/// A 2D collection of math items laid out as a table/matrix (upstream
/// `math::ir::TableItem`; `TableItem` is taken by `table.mbt`).
pub struct MathTableItem {
  /// The cells of the table, organized by row.
  cells : Array[Array[AlignedRow]]
  /// The gap between rows and columns.
  gap : Axes[Rel[Abs]]
  /// Optional augmentation lines to draw.
  augment : ResolvedAugment?
  /// The alignment for cells.
  align : FixedAlignment
  /// How to perform left/right alternation for alignment.
  alternator : LeftRightAlternator
}

///|
/// Creates a new table item.
pub fn MathTableItem::create(
  cells : Array[Array[AlignedRow]],
  gap : Axes[Rel[Abs]],
  augment : ResolvedAugment?,
  align : FixedAlignment,
  alternator : LeftRightAlternator,
  styles : StyleChain,
  span : @syntax.Span,
) -> MathItem {
  let props = MathProperties::default(styles, span)
  math_component(
    Table({ cells, gap, augment, align, alternator, }),
    props,
    styles,
  )
}

///|
/// A base with scripts (subscripts/superscripts) and/or limits attached.
pub struct ScriptsItem {
  /// The base item.
  base : MathItem
  /// The top attachment (limit above).
  top : MathItem?
  /// The bottom attachment (limit below).
  bottom : MathItem?
  /// The top-left attachment (pre-superscript).
  top_left : MathItem?
  /// The bottom-left attachment (pre-subscript).
  bottom_left : MathItem?
  /// The top-right attachment (post-superscript).
  top_right : MathItem?
  /// The bottom-right attachment (post-subscript).
  bottom_right : MathItem?
}

///|
/// Creates a new scripts item.
///
/// The resulting item inherits its math class from the base.
pub fn ScriptsItem::create(
  base : MathItem,
  top : MathItem?,
  bottom : MathItem?,
  top_left : MathItem?,
  bottom_left : MathItem?,
  top_right : MathItem?,
  bottom_right : MathItem?,
  styles : StyleChain,
) -> MathItem {
  let props = MathProperties::new(
    styles,
    base.raw_class(),
    @syntax.Span::detached(),
  )
  math_component(
    Scripts({
      base,
      top,
      bottom,
      top_left,
      bottom_left,
      top_right,
      bottom_right,
    }),
    props,
    styles,
  )
}

///|
/// A base with an accent mark above or below.
pub struct AccentItem {
  /// The base item.
  base : MathItem
  /// The accent mark item.
  accent : MathItem
  /// Whether this is a top or bottom accent.
  position : MathPosition
  /// Whether dotless styles have been added.
  dotless : Bool
  /// Whether the item's width should include the accent's width.
  ///
  /// Only used in paged export.
  exact_frame_width : Bool
}

///|
/// Creates a new accent item.
///
/// The resulting item inherits its math class from the base.
pub fn AccentItem::create(
  base : MathItem,
  accent : MathItem,
  position : MathPosition,
  dotless : Bool,
  exact_frame_width : Bool,
  styles : StyleChain,
) -> MathItem {
  let props = MathProperties::new(
    styles,
    base.raw_class(),
    @syntax.Span::detached(),
  )
  math_component(
    Accented({ base, accent, position, dotless, exact_frame_width, }),
    props,
    styles,
  )
}

///|
/// A base with a line overlaid.
pub struct CancelItem {
  /// The base item.
  base : MathItem
  /// The length of the line.
  length : Rel[Abs]
  /// The stroke for the line.
  stroke : FixedStroke
  /// Whether a cross (two lines) is drawn instead of a single line.
  cross : Bool
  /// Whether to invert the angle of the first line.
  invert_first_line : Bool
  /// Whether to draw the line behind the main content.
  background : Bool
  /// The angle of the line.
  angle : Smart[CancelAngle]
}

///|
/// Creates a new cancel item.
///
/// The resulting item inherits its math class from the base.
pub fn CancelItem::create(
  base : MathItem,
  length : Rel[Abs],
  stroke : FixedStroke,
  cross : Bool,
  invert_first_line : Bool,
  background : Bool,
  angle : Smart[CancelAngle],
  styles : StyleChain,
  span : @syntax.Span,
) -> MathItem {
  let props = MathProperties::new(styles, base.raw_class(), span)
  math_component(
    Cancel({
      base,
      length,
      stroke,
      cross,
      invert_first_line,
      background,
      angle,
    }),
    props,
    styles,
  )
}

///|
/// A base with a line drawn above or below.
pub struct LineItem {
  /// The base item.
  base : MathItem
  /// Whether the line is drawn above or below the base.
  position : MathPosition
}

///|
/// Creates a new line item.
///
/// The resulting item inherits its math class from the base.
pub fn LineItem::create(
  base : MathItem,
  position : MathPosition,
  styles : StyleChain,
  span : @syntax.Span,
) -> MathItem {
  let props = MathProperties::new(styles, base.raw_class(), span)
  math_component(Line({ base, position, }), props, styles)
}

///|
/// The prime character used by `PrimesItem`.
pub let prime_char : Char = '′'

///|
/// Grouped prime symbols.
///
/// This is for more than four prime symbols, since there are only dedicated
/// Unicode codepoints up to four.
pub struct PrimesItem {
  /// The number of primes to display. Always at least five.
  count : Int
}

///|
/// Creates a new primes item.
pub fn PrimesItem::create(count : Int, styles : StyleChain) -> MathItem {
  let props = MathProperties::default(styles, @syntax.Span::detached())
  math_component(Primes({ count, }), props, styles)
}

///|
/// A text string (upstream math IR `TextItem`; renamed because `TextItem` is
/// the shaped text run of `text/item.rs`).
pub struct MathTextItem {
  /// The text content.
  text : String
  /// The item's locator.
  locator : Locator
}

///|
/// Creates a new text item.
///
/// The resulting item is spaced and has alphabetic math class.
pub fn MathTextItem::create(
  text : String,
  styles : StyleChain,
  span : @syntax.Span,
  locator : Locator,
) -> MathItem {
  let props = MathProperties::new(styles, Some(Alphabetic), span).with_spaced(
    true,
  )
  math_component(Text({ text, locator, }), props, styles)
}

///|
/// A number.
pub struct NumberItem {
  /// The number's text content.
  text : String
}

///|
/// Creates a new number item.
pub fn NumberItem::create(
  text : String,
  styles : StyleChain,
  span : @syntax.Span,
) -> MathItem {
  let props = MathProperties::default(styles, span)
  math_component(Number({ text, }), props, styles)
}

///|
/// A single glyph (grapheme cluster).
pub struct GlyphItem {
  /// The text content.
  text : String
  /// The math class to use for layout.
  ///
  /// When the math class is large, the glyph is centered vertically and, in
  /// display style, stretched vertically. This value is not necessarily the
  /// same as the item's associated `MathProperties::class`, which is used
  /// for determining spacing between items.
  mut class : @unicode.MathClass
  /// How the glyph should be stretched.
  mut stretch : Stretch
  /// Whether this glyph has been stretched as a middle delimiter.
  mut mid_stretched : Bool?
  /// Whether to apply the flac OpenType feature.
  mut flac : Bool
}

///|
/// Creates a new glyph item.
pub fn GlyphItem::create(
  text : String,
  styles : StyleChain,
  span : @syntax.Span,
) -> MathItem {
  if @unicode.graphemes(text).length() != 1 {
    abort("assertion failed: text.graphemes(true).count() == 1")
  }
  let c = text.get_char(0).unwrap()
  let class = @unicode.default_math_class(c)
  let limits = MathLimits::for_char_with_class(c, class)
  let kind = MathKind::Glyph({
    text,
    class: class.unwrap_or(Normal),
    stretch: Stretch::new(),
    mid_stretched: None,
    flac: false,
  })
  let props = MathProperties::new(styles, class, span).with_limits(limits)
  math_component(kind, props, styles)
}

///|
/// Inline content.
pub struct BoxItem {
  /// The `BoxElem` to layout.
  elem : BoxElem
  /// The item's locator.
  locator : Locator
}

///|
/// Creates a new box item.
///
/// The resulting item is spaced.
pub fn BoxItem::create(
  elem : BoxElem,
  styles : StyleChain,
  locator : Locator,
) -> MathItem {
  let props = MathProperties::default(styles, elem.pack().span()).with_spaced(
    true,
  )
  math_component(Box({ elem, locator, }), props, styles)
}

///|
/// A MathML HTML element with resolved children.
pub struct MathmlItem {
  /// The original MathML HTML element content.
  ///
  /// This is always a `HtmlElem`.
  elem : Content
  /// The element's resolved IR body.
  body : MathItem?
}

///|
/// Creates a new MathML HTML element item.
pub fn MathmlItem::create(
  elem : Content,
  body : MathItem?,
  styles : StyleChain,
) -> MathItem {
  let props = MathProperties::default(styles, elem.span())
  math_component(Mathml({ elem, body, }), props, styles)
}

///|
/// External content that needs to be laid out separately.
pub struct ExternalItem {
  /// The content to layout externally.
  content : Content
  /// The item's locator.
  locator : Locator
}

///|
/// Creates a new external item.
///
/// The resulting item is spaced and, if the content is a `PlaceElem`, is
/// ignorant.
pub fn ExternalItem::create(
  content : Content,
  styles : StyleChain,
  locator : Locator,
) -> MathItem {
  let props = MathProperties::default(styles, content.span())
    .with_spaced(true)
    .with_ignorant(content.is_(place_elem()))
  math_component(External({ content, locator, }), props, styles)
}

///|
/// Shared sizing information for split fence segments.
pub struct SharedFenceSizing {
  /// The body items of all fence segments.
  priv items : Array[MathItem]
  /// Relative to height for stretch size calculation.
  priv mut relative_to : Abs?
  /// The fence's styles.
  priv styles : StyleChain
}

///|
/// Creates a new shared sizing information.
pub fn SharedFenceSizing::new(
  items : Array[MathItem],
  styles : StyleChain,
) -> SharedFenceSizing {
  { items, relative_to: None, styles, }
}

///|
/// Retrieves or sets the relative to height by applying `f` to the body
/// items.
pub fn SharedFenceSizing::try_get_or_update(
  self : SharedFenceSizing,
  f : (ArrayView[MathItem], StyleChain) -> Abs raise SourceError,
) -> Abs raise SourceError {
  match self.relative_to {
    Some(relative_to) => relative_to
    None => {
      let relative_to = f(self.items[:], self.styles)
      self.relative_to = Some(relative_to)
      relative_to
    }
  }
}

///|
/// The body of a `FencedItem`.
pub(all) enum FencedBody {
  /// Owned body.
  Owned(MathItem)
  /// Shared body stored in `SharedFenceSizing`.
  Shared(index~ : Int, sizing~ : SharedFenceSizing)
}

///|
pub fn FencedBody::shared(
  index : Int,
  sizing : SharedFenceSizing,
) -> FencedBody {
  Shared(index~, sizing~)
}

///|
/// Shared sizing info for split fence segments.
pub fn FencedBody::sizing(self : FencedBody) -> SharedFenceSizing? {
  match self {
    Owned(_) => None
    Shared(sizing~, ..) => Some(sizing)
  }
}

///|
/// The body item (upstream `Deref for FencedBody`).
pub fn FencedBody::item(self : FencedBody) -> MathItem {
  match self {
    Owned(item) => item
    Shared(index~, sizing~) => sizing.items[index]
  }
}

///|
/// Stretch configuration for a glyph on both axes.
pub(all) struct Stretch {
  x : StretchInfo?
  y : StretchInfo?
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Stretch with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Stretch with Hash::{hash, hash_combine}

///|
/// Creates a new empty stretch configuration.
pub fn Stretch::new() -> Stretch {
  { x: None, y: None, }
}

///|
/// Adds horizontal stretch information.
pub fn Stretch::with_x(self : Stretch, info : StretchInfo) -> Stretch {
  { ..self, x: Some(info), }
}

///|
/// Adds vertical stretch information.
pub fn Stretch::with_y(self : Stretch, info : StretchInfo) -> Stretch {
  { ..self, y: Some(info), }
}

///|
/// Updates stretch info for both axes, combining with existing info and
/// marking them as explicit.
pub fn Stretch::update(self : Stretch, info : StretchInfo) -> Stretch {
  let info = { ..info, explicit: true, }
  let x = match self.x {
    Some(val) => val.mul(info)
    None => info
  }
  let y = match self.y {
    Some(val) => val.mul(info)
    None => info
  }
  { x: Some(x), y: Some(y), }
}

///|
fn Stretch::get(self : Stretch, axis : Axis) -> StretchInfo? {
  match axis {
    X => self.x
    Y => self.y
  }
}

///|
fn Stretch::set(self : Stretch, axis : Axis, info : StretchInfo?) -> Stretch {
  match axis {
    X => { ..self, x: info, }
    Y => { ..self, y: info, }
  }
}

///|
/// Sets the reference size for relative stretching on the given axis.
///
/// Only sets the value if not already set.
pub fn Stretch::relative_to(
  self : Stretch,
  relative_to : Abs,
  axis : Axis,
) -> Stretch {
  if self.get(axis) is Some(info) && info.relative_to is None {
    self.set(axis, Some({ ..info, relative_to: Some(relative_to), }))
  } else {
    self
  }
}

///|
/// Sets the font size for short-fall calculations on the given axis.
///
/// Only sets the value if not already set.
pub fn Stretch::font_size(
  self : Stretch,
  font_size : Abs,
  axis : Axis,
) -> Stretch {
  if self.get(axis) is Some(info) && info.font_size is None {
    self.set(axis, Some({ ..info, font_size: Some(font_size), }))
  } else {
    self
  }
}

///|
/// Returns the stretch info for the given axis, if any.
pub fn Stretch::resolve(self : Stretch, axis : Axis) -> StretchInfo? {
  if self.get(axis) is Some(info) && info.buffer is Some(buffer) {
    // Sort out the buffer before returning the info to use.
    if info.relative_to is Some(_) {
      Some({ ..info, target: buffer, })
    } else {
      Some({
        ..info,
        target: Rel::new(
          info.target.rel.mul_ratio(buffer.rel),
          buffer.rel.of(info.target.abs) + buffer.abs,
        ),
      })
    }
  } else {
    self.get(axis)
  }
}

///|
/// Returns the user-requested stretch target for the given axis, if any.
pub fn Stretch::resolve_requested(self : Stretch, axis : Axis) -> Rel[Length]? {
  match self.get(axis) {
    Some({ requested_target: Some(target), .. }) if !target.is_one() =>
      Some(target)
    _ => None
  }
}

///|
/// Whether the stretch along the given axis should be represented
/// explicitly.
pub fn Stretch::is_explicit(self : Stretch, axis : Axis) -> Bool {
  self.get(axis) is Some(info) && info.explicit
}

///|
/// Information about how to stretch a glyph on one axis.
pub(all) struct StretchInfo {
  /// The target size to stretch to.
  target : Rel[Abs]
  /// A buffer to store the latest stretch added, in case it needs to be
  /// relative to something else.
  buffer : Rel[Abs]?
  /// Whether this stretch is explicit. That is, the stretch was not from a
  /// large operator in display math.
  explicit : Bool
  /// The user-requested stretch target, if any.
  requested_target : Rel[Length]?
  /// The short-fall amount for glyph assembly.
  short_fall : Em
  /// The reference size for relative targets.
  ///
  /// Only used in paged export.
  relative_to : Abs?
  /// The font size to use for short-fall.
  ///
  /// Only used in paged export.
  font_size : Abs?
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StretchInfo with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StretchInfo with Hash::{hash, hash_combine}

///|
/// Creates new stretch info with the given target and short-fall.
pub fn StretchInfo::new(target : Rel[Abs], short_fall : Em) -> StretchInfo {
  {
    target,
    buffer: None,
    explicit: false,
    requested_target: None,
    short_fall,
    relative_to: None,
    font_size: None,
  }
}

///|
/// Creates stretch info from a user-specified size.
pub fn StretchInfo::from_size(
  size : Rel[Length],
  short_fall : Em,
  font_size : Abs,
) -> StretchInfo {
  {
    target: size.map(l => l.at(font_size)),
    buffer: None,
    explicit: false,
    requested_target: if !size.is_one() {
      Some(size)
    } else {
      None
    },
    short_fall,
    relative_to: None,
    font_size: None,
  }
}

///|
pub impl Default for StretchInfo with fn default() {
  let target = Rel::new(Ratio::one(), Abs::zero())
  StretchInfo::new(target, Em::zero())
}

///|
pub extend StretchInfo with Default::{default}

///|
/// Combines two stretch infos (upstream `MulAssign for StretchInfo`).
pub fn StretchInfo::mul(self : StretchInfo, rhs : StretchInfo) -> StretchInfo {
  let target = match self.buffer {
    Some(buffer) =>
      Rel::new(
        self.target.rel.mul_ratio(buffer.rel),
        buffer.rel.of(self.target.abs) + buffer.abs,
      )
    None => self.target
  }
  let requested_target = match rhs.requested_target {
    Some(requested) =>
      Some(
        match self.requested_target {
          None => requested
          Some(target) =>
            Rel::new(
              target.rel.mul_ratio(requested.rel),
              requested.rel.of(target.abs) + requested.abs,
            )
        },
      )
    None => self.requested_target
  }
  {
    ..self,
    target,
    buffer: Some(rhs.target),
    requested_target,
    explicit: self.explicit || rhs.explicit,
    short_fall: rhs.short_fall,
  }
}

///|
/// A marker representing the positioning of something above or below a base
/// (upstream `math::ir::Position`).
pub(all) enum MathPosition {
  /// Placed above the base.
  Above
  /// Placed below the base.
  Below
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathPosition with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathPosition with @debug.Debug::{to_repr}
