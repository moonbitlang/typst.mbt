// Port of `typst-layout/src/math/text.rs`.

///|
/// Lays out a [`MathTextItem`].
fn layout_math_text(
  item : @library.MathTextItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let text = item.text
  let span = props.span
  let elem = @library.TextElem::packed(text).spanned(span)

  // There isn't a natural width for a paragraph in a math environment;
  // because it will be placed somewhere probably not at the left margin
  // it will overflow. So emulate an `hbox` instead and allow the
  // paragraph to extend as far as needed.
  let frame = layout_inline(
    ctx.engine,
    [(elem, styles)][:],
    item.locator.relayout().split(),
    styles,
    @library.Axes::splat(@library.Abs::inf()),
    false,
  ).into_frame()
  ctx.push(Frame(FrameFragment::new(props, styles, frame).with_text_like(true)))
}

///|
/// Lays out a [`NumberItem`].
// Cannot fail; the item layouters share `SourceResult<()>`
// (typst-layout/src/math/text.rs:46).
#warnings("-unused_error_type")
fn layout_math_number(
  item : @library.NumberItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let text = item.text
  let span = props.span
  // Small optimization for numbers. Note that this lays out slightly
  // differently to normal text and is worth re-evaluating in the future.
  let fragments : Array[MathFragment] = []
  for c in text {
    if GlyphFragment::synthetic(ctx.engine, styles, c, span) is Some(glyph) {
      fragments.push(Glyph(glyph))
    }
  }
  let frame = math_run_into_frame(fragments)
  ctx.push(Frame(FrameFragment::new(props, styles, frame).with_text_like(true)))
}

///|
/// Layout a single character in the math font.
// Cannot fail; the item layouters share `SourceResult<()>`
// (typst-layout/src/math/text.rs:69).
#warnings("-unused_error_type")
fn layout_math_glyph(
  item : @library.GlyphItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let styles = if item.flac {
    styles.chain_one(@library.style_flac())
  } else {
    styles
  }
  let (styles, text) = if item.text.iter().any(c => try_dotless(c) is Some(_)) &&
    has_dtls_feat(ctx.font()) {
    let variant = @library.EquationElem::variant_in(styles)
    let bold = @library.EquationElem::bold_in(styles)
    let italic = @library.EquationElem::italic_in(styles)
    let text = StringBuilder()
    for c in item.text {
      let c = match try_dotless(c) {
        Some(d) => d
        None => c
      }
      text.write_string(
        @library.to_style(
          c,
          @library.MathStyle::select(c, variant, bold, italic),
        ),
      )
    }
    (styles.chain_one(@library.style_dtls()), text.to_string())
  } else {
    (styles, item.text)
  }
  if GlyphFragment::new(
      ctx.engine,
      text,
      item.stretch,
      styles,
      props,
      item.class,
    )
    is Some(glyph) {
    if glyph.class == Large {
      // TeXbook p 155. Large operators are always vertically centered on
      // the axis.
      glyph.center_on_axis()
    }
    glyph.class = props.class()
    ctx.push(Glyph(glyph))
  }
}

///|
/// Whether the given font has the dtls OpenType feature.
fn has_dtls_feat(font : @library.FontInstance) -> Bool {
  guard font.ttf() is Some(ttf) else { return false }
  guard ttf.tables().gsub is Some(gsub) else { return false }
  gsub.features.index(@otf.Tag::from_str("dtls")) is Some(_)
}

///|
/// The non-dotless version of a dotless character that can be used with the
/// `dtls` OpenType feature.
fn try_dotless(c : Char) -> Char? {
  match c {
    'ı' | '𝚤' => Some('i')
    'ȷ' | '𝚥' => Some('j')
    _ => None
  }
}
