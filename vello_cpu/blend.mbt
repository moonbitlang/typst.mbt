// Port of `vello_cpu/src/fine/lowp/compose.rs`, `vello_cpu/src/fine/lowp/blend.rs`
// and (for the blend modes that fall back to `f32`)
// `vello_cpu/src/fine/highp/blend.rs`.
//
// All functions work on a chunk of 8 RGBA pixels (`u8x32`) stored as 32
// `Int`s.

///|
/// Composite `src_c` over `bg_c` in place (`ComposeExt::compose`); the
/// result is written to `src_c`.
fn compose(
  blend_mode : BlendMode,
  src_c : FixedArray[Int],
  bg_c : FixedArray[Int],
  alpha_mask : FixedArray[Int]?,
) -> Unit {
  for p in 0..<8 {
    let al_s = src_c[p * 4 + 3]
    let al_b = bg_c[p * 4 + 3]
    let (fa, fb, sat) = match blend_mode.compose {
      Clear => (0, 0, false)
      Copy => (255, 0, false)
      SrcOver => (255, (255 - al_s) & 0xFF, false)
      DestOver => ((255 - al_b) & 0xFF, 255, false)
      Dest => (0, 255, false)
      Xor => ((255 - al_b) & 0xFF, (255 - al_s) & 0xFF, false)
      SrcIn => (al_b, 0, false)
      DestIn => (0, al_s, false)
      SrcOut => ((255 - al_b) & 0xFF, 0, false)
      DestOut => (0, (255 - al_s) & 0xFF, false)
      SrcAtop => (al_b, (255 - al_s) & 0xFF, false)
      DestAtop => ((255 - al_b) & 0xFF, al_s, false)
      // Have not been able to find a formula for this, so just fallback to
      // Plus.
      Plus | PlusLighter => (255, 255, true)
    }
    for c in 0..<4 {
      let i = p * 4 + c
      let a = norm_mul(src_c[i], fa) & 0xFF
      let b = norm_mul(fb, bg_c[i]) & 0xFF
      let mut res = if sat {
        min_int(a + b, 255)
      } else {
        (a + b) & 0xFF
      }
      if alpha_mask is Some(alpha_mask) {
        let m = alpha_mask[p]
        let m_inv = (255 - m) & 0xFF
        let p1 = m * res
        let p2 = m_inv * bg_c[i]
        res = div_255((p1 + p2) & 0xFFFF) & 0xFF
      }
      src_c[i] = res
    }
  }
}

///|
/// Mix `src_c` with `bg_c` in place (`blend::mix`).
fn mix(src_c : FixedArray[Int], bg_c : FixedArray[Int], blend_mode : BlendMode) -> Unit {
  match blend_mode.mix {
    Normal => ()
    Multiply | Screen | Overlay | Darken | Lighten | HardLight | Difference
    | Exclusion => u8_mix(src_c, bg_c, blend_mode.mix)
    ColorDodge | ColorBurn | SoftLight | Luminosity | Color | Hue | Saturation => {
      // Fallback for blend modes that aren't supported in u8.
      for p in 0..<8 {
        let src = FixedArray::make(4, (0.0 : Float))
        let bg = FixedArray::make(4, (0.0 : Float))
        for c in 0..<4 {
          src[c] = u8_to_unit(src_c[p * 4 + c])
          bg[c] = u8_to_unit(bg_c[p * 4 + c])
        }
        highp_mix(src, bg, blend_mode.mix)
        for c in 0..<4 {
          src_c[p * 4 + c] = f32_to_u8_lane(madd(255.0, src[c], 0.5))
        }
      }
    }
  }
}

