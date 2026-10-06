// numbly 0.1.0: heading numbering patterns per level ({n:format}, plain {n},
// none for a level, a function for a level, the default beyond the last
// pattern), the same for nested enums (full: true), page numbering, used
// with outline, references, and a switch of pattern for an appendix.
// Stresses numbering closures called from headings, outline entries,
// references and counters; regex replace with a callback; several pages.
#import "@preview/numbly:0.1.0": numbly

#set page(
  width: 13cm,
  height: 17cm,
  margin: 1.4cm,
  // One number (outline, references): "page i"; two numbers (the footer,
  // which also passes the total): "i of 4".
  numbering: numbly("page {1:i}", "{1:i} of {2}"),
  header: context {
    let parts = query(selector(heading.where(level: 1)).before(here()))
    if parts.len() > 0 {
      set text(size: 8pt)
      counter(heading).display(numbly("{1:I}", "{1:I} § {2}", default: (..n) => numbering("I § 1", ..n.pos().slice(0, 2))))
      h(1fr)
      emph(parts.last().body)
    }
  },
)
#set text(size: 10pt)
#set par(justify: true)

#set heading(numbering: numbly(
  "Part {1:I}.",
  "§ {2}",
  "§ {2}.{3:a}",
  none,
  (..n) => "(" + n.pos().slice(2).map(str).join("/") + ")",
  default: "1.1.1.1.1.1 —",
))

#set enum(
  full: true,
  numbering: numbly("{1:1}.", "{1:1}.{2:a})", "({3:i})", default: (..n) => "[" + str(n.pos().last()) + "]"),
)

#outline(title: [Statutes of the Rowing Club], depth: 3)

= Name and purpose <part:name>

== Name

The club is called the Upper Reach Rowing Club. It was founded on the day
the first eight was launched.

== Purpose <sec:purpose>

The purpose of the club is the promotion of rowing as a sport for all ages.

=== Means <sec:means>

+ The club maintains
  + a boathouse,
    + with a workshop,
    + with a changing room,
  + a landing stage,
  + a fleet of
    + racing shells,
    + touring boats.
      + This level has no pattern of its own and falls back to the default.
+ The club organises
  + regular outings,
  + one regatta a year.

=== Limits

The club does not pursue commercial aims.

==== An unnumbered level

The fourth level has `none` as its pattern, so this heading carries no
number, but it still counts.

===== A level numbered by a function

===== Another one

====== Beyond the patterns

= Membership <part:members>

== Kinds of members

+ Active members row.
+ Supporting members pay.
+ Honorary members do neither.

== Admission <sec:admission>

Admission is decided by the committee; see @sec:purpose for what a candidate
signs up to, and @sec:means for what the club offers in return.

=== Juniors

=== Guests

== Leaving

A member leaves by written notice, as set out in @part:members. The first
part is @part:name.

#pagebreak()

#counter(heading).update(0)
#set heading(
  numbering: numbly("Annex {1:A}:", "{1:A}-{2:01}", "{1:A}-{2:01}-{3:①}"),
  supplement: [Annex],
)

= Fees <annex:fees>

== Annual fee

#table(
  columns: (1fr, auto),
  table.header[Kind][per year],
  [Active], [120],
  [Supporting], [60],
  [Junior], [40],
)

== Boat storage <annex:storage>

=== Singles

=== Doubles

= House rules

== Before an outing

#set enum(numbering: numbly("{1:A}", "{1:A}{2}", "{1:A}{2}{3:a}"), full: true)

+ Sign the log book.
  + Name the boat.
  + Name the crew.
    + Stroke first.
    + Cox last.
+ Check the plugs.

== After an outing

Wash the boat. Fees are in @annex:fees, racks in @annex:storage; the
admission rules are back in @sec:admission.
