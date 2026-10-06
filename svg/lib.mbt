// Port of `typst-svg/src/lib.rs`: rendering of Typst documents into SVG
// images.
//
// The `<defs>` IDs are hash-derived like upstream (`DedupId`); the hash
// inputs reproduce upstream's `Hash` byte streams (see `hash.mbt`).

///|
/// Settings for SVG export (upstream `SvgOptions<Partial>`).
pub(all) struct SvgOptions {
  /// By default, SVG documents are bounded to the page size. In some
  /// circumstances, such as when preparing documents for print, it may be
  /// desirable to include content beyond these bounds to account for bleed
  /// margins. This field allows expanding the document area to include such
  /// bleed.
  render_bleed : Bool
  /// Format options that override the defaults set by the document.
  format : PartialSvgFormatOptions
} derive(Eq, Default)

///|
pub extend SvgOptions with Default::{default}

///|
/// Resolved settings for SVG export (upstream `SvgOptions<Complete>`).
pub(all) struct CompleteSvgOptions {
  render_bleed : Bool
  format : SvgFormatOptions
} derive(Eq)

///|
/// Resolves the final options given those set by the document.
pub fn SvgOptions::resolve(
  self : SvgOptions,
  doc : SvgFormatOptions,
) -> CompleteSvgOptions {
  { render_bleed: self.render_bleed, format: self.format.resolve(doc), }
}

///|
/// Export a frame into an SVG file.
pub fn svg(page : @layout.Page, opts : CompleteSvgOptions) -> String {
  let (size, ts) = page_bleed(page, opts)
  let renderer = SVGRenderer::new()
  let xml = @xmlwriter.XmlWriter::new(xml_options(opts.format.pretty.v))
  let svg = svg_header(xml, size)
  let state = State::new(size)
  renderer.render_page(svg, state, ts, page)
  renderer.finalize(svg)
  xml.end_document()
}

///|
/// Export a page into an SVG file as part of a bundle.
///
/// Takes additional `anchor` locations that will be serialized as linkable
/// points. This enables other documents in the bundle to link into the
/// resulting SVG. Also takes a `link_resolver` for resolving cross-document
/// links.
pub fn svg_in_bundle(
  page : @layout.Page,
  opts : CompleteSvgOptions,
  anchors : ArrayView[(@library.Point, String)],
  link_resolver : @library.LateLinkResolver,
) -> String {
  let (size, ts) = page_bleed(page, opts)
  let renderer = SVGRenderer::with_options(Some(link_resolver))
  let xml = @xmlwriter.XmlWriter::new(xml_options(opts.format.pretty.v))
  let svg = svg_header(xml, size)
  let state = State::new(size)
  renderer.render_page(svg, state, ts, page)
  for anchor in anchors {
    let (pos, id) = anchor
    renderer.render_anchor(svg, pos, id)
  }
  renderer.finalize(svg)
  xml.end_document()
}

///|
/// Export a frame into an SVG suitable for embedding into HTML.
///
/// Takes additional `anchor` locations that will be serialized as linkable
/// points. This enables other documents in the bundle to link into the
/// resulting SVG. Also takes a `link_resolver` for resolving links between
/// the frame and remaining document.
pub fn svg_in_html(
  frame : @library.Frame,
  text_size : @library.Abs,
  pretty : Bool,
  id : String?,
  styles : String,
  anchors : ArrayView[(@library.Point, String)],
  link_resolver : @library.LateLinkResolver?,
) -> String {
  let renderer = SVGRenderer::with_options(link_resolver)
  let xml = @xmlwriter.XmlWriter::new(xml_options(pretty))
  let svg = svg_header_with_custom_attrs(xml, frame.size(), svg => {
    if id is Some(id) {
      svg.attr("id", id) |> ignore
    }
    svg.attr_with("style", attr => {
      // TODO: Maybe make this a little more elegant?
      attr.push_str("overflow: visible; width: ")
      attr.push_num(frame.width().ratio_to(text_size))
      attr.push_str("em; height: ")
      attr.push_num(frame.height().ratio_to(text_size))
      attr.push_str("em;")
      if !styles.is_empty() {
        attr.push_str(" ")
        attr.push_str(styles)
      }
    })
    |> ignore
  })
  let state = State::new(frame.size())
  renderer.render_frame(svg, state, frame)
  for anchor in anchors {
    let (pos, id) = anchor
    renderer.render_anchor(svg, pos, id)
  }
  renderer.finalize(svg)
  xml.end_document()
}

