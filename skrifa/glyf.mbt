// Port of skrifa 0.42.1 `src/outline/glyf/mod.rs`, `outline.rs` and
// `memory.rs` (FreeType style scaler; variations are not supported, i.e.
// only the default location is drawn).

///|
/// Number of phantom points generated at the end of an outline.
pub const PHANTOM_POINT_COUNT : Int = 4

///|
/// Maximum number of points we support in a single outline including
/// composites.
const MAX_POINTS : Int = 65535

///|
/// Scaler state for TrueType outlines.
pub struct GlyfOutlines {
  font : FontRef
  priv hmtx : @read_fonts.Hmtx
  priv loca : @read_fonts.Loca
  priv glyf : @read_fonts.Glyf
  fpgm : BytesView
  prep : BytesView
  cvt_len : Int
  max_function_defs : Int
  max_instruction_defs : Int
  max_twilight_points : Int
  max_stack_elements : Int
  max_storage : Int
  glyph_count : Int
  units_per_em : Int
  os2_vmetrics : (Int, Int)
  prefer_interpreter : Bool
  fractional_size_hinting : Bool
}

///|
pub fn GlyfOutlines::new(font : FontRef) -> GlyfOutlines? {
  let head = font.head() catch { _ => return None }
  // If bit 3 of head.flags is set, then we round ppems when scaling
  let fractional_size_hinting = (
      head.flags() & @read_fonts.HEAD_FLAG_FORCE_INTEGER_PPEM
    ) ==
    0
  let loca = font.loca(Some(head.index_to_loc_format() == 1)) catch {
    _ => return None
  }
  let glyf = font.glyf() catch { _ => return None }
  // GlyphHMetrics::new: hmtx is required
  let hmtx = font.hmtx() catch { _ => return None }
  let (
    glyph_count,
    max_function_defs,
    max_instruction_defs,
    max_twilight_points,
    max_stack_elements,
    max_storage,
    max_instructions,
  ) = match res(() => font.maxp()) {
    Ok(maxp) =>
      (
        maxp.num_glyphs(),
        maxp.max_function_defs().unwrap_or(0),
        maxp.max_instruction_defs().unwrap_or(0),
        // Add 4 for phantom points
        sat_u16(maxp.max_twilight_points().unwrap_or(0) + 4),
        // Add 32 to match FreeType's heuristic for buggy fonts
        sat_u16(maxp.max_stack_elements().unwrap_or(0) + 32),
        maxp.max_storage().unwrap_or(0),
        maxp.max_size_of_instructions().unwrap_or(0),
      )
    Err(_) => (0, 0, 0, 0, 0, 0, 0)
  }
  let os2_vmetrics = match res(() => font.os2()) {
    Ok(os2) => (os2.s_typo_ascender(), os2.s_typo_descender())
    Err(_) => (0, 0)
  }
  let fpgm = match font.data_for_tag("fpgm") {
    Some(d) => d.as_bytes()
    None => b""[:]
  }
  let prep = match font.data_for_tag("prep") {
    Some(d) => d.as_bytes()
    None => b""[:]
  }
  // Copy FreeType's logic on whether to use the interpreter
  let prefer_interpreter = !(max_instructions == 0 &&
    fpgm.length() == 0 &&
    prep.length() == 0)
  let cvt_len = match font.data_for_tag("cvt ") {
    Some(d) => if d.len() % 2 == 0 { d.len() / 2 } else { 0 }
    None => 0
  }
  Some({
    font,
    hmtx,
    loca,
    glyf,
    fpgm,
    prep,
    cvt_len,
    max_function_defs,
    max_instruction_defs,
    max_twilight_points,
    max_stack_elements,
    max_storage,
    glyph_count,
    units_per_em: head.units_per_em(),
    os2_vmetrics,
    prefer_interpreter,
    fractional_size_hinting,
  })
}

///|
fn sat_u16(v : Int) -> Int {
  if v > 0xFFFF {
    0xFFFF
  } else {
    v
  }
}

