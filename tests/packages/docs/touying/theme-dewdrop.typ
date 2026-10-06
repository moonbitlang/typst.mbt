// touying 0.8.0: the dewdrop theme with title, outline and focus slides, a footer function and the mini-slides navigation. The same deck for every theme:
// `#pause` and `#meanwhile` in text and lists, `uncover`/`only`/`alternatives`, a
// two-column slide with a table, equations with pauses and `touying-equation`, raw
// code, a figure, sections and subsections. Engine paths: the theme's show
// rules and page setup, heading-driven slide splitting, subslide repetition, counters
// and states read in headers and footers.
#import "@preview/touying:0.8.0": *
#import themes.dewdrop: *

#show: dewdrop-theme.with(aspect-ratio: "16-9", footer: self => self.info.institution, navigation: "mini-slides", config-info(title: [Title], subtitle: [Subtitle], author: [Authors], date: datetime(year: 2026, month: 10, day: 6), institution: [Institution]))

#title-slide()

#outline-slide()

= Introduction

== Pauses and lists

A first line. #pause Then a second one.

#pause

- Typesetting is #text(fill: red)[deterministic]
- Slides are pages #pause
- Animations are subslides

#meanwhile

Meanwhile, this text is on every subslide.

== Uncover, only, alternatives

#uncover("2-")[Uncovered from the second subslide on.]

#only(2)[Only on the second.]

#alternatives[First alternative][Second, a longer alternative][Third]

== Two columns

#slide(composer: (1fr, 2fr))[
  Left column with a list:
  + one
  + two #pause
  + three
][
  #table(
    columns: (1fr, auto, auto),
    table.header[Stage][Cases][Match],
    [eval], [3792], [yes],
    [paged], [2299], [yes],
    [shape], [4598], [yes],
  )
]

= Mathematics

== Equations with pauses

$ a^2 + b^2 = c^2 $

#pause

$ sum_(k=1)^n k = (n(n+1)) / 2 quad "and" quad integral_0^1 x^2 dif x = 1/3 $

#touying-equation(`
  f(x) &= pause x^2 + 2x + 1 \
       &= pause (x + 1)^2
`)

== Code and figure

```rust
fn main() {
    println!("hello");
}
```

#figure(rect(width: 40%, height: 2cm, fill: gradient.linear(blue, purple)), caption: [A gradient])

= Conclusion

== Summary

#lorem(30)

#focus-slide[Thank you]
