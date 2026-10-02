// Helpers for the generated rendering tests in `csl_gen_wbtest.mbt`. The
// scenario language and the dump format mirror
// `oracle/src/bin/gen_hayagriva_tests.rs`.

///|
fn run_csl_case(
  src : String,
  kind : String,
  style_name : String,
  spec : String,
) -> String {
  let library = if kind == "bib" {
    match from_biblatex_str(src) {
      Ok(l) => l
      Err(e) => abort("bib parse error: \{e.length()} errors")
    }
  } else {
    match from_yaml_str(src) {
      Ok(l) => l
      Err(e) => abort("yaml parse error: \{e.message}")
    }
  }
  run_csl_library(library, style_name, spec)
}

///|
/// Load a library and dump either the error or the full bibliography in two
/// styles (mirrors `load_dump` of the generator).
fn load_case(kind : String, src : String) -> String {
  let library = if kind == "bib" {
    match from_biblatex_str(src) {
      Ok(l) => l
      Err(errs) => {
        let out = StringBuilder()
        for e in errs {
          match e {
            Parse(e) =>
              out.write_string(
                "parse error: \{e.kind} @ \{e.span.start}..\{e.span.end}\n",
              )
            Type(e) =>
              out.write_string(
                "type error: \{e.kind} @ \{e.span.start}..\{e.span.end}\n",
              )
          }
        }
        return out.to_string()
      }
    }
  } else {
    match from_yaml_str(src) {
      Ok(l) => l
      Err(e) => {
        let loc = match e.location {
          Some(l) => "\{l.index}:\{l.line}:\{l.column}"
          None => "-"
        }
        return "yaml error: \{e.message} @ \{loc}\n"
      }
    }
  }
  let keys = library.keys()
  let out = StringBuilder()
  out.write_string("entries: \{keys.join(", ")}\n")
  if keys.is_empty() {
    return out.to_string()
  }
  for name in ["apa", "ieee", "chicago-notes"] {
    out.write_string("== \{name}\n")
    out.write_string(run_csl_library(library, name, keys.join("|")))
  }
  out.to_string()
}

///|
fn run_csl_library(
  library : Library,
  style_name : String,
  spec : String,
) -> String {
  let style = match ArchivedStyle::by_name(style_name) {
    Some(s) =>
      match s.get() {
        Independent(i) => i
        Dependent(_) => abort("dependent style")
      }
    None => abort("unknown style")
  }
  let locale_files = locales()
  let locale = @citationberg.LocaleCode("en-US")
  let driver = BibliographyDriver::new()
  for line in spec.split("\n") {
    if line.is_empty() {
      continue
    }
    let items = []
    for item in line.split("|") {
      let parts = item.split(";").map(p => p.to_owned()).collect()
      let entry = library.get(parts[0]).unwrap()
      let mut locator = None
      let mut hidden = false
      let mut purpose = None
      for i in 1..<parts.length() {
        let opt = parts[i]
        if opt.has_prefix("loc=") {
          let l = opt[4:].to_owned()
          let idx = l.find(":").unwrap()
          let kind = l[:idx].to_owned()
          let value = l[idx + 1:].to_owned()
          let kind : @citationberg.Locator = match kind {
            "page" => Page
            "chapter" => Chapter
            "section" => Section
            _ => Custom
          }
          locator = Some(SpecificLocator(kind, Str(value)))
        } else if opt.has_prefix("tloc=") {
          locator = Some(
            SpecificLocator(
              Custom,
              Transparent(TransparentLocator::new(opt[5:].to_owned())),
            ),
          )
        } else if opt.has_prefix("purpose=") {
          purpose = Some(
            match opt[8:].to_owned() {
              "author" => CitePurpose::Author
              "year" => Year
              "full" => Full
              _ => Prose
            },
          )
        } else if opt == "hidden" {
          hidden = true
        }
      }
      items.push(CitationItem::new(entry, locator, None, hidden, purpose))
    }
    driver.citation(
      CitationRequest::new(items, style, Some(locale), locale_files, None),
    )
  }
  let rendered = driver.finish({ style, locale: Some(locale), locale_files, })
  let out = StringBuilder()
  for i, c in rendered.citations {
    out.write_string("cite \{i}: \{dump_children(c.citation)}\n")
  }
  match rendered.bibliography {
    Some(bib) => {
      let align = match bib.second_field_align {
        None => "none"
        Some(Flush) => "flush"
        Some(Margin) => "margin"
      }
      out.write_string(
        "bib: hanging=\{bib.hanging_indent} align=\{align} line=\{bib.line_spacing} entry=\{bib.entry_spacing}\n",
      )
      for item in bib.items {
        let first = match item.first_field {
          Some(c) => dump_child(c)
          None => "-"
        }
        out.write_string(
          "[\{item.key}] \{first} | \{dump_children(item.content)}\n",
        )
      }
    }
    None => out.write_string("bib: none\n")
  }
  out.to_string()
}

///|
fn dump_fmt(f : Formatting) -> String {
  let parts = []
  match f.font_style {
    Normal => ()
    Italic => parts.push("i")
  }
  match f.font_variant {
    Normal => ()
    SmallCaps => parts.push("sc")
  }
  match f.font_weight {
    Normal => ()
    Bold => parts.push("b")
    Light => parts.push("l")
  }
  match f.text_decoration {
    None_ => ()
    Underline => parts.push("u")
  }
  match f.vertical_align {
    None_ => ()
    Baseline => parts.push("base")
    Sup => parts.push("sup")
    Sub => parts.push("sub")
  }
  if parts.is_empty() {
    ""
  } else {
    parts.join(",") + ":"
  }
}

///|
fn dump_children(c : ElemChildren) -> String {
  let out = StringBuilder()
  for child in c.0 {
    out.write_string(dump_child(child))
  }
  out.to_string()
}

///|
fn dump_child(c : ElemChild) -> String {
  match c {
    Text(f) => "{" + dump_fmt(f.formatting) + f.text + "}"
    Elem(e) => dump_elem(e)
    Markup(m) => "$" + m + "$"
    Link(text~, url~) =>
      "[" + dump_fmt(text.formatting) + text.text + "](" + url + ")"
    Transparent(cite_idx~, format~) =>
      "@" + dump_fmt(format) + cite_idx.to_string()
  }
}

///|
fn dump_elem(e : Elem) -> String {
  let display = match e.display {
    None => ""
    Some(Block) => "block"
    Some(LeftMargin) => "left-margin"
    Some(RightInline) => "right-inline"
    Some(Indent) => "indent"
  }
  let meta = match e.meta {
    None => ""
    Some(Names(_)) => "names"
    Some(Date) => "date"
    Some(Text) => "text"
    Some(Number) => "number"
    Some(Label) => "label"
    Some(CitationNumber) => "citation-number"
    Some(Name(_, i)) => "name:\{i}"
    Some(Entry(i)) => "entry:\{i}"
    Some(CitationLabel) => "citation-label"
  }
  "<" + display + "|" + meta + ">" + dump_children(e.children) + "</>"
}
