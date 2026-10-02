//! Generates `pic_scale/testdata/oracle.tsv`: the real `pic-scale` 0.7.12
//! crate (with hayro's features: `neon`, `rdm`, `sse`, `avx`; no
//! `threading`) run exactly the way hayro's renderer calls it
//! (`Scaler::new(ResamplingFunction::CatmullRom)`, then
//! `plan_planar_resampling` / `plan_rgb_resampling` /
//! `plan_rgba_resampling(.., true)` and `resample`), over deterministic
//! pseudo-random images.
//!
//! The input images are not stored: both sides regenerate them from the
//! recorded parameters with the same SplitMix64 generator (`gen_image`
//! here, `gen_image` in `pic_scale/oracle_wbtest.mbt`). Each row records the
//! output length, its FNV-1a-64 hash and its first bytes (for debugging).
//!
//! `sort` rows check the port of `core::slice::sort_unstable_by` (used by
//! `quantize_kernel`): indices sorted by descending `|key|` with many ties.
//!
//! The results depend on the SIMD paths pic-scale picks at runtime, so the
//! file must be generated on aarch64 with FEAT_RDM (e.g. Apple silicon),
//! which is what the upstream render goldens were produced on.
//!
//! Usage (from `oracle/`):
//! `cargo run --release --offline --bin gen_pic_scale_tests > ../pic_scale/testdata/oracle.tsv`

use std::fmt::Write as _;

use pic_scale::{
    ImageSize, ImageStore, ImageStoreMut, ResamplingFunction, Scaler,
};

struct SplitMix(u64);

impl SplitMix {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    fn below(&mut self, n: u64) -> u64 {
        (self.next() >> 32) % n
    }
}

fn fnv1a64(data: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for &b in data {
        h ^= b as u64;
        h = h.wrapping_mul(0x0000_0100_0000_01b3);
    }
    h
}

/// Generates an `n`-channel image (must match `gen_image` in
/// `pic_scale/oracle_wbtest.mbt`).
fn gen_image(n: usize, w: usize, h: usize, color: &str, alpha: &str, seed: u64) -> Vec<u8> {
    let mut rng = SplitMix(seed);
    let mut consts = [0u8; 4];
    for c in consts.iter_mut() {
        *c = (rng.next() >> 56) as u8;
    }
    let wd = (w.max(2) - 1) as u64;
    let hd = (h.max(2) - 1) as u64;
    let sd = (w + h).max(3) as u64 - 2;
    let mut out = Vec::with_capacity(w * h * n);
    for y in 0..h as u64 {
        for x in 0..w as u64 {
            for c in 0..n {
                let v = if n == 4 && c == 3 {
                    match alpha {
                        "opaque" => 255,
                        "zero" => 0,
                        "const" => consts[3],
                        "rand" => (rng.next() >> 56) as u8,
                        "mixed" => {
                            let r = rng.next();
                            match r >> 62 {
                                0 => 0,
                                1 => 255,
                                _ => (r >> 8) as u8,
                            }
                        }
                        "grad" => (x * 255 / wd) as u8,
                        _ => panic!("alpha mode {alpha}"),
                    }
                } else {
                    match color {
                        "rand" => (rng.next() >> 56) as u8,
                        "const" => consts[c],
                        "ext" => {
                            if rng.next() >> 63 == 1 {
                                255
                            } else {
                                0
                            }
                        }
                        "grad" => match c % 3 {
                            0 => (x * 255 / wd) as u8,
                            1 => (y * 255 / hd) as u8,
                            _ => ((x + y) * 255 / sd) as u8,
                        },
                        _ => panic!("color mode {color}"),
                    }
                };
                out.push(v);
            }
        }
    }
    out
}

fn resize<const N: usize>(
    data: &[u8],
    sw: usize,
    sh: usize,
    dw: usize,
    dh: usize,
    plan: impl FnOnce(
        &Scaler,
        ImageSize,
        ImageSize,
    ) -> Result<std::sync::Arc<pic_scale::Resampling<u8, N>>, pic_scale::PicScaleError>,
) -> Vec<u8> {
    // Same sequence as hayro's `resize_image_data_impl`.
    let scaler = Scaler::new(ResamplingFunction::CatmullRom);
    let source_size = ImageSize::new(sw, sh);
    let target_size = ImageSize::new(dw, dh);
    let src = ImageStore::<u8, N>::from_slice(data, sw, sh).unwrap();
    let mut out = vec![0; dw * dh * N];
    let mut dst = ImageStoreMut::<u8, N>::from_slice(&mut out, dw, dh).unwrap();
    let plan = plan(&scaler, source_size, target_size).unwrap();
    plan.resample(&src, &mut dst).unwrap();
    out
}

