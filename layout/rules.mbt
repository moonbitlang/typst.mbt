// Port of `typst-layout/src/rules.rs`.

///|
/// Register show rules for the [paged target](Target::Paged).
pub fn register(rules : @library.NativeRuleMap) -> Unit {
  // Model.
  rules.register(Paged, strong_rule)
  rules.register(Paged, emph_rule)
  rules.register(Paged, list_rule)
  rules.register(Paged, enum_rule)
  rules.register(Paged, terms_rule)
  rules.register(Paged, link_marker_rule)
  rules.register(Paged, link_rule)
  rules.register(Paged, direct_link_rule)
  rules.register(Paged, divider_rule)
  rules.register(Paged, title_rule)
  rules.register(Paged, heading_rule)
  rules.register(Paged, figure_rule)
  rules.register(Paged, figure_caption_rule)
  rules.register(Paged, quote_rule)
  rules.register(Paged, footnote_rule)
  rules.register(Paged, footnote_entry_rule)
  rules.register(Paged, (outline_rule : @library.ShowFn[@library.OutlineElem]))
  rules.register(
    Paged,
    (outline_entry_rule : @library.ShowFn[@library.OutlineEntry]),
  )
  rules.register(Paged, (ref_rule : @library.ShowFn[@library.RefElem]))
  rules.register(Paged, (cite_group_rule : @library.ShowFn[@library.CiteGroup]))
  rules.register(
    Paged,
    (bibliography_rule : @library.ShowFn[@library.BibliographyElem]),
  )
  rules.register(Paged, csl_light_rule)
  rules.register(Paged, csl_indent_rule)
  rules.register(Paged, (table_rule : @library.ShowFn[@library.TableElem]))
  rules.register(Paged, table_cell_rule)

  // Text.
  rules.register(Paged, sub_rule)
  rules.register(Paged, super_rule)
  rules.register(Paged, underline_rule)
  rules.register(Paged, overline_rule)
  rules.register(Paged, strike_rule)
  rules.register(Paged, highlight_rule)
  rules.register(Paged, smallcaps_rule)
  rules.register(Paged, raw_rule)
  rules.register(Paged, raw_line_rule)

  // Layout.
  rules.register(Paged, align_rule)
  rules.register(Paged, pad_rule)
  rules.register(Paged, columns_rule)
  rules.register(Paged, stack_rule)
  rules.register(Paged, grid_rule)
  rules.register(Paged, grid_cell_rule)
  rules.register(Paged, move_rule)
  rules.register(Paged, scale_rule)
  rules.register(Paged, rotate_rule)
  rules.register(Paged, skew_rule)
  rules.register(Paged, repeat_rule)
  rules.register(Paged, hide_rule)
  rules.register(Paged, layout_rule)

  // Visualize.
  rules.register(Paged, (image_rule : @library.ShowFn[@library.ImageElem]))
  rules.register(Paged, line_rule)
  rules.register(Paged, rect_rule)
  rules.register(Paged, square_rule)
  rules.register(Paged, ellipse_rule)
  rules.register(Paged, circle_rule)
  rules.register(Paged, polygon_rule)
  rules.register(Paged, curve_rule)

  // Math.
  rules.register(
    Paged,
    (equation_rule : @library.ShowFn[@library.EquationElem]),
  )

  // PDF.
  rules.register(Paged, artifact_rule)
  rules.register(Paged, pdf_marker_tag_rule)
}

///|
fn strong_rule(
  elem : @library.StrongElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem
  .body()
  .styled(
    @library.TextElem::set_delta(@library.WeightDelta(elem.delta(styles))),
  )
}

///|
fn emph_rule(
  elem : @library.EmphElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.body().styled(@library.TextElem::set_emph(@library.ItalicToggle(true)))
}

