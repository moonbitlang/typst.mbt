// Port of `typst-layout/src/inline/mod.rs`.

///|
/// Layouts the paragraph.
pub fn layout_par(
  elem : @library.ParElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.Axes[@library.Abs],
  expand : Bool,
  situation : ParSituation,
) -> @library.Fragment raise @library.SourceError {
  if !@library.layout_memo_active() {
    return layout_par_impl(
      elem, engine, locator, styles, region, expand, situation,
    )
  }
  // Upstream memoizes `layout_par_impl` with comemo (see
  // `library/memo.mbt`).
  let key = @library.memo_fingerprint(state => {
    state.write_str("layout_par")
    state.write(elem.0)
    state.write_u128(styles.memo_hash())
    state.write_f64(region.x.to_raw())
    state.write_f64(region.y.to_raw())
    state.write_bool(expand)
    state.write_discriminant(
      match situation {
        First => 0
        Consecutive => 1
        Other => 2
      },
    )
    state.write_u128(locator.memo_hash())
    state.write_u128(engine.route.memo_hash())
  })
  @library.memoized_layout(engine, key, elem.0, styles, None, engine => {
    layout_par_impl(elem, engine, locator, styles, region, expand, situation)
  })
}

///|
/// The internal, memoized implementation of `layout_par`.
fn layout_par_impl(
  elem : @library.ParElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.Axes[@library.Abs],
  expand : Bool,
  situation : ParSituation,
) -> @library.Fragment raise @library.SourceError {
  let link = @library.LocatorLink::new(locator)
  let locator = @library.Locator::link(link).split()
  let engine = engine.with_route(@library.Route::extend_(engine.route))
  let children = (engine.library.routines.realize)(
    Par,
    engine,
    locator,
    elem.body(),
    styles,
  )
  layout_inline_impl(
    engine,
    children[:],
    locator,
    styles,
    region,
    expand,
    Some(situation),
    {
      justify: elem.justify(styles),
      linebreaks: elem.linebreaks(styles),
      first_line_indent: elem.first_line_indent(styles),
      hanging_indent: elem.hanging_indent(styles).resolve(styles),
    },
  )
}

///|
/// Lays out realized content with inline layout.
pub fn layout_inline(
  engine : @library.Engine,
  children : ArrayView[@library.Pair],
  locator : @library.SplitLocator,
  shared : @library.StyleChain,
  region : @library.Axes[@library.Abs],
  expand : Bool,
) -> @library.Fragment raise @library.SourceError {
  layout_inline_impl(engine, children, locator, shared, region, expand, None, {
    justify: @library.ParElem::justify_in(shared),
    linebreaks: @library.ParElem::linebreaks_in(shared),
    first_line_indent: @library.ParElem::first_line_indent_in(shared),
    hanging_indent: @library.ParElem::hanging_indent_in(shared).resolve(shared),
  })
}

///|
/// The internal implementation of [`layout_inline`].
fn layout_inline_impl(
  engine : @library.Engine,
  children : ArrayView[@library.Pair],
  locator : @library.SplitLocator,
  shared : @library.StyleChain,
  region : @library.Axes[@library.Abs],
  expand : Bool,
  par : ParSituation?,
  base : ConfigBase,
) -> @library.Fragment raise @library.SourceError {
  // Prepare configuration that is shared across the whole inline layout.
  let config = inline_configuration(base, children, shared, par)

  // Collect all text into one string for BiDi analysis.
  let (text, segments, spans) = collect_inline(
    children, engine, locator, config, region,
  )
  let text = Utf8Str::new(text).full()

  // Perform BiDi analysis and performs some preparation steps before we
  // proceed to line breaking.
  let p = prepare(engine, config, text, segments, spans)

  // Break the text into lines.
  let lines = linebreak(engine, p, region.x - config.hanging_indent)

  // Turn the selected lines into frames.
  finalize(engine, p, lines, region, expand, locator)
}

