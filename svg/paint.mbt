// Port of `typst-svg/src/paint.rs`: fills, strokes, gradients, tilings and
// color formatting.

///|
/// The number of segments in a conic gradient. This is a heuristic value
/// that seems to work well. Smaller values could be interesting for
/// optimization.
let num_conic_segments : Int = 360

///|
/// Render a frame to a string.
fn SVGRenderer::render_tiling_frame(
  self : SVGRenderer,
  state : State,
  frame : @library.Frame,
) -> String {
  let xml = @xmlwriter.XmlWriter::new(@xmlwriter.Options::default())
  let svg = SvgElem::new(xml, "g")
  self.render_frame(svg, state, frame)
  svg.end()
  xml.end_document()
}

///|
/// Write a fill attribute.
fn SVGRenderer::write_fill(
  self : SVGRenderer,
  svg : SvgElem,
  fill : @library.Paint,
  fill_rule : @library.FillRule,
  aspect_ratio : @library.Ratio,
  ts : @library.Transform,
) -> Unit {
  match fill {
    Solid(color) => svg.attr("fill", color) |> ignore
    Gradient(gradient) => {
      let id = self.push_gradient(gradient, aspect_ratio, ts)
      svg.attr("fill", SvgUrl(id)) |> ignore
    }
    Tiling(tiling) => {
      let id = self.push_tiling(tiling, ts)
      svg.attr("fill", SvgUrl(id)) |> ignore
    }
  }
  match fill_rule {
    NonZero => svg.attr("fill-rule", "nonzero") |> ignore
    EvenOdd => svg.attr("fill-rule", "evenodd") |> ignore
  }
}

///|
/// Pushes a gradient to the list of gradients to write SVG file.
///
/// If the gradient is already present, returns the id of the existing
/// gradient. Otherwise, inserts the gradient and returns the id of the
/// inserted gradient. If the transform of the gradient is the identify
/// matrix, the returned ID will be the ID of the "source" gradient, this is a
/// file size optimization.
fn SVGRenderer::push_gradient(
  self : SVGRenderer,
  gradient : @library.Gradient,
  aspect_ratio : @library.Ratio,
  ts : @library.Transform,
) -> DedupId {
  let key = {
    let h = @library.SipHasher128::new()
    hash_gradient(h, gradient)
    hash_ratio(h, aspect_ratio)
    h.finish128()
  }
  let gradient_id = self.gradients.insert_with(key, () => {
    (gradient, aspect_ratio)
  })
  if ts.is_identity() {
    return gradient_id
  }
  let key = {
    let h = @library.SipHasher128::new()
    h.write_u32(gradient_id.kind.to_int().reinterpret_as_uint())
    h.write_u128(gradient_id.hash)
    hash_transform(h, ts)
    h.finish128()
  }
  self.gradient_refs.insert_with(key, () => {
    id: gradient_id,
    kind: GradientKind::from_gradient(gradient),
    transform: ts,
  })
}

///|
fn SVGRenderer::push_tiling(
  self : SVGRenderer,
  tiling : @library.Tiling,
  ts : @library.Transform,
) -> DedupId {
  let tiling_size = tiling.size.add_size(tiling.spacing)
  let tiling_offset = tiling.offset
  let tiling_angle = tiling.angle
  // Unfortunately due to a limitation of `xmlwriter`, we need to render the
  // frame twice: once to allocate all of the resources that it needs and
  // once to actually render it.
  let rendered = self.render_tiling_frame(State::new(tiling_size), tiling.frame)

  // Use the rendered SVG and the tiling's properties as a key, since the
  // `Tiling` itself includes `Location`s which aren't stable.
  let key = {
    let h = @library.SipHasher128::new()
    hash_size(h, tiling_size)
    hash_size(h, tiling_offset)
    hash_angle(h, tiling_angle)
    h.write_str(rendered)
    h.finish128()
  }
  let tiling_id = self.tilings.insert_with(key, () => tiling)
  if ts.is_identity() {
    return tiling_id
  }

  // The tiling reference is written as a SVG `pattern` with a `href`
  // attribute, which will overwrite the `patternTransform` of the referenced
  // pattern. Thus any pre-existing `patternTransform` of the referenced
  // pattern needs to be concatenated.
  let transform = ts.pre_concat(tiling_transform(tiling))
  let tiling_ref : TilingRef = { id: tiling_id, transform, }
  let key = {
    let h = @library.SipHasher128::new()
    h.write_u32(tiling_id.kind.to_int().reinterpret_as_uint())
    h.write_u128(tiling_id.hash)
    hash_transform(h, transform)
    h.finish128()
  }
  self.tiling_refs.insert_with(key, () => tiling_ref)
}

