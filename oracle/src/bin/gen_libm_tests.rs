//! Generates `library/libm_cases_wbtest.mbt`: differential tests for the
//! MoonBit ports of the `libm` crate's `f64` functions that upstream Typst
//! calls (`library/libm*.mbt`: `calc.exp`/`pow`/`root`/`log`/..., the
//! hyperbolic functions, `Angle::sin`/`cos`/`tan`/`asin`/`acos`/`atan`/
//! `atan2`, `calc.erf` and `round_with_precision`'s `exp10`), with expected
//! results produced by the real crate.
//!
//! Three kinds of cases, all compared bit for bit (every NaN counts as the
//! same value: LLVM does not preserve NaN signs and payloads):
//!
//! * explicit: every function at a list of special values (zeros,
//!   infinities, NaN, subnormals, limits, small integers); binary functions
//!   at all pairs of a shorter list. Inputs and expected results are
//!   recorded.
//! * thresholds: every unary function at the values on both sides of every
//!   high word the algorithms branch on, recorded as an FNV-1a-64 hash of the
//!   results.
//! * sweeps: pseudo-random arguments drawn from binary-exponent ranges. The
//!   arguments are not stored: both sides regenerate them with the same
//!   SplitMix64 generator (`sample` here, `libm_test_sample` in
//!   `library/libm_wbtest.mbt`); only the hash of the results is recorded.
//! * grids: regular grids (`i / 16` for the unary functions, quarter steps
//!   and `x^(1/n)` for `pow`), also recorded as a hash.
//!
//! Usage (from `oracle/`, so that `rust-toolchain.toml` applies):
//!   cargo run --release --offline --bin gen_libm_tests \
//!     > ../library/libm_cases_wbtest.mbt && (cd .. && moon fmt)
//! Debugging: `... --bin gen_libm_tests -- --tsv` writes every case in full
//! as `name \t x [\t y] \t result` (16 hex digits of `f64::to_bits`), so a
//! hash mismatch can be located.
//!
//! The oracle locks libm 0.2.16, upstream Typst's own lockfile 0.2.11; the
//! output of this generator is identical for both.
//!
//! The file only depends on `libm`, so it can also be compiled alone (a
//! scratch cargo project with `libm = "=0.2.16"` and this file as
//! `src/main.rs`).

use std::fmt::Write as _;

type Unary = fn(f64) -> f64;
type Binary = fn(f64, f64) -> f64;

fn scalbn(x: f64, n: f64) -> f64 {
    libm::scalbn(x, n as i32)
}

const UNARY: &[(&str, Unary)] = &[
    ("exp", libm::exp),
    ("exp2", libm::exp2),
    ("exp10", libm::exp10),
    ("expm1", libm::expm1),
    ("log", libm::log),
    ("log2", libm::log2),
    ("log10", libm::log10),
    ("log1p", libm::log1p),
    ("sin", libm::sin),
    ("cos", libm::cos),
    ("tan", libm::tan),
    ("sinh", libm::sinh),
    ("cosh", libm::cosh),
    ("tanh", libm::tanh),
    ("asinh", libm::asinh),
    ("acosh", libm::acosh),
    ("atanh", libm::atanh),
    ("asin", libm::asin),
    ("acos", libm::acos),
    ("atan", libm::atan),
    ("erf", libm::erf),
];

const BINARY: &[(&str, Binary)] = &[("pow", libm::pow), ("atan2", libm::atan2)];

/// The high words the algorithms compare against.
const THRESHOLDS: &[u32] = &[
    // exp, exp2, expm1, expo2
    0x4086232b, 0x3fd62e42, 0x3ff0a2b2, 0x3e300000, 0x408ff000, 0x40900000, 0x3c900000, 0x4043687a,
    0x40862e42, 0x40340000,
    // log, log1p
    0x00100000, 0x3ff00000, 0x3fe6a09e, 0x3ff6a09e, 0x3fda827a, 0x3fd2bec4, 0x3ca00000,
    // sinh, cosh, tanh, asinh, acosh, atanh
    0x3e500000, 0x3fe62e42, 0x3fe193ea, 0x3fd058ae, 0x41900000, 0x40000000, 0x3fe00000, 0x3df00000,
    // sin, cos, tan, rem_pio2
    0x3fe921fb, 0x3e400000, 0x3e46a09e, 0x3fe59428, 0x400f6a7a, 0x4002d97c, 0x401c463b, 0x4015fdbc,
    0x4012d97c, 0x401921fb, 0x413921fb, 0x3ff921fb, 0x400921fb,
    // asin, acos, atan
    0x3fef3333, 0x3c600000, 0x44100000, 0x3fdc0000, 0x3ff30000, 0x3fe60000, 0x40038000,
    // erf
    0x3feb0000, 0x3ff40000, 0x40180000, 0x4006db6d, 0x403c0000, 0x3fd00000,
    // pow
    0x43400000, 0x41e00000, 0x43f00000, 0x3fefffff, 0x4090cc00,
];

