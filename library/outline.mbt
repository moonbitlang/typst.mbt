// Port of the castable value types of `typst-library/src/model/outline.rs`
// (`OutlineIndent`) and the `OutlineEntry` field defaults.

///|
/// Defines how an outline is indented.
pub(all) enum OutlineIndent {
  /// Indents by the specified length per level.
  Rel(Rel[Length])
  /// Resolve the indent for a specific level through the given function.
  Func(Func)
} derive(Eq)

///|
pub impl Reflect for OutlineIndent with fn input() {
  CastInfo::Type(Type::relative()).union_with(Type(Type::func()))
}

///|
pub impl Reflect for OutlineIndent with fn output() {
  OutlineIndent::input()
}

///|
pub impl Reflect for OutlineIndent with fn castable(v) {
  v is (Relative(_) | Length(_) | Ratio(_)) || Func::castable(v)
}

///|
pub impl IntoValue for OutlineIndent with fn into_value(self) {
  match self {
    Rel(v) => Relative(v)
    Func(v) => Func(v)
  }
}

///|
pub impl FromValue for OutlineIndent with fn from_value(v) {
  match v {
    Relative(_) | Length(_) | Ratio(_) => Rel(FromValue::from_value(v))
    v if Func::castable(v) => Func(Func::from_value(v))
    v => raise HintedError(OutlineIndent::input().error(v))
  }
}

///|
/// Upstream `Some(RepeatElem::new(TextElem::packed("."))
/// .with_gap(Em::new(0.15).into()).pack())`.
fn outline_entry_elem_fill_default() -> Value {
  Content(
    Content::new(repeat_elem(), [
      (repeat_elem_body, Content(TextElem::packed("."))),
    ]).with_field(repeat_elem_gap, Length(Length::from_em(Em::new(0.15)))),
  )
}

///|
/// Resolve the indent for an entry with the given level.
fn OutlineIndent::resolve(
  self : OutlineIndent,
  engine : Engine,
  context : Context,
  level : NonZeroUSize,
  span : @syntax.Span,
) -> Rel[Length] raise SourceError {
  let depth = level.0 - 1L
  match self {
    Rel(length) => length.times(depth.to_double())
    Func(func) => {
      let value = func.call(
        engine,
        context,
        Args::new(func.span(), [Int(depth)]),
      )
      at(span, () => value.cast())
    }
  }
}

///|
/// Produces the heading for the outline, if any.
pub fn OutlineElem::realize_title(
  self : OutlineElem,
  styles : StyleChain,
) -> Content? {
  let span = self.0.span()
  let title = match self.title(styles) {
    Custom(title) => title
    Auto =>
      Some(TextElem::packed(outline_elem().local_name_in(styles)).spanned(span))
  }
  title.map(title => {
    HeadingElem::new(title).with_depth(NonZeroUSize(1)).pack().spanned(span)
  })
}

///|
/// Realizes the entries in a flat fashion.
pub fn OutlineElem::realize_flat(
  self : OutlineElem,
  engine : Engine,
  styles : StyleChain,
) -> Array[OutlineEntry] raise SourceError {
  let entries = []
  for item in self.realize_iter(engine, styles) {
    let (entry, _, included) = item
    if included {
      entries.push(entry)
    }
  }
  entries
}

///|
/// Realizes the entries in a tree fashion.
pub fn OutlineElem::realize_tree(
  self : OutlineElem,
  engine : Engine,
  styles : StyleChain,
) -> Array[OutlineNode[OutlineEntry]] raise SourceError {
  let flat = self.realize_iter(engine, styles)
  OutlineNode::build_tree(flat)
}

///|
/// Realizes the entries (upstream: as a lazy iterator; here eagerly, which
/// is equivalent since every caller consumes all of them and stops at the
/// first error).
fn OutlineElem::realize_iter(
  self : OutlineElem,
  engine : Engine,
  styles : StyleChain,
) -> Array[(OutlineEntry, NonZeroUSize, Bool)] raise SourceError {
  let span = self.0.span()
  let elems = engine.introspect(
    query_introspection(self.target(styles).0, span),
  )
  let depth = match self.depth(styles) {
    Some(depth) => depth
    None => NonZeroUSize(@int64.MAX_VALUE)
  }
  let out = []
  for elem in elems {
    guard OutlinableElem::of(elem) is Some(outlinable) else {
      bail_at(self.0.span(), "cannot outline \{elem.elem().name()}")
    }
    let level = outlinable.level()
    let include = outlinable.outlined() && level <= depth
    let entry = OutlineEntry(
      OutlineEntry::new(level, elem).pack().spanned(span),
    )
    out.push((entry, level, include))
  }
  out
}

