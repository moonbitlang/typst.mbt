//! Generates `libm/cbrt_cases_wbtest.mbt`: differential tests for the
//! MoonBit port of the `libm` crate's `cbrt` (`libm/cbrt.mbt`), with expected
//! results produced by the real crate.
//!
//! `libm::cbrt` is what Rust's `f64::cbrt` is on every target where
//! compiler-builtins defines the C symbol `cbrt` (all but Windows and
//! Apple's, e.g. x86_64 Linux), and upstream reaches it through kurbo's
//! `solve_cubic` (underline evasion in typst-layout's `deco.rs`, stroking).
//!
//! All cases are compared bit for bit (every NaN counts as the same value):
//!
//! * special: zeros, infinities, NaN, subnormals, limits, small integers,
//!   the two arguments `cbrt.rs` special-cases and the seven of its `wlist`
//!   (at several scales, both signs), the crate's own spot check. Inputs and
//!   expected results are recorded.
//! * hard: arguments whose cube root is within 2^-75 (relative to a root in
//!   [1, 2)) of the midpoint of two doubles, which the algorithm resolves in
//!   its second iteration (`ady1 < 0x1p-75`). They are found by cubing
//!   pseudo-random midpoints exactly and keeping those whose cube is that
//!   close to a double; each is also recorded negated at another scale.
//!   Inputs and expected results are recorded.
//! * cubes: `n^3` for every `n` with `n^3 < 2^53`, and its two neighbours
//!   (the exact results take the last branch of `cbrt.rs`), recorded as an
//!   FNV-1a-64 hash of the results.
//! * powers of two: `±2^k` for every `k` from -1074 to 1023, as a hash.
//! * grid: `i / 16` for `i` from -80000 to 80000, as a hash.
//! * sweeps: pseudo-random arguments drawn from binary-exponent ranges. The
//!   arguments are not stored: both sides regenerate them with the same
//!   SplitMix64 generator (`sample` here, `cbrt_test_sample` in
//!   `libm/cbrt_wbtest.mbt`); only the hash of the results is recorded.
//!
//! Usage (from `oracle/`, so that `rust-toolchain.toml` applies):
//!   cargo run --release --offline --bin gen_libm_cbrt_tests \
//!     > ../libm/cbrt_cases_wbtest.mbt && (cd .. && moon fmt)
//! Debugging: `... --bin gen_libm_cbrt_tests -- --tsv` writes every case in
//! full as `kind \t x \t result` (16 hex digits of `f64::to_bits`), so a hash
//! mismatch can be located.
//!
//! `... --bin gen_libm_cbrt_tests -- --check-std` compares the platform's
//! `f64::cbrt` with `libm::cbrt` on every case and fails if they differ. It
//! must pass wherever `libm/f64_native.mbt` uses the port (x86_64 Linux); on
//! macOS it reports how often Apple's `cbrt` is not the correctly rounded
//! result (6.6% of the sweeps' arguments, 6.8% of all cases), which is why
//! the port calls the C library there.
//!
//! The file only depends on `libm`, so it can also be compiled alone (a
//! scratch cargo project with `libm = "=0.2.16"` and this file as
//! `src/main.rs`).

use std::fmt::Write as _;

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

fn dedup(v: Vec<f64>) -> Vec<f64> {
    let mut seen = std::collections::HashSet::new();
    v.into_iter().filter(|x| seen.insert(canon(*x))).collect()
}

/// `x * 2^n` for results that are normal (exact).
fn scale(x: f64, n: i32) -> f64 {
    let e = ((x.to_bits() >> 52) & 0x7ff) as i32 + n;
    assert!((1..2047).contains(&e));
    f64::from_bits((x.to_bits() & !(0x7ff << 52)) | ((e as u64) << 52))
}

