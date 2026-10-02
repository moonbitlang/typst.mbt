// Port of skrifa 0.42.1 `src/metrics.rs` (default location only: HVAR,
// gvar and MVAR deltas are not applied).

///|
/// Metrics for a text decoration.
pub(all) struct Decoration {
  /// Offset to the top of the decoration from the baseline.
  offset : Float
  /// Thickness of the decoration.
  thickness : Float
} derive(Eq, Debug)

///|
/// Bounding box with float coordinates.
pub(all) struct BoundingBox {
  x_min : Float
  y_min : Float
  x_max : Float
  y_max : Float
} derive(Eq, Debug)

///|
/// Metrics that apply to all glyphs in a font.
pub(all) struct Metrics {
  /// Number of font design units per em unit.
  mut units_per_em : Int
  /// Number of glyphs in the font.
  mut glyph_count : Int
  /// True if the font is not proportionally spaced.
  mut is_monospace : Bool
  /// Italic angle in counter-clockwise degrees from the vertical.
  mut italic_angle : Float
  /// Distance from the baseline to the top of the alignment box.
  mut ascent : Float
  /// Distance from the baseline to the bottom of the alignment box.
  mut descent : Float
  /// Recommended additional spacing between lines.
  mut leading : Float
  /// Distance from the baseline to the top of a typical English capital.
  mut cap_height : Float?
  /// Distance from the baseline to the top of the lowercase "x".
  mut x_height : Float?
  /// Average width of all non-zero width characters in the font.
  mut average_width : Float?
  /// Maximum advance width of all characters in the font.
  mut max_width : Float?
  /// Metrics for an underline decoration.
  mut underline : Decoration?
  /// Metrics for a strikeout decoration.
  mut strikeout : Decoration?
  /// Union of minimum and maximum extents for all glyphs in the font.
  mut bounds : BoundingBox?
} derive(Eq, Debug)

///|
fn f(v : Int) -> Float {
  Float::from_int(v)
}

///|
/// Creates new metrics for the given font, size, and location in
/// normalized variation space.
pub fn Metrics::new(
  font : FontRef,
  size : Size,
  _location : LocationRef,
) -> Metrics {
  let head = res(() => font.head())
  let metrics : Metrics = {
    units_per_em: match head {
      Ok(h) => h.units_per_em()
      Err(_) => 0
    },
    glyph_count: 0,
    is_monospace: false,
    italic_angle: 0.0,
    ascent: 0.0,
    descent: 0.0,
    leading: 0.0,
    cap_height: None,
    x_height: None,
    average_width: None,
    max_width: None,
    underline: None,
    strikeout: None,
    bounds: None,
  }
  let scale = size.linear_scale(metrics.units_per_em)
  if head is Ok(head) {
    metrics.bounds = Some({
      x_min: f(head.x_min()) * scale,
      y_min: f(head.y_min()) * scale,
      x_max: f(head.x_max()) * scale,
      y_max: f(head.y_max()) * scale,
    })
  }
  if ok(() => font.maxp()) is Some(maxp) {
    metrics.glyph_count = maxp.num_glyphs()
  }
  if ok(() => font.post()) is Some(post) {
    metrics.is_monospace = post.is_fixed_pitch() != 0
    metrics.italic_angle = Float::from_double(post.italic_angle().to_f64())
    metrics.underline = Some({
      offset: f(post.underline_position()) * scale,
      thickness: f(post.underline_thickness()) * scale,
    })
  }
  if ok(() => font.hhea()) is Some(hhea) {
    metrics.max_width = Some(f(hhea.advance_width_max()) * scale)
  }
  let os2 = match res(() => font.os2()) {
    Ok(o) => Some(o)
    Err(_) => None
  }
  let mut used_typo_metrics = false
  if os2 is Some(os2) {
    if (os2.fs_selection() & @read_fonts.OS2_SELECTION_USE_TYPO_METRICS) != 0 {
      metrics.ascent = f(os2.s_typo_ascender()) * scale
      metrics.descent = f(os2.s_typo_descender()) * scale
      metrics.leading = f(os2.s_typo_line_gap()) * scale
      used_typo_metrics = true
    }
    metrics.average_width = Some(f(os2.x_avg_char_width()) * scale)
    metrics.cap_height = match os2.s_cap_height() {
      Some(v) => Some(f(v) * scale)
      None => None
    }
    metrics.x_height = match os2.sx_height() {
      Some(v) => Some(f(v) * scale)
      None => None
    }
    metrics.strikeout = Some({
      offset: f(os2.y_strikeout_position()) * scale,
      thickness: f(os2.y_strikeout_size()) * scale,
    })
  }
  if !used_typo_metrics {
    if ok(() => font.hhea()) is Some(hhea) {
      metrics.ascent = f(hhea.ascender()) * scale
      metrics.descent = f(hhea.descender()) * scale
      metrics.leading = f(hhea.line_gap()) * scale
    }
    if metrics.ascent == 0.0 && metrics.descent == 0.0 {
      if os2 is Some(os2) {
        if os2.s_typo_ascender() != 0 || os2.s_typo_descender() != 0 {
          metrics.ascent = f(os2.s_typo_ascender()) * scale
          metrics.descent = f(os2.s_typo_descender()) * scale
          metrics.leading = f(os2.s_typo_line_gap()) * scale
        } else {
          metrics.ascent = f(os2.us_win_ascent()) * scale
          metrics.descent = -(f(os2.us_win_descent()) * scale)
        }
      }
    }
  }
  metrics
}

