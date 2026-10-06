// Port of the tests of read-fonts 0.39.2 `src/tables/hdmx.rs`.

///|
/// Three records for three glyphs. Each record is 5 bytes long, but the
/// entries are aligned to 32 bits, so the record size is 8 bytes
/// ("Size of a device record, 32-bit aligned").
fn make_hdmx() -> Bytes {
  // version, num_records, size_device_record
  b"\x00\x00\x00\x03\x00\x00\x00\x08" +
  // 3 records [pixel_size, max_width, width0, width1, ..padding]
  b"\x08\x0d\x0a\x0c\x0d\x00\x00\x00" +
  b"\x10\x15\x12\x14\x15\x00\x00\x00" +
  b"\x20\x34\x26\x28\x34\x00\x00\x00"
}

///|
fn hdmx_record(hdmx : @read_fonts.Hdmx, size : Int) -> (Int, Int, Array[Int])? {
  match hdmx.record_for_size(size) {
    Some(record) =>
      Some(
        (
          record.pixel_size(),
          record.max_width(),
          record.widths().iter().map(b => b.to_int()).collect(),
        ),
      )
    None => None
  }
}

///|
test "read_hdmx" {
  let buf = make_hdmx()
  let hdmx = @read_fonts.Hdmx::read(@read_fonts.FontData::new(buf[:]), 3)
  assert_eq(hdmx.version(), 0)
  assert_eq(hdmx.num_records(), 3)
  assert_eq(hdmx.size_device_record(), 8)
  assert_eq(hdmx_record(hdmx, 8), Some((8, 13, [10, 12, 13])))
  assert_eq(hdmx_record(hdmx, 16), Some((16, 21, [18, 20, 21])))
  assert_eq(hdmx_record(hdmx, 32), Some((32, 52, [38, 40, 52])))
}

///|
test "find_by_size" {
  let buf = make_hdmx()
  let hdmx = @read_fonts.Hdmx::read(@read_fonts.FontData::new(buf[:]), 3)
  assert_true(hdmx.record_for_size(8) is Some(_))
  assert_true(hdmx.record_for_size(16) is Some(_))
  assert_true(hdmx.record_for_size(32) is Some(_))
  assert_true(hdmx.record_for_size(7) is None)
  assert_true(hdmx.record_for_size(20) is None)
  assert_true(hdmx.record_for_size(72) is None)
}

///|
test "short hdmx data" {
  // Less than the 8 header bytes.
  let short = try
    @read_fonts.Hdmx::read(@read_fonts.FontData::new(b"\x00\x00\x00\x01"[:]), 3)
  catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(short)
  // The header announces more records than there is data for: the records
  // read as empty (upstream `unwrap_or_default`).
  let buf = make_hdmx()
  let hdmx = @read_fonts.Hdmx::read(@read_fonts.FontData::new(buf[0:24]), 3)
  assert_true(hdmx.record_for_size(8) is None)
}
