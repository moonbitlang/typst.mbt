// Tests of the winding number (`winding.mbt`): the values follow from the
// definition (kurbo counts a clockwise loop in a y-down system as +1).

///|
fn winding_of(path : Array[@kurbo.PathEl], x : Double, y : Double) -> Int {
  @kurbo.BezPath::from_vec(path).winding(@kurbo.Point::new(x, y))
}

///|
test "winding: a square, by its direction" {
  let p = (x : Double, y : Double) => @kurbo.Point::new(x, y)
  let square : Array[@kurbo.PathEl] = [
    MoveTo(p(0, 0)),
    LineTo(p(10, 0)),
    LineTo(p(10, 10)),
    LineTo(p(0, 10)),
    ClosePath,
  ]
  let reversed : Array[@kurbo.PathEl] = [
    MoveTo(p(0, 0)),
    LineTo(p(0, 10)),
    LineTo(p(10, 10)),
    LineTo(p(10, 0)),
    ClosePath,
  ]
  let inside = winding_of(square, 5, 5)
  assert_true(inside == 1 || inside == -1)
  assert_eq(winding_of(reversed, 5, 5), -inside)
  assert_eq(winding_of(square, 15, 5), 0)
  assert_eq(winding_of(square, 5, -1), 0)
  assert_true(@kurbo.BezPath::from_vec(square).contains(p(1, 9)))
  assert_true(!@kurbo.BezPath::from_vec(square).contains(p(-1, 9)))
}

///|
test "winding: two loops add up, a hole cancels" {
  let p = (x : Double, y : Double) => @kurbo.Point::new(x, y)
  let ring = (a : Double, b : Double, forward : Bool) => {
    let corners = [p(a, a), p(b, a), p(b, b), p(a, b)]
    let order = if forward { [0, 1, 2, 3] } else { [0, 3, 2, 1] }
    let path : Array[@kurbo.PathEl] = [MoveTo(corners[order[0]])]
    for k in 1..<4 {
      path.push(LineTo(corners[order[k]]))
    }
    path.push(ClosePath)
    path
  }
  let twice = ring(0, 10, true)
  twice.append(ring(2, 8, true))
  assert_eq(winding_of(twice, 5, 5).abs(), 2)
  assert_eq(winding_of(twice, 1, 5).abs(), 1)
  let holed = ring(0, 10, true)
  holed.append(ring(2, 8, false))
  assert_eq(winding_of(holed, 5, 5), 0)
  assert_eq(winding_of(holed, 1, 5).abs(), 1)
}

///|
test "winding: curves, and an open path is not closed" {
  let p = (x : Double, y : Double) => @kurbo.Point::new(x, y)
  // A circle of radius 10 around (10, 10) from four cubics.
  let k = 5.522847498
  let circle : Array[@kurbo.PathEl] = [
    MoveTo(p(20, 10)),
    CurveTo(p(20, 10.0 + k), p(10.0 + k, 20), p(10, 20)),
    CurveTo(p(10.0 - k, 20), p(0, 10.0 + k), p(0, 10)),
    CurveTo(p(0, 10.0 - k), p(10.0 - k, 0), p(10, 0)),
    CurveTo(p(10.0 + k, 0), p(20, 10.0 - k), p(20, 10)),
    ClosePath,
  ]
  assert_eq(winding_of(circle, 10, 10).abs(), 1)
  assert_eq(winding_of(circle, 17, 17).abs(), 1)
  assert_eq(winding_of(circle, 18.5, 18.5), 0)
  assert_eq(winding_of(circle, 1, 1), 0)
  // A quadratic arch over the x axis, closed by a line.
  let arch : Array[@kurbo.PathEl] = [
    MoveTo(p(0, 0)),
    QuadTo(p(5, 10), p(10, 0)),
    ClosePath,
  ]
  assert_eq(winding_of(arch, 5, 2).abs(), 1)
  assert_eq(winding_of(arch, 5, 6), 0)
  // Two sides of a triangle. The missing third side is not added: a
  // point that the closed triangle contains is outside.
  let open : Array[@kurbo.PathEl] = [
    MoveTo(p(0, 0)),
    LineTo(p(10, 0)),
    LineTo(p(10, 10)),
  ]
  assert_eq(winding_of(open, 8, 2), 0)
  let closed = open.copy()
  closed.push(ClosePath)
  assert_eq(winding_of(closed, 8, 2).abs(), 1)
}