///|
/// The weak, attached spacing in front of a tight list (shared by lists and
/// enums).
fn tight_spacing(spacing : @library.Length) -> @library.Content {
  @library.VElem::new(Rel(@library.Rel::from_abs(spacing)))
  .with_weak(true)
  .with_attach(true)
  .pack()
}

///|
fn list_rule(
  elem : @library.ListElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let tight = elem.tight(styles)
  let mut realized = @library.BlockElem::multi_layouter(elem, layout_list)
    .pack()
    .spanned(elem.pack().span())
  if tight {
    let spacing = match elem.spacing(styles) {
      Custom(spacing) => spacing
      Auto => @library.ParElem::leading_in(styles)
    }
    let v = tight_spacing(spacing)
    realized = v.add(realized)
  }
  realized
}

///|
fn enum_rule(
  elem : @library.EnumElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let tight = elem.tight(styles)
  let mut realized = @library.BlockElem::multi_layouter(elem, layout_enum)
    .pack()
    .spanned(elem.pack().span())
  if tight {
    let spacing = match elem.spacing(styles) {
      Custom(spacing) => spacing
      Auto => @library.ParElem::leading_in(styles)
    }
    let v = tight_spacing(spacing)
    realized = v.add(realized)
  }
  realized
}

///|
fn terms_rule(
  elem : @library.TermsElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()
  let tight = elem.tight(styles)
  let separator = elem.separator(styles)
  let indent = elem.indent(styles)
  let hanging_indent = elem.hanging_indent(styles)
  let gutter = match elem.spacing(styles) {
    Custom(spacing) => spacing
    Auto =>
      if tight {
        @library.ParElem::leading_in(styles)
      } else {
        @library.ParElem::spacing_in(styles)
      }
  }
  let pad = hanging_indent + indent
  let unpad = if !hanging_indent.is_zero() {
    Some(
      @library.HElem::new(Rel(@library.Rel::from_abs(-hanging_indent)))
      .pack()
      .spanned(span),
    )
  } else {
    None
  }
  let children = []
  for child in elem.children() {
    let seq = []
    if unpad is Some(unpad) {
      seq.push(unpad)
    }
    seq.push(@library.pdf_marker_tag(TermsItemLabel, child.term().strong()))
    seq.push(separator.artifact(Other))
    seq.push(child.description())

    // Text in wide term lists shall always turn into paragraphs.
    if !tight {
      seq.push(@library.ParbreakElem::new().pack())
    }
    let item = @library.Content::sequence(seq).spanned(child.pack().span())
    children.push(
      @library.StackChild::Block(@library.pdf_marker_tag(TermsItemBody, item)),
    )
  }
  let padding = @library.Sides::splat(@library.Rel::zero()).with_side(
    @library.TextElem::dir_in(styles).resolve(styles).start(),
    @library.Rel::from_abs(pad),
  )
  let mut realized = @library.StackElem::new(children)
    .with_spacing(Some(Rel(@library.Rel::from_abs(gutter))))
    .pack()
    .spanned(span)
    .padded(padding)
    .styled(@library.TermsElem::set_within(true))
  if tight {
    let spacing = match elem.spacing(styles) {
      Custom(spacing) => spacing
      Auto => @library.ParElem::leading_in(styles)
    }
    let v = tight_spacing(spacing).spanned(span)
    realized = v.add(realized)
  }
  realized
}

///|
fn link_marker_rule(
  elem : @library.LinkMarker,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.body()
}

///|
fn link_rule(
  elem : @library.LinkElem,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()
  let body = elem.body()
  let dest = elem.dest().resolve_early(engine, span)
  let alt = dest.alt_text(engine, styles, span)
  // Manually construct link marker that spans the whole link elem, not just
  // the body.
  @library.LinkMarker::new(body, Some(alt))
  .pack()
  .spanned(span)
  .styled(@library.LinkElem::set_current(Some(dest)))
}

///|
fn direct_link_rule(
  elem : @library.DirectLinkElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let dest = @library.Destination::Location(elem.loc())
  elem.body().linked(dest, elem.alt())
}

