// Port of `typst-library/src/text/font/variant.rs` and the non-cast parts of
// `variations.rs` (`FontAxis`, `StandardAxes`, `FontVariations::resolve`).
// The castable types themselves live in text_font.mbt.

///|
/// Properties that distinguish a font from other fonts in the same family.
pub(all) struct FontVariant {
  /// The style of the font (normal / italic / oblique).
  style : FontStyle
  /// How heavy the font is (100 - 900).
  weight : FontWeight
  /// How condensed or expanded the font is (0.5 - 2.0).
  stretch : FontStretch
} derive(Eq, Hash, Compare)

///|
pub impl Default for FontVariant with fn default() {
  {
    style: Normal,
    weight: FontWeight::default(),
    stretch: FontStretch::default(),
  }
}

///|
pub extend FontVariant with Default::{default}

///|
/// Create a variant from its three components.
pub fn FontVariant::new(
  style : FontStyle,
  weight : FontWeight,
  stretch : FontStretch,
) -> FontVariant {
  { style, weight, stretch, }
}

///|
/// Upstream `Debug for FontVariant`: `{style:?}-{weight:?}-{stretch:?}`.
pub impl Show for FontVariant with fn output(self, logger) {
  let style = match self.style {
    Normal => "Normal"
    Italic => "Italic"
    Oblique => "Oblique"
  }
  logger.write_string(
    "\{style}-FontWeight(\{self.weight.0})-FontStretch(\{self.stretch.0})",
  )
}

///|
/// Maps an OpenType `wght` font variation value to a weight.
pub fn FontWeight::from_wght(value : AxisValue) -> FontWeight {
  FontWeight::from_number(f32_as_u16(value.get()).to_int())
}

///|
/// Maps a weight to an OpenType `wght` font variation value.
pub fn FontWeight::to_wght(self : FontWeight) -> AxisValue {
  AxisValue::new(Float::from_int(self.to_number()))
}

///|
/// Create a font stretch from an OpenType-style number between 1 and 9,
/// clamping it if necessary.
pub fn FontStretch::from_number(stretch : Int) -> FontStretch {
  match stretch {
    0 | 1 => FontStretch(500)
    2 => FontStretch(625)
    3 => FontStretch(750)
    4 => FontStretch(875)
    5 => FontStretch(1000)
    6 => FontStretch(1125)
    7 => FontStretch(1250)
    8 => FontStretch(1500)
    _ => FontStretch(2000)
  }
}

///|
/// Maps an OpenType `wdth` font variation value to a stretch.
pub fn FontStretch::from_wdth(value : AxisValue) -> FontStretch {
  FontStretch::from_ratio(Ratio::new(value.get().to_double() / 100.0))
}

///|
/// Maps an OpenType `wdth` font variation value to a stretch.
pub fn FontStretch::to_wdth(self : FontStretch) -> AxisValue {
  AxisValue::new(Float::from_double(self.to_ratio().get()) * 100.0)
}

///|
/// Round to one of the pre-defined variants.
pub fn FontStretch::round(self : FontStretch) -> FontStretch {
  match self.0 {
    0..=562 => FontStretch(500)
    563..=687 => FontStretch(625)
    688..=812 => FontStretch(750)
    813..=937 => FontStretch(875)
    938..=1062 => FontStretch(1000)
    1063..=1187 => FontStretch(1125)
    1188..=1374 => FontStretch(1250)
    1375..=1749 => FontStretch(1500)
    _ => FontStretch(2000)
  }
}

///|
/// The absolute ratio distance between this and another font stretch.
pub fn FontStretch::distance(self : FontStretch, other : FontStretch) -> Ratio {
  Ratio::new(self.to_ratio().get() - other.to_ratio().get()).abs()
}

///|
/// Rust's `f32 as u16` (saturating, NaN -> 0).
fn f32_as_u16(v : Float) -> UInt16 {
  @otf.f32_as_u16(v)
}

///|
/// The `f32` value of an axis value.
pub fn AxisValue::get(self : AxisValue) -> Float {
  Float::from_double(self.0)
}

///|
/// Create an axis value from an `f32`.
pub fn AxisValue::new(v : Float) -> AxisValue {
  AxisValue(v.to_double())
}

///|
/// Clamps this value into the allowed range for the given `axis`.
pub fn AxisValue::clamp(self : AxisValue, axis : FontAxis) -> AxisValue {
  // Rust's `f32::clamp`.
  let v = self.get()
  let min = axis.min.get()
  let max = axis.max.get()
  let v = if v < min { min } else { v }
  let v = if v > max { max } else { v }
  AxisValue::new(v)
}

///|
/// A variation axis in a font.
pub(all) struct FontAxis {
  /// The OpenType tag that identifies the axis. May be a standard tag like
  /// `wght` or a custom tag.
  tag : OpenTypeTag
  /// The minimum value the font supports for this axis.
  min : AxisValue
  /// The maximum value the font supports for this axis.
  max : AxisValue
  /// The default value the font has set for this axis.
  default : AxisValue
} derive(Eq, Hash, Debug)

