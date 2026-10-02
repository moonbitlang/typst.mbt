// Port of `hayro-cmap/src/parse.rs`.

///|
priv struct Context {
  buf : Array[Byte]
  get_cmap : (CMapName) -> Bytes?
}

///|
/// `bundle` is `Some` to emulate the `embed-cmaps` feature (binary cmaps are
/// recognized and decoded with its tables).
fn parse_inner(
  data : BytesView,
  get_cmap : (CMapName) -> Bytes?,
  depth : Int,
  bundle : Bundle?,
) -> CMap? {
  // Prevent stack overflow for malicious cmap files or circular references.
  if depth >= MAX_NESTING_DEPTH {
    return None
  }

  // Check if it's in our custom embedded cmap format.
  if bundle is Some(bundle) && has_prefix(data, bcmap_magic) {
    return bcmap_parse(data, get_cmap, depth, bundle)
  }
  let scanner = @hayro_postscript.Scanner::new(data)
  let ctx : Context = { buf: [], get_cmap, }
  let _codespace_ranges = []
  let ranges = PartitionedRanges::new()
  let notdef_ranges = PartitionedRanges::new()
  let bf_entries = []
  let mut base = None
  let mut registry : Bytes? = None
  let mut ordering : Bytes? = None
  let mut supplement : Int? = None
  let mut cmap_name : Bytes? = None
  let mut writing_mode : WritingMode? = None
  let mut last_name : Bytes? = None
  while !scanner.at_end() {
    guard scanner.parse_object() is Ok(obj) else { return None }
    guard obj is Name(name) else { continue }
    if name.is_literal() {
      match name.as_str() {
        // Strictly speaking, Registry and Ordering should be strings,
        // but some PDF generators emit names instead, so be lenient
        // and try both.
        Some("Registry") => registry = parse_string_or_name(scanner)
        Some("Ordering") => ordering = parse_string_or_name(scanner)
        Some("Supplement") =>
          supplement = match scanner.parse_number() {
            Ok(n) => Some(n.as_i32())
            Err(_) => None
          }
        Some("CMapName") =>
          cmap_name = match scanner.parse_name() {
            Ok(n) => n.decode().to_option()
            Err(_) => None
          }
        Some("WMode") => writing_mode = parse_writing_mode(scanner)
        _ => last_name = name.decode().to_option()
      }
    } else {
      match name.as_str() {
        Some("begincodespacerange") =>
          if parse_codespace_range(scanner, _codespace_ranges, ctx) is None {
            return None
          }
        Some("begincidrange") =>
          if parse_range(scanner, ranges, ctx, "endcidrange") is None {
            return None
          }
        Some("begincidchar") =>
          if parse_char(scanner, ranges, ctx, "endcidchar") is None {
            return None
          }
        Some("beginnotdefrange") =>
          if parse_range(scanner, notdef_ranges, ctx, "endnotdefrange") is None {
            return None
          }
        Some("beginnotdefchar") =>
          if parse_char(scanner, notdef_ranges, ctx, "endnotdefchar") is None {
            return None
          }
        Some("beginbfchar") =>
          if parse_bf_char(scanner, bf_entries, ctx) is None {
            return None
          }
        Some("beginbfrange") =>
          if parse_bf_range(scanner, bf_entries, ctx) is None {
            return None
          }
        Some("usecmap") => {
          guard last_name is Some(last_name) else { return None }
          guard (ctx.get_cmap)(CMapName::from_bytes(last_name))
            is Some(nested_data) else {
            return None
          }
          guard parse_inner(nested_data, ctx.get_cmap, depth + 1, bundle)
            is Some(nested) else {
            return None
          }
          base = Some(nested)
        }
        _ => ()
      }
    }
  }

  // Since we will use binary search for finding the correct entry, sort now.
  ranges.sort()
  notdef_ranges.sort()
  stable_sort_by_start(bf_entries, e => e.range.start)

  // See PDFJS-3323, which has an invalid CIDSystemInfo entry.
  // We ignore it if it's invalid.
  let character_collection = if registry is Some(registry) &&
    ordering is Some(ordering) &&
    supplement is Some(supplement) {
    Some({
      family: CidFamily::from_registry_ordering(registry, ordering),
      supplement,
    })
  } else {
    None
  }
  let metadata = { character_collection, name: cmap_name, writing_mode, }
  Some({
    metadata,
    _codespace_ranges,
    cid_ranges: ranges,
    notdef_ranges,
    bf_entries,
    base,
  })
}

