// A [Math Table](https://docs.microsoft.com/en-us/typography/opentype/spec/math) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/math.rs`. Generic upstream names
// get a `Math` prefix: `Table` -> `MathTable`, `Constants` ->
// `MathConstants`, `Kern` -> `MathKern`, `KernInfo(s)` -> `MathKernInfo(s)`,
// `GlyphInfo` -> `MathGlyphInfo`, `Variants` -> `MathVariants`.

///|
/// A [Math Value](https://docs.microsoft.com/en-us/typography/opentype/spec/math#mathvaluerecord)
/// with optional device corrections.
pub(all) struct MathValue {
  /// The X or Y value in font design units.
  value : Int16
  /// Device corrections for this value.
  device : Device?
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathValue with @debug.Debug::{to_repr}

///|
fn MathValue::parse(data : BytesView, parent : BytesView) -> MathValue? {
  let record : MathValueRecord = FromData::parse(data) catch {
    _ => return None
  }
  Some(record.get(parent))
}

///|
/// A math value record with unresolved offset.
priv struct MathValueRecord {
  value : Int16
  device_offset : Offset16?
}

///|
impl FromData for MathValueRecord with fn size() {
  4
}

///|
impl FromData for MathValueRecord with fn parse(data) {
  let s = Stream::new(data)
  let value = s.read_i16()
  let device_offset : Offset16? = s.read()
  { value, device_offset, }
}

///|
fn MathValueRecord::get(self : MathValueRecord, data : BytesView) -> MathValue {
  let device = match self.device_offset {
    Some(offset) =>
      match slice_from(data, offset.to_usize()) {
        Some(data) => Device::parse(data)
        None => None
      }
    None => None
  }
  { value: self.value, device, }
}

///|
/// A mapping from glyphs to
/// [Math Values](https://docs.microsoft.com/en-us/typography/opentype/spec/math#mathvaluerecord).
struct MathValues {
  data : BytesView
  coverage : Coverage
  records : LazyArray16[MathValueRecord]
}

///|
pub impl FromSlice for MathValues with fn parse_slice(data) {
  let s = Stream::new(data)
  let coverage : Coverage = req(math_parse_at_offset16(s, data))
  let count = s.read_u16()
  let records = s.read_array16(count)
  { data, coverage, records, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathValues with FromSlice::{parse_slice}

///|
/// Returns the value for the glyph or `None` if it is not covered.
pub fn MathValues::get(self : MathValues, glyph : GlyphId) -> MathValue? {
  guard self.coverage.get(glyph) is Some(index) else { return None }
  guard self.records.get(index) is Some(record) else { return None }
  Some(record.get(self.data))
}

///|
pub impl Debug for MathValues with fn to_repr(_) {
  Repr::literal("MathValues { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathValues with @debug.Debug::{to_repr}

///|
/// A [Math Constants Table](https://learn.microsoft.com/en-us/typography/opentype/spec/math#mathconstants-table).
struct MathConstants {
  data : BytesView
}

///|
pub impl FromSlice for MathConstants with fn parse_slice(data) {
  { data, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathConstants with FromSlice::{parse_slice}

///|
pub impl Debug for MathConstants with fn to_repr(_) {
  Repr::literal("Constants { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathConstants with @debug.Debug::{to_repr}

///|
/// Read an `i16` at an offset into the table.
fn MathConstants::read_i16(self : MathConstants, offset : Int) -> Int16 {
  (Stream::read_at(self.data, offset) : Int16) catch {
    _ => 0
  }
}

///|
/// Read an `u16` at an offset into the table.
fn MathConstants::read_u16(self : MathConstants, offset : Int) -> UInt16 {
  (Stream::read_at(self.data, offset) : UInt16) catch {
    _ => 0
  }
}

///|
/// Read a `MathValueRecord` at an offset into the table.
fn MathConstants::read_record(self : MathConstants, offset : Int) -> MathValue {
  let v = match slice_from(self.data, offset) {
    Some(data) => MathValue::parse(data, self.data)
    None => None
  }
  v.unwrap_or({ value: 0, device: None, })
}

///|
const SCRIPT_PERCENT_SCALE_DOWN_OFFSET : Int = 0

///|
const SCRIPT_SCRIPT_PERCENT_SCALE_DOWN_OFFSET : Int = 2

///|
const DELIMITED_SUB_FORMULA_MIN_HEIGHT_OFFSET : Int = 4

///|
const DISPLAY_OPERATOR_MIN_HEIGHT_OFFSET : Int = 6

///|
const MATH_LEADING_OFFSET : Int = 8

///|
const AXIS_HEIGHT_OFFSET : Int = 12

///|
const ACCENT_BASE_HEIGHT_OFFSET : Int = 16

///|
const FLATTENED_ACCENT_BASE_HEIGHT_OFFSET : Int = 20

///|
const SUBSCRIPT_SHIFT_DOWN_OFFSET : Int = 24

///|
const SUBSCRIPT_TOP_MAX_OFFSET : Int = 28

///|
const SUBSCRIPT_BASELINE_DROP_MIN_OFFSET : Int = 32

///|
const SUPERSCRIPT_SHIFT_UP_OFFSET : Int = 36

///|
const SUPERSCRIPT_SHIFT_UP_CRAMPED_OFFSET : Int = 40

///|
const SUPERSCRIPT_BOTTOM_MIN_OFFSET : Int = 44

///|
const SUPERSCRIPT_BASELINE_DROP_MAX_OFFSET : Int = 48

///|
const SUB_SUPERSCRIPT_GAP_MIN_OFFSET : Int = 52

///|
const SUPERSCRIPT_BOTTOM_MAX_WITH_SUBSCRIPT_OFFSET : Int = 56

///|
const SPACE_AFTER_SCRIPT_OFFSET : Int = 60

///|
const UPPER_LIMIT_GAP_MIN_OFFSET : Int = 64

///|
const UPPER_LIMIT_BASELINE_RISE_MIN_OFFSET : Int = 68

///|
const LOWER_LIMIT_GAP_MIN_OFFSET : Int = 72

///|
const LOWER_LIMIT_BASELINE_DROP_MIN_OFFSET : Int = 76

///|
const STACK_TOP_SHIFT_UP_OFFSET : Int = 80

///|
const STACK_TOP_DISPLAY_STYLE_SHIFT_UP_OFFSET : Int = 84

///|
const STACK_BOTTOM_SHIFT_DOWN_OFFSET : Int = 88

///|
const STACK_BOTTOM_DISPLAY_STYLE_SHIFT_DOWN_OFFSET : Int = 92

///|
const STACK_GAP_MIN_OFFSET : Int = 96

///|
const STACK_DISPLAY_STYLE_GAP_MIN_OFFSET : Int = 100

///|
const STRETCH_STACK_TOP_SHIFT_UP_OFFSET : Int = 104

///|
const STRETCH_STACK_BOTTOM_SHIFT_DOWN_OFFSET : Int = 108

///|
const STRETCH_STACK_GAP_ABOVE_MIN_OFFSET : Int = 112

///|
const STRETCH_STACK_GAP_BELOW_MIN_OFFSET : Int = 116

///|
const FRACTION_NUMERATOR_SHIFT_UP_OFFSET : Int = 120

///|
const FRACTION_NUMERATOR_DISPLAY_STYLE_SHIFT_UP_OFFSET : Int = 124

///|
const FRACTION_DENOMINATOR_SHIFT_DOWN_OFFSET : Int = 128

///|
const FRACTION_DENOMINATOR_DISPLAY_STYLE_SHIFT_DOWN_OFFSET : Int = 132

///|
const FRACTION_NUMERATOR_GAP_MIN_OFFSET : Int = 136

///|
const FRACTION_NUM_DISPLAY_STYLE_GAP_MIN_OFFSET : Int = 140

///|
const FRACTION_RULE_THICKNESS_OFFSET : Int = 144

///|
const FRACTION_DENOMINATOR_GAP_MIN_OFFSET : Int = 148

///|
const FRACTION_DENOM_DISPLAY_STYLE_GAP_MIN_OFFSET : Int = 152

///|
const SKEWED_FRACTION_HORIZONTAL_GAP_OFFSET : Int = 156

///|
const SKEWED_FRACTION_VERTICAL_GAP_OFFSET : Int = 160

///|
const OVERBAR_VERTICAL_GAP_OFFSET : Int = 164

///|
const OVERBAR_RULE_THICKNESS_OFFSET : Int = 168

///|
const OVERBAR_EXTRA_ASCENDER_OFFSET : Int = 172

///|
const UNDERBAR_VERTICAL_GAP_OFFSET : Int = 176

///|
const UNDERBAR_RULE_THICKNESS_OFFSET : Int = 180

///|
const UNDERBAR_EXTRA_DESCENDER_OFFSET : Int = 184

///|
const RADICAL_VERTICAL_GAP_OFFSET : Int = 188

///|
const RADICAL_DISPLAY_STYLE_VERTICAL_GAP_OFFSET : Int = 192

///|
const RADICAL_RULE_THICKNESS_OFFSET : Int = 196

///|
const RADICAL_EXTRA_ASCENDER_OFFSET : Int = 200

///|
const RADICAL_KERN_BEFORE_DEGREE_OFFSET : Int = 204

///|
const RADICAL_KERN_AFTER_DEGREE_OFFSET : Int = 208

///|
const RADICAL_DEGREE_BOTTOM_RAISE_PERCENT_OFFSET : Int = 212

///|
/// Percentage of scaling down for level 1 superscripts and subscripts.
pub fn MathConstants::script_percent_scale_down(self : MathConstants) -> Int16 {
  self.read_i16(SCRIPT_PERCENT_SCALE_DOWN_OFFSET)
}

///|
/// Percentage of scaling down for level 2 (scriptScript) superscripts and subscripts.
pub fn MathConstants::script_script_percent_scale_down(
  self : MathConstants,
) -> Int16 {
  self.read_i16(SCRIPT_SCRIPT_PERCENT_SCALE_DOWN_OFFSET)
}

///|
/// Minimum height required for a delimited expression (contained within parentheses, etc.) to
/// be treated as a sub-formula.
pub fn MathConstants::delimited_sub_formula_min_height(
  self : MathConstants,
) -> UInt16 {
  self.read_u16(DELIMITED_SUB_FORMULA_MIN_HEIGHT_OFFSET)
}

///|
/// Minimum height of n-ary operators (such as integral and summation) for formulas in display
/// mode (that is, appearing as standalone page elements, not embedded inline within text).
pub fn MathConstants::display_operator_min_height(
  self : MathConstants,
) -> UInt16 {
  self.read_u16(DISPLAY_OPERATOR_MIN_HEIGHT_OFFSET)
}

///|
/// White space to be left between math formulas to ensure proper line spacing.
pub fn MathConstants::math_leading(self : MathConstants) -> MathValue {
  self.read_record(MATH_LEADING_OFFSET)
}

///|
/// Axis height of the font.
pub fn MathConstants::axis_height(self : MathConstants) -> MathValue {
  self.read_record(AXIS_HEIGHT_OFFSET)
}

///|
/// Maximum (ink) height of accent base that does not require raising the accents.
pub fn MathConstants::accent_base_height(self : MathConstants) -> MathValue {
  self.read_record(ACCENT_BASE_HEIGHT_OFFSET)
}

///|
/// Maximum (ink) height of accent base that does not require flattening the accents.
pub fn MathConstants::flattened_accent_base_height(
  self : MathConstants,
) -> MathValue {
  self.read_record(FLATTENED_ACCENT_BASE_HEIGHT_OFFSET)
}

///|
/// The standard shift down applied to subscript elements.
pub fn MathConstants::subscript_shift_down(self : MathConstants) -> MathValue {
  self.read_record(SUBSCRIPT_SHIFT_DOWN_OFFSET)
}

///|
/// Maximum allowed height of the (ink) top of subscripts that does not require moving
/// subscripts further down.
pub fn MathConstants::subscript_top_max(self : MathConstants) -> MathValue {
  self.read_record(SUBSCRIPT_TOP_MAX_OFFSET)
}

///|
/// Minimum allowed drop of the baseline of subscripts relative to the (ink) bottom of the
/// base.
pub fn MathConstants::subscript_baseline_drop_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(SUBSCRIPT_BASELINE_DROP_MIN_OFFSET)
}

///|
/// Standard shift up applied to superscript elements.
pub fn MathConstants::superscript_shift_up(self : MathConstants) -> MathValue {
  self.read_record(SUPERSCRIPT_SHIFT_UP_OFFSET)
}

///|
/// Standard shift of superscripts relative to the base, in cramped style.
pub fn MathConstants::superscript_shift_up_cramped(
  self : MathConstants,
) -> MathValue {
  self.read_record(SUPERSCRIPT_SHIFT_UP_CRAMPED_OFFSET)
}

///|
/// Minimum allowed height of the (ink) bottom of superscripts that does not require moving
/// subscripts further up.
pub fn MathConstants::superscript_bottom_min(self : MathConstants) -> MathValue {
  self.read_record(SUPERSCRIPT_BOTTOM_MIN_OFFSET)
}

///|
/// Maximum allowed drop of the baseline of superscripts relative to the (ink) top of the
/// base.
pub fn MathConstants::superscript_baseline_drop_max(
  self : MathConstants,
) -> MathValue {
  self.read_record(SUPERSCRIPT_BASELINE_DROP_MAX_OFFSET)
}

///|
/// Minimum gap between the superscript and subscript ink.
pub fn MathConstants::sub_superscript_gap_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(SUB_SUPERSCRIPT_GAP_MIN_OFFSET)
}

///|
/// The maximum level to which the (ink) bottom of superscript can be pushed to increase the
/// gap between superscript and subscript, before subscript starts being moved down.
pub fn MathConstants::superscript_bottom_max_with_subscript(
  self : MathConstants,
) -> MathValue {
  self.read_record(SUPERSCRIPT_BOTTOM_MAX_WITH_SUBSCRIPT_OFFSET)
}

///|
/// Extra white space to be added after each subscript and superscript.
pub fn MathConstants::space_after_script(self : MathConstants) -> MathValue {
  self.read_record(SPACE_AFTER_SCRIPT_OFFSET)
}

///|
/// Minimum gap between the (ink) bottom of the upper limit, and the (ink) top of the base
/// operator.
pub fn MathConstants::upper_limit_gap_min(self : MathConstants) -> MathValue {
  self.read_record(UPPER_LIMIT_GAP_MIN_OFFSET)
}

///|
/// Minimum distance between baseline of upper limit and (ink) top of the base operator.
pub fn MathConstants::upper_limit_baseline_rise_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(UPPER_LIMIT_BASELINE_RISE_MIN_OFFSET)
}

///|
/// Minimum gap between (ink) top of the lower limit, and (ink) bottom of the base operator.
pub fn MathConstants::lower_limit_gap_min(self : MathConstants) -> MathValue {
  self.read_record(LOWER_LIMIT_GAP_MIN_OFFSET)
}

///|
/// Minimum distance between baseline of the lower limit and (ink) bottom of the base operator.
pub fn MathConstants::lower_limit_baseline_drop_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(LOWER_LIMIT_BASELINE_DROP_MIN_OFFSET)
}

///|
/// Standard shift up applied to the top element of a stack.
pub fn MathConstants::stack_top_shift_up(self : MathConstants) -> MathValue {
  self.read_record(STACK_TOP_SHIFT_UP_OFFSET)
}

///|
/// Standard shift up applied to the top element of a stack in display style.
pub fn MathConstants::stack_top_display_style_shift_up(
  self : MathConstants,
) -> MathValue {
  self.read_record(STACK_TOP_DISPLAY_STYLE_SHIFT_UP_OFFSET)
}

///|
/// Standard shift down applied to the bottom element of a stack.
pub fn MathConstants::stack_bottom_shift_down(
  self : MathConstants,
) -> MathValue {
  self.read_record(STACK_BOTTOM_SHIFT_DOWN_OFFSET)
}

///|
/// Standard shift down applied to the bottom element of a stack in display style.
pub fn MathConstants::stack_bottom_display_style_shift_down(
  self : MathConstants,
) -> MathValue {
  self.read_record(STACK_BOTTOM_DISPLAY_STYLE_SHIFT_DOWN_OFFSET)
}

///|
/// Minimum gap between (ink) bottom of the top element of a stack, and the (ink) top of the
/// bottom element.
pub fn MathConstants::stack_gap_min(self : MathConstants) -> MathValue {
  self.read_record(STACK_GAP_MIN_OFFSET)
}

///|
/// Minimum gap between (ink) bottom of the top element of a stack, and the (ink) top of the
/// bottom element in display style.
pub fn MathConstants::stack_display_style_gap_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(STACK_DISPLAY_STYLE_GAP_MIN_OFFSET)
}

///|
/// Standard shift up applied to the top element of the stretch stack.
pub fn MathConstants::stretch_stack_top_shift_up(
  self : MathConstants,
) -> MathValue {
  self.read_record(STRETCH_STACK_TOP_SHIFT_UP_OFFSET)
}

///|
/// Standard shift down applied to the bottom element of the stretch stack.
pub fn MathConstants::stretch_stack_bottom_shift_down(
  self : MathConstants,
) -> MathValue {
  self.read_record(STRETCH_STACK_BOTTOM_SHIFT_DOWN_OFFSET)
}

///|
/// Minimum gap between the ink of the stretched element, and the (ink) bottom of the element above.
pub fn MathConstants::stretch_stack_gap_above_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(STRETCH_STACK_GAP_ABOVE_MIN_OFFSET)
}

///|
/// Minimum gap between the ink of the stretched element, and the (ink) top of the element below.
pub fn MathConstants::stretch_stack_gap_below_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(STRETCH_STACK_GAP_BELOW_MIN_OFFSET)
}

///|
/// Standard shift up applied to the numerator.
pub fn MathConstants::fraction_numerator_shift_up(
  self : MathConstants,
) -> MathValue {
  self.read_record(FRACTION_NUMERATOR_SHIFT_UP_OFFSET)
}

///|
/// Standard shift up applied to the numerator in display style.
pub fn MathConstants::fraction_numerator_display_style_shift_up(
  self : MathConstants,
) -> MathValue {
  self.read_record(FRACTION_NUMERATOR_DISPLAY_STYLE_SHIFT_UP_OFFSET)
}

///|
/// Standard shift down applied to the denominator.
pub fn MathConstants::fraction_denominator_shift_down(
  self : MathConstants,
) -> MathValue {
  self.read_record(FRACTION_DENOMINATOR_SHIFT_DOWN_OFFSET)
}

///|
/// Standard shift down applied to the denominator in display style.
pub fn MathConstants::fraction_denominator_display_style_shift_down(
  self : MathConstants,
) -> MathValue {
  self.read_record(FRACTION_DENOMINATOR_DISPLAY_STYLE_SHIFT_DOWN_OFFSET)
}

///|
/// Minimum tolerated gap between the (ink) bottom of the numerator and the ink of the
/// fraction bar.
pub fn MathConstants::fraction_numerator_gap_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(FRACTION_NUMERATOR_GAP_MIN_OFFSET)
}

///|
/// Minimum tolerated gap between the (ink) bottom of the numerator and the ink of the
/// fraction bar in display style.
pub fn MathConstants::fraction_num_display_style_gap_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(FRACTION_NUM_DISPLAY_STYLE_GAP_MIN_OFFSET)
}

