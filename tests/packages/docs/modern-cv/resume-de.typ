// modern-cv 0.10.0: the other option values of `resume`: German (`language: "de"`, title and
// footer text from lang.toml), accent colour given as a string, uncoloured headers, no
// footer, no small caps, US-letter paper, a drawn profile picture (clipped to a circle by
// the template), embedded fonts for body and header, a custom contact separator and inset,
// entries with per-entry accent/location colours, no address icon.
// Engine paths: clip with radius on a block, grid with fixed row height, German
// hyphenation, linguify with a non-default language, gradients inside clipped content.
#import "@preview/modern-cv:0.10.0": *

// A portrait drawn with shapes: the template crops it to a 4 cm circle.
#let portrait = box(width: 4cm, height: 4cm, fill: gradient.linear(rgb("#f3e3c3"), rgb("#d9a45b"), angle: 60deg), {
  place(center + bottom, ellipse(width: 3.1cm, height: 2.2cm, fill: rgb("#5b3a29")))
  place(center + horizon, dy: -0.35cm, circle(radius: 0.85cm, fill: rgb("#f6d7b8"), stroke: 0.6pt + rgb("#5b3a29")))
  place(center + horizon, dy: -1.0cm, ellipse(width: 1.9cm, height: 0.9cm, fill: rgb("#3b2a20")))
  place(center + horizon, dx: -0.3cm, dy: -0.4cm, circle(radius: 1.5pt, fill: black))
  place(center + horizon, dx: 0.3cm, dy: -0.4cm, circle(radius: 1.5pt, fill: black))
  place(center + horizon, dy: 0.05cm, curve(stroke: 0.8pt, curve.move((0pt, 0pt)), curve.quad((8pt, 6pt), (16pt, 0pt))))
})

#show: resume.with(
  author: (
    firstname: "Katrin",
    lastname: "Vogel",
    email: "katrin.vogel@wetterwarte.example",
    phone: "+49 761 555 0123",
    github: "kvogel-met",
    orcid: "0000-0001-8271-5555",
    address: "Schauinslandstraße 14, 79100 Freiburg im Breisgau",
    positions: ("Meteorologin", "Datenanalystin", "Bergwetterdienst"),
  ),
  profile-picture: portrait,
  contact-items-separator: [#h(6pt)#sym.diamond.filled.small#h(6pt)],
  contact-items-inset: (left: 2pt, right: 1pt),
  date: "6. Oktober 2026",
  accent-color: "#7a3b12",
  colored-headers: false,
  show-footer: false,
  language: "de",
  font: ("Libertinus Serif",),
  header-font: "New Computer Modern",
  paper-size: "us-letter",
  use-smallcaps: false,
  show-address-icon: false,
)

= Berufserfahrung

#resume-entry(
  title: "Leitende Meteorologin",
  location: "Freiburg im Breisgau",
  date: "seit 2020",
  description: "Wetterwarte Südschwarzwald",
  accent-color: rgb("#7a3b12"),
  location-color: rgb("#7a3b12"),
)

#resume-item[
  - Verantwortlich für die tägliche Lawinen- und Gewittervorhersage im Feldberggebiet
  - Aufbau eines Messnetzes aus 26 automatischen Stationen zwischen 400 und 1 490 Metern
  - Einführung einer Nachtschicht-Übergabe mit schriftlichem Protokoll; seither keine
    verpasste Unwetterwarnung
]

#resume-entry(
  title: "Wissenschaftliche Mitarbeiterin",
  location: "Karlsruhe",
  date: "2015 -- 2020",
  description: "Institut für Meteorologie und Klimaforschung",
)

#resume-item[
  - Auswertung von Niederschlagsradar-Daten für konvektive Ereignisse im Oberrheingraben
  - Betreuung von sieben Abschlussarbeiten; Lehrauftrag »Statistik für Geowissenschaften«
  - Mitarbeit an zwei Messkampagnen mit Radiosonden und Fesselballon
]

#resume-entry(
  title: "Wetterbeobachterin",
  location: "Zugspitze",
  date: "2013 -- 2015",
  description: "Bergobservatorium",
)

#resume-item[
  - Stündliche Augenbeobachtungen und Wartung der Instrumente bei bis zu −28 °C
  - Digitalisierung der handschriftlichen Klimabücher von 1900 bis 1950
]

= Ausbildung

#resume-entry(
  title: "Albert-Ludwigs-Universität Freiburg",
  location: "Freiburg im Breisgau",
  date: "2015 -- 2019",
  description: "Promotion (Dr. rer. nat.), Meteorologie",
)

#resume-item[
  - Dissertation: »Auslösung von Gewittern an der Westabdachung des Schwarzwalds«
  - Auszeichnung der Fakultät für die beste Dissertation des Jahrgangs
]

#resume-entry(
  title: "Universität Innsbruck",
  location: "Innsbruck, Österreich",
  date: "2008 -- 2013",
  description: "Bachelor und Master, Atmosphärenwissenschaften",
)

#resume-gpa("1,2", "1,0 (Bestnote)")

= Kenntnisse

#resume-skill-item("Sprachen", (strong("Deutsch"), strong("Englisch"), "Französisch", "Italienisch"))
#resume-skill-item("Programmierung", (strong("Python"), "Fortran", "R", "Shell"))
#resume-skill-item("Fachgebiete", ("Gebirgsmeteorologie", "Radarmeteorologie", "Nowcasting", "Messtechnik"))

#resume-skill-grid(
  categories-with-values: (
    "Führerscheine": ("Klasse B", "Klasse C1", "Pistenraupe"),
    "Ehrenamt": ("Bergwacht Schwarzwald", "Jugend forscht (Jurorin)"),
  ),
)

= Zertifikate

#resume-certification("Lawinenkommissions-Ausbildung, Stufe 2", "Jan. 2021")
#resume-certification("Flugwetterberatung nach ICAO Anhang 3", "Nov. 2017")
#resume-certification("Ersthelferin im alpinen Gelände", "Mai 2016")

= Projekte

#resume-entry(
  title: "gipfelwind",
  location: github-link("kvogel-met/gipfelwind"),
  date: "2022 -- heute",
  description: "Böenvorhersage für Seilbahnbetreiber",
  title-link: "https://gipfelwind.example",
)

#resume-item[
  - Kurzfristvorhersage von Böenspitzen aus Stationsdaten; im Einsatz bei vier Bergbahnen
  - Wird als offene Software entwickelt und von zwei Hochschulen in der Lehre verwendet
]
