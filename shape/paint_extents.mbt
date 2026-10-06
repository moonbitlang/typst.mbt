// Port of rustybuzz 0.20.1 `src/hb/paint_extents.rs`.
//
// This file implements bounds-extraction as well as boundedness
// computation of COLRv1 fonts as described in:
//
// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#glyph-metrics-and-boundedness

///|
priv struct Extents {
  mut x_min : Float
  mut y_min : Float
  mut x_max : Float
  mut y_max : Float
}

///|
fn Extents::copy(self : Extents) -> Extents {
  { ..self, }
}

///|
fn Extents::is_empty(self : Extents) -> Bool {
  self.x_min >= self.x_max || self.y_min >= self.y_max
}

///|
fn Extents::is_void(self : Extents) -> Bool {
  self.x_min > self.x_max
}

///|
fn fmin(a : Float, b : Float) -> Float {
  // Rust's f32::min (NaN-ignoring).
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else {
    b
  }
}

///|
fn fmax(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else {
    b
  }
}

///|
fn Extents::union_(self : Extents, o : Extents) -> Unit {
  // Upstream compares `o` with itself.
  self.x_min = fmin(o.x_min, o.x_min)
  self.y_min = fmin(o.y_min, o.y_min)
  self.x_max = fmax(o.x_max, o.x_max)
  self.y_max = fmax(o.y_max, o.y_max)
}

///|
fn Extents::intersect(self : Extents, o : Extents) -> Unit {
  // Upstream compares `o` with itself.
  self.x_min = fmax(o.x_min, o.x_min)
  self.y_min = fmax(o.y_min, o.y_min)
  self.x_max = fmin(o.x_max, o.x_max)
  self.y_max = fmin(o.y_max, o.y_max)
}

///|
priv enum BoundsStatus {
  Empty
  Bounded
  Unbounded
} derive(Eq)

///|
priv struct Bounds {
  mut status : BoundsStatus
  mut extents : Extents
}

///|
fn Bounds::from_extents(extents : Extents) -> Bounds {
  let status = if extents.is_empty() { Empty } else { Bounded }
  { extents: extents.copy(), status, }
}

///|
fn Bounds::default() -> Bounds {
  Bounds::from_extents({ x_min: 0.0, x_max: 0.0, y_min: 0.0, y_max: 0.0, })
}

///|
fn Bounds::from_status(status : BoundsStatus) -> Bounds {
  let b = Bounds::default()
  b.status = status
  b
}

///|
fn Bounds::assign(self : Bounds, o : Bounds) -> Unit {
  self.status = o.status
  self.extents = o.extents.copy()
}

///|
fn Bounds::union(self : Bounds, o : Bounds) -> Unit {
  if o.status == Unbounded {
    self.status = Unbounded
  } else if o.status == Bounded {
    if self.status == Empty {
      self.assign(o)
    } else if self.status == Bounded {
      self.extents.union_(o.extents)
    }
  }
}

///|
fn Bounds::intersect(self : Bounds, o : Bounds) -> Unit {
  if o.status == Empty {
    self.status = Empty
  } else if o.status == Bounded {
    if self.status == Unbounded {
      self.assign(o)
    } else if self.status == Bounded {
      self.extents.intersect(o.extents)
      if self.extents.is_empty() {
        self.status = Empty
      }
    }
  }
}

///|
priv struct PaintExtentsContext {
  clips : Array[Bounds]
  groups : Array[Bounds]
  transforms : Array[@otf.Transform]
  // Doesn't exist in harfbuzz. The reason we need it is that in harfbuzz,
  // composite modes are passed as part of `pop`, while ttf-parser passes it
  // as part of `push`, so we need to store it in the meanwhile.
  composite_modes : Array[@otf.CompositeMode]
  face : @otf.Face
  mut current_glyph : @otf.GlyphId
}

///|
fn PaintExtentsContext::new(face : @otf.Face) -> PaintExtentsContext {
  {
    clips: [Bounds::from_status(Unbounded)],
    groups: [Bounds::from_status(Empty)],
    transforms: [@otf.Transform::default()],
    composite_modes: [@otf.CompositeMode::SourceOver],
    face,
    current_glyph: @otf.GlyphId(0),
  }
}

///|
fn PaintExtentsContext::get_extents(self : PaintExtentsContext) -> Extents {
  // harfbuzz doesn't have the unwrap_or_default part, but in a valid font
  // this should always be valid anyway.
  match self.groups.last() {
    Some(g) => g.extents.copy()
    None => Bounds::default().extents
  }
}

