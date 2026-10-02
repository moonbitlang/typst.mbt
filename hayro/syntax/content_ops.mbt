// Port of `hayro-syntax/src/content/ops.rs` and `ops_generated.rs`
// (converted from upstream by a one-off script): content stream operators.

///|
/// A typed content stream instruction.
pub(all) enum TypedInstruction {
  BeginCompatibility
  EndCompatibility
  SaveState
  RestoreState
  Transform(Number, Number, Number, Number, Number, Number)
  LineWidth(Number)
  LineCap(Number)
  LineJoin(Number)
  MiterLimit(Number)
  DashPattern(PdfArray, Number)
  RenderingIntent(Name)
  FlatnessTolerance(Number)
  SetGraphicsState(Name)
  MoveTo(Number, Number)
  LineTo(Number, Number)
  CubicTo(Number, Number, Number, Number, Number, Number)
  CubicStartTo(Number, Number, Number, Number)
  CubicEndTo(Number, Number, Number, Number)
  ClosePath
  RectPath(Number, Number, Number, Number)
  StrokePath
  CloseAndStrokePath
  FillPathNonZero
  FillPathNonZeroCompatibility
  FillPathEvenOdd
  FillAndStrokeNonZero
  FillAndStrokeEvenOdd
  CloseFillAndStrokeNonZero
  CloseFillAndStrokeEvenOdd
  EndPath
  ClipNonZero
  ClipEvenOdd
  ColorSpaceStroke(Name)
  ColorSpaceNonStroke(Name)
  StrokeColor(Array[Number])
  StrokeColorNamed(Array[Number], Name?)
  NonStrokeColor(Array[Number])
  NonStrokeColorNamed(Array[Number], Name?)
  StrokeColorDeviceGray(Number)
  NonStrokeColorDeviceGray(Number)
  StrokeColorDeviceRgb(Number, Number, Number)
  NonStrokeColorDeviceRgb(Number, Number, Number)
  StrokeColorCmyk(Number, Number, Number, Number)
  NonStrokeColorCmyk(Number, Number, Number, Number)
  Shading(Name)
  XObject(Name)
  InlineImage(Stream)
  CharacterSpacing(Number)
  WordSpacing(Number)
  HorizontalScaling(Number)
  TextLeading(Number)
  TextFont(Name, Number)
  TextRenderingMode(Number)
  TextRise(Number)
  BeginText
  EndText
  NextLine(Number, Number)
  NextLineAndSetLeading(Number, Number)
  SetTextMatrix(Number, Number, Number, Number, Number, Number)
  NextLineUsingLeading
  ShowText(PdfString)
  NextLineAndShowText(PdfString)
  ShowTextWithParameters(Number, Number, PdfString)
  ShowTexts(PdfArray)
  ColorGlyph(Number, Number)
  ShapeGlyph(Number, Number, Number, Number, Number, Number)
  MarkedContentPoint(Name)
  MarkedContentPointWithProperties(Name, Object)
  BeginMarkedContent(Name)
  BeginMarkedContentWithProperties(Name, Object)
  EndMarkedContent
  Fallback(Name)
}

