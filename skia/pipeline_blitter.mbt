// Port of `tiny-skia/src/pipeline/blitter.rs`.

///|
struct RasterPipelineBlitter {
  mask : SubMaskRef?
  pixmap_src : Pixmap
  pixmap : SubPixmapMut
  memset2d_color : PremultipliedColorU8?
  blit_anti_h_rp : RasterPipeline
  blit_rect_rp : RasterPipeline
  blit_mask_rp : RasterPipeline
  is_mask : Bool
}

///|
let dummy_pixmap : Pixmap = Pixmap::new(1, 1).unwrap()

///|
fn RasterPipelineBlitter::new(
  paint : Paint,
  mask : SubMaskRef?,
  pixmap : SubPixmapMut,
) -> RasterPipelineBlitter? {
  // Make sure that `mask` has the same size as `pixmap`.
  if mask is Some(mask) {
    if mask.size.width() != pixmap.size.width() ||
      mask.size.height() != pixmap.size.height() {
      // Pixmap and Mask are expected to have the same size
      return None
    }
  }

  // Fast-reject.
  // This is basically SkInterpretXfermode().
  match paint.blend_mode {
    // `Destination` keep the pixmap unchanged. Nothing to do here.
    Destination => return None
    DestinationIn if paint.shader.is_opaque() && paint.is_solid_color() =>
      return None
    _ => ()
  }

  // We can strength-reduce SourceOver into Source when opaque.
  let mut blend_mode = paint.blend_mode
  if paint.shader.is_opaque() && blend_mode == SourceOver && mask is None {
    blend_mode = Source
  }

  // When we're drawing a constant color in Source mode, we can sometimes just
  // memset.
  let mut memset2d_color = None
  if paint.is_solid_color() && blend_mode == Source && mask is None {
    // Unlike Skia, our shader cannot be constant.
    // Therefore there is no need to run a raster pipeline to get shader's
    // color.
    if paint.shader is SolidColor(color) {
      memset2d_color = Some(color.premultiply().to_color_u8())
    }
  }

  // Clear is just a transparent color memset.
  if blend_mode == Clear && !paint.anti_alias && mask is None {
    blend_mode = Source
    memset2d_color = Some(premultiplied_color_u8_transparent)
  }
  let blit_anti_h_rp = {
    let p = RasterPipelineBuilder::new()
    p.set_force_hq_pipeline(paint.force_hq_pipeline)
    if !paint.shader.push_stages(paint.colorspace, p) {
      return None
    }
    if mask is Some(_) {
      p.push(MaskU8)
    }
    if blend_mode.should_pre_scale_coverage() {
      p.push(Scale1Float)
      p.push(LoadDestination)
      if paint.colorspace.expand_dest_stage() is Some(stage) {
        p.push(stage)
      }
      if blend_mode.to_stage() is Some(blend_stage) {
        p.push(blend_stage)
      }
    } else {
      p.push(LoadDestination)
      if paint.colorspace.expand_dest_stage() is Some(stage) {
        p.push(stage)
      }
      if blend_mode.to_stage() is Some(blend_stage) {
        p.push(blend_stage)
      }
      p.push(Lerp1Float)
    }
    if paint.colorspace.compress_stage() is Some(stage) {
      p.push(stage)
    }
    p.push(Store)
    p.compile()
  }
  let blit_rect_rp = {
    let p = RasterPipelineBuilder::new()
    p.set_force_hq_pipeline(paint.force_hq_pipeline)
    if !paint.shader.push_stages(paint.colorspace, p) {
      return None
    }
    if mask is Some(_) {
      p.push(MaskU8)
    }
    if blend_mode == SourceOver && mask is None {
      if paint.colorspace.compress_stage() is Some(stage) {
        p.push(stage)
      }
      // TODO: ignore when dither_rate is non-zero
      p.push(SourceOverRgba)
    } else {
      if blend_mode != Source {
        p.push(LoadDestination)
        if blend_mode.to_stage() is Some(blend_stage) {
          if paint.colorspace.expand_dest_stage() is Some(stage) {
            p.push(stage)
          }
          p.push(blend_stage)
        }
      }
      if paint.colorspace.compress_stage() is Some(stage) {
        p.push(stage)
      }
      p.push(Store)
    }
    p.compile()
  }
  let blit_mask_rp = {
    let p = RasterPipelineBuilder::new()
    p.set_force_hq_pipeline(paint.force_hq_pipeline)
    if !paint.shader.push_stages(paint.colorspace, p) {
      return None
    }
    if mask is Some(_) {
      p.push(MaskU8)
    }
    if blend_mode.should_pre_scale_coverage() {
      p.push(ScaleU8)
      p.push(LoadDestination)
      if paint.colorspace.expand_dest_stage() is Some(stage) {
        p.push(stage)
      }
      if blend_mode.to_stage() is Some(blend_stage) {
        p.push(blend_stage)
      }
    } else {
      p.push(LoadDestination)
      if paint.colorspace.expand_dest_stage() is Some(stage) {
        p.push(stage)
      }
      if blend_mode.to_stage() is Some(blend_stage) {
        p.push(blend_stage)
      }
      p.push(LerpU8)
    }
    if paint.colorspace.compress_stage() is Some(stage) {
      p.push(stage)
    }
    p.push(Store)
    p.compile()
  }
  let pixmap_src = match paint.shader {
    Pattern(patt) => patt.pixmap
    // Just a dummy one.
    _ => dummy_pixmap
  }
  Some({
    mask,
    pixmap_src,
    pixmap,
    memset2d_color,
    blit_anti_h_rp,
    blit_rect_rp,
    blit_mask_rp,
    is_mask: false,
  })
}

