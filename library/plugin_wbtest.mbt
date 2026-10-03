///|
/// A plugin (compiled from the WAT below with `wasm-tools parse`) whose
/// `grow` grows its memory from 1 to 3 pages, which makes the backing buffer
/// of the memory larger than the memory itself.
///
/// ```wat
/// (module
///   (import "typst_env" "wasm_minimal_protocol_send_result_to_host" (func $send (param i32 i32)))
///   (import "typst_env" "wasm_minimal_protocol_write_args_to_buffer" (func $write (param i32)))
///   (memory (export "memory") 1)
///   (func (export "grow") (result i32)
///     (drop (memory.grow (i32.const 1)))
///     (drop (memory.grow (i32.const 1)))
///     (i32.store8 (i32.const 196000) (i32.const 120))
///     (call $send (i32.const 196000) (i32.const 1))
///     (i32.const 0))
///   (func (export "noop") (result i32)
///     (call $send (i32.const 196000) (i32.const 1))
///     (i32.const 0)))
/// ```
let grow_plugin_hex = "0061736d01000000010e0360027f7f0060017f006000017f026e020974797073745f656e76297761736d5f6d696e696d616c5f70726f746f636f6c5f73656e645f726573756c745f746f5f686f737400000974797073745f656e762a7761736d5f6d696e696d616c5f70726f746f636f6c5f77726974655f617267735f746f5f627566666572000103030202020503010001071803066d656d6f727902000467726f770002046e6f6f7000030a2f022000410140001a410140001a41a0fb0b41f8003a000041a0fb0b4101100041000b0c0041a0fb0b4101100041000b0015046e616d65010e02000473656e6401057772697465"

///|
fn plugin_test_unhex(hex : String) -> Bytes {
  let digit = (c : UInt16) => {
    let c = c.to_int()
    if c >= '0'.to_int() && c <= '9'.to_int() {
      c - '0'.to_int()
    } else {
      c - 'a'.to_int() + 10
    }
  }
  let out = FixedArray::make(hex.length() / 2, b'\x00')
  for i in 0..<out.length() {
    out[i] = (digit(hex.code_unit_at(2 * i)) * 16 +
      digit(hex.code_unit_at(2 * i + 1))).to_byte()
  }
  Bytes::from_fixedarray(out)
}

///|
/// Restoring a snapshot taken after the memory grew must only copy the
/// memory's own bytes (regression: the snapshot held the whole backing
/// buffer, which did not fit into a freshly grown memory).
test "plugin transition snapshot after memory growth" {
  plugin_test_snapshot() catch {
    e => fail(@debug.to_string(e))
  }
}

///|
fn plugin_test_snapshot() -> Unit raise {
  let base = Plugin::new(plugin_test_unhex(grow_plugin_hex))
  let a = base.transition("grow", [])
  // Move `a`'s instance into `b`, so that `a` must restore its snapshot.
  let b = a.transition("noop", [])
  inspect(a.call("noop", []), content="b\"x\"")
  inspect(b.call("noop", []), content="b\"x\"")
  // `base` still has a single page.
  let err = try base.call("noop", []) catch {
    HintedError(e) => e.message
  } noraise {
    _ => "no error"
  }
  inspect(
    err,
    content="plugin tried to read out of bounds: pointer 0x2fda0 is out of bounds for read of length 1",
  )
}
