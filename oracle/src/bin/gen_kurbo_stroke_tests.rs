//! Generates `kurbo/testdata/stroke_oracle.tsv`: differential tests for the
//! MoonBit port of kurbo 0.13.1's stroke expansion (`stroke.rs`) and its
//! dependencies (`offset.rs`, `arc.rs`, arclength / nearest / root finding),
//! with expected results produced by the real crate.
//!
//! Every line is `op \t args... \t expected`. Floats (inputs and outputs) are
//! written as the 16 hex digits of `f64::to_bits`, so the comparison in
//! `kurbo/stroke_oracle_test.mbt` is bit-exact (except that all NaNs are
//! written as `nan`). Paths are written as tokens
//! `M x y`, `L x y`, `Q x1 y1 x y`, `C x1 y1 x2 y2 x y`, `Z`. Long outputs
//! are recorded as `#<len> <fnv1a64> <prefix>` of their serialization.
//!
//! Usage (from `oracle/`, so that `rust-toolchain.toml` applies):
//!   cargo run --release --offline --bin gen_kurbo_stroke_tests \
//!     > ../kurbo/testdata/stroke_oracle.tsv
//! Debugging: `... --bin gen_kurbo_stroke_tests -- --full` writes every
//! expected output in full (no digests).

use std::fmt::Write as _;
use std::panic::{AssertUnwindSafe, catch_unwind};

use kurbo::common::solve_cubic;
use kurbo::offset::offset_cubic;
use kurbo::{
    Arc, BezPath, Cap, CubicBez, Join, Line, ParamCurve, ParamCurveArclen, ParamCurveNearest,
    PathEl, PathSeg, Point, QuadBez, Stroke, StrokeCtx, StrokeOpts, Vec2,
};

static mut FULL: bool = false;

/// The exact bits of `v`. NaNs are written as `nan`: LLVM does not preserve
/// NaN signs/payloads (e.g. it folds `(-x) * c` into `x * (-c)`).
fn hx(v: f64) -> String {
    if v.is_nan() {
        return "nan".into();
    }
    format!("{:016x}", v.to_bits())
}

fn digest(s: String) -> String {
    if unsafe { FULL } || s.len() <= 600 {
        return s;
    }
    let mut h: u64 = 0xcbf29ce484222325;
    for b in s.bytes() {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    format!("#{} {:016x} {}", s.len(), h, &s[..200])
}

fn pt(out: &mut String, p: Point) {
    write!(out, " {} {}", hx(p.x), hx(p.y)).unwrap();
}

fn path_str(els: impl IntoIterator<Item = PathEl>) -> String {
    let mut s = String::new();
    for el in els {
        match el {
            PathEl::MoveTo(p) => {
                s.push_str(" M");
                pt(&mut s, p);
            }
            PathEl::LineTo(p) => {
                s.push_str(" L");
                pt(&mut s, p);
            }
            PathEl::QuadTo(p1, p2) => {
                s.push_str(" Q");
                pt(&mut s, p1);
                pt(&mut s, p2);
            }
            PathEl::CurveTo(p1, p2, p3) => {
                s.push_str(" C");
                pt(&mut s, p1);
                pt(&mut s, p2);
                pt(&mut s, p3);
            }
            PathEl::ClosePath => s.push_str(" Z"),
        }
    }
    if s.is_empty() {
        "-".into()
    } else {
        s[1..].to_string()
    }
}

fn nums(v: &[f64]) -> String {
    if v.is_empty() {
        return "-".into();
    }
    v.iter().map(|x| hx(*x)).collect::<Vec<_>>().join(" ")
}

fn seg_str(seg: PathSeg) -> String {
    let mut s = String::new();
    match seg {
        PathSeg::Line(l) => {
            s.push('L');
            pt(&mut s, l.p0);
            pt(&mut s, l.p1);
        }
        PathSeg::Quad(q) => {
            s.push('Q');
            pt(&mut s, q.p0);
            pt(&mut s, q.p1);
            pt(&mut s, q.p2);
        }
        PathSeg::Cubic(c) => {
            s.push('C');
            pt(&mut s, c.p0);
            pt(&mut s, c.p1);
            pt(&mut s, c.p2);
            pt(&mut s, c.p3);
        }
    }
    s
}

fn join_str(j: Join) -> &'static str {
    match j {
        Join::Bevel => "bevel",
        Join::Miter => "miter",
        Join::Round => "round",
    }
}

