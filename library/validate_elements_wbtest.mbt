// Elements are compared by identity, and their fingerprints must tell them
// apart: several elements share a name (`grid.cell` and `table.cell` are
// both `cell`).

///|
test "fingerprints distinguish elements with the same name" {
  let pairs = [
    (grid_cell_elem(), table_cell_elem()),
    (grid_header_elem(), table_header_elem()),
    (grid_footer_elem(), table_footer_elem()),
    (grid_h_line_elem(), table_h_line_elem()),
    (grid_v_line_elem(), table_v_line_elem()),
    (list_item_elem(), enum_item_elem()),
    (enum_item_elem(), term_item_elem()),
    (line_elem(), par_line_elem()),
    (curve_line_elem(), raw_line_elem()),
    (move_elem(), curve_move_elem()),
    (footnote_entry_elem(), outline_entry_elem()),
    (underline_elem(), math_underline_elem()),
    (overline_elem(), math_overline_elem()),
    (math_attach_elem(), pdf_attach_elem()),
  ]
  for pair in pairs {
    let (a, b) = pair
    assert_eq(a.name(), b.name())
    assert_false(a == b)
    assert_false(hash128(a) == hash128(b))
    // As element functions, as stored in content (e.g. in metadata).
    let fa = Value::Func(Func::element(a))
    let fb = Value::Func(Func::element(b))
    assert_false(hash128(fa) == hash128(fb))
    assert_false(values_validate_equal(fa, fb))
    assert_true(values_validate_equal(fa, Value::Func(Func::element(a))))
    // The fingerprint is exact: no flag is needed.
    assert_eq(fingerprint_flags_in(() => SipHasher128::new().write(fa)), 0)
  }
}

///|
test "validation: a recorded query tells `grid.cell` from `table.cell`" {
  let elem = TextElem::packed("x").elem()
  let metadata = (func : Element) => {
    Content::from_fields(elem, [Some(Func(Func::element(func)))])
  }
  let grid = metadata(grid_cell_elem())
  let table = metadata(table_cell_elem())
  assert_true(recorded_query_validates([grid], [metadata(grid_cell_elem())]))
  assert_false(recorded_query_validates([grid], [table]))
  // Also as the element of the content itself.
  let cell = (func : Element) => Content::from_fields(func, [])
  assert_false(
    hash128(cell(grid_cell_elem())) == hash128(cell(table_cell_elem())),
  )
  assert_false(
    recorded_query_validates([cell(grid_cell_elem())], [cell(table_cell_elem())]),
  )
}
