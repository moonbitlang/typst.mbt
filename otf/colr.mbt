// A [Color Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/colr) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/colr.rs` (with the
// `variable-fonts` feature enabled).

// NOTE: Parts of the implementation have been inspired by
// [skrifa](https://github.com/googlefonts/fontations/tree/main/skrifa).

///|
/// A [base glyph](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#baseglyph-and-layer-records).
priv struct BaseGlyphRecord {
  glyph_id : GlyphId
  first_layer_index : UInt16
  num_layers : UInt16
}

///|
/// A [ClipBox](https://learn.microsoft.com/en-us/typography/opentype/spec/colr#baseglyphlist-layerlist-and-cliplist).
pub type ClipBox = RectF

///|
/// A paint.
pub(all) enum Paint {
  /// A paint with a solid color.
  Solid(RgbaColor)
  /// A paint with a linear gradient.
  LinearGradient(LinearGradient)
  /// A paint with a radial gradient.
  RadialGradient(RadialGradient)
  /// A paint with a sweep gradient.
  SweepGradient(SweepGradient)
}

///|
/// A [clip record](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#baseglyphlist-layerlist-and-cliplist).
priv struct ClipRecord {
  /// The first glyph ID for the range covered by this record.
  start_glyph_id : GlyphId
  /// The last glyph ID, *inclusive*, for the range covered by this record.
  end_glyph_id : GlyphId
  /// The offset to the clip box.
  clip_box_offset : Offset24
}

///|
impl FromData for ClipRecord with fn size() {
  7
}

///|
impl FromData for ClipRecord with fn parse(data) {
  let s = Stream::new(data)
  {
    start_glyph_id: s.read(),
    end_glyph_id: s.read(),
    clip_box_offset: s.read(),
  }
}

///|
/// Checks whether the glyphs range contains `glyph_id`.
fn ClipRecord::glyphs_range_contains(
  self : ClipRecord,
  glyph_id : GlyphId,
) -> Bool {
  self.start_glyph_id <= glyph_id && glyph_id <= self.end_glyph_id
}

///|
/// A [clip list](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#baseglyphlist-layerlist-and-cliplist).
priv struct ClipList {
  data : BytesView
  records : LazyArray32[ClipRecord]
}

///|
impl Default for ClipList with fn default() {
  { data: empty_data, records: LazyArray32::default(), }
}

///|
fn ClipList::get(
  self : ClipList,
  index : UInt,
  variation_data : ColrVariationData,
  coords : ArrayView[NormalizedCoordinate],
) -> ClipBox? {
  guard self.records.get(index) is Some(record) else { return None }
  let offset = record.clip_box_offset.to_usize()
  guard slice_from(self.data, offset) is Some(data) else { return None }
  try {
    let s = Stream::new(data)
    let format = s.read_u8()
    let deltas = if format == 2 {
      let var_s = s.copy()
      var_s.advance(8)
      let var_index_base = var_s.read_u32()
      variation_data.read_deltas(4, var_index_base, coords)
    } else {
      FixedArray::make(4, (0.0 : Float))
    }
    Some({
      x_min: Float::from_int(s.read_i16().to_int()) + deltas[0],
      y_min: Float::from_int(s.read_i16().to_int()) + deltas[1],
      x_max: Float::from_int(s.read_i16().to_int()) + deltas[2],
      y_max: Float::from_int(s.read_i16().to_int()) + deltas[3],
    })
  } catch {
    _ => None
  }
}

///|
/// Returns a ClipBox by glyph ID.
fn ClipList::find(
  self : ClipList,
  glyph_id : GlyphId,
  variation_data : ColrVariationData,
  coords : ArrayView[NormalizedCoordinate],
) -> ClipBox? {
  let len = self.records.len()
  let mut index : UInt = 0
  while index < len {
    guard self.records.get(index) is Some(v) else { return None }
    if v.glyphs_range_contains(glyph_id) {
      return self.get(index, variation_data, coords)
    }
    index += 1
  }
  None
}

///|
impl FromData for BaseGlyphRecord with fn size() {
  6
}

///|
impl FromData for BaseGlyphRecord with fn parse(data) {
  let s = Stream::new(data)
  { glyph_id: s.read(), first_layer_index: s.read(), num_layers: s.read(), }
}

///|
/// A [layer](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#baseglyph-and-layer-records).
priv struct LayerRecord {
  glyph_id : GlyphId
  palette_index : UInt16
}

///|
impl FromData for LayerRecord with fn size() {
  4
}

///|
impl FromData for LayerRecord with fn parse(data) {
  let s = Stream::new(data)
  { glyph_id: s.read(), palette_index: s.read(), }
}

///|
/// A [BaseGlyphPaintRecord](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#baseglyphlist-layerlist-and-cliplist).
priv struct BaseGlyphPaintRecord {
  glyph_id : GlyphId
  paint_table_offset : Offset32
}

///|
impl FromData for BaseGlyphPaintRecord with fn size() {
  6
}

///|
impl FromData for BaseGlyphPaintRecord with fn parse(data) {
  let s = Stream::new(data)
  { glyph_id: s.read(), paint_table_offset: s.read(), }
}

///|
/// A [gradient extend](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#baseglyphlist-layerlist-and-cliplist).
pub(all) enum GradientExtend {
  /// The `Pad` gradient extend mode.
  Pad
  /// The `Repeat` gradient extend mode.
  Repeat
  /// The `Reflect` gradient extend mode.
  Reflect
} derive(Eq, Debug)

///|
pub impl FromData for GradientExtend with fn size() {
  1
}

///|
pub impl FromData for GradientExtend with fn parse(data) {
  match data[0] {
    0 => Pad
    1 => Repeat
    2 => Reflect
    _ => raise Malformed
  }
}

///|
/// A [color stop](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#color-references-colorstop-and-colorline).
priv struct ColorStopRaw {
  stop_offset : F2DOT14
  palette_index : UInt16
  alpha : F2DOT14
}