///|
/// Export a document with potentially multiple pages into a single SVG file.
///
/// The gap will be added between the individual pages.
pub fn svg_merged(
  document : @layout.PagedDocument,
  opts : SvgOptions,
  gap : @library.Abs,
) -> String {
  let opts = opts.resolve(SvgFormatOptions::get(document.options()))
  let pages = document.pages()
  let num_gaps = if pages.length() > 0 { pages.length() - 1 } else { 0 }
  let mut size : @library.Axes[@library.Abs] = {
    x: @library.Abs::zero(),
    y: gap.times(num_gaps.to_double()),
  }
  for page in pages {
    let (page_size, _ts) = page_bleed(page, opts)
    size = { x: size.x.max(page_size.x), y: size.y + page_size.y, }
  }
  let renderer = SVGRenderer::new()
  let xml = @xmlwriter.XmlWriter::new(xml_options(opts.format.pretty.v))
  let svg = svg_header(xml, size)
  let mut y = @library.Abs::zero()
  for page in pages {
    let (page_size, bleed_ts) = page_bleed(page, opts)
    let state = State::new(page_size)
    renderer.render_page(
      svg,
      state,
      @library.Transform::translate(@library.Abs::zero(), y).pre_concat(
        bleed_ts,
      ),
      page,
    )
    y = y + page_size.y + gap
  }
  renderer.finalize(svg)
  xml.end_document()
}

///|
fn page_bleed(
  page : @layout.Page,
  opts : CompleteSvgOptions,
) -> (@library.Axes[@library.Abs], @library.Transform) {
  let bleed = if opts.render_bleed {
    page.bleed
  } else {
    @library.Sides::splat(@library.Abs::zero())
  }
  let size = page.frame.size().add_size(bleed.sum_by_axis())
  let ts = @library.Transform::translate(bleed.left, bleed.top)
  (size, ts)
}

///|
fn xml_options(pretty : Bool) -> @xmlwriter.Options {
  {
    use_single_quote: false,
    indent: if pretty {
      Spaces(2)
    } else {
      None
    },
    attributes_indent: None,
  }
}

///|
/// Renders one or multiple frames to an SVG file.
priv struct SVGRenderer {
  /// The document's link resolver, if we're writing an HTML frame or a
  /// bundle page.
  link_resolver : @library.LateLinkResolver?
  /// Prepared glyphs.
  mut glyphs : Deduplicator[RenderedGlyph?]
  /// Clip paths are used to clip a group. A clip path is a path that defines
  /// the clipping region. The clip path is referenced by the `clip-path`
  /// attribute of the group. The clip path is in the format of
  /// `M x y L x y C x1 y1 x2 y2 x y Z`.
  clip_paths : Deduplicator[String]
  /// These are the actual gradients being written in the SVG file. These
  /// gradients are deduplicated because they do not contain the transform
  /// matrix, allowing them to be reused across multiple invocations.
  ///
  /// The `Ratio` is the aspect ratio of the gradient, this is used to correct
  /// the angle of the gradient.
  gradients : Deduplicator[(@library.Gradient, @library.Ratio)]
  /// Deduplicated gradients with transform matrices. They use a reference
  /// (`href`) to a "source" gradient instead of being defined inline. This
  /// saves a lot of space since gradients are often reused but with different
  /// transforms. Therefore this allows us to reuse the same gradient multiple
  /// times.
  gradient_refs : Deduplicator[GradientRef]
  /// These are the gradients that compose a conic gradient.
  conic_subgradients : Deduplicator[SVGSubGradient]
  /// These are the actual tilings being written in the SVG file. These
  /// tilings are deduplicated because they do not contain the transform
  /// matrix, allowing them to be reused across multiple invocations.
  tilings : Deduplicator[@library.Tiling]
  /// Deduplicated tilings with transform matrices. They use a reference
  /// (`href`) to a "source" tiling instead of being defined inline.
  tiling_refs : Deduplicator[TilingRef]
}

