//! Generates `tiny_skia_path/oracle_wbtest.mbt`: differential tests for the
//! MoonBit port of `tiny-skia-path` 0.12.0 (and the used parts of
//! `strict-num` 0.1.1 / `float-cmp`), with expected results produced by the
//! real crates.
//!
//! Floats are compared bit-exactly (as `{:08x}` of `f32::to_bits`). Paths are
//! dumped segment by segment (`M x,y L x,y Q .. C .. Z | b l,t,r,b`).
//!
//! The corpus consists of hand-written paths (including the crate's own
//! `#[test]` cases and degenerate inputs) and deterministic random paths; each
//! path is transformed, measured (bounds/tight bounds), stroked with various
//! widths/caps/joins/miter limits/resolution scales and dashed.
//!
//! A final set of `bulk fuzz` tests only compares digests: the RNG and path
//! construction are mirrored in `tiny_skia_path/oracle_support_wbtest.mbt`
//! (which also holds the dump helpers).
//!
//! Usage: cargo run --release --bin gen_tiny_skia_path_tests > ../tiny_skia_path/oracle_wbtest.mbt
//!        (then `moon fmt`)

use std::fmt::Write as _;
use std::hint::black_box;

use strict_num::ApproxEqUlps;
use tiny_skia_path::{
    IntRect, IntSize, LineCap, LineJoin, NonZeroRect, NormalizedF32, Path, PathBuilder,
    PathSegment, PathStroker, Point, Rect, Size, Stroke, StrokeDash, Transform,
};

