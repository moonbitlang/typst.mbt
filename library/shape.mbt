// Port of `typst-library/src/visualize/shape.rs` (element field types and
// `#[parse]` hooks; shape geometry is a layout concern).

///|
/// A path filling rule.
pub(all) enum FillRule {
  /// Specifies that "inside" is computed by a non-zero sum of signed edge
  /// crossings.
  NonZero
  /// Specifies that "inside" is computed by an odd number of edge crossings.
  EvenOdd
} derive(Eq, Hash, Debug)

///|
pub impl Default for FillRule with fn default() {
  NonZero
}

///|
pub impl Reflect for FillRule with fn input() {
  Union([
    Value(
      Str("non-zero"),
      "Specifies that \"inside\" is computed by a non-zero sum of signed edge crossings.",
    ),
    Value(
      Str("even-odd"),
      "Specifies that \"inside\" is computed by an odd number of edge crossings.",
    ),
  ])
}

///|
pub impl Reflect for FillRule with fn output() {
  FillRule::input()
}

///|
pub impl Reflect for FillRule with fn castable(v) {
  v is Str("non-zero" | "even-odd")
}

///|
pub impl IntoValue for FillRule with fn into_value(self) {
  match self {
    NonZero => Str("non-zero")
    EvenOdd => Str("even-odd")
  }
}

///|
pub impl FromValue for FillRule with fn from_value(v) {
  match v {
    Str("non-zero") => NonZero
    Str("even-odd") => EvenOdd
    v => raise HintedError(FillRule::input().error(v))
  }
}

// SquareElem: `size` sets both `width` and `height`.

///|
fn square_elem_width_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let size : Smart[Length]? = args.named("size")
  let size = size.map(s => s.map(l => (Rel::from_abs(l) : Rel[Length])))
  let size = size.map(s => s.into_value())
  locals.set("size", size)
  match size {
    None => named_as(args, "width", square_elem(), square_elem_width)
    size => size
  }
}

///|
fn square_elem_height_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  // `Smart<Rel<Length>>` into `Sizing` has the same value representation.
  match locals.get("size") {
    None => named_as(args, "height", square_elem(), square_elem_height)
    size => size
  }
}

// CircleElem: `radius` sets both `width` and `height` to its double.

///|
fn circle_elem_width_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let size : Smart[Length]? = args.named("radius")
  let size = size.map(s => {
    s.map(r => (Rel::from_abs(r).times(2.0) : Rel[Length]))
  })
  let size = size.map(s => s.into_value())
  locals.set("size", size)
  match size {
    None => named_as(args, "width", circle_elem(), circle_elem_width)
    size => size
  }
}

///|
fn circle_elem_height_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  match locals.get("size") {
    None => named_as(args, "height", circle_elem(), circle_elem_height)
    size => size
  }
}