///|
/// Dispatch an instruction to its typed form; `None` if the operands are
/// invalid.
pub fn TypedInstruction::dispatch(
  instruction : Instruction,
) -> TypedInstruction? {
  let stack = instruction.operands
  match instruction.operator.0 {
    "BX" => Some(BeginCompatibility)
    "EX" => Some(EndCompatibility)
    "q" => Some(SaveState)
    "Q" => Some(RestoreState)
    "cm" => {
      let shift = saturating_sub(stack.length(), 6)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      guard operand_number(stack, 3 + shift) is Some(a3) else { return None }
      guard operand_number(stack, 4 + shift) is Some(a4) else { return None }
      guard operand_number(stack, 5 + shift) is Some(a5) else { return None }
      Some(Transform(a0, a1, a2, a3, a4, a5))
    }
    "w" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(LineWidth(a0))
    }
    "J" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(LineCap(a0))
    }
    "j" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(LineJoin(a0))
    }
    "M" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(MiterLimit(a0))
    }
    "d" => {
      let shift = saturating_sub(stack.length(), 2)
      guard operand_array(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      Some(DashPattern(a0, a1))
    }
    "ri" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      Some(RenderingIntent(a0))
    }
    "i" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(FlatnessTolerance(a0))
    }
    "gs" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      Some(SetGraphicsState(a0))
    }
    "m" => {
      let shift = saturating_sub(stack.length(), 2)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      Some(MoveTo(a0, a1))
    }
    "l" => {
      let shift = saturating_sub(stack.length(), 2)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      Some(LineTo(a0, a1))
    }
    "c" => {
      let shift = saturating_sub(stack.length(), 6)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      guard operand_number(stack, 3 + shift) is Some(a3) else { return None }
      guard operand_number(stack, 4 + shift) is Some(a4) else { return None }
      guard operand_number(stack, 5 + shift) is Some(a5) else { return None }
      Some(CubicTo(a0, a1, a2, a3, a4, a5))
    }
    "v" => {
      let shift = saturating_sub(stack.length(), 4)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      guard operand_number(stack, 3 + shift) is Some(a3) else { return None }
      Some(CubicStartTo(a0, a1, a2, a3))
    }
    "y" => {
      let shift = saturating_sub(stack.length(), 4)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      guard operand_number(stack, 3 + shift) is Some(a3) else { return None }
      Some(CubicEndTo(a0, a1, a2, a3))
    }
    "h" => Some(ClosePath)
    "re" => {
      let shift = saturating_sub(stack.length(), 4)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      guard operand_number(stack, 3 + shift) is Some(a3) else { return None }
      Some(RectPath(a0, a1, a2, a3))
    }
    "S" => Some(StrokePath)
    "s" => Some(CloseAndStrokePath)
    "f" => Some(FillPathNonZero)
    "F" => Some(FillPathNonZeroCompatibility)
    "f*" => Some(FillPathEvenOdd)
    "B" => Some(FillAndStrokeNonZero)
    "B*" => Some(FillAndStrokeEvenOdd)
    "b" => Some(CloseFillAndStrokeNonZero)
    "b*" => Some(CloseFillAndStrokeEvenOdd)
    "n" => Some(EndPath)
    "W" => Some(ClipNonZero)
    "W*" => Some(ClipEvenOdd)
    "CS" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      Some(ColorSpaceStroke(a0))
    }
    "cs" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      Some(ColorSpaceNonStroke(a0))
    }
    "SC" => {
      guard stack_get_all_numbers(stack) is Some(nums) else { return None }
      Some(StrokeColor(nums))
    }
    "SCN" => {
      guard parse_named_color(stack) is Some((nums, name)) else { return None }
      Some(StrokeColorNamed(nums, name))
    }
    "sc" => {
      guard stack_get_all_numbers(stack) is Some(nums) else { return None }
      Some(NonStrokeColor(nums))
    }
    "scn" => {
      guard parse_named_color(stack) is Some((nums, name)) else { return None }
      Some(NonStrokeColorNamed(nums, name))
    }
    "G" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(StrokeColorDeviceGray(a0))
    }
    "g" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(NonStrokeColorDeviceGray(a0))
    }
    "RG" => {
      let shift = saturating_sub(stack.length(), 3)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      Some(StrokeColorDeviceRgb(a0, a1, a2))
    }
    "rg" => {
      let shift = saturating_sub(stack.length(), 3)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      Some(NonStrokeColorDeviceRgb(a0, a1, a2))
    }
    "K" => {
      let shift = saturating_sub(stack.length(), 4)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      guard operand_number(stack, 3 + shift) is Some(a3) else { return None }
      Some(StrokeColorCmyk(a0, a1, a2, a3))
    }
    "k" => {
      let shift = saturating_sub(stack.length(), 4)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      guard operand_number(stack, 3 + shift) is Some(a3) else { return None }
      Some(NonStrokeColorCmyk(a0, a1, a2, a3))
    }
    "sh" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      Some(Shading(a0))
    }
    "Do" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      Some(XObject(a0))
    }
    "BI" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_stream(stack, 0 + shift) is Some(a0) else { return None }
      Some(InlineImage(a0))
    }
    "Tc" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(CharacterSpacing(a0))
    }
    "Tw" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(WordSpacing(a0))
    }
    "Tz" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(HorizontalScaling(a0))
    }
    "TL" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(TextLeading(a0))
    }
    "Tf" => {
      let shift = saturating_sub(stack.length(), 2)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      Some(TextFont(a0, a1))
    }
    "Tr" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(TextRenderingMode(a0))
    }
    "Ts" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      Some(TextRise(a0))
    }
    "BT" => Some(BeginText)
    "ET" => Some(EndText)
    "Td" => {
      let shift = saturating_sub(stack.length(), 2)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      Some(NextLine(a0, a1))
    }
    "TD" => {
      let shift = saturating_sub(stack.length(), 2)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      Some(NextLineAndSetLeading(a0, a1))
    }
    "Tm" => {
      let shift = saturating_sub(stack.length(), 6)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      guard operand_number(stack, 3 + shift) is Some(a3) else { return None }
      guard operand_number(stack, 4 + shift) is Some(a4) else { return None }
      guard operand_number(stack, 5 + shift) is Some(a5) else { return None }
      Some(SetTextMatrix(a0, a1, a2, a3, a4, a5))
    }
    "T*" => Some(NextLineUsingLeading)
    "Tj" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_string(stack, 0 + shift) is Some(a0) else { return None }
      Some(ShowText(a0))
    }
    "'" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_string(stack, 0 + shift) is Some(a0) else { return None }
      Some(NextLineAndShowText(a0))
    }
    "\"" => {
      let shift = saturating_sub(stack.length(), 3)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_string(stack, 2 + shift) is Some(a2) else { return None }
      Some(ShowTextWithParameters(a0, a1, a2))
    }
    "TJ" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_array(stack, 0 + shift) is Some(a0) else { return None }
      Some(ShowTexts(a0))
    }
    "d0" => {
      let shift = saturating_sub(stack.length(), 2)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      Some(ColorGlyph(a0, a1))
    }
    "d1" => {
      let shift = saturating_sub(stack.length(), 6)
      guard operand_number(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_number(stack, 1 + shift) is Some(a1) else { return None }
      guard operand_number(stack, 2 + shift) is Some(a2) else { return None }
      guard operand_number(stack, 3 + shift) is Some(a3) else { return None }
      guard operand_number(stack, 4 + shift) is Some(a4) else { return None }
      guard operand_number(stack, 5 + shift) is Some(a5) else { return None }
      Some(ShapeGlyph(a0, a1, a2, a3, a4, a5))
    }
    "MP" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      Some(MarkedContentPoint(a0))
    }
    "DP" => {
      let shift = saturating_sub(stack.length(), 2)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_object(stack, 1 + shift) is Some(a1) else { return None }
      Some(MarkedContentPointWithProperties(a0, a1))
    }
    "BMC" => {
      let shift = saturating_sub(stack.length(), 1)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      Some(BeginMarkedContent(a0))
    }
    "BDC" => {
      let shift = saturating_sub(stack.length(), 2)
      guard operand_name(stack, 0 + shift) is Some(a0) else { return None }
      guard operand_object(stack, 1 + shift) is Some(a1) else { return None }
      Some(BeginMarkedContentWithProperties(a0, a1))
    }
    "EMC" => Some(EndMarkedContent)
    _ => Some(Fallback(instruction.operator))
  }
}
