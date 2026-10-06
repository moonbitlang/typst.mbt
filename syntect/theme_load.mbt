// Port of `syntect/src/highlighting/theme_load.rs` and the loading part of
// `theme_set.rs`.
//
// Code based on https://github.com/defuz/sublimate/blob/master/src/core/syntax/theme.rs
// released under the MIT license by @defuz

///|
pub(all) suberror ParseThemeError {
  IncorrectUnderlineOption
  IncorrectFontStyle(String)
  IncorrectColor
  IncorrectSyntax
  IncorrectSettings
  UndefinedSettings
  UndefinedScopeSettings(String)
  ColorShemeScopeIsNotObject
  ColorShemeSettingsIsNotObject
  ScopeSelectorIsNotString(String)
  DuplicateSettings
  ScopeParse(ParseScopeError)
}

///|
pub impl Show for ParseThemeError with fn output(self, logger) {
  match self {
    IncorrectUnderlineOption =>
      logger.write_string("Incorrect underline option")
    IncorrectFontStyle(s) => logger.write_string("Incorrect font style: \{s}")
    IncorrectColor => logger.write_string("Incorrect color")
    IncorrectSyntax => logger.write_string("Incorrect syntax")
    IncorrectSettings => logger.write_string("Incorrect settings")
    UndefinedSettings => logger.write_string("Undefined settings")
    UndefinedScopeSettings(s) =>
      logger.write_string("Undefined scope settings: \{s}")
    ColorShemeScopeIsNotObject =>
      logger.write_string("Color sheme scope is not object")
    ColorShemeSettingsIsNotObject =>
      logger.write_string("Color sheme settings is not object")
    ScopeSelectorIsNotString(s) =>
      logger.write_string("Scope selector is not string: \{s}")
    DuplicateSettings => logger.write_string("Duplicate settings")
    ScopeParse(e) => logger.write_string("Scope parse error: \{e}")
  }
}

///|
pub fn UnderlineOption::from_str(
  s : String,
) -> UnderlineOption raise ParseThemeError {
  match s {
    "underline" => Underline
    "stippled_underline" => StippledUnderline
    "squiggly_underline" => SquigglyUnderline
    _ => raise IncorrectUnderlineOption
  }
}

///|
fn UnderlineOption::parse_settings(
  settings : Settings,
) -> UnderlineOption raise ParseThemeError {
  match settings {
    String(value) => UnderlineOption::from_str(value)
    _ => raise IncorrectUnderlineOption
  }
}

///|
pub fn FontStyle::from_str(s : String) -> FontStyle raise ParseThemeError {
  let mut font_style = FontStyle::empty()
  for i in split_whitespace(s) {
    font_style = font_style.union(
      match i {
        "bold" => font_style_bold
        "underline" => font_style_underline
        "italic" => font_style_italic
        "normal" | "regular" => FontStyle::empty()
        s => raise IncorrectFontStyle(s.to_owned())
      },
    )
  }
  font_style
}

///|
pub fn Color::from_str(s : String) -> Color raise ParseThemeError {
  let chars = s.iter()
  if chars.next() != Some('#') {
    raise IncorrectColor
  }
  let d = []
  for char in chars {
    d.push(to_digit16(char))
  }
  match d.length() {
    3 => { r: d[0], g: d[1], b: d[2], a: 255, }
    6 =>
      { r: d[0] * 16 + d[1], g: d[2] * 16 + d[3], b: d[4] * 16 + d[5], a: 255, }
    8 =>
      {
        r: d[0] * 16 + d[1],
        g: d[2] * 16 + d[3],
        b: d[4] * 16 + d[5],
        a: d[6] * 16 + d[7],
      }
    _ => raise IncorrectColor
  }
}

///|
fn to_digit16(c : Char) -> Byte raise ParseThemeError {
  let v = if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    raise IncorrectColor
  }
  v.to_byte()
}

///|
fn Color::parse_settings(settings : Settings) -> Color raise ParseThemeError {
  match settings {
    String(value) => Color::from_str(value)
    _ => raise IncorrectColor
  }
}

///|
fn StyleModifier::parse_settings(
  settings : Settings,
) -> StyleModifier raise ParseThemeError {
  guard settings is Object(obj) else { raise ColorShemeScopeIsNotObject }
  let font_style = match obj.get("fontStyle") {
    Some(String(value)) => Some(FontStyle::from_str(value))
    None => None
    Some(c) => raise IncorrectFontStyle(c.to_string())
  }
  let foreground = match obj.get("foreground") {
    Some(String(value)) => Some(Color::from_str(value))
    None => None
    _ => raise IncorrectColor
  }
  let background = match obj.get("background") {
    Some(String(value)) => Some(Color::from_str(value))
    None => None
    _ => raise IncorrectColor
  }
  { foreground, background, font_style, }
}

///|
fn ThemeItem::parse_settings(
  settings : Settings,
) -> ThemeItem raise ParseThemeError {
  guard settings is Object(obj) else { raise ColorShemeScopeIsNotObject }
  let scope = match obj.get("scope") {
    Some(String(value)) =>
      ScopeSelectors::from_str(value) catch {
        e => raise ScopeParse(e)
      }
    _ => raise ScopeSelectorIsNotString("")
  }
  let style = match obj.get("settings") {
    Some(settings) => StyleModifier::parse_settings(settings)
    None => raise IncorrectSettings
  }
  { scope, style, }
}

