// Port of `usvg` 0.47.0 `src/text/layout.rs`: text layout (shaping, BIDI
// reordering, positioning and decorations).
//
// Byte indices are UTF-8 byte offsets into the chunk text, like upstream.

///|
/// A glyph that has already been positioned correctly.
///
/// Note that the transform already takes the font size into consideration, so applying the
/// transform to the outline of the glyphs is all that is necessary to display it correctly.
pub struct PositionedGlyph {
  /// Returns the transform of the glyph itself within the cluster. For example,
  /// for zalgo text, it contains the transform to position the glyphs above/below
  /// the main glyph.
  priv glyph_ts : Transform
  /// Returns the transform of the whole cluster that the glyph is part of.
  priv mut cluster_ts : Transform
  /// Returns the transform of the span that the glyph is a part of.
  priv mut span_ts : Transform
  /// The units per em of the font the glyph belongs to.
  priv units_per_em : Int
  /// The font size the glyph should be scaled to.
  priv font_size : Float
  /// The ID of the glyph.
  id : Int
  /// The text from the original string that corresponds to that glyph.
  text : String
  /// The ID of the font the glyph should be taken from. Can be used with the
  /// [font database of the tree](crate::Tree::fontdb) this glyph is part of.
  font : FontId
}

///|
fn PositionedGlyph::clone(self : PositionedGlyph) -> PositionedGlyph {
  { ..self, }
}

///|
/// Returns the font size for this glyph.
pub fn PositionedGlyph::font_size(self : PositionedGlyph) -> Float {
  self.font_size
}

///|
/// Returns the transform of glyph.
pub fn PositionedGlyph::transform(self : PositionedGlyph) -> Transform {
  let sx = self.font_size / Float::from_int(self.units_per_em)
  self.span_ts
  .pre_concat(self.cluster_ts)
  .pre_concat(Transform::from_scale(sx, sx))
  .pre_concat(self.glyph_ts)
}

///|
/// Returns the transform of glyph, assuming that an outline
/// glyph is being used (i.e. from the `glyf` or `CFF/CFF2` table).
pub fn PositionedGlyph::outline_transform(self : PositionedGlyph) -> Transform {
  // Outlines are mirrored by default.
  self.transform().pre_concat(Transform::from_scale(1.0, -1.0))
}

///|
/// Returns the transform for the glyph, assuming that a CBTD-based raster glyph
/// is being used.
pub fn PositionedGlyph::cbdt_transform(
  self : PositionedGlyph,
  x : Float,
  y : Float,
  pixels_per_em : Float,
  height : Float,
) -> Transform {
  self
  .transform()
  .pre_concat(
    Transform::from_scale(
      Float::from_int(self.units_per_em) / pixels_per_em,
      Float::from_int(self.units_per_em) / pixels_per_em,
    ),
  )
  // Right now, the top-left corner of the image would be placed in
  // on the "text cursor", but we want the bottom-left corner to be there,
  // so we need to shift it up and also apply the x/y offset.
  .pre_translate(x, -height - y)
}

///|
/// Returns the transform for the glyph, assuming that a sbix-based raster glyph
/// is being used.
pub fn PositionedGlyph::sbix_transform(
  self : PositionedGlyph,
  x : Float,
  y : Float,
  x_min : Float,
  y_min : Float,
  pixels_per_em : Float,
  height : Float,
) -> Transform {
  // In contrast to CBDT, we also need to look at the outline bbox of the glyph and add a shift if necessary.
  let bbox_x_shift = -x_min
  let bbox_y_shift = if approx_zero_ulps(y_min, 4) {
    // For unknown reasons, using Apple Color Emoji will lead to a vertical shift on MacOS, but this shift
    // doesn't seem to be coming from the font and most likely is somehow hardcoded. On Windows,
    // this shift will not be applied. However, if this shift is not applied the emojis are a bit
    // too high up when being together with other text, so we try to imitate this.
    // See also https://github.com/harfbuzz/harfbuzz/issues/2679#issuecomment-1345595425
    // So whenever the y-shift is 0, we approximate this vertical shift that seems to be produced by it.
    // This value seems to be pretty close to what is happening on MacOS.
    // We can still remove this if it turns out to be a problem, but Apple Color Emoji is pretty
    // much the only `sbix` font out there and they all seem to have a y-shift of 0, so it
    // makes sense to keep it.
    (0.128 : Float) * Float::from_int(self.units_per_em)
  } else {
    -y_min
  }
  self
  .transform()
  .pre_concat(Transform::from_translate(bbox_x_shift, bbox_y_shift))
  .pre_concat(
    Transform::from_scale(
      Float::from_int(self.units_per_em) / pixels_per_em,
      Float::from_int(self.units_per_em) / pixels_per_em,
    ),
  )
  // Right now, the top-left corner of the image would be placed in
  // on the "text cursor", but we want the bottom-left corner to be there,
  // so we need to shift it up and also apply the x/y offset.
  .pre_translate(x, -height - y)
}

///|
/// Returns the transform for the glyph, assuming that an SVG glyph is
/// being used.
pub fn PositionedGlyph::svg_transform(self : PositionedGlyph) -> Transform {
  self.transform()
}

///|
/// Returns the transform for the glyph, assuming that a COLR glyph is
/// being used.
pub fn PositionedGlyph::colr_transform(self : PositionedGlyph) -> Transform {
  self.outline_transform()
}

///|
/// A span contains a number of layouted glyphs that share the same fill, stroke, paint order and
/// visibility (upstream `layout::Span`).
pub struct LayoutSpan {
  /// The fill of the span.
  priv mut fill : Fill?
  /// The stroke of the span.
  priv mut stroke : Stroke?
  /// The paint order of the span.
  paint_order : PaintOrder
  /// The font size of the span.
  font_size : NonZeroPositiveF32
  /// Font variation settings for variable fonts.
  variations : Array[FontVariation]
  /// Font optical sizing mode.
  font_optical_sizing : FontOpticalSizing
  /// The visibility of the span.
  visible : Bool
  /// The glyphs that make up the span.
  positioned_glyphs : Array[PositionedGlyph]
  /// An underline text decoration of the span.
  /// Needs to be rendered before all glyphs.
  underline : Path?
  /// An overline text decoration of the span.
  /// Needs to be rendered before all glyphs.
  overline : Path?
  /// A line-through text decoration of the span.
  /// Needs to be rendered after all glyphs.
  line_through : Path?
}

///|
fn LayoutSpan::clone(self : LayoutSpan) -> LayoutSpan {
  {
    ..self,
    positioned_glyphs: self.positioned_glyphs.map(PositionedGlyph::clone),
    underline: self.underline.map(Path::clone),
    overline: self.overline.map(Path::clone),
    line_through: self.line_through.map(Path::clone),
  }
}

///|
/// The fill of the span.
pub fn LayoutSpan::fill(self : LayoutSpan) -> Fill? {
  self.fill
}

///|
/// The stroke of the span.
pub fn LayoutSpan::stroke(self : LayoutSpan) -> Stroke? {
  self.stroke
}

