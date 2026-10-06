// Port of `hayro-interpret/src/interpret/state.rs`.

///|
/// A transfer function.
pub(all) enum ActiveTransferFunction {
  /// A single transfer function applied to all components.
  Single(@function.Function)
  /// Four transfer functions, one for each component.
  Four(FixedArray[@function.Function])
}

///|
/// Apply the transfer function to the RGB channels of an RGBA color.
/// The alpha channel is left unchanged.
pub fn ActiveTransferFunction::apply(
  self : ActiveTransferFunction,
  color : AlphaColor,
) -> AlphaColor {
  let rgba = color.components()
  match self {
    Single(f) =>
      for i in 0..<3 {
        if f.eval([rgba[i]]) is Some(out) {
          rgba[i] = out[0]
        }
      }
    Four(functions) =>
      for i in 0..<3 {
        if functions[i].eval([rgba[i]]) is Some(out) {
          rgba[i] = out[0]
        }
      }
  }
  AlphaColor::new(rgba)
}

///|
priv enum ClipType {
  Dummy
  Real
}

///|
struct State {
  // Note that the text state and ctm are theoretically part of the graphics state,
  // but we keep them separate for simplicity.
  mut graphics_state : GraphicsState
  mut text_state : TextState
  mut ctm : @kurbo.Affine
  // Strictly speaking not part of the graphics state, but we keep it there for
  // consistency.
  clips : Array[ClipType]
}

///|
fn State::default() -> State {
  {
    ctm: @kurbo.Affine::identity(),
    clips: [],
    text_state: TextState::default(),
    graphics_state: GraphicsState::default(),
  }
}

///|
fn State::new(initial_transform : @kurbo.Affine) -> State {
  { ..State::default(), ctm: initial_transform, }
}

///|
/// A deep copy (upstream `#[derive(Clone)]`).
fn State::clone(self : State) -> State {
  {
    graphics_state: self.graphics_state.clone(),
    text_state: self.text_state.clone(),
    ctm: self.ctm,
    clips: self.clips.copy(),
  }
}

///|
fn State::stroke_data(self : State) -> PaintData {
  {
    alpha: self.graphics_state.stroke_alpha,
    color: self.graphics_state.stroke_color,
    color_space: self.graphics_state.stroke_cs,
    pattern: self.graphics_state.stroke_pattern,
    transfer_function: self.graphics_state.transfer_function,
  }
}

///|
fn State::non_stroke_data(self : State) -> PaintData {
  {
    alpha: self.graphics_state.non_stroke_alpha,
    color: self.graphics_state.non_stroke_color,
    color_space: self.graphics_state.none_stroke_cs,
    pattern: self.graphics_state.non_stroke_pattern,
    transfer_function: self.graphics_state.transfer_function,
  }
}

///|
priv enum TextStateFont {
  /// The font in the text state was explicitly set and resolves to a valid
  /// font.
  Font(Font)
  /// The font was not set or an invalid font was set.
  Fallback(Font)
}

///|
fn TextStateFont::font(self : TextStateFont) -> Font {
  match self {
    Font(f) => f
    Fallback(f) => f
  }
}

///|
priv struct TextState {
  mut char_space : Float
  mut word_space : Float
  // Note that this stores 1/100 of the actual scaling.
  mut horizontal_scaling : Float
  mut leading : Float
  mut font : TextStateFont?
  mut font_size : Float
  mut rise : Float
  mut render_mode : TextRenderingMode
  mut text_matrix : @kurbo.Affine
  mut text_line_matrix : @kurbo.Affine
  // When setting the text rendering mode to `clip`, the glyphs should instead be collected
  // as paths and then applied as 1 single clip path. This field stores those clip paths.
  mut clip_paths : @kurbo.BezPath
}

///|
fn TextState::clone(self : TextState) -> TextState {
  { ..self, clip_paths: self.clip_paths.clone(), }
}

///|
fn TextState::temp_transform(self : TextState) -> @kurbo.Affine {
  @kurbo.Affine::new([
    self.font_size.to_double() * self.horizontal_scaling_().to_double(),
    0.0,
    0.0,
    self.font_size.to_double(),
    0.0,
    self.rise.to_double(),
  ])
}

///|
fn TextState::horizontal_scaling_(self : TextState) -> Float {
  self.horizontal_scaling / 100.0
}

///|
fn TextState::font_horizontal(self : TextState) -> Bool {
  match self.font {
    Some(f) => f.font().is_horizontal()
    None => false
  }
}

