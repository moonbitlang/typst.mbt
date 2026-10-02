// Port of `tiny-skia/src/edge_builder.rs`.

///|
enum Combine {
  No
  Partial
  Total
} derive(Eq)

///|
priv struct ShiftedIntRect {
  shifted : ScreenIntRect
  shift : Int
}

///|
fn ShiftedIntRect::new(rect : ScreenIntRect, shift : Int) -> ShiftedIntRect? {
  guard ScreenIntRect::from_xywh(
      rect.x().reinterpret_as_uint() << shift,
      rect.y().reinterpret_as_uint() << shift,
      rect.width().reinterpret_as_uint() << shift,
      rect.height().reinterpret_as_uint() << shift,
    )
    is Some(shifted) else {
    return None
  }
  Some({ shifted, shift, })
}

///|
fn ShiftedIntRect::recover(self : ShiftedIntRect) -> ScreenIntRect {
  ScreenIntRect::from_xywh(
    self.shifted.x().reinterpret_as_uint() >> self.shift,
    self.shifted.y().reinterpret_as_uint() >> self.shift,
    self.shifted.width().reinterpret_as_uint() >> self.shift,
    self.shifted.height().reinterpret_as_uint() >> self.shift,
  ).unwrap() // cannot fail, because the original rect was valid
}

///|
priv struct BasicEdgeBuilder {
  edges : Array[Edge]
  clip_shift : Int
}

///|
fn BasicEdgeBuilder::new(clip_shift : Int) -> BasicEdgeBuilder {
  { edges: Array(capacity=64), clip_shift, }
}

///|
/// Skia returns a linked list here, but it's a nightmare to use in Rust,
/// so we're mimicking it with Vec.
fn BasicEdgeBuilder::build_edges(
  path : @path.Path,
  clip : ShiftedIntRect?,
  clip_shift : Int,
) -> Array[Edge]? {
  // If we're convex, then we need both edges, even if the right edge is past
  // the clip.
  let can_cull_to_the_right = false // TODO: this
  let builder = BasicEdgeBuilder::new(clip_shift)
  if !builder.build(path, clip, can_cull_to_the_right) {
    // infinite or NaN segments detected during edges building
    return None
  }
  if builder.edges.length() < 2 {
    return None
  }
  Some(builder.edges)
}

///|
fn BasicEdgeBuilder::build(
  self : BasicEdgeBuilder,
  path : @path.Path,
  clip : ShiftedIntRect?,
  can_cull_to_the_right : Bool,
) -> Bool {
  match clip {
    Some(clip) => {
      let clip = clip.recover().to_rect()
      let iter = EdgeClipperIter::new(path, clip, can_cull_to_the_right)
      while iter.next() is Some(edges) {
        for edge in edges {
          match edge {
            LineTo(p0, p1) => {
              if !p0.is_finite() || !p1.is_finite() {
                return false
              }
              self.push_line(p0, p1)
            }
            QuadTo(p0, p1, p2) => {
              if !p0.is_finite() || !p1.is_finite() || !p2.is_finite() {
                return false
              }
              self.push_quad([p0, p1, p2][:])
            }
            CubicTo(p0, p1, p2, p3) => {
              if !p0.is_finite() ||
                !p1.is_finite() ||
                !p2.is_finite() ||
                !p3.is_finite() {
                return false
              }
              self.push_cubic([p0, p1, p2, p3][:])
            }
          }
        }
      }
    }
    None => {
      let iter = edge_iter(path)
      while iter.next() is Some(edge) {
        match edge {
          LineTo(p0, p1) => self.push_line(p0, p1)
          QuadTo(p0, p1, p2) => {
            let points = [p0, p1, p2]
            let mono_x = Array::make(5, @path.Point::zero())
            let n = chop_quad_at_y_extrema(points[:], mono_x)
            for i in 0..<=n {
              self.push_quad(mono_x[i * 2:])
            }
          }
          CubicTo(p0, p1, p2, p3) => {
            let points = [p0, p1, p2, p3]
            let mono_y = Array::make(10, @path.Point::zero())
            let n = chop_cubic_at_y_extrema(points[:], mono_y)
            for i in 0..<=n {
              self.push_cubic(mono_y[i * 3:])
            }
          }
        }
      }
    }
  }
  true
}

