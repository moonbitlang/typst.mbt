// Ports of skrifa 0.42.1 `src/outline/glyf/hint/{zone, graphics, round,
// projection}.rs`.

///|
/// A window into a backing array (`&mut [T]` upstream).
priv struct IntSlice {
  arr : FixedArray[Int]
  off : Int
  len : Int
}

///|
fn IntSlice::new(arr : FixedArray[Int], off : Int, len : Int) -> IntSlice {
  { arr, off, len, }
}

///|
fn IntSlice::empty() -> IntSlice {
  { arr: [], off: 0, len: 0, }
}

///|
fn IntSlice::get(self : IntSlice, i : Int) -> Int {
  self.arr[self.off + i]
}

///|
fn IntSlice::set(self : IntSlice, i : Int, v : Int) -> Unit {
  self.arr[self.off + i] = v
}

///|
fn IntSlice::valid(self : IntSlice, i : Int) -> Bool {
  i >= 0 && i < self.len
}

///|
/// Point marker bits.
const MARKER_TOUCHED_X : Int = 0x10

///|
const MARKER_TOUCHED_Y : Int = 0x20

///|
const MARKER_TOUCHED : Int = 0x30

///|
/// Describes the axis to which a measurement or point movement operation
/// applies.
priv enum CoordAxis {
  Both
  X
  Y
} derive(Eq)

///|
fn CoordAxis::touched_marker(self : CoordAxis) -> Int {
  match self {
    Both => MARKER_TOUCHED
    X => MARKER_TOUCHED_X
    Y => MARKER_TOUCHED_Y
  }
}

///|
/// Glyph zone for TrueType hinting.
priv struct Zone {
  /// Outline points prior to applying scale.
  unscaled_x : IntSlice
  unscaled_y : IntSlice
  /// Copy of the outline points after applying scale.
  original_x : IntSlice
  original_y : IntSlice
  /// Scaled outline points.
  points_x : IntSlice
  points_y : IntSlice
  flags : IntSlice
  contours : IntSlice
}

///|
fn Zone::default() -> Zone {
  let e = IntSlice::empty()
  {
    unscaled_x: e,
    unscaled_y: e,
    original_x: e,
    original_y: e,
    points_x: e,
    points_y: e,
    flags: e,
    contours: e,
  }
}

///|
fn Zone::len(self : Zone) -> Int {
  self.points_x.len
}

///|
fn Zone::point(self : Zone, index : Int) -> (Int, Int) raise HintErrorKind {
  if !self.points_x.valid(index) {
    raise InvalidPointIndex(index)
  }
  (self.points_x.get(index), self.points_y.get(index))
}

///|
fn Zone::set_point(
  self : Zone,
  index : Int,
  p : (Int, Int),
) -> Unit raise HintErrorKind {
  if !self.points_x.valid(index) {
    raise InvalidPointIndex(index)
  }
  self.points_x.set(index, p.0)
  self.points_y.set(index, p.1)
}

///|
fn Zone::original(self : Zone, index : Int) -> (Int, Int) raise HintErrorKind {
  if !self.original_x.valid(index) {
    raise InvalidPointIndex(index)
  }
  (self.original_x.get(index), self.original_y.get(index))
}

///|
fn Zone::set_original(
  self : Zone,
  index : Int,
  p : (Int, Int),
) -> Unit raise HintErrorKind {
  if !self.original_x.valid(index) {
    raise InvalidPointIndex(index)
  }
  self.original_x.set(index, p.0)
  self.original_y.set(index, p.1)
}

///|
fn Zone::unscaled(self : Zone, index : Int) -> (Int, Int) {
  // Unscaled points in the twilight zone are always (0, 0).
  if self.unscaled_x.valid(index) {
    (self.unscaled_x.get(index), self.unscaled_y.get(index))
  } else {
    (0, 0)
  }
}

///|
fn Zone::contour(self : Zone, index : Int) -> Int raise HintErrorKind {
  if !self.contours.valid(index) {
    raise InvalidContourIndex(index)
  }
  self.contours.get(index)
}

///|
fn Zone::touch(
  self : Zone,
  index : Int,
  axis : CoordAxis,
) -> Unit raise HintErrorKind {
  if !self.flags.valid(index) {
    raise InvalidPointIndex(index)
  }
  self.flags.set(index, self.flags.get(index) | axis.touched_marker())
}