///|
/// Contextual information for rendering.
priv struct State {
  /// The transform of the current item.
  transform : @library.Transform
  /// The size of the first hard frame in the hierarchy.
  size : @library.Axes[@library.Abs]
}

///|
fn State::new(size : @library.Axes[@library.Abs]) -> State {
  { size, transform: @library.Transform::identity(), }
}

///|
/// Pre translate the current item's transform.
fn State::pre_translate(self : State, pos : @library.Point) -> State {
  self.pre_concat(@library.Transform::translate(pos.x, pos.y))
}

///|
/// Pre concat the current item's transform.
fn State::pre_concat(self : State, transform : @library.Transform) -> State {
  { ..self, transform: self.transform.pre_concat(transform), }
}

///|
/// Sets the size of the first hard frame in the hierarchy.
fn State::with_size(self : State, size : @library.Axes[@library.Abs]) -> State {
  { ..self, size, }
}

///|
/// Sets the current item's transform.
fn State::with_transform(self : State, transform : @library.Transform) -> State {
  { ..self, transform, }
}

///|
/// Create a new SVG renderer with empty glyph and clip path.
fn SVGRenderer::new() -> SVGRenderer {
  SVGRenderer::with_options(None)
}

///|
/// Create a new SVG renderer with the given configuration.
fn SVGRenderer::with_options(
  link_resolver : @library.LateLinkResolver?,
) -> SVGRenderer {
  {
    link_resolver,
    glyphs: Deduplicator::new('g'),
    clip_paths: Deduplicator::new('c'),
    gradients: Deduplicator::new('f'),
    gradient_refs: Deduplicator::new('r'),
    conic_subgradients: Deduplicator::new('s'),
    tilings: Deduplicator::new('t'),
    tiling_refs: Deduplicator::new('p'),
  }
}

///|
/// Render a page with the given transform.
fn SVGRenderer::render_page(
  self : SVGRenderer,
  svg : SvgElem,
  state : State,
  ts : @library.Transform,
  page : @layout.Page,
) -> Unit {
  let svg = svg.lazy_elem("g")
  if !ts.is_identity() {
    svg.init().attr("transform", SvgTransform(ts)) |> ignore
  }
  if page.fill_or_white() is Some(fill) {
    let shape = @library.Geometry::Rect(
      page.frame.size().add_size(page.bleed.sum_by_axis()),
    ).filled(fill)
    let state = state.pre_translate({ x: -page.bleed.left, y: -page.bleed.top, })
    self.render_shape(svg.lazy_(), state, shape)
  }
  self.render_frame(svg.lazy_(), state, page.frame)
  svg.finish()
}

///|
/// Render a frame with the given transform.
fn SVGRenderer::render_frame(
  self : SVGRenderer,
  svg : SvgElem,
  state : State,
  frame : @library.Frame,
) -> Unit {
  for entry in frame.items() {
    let (pos, item) = entry
    let state = state.pre_translate(pos)
    match item {
      Group(group) => self.render_group(svg, state, group)
      Text(text) => self.render_text(svg, state, text)
      Shape(shape, _) => self.render_shape(svg, state, shape)
      Image(image, size, _) => self.render_image(svg, state, image, size)
      Link(dest, size) => self.render_link(svg, state, dest, size)
      Tag(_) => ()
    }
  }
}