///|
/// Thickness of the fraction bar.
pub fn MathConstants::fraction_rule_thickness(
  self : MathConstants,
) -> MathValue {
  self.read_record(FRACTION_RULE_THICKNESS_OFFSET)
}

///|
/// Minimum tolerated gap between the (ink) top of the denominator and the ink of the fraction bar.
pub fn MathConstants::fraction_denominator_gap_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(FRACTION_DENOMINATOR_GAP_MIN_OFFSET)
}

///|
/// Minimum tolerated gap between the (ink) top of the denominator and the ink of the fraction
/// bar in display style.
pub fn MathConstants::fraction_denom_display_style_gap_min(
  self : MathConstants,
) -> MathValue {
  self.read_record(FRACTION_DENOM_DISPLAY_STYLE_GAP_MIN_OFFSET)
}

///|
/// Horizontal distance between the top and bottom elements of a skewed fraction.
pub fn MathConstants::skewed_fraction_horizontal_gap(
  self : MathConstants,
) -> MathValue {
  self.read_record(SKEWED_FRACTION_HORIZONTAL_GAP_OFFSET)
}

///|
/// Vertical distance between the ink of the top and bottom elements of a skewed fraction.
pub fn MathConstants::skewed_fraction_vertical_gap(
  self : MathConstants,
) -> MathValue {
  self.read_record(SKEWED_FRACTION_VERTICAL_GAP_OFFSET)
}

