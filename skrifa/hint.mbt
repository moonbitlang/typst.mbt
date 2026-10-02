// Port of skrifa 0.42.1 `src/outline/glyf/hint/instance.rs` and the
// hinting parts of the FreeType scaler in `src/outline/glyf/mod.rs`.

///|
pub fn Target::default() -> Target {
  Smooth(mode=Normal, symmetric_rendering=true, preserve_linear_metrics=false)
}

///|
fn Target::is_smooth(self : Target) -> Bool {
  self is Smooth(..)
}

///|
fn Target::is_grayscale_cleartype(self : Target) -> Bool {
  match self {
    Smooth(mode~, ..) => mode is (Normal | Light)
    _ => false
  }
}

///|
fn Target::is_vertical_lcd(self : Target) -> Bool {
  self is Smooth(mode=VerticalLcd, ..)
}

///|
fn Target::symmetric_rendering(self : Target) -> Bool {
  self is Smooth(symmetric_rendering=true, ..)
}

///|
fn Target::preserve_linear_metrics(self : Target) -> Bool {
  self is Smooth(preserve_linear_metrics=true, ..)
}

///|
/// Hinting instance state for TrueType outlines.
priv struct HintInstance {
  functions : Array[Definition]
  instructions : Array[Definition]
  cvt : FixedArray[Int]
  storage : FixedArray[Int]
  mut graphics : RetainedGraphicsState
  twilight_scaled_x : FixedArray[Int]
  twilight_scaled_y : FixedArray[Int]
  twilight_original_x : FixedArray[Int]
  twilight_original_y : FixedArray[Int]
  twilight_flags : FixedArray[Int]
  axis_count : Int
  max_stack : Int
}

///|
/// Creates the instance: captures limits, scales the CVT and runs the font
/// and control value programs.
fn HintInstance::new(
  outlines : GlyfOutlines,
  scale : Int,
  ppem : Int,
  target : Target,
) -> HintInstance raise DrawError {
  // setup()
  let axis_count = match outlines.font.data_for_tag("gvar") {
    Some(d) if d.len() >= 20 => d.read_u16(4) catch { _ => 0 }
    _ => 0
  }
  let functions = Array::make(outlines.max_function_defs, Definition::default())
  let instructions = Array::make(
    outlines.max_instruction_defs,
    Definition::default(),
  )
  // CVT values are converted to 26.6 on load
  let cvt_data = match outlines.font.data_for_tag("cvt ") {
    Some(d) if d.len() % 2 == 0 => d
    _ => @read_fonts.FontData::empty()
  }
  let cvt = FixedArray::make(cvt_data.len() / 2, 0)
  // More weird scaling. This is due to the fact that CVT values are
  // already in 26.6
  let fscale = Fixed::from_bits(scale >> 6)
  for i in 0..<cvt.length() {
    let v = (cvt_data.read_i16(i * 2) catch { _ => 0 }) * 64
    cvt[i] = (Fixed::from_bits(v) * fscale).to_bits()
  }
  let storage = FixedArray::make(outlines.max_storage, 0)
  let n = outlines.max_twilight_points
  let instance : HintInstance = {
    functions,
    instructions,
    cvt,
    storage,
    graphics: RetainedGraphicsState::default(),
    twilight_scaled_x: FixedArray::make(n, 0),
    twilight_scaled_y: FixedArray::make(n, 0),
    twilight_original_x: FixedArray::make(n, 0),
    twilight_original_y: FixedArray::make(n, 0),
    twilight_flags: FixedArray::make(n, 0),
    axis_count,
    max_stack: outlines.max_stack_elements,
  }
  let twilight_contours : FixedArray[Int] = [n & 0xFFFF]
  let twilight : Zone = {
    unscaled_x: IntSlice::empty(),
    unscaled_y: IntSlice::empty(),
    original_x: IntSlice::new(instance.twilight_original_x, 0, n),
    original_y: IntSlice::new(instance.twilight_original_y, 0, n),
    points_x: IntSlice::new(instance.twilight_scaled_x, 0, n),
    points_y: IntSlice::new(instance.twilight_scaled_y, 0, n),
    flags: IntSlice::new(instance.twilight_flags, 0, n),
    contours: IntSlice::new(twilight_contours, 0, 1),
  }
  let engine = Interp::new(
    outlines.cvt_len,
    ProgramState::new(outlines.fpgm, outlines.prep, b""[:], Font),
    RetainedGraphicsState::new(scale, ppem, target),
    { defs: instance.functions, is_mut: true, },
    { defs: instance.instructions, is_mut: true, },
    CowSlice::new_mut(instance.cvt),
    CowSlice::new_mut(instance.storage),
    ValueStack::new(instance.max_stack, false),
    twilight,
    Zone::default(),
    axis_count,
    [],
    false,
  )
  try {
    // Run the font program (fpgm)
    engine.run_program(Font, false)
    // Run the control value program (prep)
    engine.run_program(ControlValue, false)
  } catch {
    e => raise HintingFailed(e.message())
  }
  // Save the retained state from the CV program
  instance.graphics = engine.graphics.retained.copy()
  instance
}

