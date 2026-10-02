// Port of `krilla-svg/src/lib.rs` (krilla-svg 0.8.1, krilla rev 7772dbe): an
// extension to the exporter that allows rendering SVG files (usvg trees) to
// a PDF file.

///|
/// Settings that should be applied when converting a SVG.
priv struct SvgSettings {
  /// Whether text should be embedded as properly selectable text. Otherwise,
  /// it will be drawn as outlined paths instead.
  embed_text : Bool
  /// How much filters, which will be converted to bitmaps, should be scaled.
  /// Higher values mean better quality, but also bigger file sizes.
  filter_scale : Float
}

///|
fn SvgSettings::default() -> SvgSettings {
  { embed_text: true, filter_scale: 4.0, }
}

///|
/// Draw a `usvg` tree onto a surface with the given size and settings
/// (krilla-svg `SurfaceExt::draw_svg`).
///
/// krilla saves the surface's fill and stroke and restores them afterwards;
/// the exporter's surface has no getters for them, but every caller in
/// `pdf/` sets the fill and stroke before drawing, so they are reset
/// instead.
fn draw_svg(
  surface : @export.Surface,
  tree : @usvg.Tree,
  size : @export.Size,
  svg_settings : SvgSettings,
  fonts : SvgFontCache,
) -> Unit? {
  let tree_size = tree.size()
  let transform = @tiny_skia_path.Transform::from_scale(
    Float::from_double(size.width) / tree_size.width(),
    Float::from_double(size.height) / tree_size.height(),
  )
  surface.push_transform(svg_transform_to_export(transform))
  surface.push_clip_path(
    svg_rect_to_clip_path(
      @export.Rect::from_xywh(
        0.0,
        0.0,
        tree_size.width().to_double(),
        tree_size.height().to_double(),
      ).unwrap(),
    ),
    NonZero,
  )
  svg_render_tree(tree, svg_settings, surface, fonts)
  surface.pop()
  surface.pop()
  surface.set_fill(None)
  surface.set_stroke(None)
  Some(())
}

///|
priv struct SvgProcessContext {
  fonts : SvgFonts
  svg_settings : SvgSettings
}

///|
fn SvgProcessContext::new(
  tree_fontdb : @usvg.FontDatabase,
  svg_settings : SvgSettings,
  cache : SvgFontCache,
) -> SvgProcessContext {
  { fonts: SvgFonts::new(tree_fontdb, cache), svg_settings, }
}

///|
fn svg_render_tree(
  tree : @usvg.Tree,
  svg_settings : SvgSettings,
  surface : @export.Surface,
  cache : SvgFontCache,
) -> Unit {
  let fc = SvgProcessContext::new(tree.fontdb(), svg_settings, cache)
  svg_group_render(tree.root(), surface, fc)
}

///|
fn svg_render_node(
  node : @usvg.Node,
  tree_fontdb : @usvg.FontDatabase,
  svg_settings : SvgSettings,
  surface : @export.Surface,
  cache : SvgFontCache,
) -> Unit {
  let fc = SvgProcessContext::new(tree_fontdb, svg_settings, cache)
  svg_group_render_node(node, surface, fc)
}

///|
/// Render an SVG glyph from an OpenType font into a surface (krilla-svg
/// `render_svg_glyph`, plugged into krilla as `render_svg_glyph_fn`).
fn render_svg_glyph(
  data : Bytes,
  context_color : Int,
  glyph : Int,
  default_size : (Float, Float),
  surface : @export.Surface,
) -> Unit? {
  let mut data = data
  let settings = SvgSettings::default()
  let default_size = @tiny_skia_path.Size::from_wh(
    default_size.0,
    default_size.1,
  ).unwrap()
  if data.length() >= 2 && data[0] == b'\x1f' && data[1] == b'\x8b' {
    data = @codecs.gzip_decompress(data[:]) catch { _ => return None }
  }
  guard @library.bytes_to_str(data[:]) is Some(xml) else { return None }
  // Incredibly hacky, but hopefully that's enough for SVG glyphs.
  let has_viewbox = xml.contains("viewBox")
  let document = @xml.Document::parse(xml) catch { _ => return None }

  // Reparsing every time might be pretty slow in some cases, because Noto
  // Color Emoji for example contains hundreds of glyphs in the same SVG
  // document, meaning that we have to reparse it every time. However,
  // Twitter Color Emoji does have each glyph in a separate SVG document, and
  // since we use COLRv1 for Noto Color Emoji anyway, this is good enough.
  let red = (context_color >> 16) & 0xFF
  let green = (context_color >> 8) & 0xFF
  let blue = context_color & 0xFF
  let opts : @usvg.Options = {
    ..@usvg.Options::default(),
    style_sheet: Some("svg { color: rgb(\{red}, \{green}, \{blue}) }"),
    default_size,
  }
  let tree = @usvg.Tree::from_xmltree(document, opts) catch { _ => return None }
  let apply_scale = default_size != tree.size() && has_viewbox

  // From the specification:
  //
  // The size of the initial viewport for the SVG document is the em square:
  // height and width both equal to head.unitsPerEm. If a viewBox
  // attribute is specified on the <svg> element with width or
  // height values different from the unitsPerEm value,
  // this will have the effect of a scale transformation on the SVG “user”
  // coordinate system.
  if apply_scale {
    let scale = f32_min(
      default_size.width() / tree.size().width(),
      default_size.height() / tree.size().height(),
    )
    surface.push_transform(
      svg_transform_to_export(
        @tiny_skia_path.Transform::from_scale(scale, scale),
      ),
    )
  }
  match tree.node_by_id("glyph" + glyph.to_string()) {
    Some(node) =>
      svg_render_node(
        node,
        tree.fontdb(),
        settings,
        surface,
        SvgFontCache::new(),
      )
    // Twitter Color Emoji SVGs contain the glyph ID on the root element,
    // which isn't saved by usvg. So in this case, we simply draw the whole
    // document.
    None => svg_render_tree(tree, settings, surface, SvgFontCache::new())
  }
  if apply_scale {
    surface.pop()
  }
  Some(())
}

///|
/// Draw an SVG-based glyph (krilla `text::glyph::svg::draw_glyph`) onto a
/// surface in font units (y-up).
fn draw_svg_glyph(
  ttf : @otf.Face,
  gid : @otf.GlyphId,
  context_color : Int,
  surface : @export.Surface,
) -> Bool {
  guard ttf.glyph_svg_image(gid) is Some(doc) else { return false }
  let upem = Float::from_int(ttf.units_per_em().to_int())
  // krilla draws color glyphs y-down (`draw_color_glyph` flips the y-axis).
  surface.push_transform(@export.Transform::from_scale(1.0, -1.0))
  let drawn = render_svg_glyph(
    doc.data.to_bytes(),
    context_color,
    gid.0.to_int(),
    (upem, upem),
    surface,
  )
  surface.pop()
  drawn is Some(_)
}
