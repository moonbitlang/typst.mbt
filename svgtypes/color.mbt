// Port of `svgtypes` 0.16.1 `src/color.rs`.

///|
/// Representation of the [`<color>`] type.
///
/// [`<color>`]: https://www.w3.org/TR/css-color-3/
pub(all) struct Color {
  red : Byte
  green : Byte
  blue : Byte
  alpha : Byte
} derive(Eq, Debug, Hash)

///|
/// Constructs a new `Color` from RGB values.
pub fn Color::new_rgb(red : Byte, green : Byte, blue : Byte) -> Color {
  { red, green, blue, alpha: 255, }
}

///|
/// Constructs a new `Color` from RGBA values.
pub fn Color::new_rgba(
  red : Byte,
  green : Byte,
  blue : Byte,
  alpha : Byte,
) -> Color {
  { red, green, blue, alpha, }
}

///|
/// Constructs a new `Color` set to black.
pub fn Color::black() -> Color {
  Color::new_rgb(0, 0, 0)
}

///|
/// Constructs a new `Color` set to white.
pub fn Color::white() -> Color {
  Color::new_rgb(255, 255, 255)
}

///|
/// Constructs a new `Color` set to gray.
pub fn Color::gray() -> Color {
  Color::new_rgb(128, 128, 128)
}

///|
/// Constructs a new `Color` set to red.
pub fn Color::red() -> Color {
  Color::new_rgb(255, 0, 0)
}

///|
/// Constructs a new `Color` set to green.
pub fn Color::green() -> Color {
  Color::new_rgb(0, 128, 0)
}

///|
/// Constructs a new `Color` set to blue.
pub fn Color::blue() -> Color {
  Color::new_rgb(0, 0, 255)
}

///|
/// Parses [CSS3](https://www.w3.org/TR/css-color-3/) `Color` from a string.
///
/// # Errors
///
///  - Returns error if a color has an invalid format.
///  - Returns error if `<color>` is followed by `<icccolor>`. It's not supported.
///
/// # Notes
///
///  - Any non-`hexdigit` bytes will be treated as `0`.
///  - The [SVG 1.1 spec] has an error.
///    There should be a `number`, not an `integer` for percent values ([details]).
///  - It also supports 4 digits and 8 digits hex notation from the
///    [CSS Color Module Level 4][css-color-4-hex].
pub fn Color::from_str(text : String) -> Color raise SvgTypesError {
  let s = Stream::from(text)
  let color = s.parse_color()

  // Check that we are at the end of the stream. Otherwise color can be followed by icccolor,
  // which is not supported.
  s.skip_spaces()
  if !s.at_end() {
    raise UnexpectedData(s.calc_char_pos())
  }
  color
}

///|
/// Tries to parse a color, but doesn't advance on error.
pub fn Stream::try_parse_color(self : Stream) -> Color? {
  let s = self.clone()
  let color = s.parse_color() catch { _ => return None }
  self.pos = s.pos
  Some(color)
}

