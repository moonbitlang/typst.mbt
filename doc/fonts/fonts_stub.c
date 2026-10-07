// Copies the fonts of `doc/fonts` into MoonBit bytes (native backend). The
// raw font data is generated into `fonts_gen.c` by the pre-build step
// (`typst_assets/fonts/gen-fonts --prefix=doc_font`) as contiguous arrays.

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include <moonbit.h>

extern const char *const doc_font_data[];
extern const int32_t doc_font_lens[];
extern const int32_t doc_font_count;

MOONBIT_FFI_EXPORT
int32_t doc_fonts_font_count(void) { return doc_font_count; }

// Copies the font with the given index into fresh bytes.
MOONBIT_FFI_EXPORT
moonbit_bytes_t doc_fonts_font(int32_t index) {
  int32_t len = doc_font_lens[index];
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  memcpy(out, doc_font_data[index], (size_t)len);
  return out;
}
