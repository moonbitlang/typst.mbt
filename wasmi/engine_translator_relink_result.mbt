// Port of wasmi 1.0.9 `engine/translator/relink_result.rs`.

///|
/// Visitor replacing a single result slot `old_result` by `new_result`.
priv struct RelinkVisitor {
  new_result : @ir.Slot
  old_result : @ir.Slot
  mut replaced : Bool
}

///|
impl @ir.VisitResults for RelinkVisitor with fn visit_result_reg(self, slot) {
  let (replaced, slot) = relink_simple(slot, self.new_result, self.old_result)
  self.replaced = replaced
  slot
}

///|
impl @ir.VisitResults for RelinkVisitor with fn visit_result_regs(
  _self,
  slots,
  _len,
) {
  slots
}

///|
/// Relinks the result [`Slot`] of `instr` from `old_result` to `new_result`
/// (upstream `RelinkResult::relink_result`).
///
/// Returns the updated instruction if it has been relinked, `None` otherwise.
pub fn relink_result(
  instr : @ir.Op,
  module : ModuleHeader,
  new_result : @ir.Slot,
  old_result : @ir.Slot,
) -> @ir.Op? {
  // Note: for call instructions we have to infer with special handling if they return
  //       a single value which allows us to relink the single result register.
  match instr {
    CallInternal0(results~, func~) => {
      guard relink_call_internal(
          results,
          EngineFunc::from_internal(func),
          module,
          new_result,
          old_result,
        )
        is Some(results) else {
        return None
      }
      Some(CallInternal0(results~, func~))
    }
    CallInternal(results~, func~) => {
      guard relink_call_internal(
          results,
          EngineFunc::from_internal(func),
          module,
          new_result,
          old_result,
        )
        is Some(results) else {
        return None
      }
      Some(CallInternal(results~, func~))
    }
    CallImported0(results~, func~) => {
      guard relink_call_imported(results, func, module, new_result, old_result)
        is Some(results) else {
        return None
      }
      Some(CallImported0(results~, func~))
    }
    CallImported(results~, func~) => {
      guard relink_call_imported(results, func, module, new_result, old_result)
        is Some(results) else {
        return None
      }
      Some(CallImported(results~, func~))
    }
    CallIndirect0(results~, func_type~) => {
      guard relink_call_indirect(
          results, func_type, module, new_result, old_result,
        )
        is Some(results) else {
        return None
      }
      Some(CallIndirect0(results~, func_type~))
    }
    CallIndirect0Imm16(results~, func_type~) => {
      guard relink_call_indirect(
          results, func_type, module, new_result, old_result,
        )
        is Some(results) else {
        return None
      }
      Some(CallIndirect0Imm16(results~, func_type~))
    }
    CallIndirect(results~, func_type~) => {
      guard relink_call_indirect(
          results, func_type, module, new_result, old_result,
        )
        is Some(results) else {
        return None
      }
      Some(CallIndirect(results~, func_type~))
    }
    CallIndirectImm16(results~, func_type~) => {
      guard relink_call_indirect(
          results, func_type, module, new_result, old_result,
        )
        is Some(results) else {
        return None
      }
      Some(CallIndirectImm16(results~, func_type~))
    }
    instr => {
      // Fallback: only relink results of instructions with statically known single results.
      let visitor = { new_result, old_result, replaced: false, }
      let relinked = instr.visit_results(visitor)
      if visitor.replaced {
        Some(relinked)
      } else {
        None
      }
    }
  }
}

///|
/// Returns `(true, new_result)` if `result` is `old_result`.
fn relink_simple(
  result : @ir.Slot,
  new_result : @ir.Slot,
  old_result : @ir.Slot,
) -> (Bool, @ir.Slot) {
  if result != old_result {
    // Note: This is a safeguard to prevent miscompilations.
    return (false, result)
  }
  (true, new_result)
}

///|
fn relink_span(
  results : @ir.SlotSpan,
  new_result : @ir.Slot,
  old_result : @ir.Slot,
) -> @ir.SlotSpan? {
  let (replaced, head) = relink_simple(results.head(), new_result, old_result)
  if replaced {
    Some(@ir.SlotSpan::new(head))
  } else {
    None
  }
}

///|
fn relink_call_internal(
  results : @ir.SlotSpan,
  func : EngineFunc,
  module : ModuleHeader,
  new_result : @ir.Slot,
  old_result : @ir.Slot,
) -> @ir.SlotSpan? {
  guard module.get_func_index(func) is Some(module_func) else {
    abort("missing module func for compiled func: EngineFunc(\{func.0})")
  }
  let engine = module.engine_upgrade()
  let func_type = module.get_type_of_func(module_func)
  let len_results = engine.resolve_func_type(func_type).len_results()
  if len_results != 1 {
    return None
  }
  relink_span(results, new_result, old_result)
}

///|
fn relink_call_imported(
  results : @ir.SlotSpan,
  func : @ir.Func,
  module : ModuleHeader,
  new_result : @ir.Slot,
  old_result : @ir.Slot,
) -> @ir.SlotSpan? {
  let engine = module.engine_upgrade()
  let func_type = module.get_type_of_func(FuncIdx(func.0))
  let len_results = engine.resolve_func_type(func_type).results().length()
  if len_results != 1 {
    return None
  }
  relink_span(results, new_result, old_result)
}

///|
fn relink_call_indirect(
  results : @ir.SlotSpan,
  func_type : @ir.FuncType,
  module : ModuleHeader,
  new_result : @ir.Slot,
  old_result : @ir.Slot,
) -> @ir.SlotSpan? {
  let engine = module.engine_upgrade()
  let func_type = module.get_func_type(FuncTypeIdx(func_type.0))
  let len_results = engine.resolve_func_type(func_type).results().length()
  if len_results != 1 {
    return None
  }
  relink_span(results, new_result, old_result)
}
