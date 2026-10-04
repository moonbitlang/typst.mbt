//! Generates `wasmi/core/testdata/oracle.tsv`: differential tests for the
//! MoonBit port of `wasmi_core` 1.0.9 (features `simd`, no `std`, i.e. the
//! `libm` float paths that Typst's `wasmi` uses), with expected results
//! produced by the real crate.
//!
//! Every line is `op \t args... \t expected`. Values are lowercase hex of
//! their bits: `i32`/`u32`/`f32` 8 digits, `i64`/`u64`/`f64` 16 digits,
//! `V128` 32 digits (the `u128`), `bool` `0`/`1`. A trap is `!<code>` with
//! the `u8` of the `TrapCode`. Memory accessors run on a 40 byte memory
//! (`mem_init`) and stores record the whole memory afterwards. `memory`,
//! `table` and `display` lines are scenario transcripts (see the functions
//! below and `wasmi/core/oracle_test.mbt`).
//!
//! Float results are bit-exact including NaN payloads: they are what the
//! crate computes on the machine running the generator, which must be
//! aarch64 (Apple silicon) like the oracle for Typst's goldens.
//!
//! Usage (from `oracle/`):
//! `cargo run --release --offline --bin gen_wasmi_core_tests > ../wasmi/core/testdata/oracle.tsv`

use std::fmt::Write as _;

use wasmi_core::simd::{self, ImmLaneIdx16, ImmLaneIdx2, ImmLaneIdx32, ImmLaneIdx4, ImmLaneIdx8};
use wasmi_core::wasm;
use wasmi_core::{
    ElementSegment, F32, F64, Fuel, FuelCostsProvider, FuelError, FuncType, FuncTypeError,
    GlobalError, LimiterError, Memory, MemoryError, MemoryType, ResourceLimiter,
    ResourceLimiterRef, Table, TableError, TableType, Trap, TrapCode, TypedVal, UntypedError,
    UntypedVal, V128, ValType,
};

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        // SplitMix64
        self.0 = self.0.wrapping_add(0x9e37_79b9_7f4a_7c15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
        z ^ (z >> 31)
    }
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

struct Out(String);

impl Out {
    fn line(&mut self, op: &str, args: &[String], expected: String) {
        self.0.push_str(op);
        for a in args {
            self.0.push('\t');
            self.0.push_str(a);
        }
        self.0.push('\t');
        self.0.push_str(&expected);
        self.0.push('\n');
    }
}

fn h32(v: u32) -> String {
    format!("{v:08x}")
}
fn h64(v: u64) -> String {
    format!("{v:016x}")
}
fn hv(v: V128) -> String {
    format!("{:032x}", v.as_u128())
}
fn hb(v: bool) -> String {
    (if v { "1" } else { "0" }).to_string()
}
fn trap(t: TrapCode) -> String {
    format!("!{}", u8::from(t))
}
fn r32(r: Result<u32, TrapCode>) -> String {
    r.map(h32).unwrap_or_else(trap)
}
fn r64(r: Result<u64, TrapCode>) -> String {
    r.map(h64).unwrap_or_else(trap)
}
fn f32b(v: u32) -> f32 {
    f32::from_bits(v)
}
fn f64b(v: u64) -> f64 {
    f64::from_bits(v)
}
fn v128(v: u128) -> V128 {
    V128::from(v)
}

// Input pools.

fn i32_pool(rng: &mut Rng) -> Vec<u32> {
    let mut v: Vec<u32> = vec![
        0, 1, 2, 3, 0xFFFF_FFFF, 0xFFFF_FFFE, 0x8000_0000, 0x7FFF_FFFF, 0x8000_0001, 0x7FFF_FFFE,
        31, 32, 33, 63, 64, 0x7F, 0x80, 0xFF, 0x100, 0x7FFF, 0x8000, 0xFFFF, 0x1_0000,
        0x1234_5678, 0xDEAD_BEEF, 0xFFFF_FF80, 0xFFFF_8000,
    ];
    for _ in 0..5 {
        v.push(rng.next() as u32);
    }
    v
}

fn i64_pool(rng: &mut Rng) -> Vec<u64> {
    let mut v: Vec<u64> = vec![
        0,
        1,
        2,
        3,
        u64::MAX,
        u64::MAX - 1,
        0x8000_0000_0000_0000,
        0x7FFF_FFFF_FFFF_FFFF,
        0x8000_0000_0000_0001,
        63,
        64,
        65,
        127,
        0x80,
        0xFF,
        0x8000,
        0xFFFF_FFFF,
        0x1_0000_0000,
        0x8000_0000,
        0xFFFF_FFFF_8000_0000,
        0x0123_4567_89AB_CDEF,
        0xFEDC_BA98_7654_3210,
        0x20_0000_2000_0001,
        0x7FFF_FFFF_FFFF_FC00,
        0xFFFF_FFFF_FFFF_FF80,
    ];
    for _ in 0..5 {
        v.push(rng.next());
    }
    v
}

/// `f32` values for binary operations (bits).
fn f32_small_pool(rng: &mut Rng) -> Vec<u32> {
    let mut v: Vec<u32> = vec![
        0x0000_0000, 0x8000_0000, // ±0
        0x3F80_0000, 0xBF80_0000, // ±1
        0x3F00_0000, 0xBF00_0000, // ±0.5
        0x3FC0_0000, 0xC020_0000, // 1.5, -2.5
        0x7F80_0000, 0xFF80_0000, // ±inf
        0x7FC0_0000, 0xFFC0_0000, // ±qNaN
        0x7FC1_2345, 0xFFC5_4321, // qNaN payloads
        0x7F80_0001, 0xFFA0_0005, // sNaN
        0x7FA1_2345, // sNaN payload
        0x0000_0001, 0x8000_0001, // ±min subnormal
        0x007F_FFFF, // max subnormal
        0x0080_0000, // min normal
        0x7F7F_FFFF, 0xFF7F_FFFF, // ±max
        0x4040_0000, // 3
        0x5015_02F9, // 1e10
        0x2EDB_E6FF, // 1e-10
        0x3DCC_CCCD, // 0.1
        0x4A80_0001, // 4194304.5
    ];
    for _ in 0..4 {
        v.push(rng.next() as u32);
    }
    v
}

/// `f32` values for unary operations and conversions (bits).
fn f32_big_pool(rng: &mut Rng) -> Vec<u32> {
    let mut v = f32_small_pool(rng);
    let floats: &[f32] = &[
        2147483648.0,
        2147483520.0,
        -2147483648.0,
        -2147483904.0,
        -2147483520.0,
        4294967296.0,
        4294967040.0,
        -1.0,
        -0.99999994,
        0.99999994,
        9223372036854775808.0,
        9223371487098961920.0,
        -9223372036854775808.0,
        -9223373136366403584.0,
        18446744073709551616.0,
        18446742974197923840.0,
        2.5,
        -1.5,
        3.5,
        -3.5,
        4.5,
        5.5,
        -0.5,
        0.49999997,
        -0.49999997,
        0.50000006,
        8388607.5,
        8388608.0,
        8388609.0,
        16777216.0,
        16777218.0,
        1e30,
        -1e30,
        123456.79,
        -7.25,
        65535.5,
        65536.0,
        -32768.5,
        2147483647.0,
        1e-40,
    ];
    v.extend(floats.iter().map(|f| f.to_bits()));
    for _ in 0..100 {
        v.push(rng.next() as u32);
    }
    // "Reasonable" magnitudes (exponents around zero).
    for _ in 0..100 {
        let r = rng.next();
        let exp = 127 - 4 + (r % 40) as u32;
        let bits = ((r >> 8) as u32 & 0x807F_FFFF) | (exp << 23);
        v.push(bits);
    }
    v
}

fn f64_small_pool(rng: &mut Rng) -> Vec<u64> {
    let mut v: Vec<u64> = vec![
        0x0000_0000_0000_0000,
        0x8000_0000_0000_0000,
        1.0f64.to_bits(),
        (-1.0f64).to_bits(),
        0.5f64.to_bits(),
        (-0.5f64).to_bits(),
        1.5f64.to_bits(),
        (-2.5f64).to_bits(),
        0x7FF0_0000_0000_0000,
        0xFFF0_0000_0000_0000,
        0x7FF8_0000_0000_0000,
        0xFFF8_0000_0000_0000,
        0x7FF8_0000_0012_3456,
        0xFFFC_0000_0000_4321,
        0x7FF0_0000_0000_0001,
        0xFFF4_0000_0000_0005,
        0x7FF1_2345_6789_ABCD,
        0x0000_0000_0000_0001,
        0x8000_0000_0000_0001,
        0x000F_FFFF_FFFF_FFFF,
        0x0010_0000_0000_0000,
        0x7FEF_FFFF_FFFF_FFFF,
        0xFFEF_FFFF_FFFF_FFFF,
        3.0f64.to_bits(),
        1e10f64.to_bits(),
        1e-10f64.to_bits(),
        0.1f64.to_bits(),
        2251799813685248.5f64.to_bits(),
    ];
    for _ in 0..4 {
        v.push(rng.next());
    }
    v
}

fn f64_big_pool(rng: &mut Rng) -> Vec<u64> {
    let mut v = f64_small_pool(rng);
    let floats: &[f64] = &[
        2147483648.0,
        2147483647.0,
        2147483647.9,
        -2147483648.0,
        -2147483648.9,
        -2147483649.0,
        4294967296.0,
        4294967295.0,
        4294967295.9,
        -1.0,
        -0.9999999999999999,
        0.9999999999999999,
        9223372036854775808.0,
        9223372036854774784.0,
        -9223372036854775808.0,
        -9223372036854777856.0,
        18446744073709551616.0,
        18446744073709549568.0,
        9.5e18,
        2.5,
        -1.5,
        3.5,
        -3.5,
        4.5,
        5.5,
        -0.5,
        0.49999999999999994,
        -0.49999999999999994,
        0.5000000000000001,
        4503599627370495.5,
        4503599627370496.0,
        4503599627370497.0,
        9007199254740992.0,
        9007199254740994.0,
        1e300,
        -1e300,
        123456.789,
        -7.25,
        1e-310,
        3.4028235677973366e38,
        3.4028236e38,
        1.401298464324817e-45,
        7.006492321624085e-46,
        1.1754942807573643e-38,
    ];
    v.extend(floats.iter().map(|f| f.to_bits()));
    for _ in 0..100 {
        v.push(rng.next());
    }
    for _ in 0..100 {
        let r = rng.next();
        let exp = 1023 - 4 + (r % 70);
        let bits = (r & 0x800F_FFFF_FFFF_FFFF) | (exp << 52);
        v.push(bits);
    }
    v
}