///|
/// Determine the inline layout's configuration.
fn inline_configuration(
  base : ConfigBase,
  children : ArrayView[@library.Pair],
  shared : @library.StyleChain,
  situation : ParSituation?,
) -> InlineConfig {
  let justify = base.justify
  let font_size = @library.TextElem::size_in(shared).resolve(shared)
  let dir = @library.TextElem::dir_in(shared).resolve(shared)
  {
    justify,
    justification_limits: @library.ParElem::justification_limits_in(shared),
    linebreaks: match base.linebreaks {
      Custom(v) => v
      Auto => if justify { Optimized } else { Simple }
    },
    first_line_indent: {
      let amount = base.first_line_indent.amount()
      let all = base.first_line_indent.all()
      if !amount.is_zero() &&
        (match situation {
          // First-line indent for the first paragraph after a list bullet
          // just looks bad.
          Some(First) => all && !in_list(shared)
          Some(Consecutive) => true
          Some(Other) => all
          None => false
        }) &&
        @library.AlignElem::alignment_in(shared).resolve(shared).x ==
        @library.FixedAlignment::from_side(dir.start()) {
        amount.at(font_size)
      } else {
        @library.Abs::zero()
      }
    },
    hanging_indent: if situation is Some(_) {
      base.hanging_indent
    } else {
      @library.Abs::zero()
    },
    numbering_marker: @library.ParLine::numbering_in(shared).map(numbering => {
      @library.ParLineMarker::new(
        numbering,
        @library.ParLine::number_align_in(shared),
        @library.ParLine::number_margin_in(shared),
        // Delay resolving the number clearance until line numbers are laid
        // out to avoid inconsistent spacing depending on varying font size.
        @library.ParLine::number_clearance_in(shared),
      ).pack()
    }),
    align: @library.AlignElem::alignment_in(shared).fix(dir).x,
    font_size,
    dir,
    hyphenate: shared_get(children, shared, s => {
      @library.TextElem::hyphenate_in(s)
    }).map(uniform => {
      match uniform {
        Custom(v) => v
        Auto => justify
      }
    }),
    lang: shared_get(children, shared, s => @library.TextElem::lang_in(s)),
    fallback: @library.TextElem::fallback_in(shared),
    cjk_latin_spacing: @library.TextElem::cjk_latin_spacing_in(shared).is_auto(),
    costs: @library.TextElem::costs_in(shared),
  }
}

///|
/// Distinguishes between a few different kinds of paragraphs.
///
/// In the form `Option<ParSituation>`, `None` implies that we are creating
/// an inline layout that isn't a semantic paragraph.
pub(all) enum ParSituation {
  /// The paragraph is the first child in the flow (i.e. in the container or
  /// page run) or right after a column break. For such paragraphs, we may
  /// want to avoid applying first line indent (depending on configuration).
  First
  /// The paragraph follows another paragraph.
  Consecutive
  /// Any other kind of paragraph.
  Other
} derive(Eq, Hash, Debug)

///|
/// Raw values from a `ParElem` or style chain. Used to initialize a
/// [`InlineConfig`].
priv struct ConfigBase {
  justify : Bool
  linebreaks : @library.Smart[@library.Linebreaks]
  first_line_indent : @library.FirstLineIndent
  hanging_indent : @library.Abs
}

///|
/// Shared configuration for the whole inline layout.
priv struct InlineConfig {
  /// Whether to justify text.
  justify : Bool
  /// Settings for justification.
  justification_limits : @library.JustificationLimits
  /// How to determine line breaks.
  linebreaks : @library.Linebreaks
  /// The indent the first line of a paragraph should have.
  first_line_indent : @library.Abs
  /// The indent that all but the first line of a paragraph should have.
  hanging_indent : @library.Abs
  /// Configuration for line numbering (a packed `ParLineMarker`).
  numbering_marker : @library.Content?
  /// The resolved horizontal alignment.
  align : @library.FixedAlignment
  /// The text size.
  font_size : @library.Abs
  /// The dominant direction.
  dir : @library.Dir
  /// A uniform hyphenation setting (only `Some(_)` if it's the same for all
  /// children, otherwise `None`).
  hyphenate : Bool?
  /// The text language (only `Some(_)` if it's the same for all children,
  /// otherwise `None`).
  lang : @library.Lang?
  /// Whether font fallback is enabled.
  fallback : Bool
  /// Whether to add spacing between CJK and Latin characters.
  cjk_latin_spacing : Bool
  /// Costs for various layout decisions.
  costs : @library.Costs
}

///|
/// Get a style property, but only if it is the same for all of the
/// children.
fn[T : Eq] shared_get(
  children : ArrayView[@library.Pair],
  styles : @library.StyleChain,
  getter : (@library.StyleChain) -> T,
) -> T? {
  let value = getter(styles)
  let mut prev : @library.StyleChain? = None
  for pair in children {
    let s = pair.1
    // Consecutive children with the same styles form one group.
    if prev is Some(p) && p == s {
      continue
    }
    prev = Some(s)
    if getter(s) != value {
      return None
    }
  }
  Some(value)
}

///|
/// Whether we have a list ancestor.
///
/// When we support some kind of more general ancestry mechanism, this can
/// become more elegant.
fn in_list(styles : @library.StyleChain) -> Bool {
  @library.ListElem::depth_in(styles).0 > 0L ||
  !@library.EnumElem::parents_in(styles).is_empty() ||
  @library.TermsElem::within_in(styles)
}
