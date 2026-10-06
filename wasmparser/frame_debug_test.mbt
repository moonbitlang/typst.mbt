// `Frame`'s `Debug` output keeps wasmparser 0.228.0's field names
// (`validator/operators.rs`, `#[derive(Debug, Copy, Clone)] pub struct
// Frame`), although the `unreachable` field is spelled `unreachable_` here.

///|
test "Frame debug output uses upstream's field names" {
  let frame : @wasmparser.Frame = {
    kind: Loop,
    block_type: Empty,
    height: 3,
    unreachable_: true,
    init_height: 1,
  }
  @debug.debug_inspect(
    frame,
    content=(
      #|{
      #|  kind: Loop,
      #|  block_type: Empty,
      #|  height: 3,
      #|  unreachable: true,
      #|  init_height: 1,
      #|}
    ),
  )
}
