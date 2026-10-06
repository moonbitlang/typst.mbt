// codly 1.3.0: long listings that break across pages: repeated header and footer
// (`header-repeat`, `footer-repeat`, cell args and transforms), `breakable: false` blocks that
// move to the next page, a generated 90-line listing, gradient zebra fill (separate layer).
// Engine: breakable blocks with clip and radius, grid headers/footers across pages, raw built
// from strings, show rules on raw.line for many lines.
#import "@preview/codly:1.3.0": *

#set page(
  width: 125mm,
  height: 120mm,
  margin: (x: 10mm, top: 14mm, bottom: 13mm),
  header: text(8pt)[Weather station firmware #h(1fr) build notes],
  footer: context align(center, text(8pt, counter(page).display("1 of 1", both: true))),
)
#set text(size: 9pt)
#show: codly-init

#codly(
  languages: (
    c: (name: "C", color: rgb("#555599")),
    csv: (name: "CSV", color: rgb("#2e7d32")),
    make: (name: "Makefile", color: rgb("#8d6e63")),
  ),
  zebra-fill: luma(245),
)

= Sampling loop

The loop below runs once a second. It is long enough to leave the
page; the file name above it and the note below it are repeated on
every page it touches.

#codly(
  header: [*sampler.c* --- main loop],
  header-repeat: true,
  header-cell-args: (align: center, fill: rgb("#e3e3f3")),
  footer: [continued in `flush.c`],
  footer-repeat: true,
  footer-cell-args: (align: right),
  footer-transform: x => text(size: 7pt, style: "italic", x),
)
```c
#include <stdint.h>
#include "sensors.h"
#include "ring.h"

#define PERIOD_MS   1000
#define WINDOW      16

static struct ring samples;
static uint32_t last_tick;

static int16_t median(int16_t *v, int n)
{
    for (int i = 1; i < n; i++) {
        int16_t key = v[i];
        int j = i - 1;
        while (j >= 0 && v[j] > key) {
            v[j + 1] = v[j];
            j--;
        }
        v[j + 1] = key;
    }
    return v[n / 2];
}

void sampler_init(void)
{
    ring_init(&samples, WINDOW);
    last_tick = clock_ms();
}

void sampler_poll(void)
{
    uint32_t now = clock_ms();
    if (now - last_tick < PERIOD_MS)
        return;
    last_tick = now;

    struct reading r = {
        .temperature = read_thermistor(),
        .humidity    = read_hygrometer(),
        .pressure    = read_barometer(),
        .wind        = read_anemometer(),
    };

    if (r.humidity > 1000)
        r.humidity = 1000;      /* sensor saturates in fog */

    ring_push(&samples, &r);
    if (ring_full(&samples)) {
        int16_t t[WINDOW];
        for (int i = 0; i < WINDOW; i++)
            t[i] = ring_at(&samples, i)->temperature;
        publish(median(t, WINDOW), &r);
        ring_clear(&samples);
    }
}
```

= Build rules

This block is not allowed to break, so it moves as a whole.

#codly(breakable: false, header: [Makefile], header-transform: x => smallcaps(x))
```make
CC      = arm-none-eabi-gcc
CFLAGS  = -Os -Wall -Wextra -ffunction-sections
OBJS    = sampler.o flush.o sensors.o ring.o

firmware.elf: $(OBJS)
	$(CC) $(CFLAGS) -T board.ld -o $@ $^

%.o: %.c sensors.h ring.h
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f $(OBJS) firmware.elf
```
#codly(breakable: true)

= One night of data

The log is generated and ninety records long. Every tenth line is
marked, and the column names are repeated on each page.

#let records = range(90).map(i => {
  let minute = calc.rem(i * 10, 60)
  let hour = calc.rem(18 + calc.quo(i * 10, 60), 24)
  let pad(n) = if n < 10 { "0" + str(n) } else { str(n) }
  let temp = 120 - i + calc.rem(i * 7, 5)
  let hum = 600 + calc.rem(i * 37, 300)
  let wind = calc.rem(i * 13, 41)
  (pad(hour) + ":" + pad(minute), str(calc.quo(temp, 10)) + "." + str(calc.rem(calc.abs(temp), 10)), str(hum), str(wind)).join(",")
})

#codly(
  highlighted-lines: range(10, 91, step: 10).map(n => (n, rgb("#cfe8cf"))),
  header: [`time,temp,hum,wind`],
  header-repeat: true,
  number-align: right + horizon,
)
#raw(records.join("\n"), block: true, lang: "csv")

After the log: #records.len() records, the last one is #raw(records.last()).
The coldest hours once more, striped with a gradient that codly draws
on a layer of its own:

// Headers and footers are reset by the package only after a block has
// seen them; before the introspection has converged, this block would
// still get the ones from above, which the gradient layer cannot hold.
#codly(header: none, footer: none)
#codly(zebra-fill: gradient.linear(rgb("#dcefdc"), rgb("#f6f1d0")), fill: rgb("#fbfbf4"))
#raw(records.slice(60, 84).join("\n"), block: true, lang: "csv")
