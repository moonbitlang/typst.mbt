// Approximation of `icu_collator::Collator::compare` for the root locale
// with default options (see `collation_gen.mbt`).

///|
fn root_collation_compare(a : String, b : String) -> Int {
  @unscanny.compare_str(a, b)
}
