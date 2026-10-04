// Port of wasmi_ir 1.0.9 `visit_results.rs`.
//
// Upstream visits `&mut Slot`/`&mut SlotSpan` result fields of an `Op` in
// place; here the visitor returns the (possibly updated) slot and
// `Op::visit_results` (generated in op_gen.mbt) returns the updated `Op`.

///|
/// Implemented by visitors of the result slots of an [`Op`].
pub(open) trait VisitResults {
  /// Visits a [`Slot`] storing the result of an [`Op`].
  fn visit_result_reg(Self, Slot) -> Slot
  /// Visits a [`SlotSpan`] storing the results of an [`Op`].
  fn visit_result_regs(Self, SlotSpan, Int?) -> SlotSpan
}
