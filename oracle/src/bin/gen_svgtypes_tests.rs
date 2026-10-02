//! Generates `svgtypes/oracle_test.mbt`: the real `svgtypes` 0.16.1 crate
//! run over a corpus of inputs (the crate's own test cases, edge cases and
//! pseudo-random inputs). Each case is an input string and the expected
//! canonical rendering of the result (floats as `to_bits()` hex, errors as
//! their `Display`), which the MoonBit test reproduces with the same
//! formatters.
//!
//! Usage: `cargo run --release --offline --bin gen_svgtypes_tests > ../svgtypes/oracle_test.mbt && moon fmt`

use std::fmt::Write as _;
use std::str::FromStr;

use svgtypes::*;

/// Escape a string as a MoonBit string literal (long strings are split into
/// a concatenation to keep lines short).
fn lit(s: &str) -> String {
    let mut out = String::from("\"");
    let mut col = 0;
    for c in s.chars() {
        col += 1;
        if col > 1000 && (c == ';' || c == ',') {
            out.push_str("\" +\n      \"");
            col = 0;
        }
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\t' => out.push_str("\\t"),
            '\r' => out.push_str("\\r"),
            '\'' | ' ' => out.push(c),
            c if c.escape_debug().count() == 1 => out.push(c),
            c => write!(out, "\\u{{{:X}}}", c as u32).unwrap(),
        }
    }
    out.push('"');
    out
}

// ---------------------------------------------------------------------------
// Canonical formatters (mirrored in the MoonBit test prelude).

fn f(x: f64) -> String {
    format!("{:016x}", x.to_bits())
}

fn b(x: bool) -> &'static str {
    if x { "t" } else { "f" }
}

fn err(e: impl std::fmt::Display) -> String {
    format!("E({e})")
}

fn color(c: &Color) -> String {
    format!("rgba({},{},{},{})", c.red, c.green, c.blue, c.alpha)
}

fn length(l: &Length) -> String {
    format!("L({},{:?})", f(l.number), l.unit)
}

fn angle(a: &Angle) -> String {
    format!("A({},{:?})", f(a.number), a.unit)
}

fn opt_str(s: Option<&str>) -> String {
    match s {
        Some(s) => format!("S({s})"),
        None => "N".into(),
    }
}

fn seq<T>(mut next: impl FnMut() -> Option<T>, mut fmt: impl FnMut(T) -> String) -> String {
    let mut out = vec![];
    for _ in 0..1000 {
        match next() {
            Some(v) => out.push(fmt(v)),
            None => return out.join(";"),
        }
    }
    out.push("...".into());
    out.join(";")
}

fn res<T, E: std::fmt::Display>(r: Result<T, E>, fmt: impl FnOnce(T) -> String) -> String {
    match r {
        Ok(v) => fmt(v),
        Err(e) => err(e),
    }
}

fn path_segment(s: PathSegment) -> String {
    match s {
        PathSegment::MoveTo { abs, x, y } => format!("M({},{},{})", b(abs), f(x), f(y)),
        PathSegment::LineTo { abs, x, y } => format!("L({},{},{})", b(abs), f(x), f(y)),
        PathSegment::HorizontalLineTo { abs, x } => format!("H({},{})", b(abs), f(x)),
        PathSegment::VerticalLineTo { abs, y } => format!("V({},{})", b(abs), f(y)),
        PathSegment::CurveTo { abs, x1, y1, x2, y2, x, y } => format!(
            "C({},{},{},{},{},{},{})",
            b(abs),
            f(x1),
            f(y1),
            f(x2),
            f(y2),
            f(x),
            f(y)
        ),
        PathSegment::SmoothCurveTo { abs, x2, y2, x, y } => {
            format!("S({},{},{},{},{})", b(abs), f(x2), f(y2), f(x), f(y))
        }
        PathSegment::Quadratic { abs, x1, y1, x, y } => {
            format!("Q({},{},{},{},{})", b(abs), f(x1), f(y1), f(x), f(y))
        }
        PathSegment::SmoothQuadratic { abs, x, y } => {
            format!("T({},{},{})", b(abs), f(x), f(y))
        }
        PathSegment::EllipticalArc { abs, rx, ry, x_axis_rotation, large_arc, sweep, x, y } => {
            format!(
                "A({},{},{},{},{},{},{},{})",
                b(abs),
                f(rx),
                f(ry),
                f(x_axis_rotation),
                b(large_arc),
                b(sweep),
                f(x),
                f(y)
            )
        }
        PathSegment::ClosePath { abs } => format!("Z({})", b(abs)),
    }
}

fn simple_segment(s: SimplePathSegment) -> String {
    match s {
        SimplePathSegment::MoveTo { x, y } => format!("M({},{})", f(x), f(y)),
        SimplePathSegment::LineTo { x, y } => format!("L({},{})", f(x), f(y)),
        SimplePathSegment::CurveTo { x1, y1, x2, y2, x, y } => format!(
            "C({},{},{},{},{},{})",
            f(x1),
            f(y1),
            f(x2),
            f(y2),
            f(x),
            f(y)
        ),
        SimplePathSegment::Quadratic { x1, y1, x, y } => {
            format!("Q({},{},{},{})", f(x1), f(y1), f(x), f(y))
        }
        SimplePathSegment::ClosePath => "Z".into(),
    }
}