///|
priv struct GlyphCluster {
  byte_idx : Int
  codepoint : Char
  mut width : Float
  mut advance : Float
  mut ascent : Float
  mut descent : Float
  mut has_relative_shift : Bool
  mut glyphs : Array[PositionedGlyph]
  mut transform : Transform
  mut path_transform : Transform
  mut visible : Bool
}

///|
fn GlyphCluster::clone(self : GlyphCluster) -> GlyphCluster {
  { ..self, glyphs: self.glyphs.map(PositionedGlyph::clone), }
}

///|
fn GlyphCluster::height(self : GlyphCluster) -> Float {
  self.ascent - self.descent
}

///|
fn GlyphCluster::full_transform(self : GlyphCluster) -> Transform {
  self.path_transform.post_concat(self.transform)
}

///|
/// The resolved fonts of a text (upstream `FontsCache`, a `HashMap` keyed by
/// `Font`).
priv struct FontsCache {
  entries : Array[(Font, ResolvedFont)]
}

///|
fn FontsCache::get(self : FontsCache, font : Font) -> ResolvedFont? {
  for e in self.entries {
    if e.0 == font {
      return Some(e.1)
    }
  }
  None
}

///|
fn FontsCache::contains(self : FontsCache, font : Font) -> Bool {
  self.get(font) is Some(_)
}

///|
fn layout_text(
  text_node : Text,
  resolver : FontResolver,
  fontdb : FontDatabase,
) -> (Array[LayoutSpan], NonZeroRect)? {
  let fonts_cache : FontsCache = { entries: [], }
  for chunk in text_node.chunks {
    for span in chunk.spans {
      if !fonts_cache.contains(span.font) {
        let font = match (resolver.select_font)(span.font, fontdb) {
          Some(id) => fontdb.load_font(id)
          None => None
        }
        if font is Some(font) {
          fonts_cache.entries.push((span.font, font))
        }
      }
    }
  }
  let spans = []
  let mut char_offset = 0
  let mut last_x : Float = 0.0
  let mut last_y : Float = 0.0
  let mut bbox = BBox::default()
  for chunk in text_node.chunks {
    let (x, y) = match chunk.text_flow {
      Linear => (chunk.x.unwrap_or(last_x), chunk.y.unwrap_or(last_y))
      Path(_) => (0.0, 0.0)
    }
    let clusters = process_chunk(chunk, fonts_cache, resolver, fontdb)
    if clusters.is_empty() {
      char_offset += chunk.text.char_count()
      continue
    }
    apply_writing_mode(text_node.writing_mode, clusters)
    apply_letter_spacing(chunk, clusters)
    apply_word_spacing(chunk, clusters)
    apply_length_adjust(chunk, clusters)
    let mut curr_pos = resolve_clusters_positions(
      text_node,
      chunk,
      char_offset,
      text_node.writing_mode,
      fonts_cache,
      clusters,
    )
    let mut text_ts = Transform::default()
    if text_node.writing_mode == TopToBottom {
      if chunk.text_flow is Linear {
        text_ts = text_ts.pre_rotate_at(90.0, x, y)
      }
    }
    for span in chunk.spans {
      let font = match fonts_cache.get(span.font) {
        Some(v) => v
        None => continue
      }
      let decoration_spans = collect_decoration_spans(span, clusters)
      let mut span_ts = text_ts
      span_ts = span_ts.pre_translate(x, y)
      if chunk.text_flow is Linear {
        let shift = resolve_baseline(span, font, text_node.writing_mode)

        // In case of a horizontal flow, shift transform and not clusters,
        // because clusters can be rotated and an additional shift will lead
        // to invalid results.
        span_ts = span_ts.pre_translate(0.0, shift)
      }
      let mut underline = None
      let mut overline = None
      let mut line_through = None
      if span.decoration.underline is Some(decoration) {
        // TODO: No idea what offset should be used for top-to-bottom layout.
        // There is
        // https://www.w3.org/TR/css-text-decor-3/#text-underline-position-property
        // but it doesn't go into details.
        let offset = match text_node.writing_mode {
          LeftToRight => -font.underline_position(span.font_size.get())
          TopToBottom => font.height(span.font_size.get()) / 2.0
        }
        if convert_decoration(
            offset, span, font, decoration, decoration_spans, span_ts,
          )
          is Some(path) {
          bbox = bbox.expand(BBox::from_rect(path.data.bounds()))
          underline = Some(path)
        }
      }
      if span.decoration.overline is Some(decoration) {
        let offset = match text_node.writing_mode {
          LeftToRight => -font.ascent(span.font_size.get())
          TopToBottom => -font.height(span.font_size.get()) / 2.0
        }
        if convert_decoration(
            offset, span, font, decoration, decoration_spans, span_ts,
          )
          is Some(path) {
          bbox = bbox.expand(BBox::from_rect(path.data.bounds()))
          overline = Some(path)
        }
      }
      if span.decoration.line_through is Some(decoration) {
        let offset = match text_node.writing_mode {
          LeftToRight => -font.line_through_position(span.font_size.get())
          TopToBottom => 0.0
        }
        if convert_decoration(
            offset, span, font, decoration, decoration_spans, span_ts,
          )
          is Some(path) {
          bbox = bbox.expand(BBox::from_rect(path.data.bounds()))
          line_through = Some(path)
        }
      }

      // The `fill-rule` should be ignored.
      // https://www.w3.org/TR/SVG2/text.html#TextRenderingOrder
      //
      // 'Since the fill-rule property does not apply to SVG text elements,
      // the specific order of the subpaths within the equivalent path does not matter.'
      let fill = span.fill.map(f => { ..f, rule: NonZero, })
      if convert_span(span, clusters, span_ts)
        is Some((span_fragments, span_bbox)) {
        bbox = bbox.expand(BBox::from_non_zero_rect(span_bbox))
        let positioned_glyphs = []
        for gc in span_fragments {
          let cluster_ts = gc.full_transform()
          for pg in gc.glyphs {
            pg.cluster_ts = cluster_ts
            pg.span_ts = span_ts
            positioned_glyphs.push(pg)
          }
        }
        spans.push({
          fill,
          stroke: span.stroke,
          paint_order: span.paint_order,
          font_size: span.font_size,
          variations: span.font.variations,
          font_optical_sizing: span.font_optical_sizing,
          visible: span.visible,
          positioned_glyphs,
          underline,
          overline,
          line_through,
        })
      }
    }
    char_offset += chunk.text.char_count()
    if text_node.writing_mode == TopToBottom {
      if chunk.text_flow is Linear {
        curr_pos = (curr_pos.1, curr_pos.0)
      }
    }
    last_x = x + curr_pos.0
    last_y = y + curr_pos.1
  }
  guard bbox.to_non_zero_rect() is Some(bbox) else { return None }
  Some((spans, bbox))
}