///|
/// Advance width in font units (`GlyphHMetrics::advance_width` at the
/// default location).
fn GlyfOutlines::advance_width(self : GlyfOutlines, gid : GlyphId) -> Int {
  self.hmtx.advance(gid).unwrap_or(0)
}

///|
/// Left side bearing in font units (`GlyphHMetrics::lsb`).
fn GlyfOutlines::lsb(self : GlyfOutlines, gid : GlyphId) -> Int {
  self.hmtx.side_bearing(gid).unwrap_or(0)
}

///|
/// Represents the information necessary to scale a glyph outline.
pub struct GlyfOutline {
  glyph_id : GlyphId
  /// The associated top-level glyph for the outline.
  glyph : @read_fonts.Glyph?
  /// Sum of the point counts of all simple glyphs in an outline.
  mut points : Int
  /// Sum of the contour counts of all simple glyphs in an outline.
  mut contours : Int
  /// Maximum number of points in a single simple glyph.
  mut max_simple_points : Int
  /// "Other" points are the unscaled or original scaled points.
  mut max_other_points : Int
  /// Maximum size of the component delta stack.
  mut max_component_delta_stack : Int
  /// Number of entries in the hinting value stack.
  mut max_stack : Int
  /// Number of CVT entries for copy-on-write support.
  mut cvt_count : Int
  /// Number of storage area entries for copy-on-write support.
  mut storage_count : Int
  /// Maximum number of points in the twilight zone for hinting.
  mut max_twilight_points : Int
  /// True if any component of a glyph has bytecode instructions.
  mut has_hinting : Bool
  /// True if the glyph requires variation delta processing.
  has_variations : Bool
  /// True if the glyph contains any simple or compound overlap flags.
  mut has_overlaps : Bool
}

///|
pub fn GlyfOutlines::outline(
  self : GlyfOutlines,
  glyph_id : GlyphId,
) -> GlyfOutline raise DrawError {
  let glyph = self.loca.get_glyf(glyph_id, self.glyf) catch {
    e => raise Read(e)
  }
  let outline : GlyfOutline = {
    glyph_id,
    glyph,
    points: 0,
    contours: 0,
    max_simple_points: 0,
    max_other_points: 0,
    max_component_delta_stack: 0,
    max_stack: 0,
    cvt_count: 0,
    storage_count: 0,
    max_twilight_points: 0,
    has_hinting: false,
    has_variations: self.font.data_for_tag("gvar") is Some(_),
    has_overlaps: false,
  }
  if glyph is Some(g) {
    self.outline_rec(g, outline, 0, 0)
  }
  outline.points += PHANTOM_POINT_COUNT
  outline.max_stack = self.max_stack_elements
  outline.cvt_count = self.cvt_len
  outline.storage_count = self.max_storage
  outline.max_twilight_points = self.max_twilight_points
  outline
}