///|
/// Distance between the overbar and the (ink) top of he base.
pub fn MathConstants::overbar_vertical_gap(self : MathConstants) -> MathValue {
  self.read_record(OVERBAR_VERTICAL_GAP_OFFSET)
}

///|
/// Thickness of overbar.
pub fn MathConstants::overbar_rule_thickness(self : MathConstants) -> MathValue {
  self.read_record(OVERBAR_RULE_THICKNESS_OFFSET)
}

///|
/// Extra white space reserved above the overbar.
pub fn MathConstants::overbar_extra_ascender(self : MathConstants) -> MathValue {
  self.read_record(OVERBAR_EXTRA_ASCENDER_OFFSET)
}

///|
/// Distance between underbar and (ink) bottom of the base.
pub fn MathConstants::underbar_vertical_gap(self : MathConstants) -> MathValue {
  self.read_record(UNDERBAR_VERTICAL_GAP_OFFSET)
}

///|
/// Thickness of underbar.
pub fn MathConstants::underbar_rule_thickness(
  self : MathConstants,
) -> MathValue {
  self.read_record(UNDERBAR_RULE_THICKNESS_OFFSET)
}

///|
/// Extra white space reserved below the underbar.
pub fn MathConstants::underbar_extra_descender(
  self : MathConstants,
) -> MathValue {
  self.read_record(UNDERBAR_EXTRA_DESCENDER_OFFSET)
}

