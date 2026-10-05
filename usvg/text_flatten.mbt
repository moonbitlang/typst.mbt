// Port of `usvg` 0.47.0 `src/text/flatten.rs`: converts layouted text into
// paths, images and groups.

///|
fn resolve_rendering_mode(text : Text) -> ShapeRendering {
  match text.rendering_mode {
    OptimizeSpeed => CrispEdges
    OptimizeLegibility => GeometricPrecision
    GeometricPrecision => GeometricPrecision
  }
}

///|
fn push_outline_paths(
  span : LayoutSpan,
  builder : Ref[@tiny_skia_path.PathBuilder],
  new_children : Array[Node],
  rendering_mode : ShapeRendering,
) -> Unit {
  let b = builder.val
  builder.val = @tiny_skia_path.PathBuilder::new()
  if b.finish() is Some(p) {
    if Path::new(
        "",
        span.visible,
        span.fill,
        span.stroke,
        span.paint_order,
        rendering_mode,
        p,
        Transform::default(),
      )
      is Some(path) {
      new_children.push(Path(path))
    }
  }
}

///|
fn flatten_text(text : Text, cache : Cache) -> (Group, NonZeroRect)? {
  let new_children = []
  let rendering_mode = resolve_rendering_mode(text)
  for span in text.layouted {
    if span.overline is Some(path) {
      new_children.push(Node::Path({ ..path.clone(), rendering_mode, }))
    }
    if span.underline is Some(path) {
      new_children.push(Node::Path({ ..path.clone(), rendering_mode, }))
    }

    // Instead of always processing each glyph separately, we always collect
    // as many outline glyphs as possible by pushing them into the span_builder
    // and only if we encounter a different glyph, or we reach the very end of the
    // span to we push the actual outline paths into new_children. This way, we don't need
    // to create a new path for every glyph if we have many consecutive glyphs
    // with just outlines (which is the most common case).
    let span_builder = Ref(@tiny_skia_path.PathBuilder::new())

    // For variable fonts, we need to extract the outline with variations applied.
    // We can't use the cache here since the outline depends on variation values.
    let has_explicit_variations = !span.variations.is_empty()
    for glyph in span.positioned_glyphs {
      // A (best-effort conversion of a) COLR glyph.
      if cache.fontdb_colr(glyph.font, glyph.id) is Some(tree) {
        let group = { ..Group::empty(), transform: glyph.colr_transform(), }
        // TODO: Probably need to update abs_transform of children?
        group.children.push(Group(tree.root))
        group.calculate_bounding_boxes() |> ignore
        new_children.push(Group(group))
      } else if cache.fontdb_svg(glyph.font, glyph.id) is Some(node) {
        // An SVG glyph. Will return the usvg node containing the glyph descriptions.
        push_outline_paths(span, span_builder, new_children, rendering_mode)
        let group = { ..Group::empty(), transform: glyph.svg_transform(), }
        // TODO: Probably need to update abs_transform of children?
        group.children.push(node)
        group.calculate_bounding_boxes() |> ignore
        new_children.push(Group(group))
      } else if cache.fontdb_raster(glyph.font, glyph.id) is Some(img) {
        // A bitmap glyph.
        push_outline_paths(span, span_builder, new_children, rendering_mode)
        let transform = if img.is_sbix {
          glyph.sbix_transform(
            Float::from_int(img.x),
            Float::from_int(img.y),
            Float::from_int(
              match img.glyph_bbox {
                Some(bbox) => bbox.x_min.to_int()
                None => 0
              },
            ),
            Float::from_int(
              match img.glyph_bbox {
                Some(bbox) => bbox.y_min.to_int()
                None => 0
              },
            ),
            Float::from_int(img.pixels_per_em),
            img.image.size.height(),
          )
        } else {
          glyph.cbdt_transform(
            Float::from_int(img.x),
            Float::from_int(img.y),
            Float::from_int(img.pixels_per_em),
            img.image.size.height(),
          )
        }
        let group = { ..Group::empty(), transform, }
        group.children.push(Image(img.image))
        group.calculate_bounding_boxes() |> ignore
        new_children.push(Group(group))
      } else {
        // Only bypass cache if: explicit variations OR (auto opsz AND font has opsz axis)
        let needs_variations = has_explicit_variations ||
          (
            span.font_optical_sizing == OpticalAuto &&
            cache.has_opsz_axis(glyph.font)
          )
        let outline = if needs_variations {
          cache.fontdb.outline_with_variations(
            glyph.font,
            glyph.id,
            span.variations,
            glyph.font_size(),
            span.font_optical_sizing,
          )
        } else {
          cache.fontdb_outline(glyph.font, glyph.id)
        }
        if outline is Some(p) {
          if p.transform(glyph.outline_transform()) is Some(outline) {
            span_builder.val.push_path(outline)
          }
        }
      }
    }
    push_outline_paths(span, span_builder, new_children, rendering_mode)
    if span.line_through is Some(path) {
      new_children.push(Node::Path({ ..path.clone(), rendering_mode, }))
    }
  }
  let group = { ..Group::empty(), id: text.id, }
  for child in new_children {
    group.children.push(child)
  }
  group.calculate_bounding_boxes() |> ignore
  guard group.stroke_bounding_box.to_non_zero_rect() is Some(stroke_bbox) else {
    return None
  }
  Some((group, stroke_bbox))
}

