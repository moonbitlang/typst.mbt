// Tests of the typed additions of docs/edsl-ports.md, sections 3.2 to 3.4:
// `Layout`, the baseline of a measured size, and the typed parameters and
// values. The pairs with a Typst twin are in `doc/twins/ports.mbt`.

///|
/// The constructor and the argument a diagnostic is located at.
fn origin_arg(diagnostic : @doc.Diagnostic) -> String raise {
  let origin = origin_of(diagnostic)
  match origin.param {
    Some(index) => "\{origin.kind}, argument \{index}"
    None => origin.kind
  }
}

///|
/// The lowered content of a document, as Typst prints it.
fn lowered(children : Array[&@doc.IntoContent]) -> String raise {
  @doc.Document(children).lower(@doc.DocWorld::in_memory()).unwrap().repr()
}

///|
test "`Box(baseline=)` is the shift form; the other forms go through `extra`" {
  inspect(
    lowered([@doc.Box("x", baseline=Pt(2))]),
    content=(
      #|box(baseline: (shift: 0% + 2pt), body: [x])
    ),
  )
  inspect(
    lowered([@doc.Box("x", baseline=Pct(-40) + Pt(1))]),
    content=(
      #|box(baseline: (shift: -40% + 1pt), body: [x])
    ),
  )
  // The alignment form and the dictionary form.
  inspect(
    lowered([
      @doc.Box("x", extra=[("baseline", @doc.Value::alignment(Horizon))]),
    ]),
    content=(
      #|box(baseline: (at: horizon), body: [x])
    ),
  )
  inspect(
    lowered([
      @doc.Box("x", extra=[
        (
          "baseline",
          @doc.Value::dict([
            ("at", @doc.Value::alignment(Bottom)),
            ("shift", @doc.Value::length(Pt(10))),
          ]),
        ),
      ]),
    ]),
    content=(
      #|box(
      #|  baseline: (at: bottom, shift: 0% + 10pt),
      #|  body: [x],
      #|)
    ),
  )
  // The set rule, and what the field does not accept.
  inspect(
    error_messages(compile([@doc.SetBox(baseline=Em(0.2)), @doc.Box("x")])),
    content="",
  )
  let none = compile([@doc.Box("x", baseline=None)])
  inspect(
    error_messages(none),
    content=(
      #|expected alignment, auto, relative length, or dictionary, found none
    ),
  )
  inspect(
    origin_arg(none.errors[0]),
    content=(
      #|Box, argument 3
    ),
  )
}