///|
/// Space between the (ink) top of the expression and the bar over it.
pub fn MathConstants::radical_vertical_gap(self : MathConstants) -> MathValue {
  self.read_record(RADICAL_VERTICAL_GAP_OFFSET)
}

///|
/// Space between the (ink) top of the expression and the bar over it.
pub fn MathConstants::radical_display_style_vertical_gap(
  self : MathConstants,
) -> MathValue {
  self.read_record(RADICAL_DISPLAY_STYLE_VERTICAL_GAP_OFFSET)
}

///|
/// Thickness of the radical rule.
pub fn MathConstants::radical_rule_thickness(self : MathConstants) -> MathValue {
  self.read_record(RADICAL_RULE_THICKNESS_OFFSET)
}

///|
/// Extra white space reserved above the radical.
pub fn MathConstants::radical_extra_ascender(self : MathConstants) -> MathValue {
  self.read_record(RADICAL_EXTRA_ASCENDER_OFFSET)
}

///|
/// Extra horizontal kern before the degree of a radical, if such is present.
pub fn MathConstants::radical_kern_before_degree(
  self : MathConstants,
) -> MathValue {
  self.read_record(RADICAL_KERN_BEFORE_DEGREE_OFFSET)
}

///|
/// Negative kern after the degree of a radical, if such is present.
pub fn MathConstants::radical_kern_after_degree(
  self : MathConstants,
) -> MathValue {
  self.read_record(RADICAL_KERN_AFTER_DEGREE_OFFSET)
}