///|
priv struct GlyphPathBuilder {
  builder : @tiny_skia_path.PathBuilder
}

///|
impl @otf.OutlineBuilder for GlyphPathBuilder with fn move_to(self, x, y) {
  self.builder.move_to(x, y)
}

///|
impl @otf.OutlineBuilder for GlyphPathBuilder with fn line_to(self, x, y) {
  self.builder.line_to(x, y)
}

///|
impl @otf.OutlineBuilder for GlyphPathBuilder with fn quad_to(
  self,
  x1,
  y1,
  x,
  y,
) {
  self.builder.quad_to(x1, y1, x, y)
}

///|
impl @otf.OutlineBuilder for GlyphPathBuilder with fn curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  self.builder.cubic_to(x1, y1, x2, y2, x, y)
}

///|
impl @otf.OutlineBuilder for GlyphPathBuilder with fn close(self) {
  self.builder.close()
}

///|
/// A raster glyph image.
priv struct BitmapImage {
  image : Image
  x : Int
  y : Int
  pixels_per_em : Int
  glyph_bbox : @otf.Rect?
  is_sbix : Bool
}

///|
fn BitmapImage::clone(self : BitmapImage) -> BitmapImage {
  { ..self, image: self.image.clone(), }
}

///|
/// Parses a face freshly (upstream parses one in every `with_face_data`
/// call; variations are set on it).
fn FontDatabase::fresh_face(self : FontDatabase, id : FontId) -> @otf.Face? {
  guard self.face(id) is Some(info) else { return None }
  (try? @otf.Face::parse(info.source[:], info.index)).to_option()
}

///|
fn FontDatabase::outline(
  self : FontDatabase,
  id : FontId,
  glyph_id : Int,
) -> TinyPath? {
  guard self.fresh_face(id) is Some(font) else { return None }

  // For variable fonts, we need to set default variation values to get proper outlines
  if font.is_variable() {
    for axis in font.variation_axes().iter() {
      font.set_variation(axis.tag, axis.def_value) |> ignore
    }
  }
  let builder : GlyphPathBuilder = {
    builder: @tiny_skia_path.PathBuilder::new(),
  }
  guard font.outline_glyph(@otf.GlyphId(glyph_id.to_uint16()), builder)
    is Some(_) else {
    return None
  }
  builder.builder.finish()
}

///|
fn FontDatabase::outline_with_variations(
  self : FontDatabase,
  id : FontId,
  glyph_id : Int,
  variations : Array[FontVariation],
  font_size : Float,
  font_optical_sizing : FontOpticalSizing,
) -> TinyPath? {
  guard self.fresh_face(id) is Some(font) else { return None }
  for v in variations {
    font.set_variation(
      @otf.Tag::from_bytes(Bytes::makei(4, i => v.tag[i])),
      v.value,
    )
    |> ignore
  }

  // Auto-set opsz if font-optical-sizing is auto and not explicitly set
  if font_optical_sizing == OpticalAuto {
    let has_explicit_opsz = variations
      .iter()
      .any(v => v.tag == b"opsz".to_fixedarray())
    if !has_explicit_opsz {
      // Check if font has opsz axis
      if font.tables().fvar is Some(axes) {
        let has_opsz_axis = axes.axes
          .iter()
          .any(axis => axis.tag == @otf.Tag::from_bytes(b"opsz"))
        if has_opsz_axis {
          font.set_variation(@otf.Tag::from_bytes(b"opsz"), font_size) |> ignore
        }
      }
    }
  }
  let builder : GlyphPathBuilder = {
    builder: @tiny_skia_path.PathBuilder::new(),
  }
  guard font.outline_glyph(@otf.GlyphId(glyph_id.to_uint16()), builder)
    is Some(_) else {
    return None
  }
  builder.builder.finish()
}