fn transform_token(t: TransformListToken) -> String {
    match t {
        TransformListToken::Matrix { a, b, c, d, e, f: ff } => format!(
            "matrix({},{},{},{},{},{})",
            f(a),
            f(b),
            f(c),
            f(d),
            f(e),
            f(ff)
        ),
        TransformListToken::Translate { tx, ty } => format!("translate({},{})", f(tx), f(ty)),
        TransformListToken::Scale { sx, sy } => format!("scale({},{})", f(sx), f(sy)),
        TransformListToken::Rotate { angle } => format!("rotate({})", f(angle)),
        TransformListToken::SkewX { angle } => format!("skewX({})", f(angle)),
        TransformListToken::SkewY { angle } => format!("skewY({})", f(angle)),
    }
}

fn filter_value(v: FilterValue<'_>) -> String {
    match v {
        FilterValue::Blur(l) => format!("blur({})", length(&l)),
        FilterValue::DropShadow { color: c, dx, dy, std_dev } => format!(
            "drop-shadow({},{},{},{})",
            match c {
                Some(c) => color(&c),
                None => "N".into(),
            },
            length(&dx),
            length(&dy),
            length(&std_dev)
        ),
        FilterValue::Brightness(x) => format!("brightness({})", f(x)),
        FilterValue::Contrast(x) => format!("contrast({})", f(x)),
        FilterValue::Grayscale(x) => format!("grayscale({})", f(x)),
        FilterValue::HueRotate(a) => format!("hue-rotate({})", angle(&a)),
        FilterValue::Invert(x) => format!("invert({})", f(x)),
        FilterValue::Opacity(x) => format!("opacity({})", f(x)),
        FilterValue::Sepia(x) => format!("sepia({})", f(x)),
        FilterValue::Saturate(x) => format!("saturate({})", f(x)),
        FilterValue::Url(u) => format!("url({u})"),
    }
}

fn paint_fallback(p: Option<PaintFallback>) -> String {
    match p {
        None => "N".into(),
        Some(PaintFallback::None) => "none".into(),
        Some(PaintFallback::CurrentColor) => "currentColor".into(),
        Some(PaintFallback::Color(c)) => color(&c),
    }
}

fn paint(p: Paint<'_>) -> String {
    match p {
        Paint::None => "none".into(),
        Paint::Inherit => "inherit".into(),
        Paint::CurrentColor => "currentColor".into(),
        Paint::Color(c) => color(&c),
        Paint::FuncIRI(l, fb) => format!("url({l},{})", paint_fallback(fb)),
        Paint::ContextFill => "context-fill".into(),
        Paint::ContextStroke => "context-stroke".into(),
    }
}

// ---------------------------------------------------------------------------
// Runners: input -> canonical result.

fn run(kind: &str, s: &str) -> String {
    match kind {
        "number" => res(Number::from_str(s), |n| f(n.0)),
        "number_list" => {
            let mut p = NumberListParser::from(s);
            seq(|| p.next(), |r| res(r, f))
        }
        "length" => res(Length::from_str(s), |l| length(&l)),
        "length_list" => {
            let mut p = LengthListParser::from(s);
            seq(|| p.next(), |r| res(r, |l| length(&l)))
        }
        "angle" => res(Angle::from_str(s), |a| format!("{}|{}", angle(&a), f(a.to_degrees()))),
        "color" => res(Color::from_str(s), |c| color(&c)),
        "paint" => res(Paint::from_str(s), paint),
        "iri" => res(IRI::from_str(s), |i| format!("iri({})", i.0)),
        "funciri" => res(FuncIRI::from_str(s), |i| format!("funciri({})", i.0)),
        "viewbox" => res(ViewBox::from_str(s), |v| {
            format!("vb({},{},{},{})", f(v.x), f(v.y), f(v.w), f(v.h))
        }),
        "points" => {
            let mut p = PointsParser::from(s);
            seq(|| p.next(), |(x, y)| format!("({},{})", f(x), f(y)))
        }
        "aspect" => res(AspectRatio::from_str(s), |a| {
            format!("ar({},{:?},{})", b(a.defer), a.align, b(a.slice))
        }),
        "paint_order" => {
            let o = PaintOrder::from_str(s).unwrap();
            format!("{:?},{:?},{:?}", o.order[0], o.order[1], o.order[2])
        }
        "enable_bg" => res(EnableBackground::from_str(s), |e| match e {
            EnableBackground::Accumulate => "accumulate".into(),
            EnableBackground::New => "new".into(),
            EnableBackground::NewWithRegion { x, y, width, height } => {
                format!("new({},{},{},{})", f(x), f(y), f(width), f(height))
            }
        }),
        "dirpos" => res(DirectionalPosition::from_str(s), |d| format!("{d:?}")),
        "transform_origin" => res(TransformOrigin::from_str(s), |t| {
            format!(
                "to({},{},{})",
                length(&t.x_offset),
                length(&t.y_offset),
                length(&t.z_offset)
            )
        }),
        "font_families" => res(parse_font_families(s), |v| {
            v.iter().map(|f| f.to_string()).collect::<Vec<_>>().join("|")
        }),
        "font_shorthand" => res(FontShorthand::from_str(s), |v| {
            format!(
                "fs({},{},{},{},{},{})",
                opt_str(v.font_style),
                opt_str(v.font_variant),
                opt_str(v.font_weight),
                opt_str(v.font_stretch),
                v.font_size,
                v.font_family
            )
        }),
        "transform" => res(Transform::from_str(s), |t| {
            format!(
                "ts({},{},{},{},{},{})",
                f(t.a),
                f(t.b),
                f(t.c),
                f(t.d),
                f(t.e),
                f(t.f)
            )
        }),
        "transform_list" => {
            let mut p = TransformListParser::from(s);
            seq(|| p.next(), |r| res(r, transform_token))
        }
        "filter" => {
            let mut p = FilterValueListParser::from(s);
            seq(|| p.next(), |r| res(r, filter_value))
        }
        "path" => {
            let mut p = PathParser::from(s);
            seq(|| p.next(), |r| res(r, path_segment))
        }
        "simple_path" => {
            let mut p = SimplifyingPathParser::from(s);
            seq(|| p.next(), |r| res(r, simple_segment))
        }
        _ => unreachable!("{kind}"),
    }
}

