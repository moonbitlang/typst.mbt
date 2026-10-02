// Small pieces of `typst-library` used by the layout engine (`layout`
// package):
//
// - the content constructors of `foundations/content/mod.rs` (`strong`,
//   `emph`, `underlined`, `linked`, `aligned`, `padded`, `moved`,
//   `artifact`),
// - geometric helpers of `layout/{abs,axes,sides,corners}.rs` that the
//   ported types did not need so far,
// - the `Resolve` impls for alignments and the text direction.

// Content constructors (`foundations/content/mod.rs`).

///|
/// Strongly emphasize this content.
pub fn Content::strong(self : Content) -> Content {
  let span = self.span()
  StrongElem::new(self).pack().spanned(span)
}

///|
/// Emphasize this content.
pub fn Content::emph(self : Content) -> Content {
  let span = self.span()
  EmphElem::new(self).pack().spanned(span)
}

///|
/// Underline this content.
pub fn Content::underlined(self : Content) -> Content {
  let span = self.span()
  UnderlineElem::new(self).pack().spanned(span)
}

///|
/// Link the content somewhere.
pub fn Content::linked(
  self : Content,
  dest : Destination,
  alt : String?,
) -> Content {
  let span = self.span()
  LinkMarker::new(self, alt)
  .pack()
  .spanned(span)
  .styled(LinkElem::set_current(Some(dest)))
}

///|
/// Set alignments for this content.
pub fn Content::aligned(self : Content, align : Alignment) -> Content {
  self.styled(AlignElem::set_alignment(align))
}

///|
/// Pad this content at the sides.
pub fn Content::padded(self : Content, padding : Sides[Rel[Length]]) -> Content {
  let span = self.span()
  PadElem::new(self)
  .with_left(padding.left)
  .with_top(padding.top)
  .with_right(padding.right)
  .with_bottom(padding.bottom)
  .pack()
  .spanned(span)
}

///|
/// Transform this content's contents without affecting layout.
pub fn Content::moved(self : Content, delta : Axes[Rel[Length]]) -> Content {
  let span = self.span()
  MoveElem::new(self).with_dx(delta.x).with_dy(delta.y).pack().spanned(span)
}

///|
/// Mark content as a PDF artifact.
pub fn Content::artifact(self : Content, kind : ArtifactKind) -> Content {
  let span = self.span()
  ArtifactElem::new(self).with_kind(kind).pack().spanned(span)
}

// Absolute lengths (`layout/abs.rs`).

///|
/// Clamp the length between a minimum and a maximum (upstream `Ord::clamp`
/// of `Abs`).
///
/// Panics if `min > max`.
pub fn Abs::clamp(self : Abs, min : Abs, max : Abs) -> Abs {
  guard min.to_raw() <= max.to_raw() else { abort("min > max") }
  if self.to_raw() < min.to_raw() {
    min
  } else if self.to_raw() > max.to_raw() {
    max
  } else {
    self
  }
}

///|
/// The sum of the lengths (upstream `Sum for Abs`).
pub fn Abs::sum(iter : Iter[Abs]) -> Abs {
  iter.fold(init=Abs::zero(), (acc, x) => acc + x)
}

// Axes (`layout/axes.rs`).

///|
/// The component-wise minimum of this and another instance.
pub fn[T : Compare] Axes::min(self : Axes[T], other : Axes[T]) -> Axes[T] {
  { x: ord_min(self.x, other.x), y: ord_min(self.y, other.y), }
}

///|
/// The component-wise maximum of this and another instance.
pub fn[T : Compare] Axes::max(self : Axes[T], other : Axes[T]) -> Axes[T] {
  { x: ord_max(self.x, other.x), y: ord_max(self.y, other.y), }
}

///|
/// The minimum of width and height.
pub fn[T : Compare] Axes::min_by_side(self : Axes[T]) -> T {
  ord_min(self.x, self.y)
}

///|
/// The maximum of width and height.
pub fn[T : Compare] Axes::max_by_side(self : Axes[T]) -> T {
  ord_max(self.x, self.y)
}

///|
/// Upstream `Ord::min`: the first value on ties.
fn[T : Compare] ord_min(a : T, b : T) -> T {
  if a.compare(b) <= 0 {
    a
  } else {
    b
  }
}

///|
/// Upstream `Ord::max`: the second value on ties.
fn[T : Compare] ord_max(a : T, b : T) -> T {
  if a.compare(b) > 0 {
    a
  } else {
    b
  }
}

