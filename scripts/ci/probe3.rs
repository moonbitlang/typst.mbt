// TEMP (platform probe on the draft PR): FNV-1a over the bits of Rust std's
// math methods on the input sequence of probe3.c.
use std::hint::black_box as b;

fn mix(h: u64, v: f64) -> u64 {
    (h ^ v.to_bits()).wrapping_mul(0x100000001b3)
}

fn main() {
    let names = [
        "cbrt", "sin", "cos", "tan", "atan2", "pow", "log", "exp", "hypot", "fma", "sinf", "cosf",
        "cbrtf",
    ];
    let mut h = [0xcbf29ce484222325u64; 13];
    let mut x = 1.0e-3f64;
    for i in 0..200000 {
        let y = 0.37 + (i as f64) * 1.0e-4;
        let xf = x as f32;
        h[0] = mix(h[0], b(x).cbrt());
        h[1] = mix(h[1], b(x).sin());
        h[2] = mix(h[2], b(x).cos());
        h[3] = mix(h[3], b(x).tan());
        h[4] = mix(h[4], b(x).atan2(b(y)));
        h[5] = mix(h[5], b(x).powf(b(y)));
        h[6] = mix(h[6], b(x).ln());
        h[7] = mix(h[7], b(y).exp());
        h[8] = mix(h[8], b(x).hypot(b(y)));
        h[9] = mix(h[9], b(x).mul_add(b(y), b(-x * y)));
        h[10] = mix(h[10], b(xf).sin() as f64);
        h[11] = mix(h[11], b(xf).cos() as f64);
        h[12] = mix(h[12], b(xf).cbrt() as f64);
        x = x * 1.00007 + 1.0e-5;
    }
    for (name, v) in names.iter().zip(h) {
        println!("  {name:<8} {v:016x}");
    }
}
