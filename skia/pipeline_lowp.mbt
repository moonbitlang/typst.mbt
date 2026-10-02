// Port of `tiny-skia/src/pipeline/lowp.rs`.
//
// A low precision raster pipeline implementation.
//
// A lowp pipeline uses u16 instead of f32 for math. Because of that, it
// doesn't implement stages that require high precision. The pipeline
// compiler will automatically decide which one to use.
//
// The u16x16 lanes are `FixedArray[Int]`s holding values in 0..=0xFFFF; all
// arithmetic wraps like NEON's u16 operations. Coordinates (f32x16) are
// bit-cast into the r/g (x) and b/a (y) registers, exactly like upstream's
// `split`/`join`.

///|
let lowp_stage_width : Int = 16

///|
struct LowpPipeline {
  pixmap : SubPixmapMut
  mask_ctx : MaskCtx
  aa_mask_ctx : AAMaskCtx
  ctx : Context
  r : FixedArray[Int]
  g : FixedArray[Int]
  b : FixedArray[Int]
  a : FixedArray[Int]
  dr : FixedArray[Int]
  dg : FixedArray[Int]
  db : FixedArray[Int]
  da : FixedArray[Int]
  mut tail : Int
  mut dx : Int
  mut dy : Int
}

///|
fn lanes16() -> FixedArray[Int] {
  FixedArray::make(16, 0)
}

///|
fn lowp_start(
  stages : Array[Stage],
  rect : ScreenIntRect,
  aa_mask_ctx : AAMaskCtx,
  mask_ctx : MaskCtx,
  ctx : Context,
  pixmap : SubPixmapMut,
) -> Unit {
  let p : LowpPipeline = {
    pixmap,
    mask_ctx,
    aa_mask_ctx,
    ctx,
    r: lanes16(),
    g: lanes16(),
    b: lanes16(),
    a: lanes16(),
    dr: lanes16(),
    dg: lanes16(),
    db: lanes16(),
    da: lanes16(),
    tail: 0,
    dx: 0,
    dy: 0,
  }
  for y in rect.y()..<rect.bottom() {
    let mut x = rect.x()
    let end = rect.right()
    while x + lowp_stage_width <= end {
      p.dx = x
      p.dy = y
      p.tail = lowp_stage_width
      p.run(stages)
      x += lowp_stage_width
    }
    if x != end {
      p.dx = x
      p.dy = y
      p.tail = end - x
      p.run(stages)
    }
  }
}

///|
fn LowpPipeline::run(self : LowpPipeline, stages : Array[Stage]) -> Unit {
  for stage in stages {
    if !self.stage(stage) {
      return
    }
  }
}

///|
fn u16(v : Int) -> Int {
  v & 0xFFFF
}

///|
fn div255(v : Int) -> Int {
  // Skia uses `vrshrq_n_u16(vrsraq_n_u16(v, v, 8), 8)` here when NEON is
  // available, but it doesn't affect performance much and breaks
  // reproducible result. Ignore it.
  u16(v + 255) >> 8
}

///|
fn inv16(v : Int) -> Int {
  u16(255 - v)
}

///|
fn mul16(a : Int, b : Int) -> Int {
  u16(a * b)
}

///|
fn from_float(f : Float) -> Int {
  f32_to_u16(f * 255.0 + 0.5)
}

///|
fn lerp16(from : Int, to : Int, t : Int) -> Int {
  div255(u16(mul16(from, inv16(t)) + mul16(to, t)))
}

///|
/// `join(lo, hi)[i]`: the f32 lane `i` (0..16) of the two registers.
fn join_lane(lo : FixedArray[Int], hi : FixedArray[Int], i : Int) -> Float {
  let (reg, j) = if i < 8 { (lo, i) } else { (hi, i - 8) }
  Float::reinterpret_from_uint(
    reg[2 * j].reinterpret_as_uint() |
    (reg[2 * j + 1].reinterpret_as_uint() << 16),
  )
}

///|
fn join(lo : FixedArray[Int], hi : FixedArray[Int]) -> FixedArray[Float] {
  FixedArray::makei(16, i => join_lane(lo, hi, i))
}

