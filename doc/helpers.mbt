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
  let quote = () => {
    let args : Array[ArgNode] = []
    if double is Some(v) {
      args.push({ name: Some("double"), value: Value::bool(v), param: 1, })
    }
    Content::of(
      NCall({ func: FElem(@library.smart_quote_elem()), args, origin: site, }),
    )
  }
  { content: Content::of(NSeq([quote(), body.into_content(), quote()], site)), }
}

///|
pub impl IntoContent for Quoted with fn into_content(self) {
  self.content
}
