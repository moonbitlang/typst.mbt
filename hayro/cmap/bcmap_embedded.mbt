// Port of `hayro-cmap/src/bcmap/embedded.rs`.
//
// Upstream decompresses the brotli-compressed bundle `assets/cmaps.brotli`
// into a lazily initialized static. Typst does not enable the
// `embed-cmaps` feature, so the bundle is not embedded here; a decompressed
// bundle can be loaded with `Bundle::new` instead.

///|
/// The (decompressed) bundle of embedded binary cmaps.
pub struct Bundle {
  priv data : Bytes
  priv delta_table : HuffmanTable
  priv count_table : HuffmanTable
  priv entries : Array[(Int, Int)]
}

///|
/// Read a decompressed cmap bundle.
pub fn Bundle::new(decompressed : Bytes) -> Bundle? {
  let reader = BReader::new(decompressed)
  guard reader.read_u32() is Some(huff_size) else { return None }
  guard reader.read_bytes(huff_size.reinterpret_as_int()) is Some(huff_data) else {
    return None
  }
  guard decode_tables(huff_data) is Some((delta_table, count_table)) else {
    return None
  }
  let entries = []
  while !reader.at_end() {
    let start = reader.position()

    // Skip file magic and version.
    guard reader.read_bytes(6) is Some(_) else { return None }
    guard reader.read_u32() is Some(file_len) else { return None }
    let file_len = file_len.reinterpret_as_int()
    guard reader.read_bytes(file_len - 10) is Some(_) else { return None }
    entries.push((start, start + file_len))
  }
  Some({ data: decompressed, delta_table, count_table, entries, })
}

///|
/// Load the data for a cmap file, by name.
pub fn Bundle::load_embedded(self : Bundle, name : CMapName) -> Bytes? {
  // Get the index of the font of the cmap in the bundle. They are sorted
  // alphabetically.
  let idx = match name {
    N83pvRksjH => 0
    N90msRksjH => 1
    N90msRksjV => 2
    N90mspRksjH => 3
    N90mspRksjV => 4
    N90pvRksjH => 5
    AddRksjH => 6
    AddRksjV => 7
    AdobeCns1Ucs2 => 8
    AdobeGb1Ucs2 => 9
    AdobeJapan1Ucs2 => 10
    AdobeKorea1Ucs2 => 11
    B5pcH => 12
    B5pcV => 13
    CnsEucH => 14
    CnsEucV => 15
    ETenB5H => 16
    ETenB5V => 17
    ETenmsB5H => 18
    ETenmsB5V => 19
    EucH => 20
    EucV => 21
    ExtRksjH => 22
    ExtRksjV => 23
    GbEucH => 24
    GbEucV => 25
    GbkEucH => 26
    GbkEucV => 27
    Gbk2kH => 28
    Gbk2kV => 29
    GbkpEucH => 30
    GbkpEucV => 31
    GbpcEucH => 32
    GbpcEucV => 33
    H => 34
    HKscsB5H => 35
    HKscsB5V => 36
    IdentityH => 37
    IdentityV => 38
    KscEucH => 39
    KscEucV => 40
    KscmsUhcH => 41
    KscmsUhcHwH => 42
    KscmsUhcHwV => 43
    KscmsUhcV => 44
    KscpcEucH => 45
    UniCnsUcs2H => 46
    UniCnsUcs2V => 47
    UniCnsUtf16H => 48
    UniCnsUtf16V => 49
    UniGbUcs2H => 50
    UniGbUcs2V => 51
    UniGbUtf16H => 52
    UniGbUtf16V => 53
    UniJisUcs2H => 54
    UniJisUcs2HwH => 55
    UniJisUcs2HwV => 56
    UniJisUcs2V => 57
    UniJisUtf16H => 58
    UniJisUtf16V => 59
    UniKsUcs2H => 60
    UniKsUcs2V => 61
    UniKsUtf16H => 62
    UniKsUtf16V => 63
    V => 64
    Custom(_) => return None
  }
  guard idx < self.entries.length() else { return None }
  let (start, end) = self.entries[idx]
  Some(self.data[start:end].to_owned())
}
