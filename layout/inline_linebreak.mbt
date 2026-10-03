// Port of `typst-layout/src/inline/linebreak.rs` (line selection). The
// break opportunities themselves (`breakpoints`, `Breakpoint`, `Trim`) live
// in the `linebreak` package.

// Cost parameters.
//
// We choose higher costs than the Knuth-Plass paper (which would be 50)
// because it hyphenates way to eagerly in Typst otherwise. Could be related
// to the ratios coming out differently since Typst doesn't have the concept
// of glue, so things work a bit differently.

///|
const DEFAULT_HYPH_COST : Double = 135.0

///|
const DEFAULT_RUNT_COST : Double = 100.0

// Other parameters.

///|
const MIN_RATIO : Double = -1.0

///|
const MIN_APPROX_RATIO : Double = -0.5

///|
const BOUND_EPS : Double = 1.0e-3

///|
/// Breaks the text into lines.
fn linebreak(
  engine : @library.Engine,
  p : Preparation,
  width : @library.Abs,
) -> Array[Line] {
  match p.config.linebreaks {
    Simple => linebreak_simple(engine, p, width)
    Optimized => linebreak_optimized(engine, p, width)
  }
}

///|
/// Performs line breaking in simple first-fit style. This means that we
/// build lines greedily, always taking the longest possible line. This may
/// lead to very unbalanced line, but is fast and simple.
fn linebreak_simple(
  engine : @library.Engine,
  p : Preparation,
  width : @library.Abs,
) -> Array[Line] {
  let lines : Array[Line] = []
  let mut start = 0
  let mut last : (Line, Int)? = None
  breakpoints(p, (end, breakpoint) => {
    // Compute the line and its size.
    let mut attempt = line(engine, p, start, end, breakpoint, lines.last())

    // If the line doesn't fit anymore, we push the last fitting attempt
    // into the stack and rebuild the line from the attempt's end. The
    // resulting line cannot be broken up further.
    if !width.fits(attempt.width) && last is Some((last_attempt, last_end)) {
      last = None
      lines.push(last_attempt)
      start = last_end
      attempt = line(engine, p, start, end, breakpoint, lines.last())
    }

    // Finish the current line if there is a mandatory line break (i.e. due
    // to "\n") or if the line doesn't fit horizontally already since then
    // no shorter line will be possible.
    if breakpoint == Mandatory || !width.fits(attempt.width) {
      lines.push(attempt)
      start = end
      last = None
    } else {
      last = Some((attempt, end))
    }
  })
  if last is Some((line, _)) {
    lines.push(line)
  }
  lines
}

///|
/// Performs line breaking in optimized Knuth-Plass style. Here, we use more
/// context to determine the line breaks than in the simple first-fit style.
/// For example, we might choose to cut a line short even though there is
/// still a bit of space to improve the fit of one of the following lines.
/// The Knuth-Plass algorithm is based on the idea of "cost". A line which
/// has a very tight or very loose fit has a higher cost than one that is
/// just right. Ending a line with a hyphen incurs extra cost and endings two
/// successive lines with hyphens even more.
///
/// To find the layout with the minimal total cost the algorithm uses
/// dynamic programming: For each possible breakpoint, it determines the
/// optimal layout _up to that point_. It walks over all possible start
/// points for a line ending at that point and finds the one for which the
/// cost of the line plus the cost of the optimal layout up to the start
/// point (already computed and stored in dynamic programming table) is
/// minimal. The final result is simply the layout determined for the last
/// breakpoint at the end of text.
fn linebreak_optimized(
  engine : @library.Engine,
  p : Preparation,
  width : @library.Abs,
) -> Array[Line] {
  let metrics = CostMetrics::compute(p)

  // Determines the exact costs of a likely good layout through Knuth-Plass
  // with approximate metrics. We can use this cost as an upper bound to
  // prune the search space in our proper optimization pass below.
  let upper_bound = linebreak_optimized_approximate(engine, p, width, metrics)

  // Using the upper bound, perform exact optimized linebreaking.
  linebreak_optimized_bounded(engine, p, width, metrics, upper_bound)
}

///|
/// An entry in the dynamic programming table for inline layout
/// optimization.
priv struct BoundedEntry {
  pred : Int
  total : Double
  line : Line
  end : Int
}

