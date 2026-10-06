// Port of `two-face` 0.4.5's `syntax` module: the extra syntax definitions
// (on top of syntect's defaults) used by Typst's raw blocks.
//
// The syntax set is generated from the crate's packed dump by
// `oracle/src/bin/gen_syntect.rs` into `syntaxes_gen.mbt`.

///|
let extra_no_newlines_cell : Ref[@syntect.SyntaxSet?] = Ref(None)

///|
/// A generated string: the generator splits what would be a source line of
/// more than 65535 columns into several literals.
fn join_chunks(chunks : ReadOnlyArray[String]) -> String {
  if chunks.length() == 1 {
    return chunks[0]
  }
  let buf = StringBuilder()
  for chunk in chunks[:] {
    buf.write_string(chunk)
  }
  buf.to_string()
}

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
      let set = @syntect.SyntaxSet::from_compact(join_chunks(syntax_header), i => {
        join_chunks(syntax_contexts[i])
      })
      extra_no_newlines_cell.val = Some(set)
      set
    }
  }
}
