//! Generates `library/calc_cases_wbtest.mbt`: differential tests of the
//! float functions of `calc` (`library/calc.mbt`) against upstream's own
//! functions (`typst::foundations::calc`). `gen_libm_tests` checks the ports
//! of the `libm` functions they are computed with; this checks what `calc`
//! does around them: which function a call reaches (`pow` of `e`, of 2, with
//! an integer exponent; the bases of `log`), the sign handling of `root`,
//! angles in degrees and radians, `round` with digits beyond `exp10`'s exact
//! table, and the errors.
//!
//! A case is `function \t arguments... \t expected`. An argument is
//! `i<decimal>` (an integer), the 16 hex digits of `f64::to_bits` (a float),
//! or `rad:<bits>` / `deg:<bits>` (an angle). The expected value is
//! `i<decimal>`, the bits of a float (for an angle: of its radians; every NaN
//! is written as `nan`, LLVM does not preserve NaN signs and payloads), or
//! `!<message>` for an error.
//!
//! Usage (from `oracle/`, so that `rust-toolchain.toml` applies):
//!   cargo run --release --offline --bin gen_calc_tests \
//!     > ../library/calc_cases_wbtest.mbt && (cd .. && moon fmt)

use std::fmt::Write as _;

use typst::diag::{SourceResult, StrResult};
use typst::foundations::calc::{self, AngleLike, DecNum, Num};
use typst::layout::Angle;
use typst_syntax::{Span, Spanned};

/// The exact bits of `v`. NaNs are written as `nan`: LLVM does not preserve
/// NaN signs/payloads.
fn hx(v: f64) -> String {
    if v.is_nan() {
        return "nan".into();
    }
    format!("{:016x}", v.to_bits())
}

/// splitmix64.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e3779b97f4a7c15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
        z ^ (z >> 31)
    }

    /// Uniform in `[0, 1)`.
    fn unit(&mut self) -> f64 {
        (self.next() >> 11) as f64 / (1u64 << 53) as f64
    }

    /// Uniform in `[lo, hi)`.
    fn range(&mut self, lo: f64, hi: f64) -> f64 {
        lo + (hi - lo) * self.unit()
    }

    /// A random mantissa with a binary exponent in `[lo, hi]` and a random
    /// sign.
    fn log_uniform(&mut self, lo: i32, hi: i32) -> f64 {
        let e = lo + (self.next() % (hi - lo + 1) as u64) as i32;
        let m = 1.0 + self.unit();
        // `m * 2^e`, also for subnormal results.
        let v = if e >= -1022 {
            m * f64::from_bits(((e + 1023) as u64) << 52)
        } else {
            m * f64::from_bits(1 << 52) * f64::from_bits(((e + 1022 + 1023) as u64) << 52)
        };
        if self.next() & 1 == 0 { v } else { -v }
    }
}

/// A `calc` argument: an integer, a float, or an angle.
#[derive(Clone, Copy)]
enum Arg {
    I(i64),
    F(f64),
    Rad(f64),
    Deg(f64),
}

impl Arg {
    fn text(self) -> String {
        match self {
            Arg::I(i) => format!("i{i}"),
            Arg::F(f) => hx(f),
            Arg::Rad(f) => format!("rad:{}", hx(f)),
            Arg::Deg(f) => format!("deg:{}", hx(f)),
        }
    }

    fn num(self) -> Num {
        match self {
            Arg::I(i) => Num::Int(i),
            Arg::F(f) => Num::Float(f),
            _ => unreachable!(),
        }
    }

    fn dec_num(self) -> DecNum {
        match self {
            Arg::I(i) => DecNum::Int(i),
            Arg::F(f) => DecNum::Float(f),
            _ => unreachable!(),
        }
    }

    fn float(self) -> f64 {
        match self {
            Arg::F(f) => f,
            _ => unreachable!(),
        }
    }

    fn int(self) -> i64 {
        match self {
            Arg::I(i) => i,
            _ => unreachable!(),
        }
    }