fn unary_inputs() -> Vec<f64> {
    let mut v: Vec<f64> = vec![
        0.0,
        -0.0,
        f64::INFINITY,
        f64::NEG_INFINITY,
        f64::NAN,
        f64::MIN_POSITIVE,
        -f64::MIN_POSITIVE,
        f64::MAX,
        f64::MIN,
        f64::EPSILON,
        1.0 + f64::EPSILON,
        1.0 - f64::EPSILON / 2.0,
        f64::from_bits(1),
        f64::from_bits(0x8000_0000_0000_0001),
        f64::from_bits(0x000f_ffff_ffff_ffff),
        f64::from_bits(0x0008_0000_0000_0000),
        std::f64::consts::E,
        std::f64::consts::PI,
        std::f64::consts::FRAC_PI_2,
        std::f64::consts::FRAC_PI_4,
        std::f64::consts::LN_2,
        std::f64::consts::LN_10,
        std::f64::consts::SQRT_2,
        -std::f64::consts::E,
        -std::f64::consts::PI,
        0.1,
        0.2,
        0.25,
        0.3,
        0.5,
        0.75,
        0.9,
        0.99,
        1.1,
        1.5,
        2.5,
        -0.1,
        -0.2,
        -0.5,
        -0.75,
        -1.5,
        -2.5,
        1e-300,
        1e-100,
        1e-20,
        1e-10,
        1e-5,
        1e5,
        1e10,
        1e20,
        1e22,
        1e100,
        1e300,
        -1e-300,
        -1e-10,
        -1e10,
        -1e300,
        // Overflow and underflow limits of exp, exp2 and expm1.
        709.782712893383973096,
        -708.39641853226410622,
        -745.13321910194110842,
        1024.0,
        1023.0,
        -1022.0,
        -1023.0,
        -1074.0,
        -1075.0,
        307.0,
        308.0,
        309.0,
        -323.0,
        -324.0,
        15.0,
        16.0,
        -15.0,
        -16.0,
        15.5,
        -15.5,
        16.5,
    ];
    for i in -20..=20 {
        v.push(i as f64);
    }
    for i in [30, 45, 60, 90, 100, 180, 270, 360, 1000, 4096, 65536, 1 << 20, 1 << 30] {
        v.push(i as f64);
        v.push(-(i as f64));
    }
    // Both sides of the limits above.
    for i in 0..v.len() {
        let x = v[i];
        if x.is_finite() && x.abs() > 100.0 && x.abs() < 2000.0 {
            v.push(f64::from_bits(x.to_bits() + 1));
            v.push(f64::from_bits(x.to_bits() - 1));
        }
    }
    dedup(v)
}

/// The values around the `THRESHOLDS` (`libm_test_threshold_inputs`).
fn threshold_inputs() -> Vec<f64> {
    let mut v = vec![];
    for &hw in THRESHOLDS {
        let b = (hw as u64) << 32;
        for bits in [b, b - 1, b | 0xffff_ffff, b + (1 << 32), b + 1] {
            v.push(f64::from_bits(bits));
            v.push(f64::from_bits(bits | (1 << 63)));
        }
    }
    v
}

fn binary_inputs() -> Vec<f64> {
    dedup(vec![
        0.0,
        -0.0,
        1.0,
        -1.0,
        0.5,
        -0.5,
        2.0,
        -2.0,
        3.0,
        -3.0,
        7.0,
        -7.0,
        10.0,
        0.25,
        1.5,
        -1.5,
        1.0 / 3.0,
        -1.0 / 3.0,
        2.0 / 3.0,
        std::f64::consts::E,
        1e5,
        1.0 + f64::EPSILON,
        1.0 - f64::EPSILON / 2.0,
        0.9999,
        -0.9999,
        1024.0,
        -1074.0,
        -1075.0,
        2147483648.0,
        2147483649.0,
        -2147483649.0,
        9007199254740992.0,
        9007199254740994.0,
        -9007199254740991.0,
        18446744073709551616.0,
        1e300,
        1e-300,
        f64::MIN_POSITIVE,
        f64::from_bits(1),
        f64::from_bits(0x8000_0000_0000_0001),
        f64::MAX,
        f64::MIN,
        f64::INFINITY,
        f64::NEG_INFINITY,
        f64::NAN,
    ])
}