///|
impl FromData for ColorStopRaw with fn size() {
  6
}

///|
impl FromData for ColorStopRaw with fn parse(data) {
  let s = Stream::new(data)
  { stop_offset: s.read(), palette_index: s.read(), alpha: s.read(), }
}

///|
/// A [var color stop](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#color-references-colorstop-and-colorline).
priv struct VarColorStopRaw {
  stop_offset : F2DOT14
  palette_index : UInt16
  alpha : F2DOT14
  var_index_base : UInt
}

///|
impl FromData for VarColorStopRaw with fn size() {
  10
}

///|
impl FromData for VarColorStopRaw with fn parse(data) {
  let s = Stream::new(data)
  {
    stop_offset: s.read(),
    palette_index: s.read(),
    alpha: s.read(),
    var_index_base: s.read(),
  }
}

///|
priv struct NonVarColorLine {
  extend : GradientExtend
  colors : LazyArray16[ColorStopRaw]
  palettes : CpalTable
  foreground_color : RgbaColor
}

///|
// TODO: Color stops should be sorted, but hard to do without allocations
fn NonVarColorLine::get(
  self : NonVarColorLine,
  palette : UInt16,
  index : UInt16,
) -> ColorStop? {
  guard self.colors.get(index) is Some(info) else { return None }
  let color = if info.palette_index == 0xFFFF {
    { ..self.foreground_color, }
  } else {
    guard self.palettes.get(palette, info.palette_index) is Some(c) else {
      return None
    }
    c
  }
  color.apply_alpha(info.alpha.to_f32())
  Some({ stop_offset: info.stop_offset.to_f32(), color, })
}

///|
// TODO: Color stops should be sorted, but hard to do without allocations
fn VarColorLine::get(
  self : VarColorLine,
  palette : UInt16,
  index : UInt16,
  variation_data : ColrVariationData,
  coordinates : ArrayView[NormalizedCoordinate],
) -> ColorStop? {
  guard self.colors.get(index) is Some(info) else { return None }
  let color = if info.palette_index == 0xFFFF {
    { ..self.foreground_color, }
  } else {
    guard self.palettes.get(palette, info.palette_index) is Some(c) else {
      return None
    }
    c
  }
  let deltas = variation_data.read_deltas(2, info.var_index_base, coordinates)
  let stop_offset = info.stop_offset.apply_float_delta(deltas[0])
  color.apply_alpha(info.alpha.apply_float_delta(deltas[1]))
  Some({ stop_offset, color, })
}

///|
priv struct VarColorLine {
  extend : GradientExtend
  colors : LazyArray16[VarColorStopRaw]
  palettes : CpalTable
  foreground_color : RgbaColor
}

///|
enum ColorLine {
  VarColorLine(VarColorLine)
  NonVarColorLine(NonVarColorLine)
}

///|
/// A [gradient extend](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/colr#color-references-colorstop-and-colorline).
pub(all) struct ColorStop {
  /// The offset of the color stop.
  stop_offset : Float
  /// The color of the color stop.
  color : RgbaColor
} derive(Debug)

///|
/// A [linear gradient](https://learn.microsoft.com/en-us/typography/opentype/spec/colr#formats-4-and-5-paintlineargradient-paintvarlineargradient)
pub struct LinearGradient {
  /// The `x0` value.
  x0 : Float
  /// The `y0` value.
  y0 : Float
  /// The `x1` value.
  x1 : Float
  /// The `y1` value.
  y1 : Float
  /// The `x2` value.
  x2 : Float
  /// The `y2` value.
  y2 : Float
  /// The extend.
  extend : GradientExtend
  variation_data : ColrVariationData
  color_line : ColorLine
}

///|
/// Returns an iterator over the stops of the linear gradient. Stops need to be sorted
/// manually by the caller.
pub fn LinearGradient::stops(
  self : LinearGradient,
  palette : UInt16,
  coords : ArrayView[NormalizedCoordinate],
) -> GradientStopsIter {
  {
    color_line: self.color_line,
    palette,
    index: 0,
    variation_data: self.variation_data,
    coords,
  }
}

///|
/// A [radial gradient](https://learn.microsoft.com/en-us/typography/opentype/spec/colr#formats-6-and-7-paintradialgradient-paintvarradialgradient)
pub struct RadialGradient {
  /// The `x0` value.
  x0 : Float
  /// The `y0` value.
  y0 : Float
  /// The `r0` value.
  r0 : Float
  /// The `r1` value.
  r1 : Float
  /// The `x1` value.
  x1 : Float
  /// The `y1` value.
  y1 : Float
  /// The extend.
  extend : GradientExtend
  variation_data : ColrVariationData
  color_line : ColorLine
}

///|
/// Returns an iterator over the stops of the radial gradient. Stops need to be sorted
/// manually by the caller.
pub fn RadialGradient::stops(
  self : RadialGradient,
  palette : UInt16,
  coords : ArrayView[NormalizedCoordinate],
) -> GradientStopsIter {
  {
    color_line: self.color_line,
    palette,
    index: 0,
    variation_data: self.variation_data,
    coords,
  }
}

///|
/// A [sweep gradient](https://learn.microsoft.com/en-us/typography/opentype/spec/colr#formats-8-and-9-paintsweepgradient-paintvarsweepgradient)
pub struct SweepGradient {
  /// The x of the center.
  center_x : Float
  /// The y of the center.
  center_y : Float
  /// The start angle.
  start_angle : Float
  /// The end angle.
  end_angle : Float
  /// The extend.
  extend : GradientExtend
  variation_data : ColrVariationData
  color_line : ColorLine
}

///|
// TODO: Make API nicer so that variable coordinates don't
// need to be passed by the caller (same for radial and linear gradient)
///|
/// Returns an iterator over the stops of the sweep gradient. Stops need to be sorted
/// manually by the caller.
pub fn SweepGradient::stops(
  self : SweepGradient,
  palette : UInt16,
  coords : ArrayView[NormalizedCoordinate],
) -> GradientStopsIter {
  {
    color_line: self.color_line,
    palette,
    index: 0,
    variation_data: self.variation_data,
    coords,
  }
}

