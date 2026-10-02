// Port of `typst-realize/src/spaces.rs`: the space collapsing and discarding
// infrastructure for realization.

///|
/// State kept for space collapsing/discarding.
priv enum SpaceState {
  /// When destructive, we skip any future spaces.
  Destructive
  /// When supportive, we usually keep future spaces, but we will discard
  /// newline spaces if the text surrounding a newline space returns true for
  /// [@unicode.discard_space_between].
  ///
  /// Text can be empty if this is not a textual element. This is easier than
  /// using an `Option`.
  Supportive(text~ : String)
  /// A current space. Spaces collapse into one with the styles of the first
  /// space by skipping following spaces, and they set `had_newline` to true
  /// if any space in a group had a newline.
  ///
  /// Since `had_newline` may update based on a future space, all spaces need
  /// to remember the previous text of a supportive element to do the
  /// [@unicode.discard_space_between] check.
  ///
  /// The `had_newline` grouping is done so that spaces before line comments
  /// don't add new space. E.g. `x //\n`
  Space(prev_text~ : String, had_newline~ : Bool)
}

///|
/// What action to take for space collapsing/discarding.
///
/// This is in addition to updating the [SpaceState] itself, which is
/// necessary even when the action is `Skip`.
priv enum SpaceAction {
  /// Invisible elements are themselves kept, but neither contain text nor
  /// affect the space collapsing state.
  Invisible
  /// Avoid adding the current space element.
  Skip
  /// Discard the preceding space, but keep the current element.
  ///
  /// This is not returned unless there was a preceding space.
  Discard
  /// Keep the current element and don't change any preceding spaces (if any).
  ///
  /// This is given for destructive elements that weren't preceded by a space.
  Keep
}

///|
/// Run the space collapsing algorithm on `buf[start..]`. This discards space
/// elements that are at the edges of the range or in the vicinity of
/// destructive elements and collapses adjacent spaces into one with the styles
/// of the first space.
///
/// This is implemented efficiently in-place by shifting elements in the buffer
/// to the left whenever we discard or collapse a space.
fn collapse_spaces(buf : Array[Pair], start : Int) -> Unit {
  let mut cursor = start
  let mut prev_space = cursor
  let mut state = SpaceState::Destructive

  // We do one pass over the elements, backshifting everything as necessary
  // when a space collapses. The variable `cursor` is our cursor in the
  // result. The variable `i` is our cursor in the original elements. At all
  // times, we have `cursor <= i`, so we can do it in-place.
  for i in start..<buf.length() {
    let (content, styles) = buf[i]
    let (action, next) = collapse_transition(state, content, styles)
    state = next
    match action {
      Invisible => ()
      Skip => continue
      Discard => {
        copy_within(buf, prev_space + 1, cursor, prev_space)
        cursor -= 1
      }
      Keep => prev_space = cursor
    }

    // Copy over normal elements (in place).
    if cursor < i {
      buf[cursor] = buf[i]
    }
    cursor += 1
  }
  if state is Space(..) {
    copy_within(buf, prev_space + 1, cursor, prev_space)
    cursor -= 1
  }

  // Delete all the excess that's left due to the gaps produced by spaces.
  buf.truncate(cursor)
}

///|
/// Copies `buf[src_start..src_end]` to `buf[dest..]` (upstream
/// `slice::copy_within`).
fn copy_within(
  buf : Array[Pair],
  src_start : Int,
  src_end : Int,
  dest : Int,
) -> Unit {
  if dest <= src_start {
    for k in 0..<(src_end - src_start) {
      buf[dest + k] = buf[src_start + k]
    }
  } else {
    for k = src_end - src_start - 1; k >= 0; k = k - 1 {
      buf[dest + k] = buf[src_start + k]
    }
  }
}

///|
/// How to transition state for the space collapsing algorithm.
fn collapse_transition(
  state : SpaceState,
  content : Content,
  styles : StyleChain,
) -> (SpaceAction, SpaceState) {
  if content.is_(@library.tag_elem()) {
    (Invisible, state)
  } else if @library.HElem::of(content) is Some(elem) {
    if elem.amount().is_fractional() || elem.weak(styles) {
      for_destructive(state)
    } else {
      (Invisible, state)
    }
  } else if content.is_(@library.linebreak_elem()) ||
    // We want to collapse spaces that would otherwise be protected and show
    // up as spans with `white-space: pre-wrap`.
    (
      @library.HtmlElem::of(content) is Some(elem) &&
      elem.tag().is_whitespace_collapsing()
    ) {
    for_destructive(state)
  } else if @library.SpaceElem::of(content) is Some(elem) {
    for_space(state, elem.had_newline())
  } else if @library.TextElem::of(content) is Some(elem) {
    for_supportive(state, elem.text())
  } else {
    for_supportive(state, "")
  }
}

///|
/// How to transition state for space collapsing during regex matching.
fn collapse_transition_textual(
  state : SpaceState,
  content : Content,
  styles : StyleChain,
) -> (SpaceAction, SpaceState, String) {
  // Roughly ordered from most to least common.
  if content.is_(@library.tag_elem()) {
    (Invisible, state, "")
  } else if content.is_(@library.linebreak_elem()) {
    let (action, state) = for_destructive(state)
    (action, state, "\n")
  } else if @library.SpaceElem::of(content) is Some(elem) {
    let (action, state) = for_space(state, elem.had_newline())
    (action, state, " ")
  } else if @library.TextElem::of(content) is Some(elem) {
    let text = elem.text()
    let (action, state) = for_supportive(state, text)
    (action, state, text)
  } else if @library.SmartQuoteElem::of(content) is Some(elem) {
    let text = if elem.double(styles) { "\"" } else { "'" }
    let (action, state) = for_supportive(state, text)
    (action, state, text)
  } else {
    let name = content.elem().name()
    abort("tried to find regex match in a non-textual element: \{name}")
  }
}

///|
/// The state transition for a destructive element.
fn for_destructive(state : SpaceState) -> (SpaceAction, SpaceState) {
  if state is Space(..) {
    (Discard, Destructive)
  } else {
    (Keep, Destructive)
  }
}

///|
/// The state transition for a space element.
///
/// If any space in a group of spaces had a newline, we treat all spaces in that
/// group as having a newline.
fn for_space(
  state : SpaceState,
  had_newline : Bool,
) -> (SpaceAction, SpaceState) {
  match state {
    Destructive => (Skip, Destructive)
    Supportive(text=prev_text) => (Keep, Space(prev_text~, had_newline~))
    Space(prev_text~, had_newline=prev_nl) =>
      (Skip, Space(prev_text~, had_newline=prev_nl || had_newline))
  }
}

///|
/// The state transition for a supportive element. `text` should be empty if
/// this is not a textual element.
fn for_supportive(
  state : SpaceState,
  text : String,
) -> (SpaceAction, SpaceState) {
  if state is Space(prev_text~, had_newline=true) &&
    @unicode.discard_space_between(prev_text, text) {
    (Discard, Supportive(text~))
  } else {
    (Keep, Supportive(text~))
  }
}