///|
/// A node in a tree of outline entry.
pub(all) struct OutlineNode[T] {
  /// The entry itself.
  entry : T
  /// The entry's level.
  level : NonZeroUSize
  /// Its descendants.
  children : Array[OutlineNode[T]]
}

///|
/// Turns a flat list of entries into a tree.
///
/// Each entry in the iterator should be accompanied by
/// - a level
/// - a boolean indicating whether it is included (`true`) or skipped (`false`)
pub fn[T] OutlineNode::build_tree(
  flat : ArrayView[(T, NonZeroUSize, Bool)],
) -> Array[OutlineNode[T]] {
  // Stores the level of the topmost skipped ancestor of the next included
  // heading.
  let mut last_skipped_level : NonZeroUSize? = None
  let tree : Array[OutlineNode[T]] = []
  for item in flat {
    let (entry, level, include) = item
    if include {
      let mut children = tree

      // Descend the tree through the latest included heading of each level
      // until either:
      // - reaching a node whose children would be siblings of this heading
      //   (=> add the current heading as a child of this node)
      // - reaching a node with no children (=> this heading probably skipped
      //   a few nesting levels in Typst, or one or more ancestors of this
      //   heading weren't included, so add it as a child of this node, which
      //   is its deepest included ancestor)
      // - or, if the latest heading(s) was(/were) skipped, then stop if
      //   reaching a node whose children would be siblings of the latest
      //   skipped heading of lowest level (=> those skipped headings would be
      //   ancestors of the current heading, so add it as a sibling of the
      //   least deep skipped ancestor among them, as those ancestors weren't
      //   added to the tree, and the current heading should not be mistakenly
      //   added as a descendant of a siblibg of that ancestor.)
      //
      // That is, if you had an included heading of level N, a skipped heading
      // of level N, a skipped heading of level N + 1, and then an included
      // heading of level N + 2, that last one is included as a level N
      // heading (taking the place of its topmost skipped ancestor), so that it
      // is not mistakenly added as a descendant of the previous level N
      // heading.
      while children.last() is Some(last) &&
            (match last_skipped_level {
              None => true
              Some(l) => last.level < l
            }) &&
            last.level < level {
        children = last.children
      }

      // Since this heading was bookmarked, the next heading (if it is a
      // child of this one) won't have a skipped direct ancestor.
      last_skipped_level = None
      children.push({ entry, level, children: [], })
    } else if (match last_skipped_level {
        None => true
        Some(l) => level < l
      }) {
      // Only the topmost / lowest-level skipped heading matters when we have
      // consecutive skipped headings, hence the condition above.
      last_skipped_level = Some(level)
    }
  }
  tree
}

// Outlinable (`trait Outlinable: Refable`), dispatched over the elements
// implementing it.

///|
/// An element that can be outlined (upstream `dyn Outlinable`).
priv enum OutlinableElem {
  Heading(HeadingElem)
  Figure(FigureElem)
  Equation(EquationElem)
}

///|
/// Upstream `content.with::<dyn Outlinable>()`.
fn OutlinableElem::of(content : Content) -> OutlinableElem? {
  if HeadingElem::of(content) is Some(elem) {
    Some(Heading(elem))
  } else if FigureElem::of(content) is Some(elem) {
    Some(Figure(elem))
  } else if EquationElem::of(content) is Some(elem) {
    Some(Equation(elem))
  } else {
    None
  }
}

///|
/// Upstream `Refable::supplement`.
fn OutlinableElem::supplement(self : OutlinableElem) -> Content {
  // After synthesis, this should always be custom content.
  let supplement = match self {
    Heading(elem) => elem.supplement(StyleChain::empty())
    Figure(elem) => elem.supplement(StyleChain::empty())
    Equation(elem) => elem.supplement(StyleChain::empty())
  }
  match supplement {
    Custom(Some(Content(content))) => content
    _ => Content::empty()
  }
}

///|
/// Upstream `Refable::counter`.
fn OutlinableElem::counter(self : OutlinableElem) -> Counter {
  match self {
    Heading(_) => Counter::of(heading_elem())
    Figure(elem) =>
      match elem.counter() {
        Some(Some(counter)) => counter
        _ => Counter::of(figure_elem())
      }
    Equation(_) => Counter::of(equation_elem())
  }
}

