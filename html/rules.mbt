// Port of `typst-html/src/rules.rs`.

///|
/// Registers show rules for the HTML target.
pub fn register(rules : @library.NativeRuleMap) -> Unit {
  // Model.
  rules.register(Html, par_rule)
  rules.register(Html, strong_rule)
  rules.register(Html, emph_rule)
  rules.register(Html, list_rule)
  rules.register(Html, enum_rule)
  rules.register(Html, terms_rule)
  rules.register(Html, link_rule)
  rules.register(Html, direct_link_rule)
  rules.register(Html, divider_rule)
  rules.register(Html, title_rule)
  rules.register(Html, heading_rule)
  rules.register(Html, figure_rule)
  rules.register(Html, figure_caption_rule)
  rules.register(Html, quote_rule)
  rules.register(Html, footnote_rule)
  rules.register(Html, footnote_marker_rule)
  rules.register(Html, footnote_container_rule)
  rules.register(Html, footnote_entry_rule)
  rules.register(Html, (outline_rule : @library.ShowFn[@library.OutlineElem]))
  rules.register(
    Html,
    (outline_entry_rule : @library.ShowFn[@library.OutlineEntry]),
  )
  rules.register(Html, (ref_rule : @library.ShowFn[@library.RefElem]))
  rules.register(Html, (cite_group_rule : @library.ShowFn[@library.CiteGroup]))
  rules.register(
    Html,
    (bibliography_rule : @library.ShowFn[@library.BibliographyElem]),
  )
  rules.register(Html, csl_light_rule)
  rules.register(Html, csl_indent_rule)
  rules.register(Html, (table_rule : @library.ShowFn[@library.TableElem]))
  rules.register(Html, table_cell_rule)

  // Text.
  rules.register(Html, sub_rule)
  rules.register(Html, super_rule)
  rules.register(Html, underline_rule)
  rules.register(Html, overline_rule)
  rules.register(Html, strike_rule)
  rules.register(Html, highlight_rule)
  rules.register(Html, smallcaps_rule)
  rules.register(Html, raw_rule)
  rules.register(Html, raw_line_rule)

  // Visualize.
  rules.register(Html, (image_rule : @library.ShowFn[@library.ImageElem]))

  // Math.
  rules.register(Html, (equation_rule : @library.ShowFn[@library.EquationElem]))

  // For the HTML target, `html.frame` is a primitive. In the laid-out target,
  // it should be a no-op so that nested frames don't break (things like `show
  // math.equation: html.frame` can result in nested ones).
  rules.register(Paged, (elem : @library.FrameElem, _, _) => elem.body())
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
    "TODO: HTML export of `\{content.elem().name()}` is not ported yet (needs \{what})",
  )
}

///|
/// Upstream `BlockElem::packed`.
fn block_packed(body : @library.Content) -> @library.Content {
  @library.BlockElem::new().with_body(Some(Content(body))).pack()
}

///|
/// Upstream `ParbreakElem::shared`.
fn parbreak() -> @library.Content {
  @library.ParbreakElem::new().pack()
}

///|
/// Upstream `LinebreakElem::shared`.
fn linebreak() -> @library.Content {
  @library.LinebreakElem::new().pack()
}

///|
/// Upstream `HElem::hole`.
fn h_hole() -> @library.Content {
  @library.HElem::new(Rel(@library.Rel::zero())).with_weak(true).pack()
}

///|
/// Shorthand for an HTML element with a body.
fn html_elem(
  tag : @library.HtmlTag,
  body : @library.Content,
) -> @library.HtmlElem {
  @library.HtmlElem::new(tag).with_body(Some(body))
}

///|
fn par_rule(
  elem : @library.ParElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(@library.tag_p, elem.body()).pack()
}

///|
fn strong_rule(
  elem : @library.StrongElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(@library.tag_strong, elem.body()).pack()
}

