//! Oracle for the MoonBit moxcms port (produces the expected values of
//! `moxcms/*_test.mbt` and `moxcms/pxfm/pxfm_wbtest.mbt`).
//!
//! Build outside the repository with the versions of `oracle/Cargo.lock`:
//! copy this directory together with `oracle/Cargo.lock` and
//! `oracle/rust-toolchain.toml`, then `cargo build --release --offline`.
//! The results depend on the CPU: the expectations were produced on Apple
//! Silicon (aarch64, NEON with `rdm`) with moxcms' default features.
//!
//! Usage:
//!   moxcms-oracle info <icc>
//!   moxcms-oracle run <icc> <ncomp> <u8|f32>      (env OUT=<file> dumps raw output)
//!   moxcms-oracle fuzz <icc> <count>              (corrupted variants, hash on stderr)
//!   moxcms-oracle srgb                             (dump new_srgb colorants)
//!   moxcms-oracle powf <n> / pow <n>               (hash of pxfm results)

use moxcms::*;
use std::io::Write;

struct Rng(u32);
impl Rng {
    fn next(&mut self) -> u32 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.0 = x;
        x
    }
    fn byte(&mut self) -> u8 {
        (self.next() >> 24) as u8
    }
    fn float(&mut self) -> f32 {
        let v = self.next() >> 10;
        v as f32 / 4194304.0 * 1.5 - 0.25
    }
}

const SEED: u32 = 2463534242;

fn special_floats() -> Vec<f32> {
    vec![
        -1.0, -0.5, -0.01, 0.0, 1e-6, 0.001, 0.25, 0.5, 0.75, 0.999, 1.0, 1.001, 1.5, 2.0,
        f32::NAN, f32::INFINITY, f32::NEG_INFINITY,
    ]
}

fn inputs_u8(n: usize) -> Vec<u8> {
    let mut out = Vec::new();
    let mut rng = Rng(SEED);
    match n {
        1 => {
            for i in 0..256u32 {
                out.push(i as u8);
            }
            for _ in 0..4096 {
                out.push(rng.byte());
            }
        }
        3 => {
            let l: Vec<u8> = (0..52).map(|i| (i * 5) as u8).collect();
            for &r in &l {
                for &g in &l {
                    for &b in &l {
                        out.extend_from_slice(&[r, g, b]);
                    }
                }
            }
            for _ in 0..50000 * 3 {
                out.push(rng.byte());
            }
        }
        4 => {
            let l: Vec<u8> = (0..17).map(|i| if i == 16 { 255 } else { (i * 16) as u8 }).collect();
            for &c in &l {
                for &m in &l {
                    for &y in &l {
                        for &k in &l {
                            out.extend_from_slice(&[c, m, y, k]);
                        }
                    }
                }
            }
            for _ in 0..50000 * 4 {
                out.push(rng.byte());
            }
        }
        _ => panic!("bad n"),
    }
    out
}

fn inputs_f32(n: usize) -> Vec<f32> {
    let mut out = Vec::new();
    let mut rng = Rng(SEED);
    let sf = special_floats();
    match n {
        1 => {
            for i in 0..=4096u32 {
                out.push(i as f32 / 4096.0);
            }
            out.extend_from_slice(&sf);
            for _ in 0..4096 {
                out.push(rng.float());
            }
        }
        3 => {
            let l: Vec<f32> = (0..=16).map(|i| i as f32 / 16.0).collect();
            for &r in &l {
                for &g in &l {
                    for &b in &l {
                        out.extend_from_slice(&[r, g, b]);
                    }
                }
            }
            for &s in &sf {
                out.extend_from_slice(&[s, s, s]);
                out.extend_from_slice(&[s, 0.5, 0.25]);
                out.extend_from_slice(&[0.75, s, 0.5]);
                out.extend_from_slice(&[0.25, 0.5, s]);
            }
            for _ in 0..50000 * 3 {
                out.push(rng.float());
            }
        }
        4 => {
            let l: Vec<f32> = (0..=8).map(|i| i as f32 / 8.0).collect();
            for &c in &l {
                for &m in &l {
                    for &y in &l {
                        for &k in &l {
                            out.extend_from_slice(&[c, m, y, k]);
                        }
                    }
                }
            }
            for &s in &sf {
                out.extend_from_slice(&[s, s, s, s]);
                out.extend_from_slice(&[s, 0.5, 0.25, 0.125]);
                out.extend_from_slice(&[0.75, s, 0.5, 0.25]);
                out.extend_from_slice(&[0.25, 0.5, s, 0.75]);
                out.extend_from_slice(&[0.25, 0.5, 0.125, s]);
            }
            for _ in 0..50000 * 4 {
                out.push(rng.float());
            }
        }
        _ => panic!("bad n"),
    }
    out
}