/// Long dumps are compared by length + FNV-1a 64 hash + a short prefix.
fn digest(s: &str) -> String {
    if s.len() <= 400 {
        return s.to_string();
    }
    let mut h: u64 = 0xcbf29ce484222325;
    for b in s.bytes() {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    format!("#{} {:016x} {}", s.len(), h, &s[..100])
}

fn hx(v: f32) -> String {
    format!("{:08x}", v.to_bits())
}

/// A MoonBit float expression with the exact bits of `v`.
fn fl(v: f32) -> String {
    format!("f(0x{:08X}U)", v.to_bits())
}

fn dpt(p: Point) -> String {
    format!("{},{}", hx(p.x), hx(p.y))
}

fn drect(r: Option<Rect>) -> String {
    match r {
        None => "None".into(),
        Some(r) => format!(
            "{},{},{},{}",
            hx(r.left()),
            hx(r.top()),
            hx(r.right()),
            hx(r.bottom())
        ),
    }
}

fn dnzrect(r: Option<NonZeroRect>) -> String {
    match r {
        None => "None".into(),
        Some(r) => format!(
            "{},{},{},{}",
            hx(r.left()),
            hx(r.top()),
            hx(r.right()),
            hx(r.bottom())
        ),
    }
}

fn dintrect(r: Option<IntRect>) -> String {
    match r {
        None => "None".into(),
        Some(r) => format!("{},{},{},{}", r.x(), r.y(), r.width(), r.height()),
    }
}

fn dts(t: Transform) -> String {
    format!(
        "{},{},{},{},{},{}",
        hx(t.sx),
        hx(t.ky),
        hx(t.kx),
        hx(t.sy),
        hx(t.tx),
        hx(t.ty)
    )
}

fn dts_opt(t: Option<Transform>) -> String {
    match t {
        None => "None".into(),
        Some(t) => dts(t),
    }
}

fn dpath(p: &Option<Path>) -> String {
    match p {
        None => "None".into(),
        Some(p) => {
            let mut s = String::new();
            for seg in p.segments() {
                match seg {
                    PathSegment::MoveTo(a) => write!(s, "M {} ", dpt(a)).unwrap(),
                    PathSegment::LineTo(a) => write!(s, "L {} ", dpt(a)).unwrap(),
                    PathSegment::QuadTo(a, b) => write!(s, "Q {} {} ", dpt(a), dpt(b)).unwrap(),
                    PathSegment::CubicTo(a, b, c) => {
                        write!(s, "C {} {} {} ", dpt(a), dpt(b), dpt(c)).unwrap()
                    }
                    PathSegment::Close => s.push_str("Z "),
                }
            }
            write!(s, "| b {}", drect(Some(p.bounds()))).unwrap();
            s
        }
    }
}

fn dsize(s: Option<Size>) -> String {
    match s {
        None => "None".into(),
        Some(s) => format!("{},{}", hx(s.width()), hx(s.height())),
    }
}

fn dintsize(s: Option<IntSize>) -> String {
    match s {
        None => "None".into(),
        Some(s) => format!("{},{}", s.width(), s.height()),
    }
}

#[derive(Clone, Debug)]
enum Op {
    M(f32, f32),
    L(f32, f32),
    Q(f32, f32, f32, f32),
    C(f32, f32, f32, f32, f32, f32),
    Z,
    Rect(f32, f32, f32, f32),
    Oval(f32, f32, f32, f32),
    Circle(f32, f32, f32),
}

fn apply(pb: &mut PathBuilder, op: &Op) {
    match *op {
        Op::M(x, y) => pb.move_to(x, y),
        Op::L(x, y) => pb.line_to(x, y),
        Op::Q(a, b, c, d) => pb.quad_to(a, b, c, d),
        Op::C(a, b, c, d, e, f) => pb.cubic_to(a, b, c, d, e, f),
        Op::Z => pb.close(),
        Op::Rect(l, t, r, b) => {
            if let Some(r) = Rect::from_ltrb(l, t, r, b) {
                pb.push_rect(r)
            }
        }
        Op::Oval(l, t, r, b) => {
            if let Some(r) = Rect::from_ltrb(l, t, r, b) {
                pb.push_oval(r)
            }
        }
        Op::Circle(x, y, r) => pb.push_circle(x, y, r),
    }
}

fn emit_op(op: &Op) -> String {
    match *op {
        Op::M(x, y) => format!("pb.move_to({}, {})", fl(x), fl(y)),
        Op::L(x, y) => format!("pb.line_to({}, {})", fl(x), fl(y)),
        Op::Q(a, b, c, d) => format!("pb.quad_to({}, {}, {}, {})", fl(a), fl(b), fl(c), fl(d)),
        Op::C(a, b, c, d, e, f) => format!(
            "pb.cubic_to({}, {}, {}, {}, {}, {})",
            fl(a),
            fl(b),
            fl(c),
            fl(d),
            fl(e),
            fl(f)
        ),
        Op::Z => "pb.close()".into(),
        Op::Rect(l, t, r, b) => format!(
            "if Rect::from_ltrb({}, {}, {}, {}) is Some(r) {{ pb.push_rect(r) }}",
            fl(l),
            fl(t),
            fl(r),
            fl(b)
        ),
        Op::Oval(l, t, r, b) => format!(
            "if Rect::from_ltrb({}, {}, {}, {}) is Some(r) {{ pb.push_oval(r) }}",
            fl(l),
            fl(t),
            fl(r),
            fl(b)
        ),
        Op::Circle(x, y, r) => format!("pb.push_circle({}, {}, {})", fl(x), fl(y), fl(r)),
    }
}

#[derive(Clone, Copy)]
struct StrokeCfg {
    width: f32,
    miter: f32,
    cap: u8,
    join: u8,
    res: f32,
}

fn cap_of(i: u8) -> LineCap {
    match i {
        0 => LineCap::Butt,
        1 => LineCap::Round,
        _ => LineCap::Square,
    }
}

fn join_of(i: u8) -> LineJoin {
    match i {
        0 => LineJoin::Miter,
        1 => LineJoin::MiterClip,
        2 => LineJoin::Round,
        _ => LineJoin::Bevel,
    }
}

fn mk_stroke(c: StrokeCfg) -> Stroke {
    Stroke {
        width: c.width,
        miter_limit: c.miter,
        line_cap: cap_of(c.cap),
        line_join: join_of(c.join),
        dash: None,
    }
}

fn emit_stroke(c: StrokeCfg) -> String {
    format!(
        "stroke_of({}, {}, {}, {})",
        fl(c.width),
        fl(c.miter),
        c.cap,
        c.join
    )
}

const fn sc(width: f32, miter: f32, cap: u8, join: u8, res: f32) -> StrokeCfg {
    StrokeCfg {
        width,
        miter,
        cap,
        join,
        res,
    }
}

const STROKES: &[StrokeCfg] = &[
    sc(1.0, 4.0, 0, 0, 1.0),
    sc(10.0, 4.0, 1, 2, 1.0),
    sc(6.0, 4.0, 2, 3, 1.0),
    sc(8.0, 10.0, 0, 1, 1.0),
    sc(8.0, 1.5, 2, 1, 1.0),
    sc(4.0, 4.0, 1, 0, 2.5),
    sc(0.5, 4.0, 0, 2, 0.3),
    sc(20.0, 1.0, 0, 0, 1.0),
    sc(3.0, 4.0, 2, 2, 10.0),
    sc(0.0, 4.0, 0, 0, 1.0),
];

fn transforms() -> Vec<Transform> {
    vec![
        Transform::from_row(1.5, 0.3, -0.7, 2.0, 10.0, -5.0),
        Transform::from_rotate(33.0),
        Transform::from_scale(2.0, 0.5).post_translate(3.25, -7.5),
    ]
}

const DASHES: &[(&[f32], f32)] = &[
    (&[5.0, 3.0], 0.0),
    (&[1.0, 2.0, 3.0, 4.0], 2.5),
    (&[10.0, 5.0], -3.0),
    (&[0.0, 4.0], 0.0),
];

struct Gen {
    out: String,
    n: usize,
}

impl Gen {
    fn line(&mut self, s: &str) {
        self.out.push_str("  ");
        self.out.push_str(s);
        self.out.push('\n');
    }

    fn check(&mut self, expr: &str, expected: &str) {
        self.line(&format!("assert_eq(dg({expr}), \"{}\")", digest(expected)));
    }

    fn begin(&mut self, name: &str) {
        self.n += 1;
        writeln!(self.out, "\n///|\ntest \"{} {}\" {{", self.n, name).unwrap();
    }

    fn end(&mut self) {
        self.out.push_str("}\n");
    }

    fn path_case(&mut self, name: &str, ops: &[Op], strokes: &[StrokeCfg], full: bool) {
        self.begin(name);
        let mut pb = PathBuilder::new();
        self.line("let pb = PathBuilder::new()");
        for op in ops {
            apply(&mut pb, op);
            self.line(&emit_op(op));
        }
        let path = pb.finish();
        self.line("let path = pb.finish()");
        self.check("dpath(path)", &dpath(&path));
        let Some(path) = path else {
            self.end();
            return;
        };
        self.line("let path = path.unwrap()");
        self.check(
            "drect(path.compute_tight_bounds())",
            &drect(path.compute_tight_bounds()),
        );
        if full {
            for ts in transforms() {
                let t = path.clone().transform(ts);
                let tight = t.as_ref().and_then(|p| p.compute_tight_bounds());
                self.line(&format!("let t = path.transform(ts_of(\"{}\"))", dts(ts)));
                self.check("dpath(t)", &dpath(&t));
                self.check(
                    "drect(t.bind(fn(p) { p.compute_tight_bounds() }))",
                    &drect(tight),
                );
            }
        }
        for &c in strokes {
            let s = path.stroke(&mk_stroke(c), c.res);
            self.check(
                &format!("dpath(path.stroke({}, {}))", emit_stroke(c), fl(c.res)),
                &dpath(&s),
            );
            if let Some(s) = &s {
                self.check(
                    &format!(
                        "drect(path.stroke({}, {}).unwrap().compute_tight_bounds())",
                        emit_stroke(c),
                        fl(c.res)
                    ),
                    &drect(s.compute_tight_bounds()),
                );
            }
        }
        if full {
            for (arr, off) in DASHES {
                let d = StrokeDash::new(arr.to_vec(), *off).unwrap();
                let arr_s: Vec<String> = arr.iter().map(|v| fl(*v)).collect();
                self.line(&format!(
                    "let d = StrokeDash::new([{}], {}).unwrap()",
                    arr_s.join(", "),
                    fl(*off)
                ));
                for res in [1.0f32, 0.25] {
                    let dashed = path.dash(&d, res);
                    self.check(&format!("dpath(path.dash(d, {}))", fl(res)), &dpath(&dashed));
                    if let Some(dashed) = dashed {
                        let c = sc(2.0, 4.0, 1, 2, 1.0);
                        let s = dashed.stroke(&mk_stroke(c), 1.0);
                        self.check(
                            &format!(
                                "dpath(path.dash(d, {}).unwrap().stroke({}, {}))",
                                fl(res),
                                emit_stroke(c),
                                fl(1.0)
                            ),
                            &dpath(&s),
                        );
                    }
                }
            }
        }
        self.end();
    }
}

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u32 {
        // xorshift64*
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        (self.0.wrapping_mul(0x2545F4914F6CDD1D) >> 32) as u32
    }

    fn below(&mut self, n: u32) -> u32 {
        self.next() % n
    }

    fn coord(&mut self, prev: (f32, f32)) -> (f32, f32) {
        match self.below(10) {
            0 => prev,
            1 => (prev.0 + 1e-4, prev.1),
            2 => (prev.0 + (self.below(1000) as f32) * 1e-3, prev.1 - 0.5),
            3 | 4 => (
                self.below(200) as f32 - 50.0,
                self.below(200) as f32 - 50.0,
            ),
            _ => (
                (self.next() as f32 / u32::MAX as f32) * 300.0 - 100.0,
                (self.next() as f32 / u32::MAX as f32) * 300.0 - 100.0,
            ),
        }
    }

    fn stroke(&mut self) -> StrokeCfg {
        let widths = [0.1, 1.0, 2.5, 7.0, 15.0, 60.0];
        let miters = [0.5, 1.0, 1.2, 2.0, 4.0, 30.0];
        let res = [0.1, 1.0, 1.0, 3.0, 16.0];
        sc(
            widths[self.below(widths.len() as u32) as usize],
            miters[self.below(miters.len() as u32) as usize],
            self.below(3) as u8,
            self.below(4) as u8,
            res[self.below(res.len() as u32) as usize],
        )
    }
}