///|
fn convert_span(
  span : TextSpan,
  clusters : Array[GlyphCluster],
  text_ts : Transform,
) -> (Array[GlyphCluster], NonZeroRect)? {
  let span_clusters = []
  let bboxes_builder = @tiny_skia_path.PathBuilder::new()
  for cluster in clusters {
    if !cluster.visible {
      continue
    }
    if span_contains(span, cluster.byte_idx) {
      span_clusters.push(cluster.clone())
    }
    let mut advance = cluster.advance
    if advance <= 0.0 {
      advance = 1.0
    }

    // We have to calculate text bbox using font metrics and not glyph shape.
    if NonZeroRect::from_xywh(0.0, -cluster.ascent, advance, cluster.height())
      is Some(r) {
      if r.transform(cluster.full_transform()) is Some(r) {
        bboxes_builder.push_rect(r.to_rect())
      }
    }
  }
  guard bboxes_builder.finish() is Some(bboxes) else { return None }
  guard bboxes.transform(text_ts) is Some(bboxes) else { return None }
  guard bboxes.compute_tight_bounds() is Some(bbox) else { return None }
  guard bbox.to_non_zero_rect() is Some(bbox) else { return None }
  Some((span_clusters, bbox))
}

///|
fn collect_decoration_spans(
  span : TextSpan,
  clusters : Array[GlyphCluster],
) -> Array[DecorationSpan] {
  let spans = []
  let mut started = false
  let mut width : Float = 0.0
  let mut transform = Transform::default()
  for cluster in clusters {
    if span_contains(span, cluster.byte_idx) {
      if started && cluster.has_relative_shift {
        started = false
        spans.push({ width, transform, })
      }
      if !started {
        width = cluster.advance
        started = true
        transform = cluster.transform
      } else {
        width += cluster.advance
      }
    } else if started {
      spans.push({ width, transform, })
      started = false
    }
  }
  if started {
    spans.push({ width, transform, })
  }
  spans
}

///|
fn convert_decoration(
  dy : Float,
  span : TextSpan,
  font : ResolvedFont,
  decoration : TextDecorationStyle,
  decoration_spans : Array[DecorationSpan],
  transform : Transform,
) -> Path? {
  let thickness = font.underline_thickness(span.font_size.get())
  let builder = @tiny_skia_path.PathBuilder::new()
  for dec_span in decoration_spans {
    let rect = match
      NonZeroRect::from_xywh(0.0, -thickness / 2.0, dec_span.width, thickness) {
      Some(v) => v
      None =>
        // Upstream warns: a decoration span has a malformed bbox
        continue
    }
    let ts = dec_span.transform.pre_translate(0.0, dy)
    let path = @tiny_skia_path.PathBuilder::from_rect(rect.to_rect())
    let path = match path.transform(ts) {
      Some(v) => v
      None => continue
    }
    builder.push_path(path)
  }
  guard builder.finish() is Some(path_data) else { return None }
  guard path_data.transform(transform) is Some(path_data) else { return None }
  Path::new(
    "",
    span.visible,
    decoration.fill,
    decoration.stroke,
    PaintOrder::default(),
    ShapeRendering::default(),
    path_data,
    Transform::default(),
  )
}

///|
/// A text decoration span.
///
/// Basically a horizontal line, that will be used for underline, overline and line-through.
/// It doesn't have a height, since it depends on the Font metrics.
priv struct DecorationSpan {
  width : Float
  transform : Transform
}

///|
/// Resolves clusters positions.
///
/// Mainly sets the `transform` property.
///
/// Returns the last text position. The next text chunk should start from that position.
fn resolve_clusters_positions(
  text : Text,
  chunk : TextChunk,
  char_offset : Int,
  writing_mode : WritingMode,
  fonts_cache : FontsCache,
  clusters : Array[GlyphCluster],
) -> (Float, Float) {
  match chunk.text_flow {
    Linear =>
      resolve_clusters_positions_horizontal(
        text, chunk, char_offset, writing_mode, clusters,
      )
    Path(path) =>
      resolve_clusters_positions_path(
        text, chunk, char_offset, path, writing_mode, fonts_cache, clusters,
      )
  }
}

///|
fn clusters_length(clusters : Array[GlyphCluster]) -> Float {
  let mut w : Float = 0.0
  for cluster in clusters {
    w = w + cluster.advance
  }
  w
}

///|
fn resolve_clusters_positions_horizontal(
  text : Text,
  chunk : TextChunk,
  offset : Int,
  writing_mode : WritingMode,
  clusters : Array[GlyphCluster],
) -> (Float, Float) {
  let mut x = process_anchor(chunk.anchor, clusters_length(clusters))
  let mut y : Float = 0.0
  for cluster in clusters {
    let cp = offset + code_point_at(chunk.text, cluster.byte_idx)
    if (text.dx.get(cp), text.dy.get(cp)) is (Some(dx), Some(dy)) {
      if writing_mode == LeftToRight {
        x += dx
        y += dy
      } else {
        y -= dx
        x += dy
      }
      cluster.has_relative_shift = !approx_zero_ulps(dx, 4) ||
        !approx_zero_ulps(dy, 4)
    }
    cluster.transform = cluster.transform.pre_translate(x, y)
    if text.rotate.get(cp) is Some(angle) {
      if !approx_zero_ulps(angle, 4) {
        cluster.transform = cluster.transform.pre_rotate(angle)
        cluster.has_relative_shift = true
      }
    }
    x += cluster.advance
  }
  (x, y)
}

///|
// Baseline resolving in SVG is a mess.
// Not only it's poorly documented, but as soon as you start mixing
// `dominant-baseline` and `alignment-baseline` each application/browser will produce
// different results.
//
// For now, resvg simply tries to match Chrome's output and not the mythical SVG spec output.
//
// See `alignment_baseline_shift` method comment for more details.
fn resolve_baseline(
  span : TextSpan,
  font : ResolvedFont,
  writing_mode : WritingMode,
) -> Float {
  let mut shift = -resolve_baseline_shift(
    span.baseline_shift,
    font,
    span.font_size.get(),
  )

  // TODO: support vertical layout as well
  if writing_mode == LeftToRight {
    if span.alignment_baseline == AlignmentBaseline::Auto ||
      span.alignment_baseline == AlignmentBaseline::Baseline {
      shift += font.dominant_baseline_shift(
        span.dominant_baseline,
        span.font_size.get(),
      )
    } else {
      shift += font.alignment_baseline_shift(
        span.alignment_baseline,
        span.font_size.get(),
      )
    }
  }
  shift
}

///|
fn resolve_baseline_shift(
  baselines : Array[BaselineShift],
  font : ResolvedFont,
  font_size : Float,
) -> Float {
  let mut shift : Float = 0.0
  for i = baselines.length() - 1; i >= 0; i = i - 1 {
    match baselines[i] {
      Baseline => ()
      Subscript => shift -= font.subscript_offset(font_size)
      Superscript => shift += font.superscript_offset(font_size)
      Number(n) => shift += n
    }
  }
  shift
}

