// Tests from `tiny-skia-path/src/stroker.rs` and `dash.rs`, plus a few
// snapshots that were verified bit-exact against tiny-skia-path 0.12.0.

///|
fn segments_of(path : Path) -> Array[PathSegment] {
  let iter = path.segments()
  iter.set_auto_close(true)
  iter.to_array()
}

///|
// Make sure that subpath auto-closing is enabled.
test "stroker: auto_close" {
  // A triangle.
  let pb = PathBuilder::new()
  pb.move_to(10.0, 10.0)
  pb.line_to(20.0, 50.0)
  pb.line_to(30.0, 10.0)
  pb.close()
  let path = pb.finish().unwrap()
  let stroke = Stroke::default()
  let stroke_path = PathStroker::new().stroke(path, stroke, 1.0).unwrap()
  let m = (x : Float, y : Float) => PathSegment::MoveTo(Point::from_xy(x, y))
  let l = (x : Float, y : Float) => PathSegment::LineTo(Point::from_xy(x, y))
  let expected : Array[PathSegment] = [
    m(10.485071, 9.878732),
    l(20.485071, 49.878731),
    l(20.0, 50.0),
    l(19.514929, 49.878731),
    l(29.514929, 9.878732),
    l(30.0, 10.0),
    l(30.0, 10.5),
    l(10.0, 10.5),
    l(10.0, 10.0),
    l(10.485071, 9.878732),
    Close,
    m(9.3596115, 9.5),
    l(30.640388, 9.5),
    l(20.485071, 50.121269),
    l(19.514929, 50.121269),
    l(9.514929, 10.121268),
    l(9.3596115, 9.5),
    Close,
  ]
  assert_eq(segments_of(stroke_path), expected)
}

///|
// From skia/tests/StrokeTest.cpp
test "stroker: cubic_1" {
  let pb = PathBuilder::new()
  pb.move_to(51.0161362, 1511.52478)
  pb.cubic_to(
    51.0161362, 1511.52478, 51.0161362, 1511.52478, 51.0161362, 1511.52478,
  )
  let path = pb.finish().unwrap()
  let stroke = { ..Stroke::default(), width: 0.394537568, }
  assert_true(PathStroker::new().stroke(path, stroke, 1.0) is None)
}

///|
fn fb(x : UInt) -> Float {
  Float::reinterpret_from_uint(x)
}

///|
// From skia/tests/StrokeTest.cpp
test "stroker: cubic_2" {
  let pb = PathBuilder::new()
  pb.move_to(fb(0x424c1086), fb(0x44bcf0cb))
  pb.cubic_to(
    fb(0x424c107c),
    fb(0x44bcf0cb),
    fb(0x424c10c2),
    fb(0x44bcf0cb),
    fb(0x424c1119),
    fb(0x44bcf0ca),
  )
  let path = pb.finish().unwrap()
  let stroke = { ..Stroke::default(), width: 0.394537568, }
  assert_true(PathStroker::new().stroke(path, stroke, 1.0) is Some(_))
}

///|
// From skia/tests/StrokeTest.cpp
// From skbug.com/6491. The large stroke width can cause numerical
// instabilities.
test "stroker: big" {
  let pb = PathBuilder::new()
  pb.move_to(fb(0x46380000), fb(0xc6380000)) // 11776, -11776
  pb.line_to(fb(0x46a00000), fb(0xc6a00000)) // 20480, -20480
  pb.line_to(fb(0x468c0000), fb(0xc68c0000)) // 17920, -17920
  pb.line_to(fb(0x46100000), fb(0xc6100000)) // 9216, -9216
  pb.line_to(fb(0x46380000), fb(0xc6380000)) // 11776, -11776
  pb.close()
  let path = pb.finish().unwrap()
  let stroke = { ..Stroke::default(), width: 1.49679073e+10, }
  assert_true(PathStroker::new().stroke(path, stroke, 1.0) is Some(_))
}

///|
// From skia/tests/StrokerTest.cpp
test "stroker: quad_stroker_one_off" {
  let pb = PathBuilder::new()
  pb.move_to(fb(0x43c99223), fb(0x42b7417e))
  pb.quad_to(fb(0x4285d839), fb(0x43ed6645), fb(0x43c941c8), fb(0x42b3ace3))
  let path = pb.finish().unwrap()
  let stroke = { ..Stroke::default(), width: 164.683548, }
  assert_true(PathStroker::new().stroke(path, stroke, 1.0) is Some(_))
}

