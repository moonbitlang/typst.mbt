// Port of `vello_cpu/src/fine/mod.rs` and `vello_cpu/src/fine/lowp/mod.rs`
// (the `U8Kernel`, the only pipeline enabled for hayro).
//
// Scratch buffers store a strip row of `Tile::HEIGHT` pixel rows in column
// major order: the pixel at `(x, y)` of the row starts at byte
// `x * 16 + y * 4`.

///|
/// Number of color components in a single column of a tile.
const TILE_HEIGHT_COMPONENTS : Int = 16

///|
/// Fine rasterizer for processing strip rows at the pixel level.
priv struct Fine {
  /// Pixel span covered by the blend buffers.
  buffer_span : Span
  /// Stack of blend buffers for managing layers and composition.
  blend_buffers : Array[FixedArray[Byte]]
  /// Pool for reusing layer buffer allocations.
  buffer_pool : Array[FixedArray[Byte]]
  /// Intermediate buffer used by painters to store generated pixel data
  /// before compositing.
  mut paint_buf : FixedArray[Byte]
  /// Buffer for storing gradient interpolation parameters (t values).
  mut f32_buf : FixedArray[Float]
  /// The current strip row y-coordinate.
  mut row_y : Int
}

///|
fn Fine::new(buffer_width : Int) -> Fine {
  let scratch_len = buffer_width * TILE_HEIGHT_COMPONENTS
  {
    buffer_span: { x: 0, width: buffer_width, },
    blend_buffers: [FixedArray::make(scratch_len, b'\x00')],
    buffer_pool: [],
    paint_buf: FixedArray::make(0, b'\x00'),
    f32_buf: FixedArray::make(0, 0.0),
    row_y: 0,
  }
}

///|
fn Fine::top(self : Fine) -> FixedArray[Byte] {
  self.blend_buffers[self.blend_buffers.length() - 1]
}

///|
/// A view into a part of a single strip row of a pixmap.
priv struct Region {
  row_idx : Int
  width : Int
  height : Int
  /// The target buffer, its stride in bytes and the byte offset of the
  /// region's first row.
  buf : FixedArray[Byte]
  stride : Int
  offset : Int
}

///|
fn rasterize_region(
  fine : Fine,
  region : Region,
  bucketer : CommandBucketer,
  resources : FineResources,
) -> Unit {
  let scene_y = region.row_idx * TILE_HEIGHT
  let row = bucketer.rows[region.row_idx]
  fine.row_y = scene_y
  // Clear the regions in the fine buffer (no opaque depth fills).
  let buf0 = fine.blend_buffers[0]
  for i in 0..<(region.width * TILE_HEIGHT_COMPONENTS) {
    buf0[i] = b'\x00'
  }
  // Render the main commands back-to-front.
  for cmd in row.render_cmds {
    fine.run_cmd(cmd, bucketer, scene_y, resources)
  }
  // Pack the composited result back into the pixmap.
  fine.pack(region)
}

///|
priv struct FineResources {
  alphas : Array[Byte]
  encoded_paints : Array[EncodedPaint]
}

///|
/// Writes the current buffer contents to the output row.
fn Fine::pack(self : Fine, region : Region) -> Unit {
  let scratch = self.top()
  for y in 0..<region.height {
    let row_start = region.offset + y * region.stride
    for x in 0..<region.width {
      let src = x * TILE_HEIGHT_COMPONENTS + y * 4
      let dst = row_start + x * 4
      region.buf[dst] = scratch[src]
      region.buf[dst + 1] = scratch[src + 1]
      region.buf[dst + 2] = scratch[src + 2]
      region.buf[dst + 3] = scratch[src + 3]
    }
  }
}