///|
fn resolve_clusters_positions_path(
  text : Text,
  chunk : TextChunk,
  char_offset : Int,
  path : TextPath,
  writing_mode : WritingMode,
  fonts_cache : FontsCache,
  clusters : Array[GlyphCluster],
) -> (Float, Float) {
  let mut last_x : Float = 0.0
  let mut last_y : Float = 0.0
  let mut dy : Float = 0.0

  // In the text path mode, chunk's x/y coordinates provide an additional offset along the path.
  // The X coordinate is used in a horizontal mode, and Y in vertical.
  let chunk_offset = match writing_mode {
    LeftToRight => chunk.x.unwrap_or(0.0)
    TopToBottom => chunk.y.unwrap_or(0.0)
  }
  let start_offset = chunk_offset +
    path.start_offset +
    process_anchor(chunk.anchor, clusters_length(clusters))
  let normals = collect_normals(
    text,
    chunk,
    clusters,
    path.path,
    char_offset,
    start_offset,
  )
  for i, cluster in clusters {
    if i >= normals.length() {
      break
    }
    let (x, y, angle) = match normals[i] {
      Some(normal) => (normal.x, normal.y, normal.angle)
      None => {
        // Hide clusters that are outside the text path.
        cluster.visible = false
        continue
      }
    }

    // We have to break a decoration line for each cluster during text-on-path.
    cluster.has_relative_shift = true
    let orig_ts = cluster.transform

    // Clusters should be rotated by the x-midpoint x baseline position.
    let half_width = cluster.width / 2.0
    cluster.transform = Transform::default()
    cluster.transform = cluster.transform.pre_translate(x - half_width, y)
    cluster.transform = cluster.transform.pre_rotate_at(angle, half_width, 0.0)
    let cp = char_offset + code_point_at(chunk.text, cluster.byte_idx)
    dy += text.dy.get(cp).unwrap_or(0.0)
    let baseline_shift = match chunk_span_at(chunk, cluster.byte_idx) {
      Some(span) =>
        match fonts_cache.get(span.font) {
          Some(font) => -resolve_baseline(span, font, writing_mode)
          None => 0.0
        }
      None => 0.0
    }

    // Shift only by `dy` since we already applied `dx`
    // during offset along the path calculation.
    if !approx_zero_ulps(dy, 4) || !approx_zero_ulps(baseline_shift, 4) {
      let shift_y = (dy - baseline_shift).to_double()
      cluster.transform = cluster.transform.pre_translate(
        0.0,
        Float::from_double(shift_y),
      )
    }
    if text.rotate.get(cp) is Some(angle) {
      if !approx_zero_ulps(angle, 4) {
        cluster.transform = cluster.transform.pre_rotate(angle)
      }
    }

    // The possible `lengthAdjust` transform should be applied after text-on-path positioning.
    cluster.transform = cluster.transform.pre_concat(orig_ts)
    last_x = x + cluster.advance
    last_y = y
  }
  (last_x, last_y)
}

///|
fn process_anchor(a : TextAnchor, text_width : Float) -> Float {
  match a {
    Start => 0.0 // Nothing.
    Middle => -text_width / 2.0
    End => -text_width
  }
}

///|
priv struct PathNormal {
  x : Float
  y : Float
  angle : Float
}

///|
fn create_curve_from_line(
  px : Float,
  py : Float,
  x : Float,
  y : Float,
) -> KCubicBez {
  let p0 : KPoint = { x: px.to_double(), y: py.to_double(), }
  let p3 : KPoint = { x: x.to_double(), y: y.to_double(), }
  let p1 = kline_eval(p0, p3, 0.33)
  let p2 = kline_eval(p0, p3, 0.66)
  { p0, p1, p2, p3, }
}

///|
/// Converts a path segment into a cubic (upstream's inline match in
/// `collect_normals` and `path_length`); `None` for `MoveTo`.
fn segment_curve(
  seg : @tiny_skia_path.PathSegment,
  prev_x : Float,
  prev_y : Float,
  prev_mx : Float,
  prev_my : Float,
) -> KCubicBez? {
  let kp = (p : @tiny_skia_path.Point) => {
    ({ x: p.x.to_double(), y: p.y.to_double(), } : KPoint)
  }
  match seg {
    MoveTo(_) => None
    LineTo(p) => Some(create_curve_from_line(prev_x, prev_y, p.x, p.y))
    QuadTo(p1, p) =>
      Some(
        (
          {
            p0: { x: prev_x.to_double(), y: prev_y.to_double(), },
            p1: kp(p1),
            p2: kp(p),
          } : KQuadBez).raise_(),
      )
    CubicTo(p1, p2, p) =>
      Some({
        p0: { x: prev_x.to_double(), y: prev_y.to_double(), },
        p1: kp(p1),
        p2: kp(p2),
        p3: kp(p),
      })
    Close => Some(create_curve_from_line(prev_x, prev_y, prev_mx, prev_my))
  }
}

///|
fn collect_normals(
  text : Text,
  chunk : TextChunk,
  clusters : Array[GlyphCluster],
  path : TinyPath,
  char_offset : Int,
  offset : Float,
) -> Array[PathNormal?] {
  let offsets : Array[Double] = []
  let normals : Array[PathNormal?] = []
  {
    let mut advance = offset
    for cluster in clusters {
      // Clusters should be rotated by the x-midpoint x baseline position.
      let half_width = cluster.width / 2.0

      // Include relative position.
      let cp = char_offset + code_point_at(chunk.text, cluster.byte_idx)
      advance += text.dx.get(cp).unwrap_or(0.0)
      let offset = advance + half_width

      // Clusters outside the path have no normals.
      if offset < 0.0 {
        normals.push(None)
      }
      offsets.push(offset.to_double())
      advance += cluster.advance
    }
  }
  let mut prev_mx = path.points()[0].x
  let mut prev_my = path.points()[0].y
  let mut prev_x = prev_mx
  let mut prev_y = prev_my
  let mut length : Double = 0.0
  let iter = path.segments()
  while iter.next() is Some(seg) {
    if seg is MoveTo(p) {
      prev_mx = p.x
      prev_my = p.y
      prev_x = p.x
      prev_y = p.y
      continue
    }
    let curve = segment_curve(seg, prev_x, prev_y, prev_mx, prev_my).unwrap()
    let arclen_accuracy = {
      let base_arclen_accuracy : Float = 0.5
      // Accuracy depends on a current scale.
      // When we have a tiny path scaled by a large value,
      // we have to increase out accuracy accordingly.
      let (sx, sy) = text.abs_transform.get_scale()
      // 1.0 acts as a threshold to prevent division by 0 and/or low accuracy.
      base_arclen_accuracy / (sx * sy).sqrt().max(1.0)
    }
    let curve_len = curve.arclen(arclen_accuracy.to_double())
    let mut k = normals.length()
    while k < offsets.length() {
      let offset = offsets[k]
      k += 1
      if offset >= length && offset <= length + curve_len {
        let mut offset = curve.inv_arclen(
          offset - length,
          arclen_accuracy.to_double(),
        )
        // some rounding error may occur, so we give offset a little tolerance
        offset = offset.clamp(min=0.0, max=1.0)
        let pos = curve.eval(offset)
        let d = curve.deriv().eval(offset)
        let d : KPoint = { x: -d.y, y: d.x, } // tangent
        let angle = libm_atan2(d.y, d.x) * (180.0 / k_pi) - 90.0
        normals.push(
          Some({
            x: Float::from_double(pos.x),
            y: Float::from_double(pos.y),
            angle: Float::from_double(angle),
          }),
        )
        if normals.length() == offsets.length() {
          break
        }
      }
    }
    length += curve_len
    prev_x = Float::from_double(curve.p3.x)
    prev_y = Float::from_double(curve.p3.y)
  }

  // If path ended and we still have unresolved normals - set them to `None`.
  for _ in 0..<(offsets.length() - normals.length()) {
    normals.push(None)
  }
  normals
}