///|
fn ThemeSettings::parse_settings(
  json : Settings,
) -> ThemeSettings raise ParseThemeError {
  let settings : ThemeSettings = ThemeSettings::default()
  guard json is Object(obj) else { raise ColorShemeSettingsIsNotObject }
  fn color(value : Settings) -> Color? {
    try Color::parse_settings(value) catch {
      _ => None
    } noraise {
      c => Some(c)
    }
  }
  fn underline(value : Settings) -> UnderlineOption? {
    try UnderlineOption::parse_settings(value) catch {
      _ => None
    } noraise {
      u => Some(u)
    }
  }
  let mut s = settings
  for key, value in obj {
    s = match key {
      "foreground" => { ..s, foreground: color(value), }
      "background" => { ..s, background: color(value), }
      "caret" => { ..s, caret: color(value), }
      "lineHighlight" => { ..s, line_highlight: color(value), }
      "misspelling" => { ..s, misspelling: color(value), }
      "minimapBorder" => { ..s, minimap_border: color(value), }
      "accent" => { ..s, accent: color(value), }
      "popupCss" => { ..s, popup_css: value.as_str(), }
      "phantomCss" => { ..s, phantom_css: value.as_str(), }
      "bracketContentsForeground" =>
        { ..s, bracket_contents_foreground: color(value), }
      "bracketContentsOptions" =>
        { ..s, bracket_contents_options: underline(value), }
      "bracketsForeground" => { ..s, brackets_foreground: color(value), }
      "bracketsBackground" => { ..s, brackets_background: color(value), }
      "bracketsOptions" => { ..s, brackets_options: underline(value), }
      "tagsForeground" => { ..s, tags_foreground: color(value), }
      "tagsOptions" => { ..s, tags_options: underline(value), }
      "highlight" => { ..s, highlight: color(value), }
      "findHighlight" => { ..s, find_highlight: color(value), }
      "findHighlightForeground" =>
        { ..s, find_highlight_foreground: color(value), }
      "gutter" => { ..s, gutter: color(value), }
      "gutterForeground" => { ..s, gutter_foreground: color(value), }
      "selection" => { ..s, selection: color(value), }
      "selectionForeground" => { ..s, selection_foreground: color(value), }
      "selectionBorder" => { ..s, selection_border: color(value), }
      "inactiveSelection" => { ..s, inactive_selection: color(value), }
      "inactiveSelectionForeground" =>
        { ..s, inactive_selection_foreground: color(value), }
      "guide" => { ..s, guide: color(value), }
      "activeGuide" => { ..s, active_guide: color(value), }
      "stackGuide" => { ..s, stack_guide: color(value), }
      "shadow" => { ..s, shadow: color(value), }
      _ => s // E.g. "shadowWidth" and "invisibles" are ignored
    }
  }
  s
}

///|
pub fn Theme::parse_settings(
  settings : Settings,
) -> Theme raise ParseThemeError {
  guard settings is Object(obj) else { raise IncorrectSyntax }
  let name = match obj.get("name") {
    Some(String(name)) => Some(name)
    None => None
    _ => raise IncorrectSyntax
  }
  let author = match obj.get("author") {
    Some(String(author)) => Some(author)
    None => None
    _ => raise IncorrectSyntax
  }
  let items = match obj.get("settings") {
    Some(Array(items)) => items
    _ => raise IncorrectSyntax
  }
  let mut settings = match items.get(0) {
    Some(Object(obj)) =>
      match obj.get("settings") {
        Some(settings) => ThemeSettings::parse_settings(settings)
        None => raise UndefinedSettings
      }
    _ => raise UndefinedSettings
  }
  if obj.get("gutterSettings") is Some(Object(obj)) {
    for key, value in obj {
      let color : Color? = try Color::parse_settings(value) catch {
        _ => None
      } noraise {
        c => Some(c)
      }
      match key {
        "background" =>
          settings = {
            ..settings,
            gutter: if settings.gutter is Some(_) {
              settings.gutter
            } else {
              color
            },
          }
        "foreground" =>
          settings = {
            ..settings,
            gutter_foreground: if settings.gutter_foreground is Some(_) {
              settings.gutter_foreground
            } else {
              color
            },
          }
        _ => ()
      }
    }
  }
  let scopes = []
  for i in 1..<items.length() {
    // TODO option to disable best effort parsing and bubble up warnings
    try ThemeItem::parse_settings(items[i]) catch {
      _ => ()
    } noraise {
      item => scopes.push(item)
    }
  }
  { name, author, settings, scopes, }
}

///|
/// Common error type used by syntax and theme loading
pub(all) suberror LoadingError {
  /// a syntax file was invalid in some way (with the path)
  ParseSyntax(ParseSyntaxError, String)
  /// a theme file was invalid in some way
  ParseTheme(ParseThemeError)
  /// a theme's Plist syntax was invalid in some way
  ReadSettings(SettingsError)
}

///|
pub impl Show for LoadingError with fn output(self, logger) {
  match self {
    ParseSyntax(e, path) => logger.write_string("\{path}: \{e}")
    ParseTheme(_) => logger.write_string("Invalid syntax theme")
    ReadSettings(_) => logger.write_string("Invalid syntax theme settings")
  }
}

///|
/// Loads a theme given a readable stream (upstream
/// `ThemeSet::load_from_reader`).
pub fn ThemeSet::load_from_reader(bytes : Bytes) -> Theme raise LoadingError {
  let settings = read_plist(bytes) catch { e => raise ReadSettings(e) }
  Theme::parse_settings(settings) catch {
    e => raise ParseTheme(e)
  }
}

///|
/// A set of themes (upstream `ThemeSet`; only its loading is ported).
pub(all) struct ThemeSet {
  themes : Map[String, Theme]
}
