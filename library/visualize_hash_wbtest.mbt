// The fingerprints of paints, strokes, frames, modules and closures cover
// what upstream's `Hash` covers (`visualize_hash.mbt`, `value_hash.mbt`):
// values that differ in any hashed field have fingerprints of their own,
// and no fingerprint is marked lossy. What upstream itself reports for such
// values is in `typst/oracle_wbtest.mbt`.

///|
/// The fingerprint of a value and the flags of its computation.
fn[T : Fingerprint] fingerprint_and_flags(value : T) -> (U128, Int) {
  let mut hash = u128_zero
  let flags = fingerprint_flags_in(() => hash = hash128(value))
  (hash, flags)
}

///|
/// Asserts that the values have pairwise distinct, exact fingerprints.
fn[T : Fingerprint] assert_distinct(values : Array[T]) -> Unit raise {
  let hashes = []
  for value in values {
    let (hash, flags) = fingerprint_and_flags(value)
    assert_eq(flags, 0)
    assert_false(hashes.contains(hash))
    hashes.push(hash)
  }
}

///|
fn test_rgb(red : Float) -> Color {
  Process(Rgb({ red, green: 0.0, blue: 0.0, alpha: 1.0, }))
}

///|
fn test_linear(offset : Double, angle : Double) -> Gradient {
  Linear({
    stops: [
      (color_red, Ratio::zero()),
      (color_blue, Ratio::new(offset)),
      (color_green, Ratio::one()),
    ],
    angle: Angle::deg(angle),
    space: Process(Oklab),
    relative: Auto,
    anti_alias: true,
  })
}

///|
fn default_stroke() -> Stroke {
  Default::default()
}

///|
fn test_stroke(thickness : Double) -> Stroke {
  {
    ..default_stroke(),
    thickness: Custom(Length::from_abs(Abs::pt(thickness))),
  }
}

///|
/// A frame with one filled square.
fn test_frame(fill : Paint) -> Frame {
  let size = Axes::new(Abs::pt(10.0), Abs::pt(10.0))
  let frame = Frame::soft(size)
  frame.push(
    Point::zero(),
    Shape(Geometry::Rect(size).filled(fill), @syntax.Span::detached()),
  )
  frame
}

///|
fn test_tiling(frame : Frame) -> Tiling {
  {
    frame,
    size: frame.size(),
    spacing: Axes::new(Abs::zero(), Abs::zero()),
    offset: Axes::new(Abs::zero(), Abs::zero()),
    angle: Angle::zero(),
    relative: Auto,
    frame_hash: LazyFingerprint::new(),
  }
}

///|
test "fingerprints of colours cover their components" {
  // Equal as sRGB colours (8 bits per channel), but not the same data.
  assert_true(test_rgb(0.10001) == test_rgb(0.10002))
  assert_distinct([test_rgb(0.10001), test_rgb(0.10002)])
  assert_distinct([
    Value::Color(test_rgb(0.10001)),
    Color(test_rgb(0.10002)),
    Color(color_black),
    Color(
      Process(LinearRgb({ red: 0.10001, green: 0.0, blue: 0.0, alpha: 1.0, })),
    ),
  ])
  let colorant = (c : Float) => {
    let fallback : ProcessColor = Cmyk({ c, m: 0.0, y: 0.0, k: 0.0, })
    { name: Some(SpotColorantName::Custom("A")), fallback, }
  }
  assert_distinct([
    Value::Dyn(SpotColorant(colorant(0.10001))),
    Dyn(SpotColorant(colorant(0.10002))),
    Dyn(SpotColorant({ ..colorant(0.10001), name: Some(All), })),
    Dyn(SpotColorant({ ..colorant(0.10001), name: None, })),
    Color(Spot({ colorant: colorant(0.10001), tint: Ratio::new(0.5), })),
    Color(Spot({ colorant: colorant(0.10001), tint: Ratio::new(0.50001), })),
  ])
}