///|
// From skia/tests/StrokerTest.cpp
test "stroker: cubic_stroker_one_off" {
  let pb = PathBuilder::new()
  pb.move_to(fb(0x433f5370), fb(0x43d1f4b3))
  pb.cubic_to(
    fb(0x4331cb76),
    fb(0x43ea3340),
    fb(0x4388f498),
    fb(0x42f7f08d),
    fb(0x43f1cd32),
    fb(0x42802ec1),
  )
  let path = pb.finish().unwrap()
  let stroke = { ..Stroke::default(), width: 42.835968, }
  assert_true(PathStroker::new().stroke(path, stroke, 1.0) is Some(_))
}

///|
test "stroker: compute_resolution_scale" {
  assert_eq(
    PathStroker::compute_resolution_scale(Transform::from_scale(2.0, 3.0)),
    3.0,
  )
  assert_eq(PathStroker::compute_resolution_scale(Transform::default()), 1.0)
  assert_eq(
    PathStroker::compute_resolution_scale(Transform::from_scale(0.0, 0.0)),
    1.0,
  )
}

///|
test "stroker: zero width" {
  let path = PathBuilder::from_rect(
    Rect::from_ltrb(0.0, 0.0, 10.0, 10.0).unwrap(),
  )
  assert_true(path.stroke({ ..Stroke::default(), width: 0.0, }, 1.0) is None)
}

///|
test "dash: new" {
  assert_eq(StrokeDash::new([], 0.0), None)
  assert_eq(StrokeDash::new([1.0], 0.0), None)
  assert_eq(StrokeDash::new([1.0, 2.0, 3.0], 0.0), None)
  assert_eq(StrokeDash::new([1.0, -2.0], 0.0), None)
  assert_eq(StrokeDash::new([0.0, 0.0], 0.0), None)
  assert_eq(StrokeDash::new([1.0, -1.0], 0.0), None)
  assert_eq(StrokeDash::new([1.0, 1.0], f32_infinity), None)
  assert_eq(StrokeDash::new([1.0, f32_infinity], 0.0), None)
}

///|
test "dash: bug_26" {
  let pb = PathBuilder::new()
  pb.move_to(665.54, 287.3)
  pb.line_to(675.67, 273.04)
  pb.line_to(675.52, 271.32)
  pb.line_to(674.79, 269.61)
  pb.line_to(674.05, 268.04)
  pb.line_to(672.88, 266.47)
  pb.line_to(671.27, 264.9)
  let path = pb.finish().unwrap()
  let stroke_dash = StrokeDash::new([6.0, 4.5], 0.0).unwrap()
  assert_true(path.dash(stroke_dash, 1.0) is Some(_))
}

///|
/// Hashes the path's verbs, points and bounds as `H<len>_<fnv1a64>` over the
/// canonical dump `V<verbs> <x><y>... B<l><t><r><b>` (f32 bits in hex).
fn path_hash(p : Path?) -> String {
  fn hex32(x : UInt) -> String {
    let digits = "0123456789abcdef"
    let buf = StringBuilder()
    for i = 7; i >= 0; i = i - 1 {
      let d = ((x >> (i * 4)) & 0xf).reinterpret_as_int()
      buf.write_char(digits[d].unsafe_to_char())
    }
    buf.to_string()
  }

  fn hf(x : Float) -> String {
    hex32(x.reinterpret_as_uint())
  }

  let s = match p {
    None => "None"
    Some(p) => {
      let sb = StringBuilder()
      sb.write_string("V")
      for v in p.verbs {
        sb.write_string(
          match v {
            Move => "M"
            Line => "L"
            Quad => "Q"
            Cubic => "C"
            Close => "Z"
          },
        )
      }
      for pt in p.points {
        sb.write_string(" " + hf(pt.x) + hf(pt.y))
      }
      let b = p.bounds
      sb.write_string(
        " B" + hf(b.left()) + hf(b.top()) + hf(b.right()) + hf(b.bottom()),
      )
      sb.to_string()
    }
  }
  let mut hash = 0xcbf29ce484222325UL
  for c in s {
    hash = (hash ^ c.to_int().to_uint64()) * 0x100000001b3UL
  }
  "H\{s.length()}_\{hex32((hash >> 32).to_uint())}\{hex32(hash.to_uint())}"
}

