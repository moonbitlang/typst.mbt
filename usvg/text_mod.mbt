// Port of `usvg` 0.47.0 `src/text/mod.rs`: font resolving and text
// conversion entry point.

///|
/// A font resolver for `<text>` elements.
///
/// This type can be useful if you want to have an alternative font handling to
/// the default one. By default, only fonts specified upfront in
/// [`Options::fontdb`](crate::Options::fontdb) will be used. This type allows
/// you to load additional fonts on-demand and customize the font selection
/// process.
pub(all) struct FontResolver {
  /// Resolver function that will be used when selecting a specific font
  /// for a generic [`Font`] specification.
  ///
  /// It receives a font specification (families + a style, weight, stretch
  /// triple) and a font database and should return the ID of the font that
  /// shall be used (if any). It may add fonts to the database.
  select_font : (Font, FontDatabase) -> FontId?
  /// Resolver function that will be used when selecting a fallback font for a
  /// character.
  ///
  /// It receives a specific character, a list of already used fonts, and a
  /// font database. It should return the ID of a font that
  /// - is not any of the already used fonts
  /// - is as close as possible to the first already used font (if any)
  /// - supports the given character
  select_fallback : (Char, Array[FontId], FontDatabase) -> FontId?
}

///|
pub impl Default for FontResolver with fn default() {
  {
    select_font: FontResolver::default_font_selector(),
    select_fallback: FontResolver::default_fallback_selector(),
  }
}

///|
pub extend FontResolver with Default::{default}

///|
/// Creates a default font selection resolver.
///
/// The default implementation forwards to `query` on the font database
/// specified in the `Options`.
pub fn FontResolver::default_font_selector() -> (Font, FontDatabase) -> FontId? {
  (font, fontdb) => {
    let name_list = font.families.copy()
    // Use the default font as fallback.
    name_list.push(Serif)
    let style = match font.style {
      Normal => DbStyle::Normal
      Italic => DbStyle::Italic
      Oblique => DbStyle::Oblique
    }
    let query : FontQuery = {
      families: name_list,
      weight: font.weight,
      stretch: font.stretch,
      style,
    }
    // Upstream warns: No match for '{}' font-family.
    fontdb.query(query)
  }
}

///|
/// Creates a default font fallback selection resolver.
///
/// The default implementation searches through the entire `fontdb`
/// to find a font that has the correct style and supports the character.
pub fn FontResolver::default_fallback_selector() -> (
  Char,
  Array[FontId],
  FontDatabase,
) -> FontId? {
  (c, exclude_fonts, fontdb) => {
    let base_font_id = exclude_fonts[0]

    // Iterate over fonts and check if any of them support the specified char.
    for face in fontdb.faces() {
      // Ignore fonts, that were used for shaping already.
      if exclude_fonts.contains(face.id) {
        continue
      }

      // Check that the new face has the same style.
      guard fontdb.face(base_font_id) is Some(base_face) else { return None }
      if base_face.style != face.style &&
        base_face.weight != face.weight &&
        base_face.stretch != face.stretch {
        continue
      }
      if !fontdb.has_char(face.id, c) {
        continue
      }
      // Upstream warns: Fallback from {} to {}.
      return Some(face.id)
    }
    None
  }
}

///|
/// Convert a text into its paths. This is done in two steps:
/// 1. We convert the text into glyphs and position them according to the rules specified
///    in the SVG specification. While doing so, we also calculate the text bbox (which
///    is not based on the outlines of a glyph, but instead the glyph metrics as well
///    as decoration spans).
/// 2. We convert all of the positioned glyphs into outlines.
fn text_to_paths(text : Text, resolver : FontResolver, cache : Cache) -> Unit? {
  guard layout_text(text, resolver, cache.fontdb)
    is Some((text_fragments, bbox)) else {
    return None
  }
  text.layouted = text_fragments
  text.bounding_box = bbox.to_rect()
  guard bbox.transform(text.abs_transform) is Some(abs_bbox) else {
    return None
  }
  text.abs_bounding_box = abs_bbox.to_rect()
  guard flatten_text(text, cache) is Some((group, stroke_bbox)) else {
    return None
  }
  text.flattened = group
  text.stroke_bounding_box = stroke_bbox.to_rect()
  guard stroke_bbox.transform(text.abs_transform) is Some(abs_stroke_bbox) else {
    return None
  }
  text.abs_stroke_bounding_box = abs_stroke_bbox.to_rect()
  Some(())
}
