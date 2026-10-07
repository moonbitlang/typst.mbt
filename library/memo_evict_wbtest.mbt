// `evict`: the caches that outlive a compilation are dropped on every
// `max_age`-th call.

///|
test "evict" {
  // (Start a new count, whatever ran before.)
  evictions.val = 0
  let data = b"%PDF-evict"
  pdf_document_cache[data] = PdfDocument::synthetic(data, [(1.0, 1.0)])
  plugin_call_cache[hash128(1)] = Ok(b"result")
  evict(3)
  evict(3)
  inspect(pdf_document_cache.contains(data), content="true")
  inspect(plugin_call_cache.length() > 0, content="true")
  evict(3)
  inspect(pdf_document_cache.contains(data), content="false")
  inspect(plugin_call_cache.length(), content="0")
  // And again from there.
  pdf_document_cache[data] = PdfDocument::synthetic(data, [(1.0, 1.0)])
  evict(3)
  evict(3)
  inspect(pdf_document_cache.contains(data), content="true")
  evict(3)
  inspect(pdf_document_cache.contains(data), content="false")
}