fn random_ops(rng: &mut Rng) -> Vec<Op> {
    let mut ops = Vec::new();
    let mut prev = (0.0f32, 0.0f32);
    let n = 2 + rng.below(7);
    for i in 0..n {
        let kind = if i == 0 { 0 } else { rng.below(12) };
        match kind {
            0 => {
                prev = rng.coord(prev);
                ops.push(Op::M(prev.0, prev.1));
            }
            1..=3 => {
                prev = rng.coord(prev);
                ops.push(Op::L(prev.0, prev.1));
            }
            4..=6 => {
                let a = rng.coord(prev);
                prev = rng.coord(a);
                ops.push(Op::Q(a.0, a.1, prev.0, prev.1));
            }
            7..=10 => {
                let a = rng.coord(prev);
                let b = rng.coord(a);
                prev = rng.coord(b);
                ops.push(Op::C(a.0, a.1, b.0, b.1, prev.0, prev.1));
            }
            _ => ops.push(Op::Z),
        }
    }
    ops
}

fn bulk_fuzz(seed: u64, n: usize) -> String {
    let mut rng = Rng(seed);
    let mut out = String::new();
    let dash_vals = [0.0f32, 0.5, 1.0, 3.0, 7.5, 20.0];
    let dash_offs = [-5.0f32, 0.0, 2.5, 11.0];
    let ts_vals = [-2.0f32, -0.5, 0.0, 0.3, 1.0, 1.5, 3.0];
    let ts_offs = [-10.0f32, 0.0, 7.25];
    for _ in 0..n {
        let ops = random_ops(&mut rng);
        let mut pb = PathBuilder::new();
        for op in &ops {
            apply(&mut pb, op);
        }
        let path = pb.finish();
        out.push_str(&digest(&dpath(&path)));
        out.push('\n');
        let Some(path) = path else { continue };
        out.push_str(&drect(path.compute_tight_bounds()));
        out.push('\n');
        let c = rng.stroke();
        let s = path.stroke(&mk_stroke(c), c.res);
        out.push_str(&digest(&dpath(&s)));
        out.push('\n');
        let len = 2 + 2 * rng.below(2) as usize;
        let arr: Vec<f32> = (0..len).map(|_| dash_vals[rng.below(6) as usize]).collect();
        let off = dash_offs[rng.below(4) as usize];
        if let Some(d) = StrokeDash::new(arr, off) {
            let dashed = path.dash(&d, c.res);
            out.push_str(&digest(&dpath(&dashed)));
            out.push('\n');
            if let Some(dashed) = dashed {
                let s = dashed.stroke(&mk_stroke(c), c.res);
                out.push_str(&digest(&dpath(&s)));
                out.push('\n');
            }
        }
        let mut v = [0.0f32; 6];
        for k in 0..4 {
            v[k] = ts_vals[rng.below(7) as usize];
        }
        v[4] = ts_offs[rng.below(3) as usize];
        v[5] = ts_offs[rng.below(3) as usize];
        let ts = Transform::from_row(v[0], v[1], v[2], v[3], v[4], v[5]);
        let t = path.clone().transform(ts);
        out.push_str(&digest(&dpath(&t)));
        out.push('\n');
        out.push_str(&drect(t.and_then(|t| t.compute_tight_bounds())));
        out.push('\n');
        out.push_str(&hx(PathStroker::compute_resolution_scale(&ts)));
        out.push('\n');
    }
    out
}