///|
fn RasterPipelineBlitter::new_mask(
  pixmap : SubPixmapMut,
) -> RasterPipelineBlitter? {
  let color = color_white.premultiply()
  let memset2d_color = Some(color.to_color_u8())
  let blit_anti_h_rp = {
    let p = RasterPipelineBuilder::new()
    p.push_uniform_color(color)
    p.push(LoadDestinationU8)
    p.push(Lerp1Float)
    p.push(StoreU8)
    p.compile()
  }
  let blit_rect_rp = {
    let p = RasterPipelineBuilder::new()
    p.push_uniform_color(color)
    p.push(StoreU8)
    p.compile()
  }
  let blit_mask_rp = {
    let p = RasterPipelineBuilder::new()
    p.push_uniform_color(color)
    p.push(LoadDestinationU8)
    p.push(LerpU8)
    p.push(StoreU8)
    p.compile()
  }
  Some({
    mask: None,
    pixmap_src: dummy_pixmap,
    pixmap,
    memset2d_color,
    blit_anti_h_rp,
    blit_rect_rp,
    blit_mask_rp,
    is_mask: true,
  })
}

///|
fn RasterPipelineBlitter::mask_ctx(self : RasterPipelineBlitter) -> MaskCtx {
  match self.mask {
    Some(c) => c.mask_ctx()
    None => MaskCtx::default()
  }
}

///|
impl Blitter for RasterPipelineBlitter with fn blit_h(self, x, y, width) {
  let r = ScreenIntRect::from_xywh_safe(x, y, width, 1)
  self.blit_rect(r)
}

///|
impl Blitter for RasterPipelineBlitter with fn blit_anti_h(
  self,
  x,
  y,
  aa,
  aa_offset,
  runs,
  runs_offset,
) {
  let mask_ctx = self.mask_ctx()
  let mut x = x
  let mut aa_offset = aa_offset
  let mut run_offset = runs_offset
  let mut run = runs[run_offset]
  while run != 0 {
    let width = run
    match aa[aa_offset] {
      0 => () // ALPHA_U8_TRANSPARENT
      255 => self.blit_h(x, y, width) // ALPHA_U8_OPAQUE
      alpha => {
        self.blit_anti_h_rp.ctx.current_coverage = Float::from_int(alpha) *
          ((1.0 : Float) / 255.0)
        let rect = ScreenIntRect::from_xywh_safe(x, y, width, 1)
        self.blit_anti_h_rp.run(
          rect,
          AAMaskCtx::default(),
          mask_ctx,
          self.pixmap_src,
          self.pixmap,
        )
      }
    }
    x += width
    run_offset += run
    aa_offset += run
    run = runs[run_offset]
  }
}

///|
impl Blitter for RasterPipelineBlitter with fn blit_v(self, x, y, height, alpha) {
  let bounds = ScreenIntRect::from_xywh_safe(x, y, 1, height)
  let mask : BlitMask = {
    image: [alpha, alpha],
    bounds,
    row_bytes: 0, // so we reuse the 1 "row" for all of height
  }
  self.blit_mask(mask, bounds)
}

///|
impl Blitter for RasterPipelineBlitter with fn blit_anti_h2(
  self,
  x,
  y,
  alpha0,
  alpha1,
) {
  let bounds = ScreenIntRect::from_xywh(
    x.reinterpret_as_uint(),
    y.reinterpret_as_uint(),
    2,
    1,
  ).unwrap()
  let mask : BlitMask = { image: [alpha0, alpha1], bounds, row_bytes: 2, }
  self.blit_mask(mask, bounds)
}

///|
impl Blitter for RasterPipelineBlitter with fn blit_anti_v2(
  self,
  x,
  y,
  alpha0,
  alpha1,
) {
  let bounds = ScreenIntRect::from_xywh(
    x.reinterpret_as_uint(),
    y.reinterpret_as_uint(),
    1,
    2,
  ).unwrap()
  let mask : BlitMask = { image: [alpha0, alpha1], bounds, row_bytes: 1, }
  self.blit_mask(mask, bounds)
}

///|
impl Blitter for RasterPipelineBlitter with fn blit_rect(self, rect) {
  if self.memset2d_color is Some(c) {
    if self.is_mask {
      let alpha = c.alpha().to_byte()
      for y in 0..<rect.height() {
        let start = self.pixmap.offset_of(rect.x(), rect.y() + y)
        for i in start..<(start + rect.width()) {
          self.pixmap.bytes[i] = alpha
        }
      }
    } else {
      for y in 0..<rect.height() {
        let start = self.pixmap.offset_of(rect.x(), rect.y() + y)
        for i in start..<(start + rect.width()) {
          self.pixmap.pixels[i] = c.0
        }
      }
    }
    return
  }
  let mask_ctx = self.mask_ctx()
  self.blit_rect_rp.run(
    rect,
    AAMaskCtx::default(),
    mask_ctx,
    self.pixmap_src,
    self.pixmap,
  )
}

///|
impl Blitter for RasterPipelineBlitter with fn blit_mask(self, mask, clip) {
  let aa_mask_ctx : AAMaskCtx = {
    pixels: mask.image,
    stride: mask.row_bytes,
    shift: mask.bounds.left() + mask.bounds.top() * mask.row_bytes,
  }
  let mask_ctx = self.mask_ctx()
  self.blit_mask_rp.run(
    clip,
    aa_mask_ctx,
    mask_ctx,
    self.pixmap_src,
    self.pixmap,
  )
}
