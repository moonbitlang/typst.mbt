// Port of `usvg` 0.47.0 `src/parser/filter.rs`: a collection of SVG
// filters.

///|
impl FromValue for ColorInterpolation with fn parse(_, _, value) {
  match value {
    "sRGB" => Some(SRGB)
    "linearRGB" => Some(LinearRGB)
    _ => None
  }
}

///|
fn filter_convert(
  node : SvgNode,
  state : State,
  object_bbox : NonZeroRect?,
  cache : Cache,
) -> Result[Array[Filter], Unit] {
  let value : String = match node.attribute(AId::Filter) {
    Some(v) => v
    None => return Ok([])
  }
  let mut has_invalid_urls = false
  let filters : Array[Filter] = []
  let create_base_filter_func = (kind : FilterKind) => {
    // Filter functions, unlike `filter` elements, do not have a filter region.
    // We're currently do not support an unlimited region, so we simply use a fairly large one.
    // This if far from ideal, but good for now.
    // TODO: Should be fixed eventually.
    let mut rect = match kind {
      DropShadow(_) | GaussianBlur(_) =>
        NonZeroRect::from_xywh(-0.5, -0.5, 2.0, 2.0).unwrap()
      _ => NonZeroRect::from_xywh(-0.1, -0.1, 1.2, 1.2).unwrap()
    }
    let object_bbox = match object_bbox {
      Some(v) => v
      None =>
        // Upstream warns: Filter '{}' has an invalid region. Skipped.
        return
    }
    rect = rect.bbox_transform(object_bbox)
    filters.push({
      uid: gen_uid(),
      id: cache.gen_filter_id(),
      rect,
      primitives: [
        {
          rect,
          // Unlike `filter` elements, filter functions use sRGB colors by default.
          color_interpolation: SRGB,
          result: "result",
          kind,
        },
      ],
    })
  }
  let parser = @svgtypes.FilterValueListParser::from(value)
  while parser.next() is Some(func) {
    let func = match func {
      Ok(v) => v
      Err(_) =>
        // Skip the whole attribute list on error.
        // Upstream warns: Failed to parse a filter value cause {}. Skipping.
        return Ok([])
    }
    match func {
      Blur(std_dev) =>
        create_base_filter_func(convert_blur_function(node, std_dev, state))
      DropShadow(color~, dx~, dy~, std_dev~) =>
        create_base_filter_func(
          convert_drop_shadow_function(node, color, dx, dy, std_dev, state),
        )
      Brightness(amount) =>
        create_base_filter_func(convert_brightness_function(amount))
      Contrast(amount) =>
        create_base_filter_func(convert_contrast_function(amount))
      Grayscale(amount) =>
        create_base_filter_func(convert_grayscale_function(amount))
      HueRotate(angle) =>
        create_base_filter_func(convert_hue_rotate_function(angle))
      Invert(amount) => create_base_filter_func(convert_invert_function(amount))
      Opacity(amount) =>
        create_base_filter_func(convert_opacity_function(amount))
      Sepia(amount) => create_base_filter_func(convert_sepia_function(amount))
      Saturate(amount) =>
        create_base_filter_func(convert_saturate_function(amount))
      Url(url) =>
        if node.document().element_by_id(url) is Some(link) {
          match convert_filter_url(link, state, object_bbox, cache) {
            Ok(res) => if res is Some(f) { filters.push(f) }
            Err(_) => has_invalid_urls = true
          }
        } else {
          has_invalid_urls = true
        }
    }
  }

  // If a `filter` attribute had urls pointing to a missing elements
  // and there are no valid filters at all - this is an error.
  //
  // Note that an invalid url is not an error in general.
  if filters.is_empty() && has_invalid_urls {
    return Err(())
  }
  Ok(filters)
}

///|
fn convert_filter_url(
  node : SvgNode,
  state : State,
  object_bbox : NonZeroRect?,
  cache : Cache,
) -> Result[Filter?, Unit] {
  let units = convert_units(node, AId::FilterUnits, ObjectBoundingBox)
  let primitive_units = convert_units(node, AId::PrimitiveUnits, UserSpaceOnUse)

  // Check if this element was already converted.
  //
  // Only `userSpaceOnUse` clipPaths can be shared,
  // because `objectBoundingBox` one will be converted into user one
  // and will become node-specific.
  let cacheable = units == UserSpaceOnUse && primitive_units == UserSpaceOnUse
  if cacheable {
    if cache.filters.get(node.element_id()) is Some(filter) {
      return Ok(Some(filter))
    }
  }
  let rect = NonZeroRect::from_xywh(
    resolve_number(
      node,
      AId::X,
      units,
      state,
      @svgtypes.Length::new(-10.0, @svgtypes.LengthUnit::Percent),
    ),
    resolve_number(
      node,
      AId::Y,
      units,
      state,
      @svgtypes.Length::new(-10.0, @svgtypes.LengthUnit::Percent),
    ),
    resolve_number(
      node,
      AId::Width,
      units,
      state,
      @svgtypes.Length::new(120.0, @svgtypes.LengthUnit::Percent),
    ),
    resolve_number(
      node,
      AId::Height,
      units,
      state,
      @svgtypes.Length::new(120.0, @svgtypes.LengthUnit::Percent),
    ),
  )
  // Upstream warns: Filter '{}' has an invalid region. Skipped.
  guard rect is Some(rect) else { return Err(()) }
  let mut rect = rect
  if units == ObjectBoundingBox {
    if object_bbox is Some(object_bbox) {
      rect = rect.bbox_transform(object_bbox)
    } else {
      // Upstream warns: Filters on zero-sized shapes are not allowed.
      return Err(())
    }
  }
  let node_with_primitives = match find_filter_with_primitives(node) {
    Some(v) => v
    None => return Err(())
  }
  let primitives = collect_filter_children(
    node_with_primitives, primitive_units, state, object_bbox, rect, cache,
  )
  if primitives.is_empty() {
    return Err(())
  }
  guard NonEmptyString::new(node.element_id()) is Some(id) else {
    return Err(())
  }
  let mut id = id
  // Generate ID only when we're parsing `objectBoundingBox` filter for the second time.
  if !cacheable && cache.filters.contains(id.get()) {
    id = cache.gen_filter_id()
  }
  let id_copy = id.get()
  let filter : Filter = { uid: gen_uid(), id, rect, primitives, }
  cache.filters[id_copy] = filter
  Ok(Some(filter))
}

