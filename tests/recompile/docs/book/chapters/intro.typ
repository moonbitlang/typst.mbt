#import "../lib/shared.typ": note, notes, theorem, theorems

= Introduction <intro>

This book has #context notes.final() counted notes and
#context theorems.final().first() theorems on
#context counter(page).final().first() pages. The data is in @data, the
pictures are in @figures, and @fig-diagram is one of them.#note[A first
note, counted by the shared module.]

#theorem[A compilation of the same files gives the same pages.]

A page is made of lines, and the lines of a paragraph depend on every word
before them: one more word at the start can move the last line to the next
page, where the header names another chapter.

== Background

Typesetting systems that watch their sources compile again after every
change @knuth1984. What they keep from the compilation before must be
exactly what they would compute again @lamport1994.#note[A second note.]

// Citations inside a block, a footnote and a caption: laid out on their
// own, from content that only names the key.
#theorem[A file that is no longer read is no longer watched @lamport1994.]

#figure(
  rect(width: 60%, height: 12pt, fill: luma(220)),
  caption: [A box, after @knuth1984.],
) <fig-box>

The box of @fig-box is grey.#footnote[As in @knuth1984, more or less.]

== Outlook <outlook>

The chapter ends on page #context here().page(), and this section is
numbered #context counter(heading).display().
