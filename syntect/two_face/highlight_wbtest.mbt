///|
/// Typst's `RAW_THEME` (`typst-library/src/text/raw.rs`), for the tests.
fn test_raw_theme() -> @syntect.Theme {
  fn color(s : String) -> @syntect.Color {
    @syntect.Color::from_str(s) catch {
      _ => abort("bad color")
    }
  }

  fn item(
    scope : String,
    fg : String?,
    fs : @syntect.FontStyle?,
  ) -> @syntect.ThemeItem {
    {
      scope: @syntect.ScopeSelectors::from_str(scope) catch {
        _ => abort("bad scope")
      },
      style: { foreground: fg.map(color), background: None, font_style: fs },
    }
  }

  let bold = @syntect.font_style_bold
  let italic = @syntect.font_style_italic
  let underline = @syntect.font_style_underline
  {
    name: Some("Typst Light"),
    author: Some("The Typst Project Developers"),
    settings: @syntect.ThemeSettings::default(),
    scopes: [
      item("comment", Some("#74747c"), None),
      item("constant.character.escape", Some("#1d6c76"), None),
      item("markup.bold", None, Some(bold)),
      item("markup.italic", None, Some(italic)),
      item("markup.underline", None, Some(underline)),
      item("markup.raw", Some("#6b6b6f"), None),
      item("string.other.math.typst", None, None),
      item("punctuation.definition.math", Some("#198810"), None),
      item("keyword.operator.math, punctuation.math.typst", Some("#1d6c76"), None),
      item("markup.heading, entity.name.section", None, Some(bold)),
      item("markup.heading.typst", None, Some(bold | underline)),
      item("punctuation.definition.list", Some("#8b41b1"), None),
      item("markup.list.term", None, Some(bold)),
      item("entity.name.label, markup.other.reference", Some("#1d6c76"), None),
      item("keyword, constant.language, variable.language", Some("#d73948"), None),
      item("storage.type, storage.modifier", Some("#d73948"), None),
      item("constant", Some("#b60157"), None),
      item("string", Some("#198810"), None),
      item("entity.name, variable.function, support", Some("#4b69c6"), None),
      item("support.macro", Some("#16718d"), None),
      item("meta.annotation", Some("#301414"), None),
      item("entity.other, meta.interpolation", Some("#8b41b1"), None),
      item("meta.diff.range", Some("#8b41b1"), None),
      item("markup.inserted, meta.diff.header.to-file", Some("#198810"), None),
      item("markup.deleted, meta.diff.header.from-file", Some("#d73948"), None),
      item(
        "meta.mapping.key.json string.quoted.double.json",
        Some("#4b69c6"),
        None,
      ),
      item(
        "meta.mapping.value.json string.quoted.double.json",
        Some("#198810"),
        None,
      ),
    ],
  }
}

///|
fn debug_op(op : @syntect.ScopeStackOp) -> String {
  match op {
    Push(scope) => "Push(\{scope.debug()})"
    Pop(n) => "Pop(\{n})"
    Clear(TopN(n)) => "Clear(TopN(\{n}))"
    Clear(All) => "Clear(All)"
    Restore => "Restore"
    Noop => "Noop"
  }
}

///|
fn hex2(b : Byte) -> String {
  let s = b.to_int().to_string(radix=16)
  if s.length() == 1 {
    "0" + s
  } else {
    s
  }
}

///|
fn describe_highlight(token : String, code : String) -> String? {
  let set = extra_no_newlines()
  guard set.find_syntax_by_token(token) is Some(syntax) else { return None }
  let theme = test_raw_theme()
  let out = StringBuilder()
  out.write_string("syntax \{syntax.name}\n")
  let hl = @syntect.HighlightLines::new(syntax, theme)
  let ps = @syntect.ParseState::new(syntax)
  for line in @syntax.split_newlines(code) {
    try ps.parse_line(line, set) catch {
      e => out.write_string("ops error \{e}\n")
    } noraise {
      ops =>
        out.write_string(
          "ops " + ops.map(o => "\{o.0}:\{debug_op(o.1)}").join(" ") + "\n",
        )
    }
    try hl.highlight_line(line, set) catch {
      e => out.write_string("line error \{e}\n")
    } noraise {
      pieces => {
        let parts = pieces.map(p => {
          let (style, s) = p
          let c = style.foreground
          hex2(c.r) +
          hex2(c.g) +
          hex2(c.b) +
          hex2(c.a) +
          "/\{style.font_style.bits().to_int()}/" +
          @unicode.rust_debug_str(s)
        })
        out.write_string("line " + parts.join(" ") + "\n")
      }
    }
  }
  Some(out.to_string())
}

///|
test "highlighting matches syntect" {
  let failures = []
  for case in highlight_cases {
    let (token, code, expected) = case
    let actual = describe_highlight(token, code)
    if actual != Some(expected) {
      failures.push((token, expected, actual))
    }
  }
  if !failures.is_empty() {
    let (token, expected, actual) = failures[0]
    fail(
      "\{failures.length()}/\{highlight_cases.length()} cases differ; first: \{token}\nexpected:\n\{expected}\nactual:\n\{actual.unwrap_or("<no syntax>")}",
    )
  }
}