///|
/// Upstream `Refable::numbering`.
fn OutlinableElem::numbering(self : OutlinableElem) -> Numbering? {
  match self {
    Heading(elem) => elem.numbering(StyleChain::empty())
    Figure(elem) => elem.numbering(StyleChain::empty())
    Equation(elem) => elem.numbering(StyleChain::empty())
  }
}

///|
/// Upstream `Outlinable::outlined`: whether this element should be included
/// in the outline.
fn OutlinableElem::outlined(self : OutlinableElem) -> Bool {
  let styles = StyleChain::empty()
  match self {
    Heading(elem) => elem.outlined(styles)
    Figure(elem) =>
      elem.outlined(styles) &&
      (elem.caption(styles) is Some(_) || self.numbering() is Some(_))
    Equation(elem) => elem.block(styles) && self.numbering() is Some(_)
  }
}

///|
/// Upstream `Outlinable::level`: the nesting level of this element.
fn OutlinableElem::level(self : OutlinableElem) -> NonZeroUSize {
  match self {
    Heading(elem) => elem.resolve_level(StyleChain::empty())
    Figure(_) | Equation(_) => NonZeroUSize(1)
  }
}

///|
/// Upstream `Outlinable::prefix`.
fn OutlinableElem::prefix(self : OutlinableElem, numbers : Content) -> Content {
  match self {
    Heading(_) => numbers
    Figure(_) | Equation(_) => {
      let supplement = self.supplement()
      if !supplement.is_empty() {
        supplement.add(TextElem::packed("\u{a0}")).add(numbers)
      } else {
        numbers
      }
    }
  }
}

///|
/// Upstream `Outlinable::body`.
fn OutlinableElem::body(self : OutlinableElem) -> Content {
  match self {
    Heading(elem) => elem.body()
    Figure(elem) =>
      match elem.caption(StyleChain::empty()) {
        Some(caption) => caption.body()
        None => Content::empty()
      }
    Equation(_) => Content::empty()
  }
}

// OutlineEntry methods.

///|
fn impl_outline_entry_indented__gap_default() -> Length raise SourceError {
  Length::from_em(Em::new(0.5))
}

///|
/// A helper function for producing an indented entry layout: Lays out a
/// prefix and the rest of the entry in an indent-aware way.
fn impl_outline_entry_indented(
  self_ : OutlineEntry,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  prefix_ : Content?,
  inner_ : Content,
  gap_ : Length,
) -> Content raise SourceError {
  let styles = at(span, () => context.get_styles())
  let outline = match OutlineEntry::parent_in(styles) {
    Some(outline) => outline
    None => bail_at(span, "must be called within the context of an outline")
  }
  let outline_loc = outline.0.location().unwrap()
  let prefix_width = match prefix_ {
    Some(prefix) =>
      Some(measure_prefix(engine, prefix, outline_loc, styles, span))
    None => None
  }
  let prefix_inset = prefix_width.map(w => w + gap_.resolve(styles))
  let indent = outline.indent(styles)
  let level = self_.level()
  let (base_indent, hanging_indent) = match indent {
    Auto =>
      compute_auto_indents(
        engine, outline_loc, styles, level, prefix_inset, span,
      )
    Custom(amount) => {
      let base = amount.resolve(engine, context, level, span)
      (base, prefix_inset)
    }
  }
  let body = match (prefix_, prefix_width, prefix_inset, hanging_indent) {
    (Some(prefix), Some(prefix_width), Some(prefix_inset), Some(hanging_indent)) => {
      // Save information about our prefix that other outline entries can
      // query for (within `compute_auto_indent`) to align themselves).
      let seq = []
      if indent.is_auto() {
        seq.push(PrefixInfo::new(outline_loc, level, prefix_inset).pack())
      }

      // Dedent the prefix by the amount of hanging indent and then skip ahead
      // so that the inner contents are aligned.
      seq.push(
        HElem::new(Rel(Rel::from_abs(Length::from_abs(-hanging_indent)))).pack(),
      )
      seq.push(pdf_marker_tag(Label, prefix))
      seq.push(
        HElem::new(
          Rel(Rel::from_abs(Length::from_abs(hanging_indent - prefix_width))),
        ).pack(),
      )
      seq.push(inner_)
      Content::sequence(seq)
    }
    _ => inner_
  }
  let start = resolve_text_dir(styles).start()
  let value : Rel[Length] = base_indent +
    Rel::from_abs(Length::from_abs(hanging_indent.unwrap_or(Abs::zero())))
  let inset : Sides[Rel[Length]?] = {
    left: if start == Left {
      Some(value)
    } else {
      None
    },
    top: if start == Top {
      Some(value)
    } else {
      None
    },
    right: if start == Right {
      Some(value)
    } else {
      None
    },
    bottom: if start == Bottom {
      Some(value)
    } else {
      None
    },
  }
  BlockElem::new()
  .with_inset(inset)
  .with_body(Some(BlockBody::Content(body)))
  .pack()
  .spanned(span)
}