fn conversion_i64_pool(rng: &mut Rng) -> Vec<u64> {
    let mut v = i64_pool(rng);
    v.extend_from_slice(&[
        (1 << 53) + 1,
        (1 << 53) + 3,
        (1 << 24) + 1,
        (1 << 63) + (1 << 39) + 1,
        (1 << 63) + (1 << 40),
        0xFFFF_FF80_0000_0001,
        0x0000_0080_0000_0081,
        0x0000_0100_0000_0080,
        0x8000_0080_0000_0000,
        0x8000_0080_0000_0001,
        0x7FFF_FFBF_FFFF_FFFF,
    ]);
    for _ in 0..60 {
        let r = rng.next();
        v.push(r >> (r % 64));
    }
    v
}

// Scalar operations.

fn gen_scalar(out: &mut Out, rng: &mut Rng) {
    let i32s = i32_pool(rng);
    let i64s = i64_pool(rng);
    // Smaller pools for the binary operations.
    let i32b: Vec<u32> = i32s[..16].iter().chain(&i32s[27..29]).copied().collect();
    let i64b: Vec<u64> = i64s[..16].iter().chain(&i64s[25..27]).copied().collect();
    macro_rules! bin_i32 {
        ($($name:ident: $f:expr),* $(,)?) => {$(
            for &a in &i32b { for &b in &i32b {
                let f = $f;
                out.line(stringify!($name), &[h32(a), h32(b)], f(a, b));
            }}
        )*};
    }
    bin_i32! {
        i32_add: |a: u32, b: u32| h32(wasm::i32_add(a as i32, b as i32) as u32),
        i32_sub: |a: u32, b: u32| h32(wasm::i32_sub(a as i32, b as i32) as u32),
        i32_mul: |a: u32, b: u32| h32(wasm::i32_mul(a as i32, b as i32) as u32),
        i32_bitand: |a: u32, b: u32| h32(wasm::i32_bitand(a as i32, b as i32) as u32),
        i32_bitor: |a: u32, b: u32| h32(wasm::i32_bitor(a as i32, b as i32) as u32),
        i32_bitxor: |a: u32, b: u32| h32(wasm::i32_bitxor(a as i32, b as i32) as u32),
        i32_shl: |a: u32, b: u32| h32(wasm::i32_shl(a as i32, b as i32) as u32),
        i32_shr_s: |a: u32, b: u32| h32(wasm::i32_shr_s(a as i32, b as i32) as u32),
        i32_shr_u: |a: u32, b: u32| h32(wasm::i32_shr_u(a as i32, b as i32) as u32),
        i32_rotl: |a: u32, b: u32| h32(wasm::i32_rotl(a as i32, b as i32) as u32),
        i32_rotr: |a: u32, b: u32| h32(wasm::i32_rotr(a as i32, b as i32) as u32),
        i32_div_s: |a: u32, b: u32| r32(wasm::i32_div_s(a as i32, b as i32).map(|v| v as u32)),
        i32_div_u: |a: u32, b: u32| r32(wasm::i32_div_u(a, b)),
        i32_rem_s: |a: u32, b: u32| r32(wasm::i32_rem_s(a as i32, b as i32).map(|v| v as u32)),
        i32_rem_u: |a: u32, b: u32| r32(wasm::i32_rem_u(a, b)),
        i32_eq: |a: u32, b: u32| hb(wasm::i32_eq(a as i32, b as i32)),
        i32_ne: |a: u32, b: u32| hb(wasm::i32_ne(a as i32, b as i32)),
        i32_lt_s: |a: u32, b: u32| hb(wasm::i32_lt_s(a as i32, b as i32)),
        i32_lt_u: |a: u32, b: u32| hb(wasm::i32_lt_u(a, b)),
        i32_le_s: |a: u32, b: u32| hb(wasm::i32_le_s(a as i32, b as i32)),
        i32_le_u: |a: u32, b: u32| hb(wasm::i32_le_u(a, b)),
        i32_gt_s: |a: u32, b: u32| hb(wasm::i32_gt_s(a as i32, b as i32)),
        i32_gt_u: |a: u32, b: u32| hb(wasm::i32_gt_u(a, b)),
        i32_ge_s: |a: u32, b: u32| hb(wasm::i32_ge_s(a as i32, b as i32)),
        i32_ge_u: |a: u32, b: u32| hb(wasm::i32_ge_u(a, b)),
    }
    macro_rules! bin_i64 {
        ($($name:ident: $f:expr),* $(,)?) => {$(
            for &a in &i64b { for &b in &i64b {
                let f = $f;
                out.line(stringify!($name), &[h64(a), h64(b)], f(a, b));
            }}
        )*};
    }
    bin_i64! {
        i64_add: |a: u64, b: u64| h64(wasm::i64_add(a as i64, b as i64) as u64),
        i64_sub: |a: u64, b: u64| h64(wasm::i64_sub(a as i64, b as i64) as u64),
        i64_mul: |a: u64, b: u64| h64(wasm::i64_mul(a as i64, b as i64) as u64),
        i64_bitand: |a: u64, b: u64| h64(wasm::i64_bitand(a as i64, b as i64) as u64),
        i64_bitor: |a: u64, b: u64| h64(wasm::i64_bitor(a as i64, b as i64) as u64),
        i64_bitxor: |a: u64, b: u64| h64(wasm::i64_bitxor(a as i64, b as i64) as u64),
        i64_shl: |a: u64, b: u64| h64(wasm::i64_shl(a as i64, b as i64) as u64),
        i64_shr_s: |a: u64, b: u64| h64(wasm::i64_shr_s(a as i64, b as i64) as u64),
        i64_shr_u: |a: u64, b: u64| h64(wasm::i64_shr_u(a as i64, b as i64) as u64),
        i64_rotl: |a: u64, b: u64| h64(wasm::i64_rotl(a as i64, b as i64) as u64),
        i64_rotr: |a: u64, b: u64| h64(wasm::i64_rotr(a as i64, b as i64) as u64),
        i64_div_s: |a: u64, b: u64| r64(wasm::i64_div_s(a as i64, b as i64).map(|v| v as u64)),
        i64_div_u: |a: u64, b: u64| r64(wasm::i64_div_u(a, b)),
        i64_rem_s: |a: u64, b: u64| r64(wasm::i64_rem_s(a as i64, b as i64).map(|v| v as u64)),
        i64_rem_u: |a: u64, b: u64| r64(wasm::i64_rem_u(a, b)),
        i64_eq: |a: u64, b: u64| hb(wasm::i64_eq(a as i64, b as i64)),
        i64_ne: |a: u64, b: u64| hb(wasm::i64_ne(a as i64, b as i64)),
        i64_lt_s: |a: u64, b: u64| hb(wasm::i64_lt_s(a as i64, b as i64)),
        i64_lt_u: |a: u64, b: u64| hb(wasm::i64_lt_u(a, b)),
        i64_le_s: |a: u64, b: u64| hb(wasm::i64_le_s(a as i64, b as i64)),
        i64_le_u: |a: u64, b: u64| hb(wasm::i64_le_u(a, b)),
        i64_gt_s: |a: u64, b: u64| hb(wasm::i64_gt_s(a as i64, b as i64)),
        i64_gt_u: |a: u64, b: u64| hb(wasm::i64_gt_u(a, b)),
        i64_ge_s: |a: u64, b: u64| hb(wasm::i64_ge_s(a as i64, b as i64)),
        i64_ge_u: |a: u64, b: u64| hb(wasm::i64_ge_u(a, b)),
    }
    for &a in &i32s {
        let x = a as i32;
        out.line("i32_clz", &[h32(a)], h32(wasm::i32_clz(x) as u32));
        out.line("i32_ctz", &[h32(a)], h32(wasm::i32_ctz(x) as u32));
        out.line("i32_popcnt", &[h32(a)], h32(wasm::i32_popcnt(x) as u32));
        out.line("i32_eqz", &[h32(a)], hb(wasm::i32_eqz(x)));
        out.line("i32_extend8_s", &[h32(a)], h32(wasm::i32_extend8_s(x) as u32));
        out.line("i32_extend16_s", &[h32(a)], h32(wasm::i32_extend16_s(x) as u32));
        out.line("i64_extend_i32_s", &[h32(a)], h64(wasm::i64_extend_i32_s(x) as u64));
        out.line("i64_extend_i32_u", &[h32(a)], h64(wasm::i64_extend_i32_u(a)));
        out.line("f32_convert_i32_s", &[h32(a)], h32(wasm::f32_convert_i32_s(x).to_bits()));
        out.line("f32_convert_i32_u", &[h32(a)], h32(wasm::f32_convert_i32_u(a).to_bits()));
        out.line("f64_convert_i32_s", &[h32(a)], h64(wasm::f64_convert_i32_s(x).to_bits()));
        out.line("f64_convert_i32_u", &[h32(a)], h64(wasm::f64_convert_i32_u(a).to_bits()));
        out.line("f32_reinterpret_i32", &[h32(a)], h32(wasm::f32_reinterpret_i32(x).to_bits()));
    }
    let mut extra32: Vec<u32> = vec![0x0100_0001, 0x0100_0003, 0x7FFF_FFC0, 0x7FFF_FFBF, 0x8000_0081];
    for _ in 0..40 {
        let r = rng.next();
        extra32.push((r as u32) >> (r >> 32) % 32);
    }
    for &a in &extra32 {
        out.line("f32_convert_i32_s", &[h32(a)], h32(wasm::f32_convert_i32_s(a as i32).to_bits()));
        out.line("f32_convert_i32_u", &[h32(a)], h32(wasm::f32_convert_i32_u(a).to_bits()));
    }
    for &a in &i64s {
        let x = a as i64;
        out.line("i64_clz", &[h64(a)], h64(wasm::i64_clz(x) as u64));
        out.line("i64_ctz", &[h64(a)], h64(wasm::i64_ctz(x) as u64));
        out.line("i64_popcnt", &[h64(a)], h64(wasm::i64_popcnt(x) as u64));
        out.line("i64_eqz", &[h64(a)], hb(wasm::i64_eqz(x)));
        out.line("i64_extend8_s", &[h64(a)], h64(wasm::i64_extend8_s(x) as u64));
        out.line("i64_extend16_s", &[h64(a)], h64(wasm::i64_extend16_s(x) as u64));
        out.line("i64_extend32_s", &[h64(a)], h64(wasm::i64_extend32_s(x) as u64));
        out.line("i32_wrap_i64", &[h64(a)], h32(wasm::i32_wrap_i64(x) as u32));
        out.line("f64_reinterpret_i64", &[h64(a)], h64(wasm::f64_reinterpret_i64(x).to_bits()));
    }
    for &a in &conversion_i64_pool(rng) {
        let x = a as i64;
        out.line("f32_convert_i64_s", &[h64(a)], h32(wasm::f32_convert_i64_s(x).to_bits()));
        out.line("f32_convert_i64_u", &[h64(a)], h32(wasm::f32_convert_i64_u(a).to_bits()));
        out.line("f64_convert_i64_s", &[h64(a)], h64(wasm::f64_convert_i64_s(x).to_bits()));
        out.line("f64_convert_i64_u", &[h64(a)], h64(wasm::f64_convert_i64_u(a).to_bits()));
    }
    // Wide arithmetic.
    for _ in 0..200 {
        let pick = |rng: &mut Rng| i64s[rng.below(i64s.len())];
        let (a, b, c, d) = (pick(rng), pick(rng), pick(rng), pick(rng));
        let args = [h64(a), h64(b), h64(c), h64(d)];
        let (lo, hi) = wasm::i64_add128(a as i64, b as i64, c as i64, d as i64);
        out.line("i64_add128", &args, format!("{}{}", h64(lo as u64), h64(hi as u64)));
        let (lo, hi) = wasm::i64_sub128(a as i64, b as i64, c as i64, d as i64);
        out.line("i64_sub128", &args, format!("{}{}", h64(lo as u64), h64(hi as u64)));
        let (lo, hi) = wasm::i64_mul_wide_s(a as i64, b as i64);
        out.line("i64_mul_wide_s", &args[..2], format!("{}{}", h64(lo as u64), h64(hi as u64)));
        let (lo, hi) = wasm::i64_mul_wide_u(a as i64, b as i64);
        out.line("i64_mul_wide_u", &args[..2], format!("{}{}", h64(lo as u64), h64(hi as u64)));
    }
}