fn cap_str(c: Cap) -> &'static str {
    match c {
        Cap::Butt => "butt",
        Cap::Square => "square",
        Cap::Round => "round",
    }
}

/// xorshift64* with a fixed seed.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545F4914F6CDD1D)
    }
    fn below(&mut self, n: u64) -> u64 {
        self.next() % n
    }
    fn unit(&mut self) -> f64 {
        (self.next() >> 11) as f64 / (1u64 << 53) as f64
    }
    fn range(&mut self, lo: f64, hi: f64) -> f64 {
        lo + (hi - lo) * self.unit()
    }
    fn pick<T: Copy>(&mut self, v: &[T]) -> T {
        v[self.below(v.len() as u64) as usize]
    }
}

fn p(x: f64, y: f64) -> Point {
    Point::new(x, y)
}

struct Out {
    lines: Vec<String>,
    skipped: usize,
}

impl Out {
    fn push(&mut self, fields: Vec<String>, expected: String) {
        let mut line = fields.join("\t");
        line.push('\t');
        line.push_str(&digest(expected));
        self.lines.push(line);
    }
}

fn style_fields(style: &Stroke) -> Vec<String> {
    let dashes: Vec<f64> = style.dash_pattern.iter().copied().collect();
    vec![
        hx(style.width),
        join_str(style.join).into(),
        hx(style.miter_limit),
        cap_str(style.start_cap).into(),
        cap_str(style.end_cap).into(),
        hx(style.dash_offset),
        nums(&dashes),
    ]
}

/// `stroke_with`, reusing one context (as vello does).
fn case_stroke(
    out: &mut Out,
    ctx: &mut StrokeCtx,
    path: &BezPath,
    style: &Stroke,
    stable: bool,
    tol: f64,
) {
    let opts = StrokeOpts::default().stable_dash_order(stable);
    let res = catch_unwind(AssertUnwindSafe(|| {
        kurbo::stroke_with(path.iter(), style, &opts, tol, ctx);
        path_str(ctx.output().iter())
    }));
    match res {
        Ok(s) => {
            let mut fields = vec![if stable { "stroke_stable" } else { "stroke" }.to_string()];
            fields.extend(style_fields(style));
            fields.push(hx(tol));
            fields.push(path_str(path.iter()));
            out.push(fields, s);
        }
        Err(_) => {
            // Leave the context in a defined state for the next case.
            *ctx = StrokeCtx::default();
            out.skipped += 1;
        }
    }
}

/// `stroke` (fresh context).
fn case_stroke_fresh(out: &mut Out, path: &BezPath, style: &Stroke, tol: f64) {
    let res = catch_unwind(AssertUnwindSafe(|| {
        path_str(kurbo::stroke(path.iter(), style, &StrokeOpts::default(), tol).iter())
    }));
    match res {
        Ok(s) => {
            let mut fields = vec!["stroke_fresh".to_string()];
            fields.extend(style_fields(style));
            fields.push(hx(tol));
            fields.push(path_str(path.iter()));
            out.push(fields, s);
        }
        Err(_) => out.skipped += 1,
    }
}

fn case_dash(out: &mut Out, path: &BezPath, offset: f64, dashes: &[f64]) {
    let res = catch_unwind(AssertUnwindSafe(|| {
        path_str(kurbo::dash(path.iter(), offset, dashes))
    }));
    match res {
        Ok(s) => out.push(
            vec![
                "dash".into(),
                hx(offset),
                nums(dashes),
                path_str(path.iter()),
            ],
            s,
        ),
        Err(_) => out.skipped += 1,
    }
}

