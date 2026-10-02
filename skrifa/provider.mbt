// Port of skrifa 0.42.1 `src/provider.rs` (`MetadataProvider`, subset).

///|
/// Interface for types that can provide font metadata.
pub(open) trait MetadataProvider {
  /// Returns the primary attributes for font classification-- stretch,
  /// style and weight.
  fn attributes(Self) -> Attributes
  /// Returns the global font metrics for the specified size and location
  /// in normalized variation space.
  fn metrics(Self, Size, LocationRef) -> Metrics
  /// Returns the glyph specific metrics for the specified size and location
  /// in normalized variation space.
  fn glyph_metrics(Self, Size, LocationRef) -> GlyphMetrics
  /// Returns the character to nominal glyph identifier mapping.
  fn charmap(Self) -> Charmap
  /// Returns the collection of scalable glyph outlines.
  fn outline_glyphs(Self) -> OutlineGlyphCollection
}

///|
pub impl MetadataProvider for FontRef with fn attributes(self) {
  Attributes::new(self)
}

///|
pub impl MetadataProvider for FontRef with fn metrics(self, size, location) {
  Metrics::new(self, size, location)
}

///|
pub impl MetadataProvider for FontRef with fn glyph_metrics(
  self,
  size,
  location,
) {
  GlyphMetrics::new(self, size, location)
}

///|
pub impl MetadataProvider for FontRef with fn charmap(self) {
  Charmap::new(self)
}

///|
pub impl MetadataProvider for FontRef with fn outline_glyphs(self) {
  OutlineGlyphCollection::new(self)
}
