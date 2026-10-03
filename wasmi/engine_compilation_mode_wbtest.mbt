///|
/// Validation in each [`CompilationMode`], checked against wasmi 1.0.9 on
///
/// ```wat
/// (module
///   (func (export "good") (result i32) i32.const 7)
///   (func (export "bad") drop))
/// ```
///
/// `Lazy` validates on first use (with offsets relative to the function
/// body), the other modes when the module is created.
test "compilation modes validate function bodies" {
  let bytes = executor_test_decode_hex(
    "0061736d010000000108026000017f6000000303020001070e0204676f6f6400000362616400010a0a02040041070b03001a0b",
  )
  let run = fn(mode : CompilationMode) -> Array[String] {
    let engine = Engine::new(Config::default().compilation_mode(mode))
    let module_ = Module::new(engine, bytes) catch {
      e => return ["load-err: \{e}"]
    }
    let store = Store::new(engine, ())
    let linker : Linker[Unit] = Linker::new(engine)
    let instance = linker.instantiate_and_start(store, module_) catch {
      e => return ["inst-err: \{e}"]
    }
    ["good", "bad", "bad"].map(name => {
      guard instance.get_func(store, name) is Some(func) else {
        abort("missing export")
      }
      let results : Array[Val] = if name == "good" { [I32(0)] } else { [] }
      try func.call(store, [], results) catch {
        e => "\{name}: err: \{e}"
      } noraise {
        _ => "\{name}: ok \{results.length()}"
      }
    })
  }
  inspect(
    run(Lazy),
    content=(
      #|[good: ok 1, bad: err: type mismatch: expected a type but nothing on stack (at offset 0x1), bad: err: lazy function compilation encountered a Wasm validation or translation error]

    ),
  )
  inspect(
    run(LazyTranslation),
    content=(
      #|[load-err: type mismatch: expected a type but nothing on stack (at offset 0x31)]

    ),
  )
  inspect(
    run(Eager),
    content=(
      #|[load-err: type mismatch: expected a type but nothing on stack (at offset 0x31)]

    ),
  )
}