// ---------------------------------------------------------------------------
// Corpus.

/// A tiny deterministic PRNG (xorshift64*).
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        x.wrapping_mul(0x2545F4914F6CDD1D)
    }
    fn below(&mut self, n: u64) -> u64 {
        self.next() % n
    }
    fn pick<'a>(&mut self, xs: &[&'a str]) -> &'a str {
        xs[self.below(xs.len() as u64) as usize]
    }
    /// A random SVG number literal.
    fn number(&mut self) -> String {
        let mut s = String::new();
        match self.below(6) {
            0 => s.push('-'),
            1 => s.push('+'),
            _ => {}
        }
        let int_digits = self.below(5);
        for _ in 0..int_digits {
            s.push((b'0' + self.below(10) as u8) as char);
        }
        if int_digits == 0 || self.below(2) == 0 {
            s.push('.');
            let frac = if int_digits == 0 { 1 + self.below(6) } else { self.below(6) };
            for _ in 0..frac {
                s.push((b'0' + self.below(10) as u8) as char);
            }
        }
        if self.below(8) == 0 {
            s.push(if self.below(2) == 0 { 'e' } else { 'E' });
            match self.below(3) {
                0 => s.push('-'),
                1 => s.push('+'),
                _ => {}
            }
            s.push((b'0' + self.below(10) as u8) as char);
            if self.below(2) == 0 {
                s.push((b'0' + self.below(3) as u8) as char);
            }
        }
        s
    }
    fn sep(&mut self) -> &'static str {
        match self.below(5) {
            0 => ",",
            1 => " , ",
            2 => "  ",
            _ => " ",
        }
    }
}