///|
fn Zone::untouch(
  self : Zone,
  index : Int,
  axis : CoordAxis,
) -> Unit raise HintErrorKind {
  if !self.flags.valid(index) {
    raise InvalidPointIndex(index)
  }
  self.flags.set(index, self.flags.get(index) & (axis.touched_marker() ^ 0xFF))
}

///|
fn Zone::is_touched(
  self : Zone,
  index : Int,
  axis : CoordAxis,
) -> Bool raise HintErrorKind {
  if !self.flags.valid(index) {
    raise InvalidPointIndex(index)
  }
  (self.flags.get(index) & axis.touched_marker()) != 0
}

///|
fn Zone::flip_on_curve(self : Zone, index : Int) -> Unit raise HintErrorKind {
  if !self.flags.valid(index) {
    raise InvalidPointIndex(index)
  }
  self.flags.set(index, self.flags.get(index) ^ 1)
}

///|
fn Zone::set_on_curve(
  self : Zone,
  start : Int,
  end : Int,
  on : Bool,
) -> Unit raise HintErrorKind {
  if start < 0 || end < 0 || start > end || end > self.flags.len {
    raise InvalidPointRange(start, end)
  }
  for i in start..<end {
    if on {
      self.flags.set(i, self.flags.get(i) | 1)
    } else {
      self.flags.set(i, self.flags.get(i) & 0xFE)
    }
  }
}

///|
fn Zone::coord(xs : IntSlice, ys : IntSlice, axis : CoordAxis) -> IntSlice {
  if axis == X {
    xs
  } else {
    ys
  }
}

///|
/// Interpolate untouched points.
fn Zone::iup(self : Zone, axis : CoordAxis) -> Unit raise HintErrorKind {
  let mut point = 0
  for i in 0..<self.contours.len {
    let mut end_point = self.contour(i)
    let first_point = point
    if end_point >= self.len() {
      end_point = self.len() - 1
    }
    while point <= end_point && !self.is_touched(point, axis) {
      point += 1
    }
    if point <= end_point {
      let first_touched = point
      let mut cur_touched = point
      point += 1
      while point <= end_point {
        if self.is_touched(point, axis) {
          self.iup_interpolate(
            axis,
            cur_touched + 1,
            point - 1,
            cur_touched,
            point,
          )
          cur_touched = point
        }
        point += 1
      }
      if cur_touched == first_touched {
        self.iup_shift(axis, first_point, end_point, cur_touched)
      } else {
        self.iup_interpolate(
          axis,
          cur_touched + 1,
          end_point,
          cur_touched,
          first_touched,
        )
        if first_touched > 0 {
          self.iup_interpolate(
            axis,
            first_point,
            first_touched - 1,
            cur_touched,
            first_touched,
          )
        }
      }
    }
  }
}

///|
/// Shift the range of points p1..=p2 based on the delta given by the
/// reference point p.
fn Zone::iup_shift(
  self : Zone,
  axis : CoordAxis,
  p1 : Int,
  p2 : Int,
  p : Int,
) -> Unit raise HintErrorKind {
  if p1 > p2 || p1 > p || p > p2 {
    return
  }
  let pts = Zone::coord(self.points_x, self.points_y, axis)
  let org = Zone::coord(self.original_x, self.original_y, axis)
  if !pts.valid(p) || !org.valid(p) {
    raise InvalidPointIndex(p)
  }
  let delta = pts.get(p) - org.get(p)
  if delta != 0 {
    if p2 >= pts.len {
      raise InvalidPointRange(p1, p2 + 1)
    }
    for i in p1..<=p2 {
      if i != p {
        pts.set(i, pts.get(i) + delta)
      }
    }
  }
}

