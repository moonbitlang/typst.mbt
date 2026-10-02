// Canonical formatters for `oracle_test.mbt` (mirrors the ones in
// `oracle/src/bin/gen_svgtypes_tests.rs`).

///|
fn f(x : Double) -> String {
  let bits = x.reinterpret_as_uint64()
  let hex = "0123456789abcdef"
  let sb = StringBuilder()
  for i = 15; i >= 0; i = i - 1 {
    let d = ((bits >> (i * 4)) & 0xFUL).to_int()
    sb.write_char(hex.get_char(d).unwrap())
  }
  sb.to_string()
}

///|
fn b(x : Bool) -> String {
  if x {
    "t"
  } else {
    "f"
  }
}

///|
fn err(e : &Show) -> String {
  "E(\{e.to_string()})"
}

///|
fn color(c : @svgtypes.Color) -> String {
  "rgba(\{c.red.to_int()},\{c.green.to_int()},\{c.blue.to_int()},\{c.alpha.to_int()})"
}

///|
fn unit(u : @svgtypes.LengthUnit) -> String {
  match u {
    None => "None"
    Em => "Em"
    Ex => "Ex"
    Px => "Px"
    In => "In"
    Cm => "Cm"
    Mm => "Mm"
    Pt => "Pt"
    Pc => "Pc"
    Percent => "Percent"
  }
}

///|
fn length(l : @svgtypes.Length) -> String {
  "L(\{f(l.number)},\{unit(l.unit)})"
}

///|
fn angle_unit(u : @svgtypes.AngleUnit) -> String {
  match u {
    Degrees => "Degrees"
    Gradians => "Gradians"
    Radians => "Radians"
    Turns => "Turns"
  }
}

///|
fn angle(a : @svgtypes.Angle) -> String {
  "A(\{f(a.number)},\{angle_unit(a.unit)})"
}

///|
fn opt_str(s : String?) -> String {
  match s {
    Some(s) => "S(\{s})"
    None => "N"
  }
}

///|
fn[T] seq(next : () -> T?, fmt : (T) -> String) -> String {
  let out = []
  for _ in 0..<1000 {
    match next() {
      Some(v) => out.push(fmt(v))
      None => return out.join(";")
    }
  }
  out.push("...")
  out.join(";")
}

///|
fn[T, E : Show] res(r : Result[T, E], fmt : (T) -> String) -> String {
  match r {
    Ok(v) => fmt(v)
    Err(e) => err(e)
  }
}

///|
fn[T, E : Show + Error] run_res(
  f : () -> T raise E,
  fmt : (T) -> String,
) -> String {
  try f() catch {
    e => err(e)
  } noraise {
    v => fmt(v)
  }
}

///|
fn path_segment(s : @svgtypes.PathSegment) -> String {
  match s {
    MoveTo(abs~, x~, y~) => "M(\{b(abs)},\{f(x)},\{f(y)})"
    LineTo(abs~, x~, y~) => "L(\{b(abs)},\{f(x)},\{f(y)})"
    HorizontalLineTo(abs~, x~) => "H(\{b(abs)},\{f(x)})"
    VerticalLineTo(abs~, y~) => "V(\{b(abs)},\{f(y)})"
    CurveTo(abs~, x1~, y1~, x2~, y2~, x~, y~) =>
      "C(\{b(abs)},\{f(x1)},\{f(y1)},\{f(x2)},\{f(y2)},\{f(x)},\{f(y)})"
    SmoothCurveTo(abs~, x2~, y2~, x~, y~) =>
      "S(\{b(abs)},\{f(x2)},\{f(y2)},\{f(x)},\{f(y)})"
    Quadratic(abs~, x1~, y1~, x~, y~) =>
      "Q(\{b(abs)},\{f(x1)},\{f(y1)},\{f(x)},\{f(y)})"
    SmoothQuadratic(abs~, x~, y~) => "T(\{b(abs)},\{f(x)},\{f(y)})"
    EllipticalArc(abs~, rx~, ry~, x_axis_rotation~, large_arc~, sweep~, x~, y~) =>
      "A(\{b(abs)},\{f(rx)},\{f(ry)},\{f(x_axis_rotation)},\{b(large_arc)},\{b(sweep)},\{f(x)},\{f(y)})"
    ClosePath(abs~) => "Z(\{b(abs)})"
  }
}

