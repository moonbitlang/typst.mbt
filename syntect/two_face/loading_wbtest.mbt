///|
fn describe_pieces(pieces : Array[(@syntect.Style, String)]) -> String {
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
  "line " + parts.join(" ") + "\n"
}

///|
fn rust_debug_strs(xs : Array[String]) -> String {
  "[" + xs.map(x => @unicode.rust_debug_str(x)).join(", ") + "]"
}

///|
fn describe_syntax_loading(yaml : String, code : String) -> String {
  let out = StringBuilder()
  try @syntect.SyntaxDefinition::load_from_str(yaml, false, None) catch {
    e => {
      out.write_string("error \{e}\n")
      if e is InvalidYaml(se) {
        let m = se.marker()
        out.write_string("at \{m.index()} \{m.line()} \{m.col()}\n")
      }
    }
  } noraise {
    def => {
      let builder = @syntect.SyntaxSetBuilder::new()
      builder.add(def)
      let set = builder.build()
      let syntax = set.syntaxes()[0]
      out.write_string(
        "syntax \{@unicode.rust_debug_str(syntax.name)} \{rust_debug_strs(syntax.file_extensions)} \{syntax.scope} hidden=\{syntax.hidden}\n",
      )
      let hl = @syntect.HighlightLines::new(syntax, test_raw_theme())
      for line in @syntax.split_newlines(code) {
        try hl.highlight_line(line, set) catch {
          e => out.write_string("line error \{e}\n")
        } noraise {
          pieces => out.write_string(describe_pieces(pieces))
        }
      }
    }
  }
  out.to_string()
}

///|
fn describe_color(c : @syntect.Color?) -> String {
  match c {
    Some(c) => hex2(c.r) + hex2(c.g) + hex2(c.b) + hex2(c.a)
    None => "-"
  }
}

///|
fn rust_debug_opt_str(s : String?) -> String {
  match s {
    Some(s) => "Some(\{@unicode.rust_debug_str(s)})"
    None => "None"
  }
}

///|
fn describe_theme(theme : @syntect.Theme) -> String {
  let c = describe_color
  let out = StringBuilder()
  out.write_string(
    "name \{rust_debug_opt_str(theme.name)} author \{rust_debug_opt_str(theme.author)}\n",
  )
  let s = theme.settings
  out.write_string(
    "settings fg \{c(s.foreground)} bg \{c(s.background)} caret \{c(s.caret)} gutter \{c(s.gutter)} gutter_fg \{c(s.gutter_foreground)} line \{c(s.line_highlight)} popup \{rust_debug_opt_str(s.popup_css)}\n",
  )
  for item in theme.scopes {
    let sels = item.scope.selectors.map(sel => {
      let path = sel.path.scopes.map(s => s.build_string()).join(" ")
      let ex = sel.excludes
        .map(e => e.scopes.map(s => s.build_string()).join(" "))
        .join(",")
      path + "|" + ex
    })
    let fs = match item.style.font_style {
      Some(f) => "Some(\{f.bits().to_int()})"
      None => "None"
    }
    out.write_string(
      "item \{sels.join(";")} fg \{c(item.style.foreground)} bg \{c(item.style.background)} fs \{fs}\n",
    )
  }
  out.to_string()
}

///|
test "syntax loading matches syntect" {
  let failures = []
  for case in syntax_loading_cases {
    let (yaml, code, expected) = case
    let actual = describe_syntax_loading(yaml, code)
    if actual != expected {
      failures.push((yaml, expected, actual))
    }
  }
  if !failures.is_empty() {
    let (yaml, expected, actual) = failures[0]
    fail(
      "\{failures.length()}/\{syntax_loading_cases.length()} cases differ; first:\n\{yaml}\nexpected:\n\{expected}\nactual:\n\{actual}",
    )
  }
}

///|
test "theme loading matches syntect" {
  let failures = []
  for case in theme_loading_cases {
    let (xml, expected) = case
    let actual = try
      @syntect.ThemeSet::load_from_reader(@utf8.encode(xml))
    catch {
      e => "error \{e}\n"
    } noraise {
      theme => describe_theme(theme)
    }
    if actual != expected {
      failures.push((xml, expected, actual))
    }
  }
  if !failures.is_empty() {
    let (xml, expected, actual) = failures[0]
    fail(
      "\{failures.length()}/\{theme_loading_cases.length()} cases differ; first:\n\{xml}\nexpected:\n\{expected}\nactual:\n\{actual}",
    )
  }
}
