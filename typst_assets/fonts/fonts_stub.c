// Copies the embedded fonts into MoonBit bytes (native backend). The raw
// font data is generated into `fonts_gen.c` by the pre-build step
// (`gen-fonts`) as contiguous arrays.

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include <moonbit.h>

extern const char *const typst_font_data[];
extern const int32_t typst_font_lens[];
extern const int32_t typst_font_count;

MOONBIT_FFI_EXPORT
int32_t typst_assets_font_count(void) { return typst_font_count; }

// Copies the embedded font with the given index into fresh bytes.
MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_assets_font(int32_t index) {
  int32_t len = typst_font_lens[index];
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  memcpy(out, typst_font_data[index], (size_t)len);
  return out;
}