///|
fn FontDatabase::has_opsz_axis(self : FontDatabase, id : FontId) -> Bool {
  match self.parse_face(id) {
    Some(font) =>
      match font.tables().fvar {
        Some(axes) =>
          axes.axes
          .iter()
          .any(axis => axis.tag == @otf.Tag::from_bytes(b"opsz"))
        None => false
      }
    None => false
  }
}

///|
fn FontDatabase::raster(
  self : FontDatabase,
  id : FontId,
  glyph_id : Int,
) -> BitmapImage? {
  guard self.parse_face(id) is Some(font) else { return None }
  let gid = @otf.GlyphId(glyph_id.to_uint16())
  guard font.glyph_raster_image(gid, 0xFFFF) is Some(image) else { return None }
  if image.format == PNG {
    guard Size::from_wh(
        Float::from_int(image.width.to_int()),
        Float::from_int(image.height.to_int()),
      )
      is Some(size) else {
      return None
    }
    guard NonZeroRect::from_xywh(
        0.0,
        0.0,
        Float::from_int(image.width.to_int()),
        Float::from_int(image.height.to_int()),
      )
      is Some(abs_bounding_box) else {
      return None
    }
    let bitmap_image : BitmapImage = {
      image: {
        id: "",
        visible: true,
        size,
        rendering_mode: OptimizeQuality,
        kind: PNG(image.data.to_owned()),
        abs_transform: Transform::default(),
        abs_bounding_box,
      },
      x: image.x.to_int(),
      y: image.y.to_int(),
      pixels_per_em: image.pixels_per_em.to_int(),
      glyph_bbox: font.glyph_bounding_box(gid),
      // ttf-parser always checks sbix first, so if this table exists, it was used.
      is_sbix: font.tables().sbix is Some(_),
    }
    return Some(bitmap_image)
  }
  None
}

///|
fn FontDatabase::svg(self : FontDatabase, id : FontId, glyph_id : Int) -> Node? {
  // TODO: Technically not 100% accurate because the SVG format in a OTF font
  // is actually a subset/superset of a normal SVG, but it seems to work fine
  // for Twitter Color Emoji, so might as well use what we already have.

  // TODO: Glyph records can contain the data for multiple glyphs. We should
  // add a cache so we don't need to reparse the data every time.
  guard self.parse_face(id) is Some(font) else { return None }
  guard font.glyph_svg_image(@otf.GlyphId(glyph_id.to_uint16())) is Some(image) else {
    return None
  }
  guard (try? Tree::from_data(image.data.to_owned(), Options::default()))
    is Ok(tree) else {
    return None
  }

  // Twitter Color Emoji seems to always have one SVG record per glyph,
  // while Noto Color Emoji sometimes contains multiple ones. It's kind of hacky,
  // but the best we have for now.
  if image.start_glyph_id == image.end_glyph_id {
    Some(Group(tree.root))
  } else {
    // Upstream warns: Failed to find SVG glyph node for glyph {}
    tree.node_by_id("glyph\{glyph_id}").map(Node::clone)
  }
}