///|
fn BasicEdgeBuilder::push_line(
  self : BasicEdgeBuilder,
  p0 : @path.Point,
  p1 : @path.Point,
) -> Unit {
  if Edge::new_line(p0, p1, self.clip_shift) is Some(edge) {
    let combine = if edge.is_vertical() && !self.edges.is_empty() {
      let last = self.edges[self.edges.length() - 1]
      if last.kind == Line {
        combine_vertical(edge, last)
      } else {
        No
      }
    } else {
      No
    }
    match combine {
      Total => ignore(self.edges.pop())
      Partial => ()
      No => self.edges.push(edge)
    }
  }
}

///|
fn BasicEdgeBuilder::push_quad(
  self : BasicEdgeBuilder,
  points : ArrayView[@path.Point],
) -> Unit {
  if Edge::new_quadratic(points, self.clip_shift) is Some(edge) {
    self.edges.push(edge)
  }
}

///|
fn BasicEdgeBuilder::push_cubic(
  self : BasicEdgeBuilder,
  points : ArrayView[@path.Point],
) -> Unit {
  if Edge::new_cubic(points, self.clip_shift) is Some(edge) {
    self.edges.push(edge)
  }
}

///|
fn combine_vertical(edge : Edge, last : Edge) -> Combine {
  if last.dx != 0 || edge.x != last.x {
    return No
  }
  if edge.winding == last.winding {
    return if edge.last_y + 1 == last.first_y {
      last.first_y = edge.first_y
      Partial
    } else if edge.first_y == last.last_y + 1 {
      last.last_y = edge.last_y
      Partial
    } else {
      No
    }
  }
  if edge.first_y == last.first_y {
    return if edge.last_y == last.last_y {
      Total
    } else if edge.last_y < last.last_y {
      last.first_y = edge.last_y + 1
      Partial
    } else {
      last.first_y = last.last_y + 1
      last.last_y = edge.last_y
      last.winding = edge.winding
      Partial
    }
  }
  if edge.last_y == last.last_y {
    if edge.first_y > last.first_y {
      last.last_y = edge.first_y - 1
    } else {
      last.last_y = last.first_y - 1
      last.first_y = edge.first_y
      last.winding = edge.winding
    }
    return Partial
  }
  No
}

///|
fn edge_iter(path : @path.Path) -> PathEdgeIter {
  {
    path,
    verb_index: 0,
    points_index: 0,
    move_to: @path.Point::zero(),
    needs_close_line: false,
  }
}

///|
priv enum PathEdge {
  LineTo(@path.Point, @path.Point)
  QuadTo(@path.Point, @path.Point, @path.Point)
  CubicTo(@path.Point, @path.Point, @path.Point, @path.Point)
}

///|
/// Lightweight variant of PathIter that only returns segments (e.g. lines
/// and quads). Does not return Move or Close. Always "auto-closes" each
/// contour.
priv struct PathEdgeIter {
  path : @path.Path
  mut verb_index : Int
  mut points_index : Int
  mut move_to : @path.Point
  mut needs_close_line : Bool
}

///|
fn PathEdgeIter::close_line(self : PathEdgeIter) -> PathEdge? {
  self.needs_close_line = false
  let edge = LineTo(self.path.points()[self.points_index - 1], self.move_to)
  Some(edge)
}

///|
fn PathEdgeIter::next(self : PathEdgeIter) -> PathEdge? {
  let verbs = self.path.verbs()
  let points = self.path.points()
  while self.verb_index < verbs.length() {
    let verb = verbs[self.verb_index]
    self.verb_index += 1
    match verb {
      Move => {
        if self.needs_close_line {
          let res = self.close_line()
          self.move_to = points[self.points_index]
          self.points_index += 1
          return res
        }
        self.move_to = points[self.points_index]
        self.points_index += 1
        continue
      }
      Close => {
        if self.needs_close_line {
          return self.close_line()
        }
        continue
      }
      _ => {
        // Actual edge.
        self.needs_close_line = true
        let edge = match verb {
          Line => {
            let e = LineTo(
              points[self.points_index - 1],
              points[self.points_index + 0],
            )
            self.points_index += 1
            e
          }
          Quad => {
            let e = QuadTo(
              points[self.points_index - 1],
              points[self.points_index + 0],
              points[self.points_index + 1],
            )
            self.points_index += 2
            e
          }
          _ => {
            let e = CubicTo(
              points[self.points_index - 1],
              points[self.points_index + 0],
              points[self.points_index + 1],
              points[self.points_index + 2],
            )
            self.points_index += 3
            e
          }
        }
        return Some(edge)
      }
    }
  }
  if self.needs_close_line {
    self.close_line()
  } else {
    None
  }
}
