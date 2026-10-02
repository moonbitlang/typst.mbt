// The `font` stage, part 3: the Typst font layer (`FontInfo`, metrics, math
// constants, instances and the `FontBook`), mirroring the end of
// `oracle/src/font.rs`.

///|
fn em(v : @library.Em) -> String {
  @library.rust_display_f64(v.get())
}

///|
fn font_style_name(s : @library.FontStyle) -> String {
  match s {
    Normal => "normal"
    Italic => "italic"
    Oblique => "oblique"
  }
}

///|
fn font_variant(v : @library.FontVariant) -> String {
  let stretch = @library.rust_round(v.stretch.to_ratio().get() * 1000.0)
  "\{font_style_name(v.style)} \{v.weight.to_number()} \{stretch.to_int64()}"
}

///|
fn line_metrics(m : @library.LineMetrics) -> String {
  "\{em(m.position)} \{em(m.thickness)}"
}

///|
fn script_metrics(m : @library.ScriptMetrics?) -> String {
  match m {
    Some(m) =>
      "\{em(m.width)} \{em(m.height)} \{em(m.horizontal_offset)} \{em(m.vertical_offset)}"
    None => "-"
  }
}

///|
fn variations_str(v : @library.FontVariations) -> String {
  v.0.map(e => "\{esc(e.0.0)}=\{ff(e.1.get())}").join(",")
}

///|
fn dump_instance(out : StringBuilder, inst : @library.FontInstance) -> Unit {
  let m = inst.metrics()
  out.write_string(
    "typst metrics \{@library.rust_display_f64(m.units_per_em)} asc \{em(m.ascender)} cap \{em(m.cap_height)} x \{em(m.x_height)} desc \{em(m.descender)} strike \{line_metrics(m.strikethrough)} under \{line_metrics(m.underline)} over \{line_metrics(m.overline)} sub \{script_metrics(m.subscript)} sup \{script_metrics(m.superscript)}\n",
  )
  let c = inst.math()
  let values = [
    c.space_width,
    c.display_operator_min_height,
    c.axis_height,
    c.accent_base_height,
    c.flattened_accent_base_height,
    c.subscript_shift_down,
    c.subscript_top_max,
    c.subscript_baseline_drop_min,
    c.superscript_shift_up,
    c.superscript_shift_up_cramped,
    c.superscript_bottom_min,
    c.superscript_baseline_drop_max,
    c.sub_superscript_gap_min,
    c.superscript_bottom_max_with_subscript,
    c.space_after_script,
    c.upper_limit_gap_min,
    c.upper_limit_baseline_rise_min,
    c.lower_limit_gap_min,
    c.lower_limit_baseline_drop_min,
    c.stack_top_shift_up,
    c.stack_top_display_style_shift_up,
    c.stack_bottom_shift_down,
    c.stack_bottom_display_style_shift_down,
    c.stack_gap_min,
    c.stack_display_style_gap_min,
    c.stretch_stack_top_shift_up,
    c.stretch_stack_bottom_shift_down,
    c.stretch_stack_gap_above_min,
    c.stretch_stack_gap_below_min,
    c.fraction_numerator_shift_up,
    c.fraction_numerator_display_style_shift_up,
    c.fraction_denominator_shift_down,
    c.fraction_denominator_display_style_shift_down,
    c.fraction_numerator_gap_min,
    c.fraction_num_display_style_gap_min,
    c.fraction_rule_thickness,
    c.fraction_denominator_gap_min,
    c.fraction_denom_display_style_gap_min,
    c.skewed_fraction_vertical_gap,
    c.skewed_fraction_horizontal_gap,
    c.overbar_vertical_gap,
    c.overbar_rule_thickness,
    c.overbar_extra_ascender,
    c.underbar_vertical_gap,
    c.underbar_rule_thickness,
    c.underbar_extra_descender,
    c.radical_vertical_gap,
    c.radical_display_style_vertical_gap,
    c.radical_rule_thickness,
    c.radical_extra_ascender,
    c.radical_kern_before_degree,
    c.radical_kern_after_degree,
  ]
  out.write_string(
    "typst math \{c.script_percent_scale_down} \{c.script_script_percent_scale_down} \{@library.rust_display_f64(c.radical_degree_bottom_raise_percent)} \{values.map(em).join(" ")}\n",
  )
  let adv = StringBuilder::new()
  let ttf = inst.ttf().unwrap()
  let count = ttf.number_of_glyphs().to_int()
  let count = if count < 512 { count } else { 512 }
  for gid in 0..<count {
    let g = gid.to_uint16()
    let x = match inst.x_advance(g) {
      Some(v) => em(v)
      None => "-"
    }
    let y = match inst.y_advance(g) {
      Some(v) => em(v)
      None => "-"
    }
    adv.write_string(
      "\{x}:\{y}:\{font_rect(ttf.glyph_bounding_box(@otf.GlyphId(g)))};",
    )
  }
  out.write_string("typst advances fnv \{hex16(fnv(adv.to_string()))}\n")
}

