// Decodes the embedded fonts (native backend). The base64 data is generated
// into `fonts_gen.c` by the pre-build step (`gen-fonts`).

#include <stddef.h>
#include <stdint.h>

#include <moonbit.h>

extern const char *const *const typst_fonts[];
extern const int32_t typst_font_lens[];
extern const int32_t typst_font_count;

static int typst_b64_value(char c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return c - 'a' + 26;
  if (c >= '0' && c <= '9') return c - '0' + 52;
  if (c == '+') return 62;
  if (c == '/') return 63;
  return -1;
}

MOONBIT_FFI_EXPORT
int32_t typst_assets_font_count(void) { return typst_font_count; }

// Decodes the embedded font with the given index into fresh bytes.
MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_assets_font(int32_t index) {
  int32_t len = typst_font_lens[index];
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  int32_t o = 0;
  uint32_t acc = 0;
  int bits = 0;
  for (const char *const *chunk = typst_fonts[index]; *chunk != NULL; chunk++) {
    for (const char *p = *chunk; *p != '\0' && o < len; p++) {
      int v = typst_b64_value(*p);
      if (v < 0) continue;
      acc = ((acc << 6) | (uint32_t)v) & 0xFFFFFF;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        out[o++] = (uint8_t)((acc >> bits) & 0xFF);
      }
    }
  }
  return out;
}
