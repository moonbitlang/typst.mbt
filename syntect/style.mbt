// Port of `syntect/src/highlighting/style.rs`.

///|
/// Foreground and background colors, with font style
pub(all) struct Style {
  /// Foreground color
  foreground : Color
  /// Background color
  background : Color
  /// Style of the font
  font_style : FontStyle
} derive(Eq, Hash)

///|
/// A change to a [`Style`] applied incrementally by a theme rule
///
/// Fields left empty (as `None`) will not modify the corresponding field on a
/// `Style`
pub(all) struct StyleModifier {
  /// Foreground color
  foreground : Color?
  /// Background color
  background : Color?
  /// Style of the font
  font_style : FontStyle?
} derive(Eq, Default)

///|
/// RGBA color, directly from the theme
///
/// Because these numbers come directly from the theme, you might have to do
/// your own color space conversion if you're outputting a different color
/// space from the theme. This can be a problem because some Sublime themes
/// use sRGB and some don't. This is specified in an attribute syntect doesn't
/// parse yet.
pub(all) struct Color {
  /// Red component
  r : Byte
  /// Green component
  g : Byte
  /// Blue component
  b : Byte
  /// Alpha (transparency) component
  a : Byte
} derive(Eq, Hash, Default)

///|
/// The color-independent styling of a font - i.e. bold, italicized, and/or
/// underlined
pub(all) struct FontStyle {
  bits : Byte
} derive(Eq, Compare, Hash, Default)

///|
/// Bold font style
pub let font_style_bold : FontStyle = { bits: 1 }

///|
/// Underline font style
pub let font_style_underline : FontStyle = { bits: 2 }

///|
/// Italic font style
pub let font_style_italic : FontStyle = { bits: 4 }

///|
/// Returns an empty set of flags.
pub fn FontStyle::empty() -> FontStyle {
  { bits: 0 }
}

///|
/// Returns the set containing all flags.
pub fn FontStyle::all() -> FontStyle {
  { bits: 7 }
}

///|
/// Returns the raw value of the flags currently stored.
pub fn FontStyle::bits(self : FontStyle) -> Byte {
  self.bits
}

///|
/// Returns `true` if no flags are currently stored.
pub fn FontStyle::is_empty(self : FontStyle) -> Bool {
  self.bits == 0
}

///|
/// Returns `true` if all flags in `other` are contained within `self`.
pub fn FontStyle::contains(self : FontStyle, other : FontStyle) -> Bool {
  (self.bits & other.bits) == other.bits
}

///|
/// Returns the union of between the flags in `self` and `other`.
pub fn FontStyle::union(self : FontStyle, other : FontStyle) -> FontStyle {
  { bits: self.bits | other.bits }
}

///|
pub impl BitOr for FontStyle with fn lor(self, other) {
  self.union(other)
}

///|
/// Upstream's `Debug` (`BOLD | ITALIC`, `(empty)`).
pub impl Show for FontStyle with fn output(self, logger) {
  let mut empty = true
  let pairs = [
    (font_style_bold, "BOLD"),
    (font_style_underline, "UNDERLINE"),
    (font_style_italic, "ITALIC"),
  ]
  for pair in pairs {
    let (flag, flag_str) = pair
    if self.contains(flag) {
      if !empty {
        logger.write_string(" | ")
      }
      empty = false
      logger.write_string(flag_str)
    }
  }
  let extra_bits = self.bits & 0xF8
  if extra_bits != 0 {
    if !empty {
      logger.write_string(" | ")
    }
    empty = false
    logger.write_string("0x")
    logger.write_string(extra_bits.to_int().to_string(radix=16))
  }
  if empty {
    logger.write_string("(empty)")
  }
}

///|
/// Black color (`#000000`)
pub let color_black : Color = { r: 0x00, g: 0x00, b: 0x00, a: 0xFF }

///|
/// White color (`#FFFFFF`)
pub let color_white : Color = { r: 0xFF, g: 0xFF, b: 0xFF, a: 0xFF }

///|
/// Upstream's `Debug` (`Color { r/g/b/a: 0/0/0/255 }`).
pub impl Show for Color with fn output(self, logger) {
  logger.write_string(
    "Color { r/g/b/a: \{self.r.to_int()}/\{self.g.to_int()}/\{self.b.to_int()}/\{self.a.to_int()} }",
  )
}

///|
/// Applies the other modifier to this style to make a new style
pub fn Style::apply(self : Style, modifier : StyleModifier) -> Style {
  {
    foreground: modifier.foreground.unwrap_or(self.foreground),
    background: modifier.background.unwrap_or(self.background),
    font_style: modifier.font_style.unwrap_or(self.font_style),
  }
}

///|
/// Applies the other modifier to this one, creating a new modifier.
///
/// Values in `other` are preferred.
pub fn StyleModifier::apply(
  self : StyleModifier,
  other : StyleModifier,
) -> StyleModifier {
  {
    foreground: if other.foreground is Some(_) { other.foreground } else { self.foreground },
    background: if other.background is Some(_) { other.background } else { self.background },
    font_style: if other.font_style is Some(_) { other.font_style } else { self.font_style },
  }
}

///|
/// Upstream's `Default for Style`.
pub fn Style::default_style() -> Style {
  { foreground: color_black, background: color_white, font_style: FontStyle::empty() }
}