///|
test "fingerprints of gradients and strokes cover their data" {
  // The reprs of these values are equal.
  assert_eq(
    Value::Gradient(test_linear(0.10001, 0.0)).repr(),
    Value::Gradient(test_linear(0.10002, 0.0)).repr(),
  )
  assert_distinct([
    Value::Gradient(test_linear(0.10001, 0.0)),
    Gradient(test_linear(0.10002, 0.0)),
    Gradient(test_linear(0.10001, 0.00001)),
  ])
  assert_eq(
    hash128(Value::Gradient(test_linear(0.1, 0.0))),
    hash128(Value::Gradient(test_linear(0.1, 0.0))),
  )
  let dash = (length : Double, phase : Double) => {
    let pattern : DashPattern = {
      array: [Length(Length::from_abs(Abs::pt(length))), LineWidth],
      phase: Length::from_abs(Abs::pt(phase)),
    }
    { ..default_stroke(), dash: Custom(Some(pattern)), }
  }
  assert_distinct([
    Value::Dyn(Stroke(test_stroke(1.00001))),
    Dyn(Stroke(test_stroke(1.00002))),
    Dyn(Stroke(default_stroke())),
    Dyn(Stroke({ ..default_stroke(), dash: Custom(None), })),
    Dyn(Stroke(dash(1.00001, 0.0))),
    Dyn(Stroke(dash(1.00002, 0.0))),
    Dyn(Stroke(dash(1.00001, 0.00001))),
    Dyn(
      Stroke({ ..default_stroke(), miter_limit: Custom(Ratio::new(4.00001)), }),
    ),
    Dyn(
      Stroke({ ..default_stroke(), miter_limit: Custom(Ratio::new(4.00002)), }),
    ),
    Dyn(
      Stroke({
        ..default_stroke(),
        paint: Custom(Gradient(test_linear(0.10001, 0.0))),
      }),
    ),
    Dyn(
      Stroke({
        ..default_stroke(),
        paint: Custom(Gradient(test_linear(0.10002, 0.0))),
      }),
    ),
    Dyn(Stroke({ ..default_stroke(), cap: Custom(Round), })),
    Dyn(Stroke({ ..default_stroke(), join: Custom(Round), })),
  ])
}

///|
test "fingerprints of frames cover their items" {
  let size = Axes::new(Abs::pt(10.0), Abs::pt(10.0))
  let red = () => test_frame(Solid(color_red))
  let group = (f : (GroupItem) -> Unit) => {
    let frame = Frame::soft(size)
    let group = GroupItem::new(red())
    f(group)
    frame.push(Point::zero(), Group(group))
    frame
  }
  let stroked = (thickness : Double) => {
    let frame = Frame::soft(size)
    frame.push(
      Point::zero(),
      Shape(
        Geometry::Line(Point::new(Abs::pt(5.0), Abs::zero())).stroked(
          FixedStroke::from_pair(Solid(color_black), Abs::pt(thickness)),
        ),
        @syntax.Span::detached(),
      ),
    )
    frame
  }
  let hard = red()
  hard.set_kind(Hard)
  let baseline = red()
  baseline.set_baseline(Abs::pt(5.0))
  let moved = Frame::soft(size)
  moved.push(Point::new(Abs::pt(0.00001), Abs::zero()), red().items()[0].1)
  let link = red()
  link.push(Point::zero(), Link(Url(Url("https://typst.app")), size))
  let other_link = red()
  other_link.push(Point::zero(), Link(Url(Url("https://typst.app/")), size))
  let tag = (flags : TagFlags) => {
    let frame = red()
    frame.push(
      Point::zero(),
      Tag(End(Location::new(hash128("a")), u128_zero, flags)),
    )
    frame
  }
  assert_distinct([
    red(),
    test_frame(Solid(color_blue)),
    test_frame(Gradient(test_linear(0.10001, 0.0))),
    test_frame(Gradient(test_linear(0.10002, 0.0))),
    Frame::soft(size),
    hard,
    baseline,
    moved,
    stroked(1.00001),
    stroked(1.00002),
    group(_ => ()),
    group(g => g.transform = Transform::translate(Abs::pt(1.0), Abs::zero())),
    group(g => g.clip = Some(Curve::rect(size))),
    group(g => g.label = Label::new("a")),
    group(g => {
      g.parent = Some(FrameParent::new(Location::new(hash128("a")), Yes))
    }),
    group(g => {
      g.parent = Some(FrameParent::new(Location::new(hash128("a")), No))
    }),
    link,
    other_link,
    tag({ introspectable: true, tagged: false, }),
    tag({ introspectable: true, tagged: true, }),
  ])
  // Equal frames have equal fingerprints, also as copy-on-write clones.
  assert_eq(hash128(red()), hash128(red()))
  let frame = red()
  assert_eq(hash128(frame.clone()), hash128(frame))
}

///|
test "fingerprints of tilings cover their frames" {
  let red = test_tiling(test_frame(Solid(color_red)))
  let blue = test_tiling(test_frame(Solid(color_blue)))
  // The reprs only show the size.
  assert_eq(Value::Tiling(red).repr(), Value::Tiling(blue).repr())
  assert_distinct([
    Value::Tiling(red),
    Tiling(blue),
    Tiling({ ..red, relative: Custom(Parent), }),
    Tiling({ ..red, spacing: Axes::new(Abs::pt(0.00001), Abs::zero()), }),
    Tiling({ ..red, angle: Angle::deg(0.00001), }),
    Tiling(test_tiling(test_frame(Tiling(red)))),
    Tiling(test_tiling(test_frame(Tiling(blue)))),
    Dyn(Stroke({ ..default_stroke(), paint: Custom(Tiling(red)), })),
    Dyn(Stroke({ ..default_stroke(), paint: Custom(Tiling(blue)), })),
  ])
  // A tiling over an equal frame is the same value.
  assert_eq(
    hash128(Value::Tiling(test_tiling(test_frame(Solid(color_red))))),
    hash128(Value::Tiling(red)),
  )
}

