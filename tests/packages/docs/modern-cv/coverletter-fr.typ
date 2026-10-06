// modern-cv 0.10.0: a French cover letter (`coverletter`, `hiring-entity-info`,
// `letter-heading`) with the default signature built from `author.signature` (a drawn
// curve), the default closing from lang.toml, custom heading/signature padding and
// alignment, paragraph spacing, a second page so that the footer counter runs, and a
// custom salutation. A second letter-heading uses the default "dear".
// Engine paths: linguify inside content (context + state database), three-box footer with
// 1fr widths, underline with `evade: false`, `align(bottom)` closing, pad with spread args.
#import "@preview/modern-cv:0.10.0": *

#let signature-drawing = box(width: 130pt, height: 36pt, {
  place(left + horizon, curve(
    stroke: (paint: rgb("#1b2a6b"), thickness: 1.1pt, cap: "round"),
    curve.move((0pt, 10pt)),
    curve.cubic((12pt, -22pt), (22pt, 28pt), (34pt, 2pt)),
    curve.cubic((40pt, -10pt), (46pt, 16pt), (58pt, 4pt)),
    curve.cubic((66pt, -4pt), (70pt, 12pt), (82pt, 6pt)),
    curve.quad((100pt, -2pt), (128pt, 8pt)),
  ))
})

#show: coverletter.with(
  author: (
    firstname: "Mathilde",
    lastname: "Dubois",
    email: "mathilde.dubois@atelier-cartes.example",
    homepage: "https://atelier-cartes.example",
    phone: "(+33) 4 55 55 01 28",
    github: "mdubois-carto",
    linkedin: "mathilde-dubois",
    address: "8 rue des Tanneurs, 63000 Clermont-Ferrand",
    positions: ("Cartographe", "Géomaticienne", "Autrice d'atlas"),
    signature: signature-drawing,
    custom: (
      (text: "Portfolio", icon: "map", link: "https://atelier-cartes.example/portfolio"),
    ),
  ),
  profile-picture: none,
  language: "fr",
  date: "6 octobre 2026",
  accent-color: rgb("#1b6b4a"),
  heading-padding: (above: 1.6em, below: 0.8em),
  signature-padding: (top: 1.5em, left: 1em),
  signature-alignment: right,
  par-spacing: 1.2em,
  show-footer: true,
  show-address-icon: false,
  paper-size: "a4",
  description: "Lettre de motivation de Mathilde Dubois",
  keywords: ("cartographie", "atlas"),
)

#hiring-entity-info(
  entity-info: (
    target: [Service des ressources humaines],
    name: [Institut géographique du Massif central],
    street-address: [24 avenue des Volcans],
    city: [63170 Aubière],
  ),
  date: "Clermont-Ferrand, le 6 octobre 2026",
)

#letter-heading(
  job-position: "le poste de cartographe en chef",
  addressee: "Madame Moreau",
  dear: "Chère",
  padding: (top: 1.2em, bottom: 0.8em),
)

= À propos de moi

Cartographe depuis douze ans, j'ai dessiné des cartes pour des randonneurs, des géologues et
des élus, et j'ai appris qu'une bonne carte est d'abord une carte qu'on a envie de déplier.
J'ai dirigé la refonte de l'atlas des chemins du Livradois, soit 148 feuilles au
1:25 000 #sym.space.nobreak;dont chacune a été vérifiée sur le terrain, à pied.

Mon travail récent porte sur la généralisation automatique du relief : comment passer d'un
modèle numérique au mètre près à des courbes de niveau lisibles sans trahir les crêtes.
J'ai publié ces méthodes et les outils qui les accompagnent sous licence libre.

= Pourquoi l'Institut

L'Institut entreprend la nouvelle série des cartes volcaniques, et c'est un projet pour
lequel je crois être préparée :

- j'ai l'habitude des chaînes de production où chaque feuille doit pouvoir être régénérée à
  l'identique dix ans plus tard ;
- je connais le terrain, pour avoir levé moi-même les sentiers de la chaîne des Puys ;
- je sais ce que coûte une erreur de toponymie, et comment l'éviter : en demandant aux
  habitants.

#lorem(90)

= Ce que j'apporterais

Une équipe de cartographie a besoin de règles simples et de quelqu'un qui les défende.
Je propose trois chantiers pour la première année : un cahier des charges graphique commun
aux séries, un contrôle automatique des feuilles avant impression, et un atelier mensuel
ouvert où les utilisateurs viennent critiquer nos épreuves.

#lorem(120)

Je serais heureuse de vous présenter ces idées, cartes à l'appui.

#letter-heading(job-position: "un entretien", addressee: "et cher comité")

Je reste à votre disposition pour toute date qui vous conviendrait en novembre.
