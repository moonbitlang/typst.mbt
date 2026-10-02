// Port of `syntect/src/easy.rs` (`HighlightLines`).

///|
/// Simple way to go directly from lines of text to colored tokens.
///
/// Depending on how you load the syntaxes (see the [`SyntaxSet`] docs), this
/// can either take strings with trailing `\n`s or without.
pub struct HighlightLines {
  priv highlighter : Highlighter
  priv parse_state : ParseState
  priv highlight_state : HighlightState
}

///|
pub fn HighlightLines::new(
  syntax : SyntaxReference,
  theme : Theme,
) -> HighlightLines {
  let highlighter = Highlighter::new(theme)
  let highlight_state = HighlightState::new(highlighter, ScopeStack::new())
  { highlighter, parse_state: ParseState::new(syntax), highlight_state, }
}

///|
/// Highlights a line of a file
pub fn HighlightLines::highlight_line(
  self : HighlightLines,
  line : String,
  syntax_set : SyntaxSet,
) -> Array[(Style, String)] raise SyntectError {
  let text = ByteIndex::new(line)
  let ops = self.parse_state.parse_line_indexed(text, syntax_set) catch {
    e => raise SyntectError::ParsingError(e)
  }
  highlight_iter(self.highlight_state, ops, text, self.highlighter)
}
