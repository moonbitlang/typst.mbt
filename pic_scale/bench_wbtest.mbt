// Benchmarks of the resamplers as hayro uses them (`moon bench`).

///|
fn bench_image(w : Int, h : Int, channels : Int) -> Bytes {
  let mut x = 0x9E3779B9U
  Bytes::makei(w * h * channels, i => {
    x = x * 1103515245U + 12345U
    // Smooth gradients with some noise, opaque where there is alpha.
    if channels == 4 && i % 4 == 3 {
      b'\xff'
    } else {
      ((i / channels % w + i / (w * channels) + (x >> 28).reinterpret_as_int()) &
      0xff).to_byte()
    }
  })
}

///|
test "bench resize_rgb_u8 1600x1200 -> 600x450 (rdm)" (it : @bench.T) {
  let src = bench_image(1600, 1200, 3)
  it.bench(() => it.keep(resize_rgb_u8(src, 1600, 1200, 600, 450)))
}

///|
test "bench resize_rgba_u8 1600x1200 -> 600x450 (rdm)" (it : @bench.T) {
  let src = bench_image(1600, 1200, 4)
  it.bench(() => {
    it.keep(resize_rgba_u8_premultiplied(src, 1600, 1200, 600, 450))
  })
}

///|
test "bench resize_planar_u8 2400x1800 -> 200x150 (i32)" (it : @bench.T) {
  let src = bench_image(2400, 1800, 1)
  it.bench(() => it.keep(resize_planar_u8(src, 2400, 1800, 200, 150)))
}