///|
/// Interpolate the range of points p1..=p2 based on the deltas given by
/// the two reference points.
fn Zone::iup_interpolate(
  self : Zone,
  axis : CoordAxis,
  p1 : Int,
  p2 : Int,
  ref1 : Int,
  ref2 : Int,
) -> Unit raise HintErrorKind {
  if p1 > p2 {
    return
  }
  let max_points = self.len()
  if ref1 >= max_points || ref2 >= max_points {
    return
  }
  let mut ref1 = ref1
  let mut ref2 = ref2
  let pts = Zone::coord(self.points_x, self.points_y, axis)
  let org = Zone::coord(self.original_x, self.original_y, axis)
  let uns = Zone::coord(self.unscaled_x, self.unscaled_y, axis)
  let unscaled = fn(i : Int) { if uns.valid(i) { uns.get(i) } else { 0 } }
  let mut orus1 = unscaled(ref1)
  let mut orus2 = unscaled(ref2)
  if orus1 > orus2 {
    let t = orus1
    orus1 = orus2
    orus2 = t
    let r = ref1
    ref1 = ref2
    ref2 = r
  }
  if !org.valid(ref1) {
    raise InvalidPointIndex(ref1)
  }
  if !org.valid(ref2) {
    raise InvalidPointIndex(ref2)
  }
  let org1 = org.get(ref1)
  let org2 = org.get(ref2)
  if !pts.valid(ref1) {
    raise InvalidPointIndex(ref1)
  }
  if !pts.valid(ref2) {
    raise InvalidPointIndex(ref2)
  }
  let cur1 = pts.get(ref1)
  let cur2 = pts.get(ref2)
  let delta1 = cur1 - org1
  let delta2 = cur2 - org2
  if p2 >= org.len || p2 >= uns.len || p2 >= pts.len {
    raise InvalidPointRange(p1, p2 + 1)
  }
  if cur1 == cur2 || orus1 == orus2 {
    for i in p1..<=p2 {
      let a = org.get(i)
      pts.set(
        i,
        if a <= org1 {
          a + delta1
        } else if a >= org2 {
          a + delta2
        } else {
          cur1
        },
      )
    }
  } else {
    let scale = hdiv(cur2 - cur1, orus2 - orus1)
    for i in p1..<=p2 {
      let a = org.get(i)
      pts.set(
        i,
        if a <= org1 {
          a + delta1
        } else if a >= org2 {
          a + delta2
        } else {
          cur1 + hmul(uns.get(i) - orus1, scale)
        },
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Rounding

///|
/// Rounding strategies supported by the interpreter.
priv enum RoundMode {
  Grid
  HalfGrid
  DoubleGrid
  DownToGrid
  UpToGrid
  Off
  Super
  Super45
} derive(Eq)

///|
/// Graphics state that controls rounding.
priv struct RoundState {
  mut mode : RoundMode
  mut threshold : Int
  mut phase : Int
  mut period : Int
}

///|
fn RoundState::default() -> RoundState {
  { mode: Grid, threshold: 0, phase: 0, period: 64, }
}

///|
fn imin(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn RoundState::round(self : RoundState, distance : Int) -> Int {
  match self.mode {
    HalfGrid =>
      if distance >= 0 {
        imax(hfloor(distance) + 32, 0)
      } else {
        imin(-(hfloor(-distance) + 32), 0)
      }
    Grid =>
      if distance >= 0 {
        imax(hround(distance), 0)
      } else {
        imin(-hround(-distance), 0)
      }
    DoubleGrid =>
      if distance >= 0 {
        imax(round_pad(distance, 32), 0)
      } else {
        imin(-round_pad(-distance, 32), 0)
      }
    DownToGrid =>
      if distance >= 0 {
        imax(hfloor(distance), 0)
      } else {
        imin(-hfloor(-distance), 0)
      }
    UpToGrid =>
      if distance >= 0 {
        imax(hceil(distance), 0)
      } else {
        imin(-hceil(-distance), 0)
      }
    Super =>
      if distance >= 0 {
        let val = ((distance + (self.threshold - self.phase)) & -self.period) +
          self.phase
        if val < 0 {
          self.phase
        } else {
          val
        }
      } else {
        let val = -((self.threshold - self.phase - distance) & -self.period) -
          self.phase
        if val > 0 {
          -self.phase
        } else {
          val
        }
      }
    Super45 =>
      if distance >= 0 {
        let val = (distance + (self.threshold - self.phase)) /
          self.period *
          self.period +
          self.phase
        if val < 0 {
          self.phase
        } else {
          val
        }
      } else {
        let val = -((self.threshold - self.phase - distance) /
          self.period *
          self.period) -
          self.phase
        if val > 0 {
          -self.phase
        } else {
          val
        }
      }
    Off => distance
  }
}

// ---------------------------------------------------------------------------
// Graphics state

///|
/// The persistent graphics state.
priv struct RetainedGraphicsState {
  mut auto_flip : Bool
  mut control_value_cutin : Int
  mut delta_base : Int
  mut delta_shift : Int
  mut instruct_control : Int
  mut min_distance : Int
  mut scan_control : Bool
  mut scan_type : Int
  mut single_width_cutin : Int
  mut single_width : Int
  target : Target
  scale : Int
  ppem : Int
  is_rotated : Bool
  is_stretched : Bool
}

///|
fn RetainedGraphicsState::new(
  scale : Int,
  ppem : Int,
  target : Target,
) -> RetainedGraphicsState {
  {
    auto_flip: true,
    // 17/16 pixels in 26.6
    control_value_cutin: 68,
    delta_base: 9,
    delta_shift: 3,
    instruct_control: 0,
    // 1 pixel in 26.6
    min_distance: 64,
    scan_control: false,
    scan_type: 0,
    single_width_cutin: 0,
    single_width: 0,
    target,
    scale,
    ppem,
    is_rotated: false,
    is_stretched: false,
  }
}

///|
fn RetainedGraphicsState::default() -> RetainedGraphicsState {
  RetainedGraphicsState::new(0, 0, Target::default())
}

///|
fn RetainedGraphicsState::copy(
  self : RetainedGraphicsState,
) -> RetainedGraphicsState {
  { ..self, }
}

///|
/// Zone pointer: 0 = twilight, 1 = glyph.
priv struct ZonePointer(Int) derive(Eq)

///|
fn ZonePointer::is_twilight(self : ZonePointer) -> Bool {
  self.0 == 0
}

///|
fn zone_pointer_from(value : Int) -> ZonePointer raise HintErrorKind {
  match value {
    0 | 1 => ZonePointer(value)
    _ => raise InvalidZoneIndex(value)
  }
}

///|
/// Context in which instructions are executed.
priv struct GraphicsState {
  mut retained : RetainedGraphicsState
  mut proj_x : Int
  mut proj_y : Int
  mut proj_axis : CoordAxis
  mut dual_proj_x : Int
  mut dual_proj_y : Int
  mut dual_proj_axis : CoordAxis
  mut freedom_x : Int
  mut freedom_y : Int
  mut freedom_axis : CoordAxis
  mut fdotp : Int
  mut round_state : RoundState
  mut rp0 : Int
  mut rp1 : Int
  mut rp2 : Int
  mut loop_counter : Int
  mut zp0 : ZonePointer
  mut zp1 : ZonePointer
  mut zp2 : ZonePointer
  zones : FixedArray[Zone]
  is_composite : Bool
  mut backward_compatibility : Bool
  mut is_pedantic : Bool
  mut did_iup_x : Bool
  mut did_iup_y : Bool
}

///|
fn GraphicsState::new(
  retained : RetainedGraphicsState,
  twilight : Zone,
  glyph : Zone,
  is_composite : Bool,
) -> GraphicsState {
  let gs : GraphicsState = {
    retained,
    proj_x: 0x4000,
    proj_y: 0,
    proj_axis: Both,
    dual_proj_x: 0x4000,
    dual_proj_y: 0,
    dual_proj_axis: Both,
    freedom_x: 0x4000,
    freedom_y: 0,
    freedom_axis: Both,
    fdotp: 0x4000,
    round_state: RoundState::default(),
    rp0: 0,
    rp1: 0,
    rp2: 0,
    loop_counter: 1,
    zp0: ZonePointer(1),
    zp1: ZonePointer(1),
    zp2: ZonePointer(1),
    zones: [twilight, glyph],
    is_composite,
    backward_compatibility: true,
    is_pedantic: false,
    did_iup_x: false,
    did_iup_y: false,
  }
  gs
}

///|
/// Returns the factor for scaling unscaled points to pixels.
fn GraphicsState::unscaled_to_pixels(self : GraphicsState) -> Int {
  if self.is_composite {
    1 << 16
  } else {
    self.retained.scale
  }
}

///|
/// Resets the non-retained portions of the graphics state.
fn GraphicsState::reset(self : GraphicsState) -> Unit {
  self.proj_x = 0x4000
  self.proj_y = 0
  self.proj_axis = Both
  self.dual_proj_x = 0x4000
  self.dual_proj_y = 0
  self.dual_proj_axis = Both
  self.freedom_x = 0x4000
  self.freedom_y = 0
  self.freedom_axis = Both
  self.fdotp = 0x4000
  self.round_state = RoundState::default()
  self.rp0 = 0
  self.rp1 = 0
  self.rp2 = 0
  self.loop_counter = 1
  self.zp0 = ZonePointer(1)
  self.zp1 = ZonePointer(1)
  self.zp2 = ZonePointer(1)
  self.backward_compatibility = true
  self.is_pedantic = false
  self.did_iup_x = false
  self.did_iup_y = false
  self.update_projection_state()
}

///|
/// Resets the retained portion of the graphics state to default values
/// while saving the user instance settings.
fn GraphicsState::reset_retained(self : GraphicsState) -> Unit {
  let r = self.retained
  self.retained = RetainedGraphicsState::new(r.scale, r.ppem, r.target)
}

///|
/// Updates cached state that is derived from projection vectors.
fn GraphicsState::update_projection_state(self : GraphicsState) -> Unit {
  // 1.0 in 2.14 fixed point.
  let one = 0x4000
  if self.freedom_x == one {
    self.fdotp = self.proj_x
  } else if self.freedom_y == one {
    self.fdotp = self.proj_y
  } else {
    let px = self.proj_x
    let py = self.proj_y
    let fx = self.freedom_x
    let fy = self.freedom_y
    self.fdotp = (px * fx + py * fy) >> 14
  }
  self.proj_axis = Both
  if self.proj_x == one {
    self.proj_axis = X
  } else if self.proj_y == one {
    self.proj_axis = Y
  }
  self.dual_proj_axis = Both
  if self.dual_proj_x == one {
    self.dual_proj_axis = X
  } else if self.dual_proj_y == one {
    self.dual_proj_axis = Y
  }
  self.freedom_axis = Both
  if self.fdotp == one {
    if self.freedom_x == one {
      self.freedom_axis = X
    } else if self.freedom_y == one {
      self.freedom_axis = Y
    }
  }
  // At small sizes, fdotp can become too small resulting in overflows
  // and spikes.
  let a = if self.fdotp < 0 { -self.fdotp } else { self.fdotp }
  if a < 0x400 {
    self.fdotp = one
  }
}

///|
/// Computes the projection of vector given by (v1 - v2) along the current
/// projection vector.
fn GraphicsState::project(
  self : GraphicsState,
  v1 : (Int, Int),
  v2 : (Int, Int),
) -> Int {
  match self.proj_axis {
    X => v1.0 - v2.0
    Y => v1.1 - v2.1
    Both => {
      let dx = v1.0 - v2.0
      let dy = v1.1 - v2.1
      dot14(dx, dy, self.proj_x, self.proj_y)
    }
  }
}

///|
/// Computes the projection of vector given by (v1 - v2) along the current
/// dual projection vector.
fn GraphicsState::dual_project(
  self : GraphicsState,
  v1 : (Int, Int),
  v2 : (Int, Int),
) -> Int {
  match self.dual_proj_axis {
    X => v1.0 - v2.0
    Y => v1.1 - v2.1
    Both => {
      let dx = v1.0 - v2.0
      let dy = v1.1 - v2.1
      dot14(dx, dy, self.dual_proj_x, self.dual_proj_y)
    }
  }
}

///|
fn GraphicsState::round(self : GraphicsState, distance : Int) -> Int {
  self.round_state.round(distance)
}

///|
/// Returns true if all (zone pointer, point index) accesses would be valid.
fn GraphicsState::in_bounds(
  self : GraphicsState,
  pairs : Array[(ZonePointer, Int)],
) -> Bool {
  for pair in pairs {
    let (zp, index) = pair
    if index < 0 || index > self.zone(zp).len() {
      return false
    }
  }
  true
}

///|
fn GraphicsState::zone(self : GraphicsState, pointer : ZonePointer) -> Zone {
  self.zones[pointer.0]
}

///|
fn GraphicsState::zp0z(self : GraphicsState) -> Zone {
  self.zone(self.zp0)
}

///|
fn GraphicsState::zp1z(self : GraphicsState) -> Zone {
  self.zone(self.zp1)
}

///|
fn GraphicsState::zp2z(self : GraphicsState) -> Zone {
  self.zone(self.zp2)
}

///|
/// Moves the requested original point by the given distance.
fn GraphicsState::move_original(
  self : GraphicsState,
  zone : ZonePointer,
  point_ix : Int,
  distance : Int,
) -> Unit raise HintErrorKind {
  let z = self.zone(zone)
  let (px, py) = z.original(point_ix)
  match self.freedom_axis {
    X => z.set_original(point_ix, (px + distance, py))
    Y => z.set_original(point_ix, (px, py + distance))
    Both => {
      let mut x = px
      let mut y = py
      if self.freedom_x != 0 {
        x = x + hmul_div(distance, self.freedom_x, self.fdotp)
      }
      if self.freedom_y != 0 {
        y = y + hmul_div(distance, self.freedom_y, self.fdotp)
      }
      z.set_original(point_ix, (x, y))
    }
  }
}

///|
/// Moves the requested scaled point by the given distance.
fn GraphicsState::move_point(
  self : GraphicsState,
  zone : ZonePointer,
  point_ix : Int,
  distance : Int,
) -> Unit raise HintErrorKind {
  // Note: we never adjust x in backward compatibility mode and we never
  // adjust y in backward compatibility mode after IUP has been done in
  // both directions.
  let back_compat = self.backward_compatibility
  let back_compat_and_did_iup = back_compat && self.did_iup_x && self.did_iup_y
  let z = self.zone(zone)
  let (px, py) = z.point(point_ix)
  match self.freedom_axis {
    X => {
      if !back_compat {
        z.set_point(point_ix, (px + distance, py))
      }
      z.touch(point_ix, X)
    }
    Y => {
      if !back_compat_and_did_iup {
        z.set_point(point_ix, (px, py + distance))
      }
      z.touch(point_ix, Y)
    }
    Both => {
      if self.freedom_x != 0 {
        if !back_compat {
          let (cx, cy) = z.point(point_ix)
          z.set_point(
            point_ix,
            (cx + hmul_div(distance, self.freedom_x, self.fdotp), cy),
          )
        }
        z.touch(point_ix, X)
      }
      if self.freedom_y != 0 {
        if !back_compat_and_did_iup {
          let (cx, cy) = z.point(point_ix)
          z.set_point(
            point_ix,
            (cx, cy + hmul_div(distance, self.freedom_y, self.fdotp)),
          )
        }
        z.touch(point_ix, Y)
      }
    }
  }
}

///|
/// Moves the requested scaled point in the zone referenced by zp2 by the
/// given delta.
fn GraphicsState::move_zp2_point(
  self : GraphicsState,
  point_ix : Int,
  dx : Int,
  dy : Int,
  do_touch : Bool,
) -> Unit raise HintErrorKind {
  let back_compat = self.backward_compatibility
  let back_compat_and_did_iup = back_compat && self.did_iup_x && self.did_iup_y
  let z = self.zp2z()
  if self.freedom_x != 0 {
    if !back_compat {
      let (x, y) = z.point(point_ix)
      z.set_point(point_ix, (x + dx, y))
    }
    if do_touch {
      z.touch(point_ix, X)
    }
  }
  if self.freedom_y != 0 {
    if !back_compat_and_did_iup {
      let (x, y) = z.point(point_ix)
      z.set_point(point_ix, (x, y + dy))
    }
    if do_touch {
      z.touch(point_ix, Y)
    }
  }
}

///|
priv struct PointDisplacement {
  zone : ZonePointer
  point_ix : Int
  dx : Int
  dy : Int
}

///|
/// Computes the adjustment made to a point along the current freedom
/// vector.
fn GraphicsState::point_displacement(
  self : GraphicsState,
  opcode : Int,
) -> PointDisplacement raise HintErrorKind {
  let (zone, point_ix) = if (opcode & 1) != 0 {
    (self.zp0, self.rp1)
  } else {
    (self.zp1, self.rp2)
  }
  let zone_data = self.zone(zone)
  let point = zone_data.point(point_ix)
  let original_point = zone_data.original(point_ix)
  let distance = self.project(point, original_point)
  let dx = hmul_div(distance, self.freedom_x, self.fdotp)
  let dy = hmul_div(distance, self.freedom_y, self.fdotp)
  { zone, point_ix, dx, dy, }
}
