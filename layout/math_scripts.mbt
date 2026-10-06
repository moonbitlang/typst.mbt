// Port of `typst-layout/src/math/scripts.rs`.

///|
/// Upstream `measure!(e, attr)`: the attribute of an optional fragment, or
/// zero.
fn measure(
  e : MathFragment?,
  attr : (MathFragment) -> @library.Abs,
) -> @library.Abs {
  match e {
    Some(e) => attr(e)
    None => @library.Abs::zero()
  }
}

///|
/// Lays out a [`ScriptsItem`].
fn layout_scripts(
  item : @library.ScriptsItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let layout = (script : @library.MathItem?) => {
    match script {
      Some(script) => Some(ctx.layout_into_fragment(script, styles))
      None => None
    }
  }

  // Layout the top and bottom attachments early so we can measure their
  // widths, in order to calculate what the stretch size is relative to.
  let t = layout(item.top)
  let b = layout(item.bottom)
  let relative_to_width = measure(t, f => f.width()).max(
    measure(b, f => f.width()),
  )
  item.base.set_stretch_relative_to(relative_to_width, X)
  let base = ctx.layout_into_fragment(item.base, styles)
  let stretchy = base.is_stretchable(X)
  let fragments = [
    layout(item.top_left),
    t,
    layout(item.top_right),
    layout(item.bottom_left),
    b,
    layout(item.bottom_right),
  ]
  layout_attachments(
    ctx,
    props,
    item.base.styles().unwrap_or(styles),
    base,
    stretchy,
    fragments,
  )
}

///|
/// Lays out a [`PrimesItem`].
// Cannot fail; the item layouters share `SourceResult<()>`
// (typst-layout/src/math/scripts.rs:73).
#warnings("-unused_error_type")
fn layout_primes(
  item : @library.PrimesItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  guard GlyphFragment::synthetic(
      ctx.engine,
      styles,
      @library.prime_char,
      props.span,
    )
    is Some(prime) else {
    return
  }
  let prime = MathFragment::Glyph(prime).into_frame()
  let width = prime.width().times((item.count + 1).to_double()).div_by(2.0)
  let frame = @library.Frame::soft(@library.Axes::new(width, prime.height()))
  frame.set_baseline(prime.ascent())
  for i in 0..<item.count {
    frame.push_frame(
      @library.Point::new(
        prime.width().times(i.to_double() / 2.0),
        @library.Abs::zero(),
      ),
      prime.clone(),
    )
  }
  ctx.push(Frame(FrameFragment::new(props, styles, frame).with_text_like(true)))
}

