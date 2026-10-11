// Page runs and the document: a compilation keeps the layout of every page
// run and of the document for the next one (`docs/incremental-design.md`,
// slice 3). This document is made of many runs, most of which do not
// change with an edit, and of things that a run or the document reads
// from outside of its children: the rest of the document (a running
// header, the number of pages, an outline, the pages of labels), a file
// that a function reads when a footer is laid out, and the position of
// the run among the pages (parity, two-sided margins).
#import "parts.typ": fact, leaf, part, parts, running, tally

#set document(title: [Pages], author: ("Ada", "Bob"), keywords: ("runs",))
#set page(
  width: 220pt,
  height: 170pt,
  margin: (inside: 26pt, outside: 14pt, top: 30pt, bottom: 28pt),
  // A header that queries the document.
  header: context running(),
  // A footer with the number of the page and of all pages, and with what
  // a function read from a file when the footer was laid out.
  footer: context [
    #set text(7pt)
    #counter(page).display("1 of 1", both: true)
    #h(1fr)
    #fact() #tally.final().first()
  ],
)
#set text(size: 8pt)
#set heading(numbering: "1.1")
#set par(justify: true)

#outline()

// The first run: text with footnotes that go across pages.
#part[Footnotes]

The first note#footnote[A note that is long enough to be broken across two
  pages if it stands at the end of one: #lorem(30)] is long, the
second#footnote[Short.] is short, and a third one#footnote[Another long
  one, further down, #lorem(24)] comes after some text: #lorem(40)

The label of the second part is on page #context locate(<second>).page(),
that of the last on page #context locate(<last>).page() of
#context counter(page).final().first().

// A page set rule in the middle: a run with other pages.
#set page(flipped: true, columns: 2, fill: rgb("#f4f1e8"))

#part[Two columns] <second>

#lorem(60) #footnote[In a column.]

#colbreak()

#tally.step()
#lorem(25)

// Runs that are the same, child for child and span for span: what tells
// them apart is where they are.
#for i in range(3) {
  leaf[The same leaf, #context counter(page).display().]
}

// A blank page for the parity, and pages with their own numbering.
#pagebreak(to: "odd")
#set page(flipped: false, columns: 1, fill: none, numbering: "i")
#counter(page).update(1)

#part[Roman numbers]

Page #context counter(page).display() of the back matter, which starts on
page #context here().page() of the document. #tally.step()

#page(width: 120pt, height: 90pt, margin: 8pt, header: none, footer: none)[
  A page of its own, with #context parts.final().first() parts in the
  document and a tally of #context tally.get().first().
]

#part[The end] <last>

The parts: #context {
  query(heading.where(level: 1))
    .filter(it => it.numbering != none)
    .map(it => [#it.body on #it.location().page()])
    .join[, ]
}. #lorem(30)
