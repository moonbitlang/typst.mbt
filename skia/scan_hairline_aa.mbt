// Port of `tiny-skia/src/scan/hairline_aa.rs`.

///|
priv struct FixedRect {
  left : Int
  top : Int
  right : Int
  bottom : Int
}

///|
fn FixedRect::from_rect(src : @path.Rect) -> FixedRect {
  {
    left: fdot16_from_f32(src.left()),
    top: fdot16_from_f32(src.top()),
    right: fdot16_from_f32(src.right()),
    bottom: fdot16_from_f32(src.bottom()),
  }
}

///|
fn alpha_mul(value : Int, alpha256 : Int) -> Int {
  ((value * alpha256) >> 8) & 0xFF
}

///|
fn hairline_aa_fill_rect(
  rect : @path.Rect,
  clip : ScreenIntRect,
  blitter : &Blitter,
) -> Unit {
  guard rect.intersect(clip.to_rect()) is Some(rect) else { // everything was clipped out
    return
  }
  let fr = FixedRect::from_rect(rect)
  fill_fixed_rect(fr, blitter)
}

///|
fn fill_fixed_rect(rect : FixedRect, blitter : &Blitter) -> Unit {
  fill_dot8(
    fdot8_from_fdot16(rect.left),
    fdot8_from_fdot16(rect.top),
    fdot8_from_fdot16(rect.right),
    fdot8_from_fdot16(rect.bottom),
    true,
    blitter,
  )
}

///|
fn fill_dot8(
  l : Int,
  t : Int,
  r : Int,
  b : Int,
  fill_inner : Bool,
  blitter : &Blitter,
) -> Unit {
  fn to_alpha(a : Int) -> Int {
    a & 0xFF
  }

  // check for empty now that we're in our reduced precision space
  if l >= r || t >= b {
    return
  }
  let mut top = t >> 8
  if top == (b - 1) >> 8 {
    // just one scanline high
    do_scanline(l, top, r, to_alpha(b - t - 1), blitter)
    return
  }
  if (t & 0xFF) != 0 {
    do_scanline(l, top, r, to_alpha(256 - (t & 0xFF)), blitter)
    top += 1
  }
  let bottom = b >> 8
  let height = bottom - top
  if height > 0 {
    let mut left = l >> 8
    if left == (r - 1) >> 8 {
      // just 1-pixel wide
      if left >= 0 && top >= 0 {
        blitter.blit_v(left, top, height, to_alpha(r - l - 1))
      }
    } else {
      if (l & 0xFF) != 0 {
        if left >= 0 && top >= 0 {
          blitter.blit_v(left, top, height, to_alpha(256 - (l & 0xFF)))
        }
        left += 1
      }
      let right = r >> 8
      let width = right - left
      if fill_inner {
        if width > 0 {
          if left >= 0 && top >= 0 {
            let rect = ScreenIntRect::from_xywh_safe(left, top, width, height)
            blitter.blit_rect(rect)
          }
        }
      }
      if (r & 0xFF) != 0 {
        if right >= 0 && top >= 0 {
          blitter.blit_v(right, top, height, to_alpha(r & 0xFF))
        }
      }
    }
  }
  if (b & 0xFF) != 0 {
    do_scanline(l, bottom, r, to_alpha(b & 0xFF), blitter)
  }
}

///|
fn do_scanline(
  l : Int,
  top : Int,
  r : Int,
  alpha : Int,
  blitter : &Blitter,
) -> Unit {
  if top < 0 {
    return
  }
  if l >> 8 == (r - 1) >> 8 {
    // 1x1 pixel
    if l >> 8 >= 0 {
      blitter.blit_v(l >> 8, top, 1, alpha_mul(alpha, r - l))
    }
    return
  }
  let mut left = l >> 8
  if (l & 0xFF) != 0 {
    if l >> 8 >= 0 {
      blitter.blit_v(l >> 8, top, 1, alpha_mul(alpha, 256 - (l & 0xFF)))
    }
    left += 1
  }
  let right = r >> 8
  let width = right - left
  if width > 0 {
    if left >= 0 {
      call_hline_blitter(left, Some(top), width, alpha, blitter)
    }
  }
  if (r & 0xFF) != 0 {
    if right >= 0 {
      blitter.blit_v(right, top, 1, alpha_mul(alpha, r & 0xFF))
    }
  }
}

