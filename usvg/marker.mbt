// Port of `usvg` 0.47.0 `src/parser/marker.rs`.

///|
// Similar to `tiny_skia_path::PathSegment`, but without the `QuadTo`.
priv enum Segment {
  MoveTo(@tiny_skia_path.Point)
  LineTo(@tiny_skia_path.Point)
  CubicTo(@tiny_skia_path.Point, @tiny_skia_path.Point, @tiny_skia_path.Point)
  Close
}

///|
fn marker_is_valid(node : SvgNode) -> Bool {
  // `marker-*` attributes cannot be set on shapes inside a `clipPath`.
  if node.ancestors().any(n => n.tag_name() == Some(EId::ClipPath)) {
    return false
  }
  let start : SvgNode? = node.find_attribute(AId::MarkerStart)
  let mid : SvgNode? = node.find_attribute(AId::MarkerMid)
  let end : SvgNode? = node.find_attribute(AId::MarkerEnd)
  start is Some(_) || mid is Some(_) || end is Some(_)
}

///|
fn marker_convert(
  node : SvgNode,
  path : TinyPath,
  state : State,
  cache : Cache,
  parent : Group,
) -> Unit {
  let list = [
    (AId::MarkerStart, KindStart),
    (AId::MarkerMid, KindMiddle),
    (AId::MarkerEnd, KindEnd),
  ]
  for item in list {
    let (aid, kind) = item
    let mut marker = None
    let link : SvgNode? = node.find_attribute(aid)
    if link is Some(link) {
      if link.tag_name() == Some(EId::Marker) {
        marker = Some(link)
      }
    }
    if marker is Some(marker) {
      // TODO: move to svgtree
      // Check for recursive marker.
      if state.parent_markers.contains(marker) {
        // Upstream warns: Recursive marker detected.
        continue
      }
      resolve_marker(node, path, marker, kind, state, cache, parent) |> ignore
    }
  }
}

///|
priv enum MarkerKind {
  KindStart
  KindMiddle
  KindEnd
}

///|
priv enum MarkerOrientation {
  Auto
  AutoStartReverse
  Angle(Float)
}

///|
fn resolve_marker(
  shape_node : SvgNode,
  path : TinyPath,
  marker_node : SvgNode,
  marker_kind : MarkerKind,
  state : State,
  cache : Cache,
  parent : Group,
) -> Unit? {
  guard stroke_scale(shape_node, marker_node, state) is Some(stroke_scale) else {
    return None
  }
  let stroke_scale = stroke_scale.get()
  guard convert_marker_rect(marker_node, state) is Some(r) else { return None }
  let view_box = marker_node
    .parse_viewbox()
    .map(vb => {
      (
        {
          rect: vb,
          aspect: marker_node
          .attribute(AId::PreserveAspectRatio)
          .unwrap_or(@svgtypes.AspectRatio::default()),
        } : ViewBox)
    })
  let has_overflow = {
    let overflow : String? = marker_node.attribute(AId::Overflow)
    // `overflow` is `hidden` by default.
    overflow is None || overflow == Some("hidden") || overflow == Some("scroll")
  }
  let clip_path = if has_overflow {
    let clip_rect = if view_box is Some(vbox) {
      vbox.rect
    } else {
      r.size().to_non_zero_rect(0.0, 0.0)
    }
    let clip_path = ClipPath::empty(cache.gen_clip_path_id())
    guard Path::new_simple(
        @tiny_skia_path.PathBuilder::from_rect(clip_rect.to_rect()),
      )
      is Some(path) else {
      return None
    }
    path.fill = Some(Fill::default())
    clip_path.root.children.push(Path(path))
    Some(clip_path)
  } else {
    None
  }

  // TODO: avoid allocation
  let segments : Array[Segment] = []
  let mut prev = @tiny_skia_path.Point::zero()
  let mut prev_move = @tiny_skia_path.Point::zero()
  let iter = path.segments()
  while iter.next() is Some(seg) {
    match seg {
      MoveTo(p) => {
        segments.push(MoveTo(p))
        prev = p
        prev_move = p
      }
      LineTo(p) => {
        segments.push(LineTo(p))
        prev = p
      }
      QuadTo(p1, p) => {
        let (p1, p2, p) = quad_to_curve(prev, p1, p)
        segments.push(CubicTo(p1, p2, p))
        prev = p
      }
      CubicTo(p1, p2, p) => {
        segments.push(CubicTo(p1, p2, p))
        prev = p
      }
      Close => {
        segments.push(Close)
        prev = prev_move
      }
    }
  }
  let draw_marker = (p : @tiny_skia_path.Point, idx : Int) => {
    let mut ts = Transform::from_translate(p.x, p.y)
    let angle = match convert_orientation(marker_node) {
      AutoStartReverse if idx == 0 =>
        rem_f32(calc_vertex_angle(segments, idx) + 180.0, 360.0)
      Auto | AutoStartReverse => calc_vertex_angle(segments, idx)
      Angle(angle) => angle
    }
    if !approx_zero_ulps(angle, 4) {
      ts = ts.pre_rotate(angle)
    }
    if view_box is Some(vbox) {
      let size = Size::from_wh(
        r.width() * stroke_scale,
        r.height() * stroke_scale,
      ).unwrap()
      let vbox_ts = vbox.to_transform(size)
      let (sx, sy) = vbox_ts.get_scale()
      ts = ts.pre_scale(sx, sy)
    } else {
      ts = ts.pre_scale(stroke_scale, stroke_scale)
    }
    ts = ts.pre_translate(-r.x(), -r.y())

    // TODO: do not create a group when no clipPath
    let g = {
      ..Group::empty(),
      transform: ts,
      abs_transform: parent.abs_transform.pre_concat(ts),
      clip_path,
    }
    let marker_state = {
      ..state,
      parent_markers: [..state.parent_markers, marker_node],
    }
    convert_children(marker_node, marker_state, cache, g)
    g.calculate_bounding_boxes() |> ignore
    if g.has_children() {
      parent.children.push(Group(g))
    }
  }
  draw_markers(segments, marker_kind, draw_marker)
  Some(())
}