    fn angle_like(self) -> AngleLike {
        match self {
            Arg::I(i) => AngleLike::Int(i),
            Arg::F(f) => AngleLike::Float(f),
            Arg::Rad(f) => AngleLike::Angle(Angle::rad(f)),
            Arg::Deg(f) => AngleLike::Angle(Angle::deg(f)),
        }
    }
}

fn sp<T>(v: T) -> Spanned<T> {
    Spanned::detached(v)
}

fn res_f64(r: SourceResult<f64>) -> String {
    match r {
        Ok(v) => hx(v),
        Err(errs) => format!("!{}", errs[0].message),
    }
}

fn res_angle(r: SourceResult<Angle>) -> String {
    res_f64(r.map(|a| a.to_rad()))
}

fn dec_num(v: DecNum) -> String {
    match v {
        DecNum::Int(i) => format!("i{i}"),
        DecNum::Float(f) => hx(f),
        DecNum::Decimal(_) => unreachable!(),
    }
}

/// One case, as a MoonBit string literal.
fn calc_line(out: &mut String, op: &str, args: &[Arg]) {
    let span = Span::detached();
    let a = |i: usize| args[i];
    let expected = match op {
        "exp" => res_f64(calc::exp(span, sp(a(0).num()))),
        "pow" => match calc::pow(span, a(0).dec_num(), sp(a(1).num())) {
            Ok(v) => dec_num(v),
            Err(errs) => format!("!{}", errs[0].message),
        },
        "sqrt" => res_f64(calc::sqrt(sp(a(0).num()))),
        "root" => res_f64(calc::root(a(0).float(), sp(a(1).int()))),
        "sin" => hx(calc::sin(a(0).angle_like())),
        "cos" => hx(calc::cos(a(0).angle_like())),
        "tan" => hx(calc::tan(a(0).angle_like())),
        "asin" => res_angle(calc::asin(sp(a(0).num()))),
        "acos" => res_angle(calc::acos(sp(a(0).num()))),
        "atan" => hx(calc::atan(a(0).num()).to_rad()),
        "atan2" => hx(calc::atan2(a(0).num(), a(1).num()).to_rad()),
        "sinh" => hx(calc::sinh(a(0).float())),
        "cosh" => hx(calc::cosh(a(0).float())),
        "tanh" => hx(calc::tanh(a(0).float())),
        "asinh" => hx(calc::asinh(a(0).float())),
        "acosh" => res_f64(calc::acosh(sp(a(0).float()))),
        "atanh" => res_f64(calc::atanh(sp(a(0).float()))),
        "log" => res_f64(calc::log(span, sp(a(0).num()), sp(a(1).float()))),
        "ln" => res_f64(calc::ln(span, sp(a(0).num()))),
        "erf" => hx(calc::erf(a(0).float())),
        "norm" => res_f64(calc::norm(
            sp(a(0).float()),
            args[1..].iter().map(|v| v.float()).collect(),
        )),
        "round" => {
            let r: StrResult<DecNum> = calc::round(a(0).dec_num(), a(1).int());
            match r {
                Ok(v) => dec_num(v),
                Err(msg) => format!("!{msg}"),
            }
        }
        _ => unreachable!("{op}"),
    };
    let mut line = op.to_string();
    for arg in args {
        write!(line, "\t{}", arg.text()).unwrap();
    }
    write!(line, "\t{expected}").unwrap();
    writeln!(out, "  {line:?},").unwrap();
}

