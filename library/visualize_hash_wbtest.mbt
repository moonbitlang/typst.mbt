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
        node_hash: LazyFingerprint::new(),
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
  let node0 = @syntax.parse_code("x")
  let a = Module::anonymous(scope(Int(1), detached))
  let b = Module::anonymous(scope(Int(2), detached))
  distinct(Module(a))
  distinct(Module(b))
  distinct(Module(a.with_name("a")))
  // Modules compare by identity. That is a flag of the fingerprint of the
  // modules that it does not identify (anonymous ones), also from the
  // cache, and of what holds them; not of named modules and of the
  // modules of plugins with functions (one object each per compilation).
  let other = Module::anonymous(scope(Int(1), detached))
  assert_false(a == other)
  assert_eq(hash128(Value::Module(a)), hash128(Value::Module(other)))
  for _ in 0..<2 {
    let (_, flags) = fingerprint_and_flags(Value::Module(a))
    assert_eq(flags, fingerprint_identity)
    let (_, flags) = fingerprint_and_flags(
      closure(node0, scope(Module(a), detached)),
    )
    assert_eq(flags, fingerprint_identity)
  }
  let named = Module::new("m", scope(Int(1), detached)).canonical()
  let identified = Module::anonymous(scope(Int(1), detached)).canonical()
  for m in [named, named.with_name("n"), identified, identified.with_name("p")] {
    for _ in 0..<2 {
      let (_, flags) = fingerprint_and_flags(Value::Module(m))
      assert_eq(flags, 0)
      let (_, flags) = fingerprint_and_flags(
        closure(node0, scope(Module(m), detached)),
      )
      assert_eq(flags, 0)
    }
  }
  // A module is canonical because its maker says so: what is made of one
  // is not, nor is a module that is just made.
  for
    m in [
      Module::new("m", scope(Int(1), detached)),
      named.with_scope(scope(Int(1), detached)),
      named.with_content(Content::empty()),
      identified.with_content(Content::empty()),
    ] {
    let (_, flags) = fingerprint_and_flags(Value::Module(m))
    assert_eq(flags, fingerprint_identity)
  }
  // Making a module canonical does not change its hash.
  assert_eq(
    hash128(Value::Module(Module::new("m", scope(Int(1), detached)))),
    hash128(Value::Module(named)),
  )
  // The flag follows the inner data.
  let (_, flags) = fingerprint_and_flags(Value::Module(a.with_name("q")))
  assert_eq(flags, fingerprint_identity)
  // A module in its own scope (which evaluation cannot build) terminates.
  let cyclic = Scope::new()
  let cycle = Module::anonymous(cyclic)
  cyclic.bind("self", Binding::new(Module(cycle), detached)) |> ignore
  distinct(Module(cycle))
  assert_eq(hash128(Value::Module(cycle)), hash128(Value::Module(cycle)))
  // Two modules that hold each other, one of them with a host closure: the
  // module where a cycle closes caches the flags of everything in it, the
  // other one is cached when it is hashed itself, and collecting the host
  // closures leaves both hashes as they are.
  let call : NativeFn = (_, _, _) => None
  let host = HostFunc::new(hash128("f"), call)
  let first_scope = Scope::new()
  let second_scope = Scope::new()
  let first = Module::anonymous(first_scope)
  let second = Module::anonymous(second_scope)
  first_scope.bind("b", Binding::new(Module(second), detached)) |> ignore
  second_scope.bind("a", Binding::new(Module(first), detached)) |> ignore
  second_scope.bind("f", Binding::new(Func(Func::host(host)), detached))
  |> ignore
  let (first_hash, first_flags) = fingerprint_and_flags(Value::Module(first))
  assert_true((first_flags & fingerprint_host) != 0)
  let collect = (m : Module) => {
    fingerprint_hosts_in(() => hash128(Value::Module(m)) |> ignore)
  }
  for _ in 0..<2 {
    for m in [second, first] {
      let hosts = collect(m)
      assert_eq(hosts.length(), 1)
      assert_true(physical_equal(hosts[0], host))
    }
  }
  let (second_hash, second_flags) = fingerprint_and_flags(Value::Module(second))
  assert_true((second_flags & fingerprint_host) != 0)
  assert_eq(
    fingerprint_and_flags(Value::Module(first)),
    (first_hash, first_flags),
  )
  assert_eq(collect(first).length(), 1)
  assert_eq(hash128(Value::Module(first)), first_hash)
  assert_eq(hash128(Value::Module(second)), second_hash)
  // The same through content, which caches the hash of its fields: content
  // in the inner module that holds the outer one is cut short while the
  // outer module is hashed, and must not keep that result.
  let elem = TextElem::packed("x").elem()
  let outer_scope = Scope::new()
  let inner_scope = Scope::new()
  let outer = Module::anonymous(outer_scope)
  let inner = Module::anonymous(inner_scope)
  let back = Content::from_fields(elem, [Some(Module(outer))])
  outer_scope.bind("b", Binding::new(Module(inner), detached)) |> ignore
  outer_scope.bind("f", Binding::new(Func(Func::host(host)), detached))
  |> ignore
  inner_scope.bind("c", Binding::new(Content(back), detached)) |> ignore
  let (outer_hash, outer_flags) = fingerprint_and_flags(Value::Module(outer))
  assert_true((outer_flags & fingerprint_host) != 0)
  for _ in 0..<2 {
    for m in [inner, outer] {
      let hosts = collect(m)
      assert_eq(hosts.length(), 1)
      assert_true(physical_equal(hosts[0], host))
    }
    let (_, back_flags) = fingerprint_and_flags(Value::Content(back))
    assert_true((back_flags & fingerprint_host) != 0)
    let (_, inner_flags) = fingerprint_and_flags(Value::Module(inner))
    assert_true((inner_flags & fingerprint_host) != 0)
    assert_eq(hash128(Value::Module(outer)), outer_hash)
  }
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
  // The same tree with the same captures is the same hash, and closures
  // with the same hash are equal (upstream `Arc<LazyHash<Closure>>`).
  let one = closure(@syntax.parse_code("x"), scope(Int(1), detached))
  let other = closure(node, scope(Int(1), detached))
  assert_eq(hash128(one), hash128(other))
  assert_true(one == other)
  assert_true(one == one)
  assert_false(one == closure(node, scope(Int(2), detached)))
  assert_false(one == closure(node, scope(Float(1.0), detached)))
  assert_false(one == closure(nested, scope(Int(1), detached)))
  // A closure's fingerprint carries no flags of its own, only those of what
  // it captured.
  assert_eq(fingerprint_and_flags(one).1, 0)
}