///|
fn call_hline_blitter(
  x : Int,
  y : Int?,
  count : Int,
  alpha : Int,
  blitter : &Blitter,
) -> Unit {
  let hline_stack_buffer = 100
  let runs = FixedArray::make(hline_stack_buffer + 1, 0)
  let aa = FixedArray::make(hline_stack_buffer, 0)
  let mut x = x
  let mut count = count
  while true {
    // In theory, we should be able to just do this once (outside of the
    // loop), since aa[] and runs[] are supposed" to be const when we call the
    // blitter. In reality, some wrapper-blitters (e.g. RgnClipBlitter) cast
    // away that constness, and modify the buffers in-place. Hence the need to
    // be defensive here and reseed the aa value.
    aa[0] = alpha
    let mut n = count
    if n > hline_stack_buffer {
      n = hline_stack_buffer
    }
    runs[0] = n & 0xFFFF
    runs[n] = 0
    if y is Some(y) {
      blitter.blit_anti_h(x, y, aa, 0, runs, 0)
    }
    x += n
    if n >= count || count == 0 {
      break
    }
    count -= n
  }
}

///|
fn hairline_aa_stroke_path(
  path : @path.Path,
  line_cap : @path.LineCap,
  clip : ScreenIntRect,
  blitter : &Blitter,
) -> Unit {
  hairline_stroke_path_impl(path, line_cap, clip, anti_hair_line_rgn, blitter)
}

///|
fn anti_hair_line_rgn(
  points : ArrayView[@path.Point],
  clip : ScreenIntRect?,
  blitter : &Blitter,
) -> Unit {
  let max : Float = 32767.0
  let fixed_bounds = @path.Rect::from_ltrb(-max, -max, max, max).unwrap()
  let clip_bounds = match clip {
    // We perform integral clipping later on, but we do a scalar clip first
    // to ensure that our coordinates are expressible in fixed/integers.
    //
    // antialiased hairlines can draw up to 1/2 of a pixel outside of
    // their bounds, so we need to outset the clip before calling the
    // clipper. To make the numerics safer, we outset by a whole pixel,
    // since the 1/2 pixel boundary is important to the antihair blitter,
    // we don't want to risk numerical fate by chopping on that edge.
    Some(clip) => clip.to_rect().outset(1.0, 1.0)
    None => None
  }
  for i in 0..<(points.length() - 1) {
    // We have to pre-clip the line to fit in a Fixed, so we just chop the
    // line.
    guard line_intersect([points[i], points[i + 1]], fixed_bounds) is Some(pts) else {
      continue
    }
    let pts = match clip_bounds {
      Some(clip_bounds) =>
        match line_intersect(pts, clip_bounds) {
          Some(p) => p
          None => continue
        }
      None => pts
    }
    let x0 = fdot6_from_f32(pts[0].x)
    let y0 = fdot6_from_f32(pts[0].y)
    let x1 = fdot6_from_f32(pts[1].x)
    let y1 = fdot6_from_f32(pts[1].y)
    if clip is Some(clip) {
      let left = if x0 < x1 { x0 } else { x1 }
      let top = if y0 < y1 { y0 } else { y1 }
      let right = if x0 > x1 { x0 } else { x1 }
      let bottom = if y0 > y1 { y0 } else { y1 }
      let ir = @path.IntRect::from_ltrb(
        fdot6_floor(left) - 1,
        fdot6_floor(top) - 1,
        fdot6_ceil(right) + 1,
        fdot6_ceil(bottom) + 1,
      )
      guard ir is Some(ir) else { return }
      if clip.to_int_rect().intersect(ir) is None {
        continue
      }
      if !clip.to_int_rect().contains(ir) {
        let subclip = ir
          .intersect(clip.to_int_rect())
          .bind(r => int_rect_to_screen_int_rect(r))
        if subclip is Some(subclip) {
          do_anti_hairline(x0, y0, x1, y1, Some(subclip), blitter)
        }
        continue
      }

      // fall through to no-clip case
    }
    do_anti_hairline(x0, y0, x1, y1, None, blitter)
  }
}

