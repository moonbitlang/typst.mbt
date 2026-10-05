///|
pub fn long() -> @doc.Document {
  Document([
    SetPage(paper="a4", numbering=Numbering("1")),
    SetText(font=["Libertinus Serif"], size=Pt(10.5)),
    SetPar(justify=true),
    SetHeading(numbering=Numbering("1.1")),
    SetEquation(numbering=Numbering("(1)")),
    Outline(),
    Space::newline(),
    Markup(
      "#for chapter in range(1, 13) [\n  = Chapter #chapter\n  #for section in range(1, 4) [\n    == Section #chapter.#section\n    #lorem(180)\n\n    $ sum_(k=0)^n binom(n, k) x^k y^(n-k) = (x + y)^n quad integral_0^1 x^(#chapter) dif x = 1 / #(chapter + 1) $\n\n    #lorem(120)\n\n    #table(\n      columns: 5,\n      ..range(15).map(i => [#(i * chapter * section)])\n    )\n  ]\n]",
    ),
    Space::newline(),
  ])
}
