// Port of `tiny-skia/src/alpha_runs.rs`.
//
// `AlphaRun` (`Option<NonZeroU16>`) is an `Int` where 0 means `None`.
// Slices are represented by an array and an offset.

///|
/// Sparse array of run-length-encoded alpha (supersampling coverage) values.
///
/// Sparseness allows us to independently compose several paths into the
/// same AlphaRuns buffer.
priv struct AlphaRuns {
  runs : FixedArray[Int]
  alpha : FixedArray[Int]
}

///|
fn AlphaRuns::new(width : Int) -> AlphaRuns {
  let runs : AlphaRuns = {
    runs: FixedArray::make(width + 1, 0),
    alpha: FixedArray::make(width + 1, 0),
  }
  runs.reset(width)
  runs
}

///|
/// Returns 0-255 given 0-256.
fn AlphaRuns::catch_overflow(alpha : Int) -> Int {
  (alpha - (alpha >> 8)) & 0xFF
}

///|
/// Returns true if the scanline contains only a single run, of alpha value 0.
fn AlphaRuns::is_empty(self : AlphaRuns) -> Bool {
  let run = self.runs[0]
  if run != 0 {
    self.alpha[0] == 0 && self.runs[run] == 0
  } else {
    true
  }
}

///|
/// Reinitialize for a new scanline.
fn AlphaRuns::reset(self : AlphaRuns, width : Int) -> Unit {
  self.runs[0] = width & 0xFFFF
  self.runs[width] = 0
  self.alpha[0] = 0
}

///|
/// Insert into the buffer a run starting at (x-offset_x).
///
/// if start_alpha > 0
///     one pixel with value += start_alpha,
///         max 255
/// if middle_count > 0
///     middle_count pixels with value += max_value
/// if stop_alpha > 0
///     one pixel with value += stop_alpha
///
/// Returns the offset_x value that should be passed on the next call, assuming
/// we're on the same scanline. If the caller is switching scanlines, then
/// offset_x should be 0 when this is called.
fn AlphaRuns::add(
  self : AlphaRuns,
  x : Int,
  start_alpha : Int,
  middle_count : Int,
  stop_alpha : Int,
  max_value : Int,
  offset_x : Int,
) -> Int {
  let mut x = x
  let mut middle_count = middle_count
  let mut runs_offset = offset_x
  let mut alpha_offset = offset_x
  let mut last_alpha_offset = offset_x
  x -= offset_x
  if start_alpha != 0 {
    AlphaRuns::break_run(self.runs, runs_offset, self.alpha, alpha_offset, x, 1)
    // I should be able to just add alpha[x] + start_alpha.
    // However, if the trailing edge of the previous span and the leading
    // edge of the current span round to the same super-sampled x value,
    // I might overflow to 256 with this add, hence the funny subtract (crud).
    let tmp = self.alpha[alpha_offset + x] + start_alpha
    // was (tmp >> 7), but that seems wrong if we're trying to catch 256
    self.alpha[alpha_offset + x] = (tmp - (tmp >> 8)) & 0xFF
    runs_offset += x + 1
    alpha_offset += x + 1
    x = 0
  }
  if middle_count != 0 {
    AlphaRuns::break_run(
      self.runs,
      runs_offset,
      self.alpha,
      alpha_offset,
      x,
      middle_count,
    )
    alpha_offset += x
    runs_offset += x
    x = 0
    while true {
      let a = AlphaRuns::catch_overflow(self.alpha[alpha_offset] + max_value)
      self.alpha[alpha_offset] = a
      let n = self.runs[runs_offset]
      alpha_offset += n
      runs_offset += n
      middle_count -= n
      if middle_count == 0 {
        break
      }
    }
    last_alpha_offset = alpha_offset
  }
  if stop_alpha != 0 {
    AlphaRuns::break_run(self.runs, runs_offset, self.alpha, alpha_offset, x, 1)
    alpha_offset += x
    self.alpha[alpha_offset] = (self.alpha[alpha_offset] + stop_alpha) & 0xFF
    last_alpha_offset = alpha_offset
  }

  // new offset_x
  last_alpha_offset
}

///|
/// Break the runs in the buffer at offsets x and x+count, properly updating
/// the runs to the right and left.
///
/// i.e. from the state AAAABBBB, run-length encoded as A4B4,
/// break_run(..., 2, 5) would produce AAAABBBB rle as A2A2B3B1.
/// Allows add() to sum another run to some of the new sub-runs.
/// i.e. adding ..CCCCC. would produce AADDEEEB, rle as A2D2E3B1.
fn AlphaRuns::break_run(
  runs : FixedArray[Int],
  runs_base : Int,
  alpha : FixedArray[Int],
  alpha_base : Int,
  x : Int,
  count : Int,
) -> Unit {
  let orig_x = x
  let mut x = x
  let mut runs_offset = runs_base
  let mut alpha_offset = alpha_base
  while x > 0 {
    let n = runs[runs_offset]
    if x < n {
      alpha[alpha_offset + x] = alpha[alpha_offset]
      runs[runs_offset + 0] = x & 0xFFFF
      runs[runs_offset + x] = (n - x) & 0xFFFF
      break
    }
    runs_offset += n
    alpha_offset += n
    x -= n
  }
  runs_offset = runs_base + orig_x
  alpha_offset = alpha_base + orig_x
  x = count
  while true {
    let n = runs[runs_offset]
    if x < n {
      alpha[alpha_offset + x] = alpha[alpha_offset]
      runs[runs_offset + 0] = x & 0xFFFF
      runs[runs_offset + x] = (n - x) & 0xFFFF
      break
    }
    x -= n
    if x == 0 {
      break
    }
    runs_offset += n
    alpha_offset += n
  }
}

///|
/// Cut (at offset x in the buffer) a run into two shorter runs with
/// matching alpha values.
///
/// Used by the RectClipBlitter to trim a RLE encoding to match the
/// clipping rectangle.
fn AlphaRuns::break_at(
  alpha : FixedArray[Int],
  alpha_base : Int,
  runs : FixedArray[Int],
  runs_base : Int,
  x : Int,
) -> Unit {
  let mut x = x
  let mut alpha_i = alpha_base
  let mut run_i = runs_base
  while x > 0 {
    let n = runs[run_i]
    if x < n {
      alpha[alpha_i + x] = alpha[alpha_i]
      runs[runs_base] = x & 0xFFFF
      runs[runs_base + x] = (n - x) & 0xFFFF
      break
    }
    run_i += n
    alpha_i += n
    x -= n
  }
}
