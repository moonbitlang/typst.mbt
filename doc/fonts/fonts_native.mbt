///|
extern "C" fn ffi_font_count() -> Int = "doc_fonts_font_count"

///|
extern "C" fn ffi_font(index : Int) -> Bytes = "doc_fonts_font"

///|
fn font_count() -> Int {
  ffi_font_count()
}

///|
fn font_data(index : Int) -> Bytes {
  ffi_font(index)
}