/// All cases.
fn calc_lines(out: &mut String, rng: &mut Rng) {
    use Arg::*;
    let e = std::f64::consts::E;
    // A number as documents write it: an integer or a float.
    fn num(rng: &mut Rng, lo: f64, hi: f64) -> Arg {
        if rng.next() % 3 == 0 {
            Arg::I(rng.range(lo, hi) as i64)
        } else {
            Arg::F(rng.range(lo, hi))
        }
    }
    let edge = [
        0.0,
        -0.0,
        1.0,
        -1.0,
        0.5,
        2.0,
        e,
        10.0,
        1e-320,
        f64::MIN_POSITIVE,
        f64::MAX,
        f64::INFINITY,
        f64::NEG_INFINITY,
        f64::NAN,
    ];

    // The documentation's examples.
    calc_line(out, "exp", &[I(1)]);
    calc_line(out, "pow", &[I(2), I(3)]);
    calc_line(out, "sqrt", &[I(16)]);
    calc_line(out, "sqrt", &[F(2.5)]);
    calc_line(out, "root", &[F(16.0), I(4)]);
    calc_line(out, "root", &[F(27.0), I(3)]);
    for x in -8..8 {
        calc_line(out, "root", &[F((x + 10) as f64), I(3)]);
    }
    for op in ["sin", "cos", "tan"] {
        calc_line(out, op, &[F(1.5)]);
        calc_line(out, op, &[Deg(90.0)]);
    }
    calc_line(out, "atan2", &[I(1), I(1)]);
    calc_line(out, "atan2", &[I(-2), I(-3)]);
    calc_line(out, "log", &[I(100), F(10.0)]);
    calc_line(out, "ln", &[F(e)]);
    calc_line(out, "erf", &[F(0.2)]);
    calc_line(out, "norm", &[F(2.0), F(1.0), F(2.0), F(-3.0), F(0.5)]);
    calc_line(out, "norm", &[F(3.0), F(1.0), F(2.0)]);
    calc_line(out, "round", &[F(3.1415), I(2)]);

    for &x in &edge {
        calc_line(out, "exp", &[F(x)]);
        calc_line(out, "sqrt", &[F(x)]);
        calc_line(out, "ln", &[F(x)]);
        for op in ["sin", "cos", "tan"] {
            calc_line(out, op, &[F(x)]);
            calc_line(out, op, &[Rad(x)]);
            calc_line(out, op, &[Deg(x)]);
        }
        for op in ["asin", "acos", "atan"] {
            calc_line(out, op, &[F(x)]);
        }
        for op in ["sinh", "cosh", "tanh", "asinh", "acosh", "atanh", "erf"] {
            calc_line(out, op, &[F(x)]);
        }
        for &y in &edge {
            calc_line(out, "pow", &[F(x), F(y)]);
            calc_line(out, "log", &[F(x), F(y)]);
            calc_line(out, "atan2", &[F(x), F(y)]);
            calc_line(out, "norm", &[F(x), F(y), F(1.0)]);
        }
        for n in [-3, -2, -1, 0, 1, 2, 3, 4, 5] {
            calc_line(out, "root", &[F(x), I(n)]);
            calc_line(out, "pow", &[F(x), I(n)]);
            calc_line(out, "round", &[F(x), I(n)]);
        }
    }
    for i in [0, 1, -1, 2, 10, 2147483647, 2147483648, -2147483648, -2147483649, i64::MAX] {
        calc_line(out, "exp", &[I(i)]);
        calc_line(out, "pow", &[F(1.5), I(i)]);
        calc_line(out, "pow", &[I(3), I(i)]);
        calc_line(out, "pow", &[I(0), I(i)]);
        calc_line(out, "root", &[F(2.0), I(i)]);
        calc_line(out, "root", &[F(-2.0), I(i)]);
    }

    for _ in 0..60 {
        calc_line(out, "exp", &[num(rng, -20.0, 20.0)]);
        calc_line(out, "exp", &[F(rng.range(-750.0, 750.0))]);
        // Bases with a special case (e, 2), integer and float exponents.
        calc_line(out, "pow", &[F(e), num(rng, -30.0, 30.0)]);
        calc_line(out, "pow", &[F(2.0), num(rng, -30.0, 30.0)]);
        calc_line(out, "pow", &[I(2), F(rng.range(-30.0, 30.0))]);
        calc_line(out, "pow", &[F(2.0), F(rng.range(-1100.0, 1100.0))]);
        calc_line(out, "pow", &[F(rng.range(0.0, 20.0)), F(rng.range(-9.0, 9.0))]);
        calc_line(out, "pow", &[F(rng.range(-20.0, 20.0)), I(rng.range(-40.0, 40.0) as i64)]);
        calc_line(out, "pow", &[I(rng.range(-20.0, 20.0) as i64), F(rng.range(-9.0, 9.0))]);
        calc_line(out, "pow", &[I(rng.range(-20.0, 20.0) as i64), I(rng.range(-9.0, 30.0) as i64)]);
        calc_line(out, "sqrt", &[num(rng, -10.0, 1000.0)]);
        let n = rng.range(-12.0, 13.0) as i64;
        calc_line(out, "root", &[F(rng.range(-1000.0, 1000.0)), I(n)]);
        calc_line(out, "root", &[F(rng.range(-1000.0, 1000.0).trunc()), I(n)]);
        for op in ["sin", "cos", "tan"] {
            calc_line(out, op, &[num(rng, -100.0, 100.0)]);
            calc_line(out, op, &[F(rng.log_uniform(-30, 300))]);
            calc_line(out, op, &[Rad(rng.range(-10.0, 10.0))]);
            calc_line(out, op, &[Deg(rng.range(-720.0, 720.0))]);
            calc_line(out, op, &[Deg((rng.range(-48.0, 48.0) as i64 * 15) as f64)]);
        }
        for op in ["asin", "acos"] {
            calc_line(out, op, &[num(rng, -1.2, 1.2)]);
            calc_line(out, op, &[F(rng.range(-1.0, 1.0))]);
        }
        calc_line(out, "atan", &[num(rng, -50.0, 50.0)]);
        calc_line(out, "atan", &[F(rng.log_uniform(-70, 70))]);
        calc_line(out, "atan2", &[num(rng, -50.0, 50.0), num(rng, -50.0, 50.0)]);
        for op in ["sinh", "cosh", "tanh", "asinh", "erf"] {
            calc_line(out, op, &[F(rng.range(-4.0, 4.0))]);
            calc_line(out, op, &[F(rng.range(-720.0, 720.0))]);
        }
        calc_line(out, "acosh", &[F(rng.range(0.5, 4.0))]);
        calc_line(out, "acosh", &[F(rng.log_uniform(0, 300).abs())]);
        calc_line(out, "atanh", &[F(rng.range(-1.1, 1.1))]);
        for base in [e, 2.0, 10.0, 3.0, 0.5, rng.range(0.1, 40.0)] {
            calc_line(out, "log", &[num(rng, -2.0, 1000.0), F(base)]);
        }
        calc_line(out, "log", &[F(rng.log_uniform(-1074, 1023).abs()), F(10.0)]);
        calc_line(out, "ln", &[num(rng, -2.0, 1000.0)]);
        calc_line(out, "ln", &[F(rng.log_uniform(-1074, 1023).abs())]);
        let p = match rng.next() % 4 {
            0 => 1.0,
            1 => 2.0,
            2 => f64::INFINITY,
            _ => rng.range(-0.5, 9.0),
        };
        let values: Vec<Arg> = std::iter::once(F(p))
            .chain((0..rng.next() % 6).map(|_| F(rng.range(-9.0, 9.0))))
            .collect();
        calc_line(out, "norm", &values);
        // Negative digits go through `exp10` beyond its exact table.
        let digits = rng.range(-320.0, 20.0) as i64;
        calc_line(out, "round", &[F(rng.range(-9.0, 9.0)), I(digits)]);
        calc_line(out, "round", &[F(rng.log_uniform(-20, 1023)), I(digits)]);
        calc_line(out, "round", &[F(rng.range(-9.0, 9.0) * 10f64.powi((-digits) as i32)), I(digits)]);
    }
}

fn main() {
    let mut out = String::new();
    out.push_str(
        "// Generated by oracle/src/bin/gen_calc_tests.rs from upstream's `calc` \
         functions;\n// see there for the format and the regeneration command. \
         Do not edit.\n\n",
    );
    out.push_str("///|\nlet calc_oracle_cases : ReadOnlyArray[String] = [\n");
    let mut rng = Rng(0x6361_6c63_0000_0000);
    calc_lines(&mut out, &mut rng);
    out.push_str("]\n");
    print!("{out}");
}