fn seg_case(out: &mut Out, seg: PathSeg, accuracies: &[f64]) {
    for &acc in accuracies {
        let len = seg.arclen(acc);
        out.push(vec!["arclen".into(), seg_str(seg), hx(acc)], hx(len));
        for frac in [-0.5, 0.0, 0.1, 0.25, 0.5, 0.75, 0.999, 1.0, 1.5] {
            let target = len * frac;
            let t = seg.inv_arclen(target, acc);
            out.push(
                vec!["inv_arclen".into(), seg_str(seg), hx(target), hx(acc)],
                hx(t),
            );
        }
    }
    for (t0, t1) in [(0.0, 1.0), (0.0, 0.3), (0.25, 0.75), (0.6, 1.0), (0.3, 0.3001)] {
        out.push(
            vec!["subsegment".into(), seg_str(seg), hx(t0), hx(t1)],
            seg_str(seg.subsegment(t0..t1)),
        );
    }
    for q in [p(0.0, 0.0), p(5.0, -3.0), seg.eval(0.37), p(1e3, 1e3)] {
        match seg {
            PathSeg::Line(l) => {
                let n = l.nearest(q, 1e-9);
                out.push(
                    vec!["nearest".into(), seg_str(seg), hx(q.x), hx(q.y)],
                    format!("{} {}", hx(n.distance_sq), hx(n.t)),
                );
            }
            PathSeg::Quad(qb) => {
                let n = qb.nearest(q, 1e-9);
                out.push(
                    vec!["nearest".into(), seg_str(seg), hx(q.x), hx(q.y)],
                    format!("{} {}", hx(n.distance_sq), hx(n.t)),
                );
            }
            PathSeg::Cubic(_) => {}
        }
    }
    if let PathSeg::Cubic(c) = seg {
        out.push(
            vec!["inflections".into(), seg_str(seg)],
            nums(&c.inflections()),
        );
        for d in [-0.5, 0.5, 5.0, -20.0, 300.0] {
            for tol in [0.25, 0.01, 1.0] {
                let res = catch_unwind(AssertUnwindSafe(|| {
                    let mut r = BezPath::new();
                    offset_cubic(c, d, tol, &mut r);
                    path_str(r.iter())
                }));
                match res {
                    Ok(s) => out.push(vec!["offset".into(), seg_str(seg), hx(d), hx(tol)], s),
                    Err(_) => out.skipped += 1,
                }
            }
        }
    }
}

fn random_seg(rng: &mut Rng, scale: f64) -> PathSeg {
    let mut q = || p(rng.range(-1.0, 1.0) * scale, rng.range(-1.0, 1.0) * scale);
    let (a, b, c, d) = (q(), q(), q(), q());
    match rng.below(3) {
        0 => PathSeg::Line(Line::new(a, b)),
        1 => PathSeg::Quad(QuadBez::new(a, b, c)),
        _ => PathSeg::Cubic(CubicBez::new(a, b, c, d)),
    }
}

/// Scale factor for dash patterns so that large paths don't produce
/// millions of dashes.
fn dash_scale(path: &BezPath) -> f64 {
    let mut m: f64 = 0.0;
    for el in path.iter() {
        if let Some(p) = el.end_point() {
            m = m.max(p.x.abs()).max(p.y.abs());
        }
    }
    (m / 100.0).max(1.0)
}

