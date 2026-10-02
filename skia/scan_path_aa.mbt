// Port of `tiny-skia/src/scan/path_aa.rs`.

///|
let supersample_shift : Int = 2

///|
let aa_shift : Int = supersample_shift

///|
let aa_scale : Int = 1 << aa_shift

///|
let aa_mask : Int = aa_scale - 1

///|
fn scan_path_aa_fill_path(
  path : @path.Path,
  fill_rule : FillRule,
  clip : ScreenIntRect,
  blitter : &Blitter,
) -> Unit {
  // Unlike `path.bounds.to_rect()?.round_out()`,
  // this method rounds out first and then converts into a Rect.
  let b = path.bounds()
  let ir = @path.Rect::from_ltrb(
    @path.floorf(b.left()),
    @path.floorf(b.top()),
    @path.ceilf(b.right()),
    @path.ceilf(b.bottom()),
  ).bind(r => r.round_out())
  guard ir is Some(ir) else { return }

  // TODO: remove
  // If the intersection of the path bounds and the clip bounds
  // will overflow 32767 when << by SHIFT, we can't supersample,
  // so draw without antialiasing.
  guard ir.intersect(clip.to_int_rect()) is Some(clipped_ir) else { return }
  if rect_overflows_short_shift(clipped_ir, aa_shift) != 0 {
    scan_path_fill_path(path, fill_rule, clip, blitter)
    return
  }

  // TODO: remove
  // Our antialiasing can't handle a clip larger than 32767.
  // TODO: skia actually limits the clip to 32767
  {
    let max_clip_coord = 32767
    if clip.right() > max_clip_coord || clip.bottom() > max_clip_coord {
      return
    }
  }

  // TODO: SkScanClipper
  // TODO: AAA

  scan_path_aa_fill_path_impl(path, fill_rule, ir, clip, blitter)
}

///|
/// Would any of the coordinates of this rectangle not fit in a short,
/// when left-shifted by shift?
fn rect_overflows_short_shift(rect : @path.IntRect, shift : Int) -> Int {
  overflows_short_shift(rect.left(), shift) |
  overflows_short_shift(rect.top(), shift) |
  overflows_short_shift(rect.right(), shift) |
  overflows_short_shift(rect.bottom(), shift)
}

///|
fn overflows_short_shift(value : Int, shift : Int) -> Int {
  let s = 16 + shift
  (left_shift(value, s) >> s) - value
}

///|
fn scan_path_aa_fill_path_impl(
  path : @path.Path,
  fill_rule : FillRule,
  bounds : @path.IntRect,
  clip : ScreenIntRect,
  blitter : &Blitter,
) -> Unit {
  // TODO: MaskSuperBlitter

  // TODO: 15% slower than skia, find out why
  guard SuperBlitter::new(bounds, clip, blitter) is Some(super_blitter) else { // clipped out, nothing else to do
    return
  }
  let path_contained_in_clip = match int_rect_to_screen_int_rect(bounds) {
    Some(bounds) => clip.contains(bounds)
    // If bounds cannot be converted into ScreenIntRect,
    // the path is out of clip.
    None => false
  }
  scan_fill_path_impl(
    path,
    fill_rule,
    clip,
    bounds.top(),
    bounds.bottom(),
    aa_shift,
    path_contained_in_clip,
    super_blitter,
  )
  // `Drop for SuperBlitter`.
  super_blitter.flush()
}

///|
priv struct SuperBlitter {
  // BaseSuperBlitter
  real_blitter : &Blitter
  mut curr_iy : Int
  width : Int
  left : Int
  super_left : Int
  mut curr_y : Int
  top : Int
  // SuperBlitter
  runs : AlphaRuns
  mut offset_x : Int
}

///|
fn SuperBlitter::new(
  bounds : @path.IntRect,
  clip_rect : ScreenIntRect,
  blitter : &Blitter,
) -> SuperBlitter? {
  guard bounds.intersect(clip_rect.to_int_rect()) is Some(sect) else {
    return None
  }
  guard int_rect_to_screen_int_rect(sect) is Some(sect) else { return None }
  Some({
    real_blitter: blitter,
    curr_iy: sect.top() - 1,
    width: sect.width(),
    left: sect.left(),
    super_left: sect.left() << aa_shift,
    curr_y: (sect.top() << aa_shift) - 1,
    top: sect.top(),
    runs: AlphaRuns::new(sect.width()),
    offset_x: 0,
  })
}

///|
fn SuperBlitter::flush(self : SuperBlitter) -> Unit {
  if self.curr_iy >= self.top {
    if !self.runs.is_empty() {
      self.real_blitter.blit_anti_h(
        self.left,
        self.curr_iy,
        self.runs.alpha,
        0,
        self.runs.runs,
        0,
      )
      self.runs.reset(self.width)
      self.offset_x = 0
    }
    self.curr_iy = self.top - 1
  }
}

///|
impl Blitter for SuperBlitter with fn blit_h(self, x, y, width) {
  let mut x = x
  let mut width = width
  let iy = y >> aa_shift

  // hack, until I figure out why my cubics (I think) go beyond the bounds
  if x.reinterpret_as_uint() >= self.super_left.reinterpret_as_uint() {
    x = x - self.super_left
  } else {
    width = x + width
    x = 0
  }
  if self.curr_y != y {
    self.offset_x = 0
    self.curr_y = y
  }
  if iy != self.curr_iy {
    // new scanline
    self.flush()
    self.curr_iy = iy
  }
  let start = x
  let stop = x + width

  // integer-pixel-aligned ends of blit, rounded out
  let mut fb = start & aa_mask
  let mut fe = stop & aa_mask
  let mut n = (stop >> aa_shift) - (start >> aa_shift) - 1
  if n < 0 {
    fb = fe - fb
    n = 0
    fe = 0
  } else if fb == 0 {
    n += 1
  } else {
    fb = aa_scale - fb
  }
  let max_value = (1 << (8 - aa_shift)) - (((y & aa_mask) + 1) >> aa_shift)
  self.offset_x = self.runs.add(
    x >> aa_shift,
    coverage_to_partial_alpha(fb),
    n,
    coverage_to_partial_alpha(fe),
    max_value,
    self.offset_x,
  )
}

///|
/// coverage_to_partial_alpha() is being used by AlphaRuns, which
/// *accumulates* SCALE pixels worth of "alpha" in [0,(256/SCALE)]
/// to produce a final value in [0, 255] and handles clamping 256->255
/// itself, with the same (alpha - (alpha >> 8)) correction as
/// coverage_to_exact_alpha().
fn coverage_to_partial_alpha(aa : Int) -> Int {
  (aa << (8 - 2 * aa_shift)) & 0xFF
}