///|
/// Lay out the attachments.
fn layout_attachments(
  ctx : MathContext,
  props : @library.MathProperties,
  styles : @library.StyleChain,
  base : MathFragment,
  stretchy : Bool,
  fragments : Array[MathFragment?],
) -> Unit {
  let tl = fragments[0]
  let t = fragments[1]
  let tr = fragments[2]
  let bl = fragments[3]
  let b = fragments[4]
  let br = fragments[5]
  let (font, size) = base.font(ctx, styles)
  let cramped = @library.EquationElem::cramped_in(styles)

  // Calculate the distance from the base's baseline to the superscripts' and
  // subscripts' baseline.
  let (tx_shift, bx_shift) = if [tl, tr, bl, br].iter().all(e => e is None) {
    (@library.Abs::zero(), @library.Abs::zero())
  } else {
    compute_script_shifts(font, size, cramped, base, tl, tr, bl, br)
  }

  // Calculate the distance from the base's baseline to the top attachment's
  // and bottom attachment's baseline.
  let (t_shift, b_shift) = compute_limit_shifts(
    font, size, base, stretchy, t, b,
  )

  // Calculate the final frame height.
  let ascent = base
    .ascent()
    .max(tx_shift + measure(tr, f => f.ascent()))
    .max(tx_shift + measure(tl, f => f.ascent()))
    .max(t_shift + measure(t, f => f.ascent()))
  let descent = base
    .descent()
    .max(bx_shift + measure(br, f => f.descent()))
    .max(bx_shift + measure(bl, f => f.descent()))
    .max(b_shift + measure(b, f => f.descent()))
  let height = ascent + descent

  // Calculate the vertical position of each element in the final frame.
  let base_y = ascent - base.ascent()
  let tx_y = (tx : MathFragment) => ascent - tx_shift - tx.ascent()
  let bx_y = (bx : MathFragment) => ascent + bx_shift - bx.ascent()
  let t_y = (t : MathFragment) => ascent - t_shift - t.ascent()
  let b_y = (b : MathFragment) => ascent + b_shift - b.ascent()

  // Calculate the distance each limit extends to the left and right of the
  // base's width.
  let ((t_pre_width, t_post_width), (b_pre_width, b_post_width)) = compute_limit_widths(
    base, t, b,
  )

  // `space_after_script` is extra spacing that is at the start before each
  // pre-script, and at the end after each post-script (see the MathConstants
  // table in the OpenType MATH spec).
  let space_after_script = font.math().space_after_script.at(size)

  // Calculate the distance each pre-script extends to the left of the base's
  // width.
  let (tl_pre_width, bl_pre_width) = compute_pre_script_widths(
    base, tl, bl, tx_shift, bx_shift, space_after_script,
  )

  // Calculate the distance each post-script extends to the right of the
  // base's width. Also calculate each post-script's kerning (we need this for
  // its position later).
  let ((tr_post_width, tr_kern), (br_post_width, br_kern)) = compute_post_script_widths(
    base, tr, br, tx_shift, bx_shift, space_after_script,
  )

  // Calculate the final frame width.
  let pre_width = t_pre_width
    .max(b_pre_width)
    .max(tl_pre_width)
    .max(bl_pre_width)
  let base_width = base.width()
  let post_width = t_post_width
    .max(b_post_width)
    .max(tr_post_width)
    .max(br_post_width)
  let width = pre_width + base_width + post_width

  // Calculate the horizontal position of each element in the final frame.
  let base_x = pre_width
  let tl_x = pre_width - tl_pre_width + space_after_script
  let bl_x = pre_width - bl_pre_width + space_after_script
  let tr_x = pre_width + base_width + tr_kern
  let br_x = pre_width + base_width + br_kern
  let t_x = pre_width - t_pre_width
  let b_x = pre_width - b_pre_width

  // Create the final frame.
  let frame = @library.Frame::soft(@library.Axes::new(width, height))
  frame.set_baseline(ascent)
  frame.push_frame(@library.Point::new(base_x, base_y), base.into_frame())
  let layout = (
    e : MathFragment?,
    x : @library.Abs,
    y : (MathFragment) -> @library.Abs,
  ) => {
    if e is Some(e) {
      frame.push_frame(@library.Point::new(x, y(e)), e.into_frame())
    }
  }
  layout(tl, tl_x, tx_y) // pre-superscript
  layout(bl, bl_x, bx_y) // pre-subscript
  layout(tr, tr_x, tx_y) // post-superscript
  layout(br, br_x, bx_y) // post-subscript
  layout(t, t_x, t_y) // upper-limit
  layout(b, b_x, b_y) // lower-limit

  // Done!
  ctx.push(Frame(FrameFragment::new(props, styles, frame)))
}

///|
/// `Option::map_or_default` for a pair of lengths.
fn pair_or_zero(
  x : (@library.Abs, @library.Abs)?,
) -> (@library.Abs, @library.Abs) {
  x.unwrap_or((@library.Abs::zero(), @library.Abs::zero()))
}

///|
/// Calculate the distance each post-script extends to the right of the base's
/// width, as well as its kerning value. Requires the distance from the base's
/// baseline to each post-script's baseline to obtain the correct kerning value.
/// Returns 2 tuples of two lengths, each first containing the distance the
/// post-script extends left of the base's width and second containing the
/// post-script's kerning value. The first tuple is for the post-superscript,
/// and the second is for the post-subscript.
fn compute_post_script_widths(
  base : MathFragment,
  tr : MathFragment?,
  br : MathFragment?,
  tr_shift : @library.Abs,
  br_shift : @library.Abs,
  space_after_post_script : @library.Abs,
) -> ((@library.Abs, @library.Abs), (@library.Abs, @library.Abs)) {
  let tr_values = pair_or_zero(
    tr.map(tr => {
      let kern = math_kern(base, tr, tr_shift, TopRight)
      (space_after_post_script + tr.width() + kern, kern)
    }),
  )

  // The base's bounding box already accounts for its italic correction, so we
  // need to shift the post-subscript left by the base's italic correction
  // (see the kerning algorithm as described in the OpenType MATH spec).
  let br_values = pair_or_zero(
    br.map(br => {
      let kern = math_kern(base, br, br_shift, BottomRight) -
        base.italics_correction()
      (space_after_post_script + br.width() + kern, kern)
    }),
  )
  (tr_values, br_values)
}

