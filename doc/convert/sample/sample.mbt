// A curated sample of the translator's output (docs/edsl-convert.md, section
// 8): `gen_*.mbt` are written by `scripts/edsl_sample.sh` (the readable
// mode) and formatted; the `edsl` stage compares each document with its
// Typst source as a functional twin (structure, layout, SVG, PDF, PNG).

///|
/// The sample: name, the Typst source (a path below the repository root)
/// and the builder of the translated document.
pub fn all() -> Array[(String, String, () -> @doc.Document)] {
  [
    (
      "showcase-static", "doc/convert/sample/showcase_static.typ", showcase_static,
    ),
    ("long", "bench/long.typ", long),
  ]
}
