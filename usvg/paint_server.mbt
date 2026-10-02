// Port of `usvg` 0.47.0 `src/parser/paint_server.rs`: gradients and
// patterns.
//
// Upstream modifies shared paint servers, masks and filters in place when
// `Arc::get_mut` succeeds, i.e. when the object has exactly one strong
// reference; otherwise it creates a copy with a newly generated ID. This
// is observable (IDs in `Tree::to_string`), so it is emulated here: while
// paint servers are updated after the conversion (`Cache::ref_roots` is
// set), the references are counted by walking the tree; during the
// conversion itself, every converted paint server is also referenced by
// `Cache::paint` (and by the referencing shape), so `get_mut` fails unless
// the object was just created.

///|
priv enum ServerOrColor {
  Server(Paint)
  ServerColor(color~ : Color, opacity~ : Opacity)
}

///|
fn paint_server_convert(
  node : SvgNode,
  state : State,
  cache : Cache,
) -> ServerOrColor? {
  // Check for existing.
  if cache.paint.get(node.element_id()) is Some(paint) {
    return Some(Server(paint))
  }

  // Unwrap is safe, because we already checked for is_paint_server().
  let paint = match node.tag_name().unwrap() {
    EId::LinearGradient => convert_linear(node, state)
    EId::RadialGradient => convert_radial(node, state)
    EId::Pattern => convert_pattern(node, state, cache)
    _ => abort("unreachable")
  }
  if paint is Some(Server(paint)) {
    cache.paint[node.element_id()] = paint
  }
  paint
}

///|
fn convert_linear(node : SvgNode, state : State) -> ServerOrColor? {
  let id = NonEmptyString::new(node.element_id())?
  let stops = convert_stops(find_gradient_with_stops(node)?)
  if stops.length() < 2 {
    return stops_to_color(stops)
  }
  let units = convert_units(node, AId::GradientUnits, ObjectBoundingBox)
  let transform = node.resolve_transform(AId::GradientTransform, state)
  let gradient : LinearGradient = {
    uid: gen_uid(),
    x1: resolve_number(node, AId::X1, units, state, @svgtypes.Length::zero()),
    y1: resolve_number(node, AId::Y1, units, state, @svgtypes.Length::zero()),
    x2: resolve_number(
      node,
      AId::X2,
      units,
      state,
      @svgtypes.Length::new(100.0, @svgtypes.LengthUnit::Percent),
    ),
    y2: resolve_number(node, AId::Y2, units, state, @svgtypes.Length::zero()),
    base: {
      id,
      units,
      transform,
      spread_method: convert_spread_method(node),
      stops,
    },
  }
  Some(Server(LinearGradient(gradient)))
}

///|
fn convert_radial(node : SvgNode, state : State) -> ServerOrColor? {
  let id = NonEmptyString::new(node.element_id())?
  let stops = convert_stops(find_gradient_with_stops(node)?)
  if stops.length() < 2 {
    return stops_to_color(stops)
  }
  let units = convert_units(node, AId::GradientUnits, ObjectBoundingBox)
  let r = resolve_number(
    node,
    AId::R,
    units,
    state,
    @svgtypes.Length::new(50.0, @svgtypes.LengthUnit::Percent),
  )
  let fr = resolve_number(node, AId::Fr, units, state, @svgtypes.Length::zero())

  // 'A value of zero will cause the area to be painted as a single color
  // using the color and opacity of the last gradient stop.'
  //
  // https://www.w3.org/TR/SVG11/pservers.html#RadialGradientElementRAttribute
  if !is_valid_length(r) {
    let stop = stops.last().unwrap()
    return Some(ServerColor(color=stop.color, opacity=stop.opacity))
  }
  let spread_method = convert_spread_method(node)
  let cx = resolve_number(
    node,
    AId::Cx,
    units,
    state,
    @svgtypes.Length::new(50.0, @svgtypes.LengthUnit::Percent),
  )
  let cy = resolve_number(
    node,
    AId::Cy,
    units,
    state,
    @svgtypes.Length::new(50.0, @svgtypes.LengthUnit::Percent),
  )
  let fx = resolve_number(
    node,
    AId::Fx,
    units,
    state,
    @svgtypes.Length::new_number(cx.to_double()),
  )
  let fy = resolve_number(
    node,
    AId::Fy,
    units,
    state,
    @svgtypes.Length::new_number(cy.to_double()),
  )
  let transform = node.resolve_transform(AId::GradientTransform, state)
  let gradient : RadialGradient = {
    uid: gen_uid(),
    cx,
    cy,
    r: PositiveF32::new(r).unwrap(),
    fx,
    fy,
    fr: PositiveF32::new(fr).unwrap_or(PositiveF32::zero()),
    base: { id, units, transform, spread_method, stops },
  }
  Some(Server(RadialGradient(gradient)))
}