///|
/// Height of the bottom of the radical degree, if such is present, in proportion to the
/// ascender of the radical sign.
pub fn MathConstants::radical_degree_bottom_raise_percent(
  self : MathConstants,
) -> Int16 {
  self.read_i16(RADICAL_DEGREE_BOTTOM_RAISE_PERCENT_OFFSET)
}

///|
/// A [Math Kern Table](https://learn.microsoft.com/en-us/typography/opentype/spec/math#mathkern-table).
struct MathKern {
  data : BytesView
  heights : LazyArray16[MathValueRecord]
  kerns : LazyArray16[MathValueRecord]
}

///|
/// Number of heights at which the kern value changes.
pub fn MathKern::count(self : MathKern) -> UInt16 {
  self.heights.len()
}

///|
/// The correction height at the given index.
///
/// The index must be smaller than `count()`.
pub fn MathKern::height(self : MathKern, index : UInt16) -> MathValue? {
  guard self.heights.get(index) is Some(record) else { return None }
  Some(record.get(self.data))
}

///|
/// The kern value at the given index.
///
/// The index must be smaller than or equal to `count()`.
pub fn MathKern::kern(self : MathKern, index : UInt16) -> MathValue? {
  guard self.kerns.get(index) is Some(record) else { return None }
  Some(record.get(self.data))
}