fn dedup(v: Vec<f64>) -> Vec<f64> {
    let mut seen = std::collections::HashSet::new();
    v.into_iter().filter(|x| seen.insert(canon(*x))).collect()
}

/// A sweep: `count` samples of `(lo, hi, signed)` biased-exponent ranges.
struct Sweep {
    name: &'static str,
    x: (u64, u64, bool),
    y: Option<(u64, u64, bool)>,
}

const fn un(name: &'static str, lo: u64, hi: u64, signed: bool) -> Sweep {
    Sweep { name, x: (lo, hi, signed), y: None }
}

const fn bin(name: &'static str, x: (u64, u64, bool), y: (u64, u64, bool)) -> Sweep {
    Sweep { name, x, y: Some(y) }
}

const ALL: (u64, u64, bool) = (0, 2047, true);

const SWEEPS: &[Sweep] = &[
    un("exp", 993, 1033, true),
    un("exp", 0, 2047, true),
    un("exp2", 967, 1034, true),
    un("exp2", 0, 2047, true),
    un("exp10", 1003, 1032, true),
    un("exp10", 0, 2047, true),
    un("expm1", 967, 1033, true),
    un("expm1", 0, 2047, true),
    un("log", 0, 2047, false),
    un("log", 1022, 1023, false),
    un("log", 0, 2047, true),
    un("log2", 0, 2047, false),
    un("log2", 1022, 1023, false),
    un("log2", 0, 2047, true),
    un("log10", 0, 2047, false),
    un("log10", 1022, 1023, false),
    un("log10", 0, 2047, true),
    un("log1p", 968, 1033, true),
    un("log1p", 0, 2047, true),
    un("sin", 995, 1025, true),
    un("sin", 1025, 1044, true),
    un("sin", 0, 2047, true),
    un("cos", 995, 1025, true),
    un("cos", 1025, 1044, true),
    un("cos", 0, 2047, true),
    un("tan", 995, 1025, true),
    un("tan", 1025, 1044, true),
    un("tan", 0, 2047, true),
    un("sinh", 995, 1033, true),
    un("sinh", 0, 2047, true),
    un("cosh", 995, 1033, true),
    un("cosh", 0, 2047, true),
    un("tanh", 995, 1028, true),
    un("tanh", 0, 2047, true),
    un("asinh", 995, 1051, true),
    un("asinh", 0, 2047, true),
    un("acosh", 1023, 1051, false),
    un("acosh", 0, 2047, true),
    un("atanh", 989, 1022, true),
    un("atanh", 0, 2047, true),
    un("asin", 995, 1022, true),
    un("asin", 0, 2047, true),
    un("acos", 995, 1022, true),
    un("acos", 0, 2047, true),
    un("atan", 994, 1090, true),
    un("atan", 0, 2047, true),
    un("erf", 993, 1026, true),
    un("erf", 0, 2047, true),
    bin("pow", (1019, 1027, false), (1017, 1029, true)),
    bin("pow", (1010, 1040, false), (1015, 1033, true)),
    bin("pow", ALL, (1020, 1030, true)),
    bin("pow", (1022, 1023, false), (1043, 1088, true)),
    bin("pow", (1022, 1023, true), (1023, 1076, true)),
    bin("pow", ALL, ALL),
    bin("atan2", (953, 1093, true), (953, 1093, true)),
    bin("atan2", ALL, ALL),
    bin("scalbn", ALL, (1021, 1035, true)),
];

const SWEEP_COUNT: usize = 20000;

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
}

/// A double with a uniformly distributed biased exponent in `lo..=hi`; the
/// low mantissa bits are cleared for some samples (integers, powers of two,
/// zero low words).
fn sample(rng: &mut Rng, (lo, hi, signed): (u64, u64, bool)) -> f64 {
    let e = lo + (rng.next() >> 11) % (hi - lo + 1);
    let mut mant = rng.next() & 0x000f_ffff_ffff_ffff;
    let t = rng.next();
    match t & 7 {
        0 => mant &= !0xffff_ffff,
        1 => mant &= !((1 << 44) - 1),
        2 => mant = 0,
        _ => {}
    }
    let sign = if signed { t >> 63 } else { 0 };
    f64::from_bits((sign << 63) | (e << 52) | mant)
}