///|
fn convert_pattern(node : SvgNode, state : State, cache : Cache) -> ServerOrColor? {
  let node_with_children = find_pattern_with_children(node)?
  let id = NonEmptyString::new(node.element_id())?
  let view_box = {
    let n1 = resolve_attr(node, AId::ViewBox)
    let n2 = resolve_attr(node, AId::PreserveAspectRatio)
    n1
    .parse_viewbox()
    .map(vb => ({
      rect: vb,
      aspect: n2
        .attribute(AId::PreserveAspectRatio)
        .unwrap_or(@svgtypes.AspectRatio::default()),
    } : ViewBox))
  }
  let units = convert_units(node, AId::PatternUnits, ObjectBoundingBox)
  let content_units = convert_units(node, AId::PatternContentUnits, UserSpaceOnUse)
  let transform = node.resolve_transform(AId::PatternTransform, state)
  let rect = NonZeroRect::from_xywh(
    resolve_number(node, AId::X, units, state, @svgtypes.Length::zero()),
    resolve_number(node, AId::Y, units, state, @svgtypes.Length::zero()),
    resolve_number(node, AId::Width, units, state, @svgtypes.Length::zero()),
    resolve_number(node, AId::Height, units, state, @svgtypes.Length::zero()),
  )
  // Upstream warns: Pattern '{}' has an invalid size. Skipped.
  let rect = rect?
  let patt : Pattern = {
    uid: gen_uid(),
    id,
    units,
    content_units,
    transform,
    rect,
    view_box,
    root: Group::empty(),
  }

  // We can apply viewbox transform only for user space coordinates.
  // Otherwise we need a bounding box, which is unknown at this point.
  if patt.view_box is Some(_) &&
    patt.units == UserSpaceOnUse &&
    patt.content_units == UserSpaceOnUse {
    let g = Group::empty()
    g.transform = view_box.unwrap().to_transform(rect.size())
    g.abs_transform = g.transform
    convert_children(node_with_children, state, cache, g)
    if !g.has_children() {
      return None
    }
    g.calculate_bounding_boxes() |> ignore
    patt.root.children.push(Group(g))
  } else {
    convert_children(node_with_children, state, cache, patt.root)
    if !patt.root.has_children() {
      return None
    }
  }
  patt.root.calculate_bounding_boxes() |> ignore
  Some(Server(Pattern(patt)))
}

///|
fn convert_spread_method(node : SvgNode) -> SpreadMethod {
  let node = resolve_attr(node, AId::SpreadMethod)
  node.attribute(AId::SpreadMethod).unwrap_or(SpreadMethod::default())
}

///|
fn convert_units(node : SvgNode, name : AId, def : Units) -> Units {
  let node = resolve_attr(node, name)
  node.attribute(name).unwrap_or(def)
}

///|
fn find_gradient_with_stops(node : SvgNode) -> SvgNode? {
  for link in node.href_iter() {
    if !link.tag_name().unwrap().is_gradient() {
      // Upstream warns: Gradient '{}' cannot reference '{}' via 'xlink:href'.
      return None
    }
    if link.children().any(n => n.tag_name() == Some(EId::Stop)) {
      return Some(link)
    }
  }
  None
}

///|
fn find_pattern_with_children(node : SvgNode) -> SvgNode? {
  for link in node.href_iter() {
    if link.tag_name() != Some(EId::Pattern) {
      // Upstream warns: Pattern '{}' cannot reference '{}' via 'xlink:href'.
      return None
    }
    if link.has_children() {
      return Some(link)
    }
  }
  None
}