///|
/// Performs line breaking in optimized Knuth-Plass style, but with an upper
/// bound on the cost. This allows us to skip many parts of the search
/// space.
fn linebreak_optimized_bounded(
  engine : @library.Engine,
  p : Preparation,
  width : @library.Abs,
  metrics : CostMetrics,
  upper_bound : Double,
) -> Array[Line] {
  // Dynamic programming table.
  let table : Array[BoundedEntry] = [
    { pred: 0, total: 0.0, line: Line::empty(), end: 0, },
  ]
  let mut active = 0
  let mut prev_end = 0
  breakpoints(p, (end, breakpoint) => {
    // Find the optimal predecessor.
    let mut best : BoundedEntry? = None

    // A lower bound for the cost of all following line attempts.
    let mut line_lower_bound : Double? = None
    for pred_index in active..<table.length() {
      let pred = table[pred_index]
      let start = pred.end
      let unbreakable = prev_end == start

      // If the minimum cost we've established for the line is already too
      // much, skip this attempt.
      if line_lower_bound is Some(lower) &&
        pred.total + lower > upper_bound + BOUND_EPS {
        continue
      }

      // Build the line.
      let attempt = line(engine, p, start, end, breakpoint, Some(pred.line))

      // Determine the cost of the line and its stretch ratio.
      let (line_ratio, line_cost) = ratio_and_cost(
        p,
        metrics,
        width,
        pred.line,
        attempt,
        breakpoint,
        unbreakable,
      )

      // If the line is overfull, we adjust the set of active candidate line
      // starts. This is the case if
      // - justification is on, but we'd need to shrink too much
      // - justification is off and the line just doesn't fit
      //
      // If this is the earliest breakpoint in the active set
      // (active == i), remove it from the active set. If there is an
      // earlier one (active < i), then the logically shorter line was in
      // fact longer (can happen with negative spacing) and we can't trim
      // the active set just yet.
      if line_ratio < metrics.min_ratio && active == pred_index {
        active += 1
      }

      // The total cost of this line and its chain of predecessors.
      let total = pred.total + line_cost

      // If the line is already underfull (`line_ratio > 0`), any shorter
      // slice of the line will be even more underfull. So it'll only get
      // worse from here and further attempts would also have a cost
      // exceeding `bound`. There is one exception: When the line has
      // negative spacing, we can't know for sure, so we don't assign the
      // lower bound in that case.
      if line_ratio > 0.0 &&
        line_lower_bound is None &&
        !attempt.has_negative_width_items() {
        line_lower_bound = Some(line_cost)
      }

      // If the cost already exceeds the upper bound, we don't need to
      // integrate this result into the table.
      if total > upper_bound + BOUND_EPS {
        continue
      }

      // If this attempt is better than what we had before, take it!
      let better = match best {
        None => true
        Some(best) => best.total >= total
      }
      if better {
        best = Some({ pred: pred_index, total, line: attempt, end, })
      }
    }

    // If this is a mandatory break, all breakpoints before this one become
    // inactive since no line can span over the mandatory break.
    if breakpoint == Mandatory {
      active = table.length()
    }
    if best is Some(best) {
      table.push(best)
    }
    prev_end = end
  })

  // Retrace the best path.
  let lines = []
  let mut idx = table.length() - 1

  // This should only happen if our bound was faulty. Which shouldn't
  // happen!
  if table[idx].end != p.text.len() {
    return linebreak_optimized_bounded(
      engine, p, width, metrics, @double.infinity,
    )
  }
  while idx != 0 {
    let entry = table[idx]
    lines.push(entry.line)
    idx = entry.pred
  }
  lines.rev_in_place()
  lines
}

///|
/// An entry in the approximate dynamic programming table.
priv struct ApproxEntry {
  pred : Int
  total : Double
  end : Int
  unbreakable : Bool
  breakpoint : @linebreak.Breakpoint
}