fn random_path(rng: &mut Rng) -> BezPath {
    let scale = rng.pick(&[1e-3, 1.0, 1.0, 50.0, 100.0, 100.0, 1e4, 1e6]);
    let mut path = BezPath::new();
    let n_sub = 1 + rng.below(3);
    for _ in 0..n_sub {
        let mut cur = p(rng.range(-1.0, 1.0) * scale, rng.range(-1.0, 1.0) * scale);
        let start = cur;
        path.move_to(cur);
        let n_seg = 1 + rng.below(6);
        for _ in 0..n_seg {
            let q = |rng: &mut Rng| -> Point {
                match rng.below(10) {
                    // Repeat the current point (degenerate segments).
                    0 => cur,
                    1 => start,
                    // Snap to a coarse grid (exact collinearities).
                    2 => p(
                        (rng.range(-4.0, 4.0)).round() * scale * 0.25,
                        (rng.range(-4.0, 4.0)).round() * scale * 0.25,
                    ),
                    _ => p(rng.range(-1.0, 1.0) * scale, rng.range(-1.0, 1.0) * scale),
                }
            };
            match rng.below(4) {
                0 => {
                    let a = q(rng);
                    path.line_to(a);
                    cur = a;
                }
                1 => {
                    let (a, b) = (q(rng), q(rng));
                    path.quad_to(a, b);
                    cur = b;
                }
                2 => {
                    let (a, b, c) = (q(rng), q(rng), q(rng));
                    path.curve_to(a, b, c);
                    cur = c;
                }
                _ => {
                    // Collinear cubic (possibly with cusps).
                    let dir = Vec2::new(rng.range(-1.0, 1.0), rng.range(-1.0, 1.0)) * scale;
                    let t = [rng.range(-1.0, 2.0), rng.range(-1.0, 2.0), rng.range(-0.5, 1.5)];
                    let a = cur + dir * t[0];
                    let b = cur + dir * t[1];
                    let c = cur + dir * t[2];
                    path.curve_to(a, b, c);
                    cur = c;
                }
            }
        }
        if rng.below(3) == 0 {
            path.close_path();
        }
    }
    path
}