///|
fn simple_segment(s : @svgtypes.SimplePathSegment) -> String {
  match s {
    MoveTo(x~, y~) => "M(\{f(x)},\{f(y)})"
    LineTo(x~, y~) => "L(\{f(x)},\{f(y)})"
    CurveTo(x1~, y1~, x2~, y2~, x~, y~) =>
      "C(\{f(x1)},\{f(y1)},\{f(x2)},\{f(y2)},\{f(x)},\{f(y)})"
    Quadratic(x1~, y1~, x~, y~) => "Q(\{f(x1)},\{f(y1)},\{f(x)},\{f(y)})"
    ClosePath => "Z"
  }
}

///|
fn transform_token(t : @svgtypes.TransformListToken) -> String {
  match t {
    Matrix(a~, b~, c~, d~, e~, f=ff) =>
      "matrix(\{f(a)},\{f(b)},\{f(c)},\{f(d)},\{f(e)},\{f(ff)})"
    Translate(tx~, ty~) => "translate(\{f(tx)},\{f(ty)})"
    Scale(sx~, sy~) => "scale(\{f(sx)},\{f(sy)})"
    Rotate(angle~) => "rotate(\{f(angle)})"
    SkewX(angle~) => "skewX(\{f(angle)})"
    SkewY(angle~) => "skewY(\{f(angle)})"
  }
}

///|
fn filter_value(v : @svgtypes.FilterValue) -> String {
  match v {
    Blur(l) => "blur(\{length(l)})"
    DropShadow(color=c, dx~, dy~, std_dev~) => {
      let c = match c {
        Some(c) => color(c)
        None => "N"
      }
      "drop-shadow(\{c},\{length(dx)},\{length(dy)},\{length(std_dev)})"
    }
    Brightness(x) => "brightness(\{f(x)})"
    Contrast(x) => "contrast(\{f(x)})"
    Grayscale(x) => "grayscale(\{f(x)})"
    HueRotate(a) => "hue-rotate(\{angle(a)})"
    Invert(x) => "invert(\{f(x)})"
    Opacity(x) => "opacity(\{f(x)})"
    Sepia(x) => "sepia(\{f(x)})"
    Saturate(x) => "saturate(\{f(x)})"
    Url(u) => "url(\{u})"
  }
}

///|
fn paint_fallback(p : @svgtypes.PaintFallback?) -> String {
  match p {
    None => "N"
    Some(None) => "none"
    Some(CurrentColor) => "currentColor"
    Some(Color(c)) => color(c)
  }
}

///|
fn paint(p : @svgtypes.Paint) -> String {
  match p {
    None => "none"
    Inherit => "inherit"
    CurrentColor => "currentColor"
    Color(c) => color(c)
    FuncIRI(l, fb) => "url(\{l},\{paint_fallback(fb)})"
    ContextFill => "context-fill"
    ContextStroke => "context-stroke"
  }
}

///|
fn align(a : @svgtypes.Align) -> String {
  match a {
    None => "None"
    XMinYMin => "XMinYMin"
    XMidYMin => "XMidYMin"
    XMaxYMin => "XMaxYMin"
    XMinYMid => "XMinYMid"
    XMidYMid => "XMidYMid"
    XMaxYMid => "XMaxYMid"
    XMinYMax => "XMinYMax"
    XMidYMax => "XMidYMax"
    XMaxYMax => "XMaxYMax"
  }
}

///|
fn paint_order_kind(k : @svgtypes.PaintOrderKind) -> String {
  match k {
    Fill => "Fill"
    Stroke => "Stroke"
    Markers => "Markers"
  }
}

///|
fn dirpos(d : @svgtypes.DirectionalPosition) -> String {
  match d {
    Top => "Top"
    Center => "Center"
    Bottom => "Bottom"
    Right => "Right"
    Left => "Left"
  }
}

