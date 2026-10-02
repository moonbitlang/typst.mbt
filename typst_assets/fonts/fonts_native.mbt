///|
extern "C" fn ffi_font_count() -> Int = "typst_assets_font_count"

///|
extern "C" fn ffi_font(index : Int) -> Bytes = "typst_assets_font"

///|
fn font_count() -> Int {
  ffi_font_count()
}

///|
fn font_data(index : Int) -> Bytes {
  ffi_font(index)
}
