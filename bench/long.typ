#set page(paper: "a4", numbering: "1")
#set text(font: "Libertinus Serif", size: 10.5pt)
#set par(justify: true)
#set heading(numbering: "1.1")
#set math.equation(numbering: "(1)")
#outline()
#for chapter in range(1, 13) [
  = Chapter #chapter
  #for section in range(1, 4) [
    == Section #chapter.#section
    #lorem(180)

    $ sum_(k=0)^n binom(n, k) x^k y^(n-k) = (x + y)^n quad integral_0^1 x^(#chapter) dif x = 1 / #(chapter + 1) $

    #lorem(120)

    #table(
      columns: 5,
      ..range(15).map(i => [#(i * chapter * section)])
    )
  ]
]