fn hand_paths() -> Vec<BezPath> {
    let mut v = Vec::new();
    let mk = |els: Vec<PathEl>| BezPath::from_vec(els);
    use PathEl::*;
    // Simple line.
    v.push(mk(vec![MoveTo(p(0.0, 0.0)), LineTo(p(100.0, 0.0))]));
    // Polyline with sharp and shallow turns.
    v.push(mk(vec![
        MoveTo(p(10.0, 10.0)),
        LineTo(p(100.0, 10.0)),
        LineTo(p(100.0, 100.0)),
        LineTo(p(10.0, 90.0)),
        LineTo(p(90.0, 85.0)),
        LineTo(p(91.0, 84.9)),
    ]));
    // Closed square.
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        LineTo(p(50.0, 0.0)),
        LineTo(p(50.0, 50.0)),
        LineTo(p(0.0, 50.0)),
        ClosePath,
    ]));
    // Closed triangle ending at start (no implicit closing line).
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        LineTo(p(40.0, 10.0)),
        LineTo(p(5.0, 30.0)),
        LineTo(p(0.0, 0.0)),
        ClosePath,
    ]));
    // Kurbo's dash_miter_join test.
    v.push(mk(vec![
        MoveTo(p(70.0, 80.0)),
        LineTo(p(0.0, 80.0)),
        LineTo(p(0.0, 77.0)),
    ]));
    // Quads.
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        QuadTo(p(50.0, 100.0), p(100.0, 0.0)),
        QuadTo(p(150.0, -100.0), p(200.0, 0.0)),
    ]));
    // Degenerate quad (control point at end).
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        QuadTo(p(0.0, 0.0), p(30.0, 40.0)),
        QuadTo(p(30.0, 40.0), p(30.0, 40.0)),
        QuadTo(p(60.0, 80.0), p(30.0, 40.0)),
    ]));
    // Smooth cubic, S curve, loop, cusp.
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        CurveTo(p(30.0, 60.0), p(70.0, 60.0), p(100.0, 0.0)),
    ]));
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        CurveTo(p(100.0, 100.0), p(0.0, 100.0), p(100.0, 0.0)),
    ]));
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        CurveTo(p(150.0, 100.0), p(-50.0, 100.0), p(100.0, 0.0)),
    ]));
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        CurveTo(p(100.0, 100.0), p(0.0, 100.0), p(100.0, 0.0)),
        CurveTo(p(200.0, -100.0), p(100.0, -100.0), p(200.0, 0.0)),
        ClosePath,
    ]));
    // Kurbo's broken_strokes cubics and pathological cubics.
    let cubics: [[(f64, f64); 4]; 12] = [
        [
            (465.24423, 107.11105),
            (475.50754, 107.11105),
            (475.50754, 107.11105),
            (475.50754, 107.11105),
        ],
        [(0., -0.01), (128., 128.001), (128., -0.01), (0., 128.001)],
        [(0., 0.), (0., -10.), (0., -10.), (0., 10.)],
        [(10., 0.), (0., 0.), (20., 0.), (10., 0.)],
        [(39., -39.), (40., -40.), (40., -40.), (0., 0.)],
        [(40., 40.), (0., 0.), (200., 200.), (0., 0.)],
        [(0., 0.), (1e-2, 0.), (-1e-2, 0.), (0., 0.)],
        [
            (400.75, 100.05),
            (400.75, 100.05),
            (100.05, 300.95),
            (100.05, 300.95),
        ],
        [(0.5, 0.), (0., 0.), (20., 0.), (10., 0.)],
        [(10., 0.), (0., 0.), (10., 0.), (10., 0.)],
        [
            (602.469, 286.585),
            (641.975, 286.585),
            (562.963, 286.585),
            (562.963, 286.585),
        ],
        [
            (1096.2962962962963, 593.90243902439033),
            (1043.6213991769548, 593.90243902439033),
            (1030.4526748971193, 593.90243902439033),
            (1056.7901234567901, 593.90243902439033),
        ],
    ];
    for c in cubics {
        v.push(mk(vec![
            MoveTo(c[0].into()),
            CurveTo(c[1].into(), c[2].into(), c[3].into()),
        ]));
    }
    // Near-cusp J curve and pathological offset curve.
    v.push(mk(vec![
        MoveTo(p(-1236.3746269978635, 152.17981429574826)),
        CurveTo(
            p(-1175.18662093517, 108.04721798590596),
            p(-1152.142883879584, 105.76260301083356),
            p(-1151.842639804639, 105.73040758939104),
        ),
    ]));
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        CurveTo(p(100.0, 0.0), p(100.0, 1.0), p(99.0, 1.0)),
    ]));
    // Coincident control points.
    v.push(mk(vec![
        MoveTo(p(10.0, 10.0)),
        CurveTo(p(10.0, 10.0), p(10.0, 10.0), p(60.0, 30.0)),
        CurveTo(p(60.0, 30.0), p(90.0, 10.0), p(90.0, 10.0)),
        CurveTo(p(90.0, 10.0), p(90.0, 10.0), p(90.0, 10.0)),
    ]));
    // Zero-length segments and a lone moveto.
    v.push(mk(vec![
        MoveTo(p(5.0, 5.0)),
        MoveTo(p(10.0, 10.0)),
        LineTo(p(10.0, 10.0)),
        LineTo(p(20.0, 10.0)),
        LineTo(p(20.0, 10.0)),
        LineTo(p(20.0, 30.0)),
        MoveTo(p(50.0, 50.0)),
    ]));
    // Single-point closed subpath, empty subpaths.
    v.push(mk(vec![
        MoveTo(p(3.0, 4.0)),
        ClosePath,
        MoveTo(p(7.0, 7.0)),
        LineTo(p(7.0, 7.0)),
        ClosePath,
    ]));
    // 180-degree U-turns.
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        LineTo(p(50.0, 0.0)),
        LineTo(p(0.0, 0.0)),
        LineTo(p(50.0, 1e-9)),
    ]));
    // Multiple subpaths, mixed closed/open.
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        LineTo(p(2.0, 0.0)),
        LineTo(p(2.0, 2.0)),
        LineTo(p(0.0, 2.0)),
        ClosePath,
        MoveTo(p(10.0, 10.0)),
        CurveTo(p(15.0, 5.0), p(20.0, 15.0), p(25.0, 10.0)),
        QuadTo(p(30.0, 0.0), p(35.0, 10.0)),
        MoveTo(p(40.0, 40.0)),
        QuadTo(p(60.0, 20.0), p(80.0, 40.0)),
        CurveTo(p(80.0, 60.0), p(40.0, 60.0), p(40.0, 40.0)),
        ClosePath,
    ]));
    // Closed path whose first segment is a curve; ClosePath without
    // returning line.
    v.push(mk(vec![
        MoveTo(p(0.0, 0.0)),
        CurveTo(p(30.0, -20.0), p(60.0, 20.0), p(90.0, 0.0)),
        LineTo(p(90.0, 40.0)),
        QuadTo(p(45.0, 80.0), p(0.0, 40.0)),
        ClosePath,
    ]));
    // Path starting without a moveto.
    v.push(mk(vec![LineTo(p(10.0, 0.0)), LineTo(p(10.0, 10.0))]));
    // Very small and very large coordinates.
    v.push(mk(vec![
        MoveTo(p(1e-6, 2e-6)),
        CurveTo(p(3e-6, 5e-6), p(4e-6, -1e-6), p(7e-6, 2e-6)),
        LineTo(p(7e-6, 9e-6)),
    ]));
    v.push(mk(vec![
        MoveTo(p(1e7, -3e7)),
        CurveTo(p(5e7, 2e7), p(-2e7, 4e7), p(3e7, 3e7)),
        LineTo(p(-1e7, 1e7)),
        ClosePath,
    ]));
    // Circle approximation (as in typst shapes).
    let k = 0.5522847498;
    v.push(mk(vec![
        MoveTo(p(50.0, 0.0)),
        CurveTo(p(50.0, 50.0 * k), p(50.0 * k, 50.0), p(0.0, 50.0)),
        CurveTo(p(-50.0 * k, 50.0), p(-50.0, 50.0 * k), p(-50.0, 0.0)),
        CurveTo(p(-50.0, -50.0 * k), p(-50.0 * k, -50.0), p(0.0, -50.0)),
        CurveTo(p(50.0 * k, -50.0), p(50.0, -50.0 * k), p(50.0, 0.0)),
        ClosePath,
    ]));
    // Many tiny line segments (flattened arc).
    let mut els = vec![MoveTo(p(100.0, 0.0))];
    for i in 1..=40 {
        let a = i as f64 * 0.1;
        els.push(LineTo(p(100.0 * a.cos(), 100.0 * a.sin())));
    }
    v.push(mk(els));
    v
}