///|
fn convert_stops(grad : SvgNode) -> Array[Stop] {
  let stops : Array[Stop] = []
  {
    let mut prev_offset = @svgtypes.Length::zero()
    for stop in grad.children() {
      if stop.tag_name() != Some(EId::Stop) {
        // Upstream warns: Invalid gradient child.
        continue
      }

      // `number` can be either a number or a percentage.
      let offset : @svgtypes.Length = stop
        .attribute(AId::Offset)
        .unwrap_or(prev_offset)
      let offset = match offset.unit {
        None => offset.number
        Percent => offset.number / 100.0
        _ => prev_offset.number
      }
      prev_offset = @svgtypes.Length::new_number(offset)
      let offset = f32_bound(0.0, offset.to_float(), 1.0)
      let stop_color : String? = stop.attribute(AId::StopColor)
      let (color, opacity) = split_alpha(
        match stop_color {
          Some("currentColor") =>
            stop
            .find_attribute(AId::Color)
            .unwrap_or(@svgtypes.Color::black())
          Some(value) =>
            match (try? @svgtypes.Color::from_str(value)) {
              Ok(c) => c
              Err(_) =>
                // Upstream warns: Failed to parse stop-color value.
                @svgtypes.Color::black()
            }
          _ => @svgtypes.Color::black()
        },
      )
      let stop_opacity : Opacity = stop
        .attribute(AId::StopOpacity)
        .unwrap_or(Opacity::one())
      stops.push({
        offset: StopOffset::new_clamped(offset),
        color,
        opacity: opacity * stop_opacity,
      })
    }
  }

  // Remove stops with equal offset.
  //
  // Example:
  // offset="0.5"
  // offset="0.7"
  // offset="0.7" <-- this one should be removed
  // offset="0.7"
  // offset="0.9"
  if stops.length() >= 3 {
    let mut i = 0
    while i < stops.length() - 2 {
      let offset1 = stops[i + 0].offset.get()
      let offset2 = stops[i + 1].offset.get()
      let offset3 = stops[i + 2].offset.get()
      if approx_eq_ulps(offset1, offset2, 4) && approx_eq_ulps(offset2, offset3, 4) {
        // Remove offset in the middle.
        stops.remove(i + 1) |> ignore
      } else {
        i += 1
      }
    }
  }

  // Remove zeros.
  //
  // From:
  // offset="0.0"
  // offset="0.0"
  // offset="0.7"
  //
  // To:
  // offset="0.0"
  // offset="0.00000001"
  // offset="0.7"
  if stops.length() >= 2 {
    let mut i = 0
    while i < stops.length() - 1 {
      let offset1 = stops[i + 0].offset.get()
      let offset2 = stops[i + 1].offset.get()
      if approx_eq_ulps(offset1, 0.0, 4) && approx_eq_ulps(offset2, 0.0, 4) {
        stops[i + 1] = {
          ..stops[i + 1],
          offset: StopOffset::new_clamped(offset1 + f32_epsilon),
        }
      }
      i += 1
    }
  }

  // Shift equal offsets.
  //
  // From:
  // offset="0.5"
  // offset="0.7"
  // offset="0.7"
  //
  // To:
  // offset="0.5"
  // offset="0.699999999"
  // offset="0.7"
  {
    let mut i = 1
    while i < stops.length() {
      let offset1 = stops[i - 1].offset.get()
      let offset2 = stops[i - 0].offset.get()

      // Next offset must be smaller then previous.
      if offset1 > offset2 || approx_eq_ulps(offset1, offset2, 4) {
        // Make previous offset a bit smaller.
        let new_offset = offset1 - f32_epsilon
        stops[i - 1] = {
          ..stops[i - 1],
          offset: StopOffset::new_clamped(new_offset),
        }
        stops[i - 0] = {
          ..stops[i - 0],
          offset: StopOffset::new_clamped(offset1),
        }
      }
      i += 1
    }
  }
  stops
}

///|
/// `f32::EPSILON`.
let f32_epsilon : Float = Float::reinterpret_from_uint(0x34000000U)

///|
fn resolve_number(
  node : SvgNode,
  name : AId,
  units : Units,
  state : State,
  def : @svgtypes.Length,
) -> Float {
  resolve_attr(node, name).convert_length(name, units, state, def)
}

///|
fn resolve_attr(node : SvgNode, name : AId) -> SvgNode {
  if node.has_attribute(name) {
    return node
  }
  match node.tag_name().unwrap() {
    EId::LinearGradient => resolve_lg_attr(node, name)
    EId::RadialGradient => resolve_rg_attr(node, name)
    EId::Pattern => resolve_pattern_attr(node, name)
    EId::Filter => resolve_filter_attr(node, name)
    _ => node
  }
}

