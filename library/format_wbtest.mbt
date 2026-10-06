// `Scope::prelude_path` panics like upstream
// (typst-library/src/foundations/scope.rs:249) when the path crosses two
// feature gates. The panic itself cannot be tested (the native test driver
// skips `panic` tests), so this checks its message.

///|
test "prelude path conflict message prints the middle segments like {:?}" {
  // Upstream: `let [first, path @ .., last] = path.as_slice()`, then
  // `{path:?}`: only the segments between the first and the last.
  inspect(
    prelude_path_conflict(["format", "bundle", "asset"], Html, Bundle),
    content=(
      #|cannot prelude from path ["bundle"] because it's gated by two different features: `html` and `bundle`
    ),
  )
  inspect(
    prelude_path_conflict(["format", "html"], Bundle, A11yExtras),
    content=(
      #|cannot prelude from path [] because it's gated by two different features: `bundle` and `a11y-extras`
    ),
  )
  // `{:?}` of a `&str` escapes like Rust.
  inspect(
    prelude_path_conflict(["a", "b\"c", "d\n", "e"], Html, Bundle),
    content=(
      #|cannot prelude from path ["b\"c", "d\n"] because it's gated by two different features: `html` and `bundle`
    ),
  )
}