fn gen_float(out: &mut Out, rng: &mut Rng) {
    let f32s = f32_small_pool(rng);
    let f64s = f64_small_pool(rng);
    let f64s: Vec<u64> = f64s[..22].iter().chain(&f64s[28..32]).copied().collect();
    macro_rules! bin_f32 {
        ($($name:ident => $ret:ident),* $(,)?) => {$(
            for &a in &f32s { for &b in &f32s {
                let r = wasm::$name(f32b(a), f32b(b));
                out.line(stringify!($name), &[h32(a), h32(b)], bin_f32!(@fmt $ret, r));
            }}
        )*};
        (@fmt f, $r:expr) => { h32($r.to_bits()) };
        (@fmt b, $r:expr) => { hb($r) };
    }
    bin_f32! {
        f32_add => f, f32_sub => f, f32_mul => f, f32_div => f, f32_min => f, f32_max => f,
        f32_copysign => f, f32_eq => b, f32_ne => b, f32_lt => b, f32_le => b, f32_gt => b,
        f32_ge => b,
    }
    macro_rules! bin_f64 {
        ($($name:ident => $ret:ident),* $(,)?) => {$(
            for &a in &f64s { for &b in &f64s {
                let r = wasm::$name(f64b(a), f64b(b));
                out.line(stringify!($name), &[h64(a), h64(b)], bin_f64!(@fmt $ret, r));
            }}
        )*};
        (@fmt f, $r:expr) => { h64($r.to_bits()) };
        (@fmt b, $r:expr) => { hb($r) };
    }
    bin_f64! {
        f64_add => f, f64_sub => f, f64_mul => f, f64_div => f, f64_min => f, f64_max => f,
        f64_copysign => f, f64_eq => b, f64_ne => b, f64_lt => b, f64_le => b, f64_gt => b,
        f64_ge => b,
    }
    // Random arithmetic (rounding).
    for _ in 0..300 {
        let (a, b) = (rng.next() as u32 & 0xBFFF_FFFF, rng.next() as u32 & 0xBFFF_FFFF);
        for (name, r) in [
            ("f32_add", wasm::f32_add(f32b(a), f32b(b))),
            ("f32_sub", wasm::f32_sub(f32b(a), f32b(b))),
            ("f32_mul", wasm::f32_mul(f32b(a), f32b(b))),
            ("f32_div", wasm::f32_div(f32b(a), f32b(b))),
        ] {
            out.line(name, &[h32(a), h32(b)], h32(r.to_bits()));
        }
        let (a, b) = (rng.next() & 0xBFFF_FFFF_FFFF_FFFF, rng.next() & 0xBFFF_FFFF_FFFF_FFFF);
        for (name, r) in [
            ("f64_add", wasm::f64_add(f64b(a), f64b(b))),
            ("f64_sub", wasm::f64_sub(f64b(a), f64b(b))),
            ("f64_mul", wasm::f64_mul(f64b(a), f64b(b))),
            ("f64_div", wasm::f64_div(f64b(a), f64b(b))),
        ] {
            out.line(name, &[h64(a), h64(b)], h64(r.to_bits()));
        }
    }
    for &a in &f32_big_pool(rng) {
        let x = f32b(a);
        let args = [h32(a)];
        out.line("f32_abs", &args, h32(wasm::f32_abs(x).to_bits()));
        out.line("f32_neg", &args, h32(wasm::f32_neg(x).to_bits()));
        out.line("f32_ceil", &args, h32(wasm::f32_ceil(x).to_bits()));
        out.line("f32_floor", &args, h32(wasm::f32_floor(x).to_bits()));
        out.line("f32_trunc", &args, h32(wasm::f32_trunc(x).to_bits()));
        out.line("f32_nearest", &args, h32(wasm::f32_nearest(x).to_bits()));
        out.line("f32_sqrt", &args, h32(wasm::f32_sqrt(x).to_bits()));
        out.line("f64_promote_f32", &args, h64(wasm::f64_promote_f32(x).to_bits()));
        out.line("i32_reinterpret_f32", &args, h32(wasm::i32_reinterpret_f32(x) as u32));
        out.line("i32_trunc_f32_s", &args, r32(wasm::i32_trunc_f32_s(x).map(|v| v as u32)));
        out.line("i32_trunc_f32_u", &args, r32(wasm::i32_trunc_f32_u(x)));
        out.line("i64_trunc_f32_s", &args, r64(wasm::i64_trunc_f32_s(x).map(|v| v as u64)));
        out.line("i64_trunc_f32_u", &args, r64(wasm::i64_trunc_f32_u(x)));
        out.line("i32_trunc_sat_f32_s", &args, h32(wasm::i32_trunc_sat_f32_s(x) as u32));
        out.line("i32_trunc_sat_f32_u", &args, h32(wasm::i32_trunc_sat_f32_u(x)));
        out.line("i64_trunc_sat_f32_s", &args, h64(wasm::i64_trunc_sat_f32_s(x) as u64));
        out.line("i64_trunc_sat_f32_u", &args, h64(wasm::i64_trunc_sat_f32_u(x)));
    }
    for &a in &f64_big_pool(rng) {
        let x = f64b(a);
        let args = [h64(a)];
        out.line("f64_abs", &args, h64(wasm::f64_abs(x).to_bits()));
        out.line("f64_neg", &args, h64(wasm::f64_neg(x).to_bits()));
        out.line("f64_ceil", &args, h64(wasm::f64_ceil(x).to_bits()));
        out.line("f64_floor", &args, h64(wasm::f64_floor(x).to_bits()));
        out.line("f64_trunc", &args, h64(wasm::f64_trunc(x).to_bits()));
        out.line("f64_nearest", &args, h64(wasm::f64_nearest(x).to_bits()));
        out.line("f64_sqrt", &args, h64(wasm::f64_sqrt(x).to_bits()));
        out.line("f32_demote_f64", &args, h32(wasm::f32_demote_f64(x).to_bits()));
        out.line("i64_reinterpret_f64", &args, h64(wasm::i64_reinterpret_f64(x) as u64));
        out.line("i32_trunc_f64_s", &args, r32(wasm::i32_trunc_f64_s(x).map(|v| v as u32)));
        out.line("i32_trunc_f64_u", &args, r32(wasm::i32_trunc_f64_u(x)));
        out.line("i64_trunc_f64_s", &args, r64(wasm::i64_trunc_f64_s(x).map(|v| v as u64)));
        out.line("i64_trunc_f64_u", &args, r64(wasm::i64_trunc_f64_u(x)));
        out.line("i32_trunc_sat_f64_s", &args, h32(wasm::i32_trunc_sat_f64_s(x) as u32));
        out.line("i32_trunc_sat_f64_u", &args, h32(wasm::i32_trunc_sat_f64_u(x)));
        out.line("i64_trunc_sat_f64_s", &args, h64(wasm::i64_trunc_sat_f64_s(x) as u64));
        out.line("i64_trunc_sat_f64_u", &args, h64(wasm::i64_trunc_sat_f64_u(x)));
    }
}

// Fused multiply-add (via the relaxed SIMD operations).