///|
fn divider_rule(
  elem : @library.DividerElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.LineElem::new().pack().spanned(elem.pack().span())
}

///|
fn title_rule(
  elem : @library.TitleElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::packed(
    @library.at(elem.pack().span(), () => elem.resolve_body(styles)),
  )
}

///|
fn heading_rule(
  elem : @library.HeadingElem,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let spacing_to_numbering = @library.Em::new(0.3)
  let span = elem.pack().span()
  let mut realized = elem.body()
  let hanging_indent = elem.hanging_indent(styles)
  let mut indent = match hanging_indent {
    Custom(length) => length.resolve(styles)
    Auto => @library.Abs::zero()
  }
  if elem.numbering(styles) is Some(numbering) {
    let location = elem.pack().location().unwrap()
    let numbering = @library.Counter::of(@library.heading_elem())
      .display_at(engine, location, styles, numbering, span)
      .spanned(span)
    let align = @library.AlignElem::alignment_in(styles).resolve(styles)
    if hanging_indent is Auto && align.x == Start {
      let pod = @library.LayoutRegion::new(
        @library.Axes::splat(@library.Abs::inf()),
        @library.Axes::splat(false),
      )

      // Add weak spacing (that will collapse) on both sides to disable CJ
      // punctuation adjustment during measurement. In the actual heading the
      // numbering will not be at the boundary (negative spacing before and
      // the body after), so there could be misalignment otherwise. If there
      // is ever a cleaner way to disable punctuation adjustment, that would
      // be preferrable.
      let collapsing = @library.HElem::new(
          Rel(
            @library.Rel::from_abs(
              @library.Length::from_abs(@library.Abs::pt(1.0)),
            ),
          ),
        )
        .with_weak(true)
        .pack()
      let measurable = collapsing.add(numbering).add(collapsing)

      // We don't have a locator for the numbering here, so we just use the
      // measurement infrastructure for now.
      let link = @library.LocatorLink::measure(location, span)
      let size = (engine.library.routines.layout_frame)(
        engine,
        measurable,
        @library.Locator::link(link),
        styles,
        pod,
      ).size()
      indent = size.x + spacing_to_numbering.resolve(styles)
    }

    // The spacing is weak to eat up a potential leading space in the body.
    let spacing = @library.HElem::new(
        Rel(
          @library.Rel::from_abs(@library.Length::from_em(spacing_to_numbering)),
        ),
      )
      .with_weak(true)
      .pack()
    realized = numbering.add(spacing).add(realized)
  }
  if indent != @library.Abs::zero() {
    let body = @library.HElem::new(
        Rel(@library.Rel::from_abs(@library.Length::from_abs(-indent))),
      )
      .pack()
      .add(realized)
    let inset = @library.Sides::splat(None).with_side(
      @library.TextElem::dir_in(styles).resolve(styles).start(),
      Some(@library.Rel::from_abs(@library.Length::from_abs(indent))),
    )
    @library.BlockElem::new()
    .with_inset(inset)
    .with_body(Some(Content(body)))
    .pack()
  } else {
    @library.BlockElem::packed(realized)
  }
}

///|
fn figure_rule(
  elem : @library.FigureElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()
  let mut realized = elem.body()

  // Build the caption, if any.
  if elem.caption(styles) is Some(caption) {
    let (first, second) = match caption.position(styles) {
      Top => (caption.pack(), realized)
      Bottom => (realized, caption.pack())
    }
    realized = @library.Content::sequence([
      first,
      @library.VElem::new(Rel(@library.Rel::from_abs(elem.gap(styles))))
      .with_weak(true)
      .pack()
      .spanned(span),
      second,
    ])
  }

  // Ensure that the body is considered a paragraph.
  realized = realized.add(@library.ParbreakElem::new().pack().spanned(span))

  // Wrap the contents in a block.
  realized = @library.BlockElem::packed(realized).spanned(span)

  // Wrap in a float.
  if elem.placement(styles) is Some(align) {
    realized = @library.PlaceElem::new(realized)
      .with_alignment(align.map(align => Both(Center, align)))
      .with_scope(elem.scope(styles))
      .with_float(true)
      .pack()
      .spanned(span)
  } else if elem.scope(styles) == Parent {
    @library.bail_at(
      span,
      "parent-scoped placement is only available for floating figures",
      hints=[
        "you can enable floating placement with `figure(placement: auto, ..)`",
      ],
    )
  }
  realized
}