///|
fn resolve_lg_attr(node : SvgNode, name : AId) -> SvgNode {
  for link in node.href_iter() {
    let tag_name = match link.tag_name() {
      Some(v) => v
      None => return node
    }
    match (name, tag_name) {
      // Coordinates can be resolved only from
      // ref element with the same type.
      (AId::X1, EId::LinearGradient)
      | (AId::Y1, EId::LinearGradient)
      | (AId::X2, EId::LinearGradient)
      | (AId::Y2, EId::LinearGradient)
      // Other attributes can be resolved
      // from any kind of gradient.
      | (AId::GradientUnits, EId::LinearGradient)
      | (AId::GradientUnits, EId::RadialGradient)
      | (AId::SpreadMethod, EId::LinearGradient)
      | (AId::SpreadMethod, EId::RadialGradient)
      | (AId::GradientTransform, EId::LinearGradient)
      | (AId::GradientTransform, EId::RadialGradient) =>
        if link.has_attribute(name) {
          return link
        }
      _ => break
    }
  }
  node
}

///|
fn resolve_rg_attr(node : SvgNode, name : AId) -> SvgNode {
  for link in node.href_iter() {
    let tag_name = match link.tag_name() {
      Some(v) => v
      None => return node
    }
    match (name, tag_name) {
      // Coordinates can be resolved only from
      // ref element with the same type.
      (AId::Cx, EId::RadialGradient)
      | (AId::Cy, EId::RadialGradient)
      | (AId::R, EId::RadialGradient)
      | (AId::Fx, EId::RadialGradient)
      | (AId::Fy, EId::RadialGradient)
      // Other attributes can be resolved
      // from any kind of gradient.
      | (AId::GradientUnits, EId::LinearGradient)
      | (AId::GradientUnits, EId::RadialGradient)
      | (AId::SpreadMethod, EId::LinearGradient)
      | (AId::SpreadMethod, EId::RadialGradient)
      | (AId::GradientTransform, EId::LinearGradient)
      | (AId::GradientTransform, EId::RadialGradient) =>
        if link.has_attribute(name) {
          return link
        }
      _ => break
    }
  }
  node
}

///|
fn resolve_pattern_attr(node : SvgNode, name : AId) -> SvgNode {
  for link in node.href_iter() {
    let tag_name = match link.tag_name() {
      Some(v) => v
      None => return node
    }
    if tag_name != EId::Pattern {
      break
    }
    if link.has_attribute(name) {
      return link
    }
  }
  node
}

///|
fn resolve_filter_attr(node : SvgNode, aid : AId) -> SvgNode {
  for link in node.href_iter() {
    let tag_name = match link.tag_name() {
      Some(v) => v
      None => return node
    }
    if tag_name != EId::Filter {
      break
    }
    if link.has_attribute(aid) {
      return link
    }
  }
  node
}

///|
fn stops_to_color(stops : Array[Stop]) -> ServerOrColor? {
  if stops.is_empty() {
    None
  } else {
    Some(ServerColor(color=stops[0].color, opacity=stops[0].opacity))
  }
}

///|
/// A place holding a paint (upstream's `&mut Paint`): writes go straight to
/// the tree, so that reference counts observe them immediately.
priv struct PaintSlot {
  get : () -> Paint
  set : (Paint) -> Unit
}

///|
/// A place holding an optional fill (upstream's `&mut Option<Fill>`).
priv struct FillSlot {
  get : () -> Fill?
  set : (Fill?) -> Unit
}

///|
/// A place holding an optional stroke (upstream's `&mut Option<Stroke>`).
priv struct StrokeSlot {
  get : () -> Stroke?
  set : (Stroke?) -> Unit
}

///|
fn Path::fill_slot(self : Path) -> FillSlot {
  { get: () => self.fill, set: f => self.fill = f }
}

///|
fn Path::stroke_slot(self : Path) -> StrokeSlot {
  { get: () => self.stroke, set: s => self.stroke = s }
}

///|
// Update paints servers by doing the following:
// 1. Replace context fills/strokes that are linked to
// a use node with their actual values.
// 2. Convert all object units to UserSpaceOnUse
fn update_paint_servers(
  group : Group,
  context_transform : Transform,
  context_bbox : Rect?,
  text_bbox : Rect?,
  cache : Cache,
) -> Unit {
  for child in group.children {
    // Set context transform and bbox if applicable if the
    // current group is a use node.
    let (context_transform, context_bbox) = if group.is_context_element {
      (group.abs_transform, Some(group.bounding_box))
    } else {
      (context_transform, context_bbox)
    }
    node_to_user_coordinates(
      child, context_transform, context_bbox, text_bbox, cache,
    )
  }
}