struct Case {
    plan: &'static str,
    sw: usize,
    sh: usize,
    dw: usize,
    dh: usize,
    color: &'static str,
    alpha: &'static str,
    seed: u64,
}

fn hex(data: &[u8]) -> String {
    let mut s = String::new();
    for b in data.iter().take(16) {
        write!(s, "{b:02x}").unwrap();
    }
    if s.is_empty() {
        s.push('-');
    }
    s
}

const PLANS: [&str; 3] = ["planar", "rgb", "rgba"];
const COLORS: [&str; 4] = ["rand", "const", "ext", "grad"];
const ALPHAS: [&str; 6] = ["rand", "mixed", "opaque", "const", "zero", "grad"];

fn main() {
    let mut rng = SplitMix(0x5eed_0000_0000_0001);
    let mut cases: Vec<Case> = Vec::new();
    let push = |rng: &mut SplitMix,
                    cases: &mut Vec<Case>,
                    plan: &'static str,
                    sw: usize,
                    sh: usize,
                    dw: usize,
                    dh: usize,
                    k: usize| {
        let color = COLORS[k % COLORS.len()];
        let alpha = if plan == "rgba" {
            ALPHAS[(k / COLORS.len() + k) % ALPHAS.len()]
        } else {
            "-"
        };
        let seed = rng.next();
        cases.push(Case {
            plan,
            sw,
            sh,
            dw,
            dh,
            color,
            alpha,
            seed,
        });
    };

    let mut k = 0usize;
    // Horizontal-only resizes over all widths 1..=40 (SIMD block tails).
    for (pi, plan) in PLANS.iter().enumerate() {
        for sw in 1..=40usize {
            let mut targets = vec![(sw / 2).max(1), (sw * 3 / 4).max(1), 1];
            if sw > 1 {
                targets.push(sw - 1);
            }
            targets.sort();
            targets.dedup();
            for dw in targets {
                let sh = 1 + rng.below(4) as usize;
                push(&mut rng, &mut cases, plan, sw, sh, dw, sh, k + pi);
                k += 1;
            }
        }
    }
    // Vertical-only resizes over all heights 1..=40 and widths that hit/miss
    // the 32/16/8-column blocks of the vertical pass.
    for (pi, plan) in PLANS.iter().enumerate() {
        for sh in 2..=40usize {
            let w = 1 + rng.below(70) as usize;
            for dh in [(sh / 2).max(1), sh - 1, (sh / 3).max(1)] {
                push(&mut rng, &mut cases, plan, w, sh, w, dh, k + pi);
                k += 1;
            }
        }
    }
    // Both axes, random small sizes (downscale on at least one axis, the
    // other axis down, equal or up).
    for (pi, plan) in PLANS.iter().enumerate() {
        for _ in 0..60 {
            let sw = 1 + rng.below(48) as usize;
            let sh = 1 + rng.below(48) as usize;
            let dw = 1 + rng.below(sw as u64 * 2) as usize;
            let dh = 1 + rng.below(sh as u64 * 2) as usize;
            push(&mut rng, &mut cases, plan, sw, sh, dw, dh, k + pi);
            k += 1;
        }
    }
    // Fixed geometries: large ratios (kernels > 20 taps use ipnsort, scale
    // >= 8 switches off the `rdm` kernels), ratio boundaries, one axis up.
    let fixed: &[(usize, usize, usize, usize)] = &[
        (257, 131, 64, 33),
        (300, 40, 3, 2),
        (500, 7, 5, 7),
        (7, 500, 7, 5),
        (120, 333, 120, 4),
        (64, 9, 8, 9),
        (63, 9, 8, 9),
        (65, 9, 8, 9),
        (9, 64, 9, 8),
        (9, 63, 9, 8),
        (9, 65, 9, 8),
        (799, 3, 100, 3),
        (801, 3, 100, 3),
        (3, 799, 3, 100),
        (3, 801, 3, 100),
        (50, 10, 20, 37),
        (10, 50, 31, 7),
        (5, 5, 13, 9),
        (6, 4, 6, 4),
        (1, 1, 1, 1),
        (1, 1, 3, 1),
        (1, 9, 1, 2),
        (9, 1, 2, 1),
        (1000, 2, 37, 2),
        (2, 1000, 2, 37),
        (99, 99, 1, 1),
        (100, 1, 1, 1),
        (1, 100, 1, 1),
        (33, 17, 11, 51),
        (41, 23, 40, 22),
        (200, 150, 199, 149),
        (128, 128, 13, 13),
        (96, 64, 12, 8),
        (97, 65, 12, 8),
        (160, 90, 21, 12),
        (240, 3, 41, 3),
        (3, 240, 3, 41),
        (512, 384, 160, 120),
        (333, 2, 64, 5),
        (2, 333, 5, 64),
    ];
    for &(sw, sh, dw, dh) in fixed {
        for (pi, plan) in PLANS.iter().enumerate() {
            let reps = if plan == &"rgba" { 3 } else { 2 };
            for _ in 0..reps {
                push(&mut rng, &mut cases, plan, sw, sh, dw, dh, k + pi);
                k += 1;
            }
        }
    }
    // Downscale ratios from ~0.99 to ~0.01 on one or both axes.
    for (pi, plan) in PLANS.iter().enumerate() {
        for step in 0..24 {
            let ratio = 0.99f64 * (0.01f64 / 0.99).powf(step as f64 / 23.0);
            let sw = 40 + rng.below(260) as usize;
            let sh = 2 + rng.below(30) as usize;
            let dw = ((sw as f64 * ratio).ceil() as usize).max(1);
            let dh = if step % 3 == 0 {
                ((sh as f64 * ratio).ceil() as usize).max(1)
            } else if step % 3 == 1 {
                sh
            } else {
                sh + 1 + rng.below(5) as usize
            };
            push(&mut rng, &mut cases, plan, sw, sh, dw, dh, k + pi);
            k += 1;
            // And the transposed geometry.
            push(&mut rng, &mut cases, plan, sh, sw, dh, dw, k + pi);
            k += 1;
        }
    }

    let mut out = String::new();
    out.push_str("# plan\tsw\tsh\tdw\tdh\tcolor\talpha\tseed\tlen\tfnv1a64\thead\n");
    for c in &cases {
        let n = match c.plan {
            "planar" => 1,
            "rgb" => 3,
            _ => 4,
        };
        let data = gen_image(n, c.sw, c.sh, c.color, c.alpha, c.seed);
        let res = match c.plan {
            "planar" => resize::<1>(&data, c.sw, c.sh, c.dw, c.dh, |s, a, b| {
                s.plan_planar_resampling(a, b)
            }),
            "rgb" => resize::<3>(&data, c.sw, c.sh, c.dw, c.dh, |s, a, b| {
                s.plan_rgb_resampling(a, b)
            }),
            _ => resize::<4>(&data, c.sw, c.sh, c.dw, c.dh, |s, a, b| {
                s.plan_rgba_resampling(a, b, true)
            }),
        };
        writeln!(
            out,
            "{}\t{}\t{}\t{}\t{}\t{}\t{}\t{:016x}\t{}\t{:016x}\t{}",
            c.plan,
            c.sw,
            c.sh,
            c.dw,
            c.dh,
            c.color,
            c.alpha,
            c.seed,
            res.len(),
            fnv1a64(&res),
            hex(&res)
        )
        .unwrap();
    }

    // `sort_unstable_by` on indices by descending |key| (as in
    // `quantize_kernel`), with many ties.
    for len in (0..=64usize).chain([70, 95, 100, 127, 128, 129, 200, 255, 256, 400, 640, 1000]) {
        for key_mod in [1u64, 2, 3, 7, 40, 100000] {
            let seed = rng.next();
            let mut r = SplitMix(seed);
            let keys: Vec<f64> = (0..len)
                .map(|_| r.below(key_mod) as f64 - (key_mod / 2) as f64)
                .collect();
            let mut order: Vec<usize> = (0..len).collect();
            order.sort_unstable_by(|&a, &b| {
                keys[b]
                    .abs()
                    .partial_cmp(&keys[a].abs())
                    .unwrap_or(std::cmp::Ordering::Equal)
            });
            let bytes: Vec<u8> = order
                .iter()
                .flat_map(|&i| (i as u32).to_le_bytes())
                .collect();
            writeln!(
                out,
                "sort\t{}\t{}\t0\t0\t-\t-\t{:016x}\t{}\t{:016x}\t{}",
                len,
                key_mod,
                seed,
                bytes.len(),
                fnv1a64(&bytes),
                hex(&bytes)
            )
            .unwrap();
        }
    }
    print!("{out}");
}
