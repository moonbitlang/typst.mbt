// The `font` stage, part 2: GDEF/GSUB/GPOS, MATH and COLR (mirrors the
// second half of `oracle/src/font.rs`).

///|
/// Accumulates per-glyph lines into hashed blocks of 256 glyphs, printing a
/// sample of the lines in full.
priv struct Blocks {
  out : StringBuilder
  prefix : String
  count : Int
  block : StringBuilder
  mut start : Int
}

///|
fn Blocks::new(out : StringBuilder, prefix : String, count : Int) -> Blocks {
  { out, prefix, count, block: StringBuilder::new(), start: 0, }
}

///|
fn Blocks::push(self : Blocks, gid : Int, line : String) -> Unit {
  if is_sample(gid, self.count) {
    self.out.write_string("\{self.prefix} \{gid} \{line}\n")
  }
  self.block.write_string(line)
  self.block.write_char('\n')
  if (gid + 1) % 256 == 0 || gid + 1 == self.count {
    self.out.write_string(
      "\{self.prefix}s \{self.start}..\{gid} fnv \{hex16(fnv(self.block.to_string()))}\n",
    )
    self.block.reset()
    self.start = gid + 1
  }
}

///|
fn glyph_class_name(c : @otf.GlyphClass?) -> String {
  match c {
    Some(Base) => "Base"
    Some(Ligature) => "Ligature"
    Some(Mark) => "Mark"
    Some(Component) => "Component"
    None => "-"
  }
}

///|
fn join_u16(items : Iter[UInt16]) -> String {
  items.map(i => i.to_string()).to_array().join(",")
}

///|
fn font_dump_layout(out : StringBuilder, face : @otf.Face) -> Unit {
  let count = face.number_of_glyphs().to_int()
  if face.tables().gdef is Some(gdef) {
    out.write_string("gdef has_glyph_classes \{gdef.has_glyph_classes()}\n")
    let blocks = Blocks::new(out, "gdef glyph", count)
    for gid in 0..<count {
      let g = @otf.GlyphId(gid.to_uint16())
      let line = "\{glyph_class_name(gdef.glyph_class(g))} \{gdef.glyph_mark_attachment_class(g)} \{gdef.is_mark_glyph(g, None)}"
      blocks.push(gid, line)
    }
  }
  for entry in [("gsub", face.tables().gsub), ("gpos", face.tables().gpos)] {
    let (name, table) = entry
    guard table is Some(table) else { continue }
    for script in table.scripts.iter() {
      let langs = []
      if script.default_language is Some(lang) {
        langs.push(lang)
      }
      for lang in script.languages.iter() {
        langs.push(lang)
      }
      let text = StringBuilder::new()
      text.write_string("\{name} script \{esc(script.tag.to_string())}")
      for lang in langs {
        text.write_string(
          " [\{esc(lang.tag.to_string())} req=\{fopt(lang.required_feature)} \{join_u16(lang.feature_indices.iter())}]",
        )
      }
      out.write_string(text.to_string() + "\n")
    }
    let mut i = 0
    for feature in table.features.iter() {
      out.write_string(
        "\{name} feature \{i} \{esc(feature.tag.to_string())} \{join_u16(feature.lookup_indices.iter())}\n",
      )
      i += 1
    }
    out.write_string("\{name} variations \{table.variations is Some(_)}\n")
    let mut i = 0
    for lookup in table.lookups.iter() {
      let kinds = []
      let text = StringBuilder::new()
      for k in 0..<lookup.subtables.len().to_int() {
        let coverage = if name == "gsub" {
          let st : @otf.SubstitutionSubtable? = lookup.subtables.get(
            k.to_uint16(),
          )
          guard st is Some(st) else {
            kinds.push("?")
            continue
          }
          kinds.push(
            match st {
              Single(_) => "Single"
              Multiple(_) => "Multiple"
              Alternate(_) => "Alternate"
              Ligature(_) => "Ligature"
              Context(_) => "Context"
              ChainContext(_) => "ChainContext"
              ReverseChainSingle(_) => "ReverseChainSingle"
            },
          )
          st.coverage()
        } else {
          let st : @otf.PositioningSubtable? = lookup.subtables.get(
            k.to_uint16(),
          )
          guard st is Some(st) else {
            kinds.push("?")
            continue
          }
          kinds.push(
            match st {
              Single(_) => "Single"
              Pair(_) => "Pair"
              Cursive(_) => "Cursive"
              MarkToBase(_) => "MarkToBase"
              MarkToLigature(_) => "MarkToLigature"
              MarkToMark(_) => "MarkToMark"
              Context(_) => "Context"
              ChainContext(_) => "ChainContext"
            },
          )
          st.coverage()
        }
        for gid in 0..<count {
          if coverage.get(@otf.GlyphId(gid.to_uint16())) is Some(idx) {
            text.write_string("\{gid}:\{idx};")
          }
        }
        text.write_char('|')
      }
      out.write_string(
        "\{name} lookup \{i} flags \{lookup.flags.0} set \{fopt(lookup.mark_filtering_set)} subtables \{kinds.join(",")} coverage \{hex16(fnv(text.to_string()))}\n",
      )
      i += 1
    }
  }
}