///|
// When parsing clipPaths, masks and filters we already know group's bounding box.
// But with gradients and patterns we don't, because we have to know text bounding box
// before we even parsed it. Which is impossible.
// Therefore our only choice is to parse gradients and patterns preserving their units
// and then replace them with `userSpaceOnUse` after the whole tree parsing is finished.
// So while gradients and patterns do still store their units,
// they are not exposed in the public API and for the caller they are always `userSpaceOnUse`.
fn node_to_user_coordinates(
  node : Node,
  context_transform : Transform,
  context_bbox : Rect?,
  text_bbox : Rect?,
  cache : Cache,
) -> Unit {
  match node {
    Group(g) => {
      // No need to check clip paths, because they cannot have paint servers.
      if g.mask is Some(mask) {
        if cache.is_unique(mask.uid) {
          update_paint_servers(
            mask.root, context_transform, context_bbox, None, cache,
          )
          if mask.mask is Some(sub_mask) {
            if cache.is_unique(sub_mask.uid) {
              update_paint_servers(
                sub_mask.root, context_transform, context_bbox, None, cache,
              )
            }
          }
        }
      }
      for filter in g.filters {
        if cache.is_unique(filter.uid) {
          for primitive in filter.primitives {
            if primitive.kind is Image(image) {
              update_paint_servers(
                image.root, context_transform, context_bbox, None, cache,
              )
            }
          }
        }
      }
      update_paint_servers(g, context_transform, context_bbox, text_bbox, cache)
    }
    Path(path) => {
      // Paths inside `Text::flattened` are special and must use text's bounding box
      // instead of their own.
      let bbox = text_bbox.unwrap_or(path.bounding_box)
      process_fill(
        path.fill_slot(),
        path.abs_transform,
        context_transform,
        context_bbox,
        bbox,
        cache,
      )
      process_stroke(
        path.stroke_slot(),
        path.abs_transform,
        context_transform,
        context_bbox,
        bbox,
        cache,
      )
    }
    Image(image) =>
      if image.kind is SVG(tree) {
        update_paint_servers(
          tree.root, context_transform, context_bbox, None, cache,
        )
      }
    Text(text) => {
      // By the SVG spec, `tspan` doesn't have a bbox and uses the parent `text` bbox.
      // Therefore we have to use text's bbox when converting tspan and flatted text
      // paint servers.
      let bbox = text.bounding_box

      // We need to update three things:
      // 1. The fills/strokes of the original elements in the usvg tree.
      // 2. The fills/strokes of the layouted elements of the text.
      // 3. The fills/strokes of the outlined text.

      // 1.
      for chunk in text.chunks {
        for span in chunk.spans {
          process_fill(
            { get: () => span.fill, set: f => span.fill = f },
            text.abs_transform,
            context_transform,
            context_bbox,
            bbox,
            cache,
          )
          process_stroke(
            { get: () => span.stroke, set: s => span.stroke = s },
            text.abs_transform,
            context_transform,
            context_bbox,
            bbox,
            cache,
          )
          process_text_decoration(
            () => span.decoration.underline,
            s => span.decoration.underline = s,
            bbox,
            cache,
          )
          process_text_decoration(
            () => span.decoration.overline,
            s => span.decoration.overline = s,
            bbox,
            cache,
          )
          process_text_decoration(
            () => span.decoration.line_through,
            s => span.decoration.line_through = s,
            bbox,
            cache,
          )
        }
      }

      // 2.
      for span in text.layouted {
        process_fill(
          { get: () => span.fill, set: f => span.fill = f },
          text.abs_transform,
          context_transform,
          context_bbox,
          bbox,
          cache,
        )
        process_stroke(
          { get: () => span.stroke, set: s => span.stroke = s },
          text.abs_transform,
          context_transform,
          context_bbox,
          bbox,
          cache,
        )
        let process_decoration = (path : Path) => {
          process_fill(
            path.fill_slot(),
            text.abs_transform,
            context_transform,
            context_bbox,
            bbox,
            cache,
          )
          process_stroke(
            path.stroke_slot(),
            text.abs_transform,
            context_transform,
            context_bbox,
            bbox,
            cache,
          )
        }
        if span.overline is Some(path) {
          process_decoration(path)
        }
        if span.underline is Some(path) {
          process_decoration(path)
        }
        if span.line_through is Some(path) {
          process_decoration(path)
        }
      }

      // 3.
      update_paint_servers(
        text.flattened,
        context_transform,
        context_bbox,
        Some(bbox),
        cache,
      )
    }
  }
}

