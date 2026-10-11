// Memoized page runs and documents (not upstream: the stores behind
// upstream's `#[comemo::memoize]` on `layout_page_run_impl`,
// `typst-layout/src/pages/run.rs:78`, and on `layout_document_impl` and
// `layout_document_for_bundle_impl`, `typst-layout/src/pages/mod.rs:55` and
// `:102`; `docs/incremental-design.md`, section 8, slice 3).
//
// Both go through [memoize], with the rules of `memo.mbt`: an entry is
// found by the fingerprint of the hashed arguments (the children and the
// initial styles of a run, the content and the styles of a document),
// with the resolved locator and the route in the key where upstream tracks
// them; it keeps the arguments for the exact comparison, the library, the
// world reads, the introspector reads and the sink of the call, and it has
// comemo's age. What is specific to them:
//
// - The results are not frames but what the layout package makes of them
//   (`LayoutedPage`s, a `PagedDocument`), so the store is generic and the
//   caller says how a result is copied and whether it may be kept. A
//   result holds every frame of a run or of a document, and
//   `finalize_page` and whoever is handed a document write to what they
//   get: what an entry keeps and what it hands out are different objects,
//   on storing and on every hit ([memoize], `copy`).
// - A document is laid out once per iteration of the introspection loop
//   (`typst/lib.mbt`, `compile_scoped`), each time against the
//   introspector of the document before. The entry of iteration one was
//   computed with an empty introspector and is found by the first
//   iteration of every later compilation (all empty introspectors have
//   one number); a document that is found has the introspector it had, so
//   the entry of the next iteration is found by that number, without a
//   replay of its reads. What the loop then validates, the reads of the
//   document against the document's own introspector, is answered from
//   the table of `ReadAccelerator` (`introspector.mbt`).

///|
/// The arguments of a memoized page layout that must be equal for reuse:
/// the children of a page run with their styles, or the content of a
/// document, and the styles.
priv struct PagesInput {
  /// The content of a document (`None` for a page run).
  content : Content?
  /// The children of a page run (none for a document). An entry keeps an
  /// array of its own ([memoized_pages]): the view of the call is into the
  /// array of the realization, which page collection writes to.
  mut children : ArrayView[Pair]
  styles : StyleChain
  /// What the recording check calls the call (`memo_check.mbt`).
  label : String
}

///|
impl Eq for PagesInput with fn equal(self, other) {
  let n = self.children.length()
  if n != other.children.length() {
    return false
  }
  match (self.content, other.content) {
    (None, None) => ()
    (Some(a), Some(b)) => if !content_memo_equal(a, b) { return false }
    _ => return false
  }
  if !chain_memo_equal(self.styles, other.styles) {
    return false
  }
  for i in 0..<n {
    let (a, x) = self.children[i]
    let (b, y) = other.children[i]
    if !content_memo_equal(a, b) || !chain_memo_equal(x, y) {
      return false
    }
  }
  true
}

///|
/// The kept results of one memoized function of the page level, for
/// [memoized_pages]: `T` is what the function returns (the pages of a run,
/// a document).
pub struct PageMemo[T] {
  priv store : MemoStore[T, PagesInput]
  /// What the recording check calls a call (`memo_check.mbt`).
  priv label : String
  /// The numbers of calls that were answered by an entry and that were
  /// computed, since the process started.
  priv mut found : Int
  priv mut computed : Int
}

///|
/// An empty store. `label` names its calls in the reports of the recording
/// check.
pub fn[T] PageMemo::new(label : String) -> PageMemo[T] {
  { store: MemoStore::new(), label, found: 0, computed: 0, }
}

///|
/// How many calls the store has answered with a kept result and how many
/// it has computed since the process started (for tests and measurements,
/// like [closure_memo_stats]). Calls outside of a compilation, with
/// memoization off or in a second run of the recording check are not
/// counted.
pub fn[T] PageMemo::stats(self : PageMemo[T]) -> (Int, Int) {
  (self.found, self.computed)
}

///|
/// The number of results that the store keeps (for tests and
/// measurements).
pub fn[T] PageMemo::entries(self : PageMemo[T]) -> Int {
  self.store.length()
}

///|
/// Memoize a layout function of the page level: of the `children` of a
/// page run and its initial `styles`, or of the `content` of a document
/// and its `styles`. `key` must fingerprint every argument of the call
/// except the engine (see the docs of `memo.mbt`: with the resolved
/// locator and the route); `f` must use the engine it is given.
///
/// `copy` makes of a result one that shares no object with it that can be
/// written to: it is called for what the entry keeps and for what every
/// later call is handed. `cacheable` says whether a result may be kept at
/// all ([frame_cacheable] for its frames, [paint_cacheable] for a fill).
pub fn[T] memoized_pages(
  memo : PageMemo[T],
  engine : Engine,
  key : MemoKey,
  content : Content?,
  children : ArrayView[Pair],
  styles : StyleChain,
  copy : (T) -> T,
  cacheable : (T) -> Bool,
  f : (Engine) -> T raise SourceError,
) -> T raise SourceError {
  let input : PagesInput = { content, children, styles, label: memo.label, }
  // (A second run of the recording check computes what the first run
  // computed or found: it is not a call of its own.)
  let counted = memo_generation.val != 0 &&
    engine.world.in_scope() &&
    !memo_check_running.val
  let before = memo.computed
  let output = memoize(
    memo.store,
    engine,
    key,
    input,
    copy,
    engine => {
      if counted && !memo_check_running.val {
        memo.computed += 1
      }
      // The entry that this call may leave keeps the children in an array
      // of its own. (A call that is answered copies nothing.)
      if input.children.length() > 0 {
        input.children = input.children.to_owned()[:]
      }
      f(engine)
    },
    cacheable~,
    label=input => input.label,
  )
  if counted && memo.computed == before {
    memo.found += 1
  }
  output
}
