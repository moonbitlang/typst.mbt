// TEMP (platform probe on the draft PR): FNV-1a over the bits of the C
// library's math functions on a fixed input sequence (see probe3.rs).
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static uint64_t mix(uint64_t h, double v) {
  uint64_t b;
  memcpy(&b, &v, 8);
  return (h ^ b) * 0x100000001b3ULL;
}

int main(void) {
  const char *names[] = {"cbrt", "sin", "cos", "tan", "atan2", "pow", "log", "exp", "hypot", "fma", "sinf", "cosf", "cbrtf"};
  uint64_t h[13];
  for (int k = 0; k < 13; k++) h[k] = 0xcbf29ce484222325ULL;
  volatile double x = 1.0e-3;
  for (int i = 0; i < 200000; i++) {
    volatile double y = 0.37 + (double)i * 1.0e-4;
    volatile float xf = (float)x;
    h[0] = mix(h[0], cbrt(x));
    h[1] = mix(h[1], sin(x));
    h[2] = mix(h[2], cos(x));
    h[3] = mix(h[3], tan(x));
    h[4] = mix(h[4], atan2(x, y));
    h[5] = mix(h[5], pow(x, y));
    h[6] = mix(h[6], log(x));
    h[7] = mix(h[7], exp(y));
    h[8] = mix(h[8], hypot(x, y));
    h[9] = mix(h[9], fma(x, y, -x * y));
    h[10] = mix(h[10], (double)sinf(xf));
    h[11] = mix(h[11], (double)cosf(xf));
    h[12] = mix(h[12], (double)cbrtf(xf));
    x = x * 1.00007 + 1.0e-5;
  }
  for (int k = 0; k < 13; k++) printf("  %-8s %016llx\n", names[k], (unsigned long long)h[k]);
  return 0;
}