/// The arguments `cbrt.rs` compares `zz.abs()` with (all in [1, 8)): the two
/// of rounding to nearest, then the `wlist` of the directed modes.
const EXCEPTIONAL: &[u64] = &[
    0x4009_b782_23aa_307c, // 0x1.9b78223aa307cp+1
    0x401a_202b_fc89_ddff, // 0x1.a202bfc89ddffp+2
    0x3ff3_a9cc_d7f0_22db, // 0x1.3a9ccd7f022dbp+0
    0x3ff7_845d_2faa_c6fe, // 0x1.7845d2faac6fep+0
    0x3ffd_1ef8_1cbb_be71, // 0x1.d1ef81cbbbe71p+0
    0x4000_a201_4f62_987c, // 0x1.0a2014f62987cp+1
    0x400f_e18a_044a_5501, // 0x1.fe18a044a5501p+1
    0x401a_6bb8_c803_147b, // 0x1.a6bb8c803147bp+2
    0x401a_c853_8a03_1cbd, // 0x1.ac8538a031cbdp+2
];

fn special_inputs() -> Vec<f64> {
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
        2.0 - f64::EPSILON,
        8.0 - 4.0 * f64::EPSILON,
        std::f64::consts::E,
        std::f64::consts::PI,
        std::f64::consts::SQRT_2,
        -std::f64::consts::E,
        -std::f64::consts::PI,
        0.1,
        0.2,
        0.3,
        0.75,
        0.9,
        1.1,
        1.5,
        2.5,
        -0.1,
        -0.75,
        -1.5,
        1e-320,
        1e-310,
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
        -1e-320,
        -1e-300,
        -1e-10,
        -1e10,
        -1e300,
        // The crate's own spot check ("exposes a rounding mode problem").
        f64::from_bits(0xf7f7_92b2_8f60_0000),
    ];
    // Subnormals: the smallest, the largest, single bits, both signs.
    for bits in [1u64, 2, 3, 7, 8, 9, 0x0008_0000_0000_0000, 0x000f_ffff_ffff_ffff] {
        v.push(f64::from_bits(bits));
        v.push(f64::from_bits(bits | (1 << 63)));
    }
    for k in 0..52 {
        v.push(f64::from_bits(1 << k));
        v.push(f64::from_bits((1 << k) | 1));
    }
    // Both sides of the smallest normal number.
    v.push(f64::from_bits(0x0010_0000_0000_0001));
    v.push(f64::from_bits(0x001f_ffff_ffff_ffff));
    for i in -30..=30 {
        v.push(i as f64);
        v.push(i as f64 / 8.0);
    }
    // Cubes, exact and inexact powers of two around every residue of the
    // exponent modulo 3.
    for i in [27, 64, 125, 216, 343, 512, 729, 1000, 4096, 65536, 1 << 20, 1 << 30] {
        v.push(i as f64);
        v.push(-(i as f64));
        v.push(1.0 / i as f64);
    }
    for &bits in EXCEPTIONAL {
        let zz = f64::from_bits(bits);
        for k in [-300, -100, -1, 0, 1, 100, 300] {
            v.push(scale(zz, 3 * k));
            v.push(-scale(zz, 3 * k));
        }
        // The neighbours are ordinary arguments.
        v.push(f64::from_bits(bits + 1));
        v.push(f64::from_bits(bits - 1));
    }
    dedup(v)
}

/// The number of midpoints that `hard_inputs` cubes.
const HARD_SEARCH: u64 = 1 << 30;