///|
/// The `u8` fast path for separable blend modes.
fn u8_mix(src_c : FixedArray[Int], bg_c : FixedArray[Int], mix : Mix) -> Unit {
  let res = FixedArray::make(32, 0)
  for p in 0..<8 {
    let src_a = src_c[p * 4 + 3]
    let bg_a = bg_c[p * 4 + 3]
    for c in 0..<4 {
      let i = p * 4 + c
      let s = src_c[i]
      let d = bg_c[i]
      // `narrow_saturating_u16x32`: clamp the `u16` lane to 255.
      let narrow_sat = (v : Int) => min_int(v & 0xFFFF, 255)
      res[i] = match mix {
        // M = S * (1 - Ab) + S * D
        Multiply => {
          let p1 = norm_mul(s, (255 - bg_a) & 0xFF)
          let p2 = norm_mul(s, d)
          narrow_sat(p1 + p2)
        }
        // M = S + As * D - S * D
        Screen => {
          let p1 = norm_mul(src_a, d)
          let p2 = norm_mul(s, d)
          narrow_sat(s + p1 - p2)
        }
        // Overlay is hard-light with source and backdrop swapped.
        Overlay => hard_light_inner(s, d, src_a, bg_a, d, bg_a)
        // M = S * (1 - Ab) + min(S * Ab, D * As)
        Darken => {
          let p1 = norm_mul(s, (255 - bg_a) & 0xFF)
          let p2 = min_int(norm_mul(s, bg_a), norm_mul(d, src_a))
          narrow_sat(p1 + p2)
        }
        // M = S * (1 - Ab) + max(S * Ab, D * As)
        Lighten => {
          let p1 = norm_mul(s, (255 - bg_a) & 0xFF)
          let p2 = max_int(norm_mul(s, bg_a), norm_mul(d, src_a))
          narrow_sat(p1 + p2)
        }
        HardLight => hard_light_inner(s, d, src_a, bg_a, s, src_a)
        // M = S * (1 - Ab) + abs(S * Ab - D * As)
        Difference => {
          let p1 = norm_mul(s, (255 - bg_a) & 0xFF)
          let p2 = norm_mul(s, bg_a)
          let p3 = norm_mul(d, src_a)
          let diff = max_int(p2, p3) - min_int(p2, p3)
          narrow_sat(p1 + diff)
        }
        // M = S + As * D - 2 * S * D
        Exclusion => {
          let p1 = norm_mul(src_a, d)
          let p2 = norm_mul(s, d)
          let r = (s + p1) & 0xFFFF
          let sub = (p2 + p2) & 0xFFFF
          let r = if r >= sub { r - sub } else { 0 }
          narrow_sat(r)
        }
        _ => s
      }
    }
  }
  // `with_src_alpha`: clamp the color to the source alpha and keep the
  // source alpha.
  for p in 0..<8 {
    let src_a = src_c[p * 4 + 3]
    for c in 0..<3 {
      src_c[p * 4 + c] = min_int(res[p * 4 + c], src_a)
    }
  }
}

///|
fn hard_light_inner(
  s : Int,
  d : Int,
  src_a : Int,
  bg_a : Int,
  condition : Int,
  condition_a : Int,
) -> Int {
  let base = (s * ((255 - bg_a) & 0xFFFF)) & 0xFFFF
  // Multiply branch: 2 * S * D.
  let multiply = (2 * s * d) & 0xFFFF
  // Screen branch: As * Ab - 2 * (As - S) * (Ab - D).
  let two_diff = (2 * ((src_a - s) & 0xFFFF)) & 0xFFFF
  let screen = (src_a * bg_a - two_diff * ((bg_a - d) & 0xFFFF)) & 0xFFFF
  let blended = if ((condition + condition) & 0xFFFF) <= condition_a {
    multiply
  } else {
    screen
  }
  let res = div_255((base + blended) & 0xFFFF)
  min_int(res, 255)
}

///|
/// `highp::blend::mix` on a single unpremultiplied-to-be pixel.
fn highp_mix(src : FixedArray[Float], bg : FixedArray[Float], mix : Mix) -> Unit {
  let src_a = src[3]
  let bg_a = bg[3]
  let cs : Array[Float] = [unpremul(src[0], src_a), unpremul(src[1], src_a), unpremul(src[2], src_a)]
  let cb : Array[Float] = [unpremul(bg[0], bg_a), unpremul(bg[1], bg_a), unpremul(bg[2], bg_a)]
  let m : Array[Float] = match mix {
    Normal => [cs[0], cs[1], cs[2]]
    Multiply | Screen | Overlay | Darken | Lighten | ColorDodge | ColorBurn
    | HardLight | SoftLight | Difference | Exclusion =>
      [
        separable(mix, cs[0], cb[0]),
        separable(mix, cs[1], cb[1]),
        separable(mix, cs[2], cb[2]),
      ]
    Hue => {
      let r : Array[Float] = [cs[0], cs[1], cs[2]]
      set_sat(r, sat(cb))
      set_lum(r, lum(cb))
      r
    }
    Saturation => {
      let l = lum(cb)
      let r : Array[Float] = [cb[0], cb[1], cb[2]]
      set_sat(r, sat(cs))
      set_lum(r, l)
      r
    }
    Color => {
      let r : Array[Float] = [cs[0], cs[1], cs[2]]
      set_lum(r, lum(cb))
      r
    }
    Luminosity => {
      let r : Array[Float] = [cb[0], cb[1], cb[2]]
      set_lum(r, lum(cs))
      r
    }
  }
  for c in 0..<3 {
    // `apply_alpha`.
    let p1 = ((1.0 : Float) - bg_a) * cs[c]
    let p2 = bg_a * m[c]
    src[c] = (p1 + p2) * src_a
  }
  src[3] = src_a
}