fn canon(r: f64) -> u64 {
    if r.is_nan() { 0x7ff8_0000_0000_0000 } else { r.to_bits() }
}

struct Hash(u64);

impl Hash {
    fn new() -> Self {
        Hash(0xcbf2_9ce4_8422_2325)
    }

    fn add(&mut self, r: f64) {
        self.0 = (self.0 ^ canon(r)).wrapping_mul(0x0000_0100_0000_01b3);
    }
}

fn unary(name: &str) -> Unary {
    UNARY.iter().find(|(n, _)| *n == name).unwrap().1
}

fn binary(name: &str) -> Binary {
    if name == "scalbn" {
        return scalbn;
    }
    BINARY.iter().find(|(n, _)| *n == name).unwrap().1
}

/// The binary grids: `(name, function, arguments)`.
fn binary_grids() -> Vec<(&'static str, Binary, Vec<(f64, f64)>)> {
    let mut quarters = vec![];
    for i in -80..=80 {
        for j in -160..=160 {
            quarters.push((i as f64 / 4.0, j as f64 / 4.0));
        }
    }
    // `calc.root`: `libm::pow(radicand, 1.0 / index as f64)`.
    let mut roots = vec![];
    for i in 0..=2000 {
        for n in 1..=24 {
            roots.push((i as f64, 1.0 / n as f64));
            roots.push((i as f64 / 8.0, 1.0 / -n as f64));
        }
    }
    vec![
        ("pow", libm::pow as Binary, quarters.clone()),
        ("pow_root", libm::pow as Binary, roots),
        ("atan2", libm::atan2 as Binary, quarters),
    ]
}

const GRID: i32 = 80000;

fn words(out: &mut String, values: &[u64]) {
    for chunk in values.chunks(4) {
        out.push_str("   ");
        for v in chunk {
            write!(out, " 0x{v:016x}UL,").unwrap();
        }
        out.push('\n');
    }
}