///|
/// Converts a text chunk into a list of outlined clusters.
///
/// This function will do the BIDI reordering, text shaping and glyphs outlining,
/// but not the text layouting. So all clusters are in the 0x0 position.
fn process_chunk(
  chunk : TextChunk,
  fonts_cache : FontsCache,
  resolver : FontResolver,
  fontdb : FontDatabase,
) -> Array[GlyphCluster] {
  // The way this function works is a bit tricky.
  //
  // The first problem is BIDI reordering.
  // We cannot shape text span-by-span, because glyph clusters are not guarantee to be continuous.
  //
  // For example:
  // <text>Hel<tspan fill="url(#lg1)">lo של</tspan>ום.</text>
  //
  // Would be shaped as:
  // H e l l o   ש ל  ו  ם .   (characters)
  // 0 1 2 3 4 5 12 10 8 6 14  (cluster indices in UTF-8)
  //       ---         ---     (green span)
  //
  // As you can see, our continuous `lo של` span was split into two separated one.
  // So our 3 spans: black - green - black, become 5 spans: black - green - black - green - black.
  // If we shape `Hel`, then `lo של` an then `ום` separately - we would get an incorrect output.
  // To properly handle this we simply shape the whole chunk.
  //
  // But this introduces another issue - what to do when we have multiple fonts?
  // The easy solution would be to simply shape text with each font,
  // where the first font output is used as a base one and all others overwrite it.
  // This way in case of:
  // <text font-family="Arial">Hello <tspan font-family="Helvetica">world</tspan></text>
  // we would replace Arial glyphs for `world` with Helvetica one. Pretty simple.
  //
  // Well, it would work most of the time, but not always.
  // This is because different fonts can produce different amount of glyphs for the same text.
  // The most common example are ligatures. Some fonts can shape `fi` as two glyphs `f` and `i`,
  // but some can use `ﬁ` (U+FB01) instead.
  // Meaning that during merging we have to overwrite not individual glyphs, but clusters.

  // Glyph splitting assigns distinct glyphs to the same index in the original text, we need to
  // store previously used indices to make sure we do not re-use the same index while overwriting
  // span glyphs.
  let positions : Set[Int] = Set([])
  let mut glyphs : Array[Glyph] = []
  for span in chunk.spans {
    let font = match fonts_cache.get(span.font) {
      Some(v) => v
      None => continue
    }
    let tmp_glyphs = shape_text(
      chunk.text,
      font,
      span.small_caps,
      span.apply_kerning,
      span.font.variations,
      span.font_size.get(),
      span.font_optical_sizing,
      resolver,
      fontdb,
    )

    // Do nothing with the first run.
    if glyphs.is_empty() {
      glyphs = tmp_glyphs
      continue
    }
    positions.clear()

    // Overwrite span's glyphs.
    let mut it = 0
    while it < tmp_glyphs.length() {
      let new_glyph = tmp_glyphs[it]
      it += 1
      if !span_contains(span, new_glyph.byte_idx) {
        continue
      }
      let mut found = None
      for i, g in glyphs {
        if g.byte_idx == new_glyph.byte_idx {
          found = Some(i)
          break
        }
      }
      let idx = match found {
        Some(pos) if !positions.contains(pos) => pos
        _ => continue
      }
      positions.add(idx)
      let prev_cluster_len = glyphs[idx].cluster_len
      if prev_cluster_len < new_glyph.cluster_len {
        // If the new font represents the same cluster with fewer glyphs
        // then remove remaining glyphs.
        for _ in 1..<new_glyph.cluster_len {
          glyphs.remove(idx + 1) |> ignore
        }
      } else if prev_cluster_len > new_glyph.cluster_len {
        // If the new font represents the same cluster with more glyphs
        // then insert them after the current one.
        for j in 1..<prev_cluster_len {
          if it < tmp_glyphs.length() {
            let g = tmp_glyphs[it]
            it += 1
            glyphs.insert(idx + j, g)
          }
        }
      }
      glyphs[idx] = new_glyph
    }
  }

  // Convert glyphs to clusters.
  let clusters = []
  let mut idx = 0
  while idx < glyphs.length() {
    // `GlyphClusters`
    let start = idx
    let cluster = glyphs[idx].byte_idx
    while idx < glyphs.length() && glyphs[idx].byte_idx == cluster {
      idx += 1
    }
    if chunk_span_at(chunk, cluster) is Some(span) {
      clusters.push(
        form_glyph_clusters(glyphs[start:idx], chunk.text, span.font_size.get()),
      )
    }
  }
  clusters
}

///|
fn apply_length_adjust(
  chunk : TextChunk,
  clusters : Array[GlyphCluster],
) -> Unit {
  let is_horizontal = chunk.text_flow is Linear
  for span in chunk.spans {
    let target_width = match span.text_length {
      Some(v) => v
      None => continue
    }
    let mut width : Float = 0.0
    let cluster_indexes = []
    for i in span.start..<span.end {
      for index, c in clusters {
        if c.byte_idx == i {
          cluster_indexes.push(index)
          break
        }
      }
    }
    // Complex scripts can have multi-codepoint clusters therefore we have to remove duplicates.
    cluster_indexes.sort()
    cluster_indexes.dedup()
    for i in cluster_indexes {
      // Use the original cluster `width` and not `advance`.
      // This method essentially discards any `word-spacing` and `letter-spacing`.
      width += clusters[i].width
    }
    if cluster_indexes.is_empty() {
      continue
    }
    if span.length_adjust == Spacing {
      let factor = if cluster_indexes.length() > 1 {
        (target_width - width) / Float::from_int(cluster_indexes.length() - 1)
      } else {
        0.0
      }
      for i in cluster_indexes {
        clusters[i].advance = clusters[i].width + factor
      }
    } else {
      let factor = target_width / width
      // Prevent multiplying by zero.
      if factor < 0.001 {
        continue
      }
      for i in cluster_indexes {
        clusters[i].transform = clusters[i].transform.pre_scale(factor, 1.0)

        // Technically just a hack to support the current text-on-path algorithm.
        if !is_horizontal {
          clusters[i].advance *= factor
          clusters[i].width *= factor
        }
      }
    }
  }
}

///|
/// Rotates clusters according to
/// [Unicode Vertical_Orientation Property](https://www.unicode.org/reports/tr50/tr50-19.html).
fn apply_writing_mode(
  writing_mode : WritingMode,
  clusters : Array[GlyphCluster],
) -> Unit {
  if writing_mode != TopToBottom {
    return
  }
  for cluster in clusters {
    let orientation = char_orientation(cluster.codepoint)
    if orientation == Upright {
      let mut ts = Transform::default()
      // Position glyph in the center of vertical axis.
      ts = ts.pre_translate(0.0, (cluster.ascent + cluster.descent) / 2.0)
      // Rotate by 90 degrees in the center.
      ts = ts.pre_rotate_at(
        -90.0,
        cluster.width / 2.0,
        -(cluster.ascent + cluster.descent) / 2.0,
      )
      cluster.path_transform = ts

      // Move "baseline" to the middle and make height equal to width.
      cluster.ascent = cluster.width / 2.0
      cluster.descent = -cluster.width / 2.0
    } else {
      // Could not find a spec that explains this,
      // but this is how other applications are shifting the "rotated" characters
      // in the top-to-bottom mode.
      cluster.transform = cluster.transform.pre_translate(
        0.0,
        (cluster.ascent + cluster.descent) / 2.0,
      )
    }
  }
}