///|
/// Returns the component for the specified axis with it replaced by `v`
/// (upstream `Axes::set`, which mutates in place).
pub fn[T] Axes::with_axis_value(self : Axes[T], axis : Axis, v : T) -> Axes[T] {
  match axis {
    X => { x: v, y: self.y, }
    Y => { x: self.x, y: v, }
  }
}

///|
/// Select `t.x` if `self.x` is true and `f.x` otherwise, same for `y`.
pub fn[T] Axes::select(self : Axes[Bool], t : Axes[T], f : Axes[T]) -> Axes[T] {
  { x: if self.x { t.x } else { f.x }, y: if self.y { t.y } else { f.y }, }
}

///|
/// Component-wise `|` (upstream `BitOr for Axes<bool>`).
pub fn Axes::bitor(self : Axes[Bool], rhs : Axes[Bool]) -> Axes[Bool] {
  { x: self.x || rhs.x, y: self.y || rhs.y, }
}

///|
/// Component-wise `&` (upstream `BitAnd for Axes<bool>`).
pub fn Axes::bitand(self : Axes[Bool], rhs : Axes[Bool]) -> Axes[Bool] {
  { x: self.x && rhs.x, y: self.y && rhs.y, }
}

///|
/// Evaluate the axes relative to the given `size`.
pub fn Axes::relative_to(self : Axes[Rel[Abs]], size : Axes[Abs]) -> Axes[Abs] {
  { x: self.x.relative_to(size.x), y: self.y.relative_to(size.y), }
}

// Sides (`layout/sides.rs`).

///|
/// Sums up `left` and `right` into `x`, and `top` and `bottom` into `y`.
pub fn[T : Add] Sides::sum_by_axis(self : Sides[T]) -> Axes[T] {
  { x: self.left + self.right, y: self.top + self.bottom, }
}

///|
/// Whether all sides are zero.
pub fn[T : Numeric] Sides::is_zero(self : Sides[T]) -> Bool {
  self.left == T::zero() &&
  self.top == T::zero() &&
  self.right == T::zero() &&
  self.bottom == T::zero()
}

///|
/// Set a specific side to a value (upstream `Sides::with`).
pub fn[T] Sides::with_side(self : Sides[T], side : Side, value : T) -> Sides[T] {
  match side {
    Left => { ..self, left: value, }
    Top => { ..self, top: value, }
    Right => { ..self, right: value, }
    Bottom => { ..self, bottom: value, }
  }
}

///|
/// Evaluate the sides relative to the given `size`.
pub fn Sides::relative_to(
  self : Sides[Rel[Abs]],
  size : Axes[Abs],
) -> Sides[Abs] {
  {
    left: self.left.relative_to(size.x),
    top: self.top.relative_to(size.y),
    right: self.right.relative_to(size.x),
    bottom: self.bottom.relative_to(size.y),
  }
}

// Resolving (`Resolve` impls of alignments and the text direction).

///|
/// Upstream `styles.resolve(TextElem::dir)`: the explicit direction or the
/// one of the current language.
pub fn TextDir::resolve(self : TextDir, styles : StyleChain) -> Dir {
  match self.0 {
    Auto => TextElem::lang_in(styles).dir()
    Custom(dir) => dir
  }
}

///|
/// Upstream `Resolve for Alignment`.
pub fn Alignment::resolve(
  self : Alignment,
  styles : StyleChain,
) -> Axes[FixedAlignment] {
  self.fix(TextElem::dir_in(styles).resolve(styles))
}

///|
/// Upstream `Resolve for HAlignment`.
pub fn HAlignment::resolve(
  self : HAlignment,
  styles : StyleChain,
) -> FixedAlignment {
  self.fix(TextElem::dir_in(styles).resolve(styles))
}

///|
/// Upstream `Resolve for OuterHAlignment`.
pub fn OuterHAlignment::resolve(
  self : OuterHAlignment,
  styles : StyleChain,
) -> FixedAlignment {
  self.fix(TextElem::dir_in(styles).resolve(styles))
}

///|
/// Upstream `Resolve for VAlignment`.
pub fn VAlignment::resolve(
  self : VAlignment,
  styles : StyleChain,
) -> FixedAlignment {
  self.fix(TextElem::dir_in(styles).resolve(styles))
}

///|
/// Upstream `Resolve for Rel<Length>`.
pub fn Rel::resolve(self : Rel[Length], styles : StyleChain) -> Rel[Abs] {
  self.map(length => length.resolve(styles))
}

///|
/// Updates the value of the counter (upstream `Counter::update`).
pub fn Counter::update(
  self : Counter,
  span : @syntax.Span,
  update : CounterUpdate,
) -> Content {
  Content::new(counter_update_elem(), [
    (counter_update_elem_key, self.0.into_value()),
    (counter_update_elem_update, update.into_value()),
  ]).spanned(span)
}