///|
/// Formats the element's numbering (if any).
fn impl_outline_entry_prefix(
  self_ : OutlineEntry,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content? raise SourceError {
  let outlinable = at(span, () => self_.outlinable())
  guard outlinable.numbering() is Some(numbering) else { return None }
  let loc = at(span, () => self_.element_location())
  let styles = at(span, () => context.get_styles())
  let numbers = outlinable
    .counter()
    .display_at(engine, loc, styles, numbering, span)
  Some(outlinable.prefix(numbers))
}

///|
/// Formats the element's numbering (if any).
pub fn OutlineEntry::prefix(
  self : OutlineEntry,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content? raise SourceError {
  impl_outline_entry_prefix(self, engine, context, span)
}

///|
/// The content which is displayed in place of the referred element at its
/// entry in the outline.
pub fn OutlineEntry::body(self : OutlineEntry) -> Content raise HintedError {
  impl_outline_entry_body(self)
}

///|
/// Creates the default inner content of the entry.
fn impl_outline_entry_inner(
  self_ : OutlineEntry,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content raise SourceError {
  let body = at(span, () => impl_outline_entry_body(self_))
  let page = impl_outline_entry_page(self_, engine, context, span)
  self_.build_inner(context, span, body, page)
}

///|
/// The content which is displayed in place of the referred element at its
/// entry in the outline.
fn impl_outline_entry_body(self_ : OutlineEntry) -> Content raise HintedError {
  self_.outlinable().body()
}

///|
/// The page number of this entry's element, formatted with the numbering
/// set for the referenced page.
fn impl_outline_entry_page(
  self_ : OutlineEntry,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content raise SourceError {
  let loc = at(span, () => self_.element_location())
  let styles = at(span, () => context.get_styles())
  let numbering = match
    engine.introspect(page_numbering_introspection(loc, span)) {
    Some(numbering) => numbering
    None =>
      Pattern(
        NumberingPattern::from_str("1") catch {
          _ => abort("unreachable")
        },
      )
  }
  Counter::new(Page).display_at(engine, loc, styles, numbering, span)
}

///|
/// Builds the inner content of an entry (upstream
/// `OutlineEntry::build_inner`).
pub fn OutlineEntry::build_inner(
  self : OutlineEntry,
  context : Context,
  span : @syntax.Span,
  body : Content,
  page : Content,
) -> Content raise SourceError {
  let styles = at(span, () => context.get_styles())
  let seq = []

  // Isolate the entry body in RTL because the page number is typically LTR.
  // I'm not sure whether LTR should conceptually also be isolated, but in any
  // case we don't do it for now because the text shaping pipeline does tend
  // to choke a bit on default ignorables (in particular the CJK-Latin
  // spacing).
  //
  // See also:
  // - https://github.com/typst/typst/issues/4476
  // - https://github.com/typst/typst/issues/5176
  let rtl = resolve_text_dir(styles) == RTL
  if rtl {
    // "Right-to-Left Embedding"
    seq.push(TextElem::packed("\u{202B}"))
  }
  seq.push(body)
  if rtl {
    // "Pop Directional Formatting"
    seq.push(TextElem::packed("\u{202C}"))
  }

  // Add the filler between the section name and page number.
  match self.fill(styles) {
    Some(filler) => {
      seq.push(SpaceElem::shared())
      seq.push(
        BoxElem::new()
        .with_body(Some(filler))
        .with_width(Fr(Fr::one()))
        .pack()
        .spanned(span),
      )
      seq.push(SpaceElem::shared())
    }
    None => seq.push(HElem::new(Fr(Fr::one())).pack().spanned(span))
  }

  // Add the page number. The word joiner in front ensures that the page
  // number doesn't stand alone in its line.
  seq.push(TextElem::packed("\u{2060}"))
  seq.push(page)
  Content::sequence(seq)
}

///|
fn OutlineEntry::outlinable(
  self : OutlineEntry,
) -> OutlinableElem raise HintedError {
  let element = self.element()
  match OutlinableElem::of(element) {
    Some(outlinable) => outlinable
    None => bail("cannot outline \{element.elem().name()}")
  }
}

///|
/// Returns the location of the outlined element.
pub fn OutlineEntry::element_location(
  self : OutlineEntry,
) -> Location raise HintedError {
  let elem = self.element()
  match elem.location() {
    Some(loc) => loc
    None =>
      if OutlinableElem::of(elem) is Some(_) {
        bail_hinted("\{elem.elem().name()} must have a location", [
          "try using a show rule to customize the outline.entry instead",
        ])
      } else {
        bail("cannot outline \{elem.elem().name()}")
      }
  }
}

///|
/// Upstream `styles.resolve(TextElem::dir)`.
fn resolve_text_dir(styles : StyleChain) -> Dir {
  match TextElem::dir_in(styles).0 {
    Auto => TextElem::lang_in(styles).dir()
    Custom(dir) => dir
  }
}

///|
fn measure_prefix(
  engine : Engine,
  prefix : Content,
  loc : Location,
  styles : StyleChain,
  span : @syntax.Span,
) -> Abs raise SourceError {
  let pod = LayoutRegion::new(Axes::splat(Abs::inf()), Axes::splat(false))
  let link = LocatorLink::measure(loc, span)
  (engine.routines().layout_frame)(
    engine,
    prefix,
    Locator::link(link),
    styles,
    pod,
  ).size().x
}

///|
/// Compute the base indent and hanging indent for an auto-indented outline
/// entry of the given level, with the given prefix inset.
fn compute_auto_indents(
  engine : Engine,
  outline_loc : Location,
  styles : StyleChain,
  level : NonZeroUSize,
  prefix_inset : Abs?,
  span : @syntax.Span,
) -> (Rel[Length], Abs?) {
  let elems = engine.introspect(
    query_introspection(
      prefix_info_elem().where_([
        (prefix_info_elem_key, Dyn(Location(outline_loc))),
      ]),
      span,
    ),
  )
  let indents = determine_prefix_widths(elems)
  let fallback = Em::new(1.2).resolve(styles)
  let get = (i : Int) => {
    if i < indents.length() && indents[i] is Some(v) {
      v
    } else {
      fallback
    }
  }
  let last = level.0.to_int() - 1
  let mut base = Abs::zero()
  for i in 0..<last {
    base = base + get(i)
  }
  let hang = prefix_inset.map(p => p.max(get(last)))
  (Rel::from_abs(Length::from_abs(base)), hang)
}

///|
/// Determines the maximum prefix inset (prefix width + gap) at each outline
/// level, for the outline with the given `loc`. Levels for which there is no
/// information available yield `None`.
fn determine_prefix_widths(elems : Array[Content]) -> Array[Abs?] {
  let widths : Array[Abs?] = []
  for elem in elems {
    let info = PrefixInfo::of(elem).unwrap()
    let level = info.level().0.to_int()
    while widths.length() < level {
      widths.push(None)
    }
    widths[level - 1] = Some(
      match widths[level - 1] {
        Some(w) => w.max(info.inset())
        None => info.inset()
      },
    )
  }
  widths
}

///|
/// Upstream `ShowSet for Packed<OutlineElem>`.
fn outline_elem_show_set(content : Content, styles : StyleChain) -> Styles {
  let out = Styles::new()
  out.push(HeadingElem::set_outlined(false))
  out.push(HeadingElem::set_numbering(None))
  out.push(ParElem::set_justify(false))
  out.push(
    BlockElem::set_above(
      Custom(Spacing::from_length(ParElem::leading_in(styles))),
    ),
  )
  // Makes the outline itself available to its entries. Should be
  // superseded by a proper ancestry mechanism in the future.
  out.push(OutlineEntry::set_parent(Some(OutlineElem(content))))
  out
}

///|
/// Upstream `LocalName for Packed<OutlineElem>`.
fn outline_elem_local_name_key() -> String {
  "outline"
}
