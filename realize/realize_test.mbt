// Unit tests for realization with hand-built content and styles. The
// differential `realize` stage of the test runner checks the same pipeline
// against upstream on the whole test suite.

///|
priv struct TestWorld {
  library : @library.Library
}

///|
impl @library.World for TestWorld with fn library(self) {
  self.library
}

///|
impl @library.World for TestWorld with fn main(_) {
  @syntax.FileId::from_raw(1)
}

///|
impl @library.World for TestWorld with fn source(_, _) {
  raise @library.FileError::AccessDenied
}

///|
impl @library.World for TestWorld with fn file(_, _) {
  raise @library.FileError::AccessDenied
}

///|
impl @library.World for TestWorld with fn today(_, _) {
  None
}

///|
fn test_engine() -> @library.Engine {
  let routines = @library.Routines::new(
    eval_string=(_, _, _, _, _, _) => None,
    eval_closure=(_, _, _, _, _) => None,
  )
  let library = @library.Library::builder(routines, []).build()
  let world : TestWorld = { library, }
  {
    world,
    library,
    introspector: @library.Introspector::empty(),
    traced: @library.Traced::new(),
    sink: @library.Sink::new(),
    route: @library.Route::extend(@library.Route::root()).unnested(),
  }
}

///|
/// Realize content and render the resulting pairs (content repr and the
/// number of style links).
fn run(
  content : @library.Content,
  kind? : @library.RealizationKind = Fragment(kind=Ref::new(Block)),
) -> String raise @library.SourceError {
  let styles = @library.StyleChain::new(@library.Styles::new())
  let pairs = realize(
    kind,
    test_engine(),
    @library.Locator::root().split(),
    content,
    styles,
  )
  pairs.map(pair => pair.0.repr()).join("\n")
}

///|
fn text(s : String) -> @library.Content {
  @library.TextElem::packed(s)
}

///|
fn space() -> @library.Content {
  @library.SpaceElem::shared()
}

///|
fn seq(children : Array[@library.Content]) -> @library.Content {
  @library.Content::sequence(children)
}

///|
test "paragraph grouping and parbreaks" {
  let content = seq([
    text("a"),
    space(),
    text("b"),
    @library.ParbreakElem::new().pack(),
    text("c"),
  ])
  inspect(
    run(content),
    content=(
      #|tag()
      #|par(
      #|  leading: 0.65em,
      #|  spacing: 1.2em,
      #|  justify: false,
      #|  justification-limits: (
      #|    spacing: (min: 66.67% + 0pt, max: 150% + 0pt),
      #|    tracking: (min: 0pt, max: 0pt),
      #|  ),
      #|  linebreaks: auto,
      #|  first-line-indent: (amount: 0pt, all: false),
      #|  hanging-indent: 0pt,
      #|  body: sequence([a], [ ], [b]),
      #|)
      #|tag()
      #|tag()
      #|par(
      #|  leading: 0.65em,
      #|  spacing: 1.2em,
      #|  justify: false,
      #|  justification-limits: (
      #|    spacing: (min: 66.67% + 0pt, max: 150% + 0pt),
      #|    tracking: (min: 0pt, max: 0pt),
      #|  ),
      #|  linebreaks: auto,
      #|  first-line-indent: (amount: 0pt, all: false),
      #|  hanging-indent: 0pt,
      #|  body: [c],
      #|)
      #|tag()
    ),
  )
}

///|
test "spaces collapse at the edges and between each other" {
  let content = seq([space(), text("a"), space(), space(), text("b"), space()])
  inspect(
    run(content),
    content=(
      #|[a]
      #|[ ]
      #|[b]
    ),
  )
}

///|
test "fully inline fragment" {
  let kind = Ref::new(@library.FragmentKind::Block)
  let content = seq([text("a"), space(), text("b")])
  inspect(
    run(content, kind=Fragment(kind~)),
    content=(
      #|[a]
      #|[ ]
      #|[b]
    ),
  )
  assert_true(kind.val is Inline)
}

///|
test "list grouping" {
  let item = (s : String) => @library.ListItem::new(text(s)).pack()
  let content = seq([item("a"), space(), item("b")])
  inspect(
    run(content),
    content=(
      #|tag()
      #|tag()
      #|list(
      #|  tight: true,
      #|  marker: ([•], [‣], [–]),
      #|  indent: 0pt,
      #|  body-indent: 0.5em,
      #|  spacing: auto,
      #|  marker-align: end,
      #|  children: (item(body: [a]), item(body: [b])),
      #|)
      #|tag()
      #|tag()
      #|tag()
      #|tag()
    ),
  )
  let content = seq([item("a"), @library.ParbreakElem::new().pack(), item("b")])
  inspect(
    run(content),
    content=(
      #|tag()
      #|tag()
      #|list(
      #|  tight: false,
      #|  marker: ([•], [‣], [–]),
      #|  indent: 0pt,
      #|  body-indent: 0.5em,
      #|  spacing: auto,
      #|  marker-align: end,
      #|  children: (item(body: [a]), item(body: [b])),
      #|)
      #|tag()
      #|tag()
      #|tag()
      #|tag()
    ),
  )
}

///|
test "symbols become text outside of math" {
  inspect(
    run(@library.SymbolElem::packed("x")),
    content=(
      #|[x]
    ),
  )
}

///|
test "regex show rule" {
  let regex = @library.Regex::new("wor") catch { _ => abort("regex") }
  let recipe = @library.Recipe::new(
    Some(Regex(regex)),
    Content(text("X")),
    @syntax.Span::detached(),
  )
  let content = text("hello world").styled(Recipe(recipe))
  inspect(
    run(content),
    content=(
      #|[hello ]
      #|[X]
      #|[ld]
    ),
  )
}

///|
test "show-set rule on an element" {
  let strong = @library.StrongElem::new(text("a")).pack()
  let recipe = @library.Recipe::new(
    Some(@library.strong_elem().select()),
    Style(@library.Styles::from_array([@library.StrongElem::set_delta(500L)])),
    @syntax.Span::detached(),
  )
  let content = strong.styled(Recipe(recipe))
  let styles = @library.StyleChain::new(@library.Styles::new())
  let pairs = realize(
    Fragment(kind=Ref::new(Block)),
    test_engine(),
    @library.Locator::root().split(),
    content,
    styles,
  )
  // The strong element is prepared (and materialized with the show-set
  // style applied).
  inspect(
    pairs.map(pair => pair.0.repr()).join("\n"),
    content=(
      #|tag()
      #|strong(delta: 500, body: [a])
      #|tag()
    ),
  )
}
