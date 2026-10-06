// What both versions of the report need besides the cards: the colours,
// the measures of a card, and what is inside a tile and a card. Helper
// code by the rule of docs/edsl-ports.md, section 9 (no text or data of
// the document), in both counts.

///|
using @doc {
  type Document,
  type SetPage,
  type SetText,
  type SetPar,
  type SetBlock,
  type Heading,
  type Para,
  type Seq,
  type Text,
  type Block,
  type Grid,
  type Keyed,
  type Context,
  type Sides,
  type Stroke,
  type Paint,
  type Sizing,
  trait IntoContent,
}

///|
let ink : Paint = Rgb("#1d2a24")

///|
let muted : Paint = Rgb("#5f6f66")

///|
let surface : Paint = Rgb("#f3f6f1")

///|
let hairline : Sides[Stroke] = Sides(
  all=Stroke(paint=Rgb("#c9d3cb"), thickness=Pt(0.5)),
)

///|
/// The gap between cards, their inset and the radius of their corners, in
/// points.
const GUTTER : Double = 8

///|
const INSET : Double = 9

///|
const RADIUS : Double = 5

///|
/// What is in a tile: the figure, its label and the note.
fn tile_body(tile : Tile) -> Seq {
  Seq([
    SetBlock(spacing=Pt(5)),
    Block(Text(tile.figure, size=Pt(17), weight=Bold)),
    Block(Text(tile.label, size=Pt(9))),
    Block(Text(tile.note, size=Pt(7), fill=muted)),
  ])
}

///|
/// What is in a card: the title and the text.
fn note_body(note : Note) -> Seq {
  Seq([
    SetBlock(spacing=Pt(5)),
    Block(Text(note.title, weight=SemiBold)),
    Block(Text(note.text, size=Pt(8.5))),
  ])
}