///|
/// Runs the normal Knuth-Plass algorithm, but instead of building proper
/// lines (which is costly) to determine costs, it determines approximate
/// costs using cumulative arrays.
///
/// This results in a likely good inline layouts, for which we then compute
/// the exact cost. This cost is an upper bound for proper optimized
/// linebreaking. We can use it to heavily prune the search space.
fn linebreak_optimized_approximate(
  engine : @library.Engine,
  p : Preparation,
  width : @library.Abs,
  metrics : CostMetrics,
) -> Double {
  // Determine the cumulative estimation metrics.
  let estimates = Estimates::compute(p)

  // Dynamic programming table.
  let table : Array[ApproxEntry] = [
    { pred: 0, total: 0.0, end: 0, unbreakable: false, breakpoint: Mandatory, },
  ]
  let mut active = 0
  let mut prev_end = 0
  breakpoints(p, (end, breakpoint) => {
    // Find the optimal predecessor.
    let mut best : ApproxEntry? = None
    for pred_index in active..<table.length() {
      let pred = table[pred_index]
      let start = pred.end
      let unbreakable = prev_end == start

      // Whether the line is justified. This is not 100% accurate w.r.t to
      // line()'s behaviour, but good enough.
      let justify = p.config.justify && breakpoint != Mandatory

      // We don't really know whether the line naturally ends with a dash
      // here, so we can miss that case, but it's ok, since all of this
      // just an estimate.
      let consecutive_dash = pred.breakpoint.is_hyphen() &&
        breakpoint.is_hyphen()

      // Estimate how much the line's spaces would need to be stretched to
      // make it the desired width. We trim at the end to not take into
      // account trailing spaces. This is, again, only an approximation of
      // the real behaviour of `line`.
      let trimmed_end = start +
        p.text
        .slice(start, end)
        .trim_end_len(c => @unicode.is_whitespace(char_of(c)))
      let line_ratio = raw_ratio(
        p,
        width,
        estimates.widths.estimate(start, trimmed_end) +
        (if breakpoint.is_hyphen() {
          metrics.approx_hyphen_width
        } else {
          @library.Abs::zero()
        }),
        estimates.stretchability.estimate(start, trimmed_end),
        estimates.shrinkability.estimate(start, trimmed_end),
        estimates.justifiables.estimate(start, trimmed_end),
      )

      // Determine the line's cost.
      let line_cost = raw_cost(
        metrics, breakpoint, line_ratio, justify, unbreakable, consecutive_dash,
        true,
      )

      // Adjust the set of active breakpoints.
      // See `linebreak_optimized` for details.
      if line_ratio < metrics.min_ratio && active == pred_index {
        active += 1
      }

      // The total cost of this line and its chain of predecessors.
      let total = pred.total + line_cost

      // If this attempt is better than what we had before, take it!
      let better = match best {
        None => true
        Some(best) => best.total >= total
      }
      if better {
        best = Some({ pred: pred_index, total, end, unbreakable, breakpoint, })
      }
    }

    // If this is a mandatory break, all breakpoints before this one become
    // inactive.
    if breakpoint == Mandatory {
      active = table.length()
    }
    if best is Some(best) {
      table.push(best)
    }
    prev_end = end
  })

  // Retrace the best path.
  let indices = []
  let mut idx = table.length() - 1
  while idx != 0 {
    indices.push(idx)
    idx = table[idx].pred
  }
  let mut pred = Line::empty()
  let mut start = 0
  let mut exact = 0.0

  // The cost that we optimized was only an approximate cost, so the layout
  // we got here is only likely to be good, not guaranteed to be the best.
  // We now computes its exact cost as that gives us a sound upper bound for
  // the proper optimization pass.
  for k = indices.length() - 1; k >= 0; k = k - 1 {
    let { end, breakpoint, unbreakable, .. } = table[indices[k]]
    let attempt = line(engine, p, start, end, breakpoint, Some(pred))
    let (ratio, line_cost) = ratio_and_cost(
      p, metrics, width, pred, attempt, breakpoint, unbreakable,
    )

    // If approximation produces a valid layout without too much shrinking,
    // exact layout is guaranteed to find the same layout. If, however, the
    // line is overfull, we do not have this guarantee. Then, our bound
    // becomes useless and actively harmful (it could be lower than what
    // optimal layout produces). Thus, we immediately bail with an infinite
    // bound in this case.
    if ratio < metrics.min_ratio {
      return @double.infinity
    }
    pred = attempt
    start = end
    exact += line_cost
  }
  exact
}

///|
/// Compute the stretch ratio and cost of a line.
fn ratio_and_cost(
  p : Preparation,
  metrics : CostMetrics,
  available_width : @library.Abs,
  pred : Line,
  attempt : Line,
  breakpoint : @linebreak.Breakpoint,
  unbreakable : Bool,
) -> (Double, Double) {
  let ratio = raw_ratio(
    p,
    available_width,
    attempt.width,
    attempt.stretchability(),
    attempt.shrinkability(),
    attempt.justifiables(),
  )
  let cost = raw_cost(
    metrics,
    breakpoint,
    ratio,
    attempt.justify,
    unbreakable,
    pred.dash is Some(_) && attempt.dash is Some(_),
    false,
  )
  (ratio, cost)
}

