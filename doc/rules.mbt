// Rules and escape hatches (docs/edsl-design.md, sections 8 and 13).

///|
/// The set rules: the generated `SetText`, `SetPar`, ... types and the
/// generic [Set].
pub trait SetRule: IntoContent {}

///|
/// The set rule of a [SetRule] value.
fn set_node(rule : &SetRule) -> SetNode {
  match IntoContent::into_content(rule).node {
    NSetRule(node) => node
    // The implementors of the sealed trait are set rules.
    _ => panic()
  }
}

///|
/// A show rule with a callback: `show selector: it => ..`.
///
/// The callback receives a view of the exact content the rule matched
/// (emitting the view re-emits that content without restarting the rule)
/// and the context of the invocation.
pub struct Show {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn[W] Show::Show(
  selector : Selector[W],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
  f : (W, Ctx) -> &IntoContent raise,
) -> Show {
  let site = Site::new("Show", loc, args_loc)
  let wrap = selector.wrap
  let callback = Callback::new(site, (cx, args) => {
    let content : @library.Content = args.expect("content")
    Value::content(f(wrap(content), cx))
  })
  {
    content: Content::of(
      NShowRule({
        selector: selector.value,
        transform: TFunc(callback),
        origin: site,
      }),
    ),
  }
}

///|
pub impl IntoContent for Show with fn into_content(self) {
  self.content
}

///|
/// A show-set rule: `show selector: set f(..)`.
pub struct ShowSet {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn[W] ShowSet::ShowSet(
  selector : Selector[W],
  rule : &SetRule,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> ShowSet {
  {
    content: Content::of(
      NShowRule({
        selector: selector.value,
        transform: TStyle(set_node(rule)),
        origin: Site::new("ShowSet", loc, args_loc),
      }),
    ),
  }
}

///|
pub impl IntoContent for ShowSet with fn into_content(self) {
  self.content
}

///|
/// The generic set rule: `set path(named..)` for the element function with
/// the qualified name `path` (`"table.cell"`).
pub struct Set {
  priv node : SetNode
}

///|
#callsite(autofill(loc, args_loc))
pub fn Set::Set(
  path : String,
  named : Array[(String, Value)],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Set {
  {
    node: {
      func: FPath(path),
      args: generic_args([], named),
      origin: Site::new("Set", loc, args_loc),
    },
  }
}

///|
pub impl IntoContent for Set with fn into_content(self) {
  Content::of(NSetRule(self.node))
}

///|
pub impl SetRule for Set

///|
/// The generic function call: the public Typst function with the qualified
/// name `path` (`"table.cell"`, `"lorem"`), displayed as content like
/// `#path(..)` in markup.
pub struct Call {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Call::Call(
  path : String,
  positional? : Array[Value] = [],
  named? : Array[(String, Value)] = [],
  label? : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Call {
  {
    content: labelled_call(
      {
        func: FPath(path),
        args: generic_args(positional, named),
        origin: Site::new("Call", loc, args_loc),
      },
      label,
      3,
    ),
  }
}

///|
pub impl IntoContent for Call with fn into_content(self) {
  self.content
}

///|
/// Typst markup evaluated by the front end: the twin of
/// `eval(source, mode: "markup", scope: (..))`.
pub struct Markup {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Markup::Markup(
  source : String,
  scope? : Array[(String, Value)] = [],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Markup {
  {
    content: Content::of(
      NEval({
        mode: @syntax.SyntaxMode::Markup,
        source,
        scope: scope.copy(),
        source_param: 0,
        args: [],
        origin: Site::new("Markup", loc, args_loc),
      }),
    ),
  }
}

///|
pub impl IntoContent for Markup with fn into_content(self) {
  self.content
}

///|
/// An equation from a Typst math string: `Equation("x^2")` is `$x^2$`,
/// `Equation("x^2", block=true)` is `$ x^2 $`.
pub struct Equation {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Equation::Equation(
  source : String,
  block? : Bool = false,
  numbering? : Numbering?,
  number_align? : Alignment,
  supplement? : @library.Smart[Supplement?],
  alt? : String?,
  scope? : Array[(String, Value)] = [],
  label? : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Equation {
  // `block` is always passed, like the evaluator sets it for `$..$`.
  let args : Array[ArgNode] = [
    { name: Some("block"), value: Value::bool(block), param: 1, },
  ]
  if numbering is Some(v) {
    args.push({
      name: Some("numbering"),
      value: ToValue::to_value(v),
      param: 2,
    })
  }
  if number_align is Some(v) {
    args.push({ name: Some("number-align"), value: v.to_value(), param: 3, })
  }
  if supplement is Some(v) {
    args.push({
      name: Some("supplement"),
      value: ToValue::to_value(v),
      param: 4,
    })
  }
  if alt is Some(v) {
    args.push({ name: Some("alt"), value: ToValue::to_value(v), param: 5, })
  }
  let site = Site::new("Equation", loc, args_loc)
  let content = Content::of(
    NEval({
      mode: @syntax.SyntaxMode::Math,
      source,
      scope: scope.copy(),
      source_param: 0,
      args,
      origin: site,
    }),
  )
  {
    content: match label {
      None => content
      Some(label) => Content::of(NLabelled(content, label, site, 7))
    },
  }
}

///|
pub impl IntoContent for Equation with fn into_content(self) {
  self.content
}