///|
fn split(
  v : FixedArray[Float],
  lo : FixedArray[Int],
  hi : FixedArray[Int],
) -> Unit {
  for i in 0..<16 {
    let bits = v[i].reinterpret_as_uint()
    let (reg, j) = if i < 8 { (lo, i) } else { (hi, i - 8) }
    reg[2 * j] = (bits & 0xFFFF).reinterpret_as_int()
    reg[2 * j + 1] = (bits >> 16).reinterpret_as_int()
  }
}

///|
/// Runs one stage. Returns whether the next stage should run.
fn LowpPipeline::stage(p : LowpPipeline, stage : Stage) -> Bool {
  match stage {
    MoveSourceToDestination =>
      for i in 0..<16 {
        p.dr[i] = p.r[i]
        p.dg[i] = p.g[i]
        p.db[i] = p.b[i]
        p.da[i] = p.a[i]
      }
    MoveDestinationToSource =>
      for i in 0..<16 {
        p.r[i] = p.dr[i]
        p.g[i] = p.dg[i]
        p.b[i] = p.db[i]
        p.a[i] = p.da[i]
      }
    Premultiply =>
      for i in 0..<16 {
        p.r[i] = div255(mul16(p.r[i], p.a[i]))
        p.g[i] = div255(mul16(p.g[i], p.a[i]))
        p.b[i] = div255(mul16(p.b[i], p.a[i]))
      }
    UniformColor => {
      let rgba = p.ctx.uniform_color.rgba
      for i in 0..<16 {
        p.r[i] = rgba[0]
        p.g[i] = rgba[1]
        p.b[i] = rgba[2]
        p.a[i] = rgba[3]
      }
    }
    SeedShader => {
      let dx = Float::from_int(p.dx)
      let x = FixedArray::makei(16, i => dx + (Float::from_int(i) + 0.5))
      let yv = Float::from_int(p.dy) + 0.5
      let y = FixedArray::make(16, yv)
      split(x, p.r, p.g)
      split(y, p.b, p.a)
    }
    LoadDestination => {
      let off = p.pixmap.offset_of(p.dx, p.dy)
      let data = p.pixmap.pixels
      for l in 0..<16 {
        let c = if l < p.tail { data[off + l] } else { 0 }
        p.dr[l] = (c & 0xFF).reinterpret_as_int()
        p.dg[l] = ((c >> 8) & 0xFF).reinterpret_as_int()
        p.db[l] = ((c >> 16) & 0xFF).reinterpret_as_int()
        p.da[l] = (c >> 24).reinterpret_as_int()
      }
    }
    Store => {
      let off = p.pixmap.offset_of(p.dx, p.dy)
      let data = p.pixmap.pixels
      for l in 0..<p.tail {
        data[off + l] = pack_rgba(p.r[l], p.g[l], p.b[l], p.a[l])
      }
    }
    LoadDestinationU8 => {
      let off = p.pixmap.offset_of(p.dx, p.dy)
      let data = p.pixmap.bytes
      for l in 0..<16 {
        p.da[l] = if l < p.tail { data[off + l].to_int() } else { 0 }
      }
    }
    StoreU8 => {
      let off = p.pixmap.offset_of(p.dx, p.dy)
      let data = p.pixmap.bytes
      for l in 0..<p.tail {
        data[off + l] = (p.a[l] & 0xFF).to_byte()
      }
    }
    LoadMaskU8 => {
      // Similar to mask_u8, but only loads the mask values without actually
      // masking the pipeline.
      let offset = p.mask_ctx.offset_of(p.dx, p.dy)
      for i in 0..<16 {
        p.r[i] = 0
        p.g[i] = 0
        p.b[i] = 0
        p.a[i] = if i < p.tail {
          p.mask_ctx.data[offset + i].to_int()
        } else {
          0
        }
      }
    }
    MaskU8 => {
      let offset = p.mask_ctx.offset_of(p.dx, p.dy)
      let c = lanes16()
      let mut all_zero = true
      for i in 0..<p.tail {
        c[i] = p.mask_ctx.data[offset + i].to_int()
        if c[i] != 0 {
          all_zero = false
        }
      }
      if all_zero {
        return false
      }
      for i in 0..<16 {
        p.r[i] = div255(mul16(p.r[i], c[i]))
        p.g[i] = div255(mul16(p.g[i], c[i]))
        p.b[i] = div255(mul16(p.b[i], c[i]))
        p.a[i] = div255(mul16(p.a[i], c[i]))
      }
    }
    ScaleU8 => {
      // Load u8xTail and cast it to u16x16.
      let (d0, d1) = p.aa_mask_ctx.copy_at_xy(p.dx, p.dy, p.tail)
      for i in 0..<16 {
        let c = if i == 0 { d0 } else if i == 1 { d1 } else { 0 }
        p.r[i] = div255(mul16(p.r[i], c))
        p.g[i] = div255(mul16(p.g[i], c))
        p.b[i] = div255(mul16(p.b[i], c))
        p.a[i] = div255(mul16(p.a[i], c))
      }
    }
    LerpU8 => {
      // Load u8xTail and cast it to u16x16.
      let (d0, d1) = p.aa_mask_ctx.copy_at_xy(p.dx, p.dy, p.tail)
      for i in 0..<16 {
        let c = if i == 0 { d0 } else if i == 1 { d1 } else { 0 }
        p.r[i] = lerp16(p.dr[i], p.r[i], c)
        p.g[i] = lerp16(p.dg[i], p.g[i], c)
        p.b[i] = lerp16(p.db[i], p.b[i], c)
        p.a[i] = lerp16(p.da[i], p.a[i], c)
      }
    }
    Scale1Float => {
      let c = from_float(p.ctx.current_coverage)
      for i in 0..<16 {
        p.r[i] = div255(mul16(p.r[i], c))
        p.g[i] = div255(mul16(p.g[i], c))
        p.b[i] = div255(mul16(p.b[i], c))
        p.a[i] = div255(mul16(p.a[i], c))
      }
    }
    Lerp1Float => {
      let c = from_float(p.ctx.current_coverage)
      for i in 0..<16 {
        p.r[i] = lerp16(p.dr[i], p.r[i], c)
        p.g[i] = lerp16(p.dg[i], p.g[i], c)
        p.b[i] = lerp16(p.db[i], p.b[i], c)
        p.a[i] = lerp16(p.da[i], p.a[i], c)
      }
    }
    Clear => p.blend((_, _, _, _) => 0)
    SourceAtop =>
      p.blend((s, d, sa, da) => div255(u16(mul16(s, da) + mul16(d, inv16(sa)))))
    DestinationAtop =>
      p.blend((s, d, sa, da) => div255(u16(mul16(d, sa) + mul16(s, inv16(da)))))
    SourceIn => p.blend((s, _, _, da) => div255(mul16(s, da)))
    DestinationIn => p.blend((_, d, sa, _) => div255(mul16(d, sa)))
    SourceOut => p.blend((s, _, _, da) => div255(mul16(s, inv16(da))))
    DestinationOut => p.blend((_, d, sa, _) => div255(mul16(d, inv16(sa))))
    SourceOver => p.blend((s, d, sa, _) => u16(s + div255(mul16(d, inv16(sa)))))
    DestinationOver =>
      p.blend((s, d, _, da) => u16(d + div255(mul16(s, inv16(da)))))
    Modulate => p.blend((s, d, _, _) => div255(mul16(s, d)))
    Multiply =>
      p.blend((s, d, sa, da) => {
        div255(u16(mul16(s, inv16(da)) + mul16(d, inv16(sa)) + mul16(s, d)))
      })
    Screen => p.blend((s, d, _, _) => u16(s + d - div255(mul16(s, d))))
    Xor =>
      p.blend((s, d, sa, da) => {
        div255(u16(mul16(s, inv16(da)) + mul16(d, inv16(sa))))
      })
    Plus =>
      p.blend((s, d, _, _) => {
        let v = u16(s + d)
        if v < 255 {
          v
        } else {
          255
        }
      })
    Darken =>
      p.blend2((s, d, sa, da) => {
        let x = mul16(s, da)
        let y = mul16(d, sa)
        u16(s + d - div255(if x > y { x } else { y }))
      })
    Lighten =>
      p.blend2((s, d, sa, da) => {
        let x = mul16(s, da)
        let y = mul16(d, sa)
        u16(s + d - div255(if x < y { x } else { y }))
      })
    Exclusion =>
      p.blend2((s, d, _, _) => u16(s + d - mul16(2, div255(mul16(s, d)))))
    Difference =>
      p.blend2((s, d, sa, da) => {
        let x = mul16(s, da)
        let y = mul16(d, sa)
        u16(s + d - mul16(2, div255(if x < y { x } else { y })))
      })
    HardLight =>
      p.blend2((s, d, sa, da) => {
        div255(
          u16(
            mul16(s, inv16(da)) +
            mul16(d, inv16(sa)) +
            (if u16(s + s) <= sa {
              mul16(mul16(2, s), d)
            } else {
              u16(mul16(sa, da) - mul16(mul16(2, u16(sa - s)), u16(da - d)))
            }),
          ),
        )
      })
    Overlay =>
      p.blend2((s, d, sa, da) => {
        div255(
          u16(
            mul16(s, inv16(da)) +
            mul16(d, inv16(sa)) +
            (if u16(d + d) <= da {
              mul16(mul16(2, s), d)
            } else {
              u16(mul16(sa, da) - mul16(mul16(2, u16(sa - s)), u16(da - d)))
            }),
          ),
        )
      })
    SourceOverRgba => {
      let off = p.pixmap.offset_of(p.dx, p.dy)
      let data = p.pixmap.pixels
      for l in 0..<16 {
        let c = if l < p.tail { data[off + l] } else { 0 }
        p.dr[l] = (c & 0xFF).reinterpret_as_int()
        p.dg[l] = ((c >> 8) & 0xFF).reinterpret_as_int()
        p.db[l] = ((c >> 16) & 0xFF).reinterpret_as_int()
        p.da[l] = (c >> 24).reinterpret_as_int()
      }
      for i in 0..<16 {
        let inv_a = inv16(p.a[i])
        p.r[i] = u16(p.r[i] + div255(mul16(p.dr[i], inv_a)))
        p.g[i] = u16(p.g[i] + div255(mul16(p.dg[i], inv_a)))
        p.b[i] = u16(p.b[i] + div255(mul16(p.db[i], inv_a)))
        p.a[i] = u16(p.a[i] + div255(mul16(p.da[i], inv_a)))
      }
      for l in 0..<p.tail {
        data[off + l] = pack_rgba(p.r[l], p.g[l], p.b[l], p.a[l])
      }
    }
    Transform => {
      let ts = p.ctx.transform
      let x = join(p.r, p.g)
      let y = join(p.b, p.a)
      let nx = FixedArray::makei(16, i => {
        mad(x[i], ts.sx, mad(y[i], ts.kx, ts.tx))
      })
      let ny = FixedArray::makei(16, i => {
        mad(x[i], ts.ky, mad(y[i], ts.sy, ts.ty))
      })
      split(nx, p.r, p.g)
      split(ny, p.b, p.a)
    }
    PadX1 => {
      let x = join(p.r, p.g)
      for i in 0..<16 {
        x[i] = vnormalize(x[i])
      }
      split(x, p.r, p.g)
    }
    ReflectX1 => {
      let x = join(p.r, p.g)
      for i in 0..<16 {
        let v = x[i]
        x[i] = vnormalize(vabs(v - 1.0 - two(vfloor16((v - 1.0) * 0.5)) - 1.0))
      }
      split(x, p.r, p.g)
    }
    RepeatX1 => {
      let x = join(p.r, p.g)
      for i in 0..<16 {
        x[i] = vnormalize(x[i] - vfloor16(x[i]))
      }
      split(x, p.r, p.g)
    }
    Gradient => {
      let ctx = p.ctx.gradient
      // N.B. The loop starts at 1 because idx 0 is the color to use before
      // the first stop.
      let t = join(p.r, p.g)
      let rf = FixedArray::make(16, (0.0 : Float))
      let gf = FixedArray::make(16, (0.0 : Float))
      let bf = FixedArray::make(16, (0.0 : Float))
      let af = FixedArray::make(16, (0.0 : Float))
      for l in 0..<16 {
        let mut idx = 0
        for i in 1..<ctx.len {
          let tt = ctx.t_values[i]
          if t[l] >= tt {
            idx += 1
          }
        }
        let f = ctx.factors[idx & 0xFFFF]
        let b = ctx.biases[idx & 0xFFFF]
        rf[l] = mad(t[l], f.r, b.r)
        gf[l] = mad(t[l], f.g, b.g)
        bf[l] = mad(t[l], f.b, b.b)
        af[l] = mad(t[l], f.a, b.a)
      }
      round_f32_to_u16(rf, gf, bf, af, p.r, p.g, p.b, p.a)
    }
    EvenlySpaced2StopGradient => {
      let ctx = p.ctx.evenly_spaced_2_stop_gradient
      let t = join(p.r, p.g)
      round_f32_to_u16(
        FixedArray::makei(16, i => mad(t[i], ctx.factor.r, ctx.bias.r)),
        FixedArray::makei(16, i => mad(t[i], ctx.factor.g, ctx.bias.g)),
        FixedArray::makei(16, i => mad(t[i], ctx.factor.b, ctx.bias.b)),
        FixedArray::makei(16, i => mad(t[i], ctx.factor.a, ctx.bias.a)),
        p.r,
        p.g,
        p.b,
        p.a,
      )
    }
    XYToRadius => {
      let x = join(p.r, p.g)
      let y = join(p.b, p.a)
      let x = FixedArray::makei(16, i => (x[i] * x[i] + y[i] * y[i]).sqrt())
      split(x, p.r, p.g)
      split(y, p.b, p.a)
    }
    _ => () // null_fn (never compiled into a lowp pipeline)
  }
  true
}

