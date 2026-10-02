// Port of `tiny-skia/src/pipeline/highp.rs`.
//
// A high precision raster pipeline implementation.
//
// Unlike lowp, this one implements all stages. Just like Skia, this pipeline
// is implemented using f32x8; the lanes are `FixedArray[Float]`s here and
// every operation is applied per lane (see `wide.mbt`).

///|
let highp_stage_width : Int = 8

///|
struct HighpPipeline {
  pixmap_src : Pixmap
  pixmap_dst : SubPixmapMut
  ctx : Context
  mask_ctx : MaskCtx
  aa_mask_ctx : AAMaskCtx
  r : FixedArray[Float]
  g : FixedArray[Float]
  b : FixedArray[Float]
  a : FixedArray[Float]
  dr : FixedArray[Float]
  dg : FixedArray[Float]
  db : FixedArray[Float]
  da : FixedArray[Float]
  mut tail : Int
  mut dx : Int
  mut dy : Int
}

///|
fn lanes8() -> FixedArray[Float] {
  FixedArray::make(8, 0.0)
}

///|
fn highp_start(
  stages : Array[Stage],
  rect : ScreenIntRect,
  aa_mask_ctx : AAMaskCtx,
  mask_ctx : MaskCtx,
  ctx : Context,
  pixmap_src : Pixmap,
  pixmap_dst : SubPixmapMut,
) -> Unit {
  let p : HighpPipeline = {
    pixmap_src,
    pixmap_dst,
    ctx,
    mask_ctx,
    aa_mask_ctx,
    r: lanes8(),
    g: lanes8(),
    b: lanes8(),
    a: lanes8(),
    dr: lanes8(),
    dg: lanes8(),
    db: lanes8(),
    da: lanes8(),
    tail: 0,
    dx: 0,
    dy: 0,
  }
  for y in rect.y()..<rect.bottom() {
    let mut x = rect.x()
    let end = rect.right()
    while x + highp_stage_width <= end {
      p.dx = x
      p.dy = y
      p.tail = highp_stage_width
      p.run(stages)
      x += highp_stage_width
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
fn HighpPipeline::run(self : HighpPipeline, stages : Array[Stage]) -> Unit {
  for stage in stages {
    if !self.stage(stage) {
      return
    }
  }
}

///|
/// Runs one stage. Returns whether the next stage should run.
fn HighpPipeline::stage(p : HighpPipeline, stage : Stage) -> Bool {
  match stage {
    MoveSourceToDestination =>
      for i in 0..<8 {
        p.dr[i] = p.r[i]
        p.dg[i] = p.g[i]
        p.db[i] = p.b[i]
        p.da[i] = p.a[i]
      }
    MoveDestinationToSource =>
      for i in 0..<8 {
        p.r[i] = p.dr[i]
        p.g[i] = p.dg[i]
        p.b[i] = p.db[i]
        p.a[i] = p.da[i]
      }
    Clamp0 =>
      for i in 0..<8 {
        p.r[i] = vmax(p.r[i], 0.0)
        p.g[i] = vmax(p.g[i], 0.0)
        p.b[i] = vmax(p.b[i], 0.0)
        p.a[i] = vmax(p.a[i], 0.0)
      }
    ClampA =>
      for i in 0..<8 {
        p.r[i] = vmin(p.r[i], 1.0)
        p.g[i] = vmin(p.g[i], 1.0)
        p.b[i] = vmin(p.b[i], 1.0)
        p.a[i] = vmin(p.a[i], 1.0)
      }
    Premultiply =>
      for i in 0..<8 {
        p.r[i] = p.r[i] * p.a[i]
        p.g[i] = p.g[i] * p.a[i]
        p.b[i] = p.b[i] * p.a[i]
      }
    UniformColor => {
      let ctx = p.ctx.uniform_color
      for i in 0..<8 {
        p.r[i] = ctx.r
        p.g[i] = ctx.g
        p.b[i] = ctx.b
        p.a[i] = ctx.a
      }
    }
    SeedShader => {
      let dx = Float::from_int(p.dx)
      let dy = Float::from_int(p.dy) + 0.5
      for i in 0..<8 {
        p.r[i] = dx + (Float::from_int(i) + 0.5)
        p.g[i] = dy
        p.b[i] = 1.0
        p.a[i] = 0.0
        p.dr[i] = 0.0
        p.dg[i] = 0.0
        p.db[i] = 0.0
        p.da[i] = 0.0
      }
    }
    LoadDestination => {
      let off = p.pixmap_dst.offset_of(p.dx, p.dy)
      load_8888_tail(p.tail, p.pixmap_dst.pixels, off, p.dr, p.dg, p.db, p.da)
    }
    Store => {
      let off = p.pixmap_dst.offset_of(p.dx, p.dy)
      store_8888_tail(p.r, p.g, p.b, p.a, p.tail, p.pixmap_dst.pixels, off)
    }
    // Currently, all mask/A8 pixmaps are handled by lowp.
    LoadDestinationU8 | StoreU8 | LoadMaskU8 => () // unreachable
    Gather => {
      let ix = gather_ix(p.pixmap_src, p.r, p.g)
      load_8888_gather(p.pixmap_src, ix, p.r, p.g, p.b, p.a)
    }
    MaskU8 => {
      let offset = p.mask_ctx.offset_of(p.dx, p.dy)
      let c = lanes8()
      for i in 0..<p.tail {
        c[i] = Float::from_int(p.mask_ctx.data[offset + i].to_int())
      }
      let mut all_zero = true
      for i in 0..<8 {
        c[i] = c[i] / 255.0
        if c[i] != 0.0 {
          all_zero = false
        }
      }
      if all_zero {
        return false
      }
      for i in 0..<8 {
        p.r[i] = p.r[i] * c[i]
        p.g[i] = p.g[i] * c[i]
        p.b[i] = p.b[i] * c[i]
        p.a[i] = p.a[i] * c[i]
      }
    }
    ScaleU8 => {
      // Load u8xTail and cast it to f32x8.
      let (d0, d1) = p.aa_mask_ctx.copy_at_xy(p.dx, p.dy, p.tail)
      let c = lanes8()
      c[0] = Float::from_int(d0) / 255.0
      c[1] = Float::from_int(d1) / 255.0
      for i in 0..<8 {
        p.r[i] = p.r[i] * c[i]
        p.g[i] = p.g[i] * c[i]
        p.b[i] = p.b[i] * c[i]
        p.a[i] = p.a[i] * c[i]
      }
    }
    LerpU8 => {
      // Load u8xTail and cast it to f32x8.
      let (d0, d1) = p.aa_mask_ctx.copy_at_xy(p.dx, p.dy, p.tail)
      let c = lanes8()
      c[0] = Float::from_int(d0) / 255.0
      c[1] = Float::from_int(d1) / 255.0
      for i in 0..<8 {
        p.r[i] = lerp(p.dr[i], p.r[i], c[i])
        p.g[i] = lerp(p.dg[i], p.g[i], c[i])
        p.b[i] = lerp(p.db[i], p.b[i], c[i])
        p.a[i] = lerp(p.da[i], p.a[i], c[i])
      }
    }
    Scale1Float => {
      let c = p.ctx.current_coverage
      for i in 0..<8 {
        p.r[i] = p.r[i] * c
        p.g[i] = p.g[i] * c
        p.b[i] = p.b[i] * c
        p.a[i] = p.a[i] * c
      }
    }
    Lerp1Float => {
      let c = p.ctx.current_coverage
      for i in 0..<8 {
        p.r[i] = lerp(p.dr[i], p.r[i], c)
        p.g[i] = lerp(p.dg[i], p.g[i], c)
        p.b[i] = lerp(p.db[i], p.b[i], c)
        p.a[i] = lerp(p.da[i], p.a[i], c)
      }
    }
    Clear => p.blend((_, _, _, _) => 0.0)
    SourceAtop => p.blend((s, d, sa, da) => s * da + d * inv(sa))
    DestinationAtop => p.blend((s, d, sa, da) => d * sa + s * inv(da))
    SourceIn => p.blend((s, _, _, da) => s * da)
    DestinationIn => p.blend((_, d, sa, _) => d * sa)
    SourceOut => p.blend((s, _, _, da) => s * inv(da))
    DestinationOut => p.blend((_, d, sa, _) => d * inv(sa))
    SourceOver => p.blend((s, d, sa, _) => mad(d, inv(sa), s))
    DestinationOver => p.blend((s, d, _, da) => mad(s, inv(da), d))
    Modulate => p.blend((s, d, _, _) => s * d)
    Multiply => p.blend((s, d, sa, da) => s * inv(da) + d * inv(sa) + s * d)
    Screen => p.blend((s, d, _, _) => s + d - s * d)
    Xor => p.blend((s, d, sa, da) => s * inv(da) + d * inv(sa))
    Plus => p.blend((s, d, _, _) => vmin(s + d, 1.0))
    Darken => p.blend2((s, d, sa, da) => s + d - vmax(s * da, d * sa))
    Lighten => p.blend2((s, d, sa, da) => s + d - vmin(s * da, d * sa))
    Difference => p.blend2((s, d, sa, da) => s + d - two(vmin(s * da, d * sa)))
    Exclusion => p.blend2((s, d, _, _) => s + d - two(s * d))
    ColorBurn =>
      p.blend2((s, d, sa, da) => {
        if d == da {
          d + s * inv(da)
        } else if s == 0.0 {
          d * inv(sa)
        } else {
          sa * (da - vmin(da, (da - d) * sa * vrecip_fast(s))) +
          s * inv(da) +
          d * inv(sa)
        }
      })
    ColorDodge =>
      p.blend2((s, d, sa, da) => {
        if d == 0.0 {
          s * inv(da)
        } else if s == sa {
          s + d * inv(sa)
        } else {
          sa * vmin(da, d * sa * vrecip_fast(sa - s)) +
          s * inv(da) +
          d * inv(sa)
        }
      })
    HardLight =>
      p.blend2((s, d, sa, da) => {
        s * inv(da) +
        d * inv(sa) +
        (if two(s) <= sa {
          two(s * d)
        } else {
          sa * da - two((da - d) * (sa - s))
        })
      })
    Overlay =>
      p.blend2((s, d, sa, da) => {
        s * inv(da) +
        d * inv(sa) +
        (if two(d) <= da {
          two(s * d)
        } else {
          sa * da - two((da - d) * (sa - s))
        })
      })
    SoftLight => p.blend2(soft_light_lane)
    Hue => p.blend3(hue_k)
    Saturation => p.blend3(saturation_k)
    Color => p.blend3(color_k)
    Luminosity => p.blend3(luminosity_k)
    SourceOverRgba => {
      let off = p.pixmap_dst.offset_of(p.dx, p.dy)
      let pixels = p.pixmap_dst.pixels
      load_8888_tail(p.tail, pixels, off, p.dr, p.dg, p.db, p.da)
      for i in 0..<8 {
        let inv_a = inv(p.a[i])
        p.r[i] = mad(p.dr[i], inv_a, p.r[i])
        p.g[i] = mad(p.dg[i], inv_a, p.g[i])
        p.b[i] = mad(p.db[i], inv_a, p.b[i])
        p.a[i] = mad(p.da[i], inv_a, p.a[i])
      }
      store_8888_tail(p.r, p.g, p.b, p.a, p.tail, pixels, off)
    }
    Transform => {
      let ts = p.ctx.transform
      for i in 0..<8 {
        let tr = mad(p.r[i], ts.sx, mad(p.g[i], ts.kx, ts.tx))
        let tg = mad(p.r[i], ts.ky, mad(p.g[i], ts.sy, ts.ty))
        p.r[i] = tr
        p.g[i] = tg
      }
    }
    Reflect => {
      let cx = p.ctx.limit_x
      let cy = p.ctx.limit_y
      for i in 0..<8 {
        p.r[i] = exclusive_reflect(p.r[i], cx.scale, cx.inv_scale)
        p.g[i] = exclusive_reflect(p.g[i], cy.scale, cy.inv_scale)
      }
    }
    Repeat => {
      let cx = p.ctx.limit_x
      let cy = p.ctx.limit_y
      for i in 0..<8 {
        p.r[i] = exclusive_repeat(p.r[i], cx.scale, cx.inv_scale)
        p.g[i] = exclusive_repeat(p.g[i], cy.scale, cy.inv_scale)
      }
    }
    Bilinear => p.bilinear()
    Bicubic => p.bicubic()
    PadX1 =>
      for i in 0..<8 {
        p.r[i] = vnormalize(p.r[i])
      }
    ReflectX1 =>
      for i in 0..<8 {
        let r = p.r[i]
        p.r[i] = vnormalize(vabs(r - 1.0 - two(vfloor8((r - 1.0) * 0.5)) - 1.0))
      }
    RepeatX1 =>
      for i in 0..<8 {
        p.r[i] = vnormalize(p.r[i] - vfloor8(p.r[i]))
      }
    Gradient => {
      let ctx = p.ctx.gradient
      // N.B. The loop starts at 1 because idx 0 is the color to use before
      // the first stop.
      for l in 0..<8 {
        let t = p.r[l]
        let mut idx = 0
        for i in 1..<ctx.len {
          let tt = ctx.t_values[i]
          if t >= tt {
            idx += 1
          }
        }
        let f = ctx.factors[idx]
        let b = ctx.biases[idx]
        p.r[l] = mad(t, f.r, b.r)
        p.g[l] = mad(t, f.g, b.g)
        p.b[l] = mad(t, f.b, b.b)
        p.a[l] = mad(t, f.a, b.a)
      }
    }
    EvenlySpaced2StopGradient => {
      let ctx = p.ctx.evenly_spaced_2_stop_gradient
      for i in 0..<8 {
        let t = p.r[i]
        p.r[i] = mad(t, ctx.factor.r, ctx.bias.r)
        p.g[i] = mad(t, ctx.factor.g, ctx.bias.g)
        p.b[i] = mad(t, ctx.factor.b, ctx.bias.b)
        p.a[i] = mad(t, ctx.factor.a, ctx.bias.a)
      }
    }
    XYToUnitAngle =>
      for i in 0..<8 {
        let x = p.r[i]
        let y = p.g[i]
        let x_abs = vabs(x)
        let y_abs = vabs(y)
        let slope = vmin(x_abs, y_abs) / vmax(x_abs, y_abs)
        let s = slope * slope
        // Use a 7th degree polynomial to approximate atan.
        // This was generated using sollya.gforge.inria.fr.
        // A float optimized polynomial was generated using the following
        // command.
        // P1 = fpminimax((1/(2*Pi))*atan(x),[|1,3,5,7|],[|24...|],[2^(-40),1],relative);
        let phi = slope *
          (
            (0.15912117063999176025390625 : Float) +
            s *
            (
              (-5.185396969318389892578125e-2 : Float) +
              s *
              (
                (2.476101927459239959716796875e-2 : Float) +
                s * (-7.0547382347285747528076171875e-3 : Float)
              )
            )
          )
        let phi = if x_abs < y_abs { (0.25 : Float) - phi } else { phi }
        let phi = if x < 0.0 { (0.5 : Float) - phi } else { phi }
        let phi = if y < 0.0 { (1.0 : Float) - phi } else { phi }
        let phi : Float = if phi != phi { 0.0 } else { phi }
        p.r[i] = phi
      }
    XYToRadius =>
      for i in 0..<8 {
        let x2 = p.r[i] * p.r[i]
        let y2 = p.g[i] * p.g[i]
        p.r[i] = (x2 + y2).sqrt()
      }
    XYTo2PtConicalFocalOnCircle =>
      for i in 0..<8 {
        let x = p.r[i]
        let y = p.g[i]
        p.r[i] = x + y * y / x
      }
    XYTo2PtConicalWellBehaved => {
      let p0 = p.ctx.two_point_conical_gradient.p0
      for i in 0..<8 {
        let x = p.r[i]
        let y = p.g[i]
        p.r[i] = (x * x + y * y).sqrt() - x * p0
      }
    }
    XYTo2PtConicalGreater => {
      let p0 = p.ctx.two_point_conical_gradient.p0
      for i in 0..<8 {
        let x = p.r[i]
        let y = p.g[i]
        p.r[i] = (x * x - y * y).sqrt() - x * p0
      }
    }
    XYTo2PtConicalSmaller => {
      let p0 = p.ctx.two_point_conical_gradient.p0
      for i in 0..<8 {
        let x = p.r[i]
        let y = p.g[i]
        p.r[i] = vneg((x * x - y * y).sqrt()) - x * p0
      }
    }
    XYTo2PtConicalStrip => {
      let p0 = p.ctx.two_point_conical_gradient.p0
      for i in 0..<8 {
        let x = p.r[i]
        let y = p.g[i]
        p.r[i] = x + (p0 - y * y).sqrt()
      }
    }
    Mask2PtConicalNan => {
      let mask = p.ctx.two_point_conical_gradient.mask
      for i in 0..<8 {
        let t = p.r[i]
        let is_degenerate = t != t
        p.r[i] = if is_degenerate { 0.0 } else { t }
        mask[i] = if is_degenerate { 0 } else { 0xFFFFFFFF }
      }
    }
    Mask2PtConicalDegenerates => {
      let mask = p.ctx.two_point_conical_gradient.mask
      for i in 0..<8 {
        let t = p.r[i]
        let is_degenerate = t <= 0.0 || t != t
        p.r[i] = if is_degenerate { 0.0 } else { t }
        mask[i] = if is_degenerate { 0 } else { 0xFFFFFFFF }
      }
    }
    ApplyVectorMask => {
      let mask = p.ctx.two_point_conical_gradient.mask
      for i in 0..<8 {
        let m = mask[i]
        p.r[i] = Float::reinterpret_from_uint(p.r[i].reinterpret_as_uint() & m)
        p.g[i] = Float::reinterpret_from_uint(p.g[i].reinterpret_as_uint() & m)
        p.b[i] = Float::reinterpret_from_uint(p.b[i].reinterpret_as_uint() & m)
        p.a[i] = Float::reinterpret_from_uint(p.a[i].reinterpret_as_uint() & m)
      }
    }
    Alter2PtConicalCompensateFocal => {
      let p1 = p.ctx.two_point_conical_gradient.p1
      for i in 0..<8 {
        p.r[i] = p.r[i] + p1
      }
    }
    Alter2PtConicalUnswap =>
      for i in 0..<8 {
        p.r[i] = (1.0 : Float) - p.r[i]
      }
    NegateX =>
      for i in 0..<8 {
        p.r[i] = vneg(p.r[i])
      }
    ApplyConcentricScaleBias => {
      let ctx = p.ctx.two_point_conical_gradient
      // Apply t = t * scale + bias for concentric gradients
      for i in 0..<8 {
        p.r[i] = p.r[i] * ctx.p0 + ctx.p1
      }
    }
    GammaExpand2 =>
      for i in 0..<8 {
        p.r[i] = p.r[i] * p.r[i]
        p.g[i] = p.g[i] * p.g[i]
        p.b[i] = p.b[i] * p.b[i]
      }
    GammaExpandDestination2 =>
      for i in 0..<8 {
        p.dr[i] = p.dr[i] * p.dr[i]
        p.dg[i] = p.dg[i] * p.dg[i]
        p.db[i] = p.db[i] * p.db[i]
      }
    GammaCompress2 =>
      for i in 0..<8 {
        p.r[i] = p.r[i].sqrt()
        p.g[i] = p.g[i].sqrt()
        p.b[i] = p.b[i].sqrt()
      }
    GammaExpand22 =>
      for i in 0..<8 {
        p.r[i] = vpowf(p.r[i], 2.2)
        p.g[i] = vpowf(p.g[i], 2.2)
        p.b[i] = vpowf(p.b[i], 2.2)
      }
    GammaExpandDestination22 =>
      for i in 0..<8 {
        p.dr[i] = vpowf(p.dr[i], 2.2)
        p.dg[i] = vpowf(p.dg[i], 2.2)
        p.db[i] = vpowf(p.db[i], 2.2)
      }
    GammaCompress22 =>
      for i in 0..<8 {
        p.r[i] = vpowf(p.r[i], 0.45454545)
        p.g[i] = vpowf(p.g[i], 0.45454545)
        p.b[i] = vpowf(p.b[i], 0.45454545)
      }
    GammaExpandSrgb =>
      for i in 0..<8 {
        p.r[i] = srgb_expand(p.r[i])
        p.g[i] = srgb_expand(p.g[i])
        p.b[i] = srgb_expand(p.b[i])
      }
    GammaExpandDestinationSrgb =>
      for i in 0..<8 {
        p.dr[i] = srgb_expand(p.dr[i])
        p.dg[i] = srgb_expand(p.dg[i])
        p.db[i] = srgb_expand(p.db[i])
      }
    GammaCompressSrgb =>
      for i in 0..<8 {
        p.r[i] = srgb_compress(p.r[i])
        p.g[i] = srgb_compress(p.g[i])
        p.b[i] = srgb_compress(p.b[i])
      }
  }
  true
}

///|
/// `blend_fn!`: the same function for color and alpha.
fn HighpPipeline::blend(
  p : HighpPipeline,
  f : (Float, Float, Float, Float) -> Float,
) -> Unit {
  for i in 0..<8 {
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
fn HighpPipeline::blend2(
  p : HighpPipeline,
  f : (Float, Float, Float, Float) -> Float,
) -> Unit {
  for i in 0..<8 {
    let a = p.a[i]
    let da = p.da[i]
    p.r[i] = f(p.r[i], p.dr[i], a, da)
    p.g[i] = f(p.g[i], p.dg[i], a, da)
    p.b[i] = f(p.b[i], p.db[i], a, da)
    p.a[i] = mad(da, inv(a), a)
  }
}

///|
/// `blend_fn3!`: non-separable blend modes.
fn HighpPipeline::blend3(
  p : HighpPipeline,
  f : (Float, Float, Float, Float, Float, Float, Float, Float) -> (
    Float,
    Float,
    Float,
    Float,
  ),
) -> Unit {
  for i in 0..<8 {
    let (tr, tg, tb, ta) = f(
      p.r[i],
      p.g[i],
      p.b[i],
      p.a[i],
      p.dr[i],
      p.dg[i],
      p.db[i],
      p.da[i],
    )
    p.r[i] = tr
    p.g[i] = tg
    p.b[i] = tb
    p.a[i] = ta
  }
}

///|
fn soft_light_lane(s : Float, d : Float, sa : Float, da : Float) -> Float {
  let m = if da > 0.0 { d / da } else { 0.0 }
  let s2 = two(s)
  let m4 = two(two(m))

  // The logic forks three ways:
  //    1. dark src?
  //    2. light src, dark dst?
  //    3. light src, light dst?
  let dark_src = d * (sa + (s2 - sa) * ((1.0 : Float) - m))
  let dark_dst = (m4 * m4 + m4) * (m - 1.0) + (7.0 : Float) * m
  let lite_dst = m.sqrt() - m
  let lite_src = d * sa +
    da * (s2 - sa) * (if two(two(d)) <= da { dark_dst } else { lite_dst }) // 2 or 3?
  s * inv(da) + d * inv(sa) + (if s2 <= sa { dark_src } else { lite_src }) // 1 or (2 or 3)?
}

// We're basing our implementation of non-separable blend modes on
//   https://www.w3.org/TR/compositing-1/#blendingnonseparable.
// and
//   https://www.khronos.org/registry/OpenGL/specs/es/3.2/es_spec_3.2.pdf
// They're equivalent, but ES' math has been better simplified.
//
// Anything extra we add beyond that is to make the math work with premul
// inputs.

///|
fn hue_k(
  r : Float,
  g : Float,
  b : Float,
  a : Float,
  dr : Float,
  dg : Float,
  db : Float,
  da : Float,
) -> (Float, Float, Float, Float) {
  let (rr, gg, bb) = set_sat(r * a, g * a, b * a, sat(dr, dg, db) * a)
  let (rr, gg, bb) = set_lum(rr, gg, bb, lum(dr, dg, db) * a)
  let (rr, gg, bb) = clip_color(rr, gg, bb, a * da)
  let r = r * inv(da) + dr * inv(a) + rr
  let g = g * inv(da) + dg * inv(a) + gg
  let b = b * inv(da) + db * inv(a) + bb
  let a = a + da - a * da
  (r, g, b, a)
}

///|
fn saturation_k(
  r : Float,
  g : Float,
  b : Float,
  a : Float,
  dr : Float,
  dg : Float,
  db : Float,
  da : Float,
) -> (Float, Float, Float, Float) {
  let (rr, gg, bb) = set_sat(dr * a, dg * a, db * a, sat(r, g, b) * da)
  let (rr, gg, bb) = set_lum(rr, gg, bb, lum(dr, dg, db) * a) // (This is not redundant.)
  let (rr, gg, bb) = clip_color(rr, gg, bb, a * da)
  let r = r * inv(da) + dr * inv(a) + rr
  let g = g * inv(da) + dg * inv(a) + gg
  let b = b * inv(da) + db * inv(a) + bb
  let a = a + da - a * da
  (r, g, b, a)
}

///|
fn color_k(
  r : Float,
  g : Float,
  b : Float,
  a : Float,
  dr : Float,
  dg : Float,
  db : Float,
  da : Float,
) -> (Float, Float, Float, Float) {
  let (rr, gg, bb) = set_lum(r * da, g * da, b * da, lum(dr, dg, db) * a)
  let (rr, gg, bb) = clip_color(rr, gg, bb, a * da)
  let r = r * inv(da) + dr * inv(a) + rr
  let g = g * inv(da) + dg * inv(a) + gg
  let b = b * inv(da) + db * inv(a) + bb
  let a = a + da - a * da
  (r, g, b, a)
}

///|
fn luminosity_k(
  r : Float,
  g : Float,
  b : Float,
  a : Float,
  dr : Float,
  dg : Float,
  db : Float,
  da : Float,
) -> (Float, Float, Float, Float) {
  let (rr, gg, bb) = set_lum(dr * a, dg * a, db * a, lum(r, g, b) * da)
  let (rr, gg, bb) = clip_color(rr, gg, bb, a * da)
  let r = r * inv(da) + dr * inv(a) + rr
  let g = g * inv(da) + dg * inv(a) + gg
  let b = b * inv(da) + db * inv(a) + bb
  let a = a + da - a * da
  (r, g, b, a)
}

///|
fn sat(r : Float, g : Float, b : Float) -> Float {
  vmax(r, vmax(g, b)) - vmin(r, vmin(g, b))
}

///|
fn lum(r : Float, g : Float, b : Float) -> Float {
  r * (0.30 : Float) + g * (0.59 : Float) + b * (0.11 : Float)
}

///|
fn set_sat(r : Float, g : Float, b : Float, s : Float) -> (Float, Float, Float) {
  let mn = vmin(r, vmin(g, b))
  let mx = vmax(r, vmax(g, b))
  let sat = mx - mn

  // Map min channel to 0, max channel to s, and scale the middle
  // proportionally.
  fn scale(c : Float) -> Float {
    if sat == 0.0 {
      0.0
    } else {
      (c - mn) * s / sat
    }
  }

  (scale(r), scale(g), scale(b))
}

///|
fn set_lum(r : Float, g : Float, b : Float, l : Float) -> (Float, Float, Float) {
  let diff = l - lum(r, g, b)
  (r + diff, g + diff, b + diff)
}

///|
fn clip_color(
  r : Float,
  g : Float,
  b : Float,
  a : Float,
) -> (Float, Float, Float) {
  let mn = vmin(r, vmin(g, b))
  let mx = vmax(r, vmax(g, b))
  let l = lum(r, g, b)
  fn clip(c : Float) -> Float {
    let c = if mx >= 0.0 { c } else { l + (c - l) * l / (l - mn) }
    let c = if mx > a { l + (c - l) * (a - l) / (mx - l) } else { c }
    vmax(c, 0.0) // Sometimes without this we may dip just a little negative.
  }

  (clip(r), clip(g), clip(b))
}

///|
/// Tile x or y to [0,limit) == [0,limit - 1 ulp] (think, sampling from
/// images). The gather stages will hard clamp the output of these stages to
/// [0,limit)... we just need to do the basic repeat or mirroring.
fn exclusive_reflect(v : Float, limit : Float, inv_limit : Float) -> Float {
  vabs(
    v -
    limit -
    (limit + limit) * vfloor8((v - limit) * (inv_limit * 0.5)) -
    limit,
  )
}

///|
fn exclusive_repeat(v : Float, limit : Float, inv_limit : Float) -> Float {
  v - vfloor8(v * inv_limit) * limit
}

///|
fn HighpPipeline::bilinear(p : HighpPipeline) -> Unit {
  let x = p.r.copy()
  let y = p.g.copy()
  let wx = [lanes8(), lanes8()]
  let wy = [lanes8(), lanes8()]
  for i in 0..<8 {
    let fx = fract8(x[i] + 0.5)
    let fy = fract8(y[i] + 0.5)
    wx[0][i] = (1.0 : Float) - fx
    wx[1][i] = fx
    wy[0][i] = (1.0 : Float) - fy
    wy[1][i] = fy
  }
  p.sampler_nxn(2, -0.5, x, y, wx, wy)
}

///|
fn HighpPipeline::bicubic(p : HighpPipeline) -> Unit {
  let x = p.r.copy()
  let y = p.g.copy()
  let wx = [lanes8(), lanes8(), lanes8(), lanes8()]
  let wy = [lanes8(), lanes8(), lanes8(), lanes8()]
  for i in 0..<8 {
    let fx = fract8(x[i] + 0.5)
    let fy = fract8(y[i] + 0.5)
    wx[0][i] = bicubic_far((1.0 : Float) - fx)
    wx[1][i] = bicubic_near((1.0 : Float) - fx)
    wx[2][i] = bicubic_near(fx)
    wx[3][i] = bicubic_far(fx)
    wy[0][i] = bicubic_far((1.0 : Float) - fy)
    wy[1][i] = bicubic_near((1.0 : Float) - fy)
    wy[2][i] = bicubic_near(fy)
    wy[3][i] = bicubic_far(fy)
  }
  p.sampler_nxn(4, -1.5, x, y, wx, wy)
}

///|
fn fract8(x : Float) -> Float {
  x - vfloor8(x)
}

///|
/// In bicubic interpolation, the 16 pixels and +/- 0.5 and +/- 1.5 offsets
/// from the sample pixel center are combined with a non-uniform cubic
/// filter, with higher values near the center.
///
/// We break this function into two parts, one for near 0.5 offsets and one
/// for far 1.5 offsets.
fn bicubic_near(t : Float) -> Float {
  // 1/18 + 9/18t + 27/18t^2 - 21/18t^3 == t ( t ( -21/18t + 27/18) + 9/18) + 1/18
  mad(
    t,
    mad(
      t,
      mad((-21.0 : Float) / 18.0, t, (27.0 : Float) / 18.0),
      (9.0 : Float) / 18.0,
    ),
    (1.0 : Float) / 18.0,
  )
}

///|
fn bicubic_far(t : Float) -> Float {
  // 0/18 + 0/18*t - 6/18t^2 + 7/18t^3 == t^2 (7/18t - 6/18)
  t * t * mad((7.0 : Float) / 18.0, t, (-6.0 : Float) / 18.0)
}

///|
/// `sampler_2x2` / `sampler_4x4`.
fn HighpPipeline::sampler_nxn(
  p : HighpPipeline,
  n : Int,
  start : Float,
  cx : FixedArray[Float],
  cy : FixedArray[Float],
  wx : Array[FixedArray[Float]],
  wy : Array[FixedArray[Float]],
) -> Unit {
  let ctx = p.ctx.sampler
  let pixmap = p.pixmap_src
  for i in 0..<8 {
    p.r[i] = 0.0
    p.g[i] = 0.0
    p.b[i] = 0.0
    p.a[i] = 0.0
  }
  let y = lanes8()
  let x = lanes8()
  let rr = lanes8()
  let gg = lanes8()
  let bb = lanes8()
  let aa = lanes8()
  for l in 0..<8 {
    y[l] = cy[l] + start
  }
  for j in 0..<n {
    for l in 0..<8 {
      x[l] = cx[l] + start
    }
    for i in 0..<n {
      sample(pixmap, ctx, x, y, rr, gg, bb, aa)
      for l in 0..<8 {
        let w = wx[i][l] * wy[j][l]
        p.r[l] = mad(w, rr[l], p.r[l])
        p.g[l] = mad(w, gg[l], p.g[l])
        p.b[l] = mad(w, bb[l], p.b[l])
        p.a[l] = mad(w, aa[l], p.a[l])
        x[l] = x[l] + 1.0
      }
    }
    for l in 0..<8 {
      y[l] = y[l] + 1.0
    }
  }
}

///|
fn sample(
  pixmap : Pixmap,
  ctx : SamplerCtx,
  x : FixedArray[Float],
  y : FixedArray[Float],
  r : FixedArray[Float],
  g : FixedArray[Float],
  b : FixedArray[Float],
  a : FixedArray[Float],
) -> Unit {
  let tx = lanes8()
  let ty = lanes8()
  let w = Float::from_int(pixmap.width())
  let h = Float::from_int(pixmap.height())
  for l in 0..<8 {
    tx[l] = tile(x[l], ctx.spread_mode, w, ctx.inv_width)
    ty[l] = tile(y[l], ctx.spread_mode, h, ctx.inv_height)
  }
  let ix = gather_ix(pixmap, tx, ty)
  load_8888_gather(pixmap, ix, r, g, b, a)
}

///|
fn tile(
  v : Float,
  mode : SpreadMode,
  limit : Float,
  inv_limit : Float,
) -> Float {
  match mode {
    Pad => v
    Repeat => exclusive_repeat(v, limit, inv_limit)
    Reflect => exclusive_reflect(v, limit, inv_limit)
  }
}

///|
fn gather_ix(
  pixmap : Pixmap,
  x : FixedArray[Float],
  y : FixedArray[Float],
) -> FixedArray[Int] {
  // Exclusive -> inclusive.
  let w = ulp_sub(Float::from_int(pixmap.width()))
  let h = ulp_sub(Float::from_int(pixmap.height()))
  let width = pixmap.width()
  FixedArray::makei(8, l => {
    let xx = vmin(vmax(x[l], 0.0), w)
    let yy = vmin(vmax(y[l], 0.0), h)
    vtrunc_int(yy) * width + vtrunc_int(xx)
  })
}

///|
fn ulp_sub(v : Float) -> Float {
  // Somewhat similar to v - f32::EPSILON
  Float::reinterpret_from_uint(v.reinterpret_as_uint() - 1)
}

///|
fn load_8888_gather(
  pixmap : Pixmap,
  ix : FixedArray[Int],
  r : FixedArray[Float],
  g : FixedArray[Float],
  b : FixedArray[Float],
  a : FixedArray[Float],
) -> Unit {
  let factor : Float = 1.0 / 255.0
  let pixels = pixmap.data
  for l in 0..<8 {
    let c = pixels[ix[l].reinterpret_as_uint().reinterpret_as_int()]
    r[l] = Float::from_uint(c & 0xFF) * factor
    g[l] = Float::from_uint((c >> 8) & 0xFF) * factor
    b[l] = Float::from_uint((c >> 16) & 0xFF) * factor
    a[l] = Float::from_uint(c >> 24) * factor
  }
}

///|
fn srgb_expand(x : Float) -> Float {
  if x <= 0.04045 {
    x / 12.92
  } else {
    vpowf((x + 0.055) / 1.055, 2.4)
  }
}

///|
fn srgb_compress(x : Float) -> Float {
  if x <= 0.0031308 {
    x * 12.92
  } else {
    vpowf(x, 0.416666666) * 1.055 - 0.055
  }
}

///|
/// `load_8888` / `load_8888_tail`: lanes past `tail` load transparent black.
fn load_8888_tail(
  tail : Int,
  data : FixedArray[UInt],
  offset : Int,
  r : FixedArray[Float],
  g : FixedArray[Float],
  b : FixedArray[Float],
  a : FixedArray[Float],
) -> Unit {
  // Surprisingly, `f32 * FACTOR` is way faster than
  // `f32x8 * f32x8::splat(FACTOR)`.
  let factor : Float = 1.0 / 255.0
  for l in 0..<8 {
    let c = if l < tail { data[offset + l] } else { 0 }
    r[l] = Float::from_uint(c & 0xFF) * factor
    g[l] = Float::from_uint((c >> 8) & 0xFF) * factor
    b[l] = Float::from_uint((c >> 16) & 0xFF) * factor
    a[l] = Float::from_uint(c >> 24) * factor
  }
}

///|
/// `store_8888` / `store_8888_tail`.
fn store_8888_tail(
  r : FixedArray[Float],
  g : FixedArray[Float],
  b : FixedArray[Float],
  a : FixedArray[Float],
  tail : Int,
  data : FixedArray[UInt],
  offset : Int,
) -> Unit {
  for l in 0..<tail {
    data[offset + l] = pack_rgba(
      unnorm(r[l]),
      unnorm(g[l]),
      unnorm(b[l]),
      unnorm(a[l]),
    )
  }
}

///|
fn unnorm(v : Float) -> Int {
  vround_int(vmin(vmax(v, 0.0), 1.0) * 255.0)
}

///|
fn inv(v : Float) -> Float {
  (1.0 : Float) - v
}

///|
fn two(v : Float) -> Float {
  v + v
}

///|
fn mad(f : Float, m : Float, a : Float) -> Float {
  f * m + a
}

///|
fn lerp(from : Float, to : Float, t : Float) -> Float {
  mad(to - from, t, from)
}