///|
/// An iterator over stops of a gradient.
struct GradientStopsIter {
  color_line : ColorLine
  palette : UInt16
  mut index : UInt16
  variation_data : ColrVariationData
  coords : ArrayView[NormalizedCoordinate]
}

///|
/// Copies the iterator (Rust's `Clone`/`Copy`).
pub fn GradientStopsIter::copy(self : GradientStopsIter) -> GradientStopsIter {
  { ..self, }
}

///|
/// Returns the next color stop.
pub fn GradientStopsIter::next(self : GradientStopsIter) -> ColorStop? {
  let len = match self.color_line {
    VarColorLine(vcl) => vcl.colors.len()
    NonVarColorLine(nvcl) => nvcl.colors.len()
  }
  if self.index == len {
    return None
  }
  let index = self.index
  guard u16_checked_add(self.index, 1) is Some(next) else { return None }
  self.index = next
  match self.color_line {
    VarColorLine(vcl) =>
      vcl.get(self.palette, index, self.variation_data, self.coords)
    NonVarColorLine(nvcl) => nvcl.get(self.palette, index)
  }
}

///|
/// Iterates over the remaining color stops.
pub fn GradientStopsIter::iter(self : GradientStopsIter) -> Iter[ColorStop] {
  Iter::new(() => self.next())
}

///|
/// A [composite mode](https://learn.microsoft.com/en-us/typography/opentype/spec/colr#format-32-paintcomposite)
pub(all) enum CompositeMode {
  /// The composite mode 'Clear'.
  Clear
  /// The composite mode 'Source'.
  Source
  /// The composite mode 'Destination'.
  Destination
  /// The composite mode 'SourceOver'.
  SourceOver
  /// The composite mode 'DestinationOver'.
  DestinationOver
  /// The composite mode 'SourceIn'.
  SourceIn
  /// The composite mode 'DestinationIn'.
  DestinationIn
  /// The composite mode 'SourceOut'.
  SourceOut
  /// The composite mode 'DestinationOut'.
  DestinationOut
  /// The composite mode 'SourceAtop'.
  SourceAtop
  /// The composite mode 'DestinationAtop'.
  DestinationAtop
  /// The composite mode 'Xor'.
  Xor
  /// The composite mode 'Plus'.
  Plus
  /// The composite mode 'Screen'.
  Screen
  /// The composite mode 'Overlay'.
  Overlay
  /// The composite mode 'Darken'.
  Darken
  /// The composite mode 'Lighten'.
  Lighten
  /// The composite mode 'ColorDodge'.
  ColorDodge
  /// The composite mode 'ColorBurn'.
  ColorBurn
  /// The composite mode 'HardLight'.
  HardLight
  /// The composite mode 'SoftLight'.
  SoftLight
  /// The composite mode 'Difference'.
  Difference
  /// The composite mode 'Exclusion'.
  Exclusion
  /// The composite mode 'Multiply'.
  Multiply
  /// The composite mode 'Hue'.
  Hue
  /// The composite mode 'Saturation'.
  Saturation
  /// The composite mode 'Color'.
  Color
  /// The composite mode 'Luminosity'.
  Luminosity
} derive(Eq, Debug)

///|
pub impl FromData for CompositeMode with fn size() {
  1
}

///|
pub impl FromData for CompositeMode with fn parse(data) {
  match data[0] {
    0 => Clear
    1 => Source
    2 => Destination
    3 => SourceOver
    4 => DestinationOver
    5 => SourceIn
    6 => DestinationIn
    7 => SourceOut
    8 => DestinationOut
    9 => SourceAtop
    10 => DestinationAtop
    11 => Xor
    12 => Plus
    13 => Screen
    14 => Overlay
    15 => Darken
    16 => Lighten
    17 => ColorDodge
    18 => ColorBurn
    19 => HardLight
    20 => SoftLight
    21 => Difference
    22 => Exclusion
    23 => Multiply
    24 => Hue
    25 => Saturation
    26 => Color
    27 => Luminosity
    _ => raise Malformed
  }
}

///|
/// A trait for color glyph painting (`colr::Painter`).
///
/// See [COLR](https://learn.microsoft.com/en-us/typography/opentype/spec/colr) for details.
pub(open) trait ColrPainter {
  /// Outline a glyph and store it.
  fn outline_glyph(Self, GlyphId) -> Unit
  /// Paint the stored outline using the provided color.
  fn paint(Self, Paint) -> Unit
  /// Push a new clip path using the currently stored outline.
  fn push_clip(Self) -> Unit
  /// Push a new clip path using the clip box.
  fn push_clip_box(Self, ClipBox) -> Unit
  /// Pop the last clip path.
  fn pop_clip(Self) -> Unit
  /// Push a new layer with the given composite mode.
  fn push_layer(Self, CompositeMode) -> Unit
  /// Pop the last layer.
  fn pop_layer(Self) -> Unit
  /// Push a transform.
  fn push_transform(Self, Transform) -> Unit
  /// Pop the last transform.
  fn pop_transform(Self) -> Unit
}

///|
/// A [Color Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/colr).
struct ColrTable {
  palettes : CpalTable
  data : BytesView
  version : Byte
  // v0
  base_glyphs : LazyArray16[BaseGlyphRecord]
  layers : LazyArray16[LayerRecord]
  // v1
  base_glyph_paints_offset : Offset32
  base_glyph_paints : LazyArray32[BaseGlyphPaintRecord]
  layer_paint_offsets_offset : Offset32
  layer_paint_offsets : LazyArray32[Offset32]
  clip_list_offsets_offset : Offset32
  clip_list : ClipList
  var_index_map : DeltaSetIndexMap?
  item_variation_store : ItemVariationStore?
}

