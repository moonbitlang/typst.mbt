// The capture analysis of one closure or context expression, kept for the
// compilation (not upstream: a cache of a pure function of the syntax tree).
//
// Upstream runs `CapturesVisitor` over the expression every time a closure
// or context expression is evaluated, and so does the port outside of a
// compilation. What the visitor does depends on the external scopes only
// through lookups by name: it walks the tree, keeps the names that the
// expression binds itself (`internal`, which is syntax alone) and calls
// `capture` for every other identifier. So the identifiers that reach the
// lookup, in order, are a function of the syntax node, and the captured
// scope is what `capture` makes of them:
//
//   - skip the name if it was captured already,
//   - look it up in the external scopes (in math or in code),
//   - skip it if it is unknown, else bind a captured copy of the binding.
//
// [CaptureSite::captures] does exactly that with the recorded identifiers
// ([CapturesVisitor::recording] records them with the visitor's own
// traversal), so the scope has the same bindings in the same order. An
// identifier that is tried again in the same mode is recorded once: the
// external scopes do not change during the analysis, so the second try
// finds what the first one found (it is captured, and skipped) or fails
// again. The same name in the other mode is another lookup and is kept.
//
// The cache is a table for one compilation, found by the node's span and
// only used for the same node object: spans are not unique (detached
// spans, the one span of all nodes of an evaluated string), and after an
// edit a new node can have the span of an old one. When this was written
// nodes were objects that the reparser changed in place, and a table that
// outlived a compilation would have handed the analysis of a node as it
// was to the node as it is. That is gone: syntax trees are persistent
// (`syntax/node.mbt`), a node never changes, and an entry would be right
// for as long as the process runs.
//
// It stays per compilation all the same (step 5 of slice 1 of
// `docs/incremental-design.md`, which keeps the stores of memoized calls
// across compilations, looked at it again). What a kept table would save
// is the analysis and the node hash of the closure and context
// expressions that a recompilation evaluates, which are those of the
// files that changed: the modules of the others are found as a whole,
// with their closures, which hold their captured scopes and the cached
// hash of their node. Measured in watch sessions against a build that
// never drops the table: a touying deck recompiles in 23.9 ms after an
// edit of its main file with the table dropped and in 23.1 ms with it
// kept, in 117 ms and 116 ms after an edit of a file of the package
// (medians of fifteen, whose spread is larger than the difference), and
// a small project in the same 8.2 ms. What it would cost is a table that
// holds a node of every expression of every version of every file, with
// ages and an evictor of its own. The table
// is dropped when another compilation asks ([@library.memo_compilation]);
// when memoization is off, the visitor runs as upstream's does, which is
// also what the tests compare the cache with.

///|
/// An identifier that the capture analysis looks up.
priv struct CaptureAttempt {
  /// The identifier.
  name : String
  /// Whether it is looked up as a math identifier
  /// (`Scopes::get_binding_in_math`).
  in_math : Bool
  /// Whether the name occurs earlier in the list (in the other mode), so
  /// that it may have been captured already.
  repeated : Bool
}

///|
/// What is kept for a closure or context expression.
priv struct CaptureSite {
  /// The node that was analyzed.
  node : @syntax.SyntaxNode
  /// The identifiers that the visitor tries to capture, in order.
  attempts : Array[CaptureAttempt]
  /// The fingerprint of the node, for the closures made from it
  /// (`@library.Closure.node_hash`): upstream hashes the syntax tree into
  /// the hash of every closure, which is every time one is called for the
  /// first time or compared.
  node_hash : @library.LazyFingerprint
}

///|
/// The sites of the current compilation by the span of their nodes.
priv struct CaptureSites {
  mut generation : Int32
  sites : Map[@syntax.Span, Array[CaptureSite]]
}

///|
let capture_sites : CaptureSites = { generation: 0, sites: {}, }

///|
/// The most nodes with one span that are kept (the nodes of an evaluated
/// string all have the span of the string).
let capture_sites_per_span : Int32 = 4

///|
/// The analysis of `node` for the current compilation, or `None` outside of
/// a compilation (then the caller runs the visitor).
fn CaptureSite::of(node : @syntax.SyntaxNode) -> CaptureSite? {
  let generation = @library.memo_compilation()
  if generation == 0 {
    return None
  }
  let table = capture_sites
  if table.generation != generation {
    table.sites.clear()
    table.generation = generation
  }
  let span = node.span()
  match table.sites.get(span) {
    Some(sites) => {
      for site in sites {
        if physical_equal(site.node, node) {
          return Some(site)
        }
      }
      let site = CaptureSite::new(node)
      if sites.length() >= capture_sites_per_span {
        sites.clear()
      }
      sites.push(site)
      Some(site)
    }
    None => {
      let site = CaptureSite::new(node)
      table.sites[span] = [site]
      Some(site)
    }
  }
}

///|
/// Analyze `node`.
fn CaptureSite::new(node : @syntax.SyntaxNode) -> CaptureSite {
  let visitor = CapturesVisitor::recording()
  visitor.visit(node)
  {
    node,
    attempts: visitor.recorded(),
    node_hash: @library.LazyFingerprint::new(),
  }
}

///|
/// The scope of captured variables: that of
/// `CapturesVisitor::new(Some(external), capturer)` after visiting the node.
fn CaptureSite::captures(
  self : CaptureSite,
  external : @library.Scopes,
  capturer : @library.Capturer,
) -> @library.Scope {
  let captures = @library.Scope::new()
  // `CapturesVisitor::capture` for each identifier that is not internal.
  for attempt in self.attempts {
    if attempt.repeated && captures.get(attempt.name) is Some(_) {
      continue
    }
    let found = try {
      if attempt.in_math {
        external.get_binding_in_math(attempt.name)
      } else {
        external.get_binding(attempt.name)
      }
    } catch {
      _ => continue
    }
    captures.bind(attempt.name, found.capture(capturer)) |> ignore
  }
  captures
}

///|
/// Collect the captured variables of a closure or context expression:
/// upstream's
///
/// ```text
/// let mut visitor = CapturesVisitor::new(Some(&vm.scopes), capturer);
/// visitor.visit(node);
/// visitor.finish()
/// ```
///
/// with the traversal done once per node and compilation. Also returns the
/// fingerprint cache of the node for the closure.
fn collect_captures(
  scopes : @library.Scopes,
  node : @syntax.SyntaxNode,
  capturer : @library.Capturer,
) -> Captures {
  match CaptureSite::of(node) {
    Some(site) =>
      { captured: site.captures(scopes, capturer), node_hash: site.node_hash, }
    None => {
      let visitor = CapturesVisitor::new(Some(scopes), capturer)
      visitor.visit(node)
      {
        captured: visitor.finish(),
        node_hash: @library.LazyFingerprint::new(),
      }
    }
  }
}

///|
/// The result of [collect_captures].
priv struct Captures {
  captured : @library.Scope
  node_hash : @library.LazyFingerprint
}
