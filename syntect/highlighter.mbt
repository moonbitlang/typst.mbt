// Port of `syntect/src/highlighting/highlighter.rs`.
//
// Code based on https://github.com/defuz/sublimate/blob/master/src/core/syntax/highlighter.rs
// released under the MIT license by @defuz

///|
/// Basically a wrapper around a [`Theme`] preparing it to be used for
/// highlighting.
///
/// This is part of the API to preserve the possibility of caching matches
/// of the selectors of the theme on various scope paths or setting up some
/// kind of accelerator structure.
pub struct Highlighter {
  priv theme : Theme
  priv single_selectors : Array[(Scope, StyleModifier)]
  priv multi_selectors : Array[(ScopeSelector, StyleModifier)]
}

///|
/// Keeps a stack of scopes and styles as state between highlighting
/// different lines.
pub struct HighlightState {
  priv styles : Array[Style]
  priv single_caches : Array[ScoredStyle]
  path : ScopeStack
}

///|
/// Highlights a line of parsed code given a [`HighlightState`] and line of
/// changes from the parser (upstream `RangedHighlightIterator`, collected).
///
/// Yields the [`Style`], the text and well as the `Range` of the text in the
/// source string (UTF-8 offsets).
pub fn ranged_highlight(
  state : HighlightState,
  changes : Array[(Int, ScopeStackOp)],
  text : ByteIndex,
  highlighter : Highlighter,
) -> Array[(Style, String, (Int, Int))] {
  let out = []
  let mut index = 0
  let mut pos = 0
  while true {
    if pos == text.len() && index >= changes.length() {
      break
    }
    let (end, command) = if index < changes.length() {
      changes[index]
    } else {
      (text.len(), ScopeStackOp::Noop)
    }
    let style = match state.styles.last() {
      Some(style) => style
      None => Style::default_style()
    }
    let piece = text.slice(pos, end)
    let range = (pos, end)
    let m_path = state.path
    let m_styles = state.styles
    let m_caches = state.single_caches
    m_path.apply_with_hook(command, (op, cur_stack) => {
      match op {
        Push(_) => {
          // we can push multiple times so this might have changed
          let new_cache = match m_caches.last() {
            Some(prev_cache) =>
              highlighter.update_single_cache_for_push(prev_cache, cur_stack)
            None =>
              highlighter.update_single_cache_for_push(
                ScoredStyle::from_style(highlighter.get_default()),
                cur_stack,
              )
          }
          m_styles.push(
            highlighter.finalize_style_with_multis(new_cache, cur_stack),
          )
          m_caches.push(new_cache)
        }
        Pop => {
          m_styles.pop() |> ignore
          m_caches.pop() |> ignore
        }
      }
    }) catch {
      _ => break
    }
    pos = end
    index += 1
    if !piece.is_empty() {
      out.push((style, piece, range))
    }
  }
  out
}

///|
/// Highlights a line of parsed code (upstream `HighlightIterator`,
/// collected).
pub fn highlight_iter(
  state : HighlightState,
  changes : Array[(Int, ScopeStackOp)],
  text : ByteIndex,
  highlighter : Highlighter,
) -> Array[(Style, String)] {
  ranged_highlight(state, changes, text, highlighter).map(e => (e.0, e.1))
}

///|
/// Note that the `HighlightState` is not cached, it is used for an initial
/// stack of scopes.
pub fn HighlightState::new(
  highlighter : Highlighter,
  initial_stack : ScopeStack,
) -> HighlightState {
  let styles = [highlighter.get_default()]
  let single_caches = [ScoredStyle::from_style(styles[0])]
  for i in 0..<initial_stack.len() {
    let prefix = initial_stack.bottom_n(i + 1)
    let new_cache = highlighter.update_single_cache_for_push(
      single_caches[i],
      prefix,
    )
    styles.push(highlighter.finalize_style_with_multis(new_cache, prefix))
    single_caches.push(new_cache)
  }
  { styles, single_caches, path: initial_stack, }
}

