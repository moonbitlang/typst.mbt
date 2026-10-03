///|
/// Upstream `filter::ccitt::tests::issue1258`.
test "ccitt issue1258" {
  let params : Dict = from_bytes(b"<< /K 0 /Columns 8 /Rows 1 >>"[:]).unwrap()
  let decoded = ccitt_decode(
    b"\x35\x14"[:],
    params,
    ImageDecodeParams::default(),
  ).unwrap()
  assert_eq(decoded.data.to_bytes(), b"\x00\x00\x00\x00\x00\x00\x00\x00")
  assert_eq(decoded.image_data.unwrap().height, 1)
}