///|
fn emph_rule(
  elem : @library.EmphElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(@library.tag_em, elem.body()).pack()
}

///|
fn list_rule(
  elem : @library.ListElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let items = elem
    .children()
    .map(item => {
      // Text in wide lists shall always turn into paragraphs.
      let mut body = item.body()
      if !elem.tight(styles) {
        body = body.add(parbreak())
      }
      html_elem(@library.tag_li, body).pack().spanned(item.pack().span())
    })
  block_packed(
    html_elem(@library.tag_ul, @library.Content::sequence(items))
    .pack()
    .spanned(elem.pack().span()),
  )
}

///|
fn enum_rule(
  elem : @library.EnumElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let mut ol = @library.HtmlElem::new(@library.tag_ol)
  if elem.reversed(styles) {
    ol = ol.with_attr(@library.attr_reversed, "reversed")
  }
  if elem.start(styles) is Custom(n) {
    ol = ol.with_attr(@library.attr_start, n.0.to_string())
  }
  let body = @library.Content::sequence(
    elem
    .children()
    .map(item => {
      let mut li = @library.HtmlElem::new(@library.tag_li)
      if item.number(styles) is Custom(nr) {
        li = li.with_attr(@library.attr_value, nr.0.to_string())
      }
      // Text in wide enums shall always turn into paragraphs.
      let mut body = item.body()
      if !elem.tight(styles) {
        body = body.add(parbreak())
      }
      li.with_body(Some(body)).pack().spanned(item.pack().span())
    }),
  )
  block_packed(ol.with_body(Some(body)).pack().spanned(elem.pack().span()))
}

///|
fn terms_rule(
  elem : @library.TermsElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let children = []
  for item in elem.children() {
    // Text in wide term lists shall always turn into paragraphs.
    let mut description = item.description()
    if !elem.tight(styles) {
      description = description.add(parbreak())
    }
    children.push(
      html_elem(@library.tag_dt, item.term()).pack().spanned(item.term().span()),
    )
    children.push(
      html_elem(@library.tag_dd, description)
      .pack()
      .spanned(item.description().span()),
    )
  }
  block_packed(
    html_elem(@library.tag_dl, @library.Content::sequence(children))
    .pack()
    .spanned(elem.pack().span()),
  )
}

///|
// Also check `PATCHED_LINK_RULE` in `docs/src/main.rs` when editing this.
fn link_rule(
  elem : @library.LinkElem,
  engine : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()
  let dest = elem.target().resolve_early(engine, span)
  let href = match dest {
    Url(url) => Some(url.into_inner())
    Position(_) => {
      engine.sink.warn(
        @library.SourceDiagnostic::warning_at(
          span, "positional link was ignored during HTML export",
        ),
      )
      None
    }
    Location(location) =>
      Some(
        @library.at(span, () => {
          @library.EarlyLinkResolver::new(elem.pack().location().unwrap(), span)
          .resolve(engine, location)
          .into_relative_uri()
        }),
      )
  }
  @library.HtmlElem::new(@library.tag_a)
  .with_optional_attr(@library.attr_href, href)
  .with_body(Some(elem.body()))
  .pack()
}

///|
fn direct_link_rule(
  elem : @library.DirectLinkElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.LinkElem::new(
    @library.LinkTarget::Dest(Location(elem.loc())),
    elem.body(),
  ).pack()
}

///|
fn divider_rule(
  elem : @library.DividerElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  block_packed(
    @library.HtmlElem::new(@library.tag_hr).pack().spanned(elem.pack().span()),
  )
}

///|
fn title_rule(
  elem : @library.TitleElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()
  block_packed(
    html_elem(
      @library.tag_h1,
      @library.at(span, () => elem.resolve_body(styles)),
    )
    .pack()
    .spanned(span),
  )
}