///|
fn figure_caption_rule(
  elem : @library.FigureCaption,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::packed(elem.realize(engine, styles))
}

///|
fn quote_rule(
  elem : @library.QuoteElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()
  let block = elem.block(styles)
  let mut realized = elem.body()
  let quotes = match elem.quotes(styles) {
    Custom(quotes) => quotes
    Auto => !block
  }
  if quotes {
    // Add zero-width weak spacing to make the quotes "sticky".
    let hole = h_hole()
    let sticky = @library.Content::sequence([hole, realized, hole])
    realized = @library.QuoteElem::quoted(sticky, styles)
  }
  let attribution = elem.attribution(styles)
  if block {
    realized = @library.BlockElem::packed(realized).spanned(span)
    if attribution is Some(attribution) {
      // Bring the attribution a bit closer to the quote.
      let gap = @library.Spacing::Rel(
        @library.Rel::from_abs(@library.Length::from_em(@library.Em::new(0.9))),
      )
      let v = @library.VElem::new(gap).with_weak(true).pack()
      realized = realized.add(v)
      realized = realized.add(
        @library.BlockElem::packed(attribution.realize(span)).aligned(H(End)),
      )
    }
    realized = @library.PadElem::new(realized).pack()
  } else if attribution is Some(Label(label)) {
    realized = realized.add(@library.SpaceElem::shared())
    realized = realized.add(@library.CiteElem::new(label).pack().spanned(span))
  }
  realized
}

///|
/// Upstream `HElem::hole`: zero-width weak spacing.
fn h_hole() -> @library.Content {
  @library.HElem::new(Rel(@library.Rel::zero())).with_weak(true).pack()
}

///|
fn footnote_rule(
  elem : @library.FootnoteElem,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  // The footnote number that links to the footnote entry.
  let link = elem.realize(engine, styles)
  let sup = @library.SuperElem::new(link).pack().spanned(elem.pack().span())
  h_hole().add(@library.pdf_marker_tag(Label, sup))
}

///|
fn footnote_entry_rule(
  elem : @library.FootnoteEntry,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let number_gap = @library.Em::new(0.05)
  let (sup, body) = elem.realize(engine, styles)
  let prefix = @library.pdf_marker_tag(Label, sup)
  @library.Content::sequence([
    @library.HElem::new(Rel(@library.Rel::from_abs(elem.indent(styles)))).pack(),
    prefix,
    @library.HElem::new(
      Rel(@library.Rel::from_abs(@library.Length::from_em(number_gap))),
    )
    .with_weak(true)
    .pack(),
    body,
  ])
}

///|
fn outline_rule(
  elem : @library.OutlineElem,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let title = elem.realize_title(styles)
  let entries = elem.realize_flat(engine, styles)
  let entries = entries.map(entry => entry.pack())
  let body = @library.pdf_marker_tag(
    OutlineBody,
    @library.Content::sequence(entries),
  )
  let seq = []
  if title is Some(title) {
    seq.push(title)
  }
  seq.push(body)
  @library.Content::sequence(seq)
}

