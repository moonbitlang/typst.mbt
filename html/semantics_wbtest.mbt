// Unit tests for the semantic part of the HTML export (conversion, document
// finalization, introspection and link anchors). Realization is provided by
// a minimal stub routine that flattens sequences and styled content and
// applies native show rules; expected outputs are from upstream (see the
// test suite cases referenced in the comments).

///|
priv struct DummyWorld {
  library : @library.Library
}

///|
impl @library.World for DummyWorld with fn library(self) {
  self.library
}

///|
impl @library.World for DummyWorld with fn main(_) {
  @syntax.RootedPath::new(
    Project,
    @syntax.VirtualPath::new("/main.typ") catch {
      _ => abort("invalid path")
    },
  ).intern()
}

///|
impl @library.World for DummyWorld with fn source(_, _) {
  raise @library.FileError::NotFound("")
}

///|
impl @library.World for DummyWorld with fn file(_, _) {
  raise @library.FileError::NotFound("")
}

///|
impl @library.World for DummyWorld with fn today(_, _) {
  None
}

///|
/// The native rules: the built-in ones plus the HTML ones.
let test_rules : @library.NativeRuleMap = {
  let rules = @library.NativeRuleMap::new()
  register(rules)
  rules
}

///|
let location_counter : Ref[Int] = Ref(1000)

///|
/// A minimal realization: flattens sequences and styled content and applies
/// native show rules (no paragraph grouping, no tags, no show rules).
fn stub_realize(
  _kind : @library.RealizationKind,
  engine : @library.Engine,
  _locator : @library.SplitLocator,
  content : @library.Content,
  styles : @library.StyleChain,
) -> Array[@library.Pair] raise @library.SourceError {
  let out = []
  fn visit(
    c : @library.Content,
    styles : @library.StyleChain,
  ) -> Unit raise @library.SourceError {
    if c.to_sequence() is Some(children) {
      for child in children {
        visit(child, styles)
      }
    } else if c.is_(@library.styled_elem()) {
      visit(
        @library.StyledElem::child(c),
        styles.chain(@library.StyledElem::styles(c)),
      )
    } else if test_rules.get(Html, c) is Some(rule) {
      // Assign a location, as the rules may need one.
      let c = if c.location() is None {
        location_counter.val += 1
        c.located(
          @library.Location::new(@library.hash128(location_counter.val)),
        )
      } else {
        c
      }
      visit(rule.apply(c, engine, styles), styles)
    } else {
      out.push((c, styles))
    }
  }

  visit(content, styles)
  out
}

///|
let test_library : @library.Library = {
  let routines = @library.Routines::new(
    eval_string=(_, _, _, span, _, _) => {
      @library.bail_at(span, "eval is not available")
    },
    eval_closure=(_, _, _, _, args) => {
      @library.bail_at(args.span, "eval is not available")
    },
    realize=stub_realize,
    html_mathml_body~,
    html_span_filled~,
  )
  @library.Library::builder(routines, @library.default_formats()).build()
}

///|
fn test_engine() -> @library.Engine {
  {
    world: DummyWorld::{ library: test_library, },
    library: test_library,
    introspector: @library.Introspector::empty(),
    traced: @library.Traced::new(),
    sink: @library.Sink::new(),
    route: @library.Route::root(),
  }
}

///|
fn text(s : String) -> @library.Content {
  @library.TextElem::packed(s)
}

///|
fn span_elem(body : @library.Content?) -> @library.Content {
  @library.HtmlElem::new(@library.tag_span).with_body(body).pack()
}

///|
fn seq(children : Array[@library.Content]) -> @library.Content {
  @library.Content::sequence(children)
}

///|
/// Converts inline content (like the children of a paragraph) and encodes
/// the resulting nodes.
fn convert_inline(content : @library.Content) -> String raise {
  let engine = test_engine()
  let locator = @library.Locator::root().split()
  let styles = @library.StyleChain::empty()
  let pairs = stub_realize(Par, engine, locator, content, styles)
  let nodes = convert_to_nodes(engine, locator, pairs, Block, Normal)
  let p = HtmlElement::new(@library.tag_p).with_children(nodes)
  resolve_inline_styles(p)
  let out = html_encode(p)
  out.unsafe_substring(
    start="<!DOCTYPE html><p>".length(),
    end=out.length() - 4,
  )
}

