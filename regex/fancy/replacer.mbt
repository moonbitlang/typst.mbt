// Port of `fancy-regex` 0.16.2 `src/replacer.rs`. Upstream's `Replacer`
// trait (implemented for strings, `NoExpand` and closures) becomes an enum.

///|
/// Replacer describes types that can be used to replace matches in a string.
pub(all) enum Replacer {
  /// A template string: `$N`/`$name` are expanded (see `Captures::expand`).
  Expand(String)
  /// A literal replacement string (no `$` expansion).
  NoExpand(String)
  /// A function computing the replacement from the captures.
  Func((Captures) -> String)
}

///|
/// Appends text to `dst` to replace the current match.
pub fn Replacer::replace_append(
  self : Replacer,
  caps : Captures,
  dst : StringBuilder,
) -> Unit {
  match self {
    Expand(s) => caps.expand(s, dst)
    NoExpand(s) => dst.write_string(s)
    Func(f) => dst.write_string(f(caps))
  }
}

///|
/// Return a fixed unchanging replacement string, if the replacement does not
/// need any expansion.
pub fn Replacer::no_expansion(self : Replacer) -> String? {
  match self {
    Expand(s) => if s.contains_char('$') { None } else { Some(s) }
    NoExpand(s) => Some(s)
    Func(_) => None
  }
}