///|
fn stroke_scale(
  path_node : SvgNode,
  marker_node : SvgNode,
  state : State,
) -> NonZeroPositiveF32? {
  let units : String? = marker_node.attribute(AId::MarkerUnits)
  match units {
    Some("userSpaceOnUse") => NonZeroPositiveF32::new(1.0)
    _ => path_node.resolve_valid_length(AId::StrokeWidth, state, 1.0)
  }
}

///|
fn draw_markers(
  path : Array[Segment],
  kind : MarkerKind,
  draw_marker : (@tiny_skia_path.Point, Int) -> Unit,
) -> Unit {
  match kind {
    KindStart => if path.get(0) is Some(MoveTo(p)) { draw_marker(p, 0) }
    KindMiddle => {
      let total = path.length() - 1
      let mut i = 1
      while i < total {
        let p = match path[i] {
          MoveTo(p) => p
          LineTo(p) => p
          CubicTo(_, _, p) => p
          _ => {
            i += 1
            continue
          }
        }
        draw_marker(p, i)
        i += 1
      }
    }
    KindEnd => {
      let idx = path.length() - 1
      match path.last() {
        Some(LineTo(p)) => draw_marker(p, idx)
        Some(CubicTo(_, _, p)) => draw_marker(p, idx)
        Some(Close) => {
          let p = get_subpath_start(path, idx)
          draw_marker(p, idx)
        }
        _ => ()
      }
    }
  }
}

