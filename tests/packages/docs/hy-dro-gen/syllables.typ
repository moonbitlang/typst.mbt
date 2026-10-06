// hy-dro-gen 0.1.1: its WebAssembly plugin (hypher patterns): `exists`,
// `syllables` for words in many languages and scripts, the `languages`
// dictionary read from the package, fallbacks for unknown languages.
// Stresses plugin calls with byte arguments and returned byte strings (many
// calls, non-ASCII input), next to the compiler's own hyphenation of the
// same words in narrow columns.
#import "@preview/hy-dro-gen:0.1.1" as hy

#set page(width: 15cm, height: 20cm, margin: 1.3cm, numbering: "1")
#set text(size: 9.5pt)
#set heading(numbering: "1.")

#let split(word, ..args) = hy.syllables(word, ..args).join(sym.dot.c)

= Breaking words

== One word per language

#let samples = (
  en: ("lighthouse", "extraordinary", "photographer", "a", "rhythm"),
  de: ("Leuchtturmwärter", "Donaudampfschiff", "Straßenbahnhaltestelle", "Übergrößen"),
  fr: ("phare", "extraordinairement", "bibliothèque", "œuvre"),
  es: ("faro", "extraordinario", "murciélago", "desafortunadamente"),
  it: ("faro", "straordinariamente", "precipitevolissimevolmente"),
  pt: ("farol", "extraordinário", "paralelepípedo"),
  nl: ("vuurtoren", "zeemeeuwen", "arbeidsongeschiktheidsverzekering"),
  sv: ("fyrvaktare", "sjuksköterska", "realisationsvinstbeskattning"),
  da: ("fyrtårn", "speciallægepraksisplanlægning"),
  fi: ("majakka", "lentokonesuihkuturbiinimoottori"),
  hu: ("világítótorony", "megszentségteleníthetetlen"),
  pl: ("latarnia", "konstantynopolitańczykowianeczka"),
  cs: ("maják", "nejneobhospodařovávatelnější"),
  tr: ("deniz", "fenerbahçeliler", "muvaffakiyetsizleştirici"),
  la: ("pharus", "honorificabilitudinitatibus"),
  el: ("φάρος", "υδρογόνο", "ηλεκτροεγκεφαλογράφημα"),
  ru: ("маяк", "достопримечательность", "электрификация"),
  uk: ("маяк", "електрифікація"),
  bg: ("морски", "електрификация"),
  is: ("viti", "vaðlaheiðarvegavinnuverkfærageymsluskúr"),
)

#table(
  columns: (auto, auto, 1fr),
  stroke: (x, y) => if y > 0 { (top: 0.3pt + gray) },
  inset: (x: 4pt, y: 3pt),
  table.header[*Code*][*Language*][*Syllables*],
  ..samples
    .pairs()
    .map(((code, words)) => (
      raw(code),
      hy.languages.at(code),
      text(lang: code, words.map(w => split(w, lang: code)).join(", ")),
    ))
    .flatten(),
)

== The same word under different patterns

#let word = "international"
#table(
  columns: 4,
  inset: 4pt,
  ..("en", "de", "fr", "es", "it", "nl", "sv", "pl", "hu", "tr", "la", "fi").map(code => [#raw(code): #split(word, lang: code)])
)

== Known and unknown languages

#let probe = ("en", "de", "el", "ru", "ka", "mn", "tk", "ku", "zh", "ja", "ar", "xx", "", "eng")
#table(
  columns: probe.len(),
  inset: 3pt,
  align: center,
  ..probe.map(c => raw("\"" + c + "\"")),
  ..probe.map(c => if hy.exists(c) [yes] else [no]),
)

The package lists #hy.languages.len() languages:
#hy.languages.pairs().map(((code, name)) => [#name (#raw(code))]).join(", ", last: " and ").

Every listed code is known to the plugin:
#hy.languages.keys().all(hy.exists).

With an unknown language the word is kept whole (`fallback: auto`) or split
by another language's patterns (`fallback: "en"`):
#split("typewriter", lang: "zz", fallback: auto),
#split("typewriter", lang: "zz", fallback: "en"),
#split("typewriter", lang: "de", fallback: "en").

== Against the compiler's own hyphenation

Each word is set in a column too narrow for it, once with the breaks the
plugin reports (as soft hyphens) and once left to the compiler.

#let narrow(body) = box(width: 2.1cm, stroke: 0.3pt + gray, inset: 3pt, body)
#let long = (
  en: "extraordinary photographer",
  de: "Straßenbahnhaltestelle",
  fr: "extraordinairement",
  it: "precipitevolissimevolmente",
  nl: "arbeidsongeschiktheid",
  ru: "достопримечательность",
  el: "ηλεκτροεγκεφαλογράφημα",
  fi: "lentokonesuihkuturbiini",
)

#grid(
  columns: 4,
  gutter: 6pt,
  ..long
    .pairs()
    .map(((code, words)) => {
      set text(lang: code)
      stack(
        spacing: 3pt,
        raw(code),
        narrow({
          set text(hyphenate: false)
          words.split(" ").map(w => hy.syllables(w, lang: code).join("\u{ad}")).join(" ")
        }),
        narrow({
          set text(hyphenate: true)
          words
        }),
      )
    })
)

== Counting syllables

#let poem = (
  "The harbour lights are going out",
  "and every anchored vessel swings",
  "to face a tide that turns about",
  "the quiet water where it sings",
)

#table(
  columns: (1fr, auto),
  stroke: none,
  table.hline(),
  ..poem
    .map(line => {
      let parts = line.split(" ").map(w => hy.syllables(w))
      (parts.map(p => p.join(sym.dot.c)).join(" "), str(parts.map(p => p.len()).sum()))
    })
    .flatten(),
  table.hline(),
)

Longest word of the document by pattern count:
#{
  let all = samples.pairs().map(((code, words)) => words.map(w => (w, hy.syllables(w, lang: code).len()))).flatten().chunks(2)
  let best = all.sorted(key: p => -p.at(1)).first()
  [#best.at(0) (#best.at(1) parts).]
}