///|
/// The transform of a tiling (upstream `Tiling::transform`).
fn tiling_transform(tiling : @library.Tiling) -> @library.Transform {
  @library.Transform::translate(tiling.offset.x, tiling.offset.y).pre_concat(
    @library.Transform::rotate(tiling.angle),
  )
}

///|
/// Corrects this angle for the aspect ratio of a gradient (upstream
/// `Gradient::correct_aspect_ratio`).
fn correct_aspect_ratio(
  angle : @library.Angle,
  aspect_ratio : @library.Ratio,
) -> @library.Angle {
  @library.Angle::atan2(angle.sin() / aspect_ratio.get().abs(), angle.cos()).normalized()
}

///|
/// Write the raw gradients (without transform) to the SVG file.
fn SVGRenderer::write_gradients(self : SVGRenderer, svg : SvgElem) -> Unit {
  if self.gradients.is_empty() {
    return
  }
  let defs = svg.elem("defs")
  for entry in self.gradients.iter() {
    let (id, (gradient, aspect_ratio)) = entry
    let svg = match gradient {
      Linear(linear) => {
        let gradient = defs.elem("linearGradient")
        gradient.attr("id", id) |> ignore
        gradient.attr("spreadMethod", "pad") |> ignore
        gradient.attr("gradientUnits", "userSpaceOnUse") |> ignore
        let angle = correct_aspect_ratio(linear.angle, aspect_ratio)
        let (sin, cos) = (angle.sin(), angle.cos())

        // Scale to edges of unit square.
        let factor = sin.abs() + cos.abs()
        let (x1, y1) = match angle.quadrant() {
          First => (0.0, 0.0)
          Second => (1.0, 0.0)
          Third => (1.0, 1.0)
          Fourth => (0.0, 1.0)
        }
        let x2 = x1 + cos * factor
        let y2 = y1 + sin * factor
        gradient.attr("x1", x1) |> ignore
        gradient.attr("y1", y1) |> ignore
        gradient.attr("x2", x2) |> ignore
        gradient.attr("y2", y2) |> ignore
        gradient
      }
      Radial(radial) => {
        let gradient = defs.elem("radialGradient")
        gradient.attr("id", id) |> ignore
        gradient.attr("spreadMethod", "pad") |> ignore
        gradient.attr("gradientUnits", "userSpaceOnUse") |> ignore
        gradient.attr("cx", radial.center.x.get()) |> ignore
        gradient.attr("cy", radial.center.y.get()) |> ignore
        gradient.attr("r", radial.radius.get()) |> ignore
        gradient.attr("fx", radial.focal_center.x.get()) |> ignore
        gradient.attr("fy", radial.focal_center.y.get()) |> ignore
        gradient.attr("fr", radial.focal_radius.get()) |> ignore
        gradient
      }
      Conic(conic) => {
        let pattern = defs.elem("pattern")
        pattern.attr("id", id) |> ignore
        pattern.attr("viewBox", "0 0 1 1") |> ignore
        pattern.attr("preserveAspectRatio", "none") |> ignore
        pattern.attr("patternUnits", "userSpaceOnUse") |> ignore
        pattern.attr("width", "2") |> ignore
        pattern.attr("height", "2") |> ignore
        // TODO: Refactor this.
        pattern.attr("x", "-0.5") |> ignore
        pattern.attr("y", "-0.5") |> ignore
        let center = conic.center

        // Correct the angles with the inverse aspect-ratio, to compensate for
        // the transformation that is applied later on to the gradient fill.
        let inverse_ratio = aspect_ratio.recip()

        // We build an arg segment for each segment of a circle.
        let dtheta = @library.Angle::rad(
          2.0 * @math.PI / num_conic_segments.to_double(),
        )
        let angle_add = (a : @library.Angle, b : @library.Angle) => {
          @library.Angle::raw(a.to_raw() + b.to_raw())
        }
        let angle_neg = (a : @library.Angle) => @library.Angle::raw(-a.to_raw())
        for i in 0..<num_conic_segments {
          // Negate the angle for clockwise gradient rotation.
          let theta1 = angle_neg(
            correct_aspect_ratio(
              angle_add(conic.angle, dtheta.times(i.to_double())),
              inverse_ratio,
            ),
          )
          let theta2 = angle_neg(
            correct_aspect_ratio(
              angle_add(conic.angle, dtheta.times((i + 1).to_double())),
              inverse_ratio,
            ),
          )

          // Create the path for the segment.
          let builder = SvgPathBuilder::empty()
          builder.move_to(correct_tiling_pos(center.x, center.y))
          builder.line_to(
            correct_tiling_pos(
              @library.Ratio::new(-2.0 * theta1.cos()) + center.x,
              @library.Ratio::new(2.0 * theta1.sin()) + center.y,
            ),
          )
          builder.arc(
            @library.Axes::splat(@library.Abs::pt(1.0)),
            @library.Angle::zero(),
            0,
            1,
            correct_tiling_pos(
              @library.Ratio::new(-2.0 * theta2.cos()) + center.x,
              @library.Ratio::new(2.0 * theta2.sin()) + center.y,
            ),
          )
          builder.close()
          let t1 = i.to_double() / num_conic_segments.to_double()
          let t2 = (i + 1).to_double() / num_conic_segments.to_double()
          let subgradient : SVGSubGradient = {
            center: conic.center,
            t0: theta1,
            t1: theta2,
            c0: gradient.sample(Ratio(@library.Ratio::new(t1))),
            c1: gradient.sample(Ratio(@library.Ratio::new(t2))),
          }
          let key = {
            let h = @library.SipHasher128::new()
            hash_ratio(h, subgradient.center.x)
            hash_ratio(h, subgradient.center.y)
            hash_angle(h, subgradient.t0)
            hash_angle(h, subgradient.t1)
            hash_color(h, subgradient.c0)
            hash_color(h, subgradient.c1)
            h.finish128()
          }
          let id = self.conic_subgradients.insert_with(key, () => subgradient)

          // Add the path to the pattern.
          pattern
          .elem("path")
          .attr("d", builder.finsish())
          .attr("fill", SvgUrl(id))
          .attr("stroke", "none")
          .attr("shape-rendering", "optimizeSpeed")
          .end()
        }

        // We skip the default stop generation code.
        pattern.end()
        continue
      }
    }

    // Unwraps of to_space with this and the stops are safe since the stops
    // have been checked before to be compatible with the gradient.
    let gradient_space = gradient.space()
    let stops = gradient.stops_ref()
    for i in 0..<(stops.length() - 1) {
      let (start_c, start_t) = stops[i]
      let (end_c, end_t) = stops[i + 1]
      svg
      .elem("stop")
      .attr("offset", start_t.repr())
      .attr("stop-color", color_to_hex(to_space(start_c, gradient_space)))
      .end()

      // Generate intermediate stops between the two stops. This is a
      // workaround for a bug in many readers: They tend to just ignore the
      // color space of the gradient.
      if end_t > start_t && gradient.anti_alias() {
        generate_intermediate_stops_for_rgb_interpolation(
          gradient,
          (start_c, start_t),
          (end_c, end_t),
          (c, t) => {
            let c = to_space(c, gradient.space())
            svg
            .elem("stop")
            .attr("offset", t.repr())
            .attr("stop-color", color_to_hex(c))
            .end()
          },
        )
      }
    }
    if stops.last() is Some((last_c, last_t)) {
      svg
      .elem("stop")
      .attr("offset", last_t.repr())
      .attr("stop-color", color_to_hex(to_space(last_c, gradient.space())))
      .end()
    }
    svg.end()
  }
  defs.end()
}

