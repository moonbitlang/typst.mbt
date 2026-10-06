// Description values (docs/edsl-design.md, section 4): opaque, immutable
// values that describe content. Building them needs no engine, world or
// I/O; they are lowered to engine content by `lower.mbt`.

///|
/// Anything usable where content is expected: `String` (literal text, never
/// parsed), every description type, show-rule views and user types.
///
/// `into_content` must be pure: it runs once, when the value is passed to a
/// constructor.
pub(open) trait IntoContent {
  fn into_content(Self) -> Content
}

///|
/// An opaque, immutable description of content.
pub struct Content {
  priv node : Node
}

///|
/// The private representation of a description.
priv enum Node {
  /// Literal text. The origin is `None` for a plain `String`, which takes
  /// the span of the argument it was passed in.
  NText(String, Site?)
  /// A function call whose displayed result is the content.
  NCall(CallNode)
  /// Several pieces of content (and rules, which style what follows them).
  NSeq(Array[Content], Site)
  /// A sequence without a site of its own, inside a sequence that has
  /// one: its children are further pieces of the argument that the outer
  /// sequence's children are pieces of. `Para` puts the text after a
  /// block into one, with the rule that styles it.
  NPieces(Array[Content])
  /// A set rule.
  NSetRule(SetNode)
  /// A show rule.
  NShowRule(ShowNode)
  /// Content with a label attached. The integer is the index of the label
  /// parameter in the origin's `ArgsLoc`.
  NLabelled(Content, String, Site, Int)
  /// Content whose origins carry a runtime occurrence key.
  NKeyed(String, Content)
  /// A composite: what its `build` made (`composite.mbt`). It lowers to
  /// that content. Parameter 0 of the site is the body: the caller's
  /// argument that the result of `build` was marked as, or none.
  NComposite(Content, Site)
  /// A `context` callback.
  NContext(Callback, Site)
  /// Typst source evaluated by the front end (markup or math).
  NEval(EvalNode)
  /// Markup's space element; whether the source space had a newline.
  NSpace(Bool)
  /// Engine content, re-emitted unchanged (show-rule views, engine values).
  NEngine(@library.Content)
  /// A value: as an argument the value itself, in a sequence its display.
  NValue(Value)
  /// A description that cannot be lowered: the message is reported at the
  /// origin (a constructor found the problem; constructors do not raise).
  NInvalid(String, Site)
}

///|
/// The source location of a constructor call: the call itself and one
/// optional location per declared parameter.
priv struct Site {
  /// The call that origins report, and its arguments: the constructor's
  /// own call, or, for a constructor that ran inside the `build` of a
  /// composite (`owner`), the call of the composite.
  loc : SourceLoc
  args : ArgsLoc
  /// The constructor's name.
  kind : String
  /// For a constructor that ran inside the `build` of a composite: how its
  /// call is seen from the composite's (`composite.mbt`).
  owner : Owner?
}

///|
/// The site of a constructor call. Inside the `build` of a composite it is
/// the composite's call (`Scope::own`).
fn Site::new(kind : String, loc : SourceLoc, args : ArgsLoc) -> Site {
  match composite_scope.val {
    Some(scope) => scope.own(kind, loc, args)
    Option::None => { loc, args, kind, owner: Option::None, }
  }
}

///|
/// An origin without argument locations.
fn Site::of_call(kind : String, loc : SourceLoc) -> Site {
  Site::new(kind, loc, ArgsLoc([]))
}

///|
/// The function called by a [CallNode] or [SetNode].
priv enum FuncRef {
  /// An element function.
  FElem(@library.Element)
  /// A native function.
  FNative(@library.NativeFuncData)
  /// A qualified name resolved in the library's global scope
  /// (`table.cell`).
  FPath(String)
}

///|
/// One argument of a call.
priv struct ArgNode {
  /// `None` for positional arguments.
  name : String?
  value : Value
  /// The index of the parameter in the constructor's `ArgsLoc` (`-1`: the
  /// call's own span).
  param : Int
}

///|
priv struct CallNode {
  func : FuncRef
  args : Array[ArgNode]
  origin : Site
}

///|
priv struct SetNode {
  func : FuncRef
  args : Array[ArgNode]
  origin : Site
}

///|
/// The transformation of a show rule.
priv enum ShowTransform {
  TFunc(Callback)
  TStyle(SetNode)
  /// A value that is cast to a transformation (a function, content).
  TValue(Value)
}

///|
priv struct ShowNode {
  /// The selector, as a value description (`None`: `show: transform`).
  selector : Value?
  transform : ShowTransform
  origin : Site
}

///|
/// Source text for the Typst front end.
priv struct EvalNode {
  mode : @syntax.SyntaxMode
  source : String
  scope : Array[(String, Value)]
  /// The parameter index of the source string.
  source_param : Int
  /// For math: the element function's named arguments (`block`, ...).
  args : Array[ArgNode]
  origin : Site
}