///|
fn TextState::apply_adjustment(self : TextState, adjustment : Float) -> Unit {
  let horizontal = self.font_horizontal()
  let horizontal_scaling = if horizontal {
    self.horizontal_scaling_()
  } else {
    1.0
  }
  let scaled_adjustment = -adjustment /
    units_per_em *
    self.font_size *
    horizontal_scaling
  let (tx, ty) : (Float, Float) = if horizontal {
    (scaled_adjustment, 0.0)
  } else {
    (0.0, scaled_adjustment)
  }
  self.text_matrix = self.text_matrix *
    @kurbo.Affine::new([1.0, 0.0, 0.0, 1.0, tx.to_double(), ty.to_double()])
}

///|
fn TextState::apply_code_advance(
  self : TextState,
  char_code : UInt,
  code_len : Int,
) -> Unit {
  let glyph_advance = match self.font {
    Some(f) => f.font().code_advance(char_code)
    None => @kurbo.vec2_zero
  }
  let horizontal = self.font_horizontal()
  let word_space : Float = if char_code == 32 && code_len == 1 {
    self.word_space
  } else {
    0.0
  }
  let base_advance = (advance : Float) => {
    advance / units_per_em * self.font_size + self.char_space + word_space
  }
  let tx : Float = if horizontal {
    base_advance(Float::from_double(glyph_advance.x)) *
    self.horizontal_scaling_()
  } else {
    0.0
  }
  let ty : Float = if !horizontal {
    base_advance(Float::from_double(glyph_advance.y))
  } else {
    0.0
  }
  self.text_matrix = self.text_matrix *
    @kurbo.Affine::new([1.0, 0.0, 0.0, 1.0, tx.to_double(), ty.to_double()])
}

///|
fn TextState::full_transform(self : TextState) -> @kurbo.Affine {
  self.text_matrix * self.temp_transform()
}

///|
fn TextState::default() -> TextState {
  {
    char_space: 0.0,
    word_space: 0.0,
    horizontal_scaling: 100.0,
    leading: 0.0,
    font: None,
    // Not in the specification, but we just define it so we don't need to use an option.
    font_size: 1.0,
    render_mode: Fill,
    text_matrix: @kurbo.Affine::identity(),
    text_line_matrix: @kurbo.Affine::identity(),
    rise: 0.0,
    clip_paths: @kurbo.BezPath::new(),
  }
}

///|
priv struct GraphicsState {
  // Stroke parameters.
  mut stroke_props : StrokeProps
  // Stroke paint parameters.
  mut stroke_color : ColorComponents
  mut stroke_pattern : Pattern?
  mut stroke_cs : ColorSpace
  mut stroke_alpha : Float
  // Non-stroke paint parameters.
  mut non_stroke_color : ColorComponents
  mut non_stroke_pattern : Pattern?
  mut none_stroke_cs : ColorSpace
  mut non_stroke_alpha : Float
  mut soft_mask : SoftMask?
  mut transfer_function : ActiveTransferFunction?
  mut blend_mode : BlendMode
}

///|
/// A copy (`StrokeProps`, colors and patterns are treated as immutable
/// values and shared).
fn GraphicsState::clone(self : GraphicsState) -> GraphicsState {
  { ..self, }
}

///|
fn GraphicsState::default() -> GraphicsState {
  {
    stroke_props: StrokeProps::default(),
    non_stroke_alpha: 1.0,
    stroke_cs: ColorSpace::device_gray(),
    stroke_color: [0.0],
    none_stroke_cs: ColorSpace::device_gray(),
    non_stroke_color: [0.0],
    stroke_alpha: 1.0,
    stroke_pattern: None,
    non_stroke_pattern: None,
    soft_mask: None,
    transfer_function: None,
    blend_mode: Normal,
  }
}

///|
priv struct PaintData {
  alpha : Float
  color : ColorComponents
  color_space : ColorSpace
  pattern : Pattern?
  transfer_function : ActiveTransferFunction?
}

///|
fn handle_gs(
  dict : @hayro_syntax.Dict,
  context : Context,
  parent_resources : @hayro_syntax.Resources,
) -> Unit {
  for key in dict.keys() {
    // warn_none: "invalid value in graphics state for {key}"
    let _ = handle_gs_single(dict, key, context, parent_resources)
  }
}