///|
test "fingerprints of symbols cover the variants that the repr hides" {
  let variant = (modifiers : String, value : String) => {
    let data : SymbolVariantData = (
      ModifierSet::from_raw_dotted(modifiers),
      value,
      None,
    )
    data
  }
  let kept = (hidden : SymbolVariantData) => {
    Value::Symbol({
      inner: Modified({
        list: Runtime([hidden, variant("keep", "K")]),
        modifiers: ModifierSet::from_raw_dotted("keep"),
        deprecated: false,
      }),
    })
  }
  let a = kept(variant("", "ab\u{301}"))
  let b = kept(variant("", "a"))
  assert_eq(a.repr(), b.repr())
  assert_false(a == b)
  assert_distinct([
    a,
    b,
    kept(variant("x", "a")),
    Symbol({ inner: Single("K"), }),
    Symbol({ inner: Complex([variant("", "K")]), }),
    Symbol({
      inner: Modified({
        list: Static([variant("", "K")]),
        modifiers: ModifierSet::default(),
        deprecated: false,
      }),
    }),
    Symbol({
      inner: Modified({
        list: Runtime([variant("", "K")]),
        modifiers: ModifierSet::default(),
        deprecated: false,
      }),
    }),
    Symbol({
      inner: Modified({
        list: Runtime([variant("", "K")]),
        modifiers: ModifierSet::default(),
        deprecated: true,
      }),
    }),
  ])
  // Durations below one second have one repr.
  let half = Value::Duration(Duration(@time.Duration::seconds_f64(0.5)))
  let quarter = Value::Duration(Duration(@time.Duration::seconds_f64(0.25)))
  assert_eq(half.repr(), quarter.repr())
  assert_distinct([half, quarter])
}
