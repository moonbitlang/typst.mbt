// Port of the style chain trunk helpers and `Styles::root` of
// `typst-library/src/foundations/styles.rs`.

///|
/// Determine the shared trunk of a collection of style chains.
pub fn StyleChain::trunk(chains : Iter[StyleChain]) -> StyleChain? {
  // Determine shared style depth and first span.
  // Note: `Iter::head` consumes the first element.
  let mut trunk = match chains.next() {
    Some(first) => first
    None => return None
  }
  let mut depth = trunk.links().length()
  for chain in chains {
    let mut chain = chain
    let len = chain.links().length()
    if len < depth {
      for _ in 0..<(depth - len) {
        trunk = trunk.pop()
      }
      depth = len
    } else if len > depth {
      for _ in 0..<(len - depth) {
        chain = chain.pop()
      }
    }
    while depth > 0 && chain != trunk {
      trunk = trunk.pop()
      chain = chain.pop()
      depth -= 1
    }
  }
  Some(trunk)
}

///|
/// Determines the shared trunk of a list of elements.
///
/// This will ignore styles for tags (conceptually, they just don't exist).
pub fn StyleChain::trunk_from_pairs(pairs : ArrayView[Pair]) -> StyleChain? {
  StyleChain::trunk(
    pairs.iter().filter(pair => !pair.0.is_(tag_elem())).map(pair => pair.1),
  )
}

///|
/// Determines the styles used for content that is at the root, outside of
/// the user-controlled content (e.g. page marginals and footnotes).
///
/// - The styles must be shared by all children (the trunk).
/// - Only styles that are "outside" (i.e. not from show rules or the like)
///   are kept.
/// - Of these, the initial styles are kept and otherwise only those that are
///   liftable (set rules as opposed to direct constructor calls).
pub fn Styles::root(children : ArrayView[Pair], initial : StyleChain) -> Styles {
  // Determine the shared styles (excluding tags).
  let base = StyleChain::trunk_from_pairs(children).unwrap_or(initial).to_map()

  // Determine the initial styles that are also shared by everything. We can't
  // use `StyleChain::trunk` because it currently doesn't deal with partially
  // shared links (where a subslice matches).
  let initial_items = initial.to_map().items
  let mut trunk_len = 0
  while trunk_len < initial_items.length() &&
        trunk_len < base.items.length() &&
        initial_items[trunk_len] == base.items[trunk_len] {
    trunk_len += 1
  }

  // Filter the base styles according to our rules.
  let items = []
  for i, style in base.items {
    let initial = i < trunk_len
    if style.outside() && (initial || style.liftable()) {
      items.push(style)
    }
  }
  { items, }
}