///|
fn PaintExtentsContext::push_transform_(
  self : PaintExtentsContext,
  trans : @otf.Transform,
) -> Unit {
  let t = self.transforms.last().unwrap_or(@otf.Transform::default())
  let new = @otf.Transform::combine(t, trans)
  self.transforms.push(new)
}

///|
fn PaintExtentsContext::push_clip_(
  self : PaintExtentsContext,
  extents : Extents,
) -> Unit {
  if self.transforms.last() is Some(r) {
    transform_extents(r, extents)
  }
  let b = Bounds::from_extents(extents)
  self.clips.push(b)
}

///|
fn PaintExtentsContext::push_group(self : PaintExtentsContext) -> Unit {
  self.groups.push(Bounds::default())
}

///|
fn PaintExtentsContext::pop_group(self : PaintExtentsContext) -> Unit {
  if self.composite_modes.pop() is Some(mode) {
    if self.groups.pop() is Some(src_bounds) {
      if self.groups.last() is Some(backdrop_bounds) {
        match mode {
          Clear => backdrop_bounds.status = Empty
          Source | SourceOut => backdrop_bounds.assign(src_bounds)
          Destination | DestinationOut => ()
          SourceIn | DestinationIn => backdrop_bounds.intersect(src_bounds)
          _ => backdrop_bounds.union(src_bounds)
        }
      }
    }
  }
}

///|
fn PaintExtentsContext::paint_(self : PaintExtentsContext) -> Unit {
  if self.clips.last() is Some(clip) && self.groups.last() is Some(group) {
    group.union(clip)
  }
}

///|
impl @otf.ColrPainter for PaintExtentsContext with fn outline_glyph(
  self,
  glyph_id,
) {
  self.current_glyph = glyph_id
}

///|
impl @otf.ColrPainter for PaintExtentsContext with fn paint(self, _) {
  self.paint_()
}

///|
impl @otf.ColrPainter for PaintExtentsContext with fn push_clip(self) {
  if self.face.glyph_bounding_box(self.current_glyph) is Some(glyph_bbox) {
    self.push_clip_({
      x_min: Float::from_int(glyph_bbox.x_min.to_int()),
      y_min: Float::from_int(glyph_bbox.y_min.to_int()),
      x_max: Float::from_int(glyph_bbox.x_max.to_int()),
      y_max: Float::from_int(glyph_bbox.y_max.to_int()),
    })
  }
}

///|
impl @otf.ColrPainter for PaintExtentsContext with fn push_clip_box(
  self,
  clipbox,
) {
  self.push_clip_({
    x_min: clipbox.x_min,
    y_min: clipbox.y_min,
    x_max: clipbox.x_max,
    y_max: clipbox.y_max,
  })
}

///|
impl @otf.ColrPainter for PaintExtentsContext with fn pop_clip(self) {
  let _ = self.clips.pop()
}

///|
impl @otf.ColrPainter for PaintExtentsContext with fn push_layer(self, mode) {
  self.composite_modes.push(mode)
  self.push_group()
}

///|
impl @otf.ColrPainter for PaintExtentsContext with fn pop_layer(self) {
  self.pop_group()
}

///|
impl @otf.ColrPainter for PaintExtentsContext with fn push_transform(
  self,
  transform,
) {
  self.push_transform_(transform)
}

///|
impl @otf.ColrPainter for PaintExtentsContext with fn pop_transform(self) {
  let _ = self.transforms.pop()
}

///|
fn transform_extents(t : @otf.Transform, extents : Extents) -> Unit {
  let quad_x : FixedArray[Float] = [
    extents.x_min,
    extents.x_min,
    extents.x_max,
    extents.x_max,
  ]
  let quad_y : FixedArray[Float] = [
    extents.y_min,
    extents.y_max,
    extents.y_min,
    extents.y_max,
  ]
  for i in 0..<4 {
    // transform_point
    let x = quad_x[i]
    let y = quad_y[i]
    let new_x = t.a * x + t.c * y
    let new_y = t.b * x + t.d * y
    quad_x[i] = new_x + t.e
    quad_y[i] = new_y + t.f
  }
  extents.x_max = quad_x[0]
  extents.x_min = extents.x_max
  extents.y_max = quad_y[0]
  extents.y_min = extents.y_max
  for i in 1..<4 {
    extents.x_min = fmin(extents.x_min, quad_x[i])
    extents.y_min = fmin(extents.y_min, quad_y[i])
    extents.x_max = fmax(extents.x_max, quad_x[i])
    extents.y_max = fmax(extents.y_max, quad_y[i])
  }
}