///|
fn outline_entry_rule(
  elem : @library.OutlineEntry,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()
  let context = @library.Context::new(styles~)
  let prefix = elem.prefix(engine, context, span)
  let body = @library.at(span, () => elem.body())
  let page = elem.page(engine, context, span)
  let alt = {
    let prefix = match prefix {
      Some(p) => p.plain_text()
      None => ""
    }
    let body = body.plain_text()
    let page_str = @library.page_elem().local_name_in(styles)
    let page_nr = page.plain_text()
    let quotes = @library.SmartQuotes::get(
      @library.SmartQuoteElem::quotes_in(styles),
      @library.TextElem::lang_in(styles),
      @library.TextElem::region_in(styles),
      @library.SmartQuoteElem::alternative_in(styles),
    )
    let open = quotes.double_open
    let close = quotes.double_close
    "\{prefix} \{open}\{body}\{close} \{page_str} \{page_nr}"
  }
  let inner = elem.build_inner(context, span, body, page)
  let block = if elem.element().is_(@library.equation_elem()) {
    // Equation has no body and no levels, so indenting makes no sense.
    let body = prefix.unwrap_or(@library.Content::empty()).add(inner)
    @library.BlockElem::packed(body).spanned(span)
  } else {
    elem.indented(
      engine,
      context,
      span,
      prefix,
      inner,
      @library.Length::from_em(@library.Em::new(0.5)),
    )
  }
  let loc = @library.at(span, () => elem.element_location())
  block.linked(Location(loc), Some(alt))
}

///|
fn ref_rule(
  elem : @library.RefElem,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.realize(engine, styles)
}

///|
/// TODO(bibliography): upstream realizes the citation group
/// (`CiteGroup::realize`); bibliographies are ported separately.
fn cite_group_rule(
  elem : @library.CiteGroup,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  unported(elem, "`CiteGroup::realize`")
}

///|
/// TODO(bibliography): upstream builds the bibliography from the generated
/// works (`Works::generate`); bibliographies are ported separately.
fn bibliography_rule(
  elem : @library.BibliographyElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  unported(elem, "`Works::generate`")
}

///|
/// A rule whose port is pending: it fails with an error instead of silently
/// producing wrong output.
fn[T : @library.NativeElement] unported(
  elem : T,
  what : String,
) -> @library.Content raise @library.SourceError {
  let content = elem.into_content()
  @library.bail_at(
    content.span(),
    "TODO: paged export of `\{content.elem().name()}` is not ported yet (needs \{what})",
  )
}

///|
fn csl_light_rule(
  elem : @library.CslLightElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.body().styled(@library.TextElem::set_delta(@library.WeightDelta(-100L)))
}

///|
fn csl_indent_rule(
  elem : @library.CslIndentElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.PadElem::new(elem.body()).pack()
}

///|
fn table_rule(
  elem : @library.TableElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::multi_layouter(elem, layout_table).pack()
}

///|
fn table_cell_rule(
  elem : @library.TableCell,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  show_cell(elem.body(), elem.inset(styles), elem.align(styles))
}

///|
fn sub_rule(
  elem : @library.SubElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  show_script(
    styles,
    elem.body(),
    elem.typographic(styles),
    elem.baseline(styles),
    elem.size(styles),
    Sub,
  )
}

///|
fn super_rule(
  elem : @library.SuperElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  show_script(
    styles,
    elem.body(),
    elem.typographic(styles),
    elem.baseline(styles),
    elem.size(styles),
    Super,
  )
}

///|
fn show_script(
  styles : @library.StyleChain,
  body : @library.Content,
  typographic : Bool,
  baseline : @library.Smart[@library.Length],
  size : @library.Smart[@library.TextSize],
  kind : @library.ScriptKind,
) -> @library.Content raise @library.SourceError {
  let font_size = @library.TextElem::size_in(styles).resolve(styles)
  body.styled(
    @library.TextElem::set_shift_settings(
      Some({
        typographic,
        shift: baseline.map(l => -@library.Em::from_length(l, font_size)),
        size: size.map(t => @library.Em::from_length(t.0, font_size)),
        kind,
      }),
    ),
  )
}