///|
/// Determine the stretch ratio for a line given raw metrics.
///
/// - A ratio less than [`CostMetrics::min_ratio`] indicates an overfull
///   line.
/// - A negative ratio indicates a line that needs shrinking.
/// - A ratio of zero indicates a perfect line.
/// - A positive ratio indicates a line that needs stretching.
fn raw_ratio(
  p : Preparation,
  available_width : @library.Abs,
  line_width : @library.Abs,
  stretchability : @library.Abs,
  shrinkability : @library.Abs,
  justifiables : Int,
) -> Double {
  // Determine how much the line's spaces would need to be stretched to make
  // it the desired width.
  let mut delta = available_width - line_width

  // Avoid possible floating point errors in previous calculation.
  if delta.approx_eq(@library.Abs::zero()) {
    delta = @library.Abs::zero()
  }

  // Determine how much stretch or shrink is natural.
  let adjustability = if delta >= @library.Abs::zero() {
    stretchability
  } else {
    shrinkability
  }

  // Observations:
  // - `delta` is negative for a line that needs shrinking and positive for
  //   a line that needs stretching.
  // - `adjustability` must be non-negative to make sense.
  // - `ratio` inherits the sign of `delta`.
  let mut ratio = delta.to_raw() /
    adjustability.max(@library.Abs::zero()).to_raw()

  // The most likely cause of a NaN result is that `delta` was zero. This
  // often happens with monospace fonts and CJK texts. It means that the
  // line already fits perfectly, so `ratio` should be zero then.
  if ratio.is_nan() {
    ratio = 0.0
  }

  // If the ratio exceeds 1, we should stretch above the natural
  // stretchability using justifiables.
  if ratio > 1.0 {
    // We should stretch the line above its stretchability. Now calculate
    // the extra amount. Also, don't divide by zero.
    let extra_stretch = (delta - adjustability).div_by(
      (if justifiables > 1 { justifiables } else { 1 }).to_double(),
    )
    // Normalize the amount by half the em size.
    ratio = 1.0 +
      extra_stretch.to_raw() / p.config.font_size.div_by(2.0).to_raw()
  }

  // The min value must be < MIN_RATIO, but how much smaller doesn't matter
  // since overfull lines have hard-coded huge costs anyway.
  //
  // The max value is clamped to 10 since it doesn't really matter whether a
  // line is stretched 10x or 20x.
  f64_clamp(ratio, MIN_RATIO - 1.0, 10.0)
}

///|
/// Rust's `f64::clamp`.
fn f64_clamp(x : Double, min : Double, max : Double) -> Double {
  let mut x = x
  if x < min {
    x = min
  }
  if x > max {
    x = max
  }
  x
}

///|
/// Rust's `f64::powi(n)` for small positive `n` (LLVM expands constant
/// exponents into repeated multiplication).
fn powi(x : Double, n : Int) -> Double {
  // `__powidf2`: repeated squaring.
  let mut r = 1.0
  let mut a = x
  let mut b = n
  while true {
    if b % 2 != 0 {
      r = r * a
    }
    b = b / 2
    if b == 0 {
      break
    }
    a = a * a
  }
  r
}

///|
/// Scalar construction (NaN becomes zero).
fn scalar_new(x : Double) -> Double {
  if x.is_nan() {
    0.0
  } else {
    x
  }
}