///|
fn handle_gs_single(
  dict : @hayro_syntax.Dict,
  key : @hayro_syntax.Name,
  context : Context,
  parent_resources : @hayro_syntax.Resources,
) -> Unit? {
  let k = key.as_str()
  let gs = context.get().graphics_state
  // TODO Can we use constants here somehow?
  match k {
    "LW" => {
      guard (dict.get(k) : Float?) is Some(v) else { return None }
      gs.stroke_props = { ..gs.stroke_props, line_width: v, }
    }
    "LC" => {
      guard (dict.get(k) : @hayro_syntax.Number?) is Some(v) else {
        return None
      }
      gs.stroke_props = { ..gs.stroke_props, line_cap: convert_line_cap(v), }
    }
    "LJ" => {
      guard (dict.get(k) : @hayro_syntax.Number?) is Some(v) else {
        return None
      }
      gs.stroke_props = { ..gs.stroke_props, line_join: convert_line_join(v), }
    }
    "ML" => {
      guard (dict.get(k) : Float?) is Some(v) else { return None }
      gs.stroke_props = { ..gs.stroke_props, miter_limit: v, }
    }
    "CA" => {
      guard (dict.get(k) : Float?) is Some(v) else { return None }
      gs.stroke_alpha = v
    }
    "ca" => {
      guard (dict.get(k) : Float?) is Some(v) else { return None }
      gs.non_stroke_alpha = v
    }
    "TR" | "TR2" => {
      let obj : @hayro_syntax.Object? = match
        (dict.get("TR2") : @hayro_syntax.Object?) {
        Some(o) => Some(o)
        None => dict.get("TR")
      }
      guard obj is Some(obj) else { return None }
      let function = match obj {
        Array(array) => {
          let iter = array.iter().iterator()
          let fs = []
          for _ in 0..<4 {
            guard iter.next() is Some(o) else { return None }
            guard @function.Function::new(o) is Some(f) else { return None }
            fs.push(f)
          }
          Some(ActiveTransferFunction::Four(FixedArray::from_array(fs)))
        }
        // Only `Identity` and `Default` are valid, which both just reset it.
        Name(_) => None
        o => {
          guard @function.Function::new(o) is Some(f) else { return None }
          Some(ActiveTransferFunction::Single(f))
        }
      }
      gs.transfer_function = function
    }
    "SMask" =>
      if (dict.get("SMask") : @hayro_syntax.Name?) is Some(name) {
        if name.as_str() == "None" {
          gs.soft_mask = None
        }
      } else {
        gs.soft_mask = match (dict.get("SMask") : @hayro_syntax.Dict?) {
          Some(d) => SoftMask::new(d, context, parent_resources)
          None => None
        }
      }
    "BM" => {
      if (dict.get(k) : @hayro_syntax.Name?) is Some(name) {
        if convert_blend_mode(name.as_str()) is Some(bm) {
          gs.blend_mode = bm
          return Some(())
        }
      } else if (dict.get(k) : @hayro_syntax.PdfArray?) is Some(arr) {
        for name in (arr.iter() : Iter[@hayro_syntax.Name]) {
          if convert_blend_mode(name.as_str()) is Some(bm) {
            gs.blend_mode = bm
            return Some(())
          }
        }
      }
      // warn!("unknown blend mode, defaulting to Normal");
      gs.blend_mode = Normal
    }
    "Font" => {
      guard (dict.get("Font") : @hayro_syntax.PdfArray?) is Some(arr) else {
        return None
      }
      let iter = (arr.iter() : Iter[@hayro_syntax.Object]).iterator()
      guard iter.next() is Some(o) && o.into_dict() is Some(font_dict) else {
        return None
      }
      guard iter.next() is Some(o) && o.into_number() is Some(size) else {
        return None
      }
      let size = size.as_f32()
      let font = context.resolve_font(font_dict)
      context.get().text_state.font_size = size
      context.get().text_state.font = font
    }
    "D" => {
      guard (dict.get(k) : @hayro_syntax.PdfArray?) is Some(arr) else {
        return None
      }
      let iter = (arr.iter() : Iter[@hayro_syntax.Object]).iterator()
      guard iter.next() is Some(o) && o.into_array() is Some(dash_array) else {
        return None
      }
      guard iter.next() is Some(o) && o.into_number() is Some(dash_phase) else {
        return None
      }
      let dash_phase = dash_phase.as_f32()
      gs.stroke_props = {
        ..gs.stroke_props,
        dash_offset: dash_phase,
        // kurbo apparently cannot properly deal with offsets that are exactly 0.
        dash_array: (dash_array.iter() : Iter[Float])
        .map((n : Float) => if n == 0.0 { (0.01 : Float) } else { n })
        .collect(),
      }
    }
    "Type" => ()
    _ => ()
  }
  Some(())
}

///|
fn convert_blend_mode(name : String) -> BlendMode? {
  let bm : BlendMode = match name {
    "Normal" => Normal
    "Multiply" => Multiply
    "Screen" => Screen
    "Overlay" => Overlay
    "Darken" => Darken
    "Lighten" => Lighten
    "ColorDodge" => ColorDodge
    "ColorBurn" => ColorBurn
    "HardLight" => HardLight
    "SoftLight" => SoftLight
    "Difference" => Difference
    "Exclusion" => Exclusion
    "Hue" => Hue
    "Saturation" => Saturation
    "Color" => Color
    "Luminosity" => Luminosity
    _ => return None
  }
  Some(bm)
}