///|
fn FontDatabase::colr(
  self : FontDatabase,
  id : FontId,
  glyph_id : Int,
) -> Tree? {
  guard self.parse_face(id) is Some(face) else { return None }
  let svg = @xmlwriter.XmlWriter::new(@xmlwriter.Options::default())
  svg.start_element("svg")
  svg.write_attribute("xmlns", "http://www.w3.org/2000/svg")
  svg.write_attribute("xmlns:xlink", "http://www.w3.org/1999/xlink")
  let path_buf = StringBuilder()
  let gradient_index = 1
  let clip_path_index = 1
  svg.start_element("g")
  let glyph_painter : GlyphPainter = {
    face,
    svg,
    path_buf,
    gradient_index,
    clip_path_index,
    palette_index: 0,
    transform: @otf.Transform::default(),
    outline_transform: @otf.Transform::default(),
    transforms_stack: [@otf.Transform::default()],
  }
  guard face.paint_color_glyph(
      @otf.GlyphId(glyph_id.to_uint16()),
      0,
      { red: 0, green: 0, blue: 0, alpha: 255, },
      glyph_painter,
    )
    is Some(_) else {
    return None
  }
  svg.end_element()
  (try? Tree::from_data(@utf8.encode(svg.end_document()), Options::default())).to_option()
}

///|
fn Cache::fontdb_outline(self : Cache, font : FontId, glyph : Int) -> TinyPath? {
  match self.cache_outline.get((font, glyph)) {
    Some(hit) => hit
    None => {
      let lookup = self.fontdb.outline(font, glyph)
      self.cache_outline[(font, glyph)] = lookup
      lookup
    }
  }
}

///|
fn Cache::fontdb_colr(self : Cache, font : FontId, glyph : Int) -> Tree? {
  match self.cache_colr.get((font, glyph)) {
    Some(hit) => hit.map(Tree::clone)
    None => {
      let lookup = self.fontdb.colr(font, glyph)
      self.cache_colr[(font, glyph)] = lookup
      lookup.map(Tree::clone)
    }
  }
}

///|
fn Cache::fontdb_svg(self : Cache, font : FontId, glyph : Int) -> Node? {
  match self.cache_svg.get((font, glyph)) {
    Some(hit) => hit.map(Node::clone)
    None => {
      let lookup = self.fontdb.svg(font, glyph)
      self.cache_svg[(font, glyph)] = lookup
      lookup.map(Node::clone)
    }
  }
}

///|
fn Cache::fontdb_raster(
  self : Cache,
  font : FontId,
  glyph : Int,
) -> BitmapImage? {
  match self.cache_raster.get((font, glyph)) {
    Some(hit) => hit.map(BitmapImage::clone)
    None => {
      let lookup = self.fontdb.raster(font, glyph)
      self.cache_raster[(font, glyph)] = lookup
      lookup.map(BitmapImage::clone)
    }
  }
}

///|
fn Cache::has_opsz_axis(self : Cache, font : FontId) -> Bool {
  match self.cache_has_opsz.get(font) {
    Some(cached) => cached
    None => {
      let has_opsz = self.fontdb.has_opsz_axis(font)
      self.cache_has_opsz[font] = has_opsz
      has_opsz
    }
  }
}

///|
/// The shared objects referenced by the glyph caches (which hold clones of
/// the trees and nodes put into the flattened text).
fn Cache::extra_ref_roots(self : Cache, counter : RefCounter) -> Unit {
  for _, tree in self.cache_colr {
    if tree is Some(tree) {
      counter.tree(tree)
    }
  }
  for _, node in self.cache_svg {
    if node is Some(node) {
      counter.node(node)
    }
  }
}

///|
/// A copy of the tree (upstream's `Clone`: shared objects stay shared).
fn Tree::clone(self : Tree) -> Tree {
  {
    ..self,
    root: self.root.clone(),
    linear_gradients: self.linear_gradients.copy(),
    radial_gradients: self.radial_gradients.copy(),
    patterns: self.patterns.copy(),
    clip_paths: self.clip_paths.copy(),
    masks: self.masks.copy(),
    filters: self.filters.copy(),
  }
}

///|
fn RefCounter::text(self : RefCounter, text : Text) -> Unit {
  for chunk in text.chunks {
    for span in chunk.spans {
      self.fill(span.fill)
      self.stroke(span.stroke)
      for
        deco in [
          span.decoration.underline,
          span.decoration.overline,
          span.decoration.line_through,
        ] {
        if deco is Some(deco) {
          self.fill(deco.fill)
          self.stroke(deco.stroke)
        }
      }
    }
  }
  for span in text.layouted {
    self.fill(span.fill)
    self.stroke(span.stroke)
    for path in [span.overline, span.underline, span.line_through] {
      if path is Some(path) {
        self.fill(path.fill)
        self.stroke(path.stroke)
      }
    }
  }
  self.group(text.flattened)
}