///|
/// Determines the distance from the `target` value to the closest value
/// that lies within the axis' range.
fn[T : Compare, N : Default] FontAxis::distance(
  self : FontAxis,
  target : T,
  parse : (AxisValue) -> T,
  distance : (T, T) -> N,
) -> N {
  let min = parse(self.min)
  let max = parse(self.max)
  if target < min {
    distance(min, target)
  } else if target < max {
    N::default()
  } else {
    distance(target, max)
  }
}

///|
/// Well-known variation axes that are used for font selection and/or affected
/// by text properties during instantiation.
pub(all) struct StandardAxes {
  mut ital : FontAxis?
  mut slnt : FontAxis?
  mut wght : FontAxis?
  mut wdth : FontAxis?
  mut opsz : FontAxis?
}

///|
let standard_axes_list : ReadOnlyArray[String] = [
  "ital", "slnt", "wght", "wdth", "opsz",
]

///|
/// Extracts the standard axes from the given axes.
pub fn StandardAxes::parse(axes : Array[FontAxis]) -> StandardAxes {
  let this : StandardAxes = {
    ital: None,
    slnt: None,
    wght: None,
    wdth: None,
    opsz: None,
  }
  for axis in axes {
    match axis.tag.0 {
      "ital" => this.ital = Some(axis)
      "slnt" => this.slnt = Some(axis)
      "wght" => this.wght = Some(axis)
      "wdth" => this.wdth = Some(axis)
      "opsz" => this.opsz = Some(axis)
      _ => ()
    }
  }
  this
}

///|
/// Whether the given tag is one of the standard ones.
pub fn StandardAxes::knows(tag : OpenTypeTag) -> Bool {
  standard_axes_list.contains(tag.0)
}

///|
/// Returns a metric with which axes can be sorted for user-facing display.
pub fn StandardAxes::order(tag : OpenTypeTag) -> Int {
  match standard_axes_list.search(tag.0) {
    Some(i) => i
    None => standard_axes_list.length()
  }
}

///|
/// Resolves which variations to set given the `axes` supported by a font
/// and a desired font `variant` and point `size`.
pub fn FontVariations::resolve(
  axes : Array[FontAxis],
  variant : FontVariant,
  size : Abs,
) -> FontVariations {
  let variations = []
  let set = (axis : FontAxis, value : AxisValue) => {
    variations.push((axis.tag, value.clamp(axis)))
  }
  let axes = StandardAxes::parse(axes)
  match (variant.style, axes.ital, axes.slnt) {
    // Don't need to do anything or can't do anything.
    (Normal, _, _) | (_, None, None) => ()
    // Serve italic due to request or as fallback for oblique.
    (Italic, Some(axis), _) | (Oblique, Some(axis), None) => {
      // Set to 1.0 for italic, but avoid exceeding the axis' range.
      let max = axis.max.get()
      set(axis, AxisValue::new(if max < 1.0 { max } else { 1.0 }))
    }
    // Serve oblique due to request or as fallback for italic.
    (Oblique, _, Some(axis)) | (Italic, None, Some(axis)) =>
      // Slant values are clockwise and a typical italic is
      // counter-clockwise, so negative values are desirable. If the
      // axis doesn't support negative slant, however, we prefer,
      // positive slant over no slant at all.
      if axis.min.get() < 0.0 {
        set(axis, axis.min)
      } else if axis.max.get() > 0.0 {
        set(axis, axis.max)
      }
  }
  if axes.wdth is Some(axis) {
    set(axis, variant.stretch.to_wdth())
  }
  if axes.wght is Some(axis) {
    set(axis, variant.weight.to_wght())
  }
  if axes.opsz is Some(axis) {
    set(axis, AxisValue::new(Float::from_double(size.to_pt())))
  }
  FontVariations(variations)
}

///|
/// Adds additional font variations to the end.
pub fn FontVariations::chain(
  self : FontVariations,
  other : FontVariations,
) -> FontVariations {
  FontVariations(self.0 + other.0)
}

///|
/// Sorts and deduplicates variations so that we have one canonical
/// font instance for each combination.
pub fn FontVariations::normalized(self : FontVariations) -> FontVariations {
  // Sort should be stable so that later values consistently win.
  let indexed = self.0.mapi((i, e) => (i, e))
  indexed.sort_by((a, b) => {
    let c = compare_str(a.1.0.0, b.1.0.0)
    if c != 0 {
      c
    } else {
      a.0 - b.0
    }
  })
  let sorted = indexed.map(e => e.1)
  // We want later values to win (`rdedup_by_key`).
  let out = []
  for i, entry in sorted {
    if i + 1 < sorted.length() && sorted[i + 1].0 == entry.0 {
      continue
    }
    out.push(entry)
  }
  FontVariations(out)
}
