// The `realize` stage (see `oracle/src/realize.rs`): evaluate every test
// case, then realize the content once as a document and once as a fragment
// with only the base native show rules, an empty introspector and empty base
// styles (plus the paged target), and dump the realized pairs. Locations are
// numbered in order of appearance.

///|
fn realize_report(rel : String, tc : TestCase) -> String {
  let source = TestWorld::main_source("tests/suite/" + rel, tc.body)
  let id = source.id()
  let library = test_library()
  let library = match parse_features(tc.attrs) {
    Some(f) => { ..library, features: f, }
    None => library
  }
  // The library with only the base native show rules.
  let library = { ..library, rules: @library.NativeRuleMap::new(), }
  let world : TestWorld = { main: source, library, }
  let content = @eval.eval_source(
    world,
    library,
    @library.Traced::new(),
    @library.Sink::new(),
    @library.Route::root(),
    source,
  ) catch {
    _ => return "eval error\n"
  }
  let content = content.content()
  let out = StringBuilder()
  for fragment in [false, true] {
    let dumper = Dumper::new()
    let sink = @library.Sink::new()
    let engine : @library.Engine = {
      world,
      library,
      introspector: @library.Introspector::empty(),
      traced: @library.Traced::new(),
      sink,
      // Like in `layout_document`/`html_document`, realization happens in a
      // nested route.
      route: @library.Route::extend(@library.Route::root()).unnested(),
    }
    let info = @library.DocumentInfo::new()
    let options = @library.DocumentFormatOptions::new(formats=library.formats)
    let fragment_kind = Ref::new(@library.FragmentKind::Block)
    let kind : @library.RealizationKind = if fragment {
      Fragment(kind=fragment_kind)
    } else {
      Document(info~, options~)
    }
    let styles = @library.StyleChain::new(@library.Styles::new()).chain_one(
      @library.TargetElem::set_target(Paged),
    )
    let locator = @library.Locator::root().split()
    out.write_string(if fragment { "--- fragment\n" } else { "--- document\n" })
    try @realize.realize(kind, engine, locator, content, styles) catch {
      @library.SourceError(errors) => {
        out.write_string("err\n")
        for diag in @typst.deduplicate(errors) {
          write_source_diag(out, world, id, diag)
        }
      }
    } noraise {
      pairs =>
        for pair in pairs {
          let c = dumper.content(pair.0)
          let s = dumper.chain(pair.1)
          out.write_string("\{c} @ \{s}\n")
        }
    }
    if fragment {
      let kind = match fragment_kind.val {
        Inline => "inline"
        Block => "block"
      }
      out.write_string("kind \{kind}\n")
    } else {
      out.write_string(info_line(info))
    }
    let delayed = sink.take_delayed()
    if !delayed.is_empty() {
      out.write_string("delayed\n")
      for diag in @typst.deduplicate(delayed) {
        write_source_diag(out, world, id, diag)
      }
    }
    let warnings = sink.warnings()
    if !warnings.is_empty() {
      out.write_string("warnings\n")
      for diag in @typst.deduplicate(warnings) {
        write_source_diag(out, world, id, diag)
      }
    }
  }
  out.to_string()
}

///|
/// The document info as a line.
fn info_line(info : @library.DocumentInfo) -> String {
  let opt = (s : String?) => {
    match s {
      Some(s) => @unicode.rust_debug_str(s)
      None => "none"
    }
  }
  let list = (l : Array[String]) => {
    "[" + l.map(s => @unicode.rust_debug_str(s)).join(", ") + "]"
  }
  let date = match info.date {
    Auto => "auto"
    Custom(None) => "none"
    Custom(Some(d)) => d.repr()
  }
  let locale = match info.locale {
    Auto => "auto"
    Custom(l) => l.rfc_3066()
  }
  "info title=\{opt(info.title)} author=\{list(info.author)} description=\{opt(info.description)} keywords=\{list(info.keywords)} date=\{date} locale=\{locale}\n"
}

///|
/// Dumps content and styles, numbering locations in order of appearance.
priv struct Dumper {
  locations : Map[@library.Location, Int]
}

///|
fn Dumper::new() -> Dumper {
  { locations: {}, }
}

///|
fn Dumper::loc(self : Dumper, loc : @library.Location) -> String {
  "#\{self.loc_id(loc)}"
}

///|
/// The number of a location (assigned in order of appearance).
fn Dumper::loc_id(self : Dumper, loc : @library.Location) -> Int {
  let n = self.locations.length()
  match self.locations.get(loc) {
    Some(id) => id
    None => {
      self.locations[loc] = n
      n
    }
  }
}

///|
fn Dumper::content(self : Dumper, content : @library.Content) -> String {
  if content.to_sequence() is Some(children) {
    return "[" + children.map(c => self.content(c)).join(", ") + "]"
  }
  if content.is_(@library.styled_elem()) {
    let styles = self.styles(@library.StyledElem::styles(content))
    let child = self.content(@library.StyledElem::child(content))
    return "styled(\{styles}; \{child})"
  }
  if @library.TagElem::of(content) is Some(tag) {
    return match tag.tag() {
      Start(elem, _) => {
        let loc = self.loc(elem.location().unwrap())
        "tag.start(\{loc}, \{elem.elem().name()})"
      }
      End(loc, _, _) => "tag.end(\{self.loc(loc)})"
    }
  }
  let fields = []
  for name, value in content.fields().map {
    fields.push("\{name}: \{self.value(value)}")
  }
  let out = StringBuilder()
  out.write_string("\{content.elem().name()}(\{fields.join(", ")})")
  if content.location() is Some(loc) {
    out.write_string(" ")
    out.write_string(self.loc(loc))
  }
  if content.is_prepared() {
    out.write_string("!")
  }
  out.to_string()
}

///|
fn Dumper::value(self : Dumper, value : @library.Value) -> String {
  match value {
    Content(c) => self.content(c)
    Array(a) => "(" + a.items.map(v => self.value(v)).join(", ") + ")"
    v => v.repr()
  }
}

///|
fn Dumper::styles(self : Dumper, styles : @library.Styles) -> String {
  styles.iter().map(s => self.style(s)).collect().join(", ")
}

///|
fn Dumper::style(self : Dumper, style : @library.Style) -> String {
  match style {
    Property(p) => {
      let elem = p.elem
      let (name, v) = match elem.field(p.id) {
        Some(info) => {
          let v = if info.kind is (Settable | Ghost) {
            let single = @library.StyleChain::new(
              @library.Styles::from_array([style]),
            )
            self.value(
              info.to_output(single.get_value_with_local(elem, info, None)),
            )
          } else {
            "?"
          }
          (info.name, v)
        }
        None => ("internal", "?")
      }
      "\{elem.name()}.\{name}=\{v}"
    }
    Recipe(recipe) => {
      let selector = match recipe.selector {
        Some(s) => s.repr()
        None => "none"
      }
      let transform = match recipe.transform {
        Content(c) => self.content(c)
        Func(f) => f.repr()
        Style(s) => "set(\{self.styles(s)})"
      }
      "show \{selector}: \{transform}"
    }
    Revocation(index) => "revoke(\{index})"
  }
}

///|
fn Dumper::chain(self : Dumper, chain : @library.StyleChain) -> String {
  let links = chain.links()
  links.rev_in_place()
  links
  .map(link => "{" + link.map(s => self.style(s)).join(", ") + "}")
  .join(" ")
}