///|
priv enum BlitterKind {
  HLine
  Horish
  VLine
  Vertish
}

///|
fn do_anti_hairline(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  clip_opt : ScreenIntRect?,
  blitter : &Blitter,
) -> Unit {
  let mut x0 = x0
  let mut y0 = y0
  let mut x1 = x1
  let mut y1 = y1
  let mut clip_opt = clip_opt
  // check for integer NaN (0x80000000) which we can't handle (can't negate
  // it) It appears typically from a huge float (inf or nan) being converted
  // to int. If we see it, just don't draw.
  if any_bad_ints(x0, y0, x1, y1) != 0 {
    return
  }
  if (x1 - x0).abs() > fdot6_from_i32(511) ||
    (y1 - y0).abs() > fdot6_from_i32(511) {
    // instead of (x0 + x1) >> 1, we shift each separately. This is less
    // precise, but avoids overflowing the intermediate result if the
    // values are huge. A better fix might be to clip the original pts
    // directly (i.e. do the divide), so we don't spend time subdividing
    // huge lines at all.
    let hx = (x0 >> 1) + (x1 >> 1)
    let hy = (y0 >> 1) + (y1 >> 1)
    do_anti_hairline(x0, y0, hx, hy, clip_opt, blitter)
    do_anti_hairline(hx, hy, x1, y1, clip_opt, blitter)
    return // we're done
  }
  let mut scale_start = 0
  let mut scale_stop = 0
  let mut istart = 0
  let mut istop = 0
  let mut fstart = 0
  let mut slope = 0
  let mut blitter_kind : BlitterKind = HLine
  if (x1 - x0).abs() > (y1 - y0).abs() {
    // mostly horizontal
    if x0 > x1 {
      // we want to go left-to-right
      let t = x0
      x0 = x1
      x1 = t
      let t = y0
      y0 = y1
      y1 = t
    }
    istart = fdot6_floor(x0)
    istop = fdot6_ceil(x1)
    fstart = fdot6_to_fdot16(y0)
    if y0 == y1 {
      // completely horizontal, take fast case
      slope = 0
      blitter_kind = HLine
    } else {
      slope = fdot16_fast_div(y1 - y0, x1 - x0)
      fstart += (slope * (32 - (x0 & 63)) + 32) >> 6
      blitter_kind = Horish
    }
    if istop - istart == 1 {
      // we are within a single pixel
      scale_start = x1 - x0
      scale_stop = 0
    } else {
      scale_start = 64 - (x0 & 63)
      scale_stop = x1 & 63
    }
    if clip_opt is Some(clip) {
      let clip = clip.to_int_rect()
      if istart >= clip.right() || istop <= clip.left() {
        return // we're done
      }
      if istart < clip.left() {
        fstart += slope * (clip.left() - istart)
        istart = clip.left()
        scale_start = 64
        if istop - istart == 1 {
          // we are within a single pixel
          scale_start = contribution_64(x1)
          scale_stop = 0
        }
      }
      if istop > clip.right() {
        istop = clip.right()
        scale_stop = 0 // so we don't draw this last column
      }
      if istart == istop {
        return // we're done
      }

      // now test if our Y values are completely inside the clip
      let (top, bottom) = if slope >= 0 {
        // T2B
        let top = fdot16_floor_to_i32(fstart - fdot16_half)
        let bottom = fdot16_ceil_to_i32(
          fstart + (istop - istart - 1) * slope + fdot16_half,
        )
        (top, bottom)
      } else {
        // B2T
        let bottom = fdot16_ceil_to_i32(fstart + fdot16_half)
        let top = fdot16_floor_to_i32(
          fstart + (istop - istart - 1) * slope - fdot16_half,
        )
        (top, bottom)
      }
      let top = top - 1
      let bottom = bottom + 1
      if top >= clip.bottom() || bottom <= clip.top() {
        return // we're done
      }
      if clip.top() <= top && clip.bottom() >= bottom {
        clip_opt = None
      }
    }
  } else {
    // mostly vertical
    if y0 > y1 {
      // we want to go top-to-bottom
      let t = x0
      x0 = x1
      x1 = t
      let t = y0
      y0 = y1
      y1 = t
    }
    istart = fdot6_floor(y0)
    istop = fdot6_ceil(y1)
    fstart = fdot6_to_fdot16(x0)
    if x0 == x1 {
      if y0 == y1 {
        // are we zero length? nothing to do
        return // we're done
      }
      slope = 0
      blitter_kind = VLine
    } else {
      slope = fdot16_fast_div(x1 - x0, y1 - y0)
      fstart += (slope * (32 - (y0 & 63)) + 32) >> 6
      blitter_kind = Vertish
    }
    if istop - istart == 1 {
      // we are within a single pixel
      scale_start = y1 - y0
      scale_stop = 0
    } else {
      scale_start = 64 - (y0 & 63)
      scale_stop = y1 & 63
    }
    if clip_opt is Some(clip) {
      let clip = clip.to_int_rect()
      if istart >= clip.bottom() || istop <= clip.top() {
        return // we're done
      }
      if istart < clip.top() {
        fstart += slope * (clip.top() - istart)
        istart = clip.top()
        scale_start = 64
        if istop - istart == 1 {
          // we are within a single pixel
          scale_start = contribution_64(y1)
          scale_stop = 0
        }
      }
      if istop > clip.bottom() {
        istop = clip.bottom()
        scale_stop = 0 // so we don't draw this last row
      }
      if istart == istop {
        return // we're done
      }

      // now test if our X values are completely inside the clip
      let (left, right) = if slope >= 0 {
        // L2R
        let left = fdot16_floor_to_i32(fstart - fdot16_half)
        let right = fdot16_ceil_to_i32(
          fstart + (istop - istart - 1) * slope + fdot16_half,
        )
        (left, right)
      } else {
        // R2L
        let right = fdot16_ceil_to_i32(fstart + fdot16_half)
        let left = fdot16_floor_to_i32(
          fstart + (istop - istart - 1) * slope - fdot16_half,
        )
        (left, right)
      }
      let left = left - 1
      let right = right + 1
      if left >= clip.right() || right <= clip.left() {
        return // we're done
      }
      if clip.left() <= left && clip.right() >= right {
        clip_opt = None
      }
    }
  }
  let blitter : &Blitter = match clip_opt {
    Some(clip) => RectClipBlitter::{ blitter, clip, } as &Blitter
    None => blitter
  }
  let hair = AntiHairBlitter::{ kind: blitter_kind, blitter, }
  let mut istart = istart
  let istop = istop
  fstart = hair.draw_cap(istart, fstart, slope, scale_start)
  istart += 1
  let full_spans = istop - istart - (if scale_stop > 0 { 1 } else { 0 })
  if full_spans > 0 {
    fstart = hair.draw_line(istart, istart + full_spans, fstart, slope)
  }
  if scale_stop > 0 {
    hair.draw_cap(istop - 1, fstart, slope, scale_stop) |> ignore
  }
}