///|
/// Execute a bucketed rendering command on the current strip row.
fn Fine::run_cmd(
  self : Fine,
  cmd : RenderCmd,
  bucketer : CommandBucketer,
  row_y : Int,
  resources : FineResources,
) -> Unit {
  match cmd {
    PaintFill(span=cmd_span, alpha_idx~, attrs_idx~) => {
      let attrs = bucketer.paint_fill_attrs[attrs_idx]
      guard cmd_span.intersect(self.buffer_span) is Some(span) else { return }
      let alphas = match alpha_idx {
        Some(alpha_idx) => Some(alpha_idx + (span.x - cmd_span.x) * TILE_HEIGHT)
        None => None
      }
      self.paint_fill(span, attrs, resources, alphas)
    }
    PushBuf(span) => {
      let len = self.blend_buffers[0].length()
      let buf = match self.buffer_pool.pop() {
        Some(buf) if buf.length() == len => buf
        _ => FixedArray::make(len, b'\x00')
      }
      // Instead of always zeroing out the whole buffer, only zero the
      // row-local span that will be read when compositing this layer.
      if span is Some(span) && span.intersect(self.buffer_span) is Some(span) {
        let start = span.x * TILE_HEIGHT_COMPONENTS
        for i in start..<(start + span.width * TILE_HEIGHT_COMPONENTS) {
          buf[i] = b'\x00'
        }
      }
      self.blend_buffers.push(buf)
    }
    PopBuf =>
      if self.blend_buffers.pop() is Some(popped) {
        self.buffer_pool.push(popped)
      }
    LayerFill(span=cmd_span, alpha_idx~, attrs_idx~) => {
      guard cmd_span.intersect(self.buffer_span) is Some(span) else { return }
      let attrs = bucketer.layer_fill_attrs[attrs_idx]
      let alphas = match alpha_idx {
        Some(alpha_idx) => Some(alpha_idx + (span.x - cmd_span.x) * TILE_HEIGHT)
        None => None
      }
      self.layer_fill(row_y, span, attrs, resources, alphas)
    }
  }
}

///|
fn Fine::opacity(self : Fine, span : Span, opacity : Float) -> Unit {
  let target = self.top()
  let start = span.x * TILE_HEIGHT_COMPONENTS
  let end = start + span.width * TILE_HEIGHT_COMPONENTS
  let v = unit_to_u8(opacity)
  for i in start..<end {
    target[i] = (div_255(target[i].to_int() * v) & 0xFF).to_byte()
  }
}

///|
fn Fine::mask(self : Fine, row_y : Int, span : Span, mask : Mask) -> Unit {
  let x = span.x
  let width = span.width
  let target = self.top()
  let start = span.x * TILE_HEIGHT_COMPONENTS
  for col in 0..<width {
    let px = x + col
    if px > 65535 {
      break
    }
    let x_in_range = px < mask.width()
    for r in 0..<4 {
      let y = row_y + r
      let s = if x_in_range && (y & 0xFFFF) < mask.height() {
        mask.sample(px, y & 0xFFFF)
      } else {
        0
      }
      let base = start + col * TILE_HEIGHT_COMPONENTS + r * 4
      for c in 0..<4 {
        target[base + c] = (div_255(target[base + c].to_int() * s) & 0xFF).to_byte()
      }
    }
  }
}

///|
fn Fine::layer_fill(
  self : Fine,
  row_y : Int,
  span : Span,
  attrs : LayerFillAttrs,
  resources : FineResources,
  alphas : Int?,
) -> Unit {
  if attrs.opacity != 1.0 {
    self.opacity(span, attrs.opacity)
  }
  if attrs.mask is Some(mask) {
    self.mask(row_y, span, mask)
  }
  let x = span.x
  let n = self.blend_buffers.length()
  let source = self.blend_buffers[n - 1]
  let target = self.blend_buffers[n - 2]
  let start = span.x * TILE_HEIGHT_COMPONENTS
  let len = span.width * TILE_HEIGHT_COMPONENTS
  if attrs.blend_mode.is_default() {
    alpha_composite_buffer(
      target,
      start,
      len,
      source,
      start,
      resources.alphas,
      alphas,
    )
  } else {
    blend(
      target,
      start,
      len,
      x,
      row_y,
      source,
      start,
      false,
      attrs.blend_mode,
      resources.alphas,
      alphas,
      None,
    )
  }
}