///|
/// Applies the `letter-spacing` property to a text chunk clusters.
///
/// [In the CSS spec](https://www.w3.org/TR/css-text-3/#letter-spacing-property).
fn apply_letter_spacing(
  chunk : TextChunk,
  clusters : Array[GlyphCluster],
) -> Unit {
  // At least one span should have a non-zero spacing.
  if !chunk.spans.iter().any(span => !approx_zero_ulps(span.letter_spacing, 4)) {
    return
  }
  let num_clusters = clusters.length()
  for i, cluster in clusters {
    // Spacing must be applied only to characters that belongs to the script
    // that supports spacing.
    // We are checking only the first code point, since it should be enough.
    // https://www.w3.org/TR/css-text-3/#cursive-tracking
    let script = @unicode.script(cluster.codepoint)
    if script_supports_letter_spacing(script) {
      if chunk_span_at(chunk, cluster.byte_idx) is Some(span) {
        // A space after the last cluster should be ignored,
        // since it affects the bbox and text alignment.
        if i != num_clusters - 1 {
          cluster.advance += span.letter_spacing
        }

        // If the cluster advance became negative - clear it.
        // This is an UB so we can do whatever we want, and we mimic Chrome's behavior.
        if !is_valid_length(cluster.advance) {
          cluster.width = 0.0
          cluster.advance = 0.0
          cluster.glyphs = []
        }
      }
    }
  }
}

///|
/// Applies the `word-spacing` property to a text chunk clusters.
///
/// [In the CSS spec](https://www.w3.org/TR/css-text-3/#propdef-word-spacing).
fn apply_word_spacing(
  chunk : TextChunk,
  clusters : Array[GlyphCluster],
) -> Unit {
  // At least one span should have a non-zero spacing.
  if !chunk.spans.iter().any(span => !approx_zero_ulps(span.word_spacing, 4)) {
    return
  }
  for cluster in clusters {
    if is_word_separator_characters(cluster.codepoint) {
      if chunk_span_at(chunk, cluster.byte_idx) is Some(span) {
        // Technically, word spacing 'should be applied half on each
        // side of the character', but it doesn't affect us in any way,
        // so we are ignoring this.
        cluster.advance += span.word_spacing

        // After word spacing, `advance` can be negative.
      }
    }
  }
}

///|
fn form_glyph_clusters(
  glyphs : ArrayView[Glyph],
  text : String,
  font_size : Float,
) -> GlyphCluster {
  let mut width : Float = 0.0
  let mut x : Float = 0.0
  let positioned_glyphs = []
  for glyph in glyphs {
    let sx = glyph.font.scale(font_size)

    // Apply offset.
    //
    // The first glyph in the cluster will have an offset from 0x0,
    // but the later one will have an offset from the "current position".
    // So we have to keep an advance.
    // TODO: should be done only inside a single text span
    let ts = Transform::from_translate(
      x + Float::from_int(glyph.dx),
      -Float::from_int(glyph.dy),
    )
    positioned_glyphs.push({
      glyph_ts: ts,
      // Will be set later.
      cluster_ts: Transform::default(),
      // Will be set later.
      span_ts: Transform::default(),
      units_per_em: glyph.font.units_per_em,
      font_size,
      font: glyph.font.id,
      text: glyph.text,
      id: glyph.id,
    })
    x += Float::from_int(glyph.width)
    let glyph_width = Float::from_int(glyph.width) * sx
    if glyph_width > width {
      width = glyph_width
    }
  }
  let byte_idx = glyphs[0].byte_idx
  let font = glyphs[0].font
  {
    byte_idx,
    codepoint: char_from(text, byte_idx),
    width,
    advance: width,
    ascent: font.ascent(font_size),
    descent: font.descent(font_size),
    has_relative_shift: false,
    transform: Transform::default(),
    path_transform: Transform::default(),
    glyphs: positioned_glyphs,
    visible: true,
  }
}

///|
/// A parsed font face of the database (upstream parses it in every
/// `with_face_data` call).
fn FontDatabase::parse_face(self : FontDatabase, id : FontId) -> @otf.Face? {
  match self.parsed.get(id) {
    Some(face) => face
    None => {
      let face = match self.face(id) {
        Some(info) =>
          Some(@otf.Face::parse(info.source[:], info.index)) catch {
            _ => None
          }
        None => None
      }
      self.parsed[id] = face
      face
    }
  }
}

///|
fn FontDatabase::load_font(self : FontDatabase, id : FontId) -> ResolvedFont? {
  guard self.parse_face(id) is Some(font) else { return None }
  let units_per_em = font.units_per_em().to_int()
  if units_per_em == 0 {
    return None
  }
  let ascent = font.ascender().to_int()
  let descent = font.descender().to_int()
  let x_height = match font.x_height() {
    Some(x) if x.to_int() > 0 => x.to_int()
    _ => {
      // If not set - fallback to height * 45%.
      // 45% is what Firefox uses.
      let h = f32_as_i32(Float::from_int(ascent - descent) * 0.45)
      if h <= 0 || h > 0xFFFF {
        return None
      }
      h
    }
  }
  let line_through_position = match font.strikeout_metrics() {
    Some(metrics) => metrics.position.to_int()
    None => i16_wrap(x_height) / 2
  }
  let (underline_position, underline_thickness) = match
    font.underline_metrics() {
    Some(metrics) => {
      let t = metrics.thickness.to_int()
      let thickness = if t > 0 {
        t
      } else {
        // `ttf_parser` guarantees that units_per_em is >= 16
        units_per_em / 12
      }
      (metrics.position.to_int(), thickness)
    }
    None => (-i16_wrap(units_per_em) / 9, units_per_em / 12)
  }

  // 0.2 and 0.4 are generic offsets used by some applications (Inkscape/librsvg).
  let mut subscript_offset = i16_wrap(
    f32_as_i32(rust_round_f32(Float::from_int(units_per_em) / 0.2)),
  )
  let mut superscript_offset = i16_wrap(
    f32_as_i32(rust_round_f32(Float::from_int(units_per_em) / 0.4)),
  )
  if font.subscript_metrics() is Some(metrics) {
    subscript_offset = metrics.y_offset.to_int()
  }
  if font.superscript_metrics() is Some(metrics) {
    superscript_offset = metrics.y_offset.to_int()
  }
  Some({
    id,
    units_per_em,
    ascent,
    descent,
    x_height,
    underline_position,
    underline_thickness,
    line_through_position,
    subscript_offset,
    superscript_offset,
  })
}

///|
/// Rust's `as i16` (wrapping) on an `i32`.
fn i16_wrap(x : Int) -> Int {
  let v = x & 0xFFFF
  if v >= 0x8000 {
    v - 0x10000
  } else {
    v
  }
}

