// Port of rustybuzz 0.20.1 `src/hb/shape.rs` (the public entry points).

///|
/// Shapes the buffer content using provided font and features.
///
/// Consumes the buffer. You can then run `GlyphBuffer::clear` to get the
/// `UnicodeBuffer` back without allocating a new one.
///
/// If you plan to shape multiple strings using the same `Face` prefer
/// `shape_with_plan`. This is because `ShapePlan` initialization is pretty
/// slow and should preferably be called once for each `Face`.
pub fn shape(
  face : Face,
  features : Array[Feature],
  buffer : UnicodeBuffer,
) -> GlyphBuffer {
  buffer.0.guess_segment_properties()
  let plan = ShapePlan::new(
    face,
    buffer.0.direction,
    buffer.0.script,
    buffer.0.language,
    features,
  )
  shape_with_plan(face, plan, buffer)
}

///|
/// Shapes the buffer content using the provided font and plan.
///
/// Consumes the buffer. It is up to the caller to ensure that the shape plan
/// matches the properties of the provided buffer, otherwise the shaping
/// result will likely be incorrect.
pub fn shape_with_plan(
  face : Face,
  plan : ShapePlan,
  buffer : UnicodeBuffer,
) -> GlyphBuffer {
  let buffer = buffer.0
  buffer.guess_segment_properties()
  buffer.enter()
  if buffer.len > 0 {
    // Save the original direction, we use it later.
    let target_direction = buffer.direction
    shape_internal({ plan, face, buffer, target_direction, })
  }
  GlyphBuffer(buffer)
}
