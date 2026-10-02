// Port of `resvg/src/filter/component_transfer.rs`.

///|
/// Applies component transfer functions for each `src` image channel.
///
/// Input image pixels should have an **unpremultiplied alpha**.
fn component_transfer_apply(
  fe : @usvg.FeComponentTransfer,
  data : FixedArray[UInt],
) -> Unit {
  for i in 0..<data.length() {
    let p = data[i]
    let mut r = px_r(p)
    let mut g = px_g(p)
    let mut b = px_b(p)
    let mut a = px_a(p)
    if !is_dummy(fe.func_r) {
      r = transfer(fe.func_r, r)
    }
    if !is_dummy(fe.func_b) {
      b = transfer(fe.func_b, b)
    }
    if !is_dummy(fe.func_g) {
      g = transfer(fe.func_g, g)
    }
    if !is_dummy(fe.func_a) {
      a = transfer(fe.func_a, a)
    }
    data[i] = px_pack(r, g, b, a)
  }
}

///|
fn is_dummy(func : @usvg.TransferFunction) -> Bool {
  match func {
    Identity => true
    Table(values) => values.is_empty()
    Discrete(values) => values.is_empty()
    Linear(..) => false
    Gamma(..) => false
  }
}

///|
fn transfer(func : @usvg.TransferFunction, c : Int) -> Int {
  let c = Float::from_int(c) / 255.0
  let c = match func {
    Identity => c
    Table(values) => {
      let n = values.length() - 1
      let k = f32_to_usize(@skia.floorf(c * Float::from_int(n)))
      let k = if k < n.to_int64() { k.to_int() } else { n }
      if k == n {
        values[k]
      } else {
        let vk = values[k]
        let vk1 = values[k + 1]
        let k = Float::from_int(k)
        let n = Float::from_int(n)
        vk + (c - k / n) * n * (vk1 - vk)
      }
    }
    Discrete(values) => {
      let n = values.length()
      let k = f32_to_usize(@skia.floorf(c * Float::from_int(n)))
      values[if k < (n - 1).to_int64() { k.to_int() } else { n - 1 }]
    }
    Linear(slope~, intercept~) => slope * c + intercept
    Gamma(amplitude~, exponent~, offset~) =>
      amplitude * @skia.powf(c, exponent) + offset
  }
  f32_to_u8(f32_bound(0.0, c, 1.0) * 255.0)
}