fn main() {
    unsafe {
        FULL = std::env::args().any(|a| a == "--full");
    }
    let mut out = Out {
        lines: Vec::new(),
        skipped: 0,
    };
    let mut rng = Rng(0x9E3779B97F4A7C15);

    // --- solve_cubic ---
    let cubic_coeffs: Vec<[f64; 4]> = vec![
        [-6.0, 11.0, -6.0, 1.0],
        [1.0, 0.0, 0.0, 1.0],
        [0.0, 0.0, 0.0, 1.0],
        [1.0, -3.0, 3.0, -1.0],
        [2.0, 3.0, 1.0, 0.0],
        [1.0, 2.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
        [-1.0, 0.0, 1.0, 1e-20],
        [1e10, -3.0, 0.5, 2.0],
    ];
    for c in cubic_coeffs {
        out.push(
            vec![
                "solve_cubic".into(),
                format!("{} {} {} {}", hx(c[0]), hx(c[1]), hx(c[2]), hx(c[3])),
            ],
            nums(&solve_cubic(c[0], c[1], c[2], c[3])),
        );
    }
    for _ in 0..150 {
        let s = rng.pick(&[1e-3, 1.0, 1e3]);
        let c: Vec<f64> = (0..4).map(|_| rng.range(-1.0, 1.0) * s).collect();
        out.push(
            vec![
                "solve_cubic".into(),
                format!("{} {} {} {}", hx(c[0]), hx(c[1]), hx(c[2]), hx(c[3])),
            ],
            nums(&solve_cubic(c[0], c[1], c[2], c[3])),
        );
    }

    // --- Arc::append_iter ---
    for _ in 0..60 {
        let center = p(rng.range(-100.0, 100.0), rng.range(-100.0, 100.0));
        let radii = Vec2::new(rng.range(0.01, 50.0), rng.range(0.01, 50.0));
        let start = rng.range(-7.0, 7.0);
        let sweep = rng.range(-7.0, 7.0);
        let xrot = if rng.below(2) == 0 { 0.0 } else { rng.range(-4.0, 4.0) };
        let tol = rng.pick(&[1e-3, 0.1, 0.25, 1.0]);
        let arc = Arc::new(center, radii, start, sweep, xrot);
        out.push(
            vec![
                "arc".into(),
                format!(
                    "{} {} {} {} {} {} {}",
                    hx(center.x),
                    hx(center.y),
                    hx(radii.x),
                    hx(radii.y),
                    hx(start),
                    hx(sweep),
                    hx(xrot)
                ),
                hx(tol),
            ],
            path_str(arc.append_iter(tol)),
        );
    }

    // --- Segments: arclen, inv_arclen, subsegment, nearest, offset ---
    let fixed_segs = vec![
        PathSeg::Line(Line::new(p(0.0, 0.0), p(3.0, 4.0))),
        PathSeg::Line(Line::new(p(1.0, 1.0), p(1.0, 1.0))),
        PathSeg::Quad(QuadBez::new(p(0.0, 0.0), p(50.0, 100.0), p(100.0, 0.0))),
        PathSeg::Quad(QuadBez::new(p(0.0, 0.0), p(1.0, 1e-7), p(2.0, 0.0))),
        PathSeg::Quad(QuadBez::new(p(0.0, 0.0), p(100.0, 0.0), p(0.0, 0.0))),
        PathSeg::Quad(QuadBez::new(p(0.0, 0.0), p(0.0, 0.0), p(0.0, 0.0))),
        PathSeg::Cubic(CubicBez::new(
            p(0.0, 0.0),
            p(30.0, 60.0),
            p(70.0, 60.0),
            p(100.0, 0.0),
        )),
        PathSeg::Cubic(CubicBez::new(
            p(0.0, 0.0),
            p(100.0, 100.0),
            p(0.0, 100.0),
            p(100.0, 0.0),
        )),
        PathSeg::Cubic(CubicBez::new(
            p(0.0, 0.0),
            p(150.0, 100.0),
            p(-50.0, 100.0),
            p(100.0, 0.0),
        )),
        PathSeg::Cubic(CubicBez::new(
            p(0.0, -0.01),
            p(128.0, 128.001),
            p(128.0, -0.01),
            p(0.0, 128.001),
        )),
        PathSeg::Cubic(CubicBez::new(
            p(-1236.3746269978635, 152.17981429574826),
            p(-1175.18662093517, 108.04721798590596),
            p(-1152.142883879584, 105.76260301083356),
            p(-1151.842639804639, 105.73040758939104),
        )),
        PathSeg::Cubic(CubicBez::new(p(0.0, 0.0), p(0.0, 0.0), p(0.0, 0.0), p(0.0, 0.0))),
        PathSeg::Cubic(CubicBez::new(
            p(0.0, 0.0),
            p(100.0, 0.0),
            p(100.0, 1.0),
            p(99.0, 1.0),
        )),
    ];
    for seg in fixed_segs {
        seg_case(&mut out, seg, &[1e-6, 1e-3, 0.1]);
    }
    for _ in 0..40 {
        let scale = rng.pick(&[1e-2, 1.0, 100.0, 1e4]);
        let seg = random_seg(&mut rng, scale);
        seg_case(&mut out, seg, &[1e-6]);
    }

    // --- dash ---
    let dash_patterns: Vec<Vec<f64>> = vec![
        vec![5.0],
        vec![5.0, 3.0],
        vec![1.0, 2.0, 3.0],
        vec![0.0, 4.0],
        vec![4.0, 0.0],
        vec![3.0, 0.0, 2.0],
        vec![0.5, 0.5],
        vec![1.0, 5.0, 2.0, 5.0],
        vec![20.0, 10.0, 3.0],
        vec![73.0, 12.0],
        vec![0.0, 0.0],
    ];
    let hand = hand_paths();
    for path in &hand {
        for (i, d) in dash_patterns.iter().enumerate() {
            let offset = [0.0, 2.5, -7.0, 100.0][i % 4];
            let k = dash_scale(path);
            let d: Vec<f64> = d.iter().map(|x| x * k).collect();
            case_dash(&mut out, path, offset * k, &d);
        }
    }

    // --- stroke: hand-written paths crossed with styles ---
    let mut ctx = StrokeCtx::default();
    let joins = [Join::Bevel, Join::Miter, Join::Round];
    let caps = [Cap::Butt, Cap::Square, Cap::Round];
    for (pi, path) in hand.iter().enumerate() {
        for (ji, &join) in joins.iter().enumerate() {
            for (ci, &cap) in caps.iter().enumerate() {
                let k = pi * 9 + ji * 3 + ci;
                let width = [1.0, 0.5, 3.0, 10.0, 20.0, 0.01, 50.0][k % 7];
                let tol = [0.25, 0.1, 0.01, 1.0][k % 4];
                let miter = [4.0, 1.0, 10.0, 1.5, 100.0][k % 5];
                let end_cap = caps[(ci + pi) % 3];
                let style = Stroke::new(width)
                    .with_join(join)
                    .with_miter_limit(miter)
                    .with_start_cap(cap)
                    .with_end_cap(end_cap);
                case_stroke(&mut out, &mut ctx, path, &style, false, tol);
            }
        }
        // A couple of dashed strokes per hand path.
        for (di, d) in dash_patterns.iter().enumerate().take(10) {
            if (di + pi) % 3 != 0 {
                continue;
            }
            let style = Stroke::new([2.0, 20.0, 0.5][di % 3])
                .with_join(joins[di % 3])
                .with_caps(caps[(di + 1) % 3])
                .with_dashes(
                    [0.0, 1.5, -3.0, 33.0][di % 4] * dash_scale(path),
                    d.iter().map(|x| x * dash_scale(path)),
                );
            case_stroke(&mut out, &mut ctx, path, &style, false, 0.25);
            case_stroke(&mut out, &mut ctx, path, &style, true, 0.25);
        }
        let style = Stroke::new(4.0);
        case_stroke_fresh(&mut out, path, &style, 0.25);
    }

    // --- stroke: random paths and styles ---
    for _ in 0..500 {
        let path = random_path(&mut rng);
        let width = rng.pick(&[0.01, 0.5, 1.0, 1.0, 3.0, 10.0, 50.0, 1000.0]);
        let mut style = Stroke::new(width)
            .with_join(rng.pick(&joins))
            .with_miter_limit(rng.pick(&[1.0, 1.5, 4.0, 10.0, 100.0]))
            .with_start_cap(rng.pick(&caps))
            .with_end_cap(rng.pick(&caps));
        if rng.below(4) == 0 {
            let d = rng.pick(&[0usize, 1, 2, 5, 6, 7, 8]);
            let s = rng.pick(&[0.1, 1.0, 10.0]) * dash_scale(&path);
            let pattern: Vec<f64> = dash_patterns[d].iter().map(|x| x * s * 5.0).collect();
            let off = rng.range(-20.0, 20.0) * dash_scale(&path);
            style = style.with_dashes(off, pattern);
        }
        let tol = rng.pick(&[0.25, 0.25, 0.1, 0.01, 1.0, 0.001]);
        let stable = !style.dash_pattern.is_empty() && rng.below(3) == 0;
        case_stroke(&mut out, &mut ctx, &path, &style, stable, tol);
        if rng.below(10) == 0 {
            let k = dash_scale(&path);
            case_dash(&mut out, &path, rng.range(0.0, 10.0) * k, &[3.0 * k, 1.5 * k]);
        }
    }

    for l in &out.lines {
        println!("{l}");
    }
    eprintln!("{} cases, {} skipped (panicked)", out.lines.len(), out.skipped);
}
