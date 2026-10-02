// Unit tests of `shading.mbt`, `encode.mbt` and `gradient.mbt` (end-to-end
// comparisons against hayro-svg are in `hayro/svg/shading_oracle_test.mbt`).

///|
fn vertex(x : Double, y : Double, colors : Array[Float]) -> TriangleVertex {
  { flag: 0, point: @kurbo.Point::new(x, y), colors, }
}

///|
test "triangle interpolation" {
  let t = Triangle::new(
    vertex(0.0, 0.0, [0.0, 1.0]),
    vertex(10.0, 0.0, [1.0, 0.0]),
    vertex(0.0, 10.0, [0.5, 0.5]),
  )
  assert_eq(t.interpolate(@kurbo.Point::new(0.0, 0.0)), [0.0, 1.0])
  assert_eq(t.interpolate(@kurbo.Point::new(10.0, 0.0)), [1.0, 0.0])
  assert_eq(t.interpolate(@kurbo.Point::new(0.0, 10.0)), [0.5, 0.5])
  assert_eq(t.interpolate(@kurbo.Point::new(5.0, 0.0)), [0.5, 0.5])
  assert_true(t.contains_point(@kurbo.Point::new(1.0, 1.0)))
  assert_false(t.contains_point(@kurbo.Point::new(6.0, 6.0)))
  assert_eq(t.bounding_box(), @kurbo.Rect::new(0.0, 0.0, 10.0, 10.0))
}

///|
test "free-form triangle mesh" {
  // BitsPerFlag 8, BitsPerCoordinate 8, BitsPerComponent 8, one gray
  // component; Decode [0 255 0 255 0 1].
  let data = b"\x00\x00\x00\x00\x00\x0a\x00\xff\x00\x00\x0a\x80\x01\x0a\x0a\xff"
  let triangles = read_free_form_triangles(data, 8, 8, 8, false, [
    0.0, 255.0, 0.0, 255.0, 0.0, 1.0,
  ]).unwrap()
  assert_eq(triangles.length(), 2)
  let t = triangles[1]
  // Flag 1: the new vertex forms a triangle with the last two vertices.
  assert_eq(t.p0.point, @kurbo.Point::new(10.0, 0.0))
  assert_eq(t.p1.point, @kurbo.Point::new(0.0, 10.0))
  assert_eq(t.p2.point, @kurbo.Point::new(10.0, 10.0))
  assert_eq(t.p2.colors, [1.0])
  // A flag-1 vertex without a previous triangle fails the whole mesh.
  assert_true(
    read_free_form_triangles(b"\x01\x00\x00\x00", 8, 8, 8, false, [
      0.0, 255.0, 0.0, 255.0, 0.0, 1.0,
    ])
    is None,
  )
}

///|
test "lattice triangle mesh" {
  // VerticesPerRow 2, two rows -> 2 triangles; a trailing partial row is
  // ignored.
  let data = b"\x00\x00\x00\x0a\x00\xff\x00\x0a\x80\x0a\x0a\xff\x05"
  let triangles = read_lattice_triangles(data, 8, 8, false, 2, [
    0.0, 255.0, 0.0, 255.0, 0.0, 1.0,
  ]).unwrap()
  assert_eq(triangles.length(), 2)
  assert_eq(
    read_lattice_triangles(data, 8, 8, false, 0, [
      0.0, 255.0, 0.0, 255.0, 0.0, 1.0,
    ])
    .unwrap()
    .length(),
    0,
  )
}

///|
test "coons patch corners" {
  let pts : Array[@kurbo.Point] = [
    (0.0, 0.0),
    (0.0, 3.0),
    (0.0, 6.0),
    (0.0, 9.0),
    (3.0, 9.0),
    (6.0, 9.0),
    (9.0, 9.0),
    (9.0, 6.0),
    (9.0, 3.0),
    (9.0, 0.0),
    (6.0, 0.0),
    (3.0, 0.0),
  ].map(p => @kurbo.Point::new(p.0, p.1))
  let patch : CoonsPatch = {
    control_points: FixedArray::from_array(pts),
    colors: [[0.0], [1.0], [0.5], [0.25]],
  }
  // The corners of the unit square map to the patch corners.
  assert_eq(
    patch.map_coordinate(@kurbo.Point::new(0.0, 0.0)),
    @kurbo.Point::new(0.0, 0.0),
  )
  assert_eq(
    patch.map_coordinate(@kurbo.Point::new(1.0, 1.0)),
    @kurbo.Point::new(9.0, 9.0),
  )
  assert_eq(patch.interpolate(@kurbo.Point::new(0.0, 1.0)), [1.0])
  assert_eq(patch.interpolate(@kurbo.Point::new(1.0, 0.0)), [0.25])
  let triangles = []
  patch.to_triangles(triangles)
  assert_eq(triangles.length(), 19 * 19 * 2)
}

///|
test "radial_pos" {
  // Concentric circles r0 = 0, r1 = 10.
  let p1 = @kurbo.Point::new(0.0, 0.0)
  let r = @kurbo.Point::new(0.0, 10.0)
  assert_eq(
    radial_pos(@kurbo.Point::new(5.0, 0.0), p1, r, false, false),
    Some(0.5),
  )
  assert_eq(radial_pos(@kurbo.Point::new(20.0, 0.0), p1, r, false, false), None)
  assert_eq(
    radial_pos(@kurbo.Point::new(20.0, 0.0), p1, r, false, true),
    Some(2.0),
  )
}

///|
test "f32 total order" {
  let values : Array[Float] = [1.0, -0.0, 0.0, -1.0, 0.5]
  values.sort_by((a, b) => f32_total_cmp_key(a).compare(f32_total_cmp_key(b)))
  assert_eq(values.map(v => v.reinterpret_as_uint()), [
    (-1.0 : Float).reinterpret_as_uint(),
    (-0.0 : Float).reinterpret_as_uint(),
    (0.0 : Float).reinterpret_as_uint(),
    (0.5 : Float).reinterpret_as_uint(),
    (1.0 : Float).reinterpret_as_uint(),
  ])
}

///|
test "gradient stop approximation" {
  // A linear ramp needs no subdivision.
  let linear = approximate_gradient_stops(t => [t, 0.0, 1.0 - t, 1.0], [], 0.01)
  assert_eq(linear.map(s => s.offset), [0.0, 1.0])
  // Breakpoints start new intervals.
  let stitched = approximate_gradient_stops(
    t => [t, 0.0, 1.0 - t, 1.0],
    [0.25],
    0.01,
  )
  assert_eq(stitched.map(s => s.offset), [0.0, 0.25, 0.25, 1.0])
  // A step function is subdivided down to the maximum depth around the step.
  let step = approximate_gradient_stops(
    t => if t < 0.3 { [0.0, 0.0, 0.0, 1.0] } else { [1.0, 1.0, 1.0, 1.0] },
    [],
    0.01,
  )
  assert_eq(step[0].offset, 0.0)
  assert_eq(step[step.length() - 1].offset, 1.0)
  assert_eq(step.length(), 12)
  assert_eq(color_error([0.0, 0.5, 0.25, 1.0], [0.0, 0.0, 0.5, 1.0]), 0.5)
}