///|
/// Parses a color.
pub fn Stream::parse_color(self : Stream) -> Color raise SvgTypesError {
  self.skip_spaces()
  let mut color = Color::black()
  if self.curr_byte() == b'#' {
    // See https://www.w3.org/TR/css-color-4/#hex-notation
    self.advance(1)
    let start = self.pos
    self.skip_bytes((_, c) => is_hex_digit(c))
    let color_str = self.bytes[start:self.pos]
    // get color data len until first space or stream end
    match color_str.length() {
      6 =>
        // #rrggbb
        color = {
          ..color,
          red: hex_pair(color_str[0], color_str[1]),
          green: hex_pair(color_str[2], color_str[3]),
          blue: hex_pair(color_str[4], color_str[5]),
        }
      8 =>
        // #rrggbbaa
        color = {
          red: hex_pair(color_str[0], color_str[1]),
          green: hex_pair(color_str[2], color_str[3]),
          blue: hex_pair(color_str[4], color_str[5]),
          alpha: hex_pair(color_str[6], color_str[7]),
        }
      3 =>
        // #rgb
        color = {
          ..color,
          red: short_hex(color_str[0]),
          green: short_hex(color_str[1]),
          blue: short_hex(color_str[2]),
        }
      4 =>
        // #rgba
        color = {
          red: short_hex(color_str[0]),
          green: short_hex(color_str[1]),
          blue: short_hex(color_str[2]),
          alpha: short_hex(color_str[3]),
        }
      _ => raise InvalidValue
    }
  } else {
    // TODO: remove allocation
    let name = self.consume_ascii_ident().to_lower()
    if name == "rgb" || name == "rgba" {
      self.consume_byte(b'(')
      let mut is_percent = false
      let value = self.parse_number()
      if self.starts_with(b"%") {
        self.advance(1)
        is_percent = true
      }
      self.skip_spaces()
      self.parse_list_separator()
      if is_percent {
        // The division and multiply are explicitly not collapsed, to ensure the red
        // component has the same rounding behavior as the green and blue components.
        let red = f64_as_u8(f64_round(value / 100.0 * 255.0))
        let green = f64_as_u8(
          f64_round(self.parse_list_number_or_percent() * 255.0),
        )
        let blue = f64_as_u8(
          f64_round(self.parse_list_number_or_percent() * 255.0),
        )
        color = { ..color, red, green, blue, }
      } else {
        let red = f64_as_u8(f64_round(value))
        let green = f64_as_u8(f64_round(self.parse_list_number()))
        let blue = f64_as_u8(f64_round(self.parse_list_number()))
        color = { ..color, red, green, blue, }
      }
      self.skip_spaces()
      if !self.starts_with(b")") {
        color = {
          ..color,
          alpha: f64_as_u8(f64_round(self.parse_list_number() * 255.0)),
        }
      }
      self.skip_spaces()
      self.consume_byte(b')')
    } else if name == "hsl" || name == "hsla" {
      self.consume_byte(b'(')
      let mut hue = self.parse_list_number()
      hue = (hue % 360.0 + 360.0) % 360.0
      let saturation = f64_bound(0.0, self.parse_list_number_or_percent(), 1.0)
      let lightness = f64_bound(0.0, self.parse_list_number_or_percent(), 1.0)
      color = hsl_to_rgb(
        Float::from_double(hue) / 60.0,
        Float::from_double(saturation),
        Float::from_double(lightness),
      )
      self.skip_spaces()
      if !self.starts_with(b")") {
        color = {
          ..color,
          alpha: f64_as_u8(f64_round(self.parse_list_number() * 255.0)),
        }
      }
      self.skip_spaces()
      self.consume_byte(b')')
    } else {
      match colors_from_str(name) {
        Some(c) => color = c
        None => raise InvalidValue
      }
    }
  }
  color
}

///|
fn from_hex(c : Byte) -> Byte {
  match c {
    b'0'..=b'9' => c - b'0'
    b'a'..=b'f' => c - b'a' + 10
    b'A'..=b'F' => c - b'A' + 10
    _ => b'0'
  }
}

///|
fn short_hex(c : Byte) -> Byte {
  let h = from_hex(c)
  (h << 4) | h
}

///|
fn hex_pair(c1 : Byte, c2 : Byte) -> Byte {
  let h1 = from_hex(c1)
  let h2 = from_hex(c2)
  (h1 << 4) | h2
}

///|
/// `hue` is in a 0..6 range, while `saturation` and `lightness` are in a 0..=1 range.
/// Based on https://www.w3.org/TR/css-color-3/#hsl-color
fn hsl_to_rgb(hue : Float, saturation : Float, lightness : Float) -> Color {
  let t2 = if lightness <= 0.5 {
    lightness * (saturation + 1.0)
  } else {
    lightness + saturation - lightness * saturation
  }
  let t1 = lightness * 2.0 - t2
  let red = hue_to_rgb(t1, t2, hue + 2.0)
  let green = hue_to_rgb(t1, t2, hue)
  let blue = hue_to_rgb(t1, t2, hue - 2.0)
  Color::new_rgb(
    f32_as_u8(f32_round(red * 255.0)),
    f32_as_u8(f32_round(green * 255.0)),
    f32_as_u8(f32_round(blue * 255.0)),
  )
}

///|
fn hue_to_rgb(t1 : Float, t2 : Float, hue : Float) -> Float {
  let mut hue = hue
  if hue < 0.0 {
    hue += 6.0
  }
  if hue >= 6.0 {
    hue -= 6.0
  }
  if hue < 1.0 {
    (t2 - t1) * hue + t1
  } else if hue < 3.0 {
    t2
  } else if hue < 4.0 {
    (t2 - t1) * (4.0 - hue) + t1
  } else {
    t1
  }
}

///|
fn f64_bound(min : Double, val : Double, max : Double) -> Double {
  f64_clamp(val, min, max)
}