///|
fn encode_document(
  content : @library.Content,
  styles~ : @library.Styles = @library.Styles::new(),
) -> String raise {
  let doc = html_document(
    test_engine(),
    content,
    @library.StyleChain::new(styles),
  )
  html(doc, { format: { pretty: Some(true), }, })
}

///|
// html-space-collapsing: "No collapsing."
test "space: single text" {
  inspect(convert_inline(text("A B")), content="A B")
}

///|
// html-space-collapsing: "No collapsing, multiple text elements."
test "space: multiple text elements" {
  inspect(convert_inline(seq([text("A"), text(" "), text("B")])), content="A B")
}

///|
// html-space-collapsing: "With span in between."
test "space: span in between" {
  inspect(
    convert_inline(seq([text("A "), span_elem(None), text(" B")])),
    content=(
      #|A<span style="white-space: pre-wrap">&#x20;</span><span></span> B
    ),
  )
}

///|
// html-space-collapsing: "Within span."
test "space: within span" {
  inspect(
    convert_inline(seq([span_elem(Some(text("A "))), text("B")])),
    content="<span>A </span>B",
  )
}

///|
// html-space-collapsing: "Single text element." (consecutive whitespace)
test "space: consecutive" {
  inspect(
    convert_inline(text("A  B   C")),
    content=(
      #|A<span style="white-space: pre-wrap">&#x20;&#x20;</span>B<span style="white-space: pre-wrap">&#x20;&#x20;&#x20;</span>C
    ),
  )
}

///|
// html-space-collapsing: "Across span boundaries: 1-1."
test "space: across span boundaries 1-1" {
  inspect(
    convert_inline(
      seq([span_elem(Some(text("A "))), @library.SpaceElem::shared(), text("B")]),
    ),
    content=(
      #|<span>A<span style="white-space: pre-wrap">&#x20;</span></span> B
    ),
  )
}

///|
// html-space-collapsing: "Across span boundaries: 2-2."
test "space: across span boundaries 2-2" {
  inspect(
    convert_inline(seq([span_elem(Some(text("A  "))), text("  B")])),
    content=(
      #|<span>A<span style="white-space: pre-wrap">&#x20;&#x20;</span></span><span style="white-space: pre-wrap">&#x20;&#x20;</span>B
    ),
  )
}

///|
test "text: tabs, newlines and default ignorables" {
  inspect(
    convert_inline(text("A\tB\r\nC\u{200B} D")),
    content=(
      #|A<span style="white-space: pre-wrap">&#x9;</span>B<br>C​ D
    ),
  )
}

///|
test "smart quotes" {
  let quote = (double : Bool) => {
    @library.SmartQuoteElem::new().with_double(double).pack()
  }
  inspect(
    convert_inline(
      seq([
        quote(true),
        text("It"),
        quote(false),
        text("s 1"),
        quote(false),
        text(" a "),
        quote(false),
        text("b"),
        quote(false),
        quote(true),
      ]),
    ),
    content="“It’s 1′ a ‘b’”",
  )
}

///|
test "unknown elements are ignored with a warning" {
  let engine = test_engine()
  let locator = @library.Locator::root().split()
  let pairs = [
    (@library.ColbreakElem::new().pack(), @library.StyleChain::empty()),
  ]
  let nodes = convert_to_nodes(engine, locator, pairs, Block, Normal)
  inspect(nodes.length(), content="0")
  @debug.debug_inspect(
    engine.sink.warnings().map(w => w.message),
    content=(
      #|["colbreak was ignored during HTML export"]
    ),
  )
}