///|
/// A style with the match power of each of its fields.
pub(all) struct ScoredStyle {
  foreground : (MatchPower, Color)
  background : (MatchPower, Color)
  font_style : (MatchPower, FontStyle)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScoredStyle with Eq::{not_equal, equal}

///|
fn ScoredStyle::apply(
  self : ScoredStyle,
  other : StyleModifier,
  score : MatchPower,
) -> ScoredStyle {
  {
    foreground: update_scored(self.foreground, other.foreground, score),
    background: update_scored(self.background, other.background, score),
    font_style: update_scored(self.font_style, other.font_style, score),
  }
}

///|
fn[T] update_scored(
  scored : (MatchPower, T),
  update : T?,
  score : MatchPower,
) -> (MatchPower, T) {
  if score > scored.0 && update is Some(u) {
    (score, u)
  } else {
    scored
  }
}

///|
fn ScoredStyle::to_style(self : ScoredStyle) -> Style {
  {
    foreground: self.foreground.1,
    background: self.background.1,
    font_style: self.font_style.1,
  }
}

///|
fn ScoredStyle::from_style(style : Style) -> ScoredStyle {
  {
    foreground: (MatchPower(-1.0), style.foreground),
    background: (MatchPower(-1.0), style.background),
    font_style: (MatchPower(-1.0), style.font_style),
  }
}

///|
pub fn Highlighter::new(theme : Theme) -> Highlighter {
  let single_selectors = []
  let multi_selectors = []
  for item in theme.scopes {
    for sel in item.scope.selectors {
      if sel.extract_single_scope() is Some(scope) {
        single_selectors.push((scope, item.style))
      } else {
        multi_selectors.push((sel, item.style))
      }
    }
  }
  // So that deeper matching selectors get checked first
  // (a stable sort by descending scope length).
  let single_selectors = stable_sort_by(single_selectors, (a, b) => {
    b.0.len().compare(a.0.len())
  })
  { theme, single_selectors, multi_selectors, }
}

///|
/// The default style in the absence of any matched rules.
///
/// Basically what plain text gets highlighted as.
pub fn Highlighter::get_default(self : Highlighter) -> Style {
  {
    foreground: self.theme.settings.foreground.unwrap_or(color_black),
    background: self.theme.settings.background.unwrap_or(color_white),
    font_style: FontStyle::empty(),
  }
}

///|
fn Highlighter::update_single_cache_for_push(
  self : Highlighter,
  cur : ScoredStyle,
  path : ArrayView[Scope],
) -> ScoredStyle {
  let mut new_style = cur
  let last_scope = path[path.length() - 1]
  for entry in self.single_selectors {
    let (scope, modif) = entry
    if !scope.is_prefix_of(last_scope) {
      continue
    }
    let single_score = scope.len().to_double() *
      @math.pow(2.0, (atom_len_bits * (path.length() - 1)).to_double())
    new_style = new_style.apply(modif, MatchPower(single_score))
  }
  new_style
}

///|
fn Highlighter::finalize_style_with_multis(
  self : Highlighter,
  cur : ScoredStyle,
  path : ArrayView[Scope],
) -> Style {
  let mut new_style = cur
  for entry in self.multi_selectors {
    let (sel, modif) = entry
    if sel.does_match(path) is Some(score) {
      new_style = new_style.apply(modif, score)
    }
  }
  new_style.to_style()
}

///|
/// Returns the fully resolved style for the given stack.
///
/// This operation is convenient but expensive. For reasonable performance,
/// the caller should be caching results.
pub fn Highlighter::style_for_stack(
  self : Highlighter,
  stack : ArrayView[Scope],
) -> Style {
  let mut single_cache = ScoredStyle::from_style(self.get_default())
  for i in 0..<stack.length() {
    single_cache = self.update_single_cache_for_push(
      single_cache,
      stack[0:i + 1],
    )
  }
  self.finalize_style_with_multis(single_cache, stack)
}

///|
/// Returns a [`StyleModifier`] which, if applied to the default style, would
/// generate the fully resolved style for this stack.
pub fn Highlighter::style_mod_for_stack(
  self : Highlighter,
  path : ArrayView[Scope],
) -> StyleModifier {
  let matching_items = []
  for item in self.theme.scopes {
    if item.scope.does_match(path) is Some(score) {
      matching_items.push((score, item))
    }
  }
  let sorted = stable_sort_by(matching_items, (a, b) => a.0.compare(b.0))
  let mut modifier : StyleModifier = {
    background: None,
    foreground: None,
    font_style: None,
  }
  for entry in sorted {
    modifier = modifier.apply(entry.1.style)
  }
  modifier
}

///|
/// A stable sort (Rust's `slice::sort_by`).
pub fn[T] stable_sort_by(xs : Array[T], cmp : (T, T) -> Int) -> Array[T] {
  let indexed = xs.mapi((i, x) => (i, x))
  indexed.sort_by((a, b) => {
    let c = cmp(a.1, b.1)
    if c != 0 {
      c
    } else {
      a.0.compare(b.0)
    }
  })
  indexed.map(p => p.1)
}
