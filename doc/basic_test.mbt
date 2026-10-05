///|
using @doc {
  type Document,
  type Heading,
  type Par,
  type Seq,
  type Emph,
  type Strong,
  type SetText,
  type SetHeading,
  type SetPage,
  type Show,
  type Select,
  type Block,
  type Text,
  type V,
  type DocWorld,
}

///|
test "a small document compiles to SVG" {
  let doc = Document([
    SetPage(width=Pt(200), height=Pt(120), margin=Sides(all=Pt(10))),
    SetText(size=Pt(10)),
    SetHeading(numbering=Numbering("1.")),
    Show(Select::heading()) <| ((it, _) => {
      Seq([V(Em(0.5)), Block(Text(it, fill=Rgb("#1f4e79")))])
    }),
    Heading("Introduction"),
    Par(Seq(["Typeset with ", Emph("care"), " and ", Strong("MoonBit"), "."])),
  ])
  let report = doc.compile_paged(DocWorld::in_memory())
  for e in report.errors {
    println(e.render())
  }
  for w in report.warnings {
    println(w.render())
  }
  assert_true(report.errors.is_empty())
  let pages = report.svg_pages().unwrap()
  assert_eq(pages.length(), 1)
  assert_true(pages[0].contains("<svg"))
  assert_true(pages[0].contains("#1f4e79"))
}
