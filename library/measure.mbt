// Port of the native functions of `typst-library/src/layout/measure.rs` and
// `typst-library/src/layout/layout.rs`.

///|
/// Measures the layouted size of content.
fn impl_measure(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  width_ : Smart[Length],
  height_ : Smart[Length],
  content_ : Content,
) -> Dict raise SourceError {
  // Create a pod region with the available space.
  let styles = at(span, () => context.get_styles())
  let pod = LayoutRegion::new(
    Axes::new(
      match width_ {
        Custom(width) => width.resolve(styles)
        Auto => Abs::inf()
      },
      match height_ {
        Custom(height) => height.resolve(styles)
        Auto => Abs::inf()
      },
    ),
    Axes::splat(false),
  )

  // We put the locator into a special "measurement mode" to ensure that
  // introspection-driven features within the content continue to work. Read
  // the "Dealing with measurement" section of the [Locator] docs for more
  // details.
  let here = at(span, () => context.location())
  let link = LocatorLink::measure(here, span)
  let locator = Locator::link(link)
  let style = TargetElem::set_target(Paged)
  let frame = (engine.routines().layout_frame)(
    engine,
    content_,
    locator,
    styles.chain_one(style),
    pod,
  )
  let { x, y, } = frame.size()
  let dict = Dict::new()
  dict.insert("width", Length(Length::from_abs(x)))
  dict.insert("height", Length(Length::from_abs(y)))
  dict.insert("baseline", Length(Length::from_abs(frame.baseline())))
  dict
}

///|
/// Provides access to the current outer container's (or page's, if none)
/// dimensions (width and height).
fn impl_layout(span : @syntax.Span, func_ : Func) -> Content {
  LayoutElem::new(func_).pack().spanned(span)
}