///|
/// Calculate the distance each pre-script extends to the left of the base's
/// width. Requires the distance from the base's baseline to each pre-script's
/// baseline to obtain the correct kerning value.
/// Returns two lengths, the first being the distance the pre-superscript
/// extends left of the base's width and the second being the distance the
/// pre-subscript extends left of the base's width.
fn compute_pre_script_widths(
  base : MathFragment,
  tl : MathFragment?,
  bl : MathFragment?,
  tl_shift : @library.Abs,
  bl_shift : @library.Abs,
  space_before_pre_script : @library.Abs,
) -> (@library.Abs, @library.Abs) {
  let tl_pre_width = match tl {
    Some(tl) => {
      let kern = math_kern(base, tl, tl_shift, TopLeft)
      space_before_pre_script + tl.width() + kern
    }
    None => @library.Abs::zero()
  }
  let bl_pre_width = match bl {
    Some(bl) => {
      let kern = math_kern(base, bl, bl_shift, BottomLeft)
      space_before_pre_script + bl.width() + kern
    }
    None => @library.Abs::zero()
  }
  (tl_pre_width, bl_pre_width)
}

///|
/// Calculate the distance each limit extends beyond the base's width, in each
/// direction. Can be a negative value if the limit does not extend beyond the
/// base's width, indicating how far into the base's width the limit extends.
/// Returns 2 tuples of two lengths, each first containing the distance the
/// limit extends leftward beyond the base's width and second containing the
/// distance the limit extends rightward beyond the base's width. The first
/// tuple is for the upper-limit, and the second is for the lower-limit.
fn compute_limit_widths(
  base : MathFragment,
  t : MathFragment?,
  b : MathFragment?,
) -> ((@library.Abs, @library.Abs), (@library.Abs, @library.Abs)) {
  // The upper- (lower-) limit is shifted to the right (left) of the base's
  // center by half the base's italic correction.
  let delta = base.italics_correction().div_by(2.0)
  let t_widths = pair_or_zero(
    t.map(t => {
      let half = (t.width() - base.width()).div_by(2.0)
      (half - delta, half + delta)
    }),
  )
  let b_widths = pair_or_zero(
    b.map(b => {
      let half = (b.width() - base.width()).div_by(2.0)
      (half + delta, half - delta)
    }),
  )
  (t_widths, b_widths)
}

///|
/// Calculate the distance from the base's baseline to each limit's baseline.
/// Returns two lengths, the first being the distance to the upper-limit's
/// baseline and the second being the distance to the lower-limit's baseline.
fn compute_limit_shifts(
  font : @library.FontInstance,
  font_size : @library.Abs,
  base : MathFragment,
  stretchy : Bool,
  t : MathFragment?,
  b : MathFragment?,
) -> (@library.Abs, @library.Abs) {
  // `upper_gap_min` and `lower_gap_min` give gaps to the descender and
  // ascender of the limits respectively, whereas `upper_rise_min` and
  // `lower_drop_min` give gaps to each limit's baseline (see the
  // MathConstants table in the OpenType MATH spec).
  let math = font.math()
  let t_shift = match t {
    Some(t) =>
      if stretchy {
        let top_shift_up = math.stretch_stack_top_shift_up.at(font_size)
        let gap_above_min = math.stretch_stack_gap_above_min.at(font_size)
        let gap = (top_shift_up - base.ascent() - t.descent()).max(
          gap_above_min,
        )
        base.ascent() + gap + t.descent()
      } else {
        let upper_gap_min = math.upper_limit_gap_min.at(font_size)
        let upper_rise_min = math.upper_limit_baseline_rise_min.at(font_size)
        base.ascent() + upper_rise_min.max(upper_gap_min + t.descent())
      }
    None => @library.Abs::zero()
  }
  let b_shift = match b {
    Some(b) =>
      if stretchy {
        let bottom_shift_down = math.stretch_stack_bottom_shift_down.at(
          font_size,
        )
        let gap_below_min = math.stretch_stack_gap_below_min.at(font_size)
        let gap = (bottom_shift_down - base.descent() - b.ascent()).max(
          gap_below_min,
        )
        base.descent() + gap + b.ascent()
      } else {
        let lower_gap_min = math.lower_limit_gap_min.at(font_size)
        let lower_drop_min = math.lower_limit_baseline_drop_min.at(font_size)
        base.descent() + lower_drop_min.max(lower_gap_min + b.ascent())
      }
    None => @library.Abs::zero()
  }
  (t_shift, b_shift)
}