///|
fn run(kind : String, s : String) -> String {
  match kind {
    "number" => run_res(() => @svgtypes.Number::from_str(s), n => f(n.0))
    "number_list" => {
      let p = @svgtypes.NumberListParser::from(s)
      seq(() => p.next(), r => res(r, f))
    }
    "length" => run_res(() => @svgtypes.Length::from_str(s), length)
    "length_list" => {
      let p = @svgtypes.LengthListParser::from(s)
      seq(() => p.next(), r => res(r, length))
    }
    "angle" =>
      run_res(() => @svgtypes.Angle::from_str(s), a => {
        "\{angle(a)}|\{f(a.to_degrees())}"
      })
    "color" => run_res(() => @svgtypes.Color::from_str(s), color)
    "paint" => run_res(() => @svgtypes.Paint::from_str(s), paint)
    "iri" => run_res(() => @svgtypes.IRI::from_str(s), i => "iri(\{i.0})")
    "funciri" =>
      run_res(() => @svgtypes.FuncIRI::from_str(s), i => "funciri(\{i.0})")
    "viewbox" =>
      run_res(() => @svgtypes.ViewBox::from_str(s), v => {
        "vb(\{f(v.x)},\{f(v.y)},\{f(v.w)},\{f(v.h)})"
      })
    "points" => {
      let p = @svgtypes.PointsParser::from(s)
      seq(() => p.next(), xy => "(\{f(xy.0)},\{f(xy.1)})")
    }
    "aspect" =>
      run_res(() => @svgtypes.AspectRatio::from_str(s), a => {
        "ar(\{b(a.defer_)},\{align(a.align)},\{b(a.slice)})"
      })
    "paint_order" => {
      let o = @svgtypes.PaintOrder::from_str(s)
      "\{paint_order_kind(o.order[0])},\{paint_order_kind(o.order[1])},\{paint_order_kind(o.order[2])}"
    }
    "enable_bg" =>
      run_res(() => @svgtypes.EnableBackground::from_str(s), e => {
        match e {
          Accumulate => "accumulate"
          New => "new"
          NewWithRegion(x~, y~, width~, height~) =>
            "new(\{f(x)},\{f(y)},\{f(width)},\{f(height)})"
        }
      })
    "dirpos" =>
      run_res(() => @svgtypes.DirectionalPosition::from_str(s), dirpos)
    "transform_origin" =>
      run_res(() => @svgtypes.TransformOrigin::from_str(s), t => {
        "to(\{length(t.x_offset)},\{length(t.y_offset)},\{length(t.z_offset)})"
      })
    "font_families" =>
      run_res(() => @svgtypes.parse_font_families(s), v => {
        v.map(f => f.to_string()).join("|")
      })
    "font_shorthand" =>
      run_res(() => @svgtypes.FontShorthand::from_str(s), v => {
        "fs(\{opt_str(v.font_style)},\{opt_str(v.font_variant)},\{opt_str(v.font_weight)},\{opt_str(v.font_stretch)},\{v.font_size},\{v.font_family})"
      })
    "transform" =>
      run_res(() => @svgtypes.Transform::from_str(s), t => {
        "ts(\{f(t.a)},\{f(t.b)},\{f(t.c)},\{f(t.d)},\{f(t.e)},\{f(t.f)})"
      })
    "transform_list" => {
      let p = @svgtypes.TransformListParser::from(s)
      seq(() => p.next(), r => res(r, transform_token))
    }
    "filter" => {
      let p = @svgtypes.FilterValueListParser::from(s)
      seq(() => p.next(), r => res(r, filter_value))
    }
    "path" => {
      let p = @svgtypes.PathParser::from(s)
      seq(() => p.next(), r => res(r, path_segment))
    }
    "simple_path" => {
      let p = @svgtypes.SimplifyingPathParser::from(s)
      seq(() => p.next(), r => res(r, simple_segment))
    }
    _ => abort(kind)
  }
}

///|
fn check_cases(kind : String, cases : Array[(String, String)]) -> Unit raise {
  let failures = []
  for case in cases {
    let (input, expected) = case
    let actual = run(kind, input)
    if actual != expected {
      failures.push(
        "\{kind} \{repr(input)}:\n  expected \{expected}\n  actual   \{actual}",
      )
    }
  }
  if !failures.is_empty() {
    let shown = if failures.length() > 20 {
      failures[:20].iter().collect()
    } else {
      failures
    }
    fail(
      "\{failures.length()}/\{cases.length()} failures:\n\{shown.join("\n")}",
    )
  }
}
