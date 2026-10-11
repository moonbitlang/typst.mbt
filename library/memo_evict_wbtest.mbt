// `evict`: what outlives a compilation has comemo's ages. Every call makes
// an entry older by one, a hit makes it young, and an entry that was not
// found for more than `max_age` calls is dropped (`comemo/src/memoize.rs`,
// `CacheData::evict`: `*age += 1; *age <= max_age`).

///|
test "evict: the decode caches have ages" {
  evict(0)
  let data = b"%PDF-evict"
  let key = data_hash(data)
  pdf_document_cache.insert(key, PdfDocument::synthetic(data, [(1.0, 1.0)]))
  plugin_call_cache.insert(hash128(1), Ok(b"result"))
  // An entry survives `max_age` calls without a hit.
  evict(3)
  evict(3)
  evict(3)
  inspect(pdf_document_cache.length(), content="1")
  inspect(plugin_call_cache.length(), content="1")
  // A hit makes it young again: the one that is asked for stays, the other
  // goes with the next call.
  assert_true(pdf_document_cache.get(key) is Some(_))
  evict(3)
  inspect(pdf_document_cache.length(), content="1")
  inspect(plugin_call_cache.length(), content="0")
  evict(3)
  evict(3)
  inspect(pdf_document_cache.length(), content="1")
  evict(3)
  inspect(pdf_document_cache.length(), content="0")
  // `evict(0)` drops everything, whatever its age.
  pdf_document_cache.insert(key, PdfDocument::synthetic(data, [(1.0, 1.0)]))
  plugin_module_cache.insert(hash128(2), [])
  numbering_pattern_cache.insert(
    hash128("1."),
    NumberingPattern::from_str("1."),
  )
  evict(0)
  inspect(pdf_document_cache.length(), content="0")
  inspect(plugin_module_cache.length(), content="0")
  inspect(numbering_pattern_cache.length(), content="0")
}

///|
/// A plugin that is loaded in every compilation is one module for as long
/// as the process runs: its entry is found, so it never gets old. (Dropped
/// as a whole on every tenth call, as the decode caches were, the module
/// was another object after ten compilations, and unequal to the one that a
/// kept call returns.)
test "evict: a plugin that is loaded again and again stays one module" {
  evict(0)
  let bytes = plugin_test_memory_only(3)
  let first = plugin_test_load(bytes)
  for _ in 0..<25 {
    evict(10)
    assert_true(plugin_test_load(plugin_test_memory_only(3)) == first)
  }
  // Not loaded for `max_age` calls: still there. One more: another module.
  for _ in 0..<10 {
    evict(10)
  }
  assert_true(plugin_test_load(bytes) == first)
  for _ in 0..<11 {
    evict(10)
  }
  assert_false(plugin_test_load(bytes) == first)
  evict(0)
}
