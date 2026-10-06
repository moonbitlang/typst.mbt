// TEMP (platform probe on the draft PR): does Rust's std call the C
// library's math functions on this platform, or its own implementation?
// Counts the inputs for which `x.f()` and the C function differ in bits.
use std::hint::black_box as b;

#[link(name = "m")]
unsafe extern "C" {
    #[link_name = "cbrt"]
    fn c_cbrt(x: f64) -> f64;
    #[link_name = "sin"]
    fn c_sin(x: f64) -> f64;
    #[link_name = "cos"]
    fn c_cos(x: f64) -> f64;
    #[link_name = "tan"]
    fn c_tan(x: f64) -> f64;
    #[link_name = "atan2"]
    fn c_atan2(y: f64, x: f64) -> f64;
    #[link_name = "pow"]
    fn c_pow(x: f64, y: f64) -> f64;
    #[link_name = "log"]
    fn c_log(x: f64) -> f64;
    #[link_name = "log2"]
    fn c_log2(x: f64) -> f64;
    #[link_name = "exp"]
    fn c_exp(x: f64) -> f64;
    #[link_name = "hypot"]
    fn c_hypot(x: f64, y: f64) -> f64;
    #[link_name = "fma"]
    fn c_fma(x: f64, y: f64, z: f64) -> f64;
    #[link_name = "sinf"]
    fn c_sinf(x: f32) -> f32;
    #[link_name = "cosf"]
    fn c_cosf(x: f32) -> f32;
    #[link_name = "powf"]
    fn c_powf(x: f32, y: f32) -> f32;
    #[link_name = "cbrtf"]
    fn c_cbrtf(x: f32) -> f32;
    #[link_name = "logf"]
    fn c_logf(x: f32) -> f32;
}

fn main() {
    println!("target {} {}", std::env::consts::OS, std::env::consts::ARCH);
    let n = 200000;
    let mut d = [0usize; 17];
    let mut first_cbrt = None;
    let mut x = 1.0e-3f64;
    for i in 0..n {
        let y = 0.37 + (i as f64) * 1.0e-4;
        let xf = x as f32;
        let yf = y as f32;
        unsafe {
            let r = b(x).cbrt();
            let c = c_cbrt(b(x));
            if r.to_bits() != c.to_bits() {
                d[0] += 1;
                if first_cbrt.is_none() {
                    first_cbrt = Some((x, r, c));
                }
            }
            d[1] += (b(x).sin().to_bits() != c_sin(b(x)).to_bits()) as usize;
            d[2] += (b(x).cos().to_bits() != c_cos(b(x)).to_bits()) as usize;
            d[3] += (b(x).tan().to_bits() != c_tan(b(x)).to_bits()) as usize;
            d[4] += (b(x).atan2(b(y)).to_bits() != c_atan2(b(x), b(y)).to_bits()) as usize;
            d[5] += (b(x).powf(b(y)).to_bits() != c_pow(b(x), b(y)).to_bits()) as usize;
            d[6] += (b(x).ln().to_bits() != c_log(b(x)).to_bits()) as usize;
            d[7] += (b(x).log2().to_bits() != c_log2(b(x)).to_bits()) as usize;
            d[8] += (b(y).exp().to_bits() != c_exp(b(y)).to_bits()) as usize;
            d[9] += (b(x).hypot(b(y)).to_bits() != c_hypot(b(x), b(y)).to_bits()) as usize;
            d[10] += (b(x).mul_add(b(y), b(-x * y)).to_bits() != c_fma(b(x), b(y), b(-x * y)).to_bits()) as usize;
            d[11] += (b(xf).sin().to_bits() != c_sinf(b(xf)).to_bits()) as usize;
            d[12] += (b(xf).cos().to_bits() != c_cosf(b(xf)).to_bits()) as usize;
            d[13] += (b(xf).powf(b(yf)).to_bits() != c_powf(b(xf), b(yf)).to_bits()) as usize;
            d[14] += (b(xf).cbrt().to_bits() != c_cbrtf(b(xf)).to_bits()) as usize;
            d[15] += (b(xf).ln().to_bits() != c_logf(b(xf)).to_bits()) as usize;
            let (s, c) = b(x).sin_cos();
            d[16] += (s.to_bits() != c_sin(b(x)).to_bits() || c.to_bits() != c_cos(b(x)).to_bits()) as usize;
        }
        x = x * 1.00007 + 1.0e-5;
    }
    let names = [
        "cbrt", "sin", "cos", "tan", "atan2", "pow", "ln", "log2", "exp", "hypot", "mul_add/fma",
        "sinf", "cosf", "powf", "cbrtf", "logf", "sin_cos vs sin,cos",
    ];
    println!("inputs where Rust std and the C library differ (of {n}):");
    for (name, count) in names.iter().zip(d) {
        println!("  {name:<20} {count}");
    }
    if let Some((x, r, c)) = first_cbrt {
        println!("first cbrt difference: x={:016x} rust={:016x} c={:016x}", x.to_bits(), r.to_bits(), c.to_bits());
    }
}
