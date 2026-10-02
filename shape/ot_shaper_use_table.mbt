// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_use_table.rs` (the lookup
// functions; the tables are generated into `ot_shaper_use_table_gen.mbt`).

///|
fn use_b4(a : FixedArray[Int], i : Int) -> Int {
  (a[i >> 1] >> ((i & 1) << 2)) & 15
}

///|
fn use_get_category(u : UInt) -> Int {
  if u < 921600 {
    let u = u.reinterpret_as_int()
    use_u8[2953 +
    (
      (
        use_u8[625 +
        (
          (
            use_u16[(
              use_u8[113 +
              (
                (use_b4(use_u8, u >> 1 >> 3 >> 3 >> 5) << 5) +
                ((u >> 1 >> 3 >> 3) & 31)
              )] <<
              3
            ) +
            ((u >> 1 >> 3) & 7)] <<
            3
          ) +
          ((u >> 1) & 7)
        )] <<
        1
      ) +
      (u & 1)
    )]
  } else {
    USE_O
  }
}
