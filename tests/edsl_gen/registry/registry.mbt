// The registry of converted documents (docs/edsl-convert.md, section 8).
// The generated files of the shard packages (`tests/edsl_gen/s*/gen_*.mbt`,
// written by `tests/runner edsl-convert`, not committed) register one
// builder per case of the suite in their `fn init`; nothing is built at
// initialization. The `edsl-suite` stage of the runner looks the cases up
// by their number, which is their position in the enumeration of the suite
// (files in order, tests in order), the same in the converter and the
// stage; `tests/edsl_gen/manifest.tsv` names them.

///|
/// A converted case: its number and the builder of its document.
pub struct Case {
  number : Int
  build : () -> @doc.Document
}

///|
let cases : Array[Case] = []

///|
/// Register the builder of case `number`.
pub fn register(number : Int, build : () -> @doc.Document) -> Unit {
  cases.push({ number, build, })
}

///|
/// The registered cases, by number. Aborts on a duplicate.
pub fn all() -> Map[Int, Case] {
  let map : Map[Int, Case] = Map([])
  for case_ in cases {
    if map.contains(case_.number) {
      abort("case \{case_.number} is registered twice")
    }
    map[case_.number] = case_
  }
  map
}