/// Arguments `x` in [1, 8) whose cube root is within 2^-75 of the midpoint of
/// two doubles in [1, 2).
///
/// For a midpoint `y = m * 2^-53` (`m` odd, 2^53 < m < 2^54), `y^3 = m^3 *
/// 2^-159` exactly. With `x` the double nearest to it and `d = |x - y^3|`,
/// `|cbrt(x) - y| = d / (3 y^2)` up to second order, so `d < 2^-74` suffices.
fn hard_inputs() -> Vec<f64> {
    let mut rng = Rng(0x6862_7274_2d68_6172);
    let mut out = vec![];
    for _ in 0..HARD_SEARCH {
        let m: u64 = (1 << 53) | (rng.next() & ((1 << 53) - 1)) | 1;
        // p = m^3 = p_hi * 2^64 + p_lo, up to 162 bits.
        let m2: u128 = (m as u128) * (m as u128);
        let t: u128 = (m2 as u64 as u128) * (m as u128);
        let p_lo: u64 = t as u64;
        let p_hi: u128 = (m2 >> 64) * (m as u128) + (t >> 64);
        // 2^(159 + e) <= p < 2^(160 + e): the binade of `y^3`.
        let e: u32 = 127 - p_hi.leading_zeros() - (159 - 64);
        // One ulp of `x` is 2^(107 + e) in units of 2^-159.
        let shift = 107 + e - 64;
        let mut mant: u64 = (p_hi >> shift) as u64;
        let frac: u128 = ((p_hi & ((1u128 << shift) - 1)) << 64) | p_lo as u128;
        let ulp: u128 = 1u128 << (107 + e);
        let d = if frac > ulp / 2 {
            mant += 1;
            ulp - frac
        } else {
            frac
        };
        // d * 2^-159 < 2^-74.
        if d >= 1u128 << 85 || mant >> 53 != 0 {
            continue;
        }
        assert!(mant >> 52 == 1);
        out.push(f64::from_bits(((1023 + e as u64) << 52) | (mant & ((1 << 52) - 1))));
    }
    // The same arguments at other scales, negated.
    let n = out.len();
    for i in 0..n {
        let k = (rng.next() % 661) as i32 - 330;
        out.push(-scale(out[i], 3 * k));
    }
    out
}

/// The largest `n` with `n^3 < 2^53`.
const CUBES: u64 = 208063;

fn cube_inputs() -> Vec<f64> {
    assert!((CUBES + 1).pow(3) >= 1 << 53);
    let mut v = vec![];
    for n in 1..=CUBES {
        let x = (n * n * n) as f64;
        assert!(x as u64 == n * n * n);
        v.push(x);
        v.push(f64::from_bits(x.to_bits() - 1));
        v.push(f64::from_bits(x.to_bits() + 1));
    }
    v
}

fn pow2_inputs() -> Vec<f64> {
    let mut v = vec![];
    for k in -1074..=1023 {
        let x = if k < -1022 {
            f64::from_bits(1 << (k + 1074))
        } else {
            f64::from_bits(((k + 1023) as u64) << 52)
        };
        v.push(x);
        v.push(-x);
    }
    v
}

fn grid_inputs() -> Vec<f64> {
    (-80000..=80000).map(|i| i as f64 / 16.0).collect()
}

/// `(lo, hi, signed, count)`: `count` samples of a biased-exponent range.
const SWEEPS: &[(u64, u64, bool, usize)] = &[
    (0, 2047, true, 100000),
    // [1, 8): the reduced argument `zz`.
    (1023, 1025, true, 100000),
    // Subnormals and the smallest normal numbers.
    (0, 1, true, 50000),
    (1, 2046, false, 50000),
];

fn seed(i: usize) -> u64 {
    0x6362_7274_0000_0000 + (i as u64) * 0x1_0001
}

fn hex(v: u64) -> String {
    format!("0x{v:016x}UL")
}

fn list(out: &mut String, name: &str, values: impl Iterator<Item = u64>) {
    writeln!(out, "///|\nlet {name} : ReadOnlyArray[UInt64] = [").unwrap();
    for v in values {
        writeln!(out, "  {},", hex(v)).unwrap();
    }
    out.push_str("]\n\n");
}

fn hash_of(inputs: &[f64]) -> u64 {
    let mut h = Hash::new();
    for &x in inputs {
        h.add(libm::cbrt(x));
    }
    h.0
}