///|
fn find_filter_with_primitives(node : SvgNode) -> SvgNode? {
  for link in node.href_iter() {
    if link.tag_name() != Some(EId::Filter) {
      // Upstream warns: Filter '{}' cannot reference '{}' via 'xlink:href'.
      return None
    }
    if link.has_children() {
      return Some(link)
    }
  }
  None
}

///|
priv struct FilterResults {
  names : Set[String]
  mut idx : Int
}

///|
fn collect_filter_children(
  filter : SvgNode,
  units : Units,
  state : State,
  object_bbox : NonZeroRect?,
  filter_region : NonZeroRect,
  cache : Cache,
) -> Array[Primitive] {
  let primitives : Array[Primitive] = []
  let results : FilterResults = { names: Set([]), idx: 1, }
  let scale = if units == ObjectBoundingBox {
    if object_bbox is Some(object_bbox) {
      object_bbox.size()
    } else {
      // No need to warn. Already checked.
      return []
    }
  } else {
    Size::from_wh(1.0, 1.0).unwrap()
  }
  for child in filter.children() {
    let tag_name = match child.tag_name() {
      Some(v) => v
      None => continue
    }
    let filter_subregion = match
      resolve_primitive_region(
        child, tag_name, units, state, object_bbox, filter_region,
      ) {
      Some(v) => v
      None => break
    }
    let kind = match tag_name {
      EId::FeDropShadow => convert_drop_shadow(child, scale, primitives)
      EId::FeGaussianBlur => convert_gaussian_blur(child, scale, primitives)
      EId::FeOffset => convert_offset(child, scale, primitives)
      EId::FeBlend => convert_blend(child, primitives)
      EId::FeFlood => convert_flood(child)
      EId::FeComposite => convert_composite(child, primitives)
      EId::FeMerge => convert_merge(child, primitives)
      EId::FeTile => convert_tile(child, primitives)
      EId::FeImage => convert_fe_image(child, filter_subregion, state, cache)
      EId::FeComponentTransfer => convert_component_transfer(child, primitives)
      EId::FeColorMatrix => convert_color_matrix(child, primitives)
      EId::FeConvolveMatrix =>
        convert_convolve_matrix(child, primitives).unwrap_or_else(
          create_dummy_primitive,
        )
      EId::FeMorphology => convert_morphology(child, scale, primitives)
      EId::FeDisplacementMap =>
        convert_displacement_map(child, scale, primitives)
      EId::FeTurbulence => convert_turbulence(child)
      EId::FeDiffuseLighting =>
        convert_diffuse_lighting(child, primitives).unwrap_or_else(
          create_dummy_primitive,
        )
      EId::FeSpecularLighting =>
        convert_specular_lighting(child, primitives).unwrap_or_else(
          create_dummy_primitive,
        )
      _ =>
        // Upstream warns: '{}' is not a valid filter primitive. Skipped.
        continue
    }
    let color_interpolation : ColorInterpolation = child
      .find_attribute(AId::ColorInterpolationFilters)
      .unwrap_or(ColorInterpolation::default())
    primitives.push({
      rect: filter_subregion,
      color_interpolation,
      result: gen_result(child, results),
      kind,
    })
  }

  // TODO: remove primitives which results are not used

  primitives
}