///|
/// `Color::to_space(..).unwrap()`.
fn to_space(
  color : @library.Color,
  space : @library.ColorSpace,
) -> @library.Color {
  color.to_space(space) catch {
    _ => abort("gradient stops are compatible with the gradient space")
  }
}

///|
/// Upstream `Color::to_hex`.
fn color_to_hex(color : @library.Color) -> String {
  match color {
    Process(c) => c.to_hex()
    Spot(c) => c.fallback().to_hex()
  }
}

///|
/// Generates additional stops to replicate a gradient in rgb color space
/// interpolation by bisecting (upstream
/// `Gradient::generate_intermediate_stops_for_rgb_interpolation`).
fn generate_intermediate_stops_for_rgb_interpolation(
  gradient : @library.Gradient,
  first : (@library.Color, @library.Ratio),
  second : (@library.Color, @library.Ratio),
  yield_ : (@library.Color, @library.Ratio) -> Unit,
) -> Unit {
  let threshold : Float = 0.001
  let max_subdivisions : UInt64 = 64
  let t0 = first.1.get()
  let dt = second.1.get() - t0
  let mut prev_color = first.0
  let mut next_stop = second.1
  let mut next_color = second.0
  let mut n : UInt64 = 1 // number of subdivisions
  let mut i : UInt64 = 1 // next stop at this subdivision
  while true {
    let mut intermediate_stop = None
    // linear interpolation error at midpoint
    let euclidean_error = {
      let mid = @library.Ratio::new(
        t0 + dt * (i.to_double() - 0.5) / n.to_double(),
      )
      let exact = gradient.sample(Ratio(mid))
      let approx = @library.Color::mix_iter(
        [
          @library.WeightedColor::new(prev_color, 0.5),
          @library.WeightedColor::new(next_color, 0.5),
        ],
        Custom(Process(Srgb)),
      ) catch {
        _ => abort("mixing two colors in sRGB cannot fail")
      }
      let exact_color = premultiply(exact.to_rgb())
      let approx_color = premultiply(approx.to_rgb())
      let d0 = exact_color.0 - approx_color.0
      let d1 = exact_color.1 - approx_color.1
      let d2 = exact_color.2 - approx_color.2
      (d0 * d0 + d1 * d1 + d2 * d2).sqrt()
    }
    if n < max_subdivisions && euclidean_error > threshold {
      // deviation to large -> subdivide again
      n = n * 2
      i = 2 * i - 1
    } else if i >= n {
      // second stop reached -> done
      break
    } else {
      // intermediate stop found -> yield
      intermediate_stop = Some((next_color, next_stop))
      prev_color = next_color
      // next subdivision (largest possible)
      let shift = i.ctz()
      n = n >> shift
      i = i >> shift
      i = i + 1
    }
    next_stop = @library.Ratio::new(t0 + dt * i.to_double() / n.to_double())
    next_color = gradient.sample(Ratio(next_stop))
    if intermediate_stop is Some((c, t)) {
      yield_(c, t)
    }
  }
}