///|
fn has_prefix(data : BytesView, prefix : Bytes) -> Bool {
  if data.length() < prefix.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if data[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
fn parse_writing_mode(scanner : @hayro_postscript.Scanner) -> WritingMode? {
  guard scanner.parse_number() is Ok(n) else { return None }
  match n.as_i32() {
    0 => Some(Horizontal)
    1 => Some(Vertical)
    _ => None
  }
}

///|
fn parse_string_or_name(scanner : @hayro_postscript.Scanner) -> Bytes? {
  match scanner.parse_object() {
    Ok(String(s)) => s.decode().to_option()
    Ok(Name(n)) => n.decode().to_option()
    _ => None
  }
}

///|
fn parse_codespace_range(
  scanner : @hayro_postscript.Scanner,
  ranges : Array[CodespaceRange],
  ctx : Context,
) -> Unit? {
  while true {
    guard scanner.parse_object() is Ok(obj) else { return None }
    if name_matches(obj, "endcodespacerange") {
      return Some(())
    }
    guard extract_u32_code(obj, ctx.buf) is Some(low) else { return None }
    let n_bytes = ctx.buf.length()
    guard read_u32_code(scanner, ctx.buf) is Some(high) else { return None }
    if ctx.buf.length() != n_bytes {
      return None
    }
    ranges.push({ number_bytes: n_bytes, low, high, })
  }
  None
}

///|
fn parse_range(
  scanner : @hayro_postscript.Scanner,
  ranges : PartitionedRanges,
  ctx : Context,
  end_marker : String,
) -> Unit? {
  while true {
    guard scanner.parse_object() is Ok(obj) else { return None }
    if name_matches(obj, end_marker) {
      return Some(())
    }
    guard extract_u32_code(obj, ctx.buf) is Some(start) else { return None }
    let byte_len = ctx.buf.length()
    guard read_u32_code(scanner, ctx.buf) is Some(end) else { return None }
    guard scanner.parse_number() is Ok(n) else { return None }
    // `u32::try_from(i32)`.
    let cid = n.as_i32()
    guard cid >= 0 else { return None }
    ranges.push(byte_len, {
      range: { start, end, },
      cid_start: cid.reinterpret_as_uint(),
    })
  }
  None
}

///|
fn parse_char(
  scanner : @hayro_postscript.Scanner,
  ranges : PartitionedRanges,
  ctx : Context,
  end_marker : String,
) -> Unit? {
  while true {
    guard scanner.parse_object() is Ok(obj) else { return None }
    if name_matches(obj, end_marker) {
      return Some(())
    }
    guard extract_u32_code(obj, ctx.buf) is Some(code) else { return None }
    let byte_len = ctx.buf.length()
    guard scanner.parse_number() is Ok(n) else { return None }
    let cid = n.as_i32()
    guard cid >= 0 else { return None }
    ranges.push(byte_len, {
      range: { start: code, end: code, },
      cid_start: cid.reinterpret_as_uint(),
    })
  }
  None
}

///|
fn parse_bf_char(
  scanner : @hayro_postscript.Scanner,
  entries : Array[BfRange],
  ctx : Context,
) -> Unit? {
  while true {
    guard scanner.parse_object() is Ok(obj) else { return None }
    if name_matches(obj, "endbfchar") {
      return Some(())
    }
    guard extract_u32_code(obj, ctx.buf) is Some(code) else { return None }
    guard scanner.parse_string() is Ok(dst) else { return None }
    guard dst.decode_into(ctx.buf) is Ok(_) else { return None }
    guard decode_be(ctx.buf) is Some(dst_base) else { return None }
    entries.push({ range: { start: code, end: code, }, dst_base, })
  }
  None
}

///|
fn parse_bf_range(
  scanner : @hayro_postscript.Scanner,
  entries : Array[BfRange],
  ctx : Context,
) -> Unit? {
  while true {
    guard scanner.parse_object() is Ok(obj) else { return None }
    if name_matches(obj, "endbfrange") {
      return Some(())
    }
    guard extract_u32_code(obj, ctx.buf) is Some(start) else { return None }
    guard read_u32_code(scanner, ctx.buf) is Some(end) else { return None }
    guard scanner.parse_object() is Ok(next) else { return None }
    match next {
      String(s) => {
        guard s.decode_into(ctx.buf) is Ok(_) else { return None }
        guard decode_be(ctx.buf) is Some(dst_base) else { return None }
        entries.push({ range: { start, end, }, dst_base, })
      }
      Array(array) => {
        let array_scanner = array.objects()
        let mut code = start.to_uint64()
        while code <= end.to_uint64() {
          guard array_scanner.parse_string() is Ok(s) else { return None }
          guard s.decode_into(ctx.buf) is Ok(_) else { return None }
          guard decode_be(ctx.buf) is Some(dst_base) else { return None }
          let c = code.to_uint()
          entries.push({ range: { start: c, end: c, }, dst_base, })
          code += 1UL
        }
      }
      _ => return None
    }
  }
  None
}

///|
/// Convert the buffer into UTF-16 code units.
fn decode_be(bytes : Array[Byte]) -> Array[Int]? {
  if bytes.length() == 0 {
    return None
  }
  let out = []
  let mut i = 0

  // My understanding is that the bf strings should always be UTF16-BE encoded,
  // but it seems like some PDFs only have a single byte there? I guess we just
  // pad them? Wasn't able to find anything specific in the specifications.
  if bytes.length() % 2 != 0 {
    out.push(bytes[0].to_int())
    i = 1
  }
  while i < bytes.length() {
    out.push((bytes[i].to_int() << 8) | bytes[i + 1].to_int())
    i += 2
  }
  Some(out)
}

///|
fn read_u32_code(
  scanner : @hayro_postscript.Scanner,
  buf : Array[Byte],
) -> UInt? {
  guard scanner.parse_string() is Ok(s) else { return None }
  guard s.decode_into(buf) is Ok(_) else { return None }
  bytes_to_u32(buf)
}

///|
fn extract_u32_code(obj : @hayro_postscript.Object, buf : Array[Byte]) -> UInt? {
  guard obj is String(s) else { return None }
  guard s.decode_into(buf) is Ok(_) else { return None }
  bytes_to_u32(buf)
}

///|
fn bytes_to_u32(bytes : Array[Byte]) -> UInt? {
  if bytes.length() == 0 || bytes.length() > 4 {
    return None
  }
  let mut val = 0U
  for b in bytes {
    val = (val << 8) | b.to_uint()
  }
  Some(val)
}

///|
fn name_matches(obj : @hayro_postscript.Object, expected : String) -> Bool {
  obj is Name(name) && !name.is_literal() && name.as_str() == Some(expected)
}