fn gen_fma(out: &mut Out, rng: &mut Rng) {
    let f32s: Vec<u32> = vec![
        0x0000_0000, 0x8000_0000, 0x3F80_0000, 0xBF80_0000, 0x7F80_0000, 0xFF80_0000, 0x7FC0_0000,
        0xFFC1_2345, 0x7F80_0001, 0xFFA0_0005, 0x0000_0001, 0x7F7F_FFFF,
    ];
    let mut triples32: Vec<[u32; 3]> = Vec::new();
    for &a in &f32s {
        for &b in &f32s {
            for &c in &f32s {
                triples32.push([a, b, c]);
            }
        }
    }
    for _ in 0..1000 {
        let a = rng.next() as u32 & 0xBFFF_FFFF;
        let b = rng.next() as u32 & 0xBFFF_FFFF;
        let c = match rng.below(3) {
            0 => rng.next() as u32 & 0xBFFF_FFFF,
            // Near cancellation: c ≈ -(a * b).
            1 => (-(f32b(a) * f32b(b))).to_bits() ^ (rng.next() as u32 & 3),
            // Halfway cases.
            _ => (f32b(a) as f64 * f32b(b) as f64) as f32 as u32 ^ 0x8000_0000,
        };
        triples32.push([a, b, c]);
    }
    // Subnormal results.
    for _ in 0..200 {
        let a = (rng.next() as u32 & 0x807F_FFFF) | ((rng.next() % 40 + 40) as u32) << 23;
        let b = (rng.next() as u32 & 0x807F_FFFF) | ((rng.next() % 40 + 30) as u32) << 23;
        let c = rng.next() as u32 & 0x80FF_FFFF;
        triples32.push([a, b, c]);
    }
    for chunk in triples32.chunks(4) {
        let mut lanes = [[0u32; 4]; 3];
        for (i, t) in chunk.iter().enumerate() {
            for k in 0..3 {
                lanes[k][i] = t[k];
            }
        }
        let pack = |l: [u32; 4]| {
            v128(l.iter().enumerate().fold(0u128, |acc, (i, &x)| acc | (x as u128) << (32 * i)))
        };
        let (a, b, c) = (pack(lanes[0]), pack(lanes[1]), pack(lanes[2]));
        let args = [hv(a), hv(b), hv(c)];
        out.line("f32x4_relaxed_madd", &args, hv(simd::f32x4_relaxed_madd(a, b, c)));
        out.line("f32x4_relaxed_nmadd", &args, hv(simd::f32x4_relaxed_nmadd(a, b, c)));
    }
    let f64s: Vec<u64> = vec![
        0,
        0x8000_0000_0000_0000,
        1.0f64.to_bits(),
        (-1.0f64).to_bits(),
        0x7FF0_0000_0000_0000,
        0xFFF0_0000_0000_0000,
        0x7FF8_0000_0000_0000,
        0xFFF8_0000_0012_3456,
        0x7FF0_0000_0000_0001,
        0xFFF4_0000_0000_0005,
        1,
    ];
    let mut triples64: Vec<[u64; 3]> = Vec::new();
    for &a in &f64s {
        for &b in &f64s {
            for &c in &f64s {
                triples64.push([a, b, c]);
            }
        }
    }
    for _ in 0..1000 {
        let a = rng.next() & 0xBFFF_FFFF_FFFF_FFFF;
        let b = rng.next() & 0xBFFF_FFFF_FFFF_FFFF;
        let c = match rng.below(3) {
            0 => rng.next() & 0xBFFF_FFFF_FFFF_FFFF,
            1 => (-(f64b(a) * f64b(b))).to_bits() ^ (rng.next() & 0xFFFF),
            _ => (-(f64b(a) * f64b(b))).to_bits() ^ (rng.next() & 0xF_FFFF_FFFF),
        };
        triples64.push([a, b, c]);
    }
    for _ in 0..300 {
        let a = (rng.next() & 0x800F_FFFF_FFFF_FFFF) | (rng.next() % 600 + 200) << 52;
        let b = (rng.next() & 0x800F_FFFF_FFFF_FFFF) | (rng.next() % 600 + 30) << 52;
        let c = rng.next() & 0x801F_FFFF_FFFF_FFFF;
        triples64.push([a, b, c]);
    }
    for chunk in triples64.chunks(2) {
        let pack = |k: usize| {
            let lo = chunk[0][k] as u128;
            let hi = chunk.get(1).map(|t| t[k]).unwrap_or(0) as u128;
            v128(lo | hi << 64)
        };
        let (a, b, c) = (pack(0), pack(1), pack(2));
        let args = [hv(a), hv(b), hv(c)];
        out.line("f64x2_relaxed_madd", &args, hv(simd::f64x2_relaxed_madd(a, b, c)));
        out.line("f64x2_relaxed_nmadd", &args, hv(simd::f64x2_relaxed_nmadd(a, b, c)));
    }
}

// SIMD.

/// A V128 generator mixing lane kinds.
fn gen_v128(rng: &mut Rng, f32s: &[u32], f64s: &[u64]) -> u128 {
    let bytes = [0x00u8, 0x01, 0x02, 0x7E, 0x7F, 0x80, 0x81, 0xFE, 0xFF];
    let halves = [0x0000u16, 0x0001, 0x7FFF, 0x8000, 0x8001, 0xFFFF, 0xFFFE, 0x00FF, 0x0100, 0x4000];
    let words = [0u32, 1, 0x7FFF_FFFF, 0x8000_0000, 0xFFFF_FFFF, 0x0000_8000, 0xFFFF_7FFF, 0x0001_0000];
    match rng.below(7) {
        0 => (rng.next() as u128) << 64 | rng.next() as u128,
        1 => (0..16).fold(0, |acc, i| acc | (bytes[rng.below(bytes.len())] as u128) << (8 * i)),
        2 => (0..8).fold(0, |acc, i| acc | (halves[rng.below(halves.len())] as u128) << (16 * i)),
        3 => (0..4).fold(0, |acc, i| acc | (words[rng.below(words.len())] as u128) << (32 * i)),
        4 | 5 => (0..4).fold(0, |acc, i| acc | (f32s[rng.below(f32s.len())] as u128) << (32 * i)),
        _ => (0..2).fold(0, |acc, i| acc | (f64s[rng.below(f64s.len())] as u128) << (64 * i)),
    }
}

/// `rhs` derived from `lhs` (equal lanes in places) or independent.
fn gen_rhs(rng: &mut Rng, lhs: u128, f32s: &[u32], f64s: &[u64]) -> u128 {
    match rng.below(4) {
        0 => {
            let mask: u128 = (0..16).fold(0, |acc, i| {
                acc | (if rng.below(2) == 0 { 0xFFu128 } else { 0 }) << (8 * i)
            });
            (lhs & mask) | (gen_v128(rng, f32s, f64s) & !mask)
        }
        1 => {
            let mask: u128 = (0..4).fold(0, |acc, i| {
                acc | (if rng.below(2) == 0 { 0xFFFF_FFFFu128 } else { 0 }) << (32 * i)
            });
            (lhs & mask) | (gen_v128(rng, f32s, f64s) & !mask)
        }
        _ => gen_v128(rng, f32s, f64s),
    }
}

const SIMD_CASES: usize = 48;