///|
fn calc_vertex_angle(path : Array[Segment], idx : Int) -> Float {
  if idx == 0 {
    // First segment.

    let seg1 = path[0]
    let seg2 = path[1]
    match (seg1, seg2) {
      (MoveTo(pm), LineTo(p)) => calc_line_angle(pm.x, pm.y, p.x, p.y)
      (MoveTo(pm), CubicTo(p1, _, p)) =>
        if approx_eq_ulps(pm.x, p1.x, 4) && approx_eq_ulps(pm.y, p1.y, 4) {
          calc_line_angle(pm.x, pm.y, p.x, p.y)
        } else {
          calc_line_angle(pm.x, pm.y, p1.x, p1.y)
        }
      _ => 0.0
    }
  } else if idx == path.length() - 1 {
    // Last segment.

    let seg1 = path[idx - 1]
    let seg2 = path[idx]
    match (seg1, seg2) {
      (_, MoveTo(_)) => 0.0 // unreachable
      (_, LineTo(p)) => {
        let prev = get_prev_vertex(path, idx)
        calc_line_angle(prev.x, prev.y, p.x, p.y)
      }
      (_, CubicTo(p1, p2, p)) =>
        if approx_eq_ulps(p2.x, p.x, 4) && approx_eq_ulps(p2.y, p.y, 4) {
          calc_line_angle(p1.x, p1.y, p.x, p.y)
        } else {
          calc_line_angle(p2.x, p2.y, p.x, p.y)
        }
      (LineTo(p), Close) => {
        let next = get_subpath_start(path, idx)
        calc_line_angle(p.x, p.y, next.x, next.y)
      }
      (CubicTo(_, p2, p), Close) => {
        let prev = get_prev_vertex(path, idx)
        let next = get_subpath_start(path, idx)
        calc_curves_angle(
          prev.x,
          prev.y,
          p2.x,
          p2.y,
          p.x,
          p.y,
          next.x,
          next.y,
          next.x,
          next.y,
        )
      }
      (_, Close) => 0.0
    }
  } else {
    // Middle segments.

    let seg1 = path[idx]
    let seg2 = path[idx + 1]

    // TODO: Not sure if there is a better way.
    match (seg1, seg2) {
      (MoveTo(pm), LineTo(p)) => calc_line_angle(pm.x, pm.y, p.x, p.y)
      (MoveTo(pm), CubicTo(p1, _, _)) => calc_line_angle(pm.x, pm.y, p1.x, p1.y)
      (LineTo(p1), LineTo(p2)) => {
        let prev = get_prev_vertex(path, idx)
        calc_angle(prev.x, prev.y, p1.x, p1.y, p1.x, p1.y, p2.x, p2.y)
      }
      (CubicTo(_, c1_p2, c1_p), CubicTo(c2_p1, _, c2_p)) => {
        let prev = get_prev_vertex(path, idx)
        calc_curves_angle(
          prev.x,
          prev.y,
          c1_p2.x,
          c1_p2.y,
          c1_p.x,
          c1_p.y,
          c2_p1.x,
          c2_p1.y,
          c2_p.x,
          c2_p.y,
        )
      }
      (LineTo(pl), CubicTo(p1, _, p)) => {
        let prev = get_prev_vertex(path, idx)
        calc_curves_angle(
          prev.x,
          prev.y,
          prev.x,
          prev.y,
          pl.x,
          pl.y,
          p1.x,
          p1.y,
          p.x,
          p.y,
        )
      }
      (CubicTo(_, p2, p), LineTo(pl)) => {
        let prev = get_prev_vertex(path, idx)
        calc_curves_angle(
          prev.x,
          prev.y,
          p2.x,
          p2.y,
          p.x,
          p.y,
          pl.x,
          pl.y,
          pl.x,
          pl.y,
        )
      }
      (LineTo(p), MoveTo(_)) => {
        let prev = get_prev_vertex(path, idx)
        calc_line_angle(prev.x, prev.y, p.x, p.y)
      }
      (CubicTo(_, p2, p), MoveTo(_)) =>
        if approx_eq_ulps(p.x, p2.x, 4) && approx_eq_ulps(p.y, p2.y, 4) {
          let prev = get_prev_vertex(path, idx)
          calc_line_angle(prev.x, prev.y, p.x, p.y)
        } else {
          calc_line_angle(p2.x, p2.y, p.x, p.y)
        }
      (LineTo(p), Close) => {
        let prev = get_prev_vertex(path, idx)
        let next = get_subpath_start(path, idx)
        calc_angle(prev.x, prev.y, p.x, p.y, p.x, p.y, next.x, next.y)
      }
      (_, Close) => {
        let prev = get_prev_vertex(path, idx)
        let next = get_subpath_start(path, idx)
        calc_line_angle(prev.x, prev.y, next.x, next.y)
      }
      (_, MoveTo(_)) | (Close, _) => 0.0
    }
  }
}

///|
fn calc_line_angle(x1 : Float, y1 : Float, x2 : Float, y2 : Float) -> Float {
  calc_angle(x1, y1, x2, y2, x1, y1, x2, y2)
}