///|
fn imax(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn GlyfOutlines::outline_rec(
  self : GlyfOutlines,
  glyph : @read_fonts.Glyph,
  outline : GlyfOutline,
  component_depth : Int,
  recurse_depth : Int,
) -> Unit raise DrawError {
  if recurse_depth > GLYF_COMPOSITE_RECURSION_LIMIT {
    raise RecursionLimitExceeded(outline.glyph_id)
  }
  match glyph {
    Simple(simple) => {
      let num_points = simple.num_points()
      let num_points_with_phantom = num_points + PHANTOM_POINT_COUNT
      outline.max_simple_points = imax(
        outline.max_simple_points,
        num_points_with_phantom,
      )
      outline.points += num_points
      outline.contours += simple.end_pts_of_contours().length()
      outline.has_hinting = outline.has_hinting ||
        simple.instruction_length() != 0
      outline.max_other_points = imax(
        outline.max_other_points,
        num_points_with_phantom,
      )
      outline.has_overlaps = outline.has_overlaps ||
        simple.has_overlapping_contours()
    }
    Composite(composite) => {
      let (components, instructions) = composite.component_glyphs_and_flags()
      let count = components.length() + PHANTOM_POINT_COUNT
      let point_base = outline.points
      for item in components {
        let (component, flags) = item
        if (flags & @read_fonts.OVERLAP_COMPOUND) != 0 {
          outline.has_overlaps = true
        }
        let component_glyph = self.loca.get_glyf(
          GlyphId::from_int(component),
          self.glyf,
        ) catch {
          e => raise Read(e)
        }
        guard component_glyph is Some(component_glyph) else { continue }
        self.outline_rec(
          component_glyph,
          outline,
          component_depth + count,
          recurse_depth + 1,
        )
      }
      let has_hinting = match instructions {
        Some(ins) => ins.length() != 0
        None => false
      }
      if has_hinting {
        // We only need the "other points" buffers if the
        // composite glyph has instructions.
        let num_points_in_composite = outline.points -
          point_base +
          PHANTOM_POINT_COUNT
        outline.max_other_points = imax(
          outline.max_other_points,
          num_points_in_composite,
        )
      }
      outline.max_component_delta_stack = imax(
        outline.max_component_delta_stack,
        component_depth + count,
      )
      outline.has_hinting = outline.has_hinting || has_hinting
    }
  }
}

///|
fn GlyfOutline::ensure_point_count_limit(
  self : GlyfOutline,
) -> Unit raise DrawError {
  if self.points > MAX_POINTS {
    raise TooManyPoints(self.glyph_id)
  }
}

///|
/// Returns (is_scaled, scale) for the given size.
pub fn GlyfOutlines::compute_scale(
  self : GlyfOutlines,
  ppem : Float?,
) -> (Bool, F26Dot6) {
  if ppem is Some(ppem) && self.units_per_em > 0 {
    return (
      true,
      F26Dot6::from_bits((ppem * 64.0).to_int()) /
      F26Dot6::from_bits(self.units_per_em),
    )
  }
  (false, F26Dot6::from_bits(0x10000))
}

///|
pub fn GlyfOutlines::compute_hinted_scale(
  self : GlyfOutlines,
  ppem : Float?,
) -> (Bool, F26Dot6) {
  if ppem is Some(ppem) && !self.fractional_size_hinting {
    // Apply a fixed point round to ppem if the font doesn't
    // support fractional scaling and hinting was requested.
    return self.compute_scale(
      Some(F26Dot6::from_f64(ppem.to_double()).round().to_f32()),
    )
  }
  self.compute_scale(ppem)
}

///|
/// Buffers used during glyph scaling (structure of arrays).
priv struct FreeTypeOutlineMemory {
  unscaled_x : FixedArray[Int]
  unscaled_y : FixedArray[Int]
  scaled_x : FixedArray[Int]
  scaled_y : FixedArray[Int]
  original_scaled_x : FixedArray[Int]
  original_scaled_y : FixedArray[Int]
  contours : FixedArray[Int]
  flags : FixedArray[Int]
}

///|
fn FreeTypeOutlineMemory::new(
  outline : GlyfOutline,
  hinted : Bool,
) -> FreeTypeOutlineMemory {
  let hinted = outline.has_hinting && hinted
  let other = if hinted { outline.max_other_points } else { 0 }
  {
    scaled_x: FixedArray::make(outline.points, 0),
    scaled_y: FixedArray::make(outline.points, 0),
    unscaled_x: FixedArray::make(outline.max_other_points, 0),
    unscaled_y: FixedArray::make(outline.max_other_points, 0),
    original_scaled_x: FixedArray::make(other, 0),
    original_scaled_y: FixedArray::make(other, 0),
    contours: FixedArray::make(outline.contours, 0),
    flags: FixedArray::make(outline.points, 0),
  }
}

///|
/// F26Dot6 coords and a penchant for rounding.
priv struct FreeTypeScaler {
  outlines : GlyfOutlines
  memory : FreeTypeOutlineMemory
  mut point_count : Int
  mut contour_count : Int
  ppem : Float
  scale : F26Dot6
  is_scaled : Bool
  is_hinted : Bool
  pedantic_hinting : Bool
  /// Phantom points (26.6 bits).
  phantom_x : FixedArray[Int]
  phantom_y : FixedArray[Int]
  hinter : HintInstance?
}

///|
fn FreeTypeScaler::unhinted(
  outlines : GlyfOutlines,
  outline : GlyfOutline,
  ppem : Float?,
) -> FreeTypeScaler raise DrawError {
  outline.ensure_point_count_limit()
  let (is_scaled, scale) = outlines.compute_scale(ppem)
  {
    outlines,
    memory: FreeTypeOutlineMemory::new(outline, false),
    point_count: 0,
    contour_count: 0,
    ppem: ppem.unwrap_or(0.0),
    scale,
    is_scaled,
    is_hinted: false,
    pedantic_hinting: false,
    phantom_x: FixedArray::make(4, 0),
    phantom_y: FixedArray::make(4, 0),
    hinter: None,
  }
}

///|
fn FreeTypeScaler::hinted(
  outlines : GlyfOutlines,
  outline : GlyfOutline,
  ppem : Float?,
  hinter : HintInstance,
  pedantic_hinting : Bool,
) -> FreeTypeScaler raise DrawError {
  outline.ensure_point_count_limit()
  let (is_scaled, scale) = outlines.compute_hinted_scale(ppem)
  {
    outlines,
    memory: FreeTypeOutlineMemory::new(outline, true),
    point_count: 0,
    contour_count: 0,
    ppem: ppem.unwrap_or(0.0),
    scale,
    is_scaled,
    // We don't hint unscaled outlines
    is_hinted: is_scaled,
    pedantic_hinting,
    phantom_x: FixedArray::make(4, 0),
    phantom_y: FixedArray::make(4, 0),
    hinter: Some(hinter),
  }
}

///|
/// The result of scaling: points, flags and contours plus phantom points.
priv struct ScaledOutline {
  xs : ArrayView[Int]
  ys : ArrayView[Int]
  flags : ArrayView[Int]
  contours : ArrayView[Int]
  phantom_x : FixedArray[Int]
  phantom_y : FixedArray[Int]
}

///|
fn FreeTypeScaler::scale(
  self : FreeTypeScaler,
  glyph : @read_fonts.Glyph?,
  glyph_id : GlyphId,
) -> ScaledOutline raise DrawError {
  self.load(glyph, glyph_id, 0)
  let n = self.point_count
  let xs = self.memory.scaled_x
  let x_shift = self.phantom_x[0]
  if x_shift != 0 {
    for i in 0..<n {
      xs[i] = xs[i] - x_shift
    }
  }
  {
    xs: xs[0:n],
    ys: self.memory.scaled_y[0:n],
    flags: self.memory.flags[0:n],
    contours: self.memory.contours[0:self.contour_count],
    phantom_x: self.phantom_x,
    phantom_y: self.phantom_y,
  }
}

///|
fn FreeTypeScaler::load(
  self : FreeTypeScaler,
  glyph : @read_fonts.Glyph?,
  glyph_id : GlyphId,
  recurse_depth : Int,
) -> Unit raise DrawError {
  if recurse_depth > GLYF_COMPOSITE_RECURSION_LIMIT {
    raise RecursionLimitExceeded(glyph_id)
  }
  let (x_min, x_max, y_min, y_max) = match glyph {
    Some(g) => (g.x_min(), g.x_max(), g.y_min(), g.y_max())
    None => (0, 0, 0, 0)
  }
  ignore(x_max)
  ignore(y_min)
  let outlines = self.outlines
  let lsb = outlines.lsb(glyph_id)
  let advance = outlines.advance_width(glyph_id)
  let (ascent, descent) = outlines.os2_vmetrics
  let tsb = ascent - y_max
  let vadvance = ascent - descent
  self.setup_phantom_points(x_min, y_max, lsb, advance, tsb, vadvance)
  match glyph {
    Some(Simple(simple)) => self.load_simple(simple, glyph_id)
    Some(Composite(composite)) =>
      self.load_composite(composite, glyph_id, recurse_depth)
    None => self.load_empty(glyph_id)
  }
}

///|
/// The four "phantom" points as computed by FreeType.
fn FreeTypeScaler::setup_phantom_points(
  self : FreeTypeScaler,
  x_min : Int,
  y_max : Int,
  lsb : Int,
  advance : Int,
  tsb : Int,
  vadvance : Int,
) -> Unit {
  // horizontal:
  self.phantom_x[0] = x_min - lsb
  self.phantom_y[0] = 0
  self.phantom_x[1] = self.phantom_x[0] + advance
  self.phantom_y[1] = 0
  // vertical:
  self.phantom_x[2] = 0
  self.phantom_y[2] = y_max + tsb
  self.phantom_x[3] = 0
  self.phantom_y[3] = self.phantom_y[2] - vadvance
}

///|
fn mul26(a : Int, s : F26Dot6) -> Int {
  (F26Dot6::from_bits(a) * s).to_bits()
}

///|
// Cannot fail; keeps upstream's `Result<(), DrawError>`
// (skrifa 0.42.1 src/outline/glyf/mod.rs:519).
#warnings("-unused_error_type")
fn FreeTypeScaler::load_empty(
  self : FreeTypeScaler,
  _glyph_id : GlyphId,
) -> Unit raise DrawError {
  // Roughly corresponds to the FreeType code for empty glyphs.
  let scale = self.scale
  for i in 0..<4 {
    if self.is_scaled {
      self.phantom_x[i] = mul26(self.phantom_x[i], scale)
      self.phantom_y[i] = mul26(self.phantom_y[i], scale)
    } else {
      self.phantom_x[i] = self.phantom_x[i] << 6
      self.phantom_y[i] = self.phantom_y[i] << 6
    }
  }
}

///|
fn FreeTypeScaler::load_simple(
  self : FreeTypeScaler,
  glyph : @read_fonts.SimpleGlyph,
  glyph_id : GlyphId,
) -> Unit raise DrawError {
  let mem = self.memory
  // Compute the ranges for our point/flag buffers.
  let points_start = self.point_count
  let point_count = glyph.num_points()
  let phantom_start = point_count
  let points_end = points_start + point_count + PHANTOM_POINT_COUNT
  let other_points_end = point_count + PHANTOM_POINT_COUNT
  if points_end > mem.scaled_x.length() ||
    points_end > mem.flags.length() ||
    other_points_end > mem.unscaled_x.length() {
    raise InsufficientMemory
  }
  // Read our unscaled points and flags (up to point_count which does not
  // include phantom points).
  read_points_into(glyph, mem, points_start, point_count) catch {
    e => raise Read(e)
  }
  // Compute the range for our contour end point buffer.
  let contours_start = self.contour_count
  let contour_end_pts = glyph.end_pts_of_contours()
  let contour_count = contour_end_pts.length()
  let contours_end = contours_start + contour_count
  if contours_end > mem.contours.length() {
    raise InsufficientMemory
  }
  // Read the contour end points, ensuring that they are properly ordered.
  let mut last_end_pt = 0
  for i, end_pt in contour_end_pts {
    if end_pt < last_end_pt {
      raise Read(
        MalformedData("unordered contour end points in TrueType glyph"),
      )
    }
    last_end_pt = end_pt
    mem.contours[contours_start + i] = end_pt
  }
  // Adjust the running point/contour total counts
  self.point_count += point_count
  self.contour_count += contour_count
  // Append phantom points to the outline.
  for i in 0..<4 {
    mem.unscaled_x[phantom_start + i] = self.phantom_x[i]
    mem.unscaled_y[phantom_start + i] = self.phantom_y[i]
    mem.flags[points_start + phantom_start + i] = 0
  }
  let ins = glyph.instructions()
  let is_hinted = self.is_hinted
  if self.is_scaled {
    let scale = self.scale
    for i in 0..<other_points_end {
      mem.scaled_x[points_start + i] = mul26(mem.unscaled_x[i], scale)
      mem.scaled_y[points_start + i] = mul26(mem.unscaled_y[i], scale)
    }
  } else {
    // Unlike FreeType, we also store unscaled outlines in 26.6.
    for i in 0..<other_points_end {
      mem.scaled_x[points_start + i] = mem.unscaled_x[i] << 6
      mem.scaled_y[points_start + i] = mem.unscaled_y[i] << 6
    }
  }
  // Commit our potentially modified phantom points.
  for i in 0..<4 {
    self.phantom_x[i] = mem.scaled_x[points_start + phantom_start + i]
    self.phantom_y[i] = mem.scaled_y[points_start + phantom_start + i]
  }
  if self.hinter is Some(hinter) && is_hinted {
    self.hint_simple(
      hinter, glyph_id, ins, points_start, point_count, contours_start, contour_count,
    )
  }
  if points_start != 0 {
    // If we're not the first component, shift our contour end points.
    for i in contours_start..<contours_end {
      mem.contours[i] = (mem.contours[i] + points_start) & 0xFFFF
    }
  }
}

///|
/// `SimpleGlyph::read_points_fast` into the scaler memory: unscaled points
/// at the base of the unscaled buffer and flags at `points_start`.
fn read_points_into(
  glyph : @read_fonts.SimpleGlyph,
  mem : FreeTypeOutlineMemory,
  points_start : Int,
  point_count : Int,
) -> Unit raise ReadError {
  // Flags are written relative to `points_start` while the unscaled points
  // start at 0, so read into temporaries first.
  let xs = FixedArray::make(point_count, 0)
  let ys = FixedArray::make(point_count, 0)
  let flags = FixedArray::make(point_count, 0)
  for i in 0..<point_count {
    flags[i] = mem.flags[points_start + i]
  }
  glyph.read_points_fast(xs, ys, flags, 0)
  for i in 0..<point_count {
    mem.unscaled_x[i] = xs[i]
    mem.unscaled_y[i] = ys[i]
    mem.flags[points_start + i] = flags[i]
  }
}

///|
fn scale_component(x : F2Dot14) -> F26Dot6 {
  F26Dot6::from_bits(x.to_bits() * 4)
}

///|
fn FreeTypeScaler::load_composite(
  self : FreeTypeScaler,
  glyph : @read_fonts.CompositeGlyph,
  glyph_id : GlyphId,
  recurse_depth : Int,
) -> Unit raise DrawError {
  let mem = self.memory
  let scale = self.scale
  // The base indices of the points and contours for the current glyph.
  let point_base = self.point_count
  let contour_base = self.contour_count
  if self.is_scaled {
    for i in 0..<4 {
      self.phantom_x[i] = mul26(self.phantom_x[i], scale)
      self.phantom_y[i] = mul26(self.phantom_y[i], scale)
    }
  } else {
    for i in 0..<4 {
      self.phantom_x[i] = self.phantom_x[i] << 6
      self.phantom_y[i] = self.phantom_y[i] << 6
    }
  }
  for component in glyph.components() {
    // Loading a component glyph will override phantom points so save a
    // copy. We'll restore them unless the USE_MY_METRICS flag is set.
    let saved_x = self.phantom_x.copy()
    let saved_y = self.phantom_y.copy()
    // Load the component glyph and keep track of the points range.
    let start_point = self.point_count
    let component_gid = GlyphId::from_int(component.glyph)
    let component_glyph = self.outlines.loca.get_glyf(
      component_gid,
      self.outlines.glyf,
    ) catch {
      e => raise Read(e)
    }
    self.load(component_glyph, component_gid, recurse_depth + 1)
    let end_point = self.point_count
    if (component.flags & @read_fonts.USE_MY_METRICS) == 0 {
      // If the USE_MY_METRICS flag is missing, we restore the phantom
      // points we saved at the start of the loop.
      for i in 0..<4 {
        self.phantom_x[i] = saved_x[i]
        self.phantom_y[i] = saved_y[i]
      }
    }
    // Prepares the transform components for our conversion math below.
    let xform = component.transform
    let xx = scale_component(xform.xx)
    let yx = scale_component(xform.yx)
    let xy = scale_component(xform.xy)
    let yy = scale_component(xform.yy)
    let have_xform = (
        component.flags &
        (
          @read_fonts.WE_HAVE_A_SCALE |
          @read_fonts.WE_HAVE_AN_X_AND_Y_SCALE |
          @read_fonts.WE_HAVE_A_TWO_BY_TWO
        )
      ) !=
      0
    if have_xform {
      for i in start_point..<end_point {
        let px = F26Dot6::from_bits(mem.scaled_x[i])
        let py = F26Dot6::from_bits(mem.scaled_y[i])
        if self.is_scaled {
          let x = px * xx + py * xy
          let y = px * yx + py * yy
          mem.scaled_x[i] = x.to_bits()
          mem.scaled_y[i] = y.to_bits()
        } else {
          // This juggling is necessary because, unlike FreeType, we also
          // return unscaled outlines in 26.6 format for a consistent
          // interface.
          let ux = F26Dot6::from_bits(px.to_i32())
          let uy = F26Dot6::from_bits(py.to_i32())
          let x = ux * xx + uy * xy
          let y = ux * yx + uy * yy
          mem.scaled_x[i] = x.to_bits() << 6
          mem.scaled_y[i] = y.to_bits() << 6
        }
      }
    }
    let (ox, oy) = match component.anchor {
      Offset(x~, y~) => {
        let mut x = x
        let mut y = y
        if have_xform &&
          (
            component.flags &
            (
              @read_fonts.SCALED_COMPONENT_OFFSET |
              @read_fonts.UNSCALED_COMPONENT_OFFSET
            )
          ) ==
          @read_fonts.SCALED_COMPONENT_OFFSET {
          // According to FreeType, this algorithm is a "guess"
          // and works better than the one documented by Apple.
          let hypot = fn(a : F26Dot6, b : F26Dot6) -> Fixed {
            let a = a.abs().to_bits()
            let b = b.abs().to_bits()
            Fixed::from_bits(
              if a > b {
                a + ((3 * b) >> 3)
              } else {
                b + ((3 * a) >> 3)
              },
            )
          }
          // FreeType uses a fixed point multiplication here.
          x = (Fixed::from_bits(x) * hypot(xx, xy)).to_bits()
          y = (Fixed::from_bits(y) * hypot(yy, yx)).to_bits()
        }
        if self.is_scaled {
          let ox = mul26(x, scale)
          let mut oy = mul26(y, scale)
          if self.is_hinted &&
            (component.flags & @read_fonts.ROUND_XY_TO_GRID) != 0 {
            // Only round the y-coordinate, per FreeType.
            oy = F26Dot6::from_bits(oy).round().to_bits()
          }
          (ox, oy)
        } else {
          (x << 6, y << 6)
        }
      }
      Point(base~, component=comp) => {
        let bi = point_base + base
        let ci = start_point + comp
        if bi >= mem.scaled_x.length() {
          raise InvalidAnchorPoint(glyph_id, base)
        }
        if ci >= mem.scaled_x.length() {
          raise InvalidAnchorPoint(glyph_id, comp)
        }
        (
          mem.scaled_x[bi] - mem.scaled_x[ci],
          mem.scaled_y[bi] - mem.scaled_y[ci],
        )
      }
    }
    if ox != 0 || oy != 0 {
      for i in start_point..<end_point {
        mem.scaled_x[i] = mem.scaled_x[i] + ox
        mem.scaled_y[i] = mem.scaled_y[i] + oy
      }
    }
  }
  if self.hinter is Some(hinter) && self.is_hinted {
    let ins = glyph.instructions().unwrap_or(b""[:])
    if ins.length() != 0 {
      self.hint_composite(hinter, glyph_id, ins, point_base, contour_base)
    }
  }
}