///|
/// Render a group. If the group has `clips` set to true, a clip path will be
/// created.
fn SVGRenderer::render_group(
  self : SVGRenderer,
  svg : SvgElem,
  state : State,
  group : @library.GroupItem,
) -> Unit {
  let svg = svg.lazy_elem("g")
  let state = match group.frame.kind() {
    Soft => state.pre_concat(group.transform)
    Hard => {
      // Always generate a group for hard frames.
      svg.init() |> ignore
      let transform = state.transform.pre_concat(group.transform)
      if !transform.is_identity() {
        svg.init().attr("transform", SvgTransform(transform)) |> ignore
      }
      state
      .with_transform(@library.Transform::identity())
      .with_size(group.frame.size())
    }
  }
  if group.label is Some(label) {
    svg.init().attr("data-typst-label", label.resolve()) |> ignore
  }
  if group.clip is Some(clip_curve) {
    let offset : @library.Point = {
      x: state.transform.tx,
      y: state.transform.ty,
    }
    let key = {
      let h = @library.SipHasher128::new()
      hash_curve(h, clip_curve)
      hash_point(h, offset)
      h.finish128()
    }
    let id = self.clip_paths.insert_with(key, () => {
      convert_curve(offset, clip_curve)
    })
    svg.init().attr("clip-path", SvgUrl(id)) |> ignore
  }
  self.render_frame(svg.lazy_(), state, group.frame)
  svg.finish()
}

///|
/// Render a link element.
fn SVGRenderer::render_link(
  self : SVGRenderer,
  svg : SvgElem,
  state : State,
  dest : @library.Destination,
  size : @library.Axes[@library.Abs],
) -> Unit {
  let a = svg.elem("a")
  if !state.transform.is_identity() {
    a.attr("transform", SvgTransform(state.transform)) |> ignore
  }
  match dest {
    Url(url) => {
      let url = url.into_inner()
      a.attr("href", url).attr("xlink:href", url) |> ignore
    }
    Position(_) =>
      // TODO: Links on the same page could be supported.
      ()
    Location(loc) =>
      // TODO: Location links on the same page could also be supported
      // outside of HTML.
      if self.link_resolver is Some(resolver) &&
        resolver.resolve(loc) is Some(link) {
        let uri = link.into_relative_uri() catch { _ => "" }
        if !uri.is_empty() {
          a.attr("href", uri).attr("xlink:href", uri) |> ignore
        }
      }
  }
  a
  .elem("rect")
  .attr("width", size.x.to_pt())
  .attr("height", size.y.to_pt())
  .attr("fill", "transparent")
  .attr("stroke", "none")
  .end()
  a.end()
}

///|
/// Renders a linkable point that can be used to link into an HTML frame.
fn SVGRenderer::render_anchor(
  _self : SVGRenderer,
  svg : SvgElem,
  pos : @library.Point,
  id : String,
) -> Unit {
  svg
  .elem("g")
  .attr("id", id)
  .attr("transform", SvgTransform(@library.Transform::translate(pos.x, pos.y)))
  .end()
}

///|
/// Finalize the SVG file. This must be called after all rendering is done.
fn SVGRenderer::finalize(self : SVGRenderer, svg : SvgElem) -> Unit {
  self.write_glyph_defs(svg)
  self.write_clip_path_defs(svg)
  self.write_gradients(svg)
  self.write_gradient_refs(svg)
  self.write_subgradients(svg)
  self.write_tilings(svg)
  self.write_tiling_refs(svg)
}

///|
/// Build the clip path definitions.
fn SVGRenderer::write_clip_path_defs(self : SVGRenderer, svg : SvgElem) -> Unit {
  if self.clip_paths.is_empty() {
    return
  }
  let defs = svg.elem("defs")
  for entry in self.clip_paths.iter() {
    let (id, path) = entry
    let clip = defs.elem("clipPath").attr("id", id)
    clip.elem("path").attr("d", path).end()
    clip.end()
  }
  defs.end()
}

///|
/// Write the default SVG header, including a `typst-doc` class, the
/// `viewBox` and `width` and `height` attributes.
fn svg_header(
  xml : @xmlwriter.XmlWriter,
  size : @library.Axes[@library.Abs],
) -> SvgElem {
  svg_header_with_custom_attrs(xml, size, _ => ())
}