///|
fn heading_rule(
  elem : @library.HeadingElem,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()
  let mut realized = elem.body()
  if elem.numbering(styles) is Some(numbering) {
    let location = elem.pack().location().unwrap()
    let numbering = @library.Counter::of(@library.heading_elem())
      .display_at(engine, location, styles, numbering, span)
      .spanned(span)
    realized = numbering.add(@library.SpaceElem::shared()).add(realized)
  }

  // HTML's h1 is closer to a title element. There should only be one.
  // Meanwhile, a level 1 Typst heading is a section heading. For this
  // reason, levels are offset by one: A Typst level 1 heading becomes
  // a `<h2>`.
  let level = elem.resolve_level(styles).0
  block_packed(
    if level >= 6 {
      engine.sink.warn(
        @library.SourceDiagnostic::warning_at(
          span,
          "heading of level \{level} was transformed to <div role=\"heading\" aria-level=\"\{level + 1}\">, which is not supported by all assistive technology",
        ).with_hints([
          "HTML only supports <h1> to <h6>, not <h\{level + 1}>",
          "you may want to restructure your document so that it doesn't contain deep headings",
        ]),
      )
      html_elem(@library.tag_div, realized)
      .with_attr(@library.attr_role, "heading")
      .with_attr(@library.attr_aria_level, (level + 1).to_string())
      .pack()
      .spanned(span)
    } else {
      let t = [
          @library.tag_h2, @library.tag_h3, @library.tag_h4, @library.tag_h5, @library.tag_h6,
        ][level.to_int() - 1]
      html_elem(t, realized).pack().spanned(span)
    },
  )
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
    realized = match caption.position(styles) {
      Top => caption.pack().add(realized)
      Bottom => realized.add(caption.pack())
    }
  }

  // Ensure that the body is considered a paragraph.
  realized = realized.add(parbreak().spanned(span))
  block_packed(html_elem(@library.tag_figure, realized).pack().spanned(span))
}

///|
fn figure_caption_rule(
  elem : @library.FigureCaption,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  block_packed(
    html_elem(@library.tag_figcaption, elem.realize(engine, styles))
    .pack()
    .spanned(elem.pack().span()),
  )
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
    realized = @library.QuoteElem::quoted(realized, styles)
  }
  let attribution = elem.attribution(styles)
  if block {
    let mut blockquote = html_elem(@library.tag_blockquote, realized)
    if attribution is Some(Content(attribution)) &&
      @library.LinkElem::of(attribution) is Some(link) &&
      link.target() is Dest(Url(url)) {
      blockquote = blockquote.with_attr(@library.attr_cite, url.into_inner())
    }
    realized = block_packed(blockquote.pack().spanned(span))
    if attribution is Some(attribution) {
      realized = realized.add(attribution.realize(span))
      realized = realized.add(parbreak())
    }
  } else if attribution is Some(Label(label)) {
    realized = realized.add(@library.SpaceElem::shared())
    realized = realized.add(@library.CiteElem::new(label).pack().spanned(span))
  }
  realized
}

///|
fn footnote_rule(
  elem : @library.FootnoteElem,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()

  // The footnote number that links to the footnote entry.
  let link = elem.realize(engine, styles)
  let sup = @library.SuperElem::new(link)
    .pack()
    .styled(@library.HtmlElem::set_role(Some("doc-noteref")))
    .spanned(span)

  // Indicates the presence of a default footnote rule to emit an error when
  // no footnote container is available.
  let marker = @library.FootnoteMarker::new().pack().spanned(span)
  h_hole().add(sup).add(marker)
}

///|
fn footnote_marker_rule(
  _ : @library.FootnoteMarker,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  @library.Content::empty()
}