///|
/// `blend_fn!`.
fn LowpPipeline::blend(
  p : LowpPipeline,
  f : (Int, Int, Int, Int) -> Int,
) -> Unit {
  for i in 0..<16 {
    let a = p.a[i]
    let da = p.da[i]
    p.r[i] = f(p.r[i], p.dr[i], a, da)
    p.g[i] = f(p.g[i], p.dg[i], a, da)
    p.b[i] = f(p.b[i], p.db[i], a, da)
    p.a[i] = f(a, da, a, da)
  }
}

///|
/// `blend_fn2!`: the same logic applied to color, and source_over for alpha.
fn LowpPipeline::blend2(
  p : LowpPipeline,
  f : (Int, Int, Int, Int) -> Int,
) -> Unit {
  for i in 0..<16 {
    let a = p.a[i]
    let da = p.da[i]
    p.r[i] = f(p.r[i], p.dr[i], a, da)
    p.g[i] = f(p.g[i], p.dg[i], a, da)
    p.b[i] = f(p.b[i], p.db[i], a, da)
    p.a[i] = u16(a + div255(mul16(da, inv16(a))))
  }
}

///|
fn round_f32_to_u16(
  rf : FixedArray[Float],
  gf : FixedArray[Float],
  bf : FixedArray[Float],
  af : FixedArray[Float],
  r : FixedArray[Int],
  g : FixedArray[Int],
  b : FixedArray[Int],
  a : FixedArray[Int],
) -> Unit {
  // TODO: may produce a slightly different result to Skia
  //       affects the two_stops_linear_mirror test
  for i in 0..<16 {
    let rr = vnormalize(rf[i]) * 255.0 + 0.5
    let gg = vnormalize(gf[i]) * 255.0 + 0.5
    let bb = vnormalize(bf[i]) * 255.0 + 0.5
    let aa = af[i] * 255.0 + 0.5
    r[i] = f32_to_u16(rr)
    g[i] = f32_to_u16(gg)
    b[i] = f32_to_u16(bb)
    a[i] = f32_to_u16(aa)
  }
}