///|
/// Returns true if we should actually apply hinting.
fn HintInstance::is_enabled(self : HintInstance) -> Bool {
  // If bit 0 is set, disables hinting entirely
  (self.graphics.instruct_control & 1) == 0
}

///|
/// Returns true if backward compatibility mode has been activated by the
/// hinter settings or the `prep` table.
fn HintInstance::backward_compatibility(self : HintInstance) -> Bool {
  if self.graphics.target.preserve_linear_metrics() {
    true
  } else if self.graphics.target.is_smooth() {
    (self.graphics.instruct_control & 0x4) == 0
  } else {
    false
  }
}

///|
/// Runs the glyph program for the given glyph zone. On success (and when
/// not in backward compatibility mode) the phantom points are updated from
/// the last four points of the zone.
fn HintInstance::hint(
  self : HintInstance,
  outlines : GlyfOutlines,
  glyph_id : GlyphId,
  glyph : Zone,
  bytecode : BytesView,
  phantom_x : FixedArray[Int],
  phantom_y : FixedArray[Int],
  is_composite : Bool,
  is_pedantic : Bool,
) -> Unit raise HintError {
  // Twilight zone
  let n = self.twilight_scaled_x.length()
  let twilight_contours : FixedArray[Int] = [n & 0xFFFF]
  let twilight : Zone = {
    unscaled_x: IntSlice::empty(),
    unscaled_y: IntSlice::empty(),
    original_x: IntSlice::new(self.twilight_original_x.copy(), 0, n),
    original_y: IntSlice::new(self.twilight_original_y.copy(), 0, n),
    points_x: IntSlice::new(self.twilight_scaled_x.copy(), 0, n),
    points_y: IntSlice::new(self.twilight_scaled_y.copy(), 0, n),
    flags: IntSlice::new(self.twilight_flags.copy(), 0, n),
    contours: IntSlice::new(twilight_contours, 0, 1),
  }
  let engine = Interp::new(
    outlines.cvt_len,
    ProgramState::new(outlines.fpgm, outlines.prep, bytecode, Glyph),
    self.graphics.copy(),
    { defs: self.functions, is_mut: false, },
    { defs: self.instructions, is_mut: false, },
    CowSlice::new(self.cvt),
    CowSlice::new(self.storage),
    ValueStack::new(self.max_stack, is_pedantic),
    twilight,
    glyph,
    self.axis_count,
    [],
    is_composite,
  )
  engine.run_program(Glyph, is_pedantic) catch {
    HintError(program~, pc~, opcode~, kind~, ..) =>
      raise HintError(program~, glyph_id=Some(glyph_id), pc~, opcode~, kind~)
  }
  // If we're not running in backward compatibility mode, capture
  // modified phantom points.
  if !engine.backward_compatibility() {
    let len = glyph.len()
    for i in 0..<4 {
      phantom_x[i] = glyph.points_x.get(len - 4 + i)
      phantom_y[i] = glyph.points_y.get(len - 4 + i)
    }
  }
}

///|
fn round26(x : Int) -> Int {
  (x + 32) & -64
}

///|
fn FreeTypeScaler::hint_simple(
  self : FreeTypeScaler,
  hinter : HintInstance,
  glyph_id : GlyphId,
  ins : BytesView,
  points_start : Int,
  point_count : Int,
  contours_start : Int,
  contour_count : Int,
) -> Unit raise DrawError {
  let mem = self.memory
  let other_points_end = point_count + PHANTOM_POINT_COUNT
  let phantom_start = point_count
  if ins.length() != 0 {
    // Create a copy of our scaled points in original_scaled.
    if other_points_end > mem.original_scaled_x.length() {
      raise InsufficientMemory
    }
    for i in 0..<other_points_end {
      mem.original_scaled_x[i] = mem.scaled_x[points_start + i]
      mem.original_scaled_y[i] = mem.scaled_y[points_start + i]
    }
    // When hinting, round the phantom points.
    for i in phantom_start..<other_points_end {
      mem.scaled_x[points_start + i] = round26(mem.scaled_x[points_start + i])
      mem.scaled_y[points_start + i] = round26(mem.scaled_y[points_start + i])
    }
    let glyph : Zone = {
      unscaled_x: IntSlice::new(mem.unscaled_x, 0, other_points_end),
      unscaled_y: IntSlice::new(mem.unscaled_y, 0, other_points_end),
      original_x: IntSlice::new(mem.original_scaled_x, 0, other_points_end),
      original_y: IntSlice::new(mem.original_scaled_y, 0, other_points_end),
      points_x: IntSlice::new(mem.scaled_x, points_start, other_points_end),
      points_y: IntSlice::new(mem.scaled_y, points_start, other_points_end),
      flags: IntSlice::new(mem.flags, points_start, other_points_end),
      contours: IntSlice::new(mem.contours, contours_start, contour_count),
    }
    hinter.hint(
      self.outlines,
      glyph_id,
      glyph,
      ins,
      self.phantom_x,
      self.phantom_y,
      false,
      self.pedantic_hinting,
    ) catch {
      e => if self.pedantic_hinting { raise HintingFailed(e.message()) }
    }
  } else if !hinter.backward_compatibility() {
    // Even when missing instructions, FreeType uses rounded
    // phantom points when hinting is requested and backward
    // compatibility mode is disabled.
    for i in 0..<4 {
      self.phantom_x[i] = round26(
        mem.scaled_x[points_start + phantom_start + i],
      )
      self.phantom_y[i] = round26(
        mem.scaled_y[points_start + phantom_start + i],
      )
    }
  }
}