fn fnv(bytes: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in bytes {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

fn layout_for(n: usize) -> Layout {
    match n {
        1 => Layout::Gray,
        3 => Layout::Rgb,
        4 => Layout::Rgba,
        _ => panic!("bad n"),
    }
}

fn be32(d: &[u8], i: usize) -> u32 {
    u32::from_be_bytes([d[i], d[i + 1], d[i + 2], d[i + 3]])
}

fn mutate(data: &[u8], idx: u32) -> Vec<u8> {
    let mut rng = Rng((SEED ^ idx.wrapping_mul(0x9E37_79B9)) | 1);
    let mut d = data.to_vec();
    let len = d.len();
    let tcount = if len >= 132 {
        (be32(data, 128) as usize).min((len - 132) / 12).min(64)
    } else {
        0
    };
    let kind = rng.next() % 6;
    match kind {
        0 => {
            let l = rng.next() as usize % (len + 1);
            d.truncate(l);
        }
        1 => {
            let k = 1 + rng.next() % 4;
            for _ in 0..k {
                let p = rng.next() as usize % len;
                d[p] = rng.byte();
            }
        }
        2 => {
            let lim = len.min(132 + 12 * tcount);
            let k = 1 + rng.next() % 3;
            for _ in 0..k {
                let p = rng.next() as usize % lim;
                d[p] = rng.byte();
            }
        }
        3 => {
            if tcount > 0 {
                let t = rng.next() as usize % tcount;
                let field = 132 + 12 * t + 4 + 4 * (rng.next() as usize % 2);
                let v = if rng.next() % 2 == 0 {
                    rng.next() % (len as u32 + 64)
                } else {
                    rng.next()
                };
                d[field..field + 4].copy_from_slice(&v.to_be_bytes());
            }
        }
        _ => {
            if tcount > 0 {
                let t = rng.next() as usize % tcount;
                let off = be32(data, 132 + 12 * t + 4) as usize;
                let size = be32(data, 132 + 12 * t + 8) as usize;
                if off < len && size > 0 {
                    let span = size.min(len - off);
                    let k = 1 + rng.next() % 3;
                    for _ in 0..k {
                        let p = if kind == 4 {
                            off + rng.next() as usize % span
                        } else {
                            off + (8 + rng.next() as usize % 8).min(span - 1)
                        };
                        d[p] = rng.byte();
                    }
                }
            }
        }
    }
    d
}

fn fuzz_case(d: &[u8], idx: u32) -> String {
    let profile = match ColorProfile::new_from_slice(d) {
        Ok(p) => p,
        Err(e) => return format!("PARSE_ERR {:?}", e),
    };
    let n = match profile.color_space {
        DataColorSpace::Gray => 1,
        DataColorSpace::Cmyk | DataColorSpace::Color4 => 4,
        _ => 3,
    };
    let dst = ColorProfile::new_srgb();
    let mut out = format!("OK n={}", n);
    let mut rng = Rng(SEED ^ idx);
    match profile.create_transform_8bit(layout_for(n), &dst, Layout::Rgb, TransformOptions::default()) {
        Err(e) => out += &format!(" u8:ERR {:?}", e),
        Ok(t) => {
            let src: Vec<u8> = (0..64 * n).map(|_| rng.byte()).collect();
            let mut o = vec![0u8; 64 * 3];
            match t.transform(&src, &mut o) {
                Err(e) => out += &format!(" u8:TERR {:?}", e),
                Ok(()) => out += &format!(" u8:{:#018x}", fnv(&o)),
            }
        }
    }
    if idx % 10 == 0 {
        match profile.create_transform_f32(layout_for(n), &dst, Layout::Rgb, TransformOptions::default()) {
            Err(e) => out += &format!(" f32:ERR {:?}", e),
            Ok(t) => {
                let src: Vec<f32> = (0..64 * n).map(|_| rng.float()).collect();
                let mut o = vec![0f32; 64 * 3];
                match t.transform(&src, &mut o) {
                    Err(e) => out += &format!(" f32:TERR {:?}", e),
                    Ok(()) => {
                        let raw: Vec<u8> = o.iter().flat_map(|v| v.to_bits().to_le_bytes()).collect();
                        out += &format!(" f32:{:#018x}", fnv(&raw))
                    }
                }
            }
        }
    }
    out
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    match args[1].as_str() {
        "info" => {
            let data = std::fs::read(&args[2]).unwrap();
            match ColorProfile::new_from_slice(&data) {
                Ok(p) => {
                    println!(
                        "OK cs={:?} pcs={:?} class={:?} version={:?} intent={:?}",
                        p.color_space,
                        p.pcs,
                        p.profile_class,
                        p.version(),
                        p.rendering_intent
                    );
                    println!("matrix_shaper={}", p.is_matrix_shaper());
                    println!(
                        "a2b0={} b2a0={} cicp={:?}",
                        p.lut_a_to_b_perceptual.is_some(),
                        p.lut_b_to_a_perceptual.is_some(),
                        p.cicp
                    );
                }
                Err(e) => println!("ERR {:?}", e),
            }
        }
        "srgb" => {
            let p = ColorProfile::new_srgb();
            for c in [p.red_colorant, p.green_colorant, p.blue_colorant, p.white_point] {
                println!(
                    "{:#018x} {:#018x} {:#018x}",
                    c.x.to_bits(),
                    c.y.to_bits(),
                    c.z.to_bits()
                );
            }
            println!("{:?}", p.media_white_point.map(|c| (c.x.to_bits(), c.y.to_bits(), c.z.to_bits())));
        }
        "run" => {
            let data = std::fs::read(&args[2]).unwrap();
            let n: usize = args[3].parse().unwrap();
            let mode = args[4].as_str();
            let profile = match ColorProfile::new_from_slice(&data) {
                Ok(p) => p,
                Err(e) => {
                    println!("PARSE_ERR {:?}", e);
                    return;
                }
            };
            let dst = ColorProfile::new_srgb();
            let mut raw: Vec<u8> = Vec::new();
            let count;
            match mode {
                "u8" => {
                    let t = match profile.create_transform_8bit(
                        layout_for(n),
                        &dst,
                        Layout::Rgb,
                        TransformOptions::default(),
                    ) {
                        Ok(t) => t,
                        Err(e) => {
                            println!("CREATE_ERR {:?}", e);
                            return;
                        }
                    };
                    let src = inputs_u8(n);
                    count = src.len() / n;
                    let mut out = vec![0u8; count * 3];
                    if let Err(e) = t.transform(&src, &mut out) {
                        println!("TRANSFORM_ERR {:?}", e);
                        return;
                    }
                    raw = out;
                }
                "f32" => {
                    let t = match profile.create_transform_f32(
                        layout_for(n),
                        &dst,
                        Layout::Rgb,
                        TransformOptions::default(),
                    ) {
                        Ok(t) => t,
                        Err(e) => {
                            println!("CREATE_ERR {:?}", e);
                            return;
                        }
                    };
                    let src = inputs_f32(n);
                    count = src.len() / n;
                    let mut out = vec![0f32; count * 3];
                    if let Err(e) = t.transform(&src, &mut out) {
                        println!("TRANSFORM_ERR {:?}", e);
                        return;
                    }
                    for v in out {
                        raw.extend_from_slice(&v.to_bits().to_le_bytes());
                    }
                }
                _ => panic!("bad mode"),
            }
            println!("OK count={} hash={:#018x}", count, fnv(&raw));
            if let Ok(path) = std::env::var("OUT") {
                std::fs::File::create(path).unwrap().write_all(&raw).unwrap();
            }
        }
        "fuzz" => {
            let data = std::fs::read(&args[2]).unwrap();
            let count: u32 = args[3].parse().unwrap();
            std::panic::set_hook(Box::new(|_| {}));
            let mut all = String::new();
            for idx in 0..count {
                let d = mutate(&data, idx);
                let line = match std::panic::catch_unwind(|| fuzz_case(&d, idx)) {
                    Ok(l) => l,
                    Err(_) => "PANIC".to_string(),
                };
                println!("{} {}", idx, line);
                all += &line;
                all += "\n";
            }
            eprintln!("hash={:#018x}", fnv(all.as_bytes()));
        }
        "powf" => {
            // x in [0, 2), y in [0.05, 5)
            let n: usize = args[2].parse().unwrap();
            let mut rng = Rng(SEED);
            let mut raw = Vec::new();
            for _ in 0..n {
                let x = f32::from_bits(rng.next() >> 9 | 0x3f80_0000) - 1.0 + (rng.next() & 1) as f32;
                let y = (rng.next() >> 8) as f32 / 16777216.0 * 5.0 + 0.05;
                let r = pxfm::f_powf(x, y);
                raw.extend_from_slice(&r.to_bits().to_le_bytes());
            }
            println!("hash={:#018x}", fnv(&raw));
            if let Ok(path) = std::env::var("OUT") {
                std::fs::File::create(path).unwrap().write_all(&raw).unwrap();
            }
        }
        "pow" => {
            let n: usize = args[2].parse().unwrap();
            let mut rng = Rng(SEED);
            let mut raw = Vec::new();
            for _ in 0..n {
                let hi = (rng.next() >> 12) as u64;
                let lo = rng.next() as u64;
                let x = f64::from_bits(0x3ff0_0000_0000_0000 | (hi << 32) | lo) - 1.0;
                let y = (rng.next() >> 8) as f64 / 16777216.0 * 5.0 + 0.05;
                let r = pxfm::f_pow(x, y);
                raw.extend_from_slice(&r.to_bits().to_le_bytes());
            }
            println!("hash={:#018x}", fnv(&raw));
            if let Ok(path) = std::env::var("OUT") {
                std::fs::File::create(path).unwrap().write_all(&raw).unwrap();
            }
        }
        _ => panic!("unknown command"),
    }
}