fn gen_simd(out: &mut Out, rng: &mut Rng) {
    let f32s = f32_small_pool(rng);
    let f64s = f64_small_pool(rng);
    let f32s = &f32s[..];
    let f64s = &f64s[..];
    macro_rules! unary {
        ($($name:ident),* $(,)?) => {$(
            for _ in 0..SIMD_CASES {
                let a = v128(gen_v128(rng, f32s, f64s));
                out.line(stringify!($name), &[hv(a)], hv(simd::$name(a)));
            }
        )*};
    }
    unary! {
        i64x2_neg, i32x4_neg, i16x8_neg, i8x16_neg, i8x16_abs, i16x8_abs, i32x4_abs, i64x2_abs,
        v128_not, i8x16_popcnt, f32x4_neg, f64x2_neg, f32x4_abs, f64x2_abs, f32x4_sqrt,
        f64x2_sqrt, f32x4_ceil, f64x2_ceil, f32x4_floor, f64x2_floor, f32x4_trunc, f64x2_trunc,
        f32x4_nearest, f64x2_nearest, f32x4_convert_i32x4_s, f32x4_convert_i32x4_u,
        i32x4_trunc_sat_f32x4_s, i32x4_trunc_sat_f32x4_u, i16x8_extend_low_i8x16_s,
        i16x8_extend_low_i8x16_u, i32x4_extend_low_i16x8_s, i32x4_extend_low_i16x8_u,
        i64x2_extend_low_i32x4_s, i64x2_extend_low_i32x4_u, f64x2_convert_low_i32x4_s,
        f64x2_convert_low_i32x4_u, f64x2_promote_low_f32x4, i16x8_extend_high_i8x16_s,
        i16x8_extend_high_i8x16_u, i32x4_extend_high_i16x8_s, i32x4_extend_high_i16x8_u,
        i64x2_extend_high_i32x4_s, i64x2_extend_high_i32x4_u, i16x8_extadd_pairwise_i8x16_s,
        i16x8_extadd_pairwise_i8x16_u, i32x4_extadd_pairwise_i16x8_s,
        i32x4_extadd_pairwise_i16x8_u, i32x4_trunc_sat_f64x2_s_zero,
        i32x4_trunc_sat_f64x2_u_zero, f32x4_demote_f64x2_zero, i32x4_relaxed_trunc_f32x4_s,
        i32x4_relaxed_trunc_f32x4_u, i32x4_relaxed_trunc_f64x2_s_zero,
        i32x4_relaxed_trunc_f64x2_u_zero,
    }
    macro_rules! reduce {
        ($($name:ident => $fmt:ident),* $(,)?) => {$(
            for _ in 0..SIMD_CASES {
                let a = v128(gen_v128(rng, f32s, f64s));
                out.line(stringify!($name), &[hv(a)], $fmt(simd::$name(a)));
            }
        )*};
    }
    reduce! {
        i8x16_all_true => hb, i16x8_all_true => hb, i32x4_all_true => hb, i64x2_all_true => hb,
        i8x16_bitmask => h32, i16x8_bitmask => h32, i32x4_bitmask => h32, i64x2_bitmask => h32,
        v128_any_true => hb,
    }
    for a in [0u128, 1 << 127, 0x0101_0101_0101_0101_0101_0101_0101_0101] {
        let a = v128(a);
        for (name, r) in [
            ("i8x16_all_true", simd::i8x16_all_true(a)),
            ("i16x8_all_true", simd::i16x8_all_true(a)),
            ("i32x4_all_true", simd::i32x4_all_true(a)),
            ("i64x2_all_true", simd::i64x2_all_true(a)),
            ("v128_any_true", simd::v128_any_true(a)),
        ] {
            out.line(name, &[hv(a)], hb(r));
        }
    }
    macro_rules! binary {
        ($($name:ident),* $(,)?) => {$(
            for _ in 0..SIMD_CASES {
                let a = gen_v128(rng, f32s, f64s);
                let b = v128(gen_rhs(rng, a, f32s, f64s));
                let a = v128(a);
                out.line(stringify!($name), &[hv(a), hv(b)], hv(simd::$name(a, b)));
            }
        )*};
    }
    binary! {
        i8x16_swizzle, i8x16_relaxed_swizzle, i64x2_add, i32x4_add, i16x8_add, i8x16_add,
        i64x2_sub, i32x4_sub, i16x8_sub, i8x16_sub, i64x2_mul, i32x4_mul, i16x8_mul, i8x16_mul,
        i8x16_add_sat_s, i8x16_add_sat_u, i16x8_add_sat_s, i16x8_add_sat_u, i8x16_sub_sat_s,
        i8x16_sub_sat_u, i16x8_sub_sat_s, i16x8_sub_sat_u, i16x8_q15mulr_sat_s,
        i16x8_relaxed_q15mulr_s, i8x16_min_s, i8x16_min_u, i16x8_min_s, i16x8_min_u, i32x4_min_s,
        i32x4_min_u, i8x16_max_s, i8x16_max_u, i16x8_max_s, i16x8_max_u, i32x4_max_s,
        i32x4_max_u, i8x16_avgr_u, i16x8_avgr_u, v128_and, v128_or, v128_xor, v128_andnot,
        f32x4_min, f64x2_min, f32x4_max, f64x2_max, f32x4_relaxed_min, f32x4_relaxed_max,
        f64x2_relaxed_min, f64x2_relaxed_max, f32x4_pmin, f64x2_pmin, f32x4_pmax, f64x2_pmax,
        f32x4_add, f64x2_add, f32x4_sub, f64x2_sub, f32x4_div, f64x2_div, f32x4_mul, f64x2_mul,
        i8x16_eq, i16x8_eq, i32x4_eq, i64x2_eq, f32x4_eq, f64x2_eq, i8x16_ne, i16x8_ne, i32x4_ne,
        i64x2_ne, f32x4_ne, f64x2_ne, i8x16_lt_s, i8x16_lt_u, i16x8_lt_s, i16x8_lt_u, i32x4_lt_s,
        i32x4_lt_u, i64x2_lt_s, f32x4_lt, f64x2_lt, i8x16_le_s, i8x16_le_u, i16x8_le_s,
        i16x8_le_u, i32x4_le_s, i32x4_le_u, i64x2_le_s, f32x4_le, f64x2_le, i8x16_gt_s,
        i8x16_gt_u, i16x8_gt_s, i16x8_gt_u, i32x4_gt_s, i32x4_gt_u, i64x2_gt_s, f32x4_gt,
        f64x2_gt, i8x16_ge_s, i8x16_ge_u, i16x8_ge_s, i16x8_ge_u, i32x4_ge_s, i32x4_ge_u,
        i64x2_ge_s, f32x4_ge, f64x2_ge, i16x8_extmul_low_i8x16_s, i16x8_extmul_low_i8x16_u,
        i32x4_extmul_low_i16x8_s, i32x4_extmul_low_i16x8_u, i64x2_extmul_low_i32x4_s,
        i64x2_extmul_low_i32x4_u, i16x8_extmul_high_i8x16_s, i16x8_extmul_high_i8x16_u,
        i32x4_extmul_high_i16x8_s, i32x4_extmul_high_i16x8_u, i64x2_extmul_high_i32x4_s,
        i64x2_extmul_high_i32x4_u, i8x16_narrow_i16x8_s, i8x16_narrow_i16x8_u,
        i16x8_narrow_i32x4_s, i16x8_narrow_i32x4_u, i32x4_dot_i16x8_s,
        i16x8_relaxed_dot_i8x16_i7x16_s,
    }
    // Swizzle with in-range selectors.
    for _ in 0..SIMD_CASES {
        let a = v128(gen_v128(rng, f32s, f64s));
        let s = v128((0..16).fold(0u128, |acc, i| acc | ((rng.below(20) as u128) << (8 * i))));
        out.line("i8x16_swizzle", &[hv(a), hv(s)], hv(simd::i8x16_swizzle(a, s)));
    }
    macro_rules! ternary {
        ($($name:ident),* $(,)?) => {$(
            for _ in 0..SIMD_CASES {
                let a = v128(gen_v128(rng, f32s, f64s));
                let b = v128(gen_v128(rng, f32s, f64s));
                let c = v128(gen_v128(rng, f32s, f64s));
                out.line(stringify!($name), &[hv(a), hv(b), hv(c)], hv(simd::$name(a, b, c)));
            }
        )*};
    }
    ternary! {
        v128_bitselect, i8x16_relaxed_laneselect, i16x8_relaxed_laneselect,
        i32x4_relaxed_laneselect, i64x2_relaxed_laneselect, i32x4_relaxed_dot_i8x16_i7x16_add_s,
    }
    let shifts: [u32; 14] = [0, 1, 7, 8, 9, 15, 16, 31, 32, 33, 63, 64, 65, u32::MAX];
    macro_rules! shift {
        ($($name:ident),* $(,)?) => {$(
            for &n in &shifts {
                for _ in 0..3 {
                    let a = v128(gen_v128(rng, f32s, f64s));
                    out.line(stringify!($name), &[hv(a), h32(n)], hv(simd::$name(a, n)));
                }
            }
        )*};
    }
    shift! {
        i8x16_shl, i16x8_shl, i32x4_shl, i64x2_shl, i8x16_shr_s, i8x16_shr_u, i16x8_shr_s,
        i16x8_shr_u, i32x4_shr_s, i32x4_shr_u, i64x2_shr_s, i64x2_shr_u,
    }
    // Splat / extract / replace.
    for _ in 0..SIMD_CASES {
        let x = rng.next();
        let fx32 = f32s[rng.below(f32s.len())];
        let fx64 = f64s[rng.below(f64s.len())];
        out.line("i64x2_splat", &[h64(x)], hv(simd::i64x2_splat(x as i64)));
        out.line("i32x4_splat", &[h32(x as u32)], hv(simd::i32x4_splat(x as i32)));
        out.line("i16x8_splat", &[h32(x as i16 as i32 as u32)], hv(simd::i16x8_splat(x as i16)));
        out.line("i8x16_splat", &[h32(x as i8 as i32 as u32)], hv(simd::i8x16_splat(x as i8)));
        out.line("f32x4_splat", &[h32(fx32)], hv(simd::f32x4_splat(f32b(fx32))));
        out.line("f64x2_splat", &[h64(fx64)], hv(simd::f64x2_splat(f64b(fx64))));
    }
    for _ in 0..8 {
        let a = v128(gen_v128(rng, f32s, f64s));
        let x = rng.next();
        for lane in 0..16u8 {
            let l16 = ImmLaneIdx16::try_from(lane).ok().unwrap();
            let args = [hv(a), h32(lane as u32)];
            out.line("i8x16_extract_lane_s", &args, h32(simd::i8x16_extract_lane_s(a, l16) as u32));
            out.line("i8x16_extract_lane_u", &args, h32(simd::i8x16_extract_lane_u(a, l16)));
            out.line(
                "i8x16_replace_lane",
                &[hv(a), h32(lane as u32), h32(x as i8 as i32 as u32)],
                hv(simd::i8x16_replace_lane(a, l16, x as i8)),
            );
        }
        for lane in 0..8u8 {
            let l8 = ImmLaneIdx8::try_from(lane).ok().unwrap();
            let args = [hv(a), h32(lane as u32)];
            out.line("i16x8_extract_lane_s", &args, h32(simd::i16x8_extract_lane_s(a, l8) as u32));
            out.line("i16x8_extract_lane_u", &args, h32(simd::i16x8_extract_lane_u(a, l8)));
            out.line(
                "i16x8_replace_lane",
                &[hv(a), h32(lane as u32), h32(x as i16 as i32 as u32)],
                hv(simd::i16x8_replace_lane(a, l8, x as i16)),
            );
        }
        for lane in 0..4u8 {
            let l4 = ImmLaneIdx4::try_from(lane).ok().unwrap();
            let args = [hv(a), h32(lane as u32)];
            out.line("i32x4_extract_lane", &args, h32(simd::i32x4_extract_lane(a, l4) as u32));
            out.line(
                "f32x4_extract_lane",
                &args,
                h32(simd::f32x4_extract_lane(a, l4).to_bits()),
            );
            out.line(
                "i32x4_replace_lane",
                &[hv(a), h32(lane as u32), h32(x as u32)],
                hv(simd::i32x4_replace_lane(a, l4, x as i32)),
            );
            out.line(
                "f32x4_replace_lane",
                &[hv(a), h32(lane as u32), h32(x as u32)],
                hv(simd::f32x4_replace_lane(a, l4, f32b(x as u32))),
            );
        }
        for lane in 0..2u8 {
            let l2 = ImmLaneIdx2::try_from(lane).ok().unwrap();
            let args = [hv(a), h32(lane as u32)];
            out.line("i64x2_extract_lane", &args, h64(simd::i64x2_extract_lane(a, l2) as u64));
            out.line(
                "f64x2_extract_lane",
                &args,
                h64(simd::f64x2_extract_lane(a, l2).to_bits()),
            );
            out.line(
                "i64x2_replace_lane",
                &[hv(a), h32(lane as u32), h64(x)],
                hv(simd::i64x2_replace_lane(a, l2, x as i64)),
            );
            out.line(
                "f64x2_replace_lane",
                &[hv(a), h32(lane as u32), h64(x)],
                hv(simd::f64x2_replace_lane(a, l2, f64b(x))),
            );
        }
    }
    // Shuffle.
    for _ in 0..SIMD_CASES {
        let a = v128(gen_v128(rng, f32s, f64s));
        let b = v128(gen_v128(rng, f32s, f64s));
        let sel: [u8; 16] = std::array::from_fn(|_| rng.below(32) as u8);
        let s: [ImmLaneIdx32; 16] = sel.map(|l| ImmLaneIdx32::try_from(l).ok().unwrap());
        let sel_hex: String = sel.iter().map(|b| format!("{b:02x}")).collect();
        out.line("i8x16_shuffle", &[hv(a), hv(b), sel_hex], hv(simd::i8x16_shuffle(a, b, s)));
    }
    // Lane index validation.
    for lane in 0..=33u8 {
        let ok = |b: bool| hb(b);
        out.line("lane_idx", &["2".into(), h32(lane as u32)], ok(ImmLaneIdx2::try_from(lane).is_ok()));
        out.line("lane_idx", &["4".into(), h32(lane as u32)], ok(ImmLaneIdx4::try_from(lane).is_ok()));
        out.line("lane_idx", &["8".into(), h32(lane as u32)], ok(ImmLaneIdx8::try_from(lane).is_ok()));
        out.line("lane_idx", &["16".into(), h32(lane as u32)], ok(ImmLaneIdx16::try_from(lane).is_ok()));
        out.line("lane_idx", &["32".into(), h32(lane as u32)], ok(ImmLaneIdx32::try_from(lane).is_ok()));
    }
}

// Linear memory accessors.

const MEM_LEN: usize = 40;

fn mem_init() -> Vec<u8> {
    (0..MEM_LEN).map(|i| (i * 37 + 11) as u8).collect()
}

fn hmem(m: &[u8]) -> String {
    m.iter().map(|b| format!("{b:02x}")).collect()
}

