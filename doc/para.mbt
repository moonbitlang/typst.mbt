// `Para` (docs/edsl-ports.md, section 3.1): a paragraph of running text.
//
//   (
//     $|Each dot is one complete trial of all nine milestones.
//   ) |> Para
//   Para("One line.", justify=true)
//
// `Prose` is inline content: two of them next to each other in a sequence
// are one paragraph with nothing between them (finding S1 of the ports).
// `Para` is what an author means by a paragraph of text: text between two
// paragraph breaks, as a paragraph is in Typst source. It is not the `par`
// element: `par[..]` cannot hold a block (the engine drops a displayed
// formula in it with a warning), and a paragraph of a paper holds them.

///|
/// A paragraph of running text: the text of a [Prose] between two
/// paragraph breaks.
///
/// `text` is the text of a `Prose`: white space between words is one
/// space, `"` and `'` are smart quotes (`quotes=false`: they are text),
/// interpolated descriptions (`\{Emph("x")}`) are the descriptions, and
/// nothing else is parsed.
///
/// - Two `Para`s are two paragraphs, wherever they are; a blank line in
///   the text is a paragraph break, so the text is several paragraphs.
/// - A block may be interpolated: a displayed formula
///   (`\{Equation("..", block=true)}`), a list, a figure. The engine ends
///   the paragraph at a block and starts another one after it; `Para`
///   keeps the text after the block from being indented as a new
///   paragraph (`first-line-indent: 0pt` for that text, up to the next
///   paragraph break), so that it reads as the continuation it is. This
///   holds for the blocks that the description shows (the constructors
///   that lint L1 takes for blocks), not for what a callback, a `Call` or
///   a view produces.
/// - The options are those of `par`, set for the paragraphs of this text
///   (`set par(..)`), `extra` for the ones without a parameter
///   (`first-line-indent`). As a set rule they also reach paragraphs
///   inside the text (a footnote, a box with paragraphs), unlike the
///   arguments of `Par(..)`.
/// - There is no `par` element to label: `Para` has no `label`.
///
/// Explicit states besides a value:
/// - `linebreaks`: `auto` as `extra` with `Value::auto()`
///
/// Provenance: one call site. The words of the text are pieces of the
/// `text` argument of this call, as the words of a `Prose` are pieces of
/// its argument.
///
/// Twin: the content block with the expansion of the text (`Prose`)
/// between two `parbreak()`s, after `set par(..)` if an option is given,
/// and with the text after a block in a block of its own:
/// `Para("a \{Equation("x", block=true)} b", justify=true)` is
/// `[#set par(justify: true);#parbreak()#"a" #math.equation(block: true, ..) #[#set par(first-line-indent: 0pt);#"b"]#parbreak()]`.
pub struct Para {
  priv content : Content
}

///|
/// A call without a location of its own, which takes a span of the
/// argument it is in (`Pieces`): the paragraph breaks of `Para`.
fn piece_call(elem : @library.Element) -> Content {
  Content::of(NValue(Value::of(VCall(FElem(elem), []))))
}

///|
/// Whether a piece of running text is a paragraph break (a blank line of
/// the text, `prose_pieces`).
fn is_parbreak_piece(content : Content) -> Bool {
  content.node is NValue({ val: VCall(FElem(elem), _), }) &&
  elem == @library.parbreak_elem()
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
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Para {
  // The one site: the sequence, its rules and the pieces of the text.
  let site = Site::new("Para", loc, args_loc)
  let pieces = match prose_pieces(text, quotes, "Para") {
    Ok(pieces) => pieces
    Err(message) => return { content: Content::of(NInvalid(message, site)), }
  }
  // The options, as `set par(..)` for the sequence: the arguments of
  // `SetPar`, with the indices of this constructor's parameters.
  let args : Array[ArgNode] = []
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
  let children : Array[Content] = []
  if !args.is_empty() {
    children.push(
      Content::of(
        NSetRule({ func: FElem(@library.par_elem()), args, origin: site, }),
      ),
    )
  }
  children.push(piece_call(@library.parbreak_elem()))
  // The text after a block, up to the next block or paragraph break, is a
  // paragraph for the engine and a continuation for the reader: it gets
  // no first-line indent.
  let mut continuation : Array[Content]? = Option::None
  let close = () => {
    if continuation is Some(run) && run.length() > 1 {
      children.push(Content::of(NPieces(run)))
    }
    continuation = Option::None
  }
  for piece in pieces {
    if is_block(piece) {
      close()
      children.push(piece)
      continuation = Some([
        Content::of(
          NSetRule({
            func: FElem(@library.par_elem()),
            args: [
              {
                name: Some("first-line-indent"),
                value: ToValue::to_value(Length::Pt(0)),
                param: -1,
              },
            ],
            origin: site,
          }),
        ),
      ])
    } else if is_parbreak_piece(piece) {
      close()
      children.push(piece)
    } else if continuation is Some(run) {
      // (A space right after the block is nothing on the page. It stays
      // outside, so that a run of nothing but that space is not made.)
      if run.length() == 1 && piece.node is NSpace(_) {
        children.push(piece)
      } else {
        run.push(piece)
      }
    } else {
      children.push(piece)
    }
  }
  close()
  children.push(piece_call(@library.parbreak_elem()))
  { content: Content::of(NSeq(children, site)), }
}

///|
pub impl IntoContent for Para with fn into_content(self) {
  self.content
}
