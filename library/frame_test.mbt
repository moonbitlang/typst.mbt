// Tests of the value semantics of frames (copy-on-write like upstream's
// `Arc<LazyHash<Vec<..>>>`).

///|
fn pt(v : Double) -> @library.Abs {
  @library.Abs::pt(v)
}

///|
fn line_item() -> @library.FrameItem {
  Shape(
    @library.Geometry::Line(@library.Point::with_x(pt(1.0))).stroked(
      @library.FixedStroke::default(),
    ),
    @syntax.Span::detached(),
  )
}

///|
fn positions(frame : @library.Frame) -> Array[Double] {
  frame.items().iter().map(e => e.0.x.to_pt()).collect()
}

///|
test "clone is copy-on-write" {
  let a = @library.Frame::soft(@library.Axes::new(pt(10.0), pt(10.0)))
  a.push(@library.Point::zero(), line_item())
  let b = a.clone()
  b.push(@library.Point::with_x(pt(2.0)), line_item())
  a.translate(@library.Point::with_x(pt(1.0)))
  inspect(positions(a), content="[1]")
  inspect(positions(b), content="[0, 2]")
}

///|
test "nested groups are copied on write" {
  let inner = @library.Frame::soft(@library.Axes::new(pt(5.0), pt(5.0)))
  inner.push(@library.Point::zero(), line_item())
  let outer = @library.Frame::hard(@library.Axes::new(pt(10.0), pt(10.0)))
  outer.push(@library.Point::zero(), Group(@library.GroupItem::new(inner)))
  let copy = outer.clone()
  // Hiding mutates the group's frame in place, which must not leak into the
  // clone.
  outer.hide()
  inspect(outer.items().length(), content="0")
  guard copy.items()[0].1 is Group(group) else { fail("expected a group") }
  inspect(group.frame.items().length(), content="1")
}

///|
test "push_frame inlines small soft frames" {
  let child = @library.Frame::soft(@library.Axes::new(pt(5.0), pt(5.0)))
  child.push(@library.Point::with_x(pt(1.0)), line_item())
  let parent = @library.Frame::soft(@library.Axes::new(pt(10.0), pt(10.0)))
  parent.push(@library.Point::zero(), line_item())
  parent.push_frame(@library.Point::with_x(pt(2.0)), child)
  inspect(positions(parent), content="[0, 3]")
  // Hard frames become groups.
  let hard = @library.Frame::hard(@library.Axes::new(pt(5.0), pt(5.0)))
  hard.push(@library.Point::zero(), line_item())
  parent.push_frame(@library.Point::zero(), hard)
  inspect(parent.items()[2].1 is Group(_), content="true")
}

///|
test "transform wraps the contents in a group" {
  let frame = @library.Frame::soft(@library.Axes::new(pt(10.0), pt(10.0)))
  frame.set_baseline(pt(8.0))
  frame.push(@library.Point::zero(), line_item())
  frame.transform(
    @library.Transform::scale(@library.Ratio::new(2.0), @library.Ratio::one()),
  )
  inspect(frame.items().length(), content="1")
  inspect(frame.baseline().to_pt(), content="8")
  guard frame.items()[0].1 is Group(group) else { fail("expected a group") }
  inspect(group.transform.sx.get(), content="2")
  inspect(group.frame.items().length(), content="1")
}

///|
test "resize translates by alignment" {
  let frame = @library.Frame::soft(@library.Axes::new(pt(10.0), pt(10.0)))
  frame.set_baseline(pt(5.0))
  frame.push(@library.Point::zero(), line_item())
  let offset = frame.resize(
    @library.Axes::new(pt(20.0), pt(30.0)),
    @library.Axes::new(
      @library.FixedAlignment::Center,
      @library.FixedAlignment::End,
    ),
  )
  inspect((offset.x.to_pt(), offset.y.to_pt()), content="(5, 20)")
  inspect(frame.baseline().to_pt(), content="25")
  inspect(positions(frame), content="[5]")
}

///|
test "regions" {
  let regions : @library.Regions = {
    ..@library.Regions::repeat(
      @library.Axes::new(pt(10.0), pt(100.0)),
      @library.Axes::splat(false),
    ),
    backlog: [pt(50.0), pt(60.0)][:],
  }
  let heights = regions.iter().take(5).map(s => s.y.to_pt()).collect()
  inspect(heights, content="[100, 50, 60, 100, 100]")
  let next = regions.next()
  inspect((next.size.y.to_pt(), next.full.to_pt()), content="(50, 50)")
  inspect(regions.size.y.to_pt(), content="100")
  inspect(
    @library.Regions::from_region(
      @library.LayoutRegion::new(
        @library.Axes::new(pt(10.0), pt(20.0)),
        @library.Axes::splat(true),
      ),
    ).may_break(),
    content="false",
  )
}
