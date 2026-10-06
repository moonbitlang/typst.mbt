// Small typed helpers for what Typst markup writes with punctuation
// (docs/edsl-design.md, section 4.3). Plain strings are literal text and are
// never parsed, so these constructs need a constructor.

///|
/// Content in smart quotes: `Quoted("English")` is markup's `"English"`, a
/// `smartquote` before and after the body, which the engine resolves by the
/// text language and the nesting of quotes. (A `"` inside a plain string
/// stays a straight quote.) `double=false` gives single quotes.
///
/// Twin: `[#smartquote()#body#smartquote()]`.
pub struct Quoted {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Quoted::Quoted(
  body : &IntoContent,
  double? : Bool,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Quoted {
  let site = Site::new("Quoted", loc, args_loc)
  // The two quotes are calls without a location of their own, like the
  // quotes of `Prose`: each takes a span of its own inside the body
  // argument's when the sequence is lowered (`Pieces` in `lower.mbt`).
  let quote = () => {
    let args : Array[ArgNode] = []
    if double is Some(v) {
      args.push({ name: Some("double"), value: Value::bool(v), param: -1, })
    }
    Content::of(
      NValue(Value::of(VCall(FElem(@library.smart_quote_elem()), args))),
    )
  }
  { content: Content::of(NSeq([quote(), described(body), quote()], site)), }
}

///|
pub impl IntoContent for Quoted with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Quoted with IntoContent::{into_content}

///|
/// The display of a symbol: what markup's escapes (`\\#`) and shorthands
/// (`~`, `--`, `...`) evaluate to. It is laid out like the text, but it is
/// a `symbol` element until realization, which converted markup keeps.
/// Authors write the character in a string instead.
///
/// Twin: `#symbol("..")`.
pub struct Symbol {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Symbol::Symbol(
  text : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Symbol {
  {
    content: Content::of(
      NCall({
        func: FNative(@library.native_symbol_construct()),
        args: [{ name: Option::None, value: Value::str(text), param: 0, }],
        origin: Site::new("Symbol", loc, args_loc),
      }),
    ),
  }
}

///|
pub impl IntoContent for Symbol with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Symbol with IntoContent::{into_content}