///|
/// `Premultiply::unpremultiply` for one lane.
fn unpremul(v : Float, a : Float) -> Float {
  if a == 0.0 {
    0.0
  } else {
    v / a
  }
}

///|
fn separable(mix : Mix, cs : Float, cb : Float) -> Float {
  match mix {
    Multiply => cs * cb
    Screen => cb + cs - cs * cb
    Overlay => hard_light_single(cb, cs)
    Darken => vmin(cs, cb)
    Lighten => vmax(cs, cb)
    Difference => if cs <= cb { cb - cs } else { cs - cb }
    HardLight => hard_light_single(cs, cb)
    Exclusion => cs + cb - (2.0 : Float) * (cs * cb)
    SoftLight => {
      let d = if cb <= 0.25 {
        (((16.0 : Float) * cb - 12.0) * cb + 4.0) * cb
      } else {
        cb.sqrt()
      }
      if cs <= 0.5 {
        cb - ((1.0 : Float) - (2.0 : Float) * cs) * cb * ((1.0 : Float) - cb)
      } else {
        cb + ((2.0 : Float) * cs - 1.0) * (d - cb)
      }
    }
    ColorDodge =>
      if cb == 0.0 {
        0.0
      } else if cs == 1.0 {
        1.0
      } else {
        vmin(1.0, cb / ((1.0 : Float) - cs))
      }
    ColorBurn =>
      if cb == 1.0 {
        1.0
      } else if cs == 0.0 {
        0.0
      } else {
        (1.0 : Float) - vmin(1.0, ((1.0 : Float) - cb) / cs)
      }
    _ => cs
  }
}

///|
fn hard_light_single(src : Float, bg : Float) -> Float {
  if src <= 0.5 {
    bg * (src * 2.0)
  } else {
    let s2 = (2.0 : Float) * src - 1.0
    s2 + bg - bg * s2
  }
}

///|
fn lum(c : Array[Float]) -> Float {
  (0.3 : Float) * c[0] + (0.59 : Float) * c[1] + (0.11 : Float) * c[2]
}

///|
fn sat(c : Array[Float]) -> Float {
  vmax(vmax(c[0], c[1]), c[2]) - vmin(vmin(c[0], c[1]), c[2])
}

///|
fn clip_color(c : Array[Float]) -> Unit {
  let l = lum(c)
  let n = vmin(c[0], vmin(c[1], c[2]))
  let x = vmax(c[0], vmax(c[1], c[2]))
  for i in 0..<3 {
    if n < 0.0 {
      c[i] = l + (c[i] - l) * l / (l - n)
    }
    if x > 1.0 {
      c[i] = l + (c[i] - l) * ((1.0 : Float) - l) / (x - l)
    }
  }
}

///|
fn set_lum(c : Array[Float], l : Float) -> Unit {
  let d = l - lum(c)
  c[0] = c[0] + d
  c[1] = c[1] + d
  c[2] = c[2] + d
  clip_color(c)
}

///|
fn set_sat(c : Array[Float], s : Float) -> Unit {
  let mn = vmin(c[0], vmin(c[1], c[2]))
  let mx = vmax(c[0], vmax(c[1], c[2]))
  let sat = mx - mn
  // Map min channel to 0, max channel to s, and scale the middle
  // proportionally.
  for i in 0..<3 {
    c[i] = if sat == 0.0 { 0.0 } else { (c[i] - mn) * s / sat }
  }
}