///|
fn math_value(v : @otf.MathValue) -> String {
  "\{v.value}" + (if v.device is Some(_) { "d" } else { "" })
}

///|
fn math_value_opt(v : @otf.MathValue?) -> String {
  match v {
    Some(v) => math_value(v)
    None => "-"
  }
}

///|
fn math_construction(c : @otf.GlyphConstruction?) -> String {
  guard c is Some(c) else { return "-" }
  let text = StringBuilder::new()
  for v in c.variants.iter() {
    text.write_string("\{v.variant_glyph.0}:\{v.advance_measurement},")
  }
  if c.assembly is Some(a) {
    text.write_string(" asm \{math_value(a.italics_correction)}")
    for p in a.parts.iter() {
      text.write_string(
        " \{p.glyph_id.0}:\{p.start_connector_length}:\{p.end_connector_length}:\{p.full_advance}:\{p.part_flags.extender()}",
      )
    }
  }
  text.to_string()
}

///|
fn math_kern(k : @otf.MathKern?) -> String {
  guard k is Some(k) else { return "-" }
  let text = StringBuilder::new()
  text.write_string("\{k.count()}")
  for i in 0..<k.count().to_int() {
    text.write_string(",\{math_value_opt(k.height(i.to_uint16()))}")
  }
  for i in 0..<=k.count().to_int() {
    text.write_string(",\{math_value_opt(k.kern(i.to_uint16()))}")
  }
  text.to_string()
}

