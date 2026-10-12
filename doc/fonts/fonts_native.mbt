///|
extern "C" fn ffi_font_count() -> Int32 = "doc_fonts_font_count"

///|
extern "C" fn ffi_font(index : Int32) -> Bytes = "doc_fonts_font"

///|
fn font_count() -> Int32 {
  ffi_font_count()
}

///|
fn font_data(index : Int32) -> Bytes {
  ffi_font(index)
}
