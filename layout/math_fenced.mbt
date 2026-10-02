// Port of `typst-layout/src/math/fenced.rs`.

///|
/// Lays out a [`FencedItem`].
fn layout_fenced(
  item : @library.FencedItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  _props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let body_item = item.body.item()

  // Compute relative_to for delimiter sizing.
  let (relative_to, initial_body) = match item.body.sizing() {
    Some(sizing) => {
      let relative_to = sizing.try_get_or_update((items, styles) => {
        relative_to_from_sizing(items, ctx, styles, item.balanced)
      })
      (relative_to, None)
    }
    None => {
      let body = ctx.layout_into_fragments(body_item, styles)
      let body_styles = body_item.styles().unwrap_or(styles)
      let relative_to = relative_to_from_fragments(
        body,
        ctx,
        body_styles,
        item.balanced,
      )
      (relative_to, Some(body))
    }
  }

  // Set stretch info for stretched mid items.
  let mut has_mid_stretched = false
  for body_item in body_item.as_slice() {
    if body_item.mid_stretched() is Some(true) {
      has_mid_stretched = true
      body_item.set_stretch_relative_to(relative_to, Y)
    }
  }

  // Layout the opening delimiter if present.
  if item.open is Some(open) {
    open.set_stretch_relative_to(relative_to, Y)
    let open = ctx.layout_into_fragment(open, styles)
    ctx.push(open)
  }

  // Check if the body needs re-layout, since stretch info was updated or we
  // deferred initial layout.
  let body = if !has_mid_stretched && initial_body is Some(body) {
    body
  } else {
    ctx.layout_into_fragments(body_item, styles)
  }
  ctx.extend_with(body)

  // Layout the closing delimiter if present.
  if item.close is Some(close) {
    close.set_stretch_relative_to(relative_to, Y)
    let close = ctx.layout_into_fragment(close, styles)
    ctx.push(close)
  }
}

///|
fn relative_to_from_sizing(
  items : ArrayView[@library.MathItem],
  ctx : MathContext,
  styles : @library.StyleChain,
  balanced : Bool,
) -> @library.Abs raise @library.SourceError {
  let mut max_abs = @library.Abs::zero()
  for item in items {
    let fragments = ctx.layout_into_fragments(item, styles)
    let item_styles = item.styles().unwrap_or(styles)
    max_abs = max_abs.max(
      relative_to_from_fragments(fragments, ctx, item_styles, balanced),
    )
  }
  max_abs
}

///|
fn relative_to_from_fragments(
  fragments : Array[MathFragment],
  ctx : MathContext,
  styles : @library.StyleChain,
  balanced : Bool,
) -> @library.Abs {
  let mut max : @library.Abs? = None
  for f in fragments {
    let h = if balanced {
      let (font, size) = f.font(ctx, styles)
      let axis = font.math().axis_height.at(size)
      (f.ascent() - axis).max(f.descent() + axis).times(2.0)
    } else {
      f.height()
    }
    max = match max {
      None => Some(h)
      Some(m) => Some(m.max(h))
    }
  }
  max.unwrap_or(@library.Abs::zero())
}