fn misc_tests(g: &mut Gen) {
    // Constants and float primitives.
    g.begin("constants");
    for (name, v) in [
        ("scalar_max", tiny_skia_path::SCALAR_MAX),
        ("scalar_nearly_zero", tiny_skia_path::SCALAR_NEARLY_ZERO),
        ("scalar_root_2_over_2", tiny_skia_path::SCALAR_ROOT_2_OVER_2),
        ("float_pi", 3.14159265f32),
        ("f32_1e_8", 1e-8f32),
        ("curvature_slop", 0.000005f32),
        ("cubic_line_slop", 0.00001f32),
        ("(0.3333333 : Float)", 0.3333333f32),
        ("float_pi / 180.0", core::f32::consts::PI / 180.0),
        ("(1.0 : Float) / 3.0", 1.0f32 / 3.0),
        ("(2.0 : Float) / 3.0", 2.0f32 / 3.0),
    ] {
        g.check(&format!("hx({name})"), &hx(v));
    }
    g.end();

    g.begin("min max round");
    let vals = [
        0.0f32,
        -0.0,
        1.0,
        -1.0,
        0.5,
        -0.5,
        1.5,
        2.5,
        -2.5,
        0.49999997,
        -0.49999997,
        8388609.0,
        f32::NAN,
        f32::INFINITY,
        f32::NEG_INFINITY,
        3e9,
        -3e9,
        4.5e9,
    ];
    for &a in &vals {
        for &b in &vals[..6] {
            let mn = black_box(a).min(black_box(b));
            let mx = black_box(a).max(black_box(b));
            g.check(&format!("hx(fmin({}, {}))", fl(a), fl(b)), &hx(mn));
            g.check(&format!("hx(fmax({}, {}))", fl(a), fl(b)), &hx(mx));
        }
        g.check(&format!("hx(round_f32({}))", fl(a)), &hx(black_box(a).round()));
        g.check(
            &format!("f32_as_u32({}).to_string()", fl(a)),
            &(black_box(a) as u32).to_string(),
        );
        g.check(
            &format!("f32_as_i32({}).to_string()", fl(a)),
            &(black_box(a) as i32).to_string(),
        );
        g.check(
            &format!("hx(NormalizedF32::new_clamped({}).get())", fl(a)),
            &hx(NormalizedF32::new_clamped(a).get()),
        );
    }
    g.end();

    g.begin("approx_eq_ulps");
    let pairs = [
        (0.0f32, -0.0f32, 4),
        (1.0, 1.0000001, 4),
        (1.0, 1.0000005, 4),
        (1.0, 1.000001, 4),
        (-1.0, -1.0000002, 1),
        (1e-45, -1e-45, 4),
        (0.0, 1e-45, 4),
        (0.0, 1e-44, 4),
        (f32::NAN, f32::NAN, 4),
        (f32::INFINITY, f32::MAX, 1),
        (3.0, 3.0000002, 0),
    ];
    for (a, b, u) in pairs {
        g.check(
            &format!("approx_eq_ulps({}, {}, {}).to_string()", fl(a), fl(b), u),
            &a.approx_eq_ulps(&b, u).to_string(),
        );
    }
    g.end();

    // Transforms.
    g.begin("transform");
    let angles = [0.0f32, 30.0, 33.0, 45.0, 90.0, 180.0, -77.7, 270.0, 1234.5];
    for a in angles {
        g.check(
            &format!("dts(Transform::from_rotate({}))", fl(a)),
            &dts(Transform::from_rotate(a)),
        );
        g.check(
            &format!("dts(Transform::from_rotate_at({}, 10.5, -3.0))", fl(a)),
            &dts(Transform::from_rotate_at(a, 10.5, -3.0)),
        );
    }
    let tss = [
        Transform::identity(),
        Transform::from_row(1.2, 3.4, -5.6, -7.8, 1.2, 3.4),
        Transform::from_scale(2.0, -4.0),
        Transform::from_translate(5.5, -6.25),
        Transform::from_skew(0.3, -0.2),
        Transform::from_row(0.1, 0.2, 0.3, 0.6, 7.0, 8.0),
        Transform::from_row(1e-3, 0.0, 0.0, 1e-3, 1.0, 1.0),
        Transform::from_row(1.0, 2.0, 2.0, 4.0, 0.0, 0.0),
        Transform::from_row(0.0, 0.0, 0.0, 0.0, 1.0, 1.0),
        Transform::from_rotate(37.0).pre_scale(3.0, 0.5),
    ];
    for (i, a) in tss.iter().enumerate() {
        g.line(&format!("let a = ts_of(\"{}\")", dts(*a)));
        g.check("dts_opt(a.invert())", &dts_opt(a.invert()));
        g.check(
            "a.is_valid().to_string()",
            &a.is_valid().to_string(),
        );
        g.check(
            "hx(PathStroker::compute_resolution_scale(a))",
            &hx(PathStroker::compute_resolution_scale(a)),
        );
        let (sx, sy) = a.get_scale();
        g.check("hx(a.get_scale().0) + hx(a.get_scale().1)", &(hx(sx) + &hx(sy)));
        let b = tss[(i * 3 + 1) % tss.len()];
        g.line(&format!("let b = ts_of(\"{}\")", dts(b)));
        g.check("dts(a.pre_concat(b))", &dts(a.pre_concat(b)));
        g.check("dts(a.post_concat(b))", &dts(a.post_concat(b)));
        g.check("dts(a.pre_scale(1.5, -2.0))", &dts(a.pre_scale(1.5, -2.0)));
        g.check("dts(a.post_rotate(15.0))", &dts(a.post_rotate(15.0)));
        g.check(
            "dts(a.pre_rotate_at(15.0, 3.0, 4.0))",
            &dts(a.pre_rotate_at(15.0, 3.0, 4.0)),
        );
        let mut p = Point::from_xy(3.7, -1.9);
        a.map_point(&mut p);
        g.check("dpt(a.map_point(Point::from_xy(3.7, -1.9)))", &dpt(p));
        let r = Rect::from_ltrb(-3.5, 2.25, 17.0, 9.75).unwrap();
        g.check(
            "drect(Rect::from_ltrb(-3.5, 2.25, 17.0, 9.75).unwrap().transform(a))",
            &drect(r.transform(*a)),
        );
        let nz = NonZeroRect::from_ltrb(-3.5, 2.25, 17.0, 9.75).unwrap();
        g.check(
            "dnzrect(NonZeroRect::from_ltrb(-3.5, 2.25, 17.0, 9.75).unwrap().transform(a))",
            &dnzrect(nz.transform(*a)),
        );
    }
    g.end();

    // Rects.
    g.begin("rect");
    let rects = [
        (0.0f32, 0.0f32, 10.0f32, 10.0f32),
        (10.0, 10.0, 5.0, 10.0),
        (-30.0, 20.0, -10.0, 40.0),
        (0.3, 0.7, 10.5, 11.5),
        (-0.5, -1.5, 2.5, 3.5),
        (1.0, 1.0, 1.0, 5.0),
        (-3e38, 0.0, 3e38, 1.0),
        (2147483520.0, 0.0, 3e9, 1.0),
        (f32::NAN, 0.0, 1.0, 1.0),
        (0.0, 0.0, f32::INFINITY, 1.0),
    ];
    for (l, t, r, b) in rects {
        let rect = Rect::from_ltrb(l, t, r, b);
        let call = format!("Rect::from_ltrb({}, {}, {}, {})", fl(l), fl(t), fl(r), fl(b));
        g.check(&format!("drect({call})"), &drect(rect));
        g.check(
            &format!("dnzrect(NonZeroRect::from_ltrb({}, {}, {}, {}))", fl(l), fl(t), fl(r), fl(b)),
            &dnzrect(NonZeroRect::from_ltrb(l, t, r, b)),
        );
        g.check(
            &format!("drect(Rect::from_xywh({}, {}, {}, {}))", fl(l), fl(t), fl(r), fl(b)),
            &drect(Rect::from_xywh(l, t, r, b)),
        );
        if let Some(rect) = rect {
            g.line(&format!("let r = {call}.unwrap()"));
            g.check("dintrect(r.round())", &dintrect(rect.round()));
            g.check("dintrect(r.round_out())", &dintrect(rect.round_out()));
            g.check("dnzrect(r.to_non_zero_rect())", &dnzrect(rect.to_non_zero_rect()));
            g.check("drect(r.inset(1.5, 2.0))", &drect(rect.inset(1.5, 2.0)));
            g.check("drect(r.outset(1.5, 2.0))", &drect(rect.outset(1.5, 2.0)));
            let other = Rect::from_ltrb(2.0, -1.0, 8.5, 30.0).unwrap();
            g.check(
                "drect(r.intersect(Rect::from_ltrb(2.0, -1.0, 8.5, 30.0).unwrap()))",
                &drect(rect.intersect(&other)),
            );
            g.check(
                "drect(r.join(Rect::from_ltrb(2.0, -1.0, 8.5, 30.0).unwrap()))",
                &drect(rect.join(&other)),
            );
            let bbox = NonZeroRect::from_xywh(5.0, 7.0, 0.3, 120.0).unwrap();
            g.check(
                "drect(Some(r.bbox_transform(NonZeroRect::from_xywh(5.0, 7.0, 0.3, 120.0).unwrap())))",
                &drect(Some(rect.bbox_transform(bbox))),
            );
            if let Some(nz) = rect.to_non_zero_rect() {
                if nz.width() < 1e6 && nz.left().abs() < 1e6 {
                    g.check(
                        "dintrect(Some(r.to_non_zero_rect().unwrap().to_int_rect()))",
                        &dintrect(Some(nz.to_int_rect())),
                    );
                }
                g.check(
                    "dnzrect(Some(r.to_non_zero_rect().unwrap().bbox_transform(NonZeroRect::from_xywh(5.0, 7.0, 0.3, 120.0).unwrap())))",
                    &dnzrect(Some(nz.bbox_transform(bbox))),
                );
                g.check(
                    "dts(Transform::from_bbox(r.to_non_zero_rect().unwrap()))",
                    &dts(Transform::from_bbox(nz)),
                );
                g.check(
                    "dsize(Some(r.to_non_zero_rect().unwrap().size()))",
                    &dsize(Some(nz.size())),
                );
            }
        }
    }
    let point_sets: Vec<Vec<(f32, f32)>> = vec![
        vec![],
        vec![(1.0, 2.0)],
        vec![(3.0, 2.0), (1.0, 5.0)],
        vec![(3.0, 2.0), (1.0, f32::NAN)],
        vec![(3.0, 2.0), (1.0, 5.0), (-4.0, 0.5)],
        vec![(3.0, 2.0), (1.0, 5.0), (-4.0, 0.5), (7.0, -0.0)],
        vec![(0.0, -0.0), (-0.0, 0.0), (0.0, 0.0)],
        vec![(3.0, 2.0), (1.0, 5.0), (f32::INFINITY, 0.5), (7.0, 1.0), (0.0, 0.0)],
        vec![(1e30, 1e30), (-1e30, 2.0), (0.0, 0.0)],
    ];
    for ps in point_sets {
        let pts: Vec<Point> = ps.iter().map(|&(x, y)| Point::from_xy(x, y)).collect();
        let s: Vec<String> = ps
            .iter()
            .map(|&(x, y)| format!("Point::from_xy({}, {})", fl(x), fl(y)))
            .collect();
        g.check(
            &format!("drect(Rect::from_points([{}][:]))", s.join(", ")),
            &drect(Rect::from_points(&pts)),
        );
    }
    // IntRect.
    let irs = [
        (0i32, 0i32, 0u32, 0u32),
        (0, 0, 1, 0),
        (0, 0, u32::MAX, 1),
        (i32::MAX, 0, 1, 1),
        (1, 2, 30, 40),
        (-5, -6, 7, 8),
    ];
    for (x, y, w, h) in irs {
        let r = IntRect::from_xywh(x, y, w, h);
        let call = format!("IntRect::from_xywh({x}, {y}, {w}U, {h}U)");
        g.check(&format!("dintrect({call})"), &dintrect(r));
        if let Some(r) = r {
            let o = IntRect::from_xywh(11, 12, 50, 60).unwrap();
            g.line(&format!("let ir = {call}.unwrap()"));
            g.check(
                "dintrect(ir.intersect(IntRect::from_xywh(11, 12, 50U, 60U).unwrap()))",
                &dintrect(r.intersect(&o)),
            );
            g.check("dintrect(ir.inset(2, 3))", &dintrect(r.inset(2, 3)));
            g.check("dintrect(ir.make_outset(2, 3))", &dintrect(r.make_outset(2, 3)));
            g.check("drect(Some(ir.to_rect()))", &drect(Some(r.to_rect())));
            g.check(
                "ir.contains(IntRect::from_xywh(11, 12, 5U, 6U).unwrap()).to_string()",
                &r.contains(&IntRect::from_xywh(11, 12, 5, 6).unwrap()).to_string(),
            );
        }
    }
    g.end();

    // Sizes.
    g.begin("size");
    let sizes = [(100.0f32, 50.0f32), (3.0, 7.0), (0.4, 0.6), (1e-3, 2.5)];
    for (w, h) in sizes {
        for (w2, h2) in sizes {
            let a = Size::from_wh(w, h).unwrap();
            let b = Size::from_wh(w2, h2).unwrap();
            let ca = format!("Size::from_wh({}, {}).unwrap()", fl(w), fl(h));
            let cb = format!("Size::from_wh({}, {}).unwrap()", fl(w2), fl(h2));
            g.check(&format!("dsize(Some({ca}.scale_to({cb})))"), &dsize(Some(a.scale_to(b))));
            g.check(&format!("dsize(Some({ca}.expand_to({cb})))"), &dsize(Some(a.expand_to(b))));
        }
        let a = Size::from_wh(w, h).unwrap();
        let ca = format!("Size::from_wh({}, {}).unwrap()", fl(w), fl(h));
        g.check(&format!("dsize({ca}.scale_by(1.7))"), &dsize(a.scale_by(1.7)));
        g.check(&format!("dsize({ca}.scale_to_width(33.3))"), &dsize(a.scale_to_width(33.3)));
        g.check(&format!("dsize({ca}.scale_to_height(0.1))"), &dsize(a.scale_to_height(0.1)));
        g.check(&format!("dintsize(Some({ca}.to_int_size()))"), &dintsize(Some(a.to_int_size())));
        g.check(&format!("drect({ca}.to_rect(1.5, -2.0))"), &drect(a.to_rect(1.5, -2.0)));
    }
    let isizes = [(100u32, 50u32), (3, 7), (1, 1), (640, 480)];
    for (w, h) in isizes {
        let a = IntSize::from_wh(w, h).unwrap();
        let ca = format!("IntSize::from_wh({w}U, {h}U).unwrap()");
        for (w2, h2) in isizes {
            let b = IntSize::from_wh(w2, h2).unwrap();
            let cb = format!("IntSize::from_wh({w2}U, {h2}U).unwrap()");
            g.check(
                &format!("dintsize(Some({ca}.scale_to({cb})))"),
                &dintsize(Some(a.scale_to(b))),
            );
        }
        g.check(&format!("dintsize({ca}.scale_by(1.37))"), &dintsize(a.scale_by(1.37)));
        g.check(&format!("dintsize({ca}.scale_by(0.001))"), &dintsize(a.scale_by(0.001)));
        g.check(&format!("dintsize({ca}.scale_to_width(77U))"), &dintsize(a.scale_to_width(77)));
        g.check(&format!("dintsize({ca}.scale_to_height(5U))"), &dintsize(a.scale_to_height(5)));
        g.check(
            &format!("dintrect(Some({ca}.to_int_rect(-3, 4)))"),
            &dintrect(Some(a.to_int_rect(-3, 4))),
        );
    }
    g.end();

    // Dash construction.
    g.begin("stroke dash new");
    let dashes: Vec<(Vec<f32>, f32)> = vec![
        (vec![], 0.0),
        (vec![1.0], 0.0),
        (vec![1.0, 2.0, 3.0], 0.0),
        (vec![1.0, -2.0], 0.0),
        (vec![0.0, 0.0], 0.0),
        (vec![1.0, 1.0], f32::INFINITY),
        (vec![1.0, f32::INFINITY], 0.0),
        (vec![6.0, 4.5], 0.0),
        (vec![6.0, 4.5], 13.25),
        (vec![6.0, 4.5], -13.25),
        (vec![6.0, 4.5], -10.5),
        (vec![0.0, 3.0, 2.0, 0.0], 3.0),
        (vec![1e-3, 1e5], 7.0),
    ];
    for (arr, off) in dashes {
        let d = StrokeDash::new(arr.clone(), off);
        let s: Vec<String> = arr.iter().map(|v| fl(*v)).collect();
        let expected = match &d {
            None => "None".to_string(),
            Some(d) => {
                // Private fields, read through Debug.
                let dbg = format!("{d:?}");
                let field = |name: &str| -> String {
                    let i = dbg.find(&format!("{name}: ")).unwrap() + name.len() + 2;
                    let rest = &dbg[i..];
                    let j = rest.find([',', ' ', '}']).unwrap();
                    rest[..j].to_string()
                };
                let offset: f32 = field("offset").parse().unwrap();
                let first_len: f32 = field("first_len").parse().unwrap();
                let first_index: usize = field("first_index").parse().unwrap();
                format!("{},{},{}", hx(offset), hx(first_len), first_index)
            }
        };
        g.check(
            &format!("ddash(StrokeDash::new([{}], {}))", s.join(", "), fl(off)),
            &expected,
        );
    }
    g.end();
}