///|
fn mk_stroke(
  width : Float,
  miter_limit : Float,
  line_cap : LineCap,
  line_join : LineJoin,
) -> Stroke {
  { width, miter_limit, line_cap, line_join, dash: None, }
}

///|
// Expected hashes were produced by tiny-skia-path 0.12.0.
test "stroker: bit-exact snapshots" {
  let poly = PathBuilder::new()
  poly.move_to(0.0, 0.0)
  poly.line_to(20.0, 0.0)
  poly.line_to(5.0, 3.0)
  poly.line_to(5.0, 15.0)
  let poly = poly.finish().unwrap()
  assert_eq(
    path_hash(poly.stroke(mk_stroke(4.0, 4.0, Round, Round), 1.0)),
    "H724_4ff6368a97c03bcd",
  )
  assert_eq(
    path_hash(poly.stroke(mk_stroke(4.0, 1.5, Square, MiterClip), 1.0)),
    "H306_57e055362c81da07",
  )
  let quad = PathBuilder::new()
  quad.move_to(0.0, 0.0)
  quad.quad_to(30.0, 40.0, 60.0, 0.0)
  let quad = quad.finish().unwrap()
  assert_eq(
    path_hash(quad.stroke(mk_stroke(3.0, 4.0, Butt, Miter), 1.0)),
    "H230_c324b8520a197e84",
  )
  let cusp = PathBuilder::new()
  cusp.move_to(0.0, 0.0)
  cusp.cubic_to(10.0, 10.0, 0.0, 10.0, 10.0, 0.0)
  let cusp = cusp.finish().unwrap()
  assert_eq(
    path_hash(cusp.stroke(mk_stroke(2.0, 4.0, Butt, Round), 1.0)),
    "H1661_1c1f8f38818b6cda",
  )
  let dot = PathBuilder::new()
  dot.move_to(3.0, 4.0)
  dot.close()
  let dot = dot.finish().unwrap()
  assert_eq(
    path_hash(dot.stroke(mk_stroke(6.0, 4.0, Round, Miter), 1.0)),
    "H370_35a4ead643f060a6",
  )
  let zl = PathBuilder::new()
  zl.move_to(3.0, 4.0)
  zl.line_to(3.0, 4.0)
  zl.line_to(3.0, 4.0)
  zl.close()
  let zl = zl.finish().unwrap()
  let stroked = zl.stroke(mk_stroke(2.0, 4.0, Square, Miter), 1.0)
  assert_eq(path_hash(stroked), "H126_6cd1c1159938a0b3")
  inspect(
    stroked.unwrap().to_svg_like(),
    content=(
      #|M 4 4 L 4 5 L 2 5 L 2 3 L 4 3 Z
    ),
  )
}

///|
// Expected hashes were produced by tiny-skia-path 0.12.0.
test "dash: bit-exact snapshots" {
  let rect = PathBuilder::from_rect(
    Rect::from_ltrb(0.0, 0.0, 10.0, 10.0).unwrap(),
  )
  let d1 = StrokeDash::new([5.0, 3.0], 2.0).unwrap()
  let dashed = rect.dash(d1, 1.0)
  assert_eq(path_hash(dashed), "H269_aac1ee4dddb38756")
  inspect(
    dashed.unwrap().to_svg_like(),
    content="M 6 0 L 10 0 L 10 1 M 10 4 L 10 9 M 8 10 L 3 10 M 0 10 L 0 10 L 0 5 M 0 2 L 0 0 L 3 0",
  )
  let mixed = PathBuilder::new()
  mixed.move_to(0.0, 0.0)
  mixed.cubic_to(10.0, 20.0, 30.0, -20.0, 40.0, 0.0)
  mixed.quad_to(50.0, 10.0, 60.0, 0.0)
  mixed.close()
  let mixed = mixed.finish().unwrap()
  let d2 = StrokeDash::new([4.0, 2.0, 1.0, 2.0], -3.0).unwrap()
  let dashed = mixed.dash(d2, 1.0).unwrap()
  assert_eq(
    path_hash(dashed.stroke(mk_stroke(1.0, 4.0, Square, Bevel), 1.0)),
    "H4928_e0c109aaed648ca7",
  )
}
