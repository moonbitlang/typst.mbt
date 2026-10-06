// `Para` (docs/edsl-ports.md, section 3.1): a paragraph of running text.
//
//   (
//     $|Each dot is one complete trial of all nine milestones.
//   ) |> Para
//   Para("One line.", justify=true)
//
// `Prose` is inline content: two of them next to each other in a sequence
// are one paragraph with nothing between them (finding S1 of the ports).
// `Para` is what an author means by a paragraph of text.

///|
/// A paragraph of running text: `Par(Prose(text, quotes~), ..)` as one
/// constructor, with the options of `Par` and of `Prose`.
///
/// `text` is the text of a [Prose]: white space between words is one
/// space, `"` and `'` are smart quotes (`quotes=false`: they are text),
/// interpolated descriptions (`\{Emph("x")}`) are the descriptions, and
/// nothing else is parsed.
///
/// One `Para` is one paragraph. A blank line in the text is a paragraph
/// break as in `Prose`, which a paragraph cannot hold: the engine ignores
/// it with a warning at the text (`parbreak may not occur inside of a
/// paragraph and was ignored`), and the text before and after it runs
/// together, as in `Par(Prose(..))`.
///
/// Explicit states besides a value:
/// - `linebreaks`: `auto` as `extra` with `Value::auto()`
///
/// Provenance: one call site. The words of the text are pieces of the
/// `text` argument of this call, as the words of a `Prose` are pieces of
/// its argument; neither a `Par` nor a `Prose` is registered.
///
/// Twin: `par(..)` around the functional expansion of the text
/// (`Prose`): `Para("a \"b\"", justify=true)` is
/// `par(justify: true)[#"a" #smartquote(double: true)#"b"#smartquote(double: true)]`.
pub struct Para {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Para::Para(
  text : String,
  quotes? : Bool = true,
  leading? : Length,
  spacing? : Length,
  justify? : Bool,
  linebreaks? : String,
  hanging_indent? : Length,
  extra? : Array[(String, Value)] = [],
  label? : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Para {
  // The one site: the call of `par` and the pieces of the text have it.
  let site = Site::new("Para", loc, args_loc)
  let pieces = match prose_pieces(text, quotes, "Para") {
    Ok(pieces) => pieces
    Err(message) => return { content: Content::of(NInvalid(message, site)), }
  }
  // The arguments of `Par`, in its order; the indices are those of this
  // constructor's parameters (`quotes` is 1 and no argument of `par`).
  let args : Array[ArgNode] = []
  args.push({
    name: Option::None,
    value: Value::of(VContent(Content::of(NPieces(pieces)))),
    param: 0,
  })
  if leading is Some(v) {
    args.push({ name: Some("leading"), value: ToValue::to_value(v), param: 2, })
  }
  if spacing is Some(v) {
    args.push({ name: Some("spacing"), value: ToValue::to_value(v), param: 3, })
  }
  if justify is Some(v) {
    args.push({ name: Some("justify"), value: Value::bool(v), param: 4, })
  }
  if linebreaks is Some(v) {
    args.push({ name: Some("linebreaks"), value: Value::str(v), param: 5, })
  }
  if hanging_indent is Some(v) {
    args.push({
      name: Some("hanging-indent"),
      value: ToValue::to_value(v),
      param: 6,
    })
  }
  push_extra(args, extra, 7)
  {
    content: labelled_call(
      { func: FElem(@library.par_elem()), args, origin: site, },
      label,
      8,
    ),
  }
}

///|
pub impl IntoContent for Para with fn into_content(self) {
  self.content
}