///|
fn footnote_container_rule(
  elem : @library.FootnoteContainer,
  engine : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let content = elem.pack()
  let mut selector = @library.footnote_elem().select()

  // In bundle export, we only want the footnotes in the current document.
  if engine.introspect(
      @library.document_introspection(
        content.location().unwrap(),
        content.span(),
      ),
    )
    is Some(doc_location) {
    selector = Within(
      selector=@library.footnote_elem().select(),
      ancestor=Location(doc_location),
    )
  }

  // Create entries for all footnotes in the document.
  let notes = engine.introspect(
    @library.query_introspection(selector, content.span()),
  )
  let items = []
  for note in notes {
    let note = @library.FootnoteElem(note)
    if note.is_ref() {
      continue
    }
    let loc = note.pack().location().unwrap()
    let span = note.pack().span()
    items.push(
      html_elem(
        @library.tag_li,
        @library.FootnoteEntry::new(note).pack().spanned(span),
      )
      .with_parent(loc)
      .pack()
      .located(loc.variant(1))
      .spanned(span),
    )
  }

  // Don't create a container if we filtered out all notes.
  if items.is_empty() {
    return @library.Content::empty()
  }

  // There can be multiple footnotes in a container, so they semantically
  // represent an ordered list. However, the list is already numbered with the
  // footnote superscripts in the DOM, so we turn off CSS' list enumeration.
  let list = html_elem(@library.tag_ol, @library.Content::sequence(items))
    .with_css(@library.CssProperties::new().with_("list-style-type", "none"))
    .pack()

  // The user may want to style the whole footnote element so we wrap it in
  // an additional selectable container. This is also how it's done in the
  // ARIA spec (although there, the section also contains an additional
  // heading).
  block_packed(
    html_elem(@library.tag_section, list)
    .with_attr(@library.attr_role, "doc-endnotes")
    .pack()
    .spanned(content.span()),
  )
}

///|
fn footnote_entry_rule(
  elem : @library.FootnoteEntry,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let (sup, body) = elem.realize(engine, styles)

  // The prefix is a link back to the first footnote reference, so
  // `doc-backlink` is the appropriate ARIA role.
  let prefix = sup
    .styled(@library.HtmlElem::set_role(Some("doc-backlink")))
    .spanned(elem.pack().span())

  // We do not use the ARIA role `doc-footnote` because it "is only for
  // representing individual notes that occur within the body of a work"
  // (see <https://www.w3.org/TR/dpub-aria-1.1/#doc-footnote>). Our footnotes
  // more appropriately modelled as ARIA endnotes. This is also in line with
  // how Pandoc handles footnotes.
  prefix.add(body)
}

///|
fn outline_rule(
  elem : @library.OutlineElem,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let title = elem.realize_title(styles)
  let tree = elem.realize_tree(engine, styles)
  let list = outline_convert_list(tree)
  block_packed(
    html_elem(
      @library.tag_nav,
      title.unwrap_or(@library.Content::empty()).add(list),
    )
    .with_attr(@library.attr_role, "doc-toc")
    .pack()
    .spanned(elem.pack().span()),
  )
}

///|
fn outline_convert_list(
  list : Array[@library.OutlineNode[@library.OutlineEntry]],
) -> @library.Content {
  // The Digital Publishing ARIA spec also proposed to add `role="directory"`
  // to the `<ol>` element, but this role is deprecated, so we don't do that.
  // The elements are already easily selectable via `nav[role="doc-toc"] ol`.
  html_elem(
    @library.tag_ol,
    @library.Content::sequence(list.map(outline_convert_node)),
  )
  .with_css(@library.CssProperties::new().with_("list-style-type", "none"))
  .pack()
}

///|
fn outline_convert_node(
  node : @library.OutlineNode[@library.OutlineEntry],
) -> @library.Content {
  let body = if !node.children.is_empty() {
    // The `<div>` is not technically necessary, but otherwise it auto-wraps
    // in a `<p>`, which results in bad spacing. Perhaps, we can remove this
    // in the future. See also:
    // <https://github.com/typst/typst/issues/5907>
    html_elem(@library.tag_div, node.entry.pack())
    .pack()
    .add(outline_convert_list(node.children))
  } else {
    node.entry.pack()
  }
  html_elem(@library.tag_li, body).pack()
}