///|
fn font_dump_typst(
  out : StringBuilder,
  data : Bytes,
  face_index : UInt,
) -> Unit {
  guard @library.Font::from_data(data, face_index) is Some(font) else {
    out.write_string("typst -\n")
    return
  }
  let info = font.info()
  let flags = []
  for
    flag in [
      (@library.font_flags_monospace, "monospace"),
      (@library.font_flags_serif, "serif"),
      (@library.font_flags_math, "math"),
      (@library.font_flags_variable, "variable"),
    ] {
    if info.flags.contains(flag.0) {
      flags.push(flag.1)
    }
  }
  let ps = match font.post_script_name() {
    Some(n) => "\"" + esc(n) + "\""
    None => "-"
  }
  out.write_string(
    "typst family \"\{esc(info.family)}\" variant \{font_variant(info.variant)} flags [\{flags.join(",")}] postscript \{ps}\n",
  )
  for axis in info.axes {
    out.write_string(
      "typst axis \{esc(axis.tag.0)} \{ff(axis.min.get())} \{ff(axis.max.get())} \{ff(axis.default.get())}\n",
    )
  }
  let cov = StringBuilder::new()
  let mut n = 0
  for c in info.coverage.iter() {
    cov.write_string("\{c};")
    n += 1
  }
  let probe = StringBuilder::new()
  let mut c : UInt = 0
  while c < 0x30000 {
    probe.write_char(if info.coverage.contains(c) { '1' } else { '0' })
    c += 7
  }
  out.write_string(
    "typst coverage \{n} fnv \{hex16(fnv(cov.to_string()))} probe \{hex16(fnv(probe.to_string()))}\n",
  )
  let size = @library.Abs::pt(11.0)
  let plain = @library.FontVariations([])
  let inst = font.instantiate(info.variant, size, plain)
  out.write_string(
    "typst instance default \{variations_str(inst.variations())}\n",
  )
  dump_instance(out, inst)
  if info.flags.contains(@library.font_flags_variable) {
    let variants = [
      (
        "bold",
        @library.FontVariant::new(
          Normal,
          @library.font_weight_bold,
          @library.font_stretch_normal,
        ),
      ),
      (
        "light-italic-condensed",
        @library.FontVariant::new(
          Italic,
          @library.font_weight_light,
          @library.FontStretch(750),
        ),
      ),
      (
        "black-oblique-expanded",
        @library.FontVariant::new(
          Oblique,
          @library.font_weight_black,
          @library.FontStretch(1250),
        ),
      ),
    ]
    for entry in variants {
      let (label, v) = entry
      for pt in [6.0, 11.0, 72.0] {
        let inst = font.instantiate(v, @library.Abs::pt(pt), plain)
        out.write_string(
          "typst instance \{label} \{@library.rust_display_f64(pt)} \{variations_str(inst.variations())}\n",
        )
        dump_instance(out, inst)
      }
    }
  }
}

///|
/// Dumps the font book's selection and fallback behaviour.
fn font_dump_book() -> String {
  let fonts = []
  for file in test_font_files() {
    for font in @library.Font::iter(file.1) {
      fonts.push(font)
    }
  }
  let book = @library.FontBook::from_fonts(fonts)
  let text = StringBuilder::new()
  for entry in book.families() {
    let (family, ids) = entry
    text.write_string(
      "family \"\{esc(family)}\" \{ids.map(i => i.to_string()).join(",")}\n",
    )
  }
  let styles : Array[@library.FontStyle] = [Normal, Italic, Oblique]
  let weights = [100, 300, 400, 450, 500, 700, 900]
  let stretches = [500, 750, 1000, 1250, 2000]
  let variants = []
  for style in styles {
    for w in weights {
      for st in stretches {
        variants.push(
          @library.FontVariant::new(
            style,
            @library.FontWeight::from_number(w),
            @library.FontStretch::from_ratio(
              @library.Ratio::new(st.to_double() / 1000.0),
            ),
          ),
        )
      }
    }
  }
  for entry in book.families() {
    let (family, _) = entry
    let lower = @unicode.to_lowercase(family)
    let picks = variants.map(v => fopt(book.select(lower, v)))
    text.write_string("select \"\{esc(family)}\" \{picks.join(",")}\n")
  }
  let samples = [
    "A", "  x", "\u{200B}é", "α", "Ж", "א", "ا", "क", "ก", "中", "한",
    "あ", "😀", "∑", "⨀", "𝔸", "♠", "\u{1F1E9}", "ﬁ", "€", "🏳️",
    "∫", "⟨", "ℏ",
  ]
  let likes : Array[Int?] = [
    None,
    Some(0),
    Some(13),
    Some(20),
    Some(44),
    Some(60),
    Some(83),
  ]
  let fallback_variants = [
    variants[14],
    variants[28],
    variants[50],
    variants[80],
  ]
  for sample in samples {
    let picks = []
    for like in likes {
      for v in fallback_variants {
        let like = match like {
          Some(i) => book.info(i)
          None => None
        }
        picks.push(fopt(book.select_fallback(like, v, sample)))
      }
    }
    text.write_string("fallback \"\{esc(sample)}\" \{picks.join(",")}\n")
  }
  text.to_string()
}
