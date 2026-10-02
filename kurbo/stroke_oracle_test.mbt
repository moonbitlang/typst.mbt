// Differential tests against kurbo 0.13.1's stroke expansion, dashing,
// offset curves, arcs, arclength and nearest-point computations. The
// expected results (bit-exact f64s) are recorded in
// `testdata/stroke_oracle.tsv` by `oracle/src/bin/gen_kurbo_stroke_tests.rs`
// (see there for the format and the regeneration command).

///|
fn module_root() -> String? {
  for prefix in ["", "../", "../../", "../../../"] {
    if @fs.path_exists(prefix + "moon.mod") {
      return Some(prefix)
    }
  }
  None
}

///|
fn fnv1a64(s : String) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for c in s {
    // The serialization is ASCII.
    h = h ^ c.to_int().to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
fn hex16(v : UInt64) -> String {
  let digits = "0123456789abcdef"
  let buf = StringBuilder()
  for i = 15; i >= 0; i = i - 1 {
    buf.write_char(digits[((v >> (i * 4)) & 0xfUL).to_int()].unsafe_to_char())
  }
  buf.to_string()
}

///|
fn hx(v : Double) -> String {
  // NaN signs/payloads are not preserved by LLVM, so all NaNs compare equal.
  if v.is_nan() {
    return "nan"
  }
  hex16(v.reinterpret_as_uint64())
}

///|
fn parse_hex(s : StringView) -> Double {
  if s == "nan" {
    return 0x7FF8000000000000UL.reinterpret_as_double()
  }
  let mut v = 0UL
  for c in s {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else {
      c.to_int() - 'a'.to_int() + 10
    }
    v = (v << 4) | d.to_uint64()
  }
  v.reinterpret_as_double()
}

///|
fn clamp_len(len : Int, n : Int) -> Int {
  if len < n {
    len
  } else {
    n
  }
}

///|
fn digest(s : String) -> String {
  if s.length() <= 600 {
    return s
  }
  "#\{s.length()} \{hex16(fnv1a64(s))} \{s.view(end_offset=200)}"
}

///|
fn pt_str(buf : StringBuilder, p : @kurbo.Point) -> Unit {
  buf.write_string(" ")
  buf.write_string(hx(p.x))
  buf.write_string(" ")
  buf.write_string(hx(p.y))
}

///|
fn path_str(els : Iter[@kurbo.PathEl]) -> String {
  let buf = StringBuilder()
  let mut first = true
  while els.next() is Some(el) {
    if !first {
      buf.write_string(" ")
    }
    first = false
    match el {
      MoveTo(p) => {
        buf.write_string("M")
        pt_str(buf, p)
      }
      LineTo(p) => {
        buf.write_string("L")
        pt_str(buf, p)
      }
      QuadTo(p1, p2) => {
        buf.write_string("Q")
        pt_str(buf, p1)
        pt_str(buf, p2)
      }
      CurveTo(p1, p2, p3) => {
        buf.write_string("C")
        pt_str(buf, p1)
        pt_str(buf, p2)
        pt_str(buf, p3)
      }
      ClosePath => buf.write_string("Z")
    }
  }
  if first {
    "-"
  } else {
    buf.to_string()
  }
}

///|
fn nums_str(v : Array[Double]) -> String {
  if v.is_empty() {
    return "-"
  }
  v.map(hx).join(" ")
}

///|
fn seg_str(seg : @kurbo.PathSeg) -> String {
  let buf = StringBuilder()
  match seg {
    Line(l) => {
      buf.write_string("L")
      pt_str(buf, l.p0)
      pt_str(buf, l.p1)
    }
    Quad(q) => {
      buf.write_string("Q")
      pt_str(buf, q.p0)
      pt_str(buf, q.p1)
      pt_str(buf, q.p2)
    }
    Cubic(c) => {
      buf.write_string("C")
      pt_str(buf, c.p0)
      pt_str(buf, c.p1)
      pt_str(buf, c.p2)
      pt_str(buf, c.p3)
    }
  }
  buf.to_string()
}

///|
fn tokens(s : String) -> Array[StringView] {
  if s == "-" {
    return []
  }
  s.split(" ").to_array()
}

///|
fn nums_of(s : String) -> Array[Double] {
  tokens(s).map(parse_hex)
}

///|
fn parse_path(s : String) -> Array[@kurbo.PathEl] {
  let toks = tokens(s)
  let els : Array[@kurbo.PathEl] = []
  let mut i = 0
  let pt = (j : Int) => {
    @kurbo.Point::new(parse_hex(toks[j]), parse_hex(toks[j + 1]))
  }
  while i < toks.length() {
    match toks[i] {
      "M" => {
        els.push(MoveTo(pt(i + 1)))
        i += 3
      }
      "L" => {
        els.push(LineTo(pt(i + 1)))
        i += 3
      }
      "Q" => {
        els.push(QuadTo(pt(i + 1), pt(i + 3)))
        i += 5
      }
      "C" => {
        els.push(CurveTo(pt(i + 1), pt(i + 3), pt(i + 5)))
        i += 7
      }
      "Z" => {
        els.push(ClosePath)
        i += 1
      }
      t => abort("bad path token \{t}")
    }
  }
  els
}

///|
fn parse_seg(s : String) -> @kurbo.PathSeg {
  let toks = tokens(s)
  let pt = (j : Int) => {
    @kurbo.Point::new(parse_hex(toks[j]), parse_hex(toks[j + 1]))
  }
  match toks[0] {
    "L" => Line(@kurbo.Line::new(pt(1), pt(3)))
    "Q" => Quad(@kurbo.QuadBez::new(pt(1), pt(3), pt(5)))
    "C" => Cubic(@kurbo.CubicBez::new(pt(1), pt(3), pt(5), pt(7)))
    t => abort("bad segment token \{t}")
  }
}

///|
fn parse_join(s : String) -> @kurbo.Join {
  match s {
    "bevel" => Bevel
    "miter" => Miter
    _ => Round
  }
}

///|
fn parse_cap(s : String) -> @kurbo.Cap {
  match s {
    "butt" => Butt
    "square" => Square
    _ => Round
  }
}

///|
/// The style fields `w join miter start_cap end_cap dash_offset dashes`
/// starting at `parts[1]`.
fn parse_style(parts : Array[String]) -> @kurbo.Stroke {
  @kurbo.Stroke::new(parse_hex(parts[1]))
  .with_join(parse_join(parts[2]))
  .with_miter_limit(parse_hex(parts[3]))
  .with_start_cap(parse_cap(parts[4]))
  .with_end_cap(parse_cap(parts[5]))
  .with_dashes(parse_hex(parts[6]), nums_of(parts[7]))
}

///|
/// Runs one oracle line; returns the actual (digested) output.
fn run_case(parts : Array[String], ctx : @kurbo.StrokeCtx) -> String {
  match parts[0] {
    "solve_cubic" => {
      let c = nums_of(parts[1])
      nums_str(@kurbo.solve_cubic(c[0], c[1], c[2], c[3]))
    }
    "arc" => {
      let a = nums_of(parts[1])
      let arc = @kurbo.Arc::new(
        @kurbo.Point::new(a[0], a[1]),
        @kurbo.Vec2::new(a[2], a[3]),
        a[4],
        a[5],
        a[6],
      )
      let it = arc.append_iter(parse_hex(parts[2]))
      path_str(Iter::new(() => it.next()))
    }
    "arclen" => hx(parse_seg(parts[1]).arclen(parse_hex(parts[2])))
    "inv_arclen" =>
      hx(
        parse_seg(parts[1]).inv_arclen(parse_hex(parts[2]), parse_hex(parts[3])),
      )
    "subsegment" =>
      seg_str(
        parse_seg(parts[1]).subsegment(parse_hex(parts[2]), parse_hex(parts[3])),
      )
    "nearest" => {
      let q = @kurbo.Point::new(parse_hex(parts[2]), parse_hex(parts[3]))
      let n = match parse_seg(parts[1]) {
        Line(l) => l.nearest(q, 1.0e-9)
        Quad(qb) => qb.nearest(q, 1.0e-9)
        Cubic(_) => abort("cubic nearest")
      }
      "\{hx(n.distance_sq)} \{hx(n.t)}"
    }
    "inflections" =>
      match parse_seg(parts[1]) {
        Cubic(c) => nums_str(c.inflections())
        _ => abort("inflections")
      }
    "offset" =>
      match parse_seg(parts[1]) {
        Cubic(c) => {
          let r = @kurbo.BezPath::new()
          @kurbo.offset_cubic(c, parse_hex(parts[2]), parse_hex(parts[3]), r)
          path_str(r.iter())
        }
        _ => abort("offset")
      }
    "dash" => {
      let path = parse_path(parts[3])
      path_str(@kurbo.dash(path.iter(), parse_hex(parts[1]), nums_of(parts[2])))
    }
    "stroke" | "stroke_stable" => {
      let style = parse_style(parts)
      let opts = @kurbo.StrokeOpts::default().stable_dash_order(
        parts[0] == "stroke_stable",
      )
      let path = parse_path(parts[9])
      @kurbo.stroke_with(path.iter(), style, opts, parse_hex(parts[8]), ctx)
      path_str(ctx.output().iter())
    }
    "stroke_fresh" => {
      let style = parse_style(parts)
      let path = parse_path(parts[9])
      let out = @kurbo.stroke(
        path.iter(),
        style,
        @kurbo.StrokeOpts::default(),
        parse_hex(parts[8]),
      )
      path_str(out.iter())
    }
    op => abort("unknown op \{op}")
  }
}

///|
test "kurbo stroke oracle" {
  guard module_root() is Some(root) else { return }
  let path = root + "kurbo/testdata/stroke_oracle.tsv"
  guard @fs.path_exists(path) else { return }
  let data = @fs.read_file_to_string(path)
  let ctx = @kurbo.StrokeCtx::new()
  let mut total = 0
  let mut passed = 0
  let failed_ops : Map[String, Int] = Map([])
  for line in data.split("\n") {
    if line.is_empty() {
      continue
    }
    let parts = line.split("\t").map(p => p.to_owned()).to_array()
    let expected = parts[parts.length() - 1]
    let actual = digest(run_case(parts, ctx))
    total += 1
    if actual == expected {
      passed += 1
    } else {
      let n = failed_ops.get(parts[0]).unwrap_or(0)
      failed_ops[parts[0]] = n + 1
      if total - passed <= 5 {
        println(
          "MISMATCH line \{total}: \{line.view(end_offset=clamp_len(line.length(), 300))}",
        )
        println(
          "  actual: \{actual.view(end_offset=clamp_len(actual.length(), 300))}",
        )
      }
    }
  }
  println("kurbo stroke oracle: \{passed}/\{total} passed")
  if passed != total {
    for op, n in failed_ops {
      println("  \{op}: \{n} failed")
    }
  }
  assert_eq(passed, total)
}
