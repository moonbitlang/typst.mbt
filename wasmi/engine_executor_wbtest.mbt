// Smoke tests of the executor (`engine/executor`), see `t.wat` below.
//
// (module
//   (import "env" "host" (func $host (param i32) (result i32)))
//   ... fac (recursion), rec (infinite recursion), div, mem, fib (loop),
//   indirect (call_indirect), sum (return_call), callhost, inc (globals),
//   grow (memory.grow), simd, brtable)

///|
fn executor_test_module_bytes() -> Bytes {
  let hex = [
    "0061736d0100000001260760017e017e60017f017f60027f7f017f60027e7f01", "7e60027e7e017e6000017f6000027f7f020c0103656e7604686f73740001030d",
    "0c000102010103040105060101040501700101010503010001060b027f014100", "0b7e0142070b07590c036661630001037265630002036469760003036d656d00",
    "0403666962000508696e64697265637400060373756d00070863616c6c686f73", "74000803696e6300090467726f77000a0473696d64000b0762727461626c6500",
    "0c090901020041000b0001010aec010c1500200050047e420105200020004201", "7d10017e0b0b0900200041016a10020b0700200020016d0b0e002000412a3602",
    "0020002802000b3101037f4100210141012102024003402000450d0120012002", "6a21032002210120032102200041016b21000c000b0b20010b09002000200111",
    "00000b1700200050047e200105200042017d200120007c12070b0b0900200010", "0041016a0b1200230041016a2400230142017c240123000b0800410140003f00",
    "0b1e002000fd11fd0c01000000020000000300000004000000fdae01fd1b020b", "1a0002400240024020000e020001020b410a0f0b410b0f0b410c0b0049046e61",
    "6d650116040004686f737401036661630203726563070373756d031a02050200", "04646f6e6501016c0c0300026232010262310202623004040100017407080200",
    "016701026731",
  ].join("")
  executor_test_decode_hex(hex)
}

///|
fn executor_test_decode_hex(hex : String) -> Bytes {
  let bytes = FixedArray::make(hex.length() / 2, b'\x00')
  for i in 0..<bytes.length() {
    let digit = fn(c : Int) -> Int {
      if c >= '0'.to_int() && c <= '9'.to_int() {
        c - '0'.to_int()
      } else {
        c - 'a'.to_int() + 10
      }
    }
    let hi = digit(hex.code_unit_at(2 * i).to_int())
    let lo = digit(hex.code_unit_at(2 * i + 1).to_int())
    bytes[i] = (hi * 16 + lo).to_byte()
  }
  Bytes::from_array(bytes)
}

///|
fn executor_test_instance() -> (Store[Unit], Instance) raise WasmiError {
  let engine = Engine::default()
  let store = Store::new(engine, ())
  let module_ = Module::new(engine, executor_test_module_bytes())
  let linker : Linker[Unit] = Linker::new(engine)
  let _ = linker.func_new(
    "env",
    "host",
    @wasmi_core.FuncType::new([I32], [I32]) catch {
      _ => abort("invalid function type")
    },
    fn(_caller, params, results) {
      guard params[0] is I32(x) else { abort("expected an i32") }
      results[0] = I32(x * 2)
    },
  )
  let instance = linker.instantiate_and_start(store, module_)
  (store, instance)
}

///|
fn executor_test_call(
  store : Store[Unit],
  instance : Instance,
  name : String,
  params : Array[Val],
  results : Array[Val],
) -> Array[Val] raise WasmiError {
  guard instance.get_func(store, name) is Some(func) else {
    abort("missing export \{name}")
  }
  func.call(store, params, results)
  results
}