///|
fn FontDatabase::has_char(self : FontDatabase, id : FontId, c : Char) -> Bool {
  match self.parse_face(id) {
    Some(font) => font.glyph_index(c) is Some(_)
    None => false
  }
}

///|
/// Text shaping with font fallback.
fn shape_text(
  text : String,
  font : ResolvedFont,
  small_caps : Bool,
  apply_kerning : Bool,
  variations : Array[FontVariation],
  font_size : Float,
  font_optical_sizing : FontOpticalSizing,
  resolver : FontResolver,
  fontdb : FontDatabase,
) -> Array[Glyph] {
  let mut glyphs = shape_text_with_font(
    text, font, small_caps, apply_kerning, variations, font_size, font_optical_sizing,
    fontdb,
  ).unwrap_or([])

  // Remember all fonts used for shaping.
  let used_fonts = [font.id]

  // Loop until all glyphs become resolved or until no more fonts are left.
  while true {
    let mut missing = None
    for glyph in glyphs {
      if glyph.is_missing() {
        missing = Some(char_from(text, glyph.byte_idx))
        break
      }
    }
    if missing is Some(c) {
      let fallback_font = match
        (resolver.select_fallback)(c, used_fonts, fontdb) {
        Some(id) =>
          match fontdb.load_font(id) {
            Some(v) => v
            None => break
          }
        None => break
      }

      // Shape again, using a new font.
      let fallback_glyphs = shape_text_with_font(
        text, fallback_font, small_caps, apply_kerning, variations, font_size, font_optical_sizing,
        fontdb,
      ).unwrap_or([])
      let all_matched = fallback_glyphs.iter().all(g => !g.is_missing())
      if all_matched {
        // Replace all glyphs when all of them were matched.
        glyphs = fallback_glyphs
        break
      }

      // We assume, that shaping with an any font will produce the same amount of glyphs.
      // This is incorrect, but good enough for now.
      if glyphs.length() != fallback_glyphs.length() {
        break
      }

      // TODO: Replace clusters and not glyphs. This should be more accurate.

      // Copy new glyphs.
      for i in 0..<glyphs.length() {
        if glyphs[i].is_missing() && !fallback_glyphs[i].is_missing() {
          glyphs[i] = fallback_glyphs[i]
        }
      }

      // Remember this font.
      used_fonts.push(fallback_font.id)
    } else {
      break
    }
  }

  // Upstream warns about missing glyphs.
  glyphs
}

///|
/// Converts a text into a list of glyph IDs.
///
/// This function will do the BIDI reordering and text shaping.
fn shape_text_with_font(
  text : String,
  font : ResolvedFont,
  small_caps : Bool,
  apply_kerning : Bool,
  variations : Array[FontVariation],
  font_size : Float,
  font_optical_sizing : FontOpticalSizing,
  fontdb : FontDatabase,
) -> Array[Glyph]? {
  guard fontdb.face(font.id) is Some(info) else { return None }
  guard @shape.Face::from_slice(info.source[:], info.index) is Some(rb_font) else {
    return None
  }

  // Build the list of variations to apply
  let final_variations : Array[@shape.Variation] = variations.map(v => {
    tag: @otf.Tag::from_bytes(Bytes::makei(4, i => v.tag[i])),
    value: v.value,
  })

  // Automatic optical sizing: if font-optical-sizing is auto and the font has
  // an 'opsz' axis that isn't explicitly set, auto-set it to match font size.
  // This matches browser behavior (CSS font-optical-sizing: auto).
  if font_optical_sizing == OpticalAuto {
    let has_explicit_opsz = variations
      .iter()
      .any(v => v.tag == b"opsz".to_fixedarray())
    if !has_explicit_opsz {
      // Check if font has opsz axis using the already parsed rb_font
      if rb_font.ttf().tables().fvar is Some(axes) {
        let has_opsz_axis = axes.axes
          .iter()
          .any(axis => axis.tag == @otf.Tag::from_bytes(b"opsz"))
        if has_opsz_axis {
          final_variations.push({
            tag: @otf.Tag::from_bytes(b"opsz"),
            value: font_size,
          })
        }
      }
    }
  }

  // Apply font variations for variable fonts
  if !final_variations.is_empty() {
    rb_font.set_variations(final_variations)
  }
  let bytes = @utf8.encode(text)
  let bidi_info = @bidi.BidiInfo::new(text, Some(@bidi.Level::ltr()))
  let paragraph = bidi_info.paragraphs[0]
  let line = paragraph.range
  let glyphs = []
  let (levels, runs) = bidi_info.visual_runs(paragraph, line)
  for run in runs {
    if run.start == run.end {
      continue
    }
    let sub_bytes = bytes[run.start:run.end]
    let sub_text = @utf8.decode_lossy(sub_bytes)
    let ltr = levels[run.start].is_ltr()
    let hb_direction = if ltr {
      @shape.Direction::LeftToRight
    } else {
      @shape.Direction::RightToLeft
    }
    let buffer = @shape.UnicodeBuffer::new()
    buffer.push_str(sub_text)
    buffer.set_direction(hb_direction)
    let features = []
    if small_caps {
      features.push(@shape.Feature::new(@otf.Tag::from_bytes(b"smcp"), 1))
    }
    if !apply_kerning {
      features.push(@shape.Feature::new(@otf.Tag::from_bytes(b"kern"), 0))
    }
    let output = @shape.shape(rb_font, features, buffer)
    let positions = output.glyph_positions()
    let infos = output.glyph_infos()
    for i in 0..<output.len() {
      let pos = positions[i]
      let info = infos[i]
      let idx = run.start + info.cluster.reinterpret_as_int()
      let start = info.cluster.reinterpret_as_int()
      let last = if ltr { i + 1 } else { i - 1 }
      let end = if last >= 0 && last < infos.length() {
        infos[last].cluster.reinterpret_as_int()
      } else {
        sub_bytes.length()
      }
      glyphs.push({
        byte_idx: idx,
        cluster_len: if end >= start {
          end - start
        } else {
          0
        }, // TODO: can fail?
        text: if end >= start {
          @utf8.decode_lossy(sub_bytes[start:end])
        } else {
          // Upstream panics on an inverted range.
          ""
        },
        id: info.glyph_id.reinterpret_as_int() & 0xFFFF,
        dx: pos.x_offset,
        dy: pos.y_offset,
        width: pos.x_advance,
        font,
      })
    }
  }
  Some(glyphs)
}

///|
/// Checks that selected script supports letter spacing.
///
/// [In the CSS spec](https://www.w3.org/TR/css-text-3/#cursive-tracking).
///
/// The list itself is from: https://github.com/harfbuzz/harfbuzz/issues/64
fn script_supports_letter_spacing(script : String) -> Bool {
  !(script
  is ("Arabic"
  | "Syriac"
  | "Nko"
  | "Manichaean"
  | "Psalter_Pahlavi"
  | "Mandaic"
  | "Mongolian"
  | "Phags_Pa"
  | "Devanagari"
  | "Bengali"
  | "Gurmukhi"
  | "Modi"
  | "Sharada"
  | "Syloti_Nagri"
  | "Tirhuta"
  | "Ogham"))
}

