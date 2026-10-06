// Port of `syntect/src/highlighting/theme.rs`.
//
// Code based on https://github.com/defuz/sublimate/blob/master/src/core/syntax/theme.rs
// released under the MIT license by @defuz

///|
/// A theme parsed from a `.tmTheme` file.
///
/// This contains additional fields like `name` and `author`.
pub(all) struct Theme {
  name : String?
  author : String?
  /// External settings for the editor using this theme
  settings : ThemeSettings
  /// The color scheme of the theme
  scopes : Array[ThemeItem]
}

///|
/// Properties for a whole theme that is not affected by any scope.
pub(all) struct ThemeSettings {
  /// The default color for text.
  foreground : Color?
  /// The default backgound color of the view.
  background : Color?
  /// Color of the caret.
  caret : Color?
  /// Color of the line the caret is in.
  line_highlight : Color?
  /// The color to use for the squiggly underline drawn under misspelled words.
  misspelling : Color?
  /// The color of the border drawn around the viewport area of the minimap.
  minimap_border : Color?
  /// A color made available for use by the theme.
  accent : Color?
  /// CSS passed to popups.
  popup_css : String?
  /// CSS passed to phantoms.
  phantom_css : String?
  /// Color of bracketed sections of text when the caret is in a bracketed
  /// section.
  bracket_contents_foreground : Color?
  /// Controls certain options when the caret is in a bracket section.
  bracket_contents_options : UnderlineOption?
  /// Foreground color of the brackets when the caret is next to a bracket.
  brackets_foreground : Color?
  /// Background color of the brackets when the caret is next to a bracket.
  brackets_background : Color?
  /// Controls certain options when the caret is next to a bracket.
  brackets_options : UnderlineOption?
  /// Color of tags when the caret is next to a tag.
  tags_foreground : Color?
  /// Controls certain options when the caret is next to a tag.
  tags_options : UnderlineOption?
  /// The border color for "other" matches.
  highlight : Color?
  /// Background color of regions matching the current search.
  find_highlight : Color?
  /// Text color of regions matching the current search.
  find_highlight_foreground : Color?
  /// Background color of the gutter.
  gutter : Color?
  /// Foreground color of the gutter.
  gutter_foreground : Color?
  /// The background color of selected text.
  selection : Color?
  /// A color that will override the scope-based text color of the selection.
  selection_foreground : Color?
  /// Color of the selection regions border.
  selection_border : Color?
  /// The background color of a selection in a view that is not currently
  /// focused.
  inactive_selection : Color?
  /// A color that will override the scope-based text color of the selection
  /// in a view that is not currently focused.
  inactive_selection_foreground : Color?
  /// Color of the guides displayed to indicate nesting levels.
  guide : Color?
  /// Color of the guide lined up with the caret.
  active_guide : Color?
  /// Color of the current guide’s parent guide level.
  stack_guide : Color?
  /// The color of the shadow used when a text area can be horizontally
  /// scrolled.
  shadow : Color?
} derive(Default)

///|
pub extend ThemeSettings with Default::{default}

///|
/// A component of a theme meant to highlight a specific thing (e.g string
/// literals) in a certain way.
pub(all) struct ThemeItem {
  /// Target scope name.
  scope : ScopeSelectors
  /// The style to use for this component
  style : StyleModifier
}

///|
pub(all) enum UnderlineOption {
  None
  Underline
  StippledUnderline
  SquigglyUnderline
} derive(Eq)