///|
/// The decoration style of a decorated body (upstream
/// `body.set(TextElem::deco, smallvec![Decoration { line, extent }])`).
fn decorated(
  body : @library.Content,
  line : @library.DecoLine,
  extent : @library.Abs,
) -> @library.Content {
  body.styled(@library.TextElem::set_deco([{ line, extent, }]))
}

///|
fn underline_rule(
  elem : @library.UnderlineElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  decorated(
    elem.body(),
    Underline(
      stroke=match elem.stroke(styles) {
        Custom(stroke) => stroke.resolve(styles)
        Auto => @library.ResolvedStroke::default()
      },
      offset=elem.offset(styles).map(l => l.resolve(styles)),
      evade=elem.evade(styles),
      background=elem.background(styles),
    ),
    elem.extent(styles).resolve(styles),
  )
}

///|
fn overline_rule(
  elem : @library.OverlineElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  decorated(
    elem.body(),
    Overline(
      stroke=match elem.stroke(styles) {
        Custom(stroke) => stroke.resolve(styles)
        Auto => @library.ResolvedStroke::default()
      },
      offset=elem.offset(styles).map(l => l.resolve(styles)),
      evade=elem.evade(styles),
      background=elem.background(styles),
    ),
    elem.extent(styles).resolve(styles),
  )
}

///|
fn strike_rule(
  elem : @library.StrikeElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  decorated(
    elem.body(),
    // Note that we do not support evade option for strikethrough.
    Strikethrough(
      stroke=match elem.stroke(styles) {
        Custom(stroke) => stroke.resolve(styles)
        Auto => @library.ResolvedStroke::default()
      },
      offset=elem.offset(styles).map(l => l.resolve(styles)),
      background=elem.background(styles),
    ),
    elem.extent(styles).resolve(styles),
  )
}

///|
fn highlight_rule(
  elem : @library.HighlightElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  decorated(
    elem.body(),
    Highlight(
      fill=elem.fill(styles),
      stroke=sides_fixed_stroke(
        resolve_sides_stroke(elem.stroke(styles), styles),
      ),
      top_edge=elem.top_edge(styles),
      bottom_edge=elem.bottom_edge(styles),
      radius=corners_rel_or_zero(
        resolve_corners_rel(elem.radius(styles), styles),
      ),
    ),
    elem.extent(styles).resolve(styles),
  )
}

///|
fn smallcaps_rule(
  elem : @library.SmallcapsElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let sc : @library.Smallcaps = if elem.all(styles) { All } else { Minuscules }
  elem.body().styled(@library.TextElem::set_smallcaps(Some(sc)))
}

///|
fn raw_rule(
  elem : @library.RawElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let lines = elem.lines().unwrap_or([])
  let seq = []
  for i, line in lines {
    if i != 0 {
      seq.push(@library.LinebreakElem::new().pack())
    }
    seq.push(line.pack())
  }
  let mut realized = @library.Content::sequence(seq)
  if elem.block(styles) {
    // Align the text before inserting it into the block.
    realized = realized.aligned(H(elem.align(styles)))
    realized = @library.BlockElem::packed(realized).spanned(elem.pack().span())
  }
  realized
}

///|
fn raw_line_rule(
  elem : @library.RawLine,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.body()
}

///|
fn align_rule(
  elem : @library.AlignElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.body().aligned(elem.alignment(styles))
}

///|
fn pad_rule(
  elem : @library.PadElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::multi_layouter(elem, layout_pad).pack()
}

///|
fn columns_rule(
  elem : @library.ColumnsElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::multi_layouter(elem, layout_columns).pack()
}

///|
fn stack_rule(
  elem : @library.StackElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::multi_layouter(elem, layout_stack).pack()
}

///|
fn grid_rule(
  elem : @library.GridElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::multi_layouter(elem, layout_grid).pack()
}

