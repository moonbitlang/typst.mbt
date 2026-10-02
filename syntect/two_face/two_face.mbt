// Port of `two-face` 0.4.5's `syntax` module: the extra syntax definitions
// (on top of syntect's defaults) used by Typst's raw blocks.
//
// The syntax set is generated from the crate's packed dump by
// `oracle/src/bin/gen_syntect.rs` into `syntaxes_gen.mbt`.

///|
let extra_no_newlines_cell : Ref[@syntect.SyntaxSet?] = Ref(None)

///|
/// Akin to `SyntaxSet::load_defaults_nonewlines()`, but with extra syntax
/// definitions (the `fancy-regex` flavour of the dump).
///
/// The set is decoded once and shared; the contexts of each syntax are
/// decoded on first use.
pub fn extra_no_newlines() -> @syntect.SyntaxSet {
  match extra_no_newlines_cell.val {
    Some(set) => set
    None => {
      let set = @syntect.SyntaxSet::from_compact(syntax_header, syntax_contexts)
      extra_no_newlines_cell.val = Some(set)
      set
    }
  }
}
