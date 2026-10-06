// glossarium 0.5.10: registered glossary with short/long/plural/longplural/description/group,
// first vs. later use, `@key`, `@key:pl`, `@Key`, `:short`/`:long`, `gls` options, terms in
// headings, captions and the outline, `reset-counts`, printed glossary with back references.
// Engine: show rule on `ref`, state updates and `final()`, label queries, links, figures.
#import "@preview/glossarium:0.5.10": (
  make-glossary, register-glossary, print-glossary, gls, glspl, Gls, Glspl, agls,
  gls-short, gls-long, gls-description, reset-counts, count-refs,
)

#set page(width: 115mm, height: 140mm, margin: (x: 11mm, y: 13mm), numbering: "1")
#set text(size: 9pt)
#set par(justify: true)
#set heading(numbering: "1.1")
#show link: set text(fill: rgb("#1d4f91"))
#show: make-glossary

#let terms = (
  (
    key: "ccd",
    short: "CCD",
    long: "charge-coupled device",
    description: [A detector that collects charge in pixels and shifts it to
      a single amplifier. Its noise sets the floor of the @snr.],
    group: "Instruments",
  ),
  (
    key: "flat",
    short: "flat",
    long: "flat-field frame",
    plural: "flats",
    longplural: "flat-field frames",
    description: "An exposure of an evenly lit surface, used to map pixel sensitivity.",
    group: "Instruments",
  ),
  (
    key: "dark",
    short: "dark frame",
    description: "An exposure taken with the shutter closed.",
    group: "Instruments",
  ),
  (
    key: "guider",
    short: "autoguider",
    artshort: "an",
    description: "A small camera that keeps the mount on target.",
    group: "Instruments",
  ),
  (
    key: "snr",
    short: "SNR",
    long: "signal-to-noise ratio",
    artshort: "an",
    description: "The measured signal divided by its uncertainty.",
    group: "Quantities",
  ),
  (
    key: "fwhm",
    short: "FWHM",
    long: "full width at half maximum",
    plural: "FWHMs",
    longplural: "full widths at half maximum",
    description: [The width of a star image where it falls to half its peak;
      see also the @psf:long.],
    group: "Quantities",
  ),
  (
    key: "psf",
    short: "PSF",
    long: "point spread function",
    group: "Quantities",
  ),
  (
    key: "airmass",
    description: "The path length through the atmosphere relative to the zenith.",
    group: "Quantities",
  ),
  (
    key: "seeing",
    description: "Blurring of star images by turbulence.",
  ),
  // never referenced in the text: only shown with `show-all`
  (
    key: "limb",
    short: "limb darkening",
    description: "The dimming of a stellar disc towards its edge.",
  ),
)
#register-glossary(terms)

#align(center, text(14pt, weight: "bold")[Hillside Observatory Handbook])

#outline()

= The Camera <camera>

The main camera is a @ccd cooled to forty degrees below zero. A @ccd
needs calibration before its images can be measured: every night starts
with a set of @flat:pl and at least five @dark:pl. @Flat:pl are taken on
the twilight sky; later @flat:pl of the same night reuse the exposure
time of the first.

#figure(
  rect(width: 60%, height: 18mm, fill: gradient.linear(luma(60), luma(230), luma(90))),
  caption: [A master @flat built from nine frames (see @camera)],
) <fig-flat>

The #gls("guider") works independently of the main camera.
#agls("guider") is no luxury on this mount, and neither is
#agls("snr", first: true) estimate before a long run.
#lorem(40)

== Reading out the @ccd

Read-out takes eleven seconds. #lorem(70)

#Gls("seeing") limits what the camera can resolve. On a typical night the
@fwhm of a star is about three pixels, and @fwhm:pl below two pixels are
rare. #Glspl("fwhm") are logged for every frame.

#pagebreak()

= Measuring Stars

The #gls("psf") is fitted with a Gaussian. Once the @psf is known, the
@snr follows from the counts inside the aperture; for faint targets an
@snr of ten is the practical limit. #lorem(60)

The short form can be forced, as in @snr:short and #gls-short("fwhm"),
and so can the long one: @snr:long, #gls-long("ccd"). A term may also be
shown under another name: #gls("airmass", display: "the amount of air")
grows towards the horizon, and #gls("airmass", suffix: "-corrected")
magnitudes remove that effect. The description is available too:
"#gls-description("dark")"

#lorem(110)

= Second Season

#context reset-counts("ccd", "flat")

After the counters of two terms are reset, the first use is spelled out
once more: the @ccd was replaced in spring, the @flat library was rebuilt,
while @snr and @fwhm stay short. #lorem(90)

#figure(
  table(
    columns: 3,
    table.header[Night][@seeing][@airmass],
    [12 March], [2.1″], [1.08],
    [13 March], [3.4″], [1.31],
    [15 March], [1.8″], [1.02],
  ),
  caption: [Conditions (uses of @seeing: #context count-refs("seeing"))],
)

#lorem(60) As @fig-flat shows, a single @dark is not enough.

#pagebreak()

= Glossary

#print-glossary(terms)
