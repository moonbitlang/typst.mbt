///|
extern "C" fn ffi_font_count() -> Int32 = "typst_assets_font_count"

///|
extern "C" fn ffi_font(index : Int32) -> Bytes = "typst_assets_font"

///|
fn font_count() -> Int32 {
  ffi_font_count()
}

///|
fn font_data(index : Int32) -> Bytes {
  ffi_font(index)
}
