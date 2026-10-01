// Port of the `ContextElem` parts of `typst-library/src/foundations/context.rs`
// (`Context` itself lives in `engine.mbt`).

///|
/// Custom behavior of `context` elements: they cannot be constructed
/// manually.
fn context_elem_init(e : Element) -> Unit {
  e.hooks().construct = Some((_, args) => {
    bail_at(args.span, "cannot be constructed manually")
  })
}