///|
fn process_fill(
  fill : FillSlot,
  path_transform : Transform,
  context_transform : Transform,
  context_bbox : Rect?,
  bbox : Rect,
  cache : Cache,
) -> Unit {
  let mut ok = false
  if fill.get() is Some(f) {
    // Path context elements (i.e. for  markers) have already been resolved,
    // so we only care about use nodes.
    let slot : PaintSlot = {
      get: () => fill.get().unwrap().paint,
      set: p => fill.set(Some({ ..fill.get().unwrap(), paint: p })),
    }
    ok = process_paint(
      slot,
      f.context_element is Some(UseNode),
      context_transform,
      context_bbox,
      path_transform,
      bbox,
      cache,
    )
  }
  if !ok {
    fill.set(None)
  }
}

///|
fn process_stroke(
  stroke : StrokeSlot,
  path_transform : Transform,
  context_transform : Transform,
  context_bbox : Rect?,
  bbox : Rect,
  cache : Cache,
) -> Unit {
  let mut ok = false
  if stroke.get() is Some(s) {
    // Path context elements (i.e. for  markers) have already been resolved,
    // so we only care about use nodes.
    let slot : PaintSlot = {
      get: () => stroke.get().unwrap().paint,
      set: p => stroke.set(Some({ ..stroke.get().unwrap(), paint: p })),
    }
    ok = process_paint(
      slot,
      s.context_element is Some(UseNode),
      context_transform,
      context_bbox,
      path_transform,
      bbox,
      cache,
    )
  }
  if !ok {
    stroke.set(None)
  }
}

///|
fn process_context_paint(
  paint : PaintSlot,
  context_transform : Transform,
  path_transform : Transform,
  cache : Cache,
) -> Unit? {
  // The idea is the following: We have a certain context element that has
  // a transform A, and further below in the tree we have for example a path
  // whose paint has a transform C. In order to get from A to C, there is some
  // transformation matrix B such that A x B = C. We now need to figure out
  // a way to get from C back to A, so that the transformation of the paint
  // matches the one from the context element, even if B was applied. How
  // do we do that? We calculate CxB^(-1), which will overall then have
  // the same effect as A. How do we calculate B^(-1)?
  // --> (A^(-1)xC)^(-1)
  let rev_transform = context_transform
    .invert()?
    .pre_concat(path_transform)
    .invert()?
  match paint.get() {
    Color(_) => ()
    LinearGradient(lg) => {
      let transform = lg.base.transform.post_concat(rev_transform)
      paint.set(
        LinearGradient({
          uid: gen_uid(),
          x1: lg.x1,
          y1: lg.y1,
          x2: lg.x2,
          y2: lg.y2,
          base: {
            id: cache.gen_linear_gradient_id(),
            units: lg.base.units,
            transform,
            spread_method: lg.base.spread_method,
            stops: lg.base.stops.copy(),
          },
        }),
      )
    }
    RadialGradient(rg) => {
      let transform = rg.base.transform.post_concat(rev_transform)
      paint.set(
        RadialGradient({
          uid: gen_uid(),
          cx: rg.cx,
          cy: rg.cy,
          r: rg.r,
          fx: rg.fx,
          fy: rg.fy,
          fr: rg.fr,
          base: {
            id: cache.gen_radial_gradient_id(),
            units: rg.base.units,
            transform,
            spread_method: rg.base.spread_method,
            stops: rg.base.stops.copy(),
          },
        }),
      )
    }
    Pattern(pat) => {
      let transform = pat.transform.post_concat(rev_transform)
      paint.set(
        Pattern({
          uid: gen_uid(),
          id: cache.gen_pattern_id(),
          units: pat.units,
          content_units: pat.content_units,
          transform,
          rect: pat.rect,
          view_box: pat.view_box,
          root: pat.root.clone(),
        }),
      )
    }
  }
  Some(())
}

///|
fn process_paint(
  paint : PaintSlot,
  has_context : Bool,
  context_transform : Transform,
  context_bbox : Rect?,
  path_transform : Transform,
  bbox : Rect,
  cache : Cache,
) -> Bool {
  let mut replaced = false
  if paint.get().units() == ObjectBoundingBox ||
    paint.get().content_units() == ObjectBoundingBox {
    let bbox = if has_context {
      guard context_bbox is Some(bbox) else { return false }
      bbox
    } else {
      bbox
    }
    match paint_to_user_coordinates(paint, bbox, cache) {
      Some(r) => replaced = r
      None => return false
    }
  }
  if paint.get() is Pattern(patt) {
    if replaced || cache.is_unique(patt.uid) {
      update_paint_servers(patt.root, Transform::default(), None, None, cache)
    }
  }
  if has_context {
    process_context_paint(paint, context_transform, path_transform, cache)
    |> ignore
  }
  true
}