///|
/// returns high-bit set if x == 0x8000
fn bad_int(x : Int) -> Int {
  x & -x
}

///|
fn any_bad_ints(a : Int, b : Int, c : Int, d : Int) -> Int {
  (bad_int(a) | bad_int(b) | bad_int(c) | bad_int(d)) >> 31
}

///|
/// We want the fractional part of ordinate, but we want multiples of 64 to
/// return 64, not 0, so we can't just say (ordinate & 63).
/// We basically want to compute those bits, and if they're 0, return 64.
/// We can do that w/o a branch with an extra sub and add.
fn contribution_64(ordinate : Int) -> Int {
  ((ordinate - 1) & 63) + 1
}

///|
/// The four `AntiHairBlitter` implementations (HLine, Horish, VLine,
/// Vertish).
priv struct AntiHairBlitter {
  kind : BlitterKind
  blitter : &Blitter
}

///|
/// `u32::max(1) - 1` on an `Int` holding a `u32`.
fn sub1_sat(x : Int) -> Int {
  if x.reinterpret_as_uint() > 1 {
    x - 1
  } else {
    0
  }
}

///|
fn AntiHairBlitter::draw_cap(
  self : AntiHairBlitter,
  x : Int,
  fy : Int,
  slope : Int,
  mod64 : Int,
) -> Int {
  match self.kind {
    HLine => {
      let mut fy = fy + fdot16_one / 2
      fy = if fy > 0 { fy } else { 0 }
      let y = fy >> 16
      let a = i32_to_alpha(fy >> 8)

      // lower line
      let mut ma = fdot6_small_scale(a, mod64)
      if ma != 0 {
        call_hline_blitter(x, Some(y), 1, ma, self.blitter)
      }

      // upper line
      ma = fdot6_small_scale(255 - a, mod64)
      if ma != 0 {
        call_hline_blitter(
          x,
          if y > 0 {
            Some(y - 1)
          } else {
            None
          },
          1,
          ma,
          self.blitter,
        )
      }
      fy - fdot16_one / 2
    }
    Horish => {
      let mut fy = fy + fdot16_one / 2
      fy = if fy > 0 { fy } else { 0 }
      let lower_y = fy >> 16
      let a = i32_to_alpha(fy >> 8)
      let a0 = fdot6_small_scale(255 - a, mod64)
      let a1 = fdot6_small_scale(a, mod64)
      self.blitter.blit_anti_v2(x, sub1_sat(lower_y), a0, a1)
      fy + slope - fdot16_one / 2
    }
    VLine => {
      let mut fx = fy + fdot16_one / 2
      fx = if fx > 0 { fx } else { 0 }
      let xx = fx >> 16
      let a = i32_to_alpha(fx >> 8)
      let mut ma = fdot6_small_scale(a, mod64)
      if ma != 0 {
        self.blitter.blit_v(xx, x, 1, ma)
      }
      ma = fdot6_small_scale(255 - a, mod64)
      if ma != 0 {
        self.blitter.blit_v(sub1_sat(xx), x, 1, ma)
      }
      fx - fdot16_one / 2
    }
    Vertish => {
      let mut fx = fy + fdot16_one / 2
      fx = if fx > 0 { fx } else { 0 }
      let xx = fx >> 16
      let a = i32_to_alpha(fx >> 8)
      self.blitter.blit_anti_h2(
        sub1_sat(xx),
        x,
        fdot6_small_scale(255 - a, mod64),
        fdot6_small_scale(a, mod64),
      )
      fx + slope - fdot16_one / 2
    }
  }
}

