// TEMP (platform probe on the draft PR): what Rust's std reports on this
// platform for the operations behind the platform-dependent oracle tests.
use std::hint::black_box as b;

fn main() {
    println!("target {} {}", std::env::consts::OS, std::env::consts::ARCH);
    // NaNs: the constant, the default NaN of an invalid operation, and what
    // the hardware/libm return for the hayro PostScript cases.
    println!("f64::NAN            {:016x}", f64::NAN.to_bits());
    println!("0.0/0.0             {:016x}", (b(0.0f64) / b(0.0f64)).to_bits());
    println!("inf-inf             {:016x}", (b(f64::INFINITY) - b(f64::INFINITY)).to_bits());
    println!("-(f64::NAN)         {:016x}", (-b(f64::NAN)).to_bits());
    println!("NAN+1               {:016x}", (b(f64::NAN) + b(1.0)).to_bits());
    println!("0*inf               {:016x}", (b(0.0f64) * b(f64::INFINITY)).to_bits());
    println!("sqrt(-1) f64        {:016x}", b(-1.0f64).sqrt().to_bits());
    println!("ln(-7.3) f32        {:08x}", b(-7.3f32).ln().to_bits());
    println!("sqrt(-7.3) f32      {:08x}", b(-7.3f32).sqrt().to_bits());
    println!("log10(-7.3) f32     {:08x}", b(-7.3f32).log10().to_bits());
    // hayro type 4 `cos`: n.to_radians().cos() in f32.
    println!("cos(123456deg) f32  {:08x}", b(123456f32).to_radians().cos().to_bits());
    println!("sin(123456deg) f32  {:08x}", b(123456f32).to_radians().sin().to_bits());
    // svgtypes `skewY(30)`: tan of 30 degrees in f64.
    println!("tan(30deg) f64      {:016x}", b(30.0f64).to_radians().tan().to_bits());
    // kurbo: sin_cos, cbrt, atan2 in f64 (solve_cubic, arcs).
    let (s, c) = b(0.7f64).sin_cos();
    println!("sin_cos(0.7)        {:016x} {:016x}", s.to_bits(), c.to_bits());
    println!("cbrt(0.3)           {:016x}", b(0.3f64).cbrt().to_bits());
    println!("atan2(0.3,-0.9)     {:016x}", b(0.3f64).atan2(b(-0.9)).to_bits());
    let mut diff = 0;
    let mut x = 0.001f64;
    let mut h: u64 = 0xcbf29ce484222325;
    for _ in 0..100000 {
        let (s, c) = b(x).sin_cos();
        for v in [s, c, b(x).cbrt(), b(x).atan2(1.5), b(x).tan(), (b(x) as f32).sin() as f64, (b(x) as f32).cos() as f64] {
            h = (h ^ v.to_bits()).wrapping_mul(0x100000001b3);
        }
        x += 0.00731;
        diff += 1;
    }
    println!("fnv of 100000 x (sin_cos, cbrt, atan2, tan, sinf, cosf): {:016x} ({diff})", h);
}