///|
fn calc_curves_angle(
  px : Float,
  py : Float, // previous vertex
  cx1 : Float,
  cy1 : Float, // previous control point
  x : Float,
  y : Float, // current vertex
  cx2 : Float,
  cy2 : Float, // next control point
  nx : Float,
  ny : Float, // next vertex
) -> Float {
  if approx_eq_ulps(cx1, x, 4) && approx_eq_ulps(cy1, y, 4) {
    calc_angle(px, py, x, y, x, y, cx2, cy2)
  } else if approx_eq_ulps(x, cx2, 4) && approx_eq_ulps(y, cy2, 4) {
    calc_angle(cx1, cy1, x, y, x, y, nx, ny)
  } else {
    calc_angle(cx1, cy1, x, y, x, y, cx2, cy2)
  }
}

///|
/// `f32::consts::PI`.
let f32_pi : Float = Float::reinterpret_from_uint(0x40490FDBU)

///|
/// `f32::consts::FRAC_PI_2`.
let f32_frac_pi_2 : Float = Float::reinterpret_from_uint(0x3FC90FDBU)

///|
fn calc_angle(
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
  x3 : Float,
  y3 : Float,
  x4 : Float,
  y4 : Float,
) -> Float {
  fn normalize(rad : Float) -> Float {
    let v = rem_f32(rad, f32_pi * 2.0)
    if v < 0.0 {
      v + f32_pi * 2.0
    } else {
      v
    }
  }

  fn vector_angle(vx : Float, vy : Float) -> Float {
    let rad = libm_atan2f(vy, vx)
    if rad.is_nan() {
      0.0
    } else {
      normalize(rad)
    }
  }

  let in_a = vector_angle(x2 - x1, y2 - y1)
  let out_a = vector_angle(x4 - x3, y4 - y3)
  let d = (out_a - in_a) * 0.5
  let mut angle = in_a + d
  if f32_frac_pi_2 < d.abs() {
    angle -= f32_pi
  }
  to_degrees_f32(normalize(angle))
}

///|
fn get_subpath_start(
  segments : Array[Segment],
  idx : Int,
) -> @tiny_skia_path.Point {
  let offset = segments.length() - idx
  // `segments.iter().rev().skip(offset)`
  let mut i = segments.length() - 1 - offset
  while i >= 0 {
    if segments[i] is MoveTo(p) {
      return p
    }
    i -= 1
  }
  @tiny_skia_path.Point::zero()
}

///|
fn get_prev_vertex(
  segments : Array[Segment],
  idx : Int,
) -> @tiny_skia_path.Point {
  match segments[idx - 1] {
    MoveTo(p) => p
    LineTo(p) => p
    CubicTo(_, _, p) => p
    Close => get_subpath_start(segments, idx)
  }
}

///|
fn convert_marker_rect(node : SvgNode, state : State) -> NonZeroRect? {
  NonZeroRect::from_xywh(
    node.convert_user_length(AId::RefX, state, @svgtypes.Length::zero()),
    node.convert_user_length(AId::RefY, state, @svgtypes.Length::zero()),
    node.convert_user_length(
      AId::MarkerWidth,
      state,
      @svgtypes.Length::new_number(3.0),
    ),
    node.convert_user_length(
      AId::MarkerHeight,
      state,
      @svgtypes.Length::new_number(3.0),
    ),
  )
}

///|
fn convert_orientation(node : SvgNode) -> MarkerOrientation {
  let orient : String? = node.attribute(AId::Orient)
  match orient {
    Some("auto") => Auto
    Some("auto-start-reverse") => AutoStartReverse
    _ => {
      let angle : @svgtypes.Angle? = node.attribute(AId::Orient)
      match angle {
        Some(angle) => Angle(Float::from_double(angle.to_degrees()))
        None => Angle(0.0)
      }
    }
  }
}

///|
fn quad_to_curve(
  prev : @tiny_skia_path.Point,
  p1 : @tiny_skia_path.Point,
  p : @tiny_skia_path.Point,
) -> (@tiny_skia_path.Point, @tiny_skia_path.Point, @tiny_skia_path.Point) {
  fn calc(n1 : Float, n2 : Float) -> Float {
    (n1 + n2 * 2.0) / 3.0
  }

  (
    @tiny_skia_path.Point::from_xy(calc(prev.x, p1.x), calc(prev.y, p1.y)),
    @tiny_skia_path.Point::from_xy(calc(p.x, p1.x), calc(p.y, p1.y)),
    p,
  )
}