fn main() {
    let tsv = std::env::args().any(|a| a == "--tsv");
    let xs = unary_inputs();
    let ps = binary_inputs();
    let mut out = String::new();
    let mut full = String::new();

    out.push_str(
        "// Generated by oracle/src/bin/gen_libm_tests.rs from the `libm` crate \
         (0.2.16);\n// see there for the cases and the regeneration command. \
         Do not edit.\n\n",
    );

    // Explicit cases.
    out.push_str("///|\nlet libm_unary_inputs : ReadOnlyArray[UInt64] = [\n");
    words(&mut out, &xs.iter().map(|x| x.to_bits()).collect::<Vec<_>>());
    out.push_str("]\n\n");
    out.push_str(
        "///|\nlet libm_unary_expected : ReadOnlyArray[(String, ReadOnlyArray[UInt64])] = [\n",
    );
    for (name, f) in UNARY {
        writeln!(out, "  (\"{name}\", [").unwrap();
        let rs: Vec<u64> = xs.iter().map(|&x| canon(f(x))).collect();
        words(&mut out, &rs);
        out.push_str("  ]),\n");
        for (x, r) in xs.iter().zip(&rs) {
            writeln!(full, "{name}\t{:016x}\t{r:016x}", x.to_bits()).unwrap();
        }
    }
    out.push_str("]\n\n");

    out.push_str("///|\nlet libm_binary_inputs : ReadOnlyArray[UInt64] = [\n");
    words(&mut out, &ps.iter().map(|x| x.to_bits()).collect::<Vec<_>>());
    out.push_str("]\n\n");
    out.push_str(
        "///|\n/// Row-major: `f(inputs[i], inputs[j])` at `i * inputs.length() + j`.\n\
         let libm_binary_expected : ReadOnlyArray[(String, ReadOnlyArray[UInt64])] = [\n",
    );
    for (name, f) in BINARY {
        writeln!(out, "  (\"{name}\", [").unwrap();
        let mut rs = vec![];
        for &x in &ps {
            for &y in &ps {
                let r = canon(f(x, y));
                rs.push(r);
                writeln!(full, "{name}\t{:016x}\t{:016x}\t{r:016x}", x.to_bits(), y.to_bits())
                    .unwrap();
            }
        }
        words(&mut out, &rs);
        out.push_str("  ]),\n");
    }
    out.push_str("]\n\n");

    // Thresholds.
    out.push_str(
        "///|\n/// The high words the algorithms compare against.\n\
         let libm_threshold_words : ReadOnlyArray[UInt] = [\n",
    );
    for chunk in THRESHOLDS.chunks(6) {
        out.push_str("   ");
        for v in chunk {
            write!(out, " 0x{v:08x},").unwrap();
        }
        out.push('\n');
    }
    out.push_str("]\n\n");
    out.push_str(
        "///|\n/// Unary functions at the values around the thresholds \
         (`libm_test_threshold_inputs`).\n\
         let libm_unary_thresholds : ReadOnlyArray[(String, UInt64)] = [\n",
    );
    let ts = threshold_inputs();
    for (name, f) in UNARY {
        let mut hash = Hash::new();
        for &x in &ts {
            let r = f(x);
            hash.add(r);
            writeln!(full, "{name}\t{:016x}\t{:016x}", x.to_bits(), canon(r)).unwrap();
        }
        writeln!(out, "  (\"{name}\", 0x{:016x}UL),", hash.0).unwrap();
    }
    out.push_str("]\n\n");

    // Sweeps.
    out.push_str(
        "///|\n/// `(function, seed, count, x range, y range, hash)`; a range is \
         `(lo, hi, signed)`\n/// (`lo < 0`: unary).\n\
         let libm_sweeps : ReadOnlyArray[(String, UInt64, Int, (Int, Int, Bool), (Int, Int, Bool), UInt64)] = [\n",
    );
    for (i, sweep) in SWEEPS.iter().enumerate() {
        let seed = 0x6c69_626d_0000_0000 + i as u64;
        let mut rng = Rng(seed);
        let mut hash = Hash::new();
        for _ in 0..SWEEP_COUNT {
            let x = sample(&mut rng, sweep.x);
            match sweep.y {
                None => {
                    let r = unary(sweep.name)(x);
                    hash.add(r);
                    writeln!(full, "{}\t{:016x}\t{:016x}", sweep.name, x.to_bits(), canon(r))
                        .unwrap();
                }
                Some(range) => {
                    let y = sample(&mut rng, range);
                    let r = binary(sweep.name)(x, y);
                    hash.add(r);
                    writeln!(
                        full,
                        "{}\t{:016x}\t{:016x}\t{:016x}",
                        sweep.name,
                        x.to_bits(),
                        y.to_bits(),
                        canon(r)
                    )
                    .unwrap();
                }
            }
        }
        let (lo, hi, signed) = sweep.x;
        let (lo2, hi2, signed2) = match sweep.y {
            Some((lo, hi, signed)) => (lo as i64, hi as i64, signed),
            None => (-1, -1, false),
        };
        writeln!(
            out,
            "  (\"{}\", 0x{seed:016x}UL, {SWEEP_COUNT}, ({lo}, {hi}, {signed}), ({lo2}, {hi2}, {signed2}), 0x{:016x}UL),",
            sweep.name, hash.0
        )
        .unwrap();
    }
    out.push_str("]\n\n");

    // Grids.
    writeln!(
        out,
        "///|\n/// Unary functions at `i / 16` for `i` in `-{GRID}..={GRID}`.\n\
         let libm_unary_grids : ReadOnlyArray[(String, UInt64)] = ["
    )
    .unwrap();
    for (name, f) in UNARY {
        let mut hash = Hash::new();
        for i in -GRID..=GRID {
            let x = i as f64 / 16.0;
            let r = f(x);
            hash.add(r);
            writeln!(full, "{name}\t{:016x}\t{:016x}", x.to_bits(), canon(r)).unwrap();
        }
        writeln!(out, "  (\"{name}\", 0x{:016x}UL),", hash.0).unwrap();
    }
    out.push_str("]\n\n");
    out.push_str(
        "///|\n/// Binary grids (`libm_test_binary_grid`).\n\
         let libm_binary_grids : ReadOnlyArray[(String, UInt64)] = [\n",
    );
    for (name, f, args) in binary_grids() {
        let mut hash = Hash::new();
        let label = if name == "pow_root" { "pow" } else { name };
        for (x, y) in args {
            let r = f(x, y);
            hash.add(r);
            writeln!(full, "{label}\t{:016x}\t{:016x}\t{:016x}", x.to_bits(), y.to_bits(), canon(r))
                .unwrap();
        }
        writeln!(out, "  (\"{name}\", 0x{:016x}UL),", hash.0).unwrap();
    }
    out.push_str("]\n");

    print!("{}", if tsv { full } else { out });
}
