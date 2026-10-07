// The `watch` command on the targets that cannot watch files (wasm-gc, js:
// `moonbitlang/async`, which `kit/watcher` is built on, has no file system
// watcher there). See `watch.mbt` for the others.

///|
/// Execute a watching compilation command.
fn watch(_command : WatchCommand) -> Unit raise HintedFailure {
  raise bail(
    "watching files is not supported by this build (\{@watcher.unsupported}); use `typst compile` instead",
  )
}
