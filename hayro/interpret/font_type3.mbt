// Port of `hayro-interpret/src/font/type3.rs` and
// `hayro-interpret/src/font/glyph_simulator.rs`.

///|
priv struct GlyphSimulator {
  // We simulate that Type1 glyphs have glyph IDs so we can handle them transparently
  // to OpenType fonts.
  glyph_to_string : Map[UInt, String]
  string_to_glyph : Map[String, GlyphId]
  mut glyph_counter : UInt
}

///|
fn GlyphSimulator::new() -> GlyphSimulator {
  let glyph_to_string = Map([])
  glyph_to_string[glyph_id_notdef.to_u32()] = "notdef"
  let string_to_glyph = Map([])
  string_to_glyph["notdef"] = glyph_id_notdef
  { glyph_to_string, string_to_glyph, glyph_counter: 1, }
}

///|
fn GlyphSimulator::string_to_glyph(
  self : GlyphSimulator,
  string : String,
) -> GlyphId {
  match self.string_to_glyph.get(string) {
    Some(g) => g
    None => {
      let gid = GlyphId::new(self.glyph_counter)
      self.string_to_glyph[string] = gid
      self.glyph_to_string[gid.to_u32()] = string
      self.glyph_counter += 1
      gid
    }
  }
}

///|
fn GlyphSimulator::glyph_to_string(
  self : GlyphSimulator,
  glyph : GlyphId,
) -> String? {
  self.glyph_to_string.get(glyph.to_u32())
}

///|
priv struct Type3 {
  widths : Array[Width]
  missing_width : Float
  encoding : Encoding
  encodings : Map[Int, String]
  dict : @hayro_syntax.Dict
  char_procs : Map[String, @hayro_syntax.Stream]
  glyph_simulator : GlyphSimulator
  font_bbox : @kurbo.Rect
  matrix : @kurbo.Affine
  to_unicode : @cmap.CMap?
}

///|
fn Type3::new(
  dict : @hayro_syntax.Dict,
  cmap_resolver : CMapResolverFn,
) -> Type3? {
  let (encoding, encodings) = read_encoding(dict)
  guard read_widths(dict, dict) is Some((widths, missing_width)) else {
    return None
  }
  let font_bbox = rect_to_kurbo(
    (dict.get("FontBBox") : @hayro_syntax.Rect?).unwrap_or(
      @hayro_syntax.Rect::new(0.0, 0.0, 0.0, 0.0),
    ),
  )
  let matrix = @kurbo.Affine::new(
    match (dict.get_fixed("FontMatrix", 6) : Array[Double]?) {
      Some(m) => FixedArray::from_array(m)
      None => [0.001, 0.0, 0.0, 0.001, 0.0, 0.0]
    },
  )
  let char_procs = {
    let procs = Map([])
    let dict = (dict.get("CharProcs") : @hayro_syntax.Dict?).unwrap_or(
      @hayro_syntax.Dict::empty(),
    )
    for name in dict.keys() {
      if (dict.get(name.as_str()) : @hayro_syntax.Stream?) is Some(prog) {
        procs[name.as_str()] = prog
      }
    }
    procs
  }
  let to_unicode = read_to_unicode(dict, cmap_resolver)
  Some({
    glyph_simulator: GlyphSimulator::new(),
    encoding,
    font_bbox,
    char_procs,
    widths,
    missing_width,
    encodings,
    matrix,
    dict,
    to_unicode,
  })
}

///|
fn Type3::map_code(self : Type3, code : Byte) -> GlyphId {
  let name = match self.encodings.get(code.to_int()) {
    Some(s) => Some(s)
    None => self.encoding.map_code(code)
  }
  match name {
    Some(g) => self.glyph_simulator.string_to_glyph(g)
    None => glyph_id_notdef
  }
}

///|
fn Type3::glyph_width(self : Type3, code : Byte) -> Float {
  let w = match self.widths.get(code.to_int()) {
    Some(Value(w)) => w
    _ => self.missing_width
  }
  w * self.matrix.as_coeffs()[0].to_float() * units_per_em
}

