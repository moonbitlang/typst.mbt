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
/// How a bed ended the season.
priv enum Outcome {
  Harvested
  Growing
  Lost
}

///|
/// What the table says about an outcome.
fn Outcome::label(self : Outcome) -> String {
  match self {
    Harvested => "harvested"
    Growing => "still growing"
    Lost => "lost to the wind"
  }
}

///|
/// A bed: its name, what grew in it, when it was sown, what it gave in
/// kilograms, and how it ended.
priv struct Bed {
  id : String
  crop : String
  sown : String
  kilograms : Double
  outcome : Outcome
}

///|
let beds : Array[Bed] = [
  {
    id: "N1",
    crop: "Tomatoes, a tall variety",
    sown: "12 May",
    kilograms: 3.4,
    outcome: Lost,
  },
  {
    id: "N2",
    crop: "Runner beans on the fence",
    sown: "14 May",
    kilograms: 9.8,
    outcome: Harvested,
  },
  { id: "N3", crop: "Chard", sown: "14 May", kilograms: 6.1, outcome: Growing, },
  {
    id: "E1",
    crop: "Tomatoes, a bush variety",
    sown: "19 May",
    kilograms: 11.2,
    outcome: Harvested,
  },
  {
    id: "E2",
    crop: "Courgettes",
    sown: "19 May",
    kilograms: 4.7,
    outcome: Harvested,
  },
  { id: "E3", crop: "Kale", sown: "2 June", kilograms: 1.9, outcome: Growing, },
  {
    id: "S1",
    crop: "Lettuce, then radishes",
    sown: "5 May",
    kilograms: 0.6,
    outcome: Harvested,
  },
  {
    id: "S2",
    crop: "Sweet peas, for the bees",
    sown: "5 May",
    kilograms: 0.0,
    outcome: Lost,
  },
  { id: "S3", crop: "Leeks", sown: "9 June", kilograms: 0.3, outcome: Growing, },
  {
    id: "W1",
    crop: "Herbs",
    sown: "21 May",
    kilograms: 0.2,
    outcome: Harvested,
  },
]

///|
/// The table of the beds: its head, and its columns (the crop takes what
/// the others leave).
let bed_head : Array[String] = ["Bed", "Crop", "Sown", "Harvest (kg)", "State"]

///|
let bed_columns : Array[Sizing] = [Auto, Fr(1), Auto, Auto, Auto]

///|
/// The rows of the table of the beds. `state` draws how a bed ended, which
/// the two versions do differently.
fn[T : IntoContent] bed_rows(
  state : (String, Outcome) -> T,
) -> Array[Array[&IntoContent]] {
  beds.map(bed => {
    let row : Array[&IntoContent] = [
      bed.id,
      bed.crop,
      bed.sown,
      @format.fixed(bed.kilograms, 1),
      state(bed.outcome.label(), bed.outcome),
    ]
    row
  })
}

///|
/// The bed that gave the most: its row is marked.
fn best_bed() -> Int {
  let mut best = 0
  for i, bed in beds {
    if bed.kilograms > beds[best].kilograms {
      best = i
    }
  }
  best
}

///|
/// A stage of a plant's year, for the diagram: its name and a note.
priv struct Stage {
  name : String
  note : String
}

///|
let stages : Array[Stage] = [
  { name: "Sow", note: "indoors, in March", },
  { name: "Prick out", note: "into pots", },
  { name: "Harden off", note: "a week outside", },
  { name: "Plant", note: "after the frosts", },
  { name: "Harvest", note: "July to October", },
]

///|
/// The stage that waits for the weather: the arrow into it is dashed.
let waits : String = "Plant"

///|
/// What the arrow from the last stage back to the first says.
let back_label : String = "seed kept for next year"

///|
/// What a bar of the chart says at its end.
fn kilograms(bed : Bed) -> String {
  @format.fixed(bed.kilograms, 1) + " kg"
}

///|
/// The report around what the two versions build differently: the row of
/// tiles, the two groups of notes, the table of the beds, the chart of the
/// harvest and the diagram of the year.
fn report(
  tile_row : &IntoContent,
  worked_cards : &IntoContent,
  change_cards : &IntoContent,
  bed_table : &IntoContent,
  harvest_chart : &IntoContent,
  year_diagram : &IntoContent,
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
    Pagebreak(),
    Heading("Bed by bed", level=2),
    Para(
      "Ten of the fourteen beds were weighed. The bed that gave the most is marked; three are still in the ground.",
    ),
    bed_table,
    Para(
      "The beds are covered for the winter. The next meeting is on the first Saturday of March.",
    ),
    Pagebreak(),
    Heading("Kilograms by bed", level=2),
    Para("The same ten beds by what they gave, in the colours of their state."),
    harvest_chart,
    Heading("A plant's year", level=2),
    Para(
      "What happens to a plant between March and October. Planting waits for the last frost, and the year closes on itself.",
    ),
    year_diagram,
  ])
}
