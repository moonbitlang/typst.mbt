// Port of `fancy-regex` 0.16.2 `src/optimize.rs`: optimization of regex
// expressions.

///|
/// Rewrite the expression tree to help the VM compile an efficient program.
/// Returns a boolean to say whether the new tree explicitly contains capture
/// group 0.
pub fn optimize(tree : ExprTree) -> Bool {
  // self recursion prevents us from moving the trailing lookahead out of group 0
  if !tree.self_recursive {
    optimize_trailing_lookahead(tree)
  } else {
    false
  }
}

///|
fn optimize_trailing_lookahead(tree : ExprTree) -> Bool {
  // returns a boolean to say whether the optimization was applied.
  // - if it was applied, capture group 0 is no longer implicit, but explicit
  //   if/when the whole expression gets delegated to regex-automata
  // converts i.e. original pattern `a(?=b)` when wrapped in the capture group 0
  // as `(a(?=b))`
  // to `(a)b`
  match tree.expr {
    Concat(root_concat_children) =>
      // we get the last child if it is a positive lookahead
      if root_concat_children.last() is Some(LookAround(inner, LookAhead)) {
        // take the rest of the children from the original Concat
        let group0_children = root_concat_children[:root_concat_children.length() -
        1].to_owned()
        let group0 = Group(Concat(group0_children))
        // compose new Concat: [Group0, lookahead inner expr]
        tree.expr = Concat([group0, inner])
        true
      } else {
        false
      }
    LookAround(inner, LookAhead) => {
      let group0 = Group(Empty)
      // compose new Concat: [Group0, lookahead inner expr]
      tree.expr = Concat([group0, inner])
      true
    }
    _ => false
  }
}