///|
fn Fine::paint_fill(
  self : Fine,
  span : Span,
  attrs : PaintFillAttrs,
  resources : FineResources,
  alphas : Int?,
) -> Unit {
  match attrs.paint {
    Solid(color) => self.solid_fill(span, color, attrs, resources, alphas)
    Indexed(index) => self.indexed_fill(span, index, attrs, resources, alphas)
  }
}

///|
fn Fine::solid_fill(
  self : Fine,
  span : Span,
  color : PremulColor,
  attrs : PaintFillAttrs,
  resources : FineResources,
  alphas : Int?,
) -> Unit {
  let start = span.x * TILE_HEIGHT_COMPONENTS
  let len = span.width * TILE_HEIGHT_COMPONENTS
  let scratch = self.top()
  if attrs.blend_mode.is_default() && attrs.mask is None {
    fill_solid(scratch, start, len, color, resources.alphas, alphas)
    return
  }
  if span.width == 0 {
    return
  }
  let src = FixedArray::make(32, b'\x00')
  let c = color.premul_u8
  for p in 0..<8 {
    for k in 0..<4 {
      src[p * 4 + k] = c[k].to_byte()
    }
  }
  blend(
    scratch,
    start,
    len,
    span.x,
    self.row_y,
    src,
    0,
    true,
    attrs.blend_mode,
    resources.alphas,
    alphas,
    attrs.mask,
  )
}

///|
/// Offset to shift from pixel corner to pixel center for sampling.
const PIXEL_CENTER_OFFSET : Double = 0.5

///|
fn Fine::indexed_fill(
  self : Fine,
  span : Span,
  paint_index : Int,
  attrs : PaintFillAttrs,
  resources : FineResources,
  alphas : Int?,
) -> Unit {
  let x = span.x
  let y = self.row_y
  let width = span.width
  let len = width * TILE_HEIGHT_COMPONENTS
  if self.paint_buf.length() < len {
    self.paint_buf = FixedArray::make(len, b'\x00')
  }
  let t_len = width * TILE_HEIGHT
  if self.f32_buf.length() < t_len {
    self.f32_buf = FixedArray::make(t_len, 0.0)
  }
  let start = x * TILE_HEIGHT_COMPONENTS
  let dest = self.top()
  let color_buf = self.paint_buf
  let encoded_paint = resources.encoded_paints[paint_index]
  let sampler_x = x.to_double() + PIXEL_CENTER_OFFSET
  let sampler_y = y.to_double() + PIXEL_CENTER_OFFSET
  let default_blend = attrs.blend_mode.is_default()
  let fill_complex_paint = (
    may_have_transparency : Bool,
    painter : (FixedArray[Byte], Int, Int) -> Unit,
  ) => {
    if may_have_transparency ||
      alphas is Some(_) ||
      !default_blend ||
      attrs.mask is Some(_) {
      painter(color_buf, 0, len)
      if default_blend && attrs.mask is None {
        alpha_composite_buffer(
          dest,
          start,
          len,
          color_buf,
          0,
          resources.alphas,
          alphas,
        )
      } else {
        blend(
          dest,
          start,
          len,
          x,
          y,
          color_buf,
          0,
          false,
          attrs.blend_mode,
          resources.alphas,
          alphas,
          attrs.mask,
        )
      }
    } else {
      // Similarly to solid colors we can just override the previous values
      // if all colors in the gradient are fully opaque.
      painter(dest, start, len)
    }
  }
  match encoded_paint {
    Gradient(gradient) => {
      let t_vals = self.f32_buf
      calculate_t_vals(gradient, t_vals, t_len, sampler_x, sampler_y)
      match gradient.kind {
        Radial(kind) if kind.has_undefined() =>
          fill_complex_paint(gradient.may_have_transparency, (buf, off, n) => {
            paint_gradient_f32_lut(gradient, t_vals, buf, off, n)
          })
        _ =>
          fill_complex_paint(gradient.may_have_transparency, (buf, off, n) => {
            paint_gradient_u8(gradient, t_vals, buf, off, n)
          })
      }
    }
    Image(image) => {
      let pixmap = match image.source {
        Pixmap(pixmap) => pixmap
      }
      let painter : (FixedArray[Byte], Int, Int) -> Unit = match
        (image.has_skew(), image.nearest_neighbor()) {
        (false, false) =>
          // Axis-aligned with filtering - use optimized plain painters
          if image.sampler.quality == Medium {
            (buf, off, n) => {
              paint_plain_bilinear(
                image, pixmap, sampler_x, sampler_y, buf, off, n,
              )
            }
          } else {
            (buf, off, n) => {
              paint_bicubic(image, pixmap, sampler_x, sampler_y, buf, off, n)
            }
          }
        (true, false) =>
          // Skewed with filtering - use generic filtered painters
          if image.sampler.quality == Medium {
            (buf, off, n) => {
              paint_bilinear(image, pixmap, sampler_x, sampler_y, buf, off, n)
            }
          } else {
            (buf, off, n) => {
              paint_bicubic(image, pixmap, sampler_x, sampler_y, buf, off, n)
            }
          }
        (false, true) =>
          (buf, off, n) => {
            paint_plain_nn(image, pixmap, sampler_x, sampler_y, buf, off, n)
          }
        (true, true) =>
          (buf, off, n) => {
            paint_nn(image, pixmap, sampler_x, sampler_y, buf, off, n)
          }
      }
      fill_complex_paint(image.may_have_transparency, painter)
    }
  }
}