///|
// TODO: rewrite/simplify/explain/whatever
fn resolve_primitive_region(
  fe : SvgNode,
  kind : EId,
  units : Units,
  state : State,
  bbox : NonZeroRect?,
  filter_region : NonZeroRect,
) -> NonZeroRect? {
  let x = fe.try_convert_length(AId::X, units, state)
  let y = fe.try_convert_length(AId::Y, units, state)
  let width = fe.try_convert_length(AId::Width, units, state)
  let height = fe.try_convert_length(AId::Height, units, state)
  let region = match kind {
    EId::FeFlood | EId::FeImage =>
      // `feImage` uses the object bbox.
      if units == ObjectBoundingBox {
        guard bbox is Some(bbox) else { return None }

        // TODO: wrong
        // let ts_bbox = tiny_skia::Rect::new(ts.e, ts.f, ts.a, ts.d).unwrap();

        guard NonZeroRect::from_xywh(
            x.unwrap_or(0.0),
            y.unwrap_or(0.0),
            width.unwrap_or(1.0),
            height.unwrap_or(1.0),
          )
          is Some(r) else {
          return None
        }
        return Some(r.bbox_transform(bbox))
      } else {
        filter_region
      }
    _ => filter_region
  }

  // TODO: Wrong! Does not account rotate and skew.
  if units == ObjectBoundingBox {
    guard NonZeroRect::from_xywh(
        x.unwrap_or(0.0),
        y.unwrap_or(0.0),
        width.unwrap_or(1.0),
        height.unwrap_or(1.0),
      )
      is Some(subregion_bbox) else {
      return None
    }
    Some(region.bbox_transform(subregion_bbox))
  } else {
    NonZeroRect::from_xywh(
      x.unwrap_or(region.x()),
      y.unwrap_or(region.y()),
      width.unwrap_or(region.width()),
      height.unwrap_or(region.height()),
    )
  }
}

///|
// A malformed filter primitive usually should produce a transparent image.
// But since `FilterKind` structs are designed to always be valid,
// we are using `FeFlood` as fallback.
fn create_dummy_primitive() -> FilterKind {
  Flood({ color: Color::black(), opacity: Opacity::zero(), })
}

///|
fn resolve_input(
  node : SvgNode,
  aid : AId,
  primitives : Array[Primitive],
) -> FilterInput {
  let s : String? = node.attribute(aid)
  match s {
    Some(s) => {
      let input = parse_in(s)

      // If `in` references an unknown `result` than fallback
      // to previous result or `SourceGraphic`.
      if input is Reference(name) {
        if !primitives.iter().any(p => p.result == name) {
          return if primitives.last() is Some(prev) {
            Reference(prev.result)
          } else {
            SourceGraphic
          }
        }
      }
      input
    }
    None =>
      if primitives.last() is Some(prev) {
        // If `in` is not set and this is not the first primitive
        // than the input is a result of the previous primitive.
        Reference(prev.result)
      } else {
        // If `in` is not set and this is the first primitive
        // than the input is `SourceGraphic`.
        SourceGraphic
      }
  }
}

///|
fn parse_in(s : String) -> FilterInput {
  match s {
    "SourceGraphic" => SourceGraphic
    "SourceAlpha" => SourceAlpha
    "BackgroundImage" | "BackgroundAlpha" | "FillPaint" | "StrokePaint" =>
      // Upstream warns: {} filter input isn't supported and not planed.
      SourceGraphic
    _ => Reference(s)
  }
}

///|
fn gen_result(node : SvgNode, results : FilterResults) -> String {
  let s : String? = node.attribute(AId::Result)
  match s {
    Some(s) => {
      // Remember predefined result.
      results.names.add(s)
      results.idx += 1
      s
    }
    None =>
      // Generate an unique name for `result`.
      for ;; {
        let name = "result\{results.idx}"
        results.idx += 1
        if !results.names.contains(name) {
          break name
        }
      }
  }
}

///|
fn convert_blend(fe : SvgNode, primitives : Array[Primitive]) -> FilterKind {
  let mode : BlendMode = fe.attribute(AId::Mode).unwrap_or(BlendMode::default())
  let input1 = resolve_input(fe, AId::In, primitives)
  let input2 = resolve_input(fe, AId::In2, primitives)
  Blend({ mode, input1, input2, })
}

///|
fn convert_color_matrix(
  fe : SvgNode,
  primitives : Array[Primitive],
) -> FilterKind {
  let kind = convert_color_matrix_kind(fe).unwrap_or(ColorMatrixKind::default())
  ColorMatrix({ input: resolve_input(fe, AId::In, primitives), kind, })
}

///|
fn convert_color_matrix_kind(fe : SvgNode) -> ColorMatrixKind? {
  let type_ : String? = fe.attribute(AId::Type)
  match type_ {
    Some("saturate") => {
      let list : Array[Float]? = fe.attribute(AId::Values)
      if list is Some(list) {
        if !list.is_empty() {
          let n = f32_bound(0.0, list[0], 1.0)
          return Some(Saturate(PositiveF32::new(n).unwrap()))
        } else {
          return Some(Saturate(PositiveF32::new(1.0).unwrap()))
        }
      }
    }
    Some("hueRotate") => {
      let list : Array[Float]? = fe.attribute(AId::Values)
      if list is Some(list) {
        if !list.is_empty() {
          return Some(HueRotate(list[0]))
        } else {
          return Some(HueRotate(0.0))
        }
      }
    }
    Some("luminanceToAlpha") => return Some(LuminanceToAlpha)
    _ => {
      // Fallback to `matrix`.
      let list : Array[Float]? = fe.attribute(AId::Values)
      if list is Some(list) {
        if list.length() == 20 {
          return Some(Matrix(list))
        }
      }
    }
  }
  None
}