///|
/// The premultiplied color components of an RGB color (palette
/// `Alpha::premultiply`).
fn premultiply(c : @library.Rgb) -> (Float, Float, Float) {
  (c.red * c.alpha, c.green * c.alpha, c.blue * c.alpha)
}

///|
/// Write the sub-gradients that are used for conic gradients.
fn SVGRenderer::write_subgradients(self : SVGRenderer, svg : SvgElem) -> Unit {
  if self.conic_subgradients.is_empty() {
    return
  }
  let defs = svg.elem("defs")
  for entry in self.conic_subgradients.iter() {
    let (id, gradient) = entry
    let x1 = 2.0 - gradient.t0.cos() + gradient.center.x.get()
    let y1 = gradient.t0.sin() + gradient.center.y.get()
    let x2 = 2.0 - gradient.t1.cos() + gradient.center.x.get()
    let y2 = gradient.t1.sin() + gradient.center.y.get()
    let elem = defs
      .elem("linearGradient")
      .attr("id", id)
      .attr("gradientUnits", "objectBoundingBox")
      .attr("x1", x1)
      .attr("y1", y1)
      .attr("x2", x2)
      .attr("y2", y2)
    elem
    .elem("stop")
    .attr("offset", "0%")
    .attr("stop-color", color_to_hex(gradient.c0))
    .end()
    elem
    .elem("stop")
    .attr("offset", "100%")
    .attr("stop-color", color_to_hex(gradient.c1))
    .end()
    elem.end()
  }
  defs.end()
}