///|
fn Content::of(node : Node) -> Content {
  { node, }
}

///|
/// Erases the type of a description. Useful where the branches of an `if`
/// or `match` produce different description types.
pub fn Content::Content(body : &IntoContent) -> Content {
  described(body)
}

///|
pub impl IntoContent for Content with fn into_content(self) {
  self
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Content with IntoContent::{into_content}

///|
/// A plain string is literal text.
pub impl IntoContent for String with fn into_content(self) {
  Content::of(NText(self, None))
}

///|
/// Convert and snapshot an array of content.
fn snapshot(children : Array[&IntoContent]) -> Array[Content] {
  children.map(described)
}

///|
/// A sequence of content. Rules among the children (`SetText(..)`,
/// `Show(..)`) style the children after them. Nesting is preserved: the
/// functional Typst twin is the content block `[#a#b#c]`.
pub struct Seq {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Seq::Seq(
  children : Array[&IntoContent],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Seq {
  {
    content: Content::of(
      NSeq(snapshot(children), Site::new("Seq", loc, args_loc)),
    ),
  }
}

///|
/// A sequence of the items of an existing typed array.
#callsite(autofill(loc, args_loc))
pub fn[T : IntoContent] Seq::of(
  items : Array[T],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Seq {
  {
    content: Content::of(
      NSeq(items.map(c => described(c)), Site::new("Seq", loc, args_loc)),
    ),
  }
}

///|
pub impl IntoContent for Seq with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Seq with IntoContent::{into_content}

///|
/// Literal text with a source location of its own (a plain `String` inside
/// an array shares the location of the array argument).
pub struct Lit {
  priv content : Content
}

///|
#callsite(autofill(loc))
pub fn Lit::Lit(text : String, loc~ : SourceLoc) -> Lit {
  { content: Content::of(NText(text, Some(Site::of_call("Lit", loc)))), }
}

///|
pub impl IntoContent for Lit with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Lit with IntoContent::{into_content}

///|
/// Content with a label: the twin of `[#body<label>]`.
pub struct Labelled {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Labelled::Labelled(
  body : &IntoContent,
  label : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Labelled {
  {
    content: Content::of(
      NLabelled(described(body), label, Site::new("Labelled", loc, args_loc), 1),
    ),
  }
}

///|
pub impl IntoContent for Labelled with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Labelled with IntoContent::{into_content}

///|
/// Attaches a runtime occurrence key to the origins of everything inside
/// `body` (data-driven content built at one call site). It does not change
/// the content. A key must not start with the noncharacter U+FDD2, which
/// marks the occurrences that lowering registers itself.
pub struct Keyed {
  priv content : Content
}

///|
pub fn Keyed::Keyed(key : String, body : &IntoContent) -> Keyed {
  { content: Content::of(NKeyed(key, described(body))), }
}

///|
pub impl IntoContent for Keyed with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Keyed with IntoContent::{into_content}

///|
/// Markup's space element (Typst's collapsing space, not the text `" "`).
pub struct Space {
  priv content : Content
}

///|
pub fn Space::Space() -> Space {
  { content: Content::of(NSpace(false)), }
}

///|
/// The space that markup produces for a line break in the source. It is a
/// space like `Space()`, but realization discards it next to text of a
/// writing system without spaces (Chinese, Japanese): the twin of a
/// newline between two pieces of markup.
pub fn Space::newline() -> Space {
  { content: Content::of(NSpace(true)), }
}

///|
pub impl IntoContent for Space with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Space with IntoContent::{into_content}

///|
/// Append the `extra` arguments of a generated constructor (at parameter
/// index `param`) as named arguments: they follow the typed arguments, so
/// that a later argument wins, as in Typst. Entries that name one of the
/// `positional` fields are not appended: the constructor passes them in
/// the field's positional place (`extra_arg`).
fn push_extra(
  args : Array[ArgNode],
  extra : Array[(String, Value)],
  param : Int,
  positional? : Array[String] = [],
) -> Unit {
  for pair in extra {
    if !positional.contains(pair.0) {
      args.push({ name: Some(pair.0), value: pair.1, param, })
    }
  }
}

///|
/// The `extra` entry for the positional field `field`, if any: the function
/// takes that field positionally only, so the entry replaces the typed
/// argument in its positional place. The last entry wins.
fn extra_arg(extra : Array[(String, Value)], field : String) -> Value? {
  let mut found : Value? = Option::None
  for pair in extra {
    if pair.0 == field {
      found = Some(pair.1)
    }
  }
  found
}

///|
/// Wrap a call description with an optional label (the `label` parameter
/// of element constructors, at index `label_param` of their `ArgsLoc`).
fn labelled_call(
  call : CallNode,
  label : String?,
  label_param : Int,
) -> Content {
  let content = Content::of(NCall(call))
  match label {
    None => content
    Some(label) =>
      Content::of(NLabelled(content, label, call.origin, label_param))
  }
}
