// basic-resume 0.2.9: the other option values: A4, centred name and contact line, Libertinus
// Serif, larger sizes, another accent colour, `lang: "de"` with German text (hyphenation),
// a partial header (no pronouns, LinkedIn or ORCID: the filter of empty items), `edu` with
// `consistent: true`, and the generic one-by-two / two-by-two helpers used directly.
// Engine paths: German hyphenation and justification, align in show rules, rgb from string,
// math `dash.em` joined with strings, empty-string defaults.
#import "@preview/basic-resume:0.2.9": *

#show: resume.with(
  author: "Lotte Schäfer",
  author-position: center,
  personal-info-position: center,
  location: "Leipzig",
  email: "lotte.schaefer@buchwerk.example",
  github: "github.com/lschaefer-satz",
  phone: "+49 341 555 0199",
  personal-site: "schaefer-satz.example",
  accent-color: "#8b2635",
  font: "Libertinus Serif",
  paper: "a4",
  author-font-size: 26pt,
  font-size: 11pt,
  lang: "de",
)

== Profil

Schriftsetzerin und Herstellerin mit Schwerpunkt auf wissenschaftlichen Büchern. Ich
betreue Manuskripte von der Rohfassung bis zur Druckfreigabe und automatisiere dabei alles,
was sich wiederholt: Registererstellung, Formelsatz, Bildrechteverwaltung.

== Ausbildung

#edu(
  institution: "Hochschule für Grafik und Buchkunst Leipzig",
  location: "Leipzig",
  dates: dates-helper(start-date: "Okt. 2012", end-date: "Sept. 2016"),
  degree: "Diplom Buchkunst/Grafik-Design, Fachklasse Typografie",
  consistent: true,
)
- Diplomarbeit: _Der Fußnotenapparat in mehrsprachigen Editionen_ (Note 1,3)
- Auslandssemester an der Koninklijke Academie in Den Haag

#edu(
  institution: "Gutenbergschule Leipzig",
  location: "Leipzig",
  dates: dates-helper(start-date: "Aug. 2009", end-date: "Juli 2012"),
  degree: "Ausbildung zur Mediengestalterin Digital und Print",
  consistent: true,
)
- Abschluss als Jahrgangsbeste; Auszeichnung der Industrie- und Handelskammer

== Berufserfahrung

#work(
  title: "Leiterin Herstellung",
  location: "Leipzig",
  company: "Buchwerk Wissenschaftsverlag",
  dates: dates-helper(start-date: "Jan. 2020", end-date: "heute"),
)
- Verantwortlich für jährlich rund 45 Neuerscheinungen in Mathematik und Naturwissenschaften
- Umstellung der Herstellung auf einen einheitlichen Satzablauf mit automatischer Prüfung
  von Umbruch, Schusterjungen und Hurenkindern
  - Durchlaufzeit vom angenommenen Manuskript bis zur Druckdatei von 14 auf 6 Wochen verkürzt
  - Fehlerquote in den Korrekturfahnen halbiert
- Verhandlung der Rahmenverträge mit zwei Druckereien und einer Buchbinderei

#work(
  title: "Schriftsetzerin",
  location: "Göttingen",
  company: "Satzbüro Vogel & Partner",
  dates: dates-helper(start-date: "Okt. 2016", end-date: "Dez. 2019"),
)
- Satz von Festschriften, Tagungsbänden und einer zwölfbändigen kritischen Briefausgabe
- Entwicklung von Vorlagen für dreispaltige Wörterbuchartikel mit lebenden Kolumnentiteln
- Einarbeitung und Betreuung von drei Auszubildenden

#generic-two-by-two(
  top-left: [*Freie Mitarbeit*],
  top-right: [seit 2017],
  bottom-left: [Korrektorat und Registererstellung für vier Verlage],
  bottom-right: [_ortsunabhängig_],
)
- Sach- und Namensregister für bisher 31 Monografien

== Projekte

#project(
  name: "Registerwerkzeug",
  role: "Autorin",
  dates: dates-helper(start-date: "2021", end-date: "heute"),
  url: "schaefer-satz.example/register",
)
- Erzeugt aus markierten Stichwörtern ein mehrstufiges Register mit Verweisen und
  Seitenbereichen; sortiert nach den Regeln für Namensansetzungen

#project(
  name: "Lesbarkeitsmessungen",
  url: "example.org/lesbarkeit",
)
- Vergleich von Zeilenlängen und Durchschuss in 200 Lehrbüchern aus sechs Jahrzehnten

#generic-one-by-two(
  left: [*Werkstattgespräche* --- monatliche offene Runde zur Buchherstellung],
  right: [2018 #sym.dash.en 2022],
)
- 43 Abende mit jeweils zwanzig bis sechzig Gästen

== Zertifikate

#certificates(
  name: "Geprüfte Medienfachwirtin Print",
  issuer: "IHK zu Leipzig",
  date: "März 2019",
)

#certificates(
  name: "Barrierefreie Dokumente (PDF/UA)",
  issuer: "Akademie der Deutschen Medien",
  url: "example.org/zertifikat/pdfua",
  date: "Nov. 2022",
)

== Ehrenamt

#extracurriculars(
  activity: "Vorstand, Verein für Schwarze Kunst e. V.",
  dates: dates-helper(start-date: "2018", end-date: "heute"),
)
- Pflege einer Handsetzerei mit 180 Bleischriften; Führungen für Schulklassen

== Kenntnisse
- *Satz*: Mikrotypografie, Formelsatz, mehrsprachiger Satz (Griechisch, Kyrillisch),
  Tabellen- und Registersatz
- *Sprachen*: Deutsch (Muttersprache), Englisch (verhandlungssicher), Niederländisch (gut),
  Latein (Lesekenntnisse)
- *Sonstiges*: Farbmanagement, Papierkunde, Kalkulation, Urheber- und Bildrecht
