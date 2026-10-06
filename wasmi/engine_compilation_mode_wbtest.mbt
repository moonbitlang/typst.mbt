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
  @debug.debug_inspect(
    run(Lazy),
    content=(
      #|[
      #|  "good: ok 1",
      #|  "bad: err: type mismatch: expected a type but nothing on stack (at offset 0x1)",
      #|  "bad: err: lazy function compilation encountered a Wasm validation or translation error",
      #|]
    ),
  )
  @debug.debug_inspect(
    run(LazyTranslation),
    content=(
      #|["load-err: type mismatch: expected a type but nothing on stack (at offset 0x31)"]
    ),
  )
  @debug.debug_inspect(
    run(Eager),
    content=(
      #|["load-err: type mismatch: expected a type but nothing on stack (at offset 0x31)"]
    ),
  )
}

///|
/// Fuel charged for lazy compilation (9 per body byte with validation, 7
/// without), checked against wasmi 1.0.9 on
/// `(module (func (export "good") (result i32) i32.const 7))`: each line is
/// the initial fuel, then two calls (refuelled to 1000 in between) with the
/// remaining fuel. A call that runs out of compilation fuel leaves the
/// function uncompiled.
test "lazy compilation consumes fuel" {
  let bytes = executor_test_decode_hex(
    "0061736d010000000105016000017f0302010007080104676f6f6400000a0601040041070b",
  )
  let run = fn(mode : CompilationMode) -> String raise {
    let lines = []
    for fuel in [0UL, 10, 35, 36, 37, 40, 1000] {
      let config = Config::default().compilation_mode(mode)
      config.set_consume_fuel(true) |> ignore
      let engine = Engine::new(config)
      let module_ = Module::new(engine, bytes)
      let store = Store::new(engine, ())
      store.inner.fuel().set_fuel(fuel)
      let linker : Linker[Unit] = Linker::new(engine)
      let instance = linker.instantiate_and_start(store, module_)
      guard instance.get_func(store, "good") is Some(func) else {
        abort("missing export")
      }
      let mut line = "\{fuel}:"
      for _ in 0..<2 {
        let results : Array[Val] = [I32(0)]
        let outcome = try func.call(store, [], results) catch {
          e => "err \{e}"
        } noraise {
          _ => {
            guard results[0] is I32(v) else { abort("expected an i32") }
            "ok I32(\{v})"
          }
        }
        line = line + " \{outcome} rem=\{store.inner.fuel().get_fuel()}"
        store.inner.fuel().set_fuel(1000)
      }
      lines.push(line)
    }
    lines.join("\n")
  }
  inspect(
    run(Lazy),
    content=(
      #|0: err all fuel consumed by WebAssembly rem=0 ok I32(7) rem=962
      #|10: err all fuel consumed by WebAssembly rem=10 ok I32(7) rem=962
      #|35: err all fuel consumed by WebAssembly rem=35 ok I32(7) rem=962
      #|36: err all fuel consumed by WebAssembly rem=0 ok I32(7) rem=998
      #|37: err all fuel consumed by WebAssembly rem=1 ok I32(7) rem=998
      #|40: ok I32(7) rem=2 ok I32(7) rem=998
      #|1000: ok I32(7) rem=962 ok I32(7) rem=998
    ),
  )
  inspect(
    run(LazyTranslation),
    content=(
      #|0: err all fuel consumed by WebAssembly rem=0 ok I32(7) rem=970
      #|10: err all fuel consumed by WebAssembly rem=10 ok I32(7) rem=970
      #|35: ok I32(7) rem=5 ok I32(7) rem=998
      #|36: ok I32(7) rem=6 ok I32(7) rem=998
      #|37: ok I32(7) rem=7 ok I32(7) rem=998
      #|40: ok I32(7) rem=10 ok I32(7) rem=998
      #|1000: ok I32(7) rem=970 ok I32(7) rem=998
    ),
  )
  inspect(
    run(Eager),
    content=(
      #|0: err all fuel consumed by WebAssembly rem=0 ok I32(7) rem=998
      #|10: ok I32(7) rem=8 ok I32(7) rem=998
      #|35: ok I32(7) rem=33 ok I32(7) rem=998
      #|36: ok I32(7) rem=34 ok I32(7) rem=998
      #|37: ok I32(7) rem=35 ok I32(7) rem=998
      #|40: ok I32(7) rem=38 ok I32(7) rem=998
      #|1000: ok I32(7) rem=998 ok I32(7) rem=998
    ),
  )
}