///|
pub impl FromSlice for MathKern with fn parse_slice(data) {
  let s = Stream::new(data)
  let count = s.read_u16()
  let heights = s.read_array16(count)
  // Wrapping u16 arithmetic, like upstream in release mode.
  let kerns = s.read_array16(count + 1)
  { data, heights, kerns, }
}

///|
pub extend MathKern with FromSlice::{parse_slice}

///|
pub impl Debug for MathKern with fn to_repr(_) {
  Repr::literal("Kern { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathKern with @debug.Debug::{to_repr}

///|
priv struct MathKernInfoRecord {
  top_right : Offset16?
  top_left : Offset16?
  bottom_right : Offset16?
  bottom_left : Offset16?
}

///|
impl FromData for MathKernInfoRecord with fn size() {
  8
}

///|
impl FromData for MathKernInfoRecord with fn parse(data) {
  let s = Stream::new(data)
  {
    top_right: s.read(),
    top_left: s.read(),
    bottom_right: s.read(),
    bottom_left: s.read(),
  }
}

///|
fn MathKernInfoRecord::get(
  self : MathKernInfoRecord,
  data : BytesView,
) -> MathKernInfo {
  let parse_field = (offset : Offset16?) => {
    guard offset is Some(offset) else { return None }
    guard slice_from(data, offset.to_usize()) is Some(data) else { return None }
    opt(() => MathKern::parse_slice(data))
  }
  {
    top_right: parse_field(self.top_right),
    top_left: parse_field(self.top_left),
    bottom_right: parse_field(self.bottom_right),
    bottom_left: parse_field(self.bottom_left),
  }
}

///|
/// An [entry in a Math Kern Info Table](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/math#mathkerninforecord).
pub(all) struct MathKernInfo {
  /// The kerning data for the top-right corner.
  top_right : MathKern?
  /// The kerning data for the top-left corner.
  top_left : MathKern?
  /// The kerning data for the bottom-right corner.
  bottom_right : MathKern?
  /// The kerning data for the bottom-left corner.
  bottom_left : MathKern?
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathKernInfo with @debug.Debug::{to_repr}

///|
/// A [Math Kern Info Table](https://docs.microsoft.com/en-us/typography/opentype/spec/math#mathkerninfo-table).
struct MathKernInfos {
  data : BytesView
  coverage : Coverage
  records : LazyArray16[MathKernInfoRecord]
}

///|
pub impl FromSlice for MathKernInfos with fn parse_slice(data) {
  let s = Stream::new(data)
  let coverage : Coverage = req(math_parse_at_offset16(s, data))
  let count = s.read_u16()
  let records = s.read_array16(count)
  { data, coverage, records, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathKernInfos with FromSlice::{parse_slice}

///|
/// Returns the kerning info for the glyph or `None` if it is not covered.
pub fn MathKernInfos::get(
  self : MathKernInfos,
  glyph : GlyphId,
) -> MathKernInfo? {
  guard self.coverage.get(glyph) is Some(index) else { return None }
  guard self.records.get(index) is Some(record) else { return None }
  Some(record.get(self.data))
}

///|
pub impl Debug for MathKernInfos with fn to_repr(_) {
  Repr::literal("KernInfos { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathKernInfos with @debug.Debug::{to_repr}

///|
/// A [Math Glyph Info Table](https://learn.microsoft.com/en-us/typography/opentype/spec/math#mathglyphinfo-table).
pub(all) struct MathGlyphInfo {
  /// Per-glyph italics correction values.
  italic_corrections : MathValues?
  /// Per-glyph horizontal positions for attaching mathematical accents.
  top_accent_attachments : MathValues?
  /// Glyphs which are _extended shapes_.
  extended_shapes : Coverage?
  /// Per-glyph information for mathematical kerning.
  kern_infos : MathKernInfos?
}

///|
pub impl FromSlice for MathGlyphInfo with fn parse_slice(data) {
  let s = Stream::new(data)
  let italic_corrections = math_parse_at_offset16(s, data)
  let top_accent_attachments = math_parse_at_offset16(s, data)
  let extended_shapes = math_parse_at_offset16(s, data)
  let kern_infos = math_parse_at_offset16(s, data)
  { italic_corrections, top_accent_attachments, extended_shapes, kern_infos, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathGlyphInfo with FromSlice::{parse_slice}

///|
/// Glyph part flags.
pub(all) struct PartFlags(UInt16) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PartFlags with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PartFlags with @debug.Debug::{to_repr}

///|
pub fn PartFlags::extender(self : PartFlags) -> Bool {
  (self.0 & 0x0001) != 0
}

///|
pub impl FromData for PartFlags with fn size() {
  2
}

///|
pub impl FromData for PartFlags with fn parse(data) {
  PartFlags(FromData::parse(data))
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PartFlags with FromData::{size, parse}

///|
/// Details for a glyph part in an assembly.
pub(all) struct GlyphPart {
  /// Glyph ID for the part.
  glyph_id : GlyphId
  /// Lengths of the connectors on the start of the glyph, in font design units.
  start_connector_length : UInt16
  /// Lengths of the connectors on the end of the glyph, in font design units.
  end_connector_length : UInt16
  /// The full advance of the part, in font design units.
  full_advance : UInt16
  /// Part flags.
  part_flags : PartFlags
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphPart with @debug.Debug::{to_repr}

///|
pub impl FromData for GlyphPart with fn size() {
  10
}

///|
pub impl FromData for GlyphPart with fn parse(data) {
  let s = Stream::new(data)
  {
    glyph_id: s.read(),
    start_connector_length: s.read(),
    end_connector_length: s.read(),
    full_advance: s.read(),
    part_flags: s.read(),
  }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphPart with FromData::{size, parse}

///|
/// A [Glyph Assembly Table](https://learn.microsoft.com/en-us/typography/opentype/spec/math#glyphassembly-table).
pub(all) struct GlyphAssembly {
  /// The italics correction of the assembled glyph.
  italics_correction : MathValue
  /// Parts the assembly is composed of.
  parts : LazyArray16[GlyphPart]
}

///|
pub impl FromSlice for GlyphAssembly with fn parse_slice(data) {
  let s = Stream::new(data)
  let italics_correction = (s.read() : MathValueRecord).get(data)
  let count = s.read_u16()
  let parts = s.read_array16(count)
  { italics_correction, parts, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphAssembly with FromSlice::{parse_slice}

///|
/// Description of math glyph variants.
pub(all) struct GlyphVariant {
  /// The ID of the variant glyph.
  variant_glyph : GlyphId
  /// Advance width/height, in design units, of the variant glyph.
  advance_measurement : UInt16
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphVariant with @debug.Debug::{to_repr}

///|
pub impl FromData for GlyphVariant with fn size() {
  4
}

///|
pub impl FromData for GlyphVariant with fn parse(data) {
  let s = Stream::new(data)
  { variant_glyph: s.read(), advance_measurement: s.read(), }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphVariant with FromData::{size, parse}

///|
/// A [Math Glyph Construction Table](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/math#mathglyphconstruction-table).
pub(all) struct GlyphConstruction {
  /// A general recipe on how to construct a variant with large advance width/height.
  assembly : GlyphAssembly?
  /// Prepared variants of the glyph with varying advances.
  variants : LazyArray16[GlyphVariant]
}

///|
pub impl FromSlice for GlyphConstruction with fn parse_slice(data) {
  let s = Stream::new(data)
  let assembly = math_parse_at_offset16(s, data)
  let variant_count = s.read_u16()
  let variants = s.read_array16(variant_count)
  { assembly, variants, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphConstruction with FromSlice::{parse_slice}

///|
/// A mapping from glyphs to
/// [Math Glyph Construction Tables](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/math#mathglyphconstruction-table).
struct GlyphConstructions {
  coverage : Coverage
  constructions : LazyOffsetArray16[GlyphConstruction]
}

///|
fn GlyphConstructions::new(
  data : BytesView,
  coverage : Coverage?,
  offsets : LazyArray16[Offset16?],
) -> GlyphConstructions {
  {
    coverage: coverage.unwrap_or(
      Coverage::Format1(glyphs=LazyArray16::new(empty_data)),
    ),
    constructions: LazyOffsetArray16::new(data, offsets),
  }
}

///|
/// Returns the construction for the glyph or `None` if it is not covered.
pub fn GlyphConstructions::get(
  self : GlyphConstructions,
  glyph : GlyphId,
) -> GlyphConstruction? {
  guard self.coverage.get(glyph) is Some(index) else { return None }
  self.constructions.get(index)
}

///|
pub impl Debug for GlyphConstructions with fn to_repr(_) {
  Repr::literal("GlyphConstructions { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphConstructions with @debug.Debug::{to_repr}

///|
/// A [Math Variants Table](
/// https://learn.microsoft.com/en-us/typography/opentype/spec/math#mathvariants-table).
pub(all) struct MathVariants {
  /// Minimum overlap of connecting glyphs during glyph construction, in design units.
  min_connector_overlap : UInt16
  /// Constructions for shapes growing in the vertical direction.
  vertical_constructions : GlyphConstructions
  /// Constructions for shapes growing in the horizontal direction.
  horizontal_constructions : GlyphConstructions
}

///|
pub impl FromSlice for MathVariants with fn parse_slice(data) {
  let s = Stream::new(data)
  let min_connector_overlap = s.read_u16()
  let vertical_coverage = math_parse_at_offset16(s, data)
  let horizontal_coverage = math_parse_at_offset16(s, data)
  let vertical_count = s.read_u16()
  let horizontal_count = s.read_u16()
  let vertical_offsets = s.read_array16(vertical_count)
  let horizontal_offsets = s.read_array16(horizontal_count)
  {
    min_connector_overlap,
    vertical_constructions: GlyphConstructions::new(
      data, vertical_coverage, vertical_offsets,
    ),
    horizontal_constructions: GlyphConstructions::new(
      data, horizontal_coverage, horizontal_offsets,
    ),
  }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathVariants with FromSlice::{parse_slice}

///|
/// A [Math Table](https://docs.microsoft.com/en-us/typography/opentype/spec/math).
pub(all) struct MathTable {
  /// Math positioning constants.
  constants : MathConstants?
  /// Per-glyph positioning information.
  glyph_info : MathGlyphInfo?
  /// Variants and assembly recipes for growable glyphs.
  variants : MathVariants?
}

///|
/// Parses a table from raw data.
pub fn MathTable::parse(data : BytesView) -> MathTable? {
  let s = Stream::new(data)
  guard s.read_opt() is Some((major_version : UInt16)) else { return None }
  let major_version = major_version.to_byte() // `as u8`
  s.advance(2) // minor version
  if major_version != 1 {
    return None
  }
  Some({
    constants: math_parse_at_offset16(s, data),
    glyph_info: math_parse_at_offset16(s, data),
    variants: math_parse_at_offset16(s, data),
  })
}

///|
/// `StreamExt::parse_at_offset16` from upstream `math.rs`.
fn[T : FromSlice] math_parse_at_offset16(s : Stream, data : BytesView) -> T? {
  guard s.read_opt() is Some(Some((offset : Offset16))) else { return None }
  guard slice_from(data, offset.to_usize()) is Some(data) else { return None }
  opt(() => T::parse_slice(data))
}