fn extra_tests(g: &mut Gen) {
    // Rotation sweep (sinf/cosf; LLVM may merge them into a sincos call).
    g.begin("rotation sweep");
    let mut all = String::new();
    for i in 0..4000 {
        let a = i as f32 * 0.7371 - 1474.0;
        all.push_str(&dts(Transform::from_rotate(a)));
        all.push(';');
    }
    g.line("let all = StringBuilder()");
    g.line("for i in 0..<4000 {");
    g.line(&format!("  let a = Float::from_int(i) * {} - {}", fl(0.7371), fl(1474.0)));
    g.line("  all.write_string(dts(Transform::from_rotate(a)))");
    g.line("  all.write_char(\x27;\x27)");
    g.line("}");
    g.check("all.to_string()", &all);
    g.end();

    // Builders and iterators.
    g.begin("builders");
    let r = Rect::from_ltrb(1.5, -2.0, 30.25, 8.0).unwrap();
    g.line("let r = Rect::from_ltrb(1.5, -2.0, 30.25, 8.0).unwrap()");
    g.check("dpath(Some(PathBuilder::from_rect(r)))", &dpath(&Some(PathBuilder::from_rect(r))));
    g.check("dpath(PathBuilder::from_oval(r))", &dpath(&PathBuilder::from_oval(r)));
    g.check(
        "dpath(PathBuilder::from_circle(3.0, 4.0, 0.75))",
        &dpath(&PathBuilder::from_circle(3.0, 4.0, 0.75)),
    );
    g.check(
        "dpath(PathBuilder::from_circle(3.0, 4.0, -1.0))",
        &dpath(&PathBuilder::from_circle(3.0, 4.0, -1.0)),
    );
    let mut pb = PathBuilder::new();
    pb.move_to(0.0, 0.0);
    pb.line_to(10.0, 0.0);
    pb.push_path(&PathBuilder::from_rect(r));
    pb.line_to(5.0, 5.0);
    pb.close();
    pb.quad_to(1.0, 2.0, 3.0, 4.0);
    pb.close();
    pb.close();
    pb.cubic_to(1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
    let p = pb.finish();
    g.line("let pb = PathBuilder::new()");
    g.line("pb.move_to(0.0, 0.0)");
    g.line("pb.line_to(10.0, 0.0)");
    g.line("pb.push_path(PathBuilder::from_rect(r))");
    g.line("pb.line_to(5.0, 5.0)");
    g.line("pb.close()");
    g.line("pb.quad_to(1.0, 2.0, 3.0, 4.0)");
    g.line("pb.close()");
    g.line("pb.close()");
    g.line("pb.cubic_to(1.0, 2.0, 3.0, 4.0, 5.0, 6.0)");
    g.line("let p = pb.finish()");
    g.check("dpath(p)", &dpath(&p));
    let p = p.unwrap();
    let mut it = p.segments();
    it.set_auto_close(true);
    let mut s = String::new();
    while let Some(seg) = it.next() {
        write!(s, "{:?}/{:?};", it.curr_verb(), it.next_verb()).unwrap();
        match seg {
            PathSegment::LineTo(a) => write!(s, "L {} ", dpt(a)).unwrap(),
            PathSegment::Close => s.push_str("Z "),
            _ => s.push_str("_ "),
        }
    }
    g.line("let it = p.unwrap().segments()");
    g.line("it.set_auto_close(true)");
    g.line("let s = StringBuilder()");
    g.line("while it.next() is Some(seg) {");
    g.line("  let nv = match it.next_verb() { Some(v) => \"Some(\\{dverb(v)})\"; None => \"None\" }");
    g.line("  s.write_string(\"\\{dverb(it.curr_verb())}/\\{nv};\")");
    g.line("  match seg {");
    g.line("    LineTo(a) => s.write_string(\"L \\{dpt(a)} \")");
    g.line("    Close => s.write_string(\"Z \")");
    g.line("    _ => s.write_string(\"_ \")");
    g.line("  }");
    g.line("}");
    g.check("s.to_string()", &s);
    g.end();

    g.begin("normalized u8");
    for v in [0.0f32, 0.1, 0.5, 0.998, 1.0] {
        let n = NormalizedF32::new(v).unwrap();
        g.check(
            &format!("NormalizedF32::new({}).unwrap().to_u8().to_int().to_string()", fl(v)),
            &n.to_u8().to_string(),
        );
        g.check(
            &format!("NormalizedF32::new({}).unwrap().to_u16().to_int().to_string()", fl(v)),
            &n.to_u16().to_string(),
        );
    }
    for b in [0u8, 1, 127, 255] {
        g.check(
            &format!("hx(NormalizedF32::new_u8(b\x27\\x{b:02X}\x27).get())"),
            &hx(NormalizedF32::new_u8(b).get()),
        );
    }
    g.end();
}

fn main() {
    let mut g = Gen {
        out: String::new(),
        n: 0,
    };
    g.out.push_str(
        "// Generated by oracle/src/bin/gen_tiny_skia_path_tests.rs from tiny-skia-path 0.12.0.
// Do not edit by hand. Helpers (dumps, `bulk_fuzz`) are in oracle_support_wbtest.mbt.
",
    );

    misc_tests(&mut g);
    extra_tests(&mut g);

    // path_geometry public functions.
    g.begin("path_geometry");
    let quad_roots = [
        (1.0f32, -3.0f32, 2.0f32),
        (0.0, 2.0, -1.0),
        (2.0, -2.0, 0.5),
        (1.0, 0.0, -0.25),
        (-4.0, 1.0, 0.1),
        (1e-8, 1.0, -0.5),
        (3.0, -2.9999998, 0.7),
    ];
    for (a, b, c) in quad_roots {
        let mut roots = tiny_skia_path::path_geometry::new_t_values();
        let n = tiny_skia_path::path_geometry::find_unit_quad_roots(a, b, c, &mut roots);
        let s: Vec<String> = roots[..n].iter().map(|r| hx(r.get())).collect();
        g.line(&format!("let roots = new_t_values()"));
        g.line(&format!(
            "let n = find_unit_quad_roots({}, {}, {}, roots)",
            fl(a),
            fl(b),
            fl(c)
        ));
        g.check(
            "roots[0:n].iter().map(fn(r) { hx(r.get()) }).collect().join(\" \")",
            &s.join(" "),
        );
    }
    let cubics: Vec<[(f32, f32); 4]> = vec![
        [(20.0, 160.0), (20.0001, 160.0), (160.0, 20.0), (160.0001, 20.0)],
        [(0.0, 0.0), (100.0, 100.0), (0.0, 100.0), (100.0, 0.0)],
        [(0.0, 0.0), (30.0, 80.0), (70.0, -40.0), (100.0, 10.0)],
        [(10.0, 10.0), (10.0, 10.0), (50.0, 90.0), (90.0, 10.0)],
        [(0.0, 0.0), (1.0, 0.0), (2.0, 0.0), (3.0, 0.0)],
    ];
    for c in &cubics {
        let pts: Vec<Point> = c.iter().map(|&(x, y)| Point::from_xy(x, y)).collect();
        let src: [Point; 4] = [pts[0], pts[1], pts[2], pts[3]];
        let s: Vec<String> = c
            .iter()
            .map(|&(x, y)| format!("Point::from_xy({}, {})", fl(x), fl(y)))
            .collect();
        let mut tv = [NormalizedF32::ZERO; 3];
        let r = tiny_skia_path::path_geometry::find_cubic_max_curvature(&src, &mut tv);
        let rs: Vec<String> = r.iter().map(|t| hx(t.get())).collect();
        g.line(&format!("let src = [{}]", s.join(", ")));
        g.check(
            "find_cubic_max_curvature(src[:], Array::make(3, NormalizedF32::zero())).iter().map(fn(t) { hx(t.get()) }).collect().join(\" \")",
            &rs.join(" "),
        );
        let mut dst = [Point::zero(); 7];
        let t = tiny_skia_path::NormalizedF32Exclusive::new(0.3).unwrap();
        tiny_skia_path::path_geometry::chop_cubic_at2(&src, t, &mut dst);
        let ds: Vec<String> = dst.iter().map(|p| dpt(*p)).collect();
        g.line("let dst = Array::make(7, Point::zero())");
        g.line("chop_cubic_at2(src[:], NormalizedF32Exclusive::new(0.3).unwrap(), dst)");
        g.check("dst.map(dpt).join(\" \")", &ds.join(" "));
        let mut qd = [Point::zero(); 5];
        tiny_skia_path::path_geometry::chop_quad_at(&src[..3], t, &mut qd);
        let qs: Vec<String> = qd.iter().map(|p| dpt(*p)).collect();
        g.line("let qd = Array::make(5, Point::zero())");
        g.line("chop_quad_at(src[0:3], NormalizedF32Exclusive::new(0.3).unwrap(), qd)");
        g.check("qd.map(dpt).join(\" \")", &qs.join(" "));
    }
    g.end();

    // Hand-written paths.
    let all = STROKES;
    let mut cases: Vec<(&str, Vec<Op>)> = vec![
        (
            "triangle",
            vec![Op::M(10.0, 10.0), Op::L(20.0, 50.0), Op::L(30.0, 10.0), Op::Z],
        ),
        (
            "bug_26 polyline",
            vec![
                Op::M(665.54, 287.3),
                Op::L(675.67, 273.04),
                Op::L(675.52, 271.32),
                Op::L(674.79, 269.61),
                Op::L(674.05, 268.04),
                Op::L(672.88, 266.47),
                Op::L(671.27, 264.9),
            ],
        ),
        ("rect", vec![Op::Rect(10.0, 20.0, 110.0, 70.0)]),
        ("oval", vec![Op::Oval(-20.0, 5.0, 60.5, 45.25)]),
        ("circle", vec![Op::Circle(50.0, 50.0, 40.0)]),
        ("tiny circle", vec![Op::Circle(0.5, 0.5, 0.01)]),
        ("zero circle", vec![Op::Circle(5.0, 5.0, 0.0), Op::M(1.0, 1.0), Op::L(2.0, 2.0)]),
        (
            "quad",
            vec![Op::M(10.0, 80.0), Op::Q(95.0, 10.0, 180.0, 80.0)],
        ),
        (
            "quad closed",
            vec![Op::M(10.0, 80.0), Op::Q(95.0, 10.0, 180.0, 80.0), Op::Z],
        ),
        (
            "quad degenerate (control outside ends)",
            vec![Op::M(0.0, 0.0), Op::Q(150.0, 0.0, 100.0, 0.0)],
        ),
        (
            "quad control on line",
            vec![Op::M(0.0, 0.0), Op::Q(50.0, 50.0, 100.0, 100.0)],
        ),
        (
            "quad control equals start",
            vec![Op::M(0.0, 0.0), Op::Q(0.0, 0.0, 100.0, 50.0)],
        ),
        (
            "quad all same",
            vec![Op::M(5.0, 5.0), Op::Q(5.0, 5.0, 5.0, 5.0)],
        ),
        (
            "quad sharp",
            vec![Op::M(0.0, 0.0), Op::Q(100.0, 1.0, 0.0, 2.0)],
        ),
        (
            "cubic s",
            vec![Op::M(0.0, 0.0), Op::C(30.0, 80.0, 70.0, -40.0, 100.0, 10.0)],
        ),
        (
            "cubic loop",
            vec![Op::M(0.0, 0.0), Op::C(120.0, 100.0, -20.0, 100.0, 100.0, 0.0)],
        ),
        (
            "cubic cusp",
            vec![Op::M(0.0, 0.0), Op::C(100.0, 100.0, 0.0, 100.0, 100.0, 0.0)],
        ),
        (
            "cubic degenerate ab",
            vec![Op::M(10.0, 10.0), Op::C(10.0, 10.0, 50.0, 90.0, 90.0, 10.0)],
        ),
        (
            "cubic degenerate cd",
            vec![Op::M(10.0, 10.0), Op::C(50.0, 90.0, 90.0, 10.0, 90.0, 10.0)],
        ),
        (
            "cubic collinear",
            vec![Op::M(0.0, 0.0), Op::C(-10.0, 0.0, 120.0, 0.0, 100.0, 0.0)],
        ),
        (
            "cubic collinear 3",
            vec![Op::M(0.0, 0.0), Op::C(200.0, 0.0, -100.0, 0.0, 100.0, 0.0)],
        ),
        (
            "cubic_1",
            vec![
                Op::M(51.0161362, 1511.52478),
                Op::C(51.0161362, 1511.52478, 51.0161362, 1511.52478, 51.0161362, 1511.52478),
            ],
        ),
        (
            "cubic_2",
            vec![
                Op::M(f32::from_bits(0x424c1086), f32::from_bits(0x44bcf0cb)),
                Op::C(
                    f32::from_bits(0x424c107c),
                    f32::from_bits(0x44bcf0cb),
                    f32::from_bits(0x424c10c2),
                    f32::from_bits(0x44bcf0cb),
                    f32::from_bits(0x424c1119),
                    f32::from_bits(0x44bcf0ca),
                ),
            ],
        ),
        (
            "quad_stroker_one_off",
            vec![
                Op::M(f32::from_bits(0x43c99223), f32::from_bits(0x42b7417e)),
                Op::Q(
                    f32::from_bits(0x4285d839),
                    f32::from_bits(0x43ed6645),
                    f32::from_bits(0x43c941c8),
                    f32::from_bits(0x42b3ace3),
                ),
            ],
        ),
        (
            "cubic_stroker_one_off",
            vec![
                Op::M(f32::from_bits(0x433f5370), f32::from_bits(0x43d1f4b3)),
                Op::C(
                    f32::from_bits(0x4331cb76),
                    f32::from_bits(0x43ea3340),
                    f32::from_bits(0x4388f498),
                    f32::from_bits(0x42f7f08d),
                    f32::from_bits(0x43f1cd32),
                    f32::from_bits(0x42802ec1),
                ),
            ],
        ),
        (
            "zero length line",
            vec![Op::M(10.0, 10.0), Op::L(10.0, 10.0)],
        ),
        ("move close", vec![Op::M(5.0, 5.0), Op::Z]),
        (
            "move zero lines close",
            vec![Op::M(5.0, 5.0), Op::L(5.0, 5.0), Op::L(5.0, 5.0), Op::Z],
        ),
        (
            "teeny line",
            vec![Op::M(5.0, 5.0), Op::L(5.00001, 5.0), Op::L(40.0, 5.0)],
        ),
        (
            "near 180 turn",
            vec![Op::M(0.0, 0.0), Op::L(100.0, 0.0), Op::L(0.0, 0.1)],
        ),
        (
            "exact 180 turn",
            vec![Op::M(0.0, 0.0), Op::L(100.0, 0.0), Op::L(50.0, 0.0)],
        ),
        (
            "right angles open",
            vec![Op::M(0.0, 0.0), Op::L(50.0, 0.0), Op::L(50.0, 50.0), Op::L(0.0, 50.0)],
        ),
        (
            "multi contour",
            vec![
                Op::M(0.0, 0.0),
                Op::L(40.0, 0.0),
                Op::L(40.0, 40.0),
                Op::Z,
                Op::L(-20.0, 10.0),
                Op::M(100.0, 100.0),
                Op::Q(150.0, 50.0, 200.0, 100.0),
                Op::C(220.0, 150.0, 120.0, 180.0, 100.0, 100.0),
                Op::Z,
                Op::M(300.0, 0.0),
                Op::L(310.0, 5.0),
            ],
        ),
        (
            "double move",
            vec![Op::M(1.0, 1.0), Op::M(2.0, 2.0), Op::L(30.0, 2.0)],
        ),
        ("line without move", vec![Op::L(30.0, 20.0), Op::L(30.0, 40.0)]),
        ("single move", vec![Op::M(30.0, 20.0)]),
        (
            "small curves",
            vec![
                Op::M(0.001, 0.002),
                Op::C(0.003, 0.001, 0.004, 0.005, 0.002, 0.006),
                Op::Q(0.0, 0.004, 0.001, 0.001),
            ],
        ),
        (
            "large coords",
            vec![
                Op::M(1e6, -2e6),
                Op::L(1.5e6, 3e6),
                Op::C(2e6, 1e6, -1e6, 0.0, 1e6, -2e6),
                Op::Z,
            ],
        ),
        (
            "big",
            vec![
                Op::M(f32::from_bits(0x46380000), f32::from_bits(0xc6380000)),
                Op::L(f32::from_bits(0x46a00000), f32::from_bits(0xc6a00000)),
                Op::L(f32::from_bits(0x468c0000), f32::from_bits(0xc68c0000)),
                Op::L(f32::from_bits(0x46100000), f32::from_bits(0xc6100000)),
                Op::L(f32::from_bits(0x46380000), f32::from_bits(0xc6380000)),
                Op::Z,
            ],
        ),
        (
            "star",
            vec![
                Op::M(50.0, 0.0),
                Op::L(61.0, 35.0),
                Op::L(98.0, 35.0),
                Op::L(68.0, 57.0),
                Op::L(79.0, 91.0),
                Op::L(50.0, 70.0),
                Op::L(21.0, 91.0),
                Op::L(32.0, 57.0),
                Op::L(2.0, 35.0),
                Op::L(39.0, 35.0),
                Op::Z,
            ],
        ),
        (
            "rounded rect like",
            vec![
                Op::M(10.0, 0.0),
                Op::L(90.0, 0.0),
                Op::C(95.5, 0.0, 100.0, 4.5, 100.0, 10.0),
                Op::L(100.0, 40.0),
                Op::Q(100.0, 50.0, 90.0, 50.0),
                Op::L(10.0, 50.0),
                Op::C(4.5, 50.0, 0.0, 45.5, 0.0, 40.0),
                Op::L(0.0, 10.0),
                Op::C(0.0, 4.5, 4.5, 0.0, 10.0, 0.0),
                Op::Z,
            ],
        ),
    ];
    for (name, ops) in cases.drain(..) {
        g.path_case(name, &ops, all, true);
    }

    // The `big` case with its upstream stroke width.
    {
        let ops = vec![
            Op::M(f32::from_bits(0x46380000), f32::from_bits(0xc6380000)),
            Op::L(f32::from_bits(0x46a00000), f32::from_bits(0xc6a00000)),
            Op::L(f32::from_bits(0x468c0000), f32::from_bits(0xc68c0000)),
            Op::L(f32::from_bits(0x46100000), f32::from_bits(0xc6100000)),
            Op::L(f32::from_bits(0x46380000), f32::from_bits(0xc6380000)),
            Op::Z,
        ];
        g.path_case("big wide", &ops, &[sc(1.49679073e+10, 4.0, 0, 0, 1.0)], false);
        let ops = vec![
            Op::M(f32::from_bits(0x43c99223), f32::from_bits(0x42b7417e)),
            Op::Q(
                f32::from_bits(0x4285d839),
                f32::from_bits(0x43ed6645),
                f32::from_bits(0x43c941c8),
                f32::from_bits(0x42b3ace3),
            ),
        ];
        g.path_case("quad_stroker_one_off wide", &ops, &[sc(164.683548, 4.0, 0, 0, 1.0)], false);
        let ops = vec![
            Op::M(f32::from_bits(0x433f5370), f32::from_bits(0x43d1f4b3)),
            Op::C(
                f32::from_bits(0x4331cb76),
                f32::from_bits(0x43ea3340),
                f32::from_bits(0x4388f498),
                f32::from_bits(0x42f7f08d),
                f32::from_bits(0x43f1cd32),
                f32::from_bits(0x42802ec1),
            ),
        ];
        g.path_case("cubic_stroker_one_off wide", &ops, &[sc(42.835968, 4.0, 0, 0, 1.0)], false);
        let ops = vec![
            Op::M(0.0, 1.0),
            Op::Q(1.0, 6.0, 0.0, 3.0),
        ];
        g.path_case("extreme quad width", &ops, &[sc(5e7, 4.0, 0, 0, 1.0), sc(5e7, 4.0, 1, 2, 1.0)], false);
    }

    // Random paths.
    let mut rng = Rng(0x9E3779B97F4A7C15);
    for i in 0..150 {
        let ops = random_ops(&mut rng);
        let strokes: Vec<StrokeCfg> = (0..3).map(|_| rng.stroke()).collect();
        g.path_case(&format!("random {i}"), &ops, &strokes, i % 10 == 0);
    }

    // Bulk fuzzing: the RNG and path construction are mirrored by `bulk_fuzz`
    // in the generated MoonBit helpers; only the digest is compared.
    assert_eq!(1e-4f32.to_bits(), 0x38D1B717);
    assert_eq!(1e-3f32.to_bits(), 0x3A83126F);
    for chunk in 0..24u64 {
        let seed = 0xD1B54A32D192ED03u64.wrapping_mul(chunk + 1);
        g.begin(&format!("bulk fuzz {chunk}"));
        g.check(&format!("bulk_fuzz({seed}UL, 120)"), &bulk_fuzz(seed, 120));
        g.end();
    }

    print!("{}", g.out);
}