fn gen_memory_access(out: &mut Out, rng: &mut Rng) {
    let ptrs: [u64; 14] = [0, 1, 7, 15, 16, 24, 25, 28, 31, 32, 36, 39, 40, 41];
    let big: [u64; 5] = [u32::MAX as u64, u64::MAX, u64::MAX - 3, 1 << 32, 1 << 63];
    let offsets: [u64; 5] = [0, 1, 8, 24, u64::MAX];
    let mut pairs: Vec<(u64, u64)> = Vec::new();
    for &p in &ptrs {
        for &o in &offsets[..4] {
            pairs.push((p, o));
        }
    }
    for &p in &big {
        for &o in &offsets {
            pairs.push((p, o));
        }
    }
    for &p in &ptrs[..3] {
        pairs.push((p, u64::MAX));
        pairs.push((p, u64::MAX - p));
    }
    let mem = mem_init();
    macro_rules! load {
        ($($name:ident, $at:ident => $fmt:expr;)*) => {$(
            for &(p, o) in &pairs {
                let r = wasm::$name(&mem, p, o);
                out.line(stringify!($name), &[h64(p), h64(o)], r.map($fmt).unwrap_or_else(trap));
            }
            for &(p, o) in &pairs {
                let a = p.wrapping_add(o);
                let r = wasm::$at(&mem, a as usize);
                out.line(stringify!($at), &[h64(a)], r.map($fmt).unwrap_or_else(trap));
            }
        )*};
    }
    load! {
        i32_load8_s, i32_load8_s_at => |v: i32| h32(v as u32);
        i32_load8_u, i32_load8_u_at => |v: i32| h32(v as u32);
        i32_load16_s, i32_load16_s_at => |v: i32| h32(v as u32);
        i32_load16_u, i32_load16_u_at => |v: i32| h32(v as u32);
        i64_load8_s, i64_load8_s_at => |v: i64| h64(v as u64);
        i64_load8_u, i64_load8_u_at => |v: i64| h64(v as u64);
        i64_load16_s, i64_load16_s_at => |v: i64| h64(v as u64);
        i64_load16_u, i64_load16_u_at => |v: i64| h64(v as u64);
        i64_load32_s, i64_load32_s_at => |v: i64| h64(v as u64);
        i64_load32_u, i64_load32_u_at => |v: i64| h64(v as u64);
        load32, load32_at => h32;
        load64, load64_at => h64;
    }
    macro_rules! simd_load {
        ($($name:ident, $at:ident;)*) => {$(
            for &(p, o) in &pairs {
                let r = simd::$name(&mem, p, o);
                out.line(stringify!($name), &[h64(p), h64(o)], r.map(hv).unwrap_or_else(trap));
            }
            for &(p, o) in &pairs {
                let a = p.wrapping_add(o);
                let r = simd::$at(&mem, a as usize);
                out.line(stringify!($at), &[h64(a)], r.map(hv).unwrap_or_else(trap));
            }
        )*};
    }
    simd_load! {
        v128_load, v128_load_at;
        v128_load32_zero, v128_load32_zero_at;
        v128_load64_zero, v128_load64_zero_at;
        v128_load8_splat, v128_load8_splat_at;
        v128_load16_splat, v128_load16_splat_at;
        v128_load32_splat, v128_load32_splat_at;
        v128_load64_splat, v128_load64_splat_at;
        v128_load8x8_s, v128_load8x8_s_at;
        v128_load8x8_u, v128_load8x8_u_at;
        v128_load16x4_s, v128_load16x4_s_at;
        v128_load16x4_u, v128_load16x4_u_at;
        v128_load32x2_s, v128_load32x2_s_at;
        v128_load32x2_u, v128_load32x2_u_at;
    }
    let x = v128(0x0011_2233_4455_6677_8899_AABB_CCDD_EEFF);
    macro_rules! lane_load {
        ($($name:ident, $at:ident, $idx:ident, $n:expr;)*) => {$(
            for &(p, o) in &pairs {
                let lane = rng.below($n) as u8;
                let l = $idx::try_from(lane).ok().unwrap();
                let r = simd::$name(&mem, p, o, x, l);
                out.line(stringify!($name), &[h64(p), h64(o), hv(x), h32(lane as u32)], r.map(hv).unwrap_or_else(trap));
                let a = p.wrapping_add(o);
                let r = simd::$at(&mem, a as usize, x, l);
                out.line(stringify!($at), &[h64(a), hv(x), h32(lane as u32)], r.map(hv).unwrap_or_else(trap));
            }
        )*};
    }
    lane_load! {
        v128_load8_lane, v128_load8_lane_at, ImmLaneIdx16, 16;
        v128_load16_lane, v128_load16_lane_at, ImmLaneIdx8, 8;
        v128_load32_lane, v128_load32_lane_at, ImmLaneIdx4, 4;
        v128_load64_lane, v128_load64_lane_at, ImmLaneIdx2, 2;
    }
    let value = rng.next();
    macro_rules! store {
        ($($name:ident, $at:ident, $val:expr, $arg:expr;)*) => {$(
            for &(p, o) in &pairs {
                let mut m = mem_init();
                let r = wasm::$name(&mut m, p, o, $val);
                let res = match r { Ok(()) => hmem(&m), Err(t) => format!("{}:{}", trap(t), hmem(&m)) };
                out.line(stringify!($name), &[h64(p), h64(o), $arg], res);
                let a = p.wrapping_add(o);
                let mut m = mem_init();
                let r = wasm::$at(&mut m, a as usize, $val);
                let res = match r { Ok(()) => hmem(&m), Err(t) => format!("{}:{}", trap(t), hmem(&m)) };
                out.line(stringify!($at), &[h64(a), $arg], res);
            }
        )*};
    }
    store! {
        i32_store8, i32_store8_at, value as i32, h32(value as u32);
        i32_store16, i32_store16_at, value as i32, h32(value as u32);
        i64_store8, i64_store8_at, value as i64, h64(value);
        i64_store16, i64_store16_at, value as i64, h64(value);
        i64_store32, i64_store32_at, value as i64, h64(value);
        store32, store32_at, value as u32, h32(value as u32);
        store64, store64_at, value, h64(value);
    }
    let vx = v128(((rng.next() as u128) << 64) | rng.next() as u128);
    for &(p, o) in &pairs {
        let mut m = mem_init();
        let r = simd::v128_store(&mut m, p, o, vx);
        let res = match r {
            Ok(()) => hmem(&m),
            Err(t) => format!("{}:{}", trap(t), hmem(&m)),
        };
        out.line("v128_store", &[h64(p), h64(o), hv(vx)], res);
        let a = p.wrapping_add(o);
        let mut m = mem_init();
        let r = simd::v128_store_at(&mut m, a as usize, vx);
        let res = match r {
            Ok(()) => hmem(&m),
            Err(t) => format!("{}:{}", trap(t), hmem(&m)),
        };
        out.line("v128_store_at", &[h64(a), hv(vx)], res);
    }
    macro_rules! lane_store {
        ($($name:ident, $at:ident, $idx:ident, $n:expr;)*) => {$(
            for &(p, o) in &pairs {
                let lane = rng.below($n) as u8;
                let l = $idx::try_from(lane).ok().unwrap();
                let mut m = mem_init();
                let r = simd::$name(&mut m, p, o, vx, l);
                let res = match r { Ok(()) => hmem(&m), Err(t) => format!("{}:{}", trap(t), hmem(&m)) };
                out.line(stringify!($name), &[h64(p), h64(o), hv(vx), h32(lane as u32)], res);
                let a = p.wrapping_add(o);
                let mut m = mem_init();
                let r = simd::$at(&mut m, a as usize, vx, l);
                let res = match r { Ok(()) => hmem(&m), Err(t) => format!("{}:{}", trap(t), hmem(&m)) };
                out.line(stringify!($at), &[h64(a), hv(vx), h32(lane as u32)], res);
            }
        )*};
    }
    lane_store! {
        v128_store8_lane, v128_store8_lane_at, ImmLaneIdx16, 16;
        v128_store16_lane, v128_store16_lane_at, ImmLaneIdx8, 8;
        v128_store32_lane, v128_store32_lane_at, ImmLaneIdx4, 4;
        v128_store64_lane, v128_store64_lane_at, ImmLaneIdx2, 2;
    }
}

// Memory and table scenarios.

/// A resource limiter that allows growth up to `limit` (bytes or elements)
/// and either denies (`Ok(false)`) or errors beyond it. Logs its calls.
struct Limiter {
    limit: usize,
    error: bool,
    log: Vec<String>,
}

impl ResourceLimiter for Limiter {
    fn memory_growing(
        &mut self,
        current: usize,
        desired: usize,
        maximum: Option<usize>,
    ) -> Result<bool, LimiterError> {
        self.log.push(format!("mg({current},{desired},{})", opt(maximum.map(|m| m as u64))));
        if desired <= self.limit {
            Ok(true)
        } else if self.error {
            Err(LimiterError::ResourceLimiterDeniedAllocation)
        } else {
            Ok(false)
        }
    }
    fn table_growing(
        &mut self,
        current: usize,
        desired: usize,
        maximum: Option<usize>,
    ) -> Result<bool, LimiterError> {
        self.log.push(format!("tg({current},{desired},{})", opt(maximum.map(|m| m as u64))));
        if desired <= self.limit {
            Ok(true)
        } else if self.error {
            Err(LimiterError::OutOfBoundsGrowth)
        } else {
            Ok(false)
        }
    }
    fn memory_grow_failed(&mut self, error: &LimiterError) {
        self.log.push(format!("mgf({error})"));
    }
    fn table_grow_failed(&mut self, error: &LimiterError) {
        self.log.push(format!("tgf({error})"));
    }
    fn instances(&self) -> usize {
        1
    }
    fn tables(&self) -> usize {
        1
    }
    fn memories(&self) -> usize {
        1
    }
}

fn opt(v: Option<u64>) -> String {
    v.map(|v| v.to_string()).unwrap_or_else(|| "-".into())
}

/// Parses a limiter spec: `-` (none) or `<limit>:<ok|err>`.
fn limiter_of(spec: &str) -> Option<Limiter> {
    let (limit, mode) = spec.split_once(':')?;
    Some(Limiter { limit: limit.parse().unwrap(), error: mode == "err", log: Vec::new() })
}

fn drain(log: &mut Vec<String>, t: &mut Vec<String>) {
    t.append(log);
}

fn run_memory(
    min: u64,
    max: Option<u64>,
    log2: u8,
    m64: bool,
    limiter: &str,
    ops: &[String],
) -> String {
    let mut t: Vec<String> = Vec::new();
    let mut b = MemoryType::builder();
    b.min(min);
    b.max(max);
    b.page_size_log2(log2);
    b.memory64(m64);
    let ty = match b.build() {
        Ok(ty) => ty,
        Err(e) => return format!("ty!{e}"),
    };
    t.push(format!(
        "ty({},{},{},{})",
        ty.minimum(),
        opt(ty.maximum()),
        ty.page_size(),
        hb(ty.is_64())
    ));
    let mut lim = limiter_of(limiter);
    let mut mem = {
        let mut lref = match lim.as_mut() {
            Some(l) => ResourceLimiterRef::from(l as &mut dyn ResourceLimiter),
            None => ResourceLimiterRef::default(),
        };
        match Memory::new(ty, &mut lref) {
            Ok(m) => m,
            Err(e) => {
                drop(lref);
                if let Some(l) = lim.as_mut() {
                    drain(&mut l.log, &mut t);
                }
                t.push(format!("new!{e}"));
                return t.join(";");
            }
        }
    };
    if let Some(l) = lim.as_mut() {
        drain(&mut l.log, &mut t);
    }
    t.push(format!("new={}", mem.size()));
    for op in ops {
        let parts: Vec<&str> = op.split(':').collect();
        let mut lref = match lim.as_mut() {
            Some(l) => ResourceLimiterRef::from(l as &mut dyn ResourceLimiter),
            None => ResourceLimiterRef::default(),
        };
        let res = match parts[0] {
            "g" => {
                let delta: u64 = parts[1].parse().unwrap();
                match mem.grow(delta, None, &mut lref) {
                    Ok(old) => format!("g={old}"),
                    Err(e) => format!("g!{e}"),
                }
            }
            "gf" => {
                let delta: u64 = parts[1].parse().unwrap();
                let mut fuel = Fuel::new(true, FuelCostsProvider::default());
                fuel.set_fuel(parts[2].parse().unwrap()).unwrap();
                match mem.grow(delta, Some(&mut fuel), &mut lref) {
                    Ok(old) => format!("g={old},fuel={}", fuel.get_fuel().unwrap()),
                    Err(e) => format!("g!{e}"),
                }
            }
            "r" => {
                let off: usize = parts[1].parse().unwrap();
                let mut buf = vec![0u8; parts[2].parse().unwrap()];
                match mem.read(off, &mut buf) {
                    Ok(()) => format!("r={}", hmem(&buf)),
                    Err(e) => format!("r!{e}"),
                }
            }
            "w" => {
                let off: usize = parts[1].parse().unwrap();
                let len: usize = parts[2].parse().unwrap();
                let buf: Vec<u8> = (0..len).map(|i| (i * 13 + 5) as u8).collect();
                match mem.write(off, &buf) {
                    Ok(()) => "w".to_string(),
                    Err(e) => format!("w!{e}"),
                }
            }
            _ => unreachable!(),
        };
        drop(lref);
        if let Some(l) = lim.as_mut() {
            drain(&mut l.log, &mut t);
        }
        t.push(res);
        t.push(format!("sz={},{}", mem.size(), mem.data_size()));
    }
    let dt = mem.dynamic_ty();
    t.push(format!("dyn({},{})", dt.minimum(), opt(dt.maximum())));
    t.join(";")
}

