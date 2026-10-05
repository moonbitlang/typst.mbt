// Shard 0 of the converted suite (docs/edsl-convert.md, section 8): the
// generated files `gen_*.mbt` of this package (not committed) register
// their cases with the registry when the program starts.

///|
/// Makes the runner link this package, so that its `fn init` runs.
pub fn touch() -> Unit {

}
