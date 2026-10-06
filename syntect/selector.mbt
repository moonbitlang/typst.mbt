// Port of `syntect/src/highlighting/selector.rs`.
//
// Code based on https://github.com/defuz/sublimate/blob/master/src/core/syntax/scope.rs
// released under the MIT license by @defuz

///|
/// A single selector consisting of a stack to match and a possible stack to
/// exclude from being matched.
pub(all) struct ScopeSelector {
  path : ScopeStack
  excludes : Array[ScopeStack]
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScopeSelector with Eq::{not_equal, equal}

///|
/// A selector set that matches anything matched by any of its component
/// selectors.
pub(all) struct ScopeSelectors {
  /// The selectors, if any of them match, that this matches
  selectors : Array[ScopeSelector]
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScopeSelectors with Eq::{not_equal, equal}

///|
/// Checks if this selector matches the given stack, returning the match
/// score if so.
pub fn ScopeSelector::does_match(
  self : ScopeSelector,
  stack : ArrayView[Scope],
) -> MatchPower? {
  // if there are any exclusions, and any one of them matches, then this
  // selector doesn't match
  if self.excludes
    .iter()
    .any(sel => sel.is_empty() || sel.does_match(stack) is Some(_)) {
    return None
  }
  if self.path.is_empty() {
    // an empty scope selector always matches with a score of 1
    Some(MatchPower(1.0))
  } else {
    self.path.does_match(stack)
  }
}

///|
/// If this selector is really just a single scope, return it
pub fn ScopeSelector::extract_single_scope(self : ScopeSelector) -> Scope? {
  if self.path.len() > 1 || !self.excludes.is_empty() || self.path.is_empty() {
    return None
  }
  Some(self.path.as_slice()[0])
}

///|
/// Extract all selectors for generating CSS
pub fn ScopeSelector::extract_scopes(self : ScopeSelector) -> Array[Scope] {
  self.path.scopes.copy()
}

///|
/// Parses a scope stack followed optionally by (one or more) " -" and then a
/// scope stack to exclude
pub fn ScopeSelector::from_str(
  s : StringView,
) -> ScopeSelector raise ParseScopeError {
  let excludes = []
  let mut path_str : StringView = ""
  for i, selector in s.split(" -").collect() {
    if i == 0 {
      path_str = selector
    } else {
      excludes.push(ScopeStack::from_str(selector))
    }
  }
  { path: ScopeStack::from_str(path_str), excludes, }
}

///|
/// Checks if any of the given selectors match the given scope stack. If so,
/// it returns a match score; higher match scores are stronger matches.
pub fn ScopeSelectors::does_match(
  self : ScopeSelectors,
  stack : ArrayView[Scope],
) -> MatchPower? {
  // `Iterator::max` returns the last of equal maxima.
  let mut best : MatchPower? = None
  for sel in self.selectors {
    if sel.does_match(stack) is Some(score) {
      match best {
        Some(b) if score < b => ()
        _ => best = Some(score)
      }
    }
  }
  best
}

///|
/// Parses a series of selectors separated by commas or pipes
pub fn ScopeSelectors::from_str(
  s : StringView,
) -> ScopeSelectors raise ParseScopeError {
  let selectors = []
  let mut start = 0
  for i in 0..<=s.length() {
    if i == s.length() || s.code_unit_at(i) == ',' || s.code_unit_at(i) == '|' {
      selectors.push(ScopeSelector::from_str(s[start:i]))
      start = i + 1
    }
  }
  { selectors, }
}
