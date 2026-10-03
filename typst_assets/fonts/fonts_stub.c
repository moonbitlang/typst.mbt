// Decodes the embedded fonts (native backend). The base64 data is generated
// into `fonts_gen.c` by the pre-build step (`gen-fonts`).

#include <stddef.h>
#include <stdint.h>

#include <moonbit.h>

extern const char *const *const typst_fonts[];
extern const int32_t typst_font_lens[];
extern const int32_t typst_font_count;

// The value of each base64 digit, or -1.
static int8_t typst_b64_table[256];
static int typst_b64_ready = 0;

static void typst_b64_init(void) {
  for (int i = 0; i < 256; i++) typst_b64_table[i] = -1;
  for (int i = 0; i < 26; i++) {
    typst_b64_table['A' + i] = (int8_t)i;
    typst_b64_table['a' + i] = (int8_t)(26 + i);
  }
  for (int i = 0; i < 10; i++) typst_b64_table['0' + i] = (int8_t)(52 + i);
  typst_b64_table['+'] = 62;
  typst_b64_table['/'] = 63;
  typst_b64_ready = 1;
}

MOONBIT_FFI_EXPORT
int32_t typst_assets_font_count(void) { return typst_font_count; }

// Decodes the embedded font with the given index into fresh bytes.
//
// Characters that are not base64 digits (padding) are skipped. Groups of four
// digits are decoded at once; the bit-by-bit loop handles the rest. This is
// the startup's hot path (about 10 MB of fonts).
MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_assets_font(int32_t index) {
  if (!typst_b64_ready) typst_b64_init();
  int32_t len = typst_font_lens[index];
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  int32_t o = 0;
  uint32_t acc = 0;
  int bits = 0;
  for (const char *const *chunk = typst_fonts[index]; *chunk != NULL; chunk++) {
    const unsigned char *p = (const unsigned char *)*chunk;
    // Fast path: whole groups of four digits while no bits are pending.
    while (bits == 0 && o + 3 <= len) {
      int a = typst_b64_table[p[0]];
      if (a < 0) break;
      int b = typst_b64_table[p[1]];
      if (b < 0) break;
      int c = typst_b64_table[p[2]];
      if (c < 0) break;
      int d = typst_b64_table[p[3]];
      if (d < 0) break;
      uint32_t v = ((uint32_t)a << 18) | ((uint32_t)b << 12) |
                   ((uint32_t)c << 6) | (uint32_t)d;
      out[o] = (uint8_t)(v >> 16);
      out[o + 1] = (uint8_t)(v >> 8);
      out[o + 2] = (uint8_t)v;
      o += 3;
      p += 4;
    }
    for (; *p != '\0' && o < len; p++) {
      int v = typst_b64_table[*p];
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