///|
/// Write the SVG header with additional attributes and standard attributes.
fn svg_header_with_custom_attrs(
  xml : @xmlwriter.XmlWriter,
  size : @library.Axes[@library.Abs],
  write_custom_attrs : (SvgElem) -> Unit,
) -> SvgElem {
  // Clamp the size of SVGs to at least one pt. resvg and probably also
  // other SVG parsers don't handle SVGs with 0 sized dimensions.
  let one = @library.Abs::pt(1.0)
  let size : @library.Axes[@library.Abs] = {
    x: size.x.max(one),
    y: size.y.max(one),
  }
  let svg = SvgElem::new(xml, "svg")
  write_custom_attrs(svg)
  svg.attr_with("viewBox", attr => {
    attr.push_nums([0.0, 0.0, size.x.to_pt(), size.y.to_pt()])
  })
  |> ignore
  svg.attr_with("width", attr => {
    attr.push_num(size.x.to_pt())
    attr.push_str("pt")
  })
  |> ignore
  svg.attr_with("height", attr => {
    attr.push_num(size.y.to_pt())
    attr.push_str("pt")
  })
  |> ignore
  svg.attr("xmlns", "http://www.w3.org/2000/svg") |> ignore
  svg.attr("xmlns:xlink", "http://www.w3.org/1999/xlink") |> ignore
  svg.attr("xmlns:h5", "http://www.w3.org/1999/xhtml") |> ignore
  svg
}

///|
/// Deduplicates its elements. It is used to deduplicate glyphs and clip
/// paths. The `kind` is the prefix of the index. This is used to distinguish
/// between glyphs and clip paths.
priv struct Deduplicator[T] {
  kind : Char
  /// Insertion-ordered (like upstream's `IndexMap`).
  map : Map[@library.U128, T]
}

///|
fn[T] Deduplicator::new(kind : Char) -> Deduplicator[T] {
  { kind, map: {}, }
}

///|
/// Inserts a value. If the hash is already present, returns the id of the
/// existing value and `f` will not be called. Otherwise, inserts the value
/// and returns the id of the inserted value.
fn[T] Deduplicator::insert_with(
  self : Deduplicator[T],
  hash : @library.U128,
  f : () -> T,
) -> DedupId {
  self.insert_with_val(hash, f).0
}

///|
/// Same as [Deduplicator::insert_with], but it also returns the cached or
/// inserted value.
fn[T] Deduplicator::insert_with_val(
  self : Deduplicator[T],
  hash : @library.U128,
  f : () -> T,
) -> (DedupId, T) {
  let val = match self.map.get(hash) {
    Some(v) => v
    None => {
      let v = f()
      self.map[hash] = v
      v
    }
  }
  ({ kind: self.kind, hash, }, val)
}

///|
/// Iterate over the elements alongside their ids.
fn[T] Deduplicator::iter(self : Deduplicator[T]) -> Array[(DedupId, T)] {
  self.map.iter().map(e => ({ kind: self.kind, hash: e.0, }, e.1)).collect()
}

///|
/// Returns true if the deduplicator is empty.
fn[T] Deduplicator::is_empty(self : Deduplicator[T]) -> Bool {
  self.map.is_empty()
}

///|
/// Identifies a `<def>`.
pub(all) struct DedupId {
  kind : Char
  hash : @library.U128
} derive(Eq, Hash)

///|
pub impl SvgDisplay for DedupId with fn fmt(self, f) {
  f.push_char(self.kind)
  let digits = StringBuilder()
  let hex = "0123456789ABCDEF"
  for word in [self.hash.hi, self.hash.lo] {
    for i = 15; i >= 0; i = i - 1 {
      let nibble = ((word >> (i * 4)) & 0xF).to_int()
      digits.write_char(hex.unsafe_get(nibble).unsafe_to_char())
    }
  }
  let digits = digits.to_string()
  let mut start = 0
  while start < digits.length() && digits.unsafe_get(start) == '0' {
    start += 1
  }
  f.push_str(digits.unsafe_substring(start~, end=digits.length()))
}