///|
fn process_text_decoration(
  get : () -> TextDecorationStyle?,
  set : (TextDecorationStyle?) -> Unit,
  bbox : Rect,
  cache : Cache,
) -> Unit {
  if get() is Some(_) {
    process_fill(
      {
        get: () => get().unwrap().fill,
        set: f => set(Some({ ..get().unwrap(), fill: f })),
      },
      Transform::default(),
      Transform::default(),
      None,
      bbox,
      cache,
    )
    process_stroke(
      {
        get: () => get().unwrap().stroke,
        set: s => set(Some({ ..get().unwrap(), stroke: s })),
      },
      Transform::default(),
      Transform::default(),
      None,
      bbox,
      cache,
    )
  }
}

///|
/// `Paint::to_user_coordinates`. Returns whether a new object replaced the
/// paint (`Some(false)` if it was modified in place).
fn paint_to_user_coordinates(
  paint : PaintSlot,
  bbox : Rect,
  cache : Cache,
) -> Bool? {
  // Upstream warns: {} on zero-sized shapes is not allowed.
  let bbox = bbox.to_non_zero_rect()?

  // `Arc::get_mut()` allow us to modify some paint servers in-place.
  // This reduces the amount of cloning and preserves the original ID as well.
  match paint.get() {
    Color(_) => Some(false) // unreachable
    LinearGradient(lg) => {
      let transform = lg.base.transform.post_concat(Transform::from_bbox(bbox))
      if cache.is_unique(lg.uid) {
        lg.base.transform = transform
        lg.base.units = UserSpaceOnUse
        Some(false)
      } else {
        paint.set(
          LinearGradient({
            uid: gen_uid(),
            x1: lg.x1,
            y1: lg.y1,
            x2: lg.x2,
            y2: lg.y2,
            base: {
              id: cache.gen_linear_gradient_id(),
              units: UserSpaceOnUse,
              transform,
              spread_method: lg.base.spread_method,
              stops: lg.base.stops.copy(),
            },
          }),
        )
        Some(true)
      }
    }
    RadialGradient(rg) => {
      let transform = rg.base.transform.post_concat(Transform::from_bbox(bbox))
      if cache.is_unique(rg.uid) {
        rg.base.transform = transform
        rg.base.units = UserSpaceOnUse
        Some(false)
      } else {
        paint.set(
          RadialGradient({
            uid: gen_uid(),
            cx: rg.cx,
            cy: rg.cy,
            r: rg.r,
            fx: rg.fx,
            fy: rg.fy,
            fr: rg.fr,
            base: {
              id: cache.gen_radial_gradient_id(),
              units: UserSpaceOnUse,
              transform,
              spread_method: rg.base.spread_method,
              stops: rg.base.stops.copy(),
            },
          }),
        )
        Some(true)
      }
    }
    Pattern(patt) => {
      let rect = if patt.units == ObjectBoundingBox {
        patt.rect.bbox_transform(bbox)
      } else {
        patt.rect
      }
      if cache.is_unique(patt.uid) {
        patt.rect = rect
        patt.units = UserSpaceOnUse
        if patt.content_units == ObjectBoundingBox && patt.view_box is None {
          // No need to shift patterns.
          let transform = Transform::from_scale(bbox.width(), bbox.height())
          push_pattern_transform(patt, transform)
        }
        if patt.view_box is Some(view_box) {
          push_pattern_transform(patt, view_box.to_transform(rect.size()))
        }
        patt.content_units = UserSpaceOnUse
        Some(false)
      } else {
        let new_patt : Pattern = {
          uid: gen_uid(),
          id: cache.gen_pattern_id(),
          units: UserSpaceOnUse,
          content_units: UserSpaceOnUse,
          transform: patt.transform,
          rect,
          view_box: patt.view_box,
          root: patt.root.clone(),
        }
        if patt.content_units == ObjectBoundingBox && patt.view_box is None {
          // No need to shift patterns.
          let transform = Transform::from_scale(bbox.width(), bbox.height())
          push_pattern_transform(new_patt, transform)
        }
        if patt.view_box is Some(view_box) {
          push_pattern_transform(new_patt, view_box.to_transform(rect.size()))
        }
        paint.set(Pattern(new_patt))
        Some(true)
      }
    }
  }
}

