// The text and the data of the report: invented for this example (a
// rooftop garden after its first season). Both versions of the document
// read them. By the rule of docs/edsl-ports.md, section 9, nothing in this
// file is helper code: every item has text or data of the document.

///|
/// A tile: a figure, what it counts, and a note.
priv struct Tile {
  figure : String
  label : String
  note : String
}

///|
let tiles : Array[Tile] = [
  { figure: "38 kg", label: "Harvest", note: "tomatoes, beans and chard", },
  { figure: "14", label: "Raised beds", note: "each 1.2 m by 2.4 m", },
  {
    figure: "61%",
    label: "Rainwater",
    note: "of all the water used, read off the tank every Friday",
  },
  { figure: "9", label: "Volunteers", note: "two of them every week", },
]

///|
/// A card: a title and a paragraph.
priv struct Note {
  id : String
  title : String
  text : String
}

///|
let worked : Array[Note] = [
  {
    id: "mulch",
    title: "Straw mulch",
    text: "The beds under straw needed water every third day in July; the bare ones every day.",
  },
  { id: "beans", title: "Beans on the fence", text: "No frame to build.", },
  {
    id: "rota",
    title: "A watering rota on the door",
    text: "A paper list worked better than the group chat: whoever came could see at once what was done and what was not, and nobody watered twice.",
  },
]

///|
let to_change : Array[Note] = [
  {
    id: "wind",
    title: "Wind",
    text: "The tall tomato varieties broke twice. Next year: bush varieties on the north side, and stakes before planting.",
  },
  {
    id: "compost",
    title: "Compost",
    text: "One bin is not enough for fourteen beds.",
  },
  {
    id: "seedlings",
    title: "Seedlings",
    text: "Sowing on the windowsill in March gave thin plants. A cold frame on the roof is planned.",
  },
  {
    id: "paths",
    title: "Paths",
    text: "Sixty centimetres between the beds is too narrow for the wheelbarrow.",
  },
  {
    id: "labels",
    title: "Labels",
    text: "Pencil on wood lasted the season; the printed ones faded by June.",
  },
]

///|
/// The report around its three groups of cards: the row of tiles and the
/// two groups of notes, which the two versions build differently.
fn report(
  tile_row : &IntoContent,
  worked_cards : &IntoContent,
  change_cards : &IntoContent,
) -> Document {
  Document([
    SetPage(width=Pt(420), height=Pt(595), margin=Sides(all=Pt(36))),
    SetText(size=Pt(10), fill=ink),
    SetPar(justify=true),
    Heading("Rooftop garden: the first season"),
    Para(
      "Fourteen beds were built on the roof of the workshop in April and planted in May. This is what the season gave, what worked, and what we will do differently next year.",
    ),
    tile_row,
    Heading("What worked", level=2),
    Para(
      "Three things that cost little and that we would do again without thinking about it.",
    ),
    worked_cards,
    Heading("What to change", level=2),
    Para(
      "Five notes from the last meeting of the season, in the order in which they came up.",
    ),
    change_cards,
    Para(
      "The beds are covered for the winter. The next meeting is on the first Saturday of March.",
    ),
  ])
}