///|
fn grid_cell_rule(
  elem : @library.GridCell,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  show_cell(elem.body(), elem.inset(styles), elem.align(styles))
}

///|
/// Function with common code to display a grid cell or table cell.
fn show_cell(
  body : @library.Content,
  inset : @library.Smart[@library.Sides[@library.Rel[@library.Length]?]],
  align : @library.Smart[@library.Alignment],
) -> @library.Content raise @library.SourceError {
  let mut body = body
  let inset = (match inset {
    Custom(inset) => inset
    Auto => @library.Sides::splat(None)
  }).map(side => side.unwrap_or(@library.Rel::zero()))
  if inset != @library.Sides::splat(@library.Rel::zero()) {
    // Only pad if some inset is not 0pt.
    // Avoids a bug where using .padded() in any way inside Show causes
    // alignment in align(...) to break.
    body = body.padded(inset)
  }
  if align is Custom(alignment) {
    body = body.aligned(alignment)
  }
  body
}

///|
fn move_rule(
  elem : @library.MoveElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_move).pack()
}

///|
fn scale_rule(
  elem : @library.ScaleElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_scale).pack()
}

///|
fn rotate_rule(
  elem : @library.RotateElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_rotate).pack()
}

///|
fn skew_rule(
  elem : @library.SkewElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_skew).pack()
}

///|
fn repeat_rule(
  elem : @library.RepeatElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_repeat).pack()
}

///|
fn hide_rule(
  elem : @library.HideElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.body().styled(@library.HideElem::set_hidden(true))
}

///|
fn layout_rule(
  elem : @library.LayoutElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::multi_layouter(elem, (
    elem,
    engine,
    locator,
    styles,
    regions,
  ) => {
    // Gets the current region's base size, which will be the size of the
    // outer container, or of the page if there is no such container.
    let { x, y, } = regions.base()
    let loc = elem.pack().location().unwrap()
    let context = @library.Context::new(location=loc, styles~)
    let dict = @library.Dict::new()
    dict.insert("width", Length(@library.Length::from_abs(x)))
    dict.insert("height", Length(@library.Length::from_abs(y)))
    let result = elem
      .func()
      .call_values(engine, context, [Dict(dict)])
      .display()
    layout_fragment(engine, result, locator, styles, regions)
  }).pack()
}

///|
fn image_rule(
  elem : @library.ImageElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_image)
  .with_width(elem.width(styles))
  .with_height(elem.height(styles))
  .pack()
}

///|
fn line_rule(
  elem : @library.LineElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_line).pack()
}

///|
fn rect_rule(
  elem : @library.RectElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_rect)
  .with_width(elem.width(styles))
  .with_height(elem.height(styles))
  .pack()
}

///|
fn square_rule(
  elem : @library.SquareElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_square)
  .with_width(elem.width(styles))
  .with_height(elem.height(styles))
  .pack()
}

///|
fn ellipse_rule(
  elem : @library.EllipseElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_ellipse)
  .with_width(elem.width(styles))
  .with_height(elem.height(styles))
  .pack()
}

///|
fn circle_rule(
  elem : @library.CircleElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_circle)
  .with_width(elem.width(styles))
  .with_height(elem.height(styles))
  .pack()
}

///|
fn polygon_rule(
  elem : @library.PolygonElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_polygon).pack()
}

///|
fn curve_rule(
  elem : @library.CurveElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.BlockElem::single_layouter(elem, layout_curve).pack()
}

///|
fn equation_rule(
  elem : @library.EquationElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  if elem.block(styles) {
    @library.BlockElem::multi_layouter(elem, layout_equation_block).pack()
  } else {
    @library.InlineElem::layouter(elem, layout_equation_inline).pack()
  }
}

///|
fn artifact_rule(
  elem : @library.ArtifactElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.body()
}

///|
fn pdf_marker_tag_rule(
  elem : @library.PdfPdfMarkerTag,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.body()
}