///|
fn convert_component_transfer(
  fe : SvgNode,
  primitives : Array[Primitive],
) -> FilterKind {
  let mut func_r = Identity
  let mut func_g = Identity
  let mut func_b = Identity
  let mut func_a = Identity
  let input = resolve_input(fe, AId::In, primitives)
  for child in fe.children() {
    if !child.is_element() {
      continue
    }
    if convert_transfer_function(child) is Some(func) {
      match child.tag_name().unwrap() {
        EId::FeFuncR => func_r = func
        EId::FeFuncG => func_g = func
        EId::FeFuncB => func_b = func
        EId::FeFuncA => func_a = func
        _ => ()
      }
    }
  }
  ComponentTransfer({ input, func_r, func_g, func_b, func_a, })
}

///|
fn convert_transfer_function(node : SvgNode) -> TransferFunction? {
  guard (node.attribute(AId::Type) : String?) is Some(type_) else {
    return None
  }
  match type_ {
    "identity" => Some(Identity)
    "table" => {
      let values : Array[Float]? = node.attribute(AId::TableValues)
      match values {
        Some(values) => Some(Table(values))
        None => Some(Table([]))
      }
    }
    "discrete" => {
      let values : Array[Float]? = node.attribute(AId::TableValues)
      match values {
        Some(values) => Some(Discrete(values))
        None => Some(Discrete([]))
      }
    }
    "linear" =>
      Some(
        Linear(
          slope=node.attribute(AId::Slope).unwrap_or(1.0),
          intercept=node.attribute(AId::Intercept).unwrap_or(0.0),
        ),
      )
    "gamma" =>
      Some(
        Gamma(
          amplitude=node.attribute(AId::Amplitude).unwrap_or(1.0),
          exponent=node.attribute(AId::Exponent).unwrap_or(1.0),
          offset=node.attribute(AId::Offset).unwrap_or(0.0),
        ),
      )
    _ => None
  }
}

///|
fn convert_composite(fe : SvgNode, primitives : Array[Primitive]) -> FilterKind {
  let op : String = fe.attribute(AId::Operator).unwrap_or("over")
  let operator = match op {
    "in" => CompositeOperator::In
    "out" => Out
    "atop" => Atop
    "xor" => Xor
    "arithmetic" =>
      Arithmetic(
        k1=fe.attribute(AId::K1).unwrap_or(0.0),
        k2=fe.attribute(AId::K2).unwrap_or(0.0),
        k3=fe.attribute(AId::K3).unwrap_or(0.0),
        k4=fe.attribute(AId::K4).unwrap_or(0.0),
      )
    _ => Over
  }
  let input1 = resolve_input(fe, AId::In, primitives)
  let input2 = resolve_input(fe, AId::In2, primitives)
  Composite({ operator, input1, input2, })
}

///|
/// Rust's saturating `f32 as i32` cast.
fn f32_as_i32(x : Float) -> Int {
  x.to_int()
}