///|
/// Calculate the distance from the base's baseline to each script's baseline.
/// Returns two lengths, the first being the distance to the superscripts'
/// baseline and the second being the distance to the subscripts' baseline.
fn compute_script_shifts(
  font : @library.FontInstance,
  font_size : @library.Abs,
  cramped : Bool,
  base : MathFragment,
  tl : MathFragment?,
  tr : MathFragment?,
  bl : MathFragment?,
  br : MathFragment?,
) -> (@library.Abs, @library.Abs) {
  let math = font.math()
  let sup_shift_up = (if cramped {
    math.superscript_shift_up_cramped
  } else {
    math.superscript_shift_up
  }).at(font_size)
  let sup_bottom_min = math.superscript_bottom_min.at(font_size)
  let sup_bottom_max_with_sub = math.superscript_bottom_max_with_subscript.at(
    font_size,
  )
  let sup_drop_max = math.superscript_baseline_drop_max.at(font_size)
  let gap_min = math.sub_superscript_gap_min.at(font_size)
  let sub_shift_down = math.subscript_shift_down.at(font_size)
  let sub_top_max = math.subscript_top_max.at(font_size)
  let sub_drop_min = math.subscript_baseline_drop_min.at(font_size)
  let mut shift_up = @library.Abs::zero()
  let mut shift_down = @library.Abs::zero()
  let is_text_like = base.is_text_like()
  if tl is Some(_) || tr is Some(_) {
    let ascent = base.base_ascent()
    shift_up = shift_up
      .max(sup_shift_up)
      .max(
        if is_text_like {
          @library.Abs::zero()
        } else {
          ascent - sup_drop_max
        },
      )
      .max(sup_bottom_min + measure(tl, f => f.descent()))
      .max(sup_bottom_min + measure(tr, f => f.descent()))
  }
  if bl is Some(_) || br is Some(_) {
    let descent = base.base_descent()
    shift_down = shift_down
      .max(sub_shift_down)
      .max(
        if is_text_like {
          @library.Abs::zero()
        } else {
          descent + sub_drop_min
        },
      )
      .max(measure(bl, f => f.ascent()) - sub_top_max)
      .max(measure(br, f => f.ascent()) - sub_top_max)
  }
  for pair in [(tl, bl), (tr, br)] {
    if pair is (Some(sup), Some(sub)) {
      let sup_bottom = shift_up - sup.descent()
      let sub_top = sub.ascent() - shift_down
      let gap = sup_bottom - sub_top
      if gap >= gap_min {
        continue
      }
      let increase = gap_min - gap
      let sup_only = (sup_bottom_max_with_sub - sup_bottom).clamp(
        @library.Abs::zero(),
        increase,
      )
      let rest = (increase - sup_only).div_by(2.0)
      shift_up = shift_up + (sup_only + rest)
      shift_down = shift_down + rest
    }
  }
  (shift_up, shift_down)
}

///|
/// Calculate the kerning value for a script with respect to the base. A
/// positive value means shifting the script further away from the base, whereas
/// a negative value means shifting the script closer to the base. Requires the
/// distance from the base's baseline to the script's baseline, as well as the
/// script's corner (tl, tr, bl, br).
fn math_kern(
  base : MathFragment,
  script : MathFragment,
  shift : @library.Abs,
  pos : @library.Corner,
) -> @library.Abs {
  // This process is described under the MathKernInfo table in the OpenType
  // MATH spec.

  let (corr_height_top, corr_height_bot) = match pos {
    // Calculate two correction heights for superscripts:
    // - The distance from the superscript's baseline to the top of the
    //   base's bounding box.
    // - The distance from the base's baseline to the bottom of the
    //   superscript's bounding box.
    TopLeft | TopRight => (base.ascent() - shift, shift - script.descent())
    // Calculate two correction heights for subscripts:
    // - The distance from the base's baseline to the top of the
    //   subscript's bounding box.
    // - The distance from the subscript's baseline to the bottom of the
    //   base's bounding box.
    BottomLeft | BottomRight =>
      (script.ascent() - shift, shift - base.descent())
  }

  // Calculate the sum of kerning values for each correction height.
  let summed_kern = (height : @library.Abs) => {
    let base_kern = base.kern_at_height(pos, height)
    let attach_kern = script.kern_at_height(pos.inv(), height)
    base_kern + attach_kern
  }

  // Take the smaller kerning amount (and so the larger value). Note that
  // there is a bug in the spec (as of 2024-08-15): it says to take the
  // minimum of the two sums, but as the kerning value is usually negative it
  // really means the smaller kern. The current wording of the spec could
  // result in glyphs colliding.
  summed_kern(corr_height_top).max(summed_kern(corr_height_bot))
}