///|
fn outline_entry_rule(
  elem : @library.OutlineEntry,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let span = elem.pack().span()
  let context = @library.Context::new(styles~)
  let mut realized = @library.at(span, () => elem.body())
  if elem.prefix(engine, context, span) is Some(prefix) {
    let wrapped = html_elem(@library.tag_span, prefix)
      .with_attr(@library.attr_class, "prefix")
      .pack()
      .spanned(span)
    let separator = match @library.FigureElem::of(elem.element()) {
      Some(elem) => elem.resolve_separator(styles)
      None => @library.SpaceElem::shared()
    }
    realized = @library.Content::sequence([wrapped, separator, realized])
  }
  let loc = @library.at(span, () => elem.element_location())
  let dest = @library.Destination::Location(loc)
  @library.LinkElem::new(Dest(dest), realized).pack()
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
/// TODO: Upstream realizes the citation group (`CiteGroup::realize`) with
/// the `doc-biblioref` role; bibliographies are not ported yet.
fn cite_group_rule(
  elem : @library.CiteGroup,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  unported(elem, "`CiteGroup::realize`")
}

///|
/// TODO: Upstream builds a `<section role="doc-bibliography">` from the
/// generated works (`Works::generate`); bibliographies are not ported yet.
///
/// For the bibliography, we have a few elements that should be styled (e.g.
/// indent), but inline styles are not apprioriate because they couldn't be
/// properly overridden. For those, we currently emit classes so that a user
/// can style them with CSS, but do not emit any styles ourselves.
fn bibliography_rule(
  elem : @library.BibliographyElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  unported(elem, "`Works::generate`")
}

///|
fn csl_light_rule(
  elem : @library.CslLightElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(@library.tag_span, elem.body())
  .with_attr(@library.attr_class, "light")
  .pack()
}

///|
fn csl_indent_rule(
  elem : @library.CslIndentElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  block_packed(
    html_elem(@library.tag_div, elem.body())
    .with_attr(@library.attr_class, "indent")
    .pack()
    .spanned(elem.pack().span()),
  )
}

///|
fn table_rule(
  elem : @library.TableElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let grid = elem.grid().unwrap()
  show_cellgrid(grid, styles, elem.pack().span())
}

///|
fn show_cellgrid(
  grid : @library.CellGrid,
  styles : @library.StyleChain,
  span : @syntax.Span,
) -> @library.Content {
  let elem = (tag : @library.HtmlTag, body : @library.Content) => {
    html_elem(tag, body).pack().spanned(span)
  }
  let columns = grid.non_gutter_column_count()
  let rows : Array[ArrayView[@library.Entry]] = []
  for i = 0; i < grid.entries.length(); i = i + columns {
    let end = if i + columns < grid.entries.length() {
      i + columns
    } else {
      grid.entries.length()
    }
    rows.push(grid.entries[i:end])
  }
  let tr = (tag : @library.HtmlTag, row : ArrayView[@library.Entry]) => {
    let row = row
      .iter()
      .filter_map(entry => entry.as_cell())
      .map(cell => show_cell(tag, cell, styles))
      .to_array()
    elem(@library.tag_tr, @library.Content::sequence(row))
  }

  // TODO(subfooters): similarly to headers, take consecutive footers from
  // the end for 'tfoot'.
  let footer = grid.footer.map(ft => {
    // Convert from gutter to non-gutter coordinates. Use ceil as it might
    // include the previous gutter row
    // (cf. typst-library/layout/grid/resolve.rs).
    let footer_start = if grid.has_gutter {
      (ft.inner.start + 1) / 2
    } else {
      ft.inner.start
    }
    let drained = drain_from(rows, footer_start)
    elem(
      @library.tag_tfoot,
      @library.Content::sequence(drained.map(row => tr(@library.tag_td, row))),
    )
  })

  // Header range converting from gutter (doubled) to non-gutter coordinates.
  let header_range = (hd : @library.Repeatable[@library.Header]) => {
    let range = hd.inner.range
    if grid.has_gutter {
      // Use ceil as it might be `2 * row_amount - 1` if the header is at
      // the end (cf. typst-library/layout/grid/resolve.rs).
      @library.RowRange::{ start: range.start / 2, end: (range.end + 1) / 2, }
    } else {
      range
    }
  }

  // Store all consecutive headers at the start in 'thead'. All remaining
  // headers are just 'th' rows across the table body.
  let mut consecutive_header_end = 0
  let mut first_mid_table_header = 0
  for hd in grid.headers {
    let range = header_range(hd)
    let is_consecutive = range.start == consecutive_header_end
    consecutive_header_end = range.end
    if !is_consecutive {
      break
    }
    first_mid_table_header += 1
  }
  let (y_offset, header, rows) = if first_mid_table_header > 0 {
    let removed_header_rows = header_range(
        grid.headers[first_mid_table_header - 1],
      ).end
    let rest = drain_from(rows, removed_header_rows)
    (
      removed_header_rows,
      Some(
        elem(
          @library.tag_thead,
          @library.Content::sequence(rows.map(row => tr(@library.tag_th, row))),
        ),
      ),
      rest,
    )
  } else {
    (0, None, rows)
  }

  // TODO: Consider improving accessibility properties of multi-level headers
  // inside tables in the future, e.g. indicating which columns they are
  // relative to and so on. See also:
  // https://www.w3.org/WAI/tutorials/tables/multi-level/
  let mut next_header = first_mid_table_header
  let body_rows = []
  for relative_y, row in rows {
    let y = relative_y + y_offset
    let current_header_range = grid.headers
      .get(next_header)
      .map(h => header_range(h))
    if current_header_range is Some(range) && range.contains(y) {
      if y + 1 == range.end {
        next_header += 1
      }
      body_rows.push(tr(@library.tag_th, row))
    } else {
      body_rows.push(tr(@library.tag_td, row))
    }
  }
  let mut body = @library.Content::sequence(body_rows)
  if header is Some(_) || footer is Some(_) {
    body = elem(@library.tag_tbody, body)
  }
  let content = []
  if header is Some(header) {
    content.push(header)
  }
  content.push(body)
  if footer is Some(footer) {
    content.push(footer)
  }
  block_packed(elem(@library.tag_table, @library.Content::sequence(content)))
}

///|
/// Removes and returns the elements from `at` on (upstream `drain(at..)`).
fn[T] drain_from(rows : Array[T], at : Int) -> Array[T] {
  let tail = []
  for i in at..<rows.length() {
    tail.push(rows[i])
  }
  while rows.length() > at {
    rows.pop() |> ignore
  }
  tail
}

///|
fn show_cell(
  tag : @library.HtmlTag,
  cell : @library.Cell,
  styles : @library.StyleChain,
) -> @library.Content {
  let cell = cell.body
  guard @library.TableCell::of(cell) is Some(cell) else { return cell }
  let attrs = @library.HtmlAttrs::new()
  let span = (n : @library.NonZeroUSize) => {
    if n.get() != 1L {
      Some(n.get().to_string())
    } else {
      None
    }
  }
  if span(cell.colspan(styles)) is Some(colspan) {
    attrs.push(@library.attr_colspan, colspan)
  }
  if span(cell.rowspan(styles)) is Some(rowspan) {
    attrs.push(@library.attr_rowspan, rowspan)
  }
  @library.HtmlElem::new(tag)
  .with_body(Some(cell.pack()))
  .with_attrs(attrs)
  .pack()
  .spanned(cell.pack().span())
}

///|
fn table_cell_rule(
  elem : @library.TableCell,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  elem.body()
}

///|
fn sub_rule(
  elem : @library.SubElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(@library.tag_sub, elem.body()).pack()
}

///|
fn super_rule(
  elem : @library.SuperElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(@library.tag_sup, elem.body()).pack()
}

///|
fn underline_rule(
  elem : @library.UnderlineElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  // Note: In modern HTML, `<u>` is not the underline element, but
  // rather an "Unarticulated Annotation" element (see HTML spec
  // 4.5.22). Using `text-decoration` instead is recommended by MDN.
  html_elem(@library.tag_span, elem.body())
  .with_css(@library.CssProperties::new().with_("text-decoration", "underline"))
  .pack()
}

///|
fn overline_rule(
  elem : @library.OverlineElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(@library.tag_span, elem.body())
  .with_css(@library.CssProperties::new().with_("text-decoration", "overline"))
  .pack()
}

///|
fn strike_rule(
  elem : @library.StrikeElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(@library.tag_s, elem.body()).pack()
}

///|
fn highlight_rule(
  elem : @library.HighlightElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(@library.tag_mark, elem.body()).pack()
}

///|
fn smallcaps_rule(
  elem : @library.SmallcapsElem,
  _ : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let variant = if elem.all(styles) { "all-small-caps" } else { "small-caps" }
  html_elem(@library.tag_span, elem.body())
  .with_css(@library.CssProperties::new().with_("font-variant-caps", variant))
  .pack()
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
      seq.push(linebreak())
    }
    seq.push(line.pack())
  }
  let span = elem.pack().span()
  let lang = elem.lang(styles)
  let code = html_elem(@library.tag_code, @library.Content::sequence(seq))
    .with_optional_attr(@library.HtmlAttr::constant("data-lang"), lang)
    .pack()
    .spanned(span)
  if elem.block(styles) {
    block_packed(html_elem(@library.tag_pre, code).pack().spanned(span))
  } else {
    code
  }
}

