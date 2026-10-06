// Port of `usvg` 0.47.0 `src/parser/style.rs`: fill and stroke resolving.

///|
impl FromValue for LineCap with fn parse(_, _, value) {
  match value {
    "butt" => Some(Butt)
    "round" => Some(Round)
    "square" => Some(Square)
    _ => None
  }
}

///|
impl FromValue for LineJoin with fn parse(_, _, value) {
  match value {
    "miter" => Some(Miter)
    "miter-clip" => Some(MiterClip)
    "round" => Some(Round)
    "bevel" => Some(Bevel)
    _ => None
  }
}

///|
impl FromValue for FillRule with fn parse(_, _, value) {
  match value {
    "nonzero" => Some(NonZero)
    "evenodd" => Some(EvenOdd)
    _ => None
  }
}

///|
fn resolve_fill(
  node : SvgNode,
  has_bbox : Bool,
  state : State,
  cache : Cache,
) -> Fill? {
  if state.parent_clip_path is Some(_) {
    // A `clipPath` child can be filled only with a black color.
    return Some({
      paint: Color(Color::black()),
      opacity: Opacity::one(),
      rule: node.find_attribute(AId::ClipRule).unwrap_or(FillRule::default()),
      context_element: None,
    })
  }
  let sub_opacity = Ref(Opacity::one())
  let (paint, context_element) = if node
    .ancestors()
    .find_first(n => n.has_attribute(AId::Fill))
    is Some(n) {
    guard (n.attribute(AId::Fill) : String?) is Some(value) else { return None }
    guard convert_paint(
        node,
        value,
        AId::Fill,
        has_bbox,
        state,
        sub_opacity,
        cache,
      )
      is Some(r) else {
      return None
    }
    r
  } else {
    (Color(Color::black()), None)
  }
  let fill_opacity : Opacity = node
    .find_attribute(AId::FillOpacity)
    .unwrap_or(Opacity::one())
  Some({
    paint,
    opacity: sub_opacity.val * fill_opacity,
    rule: node.find_attribute(AId::FillRule).unwrap_or(FillRule::default()),
    context_element,
  })
}

///|
fn resolve_stroke(
  node : SvgNode,
  has_bbox : Bool,
  state : State,
  cache : Cache,
) -> Stroke? {
  if state.parent_clip_path is Some(_) {
    // A `clipPath` child cannot be stroked.
    return None
  }
  let sub_opacity = Ref(Opacity::one())
  let (paint, context_element) = if node
    .ancestors()
    .find_first(n => n.has_attribute(AId::Stroke))
    is Some(n) {
    guard (n.attribute(AId::Stroke) : String?) is Some(value) else {
      return None
    }
    guard convert_paint(
        node,
        value,
        AId::Stroke,
        has_bbox,
        state,
        sub_opacity,
        cache,
      )
      is Some(r) else {
      return None
    }
    r
  } else {
    return None
  }
  guard node.resolve_valid_length(AId::StrokeWidth, state, 1.0) is Some(width) else {
    return None
  }

  // Must be bigger than 1.
  let miterlimit : Float = node
    .find_attribute(AId::StrokeMiterlimit)
    .unwrap_or(4.0)
  let miterlimit : Float = if miterlimit < 1.0 { 1.0 } else { miterlimit }
  let miterlimit = StrokeMiterlimit::new(miterlimit)
  let stroke_opacity : Opacity = node
    .find_attribute(AId::StrokeOpacity)
    .unwrap_or(Opacity::one())
  let stroke : Stroke = {
    paint,
    dasharray: conv_dasharray(node, state),
    dashoffset: node.resolve_length(AId::StrokeDashoffset, state, 0.0),
    miterlimit,
    opacity: sub_opacity.val * stroke_opacity,
    width,
    linecap: node
    .find_attribute(AId::StrokeLinecap)
    .unwrap_or(LineCap::default()),
    linejoin: node
    .find_attribute(AId::StrokeLinejoin)
    .unwrap_or(LineJoin::default()),
    context_element,
  }
  Some(stroke)
}

