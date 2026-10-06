// A deduplicated function type is guarded by the index of the engine that
// allocated it (wasmi 1.0.9 `src/engine/func_types.rs`: `DedupFuncType` is a
// `GuardedEntity<EngineIdx, DedupFuncTypeIdx>`, and the registry panics on an
// entity of another engine, `unwrap_index`, :96-108).

///|
test "deduplicated function types belong to their engine" {
  let ty = @wasmi_core.FuncType::new([I32, I64], [F32])
  let other = @wasmi_core.FuncType::new([], [])
  let a = Engine::new(Config::default())
  let b = Engine::new(Config::default())
  let in_a = a.alloc_func_type(ty)
  let in_b = b.alloc_func_type(ty)
  // Deduplication within an engine.
  assert_true(a.alloc_func_type(ty) == in_a)
  assert_true(a.alloc_func_type(other) != in_a)
  // Both are the first type of their registry, but of different engines:
  // upstream's derived `PartialEq` compares the guard index too.
  assert_true(in_a != in_b)
  // The registry of each engine only accepts its own entities.
  @debug.debug_inspect(
    in_a.entity_index(a.func_types.engine_idx),
    content="Some(0)",
  )
  @debug.debug_inspect(
    in_a.entity_index(b.func_types.engine_idx),
    content="None",
  )
  @debug.debug_inspect(
    in_b.entity_index(b.func_types.engine_idx),
    content="Some(0)",
  )
  @debug.debug_inspect(
    in_b.entity_index(a.func_types.engine_idx),
    content="None",
  )
  assert_true(a.resolve_func_type(in_a) == ty)
  assert_true(b.resolve_func_type(in_b) == ty)
}

///|
test "foreign function type panic message" {
  // The panic itself cannot be tested (the native test driver skips panic
  // tests); upstream: `panic!("encountered foreign entity in func type
  // registry: {}", self.engine_idx.into_usize())`.
  inspect(
    foreign_func_type_message(3),
    content="encountered foreign entity in func type registry: 3",
  )
}