fn gen_memory_scenarios(out: &mut Out) {
    // Memory type validation (no allocation).
    let mins: [u64; 9] = [0, 1, 3, 65536, 65537, 1 << 48, (1 << 48) + 1, 1 << 32, u64::MAX];
    let maxs: [Option<u64>; 8] =
        [None, Some(0), Some(2), Some(65536), Some(65537), Some(1 << 48), Some(1 << 32), Some(u64::MAX)];
    for &log2 in &[16u8, 0, 1] {
        for &m64 in &[false, true] {
            for &min in &mins {
                for &max in &maxs {
                    let mut b = MemoryType::builder();
                    b.min(min);
                    b.max(max);
                    b.page_size_log2(log2);
                    b.memory64(m64);
                    let res = match b.build() {
                        Ok(ty) => {
                            format!("ok({},{},{})", ty.minimum(), opt(ty.maximum()), ty.page_size())
                        }
                        Err(e) => format!("err({e})"),
                    };
                    out.line(
                        "memory_type",
                        &[min.to_string(), opt(max), log2.to_string(), hb(m64)],
                        res,
                    );
                }
            }
        }
    }
    // Subtyping.
    let tys: Vec<(u64, Option<u64>, u8, bool)> = vec![
        (0, Some(1), 16, false),
        (0, Some(2), 16, false),
        (2, None, 16, false),
        (1, None, 16, false),
        (0, None, 16, false),
        (0, Some(1), 16, true),
        (0, Some(1), 0, false),
        (1, Some(1), 16, false),
    ];
    for a in &tys {
        for b in &tys {
            let mk = |t: &(u64, Option<u64>, u8, bool)| {
                let mut bld = MemoryType::builder();
                bld.min(t.0);
                bld.max(t.1);
                bld.page_size_log2(t.2);
                bld.memory64(t.3);
                bld.build().unwrap()
            };
            let args = [
                a.0.to_string(),
                opt(a.1),
                a.2.to_string(),
                hb(a.3),
                b.0.to_string(),
                opt(b.1),
                b.2.to_string(),
                hb(b.3),
            ];
            out.line("memory_subtype", &args, hb(mk(a).is_subtype_of(&mk(b))));
        }
    }
    // Memory creation and growth (only scenarios that never allocate more
    // than a few pages).
    struct S(u64, Option<u64>, u8, bool, &'static str, &'static [&'static str]);
    let scenarios: Vec<S> = vec![
        S(0, None, 16, false, "-", &["g:0", "g:1", "g:2", "g:65534", "g:65536", "g:18446744073709551615", "r:0:4", "w:65530:6", "r:65530:6", "w:65535:2", "r:196607:2", "r:196608:0", "r:196609:0", "r:18446744073709551615:2"]),
        S(1, Some(3), 16, false, "-", &["g:1", "g:2", "g:1", "g:0", "w:131070:2", "r:131068:4"]),
        S(1, Some(3), 16, false, "131072:ok", &["g:1", "g:1", "g:1"]),
        S(1, Some(3), 16, false, "131072:err", &["g:1", "g:1"]),
        S(2, None, 16, false, "65536:ok", &[]),
        S(2, None, 16, false, "65536:err", &[]),
        S(0, Some(5), 16, false, "1000000:ok", &["g:2", "g:4", "g:3", "g:1"]),
        S(0, None, 16, true, "-", &["g:1", "g:281474976710655", "g:281474976710656", "g:18446744073709551615"]),
        S(0, Some(10), 0, false, "-", &["g:3", "g:7", "g:1", "w:8:2", "r:5:5"]),
        S(5, None, 0, false, "-", &["g:4294967292", "g:4294967293", "g:7", "r:0:12"]),
        S(0, None, 0, true, "-", &["g:18446744073709551615", "g:9", "g:18446744073709551607", "r:7:2"]),
        S(1, None, 16, false, "-", &["gf:1:1024", "gf:1:1023", "gf:0:0", "gf:2:5000"]),
        S(1, None, 16, false, "1000000:ok", &["gf:1:10", "g:1"]),
        S(65536, None, 16, false, "65536:ok", &[]),
        S(65537, None, 16, true, "0:ok", &[]),
        S(281474976710656, None, 16, true, "0:err", &[]),
        S(4294967296, None, 0, false, "0:ok", &[]),
    ];
    for s in &scenarios {
        let ops: Vec<String> = s.5.iter().map(|o| o.to_string()).collect();
        let res = run_memory(s.0, s.1, s.2, s.3, s.4, &ops);
        out.line(
            "memory",
            &[s.0.to_string(), opt(s.1), s.2.to_string(), hb(s.3), s.4.to_string(), ops.join(",")],
            res,
        );
    }
}

fn val_type(s: &str) -> ValType {
    match s {
        "i32" => ValType::I32,
        "i64" => ValType::I64,
        "f32" => ValType::F32,
        "f64" => ValType::F64,
        "v128" => ValType::V128,
        "func" => ValType::FuncRef,
        "extern" => ValType::ExternRef,
        _ => unreachable!(),
    }
}

fn tv(ty: &str, v: &str) -> TypedVal {
    TypedVal::new(val_type(ty), UntypedVal::from(v.parse::<u64>().unwrap()))
}

fn table_dump(table: &Table) -> String {
    (0..table.size())
        .map(|i| table.get_untyped(i).unwrap().to_bits64().to_string())
        .collect::<Vec<_>>()
        .join(" ")
}

fn run_table(
    min: u64,
    max: Option<u64>,
    is64: bool,
    limiter: &str,
    init: &str,
    ops: &[String],
) -> String {
    let mut t: Vec<String> = Vec::new();
    let ty = if is64 {
        TableType::new64(ValType::FuncRef, min, max)
    } else {
        TableType::new(ValType::FuncRef, min as u32, max.map(|m| m as u32))
    };
    let mut lim = limiter_of(limiter);
    let (ity, ival) = init.split_once('=').unwrap();
    let mut table = {
        let mut lref = match lim.as_mut() {
            Some(l) => ResourceLimiterRef::from(l as &mut dyn ResourceLimiter),
            None => ResourceLimiterRef::default(),
        };
        let r = Table::new(ty, tv(ity, ival), &mut lref);
        drop(lref);
        if let Some(l) = lim.as_mut() {
            drain(&mut l.log, &mut t);
        }
        match r {
            Ok(table) => table,
            Err(e) => {
                t.push(format!("new!{e}"));
                return t.join(";");
            }
        }
    };
    t.push(format!("new={}", table.size()));
    let segment = ElementSegment::new(
        ValType::FuncRef,
        [100u64, 101, 102, 103, 104].map(UntypedVal::from),
    );
    let extern_segment = ElementSegment::new(ValType::ExternRef, [UntypedVal::from(9u64)]);
    let mut other = Table::new(
        TableType::new(ValType::FuncRef, 4, None),
        tv("func", "50"),
        &mut ResourceLimiterRef::default(),
    )
    .unwrap();
    for (i, v) in [50u64, 51, 52, 53].iter().enumerate() {
        other.set_untyped(i as u64, UntypedVal::from(*v)).unwrap();
    }
    for op in ops {
        let p: Vec<&str> = op.split(':').collect();
        let num = |i: usize| -> u64 { p[i].parse().unwrap() };
        let mut lref = match lim.as_mut() {
            Some(l) => ResourceLimiterRef::from(l as &mut dyn ResourceLimiter),
            None => ResourceLimiterRef::default(),
        };
        let res = match p[0] {
            "g" => {
                let (ity, ival) = p[2].split_once('=').unwrap();
                match table.grow(num(1), tv(ity, ival), None, &mut lref) {
                    Ok(old) => format!("g={old}"),
                    Err(e) => format!("g!{e}"),
                }
            }
            "gf" => {
                let mut fuel = Fuel::new(true, FuelCostsProvider::default());
                fuel.set_fuel(num(2)).unwrap();
                match table.grow_untyped(num(1), UntypedVal::from(77u64), Some(&mut fuel), &mut lref) {
                    Ok(old) => format!("g={old},fuel={}", fuel.get_fuel().unwrap()),
                    Err(e) => format!("g!{e}"),
                }
            }
            "s" => {
                let (ity, ival) = p[2].split_once('=').unwrap();
                match table.set(num(1), tv(ity, ival)) {
                    Ok(()) => "s".to_string(),
                    Err(e) => format!("s!{e}"),
                }
            }
            "G" => match table.get(num(1)) {
                Some(v) => format!("G={:?},{}", v.ty(), v.untyped().to_bits64()),
                None => "G=-".to_string(),
            },
            "f" => {
                let (ity, ival) = p[2].split_once('=').unwrap();
                match table.fill(num(1), tv(ity, ival), num(3), None) {
                    Ok(()) => "f".to_string(),
                    Err(e) => format!("f!{e}"),
                }
            }
            "c" => match table.copy_within(num(1), num(2), num(3), None) {
                Ok(()) => "c".to_string(),
                Err(e) => format!("c!{e}"),
            },
            "C" => match Table::copy(&mut table, num(1), &other, num(2), num(3), None) {
                Ok(()) => "C".to_string(),
                Err(e) => format!("C!{e}"),
            },
            "i" => match table.init(segment.as_ref(), num(1), num(2) as u32, num(3) as u32, None) {
                Ok(()) => "i".to_string(),
                Err(e) => format!("i!{e}"),
            },
            "ie" => match table.init(extern_segment.as_ref(), num(1), 0, 1, None) {
                Ok(()) => "i".to_string(),
                Err(e) => format!("i!{e}"),
            },
            "if" => {
                let mut fuel = Fuel::new(true, FuelCostsProvider::default());
                fuel.set_fuel(num(4)).unwrap();
                match table.init(segment.as_ref(), num(1), num(2) as u32, num(3) as u32, Some(&mut fuel)) {
                    Ok(()) => format!("i,fuel={}", fuel.get_fuel().unwrap()),
                    Err(e) => format!("i!{e}"),
                }
            }
            _ => unreachable!(),
        };
        drop(lref);
        if let Some(l) = lim.as_mut() {
            drain(&mut l.log, &mut t);
        }
        t.push(res);
        t.push(format!("[{}]", table_dump(&table)));
    }
    let dt = table.dynamic_ty();
    t.push(format!("dyn({},{})", dt.minimum(), opt(dt.maximum())));
    t.join(";")
}

fn gen_table_scenarios(out: &mut Out) {
    struct S(u64, Option<u64>, bool, &'static str, &'static str, &'static [&'static str]);
    let scenarios: Vec<S> = vec![
        S(2, Some(6), false, "-", "func=1", &["g:0:func=3", "g:2:func=3", "g:3:func=4", "g:2:func=5", "g:1:extern=5", "s:0:func=9", "s:4:func=9", "s:3:i32=9", "G:0", "G:3", "G:4", "G:18446744073709551615", "f:1:func=8:2", "f:3:func=8:2", "f:4:func=8:0", "f:5:func=8:0", "f:0:extern=8:1", "c:0:1:3", "c:1:0:3", "c:2:2:2", "c:3:0:2", "c:4:0:0", "c:5:0:0", "c:18446744073709551615:0:2"]),
        S(3, None, false, "-", "func=0", &["i:0:1:3", "i:1:3:2", "i:2:4:2", "i:3:0:0", "i:4:0:0", "i:0:5:0", "i:0:6:0", "ie:0", "if:0:0:3:100", "if:0:0:3:0", "if:0:0:0:0", "C:0:1:3", "C:1:0:3", "C:2:2:2", "C:3:4:0"]),
        S(1, Some(4), false, "3:ok", "func=1", &["g:1:func=2", "g:1:func=2", "g:5:func=2", "g:1:func=2"]),
        S(1, Some(4), false, "2:err", "func=1", &["g:1:func=2", "g:1:func=2"]),
        S(2, None, false, "1:ok", "func=1", &[]),
        S(2, None, false, "1:err", "func=1", &[]),
        S(0, None, false, "-", "extern=1", &[]),
        S(0, None, false, "-", "func=1", &["g:4294967296:func=1", "g:18446744073709551615:func=1"]),
        S(1, None, true, "-", "func=1", &["g:18446744073709551614:func=1", "g:18446744073709551615:func=1"]),
        S(1, None, false, "-", "func=1", &["gf:3:6", "gf:3:5", "gf:4:2", "gf:0:0"]),
        S(1, Some(2), false, "100:ok", "func=1", &["gf:3:0", "gf:1:0"]),
    ];
    for s in &scenarios {
        let ops: Vec<String> = s.5.iter().map(|o| o.to_string()).collect();
        let res = run_table(s.0, s.1, s.2, s.3, s.4, &ops);
        out.line(
            "table",
            &[s.0.to_string(), opt(s.1), hb(s.2), s.3.to_string(), s.4.to_string(), ops.join(",")],
            res,
        );
    }
    // Table type subtyping.
    let tys: Vec<(&str, u64, Option<u64>, bool)> = vec![
        ("func", 0, Some(1), false),
        ("func", 0, Some(2), false),
        ("func", 2, None, false),
        ("func", 1, None, false),
        ("extern", 0, Some(1), false),
        ("func", 0, Some(1), true),
    ];
    for a in &tys {
        for b in &tys {
            let mk = |t: &(&str, u64, Option<u64>, bool)| {
                if t.3 {
                    TableType::new64(val_type(t.0), t.1, t.2)
                } else {
                    TableType::new(val_type(t.0), t.1 as u32, t.2.map(|m| m as u32))
                }
            };
            let args = [
                a.0.to_string(),
                a.1.to_string(),
                opt(a.2),
                hb(a.3),
                b.0.to_string(),
                b.1.to_string(),
                opt(b.2),
                hb(b.3),
            ];
            out.line("table_subtype", &args, hb(mk(a).is_subtype_of(&mk(b))));
        }
    }
}

// Display / Debug strings.

fn gen_display(out: &mut Out, rng: &mut Rng) {
    for code in 0..=11u8 {
        let res = match TrapCode::try_from(code) {
            Ok(t) => format!("{t}|{}", Trap::from(t)),
            Err(_) => "invalid".to_string(),
        };
        out.line("trap_code", &[code.to_string()], res);
    }
    out.line("trap_message", &[], Trap::new("custom message").to_string());
    out.line("trap_exit", &["3".into()], Trap::i32_exit(3).to_string());
    let memory_errors = [
        MemoryError::OutOfSystemMemory,
        MemoryError::OutOfBoundsGrowth,
        MemoryError::OutOfBoundsAccess,
        MemoryError::InvalidMemoryType,
        MemoryError::InvalidStaticBufferSize,
        MemoryError::ResourceLimiterDeniedAllocation,
        MemoryError::MinimumSizeOverflow,
        MemoryError::MaximumSizeOverflow,
        MemoryError::OutOfFuel { required_fuel: 42 },
    ];
    for (i, e) in memory_errors.iter().enumerate() {
        out.line("memory_error", &[i.to_string()], e.to_string());
    }
    let table_errors = [
        TableError::OutOfSystemMemory,
        TableError::MinimumSizeOverflow,
        TableError::MaximumSizeOverflow,
        TableError::ResourceLimiterDeniedAllocation,
        TableError::GrowOutOfBounds,
        TableError::InitOutOfBounds,
        TableError::FillOutOfBounds,
        TableError::SetOutOfBounds,
        TableError::CopyOutOfBounds,
        TableError::ElementTypeMismatch,
        TableError::OutOfFuel { required_fuel: 7 },
    ];
    for (i, e) in table_errors.iter().enumerate() {
        out.line("table_error", &[i.to_string()], e.to_string());
    }
    let limiter_errors = [
        LimiterError::OutOfSystemMemory,
        LimiterError::OutOfBoundsGrowth,
        LimiterError::ResourceLimiterDeniedAllocation,
        LimiterError::OutOfFuel { required_fuel: 5 },
    ];
    for (i, e) in limiter_errors.iter().enumerate() {
        out.line("limiter_error", &[i.to_string()], e.to_string());
    }
    let fuel_errors = [FuelError::FuelMeteringDisabled, FuelError::OutOfFuel { required_fuel: 9 }];
    for (i, e) in fuel_errors.iter().enumerate() {
        out.line("fuel_error", &[i.to_string()], e.to_string());
    }
    let func_type_errors =
        [FuncTypeError::TooManyFunctionParams, FuncTypeError::TooManyFunctionResults];
    for (i, e) in func_type_errors.iter().enumerate() {
        out.line("func_type_error", &[i.to_string()], e.to_string());
    }
    let global_errors = [GlobalError::ImmutableWrite, GlobalError::TypeMismatch];
    for (i, e) in global_errors.iter().enumerate() {
        out.line("global_error", &[i.to_string()], e.to_string());
    }
    out.line("untyped_error", &["0".into()], UntypedError::invalid_len().to_string());
    // FuncType.
    let all = [
        ValType::I32,
        ValType::I64,
        ValType::F32,
        ValType::F64,
        ValType::V128,
        ValType::FuncRef,
        ValType::ExternRef,
    ];
    let names = ["i32", "i64", "f32", "f64", "v128", "func", "extern"];
    for (np, nr) in [(0, 0), (1, 0), (0, 1), (3, 2), (21, 0), (11, 11), (1000, 1000), (1001, 0), (0, 1001)] {
        let params: Vec<usize> = (0..np).map(|i| (i * 3 + 1) % 7).collect();
        let results: Vec<usize> = (0..nr).map(|i| (i * 5 + 2) % 7).collect();
        let res = match FuncType::new(
            params.iter().map(|&i| all[i]),
            results.iter().map(|&i| all[i]),
        ) {
            Ok(ft) => {
                let dbg = format!("{ft:?}");
                if dbg.len() > 200 {
                    format!("ok {} {} {}", ft.len_params(), ft.len_results(), dbg.len())
                } else {
                    format!("ok {} {} {dbg}", ft.len_params(), ft.len_results())
                }
            }
            Err(e) => format!("err {e}"),
        };
        let enc = |v: &[usize]| v.iter().map(|&i| names[i]).collect::<Vec<_>>().join(" ");
        out.line("func_type", &[np.to_string(), nr.to_string()], res.clone());
        let _ = enc;
    }
    // F32 / F64 Display and Debug.
    let mut f32s = f32_small_pool(rng);
    f32s.extend([1e16f32, 1e15, 1e-4, 9.9e-5, 123.456, 0.3, 16777216.0, 1e38].map(f32::to_bits));
    for &a in &f32s {
        let f = F32::from_bits(a);
        out.line("f32_fmt", &[h32(a)], format!("{f}|{f:?}"));
    }
    let mut f64s = f64_small_pool(rng);
    f64s.extend([1e16f64, 1e15, 1e-4, 9.9e-5, 123.456, 0.3, 9007199254740993.0, 1e300].map(f64::to_bits));
    for &a in &f64s {
        let f = F64::from_bits(a);
        out.line("f64_fmt", &[h64(a)], format!("{f}|{f:?}"));
    }
}

fn main() {
    let mut rng = Rng(0x7761_736d_6963_6f72);
    let mut out = Out(String::new());
    gen_scalar(&mut out, &mut rng);
    gen_float(&mut out, &mut rng);
    gen_fma(&mut out, &mut rng);
    gen_simd(&mut out, &mut rng);
    gen_memory_access(&mut out, &mut rng);
    gen_memory_scenarios(&mut out);
    gen_table_scenarios(&mut out);
    gen_display(&mut out, &mut rng);
    let mut header = String::new();
    writeln!(
        header,
        "# Generated by oracle/src/bin/gen_wasmi_core_tests.rs (wasmi_core 1.0.9, simd, no std)."
    )
    .unwrap();
    writeln!(
        header,
        "# Regenerate (from oracle/, on aarch64): cargo run --release --offline --bin gen_wasmi_core_tests > ../wasmi/core/testdata/oracle.tsv"
    )
    .unwrap();
    print!("{header}{}", out.0);
}