// ---------------------------------------------------------------------------
// U8Kernel operations.

///|
/// Fill a row scratch span with a solid color, optionally modulated by
/// per-pixel alphas.
fn fill_solid(
  dest : FixedArray[Byte],
  start : Int,
  len : Int,
  color : PremulColor,
  alpha_buf : Array[Byte],
  alphas : Int?,
) -> Unit {
  let color = color.premul_u8
  if color[3] == 255 && alphas is None {
    // `copy_solid`.
    let mut i = start
    while i < start + len {
      dest[i] = color[0].to_byte()
      dest[i + 1] = color[1].to_byte()
      dest[i + 2] = color[2].to_byte()
      dest[i + 3] = color[3].to_byte()
      i += 4
    }
  } else {
    alpha_composite_solid(dest, start, len, color, alpha_buf, alphas)
  }
}

///|
/// Composites a solid color onto a buffer using alpha blending.
fn alpha_composite_solid(
  dest : FixedArray[Byte],
  start : Int,
  len : Int,
  src : FixedArray[Int],
  alpha_buf : Array[Byte],
  alphas : Int?,
) -> Unit {
  match alphas {
    Some(alpha_off) => {
      // `alpha_fill::alpha_composite_solid`, per chunk of 8 pixels.
      let src_a = src[3]
      let chunks = len / 32
      for ch in 0..<chunks {
        for p in 0..<8 {
          let mask = alpha_buf[alpha_off + ch * 8 + p].to_int()
          let inv_src_a_mask_a = (255 - (norm_mul(src_a, mask) & 0xFF)) & 0xFF
          let base = start + ch * 32 + p * 4
          for c in 0..<4 {
            let bg = dest[base + c].to_int()
            let p1 = bg * inv_src_a_mask_a
            let p2 = src[c] * mask
            dest[base + c] = (div_255((p1 + p2) & 0xFFFF) & 0xFF).to_byte()
          }
        }
      }
    }
    None => {
      // `fill::alpha_composite_solid`, per chunk of 16 pixels.
      let one_minus_alpha = (255 - src[3]) & 0xFF
      let chunks = len / 64
      for ch in 0..<chunks {
        for p in 0..<16 {
          let base = start + ch * 64 + p * 4
          for c in 0..<4 {
            let bg = dest[base + c].to_int()
            dest[base + c] = (((norm_mul(bg, one_minus_alpha) & 0xFF) + src[c]) &
            0xFF).to_byte()
          }
        }
      }
    }
  }
}