fn corpus() -> Vec<(&'static str, Vec<String>)> {
    let mut rng = Rng(0x9E3779B97F4A7C15);
    let mut out: Vec<(&'static str, Vec<String>)> = vec![];
    let v = |xs: &[&str]| xs.iter().map(|s| s.to_string()).collect::<Vec<_>>();

    // Numbers.
    let mut numbers = v(&[
        "0", "1", "-1", " -1 ", "  1  ", ".4", "-.4", "-.4text", "-.01 text", "-.01 4",
        ".0000000000008", "1000000000000", "123456.123456", "+10", "1e2", "1e+2", "1E2",
        "1e-2", "1ex", "1em", "12345678901234567890", "0.", "1.3e-2", "1e", "q", "", "-",
        "+", "-q", ".", "99999999e99999999", "-99999999e99999999", "1e-7", ".5e+3",
        "1.e5", ".e5", "1e+", "1e-", "-.", "+.5", "0.1", "0.2", "0.30000000000000004",
        "3.141592653589793238462643383279", "2.2250738585072011e-308",
        "2.2250738585072014e-308", "4.9e-324", "2.4703282292062327e-324",
        "2.4703282292062328e-324", "1.7976931348623157e308", "1.7976931348623159e308",
        "9007199254740993", "9007199254740992.5", "123456789012345678901234567890e-20",
        "0.000000000000000000000000000000000000000000001", "1e-400", "-0", "-0.0",
        "00001.50000", "1.5 ", "1.5 x", "1.5,", "\t\n1\r", "1e5px", "7e-1em", "1E+0",
        "0.1e-1", "1..2", "1.2.3", "--1", "+-1", "1e2e3", "8.98846567431158e307",
        "0.000001", "1e22", "1e23", "123.456e-89", "1x", "１", "1é",
    ]);
    for _ in 0..300 {
        numbers.push(rng.number());
    }
    for _ in 0..60 {
        // Long mantissas.
        let mut s = String::new();
        for _ in 0..(15 + rng.below(30)) {
            s.push((b'0' + rng.below(10) as u8) as char);
        }
        let pos = rng.below(s.len() as u64) as usize;
        s.insert(pos, '.');
        if rng.below(2) == 0 {
            write!(s, "e{}", rng.below(40) as i64 - 20).unwrap();
        }
        numbers.push(s);
    }
    out.push(("number", numbers.clone()));

    let mut number_lists = v(&[
        "10, 20 -50", "", " ", "1,2,3", "1 2 3,", "1,,2", "1 q 2", "1-2-3", "1.2.3.4",
        ".5.5", "1e2-3", "  10  ,  20  ", "1,", ",1", "1 2 3 4 5 6 7 8 9 10",
    ]);
    for _ in 0..40 {
        let n = 1 + rng.below(8);
        let mut s = String::new();
        for i in 0..n {
            if i > 0 {
                s.push_str(rng.sep());
            }
            s.push_str(&rng.number());
        }
        number_lists.push(s);
    }
    out.push(("number_list", number_lists));

    // Lengths.
    let mut lengths = v(&[
        "1", "1em", "1ex", "1px", "1in", "1cm", "1mm", "1pt", "1pc", "1%", "1e0", "1.0e0",
        "1.0e0em", "1,", "1 ,", "1 1", "1q", "1mmx", "1PX", "1 px", "-5.5%", "", "em",
        " 3pt", "3pt ", "1e1e", "2emx", "1e-3mm", "10%%",
    ]);
    let units = ["", "em", "ex", "px", "in", "cm", "mm", "pt", "pc", "%", "q", "Px"];
    for _ in 0..60 {
        lengths.push(format!("{}{}", rng.number(), rng.pick(&units)));
    }
    out.push(("length", lengths));
    let mut length_lists = v(&[
        "10px 20% 50mm", "", "1 2 3", "1px,2px,3px", "1px 2q", "1em,", "5% 5%",
    ]);
    for _ in 0..30 {
        let n = 1 + rng.below(5);
        let mut s = String::new();
        for i in 0..n {
            if i > 0 {
                s.push_str(rng.sep());
            }
            s.push_str(&rng.number());
            s.push_str(rng.pick(&units));
        }
        length_lists.push(s);
    }
    out.push(("length_list", length_lists));

    // Angles.
    let mut angles = v(&[
        "1", "1deg", "1grad", "1rad", "1turn", "1q", "1degq", "", "-45deg", "3.14159rad",
        "0.25turn", "200grad", "1 deg", "1DEG", "57.29577951308232rad", "1e3grad",
    ]);
    let aunits = ["", "deg", "grad", "rad", "turn", "x"];
    for _ in 0..40 {
        angles.push(format!("{}{}", rng.number(), rng.pick(&aunits)));
    }
    out.push(("angle", angles));

    // Colors.
    let mut colors = v(&[
        "#ff0000", "#FF0000", "#f00", "#ff0000ff", "#FF0000FF", "#f00f", "  #ff0000  ",
        "rgb(254, 203, 231)", " rgb( 77 , 77 , 77 ) ", "rgb(50%, 50%, 50%)",
        "rgb(140%, -10%, 130%)", "rgb(33.333%,46.666%,93.333%)", "RGB(254, 203, 231)",
        "RgB(254, 203, 231)", "rgb(3.141592653, 110, 201)",
        "rgb(254, 150.829521289232389, 210)", "rgb(96, 255, 0.2)", "rgb(0.0, 129.82, 231.092)",
        "rgb(0.0, 129.82, 231.092, 0.5)", "rgb(290.2, 255.9, 300.0)", "red", " red ", "RED",
        "ReD", "cornflowerblue", "transparent", "rgba(10, 20, 30, 0.5)",
        "rgba(3.141592653, 110, 201, 1.0)", "rgba(0.0, 129.82, 231.092, 1.5)",
        "rgba(10, 20, 30, -2)", "rgba(10, 20, 30, 2)", "rgb(10, 20, 30, 0.5)",
        "hsl(120, 100%, 75%)", "hsl(60, 100%, 50%)", "hsl(360, 100%, 100%)",
        "hsl(800, 150%, -50%)", "hsla(120, 100%, 75%, 0.5)", "hsl(120, 100%, 75%, 0.5)",
        "hsl(230, 57%, 54%)", "hsl(120.152, 100%, 75%)", "hsla(120.152, 100%, 75%, 0.5)",
        "text", "#CD853F icc-color(acmecmyk, 0.11, 0.48, 0.83, 0.00)",
        "red icc-color(acmecmyk, 0.11, 0.48, 0.83, 0.00)", "rgb(-0\x0d", "#9ߞpx! ;",
        "rgba(10, 20, 30, 5%)", "rgb(140%, -10mm, 130pt)", "", "#", "#12", "#12345",
        "#1234567", "#123456789", "#ggg", "rgb(", "rgb()", "rgb(1,2)", "rgb(1,2,3",
        "rgb(1 2 3)", "rgb(1%,2,3)", "rgb(1,2%,3%)", "rgb(0.5%, 0.5%, 0.5%)",
        "rgb(-0.5, -0.4, 254.5)", "rgb(127.5, 128.5, 0.49999999999999994)",
        "rgba(1,2,3,0.498)", "rgba(1,2,3,0.502)", "hsl(-120, 50%, 50%)", "hsl(0,0%,0%)",
        "hsl(359.999, 100%, 50%)", "hsl(1e10, 50%, 50%)", "hsl(30, 50, 50)",
        "hsl(30 50% 50%)", "HSL(30, 50%, 50%)", "hsla(30, 50%, 50%)",
        "currentColor", "none", "inherit", "rgb (1,2,3)", "#abc def", "red;", "réd",
        "\u{feff}red", "rgb(1,2,3)x", "rgb(1e2, 1e1, 1e0)", "rgb(1e400, 0, 0)",
    ]);
    for name in [
        "aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige", "bisque",
        "black", "blanchedalmond", "blue", "blueviolet", "brown", "burlywood", "cadetblue",
        "chartreuse", "chocolate", "coral", "cornflowerblue", "cornsilk", "crimson", "cyan",
        "darkblue", "darkcyan", "darkgoldenrod", "darkgray", "darkgreen", "darkgrey",
        "darkkhaki", "darkmagenta", "darkolivegreen", "darkorange", "darkorchid", "darkred",
        "darksalmon", "darkseagreen", "darkslateblue", "darkslategray", "darkslategrey",
        "darkturquoise", "darkviolet", "deeppink", "deepskyblue", "dimgray", "dimgrey",
        "dodgerblue", "firebrick", "floralwhite", "forestgreen", "fuchsia", "gainsboro",
        "ghostwhite", "gold", "goldenrod", "gray", "grey", "green", "greenyellow",
        "honeydew", "hotpink", "indianred", "indigo", "ivory", "khaki", "lavender",
        "lavenderblush", "lawngreen", "lemonchiffon", "lightblue", "lightcoral", "lightcyan",
        "lightgoldenrodyellow", "lightgray", "lightgreen", "lightgrey", "lightpink",
        "lightsalmon", "lightseagreen", "lightskyblue", "lightslategray", "lightslategrey",
        "lightsteelblue", "lightyellow", "lime", "limegreen", "linen", "magenta", "maroon",
        "mediumaquamarine", "mediumblue", "mediumorchid", "mediumpurple", "mediumseagreen",
        "mediumslateblue", "mediumspringgreen", "mediumturquoise", "mediumvioletred",
        "midnightblue", "mintcream", "mistyrose", "moccasin", "navajowhite", "navy",
        "oldlace", "olive", "olivedrab", "orange", "orangered", "orchid", "palegoldenrod",
        "palegreen", "paleturquoise", "palevioletred", "papayawhip", "peachpuff", "peru",
        "pink", "plum", "powderblue", "purple", "rebeccapurple", "red", "rosybrown",
        "royalblue", "saddlebrown", "salmon", "sandybrown", "seagreen", "seashell", "sienna",
        "silver", "skyblue", "slateblue", "slategray", "slategrey", "snow", "springgreen",
        "steelblue", "tan", "teal", "thistle", "tomato", "turquoise", "violet", "wheat",
        "white", "whitesmoke", "yellow", "yellowgreen", "transparent",
    ] {
        colors.push(name.to_string());
        colors.push(name.to_uppercase());
    }
    for _ in 0..150 {
        let h = rng.below(1000) as f64 / 7.0 - 30.0;
        let s = rng.below(1200) as f64 / 10.0 - 5.0;
        let l = rng.below(1200) as f64 / 10.0 - 5.0;
        colors.push(format!("hsl({h}, {s}%, {l}%)"));
    }
    for _ in 0..100 {
        let r = rng.below(3000) as f64 / 10.0 - 10.0;
        let g = rng.below(3000) as f64 / 10.0 - 10.0;
        let bb = rng.below(3000) as f64 / 10.0 - 10.0;
        let a = rng.below(1200) as f64 / 1000.0;
        colors.push(format!("rgba({r}, {g}, {bb}, {a})"));
        colors.push(format!("rgb({}%,{}%,{}%)", r / 2.0, g / 2.0, bb / 2.0));
    }
    for _ in 0..40 {
        let len = [3, 4, 6, 8][rng.below(4) as usize];
        let mut s = String::from("#");
        for _ in 0..len {
            s.push(b"0123456789abcdefABCDEF"[rng.below(22) as usize] as char);
        }
        colors.push(s);
    }
    out.push(("color", colors));

    // Paint.
    out.push((
        "paint",
        v(&[
            "none", "  none   ", " inherit ", " currentColor ", " red ", " url(#qwe) ",
            " url(#qwe) none ", " url(#qwe) currentColor ", " url(#qwe) red ", "qwe",
            "red icc-color(acmecmyk, 0.11, 0.48, 0.83, 0.00)",
            "url(#qwe) red icc-color(acmecmyk, 0.11, 0.48, 0.83, 0.00)", "context-fill",
            "context-stroke", "\u{a0}none\u{3000}", "url(#)", "url(#a) qwe", "url('#a') blue",
            "url(\"#a b\")", "url(#a", "", "#fff", "rgb(1,2,3)", "url(#a)  #123",
            "url(#a) none x", "url( #x )", "URL(#x)", "inherit x",
        ]),
    ));

    // IRI / FuncIRI.
    let iris = v(&[
        "#id", "   #id   ", "   #id   text", "#1", "# id", "", "id", "#", "#a)b", "#é",
        "#a\tb", "  #日本 x",
    ]);
    out.push(("iri", iris));
    out.push((
        "funciri",
        v(&[
            "url(#id)", "url(#1)", "    url(    #id    )   ", "url(#id) qwe", "url('#id')",
            "url(' #id ')", "url(\"#id\")", "url(\" #id \")", "url ( #1 )", "url(#)",
            "url(# id)", "url('#id)", "url(#id')", "", "url(", "url(#a\u{3000}')",
            "url('#a\u{3000}')", "url(#日本)", "url(#a\"b)", "url(\"#id')", "uRl(#x)",
            "url('#id' )", "url(#id x)",
        ]),
    ));

    // ViewBox.
    let mut vbs = v(&[
        "-20 30 100 500", "qwe", "10 20 30 0", "10 20 0 40", "10 20 0 0", "10 20 -30 0",
        "10 20 30 -40", "10 20 -30 -40", "", "1,2,3,4", "1 2 3", "1 2 3 4 5", "1 2 3 4x",
        " 0 0 1e-300 1e300 ",
    ]);
    for _ in 0..20 {
        vbs.push(format!(
            "{} {} {} {}",
            rng.number(),
            rng.number(),
            rng.number(),
            rng.number()
        ));
    }
    out.push(("viewbox", vbs));

    // Points.
    let mut points = v(&[
        "10 20 30 40", "10 20 30 40 50", "", "10,20 30,40", "10-20-30-40", "1 2 q 3 4",
        "1 2 3 q", "  ", "1,2,", ",1,2",
    ]);
    for _ in 0..20 {
        let n = rng.below(9);
        let mut s = String::new();
        for i in 0..n {
            if i > 0 {
                s.push_str(rng.sep());
            }
            s.push_str(&rng.number());
        }
        points.push(s);
    }
    out.push(("points", points));

    // AspectRatio.
    out.push((
        "aspect",
        v(&[
            "none", "defer none", "xMinYMid", "xMinYMid slice", "xMinYMid meet", "",
            "xMidYMid  slice ", "defer", "defer  xMaxYMax meet", "defernone", "XMinYMid",
            "xMinYMid foo", "xMinYMid slice x", "  xMaxYMin", "xMidYMax,slice", "none meet",
            "xMinYMin;",
        ]),
    ));

    // PaintOrder.
    out.push((
        "paint_order",
        v(&[
            "normal", "qwe", "", "stroke qwe", "stroke stroke", "stroke", "stroke markers",
            "stroke markers fill", "markers", "  stroke\n", "stroke stroke stroke stroke",
            "fill", "markers stroke", "fill fill", "normal stroke", "stroke normal",
            "stroke,fill", "stroke markers fill markers", "   ",
        ]),
    ));

    // EnableBackground.
    out.push((
        "enable_bg",
        v(&[
            "accumulate", "  accumulate  ", "new", "  new  ", "new 1 2 3 4", " accumulate b ",
            " new b ", "new 1 2 3", "new 1 2 3 4 5", "new 0 0 0 0", "", "news", "new,1,2,3,4",
            "new -1 -2 3 4", "new 1 2 -3 4", "accumulatex",
        ]),
    ));

    // DirectionalPosition.
    out.push((
        "dirpos",
        v(&[
            "left", "right", "center", "top", "bottom", "left,", "left ,", "left center",
            "something", "", "  top", "lefty", "日本", "Left",
        ]),
    ));

    // TransformOrigin (inputs for which upstream doesn't panic).
    out.push((
        "transform_origin",
        v(&[
            "center", "left", "right", "top", "bottom", "30px", "center left", "left center",
            "center bottom", "bottom center", "30%, center", " center, 30%", "left top",
            "center right 3px", "", "some", "center some", "left right", "left top 3%",
            "10px 20px", "10px 20px 30px", "10px 20px 30px 40px", "top 10px", "10px top",
            "left 10px", "10px left", "top left", "top bottom", "center center",
            "center center 1em", "1 2 3", "left,top,2", "50%", "bottom 1e1",
        ]),
    ));

    // Fonts.
    out.push((
        "font_families",
        v(&[
            "Times New Roman", "serif", "sans-serif", "cursive", "fantasy", "monospace",
            "'Times New Roman'", "'Times New Roman', sans-serif",
            "Arial, sans-serif, 'fantasy'", "    Arial  , monospace  , 'fantasy'",
            "Times    New Roman", "\"Times New Roman\", sans-serif, sans-serif, \"Arial\"",
            "Times New Roman,,,Arial",
            "简体中文,sans-serif  , ,\"日本語フォント\",Arial", "", "Red/Black, sans-serif",
            "\"Lucida\" Grande, sans-serif", "Ahem!, sans-serif", "test@foo, sans-serif",
            "#POUND, sans-serif", "Hawaii 5-0, sans-serif", "a, ", "'unterminated",
            "'a\\'b'", "-foo", "--foo", "-", "Ünïcödé Font", "ðx", "\u{ed}x", "a,'b',c",
            "a ,b", "'a' 'b'", "Noto  Sans , ", "x\u{ee}y", "Arial\t,serif",
        ]),
    ));
    out.push((
        "font_shorthand",
        v(&[
            "12pt/14pt sans-serif", "80% sans-serif", "bold italic large Palatino, serif",
            "x-large/110% \"new century schoolbook\", serif",
            "normal small-caps 120%/120% fantasy",
            "condensed oblique 12pt \"Helvetica Neue\", serif",
            "italic 500 2em sans-serif, 'Noto Sans'", "xx-large 'Noto Sans'",
            "small-caps normal normal italic xx-small Times", "", "Noto Sans", "12pt  ",
            "something 12pt 'Noto Sans'", "'Noto Sans' 13pt",
            "small-caps normal normal normal italic xx-large Times", "12pt", "12pt/",
            "12pt / 1.5 Arial", "  bold 12px Arial", "bold", "medium 日本", "12q Arial",
            "1e2px Arial", "ultra-condensed 900 smaller x",
        ]),
    ));

    // Transforms.
    let mut transforms = v(&[
        "matrix(1 0 0 1 10 20)", "translate(10 20)", "scale(2 3)", "rotate(30)",
        "rotate(30 10 20)", "translate(10 15) translate(0 5)", "translate(10) scale(2)",
        "translate(25 215) scale(2) skewX(45)", "skewX(45)", "text", "scale(2) text", "???G",
        " ", "\x01", "rect()", "scale(2) rect()", "", "skewY(30)", "rotate(-45.5)",
        "matrix(1,2,3,4,5,6)", "matrix(1 2 3 4 5)", "translate(1,2),scale(3)",
        "translate (1 2)", "rotate(10 20)", "rotate(10 20 30 40)", "scale(1e300) scale(1e300)",
        "skewX(90)", "rotate(90)", "rotate(180)", "rotate(270)", "rotate(360)",
        "rotate(1e20)", "translate(1 2)  ,  translate(3 4)", "translate(1 2),,translate(3 4)",
    ]);
    for _ in 0..80 {
        let n = 1 + rng.below(4);
        let mut s = String::new();
        for i in 0..n {
            if i > 0 {
                s.push(' ');
            }
            match rng.below(7) {
                0 => write!(
                    s,
                    "matrix({} {} {} {} {} {})",
                    rng.number(),
                    rng.number(),
                    rng.number(),
                    rng.number(),
                    rng.number(),
                    rng.number()
                )
                .unwrap(),
                1 => write!(s, "translate({}, {})", rng.number(), rng.number()).unwrap(),
                2 => write!(s, "scale({} {})", rng.number(), rng.number()).unwrap(),
                3 => write!(s, "rotate({})", rng.number()).unwrap(),
                4 => write!(
                    s,
                    "rotate({} {} {})",
                    rng.number(),
                    rng.number(),
                    rng.number()
                )
                .unwrap(),
                5 => write!(s, "skewX({})", rng.number()).unwrap(),
                _ => write!(s, "skewY({})", rng.number()).unwrap(),
            }
        }
        transforms.push(s);
    }
    out.push(("transform", transforms.clone()));
    out.push(("transform_list", transforms));

    // Filters.
    out.push((
        "filter",
        v(&[
            "", "none", "blur()", "blur(2)", "blur(2mm)", "blur(2%)", "blur(-1)", "blur(1 2)",
            "brightness()", "brightness(2)", "brightness(50%)", "brightness(-1)",
            "brightness(2mm)", "drop-shadow()", "drop-shadow(2 3)", "drop-shadow(red 2 3)",
            "drop-shadow(2 3 red)", "drop-shadow(currentColor 2 3)",
            "drop-shadow(2 3 currentColor)", "drop-shadow(red 2 3 4)",
            "drop-shadow(red 2 3 4 red)", "drop-shadow(currentColor 2 3 4 currentColor)",
            "drop-shadow(2% 3% 4%)", "drop-shadow(-1 -2 3)", "hue-rotate(45)", "url(#qwe)",
            "blur() blur()", "blur() contrast(1)", "none blur()", "hue-rotate()",
            "hue-rotate(0)", "hue-rotate(45deg)", "hue-rotate(1rad)", "hue-rotate(1turn)",
            "hue-rotate(100grad)", "contrast(0)", "grayscale(1)", "invert(0.5)",
            "opacity(25%)", "sepia(-0)", "saturate(1e2)", "url(#)", "url()", "foo(1)",
            "blur(1", "blur", "drop-shadow(rgb(1,2,3) 1px 2px 3px)",
            "drop-shadow(1px 2px -3px)", "drop-shadow(#fff 1 2 3 4)", "blur(1) , blur(2)",
            "blur(-0)", "drop-shadow(1 2 #abc)", "drop-shadow(red)", "drop-shadow(1)",
            "hue-rotate(1e2deg) invert()", "url(#a b)", "BLUR(1)",
        ]),
    ));

    // Paths.
    let mut paths = v(&[
        "", "q", "L 20 30", "M 10 20 L 30 40 L 50", "M 10 20", "m 10 20",
        "M 10 20 30 40 50 60", "M 10 20 30 40 50 60 M 70 80 90 100 110 120",
        "M 10 20 A 5 5 30 1 1 20 20", "M 10 20 a 5 5 30 0 0 20 20", "M10-20A5.5.3-4 010-.1",
        "M 10 20 L 5 15 C 10 20 30 40 50 60", "M 10, 20 L 5, 15 C 10, 20 30, 40 50, 60",
        "M 10,20 L 5,15 C 10,20 30,40 50,60", "M10, 20 L5, 15 C10, 20 30 40 50 60",
        "M10 20V30H40V50H60Z",
        "M 10 20 L 30 40 H 50 V 60 C 70 80 90 100 110 120 S 130 140 150 160\n        Q 170 180 190 200 T 210 220 A 50 50 30 1 1 230 240 Z",
        "m 10 20 l 30 40 h 50 v 60 c 70 80 90 100 110 120 s 130 140 150 160\n        q 170 180 190 200 t 210 220 a 50 50 30 1 1 230 240 z",
        "M10 20 L 30 40 ZM 100 200 L 300 400", "M10 20 L 30 40 zM 100 200 L 300 400",
        "M10 20 L 30 40 Z Z Z", "M\t.", "M 0 0 Z 2", "M 0 0 Z H 10", "M10-20l30.1.5.1-20z",
        "M 10 20 L 30 40 Z Z Z Z", "m 30 40 110 120 -20 -130", "M 30 40 S 171 45 180 155",
        "M 30 40 C 16 137 171 45 100 90 S 171 45 180 155", "M 1 5 A 5 5 0 0 1 3 1 s 3 2 8 2",
        "M 30 40 T 180 155", "M 30 40 Q 171 45 100 90 T 160 180",
        "M 30 40 Q 171 45 100 90 t 60 80", "M 30 40 q 171 45 50 40 t 60 80",
        "M 30 30 T 40 140 T 170 30", "M 30 30 T 40 140 t 100 -30",
        "M 30 30 T 40 140 q 30 100 120 -30", "M 30 30 T 40 170 s 90 -20 90 -90",
        "M 30 30 T 40 140 Q 80 180 170 30", "M 1 5 A 5 5 0 0 1 3 1 t 8 2",
        "M 10 20 L 30 40 Z L 50 60", "M 30 40 A 40 30 20 1 1 150 100",
        "M 0 0 A 0 5 0 0 1 10 10", "M 0 0 A 5 0.000001 0 0 1 10 10", "M 5 5 A 5 5 0 0 1 5 5",
        "M 0 0 A 1 1 0 0 1 100 0", "M 0 0 A -5 -5 0 1 0 10 0", "M 0 0 A 5 5 720 1 0 10 0",
        "M 0 0 A 5 5 -400 1 1 10 3", "M 0 0 a 5 5 0 2 0 10 0", "M 0 0 a 5 5 0 0", "M 0 0 a",
        "M 0 0 a 5 5 0 1,1 10 0", "M0 0a5 5 0 1110 0", "M 0 0 z m 10 10 l 5 5 z l 1 1",
        "m 1 1 z m 2 2 z", "M 1 2 L", "M 1 2 L 3", "M 1 2 Lx", "M1 2 3", "m1 2 3 4 5",
        "M1,2,3,4", "M 1 2 C 1 2 3 4 5 6 7 8 9 10 11 12", "M 1 2 S 3 4 5 6 7 8 9 10",
        "M 1 2 Q 3 4 5 6 7 8 9 10", "M 1 2 T 3 4 5 6", "M 1 2 H 3 4 5 V 6 7 8",
        "M 1 2 h 3 4 5 v 6 7 8", "M 1 2 z 3", "M 1e2 1e-2 L .5.5", "M 1 2 L 3 4 #",
        "M 1 2 é", "M 0 0 A 100 50 45 0 1 10 1000", "M 0 0 A 1e-6 1e-6 0 0 1 1e-6 0",
        "M 3 4 A 1e300 1e300 0 0 1 5 6",
    ]);
    let cmds = ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "S", "s", "Q", "q", "T", "t",
        "A", "a", "Z", "z"];
    for _ in 0..250 {
        let mut s = format!(
            "{} {} {}",
            if rng.below(2) == 0 { "M" } else { "m" },
            rng.number(),
            rng.number()
        );
        let n = 1 + rng.below(8);
        for _ in 0..n {
            let c = rng.pick(&cmds);
            s.push(' ');
            s.push_str(c);
            let args = match c {
                "M" | "m" | "L" | "l" | "T" | "t" => 2,
                "H" | "h" | "V" | "v" => 1,
                "C" | "c" => 6,
                "S" | "s" | "Q" | "q" => 4,
                "A" | "a" => 7,
                _ => 0,
            };
            for i in 0..args {
                s.push_str(rng.sep());
                if (c == "A" || c == "a") && (i == 3 || i == 4) {
                    s.push(if rng.below(2) == 0 { '0' } else { '1' });
                } else if (c == "A" || c == "a") && (i == 0 || i == 1) {
                    // Radii: mostly sane magnitudes.
                    write!(s, "{}", rng.below(2000) as f64 / 10.0).unwrap();
                } else {
                    s.push_str(&rng.number());
                }
            }
        }
        paths.push(s);
    }
    // Many arcs with varied parameters.
    for _ in 0..200 {
        let rx = rng.below(3000) as f64 / 10.0 - 20.0;
        let ry = rng.below(3000) as f64 / 10.0 - 20.0;
        let rot = rng.below(7200) as f64 / 10.0 - 360.0;
        let x = rng.below(4000) as f64 / 10.0 - 200.0;
        let y = rng.below(4000) as f64 / 10.0 - 200.0;
        let sx = rng.below(400) as f64 / 10.0 - 20.0;
        let sy = rng.below(400) as f64 / 10.0 - 20.0;
        paths.push(format!(
            "M {sx} {sy} {} {rx} {ry} {rot} {} {} {x} {y}",
            if rng.below(2) == 0 { "A" } else { "a" },
            rng.below(2),
            rng.below(2)
        ));
    }
    out.push(("path", paths.clone()));
    out.push(("simple_path", paths));

    out
}

fn main() {
    let mut o = String::new();
    writeln!(o, "// Generated by `oracle/src/bin/gen_svgtypes_tests.rs` from the real").unwrap();
    writeln!(o, "// `svgtypes` 0.16.1 crate. Do not edit.").unwrap();
    writeln!(o).unwrap();
    let mut total = 0;
    for (kind, inputs) in corpus() {
        writeln!(o, "///|").unwrap();
        writeln!(o, "test \"oracle {kind}\" {{").unwrap();
        writeln!(o, "  let cases : Array[(String, String)] = [").unwrap();
        for input in &inputs {
            let expected = run(kind, input);
            writeln!(o, "    ({}, {}),", lit(input), lit(&expected)).unwrap();
            total += 1;
        }
        writeln!(o, "  ]").unwrap();
        writeln!(o, "  check_cases({}, cases)", lit(kind)).unwrap();
        writeln!(o, "}}").unwrap();
        writeln!(o).unwrap();
    }
    eprintln!("{total} cases");
    print!("{o}");
}