///|
fn AntiHairBlitter::draw_line(
  self : AntiHairBlitter,
  x : Int,
  stop_x : Int,
  fy : Int,
  slope : Int,
) -> Int {
  match self.kind {
    HLine => {
      let count = stop_x - x
      if count == 0 {
        return fy
      }
      let mut fy = fy + fdot16_one / 2
      fy = if fy > 0 { fy } else { 0 }
      let y = fy >> 16
      let mut a = i32_to_alpha(fy >> 8)

      // lower line
      if a != 0 {
        call_hline_blitter(x, Some(y), count, a, self.blitter)
      }

      // upper line
      a = 255 - a
      if a != 0 {
        call_hline_blitter(
          x,
          if y > 0 {
            Some(y - 1)
          } else {
            None
          },
          count,
          a,
          self.blitter,
        )
      }
      fy - fdot16_one / 2
    }
    Horish => {
      let mut x = x
      let mut fy = fy + fdot16_one / 2
      while true {
        fy = if fy > 0 { fy } else { 0 }
        let lower_y = fy >> 16
        let a = i32_to_alpha(fy >> 8)
        self.blitter.blit_anti_v2(x, sub1_sat(lower_y), 255 - a, a)
        fy += slope
        x += 1
        if x >= stop_x {
          break
        }
      }
      fy - fdot16_one / 2
    }
    VLine => {
      let y = x
      let stop_y = stop_x
      let height = stop_y - y
      if height == 0 {
        return fy
      }
      let mut fx = fy + fdot16_one / 2
      fx = if fx > 0 { fx } else { 0 }
      let xx = fx >> 16
      let mut a = i32_to_alpha(fx >> 8)
      if a != 0 {
        self.blitter.blit_v(xx, y, height, a)
      }
      a = 255 - a
      if a != 0 {
        self.blitter.blit_v(sub1_sat(xx), y, height, a)
      }
      fx - fdot16_one / 2
    }
    Vertish => {
      let mut y = x
      let stop_y = stop_x
      let mut fx = fy + fdot16_one / 2
      while true {
        fx = if fx > 0 { fx } else { 0 }
        let xx = fx >> 16
        let a = i32_to_alpha(fx >> 8)
        self.blitter.blit_anti_h2(sub1_sat(xx), y, 255 - a, a)
        fx += slope
        y += 1
        if y >= stop_y {
          break
        }
      }
      fx - fdot16_one / 2
    }
  }
}