///|
test "the fingerprint of a tiling carries the flags of its frame" {
  let call : NativeFn = (_, _, _) => None
  let host = HostFunc::new(hash128("f"), call)
  let elem = TextElem::packed("x").elem()
  let frame = test_frame(Solid(color_red))
  frame.push(
    Point::zero(),
    Tag(
      Start(Content::from_fields(elem, [Some(Func(Func::host(host)))]), {
        introspectable: true,
        tagged: false,
      }),
    ),
  )
  let tiling = test_tiling(frame)
  assert_eq(
    test_tiling(test_frame(Solid(color_red))).frame_fingerprint_flags(),
    0,
  )
  assert_true((tiling.frame_fingerprint_flags() & fingerprint_identity) != 0)
  // Also from the cache, and for the values that hold the tiling.
  let (_, flags) = fingerprint_and_flags(Value::Tiling(tiling))
  assert_true((flags & fingerprint_identity) != 0)
  assert_true((flags & fingerprint_host) != 0)
  assert_false(paint_cacheable(Tiling(tiling)))
  assert_true(
    paint_cacheable(Tiling(test_tiling(test_frame(Solid(color_red))))),
  )
  // A collector of host closures visits the frame although its hash is
  // cached.
  let collect = () => {
    fingerprint_hosts_in(() => hash128(Value::Tiling(tiling)) |> ignore)
  }
  assert_eq(collect().length(), 1)
  assert_true(physical_equal(collect()[0], host))
}

///|
test "fingerprints of modules and closures cover scopes and syntax trees" {
  let scope = (value : Value, span : @syntax.Span) => {
    let scope = Scope::new()
    scope.bind("x", Binding::new(value, span)) |> ignore
    scope
  }
  let detached = @syntax.Span::detached()
  let closure = (node : @syntax.SyntaxNode, captured : Scope) => {
    Value::Func(
      Func::closure({
        node: Closure(node),
        defaults: [],
        captured,
        num_pos_params: 0,
        hash: LazyFingerprint::new(),
      }),
    )
  }
  let hashes = []
  let distinct = (value : Value) => {
    let hash = hash128(value)
    assert_false(hashes.contains(hash))
    hashes.push(hash)
  }
  // Anonymous modules (plugins) are told apart by their scopes, also when
  // a closure captures them.
  let a = Module::anonymous(scope(Int(1), detached))
  let b = Module::anonymous(scope(Int(2), detached))
  distinct(Module(a))
  distinct(Module(b))
  distinct(Module(a.with_name("a")))
  // Modules compare by identity: their fingerprint is flagged like a
  // closure's, also from the cache.
  let other = Module::anonymous(scope(Int(1), detached))
  assert_false(a == other)
  assert_eq(hash128(Value::Module(a)), hash128(Value::Module(other)))
  for _ in 0..<2 {
    let (_, flags) = fingerprint_and_flags(Value::Module(a))
    assert_eq(flags, fingerprint_identity)
  }
  // A module in its own scope (which evaluation cannot build) terminates.
  let cyclic = Scope::new()
  let cycle = Module::anonymous(cyclic)
  cyclic.bind("self", Binding::new(Module(cycle), detached)) |> ignore
  distinct(Module(cycle))
  assert_eq(hash128(Value::Module(cycle)), hash128(Value::Module(cycle)))
  let node = @syntax.parse_code("x")
  distinct(closure(node, scope(Module(a), detached)))
  distinct(closure(node, scope(Module(b), detached)))
  // Captured bindings: the value, the span and the kind.
  distinct(closure(node, scope(Dyn(Stroke(test_stroke(1.00001))), detached)))
  distinct(closure(node, scope(Dyn(Stroke(test_stroke(1.00002))), detached)))
  distinct(closure(node, scope(Int(1), detached)))
  distinct(closure(node, scope(Int(1), @syntax.Span(7))))
  let captured = Scope::new()
  captured.bind("x", Binding::new(Int(1), detached).capture(Function)) |> ignore
  distinct(closure(node, captured))
  let captured = Scope::new()
  captured.bind("x", Binding::new(Int(1), detached).capture(Context)) |> ignore
  distinct(closure(node, captured))
  // The syntax tree: equal text and spans, different nodes.
  let nested = @syntax.parse_code("[- a\n  - b]")
  let flat = @syntax.parse_code("[- a\n- b]")
  assert_false(
    hash128(closure(nested, Scope::new())) ==
    hash128(closure(flat, Scope::new())),
  )
  // The same tree with the same captures is the same hash (closures still
  // compare by identity).
  assert_eq(
    hash128(closure(@syntax.parse_code("x"), scope(Int(1), detached))),
    hash128(closure(node, scope(Int(1), detached))),
  )
}