///|
fn push_pattern_transform(patt : Pattern, transform : Transform) -> Unit {
  // TODO: we should update abs_transform in all descendants as well
  let g = patt.root
  patt.root = Group::empty()
  g.transform = transform
  g.abs_transform = transform
  patt.root.children.push(Group(g))
  patt.root.calculate_bounding_boxes() |> ignore
}

///|
fn Paint::units(self : Paint) -> Units {
  match self {
    Color(_) => UserSpaceOnUse
    LinearGradient(lg) => lg.base.units
    RadialGradient(rg) => rg.base.units
    Pattern(patt) => patt.units
  }
}

///|
fn Paint::content_units(self : Paint) -> Units {
  match self {
    Pattern(patt) => patt.content_units
    _ => UserSpaceOnUse
  }
}

///|
/// Whether the object with the given `uid` would be uniquely referenced
/// (`Arc::get_mut` succeeds); see the file header.
fn Cache::is_unique(self : Cache, uid : Int) -> Bool {
  match self.ref_roots {
    None => false
    Some(roots) => {
      let counter = RefCounter::new()
      for root in roots {
        counter.group(root)
      }
      self.extra_ref_roots(counter)
      counter.counts.get(uid).unwrap_or(0) == 1
    }
  }
}

///|
/// Counts the references to shared objects (upstream's `Arc` strong counts).
priv struct RefCounter {
  counts : Map[Int, Int]
}

///|
fn RefCounter::new() -> RefCounter {
  { counts: {} }
}

///|
/// Counts a reference; returns whether the object is seen for the first
/// time (and its content must be visited).
fn RefCounter::hit(self : RefCounter, uid : Int) -> Bool {
  let n = self.counts.get(uid).unwrap_or(0)
  self.counts[uid] = n + 1
  n == 0
}

///|
fn RefCounter::paint(self : RefCounter, paint : Paint) -> Unit {
  match paint {
    Color(_) => ()
    LinearGradient(lg) => self.hit(lg.uid) |> ignore
    RadialGradient(rg) => self.hit(rg.uid) |> ignore
    Pattern(patt) => if self.hit(patt.uid) { self.group(patt.root) }
  }
}

///|
fn RefCounter::fill(self : RefCounter, fill : Fill?) -> Unit {
  if fill is Some(fill) {
    self.paint(fill.paint)
  }
}

///|
fn RefCounter::stroke(self : RefCounter, stroke : Stroke?) -> Unit {
  if stroke is Some(stroke) {
    self.paint(stroke.paint)
  }
}

///|
fn RefCounter::clip_path(self : RefCounter, clip : ClipPath) -> Unit {
  if self.hit(clip.uid) {
    if clip.clip_path is Some(sub) {
      self.clip_path(sub)
    }
    self.group(clip.root)
  }
}

///|
fn RefCounter::mask(self : RefCounter, mask : Mask) -> Unit {
  if self.hit(mask.uid) {
    if mask.mask is Some(sub) {
      self.mask(sub)
    }
    self.group(mask.root)
  }
}

///|
fn RefCounter::filter(self : RefCounter, filter : Filter) -> Unit {
  if self.hit(filter.uid) {
    for primitive in filter.primitives {
      if primitive.kind is Image(image) {
        self.group(image.root)
      }
    }
  }
}

///|
fn RefCounter::group(self : RefCounter, g : Group) -> Unit {
  if g.clip_path is Some(clip) {
    self.clip_path(clip)
  }
  if g.mask is Some(mask) {
    self.mask(mask)
  }
  for filter in g.filters {
    self.filter(filter)
  }
  for child in g.children {
    self.node(child)
  }
}

///|
fn RefCounter::tree(self : RefCounter, tree : Tree) -> Unit {
  self.group(tree.root)
  for lg in tree.linear_gradients {
    self.paint(LinearGradient(lg))
  }
  for rg in tree.radial_gradients {
    self.paint(RadialGradient(rg))
  }
  for patt in tree.patterns {
    self.paint(Pattern(patt))
  }
  for clip in tree.clip_paths {
    self.clip_path(clip)
  }
  for mask in tree.masks {
    self.mask(mask)
  }
  for filter in tree.filters {
    self.filter(filter)
  }
}

///|
fn RefCounter::node(self : RefCounter, node : Node) -> Unit {
  match node {
    Group(g) => self.group(g)
    Path(p) => {
      self.fill(p.fill)
      self.stroke(p.stroke)
    }
    Image(image) => if image.kind is SVG(tree) { self.tree(tree) }
    Text(text) => self.text(text)
  }
}