///|
test "rules: inline elements" {
  inspect(
    convert_inline(
      seq([
        @library.StrongElem::new(text("a")).pack(),
        @library.EmphElem::new(text("b")).pack(),
        @library.SubElem::new(text("c")).pack(),
        @library.SuperElem::new(text("d")).pack(),
        @library.StrikeElem::new(text("e")).pack(),
        @library.HighlightElem::new(text("f")).pack(),
        @library.UnderlineElem::new(text("g")).pack(),
        @library.SmallcapsElem::new(text("h")).pack(),
      ]),
    ),
    content=(
      #|<strong>a</strong><em>b</em><sub>c</sub><sup>d</sup><s>e</s><mark>f</mark><span style="text-decoration: underline">g</span><span style="font-variant-caps: small-caps">h</span>
    ),
  )
}

///|
// html-elem-attrs-fold
test "document: attrs fold" {
  let set = (attrs : Array[(String, String)]) => {
    let a = @library.HtmlAttrs::new()
    for pair in attrs {
      a.push(@library.HtmlAttr::constant(pair.0), pair.1)
    }
    @library.HtmlElem::set_attrs(a)
  }
  let div = @library.HtmlElem::new(@library.tag_div)
    .with_attrs(
      {
        let a = @library.HtmlAttrs::new()
        a.push(@library.HtmlAttr::constant("a"), "1'")
        a.push(@library.HtmlAttr::constant("b"), "2")
        a
      },
    )
    .pack()
  let content = div
    .styled(set([("c", "3'")]))
    .styled(set([("d", "4")]))
    .styled(set([("c", "3")]))
    .styled(set([("a", "1")]))
  inspect(
    encode_document(content),
    content=(
      #|<!DOCTYPE html>
      #|<html lang="en">
      #|  <head>
      #|    <meta charset="utf-8">
      #|    <meta name="viewport" content="width=device-width, initial-scale=1">
      #|  </head>
      #|  <body>
      #|    <div a="1'" b="2" c="3'" d="4"></div>
      #|  </body>
      #|</html>
      #|
    ),
  )
}