///|
fn SVGRenderer::write_gradient_refs(self : SVGRenderer, svg : SvgElem) -> Unit {
  if self.gradient_refs.is_empty() {
    return
  }
  let defs = svg.elem("defs")
  for entry in self.gradient_refs.iter() {
    let (id, gradient_ref) = entry
    let (elem_name, transform_name) = match gradient_ref.kind {
      Linear => ("linearGradient", "gradientTransform")
      Radial => ("radialGradient", "gradientTransform")
      Conic => ("pattern", "patternTransform")
    }
    defs
    .elem(elem_name)
    .attr(transform_name, SvgTransform(gradient_ref.transform))
    .attr("id", id)
    // Writing the href attribute to the "reference" gradient.
    .attr("href", SvgIdRef(gradient_ref.id))
    // Also writing the xlink:href attribute for compatibility.
    .attr("xlink:href", SvgIdRef(gradient_ref.id))
    .end()
  }
  defs.end()
}

///|
/// Write the raw tilings (without transform) to the SVG file.
fn SVGRenderer::write_tilings(self : SVGRenderer, svg : SvgElem) -> Unit {
  if self.tilings.is_empty() {
    return
  }
  let defs = svg.elem("defs")
  for entry in self.tilings.iter() {
    let (id, tiling) = entry
    let size = tiling.size.add_size(tiling.spacing)
    let pattern = defs
      .elem("pattern")
      .attr("id", id)
      .attr("width", size.x.to_pt())
      .attr("height", size.y.to_pt())
      .attr("patternUnits", "userSpaceOnUse")
      .attr("patternTransform", SvgTransform(tiling_transform(tiling)))
      .attr_with("viewBox", attr => {
        attr.push_nums([0.0, 0.0, size.x.to_pt(), size.y.to_pt()])
      })
    // Render the frame.
    let state = State::new(size)
    self.render_frame(pattern, state, tiling.frame)
    pattern.end()
  }
  defs.end()
}

///|
/// Writes the references to the deduplicated tilings for each usage site.
fn SVGRenderer::write_tiling_refs(self : SVGRenderer, svg : SvgElem) -> Unit {
  if self.tiling_refs.is_empty() {
    return
  }
  let defs = svg.elem("defs")
  for entry in self.tiling_refs.iter() {
    let (id, tiling_ref) = entry
    defs
    .elem("pattern")
    .attr("patternTransform", SvgTransform(tiling_ref.transform))
    .attr("id", id)
    // Writing the href attribute to the "reference" pattern.
    .attr("href", SvgIdRef(tiling_ref.id))
    // Also writing the xlink:href attribute for compatibility.
    .attr("xlink:href", SvgIdRef(tiling_ref.id))
    .end()
  }
  defs.end()
}

///|
/// A reference to a deduplicated tiling, with a transform matrix.
///
/// Allows tilings to be reused across multiple invocations, simply by
/// changing the transform matrix.
priv struct TilingRef {
  /// The ID of the deduplicated gradient
  id : DedupId
  /// The transform matrix to apply to the tiling.
  transform : @library.Transform
}

///|
/// A reference to a deduplicated gradient, with a transform matrix.
///
/// Allows gradients to be reused across multiple invocations, simply by
/// changing the transform matrix.
priv struct GradientRef {
  /// The ID of the deduplicated gradient
  id : DedupId
  /// The gradient kind (used to determine the SVG element to use) but
  /// without needing to clone the entire gradient.
  kind : GradientKind
  /// The transform matrix to apply to the gradient.
  transform : @library.Transform
}

