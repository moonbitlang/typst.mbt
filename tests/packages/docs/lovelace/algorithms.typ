// lovelace 0.3.1: pseudocode-list with nested indentation, line numbers,
// line labels and references to lines, custom keywords, booktabs with
// numbered titles, inside figures of kind "algorithm" with captions.
// Stresses list -> grid transformation, grid cells with rowspans and partial
// strokes, figure counters updated per line, query before here().
#import "@preview/lovelace:0.3.1": *

#set page(width: 14cm, height: 19cm, margin: 1.4cm, numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.")

#let kw(name) = text(fill: rgb("#8a1c7c"), weight: "bold", name)
#let fn(name) = smallcaps(name)
#let comment(body) = h(1fr) + text(fill: gray.darken(20%), style: "italic", size: 0.9em)[▷ #body]

#show figure.where(kind: "algorithm"): set figure(supplement: [Algorithm])
#show figure.where(kind: "algorithm"): set block(breakable: true)

= Sorting the post

The sorting office receives letters in no order at all. Two procedures are
in use, one for a handful of letters and one for a sack.

#figure(
  kind: "algorithm",
  supplement: [Algorithm],
  caption: [Insertion sort, for a handful of letters.],
  pseudocode-list(booktabs: true, numbered-title: [#fn[Insert-Sort]\(letters $L_1, dots, L_n$)])[
    + #kw[for] $i <- 2$ #kw[to] $n$ #kw[do]
      + $x <- L_i$ #comment[the letter in hand]
      + $j <- i - 1$
      + #line-label(<line:shift>) #kw[while] $j >= 1$ #kw[and] $L_j > x$ #kw[do]
        + $L_(j+1) <- L_j$
        + $j <- j - 1$
      + #kw[end]
      + #line-label(<line:place>) $L_(j+1) <- x$
    + #kw[end]
    + #kw[return] $L$
  ],
) <alg:insert>

In @alg:insert the loop in @line:shift moves later letters one pigeonhole to
the right until the place for $x$ is free; @line:place puts it down.

#figure(
  kind: "algorithm",
  supplement: [Algorithm],
  caption: [Merge sort, for a sack.],
  pseudocode-list(
    booktabs: true,
    numbered-title: [#fn[Sack-Sort]\($L$)],
    line-number-supplement: "Step",
    hooks: .5em,
    stroke: 0.6pt + navy,
  )[
    + #kw[if] $|L| <= 8$ #kw[then]
      + #line-label(<line:base>) #kw[return] #fn[Insert-Sort]\($L$)
    + #kw[else]
      + split $L$ into halves $A$ and $B$
      + $A <- #fn[Sack-Sort]\(A)$; $B <- #fn[Sack-Sort]\(B)$
      + $R <- ()$
      + #line-label(<line:merge>) #kw[while] $A$ and $B$ are both non-empty #kw[do]
        + #kw[if] $"first"(A) <= "first"(B)$ #kw[then]
          + move $"first"(A)$ to the end of $R$
        + #kw[else]
          + move $"first"(B)$ to the end of $R$
        + #kw[end]
      + #kw[end]
      + #kw[return] $R$ followed by what is left of $A$ or $B$
    + #kw[end]
  ],
) <alg:merge>

@alg:merge falls back on @alg:insert in @line:base. The merge loop starts in
@line:merge[step]; the supplement of a line reference can be overridden.

= Without numbers, without a figure

#pseudocode-list(line-numbering: none, indentation: 2em, stroke: none)[
  - *input:* a postcode $p$
  - *output:* the delivery round
  + look up the district of $p$
  + *if* the district is rural
    + *return* the van round
  + *otherwise*
    + *return* the walking round
]

Lines that begin with a bullet instead of a number are never numbered:

#pseudocode-list(line-numbering: "(a)", line-gap: 1em)[
  - _Morning shift_
  + empty the pillar boxes #line-label(<line:empty>)
  + cancel the stamps
  - _Afternoon shift_
  + sort
    + by district
    + by street
      + by house number
  + bundle
]

The first job of the day is @line:empty.

= Two procedures side by side

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  pseudocode-list(title: smallcaps[Weigh], booktabs: true, booktabs-stroke: 1pt + maroon)[
    + put the parcel on the scale
    + *if* weight > 2 kg
      + charge the parcel rate
    + *else*
      + charge the letter rate
  ],
  pseudocode-list(title: smallcaps[Frank], booktabs: true, booktabs-stroke: 1pt + maroon, line-numbering: "I", line-number-alignment: left)[
    + read the rate
    + *repeat*
      + add a stamp
    + *until* the value is reached
    + cancel
  ],
)