///|
/// Compute the cost of a line given raw metrics.
///
/// This mostly follows the formula in the Knuth-Plass paper, but there are
/// some adjustments.
fn raw_cost(
  metrics : CostMetrics,
  breakpoint : @linebreak.Breakpoint,
  ratio : Double,
  justify : Bool,
  unbreakable : Bool,
  consecutive_dash : Bool,
  approx : Bool,
) -> Double {
  // Determine the stretch/shrink cost of the line.
  let badness = if ratio < metrics.min_ratio_for(approx) {
    // Overfull line always has maximum cost.
    1_000_000.0
  } else if breakpoint != Mandatory || justify || ratio < 0.0 {
    // If the line shall be justified or needs shrinking, it has normal
    // badness with cost 100|ratio|^3. We limit the ratio to 10 as to not
    // get to close to our maximum cost.
    100.0 * scalar_new(powi(scalar_new(ratio.abs()), 3))
  } else {
    // If the line shouldn't be justified and doesn't need shrink, we don't
    // pay any cost.
    0.0
  }

  // Compute penalties.
  let mut penalty = 0.0

  // Penalize runts (lone words before a mandatory break / at the end).
  if unbreakable && breakpoint == Mandatory {
    penalty += metrics.runt_cost
  }

  // Penalize hyphenation.
  if breakpoint is Hyphen(l, r) {
    // We penalize hyphenations close to the edges of the word (< LIMIT
    // chars) extra. For each step of distance from the limit, we add 15% to
    // the cost.
    let limit = 5
    let steps = (if l < limit { limit - l } else { 0 }) +
      (if r < limit { limit - r } else { 0 })
    let extra = 0.15 * steps.to_double()
    penalty += (1.0 + extra) * metrics.hyph_cost
  }

  // Penalize two consecutive dashes extra (not necessarily hyphens).
  // Knuth-Plass does this separately after the squaring, with a higher
  // cost, but I couldn't find any explanation as to why.
  if consecutive_dash {
    penalty += metrics.hyph_cost
  }

  // From the Knuth-Plass Paper: $ (1 + beta_j + pi_j)^2 $.
  //
  // We add one to minimize the number of lines when everything else is more
  // or less equal.
  scalar_new(powi(scalar_new(1.0 + badness + penalty), 2))
}

///|
/// Calls `f` for all possible points in the text where lines can broken.
fn breakpoints(
  p : Preparation,
  f : (Int, @linebreak.Breakpoint) -> Unit,
) -> Unit {
  let (ends, kinds) = match p.breakpoints {
    Some(all) => all
    None => {
      let ends = []
      let kinds = []
      let hyphenate = p.config.hyphenate != Some(false)
      let cj = p.config.lang is Some(lang) && lang.as_str() is ("zh" | "ja")
      @linebreak.breakpoints(
        p.text.to_string(),
        cj~,
        hyphenate~,
        lang_at=offset => lang_at(p, offset),
        hyphenate_at=offset => hyphenate_at(p, offset),
        (end, breakpoint) => {
          ends.push(end)
          kinds.push(breakpoint)
        },
      )
      p.breakpoints = Some((ends, kinds))
      (ends, kinds)
    }
  }
  for i in 0..<ends.length() {
    f(ends[i], kinds[i])
  }
}

///|
/// Whether hyphenation is enabled at the given offset.
fn hyphenate_at(p : Preparation, offset : Int) -> Bool {
  match p.config.hyphenate {
    Some(v) => v
    None => {
      let (_, _, item) = p.get(offset)
      match item.text() {
        Some(text) =>
          match @library.TextElem::hyphenate_in(text.styles) {
            Custom(v) => v
            Auto => p.config.justify
          }
        None => false
      }
    }
  }
}

///|
/// The text language at the given offset.
fn lang_at(p : Preparation, offset : Int) -> @hypher.Lang? {
  let lang = match p.config.lang {
    Some(lang) => lang
    None => {
      let (_, _, item) = p.get(offset)
      guard item.text() is Some(text) else { return None }
      @library.TextElem::lang_in(text.styles)
    }
  }
  let s = lang.as_str()
  // `lang.as_str().as_bytes().try_into()` requires exactly two bytes.
  if utf8_str_len(s) != 2 {
    return None
  }
  @hypher.Lang::from_iso(s)
}

///|
/// Resolved metrics relevant for cost computation.
priv struct CostMetrics {
  min_ratio : Double
  min_approx_ratio : Double
  approx_hyphen_width : @library.Abs
  hyph_cost : Double
  runt_cost : Double
}

///|
/// Compute shared metrics for inline layout optimization.
fn CostMetrics::compute(p : Preparation) -> CostMetrics {
  {
    // When justifying, we may stretch spaces below their natural width.
    min_ratio: if p.config.justify {
      MIN_RATIO
    } else {
      0.0
    },
    min_approx_ratio: if p.config.justify {
      MIN_APPROX_RATIO
    } else {
      0.0
    },
    // Approximate hyphen width for estimates.
    approx_hyphen_width: @library.Em::new(0.33).at(p.config.font_size),
    // Costs.
    hyph_cost: DEFAULT_HYPH_COST * p.config.costs.hyphenation().get(),
    runt_cost: DEFAULT_RUNT_COST * p.config.costs.runt().get(),
  }
}

///|
/// The minimum line ratio we allow for shrinking. For approximate layout,
/// we allow less because otherwise we get an invalid layout fairly often,
/// which makes our bound useless.
fn CostMetrics::min_ratio_for(self : CostMetrics, approx : Bool) -> Double {
  if approx {
    self.min_approx_ratio
  } else {
    self.min_ratio
  }
}