///|
/// A subgradient for conic gradients.
priv struct SVGSubGradient {
  /// The center point of the gradient.
  center : @library.Axes[@library.Ratio]
  /// The start point of the subgradient.
  t0 : @library.Angle
  /// The end point of the subgradient.
  t1 : @library.Angle
  /// The color at the start point of the subgradient.
  c0 : @library.Color
  /// The color at the end point of the subgradient.
  c1 : @library.Color
}

///|
/// The kind of linear gradient.
priv enum GradientKind {
  /// A linear gradient.
  Linear
  /// A radial gradient.
  Radial
  /// A conic gradient.
  Conic
}

///|
fn GradientKind::from_gradient(value : @library.Gradient) -> GradientKind {
  match value {
    Linear(_) => Linear
    Radial(_) => Radial
    Conic(_) => Conic
  }
}

///|
pub impl SvgDisplay for @library.Color with fn fmt(self, f) {
  match self.to_process() {
    Rgb(_) | Luma(_) | Cmyk(_) | Hsv(_) as c => f.push_str(c.to_hex())
    LinearRgb(rgb) => {
      f.push_str("color(srgb-linear ")
      f.push_nums([
        round_f32(rgb.red, 5),
        round_f32(rgb.green, 5),
        round_f32(rgb.blue, 5),
      ])
      if rgb.alpha != 1.0 {
        f.push_str(" / ")
        f.push_num(round_f32(rgb.alpha, 5))
      }
      f.push_str(")")
    }
    Oklab(oklab) => {
      f.push_str("oklab(")
      f.push_num(round_f32((100.0 : Float) * oklab.l, 3))
      f.push_str("% ")
      f.push_nums([round_f32(oklab.a, 5), round_f32(oklab.b, 5)])
      if oklab.alpha != 1.0 {
        f.push_str(" / ")
        f.push_num(round_f32(oklab.alpha, 5))
      }
      f.push_str(")")
    }
    Oklch(oklch) => {
      f.push_str("oklch(")
      f.push_num(round_f32((100.0 : Float) * oklch.l, 3))
      f.push_str("% ")
      f.push_num(round_f32(oklch.chroma, 5))
      f.push_str(" ")
      f.push_num(round_f32(into_degrees(oklch.hue), 5))
      if oklch.alpha != 1.0 {
        f.push_str(" / ")
        f.push_num(round_f32(oklch.alpha, 5))
      }
      f.push_str(")")
    }
    Hsl(hsl) => {
      if hsl.alpha != 1.0 {
        f.push_str("hsla(")
      } else {
        f.push_str("hsl(")
      }
      f.push_num(round_f32(into_degrees(hsl.hue), 3))
      f.push_str("deg ")
      f.push_num(round_f32((100.0 : Float) * hsl.saturation, 3))
      f.push_str("% ")
      f.push_num(round_f32((100.0 : Float) * hsl.lightness, 3))
      if hsl.alpha != 1.0 {
        f.push_str(" / ")
        f.push_num(round_f32(hsl.alpha, 5))
      }
      f.push_str(")")
    }
  }
}

///|
/// Palette's `RgbHue::into_degrees`: the hue normalized to `(-180, 180]`.
fn into_degrees(x : Float) -> Float {
  let ceil = ((x + 180.0) / 360.0 - 1.0).to_double().ceil()
  x - Float::from_double(ceil) * 360.0
}

///|
/// Upstream `round::<DIGITS>`.
fn round_f32(num : Float, digits : Int) -> Double {
  let factor = @library.exp10(digits)
  @library.rust_round(num.to_double() * factor) / factor
}

///|
/// Maps a coordinate in a unit size square to a coordinate in the tiling.
fn correct_tiling_pos(x : @library.Ratio, y : @library.Ratio) -> @library.Point {
  (
    { x: @library.Abs::pt(x.get() + 0.5), y: @library.Abs::pt(y.get() + 0.5), } :
    @library.Point).times(0.5)
}
