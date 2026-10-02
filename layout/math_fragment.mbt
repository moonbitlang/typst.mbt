// Port of `typst-layout/src/math/fragment/mod.rs`.

///|
priv enum MathFragment {
  Glyph(GlyphFragment)
  Frame(FrameFragment)
  Space(@library.Abs)
  Tag(@library.Tag)
}

///|
fn MathFragment::size(self : MathFragment) -> @library.Axes[@library.Abs] {
  match self {
    Glyph(glyph) => glyph.size
    Frame(fragment) => fragment.frame.size()
    Space(amount) => @library.Axes::new(amount, @library.Abs::zero())
    Tag(_) => @library.Axes::zero_size()
  }
}

///|
fn MathFragment::width(self : MathFragment) -> @library.Abs {
  match self {
    Glyph(glyph) => glyph.size.x
    Frame(fragment) => fragment.frame.width()
    Space(amount) => amount
    Tag(_) => @library.Abs::zero()
  }
}

///|
fn MathFragment::height(self : MathFragment) -> @library.Abs {
  match self {
    Glyph(glyph) => glyph.size.y
    Frame(fragment) => fragment.frame.height()
    _ => @library.Abs::zero()
  }
}

///|
fn MathFragment::ascent(self : MathFragment) -> @library.Abs {
  match self {
    Glyph(glyph) => glyph.ascent()
    Frame(fragment) => fragment.frame.ascent()
    _ => @library.Abs::zero()
  }
}

///|
fn MathFragment::descent(self : MathFragment) -> @library.Abs {
  match self {
    Glyph(glyph) => glyph.descent()
    Frame(fragment) => fragment.frame.descent()
    _ => @library.Abs::zero()
  }
}

///|
fn MathFragment::stroke(self : MathFragment) -> @library.FixedStroke? {
  match self {
    Glyph(glyph) => glyph.item.stroke
    _ => None
  }
}

///|
fn MathFragment::base_ascent(self : MathFragment) -> @library.Abs {
  match self {
    Frame(fragment) => fragment.base_ascent
    _ => self.ascent()
  }
}

///|
fn MathFragment::base_descent(self : MathFragment) -> @library.Abs {
  match self {
    Frame(fragment) => fragment.base_descent
    _ => self.descent()
  }
}

///|
fn MathFragment::class(self : MathFragment) -> @unicode.MathClass {
  match self {
    Glyph(glyph) => glyph.class
    Frame(fragment) => fragment.class
    Space(_) => Space
    Tag(_) => Special
  }
}

///|
fn MathFragment::math_size(self : MathFragment) -> @library.MathSize? {
  match self {
    Glyph(glyph) => Some(glyph.math_size)
    Frame(fragment) => Some(fragment.math_size)
    _ => None
  }
}

///|
fn MathFragment::font(
  self : MathFragment,
  ctx : MathContext,
  styles : @library.StyleChain,
) -> (@library.FontInstance, @library.Abs) {
  (
    match self {
      Glyph(glyph) => glyph.item.font
      _ => ctx.font()
    },
    match self.font_size() {
      Some(size) => size
      None => @library.TextElem::size_in(styles).resolve(styles)
    },
  )
}

///|
fn MathFragment::font_size(self : MathFragment) -> @library.Abs? {
  match self {
    Glyph(glyph) => Some(glyph.item.size)
    Frame(fragment) => Some(fragment.font_size)
    _ => None
  }
}

///|
fn MathFragment::is_stretchable(
  self : MathFragment,
  axis : @library.Axis,
) -> Bool {
  match self {
    Glyph(glyph) => glyph.stretchable_axes.get(axis)
    _ => false
  }
}

///|
fn MathFragment::is_text_like(self : MathFragment) -> Bool {
  match self {
    Glyph(glyph) => !glyph.extended_shape
    Frame(frame) => frame.text_like
    _ => false
  }
}

///|
fn MathFragment::italics_correction(self : MathFragment) -> @library.Abs {
  match self {
    Glyph(glyph) => glyph.italics_correction
    Frame(fragment) => fragment.italics_correction
    _ => @library.Abs::zero()
  }
}