///|
fn convert_paint(
  node : SvgNode,
  value : String,
  aid : AId,
  has_bbox : Bool,
  state : State,
  opacity : Ref[Opacity],
  cache : Cache,
) -> (Paint, ContextElement?)? {
  let paint = try @svgtypes.Paint::from_str(value) catch {
    _ =>
      if aid == AId::Fill {
        // Upstream warns: Failed to parse fill value. Fallback to black.
        @svgtypes.Paint::Color(@svgtypes.Color::black())
      } else {
        // Upstream warns: Failed to parse stroke value. Fallback to no stroke.
        return None
      }
  } noraise {
    v => v
  }
  match paint {
    None => None
    Inherit => None // already resolved by svgtree
    ContextFill =>
      match state.context_element {
        Some((Some(f), _)) => Some((f.paint, f.context_element))
        _ => None
      }
    ContextStroke =>
      match state.context_element {
        Some((_, Some(s))) => Some((s.paint, s.context_element))
        _ => None
      }
    CurrentColor => {
      let svg_color : @svgtypes.Color = node
        .find_attribute(AId::Color)
        .unwrap_or(@svgtypes.Color::black())
      let (color, alpha) = svg_color.split_alpha()
      opacity.val = alpha
      Some((Color(color), None))
    }
    Color(svg_color) => {
      let (color, alpha) = svg_color.split_alpha()
      opacity.val = alpha
      Some((Color(color), None))
    }
    FuncIRI(func_iri, fallback) =>
      if node.document().element_by_id(func_iri) is Some(link) {
        let tag_name = link.tag_name().unwrap()
        if tag_name.is_paint_server() {
          match paint_server_convert(link, state, cache) {
            Some(Server(paint)) =>
              // We can use a paint server node with ObjectBoundingBox units
              // for painting only when the shape itself has a bbox.
              //
              // See SVG spec 7.11 for details.

              if !has_bbox && paint.units() == ObjectBoundingBox {
                from_fallback(node, fallback, opacity).map(p => (p, None))
              } else {
                Some((paint, None))
              }
            Some(ServerColor(color~, opacity=so)) => {
              opacity.val = so
              Some((Color(color), None))
            }
            None => from_fallback(node, fallback, opacity).map(p => (p, None))
          }
        } else {
          // Upstream warns: '{}' cannot be used to {} a shape.
          None
        }
      } else {
        from_fallback(node, fallback, opacity).map(p => (p, None))
      }
  }
}

///|
fn from_fallback(
  node : SvgNode,
  fallback : @svgtypes.PaintFallback?,
  opacity : Ref[Opacity],
) -> Paint? {
  guard fallback is Some(fallback) else { return None }
  match fallback {
    None => None
    CurrentColor => {
      let svg_color : @svgtypes.Color = node
        .find_attribute(AId::Color)
        .unwrap_or(@svgtypes.Color::black())
      let (color, alpha) = svg_color.split_alpha()
      opacity.val = alpha
      Some(Color(color))
    }
    Color(svg_color) => {
      let (color, alpha) = svg_color.split_alpha()
      opacity.val = alpha
      Some(Color(color))
    }
  }
}

///|
// Prepare the 'stroke-dasharray' according to:
// https://www.w3.org/TR/SVG11/painting.html#StrokeDasharrayProperty
fn conv_dasharray(node : SvgNode, state : State) -> Array[Float]? {
  guard node.ancestors().find_first(n => n.has_attribute(AId::StrokeDasharray))
    is Some(node) else {
    return None
  }
  guard convert_list(node, AId::StrokeDasharray, state) is Some(list) else {
    return None
  }

  // `A negative value is an error`
  if list.iter().any(n => is_sign_negative_f32(n)) {
    return None
  }

  // `If the sum of the values is zero, then the stroke is rendered
  // as if a value of none were specified.`
  // no Iter::sum(), because of f64

  {
    let mut sum : Float = 0.0
    for n in list {
      sum += n
    }
    if approx_eq_ulps(sum, 0.0, 4) {
      return None
    }
  }

  // `If an odd number of values is provided, then the list of values
  // is repeated to yield an even number of values.`
  if list.length() % 2 != 0 {
    let tmp_list = list.copy()
    tmp_list.append(list)
    return Some(tmp_list)
  }
  Some(list)
}