///|
test "executor: calls, loops, memory, globals, simd" {
  let (store, instance) = executor_test_instance()
  let call = fn(name, params, results) raise WasmiError {
    executor_test_call(store, instance, name, params, results)
  }
  guard call("fac", [I64(20)], [I64(0)]) is [I64(2432902008176640000)] else {
    fail("fac")
  }
  guard call("fib", [I32(30)], [I32(0)]) is [I32(832040)] else { fail("fib") }
  guard call("mem", [I32(100)], [I32(0)]) is [I32(42)] else { fail("mem") }
  guard call("indirect", [I64(5), I32(0)], [I64(0)]) is [I64(120)] else {
    fail("indirect")
  }
  guard call("sum", [I64(100000), I64(0)], [I64(0)]) is [I64(5000050000)] else {
    fail("sum")
  }
  guard call("callhost", [I32(20)], [I32(0)]) is [I32(41)] else {
    fail("callhost")
  }
  guard call("inc", [], [I32(0)]) is [I32(1)] else { fail("inc") }
  guard call("inc", [], [I32(0)]) is [I32(2)] else { fail("inc") }
  guard call("grow", [], [I32(0), I32(0)]) is [I32(1), I32(2)] else {
    fail("grow")
  }
  guard call("simd", [I32(10)], [I32(0)]) is [I32(13)] else { fail("simd") }
  guard call("brtable", [I32(0)], [I32(0)]) is [I32(10)] else {
    fail("brtable 0")
  }
  guard call("brtable", [I32(2)], [I32(0)]) is [I32(12)] else {
    fail("brtable 2")
  }
  guard call("brtable", [I32(99)], [I32(0)]) is [I32(12)] else {
    fail("brtable default")
  }
}

///|
test "executor: traps" {
  let (store, instance) = executor_test_instance()
  let call = fn(name, params, results) raise WasmiError {
    executor_test_call(store, instance, name, params, results)
  }
  let trap = fn(name : String, params : Array[Val]) -> String {
    try call(name, params, [I32(0)]) catch {
      TrapCode(code) => code.trap_message()
      error => "other error: \{error}"
    } noraise {
      _ => "no trap"
    }
  }
  inspect(trap("rec", [I32(0)]), content="call stack exhausted")
  inspect(trap("div", [I32(1), I32(0)]), content="integer divide by zero")
  inspect(
    trap("div", [I32(-2147483647 - 1), I32(-1)]),
    content="integer overflow",
  )
  inspect(trap("mem", [I32(65535)]), content="out of bounds memory access")
  // The stacks are reused after a trap.
  guard call("fac", [I64(5)], [I64(0)]) is [I64(120)] else { fail("fac") }
}

///|
/// Stack limits, checked against wasmi 1.0.9 (largest successful argument):
///
/// ```wat
/// (func $depth (param i32) (result i32)  ;; plain recursion: 999
///   (if (result i32) (i32.eqz (local.get 0)) (then (i32.const 0))
///     (else (i32.add (call $depth (i32.sub (local.get 0) (i32.const 1))) (i32.const 1)))))
/// (func $big (param i32) (result i32) (local i64 x 5000)  ;; value stack: 198
///   ...same recursion with 5000 locals...)
/// (func $tail (param i32 i32) (result i32) (local i64 x 5000)  ;; return_call: unbounded
///   ...)
/// ```
test "executor: stack limits match wasmi" {
  let bytes = executor_test_decode_hex(
    [
      "0061736d01000000010c0260017f017f60027f7f017f03040300000107160305", "64657074680000036269670001047461696c00020a51031500200045047f4100",
      "05200041016b100041016a0b0b1e0188277e2000ad2103200045047f41000520", "0041016b10012003a76a0b0b1a0188277e200045047f200105200041016b2001",
      "41016a12020b0b001a046e616d65011303000564657074680103626967020474", "61696c",
    ].join(""),
  )
  let engine = Engine::default()
  let store = Store::new(engine, ())
  let module_ = Module::new(engine, bytes)
  let linker : Linker[Unit] = Linker::new(engine)
  let instance = linker.instantiate_and_start(store, module_)
  let max_ok = fn(name : String, two : Bool, hi : Int) -> String {
    guard instance.get_func(store, name) is Some(func) else { abort(name) }
    let mut lo = 0
    let mut hi = hi
    let mut err = ""
    while lo + 1 < hi {
      let mid = (lo + hi) / 2
      let params : Array[Val] = if two {
        [I32(mid), I32(0)]
      } else {
        [I32(mid)]
      }
      try func.call(store, params, [I32(0)]) catch {
        e => {
          err = e.message()
          hi = mid
        }
      } noraise {
        _ => lo = mid
      }
    }
    "\{lo}: \{err}"
  }
  inspect(
    max_ok("depth", false, 2_000_000),
    content=(
      #|999: call stack exhausted
    ),
  )
  inspect(
    max_ok("big", false, 2_000_000),
    content=(
      #|198: call stack exhausted
    ),
  )
  inspect(
    max_ok("tail", true, 200_000),
    content=(
      #|199999: 
    ),
  )
}