///|
fn MathFragment::accent_attach(
  self : MathFragment,
) -> (@library.Abs, @library.Abs) {
  match self {
    Glyph(glyph) => glyph.accent_attach
    Frame(fragment) => fragment.accent_attach
    _ => (self.width().div_by(2.0), self.width().div_by(2.0))
  }
}

///|
fn MathFragment::into_frame(self : MathFragment) -> @library.Frame {
  match self {
    Glyph(glyph) => glyph.into_frame()
    Frame(fragment) => fragment.frame
    Tag(tag) => {
      let frame = @library.Frame::soft(@library.Axes::zero_size())
      frame.push(@library.Point::zero(), Tag(tag))
      frame
    }
    Space(_) => @library.Frame::soft(self.size())
  }
}

///|
fn MathFragment::fill(self : MathFragment) -> @library.Paint? {
  match self {
    Glyph(glyph) => Some(glyph.item.fill)
    _ => None
  }
}

///|
/// If no kern table is provided for a corner, a kerning amount of zero is
/// assumed.
fn MathFragment::kern_at_height(
  self : MathFragment,
  corner : @library.Corner,
  height : @library.Abs,
) -> @library.Abs {
  match self {
    Glyph(glyph) => {
      // For glyph assemblies we pick either the start or end glyph
      // depending on the corner.
      let glyphs = glyph.item.glyphs
      let is_vertical = glyphs
        .iter()
        .all(g => g.y_advance != @library.Em::zero())
      let glyph_index = match (is_vertical, corner) {
        (true, TopLeft | TopRight) => glyphs.length() - 1
        (false, TopRight | BottomRight) => glyphs.length() - 1
        _ => 0
      }
      kern_at_height(
        glyph.item.font,
        glyphs[glyph_index].id,
        corner,
        @library.Em::from_abs(height, glyph.item.size),
      )
      .unwrap_or(@library.Em::zero())
      .at(glyph.item.size)
    }
    _ => @library.Abs::zero()
  }
}

///|
priv struct FrameFragment {
  frame : @library.Frame
  font_size : @library.Abs
  class : @unicode.MathClass
  math_size : @library.MathSize
  base_ascent : @library.Abs
  base_descent : @library.Abs
  italics_correction : @library.Abs
  accent_attach : (@library.Abs, @library.Abs)
  text_like : Bool
}

///|
fn FrameFragment::new(
  props : @library.MathProperties,
  styles : @library.StyleChain,
  frame : @library.Frame,
) -> FrameFragment {
  let base_ascent = frame.ascent()
  let base_descent = frame.descent()
  let accent_attach = frame.width().div_by(2.0)
  let modifiers = FrameModifiers::get_in(styles)
  {
    frame: modified(frame, modifiers),
    font_size: @library.TextElem::size_in(styles).resolve(styles),
    class: props.class(),
    math_size: props.size,
    base_ascent,
    base_descent,
    italics_correction: @library.Abs::zero(),
    accent_attach: (accent_attach, accent_attach),
    text_like: false,
  }
}

///|
fn FrameFragment::with_base_ascent(
  self : FrameFragment,
  base_ascent : @library.Abs,
) -> FrameFragment {
  { ..self, base_ascent, }
}

///|
fn FrameFragment::with_base_descent(
  self : FrameFragment,
  base_descent : @library.Abs,
) -> FrameFragment {
  { ..self, base_descent, }
}

///|
fn FrameFragment::with_italics_correction(
  self : FrameFragment,
  italics_correction : @library.Abs,
) -> FrameFragment {
  { ..self, italics_correction, }
}

///|
fn FrameFragment::with_accent_attach(
  self : FrameFragment,
  accent_attach : (@library.Abs, @library.Abs),
) -> FrameFragment {
  { ..self, accent_attach, }
}

///|
fn FrameFragment::with_text_like(
  self : FrameFragment,
  text_like : Bool,
) -> FrameFragment {
  { ..self, text_like, }
}