///|
/// Composites a source buffer onto a destination buffer using alpha
/// blending.
fn alpha_composite_buffer(
  dest : FixedArray[Byte],
  start : Int,
  len : Int,
  src : FixedArray[Byte],
  src_start : Int,
  alpha_buf : Array[Byte],
  alphas : Int?,
) -> Unit {
  let chunks = len / 32
  match alphas {
    Some(alpha_off) =>
      // `alpha_fill::alpha_composite`.
      for ch in 0..<chunks {
        for p in 0..<8 {
          let mask = alpha_buf[alpha_off + ch * 8 + p].to_int()
          let sbase = src_start + ch * 32 + p * 4
          let src_a = src[sbase + 3].to_int()
          let inv_src_a_mask_a = (255 - (norm_mul(src_a, mask) & 0xFF)) & 0xFF
          let base = start + ch * 32 + p * 4
          for c in 0..<4 {
            let bg = dest[base + c].to_int()
            let p1 = bg * inv_src_a_mask_a
            let p2 = src[sbase + c].to_int() * mask
            dest[base + c] = (div_255((p1 + p2) & 0xFFFF) & 0xFF).to_byte()
          }
        }
      }
    None =>
      // `fill::alpha_composite`.
      for ch in 0..<chunks {
        for p in 0..<8 {
          let sbase = src_start + ch * 32 + p * 4
          let one_minus_alpha = (255 - src[sbase + 3].to_int()) & 0xFF
          let base = start + ch * 32 + p * 4
          for c in 0..<4 {
            let bg = dest[base + c].to_int()
            dest[base + c] = ((
              (norm_mul(bg, one_minus_alpha) & 0xFF) + src[sbase + c].to_int()
            ) &
            0xFF).to_byte()
          }
        }
      }
  }
}

///|
/// Applies a blend mode to composite source pixels onto destination.
///
/// The source is either a buffer (`src_repeat = false`, 32 bytes per chunk
/// starting at `src_start`) or a single 32-byte chunk repeated for every
/// chunk (`src_repeat = true`).
fn blend(
  dest : FixedArray[Byte],
  start : Int,
  len : Int,
  start_x : Int,
  start_y : Int,
  src : FixedArray[Byte],
  src_start : Int,
  src_repeat : Bool,
  blend_mode : BlendMode,
  alpha_buf : Array[Byte],
  alphas : Int?,
  mask : Mask?,
) -> Unit {
  let chunks = len / 32
  let src_c = FixedArray::make(32, 0)
  let bg_c = FixedArray::make(32, 0)
  let masks = FixedArray::make(8, 0)
  let default_mix = blend_mode.mix == Normal
  let mut start_x = start_x
  for ch in 0..<chunks {
    let sbase = if src_repeat { src_start } else { src_start + ch * 32 }
    let base = start + ch * 32
    for i in 0..<32 {
      src_c[i] = src[sbase + i].to_int()
      bg_c[i] = dest[base + i].to_int()
    }
    let has_masks = alphas is Some(_) || mask is Some(_)
    if has_masks {
      // The mask samples of the two columns of this chunk.
      let mask_samples = FixedArray::make(8, 255)
      if mask is Some(m) {
        let sample = (x : Int, y : Int) => {
          if x < m.width() && y < m.height() {
            m.sample(x, y)
          } else {
            255
          }
        }
        for k in 0..<4 {
          mask_samples[k] = sample(start_x, (start_y + k) & 0xFFFF)
          mask_samples[4 + k] = sample(
            (start_x + 1) & 0xFFFF,
            (start_y + k) & 0xFFFF,
          )
        }
        start_x = (start_x + 2) & 0xFFFF
      }
      for k in 0..<8 {
        masks[k] = match alphas {
          Some(alpha_off) => {
            let a1 = alpha_buf[alpha_off + ch * 8 + k].to_int()
            if mask is Some(_) {
              div_255(a1 * mask_samples[k]) & 0xFF
            } else {
              a1
            }
          }
          None => mask_samples[k]
        }
      }
    }
    if !default_mix {
      mix(src_c, bg_c, blend_mode)
    }
    compose(blend_mode, src_c, bg_c, if has_masks { Some(masks) } else { None })
    for i in 0..<32 {
      dest[base + i] = src_c[i].to_byte()
    }
  }
}