///|
fn font_dump_math(out : StringBuilder, face : @otf.Face) -> Unit {
  guard face.tables().math is Some(math) else { return }
  if math.constants is Some(c) {
    let values = [
      c.math_leading(),
      c.axis_height(),
      c.accent_base_height(),
      c.flattened_accent_base_height(),
      c.subscript_shift_down(),
      c.subscript_top_max(),
      c.subscript_baseline_drop_min(),
      c.superscript_shift_up(),
      c.superscript_shift_up_cramped(),
      c.superscript_bottom_min(),
      c.superscript_baseline_drop_max(),
      c.sub_superscript_gap_min(),
      c.superscript_bottom_max_with_subscript(),
      c.space_after_script(),
      c.upper_limit_gap_min(),
      c.upper_limit_baseline_rise_min(),
      c.lower_limit_gap_min(),
      c.lower_limit_baseline_drop_min(),
      c.stack_top_shift_up(),
      c.stack_top_display_style_shift_up(),
      c.stack_bottom_shift_down(),
      c.stack_bottom_display_style_shift_down(),
      c.stack_gap_min(),
      c.stack_display_style_gap_min(),
      c.stretch_stack_top_shift_up(),
      c.stretch_stack_bottom_shift_down(),
      c.stretch_stack_gap_above_min(),
      c.stretch_stack_gap_below_min(),
      c.fraction_numerator_shift_up(),
      c.fraction_numerator_display_style_shift_up(),
      c.fraction_denominator_shift_down(),
      c.fraction_denominator_display_style_shift_down(),
      c.fraction_numerator_gap_min(),
      c.fraction_num_display_style_gap_min(),
      c.fraction_rule_thickness(),
      c.fraction_denominator_gap_min(),
      c.fraction_denom_display_style_gap_min(),
      c.skewed_fraction_horizontal_gap(),
      c.skewed_fraction_vertical_gap(),
      c.overbar_vertical_gap(),
      c.overbar_rule_thickness(),
      c.overbar_extra_ascender(),
      c.underbar_vertical_gap(),
      c.underbar_rule_thickness(),
      c.underbar_extra_descender(),
      c.radical_vertical_gap(),
      c.radical_display_style_vertical_gap(),
      c.radical_rule_thickness(),
      c.radical_extra_ascender(),
      c.radical_kern_before_degree(),
      c.radical_kern_after_degree(),
    ]
    out.write_string(
      "math constants \{c.script_percent_scale_down()} \{c.script_script_percent_scale_down()} \{c.delimited_sub_formula_min_height()} \{c.display_operator_min_height()} \{c.radical_degree_bottom_raise_percent()} \{values.map(math_value).join(" ")}\n",
    )
  }
  if math.variants is Some(v) {
    out.write_string("math min_connector_overlap \{v.min_connector_overlap}\n")
  }
  let count = face.number_of_glyphs().to_int()
  let blocks = Blocks::new(out, "math glyph", count)
  for gid in 0..<count {
    let g = @otf.GlyphId(gid.to_uint16())
    let line = StringBuilder::new()
    if math.glyph_info is Some(info) {
      let italic = match info.italic_corrections {
        Some(v) => math_value_opt(v.get(g))
        None => "-"
      }
      let accent = match info.top_accent_attachments {
        Some(v) => math_value_opt(v.get(g))
        None => "-"
      }
      let extended = match info.extended_shapes {
        Some(c) => c.contains(g)
        None => false
      }
      line.write_string(
        "italic \{italic} accent \{accent} extended \{extended} kern",
      )
      let kern = match info.kern_infos {
        Some(k) => k.get(g)
        None => None
      }
      match kern {
        Some(k) =>
          line.write_string(
            " \{math_kern(k.top_right)} \{math_kern(k.top_left)} \{math_kern(k.bottom_right)} \{math_kern(k.bottom_left)}",
          )
        None => line.write_string(" -")
      }
    }
    if math.variants is Some(v) {
      line.write_string(
        " vert \{math_construction(v.vertical_constructions.get(g))} horiz \{math_construction(v.horizontal_constructions.get(g))}",
      )
    }
    blocks.push(gid, line.to_string())
  }
}

///|
fn rgba(c : @otf.RgbaColor) -> String {
  "\{c.red.to_int()},\{c.green.to_int()},\{c.blue.to_int()},\{c.alpha.to_int()}"
}

///|
priv struct ColrRecorder {
  buf : StringBuilder
}

///|
fn ColrRecorder::stops(
  self : ColrRecorder,
  stops : @otf.GradientStopsIter,
  extend_ : @otf.GradientExtend,
) -> Unit {
  let name = match extend_ {
    Pad => "pad"
    Repeat => "repeat"
    Reflect => "reflect"
  }
  self.buf.write_string(name)
  while stops.next() is Some(stop) {
    self.buf.write_string(" \{rgba(stop.color)}@\{ff(stop.stop_offset)}")
  }
}

///|
fn composite_mode_name(mode : @otf.CompositeMode) -> String {
  match mode {
    Clear => "Clear"
    Source => "Source"
    Destination => "Destination"
    SourceOver => "SourceOver"
    DestinationOver => "DestinationOver"
    SourceIn => "SourceIn"
    DestinationIn => "DestinationIn"
    SourceOut => "SourceOut"
    DestinationOut => "DestinationOut"
    SourceAtop => "SourceAtop"
    DestinationAtop => "DestinationAtop"
    Xor => "Xor"
    Plus => "Plus"
    Screen => "Screen"
    Overlay => "Overlay"
    Darken => "Darken"
    Lighten => "Lighten"
    ColorDodge => "ColorDodge"
    ColorBurn => "ColorBurn"
    HardLight => "HardLight"
    SoftLight => "SoftLight"
    Difference => "Difference"
    Exclusion => "Exclusion"
    Multiply => "Multiply"
    Hue => "Hue"
    Saturation => "Saturation"
    Color => "Color"
    Luminosity => "Luminosity"
  }
}