///|
fn Type3::char_code_to_unicode(
  self : Type3,
  char_code : UInt,
) -> @cmap.BfString? {
  // Type3 fonts can only provide Unicode via ToUnicode CMap.
  match self.to_unicode {
    Some(t) => t.lookup_bf_string(char_code)
    None => None
  }
}

///|
fn Type3::render_glyph(
  self : Type3,
  glyph : Type3Glyph,
  transform : @kurbo.Affine,
  glyph_transform : @kurbo.Affine,
  paint : Paint,
  device : &Device,
) -> Unit? {
  let state = glyph.state.clone()
  let root_transform = transform *
    glyph_transform *
    self.matrix *
    @kurbo.Affine::scale(units_per_em.to_double())
  state.ctm = root_transform

  // Not sure if this is mentioned anywhere, but I do think we need to reset the text state
  // (though the graphics state itself should be preserved).
  state.text_state = TextState::default()
  guard self.glyph_simulator.glyph_to_string(glyph.glyph_id) is Some(name) else {
    return None
  }
  guard self.char_procs.get(name) is Some(program) else { return None }
  guard program.decoded() is Ok(decoded) else { return None }
  let iter = @hayro_syntax.TypedIter::new(decoded)
  let is_shape_glyph = {
    let iter = iter.clone()
    let mut is_shape_glyph = true
    while iter.next() is Some(op) {
      match op {
        ShapeGlyph(_, _, _, _, _, _) => break
        ColorGlyph(_, _) => {
          is_shape_glyph = false
          break
        }
        _ => ()
      }
    }
    is_shape_glyph
  }
  let context = Context::new_with(
    state.ctm,
    self.font_bbox,
    glyph.cache,
    glyph.xref,
    glyph.settings,
    state,
    glyph.nesting_depth,
  )
  let mut resources = @hayro_syntax.Resources::from_parent(
    (self.dict.get("Resources") : @hayro_syntax.Dict?).unwrap_or(
      @hayro_syntax.Dict::empty(),
    ),
    glyph.parent_resources,
  )

  // Technically not valid, but also support by Adobe Acrobat. See PDFBOX-5294.
  if (program.dict().get("Resources") : @hayro_syntax.Dict?)
    is Some(procs_resources) {
    resources = @hayro_syntax.Resources::from_parent(procs_resources, resources)
  }
  if is_shape_glyph {
    let device = Type3ShapeGlyphDevice::new(device, paint)
    interpret(iter, resources, context, device)
  } else {
    interpret(iter, resources, context, device)
  }
  Some(())
}

///|
impl CacheKey for Type3 with fn cache_key(self) {
  CacheKey::cache_key(self.dict)
}

///|
priv struct Type3ShapeGlyphDevice {
  inner : &Device
  paint : Paint
}

///|
fn Type3ShapeGlyphDevice::new(
  device : &Device,
  paint : Paint,
) -> Type3ShapeGlyphDevice {
  { inner: device, paint, }
}

// Only filling, stroking of paths and stencil masks are allowed.

///|
impl Device for Type3ShapeGlyphDevice with fn draw_path(
  self,
  path,
  props,
  draw_mode,
) {
  self.inner.draw_path(path, { ..props, paint: self.paint, }, draw_mode)
}

///|
impl Device for Type3ShapeGlyphDevice with fn push_clip_path(self, clip_path) {
  self.inner.push_clip_path(clip_path)
}

///|
impl Device for Type3ShapeGlyphDevice with fn push_transparency_group(
  _,
  _,
  _,
  _,
) {
  ()
}

///|
impl Device for Type3ShapeGlyphDevice with fn draw_glyph(
  self,
  g,
  glyph_transform,
  props,
  draw_mode,
) {
  self.inner.draw_glyph(g, glyph_transform, props, draw_mode)
}

///|
impl Device for Type3ShapeGlyphDevice with fn pop_clip(self) {
  self.inner.pop_clip()
}

///|
impl Device for Type3ShapeGlyphDevice with fn pop_transparency_group(_) {
  ()
}

///|
impl Device for Type3ShapeGlyphDevice with fn draw_image(self, image, props) {
  if image is Stencil(s) {
    self.inner.draw_image(Stencil({ ..s, paint: self.paint, }), props)
  }
}