fn main() {
    let mode = std::env::args().nth(1);
    let special = special_inputs();
    let hard = hard_inputs();
    let cubes = cube_inputs();
    let pow2 = pow2_inputs();
    let grid = grid_inputs();
    let sweeps: Vec<Vec<f64>> = SWEEPS
        .iter()
        .enumerate()
        .map(|(i, &(lo, hi, signed, count))| {
            let mut rng = Rng(seed(i));
            (0..count).map(|_| sample(&mut rng, (lo, hi, signed))).collect()
        })
        .collect();

    let mut kinds: Vec<(String, &[f64])> = vec![
        ("special".into(), &special),
        ("hard".into(), &hard),
        ("cubes".into(), &cubes),
        ("pow2".into(), &pow2),
        ("grid".into(), &grid),
    ];
    for (i, s) in sweeps.iter().enumerate() {
        kinds.push((format!("sweep{i}"), s));
    }

    match mode.as_deref() {
        Some("--tsv") => {
            let mut out = String::new();
            for (kind, inputs) in &kinds {
                for &x in inputs.iter() {
                    writeln!(out, "{kind}\t{:016x}\t{:016x}", x.to_bits(), canon(libm::cbrt(x)))
                        .unwrap();
                }
            }
            print!("{out}");
            return;
        }
        Some("--check-std") => {
            let mut total = 0usize;
            let mut differing = 0usize;
            for (kind, inputs) in &kinds {
                let mut n = 0usize;
                for &x in inputs.iter() {
                    let x = std::hint::black_box(x);
                    if canon(x.cbrt()) != canon(libm::cbrt(x)) {
                        n += 1;
                    }
                }
                println!("{kind}: f64::cbrt differs from libm::cbrt in {n} of {}", inputs.len());
                total += inputs.len();
                differing += n;
            }
            println!("total: {differing} of {total}");
            if differing != 0 {
                std::process::exit(1);
            }
            return;
        }
        Some(other) => panic!("unknown argument {other}"),
        None => {}
    }

    let mut out = String::new();
    out.push_str(
        "// Generated by oracle/src/bin/gen_libm_cbrt_tests.rs from the `libm` crate (0.2.16);\n\
         // see there for the cases and the regeneration command. Do not edit.\n\n",
    );
    list(&mut out, "cbrt_special_inputs", special.iter().map(|x| x.to_bits()));
    list(&mut out, "cbrt_special_expected", special.iter().map(|&x| canon(libm::cbrt(x))));
    list(&mut out, "cbrt_hard_inputs", hard.iter().map(|x| x.to_bits()));
    list(&mut out, "cbrt_hard_expected", hard.iter().map(|&x| canon(libm::cbrt(x))));
    writeln!(out, "///|\nconst CBRT_CUBES : Int = {CUBES}\n").unwrap();
    writeln!(out, "///|\nconst CBRT_CUBES_HASH : UInt64 = {}\n", hex(hash_of(&cubes))).unwrap();
    writeln!(out, "///|\nconst CBRT_POW2_HASH : UInt64 = {}\n", hex(hash_of(&pow2))).unwrap();
    writeln!(out, "///|\nconst CBRT_GRID_HASH : UInt64 = {}\n", hex(hash_of(&grid))).unwrap();
    out.push_str(
        "///|\n/// `(seed, count, lo, hi, signed, hash)`.\n\
         let cbrt_sweeps : ReadOnlyArray[(UInt64, Int, Int, Int, Bool, UInt64)] = [\n",
    );
    for (i, &(lo, hi, signed, count)) in SWEEPS.iter().enumerate() {
        writeln!(
            out,
            "  ({}, {count}, {lo}, {hi}, {signed}, {}),",
            hex(seed(i)),
            hex(hash_of(&sweeps[i]))
        )
        .unwrap();
    }
    out.push_str("]\n");
    print!("{out}");
}
