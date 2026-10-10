// Readable output of descriptions (docs/edsl-design.md, section 4.4):
// `Show` of a description is the interpolation hook of `Prose` and writes a
// placeholder; what a description is made of is shown by core's `Debug`:
// `debug(v)`, `debug_inspect(v, content=..)` in tests, `\{Repr(v)}` in
// strings.

///|
/// The representation of a function reference.
fn Callee::describe(self : Callee) -> String {
  match self {
    FElem(elem) => elem.name()
    FNative(func) => func.name
    FPath(path) => path
  }
}

///|
/// The arguments of a call: positional ones first, as they are written.
fn args_repr(args : Array[ArgNode]) -> Array[(String?, @debug.Repr)] {
  let out : Array[(String?, @debug.Repr)] = []
  for arg in args {
    out.push((arg.name, @debug.Debug::to_repr(arg.value)))
  }
  out
}

///|
/// The unit of a numeric literal.
fn unit_suffix(unit : @library.NumericUnit) -> String {
  match unit {
    Pt => "pt"
    Mm => "mm"
    Cm => "cm"
    In => "in"
    Rad => "rad"
    Deg => "deg"
    Em => "em"
    Fr => "fr"
    Percent => "%"
  }
}

///|
/// A value as Typst would write it, where it has such a form.
pub impl @debug.Debug for Value with fn to_repr(self) {
  match self.val {
    VNone => @debug.Repr::literal("none")
    VAuto => @debug.Repr::literal("auto")
    VBool(v) => @debug.Repr::bool(v)
    VInt(v) => @debug.Repr::integer(v.to_string())
    VFloat(v) => @debug.Repr::double(v)
    VStr(v) => @debug.Repr::string(v)
    VNumeric(v, unit) => @debug.Repr::literal("\{v}\{unit_suffix(unit)}")
    VAdd(a, b) =>
      @debug.Repr::ctor("add", [
        (Option::None, @debug.Debug::to_repr(a)),
        (Option::None, @debug.Debug::to_repr(b)),
      ])
    VSub(a, b) =>
      @debug.Repr::ctor("sub", [
        (Option::None, @debug.Debug::to_repr(a)),
        (Option::None, @debug.Debug::to_repr(b)),
      ])
    VMul(a, b) =>
      @debug.Repr::ctor("mul", [
        (Option::None, @debug.Debug::to_repr(a)),
        (Option::None, @debug.Debug::to_repr(b)),
      ])
    VDiv(a, b) =>
      @debug.Repr::ctor("div", [
        (Option::None, @debug.Debug::to_repr(a)),
        (Option::None, @debug.Debug::to_repr(b)),
      ])
    VNeg(a) =>
      @debug.Repr::ctor("neg", [(Option::None, @debug.Debug::to_repr(a))])
    VArray(items) =>
      @debug.Repr::array(items.map(item => @debug.Debug::to_repr(item)))
    VDict(pairs) =>
      @debug.Repr::map(
        pairs.map(pair => {
          (@debug.Repr::string(pair.0), @debug.Debug::to_repr(pair.1))
        }),
      )
    VContent(content) => @debug.Debug::to_repr(content)
    VLabel(name) => @debug.Repr::literal("<\{name}>")
    VCall(func, args) => @debug.Repr::ctor(func.describe(), args_repr(args))
    VGlobal(path) => @debug.Repr::literal(path)
    VCallback(callback) =>
      @debug.Repr::literal("<callback of \{callback.origin.kind}>")
    VSpread(inner) =>
      @debug.Repr::ctor("spread", [(Option::None, @debug.Debug::to_repr(inner))])
    VEngine(value) => @debug.Repr::literal(value.repr())
    VInvalid(message) =>
      @debug.Repr::ctor("invalid", [
        (Option::None, @debug.Repr::string(message)),
      ])
  }
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Value with @debug.Debug::{to_repr}

///|
/// A description as its constructor call: `Heading("Title", level=2)`,
/// `Seq(["a", Emph("b")])`, `Prose([..])` with its pieces.
pub impl @debug.Debug for Content with fn to_repr(self) {
  match self.node {
    NText(text, Option::None) => @debug.Repr::string(text)
    NText(text, Some(_)) =>
      @debug.Repr::ctor("Lit", [(Option::None, @debug.Repr::string(text))])
    NCall(call) => {
      // (The pieces that `Prose` and `Quoted` make, quotes and breaks, are
      // call values, which are named by their function.)
      let name = call.origin.kind
      let args = args_repr(call.args)
      // A generic call names its function.
      if call.func is FPath(path) {
        args.insert(0, (Option::None, @debug.Repr::string(path)))
      }
      @debug.Repr::ctor(name, args)
    }
    NSeq(children, site) if site.kind == "Para" => para_repr(children)
    NSeq(children, site) =>
      @debug.Repr::ctor(site.kind, [
        (
          Option::None,
          @debug.Repr::array(
            children.map(child => @debug.Debug::to_repr(child)),
          ),
        ),
      ])
    // A run of pieces without a site (the text after a block in `Para`).
    NPieces(children) =>
      @debug.Repr::array(children.map(child => @debug.Debug::to_repr(child)))
    NSetRule(set) => {
      let args = args_repr(set.args)
      if set.func is FPath(path) {
        args.insert(0, (Option::None, @debug.Repr::string(path)))
      }
      @debug.Repr::ctor(set.origin.kind, args)
    }
    NShowRule(show) => {
      let args : Array[(String?, @debug.Repr)] = []
      if show.selector is Some(selector) {
        args.push((Option::None, @debug.Debug::to_repr(selector)))
      }
      args.push(
        (
          Option::None,
          match show.transform {
            TFunc(_) => @debug.Repr::literal("<callback>")
            TStyle(set) => @debug.Debug::to_repr(Content::of(NSetRule(set)))
            TValue(value) => @debug.Debug::to_repr(value)
          },
        ),
      )
      @debug.Repr::ctor(show.origin.kind, args)
    }
    NLabelled(body, label, site, _) =>
      if site.kind == "Labelled" {
        @debug.Repr::ctor("Labelled", [
          (Option::None, @debug.Debug::to_repr(body)),
          (Option::None, @debug.Repr::string(label)),
        ])
      } else {
        // The `label` parameter of a constructor.
        @debug.Repr::ctor("Labelled", [
          (Option::None, @debug.Debug::to_repr(body)),
          (Some("label"), @debug.Repr::string(label)),
        ])
      }
    NKeyed(key, body) =>
      @debug.Repr::ctor("Keyed", [
        (Option::None, @debug.Repr::string(key)),
        (Option::None, @debug.Debug::to_repr(body)),
      ])
    // A composite: its name around what it is made of.
    NComposite(body, site) =>
      @debug.Repr::ctor(site.kind, [(Option::None, @debug.Debug::to_repr(body))])
    NContext(_, _) =>
      @debug.Repr::ctor("Context", [
        (Option::None, @debug.Repr::literal("<callback>")),
      ])
    NEval(node) => {
      let args = [(Option::None, @debug.Repr::string(node.source))]
      args.append(args_repr(node.args))
      if !node.scope.is_empty() {
        args.push(
          (
            Some("scope"),
            @debug.Repr::map(
              node.scope.map(pair => {
                (@debug.Repr::string(pair.0), @debug.Debug::to_repr(pair.1))
              }),
            ),
          ),
        )
      }
      @debug.Repr::ctor(node.origin.kind, args)
    }
    NSpace(false) => @debug.Repr::ctor("Space", [])
    NSpace(true) => @debug.Repr::ctor("Space::newline", [])
    // Engine content (a view): Typst's own representation of the
    // element, which has its fields and no spans or locations.
    NEngine(content) =>
      @debug.Repr::ctor("View", [
        (Option::None, @debug.Repr::literal(content.repr())),
      ])
    NValue(value) => @debug.Debug::to_repr(value)
    NInvalid(message, site, _) =>
      @debug.Repr::ctor(site.kind, [
        (Some("invalid"), @debug.Repr::string(message)),
      ])
  }
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Content with @debug.Debug::{to_repr}

///|
/// A `Para` as its call: the pieces of its text (without the paragraph
/// breaks around them and the rules that lowering needs) and its options.
fn para_repr(children : Array[Content]) -> @debug.Repr {
  let pieces : Array[@debug.Repr] = []
  let args : Array[(String?, @debug.Repr)] = []
  let last = children.length() - 1
  let mut opened = false
  for i, child in children {
    match child.node {
      NSetRule(set) => args.append(args_repr(set.args))
      NPieces(run) =>
        for piece in run {
          if !(piece.node is NSetRule(_)) {
            pieces.push(@debug.Debug::to_repr(piece))
          }
        }
      _ =>
        if !opened && is_parbreak_piece(child) {
          opened = true
        } else if i != last {
          pieces.push(@debug.Debug::to_repr(child))
        }
    }
  }
  args.insert(0, (Option::None, @debug.Repr::array(pieces)))
  @debug.Repr::ctor("Para", args)
}

// The handwritten description types.

///|
pub impl @debug.Debug for Prose with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Prose with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Para with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Para with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Seq with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Seq with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Lit with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Lit with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Labelled with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Labelled with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Keyed with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Keyed with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Space with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Space with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Symbol with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Symbol with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Quoted with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Quoted with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Markup with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Markup with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Equation with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Equation with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Call with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Call with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Context with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Context with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Layout with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Layout with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for CounterStep with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CounterStep with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for CounterUpdate with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CounterUpdate with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for ContentView with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ContentView with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Document with fn to_repr(self) {
  guard self.content.node is NSeq(children, _) else {
    return @debug.Debug::to_repr(self.content)
  }
  let args : Array[(String?, @debug.Repr)] = [
    (
      Option::None,
      @debug.Repr::array(children.map(child => @debug.Debug::to_repr(child))),
    ),
  ]
  if self.dir != "" {
    args.push((Some("dir"), @debug.Repr::string(self.dir)))
  }
  @debug.Repr::ctor("Document", args)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Document with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Set with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Set with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Show with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Show with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for ShowSet with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ShowSet with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for ShowWith with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ShowWith with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for NoneValue with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NoneValue with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for AutoValue with fn to_repr(self) {
  @debug.Debug::to_repr(IntoContent::into_content(self))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AutoValue with @debug.Debug::{to_repr}