///|
/// Parses a table from raw data.
pub fn ColrTable::parse(palettes : CpalTable, data : BytesView) -> ColrTable? {
  let s = Stream::new(data)
  try {
    let version = s.read_u16()
    if version > 1 {
      return None
    }
    let num_base_glyphs = s.read_u16()
    let base_glyphs_offset : Offset32 = s.read()
    let layers_offset : Offset32 = s.read()
    let num_layers = s.read_u16()
    let base_glyphs = Stream::new_at_r(data, base_glyphs_offset.to_usize()).read_array16(
      num_base_glyphs,
    )
    let layers = Stream::new_at_r(data, layers_offset.to_usize()).read_array16(
      num_layers,
    )
    let table : ColrTable = {
      version: version.to_byte(),
      data,
      palettes,
      base_glyphs,
      layers,
      base_glyph_paints_offset: Offset32(0), // the actual value doesn't matter
      base_glyph_paints: LazyArray32::default(),
      layer_paint_offsets_offset: Offset32(0),
      layer_paint_offsets: LazyArray32::default(),
      clip_list_offsets_offset: Offset32(0),
      clip_list: Default::default(),
      item_variation_store: None,
      var_index_map: None,
    }
    if version == 0 {
      return Some(table)
    }
    let base_glyph_paints_offset : Offset32 = s.read()
    let layer_list_offset : Offset32? = s.read()
    let clip_list_offset : Offset32? = s.read()
    let var_index_map_offset : Offset32? = s.read()
    let item_variation_offset : Offset32? = s.read()
    let base_glyph_paints = {
      let s = Stream::new_at_r(data, base_glyph_paints_offset.to_usize())
      let count = s.read_u32()
      s.read_array32(count)
    }
    let mut layer_paint_offsets_offset = table.layer_paint_offsets_offset
    let mut layer_paint_offsets = table.layer_paint_offsets
    if layer_list_offset is Some(offset) {
      layer_paint_offsets_offset = offset
      let s = Stream::new_at_r(data, offset.to_usize())
      let count = s.read_u32()
      layer_paint_offsets = s.read_array32(count)
    }
    let mut clip_list_offsets_offset = table.clip_list_offsets_offset
    let mut clip_list = table.clip_list
    if clip_list_offset is Some(offset) {
      clip_list_offsets_offset = offset
      let clip_data = slice_from_r(data, offset.to_usize())
      let s = Stream::new(clip_data)
      s.advance(1) // Format
      let count = s.read_u32()
      clip_list = { data: clip_data, records: s.read_array32(count), }
    }
    let mut item_variation_store = None
    if item_variation_offset is Some(offset) {
      let item_var_data = slice_from_r(data, offset.to_usize())
      let s = Stream::new(item_var_data)
      let var_store = req(ItemVariationStore::parse(s))
      item_variation_store = Some(var_store)
    }
    let mut var_index_map = None
    if var_index_map_offset is Some(offset) {
      let var_index_map_data = slice_from_r(data, offset.to_usize())
      var_index_map = Some(DeltaSetIndexMap::new(var_index_map_data))
    }
    Some({
      ..table,
      base_glyph_paints_offset,
      base_glyph_paints,
      layer_paint_offsets_offset,
      layer_paint_offsets,
      clip_list_offsets_offset,
      clip_list,
      item_variation_store,
      var_index_map,
    })
  } catch {
    _ => None
  }
}

///|
/// Returns `true` if the current table has version 0.
///
/// A simple table can only emit `outline_glyph` and `paint`
/// [`ColrPainter`] methods.
pub fn ColrTable::is_simple(self : ColrTable) -> Bool {
  self.version == 0
}

///|
fn ColrTable::get_v0(self : ColrTable, glyph_id : GlyphId) -> BaseGlyphRecord? {
  self.base_glyphs
  .binary_search_by(base => base.glyph_id.compare(glyph_id))
  .map(v => v.1)
}

///|
fn ColrTable::get_v1(
  self : ColrTable,
  glyph_id : GlyphId,
) -> BaseGlyphPaintRecord? {
  self.base_glyph_paints
  .binary_search_by(base => base.glyph_id.compare(glyph_id))
  .map(v => v.1)
}

///|
fn ColrTable::variation_data(self : ColrTable) -> ColrVariationData {
  { variation_store: self.item_variation_store, delta_map: self.var_index_map, }
}

///|
/// Whether the table contains a definition for the given glyph.
pub fn ColrTable::contains(self : ColrTable, glyph_id : GlyphId) -> Bool {
  self.get_v1(glyph_id) is Some(_) || self.get_v0(glyph_id) is Some(_)
}

///|
/// Returns the clip box for a glyph.
pub fn ColrTable::clip_box(
  self : ColrTable,
  glyph_id : GlyphId,
  coords : ArrayView[NormalizedCoordinate],
) -> ClipBox? {
  self.clip_list.find(glyph_id, self.variation_data(), coords)
}

///|
// This method should only be called from outside, not from within `colr.mbt`.
// From inside, you always should call paint_impl, so that the recursion stack can
// be passed on and any kind of recursion can be prevented.
///|
/// Paints the color glyph.
pub fn ColrTable::paint(
  self : ColrTable,
  glyph_id : GlyphId,
  palette : UInt16,
  painter : &ColrPainter,
  coords : ArrayView[NormalizedCoordinate],
  foreground_color : RgbaColor,
) -> Unit? {
  let recursion_stack = RecursionStack::new()
  self.paint_impl(
    glyph_id, palette, painter, recursion_stack, coords, foreground_color,
  )
}

///|
fn ColrTable::paint_impl(
  self : ColrTable,
  glyph_id : GlyphId,
  palette : UInt16,
  painter : &ColrPainter,
  recursion_stack : RecursionStack,
  coords : ArrayView[NormalizedCoordinate],
  foreground_color : RgbaColor,
) -> Unit? {
  if self.get_v1(glyph_id) is Some(base) {
    self.paint_v1(
      base, palette, painter, recursion_stack, coords, foreground_color,
    )
  } else if self.get_v0(glyph_id) is Some(base) {
    self.paint_v0(base, palette, painter, foreground_color)
  } else {
    None
  }
}