///|
/// A specialized handler of the page counter that tracks both the physical
/// and the logical page counter (upstream `ManualPageCounter`,
/// `introspection/counter.rs`).
pub struct ManualPageCounter {
  priv mut physical : Int
  priv mut logical : Int64
}

///|
/// Create a new fast page counter, starting at 1.
pub fn ManualPageCounter::new() -> ManualPageCounter {
  { physical: 1, logical: 1L, }
}

///|
/// Get the current physical page counter state.
pub fn ManualPageCounter::physical(self : ManualPageCounter) -> Int {
  self.physical
}

///|
/// Get the current logical page counter state.
pub fn ManualPageCounter::logical(self : ManualPageCounter) -> Int64 {
  self.logical
}

///|
/// Advance past a page.
pub fn ManualPageCounter::visit(
  self : ManualPageCounter,
  engine : Engine,
  page : Frame,
) -> Unit raise SourceError {
  for entry in page.items() {
    match entry.1 {
      Group(group) => self.visit(engine, group.frame)
      Tag(Start(elem, _)) => {
        guard CounterUpdateElem::of(elem) is Some(elem) else { continue }
        if elem.key() == CounterKey::Page {
          let state = CounterState([self.logical])
          state.update(engine, elem.update())
          self.logical = state.first()
        }
      }
      _ => ()
    }
  }
}

///|
/// Step past a page _boundary._
pub fn ManualPageCounter::step(self : ManualPageCounter) -> Unit {
  self.physical = self.physical + 1
  self.logical = self.logical + 1L
}

// Links (`model/link.rs`).

///|
/// The alternative text of a link destination (upstream
/// `Destination::alt_text`).
pub fn Destination::alt_text(
  self : Destination,
  engine : Engine,
  styles : StyleChain,
  span : @syntax.Span,
) -> String raise SourceError {
  match self {
    Url(url) => {
      let contact = url
        .strip_contact_scheme()
        .map(pair => {
          let (scheme, stripped) = pair
          let key = match scheme {
            Mailto => "email"
            Tel => "telephone"
          }
          let lang = TextElem::lang_in(styles).as_str()
          let region = TextElem::region_in(styles).map(r => r.as_str())
          "\{localized_str(lang, region, key)} \{stripped}"
        })
      contact.unwrap_or(url.into_inner())
    }
    Position(pos) => {
      let page_nr = pos.page.0.to_string()
      let page_str = page_elem().local_name_in(styles)
      "\{page_str} \{page_nr}"
    }
    Location(loc) => {
      let fallback = (engine : Engine) => {
        // Fall back to a generating a page reference.
        let numbering = match loc.page_numbering(engine, span) {
          Some(numbering) => numbering
          None =>
            Pattern(
              NumberingPattern::from_str("1") catch {
                _ => abort("unreachable")
              },
            )
        }
        let page_nr = Counter::new(Page)
          .display_at(engine, loc, styles, numbering, span)
          .plain_text()
        let page_str = page_elem().local_name_in(styles)
        "\{page_str} \{page_nr}"
      }

      // Try to generate more meaningful alt text if the location is a
      // refable element.
      if engine.introspect(query_first_introspection(Location(loc), span))
        is Some(elem) &&
        OutlinableElem::of(elem) is Some(refable) {
        let counter = refable.counter()
        let supplement = refable.supplement().plain_text()
        if refable.numbering() is Some(numbering) {
          let numbers = counter.display_at(
            engine,
            loc,
            styles,
            numbering.trimmed(),
            span,
          )
          return "\{supplement} \{numbers.plain_text()}"
        } else {
          let page_ref = fallback(engine)
          return "\{supplement}, \{page_ref}"
        }
      }
      fallback(engine)
    }
  }
}

// Outline entries (`model/outline.rs`).

///|
/// The page number of this entry's element, formatted with the numbering
/// set for the referenced page (upstream `OutlineEntry::page`).
pub fn OutlineEntry::page(
  self : OutlineEntry,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content raise SourceError {
  impl_outline_entry_page(self, engine, context, span)
}

///|
/// A helper function for producing an indented entry layout: Lays out a
/// prefix and the rest of the entry in an indent-aware way (upstream
/// `OutlineEntry::indented`).
pub fn OutlineEntry::indented(
  self : OutlineEntry,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  prefix : Content?,
  inner : Content,
  gap : Length,
) -> Content raise SourceError {
  impl_outline_entry_indented(self, engine, context, span, prefix, inner, gap)
}