///|
/// Estimated line metrics.
///
/// Allows to get a quick estimate of a metric for a line between two byte
/// positions.
priv struct Estimates {
  widths : CumulativeVec
  stretchability : CumulativeVec
  shrinkability : CumulativeVec
  justifiables : CumulativeIntVec
}

///|
/// Compute estimations for approximate Knuth-Plass layout.
fn Estimates::compute(p : Preparation) -> Estimates {
  let cap = p.text.len()
  let widths = CumulativeVec::with_capacity(cap)
  let stretchability = CumulativeVec::with_capacity(cap)
  let shrinkability = CumulativeVec::with_capacity(cap)
  let justifiables = CumulativeIntVec::with_capacity(cap)
  for entry in p.items {
    let (start, end, item) = entry
    if item is Text(shaped) {
      for g in shaped.glyphs.kept() {
        let byte_len = g.range_end - g.range_start
        let (sl, sr) = g.stretchability()
        let (hl, hr) = g.shrinkability()
        widths.push(byte_len, g.x_advance.at(g.size))
        stretchability.push(byte_len, (sl + sr).at(g.size))
        shrinkability.push(byte_len, (hl + hr).at(g.size))
        justifiables.push(byte_len, if g.is_justifiable() { 1 } else { 0 })
      }
    } else {
      widths.push(end - start, item.natural_width())
    }
    widths.adjust(end)
    stretchability.adjust(end)
    shrinkability.adjust(end)
    justifiables.adjust(end)
  }
  { widths, stretchability, shrinkability, justifiables, }
}

///|
/// An accumulative array of a metric.
priv struct CumulativeVec {
  mut total : @library.Abs
  summed : Array[@library.Abs]
}

///|
/// Create a new instance with the given capacity.
fn CumulativeVec::with_capacity(capacity : Int) -> CumulativeVec {
  let total = @library.Abs::zero()
  let summed = Array::new(capacity~)
  summed.push(total)
  { total, summed, }
}

///|
/// Adjust to cover the given byte length.
fn CumulativeVec::adjust(self : CumulativeVec, len : Int) -> Unit {
  if len < self.summed.length() {
    self.summed.truncate(len)
  } else {
    while self.summed.length() < len {
      self.summed.push(self.total)
    }
  }
}

///|
/// Adds a new segment with the given byte length and metric.
fn CumulativeVec::push(
  self : CumulativeVec,
  byte_len : Int,
  metric : @library.Abs,
) -> Unit {
  self.total = self.total + metric
  for _ in 0..<byte_len {
    self.summed.push(self.total)
  }
}

///|
/// Estimates the metrics for the line spanned by the range.
fn CumulativeVec::estimate(
  self : CumulativeVec,
  start : Int,
  end : Int,
) -> @library.Abs {
  self.get(end) - self.get(start)
}

///|
/// Get the metric at the given byte position.
fn CumulativeVec::get(self : CumulativeVec, index : Int) -> @library.Abs {
  if index == 0 {
    @library.Abs::zero()
  } else {
    self.summed[index - 1]
  }
}

///|
/// An accumulative array of an integer metric.
priv struct CumulativeIntVec {
  mut total : Int
  summed : Array[Int]
}

///|
fn CumulativeIntVec::with_capacity(capacity : Int) -> CumulativeIntVec {
  let summed = Array::new(capacity~)
  summed.push(0)
  { total: 0, summed, }
}

///|
fn CumulativeIntVec::adjust(self : CumulativeIntVec, len : Int) -> Unit {
  if len < self.summed.length() {
    self.summed.truncate(len)
  } else {
    while self.summed.length() < len {
      self.summed.push(self.total)
    }
  }
}

///|
fn CumulativeIntVec::push(
  self : CumulativeIntVec,
  byte_len : Int,
  metric : Int,
) -> Unit {
  self.total = self.total + metric
  for _ in 0..<byte_len {
    self.summed.push(self.total)
  }
}

///|
fn CumulativeIntVec::estimate(
  self : CumulativeIntVec,
  start : Int,
  end : Int,
) -> Int {
  self.get(end) - self.get(start)
}

///|
fn CumulativeIntVec::get(self : CumulativeIntVec, index : Int) -> Int {
  if index == 0 {
    0
  } else {
    self.summed[index - 1]
  }
}