///|
impl @otf.ColrPainter for ColrRecorder with fn outline_glyph(self, glyph_id) {
  self.buf.write_string("outline \{glyph_id.0};")
}

///|
impl @otf.ColrPainter for ColrRecorder with fn paint(self, paint) {
  let no_coords : Array[@otf.NormalizedCoordinate] = []
  match paint {
    Solid(c) => self.buf.write_string("solid \{rgba(c)};")
    LinearGradient(g) => {
      self.buf.write_string(
        "linear \{ff(g.x0)} \{ff(g.y0)} \{ff(g.x1)} \{ff(g.y1)} \{ff(g.x2)} \{ff(g.y2)} ",
      )
      self.stops(g.stops(0, no_coords[:]), g.extend_)
      self.buf.write_char(';')
    }
    RadialGradient(g) => {
      self.buf.write_string(
        "radial \{ff(g.x0)} \{ff(g.y0)} \{ff(g.r0)} \{ff(g.r1)} \{ff(g.x1)} \{ff(g.y1)} ",
      )
      self.stops(g.stops(0, no_coords[:]), g.extend_)
      self.buf.write_char(';')
    }
    SweepGradient(g) => {
      self.buf.write_string(
        "sweep \{ff(g.center_x)} \{ff(g.center_y)} \{ff(g.start_angle)} \{ff(g.end_angle)} ",
      )
      self.stops(g.stops(0, no_coords[:]), g.extend_)
      self.buf.write_char(';')
    }
  }
}

///|
impl @otf.ColrPainter for ColrRecorder with fn push_clip(self) {
  self.buf.write_string("clip;")
}

///|
impl @otf.ColrPainter for ColrRecorder with fn push_clip_box(self, b) {
  self.buf.write_string(
    "clipbox \{ff(b.x_min)} \{ff(b.y_min)} \{ff(b.x_max)} \{ff(b.y_max)};",
  )
}

///|
impl @otf.ColrPainter for ColrRecorder with fn pop_clip(self) {
  self.buf.write_string("popclip;")
}

///|
impl @otf.ColrPainter for ColrRecorder with fn push_layer(self, mode) {
  self.buf.write_string("layer \{composite_mode_name(mode)};")
}

///|
impl @otf.ColrPainter for ColrRecorder with fn pop_layer(self) {
  self.buf.write_string("poplayer;")
}

///|
impl @otf.ColrPainter for ColrRecorder with fn push_transform(self, t) {
  self.buf.write_string(
    "transform \{ff(t.a)} \{ff(t.b)} \{ff(t.c)} \{ff(t.d)} \{ff(t.e)} \{ff(t.f)};",
  )
}

///|
impl @otf.ColrPainter for ColrRecorder with fn pop_transform(self) {
  self.buf.write_string("poptransform;")
}

///|
fn font_dump_colr(out : StringBuilder, face : @otf.Face) -> Unit {
  guard face.color_palettes() is Some(palettes) else { return }
  out.write_string("colr palettes \{palettes}\n")
  let count = face.number_of_glyphs().to_int()
  let blocks = Blocks::new(out, "colr glyph", count)
  for gid in 0..<count {
    let g = @otf.GlyphId(gid.to_uint16())
    let rec : ColrRecorder = { buf: StringBuilder::new(), }
    let res = face.paint_color_glyph(
      g,
      0,
      @otf.RgbaColor::new(b'\x01', b'\x02', b'\x03', b'\xFF'),
      rec,
    )
    blocks.push(gid, "\{res is Some(_)} \{rec.buf.to_string()}")
  }
}
