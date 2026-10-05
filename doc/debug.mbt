// Readable output of descriptions (docs/edsl-design.md, section 4.4):
// `Show` of a description is the interpolation hook of `Prose` and writes a
// placeholder; what a description is made of is shown by core's `Debug`:
// `debug(v)`, `debug_inspect(v, content=..)` in tests, `\{Repr(v)}` in
// strings.

///|
/// The representation of a function reference.
fn FuncRef::describe(self : FuncRef) -> String {
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
    out.push((arg.name, arg.value.to_repr()))
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
        (Option::None, a.to_repr()),
        (Option::None, b.to_repr()),
      ])
    VSub(a, b) =>
      @debug.Repr::ctor("sub", [
        (Option::None, a.to_repr()),
        (Option::None, b.to_repr()),
      ])
    VMul(a, b) =>
      @debug.Repr::ctor("mul", [
        (Option::None, a.to_repr()),
        (Option::None, b.to_repr()),
      ])
    VNeg(a) => @debug.Repr::ctor("neg", [(Option::None, a.to_repr())])
    VArray(items) => @debug.Repr::array(items.map(item => item.to_repr()))
    VDict(pairs) =>
      @debug.Repr::map(
        pairs.map(pair => (@debug.Repr::string(pair.0), pair.1.to_repr())),
      )
    VContent(content) => content.to_repr()
    VLabel(name) => @debug.Repr::literal("<\{name}>")
    VCall(func, args) => @debug.Repr::ctor(func.describe(), args_repr(args))
    VGlobal(path) => @debug.Repr::literal(path)
    VCallback(callback) =>
      @debug.Repr::literal("<callback of \{callback.origin.kind}>")
    VSpread(inner) =>
      @debug.Repr::ctor("spread", [(Option::None, inner.to_repr())])
    VEngine(value) => @debug.Repr::literal(value.repr())
    VInvalid(message) =>
      @debug.Repr::ctor("invalid", [
        (Option::None, @debug.Repr::string(message)),
      ])
  }
}

///|
/// A description as its constructor call: `Heading("Title", level=2)`,
/// `Seq(["a", Emph("b")])`, `Prose([..])` with its pieces.
pub impl @debug.Debug for Content with fn to_repr(self) {
  match self.node {
    NText(text, Option::None) => @debug.Repr::string(text)
    NText(text, Some(_)) =>
      @debug.Repr::ctor("Lit", [(Option::None, @debug.Repr::string(text))])
    NCall(call) => {
      // The pieces that `Prose` and `Quoted` make (quotes, breaks) are
      // calls with their site: name them by their function.
      let name = if call.origin.kind == "Prose" || call.origin.kind == "Quoted" {
        call.func.describe()
      } else {
        call.origin.kind
      }
      @debug.Repr::ctor(name, args_repr(call.args))
    }
    NSeq(children, site) =>
      @debug.Repr::ctor(site.kind, [
        (
          Option::None,
          @debug.Repr::array(children.map(child => child.to_repr())),
        ),
      ])
    NSetRule(set) => @debug.Repr::ctor(set.origin.kind, args_repr(set.args))
    NShowRule(show) => {
      let args : Array[(String?, @debug.Repr)] = []
      if show.selector is Some(selector) {
        args.push((Option::None, selector.to_repr()))
      }
      args.push(
        (
          Option::None,
          match show.transform {
            TFunc(_) => @debug.Repr::literal("<callback>")
            TStyle(set) =>
              @debug.Repr::ctor(set.origin.kind, args_repr(set.args))
            TValue(value) => value.to_repr()
          },
        ),
      )
      @debug.Repr::ctor(show.origin.kind, args)
    }
    NLabelled(body, label, site, _) =>
      if site.kind == "Labelled" {
        @debug.Repr::ctor("Labelled", [
          (Option::None, body.to_repr()),
          (Option::None, @debug.Repr::string(label)),
        ])
      } else {
        // The `label` parameter of a constructor.
        @debug.Repr::ctor("Labelled", [
          (Option::None, body.to_repr()),
          (Some("label"), @debug.Repr::string(label)),
        ])
      }
    NKeyed(key, body) =>
      @debug.Repr::ctor("Keyed", [
        (Option::None, @debug.Repr::string(key)),
        (Option::None, body.to_repr()),
      ])
    NContext(_, _) =>
      @debug.Repr::ctor("Context", [
        (Option::None, @debug.Repr::literal("<callback>")),
      ])
    NEval(node) => {
      let args = [(Option::None, @debug.Repr::string(node.source))]
      args.append(args_repr(node.args))
      @debug.Repr::ctor(node.origin.kind, args)
    }
    NSpace(false) => @debug.Repr::ctor("Space", [])
    NSpace(true) => @debug.Repr::ctor("Space::newline", [])
    NEngine(content) =>
      @debug.Repr::ctor("View", [
        (Option::None, @debug.Repr::literal(content.elem().name())),
      ])
    NValue(value) => value.to_repr()
    NInvalid(message, site) =>
      @debug.Repr::ctor(site.kind, [
        (Some("invalid"), @debug.Repr::string(message)),
      ])
  }
}

// The handwritten description types.

///|
pub impl @debug.Debug for Prose with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Seq with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Lit with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Labelled with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Keyed with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Space with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Symbol with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Quoted with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Markup with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Equation with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Call with fn to_repr(self) {
  self.content.to_repr()
}

///|
pub impl @debug.Debug for Context with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for CounterStep with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for CounterUpdate with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for ContentView with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for Document with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for Set with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for Show with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for ShowSet with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for ShowWith with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for NoneValue with fn to_repr(self) {
  self.into_content().to_repr()
}

///|
pub impl @debug.Debug for AutoValue with fn to_repr(self) {
  self.into_content().to_repr()
}