///|
// html-elem-not-alone
test "document: html element not alone" {
  let content = seq([
    @library.HtmlElem::new(@library.tag_html).pack(),
    @library.SpaceElem::shared(),
    text("Text"),
  ])
  let msg = try encode_document(content) catch {
    @library.SourceError(errors) => @debug.to_string(errors.map(e => e.message))
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(
    msg,
    content=(
      #|["`<html>` element must be the only element in the document"]
    ),
  )
}

///|
// html-elem-alone-context (without the context)
test "document: html element alone" {
  inspect(
    encode_document(@library.HtmlElem::new(@library.tag_html).pack()),
    content=(
      #|<!DOCTYPE html>
      #|<html></html>
      #|
    ),
  )
}

///|
test "document: metadata from document info" {
  let content = text("Hi")
  let styles = @library.Styles::from_array([
    @library.DocumentElem::set_title(Some(text("My title"))),
    @library.DocumentElem::set_description(Some(text("Desc"))),
    @library.DocumentElem::set_author(@library.OneOrMultiple(["A", "B"])),
    @library.DocumentElem::set_keywords(@library.OneOrMultiple(["x", "y"])),
    @library.TextElem::set_lang(@library.Lang("de")),
    @library.TextElem::set_region(Some(@library.Region("AT"))),
  ])
  inspect(
    encode_document(content, styles~),
    content=(
      #|<!DOCTYPE html>
      #|<html lang="de-AT">
      #|  <head>
      #|    <meta charset="utf-8">
      #|    <meta name="viewport" content="width=device-width, initial-scale=1">
      #|    <title>My title</title>
      #|    <meta name="description" content="Desc">
      #|    <meta name="author" content="A">
      #|    <meta name="author" content="B">
      #|    <meta name="keywords" content="x, y">
      #|  </head>
      #|  <body>Hi</body>
      #|</html>
      #|
    ),
  )
}

///|
test "document: pretty option from the document" {
  let doc = html_document(
    test_engine(),
    @library.HtmlElem::new(@library.tag_div).pack(),
    @library.StyleChain::empty(),
  )
  inspect(
    html(doc, HtmlOptions::default()),
    content=(
      #|<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body><div></div></body></html>
    ),
  )
}

///|
fn located(c : @library.Content, n : Int) -> @library.Content {
  c.located(@library.Location::new(@library.hash128(n)))
}

///|
fn start_tag(c : @library.Content) -> HtmlNode {
  Tag(Start(c, { introspectable: true, tagged: false, }))
}

///|
fn end_tag(c : @library.Content) -> HtmlNode {
  Tag(
    End(c.location().unwrap(), @library.hash128(0), {
      introspectable: true,
      tagged: false,
    }),
  )
}

///|
test "introspector: positions" {
  let m1 = located(@library.MetadataElem::new(Int(1)).pack(), 1)
  let m2 = located(@library.MetadataElem::new(Int(2)).pack(), 2)
  let inner = HtmlElement::new(@library.tag_span).with_children([
    Text("a", @syntax.Span::detached()),
    start_tag(m2),
    end_tag(m2),
  ])
  let body = HtmlElement::new(@library.tag_body).with_children([
    Text("x", @syntax.Span::detached()),
    Text("y", @syntax.Span::detached()),
    start_tag(m1),
    end_tag(m1),
    Element(inner),
  ])
  let root = HtmlElement::new(@library.tag_html).with_children([
    Element(HtmlElement::new(@library.tag_head)),
    Element(body),
  ])
  let introspector = HtmlIntrospector::new([Element(root)])
  let pos = (c : @library.Content) => {
    introspector
    .html_position(c.location().unwrap())
    .map(p => p.element().to_owned())
  }
  @debug.debug_inspect(pos(m1), content="Some([1, 0])")
  @debug.debug_inspect(pos(m2), content="Some([1, 1, 0])")
  inspect(
    @library.IntrospectorBackend::query(
      introspector,
      @library.metadata_elem().select(),
    ).length(),
    content="2",
  )
  inspect(
    @library.IntrospectorBackend::page(introspector, m1.location().unwrap())
    is None,
    content="true",
  )
}

///|
test "link anchors" {
  let label = @library.Label::new("intro").unwrap()
  let target = located(@library.MetadataElem::new(Int(1)).pack(), 1).labelled(
    label,
  )
  let target2 = located(@library.MetadataElem::new(Int(2)).pack(), 2)
  let link = located(
    @library.LinkElem::new(@library.LinkTarget::Label(label), text("go")).pack(),
    3,
  )
  let link2 = located(
    @library.LinkElem::new(
      @library.LinkTarget::Dest(Location(target2.location().unwrap())),
      text("go"),
    ).pack(),
    4,
  )
  let body = HtmlElement::new(@library.tag_body).with_children([
    start_tag(link),
    end_tag(link),
    start_tag(link2),
    end_tag(link2),
    start_tag(target),
    Text("hello", @syntax.Span::detached()),
    end_tag(target),
    start_tag(target2),
    end_tag(target2),
  ])
  let root = HtmlElement::new(@library.tag_html).with_children([Element(body)])
  let doc = HtmlDocument::new(
    { nodes: [Element(root)], root_index: 0, },
    @library.DocumentInfo::new(),
    @library.DocumentFormatOptions::new(),
  )
  let targets = doc.introspector().link_targets()
  inspect(targets.length(), content="2")
  let anchors = create_link_anchors(doc, targets)
  doc.introspector().set_anchors(anchors)
  inspect(
    html_encode(doc.root()),
    content=(
      #|<!DOCTYPE html><html><body><span id="intro">hello</span><span id="loc-1"></span></body></html>
    ),
  )
  @debug.debug_inspect(
    @library.IntrospectorBackend::anchor(
      doc.introspector(),
      target.location().unwrap(),
    ),
    content=(
      #|Some("intro")
    ),
  )
}

///|
test "routines: html_mathml_body and html_span_filled" {
  let math = @library.HtmlElem::new(@library.tag_mathml_math)
    .with_body(Some(text("x")))
    .pack()
  @debug.debug_inspect(
    html_mathml_body(math, @library.StyleChain::empty()).map(b => b is Some(_)),
    content="Some(true)",
  )
  inspect(
    html_mathml_body(span_elem(None), @library.StyleChain::empty()) is None,
    content="true",
  )
  inspect(
    convert_inline(
      html_span_filled(text("x"), @library.Color::from_u8(255, 0, 0, 255)),
    ),
    content=(
      #|<span style="color: #ff0000">x</span>
    ),
  )
}
