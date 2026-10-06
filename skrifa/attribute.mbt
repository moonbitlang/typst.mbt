// Port of skrifa 0.42.1 `src/attribute.rs`.

///|
/// Stretch, style and weight attributes of a font.
pub(all) struct Attributes {
  stretch : Stretch
  style : Style
  weight : Weight
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Attributes with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Attributes with @debug.Debug::{to_repr}

///|
/// Extracts the stretch, style and weight attributes for the specified font.
pub fn Attributes::new(font : FontRef) -> Attributes {
  if ok(() => font.os2()) is Some(os2) {
    // Prefer values from the OS/2 table if it exists. We also use
    // the post table to extract the angle for oblique styles.
    let post = match res(() => font.post()) {
      Ok(p) => Some(p)
      Err(_) => None
    }
    Attributes::from_os2_post(os2, post)
  } else if ok(() => font.head()) is Some(head) {
    // Otherwise, fall back to the macStyle field of the head table.
    Attributes::from_head(head)
  } else {
    { stretch: Stretch::normal(), style: Normal, weight: Weight::normal(), }
  }
}

///|
fn Attributes::from_os2_post(
  os2 : @read_fonts.Os2,
  post : @read_fonts.Post?,
) -> Attributes {
  let stretch = Stretch::from_width_class(os2.us_width_class())
  // Bits 1 and 9 of the fsSelection field signify italic and
  // oblique, respectively.
  let fs_selection = os2.fs_selection()
  let style = if (fs_selection & @read_fonts.OS2_SELECTION_ITALIC) != 0 {
    Italic
  } else if (fs_selection & @read_fonts.OS2_SELECTION_OBLIQUE) != 0 {
    let angle = match post {
      Some(post) => Some(Float::from_double(post.italic_angle().to_f64()))
      None => None
    }
    Oblique(angle)
  } else {
    Normal
  }
  // The usWeightClass field is specified with a 1-1000 range, but
  // we don't clamp here because variable fonts could potentially
  // have a value outside of that range.
  let weight = Weight(Float::from_int(os2.us_weight_class()))
  { stretch, style, weight, }
}

///|
fn Attributes::from_head(head : @read_fonts.Head) -> Attributes {
  let mac_style = head.mac_style()
  let style = if (mac_style & @read_fonts.MAC_STYLE_ITALIC) != 0 {
    Italic
  } else {
    Normal
  }
  let weight = if (mac_style & @read_fonts.MAC_STYLE_BOLD) != 0 {
    Weight::bold()
  } else {
    Weight::normal()
  }
  { stretch: Stretch::normal(), style, weight, }
}

///|
/// Visual width of a font-- a relative change from the normal aspect
/// ratio, typically in the range 0.5 to 2.0.
pub(all) struct Stretch(Float) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Stretch with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Stretch with @debug.Debug::{to_repr}

///|
pub fn Stretch::normal() -> Stretch {
  Stretch(1.0)
}

///|
/// Creates a new stretch attribute with the given ratio.
pub fn Stretch::new(ratio : Float) -> Stretch {
  Stretch(ratio)
}

///|
fn Stretch::from_width_class(width_class : Int) -> Stretch {
  // The specified range is 1-9 and Skia simply clamps out of range
  // values. We follow.
  match width_class {
    0..=1 => Stretch(0.5)
    2 => Stretch(0.625)
    3 => Stretch(0.75)
    4 => Stretch(0.875)
    5 => Stretch(1.0)
    6 => Stretch(1.125)
    7 => Stretch(1.25)
    8 => Stretch(1.5)
    _ => Stretch(2.0)
  }
}

///|
/// Returns the stretch attribute as a ratio.
pub fn Stretch::ratio(self : Stretch) -> Float {
  self.0
}

///|
/// Returns the stretch attribute as a percentage value.
pub fn Stretch::percentage(self : Stretch) -> Float {
  self.0 * 100.0
}

///|
/// Visual style or 'slope' of a font.
pub(all) enum Style {
  Normal
  Italic
  Oblique(Float?)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Style with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Style with @debug.Debug::{to_repr}

///|
/// Visual weight class of a font, typically on a scale from 1.0 to 1000.0.
pub(all) struct Weight(Float) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Weight with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Weight with @debug.Debug::{to_repr}

///|
pub fn Weight::normal() -> Weight {
  Weight(400.0)
}

///|
pub fn Weight::bold() -> Weight {
  Weight(700.0)
}

///|
/// Creates a new weight attribute with the given value.
pub fn Weight::new(weight : Float) -> Weight {
  Weight(weight)
}

///|
/// Returns the underlying weight value.
pub fn Weight::value(self : Weight) -> Float {
  self.0
}