///|
/// Rust's saturating `f64 as i32` cast.
fn f64_as_i32(x : Double) -> Int {
  if x.is_nan() {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else if x <= -2147483648.0 {
    -2147483648
  } else {
    x.to_int()
  }
}

///|
/// Rust's saturating `f32 as u32` cast.
fn f32_as_u32(x : Float) -> UInt {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 4294967295.0 {
    4294967295
  } else {
    x.to_double().to_uint()
  }
}

///|
fn convert_convolve_matrix(
  fe : SvgNode,
  primitives : Array[Primitive],
) -> FilterKind? {
  fn parse_target(target : Float?, order : UInt) -> UInt? {
    let default_target = f32_as_u32((Float::from_uint(order) / 2.0).floor())
    let target = f32_as_i32(target.unwrap_or(Float::from_uint(default_target)))
    if target < 0 || target >= order.reinterpret_as_int() {
      None
    } else {
      Some(target.reinterpret_as_uint())
    }
  }

  let mut order_x : UInt = 3
  let mut order_y : UInt = 3
  let value : String? = fe.attribute(AId::Order)
  if value is Some(value) {
    let s = @svgtypes.NumberListParser::from(value)
    let x = match s.next() {
      Some(Ok(n)) => f64_as_i32(n)
      _ => 3
    }
    let y = match s.next() {
      Some(Ok(n)) => f64_as_i32(n)
      _ => x
    }
    if x > 0 && y > 0 {
      order_x = x.reinterpret_as_uint()
      order_y = y.reinterpret_as_uint()
    }
  }
  let mut matrix = []
  let list : Array[Float]? = fe.attribute(AId::KernelMatrix)
  if list is Some(list) {
    if list.length() == (order_x * order_y).reinterpret_as_int() {
      matrix = list
    }
  }
  let mut kernel_sum : Float = 0.0
  for v in matrix {
    kernel_sum += v
  }
  // Round up to prevent float precision issues.
  kernel_sum = rust_round_f32(kernel_sum * 1_000_000.0) / 1_000_000.0
  if approx_zero_ulps(kernel_sum, 4) {
    kernel_sum = 1.0
  }
  let divisor : Float = fe.attribute(AId::Divisor).unwrap_or(kernel_sum)
  if approx_zero_ulps(divisor, 4) {
    return None
  }
  let bias : Float = fe.attribute(AId::Bias).unwrap_or(0.0)
  guard parse_target(fe.attribute(AId::TargetX), order_x) is Some(target_x) else {
    return None
  }
  guard parse_target(fe.attribute(AId::TargetY), order_y) is Some(target_y) else {
    return None
  }
  guard ConvolveMatrixData::new(target_x, target_y, order_x, order_y, matrix)
    is Some(kernel_matrix) else {
    return None
  }
  let edge_mode_attr : String = fe
    .attribute(AId::EdgeMode)
    .unwrap_or("duplicate")
  let edge_mode = match edge_mode_attr {
    "none" => EdgeNone
    "wrap" => Wrap
    _ => Duplicate
  }
  let preserve_alpha_attr : String = fe
    .attribute(AId::PreserveAlpha)
    .unwrap_or("false")
  let preserve_alpha = preserve_alpha_attr == "true"
  Some(
    ConvolveMatrix({
      input: resolve_input(fe, AId::In, primitives),
      matrix: kernel_matrix,
      divisor: NonZeroF32::new(divisor).unwrap(),
      bias,
      edge_mode,
      preserve_alpha,
    }),
  )
}

///|
/// Rust's `f32::round` (half away from zero).
fn rust_round_f32(x : Float) -> Float {
  if x.is_nan() || x.is_inf() {
    return x
  }
  let t = x.trunc()
  let diff = (x - t).abs()
  if diff >= 0.5 {
    t + (if x < 0.0 { -1.0 } else { 1.0 })
  } else {
    t
  }
}

///|
fn convert_displacement_map(
  fe : SvgNode,
  scale : Size,
  primitives : Array[Primitive],
) -> FilterKind {
  let parse_channel = (aid : AId) => {
    let v : String = fe.attribute(aid).unwrap_or("A")
    match v {
      "R" => ColorChannel::R
      "G" => ColorChannel::G
      "B" => ColorChannel::B
      _ => ColorChannel::A
    }
  }

  // TODO: should probably split scale to scale_x and scale_y,
  //       but resvg doesn't support displacement map anyway...
  let scale = (scale.width() + scale.height()) / 2.0
  let scale_attr : Float = fe.attribute(AId::Scale).unwrap_or(0.0)
  DisplacementMap({
    input1: resolve_input(fe, AId::In, primitives),
    input2: resolve_input(fe, AId::In2, primitives),
    scale: scale_attr * scale,
    x_channel_selector: parse_channel(AId::XChannelSelector),
    y_channel_selector: parse_channel(AId::YChannelSelector),
  })
}

///|
fn convert_drop_shadow(
  fe : SvgNode,
  scale : Size,
  primitives : Array[Primitive],
) -> FilterKind {
  let (std_dev_x, std_dev_y) = convert_std_dev_attr(fe, scale, "2 2")
  let (color, opacity) = fe
    .attribute(AId::FloodColor)
    .unwrap_or(@svgtypes.Color::black())
    .split_alpha()
  let flood_opacity : Opacity = fe
    .attribute(AId::FloodOpacity)
    .unwrap_or(Opacity::one())
  let dx : Float = fe.attribute(AId::Dx).unwrap_or(2.0)
  let dy : Float = fe.attribute(AId::Dy).unwrap_or(2.0)
  DropShadow({
    input: resolve_input(fe, AId::In, primitives),
    dx: dx * scale.width(),
    dy: dy * scale.height(),
    std_dev_x,
    std_dev_y,
    color,
    opacity: opacity * flood_opacity,
  })
}

///|
fn convert_flood(fe : SvgNode) -> FilterKind {
  let (color, opacity) = fe
    .attribute(AId::FloodColor)
    .unwrap_or(@svgtypes.Color::black())
    .split_alpha()
  let flood_opacity : Opacity = fe
    .attribute(AId::FloodOpacity)
    .unwrap_or(Opacity::one())
  Flood({ color, opacity: opacity * flood_opacity, })
}

///|
fn convert_gaussian_blur(
  fe : SvgNode,
  scale : Size,
  primitives : Array[Primitive],
) -> FilterKind {
  let (std_dev_x, std_dev_y) = convert_std_dev_attr(fe, scale, "0 0")
  GaussianBlur({
    input: resolve_input(fe, AId::In, primitives),
    std_dev_x,
    std_dev_y,
  })
}

///|
fn convert_std_dev_attr(
  fe : SvgNode,
  scale : Size,
  default : String,
) -> (PositiveF32, PositiveF32) {
  let text : String = fe.attribute(AId::StdDeviation).unwrap_or(default)
  let parser = @svgtypes.NumberListParser::from(text)
  let next = () => {
    match parser.next() {
      Some(Ok(n)) => Some(n)
      _ => None
    }
  }
  let n1 = next()
  let n2 = next()
  // `stdDeviation` must have no more than two values.
  // Otherwise we should fallback to `0 0`.
  let n3 = next()
  let (std_dev_x, std_dev_y) = match (n1, n2, n3) {
    (Some(n1), Some(n2), None) => (n1, n2)
    (Some(n1), None, None) => (n1, n1)
    _ => (0.0, 0.0)
  }
  let std_dev_x = Float::from_double(std_dev_x) * scale.width()
  let std_dev_y = Float::from_double(std_dev_y) * scale.height()
  let std_dev_x = PositiveF32::new(std_dev_x).unwrap_or(PositiveF32::zero())
  let std_dev_y = PositiveF32::new(std_dev_y).unwrap_or(PositiveF32::zero())
  (std_dev_x, std_dev_y)
}

///|
fn convert_fe_image(
  fe : SvgNode,
  filter_subregion : NonZeroRect,
  state : State,
  cache : Cache,
) -> FilterKind {
  match convert_fe_image_inner(fe, filter_subregion, state, cache) {
    Some(kind) => kind
    None => create_dummy_primitive()
  }
}

///|
fn convert_fe_image_inner(
  fe : SvgNode,
  filter_subregion : NonZeroRect,
  state : State,
  cache : Cache,
) -> FilterKind? {
  let rendering_mode : ImageRendering = fe
    .find_attribute(AId::ImageRendering)
    .unwrap_or(state.opt.image_rendering)
  let node : SvgNode? = fe.try_attribute(AId::Href)
  if node is Some(node) {
    let state = { ..state, fe_image_link: true, }
    let root = Group::empty()
    convert_element(node, state, cache, root)
    return if root.has_children() {
      root.calculate_bounding_boxes() |> ignore
      // Transfer node id from group's child to the group itself if needed.
      if root.children.get(0) is Some(Group(g)) {
        if g.children.get(0) is Some(child2) {
          g.id = child2.id()
          match child2 {
            Group(g2) => g2.id = ""
            Path(path) => path.id = ""
            Image(image) => g.children[0] = Image({ ..image, id: "", })
            Text(text) => text.id = ""
          }
        }
      }
      Some(Image({ root, }))
    } else {
      None
    }
  }
  // Upstream warns: The 'feImage' element lacks the 'xlink:href' attribute. Skipped.
  guard (fe.try_attribute(AId::Href) : String?) is Some(href) else {
    return None
  }
  guard get_href_data(href, state) is Some(img_data) else { return None }
  guard img_data.actual_size() is Some(actual_size) else { return None }
  let aspect : @svgtypes.AspectRatio = fe
    .attribute(AId::PreserveAspectRatio)
    .unwrap_or(@svgtypes.AspectRatio::default())
  let root = Group::empty()
  guard filter_subregion.translate_to(0.0, 0.0) is Some(subregion) else {
    return None
  }
  convert_image_inner(
    img_data,
    cache.gen_image_id().get(),
    true,
    rendering_mode,
    aspect,
    actual_size,
    subregion,
    cache,
    root,
  )
  |> ignore
  root.calculate_bounding_boxes() |> ignore
  Some(Image({ root, }))
}

///|
fn convert_diffuse_lighting(
  fe : SvgNode,
  primitives : Array[Primitive],
) -> FilterKind? {
  guard convert_light_source(fe) is Some(light_source) else { return None }
  Some(
    DiffuseLighting({
      input: resolve_input(fe, AId::In, primitives),
      surface_scale: fe.attribute(AId::SurfaceScale).unwrap_or(1.0),
      diffuse_constant: fe.attribute(AId::DiffuseConstant).unwrap_or(1.0),
      lighting_color: convert_lighting_color(fe),
      light_source,
    }),
  )
}

///|
fn convert_specular_lighting(
  fe : SvgNode,
  primitives : Array[Primitive],
) -> FilterKind? {
  guard convert_light_source(fe) is Some(light_source) else { return None }
  let specular_exponent : Float = fe
    .attribute(AId::SpecularExponent)
    .unwrap_or(1.0)
  if !(specular_exponent >= 1.0 && specular_exponent <= 128.0) {
    // When exponent is out of range, the whole filter primitive should be ignored.
    return None
  }
  let specular_exponent = f32_bound(1.0, specular_exponent, 128.0)
  Some(
    SpecularLighting({
      input: resolve_input(fe, AId::In, primitives),
      surface_scale: fe.attribute(AId::SurfaceScale).unwrap_or(1.0),
      specular_constant: fe.attribute(AId::SpecularConstant).unwrap_or(1.0),
      specular_exponent,
      lighting_color: convert_lighting_color(fe),
      light_source,
    }),
  )
}

///|
fn convert_lighting_color(node : SvgNode) -> Color {
  // Color's alpha doesn't affect lighting-color. Simply skip it.
  let value : String? = node.attribute(AId::LightingColor)
  match value {
    Some("currentColor") =>
      node
      .find_attribute(AId::Color)
      // Yes, a missing `currentColor` resolves to black and not white.
      .unwrap_or(@svgtypes.Color::black())
      .split_alpha().0
    Some(value) =>
      match (try? @svgtypes.Color::from_str(value)) {
        Ok(c) => c.split_alpha().0
        Err(_) =>
          // Upstream warns: Failed to parse lighting-color value.
          Color::white()
      }
    _ => Color::white()
  }
}

///|
fn convert_light_source(parent : SvgNode) -> LightSource? {
  guard parent
    .children()
    .find_first(n => {
      n.tag_name()
      is Some(EId::FeDistantLight | EId::FePointLight | EId::FeSpotLight)
    })
    is Some(child) else {
    return None
  }
  match child.tag_name() {
    Some(EId::FeDistantLight) =>
      Some(
        DistantLight({
          azimuth: child.attribute(AId::Azimuth).unwrap_or(0.0),
          elevation: child.attribute(AId::Elevation).unwrap_or(0.0),
        }),
      )
    Some(EId::FePointLight) =>
      Some(
        PointLight({
          x: child.attribute(AId::X).unwrap_or(0.0),
          y: child.attribute(AId::Y).unwrap_or(0.0),
          z: child.attribute(AId::Z).unwrap_or(0.0),
        }),
      )
    Some(EId::FeSpotLight) => {
      let specular_exponent : Float = child
        .attribute(AId::SpecularExponent)
        .unwrap_or(1.0)
      let specular_exponent = PositiveF32::new(specular_exponent).unwrap_or(
        PositiveF32::new(1.0).unwrap(),
      )
      Some(
        SpotLight({
          x: child.attribute(AId::X).unwrap_or(0.0),
          y: child.attribute(AId::Y).unwrap_or(0.0),
          z: child.attribute(AId::Z).unwrap_or(0.0),
          points_at_x: child.attribute(AId::PointsAtX).unwrap_or(0.0),
          points_at_y: child.attribute(AId::PointsAtY).unwrap_or(0.0),
          points_at_z: child.attribute(AId::PointsAtZ).unwrap_or(0.0),
          specular_exponent,
          limiting_cone_angle: child.attribute(AId::LimitingConeAngle),
        }),
      )
    }
    _ => None
  }
}

///|
fn convert_merge(fe : SvgNode, primitives : Array[Primitive]) -> FilterKind {
  let inputs = []
  for child in fe.children() {
    inputs.push(resolve_input(child, AId::In, primitives))
  }
  Merge({ inputs, })
}

///|
fn convert_morphology(
  fe : SvgNode,
  scale : Size,
  primitives : Array[Primitive],
) -> FilterKind {
  let op : String = fe.attribute(AId::Operator).unwrap_or("erode")
  let operator = match op {
    "dilate" => Dilate
    _ => Erode
  }
  let mut radius_x = PositiveF32::new(scale.width()).unwrap()
  let mut radius_y = PositiveF32::new(scale.height()).unwrap()
  let list : Array[Float]? = fe.attribute(AId::Radius)
  if list is Some(list) {
    let mut rx : Float = 0.0
    let mut ry : Float = 0.0
    if list.length() == 2 {
      rx = list[0]
      ry = list[1]
    } else if list.length() == 1 {
      rx = list[0]
      ry = list[0] // The same as `rx`.
    }
    if approx_zero_ulps(rx, 4) && approx_zero_ulps(ry, 4) {
      rx = 1.0
      ry = 1.0
    }

    // If only one of the values is zero, reset it to 1.0
    // This is not specified in the spec, but this is how Chrome and Safari work.
    if approx_zero_ulps(rx, 4) && !approx_zero_ulps(ry, 4) {
      rx = 1.0
    }
    if !approx_zero_ulps(rx, 4) && approx_zero_ulps(ry, 4) {
      ry = 1.0
    }

    // Both values must be positive.
    if is_sign_positive_f32(rx) && is_sign_positive_f32(ry) {
      radius_x = PositiveF32::new(rx * scale.width()).unwrap()
      radius_y = PositiveF32::new(ry * scale.height()).unwrap()
    }
  }
  Morphology({
    input: resolve_input(fe, AId::In, primitives),
    operator,
    radius_x,
    radius_y,
  })
}

///|
fn convert_offset(
  fe : SvgNode,
  scale : Size,
  primitives : Array[Primitive],
) -> FilterKind {
  let dx : Float = fe.attribute(AId::Dx).unwrap_or(0.0)
  let dy : Float = fe.attribute(AId::Dy).unwrap_or(0.0)
  Offset({
    input: resolve_input(fe, AId::In, primitives),
    dx: dx * scale.width(),
    dy: dy * scale.height(),
  })
}

///|
fn convert_tile(fe : SvgNode, primitives : Array[Primitive]) -> FilterKind {
  Tile({ input: resolve_input(fe, AId::In, primitives), })
}

///|
fn convert_turbulence(fe : SvgNode) -> FilterKind {
  let mut base_frequency_x = PositiveF32::zero()
  let mut base_frequency_y = PositiveF32::zero()
  let list : Array[Float]? = fe.attribute(AId::BaseFrequency)
  if list is Some(list) {
    let mut x : Float = 0.0
    let mut y : Float = 0.0
    if list.length() == 2 {
      x = list[0]
      y = list[1]
    } else if list.length() == 1 {
      x = list[0]
      y = list[0] // The same as `x`.
    }
    if is_sign_positive_f32(x) && is_sign_positive_f32(y) {
      base_frequency_x = PositiveF32::new(x).unwrap()
      base_frequency_y = PositiveF32::new(y).unwrap()
    }
  }
  let mut num_octaves : Float = fe.attribute(AId::NumOctaves).unwrap_or(1.0)
  if is_sign_negative_f32(num_octaves) {
    num_octaves = 0.0
  }
  let type_ : String = fe.attribute(AId::Type).unwrap_or("turbulence")
  let kind = match type_ {
    "fractalNoise" => FractalNoise
    _ => TurbulenceKind::Turbulence
  }
  let seed : Float = fe.attribute(AId::Seed).unwrap_or(0.0)
  let stitch : String? = fe.attribute(AId::StitchTiles)
  Turbulence({
    base_frequency_x,
    base_frequency_y,
    num_octaves: f32_as_u32(rust_round_f32(num_octaves)),
    seed: f32_as_i32(seed.trunc()),
    stitch_tiles: stitch == Some("stitch"),
    kind,
  })
}

///|
fn convert_grayscale_function(amount : Double) -> FilterKind {
  let amount = Float::from_double(amount.min(1.0))
  let one : Float = 1.0
  ColorMatrix({
    input: SourceGraphic,
    kind: Matrix([
      0.2126 + 0.7874 * (one - amount),
      0.7152 - 0.7152 * (one - amount),
      0.0722 - 0.0722 * (one - amount),
      0.0,
      0.0,
      0.2126 - 0.2126 * (one - amount),
      0.7152 + 0.2848 * (one - amount),
      0.0722 - 0.0722 * (one - amount),
      0.0,
      0.0,
      0.2126 - 0.2126 * (one - amount),
      0.7152 - 0.7152 * (one - amount),
      0.0722 + 0.9278 * (one - amount),
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ]),
  })
}

///|
fn convert_sepia_function(amount : Double) -> FilterKind {
  let amount = Float::from_double(amount.min(1.0))
  let one : Float = 1.0
  ColorMatrix({
    input: SourceGraphic,
    kind: Matrix([
      0.393 + 0.607 * (one - amount),
      0.769 - 0.769 * (one - amount),
      0.189 - 0.189 * (one - amount),
      0.0,
      0.0,
      0.349 - 0.349 * (one - amount),
      0.686 + 0.314 * (one - amount),
      0.168 - 0.168 * (one - amount),
      0.0,
      0.0,
      0.272 - 0.272 * (one - amount),
      0.534 - 0.534 * (one - amount),
      0.131 + 0.869 * (one - amount),
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ]),
  })
}

///|
fn convert_saturate_function(amount : Double) -> FilterKind {
  let amount = PositiveF32::new(Float::from_double(amount)).unwrap_or(
    PositiveF32::zero(),
  )
  ColorMatrix({ input: SourceGraphic, kind: Saturate(amount), })
}

///|
fn convert_hue_rotate_function(amount : @svgtypes.Angle) -> FilterKind {
  ColorMatrix({
    input: SourceGraphic,
    kind: HueRotate(Float::from_double(amount.to_degrees())),
  })
}

///|
fn convert_invert_function(amount : Double) -> FilterKind {
  let amount = Float::from_double(amount.min(1.0))
  let one : Float = 1.0
  ComponentTransfer({
    input: SourceGraphic,
    func_r: Table([amount, one - amount]),
    func_g: Table([amount, one - amount]),
    func_b: Table([amount, one - amount]),
    func_a: Identity,
  })
}

///|
fn convert_opacity_function(amount : Double) -> FilterKind {
  let amount = Float::from_double(amount.min(1.0))
  ComponentTransfer({
    input: SourceGraphic,
    func_r: Identity,
    func_g: Identity,
    func_b: Identity,
    func_a: Table([0.0, amount]),
  })
}

///|
fn convert_brightness_function(amount : Double) -> FilterKind {
  let amount = Float::from_double(amount)
  ComponentTransfer({
    input: SourceGraphic,
    func_r: Linear(slope=amount, intercept=0.0),
    func_g: Linear(slope=amount, intercept=0.0),
    func_b: Linear(slope=amount, intercept=0.0),
    func_a: Identity,
  })
}

///|
fn convert_contrast_function(amount : Double) -> FilterKind {
  let amount = Float::from_double(amount)
  let half : Float = 0.5
  ComponentTransfer({
    input: SourceGraphic,
    func_r: Linear(slope=amount, intercept=-(half * amount) + half),
    func_g: Linear(slope=amount, intercept=-(half * amount) + half),
    func_b: Linear(slope=amount, intercept=-(half * amount) + half),
    func_a: Identity,
  })
}

///|
fn convert_blur_function(
  node : SvgNode,
  std_dev : @svgtypes.Length,
  state : State,
) -> FilterKind {
  let std_dev = PositiveF32::new(
    convert_user_length(std_dev, node, AId::Dx, state),
  ).unwrap_or(PositiveF32::zero())
  GaussianBlur({ input: SourceGraphic, std_dev_x: std_dev, std_dev_y: std_dev, })
}

///|
fn convert_drop_shadow_function(
  node : SvgNode,
  color : @svgtypes.Color?,
  dx : @svgtypes.Length,
  dy : @svgtypes.Length,
  std_dev : @svgtypes.Length,
  state : State,
) -> FilterKind {
  let std_dev = PositiveF32::new(
    convert_user_length(std_dev, node, AId::Dx, state),
  ).unwrap_or(PositiveF32::zero())
  let (color, opacity) = (match color {
    Some(c) => c
    None => node.find_attribute(AId::Color).unwrap_or(@svgtypes.Color::black())
  }).split_alpha()
  DropShadow({
    input: SourceGraphic,
    dx: convert_user_length(dx, node, AId::Dx, state),
    dy: convert_user_length(dy, node, AId::Dy, state),
    std_dev_x: std_dev,
    std_dev_y: std_dev,
    color,
    opacity,
  })
}