///|
fn i32_to_alpha(a : Int) -> Int {
  a & 0xFF
}

///|
priv struct RectClipBlitter {
  blitter : &Blitter
  clip : ScreenIntRect
}

///|
/// `u32` subtraction-and-compare `(a - b) < c` with wrapping.
fn u32_wrapping_lt(a : Int, b : Int, c : Int) -> Bool {
  (a - b).reinterpret_as_uint() < c.reinterpret_as_uint()
}

///|
impl Blitter for RectClipBlitter with fn blit_anti_h(
  self,
  x,
  y,
  antialias,
  aa_offset,
  runs,
  runs_offset,
) {
  if !u32_wrapping_lt(y, self.clip.top(), self.clip.height()) ||
    x.reinterpret_as_uint() >= self.clip.right().reinterpret_as_uint() {
    return
  }
  let mut x0 = x
  let mut x1 = x + compute_anti_width(runs, runs_offset)
  if x1.reinterpret_as_uint() <= self.clip.left().reinterpret_as_uint() {
    return
  }
  let mut aa_offset = aa_offset
  let mut runs_offset = runs_offset
  if x0.reinterpret_as_uint() < self.clip.left().reinterpret_as_uint() {
    let dx = self.clip.left() - x0
    AlphaRuns::break_at(antialias, aa_offset, runs, runs_offset, dx)
    aa_offset += dx
    runs_offset += dx
    x0 = self.clip.left()
  }
  if x1.reinterpret_as_uint() > self.clip.right().reinterpret_as_uint() {
    x1 = self.clip.right()
    AlphaRuns::break_at(antialias, aa_offset, runs, runs_offset, x1 - x0)
    runs[runs_offset + (x1 - x0)] = 0
  }
  self.blitter.blit_anti_h(x0, y, antialias, aa_offset, runs, runs_offset)
}

///|
impl Blitter for RectClipBlitter with fn blit_v(self, x, y, height, alpha) {
  if !u32_wrapping_lt(x, self.clip.left(), self.clip.width()) {
    return
  }
  let mut y0 = y
  let mut y1 = y + height
  if y0.reinterpret_as_uint() < self.clip.top().reinterpret_as_uint() {
    y0 = self.clip.top()
  }
  if y1.reinterpret_as_uint() > self.clip.bottom().reinterpret_as_uint() {
    y1 = self.clip.bottom()
  }
  if y0.reinterpret_as_uint() < y1.reinterpret_as_uint() {
    let h = y1 - y0
    if h != 0 {
      self.blitter.blit_v(x, y0, h, alpha)
    }
  }
}

///|
impl Blitter for RectClipBlitter with fn blit_anti_h2(
  self,
  x,
  y,
  alpha0,
  alpha1,
) {
  Blitter::blit_anti_h(self, x, y, [alpha0, alpha1], 0, [1, 1, 0], 0)
}

///|
impl Blitter for RectClipBlitter with fn blit_anti_v2(
  self,
  x,
  y,
  alpha0,
  alpha1,
) {
  Blitter::blit_anti_h(self, x, y, [alpha0], 0, [1, 0], 0)
  Blitter::blit_anti_h(self, x, y + 1, [alpha1], 0, [1, 0], 0)
}

///|
fn compute_anti_width(runs : FixedArray[Int], offset : Int) -> Int {
  let mut i = offset
  let mut width = 0
  while runs[i] != 0 {
    let count = runs[i]
    width += count
    i += count
  }
  width
}
