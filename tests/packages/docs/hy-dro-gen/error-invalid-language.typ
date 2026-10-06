// hy-dro-gen 0.1.1: `syllables` with a language the plugin has no patterns
// for and no fallback: the WebAssembly plugin itself reports the error.
// Stresses a plugin error message and the trace through the package.
#import "@preview/hy-dro-gen:0.1.1" as hy

#set page(width: 10cm, height: 6cm, margin: 1cm)

#let hyphens(word, lang) = hy.syllables(word, lang: lang).join("-")

English: #hyphens("lighthouse", "en")

Klingon: #hyphens("lighthouse", "tlh")
