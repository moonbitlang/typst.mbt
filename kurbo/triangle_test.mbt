// Tests of `triangle.mbt`/`circle.mbt` (partly from kurbo's `triangle.rs`).

///|
fn assert_approx_eq(
  x : Double,
  y : Double,
  max_relative_error : Double,
) -> Unit raise {
  let m = @kurbo.f64_max(x.abs(), y.abs())
  assert_true((x - y).abs() <= m * max_relative_error, msg="\{x} != \{y}")
}

///|
fn assert_approx_eq_point(
  x : @kurbo.Point,
  y : @kurbo.Point,
  max_relative_error : Double,
) -> Unit raise {
  assert_approx_eq(x.x, y.x, max_relative_error)
  assert_approx_eq(x.y, y.y, max_relative_error)
}

///|
const F64_EPSILON : Double = 2.220446049250313e-16

///|
test "centroid" {
  let t = @kurbo.Triangle::from_coords((-90.02, 3.5), (7.2, -9.3), (8.0, 9.1)).centroid()
  let expected = @kurbo.Point::new(-24.94, 1.1)
  assert_approx_eq_point(t, expected, F64_EPSILON * 100.0)
}

///|
test "area" {
  let t = @kurbo.Triangle::new(
    @kurbo.Point::new(12123.423, 2382.7834),
    @kurbo.Point::new(7892.729, 238.459),
    @kurbo.Point::new(7820.2, 712.23),
  )
  let expected = 1079952.9157407999
  // initial
  assert_approx_eq(t.area(), -expected, F64_EPSILON * 100.0)
  // permutate vertex
  let t = @kurbo.Triangle::new(t.b, t.a, t.c)
  assert_approx_eq(t.area(), expected, F64_EPSILON * 100.0)
}

///|
test "winding" {
  let ccw = @kurbo.Triangle::from_coords((0.0, 0.0), (10.0, 0.0), (0.0, 10.0))
  let cw = @kurbo.Triangle::new(ccw.a, ccw.c, ccw.b)
  let inside = @kurbo.Point::new(2.0, 2.0)
  let outside = @kurbo.Point::new(8.0, 8.0)
  assert_eq(ccw.winding(inside), 1)
  assert_eq(cw.winding(inside), -1)
  assert_eq(ccw.winding(outside), 0)
  assert_eq(cw.winding(outside), 0)
  // Points on an edge have a zero cross product, whose sign is positive.
  assert_eq(ccw.winding(@kurbo.Point::new(5.0, 0.0)), 1)
  assert_eq(cw.winding(@kurbo.Point::new(5.0, 0.0)), 0)
  assert_true(ccw.contains(inside))
  assert_false(ccw.contains(outside))
  // A NaN point is never contained.
  assert_eq(ccw.winding(@kurbo.Point::new(0.0 / 0.0, 1.0)), 0)
}

///|
test "bounding_box" {
  let t = @kurbo.Triangle::from_coords((3.0, -1.0), (-2.0, 5.0), (7.5, 2.0))
  assert_eq(t.bounding_box(), @kurbo.Rect::new(-2.0, -1.0, 7.5, 5.0))
}

///|
test "circle contains" {
  let c = @kurbo.Circle::new(@kurbo.Point::new(1.0, 1.0), 2.0)
  assert_true(c.contains(@kurbo.Point::new(2.0, 2.0)))
  // The boundary is not contained.
  assert_false(c.contains(@kurbo.Point::new(3.0, 1.0)))
  assert_eq(c.winding(@kurbo.Point::new(5.0, 1.0)), 0)
}

///|
test "rect contains" {
  let r = @kurbo.Rect::new(0.0, 0.0, 10.0, 5.0)
  assert_true(r.contains(@kurbo.Point::new(0.0, 0.0)))
  assert_false(r.contains(@kurbo.Point::new(10.0, 2.0)))
  assert_false(r.contains(@kurbo.Point::new(2.0, 5.0)))
  assert_true(r.contains(@kurbo.Point::new(9.99, 4.99)))
}