///|
fn FreeTypeScaler::hint_composite(
  self : FreeTypeScaler,
  hinter : HintInstance,
  glyph_id : GlyphId,
  ins : BytesView,
  point_base : Int,
  contour_base : Int,
) -> Unit raise DrawError {
  let mem = self.memory
  // For composite glyphs, the unscaled and original points are
  // simply copies of the current point set.
  let start_point = point_base
  let end_point = self.point_count + PHANTOM_POINT_COUNT
  let range_len = end_point - start_point
  let phantom_start = range_len - PHANTOM_POINT_COUNT
  if end_point > mem.flags.length() {
    raise InsufficientMemory
  }
  // Append the current phantom points to the outline.
  for i in 0..<4 {
    mem.scaled_x[start_point + phantom_start + i] = self.phantom_x[i]
    mem.scaled_y[start_point + phantom_start + i] = self.phantom_y[i]
    mem.flags[start_point + phantom_start + i] = 0
  }
  let other_points_end = range_len
  if other_points_end > mem.unscaled_x.length() {
    raise InsufficientMemory
  }
  for i in 0..<other_points_end {
    mem.unscaled_x[i] = mem.scaled_x[start_point + i]
    mem.unscaled_y[i] = mem.scaled_y[start_point + i]
  }
  if other_points_end > mem.original_scaled_x.length() {
    raise InsufficientMemory
  }
  for i in 0..<other_points_end {
    mem.original_scaled_x[i] = mem.scaled_x[start_point + i]
    mem.original_scaled_y[i] = mem.scaled_y[start_point + i]
  }
  if self.contour_count > mem.contours.length() ||
    contour_base > self.contour_count {
    raise InsufficientMemory
  }
  // Round the phantom points.
  for i in phantom_start..<range_len {
    mem.scaled_x[start_point + i] = round26(mem.scaled_x[start_point + i])
    mem.scaled_y[start_point + i] = round26(mem.scaled_y[start_point + i])
  }
  // Clear the "touched" flags that are used during IUP processing.
  for i in 0..<range_len {
    mem.flags[start_point + i] = mem.flags[start_point + i] &
      (MARKER_TOUCHED ^ 0xFF)
  }
  // Make sure our contour end points accurately reflect the outline
  // slices.
  if point_base != 0 {
    for i in contour_base..<self.contour_count {
      mem.contours[i] = (mem.contours[i] - point_base) & 0xFFFF
    }
  }
  let glyph : Zone = {
    unscaled_x: IntSlice::new(mem.unscaled_x, 0, other_points_end),
    unscaled_y: IntSlice::new(mem.unscaled_y, 0, other_points_end),
    original_x: IntSlice::new(mem.original_scaled_x, 0, other_points_end),
    original_y: IntSlice::new(mem.original_scaled_y, 0, other_points_end),
    points_x: IntSlice::new(mem.scaled_x, start_point, range_len),
    points_y: IntSlice::new(mem.scaled_y, start_point, range_len),
    flags: IntSlice::new(mem.flags, start_point, range_len),
    contours: IntSlice::new(
      mem.contours,
      contour_base,
      self.contour_count - contour_base,
    ),
  }
  hinter.hint(
    self.outlines,
    glyph_id,
    glyph,
    ins,
    self.phantom_x,
    self.phantom_y,
    true,
    self.pedantic_hinting,
  ) catch {
    e => if self.pedantic_hinting { raise HintingFailed(e.message()) }
  }
  // Undo the contour shifts if we applied them above.
  if point_base != 0 {
    for i in contour_base..<self.contour_count {
      mem.contours[i] = (mem.contours[i] + point_base) & 0xFFFF
    }
  }
}