///|
/// A glyph.
///
/// Basically, a glyph ID and it's metrics.
priv struct Glyph {
  /// The glyph ID in the font.
  id : Int
  /// Position in bytes in the original string.
  ///
  /// We use it to match a glyph with a character in the text chunk and therefore with the style.
  byte_idx : Int
  // The length of the cluster in bytes.
  cluster_len : Int
  /// The text from the original string that corresponds to that glyph.
  text : String
  /// The glyph offset in font units.
  dx : Int
  /// The glyph offset in font units.
  dy : Int
  /// The glyph width / X-advance in font units.
  width : Int
  /// Reference to the source font.
  ///
  /// Each glyph can have it's own source font.
  font : ResolvedFont
}

///|
fn Glyph::is_missing(self : Glyph) -> Bool {
  self.id == 0
}

///|
priv struct ResolvedFont {
  id : FontId
  units_per_em : Int
  // All values below are in font units.
  ascent : Int
  descent : Int
  x_height : Int
  underline_position : Int
  underline_thickness : Int
  // line-through thickness should be the the same as underline thickness
  // according to the TrueType spec:
  // https://docs.microsoft.com/en-us/typography/opentype/spec/os2#ystrikeoutsize
  line_through_position : Int
  subscript_offset : Int
  superscript_offset : Int
}

///|
fn chunk_span_at(chunk : TextChunk, byte_offset : Int) -> TextSpan? {
  chunk.spans.iter().find_first(span => span_contains(span, byte_offset))
}

///|
fn span_contains(span : TextSpan, byte_offset : Int) -> Bool {
  byte_offset >= span.start && byte_offset < span.end
}

///|
/// Checks that the selected character is a word separator.
///
/// According to: https://www.w3.org/TR/css-text-3/#word-separator
fn is_word_separator_characters(c : Char) -> Bool {
  c.to_int()
  is (0x0020 | 0x00A0 | 0x1361 | 0x010100 | 0x010101 | 0x01039F | 0x01091F)
}

///|
fn ResolvedFont::scale(self : ResolvedFont, font_size : Float) -> Float {
  font_size / Float::from_int(self.units_per_em)
}

///|
fn ResolvedFont::ascent(self : ResolvedFont, font_size : Float) -> Float {
  Float::from_int(self.ascent) * self.scale(font_size)
}

///|
fn ResolvedFont::descent(self : ResolvedFont, font_size : Float) -> Float {
  Float::from_int(self.descent) * self.scale(font_size)
}

///|
fn ResolvedFont::height(self : ResolvedFont, font_size : Float) -> Float {
  self.ascent(font_size) - self.descent(font_size)
}

///|
fn ResolvedFont::x_height(self : ResolvedFont, font_size : Float) -> Float {
  Float::from_int(self.x_height) * self.scale(font_size)
}

///|
fn ResolvedFont::underline_position(
  self : ResolvedFont,
  font_size : Float,
) -> Float {
  Float::from_int(self.underline_position) * self.scale(font_size)
}

///|
fn ResolvedFont::underline_thickness(
  self : ResolvedFont,
  font_size : Float,
) -> Float {
  Float::from_int(self.underline_thickness) * self.scale(font_size)
}

///|
fn ResolvedFont::line_through_position(
  self : ResolvedFont,
  font_size : Float,
) -> Float {
  Float::from_int(self.line_through_position) * self.scale(font_size)
}

///|
fn ResolvedFont::subscript_offset(
  self : ResolvedFont,
  font_size : Float,
) -> Float {
  Float::from_int(self.subscript_offset) * self.scale(font_size)
}

///|
fn ResolvedFont::superscript_offset(
  self : ResolvedFont,
  font_size : Float,
) -> Float {
  Float::from_int(self.superscript_offset) * self.scale(font_size)
}

///|
fn ResolvedFont::dominant_baseline_shift(
  self : ResolvedFont,
  baseline : DominantBaseline,
  font_size : Float,
) -> Float {
  let alignment = match baseline {
    DominantBaseline::Auto => AlignmentBaseline::Auto
    UseScript => AlignmentBaseline::Auto // unsupported
    NoChange => AlignmentBaseline::Auto // already resolved
    ResetSize => AlignmentBaseline::Auto // unsupported
    DominantBaseline::Ideographic => AlignmentBaseline::Ideographic
    DominantBaseline::Alphabetic => AlignmentBaseline::Alphabetic
    DominantBaseline::Hanging => AlignmentBaseline::Hanging
    DominantBaseline::Mathematical => AlignmentBaseline::Mathematical
    DominantBaseline::Central => AlignmentBaseline::Central
    DominantBaseline::Middle => AlignmentBaseline::Middle
    DominantBaseline::TextAfterEdge => AlignmentBaseline::TextAfterEdge
    DominantBaseline::TextBeforeEdge => AlignmentBaseline::TextBeforeEdge
  }
  self.alignment_baseline_shift(alignment, font_size)
}

///|
// The `alignment-baseline` property is a mess.
//
// The SVG 1.1 spec (https://www.w3.org/TR/SVG11/text.html#BaselineAlignmentProperties)
// goes on and on about what this property suppose to do, but doesn't actually explain
// how it should be implemented. It's just a very verbose overview.
//
// As of Nov 2022, only Chrome and Safari support `alignment-baseline`. Firefox isn't.
// Same goes for basically every SVG library in existence.
// Meaning we have no idea how exactly it should be implemented.
//
// Since baseline TrueType tables parsing and baseline synthesis are pretty hard,
// we do what Chrome does - use hardcoded values. And it seems like Safari does the same.
fn ResolvedFont::alignment_baseline_shift(
  self : ResolvedFont,
  alignment : AlignmentBaseline,
  font_size : Float,
) -> Float {
  match alignment {
    Auto => 0.0
    Baseline => 0.0
    BeforeEdge | TextBeforeEdge => self.ascent(font_size)
    Middle => self.x_height(font_size) * 0.5
    Central => self.ascent(font_size) - self.height(font_size) * 0.5
    AfterEdge | TextAfterEdge => self.descent(font_size)
    Ideographic => self.descent(font_size)
    Alphabetic => 0.0
    Hanging => self.ascent(font_size) * 0.8
    Mathematical => self.ascent(font_size) * 0.5
  }
}

///|
/// Converts byte position into a code point position (`ByteIndex::code_point_at`).
fn code_point_at(text : String, byte_idx : Int) -> Int {
  let mut i = 0
  let mut count = 0
  for c in text {
    if i == byte_idx {
      break
    }
    i += utf8_char_len(c)
    count += 1
  }
  count
}

///|
/// Converts byte position into a character (`ByteIndex::char_from`).
fn char_from(text : String, byte_idx : Int) -> Char {
  let mut i = 0
  for c in text {
    if i == byte_idx {
      return c
    }
    i += utf8_char_len(c)
  }
  abort("byte index out of range")
}

///|
fn utf8_char_len(c : Char) -> Int {
  let c = c.to_int()
  if c < 0x80 {
    1
  } else if c < 0x800 {
    2
  } else if c < 0x10000 {
    3
  } else {
    4
  }
}

///|
/// The number of chars (Unicode scalar values) of a string.
fn String::char_count(self : String) -> Int {
  let mut n = 0
  for _ in self {
    n += 1
  }
  n
}
