// Generated stubs for native functions that are not ported yet.

///|
/// TODO: port `Content.func` (typst-library/src/foundations/content/mod.rs).
fn impl_content_func(self_ : Content) -> Element raise HintedError {
  ignore(self_)
  bail("`Content.func` is not yet ported")
}

///|
/// TODO: port `Content.has` (typst-library/src/foundations/content/mod.rs).
fn impl_content_has(self_ : Content, field_ : String) -> Bool raise HintedError {
  ignore(self_)
  ignore(field_)
  bail("`Content.has` is not yet ported")
}

///|
/// TODO: port `Content.at` (typst-library/src/foundations/content/mod.rs).
fn impl_content_at(
  self_ : Content,
  field_ : String,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(field_)
  ignore(default_)
  bail("`Content.at` is not yet ported")
}

///|
/// TODO: port `Content.fields` (typst-library/src/foundations/content/mod.rs).
fn impl_content_fields(self_ : Content) -> Dict raise HintedError {
  ignore(self_)
  bail("`Content.fields` is not yet ported")
}

///|
/// TODO: port `plugin` (typst-library/src/foundations/plugin.rs).
fn impl_plugin(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`plugin` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `plugin.transition` (typst-library/src/foundations/plugin.rs).
fn impl_plugin_transition(
  func_ : Value,
  arguments_ : Array[BytesValue],
) -> Value raise HintedError {
  ignore(func_)
  ignore(arguments_)
  bail("`plugin.transition` is not yet ported")
}

///|
/// TODO: port `target` (typst-library/src/foundations/target.rs).
fn impl_target(context : Context) -> Value raise HintedError {
  ignore(context)
  bail("`target` is not yet ported")
}

///|
/// TODO: port `layout` (typst-library/src/layout/layout.rs).
fn impl_layout(span : @syntax.Span, func_ : Func) -> Content raise HintedError {
  ignore(span)
  ignore(func_)
  bail("`layout` is not yet ported")
}

///|
/// TODO: port `measure` (typst-library/src/layout/measure.rs).
fn impl_measure(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  width_ : Smart[Length],
  height_ : Smart[Length],
  content_ : Content,
) -> Dict raise SourceError {
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(width_)
  ignore(height_)
  ignore(content_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`measure` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `cbor` (typst-library/src/loading/cbor.rs).
fn impl_cbor(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`cbor` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `cbor.encode` (typst-library/src/loading/cbor.rs).
fn impl_cbor_encode(
  value_ : @syntax.Spanned[Value],
) -> BytesValue raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`cbor.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_csv__delimiter_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `csv.delimiter` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `RowType::Array`.
fn impl_csv__row_type_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `csv.row_type` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `csv` (typst-library/src/loading/csv.rs).
fn impl_csv(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
  delimiter_ : Value,
  row_type_ : Value,
) -> Arr raise SourceError {
  ignore(engine)
  ignore(source_)
  ignore(delimiter_)
  ignore(row_type_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`csv` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `json` (typst-library/src/loading/json.rs).
fn impl_json(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`json` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `json.encode` (typst-library/src/loading/json.rs).
fn impl_json_encode(
  value_ : @syntax.Spanned[Value],
  pretty_ : Bool,
) -> String raise SourceError {
  ignore(value_)
  ignore(pretty_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`json.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Some(Encoding::Utf8)`.
fn impl_read__encoding_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `read.encoding` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `read` (typst-library/src/loading/read.rs).
fn impl_read(
  engine : Engine,
  path_ : @syntax.Spanned[PathOrStr],
  encoding_ : Value,
) -> Value raise SourceError {
  ignore(engine)
  ignore(path_)
  ignore(encoding_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`read` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `toml` (typst-library/src/loading/toml.rs).
fn impl_toml(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Dict raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`toml` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `toml.encode` (typst-library/src/loading/toml.rs).
fn impl_toml_encode(
  value_ : @syntax.Spanned[Dict],
  pretty_ : Bool,
) -> String raise SourceError {
  ignore(value_)
  ignore(pretty_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`toml.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `xml` (typst-library/src/loading/xml.rs).
fn impl_xml(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`xml` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `yaml` (typst-library/src/loading/yaml.rs).
fn impl_yaml(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`yaml` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `yaml.encode` (typst-library/src/loading/yaml.rs).
fn impl_yaml_encode(
  value_ : @syntax.Spanned[Value],
) -> String raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`yaml.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Em::new(0.5).into()`.
fn impl_outline_entry_indented__gap_default() -> Length raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `outline_entry_indented.gap` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.indented` (typst-library/src/model/outline.rs).
fn impl_outline_entry_indented(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  prefix_ : Content?,
  inner_ : Content,
  gap_ : Length,
) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(prefix_)
  ignore(inner_)
  ignore(gap_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.indented` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.prefix` (typst-library/src/model/outline.rs).
fn impl_outline_entry_prefix(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content? raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.prefix` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.inner` (typst-library/src/model/outline.rs).
fn impl_outline_entry_inner(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.inner` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.body` (typst-library/src/model/outline.rs).
fn impl_outline_entry_body(self_ : Value) -> Content raise HintedError {
  ignore(self_)
  bail("`OutlineEntry.body` is not yet ported")
}

///|
/// TODO: port `OutlineEntry.page` (typst-library/src/model/outline.rs).
fn impl_outline_entry_page(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.page` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.luma` (typst-library/src/visualize/color.rs).
fn impl_color_luma(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.luma` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.oklab` (typst-library/src/visualize/color.rs).
fn impl_color_oklab(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.oklab` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.oklch` (typst-library/src/visualize/color.rs).
fn impl_color_oklch(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.oklch` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.linear-rgb` (typst-library/src/visualize/color.rs).
fn impl_color_linear_rgb(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.linear-rgb` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.rgb` (typst-library/src/visualize/color.rs).
fn impl_color_rgb(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.rgb` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.cmyk` (typst-library/src/visualize/color.rs).
fn impl_color_cmyk(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.cmyk` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.hsl` (typst-library/src/visualize/color.rs).
fn impl_color_hsl(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.hsl` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.hsv` (typst-library/src/visualize/color.rs).
fn impl_color_hsv(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.hsv` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.components` (typst-library/src/visualize/color.rs).
fn impl_color_components(self_ : Value, alpha_ : Bool) -> Arr raise HintedError {
  ignore(self_)
  ignore(alpha_)
  bail("`Color.components` is not yet ported")
}

///|
/// TODO: port `Color.space` (typst-library/src/visualize/color.rs).
fn impl_color_space(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Color.space` is not yet ported")
}

///|
/// TODO: port `Color.to-hex` (typst-library/src/visualize/color.rs).
fn impl_color_to_hex(self_ : Value) -> String raise HintedError {
  ignore(self_)
  bail("`Color.to-hex` is not yet ported")
}

///|
/// TODO: port `Color.lighten` (typst-library/src/visualize/color.rs).
fn impl_color_lighten(
  self_ : Value,
  factor_ : Ratio,
) -> Value raise HintedError {
  ignore(self_)
  ignore(factor_)
  bail("`Color.lighten` is not yet ported")
}

///|
/// TODO: port `Color.darken` (typst-library/src/visualize/color.rs).
fn impl_color_darken(self_ : Value, factor_ : Ratio) -> Value raise HintedError {
  ignore(self_)
  ignore(factor_)
  bail("`Color.darken` is not yet ported")
}

///|
/// TODO: port `Color.saturate` (typst-library/src/visualize/color.rs).
fn impl_color_saturate(
  self_ : Value,
  span : @syntax.Span,
  factor_ : Ratio,
) -> Value raise SourceError {
  ignore(self_)
  ignore(span)
  ignore(factor_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.saturate` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.desaturate` (typst-library/src/visualize/color.rs).
fn impl_color_desaturate(
  self_ : Value,
  span : @syntax.Span,
  factor_ : Ratio,
) -> Value raise SourceError {
  ignore(self_)
  ignore(span)
  ignore(factor_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.desaturate` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_color_negate__space_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `color_negate.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.negate` (typst-library/src/visualize/color.rs).
fn impl_color_negate(self_ : Value, space_ : Value) -> Value raise HintedError {
  ignore(self_)
  ignore(space_)
  bail("`Color.negate` is not yet ported")
}

///|
/// TODO: port default `ProcessColorSpace::Oklch`.
fn impl_color_rotate__space_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `color_rotate.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.rotate` (typst-library/src/visualize/color.rs).
fn impl_color_rotate(
  self_ : Value,
  span : @syntax.Span,
  angle_ : Angle,
  space_ : Value,
) -> Value raise SourceError {
  ignore(self_)
  ignore(span)
  ignore(angle_)
  ignore(space_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.rotate` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_color_mix__space_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `color_mix.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.mix` (typst-library/src/visualize/color.rs).
fn impl_color_mix(
  colors_ : Array[Value],
  space_ : Value,
) -> Value raise HintedError {
  ignore(colors_)
  ignore(space_)
  bail("`Color.mix` is not yet ported")
}

///|
/// TODO: port `Color.transparentize` (typst-library/src/visualize/color.rs).
fn impl_color_transparentize(
  self_ : Value,
  scale_ : Ratio,
) -> Value raise HintedError {
  ignore(self_)
  ignore(scale_)
  bail("`Color.transparentize` is not yet ported")
}

///|
/// TODO: port `Color.opacify` (typst-library/src/visualize/color.rs).
fn impl_color_opacify(self_ : Value, scale_ : Ratio) -> Value raise HintedError {
  ignore(self_)
  ignore(scale_)
  bail("`Color.opacify` is not yet ported")
}

///|
/// TODO: port `SpotColorant.construct` (typst-library/src/visualize/color.rs).
fn impl_spot_colorant_construct(
  name_ : Value,
  fallback_ : Value,
) -> Value raise SourceError {
  ignore(name_)
  ignore(fallback_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`SpotColorant.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `SpotColorant.tint` (typst-library/src/visualize/color.rs).
fn impl_spot_colorant_tint(
  self_ : Value,
  value_ : @syntax.Spanned[Ratio],
) -> Value raise SourceError {
  ignore(self_)
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`SpotColorant.tint` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Smart::Auto)`.
fn impl_gradient_linear__space_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_linear.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_gradient_linear__relative_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_linear.relative` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Dir::LTR`.
fn impl_gradient_linear__dir_default() -> Dir raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_linear.dir` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.linear` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_linear(
  args : Args,
  span : @syntax.Span,
  stops_ : Array[@syntax.Spanned[Value]],
  space_ : @syntax.Spanned[Value],
  relative_ : Value,
) -> Value raise SourceError {
  ignore(args)
  ignore(span)
  ignore(stops_)
  ignore(space_)
  ignore(relative_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.linear` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Smart::Auto)`.
fn impl_gradient_radial__space_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_gradient_radial__relative_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.relative` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Axes::splat(Ratio::new(0.5))`.
fn impl_gradient_radial__center_default() -> Axes[Ratio] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.center` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Ratio::new(0.5))`.
fn impl_gradient_radial__radius_default() -> @syntax.Spanned[Ratio] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.radius` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Ratio::new(0.0))`.
fn impl_gradient_radial__focal_radius_default() -> @syntax.Spanned[Ratio] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.focal_radius` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.radial` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_radial(
  span : @syntax.Span,
  stops_ : Array[@syntax.Spanned[Value]],
  space_ : @syntax.Spanned[Value],
  relative_ : Value,
  center_ : Axes[Ratio],
  radius_ : @syntax.Spanned[Ratio],
  focal_center_ : Smart[Axes[Ratio]],
  focal_radius_ : @syntax.Spanned[Ratio],
) -> Value raise SourceError {
  ignore(span)
  ignore(stops_)
  ignore(space_)
  ignore(relative_)
  ignore(center_)
  ignore(radius_)
  ignore(focal_center_)
  ignore(focal_radius_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.radial` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Angle::zero()`.
fn impl_gradient_conic__angle_default() -> Angle raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_conic.angle` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Smart::Auto)`.
fn impl_gradient_conic__space_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_conic.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_gradient_conic__relative_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_conic.relative` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Axes::splat(Ratio::new(0.5))`.
fn impl_gradient_conic__center_default() -> Axes[Ratio] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_conic.center` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.conic` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_conic(
  span : @syntax.Span,
  stops_ : Array[@syntax.Spanned[Value]],
  angle_ : Angle,
  space_ : @syntax.Spanned[Value],
  relative_ : Value,
  center_ : Axes[Ratio],
) -> Value raise SourceError {
  ignore(span)
  ignore(stops_)
  ignore(angle_)
  ignore(space_)
  ignore(relative_)
  ignore(center_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.conic` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Ratio::zero())`.
fn impl_gradient_sharp__smoothness_default() -> @syntax.Spanned[Ratio] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_sharp.smoothness` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.sharp` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_sharp(
  self_ : Value,
  steps_ : @syntax.Spanned[USize],
  smoothness_ : @syntax.Spanned[Ratio],
) -> Value raise SourceError {
  ignore(self_)
  ignore(steps_)
  ignore(smoothness_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.sharp` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.repeat` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_repeat(
  self_ : Value,
  repetitions_ : @syntax.Spanned[USize],
  mirror_ : Bool,
) -> Value raise SourceError {
  ignore(self_)
  ignore(repetitions_)
  ignore(mirror_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.repeat` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.kind` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_kind(self_ : Value) -> Func raise HintedError {
  ignore(self_)
  bail("`Gradient.kind` is not yet ported")
}

///|
/// TODO: port `Gradient.stops` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_stops(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Gradient.stops` is not yet ported")
}

///|
/// TODO: port `Gradient.space` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_space(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Gradient.space` is not yet ported")
}

///|
/// TODO: port `Gradient.relative` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_relative(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Gradient.relative` is not yet ported")
}

///|
/// TODO: port `Gradient.angle` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_angle(self_ : Value) -> Angle? raise HintedError {
  ignore(self_)
  bail("`Gradient.angle` is not yet ported")
}

///|
/// TODO: port `Gradient.center` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_center(self_ : Value) -> Axes[Ratio]? raise HintedError {
  ignore(self_)
  bail("`Gradient.center` is not yet ported")
}

///|
/// TODO: port `Gradient.radius` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_radius(self_ : Value) -> Ratio? raise HintedError {
  ignore(self_)
  bail("`Gradient.radius` is not yet ported")
}

///|
/// TODO: port `Gradient.focal-center` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_focal_center(self_ : Value) -> Axes[Ratio]? raise HintedError {
  ignore(self_)
  bail("`Gradient.focal-center` is not yet ported")
}

///|
/// TODO: port `Gradient.focal-radius` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_focal_radius(self_ : Value) -> Ratio? raise HintedError {
  ignore(self_)
  bail("`Gradient.focal-radius` is not yet ported")
}

///|
/// TODO: port `Gradient.sample` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_sample(self_ : Value, t_ : Value) -> Value raise HintedError {
  ignore(self_)
  ignore(t_)
  bail("`Gradient.sample` is not yet ported")
}

///|
/// TODO: port `Gradient.samples` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_samples(
  self_ : Value,
  ts_ : Array[Value],
) -> Arr raise HintedError {
  ignore(self_)
  ignore(ts_)
  bail("`Gradient.samples` is not yet ported")
}

///|
/// TODO: port default `Em::one().into()`.
fn impl_polygon_elem_regular__size_default() -> Length raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `polygon_elem_regular.size` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `PolygonElem.regular` (typst-library/src/visualize/polygon.rs).
fn impl_polygon_elem_regular(
  span : @syntax.Span,
  fill_ : Value?,
  stroke_ : Value?,
  size_ : Length,
  vertices_ : U64,
) -> Content raise HintedError {
  ignore(span)
  ignore(fill_)
  ignore(stroke_)
  ignore(size_)
  ignore(vertices_)
  bail("`PolygonElem.regular` is not yet ported")
}

///|
/// TODO: port `Stroke.construct` (typst-library/src/visualize/stroke.rs).
fn impl_stroke_construct(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Stroke.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Smart::Auto)`.
fn impl_tiling_construct__size_default() -> @syntax.Spanned[Smart[Axes[Length]]] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.size` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Axes::splat(Length::zero()))`.
fn impl_tiling_construct__spacing_default() -> @syntax.Spanned[Axes[Length]] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.spacing` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::new(Axes::splat(Rel::zero()), Span::detached())`.
fn impl_tiling_construct__offset_default() -> @syntax.Spanned[Axes[Rel[Length]]] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.offset` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Angle::zero())`.
fn impl_tiling_construct__angle_default() -> @syntax.Spanned[Angle] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.angle` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_tiling_construct__relative_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.relative` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Tiling.construct` (typst-library/src/visualize/tiling.rs).
fn impl_tiling_construct(
  engine : Engine,
  span : @syntax.Span,
  size_ : @syntax.Spanned[Smart[Axes[Length]]],
  spacing_ : @syntax.Spanned[Axes[Length]],
  offset_ : @syntax.Spanned[Axes[Rel[Length]]],
  angle_ : @syntax.Spanned[Angle],
  relative_ : Value,
  body_ : Content,
) -> Value raise SourceError {
  ignore(engine)
  ignore(span)
  ignore(size_)
  ignore(spacing_)
  ignore(offset_)
  ignore(angle_)
  ignore(relative_)
  ignore(body_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Tiling.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port constant `Color::BLACK`.
fn impl_color_const_black() -> Value {
  None
}

///|
/// TODO: port constant `Color::GRAY`.
fn impl_color_const_gray() -> Value {
  None
}

///|
/// TODO: port constant `Color::WHITE`.
fn impl_color_const_white() -> Value {
  None
}

///|
/// TODO: port constant `Color::SILVER`.
fn impl_color_const_silver() -> Value {
  None
}

///|
/// TODO: port constant `Color::NAVY`.
fn impl_color_const_navy() -> Value {
  None
}

///|
/// TODO: port constant `Color::BLUE`.
fn impl_color_const_blue() -> Value {
  None
}

///|
/// TODO: port constant `Color::AQUA`.
fn impl_color_const_aqua() -> Value {
  None
}

///|
/// TODO: port constant `Color::TEAL`.
fn impl_color_const_teal() -> Value {
  None
}

///|
/// TODO: port constant `Color::EASTERN`.
fn impl_color_const_eastern() -> Value {
  None
}

///|
/// TODO: port constant `Color::PURPLE`.
fn impl_color_const_purple() -> Value {
  None
}

///|
/// TODO: port constant `Color::FUCHSIA`.
fn impl_color_const_fuchsia() -> Value {
  None
}

///|
/// TODO: port constant `Color::MAROON`.
fn impl_color_const_maroon() -> Value {
  None
}

///|
/// TODO: port constant `Color::RED`.
fn impl_color_const_red() -> Value {
  None
}

///|
/// TODO: port constant `Color::ORANGE`.
fn impl_color_const_orange() -> Value {
  None
}

///|
/// TODO: port constant `Color::YELLOW`.
fn impl_color_const_yellow() -> Value {
  None
}

///|
/// TODO: port constant `Color::OLIVE`.
fn impl_color_const_olive() -> Value {
  None
}

///|
/// TODO: port constant `Color::GREEN`.
fn impl_color_const_green() -> Value {
  None
}

///|
/// TODO: port constant `Color::LIME`.
fn impl_color_const_lime() -> Value {
  None
}

///|
/// TODO: port constant `Color::MAP`.
fn impl_color_const_map() -> Value {
  None
}

///|
/// TODO: port `#[defs]` of `HtmlFormat` (typst-html/src/format.rs).
fn defs_html_format(scope : Scope) -> Unit {
  ignore(scope)
}