///|
/// This is used by `RawElem::synthesize` through a routine.
///
/// It's a temporary workaround until `TextElem::fill` is supported in HTML
/// export.
pub fn html_span_filled(
  content : @library.Content,
  color : @library.Color,
) -> @library.Content {
  let span = content.span()
  html_elem(@library.tag_span, content)
  .with_css(
    @library.CssProperties::build(_ => ()).with_("color", color).finish(),
  )
  .pack()
  .spanned(span)
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
/// TODO: Upstream decodes the image (`ImageElem::decode`) and embeds it as a
/// base64 data URL (`typst_svg::WebImage`) in an `<img>` with `alt`,
/// `width`, `height` attributes and CSS sizing; image decoding is not ported
/// yet.
// Also check `PATCHED_IMAGE_RULE` in `docs/src/main.rs` when editing this.
fn image_rule(
  elem : @library.ImageElem,
  _ : @library.Engine,
  _ : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  unported(elem, "`ImageElem::decode`")
}

///|
fn equation_rule(
  elem : @library.EquationElem,
  engine : @library.Engine,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let content = elem.pack()
  let item = @library.resolve_equation(
    elem,
    engine,
    @library.Locator::synthesize(content.location().unwrap()),
    styles,
  )
  let block = elem.block(styles)
  let body = convert_math_to_nodes(item, engine, styles, block)
  let math = html_elem(
      @library.tag_mathml_math,
      @library.Content::sequence(body),
    )
    .with_optional_attr(
      @library.attr_mathml_display,
      if block {
        Some("block")
      } else {
        None
      },
    )
    .pack()
    .spanned(content.span())
  if block {
    block_packed(math)
  } else {
    math
  }
}

///|
/// Returns the body of a MathML `HtmlElem`, if the content is one.
pub fn html_mathml_body(
  content : @library.Content,
  styles : @library.StyleChain,
) -> @library.Content?? {
  guard @library.HtmlElem::of(content) is Some(elem) else { return None }
  if elem.tag().is_mathml() {
    Some(elem.body(styles))
  } else {
    None
  }
}