///|
fn ColrTable::paint_v0(
  self : ColrTable,
  base : BaseGlyphRecord,
  palette : UInt16,
  painter : &ColrPainter,
  foreground_color : RgbaColor,
) -> Unit? {
  let start = base.first_layer_index
  guard u16_checked_add(start, base.num_layers) is Some(end) else {
    return None
  }
  guard self.layers.slice(start, end) is Some(layers) else { return None }
  for layer in layers.iter() {
    if layer.palette_index == 0xFFFF {
      // A special case.
      painter.outline_glyph(layer.glyph_id)
      painter.paint(Paint::Solid({ ..foreground_color, }))
    } else {
      guard self.palettes.get(palette, layer.palette_index) is Some(color) else {
        return None
      }
      painter.outline_glyph(layer.glyph_id)
      painter.paint(Paint::Solid(color))
    }
  }
  Some(())
}

///|
fn ColrTable::paint_v1(
  self : ColrTable,
  base : BaseGlyphPaintRecord,
  palette : UInt16,
  painter : &ColrPainter,
  recursion_stack : RecursionStack,
  coords : ArrayView[NormalizedCoordinate],
  foreground_color : RgbaColor,
) -> Unit? {
  let clip_box = self.clip_box(base.glyph_id, coords)
  if clip_box is Some(clip_box) {
    painter.push_clip_box(clip_box)
  }
  self.parse_paint(
    self.base_glyph_paints_offset.to_usize() +
    base.paint_table_offset.to_usize(),
    palette,
    painter,
    recursion_stack,
    coords,
    foreground_color,
  )
  |> ignore
  if clip_box is Some(_) {
    painter.pop_clip()
  }
  Some(())
}

///|
fn ColrTable::parse_paint(
  self : ColrTable,
  offset : Int,
  palette : UInt16,
  painter : &ColrPainter,
  recursion_stack : RecursionStack,
  coords : ArrayView[NormalizedCoordinate],
  foreground_color : RgbaColor,
) -> Unit? {
  guard Stream::new_at(self.data, offset) is Some(s) else { return None }
  guard s.read_opt() is Some((format : Byte)) else { return None }

  // Cycle detected
  if recursion_stack.contains(offset) {
    return None
  }
  if !recursion_stack.push(offset) {
    return None
  }
  let result = self.parse_paint_impl(
    offset, palette, painter, recursion_stack, s, format, coords, foreground_color,
  )
  recursion_stack.pop()
  result
}