///|
/// Glyph specific metrics.
pub struct GlyphMetrics {
  font : FontRef
  size : Size
  glyph_count : Int
  fixed_scale : Fixed
  priv hmtx : @read_fonts.Hmtx?
  default_advance_width : Int
  priv loca_glyf : (@read_fonts.Loca, @read_fonts.Glyf)?
}

///|
/// Creates new glyph metrics from the given font, size, and location in
/// normalized variation space.
pub fn GlyphMetrics::new(
  font : FontRef,
  size : Size,
  _location : LocationRef,
) -> GlyphMetrics {
  let glyph_count = match res(() => font.maxp()) {
    Ok(maxp) => maxp.num_glyphs()
    Err(_) => 0
  }
  let upem = match res(() => font.head()) {
    Ok(head) => head.units_per_em()
    Err(_) => 0
  }
  let fixed_scale = size.fixed_linear_scale(upem)
  let hmtx = match res(() => font.hmtx()) {
    Ok(h) => Some(h)
    Err(_) => None
  }
  let default_advance_width = match hmtx {
    Some(h) =>
      if h.num_h_metrics() > 0 {
        h.h_metric_advance(h.num_h_metrics() - 1)
      } else {
        0
      }
    None => 0
  }
  let loca_glyf = match (ok(() => font.loca(None)), ok(() => font.glyf())) {
    (Some(loca), Some(glyf)) => Some((loca, glyf))
    _ => None
  }
  {
    font,
    size,
    glyph_count,
    fixed_scale,
    hmtx,
    default_advance_width,
    loca_glyf,
  }
}

///|
/// Returns the number of available glyphs in the font.
pub fn GlyphMetrics::glyph_count(self : GlyphMetrics) -> Int {
  self.glyph_count
}

///|
fn GlyphMetrics::apply(self : GlyphMetrics, value : Int) -> Float {
  self.fixed_scale
  .mul_div(Fixed::from_bits(value), Fixed::from_bits(64))
  .to_f32()
}

///|
/// Returns the advance width for the specified glyph.
///
/// If normalized coordinates were provided when constructing glyph metrics
/// and an `HVAR` table is present, applies the appropriate delta.
pub fn GlyphMetrics::advance_width(
  self : GlyphMetrics,
  glyph_id : GlyphId,
) -> Float? {
  if glyph_id.to_u32() >= self.glyph_count.reinterpret_as_uint() {
    return None
  }
  let gid = glyph_id.to_int()
  let advance = match self.hmtx {
    Some(h) if gid < h.num_h_metrics() => h.h_metric_advance(gid)
    _ => self.default_advance_width
  }
  Some(self.apply(advance))
}

///|
/// Returns the left side bearing for the specified glyph.
pub fn GlyphMetrics::left_side_bearing(
  self : GlyphMetrics,
  glyph_id : GlyphId,
) -> Float? {
  if glyph_id.to_u32() >= self.glyph_count.reinterpret_as_uint() {
    return None
  }
  let gid = glyph_id.to_int()
  let lsb = match self.hmtx {
    Some(h) =>
      if gid < h.num_h_metrics() {
        h.h_metric_side_bearing(gid)
      } else {
        let ix = gid - h.num_h_metrics()
        if ix < h.num_left_side_bearings() {
          h.left_side_bearing(ix)
        } else {
          0
        }
      }
    None => 0
  }
  Some(self.apply(lsb))
}

///|
/// Returns the bounding box for the specified glyph (glyf fonts without
/// variations only).
pub fn GlyphMetrics::bounds(
  self : GlyphMetrics,
  glyph_id : GlyphId,
) -> BoundingBox? {
  guard self.loca_glyf is Some((loca, glyf)) else { return None }
  let glyph = loca.get_glyf(glyph_id, glyf) catch { _ => return None }
  match glyph {
    Some(glyph) =>
      Some({
        x_min: self.apply(glyph.x_min()),
        y_min: self.apply(glyph.y_min()),
        x_max: self.apply(glyph.x_max()),
        y_max: self.apply(glyph.y_max()),
      })
    None => Some({ x_min: 0.0, y_min: 0.0, x_max: 0.0, y_max: 0.0, })
  }
}