///|
fn ColrTable::parse_paint_impl(
  self : ColrTable,
  offset : Int,
  palette : UInt16,
  painter : &ColrPainter,
  recursion_stack : RecursionStack,
  s : Stream,
  format : Byte,
  coords : ArrayView[NormalizedCoordinate],
  foreground_color : RgbaColor,
) -> Unit? {
  // Paints a sub-paint at the given offset (the result is ignored, like
  // upstream).
  fn sub(paint_offset : Int) {
    self.parse_paint(
      paint_offset, palette, painter, recursion_stack, coords, foreground_color,
    )
    |> ignore
  }

  fn i16_f32(v : Int16) -> Float {
    Float::from_int(v.to_int())
  }

  try {
    match format {
      1 => {
        // PaintColrLayers
        let layers_count = s.read_u8()
        let first_layer_index = s.read_u32()
        for i in 0..<layers_count.to_int() {
          let index = req(
            u32_checked_add(first_layer_index, i.reinterpret_as_uint()),
          )
          let paint_offset = req(self.layer_paint_offsets.get(index))
          sub(
            self.layer_paint_offsets_offset.to_usize() + paint_offset.to_usize(),
          )
        }
      }
      2 => {
        // PaintSolid
        let palette_index = s.read_u16()
        let alpha = s.read_f2dot14()
        let color = if palette_index == 0xFFFF {
          { ..foreground_color, }
        } else {
          req(self.palettes.get(palette, palette_index))
        }
        color.apply_alpha(alpha.to_f32())
        painter.paint(Paint::Solid(color))
      }
      3 => {
        // PaintVarSolid
        let palette_index = s.read_u16()
        let alpha = s.read_f2dot14()
        let var_index_base = s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(1, var_index_base, coords)
        let color = if palette_index == 0xFFFF {
          { ..foreground_color, }
        } else {
          req(self.palettes.get(palette, palette_index))
        }
        color.apply_alpha(alpha.apply_float_delta(deltas[0]))
        painter.paint(Paint::Solid(color))
      }
      4 => {
        // PaintLinearGradient
        let color_line_offset : Offset24 = s.read()
        let color_line = req(
          self.parse_color_line(
            offset + color_line_offset.to_usize(),
            foreground_color,
          ),
        )
        let x0 = i16_f32(s.read_i16())
        let y0 = i16_f32(s.read_i16())
        let x1 = i16_f32(s.read_i16())
        let y1 = i16_f32(s.read_i16())
        let x2 = i16_f32(s.read_i16())
        let y2 = i16_f32(s.read_i16())
        painter.paint(
          Paint::LinearGradient({
            x0,
            y0,
            x1,
            y1,
            x2,
            y2,
            extend: color_line.extend,
            variation_data: self.variation_data(),
            color_line: NonVarColorLine(color_line),
          }),
        )
      }
      5 => {
        // PaintVarLinearGradient
        let var_color_line_offset : Offset24 = s.read()
        let color_line = req(
          self.parse_var_color_line(
            offset + var_color_line_offset.to_usize(),
            foreground_color,
          ),
        )
        let var_s = s.copy()
        var_s.advance(12)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(6, var_index_base, coords)
        let x0 = i16_f32(s.read_i16()) + deltas[0]
        let y0 = i16_f32(s.read_i16()) + deltas[1]
        let x1 = i16_f32(s.read_i16()) + deltas[2]
        let y1 = i16_f32(s.read_i16()) + deltas[3]
        let x2 = i16_f32(s.read_i16()) + deltas[4]
        let y2 = i16_f32(s.read_i16()) + deltas[5]
        painter.paint(
          Paint::LinearGradient({
            x0,
            y0,
            x1,
            y1,
            x2,
            y2,
            extend: color_line.extend,
            variation_data: self.variation_data(),
            color_line: VarColorLine(color_line),
          }),
        )
      }
      6 => {
        // PaintRadialGradient
        let color_line_offset : Offset24 = s.read()
        let color_line = req(
          self.parse_color_line(
            offset + color_line_offset.to_usize(),
            foreground_color,
          ),
        )
        let x0 = i16_f32(s.read_i16())
        let y0 = i16_f32(s.read_i16())
        let r0 = Float::from_int(s.read_u16().to_int())
        let x1 = i16_f32(s.read_i16())
        let y1 = i16_f32(s.read_i16())
        let r1 = Float::from_int(s.read_u16().to_int())
        painter.paint(
          Paint::RadialGradient({
            x0,
            y0,
            r0,
            x1,
            y1,
            r1,
            extend: color_line.extend,
            variation_data: self.variation_data(),
            color_line: NonVarColorLine(color_line),
          }),
        )
      }
      7 => {
        // PaintVarRadialGradient
        let color_line_offset : Offset24 = s.read()
        let color_line = req(
          self.parse_var_color_line(
            offset + color_line_offset.to_usize(),
            foreground_color,
          ),
        )
        let var_s = s.copy()
        var_s.advance(12)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(6, var_index_base, coords)
        let x0 = i16_f32(s.read_i16()) + deltas[0]
        let y0 = i16_f32(s.read_i16()) + deltas[1]
        let r0 = Float::from_int(s.read_u16().to_int()) + deltas[2]
        let x1 = i16_f32(s.read_i16()) + deltas[3]
        let y1 = i16_f32(s.read_i16()) + deltas[4]
        let r1 = Float::from_int(s.read_u16().to_int()) + deltas[5]
        painter.paint(
          Paint::RadialGradient({
            x0,
            y0,
            r0,
            x1,
            y1,
            r1,
            extend: color_line.extend,
            variation_data: self.variation_data(),
            color_line: VarColorLine(color_line),
          }),
        )
      }
      8 => {
        // PaintSweepGradient
        let color_line_offset : Offset24 = s.read()
        let color_line = req(
          self.parse_color_line(
            offset + color_line_offset.to_usize(),
            foreground_color,
          ),
        )
        let center_x = i16_f32(s.read_i16())
        let center_y = i16_f32(s.read_i16())
        let start_angle = s.read_f2dot14().to_f32()
        let end_angle = s.read_f2dot14().to_f32()
        painter.paint(
          Paint::SweepGradient({
            center_x,
            center_y,
            start_angle,
            end_angle,
            extend: color_line.extend,
            color_line: NonVarColorLine(color_line),
            variation_data: self.variation_data(),
          }),
        )
      }
      9 => {
        // PaintVarSweepGradient
        let color_line_offset : Offset24 = s.read()
        let color_line = req(
          self.parse_var_color_line(
            offset + color_line_offset.to_usize(),
            foreground_color,
          ),
        )
        let var_s = s.copy()
        var_s.advance(8)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(4, var_index_base, coords)
        let center_x = i16_f32(s.read_i16()) + deltas[0]
        let center_y = i16_f32(s.read_i16()) + deltas[1]
        let start_angle = s.read_f2dot14().apply_float_delta(deltas[2])
        let end_angle = s.read_f2dot14().apply_float_delta(deltas[3])
        painter.paint(
          Paint::SweepGradient({
            center_x,
            center_y,
            start_angle,
            end_angle,
            extend: color_line.extend,
            color_line: VarColorLine(color_line),
            variation_data: self.variation_data(),
          }),
        )
      }
      10 => {
        // PaintGlyph
        let paint_offset : Offset24 = s.read()
        let glyph_id : GlyphId = s.read()
        painter.outline_glyph(glyph_id)
        painter.push_clip()
        sub(offset + paint_offset.to_usize())
        painter.pop_clip()
      }
      11 => {
        // PaintColrGlyph
        let glyph_id : GlyphId = s.read()
        self.paint_impl(
          glyph_id, palette, painter, recursion_stack, coords, foreground_color,
        )
        |> ignore
      }
      12 => {
        // PaintTransform
        let paint_offset : Offset24 = s.read()
        let ts_offset : Offset24 = s.read()
        let s = Stream::new_at_r(self.data, offset + ts_offset.to_usize())
        let a = (s.read() : Fixed).0
        let b = (s.read() : Fixed).0
        let c = (s.read() : Fixed).0
        let d = (s.read() : Fixed).0
        let e = (s.read() : Fixed).0
        let f = (s.read() : Fixed).0
        let ts = Transform::new(a, b, c, d, e, f)
        painter.push_transform(ts)
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      13 => {
        // PaintVarTransform
        let paint_offset : Offset24 = s.read()
        let ts_offset : Offset24 = s.read()
        let s = Stream::new_at_r(self.data, offset + ts_offset.to_usize())
        let var_s = s.copy()
        var_s.advance(24)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(6, var_index_base, coords)
        let a = (s.read() : Fixed).apply_float_delta(deltas[0])
        let b = (s.read() : Fixed).apply_float_delta(deltas[1])
        let c = (s.read() : Fixed).apply_float_delta(deltas[2])
        let d = (s.read() : Fixed).apply_float_delta(deltas[3])
        let e = (s.read() : Fixed).apply_float_delta(deltas[4])
        let f = (s.read() : Fixed).apply_float_delta(deltas[5])
        let ts = Transform::new(a, b, c, d, e, f)
        painter.push_transform(ts)
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      14 => {
        // PaintTranslate
        let paint_offset : Offset24 = s.read()
        let tx = i16_f32(s.read_i16())
        let ty = i16_f32(s.read_i16())
        painter.push_transform(Transform::new_translate(tx, ty))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      15 => {
        // PaintVarTranslate
        let paint_offset : Offset24 = s.read()
        let var_s = s.copy()
        var_s.advance(4)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(2, var_index_base, coords)
        let tx = i16_f32(s.read_i16()) + deltas[0]
        let ty = i16_f32(s.read_i16()) + deltas[1]
        painter.push_transform(Transform::new_translate(tx, ty))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      16 => {
        // PaintScale
        let paint_offset : Offset24 = s.read()
        let sx = s.read_f2dot14().to_f32()
        let sy = s.read_f2dot14().to_f32()
        painter.push_transform(Transform::new_scale(sx, sy))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      17 => {
        // PaintVarScale
        let paint_offset : Offset24 = s.read()
        let var_s = s.copy()
        var_s.advance(4)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(2, var_index_base, coords)
        let sx = s.read_f2dot14().apply_float_delta(deltas[0])
        let sy = s.read_f2dot14().apply_float_delta(deltas[1])
        painter.push_transform(Transform::new_scale(sx, sy))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      18 => {
        // PaintScaleAroundCenter
        let paint_offset : Offset24 = s.read()
        let sx = s.read_f2dot14().to_f32()
        let sy = s.read_f2dot14().to_f32()
        let center_x = i16_f32(s.read_i16())
        let center_y = i16_f32(s.read_i16())
        painter.push_transform(Transform::new_translate(center_x, center_y))
        painter.push_transform(Transform::new_scale(sx, sy))
        painter.push_transform(Transform::new_translate(-center_x, -center_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
        painter.pop_transform()
        painter.pop_transform()
      }
      19 => {
        // PaintVarScaleAroundCenter
        let paint_offset : Offset24 = s.read()
        let var_s = s.copy()
        var_s.advance(8)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(4, var_index_base, coords)
        let sx = s.read_f2dot14().apply_float_delta(deltas[0])
        let sy = s.read_f2dot14().apply_float_delta(deltas[1])
        let center_x = i16_f32(s.read_i16()) + deltas[2]
        let center_y = i16_f32(s.read_i16()) + deltas[3]
        painter.push_transform(Transform::new_translate(center_x, center_y))
        painter.push_transform(Transform::new_scale(sx, sy))
        painter.push_transform(Transform::new_translate(-center_x, -center_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
        painter.pop_transform()
        painter.pop_transform()
      }
      20 => {
        // PaintScaleUniform
        let paint_offset : Offset24 = s.read()
        let scale = s.read_f2dot14().to_f32()
        painter.push_transform(Transform::new_scale(scale, scale))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      21 => {
        // PaintVarScaleUniform
        let paint_offset : Offset24 = s.read()
        let var_s = s.copy()
        var_s.advance(2)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(1, var_index_base, coords)
        let scale = s.read_f2dot14().apply_float_delta(deltas[0])
        painter.push_transform(Transform::new_scale(scale, scale))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      22 => {
        // PaintScaleUniformAroundCenter
        let paint_offset : Offset24 = s.read()
        let scale = s.read_f2dot14().to_f32()
        let center_x = i16_f32(s.read_i16())
        let center_y = i16_f32(s.read_i16())
        painter.push_transform(Transform::new_translate(center_x, center_y))
        painter.push_transform(Transform::new_scale(scale, scale))
        painter.push_transform(Transform::new_translate(-center_x, -center_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
        painter.pop_transform()
        painter.pop_transform()
      }
      23 => {
        // PaintVarScaleUniformAroundCenter
        let paint_offset : Offset24 = s.read()
        let var_s = s.copy()
        var_s.advance(6)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(3, var_index_base, coords)
        let scale = s.read_f2dot14().apply_float_delta(deltas[0])
        let center_x = i16_f32(s.read_i16()) + deltas[1]
        let center_y = i16_f32(s.read_i16()) + deltas[2]
        painter.push_transform(Transform::new_translate(center_x, center_y))
        painter.push_transform(Transform::new_scale(scale, scale))
        painter.push_transform(Transform::new_translate(-center_x, -center_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
        painter.pop_transform()
        painter.pop_transform()
      }
      24 => {
        // PaintRotate
        let paint_offset : Offset24 = s.read()
        let angle = s.read_f2dot14().to_f32()
        painter.push_transform(Transform::new_rotate(angle))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      25 => {
        // PaintVarRotate
        let paint_offset : Offset24 = s.read()
        let var_s = s.copy()
        var_s.advance(2)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(1, var_index_base, coords)
        let angle = s.read_f2dot14().apply_float_delta(deltas[0])
        painter.push_transform(Transform::new_rotate(angle))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      26 => {
        // PaintRotateAroundCenter
        let paint_offset : Offset24 = s.read()
        let angle = s.read_f2dot14().to_f32()
        let center_x = i16_f32(s.read_i16())
        let center_y = i16_f32(s.read_i16())
        painter.push_transform(Transform::new_translate(center_x, center_y))
        painter.push_transform(Transform::new_rotate(angle))
        painter.push_transform(Transform::new_translate(-center_x, -center_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
        painter.pop_transform()
        painter.pop_transform()
      }
      27 => {
        // PaintVarRotateAroundCenter
        let paint_offset : Offset24 = s.read()
        let var_s = s.copy()
        var_s.advance(6)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(3, var_index_base, coords)
        let angle = s.read_f2dot14().apply_float_delta(deltas[0])
        let center_x = i16_f32(s.read_i16()) + deltas[1]
        let center_y = i16_f32(s.read_i16()) + deltas[2]
        painter.push_transform(Transform::new_translate(center_x, center_y))
        painter.push_transform(Transform::new_rotate(angle))
        painter.push_transform(Transform::new_translate(-center_x, -center_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
        painter.pop_transform()
        painter.pop_transform()
      }
      28 => {
        // PaintSkew
        let paint_offset : Offset24 = s.read()
        let skew_x = s.read_f2dot14().to_f32()
        let skew_y = s.read_f2dot14().to_f32()
        painter.push_transform(Transform::new_skew(skew_x, skew_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      29 => {
        // PaintVarSkew
        let paint_offset : Offset24 = s.read()
        let var_s = s.copy()
        var_s.advance(4)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(2, var_index_base, coords)
        let skew_x = s.read_f2dot14().apply_float_delta(deltas[0])
        let skew_y = s.read_f2dot14().apply_float_delta(deltas[1])
        painter.push_transform(Transform::new_skew(skew_x, skew_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
      }
      30 => {
        // PaintSkewAroundCenter
        let paint_offset : Offset24 = s.read()
        let skew_x = s.read_f2dot14().to_f32()
        let skew_y = s.read_f2dot14().to_f32()
        let center_x = i16_f32(s.read_i16())
        let center_y = i16_f32(s.read_i16())
        painter.push_transform(Transform::new_translate(center_x, center_y))
        painter.push_transform(Transform::new_skew(skew_x, skew_y))
        painter.push_transform(Transform::new_translate(-center_x, -center_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
        painter.pop_transform()
        painter.pop_transform()
      }
      31 => {
        // PaintVarSkewAroundCenter
        let paint_offset : Offset24 = s.read()
        let var_s = s.copy()
        var_s.advance(8)
        let var_index_base = var_s.read_u32()
        let deltas = self
          .variation_data()
          .read_deltas(4, var_index_base, coords)
        let skew_x = s.read_f2dot14().apply_float_delta(deltas[0])
        let skew_y = s.read_f2dot14().apply_float_delta(deltas[1])
        let center_x = i16_f32(s.read_i16()) + deltas[2]
        let center_y = i16_f32(s.read_i16()) + deltas[3]
        painter.push_transform(Transform::new_translate(center_x, center_y))
        painter.push_transform(Transform::new_skew(skew_x, skew_y))
        painter.push_transform(Transform::new_translate(-center_x, -center_y))
        sub(offset + paint_offset.to_usize())
        painter.pop_transform()
        painter.pop_transform()
        painter.pop_transform()
      }
      32 => {
        // PaintComposite
        let source_paint_offset : Offset24 = s.read()
        let composite_mode : CompositeMode = s.read()
        let backdrop_paint_offset : Offset24 = s.read()
        painter.push_layer(SourceOver)
        sub(offset + backdrop_paint_offset.to_usize())
        painter.push_layer(composite_mode)
        sub(offset + source_paint_offset.to_usize())
        painter.pop_layer()
        painter.pop_layer()
      }
      _ => ()
    }
    Some(())
  } catch {
    _ => None
  }
}

///|
fn ColrTable::parse_color_line(
  self : ColrTable,
  offset : Int,
  foreground_color : RgbaColor,
) -> NonVarColorLine? {
  try {
    let s = Stream::new_at_r(self.data, offset)
    let extend : GradientExtend = s.read()
    let count = s.read_u16()
    let colors = s.read_array16(count)
    Some({ extend, colors, foreground_color, palettes: self.palettes, })
  } catch {
    _ => None
  }
}

///|
fn ColrTable::parse_var_color_line(
  self : ColrTable,
  offset : Int,
  foreground_color : RgbaColor,
) -> VarColorLine? {
  try {
    let s = Stream::new_at_r(self.data, offset)
    let extend : GradientExtend = s.read()
    let count = s.read_u16()
    let colors = s.read_array16(count)
    Some({ extend, colors, foreground_color, palettes: self.palettes, })
  } catch {
    _ => None
  }
}

///|
priv struct RecursionStack {
  // The limit of 64 is chosen arbitrarily and not from the spec. But we have to stop somewhere...
  stack : FixedArray[Int]
  mut len : Int
}

///|
fn RecursionStack::new() -> RecursionStack {
  { stack: FixedArray::make(64, 0), len: 0, }
}

///|
fn RecursionStack::is_empty(self : RecursionStack) -> Bool {
  self.len == 0
}

///|
/// Returns `false` when the stack is full (upstream's `Err(())`).
fn RecursionStack::push(self : RecursionStack, offset : Int) -> Bool {
  if self.len == self.stack.length() {
    false
  } else {
    self.stack[self.len] = offset
    self.len += 1
    true
  }
}

///|
fn RecursionStack::contains(self : RecursionStack, offset : Int) -> Bool {
  for i in 0..<self.len {
    if self.stack[i] == offset {
      return true
    }
  }
  false
}

///|
fn RecursionStack::pop(self : RecursionStack) -> Unit {
  // `debug_assert!(!self.is_empty())`
  self.len -= 1
}

///|
/// `colr::VariationData`.
struct ColrVariationData {
  variation_store : ItemVariationStore?
  delta_map : DeltaSetIndexMap?
}

///|
impl Default for ColrVariationData with fn default() {
  { variation_store: None, delta_map: None, }
}

///|
// Inspired from `fontations`.
fn ColrVariationData::read_deltas(
  self : ColrVariationData,
  n : Int,
  var_index_base : UInt,
  coordinates : ArrayView[NormalizedCoordinate],
) -> FixedArray[Float] {
  let no_variation_deltas : UInt = 0xFFFFFFFF
  let deltas : FixedArray[Float] = FixedArray::make(n, 0.0)
  guard self.variation_store is Some(variation_store) &&
    !coordinates.is_empty() &&
    var_index_base != no_variation_deltas else {
    return deltas
  }
  for i in 0..<n {
    deltas[i] = match self.delta_map {
      Some(d) =>
        match d.map(var_index_base + i.reinterpret_as_uint()) {
          Some((outer, inner)) =>
            variation_store
            .parse_delta(outer, inner, coordinates)
            .unwrap_or(0.0)
          None => 0.0
        }
      None => 0.0
    }
  }
  deltas
}
